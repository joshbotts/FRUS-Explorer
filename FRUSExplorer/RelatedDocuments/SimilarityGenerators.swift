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
/// Strength is the citation multiplicity (how many edges connect the pair), so a document the anchor
/// cites repeatedly ranks above one it cites once; the engine normalises the axis to `[0, 1]`.
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
                strength: Double(candidate.citationCount))
        }
    }
}
