# M2 riding the semantic-vectors pipeline — assessment, plan, and generation cost

**Status:** planning, unbuilt. Answers the owner's 2026-08-07 question: *can M2 (early-era person
detection, `Planning/People-Early-Era-Program.md`) ride along the vector-embeddings work scoped in
`Planning/Vector-Embeddings-Semantic-Design.md`?*
**Verdict: yes — they share a corpus pass, a pipeline discipline, a hardware window, and one
genuinely load-bearing model reuse. They must NOT share verdicts or gates.** The seam is drawn in
§2.
**Date:** 2026-08-07. Every number is measured in this repo or derived with the assumption stated
beside it; the two unverified hardware claims are marked **[U]** and are exactly what the V-0
spike resolves.

---

## 1. Why the two programs meet

Both are offline, owner-executed passes over the same input: the body text of every document in
the corpus.

- The embeddings Stage 1 (design doc §3.1) chunks each document's body text, embeds, pools, and
  writes a raw vector store.
- M2 runs NER over the same body text — the M1a survey measured that only **~34% of person
  mentions in the 268 no-list volumes carry `<persName>` markup** (12–31% in the 1946– band), so
  detection over running prose is required, not optional
  (`Planning/early-era-people/M1a-Findings.md`).

Today those would be two separately-built corpus sweeps with two text extractors, two run
manifests, and two cache layouts. Built together they are one extraction, two consumers.

**Corpus arithmetic, measured 2026-08-07** (tag-stripped character data inside
`<div type="document">`, all 552 manifest volumes — the same extraction boundary the design doc's
Stage 1 uses):

| Quantity | Value |
|---|---|
| document divs | 314,483 |
| body text | 1.374 B chars / 229.2 M words |
| **est. BPE tokens** | **~310–344 M** (chars/4 and words×1.35 bracket it; call ~330 M) |
| embedded tokens after 15% chunk overlap | **~380 M** |
| chunks at ~800 tokens | **~475 k** |
| M2 scope (268 no-list volumes) | 705 M chars ≈ **~176 M tokens** (51.3%) |

Two design-doc guesses this measurement corrects: the chunk estimate (~475 k, not 600 k–1 M), and
the §3.3 wall-clock band — see §4.1, where the "1–6 hour" figure survives only for the ≤137 M
fallback models, not the 300 M primary.

---

## 2. The seam: what rides, what must not

### Rides

1. **R-0 — a shared extracted-text layer** (the one design amendment this doc asks for). Stage 1
   currently goes TEI → chunks → vectors in one motion. Split the first step out: write each
   volume's extracted body text to the raw store (`.cache/semantic-vectors/text/`, one file per
   volume, ~1.4 GB) *before* chunking, with the extraction pinned in the run manifest. Embeddings
   chunk from it; NER reads it; any future pass (RAG passages, §7.6 of the design doc) reads it.
   One extraction, audited once. Without this, the two programs each re-derive "what is the body
   text of document N" and can silently disagree — the cross-source-join failure class this repo
   keeps re-learning (`BundledKeynessBaseline`, the `corresp`-vs-`ref` slip in this very program).
2. **The pipeline discipline, verbatim.** `tools/semantic-vectors/` (uv-managed, lockfile-pinned)
   gains a sibling `tools/early-era-ner/` sharing the same idioms: raw outputs under `.cache/`
   treated as an expensive harvest, run manifest recording model SHA + params + library versions,
   deterministic Swift packer with artifact tests for anything that ships.
3. **The hardware window.** Both are overnight-band jobs (§4). Sequential on the Studio they are
   one weekend; in parallel — embed on the Studio, NER on the Air — one calendar night.
4. **Mention-context embeddings as a reconciliation signal** — the load-bearing reuse, not just
   logistics. M2's hard half is not finding "Marshall"; it is deciding *which* Marshall. The same
   embedding model, same env, same raw store can embed a context window around each detected
   mention, giving identity clustering a semantic feature alongside POCOM's year constraint
   (measured in M1a: 83.2% of from/to surnames known, 63.9% unique-by-year — strong but
   surname-only). Same-context mentions cluster; a foreign minister and a US ambassador sharing a
   surname separate. Cost: ~1 context window per detected mention ≈ a second, smaller embedding
   pass (§4.3). This also makes §7.7 of the design doc (person-trajectory embeddings) a free
   descendant.
5. **The eval-staging machinery.** `Planning/early-era-people/m1a_survey.py`'s stratified sampling
   extends unchanged to stage the M2a prose ground truth (§3, step 0).

### Does not ride

1. **The gates.** M1a's 300-row from/to eval is **still un-keyed**; M2 needs its own
   prose-mention ground truth (M2a below). The standing rule — no extraction *ships* before
   ground truth — is unchanged. Running the NER pass to *produce candidates* is harvest, not
   shipping, and is fine; nothing derived from it enters an artifact until measured.
2. **V-0's kill criteria stay embedding-only.** If no model clears the design doc's pre-1900
   cosine gate, the *semantic axis* dies or ships era-scoped — but that verdict says nothing
   about NER precision, which M2a measures independently. Shared infrastructure, separate fates.
   The converse also holds: an M2 failure must not take the embeddings down.
3. **The adversarial review** — its own batch program, the only real dollar line (§4.4), sized
   only after detection counts exist.
4. **App-side artifacts.** M2's output flows into the person-authority / rollup machinery
   (synthetic-ref namespace, force-merge-only — the archived wave plan's rules), not into the
   vector tiers. No coupling of shipping artifacts.

---

## 3. The combined pipeline

Stages named to compose with the design doc's V-phases:

| Stage | What | Depends on |
|---|---|---|
| **V-0** | The design doc's spike, unchanged — 3 volumes × 3 models, quality gates, quantization ladder. **Run it on both machines** (§4.5: ~5 M tokens ≈ minutes each) — it doubles as the throughput measurement that collapses every [U] in §4. | corpus on both machines |
| **M2a** | Prose ground truth: extend `m1a_survey.py` to sample ~60–80 documents, era-stratified, for **exhaustive** person-mention annotation (~900–1,200 mention decisions). Owner keys it alongside the M1a 300. Nothing downstream is measurable without it. | — (parallel with V-0) |
| **V-1 + R-0** | Stage-1 build with the extracted-text layer split out; full-corpus embed on the Studio. | V-0 |
| **R-1** | NER pass over the no-list volumes from the R-0 text layer. Candidates: Apple `NLTagger` (near-free control — the app already runs it corpus-wide in ~1 h for word clouds), spaCy `en_core_web_trf`, GLiNER-medium. All three scored against M2a; 19th-century diplomatic prose is far from every NER model's training distribution and the winner is an empirical question. | R-0, M2a |
| **R-2** | Mention-context embedding pass over R-1's detections (the reconciliation signal). | V-1, R-1 |
| **R-3** | Identity clustering: POCOM year-constraint + context-vector + surname blocking, scored against M2a; then the adversarial-review tier over the uncertain band (§4.4). | R-2, M1a keyed |
| **R-4** | Artifacts: derived person entries in the synthetic-ref namespace, provenance-marked (M3's UI rules). Gated on R-3's measured precision. | R-3 |

Sequencing constraint carried from the design doc unchanged: the #645 truncation fixes and the
archival route arms land before any *axis* ships. They do not gate the harvest stages above.

**Execution route (2026-08-07 owner decision): the model passes run through LM Studio,
owner-operated — see §5.** The stage table above is unchanged; §5 replaces *who runs Stage 1 and
with what runner*, not what gets produced.

---

## 4. Generation cost on the two machines

### 4.0 The machines

| | **M1 Max Mac Studio** | **M5 MacBook Air (2026)** |
|---|---|---|
| CPU | 10-core (8P+2E) | 10-core (4P+6E) |
| GPU | 24- or 32-core, ~10.4 TFLOPS fp32 / ~21 fp16 (32-core) | 8- or 10-core + **Neural Accelerator per core**; Apple claims >4× M4 peak GPU AI compute |
| Memory bandwidth | 400 GB/s | 153 GB/s |
| Cooling | active — sustains indefinitely | **fanless — throttles on multi-hour loads** |
| RAM floor | 32 GB | 16 GB |

Batched encoder inference is compute-bound (the 0.6 GB of weights amortise across the batch), so
the Air's bandwidth deficit matters less than its two real handicaps: sustained thermals, and
whether the ML stack actually drives the Neural Accelerators for encoder-class models — MLX
support for M5's accelerators exists for LLM workloads, but encoder utilisation is **[U]**.
If the accelerators engage, the Air is roughly at parity with the Studio; if the pass falls back
to plain GPU shaders, it runs ~1.5–2× slower. That software question, not silicon, is the
dominant uncertainty below — and V-0 on both machines answers it for a few cents.

Effective-throughput assumptions (stated so the tables can be re-derived): Studio 32-core ≈
**5–8 TFLOPS** sustained fp16-effective (25–40% MFU of ~21 peak; a 24-core Studio is ~1.3×
slower); Air 10-core-GPU ≈ **2.5–8 TFLOPS** sustained (accelerator-dependent, throttle included;
the 8-core config ~1.25× slower). Encoder forward cost ≈ 2 × params FLOPs/token.

### 4.1 The embedding pass (V-1: ~380 M tokens)

| Model | FLOPs | **M1 Max Studio** | **M5 MacBook Air** |
|---|---|---|---|
| **EmbeddingGemma-300M** (primary) | 2.3 × 10¹⁷ | **~8–13 h** | **~8–26 h** |
| arctic-embed-m 109M (fallback) | 8.3 × 10¹⁶ | ~3–5 h | ~3–9 h |
| nomic-embed 137M | 1.0 × 10¹⁷ | ~4–6 h | ~4–12 h |
| Qwen3-Embedding-0.6B | 4.6 × 10¹⁷ | ~16–26 h | ~16–50 h |
| bge-small 33M (control) | 2.5 × 10¹⁶ | ~1–1.5 h | ~1–3 h |

**Correction to the design doc's §3.3:** its "1–6 hour band [U]" implies 80–400 k tokens/s, which
is 49+ TFLOPS effective for the 300 M primary — not achievable on either machine. The band holds
only for the ≤137 M fallbacks. The honest headline for the primary candidate is **an overnight
run on the Studio (~8–13 h) and an overnight-to-a-day-plus run on the Air**. Still firmly the
"owner-executed once" tier; nothing about the design's economics changes.

PCA→UMAP→HDBSCAN over 317 k × 256-d: tens of minutes on either machine's CPU cores; not a factor.

### 4.2 The NER pass (R-1: ~176 M tokens, no-list volumes only)

| Detector | **M1 Max Studio** | **M5 MacBook Air** | Note |
|---|---|---|---|
| Apple `NLTagger` (CPU) | **~1–2 h** | ~1.5–3 h | Near-free control; quality on 19th-c prose unmeasured — that is what M2a is for |
| spaCy `en_core_web_trf` (125 M) | ~3–6 h | ~3–9 h | |
| GLiNER-medium (~205 M, span scoring ≈ 2× encoder cost) | **~5–9 h** | ~5–16 h | Zero-shot labels fit the domain-shift problem best |

Corpus-wide instead of scope-only (for uniformity of the artifact): ×1.9 on every row.

### 4.3 The mention-context pass (R-2)

M1a measured 253,919 marked mentions in scope at ~34% markup share → total mentions plausibly
**~750 k**, of which ~500 k are unmarked (R-1's new detections). One ~256-token context window per
mention ≈ 190 M tokens through the same encoder — **roughly half the cost of a §4.1 row**: ~4–7 h
Studio on the 300 M model, ~1.5–2.5 h on the 109 M fallback.

### 4.4 The adversarial review (R-3's uncertain band) — the only dollar line

Local LLM review of every candidate does not fit the hardware: ~500 k candidates × ~700 tokens ≈
350 M tokens through an 8B-class model at the Studio's ~350–600 tok/s ≈ **7–12 days continuous**
— tier it instead:

- **Auto-accept** the band where POCOM-unique-by-year + context-vector agreement clears the
  M2a-measured precision bar; **auto-reject** clear negatives.
- **LLM-review only the uncertain middle.** At an assumed 20–30% (~100–150 k candidates): local
  8B ≈ 2–4 days Studio background, or an API batch at Haiku-class pricing ≈ **$45–90** (Sonnet-
  class ≈ 3×). Full-population review, if ever wanted: ~$220–440 batch.
- Sized properly only after R-1 counts and M2a precision exist; committed accept/reject artifacts
  per the archived plan's rules.

### 4.5 The literal price

Electricity (the only cash cost of the local passes):

| | draw under load | full program (embed + NER + context ≈ 15–25 h) | cost @ $0.15–0.25/kWh |
|---|---|---|---|
| M1 Max Studio | ~90–120 W wall | ~1.8–3.0 kWh | **~$0.30–0.75** |
| M5 Air | ~25–40 W wall | ~0.6–1.2 kWh | **~$0.10–0.30** |

The V-0 spike on both machines (~5 M tokens × 3 models) is minutes and pennies each.

For contrast, embedding ~380 M tokens through a hosted API would run ~$8 (OpenAI 3-small) to
~$50–60 (3-large / Gemini-class) — but the API route is not actually eligible: the design's
requirements (pinned model SHA, a future on-device query encoder embedding into the *same*
space) rule it out. The comparison only shows the local pass is also the cheap option.

**The real price is not electricity.** It is: (1) wall-clock and machine occupancy — the Studio
is the right primary because it sustains indefinitely and is not the travel machine; the Air's
best roles are the V-0 spike and the parallel NER pass; (2) **owner keying time**, the scarce
resource this program actually competes for: the M1a 300 rows (~2–3 h) plus the M2a exhaustive
sample (~3–5 h). Those two sittings gate everything; no machine makes them faster.

### Recommendation

Run **V-0 on both machines** first — it converts every [U] above into a measurement for a few
cents. Then: full embed on the **Studio** (primary model, overnight), NER on the **Air** the same
night, mention-context pass on the Studio the following evening. Total: **one weekend of machine
time, under a dollar of electricity, and two owner keying sittings** — after which every
downstream decision (model choice, detector choice, review-tier sizing) is made from measured
numbers.

---

## 5. Execution route: LM Studio, owner-run (decided 2026-08-07)

The owner runs the model passes through **LM Studio** on their own machines and hands the raw
store back; Claude runs everything deterministic downstream. Full recipe:
**`tools/semantic-harvest/README.md`**, driven by the committed, stdlib-only
`tools/semantic-harvest/harvest_embeddings.py` (no pip, no venv — it runs on the macOS-bundled
`python3`, which is what makes the Studio setup a 15-minute job). The script is resumable per
volume, records provenance and per-volume timings, and was verified end-to-end against a mock
`/v1/embeddings` server before being handed over (312 docs → 586 chunks on `frus1861`; spans
tile; resume skips; checksums verify).

What changes relative to §2/§3 of this doc and the design doc's Stage 1:

1. **The runner is LM Studio's `/v1/embeddings`** (OpenAI-compatible; embedding models must be
   explicitly loaded, context 2048). EmbeddingGemma-300M exists as an official
   `lmstudio-community` GGUF; nomic and bge-small likewise; arctic-embed's GGUF availability is
   checked in the app at spike time. **Use F16/Q8_0 GGUFs, never Q4, for embeddings** — and note
   the engine consequence honestly: llama.cpp under LM Studio may not drive the M5's Neural
   Accelerators the way MLX does, so the Air's §4 upper band is less likely on this route. The
   spike measures it; nothing is assumed.
2. **The pin moves.** Instead of a Python lockfile + HF revision, provenance pins the **GGUF
   file's SHA-256** (`MODEL_FILE` env), the LM Studio model id, and the chunk/prefix parameters.
   Same contract, different anchor. A quantized GGUF is a *different model* than the fp32
   checkpoint for pinning purposes — the V-0 gates run through the same runtime that will do the
   full pass, so quality is measured on what actually ships.
3. **Pooling leaves the harvest.** The store keeps **chunk vectors + spans**, not document
   vectors; pooling, L2, Matryoshka truncation, and quantization all move into the deterministic
   packer on Claude's side. A pooling-rule change — the exact hazard the OS-27 doc flagged — now
   costs a re-pack (minutes), never a re-run (overnight). This supersedes §3.1's "pools to one
   document vector" for this route, and improves on it.
4. **The transfer is part of the pipeline.** The store carries `SHA256SUMS`; the runbook's Phase
   4 verifies them on the Air before anything reads the vectors. An unverified transfer is not a
   raw store.
5. **Division of labour**, explicit: owner = Phases 0–4 (setup, spike on both machines, model
   choice sign-off from the spike numbers, full harvest, transfer); Claude = store validation,
   the V-0 scoring gates (weak-positive MRR via `cross_references`, blind-panel staging,
   quantization ladder), pooling/packing, and every artifact test.
6. **NER note:** GLiNER/spaCy are not LM Studio models. The LM-Studio-native detection route is
   structured-output chat NER (sample-first per §4.4's logic); the NLTagger control runs in-repo
   on the Air. The R-1 harness lands in `tools/semantic-harvest/` after the spike and M2a exist.

## 6. Owner decisions this doc adds

1. Approve the **R-0 text layer** amendment to Stage 1 (the one change to the design doc's
   pipeline; costs ~1.4 GB of cache and buys a single audited extraction).
2. Approve the **combined V-0**: run the spike on both machines, adding the NER candidates to the
   same 3-volume sweep so one spike prices both programs.
3. Schedule the **two keying sittings** (M1a 300 rows; M2a exhaustive sample) — everything else
   in both programs waits on these, not on hardware.
4. Detector shortlist sign-off (NLTagger control / spaCy-trf / GLiNER) — or name a different one
   before the spike, not after.

Version history:
  1.1 — 2026-08-07 (later): §5 execution route — LM Studio owner-run, committed harvester,
        pin moved to GGUF SHA, pooling moved to the deterministic pack side.
  1.0 — 2026-08-07: initial assessment and cost model (measured corpus tokens; both-machine
        estimates; design-doc §3.3 wall-clock correction; the ride/does-not-ride seam).
