// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

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
struct BrowserView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: BrowserViewModel?
    @State private var pendingSearchParams: SearchParameters? = nil
    // On macOS: showProjectContext drives the ProjectContext sheet.
    // On iOS: tapping ProjectPickerMenu switches to the Activity tab instead.
    #if os(macOS)
    @State private var showProjectContext = false
    @State private var showCollections = false
    #endif
    // showSearch and showCitationLookup live in AppState (promoted in Session 43)
    // so that macOS menu commands and future iOS tab navigation can trigger them.
    // On macOS, showSettingsSheet/pendingOnboardingAfterReset remain in AppState for
    // the sheet-based Settings flow (converted to a Settings scene in Session 46).

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        @Bindable var appState = appState
        Group {
            if let vm = viewModel {
                #if os(macOS)
                splitLayout(vm: vm)
                #else
                if sizeClass == .regular {
                    splitLayout(vm: vm)
                } else {
                    stackLayout(vm: vm)
                }
                #endif
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showProjectContext) {
            ProjectContextView()
        }
        .sheet(isPresented: $showCollections) {
            CollectionListView()
                .frame(minWidth: 480, minHeight: 560)
        }
        .sheet(isPresented: $appState.showSearch) {
            if let service = appState.searchService {
                SearchView(
                    searchService: service,
                    subjectTagStore: appState.subjectTagStore,
                    initialParameters: pendingSearchParams
                )
            }
        }
        .onChange(of: appState.pendingSearch) { _, params in
            guard let params else { return }
            pendingSearchParams = params
            appState.pendingSearch = nil
            appState.showSearch = true
        }
        .sheet(isPresented: $appState.showCitationLookup) {
            CitationLookupView()
        }
        #endif
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard let entry else { return }
            viewModel?.navigationPath.append(.document(entry))
            appState.pendingBrowseDocument = nil
            #if DEBUG
            print("[BrowserView] pendingBrowseDocument consumed: \(entry.volumeId)/\(entry.documentId)")
            #endif
        }
        .onAppear { bootstrapViewModel() }
    }

    // MARK: - Layout Variants

    @ViewBuilder
    private func splitLayout(vm: BrowserViewModel) -> some View {
        NavigationSplitView {
            SubseriesListView(vm: vm)
                .navigationTitle(String(localized: "browser.title", defaultValue: "FRUS Explorer"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu {
                            #if os(iOS)
                            appState.activeTab = .activity
                            #else
                            showProjectContext = true
                            #endif
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.search.a11y",
                                   defaultValue: "Search documents")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.showCitationLookup = true
                        } label: {
                            Image(systemName: "text.magnifyingglass")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.citationLookup.a11y",
                                   defaultValue: "Find by citation")
                        )
                    }
                    #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCollections = true
                        } label: {
                            Image(systemName: "tray.2")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.collections.a11y",
                                   defaultValue: "Open Collections")
                        )
                    }
                    #endif
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
                    // Only the ProjectPickerMenu remains in the Browse toolbar.
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu {
                            #if os(iOS)
                            appState.activeTab = .activity
                            #else
                            showProjectContext = true
                            #endif
                        }
                    }
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
    @ViewBuilder
    private func levelView(for level: BrowserViewModel.BrowserLevel, vm: BrowserViewModel) -> some View {
        Group {
            switch level {
            case .corpus:            CorpusView(vm: vm)
            case .subseries(let g):  SubseriesView(vm: vm, group: g)
            case .volume(let e):     VolumeView(vm: vm, volume: e)
            case .compilation(let vid, let s): CompilationView(vm: vm, volumeId: vid, section: s)
            case .document(let e):   DocumentView(entry: e)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BrowserBreadcrumbBar(path: vm.navigationPath) { index in
                if let index {
                    vm.navigationPath = Array(vm.navigationPath.prefix(index + 1))
                } else {
                    vm.navigationPath = []
                }
            }
        }
    }

    // MARK: - Bootstrap

    private func bootstrapViewModel() {
        guard viewModel == nil else { return }
        viewModel = BrowserViewModel(
            manifestStore: appState.manifestStore,
            tagStore: appState.volumeLevelTagStore,
            downloadManager: appState.downloadManager,
            indexingPipeline: appState.indexingPipeline
        )
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
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
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
