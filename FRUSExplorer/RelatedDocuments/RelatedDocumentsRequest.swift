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
///   1.1 — 2026-10-19 (plan of record §6g): the anchor's year is read from the index
///          (``resolvedAnchorYear(pipeline:)``), and a tester's verdict on a semantic row is built
///          here (``semanticFeedback(_:on:pipeline:provenanceDigest:recordedAt:)``)
struct RelatedDocumentsRequest: Codable, Hashable, Sendable {

    /// The seed document.
    let anchor: DocumentKey
    /// The year the door that opened the seed read from its `DocumentBrowserEntry.dateline`, or
    /// `nil` when that entry carried none, as most doors' entries do. Nothing ranks or bands on it
    /// directly: ``resolvedAnchorYear(pipeline:)`` prefers the index's date and falls back to this.
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
        let year = await resolvedAnchorYear(pipeline: appState.indexingPipeline)
        return await RelatedDocumentsEngine.rank(
            anchor: anchor,
            anchorYear: year,
            weights: weights,
            scopeVolumeIds: scope.resolveVolumeIds(appState: appState),
            limit: limit,
            appState: appState)
    }
}

// MARK: - The anchor's year

extension RelatedDocumentsRequest {

    /// The anchor's year as Related Documents uses it, for the ranking and for every verdict a tester
    /// gives on the list: the year of the index's date for the anchor, and only where the index has
    /// none, the year the door read from the dateline (``anchorYear``).
    ///
    /// **The index first, because the doors disagree** (plan of record §6g, found in A8). A door can
    /// pass only the dateline its `DocumentBrowserEntry` carries, and most build theirs without one:
    /// Continue reading, History, a collection, a cross-reference, a link, a Related Documents row.
    /// A verdict given after one of those was recorded with no era and counted under *Undated
    /// anchor*, while the same document opened from Search counted under its era: in the iPhone
    /// simulator on 2026-10-19, `frus1900/d60` (January 25, 1899) gave no era from Continue reading
    /// and `0` from Search. The index's `document_dates` row is the same whichever door was taken,
    /// and it is the date the date-proximity axis already reads for the anchor.
    ///
    /// It is also the better date where both exist. Over a full index (version 65, 316,768
    /// documents, measured 2026-10-19), 17,747 documents (827 of them before 1900) have a date in
    /// the index and a dateline that names no year, and none has a dateline year without a date in
    /// the index. 22 put the two years in different eras, and in 21 of them the dateline is the one
    /// that is wrong: a misprint (`frus1929v02/d1030`, a telegram of September 18, 1929 whose
    /// dateline reads 1829) or a time read as a year (`October 22, 1515Z`). The door's year is kept
    /// as the fallback for an index that cannot answer.
    ///
    /// Read through `IndexingPipeline.documentDates(for:)`, which finds the row by the table's key.
    /// `datesByDocumentKey(_:)` returns the same dictionary but matches on a concatenation of the
    /// two columns, which no index serves: on a full library that is a scan of all 316,768 rows,
    /// 17 ms warm against 0.03 ms by the key (the two statements in `sqlite3` on the M5 Mac,
    /// 2026-10-19), and this runs at every load of the list and every verdict.
    ///
    /// - Parameter pipeline: The live index; `nil` (not open yet) leaves the door's year.
    /// - Returns: The year, or `nil` for an anchor that neither the index nor its dateline dates.
    func resolvedAnchorYear(pipeline: IndexingPipeline?) async -> Int? {
        guard let pipeline else { return anchorYear }
        let dates = (try? await pipeline.documentDates(
            for: [(volumeId: anchor.volumeId, documentId: anchor.documentId)])) ?? [:]
        return Self.anchorYear(indexDate: dates[anchor.compositeString], doorYear: anchorYear)
    }

    /// The rule ``resolvedAnchorYear(pipeline:)`` applies: the year of the index's `date_iso` when
    /// it has one, otherwise the door's year.
    ///
    /// - Parameters:
    ///   - indexDate: The anchor's `document_dates.date_iso` (`yyyy-MM-dd`), if the index has one.
    ///   - doorYear: The year the door read from the dateline, if any.
    /// - Returns: The year Related Documents gives the anchor.
    static func anchorYear(indexDate: String?, doorYear: Int?) -> Int? {
        indexDate.flatMap { Int($0.prefix(4)) } ?? doorYear
    }

    /// A tester's verdict on one semantic row of this request's list, as `SemanticFeedbackLog`
    /// records it: the era is the anchor's ``resolvedAnchorYear(pipeline:)`` in the app's own
    /// `CoverageEra` banding, so the same anchor is banded the same whichever door opened it.
    ///
    /// Built here rather than in `RelatedDocumentsContent`, whose context menu calls it, so a test can
    /// run the verdict a tester's tap records over a real index.
    ///
    /// - Parameters:
    ///   - verdict: The tester's verdict.
    ///   - row: The row being judged.
    ///   - pipeline: The live index the anchor's year is read from.
    ///   - provenanceDigest: The vector generation the row was ranked with.
    ///   - recordedAt: When the tester gave the verdict.
    /// - Returns: The entry to record.
    func semanticFeedback(
        _ verdict: SemanticFeedbackEntry.Verdict, on row: RelatedDocumentRow,
        pipeline: IndexingPipeline?, provenanceDigest: String?, recordedAt: Date
    ) async -> SemanticFeedbackEntry {
        let year = await resolvedAnchorYear(pipeline: pipeline)
        return SemanticFeedbackEntry(
            recordedAt: recordedAt,
            anchor: anchor.compositeString,
            neighbour: row.key.compositeString,
            verdict: verdict,
            cosine: row.axisScores[.semanticSimilarity],
            era: year.map { CoverageEra.bucket(year: $0).rawValue.description },
            sameVolume: row.key.volumeId == anchor.volumeId,
            provenanceDigest: provenanceDigest)
    }
}
