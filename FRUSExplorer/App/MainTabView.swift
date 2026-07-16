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
/// Uses the iOS 18+ `Tab` API with a `value:` parameter. Selection is a per-window
/// `@SceneStorage` value seeded from the persisted last tab (#316, version history 1.12);
/// cross-view hand-offs arrive via the consume-once `appState.pendingTab`. All five tabs are
/// fully wired as of Session 44.
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
///          bottom tab bar unchanged.
///   1.9 — Session 1 / #238: correction to 1.8 — a tab hosting its own `NavigationSplitView`
///          *does* nest a split view under `.sidebarAdaptable`, and in the collapsed
///          floating-top-tab-bar representation that nested column overlaid content that
///          could not be scrolled into view. `BrowserView` now uses a `NavigationStack`
///          (its `stackLayout`) on all size classes; `ResearchView`/`SettingsView` still
///          nest splits and are tracked as a follow-up. Rule going forward: tabs under
///          `.sidebarAdaptable` host a `NavigationStack`, not a `NavigationSplitView`.
///   1.10 — #272: `ResearchView` now complies too — iOS flattens it to a `NavigationStack`
///          (macOS keeps its `NavigationSplitView`).
///   1.11 — #272 follow-up: **the ledger is closed — every tab complies.** 1.9 and 1.10 both
///          named `SettingsView` as still nesting a split; that was never true. The iOS
///          Settings tab has hosted a `NavigationStack` (SettingsView.swift:87) since
///          97eeb76 (2026-05-18), which moved the split into the macOS-only
///          `FRUSSettingsView`. The claim was written seven weeks later and simply never
///          checked against the file. Verify before re-adding an entry here: the only
///          `NavigationSplitView`s left in the module are `#if os(macOS)`-guarded
///          (`FRUSSettingsView`, `ResearchView`, `MacCorpusBrowserWindow`) or unreferenced
///          (`BrowserView.splitLayout`), and none can render under `.sidebarAdaptable`.
///   1.12 — #316: the tab selection is now per-window `@SceneStorage`, not a shared `appState`
///          property, so multiple iPad main windows (Stage Manager) no longer mirror each
///          other's tab — a user tap changes only the per-scene value, which nothing else
///          observes. Cross-view hand-offs arrive through the separate consume-once
///          `appState.pendingTab` (drained on change + on appear, so a cold-launch open-with /
///          Spotlight request is not dropped); the fresh-window seed is persisted straight to
///          UserDefaults. Deliberately NOT `scenePhase`-gated: the first design gated adoption
///          on `scenePhase == .active`, but iPadOS reports every *visible* window `.active`, so
///          that reintroduced mirroring for co-visible windows and stranded launch hand-offs
///          (#337 review). Hand-offs adopt in every open window (as before this change); only
///          idle tab taps are now per-window.
struct MainTabView: View {

    @Environment(AppState.self) private var appState

    /// Per-window tab selection (#316). Backing the selection with `@SceneStorage` instead of
    /// the shared `appState` gives every iPad main window (Stage Manager / multiple windows) its
    /// own tab, so switching tabs in one window never mirrors into another — a user tap changes
    /// only this per-scene value, which nothing else observes. A fresh window seeds from the
    /// persisted last-selected tab (`AppState.seedActiveTab`); a state-restored window keeps its
    /// own. Cross-view hand-offs arrive through the separate consume-once `appState.pendingTab`,
    /// drained below.
    @SceneStorage("frus.selectedTab") private var selectedTab: AppTab = AppState.seedActiveTab

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $selectedTab) {
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
        // iPad renders the tabs as a native adaptive sidebar (toggleable to a floating
        // top tab bar) — the macOS-like layout researchers expect on a keyboard/trackpad
        // iPad — while iPhone automatically keeps the bottom tab bar, so the phone
        // experience is unchanged. GUARD RULE (#238, see version history 1.9): a tab's
        // content must host a NavigationStack, NOT a NavigationSplitView — a nested split
        // mis-computes its top safe area under the floating top tab bar and overlays
        // content. ALL FIVE TABS COMPLY: BrowserView (stackLayout on all size classes),
        // ResearchView (iOS flattens to a NavigationStack as of #272; macOS keeps the
        // split), and SettingsView (NavigationStack since 97eeb76 — the "SettingsView
        // still nests a split" follow-up this comment used to name never existed; see
        // version history 1.11). No open conversion work remains; the rule is now purely
        // forward-looking. (BigPicture-iPadMacParity Phase 1 + #238 correction — note that
        // doc carries its own stale copy of this ledger; this comment is authoritative.)
        .tabViewStyle(.sidebarAdaptable)
        // #316 — persist THIS window's selection as the fresh-window seed. Written straight to
        // UserDefaults (not a shared @Observable property), so a user tap here is never observed
        // by another window and cannot mirror. Any window may update the seed; it is just "the
        // last tab shown", used only to open brand-new windows.
        .onChange(of: selectedTab) { _, newValue in
            AppState.persistTabSeed(newValue)
        }
        // #316 — drain the consume-once cross-view hand-off request into this window's selection.
        // The ~22 hand-off sites set `appState.pendingTab` alongside their `pendingX` content
        // field; every open MainTabView adopts it and clears it (the standard pendingX pattern),
        // so the hand-off's tab comes forward wherever the user is. Cleared so a later unrelated
        // change does not re-trigger it, and so a fresh window (nil) falls through to its seed.
        .onChange(of: appState.pendingTab) { _, pending in
            guard let pending else { return }
            selectedTab = pending
            appState.pendingTab = nil
        }
        // #316 — catch a request delivered during a cold launch (open-with, Spotlight, Handoff)
        // BEFORE this observer existed: `onChange` never fires for state set before the view
        // appeared, so drain any already-pending request here. A window opened later sees `nil`
        // (a prior window consumed it) and keeps its seeded tab.
        .onAppear {
            if let pending = appState.pendingTab {
                selectedTab = pending
                appState.pendingTab = nil
            }
        }
        // Word Cloud handoff: any surface sets `appState.pendingWordCloud`; the
        // sheet presents over whichever tab is active and clears it on dismiss.
        // Mirrors the `pendingAnalytics` pattern but presented at the tab root so
        // it is reachable from every tab.
        .sheet(item: $appState.pendingWordCloud) { scope in
            WordCloudView(scope: scope)
                .environment(appState)
        }
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
                    appState.pendingTab = .search
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
                    appState.pendingTab = .search
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

    // The Chronology/Analytics toolbar buttons, their sheets, and the pendingAnalytics/
    // pendingChronology handoff observers now live INSIDE `BrowserView` (within its own
    // NavigationStack/NavigationSplitView). Declared here — on `BrowserView()` from outside its
    // navigation container — they were silently dropped and the features were unreachable on iOS.
    // This wrapper remains only to give `BrowserView`'s `@State` stable identity across tab switches.
    var body: some View {
        BrowserView()
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
