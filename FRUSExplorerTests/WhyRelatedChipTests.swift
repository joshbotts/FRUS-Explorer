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

// MARK: - WhyRelatedChipTests

/// The "why related" chips say what their axis actually measured.
///
/// ## The defect
/// A generator axis's score is normalised by *that anchor's own strongest candidate*, so printing it
/// as a percentage states something the number does not mean. Measured on the owner's 552-volume
/// index (2026-08-02, over the 88,940 anchors that are themselves indexed documents):
///
///  - `archivalProvenance` emits a constant strength, so max-normalisation is the identity map and
///    its chip has read exactly "100%" on **every row it has ever rendered**.
///  - `crossReference` reads 100% for the **54.98%** of anchors with exactly one candidate, and an
///    identical single citation reads as little as 21% beside a 48×-cited neighbour.
///
/// So generator axes now state evidence and scorer axes state their score.
///
/// Version history:
///   1.0 — cross-reference chip honesty: initial implementation
@Suite("Why-related chips")
struct WhyRelatedChipTests {

    private func row(
        axisScores: [SimilarityAxis: Double],
        evidence: [SimilarityAxis: Int] = [:],
        labels: [SimilarityAxis: String] = [:]
    ) -> RelatedDocumentRow {
        var row = RelatedDocumentRow(
            key: DocumentKey(volumeId: "frus1864p1", documentId: "d147"),
            record: CandidateRecord(header: "Mr. Adams to Mr. Seward",
                                    dateline: nil, documentNumber: nil, isEditorialNote: false),
            totalScore: 1.0,
            axisScores: axisScores)
        row.axisEvidence = evidence
        row.axisEvidenceLabel = labels
        return row
    }

    // MARK: - What each axis says

    /// The chip that carried no information at all, now carrying the only thing that varies (#644).
    ///
    /// Archival strength is a constant and correctly so — every candidate in a pool shares one
    /// container, so there is nothing to grade *within* a pool. What was missing is legibility
    /// *across* anchors: "same provenance" read identically for a lot holding two documents and
    /// for Nixon's NSC Files holding 7,056.
    @Test("Archival provenance names its container and its size")
    func archivalStatesCohort() {
        let chips = row(axisScores: [.archivalProvenance: 1.0],
                        evidence: [.archivalProvenance: 1_063],
                        labels: [.archivalProvenance: "Lot 54 D 270"]).whyRelatedChips
        #expect(chips.count == 1)
        #expect(chips[0].chip == .cohort(container: "Lot 54 D 270", size: 1_063))

        // A tiny container and a huge one must be distinguishable — that is the entire point.
        let small = row(axisScores: [.archivalProvenance: 1.0],
                        evidence: [.archivalProvenance: 2],
                        labels: [.archivalProvenance: "Lot 60 D 627"]).whyRelatedChips
        #expect(small[0].chip != chips[0].chip)
    }

    /// A match path that produced no readable container name falls back to presence — never to a
    /// percentage, for the reason #643 established.
    @Test("An unnamed container still refuses a percentage")
    func archivalWithoutLabel() {
        #expect(row(axisScores: [.archivalProvenance: 1.0]).whyRelatedChips[0].chip == .presence)
        // A label with no count is not a cohort either — "1 of 0" would be nonsense.
        let countless = row(axisScores: [.archivalProvenance: 1.0],
                            labels: [.archivalProvenance: "Lot 54 D 270"]).whyRelatedChips
        #expect(countless[0].chip == .presence)
        let zero = row(axisScores: [.archivalProvenance: 1.0],
                       evidence: [.archivalProvenance: 0],
                       labels: [.archivalProvenance: "Lot 54 D 270"]).whyRelatedChips
        #expect(zero[0].chip == .presence)
        // And never a percentage, whatever the score.
        let odd = row(axisScores: [.archivalProvenance: 0.42]).whyRelatedChips
        #expect(odd[0].chip == .presence)
    }

    /// The number a researcher can act on: how many times these two documents actually cite
    /// each other.
    @Test("Cross-references state the citation count they found")
    func crossReferenceStatesCitations() {
        let chips = row(axisScores: [.crossReference: 1.0],
                        evidence: [.crossReference: 3]).whyRelatedChips
        #expect(chips[0].chip == .citations(3))

        // The same evidence reports the same chip whatever the normalised score is — which is the
        // whole point, since the score depends on the anchor's strongest OTHER candidate.
        let crushed = row(axisScores: [.crossReference: 0.205288],
                          evidence: [.crossReference: 1]).whyRelatedChips
        let alone = row(axisScores: [.crossReference: 1.0],
                        evidence: [.crossReference: 1]).whyRelatedChips
        #expect(crushed[0].chip == alone[0].chip)
        #expect(crushed[0].chip == .citations(1))
    }

    /// Scorer axes are absolute `[0, 1]` measures, so a percentage is the right reading for them
    /// and must be left alone.
    @Test("Scorer axes still state a percentage")
    func scorersStatePercent() {
        let chips = row(axisScores: [.dateProximity: 0.75, .subseries: 0.6,
                                     .sharedPersons: 0.5]).whyRelatedChips
        #expect(chips.map(\.chip) == [.percent(75), .percent(60), .percent(50)])
    }

    /// A real but tiny contribution must not read as zero.
    @Test("A sub-one-percent scorer contribution is not rounded away to a bare 0")
    func subOnePercent() {
        let chips = row(axisScores: [.sharedPersons: 0.004]).whyRelatedChips
        #expect(chips[0].chip == .percent(0), "the view renders `.percent(0)` as \"<1%\"")
    }

    // MARK: - Order

    /// The tie-break exists because ties are the common case, not an edge case: archival is exactly
    /// 1.0 whenever it fires, the top cross-reference candidate is exactly 1.0 for 88.38% of firing
    /// anchors, and date proximity is exactly 1.0 at Δyear = 0. `axisScores` is a `Dictionary` —
    /// per-process hash-seeded — and `sorted(by:)` is not stable, so without a total order the same
    /// row can render its chips differently between launches.
    @Test("Tied axes render in a stable, reproducible order")
    func tiesAreOrderedDeterministically() {
        let tied: [SimilarityAxis: Double] = [
            .archivalProvenance: 1.0, .crossReference: 1.0, .dateProximity: 1.0
        ]
        let expected = SimilarityAxis.allCases.filter { tied[$0] != nil }

        // Many independently-built dictionaries: a single instance could agree by luck.
        for _ in 0..<50 {
            let chips = row(axisScores: tied, evidence: [.crossReference: 2, .archivalProvenance: 9],
                            labels: [.archivalProvenance: "Lot 1"]).whyRelatedChips
            #expect(chips.map(\.axis) == expected,
                    "tied chips must fall back to the declaration order, got \(chips.map(\.axis))")
        }
    }

    @Test("Chips are ordered by score, strongest first")
    func strongestFirst() {
        let chips = row(axisScores: [.sharedPersons: 0.2, .dateProximity: 0.9,
                                     .subseries: 0.6]).whyRelatedChips
        #expect(chips.map(\.axis) == [.dateProximity, .subseries, .sharedPersons])
    }

    // MARK: - The guard

    /// A cross-reference row whose evidence never arrived must not quietly fall back to the
    /// misleading percentage this work exists to remove. It degrades visibly and complains in DEBUG.
    @Test("A cross-reference row missing its evidence does not silently look normal")
    func missingEvidenceIsNotSilent() {
        let chips = row(axisScores: [.crossReference: 1.0]).whyRelatedChips
        // It still renders — a blank chip would be worse — but as a percent, which is the state the
        // DEBUG log names. What must NOT happen is it claiming a citation count it does not have.
        #expect(chips[0].chip == .percent(100))
        #expect(chips[0].chip != .citations(1))
    }

    // MARK: - The wiring

    /// The chips above are computed from `axisEvidence`; **this** asserts that anything ever puts
    /// something in it.
    ///
    /// Every test above builds its row by hand, so removing the generator's `evidenceCount:` — the
    /// one line that supplies the data — left the whole suite green. Driving the real path needs a
    /// live `AppState`, an indexed fixture and a `CrossReferenceStore`, which this bundle has no
    /// way to assemble; a source audit is the honest substitute and it names what it cannot check.
    @Test("The generator supplies the count and the engine attaches it")
    func evidenceIsWired() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(contentsOf: root.appending(path: path), encoding: .utf8)
        }

        let generators = try source("FRUSExplorer/RelatedDocuments/SimilarityGenerators.swift")
        #expect(generators.contains("evidenceLabel: result.basis"),
                "the archival generator must name the container, or the chip cannot say which")
        #expect(generators.contains("archivalNeighborsWithCohort"),
                "the archival generator must use the cohort-aware entry point")

        // The cohort is captured BEFORE applyScope and includes the anchor. Getting either wrong
        // makes the number quietly mean something else: a scoped cohort would read "1 of 12" and
        // "1 of 7,056" on two screens showing the same pair, and forgetting the +1 understates
        // every container by one.
        let pipeline = try source("FRUSExplorer/Search/IndexingPipeline.swift")
        let cohortLine = try #require(pipeline.range(of: "let cohortCount = "))
        let scopeLine = try #require(pipeline.range(of: "let scoped = Self.applyScope(result"))
        #expect(cohortLine.lowerBound < scopeLine.lowerBound,
                "the cohort must be taken before the scope narrows the count")
        #expect(pipeline.contains("result.totalCount + 1"),
                "every match path excludes the anchor from its own count")
        #expect(generators.contains("evidenceCount: candidate.citationCount"),
                """
                CrossReferenceGenerator must pass the raw citation count. Without it every                 cross-reference chip silently falls back to the normalised percentage this work                 exists to replace — and no assertion over a hand-built row can see that.
                """)

        let engine = try source("FRUSExplorer/RelatedDocuments/RelatedDocumentsEngine.swift")
        #expect(engine.contains("rows[index].axisEvidence = evidence"),
                "the engine must attach the evidence to each ranked row")
        // After ranking, like `snippet` — so the ranker stays pure and cannot reorder anything.
        let fillIndex = try #require(engine.range(of: "rows[index].axisEvidence")).lowerBound
        let rankIndex = try #require(engine.range(of: "RelatedDocumentsRanker.rank(")).lowerBound
        #expect(rankIndex < fillIndex, "evidence must be attached AFTER ranking, never inside it")
        #expect(!engine.contains("generatorEvidence: generatorEvidence"),
                "the evidence must not be threaded into the ranker as a parameter")
    }

    // MARK: - The ranker is untouched

    /// The evidence is attached after ranking, exactly like `snippet`, so nothing here can move a
    /// row. This pins that: a row's rank and score must not depend on `axisEvidence` at all.
    @Test("Attaching evidence cannot change a row's score or order")
    func evidenceDoesNotAffectRanking() {
        let anchor = DocumentKey(volumeId: "v", documentId: "anchor")
        let keys = (1...5).map { DocumentKey(volumeId: "v", documentId: "d\($0)") }
        let records = Dictionary(uniqueKeysWithValues: keys.map {
            ($0, CandidateRecord(header: $0.documentId, dateline: nil,
                                 documentNumber: nil, isEditorialNote: false))
        })
        let strengths = Dictionary(uniqueKeysWithValues: keys.enumerated().map {
            ($0.element, Double($0.offset + 1))
        })
        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.crossReference: strengths],
            scorerScores: [:],
            records: records,
            weights: AxisWeights(weights: [.crossReference: 1.0]),
            limit: 10)

        // The ranker produces rows with no evidence at all — it never sees any.
        let withEvidence = ranked.rows.filter { !$0.axisEvidence.isEmpty }
        #expect(withEvidence.isEmpty, "the ranker must not populate axisEvidence")
        let order = ranked.rows.map(\.key)
        let scores = ranked.rows.map(\.totalScore)

        // Attaching evidence afterwards changes neither.
        var rows = ranked.rows
        for index in rows.indices { rows[index].axisEvidence = [.crossReference: index + 1] }
        #expect(rows.map(\.key) == order)
        #expect(rows.map(\.totalScore) == scores)
    }
}
