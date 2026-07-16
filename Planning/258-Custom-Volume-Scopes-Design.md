# #258 — Custom Named Volume Scopes: Design Sketch

**Session:** design-only (no implementation scheduled)
**Date:** 2026-07-15
**Status:** Design sketch. Nothing built. An adversarial review attacks this before implementation is scheduled.
**Derived from:** branch `claude/258-design-sketch`, tip `946a485` (Merge #326, "315b-provenance-ui").
**Method note:** Every factual claim about the codebase carries a `file:line` derived by reading the
code at `946a485` — not from planning docs or commit messages. Claims I could not verify from the
code are labelled **[UNVERIFIED]**. No implementation code appears below beyond illustrative
type/API signatures. §9 names this document's own least-verified claims for the review to attack.

---

## 1. The ask, restated

> *"Allow users to create custom named sets of volumes to use as search/analytics scopes."* Plus:
> opportunistically consolidate the app's separate scope pickers; a `CustomVolumeScope` SwiftData
> type (persisted, cloud-synced); a selection UI that picks volumes by subseries, title, subject
> tags, people-mentions, and other indexed metadata; and a Settings pane to manage them.

**Verdict on shape.** Build `CustomVolumeScope` as a **flat, all-defaulted SwiftData record whose
membership is a `[String]` array of manifest `volumeId`s** — no child relationship, no non-optional
custom enum (§3). Resolve it to a `Set<String>` that drops straight into the existing
`scopeVolumeIds` query plumbing that already threads through the whole app (§4); **no new FTS query
surface is needed.** Ship a **minimal end-to-end slice first** (model + resolver + editor + one
consuming surface + one management pane), then adopt surface-by-surface (§7). **Do not** attempt a
big-bang consolidation of all ~14 existing scope surfaces into one control: they split across two
irreconcilable grains (indexed-corpus vs. whole-manifest, §2) and three of them are about
*acquisition* (downloads), not analysis. Consolidation is **additive** — custom scopes become a new
*section* inside the scope controls that already exist, not a rewrite of them.

---

## 2. Scope-picker census (code-derived)

Fourteen volume-scoping surfaces exist across ~8 distinct scope *models*. One further family
(year-range presets) scopes by **date, not volume** and is out of scope; listed last for completeness.

| # | Surface | file:line | What it scopes | Selection model | Consolidation |
|---|---|---|---|---|---|
| 1 | Search advanced filter — Volume & Subseries pickers (iOS) | `SearchFilterView.swift:380`; state in `SearchViewModel.swift:166,173,497` | FTS5 search results, **indexed** volumes | Two combining pickers (whole-subseries + individual volumes) unioned by `effectiveVolumeIds` → `SearchParameters.volumeIds` | **Adapt** — add a "Custom scope" input that seeds the two pickers |
| 2 | Search advanced filter (macOS) | `MacSearchViewModel.swift:406` (`syncToFilterVM`), `:503` (`applyAdvancedFilters`) | same | Reuses `SearchViewModel` as `filterVM`; shares `reconstructScope` (`SearchViewModel.swift:640`) | **Adapt** — same model, **separate UI host** (§6) |
| 3 | Corpus term-frequency analytics — inline scope bar | `AnalyticsView.swift:501` (`scopeBar`), `:556` (`scopeMenuContent`), state `:188` | corpus term series, **indexed** | Inline whole-corpus / by-subseries / by-volume `Menu` — a **hand-rolled duplicate** of the shared `AnalyticsScopeBar` | **Adapt + de-dup** |
| 4 | Shared `AnalyticsScopeBar` — Person Analytics | def `AnalyticsChartChrome.swift:195`; host `PersonAnalyticsView.swift:453` | person-mention analytics, **indexed** | whole-corpus/subseries/volume `Menu` → `[String]? scopeVolumeIds` | **Adapt** — one edit benefits both hosts |
| 5 | Shared `AnalyticsScopeBar` — Cross-Reference Analytics | host `CrossReferenceAnalyticsView.swift:258` | cross-ref analytics, **indexed** | same shared bar | **Adapt** (rides on #4) |
| 6 | `SeriesScopeBar` — Production dashboard | def `SeriesScopeBar.swift:70`; host `SeriesProductionDashboard.swift:106` | "About the Series" dashboards over **manifest** entries (renders zero-index) | whole-series / by-subseries **decade-nested** `Menu` → `SeriesScope.volumeIds` (`SeriesScopeBar.swift:20`) | **Adapt** — must resolve custom scope at **manifest grain** |
| 7 | `SeriesScopeBar` — Geography dashboard | host `SeriesGeographyDashboard.swift:123` | same | same | **Adapt** (rides on #6) |
| 8 | `SeriesScopeBar` — Administration Profiles dashboard | host `AdministrationProfilesDashboard.swift:169`, state `:90` | same | same | **Adapt** (rides on #6) |
| 9 | `WordCloudScope` + bar + resolver | enum `WordCloudModels.swift:294`; bar `WordCloudView.swift:1034`; resolver `WordCloudScopeResolver.swift:24` | word-cloud term source | **Polymorphic enum**: doc/volume/subseries/corpus/collection/userTag/savedSearch/dateRange, with `signature` round-trip (`WordCloudModels.swift:316,359`) | **Adopt** — add a `.customScope(id:)` case |
| 10 | `DownloadScope` — Onboarding picker | enum `DownloadModels.swift:19`; UI `DownloadScopePickerView.swift:36`; `OnboardingView.swift:60` | which volumes to **download** | corpus/subseries/volume enum | **Leave/defer** — acquisition, not analysis |
| 11 | `DownloadScope` — iOS Settings "Add Volumes" | `SettingsView.swift:430` (`@State selectedScope: DownloadScope`) | download | inline picker | **Leave/defer** |
| 12 | `DownloadScope` — macOS Settings "Add Volumes" | `FRUSSettingsView.swift:2145` (**ad-hoc** `enum ScopeChoice`, `@State` sets) | download | ad-hoc per-view enum | **Leave/defer** (note the ad-hoc duplication) |
| 13 | `SummarizationScope` — Background summarizer | enum `BackgroundSummarizationService.swift:19`; UI `BackgroundSummarizationSettingsView.swift:504` | which docs to bulk-summarize | volume/subseries/userTag/savedSearch/dateRange enum | **Defer** — "summarize a custom scope" is natural but not core |
| 14 | `NeighborScope` — Archival Neighbors | enum `ArchivalNeighborsSheet.swift:47`; `applyScope` at `IndexingPipeline.swift:5479` | one anchor's archival neighbors | allIndexed/volume/subseries enum | **Leave** — anchored to one document/source; custom-set semantics don't fit |
| — | `AdministrationPresetMenu` (year-range) — Corpus + CrossRef analytics | `AdministrationPresetMenu.swift:27`; `AnalyticsView.swift:637`; `CrossReferenceAnalyticsView.swift:280` | **DATE** range, not a volume set | preset menu | **Out of scope** — scopes by date |

**Two structural facts fall out of the census:**

- **The grain split.** Surfaces 1–5, 9 scope over *indexed* volumes (`AppState.indexedVolumeIds`,
  `AppState.swift:786`); surfaces 6–8 scope over the *whole manifest* (`SeriesScope` is
  "deliberately distinct… scopes over manifest entries and carries no service dependency",
  `SeriesScopeBar.swift:16-19`). A single custom scope must therefore be **resolvable at both
  grains** — raw manifest ids for the Series bar, intersected with `indexedVolumeIds` for the FTS
  surfaces. This is the load-bearing constraint on the whole feature.
- **The unifying primitive already exists.** Every FTS-backed surface ultimately passes a
  `scopeVolumeIds: [String]?` / `Set<String>?` that becomes a SQL `volume_id IN (…)` clause
  (`IndexingPipeline.swift:2315`, `:2384`, `:2438`, `:5485`; `PersonMentionStore.swift:530`). A
  custom scope only has to *produce that set*. No query rewrite is needed anywhere.

---

## 3. The data model

```swift
@Model final class CustomVolumeScope {
    var id: UUID = UUID()
    var name: String = ""
    /// Membership: stable manifest volumeIds (see stability note). Value-array storage —
    /// the Collection.projectIds pattern — so no child @Model and no inverse relationship.
    var volumeIds: [String] = []
    var createdAt: Date?
    var lastModified: Date?
}
```

**Every design choice is pinned to a repo constraint:**

- **All properties defaulted or optional.** This is the repo's hard CloudKit rule: SavedSearch is
  documented as "All properties have default values or are optional so that CloudKit schema
  migrations… work without breaking existing records" (`SavedSearch.swift:27-29`). `createdAt`/
  `lastModified` are `Date?` "for CloudKit schema compatibility" exactly as `GeneratedSummary`
  (`GeneratedSummary.swift:131-134`).

- **Membership as `[String]`, not a relationship.** `Collection.projectIds: [UUID] = []`
  (`Collection.swift:103`) proves SwiftData stores value arrays on a synced `@Model` directly. Three
  models — `DocumentTagAssignment` (`:33-34`), `DocumentHighlight` (`:80`), `PersonClusterOverride`
  (`:62`) — **deliberately avoid `@Relationship`** and store plain ids "for CloudKit safety" / "to
  avoid cascade issues". A scope is a *set of ids*, not an ordered graph, so a child
  `CollectionEntry`-style model (`Collection.swift:299,434`) would add a second CloudKit record type
  and a schema deploy for no benefit. **Recommend the array.** Order is not meaningful for a scope;
  dedup on write. *If* ordered membership is ever wanted, the `sortOrder`-bearing child pattern is
  the fallback — but it is not v1.

- **No non-optional custom enum or Codable field — ever.** This repo *shipped* the trap: a
  non-optional `authorship` enum added to `GeneratedSummary` "force-casts [a legacy NULL] and traps
  at the getter" (`GeneratedSummary.swift:99-112`, issue #297). Same doc note: "A non-optional
  *custom* type added to an already-persisted model traps the same way whether it is an enum or a
  `Codable` value." `CustomVolumeScope` has **no** such field. If a future `kind` (static vs.
  dynamic, §8-Q2) is added, store it as an **optional `String` rawValue** coerced on read.

- **Stable membership key = `volumeId`.** The manifest declares `volumeId` "the stable primary key
  across all data layers" (`ManifestModels.swift:27-28`). Consequences for manifest churn:
  - *Volume **added*** across a manifest update → simply absent from existing sets; no breakage.
  - *Volume **renamed*** → `volumeId` is "derived from the volume filename without extension"
    (`ManifestModels.swift:26-28`), so a rename **changes the key** and the stored reference dangles.
    Degrade gracefully: `manifestStore.entry(forVolumeId:)` returns `nil` and callers fall back to
    the raw id (the existing tolerance — `WordCloudScopeResolver.swift:53,61`). Skip dangling ids at
    resolution; optionally surface a "N volumes no longer available" hint in the editor. **[UNVERIFIED]**
    whether OH has ever renamed a shipped `volumeId`; the design tolerates it regardless.

- **Name uniqueness: none enforced.** Neither `Collection.name` (`Collection.swift:56`) nor
  `SavedSearch.name` (`SavedSearch.swift:48`) is unique — both are bare defaulted `String`s.
  **Recommend: allow duplicate names, disambiguate by `id`,** optionally soft-warn in the editor.
  Uniqueness across CloudKit devices is un-guaranteeable anyway.

- **Sync-conflict posture: last-writer-wins, per field.** SwiftData over
  `NSPersistentCloudKitContainer` resolves conflicts field-by-field (LWW). Because `volumeIds` is a
  **single** CloudKit field (one array), two devices editing membership concurrently will LWW the
  *entire array* — one device's change is lost, not merged. Acceptable for v1 (scopes are
  low-churn, single-user); **document it**. **[UNVERIFIED by test]** — inferred from the container
  default, not run on two devices (§9).

- **Schema enrollment.** Add `CustomVolumeScope.self` to `frusModelTypes`
  (`ModelContainer+FRUS.swift:53-72`). This is a **new CloudKit record type**: per the standing note
  there (`:39-52`, `:94-112`), it is created lazily on first push and **must be deployed to the
  Production CloudKit schema before shipping** or fielded builds get `serverRejectedRequest`. This
  is a required release step, not optional.

---

## 4. The service layer

**Resolution is trivial because the record *is* the id set.** A thin resolver mirrors
`WordCloudScopeResolver` (`WordCloudScopeResolver.swift:24`) but is far simpler — no FTS or search
re-run, just a lookup + grain adapter:

```swift
@MainActor struct CustomScopeResolver {
    let manifestStore: ManifestStore
    /// FTS surfaces (#1–5, 9): intersect membership with what can actually return results.
    func indexedVolumeIds(_ scope: CustomVolumeScope, indexed: Set<String>) -> Set<String>
    /// Series surfaces (#6–8): raw manifest ids, kept even if un-downloaded.
    func manifestVolumeIds(_ scope: CustomVolumeScope) -> Set<String>
}
```

- The resolved `Set<String>` flows **unchanged** into `IndexingPipeline.searchDocuments(…,
  scopeVolumeIds:)` and siblings (`IndexingPipeline.swift:4981,5047,5148,6076`), into
  `PersonMentionStore` (`:562,481`), and into `AdministrationProfilesData` (`:455`). No new query
  path.
- **Built-in ⊕ custom composition, one picker model.** The existing bars already offer "Whole
  corpus/series" + "By Subseries" (+ "By Volume" for the indexed bars). Custom scopes become a
  **third section** in the same `Menu`. Suggested picker enum:
  `enum ScopeSelection { case wholeCorpus; case subseries(String); case volume(String);
  case custom(UUID) }` — the first three reproduce today's behaviour; `.custom` resolves via
  `CustomScopeResolver`. The indexed bars additionally intersect with `indexedVolumeIds`; the Series
  bar does not. **The two bar families keep their own grain-appropriate resolver call** — this is the
  §2 grain split made concrete, and it is why one universal control is the wrong target.
- **Live observation of scope edits: `@Query` on the shared container.** The repo's convention is
  native `@Query` reactivity, not manual refresh triggers (`AppState.swift:83`: "@Query
  allTagAssignments in ResearchView which is reactive natively"; exemplars
  `ResearchView.swift:108,112`). Every host that shows the picker declares
  `@Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]`; renaming or
  re-membering a scope re-renders the picker and the active-scope label with no extra plumbing.
  *Re-running the query* on membership change is the host's existing `onChange(scope)` path (already
  wired on every bar — e.g. `SeriesScopeBar.onChange`, `SeriesScopeBar.swift:77`).

---

## 5. Selection tooling — grounded in real data sources

The issue's five selection facets, each mapped to its source and cost for an **interactive** picker:

| Facet | Source | file:line | Cost |
|---|---|---|---|
| **Subseries** | `VolumeManifestEntry.subseries` | `ManifestModels.swift:35` | **Cheap** — in-memory; already bucketed (`AnalyticsScopeBar.swift:209`, `SeriesScopeBar decadeGroups:106`). |
| **Volume names** | `VolumeManifestEntry.title` | `ManifestModels.swift:40` | **Cheap** — in-memory; typeahead is a `String` filter. |
| **Volume subject tags** (a) | `VolumeManifestEntry.tags` (OH slugs in the manifest) | `ManifestModels.swift:64-66` | **Cheap** — in-memory per entry. |
| **Volume subject tags** (b) | `VolumeSubjectProfiles.volumesBySubjectRef` (frus-subjects derived) | `VolumeSubjectProfiles.swift:67,164`; store `:183` | **Cheap** — reverse index `subjectRef → [volumeId]` pre-built at load; pick a subject → volumes in O(1). |
| **People-mentions** | `PersonMentionStore.documentKeys(forRollupId:)` → distinct `volumeId` | `PersonMentionStore.swift:307`; actor `:171` | **Moderate** — an **async SQLite query**, not a bundled dict; only *indexed* volumes have rows. Fine per-lookup; a "volumes mentioning any of N people" batch wants one grouped query. |
| **Other indexed metadata** | `dateRange` / `status` / `editors` on the manifest entry | `ManifestModels.swift:43,50,53` | **Cheap** — in-memory. |

**Precompute verdict:** four of five facets are already in-memory (manifest + the lazily-loaded
subject-profiles dict, `VolumeSubjectProfilesStore.shared`, `:183`) and need **no** precomputation.
Only the **people-mentions** facet touches the DB; a single async query per selected person is
adequate for an interactive picker — **no precompute needed for v1** ([UNVERIFIED by load test], §9).
Note the people/subject-tag facets can only *reach* indexed data, so a people-driven selection
naturally yields indexed volumes; that is consistent with the FTS grain but under-populates a Series
scope — surface this in the editor.

---

## 6. Per-surface integration cost (S/M/L)

CRITICAL repo facts that double two line items: the **macOS Search window is a separate
implementation** (`SearchSheet`/`MacSearchViewModel`) from iOS (`SearchView`/`SearchViewModel`) —
search work lands twice (memory: "macOS Search is Separate"; bridge at `MacSearchViewModel.swift:406`);
and **Settings is parallel per-platform** (`SettingsView` iOS + `FRUSSettingsView` macOS) — the
management pane lands twice (memory: "Dual Settings Views"; tag-pane precedent
`SettingsView.swift:2115` / `FRUSSettingsView.swift:706`).

| Work item | Size | Why |
|---|---|---|
| `CustomVolumeScope` model + schema enrollment + CloudKit deploy note | **S** | One flat record; the risk is the deploy step, not the code. |
| `CustomScopeResolver` (two grain methods) | **S** | The set is stored; only the intersect/passthrough differ. |
| Scope **editor** (name + volume multi-select; subseries + title facets) | **M** | New shared SwiftUI; reuses manifest bucketing. Subject/people facets are additive (Phase 4). |
| Management pane — **iOS** (`SettingsView`) | **M** | Follows the tag pane (`SettingsView.swift:2115`). |
| Management pane — **macOS** (`FRUSSettingsView`) | **M** | Parallel; follows `FRUSSettingsView.swift:706`. |
| Search filter — **iOS** (`SearchFilterView`) | **S** | Feed a resolved set into `selectedVolumeIds`/`effectiveVolumeIds` (`SearchViewModel.swift:497`). |
| Search filter — **macOS** (`SearchSheet` + `MacSearchViewModel`) | **S** | Separate host; rides the `filterVM` bridge (`:406,503`). |
| `AnalyticsScopeBar` custom-scope section (Person + CrossRef) | **S** | **One** edit to the shared bar (`AnalyticsChartChrome.swift:195`) reaches both hosts. |
| Corpus `AnalyticsView` inline bar (migrate to shared + custom) | **S–M** | The inline duplicate (`AnalyticsView.swift:501-580`) should be folded into the shared bar. |
| `SeriesScopeBar` custom-scope section (3 dashboards) | **M** | One bar edit reaches 3 hosts, but needs the **manifest-grain** resolver path (§2/§4). |
| Word-cloud `.customScope` case (enum + `signature` + resolver + bar) | **M** | Enum round-trip (`WordCloudModels.swift:316,359`) + resolver + precompute queue. |
| Downloads / Summarization adopters | **M** | Optional; different (acquisition) semantics. |

---

## 7. Phasing (repo works in ~0.5–1-day per-PR sessions)

**Phase 1 — minimal end-to-end slice (M–L, ~1.5 sessions).** `CustomVolumeScope` model + schema
enrollment + CloudKit deploy note; `CustomScopeResolver`; the scope editor with the two **cheap**
facets (subseries + title multi-select); **one** consuming surface — **iOS Search advanced filter**
(highest-value, and its two-picker model already ingests a flat volume set); **iOS** management pane.
This is a shippable vertical: create a named scope, search with it, manage it. *Ships alone.*

**Phase 2 — macOS parity (M, ~1 session).** Search filter (macOS `SearchSheet`/`MacSearchViewModel`)
+ management pane (`FRUSSettingsView`). Closes the platform fork Phase 1 opens.

**Phase 3 — analytics adoption (M, ~1 session).** Custom-scope section in the shared
`AnalyticsScopeBar` (Person + CrossRef in one edit) + migrate the corpus `AnalyticsView` inline bar
onto the shared component (the de-dup consolidation win).

**Phase 4 — Series dashboards + richer selection (M–L, ~1–1.5 sessions).** `SeriesScopeBar`
custom-scope section with the **manifest-grain** resolver; add the subject-tag facet
(`VolumeSubjectProfiles`) and the people-mention facet (`PersonMentionStore`, async) to the editor.

**Phase 5 — deferrable adopters + docs (M).** Word-cloud `.customScope` case; download/summarization
adopters if wanted; the mandatory feature-session **docs pass** (memory:
"Feature-Session Docs Rule" — Docs/ manuals, TestFlight notes, README, in-app
`ResearchGuideView`/`IndexingEducationView`).

**Deferrable/never:** Downloads pickers (#10–12), Summarization (#13) — different semantics, adopt on
demand; `NeighborScope` (#14) — single-anchor, does not fit; the year-range preset menus — date, not
volume.

---

## 8. Risks & open owner questions

**Q1 — Membership grain: whole-manifest or indexed-only?** A custom scope naming un-downloaded
volumes is meaningful to the Series dashboards (they read the manifest, `SeriesScopeBar.swift:16-19`)
but inert for Search (which can only return indexed results). *Options:* (a) **store raw manifest
ids, resolve per-surface** (intersect with `indexedVolumeIds` for FTS) — the scope stays stable as
the user downloads more; **recommended**; (b) restrict membership to indexed volumes — simpler, but
the scope silently *shrinks/grows* with the download set and loses Series meaning. **Recommend (a).**

**Q2 — Static set or dynamic query? (biggest product fork.)** Is a custom scope a frozen *snapshot*
of `volumeId`s, or a stored *predicate* ("all volumes tagged Vietnam") that re-resolves as the corpus
grows? The repo already does dynamic resolution elsewhere — smart collections re-run a `SavedSearch`
at export (`Collection.savedSearchId`, `Collection.swift:108-114`). *Options:* (a) **static set** —
matches the issue's literal "select volumes for inclusion", simplest model+resolver; **recommended
for v1**; (b) dynamic predicate — more powerful, but the predicate must be CloudKit-encodable and the
resolver re-runs the (async, index-dependent) facet queries every read. **Recommend (a), with the
model left open to add an optional predicate field later** (additive, per §3's optional-field rule).

**Q3 — Relationship to the existing `WordCloudScope` enum.** Collapse them, or keep
`CustomVolumeScope` as the persisted record that other scope types *reference by id*? They are
different kinds of thing: `WordCloudScope` is an ephemeral value with a `signature`
(`WordCloudModels.swift:294,359`); `CustomVolumeScope` is a synced record. **Recommend: do not
collapse** — the record is canonical; `WordCloudScope`/`AnalyticsScopeBar` gain a
`.customScope(id:)`/`.custom(UUID)` case that dereferences it.

---

## 9. What the adversarial review should attack

1. **The per-surface S/M/L estimates (§6) — least verified.** I read the scope *models* and their
   bindings, not every host view's full state lifecycle. Most suspect: the **macOS Search filter**
   host (the `filterVM` bridge, `MacSearchViewModel.swift:406,503`, has non-obvious apply timing) and
   the **Series manifest-grain adapter** (§4) — I asserted "one bar edit reaches 3 hosts" without
   tracing each dashboard's `onChange` rebuild.
2. **The `[String]`-array + CloudKit LWW claim (§3).** I inferred field-level last-writer-wins on the
   whole `volumeIds` array from the `NSPersistentCloudKitContainer` default and the `projectIds`
   precedent — **not** run on two devices. If the review can, verify a concurrent two-device
   membership edit and confirm the loss is acceptable (or force per-member records after all).
3. **"AnalyticsView's inline bar is a duplicate that should be consolidated" (#3 in §2, §6).** I read
   `AnalyticsView.swift:501-580` as a hand-rolled copy of `AnalyticsScopeBar`. Attack whether it is
   *intentionally* divergent (some corpus-analytics-specific behaviour) such that folding it in would
   regress something.
4. **People-mention selection needs no precompute (§5).** I claim a per-person async
   `documentKeys(forRollupId:)` query suffices interactively. Not load-tested against a full index; a
   scope built from many people could stack queries.
5. **Manifest-churn tolerance (§3).** The dangling-`volumeId`-on-rename story is reasoned from the
   filename-derived key and existing fallbacks — **[UNVERIFIED]** that OH has ever renamed a shipped
   `volumeId`, and untested that resolution skips dangling ids cleanly on every surface.
6. **The static-vs-dynamic recommendation (§8-Q2).** The single biggest product decision; I sampled
   only the smart-collection precedent. If the owner wants dynamic scopes, Phase 1's model shape and
   the resolver's cost profile both change.
