# Document-Level Lexical Similarity Neighbors — Feasibility & Value Assessment

**Version**: 2.0 (revised 2026-08-01)
**Date**: 2026-07-27, revised after the Q&CA wave closed
**Status**: **Phase A NOT recommended as specified.** The v1.0 verdict — "feasible, and valuable,
in a precision-first shape" — is withdrawn on an argument v1.0 never made. Two smaller pieces
survive; see §1a.

---

## 1a. Revised verdict (2026-08-01)

This revision was prompted by two questions: does the plan change now that D-1 has been demoted
(PR #624), and does the shipped Q&CA wave open anything to fold in?

**D-1's demotion changes essentially nothing here.** The string "D-1" appears zero times in the
v1.0 text, and the artifact lands on the *safe* side of the stem↔lemma divide by construction —
its vector basis is `WordCloudMultiLensTokenizer`, which enumerates `scheme: .lemma`
(`WordCloudKit/WordCloudMultiLensTokenizer.swift:143,153,157-161`), the same space as
`keyness-baseline.json` and the opposite space from the `porter unicode61` FTS5 index
(`FTS5Store/FTS5Types.swift:113,126`). No surface hands a neighbor-derived term back to search.
The **one** place it bites is §9's back-pocket alternative, *"extract the anchor's top TF-IDF
terms (`fts5vocab` gives df)"* (:305-306), which straddles both spaces — lemma terms, stem-keyed
`df`. That is exactly the cross-source join `BundledKeynessBaseline.swift:22-27` refuses on
record. Fixable by running the whole fallback in stem space, but it is a different build than the
sentence implies.

### What actually withdraws the verdict

**The plan's own ship gate, multiplied by a fence the plan already concedes.**

§4 sets the bar: *"under ~15% document coverage at ship threshold … means the thresholding is not
working — a finding, not a tolerance to widen."* That is stated against 314,479 corpus documents.
But every Related Documents path drops a candidate with no `document_cache` display row
(`RelatedDocumentsEngine.rank`: `guard let record = records[key] else { continue }`), and §6.2
concedes the consequence itself — *"The index knows neighbors in all 552 volumes; the library
usually holds a handful."*

Combine that with §3's mandated **≥80% cross-volume** reservation and the arithmetic is forced. At
a 40-volume library a cross-volume neighbor survives with probability ≈ 40/552, times ~1.7 if the
library is topically curated (measured: Berlin-family vs random control at τ=0.50, 4.593e-6 vs
2.702e-6 per pair). A document therefore retains ~30% of its neighbors → **7.5–13% effective
coverage — below the plan's own floor, by construction.**

The measurement that would catch this is scheduled for L-2, on the one 552-volume index in
existence, where it passes. And the only structural fix — Phase B — is explicitly scoped **out**
by decision 6.

Compare what already ships, measured read-only against the live index: **195,534 of 316,839
documents (61.7%)** have an archival-provenance companion *inside their own volume*, and
**133,052 of 185,549 (71.7%)** cross-reference edges are intra-volume. Both existing generators
degrade *gracefully* to a one-volume library. A cross-volume-reserved lexical axis degrades
*catastrophically* — and both weight UIs iterate `SimilarityAxis.allCases` unconditionally
(`RelatedDocumentsView.swift:235`, `ProjectHomeView.swift:621`), so it becomes a permanent seventh
slider that is empty for nine documents in ten, beside the sixth that has been empty since #261.

**One defect the plan is silent about, and a sparse axis is the first thing to weaponise it.**
Generator axes are normalised *by their own max* (`RelatedDocumentsEngine`, step 2). An axis
returning a single candidate hands it a normalised **1.0**; at the proposed default weight 0.7
that totals 0.70. A genuine single-citation cross-reference partner, against an anchor whose top
citer is `logDampedMultiplicity(121) ≈ 5.796` (`SimilarityModel.swift:269-274`), totals 0.173.
**A thin lexical neighbor outranks it 4×, and the effect worsens as coverage thins.**

### What survives

1. **A reprint / "also printed as…" index.** §3 treats score ≥95 pairs as noise control; it is the
   better feature. Cross-volume by nature, precision ~1.0, verifiable by eye, small — and uniquely
   **useful with the other volume not downloaded**, because *"also printed as Doc 412 in vol.
   VIII"* is itself the deliverable. FRUS genuinely reprints. Effort S. Render it as a
   document-view affordance, **not** an axis, so it never touches the normalisation defect and
   adds no slider.
2. **Volume-grain leads (the old Phase B)** as the only axis-adjacent surface, if ever built. It
   is the half immune to the fence, because the payload is the recommendation, not the landing.

Park both behind the N-1…N-6 lane, which carries measured yields.

### If the owner overrides: the first session is L-0, not L-1

Half a day, pure measurement, no artifact and no app code. Run Pass 1 + Pass 2 on one subseries
slice; emit the cosine histogram and, for each τ ∈ {0.30, 0.40, 0.50, 0.60}, the
same-volume / same-subseries / cross-subseries split **and** the retained-neighbor share simulated
at library sizes L ∈ {10, 40, 100, 552}.

> **Acceptance:** at **L = 40** with the ≥80% cross-volume reservation applied, effective document
> coverage ≥ 15%. If it does not clear 15% at L = 40 — *not* at L = 552 — stop; the artifact is not
> built.

That single check is what v1.0 was missing. It costs a fraction of L-1, and it is the honest
version of the acceptance bar §4 already promised.

---

## 1b. Corrections to v1.0

Everything below was measured against code, the local corpus, or the live index read-only. The
body of this document (§2 onward) is retained as reference and is **superseded in detail** by this
table.

| § | v1.0 claim | Status | Correction |
|---|---|---|---|
| §1, §4 | "11.1 MB bundled-JSON footprint"; full k-NN is "4×" it | **Now false** | 17 files, **12.32 MB**. The delta is exactly `keyness-baseline.json` (1,254,148 B), shipped by S-1 after this doc was written. Full k-NN is ~3.6×. Correct on 2026-07-27. |
| §1, §5.3 | "measured … **18m53s**"; "the dominant **I/O** cost" | **Uncorroborated + mischaracterised** | 18m53s appears nowhere in the repo but this doc and its own DEVELOPMENT-PLAN echo; the generator has no wall-clock instrumentation. The authoritative record is **CLAUDE.md: "~50-60 minutes."** And it is CPU-bound, not I/O — reading and scanning all 3.34 GB takes 19–28 s warm. That matters: a CPU-bound pass *is* parallelizable, which the I/O framing argued against. |
| §4 | acceptance bar "under ~15% document coverage" | **Wrong denominator** | Stated against 314,479 TEI divs; every related-docs path joins `document_cache`, which holds **316,839 rows** because `promotableQuasiDocumentKinds` promotes chapters/prefaces (`FRUSDocumentParser.swift:763-769`). 2,360 displayable documents can never carry a neighbor under the `[v1,d1,v2,d2]` encoding — state that as a designed exclusion. |
| §3 vs §4 vs §10 | shared-term evidence "+8–12 B/pair (~1–1.5 MB at 120k)" alongside a ≤3.5 MB bar | **Cannot all hold** | Measured with this repo's own encoder conventions: base 5-int record = **20.25 B/pair**; +3 vocabulary indices = **+11.0 B best case, +17.4 B typical** (the `topics` lens has 219,952 distinct terms, not the ~300 that would make 8–12 B true). At 120k pairs: **3.9–4.6 MB**, before an unbudgeted reprints tier. The plan trips its own no-ship gate on day one. Decision 3 must be resolved as *either* evidence *or* the bar. |
| §5.1 | "314k docs × top-96 terms × ~6 B ≈ 200 MB working set" | **Now false** | `WordCloudMultiLensTokenizer.accumulate` returns **String-keyed** dictionaries (`:140`), and §5.1's whole change is retaining one per document. Measured mean 213.5 distinct non-stopword terms/doc → **~1.5–2 GB**. Intern to `Int32` during tokenization — design it in, don't discover it. |
| §5.2 | "Drop terms with df > ceiling (~5k; kills residual boilerplate)" | **Now false as stated** | Measured df: **berlin 16,271** (dropped), nato 11,306, alliance 7,433, soviet 54,657, treaty 42,971. §3's own worked example — *"shares: Berlin, airlift, sector"* — cannot occur. The real boilerplate is already gone via the diplomatic stopword layer. Re-pose the ceiling as a quality trade, not hygiene. |
| §5.3 | APSS is "the main schedule risk — rate it medium"; "minutes-to-low-hours" | **Now false** | Measured under the plan's own prune parameters: 4.55e9 candidate pairs at T=64 → **~30 s to 3 min single-threaded**. Pass 3 is ~2–5% of the run. Re-rate **LOW**; drop prefix filtering and parallel-merge. The genuine risk is determinism, which is a test problem. |
| §5 (implied), §9 | that `keyness-baseline.json` could supply IDF | **Cannot** | It carries `cutoffCount / distinctTerms / terms / totalTokens` per lens — corpus **term** frequency, no **document** frequency — and `topics` retains 20,086 of 219,952 terms, so the whole high-IDF tail is unpriced. §5.2's df pass must be built. |
| §6.1 | "a 2–3.5 MB decode is inside the `CentralFilesIndexStore` precedent" | **Wrong precedent** | That is the synchronous `static let shared = load()` pattern (`CentralFilesIndex.swift:415`) which `BundledCloudVectors` was written to **avoid** — *"first touch would be a view body"* (`BundledCloudVectors.swift:35-37`). It is a **size** precedent only. |
| §5.4, §9, §10 | "the corpus is not on this machine"; four items "could not verify" | **Now false** | `/Users/jbotts/Development/frus/volumes` holds all 552 manifest volumes. Three of the four are now measured (below). |
| §5.4, §8 | non-`"dN"` xml:id share unknown | **Now measured** | **948–949 of ~314,48x document divs = 0.30%**, ~944 distinct forms (`appA`, `d76a`, `d1190a/b`); **zero** divs lack an `xml:id`; max ordinal 1,916. `idExceptions` ≈ 18 KB. Retire the §8 risk row and the L-1 sub-task. |
| §4 | "Top-5 … ~21–23 MB" | **Understated** | Re-derived over the real per-volume distribution: top-10 ≈ **43.7 MB**, top-5 ≈ **23.9 MB** (the doc omits ~4.0 MB of per-document keying). The rejection is sound. |
| §4 | "11.7 B per compact int-pair entry" | **Right number, wrong instrument** | 110,400 entries verified exactly, but 11.7 divides the *whole file*; the `entries` arrays alone are 10.01 B/entry. Use the measured shapes: 12.63 / 20.25 / 31.25–37.60 B. |
| §5 (implied) | per-volume document counts readable from the manifest | **Now false** | All 552 manifest entries carry `"documentCount": 0`. Counts must come from `TEIBodyTextExtractor.documents(in:)` and be recorded in the generator's own provenance. |
| §1 | "Nothing today says 'these two documents are about the same thing'" | **True, but reads as overtaken** | Tighten to *"nothing computes document-to-document proximity from text."* S-1 keyness is term-level (`Keyness.swift:106-112`), S-2 collocation term-to-term (`Collocation.swift:39-67`); no cosine / more-like-this anywhere. But a four-tap path now exists (research rail → Word Cloud on `.document` → keyness → "Search for this term") that a reader will point at. |
| §2.3 | `ReferenceListPanel.swift:373-469` | **Stale ref** | Now `:447-489`. |
| §1 | `ProjectLeadsService.swift:46-47` | **Path nit** | `FRUSExplorer/ProjectContext/ProjectLeadsService.swift`; the quoted comment is on `:47`. |
| §4 | mean degree 0.6–1.0, 20–35% coverage | **Still true** | 100–150k × 2 / 314,479 = 0.64–0.95. The one §4 number that survives unchanged. |
| §2.1, §2.2 | axis table, two generators, pool floor 120, `sharedSubjects` inert | **Still true** | Weights 1.0/1.0/0.5/0.3/0.7/0.0 (`SimilarityModel.swift:86-95`); exactly `ArchivalProvenanceGenerator()` + `CrossReferenceGenerator()`; `candidatePoolFloor = 120`; `DocumentSubjectStore.shared = nil` (`:74`). **The Q&CA wave shipped nothing into this pipeline.** |
| §1 | `effectiveWeights` back-fills a future semantic axis with its default | **Still true** | Exact at the cited lines. Adding an axis really is four switch arms plus a generator. |

**Not in v1.0 at all, and load-bearing:** the by-own-max normalisation defect described in §1a.

---

## 1c. Fold-ins from the Q&CA wave

Ranked by value. Each verified against code.

1. **Invert the phase order, or don't ship.** Decision 6 puts Phase B out of scope; that is
   backwards, for the reason in §1a. Phase B is the half immune to the `document_cache` fence.
   *Effort M. Owner decision required.*
2. **Promote the reprints tier to a first-class section** with its own acceptance bar. *Phase A,
   Effort S.*
3. **Typed unavailability for the axis.** Related Documents has one generic empty state
   (`RelatedDocumentsView.swift:204-214`), so "no neighbor above threshold" and "artifact hasn't
   decoded" would be indistinguishable. S-2 shipped the right shape —
   `CollocationAnalysis.Unavailable` enumerates seven cases (`Collocation.swift:203-224`). A sparse
   axis needs this more than a dense one. *Phase A, Effort S.*
4. **Working corpora as a SEED — not as a scope.** `WorkingCorpus.documentKeys` is the identical
   `"volumeId/documentId"` string `ProjectLeadsService` already feeds `DocumentKey(compositeString:)`,
   and `ProjectLeadsAggregator.aggregate` takes a bare seed set. "Find documents like this set" is
   `recompute` with a different seed source and **no new enum case**, so it does not touch closed
   decision 1. Restricting neighbor *output* to corpus members would — use an optional
   `documentKeyFilter: Set<String>?` rather than a `NeighborScope` case. Note the cap mismatch: a
   corpus holds up to 7,500 keys against `seedCap = 40`. *Separate issue, Effort M, needs a decision.*
   **Free now regardless:** neither `RelatedDocuments/` nor `ProjectLeadsService` mentions
   `WorkingCorpus` (grep: zero hits), so a researcher with a corpus applied sees neighbors from
   outside it. §6.1 should say so in one sentence rather than let it arrive as a bug report.
5. **Use the batch download bar.** §6.2 cites the single-volume row;
   `CollectionPreviewView.missingVolumesBar` (`:307-347`) is the actual model — N volumes, one
   button through `DownloadManager`, a distinct "not available" caption. *Phase B, Effort S.*
6. **`documentBodyTextsByKey(forKeys:)`** — shipped after v1.0, keyed body text chunked 400 at a
   time (`IndexingPipeline.swift:5652-5670`). If shared-term evidence is computed at runtime rather
   than shipped, this is the fetch, and `CollocationConfiguration` (`CollocationService.swift:19-55`)
   is the discipline to copy verbatim. *Phase A, Effort S.*
7. **`AnalyticsProvenance` is the export shape** — caveats emitted *unconditionally* with explicit
   "not applied" phrasing, because *"an absent line in a methods block reads as 'not applicable'
   when it often means 'still true, just not shown'"* (`AnalyticsProvenance.swift:28-51`). A
   neighbor list exported without `minScoreShipped` and coverage repeats that omission.
8. **M-2's method appendix — NOT REAL as written.** `QueryMethodAppendix.Row` is query-shaped and
   its one rule is never to print a number whose basis it cannot name; a neighbor has none of its
   fields. But `SaveWorkingCorpusSheet` already writes provenance prose into `sourceDescription`
   at zero schema cost (`:162-171`) — "Lexical neighbors of frus1958-60v08/d42" fits that slot. A
   *persisted* "found via" line is a Wave R-7 schema deploy; cost it honestly, separate issue.
9. **REJECTED — the `terms` table as a normalisation signal.** Measured: 66,095 rows / 10,632
   distinct terms over **312** of 552 volumes; **41%** of terms carry >1 distinct definition across
   volumes; 9,457 rows are 1–2 characters. It is an abbreviation glossary (`A → airgram`).
   Asymmetric coverage would bias exactly the cross-volume pairs §3 reserves 80% of its budget for.
   Recorded here so it is not re-proposed.


---

*The sections below are v1.0, retained as reference. Read them against §1b.*

## 2. What exists today (and where the gap is)

### 2.1 The #308 axis model

`SimilarityAxis` (`RelatedDocuments/SimilarityModel.swift:26`) splits axes into **generators**
(produce a bounded candidate set via keyed lookup) and **scorers** (only re-rank):

| Axis | Role | Source | Default weight |
|---|---|---|---|
| `archivalProvenance` | generator | `IndexingPipeline.archivalNeighbors` (`document_sources` ⋈ `document_cache`) | 1.0 |
| `crossReference` | generator | `CrossReferenceStore.relatedByCitation` (`cross_references` ⋈ `document_cache`) | 1.0 |
| `dateProximity` | scorer | `document_dates`, `exp(-|Δyear|/8)` | 0.5 |
| `subseries` | scorer | manifest subseries | 0.3 |
| `sharedPersons` | scorer | person rollup Jaccard | 0.7 |
| `sharedSubjects` | scorer | **inert** — doc-grain data never shipped | 0.0 |

The candidate universe is the union of the two generators (`RelatedDocumentsEngine.swift:49-51`,
pool floor 120). Both generators are archival/editorial signals: same filing location, or an
explicit `<ref>`. Topically related documents in a *different* record group, era compilation, or
subseries — with no editorial cross-reference — are structurally invisible, no matter how the
user tunes the sliders. The empty-state copy concedes the boundary: *"indexing more volumes may
surface some"* (`RelatedDocumentsView.swift:207-210`).

### 2.2 Project Leads

Leads (#377 Phase 3, "Suggested Next" on Project Home) are entirely runtime: seeds = project
collections ∪ noted docs ∪ focus-tagged docs (cap 40), each run through
`RelatedDocumentsEngine.rank` (per-seed limit 30), summed by `ProjectLeadsAggregator`, capped at
24, persisted as `ProjectLeadEntry` (a CloudKit record type — Wave R-7 gate applies to any new
stored property). **A new generator axis improves leads with zero changes to this pipeline**:
the engine picks it up, both weight-slider UIs iterate `SimilarityAxis.allCases`, and
`AxisWeights` round-trips unknown-to-old-builds cases safely.

### 2.3 Reach: everything is fenced to the local index — except one surface

Every related-docs path INNER-joins `document_cache`, so only indexed (downloaded) documents
surface. The one precedent for pointing beyond the local library is the cross-reference graph:
placeholder nodes for undownloaded targets plus a "Volume not downloaded" row with a **Download
Volume** action (`ReferenceListPanel.swift:373-469`). The #258 invariant (warn-not-seed; state
the denominator) and the QCA I-3 rule (query-shaped leads present as a **separate section,
never blended into `aggregateScore`**) are the two established guardrails an off-index tier
must respect.

### 2.4 Adjacent planned work — no collision

`QCA-Projects-Integration-Assessment.md` §I-3 ("project-vocabulary leads", Q-V rider) proposes
*project-grain* keyness → a search query → untouched matching documents. This assessment's
index is *document-grain pairwise* neighbors consumed as an axis. They are complementary: Q-V
answers "what does this project's language find?", lexical neighbors answer "what else reads
like this document?". Q-V stays query-shaped and separate; lexical neighbors blend honestly
into the axis model because they are a true generator.

---

## 3. The proposed artifact

**Grain**: unordered document pairs `(docA, docB, score)`, mirrored into per-document adjacency
at load. **Not** top-k-for-everyone: only pairs above a quality threshold τ, per-document cap
k = 5, with the pair budget (~100–150k pairs) as the binding constraint and τ emergent.

**Contents** (CloudVectorsFile sibling — int-indexed, self-contained, compact arrays):

```
{
  "version": 1,
  "generated": "YYYY-MM-DD",
  "provenance": { volumeCount, documentCount, pairCount, minScoreShipped,
                  vectorLens, tuning, dfCeiling, perDocTermCap,
                  coverage: { docsWithNeighbors, crossVolumePairShare } },
  "volumes": ["frus1861", ...],                  // 552, int-indexed
  "pairs":   [[v1, d1, v2, d2, score], ...],     // d = document ordinal (xml:id "dN");
                                                 // score quantized 0–100
  "idExceptions": { "12/305": "d305a", ... },    // the rare non-"dN" xml:ids
  "reprints": [[v1, d1, v2, d2], ...]            // near-identical pairs (score ≥ ~95),
                                                 // segregated so they never consume k slots
}
```

Two content decisions to make at implementation time, both flagged in §10:

- **Shared-term evidence.** Appending the top ~3 shared vocabulary indices per pair
  (+ a vocabulary array) costs roughly +8–12 bytes/pair (~1–1.5 MB at 120k pairs) and buys an
  honest per-row "shares: *Berlin*, *airlift*, *sector*" explanation. The zero-byte fallback:
  intersect the anchor's top terms with the target volume's already-bundled cloud-vectors
  top-50 — approximate but free. Recommend storing the 3 indices if the pair budget allows.
- **Same-volume pairs.** Cross-volume pairs are the scarce value (same-volume cousins are
  partially served by browsing and the subseries scorer). Recommend reserving ≥80% of the pair
  budget for cross-volume, admitting same-volume pairs only at a higher τ.

**Reprints are a feature, not noise.** FRUS genuinely re-prints documents across volumes;
near-identical pairs would otherwise dominate every neighbor list. Segregating score ≥ ~95
pairs both protects the k slots and creates an optional future "also printed as…" affordance.

---

## 4. The size model (why full k-NN dies and thresholded pairs live)

Calibration: `cloud-vectors-volumes.json` = 1,291,267 B for 110,400 `[termIndex, count]`
entries ≈ **11.7 B per compact int-pair entry**. A neighbor entry (`[volIdx, docOrd, score]`,
docOrd up to 4 digits, score 2 digits) is ~13–15 B; a five-int pair record ~20–24 B.

| Scenario | Entries | Est. size | Verdict |
|---|---|---|---|
| Top-10 for all 314,479 docs | 3.14 M | **~41–45 MB** | Rejected. 35× the volumes file; 4× today's entire 11.1 MB bundled-JSON total; the O-1 plan split *1.5 MB* across two files to protect a decode window. |
| Top-5 for all docs | 1.57 M | ~21–23 MB | Rejected, same grounds. |
| **Thresholded pairs, k ≤ 5, budget-capped** | **100–150k pairs** | **~2–3.5 MB** | **Recommended.** Inside the `central-files-index.json` (3.5 MB) precedent for a single lazily-decoded artifact; loaded off-main, never on the render path. |
| Doc → top-3 *volumes* only (no doc landing) | 314k × 3 | ~5–6 MB | Rejected: bigger than the pairs index and loses document-level landing — worse on both axes. |

Coverage honesty: 100–150k mirrored pairs over 314k documents means a mean degree of ~0.6–1.0 —
realistically **20–35% of documents carry ≥1 neighbor**, concentrated where lexical signal is
strong. That asymmetry is the design, not a defect: the axis contributes nothing for a routine
administrative memo and contributes strongly for a Berlin-crisis telegram with cousins in four
other volumes. The UI already handles axes that contribute nothing (score 0 → no chip). Marked,
never faked — coverage stats ship in provenance, mirroring `belowSignalThreshold`'s
"marked, never dropped" posture (decision O-4-2).

**Acceptance bar** (state it up front, O-1 style): an index over ~3.5 MB, or under ~15%
document coverage at ship threshold, means the thresholding/weighting is not working — a
finding, not a tolerance to widen.

---

## 5. Generation pipeline

New SPM trio `LexicalNeighborsGeneratorCore` / `LexicalNeighborsGenerator` / tests, mirroring
the CloudVectors layout. Env: `VOLUMES_DIR`, `MANIFEST`, `STOPWORDS`, `LEXICONS`, `OUTPUT`,
`GENERATED_DATE` plus tuning knobs. Entirely offline & deterministic.

### 5.1 Pass 1 — tokenize per document (pure reuse)

`VolumeCorpusEnumerator` (filename-sorted) → `TEIBodyTextExtractor.documents(in:)` →
`WordCloudMultiLensTokenizer.accumulate` **per document** (the runner currently merges into a
per-volume tally; this generator keeps the per-document counts — the tokenizer API already
accumulates per call). Vector basis: the **`topics` lens (open-vocabulary nouns)**, stopworded
(english + diplomatic + markings). Rationale: the curated `concepts`/`sentiment` lexicons
(170/200 terms) are far too small a basis — thousands of documents would collide on "war,
peace, treaty"; nouns carry the discriminative content (places, named things, subject matter).
The O-1 warning is direct evidence for the boilerplate risk this lens choice + stopword layers
mitigate: *"without [diplomatic stopwords] every cloud is 'telegram / department /
washington'"* (`CloudVectorsRunner.swift:56-58`). Entity lenses need the separate `.nameType`
walk and stay out of scope, exactly as they did for bundled clouds.

Cost anchor: the measured 18m53s O-1 pass is the same I/O + tokenizer work. Memory: 314k docs ×
top-96 terms × ~6 B ≈ 200 MB working set — fine for a `-c release` run on the dev machine.

### 5.2 Pass 2 — weight and prune

Document frequencies over the per-doc tallies → integer-scaled IDF weights → per-document
top-T terms (T ≈ 64–128). Drop terms with df > ceiling (~5k; kills residual boilerplate beyond
stopwords) and df < 2 (singletons cannot pair). Integer weights throughout so Pass 3 is fully
integral — no float-summation-order nondeterminism to manage.

### 5.3 Pass 3 — all-pairs similarity (the one new algorithm)

Inverted index over the pruned top-T postings; candidate pairs from shared terms; exact
weighted cosine (integer arithmetic, fixed sorted-term walk); per-doc top-k heap; global pair
ranking (score desc, composite key asc — the house tie-break) truncated to the pair budget.
Candidate volume is bounded by Σ df′² over the pruned vocabulary; the df ceiling is what keeps
it tractable, and prefix-filtering (Bayardo-style) is the standard escalation if a naive pass
measures slow. **Measure on one subseries slice first**; the full run is owner-executed once,
like O-1. Envelope: expect the corpus pass (~19 min) plus minutes-to-low-hours of APSS;
parallelizable with deterministic merge if needed.

**This is the only component without in-repo precedent, and it is the main schedule risk —
rate it medium, not low.** Everything else in this pipeline is assembly of proven parts.

### 5.4 Determinism & tests

All O-1 idioms carry over: filename-sorted scan, sorted walks, count-then-key tie-breaks at
every ranking step, quantize-before-rank, first-appearance interning (if vocabulary ships),
`sortedKeys` compact encoder, `GENERATED_DATE`. Test suite mirrors `CloudVectorsGeneratorTests`:
byte-identical repack, threshold/cap/budget behavior, reprint segregation, id-exception
round-trip, cross-volume share accounting, and a "budget respected" acceptance test. Corpus
facts to verify during implementation (the corpus is not on this machine — §9): the real score
distribution, the true share of non-`"dN"` xml:ids (the `CrossRefValidationGenerator` Pass A
id inventory is the ready-made tool), and APSS wall-clock.

---

## 6. App integration

### 6.1 Phase A — the axis (indexed candidates only; zero schema impact)

- `SimilarityAxis.lexicalSimilarity` — a **generator** (`isGenerator = true`), display name
  "Similar language" (`String(localized:)`), symbol e.g. `text.magnifyingglass`. Four
  exhaustive switches to extend; both weight-slider UIs, `AxisWeights` persistence, and the
  leads default back-fill pick it up automatically.
- `BundledLexicalNeighbors` loader on the `BundledCloudVectors` pattern: `@MainActor` enum,
  idempotent async `prepare()`, decode in `Task.detached(.utility)`, **never first-touched on
  the render path**; a 2–3.5 MB decode is inside the `CentralFilesIndexStore` precedent. Hold
  adjacency as sorted compact arrays + binary search rather than a per-doc dictionary to keep
  resident memory near artifact size.
- `LexicalNeighborGenerator`: keyed lookup → neighbors filtered to indexed docs via a batched
  `document_cache` IN-query (which also supplies the `CandidateRecord`s, same as the archival
  generator) → strengths = quantized scores (the ranker normalizes per-axis by its own max).
  Scope filtering via `scopeVolumeIds` is a trivial predicate on the volume index.
- **Default weight: 0.7, owner to confirm.** Nonzero is justified where `sharedSubjects` 0.0
  was not: this data ships curated, thresholded, and spot-checked, rather than being an absent
  upstream drop. Existing users inherit the default via the forward-compatible overlay.
- Leads improve for free: the axis flows through `RelatedDocumentsEngine.rank` inside the
  existing `ProjectLeadsService` recompute. `ProjectLeadEntry` gains no stored property — **no
  CloudKit schema deploy** (Wave R-7 gate untouched).
- New bundled resource ⇒ one `xcodegen generate` + the mandatory scheme restore; the Resources
  glob enrolls the file itself.

### 6.2 Phase B (optional follow-on) — the off-index tier

The index knows neighbors in all 552 volumes; the library usually holds a handful. For lead
seeds whose strong neighbors fall in **non-downloaded** volumes, roll them up volume-grain —
"4 strong matches for your project in *1958–1960, Berlin Crisis* (v. VIII)" — title from the
bundled manifest, evidence from shared terms, action = the established Download affordance
(`ReferenceListPanel` precedent). Presented as a **separate section** per the I-3 rule (never
blended into `aggregateScore`), computed at render time (no `ProjectLeadEntry` persistence, so
still no CloudKit impact). This would be the app's first surface that answers "which volume
should I download next *for this project*" — the research-workflow analogue of the word cloud's
zero-download story, and a partial substitute for the never-built hosted Quick-Start index.
Document-grain landing inside a non-downloaded volume is impossible by construction (no
`document_cache` row → no display record), which is why the rollup is volume-grain; the #258
"state the denominator" rule applies to the section copy.

---

## 7. Value assessment, per surface

| Surface | What the axis adds | Confidence |
|---|---|---|
| Related Documents panel | The missing *topical* generator: expands the candidate universe itself, not just the ranking. Cross-volume, cross-record-group, cross-era cousins with no editorial `<ref>` and no shared filing location become findable. Explainable rows ("shares: …") — no black box. | High for the mechanism; retrieval quality needs the §5.4 spot-check before default-on. |
| Project Leads (Phase A) | Better candidates through the same aggregator; per-project tunable; dismissals/upserts unchanged. | High (pure pass-through). |
| Project Leads (Phase B) | The first "download volume X for this project" motivator; corpus-reach discovery aligned with the app's zero-download direction. | Medium — new UX, needs the guardrails in §6.2. |
| Word-cloud/onboarding surfaces | None directly; shares tokenizer stack and vocabulary conventions. Not a goal here. | — |

Why this dodges the failure that killed doc-grain subjects (#261/#308): that data was an
upstream drop with uniform coverage ambitions and no quality floor, and its noise only washed
out at volume grain. This artifact is the opposite posture — corpus-derived, thresholded,
budget-capped, coverage-honest, reprint-segregated, and shipped behind a user-visible weight
slider. Precision-first is the entire design.

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Boilerplate similarity (telegraphic prose, salutations, chrome) | Documented phenomenon with a documented mitigation stack: english+diplomatic+markings stopwords, IDF, df ceiling, threshold τ, and the spot-check panel gating default-on. |
| Reprint near-duplicates crowd neighbor lists | Segregated `reprints` tier at score ≥ ~95; separately useful. |
| APSS runtime blow-up | df ceiling bounds candidates; prefix filtering as escalation; measure on a subseries slice before the full run. Medium risk, one-off owner-executed cost. |
| Artifact staleness vs corpus | Same posture as every bundled index: regenerate on refresh; manifest-filtered scan ignores the 694-vs-552 extra files; provenance pins tuning + inputs (hash inputs like `VolumeSubjectProfilesGenerator` pins its drop's md5). |
| Non-`"dN"` xml:ids break the ordinal encoding | `idExceptions` side table; measure the real share with the existing id-inventory tooling before finalizing the encoding. |
| Decode/memory on device | 2–3.5 MB lazy off-main decode (≤ existing 3.5 MB precedent); compact-array residency; never render-path-touched (the BundledCloudVectors rule). |
| Tokenizer drift between artifact and app | Same structural answer as O-1: WordCloudKit compiled into both; parity suite already pinned; artifact provenance records lens + tuning. Body text remains the extractor's *approximation* of `IndexingPipeline.extractBodyText` — acceptable here for the same reason it was acceptable for clouds (scores, not rendering). |
| Retrieval quality disappoints anyway | The axis defaults to a slider the user can zero; worst case parallels `sharedSubjects` (ship at weight 0 / opt-in) rather than a rip-out. |

## 9. Alternatives considered

- **Full-corpus k-NN bundle — rejected** (§4: 40+ MB).
- **Runtime "more like this" via FTS5 (no artifact)** — extract the anchor's top TF-IDF terms
  (`fts5vocab` gives df) and run a BM25 OR-query. Viable and cheap, but: indexed-volumes-only
  forever (no Phase B story), per-view query cost, results vary with library composition, no
  curation/threshold pass, and it duplicates rather than joins the axis model's keyed-generator
  contract. Worth keeping in the back pocket if generation quality disappoints; note Q-V/I-3
  already claims the `fts5vocab` keyness machinery at project grain.
- **Semantic embeddings (NLEmbedding / FoundationModels) — rejected for this artifact.**
  314k × 512-float vectors ≈ 600 MB before any ANN structure; OS-version-dependent models break
  the deterministic-artifact contract; unexplainable rows. On-device semantic re-ranking of an
  already-bounded candidate set is a separate, later idea.
- **Hosted per-volume neighbor shards** — no hosting exists (volumes come from HistoryAtState's
  GitHub; the approved Quick-Start hosted index was never built). Revisit only if a future
  hosted-artifact channel appears.

## 10. Recommendation & open decisions

Proceed as a small workstream (~3–5 sessions): **L-1** generator core + tests + subseries-slice
calibration; **L-2** full-corpus run, spot-check panel, artifact + acceptance bar; **L-3**
loader + axis + both-surface integration; **L-4 (optional)** Phase B off-index leads tier.

Owner decisions to confirm before L-1:
1. Pair budget / size bar (proposed: ~120k pairs, ≤3.5 MB, ≥15% coverage floor).
2. Vector lens basis (proposed: `topics` nouns; alternative: nouns + curated concepts boost).
3. Shared-term evidence in-artifact (proposed: yes, 3 term indices per pair) vs the free
   volume-vocabulary intersection approximation.
4. Same-volume pair admission (proposed: ≥80% of budget reserved cross-volume).
5. Default weight 0.7 vs opt-in 0.0 pending the spot-check panel's precision result.
6. Phase B in or out of initial scope (proposed: out; ship A, evaluate, then decide).

**What this assessment could not verify** (corpus absent from this machine): real cosine/score
distributions, true coverage at any τ, APSS wall-clock, and the non-`"dN"` id share. All four
are measurable in L-1 with existing tooling, and the acceptance bar exists precisely so those
measurements — not this document's estimates — make the ship/no-ship call.
