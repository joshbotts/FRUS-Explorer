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
/// `queryText` is observed by a `.task(id: debouncedQuery)` in `SearchSheet`.
/// `debouncedQuery` updates after a 300ms delay, triggering a new search.
/// Immediate searches can be triggered by calling `performSearch` directly.
///
/// ## Filter State
/// `parameters` is a `SearchParameters` value type mutated by the filter controls.
/// Scope toggles (`scopeDocuments`, `scopeNotes`, `scopeSummaries`) project into
/// `parameters.includeSummaries` / `parameters.includeNotes`.
///
/// ## Sorting
/// Sorting is applied client-side after results arrive from `SearchService`, since
/// BM25 scores are already in the result set and date strings are in ISO 8601 order.
///
/// ## Naming
/// Named `MacSearchViewModel` to distinguish from the existing iOS `SearchViewModel`
/// in `Search/SearchViewModel.swift`. The iOS revamp will reconcile these.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; iOS revamp will unify)
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
        didSet { parameters.includeNotes = scopeNotes }
    }

    var scopeSummaries: Bool = true {
        didSet { parameters.includeSummaries = scopeSummaries }
    }

    var scopeCollections: Bool = false // deferred to future session

    // MARK: - Filter Parameters

    var parameters: SearchParameters = SearchParameters()

    // MARK: - Sort

    var sortOrder: SearchSortOrder = .relevance

    // MARK: - Results

    var results: [SearchResult] = []
    var isSearching: Bool = false
    var searchError: Error? = nil

    var sortedResults: [SearchResult] {
        switch sortOrder {
        case .relevance:
            return results
        case .dateAscending:
            return results.sorted { ($0.dateline ?? "") < ($1.dateline ?? "") }
        case .dateDescending:
            return results.sorted { ($0.dateline ?? "") > ($1.dateline ?? "") }
        }
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
        if parameters.dateRange != nil  { parts.append("date") }
        if parameters.volumeIds != nil  { parts.append("volume") }
        if !parameters.userTagIds.isEmpty { parts.append("tags") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Private

    private var debounceTask: Task<Void, Never>?

    // MARK: - Search

    /// Executes a search against `SearchService` using the current `parameters` and `queryText`.
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

        do {
            results = try await service.search(parameters: params, limit: 50)
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
