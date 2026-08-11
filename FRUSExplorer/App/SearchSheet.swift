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
/// Selecting a result calls `AppState.openDocument(_:from: .tool(.search))`, which routes it to
/// this window's provenance host — the document window Search was launched from — falling back
/// (most-recently-key live host → mint a standalone window) when that host has closed. The search
/// window stays open.
///
/// ## Pending Search
/// `AppState.pendingSearch` (set by "Find all mentions" in `PersonDetailSheet`) is
/// observed here. On change the parameters are applied and a new search fires.
/// Producers open the window directly (`openWindow(id: "frus.search")`) alongside the
/// hand-off — the old MainWindowView opening relay is retired (provenance PR 2).
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

    /// Opens Archival Analytics scoped to this result set's volumes (#833).
    ///
    /// Extracted from the closure because the type-checker could not solve it inline — the
    /// facet panel's initializer is already a large expression.
    private func openArchivalProfile(volumeIds: [String]) {
        let term = searchVM.queryText.trimmingCharacters(in: .whitespaces)
        let label: String
        if term.isEmpty {
            label = String(localized: "facets.provenance.openProfile.label.results",
                           defaultValue: "Search results")
        } else {
            label = String(format: String(localized: "facets.provenance.openProfile.label %@",
                                          defaultValue: "Search: %@"), term)
        }
        appState.openArchivalScope(ArchivalScopeRequest(volumeIds: volumeIds, label: label),
                                   from: nil)
        appState.bindTool(.archivalAnalytics, to: appState.provenance(of: .search))
        openWindow.fronting(id: "frus.archivalAnalytics")
    }

    @State private var searchVM = MacSearchViewModel()

    /// Keyboard focus for the query field (#749 / audit L-35).
    ///
    /// The window had no focus machinery at all, so on first open the caret landed wherever AppKit's
    /// initial-first-responder pick put it, and on every re-summon it stayed on whatever was last
    /// focused — typing a query moved the result-list selection instead of editing text.
    @FocusState private var queryFieldFocused: Bool

    /// The Query Inspector's state for this window (Q-2).
    @State private var inspectorController = QueryInspectorController()

    /// The facet panel's state for this window (R-1).
    @State private var facetController = FacetPanelController()

    /// Whether the facet inspector column is showing. `@SceneStorage` so each window keeps
    /// its own choice.
    /// Was `@SceneStorage`; now per-session (#754 / audit L-45, owner decision: stop persisting).
    ///
    /// The flag survived a relaunch. The query, results and `FacetPanelController` it describes did
    /// not — they are `@State` — so the window could reopen with **the facet inspector extended over
    /// nothing**: a persisted description of discarded content. Restoring only the half that costs
    /// nothing to restore is worse than restoring neither, because the surviving half asserts the
    /// other one exists.
    @State private var showFacetPanel = false

    /// Whether the inspector's detail rows are showing. `@SceneStorage` so the choice is
    /// remembered per window, as the design asks, rather than globally.
    /// Same reasoning as `showFacetPanel` (#754 / L-45): the Query Inspector describes a search
    /// that does not survive the relaunch either.
    @State private var inspectorExpanded = false

    @State private var showAdvancedFilters = false
    @State private var showTimeline = false
    /// Concordance mode (R-3b). Mutually exclusive with the timeline — both replace the results list.
    @State private var showConcordance = false
    @State private var concordance = ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
    @State private var concordanceSort: KWICSort = .leftContext
    /// Collocates mode (S-2). Mutually exclusive with the other two — all three replace the list.
    @State private var showCollocates = false
    @State private var showSaveCorpusSheet = false
    @State private var collocation: CollocationAnalysis.Outcome = .pending
    @State private var isLoadingCollocation = false
    /// macOS had no concordance loading indicator at all: `rebuildConcordance` set nothing, so a
    /// slow rebuild simply looked frozen. Added here because a collocation scan is heavier still.
    @State private var isLoadingConcordance = false
    @AppStorage(SearchCollocationDefaults.windowKey) private var collocationWindow = 10
    @AppStorage(SearchCollocationDefaults.orderKey)
    private var collocationOrderRaw = CollocationOrder.evidence.rawValue
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

    /// All known projects, for resolving the active project's name in the advanced
    /// filter panel's project-scope picker (#377 Phase 2).
    @Query private var allProjects: [Project]

    var body: some View {
        // The S6 boot guard, which this window never had — the same one `PeopleWindowView` and
        // `CitationLookupView` carry so a restored window "never renders the definitive empty
        // state as a lie".
        //
        // Without it, a Search window that came up before the search stack existed answered every
        // query with "No Results. Try different keywords." over an index holding 316,839
        // documents, left Facets disabled, and rendered the Advanced popover as an empty box —
        // three symptoms of one absence, none of them saying so.
        if appState.searchService == nil {
            ProgressView(String(localized: "search.preparingIndex",
                                defaultValue: "Preparing your index…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            loadedBody
        }
    }

    /// The window proper, once there is an index behind it.
    private var loadedBody: some View {
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

            // #377 Phase 5: the ambient "Working on: <question>" lens (self-padded; zero height when inactive).
            WorkingOnBanner()
            workingCorpusBanner

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                scopeRow
                filterRow
                documentTypeRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            queryInspectorStrip

            sortBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Divider()

            overCapAdvisory

            checklistHiddenBanner

            if searchVM.checklistMode && searchVM.displayedResults.isEmpty && !searchVM.results.isEmpty {
                // Checklist mode has hidden every result (#189-D).
                allReviewedEmptyState
            } else if hasZeroResults {
                // macOS had NO zero-result state at all before Q-2: the chain fell through
                // to `resultsList`, which rendered an empty `List`, and the only zero-result
                // copy anywhere was the sort bar's "No results".
                //
                // Placement is load-bearing. This must precede `showTimeline`, which has no
                // emptiness condition of its own — after it, a zero-result search with the
                // timeline toggled on would render an empty timeline and the decomposition
                // would never evaluate. There is nothing to preserve in either mode when
                // the result set is empty.
                //
                // `MacSearchViewModel` has no `hasSearched`; `submittedQuery` is the
                // equivalent, since only `submitSearch()` sets it.
                QueryZeroResultView(
                    inspection: inspectorController.inspection
                        ?? QueryInspection(expression: nil, operands: [],
                                           indexedVolumeCount: appState.indexedVolumeIds.count,
                                           isFilterOnly: false),
                    emptyConjuncts: inspectorController.emptyConjuncts)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task(id: searchVM.searchTrigger) {
                        await inspectorController.decomposeZeroResult(
                            parameters: searchVM.submittedSearchParameters,
                            service: appState.searchService)
                    }
            } else if showCollocates {
                CollocationView(
                    scope: resultSetScope,
                    outcome: collocation,
                    windowSize: $collocationWindow,
                    order: Binding(get: { CollocationOrder(rawValue: collocationOrderRaw) ?? .evidence },
                                   set: { collocationOrderRaw = $0.rawValue }),
                    isLoading: isLoadingCollocation)
            } else if showConcordance {
                concordancePanel
            } else if showTimeline {
                timelineView
            } else if searchVM.isSearching, searchVM.results.isEmpty {
                // A dedicated branch, NOT a background on `resultsList`.
                //
                // The first attempt attached the cloud as `.background` of the List and it
                // was never visible on macOS. Measured on this platform, rendering the same
                // composition off-screen and counting pixels of a solid backdrop colour:
                //
                //     control, no List ......................... 100.0%
                //     List(.plain) + .background ................ 20.8%   <- what shipped
                //     List(.plain) + scrollContentBackground(.hidden)  20.8%
                //     EMPTY List(.plain) + .background .......... 20.8%
                //     greedy ProgressView + .background ......... 98.7%   <- this branch
                //
                // Two things worth keeping from that. An EMPTY list occludes just as much as
                // a populated one, so "the list has no rows, the background will show" is
                // false. And `.scrollContentBackground(.hidden)` — the obvious fix, and the
                // one the P-2 integration map suggested — changes nothing here at all.
                //
                // Replacing the list is sound precisely because this branch requires
                // `results.isEmpty`: there is nothing on screen to preserve. macOS's
                // deliberate keep-the-previous-results behaviour is untouched, because that
                // case takes the `else` below.
                firstSearchPendingView
            } else {
                resultsList
            }

            // Hoisted out of the results-list branch. It was unreachable under the concordance,
            // which covers exactly the page on screen (`SearchService.concordance` takes the
            // caller's displayed page) — so a macOS user could read the first page's occurrences
            // and had no control to reach the second. It must stay hidden under the timeline and
            // the collocates panel, which cover the whole retained set.
            if ResultReading.active(timeline: showTimeline,
                                    concordance: showConcordance,
                                    collocates: showCollocates).isPaged,
               searchVM.totalPages > 1 {
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
        // The facet panel (R-1). `.inspector` is the macOS idiom the design asks for; the
        // *toggle* lives in the sort bar rather than the titlebar because
        // `MacSearchWindowView` has no `.toolbar` at all — verified, zero occurrences — so
        // the design's "toggled from a titlebar inspector button" has no host. Adding one
        // would change this window's chrome, which is a separate decision from shipping the
        // panel; the sort bar already carries the timeline and checklist toggles, so the
        // control sits with its siblings.
        .inspector(isPresented: $showFacetPanel) {
            FacetPanelView(
                controller: facetController,
                matchCount: searchVM.totalMatchCount,
                displayedCount: searchVM.displayedResults.count,
                isPartialEvidence: resultSetScope.isPartialEvidence,
                isChecklistHiding: searchVM.checklistMode
                    && searchVM.displayedResults.count < searchVM.results.count,
                onNarrow: { narrowing in
                    // Captured here because the narrow re-runs the search, and by the time
                    // the panel recomputes, its match count describes the narrowed set.
                    facetController.recordNarrowing(from: searchVM.totalMatchCount)
                    narrowing.apply(to: &searchVM.parameters)
                    searchVM.parametersVersion += 1
                },
                onApplySelection: { section, keys in
                    facetController.recordNarrowing(from: searchVM.totalMatchCount)
                    FacetSelectionApplier.apply(section, keys: keys, to: &searchVM.parameters)
                    searchVM.parametersVersion += 1
                },
                onOpenArchivalProfile: { openArchivalProfile(volumeIds: $0) },
                onDiscloseSection: { section in
                    Task {
                        await facetController.load(
                            section,
                            parameters: searchVM.submittedSearchParameters,
                            service: appState.searchService,
                            pipeline: appState.indexingPipeline)
                    }
                })
                .inspectorColumnWidth(min: 240, ideal: 300, max: 420)
        }
        .task(id: searchVM.searchTrigger) {
            await searchVM.performSearch(service: appState.searchService)
            searchVM.recordSearchHistory(projectId: appState.activeProjectId,
                                         indexedVolumeCount: appState.indexedVolumeIds.count,
                                         in: modelContext)
            // A new result set invalidates every computed section. Keyed on the same trigger
            // the search itself uses, so a facet can never describe a previous match.
            facetController.invalidate(signature: searchVM.searchTrigger)
        }
        // Keyed on the *live* text plus the filter version, not `searchTrigger`, so the
        // inspector explains the query as it is being typed — the design's "a researcher
        // learns NEAR by watching the expression change". The controller debounces, so a
        // keystroke costs nothing until typing settles.
        .task(id: "\(searchVM.queryText)|\(searchVM.parametersVersion)") {
            await inspectorController.refresh(
                parameters: searchVM.liveSearchParameters,
                service: appState.searchService,
                indexedVolumeCount: appState.indexedVolumeIds.count)
        }
        // R-3b: rebuild the concordance for the page on screen. `sort` is not a trigger — ordering is
        // applied at render time, and making it a fetch would stall a control that must feel instant.
        .task(id: ConcordanceRebuildKey(mode: showConcordance, rows: searchVM.pagedResults,
                                        version: searchVM.executedSearchVersion)) {
            await rebuildConcordance()
        }
        // Put the caret in the query field when the window first appears (#749 / audit L-35).
        // `.defaultFocus` alone is not trusted here: `CitationLookupView` — the sibling find window —
        // needed `.defaultFocus` PLUS a `.task` fallback because, in its own words, defaultFocus
        // "never landed". A one-tick delay lets the field exist before focus is assigned.
        .task {
            await Task.yield()
            queryFieldFocused = true
        }
        // And again on every ⌘S / toolbar-Search re-summon. Re-fronting a singleton window runs no
        // code inside it and never resets first responder, so without this the caret stayed on
        // whatever was last focused — typing a query drove the result-list selection instead. Same
        // shape as `DocumentFindBar`'s `focusToken` (the established in-repo pattern).
        .onChange(of: appState.searchQueryFocusToken) { _, _ in
            queryFieldFocused = true
        }
        // Same rollup-renumbering hazard as iOS (#747), in a window that can sit open for days.
        .onChange(of: appState.personRollupGeneration) { _, _ in
            Task {
                if await searchVM.refreshPersonRollupBinding(using: appState.personMentionStore) {
                    await searchVM.performSearch(service: appState.searchService)
                }
            }
        }
        // A dropped person filter changes the result set, so it is announced rather than left for
        // the user to notice that a chip is missing (#747). Rare by construction: it fires only
        // when the anchor's volume has left the index.
        .alert(String(localized: "search.person.filterDropped.title",
                      defaultValue: "Person filter cleared"),
               isPresented: Binding(get: { searchVM.droppedPersonFilterNotice != nil },
                                    set: { if !$0 { searchVM.droppedPersonFilterNotice = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(searchVM.droppedPersonFilterNotice ?? "")
        }

        .task {
            // Consume search parameters set *before* this window was opened.
            // `.onChange` only fires on subsequent value changes — it misses the
            // initial `pendingSearch` that was already set when the Window scene
            // created a fresh `MacSearchWindowView` instance.
            if let params = appState.consumeHandoff(\.pendingSearch, for: .macSearch) {
                searchVM.applyParameters(params)
            }
        }
        // Not keyed on the page: a collocation reads the whole retained set, so paging changes
        // nothing about the answer. Keyed on the window, which does.
        .sheet(isPresented: $showSaveCorpusSheet) {
            SaveWorkingCorpusSheet(
                results: searchVM.displayedResults,
                queryText: searchVM.submittedSearchParameters.keywords ?? "",
                indexedVolumeCount: appState.indexedVolumeIds.count,
                scope: resultSetScope)
        }
        .task(id: CollocationRebuildKey(mode: showCollocates, window: collocationWindow,
                                        version: searchVM.executedSearchVersion)) {
            await rebuildCollocation()
        }
        .onChange(of: appState.pendingSearch) { _, _ in
            guard let params = appState.consumeHandoff(\.pendingSearch, for: .macSearch) else { return }
            searchVM.applyParameters(params)
        }
        .onChange(of: appState.indexGeneration) { _, _ in
            searchVM.results = []
            searchVM.queryText = ""
        }
        // Project History scope (#377 Phase 2a): the macOS Search window is a persistent
        // Window scene, so an active-project change must reset the scope and drop any stale
        // `documentIds` gate — otherwise a search picked to "this project's documents" for
        // project A would keep gating results to A's set after the user switched to B.
        .onChange(of: appState.activeProjectId) { _, _ in
            refreshProjectScope(resetSelection: true)
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
                    .focused($queryFieldFocused)
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
                openWindow.fronting(id: "frus.citationLookup")
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

                // #756 retired the #258 Q4(a) disclosure. It read "The volume scope is not saved
                // with the search — re-apply it after running the saved search", which was true
                // when SavedSearch flattened SearchParameters into columns and dropped eight of
                // twenty fields. The whole value is now archived, so the volume scope IS saved —
                // and the notice had become a false warning telling users to redo work the app had
                // already done. Removing it is part of the fix, not a cosmetic tidy.
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

    // MARK: - Project Scope (#377 Phase 2a)

    /// (Re)loads the active project's engaged-document set into the advanced-filter VM and
    /// re-applies the resulting `documentIds` gate to the executed query. The single path
    /// for keeping the macOS project scope live — called both when the Advanced-filter
    /// panel opens and when the active project changes.
    ///
    /// - Parameter resetSelection: when `true`, first resets the scope to `.off` (used on an
    ///   active-project change, so a History selection never silently carries to a different
    ///   project); when `false`, preserves the current selection (used when merely reopening
    ///   the panel for the same project).
    ///
    /// No-ops when the filter VM does not yet exist (the panel has never been opened, so no
    /// scope can be active and `parameters.documentIds` is already `nil`).
    private func refreshProjectScope(resetSelection: Bool) {
        guard let fvm = searchVM.filterVM else { return }
        if resetSelection {
            fvm.projectScope = .off
            fvm.projectOnlyNew = false
        }
        guard let pid = appState.activeProjectId else {
            fvm.projectScope = .off
            fvm.projectOnlyNew = false
            fvm.projectEngagedDocumentKeys = []
            fvm.projectFocusVolumeIds = []
            fvm.projectScopeName = nil
            searchVM.applyProjectScope()
            return
        }
        let project = allProjects.first { $0.id == pid }
        fvm.projectScopeName = project?.name
        // Focus volumes resolve from the project's subjects via the bundled profiles — an
        // in-memory lookup, so set synchronously (#377 Phase 2b).
        fvm.projectFocusVolumeIds = SearchViewModel.focusVolumeIds(for: project)
        // Compute the engaged set on a background context so a large library never freezes
        // the UI (#377 Phase 2a fix). The scalar name is set synchronously (cheap); the
        // key set arrives asynchronously and re-applies the scope when ready. Sorted so an
        // unchanged set compares equal in `applyProjectScope` (no spurious re-search).
        let container = modelContext.container
        Task {
            let keys = await ProjectEngagedDocuments.keys(forProject: pid, container: container)
            fvm.projectEngagedDocumentKeys = keys.sorted()
            searchVM.applyProjectScope()
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

            // #775: the Years facet's set is a filter the date chip cannot represent — a set of
            // years is not an interval — so it needs a chip of its own or it would be in force
            // with nothing on screen saying so.
            FilterChip(
                label: "Years",
                value: searchVM.yearFilterLabel,
                isActive: searchVM.parameters.yearKeys != nil
            ) { searchVM.clearYearFilter() }
            .help(String(
                localized: "search.filter.years.help",
                defaultValue: "Years chosen in the facet panel. Matches a document's start year, which is what the facet counts. Tap × to clear."
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
                label: "Person",
                value: searchVM.personFilterLabel,
                isActive: searchVM.personFilterLabel != nil
            ) { searchVM.clearPersonFilter() }
            .help(String(
                localized: "search.filter.person.help",
                defaultValue: "Person filter — set from the People facet or the filter sheet. Tap × to clear."
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
                // Open the popover IMMEDIATELY, then load the project-scope engaged set
                // off the main thread (#377 Phase 2a fix). Doing the fetch synchronously
                // here froze the UI on a large library and made the popover appear not to
                // display at all.
                showAdvancedFilters = true
                refreshProjectScope(resetSelection: false)
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
                // `filterVM` is created by `syncToFilterVM` only once `appState.searchService`
                // exists. When it does not, this used to render nothing at all — a zero-size
                // popover, which reads as a control that simply does not work. The guard above
                // should make that unreachable now; this stays because "unreachable" is a claim
                // about today's scene graph, and the failure it replaces was silent.
                if searchVM.filterVM == nil {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text(String(localized: "search.filters.preparing",
                                    defaultValue: "Filters aren’t ready yet — the index is still loading."))
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .frame(width: 320)
                }
                if let filterVM = searchVM.filterVM {
                    // `filterVM` is the sheet's own view model and `syncToFilterVM` copies
                    // `phrase` but not `keywords`, so counting against its own parameters
                    // would describe a different result set than the one behind the sheet.
                    SearchFilterView(vm: filterVM,
                                     tagCountParameters: searchVM.submittedSearchParameters)
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

    /// The blank area a fresh Search window shows while its first query runs.
    ///
    /// Only reachable with an empty result set, so it never displaces results. The sort
    /// bar's own "Searching…" indicator stays as it is — this fills the space below it.
    private var firstSearchPendingView: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pendingCloudBackdrop(
                scope: CloudSurfaceArbiter.searchScope(
                    volumeIds: searchVM.parameters.volumeIds,
                    manifest: appState.manifestStore),
                isPending: true
            )
    }

    // MARK: - Sort Bar

    /// Whether a search has run and returned nothing.
    ///
    /// `MacSearchViewModel` has no `hasSearched` flag; `submittedQuery` is non-empty only
    /// after `submitSearch()`, which is the same signal.
    private var hasZeroResults: Bool {
        !searchVM.isSearching
            && searchVM.results.isEmpty
            && !searchVM.submittedQuery.trimmingCharacters(in: .whitespaces).isEmpty
            && searchVM.searchError == nil
    }

    /// The Query Inspector strip: what the query became, between the control rows and the
    /// sort bar (Q-2).
    ///
    /// Hidden entirely until there is something to say. The expression row itself never
    /// collapses once present — decision Q-2-2 — only the detail rows do, and that state
    /// is remembered per window.
    @ViewBuilder
    private var queryInspectorStrip: some View {
        if let inspection = inspectorController.inspection,
           inspection.expression != nil || inspection.isFilterOnly {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    QueryInspectorStrip(
                        inspection: inspection,
                        isExpanded: inspectorExpanded,
                        isCountingScoped: inspectorController.isCountingScoped,
                        onRequestScopedCounts: {
                            Task {
                                await inspectorController.loadScopedCounts(
                                    parameters: searchVM.submittedSearchParameters,
                                    service: appState.searchService)
                            }
                        })
                    Button {
                        inspectorExpanded.toggle()
                    } label: {
                        Image(systemName: inspectorExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(inspectorExpanded
                          ? String(localized: "search.inspector.collapse", defaultValue: "Hide term detail")
                          : String(localized: "search.inspector.expand", defaultValue: "Show term detail"))
                    .accessibilityLabel(inspectorExpanded
                          ? String(localized: "search.inspector.collapse", defaultValue: "Hide term detail")
                          : String(localized: "search.inspector.expand", defaultValue: "Show term detail"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .background(.quaternary.opacity(0.35))
            Divider()
        }
    }

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
            // Facet panel toggle (R-1). Placed here rather than the titlebar because this
            // window has no toolbar to hang it from — see the `.inspector` comment.
            Button {
                showFacetPanel.toggle()
            } label: {
                Label(String(localized: "search.facets.short", defaultValue: "Facets"),
                      systemImage: "chart.bar.doc.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(showFacetPanel ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            .help(showFacetPanel
                  ? String(localized: "search.facets.off.help",
                           defaultValue: "Hide the result-set facets")
                  : String(localized: "search.facets.on.help.v2",
                           defaultValue: "Break the whole match down by year, volume, person, type and provenance — before any narrowing you apply"))
            .accessibilityLabel(String(localized: "search.facets.a11y",
                                       defaultValue: "Result-set facets"))

            Divider().frame(height: 16)

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
                if showTimeline { showConcordance = false; showCollocates = false }
            } label: {
                Image(systemName: showTimeline ? "chart.bar.fill" : "chart.bar")
                    .font(.system(size: 12))
                    .foregroundStyle(showTimeline ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            // Its own tooltip and label at last. These strings previously sat on the CONCORDANCE
            // button — a second, stacked `.help` that silently won, plus the timeline's
            // accessibility label attached to the wrong control — so the timeline toggle had
            // neither and the concordance announced itself as the timeline.
            .help(showTimeline
                  ? String(localized: "search.timeline.hide.help",
                           defaultValue: "Hide the chronological timeline and show the results list")
                  : String(localized: "search.timeline.show.help",
                           defaultValue: "Show these results as a chronological timeline"))
            .accessibilityLabel(showTimeline
                ? String(localized: "search.timeline.hide.a11y", defaultValue: "Hide timeline")
                : String(localized: "search.timeline.show.a11y", defaultValue: "Show timeline"))

            Button {
                showConcordance.toggle()
                if showConcordance { showTimeline = false; showCollocates = false }
            } label: {
                // `text.alignright` when off meant macOS showed, for the INACTIVE state, the very
                // symbol iOS uses for the ACTIVE one. Tint already carries the state on this bar
                // (every neighbour does it that way), so the glyph should simply stay put.
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12))
                    .foregroundStyle(showConcordance ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            .help(showConcordance
                  ? String(localized: "search.kwic.hide.help",
                           defaultValue: "Hide the concordance and show the results list")
                  : String(localized: "search.kwic.show.help.v2",
                           defaultValue: "Show every occurrence of your term on its own line, aligned — for the documents on this page"))
            .accessibilityLabel(showConcordance
                ? String(localized: "search.kwic.hide.a11y", defaultValue: "Hide concordance")
                : String(localized: "search.kwic.show.a11y", defaultValue: "Show concordance"))

            Button {
                showCollocates.toggle()
                if showCollocates { showTimeline = false; showConcordance = false }
            } label: {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 12))
                    .foregroundStyle(showCollocates ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.results.isEmpty)
            .help(showCollocates
                  ? String(localized: "search.collocates.hide.help",
                           defaultValue: "Hide the collocates and show the results list")
                  : String(localized: "search.collocates.show.help",
                           defaultValue: "Show which words appear near your search term across all of these results"))
            .accessibilityLabel(showCollocates
                ? String(localized: "search.collocates.hide.a11y", defaultValue: "Hide collocates")
                : String(localized: "search.collocates.show.a11y", defaultValue: "Show collocates"))

            Divider().frame(height: 14)

            // Behind the divider, after the three readings rather than wedged between two of
            // them. Timeline / Concordance / Collocates are mutually exclusive ways of looking at
            // the set; this writes a durable `WorkingCorpus` and is the only one of the four with
            // an effect that outlives the search. It also gates on `displayedResults` where the
            // readings gate on `results`.
            Button {
                showSaveCorpusSheet = true
            } label: {
                Image(systemName: "tray.full")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(searchVM.displayedResults.isEmpty)
            .help(String(localized: "search.corpus.save.help",
                         defaultValue: "Save these results as a named working corpus you can search inside later"))
            .accessibilityLabel(String(localized: "search.corpus.save",
                                       defaultValue: "Save as Working Corpus…"))

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
        // `nil` when the concurrent COUNT(*) did not come back. Previously this fell back
        // to the fetched count, which made a truncated set look complete — see
        // `MacSearchViewModel.totalMatchCount`.
        let total: Int? = searchVM.totalMatchCount.map { max($0, loaded) }
        let start    = searchVM.currentPage * searchVM.pageSize + 1
        let end      = min(start + searchVM.pageSize - 1, loaded)
        let truncated = searchVM.isResultSetTruncated

        // Inside a corpus that was itself a capped capture, BOTH `loaded` and `total` describe
        // the corpus-scoped query — so the ordinary "267 loaded · 267 total" reads as a complete
        // set, which is the claim #607 removed on iOS and left standing here. The corpus branch
        // drops both figures rather than qualifying them: neither is the denominator a reader
        // would want, and the corpus's own capture total is.
        let corpusClause = resultSetScope.corpusCaptureClause

        HStack(spacing: 6) {
            if loaded == 0 {
                Text("No results")
                    .font(.system(size: 11, weight: .medium))
            } else if let corpusClause, loaded <= searchVM.pageSize {
                Text("\(loaded.formatted()) in this corpus · \(corpusClause)")
                    .font(.system(size: 11, weight: .medium))
            } else if let corpusClause {
                Text("\(start)–\(end) of \(loaded.formatted()) in this corpus · \(corpusClause)")
                    .font(.system(size: 11, weight: .medium))
            } else if let total, loaded <= searchVM.pageSize {
                Text("\(loaded) of \(total.formatted()) result\(total == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
            } else if let total {
                Text("\(start)–\(end) of \(loaded.formatted()) loaded · \(total.formatted()) total")
                    .font(.system(size: 11, weight: .medium))
            } else if loaded <= searchVM.pageSize {
                Text("\(loaded) loaded · total unavailable")
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text("\(start)–\(end) of \(loaded.formatted()) loaded · total unavailable")
                    .font(.system(size: 11, weight: .medium))
            }

            // "narrowed from N" (R-1). Shown only while the facet panel is open, because that
            // is when the pre-narrowing figure is on screen to be narrowed *from* — outside
            // that context it is a number with no referent.
            if showFacetPanel, let pre = facetController.narrowedFrom,
               let total, pre > total {
                Text(String(localized: "search.narrowedFrom",
                            defaultValue: "· narrowed from \(pre.formatted())"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if truncated {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .help(
                        total.map {
                            String(
                                localized: "search.cap.tooltip",
                                defaultValue:
                                    "Showing \(loaded.formatted()) of \($0.formatted()) matches. Narrow your search with a date range, volume filter, or more specific terms to see every result."
                            )
                        } ?? String(
                            localized: "search.cap.tooltip.unknownTotal",
                            defaultValue:
                                "Showing the first \(loaded.formatted()) matches. The total could not be counted, so there may be many more — narrow your search with a date range, volume filter, or more specific terms."
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

    /// Which set this window is showing. Unlike iOS, macOS holds a real whole-query count, so the
    /// sentences that can name a total will name one here and not there.
    /// The concordance branch, lifted out of the reading chain.
    ///
    /// Not cosmetic: the chain is a `ViewBuilder` `if/else if` over five branches, and adding one
    /// member to ``ResultSetScope`` pushed the whole expression past the type-checker's budget
    /// ("unable to type-check this expression in reasonable time"). Extracting the largest branch
    /// gives the solver a boundary.
    @ViewBuilder
    private var concordancePanel: some View {
        ConcordanceView(scope: resultSetScope, result: concordance, sort: $concordanceSort) { line in
            // Same destination a results-list row reaches, so a concordance line and a row
            // behave identically.
            if let result = searchVM.pagedResults.first(where: {
                $0.volumeId == line.volumeId && $0.documentId == line.documentId
            }) {
                selectedResultId = result.id
                navigateToResult(result)
            }
        }
        // Matches SearchView's overlay. macOS had none, so a rebuild simply looked frozen.
        .overlay { if isLoadingConcordance { ProgressView() } }
    }

    /// The applied working corpus, named on the window it governs.
    ///
    /// The macOS half of iOS's `workingCorpusBanner`, which #606 added on one platform only. Until
    /// now the Mac named the corpus nowhere: `activeFilterSummary` contributes the bare token
    /// "corpus" among other filter names, so the only positive signal that a document-grain scope
    /// was in force was the result count changing when it was removed.
    ///
    /// Placed with `WorkingOnBanner` rather than in the filter row, because it is a statement
    /// about what the window is showing rather than a control — the same reasoning that put it
    /// above the results on iOS.
    @ViewBuilder
    private var workingCorpusBanner: some View {
        if let name = searchVM.filterVM?.appliedWorkingCorpusName {
            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(format: String(localized: "search.corpusScope.label %@",
                                           defaultValue: "Inside “%@”"), name))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Button {
                    searchVM.filterVM?.clearWorkingCorpus()
                    searchVM.applyAdvancedFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "search.corpusScope.clear.help",
                             defaultValue: "Leave this working corpus and search the full scope again"))
                .accessibilityLabel(String(localized: "search.corpusScope.clear.a11y",
                                           defaultValue: "Leave this working corpus"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private var resultSetScope: ResultSetScope {
        ResultSetScope(loaded: searchVM.results.count,
                       shown: searchVM.displayedResults.count,
                       fetchLimit: MacSearchViewModel.searchHardLimit,
                       totalMatchCount: searchVM.totalMatchCount,
                       documentsOnPage: searchVM.pagedResults.count,
                       pageCount: searchVM.totalPages,
                       appliedCorpusTruncation: searchVM.filterVM?.appliedWorkingCorpusTruncation)
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
            let total  = searchVM.totalMatchCount?.formatted()
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    // The warning must survive an unavailable count — that combination is
                    // exactly the case that used to render as "complete".
                    Text(total.map { "Showing \(loaded) of \($0) matches" }
                         ?? "Showing the first \(loaded) matches — the total is unavailable")
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
        VStack(spacing: 0) {
            // Above the chart, as on iOS. The over-cap advisory two rows up reports a SIZE; this
            // is the only thing on screen that says the plotted SHAPE is a relevance ranking's,
            // not the whole match's.
            if let bias = resultSetScope.timelineBiasCaption {
                Text(bias)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
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
                    // Default click routes to this Search window's provenance host
                    // (navigateToResult → appState.openDocument); offered explicitly here too.
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
                        // result list survives every row navigation. The spawned window
                        // inherits this Search window's provenance (transitive bind).
                        let request = ArchivalNeighborsRequest.document(
                            volumeId:     result.volumeId,
                            documentId:   result.documentId,
                            documentYear: result.dateISO.flatMap { Int($0.prefix(4)) }
                        )
                        appState.bindTool(.archivalNeighbors(request),
                                          to: appState.provenance(of: .search))
                        openWindow(value: request)
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
                TipItem(code: "NEAR(a b, 30)",    description: "proximity — both within 30 words of each other; operands may be phrases or term*")
                TipItem(code: "=word",            description: "exact word — \"=containment\" excludes contain, containing, container")
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
    /// to. Opens `frus.analytics` DIRECTLY (the MainWindowView relay is retired —
    /// provenance PR 2), binding it to this Search window's own provenance;
    /// `AnalyticsView` applies the parameters and runs the chart query immediately.
    private func openSearchInAnalytics() {
        let term = searchVM.submittedQuery.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        appState.openAnalytics(
            AnalyticsParameters(
                term: term,
                yearRangeStart: searchVM.parameters.dateRange?.earliest.flatMap(Self.isoYear),
                yearRangeEnd: searchVM.parameters.dateRange?.latest.flatMap(Self.isoYear)
            ),
            from: nil
        )
        appState.bindTool(.analytics, to: appState.provenance(of: .search))
        openWindow.fronting(id: "frus.analytics")
    }

    /// Extracts the four-digit year from an ISO `yyyy-MM-dd` date string, as
    /// stored in `DateRange.earliest`/`latest`. Returns `nil` for malformed input.
    private static func isoYear(_ isoDate: String) -> Int? {
        Int(isoDate.prefix(4))
    }

    /// Opens the result in this Search window's provenance host (the window the user
    /// launched Search from), resolved through the fallback chain when that host has closed.
    private func navigateToResult(_ result: SearchResult) {
        appState.openDocument(DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        ), from: .tool(.search), using: openWindow)
    }

    /// Opens the result in its own document window, leaving the Search window and
    /// the main window untouched (so the results list stays put). macOS shows it as
    /// a tab or a separate window per the user's "Prefer tabs when opening documents"
    /// setting (System Settings ▸ Desktop & Dock) — document windows share one
    /// `WindowGroup`, so they tab together. Per-document identity means reopening the
    /// same document focuses its existing window/tab.
    /// Builds the concordance for the page on screen (R-3b).
    ///
    /// The macOS twin of `SearchView.rebuildConcordance()`. Deliberately concordances
    /// `pagedResults` rather than `results`: this window retains up to 7,500 results, and fetching
    /// body text for all of them would be ~37 MB for a view showing twenty lines.
    private func rebuildConcordance() async {
        guard showConcordance, let service = appState.searchService else { return }
        let page = searchVM.pagedResults
        guard !page.isEmpty else {
            concordance = ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
            return
        }
        isLoadingConcordance = true
        defer { isLoadingConcordance = false }
        concordance = (try? await service.concordance(
            for: page, parameters: searchVM.submittedSearchParameters))
            ?? ConcordanceResult(lines: [], omittedCount: 0, documentsWithoutLines: 0)
    }

    /// Recomputes the collocation over the whole retained result set.
    ///
    /// `displayedResults`, not `pagedResults`: a measure over one page cannot clear its own floor.
    /// This window retains up to 7,500 results, so the scan is bounded by a match budget rather than
    /// by document count — see `SearchService.collocationMatchBudget`.
    private func rebuildCollocation() async {
        guard showCollocates, let service = appState.searchService else { return }
        let results = searchVM.displayedResults
        guard !results.isEmpty else { collocation = .unavailable(.noMatches); return }
        isLoadingCollocation = true
        defer { isLoadingCollocation = false }

        await BundledKeynessBaseline.prepare()
        // ONE resolution of the live settings, shared by the tokenizer and the reference lookup.
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

        do {
            collocation = try await service.collocation(
            for: results, parameters: searchVM.submittedSearchParameters,
            windowSize: collocationWindow, configuration: configuration,
            reference: reference, generated: BundledKeynessBaseline.generated)
        } catch is CancellationError {
            // Switching modes or re-running a search cancels a scan in flight — the common case.
            // Writing a verdict here would replace a fresh panel with a stale one's failure, and
            // `.noMatches` would state something specific and false about the query.
            return
        } catch {
            collocation = .unavailable(.scanFailed)
        }
    }

    private func openResultInNewWindow(_ result: SearchResult) {
        // Mint from the full result payload (widened DocumentWindowID) so the new window renders
        // the same document chrome as a routed open — matching navigateToResult's entry fields.
        openWindow(value: DocumentWindowID(entry: DocumentBrowserEntry(
            documentId: result.documentId,
            volumeId: result.volumeId,
            documentNumber: result.documentNumber,
            header: result.header,
            dateline: result.dateline,
            sourceNote: result.sourceNote,
            isEditorialNote: result.isEditorialNote
        )))
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
        // #312 follow-up: full-row tap target — both modifiers, in this order. The macOS Search
        // window is a separate implementation from the iOS `SearchView` (see the parallel fix to
        // `SearchView.SearchResultRow`), so this had to be ported rather than inherited.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
