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
///     showing corpus-wide cross-volume edges. The stage holds the graph's view model and the
///     window is titled from its centre (#1500), below.
///   - *Browse Documents* → lists all documents in the volume (via
///     `IndexingPipeline.documents(forVolume:)`); tapping one sets
///     `AppState.currentGraphEntry` which transitions to Targeted mode.
///
/// ## "View Document" interaction
/// `CrossReferenceGraphView` calls `AppState.openDocument(_:from: .tool(.graph))` on macOS
/// to open a document in this graph window's provenance host rather than pushing inline.
///
/// ## Volume hand-off (UI audit B6)
/// `AppState.pendingVolumeGraph` — the volume-grain sibling of `currentGraphEntry`,
/// set by the Corpus Browser's per-volume graph buttons before `openWindow(id:)` —
/// is consumed here (`.task` for a freshly created window, `.onChange` for one
/// already open): targeted mode is cleared and the picker jumps straight to its
/// volume-connections stage. The picker's Back button then works as usual, so the
/// hand-off lands in the same navigation model the standalone window uses.
///
/// ## The Volume Connections stage's title (#1500)
/// The graph navigates by itself: Explore connections in its panel and its Back move the view
/// model's `centralVolumeId` and nothing else. The view model used to be the graph view's own
/// `@State`, so the window went on titling the stage with the volume it OPENED on while the discs
/// and the panel's "N references into/from …" lines belonged to another. The stage now holds the
/// view model (`PickerStage.volumeGraph`), hands it to `VolumeConnectionGraphView(vm:)`, and titles
/// the stage through `VolumeConnectionGraphViewModel.centreTitle(in:)`, so Explore and Back move
/// the title. Both ways onto the stage — the mode choice and the hand-off — make a fresh view
/// model through `volumeGraphStage(_:)`, and the graph view is keyed on it, so a hand-off to a
/// window already showing a volume graph draws the volume it names. On `v2` it did not, by
/// reading: the new volume id kept the stage in the same case, so the graph view kept its identity
/// and its `@State` view model, and its unkeyed `.task` did not run again — the old graph under the
/// new volume's title.
///
/// Version history:
///   1.0 — Initial implementation (replaces two-line placeholder in SupportingViews.swift)
///   1.1 — Session 75: two-stage volume/document picker replaces the "No Document Selected"
///          placeholder; `VolumeConnectionGraphView` reachable from the picker without
///          requiring a prior document-level navigation
///   1.2 — Session 2026-07-04 (macOS UI audit B6): consumes the `pendingVolumeGraph`
///          hand-off, replacing the Corpus Browser's `VolumeConnectionGraphView` sheet
///   1.3 — #1391: the document picker's rows draw `DocumentHeaderDisplay.numberedRow`, so a head
///          that prints its own number no longer reads "256. 256. …"
///   1.4 — #1500: the Volume Connections stage holds the graph's view model and is titled from its
///          centre, so Explore connections and Back move the title; every way onto the stage makes
///          a fresh view model (`volumeGraphStage(_:)`)
struct CrossReferenceGraphWindowView: View {

    /// The document this window was opened for, when it was opened with one (UI review M-2).
    ///
    /// **Additive by design.** `nil` reproduces the previous behaviour exactly — read
    /// `appState.currentGraphEntry`, and fall back to the picker when that is nil too — so the
    /// cold Window-menu path and its picker are preserved by construction rather than by care.
    /// A non-nil request makes this window's subject *its own*, which is the whole of M-2: two
    /// documents' graphs can be open at once because neither is reading a process-global slot.
    ///
    /// The type already existed and already ships value-based on iPad (#317), so this is the
    /// macOS half of a port rather than a new shape.
    var request: GraphWindowRequest? = nil

    @Environment(AppState.self) private var appState

    // MARK: - Picker state

    private enum PickerStage {
        /// Stage 1: user has not yet chosen a volume.
        case selectVolume
        /// Stage 2: user chose a volume; waiting for mode choice.
        case modeChoice(volumeId: String)
        /// User chose the volume-level connections graph. The stage holds the graph's view model
        /// (#1500): the window is titled from its centre, which the graph's Explore connections and
        /// Back move.
        case volumeGraph(VolumeConnectionGraphViewModel)
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
        Group {
            // The window's OWN subject wins over the shared slot. #749 / M-13 made a live-bound
            // retarget *visible* (open-and-raise) because it could not be prevented while every
            // graph read one global; with a request there is nothing to retarget — a second
            // document opens a second window.
            if let entry = request?.entry ?? appState.currentGraphEntry,
               let store = appState.crossReferenceStore {
                CrossReferenceGraphView(
                    entry: entry,
                    crossReferenceStore: store,
                    indexingPipeline: appState.indexingPipeline,
                    downloadedVolumeIds: downloadedVolumeIds
                )
                // Rebuild (re-querying the reopened store) when the focus changes OR after an
                // in-session reindex settles — otherwise a graph left open across a reindex would
                // read the stale boot connection until relaunch (#275).
                .id("\(entry.id)-\(appState.readOnlyStoresGeneration)")
            } else {
                pickerContent
                    .task { await loadIndexedVolumes() }
            }
        }
        // Consume a volume hand-off (Corpus Browser graph buttons, UI audit B6):
        // `.task` covers a window freshly created by the hand-off (`.onChange`
        // misses a value that was already set), `.onChange` covers one already
        // open — mirroring MacSearchWindowView's pendingSearch pattern. Both call
        // the idempotent consumer, so the Group's per-branch `.task` replication
        // (the documented Group gotcha) is harmless.
        .task { consumePendingVolumeGraph() }
        .onChange(of: appState.pendingVolumeGraph) { _, volumeId in
            guard volumeId != nil else { return }
            consumePendingVolumeGraph()
        }
    }

    /// Applies (and clears) `AppState.pendingVolumeGraph`: leaves targeted mode (the
    /// document-scoped `currentGraphEntry`) and jumps the picker straight to the
    /// volume-connections stage for the handed-off volume.
    private func consumePendingVolumeGraph() {
        guard let volumeId = appState.pendingVolumeGraph else { return }
        appState.pendingVolumeGraph = nil
        appState.currentGraphEntry = nil
        stage = volumeGraphStage(volumeId)
        #if DEBUG
        print("[CrossReferenceGraphWindowView] pendingVolumeGraph consumed: \(volumeId)")
        #endif
    }

    /// A fresh Volume Connections stage centred on `volumeId` (#1500): the mode choice's and the
    /// Corpus Browser hand-off's. A new view model every time, so a hand-off to a window already
    /// showing a volume graph opens the volume it names, and one naming the volume the reader has
    /// explored away from goes back to it.
    /// - Parameter volumeId: The volume at the graph's centre.
    /// - Returns: The stage.
    private func volumeGraphStage(_ volumeId: String) -> PickerStage {
        .volumeGraph(VolumeConnectionGraphViewModel(centralVolumeId: volumeId))
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
                            .help(String(
                                localized: "xref.picker.back.help",
                                defaultValue: "Return to the volume picker"
                            ))
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
        case .modeChoice(let vid), .documentList(let vid, _):
            return allEntries.first(where: { $0.volumeId == vid })?.title ?? vid
        case .volumeGraph(let graph):
            // The volume at the graph's centre now, which Explore connections and Back move —
            // never the volume the stage opened on (#1500).
            return graph.centreTitle(in: allEntries)
        }
    }

    @ViewBuilder
    private var pickerStageView: some View {
        switch stage {
        case .selectVolume:
            volumePickerList

        case .modeChoice(let vid):
            modeChoiceView(volumeId: vid)

        case .volumeGraph(let graph):
            if appState.crossReferenceStore != nil {
                VolumeConnectionGraphView(vm: graph)
                    // A new view model is a new view, whose load runs (#1500).
                    .id(ObjectIdentifier(graph))
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
                            // #312 follow-up: full-row tap target — both modifiers, in this order.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
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
            WrappingFooterSection {
                Button {
                    withAnimation { stage = volumeGraphStage(volumeId) }
                } label: {
                    Label(
                        String(localized: "xref.picker.volumeGraph",
                               defaultValue: "Volume Connections"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                    .padding(.vertical, 4)
                    // #312 follow-up: full-row tap target for this action row.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    String(localized: "xref.picker.volumeGraph.hint",
                           defaultValue: "Shows all cross-references to and from documents in this volume, across the full corpus")
                )
                .help(String(
                    localized: "xref.picker.volumeGraph.help",
                    defaultValue: "Show every cross-reference between this volume and other indexed volumes"
                ))
            } footer: {
                Text(String(localized: "xref.picker.volumeGraph.footer",
                            defaultValue: "Corpus-wide connections for this volume — every other volume it cross-references or is referenced by."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            WrappingFooterSection {
                Button {
                    Task { await loadDocuments(for: volumeId) }
                } label: {
                    Label(
                        String(localized: "xref.picker.browseDocuments",
                               defaultValue: "Browse Documents"),
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .padding(.vertical, 4)
                    // #312 follow-up: full-row tap target for this action row.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    String(localized: "xref.picker.browseDocuments.hint",
                           defaultValue: "Pick a specific document to view its ego-level cross-reference graph")
                )
                .help(String(
                    localized: "xref.picker.browseDocuments.help",
                    defaultValue: "Choose a specific document and see its inbound/outbound references"
                ))
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
                            // #1391: without the split, a head that prints its own number
                            // reads "256. 256. Department of State…".
                            let row = DocumentHeaderDisplay.numberedRow(
                                header: doc.header, number: doc.documentNumber)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    if let num = row.number {
                                        Text("\(num).")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(row.title)
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
                            // #312 follow-up: full-row tap target.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
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
