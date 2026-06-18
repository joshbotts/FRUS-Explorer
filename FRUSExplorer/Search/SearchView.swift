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
///   1.11 — Session 156: "Find by citation" added to the "More" overflow `Menu` and
///          its sheet moved here from `SearchTabView`. `SearchView` owns its own
///          `NavigationStack`/toolbar (since 1.10), so a `.toolbar` modifier applied
///          outside it (as `SearchTabView` previously did) never reaches the nav
///          bar — the button was silently unreachable on iOS.
///   1.12 — Session 159: on iPad with Stage Manager (`supportsMultipleWindows`),
///          opening a result opens the document in its own window so the results
///          list stays visible alongside (open several documents from one list in
///          turn); per-document window identity focuses an already-open document
///          rather than duplicating it. A row context-menu "Open in Place" pushes
///          inline instead. iPhone / non-Stage-Manager keeps the push behaviour.
struct SearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @Environment(\.openWindow) private var openWindow
    /// `true` when the platform can open a second window (Stage Manager on iPad).
    /// When set, opening a result opens the document in its own window so the
    /// results list stays visible alongside; otherwise the document is pushed onto
    /// the search navigation stack as before.
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    @State private var vm: SearchViewModel
    @State private var showTimeline = false
    @State private var showSaveSearchSheet = false
    @State private var showSavedSearches = false
    @State private var showCitationLookup = false
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
                // `.navigationBarDrawer(.always)` pins the search field in its own
                // row beneath the nav bar on iOS, so it never expands into the bar
                // and suppresses the trailing `.primaryAction` toolbar items
                // (filters, timeline, the Save/Saved/Citation overflow menu) on the
                // compact-width results screen. With the default placement + inline
                // title those buttons were unreachable on iPhone (Session 162).
                .searchable(
                    text: $vm.keywords,
                    placement: searchFieldPlacement,
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
                // Active volume scope (e.g. the post-indexing "Search this volume"
                // handoff) is surfaced as a dismissible banner pinned above the
                // results. `.safeAreaInset` reserves no height when no scope is
                // active because `volumeScopeBanner` resolves to `EmptyView`.
                .safeAreaInset(edge: .top, spacing: 0) {
                    volumeScopeBanner
                }
                // macOS keeps the search actions in the inspector toolbar (where `.searchable` does
                // not suppress them). iOS uses the persistent `searchActionsBar` content row below —
                // an active `.searchable` field hides nav-bar trailing items, which made filters /
                // timeline / Save vanish over the results.
                .toolbar {
                    #if os(macOS)
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "search.done", defaultValue: "Done")) { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) { filterButton }
                    ToolbarItem(placement: .primaryAction) { timelineButton }
                    ToolbarItem(placement: .primaryAction) { moreMenu }
                    #endif
                }
                #if os(iOS)
                .safeAreaInset(edge: .top, spacing: 0) { searchActionsBar }
                #endif
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
                .sheet(isPresented: $showCitationLookup) {
                    CitationLookupView()
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
            vm.appState = appState
            vm.loadAvailableUserTags(context: modelContext)
            // Load the volume/subseries picker options before applying any incoming
            // parameters so `applyParameters` can reconstruct the subseries selection
            // from a flat `volumeIds` scope (see `SearchViewModel.reconstructScope`).
            vm.loadAvailableVolumes(
                allEntries: appState.manifestStore.diffResult?.known
                    ?? appState.manifestStore.bundledEntries,
                indexedIds: appState.indexedVolumeIds
            )
            if let params = initialParameters {
                vm.applyParameters(params)
            }
            if let pid = appState.activeProjectId {
                let descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.id == pid }
                )
                let project = try? modelContext.fetch(descriptor).first
                vm.applyProjectDefaults(project)
            }
            // Consume a handoff that was already pending when this tab first
            // appeared (e.g. the user opened Analytics, tapped "open matching
            // documents", and the Search tab is being created for the first time).
            consumePendingSearch()
        }
        // Consume handoffs that arrive while the Search tab is already alive —
        // `AppState.pendingSearch` is set by Corpus Analytics, "Find all mentions",
        // and the indexing banners, which also switch `activeTab` to `.search`.
        // Before Session 162 nothing on iOS read `pendingSearch`, so every one of
        // those handoffs silently did nothing.
        .onChange(of: appState.pendingSearch) { _, params in
            if params != nil { consumePendingSearch() }
        }
    }

    /// Placement for the `.searchable` field — a pinned drawer on iOS so the
    /// nav-bar toolbar stays reachable (see the `.searchable` call site), and the
    /// system default on macOS where the field lives in the inspector toolbar.
    private var searchFieldPlacement: SearchFieldPlacement {
        #if os(iOS)
        .navigationBarDrawer(displayMode: .always)
        #else
        .automatic
        #endif
    }

    /// Applies and runs a `pendingSearch` handoff, then clears it so it fires once.
    ///
    /// Runs the search immediately when the parameters carry a positive
    /// constraint (keywords/phrase/prefix, or a person filter) so the user lands
    /// on results rather than a pre-filled-but-unexecuted form. A volume-only
    /// snapshot ("Search this volume") has no executable FTS term, so it just
    /// applies the volume scope — surfaced as the dismissible `volumeScopeBanner`
    /// — and waits for the user to type a query that will be scoped to it.
    private func consumePendingSearch() {
        guard let params = appState.pendingSearch else { return }
        appState.pendingSearch = nil
        vm.applyParameters(params)
        let canRun = !(params.keywords ?? "").isEmpty
            || !(params.phrase ?? "").isEmpty
            || !(params.prefixWildcard ?? "").isEmpty
            || !(params.personRef ?? "").isEmpty
            || params.personRollupId != nil
        if canRun {
            Task { await vm.search() }
        }
    }

    // MARK: - Search Action Controls

    /// Filter toggle — shared by the macOS nav-bar toolbar and the iOS `searchActionsBar`.
    @ViewBuilder
    private var filterButton: some View {
        Button {
            vm.showFilterPanel = true
        } label: {
            Image(systemName: vm.hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .controlHelp(
            String(localized: "search.filters.toggle.a11y", defaultValue: "Toggle filters"),
            detail: String(localized: "search.filters.toggle.help",
                           defaultValue: "Filter results by volume, date range, document type, or tags"),
            systemImage: "line.3.horizontal.decrease.circle"
        )
    }

    /// Timeline toggle — disabled until there are results to chart.
    @ViewBuilder
    private var timelineButton: some View {
        Button {
            showTimeline.toggle()
        } label: {
            Image(systemName: showTimeline ? "chart.bar.fill" : "chart.bar")
        }
        .controlHelp(
            showTimeline
                ? String(localized: "search.timeline.hide.a11y", defaultValue: "Hide timeline")
                : String(localized: "search.timeline.show.a11y", defaultValue: "Show timeline"),
            detail: String(localized: "search.timeline.help",
                           defaultValue: "Chart how the search results distribute over time"),
            systemImage: "chart.bar"
        )
        .disabled(vm.results.isEmpty)
    }

    /// Save / Saved searches / Find by citation overflow menu.
    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Button {
                saveSearchName = vm.keywords.trimmingCharacters(in: .whitespaces)
                showSaveSearchSheet = true
            } label: {
                Label(String(localized: "search.saveSearch.a11y", defaultValue: "Save this search"),
                      systemImage: "bookmark")
            }
            .disabled(!vm.hasSearched)
            Button {
                showSavedSearches = true
            } label: {
                Label(String(localized: "search.savedSearches.a11y", defaultValue: "Saved searches"),
                      systemImage: "bookmark.fill")
            }
            Button {
                showCitationLookup = true
            } label: {
                Label(String(localized: "search.citationLookup.a11y", defaultValue: "Find by citation"),
                      systemImage: "text.magnifyingglass")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .controlHelp(
            String(localized: "search.moreActions.a11y", defaultValue: "More search actions"),
            detail: String(localized: "search.moreActions.help",
                           defaultValue: "Save this search, revisit saved searches, or find a document by citation"),
            systemImage: "ellipsis.circle"
        )
    }

    #if os(iOS)
    /// Persistent search-action row pinned below the `.searchable` field on iOS. An active search
    /// field suppresses the nav-bar trailing items, which used to make filters / timeline / Save
    /// disappear over the results; this content row keeps them reachable in every state.
    private var searchActionsBar: some View {
        HStack(spacing: 20) {
            filterButton
            timelineButton
            Spacer()
            moreMenu
        }
        .font(.title3)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
    #endif

    // MARK: - Volume Scope Banner

    /// A dismissible banner pinned above the results whenever the search is
    /// scoped to one or more volumes. Lets the user see the active scope (the
    /// volume's title) and clear it. Resolves to `EmptyView` when no scope is
    /// active so the enclosing `.safeAreaInset` reserves no height.
    @ViewBuilder
    private var volumeScopeBanner: some View {
        if !vm.effectiveVolumeIds.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(volumeScopeLabel)
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button {
                    clearVolumeScope()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "search.volumeScope.clear.a11y",
                                           defaultValue: "Clear volume filter"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    /// Human-readable label for the active volume scope — the volume's title
    /// (resolved from the manifest) when the effective scope is a single volume,
    /// otherwise a count of the effective volumes (the union of the individually
    /// selected volumes and every volume in the selected subseries). Falls back to
    /// the raw volume ID if the manifest lacks an entry.
    private var volumeScopeLabel: String {
        let ids = vm.effectiveVolumeIds
        if ids.count == 1 {
            let title = appState.manifestStore.entry(forVolumeId: ids[0])?.title ?? ids[0]
            return String(format: String(localized: "search.volumeScope.single %@",
                                          defaultValue: "Scoped to %@"), title)
        } else {
            return String(format: String(localized: "search.volumeScope.multiple %lld",
                                          defaultValue: "Scoped to %lld volumes"),
                          Int64(ids.count))
        }
    }

    /// Clears the active volume scope (both the individual-volume and subseries
    /// selections) and re-runs the current query (if one is active) so the results
    /// immediately widen to the full corpus.
    private func clearVolumeScope() {
        vm.selectedVolumeIds = []
        vm.selectedSubseriesIds = []
        let hasQuery = !vm.keywords.trimmingCharacters(in: .whitespaces).isEmpty
            || !vm.personRefText.trimmingCharacters(in: .whitespaces).isEmpty
            || vm.personRollupId != nil
        if vm.hasSearched && hasQuery {
            Task { await vm.search() }
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
                            openResult(vm.makeEntry(from: r))
                        }
                    }
                )
            } else {
                resultsList
            }
        } else {
            // Initial prompt — no search has been performed yet. When a volume
            // scope is active (e.g. just arrived via "Search this volume"), the
            // prompt reflects that the next query will be scoped to that volume.
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(vm.effectiveVolumeIds.isEmpty
                     ? String(localized: "search.prompt",
                              defaultValue: "Enter keywords to search the FRUS corpus.")
                     : String(localized: "search.prompt.scoped",
                              defaultValue: "Enter keywords to search within the selected volumes."))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                // Page controls — only meaningful for the paged list (not the timeline).
                if !showTimeline && vm.totalPages > 1 {
                    pageControls
                }
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

    /// Previous / next page controls shown in the results header when the result set
    /// spans more than one page. Tapping re-pages `vm.pagedResults` (and resets scroll).
    private var pageControls: some View {
        HStack(spacing: 12) {
            Button {
                if vm.currentPage > 0 { vm.currentPage -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(vm.currentPage == 0)
            .accessibilityLabel(String(localized: "search.page.previous",
                                       defaultValue: "Previous page"))

            Text(String(
                format: String(localized: "search.page.indicator %lld %lld",
                               defaultValue: "Page %lld of %lld"),
                Int64(vm.currentPage + 1), Int64(vm.totalPages)
            ))
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)

            Button {
                if vm.currentPage < vm.totalPages - 1 { vm.currentPage += 1 }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(vm.currentPage >= vm.totalPages - 1)
            .accessibilityLabel(String(localized: "search.page.next",
                                       defaultValue: "Next page"))
        }
        .font(.footnote)
        .buttonStyle(.borderless)
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

    /// Opens a search result. On a platform that can open a second window (Stage
    /// Manager on iPad) the document opens in its own window — the results list
    /// stays visible alongside, so the user can open several documents from one
    /// list in turn. Per-document window identity means reopening the same document
    /// focuses its existing window while a different document opens a new one.
    /// Everywhere else the document is pushed onto the search navigation stack.
    private func openResult(_ entry: DocumentBrowserEntry) {
        #if os(iOS)
        if supportsMultipleWindows {
            openWindow(value: DocumentWindowID(
                volumeId: entry.volumeId,
                documentId: entry.documentId,
                header: entry.header
            ))
            return
        }
        #endif
        vm.navigationPath.append(entry)
    }

    private var resultsList: some View {
        List {
            ForEach(vm.pagedResults) { result in
                Button {
                    openResult(vm.makeEntry(from: result))
                } label: {
                    SearchResultRow(
                        result: result,
                        userTags: vm.availableUserTags,
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
                #if os(iOS)
                // When multi-window is available the row opens a window by default;
                // offer the in-place reader (push) as an explicit alternative.
                .contextMenu {
                    if supportsMultipleWindows {
                        Button {
                            vm.navigationPath.append(vm.makeEntry(from: result))
                        } label: {
                            Label(
                                String(localized: "search.result.openInPlace",
                                       defaultValue: "Open in Place"),
                                systemImage: "rectangle.portrait"
                            )
                        }
                    }
                }
                #endif
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
        // Re-identify the list when the page changes so it scrolls back to the top
        // instead of retaining the previous page's offset.
        .id(vm.currentPage)
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult
    /// All known user tags, passed from the parent view's `vm.availableUserTags`.
    /// Forwarded to `SearchTagChipsRow` so UUID strings can be resolved to names.
    let userTags: [UserTag]
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

            // Document-type badges
            if result.isEditorialNote || result.isFrontMatter {
                HStack(spacing: 6) {
                    if result.isEditorialNote {
                        Label(
                            String(localized: "search.result.editorialNote.badge",
                                   defaultValue: "Editorial Note"),
                            systemImage: "text.badge.checkmark"
                        )
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    }
                    if result.isFrontMatter {
                        Label(
                            String(localized: "search.result.frontMatter.badge",
                                   defaultValue: "Front Matter"),
                            systemImage: "doc.text"
                        )
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    }
                }
            }

            // User tag chips — pass userTags so chips show names, not raw UUIDs
            if !result.userTagIds.isEmpty {
                SearchTagChipsRow(
                    tagIds: result.userTagIds,
                    systemImage: "person.crop.circle.badge.plus",
                    userTags: userTags,
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

/// Horizontally scrolling row of tappable user-tag chips for a search result.
///
/// `userTags` is the full list of `UserTag` rows supplied by the parent view.
/// Each UUID string in `tagIds` is resolved to a `UserTag.name` so the chip
/// label shows the human-readable name rather than a raw UUID string.
private struct SearchTagChipsRow: View {
    let tagIds: [String]
    let systemImage: String
    /// All known user tags, supplied by the parent. Used to resolve UUID strings
    /// in `tagIds` to display names.
    let userTags: [UserTag]
    let onTap: (String) -> Void

    /// Returns the display name for a tag UUID string, falling back to the UUID if
    /// the tag has been deleted or is not yet loaded.
    private func tagName(for tagId: String) -> String {
        userTags.first(where: { $0.id.uuidString == tagId })?.name ?? tagId
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tagIds, id: \.self) { tagId in
                    let name = tagName(for: tagId)
                    Button {
                        onTap(tagId)
                    } label: {
                        Label(name, systemImage: systemImage)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "search.tagchip.a11y",
                               defaultValue: "Filter by \(name)")
                    )
                }
            }
        }
    }
}
