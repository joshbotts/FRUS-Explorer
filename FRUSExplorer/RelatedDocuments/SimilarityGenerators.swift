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
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> [GeneratedCandidate] {
        guard let pipeline = appState.indexingPipeline else { return [] }
        let result = try await pipeline.archivalNeighbors(
            forVolumeId: anchor.volumeId,
            documentId: anchor.documentId,
            documentYear: anchorYear,
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
