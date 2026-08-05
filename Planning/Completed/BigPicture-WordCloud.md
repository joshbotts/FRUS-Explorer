// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

# Word Cloud Analytics

**Status:** Implemented 2026-06-26 (decisions 1–3 = recommended; decision 4 = spiral built).
**All phases (1–4) complete.** Core pipeline, spiral cloud + accessible ranked view,
PNG/PDF/CSV export, iOS/macOS presentation, all seven scope entry points, heavy-scope
on-disk cache + determinate progress, plus the Phase 4 polish: plural-folding fallback,
per-scope hide-word overrides, side-by-side comparative clouds, and word-cloud overview
pages embedded in collection PDF/HTML exports. Shipped and tested.
**Priority:** Medium (feature backlog) — complete
**Estimated effort:** Done.

---

## Problem Statement

FRUS Explorer's analytics today answer **"how is this term distributed?"** — the user
supplies a term and `CorpusAnalyticsService` charts matching-document counts by year,
decade, subseries, or volume. There is no way to ask the inverse, exploratory question:
**"what are the salient terms in *this* body of material?"** A word cloud answers exactly
that, and is valuable across many different "bodies of material" a researcher works with —
a single document, a volume, a subseries, the whole corpus, or their own curated sets
(collections, user tags, saved searches).

The inverse direction is currently a stub: `CorpusAnalyticsService.topTermsByYear(year:limit:)`
returns `[]`. So this is genuinely new computation, not a reskin of the existing charts.

---

## Feasibility — all 7 scopes are feasible

Every requested scope reduces to the **same primitive**: a resolvable set of
`(volumeId, documentId)` pairs whose `bodyText` is retrievable from `document_cache`.
Once a scope is resolved to its document set, the word-cloud pipeline is identical. Scopes
differ only in (a) how the document set is resolved and (b) compute cost.

| Scope | Resolution path | Cost tier |
|---|---|---|
| **Document** | The document itself | Trivial |
| **Volume** | `IndexingPipeline.documents(forVolume:)` (exists) | Cheap |
| **Collection** | `Collection.documentEntries` → `CollectionEntry(volumeId, documentId)` | Cheap |
| **Saved search** | `SavedSearch.searchParameters` → re-run `SearchService` → result doc set | Cheap–moderate |
| **User tag** | `document_cache.user_tag_ids` (space-separated UUIDs); **new helper needed** | Cheap–moderate |
| **Subseries** | Manifest → member volume IDs → their documents | Moderate–heavy |
| **Corpus** | All indexed documents | **Heavy — needs a distinct strategy** |

All but **corpus** (and very large subseries) are bounded sets that can be tokenized on
the fly. Corpus is the only scope that must not be tokenized word-by-word in Swift on iOS.

---

## Architecture

### 1. One scope abstraction

A single `WordCloudScope` enum funnels all 7 entry points into one pipeline:

```
WordCloudScope → [(volumeId, documentId)] → bodyText → tokens → counts → top-N TermCount
```

```swift
/// Identifies a body of FRUS material to compute a word cloud over. Every case
/// resolves to a set of (volumeId, documentId) document keys.
enum WordCloudScope: Hashable, Sendable {
    case document(volumeId: String, documentId: String)
    case volume(volumeId: String)
    case subseries(subseriesId: String)
    case corpus
    case collection(id: UUID)
    case userTag(id: UUID)
    case savedSearch(id: UUID)
}
```

A `signature` (stable string key) is derived from the case for caching, mirroring how
`CorpusAnalyticsService` caches by query term.

### 2. `WordFrequencyService` (actor)

A sibling to `CorpusAnalyticsService`, same caching idiom (in-memory, bounded, with
`invalidateCache()` called when the FTS index changes — user-content scopes also
invalidate on tag/collection edits). Responsibilities:

1. **Resolve** the scope → `[(volumeId, documentId)]` (delegates to existing APIs;
   adds one new tag-resolution helper on `IndexingPipeline`).
2. **Fetch** `bodyText` for those documents, batched (reuse the existing batched
   document-fetch paths; cap batch sizes on iOS as IndexingPipeline already does).
3. **Tokenize** with **NaturalLanguage** (`NLTokenizer` for word segmentation; optional
   `NLTagger` lemmatization). Lowercase; drop numbers, punctuation, tokens shorter than a
   threshold, and stopwords.
4. **Count** and return the top-N as the **existing `TermCount` struct** — no new model.

```swift
actor WordFrequencyService {
    func topTerms(for scope: WordCloudScope, limit: Int) async throws -> [TermCount]
    func invalidateCache()
}
```

NaturalLanguage is built-in, on-device, free, and **not yet used in the project** — adds
no dependency.

### 3. Tokenization & normalization

- **Lemmatization (recommended default):** merge inflected forms to a readable lemma
  ("negotiations" → "negotiation"). Produces more readable, less fragmented clouds than the
  FTS English stemmer (which yields stems like "diplomaci"). Decision flagged below.
- Filter: numbers, single/double-character tokens, and stopwords.

### 4. Stopwords (bundled resource)

`Resources/word-cloud-stopwords.json`, in two layers:

- **English layer** — standard high-frequency function words. Always on.
- **Diplomatic-boilerplate layer (optional)** — domain words that otherwise dominate every
  FRUS cloud ("telegram", "department", "washington", "secretary", "embassy", …). This is
  *editorially opinionated* and must be user-toggleable, defaulting on. Decision flagged below.

### 5. Corpus strategy (do not brute-force on iOS)

Two viable paths:

- **Background + on-disk cache (recommended first):** compute corpus/large-subseries clouds
  as a background task with progress, cache the result to disk keyed by index version. These
  scopes change rarely, so a cached result serves most opens. Reuses the bounded-scope code.
- **`fts5vocab` (`row`) table:** create once for a fast global top-terms query. Returns
  stemmed FTS vocabulary (not lemmas) and only supports the *whole* index cleanly (the
  `instance` variant supports subsets but is heavy to scan). Add later only if corpus latency
  demands it.

Recommendation: ship background+cache; treat `fts5vocab` as a later optimization.

---

## Rendering & Accessibility

- `WordCloudView(scope:)` with two view modes, mirroring the existing
  `AnalyticsViewMode.chart/.table` toggle:
  - **Cloud** — visual tag cloud. Font size ∝ √(count) so glyph *area* encodes frequency.
    Layout: deterministic Archimedean-spiral placement with bounding-box collision in a
    `Canvas`. (This is the only genuinely fiddly part — see Phasing.)
  - **Ranked list / table** — term + count, sortable. This is *also the accessibility
    representation*.
- **Accessibility is mandatory.** A word cloud is opaque to VoiceOver, and
  `CodingStandardsAuditTests` already enforces `accessibilityRepresentation` on the
  cross-reference graph. The cloud must expose the ranked list via
  `accessibilityRepresentation`, and honor Dynamic Type / `reduceMotion` (no layout
  animation under reduce-motion).
- **Interaction:** tapping a word runs a scoped search for that term via the existing
  `pendingSearch` handoff — same "drill from analytics into documents" affordance the
  Analytics ↔ Search handoff already provides.

---

## Export

**No image-export infrastructure exists today** — the Collections exporters
(`PDFCollectionExporter`, `HTMLCollectionExporter`, `DocxCollectionExporter`,
`ZoteroCollectionExporter`) are document-content exporters only. New work:

- **PNG / PDF image:** rasterize `WordCloudView` with SwiftUI `ImageRenderer` at high scale.
- **CSV** (`term,count`): trivial and the most useful research artifact — prioritize it.
- **Embed** the cloud image into existing PDF/HTML **collection** exports (optional, later).
- Define `UTType` entries as needed; route through the platform share sheet (iOS) /
  `NSSavePanel` (macOS), consistent with existing export flows.

Update `FRUS-API.openapi.yaml` if any exported artifact's shape is part of the documented
API surface (per Coding Standards).

---

## Integration into the App

Treat the word cloud as a **cross-cutting analytics output**, reachable from each scope's
own context rather than buried in the Analytics tab.

- **Handoff:** add `pendingWordCloud: WordCloudScope?` to `AppState`, mirroring the
  established `pendingSearch` / `pendingAnalytics` / `pendingChronology` /
  `pendingBrowseDocument` pattern. Any view sets it; the host presents the cloud and clears
  it once consumed.
- **Entry points:**
  - Document view — toolbar/overflow menu "Word cloud".
  - Volume & Subseries browser — context menu.
  - Collection editor — Export menu + a "Word cloud" action.
  - Tag detail — "Word cloud" action.
  - Saved-search row — "Word cloud" action.
  - Corpus — a new **Word-cloud view mode** in the Analytics tab, alongside the existing
    chart/table modes.
- **macOS:** a dedicated `frus.wordcloud` window scene, consistent with the other analytics
  windows (Search, Browser, CrossReference, SourceExplorer, Collections).

---

## Open Decisions (settle before building)

1. **Token normalization** — lemmatized readable forms (recommended) vs. raw surface forms
   vs. FTS-matching stems.
2. **Stopwords** — English-only vs. include the opinionated diplomatic-boilerplate layer
   (recommended on-by-default, user-toggleable).
3. **Corpus approach** — background + cache (recommended) vs. invest in `fts5vocab` now.
4. **Layout ambition** — ship the accessible ranked/weighted view first and add the spiral
   tag-cloud after (recommended), vs. build the spiral layout up front.

---

## Phasing

- **Phase 1 — Core pipeline (bounded scopes).** `WordCloudScope`, `WordFrequencyService`,
  NaturalLanguage tokenization, stopwords resource, tag-resolution helper. Ranked/table view.
  CSV export. Scopes: document, volume, collection, user tag, saved search. *No spiral
  layout, no corpus.* Fully accessible and testable on its own.
- **Phase 2 — Visual cloud + image export.** Spiral `Canvas` layout, `ImageRenderer`
  PNG/PDF export, tap-to-search, `reduceMotion`/Dynamic Type handling,
  `accessibilityRepresentation` wired to Phase 1's list.
- **Phase 3 — Heavy scopes. ✅ Done.** Subseries and corpus persist their results to disk
  (`WordCloudDiskCache`, keyed by the `document_cache` row-count fingerprint) so they survive
  relaunch, and report determinate progress during computation (`WordCloudProgress` →
  `WordCloudProgressModel`). The corpus entry lives in the Browse toolbar (iOS) and the
  macOS window scene. `fts5vocab` remains an unimplemented future optimization.
- **Phase 4 — Polish. ✅ Done.**
  - **Plural-folding fallback** (`WordCloudTokenizer.singularize`) merges plurals the
    lemmatiser misses (`treaties`→`treaty`), with an exception set for `-is`/`-us`/`-ss`/`-ous`.
  - **Per-scope hide-word overrides** (`WordCloudOverrides`, UserDefaults): long-press a word
    to hide it from that scope's cloud (persisted, threaded through the service as
    `extraStopwords` and into the cache keys); "Show N hidden words" restores them.
  - **Comparative clouds** (`WordCloudComparisonView` + `ComparativeCloudColumn`): "Compare
    with…" picks a second scope (corpus, a collection, or a tag) shown side-by-side (wide) or
    stacked (compact). Shared `WordCloudLoader` keeps resolve→compute in one place.
  - **Collection export embedding**: an opt-in "Include word cloud overview" toggle adds a
    cloud page to PDF exports and a base64 `<figure>` to HTML exports
    (`WordCloudExporter.collectionCloudImage`, tokenising the documents' own body text — no
    index round-trip).
  - *Not done:* the `fts5vocab` corpus optimization remains a future option (background+cache
    is sufficient in practice).

- **Background precompute (iOS).** Heavy scopes are precomputed off the main thread by the
  existing indexing `BGProcessingTask`. `WordCloudPrecomputeQueue` (UserDefaults) holds
  pending scope signatures; the corpus is enqueued whenever indexing completes (its
  fingerprint just changed); the BG handler drains the queue after indexing via
  `WordCloudLoader.precompute`, writing each result to `WordCloudDiskCache` so the user opens
  it instantly. `WordCloudScope(signature:)` reconstructs scopes from the persisted queue.
  Gated by a "Precompute word clouds in background" toggle in **Settings → Storage & Index**
  (default on). Drains within budget and resumes (cancelled jobs stay queued). This is step 1
  of reusing the indexing background/widget infrastructure; generalising the Live Activity
  contract and adding background bulk summarization are the remaining steps (the latter gated
  on on-device FoundationModels-in-background verification).

---

## Prerequisites / References

- `CorpusAnalyticsService` (caching idiom, `TermCount`, scope handoff via `AnalyticsParameters`)
- `IndexingPipeline.documents(forVolume:)`, `document_cache.bodyText`, `user_tag_ids` column
- `Collection` / `CollectionEntry`, `SavedSearch.searchParameters`, manifest subseries lookup
- `AppState` `pending*` handoff pattern
- Coding Standards: `String(localized:)`, doc comments, Apache header, `accessibilityRepresentation`,
  `reduceMotion`, OpenAPI spec maintenance
- NaturalLanguage framework (new to the project)

---

## Version History

- 1.0 — 2026-06-25: Initial feasibility + architecture spec.
