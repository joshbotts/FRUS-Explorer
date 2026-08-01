# OS 27 — Semantic Retrieval: Siri Distribution, Natural-Language Search, Similarity Axis

**Status:** design sketch, unreviewed. Written against **beta** documentation and third-party WWDC26 write-ups — every OS-27 API claim below is marked **[V]** verified against Apple's own material or **[U]** unverified/second-hand. No claim here has been exercised against the Xcode 27 beta SDK. Read §8 before scheduling.
**Issue:** none yet — no open issue covers App Intents, Spotlight semantics, or embeddings (searched 2026-08-01).
**Related:** #308 (multi-axis related-documents model — the axis in §5 extends it), #377 Phase 3 (Project Leads), #488 (the CloudKit schema-deploy tax that §5.3 is designed to avoid), Session 154 (`rebuildSpotlightIndex()`)
**Date:** 2026-08-01

---

## 1. Three workstreams, deliberately separate

"Semantic index" names three different mechanisms with different owners and opposite directions of data flow. Conflating them is the main risk this document exists to prevent.

| # | Workstream | Direction | Mechanism | OS floor | Ships |
|---|---|---|---|---|---|
| **A** | Siri distribution | app → **system** | `IndexedEntity` + App Intents schemas | iOS 27 | on 27 adoption |
| **B** | Natural-language search | app → **own** index | `CSUserQuery` + ranked results | **iOS 18** | **now** |
| **C** | Similarity axis | app → **own** vectors | `NLContextualEmbedding` / Core AI | **iOS 17** / 27 | now / on 27 |

Only **B** and **C** are retrieval. **A** is discovery — it makes FRUS content findable *by Siri*, and returns nothing your code can query.

The scheduling consequence: **B and C do not depend on OS 27 at all.** Both clear the current `deploymentTarget: 26.0` with room to spare and need no `#available` gating. Only A does. If the 27 timeline slips or the beta proves unstable, B and C proceed untouched.

---

## 2. OS 27 migration exposure (verified against source, 2026-08-01)

Establishing the floor first, because it is unusually low and shapes how much of the 27 cycle is discretionary.

| Change | Exposure |
|---|---|
| **UIScene lifecycle mandate** — non-adopting apps fail to launch **[V]** | **None.** SwiftUI `@main App` is already scene-based. `FRUSAppDelegate` (`App/FRUSExplorerApp.swift:206`) implements only `handleEventsForBackgroundURLSession` — not a deprecated lifecycle method. |
| **`UIDesignRequiresCompatibility` removed** from Xcode 27 **[V]** | **None.** Never set; on Liquid Glass since 26. |
| **`ImageCreator` discontinued** **[V]** | Not used. |
| **SiriKit deprecated → App Intents** **[V]** | Not used. This is workstream A's *opportunity*, not a migration. |
| **SceneKit → RealityKit** | Not used. |
| **`UIScreen.main` deprecated** | **One hit:** `Analytics/WordCloud/FrameTimeProbe.swift:301` (`maximumFramesPerSecond` in a debug probe). Migrate to `windowScene.screen`. Trivial. |

**Everything in §§3–5 is discretionary.** Nothing on 27 forces work beyond one line in a debug probe.

---

## 3. Workstream A — `IndexedEntity` and App Intents

### 3.1 What it buys

Adopting `IndexedEntity` on an App Intents entity contributes app content to the **system's** semantic index, so Siri surfaces it conversationally with attribution back to the app **[V]**. Intent schemas let users act on that content with no fixed phrases and no code changes as Siri's language understanding expands **[V]**. The View Annotations API maps on-screen views to entities so a user can reference what they are looking at **[V]**.

For a 552-volume searchable diplomatic corpus this is the highest reach-per-unit-effort item in the document: FRUS content becomes answerable at the system level rather than only inside the app.

### 3.2 What already exists

The substrate is largely built, which is what makes this cheap:

- `IndexingPipeline.submitSpotlightItems(for:)` (`Search/IndexingPipeline.swift:1655`) donates one `CSSearchableItem` per document at index time.
- `makeSearchableItem` (`:1667`) builds the attribute set from `document_cache` fields.
- `rebuildSpotlightIndex()` (`:1690`) re-donates the whole corpus without re-parsing XML.
- Volume deletion already clears its Spotlight domain (`:1412`).
- `FRUSExplorerApp.swift:1158` handles `CSSearchableItemActionType` continuation into `continueDocumentActivity` → deep link, with the #338 no-spawning-window case handled.

So donation, teardown, rebuild, and the landing path all exist. What is missing is the App Intents layer above them — `import AppIntents` matches nothing outside the widget target.

### 3.3 The open structural question

**Does `IndexedEntity` layer on top of existing `CSSearchableItem` donation, or replace it? [U]**

This is the one question that changes the size of the work, and it could not be settled from documentation. Two outcomes:

- *Additive* — define `AppEntity` + `IndexedEntity` conformances, keep the existing donation path, and the system links them. Small.
- *Replacing* — re-express donation through the entity layer, which touches `submitSpotlightItems`, `makeSearchableItem`, `rebuildSpotlightIndex`, and forces a full-corpus re-donation on upgrade for every existing user. Substantially larger.

**Resolve this against the Xcode 27 beta before estimating A.** Do not schedule it on the assumption of the additive case.

### 3.4 Sketch

- `FRUSDocumentEntity: AppEntity, IndexedEntity` — keyed by the existing `"\(volumeId)/\(documentId)"` composite, which is already the `CSSearchableItem.uniqueIdentifier`. Identity is free.
- `CSSearchableIndexDelegate.searchableItems(forIdentifiers:)` **[V]** — lets the system re-request full metadata lazily, so the donated payload can stay thin while the entity resolves richly on demand. This is the natural seam for the §4.2 payload problem.
- Candidate intents: open document, search corpus, summarize document (routes to the existing `SummarizationProvider`), add to collection.

---

## 4. Workstream B — `CSUserQuery` natural-language search

### 4.1 The API, and a correction

`CSUserQuery` with `CSUserQueryContext.enableRankedResults = true`, sorted with the `compareByRank` comparator, gives the app **direct programmatic semantic search over its own Core Spotlight index** — per-app, entirely local, never leaving the device **[V]**.

**This is not new in 27.** It shipped at WWDC24 (iOS 18) **[V]**. It has been available to this app for its entire supported range. Any plan that schedules it behind the 27 adoption is mis-sequenced.

Separately, iOS 27 adds **`SpotlightSearchTool`** **[V]** — a `Tool` conformer attached to a `LanguageModelSession` where the *model* writes the queries and reasons over results. Interesting for a conversational "chat with the corpus" surface, and it composes with the existing `SummarizationProvider` stack. It is the wrong shape for computing a ranked axis over thousands of candidates (§5.1), and it is a **separate** feature from B — do not merge them.

### 4.2 The blocker: the donated payload is nearly empty

```swift
// Search/IndexingPipeline.swift:1669
let attrs = CSSearchableItemAttributeSet(contentType: .text)
attrs.title = header.isEmpty ? documentId : header
attrs.contentDescription = String(bodyText.prefix(300))
attrs.keywords = [volumeId, documentId]
```

`attrs.textContent` — the full-text property semantic search is designed to match against — **is never set**. Today's index carries a title and 300 characters. Semantic search over that is barely semantic, and it caps workstream A's quality too (§3), since the system index is the same one Siri reads.

**Decision required.** Options, in preference order:

1. **Set `textContent` to a bounded extract** (first ~2–4 KB of `body_text`). Bounded index growth, most of the topical signal, no delegate work.
2. **Thin payload + `CSSearchableIndexDelegate`** (§3.3) — donate little, resolve full metadata on request. Best if A lands additively; more moving parts.
3. **Full body text.** Rejected: at corpus scale the system index growth is unbounded and unmeasured, and Spotlight storage is not the app's to spend.

Whichever is chosen, **existing users need a `rebuildSpotlightIndex()` run on upgrade** to benefit. That path already exists and does not re-parse XML, but it is a full-corpus pass and needs the same "honest progress, cancellable" treatment as other long index operations.

### 4.3 Honest-empty behaviour

Results are bounded by *indexed* volumes, exactly like Archival Neighbors. Reuse that framing verbatim — an empty result is a true answer about the user's index, not a failure, and the existing copy already says so well.

---

## 5. Workstream C — a `semanticSimilarity` axis for #308

### 5.1 Why not Spotlight

The tempting shortcut is query-by-example: feed the anchor document's text to `CSUserQuery` and treat the ranked results as neighbours. It fails against the #308 architecture for three reasons, the first structural.

**(a) It can only ever be a generator.** The #308 design §6.2 split — generators produce bounded candidate sets, scorers batch-rank an existing set and never enumerate — is what keeps `RelatedDocumentsRanker` tractable. Spotlight exposes **no pairwise API**: there is no way to ask "how similar are document A and document B" **[V]** — no embeddings, no similarity scores, no more-like-this call. So a Spotlight axis could contribute candidates but could never re-score the candidates `archivalProvenance` and `crossReference` generated. A document that is semantically a perfect match but fell outside Spotlight's top-N would score **zero** on the axis rather than "high" — silently, and indistinguishably from a genuine non-match.

**(b) The rank is an uncalibrated ordinal.** `AxisWeights` computes `Σ weight[axis] × axisScore[axis]` over scores the app defines and normalises. Spotlight's rank has no documented scale. Mixing it in distorts the other five axes' weights in a way the tuning UI would misrepresent.

**(c) It inherits §4.2.** Query-by-example against a title and 300 characters is not a similarity measure.

Embeddings solve all three. Note this is a *narrow* rejection: Spotlight remains right for workstream B, where a user-supplied query string is the actual input.

### 5.2 The axis

Add to `SimilarityAxis` (`RelatedDocuments/SimilarityModel.swift`):

```
case semanticSimilarity
```

- **Role: both generator and scorer.** Pairwise cosine makes it a true scorer (batch-score a bounded candidate set); top-N over the vector store makes it a generator. It is the first axis to be both — `isGenerator` returns `true`, and the ranker must be checked to confirm a generator is also invoked in the scoring pass rather than assumed disjoint.
- **`defaultWeight`: `0.0`**, following the `sharedSubjects` precedent (#308 design Q4). Ships opt-in behind explicit "experimental" framing; does not reshape existing results on upgrade.
- `displayName`: "Similar wording" or "Semantically similar" — deliberately *not* "related," which every axis is. `systemImage`: `"text.magnifyingglass"`.
- The existing "why related" chips need a per-row explanation for this axis. Cosine is not self-explaining the way "cited by" or "same lot file" is; a row that appears with no visible justification reads as noise. Weakest part of the UX story — treat as an open question, not a solved detail.

### 5.3 Storage: SQLite, **not** SwiftData

**Vectors go in the FTS5/SQLite store alongside `document_cache`. They must not become a `@Model`.**

Three reasons, the first decisive:

1. **The #488 tax.** Any new `@Model` or stored property trips `CloudKitSchemaInventoryTests` and requires a Production schema deploy before shipping. Embeddings are *derived* data — recomputable from indexed volumes — and would drag a rebuild-from-corpus artifact into the sync schema permanently.
2. **Volume.** Order of 250k+ documents at full corpus. At 512 dims × `Float32` that is ~2 KB/doc ≈ **500 MB**; `Float16` halves it to ~250 MB. Either way this is not CloudKit-shaped data.
3. **Platform dimension mismatch [U].** `NLContextualEmbedding` is reported as **512-dimensional on iOS and 768-dimensional on macOS**. If true, synced vectors would be dimensionally incompatible across a user's own devices. Per-device local computation sidesteps this entirely. **Verify before any storage design** — and note that if it holds, it also means iPhone and Mac can legitimately produce *different* related-document rankings for the same anchor, which the UI should not claim is deterministic.

Lifecycle: compute per-volume at index time inside the existing `DownloadManager` → `IndexingPipeline` flow; delete with the volume alongside the FTS5 and Spotlight teardown at `:1412`; make it resumable, since a full-corpus embed is long.

### 5.4 Compute cost — the real risk

Embedding 250k+ documents on-device is the largest unknown here and the most likely reason C slips.

- **`NLContextualEmbedding`** (iOS 17+, on-device, three script models — Latin covers 20 languages) requires an **asset download** before use: check `hasAvailableAssets`, call `requestAssets`, then `load()` **[V]**. It can therefore be *unavailable at first run*, which needs the same graceful-degradation treatment `AppleIntelligenceProvider.isAvailable` already gives summarization. Reuse that pattern.
- It produces **per-token sequences**, not a document vector. A pooling strategy (mean-pool, or pool over a bounded head extract) must be chosen and **pinned in the artifact**, because changing it silently invalidates every stored vector — the same class of hazard `BundledKeynessBaseline` guards with its tokenisation pin. Follow that precedent: store the pooling strategy and model identity alongside the vectors and refuse to mix.
- **Core AI** (iOS 27) is the alternative if a stronger sentence-embedding model is wanted — purpose-built for on-device inference with ahead-of-time compilation and fine-grained memory control **[V]**. It is the only part of C that is OS-27-gated, and it is optional.

**Prototype before committing.** Embed one mid-size volume, measure wall-clock and storage on the oldest supported hardware, and extrapolate. If a single volume is not comfortably inside the existing indexing budget, C needs rescoping — reduced dimensions, header-plus-lede embedding rather than full body, or an opt-in per-volume toggle rather than automatic coverage.

### 5.5 Project Leads (#377 Phase 3)

`ProjectLeadsService` currently merges per-axis scores across every seed, and `ProjectLeadEntry.aggregateScore` sums relatedness across seeds. Embeddings enable a better primitive:

**Compute a project centroid** from the seed documents' vectors and retrieve nearest neighbours to the centroid in one pass. Cheaper than N per-seed queries, and semantically better — it finds documents near the project's thematic centre rather than near any single seed, which is closer to what a "lead" means.

**The catch:** a centroid query destroys per-seed attribution, and `contributingSeedKeys` exists precisely to power the "related to N of your documents" affordance. So the shape is **centroid for generation, per-seed cosine for attribution** — retrieve against the centroid, then batch-score the bounded result set per seed to repopulate `contributingSeedKeys`. Which is exactly the #308 §6.2 generator/scorer split, reused.

Note `ProjectLeadEntry` **is** CloudKit-synced. Leads computed on a Mac and on an iPhone may differ if §5.3(3) holds. `lastComputedAt` already exists to reason about staleness; whether last-writer-wins across devices is acceptable here is an open question.

---

## 6. Phasing

Ordered by *dependency*, not by value. B0 unblocks both A and B, so it goes first despite being the least visible.

| Phase | Work | OS floor | Depends on |
|---|---|---|---|
| **B0** | Resolve §4.2 payload decision; set `textContent`; upgrade-path `rebuildSpotlightIndex()` | 26 | — |
| **B1** | `CSUserQuery` natural-language search surface | 26 | B0 |
| **A0** | **Spike:** settle §3.3 (additive vs replacing) on Xcode 27 beta | 27 | — |
| **A1** | `FRUSDocumentEntity` + intents; Siri surfaces | 27 | A0, B0 |
| **C0** | **Spike:** §5.4 cost + §5.3(3) dimension check on one volume | 26 | — |
| **C1** | Vector store, index-time compute, teardown | 26 | C0 |
| **C2** | `semanticSimilarity` axis in #308 ranker, weight 0 | 26 | C1 |
| **C3** | Project-lead centroid retrieval | 26 | C2 |

Both spikes (A0, C0) are cheap and gate the two largest estimates. Run them before committing anything downstream.

`SpotlightSearchTool` conversational search is deliberately **not** phased here — it is a distinct feature that should get its own design once B has established what the index actually contains.

---

## 7. What this does not do

- **No new `@Model`, no CloudKit schema deploy** — by construction (§5.3). The one exception is if C3 needs new fields on `ProjectLeadEntry`, which would carry the full #488 checklist.
- **No change to FTS5 search.** Workstream B is an *additional* surface, not a replacement for BM25 lexical search. FRUS researchers rely on exact-phrase and proximity behaviour that semantic ranking does not reproduce; presenting semantic results as an upgrade would be a regression for the primary use case.
- **No document-grain subject data.** Orthogonal to #261/#308 Phase 3, and neither blocks the other.

---

## 8. Open questions

1. **§3.3 — is `IndexedEntity` additive to existing `CSSearchableItem` donation?** Gates A's estimate. Beta spike.
2. **§4.2 — which payload option?** Gates B and caps A's quality. Needs an index-growth measurement, not a guess.
3. **§5.3(3) — does `NLContextualEmbedding` really differ 512/768 across iOS and macOS?** Gates C's storage design and the determinism claim in C3.
4. **§5.4 — is on-device embedding affordable at corpus scale on the oldest supported hardware?** The single most likely reason C does not ship as specified.
5. **§5.2 — what is the per-row "why related" explanation for a cosine axis?** Unsolved. An unexplained row is worse than an absent one.
6. **§5.5 — is last-writer-wins acceptable for cross-device lead divergence?**
7. Should B's results be a separate surface or a mode toggle inside existing search? Affects whether §7's "not a replacement" boundary is legible to the user.

---

## 9. Sources

OS-27 claims rest on beta-period material, not shipped documentation:

- [What's New — iOS, Apple Developer](https://developer.apple.com/ios/whats-new/)
- [Build intelligent Siri experiences with App Schemas — WWDC26 session 240](https://developer.apple.com/videos/play/wwdc2026/240/)
- [What's new in the Foundation Models framework — WWDC26 session 241](https://developer.apple.com/videos/play/wwdc2026/241/)
- [LLM search using Core Spotlight — WWDC26 session 246](https://developer.apple.com/videos/play/wwdc2026/246/)
- [Support semantic search with Core Spotlight — WWDC24 session 10131](https://developer.apple.com/videos/play/wwdc2024/10131/) (the `CSUserQuery` source)
- [Explore Natural Language multilingual models — WWDC23 session 10042](https://developer.apple.com/videos/play/wwdc2023/10042/) (`NLContextualEmbedding`)
- [`NLContextualEmbedding.hasAvailableAssets`](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding/hasavailableassets)

Version history:
  1.0 — 2026-08-01: initial design sketch (unreviewed)
