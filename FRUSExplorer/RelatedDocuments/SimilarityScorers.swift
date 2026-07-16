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
            let delta = abs(Double(candidateYear - anchorYear))
            scores[candidate] = exp(-delta / Self.tau)
        }
        return scores
    }

    /// The four-digit year prefix of an ISO date (`yyyy-MM-dd` → `yyyy`), or `nil`.
    private func year(_ iso: String) -> Int? { Int(iso.prefix(4)) }
}

// MARK: - SubseriesScorer

/// Scores candidates by shelf proximity: the same volume as the anchor, or the same subseries.
///
/// Same volume scores 1.0 (a document's own volume is its strongest structural neighbourhood); a
/// different volume in the same `VolumeManifestEntry.subseries` scores 0.5; anything else 0. The
/// subseries lookup is a precomputed `[volumeId: subseries]` map, because `entry(forVolumeId:)` is a
/// linear scan over ~550 entries and must not run once per candidate.
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
struct SubseriesScorer: SimilarityScorer {

    var axis: SimilarityAxis { .subseries }

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
        // Precompute volumeId → subseries once (entry(forVolumeId:) is an O(n) linear scan).
        let entries = store.diffResult?.known ?? store.bundledEntries
        var subseriesByVolume: [String: String] = [:]
        subseriesByVolume.reserveCapacity(entries.count)
        for entry in entries { subseriesByVolume[entry.volumeId] = entry.subseries }

        var scores: [DocumentKey: Double] = [:]
        for candidate in candidates {
            if candidate.volumeId == anchor.volumeId {
                scores[candidate] = 1.0
            } else if let anchorSubseries, !anchorSubseries.isEmpty,
                      subseriesByVolume[candidate.volumeId] == anchorSubseries {
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
            let intersection = anchorRollups.intersection(candidateRollups).count
            guard intersection > 0 else { continue }
            let union = anchorRollups.union(candidateRollups).count
            scores[candidate] = Double(intersection) / Double(union)
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
            let intersection = anchorRefs.intersection(candidateRefs).count
            guard intersection > 0 else { continue }
            let union = anchorRefs.union(candidateRefs).count
            scores[candidate] = Double(intersection) / Double(union)
        }
        return scores
    }
}
