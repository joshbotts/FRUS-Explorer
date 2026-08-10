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

// MARK: - GeneratedPoolTruncationTests

/// That a truncated candidate pool says so (#645).
///
/// #645's third ask, and the repo's own convention — `RecordedCount` and the facet `bounds` both
/// refuse to present a truncated total as a complete one. The related-documents overflow line did
/// exactly that: `totalBeforeLimit` is computed **inside** the ≤120 candidate pool, so an anchor
/// with 1,063 archival neighbours reported at most 120 and called it the total. Ranking can only
/// surface a document the pool contained, so the other 943 were never scored and nothing said so.
///
/// Version history:
///   1.0 — Session 2026-08-10: #645 remainder
@Suite("Generated pool truncation (#645)")
struct GeneratedPoolTruncationTests {

    private func candidate(_ id: String) -> GeneratedCandidate {
        GeneratedCandidate(
            key: DocumentKey(volumeId: "frus1952-54v01", documentId: id),
            record: CandidateRecord(header: id, dateline: nil, documentNumber: nil,
                                    isEditorialNote: false),
            strength: 1.0)
    }

    @Test("A pool that returned fewer than it had is truncated")
    func reportsTruncation() {
        let pool = GeneratedPool(candidates: [candidate("d1"), candidate("d2")],
                                 availableTotal: 1_063)
        #expect(pool.isTruncated)
        #expect(pool.availableTotal == 1_063)
    }

    @Test("A pool that returned everything is not truncated")
    func completePoolIsNotTruncated() {
        #expect(!GeneratedPool(candidates: [candidate("d1")], availableTotal: 1).isTruncated)
    }

    @Test("An unreported total is unknown, not complete")
    func unknownTotalIsNotTruncated() {
        // The distinction that carries the design. A generator that does not count must not be
        // read as asserting completeness — that is how a truncated total becomes a confident one.
        let pool = GeneratedPool(candidates: [candidate("d1"), candidate("d2")])
        #expect(pool.availableTotal == nil)
        #expect(!pool.isTruncated, """
            `nil` means "did not count". Treating it as truncated would put a disclosure on every \
            cross-reference result; treating it as a total would assert a completeness nobody \
            measured. It is neither.
            """)
    }

    @Test("The empty pool reports nothing")
    func emptyPool() {
        #expect(GeneratedPool.empty.candidates.isEmpty)
        #expect(GeneratedPool.empty.availableTotal == nil)
        #expect(!GeneratedPool.empty.isTruncated)
    }

    @Test("The result carries the cut so a surface can disclose it")
    func resultCarriesTheCut() {
        let withCut = RelatedDocumentsResult(rows: [], totalBeforeLimit: 120, poolCutFrom: 1_063)
        #expect(withCut.poolCutFrom == 1_063, """
            Without this the overflow line reads "0 more related" for an anchor with 943 \
            neighbours nobody scored — the exact shape #645 objected to.
            """)
        #expect(RelatedDocumentsResult.empty.poolCutFrom == nil)
        #expect(RelatedDocumentsResult(rows: [], totalBeforeLimit: 5).poolCutFrom == nil,
                "the default stays nil, so a caller that does not know cannot accidentally claim")
    }

    @Test("The archival generator reports its total; the cross-reference generator does not")
    func generatorsReportHonestly() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/RelatedDocuments/SimilarityGenerators.swift"),
            encoding: .utf8)
        #expect(source.contains("availableTotal: result.totalCount"), """
            The archival generator knows its whole in-scope neighbour set — `totalCount` — and \
            discarding it is what left the engine unable to report the cut (#645).
            """)
        let crossRef = try #require(source.range(of: "struct CrossReferenceGenerator"))
        #expect(!String(source[crossRef.lowerBound...]).contains("availableTotal:"), """
            `relatedByCitation` reports no total, so this generator must leave it nil rather than \
            inferring one from what it happened to return.
            """)
    }

    @Test("The engine takes the largest cut, not the sum")
    func engineTakesTheLargestCut() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/RelatedDocuments/RelatedDocumentsEngine.swift"),
            encoding: .utf8)
        #expect(source.contains("poolCutFrom = max(poolCutFrom ?? 0, total)"), """
            The axes overlap, so summing their totals double-counts the documents both produced. \
            The largest is the one whose truncation actually bounds what a scorer could have \
            surfaced.
            """)
        #expect(source.contains("poolCutFrom: poolCutFrom"),
                "and it must reach the result, or no surface can disclose it")
    }

    @Test("The surface says it, and only when it has something to say")
    func viewDisclosesTheCut() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift"),
            encoding: .utf8)
        #expect(source.contains("related.poolCut"), """
            The overflow line counts what scored inside the pool; a second line has to say the \
            pool itself was cut, or the first one is a truncated total presented as complete — \
            which is the convention #645 cited against it.
            """)
        #expect(source.contains("if let poolCutFrom, poolCutFrom > totalBeforeLimit"), """
            Guarded, so an anchor whose pool was NOT cut gets no disclosure at all. A permanent \
            caveat reads as boilerplate and stops being read.
            """)
        #expect(source.contains("poolCutFrom = result.poolCutFrom"),
                "and the view has to actually take the value off the result")
    }
}
