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

// MARK: - SearchSortOrder

enum SearchSortOrder: CaseIterable {
    case relevance
    case dateAscending
    case dateDescending

    var label: String {
        switch self {
        case .relevance:      return "Relevance"
        case .dateAscending:  return "Date ↑"
        case .dateDescending: return "Date ↓"
        }
    }
}

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
///   via `SearchFilterView`. Call `applyAdvancedFilters()` on sheet dismiss to copy
///   `filterVM` values into `parameters` and trigger re-search.
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

    var scopeCollections: Bool = false // deferred to future session

    // MARK: - Filter Parameters

    var parameters: SearchParameters = SearchParameters()

    /// Triggers a re-search whenever any filter changes. Observed via `searchTrigger`.
    var parametersVersion: Int = 0

    /// Combined token for `.task(id:)` — changes when the submitted query or any
    /// filter changes. Does **not** change when the user is merely typing in the
    /// text field; only `submitSearch()` (Return key) updates `submittedQuery`.
    var searchTrigger: String { "\(submittedQuery)|\(parametersVersion)" }

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

    var totalPages: Int {
        max(1, Int(ceil(Double(results.count) / Double(pageSize))))
    }

    // MARK: - Results

    var results: [SearchResult] = []
    var isSearching: Bool = false
    var searchError: Error? = nil

    /// True total number of matches across the full corpus for the current query,
    /// independent of `searchHardLimit`. Updated in parallel with `results` by
    /// `performSearch`. When `totalMatchCount > results.count`, results have been
    /// truncated to fit `searchHardLimit` and the UI shows an over-cap advisory.
    var totalMatchCount: Int = 0

    /// True iff the displayed `results` are a truncated subset of `totalMatchCount`.
    var isResultSetTruncated: Bool { totalMatchCount > results.count }

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
        let all = allSortedResults
        let start = currentPage * pageSize
        guard start < all.count else { return [] }
        return Array(all[start..<min(start + pageSize, all.count)])
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
        return parameters.userTagIds.count == 1 ? parameters.userTagIds[0] : "\(parameters.userTagIds.count) tags"
    }

    var activeFilterSummary: String? {
        var parts: [String] = []
        if parameters.dateRange != nil           { parts.append("date") }
        if parameters.volumeIds != nil           { parts.append("volume") }
        if !parameters.userTagIds.isEmpty        { parts.append("tags") }
        if parameters.phrase != nil              { parts.append("phrase") }
        if parameters.personRef != nil           { parts.append("person") }
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

    func clearDateFilter() {
        parameters.dateRange = nil
        filterVM?.dateRangeEnabled = false
        parametersVersion += 1
    }

    func clearVolumeFilter() {
        parameters.volumeIds = nil
        parametersVersion += 1
    }

    func clearTagFilter() {
        parameters.userTagIds = []
        parametersVersion += 1
    }

    // MARK: - Advanced Filter Bridge

    /// Copies current `parameters` state into `filterVM` so the filter sheet
    /// shows the currently active values when presented. Creates `filterVM` on
    /// first call if `searchService` is available.
    func syncToFilterVM(searchService: SearchService?) {
        if filterVM == nil, let svc = searchService {
            filterVM = SearchViewModel(searchService: svc)
        }
        guard let filterVM else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

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
        filterVM.documentTypeFilter = parameters.documentTypeFilter
        filterVM.includeDocumentText = parameters.includeDocumentText
        filterVM.includeSummaries   = parameters.includeSummaries
        filterVM.includeNotes       = parameters.includeNotes
    }

    /// Copies `filterVM` state back into `parameters` and triggers a re-search.
    /// Call this in the `onDismiss` handler of the `SearchFilterView` sheet.
    func applyAdvancedFilters() {
        guard let filterVM else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

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
        parameters.documentTypeFilter = filterVM.documentTypeFilter
        parameters.includeDocumentText = filterVM.includeDocumentText
        parameters.includeSummaries = filterVM.includeSummaries
        parameters.includeNotes     = filterVM.includeNotes

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
    /// If no keywords are provided but a `personRef` filter is present, the person ref
    /// is used as the query text so the search actually runs.
    func applyParameters(_ params: SearchParameters) {
        let kw = params.keywords ?? (params.personRef.map { "person:\($0)" } ?? "")
        if !kw.isEmpty {
            queryText = kw
            submittedQuery = kw
        }
        parameters = params
        scopeDocuments = params.includeDocumentText
        scopeNotes     = params.includeNotes
        scopeSummaries = params.includeSummaries
        parametersVersion += 1
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
        guard !query.isEmpty, let service else {
            results = []
            totalMatchCount = 0
            return
        }

        var params = parameters
        params.keywords = query

        // Empty scope guard: at least one of the three scope flags must be enabled.
        // Without this, SearchService throws `emptyQuery`, which surfaces as an unhelpful
        // technical error string.
        guard params.includeDocumentText || params.includeSummaries || params.includeNotes else {
            results = []
            totalMatchCount = 0
            searchError = MacSearchError.emptyScope
            return
        }

        isSearching = true
        searchError = nil
        currentPage = 0
        defer { isSearching = false }

        // Capture an immutable copy so Swift 6 region-based isolation is happy
        // when the same parameters value is sent to two actor-isolated calls below.
        let frozenParams = params

        // Fetch results and total count in parallel. searchCount runs an FTS5 COUNT(*)
        // without snippet/bm25 work so it returns substantially faster than search().
        async let resultsTask  = service.search(parameters: frozenParams,
                                                limit: Self.searchHardLimit)
        async let countTask    = service.searchCount(parameters: frozenParams)
        do {
            let fetched = try await resultsTask
            let total   = (try? await countTask) ?? fetched.count
            results = fetched
            totalMatchCount = max(total, fetched.count)
            // Clamp page index to the new result set.
            if currentPage >= totalPages { currentPage = max(0, totalPages - 1) }
            #if DEBUG
            print("[MacSearchViewModel] Search returned \(fetched.count)/\(totalMatchCount) results")
            #endif
        } catch {
            // CancellationError means this task was superseded by a new search trigger.
            // Preserve the current results rather than flashing an empty list.
            guard !(error is CancellationError) else { return }
            searchError = error
            results = []
            totalMatchCount = 0
            #if DEBUG
            print("[MacSearchViewModel] Search failed: \(error)")
            #endif
        }
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
