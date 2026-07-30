// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import WordCloudKit

/// Decision **O-1-2**: one `NLTagger` pass with N accumulators, instead of one pass per lens.
///
/// The merge is only sound if it is a refactor rather than an approximation, and the claim
/// that it *is* one rests on an assumption about a closed-source framework: that requesting
/// `.lexicalClass` alongside `.lemma` does not perturb the lemma. **This suite is what makes
/// the optimisation safe to take** — it runs `WordCloudMultiLensTokenizer` and four separate
/// `WordCloudTokenizer`s over the same text and requires term-for-term, count-for-count
/// agreement.
///
/// If it ever fails on the lexicon lenses only, the assumption broke, and the fallback is two
/// passes (lexicon lenses together, POS lenses together) rather than four — still a 2× saving.
///
/// Version history:
///   1.0 — O-1: initial implementation
@Suite("WordCloudKit — one-pass / four-pass parity (O-1-2)")
struct WordCloudMultiLensParityTests {

    // MARK: - Fixtures

    /// Prose with enough shape to exercise every filter: nouns, verbs, adjectives,
    /// lexicon hits, plurals for the fold, a marking, a stopword, digits, and a hyphenate.
    private static let diplomaticProse = """
    The Secretary of State negotiated the treaty in Geneva, and the delegations \
    considered several proposals concerning sovereignty and security. Top Secret \
    telegrams described the crisis as dangerous, while the Ambassador urged \
    restraint. Peace depends on mutual deterrence and on the legitimacy of the \
    settlement; treaties signed in 1954 established the framework. The committee \
    reviewed 27 documents and recommended that the government accept the agreement, \
    though hostility persisted and negotiations nearly collapsed.
    """

    /// A second passage with different vocabulary, so a single lucky text cannot carry
    /// the suite.
    private static let economicProse = """
    Economic assistance programs expanded rapidly. The Bank approved loans, and \
    officials debated whether aid strengthened cooperation or produced dependence. \
    Trade agreements reduced tariffs; exports grew while deficits worsened. \
    Confidential memoranda warned that instability threatened the alliance, but \
    prosperity and confidence returned after the currencies stabilised.
    """

    private static let stopwords: Set<String> = [
        "the", "of", "and", "in", "that", "as", "on", "or", "but", "while",
        "several", "though", "after", "whether", "nearly"
    ]

    private static let markings: Set<String> = ["top secret", "secret", "confidential"]

    private static let lexicons = WordCloudLexiconSet(payload: .init(
        concepts: [
            "sovereignty", "security", "deterrence", "legitimacy", "settlement",
            "cooperation", "dependence", "prosperity", "instability", "alliance",
            "restraint", "framework", "confidence"
        ],
        sentimentPositive: ["peace", "prosperity", "confidence", "agreement", "cooperation"],
        sentimentNegative: ["crisis", "dangerous", "hostility", "instability", "deficit"]
    ))

    /// The four lenses the bundled cloud vectors carry.
    /// Every lens the one-pass tokenizer is asked for in production — which since S-1 is not just
    /// the four the cloud draws. `.allTerms` and `.descriptors` are gathered for the keyness
    /// baseline, and `.allTerms` is the one whose parity matters MOST: it is the app's default lens,
    /// and the app counts it through the SINGLE-lens tokenizer, which builds its tagger with
    /// `[.lemma]` while the multi-lens one adds `.lexicalClass`. That asymmetry is exactly what this
    /// suite exists to pin, and leaving the default lens out of it left the keyness reference for
    /// the default screen unpinned.
    private static let lenses = [WordCloudLens.allTerms, .descriptors]
        + WordCloudLens.bundledCloudLenses

    // MARK: - Helpers

    /// Counts each lens with its own tokenizer — the pre-O-1 behaviour, four passes.
    private func fourPass(_ texts: [String], tuning: WordCloudTuning) -> [WordCloudLens: [String: Int]] {
        var result: [WordCloudLens: [String: Int]] = [:]
        for lens in Self.lenses {
            var counts: [String: Int] = [:]
            let tokenizer = WordCloudTokenizer(
                stopwords: Self.stopwords,
                minimumLength: tuning.minimumLength,
                foldPlurals: tuning.foldPlurals,
                lens: lens,
                lexicon: Self.lexicons.filter(for: lens),
                markings: tuning.filterMarkings ? Self.markings : []
            )
            for text in texts { tokenizer.accumulate(from: text, into: &counts) }
            if !counts.isEmpty { result[lens] = counts }
        }
        return result
    }

    /// Counts every lens from one pass — the O-1-2 behaviour.
    private func onePass(_ texts: [String], tuning: WordCloudTuning) throws -> [WordCloudLens: [String: Int]] {
        let tokenizer = try #require(WordCloudMultiLensTokenizer(
            lenses: Self.lenses,
            tuning: tuning,
            stopwords: Self.stopwords,
            lexicons: Self.lexicons,
            markings: tuning.filterMarkings ? Self.markings : []
        ))
        var counts: [WordCloudLens: [String: Int]] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts) }
        return counts
    }

    /// Asserts the two paths agree exactly, reporting the first divergence per lens.
    private func expectParity(_ texts: [String], tuning: WordCloudTuning = .standard) throws {
        let expected = fourPass(texts, tuning: tuning)
        let actual = try onePass(texts, tuning: tuning)

        #expect(Set(expected.keys) == Set(actual.keys), "lens sets differ")
        for lens in Set(expected.keys).union(actual.keys) {
            let lhs = expected[lens] ?? [:]
            let rhs = actual[lens] ?? [:]
            #expect(lhs == rhs, """
                \(lens.rawValue): one-pass diverged from four-pass.
                  only in four-pass: \(lhs.filter { rhs[$0.key] != $0.value })
                  only in one-pass:  \(rhs.filter { lhs[$0.key] != $0.value })
                """)
        }
    }

    // MARK: - Parity

    @Test("One pass equals four passes on diplomatic prose")
    func parityDiplomatic() throws {
        try expectParity([Self.diplomaticProse])
    }

    @Test("One pass equals four passes on economic prose")
    func parityEconomic() throws {
        try expectParity([Self.economicProse])
    }

    @Test("Parity holds when many documents fold into one running tally")
    func parityAcrossAccumulatedDocuments() throws {
        // The generator accumulates a whole volume document by document; this is that
        // shape, and it also catches an accumulator reset bug a single-text test misses.
        try expectParity([Self.diplomaticProse, Self.economicProse, Self.diplomaticProse])
    }

    @Test("Parity survives non-default tuning")
    func parityUnderAlternativeTuning() throws {
        // The bundled vectors ship under `.standard`, but the merged path must not be
        // correct only there — a wrong `minimumLength` or fold would show up here first.
        try expectParity([Self.diplomaticProse, Self.economicProse],
                         tuning: WordCloudTuning(minimumLength: 5, foldPlurals: false))
        try expectParity([Self.diplomaticProse],
                         tuning: WordCloudTuning(minimumLength: 3, filterMarkings: false))
    }

    @Test("Parity holds for a lexicon-only request, which asks for no lexical class at all")
    func parityLexiconLensesOnly() throws {
        // This is the case the framework assumption bears on: with no POS lens present the
        // merged path requests `[.lemma]` only, exactly as a single-lens run does.
        let lensSubset: [WordCloudLens] = [.concepts, .sentiment]
        var expected: [WordCloudLens: [String: Int]] = [:]
        for lens in lensSubset {
            var counts: [String: Int] = [:]
            WordCloudTokenizer(
                stopwords: Self.stopwords, minimumLength: 3, foldPlurals: true,
                lens: lens, lexicon: Self.lexicons.filter(for: lens), markings: Self.markings
            ).accumulate(from: Self.diplomaticProse, into: &counts)
            if !counts.isEmpty { expected[lens] = counts }
        }
        let tokenizer = try #require(WordCloudMultiLensTokenizer(
            lenses: lensSubset, tuning: .standard, stopwords: Self.stopwords,
            lexicons: Self.lexicons, markings: Self.markings
        ))
        var actual: [WordCloudLens: [String: Int]] = [:]
        tokenizer.accumulate(from: Self.diplomaticProse, into: &actual)
        #expect(expected == actual)
    }

    // MARK: - The suite must not be vacuous

    @Test("The fixtures actually produce counts in all four lenses")
    func fixturesAreNotEmpty() throws {
        // Every parity assertion above compares two dictionaries. Two empty dictionaries
        // are equal, so without this the whole suite could pass against a tokenizer that
        // counted nothing at all.
        let counts = try onePass([Self.diplomaticProse, Self.economicProse], tuning: .standard)
        for lens in Self.lenses {
            let terms = counts[lens] ?? [:]
            #expect(!terms.isEmpty, "\(lens.rawValue) produced no terms — parity would be vacuous")
        }
        // And the lenses must not all be counting the same thing.
        #expect(counts[.concepts] != counts[.topics])
        #expect(counts[.topics] != counts[.actions])
    }

    // MARK: - Contract

    @Test("Entity lenses are refused rather than silently counted as zero")
    func rejectsEntityLenses() {
        #expect(WordCloudMultiLensTokenizer(
            lenses: [.topics, .people], tuning: .standard,
            stopwords: [], lexicons: .empty, markings: []) == nil)
        #expect(WordCloudMultiLensTokenizer(
            lenses: [], tuning: .standard,
            stopwords: [], lexicons: .empty, markings: []) == nil)
    }

    @Test("Duplicate lenses collapse, preserving first-occurrence order")
    func collapsesDuplicateLenses() throws {
        let tokenizer = try #require(WordCloudMultiLensTokenizer(
            lenses: [.topics, .concepts, .topics], tuning: .standard,
            stopwords: [], lexicons: Self.lexicons, markings: []))
        #expect(tokenizer.lenses == [.topics, .concepts])

        // A collapsed duplicate must not double-count.
        var counts: [WordCloudLens: [String: Int]] = [:]
        tokenizer.accumulate(from: Self.diplomaticProse, into: &counts)
        var single: [String: Int] = [:]
        WordCloudTokenizer(stopwords: [], minimumLength: 3, foldPlurals: true,
                           lens: .topics, lexicon: nil, markings: [])
            .accumulate(from: Self.diplomaticProse, into: &single)
        #expect(counts[.topics] == single)
    }
}
