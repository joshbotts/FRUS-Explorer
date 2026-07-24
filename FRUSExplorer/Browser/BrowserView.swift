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
///   Session 09: `pendingBrowseVolume` resolves against the unfiltered manifest —
///         the filtered-groups lookup silently dropped hand-offs to undownloaded
///         volumes, which the subject pivot routinely targets.
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
    @State private var showChronology = false
    @State private var chronologyParameters: ChronologyParameters?
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
                // See Planning/Issues-233-243-Plan.md Session 1 and BigPicture-iPadMacParity.md.
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
        }
        .sheet(isPresented: $showPersonAnalytics) {
            PersonAnalyticsView()
                .environment(appState)
                .modelContainer(modelContext.container)
        }
        .sheet(isPresented: $showCrossRefAnalytics) {
            CrossReferenceAnalyticsView()
                .environment(appState)
                .modelContainer(modelContext.container)
                // #338 step 4: publish this window's scene id so the analytics view's document /
                // volume open actions target THIS window (a sheet doesn't reliably inherit it).
                .environment(\.sceneID, sceneID)
        }
        .sheet(isPresented: $showChronology) {
            ChronologyView(initialParameters: chronologyParameters)
                .environment(appState)
                // #338 step 2: a sheet doesn't reliably inherit `\.sceneID` (review Finding 1), so
                // publish it explicitly so ChronologyView's Word Cloud button targets THIS window.
                .environment(\.sceneID, sceneID)
        }
        // Search → Analytics handoff (a capped search offered to "Visualize in Corpus Analytics")
        // and the cross-view → Chronology handoff. Captured into local state before presenting, then
        // cleared on AppState so the observer doesn't refire on the next sheet dismissal.
        // #338 step 3: consume the hand-off only when it is addressed to THIS window's scene, so a
        // word cloud's / search's Analyze or Chronology hand-off no longer fans its sheet out to
        // every open iPad window. `consumeHandoff` re-reads, target-checks, and clears in one step.
        .onChange(of: appState.pendingAnalytics) { _, _ in
            guard let sceneID,
                  let params = appState.consumeHandoff(\.pendingAnalytics, for: sceneID) else { return }
            analyticsParameters = params
            showAnalytics = true
        }
        .onChange(of: appState.pendingChronology) { _, _ in
            guard let sceneID,
                  let params = appState.consumeHandoff(\.pendingChronology, for: sceneID) else { return }
            chronologyParameters = params
            showChronology = true
        }
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
        }
        // #324: under FRUS_UI_TEST_MODE the browse stack can render before AppState
        // finishes booting the download manager, so the view model would capture nil
        // for the session and report every volume as not-downloaded. Back-fill it the
        // moment the manager appears (a no-op in production, where it exists at boot).
        .onChange(of: appState.downloadManager == nil) { _, isNil in
            if !isNil { viewModel?.attachDownloadManagerIfNeeded(appState.downloadManager) }
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
                    appState.openWordCloud(.corpus, from: sceneID)
                } label: {
                    Label { Text(String(localized: "browse.wordcloud.a11y", defaultValue: "Corpus Word Cloud")) }
                        icon: { Image(systemName: WordCloudGlyph.symbol) }
                }
            } label: {
                Image(systemName: "chart.bar.xaxis")
            }
            .controlHelp(
                String(localized: "browse.analysisTools.a11y", defaultValue: "Analysis Tools"),
                detail: String(localized: "browse.analysisTools.help",
                               defaultValue: "Chronology, Corpus Analytics, Person Analytics, Cross-Reference Analytics, and the corpus Word Cloud"),
                systemImage: "chart.bar.xaxis"
            )
        }
    }

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
                            Image(systemName: appState.filterDownloadedOnly
                                  ? "arrow.down.circle.fill"
                                  : "arrow.down.circle")
                        }
                        .accessibilityLabel(
                            appState.filterDownloadedOnly
                                ? String(localized: "browser.filter.off.a11y",
                                         defaultValue: "Show all volumes")
                                : String(localized: "browser.filter.on.a11y",
                                         defaultValue: "Show downloaded volumes only")
                        )
                        .help(
                            appState.filterDownloadedOnly
                                ? String(localized: "browser.filter.off.help",
                                         defaultValue: "Show all volumes in the corpus, including those not yet downloaded")
                                : String(localized: "browser.filter.on.help",
                                         defaultValue: "Show only volumes you have downloaded and can browse offline")
                        )
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
                            Image(systemName: appState.filterDownloadedOnly
                                  ? "arrow.down.circle.fill"
                                  : "arrow.down.circle")
                        }
                        .accessibilityLabel(
                            appState.filterDownloadedOnly
                                ? String(localized: "browser.filter.off.a11y",
                                         defaultValue: "Show all volumes")
                                : String(localized: "browser.filter.on.a11y",
                                         defaultValue: "Show downloaded volumes only")
                        )
                        .help(
                            appState.filterDownloadedOnly
                                ? String(localized: "browser.filter.off.help",
                                         defaultValue: "Show all volumes in the corpus, including those not yet downloaded")
                                : String(localized: "browser.filter.on.help",
                                         defaultValue: "Show only volumes you have downloaded and can browse offline")
                        )
                    }
                    analyticsToolbarItems
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
    @ViewBuilder
    private func levelView(for level: BrowserViewModel.BrowserLevel, vm: BrowserViewModel) -> some View {
        Group {
            switch level {
            case .corpus:            CorpusView(vm: vm)
            case .subseries(let g):  SubseriesView(vm: vm, group: g)
            case .volume(let e):     VolumeView(vm: vm, volume: e)
            case .compilation(let vid, let s): CompilationView(vm: vm, volumeId: vid, section: s)
            case .document(let e):   DocumentView(entry: e)
            case .people:            PersonIndexView()
            }
        }
        // #377 Phase 5 follow-up: keep the "Working on:" research-question subtitle visible at every
        // pushed Browse depth on regular-width iPad (each level sets its own navigationTitle; this
        // pairs the subtitle to it). The corpus root is rendered directly in `stackLayout`, so it
        // carries its own `.workingOnSubtitle()`; no level view sets a subtitle of its own to clobber.
        .workingOnSubtitle()
        .safeAreaInset(edge: .top, spacing: 0) {
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
                "Subseries \(group.subseries), \(group.totalVolumes) volumes"
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
            Text("\(group.totalVolumes) volumes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#endif // os(iOS)
