# #308 — FRUS-Subjects Integration: Architecture Design

**Status:** design sketch, adversarial review complete and **body revised per the findings** (Opus-authored; full Fable review disposition preserved in §9, 2026-07-16). §§4, 6, 7 below incorporate F1–F9; read §9 for the evidence trail and what was verified true.
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

**Facet semantics — "characteristic," not "about" (review F3).** The profile is a per-volume top-15 of the *most distinctive* subjects (median 129 subjects qualify per volume; ~88% are dropped). So the facet means "volumes where X is among their most characteristic subjects," not "volumes about X." At **category** grain this barely discriminates — Foreign Economic Policy reaches **90.6%** of the 552 volumes and 7 of 13 categories exceed 50% — whereas **sub-category** grain is healthy (median reach ~4%). Implication for the UI: sub-category is where the facet earns its keep; label it honestly ("characteristic subjects"), and carry the per-row reach counts (§4.4) so the user sees a category touching 90% of the corpus for what it is. The category level is still useful as a coarse grouping/entry point, not as a discriminating filter.

**Fold "General" into its category (review F4).** 105 of the 371 bundled subjects sit in `".../General"` sub-categories, and for several categories (Information Programs is *entirely* General; Human Rights ~71%) the two-level drill-down collapses to "General ≡ the category." Present a `".../General"` sub-category as the category row itself, not as a child, so the drill-down never dead-ends in a junk drawer. Note vocabulary coverage in the picker (only 97 of 127 sub-categories and 371 of 543 subjects survive the profile filters into the bundle).

### 4.2 Search surface

`SearchFilterView` (`FRUSExplorer/Search/SearchFilterView.swift`) — the shared iOS+macOS filter that already hosts the #258 `customScopeSection` (the "macOS search is separate" porting trap does **not** apply — this surface is genuinely shared). Add a sibling **"By Subject Category"** section: a category picker, and within a category a sub-category drill-down. On tap it seeds `vm.selectedVolumeIds = ids.sorted()`, snapshot semantics, no new query field, zero SQL change (the WHERE builder already applies `dc.volume_id IN (…)` at `IndexingPipeline.swift:2156`).

**Follow `customScopeRow` FULLY, including its guard (review F5).** `customScopeRow` (`SearchFilterView.swift:432–443`) does two load-bearing things beyond seeding the id set: it resolves through `CustomScopeResolver.indexedResolution` and **warns + seeds nothing** when none of the members are indexed (the #258 "never seed a bare empty/whole-corpus set" invariant), and it **clears `vm.selectedSubseriesIds`**. The facet must do the same — the profile volume set is manifest-wide (up to 552 volumes, most not downloaded), so seeding it raw would (a) silently produce a zero-result search for a category with no indexed members, and (b) AND against a stale subseries selection. So: run the facet's volume set through `indexedResolution`, warn-not-seed on empty, and clear the subseries selection — reusing the exact `customScopeRow` path, not a simplified copy of it.

**Design choice — dedicated channel vs. reuse `selectedVolumeIds`:** reuse the volume-id channel (option a) for v1 — it's the least code and matches custom scopes. Note the tradeoff for review: a subject facet and a manual volume selection then *overwrite* each other rather than compose. If composition matters, a distinct `SearchParameters.subjectScopeVolumeIds` resolved to the same `IN (…)` clause is the fast-follow (§8 Q2).

### 4.3 Analytics surface

`AnalyticsScopeBar` (`FRUSExplorer/Analytics/AnalyticsChartChrome.swift`) — the shared bar whose entire scope model is one `@Binding scopeVolumeIds: [String]?`, funneled through `setScope(_:label:)`. Add a **"By Subject Category"** menu section (a new `Divider()`-separated block, exactly like the #258 Phase 3 custom-scope section), resolving to the same `[String]?`. `CorpusAnalyticsService` applies it as a volume-id post-filter with zero service change. Facet sets are non-empty by construction (a category with no volumes is not offered), so `setScope`'s empty→nil "no filter" inversion cannot fire here — the analytics side needs no `indexedResolution` guard (unlike search, F5). The manifest-grain `SeriesScopeBar` gets the parallel section against `manifestVolumeIds`.

**Adopter list (review F6 correction):** the real `AnalyticsScopeBar` adopters are `AnalyticsView:510`, `PersonAnalyticsView:453`, `CrossReferenceAnalyticsView:258` — they inherit the section. **`WordCloudView` is NOT one** — it has its own `WordCloudScope` / `WordCloudScopeResolver` (custom-scope support was built separately in #258 Phase 5). Adding subject faceting to the word cloud is therefore a *new* `WordCloudScope` case + resolver arm — call it out as an explicit Phase-1 sub-task or a deliberate non-goal, not a free inheritance.

### 4.4 Picker UI

Reuse the `SubjectFacetPicker` idiom (`CustomScopesView.swift`) — searchable catalog, per-row reach, platform-split chrome (macOS plain sheet / iOS `NavigationStack`+`.searchable`, the #332 fix). A two-level category → sub-category navigation, and the `VolumeSubjectsChips` category-grouped presentation (`VolumeSubjectsView.swift`) is the display precedent for the hierarchy.

### 4.5 The #261 noise reaches Phase 1 — do not assume "volume grain is clean" (review F2)

The original claim that doc-level noise "washes out at volume grain" is **false in the shipped index**, and Phase 1 makes it worse by promoting the noise from passive display into an active *filter*. Verified: `frus1964-68v10` (National Security Policy, 1964–68) carries **AIDS** (Human Rights / HIV-AIDS) at score **0.702** — a top-ranked profile entry; five pre-1968 volumes carry "Terrorism". The mechanism is intrinsic: TF-IDF *amplifies* a rare anachronism (high IDF), so the genericity + min-2 filters that remove *common* noise do the opposite for *rare* noise. A "HIV/AIDS" facet surfacing a Vietnam-era volume is exactly the kind of credibility hit the #261 gate exists to prevent.

Two fixes, not mutually exclusive:
1. **Generator-level era-sanity pass** (preferred): in `VolumeSubjectProfilesGenerator`, drop or down-rank a subject↔volume profile entry whose subject is anachronistic for the volume's `dateRange` (a small curated subject→earliest-plausible-year table covers the known offenders: AIDS, Terrorism, a handful more). This cleans the *already-shipped* volume feature too, and needs a profiles-index regen (offline, deterministic) — a bump to the bundled artifact, not a schema change.
2. **Extend the #261 "detected topics" framing to the Phase 1 facet UI** (minimum): the sketch reserved that framing for Phase 3; the volume-grain facet inherits enough noise to warrant it now. Label the facet section "detected topics (experimental)" or similar.

This qualifies the "genuinely shippable today" claim: Phase 1 **is** shippable with no new *document* data, but honestly shipping it wants the era-sanity regen (fix 1) rather than the raw profiles. Treat fix 1 as part of Phase 1, not a follow-up.

**Phase 1 is the smallest honest slice** — it delivers the "top two levels as facets" requirement, volume-grain, from data already in the bundle — *with* the F3 "characteristic" labeling, the F4 General fold, the F5 indexed-resolution guard, and the F2 era-sanity regen.

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

### 6.2 The model — generators vs. scorers (revised per review F1/F8)

The original single `SimilarityAxis` protocol conflated two roles that have very different cost, and that conflation was the design's weakest point: three of the five "live" signals **cannot cheaply enumerate neighbors** — a head-of-state person rollup maps to tens of thousands of documents (`documentKeys(forRollupId:)`), a busy ±N-year window is 10⁴+ (`documentKeysInDateRange`), and a subseries is ~50 volumes × hundreds of docs. "Union every axis's enumeration" therefore approaches the whole corpus for a prominent-person or broad-date anchor, and scoring then costs one SQL call per candidate for the person axis. The fix is to **split the roles**:

- **Generators** — axes that produce a *bounded* candidate set (genuinely O(neighbors)): **archival provenance** (`archivalNeighbors`) and **cross-references** (`CrossReferenceStore` edges). Candidate generation unions *only* the generators' sets, then applies `NeighborScope` (`:47`) breadth.
- **Scorers** — axes that only *rank* the already-generated candidates, never enumerate: **date** (|Δyear| decay), **subseries** (same-subseries boost), **persons** (shared-person overlap), and eventually **subjects**. Persons may *optionally* generate, but only gated by a per-person corpus doc-frequency floor (the persons analog of the profiles' genericity floor), so a ubiquitous name never expands the candidate set.

```
protocol SimilarityGenerator {                       // bounded candidate enumeration
    func candidates(for anchor: DocumentKey, scope: NeighborScope,
                    appState: AppState) async throws -> [DocumentKey]
}
protocol SimilarityScorer {                          // rank the candidates; no enumeration
    // batch signature extraction — one chunked-IN query per axis, NOT one-per-candidate
    // (the PersonMentionStore 499-doc chunk precedent)
    func scores(anchor: DocumentKey, candidates: [DocumentKey],
                appState: AppState) async throws -> [DocumentKey: Double]   // 0…1 per candidate
}
```

Both are `async throws` (every real source is a throwing SQLite call — the original sync/non-throwing signature was wrong). A candidate's total proximity is the **user-weighted** sum of its scorer values (plus a generator-membership bonus). The **weights and thresholds live on `RelatedDocumentsRequest` (§6.3), not on the axis types** — they are per-request user state that must ride the Codable window payload, not properties of a stateless axis. A heterogeneous `[any SimilarityScorer]` composes via opened existentials (Swift 5.7+: open each scorer once, capture the anchor, produce an erased `[DocumentKey: Double]`) — name the erasure in the implementation; it is not free.

The **subject axis is a scorer** that contributes 0 while `DocumentSubjectStore.shared == nil` — the feature ships fully functional on the live generators + scorers and gains the subject scorer on the data drop, no view change. That is the data-agnostic property #308's customizability makes natural: the user tunes weights over whatever axes have data.

### 6.3 Restorability + presentation

A `RelatedDocumentsRequest` **Codable + Hashable** value type carrying the **weight vector + anchor doc key + scope**, mirroring `ArchivalNeighborsRequest`'s restorability (`ArchivalNeighborsSheet.swift:75`). Its `load(appState:)` reconstructs the ranked list from the value alone — so a macOS window restores the *exact tuning*. Weights persist via `@AppStorage` (the research-panel accordion idiom, `MacDocumentView.swift:107`).

Presentation follows the **established sheet-vs-window rule** (`ArchivalNeighborsSheet.swift:594`): iOS presents the related list as a `.sheet` (new `DocumentSheet` case, `DocumentView.swift:35`); macOS presents a **value-based `WindowGroup(for: RelatedDocumentsRequest.self)`** window (a work list you step through, so it must survive navigation). A row tap hands off via `appState.pendingBrowseDocument`; the macOS window stays open. This is precisely the C2 (#317) value-based pattern — reuse it, don't reinvent.

### 6.4 Entry points

- **iOS** `DocumentView`: a "Related documents" toolbar/overflow action + a "Subjects" disclosure in the tag-section region (`DocumentView.swift:1681` — the tag section; `:1640` is the Notes header, cite corrected per F9).
- **macOS** `MacDocumentView` (`FRUSExplorer/App/`): a "Subjects" and a "Related" `DisclosureGroup` in the research-panel accordion (`:473`), and a "Related" button on `ResearchStripView` (the "Sources" button precedent).

The **related list** is the sheet (iOS) / value-based window (macOS) per the rule; the **full-hierarchy display** is inline in both.

**The Subjects disclosure must visibility-gate, not empty-state (review F7).** The document-grain hierarchy is Phase 3 data, and #261 has no ETA — so an always-present "Subjects" disclosure would be a **visibly dead** section on every document indefinitely. Follow the `VolumeSubjectProfilesStore` precedent: the section does **not appear** when its data source is nil, rather than appearing with an empty state. So the *document-grain* Subjects disclosure is a Phase 3 entry point, gated on `DocumentSubjectStore.shared != nil`.

**Cheap Phase-2 win the original sketch missed:** a document can show its **volume's** profile subjects *now* — that data ships today (`VolumeSubjectProfilesStore` / `topSubjects(forVolumeId:)`), and the `VolumeSubjectsChips` presentation already exists. So Phase 2 can ship a "Subjects (this volume)" disclosure — clearly labeled volume-level, not document-level — giving the document view real subject content immediately, with the *document-level* hierarchy replacing/augmenting it in Phase 3. This turns a dead Phase-2 section into a live one at near-zero cost.

---

## 7. Phasing

**Phase 1 — Two-level facets (ships now, no new *document* data).** `ScopeFacets` category/sub-category helpers (SubjectEntry gains `subcategory`) + `SearchFilterView` section (via the full `customScopeRow` indexed-resolution guard, F5) + `AnalyticsScopeBar`/`SeriesScopeBar` sections (adopters `AnalyticsView`/`PersonAnalytics`/`CrossRefAnalytics`; WordCloud is a separate case, F6) + the two-level picker with "characteristic subjects" labeling and per-row reach + the General fold (F3/F4). **Includes the F2 era-sanity regen of `volume-subject-profiles-index.json`** (drop anachronistic subject↔volume entries) — treat as part of Phase 1, since honestly shipping the facet wants clean profiles. Volume-grain throughout; the #258 Phase 3/4 templates make the app code mechanical.

**Phase 2 — Find related documents, multi-axis (ships now, subject scorer inert).** The generators-vs-scorers model (§6.2) + `RelatedDocumentsRequest` value type (carries the weight vector) + candidate generation over the two live **generators** (provenance, cross-refs) scored by the live **scorers** (date, subseries, persons) + customizable weights + iOS-sheet/macOS-window presentation + document-view entry points. Plus the cheap "Subjects (this volume)" disclosure (F7) from the shipped volume profiles. Delivers requirement #3 and the related-docs half of #2 on data already indexed. The subject scorer is wired but contributes 0 (guarded by `DocumentSubjectStore.shared`); the document-grain Subjects disclosure is visibility-gated off until Phase 3.

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

## 9. Review disposition (Fable adversarial review, 2026-07-16)

**Verdict:** the phasing is structurally sound, the grain-split invariant holds as an architecture, and the keystone data claim is **verified true against the shipped artifact** — Phase 1 ships on data already in the bundle. But "genuinely shippable today" needs four amendments before implementation (F2, F4, F5, F6 below), and Phase 2's candidate-generation model (§6.2) is the weakest load-bearing element: as written it does not bound the work (F1). Evidence labels: **RAN** = checked data/artifact, **READ** = traced code, **REASONED** = design judgment.

### Findings

**F1 — HIGH (REASONED, on RAN corpus scale + READ APIs): §6.2 candidate generation over-promises.** Three of the five "live" axes enumerate huge sets, not neighbor sets: *persons* (`documentKeys(forRollupId:)` for a head-of-state rollup is tens of thousands of docs cross-corpus), *date* (±N years via `documentKeysInDateRange` over a busy era is 10⁴+), *subseries* (~50 volumes × hundreds of docs). "Union the per-axis cheap enumerations" therefore approaches the corpus for prominent-person or broad-date anchors, and scoring then costs O(candidates × axes) with **one SQL call per candidate** for the person axis (`personRefs(forDocumentId:)`). *Fix:* split axes into **generators** (archival neighbors, cross-ref edges — genuinely O(neighbors)) and **scorers** (date, subseries, persons — score-only over generated candidates); if persons must generate, gate by per-person corpus doc-frequency (the persons analog of the profiles' genericity floor); batch signature extraction via chunked `IN` (the `PersonMentionStore` 499-doc chunk precedent).

**F2 — MEDIUM-HIGH (RAN): "noise washes out at volume grain" is falsified in the shipped index, and Phase 1 promotes the noise into filters.** `frus1964-68v10` (National Security Policy, 1964–68) carries **AIDS** (Human Rights / HIV/AIDS) at score 0.702 — a top-ranked profile entry. The #261 anachronism survived the genericity + min-2 filters, and TF-IDF *amplifies* rare anachronisms (high IDF). Five pre-1968 volumes also carry "Terrorism". This already ships in the passive volume-browser display; Phase 1 elevates it to a search/analytics facet ("HIV/AIDS" → a Vietnam-era volume). *Fix:* a generator-level era-sanity/blocklist pass (subject × volume `dateRange`), or at minimum extend the #261 "detected topics" framing to the Phase 1 facet UI (the sketch reserves it for Phase 3).

**F3 — MEDIUM-HIGH (RAN): the facet means "distinctive", not "about", and category-grain facets barely discriminate.** Per volume, a median **129** subjects pass min-2 + genericity but only 15 are kept — ~88% of qualifying subject↔volume pairs are dropped, so the facet is "volumes where X is among the 15 most *distinctive* subjects". Reach: Foreign Economic Policy touches **90.6%** of the 552 volumes; 7 of 13 categories ≥50% — category-level filters remove little. Sub-category reach is healthy (median 23 volumes ≈ 4%), so the drill-down is where the facet earns its keep. *Fix:* label the facet honestly ("characteristic subjects"), keep the planned per-row reach counts, document the semantics; acceptable for v1 since profiles are the only shippable data.

**F4 — MEDIUM (RAN): the ".../General" junk drawer dominates several sub-category lists.** 105 of the 371 bundled subjects sit in "General" sub-categories; **Information Programs' entire 213-volume reach is via "General" (zero non-General)**; Human Rights is 71% General-driven; 97 of 127 sub-categories survive into the bundle at all (172 of 543 subjects absent). For several categories the two-level drill-down collapses to "General" ≡ the category. *Fix:* fold "General" into the category row rather than presenting it as a child; note vocabulary coverage in the picker.

**F5 — MEDIUM (READ): §4.2's "exactly like `customScopeRow`" omits two load-bearing details.** `customScopeRow` (`SearchFilterView.swift:432–443`) (a) resolves through `CustomScopeResolver.indexedResolution` and **warns + seeds nothing** when no members are indexed — the very #258 invariant §9 was asked to probe — and (b) clears `vm.selectedSubseriesIds`. The facet path as sketched seeds manifest-wide (552-volume) sets raw: a category with zero indexed members silently yields a zero-result search, and a stale subseries selection would AND against the facet set. *Fix:* facet taps run the same indexed-resolution guard + subseries clear. (Analytics is safe: facet sets are non-empty by construction, so `setScope`'s empty→nil inversion cannot fire — state that explicitly.)

**F6 — MEDIUM (RAN): `WordCloudView` is *not* an `AnalyticsScopeBar` adopter.** It has its own `WordCloudScope`/`WordCloudScopeResolver`; its custom-scope support was separately built in #258 Phase 5. The §4.3 claim that it "inherits" the new section is false — a subject facet there is a new `WordCloudScope` case + resolver arm, or an explicit non-goal. Verified adopters: `AnalyticsView:510`, `PersonAnalyticsView:453`, `CrossReferenceAnalyticsView:258`.

**F7 — MEDIUM (REASONED): the invariant holds for *rendering*, but Phase 2's "Subjects" disclosure would ship permanently empty.** §6.4 lists a Subjects disclosure among Phase 2 entry points while the hierarchy display is Phase 3, and §5.2 says consumers "degrade to no subjects yet" — with #261's gate having no ETA, that is a visibly dead disclosure on every document. *Fix:* follow the `VolumeSubjectProfilesStore` precedent — the section does not **appear** when the store is nil (visibility-gate, not empty-state); move the disclosure explicitly to Phase 3. *Missed cheap win:* the disclosure could ship useful in Phase 2 showing the **volume's** profile subjects (data available now, labeled volume-level).

**F8 — LOW-MEDIUM (REASONED): the `SimilarityAxis` protocol as written omits the composition step.** `[any SimilarityAxis]` with `Signature` in parameter position needs opened-existential trampolines (workable since Swift 5.7: open each axis once, capture the anchor signature in an erased `(DocumentKey) -> Double`), but the sketch should name it. More substantively: `signature(for:appState:)` is sync/non-throwing while every real source is a throwing SQLite call — the protocol needs async/throws + **batch** signature APIs (see F1). `weight`/`threshold` belong on `RelatedDocumentsRequest` (per-request user state that must ride the Codable window payload), not on the axis type.

**F9 — LOW (READ): cite drift.** The iOS tag-section is `DocumentView.swift:1681` (":1640" is the Notes header); `MacDocumentView` lives in `FRUSExplorer/App/` (its `:107`/`:473` cites are correct). All other cited file:lines resolve.

**Q2 ruling (correctness, not just UX): reuse is acceptable for v1.** The seeded set is visible (selection count + explanatory footer), replace-not-compose matches the custom-scope precedent, and facet-then-manual-edit actually *composes* correctly under snapshot semantics. Not a silent-clobber bug **provided** F5's guard and feedback ship with it; the dedicated channel remains a fair fast-follow.

### Verified true (survived the review)

- **Keystone (RAN/READ):** `ResolvedSubject` exposes both `category` and `subcategory` (`VolumeSubjectProfiles.swift:38–51`); the shipped index's 371 vocab entries all carry a **populated, non-degenerate** `s` (0 empty; 13 categories; 97 (cat,sub) pairs); 552 profiles whose volume-id set **exactly equals** the manifest's. Phase 1's "no new data" claim is true.
- **Provenance integrity (RAN):** the bundled provenance md5 `358770…` matches the actual `document_subjects.json`; generator filters match the provenance string (genericity 0.1 drops exactly 7 subjects; min-2; top-15, min profile 11).
- **Data shapes (RAN):** taxonomy 13/127/543 (byte-identical copy in the frus-subjects handoff, md5 `b1114adb…`); `document_subjects.json` subject-major with 520 subjects, exactly 1,423,734 refs, complete 520-entry `subjectsIndex` crosswalk; 23 taxonomy-only refs = 543 − 520.
- **Reuse claims (READ):** `ScopeFacets` pure set-math helpers exist; `SubjectEntry` has `category`, lacks `subcategory` as stated; `SearchFilterView` is genuinely shared iOS+macOS (`SearchView.swift:185`, `SearchSheet.swift:540`) — the "macOS search is separate" porting trap does **not** apply to this surface; `dc.volume_id IN (…)` WHERE builder; `AnalyticsScopeBar`'s single `[String]?` binding + `setScope`; `SeriesScopeBar` exists (manifest grain); `archivalNeighbors` (`:5043`), `NeighborScope` (Codable/Hashable), `CrossReferenceStore.inbound/outboundEdges` (`:354/:377`), `PersonMentionStore.personRefs` (`:242`) + rollup machinery, `documentKeysInDateRange` (`:2244`), person `EXISTS` precedent (`:2190`); `ArchivalNeighborsRequest` Codable+Hashable (`:75`) and the window-not-sheet rationale (`:594`); `SubjectFacetPicker` #332 platform-split chrome; `subject_tag_ids` inert since Session 9.
- **Grain invariant:** honored for Phase 1 (facets read only profiles; no path touches `DocumentSubjectStore`) — subject to F7's visibility-gate amendment for Phase 2.
