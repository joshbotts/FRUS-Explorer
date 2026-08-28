#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""The V-5 step-4 spike's parity half: does a standalone llama.cpp build reproduce the
stored corpus vectors from the pinned GGUF?

Reconstructs era-stratified chunks from the R-0 text layer exactly as the harvest cut
them (PREFIX + text[c0:c1]), embeds them all in ONE llama-embedding invocation (one
model load; --embd-separator batches the prompts), and reports the cosine distribution
against the stored float vectors — placed against the §1a ladder, where ≥0.995 costs
0.003 recall and 1.0 is parity by construction.

Stdlib only, macOS bundled python3 — the tools/semantic-harvest contract.

Env:
  LLAMA_EMBEDDING  path to the llama-embedding binary (required)
  GGUF             path to the pinned GGUF (required; SHA-verify it yourself first)
  STORE            the raw store (default ~/frus-semantic-raw)
  VOLUMES          comma-separated volume ids (default an era-stratified six)
  PER_VOLUME       chunks sampled per volume, evenly strided (default 50)
  OUT              report JSON (default Planning/semantic-vectors/encoder-spike-parity.json)
"""
from __future__ import annotations
import gzip, json, math, os, struct, subprocess, sys, tempfile

STORE = os.path.expanduser(os.environ.get("STORE", "~/frus-semantic-raw"))
VOLUMES = os.environ.get(
    "VOLUMES", "frus1861,frus1895p1,frus1918Russiav02,frus1943China,frus1961-63v06,frus1981-88v41"
).split(",")
PER_VOLUME = int(os.environ.get("PER_VOLUME", "50"))
PREFIX = "title: none | text: "
SEP = "<#frus-sep#>"


def chunks_for(volume: str) -> list[tuple[str, list[float]]]:
    """(prompt, stored_vector) per sampled chunk, in store row order."""
    metas = [json.loads(line) for line in open(f"{STORE}/vectors/{volume}.meta.jsonl")]
    texts: dict[str, str] = {}
    with gzip.open(f"{STORE}/text/{volume}.jsonl.gz", "rt") as handle:
        for line in handle:
            row = json.loads(line)
            texts[row["d"]] = row["t"]
    raw = open(f"{STORE}/vectors/{volume}.bin", "rb").read()
    dims = 768
    assert len(raw) == len(metas) * dims * 4, f"{volume}: bin size disagrees with meta rows"

    stride = max(1, len(metas) // PER_VOLUME)
    picked = list(range(0, len(metas), stride))[:PER_VOLUME]
    out = []
    for index in picked:
        meta = metas[index]
        text = texts[meta["d"]][meta["c0"]:meta["c1"]]
        vector = list(struct.unpack_from(f"<{dims}f", raw, index * dims * 4))
        out.append((PREFIX + text, vector))
    return out


def main() -> int:
    binary = os.environ.get("LLAMA_EMBEDDING")
    gguf = os.environ.get("GGUF")
    if not binary or not gguf:
        sys.exit("Set LLAMA_EMBEDDING and GGUF.")
    out_path = os.environ.get("OUT", "Planning/semantic-vectors/encoder-spike-parity.json")

    prompts, stored = [], []
    per_volume_counts = {}
    for volume in VOLUMES:
        rows = chunks_for(volume)
        per_volume_counts[volume] = len(rows)
        for prompt, vector in rows:
            # The separator must never appear in a prompt; a corpus chunk containing it
            # would silently split into two embeddings and misalign every later cosine.
            assert SEP not in prompt
            prompts.append(prompt.replace("\n", " "))
            stored.append(vector)

    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(SEP.join(prompts))
        prompt_file = handle.name

    result = subprocess.run(
        [binary, "-m", gguf, "-f", prompt_file, "--embd-separator", SEP,
         "--embd-output-format", "json", "--embd-normalize", "2", "-b", "4096", "-ub", "4096"],
        capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"llama-embedding failed:\n{result.stderr[-2000:]}")
    data = json.loads(result.stdout)["data"]
    if len(data) != len(prompts):
        sys.exit(f"embedded {len(data)} of {len(prompts)} prompts — separator split mismatch")

    cosines = []
    for row, reference in zip(data, stored):
        emb = row["embedding"]
        dot = sum(a * b for a, b in zip(emb, reference))
        na = math.sqrt(sum(a * a for a in emb))
        nb = math.sqrt(sum(b * b for b in reference))
        cosines.append(dot / (na * nb))

    cosines_sorted = sorted(cosines)
    report = {
        "chunks": len(cosines),
        "perVolume": per_volume_counts,
        "min": cosines_sorted[0],
        "p1": cosines_sorted[len(cosines) // 100],
        "p50": cosines_sorted[len(cosines) // 2],
        "mean": sum(cosines) / len(cosines),
        "below_0995": sum(1 for c in cosines if c < 0.995),
        "gguf": os.path.basename(gguf),
        "llamaEmbedding": binary,
    }
    with open(out_path, "w") as handle:
        json.dump(report, handle, indent=1, sort_keys=True)
    print(json.dumps(report, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
