// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import Foundation
import Observation
import SwiftData

// `SearchSortOrder` now lives in SearchModels.swift (shared with the iOS SearchView, #305).

// MARK: - MacSearchViewModel

/// Owns all state for the macOS Search sheet.
///
/// ## Submit-Only Search
/// `queryText` is the live text-field buffer and never triggers a search on its own.
/// A search fires only when the user presses Return, which calls `submitSearch()` and
/// sets `submittedQuery = queryText`. `searchTrigger` derives from `submittedQuery` and
/// `parametersVersion`; a `.task(id: searchTrigger)` in `SearchSheet` calls
/// `performSearch` whenever the trigger changes.
///
/// Filter changes (scope toggles, advanced filter sheet apply) bump `parametersVersion`,
/// which changes `searchTrigger` and re-runs `performSearch` against the **already-
/// submitted** query. If no query has been submitted yet (`submittedQuery` is empty),
/// `performSearch` short-circuits harmlessly.
///
/// ## Filter State
/// Two-tier filter model:
/// - Basic scope toggles (`scopeDocuments`, `scopeNotes`, `scopeSummaries`) project
///   directly into `parameters`.
/// - Advanced filter state lives in `filterVM` (`SearchViewModel`), which is presented
///   via `SearchFilterView` in a live popover (UI audit C4). The presenter calls
///   `applyAdvancedFilters()` on each `filterVM.advancedFilterSignature` change to copy
///   `filterVM` values into `parameters` and trigger re-search immediately.
///
/// ## Sorting and Pagination
/// Sorting is applied client-side on all results. `pagedResults` slices `allSortedResults`
/// by `pageSize`/`currentPage`. `performSearch` fetches up to 7,500 results so that all
/// pages are available without a server round-trip. `totalMatchCount` is fetched in
/// parallel via `SearchService.searchCount` and represents the true uncapped match count
/// — when it exceeds `results.count`, the UI surfaces an over-cap advisory.
///
/// ## Search-in Scope Toggles
/// `scopeDocuments`, `scopeNotes`, and `scopeSummaries` mirror
/// `SearchParameters.includeDocumentText`/`includeSummaries`/`includeNotes`. Toggling a
/// scope chip is equivalent to toggling the corresponding scope checkbox in the advanced
/// filter sheet. If all three scopes are disabled `performSearch` short-circuits with a
/// friendly error rather than asking the FTS5 layer to throw `emptyQuery`.
///
/// ## Naming
/// Named `MacSearchViewModel` to distinguish from the existing iOS `SearchViewModel`
/// in `Search/SearchViewModel.swift`. The iOS revamp will reconcile these.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; iOS revamp will unify)
///   1.1 — Add pagination, parametersVersion, filterVM bridge, advanced filter sync
///   1.2 — Session 120: raise cap from 500 → 7,500; add `totalMatchCount`; wire
///          `scopeDocuments` to `includeDocumentText`; clamp `currentPage` when results
///          shrink; gate empty-scope searches with a friendly error
///   1.3 — Session 121: add `submitSearch()` so `.onSubmit` bypasses debounce instead of
///          spawning a parallel Task; fix `performSearch` catch to skip result-clearing on
///          `CancellationError` (prevents flash of empty results when task is superseded)
///   1.4 — Session 129: remove 300 ms auto-debounce from `queryText.didSet`; rename
///          `debouncedQuery` → `submittedQuery`; `performSearch` reads `submittedQuery`
///          so queries never fire before the user presses Return; filter/scope changes
///          re-run the previously submitted query (not the live text-field buffer)
///   1.5 — Session 163: `syncToFilterVM` now loads the volume/subseries picker options
///          and reconstructs the picker selection from `parameters.volumeIds`;
///          `applyAdvancedFilters` writes `filterVM.effectiveVolumeIds` back into
///          `parameters.volumeIds` so the new advanced-filter volume pickers apply.
///   1.6 — Session 2026-07-04 (macOS UI audit C4): `applyAdvancedFilters` is now
///          called live per filter edit (signature observation in the popover host)
///          instead of once in the removed sheet's `onDismiss` batch.
@Observable
@MainActor
final class MacSearchViewModel {

    // MARK: - Input State

    /// Live text-field buffer. Does **not** trigger a search on its own.
    /// Call `submitSearch()` (bound to `.onSubmit`) to commit this value to
    /// `submittedQuery` and fire a search.
    var queryText: String = ""

    /// The last query string committed by `submitSearch()` or `applyParameters(_:)`.
    /// `searchTrigger` derives from this value, so only committed queries drive searches.
    var submittedQuery: String = ""

    // MARK: - Scope toggles

    /// Whether full document text (header, dateline, source note, body) is searched.
    /// Mirrors `parameters.includeDocumentText`. Toggling this off is equivalent to
    /// unchecking "Document text" in the advanced filter sheet.
    var scopeDocuments: Bool = true {
        didSet {
            parameters.includeDocumentText = scopeDocuments
            filterVM?.includeDocumentText = scopeDocuments
            parametersVersion += 1
        }
    }

    var scopeNotes: Bool = true {
        didSet {
            parameters.includeNotes = scopeNotes
            filterVM?.includeNotes = scopeNotes
            parametersVersion += 1
        }
    }

    var scopeSummaries: Bool = true {
        didSet {
            parameters.includeSummaries = scopeSummaries
            filterVM?.includeSummaries = scopeSummaries
            parametersVersion += 1
        }
    }

    // `scopeCollections` was removed with its chip (UI review M-10). It was a stored property
    // nothing ever read: no `didSet`, no projection into `parameters`, no reader but the chip's
    // own binding. Re-adding it means adding `includeCollections` to `SearchParameters` and a
    // `didSet` matching the three above — in that order, so the control cannot ship ahead of the
    // behaviour a second time.

    // MARK: - Initialisation

    /// Applies the user-configured search defaults (`SearchDefaults`, set in
    /// Settings → Search) to the scope toggles, the type filter, and the
    /// underlying `parameters`. Property observers do not fire during
    /// initialisation, so `parameters` is updated explicitly.
    init() {
        let documents = SearchDefaults.scopeDocuments
        let notes     = SearchDefaults.scopeNotes
        let summaries = SearchDefaults.scopeSummaries
        let typeFilter = SearchDefaults.documentTypeFilter
        scopeDocuments = documents
        scopeNotes     = notes
        scopeSummaries = summaries
        parameters.includeDocumentText = documents
        parameters.includeNotes        = notes
        parameters.includeSummaries    = summaries
        parameters.documentTypeFilter  = typeFilter
    }

    // MARK: - Filter Parameters

    var parameters: SearchParameters = SearchParameters()

    /// Triggers a re-search whenever any filter changes. Observed via `searchTrigger`.
    var parametersVersion: Int = 0

    /// Combined token for `.task(id:)` — changes when the submitted query or any
    /// filter changes. Does **not** change when the user is merely typing in the
    /// text field; only `submitSearch()` (Return key) updates `submittedQuery`.
    var searchTrigger: String { "\(submittedQuery)|\(parametersVersion)" }

    /// The parameters a search would run with *right now*, from the live text field.
    ///
    /// Distinct from what `performSearch` uses, which reads `submittedQuery`. The Query
    /// Inspector wants the live text so the expression updates as the researcher types —
    /// that is how someone learns `NEAR` from watching it — while the search itself stays
    /// on Return, as it must at this corpus size.
    var liveSearchParameters: SearchParameters {
        var params = parameters
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    /// The parameters of the search that actually ran — for the zero-result decomposition,
    /// which must decompose the executed query rather than whatever is in the field now.
    var submittedSearchParameters: SearchParameters {
        var params = parameters
        let trimmed = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        params.keywords = trimmed.isEmpty ? nil : trimmed
        return params
    }

    // MARK: - Advanced Filter ViewModel

    /// Backing view model for `SearchFilterView` presented as a sheet.
    /// Created lazily on the first call to `syncToFilterVM(searchService:)`.
    /// Nil until then (and nil if `searchService` is not yet available).
    var filterVM: SearchViewModel? = nil

    // MARK: - Sort

    var sortOrder: SearchSortOrder = .relevance {
        didSet { currentPage = 0 }
    }

    // MARK: - Pagination

    static let pageSizeOptions: [Int] = [10, 20, 50, 100]

    var pageSize: Int = 20 {
        didSet { currentPage = 0 }
    }

    var currentPage: Int = 0

    /// Bumped once per COMPLETED search, so a view can key work on "the results were replaced".
    ///
    /// The macOS twin of `SearchViewModel.executedSearchVersion`, added for the concordance (R-3b).
    /// Keying on `results.count` instead — which is what I reached for first — would miss a new
    /// search returning the same number of rows, leaving a concordance built from the previous
    /// query on screen. That is the worst kind of stale for a view whose output gets quoted.
    private(set) var executedSearchVersion: Int = 0

    var totalPages: Int {
        max(1, Int(ceil(Double(displayedResults.count) / Double(pageSize))))
    }

    // MARK: - Results

    var results: [SearchResult] = []
    var isSearching: Bool = false
    var searchError: Error? = nil

    /// True total number of matches for the current query, independent of
    /// `searchHardLimit` — or `nil` when the count could not be obtained.
    ///
    /// ## Why this is optional
    /// It used to fall back to `results.count` when the concurrent `COUNT(*)` threw. That
    /// silently made the total equal the fetch cap **and switched off both truncation
    /// signals**, because `isResultSetTruncated` compares the two: a truncated set rendered
    /// as "7,500 loaded · 7,500 total" with the orange triangle and the over-cap advisory
    /// both gone, and that number was what `recordSearchHistory` wrote to the research
    /// trail. Not a wrong number in a corner — a wrong number that erased its own warning.
    ///
    /// `nil` now means "unknown", the surfaces say so, and the truncation warning is driven
    /// by whether the fetch actually hit its cap rather than by a comparison against a
    /// number that may not exist.
    var totalMatchCount: Int?

    /// The FTS5 expression the last completed search executed. Mirrors the iOS field; see
    /// `SearchViewModel.lastRenderedExpression` for why it is captured at execution rather than
    /// re-derived by the recorder.
    var lastRenderedExpression: String?

    /// Whether the displayed `results` are a truncated subset of the real match set.
    ///
    /// Keyed on the fetch hitting its own cap, which is knowable without the count. When
    /// the count *is* available and exceeds the fetch, that also counts — a filter applied
    /// after the limit could otherwise hide the truncation.
    var isResultSetTruncated: Bool {
        if results.count >= Self.searchHardLimit { return true }
        if let totalMatchCount { return totalMatchCount > results.count }
        return false
    }

    /// The count to display, and whether it is the real total.
    ///
    /// Callers must not print `resultCountForDisplay` without consulting
    /// ``isTotalCountAvailable`` — that pairing is the whole point of the type change.
    var resultCountForDisplay: Int { totalMatchCount ?? results.count }

    /// Whether the displayed count is the true total rather than just what was fetched.
    var isTotalCountAvailable: Bool { totalMatchCount != nil }

    /// Hard upper bound on the number of results materialised by `performSearch`.
    /// Raised from 500 → 7,500 in Session 120 (PR #45). At ~5 KB body-text average
    /// the working set stays well under 50 MB on macOS; the count badge displays the
    /// true uncapped total via `totalMatchCount`.
    static let searchHardLimit: Int = 7_500

    /// Returns `results` ordered according to `sortOrder`.
    ///
    /// Date sorting uses the structured `dateISO` value (`yyyy-MM-dd`, from
    /// `document_dates.date_iso`) — NOT the raw `dateline` string, which begins
    /// with a place name and a textual month and therefore cannot be sorted
    /// chronologically. Documents without a stored date are pushed to the **end**
    /// of the list in both ascending and descending order so the dated stream
    /// remains contiguous (mirrors history.state.gov's `empty greatest`/`empty
    /// least` XQuery behaviour).
    ///
    /// Ties on the ISO date are broken by BM25 score (more relevant first) so
    /// the order within a single day is stable and meaningful.
    var allSortedResults: [SearchResult] {
        switch sortOrder {
        case .relevance:
            return results
        case .dateAscending:
            return results.sorted { Self.dateOrder($0, $1, ascending: true) }
        case .dateDescending:
            return results.sorted { Self.dateOrder($0, $1, ascending: false) }
        }
    }

    /// Tuple comparator for date-asc / date-desc. Undated rows always go last;
    /// ties are broken by BM25 score (lower is better, so ascending bm25 = more
    /// relevant first).
    private static func dateOrder(
        _ lhs: SearchResult,
        _ rhs: SearchResult,
        ascending: Bool
    ) -> Bool {
        switch (lhs.dateISO, rhs.dateISO) {
        case let (a?, b?):
            if a == b { return lhs.bm25Score < rhs.bm25Score }
            return ascending ? a < b : a > b
        case (.some, .none):
            return true                      // lhs dated → comes before undated rhs
        case (.none, .some):
            return false                     // lhs undated → goes after dated rhs
        case (.none, .none):
            return lhs.bm25Score < rhs.bm25Score
        }
    }

    var pagedResults: [SearchResult] {
        let all = displayedResults
        // Clamp the page index at read time (side-effect-free) so a reviewed-set change that
        // shrinks the list can never leave `pagedResults` returning a blank page for a
        // now-out-of-range `currentPage` (mirrors `SearchViewModel.pagedResults`).
        let page = min(max(0, currentPage), totalPages - 1)
        let start = page * pageSize
        guard start < all.count else { return [] }
        return Array(all[start..<min(start + pageSize, all.count)])
    }

    // MARK: - Checklist Mode (#189-D)

    /// True when checklist review mode is active. Session-scoped; not persisted (resets on
    /// relaunch). While on, results the user has reviewed this session are hidden from the list,
    /// the timeline, and the page math. Mirrors `SearchViewModel`'s iOS implementation so the
    /// macOS Search window behaves identically.
    var checklistMode: Bool = false {
        didSet { clampCurrentPage() }
    }

    /// The instant checklist mode was last enabled (or a new search re-anchored it). Documents
    /// opened at or after this instant (per `ReadingHistoryEntry.accessedAt`) are hidden. `nil`
    /// while mode is off.
    var checklistEnabledAt: Date?

    /// `(volumeId|documentId)` keys opened since `checklistEnabledAt`, fed by a live
    /// `ReadingHistoryEntry` `@Query` in `MacSearchWindowView` (mirrors `readSinceEnabledKeys`
    /// on iOS).
    var readSinceEnabledKeys: Set<String> = [] {
        didSet { clampCurrentPage() }
    }

    /// `(volumeId|documentId)` keys the user marked reviewed this session via the row context
    /// menu — an in-memory set, never a fabricated `ReadingHistoryEntry`.
    var markedReviewedKeys: Set<String> = [] {
        didSet { clampCurrentPage() }
    }

    /// The trimmed submitted query the checklist is currently anchored to. `performSearch` re-runs
    /// on every filter/scope change (not only on a new query, unlike iOS's `search()`), so the
    /// re-anchor is gated on this changing — otherwise a filter edit mid-session would wipe the
    /// user's reviewed marks. Mirrors ``SearchHistoryWriter/Anchor``'s "one row per distinct query"
    /// pattern.
    private var lastChecklistAnchorQuery: String?

    /// A stable reviewed-set key for a `(volume, document)` pair.
    nonisolated static func reviewedKey(volumeId: String, documentId: String) -> String {
        "\(volumeId)|\(documentId)"
    }

    /// The reviewed set while checklist mode is on: docs opened since enable ∪ docs marked.
    var hiddenReviewedKeys: Set<String> {
        checklistMode ? readSinceEnabledKeys.union(markedReviewedKeys) : []
    }

    /// `allSortedResults` minus reviewed docs when checklist mode is on. All display-time page
    /// math (`totalPages`, `pagedResults`) and the timeline page over this, so the slice, count,
    /// and page index stay in sync.
    var displayedResults: [SearchResult] {
        let hidden = hiddenReviewedKeys
        guard !hidden.isEmpty else { return allSortedResults }
        return allSortedResults.filter {
            !hidden.contains(Self.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId))
        }
    }

    /// Enables/disables checklist mode. Enabling stamps the anchor and clears prior marks;
    /// disabling clears all reviewed state so the full list returns.
    func setChecklistMode(_ on: Bool) {
        checklistMode = on
        if on {
            checklistEnabledAt = .now
            lastChecklistAnchorQuery = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            markedReviewedKeys.removeAll()
        } else {
            checklistEnabledAt = nil
            lastChecklistAnchorQuery = nil
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

    // MARK: - UI State

    var showTips: Bool = false

    // MARK: - Computed Labels

    var dateRangeLabel: String? {
        guard let range = parameters.dateRange else { return nil }
        return [range.earliest, range.latest].compactMap { $0 }.joined(separator: " – ")
    }

    var volumeFilterLabel: String? {
        guard let ids = parameters.volumeIds, !ids.isEmpty else { return nil }
        return ids.count == 1 ? ids[0] : "\(ids.count) volumes"
    }

    var tagFilterLabel: String? {
        guard !parameters.userTagIds.isEmpty else { return nil }
        guard parameters.userTagIds.count == 1 else {
            return String(localized: "search.filter.tags.count",
                          defaultValue: "\(parameters.userTagIds.count) tags")
        }
        // Resolve to the tag's name. This used to return the raw id, so the chip read
        // "Tagged 37A4D180-4990-4C2A-A0F9-BB41B4116EC2" — already the case for the shipped
        // result-row chip tap, before any facet existed.
        let id = parameters.userTagIds[0]
        if let name = filterVM?.availableUserTags.first(where: { $0.id.uuidString == id })?.name {
            return name
        }
        // No tag list yet (the Advanced panel has never been opened) or the id no longer
        // resolves. A truncated id beats a full one, and beats claiming a name we do not have.
        return String(localized: "search.filter.tags.unresolved", defaultValue: "1 tag")
    }

    var activeFilterSummary: String? {
        var parts: [String] = []
        if parameters.dateRange != nil           { parts.append("date") }
        if parameters.yearKeys != nil            { parts.append("years") }
        if parameters.volumeIds != nil           { parts.append("volume") }
        // `documentIds` has TWO producers — an applied working corpus and a project History
        // gate — and `DocumentScopeGate.combine` intersects them, so it can carry either or both.
        // Labelling it unconditionally "project" named the wrong scope whenever a corpus was the
        // source, which is the common case: the corpus is applied from the filter sheet two
        // controls away, while a History gate needs an active project in History mode.
        if parameters.documentIds != nil {
            let corpus = filterVM?.appliedWorkingCorpusKeys != nil
            let project = filterVM?.projectScope != .off
            switch (corpus, project) {
            case (true, true):  parts.append("corpus + project")
            case (true, false): parts.append("corpus")
            default:            parts.append("project")
            }
        }
        if !parameters.userTagIds.isEmpty        { parts.append("tags") }
        if parameters.phrase != nil              { parts.append("phrase") }
        if parameters.personRef != nil || parameters.personRollupId != nil { parts.append("person") }
        if !parameters.excludedTerms.isEmpty     { parts.append("excluded") }
        if parameters.prefixWildcard != nil      { parts.append("prefix") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Filter Mutations (each bumps parametersVersion to trigger re-search)

    func setDocumentTypeFilter(_ filter: DocumentTypeFilter) {
        parameters.documentTypeFilter = filter
        filterVM?.documentTypeFilter = filter
        parametersVersion += 1
    }

    /// Includes or excludes front matter in the executed query (M-4).
    ///
    /// ## This field was reachable and inert on macOS before this existed
    /// `SearchFilterView`'s "Include front matter" toggle binds `filterVM.includeFrontMatter`, and
    /// #916 put that property into `advancedFilterSignature` so the popover re-applies when it
    /// changes. But ``applyAdvancedFilters()`` copied its three siblings — `includeDocumentText`,
    /// `includeSummaries`, `includeNotes` — and **not this one**, and ``syncToFilterVM(…)`` never
    /// seeded it either. So on macOS the toggle moved, the search re-ran, and the results were
    /// identical: the third instance of this review's no-silent-no-ops defect, and the second for
    /// this very field. Both halves are fixed alongside this setter, because a token that writes
    /// `parameters` while the popover writes `filterVM` would otherwise let each silently undo the
    /// other.
    ///
    /// Writing **both** stores is the same shape ``setDocumentTypeFilter(_:)`` uses, and it is what
    /// keeps a subsequent `applyAdvancedFilters()` from reverting a token's edit.
    ///
    /// - Parameter include: `true` to search front matter (the default), `false` to exclude it.
    func setIncludeFrontMatter(_ include: Bool) {
        guard parameters.includeFrontMatter != include else { return }
        parameters.includeFrontMatter = include
        filterVM?.includeFrontMatter = include
        parametersVersion += 1
    }

    /// A short label for the active person filter, or `nil` when there is none.
    ///
    /// Exists so a People facet click reads back in the filter row the way a Volume or Date
    /// click already does — the design's requirement that facets and the filter sheet cannot
    /// disagree only holds if every narrowable dimension is visible in one place.
    var personFilterLabel: String? {
        if let rollupId = parameters.personRollupId {
            // Prefer the stored name. `rollup_id` is a slot number that is renumbered on every
            // rollup rebuild (#747), so "person #12" both means nothing to the reader and stops
            // being the same person between one correction and the next.
            if let label = parameters.personLabel, !label.isEmpty { return label }
            return String(localized: "search.filter.person.rollup",
                          defaultValue: "person #\(rollupId)")
        }
        if let ref = parameters.personRef {
            return ref.hasPrefix("#") ? String(ref.dropFirst()) : ref
        }
        return nil
    }

    /// Clears the person filter in both of its forms.
    func clearPersonFilter() {
        guard parameters.personRef != nil || parameters.personRollupId != nil else { return }
        parameters.personRef = nil
        parameters.personRollupId = nil
        parameters.personAnchor = nil
        filterVM?.personRollupId = nil
        filterVM?.personAnchor = nil
        // **Both halves of the mirror, or the clear undoes itself.** `applyAdvancedFilters` rebuilds
        // `personRef` from `filterVM.personRefText` (:712) and `personLabel` from `filterVM`
        // (:714). Clearing only the rollup fields left the typed ref alive in the filter VM, so the
        // person filter came back the next time anything in the Advanced popover changed — a ×
        // that held until the reader touched an unrelated control. Found while wiring M-4's token
        // row, which routes its remove button here.
        filterVM?.personRefText = ""
        filterVM?.personLabel = nil
        parametersVersion += 1
    }

    /// Captures or re-resolves the person filter's durable anchor against the live rollup (#747).
    ///
    /// The macOS twin of `SearchViewModel.refreshPersonRollupBinding(using:)`. Both exist because
    /// the two search surfaces keep separate state (`project_macos_search_separate`); fixing only
    /// one would leave the Mac search window filtering by a stale slot number after every merge.
    ///
    /// - Returns: `true` if the caller should re-run the search.
    @discardableResult
    func refreshPersonRollupBinding(using store: PersonMentionStore?) async -> Bool {
        let before = PersonFilterBinding(rollupId: parameters.personRollupId,
                                         label: parameters.personLabel,
                                         anchor: parameters.personAnchor)
        let (after, dropped) = await PersonRollupRefresh.rebind(before, using: store)
        guard after != before else { return false }
        parameters.personRollupId = after.rollupId
        parameters.personLabel = after.label
        parameters.personAnchor = after.anchor
        filterVM?.personRollupId = after.rollupId
        filterVM?.personLabel = after.label
        filterVM?.personAnchor = after.anchor
        if dropped {
            droppedPersonFilterNotice = String(
                localized: "search.person.filterDropped",
                defaultValue: "The person filter was cleared — \(before.label ?? "that person") is no longer in the indexed corpus.")
        }
        // Only an id change (or a drop) alters the result set; a first-time anchor capture does not.
        let changed = dropped || after.rollupId != before.rollupId
        if changed { parametersVersion += 1 }
        return changed
    }

    /// Set when the last rebind dropped the person filter because its anchor no longer resolves.
    var droppedPersonFilterNotice: String?

    func clearDateFilter() {
        parameters.dateRange = nil
        filterVM?.dateRangeEnabled = false
        parametersVersion += 1
    }

    /// The Years-facet chip's label, or `nil` when no year set is in force (#775).
    ///
    /// Names the years up to three, then counts. Which years were kept is the finding a reader
    /// needs; beyond three the list outgrows the chip.
    var yearFilterLabel: String? {
        guard let years = parameters.yearKeys else { return nil }
        if years.isEmpty {
            return String(localized: "search.filter.years.none", defaultValue: "none")
        }
        if years.count <= 3 { return years.sorted().joined(separator: ", ") }
        return String(format: String(localized: "search.filter.years.count %lld",
                                     defaultValue: "%lld years"), Int64(years.count))
    }

    func clearYearFilter() {
        parameters.yearKeys = nil
        filterVM?.facetYearKeys = nil
        parametersVersion += 1
    }

    /// Clears the #308 subject-bucket narrowing. No `filterVM` counterpart: the Advanced popover
    /// has no subject control, because the bucket is chosen from a breakdown of the current result
    /// set rather than from a standing list.
    func clearSubjectFilter() {
        parameters.subjectBucket = nil
        parameters.subjectBucketKey = nil
        parametersVersion += 1
    }

    func clearVolumeFilter() {
        // Clear the manual volume/subseries selection, then re-derive the scope so the
        // executed gate matches: in Focus this falls back to the subject-derived volumes
        // (the manual selection was overriding them, #377 Phase 2b); off/History simply
        // drop the volume constraint. `applyProjectScope` bumps only if the gate changed.
        if let fvm = filterVM {
            fvm.selectedVolumeIds = []
            fvm.selectedSubseriesIds = []
            applyProjectScope()
        } else {
            parameters.volumeIds = nil
            parametersVersion += 1
        }
    }

    func clearTagFilter() {
        parameters.userTagIds = []
        // The same stale-mirror defect as `clearPersonFilter`: `applyAdvancedFilters` rebuilds
        // `parameters.userTagIds` from `filterVM.selectedUserTagIds` (:727), so clearing only the
        // parameters left the selection checked in the popover and the filter returned on the next
        // edit there.
        filterVM?.selectedUserTagIds = []
        parametersVersion += 1
    }

    // MARK: - Advanced Filter Bridge

    /// Copies current `parameters` state into `filterVM` so the filter sheet
    /// shows the currently active values when presented. Creates `filterVM` on
    /// first call if `searchService` is available.
    func syncToFilterVM(
        searchService: SearchService?,
        volumeEntries: [VolumeManifestEntry] = [],
        indexedVolumeIds: Set<String> = [],
        userTags: [UserTag] = []
    ) {
        if filterVM == nil, let svc = searchService {
            filterVM = SearchViewModel(searchService: svc)
        }
        guard let filterVM else { return }

        // Populate the volume/subseries picker options, then reconstruct the picker
        // selection from the currently active flat `volumeIds` scope so the sheet
        // shows what is actually applied.
        filterVM.loadAvailableVolumes(allEntries: volumeEntries, indexedIds: indexedVolumeIds)
        let scope = SearchViewModel.reconstructScope(
            from: parameters.volumeIds ?? [],
            available: filterVM.availableVolumes
        )
        filterVM.selectedSubseriesIds = scope.subseries
        filterVM.selectedVolumeIds    = scope.volumes

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        filterVM.facetYearKeys = parameters.yearKeys
        if let range = parameters.dateRange {
            filterVM.dateRangeEnabled = true
            if let earliest = range.earliest, let d = fmt.date(from: earliest) {
                filterVM.dateRangeStart = d
            }
            if let latest = range.latest, let d = fmt.date(from: latest) {
                filterVM.dateRangeEnd = d
            }
        } else {
            filterVM.dateRangeEnabled = false
        }

        filterVM.phrase             = parameters.phrase ?? ""
        filterVM.prefixWildcard     = parameters.prefixWildcard ?? ""
        filterVM.booleanMode        = parameters.booleanMode
        filterVM.excludedTermsText  = parameters.excludedTerms.joined(separator: ", ")
        filterVM.personRefText      = parameters.personRef ?? ""
        filterVM.personRollupId     = parameters.personRollupId
        filterVM.personLabel        = parameters.personLabel
        filterVM.personAnchor       = parameters.personAnchor
        filterVM.documentTypeFilter = parameters.documentTypeFilter
        filterVM.includeDocumentText = parameters.includeDocumentText
        filterVM.includeSummaries   = parameters.includeSummaries
        filterVM.includeNotes       = parameters.includeNotes
        // Seeded, not merely applied. A saved search archives the whole `SearchParameters` (#756),
        // so a recalled search really can arrive with front matter excluded; without this line the
        // popover would show it included and the next edit would silently re-include it.
        filterVM.includeFrontMatter = parameters.includeFrontMatter

        // User-tag filter (188-D parity, #212): feed the live tag list so the shared
        // `SearchFilterView.userTagsSection` appears on macOS, and reconstruct the active
        // selection from `parameters` so an applied tag filter shows its tags checked. Because
        // this runs on every "Advanced…" open with a live @Query source, the section always
        // reflects current tags with no relaunch.
        filterVM.availableUserTags  = userTags
        filterVM.selectedUserTagIds = Set(parameters.userTagIds.compactMap { UUID(uuidString: $0) })
    }

    /// Copies `filterVM` state back into `parameters` and triggers a re-search.
    /// Called live by the Search window on each `filterVM.advancedFilterSignature`
    /// change while the filter popover is open (UI audit C4) — there is no
    /// dismiss-time batch anymore.
    func applyAdvancedFilters() {
        guard let filterVM else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        parameters.yearKeys = filterVM.facetYearKeys
        if filterVM.dateRangeEnabled {
            parameters.dateRange = DateRange(
                earliest: fmt.string(from: filterVM.dateRangeStart),
                latest:   fmt.string(from: filterVM.dateRangeEnd)
            )
        } else {
            parameters.dateRange = nil
        }

        parameters.phrase           = filterVM.phrase.isEmpty ? nil : filterVM.phrase
        parameters.prefixWildcard   = filterVM.prefixWildcard.isEmpty ? nil : filterVM.prefixWildcard
        parameters.booleanMode      = filterVM.booleanMode
        parameters.excludedTerms    = filterVM.excludedTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        parameters.personRef        = filterVM.personRefText.isEmpty ? nil : filterVM.personRefText
        parameters.personRollupId   = filterVM.personRollupId
        parameters.personLabel      = filterVM.personLabel
        parameters.personAnchor     = filterVM.personAnchor
        parameters.documentTypeFilter = filterVM.documentTypeFilter
        parameters.includeDocumentText = filterVM.includeDocumentText
        parameters.includeSummaries = filterVM.includeSummaries
        parameters.includeNotes     = filterVM.includeNotes
        // The fourth scope toggle, missing here until M-4. Its absence made the popover's
        // "Include front matter" checkbox a live control that changed nothing on macOS: #916 had
        // already put the property into `advancedFilterSignature`, so flipping it re-ran the search
        // — with this field unchanged. See `setIncludeFrontMatter(_:)`.
        parameters.includeFrontMatter = filterVM.includeFrontMatter
        // User-tag filter (188-D parity, #212): write the selection back so a chosen tag
        // actually narrows the FTS query and drives the "Tagged" summary chip.
        parameters.userTagIds       = filterVM.selectedUserTagIds.map(\.uuidString)
        // Volume scope + project History/Focus gates (#377 Phase 2): a single derivation
        // from the filter VM's scope (see `scopeDerivedParams`) so `applyAdvancedFilters` and
        // `applyProjectScope` never diverge.
        let scoped = scopeDerivedParams()
        parameters.volumeIds          = scoped.volumeIds
        parameters.documentIds        = scoped.documentIds
        parameters.excludeDocumentIds = scoped.excludeDocumentIds

        // Keep scope toggles in sync. Direct assignment to the backing storage
        // would skip the `didSet` observers (which bump `parametersVersion`), but
        // since we already bump `parametersVersion` below this is intentional —
        // the chips just visually reflect what advanced filters already applied.
        scopeDocuments  = filterVM.includeDocumentText
        scopeNotes      = filterVM.includeNotes
        scopeSummaries  = filterVM.includeSummaries

        parametersVersion += 1
    }

    // MARK: - Pending Search Application

    /// Applies a `SearchParameters` snapshot received from `AppState.pendingSearch`.
    ///
    /// Sets both `parameters` and the reflected UI state (scope toggles, query text),
    /// then bumps `parametersVersion` so `.task(id: searchTrigger)` fires a new search.
    ///
    /// A keyword-less person handoff (the People browser's "Find all mentions") runs on its
    /// `personRef`/`personRollupId` filter alone — `performSearch` now treats a person filter as a
    /// valid standalone term, and the `parametersVersion` bump fires the search. We no longer
    /// fabricate a `"person:<ref>"` query string (which used to leak into the FTS keywords).
    func applyParameters(_ params: SearchParameters) {
        let kw = params.keywords ?? ""
        queryText = kw
        submittedQuery = kw
        parameters = params
        // Project History/Focus scope is a live, manual choice — never inherited from a
        // restored snapshot or a pending-search hand-off (#377 Phase 2). Drop any gates the
        // snapshot carried and clear the filter VM's selection so the picker matches, and so
        // a later unrelated filter edit (which re-runs `applyAdvancedFilters`) can't silently
        // reintroduce a gate.
        parameters.documentIds = nil
        parameters.excludeDocumentIds = nil
        filterVM?.projectScope = .off
        filterVM?.projectOnlyNew = false
        scopeDocuments = params.includeDocumentText
        scopeNotes     = params.includeNotes
        scopeSummaries = params.includeSummaries
        parametersVersion += 1
    }

    /// Re-derives `parameters.documentIds` from the filter VM's current project scope +
    /// engaged-key set and re-runs the search **only if the effective gate changed**
    /// (#377 Phase 2a). Called by `SearchSheet` after it (re)loads the engaged set — on
    /// opening Advanced filters and on an active-project change — so the executed query
    /// always reflects the live project scope without re-searching when nothing changed
    /// (e.g. merely opening the panel with no scope active; the engaged set is stored sorted
    /// so an unchanged set compares equal). Note: if the active project changes *while* the
    /// Advanced popover is open with History active, this bump plus the popover's own
    /// `advancedFilterSignature` observer (which sees the scope flip to `.off`) can both fire
    /// — two re-searches for one switch, both correctly yielding the ungated result.
    func applyProjectScope() {
        guard filterVM != nil else { return }
        let scoped = scopeDerivedParams()
        if scoped.volumeIds != parameters.volumeIds
            || scoped.documentIds != parameters.documentIds
            || scoped.excludeDocumentIds != parameters.excludeDocumentIds {
            parameters.volumeIds          = scoped.volumeIds
            parameters.documentIds        = scoped.documentIds
            parameters.excludeDocumentIds = scoped.excludeDocumentIds
            parametersVersion += 1
        }
    }

    /// The volume scope + project History/Focus gates derived from the filter VM's current
    /// scope (#377 Phase 2). The single source both `applyAdvancedFilters` and
    /// `applyProjectScope` use, so the executed `parameters` never disagree about the scope.
    /// - Focus overrides the volume scope with the subject-derived focus volumes and,
    ///   with "only new" on, excludes the engaged set; History gates to the engaged set;
    ///   off uses the manual volume/subseries selection.
    private func scopeDerivedParams() -> (volumeIds: [String]?, documentIds: [String]?, excludeDocumentIds: [String]?) {
        guard let fvm = filterVM else { return (nil, nil, nil) }
        let manualVolumes = fvm.effectiveVolumeIds.isEmpty ? nil : fvm.effectiveVolumeIds
        let volumeIds: [String]?
        let documentIds: [String]?
        switch fvm.projectScope {
        case .off:
            volumeIds = manualVolumes
            documentIds = nil
        case .history:
            volumeIds = manualVolumes
            documentIds = fvm.projectEngagedDocumentKeys
        case .focus:
            // A manual volume selection (or applied custom scope) overrides the subject-
            // derived focus volumes; with neither, Focus matches nothing (empty
            // `documentIds`, per the History contract) rather than the whole corpus.
            if let manual = manualVolumes {
                volumeIds = manual
                documentIds = nil
            } else if fvm.projectFocusVolumeIds.isEmpty {
                volumeIds = nil
                documentIds = []
            } else {
                volumeIds = fvm.projectFocusVolumeIds
                documentIds = nil
            }
        }
        let exclude = (fvm.projectScope == .focus && fvm.projectOnlyNew)
            ? fvm.projectEngagedDocumentKeys : nil
        // M-1: the working corpus composes with whatever the project scope already gated, by
        // INTERSECTION — both are document-grain constraints the user applied. Missing here, an
        // applied corpus was written to `filterVM` and never reached `parameters`, so the Mac
        // search ignored it entirely while the filter sheet showed it as applied.
        let gated = DocumentScopeGate.combine(corpus: fvm.appliedWorkingCorpusKeys,
                                              projectGate: documentIds)
        return (volumeIds, gated, exclude)
    }

    // MARK: - Search

    /// Commits the current `queryText` as the submitted query and fires a search.
    ///
    /// Sets `submittedQuery = queryText`, which changes `searchTrigger` and causes
    /// the `.task(id: searchTrigger)` observer in `SearchSheet` to call `performSearch`.
    /// This is the **only** path that updates `submittedQuery`; it is bound to
    /// `.onSubmit` (Return key) so searches fire only when the user explicitly submits.
    func submitSearch() {
        submittedQuery = queryText
    }

    /// Executes a search against `SearchService` using `submittedQuery` and the current `parameters`.
    ///
    /// Fetches up to `searchHardLimit` (7,500) results so all pagination pages are available
    /// client-side. In parallel, fetches the true total match count via
    /// `SearchService.searchCount` and stores it in `totalMatchCount`. When all three scope
    /// flags are disabled (`includeDocumentText`, `includeSummaries`, `includeNotes` all
    /// false), a friendly error is set before any FTS5 call is attempted.
    ///
    /// `currentPage` is reset to 0 on every successful fetch; if the result set shrank below
    /// the previous page index it is clamped to a valid page.
    ///
    /// ## Cancellation handling
    /// Called exclusively from `.task(id: searchTrigger)` in `SearchSheet`. When
    /// `searchTrigger` changes, SwiftUI cancels the running task before starting a new one.
    /// `CancellationError` is caught here and causes an early return **without** clearing
    /// `results` — preserving the previous result set during the transition rather than
    /// flashing an empty list. `isSearching` is always reset via `defer`.
    func performSearch(service: SearchService?) async {
        let query = submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        // A person filter (single ref or a cross-corpus rollup) is a valid standalone term, so a
        // keyword-less "Find all mentions" handoff runs on it alone.
        let hasPersonFilter = parameters.personRef != nil || parameters.personRollupId != nil
        guard (!query.isEmpty || hasPersonFilter), let service else {
            results = []
            totalMatchCount = nil
            lastRenderedExpression = nil
            return
        }

        var params = parameters
        params.keywords = query.isEmpty ? nil : query

        // Empty scope guard: at least one of the three scope flags must be enabled.
        // Without this, SearchService throws `emptyQuery`, which surfaces as an unhelpful
        // technical error string.
        guard params.includeDocumentText || params.includeSummaries || params.includeNotes else {
            results = []
            totalMatchCount = nil
            lastRenderedExpression = nil
            searchError = MacSearchError.emptyScope
            return
        }

        isSearching = true
        searchError = nil
        currentPage = 0
        defer { isSearching = false }

        // Re-anchor the checklist ONLY when the submitted query actually changed (#189-D).
        // Unlike iOS's `search()` — which fires only for deliberate new queries — macOS
        // `performSearch` also re-runs on every filter/scope change (those bump
        // `parametersVersion`, part of `searchTrigger`), so an unconditional re-anchor would
        // silently wipe the user's reviewed marks whenever they touched a filter mid-session.
        // Gating on the query (mirrors `historyAnchor`) keeps marks across filter
        // re-runs of the same query while still clearing them for a genuine new query. Reviewed
        // identity is document identity, which recurs across searches, so a stale mark must not
        // leak into an unrelated query.
        if checklistMode, query != lastChecklistAnchorQuery {
            lastChecklistAnchorQuery = query
            checklistEnabledAt = .now
            readSinceEnabledKeys.removeAll()
            markedReviewedKeys.removeAll()
        }

        // Capture an immutable copy so Swift 6 region-based isolation is happy
        // when the same parameters value is sent to two actor-isolated calls below.
        let frozenParams = params

        // Fetch results and total count in parallel. searchCount runs an FTS5 COUNT(*)
        // without snippet/bm25 work so it returns substantially faster than search().
        async let resultsTask  = service.search(parameters: frozenParams,
                                                limit: Self.searchHardLimit)
        async let countTask    = service.searchCount(parameters: frozenParams)
        async let expressionTask = try? service.matchExpressions(for: frozenParams).corpus
        do {
            let fetched = try await resultsTask
            results = fetched
            lastRenderedExpression = await expressionTask
            executedSearchVersion &+= 1
            // Deliberately NOT `?? fetched.count`. An unavailable count is unknown, not
            // equal to what happened to be fetched — see `totalMatchCount`.
            if let total = try? await countTask {
                // `max` guards the reverse inconsistency: a count that somehow came back
                // below the fetch would understate the result set.
                totalMatchCount = max(total, fetched.count)
            } else {
                totalMatchCount = nil
            }
            // Clamp page index to the new result set.
            if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
            #if DEBUG
            // `totalMatchCount` is Optional — nil when the whole-query count was not fetched
            // (see the branch above). Interpolating it directly printed "Optional(1234)", or
            // the bare word "nil", which is why the compiler flags the debug-description
            // interpolation: the log line was less readable than it looked.
            print("[MacSearchViewModel] Search returned \(fetched.count)/"
                  + "\(totalMatchCount.map(String.init) ?? "not counted") results")
            #endif
        } catch {
            // CancellationError means this task was superseded by a new search trigger.
            // Preserve the current results rather than flashing an empty list.
            guard !(error is CancellationError) else { return }
            searchError = error
            results = []
            totalMatchCount = nil
            lastRenderedExpression = nil
            #if DEBUG
            print("[MacSearchViewModel] Search failed: \(error)")
            #endif
        }
    }

    // MARK: - Search History

    /// What this window last wrote to the trail — see ``SearchHistoryWriter/Anchor``.
    ///
    /// Filter and scope changes bump `parametersVersion`, which re-runs `performSearch` for the
    /// **same** `submittedQuery`. Those are not separate searches the researcher ran, so they
    /// refresh the anchored row rather than minting a second one — but the row's scope and counts
    /// become the ones it finally ran under, which is the M-2 fix.
    private var historyAnchor: SearchHistoryWriter.Anchor?

    /// Records the most recently executed search — the macOS half of the trail's search producer.
    ///
    /// Call once after `performSearch` completes. All the rules — the research-logging gate, the
    /// empty-query and error skips, and the insert-or-refresh decision — live in
    /// ``SearchHistoryWriter``, shared with iOS.
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
                queryText: submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                // The true total when there is one, the fetched count otherwise. Before Q-M2 an
                // unavailable count was written as exactly the fetch cap, so a trail entry could
                // record "7,500" for a query matching 195,519 — a number a researcher may cite.
                resultCount: resultCountForDisplay,
                loadedCount: results.count,
                matchCount: totalMatchCount,
                fetchLimit: Self.searchHardLimit,
                indexedVolumeCount: indexedVolumeCount,
                parameters: submittedSearchParameters,
                appliedCorpusId: filterVM?.appliedWorkingCorpusId,
                renderedExpression: lastRenderedExpression,
                projectId: projectId,
                hasError: searchError != nil),
            anchor: &historyAnchor,
            in: context,
            defaults: defaults)
        #if DEBUG
        print("[MacSearchViewModel] SearchHistoryEntry \(outcome): \"\(submittedQuery)\"")
        #else
        _ = outcome
        #endif
    }
}

// MARK: - MacSearchError

/// User-facing error states that originate in `MacSearchViewModel` rather than the
/// underlying `SearchService` / `FTS5Store` layer.
///
/// Version history:
///   1.0 — Session 120: added for the empty-scope guard in `performSearch`
enum MacSearchError: LocalizedError {
    /// All three "Search in" scope flags are disabled — there is nothing to search.
    case emptyScope

    var errorDescription: String? {
        switch self {
        case .emptyScope:
            return String(
                localized: "search.error.emptyScope",
                defaultValue: "Enable at least one of Documents, Notes, or Summaries to search."
            )
        }
    }
}

#endif // os(macOS)
