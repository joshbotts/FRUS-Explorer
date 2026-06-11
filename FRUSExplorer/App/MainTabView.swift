// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - MainTabView

/// Root tab bar view for FRUS Explorer on iOS.
///
/// Uses the iOS 18+ `Tab` API with `value:` parameter so `appState.activeTab`
/// drives selection and persists across launches. All five tabs are fully wired
/// as of Session 44.
///
/// ## Badges
/// - **Activity** tab: count of `ResearchNote`s with `createdAt` newer than
///   `appState.lastActivityTabVisit`. Cleared automatically when the user selects
///   the Activity tab (the timestamp is stamped in the `.onChange` handler).
/// - **Settings** tab: count of downloaded-but-unindexed volumes, via
///   `appState.unindexedVolumeCount`. Prompts the user to run Reindex.
///
/// `MainTabView` is instantiated by `ContentView` on iOS after the user has
/// completed onboarding. macOS continues to use `BrowserView` directly.
///
/// Version history:
///   1.0 — Session 43: initial iOS tab shell with Browse + 4 placeholder tabs
///   1.1 — Session 44: all four placeholder tabs wired with real content
///   1.2 — Session 45: activity + settings badges; lastActivityTabVisit stamping
///   1.3 — Session 56: Settings badge changed from raw count to boolean "·" indicator
///          (HIG: badges must represent actionable user-driven information, not status
///          counts; a simple dot communicates "attention needed" without implying
///          the number is an actionable queue)
///   1.4 — Session 93: IndexingBannerView wired via .safeAreaInset(edge: .bottom) on
///          each tab's root view; ActivityKit / Live Activity deferred (see
///          IndexingBannerView.swift); banner visible across all tabs during indexing
///   1.5 — Session 99: Analytics toolbar button in BrowserTabView; AnalyticsView sheet
///   1.6 — Session 114: IndexingSummaryCard shown when completedIndexingMetadata non-nil;
///          transitions between banner ↔ card via .move + .opacity
///   1.7 — Session 130: Activity tab replaced by Research tab (ResearchView); no badge
///          on Research tab (it is a navigation tool, not an inbox)
///   1.8 — Session 159: `.tabViewStyle(.sidebarAdaptable)` — iPad renders the tabs as a
///          native adaptive sidebar (BigPicture-iPadMacParity Phase 1); iPhone keeps the
///          bottom tab bar unchanged. Each tab's own NavigationSplitView/Stack becomes
///          the sidebar's detail content, so no nested split view is introduced.
struct MainTabView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.activeTab) {
            Tab(
                String(localized: "tab.browse", defaultValue: "Browse"),
                systemImage: "books.vertical",
                value: AppTab.browse
            ) {
                BrowserTabView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.search", defaultValue: "Search"),
                systemImage: "magnifyingglass",
                value: AppTab.search
            ) {
                SearchTabView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.research", defaultValue: "Research"),
                systemImage: "note.text",
                value: AppTab.research
            ) {
                ResearchView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.collections", defaultValue: "Collections"),
                systemImage: "tray.2",
                value: AppTab.collections
            ) {
                CollectionListView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gear",
                value: AppTab.settings
            ) {
                SettingsView()
                    .safeAreaInset(edge: .bottom, spacing: 0) { indexingBanner }
            }
            // Boolean dot badge: shows when any downloaded volumes are awaiting indexing.
            // A raw count badge (the previous behaviour) is misleading — the number is a
            // background status metric, not an actionable queue the user must clear item
            // by item. A dot communicates "something needs attention" without implying
            // a specific count.
            .badge(appState.unindexedVolumeCount > 0 ? "·" : "")
        }
        // iPad (regular width) renders the tabs as a native adaptive sidebar — the
        // macOS-like layout researchers expect on a keyboard/trackpad iPad — while
        // iPhone (compact width) automatically falls back to the bottom tab bar, so
        // the phone experience is unchanged. Each tab keeps its own internal
        // navigation (e.g. BrowserView's / ResearchView's NavigationSplitView),
        // which becomes the sidebar's detail content rather than nesting a second
        // split. (BigPicture-iPadMacParity Phase 1.)
        .tabViewStyle(.sidebarAdaptable)
    }

    /// Returns the appropriate indexing UI above the tab bar, or `EmptyView` when idle.
    ///
    /// Priority order:
    /// 1. `completedIndexingMetadata` non-nil → `IndexingSummaryCard` (post-index success)
    /// 2. `currentIndexingProgress` non-nil, queue position non-nil → `IndexingQueueBannerView`
    /// 3. `currentIndexingProgress` non-nil, single volume → `IndexingBannerView`
    /// 4. Both nil → `EmptyView` (no height inset)
    ///
    /// Transitions use `.move(edge: .bottom).combined(with: .opacity)` so the card
    /// slides up from the tab bar edge when indexing completes.
    @ViewBuilder
    private var indexingBanner: some View {
        if let meta = appState.completedIndexingMetadata {
            let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
            IndexingSummaryCard(
                metadata: meta,
                volumeTitle: title,
                onSearchVolume: { volumeId in
                    appState.pendingSearch = SearchParameters(volumeIds: [volumeId])
                    appState.activeTab = .search
                    appState.completedIndexingMetadata = nil
                },
                onDismiss: {
                    appState.completedIndexingMetadata = nil
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let update = appState.currentIndexingProgress,
                  let queuePosition = appState.indexingQueuePosition {
            IndexingQueueBannerView(
                update: update,
                queuePosition: queuePosition,
                volumeTitles: appState.indexingQueueVolumeTitles,
                metadata: appState.lastDiscoveredMetadata,
                averageDocsPerSecond: appState.indexingQueueAverageDocsPerSecond,
                averageDocumentCount: appState.indexingQueueAverageDocumentCount
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let update = appState.currentIndexingProgress {
            IndexingBannerView(
                update: update,
                metadata: appState.lastDiscoveredMetadata,
                volume: appState.manifestStore.entry(forVolumeId: update.volumeId),
                onPersonSearch: { name in
                    appState.pendingSearch = SearchParameters(keywords: name)
                    appState.activeTab = .search
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - BrowserTabView

/// Wraps `BrowserView` for the Browse tab with an Analytics toolbar button.
///
/// Exists as a named struct so that SwiftUI maintains stable `@State` identity for
/// `BrowserView`'s `viewModel` across tab switches. Without the wrapper, switching
/// away from and back to the Browse tab could recreate `BrowserView` and reset
/// navigation state.
///
/// Version history:
///   1.0 — Session 43: initial implementation
///   1.1 — Session 99: Analytics toolbar button; presents AnalyticsView as a sheet
///   1.2 — Session 2026-06-07: observes `appState.pendingAnalytics` (Search's
///          over-cap "Visualize in Corpus Analytics" handoff) and presents the
///          sheet pre-seeded via `AnalyticsView(initialParameters:)`
struct BrowserTabView: View {

    @Environment(AppState.self) private var appState
    @State private var showAnalytics = false
    @State private var analyticsParameters: AnalyticsParameters? = nil

    var body: some View {
        BrowserView()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        analyticsParameters = nil
                        showAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityLabel(
                        String(localized: "browse.analytics.a11y",
                               defaultValue: "Corpus Analytics")
                    )
                }
            }
            .sheet(isPresented: $showAnalytics) {
                AnalyticsView(initialParameters: analyticsParameters)
                    .environment(appState)
            }
            // Search → Analytics handoff: a capped search offered to "Visualize
            // in Corpus Analytics". Captured into local state before presenting —
            // `AnalyticsView` reads it once at init (a fresh sheet instance is
            // created each presentation) — then cleared on `AppState` so the
            // observer doesn't refire on the next sheet dismissal.
            .onChange(of: appState.pendingAnalytics) { _, params in
                guard let params else { return }
                analyticsParameters = params
                appState.pendingAnalytics = nil
                showAnalytics = true
            }
    }
}

// MARK: - SearchTabView

/// Search tab root on iOS.
///
/// Embeds `SearchView` directly (no sheet wrapper). `SearchView` owns its own
/// "Find by citation" entry (in its "More" overflow menu) and presents
/// `CitationLookupView` as a local sheet.
///
/// When `appState.searchService` is unavailable (database not yet opened),
/// a `ContentUnavailableView` placeholder is shown instead.
///
/// Version history:
///   1.0 — Session 44: initial implementation
///   1.1 — Session 156: removed the Citation Lookup toolbar button/sheet — it was
///          applied outside `SearchView`'s own `NavigationStack` and never reached
///          the nav bar (silently unreachable). Moved into `SearchView` itself
///          (its "More" overflow menu).
private struct SearchTabView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        if let service = appState.searchService {
            SearchView(
                searchService: service
            )
        } else {
            ContentUnavailableView(
                String(localized: "search.unavailable.title",
                       defaultValue: "Search Unavailable"),
                systemImage: "magnifyingglass",
                description: Text(
                    String(localized: "search.unavailable.detail",
                           defaultValue: "The search index is not available.")
                )
            )
        }
    }
}

#endif
