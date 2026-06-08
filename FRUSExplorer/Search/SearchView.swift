// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SearchView

/// Full composable search view with keyword search, advanced filters, and a results list.
///
/// ## Layout
/// Uses SwiftUI's `.searchable` modifier to place the keyword field in the navigation
/// bar (on iOS) or toolbar (on macOS). Advanced filters are presented via a separate
/// `SearchFilterView` sheet, opened with the filter toolbar button.
///
/// ## Navigation
/// Uses its own `NavigationStack` so document navigation stays within the search
/// context without affecting the browser's navigation stack.
///
/// ## Suffix Wildcard
/// Only prefix wildcards are supported by FTS5 (`negoti*`). This limitation is
/// documented in `SearchFilterView`'s advanced text section and in `SearchViewModel`.
///
/// Version history:
///   1.0 — Session 16: initial implementation
///   1.1 — Session 38: document type filter section added to filter panel
///   1.2 — Session 40: person ref filter field added; `initialParameters` support
///   1.3 — Session 41: person ref field replaced with autocomplete picker backed by SQLite
///   1.4 — Session 44: Done button and dismiss guarded to non-iOS (Search is a tab on iOS)
///   1.5 — Session 62: replaced custom `searchInputRow` with `.searchable` modifier;
///          filter panel extracted to `SearchFilterView` sheet (F-002); `personSearchText`
///          and `personSuggestions` moved to `SearchFilterView`
///   1.6 — Session 88: timeline toggle button; `DocumentTimelineView` replaces results list when active
///   1.7 — Session 96: Save Search toolbar button + name sheet; Saved Searches toolbar button + list sheet
///   1.8 — Session 100: vm.appState wired in .task for searchSubmit logging
///   1.9 — Session 2026-06-07: over-cap "Visualize in Corpus Analytics" button in
///          `resultCountHeader` — hands keywords + active date filter off to
///          `AnalyticsView` via `AppState.pendingAnalytics` (see `AnalyticsParameters`)
///   1.10 — Session 2026-06-08: removed the `.bottomBar` toolbar placement used on
///          compact-width iPhones — it visually conflicted with `MainTabView`'s
///          app-level tab bar (the tab bar won the z-order fight and hid the
///          buttons entirely). Save Search and Saved Searches are now folded into
///          a single "More" overflow `Menu`, and Filter/Timeline stay as compact
///          icons — keeping everything in the nav bar at every size class so there
///          is no second bottom bar to collide with the tab bar.
struct SearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @State private var vm: SearchViewModel
    @State private var showTimeline = false
    @State private var showSaveSearchSheet = false
    @State private var showSavedSearches = false
    @State private var saveSearchName = ""
    private let initialParameters: SearchParameters?

    init(
        searchService: SearchService,
        initialParameters: SearchParameters? = nil
    ) {
        _vm = State(initialValue: SearchViewModel(searchService: searchService))
        self.initialParameters = initialParameters
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack(path: $vm.navigationPath) {
            resultsSection
                .navigationTitle(
                    String(localized: "search.title", defaultValue: "Search")
                )
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                // System search bar — integrates with the navigation bar on iOS
                // and the toolbar area on macOS (inspector context).
                .searchable(
                    text: $vm.keywords,
                    prompt: String(localized: "search.keywords.placeholder",
                                   defaultValue: "Keywords…")
                )
                // Fire search on keyboard Return / iOS "Search" button.
                .onSubmit(of: .search) {
                    Task { await vm.search() }
                }
                // Clearing the search bar resets results so the view returns to
                // the initial "enter keywords" prompt state.
                .onChange(of: vm.keywords) { _, newValue in
                    if newValue.isEmpty {
                        vm.results    = []
                        vm.hasSearched = false
                        vm.searchError = nil
                    }
                }
                .toolbar {
                    #if !os(iOS)
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "search.done",
                                      defaultValue: "Done")) {
                            dismiss()
                        }
                    }
                    #endif
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            vm.showFilterPanel = true
                        } label: {
                            Image(systemName: vm.hasActiveFilters
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel(
                            String(localized: "search.filters.toggle.a11y",
                                   defaultValue: "Toggle filters")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showTimeline.toggle()
                        } label: {
                            Image(systemName: showTimeline ? "chart.bar.fill" : "chart.bar")
                        }
                        .accessibilityLabel(
                            showTimeline
                                ? String(localized: "search.timeline.hide.a11y",
                                         defaultValue: "Hide timeline")
                                : String(localized: "search.timeline.show.a11y",
                                         defaultValue: "Show timeline")
                        )
                        .disabled(vm.results.isEmpty)
                    }
                    // Save Search / Saved Searches are folded into a single overflow
                    // menu rather than given their own toolbar items. On iPhone these
                    // previously moved to `.bottomBar` to avoid crowding the nav bar
                    // alongside `.searchable` and its Cancel button — but that placed
                    // them in direct z-order conflict with MainTabView's app-level tab
                    // bar, which won and hid them entirely. Consolidating into one
                    // `Menu` keeps everything in the nav bar (no `.bottomBar` anywhere
                    // in this view) while still leaving room for `.searchable`.
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                saveSearchName = vm.keywords.trimmingCharacters(in: .whitespaces)
                                showSaveSearchSheet = true
                            } label: {
                                Label(
                                    String(localized: "search.saveSearch.a11y",
                                           defaultValue: "Save this search"),
                                    systemImage: "bookmark"
                                )
                            }
                            .disabled(!vm.hasSearched)

                            Button {
                                showSavedSearches = true
                            } label: {
                                Label(
                                    String(localized: "search.savedSearches.a11y",
                                           defaultValue: "Saved searches"),
                                    systemImage: "bookmark.fill"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel(
                            String(localized: "search.moreActions.a11y",
                                   defaultValue: "More search actions")
                        )
                    }
                }
                // Advanced filter sheet — iOS uses detents; macOS uses a fixed frame
                // declared inside SearchFilterView.
                .sheet(isPresented: $vm.showFilterPanel) {
                    SearchFilterView(vm: vm)
                        .environment(appState)
                        .modelContainer(modelContext.container)
                }
                .sheet(isPresented: $showSaveSearchSheet) {
                    saveSearchSheet
                }
                .sheet(isPresented: $showSavedSearches) {
                    SavedSearchesView { saved in
                        vm.applyParameters(saved.searchParameters)
                        Task { await vm.search() }
                    }
                    .modelContainer(modelContext.container)
                }
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    #if os(iOS)
                    DocumentView(entry: entry)
                    #else
                    MacDocumentView(entry: entry, navigationPath: .constant([]), highlightCoordinator: HighlightCoordinator())
                    #endif
                }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
        .task {
            if let params = initialParameters {
                vm.applyParameters(params)
            }
            vm.appState = appState
            vm.loadAvailableUserTags(context: modelContext)
            if let pid = appState.activeProjectId {
                let descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.id == pid }
                )
                let project = try? modelContext.fetch(descriptor).first
                vm.applyProjectDefaults(project)
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if vm.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.searchError {
            ContentUnavailableView(
                String(localized: "search.error.title", defaultValue: "Search Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if vm.hasSearched && vm.results.isEmpty {
            ContentUnavailableView(
                String(localized: "search.empty.title", defaultValue: "No Results"),
                systemImage: "magnifyingglass",
                description: Text(String(localized: "search.empty.detail",
                                         defaultValue: "Try different keywords or adjust your filters."))
            )
        } else if !vm.results.isEmpty {
            resultCountHeader
            if showTimeline {
                DocumentTimelineView(
                    items: vm.results.map {
                        DocumentTimelineView.Item(
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            header: $0.header
                        )
                    },
                    onSelect: { item in
                        if let r = vm.results.first(where: {
                            $0.volumeId == item.volumeId && $0.documentId == item.documentId
                        }) {
                            vm.navigationPath.append(vm.makeEntry(from: r))
                        }
                    }
                )
            } else {
                resultsList
            }
        } else {
            // Initial prompt — no search has been performed yet.
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(String(localized: "search.prompt",
                            defaultValue: "Enter keywords to search the FRUS corpus."))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resultCountHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(
                    String(
                        format: String(localized: "search.count %lld",
                                       defaultValue: "%lld results"),
                        Int64(vm.resultCount)
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                Spacer()
            }
            // Over-cap guidance: shown when the result set hit the hard limit, meaning
            // there are likely more matching documents not visible in the list.
            if vm.isResultsCapped {
                Text(String(
                    format: String(localized: "search.capped.guidance %lld",
                                   defaultValue: "Showing the first %lld results — add more keywords or filters to see more specific results."),
                    Int64(SearchViewModel.searchHardLimit)
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)

                // Search → Analytics handoff (Direction B): when the cap is hit,
                // suggest visualising the result distribution over time so the
                // user can pick a date range that narrows the match set, rather
                // than guessing at extra keywords.
                Button {
                    openCappedResultsInAnalytics()
                } label: {
                    Label(
                        String(localized: "search.capped.analytics.button",
                               defaultValue: "Visualize in Corpus Analytics"),
                        systemImage: "chart.bar.xaxis"
                    )
                    .font(.caption2.weight(.medium))
                }
                .buttonStyle(.borderless)
                .padding(.top, 1)
                .help(String(
                    localized: "search.capped.analytics.help",
                    defaultValue: "Open Corpus Analytics charting how often these keywords appear over time, so you can pick a date range that narrows your results"
                ))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    /// Builds an `AnalyticsParameters` snapshot from the current (capped) search
    /// and hands off to Corpus Analytics via `AppState.pendingAnalytics`.
    ///
    /// Carries the submitted keywords as the chart term, and — when an explicit
    /// date filter is active — the filter's start/end years as the chart's
    /// year-range bounds, so the chart opens already focused on the same window
    /// the search was scoped to. `phrase`/`prefixWildcard` are intentionally not
    /// folded in: `CorpusAnalyticsService` charts a single plain-text term, and
    /// `keywords` is the field most search sessions actually populate.
    private func openCappedResultsInAnalytics() {
        let term = vm.keywords.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        var startYear: Int? = nil
        var endYear: Int? = nil
        if vm.dateRangeEnabled {
            let cal = Calendar(identifier: .gregorian)
            startYear = cal.component(.year, from: vm.dateRangeStart)
            endYear   = cal.component(.year, from: vm.dateRangeEnd)
        }
        appState.pendingAnalytics = AnalyticsParameters(
            term: term,
            yearRangeStart: startYear,
            yearRangeEnd: endYear
        )
        #if DEBUG
        print("[SearchView] Over-cap handoff to Analytics — term: \"\(term)\", years: \(String(describing: startYear))–\(String(describing: endYear))")
        #endif
    }

    // MARK: - Save Search Sheet

    private var saveSearchSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "search.saveSearch.section",
                               defaultValue: "Search Name")) {
                    TextField(
                        String(localized: "search.saveSearch.placeholder",
                               defaultValue: "Name"),
                        text: $saveSearchName
                    )
                }
                if !vm.keywords.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section(String(localized: "search.saveSearch.query",
                                   defaultValue: "Query")) {
                        Text(vm.keywords)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "search.saveSearch.title",
                                    defaultValue: "Save Search"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "search.saveSearch.save",
                                  defaultValue: "Save")) {
                        let record = SavedSearch(
                            name: saveSearchName.trimmingCharacters(in: .whitespaces),
                            parameters: vm.searchParameters
                        )
                        modelContext.insert(record)
                        showSaveSearchSheet = false
                    }
                    .disabled(saveSearchName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "search.saveSearch.cancel",
                                  defaultValue: "Cancel")) {
                        showSaveSearchSheet = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 340, minHeight: 180)
        #endif
    }

    private var resultsList: some View {
        List {
            ForEach(vm.results) { result in
                Button {
                    vm.navigationPath.append(vm.makeEntry(from: result))
                } label: {
                    SearchResultRow(
                        result: result,
                        onUserTagTap: { tagId in
                            if let uuid = UUID(uuidString: tagId) {
                                vm.selectedUserTagIds.insert(uuid)
                                Task { await vm.search() }
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(result.header)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult
    let onUserTagTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header + document number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let num = result.documentNumber {
                    Text("\(num).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(result.header)
                    // .headline (17pt semibold) is correct for iOS list rows; on macOS
                    // in the inspector panel .body is more appropriate for the density.
                    #if os(macOS)
                    .font(.body)
                    #else
                    .font(.headline)
                    #endif
                    .lineLimit(2)
            }

            // Dateline
            if let dateline = result.dateline {
                Text(dateline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Volume ID
            Text(result.volumeId)
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Snippet — render <b>…</b> markers as highlighted text
            if !result.snippet.isEmpty {
                SearchSnippetView(snippet: result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 1)
            }

            // User tag chips
            if !result.userTagIds.isEmpty {
                SearchTagChipsRow(
                    tagIds: result.userTagIds,
                    systemImage: "person.crop.circle.badge.plus",
                    onTap: onUserTagTap
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SearchSnippetView

/// Renders an FTS5 snippet where `<b>` / `</b>` delimiters mark matched terms.
///
/// Matched terms are shown in the accent colour with medium weight; the surrounding
/// context text uses the inherited foreground style. Mirrors `SnippetView` in
/// `SearchSheet.swift` (used by the macOS search sheet and iOS search view).
private struct SearchSnippetView: View {
    let snippet: String

    var body: some View {
        (try? AttributedString(styledSnippet(snippet), including: \.swiftUI))
            .map { Text($0) } ?? Text(plainSnippet)
    }

    private var plainSnippet: String {
        snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
    }

    private func styledSnippet(_ raw: String) throws -> AttributedString {
        var result = AttributedString()
        var remainder = raw
        while !remainder.isEmpty {
            if let openRange = remainder.range(of: "<b>"),
               let closeRange = remainder.range(of: "</b>",
                   range: openRange.upperBound..<remainder.endIndex) {
                let before = String(remainder[..<openRange.lowerBound])
                if !before.isEmpty { result += AttributedString(before) }
                let highlighted = String(remainder[openRange.upperBound..<closeRange.lowerBound])
                var span = AttributedString(highlighted)
                span.swiftUI.foregroundColor = .accentColor
                span.swiftUI.font = .caption.weight(.medium)
                result += span
                remainder = String(remainder[closeRange.upperBound...])
            } else {
                result += AttributedString(remainder)
                break
            }
        }
        return result
    }
}

// MARK: - SearchTagChipsRow

private struct SearchTagChipsRow: View {
    let tagIds: [String]
    let systemImage: String
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tagIds, id: \.self) { tagId in
                    Button {
                        onTap(tagId)
                    } label: {
                        Label(tagId, systemImage: systemImage)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "search.tagchip.a11y",
                               defaultValue: "Filter by \(tagId)")
                    )
                }
            }
        }
    }
}
