// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SemanticVectorsKit

/// The edition-twin rule (V-3 requirement, first implemented in V-5 s3): the real corpus pairs,
/// the fold's first-wins ordering, and the ids that must NOT fold.
@Suite("Semantic edition twins")
struct SemanticEditionTwinsTests {

    @Test("The real corpus pairs fold to one base id")
    func realPairsFold() {
        #expect(SemanticEditionTwins.baseVolumeID("frus1951-54Iran") == "frus1951-54Iran")
        #expect(SemanticEditionTwins.baseVolumeID("frus1951-54IranEd2") == "frus1951-54Iran")
        #expect(SemanticEditionTwins.baseVolumeID("frus1969-76ve15p2Ed2") == "frus1969-76ve15p2")
        #expect(SemanticEditionTwins.areTwins("frus1951-54Iran", "frus1951-54IranEd2"))
        #expect(SemanticEditionTwins.areTwins("frus1951-54IranEd2", "frus1951-54IranEd2"),
                "a volume is trivially its own twin — callers rely on this for anchor folding")
    }

    @Test("Ordinary ids do not fold into each other")
    func ordinaryIDsUntouched() {
        #expect(SemanticEditionTwins.baseVolumeID("frus1895p1") == "frus1895p1")
        #expect(!SemanticEditionTwins.areTwins("frus1895p1", "frus1895p2"))
        // The marker is a SUFFIX: an 'Ed2' elsewhere in an id must not trigger the rule.
        #expect(SemanticEditionTwins.baseVolumeID("frusEd2xyz") == "frusEd2xyz")
    }

    @Test("Folding keeps the FIRST occurrence — the better-scored edition of a ranked list")
    func foldingIsFirstWins() {
        let ranked: [(volume: String, document: String, score: Double)] = [
            ("frus1951-54IranEd2", "d166", 0.99),
            ("frus1951-54Iran", "d166", 0.98),      // the twin — folded
            ("frus1951-54Iran", "d167", 0.90),      // different document — kept
            ("frus1895p1", "d527", 0.80),
            ("frus1951-54IranEd2", "d167", 0.70),   // twin of the kept d167 — folded
        ]
        let folded = SemanticEditionTwins.foldingTwins(ranked) { ($0.volume, $0.document) }
        #expect(folded.map(\.score) == [0.99, 0.90, 0.80])
        #expect(folded.first?.volume == "frus1951-54IranEd2",
                "first-wins must keep the better-scored edition, not prefer an edition by name")
    }

    @Test("The fold key is one definition for both the batch fold and streaming callers")
    func foldKeyMatchesBatchFold() {
        #expect(SemanticEditionTwins.foldKey(volumeID: "frus1951-54IranEd2", documentID: "d166")
            == SemanticEditionTwins.foldKey(volumeID: "frus1951-54Iran", documentID: "d166"))
        #expect(SemanticEditionTwins.foldKey(volumeID: "frus1951-54Iran", documentID: "d166")
            != SemanticEditionTwins.foldKey(volumeID: "frus1951-54Iran", documentID: "d167"))
    }
}
