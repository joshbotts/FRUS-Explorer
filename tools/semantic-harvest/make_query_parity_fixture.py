#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Generate the QUERY parity fixture the in-app encoder is accepted against (V-5 s2).

Embeds the owner's evaluation queries under the pinned QUERY prompt through a
llama-embedding build at the spiked commit, and writes the 768-d reference vectors as a
committed JSON fixture. The in-app `LlamaQueryEncoder` must reproduce these vectors —
same engine, same weights — so the gate is tight (>=0.9999 cosine): a miss is a wrapper
bug (wrong pooling, missing normalize, wrong prompt, tokenizer misuse), never model
drift. Cross-engine parity (LM Studio, the vectors the judged sitting used) is already
established by the step-4 spike at min cosine 0.9999984 over 300 corpus chunks.

Query lines follow the harness grammar: a line's tag is split off at three-spaces-hash
("   #"); '#'-prefixed lines are comments. The prompt prefix is the query template the
sitting judged: "task: search result | query: ".

Stdlib only, macOS bundled python3 — the tools/semantic-harvest contract.

Env:
  LLAMA_EMBEDDING  path to the llama-embedding binary (required)
  GGUF             path to the pinned GGUF (required; SHA-verify it yourself first)
  QUERIES          the owner query file (default Planning/semantic-vectors/owner-eval-queries-2026-08-27.txt)
  OUT              fixture path (default FRUSExplorerTests/Fixtures/query-parity-fixture.json)
"""
from __future__ import annotations
import hashlib, json, os, subprocess, sys, tempfile

QUERY_PREFIX = "task: search result | query: "
SEP = "<#frus-sep#>"


def parse_queries(path: str) -> list[str]:
    out = []
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\r\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        out.append(line.split("   #", 1)[0].rstrip())
    return out


def main() -> int:
    binary = os.environ.get("LLAMA_EMBEDDING")
    gguf = os.environ.get("GGUF")
    if not binary or not gguf:
        sys.exit("Set LLAMA_EMBEDDING and GGUF.")
    queries_path = os.environ.get(
        "QUERIES", "Planning/semantic-vectors/owner-eval-queries-2026-08-27.txt")
    out_path = os.environ.get("OUT", "FRUSExplorerTests/Fixtures/query-parity-fixture.json")

    queries = parse_queries(queries_path)
    if not queries:
        sys.exit(f"no queries parsed from {queries_path}")
    prompts = []
    for query in queries:
        assert SEP not in query
        prompts.append((QUERY_PREFIX + query).replace("\n", " "))

    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(SEP.join(prompts))
        prompt_file = handle.name

    result = subprocess.run(
        [binary, "-m", gguf, "-f", prompt_file, "--embd-separator", SEP,
         "--embd-output-format", "json", "--embd-normalize", "2"],
        capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"llama-embedding failed:\n{result.stderr[-2000:]}")
    data = json.loads(result.stdout)["data"]
    if len(data) != len(prompts):
        sys.exit(f"embedded {len(data)} of {len(prompts)} prompts — separator split mismatch")

    gguf_sha = hashlib.sha256(open(gguf, "rb").read()).hexdigest()
    fixture = {
        "queryPrefix": QUERY_PREFIX,
        "ggufSHA256": gguf_sha,
        "referenceEngine": "llama-embedding (llama.cpp 8663224), default flags, --embd-normalize 2",
        "queries": [
            {"text": query, "vector": row["embedding"]}
            for query, row in zip(queries, data)
        ],
    }
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as handle:
        json.dump(fixture, handle, indent=None, sort_keys=True)
    dims = {len(q["vector"]) for q in fixture["queries"]}
    print(f"wrote {out_path}: {len(queries)} queries, dims={sorted(dims)}, gguf sha {gguf_sha[:12]}…")
    if dims != {768}:
        sys.exit("FATAL: expected 768-d reference vectors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
