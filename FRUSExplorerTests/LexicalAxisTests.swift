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

// MARK: - LexicalAxisTests

/// The W-17 lexical-similarity axis: the model contract, the pure term-selection
/// arithmetic, the ranker's treatment of its absolute ratio, and the wiring. The store
/// half (column restriction, df ceiling, quoting) is pinned in
/// `FTS5StoreTests/LexicalCandidateQueryTests`.
///
/// Version history:
///   1.0 — W-17 session 2: initial implementation
@Suite("Lexical similarity axis")
struct LexicalAxisTests {

    // MARK: - The model contract

    @Test("The axis is a generator, ships opt-in at weight 0, and says experimental in its name")
    func axisContract() {
        let axis = SimilarityAxis.lexicalSimilarity
        #expect(SimilarityAxis.allCases.contains(axis))
        #expect(axis.isGenerator)
        #expect(axis.defaultWeight == 0)
        #expect(axis.displayName.localizedCaseInsensitiveContains("experimental"),
                "the shared evaluation has not run; the name must say so where the slider is")
    }

    @Test("The rawValue is the persistence token and must not drift")
    func rawValueIsPinned() {
        // The UserDefaults tuning string, the CloudKit-mirrored project override, and the
        // window-restore payload all key on this literal; renaming it ships as a silent
        // weight of 0 for every user who ever moved the slider — and compiles clean.
        #expect(SimilarityAxis.lexicalSimilarity.rawValue == "lexicalSimilarity")
    }

    @Test("A stored tuning that predates the axis reads it at the default 0")
    func storedTuningInheritsTheDefault() throws {
        // #1021 departures-only persistence: an absent axis refills from `defaultWeight`,
        // so no legacy-vector amnesty row is needed for this axis — pin that it holds.
        let stored = try #require(AxisWeights(rawValue: "sharedPersons:1.0"))
        #expect(stored[.lexicalSimilarity] == 0)
        #expect(stored[.sharedPersons] == 1.0)
    }

    // MARK: - Term selection (pure)

    @Test("Word counting folds case, drops stopwords and short words, and counts repeats")
    func wordCounts() {
        let counts = LexicalSimilarityGenerator.wordCounts(
            in: "Containment, CONTAINMENT; the doctrine of containment. War War!",
            stopwords: ["the"])
        #expect(counts["containment"] == 3)
        #expect(counts["doctrine"] == 1)
        #expect(counts["the"] == nil, "stopwords are out")
        #expect(counts["of"] == nil, "three-letter words are below the floor")
        #expect(counts["war"] == nil, "three-letter words are below the floor even when frequent")
    }

    @Test("Hyphens and digits split words rather than joining them")
    func wordBoundaries() {
        let counts = LexicalSimilarityGenerator.wordCounts(
            in: "pan-aircraft battery 1946 telegram7 alliance", stopwords: [])
        #expect(counts["pan"] == nil, "the split fragment is below the four-character floor")
        #expect(counts["aircraft"] == 1, "the hyphen splits; the right half survives on its own")
        #expect(counts["panaircraft"] == nil, "the halves are never joined")
        #expect(counts["telegram"] == 1, "a digit ends the word")
        #expect(counts["alliance"] == 1)
    }

    // MARK: - The ranker's treatment

    @Test("The lexical ratio enters the ranker absolute: kept raw, clamped, never max-normalised")
    func rankerKeepsTheRatioAbsolute() {
        let anchor = DocumentKey(volumeId: "v1", documentId: "d0")
        let weak = DocumentKey(volumeId: "v1", documentId: "d1")
        let over = DocumentKey(volumeId: "v1", documentId: "d2")
        let record = CandidateRecord(header: "h", dateline: nil, documentNumber: nil,
                                     isEditorialNote: false)
        let (rows, _) = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.lexicalSimilarity: [weak: 0.22, over: 1.07]],
            scorerScores: [:],
            records: [weak: record, over: record],
            weights: AxisWeights(weights: [.lexicalSimilarity: 1.0]),
            limit: 10)
        let byKey = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
        // 0.22 stays 0.22 — under max-normalisation it would read 0.22/1.07 ≈ 0.21 only
        // because a stronger neighbour happened to exist, and 1.0 whenever it was alone.
        #expect(byKey[weak]?.axisScores[.lexicalSimilarity] == 0.22)
        // A candidate outscoring the anchor (rarer term repeated harder) clamps to 1.
        #expect(byKey[over]?.axisScores[.lexicalSimilarity] == 1.0)
    }

    // MARK: - The chip

    @Test("A labelled row chips its shared terms; an unlabelled one states the percentage")
    func chipStatesTermsOrPercent() {
        let key = DocumentKey(volumeId: "v1", documentId: "d1")
        let record = CandidateRecord(header: "h", dateline: nil, documentNumber: nil,
                                     isEditorialNote: false)
        var row = RelatedDocumentRow(key: key, record: record, totalScore: 0.8,
                                     axisScores: [.lexicalSimilarity: 0.8])
        // First paint: no render-time terms yet — the percentage is the honest interim.
        #expect(row.whyRelatedChips.first?.chip == .percent(80))
        // After the shared `SemanticSharedTerms` pass writes the label:
        row.axisEvidenceLabel[.lexicalSimilarity] = "Kearsarge\u{1F}Schufeldt"
        #expect(row.whyRelatedChips.first?.chip == .sharedTerms(["Kearsarge", "Schufeldt"]))
    }

    // MARK: - Wiring

    @Test("The generator is registered, and shares the semantic axis's render-time evidence pass")
    func wiring() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let engine = try String(contentsOf: root.appendingPathComponent(
            "FRUSExplorer/RelatedDocuments/RelatedDocumentsEngine.swift"), encoding: .utf8)
        #expect(engine.contains("LexicalSimilarityGenerator()"),
                "an unregistered generator is a whole axis that silently never runs")
        let view = try String(contentsOf: root.appendingPathComponent(
            "FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift"), encoding: .utf8)
        #expect(view.contains("[.semanticSimilarity, .lexicalSimilarity]"),
                "the evidence pass must cover both vocabulary axes, or the lexical chip stays a bare percentage forever")
    }
}
