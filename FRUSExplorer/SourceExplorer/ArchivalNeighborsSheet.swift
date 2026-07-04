// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalNeighborsResult

/// The payload an Archival Neighbors loader returns: the matched neighbor
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

// MARK: - ArchivalNeighborsRequest

/// A **value-typed, restorable description** of one Archival Neighbors query — the
/// hand-off payload for the macOS Archival Neighbors window scene
/// (`WindowGroup(for: ArchivalNeighborsRequest.self)`, Source Explorer Phase 5 S6).
///
/// The neighbors query has four shapes across the app's surfaces, and every one
/// resolves purely through `AppState.indexingPipeline`, so the fetch can be
/// reconstructed **from the value alone** inside the window content — no pending-state
/// hand-off (`appState.currentSourceNote`-style) is needed, and `Codable` conformance
/// lets SwiftUI restore the window (and re-run the local SQLite query, which is cheap)
/// across relaunches.
///
/// Identity is the full payload: `openWindow(value:)` focuses an existing window
/// whose request compares equal and opens a new window otherwise — i.e. one window
/// per *distinct* archival source, browsable side by side.
enum ArchivalNeighborsRequest: Codable, Hashable, Sendable {
    /// Neighbors of an indexed document, keyed by its stored source note
    /// (`IndexingPipeline.archivalNeighbors(forVolumeId:documentId:documentYear:)`).
    case document(volumeId: String, documentId: String, documentYear: Int?)
    /// Neighbors of a volume-level front-matter source entry
    /// (`IndexingPipeline.archivalNeighbors(forLotFile:recordGroup:series:repository:decimalClass:aliasFallback:)`).
    /// The Phase-4 alias fallback is flattened into `aliasLotFileNorm` + `aliasNames`
    /// so the case stays `Codable`; `load(appState:)` reconstructs it.
    case volumeSource(lotFile: String?, recordGroup: String?, series: String?,
                      repository: String?, decimalClass: String?,
                      aliasLotFileNorm: String?, aliasNames: [String])
    /// Record-level neighbors of a bundled collection-authority record
    /// (`IndexingPipeline.collectionNeighbors` — the same OR-union clause as the S5
    /// counts, so the window total equals the "N documents in M volumes" line).
    case collection(lotFileNorm: String?, repository: String?, recordGroup: String?,
                    names: [String])
    /// Neighbors of one decimal / subject-numeric class leaf (a collection record's
    /// class-keyed sub-series).
    case decimalClass(String)

    /// Builds a document-keyed request from the sheet-item key used by iOS surfaces.
    init(docKey: ArchivalNeighborsDocKey) {
        self = .document(volumeId: docKey.volumeId,
                         documentId: docKey.documentId,
                         documentYear: docKey.documentYear)
    }

    /// Builds a volume-source request from a row's neighbors target, flattening the
    /// attached alias fallback (if any) into the Codable payload.
    init(volumeSource target: VolumeSourceNeighborsTarget) {
        self = .volumeSource(
            lotFile:          target.lotFile,
            recordGroup:      target.recordGroup,
            series:           target.series,
            repository:       target.repository,
            decimalClass:     target.decimalClass,
            aliasLotFileNorm: target.aliasFallback?.lotFileNorm,
            aliasNames:       target.aliasFallback?.names ?? []
        )
    }

    /// Builds a record-level request from a bundled collection-authority record
    /// (canonical name first, then the merged alias forms — the order
    /// `collectionNeighbors` documents).
    init(collectionRecord record: AuthorityCollectionRecord) {
        self = .collection(lotFileNorm: record.lotFileNorm,
                           repository:  record.repository,
                           recordGroup: record.recordGroup,
                           names:       [record.name] + record.aliases)
    }

    /// The alias fallback reconstructed from a `.volumeSource` payload, or `nil` for
    /// the other cases and when the flattened fields are empty (a fallback with no lot
    /// key and no name forms can never match — semantically "no fallback attached").
    /// Factored out of `load(appState:)` so the round-trip is unit-testable.
    var reconstructedAliasFallback: IndexingPipeline.CollectionAliasFallback? {
        guard case .volumeSource(_, _, _, _, _, let aliasLot, let aliasNames) = self else {
            return nil
        }
        guard aliasLot != nil || !aliasNames.isEmpty else { return nil }
        return .init(lotFileNorm: aliasLot, names: aliasNames)
    }

    /// Runs the query this request describes against the live index. Every shape
    /// resolves through `appState.indexingPipeline`, which is exactly what lets the
    /// macOS window scene reconstruct the fetch from the restored value.
    @MainActor
    func load(appState: AppState) async -> ArchivalNeighborsResult {
        guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
        switch self {
        case .document(let volumeId, let documentId, let documentYear):
            return (try? await pipeline.archivalNeighbors(
                forVolumeId:  volumeId,
                documentId:   documentId,
                documentYear: documentYear
            )) ?? ([], 0, nil)
        case .volumeSource(let lotFile, let recordGroup, let series,
                           let repository, let decimalClass, _, _):
            return (try? await pipeline.archivalNeighbors(
                forLotFile:    lotFile,
                recordGroup:   recordGroup,
                series:        series,
                repository:    repository,
                decimalClass:  decimalClass,
                aliasFallback: reconstructedAliasFallback
            )) ?? ([], 0, nil)
        case .collection(let lotFileNorm, let repository, let recordGroup, let names):
            return (try? await pipeline.collectionNeighbors(
                lotFileNorm: lotFileNorm,
                repository:  repository,
                recordGroup: recordGroup,
                names:       names
            )) ?? ([], 0, nil)
        case .decimalClass(let cls):
            return (try? await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil,
                repository: nil, decimalClass: cls
            )) ?? ([], 0, nil)
        }
    }
}

// MARK: - ArchivalNeighborsContent

/// The shared **core** of every Archival Neighbors presentation: loading state, the
/// honest empty state, the neighbor list with its overflow row, and row-tap
/// navigation. Chrome stays with the callers — `ArchivalNeighborsSheet` wraps it in
/// a `NavigationStack` with a Done button (iOS sheets), and the macOS
/// `ArchivalNeighborsWindowView` shows it bare under a window title/subtitle
/// (Source Explorer Phase 5 S6).
///
/// Row taps post the neighbor to `AppState.pendingBrowseDocument` (the established
/// cross-window hand-off — `MainWindowView` consumes it on macOS, the Browse tab on
/// iOS) and then invoke `onNavigate`: the sheet passes `dismiss`, the window passes
/// nothing so the list stays open beside the reading window.
struct ArchivalNeighborsContent: View {

    /// Shared app state, used to navigate to a tapped neighbor.
    let appState: AppState
    /// Loads the neighbors when the view appears (runs the actor-isolated query).
    let load: () async -> ArchivalNeighborsResult
    /// Invoked after a row tap posts its navigation hand-off. Sheets dismiss here;
    /// the macOS window intentionally stays open (browsable alongside the document).
    var onNavigate: (() -> Void)? = nil
    /// Reports the loaded result upward — the sheet shows `basis` under its title,
    /// the macOS window shows it as the window subtitle.
    var onLoaded: ((ArchivalNeighborsResult) -> Void)? = nil

    @State private var docs: [IndexingPipeline.RelatedDocument] = []
    @State private var totalCount = 0
    @State private var isLoading = true
    /// Guards the load task against duplicate runs. The body is a `Group`, and SwiftUI
    /// applies `Group` modifiers to each child — so `.task` fires again when the loading
    /// branch swaps to the loaded one (the codebase's documented Group gotcha; see
    /// `VolumeSourcesView.didLoad`). Without the guard every open ran the full neighbors
    /// query twice, including the alias fallback's expensive non-indexed scans.
    @State private var didLoad = false

    /// Whether the live index exists to query. `false` during app boot — a restored
    /// macOS Archival Neighbors window's `.task` typically fires before
    /// `bootDownloadManager()` assigns `appState.indexingPipeline`, and querying then
    /// would render the definitive "No Archival Neighbors" verdict as a lie. Reading
    /// the `@Observable` property in `body` (via the `.task(id:)` value) re-evaluates
    /// the view and re-fires the task when the pipeline becomes available.
    private var pipelineReady: Bool { appState.indexingPipeline != nil }

    var body: some View {
        Group {
            if !pipelineReady {
                // Pipeline not created yet (app still booting): show a preparing
                // placeholder, never the honest-empty verdict — that state is reserved
                // for a real zero-row query result against the live index.
                ProgressView(String(localized: "archivalNeighbors.preparingIndex",
                                    defaultValue: "Preparing your index…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if docs.isEmpty {
                ContentUnavailableView(
                    String(localized: "archivalNeighbors.empty",
                           defaultValue: "No Archival Neighbors"),
                    systemImage: "archivebox",
                    description: Text(String(localized: "archivalNeighbors.empty.detail",
                        defaultValue: "No documents in your indexed volumes cite this archival source — indexing more volumes may surface some."))
                )
            } else {
                List {
                    // Keyed by the composite volume/document pair: neighbors span
                    // volumes and FRUS document ids are volume-local ("d12" recurs
                    // in most volumes), so documentId alone collides.
                    ForEach(docs, id: \.compositeKey) { doc in
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
        // Keyed on pipeline availability so a window restored (or opened) before boot
        // finishes re-runs the load once `appState.indexingPipeline` is assigned; the
        // `didLoad` guard absorbs the Group-modifier replication (branch swaps re-fire
        // the task) so the query itself runs exactly once.
        .task(id: pipelineReady) {
            guard pipelineReady, !didLoad else { return }
            didLoad = true
            let result = await load()
            docs       = result.documents
            totalCount = result.totalCount
            isLoading  = false
            onLoaded?(result)
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

    /// Navigates to the tapped neighbor (Browse tab on iOS; the main browser window
    /// on macOS, via the `pendingBrowseDocument` hand-off `MainWindowView` consumes).
    private func open(_ doc: IndexingPipeline.RelatedDocument) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: doc.documentId,
            volumeId:   doc.volumeId,
            header:     doc.header.isEmpty ? doc.documentId : doc.header
        )
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        onNavigate?()
    }
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
///   1.1 — Session 2026-07-04 (Source Explorer Phase 5 step 1): honest empty state.
///          For keyed rows the "no results" state can no longer mean "we failed to
///          parse it" (Phases 1–3 killed that); the wording now says exactly what an
///          empty result means — nothing in *your indexed volumes* cites the source —
///          and matches the zero-count hint on the three-state row affordance. The
///          list may also exceed a row's count badge: the badge counts direct keys
///          only, while this sheet's loader can add the Phase-4 alias fallback.
///   1.2 — Session 2026-07-04 (Source Explorer Phase 5 S6): list/empty/row/navigation
///          core extracted into the shared `ArchivalNeighborsContent`, which this
///          sheet wraps with `NavigationStack` + Done chrome. On macOS every neighbors
///          surface now opens the `ArchivalNeighborsRequest` window instead of this
///          sheet, so the sheet is presented by the iOS surfaces only.
///   1.3 — Session 2026-07-04 (Phase 5 adversarial-review fixes): the shared content
///          core (a) shows a "Preparing your index…" placeholder — never the
///          honest-empty verdict — while `appState.indexingPipeline` is nil, and
///          re-runs the load when it appears (`.task(id:)` on pipeline readiness):
///          a restored macOS neighbors window races app boot and previously showed
///          a false, permanent "No Archival Neighbors"; (b) guards the load with
///          `didLoad` — the `.task` sits on a branch-swapping `Group`, so per the
///          documented Group gotcha every query ran twice.
struct ArchivalNeighborsSheet: View {

    /// Shared app state, used to navigate to a tapped neighbor.
    let appState: AppState
    /// Loads the neighbors when the sheet appears (runs the actor-isolated query).
    let load: () async -> ArchivalNeighborsResult

    @Environment(\.dismiss) private var dismiss
    /// The loaded archival basis, shown under the title (reported by the content core).
    @State private var basis: String? = nil

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
            ArchivalNeighborsContent(
                appState: appState,
                load: load,
                onNavigate: { dismiss() },
                onLoaded: { basis = $0.basis }
            )
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
    }
}

#if os(macOS)

// MARK: - ArchivalNeighborsWindowView

/// Content for the macOS **Archival Neighbors window** (Source Explorer Phase 5,
/// owner decision S6): the shared `ArchivalNeighborsContent` under window chrome —
/// the title names the surface, the subtitle names the archival basis once loaded.
///
/// A window, not a sheet, because the result is a work list: researchers step
/// through cross-volume neighbors one by one, and a sheet dies on the first
/// navigation (the UI audit's B1). Here a row tap hands the document to the main
/// window (`pendingBrowseDocument`, the established cross-window hand-off) and this
/// window **stays open** beside it.
///
/// Version history:
///   1.0 — Session 2026-07-04 (Source Explorer Phase 5 S6): initial implementation
///   1.1 — Session 2026-07-04 (Phase 5 adversarial-review fixes): windows restored at
///          relaunch no longer race app boot — the shared content core now waits on
///          `appState.indexingPipeline` (placeholder + `.task(id:)` re-fire) instead
///          of rendering a false, permanent "No Archival Neighbors" verdict.
struct ArchivalNeighborsWindowView: View {

    /// The restorable query description this window presents.
    let request: ArchivalNeighborsRequest

    @Environment(AppState.self) private var appState
    /// The loaded archival basis, shown as the window subtitle.
    @State private var basis: String? = nil

    var body: some View {
        ArchivalNeighborsContent(
            appState: appState,
            load: { await request.load(appState: appState) },
            onNavigate: nil,   // the window stays open — that is the point of S6
            onLoaded: { basis = $0.basis }
        )
        .navigationTitle(String(localized: "archivalNeighbors.title",
                                defaultValue: "Archival Neighbors"))
        .navigationSubtitle(basis ?? "")
        .frame(minWidth: 460, minHeight: 380)
    }
}

#endif // os(macOS)
