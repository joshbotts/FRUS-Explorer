// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalProvenanceGenerator

/// Generates candidates that share the anchor's original archival provenance — the same lot file,
/// central decimal file, record-group series, or presidential-library collection.
///
/// Wraps the existing bounded neighbor engine (`IndexingPipeline.archivalNeighbors(forVolumeId:…)`),
/// which re-parses the anchor's stored source note and runs one indexed keyed query. Cost is
/// `O(neighbours)`, never a corpus scan (design §6.2). Each candidate carries a flat strength of 1 —
/// archival adjacency is binary (a document either shares the archival key or doesn't), so the axis
/// contributes uniformly and the *other* axes discriminate among the archival neighbours.
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
struct ArchivalProvenanceGenerator: SimilarityGenerator {

    var axis: SimilarityAxis { .archivalProvenance }

    /// Creates the generator.
    init() {}

    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> [GeneratedCandidate] {
        guard let pipeline = appState.indexingPipeline else { return [] }
        let result = try await pipeline.archivalNeighbors(
            forVolumeId: anchor.volumeId,
            documentId: anchor.documentId,
            documentYear: anchorYear,
            limit: limit,
            scopeVolumeIds: scopeVolumeIds)
        return result.documents.map { document in
            GeneratedCandidate(
                key: DocumentKey(volumeId: document.volumeId, documentId: document.documentId),
                record: CandidateRecord(
                    header: document.header,
                    dateline: document.dateline,
                    documentNumber: document.documentNumber,
                    isEditorialNote: document.isEditorialNote),
                strength: 1.0)
        }
    }
}

// MARK: - CrossReferenceGenerator

/// Generates candidates that the anchor directly cites or that directly cite the anchor.
///
/// Wraps the bounded `CrossReferenceStore.relatedByCitation` ego query (document-target-filtered,
/// both directions, indexed candidates only) — `O(ego edges)`, never a corpus scan (design §6.2).
/// Strength is the citation multiplicity **log-damped** (`1 + ln(count)`, #356), so a document the
/// anchor cites repeatedly still ranks above one it cites once, but a heavy-tailed outlier (measured
/// up to 121× — usually an editorial note reproducing many telegrams) no longer compresses the
/// anchor's genuine single-citation partners toward ~0 when the engine normalises the axis to
/// `[0, 1]` by its max. `1 + ln` keeps a 1× citation at exactly 1.0 (never below the floor) while
/// pulling the outlier from 121 down to ~5.8, so a lone direct citation stays visible above the
/// flat archival-provenance bulk. Decision recorded in #356; the design owner chose log over √
/// (gentler) and saturation (near-binary).
///
/// Co-citation (documents citing the same sources as the anchor) is a deliberate fast-follow — it
/// needs a landmark cap so a heavily-cited shared target doesn't blow the bound — and is not included
/// here; direct citation is the primary, cheapest cross-reference relatedness signal.
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation (direct citation)
struct CrossReferenceGenerator: SimilarityGenerator {

    var axis: SimilarityAxis { .crossReference }

    /// Creates the generator.
    init() {}

    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> [GeneratedCandidate] {
        guard let store = appState.crossReferenceStore else { return [] }
        let candidates = try await store.relatedByCitation(
            forDocumentId: anchor.documentId,
            volumeId: anchor.volumeId,
            scopeVolumeIds: scopeVolumeIds,
            limit: limit)
        return candidates.map { candidate in
            GeneratedCandidate(
                key: DocumentKey(volumeId: candidate.volumeId, documentId: candidate.documentId),
                record: CandidateRecord(
                    header: candidate.header,
                    dateline: candidate.dateline,
                    documentNumber: candidate.documentNumber,
                    isEditorialNote: candidate.isEditorialNote),
                // #356: log-damp the raw multiplicity so one outlier can't bury the anchor's real
                // single-citation partners (see ProximityMath.logDampedMultiplicity).
                strength: ProximityMath.logDampedMultiplicity(candidate.citationCount))
        }
    }
}
