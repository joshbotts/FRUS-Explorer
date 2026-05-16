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
/// Binds directly to `SearchService` for FTS5 queries and `SubjectTagStore`
/// for subject tag filter options.
///
/// ## Project Defaults
/// Call `applyProjectDefaults(_:)` after init to pre-populate filters from
/// the active project's default date range and subject tag IDs.
///
/// ## Lifecycle
/// 1. Init with `searchService` and `subjectTagStore`.
/// 2. Call `loadAvailableSubjectTags()` to populate the subject tag picker.
/// 3. Call `loadAvailableUserTags(context:)` to populate the user tag picker.
/// 4. Optionally call `applyProjectDefaults(_:)` if a project is active.
/// 5. Call `search()` when the user submits.
///
/// ## Suffix Wildcard Limitation
/// Only prefix wildcards are supported by FTS5 (e.g. `negoti*`). The `*`
/// is appended automatically to `prefixWildcard`. Suffix wildcards (`*ate`)
/// are not valid FTS5 syntax and are not exposed in the UI.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: `documentTypeFilter` property added
@Observable
@MainActor
final class SearchViewModel {

    // MARK: - Text Search Parameters

    /// Space-separated keywords (combined via `booleanMode`).
    var keywords: String = ""

    /// Exact phrase — order-sensitive, case-insensitive.
    var phrase: String = ""

    /// Prefix for a wildcard search. `*` is appended automatically.
    /// Only prefix wildcards are supported; suffix wildcards are not valid FTS5.
    var prefixWildcard: String = ""

    /// How keyword terms are combined. Default `.and`.
    var booleanMode: FTS5Query.BooleanMode = .and

    /// Comma-separated terms that must NOT appear in matching documents.
    var excludedTermsText: String = ""

    // MARK: - Date Range Parameters

    var dateRangeEnabled: Bool = false
    var dateRangeStart: Date = Calendar.current.date(byAdding: .year, value: -80, to: .now) ?? .distantPast
    var dateRangeEnd: Date = .now

    // MARK: - Tag Filter Parameters

    var selectedSubjectTagIds: Set<String> = []
    var selectedUserTagIds: Set<UUID> = []

    // MARK: - Content Scope Parameters

    var includeSummaries: Bool = true
    var includeNotes: Bool = true

    // MARK: - Document Type Filter

    /// Which document types to include in results. Default `.all`.
    var documentTypeFilter: DocumentTypeFilter = .all

    // MARK: - Results

    var results: [SearchResult] = []
    var isSearching: Bool = false
    var searchError: String? = nil
    var hasSearched: Bool = false

    // MARK: - Available Filter Options

    var availableSubjectTags: [SubjectTag] = []
    var availableUserTags: [UserTag] = []

    // MARK: - UI State

    var showFilterPanel: Bool = false
    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Dependencies

    private let searchService: SearchService
    let subjectTagStore: SubjectTagStore

    // MARK: - Initialisation

    init(searchService: SearchService, subjectTagStore: SubjectTagStore) {
        self.searchService = searchService
        self.subjectTagStore = subjectTagStore
    }

    // MARK: - Setup

    func loadAvailableSubjectTags() async {
        availableSubjectTags = await subjectTagStore.allTags()
    }

    func loadAvailableUserTags(context: ModelContext) {
        availableUserTags = (try? context.fetch(
            FetchDescriptor<UserTag>(sortBy: [SortDescriptor(\.name)])
        )) ?? []
    }

    func applyProjectDefaults(_ project: Project?) {
        guard let project else { return }
        if let start = project.defaultDateRangeStart,
           let end = project.defaultDateRangeEnd {
            dateRangeEnabled = true
            dateRangeStart = start
            dateRangeEnd = end
        }
        if !project.defaultSubjectTagIds.isEmpty {
            selectedSubjectTagIds = Set(project.defaultSubjectTagIds)
        }
    }

    // MARK: - Search

    func search() async {
        let params = searchParameters
        let hasPositiveTerm = params.keywords != nil || params.phrase != nil || params.prefixWildcard != nil
        guard hasPositiveTerm else {
            searchError = String(
                localized: "search.error.empty",
                defaultValue: "Enter a keyword, phrase, or prefix to search."
            )
            return
        }
        isSearching = true
        searchError = nil
        hasSearched = true
        do {
            results = try await searchService.search(parameters: params)
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
    }

    func clearFilters() {
        phrase = ""
        prefixWildcard = ""
        booleanMode = .and
        excludedTermsText = ""
        dateRangeEnabled = false
        selectedSubjectTagIds = []
        selectedUserTagIds = []
        includeSummaries = true
        includeNotes = true
        documentTypeFilter = .all
    }

    func clearAll() {
        keywords = ""
        clearFilters()
        results = []
        hasSearched = false
        searchError = nil
    }

    // MARK: - Computed Properties

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
        return SearchParameters(
            keywords: kw.isEmpty ? nil : kw,
            phrase: ph.isEmpty ? nil : ph,
            booleanMode: booleanMode,
            excludedTerms: excluded,
            prefixWildcard: pw.isEmpty ? nil : pw,
            dateRange: range,
            subjectTagIds: Array(selectedSubjectTagIds),
            userTagIds: selectedUserTagIds.map(\.uuidString),
            includeSummaries: includeSummaries,
            includeNotes: includeNotes,
            documentTypeFilter: documentTypeFilter
        )
    }

    var resultCount: Int { results.count }

    var hasActiveFilters: Bool {
        if documentTypeFilter != .all { return true }
        if dateRangeEnabled { return true }
        if !selectedSubjectTagIds.isEmpty { return true }
        if !selectedUserTagIds.isEmpty { return true }
        if !excludedTermsText.isEmpty { return true }
        if !phrase.isEmpty { return true }
        if !prefixWildcard.isEmpty { return true }
        if !includeSummaries || !includeNotes { return true }
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

    // MARK: - Private Helpers

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
