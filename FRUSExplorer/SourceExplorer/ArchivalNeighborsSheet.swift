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

// MARK: - NeighborScope

/// The volume breadth an Archival Neighbors query runs against (#217).
///
/// A neighbors surface with an anchor volume (a document, or a volume front-matter
/// source) offers all three scopes; a cross-volume surface (a collection or
/// decimal-class record, which has no single home volume) offers only `.allIndexed`.
/// The scope is resolved to a `volumeId` set the query filters on — see
/// `IndexingPipeline.applyScope(_:scopeVolumeIds:limit:)` — so the same archival key
/// returns the same in-scope neighbors on every trigger surface.
///
/// `Codable`/`Hashable` so it can ride inside a restored macOS neighbors window's
/// request payload and key the content view's reload `.task`.
enum NeighborScope: Codable, Hashable, Sendable {
    /// Every indexed volume (cross-corpus). The default for document, collection, and
    /// decimal-class surfaces — the cross-corpus reach is the value of neighbors.
    case allIndexed
    /// Only the anchor's own volume. The default for a volume front-matter source.
    case volume(String)
    /// Every volume in the anchor's subseries (`VolumeManifestEntry.subseries`, e.g.
    /// `"1969-76"`); `anchorVolumeId` seeds both the picker label and the manifest
    /// member-set lookup.
    case subseries(key: String, anchorVolumeId: String)
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
    /// so the case stays `Codable`; `load(appState:)` reconstructs it. `anchorVolumeId`
    /// is the source entry's own volume, which seeds the "This volume" default scope (#217).
    case volumeSource(lotFile: String?, recordGroup: String?, series: String?,
                      repository: String?, decimalClass: String?,
                      aliasLotFileNorm: String?, aliasNames: [String],
                      anchorVolumeId: String?)
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
            aliasNames:       target.aliasFallback?.names ?? [],
            anchorVolumeId:   target.volumeId
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
        guard case .volumeSource(_, _, _, _, _, let aliasLot, let aliasNames, _) = self else {
            return nil
        }
        guard aliasLot != nil || !aliasNames.isEmpty else { return nil }
        return .init(lotFileNorm: aliasLot, names: aliasNames)
    }

    /// The request's anchor volume, when it has one — a document's own volume or a
    /// front-matter source entry's volume. `nil` for the inherently cross-volume
    /// collection and decimal-class shapes. Seeds the scope picker's "This volume" /
    /// "This subseries" options (#217).
    var anchorVolumeId: String? {
        switch self {
        case .document(let volumeId, _, _):
            return volumeId
        case .volumeSource(_, _, _, _, _, _, _, let anchor):
            return anchor
        case .collection, .decimalClass:
            return nil
        }
    }

    /// The per-trigger default scope (#217): a volume front-matter source opens scoped
    /// to its own volume (the researcher is reading that volume's provenance); every
    /// other surface opens cross-corpus, where the neighbor reach is the point.
    var defaultScope: NeighborScope {
        switch self {
        case .volumeSource:
            return anchorVolumeId.map { .volume($0) } ?? .allIndexed
        case .document, .collection, .decimalClass:
            return .allIndexed
        }
    }

    /// Runs the query this request describes against the live index. Every shape
    /// resolves through `appState.indexingPipeline`, which is exactly what lets the
    /// macOS window scene reconstruct the fetch from the restored value.
    @MainActor
    func load(appState: AppState, scopeVolumeIds: Set<String>? = nil) async -> ArchivalNeighborsResult {
        guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
        switch self {
        case .document(let volumeId, let documentId, let documentYear):
            return (try? await pipeline.archivalNeighbors(
                forVolumeId:  volumeId,
                documentId:   documentId,
                documentYear: documentYear,
                scopeVolumeIds: scopeVolumeIds
            )) ?? ([], 0, nil)
        case .volumeSource(let lotFile, let recordGroup, let series,
                           let repository, let decimalClass, _, _, _):
            return (try? await pipeline.archivalNeighbors(
                forLotFile:    lotFile,
                recordGroup:   recordGroup,
                series:        series,
                repository:    repository,
                decimalClass:  decimalClass,
                aliasFallback: reconstructedAliasFallback,
                scopeVolumeIds: scopeVolumeIds
            )) ?? ([], 0, nil)
        case .collection(let lotFileNorm, let repository, let recordGroup, let names):
            return (try? await pipeline.collectionNeighbors(
                lotFileNorm: lotFileNorm,
                repository:  repository,
                recordGroup: recordGroup,
                names:       names,
                scopeVolumeIds: scopeVolumeIds
            )) ?? ([], 0, nil)
        case .decimalClass(let cls):
            return (try? await pipeline.archivalNeighbors(
                forLotFile: nil, recordGroup: nil, series: nil,
                repository: nil, decimalClass: cls,
                scopeVolumeIds: scopeVolumeIds
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
/// Row taps navigate to the neighbor — on macOS via `AppState.openDocument`, routed to
/// the presenting window's provenance host (`originRequest`); on iOS via the
/// `pendingBrowseDocument` hand-off the Browse tab consumes — and then invoke
/// `onNavigate`: the sheet passes `dismiss`, the window passes nothing so the list
/// stays open beside the reading window.
struct ArchivalNeighborsContent: View {

    /// Shared app state, used to navigate to a tapped neighbor and to resolve a
    /// subseries scope's member volumes from the manifest.
    let appState: AppState
    /// Loads the neighbors for a resolved scope (`nil` = all indexed volumes) — the
    /// actor-isolated query, re-run whenever the scope picker changes (#217).
    let load: (Set<String>?) async -> ArchivalNeighborsResult
    /// The scope the view opens at (per-trigger default #217); also the value the
    /// picker resets toward.
    let defaultScope: NeighborScope
    /// The anchor volume, when the surface has one — enables the "This volume" / "This
    /// subseries" scope options. `nil` on cross-volume surfaces (collection / decimal
    /// class), which show no picker and always query the whole index.
    let anchorVolumeId: String?
    /// Invoked after a row tap posts its navigation hand-off. Sheets dismiss here;
    /// the macOS window intentionally stays open (browsable alongside the document).
    var onNavigate: (() -> Void)? = nil
    /// Reports the loaded result upward — the sheet shows `basis` under its title,
    /// the macOS window shows it as the window subtitle.
    var onLoaded: ((ArchivalNeighborsResult) -> Void)? = nil
    /// The value-based window request this content is presented under, when it IS the
    /// Archival Neighbors window (`ArchivalNeighborsWindowView` passes its own request).
    /// Row taps route through `.tool(.archivalNeighbors(originRequest))` so the open lands
    /// in the window's provenance host; `nil` in the iOS sheet presentations, which
    /// navigate via `pendingBrowseDocument` instead.
    var originRequest: ArchivalNeighborsRequest? = nil

    #if os(macOS)
    /// Mint tail for `AppState.openDocument` — when no document host is live, a row tap
    /// lands in a fresh standalone document window instead of being dropped.
    @Environment(\.openWindow) private var openWindow
    #endif

    /// #338 step 4: the scene this sheet renders in on iOS, so a row tap's open-document hand-off
    /// addresses the presenting window. Injected at each of the sheet's presentation sites; nil on
    /// macOS (the row tap routes through `openDocument`).
    @Environment(\.sceneID) private var sceneID

    @State private var docs: [IndexingPipeline.RelatedDocument] = []
    @State private var totalCount = 0
    @State private var isLoading = true
    /// The currently selected scope, seeded from `defaultScope`.
    @State private var scope: NeighborScope
    /// The scope whose result is currently shown. Guards the load task against
    /// duplicate runs for the *same* scope: `.task(id:)` sits above a branch-swapping
    /// `Group` (the documented Group gotcha; see `VolumeSourcesView.didLoad`), so a
    /// branch swap can re-fire it — this absorbs that while still reloading on a real
    /// scope change. `nil` until the first load completes.
    @State private var lastLoadedScope: NeighborScope?

    /// Designated initializer — seeds the `@State` scope from the per-trigger default.
    init(appState: AppState,
         defaultScope: NeighborScope = .allIndexed,
         anchorVolumeId: String? = nil,
         load: @escaping (Set<String>?) async -> ArchivalNeighborsResult,
         onNavigate: (() -> Void)? = nil,
         onLoaded: ((ArchivalNeighborsResult) -> Void)? = nil,
         originRequest: ArchivalNeighborsRequest? = nil) {
        self.appState = appState
        self.defaultScope = defaultScope
        self.anchorVolumeId = anchorVolumeId
        self.load = load
        self.onNavigate = onNavigate
        self.onLoaded = onLoaded
        self.originRequest = originRequest
        _scope = State(initialValue: defaultScope)
    }

    /// Whether the live index exists to query. `false` during app boot — a restored
    /// macOS Archival Neighbors window's `.task` typically fires before
    /// `bootDownloadManager()` assigns `appState.indexingPipeline`, and querying then
    /// would render the definitive "No Archival Neighbors" verdict as a lie. Reading
    /// the `@Observable` property in `body` (via the `.task(id:)` value) re-evaluates
    /// the view and re-fires the task when the pipeline becomes available.
    private var pipelineReady: Bool { appState.indexingPipeline != nil }

    var body: some View {
        VStack(spacing: 0) {
            scopePicker
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
                        description: Text(emptyDetail)
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
        }
        // Keyed on pipeline availability **and the selected scope**: a window restored
        // before boot re-runs once the pipeline is assigned, and switching scope re-runs
        // the query. The `lastLoadedScope` guard absorbs the Group-modifier replication
        // (branch swaps re-fire the task) so a given scope loads exactly once.
        .task(id: reloadKey) {
            guard pipelineReady, lastLoadedScope != scope else { return }
            lastLoadedScope = scope
            isLoading = true
            let result = await load(resolvedScopeVolumeIds(scope))
            docs       = result.documents
            totalCount = result.totalCount
            isLoading  = false
            onLoaded?(result)
        }
    }

    /// Reload identity: the query re-runs when the pipeline becomes ready or the scope
    /// changes. A `String` because `.task(id:)` needs a stable `Hashable`.
    private var reloadKey: String {
        let scopeKey: String
        switch scope {
        case .allIndexed:            scopeKey = "all"
        case .volume(let v):         scopeKey = "vol:\(v)"
        case .subseries(let k, _):   scopeKey = "sub:\(k)"
        }
        return "\(pipelineReady)|\(scopeKey)"
    }

    /// The empty-state detail, scope-aware so "nothing in this volume" doesn't read as
    /// "nothing anywhere" (#217) — a scoped empty invites widening to all volumes.
    private var emptyDetail: String {
        switch scope {
        case .allIndexed:
            return String(localized: "archivalNeighbors.empty.detail",
                defaultValue: "No documents in your indexed volumes cite this archival source — indexing more volumes may surface some.")
        case .volume, .subseries:
            return String(localized: "archivalNeighbors.empty.detail.scoped",
                defaultValue: "No documents in this scope cite this archival source — switch to All volumes to search the whole index.")
        }
    }

    // MARK: Scope (#217)

    /// The scopes offered for this surface, most-specific first: this volume, this
    /// subseries (only when it has more than one indexed-corpus member), all volumes.
    /// Cross-volume surfaces (no `anchorVolumeId`) offer only "all" — so no picker.
    private var availableScopes: [NeighborScope] {
        guard let anchorVolumeId else { return [.allIndexed] }
        var scopes: [NeighborScope] = [.volume(anchorVolumeId)]
        if let key = anchorSubseriesKey, subseriesMembers(key).count > 1 {
            scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId))
        }
        scopes.append(.allIndexed)
        return scopes
    }

    /// The anchor volume's non-empty subseries key, or `nil`.
    private var anchorSubseriesKey: String? {
        guard let anchorVolumeId,
              let key = appState.manifestStore.entry(forVolumeId: anchorVolumeId)?.subseries,
              !key.isEmpty else { return nil }
        return key
    }

    /// The known volumes sharing a subseries key (the "all known" list, matching the
    /// app-wide `diffResult?.known ?? bundledEntries` pattern).
    private func subseriesMembers(_ key: String) -> [String] {
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return all.filter { $0.subseries == key }.map(\.volumeId)
    }

    /// Resolves a scope to the `volumeId` set the query filters on (`nil` = all indexed).
    private func resolvedScopeVolumeIds(_ scope: NeighborScope) -> Set<String>? {
        switch scope {
        case .allIndexed:
            return nil
        case .volume(let v):
            return [v]
        case .subseries(let key, _):
            let members = subseriesMembers(key)
            return members.isEmpty ? nil : Set(members)
        }
    }

    /// The scope segmented control — shown only when the surface offers more than one
    /// scope (i.e. it has an anchor volume).
    @ViewBuilder
    private var scopePicker: some View {
        if availableScopes.count > 1 {
            Picker(selection: $scope) {
                ForEach(availableScopes, id: \.self) { option in
                    Text(scopeLabel(option)).tag(option)
                }
            } label: {
                Text(String(localized: "archivalNeighbors.scope.label", defaultValue: "Scope"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
    }

    /// The short segmented-control label for a scope.
    private func scopeLabel(_ scope: NeighborScope) -> String {
        switch scope {
        case .allIndexed:
            return String(localized: "archivalNeighbors.scope.all", defaultValue: "All volumes")
        case .volume:
            return String(localized: "archivalNeighbors.scope.volume", defaultValue: "This volume")
        case .subseries:
            return String(localized: "archivalNeighbors.scope.subseries", defaultValue: "This subseries")
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

    /// Navigates to the tapped neighbor (Browse tab on iOS; this window's provenance host
    /// on macOS, via `AppState.openDocument(_:from: .tool(.archivalNeighbors(request)))` —
    /// `.global` when no window request identifies this presentation).
    private func open(_ doc: IndexingPipeline.RelatedDocument) {
        let entry = DocumentBrowserEntry(
            documentId: doc.documentId,
            volumeId:   doc.volumeId,
            header:     doc.header.isEmpty ? doc.documentId : doc.header
        )
        #if os(macOS)
        let source: DocumentOpenSource =
            originRequest.map { .tool(.archivalNeighbors($0)) } ?? .global
        appState.openDocument(entry, from: source, using: openWindow)
        #else
        appState.openBrowseDocument(entry, from: sceneID)
        appState.pendingTab = .browse
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
    /// Loads the neighbors for a resolved scope (`nil` = all indexed) — the
    /// actor-isolated query, re-run on scope change (#217).
    let load: (Set<String>?) async -> ArchivalNeighborsResult
    /// The scope the sheet opens at (per-trigger default #217).
    let defaultScope: NeighborScope
    /// The anchor volume, when the surface has one (enables the scope picker).
    let anchorVolumeId: String?

    @Environment(\.dismiss) private var dismiss
    /// The loaded archival basis, shown under the title (reported by the content core).
    @State private var basis: String? = nil

    /// Designated initializer — caller supplies the scope-parameterized loader and,
    /// when the surface has an anchor volume, the default scope + anchor for the picker.
    init(appState: AppState,
         defaultScope: NeighborScope = .allIndexed,
         anchorVolumeId: String? = nil,
         load: @escaping (Set<String>?) async -> ArchivalNeighborsResult) {
        self.appState = appState
        self.defaultScope = defaultScope
        self.anchorVolumeId = anchorVolumeId
        self.load = load
    }

    /// Convenience for document-keyed surfaces: loads neighbors by the document's key
    /// via `IndexingPipeline.archivalNeighbors`. Defaults to all-indexed scope with the
    /// document's own volume as the picker anchor.
    init(appState: AppState, docKey: ArchivalNeighborsDocKey) {
        self.appState = appState
        self.defaultScope = .allIndexed
        self.anchorVolumeId = docKey.volumeId
        self.load = { scopeVolumeIds in
            guard let pipeline = appState.indexingPipeline else { return ([], 0, nil) }
            return (try? await pipeline.archivalNeighbors(
                forVolumeId:  docKey.volumeId,
                documentId:   docKey.documentId,
                documentYear: docKey.documentYear,
                scopeVolumeIds: scopeVolumeIds
            )) ?? ([], 0, nil)
        }
    }

    var body: some View {
        NavigationStack {
            ArchivalNeighborsContent(
                appState: appState,
                defaultScope: defaultScope,
                anchorVolumeId: anchorVolumeId,
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

// MARK: - ArchivalNeighborsWindowView

/// Content for the **Archival Neighbors window** — macOS since Source Explorer Phase 5
/// (owner decision S6), and iPad with Stage Manager since #241: the shared
/// `ArchivalNeighborsContent` under window chrome, the title naming the surface and the
/// subtitle naming the archival basis once loaded.
///
/// A window, not a sheet, because the result is a work list: researchers step
/// through cross-volume neighbors one by one, and a sheet dies on the first
/// navigation (the UI audit's B1). Here a row tap hands the document to the main
/// window (`pendingBrowseDocument`, the established cross-window hand-off) and this
/// window **stays open** beside it. That argument was never macOS-specific — it is why
/// #241 chose this scene as the first iPad window port.
///
/// ## Platform chrome
/// macOS takes the window's own title bar, so the content renders bare with a min frame.
/// iPad has no title bar: the content needs a `NavigationStack` to render
/// `.navigationTitle`/`.navigationSubtitle` in a nav bar (the same wrapper the
/// `DocumentWindowID` iOS scene applies), and window sizing belongs to the scene's
/// `.defaultSize`, not to a min frame that would fight Stage Manager's resizing.
/// `.navigationSubtitle` is iOS 26.0+ — verified against the iPhoneOS 26.5 SDK
/// swiftinterface, and the app's deployment target clears it — so the chrome needs no
/// per-platform fork beyond the container.
///
/// Version history:
///   1.0 — Session 2026-07-04 (Source Explorer Phase 5 S6): initial implementation
///   1.1 — Session 2026-07-04 (Phase 5 adversarial-review fixes): windows restored at
///          relaunch no longer race app boot — the shared content core now waits on
///          `appState.indexingPipeline` (placeholder + `.task(id:)` re-fire) instead
///          of rendering a false, permanent "No Archival Neighbors" verdict.
///   1.2 — #241 Session R: lifted out of `#if os(macOS)` — the same view now backs the
///          iPad Stage-Manager window scene. iOS wraps it in a `NavigationStack` for
///          nav-bar chrome; the macOS min frame stays macOS-only.
struct ArchivalNeighborsWindowView: View {

    /// The restorable query description this window presents.
    let request: ArchivalNeighborsRequest

    @Environment(AppState.self) private var appState
    /// The loaded archival basis, shown as the window subtitle.
    @State private var basis: String? = nil

    var body: some View {
        #if os(iOS)
        // iPad windows have no title bar of their own — the nav bar is the chrome.
        NavigationStack { neighborsContent }
        #else
        neighborsContent
        #endif
    }

    /// The shared content core under its title/subtitle chrome, container-agnostic.
    private var neighborsContent: some View {
        ArchivalNeighborsContent(
            appState: appState,
            defaultScope: request.defaultScope,
            anchorVolumeId: request.anchorVolumeId,
            load: { scopeVolumeIds in
                await request.load(appState: appState, scopeVolumeIds: scopeVolumeIds)
            },
            onNavigate: nil,   // the window stays open — that is the point of S6
            onLoaded: { basis = $0.basis },
            originRequest: request   // row taps route to this window's provenance host
        )
        .navigationTitle(String(localized: "archivalNeighbors.title",
                                defaultValue: "Archival Neighbors"))
        .navigationSubtitle(basis ?? "")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 380)
        #endif
    }
}
