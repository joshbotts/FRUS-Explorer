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
   - `lmstudio-community/embeddinggemma-300m-qat-GGUF` *(primary candidate; QAT release —
     its Q4_0 is the intended file. Header verified 2026-08-10: `add_eos_token=true`; the
     SEP warning it logs on every embed request is SPURIOUS — see Field notes)*
   - `nomic-ai/nomic-embed-text-v1.5-GGUF` — **trap, measured 2026-08-10:** LM Studio ships
     its own bundled Q4_K_M nomic under `~/.lmstudio/.internal/bundled-models/`, and the
     in-app search will surface it instead of downloading, which is how the first Studio
     spike silently ran on the forbidden quant. Verify a file actually appears under
     `~/.lmstudio/models/nomic-ai/`; with both copies present the server disambiguates the
     ids as `...@q8_0` / `...@q4_k_m` — harvest with `@q8_0`.
   - `CompendiumLabs/bge-small-en-v1.5-gguf` *(control)*
   - `fisher046/snowflake-arctic-embed-l-v2.0-Q8_0-GGUF` — note this is arctic-embed
     **l-v2.0** (~568 M params, still Apache-2.0), not the 109 M `m-v1.5` the plan's cost
     tables price. Measured on the M1 Max Studio: ~6.8 k tokens/s -> a **~15–16 h full run**
     if it wins the gates. Header verified clean (`add_eos_token=true` with eos == sep, so
     the SEP warning structurally cannot fire on it).
3. **Copy the inputs over** (AirDrop or an SSD):
   - `Development/frus/volumes/` → `~/frus-volumes` on the Studio (3.34 GB)
   - this folder's `harvest_embeddings.py` + a copy of
     `FRUSExplorer/Resources/manifest.json` → anywhere, e.g. `~/semantic-harvest/`
4. **Check python3**: run `python3 --version` in Terminal. If macOS offers to install the
   Command Line Tools, accept and wait — that is the only install.

## Phase 1 — the V-0 spike (Studio only, ~15–60 min per model)

Run once per model, on the Studio. (Owner decision 2026-08-10: the spike does NOT run on the
Air — Phase 1 completed Studio-only, so the plan's Air-side question, whether the M5's
accelerators engage for encoder inference, deliberately stays unmeasured until some later
pass actually needs the Air. The printed tokens/s replaces the plan's Studio-side hardware
guesses.)

1. In LM Studio, load ONE model at a time (server tab → load; set **context length 2048**;
   confirm the *embedding* tag). Start the server (default port 1234). Pass `MODEL=`
   explicitly on every run: with several embedding models downloaded every id contains
   "embed", so the harvester's auto-pick always refuses. Copy ids exactly from
   `curl -s localhost:1234/v1/models` — the harvester exits on an id the server does not
   list, because LM Studio routes an unknown id to whatever model is loaded, which "works"
   while writing a fictional model into every head.json (measured: a literal placeholder
   string embedded a full spike). bge caveat, also measured: its architectural max is
   **512 tokens** and the ~800-token chunks are REFUSED, so run the control with
   `CHUNK_CHARS=1800 OVERLAP_CHARS=270` (~433 tokens, same 15% overlap) — the re-chunk is
   pinned in that store's run-manifest and is a caveat on the comparison, not a bug.
2. In Terminal:

   ```
   cd ~/semantic-harvest
   SPIKE=1 MODEL="<id from /v1/models>" MODEL_FILE="/path/to/the/loaded.gguf" \
     OUT_DIR=~/frus-semantic-raw-spike-<model> python3 harvest_embeddings.py
   ```

   `MODEL_FILE` pins the GGUF's SHA-256 into provenance (My Models → reveal in Finder →
   drag the file into Terminal). The harvester validates the path at startup precisely
   because it is consumed at the END of the run — a typo there once cost a finished spike
   its manifest and checksums.

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

Bring the Studio's `frus-semantic-raw-spike-*` folders (five of them — see Field notes) to
the Air and tell Claude the paths. Claude then: validates the stores, runs the weak-positive gate (cross-reference
neighbors, MRR@10 per model per era) against the live index, stages the blind-panel CSV for you,
and computes the quantization ladder — the V-0 verdict comes back as numbers, and the full-run
model is chosen from them, not from leaderboards.

**Executed 2026-08-10** by `spike_gates.py` (the Air-side analysis half — needs numpy,
unlike the Studio scripts). Verdict and all numbers:
`Planning/semantic-spike/V0-Spike-Verdict.md`; machine copy `spike-gates.json` beside it.
Headlines: gemma leads the weak-positive gate on every statistic in both measurable eras
(frus1861 has **zero** cross-ref edges — the blind panel is the only pre-1900 gate);
int8 + Hamming-rerank are measured-free while the 768→256 Matryoshka cut costs 23% of
gemma's exact top-10 (512 halves that at double the Tier-2 budget); the accidental
Q4_K_M nomic agrees with its Q8_0 twin on only 82% of rank-1 neighbors — the no-Q4 rule,
measured. **Owner's move before Phase 3:** grade all 100 rows of
`Planning/semantic-spike/blind-panel.csv` (good / moderate / garbage — *would a historian
want this?*) **before** opening `blind-panel-key.csv`, which would unblind you; and read
the Gemma licence (binds V-5 weight-bundling only, not the harvest).

## Phase 3 — the full harvest (Studio, overnight)

**Owner decision 2026-08-10: the full run is gemma** (`text-embedding-embeddinggemma-300m-qat`),
on the Phase 2 numbers. With that model loaded (context 2048, server running), the full
command — every env var matters:

```
cd ~/semantic-harvest
MODEL="text-embedding-embeddinggemma-300m-qat" \
MODEL_FILE="/path/to/the/loaded/embeddinggemma...q4_0.gguf" \
PREFIX="title: none | text: " \
caffeinate -i python3 harvest_embeddings.py 2>&1 | tee harvest.log
```

- **`PREFIX` is not optional.** The spike embedded every chunk under
  `title: none | text: ` (trailing space included) and the Phase 2 gates validated THAT
  configuration; a run without it produces vectors from a different contract and no error.
  The same goes for a resume: re-run the exact same command line (`tee -a` to keep the
  earlier log), because a resumed volume embeds under whatever env the new invocation has.
- **`MODEL_FILE` is not optional this time**: the spike captured a GGUF SHA only for
  nomic-q8; the full run's provenance must not repeat that gap. (My Models → reveal in
  Finder → drag the file into Terminal.)
- Copy the model id exactly from `curl -s localhost:1234/v1/models` — the harvester
  refuses unlisted ids by design.
- Measured extrapolation for gemma: **~6.1 h**; the ETA on each progress line corrects
  this within the first hour. Expect the SEP warning in LM Studio's log on every batch —
  known-spurious on the QAT gemma (see Field notes).

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

## Field notes — Studio spike, 2026-08-10

- **The gemma SEP warning is noise.** Every embed request against the QAT gemma logs "at
  least one last token … is not SEP / 'tokenizer.ggml.add_eos_token' should be set to
  'true'". The header already says true, the flag IS consumed (same-weights A/B via
  `gguf_eos_flag.py` set-false on a copy + `check_eos_effect.py` Mode 2: cosine ~0.98
  between flag states), and the warning fires identically under BOTH states — a BERT-era
  SEP check that a SEP-less Gemma vocabulary can never satisfy. Learned the hard way in
  the same session: llama.cpp reads the header at LOAD time, so a flipped file probed
  without ejecting and reloading returns cosine 1.000000 against the stale in-memory
  flag and looks exactly like "flag ignored".
- **Terminal-token sensitivity is real:** with-vs-without-EOS moves embeddinggemma's
  vectors to ~0.98 cosine — a larger effect than appending literal junk text (~0.994).
  A wrong header here would have been a genuine defect; it just was not wrong.
- **Header census** (`gguf_eos_flag.py show` over all four GGUFs): gemma true; arctic
  true with eos == sep, so the warning cannot fire on it; bge and nomic ABSENT — the
  BERT-family default framing applies, confirmed by the absence of warnings on their
  runs.
- **Throughputs, M1 Max Studio** (closing lines; per-volume detail in each store's
  `runs.jsonl`): bge ~24.1 k tok/s (re-chunked control), nomic Q4_K_M ~17.4 k, nomic
  Q8_0 ~19.2 k (the correct quant is also the faster one — K-quant dequantisation costs
  more than Q8_0), arctic ~6.8 k; gemma's is in its `run-manifest.json`. The small
  models are overhead-bound, not compute-bound — 33 M bge is nowhere near 4× faster
  than 137 M nomic.
- The Studio pass closed with **five stores**, not four: the accidental bundled-Q4_K_M
  nomic store was kept beside the Q8_0 re-run — same chunks, same prefix, one quant tier
  apart — as a free rung of the Phase 2 quantization ladder.

## Later phases (not yet — after V-0)

The NER pass (R-1) and the adversarial-review tier get their own harnesses in this folder once
the spike numbers and the M2a ground-truth sample exist. Note for planning: GLiNER and spaCy do
not run in LM Studio — the LM-Studio-native detection route is structured-output chat NER, which
is priced sample-first in the plan; the NLTagger control pass runs on the Air inside the repo and
needs nothing from this runbook.
