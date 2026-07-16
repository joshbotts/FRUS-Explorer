// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AxisWeights @AppStorage support

/// Persists the weight vector as a compact `axis:weight,…` string so it can back an `@AppStorage`
/// default — the user's preferred tuning, remembered across find-related invocations.
///
/// The encoding is **manual on purpose**: `AxisWeights` is also `Codable`, and a `RawRepresentable`
/// whose `rawValue` routed through `JSONEncoder().encode(self)` recurses (the value's own `Codable`
/// re-enters `rawValue`). Encoding each `axis.rawValue:weight` pair directly avoids the type's
/// `Codable` entirely. An unknown axis token or bad number is skipped; an empty result is `nil`, so a
/// malformed stored value falls back to `.default` at the read site.
extension AxisWeights: RawRepresentable {
    init?(rawValue: String) {
        var parsed: [SimilarityAxis: Double] = [:]
        for pair in rawValue.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let axis = SimilarityAxis(rawValue: String(parts[0])),
                  let weight = Double(parts[1]) else { continue }
            parsed[axis] = weight
        }
        guard !parsed.isEmpty else { return nil }
        self.init(weights: parsed)
    }

    var rawValue: String {
        // Sorted by axis rawValue for a stable, deterministic string.
        SimilarityAxis.allCases
            .sorted { $0.rawValue < $1.rawValue }
            .map { "\($0.rawValue):\(self[$0])" }
            .joined(separator: ",")
    }
}

// MARK: - RelatedDocumentsContent

/// The shared **core** of every find-related presentation: the tuning bar (scope + per-axis weight
/// sliders), the pipeline-readiness / loading / honest-empty states, the ranked list with its
/// overflow hint, and row-tap navigation. Chrome stays with the callers — `RelatedDocumentsSheet`
/// wraps it in a `NavigationStack` with a Done button (iOS), and `RelatedDocumentsWindowView` shows
/// it under window title chrome (macOS + iPad Stage Manager). Mirrors `ArchivalNeighborsContent`
/// (design §6.3): the pipeline-ready placeholder + `.task(id:)` duplicate-fire guard are copied
/// verbatim because the same restore-races-boot race applies.
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsContent: View {

    /// Shared app state — resolves the scope, runs the ranking, and receives the row-tap hand-off.
    let appState: AppState
    /// The restorable query this view opened at (anchor + initial weights + scope + limit).
    let request: RelatedDocumentsRequest
    /// Invoked after a row tap posts its navigation hand-off. The sheet passes `dismiss`; the window
    /// passes `nil` so the list stays open beside the reading window (the value of a work list).
    var onNavigate: (() -> Void)? = nil

    /// The user's persisted default tuning, updated whenever a slider settles so the *next* fresh
    /// open inherits it. The live per-view tuning is `@State` (seeded from `request.weights`), so a
    /// restored macOS window keeps its own tuning independent of this global default.
    @AppStorage("frus.related.weights") private var persistedWeights = AxisWeights.default

    @State private var weights: AxisWeights
    @State private var scope: NeighborScope
    @State private var rows: [RelatedDocumentRow] = []
    @State private var totalBeforeLimit = 0
    @State private var isLoading = true
    /// Bumped when a weight slider settles, to re-fire the load without putting the continuously
    /// changing weight values directly in the `.task` id (which would re-rank on every drag tick).
    @State private var weightReloadToken = 0
    /// Guards the load task against the documented Group-modifier duplicate fire (a branch swap
    /// re-fires `.task(id:)`); `nil` until the first load completes.
    @State private var lastLoadedKey: String?

    /// Designated initializer — seeds the live tuning + scope from the request.
    init(appState: AppState, request: RelatedDocumentsRequest, onNavigate: (() -> Void)? = nil) {
        self.appState = appState
        self.request = request
        self.onNavigate = onNavigate
        _weights = State(initialValue: request.weights)
        _scope = State(initialValue: request.scope)
    }

    /// Whether the live index exists to query — `false` during app boot. Reading the `@Observable`
    /// property re-evaluates the view (and re-fires the load) when the pipeline becomes available, so
    /// a restored window never renders the honest-empty verdict as a lie.
    private var pipelineReady: Bool { appState.indexingPipeline != nil }

    var body: some View {
        VStack(spacing: 0) {
            tuningBar
            Divider()
            Group {
                if !pipelineReady {
                    ProgressView(String(localized: "related.preparingIndex",
                                        defaultValue: "Preparing your index…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rows.isEmpty {
                    ContentUnavailableView(
                        String(localized: "related.empty", defaultValue: "No Related Documents"),
                        systemImage: "doc.on.doc",
                        description: Text(emptyDetail))
                } else {
                    List {
                        ForEach(rows) { row in
                            Button { open(row) } label: { rowLabel(row) }
                                .buttonStyle(.plain)
                        }
                        if totalBeforeLimit > rows.count {
                            Text(String(
                                format: String(localized: "related.overflow %lld",
                                               defaultValue: "%lld more related — raise a weight or narrow the scope to refine."),
                                Int64(totalBeforeLimit - rows.count)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .task(id: reloadKey) {
            guard pipelineReady, lastLoadedKey != reloadKey else { return }
            lastLoadedKey = reloadKey
            isLoading = true
            let result = await RelatedDocumentsEngine.rank(
                anchor: request.anchor,
                anchorYear: request.anchorYear,
                weights: weights,
                scopeVolumeIds: scope.resolveVolumeIds(appState: appState),
                limit: request.limit,
                appState: appState)
            rows = result.rows
            totalBeforeLimit = result.totalBeforeLimit
            isLoading = false
        }
    }

    /// Reload identity: re-runs when the pipeline becomes ready, the scope changes, or a weight
    /// slider settles (via `weightReloadToken`).
    private var reloadKey: String {
        let scopeKey: String
        switch scope {
        case .allIndexed:          scopeKey = "all"
        case .volume(let v):       scopeKey = "vol:\(v)"
        case .subseries(let k, _): scopeKey = "sub:\(k)"
        }
        return "\(pipelineReady)|\(scopeKey)|\(weightReloadToken)"
    }

    /// The empty-state detail, scope-aware so a scoped empty invites widening.
    private var emptyDetail: String {
        switch scope {
        case .allIndexed:
            return String(localized: "related.empty.detail",
                defaultValue: "No indexed documents share this document's archival provenance or cross-references — indexing more volumes may surface some.")
        case .volume, .subseries:
            return String(localized: "related.empty.detail.scoped",
                defaultValue: "No related documents in this scope — switch to All volumes to search the whole index.")
        }
    }

    // MARK: Tuning

    /// The scope picker (when the anchor has a volume) plus a collapsible per-axis weight panel.
    @ViewBuilder
    private var tuningBar: some View {
        VStack(spacing: 8) {
            if availableScopes.count > 1 {
                Picker(selection: $scope) {
                    ForEach(availableScopes, id: \.self) { option in
                        Text(scopeLabel(option)).tag(option)
                    }
                } label: {
                    Text(String(localized: "related.scope.label", defaultValue: "Scope"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            DisclosureGroup(String(localized: "related.weights.label", defaultValue: "Adjust weights")) {
                VStack(spacing: 6) {
                    ForEach(SimilarityAxis.allCases) { axis in
                        weightRow(axis)
                    }
                }
                .padding(.top, 4)
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// One axis's weight slider, with the shared-subjects axis disabled + annotated while its data is
    /// gated (design Q4 — the detected-topic axis ships opt-in and inert until Phase 3).
    @ViewBuilder
    private func weightRow(_ axis: SimilarityAxis) -> some View {
        let subjectsInert = axis == .sharedSubjects && DocumentSubjectStore.shared == nil
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Label(axis.displayName, systemImage: axis.systemImage)
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text(weights[axis], format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { weights[axis] },
                    set: { weights[axis] = $0; persistedWeights = weights }),
                in: 0...1,
                onEditingChanged: { editing in if !editing { weightReloadToken += 1 } })
            .disabled(subjectsInert)
            if subjectsInert {
                Text(String(localized: "related.weights.subjects.gated",
                            defaultValue: "Available when detected-topic data ships (experimental)."))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    /// The scopes offered: this volume, this subseries (when it has more than one known member), all
    /// volumes. The anchor always has a volume, so the picker always offers at least volume + all.
    private var availableScopes: [NeighborScope] {
        let anchorVolumeId = request.anchorVolumeId
        var scopes: [NeighborScope] = [.volume(anchorVolumeId)]
        if let key = anchorSubseriesKey, subseriesMemberCount(key) > 1 {
            scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId))
        }
        scopes.append(.allIndexed)
        return scopes
    }

    /// The anchor volume's non-empty subseries key, or `nil`.
    private var anchorSubseriesKey: String? {
        guard let key = appState.manifestStore.entry(forVolumeId: request.anchorVolumeId)?.subseries,
              !key.isEmpty else { return nil }
        return key
    }

    /// How many known volumes share a subseries key.
    private func subseriesMemberCount(_ key: String) -> Int {
        let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return entries.filter { $0.subseries == key }.count
    }

    /// The short segmented-control label for a scope.
    private func scopeLabel(_ scope: NeighborScope) -> String {
        switch scope {
        case .allIndexed: return String(localized: "related.scope.all", defaultValue: "All volumes")
        case .volume:     return String(localized: "related.scope.volume", defaultValue: "This volume")
        case .subseries:  return String(localized: "related.scope.subseries", defaultValue: "This subseries")
        }
    }

    // MARK: Rows

    /// One related-document row: header, volume + dateline, and "why related" axis chips.
    @ViewBuilder
    private func rowLabel(_ row: RelatedDocumentRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.record.header.isEmpty ? row.documentId : row.record.header)
                .font(.body).lineLimit(2)
            HStack(spacing: 6) {
                Text(row.volumeId).font(.caption).foregroundStyle(.secondary)
                if let dateline = row.record.dateline, !dateline.isEmpty {
                    Text(verbatim: "·").font(.caption).foregroundStyle(.tertiary)
                    Text(dateline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            whyRelated(row)
        }
        .padding(.vertical, 2)
    }

    /// Small icon chips naming the axes that contributed to this row, strongest first — the
    /// "why related" affordance.
    @ViewBuilder
    private func whyRelated(_ row: RelatedDocumentRow) -> some View {
        let axes = row.axisScores.sorted { $0.value > $1.value }.map(\.key)
        if !axes.isEmpty {
            HStack(spacing: 5) {
                ForEach(axes) { axis in
                    Image(systemName: axis.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel(axis.displayName)
                }
            }
        }
    }

    /// Navigates to the tapped document (Browse tab on iOS; the main browser window on macOS via the
    /// `pendingBrowseDocument` hand-off), then invokes `onNavigate` (dismiss for the sheet, nothing
    /// for the window).
    private func open(_ row: RelatedDocumentRow) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            header: row.record.header.isEmpty ? row.documentId : row.record.header)
        #if os(iOS)
        appState.pendingTab = .browse
        #endif
        onNavigate?()
    }
}

// MARK: - RelatedDocumentsSheet

/// The iOS sheet presentation of find-related — the shared content core wrapped in a
/// `NavigationStack` with a Done button. Presented where windows are unavailable (iPhone, iPads
/// without Stage Manager); where they exist, callers open `RelatedDocumentsWindowView` instead.
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsSheet: View {

    /// Shared app state.
    let appState: AppState
    /// The query to present.
    let request: RelatedDocumentsRequest

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RelatedDocumentsContent(appState: appState, request: request, onNavigate: { dismiss() })
                .navigationTitle(String(localized: "related.title", defaultValue: "Related Documents"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }
}

// MARK: - RelatedDocumentsWindowView

/// The macOS (and iPad Stage Manager) window presentation of find-related: the shared content core
/// under window chrome. A window, not a sheet, because the ranked list is a work list the researcher
/// steps through — a row tap hands the document to the main window and this window stays open beside
/// it, exactly like the Archival Neighbors window (design §6.3, the C2/#317 value-based pattern).
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsWindowView: View {

    /// The restorable query this window presents.
    let request: RelatedDocumentsRequest

    @Environment(AppState.self) private var appState

    var body: some View {
        #if os(iOS)
        NavigationStack { content }
        #else
        content
        #endif
    }

    /// The shared content core under its title chrome, container-agnostic. The window stays open on a
    /// row tap (`onNavigate: nil`).
    private var content: some View {
        RelatedDocumentsContent(appState: appState, request: request, onNavigate: nil)
            .navigationTitle(String(localized: "related.title", defaultValue: "Related Documents"))
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 420)
            #endif
    }
}
