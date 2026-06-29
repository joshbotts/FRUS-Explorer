// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalNeighborsResult

/// The payload an `ArchivalNeighborsSheet` loader returns: the matched neighbor
/// documents, the total match count (which may exceed the returned slice), and a
/// human-readable archival basis (e.g. "Lot 64 D 199") or `nil` when none applies.
typealias ArchivalNeighborsResult = (
    documents: [IndexingPipeline.RelatedDocument],
    totalCount: Int,
    basis: String?
)

// MARK: - ArchivalNeighborsDocKey

/// Identifiable document key for presenting `ArchivalNeighborsSheet` from any
/// document-keyed surface (graph node, search result, browser row) via `.sheet(item:)`.
/// `documentYear` feeds the decimal-file chronological segmenting in the neighbor query.
struct ArchivalNeighborsDocKey: Identifiable, Equatable {
    let volumeId: String
    let documentId: String
    let documentYear: Int?
    var id: String { "\(volumeId)/\(documentId)" }
}

// MARK: - ArchivalNeighborsSheet

/// A sheet listing a document's (or a volume source's) **archival neighbors** — other
/// indexed FRUS documents drawn from the same original archival provenance: lot file,
/// central decimal file, record-group series, or presidential-library collection
/// (`IndexingPipeline.relatedDocuments(for:)`).
///
/// Reusable across surfaces: the caller supplies an async `load` closure (keyed by a
/// document, or by a volume-level source entry), so one sheet serves the cross-reference
/// graph, search results, browser document lists, and the volume sources list. All
/// returned neighbors are already indexed, so each row navigates straight to the document.
///
/// Version history:
///   1.0 — Session 166: archival-neighbors rollout (generalises the former lot-file sheet)
struct ArchivalNeighborsSheet: View {

    /// Shared app state, used to navigate to a tapped neighbor.
    let appState: AppState
    /// Loads the neighbors when the sheet appears (runs the actor-isolated query).
    let load: () async -> ArchivalNeighborsResult

    @Environment(\.dismiss) private var dismiss
    @State private var docs: [IndexingPipeline.RelatedDocument] = []
    @State private var totalCount = 0
    @State private var basis: String? = nil
    @State private var isLoading = true

    /// Designated initializer — caller supplies the loader.
    init(appState: AppState, load: @escaping () async -> ArchivalNeighborsResult) {
        self.appState = appState
        self.load = load
    }

    /// Convenience for document-keyed surfaces: loads neighbors by the document's key
    /// via `IndexingPipeline.archivalNeighbors`.
    init(appState: AppState, docKey: ArchivalNeighborsDocKey) {
        self.appState = appState
        self.load = {
            guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
            return (try? await pipeline.archivalNeighbors(
                forVolumeId:  docKey.volumeId,
                documentId:   docKey.documentId,
                documentYear: docKey.documentYear
            )) ?? ([], 0, nil)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if docs.isEmpty {
                    ContentUnavailableView(
                        String(localized: "archivalNeighbors.empty",
                               defaultValue: "No Archival Neighbors"),
                        systemImage: "archivebox",
                        description: Text(String(localized: "archivalNeighbors.empty.detail",
                            defaultValue: "No other indexed FRUS documents share this archival source. Downloading and indexing more volumes will surface more neighbors."))
                    )
                } else {
                    List {
                        ForEach(docs, id: \.documentId) { doc in
                            Button { open(doc) } label: { row(doc) }
                                .buttonStyle(.plain)
                        }
                        if totalCount > docs.count {
                            Text(String(
                                format: String(localized: "archivalNeighbors.overflow %lld",
                                               defaultValue: "%lld more share this source — open Source Explorer to see them all."),
                                Int64(totalCount - docs.count)
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "archivalNeighbors.title",
                                    defaultValue: "Archival Neighbors"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(String(localized: "archivalNeighbors.title",
                                    defaultValue: "Archival Neighbors"))
                            .font(.headline)
                        if let basis {
                            Text(basis).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
        .task {
            let result = await load()
            docs       = result.documents
            totalCount = result.totalCount
            basis      = result.basis
            isLoading  = false
        }
    }

    /// One neighbor row: header (or document id) plus its volume and dateline.
    @ViewBuilder
    private func row(_ doc: IndexingPipeline.RelatedDocument) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(doc.header.isEmpty ? doc.documentId : doc.header)
                .font(.body)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(doc.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let dateline = doc.dateline, !dateline.isEmpty {
                    Text(verbatim: "·").font(.caption).foregroundStyle(.tertiary)
                    Text(dateline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Navigates to the tapped neighbor (Browse tab on iOS; browser window on macOS).
    private func open(_ doc: IndexingPipeline.RelatedDocument) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: doc.documentId,
            volumeId:   doc.volumeId,
            header:     doc.header.isEmpty ? doc.documentId : doc.header
        )
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        dismiss()
    }
}
