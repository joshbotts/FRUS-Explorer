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
/// Version history:
///   1.0 — Session 11: initial implementation
struct BrowserView: View {

    @Environment(AppState.self) private var appState
    @State private var viewModel: BrowserViewModel?
    @State private var showProjectContext = false
    @State private var showSearch = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
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
        .sheet(isPresented: $showSearch) {
            if let service = appState.searchService {
                SearchView(
                    searchService: service,
                    subjectTagStore: appState.subjectTagStore
                )
            }
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
                }
        }
    }

    // MARK: - Level Router

    @ViewBuilder
    private func levelView(for level: BrowserViewModel.BrowserLevel, vm: BrowserViewModel) -> some View {
        switch level {
        case .corpus:
            CorpusView(vm: vm)
        case .subseries(let group):
            SubseriesView(vm: vm, group: group)
        case .volume(let entry):
            VolumeView(vm: vm, volume: entry)
        case .compilation(let volumeId, let section):
            CompilationView(vm: vm, volumeId: volumeId, section: section)
        case .document(let entry):
            DocumentView(entry: entry)
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
