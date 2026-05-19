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
/// ## Debouncing
/// `queryText` is observed by a `.task(id: searchTrigger)` in `SearchSheet`.
/// `debouncedQuery` updates after a 300ms delay. `parametersVersion` is bumped
/// whenever filter state changes. Either change triggers a new search.
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
/// by `pageSize`/`currentPage`. `performSearch` always fetches up to 500 results so that
/// all pages are available without a server round-trip.
///
/// ## Naming
/// Named `MacSearchViewModel` to distinguish from the existing iOS `SearchViewModel`
/// in `Search/SearchViewModel.swift`. The iOS revamp will reconcile these.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; iOS revamp will unify)
///   1.1 — Add pagination, parametersVersion, filterVM bridge, advanced filter sync
@Observable
@MainActor
final class MacSearchViewModel {

    // MARK: - Input State

    var queryText: String = "" {
        didSet {
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                debouncedQuery = queryText
            }
        }
    }

    /// Updated after debounce delay. Observed by `SearchSheet`'s `.task(id:)`.
    var debouncedQuery: String = ""

    // MARK: - Scope toggles

    var scopeDocuments: Bool = true {
        didSet { /* documents scope always on in current model */ }
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

    /// Combined token for `.task(id:)` — changes when query or any filter changes.
    var searchTrigger: String { "\(debouncedQuery)|\(parametersVersion)" }

    // MARK: - Advanced Filter ViewModel

    /// Backing view model for `SearchFilterView` presented as a sheet.
    /// Created lazily on the first call to `syncToFilterVM(searchService:subjectTagStore:)`.
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

    var allSortedResults: [SearchResult] {
        switch sortOrder {
        case .relevance:
            return results
        case .dateAscending:
            return results.sorted { ($0.dateline ?? "") < ($1.dateline ?? "") }
        case .dateDescending:
            return results.sorted { ($0.dateline ?? "") > ($1.dateline ?? "") }
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

    // MARK: - Private

    private var debounceTask: Task<Void, Never>?

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
    func syncToFilterVM(searchService: SearchService?, subjectTagStore: SubjectTagStore) {
        if filterVM == nil, let svc = searchService {
            filterVM = SearchViewModel(searchService: svc, subjectTagStore: subjectTagStore)
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
        parameters.includeSummaries = filterVM.includeSummaries
        parameters.includeNotes     = filterVM.includeNotes

        // Keep scope toggles in sync
        scopeNotes      = filterVM.includeNotes
        scopeSummaries  = filterVM.includeSummaries

        parametersVersion += 1
    }

    // MARK: - Search

    /// Executes a search against `SearchService` using the current `parameters` and `queryText`.
    /// Fetches up to 500 results so all pagination pages are available client-side.
    func performSearch(service: SearchService?) async {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let service else {
            results = []
            return
        }

        var params = parameters
        params.keywords = query

        isSearching = true
        searchError = nil
        currentPage = 0

        do {
            results = try await service.search(parameters: params, limit: 500)
        } catch {
            searchError = error
            results = []
            #if DEBUG
            print("[MacSearchViewModel] Search failed: \(error)")
            #endif
        }

        isSearching = false
    }
}

#endif // os(macOS)
