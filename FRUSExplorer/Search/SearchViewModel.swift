// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Observation

// MARK: - SearchViewModel

/// Manages state and business logic for the Search view.
///
/// Holds the full set of search parameters and drives the results list.
/// Binds directly to `SearchService` for FTS5 queries.
///
/// ## Project Defaults
/// Call `applyProjectDefaults(_:)` after init to pre-populate filters from
/// the active project's default date range and subject tag IDs.
///
/// ## Lifecycle
/// 1. Init with `searchService`.
/// 2. `SearchView` feeds `availableUserTags` from a live `@Query`, so a tag created
///    elsewhere (e.g. the research-note editor) appears as a filter chip without a restart.
/// 3. Optionally call `applyProjectDefaults(_:)` if a project is active.
/// 4. Call `search()` when the user submits.
///
/// ## Suffix Wildcard Limitation
/// Only prefix wildcards are supported by FTS5 (e.g. `negoti*`). The `*`
/// is appended automatically to `prefixWildcard`. Suffix wildcards (`*ate`)
/// are not valid FTS5 syntax and are not exposed in the UI.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: `documentTypeFilter` property added
///   1.2 — Session 40: `personRefText` property and `applyParameters(_:)` added
///   1.3 — Session 62: `showFilterPanel` semantics changed from inline panel to sheet flag
///   1.4 — Session 100: `appState` property for logEvent(.searchSubmit) after search()
///          (both removed in Wave R-2a — see the last entry)
///   1.5 — Session 130: `searchHardLimit = 500` passed to `searchService.search()`; iOS
///          was silently capped at `defaultPageSize = 20` (the macOS VM already used 7 500)
///   1.6 — Session 2026-06-08: `phrase`, `prefixWildcard`, `booleanMode`, and
///          `excludedTermsText` are no longer user-editable — `SearchFilterView`'s
///          "Advanced Text" controls were removed in favour of `FTS5InlineQueryParser`
///          inline syntax in the main search box. The properties remain solely so
///          `applyParameters(_:)` can restore older `SavedSearch`/`pendingSearch`
///          snapshots without data loss.
///   1.7 — Session 163: add `selectedSubseriesIds` + `availableVolumes` for the
///          advanced-filter volume/subseries pickers; `effectiveVolumeIds` unions the
///          two selections; `applyParameters`/`reconstructScope` round-trip a flat
///          `volumeIds` scope back into the two pickers.
///   1.8 — Session 2026-07-04 (macOS UI audit C4): `advancedFilterSignature` added —
///          Equatable fingerprint of the applied advanced-filter fields, observed by
///          the macOS Search window's live filter popover to apply edits immediately.
///   Session 09: `selectedSubjectTagIds` live state removed — persisted subject ids
///         no longer echo into `hasActiveFilters`, emitted parameters, or new
///         `SavedSearch` records (the filter is inert).
///   1.9 — Wave R-4 (2026-07-26): `recordSearchHistory(projectId:in:defaults:)` added —
///          the iOS producer for `SearchHistoryEntry`, which until now had exactly one
///          writer and it was `MacSearchViewModel` (`#if os(macOS)`). An iOS-only
///          researcher's Project Home "Searches Run" tile was therefore structurally
///          always 0 and its Recent Searches card permanently empty. Mirrors the macOS
///          writer's semantics exactly, including the `submittedQuery` de-duplication
///          that keeps a filter/scope-only re-run from minting a second row.
///   2.0 — Wave R-2a: the `.searchSubmit` session event and the `appState` back reference it
///          needed are gone. `SearchHistoryEntry` is the only record of a search now, on both
///          platforms; `ResearchTrailMigration` brings the events earlier builds wrote across,
///          de-duplicated against the entries R-4's producer already wrote.
@Observable
@MainActor
final class SearchViewModel {

    // MARK: - Text Search Parameters

    /// Raw text typed into the main search box, in Google-style inline syntax
    /// (`"phrase"`, `term1 OR term2`, `-excluded`, `term*`) — parsed by
    /// `FTS5InlineQueryParser` in `SearchService`.
    var keywords: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Exact phrase — order-sensitive, case-insensitive. Session 2026-06-08 removed
    /// the dedicated "Exact phrase" field from `SearchFilterView`; users now type
    /// `"quoted phrases"` directly into the main search box, where
    /// `FTS5InlineQueryParser` handles them natively. This property is retained only
    /// so `applyParameters(_:)` can faithfully restore older `SavedSearch`/
    /// `pendingSearch` snapshots that still carry a populated `phrase` value.
    var phrase: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Prefix for a wildcard search. `*` is appended automatically. Session
    /// 2026-06-08 removed the dedicated "Prefix wildcard" field from
    /// `SearchFilterView`; users now type `term*` directly into the main search box.
    /// Retained only for `applyParameters(_:)` restoration of older snapshots.
    var prefixWildcard: String = ""

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// How keyword terms are combined. Default `.and`. Session 2026-06-08 removed
    /// the "Keyword mode" (AND/OR) picker from `SearchFilterView`; users now type
    /// `term1 OR term2` directly into the main search box, where mixed AND/OR/NOT
    /// expressions are supported per-query (something this single global mode never
    /// could express). Retained only for `applyParameters(_:)` restoration.
    var booleanMode: FTS5Query.BooleanMode = .and

    /// Legacy/backward-compatibility only — **no longer user-editable**.
    ///
    /// Comma-separated terms that must NOT appear in matching documents. Session
    /// 2026-06-08 removed the "Excluded terms" field from `SearchFilterView`; users
    /// now type `-word` or `NOT word` directly into the main search box. Retained
    /// only for `applyParameters(_:)` restoration of older snapshots.
    var excludedTermsText: String = ""

    // MARK: - Date Range Parameters

    var dateRangeEnabled: Bool = false

    /// The Years facet's applied selection: documents whose **start year** is one of these (#775).
    ///
    /// `nil` = no year-set filter; an empty array matches nothing (see
    /// `SearchParameters.yearKeys`). Separate from `dateRangeEnabled`/`dateRangeStart`/`End`
    /// because a set of years is not an interval — `{1951, 1953}` cannot be written as a range —
    /// and because the two ask different questions: this one is start-year containment, matching
    /// the facet's own bucket rule, while the date range is interval overlap. They AND.
    var facetYearKeys: [String]? = nil
    var dateRangeStart: Date = Calendar.current.date(byAdding: .year, value: -80, to: .now) ?? .distantPast
    var dateRangeEnd: Date = .now

    // MARK: - Tag Filter Parameters

    // (The former `selectedSubjectTagIds` live state was removed in Session 09 with the
    // document-level subject taxonomy: the SQL filter is inert, so echoing persisted
    // subject ids here would only fake an "active filter" and write retired ids into
    // new SavedSearch records. `SearchParameters.subjectTagIds` itself survives for
    // persistence stability and is always emitted empty from live state.)
    var selectedUserTagIds: Set<UUID> = []

    // MARK: - Content Scope Parameters

    /// Whether document body content (header, dateline, source note, body text)
    /// is included in the search scope. Seeded from the Settings "Search Defaults"
    /// pane (`SearchDefaults`); per-session changes here do not write back.
    var includeDocumentText: Bool = SearchDefaults.scopeDocuments
    var includeSummaries: Bool = SearchDefaults.scopeSummaries
    var includeNotes: Bool = SearchDefaults.scopeNotes

    // MARK: - Document Type Filter

    /// Which document types to include in results. Seeded from the Settings
    /// "Search Defaults" pane (`SearchDefaults`).
    var documentTypeFilter: DocumentTypeFilter = SearchDefaults.documentTypeFilter

    // MARK: - Front Matter Scope

    /// Whether front-matter prose sections (preface, introduction, prefatoryNote, terms, etc.)
    /// are included in search results. Default `true`.
    var includeFrontMatter: Bool = true

    // MARK: - Person Reference Filter

    /// `@ref` attribute value from `<persName>` to restrict results to documents
    /// that mention a specific person. Empty string means no filter.
    var personRefText: String = ""

    /// Cross-corpus person rollup id (the People browser's "Find all mentions" handoff). Restricts
    /// results to documents mentioning any member of the clustered identity. `nil` means no filter.
    var personRollupId: Int?

    /// Active subject bucket from the results facet (#308) — a position in
    /// ``SubjectBucketVocabulary``. `nil` means no subject filter.
    var subjectBucket: Int?

    /// The durable `category`/`subcategory` identity of ``subjectBucket``. See
    /// `SearchParameters.subjectBucketKey`.
    var subjectBucketKey: String?

    /// Active SUBJECT filter from the Subject Explorer (#1023) — the durable ref. `nil` means no
    /// subject filter. Finer than ``subjectBucket``: a bucket is a `(category, subcategory)` pair
    /// and a subject is one of the ~4.6 subjects inside it.
    var subjectRef: String?

    /// Display name of ``subjectRef`` — the fallback half of the durable key AND what the filter
    /// chip says. Both uses need it: a ref alone cannot be shown to a reader, and after an upstream
    /// re-mint it is the only thing that still resolves.
    var subjectName: String?

    /// Display name for the active `personRollupId`/`personRef` filter, shown in the filter chip.
    var personLabel: String?

    /// Durable `(volumeId, ref)` identity behind `personRollupId` (#747).
    ///
    /// `personRollupId` is a **slot number**: the rollup table is rebuilt wholesale and renumbered
    /// from 1 on every correction and every corpus change, so a chip that holds only the integer
    /// starts filtering to a different person the moment anyone merges two identities. The anchor
    /// is a TEI key and does not move, so it survives the rebuild and re-resolves to the current
    /// slot. Captured lazily by ``refreshPersonRollupBinding(using:)`` — the sites that *set* a
    /// rollup id do not have it, because rollup-sourced `PersonIndexEntry`s carry an empty `ref`.
    var personAnchor: PersonRollupAnchor?

    /// Set when the last rebind dropped the person filter because its anchor no longer resolves,
    /// so the view can say so instead of silently widening the result set.
    var droppedPersonFilterNotice: String?

    // MARK: - Volume & Subseries Filter

    /// **Individually** selected volume IDs (the Volumes picker), distinct from the
    /// subseries selection below.
    ///
    /// Empty = no individual-volume constraint. Populated by the post-indexing
    /// "Search this volume" handoff (`IndexingSummaryCard.onSearchVolume` →
    /// `AppState.pendingSearch` → `applyParameters(_:)`), by the Volumes picker in
    /// `SearchFilterView`, and by analytics drill-in handoffs. The *effective* scope
    /// forwarded to `SearchService` is `effectiveVolumeIds` (the union with the
    /// subseries selection), which `IndexingPipeline.searchDocuments` applies SQL-side.
    var selectedVolumeIds: [String] = []

    /// Selected subseries identifiers (the Subseries picker), e.g. `"1969-76"`.
    ///
    /// Each selected subseries expands to all of its **indexed** volumes (from
    /// `availableVolumes`) when computing `effectiveVolumeIds`. Kept separate from
    /// `selectedVolumeIds` so the two pickers round-trip independently.
    var selectedSubseriesIds: Set<String> = []

    /// Indexed volumes available to the volume/subseries pickers, loaded via
    /// `loadAvailableVolumes(allEntries:indexedIds:)`. Only indexed volumes appear so
    /// users cannot scope to a volume that can never return results.
    var availableVolumes: [VolumeManifestEntry] = []

    // MARK: - Project Scope (#377 Phase 2)

    /// How the active project constrains this search. `.off` (the default) ignores the
    /// project; `.history` gates results to `projectEngagedDocumentKeys`.
    ///
    /// The filter panel exposes the picker only when `projectEngagedDocumentKeys` is
    /// non-empty (i.e. a project is active and has engaged documents), so this stays
    /// `.off` and inert in Global Context.
    var projectScope: ProjectSearchScope = .off

    /// The active project's engaged `"volumeId/documentId"` keys, loaded by the view
    /// from live project activity (`ProjectEngagedDocuments`). Empty when no project is
    /// active or the project has engaged no documents.
    ///
    /// When `projectScope == .history`, this becomes `SearchParameters.documentIds`: a
    /// non-empty set gates the FTS query to exactly these documents, and an empty set
    /// (History chosen for a project with no history yet) matches nothing.
    var projectEngagedDocumentKeys: [String] = []

    /// The active project's display name, for the scope picker's label. `nil` in Global
    /// Context.
    var projectScopeName: String?

    /// The volumes the active project's focus subjects are characteristic of (#377 Phase 2b),
    /// resolved by the view from `Project.defaultSubjectTagIds` via `VolumeSubjectProfiles`.
    /// When `projectScope == .focus`, this becomes `SearchParameters.volumeIds` — a discovery
    /// scope over the corpus. Empty when the project has no focus subjects (then `.focus` is
    /// not offered).
    var projectFocusVolumeIds: [String] = []

    /// The Focus-mode "only new to this project" toggle (#377 Phase 2b, default off): when on,
    /// `projectEngagedDocumentKeys` becomes `SearchParameters.excludeDocumentIds`, dropping
    /// documents already collected/annotated/visited so discovery emphasizes fresh material.
    var projectOnlyNew: Bool = false

    /// The volumes a project's focus subjects are characteristic of, resolved via the bundled
    /// volume-subject profiles (#377 Phase 2b). Empty when the project has no focus subjects
    /// or the profiles are unavailable. An in-memory lookup — safe to call synchronously.
    /// Shared by the iOS `SearchView` and the macOS `SearchSheet` so Focus resolves the same
    /// way on both.
    static func focusVolumeIds(for project: Project?) -> [String] {
        guard let project, !project.defaultSubjectTagIds.isEmpty,
              let profiles = VolumeSubjectProfilesStore.shared else { return [] }
        return profiles.volumeIds(forSubjectRefs: project.defaultSubjectTagIds).sorted()
    }

    /// Equatable fingerprint of every advanced-filter field that
    /// `MacSearchViewModel.applyAdvancedFilters()` copies back into its parameters.
    ///
    /// Observed by the macOS Search window (`.onChange` inside the live filter
    /// popover, UI audit C4) so edits apply to the result list immediately instead
    /// of batching on dismiss. Reading it inside a view body registers Observation
    /// tracking on all constituent fields. The legacy non-editable fields (`phrase`,
    /// `prefixWildcard`, `booleanMode`, `excludedTermsText`) are excluded — they
    /// cannot change while the popover is open.
    var advancedFilterSignature: String {
        var parts: [String] = []
        parts.append(dateRangeEnabled
            ? "d1|\(dateRangeStart.timeIntervalSinceReferenceDate)|\(dateRangeEnd.timeIntervalSinceReferenceDate)"
            : "d0")
        // #775: the Years facet's set. Without it macOS's `applyAdvancedFilters` never fires on a
        // year selection — the signature is what tells it the filter state changed — so the set
        // would be applied, shown, and silently ignored by the search. Exactly M-1 again.
        parts.append(facetYearKeys.map { $0.sorted().joined(separator: ",") } ?? "y-")
        parts.append(personRefText)
        parts.append(personRollupId.map(String.init) ?? "")
        parts.append(personLabel ?? "")
        parts.append(String(describing: documentTypeFilter))
        parts.append(includeDocumentText ? "1" : "0")
        parts.append(includeSummaries ? "1" : "0")
        parts.append(includeNotes ? "1" : "0")
        // The fourth scope, missing until now: the Mac's live "Include front matter" toggle moved
        // and nothing re-applied. See `AdvancedFilterSignatureTests`, which pins the whole class.
        parts.append(includeFrontMatter ? "1" : "0")
        parts.append(selectedSubseriesIds.sorted().joined(separator: ","))
        // M-1: without this the Mac's `applyAdvancedFilters` never fires on an apply or a clear —
        // the signature is what tells it the filter VM changed — so the corpus was set, shown as
        // applied, and silently ignored by the search. The count is enough to distinguish; the keys
        // themselves can be thousands of strings and this runs on every filter edit.
        parts.append(appliedWorkingCorpusName ?? "")
        parts.append(String(appliedWorkingCorpusKeys?.count ?? -1))
        parts.append(selectedVolumeIds.joined(separator: ","))
        // User-tag filter (188-D): sorted for order-independence so toggling a tag perturbs the
        // signature deterministically, which drives the macOS live-apply observer (#212). iOS
        // does not observe this signature, so its behavior is unchanged.
        parts.append(selectedUserTagIds.map(\.uuidString).sorted().joined(separator: ","))
        // Project scope (#377 Phase 2): a scope change must perturb the signature so the
        // macOS live-apply observer copies the resulting gates into `parameters`. Focus mode's
        // "only new" toggle is part of the scope, so it joins the fingerprint too.
        parts.append("ps|\(projectScope.rawValue)|\(projectOnlyNew ? 1 : 0)")
        return parts.joined(separator: "§")
    }

    // MARK: - Results

    var results: [SearchResult] = [] {
        didSet { if currentPage >= totalPages { currentPage = 0 } }
    }
    /// Every document matching the query, uncapped — or `nil` when the count could not be taken.
    ///
    /// ## Why this now exists, having been argued against
    /// The doc comment on `recordSearchHistory` recorded the decision not to have one: "adding
    /// [a count] would put a second FTS5 `COUNT(*)` on every iPhone search to improve a number
    /// nothing yet displays". Both halves have changed. ``ResultSetScope`` displays it — in the
    /// capture warning, in the corpus's own stored provenance, and in the results header — and the
    /// cost turns out not to be a second query's worth of work.
    ///
    /// Measured against the real 6.3 GB store, a filtered count over a date range, as the marginal
    /// cost of running it directly after the search that shares its joins:
    ///
    ///     term            filtered match   search    count     marginal
    ///     petroleum            1,506       0.099 s   0.021 s      21%
    ///     negotiations        35,275       0.974 s   0.104 s      11%
    ///     ambassador          53,388       1.189 s   0.156 s      13%
    ///
    /// Taken cold and alone the same count is 10.96 s — but that is the first touch of the join
    /// pages, and `searchDocuments` pays it already: it emits the identical CTE, joins and WHERE,
    /// differing only by `ORDER BY m.score LIMIT n`, and ordering on a computed score means the
    /// join is evaluated for **every** matched row however small the limit. The expensive part is
    /// not added by counting; it is already the search's.
    ///
    /// `nil` rather than a fallback when the count fails: a wrong total is worse than none here,
    /// since it becomes the denominator stored on a working corpus.
    var totalMatchCount: Int?

    /// The FTS5 expression the last completed search executed, captured during `search()`.
    ///
    /// Recorded there rather than re-derived in `recordSearchHistory` for two reasons: the
    /// renderer lives on the `SearchService` actor and cannot be reached from the synchronous
    /// recorder, and a later re-derivation would describe whatever the parameters are THEN. An
    /// appendix entry has to carry the expression that produced its count.
    var lastRenderedExpression: String?

    var isSearching: Bool = false
    var searchError: String? = nil
    var hasSearched: Bool = false

    /// Increments once per executed search — a stable `.task(id:)` key for views that
    /// must recompute when a search *runs*, not when its text changes.
    var executedSearchVersion: Int = 0

    // MARK: - Sorting (#305)

    /// Result ordering. `relevance` = FTS5 BM25 (as returned); the date orders use `dateISO`.
    /// Changing it resets to the first page so the user sees the top of the re-sorted list.
    var sortOrder: SearchSortOrder = .relevance {
        didSet { if sortOrder != oldValue { currentPage = 0 } }
    }

    /// `results` ordered by `sortOrder`. Date sorting uses the structured `dateISO` value
    /// (`yyyy-MM-dd`); undated rows go last in both directions and ISO-date ties break by BM25
    /// (more relevant first). Mirrors `MacSearchViewModel.allSortedResults`.
    var sortedResults: [SearchResult] {
        switch sortOrder {
        case .relevance:      return results
        case .dateAscending:  return results.sorted { Self.dateOrder($0, $1, ascending: true) }
        case .dateDescending: return results.sorted { Self.dateOrder($0, $1, ascending: false) }
        }
    }

    /// Tuple comparator for date-asc / date-desc: undated rows always last; ISO-date ties break by
    /// BM25 (lower = more relevant first).
    private static func dateOrder(_ lhs: SearchResult, _ rhs: SearchResult, ascending: Bool) -> Bool {
        switch (lhs.dateISO, rhs.dateISO) {
        case let (a?, b?):
            if a == b { return lhs.bm25Score < rhs.bm25Score }
            return ascending ? a < b : a > b
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return lhs.bm25Score < rhs.bm25Score
        }
    }

    // MARK: - Checklist Mode (#189-D)

    /// True when checklist mode is active. Session-scoped; not persisted (resets on relaunch).
    /// While on, results the user has reviewed this session are hidden.
    var checklistMode: Bool = false {
        didSet { clampCurrentPage() }
    }

    /// The instant checklist mode was last enabled. Documents opened at or after this instant
    /// (per `ReadingHistoryEntry.accessedAt`) are hidden. `nil` while mode is off.
    var checklistEnabledAt: Date?

    /// `(volumeId|documentId)` keys the user opened since `checklistEnabledAt`, fetched from
    /// `ReadingHistoryEntry` by `SearchView` and pushed in (mirrors `availableUserTags`).
    var readSinceEnabledKeys: Set<String> = [] {
        didSet { clampCurrentPage() }
    }

    /// `(volumeId|documentId)` keys the user tapped "Mark reviewed" on this session — a
    /// lightweight in-memory set, NOT a fabricated `ReadingHistoryEntry`.
    var markedReviewedKeys: Set<String> = [] {
        didSet { clampCurrentPage() }
    }

    /// A stable reviewed-set key for a `(volume, document)` pair.
    nonisolated static func reviewedKey(volumeId: String, documentId: String) -> String {
        "\(volumeId)|\(documentId)"
    }

    /// The reviewed set while checklist mode is on: docs opened since enable ∪ docs marked.
    var hiddenReviewedKeys: Set<String> {
        checklistMode ? readSinceEnabledKeys.union(markedReviewedKeys) : []
    }

    /// `sortedResults` minus reviewed docs when checklist mode is on. All display-time page math
    /// pages over this array, so the slice, count, and page index stay in sync.
    var displayedResults: [SearchResult] {
        let hidden = hiddenReviewedKeys
        guard !hidden.isEmpty else { return sortedResults }
        return sortedResults.filter { !hidden.contains(Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId)) }
    }

    /// Enables/disables checklist mode. Enabling stamps the anchor time and clears prior marks;
    /// disabling clears all reviewed state so the full list returns.
    func setChecklistMode(_ on: Bool) {
        checklistMode = on
        if on {
            checklistEnabledAt = .now
            markedReviewedKeys.removeAll()
        } else {
            checklistEnabledAt = nil
            readSinceEnabledKeys.removeAll()
            markedReviewedKeys.removeAll()
        }
        currentPage = 0
    }

    /// Marks a document reviewed for this checklist session (hides it without opening it).
    func markReviewed(volumeId: String, documentId: String) {
        markedReviewedKeys.insert(Self.reviewedKey(volumeId: volumeId, documentId: documentId))
    }

    /// Resets `currentPage` to 0 when a reviewed-set change shrank the list below the current page.
    private func clampCurrentPage() {
        if currentPage >= totalPages { currentPage = 0 }
    }

    // MARK: - Available Filter Options

    /// The user's tags, used to render the filter panel's tag chips and to resolve
    /// tag UUIDs to names in result rows. Fed by `SearchView` from a live SwiftData
    /// `@Query`, so newly-created tags appear without an app restart.
    var availableUserTags: [UserTag] = []

    // MARK: - UI State

    /// Controls presentation of the `SearchFilterView` sheet.
    /// Set to `true` by the filter toolbar button; `false` when the sheet is dismissed.
    var showFilterPanel: Bool = false
    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Pagination

    /// Maximum results fetched by `search()` for a query with text in it.
    ///
    /// iOS pages through results (`pageSize` per page) rather than rendering them in one
    /// continuous list, so the full set is materialised in memory but only a single page
    /// of rows is ever rendered. Raised from 500 → 1 000 once pagination bounded the
    /// render cost. The macOS search window uses a separate hard limit of 7 500.
    ///
    /// The binding cost is not the rows, it is `body_text`: a keyword query needs it to build each
    /// row's context snippet, and it measures a 7,416-character mean over the corpus — ~7.7 MB per
    /// thousand rows, off SQLite overflow pages. That is what this ceiling bounds.
    static let searchHardLimit: Int = 1_000

    /// Maximum results fetched for a **filter-only browse** — a subject or person constraint with
    /// no keyword, phrase, or prefix.
    ///
    /// Higher than `searchHardLimit` because the row is a different size. A browse has no query
    /// terms, so `SearchService` cannot build a context snippet and the fetch does not select
    /// `body_text` at all; measured, a 1,000-row browse window carried 7,694,772 bytes of body
    /// before that change and **0 after**, at half the wall time. What remains is header, dateline,
    /// source note and tag ids — a few hundred bytes a row, so 7,500 costs less than the old 1,000.
    ///
    /// 7,500 is chosen against the data rather than by symmetry with macOS: measured over the
    /// shipped subject index, a 1,000-row ceiling returns every document for 69% of subjects and
    /// 7,500 does so for **95%**. The remaining 5% are the corpus-wide subjects (*War* reaches
    /// 58,480 documents) where no ceiling a phone should hold would help, and where the
    /// "loaded · total" header is the honest answer.
    static let filterOnlyHardLimit: Int = 7_500

    /// The ceiling the CURRENT results were actually fetched at.
    ///
    /// **Recorded at fetch time, not recomputed from `searchParameters`.** Those are the live
    /// filter state and may have moved since the search ran — the same reason `resultsSnapshot`
    /// passes `submittedSearchParameters` rather than the live value. Deriving the cap from them
    /// would make `isResultsCapped` and the facet total answer for a query the user is still
    /// typing, and both of those decide whether the app claims a count is complete.
    private(set) var lastFetchLimit: Int = searchHardLimit

    /// Number of results rendered per page on iOS.
    static let pageSize: Int = 25

    /// Zero-based index of the currently displayed results page.
    var currentPage: Int = 0

    /// Total number of result pages for the currently-displayed (checklist-filtered) set (≥ 1).
    var totalPages: Int {
        max(1, Int(ceil(Double(displayedResults.count) / Double(Self.pageSize))))
    }

    /// The slice of `displayedResults` shown on the current page. Only these rows are rendered,
    /// keeping the list bounded regardless of how many results were fetched. The page index is
    /// clamped here (side-effect-free) so a reviewed-set change that shrinks the list can never
    /// leave `pagedResults` returning a blank page for a now-out-of-range `currentPage`.
    var pagedResults: [SearchResult] {
        let base = displayedResults
        let page = min(max(0, currentPage), totalPages - 1)
        let start = page * Self.pageSize
        guard start < base.count else { return [] }
        return Array(base[start..<min(start + Self.pageSize, base.count)])
    }

    // MARK: - Dependencies

    private let searchService: SearchService

    // Wave R-2a: the `weak var appState` injected here since Session 100 existed solely so
    // `search()` could fire `AppState.logEvent(.searchSubmit(…))`. That writer is retired, and
    // `SearchView` passes the active project id to `recordSearchHistory` directly, so the back
    // reference is gone rather than left as an unread property.

    // MARK: - Initialisation

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // MARK: - Setup

    /// Populates `availableVolumes` with the indexed subset of `allEntries`, sorted by
    /// volume ID, for the volume/subseries pickers in `SearchFilterView`.
    ///
    /// - Parameters:
    ///   - allEntries: Every known volume (typically `manifestStore.diffResult?.known
    ///     ?? manifestStore.bundledEntries`).
    ///   - indexedIds: The set of volume IDs that have been indexed
    ///     (`AppState.indexedVolumeIds`).
    func loadAvailableVolumes(allEntries: [VolumeManifestEntry], indexedIds: Set<String>) {
        availableVolumes = allEntries
            .filter { indexedIds.contains($0.volumeId) }
            .sorted { $0.volumeId < $1.volumeId }
    }

    func applyProjectDefaults(_ project: Project?) {
        guard let project else { return }
        if let start = project.defaultDateRangeStart,
           let end = project.defaultDateRangeEnd {
            dateRangeEnabled = true
            dateRangeStart = start
            dateRangeEnd = end
        }
        // Project.defaultSubjectTagIds is deliberately NOT applied: subject-tag
        // filtering is inert since Session 09 (see SearchParameters.subjectTagIds).
    }

    // MARK: - Search

    /// The keyword text of the search most recently *executed*, trimmed.
    ///
    /// Frozen at the top of `search()` rather than read from `keywords` at recording time:
    /// `keywords` is bound live to the `.searchable` field, so a user who keeps typing while
    /// the FTS5 query is in flight would otherwise have the *later* text recorded against the
    /// *earlier* search. Named for its macOS counterpart, `MacSearchViewModel.submittedQuery`.
    private var submittedQuery: String = ""

    func search() async {
        let params = searchParameters
        // A person or subject filter is a valid standalone constraint — `SearchService`
        // applies it SQL-side, so "Find all mentions" handoffs (which carry only
        // a `personRef`) can run without a keyword. Before Session 162 this guard
        // rejected them, so the person handoff surfaced an error instead of results.
        let hasPositiveTerm = params.keywords != nil
            || params.phrase != nil
            || params.prefixWildcard != nil
            || params.supportsFilterOnlySearch
        guard hasPositiveTerm else {
            searchError = String(
                localized: "search.error.empty",
                defaultValue: "Enter a keyword, phrase, or prefix to search."
            )
            return
        }
        // Freeze the query text for `recordSearchHistory` before awaiting anything (see
        // `submittedQuery`).
        submittedQuery = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        searchError = nil
        hasSearched = true
        do {
            // Concurrently, not sequentially: the two statements share their joins, so the
            // second runs against pages the first has already faulted in. Mirrors
            // `MacSearchViewModel.performSearch`, which has always done it this way.
            // A browse fetches deeper than a keyword search because its rows are far smaller —
            // no `body_text`, since there are no terms to snippet against. See `filterOnlyHardLimit`.
            let fetchLimit = params.runsAsFilterOnly ? Self.filterOnlyHardLimit : Self.searchHardLimit
            lastFetchLimit = fetchLimit
            async let fetched = searchService.search(parameters: params, limit: fetchLimit)
            async let counted: Int? = {
                // A failed count must not fail the search. The header and the capture warning
                // both degrade to "total unavailable", which is what macOS already shows.
                do { return try await searchService.searchCount(parameters: params) }
                catch { return nil }
            }()
            results = try await fetched
            totalMatchCount = await counted
            // Same actor hop as the fetch, no query: a thin face on the renderer the search used.
            lastRenderedExpression = try? await searchService.matchExpressions(for: params).corpus
            // Bumped AFTER `results` is replaced, so the "completed search" the doc comment
            // promises is what consumers actually observe. It used to be bumped in the
            // synchronous prefix, five lines and one actor hop earlier: SwiftUI re-evaluated the
            // body during the await — it must, or the `isSearching` spinner would never appear —
            // and every `.task(id:)` keyed on the version fired against the PREVIOUS query's
            // results. The concordance survived that by accident, because its key also carries the
            // page and `currentPage = 0` re-triggered it; a key without a page member had no such
            // rescue and settled on a confident ranking of the wrong documents. Matches
            // `MacSearchViewModel.performSearch`, which has always ordered these correctly.
            executedSearchVersion &+= 1
            currentPage = 0
            // A new query is a fresh checklist (#189-D): re-anchor "reviewed since" to now and
            // clear prior marks, so results reviewed under a *previous* query aren't silently
            // hidden in this one (the reviewed key is document identity, which recurs across
            // searches). The read-since observer re-queries against the new anchor.
            if checklistMode {
                checklistEnabledAt = .now
                readSinceEnabledKeys.removeAll()
                markedReviewedKeys.removeAll()
            }
            #if DEBUG
            print("[SearchView] Search returned \(results.count) results")
            #endif
        } catch {
            results = []
            // Cleared with the results, at every site that clears them: a total left over from
            // the previous query is a denominator for a set that no longer exists.
            totalMatchCount = nil
            lastRenderedExpression = nil
            // Bumped here too: a failed search is a completed one for every consumer keyed on the
            // version, and leaving it unchanged would strand them on the previous query's answer.
            executedSearchVersion &+= 1
            searchError = error.localizedDescription
            #if DEBUG
            print("[SearchView] Search error: \(error)")
            #endif
        }
        isSearching = false
        // Wave R-2a: the `appState?.logEvent(.searchSubmit(…))` that stood here is gone, as R-4
        // said it would be. `SearchView.runSearch()` calls `recordSearchHistory` immediately after
        // this method returns, and that `SearchHistoryEntry` is now the only record of a search —
        // read by the History surface, Project Home, and the derived session log alike.
        // `ResearchTrailMigration` carries the events already written by earlier builds across.
    }

    // MARK: - Search History

    /// What this screen last wrote to the trail — see ``SearchHistoryWriter/Anchor``.
    ///
    /// Several of `SearchView`'s entry points re-run `search()` for the **same** query with a
    /// changed filter — clearing the volume scope, tapping a tag chip on a result row. Those are
    /// not separate searches the researcher ran, so they refresh the anchored row rather than
    /// minting a second one. Held here rather than derived from the table, which is shared across
    /// windows, devices and projects.
    private var historyAnchor: SearchHistoryWriter.Anchor?

    /// Records the most recently executed search — the iOS half of the trail's search producer.
    ///
    /// Call once after `search()` completes; `SearchView.runSearch()` is the single site that does
    /// so, which is why every search entry point in that view routes through it. All the rules —
    /// the research-logging gate, the empty-query and error skips, and the insert-or-refresh
    /// decision — live in ``SearchHistoryWriter``, shared with macOS, because two copies of them
    /// is how #612 shipped a trail whose two platforms disagreed about the same query's count.
    ///
    /// - Parameters:
    ///   - projectId: the project active at execution, or `nil` in global context.
    ///   - indexedVolumeCount: how many volumes this device has indexed — the denominator.
    ///   - context: the context to write to.
    ///   - defaults: where the research-logging switch is read from.
    func recordSearchHistory(projectId: UUID?,
                             indexedVolumeCount: Int? = nil,
                             in context: ModelContext,
                             defaults: UserDefaults = .standard) {
        let outcome = SearchHistoryWriter.record(
            SearchHistoryWriter.Reading(
                queryText: submittedQuery,
                // The true total when there is one, the fetched count otherwise. `resultCount`
                // cannot express "unknown", so the honest fallback is what was actually seen.
                resultCount: totalMatchCount ?? results.count,
                loadedCount: results.count,
                matchCount: totalMatchCount,
                fetchLimit: lastFetchLimit,
                indexedVolumeCount: indexedVolumeCount,
                // The executed parameters, not the live filter state — those may have moved.
                parameters: submittedSearchParameters,
                appliedCorpusId: appliedWorkingCorpusId,
                // Rendered in `search()` against these parameters. Deliberately NOT the Query
                // Inspector, which is debounced view state keyed on the live text.
                renderedExpression: lastRenderedExpression,
                projectId: projectId,
                hasError: searchError != nil),
            anchor: &historyAnchor,
            in: context,
            defaults: defaults)
        #if DEBUG
        print("[SearchViewModel] SearchHistoryEntry \(outcome): \"\(submittedQuery)\"")
        #else
        _ = outcome
        #endif
    }

    func clearFilters() {
        phrase = ""
        prefixWildcard = ""
        booleanMode = .and
        excludedTermsText = ""
        dateRangeEnabled = false
        facetYearKeys = nil
        selectedUserTagIds = []
        selectedVolumeIds = []
        selectedSubseriesIds = []
        includeDocumentText = SearchDefaults.scopeDocuments
        includeSummaries = SearchDefaults.scopeSummaries
        includeNotes = SearchDefaults.scopeNotes
        includeFrontMatter = true
        documentTypeFilter = SearchDefaults.documentTypeFilter
        personRefText = ""
        personRollupId = nil
        personLabel = nil
        personAnchor = nil
        // #308. Clear Filters must reach a facet-panel narrowing too — it is set by a single tap
        // and is exactly the kind a reader would expect this button to undo.
        subjectBucket = nil
        subjectBucketKey = nil
        // Reset the project scope selection + Focus "only new" toggle (keep the loaded
        // engaged-key/focus-volume sets — they are context, not user filters, and
        // re-populate only when the project changes).
        projectScope = .off
        projectOnlyNew = false
        // Cleared with the rest. Leaving it made Clear Filters a promise it did not keep for the
        // one filter the control could not display either.
        clearWorkingCorpus()
    }

    func clearAll() {
        keywords = ""
        clearFilters()
        results = []
        totalMatchCount = nil
        lastRenderedExpression = nil
        hasSearched = false
        searchError = nil
    }

    // MARK: - Computed Properties

    /// The effective volume scope forwarded to `SearchService`: the de-duplicated
    /// union of the individually-selected volumes (`selectedVolumeIds`) and every
    /// indexed volume belonging to a selected subseries (`selectedSubseriesIds`).
    ///
    /// Empty when no volume or subseries filter is active, in which case
    /// `searchParameters` passes `nil` (search the whole indexed corpus).
    var effectiveVolumeIds: [String] {
        var ids = Set(selectedVolumeIds)
        if !selectedSubseriesIds.isEmpty {
            for entry in availableVolumes where selectedSubseriesIds.contains(entry.subseries) {
                ids.insert(entry.volumeId)
            }
        }
        return ids.sorted()
    }

    /// The applied working corpus, as its **indexed** document keys, or `nil` when none is applied.
    ///
    /// Document-grain scope (M-1). Held as resolved keys rather than as the corpus's identifier so
    /// the search parameters stay a self-contained value — the same reason `documentIds` exists at
    /// all — and so an applied corpus survives the corpus being renamed mid-session.
    var appliedWorkingCorpusKeys: [String]?

    /// The corpus's name, for the applied-scope chip. Cleared with the keys.
    var appliedWorkingCorpusName: String?

    /// The applied corpus's id, recorded so a trail entry can resolve its truncation later.
    /// Names are deliberately not unique, so an entry keyed on the name could resolve the wrong
    /// corpus's capture and mislabel its own count as partial or complete.
    var appliedWorkingCorpusId: UUID?

    /// What is known about the applied corpus's own truncation, captured at the moment it is
    /// applied because that is the only place the `WorkingCorpus` object is in hand.
    ///
    /// Carried alongside the keys rather than looked up by name later: names are deliberately not
    /// unique (`WorkingCorpus` says so — uniqueness cannot be guaranteed across CloudKit devices),
    /// so a by-name lookup could resolve the wrong corpus's truncation onto the applied one.
    var appliedWorkingCorpusTruncation: WorkingCorpus.CaptureTruncation?

    /// Clears any applied working corpus.
    func clearWorkingCorpus() {
        appliedWorkingCorpusKeys = nil
        appliedWorkingCorpusName = nil
        appliedWorkingCorpusId = nil
        appliedWorkingCorpusTruncation = nil
    }

    /// The volume scope + History/Focus document gate the active project scope produces
    /// (#377 Phase 2). History gates `documentIds` to the engaged set. Focus scopes to
    /// volumes: a **manual** volume selection (or applied custom scope) *overrides* the
    /// subject-derived focus volumes, otherwise the subject volumes apply; a Focus scope
    /// with neither matches nothing (an empty `documentIds`, mirroring History's empty-set
    /// contract) rather than silently searching the whole corpus.
    private var projectScopedGates: (volumeIds: [String]?, documentIds: [String]?) {
        let manualVolumes = effectiveVolumeIds.isEmpty ? nil : effectiveVolumeIds
        switch projectScope {
        case .off:
            return (manualVolumes, nil)
        case .history:
            return (manualVolumes, projectEngagedDocumentKeys)
        case .focus:
            if let manualVolumes { return (manualVolumes, nil) }        // manual overrides
            return projectFocusVolumeIds.isEmpty
                ? (nil, [])                                             // neither → match nothing
                : (projectFocusVolumeIds, nil)                         // subject-derived
        }
    }

    /// The parameters of the search that actually **ran**.
    ///
    /// `searchParameters` reads the live `keywords` field, which changes on every keystroke. Any
    /// consumer describing the results on screen — the concordance, the collocation — must anchor on
    /// what produced them, or it reports on a query the user has typed but not run. Mirrors
    /// `MacSearchViewModel.submittedSearchParameters`, which this side lacked.
    var submittedSearchParameters: SearchParameters {
        var params = searchParameters
        let trimmed = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    var searchParameters: SearchParameters {
        let kw = keywords.trimmingCharacters(in: .whitespaces)
        let ph = phrase.trimmingCharacters(in: .whitespaces)
        let pw = prefixWildcard.trimmingCharacters(in: .whitespaces)
        let excluded = excludedTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let range: DateRange? = dateRangeEnabled
            ? DateRange(
                earliest: SearchViewModel.isoDate(dateRangeStart),
                latest: SearchViewModel.isoDate(dateRangeEnd)
              )
            : nil
        let scoped = projectScopedGates
        return SearchParameters(
            keywords: kw.isEmpty ? nil : kw,
            phrase: ph.isEmpty ? nil : ph,
            booleanMode: booleanMode,
            excludedTerms: excluded,
            prefixWildcard: pw.isEmpty ? nil : pw,
            dateRange: range,
            yearKeys: facetYearKeys,
            subjectTagIds: [],
            userTagIds: selectedUserTagIds.map(\.uuidString),
            volumeIds: scoped.volumeIds,
            documentIds: DocumentScopeGate.combine(corpus: appliedWorkingCorpusKeys,
                                                   projectGate: scoped.documentIds),
            // Project Focus "only new" (#377 Phase 2b): excludes the engaged set so discovery
            // emphasizes fresh material. Only in `.focus` with the toggle on.
            excludeDocumentIds: (projectScope == .focus && projectOnlyNew)
                ? projectEngagedDocumentKeys : nil,
            includeDocumentText: includeDocumentText,
            includeSummaries: includeSummaries,
            includeNotes: includeNotes,
            documentTypeFilter: documentTypeFilter,
            personRef: personRefText.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : personRefText.trimmingCharacters(in: .whitespaces),
            personRollupId: personRollupId,
            personLabel: personLabel,
            personAnchor: personAnchor,
            includeFrontMatter: includeFrontMatter,
            subjectBucket: subjectBucket,
            subjectBucketKey: subjectBucketKey,
            subjectRef: subjectRef,
            subjectName: subjectName
        )
    }

    /// The number of results currently shown to the user — the checklist-filtered count, so the
    /// results-count header matches the visible rows.
    var resultCount: Int { displayedResults.count }

    /// `true` when the result set hit the ceiling it was fetched at, indicating the query matches
    /// more documents than are shown. Users should narrow their search terms. Keyed on the raw
    /// fetch count (not the checklist-filtered view), since the cap is about the FTS5 fetch.
    ///
    /// Compares against `lastFetchLimit`, which differs by query shape: a browse is fetched to
    /// `filterOnlyHardLimit`. Comparing against the keyword ceiling instead would call a
    /// 7,500-row browse "not capped" at exactly the point it is.
    var isResultsCapped: Bool { results.count == lastFetchLimit }

    // Note: this still checks the legacy `phrase`/`prefixWildcard`/`excludedTermsText`/
    // `booleanMode` fields even though `SearchFilterView` no longer exposes controls for
    // them — a restored `SavedSearch`/`pendingSearch` snapshot can still populate them via
    // `applyParameters(_:)`, and when it does, that state genuinely affects the query, so
    // the "Clear Filters" affordance must remain available to reset it.
    /// The search service, for tests that need to drive the count loader.
    var searchServiceForTesting: SearchService { searchService }

    /// How many documents in the current result set carry each user tag, keyed by
    /// `UUID.uuidString` (R-1 follow-up).
    ///
    /// Populated on demand when the filter sheet opens — never eagerly, and never for the
    /// facet panel. An absent key means the tag matched nothing, or counts have not been
    /// computed; the surface distinguishes those with ``hasUserTagCounts``.
    var userTagCounts: [String: Int] = [:]

    /// Whether the tag counts have been computed for the current match.
    ///
    /// Separate from `userTagCounts.isEmpty`, because "every tag matched nothing" and "not
    /// computed yet" must render differently — the first is an answer.
    var hasUserTagCounts: Bool = false

    /// Whether the count pass is running.
    var isCountingUserTags: Bool = false

    /// Counts each of `tags` against the result set `matchParameters` describes.
    ///
    /// - Parameter matchParameters: the query to count against. Passed in rather than read
    ///   from `self` because on macOS this view model is the *filter sheet's* — seeded by
    ///   `MacSearchViewModel.syncToFilterVM`, which copies `phrase` but **not** `keywords`.
    ///   Counting against `self.searchParameters` there would silently describe a different
    ///   result set than the one on screen.
    func loadUserTagCounts(
        matching matchParameters: SearchParameters,
        tags: [UserTag],
        service: SearchService?,
        pipeline: IndexingPipeline?
    ) async {
        guard let service, let pipeline, !tags.isEmpty else { return }
        isCountingUserTags = true
        defer { isCountingUserTags = false }
        do {
            let expressions = try await service.matchExpressions(for: matchParameters)
            let filters = await service.filtersForTesting(matchParameters)
            let counts = try await pipeline.userTagCounts(
                corpusMatch: expressions.corpus, userContentMatch: expressions.userContent,
                filters: filters, tagIds: tags.map(\.id.uuidString))
            guard !Task.isCancelled else { return }
            userTagCounts = counts
            hasUserTagCounts = true
        } catch {
            // A query with no searchable content throws `emptyQuery`; that is not a count
            // failure and must not leave `hasUserTagCounts` true with stale numbers.
            userTagCounts = [:]
            hasUserTagCounts = false
        }
    }

    /// The match total to show the facet panel, or `nil` when it is not known (R-1c).
    ///
    /// iOS has never held a whole-query count: `resultCount` is the *fetched* count, capped
    /// at `searchHardLimit` (1,000). So this returns the fetched count only when the fetch
    /// demonstrably did **not** hit its cap — at the cap the real total is unknown, and
    /// reporting 1,000 as "all 1,000 matches" would be exactly the lie the Q-M2 work removed
    /// from macOS. The panel renders "total unavailable" instead.
    ///
    /// The facet *sections* are unaffected either way: they aggregate over the whole match in
    /// SQL, independent of what was fetched.
    var totalMatchCountForFacets: Int? {
        // The real total when one was taken; otherwise the old rule, which refuses to report the
        // fetched count as a total once the fetch hit its ceiling. The fallback is not dead code —
        // `searchCount` can fail, and `nil` is what the panel already renders as "total
        // unavailable".
        totalMatchCount ?? Self.facetTotal(fetched: results.count, cap: lastFetchLimit)
    }

    /// The rule behind ``totalMatchCountForFacets``, extracted so it can be tested at the
    /// boundary.
    ///
    /// It has to be: a test that only exercises an empty result set cannot distinguish
    /// "return the fetched count" from "return nil at the cap" — both give 0 — and a
    /// mutation replacing the whole rule with `fetched` passed on exactly that basis.
    /// Reaching the real cap in a test would need a thousand-document fixture.
    static func facetTotal(fetched: Int, cap: Int) -> Int? {
        fetched >= cap ? nil : fetched
    }

    /// Applies a facet narrowing (R-1c).
    ///
    /// iOS holds filter state as individual fields rather than macOS's single
    /// `SearchParameters`, so `FacetNarrowing.apply(to:)` cannot be shared — the fields are
    /// this view model's own. What *is* shared is the destination: every case writes a field
    /// the filter sheet also owns, so a facet and the sheet can never disagree, which is the
    /// property the design asks for.
    func applyFacetNarrowing(_ narrowing: FacetNarrowing) {
        switch narrowing {
        case .year(let year):
            guard let start = Self.date(fromISO: "\(year)-01-01"),
                  let end = Self.date(fromISO: "\(year)-12-31") else { return }
            dateRangeEnabled = true
            dateRangeStart = start
            dateRangeEnd = end
        case .volume(let volumeId):
            // Replace rather than add: the facet's count is for that volume alone, so
            // unioning would return more documents than the row promised.
            selectedVolumeIds = [volumeId]
            selectedSubseriesIds = []
        case .person(let rollupId, let label):
            personRollupId = rollupId
            // #1092: carry the tapped bucket's display name, or the chip reads "person #N".
            personLabel = label
            // Drop any anchor from a previous person: it names someone else, and leaving it would
            // make the next rebind silently re-point this filter back at them.
            personAnchor = nil
            // A rollup and a typed ref are alternative spellings of one filter; leaving the
            // text set would AND them and silently undercount.
            personRefText = ""
        case .documentType(let filter):
            documentTypeFilter = filter
        case .subject(let bucket):
            // Replace rather than union, for the reason `.volume` gives: the row's count is for
            // that bucket alone.
            subjectBucket = bucket
            subjectBucketKey = DocumentSubjectStore.shared?.bucketVocabulary.key(at: bucket)
        }
        // No version bump: unlike macOS, this view model has no `parametersVersion` and iOS
        // re-runs the search explicitly. The caller owns that — see `SearchView`.
    }

    /// Applies a staged facet selection (#775), routed through the one shared applier.
    ///
    /// iOS holds its filters as individual fields rather than a `SearchParameters`, so this
    /// round-trips through a value: build the parameters, let `FacetSelectionApplier` write the
    /// change, read the result back. That is a little indirect and it is the point — the
    /// single-tap path has two appliers, one per platform, and they have already drifted.
    func applyFacetSelection(_ section: FacetSection, keys: [String]?) {
        var parameters = searchParameters
        FacetSelectionApplier.apply(section, keys: keys, to: &parameters)
        switch section {
        case .years:
            facetYearKeys = parameters.yearKeys
        case .volumes:
            // A subseries selection is a different way of naming volumes and would widen the gate
            // back out — the same reason the single-tap path clears it.
            selectedVolumeIds = parameters.volumeIds ?? []
            selectedSubseriesIds = []
        case .people, .documentType, .provenance, .subjects:
            break
        }
    }

    /// Captures or re-resolves the person filter's durable anchor against the live rollup (#747).
    ///
    /// Call after applying a person filter and again on every `AppState.personRollupGeneration`
    /// change: the rollup table is renumbered from 1 on every rebuild, so an id captured before a
    /// merge points at whoever now occupies that slot. Sets ``droppedPersonFilterNotice`` when the
    /// anchor no longer resolves, so the view can tell the user rather than quietly returning a
    /// wider result set.
    ///
    /// - Returns: `true` if the caller should re-run the search (the filter changed).
    @discardableResult
    func refreshPersonRollupBinding(using store: PersonMentionStore?) async -> Bool {
        let before = PersonFilterBinding(rollupId: personRollupId,
                                         label: personLabel,
                                         anchor: personAnchor)
        let (after, dropped) = await PersonRollupRefresh.rebind(before, using: store)
        guard after != before else { return false }
        personRollupId = after.rollupId
        personLabel = after.label
        personAnchor = after.anchor
        if dropped {
            droppedPersonFilterNotice = String(
                localized: "search.person.filterDropped",
                defaultValue: "The person filter was cleared — \(before.label ?? "that person") is no longer in the indexed corpus.")
        }
        // A pure anchor capture changes no filter, so it must not cost the user a re-run.
        return dropped || after.rollupId != before.rollupId
    }

    /// Parses a `yyyy-MM-dd` string into a `Date`, for the year-facet narrowing.
    private static func date(fromISO iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    /// The narrowings currently in force, as clearable summaries (R-1c).
    ///
    /// iOS has never had an active-filter row — only a filled filter glyph, which says
    /// *that* something is filtered but not what, and offers no way back. That gap is
    /// tolerable when every filter was set in a sheet the user just closed; it is not
    /// tolerable once a single tap in a facet list can narrow the result set, because then
    /// the narrowing is the interaction and it needs to be legible and reversible.
    ///
    /// Derived from the live fields rather than remembered from the tap, so it cannot drift
    /// from what is actually filtering, and so it also covers filters set in the sheet.
    var activeNarrowings: [ActiveNarrowing] {
        var out: [ActiveNarrowing] = []
        if dateRangeEnabled {
            out.append(ActiveNarrowing(
                id: "date",
                label: String(localized: "search.narrowing.date",
                              defaultValue: "\(Self.isoDate(dateRangeStart)) to \(Self.isoDate(dateRangeEnd))")))
        }
        if let years = facetYearKeys {
            out.append(ActiveNarrowing(
                id: "years",
                // Named, not counted, up to three: "1951, 1953" is the whole point of #775 and a
                // chip reading "2 years" would hide which two. Beyond three the list is longer
                // than the chip, so it degrades to a count.
                label: years.isEmpty
                    ? String(localized: "search.narrowing.years.none",
                             defaultValue: "No years")
                    : years.count <= 3
                    ? years.sorted().joined(separator: ", ")
                    : String(format: String(localized: "search.narrowing.years %lld",
                                            defaultValue: "%lld years"),
                             Int64(years.count))))
        }
        if !selectedVolumeIds.isEmpty {
            out.append(ActiveNarrowing(
                id: "volume",
                label: selectedVolumeIds.count == 1
                    ? selectedVolumeIds[0]
                    : String(localized: "search.narrowing.volumes",
                             defaultValue: "\(selectedVolumeIds.count) volumes")))
        }
        if !selectedSubseriesIds.isEmpty {
            out.append(ActiveNarrowing(
                id: "subseries",
                label: String(localized: "search.narrowing.subseries",
                              defaultValue: "\(selectedSubseriesIds.count) subseries")))
        }
        if let personRollupId {
            // #1092: prefer the stored display name — the slot number is meaningless to a
            // reader and is renumbered on every rollup rebuild (#747). The numeric fallback
            // survives only for a filter restored without its label.
            out.append(ActiveNarrowing(
                id: "person",
                label: personLabel
                    ?? String(localized: "search.narrowing.person",
                              defaultValue: "person #\(personRollupId)")))
        }
        if !selectedUserTagIds.isEmpty {
            // `Set<UUID>`, not an array — so no index subscript, and a stable label needs a
            // deterministic pick rather than whatever the set iterates first.
            let onlyName = selectedUserTagIds.count == 1
                ? selectedUserTagIds.first.flatMap { id in
                    availableUserTags.first { $0.id == id }?.name }
                : nil
            out.append(ActiveNarrowing(
                id: "tag",
                label: onlyName
                    ?? (selectedUserTagIds.count == 1
                        ? String(localized: "search.narrowing.tag.one", defaultValue: "1 tag")
                        : String(localized: "search.narrowing.tags",
                                 defaultValue: "\(selectedUserTagIds.count) tags"))))
        }
        if documentTypeFilter != .all {
            out.append(ActiveNarrowing(
                id: "type",
                label: documentTypeFilter == .editorialNotesOnly
                    ? String(localized: "search.narrowing.notes", defaultValue: "Editorial notes")
                    : String(localized: "search.narrowing.documents", defaultValue: "Documents")))
        }
        if let bucket = subjectBucketKey
            .flatMap({ DocumentSubjectStore.shared?.bucketVocabulary.id(forKey: $0) }) ?? subjectBucket {
            // Named from the vocabulary, not from the tap: this list is derived from live fields
            // precisely so it cannot describe a filter that is no longer the one applied. A bucket
            // the vocabulary cannot name still gets a chip — a filter with no way back is the one
            // failure this whole list exists to prevent.
            out.append(ActiveNarrowing(
                id: "subject",
                label: DocumentSubjectStore.shared?.bucketVocabulary.label(at: bucket)
                    ?? String(localized: "search.narrowing.subject.unknown",
                              defaultValue: "Subject filter")))
        }
        // The subject chip, separate from the bucket one above: they are different grains and a
        // reader can hold both at once (a bucket from the facet, a subject from the explorer).
        // Named from the STORED name rather than re-resolved, because after an upstream re-mint the
        // ref no longer resolves and a chip that vanished would be a filter with no way back — the
        // one failure this list exists to prevent.
        if subjectRef != nil {
            out.append(ActiveNarrowing(
                id: "subjectRef",
                label: subjectName ?? String(localized: "search.narrowing.subjectRef.unknown",
                                             defaultValue: "Topic filter")))
        }
        return out
    }

    /// Clears one active narrowing by its identifier.
    func clearNarrowing(_ id: String) {
        switch id {
        case "date": dateRangeEnabled = false
        case "years": facetYearKeys = nil
        case "volume": selectedVolumeIds = []
        case "subseries": selectedSubseriesIds = []
        case "person": personRollupId = nil; personRefText = ""; personAnchor = nil
        case "type": documentTypeFilter = .all
        case "tag": selectedUserTagIds = []
        case "subject": subjectBucket = nil; subjectBucketKey = nil
        case "subjectRef": subjectRef = nil; subjectName = nil
        default: return
        }
        // Caller re-runs the search, matching this view model's existing convention.
    }

    var hasActiveFilters: Bool {
        if documentTypeFilter != .all { return true }
        if personRollupId != nil { return true }
        if !personRefText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if dateRangeEnabled { return true }
        // `nil` is no filter; an EMPTY array is a real filter that matches nothing, so this tests
        // for presence rather than for non-emptiness.
        if facetYearKeys != nil { return true }
        // #308's facet-panel narrowing. Like `facetYearKeys` it is set by a tap rather than in the
        // sheet, which is precisely why it has to be reported: nothing else on screen would.
        if subjectBucket != nil { return true }
        if subjectRef != nil { return true }
        if !selectedVolumeIds.isEmpty { return true }
        if !selectedSubseriesIds.isEmpty { return true }
        if !selectedUserTagIds.isEmpty { return true }
        if !excludedTermsText.isEmpty { return true }
        if !phrase.isEmpty { return true }
        if !prefixWildcard.isEmpty { return true }
        if !includeDocumentText || !includeSummaries || !includeNotes { return true }
        if !includeFrontMatter { return true }
        if projectScope != .off { return true }
        // An applied working corpus gates every row, so the filter glyph must say so. It was
        // missing here because a corpus is applied through its own field rather than through the
        // volume-checkbox field a custom volume scope writes — so it inherited none of the filter
        // vocabulary that field carries for free.
        if appliedWorkingCorpusKeys != nil { return true }
        switch booleanMode {
        case .or: return true
        case .and: return false
        }
    }

    func makeEntry(from result: SearchResult) -> DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        )
    }

    // MARK: - Parameter Application (used by pendingSearch)

    /// Applies a `SearchParameters` snapshot to all filter fields.
    /// Called by `SearchView` when presented with pre-filled parameters via
    /// `AppState.pendingSearch`.
    func applyParameters(_ params: SearchParameters) {
        keywords          = params.keywords ?? ""
        phrase            = params.phrase ?? ""
        prefixWildcard    = params.prefixWildcard ?? ""
        booleanMode       = params.booleanMode
        excludedTermsText = params.excludedTerms.joined(separator: ", ")
        personRefText     = params.personRef ?? ""
        personRollupId    = params.personRollupId
        personLabel       = params.personLabel
        personAnchor      = params.personAnchor
        // #775: restore the year set. `nil` is a real value here (no year filter), so this
        // assigns unconditionally rather than guarding on non-nil — a guard would leave a
        // previous search's years in force under a restored search that has none.
        facetYearKeys = params.yearKeys
        if let range = params.dateRange {
            dateRangeEnabled = true
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            if let earliest = range.earliest { dateRangeStart = fmt.date(from: earliest) ?? dateRangeStart }
            if let latest   = range.latest   { dateRangeEnd   = fmt.date(from: latest)   ?? dateRangeEnd }
        } else {
            dateRangeEnabled = false
        }
        // params.subjectTagIds is intentionally dropped (inert since Session 09) —
        // restoring it would fake an "active filter" for a constraint that does nothing.
        selectedUserTagIds    = Set(params.userTagIds.compactMap { UUID(uuidString: $0) })
        let scope = Self.reconstructScope(from: params.volumeIds ?? [], available: availableVolumes)
        selectedSubseriesIds  = scope.subseries
        selectedVolumeIds     = scope.volumes
        includeDocumentText   = params.includeDocumentText
        includeSummaries      = params.includeSummaries
        includeNotes          = params.includeNotes
        includeFrontMatter    = params.includeFrontMatter
        documentTypeFilter    = params.documentTypeFilter
        // ASSIGNED UNCONDITIONALLY, never `if let`. A recalled search that omits it must CLEAR any
        // bucket the previous search left in force — this view model's fields outlive one search,
        // so a conditional assignment would leak a stale subject filter into every hand-off.
        subjectBucket         = params.subjectBucket
        subjectBucketKey      = params.subjectBucketKey
        // Unconditional for the same reason, and this pair is why a hand-off used to die on iOS
        // and live on macOS: `MacSearchViewModel.applyParameters` assigns the whole
        // `SearchParameters`, while this one copies named fields — so a field added there and not
        // here is dropped between `consumePendingSearch` and `search()`, which re-derives from
        // these very fields. The reader got "Enter a keyword, phrase, or prefix to search" from a
        // door that had just handed over a perfectly good subject (#1023).
        subjectRef            = params.subjectRef
        subjectName           = params.subjectName
        // Project History scope is a live, manual choice — never inherited from a restored
        // snapshot or a pending-search hand-off (Analytics drill-in, "Find all mentions",
        // indexing banners). Without this reset a History scope selected earlier in the
        // session would silently keep gating unrelated hand-off searches (#377 Phase 2a).
        // `params.documentIds` is deliberately dropped: `searchParameters` re-derives
        // `documentIds` from `projectScope`, so clearing the scope fully clears the gate.
        projectScope          = .off
        projectOnlyNew        = false
    }

    // MARK: - Scope Reconstruction

    /// Splits a flat `volumeIds` scope back into a subseries selection plus a set of
    /// individually-selected volumes, so a scope round-tripped through
    /// `SearchParameters` (the analytics drill-in, a `SavedSearch`, or a pending
    /// handoff) repopulates the two pickers faithfully.
    ///
    /// A subseries is treated as "selected as a whole" only when *every* one of its
    /// indexed volumes appears in `volumeIds`; those volumes are then removed from the
    /// individual set. Volumes belonging to a partially-covered subseries remain
    /// individual selections. When `available` is empty (manifest not yet loaded) every
    /// id is returned as an individual selection — the effective scope is identical,
    /// only the picker labelling differs.
    ///
    /// Shared by `applyParameters(_:)` here and `MacSearchViewModel.syncToFilterVM`.
    static func reconstructScope(
        from volumeIds: [String],
        available: [VolumeManifestEntry]
    ) -> (subseries: Set<String>, volumes: [String]) {
        guard !volumeIds.isEmpty, !available.isEmpty else { return ([], volumeIds) }
        let idSet = Set(volumeIds)
        let bySubseries = Dictionary(grouping: available, by: { $0.subseries })
        var subseries: Set<String> = []
        var consumed: Set<String> = []
        for (sub, entries) in bySubseries {
            let subVolumeIds = Set(entries.map(\.volumeId))
            if !subVolumeIds.isEmpty, subVolumeIds.isSubset(of: idSet) {
                subseries.insert(sub)
                consumed.formUnion(subVolumeIds)
            }
        }
        let individual = volumeIds.filter { !consumed.contains($0) }
        return (subseries, individual)
    }

    // MARK: - Private Helpers

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
