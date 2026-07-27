# Document-Level Lexical Similarity Neighbors — Feasibility & Value Assessment

**Version**: 1.0
**Date**: 2026-07-27
**Status**: Assessment — recommended: a precision-first, budget-capped bundled neighbor index
(CloudVectorsGenerator sibling) consumed as a third *generator* axis; a full-corpus k-NN
artifact is rejected on size.

---

## 1. The question, and the verdict

Can we generate a bundled index of document-level lexical-similarity neighbors — the same way
Workstream O produced `cloud-vectors-core.json` / `cloud-vectors-volumes.json` — and surface it
as another axis in Related Documents and/or Project Leads? Is it worth doing?

**Verdict: feasible, and valuable — but only in a precision-first shape.**

- **Feasible.** Every piece of offline scaffolding the generator needs already exists and is
  parity-tested: `VolumeCorpusEnumerator`, `TEIBodyTextExtractor` (per-document body text),
  `WordCloudMultiLensTokenizer` (one `NLTagger` pass, injected stopwords/lexicons), the
  determinism idioms, and the `BundledCloudVectors` loader pattern. The measured O-1 baseline —
  **552 volumes, 314,479 documents, 3.34 GB TEI, 18m53s** for a full single-threaded
  tokenization pass — bounds the new generator's dominant I/O cost. Exactly one genuinely new
  algorithmic component is required: all-pairs similarity search (APSS) over ~314k sparse
  TF-IDF vectors, a well-understood problem at this scale (§5.3).
- **The decisive constraint is artifact size, and it forces the design.** A conventional
  "top-10 neighbors for every document" index is **~40–45 MB** of JSON (§4) — 35× the largest
  cloud-vectors file, 4× the entire current 11.1 MB bundled-JSON footprint, and far outside the
  house `Data(contentsOf:) + JSONDecoder` pattern. A **thresholded strong-pairs index
  (~100–150k pairs, ~2–3.5 MB)** fits inside existing precedent (`central-files-index.json` is
  3.5 MB) and concentrates exactly where the value is: high-confidence topical cousins,
  weighted toward cross-volume pairs no existing axis can find.
- **Valuable because it fills the one gap the #308 axis model documents about itself.** The
  Related Documents candidate universe is the union of the *two* generators only — archival
  provenance and explicit editorial cross-references. Nothing today says "these two documents
  are about the same thing": the shared-subjects axis has been inert since #261/#308 (document-
  grain subject data was too noisy to ship; `DocumentSubjectStore.shared` is hard-coded `nil`),
  and persons/date/subseries only re-rank candidates the two generators already produced. A
  lexical-neighbor index is a *generator*-shaped axis — a bounded keyed lookup — and the
  plumbing was built expecting it: `ProjectLeadsService.effectiveWeights` explicitly back-fills
  "a future semantic-proximity axis" with its default weight rather than an implicit 0
  (`ProjectLeadsService.swift:46-47`).

Recommended shape: **Phase A** — generator + bundled index + `SimilarityAxis.lexicalSimilarity`
(indexed-candidates-only, zero schema impact, ~2–3 sessions). **Phase B (optional follow-on)** —
the off-index tier: "strong matches in volumes you haven't downloaded" as a separate leads
section with a download affordance (~1–2 sessions). §6 details both.

---

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
