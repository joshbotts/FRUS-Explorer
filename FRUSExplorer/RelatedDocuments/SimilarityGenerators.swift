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
/// **Engine-level consequence, worth stating because it is invisible from here.** Because every
/// candidate's strength is the same constant, the ranker's per-axis max-normalisation
/// (`RelatedDocumentsRanker.rank`, step 2) is the *identity map* on this axis: every archival
/// candidate contributes a full `weight × 1.0` and the axis cannot discriminate among its own
/// candidates at all. That is why the "why related" chip states presence rather than a percentage —
/// a percentage here would have exactly one possible value.
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
    ) async throws -> GeneratedPool {
        guard let pipeline = appState.indexingPipeline else { return .empty }
        // The cohort-aware entry point: the same query, plus how many documents share this
        // anchor's container corpus-wide. That number is the chip (#644); it never touches the
        // strength, which stays constant because every candidate here shares one container.
        let result = try await pipeline.archivalNeighborsWithCohort(
            forVolumeId: anchor.volumeId,
            documentId: anchor.documentId,
            documentYear: anchorYear,
            limit: limit,
            scopeVolumeIds: scopeVolumeIds)
        // #645: `totalCount` is the whole in-scope neighbour set; `documents` is at most `limit`
        // of it. Reporting the difference is what stops the engine's "N more" line — computed
        // inside this pool — from presenting a truncated total as a complete one.
        return GeneratedPool(
            candidates: result.documents.map { document in
                GeneratedCandidate(
                    key: DocumentKey(volumeId: document.volumeId, documentId: document.documentId),
                    record: CandidateRecord(
                        header: document.header,
                        dateline: document.dateline,
                        documentNumber: document.documentNumber,
                        isEditorialNote: document.isEditorialNote),
                    strength: 1.0,
                    evidenceCount: result.cohortCount,
                    evidenceLabel: result.basis)
            },
            availableTotal: result.totalCount)
    }
}

// MARK: - CrossReferenceGenerator

/// Generates candidates that the anchor directly cites or that directly cite the anchor.
///
/// Wraps the bounded `CrossReferenceStore.relatedByCitation` ego query (document-target-filtered,
/// both directions, indexed candidates only) — `O(ego edges)`, never a corpus scan (design §6.2).
/// Strength is the citation multiplicity **log-damped** (`1 + ln(count)`, #356), so a document the
/// anchor cites repeatedly still ranks above one it cites once, while a heavy-tailed outlier
/// compresses the anchor's single-citation partners less than a raw count would. Decision recorded
/// in #356; the design owner chose log over √ (gentler) and saturation (near-binary).
///
/// Measured on the owner's index (2026-08-02, over anchors that are themselves indexed documents):
/// the largest pair multiplicity is **48**, not the 121 this comment previously claimed, and 92.63%
/// of pairs are 1×. The worst pair is `frus1864p1/comp2` ↔ `frus1864p1/d147` — and `comp2` is
/// headed "Index." with `is_editorial_note = 0`, so the old gloss "usually an editorial note
/// reproducing many telegrams" was wrong too; it survives the target predicate only because its id
/// is `comp2` rather than `in5`.
///
/// See ``ProximityMath/logDampedMultiplicity(_:)`` for what the damping is and is not worth.
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
    ) async throws -> GeneratedPool {
        guard let store = appState.crossReferenceStore else { return .empty }
        let candidates = try await store.relatedByCitation(
            forDocumentId: anchor.documentId,
            volumeId: anchor.volumeId,
            scopeVolumeIds: scopeVolumeIds,
            limit: limit)
        // `availableTotal` is deliberately left nil: `relatedByCitation` returns at most `limit`
        // and reports no total, so this generator does not know whether it was cut. `nil` means
        // "unknown", and `GeneratedPool` keeps that distinct from "not truncated" — inferring
        // completeness from a generator that never counted is how a truncated total becomes a
        // confident one.
        return GeneratedPool(candidates: candidates.map { candidate in
            GeneratedCandidate(
                key: DocumentKey(volumeId: candidate.volumeId, documentId: candidate.documentId),
                record: CandidateRecord(
                    header: candidate.header,
                    dateline: candidate.dateline,
                    documentNumber: candidate.documentNumber,
                    isEditorialNote: candidate.isEditorialNote),
                // #356: log-damp the raw multiplicity so one outlier can't bury the anchor's real
                // single-citation partners (see ProximityMath.logDampedMultiplicity).
                strength: ProximityMath.logDampedMultiplicity(candidate.citationCount),
                evidenceCount: candidate.citationCount)
        })
    }
}
