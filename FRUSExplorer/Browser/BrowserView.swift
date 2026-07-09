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
struct BrowserView: View {

    @Environment(AppState.self) private var appState
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
                if sizeClass == .regular {
                    splitLayout(vm: vm)
                } else {
                    stackLayout(vm: vm)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard let entry else { return }
            viewModel?.navigationPath.append(.document(entry))
            appState.pendingBrowseDocument = nil
            #if DEBUG
            print("[BrowserView] pendingBrowseDocument consumed: \(entry.volumeId)/\(entry.documentId)")
            #endif
        }
        // Volume-grain sibling of the observer above (UI audit gap 12): Cross-Volume
        // Provenance rows hand off a volume id; push its browser level and clear.
        .onChange(of: appState.pendingBrowseVolume) { _, volumeId in
            guard let volumeId, let vm = viewModel else { return }
            appState.pendingBrowseVolume = nil
            guard let entry = vm.allSubseriesGroups
                .flatMap(\.volumes)
                .first(where: { $0.volumeId == volumeId }) else { return }
            vm.navigationPath.append(.volume(entry))
            #if DEBUG
            print("[BrowserView] pendingBrowseVolume consumed: \(volumeId)")
            #endif
        }
        .onChange(of: appState.filterDownloadedOnly) { _, flag in
            viewModel?.filterDownloadedOnly = flag
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView(initialParameters: analyticsParameters)
                .environment(appState)
        }
        .sheet(isPresented: $showPersonAnalytics) {
            PersonAnalyticsView()
                .environment(appState)
        }
        .sheet(isPresented: $showCrossRefAnalytics) {
            CrossReferenceAnalyticsView()
                .environment(appState)
        }
        .sheet(isPresented: $showChronology) {
            ChronologyView(initialParameters: chronologyParameters)
                .environment(appState)
        }
        // Search → Analytics handoff (a capped search offered to "Visualize in Corpus Analytics")
        // and the cross-view → Chronology handoff. Captured into local state before presenting, then
        // cleared on AppState so the observer doesn't refire on the next sheet dismissal.
        .onChange(of: appState.pendingAnalytics) { _, params in
            guard let params else { return }
            analyticsParameters = params
            appState.pendingAnalytics = nil
            showAnalytics = true
        }
        .onChange(of: appState.pendingChronology) { _, params in
            guard let params else { return }
            chronologyParameters = params
            appState.pendingChronology = nil
            showChronology = true
        }
        .onAppear { bootstrapViewModel() }
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
                    appState.pendingWordCloud = .corpus
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
                            appState.activeTab = .research
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
                            appState.activeTab = .research
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
    ///  - **Regular width / iPad (#238):** under the iPadOS floating top tab bar (the collapsed
    ///    `.sidebarAdaptable` representation) a pinned top inset is drawn beneath the tab bar and
    ///    cannot be scrolled into view. The tab sidebar and the navigation back button convey
    ///    location on iPad, so the bar is dropped entirely at `sizeClass == .regular`.
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
        .safeAreaInset(edge: .top, spacing: 0) {
            // Breadcrumb suppression (see doc comment above):
            //  - Regular width / iPad (#238): a pinned `.safeAreaInset` breadcrumb is
            //    occluded by the iPadOS floating top tab bar (`.sidebarAdaptable`) and cannot
            //    be scrolled into view. The tab sidebar and the navigation back button convey
            //    location instead. Rendering `EmptyView` (rather than hiding a laid-out bar)
            //    keeps the crumbs out of the accessibility tree too — no hidden-but-focusable
            //    chrome for VoiceOver / keyboard users.
            //  - Document level (any width, Session 121): the wrapped multi-row path blocks
            //    the document header.
            if sizeClass == .regular {
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
