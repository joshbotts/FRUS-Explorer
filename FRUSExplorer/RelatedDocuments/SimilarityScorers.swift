// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DateProximityScorer

/// Scores candidates by how close their editorial coverage date is to the anchor's, via an
/// exponential `|Δyear|` decay.
///
/// One batched query (`IndexingPipeline.datesByDocumentKey`, 499-chunked) fetches the authoritative
/// `document_dates` for the anchor *and* every candidate at once — never per-candidate SQL. Undated
/// documents (absent from the batch) simply contribute nothing on this axis.
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
struct DateProximityScorer: SimilarityScorer {

    var axis: SimilarityAxis { .dateProximity }

    /// Decay constant (years): `score = exp(-|Δyear| / tau)`. At `tau = 8`, an 8-year gap ≈ 0.37 and
    /// a 16-year gap ≈ 0.14 — close-in-date documents rank high without the axis becoming a hard
    /// cut-off.
    static let tau = 8.0

    /// Creates the scorer.
    init() {}

    func scores(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async throws -> [DocumentKey: Double] {
        guard let pipeline = appState.indexingPipeline, !candidates.isEmpty else { return [:] }
        let keys = ([anchor] + candidates).map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let datesByKey = try await pipeline.datesByDocumentKey(keys)
        guard let anchorISO = datesByKey[anchor.compositeString],
              let anchorYear = year(anchorISO) else { return [:] }
        var scores: [DocumentKey: Double] = [:]
        for candidate in candidates {
            guard let iso = datesByKey[candidate.compositeString], let candidateYear = year(iso) else { continue }
            scores[candidate] = ProximityMath.dateDecay(deltaYears: candidateYear - anchorYear, tau: Self.tau)
        }
        return scores
    }

    /// The four-digit year prefix of an ISO date (`yyyy-MM-dd` → `yyyy`), or `nil`.
    private func year(_ iso: String) -> Int? { Int(iso.prefix(4)) }
}

// MARK: - SubseriesScorer

/// Scores candidates by where the FRUS editors *placed* them — how close together they sit in the
/// volume's own arrangement, and failing that, whether they share a subseries.
///
/// Same volume scores `0.60 + 0.40 × max(containment, print-adjacency)`, so `[0.60, 1.00]`; a
/// different volume in the same `VolumeManifestEntry.subseries` scores `0.50`; anything else is
/// absent. The floor of 0.60 sits above the subseries 0.50, so this axis can never rank a
/// cross-volume candidate above a same-volume one — the change adds discrimination *inside* a
/// volume and reorders nothing across volumes.
///
/// ## Why two terms
/// The two say different things and the stronger one wins (`max`, not a sum — the axis reports the
/// single strongest placement statement the editors made, and `max` also keeps the result ≤ 1
/// without a clamp):
///  - **Containment** (``ProximityMath/narrowing(totalUnits:containerUnits:)``) — "the editors put
///    you both in the same small box". This is the term #562 is about, and on real candidate pools
///    it is the one that governs.
///  - **Print adjacency** (``ProximityMath/printAdjacency(ordinalGap:)``) — "you were printed side
///    by side". Computed over whole-volume reading order, so a pair that is consecutive *across* a
///    section boundary still scores 1.0. That population is small (roughly 2% of adjacent pairs)
///    but it is free, and a within-section rule would structurally miss it.
///
/// A volume with no internal arrangement at all — one section holding hundreds of documents — is
/// exactly the case where containment goes to ~0 and adjacency is the only thing left to say.
///
/// ## Cost
/// Exactly **one** `cachedVolumeStructure` fetch per call, for the anchor's volume, and only when
/// at least one candidate shares it. Every same-volume candidate is by construction in the anchor's
/// volume, and the scorer is invoked once with the whole candidate array — so this must never move
/// inside the loop. The read is a primary-key hit plus a JSON decode on the pipeline actor, off the
/// main thread.
///
/// The subseries lookup goes through `ManifestStore.entry(forVolumeId:)` directly. This used to
/// build a 552-entry `[volumeId: subseries]` map per call to avoid what a stale comment described
/// as a linear scan; the method is an `entryIndex[id]` dictionary hit and has been for some time,
/// so the map was strictly more expensive than the lookups it replaced.
///
/// ## Degradation
/// A same-volume candidate the arrangement cannot place scores exactly `0.60` — never `1.0`, which
/// would silently restore the old flat behaviour and let a volume with a missing structure row
/// outrank a correctly-scored one, and never `0`, which would strip the row's "why related" chip
/// and drop it below the subseries band. `0.60` is also what a genuinely unarranged volume earns on
/// its own merits, so the degraded value states the truth: same volume, no finer evidence.
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
///   1.1 — #562: corpus proximity — the flat same-volume 1.0 becomes a containment/adjacency curve
struct SubseriesScorer: SimilarityScorer {

    var axis: SimilarityAxis { .subseries }

    /// The score for a same-volume candidate carrying no finer evidence — either because the volume
    /// has no internal arrangement, or because its structure could not be read. Above the 0.5
    /// subseries tier by construction.
    /// `nonisolated` because `SimilarityScorer` is `@MainActor`, and these are two immutable
    /// numbers the pure-math tests need to read off the main actor.
    nonisolated static let sameVolumeFloor = 0.60

    /// The span the containment and adjacency terms scale across, `sameVolumeFloor + span == 1`.
    nonisolated static let sameVolumeSpan = 0.40

    /// The same-volume score for one pair, given the anchor volume's flattened arrangement.
    ///
    /// Pure and `nonisolated` so the whole same-volume rule — the composition, the degradation
    /// branch, both terms — is exercisable without a live index. The scorer's own `scores(_:_:_:)`
    /// needs one, so anything left inside it can only be checked by reading the source; keeping
    /// this out here is what lets a test catch a sum where a `max` belongs, or a degraded candidate
    /// quietly restored to 1.0.
    ///
    /// - Parameter arrangement: `nil` when the volume's structure could not be read at all.
    /// - Returns: `[0.60, 1.00]`; exactly ``sameVolumeFloor`` when either document cannot be placed.
    nonisolated static func sameVolumeScore(
        anchorId: String,
        candidateId: String,
        arrangement: VolumeArrangement?
    ) -> Double {
        guard let arrangement,
              let anchorSection = arrangement.section(holding: anchorId),
              let candidateSection = arrangement.section(holding: candidateId)
        else { return sameVolumeFloor }

        let containment = ProximityMath.narrowing(
            totalUnits: arrangement.totalUnits,
            containerUnits: arrangement.containerUnits(anchorSection, candidateSection))

        var adjacency = 0.0
        if let anchorOrdinal = arrangement.ordinal(of: anchorId),
           let candidateOrdinal = arrangement.ordinal(of: candidateId) {
            adjacency = ProximityMath.printAdjacency(ordinalGap: anchorOrdinal - candidateOrdinal)
        }

        // `max`, not a sum: the axis reports the single strongest placement statement the editors
        // made, and taking the maximum of two `[0, 1]` terms stays inside the range with no clamp.
        return sameVolumeFloor + sameVolumeSpan * max(containment, adjacency)
    }

    /// Creates the scorer.
    init() {}

    func scores(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async throws -> [DocumentKey: Double] {
        guard !candidates.isEmpty else { return [:] }
        let store = appState.manifestStore
        let anchorSubseries = store.entry(forVolumeId: anchor.volumeId)?.subseries

        // One fetch, for the anchor's volume, and only if some candidate is actually in it.
        var arrangement: VolumeArrangement?
        if candidates.contains(where: { $0.volumeId == anchor.volumeId }),
           let pipeline = appState.indexingPipeline {
            // `try?` deliberately: RelatedDocumentsEngine wraps this whole call in `try?` and
            // coalesces a throw to "no contribution", so letting one escape would zero the axis for
            // every candidate — the exact silent-flat failure this work exists to prevent.
            if let structure = try? await pipeline.cachedVolumeStructure(forVolumeId: anchor.volumeId),
               !structure.isEmpty {
                arrangement = VolumeArrangement(structure)
            } else {
                #if DEBUG
                // Paired with `isVolumeIndexed` because `cachedVolumeStructure` collapses "no row",
                // "unreadable column" and "decode failed" into one nil. Without the pairing a
                // corrupt row on a fully indexed volume looks identical to a volume nobody indexed,
                // and only the first is interesting.
                if (try? pipeline.isVolumeIndexed(anchor.volumeId)) == true {
                    print("[SubseriesScorer] \(anchor.volumeId) is indexed but has no usable structure — corpus proximity degraded to the floor")
                }
                #endif
            }
        }
        var scores: [DocumentKey: Double] = [:]
        for candidate in candidates {
            if candidate.volumeId == anchor.volumeId {
                scores[candidate] = Self.sameVolumeScore(
                    anchorId: anchor.documentId,
                    candidateId: candidate.documentId,
                    arrangement: arrangement)
            } else if let anchorSubseries, !anchorSubseries.isEmpty,
                      store.entry(forVolumeId: candidate.volumeId)?.subseries == anchorSubseries {
                scores[candidate] = 0.5
            }
        }
        return scores
    }
}

// MARK: - SharedPersonScorer

/// Scores candidates by overlap of the people they mention, measured against the anchor as a
/// Jaccard index over cross-corpus person-rollup identities.
///
/// One batched query (`PersonMentionStore.rollupMentions(forDocuments:)`, 499-chunked) resolves the
/// anchor's and every candidate's raw per-volume person refs to stable rollup ids in a single pass —
/// the design's "batch, never one-SQL-per-candidate" rule. Raw refs are volume-local and collide
/// across volumes, so overlap is computed over rollup ids, never raw refs. An anchor mentioning no
/// resolvable people contributes nothing.
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
struct SharedPersonScorer: SimilarityScorer {

    var axis: SimilarityAxis { .sharedPersons }

    /// Creates the scorer.
    init() {}

    func scores(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async throws -> [DocumentKey: Double] {
        guard let store = appState.personMentionStore, !candidates.isEmpty else { return [:] }
        let docs = ([anchor] + candidates).map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let mentions = try await store.rollupMentions(forDocuments: docs)

        // Reconstruct each document's rollup-id set from the flat (rollup × document) rows.
        var rollupsByDocument: [String: Set<Int>] = [:]
        for mention in mentions {
            let key = DocumentKey(volumeId: mention.volumeId, documentId: mention.documentId).compositeString
            rollupsByDocument[key, default: []].insert(mention.rollupId)
        }

        let anchorRollups = rollupsByDocument[anchor.compositeString] ?? []
        guard !anchorRollups.isEmpty else { return [:] }

        var scores: [DocumentKey: Double] = [:]
        for candidate in candidates {
            let candidateRollups = rollupsByDocument[candidate.compositeString] ?? []
            let score = ProximityMath.jaccard(anchorRollups, candidateRollups)
            guard score > 0 else { continue }
            scores[candidate] = score
        }
        return scores
    }
}

// MARK: - SharedSubjectScorer

/// Scores candidates by overlap of their detected subject topics against the anchor's.
///
/// **Inert in Phases 1–2**: `DocumentSubjectStore.shared` is `nil` (the document-grain data is gated
/// on #261, design §5), so this scorer returns no scores and contributes 0 to every candidate — the
/// find-related feature ships fully functional on the live generators and scorers and gains this axis
/// on the data drop with no view change. The overlap logic below is the Phase 3 behaviour, guarded so
/// it lights up automatically once the index is bundled.
///
/// Version history:
///   1.0 — #308 Phase 2: seam scorer, inert until the Phase 3 document-subject index ships
struct SharedSubjectScorer: SimilarityScorer {

    var axis: SimilarityAxis { .sharedSubjects }

    /// Creates the scorer.
    init() {}

    func scores(
        anchor: DocumentKey,
        candidates: [DocumentKey],
        appState: AppState
    ) async throws -> [DocumentKey: Double] {
        guard let index = DocumentSubjectStore.shared, !candidates.isEmpty else { return [:] }
        let anchorRefs = Set(index.subjects(forDocument: anchor).map(\.ref))
        guard !anchorRefs.isEmpty else { return [:] }
        var scores: [DocumentKey: Double] = [:]
        for candidate in candidates {
            let candidateRefs = Set(index.subjects(forDocument: candidate).map(\.ref))
            let score = ProximityMath.jaccard(anchorRefs, candidateRefs)
            guard score > 0 else { continue }
            scores[candidate] = score
        }
        return scores
    }
}
