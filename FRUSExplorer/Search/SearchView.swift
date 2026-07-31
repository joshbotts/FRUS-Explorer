// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResultReading

/// The mutually exclusive ways the search screen can present a result set.
///
/// The three analytical readings each replace the result list entirely, so only one can be on at
/// a time. They used to be three independent `Bool`s whose toggles hand-cleared the other two,
/// and the active one was signalled *only* by swapping a menu row's `systemImage` to a checkmark.
/// `Label(_:systemImage:)` contributes no accessible text from its image, so VoiceOver announced
/// "Timeline" identically whether Timeline was on or off — state carried by icon alone, with no
/// programmatic equivalent.
///
/// Modelling the choice as one value lets an inline `Picker` draw the checkmarks *and* announce
/// the selection for free, and the mutual exclusion stops being bookkeeping that a fourth reading
/// could forget to join. The three flags remain the storage the view body and the `.task(id:)`
/// rebuild keys read; this is a projection over them, not a replacement for them.
///
/// Version history:
///   1.0 — Q-wave: initial implementation
enum ResultReading: String, CaseIterable, Identifiable {

    /// The ordinary paged result list — the absence of a reading, not a fourth one.
    case list
    /// Matches plotted over time.
    case timeline
    /// Every occurrence of the query term on its own line, aligned.
    case concordance
    /// The words that occur near the query term.
    case collocates

    var id: String { rawValue }

    /// The menu row's title. Keys are the ones these rows already shipped with, so the change
    /// does not orphan translations.
    var title: String {
        switch self {
        case .list:
            String(localized: "search.mode.list", defaultValue: "List")
        case .timeline:
            String(localized: "search.mode.timeline", defaultValue: "Timeline")
        case .concordance:
            String(localized: "search.mode.concordance", defaultValue: "Concordance")
        case .collocates:
            String(localized: "search.mode.collocates", defaultValue: "Collocates")
        }
    }

    /// The menu row's glyph. Each reading keeps the mark it shipped with; the checkmark that used
    /// to displace it now comes from the `Picker` instead of replacing the icon.
    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .timeline: "chart.bar"
        case .concordance: "text.alignleft"
        case .collocates: "circle.grid.cross"
        }
    }

    /// Whether this reading is a view of ONE PAGE, and so pages with the pagination controls.
    ///
    /// The list and the concordance are; the timeline and the collocates panel are not — both cover
    /// the whole retained set, so a page control does nothing to them. Getting this wrong was live
    /// on both platforms in opposite directions: iOS rendered the controls over the collocates
    /// panel where they moved nothing, and macOS hid them under the concordance, which covers
    /// exactly one page and therefore *needs* them.
    var isPaged: Bool {
        switch self {
        case .list, .concordance: true
        case .timeline, .collocates: false
        }
    }

    /// Which reading three stored flags amount to.
    ///
    /// The precedence order mirrors the `else if` chain in `SearchView.resultsList` exactly. If
    /// the two ever disagree the control names one reading while the screen shows another, so this
    /// lives beside the flags it reads rather than inside a view where no test can reach it.
    static func active(timeline: Bool, concordance: Bool, collocates: Bool) -> ResultReading {
        if collocates { return .collocates }
        if concordance { return .concordance }
        if timeline { return .timeline }
        return .list
    }

    /// The flags this reading implies — all three, always, never a toggle.
    ///
    /// Assigning the whole triple is what makes exclusivity structural: there is no assignment
    /// reachable from here that leaves two readings on at once, which is exactly the invariant the
    /// three hand-cleared `Bool`s relied on every call site to maintain.
    var flags: (timeline: Bool, concordance: Bool, collocates: Bool) {
        (timeline: self == .timeline,
         concordance: self == .concordance,
         collocates: self == .collocates)
    }
}

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
///          (removed in Wave R-2a — see 1.17)
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
///   1.13 — Dynamic Type pass 2026-07-04 (UI audit A1): the empty-prompt hero
///          glyph scales via `@ScaledMetric` (capped at accessibility3).
///   1.14 — Dynamic Type review 2026-07-04: glyph cap enforced in code via
///          `FRUSTheme.cappedGlyphSize` (the `.dynamicTypeSize` cap was inert
///          on a `.system(size:)` font).
///   1.15 — 2026-07-22: reversed the 1.12 Stage-Manager default per owner request —
///          a result tap now opens the document IN THIS window (push), keeping the
///          search context one back-swipe away; opening in a separate document window
///          (the 1.12 behaviour, so the results list stays visible) is demoted to the
///          row context menu's "Open in New Window". iPhone unchanged (always pushed).
///   1.16 — Wave R-4 (2026-07-26): all five search entry points now route through
///          `runSearch()`, which runs the query and then records a `SearchHistoryEntry`
///          via `SearchViewModel.recordSearchHistory`. Before this, iOS recorded searches
///          only as `SessionEvent.searchSubmit`, so Project Home's "Searches Run" tile and
///          Recent Searches card — both backed by `SearchHistoryEntry` — were structurally
///          empty for anyone who never used the Mac app.
///   1.17 — Wave R-2a: `vm.appState` is no longer wired in `.task` — the only thing it fed was
///          the retired `.searchSubmit` session event. `runSearch()` is unchanged.
///   1.18 — Q wave: the actions-bar chart control becomes `examineMenu` — `binoculars`,
///          named after what it does rather than after one of its four children. The three
///          mutually exclusive readings become an inline `Picker` over ``ResultReading`` so
///          VoiceOver can announce the selection, the glyph now fills for any active reading
///          (it tracked only Timeline), and Save as Working Corpus moves to `moreMenu` beside
///          Save this search — it is an action, not a reading.

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
    /// #338 step 2: this scene's identity, injected into the Saved Searches sheet so its Word Cloud
    /// action addresses THIS window (a sheet doesn't reliably inherit `\.sceneID`).
    @Environment(\.sceneID) private var sceneID

    /// Point size of the empty-prompt hero glyph, scaled with Dynamic Type
    /// relative to `.largeTitle` so it tracks the prompt text. Clamped via
    /// `FRUSTheme.cappedGlyphSize` at the glyph site.
    @ScaledMetric(relativeTo: .largeTitle) private var promptGlyphSize: CGFloat = 48

    @State private var vm: SearchViewModel
    /// Live list of the user's tags, kept current by SwiftData. Fed into
    /// `vm.availableUserTags` so a tag created elsewhere (e.g. the research-note
    /// editor) appears as a search filter chip without an app restart (#188-D).
    @Query(sort: \UserTag.name) private var liveUserTags: [UserTag]
    /// The Query Inspector's state (Q-2).
    @State private var inspectorController = QueryInspectorController()

    /// The facet panel's state (R-1).
    @State private var facetController = FacetPanelController()

    /// Whether the facet sheet is showing.
    @State private var showFacetSheet = false

    /// Whether the inspector card's detail rows are showing. `@SceneStorage` so the choice
    /// survives per scene, matching the macOS strip.
    @SceneStorage("search.inspector.expanded") private var inspectorExpanded = false

    @State private var showTimeline = false
    /// Concordance mode (R-3b) — mutually exclusive with the timeline, since both replace the list.
    @State private var showConcordance = false
    @State private var concordance = ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
    @State private var concordanceSort: KWICSort = .leftContext
    @State private var showCollocates = false
    @State private var showSaveCorpusSheet = false
    @State private var collocation: CollocationAnalysis.Outcome = .pending
    @State private var isLoadingCollocation = false
    @AppStorage(SearchCollocationDefaults.windowKey) private var collocationWindow = 10
    @AppStorage(SearchCollocationDefaults.orderKey)
    private var collocationOrderRaw = CollocationOrder.evidence.rawValue
    @State private var isLoadingConcordance = false
    @State private var showSaveSearchSheet = false
    @State private var showSavedSearches = false
    @State private var showCitationLookup = false
    @State private var saveSearchName = ""
    /// When set, presents the Archival Neighbors sheet for a search result's document.
    @State private var archivalNeighborsTarget: ArchivalNeighborsDocKey? = nil
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
                // Checklist mode (#189-D): a hidden, always-mounted observer keeps the reviewed
                // set live as documents are opened, independent of which results branch (list or
                // timeline) is showing or how the document was opened. Re-created when the anchor
                // moves so it queries against the current cutoff.
                .background {
                    if vm.checklistMode, let enabledAt = vm.checklistEnabledAt {
                        ChecklistReviewedObserver(enabledAt: enabledAt) { keys in
                            vm.readSinceEnabledKeys = keys
                        }
                        .id(enabledAt)
                    }
                }
                .navigationTitle(
                    String(localized: "search.title", defaultValue: "Search")
                )
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                // #377 Phase 5: on regular-width iPad the top-inset "Working on:" banner is suppressed
                // (floating tab bar overlay, #238); surface the research question as a subtitle instead.
                .workingOnSubtitle()
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
                    Task { await runSearch() }
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
                    // #377 Phase 5: the ambient "Working on: <question>" lens above the (transient)
                    // volume-scope banner. Both reserve zero height when inactive.
                    VStack(spacing: 0) {
                        WorkingOnBanner()
                        workingCorpusBanner
                        volumeScopeBanner
                    }
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
                    ToolbarItem(placement: .primaryAction) { examineMenu }
                    ToolbarItem(placement: .primaryAction) { moreMenu }
                    #endif
                }
                #if os(iOS)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        searchActionsBar
                        queryInspectorCard
                        narrowedByRow
                    }
                }
                .sheet(isPresented: $showSaveCorpusSheet) { saveCorpusSheet }
                // The facet sheet (R-1c). Medium and large detents per the design, so it can
                // be skimmed beside the results or opened fully to work through a long list.
                .sheet(isPresented: $showFacetSheet) {
                    NavigationStack {
                        FacetPanelView(
                            controller: facetController,
                            matchCount: vm.hasSearched ? vm.totalMatchCountForFacets : nil,
                            displayedCount: vm.displayedResults.count,
                            isPartialEvidence: resultSetScope.isPartialEvidence,
                            isChecklistHiding: vm.checklistMode
                                && vm.displayedResults.count < vm.results.count,
                            onNarrow: { narrowing in
                                facetController.recordNarrowing(from: vm.totalMatchCountForFacets)
                                vm.applyFacetNarrowing(narrowing)
                                showFacetSheet = false
                                Task { await runSearch() }
                            },
                            onDiscloseSection: { section in
                                Task {
                                    await facetController.load(
                                        section,
                                        parameters: vm.searchParameters,
                                        service: appState.searchService,
                                        pipeline: appState.indexingPipeline)
                                }
                            })
                            .navigationTitle(String(localized: "search.facets.title",
                                                    defaultValue: "This result set"))
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(String(localized: "search.done", defaultValue: "Done")) {
                                        showFacetSheet = false
                                    }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                }
                // Keyed on the live field so the expression updates as the researcher
                // types — the design's "a researcher learns NEAR by watching the
                // expression change". The controller debounces; a keystroke costs nothing
                // until typing settles. The search itself still runs only on submit.
                // The facet panel MUST be invalidated when the search changes. Without this
                // — which is how R-1c shipped — `load` early-returns on
                // `loadedSections.contains(section)` and `@State facetController` lives for
                // the tab's lifetime, so a section opened once was shown against every later
                // search: stale buckets beside a live match count. `narrowedFrom` was also
                // unreachable, because it is only promoted inside `invalidate`.
                //
                // Keyed on `executedSearchVersion`, which bumps once per *executed* search —
                // `keywords` changes while typing and would discard the panel mid-read.
                // The concordance is built for the page on screen, so it is rebuilt when the mode opens,
        // when the page turns, and when a new search replaces the results. `executedSearchVersion`
        // rather than `results` — it is bumped once per COMPLETED search, so this cannot fire against
        // a half-replaced set.
        .task(id: ConcordanceRebuildKey(mode: showConcordance, rows: vm.pagedResults,
                                        version: vm.executedSearchVersion)) {
            await rebuildConcordance()
        }
        // Keyed on the WINDOW too, and NOT on the page: a collocation reads the whole retained
        // result set, so paging changes nothing about it — rebuilding on page turn would rescan
        // thousands of documents to produce the identical ranking.
        .task(id: CollocationRebuildKey(mode: showCollocates, window: collocationWindow,
                                        version: vm.executedSearchVersion)) {
            await rebuildCollocation()
        }
        .onChange(of: vm.executedSearchVersion) { _, _ in
                    facetController.invalidate(signature: "ios-\(vm.executedSearchVersion)")
                }
                .task(id: vm.keywords) {
                    await inspectorController.refresh(
                        parameters: vm.searchParameters,
                        service: appState.searchService,
                        indexedVolumeCount: appState.indexedVolumeIds.count)
                }
                #endif
                // Advanced filter sheet — iOS uses detents; macOS uses a fixed frame
                // declared inside SearchFilterView.
                .sheet(isPresented: $vm.showFilterPanel) {
                    // iOS's filter sheet shares this view model, so its parameters ARE the
                    // search's — but pass them explicitly anyway, because macOS's do not.
                    SearchFilterView(vm: vm, tagCountParameters: vm.searchParameters)
                        .environment(appState)
                        .modelContainer(modelContext.container)
                }
                // Refresh the project's engaged-document set as the filter panel opens, so
                // the History scope reflects documents engaged since the tab was shown (#377
                // Phase 2a) — parity with the macOS Advanced panel, which reloads on open.
                .onChange(of: vm.showFilterPanel) { _, isOpen in
                    if isOpen { refreshEngagedKeys() }
                }
                .sheet(isPresented: $showSaveSearchSheet) {
                    saveSearchSheet
                }
                .sheet(isPresented: $showSavedSearches) {
                    SavedSearchesView { saved in
                        vm.applyParameters(saved.searchParameters)
                        Task { await runSearch() }
                    }
                    .modelContainer(modelContext.container)
                    // #338 step 2: publish this window's scene id into the sheet so
                    // SavedSearchesView's Word Cloud action targets THIS window (Finding 2).
                    .environment(\.sceneID, sceneID)
                }
                .sheet(isPresented: $showCitationLookup) {
                    CitationLookupView()
                }
                .sheet(item: $archivalNeighborsTarget) { key in
                    ArchivalNeighborsSheet(appState: appState, docKey: key)
                        .environment(appState)
                        // #338 step 4: address THIS window for the sheet's open-document action.
                        .environment(\.sceneID, sceneID)
                }
                .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                    #if os(iOS)
                    // #377 Phase 5 follow-up: a document opened from Search results also keeps the
                    // "Working on:" subtitle on regular-width iPad (no-op elsewhere).
                    DocumentView(entry: entry)
                        .workingOnSubtitle()
                    #else
                    MacDocumentView(entry: entry, navigationPath: .constant([]), highlightCoordinator: HighlightCoordinator())
                    #endif
                }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
        .task {
            vm.availableUserTags = liveUserTags
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
            applyActiveProject()
            // Consume a handoff that was already pending when this tab first
            // appeared (e.g. the user opened Analytics, tapped "open matching
            // documents", and the Search tab is being created for the first time).
            consumePendingSearch()
        }
        // Keep the filter panel's tag chips current: when SwiftData reports a tag
        // added/removed/renamed (on this device or via CloudKit), feed the fresh
        // list into the view model so chips update live (#188-D). Keyed on the name
        // list so a rename also propagates — an array of `@Model` objects compares by
        // persistent identity, which a rename does not change.
        .onChange(of: liveUserTags.map(\.name)) { _, _ in
            vm.availableUserTags = liveUserTags
        }
        // Consume handoffs that arrive while the Search tab is already alive —
        // `AppState.pendingSearch` is set by Corpus Analytics, "Find all mentions",
        // and the indexing banners, which also switch `activeTab` to `.search`.
        // Before Session 162 nothing on iOS read `pendingSearch`, so every one of
        // those handoffs silently did nothing.
        .onChange(of: appState.pendingSearch) { _, params in
            if params != nil { consumePendingSearch() }
        }
        // Re-apply project context when the active project changes: refresh the date
        // defaults and the engaged-document set that backs the History search scope
        // (#377 Phase 2). Resets the scope to `.off` so a prior selection can't silently
        // gate results to a different project's history.
        .onChange(of: appState.activeProjectId) { _, _ in
            applyActiveProject()
        }
    }

    // MARK: - Running a Search

    /// Runs the current query and records it in the research trail (Wave R-4).
    ///
    /// **Every** search entry point in this view must call this rather than `vm.search()`
    /// directly — the keyboard Return, the Saved Searches sheet, an incoming `pendingSearch`
    /// hand-off, clearing the volume scope, and tapping a tag chip on a result row. A bare
    /// `vm.search()` would run the search but leave no `SearchHistoryEntry`, which is the
    /// failure this indirection exists to prevent; `ResearchLoggingGateTests`
    /// `iOSSearchEntryPointsRouteThroughTheRecorder` fails if one reappears.
    ///
    /// `recordSearchHistory` applies its own skip conditions (logging off, empty query,
    /// errored search, or a filter/scope-only re-run of the same query), so calling it after
    /// every execution is correct — the last two entry points above are re-runs by nature.
    private func runSearch() async {
        await vm.search()
        vm.recordSearchHistory(projectId: appState.activeProjectId, in: modelContext)
    }

    /// Loads the active project's search context into the view model: date defaults,
    /// the project name (for the scope picker's label), and the engaged
    /// `"volumeId/documentId"` set that the History scope gates on (#377 Phase 2).
    /// Clears everything and resets the scope in Global Context.
    private func applyActiveProject() {
        guard let pid = appState.activeProjectId else {
            vm.projectScope = .off
            vm.projectOnlyNew = false
            refreshEngagedKeys()
            return
        }
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == pid }
        )
        let project = try? modelContext.fetch(descriptor).first
        vm.applyProjectDefaults(project)
        vm.projectScope = .off
        vm.projectOnlyNew = false
        refreshEngagedKeys()
    }

    /// Reloads the active project's engaged-document set (+ display name) into the VM
    /// **without** touching the current scope selection (#377 Phase 2a). Called on active-
    /// project change (via `applyActiveProject`) and whenever the filter panel opens, so the
    /// History scope reflects documents engaged since the Search tab was first shown — the
    /// macOS panel already reloads on every open; this gives iOS the same freshness. Keys are
    /// sorted so the set has a stable order.
    private func refreshEngagedKeys() {
        guard let pid = appState.activeProjectId else {
            vm.projectEngagedDocumentKeys = []
            vm.projectFocusVolumeIds = []
            vm.projectScopeName = nil
            return
        }
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == pid })
        let project = try? modelContext.fetch(descriptor).first
        vm.projectScopeName = project?.name
        // Focus volumes resolve from the project's subjects via the bundled profiles — an
        // in-memory lookup, so it's set synchronously (#377 Phase 2b).
        vm.projectFocusVolumeIds = SearchViewModel.focusVolumeIds(for: project)
        // Compute the engaged set off the main thread so a large library never freezes the
        // UI when the filter panel opens or the project changes (#377 Phase 2a fix).
        let container = modelContext.container
        Task {
            let keys = await ProjectEngagedDocuments.keys(forProject: pid, container: container)
            vm.projectEngagedDocumentKeys = keys.sorted()
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
        // #338 step 5: consume only a search hand-off addressed to THIS window (or the `.anyWindow`
        // wildcard), so the query runs in the window it was triggered from, coupled to the tab switch.
        guard let sceneID,
              let params = appState.consumeHandoff(\.pendingSearch, for: sceneID, orAnyWindow: true) else { return }
        vm.applyParameters(params)
        let canRun = !(params.keywords ?? "").isEmpty
            || !(params.phrase ?? "").isEmpty
            || !(params.prefixWildcard ?? "").isEmpty
            || !(params.personRef ?? "").isEmpty
            || params.personRollupId != nil
        if canRun {
            Task { await runSearch() }
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

    /// Which set this screen is showing — the one place iOS composes it, so no surface can
    /// invent its own account of the same numbers. `totalMatchCount` is now a real whole-query
    /// count, taken concurrently with the search; it stays `Optional` because the count can fail,
    /// and every sentence in ``ResultSetScope`` is written to be true without one.
    private var resultSetScope: ResultSetScope {
        ResultSetScope(loaded: vm.results.count,
                       shown: vm.displayedResults.count,
                       fetchLimit: SearchViewModel.searchHardLimit,
                       totalMatchCount: vm.totalMatchCount,
                       documentsOnPage: vm.pagedResults.count,
                       pageCount: vm.totalPages,
                       appliedCorpusTruncation: vm.appliedWorkingCorpusTruncation)
    }

    /// The active reading, derived from the three flags the body and rebuild keys still read.
    ///
    /// The precedence order mirrors the `else if` chain in `resultsList` exactly. If the two ever
    /// disagree, the control would name one reading while the screen showed another.
    private var activeReading: ResultReading {
        ResultReading.active(timeline: showTimeline,
                             concordance: showConcordance,
                             collocates: showCollocates)
    }

    /// A single-selection projection over the three flags, so the menu can host a `Picker`.
    ///
    /// The setter assigns all three unconditionally rather than toggling, which is what makes the
    /// exclusivity structural: there is no assignment that can leave two readings on.
    private var readingSelection: Binding<ResultReading> {
        Binding(
            get: { activeReading },
            set: { selected in
                let flags = selected.flags
                showTimeline = flags.timeline
                showConcordance = flags.concordance
                showCollocates = flags.collocates
            }
        )
    }

    /// The actions-bar control for examining the result set as a whole (R-1c, R-3b, S-2, M-1).
    ///
    /// ## Why binoculars, and not a chart
    /// This menu once held Timeline and Facets and was labelled `chart.bar` — the glyph of one of
    /// its own children. Three readings later only Timeline produces a chart, so the icon promised
    /// a picture the other three do not deliver, and named the container after a single child. No
    /// symbol depicts "timeline + concordance + collocates + facets" because they share no picture;
    /// binoculars is chosen for being *about surveying what is already in front of you* while
    /// colliding with nothing — the app's optical vocabulary is otherwise `magnifyingglass`
    /// (search) and `eye` (visibility), and neither is this.
    ///
    /// ## Why the readings are a `Picker`
    /// See ``ResultReading``. The three were `Button`s that toggled `Bool`s and showed a checkmark
    /// in place of their icon, which VoiceOver could not read.
    ///
    /// Facets sits below the divider because it is not a reading: it opens a sheet over the
    /// results rather than replacing them, and it is the one item measured against the whole match
    /// rather than the retained set.
    @ViewBuilder
    private var examineMenu: some View {
        Menu {
            Picker(String(localized: "search.mode.picker", defaultValue: "Read as"),
                   selection: readingSelection) {
                ForEach(ResultReading.allCases) { reading in
                    Label(reading.title, systemImage: reading.systemImage).tag(reading)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                showFacetSheet = true
            } label: {
                Label(String(localized: "search.mode.facets", defaultValue: "Facets"),
                      systemImage: "chart.bar.doc.horizontal")
            }
        } label: {
            Image(systemName: activeReading == .list ? "binoculars" : "binoculars.fill")
        }
        .controlHelp(
            String(localized: "search.mode.a11y", defaultValue: "Examine these results"),
            detail: String(localized: "search.mode.help",
                           defaultValue: "Read the results you have as a timeline, as your search term in context, or as the words that occur near it — or break the whole match down by year, volume, person, type and provenance."),
            // The Large Content Viewer HUD is driven by this SEPARATE literal. Left behind, a
            // low-vision user would keep seeing chart.bar after the visible glyph had moved.
            systemImage: "binoculars"
        )
        // The control had no value at all: with a reading active, the whole results region is
        // replaced while nothing announces which control did it.
        .accessibilityValue(activeReading.title)
        .disabled(vm.results.isEmpty)
    }

    #if os(iOS)
    /// Checklist-review toggle (#189-D), promoted to a first-class, self-labeling control in the
    /// iOS `searchActionsBar` (#218) so it's discoverable without opening the overflow menu.
    /// Tints when active. Disabled until a search returns results, but — like the macOS control —
    /// stays enabled once results exist even in the all-reviewed state (gated on raw `results`,
    /// not `displayedResults`), so the user can always turn it back off. iOS-only: its sole call
    /// site (`searchActionsBar`) is `#if os(iOS)`; the macOS `SearchView` surface keeps the
    /// overflow-menu toggle.
    @ViewBuilder
    private var checklistButton: some View {
        Button {
            vm.setChecklistMode(!vm.checklistMode)
        } label: {
            Image(systemName: "checklist")
                .foregroundStyle(vm.checklistMode ? Color.accentColor : Color.primary)
        }
        .controlHelp(
            String(localized: "search.checklist.toggle", defaultValue: "Checklist Mode"),
            detail: vm.checklistMode
                ? String(localized: "search.checklist.off.help",
                         defaultValue: "Turn off Checklist Mode and show every result")
                : String(localized: "search.checklist.on.help",
                         defaultValue: "Checklist review mode — hide results as you review them"),
            systemImage: "checklist"
        )
        .accessibilityValue(vm.checklistMode
                            ? String(localized: "search.checklist.state.on", defaultValue: "On")
                            : String(localized: "search.checklist.state.off", defaultValue: "Off"))
        .disabled(vm.results.isEmpty)
    }
    #endif

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
            // Saving the RESULTS is the sibling of saving the QUERY, which is why it lives here
            // and not among the readings. Every other item in the examine menu re-presents the set
            // and leaves nothing behind; this one writes a CloudKit-synced `WorkingCorpus` whose
            // consumer is a different control on a different surface. It also carried the only
            // second enablement rule in that menu — `displayedResults`, where the readings gate on
            // `results` — which is a further sign it was never the same kind of thing.
            Button {
                showSaveCorpusSheet = true
            } label: {
                Label(String(localized: "search.corpus.save", defaultValue: "Save as Working Corpus…"),
                      systemImage: "tray.full")
            }
            .disabled(vm.displayedResults.isEmpty)
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
            // Checklist mode (#189-D): hides results as you review them (open them, or tap
            // "Mark reviewed"), so a long result set becomes a shrinking to-do list.
            // On iOS this now lives as a promoted control in `searchActionsBar` (#218), so the
            // overflow toggle is retained only for the macOS `SearchView` surface to avoid two
            // controls for one state; the shipping macOS search window (SearchSheet) has its own.
            #if os(macOS)
            Divider()
            Toggle(isOn: Binding(
                get: { vm.checklistMode },
                set: { on in vm.setChecklistMode(on) }
            )) {
                Label(String(localized: "search.checklist.toggle", defaultValue: "Checklist Mode"),
                      systemImage: "checklist")
            }
            .disabled(vm.results.isEmpty)
            #endif
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .controlHelp(
            String(localized: "search.moreActions.a11y", defaultValue: "More search actions"),
            detail: String(localized: "search.moreActions.help",
                           defaultValue: "Save this search or its results, revisit saved searches, or find a document by citation"),
            systemImage: "ellipsis.circle"
        )
    }


    #if os(iOS)
    /// Persistent search-action row pinned below the `.searchable` field on iOS. An active search
    /// field suppresses the nav-bar trailing items, which used to make filters / timeline / Save
    /// disappear over the results; this content row keeps them reachable in every state.
    /// Active narrowings, as clearable chips under the inspector card (R-1c).
    ///
    /// iOS has never had an active-filter row — only a filled filter glyph, which says *that*
    /// something is filtered but neither what nor how to undo it. That was tolerable while
    /// every filter was set in a sheet the user had just closed. Once a single tap in a facet
    /// list narrows the result set, the narrowing *is* the interaction, and it has to be
    /// legible and reversible on the screen where it took effect.
    @ViewBuilder
    private var narrowedByRow: some View {
        let narrowings = vm.activeNarrowings
        if !narrowings.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text(String(localized: "search.narrowedBy", defaultValue: "Narrowed by"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(narrowings) { narrowing in
                        Button {
                            vm.clearNarrowing(narrowing.id)
                            Task { await runSearch() }
                        } label: {
                            HStack(spacing: 3) {
                                Text(narrowing.label)
                                    .font(.caption)
                                    .lineLimit(1)
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12),
                                        in: Capsule())
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            localized: "search.narrowing.clear.a11y",
                            defaultValue: "Remove the \(narrowing.label) filter"))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    /// The Query Inspector as a disclosure card under the search field (Q-2).
    ///
    /// Collapsed it is one mono line — the expression the search will actually run.
    /// Expanded it adds each term's stem and counts. Per decision Q-2-2 the expression
    /// line itself is never hidden: the audience publishes method appendices, and hiding
    /// the raw expression optimises for the wrong user.
    @ViewBuilder
    private var queryInspectorCard: some View {
        if let inspection = inspectorController.inspection,
           inspection.expression != nil || inspection.isFilterOnly {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { inspectorExpanded.toggle() }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        QueryInspectorStrip(
                            inspection: inspection,
                            isExpanded: inspectorExpanded,
                            isCountingScoped: inspectorController.isCountingScoped,
                            onRequestScopedCounts: {
                                Task {
                                    await inspectorController.loadScopedCounts(
                                        parameters: vm.searchParameters,
                                        service: appState.searchService)
                                }
                            })
                        Image(systemName: inspectorExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(inspectorExpanded
                    ? String(localized: "search.inspector.collapse", defaultValue: "Hide term detail")
                    : String(localized: "search.inspector.expand", defaultValue: "Show term detail"))
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private var searchActionsBar: some View {
        HStack(spacing: 20) {
            filterButton
            examineMenu
            checklistButton
            sortMenu
            Spacer()
            moreMenu
        }
        .font(.title3)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Sort control (#305): a compact menu to reorder results by relevance or document date, ported
    /// from the macOS sort bar. The icon fills when a non-default order is active.
    private var sortMenu: some View {
        Menu {
            Picker(String(localized: "search.sort.title", defaultValue: "Sort results"),
                   selection: Binding(get: { vm.sortOrder }, set: { vm.sortOrder = $0 })) {
                ForEach(SearchSortOrder.allCases, id: \.self) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(String(localized: "search.sort.title", defaultValue: "Sort results"),
                  systemImage: vm.sortOrder == .relevance
                      ? "arrow.up.arrow.down"
                      : "arrow.up.arrow.down.circle.fill")
                .labelStyle(.iconOnly)
        }
        .disabled(vm.results.isEmpty)
        .accessibilityLabel(String(localized: "search.sort.a11y", defaultValue: "Sort results"))
        .accessibilityValue(vm.sortOrder.label)
    }
    #endif

    // MARK: - Scope Banners

    /// The applied working corpus, named on the screen it governs.
    ///
    /// `appliedWorkingCorpusName` has existed since M-1 with a doc comment promising "the
    /// applied-scope chip", and nothing rendered it — so a researcher searching inside a corpus
    /// saw a bare result count, an unfilled filter glyph (the corpus was absent from
    /// `hasActiveFilters`) and nothing at all naming the scope every row had passed through.
    ///
    /// Deliberately the sibling of ``volumeScopeBanner`` rather than a new idiom: the two are the
    /// same idea at two grains, and a researcher who has learned one should recognise the other.
    @ViewBuilder
    private var workingCorpusBanner: some View {
        if let name = vm.appliedWorkingCorpusName {
            HStack(spacing: 8) {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(format: String(localized: "search.corpusScope.label %@",
                                           defaultValue: "Inside “%@”"), name))
                    .font(.footnote)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button {
                    vm.clearWorkingCorpus()
                    Task { await runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "search.corpusScope.clear.a11y",
                                           defaultValue: "Leave this working corpus"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

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
            Task { await runSearch() }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if vm.isSearching {
            // iOS unmounts the whole results area while searching — count header, List and
            // pagination all go — so this is already an empty pending surface and the cloud
            // fights nothing. It is also why the delay matters here: a rare term returns in
            // tens of milliseconds and this branch would otherwise flash.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .pendingCloudBackdrop(
                    scope: CloudSurfaceArbiter.searchScope(volumeIds: vm.effectiveVolumeIds,
                                                           manifest: appState.manifestStore),
                    isPending: vm.isSearching
                )
        } else if let err = vm.searchError {
            ContentUnavailableView(
                String(localized: "search.error.title", defaultValue: "Search Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if vm.hasSearched && vm.results.isEmpty {
            // Q-2: "Try different keywords" is indistinguishable from a typo, a stemming
            // surprise, and a genuine historical absence. Name the conjunct that is empty.
            QueryZeroResultView(
                inspection: inspectorController.inspection
                    ?? QueryInspection(expression: nil, operands: [],
                                       indexedVolumeCount: appState.indexedVolumeIds.count,
                                       isFilterOnly: false),
                emptyConjuncts: inspectorController.emptyConjuncts)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: vm.executedSearchVersion) {
                    await inspectorController.decomposeZeroResult(
                        parameters: vm.searchParameters, service: appState.searchService)
                }
        } else if !vm.results.isEmpty {
            resultCountHeader
            checklistHiddenBanner
            if vm.checklistMode && vm.displayedResults.isEmpty {
                // Checklist mode has hidden every result (#189-D) — applies in both list and
                // timeline modes (checked before the timeline branch).
                ContentUnavailableView(
                    String(localized: "search.checklist.allReviewed.title",
                           defaultValue: "All Results Reviewed"),
                    systemImage: "checkmark.circle",
                    description: Text(String(localized: "search.checklist.allReviewed.detail",
                                             defaultValue: "You've reviewed every result. Turn off Checklist Mode to see them again."))
                )
            } else if showCollocates {
                CollocationView(
                    scope: resultSetScope,
                    outcome: collocation,
                    windowSize: $collocationWindow,
                    order: Binding(get: { CollocationOrder(rawValue: collocationOrderRaw) ?? .evidence },
                                   set: { collocationOrderRaw = $0.rawValue }),
                    isLoading: isLoadingCollocation)
            } else if showConcordance {
                ConcordanceView(scope: resultSetScope, result: concordance, sort: $concordanceSort) { line in
                    // Open the line's document through the same path a list row uses, so a
                    // concordance line and a result row land in exactly the same place.
                    if let result = vm.pagedResults.first(where: {
                        $0.volumeId == line.volumeId && $0.documentId == line.documentId
                    }) {
                        openResult(vm.makeEntry(from: result))
                    }
                }
                .overlay { if isLoadingConcordance { ProgressView() } }
            } else if showTimeline {
                // The bias caption, above the chart rather than below it — a distribution is read
                // before a footnote. It states that the SHAPE is skewed, which nothing else on
                // screen says: the cap notice reports a size, and a reader can discount a size.
                // A relevance-ranked top-N is not date-neutral, so no amount of knowing "there are
                // more" corrects the shape of what is plotted.
                if let bias = resultSetScope.timelineBiasCaption {
                    Text(bias)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }
                // Plot the checklist-filtered set so the timeline hides reviewed documents the
                // same way the list does (#189-D).
                DocumentTimelineView(
                    items: vm.displayedResults.map {
                        DocumentTimelineView.Item(
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            header: $0.header
                        )
                    },
                    onSelect: { item in
                        if let r = vm.displayedResults.first(where: {
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
                    .font(.system(size: FRUSTheme.cappedGlyphSize(promptGlyphSize, base: 48)))
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

    /// A subtle banner shown while checklist mode is on and at least one result is hidden, so the
    /// shrunken result count is explained (#189-D).
    @ViewBuilder
    private var checklistHiddenBanner: some View {
        if vm.checklistMode {
            let hidden = vm.results.count - vm.displayedResults.count
            if hidden > 0 {
                Label(
                    String(format: String(localized: "search.checklist.hiddenBanner %lld",
                                          defaultValue: "%lld reviewed hidden"), Int64(hidden)),
                    systemImage: "checklist"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 2)
            }
        }
    }

    private var resultCountHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(resultSetScope.headerDescription
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                Spacer()
                // Page controls, shown for the readings that actually page. `!showTimeline` let
                // them render over the collocates panel, where turning the page moved nothing:
                // `CollocationRebuildKey` deliberately excludes the page, so the controls worked
                // and had no effect.
                if activeReading.isPaged && vm.totalPages > 1 {
                    pageControls
                }
            }
            // Over-cap guidance: shown when the result set hit the hard limit, meaning
            // there are likely more matching documents not visible in the list.
            // Over-cap guidance — only when the result set hit the hard limit.
            if let guidance = resultSetScope.overCapGuidance {
                Text(guidance)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Search → Analytics handoff (Direction B): available for any keyword
            // search so the user can always chart the term's distribution over time.
            // When the result set is capped, it also helps find a date range that
            // narrows the match set.
            if !vm.keywords.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    openSearchInAnalytics()
                } label: {
                    Label(
                        String(localized: "search.analytics.button",
                               defaultValue: "Visualize in Corpus Analytics"),
                        systemImage: "chart.bar.xaxis"
                    )
                    .font(.caption2.weight(.medium))
                }
                .buttonStyle(.borderless)
                .padding(.top, 1)
                .help(String(
                    localized: "search.analytics.help",
                    defaultValue: "Open Corpus Analytics charting how often these keywords appear over time"
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

    /// Builds an `AnalyticsParameters` snapshot from the current search and hands off
    /// to Corpus Analytics via `AppState.pendingAnalytics`. Available for any keyword
    /// search (not only over-cap ones).
    ///
    /// Carries the submitted keywords as the chart term, and — when an explicit
    /// date filter is active — the filter's start/end years as the chart's
    /// year-range bounds, so the chart opens already focused on the same window
    /// the search was scoped to. `phrase`/`prefixWildcard` are intentionally not
    /// folded in: `CorpusAnalyticsService` charts a single plain-text term, and
    /// `keywords` is the field most search sessions actually populate.
    private func openSearchInAnalytics() {
        let term = vm.keywords.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        var startYear: Int? = nil
        var endYear: Int? = nil
        if vm.dateRangeEnabled {
            let cal = Calendar(identifier: .gregorian)
            startYear = cal.component(.year, from: vm.dateRangeStart)
            endYear   = cal.component(.year, from: vm.dateRangeEnd)
        }
        appState.openAnalytics(
            AnalyticsParameters(
                term: term,
                yearRangeStart: startYear,
                yearRangeEnd: endYear
            ),
            from: sceneID
        )
        // #369 BUG-11: the analytics sheet is owned by BrowserView (Browse tab), so bring that tab
        // forward — otherwise, handed off from the Search tab, the sheet presents on a backgrounded
        // tab and nothing appears to happen. Mirrors WordCloudView's analyze/chronology hand-offs.
        // `pendingTab` is iOS-only (macOS routes to windows), so guard it like the siblings do.
        #if os(iOS)
        appState.openTab(.browse, from: sceneID)
        #endif
        #if DEBUG
        print("[SearchView] Over-cap handoff to Analytics — term: \"\(term)\", years: \(String(describing: startYear))–\(String(describing: endYear))")
        #endif
    }

    // MARK: - Save Search Sheet

    private var saveSearchSheet: some View {
        NavigationStack {
            Form {
                // These two keys were swapped relative to the macOS sheet: iOS had the section
                // titled "Search Name" with a "Name" placeholder, macOS the reverse. Same keys,
                // so one of the two was always going to be wrong once a catalog ships.
                Section(String(localized: "search.saveSearch.section",
                               defaultValue: "Name")) {
                    TextField(
                        String(localized: "search.saveSearch.placeholder",
                               defaultValue: "Name this search"),
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
                // #258 Q4(a): SavedSearch persists no volume scope, so an active
                // volume/subseries/custom-scope selection is silently dropped on save.
                // v1 disclosure per the reviewed sketch; the additive optional field
                // is the named fast-follow.
                if !vm.effectiveVolumeIds.isEmpty {
                    Section {
                        Label(String(localized: "search.saveSearch.scopeNotSaved",
                                     defaultValue: "The volume scope is not saved with the search — re-apply it after running the saved search."),
                              systemImage: "info.circle")
                            .font(.caption)
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
    /// Opens a tapped result IN THIS window by pushing it onto the search navigation stack, so the
    /// document opens where the search is and the results list is one back-swipe away. "Open in New
    /// Window" (the row context menu, Stage Manager) is the explicit alternative that opens a separate
    /// document window so the results list stays visible alongside.
    /// Builds the concordance for the page on screen.
    ///
    /// Driven by mode, page and result changes rather than computed in `body`: the build is a DB
    /// fetch plus a scan, and a view body must not do either. Concordancing `pagedResults` (not the
    /// whole retained set) is what keeps it to one page's worth of body text — see
    /// `SearchService.concordance(for:parameters:radius:)`.
    private func rebuildConcordance() async {
        guard showConcordance, let service = appState.searchService else { return }
        let page = vm.pagedResults
        guard !page.isEmpty else {
            concordance = ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
            return
        }
        isLoadingConcordance = true
        defer { isLoadingConcordance = false }
        concordance = (try? await service.concordance(
            for: page, parameters: vm.submittedSearchParameters))
            ?? ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
    }

    /// Recomputes the collocation over the whole retained result set.
    ///
    /// `vm.displayedResults`, not `vm.pagedResults`: a measure over one page cannot clear its own
    /// floor — 25 documents yield roughly 400 window tokens across ~290 distinct lemmas, so almost
    /// nothing reaches three occurrences and the panel reads as broken rather than bounded.
    private func rebuildCollocation() async {
        guard showCollocates, let service = appState.searchService else { return }
        let results = vm.displayedResults
        guard !results.isEmpty else { collocation = .unavailable(.noMatches); return }
        isLoadingCollocation = true
        defer { isLoadingCollocation = false }

        // The reference decodes off the main actor at launch; a read taken before it lands would
        // verdict `.noArtifact`, which is a different claim from "not yet".
        await BundledKeynessBaseline.prepare()
        // ONE resolution of the live settings, shared by the tokenizer and the reference lookup —
        // the guard validates what a caller claims, not what its tokenizer was built with.
        let configuration = CollocationConfiguration.live()
        let availability = BundledKeynessBaseline.baseline(
            for: .allTerms, tuning: configuration.tuning,
            includeDiplomatic: configuration.includeDiplomatic)
        let reference: (terms: [String: Int], totalTokens: Int, cutoffCount: Int)
        switch availability {
        case .unavailable(.noArtifact), .unavailable(.lensNotPriced):
            collocation = .unavailable(.noArtifact); return
        case .unavailable(.configurationMismatch(let mismatches)):
            collocation = .unavailable(.configurationMismatch(mismatches)); return
        case .available(let terms, let total, let cutoff):
            reference = (terms, total, cutoff)
        }
        let generated = BundledKeynessBaseline.generated

        do {
            collocation = try await service.collocation(
            for: results, parameters: vm.submittedSearchParameters, windowSize: collocationWindow,
            configuration: configuration, reference: reference, generated: generated)
        } catch is CancellationError {
            // Switching modes or re-running a search cancels a scan in flight — the common case.
            // Writing a verdict here would replace a fresh panel with a stale one's failure, and
            // `.noMatches` would state something specific and false about the query.
            return
        } catch {
            collocation = .unavailable(.scanFailed)
        }
    }

    /// The capture sheet, extracted from the modifier chain: inlined, it pushed the body past the
    /// type-checker's budget outright.
    ///
    /// Captures the whole retained set, not the page — a corpus is the answer to a query, and a page
    /// is an accident of pagination.
    private var saveCorpusSheet: some View {
        SaveWorkingCorpusSheet(results: vm.displayedResults,
                               queryText: vm.submittedSearchParameters.keywords ?? "",
                               indexedVolumeCount: appState.indexedVolumeIds.count,
                               scope: resultSetScope)
    }

    private func openResult(_ entry: DocumentBrowserEntry) {
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
                                Task { await runSearch() }
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(result.header)
                // Checklist mode (#189-D): swipe (and the context menu) to mark a result
                // reviewed — hides it without opening it. Only offered while checklist mode is on.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if vm.checklistMode {
                        Button {
                            vm.markReviewed(volumeId: result.volumeId, documentId: result.documentId)
                        } label: {
                            Label(String(localized: "search.checklist.markReviewed.short",
                                         defaultValue: "Reviewed"),
                                  systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
                #if os(iOS)
                // The row opens the document IN THIS window by default (push); on Stage Manager, offer
                // "Open in New Window" as the explicit alternative that keeps the results list visible
                // alongside while several documents are opened in turn.
                .contextMenu {
                    if vm.checklistMode {
                        Button {
                            vm.markReviewed(volumeId: result.volumeId, documentId: result.documentId)
                        } label: {
                            Label(String(localized: "search.checklist.markReviewed",
                                         defaultValue: "Mark Reviewed"),
                                  systemImage: "checkmark.circle")
                        }
                        Divider()
                    }
                    if supportsMultipleWindows {
                        Button {
                            appState.openAuxWindow(DocumentWindowID(
                                volumeId: result.volumeId,
                                documentId: result.documentId,
                                header: result.header
                            ), from: sceneID, using: openWindow)
                        } label: {
                            Label(
                                String(localized: "search.result.openInNewWindow",
                                       defaultValue: "Open in New Window"),
                                systemImage: "rectangle.badge.plus"
                            )
                        }
                    }
                    Button {
                        // #241: on a Stage-Manager iPad the neighbor list opens as its own
                        // window, so it survives opening result after result from this list
                        // — the same reason `openResult` prefers a document window above.
                        // Elsewhere (iPhone, iPads without Stage Manager) it stays a sheet.
                        if supportsMultipleWindows {
                            appState.openAuxWindow(ArchivalNeighborsRequest.document(
                                volumeId:     result.volumeId,
                                documentId:   result.documentId,
                                documentYear: result.dateISO.flatMap { Int($0.prefix(4)) }
                            ), from: sceneID, using: openWindow)
                        } else {
                            archivalNeighborsTarget = ArchivalNeighborsDocKey(
                                volumeId:     result.volumeId,
                                documentId:   result.documentId,
                                documentYear: result.dateISO.flatMap { Int($0.prefix(4)) }
                            )
                        }
                    } label: {
                        Label(
                            String(localized: "search.result.archivalNeighbors",
                                   defaultValue: "Archival Neighbors…"),
                            systemImage: "archivebox"
                        )
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

// MARK: - ChecklistReviewedObserver

/// A zero-size, always-mounted observer that keeps the search view model's
/// `readSinceEnabledKeys` in sync with the local reading history while checklist mode is on
/// (#189-D). Backed by a live `@Query`, so a document opened by *any* means — pushed in place,
/// opened in a Stage-Manager sibling window, reached from timeline mode, or even read from
/// another screen — updates the reviewed set the moment its `ReadingHistoryEntry` lands, with no
/// fragile navigation/scene-phase triggers. Re-created (via `.id(enabledAt)`) whenever the anchor
/// moves (mode re-enable or a new search), so it always queries against the current cutoff.
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
        entries.map { SearchViewModel.reviewedKey(volumeId: $0.volumeId, documentId: $0.documentId) }
    }

    private func push() { onKeys(Set(reviewedKeys)) }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let result: SearchResult
    /// All known user tags, passed from the parent view's `vm.availableUserTags`.
    /// Forwarded to `SearchTagChipsRow` so UUID strings can be resolved to names.
    let userTags: [UserTag]
    let onUserTagTap: (String) -> Void

    /// Global default snippet length and this surface's override (#189-C); observed so the row
    /// re-renders live when either is changed in Settings or the search filter panel.
    @AppStorage(SearchDefaults.snippetLineCountKey) private var globalSnippetLines = SearchDefaults.defaultSnippetLineCount
    @AppStorage(SearchDefaults.snippetLineCountMainOverrideKey) private var snippetOverride = 0

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

            // Snippet — render <b>…</b> markers as highlighted text, clamped to the user's
            // chosen line count (#189-C).
            if !result.snippet.isEmpty {
                SearchSnippetView(snippet: result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(SearchDefaults.effectiveSnippetLineCount(global: globalSnippetLines, override: snippetOverride))
                    .padding(.top, 1)
            }

            // Classification chip (Source Explorer Phase 5) — derived from the
            // result's already-loaded source note, so no per-row query is added.
            if let note = result.sourceNote,
               let marking = SourceNoteParser.classificationMarking(fromSourceNote: note) {
                ClassificationChip(marking: marking)
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
        // #312 follow-up: full-row tap target (frame widens, contentShape makes the widened area
        // hit-testable; the enclosing row Button is `.buttonStyle(.plain)`, which hit-tests only
        // opaque content). NOTE this row nests its own tag chips: contentShape on the parent should
        // not shadow them, since SwiftUI hit-tests children before the parent's shape — if a chip
        // tap ever starts opening the document instead of filtering by the tag, this pair is the
        // first thing to suspect.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - SearchSnippetView

/// Renders an FTS5 snippet where `<b>` / `</b>` delimiters mark matched terms.
///
/// Matched terms are shown in the accent colour with medium weight; the surrounding
/// context text uses the inherited foreground style. Mirrors `SnippetView` in
/// `SearchSheet.swift` (used by the macOS search sheet and iOS search view).
struct SearchSnippetView: View {
    /// The raw snippet with `<b>…</b>` match markers.
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

// MARK: - SnippetLengthOverridePicker

/// A per-surface snippet-length override picker (#189-C): "Follow global" (`0`) plus 1…10 lines.
/// Bound to a persisted `@AppStorage` override; `0` defers to the global default set in Settings.
/// Reused by the main search filter panel and the add-document sheet.
struct SnippetLengthOverridePicker: View {
    /// The per-surface override binding (`0` = follow the global default).
    @Binding var override: Int

    var body: some View {
        Picker(String(localized: "search.snippet.override.label", defaultValue: "Snippet length"),
               selection: $override) {
            Text(String(localized: "search.snippet.override.followGlobal",
                        defaultValue: "Follow global")).tag(0)
            ForEach(1...10, id: \.self) { n in
                Text(SearchDefaults.snippetLinesLabel(n)).tag(n)
            }
        }
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
