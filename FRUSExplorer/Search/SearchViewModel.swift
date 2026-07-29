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

    /// Display name for the active `personRollupId`/`personRef` filter, shown in the filter chip.
    var personLabel: String?

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
        parts.append(personRefText)
        parts.append(personRollupId.map(String.init) ?? "")
        parts.append(personLabel ?? "")
        parts.append(String(describing: documentTypeFilter))
        parts.append(includeDocumentText ? "1" : "0")
        parts.append(includeSummaries ? "1" : "0")
        parts.append(includeNotes ? "1" : "0")
        parts.append(selectedSubseriesIds.sorted().joined(separator: ","))
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

    /// Maximum results fetched by `search()`.
    ///
    /// iOS pages through results (`pageSize` per page) rather than rendering them in one
    /// continuous list, so the full set is materialised in memory but only a single page
    /// of rows is ever rendered. Raised from 500 → 1 000 once pagination bounded the
    /// render cost. The macOS search window uses a separate hard limit of 7 500.
    static let searchHardLimit: Int = 1_000

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
        // A person filter is a valid standalone constraint — `SearchService`
        // applies it SQL-side, so "Find all mentions" handoffs (which carry only
        // a `personRef`) can run without a keyword. Before Session 162 this guard
        // rejected them, so the person handoff surfaced an error instead of results.
        let hasPositiveTerm = params.keywords != nil
            || params.phrase != nil
            || params.prefixWildcard != nil
            || params.personRef != nil
            || params.personRollupId != nil
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
        // Bumped once per executed search so views that must react to a *completed*
        // search — the Query Inspector's zero-result decomposition — have a `.task(id:)`
        // key. `keywords` alone is the live field and changes while typing; `hasSearched`
        // latches true and never changes again.
        executedSearchVersion &+= 1
        isSearching = true
        searchError = nil
        hasSearched = true
        do {
            results = try await searchService.search(parameters: params,
                                                     limit: Self.searchHardLimit)
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

    /// The most recently recorded search-history query text.
    ///
    /// Several of `SearchView`'s entry points re-run `search()` for the **same** query with a
    /// changed filter — clearing the volume scope, tapping a tag chip on a result row — and
    /// those must not each mint a "search executed" row. Tracking the last recorded query
    /// yields one entry per distinct submitted query rather than one per execution. Exactly
    /// `MacSearchViewModel.lastRecordedHistoryQuery`, whose re-runs come from
    /// `parametersVersion` instead.
    private var lastRecordedHistoryQuery: String?

    /// Inserts a `SearchHistoryEntry` into the SwiftData context for the most recently
    /// executed search — the iOS half of the trail's search producer.
    ///
    /// Call once after `search()` completes; `SearchView.runSearch()` is the single site that
    /// does so, which is why every search entry point in that view routes through it. No-ops
    /// when the query is empty (a person-only "find all mentions" hand-off, say), the search
    /// errored, or the query text matches the last recorded entry (see
    /// `lastRecordedHistoryQuery`).
    ///
    /// **Honours the research-logging preference**, and did so from its first commit — Wave R-1
    /// closed the gate before this writer existed precisely so that adding it could not start
    /// collecting search text on a platform that was not collecting it. As on macOS the gate is
    /// checked **before** `lastRecordedHistoryQuery` is updated, so switching logging back on
    /// mid-session does not silently swallow the query that was suppressed.
    ///
    /// ## One difference from the macOS writer
    /// `resultCount` is `results.count`, the fetched count — capped at `searchHardLimit`
    /// (1,000). `MacSearchViewModel` records `totalMatchCount`, the true uncapped total, because
    /// its `performSearch` already runs `SearchService.searchCount` in parallel for its
    /// truncation banner. This view model runs no such count, and adding one would put a second
    /// FTS5 `COUNT(*)` on every iPhone search to improve a number nothing yet displays. A query
    /// matching more than 1,000 documents is therefore recorded as 1,000 on iOS.
    ///
    /// - Parameters:
    ///   - projectId: The active project, stamped onto the entry; `nil` when none is active.
    ///   - context: The context the entry is inserted into.
    ///   - defaults: The store the research-logging gate is read from. Defaults to
    ///     `.standard`; overridden only by tests.
    func recordSearchHistory(projectId: UUID?,
                             in context: ModelContext,
                             defaults: UserDefaults = .standard) {
        guard AppState.isResearchLoggingEnabled(in: defaults) else {
            #if DEBUG
            print("[SearchViewModel] SearchHistoryEntry suppressed (research logging off)")
            #endif
            return
        }
        let query = submittedQuery
        guard !query.isEmpty, searchError == nil, query != lastRecordedHistoryQuery else { return }
        lastRecordedHistoryQuery = query

        let record = SearchHistoryEntry(
            queryText: query,
            resultCount: results.count,
            projectId: projectId
        )
        context.insert(record)
        #if DEBUG
        print("[SearchViewModel] SearchHistoryEntry recorded: \"\(query)\" results=\(results.count)")
        #endif
    }

    func clearFilters() {
        phrase = ""
        prefixWildcard = ""
        booleanMode = .and
        excludedTermsText = ""
        dateRangeEnabled = false
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
        // Reset the project scope selection + Focus "only new" toggle (keep the loaded
        // engaged-key/focus-volume sets — they are context, not user filters, and
        // re-populate only when the project changes).
        projectScope = .off
        projectOnlyNew = false
    }

    func clearAll() {
        keywords = ""
        clearFilters()
        results = []
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
            subjectTagIds: [],
            userTagIds: selectedUserTagIds.map(\.uuidString),
            volumeIds: scoped.volumeIds,
            documentIds: scoped.documentIds,
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
            includeFrontMatter: includeFrontMatter
        )
    }

    /// The number of results currently shown to the user — the checklist-filtered count, so the
    /// results-count header matches the visible rows.
    var resultCount: Int { displayedResults.count }

    /// `true` when the result set hit `searchHardLimit`, indicating the query matches
    /// more documents than are shown. Users should narrow their search terms. Keyed on the raw
    /// fetch count (not the checklist-filtered view), since the cap is about the FTS5 fetch.
    var isResultsCapped: Bool { results.count == Self.searchHardLimit }

    // Note: this still checks the legacy `phrase`/`prefixWildcard`/`excludedTermsText`/
    // `booleanMode` fields even though `SearchFilterView` no longer exposes controls for
    // them — a restored `SavedSearch`/`pendingSearch` snapshot can still populate them via
    // `applyParameters(_:)`, and when it does, that state genuinely affects the query, so
    // the "Clear Filters" affordance must remain available to reset it.
    var hasActiveFilters: Bool {
        if documentTypeFilter != .all { return true }
        if personRollupId != nil { return true }
        if !personRefText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if dateRangeEnabled { return true }
        if !selectedVolumeIds.isEmpty { return true }
        if !selectedSubseriesIds.isEmpty { return true }
        if !selectedUserTagIds.isEmpty { return true }
        if !excludedTermsText.isEmpty { return true }
        if !phrase.isEmpty { return true }
        if !prefixWildcard.isEmpty { return true }
        if !includeDocumentText || !includeSummaries || !includeNotes { return true }
        if !includeFrontMatter { return true }
        if projectScope != .off { return true }
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
