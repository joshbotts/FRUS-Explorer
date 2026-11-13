// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - KeynessTests

/// Log-likelihood keyness: the arithmetic, the sign, the floor, and the reason an effect size is
/// reported beside the significance.
///
/// The expected values are computed independently (Python, standard G² formulation) rather than
/// read off this implementation, so the suite can disagree with the code.
@Suite("Keyness")
struct KeynessTests {

    private let tolerance = 0.000_01

    @Test("G² matches the standard formulation on independently computed cases")
    func logLikelihoodMatchesReference() throws {
        // a=10 in a 1,000-token scope against b=100 in a 100,000-token reference.
        let scores = Keyness.score(scopeCounts: ["morale": 10], referenceCounts: ["morale": 100],
                                   scopeTotal: 1000, referenceTotal: 100_000)
        let morale = try #require(scores.first)
        #expect(abs(morale.logLikelihood - 27.272535) < tolerance,
                "G² should be 27.272535, got \(morale.logLikelihood)")
        #expect(abs(morale.logRatio - 3.321928) < tolerance,
                "10× over-representation is 2^3.32, got \(morale.logRatio)")
    }

    @Test("Under-representation scores NEGATIVE, so avoidance is not shown as distinctiveness")
    func underuseIsSigned() throws {
        // 2 per 1,000 against 500 per 100,000 — the scope uses this word LESS.
        let scores = Keyness.score(scopeCounts: ["department": 2],
                                   referenceCounts: ["department": 500],
                                   scopeTotal: 1000, referenceTotal: 100_000,
                                   minimumScopeCount: 1)
        let term = try #require(scores.first)
        #expect(abs(term.logLikelihood - -2.316980) < tolerance)
        #expect(!term.isOverused)
        #expect(term.logRatio < 0)
        // Unsigned G² would report this as just as "key" as the same magnitude of over-use, putting
        // the vocabulary a set AVOIDS at the top of a list of what it is about.
    }

    @Test("A term absent from the reference scores, rather than producing NaN or infinity")
    func absentFromReferenceIsFinite() throws {
        let scores = Keyness.score(scopeCounts: ["fifthcolumn": 5], referenceCounts: [:],
                                   scopeTotal: 1000, referenceTotal: 100_000)
        let term = try #require(scores.first)
        #expect(abs(term.logLikelihood - 46.151205) < tolerance)
        #expect(term.logRatio.isFinite,
                "An uncorrected log ratio here is +infinity, which breaks every sort and formatter")
        #expect(abs(term.logRatio - 9.965784) < tolerance)
        #expect(term.referenceCount == 0)
        // This is the case a researcher most wants surfaced — a word the set uses and the corpus
        // does not — so it must rank, not be dropped as a division-by-zero.
    }

    // MARK: The two honesty features

    @Test("The floor keeps a once- or twice-occurring term off the ranking")
    func lowFrequencyFloor() {
        // Nominally significant (G² = 6.48) and 100× over-represented — from ONE occurrence. That is
        // a fact about the corpus being large, not about the documents.
        let counts = ["hapax": 1, "twice": 2, "thrice": 3]
        let reference = ["hapax": 1, "twice": 1, "thrice": 1]
        let scores = Keyness.score(scopeCounts: counts, referenceCounts: reference,
                                   scopeTotal: 1000, referenceTotal: 100_000)
        #expect(scores.map(\.term) == ["thrice"],
                "The default floor is 3: a term appearing twice must not be rankable, per the plan")

        // The floor is a parameter, not a law — a caller studying a tiny set can lower it knowingly.
        let permissive = Keyness.score(scopeCounts: counts, referenceCounts: reference,
                                       scopeTotal: 1000, referenceTotal: 100_000,
                                       minimumScopeCount: 1)
        #expect(permissive.count == 3)
    }

    @Test("G² conflates effect size with sample size, which is why the log ratio is reported too")
    func effectSizeIsIndependentOfSampleSize() throws {
        // Both terms are exactly 100× over-represented. Their G² differs by a factor of FIFTY.
        let small = Keyness.score(scopeCounts: ["a": 1], referenceCounts: ["a": 1],
                                  scopeTotal: 1000, referenceTotal: 100_000, minimumScopeCount: 1)
        let large = Keyness.score(scopeCounts: ["b": 50], referenceCounts: ["b": 50],
                                  scopeTotal: 1000, referenceTotal: 100_000, minimumScopeCount: 1)
        let a = try #require(small.first)
        let b = try #require(large.first)

        #expect(abs(a.logLikelihood - 6.477553) < tolerance)
        #expect(abs(b.logLikelihood - 323.877649) < tolerance)
        #expect(abs(a.logRatio - b.logRatio) < tolerance,
                "Identical over-representation must produce an identical effect size — that is the number a researcher comparing sets of different sizes needs")
        #expect(b.logLikelihood > a.logLikelihood * 40,
                "…while G² differs by ~50×, purely because there is more text")
    }

    // MARK: Ordering and degenerate inputs

    @Test("Ranking is by descending G², and is total")
    func rankingIsDescendingAndTotal() {
        let scope = ["alpha": 10, "beta": 10, "gamma": 30]
        let reference = ["alpha": 5, "beta": 5, "gamma": 5]
        let first = Keyness.score(scopeCounts: scope, referenceCounts: reference,
                                  scopeTotal: 1000, referenceTotal: 100_000)
        #expect(first.first?.term == "gamma", "Most distinctive first")
        // `alpha` and `beta` have identical counts, so identical scores; a Dictionary's iteration
        // order is not stable between runs, so without the term tiebreak this list could reorder
        // between renders of the same data.
        let second = Keyness.score(scopeCounts: scope, referenceCounts: reference,
                                   scopeTotal: 1000, referenceTotal: 100_000)
        #expect(first.map(\.term) == second.map(\.term))
        #expect(first.map(\.term) == ["gamma", "alpha", "beta"])
    }

    @Test("Empty or zero-total inputs yield nothing, not a division by zero")
    func degenerateInputs() {
        #expect(Keyness.score(scopeCounts: [:], referenceCounts: ["a": 1],
                              scopeTotal: 1000, referenceTotal: 1000).isEmpty)
        #expect(Keyness.score(scopeCounts: ["a": 5], referenceCounts: ["a": 1],
                              scopeTotal: 0, referenceTotal: 1000).isEmpty)
        #expect(Keyness.score(scopeCounts: ["a": 5], referenceCounts: ["a": 1],
                              scopeTotal: 1000, referenceTotal: 0).isEmpty)
    }

    // MARK: The pairing check

    @Test("Vocabulary overlap distinguishes a matched baseline from a mismatched one")
    func vocabularyOverlapDetectsMismatch() {
        // The failure this exists to catch: scope counted as NLTagger LEMMAS, baseline as SQLite
        // porter STEMS. The two tokenisations of the same English produce largely different strings,
        // and the resulting keyness would be wrong systematically rather than randomly.
        let lemmas = ["treaty": 10, "alliance": 8, "morale": 5, "security": 12]
        let stems = ["treati": 100, "alli": 80, "moral": 50, "secur": 120]
        #expect(Keyness.vocabularyOverlap(scopeCounts: lemmas, referenceCounts: stems) == 0.0,
                "A mismatched pairing must be detectable before it is divided")

        let matched = ["treaty": 100, "alliance": 80, "morale": 50, "security": 120]
        #expect(Keyness.vocabularyOverlap(scopeCounts: lemmas, referenceCounts: matched) == 1.0)

        #expect(Keyness.vocabularyOverlap(scopeCounts: [:], referenceCounts: matched) == 0.0)
    }
}
