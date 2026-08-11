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
/// - **Settings** tab: a "·" indicator when downloaded-but-unindexed volumes exist, via
///   `appState.unindexedVolumeCount`, and no badge at all otherwise. Prompts the user to
///   run Reindex.
///   (The Activity tab and its new-notes badge were retired in 1.7 — Research, its
///   replacement, is a navigation tool, not an inbox, and carries no badge.)
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
///   1.13 — Session 2026-08-09 (#657, first step): the Settings badge is now ABSENT at zero
///          rather than empty. `""` is still a badge — it materialises a `UILabel` inside the
///          tab item's layout, the stack the iPad crash log names. Spelled `Text?` because
///          `TabContent.badge` (unlike `View.badge`) has no optional-String overload.
///          **This is a suspect removed, not a proven fix.** #657 is unreproduced and its own
///          report will not choose between a watchdog hang and a data abort; conviction needs
///          the device backtrace captured in Read mode (plan item B-1). The issue stays open.
///   1.14 — Session 2026-08-11: #833 — the shell presents Archival Analytics from
///          `pendingArchivalScope`. That surface had no presenter outside `BrowserView`'s own
///          `@State`, so a scope handed over from Search or a subject sheet opened nothing.
struct MainTabView: View {

    @Environment(AppState.self) private var appState
    /// This scene's model context, only for handing its container to the analytics sheets — a
    /// sheet does not reliably inherit the container any more than it inherits `AppState`.
    @Environment(\.modelContext) private var modelContext

    /// Per-window tab selection (#316). Backing the selection with `@SceneStorage` instead of
    /// the shared `appState` gives every iPad main window (Stage Manager / multiple windows) its
    /// own tab, so switching tabs in one window never mirrors into another — a user tap changes
    /// only this per-scene value, which nothing else observes. A fresh window seeds from the
    /// persisted last-selected tab (`AppState.seedActiveTab`); a state-restored window keeps its
    /// own. Cross-view hand-offs arrive through the separate consume-once `appState.pendingTab`,
    /// drained below.
    @SceneStorage("frus.selectedTab") private var selectedTab: AppTab = AppState.seedActiveTab

    /// Per-scene identity for cross-scene hand-off targeting (#338), minted once per window for its
    /// live lifetime — the exact iPad analogue of the macOS per-instance `DocumentHostID.main`, which
    /// is likewise `@State` (session-scoped, deliberately NOT restored). Hand-offs are transient, so
    /// nothing needs the token to survive process death; `@SceneStorage` was avoided because
    /// restoration could replay one archived token into two live scenes and silently re-open the
    /// fan-out this exists to close (#338 review). Published via `\.sceneID` so a hand-off producer in
    /// this window addresses its `Handoff` to *this* scene, and only this scene applies it.
    /// …except that since #752 / M-25 the identity may be published from **above** this view, by
    /// `ContinuationHost`, so the Spotlight / Handoff / open-with handlers — which are attached to
    /// the `WindowGroup`'s content, two levels up — can address the window they fired in. When one
    /// is published this view adopts it; the local mint below stays as the fallback for any host
    /// that is not wrapped, so nothing changes for those.
    @Environment(\.sceneID) private var inheritedSceneID

    @State private var mintedSceneIDToken = UUID().uuidString

    /// This window's scene token: the inherited identity when there is one, else this view's mint.
    private var sceneIDToken: String { inheritedSceneID?.raw ?? mintedSceneIDToken }

    /// The word cloud this window is presenting, once **consumed** from the shared hand-off slot
    /// (#752). Local state, so another window's producer can no longer dismiss this sheet by
    /// overwriting the slot underneath it.
    @State private var presentedWordCloud: Handoff<WordCloudScope>?

    /// The archival-scope hand-off this window has adopted, or `nil` (#833).
    ///
    /// The tab shell is the iOS presenter of Archival Analytics for the same reason it is the
    /// presenter of the word cloud: the producers are spread across Search, Browse and the
    /// subject sheets, and a hand-off whose only presenter lived inside one tab's own `@State`
    /// could not be opened from the others. Before this, the search door switched to the Browse
    /// tab and nothing appeared — the surface's only opener was a menu button in that tab.
    @State private var presentedArchivalScope: Handoff<ArchivalScopeRequest>?

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
            //
            // The zero case passes `nil`, not `""` (#657, first step). An empty string is
            // still a badge: it materialises a `UILabel` in the tab item's layout, which is
            // the stack the iPad crash log names. `nil` is the absent badge.
            //
            // It must be spelled `Text?`, not `String?`. `Tab` conforms to `TabContent`, not
            // to `View`, and `TabContent.badge` has no optional-String overload — only
            // `badge(_ label: Text?)` admits nil. (`View.badge` does have `LocalizedStringKey?`
            // and `S?` overloads; nothing learned from a List-row badge transfers here, which
            // is the mistake the issue itself makes.) Wrapping the dot in `Text` is what lets
            // the ternary's two branches unify.
            .badge(appState.unindexedVolumeCount > 0 ? Text(verbatim: "·") : nil)
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
        // #338 — publish this window's scene identity to every tab (and the sheets they present) so a
        // hand-off producer can address its `Handoff` to this scene, and only this scene consumes it
        // (the foundation for fixing the pendingX fan-out across open iPad windows).
        .environment(\.sceneID, SceneID(sceneIDToken))
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
        .onChange(of: appState.pendingTab) { _, _ in
            if let pending = appState.consumePendingTab(for: SceneID(sceneIDToken)) { selectedTab = pending }
        }
        // #316 — catch a request delivered during a cold launch (open-with, Spotlight, Handoff)
        // BEFORE this observer existed: `onChange` never fires for state set before the view
        // appeared, so drain any already-pending request here. A window opened later sees `nil`
        // (a prior window consumed it) and keeps its seeded tab.
        .onAppear {
            if let pending = appState.consumePendingTab(for: SceneID(sceneIDToken)) { selectedTab = pending }
            // #338 aux-window origin: publish this main window's scene as live, so an aux window
            // (Archival Neighbors / Related Documents) launched from here can hand a document back to
            // THIS window; removed on disappear so a closed window resolves to `.anyWindow` instead.
            appState.registerScene(SceneID(sceneIDToken))
        }
        // Deregister on teardown so a closed window's aux windows resolve their origin to `.anyWindow`
        // instead of a dead scene. On iPadOS a window close disconnects the scene and tears down this
        // WindowGroup root, firing `onDisappear` — unlike macOS (`liveDocumentHosts`), which needs an
        // NSWindow `willClose` backstop because a red-button close there can outrun SwiftUI's teardown.
        // If a stale token is ever observed on-device (an aux-window open black-holing after its
        // launcher closed), add a UIWindowScene `willDisconnect` belt-and-braces here. (#338 review.)
        .onDisappear { appState.unregisterScene(SceneID(sceneIDToken)) }
        // Word Cloud hand-off (#338 step 2): present the sheet only when the hand-off is addressed to
        // THIS window's scene, so a word cloud opened in one iPad window no longer fans out to every
        // open window. `Handoff` is `Identifiable`; the guarded binding yields it only for a matching
        // target, and clears the shared slot on dismiss. A producer stamps its own `\.sceneID`
        // (published above), so exactly one window's binding matches.
        // #752 (audit H-9, M-31, M-33): CONSUME the hand-off into this window's own state, and
        // accept `.anyWindow`, like every sibling channel.
        //
        // The old binding read the shared slot live on every render and cleared it only on dismiss.
        // Two defects followed. (1) It matched the window's exact token with no `.anyWindow`
        // acceptance — the one channel of five without it — so a standalone document window whose
        // launcher had closed (or which the app had restored, capturing no origin) targeted
        // `.anyWindow` and **no presenter ever matched**: the tile did nothing, permanently, while
        // its rail siblings worked. That contradicted `AppState`'s own claim that `.anyWindow`
        // "never black-holes". (2) Because presentation never consumed, the slot stayed populated
        // for as long as the sheet was up, so opening a cloud in window B overwrote it and window
        // A's sheet — whose getter now returned nil — dismissed itself.
        .onChange(of: appState.pendingWordCloud) { _, _ in consumePendingWordCloud() }
        .onAppear { consumePendingWordCloud() }
        .onChange(of: appState.pendingArchivalScope) { _, _ in consumePendingArchivalScope() }
        .onAppear { consumePendingArchivalScope() }
        .sheet(item: $presentedArchivalScope) { archivalSheet($0) }
        .sheet(item: $presentedWordCloud) { handoff in
            WordCloudView(scope: handoff.payload)
                .environment(appState)
                // #338 step 3: publish THIS window's scene id into the word-cloud sheet so the
                // in-cloud Analyze / Chronology producers address this window (a sheet doesn't
                // reliably inherit `\.sceneID`).
                .environment(\.sceneID, SceneID(sceneIDToken))
        }
        // #377 Phase 5: the tab shell is the correct host for the one-time second-project nudge on
        // iOS — it's always on screen, so it covers whatever surface creates a project. Today that
        // means the "New Project…" row in the Settings tab's Projects pane (`ProjectsSettingsView`),
        // which is a child of this shell. The signal is still addressed app-wide rather than
        // per-scene; if more create surfaces appear, route it per-scene (`Handoff`/`\.sceneID`,
        // cf. #338) so an iPad Stage-Manager multi-window setup shows the alert in one window,
        // not all of them.
        .secondProjectNudge()
    }

    /// The scoped Archival Analytics sheet.
    ///
    /// A function rather than an inline closure purely for the type-checker: the tab shell's body
    /// is already at the limit and inlining this failed to solve in reasonable time. The three
    /// injections are the ones `BrowserView`'s sheet made, for the same reason — a sheet does not
    /// reliably inherit them, and this view reads all three.
    @ViewBuilder
    private func archivalSheet(_ handoff: Handoff<ArchivalScopeRequest>) -> some View {
        ArchivalAnalyticsView(initialScope: handoff.payload)
            .environment(appState)
            .modelContainer(modelContext.container)
            .environment(\.sceneID, SceneID(sceneIDToken))
            // #498: prophylactic, matching the sibling analytics sheets.
            .statusBarHidden(false)
    }

    /// Adopts a pending archival-scope hand-off addressed to this window (#833).
    ///
    /// The `presentedArchivalScope == nil` guard is what makes the two-presenter arrangement
    /// deterministic. When a scope arrives while the sheet is already up, this consumer declines
    /// it and leaves it in the slot, so the mounted `ArchivalAnalyticsView` adopts it and
    /// re-scopes in place; when nothing is up, this consumer takes it and presents. The mounted
    /// view therefore always wins, whichever `onChange` the runtime happens to run first.
    private func consumePendingArchivalScope() {
        guard presentedArchivalScope == nil else { return }
        guard let handoff = appState.pendingArchivalScope else { return }
        let mine = SceneID(sceneIDToken)
        guard handoff.target == mine || handoff.target == .anyWindow else { return }
        appState.pendingArchivalScope = nil
        presentedArchivalScope = handoff
    }

    /// Adopts a pending word-cloud hand-off addressed to this window (#752).
    ///
    /// Uses `orAnyWindow: true`, matching `pendingSearch`, `pendingTab`, `pendingBrowseDocument`
    /// and `pendingBrowseVolume` — this was the one channel of five that demanded an exact scene
    /// match, which is why a standalone document window with no live origin had no presenter at all.
    ///
    /// Consuming (rather than reading the slot live) is what stops window B's producer from
    /// dismissing window A's open sheet: once adopted, this window's presentation depends only on
    /// its own state.
    private func consumePendingWordCloud() {
        guard presentedWordCloud == nil else { return }   // don't replace a sheet already up
        guard let handoff = appState.pendingWordCloud else { return }
        let mine = SceneID(sceneIDToken)
        guard handoff.target == mine || handoff.target == .anyWindow else { return }
        appState.pendingWordCloud = nil
        presentedWordCloud = handoff
    }

    /// Returns the appropriate indexing UI above the tab bar, or `EmptyView` when idle.
    ///
    /// Priority order:
    /// 1. `indexingBatch` non-nil, queue position non-nil → `IndexingQueueBannerView`
    /// 2. `indexingBatch` non-nil, single volume → `IndexingBannerView`
    /// 3. `indexingBatch` nil, `completedIndexingMetadata` non-nil → `IndexingSummaryCard`
    /// 4. Both nil → `EmptyView` (no height inset)
    ///
    /// **The queue outranks the summary card**, which is the inverse of the original
    /// order and the whole point. `completedIndexingMetadata` is set once per *volume*,
    /// so with the card on top a 27-volume download played banner → card → banner → card
    /// twenty-seven times. Now the banner holds for the life of the queue and the card
    /// appears once, when everything downloaded is searchable.
    ///
    /// Transitions use `.move(edge: .bottom).combined(with: .opacity)` so the card
    /// slides up from the tab bar edge when indexing completes.
    @ViewBuilder
    private var indexingBanner: some View {
        // #665: the iCloud indicator shares this inset. Indexing wins when both want it —
        // indexing is transient and finishes, while a local-only or failed-sync state waits and
        // will still be true when the banner frees up.
        if appState.indexingBatch == nil, appState.completedIndexingMetadata == nil,
           SyncStatusBanner.isWorthShowing(state: appState.cloudKitSyncState,
                                           cloudKitEnabled: appState.cloudKitSyncEnabled) {
            SyncStatusBanner(
                state: appState.cloudKitSyncState,
                cloudKitEnabled: appState.cloudKitSyncEnabled,
                onOpenSettings: {
                    appState.openTab(.settings, from: SceneID(sceneIDToken))
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let batch = appState.indexingBatch {
            if let queuePosition = appState.indexingQueuePosition {
                IndexingQueueBannerView(
                    update: batch.latest,
                    queuePosition: queuePosition,
                    volumeTitles: appState.indexingQueueVolumeTitles,
                    metadata: appState.lastDiscoveredMetadata,
                    averageDocsPerSecond: appState.indexingQueueAverageDocsPerSecond,
                    averageDocumentCount: appState.indexingQueueAverageDocumentCount
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                IndexingBannerView(
                    update: batch.latest,
                    metadata: appState.lastDiscoveredMetadata,
                    volume: appState.manifestStore.entry(forVolumeId: batch.latest.volumeId),
                    onPersonSearch: { name in
                        appState.openSearch(SearchParameters(keywords: name), from: SceneID(sceneIDToken))
                        appState.openTab(.search, from: SceneID(sceneIDToken))
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else if let meta = appState.completedIndexingMetadata {
            let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
            IndexingSummaryCard(
                metadata: meta,
                volumeTitle: title,
                queueVolumeCount: appState.completedIndexingBatchVolumeCount,
                onSearchVolume: { volumeId in
                    appState.openSearch(SearchParameters(volumeIds: [volumeId]), from: SceneID(sceneIDToken))
                    appState.openTab(.search, from: SceneID(sceneIDToken))
                    appState.completedIndexingMetadata = nil
                    appState.completedIndexingBatchVolumeCount = nil
                },
                onDismiss: {
                    appState.completedIndexingMetadata = nil
                    appState.completedIndexingBatchVolumeCount = nil
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
///   1.3 — #486: removed the tab-level `WorkingOnBanner` top `.safeAreaInset`. Applied to
///          `BrowserView()` from outside its `NavigationStack`, the inset was composited over
///          the navigation bar rather than pushing it down, clipping the back button, the
///          title, and the trailing toolbar items. The banner moved inside the stack.
struct BrowserTabView: View {

    // The Chronology/Analytics toolbar buttons, their sheets, and the pendingAnalytics/
    // pendingChronology handoff observers now live INSIDE `BrowserView` (within its own
    // NavigationStack/NavigationSplitView). Declared here — on `BrowserView()` from outside its
    // navigation container — they were silently dropped and the features were unreachable on iOS.
    // This wrapper remains only to give `BrowserView`'s `@State` stable identity across tab switches.
    // #486: the "Working on: <question>" banner used to be injected HERE, as a top
    // `.safeAreaInset` on `BrowserView()` — i.e. from OUTSIDE its `NavigationStack`. That was wrong.
    // A top safe-area inset applied TO a navigation container does not push the navigation bar down;
    // SwiftUI composites the inset into the same top chrome band, drawing it OVER the bar. On iPhone
    // the banner therefore sliced the back chevron, the inline title, and the trailing toolbar items
    // at every Browse depth (the Browse root's large title escaped to its own row, but its three
    // trailing toolbar buttons did not). The comment that stood here claimed the placement "never
    // touches the #238/Session-121 top-inset occlusion math" — it did, and it is the whole bug.
    //
    // The banner now lives INSIDE `BrowserView`'s stack, on the corpus root and folded into the
    // per-level breadcrumb inset, exactly as `SearchView` has always applied it (SearchView was never
    // affected precisely because its inset is inside its own `NavigationStack`).
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
        } else if !appState.isBootComplete {
            // #753 (audit M-23): while the app is still starting, say so. This tab used to answer
            // "Search Unavailable — the search index is not available" over a fully built index of
            // 316,839 documents, purely because `searchService` is assigned deep into the async
            // boot. That message reads as permanent breakage, and it was also indistinguishable
            // from a genuine store-open failure — the case the branch below still covers.
            //
            // macOS Search fixed exactly this and named the principle: never render the definitive
            // empty state as a lie. The iOS tab was simply never given the same treatment.
            BootPlaceholderView(
                detail: String(localized: "search.preparing.detail",
                               defaultValue: "Search will be ready in a moment."))
        } else {
            // Boot finished and there is still no service: a real failure, correctly stated.
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
