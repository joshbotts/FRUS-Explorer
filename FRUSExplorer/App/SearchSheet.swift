// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftData
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
/// Selecting a result sets `AppState.pendingBrowseDocument`, which every document host routes to the active window
/// (`routeBrowseToActiveHost`) so it opens where the user launched the search. The search window stays open.
///
/// ## Pending Search
/// `AppState.pendingSearch` (set by "Find all mentions" in `PersonDetailSheet`) is
/// observed here. On change the parameters are applied and a new search fires.
/// `MainWindowView` also observes `pendingSearch` and calls `openWindow(id:)` to
/// ensure the window is open before the parameters arrive.
///
/// ## Advanced Filters
/// Tapping "Advanced…" in the filter row opens `SearchFilterView` in a popover
/// anchored to the button (UI audit C4). Filters apply **live**: an `.onChange`
/// on `filterVM.advancedFilterSignature` calls `searchVM.applyAdvancedFilters()`
/// per edit, which copies filter state into `parameters` and bumps
/// `parametersVersion`, re-running the search via `.task(id: searchVM.searchTrigger)`
/// while the result list stays visible behind the popover.
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
///   1.6 — Session 2026-06-07: over-cap advisory gains a "Visualize in Corpus
///          Analytics" button — hands submittedQuery + active date filter off to
///          `AnalyticsView` via `AppState.pendingAnalytics` (see `AnalyticsParameters`)
///   1.7 — Session 2026-06-07: each completed search now records a
///          `SearchHistoryEntry` (`searchVM.recordSearchHistory`), surfaced in
///          the new macOS "History" menu and "Complete History" window
///   1.8 — Session 2026-06-07: timeline toggle added to the sort bar — swaps
///          the results list/pagination for `DocumentTimelineView` (the same
///          Swift Charts visualization already used on iOS Search and in the
///          Collections editor), bringing chronological browsing to macOS
///   1.9 — Fix: added `.task` (no id) to consume `AppState.pendingSearch` on
///          initial window load. The existing `.onChange` only fires on value
///          *changes*; when the window is newly opened after `pendingSearch` is
///          already set, the new view's `.onChange` never fires for that value.
///   1.10 — Session 159: result row context menu gained a working "Open in New
///          Window" (was a deferred stub) that opens the document in its own
///          `DocumentWindowID` window via `openWindow`; macOS shows it as a tab or
///          a separate window per the user's "Prefer tabs" setting since document
///          windows share a `WindowGroup`. Default click still opens in the main
///          window (`navigateToResult` → `pendingBrowseDocument`).
///   1.11 — Session 2026-07-04 (Source Explorer Phase 5 S6): the result row's
///          "Archival Neighbors…" action opens the value-based Archival Neighbors
///          window (`openWindow(value: ArchivalNeighborsRequest.document…)`) instead
///          of a sheet, so the neighbors list survives row navigation; the
///          `archivalNeighborsTarget` state and its `.sheet` were removed
///   1.12 — Session 2026-07-04 (macOS UI audit B4): "Find by Citation" opens the
///          frus.citationLookup window (⌘⇧F, the sibling find flow) instead of a
///          sheet; the `showCitationLookup` state and its `.sheet` were removed
///   1.13 — Session 2026-07-04 (macOS UI audit C4): advanced filters became a live
///          popover anchored to the "Advanced…" button — edits apply immediately
///          via `.onChange(of: filterVM.advancedFilterSignature)`; the modal sheet
///          and its `onDismiss` batch `applyAdvancedFilters()` call were removed
///   1.14 — Session 2026-07-04 (macOS UI audit A7): result rows are keyboard-
///          navigable — the results List gained selection (`selectedResultId`),
///          so ↑/↓ traverse rows natively and ↩ opens the selected result; a row
///          click now also selects it (so arrow keys continue from the row the
///          user last opened), preserving the click-to-open behavior
struct MacSearchWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @State private var searchVM = MacSearchViewModel()
    @State private var showAdvancedFilters = false
    @State private var showTimeline = false
    @State private var showSaveSearchSheet = false
    @State private var showSavedSearches = false
    @State private var saveSearchName = ""
    /// The result row selected in the results List (UI audit A7): gives the list
    /// native ↑/↓ keyboard traversal, and ↩ opens the selected result. A stale id
    /// (after a new search or page change) simply matches no row. Never persisted.
    @State private var selectedResultId: SearchResult.ID? = nil

    /// All user tags fetched from SwiftData. Passed to `SearchResultRow` so tag UUID
    /// strings in results can be resolved to human-readable names.
    @Query private var allUserTags: [UserTag]

    var body: some View {
        VStack(spacing: 0) {

            // Checklist mode (#189-D): a zero-size, always-mounted observer keeps the reviewed
            // set in sync with the reading history via a live `@Query`, so opening a result by
            // any means (main window, new window, timeline) hides it. Re-created via `.id` when
            // the anchor moves (mode re-enable or a new search).
            if searchVM.checklistMode, let enabledAt = searchVM.checklistEnabledAt {
                ChecklistReviewedObserver(enabledAt: enabledAt) { keys in
                    searchVM.readSinceEnabledKeys = keys
                }
                .id(enabledAt)
            }

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

            checklistHiddenBanner

            if searchVM.checklistMode && searchVM.displayedResults.isEmpty && !searchVM.results.isEmpty {
                // Checklist mode has hidden every result (#189-D).
                allReviewedEmptyState
            } else if showTimeline {
                timelineView
            } else {
                resultsList

                if searchVM.totalPages > 1 {
                    Divider()
                    paginationBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
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
            searchVM.recordSearchHistory(projectId: appState.activeProjectId, in: modelContext)
        }
        .task {
            // Consume search parameters set *before* this window was opened.
            // `.onChange` only fires on subsequent value changes — it misses the
            // initial `pendingSearch` that was already set when the Window scene
            // created a fresh `MacSearchWindowView` instance.
            if let params = appState.pendingSearch {
                searchVM.applyParameters(params)
                appState.pendingSearch = nil
            }
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
                // B4: Citation Lookup is its own window (⌘⇧F) — the sibling find
                // flow to this Search window (⌘F).
                openWindow(id: "frus.citationLookup")
                bringMacWindowToFront(id: "frus.citationLookup")
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

                // #258 Q4(a): SavedSearch persists no volume scope; disclose instead of
                // dropping silently. Required on BOTH save sheets by the reviewed design
                // (SS8-Q4) — the pre-merge review caught this one missing.
                if !(searchVM.filterVM?.effectiveVolumeIds.isEmpty ?? true) {
                    Label(String(localized: "search.saveSearch.scopeNotSaved",
                                 defaultValue: "The volume scope is not saved with the search — re-apply it after running the saved search."),
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                searchVM.syncToFilterVM(
                    searchService: appState.searchService,
                    volumeEntries: appState.manifestStore.diffResult?.known
                        ?? appState.manifestStore.bundledEntries,
                    indexedVolumeIds: appState.indexedVolumeIds,
                    userTags: allUserTags
                )
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
                defaultValue: "Open advanced filters — date range, volume scope, document type, person, search scope. Changes apply immediately."
            ))
            // Live filter popover (UI audit C4): anchored to the button so the
            // result list stays visible while filtering — the modal sheet this
            // replaces hid the very results being narrowed. Edits apply
            // immediately via the `advancedFilterSignature` observation below;
            // there is no dismiss-time batch.
            .popover(isPresented: $showAdvancedFilters, arrowEdge: .bottom) {
                if let filterVM = searchVM.filterVM {
                    SearchFilterView(vm: filterVM)
                        .frame(width: 480, height: 560)
                        .onChange(of: filterVM.advancedFilterSignature) { _, _ in
                            searchVM.applyAdvancedFilters()
                        }
                }
            }
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

            // Checklist review mode (#189-D) — a self-labeling icon+text control (#218) so it
            // reads as "Checklist" without hovering, instead of a bare icon discoverable only by
            // tooltip. Hides results as they're reviewed (opened by any means, or marked via the
            // row context menu), turning a long result set into a shrinking to-do list. Disabled
            // until there are results; stays enabled in the all-reviewed state (gated on raw
            // `results`) so the user can always turn it back off.
            Button {
                searchVM.setChecklistMode(!searchVM.checklistMode)
            } label: {
                Label(String(localized: "search.checklist.short", defaultValue: "Checklist"),
                      systemImage: "checklist")
                    .font(.system(size: 12))
                    .foregroundStyle(searchVM.checklistMode ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
                    .fixedSize()  // keep the label intact; the flexible result-count text absorbs
                                  // any compression in the dense sort bar at minimum window width
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            .help(searchVM.checklistMode
                  ? String(localized: "search.checklist.off.help",
                           defaultValue: "Turn off Checklist Mode and show every result")
                  : String(localized: "search.checklist.on.help",
                           defaultValue: "Checklist review mode — hide results as you review them"))
            .accessibilityLabel(String(localized: "search.checklist.toggle", defaultValue: "Checklist Mode"))
            .accessibilityValue(searchVM.checklistMode
                                ? String(localized: "search.checklist.state.on", defaultValue: "On")
                                : String(localized: "search.checklist.state.off", defaultValue: "Off"))

            Divider().frame(height: 14)

            // Timeline toggle — swaps the results list/pagination for a
            // chronological Swift Charts visualization (DocumentTimelineView,
            // shared with the iOS Search tab and Collections editor). Mirrors
            // the toggle in SearchView.swift so the feature reaches macOS too.
            Button {
                showTimeline.toggle()
            } label: {
                Image(systemName: showTimeline ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            .help(showTimeline
                  ? String(localized: "search.timeline.hide.help",
                           defaultValue: "Hide the chronological timeline and show the results list")
                  : String(localized: "search.timeline.show.help",
                           defaultValue: "Show these results as a chronological timeline"))
            .accessibilityLabel(showTimeline
                ? String(localized: "search.timeline.hide.a11y", defaultValue: "Hide timeline")
                : String(localized: "search.timeline.show.a11y", defaultValue: "Show timeline"))

            Divider().frame(height: 14)

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
        // `loaded` = how many results are currently shown — the checklist-filtered count
        // (#189-D) when checklist mode is on, else the materialised set (capped at
        // `MacSearchViewModel.searchHardLimit`). The paging math below pages over the same
        // `displayedResults`, so the start–end range and page count stay in sync.
        // `total`  = the true uncapped match count returned by FTS5 COUNT(*) (unaffected by
        // the client-side reviewed filter, so the over-cap advisory still reflects the raw fetch).
        let loaded   = searchVM.displayedResults.count
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

            // Search → Analytics handoff (Direction B): available for any keyword
            // search, not only over-cap ones, so the user can always chart the term's
            // distribution over time.
            if loaded > 0, !searchVM.submittedQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer(minLength: 8)
                Button {
                    openSearchInAnalytics()
                } label: {
                    Label("Visualize in Corpus Analytics", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help(String(localized: "search.analytics.help",
                             defaultValue: "Open Corpus Analytics charting how often these keywords appear over time"))
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
                // The "Visualize in Corpus Analytics" handoff now lives in the result-count
                // header (available for every keyword search, not only over-cap ones).
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    /// A subtle banner shown while checklist mode is on and at least one result is hidden, so the
    /// shrunken list never reads as a bug (#189-D).
    @ViewBuilder
    private var checklistHiddenBanner: some View {
        if searchVM.checklistMode {
            let hidden = searchVM.results.count - searchVM.displayedResults.count
            if hidden > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(String(format: String(localized: "search.checklist.hiddenBanner %lld",
                                              defaultValue: "%lld reviewed hidden"), Int64(hidden)))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }

    /// Shown in place of the results list/timeline when checklist mode has hidden every result
    /// (#189-D).
    private var allReviewedEmptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "search.checklist.allReviewed.title",
                         defaultValue: "All Results Reviewed"),
                  systemImage: "checkmark.circle")
        } description: {
            Text(String(localized: "search.checklist.allReviewed.detail",
                        defaultValue: "You've reviewed every result. Turn off Checklist Mode to see them again."))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Chronological visualization of the current result set, shown in place
    /// of `resultsList`/`paginationBar` when `showTimeline` is enabled.
    /// Reuses `DocumentTimelineView` (Search/DocumentTimelineView.swift) —
    /// the same Swift Charts component already wired into the iOS Search tab
    /// and the Collections editor — so chart/list display modes, year
    /// grouping, and undated-document handling all come for free.
    private var timelineView: some View {
        DocumentTimelineView(
            // Page over the checklist-filtered set (#189-D) so reviewed documents drop out of
            // the timeline just as they do from the list.
            items: searchVM.displayedResults.map {
                DocumentTimelineView.Item(
                    volumeId: $0.volumeId,
                    documentId: $0.documentId,
                    header: $0.header
                )
            },
            onSelect: { item in
                if let result = searchVM.displayedResults.first(where: {
                    $0.volumeId == item.volumeId && $0.documentId == item.documentId
                }) {
                    navigateToResult(result)
                }
            }
        )
    }

    private var resultsList: some View {
        // Selection (UI audit A7) gives the NSTableView-backed List its native
        // arrow-key traversal once focus is in the list (click a row or Tab to it);
        // ↩ opens the selected row via `.onKeyPress` below. The tap gesture keeps
        // the long-standing click-to-open behavior AND records the row as selected,
        // so ↑/↓ continue from the result the user last opened.
        List(searchVM.pagedResults, id: \.id, selection: $selectedResultId) { result in
            SearchResultRow(result: result, userTags: allUserTags)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.visible, edges: .bottom)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedResultId = result.id
                    navigateToResult(result)
                }
                .contextMenu {
                    // Default click opens in the main window (navigateToResult →
                    // pendingBrowseDocument); offered explicitly here too.
                    Button {
                        navigateToResult(result)
                    } label: {
                        Label(
                            String(localized: "search.result.open",
                                   defaultValue: "Open"),
                            systemImage: "arrow.up.right.square"
                        )
                    }
                    Button {
                        openResultInNewWindow(result)
                    } label: {
                        Label(
                            String(localized: "search.result.openNewWindow",
                                   defaultValue: "Open in New Window"),
                            systemImage: "macwindow.on.rectangle"
                        )
                    }
                    Button {
                        // S6: Archival Neighbors opens in its own window so the
                        // result list survives every row navigation.
                        openWindow(value: ArchivalNeighborsRequest.document(
                            volumeId:     result.volumeId,
                            documentId:   result.documentId,
                            documentYear: result.dateISO.flatMap { Int($0.prefix(4)) }
                        ))
                    } label: {
                        Label(
                            String(localized: "search.result.archivalNeighbors",
                                   defaultValue: "Archival Neighbors…"),
                            systemImage: "archivebox"
                        )
                    }

                    // Checklist mode (#189-D): mark a result reviewed — hides it without
                    // opening it. Offered only while checklist mode is on. (macOS uses the
                    // context menu; the iOS row also offers a swipe action.)
                    if searchVM.checklistMode {
                        Divider()
                        Button {
                            searchVM.markReviewed(volumeId: result.volumeId, documentId: result.documentId)
                        } label: {
                            Label(
                                String(localized: "search.checklist.markReviewed",
                                       defaultValue: "Mark Reviewed"),
                                systemImage: "checklist"
                            )
                        }
                    }
                }
        }
        .listStyle(.plain)
        // ↩ opens the selected result (A7) — same navigation as a row click. Fires
        // only while focus is inside the List, so the search field's own Return
        // (`.onSubmit` → submitSearch) is untouched; `.ignored` hands anything
        // else back to the system.
        .onKeyPress(.return) {
            guard let id = selectedResultId,
                  let result = searchVM.pagedResults.first(where: { $0.id == id })
            else { return .ignored }
            navigateToResult(result)
            return .handled
        }
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

            // NOTE: as of Session 2026-06-08 the main search field genuinely parses
            // Google-style inline syntax via FTS5InlineQueryParser — quotes, OR, NOT,
            // a leading "-", a trailing "*", and now "(...)" grouping are real operators
            // here, not literal characters. (Previously they were stripped/mangled by a
            // naive whitespace split — see FTS5InlineQueryParser's doc comment for that
            // bug's history; this tips panel used to warn users away from typing this
            // syntax for exactly that reason.) The dedicated Phrase / Keyword-mode /
            // Excluded-terms / Prefix-wildcard fields were removed from Advanced Filters
            // the same session — everything they did is now expressible inline, with
            // strictly more power (mixed AND/OR/NOT/grouping per query, not one global mode).
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 6) {
                TipItem(code: "\"exact phrase\"", description: "match these words in this exact order")
                TipItem(code: "term1 OR term2",   description: "match either term (capital OR — lowercase \"or\" is a literal word)")
                TipItem(code: "-word",            description: "exclude documents containing this word (also: capital NOT)")
                TipItem(code: "term*",            description: "prefix wildcard — \"negoti*\" matches negotiate, negotiations, …")
                TipItem(code: "(a OR b) (c OR d)", description: "group terms — each group must match (capital OR inside parens)")
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

    /// Builds an `AnalyticsParameters` snapshot from the current search and hands off
    /// to Corpus Analytics via `AppState.pendingAnalytics`. Available for any keyword
    /// search (not only over-cap ones).
    ///
    /// Carries `submittedQuery` as the chart term and — when `parameters.dateRange`
    /// is set — its `earliest`/`latest` ISO years as the chart's year-range bounds,
    /// so the chart opens already focused on the same window the search was scoped
    /// to. `MainWindowView` observes `pendingAnalytics` and opens `frus.analytics`;
    /// `AnalyticsView` applies the parameters and runs the chart query immediately.
    private func openSearchInAnalytics() {
        let term = searchVM.submittedQuery.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        appState.pendingAnalytics = AnalyticsParameters(
            term: term,
            yearRangeStart: searchVM.parameters.dateRange?.earliest.flatMap(Self.isoYear),
            yearRangeEnd: searchVM.parameters.dateRange?.latest.flatMap(Self.isoYear)
        )
    }

    /// Extracts the four-digit year from an ISO `yyyy-MM-dd` date string, as
    /// stored in `DateRange.earliest`/`latest`. Returns `nil` for malformed input.
    private static func isoYear(_ isoDate: String) -> Int? {
        Int(isoDate.prefix(4))
    }

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

    /// Opens the result in its own document window, leaving the Search window and
    /// the main window untouched (so the results list stays put). macOS shows it as
    /// a tab or a separate window per the user's "Prefer tabs when opening documents"
    /// setting (System Settings ▸ Desktop & Dock) — document windows share one
    /// `WindowGroup`, so they tab together. Per-document identity means reopening the
    /// same document focuses its existing window/tab.
    private func openResultInNewWindow(_ result: SearchResult) {
        openWindow(value: DocumentWindowID(
            volumeId: result.volumeId,
            documentId: result.documentId,
            header: result.header
        ))
    }
}

// MARK: - ChecklistReviewedObserver

/// A zero-size, always-mounted observer that keeps `MacSearchViewModel.readSinceEnabledKeys` in
/// sync with the local reading history while checklist mode is on (#189-D). Backed by a live
/// `@Query`, so a document opened by *any* means — the main window, a new tab/window, or from
/// the timeline — updates the reviewed set the moment its `ReadingHistoryEntry` lands, with no
/// fragile navigation triggers. Re-created (via `.id(enabledAt)`) whenever the anchor moves
/// (mode re-enable or a new search). Mirrors the iOS observer in `SearchView.swift`.
private struct ChecklistReviewedObserver: View {

    /// Pushes the freshly-computed reviewed keys up to the view model.
    private let onKeys: (Set<String>) -> Void

    /// Documents opened at or after the checklist anchor. `accessedAt` is optional, so the
    /// predicate uses `flatMap`; `nil`-dated rows are excluded (correct for a "since" query).
    @Query private var entries: [ReadingHistoryEntry]

    init(enabledAt: Date, onKeys: @escaping (Set<String>) -> Void) {
        self.onKeys = onKeys
        _entries = Query(filter: #Predicate<ReadingHistoryEntry> { entry in
            (entry.accessedAt.flatMap { $0 >= enabledAt }) == true
        })
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { push() }
            .onChange(of: reviewedKeys) { _, _ in push() }
    }

    /// The reviewed keys derived from the current query rows.
    private var reviewedKeys: [String] {
        entries.map { MacSearchViewModel.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId) }
    }

    private func push() { onKeys(Set(reviewedKeys)) }
}

// MARK: - SearchResultRow

/// A single search-result row for the macOS Search window.
///
/// `userTags` resolves UUID strings in `result.userTagIds` to human-readable
/// tag names. Supplied by the parent `MacSearchWindowView` via its `@Query`.
private struct SearchResultRow: View {
    let result: SearchResult
    /// All known user tags, supplied by the parent view's `@Query`. Used to
    /// resolve UUID strings in `result.userTagIds` to display names.
    let userTags: [UserTag]

    /// Global default snippet length and this window's per-surface override (#189-C); observed so
    /// the row re-renders live when either is changed in Settings or the search filter popover's
    /// Result Preview control. The override writes the same key the filter popover binds to
    /// (`snippetLineCountMainOverrideKey`), bringing the macOS Search window to iOS parity.
    @AppStorage(SearchDefaults.snippetLineCountKey) private var globalSnippetLines = SearchDefaults.defaultSnippetLineCount
    @AppStorage(SearchDefaults.snippetLineCountMainOverrideKey) private var snippetOverride = 0

    /// Returns the display name for a tag UUID string, falling back to the UUID if
    /// the tag has been deleted or is not yet loaded.
    private func tagName(for tagId: String) -> String {
        userTags.first(where: { $0.id.uuidString == tagId })?.name ?? tagId
    }

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
                if result.isFrontMatter {
                    Text("front matter")
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.teal.opacity(0.1))
                        .foregroundStyle(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                // Classification chip (Source Explorer Phase 5) — derived from the
                // result's already-loaded source note; no per-row query.
                if let note = result.sourceNote,
                   let marking = SourceNoteParser.classificationMarking(fromSourceNote: note) {
                    ClassificationChip(marking: marking)
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

            // TEI-derived snippet (~1000 chars of surrounding context each side, from
            // SearchService.search). Clamped to the user's chosen line count (#189-C) —
            // the global default, or this window's Result Preview override — so readers can
            // widen or tighten the preview just as on iOS.
            SnippetView(snippet: result.snippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .lineLimit(SearchDefaults.effectiveSnippetLineCount(global: globalSnippetLines, override: snippetOverride))
                .fixedSize(horizontal: false, vertical: true)

            if !result.userTagIds.isEmpty {
                HStack(spacing: 4) {
                    ForEach(result.userTagIds.prefix(3), id: \.self) { tagId in
                        Text("◆ \(tagName(for: tagId))")
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
