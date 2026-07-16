// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SimilarityAxis

/// One dimension of document-to-document proximity in the #308 find-related model.
///
/// Axes split into two roles (design §6.2). **Generators** produce a *bounded* candidate
/// set (genuinely `O(neighbours)`, a keyed lookup) — archival provenance and cross-references.
/// **Scorers** only *rank* the already-generated candidates and never enumerate — date,
/// subseries, shared persons, and (Phase 3) shared subjects. The split exists because three of
/// the "live" signals map to huge sets (a head-of-state person rollup is tens of thousands of
/// documents), so unioning every axis's enumeration would approach the whole corpus for a
/// prominent anchor; scorers dodge that by batch-scoring the bounded candidate set instead.
///
/// Version history:
///   1.0 — #308 Phase 2: initial six-axis model (cross-reference generator lands in Phase 2b;
///          shared-subjects scorer is inert until the Phase 3 document-grain data drop)
enum SimilarityAxis: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// Same original archival provenance — lot file, central decimal file, record-group series,
    /// or presidential-library collection (`IndexingPipeline.archivalNeighbors`). A generator.
    case archivalProvenance
    /// Directly cited by or citing the anchor (`CrossReferenceStore` edges). A generator.
    case crossReference
    /// Nearness of editorial coverage dates (`|Δyear|` decay). A scorer.
    case dateProximity
    /// Same volume or same subseries (`VolumeManifestEntry.subseries`). A scorer.
    case subseries
    /// Overlap of the mentioned people, resolved through the cross-corpus person rollup. A scorer.
    case sharedPersons
    /// Overlap of detected subject topics (Phase 3 document-grain data; inert until then). A scorer.
    case sharedSubjects

    var id: String { rawValue }

    /// Whether this axis *produces* candidates (bounded enumeration) rather than only scoring
    /// them. Generators drive the candidate universe; scorers rank it (design §6.2).
    var isGenerator: Bool {
        switch self {
        case .archivalProvenance, .crossReference: return true
        case .dateProximity, .subseries, .sharedPersons, .sharedSubjects: return false
        }
    }

    /// The user-facing axis name.
    var displayName: String {
        switch self {
        case .archivalProvenance:
            return String(localized: "related.axis.archival", defaultValue: "Archival provenance")
        case .crossReference:
            return String(localized: "related.axis.crossReference", defaultValue: "Cross-references")
        case .dateProximity:
            return String(localized: "related.axis.date", defaultValue: "Close in date")
        case .subseries:
            return String(localized: "related.axis.subseries", defaultValue: "Same volume or subseries")
        case .sharedPersons:
            return String(localized: "related.axis.persons", defaultValue: "Shared people")
        case .sharedSubjects:
            return String(localized: "related.axis.subjects", defaultValue: "Shared topics")
        }
    }

    /// An SF Symbol representing the axis in the tuning UI and per-row "why related" chips.
    var systemImage: String {
        switch self {
        case .archivalProvenance: return "archivebox"
        case .crossReference:     return "arrow.triangle.branch"
        case .dateProximity:      return "calendar"
        case .subseries:          return "books.vertical"
        case .sharedPersons:      return "person.2"
        case .sharedSubjects:     return "tag"
        }
    }

    /// The out-of-the-box weight for this axis. Generators and shared people start meaningful;
    /// date and subseries are mild refinements; **shared subjects defaults to 0** — the data is
    /// gated (#261) and, per design Q4, the detected-topic axis ships opt-in with an explicit
    /// "experimental" framing rather than shaping results by default.
    var defaultWeight: Double {
        switch self {
        case .archivalProvenance: return 1.0
        case .crossReference:     return 1.0
        case .dateProximity:      return 0.5
        case .subseries:          return 0.3
        case .sharedPersons:      return 0.7
        case .sharedSubjects:     return 0.0
        }
    }
}

// MARK: - AxisWeights

/// The user-tunable weight vector over the similarity axes — per-request state (it rides the
/// `Codable` window payload so a restored macOS window recovers the exact tuning, design §6.3),
/// not a property of the stateless axis types.
///
/// A candidate's total proximity is `Σ weight[axis] × axisScore[axis]` (`RelatedDocumentsRanker`).
struct AxisWeights: Codable, Hashable, Sendable {

    /// Weight per axis; a missing axis reads as 0 through the subscript.
    private(set) var weights: [SimilarityAxis: Double]

    /// Creates a weight vector from an explicit per-axis map.
    init(weights: [SimilarityAxis: Double]) {
        self.weights = weights
    }

    /// The default tuning — each axis's `defaultWeight` (shared subjects 0, design Q4).
    static let `default` = AxisWeights(
        weights: Dictionary(uniqueKeysWithValues: SimilarityAxis.allCases.map { ($0, $0.defaultWeight) }))

    /// The weight for `axis` (0 when unset). Assigning updates the vector.
    subscript(_ axis: SimilarityAxis) -> Double {
        get { weights[axis] ?? 0 }
        set { weights[axis] = newValue }
    }
}

// MARK: - Candidate + result value types

/// The display fields for one related-document row, carried alongside the key so the list
/// renders (and the row-tap hand-off builds a `DocumentBrowserEntry`) without a re-fetch.
struct CandidateRecord: Sendable, Hashable {
    /// The document header (title). May be empty; the row falls back to the document id.
    let header: String
    /// The human-readable dateline (a display string, e.g. `"Washington, June 3, 1964"`), if any.
    let dateline: String?
    /// The document number within its volume, if any.
    let documentNumber: String?
    /// Whether the document is an editorial note rather than a primary document.
    let isEditorialNote: Bool

    /// Creates a display record.
    init(header: String, dateline: String?, documentNumber: String?, isEditorialNote: Bool) {
        self.header = header
        self.dateline = dateline
        self.documentNumber = documentNumber
        self.isEditorialNote = isEditorialNote
    }
}

/// One candidate a generator produced: its key, display record, and a **raw** (pre-normalisation)
/// strength for its generating axis. The engine normalises each axis's strengths to `[0, 1]`.
struct GeneratedCandidate: Sendable {
    /// The candidate document.
    let key: DocumentKey
    /// The candidate's display fields.
    let record: CandidateRecord
    /// The generator's raw strength for this candidate (`≥ 0`), normalised per axis by the engine.
    let strength: Double

    /// Creates a generated candidate.
    init(key: DocumentKey, record: CandidateRecord, strength: Double) {
        self.key = key
        self.record = record
        self.strength = strength
    }
}

/// One ranked related-document result: the document, its display record, its total proximity, and
/// the per-axis breakdown of *nonzero* contributions (the "why related" affordance).
struct RelatedDocumentRow: Identifiable, Sendable, Hashable {
    /// The related document.
    let key: DocumentKey
    /// Display fields for the row.
    let record: CandidateRecord
    /// The weighted total proximity `Σ weight[axis] × axisScore[axis]`.
    let totalScore: Double
    /// The nonzero per-axis contributions (post-weight `axisScore`, not the weighted product),
    /// for the "why related" chips.
    let axisScores: [SimilarityAxis: Double]

    var id: DocumentKey { key }
    /// The related document's volume.
    var volumeId: String { key.volumeId }
    /// The related document's id.
    var documentId: String { key.documentId }

    /// Creates a ranked row.
    init(key: DocumentKey, record: CandidateRecord, totalScore: Double,
                axisScores: [SimilarityAxis: Double]) {
        self.key = key
        self.record = record
        self.totalScore = totalScore
        self.axisScores = axisScores
    }
}

/// The payload a find-related load returns: the ranked rows (already limited) and the candidate
/// count before the limit was applied (drives an "N more" overflow hint).
struct RelatedDocumentsResult: Sendable {
    /// The ranked, limited rows.
    let rows: [RelatedDocumentRow]
    /// The candidate count before limiting.
    let totalBeforeLimit: Int

    /// The empty result — no live index, or no candidates.
    static let empty = RelatedDocumentsResult(rows: [], totalBeforeLimit: 0)

    /// Creates a result.
    init(rows: [RelatedDocumentRow], totalBeforeLimit: Int) {
        self.rows = rows
        self.totalBeforeLimit = totalBeforeLimit
    }
}

// MARK: - Axis protocols

/// A bounded candidate producer (design §6.2). Enumerates only `O(neighbours)` documents via a
/// keyed lookup — never a corpus scan. `@MainActor` so it reads `AppState`; the actual SQLite work
/// happens inside the awaited actor calls (`IndexingPipeline`, `CrossReferenceStore`), off the main
/// thread.
@MainActor protocol SimilarityGenerator {
    /// The axis this generator produces candidates for.
    var axis: SimilarityAxis { get }
    /// The bounded candidate set for `anchor`, filtered to `scopeVolumeIds` (`nil` = all indexed).
    /// `anchorYear` feeds date-sensitive keyed queries (e.g. decimal-file chronological segmenting).
    func candidates(for anchor: DocumentKey, anchorYear: Int?,
                    scopeVolumeIds: Set<String>?, appState: AppState) async throws -> [GeneratedCandidate]
}

/// A ranker over an already-generated candidate set (design §6.2). Produces a `[0, 1]` score per
/// candidate via **batch** signature extraction (one chunked query, never one-per-candidate) and
/// never enumerates. `@MainActor` for the same reason as `SimilarityGenerator`.
@MainActor protocol SimilarityScorer {
    /// The axis this scorer contributes.
    var axis: SimilarityAxis { get }
    /// A `0…1` proximity for each candidate against `anchor`. A candidate absent from the result
    /// (or scored 0) contributes nothing on this axis.
    func scores(anchor: DocumentKey, candidates: [DocumentKey],
                appState: AppState) async throws -> [DocumentKey: Double]
}
