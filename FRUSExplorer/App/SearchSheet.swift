// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - MacSearchWindowView

/// Full-text search window content for the macOS Search window scene (`"frus.search"`).
///
/// ## Layout (top to bottom)
/// 1. Search input + Tips toggle
/// 2. Scope toggles (Documents · Notes · Summaries · Collections)
/// 3. Filter row (Date · Volume/subseries · Tagged · Advanced…)
/// 4. Document type selector (Both / Primary only / Editorial notes only)
/// 5. Sort bar (result count with page range · page size picker · sort order)
/// 6. Results list (current page of `pagedResults`)
/// 7. Pagination bar (prev · page indicator · next)
/// 8. Tips panel (collapsible)
///
/// ## Persistence
/// Lives in a `Window` scene so state (query, filters, results, page) is retained
/// while the user examines documents in the main window. The window can be resized
/// freely and remains open across navigation.
///
/// ## Navigation
/// Selecting a result sets `AppState.pendingBrowseDocument`, which `MainWindowView`
/// consumes and pushes onto its `NavigationStack`. The search window stays open.
///
/// ## Pending Search
/// `AppState.pendingSearch` (set by "Find all mentions" in `PersonDetailSheet`) is
/// observed here. On change the parameters are applied and a new search fires.
/// `MainWindowView` also observes `pendingSearch` and calls `openWindow(id:)` to
/// ensure the window is open before the parameters arrive.
///
/// ## Advanced Filters
/// Tapping "Advanced…" in the filter row opens `SearchFilterView` as a sheet.
/// On dismiss, `searchVM.applyAdvancedFilters()` copies filter state back into
/// `parameters` and bumps `parametersVersion`, which triggers a new search via
/// `.task(id: searchVM.searchTrigger)`.
///
/// Version history:
///   1.0 — New UI scaffolding (macOS-only; uses MacSearchViewModel)
///   1.1 — Add pagination, page size picker, Advanced Filters sheet, resizable frame
///   1.2 — Converted from sheet to Window scene; removed navigationPath binding and Cancel
///   1.3 — Session 120: result-count label shows true uncapped total; over-cap advisory
///          recommends narrowing by date; result row uses TEI-derived snippet with two
///          full lines of surrounding context (no stemmed-token leakage)
///   1.4 — Session 120: "Find by Citation" button surfaces CitationLookupView in the
///          search window so macOS users have a direct entry point
///   1.5 — Session 121: `.onSubmit` now calls `searchVM.submitSearch()` instead of
///          launching an independent Task; avoids parallel search tasks that caused
///          the "three result sets" cycling bug
struct MacSearchWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var searchVM = MacSearchViewModel()
    @State private var showAdvancedFilters = false
    @State private var showCitationLookup = false
    @State private var showSaveSearchSheet = false
    @State private var showSavedSearches = false
    @State private var saveSearchName = ""

    var body: some View {
        VStack(spacing: 0) {

            searchInputRow
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                scopeRow
                filterRow
                documentTypeRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            sortBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Divider()

            overCapAdvisory

            resultsList

            if searchVM.totalPages > 1 {
                Divider()
                paginationBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            if searchVM.showTips {
                Divider()
                tipsPanel
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 640, idealWidth: 820, maxWidth: .infinity,
               minHeight: 500, idealHeight: 680, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: searchVM.showTips)
        .task(id: searchVM.searchTrigger) {
            await searchVM.performSearch(service: appState.searchService)
        }
        .onChange(of: appState.pendingSearch) { _, params in
            guard let params else { return }
            searchVM.applyParameters(params)
            appState.pendingSearch = nil
        }
        .onChange(of: appState.indexGeneration) { _, _ in
            searchVM.results = []
            searchVM.queryText = ""
        }
        .sheet(isPresented: $showAdvancedFilters,
               onDismiss: { searchVM.applyAdvancedFilters() }) {
            if let filterVM = searchVM.filterVM {
                SearchFilterView(vm: filterVM)
            }
        }
        .sheet(isPresented: $showCitationLookup) {
            CitationLookupView()
        }
        .sheet(isPresented: $showSaveSearchSheet) {
            saveSearchSheet
                .modelContainer(modelContext.container)
        }
        .sheet(isPresented: $showSavedSearches) {
            SavedSearchesView { saved in
                searchVM.applyParameters(saved.searchParameters)
                Task { await searchVM.performSearch(service: appState.searchService) }
            }
            .modelContainer(modelContext.container)
        }
    }

    // MARK: - Search Input Row

    private var searchInputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)

                TextField("Search documents, notes, summaries…", text: $searchVM.queryText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { searchVM.submitSearch() }

                if !searchVM.queryText.isEmpty {
                    Button {
                        searchVM.queryText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(String(
                        localized: "search.field.clear.help",
                        defaultValue: "Clear search field"
                    ))
                    .accessibilityLabel(String(
                        localized: "search.field.clear.a11y",
                        defaultValue: "Clear search"
                    ))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )

            Button {
                searchVM.showTips.toggle()
            } label: {
                Label("Tips", systemImage: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(searchVM.showTips ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(String(
                localized: "search.tips.help",
                defaultValue: "Show or hide search-syntax tips: quoted phrases, OR, exclusion, date filters, and stemming"
            ))

            Button {
                showCitationLookup = true
            } label: {
                Label(
                    String(localized: "search.citationLookup.button",
                           defaultValue: "Find by Citation"),
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help(String(
                localized: "search.citationLookup.help",
                defaultValue: "Resolve a pasted or manually entered FRUS citation to a specific document"
            ))

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            // Save this search
            Button {
                saveSearchName = searchVM.submittedQuery.trimmingCharacters(in: .whitespaces)
                showSaveSearchSheet = true
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.submittedQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            .help(String(
                localized: "search.saveSearch.help",
                defaultValue: "Save this search so you can quickly run it again"
            ))
            .accessibilityLabel(String(
                localized: "search.saveSearch.a11y",
                defaultValue: "Save this search"
            ))

            // Open saved searches
            Button {
                showSavedSearches = true
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .help(String(
                localized: "search.savedSearches.help",
                defaultValue: "Browse and re-run your saved searches"
            ))
            .accessibilityLabel(String(
                localized: "search.savedSearches.a11y",
                defaultValue: "Saved searches"
            ))
        }
    }

    // MARK: - Save Search Sheet

    /// macOS-native save-search dialog.
    ///
    /// Uses a `VStack` layout rather than `NavigationStack { Form }` — a
    /// `NavigationStack` inside a sheet adds a 44 pt navigation bar and toolbar
    /// chrome that is inappropriate for a two-field confirmation dialog on macOS.
    /// The native macOS pattern is a content area with `LabeledContent` rows
    /// and a `Divider`-separated button bar (Cancel left, default action right).
    private var saveSearchSheet: some View {
        VStack(spacing: 0) {

            // Content
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "search.saveSearch.title",
                            defaultValue: "Save Search"))
                    .font(.headline)

                LabeledContent(String(localized: "search.saveSearch.section",
                                      defaultValue: "Name")) {
                    TextField(
                        String(localized: "search.saveSearch.placeholder",
                               defaultValue: "Name this search"),
                        text: $saveSearchName
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSave() }
                }

                LabeledContent(String(localized: "search.saveSearch.query",
                                      defaultValue: "Query")) {
                    Text(searchVM.submittedQuery)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)

            Divider()

            // Button bar — Cancel left, Save right (standard macOS dialog layout)
            HStack {
                Button(String(localized: "search.saveSearch.cancel",
                              defaultValue: "Cancel")) {
                    showSaveSearchSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "search.saveSearch.save",
                              defaultValue: "Save")) {
                    performSave()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(saveSearchName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 360, idealWidth: 400, minHeight: 180, idealHeight: 200)
    }

    /// Persists the current search with the entered name and dismisses the sheet.
    private func performSave() {
        let name = saveSearchName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Merge the submitted query text into the parameters snapshot before
        // persisting — MacSearchViewModel tracks keywords separately in `submittedQuery`.
        var paramsToSave = searchVM.parameters
        let kw = searchVM.submittedQuery.trimmingCharacters(in: .whitespaces)
        paramsToSave.keywords = kw.isEmpty ? nil : kw
        let record = SavedSearch(name: name, parameters: paramsToSave)
        modelContext.insert(record)
        showSaveSearchSheet = false
    }

    // MARK: - Scope Row

    private var scopeRow: some View {
        HStack(spacing: 6) {
            Text("Search in")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            ScopeChip(label: "Documents",   isOn: $searchVM.scopeDocuments)
                .help(String(
                    localized: "search.scope.documents.help",
                    defaultValue: "Search the full text of FRUS documents (header, dateline, source note, body)"
                ))
            ScopeChip(label: "Notes",       isOn: $searchVM.scopeNotes)
                .help(String(
                    localized: "search.scope.notes.help",
                    defaultValue: "Search the body text of your research notes"
                ))
            ScopeChip(label: "Summaries",   isOn: $searchVM.scopeSummaries)
                .help(String(
                    localized: "search.scope.summaries.help",
                    defaultValue: "Search the text of generated AI summaries"
                ))
            ScopeChip(label: "Collections", isOn: $searchVM.scopeCollections)
                .help(String(
                    localized: "search.scope.collections.help",
                    defaultValue: "Search collection names and notes (deferred — not yet wired)"
                ))
        }
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 8) {
            FilterChip(
                label: "Date",
                value: searchVM.dateRangeLabel,
                isActive: searchVM.parameters.dateRange != nil
            ) { searchVM.clearDateFilter() }
            .help(String(
                localized: "search.filter.date.help",
                defaultValue: "Date-range filter (TEI document dates). Tap × to clear."
            ))

            Divider().frame(height: 16)

            FilterChip(
                label: "Volume / subseries",
                value: searchVM.volumeFilterLabel,
                isActive: searchVM.parameters.volumeIds != nil
            ) { searchVM.clearVolumeFilter() }
            .help(String(
                localized: "search.filter.volume.help",
                defaultValue: "Volume or subseries filter. Tap × to clear."
            ))

            Divider().frame(height: 16)

            FilterChip(
                label: "Tagged",
                value: searchVM.tagFilterLabel,
                isActive: !searchVM.parameters.userTagIds.isEmpty
            ) { searchVM.clearTagFilter() }
            .help(String(
                localized: "search.filter.tags.help",
                defaultValue: "User-tag filter. Tap × to clear."
            ))

            Divider().frame(height: 16)

            Button {
                searchVM.syncToFilterVM(searchService: appState.searchService)
                showAdvancedFilters = true
            } label: {
                HStack(spacing: 3) {
                    if searchVM.activeFilterSummary != nil {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text("Advanced…")
                        .font(.system(size: 11))
                        .foregroundStyle(searchVM.activeFilterSummary != nil
                            ? Color.accentColor : Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open advanced search filters")
            .help(String(
                localized: "search.filter.advanced.help",
                defaultValue: "Open advanced filters — phrase search, boolean mode, prefix wildcard, excluded terms, person reference"
            ))
        }
    }

    // MARK: - Document Type Row

    private var documentTypeRow: some View {
        HStack(spacing: 6) {
            Text("Type")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            ForEach(DocumentTypeFilter.searchUIOptions, id: \.label) { option in
                Button {
                    searchVM.setDocumentTypeFilter(option.filter)
                } label: {
                    Text(option.label)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            searchVM.parameters.documentTypeFilter == option.filter
                                ? Color.green.opacity(0.15)
                                : Color.secondary.opacity(0.08)
                        )
                        .foregroundStyle(
                            searchVM.parameters.documentTypeFilter == option.filter
                                ? Color.green : Color.secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    searchVM.parameters.documentTypeFilter == option.filter
                                        ? Color.green.opacity(0.4)
                                        : Color.secondary.opacity(0.2),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
                .help(documentTypeHelpText(for: option.filter))
            }
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            if searchVM.isSearching {
                ProgressView().controlSize(.small)
                Text("Searching…").font(.system(size: 11)).foregroundStyle(.secondary)
            } else if !searchVM.queryText.isEmpty {
                resultCountLabel
            }

            Spacer()

            pageSizePicker

            Divider().frame(height: 14)

            HStack(spacing: 4) {
                Text("Sort").font(.system(size: 11)).foregroundStyle(.tertiary)

                ForEach(SearchSortOrder.allCases, id: \.self) { order in
                    Button {
                        searchVM.sortOrder = order
                    } label: {
                        Text(order.label)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                searchVM.sortOrder == order
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                searchVM.sortOrder == order ? Color.accentColor : Color.secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(
                                        searchVM.sortOrder == order
                                            ? Color.accentColor.opacity(0.3)
                                            : Color.secondary.opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(sortOrderHelpText(for: order))
                }
            }
        }
    }

    @ViewBuilder
    private var resultCountLabel: some View {
        // `loaded` = how many results are materialised on the client (capped at
        // `MacSearchViewModel.searchHardLimit`).
        // `total`  = the true uncapped match count returned by FTS5 COUNT(*).
        let loaded   = searchVM.results.count
        let total    = max(searchVM.totalMatchCount, loaded)
        let start    = searchVM.currentPage * searchVM.pageSize + 1
        let end      = min(start + searchVM.pageSize - 1, loaded)
        let truncated = searchVM.isResultSetTruncated

        HStack(spacing: 6) {
            if loaded == 0 {
                Text("No results")
                    .font(.system(size: 11, weight: .medium))
            } else if loaded <= searchVM.pageSize {
                Text("\(loaded) of \(total.formatted()) result\(total == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text("\(start)–\(end) of \(loaded.formatted()) loaded · \(total.formatted()) total")
                    .font(.system(size: 11, weight: .medium))
            }

            if truncated {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .help(
                        String(
                            localized: "search.cap.tooltip",
                            defaultValue:
                                "Showing \(loaded.formatted()) of \(total.formatted()) matches. Narrow your search with a date range, volume filter, or more specific terms to see every result."
                        )
                    )
            }
        }
    }

    /// Advisory banner shown directly below the results header when the underlying
    /// match count exceeds what was loaded (capped at `searchHardLimit`).
    ///
    /// Encourages the user to constrain with date filters rather than scrolling
    /// through a partial set unknowingly.
    @ViewBuilder
    private var overCapAdvisory: some View {
        if searchVM.isResultSetTruncated {
            let loaded = searchVM.results.count.formatted()
            let total  = searchVM.totalMatchCount.formatted()
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Showing \(loaded) of \(total) matches")
                        .font(.system(size: 11, weight: .medium))
                    Text("Narrow your search with a date range, volume filter, or more specific terms to load every match.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private var pageSizePicker: some View {
        HStack(spacing: 4) {
            Text("Show")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Menu {
                ForEach(MacSearchViewModel.pageSizeOptions, id: \.self) { size in
                    Button("\(size)") { searchVM.pageSize = size }
                }
            } label: {
                Text("\(searchVM.pageSize)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(String(
                localized: "search.pageSize.help",
                defaultValue: "Choose how many results to display per page"
            ))
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(searchVM.pagedResults, id: \.id) { result in
            SearchResultRow(result: result)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.visible, edges: .bottom)
                .contentShape(Rectangle())
                .onTapGesture { navigateToResult(result) }
                .contextMenu {
                    Button("Open in new window") {
                        // openWindow API — deferred to future session
                    }
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button {
                if searchVM.currentPage > 0 { searchVM.currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(searchVM.currentPage == 0)
            .help(String(
                localized: "search.pagination.previous.help",
                defaultValue: "Previous page of results"
            ))
            .accessibilityLabel(String(
                localized: "search.pagination.previous.a11y",
                defaultValue: "Previous page"
            ))

            Text("Page \(searchVM.currentPage + 1) of \(searchVM.totalPages)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                if searchVM.currentPage < searchVM.totalPages - 1 {
                    searchVM.currentPage += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(searchVM.currentPage >= searchVM.totalPages - 1)
            .help(String(
                localized: "search.pagination.next.help",
                defaultValue: "Next page of results"
            ))
            .accessibilityLabel(String(
                localized: "search.pagination.next.a11y",
                defaultValue: "Next page"
            ))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tips Panel

    private var tipsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search tips")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.7)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 6) {
                TipItem(code: "\"exact phrase\"",    description: "match words in order")
                TipItem(code: "Rusk OR Bundy",       description: "either term")
                TipItem(code: "blockade -quarantine", description: "exclude a term")
                TipItem(code: nil, description: "Date filter uses TEI <date @when> — only dated documents match")
                TipItem(code: nil, description: "Person filter searches indexed <persName> mentions across volumes")
                TipItem(code: nil, description: "Scope toggles persist across sessions; adjust in Settings")
            }
        }
    }

    // MARK: - Tooltip Helpers

    private func documentTypeHelpText(for filter: DocumentTypeFilter) -> String {
        switch filter {
        case .all:
            return String(localized: "search.docType.both.help",
                          defaultValue: "Include both primary-source documents and editorial notes in results")
        case .documentsOnly:
            return String(localized: "search.docType.documents.help",
                          defaultValue: "Restrict results to numbered primary-source documents only")
        case .editorialNotesOnly:
            return String(localized: "search.docType.editorialNotes.help",
                          defaultValue: "Restrict results to FRUS editorial notes only")
        }
    }

    private func sortOrderHelpText(for order: SearchSortOrder) -> String {
        switch order {
        case .relevance:
            return String(localized: "search.sort.relevance.help",
                          defaultValue: "Sort results by BM25 relevance — best matches first")
        case .dateAscending:
            return String(localized: "search.sort.dateAsc.help",
                          defaultValue: "Sort by document date, oldest first. Undated documents go to the end.")
        case .dateDescending:
            return String(localized: "search.sort.dateDesc.help",
                          defaultValue: "Sort by document date, most recent first. Undated documents go to the end.")
        }
    }

    // MARK: - Actions

    private func navigateToResult(_ result: SearchResult) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        )
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(result.volumeId) · Doc \(result.documentNumber ?? result.documentId)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                if result.isEditorialNote {
                    Text("editorial note")
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                if let dateline = result.dateline {
                    Text(dateline)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Text(result.header)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            // TEI-derived snippet (~400 chars of surrounding context). `lineLimit(4)`
            // shows ≥2 full lines on the typical Search window width; readers see
            // enough sentence context to judge relevance without opening the document.
            SnippetView(snippet: result.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if !result.userTagIds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(result.userTagIds.prefix(3), id: \.self) { tag in
                        Text("◆ \(tag)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.08))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }
}

// MARK: - SnippetView

/// Renders an FTS5 snippet string where `<b>` / `</b>` delimiters mark matched terms.
///
/// Uses `Text(AttributedString)` directly — avoids the throwing
/// `AttributedString.init(_:including:)` scope-filter initializer, which silently
/// fails on macOS when attribute scopes are mixed (AppKit vs SwiftUI), causing the
/// raw `<b>word</b>` fallback to render.
private struct SnippetView: View {
    let snippet: String

    var body: some View {
        Text(styledSnippet(snippet))
    }

    private func styledSnippet(_ raw: String) -> AttributedString {
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
                span.swiftUI.foregroundColor = Color.yellow
                span.swiftUI.font = .system(size: 12, weight: .medium)
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

// MARK: - Scope Chip

private struct ScopeChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isOn ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let value: String?
    let isActive: Bool
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.tertiary)

            if isActive, let value {
                HStack(spacing: 3) {
                    Text(value).font(.system(size: 11)).foregroundStyle(Color.accentColor)
                    Button { onClear() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help(String(
                        localized: "search.filter.chip.clear.help",
                        defaultValue: "Clear this filter"
                    ))
                    .accessibilityLabel(String(
                        localized: "search.filter.chip.clear.a11y",
                        defaultValue: "Clear filter"
                    ))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                )
            } else {
                Text("any")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .italic()
            }
        }
    }
}

// MARK: - Tip Item

private struct TipItem: View {
    let code: String?
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if let code {
                Text(code)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .foregroundStyle(.secondary)
                Text("—").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Text(description).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - DocumentTypeFilter helpers

extension DocumentTypeFilter {
    struct UIOption {
        let label: String
        let filter: DocumentTypeFilter
    }
    static let searchUIOptions: [UIOption] = [
        UIOption(label: "Both",              filter: .all),
        UIOption(label: "Primary documents", filter: .documentsOnly),
        UIOption(label: "Editorial notes",   filter: .editorialNotesOnly),
    ]
}

#endif // os(macOS)
