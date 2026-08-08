# Vector Embeddings & Semantic Similarity — Precomputed-Corpus Design

**Status:** design recommendations, unreviewed. No code. Every number sourced from this repo's own
measured documents is cited; every external claim about models/APIs that has not been exercised
against a real toolchain is marked **[U]** unverified.
**Owner ask (2026-08-03):** bundled semantic indexing driving a semantic proximity axis for
Related Documents and Project Leads, plus a browse/discovery view for visually inspecting semantic
space (aggregated axes and fewer-dimensional slices). Generation hardware available: an M1 Mac
Studio with many cores for long-running vectorization.
**Related:** `Planning/OS27-Semantic-Retrieval-Design.md` (the on-device sketch this supersedes in
part — see §1), `Planning/Lexical-Similarity-Neighbors-Assessment.md` (the measured corpus facts
this leans on throughout), #308 (axis model), #377 Phase 3 (Project Leads), #643 (by-own-max
normalisation defect), #645 (candidate-pool truncation sites), #488 (CloudKit schema-deploy tax).
**Date:** 2026-08-03

---

## 0. Summary of recommendations

1. **Precompute everything heavy on the Mac Studio; ship vectors, not models.** The OS-27 design's
   workstream C rated on-device embedding of 316,839 documents as "the single most likely reason C
   does not ship as specified" (§5.4). Owner-side precomputation deletes that risk entirely and
   replaces it with a distribution problem, which this repo already knows how to solve — it ships
   17 bundled artifacts today and downloads 552 volumes from GitHub with blob-SHA verification.
2. **Split the corpus vectors into three tiers by access pattern** (the `cloud-vectors-core` /
   `cloud-vectors-volumes` precedent, applied harder):
   - **Tier 0, bundled (~3–4 MB):** 2-D map coordinates for every document + cluster labels +
     volume/subseries centroids. Powers the discovery map and volume-grain leads with **zero
     volumes downloaded** — the word-cloud zero-download story, repeated.
   - **Tier 1, bundled, owner decision (~10 MB):** binary-quantized (256-bit) vectors for the whole
     corpus. Powers corpus-wide semantic candidate *generation* (Hamming distance) everywhere,
     including volumes the user never downloaded — the never-built "Quick-Start hosted index",
     finally shaped like something this app can ship.
   - **Tier 2, downloaded per volume (~150 KB/volume, ~81 MB full corpus):** int8 256-dim vectors,
     fetched alongside the volume by `DownloadManager` from an app-owned GitHub repo, mmapped as
     flat per-volume shards, deleted with the volume. Powers exact cosine scoring and the map's
     live "slice" projections.
3. **Retrieval is exact brute force. No ANN library, no sqlite-vec, no HNSW.** At this corpus
   scale a full scan is milliseconds (§5.2), exact, allocation-free, and deterministic — which is
   the house religion. An approximate index is complexity with no payoff below ~1M vectors.
4. **Model: a small open Matryoshka embedding model, run through a two-stage pipeline** — a pinned
   Python embed/project stage that writes a raw vector store (treated like a harvest cache, per the
   `RecordGroupCatalogGenerator` raw-store precedent), then a deterministic Swift SPM
   `SemanticVectorsGenerator` packer with the full artifact-test treatment. Primary candidate:
   **EmbeddingGemma-300M** (768-d Matryoshka → 256/128, multilingual, on-device-class) with
   Apache-2.0 fallbacks benchmarked in a V-0 spike (§3.2). Do **not** build the corpus side on
   `NLContextualEmbedding` (§3.4).
5. **The envisioned features are feasible, in this order:** semantic axis for #308 (straightforward
   — and it must enter the ranker as a *self-normalising* scorer to dodge #643), Project Leads
   centroid retrieval (the OS-27 §5.5 shape survives unchanged), discovery map (feasible and
   genuinely novel, but the renderer must be Metal with level-of-detail, not SwiftUI Canvas), and
   free-text semantic search **last**, because it is the only feature that needs an on-device query
   encoder (§6.4).
6. **The first session is a spike (V-0), not a build:** embed 3 volumes including one pre-1900,
   gate quality with cross-reference weak-positives plus the lexical assessment's era-stratified
   blind protocol, and measure binary+rerank recall. The lexical assessment earned its verdict by
   measuring before building; this workstream should not regress on that.

---

## 1. What changes relative to the two prior documents

**Against `OS27-Semantic-Retrieval-Design.md` workstream C** (on-device `NLContextualEmbedding` at
index time): the owner's Mac Studio flips the compute question. That design's §5.4 risk (corpus-
scale embedding on the oldest supported iPhone), its asset-download unavailability handling, its
pooling-strategy pinning hazard, and its §5.3(3) iOS/macOS dimension-mismatch worry all evaporate
when vectors are computed once, offline, and shipped as data. What survives from that document:

- §5.2's axis design (opt-in weight 0.0, "Semantically similar" naming, the unsolved "why related"
  chip — §6.1 below picks that up).
- §5.3's storage verdict: **vectors never become a `@Model`** — derived data, recomputable,
  #488-free by construction. This document keeps that rule and sharpens it: not SQLite BLOBs
  either, but flat mmapped shard files (§5.1).
- §5.5's Project Leads shape: centroid for generation, per-seed cosine for attribution.
- Workstreams A (Siri/`IndexedEntity`) and B (`CSUserQuery`) are untouched and stay separate. B
  remains the right tool for user-typed natural-language queries *today*, before any query encoder
  ships; nothing here replaces BM25 lexical search (that document's §7 boundary stands).

**Against `Lexical-Similarity-Neighbors-Assessment.md`**: its measured corpus facts are the ground
truth this design builds on — 316,839 `document_cache` rows; 46,234 documents (14.6%) with no
source note *and* no cross-reference candidate (98.2% of pre-1900 is zero-candidate); the
`document_cache` display fence; the reprint tier's failure by cosine; the "Schedule A"
document-*type* failure; the #643 normalisation defect and the `isSelfNormalising` escape; the
seven #645 truncation sites that should land first. Its *verdict* — bundled artifact dominated by
a free FTS5 query — does **not** transfer, for a structural reason: the free query it lost to is
lexical. BM25 can re-derive lexical neighbors from the index the user already carries; nothing on
the device can re-derive *semantic* neighbors without a model and a corpus pass, which is exactly
the thing being precomputed. The competition that killed the lexical artifact does not exist here.
What does transfer is its warning: **precision is unproven until measured, and pre-1900 — the era
this feature exists for — is where cosine embarrassed the lexical axis.** Same kill criteria, same
blind protocol (§8).

Sequencing note carried over verbatim: the two incumbent fixes (#645 at all seven sites; the four
missing archival route arms) are cheaper than any axis and shrink the zero-candidate population
that justifies this one. Land them first, then re-measure the addressable market.

---

## 2. Corpus arithmetic (the numbers everything below uses)

| Quantity | Value | Source |
|---|---|---|
| Volumes / subseries | 552 / 107 | manifest, cloud-vectors |
| Documents (display rows) | **316,839** | lexical assessment §0.1, measured on the live index |
| TEI document divs | ~314,479 | lexical assessment §1b |
| Corpus XML | 3.34 GB | manifest `sizeBytes` sum, verified 2026-08-03 |
| Non-`"dN"` xml:ids | 948–949 (0.30%), `idExceptions` ≈ 18 KB | lexical assessment §1b |
| Manifest `documentCount` | **0 for all entries** — per-volume counts must come from the generator's own scan | lexical assessment §1b |
| Existing bundled JSON | 12.3 MB across 17 files | lexical assessment §1b |
| A full-corpus user already carries | 3.11 GiB volumes + 6.29 GiB index | lexical assessment §0.6 |

Vector storage at 316,839 documents:

| Encoding | Per doc | Corpus | Per volume (avg 574 docs) |
|---|---|---|---|
| 768-d float32 | 3,072 B | **973 MB** — rejected on sight | — |
| 256-d float16 | 512 B | 162 MB | 294 KB |
| **256-d int8** (Tier 2) | 256 B (+4 B scale) | **~82 MB** | **~149 KB** |
| 128-d int8 | 128 B | 41 MB | 75 KB |
| **256-bit binary** (Tier 1) | 32 B | **10.1 MB** | 18 KB |
| **2-D coords, int16 grid** (Tier 0) | 4 B | **1.27 MB** | 2.3 KB |

The int8 Tier 2 corpus total (~82 MB) is 2.6% of the volume XML the same full-corpus user already
downloaded, and ~1.3% of their index. Per volume it is invisible next to the ~6 MB XML fetch. The
Tier 1 binary file is the only artifact that moves the *bundle*, and it is the one genuine
app-size decision in this design (§4.2).

---

## 3. Generation pipeline (the Mac Studio's job)

### 3.1 Two-stage architecture: pinned harvest, deterministic pack

The house standard is "entirely offline & deterministic," and neural embedding is neither — float
output varies across BLAS builds, batch shapes, and hardware. Do not fight that; contain it, the
way `RecordGroupCatalogGenerator` contains a 22 GB network harvest it cannot re-run cheaply:

- **Stage 1 — embed + project (Python, pinned, cached).** A committed, lockfile-pinned script
  (`tools/semantic-vectors/`, `uv`-managed) that: chunks each document's body text, embeds chunks,
  length-weighted-mean-pools to one document vector, L2-normalises, and writes a **raw vector
  store** (one file per volume, float32, plus a run manifest recording model SHA-256, revision,
  chunking params, pooling, library versions). It also runs PCA→UMAP for the 2-D map and HDBSCAN
  (or k-means) + c-TF-IDF labelling for clusters, with `random_state` pinned. The raw store lives
  under `.cache/semantic-vectors/` and is treated exactly like the NARA raw NDJSON: **the
  expensive, non-reproducible harvest you never delete while the artifact is settling.**
- **Stage 2 — pack (Swift SPM `SemanticVectorsGenerator`, deterministic, tested).** Reads the raw
  store; quantizes (int8 with per-vector symmetric scale; binary by sign); truncates Matryoshka
  dims; grids the 2-D coords to int16; orders everything by the filename-sorted volume scan and
  document ordinal; emits every artifact in §4 with full provenance (model identity + SHA, dims,
  quantization params, chunking/pooling pins, `GENERATED_DATE`). All the O-1 idioms apply —
  sortedKeys where JSON, explicit sorts, tie-breaks, byte-identical repack tests. Determinism is
  asserted **from raw store to artifact**, not from corpus to artifact; provenance is what makes
  the raw store auditable. This is the same epistemic split the keyness baseline makes when it
  pins tokenisation rather than re-deriving it on device.

Body text comes from `TEIBodyTextExtractor.documents(in:)` — the same approximation the cloud
vectors accepted, for the same reason (scores, not rendering). Reuse the id-exceptions inventory
from `CrossRefValidationGenerator` Pass A for the 0.30% non-`"dN"` ids.

An all-Swift alternative exists — convert the encoder to Core ML once and run Stage 1 in Swift on
the Studio's ANE/GPU — and it buys exact parity with a future on-device query encoder (§6.4). It
costs the UMAP/cluster stage, which has no credible Swift implementation. Verdict: start Python;
if V-5 ships a Core ML query encoder, re-run Stage 1 through that same Core ML model at that point
so corpus and query vectors come from literally one artifact **[U — parity gap between a Core ML
conversion and the original PyTorch checkpoint is typically ~0.999 cosine but must be measured,
not assumed]**.

### 3.2 Model choice

Requirements, in order: (1) strong retrieval quality at ≤300M params, because a future on-device
query encoder must be shippable; (2) **Matryoshka** training, so one generation run yields 256-d
shipping vectors and cheaper truncations without re-embedding; (3) multilingual tolerance — FRUS
carries French/Spanish/German passages; (4) a licence compatible with *redistributing the weights
inside an app binary* later, not merely with running them locally.

| Model | Params | Dims (MRL) | Context | Licence | Note |
|---|---|---|---|---|---|
| **EmbeddingGemma-300M** | 308M | 768→512/256/128 | 2K | Gemma terms | Primary candidate: best MTEB-at-size as of late 2025, explicitly on-device-targeted, MLX/Core ML ports exist **[U]**. Gemma licence permits redistribution with conditions — **owner must read it before V-5 bundles weights**; for Stage-1-only use it is unproblematic. |
| snowflake-arctic-embed-m-v1.5 | 109M | 768→256 | 512 | Apache-2.0 | The clean-licence fallback; strong retrieval, MRL-trained, English-centric. |
| nomic-embed-text-v1.5 | 137M | 768→64 | 2K | Apache-2.0 | MRL; requires task prefixes (`search_document:`/`search_query:`) — a pooling-pin-class hazard: the prefix becomes part of the artifact contract. |
| Qwen3-Embedding-0.6B | 600M | 1024, MRL | 32K | Apache-2.0 | Quality ceiling of the small tier; 2× the weight budget of the others for a query encoder. |
| bge-small-en-v1.5 | 33M | 384 | 512 | MIT | Floor/control model for the spike; no MRL. |

The V-0 spike (§8) picks between the top three on *this* corpus — 19th-century diplomatic prose is
far from MTEB's distribution, and the lexical assessment's pre-1900 findings are a standing warning
against trusting leaderboard numbers here.

### 3.3 Chunking, pooling, and wall-clock

FRUS documents average ~10.5 KB of XML (3.34 GB / 317k), so body text runs roughly 1–2K tokens
with a long tail (editorial notes, memcons). Chunk at ~800 tokens with ~15% overlap; embed chunks;
document vector = length-weighted mean of chunk vectors, L2-normalised. Estimate ~600k–1M chunks
corpus-wide. On an M1 Studio running a 100–300M encoder batched on MPS/MLX, expect order
100–500 chunks/s **[U]** → a full-corpus pass in the **1–6 hour** band, an overnight run at worst.
This is the CloudVectors "~50–60 minutes, owner-executed once" tier of cost, not a new tier.

> **Corrected 2026-08-07** (`M2-Semantic-Pipeline-Ride-Along.md` §4.1): the corpus measures
> **~330 M body-text tokens** (~475 k chunks, not 600 k–1 M), and the 1–6 h band implies a
> throughput no Apple-Silicon machine reaches for the 300 M primary — it holds only for the
> ≤137 M fallbacks. Measured-assumption estimate for EmbeddingGemma-300M on the M1 Max Studio:
> **~8–13 h**. Same cost tier, honest clock. That doc also adds the R-0 extracted-text layer
> (one amendment to Stage 1) so the M2 NER pass shares this pipeline's extraction.
UMAP over 317k × 256-d (PCA-50 first) is minutes on 20 cores **[U]**.

Two decisions to pin in provenance because changing them silently invalidates every vector: the
chunking parameters and the pooling rule (the exact hazard the OS-27 doc flagged for
`NLContextualEmbedding` pooling — it applies unchanged to offline generation). **Chunk vectors are
discarded in v1** — keeping them (for passage-level retrieval) multiplies Tier 2 by ~2–3× and no
v1 surface reads them; note it as the one cheap-to-reopen decision if a RAG surface (§7) ever
wants passage grain.

### 3.4 Why not `NLContextualEmbedding` for the corpus side

Tempting: zero model management, Apple-optimised, and the Studio could run the same API. Rejected
for the corpus side because the model is **not pinnable** — assets rev with OS updates, and the
artifact contract this repo lives by (pin the tokenisation, refuse on mismatch) cannot be honoured
when Apple owns the revision schedule. A corpus embedded under revision N and queries encoded under
revision N+1 fail silently, the exact cross-source join `BundledKeynessBaseline` refuses on record.
It also produces token vectors (pooling is on us), its retrieval quality against modern MRL
embedders is unverified on this corpus, and the OS-27 doc's own §5.3(3) dimension question is
still open. It remains the zero-download fallback if V-5's bundled-encoder route fails — nothing
in this design forecloses it, because the query encoder decision is deferred to V-5 anyway (§6.4).

---

## 4. Artifacts and distribution

### 4.1 Tier 0 — bundled map + centroids (~3–4 MB, new bundle resources)

One `semantic-map.bin` (custom binary, not JSON — coordinates gain nothing from text encoding and
the decode window matters at 317k records) + one small `semantic-map-meta.json`:

- Per document: int16×2 grid coordinates (quantized from UMAP output), u16 cluster id. Documents
  keyed implicitly: volumes in manifest order, docs by ordinal, `idExceptions` side table (~18 KB)
  for the 0.30%. 6 B/doc ≈ **1.9 MB**.
- Per cluster (expect ~300–1500): label (c-TF-IDF top terms through the **WordCloudKit tokenizer
  and stopword stack**, so labels speak the same vocabulary as every cloud surface), centroid
  coords, member count, era histogram. Tens of KB.
- Per volume and subseries: 256-d int8 **centroids** (552 + 107 × 260 B ≈ 171 KB) — these power
  volume-grain leads and "position this undownloaded volume on the map."
- Provenance: model SHA, dims, UMAP params + seed, cluster params, `GENERATED_DATE`.

Loader: `BundledSemanticMap` on the `BundledCloudVectors` pattern — `@MainActor` enum, idempotent
async `prepare()`, decode off-main in `Task.detached(.utility)`, never first-touched on a render
path. New bundle resources ⇒ one `xcodegen generate` + the mandatory scheme restore.

### 4.2 Tier 1 — bundled binary vectors (10.1 MB, **owner decision**)

`semantic-vectors-binary.bin`: 256 sign bits per document, corpus-wide. What it buys:

- **Corpus-wide semantic candidate generation with zero downloads.** Hamming top-N over 10.1 MB is
  a `popcount` scan — ~2.5M 64-bit XOR+popcounts per query, well under 10 ms on any supported
  device **[U — measure in V-2]**.
- The off-index tier the lexical assessment could only sketch: "4 strong semantic matches for this
  project in *1958–60 Berlin Crisis* (not downloaded)" with the established Download affordance —
  because Tier 1 covers volumes the user does not have. Volume-grain rollup presentation, separate
  section, never blended into `aggregateScore` (the I-3 rule).
- A rerank source: Hamming top-200 → int8 exact rescore (where Tier 2 is present) → top-k.
  Expected recall@10 vs full-precision ≥95% **[U — the V-0 spike measures this]**.

The cost is bundle size: +10.1 MB against today's 12.3 MB of bundled JSON — an ~80% jump, paid by
every user including the never-downloads-anything one. Alternatives if that is unacceptable:
128-bit binary (5.1 MB, weaker), or demoting Tier 1 to a first-launch background download from the
same channel as Tier 2. Recommendation: **bundle the 256-bit file** — it is the only artifact that
makes semantic features work before the first download, and "works before the first download" is
this app's signature move (word clouds, splash, leads copy). But it is genuinely the owner's call.

### 4.3 Tier 2 — per-volume int8 shards (~149 KB/volume, downloaded)

One `frus1861.vec` per volume: header (magic, version, model SHA prefix, dims, count) + int8
vectors in document-ordinal order + per-vector float16 scales + the volume's id-exception rows.
Distribution channel, in preference order:

1. **App-owned GitHub repo** (e.g. `frus-semantic-vectors`), fetched with the exact
   `DownloadManager` machinery that already fetches volumes from GitHub — contents-API listing,
   direct download URL, git-blob-SHA verification, background-session resume. A vectors manifest
   (checksums + provenance pin) rides in the repo. This is near-zero new infrastructure and keeps
   the artifact refreshable independently of app releases.
2. **Apple-Hosted Background Assets** (OS-26 floor supports it **[U — verify the hosting
   entitlement and size limits before choosing]**) — more productized, but new machinery, new
   review surface, and it couples artifact refresh to App Store Connect.

Lifecycle: fetched automatically after a volume's XML download completes (an `IndexingPipeline`
post-step, so the volume is "semantic-ready" exactly when it is search-ready); deleted in the same
teardown that clears FTS5 and Spotlight (`IndexingPipeline.swift:1412` precedent); re-fetched when
the vectors manifest's provenance stamp changes (the `applyBrokenRefsIndexIfNeeded` re-run
pattern). A registry table in the SQLite store records shard presence + provenance per volume —
**the vectors themselves stay out of SQLite**: a brute-force scan wants one contiguous mmapped
buffer per volume, not 574 BLOB fetches. Missing shard ⇒ the axis is *typed-unavailable* for that
volume (the `CollocationAnalysis.Unavailable` shape — the lexical assessment's fold-in 3 applies
here verbatim), never silently zero.

**Version skew rule:** every artifact in all three tiers carries the same model SHA + dims pin,
and every consumer refuses to mix pins — a Tier 2 shard from generation N never rescoreds Tier 1
candidates from generation N+1. Refuse loudly, re-fetch, or degrade to the tier that matches;
never blend. This is `BundledKeynessBaseline.configurationMismatch`, promoted to a family rule.

---

## 5. On-device retrieval

### 5.1 Storage and memory

mmap the shards; never copy them into Swift arrays. Resident cost is whatever the scan touches —
the full 552-shard corpus is ~82 MB of *mapped* pages against a 6.29 GiB index the same user
already holds. Tier 0/1 load once, off-main, behind `prepare()`.

### 5.2 The kernel

Exact scan, three flavours, all deterministic:

- **Hamming (Tier 1):** XOR + popcount over 4×UInt64 per doc; top-N heap with the house
  count-then-key tie-break. Corpus-wide: ~317k iterations.
- **int8 cosine (Tier 2):** vectors are L2-normalised before quantization, so dot(int8,int8) ×
  scale₁ × scale₂ ≈ cosine. A 256-d int8 dot is 64 SIMD16 MACs; one volume (574 docs) is
  ~150k MACs — instant; the full downloaded corpus (317k docs × 256) ≈ 81M MACs, order
  ~10–50 ms on the oldest supported hardware **[U — V-2 measures on the oldest device; the
  lexical assessment's on-device-latency kill criterion applies]**. Accelerate/BNNS if hand-rolled
  SIMD disappoints, but hand-rolled `simd_int` loops are likely sufficient and dependency-free.
- **Axis projection (map slices, §6.3):** dot each visible doc's int8 vector against a float
  axis vector — same kernel, one query, N docs.

No ANN. If the corpus someday 10×es, revisit; at 317k, brute force wins on every axis this repo
cares about (exact, deterministic, zero deps, trivially testable).

### 5.3 What is NOT stored

No `@Model`, no CloudKit record types, no new SwiftData property — #488 untouched by construction.
`ProjectLeadEntry` schema unchanged (leads recompute locally from shipped vectors; cross-device
divergence disappears because **every device now scores identical pinned vectors** — the OS-27
doc's §5.5 last-writer-wins question dissolves). The one residual: devices with different
*download sets* still compute different leads, which is already true of every axis today.

---

## 6. The envisioned features, assessed

### 6.1 Semantic proximity axis for #308 — **feasible, smallest lift, highest evidence-per-effort**

`SimilarityAxis.semanticSimilarity`, exactly four switch arms + a generator, as the OS-27 doc
specified (weight **0.0**, experimental framing, "Semantically similar", `text.magnifyingglass`).
Both weight UIs pick it up automatically; `AxisWeights` round-trips unknown cases safely. Three
sharpenings from the lexical assessment's scar tissue:

1. **Enter the ranker self-normalised.** Cosine is already absolute in [0,1]. Feeding it through
   the by-own-max generator normalisation (#643) would hand a document's *only* semantic neighbor
   a 1.0 regardless of actual similarity — the exact thin-axis weaponisation the lexical
   assessment documented. Add `isSelfNormalising` (its §0.12 proposal) and use raw cosine.
2. **Generator and scorer both.** Candidate generation: Tier 1 Hamming top-N (corpus-wide) then
   filter/rescore against Tier 2 + the `document_cache` fence. Scoring: batch-cosine the *other*
   generators' candidates so a semantically-perfect archival neighbor scores high on this axis
   too (the OS-27 §5.1(a) argument). Confirm the ranker invokes a generator in the scoring pass
   rather than assuming disjoint — flagged in OS-27 §5.2, still unverified.
3. **The "why related" chip.** Cosine explains nothing, and an unexplained row reads as noise
   (OS-27 §5.2's open question). Recommended answer: compute shared-distinctive-terms **at render
   time** for the ~30 displayed rows only — `documentBodyTextsByKey(forKeys:)` + the keyness
   machinery already exist, the pair's texts are on device by definition (both passed the
   `document_cache` fence), and the lexical assessment measured this class of query at ~50 ms.
   Chip: `shares: kearsarge, raider` (display forms from the anchor's own text — never stems).
   Fallback where extraction is thin: `Semantic match · 82%`. An on-device LLM one-liner via the
   existing `SummarizationProvider` is a v2 nicety, cached if ever built.

**Who it serves is already measured:** 46,234 documents with an empty Related list today, 98.2%
of pre-1900. That is also where cosine quality is *least proven* — the axis lives or dies on the
V-0 pre-1900 gate, not on Cold War telegrams, which everything retrieves well.

### 6.2 Project Leads — **feasible; the OS-27 §5.5 design survives verbatim**

Centroid of seed vectors (seedCap 40) → Tier 1/2 top-N → per-seed cosine on the bounded result to
repopulate `contributingSeedKeys` — generation by centroid, attribution per seed, the §6.2
generator/scorer split reused. Two additions: (a) the off-index volume-grain tier — Hamming hits
in undownloaded volumes roll up to "N strong matches in *volume*" + Download button, separate
section per I-3; (b) `WorkingCorpus` as a seed source is the same free win the lexical assessment
identified (fold-in 4), same cap-mismatch caveat (7,500 keys vs seedCap 40).

### 6.3 Browse/discovery map — **feasible and novel; the risk is rendering discipline, not data**

Answering the owner's "using raw vectors?" directly: **no live dimensionality reduction on
device.** UMAP on-device is expensive, non-deterministic, and layout-unstable across runs — users
would watch the map rearrange itself. Ship the **precomputed 2-D layout** (Tier 0) as the stable
"geography," and use **raw vectors for live projections** — the two compose:

- **Global map:** all 316,839 points at precomputed coords. Rendering: **Metal
  (`MTKView`/point-sprites) with level-of-detail** — corpus zoom draws a precomputed density
  layer + cluster labels; volume/cluster zoom draws real points. SwiftUI `Canvas` degrades past
  ~20–50k points **[U]** and 317k is 6–15× that; do not start there. This is the one place this
  workstream buys new rendering machinery — budget it honestly (it is a session, not an
  afternoon).
- **Colour lenses, all from bundled data already shipped:** era/decade, subseries, administration
  (`administrations.json`), provenance category (`source-provenance-index`), volume subjects,
  downloaded-vs-not, cluster. A map coloured by provenance category alone — "watch the central
  files give way to presidential libraries across the space" — is a historian-grade artifact no
  other FRUS tool has.
- **Fewer-dimensional slices (the owner's phrase):** a *semantic axis* = normalised difference of
  two centroid vectors, where the user picks the poles — two documents, two clusters, two
  volumes, or two subject/keyness term-sets. Project visible documents onto it (one dot product
  each, §5.2) and drive the x-axis with it while y stays date (or a second semantic axis). This
  is honest in a way the UMAP plane is not — UMAP preserves neighborhoods, not global distances,
  and the UI copy should say so (`AnalyticsProvenance`'s unconditional-caveat posture: the map
  states "layout preserves local similarity; distances between far regions are not meaningful").
- **Selection → action:** lasso/marquee → the existing `WorkingCorpus` (≤7,500 keys) or a
  Collection; tap → document (fence rule: undownloaded docs open the volume-download affordance,
  `ReferenceListPanel` precedent); anchor-doc mode → highlight its Hamming neighborhood.

Feasibility verdict: **high** on data (Tier 0 is 6 B/doc), **medium** on rendering effort, and the
interaction design (lasso, LOD thresholds, label collision) is the real scope. Prototype the Metal
LOD spike early (V-4a) before committing the full surface.

### 6.4 Free-text semantic search — **feasible, but last, and honestly optional**

Everything above runs without any on-device encoder: doc→doc, seeds→leads, map, slices are all
vector-lookup features. Typed-query semantic search is the only feature needing a query-side
encoder, and it has three routes: bundle a Core ML conversion of the corpus model (~80–150 MB
quantized **[U]** — likely a Background Assets download, not a bundle item; Gemma licence check
required), `NLContextualEmbedding` (free but unpinnable — §3.4's mismatch risk lands squarely
here), or don't ship it and let `CSUserQuery` (OS-27 workstream B) remain the natural-language
surface. Recommendation: defer to V-5, decide with V-0's model choice in hand, and treat OS-27
workstream B as the interim answer. If V-5 ships, blend as **hybrid**: BM25 candidates ∪ semantic
candidates → RRF or weighted merge — never replace lexical search (§7 boundary of the OS-27 doc;
FRUS researchers need exact-phrase behaviour).

---

## 7. Other semantic integrations, ranked by evidence-per-effort

1. **Zero-candidate rescue** — is §6.1; listed to name the metric: re-measure the 46,234 after
   the #645/route-arm fixes, and report axis coverage against *that* population in provenance.
2. **"Which volume next" leads** (§6.2b) — the first surface that answers the question with
   semantic evidence, and the resurrection of the never-built hosted Quick-Start index.
3. **Cluster-share-over-time analytics** — cluster × decade stacked areas in the Analytics tab
   (Swift Charts is already there; administration boundaries from `administrations.json`).
   Cheap: Tier 0 already carries cluster ids and the manifest carries date ranges.
4. **Auto-collection suggestions** — cluster the user's downloaded library / a WorkingCorpus,
   propose named groups (cluster labels are pre-baked). Pure Tier 0/2 arithmetic.
5. **Subject-tag denoising (#261 revisited)** — the doc-grain frus-subjects drop was withdrawn as
   too noisy at document grain; k-NN majority vote over embeddings is the standard cheap
   denoiser. A measurement session, not a feature: if precision jumps, `sharedSubjects` finally
   gets non-inert data.
6. **RAG grounding for a "chat with the corpus" surface** — the OS-27 doc's `SpotlightSearchTool`
   sketch, but with a real retriever underneath (§6.4 hybrid). Needs V-5 and a passage-grain
   decision (§3.3). Explicitly out of v1.
7. **Person-trajectory embeddings** — average vectors of a person's documents per year
   (person-authority index supplies the rollup); "Kissinger's 1969 docs vs his 1975 docs" as a
   path through the map. Novel but speculative; needs a design of its own.
8. **Reprint detection — explicitly NOT this workstream.** The lexical assessment measured
   cosine's failure at that job (score-1.00 pairs dominated by shared-surname short telegrams;
   inverse length correlation). Reprints want a shingle/text-identity index with a length floor.
   Embeddings do not change that verdict; do not let this workstream absorb it.

---

## 8. Spike V-0: the gates before any building

Half a week on the Studio, no app code:

1. Embed 3 volumes — one pre-1900, one interwar, one Cold War — with the top 3 model candidates
   (§3.2) at 768-d and truncations 256/128.
2. **Weak-positive gate:** documents joined by an editorial `<ref>` (the cross_references table —
   ~185k edges, 71.7% intra-volume) should rank each other highly; report MRR@10 per model per
   era. Free labels, corpus-native, no annotation cost.
3. **Blind precision panel:** the lexical assessment's §0.11 protocol verbatim — 100 rows,
   era-stratified, pre-1900 its own bucket, kill if overall <60% "a historian would want this"
   or pre-1900 fails alone. Include the "Schedule A" payroll table and its structural-document
   cousins deliberately; decide the type-exclusion list from evidence.
4. **Quantization ladder:** recall@10 of int8-256 vs float-768; Hamming-256→int8 rerank vs flat
   int8. Sets Tier 1/2 shapes with numbers instead of citations.
5. **Wall-clock + raw-store size** extrapolated to 552 volumes.

Kill criteria mirror the lexical assessment's, plus one: **if no model clears the pre-1900 gate,
the axis ships Cold-War-scoped or not at all** — do not ship a semantic axis whose headline
population is the one it fails on.

## 9. Phasing

| Phase | Work | Depends on |
|---|---|---|
| **V-0** | Model/quality/quantization spike (§8) | corpus on the Studio |
| **V-1** | Stage-1 pipeline + raw store; `SemanticVectorsGenerator` packer + artifact tests; full-corpus run | V-0 |
| **V-2** | Device substrate: Tier 0/1 loaders, shard fetch/registry/teardown in DownloadManager+IndexingPipeline, mmap scan kernels, oldest-device latency measurement | V-1 |
| **V-3** | `semanticSimilarity` axis (self-normalised, weight 0) + render-time chips; leads centroid + off-index volume tier | V-2; ideally after #645/route-arm fixes |
| **V-4** | Discovery map — V-4a Metal LOD spike first, then lenses/slices/lasso | V-2 (Tier 0 only) |
| **V-5** | Optional: query encoder (Core ML via Background Assets), hybrid search; corpus re-embed through the shipped encoder for exact parity | V-0's model call, licence check |

V-3 and V-4 are independent after V-2 and can land in either order. Nothing here gates on OS 27;
nothing touches CloudKit schema; the OS-27 doc's workstreams A/B proceed (or don't) untouched.

## 10. Open questions / owner decisions

1. **Tier 1 bundled (+10.1 MB) vs first-launch download vs 128-bit (+5.1 MB)?** (§4.2 — the one
   real app-size decision.)
2. **Model + licence:** EmbeddingGemma quality vs Apache-2.0 cleanliness of arctic-embed/nomic —
   decided by V-0 numbers plus a licence read, not vibes.
3. **Hosting:** app-owned GitHub repo (recommended) vs Apple-Hosted Background Assets.
4. **Dims:** 256 recommended; V-0's quantization ladder may justify 128 (halves Tier 2).
5. **Chunk vectors:** discard in v1 (recommended) — reopened only by a future RAG surface.
6. **Map scope for v1:** full-corpus surface vs library-only first release (rendering risk
   containment).
7. **Where the map lives:** Analytics tab, a new Browse mode, or a macOS window scene of its own —
   interacts with the platform-split conventions and deserves its own UX pass.

---

Version history:
  1.0 — 2026-08-03: initial recommendations (precomputed-corpus design, Mac Studio pipeline,
        three-tier distribution, feature feasibility, spike gates). Unreviewed.
