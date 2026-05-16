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
struct BrowserView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: BrowserViewModel?
    @State private var showProjectContext = false
    @State private var showSearch = false
    @State private var pendingSearchParams: SearchParameters? = nil
    @State private var showCitationLookup = false
    // Settings sheet visibility is stored in AppState so ResetView can dismiss it
    // programmatically before triggering the transition back to OnboardingView.

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
        .sheet(isPresented: $showProjectContext) {
            ProjectContextView()
        }
        .sheet(isPresented: $appState.showSettingsSheet,
               onDismiss: handleSettingsSheetDismiss) {
            SettingsView()
        }
        #if os(macOS)
        // Fallback for macOS: `.sheet(isPresented:onDismiss:)` does not reliably fire
        // `onDismiss` when `isPresented` is set to `false` programmatically (a known
        // SwiftUI macOS limitation). Watching `showSettingsSheet` directly ensures
        // `handleSettingsSheetDismiss()` runs after a programmatic reset dismissal.
        // The function is idempotent — its `pendingOnboardingAfterReset` guard makes
        // a redundant call from the `onDismiss` path a safe no-op.
        .onChange(of: appState.showSettingsSheet) { _, isShowing in
            if !isShowing {
                handleSettingsSheetDismiss()
            }
        }
        #endif
        .sheet(isPresented: $showSearch) {
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
            showSearch = true
        }
        .sheet(isPresented: $showCitationLookup) {
            CitationLookupView()
        }
        .onAppear { bootstrapViewModel() }
    }

    // MARK: - Sheet Dismiss Coordination

    /// Called by SwiftUI after the Settings sheet has fully animated out.
    ///
    /// If the dismissal was triggered by a completed reset (signalled by
    /// `appState.pendingOnboardingAfterReset`), this is the earliest safe moment
    /// to clear `hasCompletedOnboarding` — the sheet is gone, so `ContentView`
    /// can switch to `OnboardingView` without competing with a live modal.
    private func handleSettingsSheetDismiss() {
        guard appState.pendingOnboardingAfterReset else { return }
        appState.pendingOnboardingAfterReset = false
        appState.hasCompletedOnboarding = false
    }

    // MARK: - Layout Variants

    @ViewBuilder
    private func splitLayout(vm: BrowserViewModel) -> some View {
        NavigationSplitView {
            SubseriesListView(vm: vm)
                .navigationTitle(String(localized: "browser.title", defaultValue: "FRUS Explorer"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu { showProjectContext = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSearch = true
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
                            showCitationLookup = true
                        } label: {
                            Image(systemName: "text.magnifyingglass")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.citationLookup.a11y",
                                   defaultValue: "Find by citation")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.showSettingsSheet = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.settings.a11y",
                                   defaultValue: "Open settings")
                        )
                    }
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
                    ToolbarItem(placement: .primaryAction) {
                        ProjectPickerMenu { showProjectContext = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSearch = true
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
                            showCitationLookup = true
                        } label: {
                            Image(systemName: "text.magnifyingglass")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.citationLookup.a11y",
                                   defaultValue: "Find by citation")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appState.showSettingsSheet = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel(
                            String(localized: "browser.settings.a11y",
                                   defaultValue: "Open settings")
                        )
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
