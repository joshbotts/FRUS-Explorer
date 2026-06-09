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
/// 2. Call `loadAvailableUserTags(context:)` to populate the user tag picker.
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
///   1.5 — Session 130: `searchHardLimit = 500` passed to `searchService.search()`; iOS
///          was silently capped at `defaultPageSize = 20` (the macOS VM already used 7 500)
///   1.6 — Session 2026-06-08: `phrase`, `prefixWildcard`, `booleanMode`, and
///          `excludedTermsText` are no longer user-editable — `SearchFilterView`'s
///          "Advanced Text" controls were removed in favour of `FTS5InlineQueryParser`
///          inline syntax in the main search box. The properties remain solely so
///          `applyParameters(_:)` can restore older `SavedSearch`/`pendingSearch`
///          snapshots without data loss.
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

    var selectedSubjectTagIds: Set<String> = []
    var selectedUserTagIds: Set<UUID> = []

    // MARK: - Content Scope Parameters

    /// Whether document body content (header, dateline, source note, body text)
    /// is included in the search scope. Default `true`.
    var includeDocumentText: Bool = true
    var includeSummaries: Bool = true
    var includeNotes: Bool = true

    // MARK: - Document Type Filter

    /// Which document types to include in results. Default `.all`.
    var documentTypeFilter: DocumentTypeFilter = .all

    // MARK: - Front Matter Scope

    /// Whether front-matter prose sections (preface, introduction, prefatoryNote, terms, etc.)
    /// are included in search results. Default `true`.
    var includeFrontMatter: Bool = true

    // MARK: - Person Reference Filter

    /// `@ref` attribute value from `<persName>` to restrict results to documents
    /// that mention a specific person. Empty string means no filter.
    var personRefText: String = ""

    // MARK: - Results

    var results: [SearchResult] = []
    var isSearching: Bool = false
    var searchError: String? = nil
    var hasSearched: Bool = false

    // MARK: - Available Filter Options

    var availableUserTags: [UserTag] = []

    // MARK: - UI State

    /// Controls presentation of the `SearchFilterView` sheet.
    /// Set to `true` by the filter toolbar button; `false` when the sheet is dismissed.
    var showFilterPanel: Bool = false
    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Pagination

    /// Maximum results fetched by `search()`.
    ///
    /// iOS shows all results in a continuous list (no client-side pagination), so a
    /// cap of 500 balances completeness against list-render memory. The macOS search
    /// window uses a separate hard limit of 7 500 with explicit page controls.
    static let searchHardLimit: Int = 500

    // MARK: - Dependencies

    private let searchService: SearchService

    /// Injected by `SearchView` after init so `search()` can fire `logEvent`.
    /// Optional: no-op if not set (e.g. in unit tests).
    weak var appState: AppState?

    // MARK: - Initialisation

    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // MARK: - Setup

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
            results = try await searchService.search(parameters: params,
                                                     limit: Self.searchHardLimit)
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
        if hasSearched {
            appState?.logEvent(.searchSubmit(
                query: keywords.trimmingCharacters(in: .whitespaces),
                resultCount: results.count
            ))
        }
    }

    func clearFilters() {
        phrase = ""
        prefixWildcard = ""
        booleanMode = .and
        excludedTermsText = ""
        dateRangeEnabled = false
        selectedSubjectTagIds = []
        selectedUserTagIds = []
        includeDocumentText = true
        includeSummaries = true
        includeNotes = true
        includeFrontMatter = true
        documentTypeFilter = .all
        personRefText = ""
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
            includeDocumentText: includeDocumentText,
            includeSummaries: includeSummaries,
            includeNotes: includeNotes,
            documentTypeFilter: documentTypeFilter,
            personRef: personRefText.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : personRefText.trimmingCharacters(in: .whitespaces),
            includeFrontMatter: includeFrontMatter
        )
    }

    var resultCount: Int { results.count }

    /// `true` when the result set hit `searchHardLimit`, indicating the query matches
    /// more documents than are shown. Users should narrow their search terms.
    var isResultsCapped: Bool { results.count == Self.searchHardLimit }

    // Note: this still checks the legacy `phrase`/`prefixWildcard`/`excludedTermsText`/
    // `booleanMode` fields even though `SearchFilterView` no longer exposes controls for
    // them — a restored `SavedSearch`/`pendingSearch` snapshot can still populate them via
    // `applyParameters(_:)`, and when it does, that state genuinely affects the query, so
    // the "Clear Filters" affordance must remain available to reset it.
    var hasActiveFilters: Bool {
        if documentTypeFilter != .all { return true }
        if !personRefText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if dateRangeEnabled { return true }
        if !selectedSubjectTagIds.isEmpty { return true }
        if !selectedUserTagIds.isEmpty { return true }
        if !excludedTermsText.isEmpty { return true }
        if !phrase.isEmpty { return true }
        if !prefixWildcard.isEmpty { return true }
        if !includeDocumentText || !includeSummaries || !includeNotes { return true }
        if !includeFrontMatter { return true }
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
        if let range = params.dateRange {
            dateRangeEnabled = true
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            if let earliest = range.earliest { dateRangeStart = fmt.date(from: earliest) ?? dateRangeStart }
            if let latest   = range.latest   { dateRangeEnd   = fmt.date(from: latest)   ?? dateRangeEnd }
        } else {
            dateRangeEnabled = false
        }
        selectedSubjectTagIds = Set(params.subjectTagIds)
        selectedUserTagIds    = Set(params.userTagIds.compactMap { UUID(uuidString: $0) })
        includeDocumentText   = params.includeDocumentText
        includeSummaries      = params.includeSummaries
        includeNotes          = params.includeNotes
        includeFrontMatter    = params.includeFrontMatter
        documentTypeFilter    = params.documentTypeFilter
    }

    // MARK: - Private Helpers

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
