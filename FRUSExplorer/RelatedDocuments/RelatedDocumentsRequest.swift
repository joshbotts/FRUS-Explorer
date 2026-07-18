// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NeighborScope volume resolution

extension NeighborScope {

    /// Resolves this scope to the `volumeId` set a find-related query filters on (`nil` = all
    /// indexed volumes). Mirrors `ArchivalNeighborsContent`'s per-surface scope resolution: a
    /// subseries scope expands to its known member volumes (the app-wide
    /// `diffResult?.known ?? bundledEntries` set), collapsing to `nil` when it has none.
    @MainActor
    func resolveVolumeIds(appState: AppState) -> Set<String>? {
        switch self {
        case .allIndexed:
            return nil
        case .volume(let volumeId):
            return [volumeId]
        case .subseries(let key, _):
            let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
            let members = entries.filter { $0.subseries == key }.map(\.volumeId)
            return members.isEmpty ? nil : Set(members)
        }
    }
}

// MARK: - RelatedDocumentsRequest

/// A **value-typed, restorable description** of one find-related query — the hand-off payload for
/// the macOS find-related window scene (`WindowGroup(for: RelatedDocumentsRequest.self)`), mirroring
/// `ArchivalNeighborsRequest` (design §6.3).
///
/// It carries the anchor, its coverage year, the user's per-axis weight vector, the volume scope, and
/// the row limit — everything `RelatedDocumentsEngine` needs — so the query reconstructs **from the
/// value alone** and a restored macOS window recovers the *exact tuning* the user had. `Codable` lets
/// SwiftUI persist and restore it; `Hashable` identity is the full payload, so `openWindow(value:)`
/// focuses an equal window and opens a new one for a distinct query, exactly like the archival
/// neighbours window.
///
/// The live in-window re-tuning (dragging a weight slider) is view `@State` seeded from `weights`; the
/// request value is the initial/restored tuning, not a per-keystroke identity — so tweaking a slider
/// re-ranks in place rather than spawning a window.
///
/// **#357 (decided: accept):** because `weights` is part of the identity, re-opening Related Documents
/// for the same anchor *after* changing the persisted default tuning opens a second window rather than
/// refocusing the first. This is intentional — a distinct tuning is a distinct query, and having two
/// tunings of the same document side by side is a feature, not a bug. (Windows are cheap; revisit only
/// if it annoys in practice.)
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
struct RelatedDocumentsRequest: Codable, Hashable, Sendable {

    /// The seed document.
    let anchor: DocumentKey
    /// The seed's coverage year, if known — threaded to date-sensitive generators.
    let anchorYear: Int?
    /// The user's per-axis weights (the restored tuning).
    var weights: AxisWeights
    /// The volume breadth to search.
    var scope: NeighborScope
    /// Maximum rows to return.
    var limit: Int

    /// The default row limit — the archival-neighbours default, kept consistent across the two
    /// related-document surfaces.
    static let defaultLimit = 30

    /// Creates a request. `weights` defaults to the shared out-of-the-box tuning and `scope` to all
    /// indexed volumes (the cross-corpus reach is the point of "related documents").
    init(anchor: DocumentKey, anchorYear: Int? = nil,
                weights: AxisWeights = .default, scope: NeighborScope = .allIndexed,
                limit: Int = RelatedDocumentsRequest.defaultLimit) {
        self.anchor = anchor
        self.anchorYear = anchorYear
        self.weights = weights
        self.scope = scope
        self.limit = limit
    }

    /// The anchor's own volume — seeds the scope picker's "This volume" / "This subseries" options.
    var anchorVolumeId: String { anchor.volumeId }

    /// Runs the query this request describes against the live index, resolving `scope` to a volume
    /// set and delegating to `RelatedDocumentsEngine`. Every input rides the value, which is what lets
    /// the macOS window scene reconstruct the fetch from the restored request.
    @MainActor
    func load(appState: AppState) async -> RelatedDocumentsResult {
        await RelatedDocumentsEngine.rank(
            anchor: anchor,
            anchorYear: anchorYear,
            weights: weights,
            scopeVolumeIds: scope.resolveVolumeIds(appState: appState),
            limit: limit,
            appState: appState)
    }
}
