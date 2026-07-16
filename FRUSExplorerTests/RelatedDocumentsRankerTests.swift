// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - DocumentKeyTests

/// Verifies the shared `DocumentKey`'s boundary conversions and `Codable` round-trip.
struct DocumentKeyTests {

    @Test("compositeString is the slash-joined boundary form")
    func compositeString() {
        #expect(DocumentKey(volumeId: "frus1969-76v01", documentId: "d42").compositeString
                == "frus1969-76v01/d42")
        #expect(DocumentKey("v", "d").tuple.volumeId == "v")
    }

    @Test("init?(compositeString:) round-trips and rejects malformed input")
    func compositeRoundTrip() {
        let key = DocumentKey(volumeId: "frus1969-76v01", documentId: "d42")
        #expect(DocumentKey(compositeString: key.compositeString) == key)
        // A document id never contains a slash, so first-slash split is total.
        #expect(DocumentKey(compositeString: "no-separator") == nil)
        #expect(DocumentKey(compositeString: "/d42") == nil)          // empty volume
        #expect(DocumentKey(compositeString: "frus1969-76v01/") == nil) // empty document
        #expect(DocumentKey(compositeString: "") == nil)
    }

    @Test("DocumentKey Codable round-trips")
    func codable() throws {
        let key = DocumentKey(volumeId: "frus1952-54v10", documentId: "d197")
        let data = try JSONEncoder().encode(key)
        #expect(try JSONDecoder().decode(DocumentKey.self, from: data) == key)
    }
}

// MARK: - SimilarityAxisTests

/// Verifies the axis catalogue and the generator/scorer role split.
struct SimilarityAxisTests {

    @Test("all six axes are present")
    func allCases() {
        #expect(SimilarityAxis.allCases.count == 6)
    }

    @Test("only archival provenance and cross-reference are generators")
    func generatorSplit() {
        let generators = SimilarityAxis.allCases.filter(\.isGenerator)
        #expect(Set(generators) == [.archivalProvenance, .crossReference])
    }

    @Test("shared subjects defaults to weight 0 (gated, opt-in)")
    func subjectDefaultOff() {
        #expect(SimilarityAxis.sharedSubjects.defaultWeight == 0)
        #expect(SimilarityAxis.archivalProvenance.defaultWeight > 0)
    }
}

// MARK: - AxisWeightsTests

/// Verifies the weight vector's defaults, subscript, and `Codable` round-trip.
struct AxisWeightsTests {

    @Test("default covers every axis; subject is 0")
    func defaults() {
        let weights = AxisWeights.default
        for axis in SimilarityAxis.allCases {
            #expect(weights[axis] == axis.defaultWeight)
        }
        #expect(weights[.sharedSubjects] == 0)
    }

    @Test("subscript reads 0 for an unset axis and updates on assignment")
    func subscriptBehaviour() {
        var weights = AxisWeights(weights: [.archivalProvenance: 1.0])
        #expect(weights[.dateProximity] == 0)   // unset → 0
        weights[.dateProximity] = 0.4
        #expect(weights[.dateProximity] == 0.4)
    }

    @Test("AxisWeights Codable round-trips")
    func codable() throws {
        let weights = AxisWeights(weights: [.archivalProvenance: 1.0, .sharedPersons: 0.7])
        let data = try JSONEncoder().encode(weights)
        #expect(try JSONDecoder().decode(AxisWeights.self, from: data) == weights)
    }
}

// MARK: - RelatedDocumentsRankerTests

/// Verifies the pure scoring core: weighted-sum, per-generator normalisation, anchor exclusion,
/// record gating, tie-breaking, limiting, and the zero-signal drops.
struct RelatedDocumentsRankerTests {

    private let anchor = DocumentKey(volumeId: "v1", documentId: "d0")
    private let a = DocumentKey(volumeId: "v1", documentId: "d1")
    private let b = DocumentKey(volumeId: "v1", documentId: "d2")
    private let c = DocumentKey(volumeId: "v1", documentId: "d3")

    /// A display record for every candidate, so the record-gating never trips unless a test omits one.
    private func records(_ keys: [DocumentKey]) -> [DocumentKey: CandidateRecord] {
        Dictionary(uniqueKeysWithValues: keys.map {
            ($0, CandidateRecord(header: "Doc \($0.documentId)", dateline: nil,
                                 documentNumber: nil, isEditorialNote: false))
        })
    }

    @Test("weighted sum ranks by total proximity and records the nonzero breakdown")
    func weightedSum() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [.dateProximity: [a: 1.0, b: 0.5]],
            records: records([a, b]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .dateProximity: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a, b])                 // a (2.0) before b (1.5)
        #expect(abs(rows[0].totalScore - 2.0) < 1e-9)
        #expect(abs(rows[1].totalScore - 1.5) < 1e-9)
        #expect(rows[0].axisScores[.archivalProvenance] == 1.0)
        #expect(rows[0].axisScores[.dateProximity] == 1.0)
        #expect(rows[1].axisScores[.dateProximity] == 0.5)
    }

    @Test("each generator axis is normalised to [0,1] by its own max")
    func generatorNormalisation() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.crossReference: [a: 4, b: 2]],   // raw strengths 4 and 2
            scorerScores: [:],
            records: records([a, b]),
            weights: AxisWeights(weights: [.crossReference: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a, b])
        #expect(rows[0].axisScores[.crossReference] == 1.0)   // 4/4
        #expect(rows[1].axisScores[.crossReference] == 0.5)   // 2/4
    }

    @Test("the anchor is excluded even if a generator emits it")
    func anchorExcluded() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [anchor: 1, a: 1]],
            scorerScores: [:],
            records: records([anchor, a]),
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a])
    }

    @Test("a candidate without a display record is dropped")
    func recordGating() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [:],
            records: records([a]),   // b has no record
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a])
    }

    @Test("a candidate with zero total is omitted")
    func zeroTotalOmitted() {
        // Archival produced `a`, but its weight is 0 and no scorer touches it → total 0 → dropped.
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1]],
            scorerScores: [:],
            records: records([a]),
            weights: AxisWeights(weights: [.archivalProvenance: 0, .dateProximity: 1]),
            limit: 30)
        #expect(rows.isEmpty)
    }

    @Test("an inert axis with no scores contributes nothing and never crashes")
    func inertSubjectAxis() {
        // sharedSubjects weight is > 0 but the scorer returned no scores (Phase 2 inert):
        // the archival signal still ranks `a`, and no subject contribution appears.
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1]],
            scorerScores: [:],   // no sharedSubjects entries
            records: records([a]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .sharedSubjects: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a])
        #expect(rows[0].axisScores[.sharedSubjects] == nil)
    }

    @Test("ties break by composite key ascending (stable)")
    func tieBreak() {
        // a and b get identical totals; a.compositeString ("v1/d1") < b ("v1/d2").
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [:],
            records: records([a, b]),
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30)
        #expect(rows.map(\.key) == [a, b])
    }

    @Test("the limit truncates to the top rows")
    func limitTruncates() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1, c: 1]],
            scorerScores: [.dateProximity: [a: 1.0, b: 0.5, c: 0.1]],
            records: records([a, b, c]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .dateProximity: 1]),
            limit: 2)
        #expect(rows.map(\.key) == [a, b])   // top 2 by total
    }

    @Test("an empty candidate universe yields no rows")
    func emptyUniverse() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor, generatorStrengths: [:], scorerScores: [:],
            records: [:], weights: .default, limit: 30)
        #expect(rows.isEmpty)
    }

    @Test("all-zero weights yield no rows")
    func allZeroWeights() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [.dateProximity: [a: 1.0]],
            records: records([a, b]),
            weights: AxisWeights(weights: [:]),   // everything 0
            limit: 30)
        #expect(rows.isEmpty)
    }
}

// MARK: - RelatedDocumentsRequestTests

/// Verifies the restorable request value round-trips through `Codable` (the window-payload contract).
struct RelatedDocumentsRequestTests {

    @Test("RelatedDocumentsRequest Codable round-trips with custom tuning and scope")
    func codableRoundTrip() throws {
        var weights = AxisWeights.default
        weights[.sharedSubjects] = 0.4
        let request = RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: "frus1969-76v01", documentId: "d42"),
            anchorYear: 1971,
            weights: weights,
            scope: .subseries(key: "1969-76", anchorVolumeId: "frus1969-76v01"),
            limit: 25)
        let data = try JSONEncoder().encode(request)
        let restored = try JSONDecoder().decode(RelatedDocumentsRequest.self, from: data)
        #expect(restored == request)
        #expect(restored.weights[.sharedSubjects] == 0.4)
        #expect(restored.anchorYear == 1971)
    }
}
