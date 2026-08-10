# Semantic harvest runbook — LM Studio, owner-run

You run the model passes; Claude runs everything deterministic downstream. This file is the
complete recipe. The plan and cost model behind it: `Planning/M2-Semantic-Pipeline-Ride-Along.md`
(§6 documents this execution route).

The whole harvest is **two files** carried to the Studio — this script and `manifest.json` —
plus a copy of the volumes folder. Python needs no packages: the script is stdlib-only and runs
on the macOS-bundled `python3`.

---

## Phase 0 — one-time setup on the Mac Studio (~15 min)

1. **Install LM Studio** (lmstudio.ai), open it once, and in Settings enable the **Developer**
   options so the local server tab appears. Optionally enable the `lms` CLI when prompted.
2. **Download the spike models** — paste each Hugging Face repo name below into LM Studio's
   in-app search (it searches HF directly; confirm each shows the *Embedding* tag). Download
   the **F16 or Q8_0** file where offered; do not use Q4 for embeddings. The one exception is
   a **QAT** release: quantization-aware trained, so its quantized file *is* the intended
   artifact.
   - `lmstudio-community/embeddinggemma-300m-qat-GGUF` *(primary candidate; QAT release)*
   - `nomic-ai/nomic-embed-text-v1.5-GGUF`
   - `CompendiumLabs/bge-small-en-v1.5-gguf` *(control)*
   - `fisher046/snowflake-arctic-embed-l-v2.0-Q8_0-GGUF` — note this is arctic-embed
     **l-v2.0** (~568 M params, still Apache-2.0), not the 109 M `m-v1.5` the plan's cost
     tables price. Expect the slowest spike pass of the four, and a full run roughly 2× the
     300 M primary's hours if it wins the gates — the spike measures the real number.
3. **Copy the inputs over** (AirDrop or an SSD):
   - `Development/frus/volumes/` → `~/frus-volumes` on the Studio (3.34 GB)
   - this folder's `harvest_embeddings.py` + a copy of
     `FRUSExplorer/Resources/manifest.json` → anywhere, e.g. `~/semantic-harvest/`
4. **Check python3**: run `python3 --version` in Terminal. If macOS offers to install the
   Command Line Tools, accept and wait — that is the only install.

## Phase 1 — the V-0 spike (both machines, ~15–60 min each)

Run once per model, on **both** the Studio and the Air — the printed tokens/s is the number that
replaces every hardware guess in the plan.

1. In LM Studio, load the model (server tab → load; set **context length 2048**; confirm the
   model is tagged *embedding*). Start the server (default port 1234). One caveat: bge-small's
   architectural max is **512 tokens** — LM Studio clamps the context there, and the harvester's
   ~800-token chunks exceed it, so the control model may silently truncate or refuse batches.
   If its spike run errors out, rerun the control only with
   `CHUNK_CHARS=1800 OVERLAP_CHARS=270` (~433 tokens, same 15% overlap) and note it in the
   hand-off — a truncated or re-chunked control is a caveat on the comparison, not a bug.
2. In Terminal:

   ```
   cd ~/semantic-harvest
   SPIKE=1 OUT_DIR=~/frus-semantic-raw-spike-<model> python3 harvest_embeddings.py
   ```

   Two of the four carry a documented **document-side prompt**. The prefix is part of the
   vector contract and is recorded in provenance (`run-manifest.json`'s `prefix`), so whichever
   choice embeds the spike must also embed the full run:
   - **nomic** (required): `PREFIX="search_document: "`
   - **embeddinggemma** (per its model card's retrieval-document prompt; trailing space
     included): `PREFIX="title: none | text: "` — verify the string against the model card at
     spike time before relying on it.
   bge-small and arctic embed documents bare (their prefixes are query-side only).
3. Note the closing line (`~N tokens/s`). Eject the model, load the next, repeat with a fresh
   `OUT_DIR`.

Spike output per model is ~40 MB. Keying nothing, deciding nothing — this measures.

## Phase 2 — send Claude the spike

Bring every `frus-semantic-raw-spike-*` folder (both machines') to the Air and tell Claude the
paths. Claude then: validates the stores, runs the weak-positive gate (cross-reference
neighbors, MRR@10 per model per era) against the live index, stages the blind-panel CSV for you,
and computes the quantization ladder — the V-0 verdict comes back as numbers, and the full-run
model is chosen from them, not from leaderboards.

## Phase 3 — the full harvest (Studio, overnight)

With the chosen model loaded (context 2048, server running):

```
cd ~/semantic-harvest
caffeinate -i python3 harvest_embeddings.py 2>&1 | tee harvest.log
```

- `caffeinate -i` keeps the Studio awake; closing the Terminal window kills the run, so leave it
  open (or prefix with `nohup` and background it).
- **Interruptions are fine.** Re-running the same command skips every completed volume and redoes
  only the one that was in flight.
- Expected: ~8–13 h for the 300M model (the spike will have tightened this), ~2 GB of output in
  `~/frus-semantic-raw`, and a live ETA on every progress line.
- If a batch fails repeatedly the script stops with the error — usually the server unloaded the
  model or the Mac slept. Fix, re-run, it resumes.

## Phase 4 — transfer Studio → Air

Either:

- **SSD / AirDrop**: copy `~/frus-semantic-raw` (≈2 GB) to the Air at
  `~/Development/frus-semantic-raw`, **or**
- **rsync over the network**: on the Air enable System Settings → Sharing → **Remote Login**,
  then on the Studio:

  ```
  rsync -av --progress ~/frus-semantic-raw/ jbotts@<air-name>.local:Development/frus-semantic-raw/
  ```

Then verify on the Air — this is the step that makes the transfer trustworthy:

```
cd ~/Development/frus-semantic-raw && shasum -a 256 -c SHA256SUMS
```

Every line must say `OK`. Also bring `harvest.log`.

## Phase 5 — hand off

Tell Claude: *"the raw store is at ~/Development/frus-semantic-raw, checksums verified"*. From
there Claude owns: store validation, deterministic pooling to document vectors, L2/Matryoshka
truncation, quantization, the `SemanticVectorsGenerator` packer with artifact tests, and the
scoring gates. A pooling-rule change never costs you a re-run — the store keeps chunk vectors
precisely so the deterministic side can be redone freely.

## What this store contains (the contract)

```
frus-semantic-raw/
  text/<vol>.jsonl.gz       # the R-0 layer: {"d": docId, "o": ordinal, "t": text} per document
  vectors/<vol>.bin         # float32-LE chunk vectors, meta order
  vectors/<vol>.meta.jsonl  # {"d","o","ci","c0","c1"} per chunk — pooling is derived from this
  vectors/<vol>.head.json   # done-marker: model, dim, counts, seconds (written last)
  runs.jsonl                # per-volume timing log (append-only across resumes)
  run-manifest.json         # provenance: model id + listing, GGUF SHA (if MODEL_FILE set),
                            # chunk/prefix/batch params, machine, script SHA, totals
  SHA256SUMS                # transfer integrity
```

To record the model file's SHA in provenance (worth doing for the full run): in LM Studio's
My Models list, reveal the GGUF in Finder, then run the harvest with
`MODEL_FILE="/path/to/model.gguf"`.

## Later phases (not yet — after V-0)

The NER pass (R-1) and the adversarial-review tier get their own harnesses in this folder once
the spike numbers and the M2a ground-truth sample exist. Note for planning: GLiNER and spaCy do
not run in LM Studio — the LM-Studio-native detection route is structured-output chat NER, which
is priced sample-first in the plan; the NLTagger control pass runs on the Air inside the repo and
needs nothing from this runbook.
