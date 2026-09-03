#!/usr/bin/env python3
"""FRUS corpus embedding harvest via LM Studio (owner-run).

Reads every manifest volume's TEI, extracts document body text, chunks it, embeds the
chunks through LM Studio's OpenAI-compatible /v1/embeddings endpoint, and writes a raw
store: per-volume text layer + chunk vectors + chunk metadata + provenance.

Stdlib only — no pip, no venv. Runs on the stock macOS python3 (Command Line Tools).
Resumable: a completed volume is skipped on re-run; an interrupted volume is redone.

    SPIKE=1 python3 harvest_embeddings.py            # V-0: three era-spread volumes
    caffeinate -i python3 harvest_embeddings.py       # full corpus (overnight)

Environment:
  LMSTUDIO_URL   default http://localhost:1234
  MODEL          LM Studio model id (else: auto-picked iff exactly one 'embed' model)
  MODEL_FILE     optional path to the GGUF file, to record its SHA-256 in provenance
  VOLUMES_DIR    default ~/frus-volumes  (a copy of Development/frus/volumes)
  MANIFEST       default ./manifest.json (copy it next to this script)
  OUT_DIR        default ~/frus-semantic-raw
  VOLUMES        comma-separated volume ids (overrides SPIKE / full corpus)
  SPIKE          =1 embeds frus1861, frus1938v01, frus1948v06 only
  PREFIX         text prepended to every chunk (nomic needs "search_document: ")
  BATCH          chunks per request, default 64
  CHUNK_CHARS    default 3200 (~800 tokens at the corpus's measured 4.16 chars/token)
  OVERLAP_CHARS  default 480 (~15%)
  ALLOW_CONTRACT_CHANGE  =1 lets a RESUME proceed under a contract that differs from the
                 store's run-manifest.json. Without it the run refuses (see below).
Contract guard (R-2 of the release plan):
  A resume embeds under whatever env THIS invocation has, and run-manifest.json is
  rewritten from it at the end with no comparison against the store's. So a resume that
  forgets PREFIX="title: none | text: " embeds the new volume under a different prompt,
  records prefix "" for the WHOLE store, packs cleanly under a new provenance digest, and
  costs every installed device a 162 MB re-fetch of shards that are now two prompts mixed.
  The store cannot catch it: head.json (before this change) recorded only model and dim.
  So the harvester now (a) refuses to resume when model / model_file_sha256 / prefix /
  chunk_chars / overlap_chars differ from the store's manifest and at least one volume is
  already complete, and (b) writes the contract into every new head.json so the packer can
  check it per volume from now on.

Design notes (why the store looks like this):
  * CHUNK vectors are stored, not document vectors. Pooling/normalisation/Matryoshka
    truncation are deterministic and happen in the downstream packer — so a pooling-rule
    change never costs a re-run of the expensive neural pass.
  * The text layer is written even though the corpus exists elsewhere: it pins exactly
    what was embedded, so embeddings and any later pass (NER) share one extraction.
  * Extraction boundary: character data inside <div type="document"> divs, truncated at
    the next <div or </body> — the truncation keeps a volume's back-of-book index out of
    its final document (frus1941-43's index alone is 347 KB).
"""

import gzip
import hashlib
import json
import os
import platform
import re
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request

# ---------------------------------------------------------------- configuration

URL = os.environ.get("LMSTUDIO_URL", "http://localhost:1234").rstrip("/")
VOLUMES_DIR = os.path.expanduser(os.environ.get("VOLUMES_DIR", "~/frus-volumes"))
MANIFEST = os.environ.get("MANIFEST", os.path.join(os.path.dirname(__file__) or ".", "manifest.json"))
OUT = os.path.expanduser(os.environ.get("OUT_DIR", "~/frus-semantic-raw"))
BATCH = int(os.environ.get("BATCH", "64"))
CHUNK_CHARS = int(os.environ.get("CHUNK_CHARS", "3200"))
OVERLAP_CHARS = int(os.environ.get("OVERLAP_CHARS", "480"))
PREFIX = os.environ.get("PREFIX", "")
SPIKE_VOLUMES = ["frus1861", "frus1938v01", "frus1948v06"]  # pre-1900 / interwar / Cold War

TAG = re.compile(r"<[^>]+>")
DOCSPLIT = re.compile(r'(?=<div\b[^>]*type="document")')
XMLID = re.compile(r'xml:id="([^"]+)"')


# ---------------------------------------------------------------- extraction

def extract_documents(xml_text):
    """[(doc_id, ordinal, normalised_text)] for every document div in one volume."""
    docs = []
    parts = DOCSPLIT.split(xml_text)[1:]
    for ordinal, segment in enumerate(parts):
        # Truncate at the next div (a wrapper or back-matter section that opened after
        # this document closed) or at </body>, whichever comes first. The leading tag of
        # THIS document is at position 0, so start the search after it.
        tag_end = segment.find(">")
        cut = len(segment)
        nxt = segment.find("<div", tag_end + 1)
        if nxt != -1:
            cut = min(cut, nxt)
        body_end = segment.find("</body>")
        if body_end != -1:
            cut = min(cut, body_end)
        did_match = XMLID.search(segment[:600])
        doc_id = did_match.group(1) if did_match else "ord%d" % ordinal
        text = " ".join(TAG.sub(" ", segment[:cut]).split())
        if text:
            docs.append((doc_id, ordinal, text))
    return docs


def chunk(text):
    """[(char_start, char_end)] windows over `text`, split at word boundaries."""
    if len(text) <= CHUNK_CHARS + OVERLAP_CHARS:
        return [(0, len(text))]
    spans = []
    start = 0
    while start < len(text):
        end = min(start + CHUNK_CHARS, len(text))
        if end < len(text):
            space = text.rfind(" ", start + CHUNK_CHARS // 2, end)
            if space != -1:
                end = space
        spans.append((start, end))
        if end >= len(text):
            break
        nxt = end - OVERLAP_CHARS
        space = text.find(" ", nxt)
        start = space + 1 if (space != -1 and space < end) else end
    return spans


# ---------------------------------------------------------------- LM Studio client

def http_json(method, path, payload=None, timeout=600):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(URL + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def pick_model():
    explicit = os.environ.get("MODEL", "")
    listing = http_json("GET", "/v1/models")
    ids = [m.get("id", "") for m in listing.get("data", [])]
    if explicit:
        # LM Studio routes an unknown id to whatever model is loaded (observed 2026-08-10:
        # a literal "<the nomic id from curl>" placeholder embedded a full spike), so an
        # unlisted id would "work" while writing a fictional model into every head.json.
        if ids and explicit not in ids:
            sys.exit("MODEL %r is not among the ids the server reports:\n  %s\n"
                     "Copy the id exactly from the list above." % (explicit, "\n  ".join(ids)))
        return explicit, listing
    embed_ids = [i for i in ids if "embed" in i.lower()]
    if len(embed_ids) == 1:
        return embed_ids[0], listing
    sys.exit("Set MODEL explicitly. Models the server reports:\n  " + "\n  ".join(ids or ["(none)"]))


def embed_batch(model, texts):
    delay = 5
    for attempt in range(4):
        try:
            resp = http_json("POST", "/v1/embeddings", {"model": model, "input": texts})
            rows = sorted(resp["data"], key=lambda r: r["index"])
            if len(rows) != len(texts):
                raise RuntimeError("expected %d embeddings, got %d" % (len(texts), len(rows)))
            return [r["embedding"] for r in rows]
        except (urllib.error.URLError, RuntimeError, KeyError, TimeoutError) as err:
            if attempt == 3:
                raise
            print("    retry after error: %s (waiting %ds)" % (err, delay))
            time.sleep(delay)
            delay *= 3


# ---------------------------------------------------------------- contract guard

# The fields a resume must not change. `dim` is deliberately absent: it is DERIVED from the
# model at the first embed, not chosen, so a model mismatch already covers it and a spurious
# dim refusal on a fresh store would block the first run.
CONTRACT_FIELDS = ("model", "model_file_sha256", "prefix", "chunk_chars", "overlap_chars")


def current_contract(model, model_file_sha):
    """This invocation's contract, in run-manifest.json's own field names and types."""
    return {"model": model, "model_file_sha256": model_file_sha, "prefix": PREFIX,
            "chunk_chars": CHUNK_CHARS, "overlap_chars": OVERLAP_CHARS}


def stored_contract(out_dir):
    """The store's recorded contract, or None when there is no run-manifest.json yet."""
    path = os.path.join(out_dir, "run-manifest.json")
    if not os.path.exists(path):
        return None
    try:
        return json.load(open(path))
    except ValueError:
        return None


def contract_mismatch(stored, current):
    """Fields whose value differs between the store's manifest and this run.

    Pure, so the selftest pins it directly. `model_file_sha256` is compared only when BOTH
    sides are real digests: the manifest records "not captured" when MODEL_FILE was unset,
    and a run that sets it for the first time is adding provenance, not changing it.
    """
    diffs = []
    for field in CONTRACT_FIELDS:
        old, new = stored.get(field), current.get(field)
        if field == "model_file_sha256" and ("not captured" in (old, new) or None in (old, new)):
            continue
        if old != new:
            diffs.append((field, old, new))
    return diffs


def refuse_if_contract_changed(out_dir, current, completed_count):
    """Exit non-zero when a RESUME would embed under a different contract than the store's.

    Only a resume is refused — a run-manifest.json left behind in a directory with no
    completed volume describes nothing this run will mix with. ALLOW_CONTRACT_CHANGE=1
    is the override, for the case where the operator really is starting a new family in
    an old directory and knows the packed digest will change.
    """
    if completed_count == 0:
        return
    stored = stored_contract(out_dir)
    if stored is None:
        return
    diffs = contract_mismatch(stored, current)
    if not diffs:
        return
    lines = ["REFUSING TO RESUME: this invocation's contract differs from the store's "
             "run-manifest.json, and %d volume(s) are already embedded under the old one."
             % completed_count]
    for field, old, new in diffs:
        lines.append("  %-18s store: %r\n  %-18s now:   %r" % (field, old, "", new))
    lines.append("Resuming would embed the remaining volumes under a different prompt or "
                 "chunking, then rewrite run-manifest.json for the WHOLE store, and the packed "
                 "artifact would carry a new provenance digest — costing every installed device "
                 "a full shard re-fetch (162 MB) of vectors that mix two contracts.")
    lines.append("Re-run the exact Phase-3 command line from README.md (every env var), or set "
                 "ALLOW_CONTRACT_CHANGE=1 if a new family in this directory is really intended.")
    if os.environ.get("ALLOW_CONTRACT_CHANGE") == "1":
        print("\n".join(lines).replace("REFUSING TO RESUME", "WARNING (ALLOW_CONTRACT_CHANGE=1)"))
        return
    sys.exit("\n".join(lines))


# ---------------------------------------------------------------- store

def volume_done(vol, dim_holder):
    head_path = os.path.join(OUT, "vectors", vol + ".head.json")
    bin_path = os.path.join(OUT, "vectors", vol + ".bin")
    if not (os.path.exists(head_path) and os.path.exists(bin_path)):
        return False
    try:
        head = json.load(open(head_path))
    except ValueError:
        return False
    ok = os.path.getsize(bin_path) == head["dim"] * 4 * head["chunks"]
    if ok and dim_holder[0] is None:
        dim_holder[0] = head["dim"]
    return ok


def harvest_volume(vol, model, dim_holder, stats):
    path = os.path.join(VOLUMES_DIR, vol + ".xml")
    if not os.path.exists(path):
        print("  !! missing from VOLUMES_DIR, skipped: %s" % vol)
        stats["missing"].append(vol)
        return
    started = time.time()
    xml_text = open(path, encoding="utf-8", errors="replace").read()
    docs = extract_documents(xml_text)

    chunks, meta = [], []
    for doc_id, ordinal, text in docs:
        for ci, (c0, c1) in enumerate(chunk(text)):
            chunks.append(PREFIX + text[c0:c1])
            meta.append({"d": doc_id, "o": ordinal, "ci": ci, "c0": c0, "c1": c1})

    vec_path = os.path.join(OUT, "vectors", vol + ".bin")
    with open(vec_path, "wb") as out:
        done = 0
        while done < len(chunks):
            batch = chunks[done:done + BATCH]
            for vector in embed_batch(model, batch):
                if dim_holder[0] is None:
                    dim_holder[0] = len(vector)
                elif len(vector) != dim_holder[0]:
                    sys.exit("dimension changed mid-run (%d -> %d) — model swapped?"
                             % (dim_holder[0], len(vector)))
                out.write(struct.pack("<%df" % len(vector), *vector))
            done += len(batch)

    with open(os.path.join(OUT, "vectors", vol + ".meta.jsonl"), "w") as out:
        for row in meta:
            out.write(json.dumps(row, separators=(",", ":")) + "\n")
    with gzip.open(os.path.join(OUT, "text", vol + ".jsonl.gz"), "wt", encoding="utf-8") as out:
        for doc_id, ordinal, text in docs:
            out.write(json.dumps({"d": doc_id, "o": ordinal, "t": text},
                                 separators=(",", ":"), ensure_ascii=False) + "\n")

    secs = time.time() - started
    chars = sum(len(t) for _, _, t in docs)
    # head.json is written LAST — its presence plus a size check is the done marker.
    # The contract rides in every head.json so the packer can check it PER VOLUME. Before
    # this only model and dim were recorded, which is why a prefix mismatch was undetectable
    # from the store side. Additive: the 552 existing heads lack these keys and stay valid.
    json.dump({"volume": vol, "model": model, "dim": dim_holder[0], "docs": len(docs),
               "chunks": len(chunks), "chars": chars, "secs": round(secs, 1),
               "prefix": PREFIX, "chunk_chars": CHUNK_CHARS, "overlap_chars": OVERLAP_CHARS},
              open(os.path.join(OUT, "vectors", vol + ".head.json"), "w"))
    with open(os.path.join(OUT, "runs.jsonl"), "a") as out:
        out.write(json.dumps({"vol": vol, "docs": len(docs), "chunks": len(chunks),
                              "chars": chars, "secs": round(secs, 1),
                              "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}) + "\n")
    stats["docs"] += len(docs)
    stats["chunks"] += len(chunks)
    stats["chars"] += chars
    stats["secs"] += secs
    return secs, chars, len(chunks)


# ---------------------------------------------------------------- provenance

def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def machine_description():
    try:
        model = subprocess.run(["sysctl", "-n", "hw.model"], capture_output=True,
                               text=True).stdout.strip()
        cpu = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                             capture_output=True, text=True).stdout.strip()
    except OSError:
        model, cpu = "", ""
    return {"node": platform.node(), "hw_model": model, "cpu": cpu,
            "arch": platform.machine(), "python": platform.python_version()}


def write_checksums():
    sums_path = os.path.join(OUT, "SHA256SUMS")
    with open(sums_path, "w") as out:
        for sub in ("text", "vectors"):
            folder = os.path.join(OUT, sub)
            for name in sorted(os.listdir(folder)):
                full = os.path.join(folder, name)
                out.write("%s  %s/%s\n" % (sha256(full), sub, name))
    return sums_path


# ---------------------------------------------------------------- main

def main():
    manifest = json.load(open(MANIFEST))
    entries = manifest["volumes"] if isinstance(manifest, dict) else manifest
    all_volumes = [v["volumeId"] for v in entries]

    if os.environ.get("VOLUMES"):
        volumes = [v.strip() for v in os.environ["VOLUMES"].split(",") if v.strip()]
    elif os.environ.get("SPIKE"):
        volumes = SPIKE_VOLUMES
    else:
        volumes = all_volumes

    for sub in ("text", "vectors"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)

    model, listing = pick_model()
    # Validate MODEL_FILE up front: it is hashed into run-manifest.json at the END of the
    # run, and a typo would otherwise surface only after the last volume embeds — on the
    # full harvest, hours later, killing the manifest and SHA256SUMS writes (2026-08-10).
    model_file = os.environ.get("MODEL_FILE", "")
    if model_file and not os.path.exists(model_file):
        sys.exit("MODEL_FILE does not exist: %s" % model_file)
    # Hashed NOW rather than only at the end: the contract guard below compares it, and this
    # is the one check that can tell an operator they loaded a DIFFERENT GGUF at the same
    # path — the packer verifies the manifest's digest is 64 hex, not that it is the same file.
    model_file_sha = sha256(model_file) if model_file else "not captured"
    print("LM Studio %s | model %s | %d volume(s) -> %s" % (URL, model, len(volumes), OUT))

    dim_holder = [None]
    stats = {"docs": 0, "chunks": 0, "chars": 0, "secs": 0.0, "missing": []}
    remaining_chars_estimate = None
    todo = [v for v in volumes if not volume_done(v, dim_holder)]
    print("%d already complete, %d to do" % (len(volumes) - len(todo), len(todo)))
    refuse_if_contract_changed(OUT, current_contract(model, model_file_sha),
                               completed_count=len(volumes) - len(todo))

    for index, vol in enumerate(todo):
        result = harvest_volume(vol, model, dim_holder, stats)
        if result is None:
            continue
        secs, chars, nchunks = result
        rate = stats["chars"] / stats["secs"] if stats["secs"] else 0
        # ETA from the manifest sizeBytes of unfinished volumes, scaled by the measured
        # chars-per-XML-byte ratio of what we have processed so far.
        if remaining_chars_estimate is None:
            size_by_vol = {v["volumeId"]: v.get("sizeBytes", 0) for v in entries}
            xml_done = sum(size_by_vol.get(v, 0) for v in todo[:index + 1])
            ratio = stats["chars"] / xml_done if xml_done else 0.41
            remaining_chars_estimate = ratio * sum(size_by_vol.get(v, 0) for v in todo[index + 1:])
        else:
            remaining_chars_estimate = max(0.0, remaining_chars_estimate - chars)
        eta_h = remaining_chars_estimate / rate / 3600 if rate else 0
        print("[%d/%d] %-22s %5d chunks  %6.1fs  %8.0f chars/s (~%.0f tok/s)  ETA %.1fh"
              % (index + 1, len(todo), vol, nchunks, secs, rate, rate / 4.16, eta_h))

    run_manifest = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "script_sha256": sha256(os.path.abspath(__file__)),
        "machine": machine_description(),
        "lmstudio_url": URL,
        "model": model,
        "models_listing": listing,
        "model_file_sha256": model_file_sha,
        "dim": dim_holder[0],
        "chunk_chars": CHUNK_CHARS, "overlap_chars": OVERLAP_CHARS,
        "prefix": PREFIX, "batch": BATCH,
        "volumes_requested": len(volumes), "volumes_missing": stats["missing"],
        "totals_this_run": {"docs": stats["docs"], "chunks": stats["chunks"],
                            "chars": stats["chars"], "embed_secs": round(stats["secs"], 1),
                            "est_tokens": int(stats["chars"] / 4.16)},
    }
    json.dump(run_manifest, open(os.path.join(OUT, "run-manifest.json"), "w"), indent=2)

    print("\nWriting SHA256SUMS (integrity for the Studio -> Air transfer)...")
    sums = write_checksums()
    print("Done. Store: %s\n  Verify after transfer with:  cd %s && shasum -a 256 -c SHA256SUMS"
          % (OUT, os.path.basename(OUT)))
    if stats["secs"]:
        print("This run: %s chunks, %.1f h embed time, ~%.0f tokens/s"
              % (stats["chunks"], stats["secs"] / 3600, stats["chars"] / 4.16 / stats["secs"]))


if __name__ == "__main__":
    main()
