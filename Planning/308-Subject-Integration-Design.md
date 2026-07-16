# #308 — FRUS-Subjects Integration: Architecture Design

**Status:** design sketch for review (Opus-authored, Fable review pending)
**Issue:** [#308](https://github.com/joshbotts/FRUS-Explorer/issues/308) — "FRUS-subjects integration"
**Related:** #261 (document-level data gate), #264 (person↔subject affinity), #235 (NARA lookup), the shipped volume-subject-profiles feature (Wave-6 Session 9, PR #251)
**Date:** 2026-07-16

---

## 1. What #308 asks for, and the constraint that shapes everything

The issue fixes three requirements:

1. **Search + analytics** use the **top two** taxonomy levels — **category** and **sub-category** — as targets/filters. The third level (**subject**) is only a *narrower drill-down*, never a primary facet.
2. **Documents** display the **full three-level hierarchy** and use subject-level metadata as part of a **"find related documents"** feature.
3. **"Find related documents"** lets the user **customize the axes** of similarity/proximity (and/or the metadata categories) the app targets.

The constraint that shapes the whole design: **the document-level subject data is not shippable** (#261 — ~97% raw string-match, 579 anachronistic pre-1970 "AIDS" refs, 40–48%/volume unreconcilable variant pairs, ~95 non-reproducible synthetic refs). The owner confirmed (2026-07-16) the data is not ready. So this is an **architecture-and-scaffolding** deliverable: build the app so that integrating the data later is a **data drop, not a rebuild**.

This is the same shape as #258 (custom volume scopes): design a load-bearing invariant, build the surfaces against it, and let the data arrive behind a clean seam.

---

## 2. The data landscape (real shapes, verified 2026-07-16)

Three artifacts, three grains. The architecture lives or dies on keeping them straight.

### 2.1 The taxonomy (vocabulary — public-domain, **shippable**)

`frus-subject-taxonomy/exports/taxonomy.json` (245 KB, `generated: 2026-06-16`; a byte-identical copy ships in the frus-subjects handoff). Three levels:

- **13 categories** — `{label, totalAnnotations, subcategories[]}`. Labels: *Foreign Economic Policy, Politico-Military Issues, Warfare, Bilateral Relations, Global Issues, International Law, Arms Control and Disarmament, Human Rights, Science and Technology, Information Programs, Department of State, International Organizations, Uncategorized.*
- **127 sub-categories** — `{label, subjects[]}`, e.g. *"Trade and Commercial Policy/Agreements"*.
- **543 subjects** — `{ref, name, count, volumes, variants[]}` + optional `{lcshUri, lcshMatch}`. Example: `{"ref":"rectjw2jgFLXmsufI","name":"Export control","count":14247,"volumes":522,"lcshUri":".../sh85046493","lcshMatch":"exact","variants":["Export controls--United States", …]}`.

**A subject's category + sub-category are *implied by nesting*, not stored on the subject.** There is currently **no** taxonomy bundled in the app (`Resources/` has `volume-subject-profiles-index.json` and the unrelated `volume-tag-taxonomy.json`).

### 2.2 The document mappings (the noisy, **gated** part — #261)

`frus-subjects/data/document_subjects.json` (10.3 MB, md5 `358770f316d679d4fc7aeb77ea1dcaed`). **Subject-major (inverted index), not document-keyed:**

- `subjects[ref][volumeId] = "d107, d111, d214, …"` — 520 subjects, 1,423,734 (subject, doc) references. The smallest addressable unit is the triple `(subjectRef, volumeId, docId)`; the natural per-document key is the composite `(volumeId, documentId)`.
- `subjectsIndex[ref] = {name, category, subcategory}` — a **self-contained crosswalk** (this is what makes ref → two-level attribution derivable offline without walking the taxonomy tree).

The **vocabulary layer** (taxonomy + `subjectsIndex` crosswalk) is curated and shippable; it is only the **per-document `subjects` mappings** that carry the #261 noise verdict. This distinction is load-bearing (§5).

### 2.3 The volume profiles (**the one subject feature that ships today**)

`Resources/volume-subject-profiles-index.json` (223 KB) — a TF-IDF-style per-volume top-15 profile, generated offline from `document_subjects.json` with a genericity floor and a min-docs threshold, *because doc-level noise washes out at volume grain* (the whole rationale for shipping at volume grain, not document grain).

App side: `VolumeSubjectProfiles` (`FRUSExplorer/Browser/VolumeSubjectProfiles.swift`) decodes the wire format into two ready indexes and **the canonical app-side subject value type**:

```
ResolvedSubject { ref, name, category, subcategory, score }   // carries BOTH facet levels already
resolvedByVolume:     [volumeId : [ResolvedSubject]]           // ranked per volume
volumesBySubjectRef:  [subjectRef : [volumeId]]                // the cross-volume pivot
```

`VolumeSubjectProfilesStore.shared` loads it lazily, nil-tolerant. **This already carries `category` *and* `subcategory` per subject** — which is exactly the two levels #308 wants as facets. That fact is the key that unlocks Phase 1 with no new data.

---

## 3. The load-bearing invariant: the grain / data-availability boundary

Everything #308 wants splits cleanly into two grains along the data-availability line:

| #308 requirement | Grain needed | Data status | Ships |
|---|---|---|---|
| category / sub-category facets in **search + analytics** | **volume** | shipped (profiles carry both levels) | **now** |
| **subject** drill-down (3rd level) | document | gated (#261) | on data drop |
| **full hierarchy on a document** | document | gated (#261) | on data drop |
| **find related documents** (provenance / cross-refs / persons / date axes) | document (already indexed) | shipped | **now** |
| **find related** — the *subject* axis | document | gated (#261) | on data drop |

**The invariant:** every subject surface reads through a `DocumentSubjectStore` (§5) that returns **empty when the document-grain index is not bundled**. Volume-grain surfaces (the two-level facets) read the already-shipped profiles and never touch that store. This is the direct analog of #258's `IndexedResolution` — a single seam that makes "the data isn't here yet" an explicit, non-crashing, non-inverting state, so the surfaces are written once and light up on the drop.

Concretely: a fresh build with no document-subject index bundled ships **Phases 1 and 2 fully working** (facets + multi-axis related-docs minus the subject axis). Bundling the index in Phase 3 lights up the subject drill-down, the document hierarchy, and the subject axis — **no view rewrites**.

---

## 4. Facets: category + sub-category in search and analytics (Phase 1 — ships now)

**No new data, no schema/index change.** Category and sub-category each resolve to a **`Set<volumeId>`** from the bundled profiles, and flow through the *existing* volume-id prefilter that custom scopes already use.

### 4.1 The resolver (extend `ScopeFacets`, the #258 Phase 4 template)

`ScopeFacets` (`FRUSExplorer/Models/CustomVolumeScope.swift`) already has `subjectCatalog(resolvedByVolume:volumesBySubjectRef:)` and `volumeIds(forSubjectRef:…)`, pure set-math over dictionaries (fixture-testable, no store). Extend to the two-level grain:

```
ScopeFacets.categoryCatalog(resolvedByVolume:)            -> [CategoryEntry{label, volumeCount}]
ScopeFacets.subCategoryCatalog(resolvedByVolume:)         -> [SubCategoryEntry{category, label, volumeCount}]
ScopeFacets.volumeIds(forCategory:resolvedByVolume:)              -> Set<volumeId>
ScopeFacets.volumeIds(forCategory:subcategory:resolvedByVolume:)  -> Set<volumeId>
```

`ScopeFacets.SubjectEntry` currently exposes `category` but **not** `subcategory` — extend it (the decoded `ResolvedSubject` already has both, so no artifact change). A volume is "in" a category if any of its profile's `ResolvedSubject`s carries that category. Because profiles are already **manifest-wide** (cover un-downloaded volumes), the same resolver serves both the indexed grain (corpus analytics / search) and the manifest grain (Series dashboards).

### 4.2 Search surface

`SearchFilterView` (`FRUSExplorer/Search/SearchFilterView.swift`) — the shared iOS+macOS filter that already hosts the #258 `customScopeSection`. Add a sibling **"By Subject Category"** section: a category picker, and within a category a sub-category drill-down. On tap it seeds `vm.selectedVolumeIds = ids.sorted()` exactly like `customScopeRow` — snapshot semantics, no new query field, zero SQL change (the WHERE builder already applies `dc.volume_id IN (…)` at `IndexingPipeline.swift:2156`).

**Design choice — dedicated channel vs. reuse `selectedVolumeIds`:** reuse the volume-id channel (option a) for v1 — it's the least code and matches custom scopes. Note the tradeoff for review: a subject facet and a manual volume selection then *overwrite* each other rather than compose. If composition matters, a distinct `SearchParameters.subjectScopeVolumeIds` resolved to the same `IN (…)` clause is the fast-follow (§8 Q2).

### 4.3 Analytics surface

`AnalyticsScopeBar` (`FRUSExplorer/Analytics/AnalyticsChartChrome.swift`) — the shared bar whose entire scope model is one `@Binding scopeVolumeIds: [String]?`, funneled through `setScope(_:label:)`. Add a **"By Subject Category"** menu section (a new `Divider()`-separated block, exactly like the #258 Phase 3 custom-scope section), resolving to the same `[String]?`. `CorpusAnalyticsService` applies it as a volume-id post-filter with zero service change. The manifest-grain `SeriesScopeBar` gets the parallel section against `manifestVolumeIds`. All `AnalyticsScopeBar` adopters (AnalyticsView, PersonAnalyticsView, CrossReferenceAnalyticsView, WordCloudView) inherit it.

### 4.4 Picker UI

Reuse the `SubjectFacetPicker` idiom (`CustomScopesView.swift`) — searchable catalog, per-row reach, platform-split chrome (macOS plain sheet / iOS `NavigationStack`+`.searchable`, the #332 fix). A two-level category → sub-category navigation, and the `VolumeSubjectsChips` category-grouped presentation (`VolumeSubjectsView.swift`) is the display precedent for the hierarchy.

**Phase 1 is genuinely shippable today** and is the smallest honest slice: it delivers exactly the "top two levels as facets" requirement, volume-grain, from data already in the bundle.

---

## 5. The document-grain seam (Phase 3 prerequisite — built empty in Phases 1–2)

The subject drill-down, the on-document hierarchy, and the subject axis of find-related all need a **document → subjects** lookup that does not exist today (the retired `document_cache.subject_tag_ids` column is inert since Session 9). Define the seam now; fill it on the data drop.

### 5.1 The future bundled index + generator

Mirror `VolumeSubjectProfilesGenerator`: a new `DocumentSubjectIndexGenerator` inverts `document_subjects.json` into a compact **document-keyed** bundle:

```
document-subject-index.json:
  vocab:    [{r:ref, n:name, c:category, s:subcategory}]   // the shippable crosswalk (§2.2)
  docs:     { "<volumeId>/<docId>" : [vocabIndex, …] }     // int indices into vocab
  provenance: { sourceMd5, generated, filters }            // pins the noisy source drop
```

The **vocabulary rides inside this index** (from `subjectsIndex`), so bundling the doc index also bundles the taxonomy labels — Phase 1's facets never need it (profiles already carry the labels), but Phase 3's full-hierarchy display gets it for free. The generator applies the #261 mitigations (over-broad blocklist, min-instance-per-doc, flagged-instance + human-rejection exclusions) so the *bundled* map is the filtered subset, framed as **"detected topics," never authoritative** (#261 pilot framing).

### 5.2 The app-side store (built now, empty now)

```
enum DocumentSubjectStore {
    static let shared: DocumentSubjectIndex?          // nil when not bundled — the seam
}
struct DocumentSubjectIndex {
    func subjects(forDocument key: DocumentKey) -> [ResolvedSubject]   // [] when absent
    func hierarchy(forDocument key: DocumentKey) -> [CategoryGroup]    // grouped, [] when absent
}
```

Reuse the existing `ResolvedSubject` value type (§2.3) so the document display and the volume display speak the same shape. Lazy, nil-tolerant, not at `AppState` init (the `VolumeSubjectProfilesStore` precedent). **Ships in Phases 1–2 returning empty** — every consumer degrades to "no subjects yet," never crashes, never inverts.

### 5.3 Query seam for true document-grain filtering (Phase 3, only if needed)

The two-level facets never need document-grain SQL (they're volume-set prefilters, §4). *If* subject-level drill-down should filter the FTS result set at document grain, two precedented options (defer the choice to Phase 3):

- (a) Repopulate a `document_cache` subject column from the bundled map + revive the retired `subject_tag_ids` machinery + bump `currentDateIndexVersion` (the reindex path).
- (b) A bundled doc→subject lookup queried alongside FTS via an `EXISTS` sub-query (the `person_mentions` precedent, `IndexingPipeline.swift:2190`) or a key-set prefilter (the `documentKeysInDateRange` precedent, `:2244`) — **no reindex**.

Recommend (b) — additive, no index-version bump, matches the person-mention precedent.

---

## 6. Find related documents: a customizable multi-axis model (Phase 2 — ships now, subject axis gated)

This is the ambitious requirement, and the recon found a **mature multi-signal substrate already in the app** — just not yet composed into a single tunable feature or surfaced on the document view. The design generalizes the existing single-axis "Archival Neighbors" into an N-axis, user-weighted model.

### 6.1 The axes that already exist per document

| Axis | Signal source | Scorer | Ships now |
|---|---|---|---|
| **Archival provenance** | `IndexingPipeline.archivalNeighbors(…)` (`:5042`) — lot/RG/decimal/library match, already a working neighbor engine with `RelatedDocument` rows + `NeighborScope` breadth | tiered key match (exact lot > RG+series > decimal > library) | ✅ |
| **Cross-references** | `CrossReferenceStore` inbound/outbound edges (`:355/:378`) | direct-citation / co-citation | ✅ |
| **Shared persons** | `PersonMentionStore.personRefs(forDocumentId:volumeId:)` (`:242`), resolved through the rollup identity (`rollupMentions`, `:343`) so cross-volume ref collisions don't conflate | set overlap (Jaccard) | ✅ |
| **Coverage date** | `extractYear(from: dateline)` / `extractDateRange` | \|Δyear\| decay | ✅ |
| **Volume / subseries** | `VolumeManifestEntry.subseries` | same-volume / same-subseries boost | ✅ |
| **Shared subjects** | `DocumentSubjectStore` (§5) — **empty until the data drop** | set overlap at chosen grain (category / sub-category / subject) | ⛔ gated |

### 6.2 The model

```
protocol SimilarityAxis {
    associatedtype Signature
    func signature(for doc: DocumentKey, appState: AppState) -> Signature   // feature extractor
    func score(_ a: Signature, _ b: Signature) -> Double                    // pairwise, 0…1
    var weight: Double { get }          // user-tunable, 0…1 (0 = axis off)
    var threshold: Double? { get }      // optional floor
}
```

A candidate document's total proximity is the weighted sum over enabled axes. The **subject axis contributes 0 while `DocumentSubjectStore.shared == nil`** — the feature ships fully functional on the other five axes and gains a sixth on the data drop, with no view change. This is the data-agnostic property #308's customizability requirement makes natural: the user tunes weights over whatever axes have data.

**Candidate generation** (not all-pairs — 300k+ docs): union the neighbor sets each *enabled* axis can cheaply enumerate (provenance neighbors, cross-ref edges, same-person docs, same-subseries, ±N years), then score+rank that union. Reuse `NeighborScope` (`:47`) as the breadth control.

### 6.3 Restorability + presentation

A `RelatedDocumentsRequest` **Codable + Hashable** value type carrying the **weight vector + anchor doc key + scope**, mirroring `ArchivalNeighborsRequest`'s restorability (`ArchivalNeighborsSheet.swift:75`). Its `load(appState:)` reconstructs the ranked list from the value alone — so a macOS window restores the *exact tuning*. Weights persist via `@AppStorage` (the research-panel accordion idiom, `MacDocumentView.swift:107`).

Presentation follows the **established sheet-vs-window rule** (`ArchivalNeighborsSheet.swift:594`): iOS presents the related list as a `.sheet` (new `DocumentSheet` case, `DocumentView.swift:35`); macOS presents a **value-based `WindowGroup(for: RelatedDocumentsRequest.self)`** window (a work list you step through, so it must survive navigation). A row tap hands off via `appState.pendingBrowseDocument`; the macOS window stays open. This is precisely the C2 (#317) value-based pattern — reuse it, don't reinvent.

### 6.4 Entry points

- **iOS** `DocumentView`: a "Related documents" toolbar/overflow action + a "Subjects" disclosure in the tag-section region (`:1640`).
- **macOS** `MacDocumentView`: a "Subjects" and a "Related" `DisclosureGroup` in the research-panel accordion (`:473`), and a "Related" button on `ResearchStripView` (the "Sources" button precedent).

The **full-hierarchy display** is inline in both (not a sheet); the **related list** is the sheet/window per the rule.

---

## 7. Phasing

**Phase 1 — Two-level facets (ships now, no new data).** `ScopeFacets` category/sub-category helpers + `SearchFilterView` section + `AnalyticsScopeBar`/`SeriesScopeBar` sections + the two-level picker. Delivers requirement #1 in full, volume-grain, from the bundled profiles. Smallest honest slice; the #258 Phase 3/4 templates make it mechanical.

**Phase 2 — Find related documents, multi-axis (ships now, subject axis inert).** The `SimilarityAxis` model + `RelatedDocumentsRequest` value type + candidate generation over the five live axes + customizable weights + iOS-sheet/macOS-window presentation + document-view entry points. Delivers requirement #3 and the related-docs half of #2, on data that's already indexed. The subject axis is wired but contributes 0 (guarded by `DocumentSubjectStore.shared`).

**Phase 3 — Document-grain data drop (gated on #261).** `DocumentSubjectIndexGenerator` + bundled `document-subject-index.json` + `DocumentSubjectStore` filled + document full-hierarchy display + subject drill-down (facet 3rd level) + the subject axis lights up in find-related. All the surfaces already exist from Phases 1–2; this is the integration, not a rebuild. Framed as "detected topics," never authoritative (#261).

Phases 1 and 2 are independently mergeable and shippable in a build without the gated data. Phase 3 waits on the #261 upstream regeneration (owner decision pending).

---

## 8. Open questions for review

- **Q1 — Vocabulary bundling for Phase 1 facet labels.** The two-level facets read `category`/`subcategory` strings straight from the profiles, so Phase 1 needs *no* taxonomy bundle. Confirm we don't want the full taxonomy (with LCSH links, category `totalAnnotations`) bundled earlier for richer facet labels/ordering. *Recommendation: no — profiles suffice for Phase 1; the crosswalk rides in the Phase 3 doc index.*

- **Q2 — Facet channel: reuse `selectedVolumeIds` vs. a dedicated `subjectScopeVolumeIds`.** Reuse is least code but a subject facet and a manual volume pick overwrite each other. *Recommendation: reuse for v1 (matches custom scopes); dedicated composing field as a fast-follow if users hit the overwrite.*

- **Q3 — Similarity candidate-generation cost.** Pairwise over 300k+ docs is infeasible; the design unions per-axis cheap neighbor sets then scores the union. Confirm that bound is acceptable and that provenance/cross-ref/person enumerations are all O(neighbors), not O(corpus). *The recon confirms each has a keyed lookup; validate at build time.*

- **Q4 — Weight defaults + the #261 noise.** When the subject axis lights up, its default weight matters given ~97% raw string-match / 60–77% researcher-usefulness. *Recommendation: ship the subject axis default-*low* (or off) with an explicit "detected topics, experimental" label; let power users raise it.*

- **Q5 — The 23 taxonomy-only refs + drift.** 23 taxonomy subjects have zero document mappings; ~95 synthetic refs are non-reproducible across drops. The generator must pin the source md5 (the `VolumeSubjectProfiles` provenance precedent) and tolerate vocab/mapping mismatch. *Confirm the generator fails loud on md5 drift.*

- **Q6 — Does subject-level drill-down filter at document grain, or stay volume-grain?** #308 says subject is a "narrower drill-down." If that means *within a category facet, narrow to a subject's volumes*, it stays volume-grain (Phase 1, ships now). If it means *filter the FTS results to documents tagged with the subject*, it needs the document index + §5.3 query seam (Phase 3). *Recommendation: v1 subject drill-down is volume-grain (a subject → its volumes, from `volumesBySubjectRef`), consistent with the facets; true document-grain subject filtering is Phase 3.*

- **Q7 — "Metadata categories" scope of customizability.** #308 says users customize "the axes of similarity/proximity (and/or metadata categories)." Read here as: the six axes in §6.1 are the tunable set. Confirm no additional metadata (e.g., editor, publication date, classification marking) is expected as a similarity axis in v1.

---

## 9. Review disposition

*(to be completed by the Fable adversarial review before the Sunday 7/19 Fable-included window closes)*

Attack surface to probe: the grain-split invariant (does any surface accidentally require document-grain data to *render*, breaking the data-agnostic property?); the facet channel overwrite (Q2) as a correctness issue, not just UX; the similarity candidate-generation cost (Q3) as a real perf bound; whether `DocumentSubjectStore.shared == nil` is honored on *every* subject read (the #258 "never a bare empty set" failure-mode analog — here it's "never require the gated data to render a shipped surface"); the reuse claims against the cited file:lines (do `ScopeFacets`, `AnalyticsScopeBar`, `ArchivalNeighborsRequest`, the sheet-vs-window rule actually compose as described?); and whether Phase 2's "find related" over-promises given only five live axes.
