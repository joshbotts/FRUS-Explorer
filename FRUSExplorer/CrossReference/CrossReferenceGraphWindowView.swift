// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - CrossReferenceGraphWindowView

/// Root content for the "Cross-Reference Graph" macOS window scene (`frus.crossReferenceGraph`).
///
/// ## Two operating modes
///
/// **Targeted mode** — When `AppState.currentGraphEntry` is set (the user tapped a graph
/// button in `DocumentView` or the Corpus Browser), the window shows `CrossReferenceGraphView`
/// for that document immediately. `.id(entry.id)` forces SwiftUI to tear down and rebuild the
/// graph when the target document changes while the window is already open.
///
/// **Picker mode** — When `currentGraphEntry` is nil (window opened standalone or after the
/// user clears the selection), a two-stage picker is shown:
///
///   **Stage 1 — Volume**: List of all indexed volumes drawn from `ManifestStore` filtered
///   by `IndexingPipeline.isVolumeIndexed`.
///
///   **Stage 2 — Mode choice**: Two options once a volume is selected:
///   - *Volume Connections* → opens `VolumeConnectionGraphView` pre-selected to that volume,
///     showing corpus-wide cross-volume edges.
///   - *Browse Documents* → lists all documents in the volume (via
///     `IndexingPipeline.documents(forVolume:)`); tapping one sets
///     `AppState.currentGraphEntry` which transitions to Targeted mode.
///
/// ## "View Document" interaction
/// `CrossReferenceGraphView` sets `appState.pendingBrowseDocument` on macOS to open a
/// document in the main FRUS window rather than pushing inline.
///
/// Version history:
///   1.0 — Initial implementation (replaces two-line placeholder in SupportingViews.swift)
///   1.1 — Session 75: two-stage volume/document picker replaces the "No Document Selected"
///          placeholder; `VolumeConnectionGraphView` reachable from the picker without
///          requiring a prior document-level navigation
struct CrossReferenceGraphWindowView: View {

    @Environment(AppState.self) private var appState

    // MARK: - Picker state

    private enum PickerStage {
        /// Stage 1: user has not yet chosen a volume.
        case selectVolume
        /// Stage 2: user chose a volume; waiting for mode choice.
        case modeChoice(volumeId: String)
        /// User chose the volume-level connections graph.
        case volumeGraph(volumeId: String)
        /// User chose to browse documents; document list is loaded.
        case documentList(volumeId: String, documents: [DocumentBrowserEntry])
    }

    @State private var stage: PickerStage = .selectVolume
    @State private var indexedVolumeIds: Set<String> = []

    // MARK: - Stage helpers

    private var isAtVolumePicker: Bool {
        if case .selectVolume = stage { return true }
        return false
    }

    // MARK: - Helpers

    private var allEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    private var indexedEntries: [VolumeManifestEntry] {
        allEntries.filter { indexedVolumeIds.contains($0.volumeId) }.sorted {
            let a = Int(String($0.subseries.prefix(4))) ?? 0
            let b = Int(String($1.subseries.prefix(4))) ?? 0
            return a > b  // newest subseries first
        }
    }

    private var downloadedVolumeIds: Set<String> {
        let entries = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return Set(entries.compactMap { entry -> String? in
            appState.downloadManager?.isVolumeDownloaded(entry.volumeId) == true
                ? entry.volumeId : nil
        })
    }

    // MARK: - Body

    var body: some View {
        if let entry = appState.currentGraphEntry,
           let store = appState.crossReferenceStore {
            CrossReferenceGraphView(
                entry: entry,
                crossReferenceStore: store,
                downloadedVolumeIds: downloadedVolumeIds
            )
            .id(entry.id)
        } else {
            pickerContent
                .task { await loadIndexedVolumes() }
        }
    }

    // MARK: - Picker content

    @ViewBuilder
    private var pickerContent: some View {
        NavigationStack {
            pickerStageView
                .navigationTitle(pickerNavigationTitle)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    if !isAtVolumePicker {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                withAnimation { stage = .selectVolume }
                            } label: {
                                Label(
                                    String(localized: "xref.picker.back",
                                           defaultValue: "Back"),
                                    systemImage: "chevron.left"
                                )
                            }
                        }
                    }
                }
        }
        .frame(minWidth: 480, minHeight: 440)
    }

    private var pickerNavigationTitle: String {
        switch stage {
        case .selectVolume:
            return String(localized: "xref.picker.selectVolume.title",
                          defaultValue: "Select a Volume")
        case .modeChoice(let vid), .volumeGraph(let vid), .documentList(let vid, _):
            return allEntries.first(where: { $0.volumeId == vid })?.title ?? vid
        }
    }

    @ViewBuilder
    private var pickerStageView: some View {
        switch stage {
        case .selectVolume:
            volumePickerList

        case .modeChoice(let vid):
            modeChoiceView(volumeId: vid)

        case .volumeGraph(let vid):
            if let store = appState.crossReferenceStore {
                VolumeConnectionGraphView(initialSelectedVolumeId: vid)
                    .environment(appState)
            } else {
                noStoreView
            }

        case .documentList(_, let docs):
            documentPickerList(docs)
        }
    }

    // MARK: - Stage 1 — Volume list

    private var volumePickerList: some View {
        Group {
            if indexedEntries.isEmpty {
                ContentUnavailableView(
                    String(localized: "xref.picker.noVolumes.title",
                           defaultValue: "No Indexed Volumes"),
                    systemImage: "books.vertical",
                    description: Text(
                        String(localized: "xref.picker.noVolumes.detail",
                               defaultValue: "Download and index at least one volume in the Corpus Browser to use the graph picker.")
                    )
                )
            } else {
                List {
                    ForEach(indexedEntries) { vol in
                        Button {
                            withAnimation { stage = .modeChoice(volumeId: vol.volumeId) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vol.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(vol.volumeId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Stage 2 — Mode choice

    private func modeChoiceView(volumeId: String) -> some View {
        List {
            Section {
                Button {
                    withAnimation { stage = .volumeGraph(volumeId: volumeId) }
                } label: {
                    Label(
                        String(localized: "xref.picker.volumeGraph",
                               defaultValue: "Volume Connections"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    String(localized: "xref.picker.volumeGraph.hint",
                           defaultValue: "Shows all cross-references to and from documents in this volume, across the full corpus")
                )
            } footer: {
                Text(String(localized: "xref.picker.volumeGraph.footer",
                            defaultValue: "Corpus-wide connections for this volume — every other volume it cross-references or is referenced by."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await loadDocuments(for: volumeId) }
                } label: {
                    Label(
                        String(localized: "xref.picker.browseDocuments",
                               defaultValue: "Browse Documents"),
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    String(localized: "xref.picker.browseDocuments.hint",
                           defaultValue: "Pick a specific document to view its ego-level cross-reference graph")
                )
            } footer: {
                Text(String(localized: "xref.picker.browseDocuments.footer",
                            defaultValue: "Choose a specific document to explore its inbound and outbound cross-references."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Stage 2b — Document list

    private func documentPickerList(_ docs: [DocumentBrowserEntry]) -> some View {
        Group {
            if docs.isEmpty {
                ContentUnavailableView(
                    String(localized: "xref.picker.noDocs.title",
                           defaultValue: "No Documents"),
                    systemImage: "doc.text",
                    description: Text(
                        String(localized: "xref.picker.noDocs.detail",
                               defaultValue: "No documents were found for this volume in the index.")
                    )
                )
            } else {
                List {
                    ForEach(docs) { doc in
                        Button {
                            appState.currentGraphEntry = doc
                            // Transitioning to targeted mode is handled by body's if-let above.
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    if let num = doc.documentNumber {
                                        Text("\(num).")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(doc.header)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                }
                                if let dateline = doc.dateline {
                                    Text(dateline)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Error fallback

    private var noStoreView: some View {
        ContentUnavailableView(
            String(localized: "xref.picker.noStore.title",
                   defaultValue: "Graph Unavailable"),
            systemImage: "exclamationmark.triangle",
            description: Text(
                String(localized: "xref.picker.noStore.detail",
                       defaultValue: "The cross-reference database is not available. Try re-indexing a volume.")
            )
        )
    }

    // MARK: - Async loaders

    private func loadIndexedVolumes() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let all = allEntries
        let ids = all.compactMap { entry -> String? in
            (try? pipeline.isVolumeIndexed(entry.volumeId)) == true ? entry.volumeId : nil
        }
        indexedVolumeIds = Set(ids)
    }

    private func loadDocuments(for volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        // `IndexingPipeline` is an actor; hop to it via `await` even though
        // `documents(forVolume:)` is synchronous.
        let docs = (try? await pipeline.documents(forVolume: volumeId)) ?? []
        withAnimation { stage = .documentList(volumeId: volumeId, documents: docs) }
    }
}

#endif // os(macOS)
