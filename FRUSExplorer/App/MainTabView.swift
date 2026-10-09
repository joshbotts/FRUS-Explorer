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
///          (`BrowserView.splitLayout`, deleted since), and none can render under `.sidebarAdaptable`.
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
///   1.15 — #1070: the shared banner inset yields to the on-screen keyboard. A bottom
///          `safeAreaInset` floats onto the keyboard's accessory row, and the sync banner
///          was occluding the #861 Done bar there (measured: the Done existed, unhittable)
///          — with the keyboard also covering the tab bar, a reader was trapped
///   1.16 — #1299 follow-up: the Search tab publishes the height of the banner inset as
///          `\.tabShellBottomOverlay`. The inset is applied outside `SearchView`'s navigation
///          stack, which does not pass it on, so the banner is drawn OVER the Search content —
///          measured at AX5 on iPhone 17, the Local Only banner covered the pre-search Search tips
///          link (y 707–770) from y = 551, and the prompt's scroll view had nothing to scroll.
///          `SearchView` reads the value to give its pre-search content room to scroll clear.
///   1.17 — #1368: each window registers its `UISceneSession` beside its scene token
///          (`SceneSessionReader`), so closing an aux window can bring this one forward rather
///          than leaving the reader on the Home Screen. Review round 1: `SceneSessionReader`'s doc
///          names its second host, `AuxWindowOriginModifier`.
///   1.18 — #1565: the banner no longer covers a tab's content. Each tab's own view controller
///          sets aside the banner's height at the bottom of its safe area, and the banner is drawn
///          in that room (`TabShellBannerModifier`), so lists, a pushed screen's bottom bar and the
///          reader all end above it. `\.tabShellBottomOverlay` (1.16) is gone: nothing needs to be
///          told the banner's height any more.
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

    /// Gates Archival Analytics onto its own window where one is available (F-11 / CW-9c).
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    /// Opens the value-based `archivalAnalyticsScene`.
    @Environment(\.openWindow) private var openWindow

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

    /// Whether the on-screen keyboard is up — the banner inset yields to it (#1070; see
    /// the observers on the `TabView` for the measured occlusion this prevents).
    @State private var keyboardIsVisible = false

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $selectedTab) {
            Tab(
                String(localized: "tab.browse", defaultValue: "Browse"),
                systemImage: "books.vertical",
                value: AppTab.browse
            ) {
                BrowserTabView()
                    .tabShellBanner { indexingBanner }
            }
            Tab(
                String(localized: "tab.search", defaultValue: "Search"),
                systemImage: "magnifyingglass",
                value: AppTab.search
            ) {
                SearchTabView()
                    .tabShellBanner { indexingBanner }
            }
            Tab(
                String(localized: "tab.research", defaultValue: "Research"),
                systemImage: "note.text",
                value: AppTab.research
            ) {
                ResearchView()
                    .tabShellBanner { indexingBanner }
            }
            Tab(
                String(localized: "tab.collections", defaultValue: "Collections"),
                systemImage: "tray.2",
                value: AppTab.collections
            ) {
                CollectionListView()
                    .tabShellBanner { indexingBanner }
            }
            Tab(
                String(localized: "tab.settings", defaultValue: "Settings"),
                systemImage: "gear",
                value: AppTab.settings
            ) {
                SettingsView()
                    .tabShellBanner { indexingBanner }
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
        // UI review F-3: the sidebar was five rows above an empty column (~510 pt measured, not
        // the review's ~900). The researcher's own objects now fill it. Gated on the pad idiom
        // because iPhone never shows the sidebar representation and the footer's two `@Query`s
        // would otherwise run there for nothing — see `SidebarShortcuts` for why this is a footer
        // rather than the `TabSection`s the review names.
        .tabViewSidebarFooter {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // **The footer is NOT inside the TabView's environment chain, and this crashed
                // build 42 on iPad (#950).** `.tabViewSidebarFooter` content is hosted by the
                // sidebar container, so none of the modifiers applied to the `TabView` below reach
                // it — not `.environment(appState)` from the scene, not the `\.sceneID` set at
                // `:232`, not the scene's `.modelContainer`. `SidebarShortcuts` opens with
                // `@Environment(AppState.self)`, which is resolved EAGERLY on declaration rather
                // than lazily in `body`, so it traps the instant the footer is built:
                //
                //     Fatal error: No Observable object of type AppState found.
                //
                // It only shows on iPad, and only when the window is wide enough for the sidebar
                // representation — which is why the reproduction is *resizing the main window*
                // rather than any particular tap. Every scene in the app injects `appState`
                // correctly; this hierarchy simply is not descended from one.
                //
                // All three are re-injected, not just the one that trapped:
                //  * `appState` — the crash.
                //  * `\.modelContext` — `SidebarShortcuts` runs two `@Query`s. They would fail for
                //    exactly the same reason the moment the first failure stopped masking them.
                //  * `\.sceneID` — silently defaulted rather than trapping, which is worse: the
                //    footer's saved-search hand-off would be addressed to the wrong window on a
                //    second iPad scene, the #752 failure mode.
                SidebarShortcuts()
                    .environment(appState)
                    .environment(\.modelContext, modelContext)
                    .environment(\.sceneID, SceneID(sceneIDToken))
            }
        }
        // #338 — publish this window's scene identity to every tab (and the sheets they present) so a
        // hand-off producer can address its `Handoff` to this scene, and only this scene consumes it
        // (the foundation for fixing the pendingX fan-out across open iPad windows).
        .environment(\.sceneID, SceneID(sceneIDToken))
        // #1070: the banner yields to the keyboard. Anything drawn at the bottom of the safe area
        // floats up with the keyboard, landing exactly on the accessory row where the #861 Done
        // bar renders — measured on the Browse root, the bar's Done existed but was not
        // hittable, so the keyboard could not be put away and the raised keyboard covered
        // the tab bar (the reported trap). Hiding rather than `.ignoresSafeArea(.keyboard)`
        // on the tab roots, because that modifier would also stop every tab's own fields
        // from avoiding the keyboard — a worse defect than a banner that waits out a
        // typing session (its states persist; it returns the moment the keyboard goes).
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation { keyboardIsVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation { keyboardIsVisible = false }
        }
        // #316 — persist THIS window's selection as the fresh-window seed. Written straight to
        // UserDefaults (not a shared @Observable property), so a user tap here is never observed
        // by another window and cannot mirror. Any window may update the seed; it is just "the
        // last tab shown", used only to open brand-new windows.
        .onChange(of: selectedTab) { _, newValue in
            AppState.persistTabSeed(newValue)
        }
        // #316 — drain the consume-once cross-view hand-off request into this window's selection.
        // The hand-off sites set `appState.pendingTab` alongside their `pendingX` content field; the
        // MainTabView of the addressed window adopts it and clears it (the standard pendingX pattern),
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
        // #1368: register this window's UIKit session beside its token, so an aux window launched
        // from here can ask iPadOS to bring THIS window forward when it closes. Never unregistered:
        // the session, not this view's `onDisappear`, decides whether the window is still there.
        .background {
            SceneSessionReader { appState.registerSceneSession($0, for: SceneID(sceneIDToken)) }
        }
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
        // which is a child of this shell. The signal is a `Handoff` addressed to the window the
        // project was created in (F-20 / W-2d) — an iPad Stage-Manager setup shows the alert in
        // that one window, not all of them; `.anyWindow` covers a scene-less producer.
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
        // NO `onNavigateAway:` HERE, and it is not an oversight. That parameter doubles as
        // `ArchivalAnalyticsView`'s marker for "the Research Guide is what presented me", and the
        // surface withholds its **About Archival Sourcing** toolbar link on it (#835). Supplying
        // one from the shell to close this sheet behind the scope bar's Topic-index door (#1274)
        // silently deleted that link from the app's primary iOS presentation of the surface. The
        // door closes this sheet through the view's own `dismiss()` instead.
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

        // UI review F-11 / CW-9c: where a window is available this surface opens as its own scene
        // rather than a sheet over the tab bar. The hand-off is still the single entry point #833
        // made it — every topic door and the Browse menu produce one, and this consumer decides
        // only where it lands, so the two-presenter determinism above is unchanged.
        if supportsMultipleWindows {
            appState.openAuxWindow(handoff.payload, from: mine, using: openWindow)
            return
        }
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
    /// Every tab draws it through `tabShellBanner`, which also keeps the tab's content clear of
    /// it (#1565).
    ///
    /// **The precedence is `IndexingInsetState.resolve`, not this body.** B-6 was a hole in the
    /// old `if`/`else if` chain — a queued download with no batch matched no branch and the inset
    /// collapsed to nothing — and it survived because the chain had no seam a test could reach.
    /// Switch on the state; do not re-test the conditions here, or the extraction buys nothing.
    ///
    /// Within `.batch`, the queue banner still outranks the single-volume one:
    /// 1. queue position non-nil → `IndexingQueueBannerView`
    /// 2. otherwise → `IndexingBannerView`
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
        // #1070: nothing here renders while the keyboard is up — the banner floats onto the
        // keyboard's accessory row and occludes the #861 Done bar (measured: the bar's Done
        // existed but was unhittable under this banner). Every state here persists or
        // re-announces, so nothing is lost by waiting out a typing session.
        switch IndexingInsetState.resolve(
            keyboardIsVisible: keyboardIsVisible,
            hasBatch: appState.indexingBatch != nil,
            hasCompletedMetadata: appState.completedIndexingMetadata != nil,
            downloadQueueIsEmpty: appState.downloadQueue.isEmpty,
            syncIsWorthShowing: SyncStatusBanner.isWorthShowing(appState.iCloudStatusSummary)
        ) {
        case .hidden:
            // #1070: nothing here renders while the keyboard is up — the banner floats onto the
            // keyboard's accessory row and occludes the #861 Done bar.
            EmptyView()
        // #665: the iCloud indicator shares this banner's place. Transient work wins when both want it —
        // it finishes, while a local-only or failed-sync state waits and will still be true when
        // the banner frees up.
        case .sync:
            SyncStatusBanner(
                summary: appState.iCloudStatusSummary,
                onOpenSettings: {
                    appState.openTab(.settings, from: SceneID(sceneIDToken))
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        // B-6: queued but not yet indexing. Without this the app said nothing at all about work
        // it was doing — the arbiter had already refused the splash for this same window.
        case .downloadsQueued:
            DownloadQueueBannerView(count: appState.downloadQueue.count)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .batch:
            if let batch = appState.indexingBatch {
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
            }
        case .summary:
            if let meta = appState.completedIndexingMetadata {
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
        case .none:
            EmptyView()
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

// MARK: - Tab shell banner (#1565)

extension View {
    /// Draws the tab shell's banner at the bottom of this tab and keeps the tab's content clear of it (#1565).
    ///
    /// Applied to each tab's root by `MainTabView`; see ``TabShellBannerModifier`` for how.
    func tabShellBanner<Banner: View>(@ViewBuilder _ banner: @escaping () -> Banner) -> some View {
        modifier(TabShellBannerModifier(banner: banner))
    }
}

/// Draws the indexing and iCloud banner at the bottom of a tab, in room the tab's own view controller sets aside (#1565).
///
/// ## What #1565 found
/// The shell applied the banner as a bottom `safeAreaInset` on each tab's root, from outside the root's
/// `NavigationStack`. A stack does not pass that inset to the screens it shows, so the banner was drawn over them.
/// Measured on iPhone 17 (iOS 26.5) with the Local Only banner up, its top edge at y = 721.7 and the tab bar's at 791:
/// - the Browse root, Browse ▸ Archives and the Settings root each came to rest with their last row's text at
///   y 732–755, under the banner, where it could be seen only while a drag was held and could not be tapped;
/// - Settings ▸ Volumes & Storage ▸ Download from GitHub drew its Download button at y 741–775, wholly under the
///   banner, so a reader with a banner showing could not start a download from that screen;
/// - the reader's web view ran to y = 791, its last 69 points under the banner, so the end of a document cleared the
///   banner only by the page's own bottom padding.
///
/// Two reservations made in SwiftUI from outside the stack were measured on the same device. `safeAreaPadding`
/// changed nothing. `contentMargins(.bottom, _, for: .scrollContent)` did reach the lists, at the root and one push
/// deep, but only scroll content: the Download button stayed under the banner.
///
/// ## What this does
/// The tab's content is hosted by a view controller of its own (SwiftUI's per-tab hosting controller, a child of the
/// tab bar controller). ``TabShellBannerReserve`` adds the banner's height to the bottom of THAT controller's safe
/// area, which is the one inset a navigation stack does pass on: UIKit hands a controller's safe area to every view
/// and child controller inside it. So everything in the tab ends above the banner without being told its height: a
/// list's last row, a pushed screen's own bottom bar, the reader, a placeholder centred in what is left. Measured
/// after: the three lists rest with their last row's text ending at y 685–686 and the Download button sits at
/// y 671–706; and on a build with this reserve, before the banner's drawing was final, the reader's web view ended
/// at y = 721.7, the banner's top edge.
///
/// The banner is then drawn in the room set aside: hung below the bottom edge of the safe area by its own height
/// (the alignment guide below). Its place is tied to that edge alone, so it covers nothing that keeps to the safe
/// area, whichever controller the reserve reached. Before the reserve lands, or if it never did, the banner would
/// hang behind the tab bar (measured on iPhone 17 with the reserve taken out: its top edge at y = 791, the tab
/// bar's own) and the content would be whole.
///
/// A sheet or a popover is presented, not contained: UIKit gives it a safe area of its own, which this does not
/// touch.
///
/// **The keyboard rule is unchanged (#1070).** While the keyboard is up `MainTabView.indexingBanner` renders
/// nothing, the stack below measures zero, and the reserve goes back to zero with it.
///
/// Version history:
///   1.0 — #1565: initial implementation
struct TabShellBannerModifier<Banner: View>: ViewModifier {

    /// The banner, or nothing while the shell has nothing to say.
    @ViewBuilder let banner: () -> Banner

    /// The banner's measured height, in points. Zero while it renders nothing.
    @State private var bannerHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background { TabShellBannerReserve(height: bannerHeight) }
            .overlay(alignment: .bottom) {
                // Measured through a stack, which lays out at zero height when the banner renders nothing, so the
                // reserve falls back to 0 instead of keeping a stale height.
                VStack(spacing: 0) { banner() }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        bannerHeight = height
                    }
                    // The overlay's bottom is the bottom edge of the safe area. Aligning the banner's TOP to it
                    // hangs the banner below that edge, in the room the reserve sets aside.
                    .alignmentGuide(.bottom) { $0[.top] }
            }
    }
}

/// Sets aside room at the bottom of the view controller that hosts a tab's content (#1565).
///
/// A UIKit view in the tab root's background, which draws nothing: it walks its responder chain to the nearest view
/// controller and sets that controller's `additionalSafeAreaInsets.bottom`. The nearest controller is the one whose
/// view holds both this view and the banner ``TabShellBannerModifier`` draws, so the room is set aside exactly where
/// the banner hangs. Measured on iPhone 17 (iOS 26.5): it is SwiftUI's `TabHostingController`, whose parent is the tab
/// bar controller.
///
/// **It writes after the update, never during it.** `updateUIView` runs inside SwiftUI's update, and changing the
/// host's safe area there would invalidate the layout SwiftUI is in the middle of computing. The write is queued on
/// the main queue instead, and reads the height then, so several changes in one update make one write. It also writes
/// no SwiftUI state at any point (a representable that does so while it is being built is the trap that once blanked
/// the semantic map).
///
/// Version history:
///   1.0 — #1565: initial implementation
struct TabShellBannerReserve: UIViewRepresentable {

    /// How much room to set aside, in points.
    let height: CGFloat

    /// Builds the reserving view. It draws nothing and takes no touches.
    func makeUIView(context: Context) -> ReservingView {
        let view = ReservingView()
        view.isUserInteractionEnabled = false
        view.height = height
        return view
    }

    /// Passes on a new height, to be applied once this update is over.
    func updateUIView(_ uiView: ReservingView, context: Context) {
        uiView.height = height
        uiView.reserveSoon()
    }

    /// Gives the room back when the tab's content goes away.
    static func dismantleUIView(_ uiView: ReservingView, coordinator: ()) {
        uiView.dismantle()
    }

    /// The UIKit view whose host is inset.
    final class ReservingView: UIView {

        /// How much room the host should set aside.
        var height: CGFloat = 0

        /// The controller this view last inset, so the room can be given back if the view leaves it.
        private weak var reservedHost: UIViewController?

        /// Set once SwiftUI has let go of this view. A write queued before then must not land after it.
        private var isDismantled = false

        /// Applies the height once the view has a host to apply it to.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            reserveSoon()
        }

        /// Queues the write for after the current update.
        func reserveSoon() {
            DispatchQueue.main.async { [weak self] in self?.reserve() }
        }

        /// Gives the room back for good: SwiftUI is done with this view.
        func dismantle() {
            isDismantled = true
            giveBack()
        }

        /// Takes the reserve off the host it was last applied to.
        private func giveBack() {
            reservedHost?.additionalSafeAreaInsets.bottom = 0
            reservedHost = nil
        }

        /// Sets the host's bottom inset to the height, if it is not that already.
        private func reserve() {
            guard !isDismantled, let host = nearestViewController else { return }
            if let reservedHost, reservedHost !== host { giveBack() }
            reservedHost = host
            if host.additionalSafeAreaInsets.bottom != height {
                host.additionalSafeAreaInsets.bottom = height
            }
        }

        /// The first view controller up this view's responder chain: the one whose view holds it.
        private var nearestViewController: UIViewController? {
            var responder = next
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }
    }
}

// MARK: - Scene session reader (#1368)

/// Reports the `persistentIdentifier` of the `UISceneSession` its window belongs to (#1368).
///
/// A SwiftUI view cannot see its own scene session, and an aux window's Done needs one to ask
/// iPadOS to bring the launching window forward — `activateSceneSession` takes a session, not
/// the app's own `SceneID` token. So `MainTabView` hosts this zero-size UIKit view in its
/// background, and so — since #1368's review round, for the windows an aux window launches —
/// does `AuxWindowOriginModifier`; the view reads `window?.windowScene?.session` once UIKit has
/// placed it in a window.
///
/// It reports from `didMoveToWindow`, never from `makeUIView`: a representable that writes state
/// while SwiftUI is building it is the trap that once blanked the semantic map. The one write it
/// causes lands in `AppState.mainWindowSessions` or `AppState.auxWindowSessions`, both
/// `@ObservationIgnored` and read by no view, so making it inside UIKit's window-attach pass
/// invalidates nothing.
struct SceneSessionReader: UIViewRepresentable {
    /// Called with the session's `persistentIdentifier` each time the view joins a window.
    let onSession: @MainActor (String) -> Void

    /// Builds the reporting view. It draws nothing and takes no touches.
    func makeUIView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.isUserInteractionEnabled = false
        view.onSession = onSession
        return view
    }

    /// Keeps the callback current; the report itself comes from the view's window changes.
    func updateUIView(_ uiView: ReportingView, context: Context) {
        uiView.onSession = onSession
    }

    /// The UIKit view whose window is read.
    final class ReportingView: UIView {
        /// Where the session identifier is sent.
        var onSession: (@MainActor (String) -> Void)?

        /// Reports the session of the window the view has just joined, if it has joined one.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let sessionID = window?.windowScene?.session.persistentIdentifier else { return }
            onSession?(sessionID)
        }
    }
}

#endif
