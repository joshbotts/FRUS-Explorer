// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// BrowserView is iOS-only. macOS uses MainWindowView with a NavigationStack.
#if os(iOS)

// MARK: - BrowserView

/// Root view for the hierarchical FRUS corpus browser.
///
/// Uses `NavigationSplitView` on macOS and iPadOS (regular horizontal size class)
/// for a persistent sidebar, and `NavigationStack` on iPhone for push navigation.
///
/// The sidebar (or root list) always shows the full subseries list so the user can
/// jump between subseries without backtracking.
///
/// ## Settings sheet coordination
/// The Settings sheet presentation flag lives in `AppState` (not as a local `@State`)
/// so that `ResetView` can dismiss the sheet programmatically. The sheet carries an
/// `onDismiss` handler (`handleSettingsSheetDismiss`) that completes the post-reset
/// transition to `OnboardingView` only after the sheet has fully animated out,
/// preventing a SwiftUI race where `ContentView` tries to replace this view while
/// a modal is still on screen.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 32: moved Settings sheet flag to `AppState`; added `onDismiss`
///          handler for safe post-reset navigation to `OnboardingView`
///   1.2 — Session 35: macOS fallback — `onChange(of: showSettingsSheet)` ensures
///          `handleSettingsSheetDismiss()` fires even when `onDismiss` is skipped
///          by SwiftUI on programmatic sheet dismissal (known macOS limitation)
///   1.3 — Session 40: pendingSearch observation — opens search sheet pre-filled
///   1.4 — Session 43: showSearch and showCitationLookup promoted to AppState
///   1.5 — Session 44: iOS stackLayout sheets/toolbar buttons removed; Settings/Search/
///          CitationLookup are tabs on iOS; pendingBrowseDocument observer added both platforms
///   1.6 — Session 46: macOS Settings sheet removed (now a Settings scene); gear button
///          removed; handleSettingsSheetDismiss removed; Collections toolbar button added
///   1.7 — Session 50: downloaded-volumes filter toggle in both toolbars; AppState sync
///          via onChange; macOS About sheet
///   1.8 — Session 60: Search and Collections sheets replaced with `.inspector` panel
///          (MacPanel enum); toolbar reorganized — ProjectPickerMenu to .navigation,
///          search tools grouped as .primaryAction, download filter as .secondaryAction
///          with Label; iPad splitLayout retains only picker + filter (tabs cover the rest)
///   1.9 — Session 61: About sheet removed; About is now a Window scene (F-014)
///   2.0 — Session 121: suppress BrowserBreadcrumbBar at .document level; multi-row
///          breadcrumb path was blocking document header on narrow screens (iOS)
///   2.1 — Session 2026-06-07: removed dead `#if os(macOS)` branches — this file has
///          been iOS-only (wrapped in a file-level `#if os(iOS)`) since Session 60's
///          `MainWindowView`/inspector-panel split, which made the nested macOS
///          `.inspector`/`MacPanel`/`showProjectContext`/toolbar code unreachable;
///          `appState.showSearch` (only ever set from the removed branch) was left
///          fully unused — removed from `AppState` in 2.2
///   2.2 — Session 2026-06-07: removed orphaned `appState.showSearch` (see 2.1);
///          `showCitationLookup` remains in AppState for the Citation Lookup sheet
///          (removed from AppState in 2.3 — iOS Citation Lookup is SearchView-local
///          sheet state; macOS is the frus.citationLookup Window scene)
///   2.3 — Session 2026-07-04 (macOS UI audit gap 12): pendingBrowseVolume observer —
///          Cross-Volume Provenance rows dismiss-and-navigate to the cited volume
///          (the volume-grain sibling of the pendingBrowseDocument observer)
///   2.4 — Session 1 / #238 Fix B: iPad (regular width) now uses `stackLayout`
///          (`NavigationStack`) instead of `splitLayout` (`NavigationSplitView`). The nested
///          split inside the `.sidebarAdaptable` TabView overlaid content in the iPadOS
///          floating-top-tab-bar representation; `splitLayout`/`SubseriesListView` are kept
///          unreferenced for easy revert. Breadcrumb also suppressed at regular width (Fix A).
///   2.5 — Session 1 review: Fix A's breadcrumb suppression gated on pad idiom + regular
///          width (size class alone also fired on Plus/Max iPhones in landscape, where the
///          bottom tab bar never occludes the bar)
///   2.6 — #486: the "Working on:" banner moved INSIDE the NavigationStack — a top
///          `.safeAreaInset` on `BrowserView()` (applied by `BrowserTabView`) drew over the
///          navigation bar rather than below it. It is now an inset on the `CorpusView` root
///          and folded into the per-level breadcrumb inset, so it appears at every Browse
///          depth and reserves space below the bar.
///   2.7 — #498: `.statusBarHidden(false)` on each analysis sheet's content, outside the inner
///          NavigationStack — the actual fix for the rotation deadlock the orientation lock was
///          only mitigating. See the note above the sheet declarations.
///   2.8 — Wave R / R-9: `appState.indexingPipeline` is back-filled into the view model by
///          an `onChange` observer, alongside the #324 `downloadManager` one it was always
///          missing. Bootstrapping from `.onAppear` can capture a nil pipeline, which made
///          every compilation report "Index Required" for the rest of the session.
///   2.9 — Wave R / R-8: the analysis menu and the downloaded-only filter name themselves in
///          their `Label`s instead of relying on `.controlHelp` / `.accessibilityLabel` alone.
///          An item collapsed into the iPadOS toolbar overflow takes its accessible name from
///          the label closure, so the analysis menu announced "chart.bar.xaxis". Adds the
///          `#if DEBUG` `uiTestOverflowFillerItems` seam that lets a UI test reach that state.
///   Session 09: `pendingBrowseVolume` resolves against the unfiltered manifest —
///         the filtered-groups lookup silently dropped hand-offs to undownloaded
///         volumes, which the subject pivot routinely targets.
///   2.10 — Session 2026-08-11: #833 — the Archival Analytics row produces a hand-off instead
///          of presenting its own sheet, so iOS has one presenter of that surface
struct BrowserView: View {

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    /// The shared container, re-injected into the three analytics sheets (#258 P3 review).
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BrowserViewModel?
    // Corpus Analytics / Chronology are presented as sheets from the Browse toolbar. These items
    // MUST live inside BrowserView's own NavigationStack/NavigationSplitView — when they were
    // declared on `BrowserView()` from BrowserTabView (outside the nav container) they were silently
    // dropped and the features became unreachable on iPhone and iPad.
    @State private var showAnalytics = false
    @State private var analyticsParameters: AnalyticsParameters?
    @State private var showPersonAnalytics = false
    @State private var showCrossRefAnalytics = false
    /// Semantic Analytics (the map, its lenses and slices).
    @State private var showSemanticAnalytics = false
    /// The scope and lens a continued map should open with (UI review F-28), or `nil` for a map
    /// the reader opened here.
    @State private var continuedSemanticMap: SemanticMapRequest?
    @State private var showChronology = false
    @State private var chronologyParameters: ChronologyParameters?
    // #498: every one of these sheets presents a view that opens its OWN NavigationStack, which
    // nests a second SwiftUI graph host inside the window's. Rotating one of them while a
    // platform-backed text field inside it has been focused makes UIKit re-enter that nested host
    // through `-[UIViewController _traitCollectionDidChange:]` to resolve `childForStatusBarHidden`,
    // reading a preference out of the transaction that is still building it — the AttributeGraph
    // cycle. Authoring `.statusBarHidden(false)` on the view handed to `.sheet` (OUTSIDE the inner
    // NavigationStack) gives that query a locally-resolvable answer, so it never recurses. The
    // placement is the fix: the identical modifier applied INSIDE the inner NavigationStack still
    // wedges. Measured on iPhone 17 Pro Max, iOS 26: 29,040,997 cycle detections + a hang before,
    // 0 after; see the sibling coverage in `AnalyticsRotationTests`.
    // showCitationLookup lives in AppState (promoted in Session 43) so that macOS
    // menu commands and future iOS tab navigation can trigger it. On iOS, Search/
    // Citation Lookup/Settings are persistent tabs (MainTabView) — BrowserView
    // itself only reacts to ProjectPickerMenu taps (→ Research tab) and
    // pendingBrowseDocument/filterDownloadedOnly below.

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var appState = appState
        Group {
            if let vm = viewModel {
                // #238 Fix B: use the NavigationStack layout on every size class. A
                // NavigationSplitView nested inside the `.sidebarAdaptable` TabView is an
                // unsupported composition on iPadOS 26 — in the collapsed floating-top-tab-bar
                // representation the nested detail column mis-computes its top safe area and
                // overlays content that can't be scrolled into view. NavigationStack-per-tab is
                // the shape Apple documents for `.sidebarAdaptable`: the tab sidebar remains the
                // persistent rail and the subseries list is the stack root (`CorpusView`).
                //
                // `splitLayout` / `SubseriesListView` are retained (currently unreferenced) so
                // this change can be reverted by restoring the `sizeClass == .regular` branch.
                // See Planning/Completed/Issues-233-243-Plan.md Session 1 and Planning/Completed/BigPicture-iPadMacParity.md.
                stackLayout(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appState.pendingBrowseDocument) { _, _ in
            consumePendingBrowseDocument()
        }
        // Volume-grain sibling of the observer above (UI audit gap 12): Cross-Volume
        // Provenance rows and the Session-9 subject pivot hand off a volume id; push
        // its browser level and clear. Resolve from the UNFILTERED manifest — the old
        // lookup through `allSubseriesGroups` respected the "downloaded only" filter,
        // silently dropping hand-offs to undownloaded volumes, which the subject
        // pivot's cross-corpus list routinely targets (VolumeView shows its own
        // Download placeholder for those).
        .onChange(of: appState.pendingBrowseVolume) { _, _ in
            consumePendingBrowseVolume()
        }
        .onChange(of: appState.filterDownloadedOnly) { _, flag in
            viewModel?.filterDownloadedOnly = flag
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView(initialParameters: analyticsParameters)
                .environment(appState)
                // #258 P3 review (INFO, taken): the shared scope bar hosts a @Query;
                // sheets inherit the WindowGroup's container today, but re-injecting
                // matches the SearchView convention and survives a future #241-program
                // move of these views into their own window scenes.
                .modelContainer(modelContext.container)
                // #338 step 5: publish this window's scene id so AnalyticsView's "open in Search"
                // hand-off targets THIS window (a sheet doesn't reliably inherit `\.sceneID`) —
                // matching the sibling CrossRef-Analytics / Chronology sheets below.
                .environment(\.sceneID, sceneID)
                // Wave B fix: the default form sheet (~540pt) is too narrow for the consolidated
                // filter row and cramps the chart. `.page` sizing gives the sheet a wider canvas on
                // iPad (a no-op on compact iPhone, which uses the full-height sheet regardless).
                .presentationSizing(.page)
                // #498: author the status-bar preference HERE, on the view handed to `.sheet`,
                // outside AnalyticsView's own NavigationStack. See the note below.
                .statusBarHidden(false)
        }
        .sheet(isPresented: $showPersonAnalytics) {
            PersonAnalyticsView()
                .environment(appState)
                .modelContainer(modelContext.container)
                // #498: same fix, same reason — this sheet's two person-search fields reproduced
                // the cycle too (bounded, ~30 detections per rotation rather than a wedge, but the
                // same defect). One line here covers every field on the sheet.
                .statusBarHidden(false)
        }
        .sheet(isPresented: $showSemanticAnalytics) {
            // A sheet, matching its siblings — and note this is an iOS-only presentation. On macOS
            // the same view is a Window scene, because an MTKView in a SwiftUI sheet there draws,
            // presents, and never reaches the screen. That is an AppKit `SheetPresentationWindow`
            // behaviour; UIKit presents a sheet as a view controller and the map renders. Verified
            // on the simulator rather than assumed, because the macOS failure looked exactly like
            // this and cost two sessions.
            SemanticAnalyticsView(appState: appState, continued: continuedSemanticMap)
                .environment(appState)
                .modelContainer(modelContext.container)
                .environment(\.sceneID, sceneID)
                .statusBarHidden(false)
        }
        .sheet(isPresented: $showCrossRefAnalytics) {
            CrossReferenceAnalyticsView()
                .environment(appState)
                .modelContainer(modelContext.container)
                // #338 step 4: publish this window's scene id so the analytics view's document /
                // volume open actions target THIS window (a sheet doesn't reliably inherit it).
                .environment(\.sceneID, sceneID)
                // #498: prophylactic. This sheet has no text field today, so it does not currently
                // reproduce — but it is the same sheet → own-NavigationStack shape, and adding a
                // field later would silently re-open the defect.
                .statusBarHidden(false)
        }
        .sheet(isPresented: $showChronology) {
            ChronologyView(initialParameters: chronologyParameters)
                .environment(appState)
                // #338 step 2: a sheet doesn't reliably inherit `\.sceneID` (review Finding 1), so
                // publish it explicitly so ChronologyView's Word Cloud button targets THIS window.
                .environment(\.sceneID, sceneID)
                // #498: prophylactic, as above — no text field today, same presentation shape.
                .statusBarHidden(false)
        }
        // Search → Analytics handoff (a capped search offered to "Visualize in Corpus Analytics")
        // and the cross-view → Chronology handoff. Captured into local state before presenting, then
        // cleared on AppState so the observer doesn't refire on the next sheet dismissal.
        // #338 step 3: consume the hand-off only when it is addressed to THIS window's scene, so a
        // word cloud's / search's Analyze or Chronology hand-off no longer fans its sheet out to
        // every open iPad window. `consumeHandoff` re-reads, target-checks, and clears in one step.
        .onChange(of: appState.pendingAnalytics) { _, _ in consumePendingAnalytics() }
        .onChange(of: appState.pendingChronology) { _, _ in consumePendingChronology() }
        .onChange(of: appState.pendingSemanticMap) { _, _ in consumePendingSemanticMap() }
        .onAppear {
            bootstrapViewModel()
            // Cumulative-review fix: `.onChange` only observes changes made while this view is
            // attached, but the content channels can be set BEFORE BrowserView exists — a
            // Related-Documents row tap or subject-chip pivot from another tab posts the value
            // and switches to Browse via pendingTab, and Browse may be freshly instantiated.
            // Drain anything already pending once the view model exists (bootstrap is
            // synchronous, so it does).
            consumePendingBrowseDocument()
            consumePendingBrowseVolume()
            // Analytics and Chronology were the only two iOS channels with no appear-time drain
            // (#750 / audit H-8, H-11) — and they are the ones whose producers ALWAYS instantiate
            // Browse as part of the same action: `openAnalytics(...)` then `openTab(.browse)`. On a
            // cold launch on another tab, or in a fresh iPad window, `.onChange` never fires for a
            // value set before the view attached, so the sheet never opened and the hand-off sat
            // parked until a later one overwrote it. Repeating the action "worked", which is what
            // made it look intermittent rather than broken.
            consumePendingAnalytics()
            consumePendingSemanticMap()
            consumePendingChronology()
        }
        // #324: under FRUS_UI_TEST_MODE the browse stack can render before AppState
        // finishes booting the download manager, so the view model would capture nil
        // for the session and report every volume as not-downloaded. Back-fill it the
        // moment the manager appears (a no-op in production, where it exists at boot).
        .onChange(of: appState.downloadManager == nil) { _, isNil in
            if !isNil { viewModel?.attachDownloadManagerIfNeeded(appState.downloadManager) }
        }
        // R-9: the sibling of the #324 back-fill above, and the half that fix left undone.
        // `appState.indexingPipeline` is assigned EARLIER than the download manager (both inside
        // bootDownloadManager), so a view model that captured a nil manager captured a nil
        // pipeline too — and only the manager was ever repaired. Without this, `isIndexed`
        // answered false for every volume for the rest of the session, so CompilationView showed
        // "Index Required" for fully indexed volumes and its "Index Now" button did nothing.
        .onChange(of: appState.indexingPipeline == nil) { _, isNil in
            if !isNil { viewModel?.attachIndexingPipelineIfNeeded(appState.indexingPipeline) }
        }
        // Warm the lazy volume-subject-profiles decode off the main thread while the
        // user is still at the subseries/volume lists, so the first VolumeView push
        // doesn't pay the (small) decode inside its body evaluation. `static let`
        // initialization is thread-safe; later main-thread reads are plain accesses.
        .task {
            Task.detached(priority: .utility) { _ = VolumeSubjectProfilesStore.shared }
        }
    }

    // MARK: - Shared Toolbar Content

    /// Chronology + Corpus Analytics buttons, shared by the split (iPad) and stack (iPhone) layouts.
    /// Declared as `ToolbarContent` so it can be composed into each layout's `.toolbar` *inside* the
    /// navigation container (the only place toolbar items actually render).
    /// Chronology / Corpus Analytics / Word Cloud, grouped into a single explicit
    /// `Menu` rather than three separate `.primaryAction` buttons.
    ///
    /// On iPad the Browse sidebar toolbar previously held five primary items (project
    /// picker, downloaded-only filter, and these three), which iPadOS collapsed into an
    /// auto-overflow "…" control that could fail to open — leaving Corpus Analytics
    /// effectively unreachable from the browser. A dedicated `Menu` is always tappable
    /// and keeps the toolbar to three primary items.
    ///
    /// ## Why the label is a `Label` and not an `Image` (R-8)
    /// This button's name reached VoiceOver as the raw symbol string `chart.bar.xaxis`
    /// whenever iPadOS collapsed it into the navigation-bar overflow. `.controlHelp`'s
    /// `.accessibilityLabel` decorates only the in-bar representation; the overflow row
    /// re-derives its name from the label closure's own content. Naming the `Label`
    /// fixes both representations, and the bar still renders it icon-only.
    @ToolbarContentBuilder
    private var analyticsToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    chronologyParameters = nil
                    showChronology = true
                } label: {
                    Label(String(localized: "browse.chronology.a11y", defaultValue: "Chronology"),
                          systemImage: "calendar.day.timeline.left")
                }
                Button {
                    analyticsParameters = nil
                    showAnalytics = true
                } label: {
                    Label(String(localized: "browse.analytics.a11y", defaultValue: "Corpus Analytics"),
                          systemImage: "chart.bar.xaxis")
                }
                Button {
                    showPersonAnalytics = true
                } label: {
                    Label(String(localized: "browse.personAnalytics.a11y", defaultValue: "Person Analytics"),
                          systemImage: "person.2")
                }
                Button {
                    showCrossRefAnalytics = true
                } label: {
                    Label(String(localized: "browse.crossRefAnalytics.a11y", defaultValue: "Cross-Reference Analytics"),
                          systemImage: "point.3.connected.trianglepath.dotted")
                }
                Button {
                    // Through the hand-off, like the word cloud below it: the tab shell is the
                    // single iOS presenter (#833), so this button and the topic/search doors all
                    // reach the same surface. An empty volume set means "no scope".
                    appState.openArchivalScope(.unscoped, from: sceneID)
                } label: {
                    Label(String(localized: "browse.archivalAnalytics.a11y",
                                 defaultValue: "Archival Analytics"),
                          systemImage: "archivebox")
                }
                Button {
                    showSemanticAnalytics = true
                } label: {
                    Label(String(localized: "browse.semanticAnalytics.a11y",
                                 defaultValue: "Semantic Analytics"),
                          systemImage: "point.3.filled.connected.trianglepath.dotted")
                }
                Button {
                    appState.openWordCloud(.corpus, from: sceneID)
                } label: {
                    Label { Text(String(localized: "browse.wordcloud.a11y", defaultValue: "Corpus Word Cloud")) }
                        icon: { Image(systemName: WordCloudGlyph.symbol) }
                }
            } label: {
                Label(Self.analysisToolsName, systemImage: "chart.bar.xaxis")
            }
            .controlHelp(
                Self.analysisToolsName,
                detail: String(localized: "browse.analysisTools.help.v3",
                               defaultValue: "Chronology, Corpus Analytics, Person Analytics, Cross-Reference Analytics, Archival Analytics, Semantic Analytics, and the corpus Word Cloud"),
                systemImage: "chart.bar.xaxis"
            )
        }
    }

    /// The analysis menu's name, used by BOTH its `Label` (which is what the iPadOS
    /// toolbar overflow reads) and its `.controlHelp` (which is what the in-bar
    /// representation reads). One property so the two can never drift apart — a drift
    /// that is invisible until the toolbar happens to overflow. See R-8.
    /// Computed, not a stored `static let`, so the lookup is re-resolved per render exactly
    /// as the inline `String(localized:)` it replaced was — a stored one would freeze the
    /// locale at first access.
    static var analysisToolsName: String {
        String(localized: "browse.analysisTools.a11y", defaultValue: "Analysis Tools")
    }

    /// The downloaded-only filter's name, shared by both layouts' toolbars. Like the
    /// analysis menu it is read twice — once from the `Label` (the iPadOS overflow row)
    /// and once from `.accessibilityLabel` (the in-bar button) — so it lives in one place.
    private var downloadFilterName: String {
        appState.filterDownloadedOnly
            ? String(localized: "browser.filter.off.a11y",
                     defaultValue: "Show all volumes")
            : String(localized: "browser.filter.on.a11y",
                     defaultValue: "Show downloaded volumes only")
    }

    /// The downloaded-only filter's glyph — filled while the filter is on.
    private var downloadFilterSymbol: String {
        appState.filterDownloadedOnly ? "arrow.down.circle.fill" : "arrow.down.circle"
    }

    /// The downloaded-only filter's tooltip / VoiceOver hint.
    private var downloadFilterHelp: String {
        appState.filterDownloadedOnly
            ? String(localized: "browser.filter.off.help",
                     defaultValue: "Show all volumes in the corpus, including those not yet downloaded")
            : String(localized: "browser.filter.on.help",
                     defaultValue: "Show only volumes you have downloaded and can browse offline")
    }

    #if DEBUG
    /// The launch-environment key a UI test sets to force this toolbar into the iPadOS
    /// navigation-bar overflow (R-8).
    static let uiTestToolbarOverflowKey = "FRUS_UI_TEST_TOOLBAR_OVERFLOW"

    /// Inert filler toolbar items that exist only to make iPadOS collapse the Browse
    /// toolbar into its overflow control.
    ///
    /// ## Why a seam and not a plain assertion
    /// R-8's defect is observable only once an item has been **re-hosted** into the
    /// overflow: while it sits in the bar, `.controlHelp`'s `accessibilityLabel` is
    /// present and correct, and the raw-symbol name never appears. No shipping iPad size
    /// collapses the three-item Browse toolbar — measured on iPad Pro 13-inch (M5) and
    /// iPad mini (A17 Pro), portrait, both of which keep all three items in the bar — so
    /// a UI test that merely looked for "Analysis Tools" would pass against the bug. This
    /// seam creates the state the assertion is actually about.
    ///
    /// Gated twice over, like `UITestVolumeSeeder`: the whole block is `#if DEBUG` (absent
    /// from AppStore and DirectDistribution builds) and it emits nothing unless
    /// ``uiTestToolbarOverflowKey`` is set to `"1"`.
    @ToolbarContentBuilder
    private var uiTestOverflowFillerItems: some ToolbarContent {
        if ProcessInfo.processInfo.environment[Self.uiTestToolbarOverflowKey] == "1" {
            // Six, not three: the item count needed to overflow grows with screen width,
            // and this must hold on the widest installed iPad. Names are unlocalized on
            // purpose — this content cannot reach a shipping build.
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 1", systemImage: "1.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 2", systemImage: "2.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 3", systemImage: "3.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 4", systemImage: "4.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 5", systemImage: "5.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { } label: { Label("UI Test Filler 6", systemImage: "6.circle") }
            }
        }
    }
    #endif

    // MARK: - Layout Variants

    /// The iPad/regular-width two-column layout.
    ///
    /// **Currently unreferenced (#238 Fix B):** `body` routes every size class through
    /// `stackLayout` because nesting this `NavigationSplitView` inside the `.sidebarAdaptable`
    /// TabView overlaid content in the collapsed top-tab-bar representation. It is kept intact
    /// so the change is a one-line revert (restore the `sizeClass == .regular` branch in `body`).
    @ViewBuilder
    private func splitLayout(vm: BrowserViewModel) -> some View {
        NavigationSplitView {
            SubseriesListView(vm: vm)
                .navigationTitle(String(localized: "browser.title", defaultValue: "FRUS Explorer"))
                .toolbar {
                    // iPad split layout: Search and Citation Lookup are persistent
                    // tabs, so only the project picker and download filter appear here.
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu {
                            appState.openTab(.research, from: sceneID)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.filterDownloadedOnly.toggle()
                        } label: {
                            // R-8: named `Label`, not a bare `Image` — the iPadOS toolbar
                            // overflow re-derives the row's name from this closure.
                            Label(downloadFilterName, systemImage: downloadFilterSymbol)
                        }
                        .accessibilityLabel(downloadFilterName)
                        .help(downloadFilterHelp)
                    }
                    analyticsToolbarItems
                }
        } detail: {
            if let last = vm.navigationPath.last {
                levelView(for: last, vm: vm)
            } else {
                CorpusView(vm: vm)
            }
        }
    }

    @ViewBuilder
    private func stackLayout(vm: BrowserViewModel) -> some View {
        NavigationStack(path: Binding(
            get: { vm.navigationPath },
            set: { vm.navigationPath = $0 }
        )) {
            CorpusView(vm: vm)
                // #486: the "Working on:" banner, INSIDE the NavigationStack. Applied to
                // `BrowserView()` from the tab wrapper it was drawn over the navigation bar
                // (a top inset on a navigation container is composited into the bar's chrome
                // band, not pushed below it) and clipped the root's three trailing toolbar
                // items. Here it reserves space below the bar, like the per-level breadcrumb.
                // Pushed levels get it from `levelView(for:vm:)`'s inset, so the banner is
                // present at every Browse depth (the #377 Phase 5 intent). Reserves zero
                // height when no project with a research question is active, and renders
                // nothing at all on regular-width iPad (#461/#462 — the research question is
                // a navigation subtitle there instead; see `WorkingOnBanner`).
                .safeAreaInset(edge: .top, spacing: 0) { WorkingOnBanner() }
                .navigationTitle(String(localized: "browser.title", defaultValue: "FRUS Explorer"))
                .navigationDestination(for: BrowserViewModel.BrowserLevel.self) { level in
                    levelView(for: level, vm: vm)
                }
                .toolbar {
                    // On iOS, Search/CitationLookup/Settings are persistent tabs.
                    // Only the ProjectPickerMenu and download filter remain in the Browse toolbar.
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu {
                            appState.openTab(.research, from: sceneID)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.filterDownloadedOnly.toggle()
                        } label: {
                            // R-8: named `Label`, not a bare `Image` — the iPadOS toolbar
                            // overflow re-derives the row's name from this closure.
                            Label(downloadFilterName, systemImage: downloadFilterSymbol)
                        }
                        .accessibilityLabel(downloadFilterName)
                        .help(downloadFilterHelp)
                    }
                    analyticsToolbarItems
                    #if DEBUG
                    uiTestOverflowFillerItems
                    #endif
                }
        }
    }

    // MARK: - Level Router

    /// Routes a `BrowserLevel` to its corresponding view and injects the breadcrumb bar.
    ///
    /// `Group` is used instead of `AnyView` so that SwiftUI can look through the wrapper
    /// and determine the concrete view type for each case. This preserves `@State` identity
    /// across re-renders of `BrowserView.body` — critical for `DocumentView`, whose
    /// `@State var vm: DocumentViewModel?` must survive parent re-renders without resetting.
    ///
    /// Using `AnyView` here erases structural identity. When `BrowserView.body` re-renders
    /// (triggered by any change to `vm.navigationPath`), SwiftUI cannot diff through `AnyView`
    /// and recreates the wrapped view, resetting `@State` and restarting document loading.
    ///
    /// ## Breadcrumb suppression
    /// `BrowserBreadcrumbBar` is a pinned `.safeAreaInset(edge: .top)` overlay. It is suppressed in
    /// two cases:
    ///  - **Regular-width iPad (#238):** under the iPadOS floating top tab bar (the collapsed
    ///    `.sidebarAdaptable` representation) a pinned top inset is drawn beneath the tab bar and
    ///    cannot be scrolled into view. The tab sidebar and the navigation back button convey
    ///    location on iPad, so the bar is dropped when the pad idiom reports regular width
    ///    (Plus/Max iPhones in landscape and compact-width iPads keep the bottom tab bar and
    ///    keep the breadcrumb).
    ///  - **Document level (any width, Session 121):** a full corpus-to-document path wraps to
    ///    2–3 rows (~100 pt) and, as a `.safeAreaInset` overlay, blocks the document header and
    ///    initial body content. The inline document title and back button suffice inside a document.
    ///
    /// ## "Working on:" banner (#486)
    /// The same inset also carries `WorkingOnBanner`, stacked above the breadcrumb. It used to be
    /// applied to `BrowserView()` from `BrowserTabView` — outside this `NavigationStack` — where it
    /// was composited over the navigation bar instead of pushing content below it, clipping the back
    /// button, the title, and the trailing toolbar items on iPhone. Unlike the breadcrumb it is
    /// suppressed at no depth; the reasoning (and the measurement behind it) is at the inset itself.
    @ViewBuilder
    private func levelView(for level: BrowserViewModel.BrowserLevel, vm: BrowserViewModel) -> some View {
        Group {
            switch level {
            case .corpus:            CorpusView(vm: vm)
            case .subseries(let g):  SubseriesView(vm: vm, group: g)
            case .volume(let e):     VolumeView(vm: vm, volume: e)
            case .compilation(let vid, let s): CompilationView(vm: vm, volumeId: vid, section: s)
            case .document(let e):   DocumentView(entry: e, onNavigateToDocument: pushInBrowseStack)
            case .people:            PersonIndexView()
            }
        }
        // #377 Phase 5 follow-up: keep the "Working on:" research-question subtitle visible at every
        // pushed Browse depth on regular-width iPad (each level sets its own navigationTitle; this
        // pairs the subtitle to it). The corpus root is rendered directly in `stackLayout`, so it
        // carries its own `.workingOnSubtitle()`; no level view sets a subtitle of its own to clobber.
        .workingOnSubtitle()
        .safeAreaInset(edge: .top, spacing: 0) {
            // #486: banner ABOVE the breadcrumb, in ONE inset rather than a competing second one.
            // Both children reserve zero height when inactive, so a level with neither (no active
            // project, or any level on regular-width iPad) still insets nothing.
            //
            // The banner is NOT suppressed at any depth — including `.document`, unlike the
            // breadcrumb. Measured on iPhone 17 Pro (iOS 26.5) with a real volume open: the
            // document body is a `WKWebView` whose scroll view keeps the default
            // `contentInsetAdjustmentBehavior`, so it adopts the reduced safe area and the prose
            // starts BELOW the banner rather than under it. Session 121's document-level
            // suppression exists because the breadcrumb wraps to 2–3 rows (~100 pt) and buries the
            // document header; the banner is one ~22 pt line and does not.
            VStack(spacing: 0) {
                WorkingOnBanner()
                breadcrumbBarIfAppropriate(for: level, vm: vm)
            }
        }
    }

    /// The breadcrumb bar for a pushed Browse level, or nothing.
    @ViewBuilder
    private func breadcrumbBarIfAppropriate(for level: BrowserViewModel.BrowserLevel,
                                            vm: BrowserViewModel) -> some View {
        Group {
            // Breadcrumb suppression (see doc comment above):
            //  - iPad (#238): a pinned `.safeAreaInset` breadcrumb is occluded by the iPadOS
            //    floating top tab bar (`.sidebarAdaptable`) and cannot be scrolled into view.
            //    The tab sidebar and the navigation back button convey location instead.
            //    Rendering `EmptyView` (rather than hiding a laid-out bar) keeps the crumbs
            //    out of the accessibility tree too — no hidden-but-focusable chrome for
            //    VoiceOver / keyboard users. Gated on the pad idiom AND regular width, NOT
            //    size class alone: Plus/Max iPhones report regular width in landscape but
            //    keep the bottom tab bar (no occlusion, no sidebar rail), and a compact-width
            //    iPad (Slide Over / narrow Split View) also shows the bottom tab bar, where
            //    the breadcrumb is safe and useful.
            //  - Document level (any width, Session 121): the wrapped multi-row path blocks
            //    the document header.
            if UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular {
                EmptyView()
            } else if case .document = level {
                EmptyView()
            } else {
                BrowserBreadcrumbBar(path: vm.navigationPath) { index in
                    if let index {
                        vm.navigationPath = Array(vm.navigationPath.prefix(index + 1))
                    } else {
                        vm.navigationPath = []
                    }
                }
            }
        }
    }

    // MARK: - Bootstrap

    /// Consumes a pending document hand-off, pushing it onto the browse stack and clearing the
    /// channel. Callable from both the `.onChange` observer (value set while the view is live)
    /// and `.onAppear` (value set before the view existed). The clear happens only AFTER a
    /// successful adopt — a nil view model leaves the value pending for the drain that runs once
    /// bootstrap completes (previously the optional-chained append silently dropped it).
    /// Follows a cross-reference or page-turn inside the Browse stack (#751 / audit M-17a).
    ///
    /// Browse is where the hand-off already lands, so `.push` is exactly what the old routing did —
    /// this changes nothing for cross-references. What it adds is `.replace`: a page-turn no longer
    /// deepens the stack, so paging through twenty documents costs one Back tap instead of twenty
    /// (there is no breadcrumb escape at document level, and none at all on regular-width iPad).
    ///
    /// Routing directly is also simpler than the hand-off it replaces for this case: no round trip
    /// through `AppState`, and no window-targeting question, because the reader is already here.
    private func pushInBrowseStack(_ entry: DocumentBrowserEntry, _ jump: DocumentJump) {
        guard let vm = viewModel else { return }
        if jump == .replace, !vm.navigationPath.isEmpty {
            vm.navigationPath.removeLast()
        }
        vm.navigationPath.append(.document(entry))
    }

    private func consumePendingBrowseDocument() {
        // #338 step 4: consume only a hand-off addressed to THIS window's scene, so a document open
        // no longer fans out to every iPad window. The `vm` check precedes the consume (short-circuit),
        // so a not-yet-bootstrapped window leaves the hand-off pending for the onAppear drain.
        guard let sceneID, let vm = viewModel,
              let entry = appState.consumeHandoff(\.pendingBrowseDocument, for: sceneID,
                                                  orAnyWindow: true) else { return }
        vm.navigationPath.append(.document(entry))
        #if DEBUG
        print("[BrowserView] pendingBrowseDocument consumed: \(entry.volumeId)/\(entry.documentId)")
        #endif
    }

    /// Consumes a pending Corpus Analytics hand-off and presents the sheet (#750 / audit H-8, H-11).
    ///
    /// Extracted from the `.onChange` observer so the same code can run from `.onAppear`. Both
    /// entry points are required: the producers write the slot and *then* call `openTab(.browse)`,
    /// so on a cold launch or a fresh iPad window the tab switch is what creates this view — and
    /// `.onChange` never fires for a value that was already set when the view attached.
    ///
    /// Unlike the browse-document twins this does not wait on `viewModel`: presenting the sheet
    /// needs only the parameters, and gating on bootstrap would reintroduce the dropped hand-off
    /// this fixes.
    private func consumePendingAnalytics() {
        guard let sceneID,
              let params = appState.consumeHandoff(\.pendingAnalytics, for: sceneID) else { return }
        analyticsParameters = params
        showAnalytics = true
    }

    /// Semantic-map twin of ``consumePendingAnalytics`` — same both-ways contract (#750).
    ///
    /// The map handed off from another device (UI review F-28). Both entry points matter here for
    /// the reason the doc above gives, and more so: a Handoff arrives at a cold launch as often as
    /// not, so `.onChange` alone would drop the continuation that started the app.
    private func consumePendingSemanticMap() {
        guard let sceneID,
              let request = appState.consumeHandoff(\.pendingSemanticMap, for: sceneID,
                                                    orAnyWindow: true) else { return }
        continuedSemanticMap = request
        showSemanticAnalytics = true
    }

    /// Chronology twin of ``consumePendingAnalytics`` — same both-ways contract (#750).
    private func consumePendingChronology() {
        guard let sceneID,
              let params = appState.consumeHandoff(\.pendingChronology, for: sceneID) else { return }
        chronologyParameters = params
        showChronology = true
    }

    /// Volume-grain sibling of `consumePendingBrowseDocument` — same adopt-then-clear contract.
    private func consumePendingBrowseVolume() {
        // #338 step 4: scene-addressed twin of consumePendingBrowseDocument (same vm-before-consume order).
        guard let sceneID, let vm = viewModel,
              let volumeId = appState.consumeHandoff(\.pendingBrowseVolume, for: sceneID,
                                                     orAnyWindow: true) else { return }
        guard let entry = appState.manifestStore.entry(forVolumeId: volumeId) else { return }
        vm.navigationPath.append(.volume(entry))
        #if DEBUG
        print("[BrowserView] pendingBrowseVolume consumed: \(volumeId)")
        #endif
    }

    private func bootstrapViewModel() {
        guard viewModel == nil else { return }
        let vm = BrowserViewModel(
            manifestStore: appState.manifestStore,
            tagStore: appState.volumeLevelTagStore,
            downloadManager: appState.downloadManager,
            indexingPipeline: appState.indexingPipeline
        )
        vm.filterDownloadedOnly = appState.filterDownloadedOnly
        viewModel = vm
        #if DEBUG
        print("[BrowserView] BrowserViewModel created.")
        #endif
    }
}

// MARK: - SubseriesListView (shared sidebar / root list)

/// The subseries list used as the sidebar content in split layouts and as the root
/// in stack layouts (via `CorpusView`).
private struct SubseriesListView: View {
    let vm: BrowserViewModel

    var body: some View {
        List(vm.allSubseriesGroups) { group in
            Button {
                vm.navigationPath = [.subseries(group)]
            } label: {
                SubseriesRowView(group: group)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "Subseries \(group.subseries), ^[\(group.totalVolumes) volume](inflect: true)"
            )
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - SubseriesRowView

private struct SubseriesRowView: View {
    let group: SubseriesGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.subseries)
                .font(.headline)
            // Inflected: the browse screenshot in the UI review shows "1989–92 · 1 volumes"
            // (F-23). The automatic-grammar form fixes singular and plural in every locale that
            // supports it rather than hand-branching English.
            Text("^[\(group.totalVolumes) volume](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        // #312 follow-up: full-row tap target. BOTH modifiers, in this order — the frame widens
        // this VStack (whose intrinsic width is only its longest line) to the row, and
        // contentShape makes the widened area hit-testable, since the enclosing
        // `.buttonStyle(.plain)` Button hit-tests only opaque content. See `CorpusView` for the
        // A/B measurement behind "both, in this order".
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#endif // os(iOS)
