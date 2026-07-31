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

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - KeynessCloudTests

/// Turning a computed cloud into a keyness ranking — and refusing to, when the two sides are not
/// comparable.
///
/// `.serialized` because every case injects into ``BundledKeynessBaseline``'s shared static.
@Suite("Keyness cloud", .serialized)
@MainActor
struct KeynessCloudTests {

    private static let lexicons = "lex-digest"
    private static let stopwords = "stop-digest"

    /// A reference where `treaty` is ordinary corpus vocabulary and `quemoy` is rare.
    private func injectReference(
        _ terms: [String: Int] = ["treaty": 50_000, "quemoy": 40, "government": 200_000],
        totalTokens: Int = 1_000_000,
        cutoffCount: Int = 12,
        tuning: WordCloudTuning = .standard,
        includeDiplomatic: Bool = true,
        distinctTerms: Int = 250_000
    ) {
        let file = KeynessBaselineFile(
            version: 1, generated: "2026-07-27",
            provenance: .init(volumeCount: 552, documentCount: 314_479,
                              tuning: .standard, topTermsPerList: 50),
            termsPerLens: 20_000,
            configuration: .init(tuning: tuning, includeDiplomatic: includeDiplomatic,
                                 lexiconsDigest: Self.lexicons, stopwordsDigest: Self.stopwords),
            lenses: [WordCloudLens.allTerms.rawValue: .init(
                totalTokens: totalTokens, distinctTerms: distinctTerms,
                terms: terms, cutoffCount: cutoffCount)])
        BundledKeynessBaseline.injectForTesting(
            file, digests: (lexicons: Self.lexicons, stopwords: Self.stopwords))
    }

    private func rank(
        _ terms: [(String, Int)],
        scopeTotal: Int = 10_000,
        fetchedTermCount: Int? = nil,
        termLimit: Int = 220,
        lens: WordCloudLens = .allTerms,
        tuning: WordCloudTuning = .standard,
        includeDiplomatic: Bool = true
    ) -> KeynessCloud.Outcome {
        KeynessCloud.rank(terms: terms.map { TermCount(term: $0.0, count: $0.1) },
                          scopeTotal: scopeTotal,
                          fetchedTermCount: fetchedTermCount ?? terms.count,
                          termLimit: termLimit, lens: lens,
                          tuning: tuning, includeDiplomatic: includeDiplomatic)
    }

    private func ranking(_ outcome: KeynessCloud.Outcome) -> KeynessCloud.Ranking? {
        if case .ranked(let r) = outcome { return r }
        return nil
    }

    // MARK: - The measure

    @Test("A word rare corpus-wide but common here outranks a word that is common everywhere")
    func distinctivenessBeatsFrequency() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // BOTH terms must survive the over-representation filter, or this proves nothing about
        // ORDERING: the first version scored `treaty` at 3% of a scope against 5% of the reference,
        // so it was dropped as under-represented and "quemoy first" held trivially, in a list of one.
        //
        // Here `treaty` is 12% of the scope against 5% corpus-wide — genuinely over-represented, and
        // five times more frequent in the scope than `quemoy`, so a frequency cloud puts it first.
        // `quemoy` is 6% of the scope against 0.004% corpus-wide. If keyness cannot reverse that
        // pair it is not doing anything.
        let r = try #require(ranking(rank([("treaty", 1_200), ("quemoy", 600)])))
        #expect(r.scores.count == 2,
                "precondition: both terms must be ranked, or this tests filtering rather than ordering — got \(r.scores.map(\.term))")
        #expect(r.scores.first?.term == "quemoy",
                "ranked \(r.scores.map(\.term)) — a keyness list that leads with the corpus's own common vocabulary is a frequency list")
    }

    @Test("Under-represented words are excluded, because a size ranking cannot carry a sign")
    func onlyOverRepresented() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // `government` is 20% of the reference and 0.3% of this scope — strongly UNDER-represented.
        let r = try #require(ranking(rank([("quemoy", 60), ("government", 30)])))
        #expect(r.scores.map(\.term) == ["quemoy"])
        let allOverused = r.scores.filter { !$0.isOverused }.isEmpty
        #expect(allOverused)
    }

    @Test("The scope denominator is the TRUE total, not the sum of the listed terms")
    func usesTrueScopeTotal() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let terms = [("quemoy", 60), ("treaty", 300)]
        let tight = try #require(ranking(rank(terms, scopeTotal: 360)))
        let true_ = try #require(ranking(rank(terms, scopeTotal: 100_000)))
        // Same counts, different denominators, materially different scores. If the caller passed the
        // sum of the terms instead of WordCloudResult.totalTokenCount, every relative frequency
        // would be inflated — and inflated unevenly against the reference.
        let a = try #require(tight.scores.first(where: { $0.term == "quemoy" }))
        let b = try #require(true_.scores.first(where: { $0.term == "quemoy" }))
        #expect(a.logLikelihood != b.logLikelihood)
    }

    @Test("The low-frequency floor keeps a one-mention word off the top")
    func floorApplies() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let r = try #require(ranking(rank([("quemoy", 60), ("kamchatka", 2)])))
        let terms = r.scores.map(\.term)
        #expect(!terms.contains("kamchatka"),
                "a word appearing twice can top a keyness ranking without saying anything about the documents")
        #expect(r.minimumScopeCount == Keyness.defaultMinimumScopeCount)
    }

    @Test("A scope with nothing above the floor reports that, rather than an empty ranking")
    func nothingAboveFloor() {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        #expect(rank([("a", 1), ("b", 2)])
                == .unavailable(.noTermsAboveFloor(minimum: Keyness.defaultMinimumScopeCount)))
    }

    @Test("A scope whose every word is typical reports that, and it is not an error")
    func nothingDistinctive() {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // Only under-represented terms survive the floor.
        #expect(rank([("government", 10)]) == .unavailable(.nothingOverRepresented))
    }

    // MARK: - Honest disclosure

    @Test("Truncation is DETECTED, not assumed — the caveat is true either way")
    func truncationIsComputed() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // Fewer terms than the limit: the scope simply ran out, so the ranking is complete.
        let complete = try #require(ranking(rank([("quemoy", 60), ("treaty", 300)], termLimit: 220)))
        #expect(!complete.rankedAmongTopFrequent)
        // Exactly the limit: the frequency cut is what bounded the candidates.
        let truncated = try #require(ranking(rank([("quemoy", 60), ("treaty", 300)], termLimit: 2)))
        #expect(truncated.rankedAmongTopFrequent,
                "a cloud that returned exactly its limit was cut short, and a caveat claiming completeness would be false")
        #expect(truncated.candidateCount == 2)
    }

    @Test("Hiding one word does not turn a truncated fetch into a claim of completeness")
    func sessionHideDoesNotFlipTheCaveat() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // The cloud fetched its full limit and the user then hid one word from this cloud, so the
        // list handed to `rank` is one short. Judging truncation from THAT would flip the caveat to
        // "ranked over every word occurring at least 3 times here" — false, and unfalsifiable by a
        // reader.
        let r = try #require(ranking(rank([("quemoy", 60), ("treaty", 300)],
                                          fetchedTermCount: 220, termLimit: 220)))
        #expect(r.rankedAmongTopFrequent,
                "a fetch that hit its limit is truncated no matter how many words were hidden afterwards")
    }

    @Test("An unpriced term is distinguishable from one the corpus never used")
    func unpricedIsNotUnused() throws {
        injectReference(cutoffCount: 110)
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // `matsu` is absent from the reference — but the reference only prices words occurring 110+
        // times corpus-wide, so its absence means "rarer than 110", not "never used". It is also
        // exactly the row a high keyness score floats to the top.
        let r = try #require(ranking(rank([("matsu", 40)])))
        let score = try #require(r.scores.first)
        #expect(score.referenceCount == 0)
        #expect(r.isUnpriced(score),
                "a bare '0 corpus-wide' would assert something the truncated reference cannot support")
        // With a cutoff of 1 nothing is truncated, so a zero really does mean unused.
        BundledKeynessBaseline.injectForTesting(nil)
        injectReference(cutoffCount: 1)
        let complete = try #require(ranking(rank([("matsu", 40)])))
        let completeScore = try #require(complete.scores.first)
        #expect(!complete.isUnpriced(completeScore))
    }

    @Test("candidateCount reports what was SCORED, not what was handed in")
    func candidateCountExcludesFlooredTerms() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // Three terms in, one below the floor: a candidateCount echoing the input would overstate
        // the ranking's reach in the caveat the user reads.
        let r = try #require(ranking(rank([("quemoy", 60), ("treaty", 300), ("kamchatka", 1)])))
        #expect(r.candidateCount == 2)
    }

    @Test("The reference's coverage travels with the ranking, so the view can disclose it")
    func coverageTravels() throws {
        injectReference(cutoffCount: 110, distinctTerms: 254_027)
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let r = try #require(ranking(rank([("quemoy", 60)])))
        #expect(r.referenceCutoffCount == 110,
                "without the cutoff a view cannot distinguish UNPRICED from absent-from-the-corpus")
        #expect(r.referenceDistinct == 254_027)
        #expect(r.referenceRetained == 3)
        #expect(r.generated == "2026-07-27")
    }

    // MARK: - Refusing to compare

    @Test("No artifact means no ranking — never a ranking against nothing")
    func noArtifact() {
        BundledKeynessBaseline.injectForTesting(nil)
        #expect(rank([("quemoy", 60)]) == .unavailable(.noArtifact))
    }

    @Test("An unpriced lens is reported as such, not silently scored against an empty reference")
    func lensNotPriced() {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        #expect(rank([("kennedy", 60)], lens: .people) == .unavailable(.lensNotPriced(.people)))
    }

    @Test("Turning boilerplate exclusion off blocks the comparison")
    func boilerplateMismatchBlocks() {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // The one-tap case from the cloud's own Options menu. With the layer off the scope fills
        // with department/telegram/washington at reference count zero, which keyness would rank as
        // the corpus's most distinctive vocabulary.
        #expect(rank([("quemoy", 60)], includeDiplomatic: false)
                == .unavailable(.configurationMismatch([.diplomaticLayer])))
    }

    @Test("Settings that only shrink the scope are still comparable")
    func shrinkingSettingsAllowed() {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        // A longer minimum length and a higher minimum count remove terms from the scope; every term
        // that survives still has a reference. Refusing these would withhold keyness from a user
        // whose settings cost nothing.
        for tuning in [WordCloudTuning(minimumLength: 5), WordCloudTuning(minimumCount: 9)] {
            if case .unavailable(let reason) = rank([("quemoy", 60)], tuning: tuning) {
                Issue.record("\(tuning) should not block keyness — got \(reason)")
            }
        }
    }

    // MARK: - Layout input

    @Test("The effect size is carried alongside G², and they can disagree about rank")
    func effectSizeIsIndependentOfSignificance() throws {
        // REAL figures, not invented ones: the scope and reference counts below are what
        // `FRUS, The Conference of Berlin (Potsdam), 1945, Vol. II` and the shipped
        // keyness-baseline.json actually contain. A first attempt at a synthetic fixture put both
        // rankings the same way round, and this test's own precondition caught it.
        //
        // `reparation` ranks 3rd on G² and `babelsberg` 5th — but babelsberg is 320x
        // over-represented against reparation's 25x. Ranked on evidence they go one way; ranked on
        // effect they go the other. A reader shown only the score would take reparation to be the
        // stronger finding, when babelsberg is the word that is almost unique to this volume.
        injectReference(["reparation": 21_314, "babelsberg": 507], totalTokens: 94_622_813)
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let r = try #require(ranking(rank([("reparation", 1_423), ("babelsberg", 429)],
                                          scopeTotal: 250_418)))
        let common = try #require(r.scores.first(where: { $0.term == "reparation" }))
        let rare = try #require(r.scores.first(where: { $0.term == "babelsberg" }))
        #expect(common.logLikelihood > rare.logLikelihood,
                "precondition: G² must favour the higher-volume term, or this proves nothing")
        #expect(rare.logRatio > common.logRatio,
                "…while the effect size favours the more concentrated one — which is why both are shown")
        // ~25x vs ~320x — the numbers the row actually renders, via the property it renders them
        // from. Printing `logRatio` itself would show "4.7x" and "8.3x": a 13-fold understatement of
        // the gap, on a screen where nothing would look wrong.
        #expect(common.foldOverRepresentation > 20 && common.foldOverRepresentation < 30)
        #expect(rare.foldOverRepresentation > 250 && rare.foldOverRepresentation < 400)
        #expect(rare.foldOverRepresentation / common.foldOverRepresentation > 10,
                "the effect sizes must differ by an order of magnitude, or the fold conversion is not doing its job")
    }

    @Test("A term absent from the reference gets a finite effect size, not an infinity")
    func absentTermHasFiniteEffectSize() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let r = try #require(ranking(rank([("matsu", 40)])))
        let score = try #require(r.scores.first)
        // The +0.5 continuity correction. Without it the ratio is log2(x/0) = infinity, which the
        // fold conversion would render as "inf× more often here" and which breaks every sort.
        #expect(score.referenceCount == 0)
        #expect(score.logRatio.isFinite)
        #expect(score.foldOverRepresentation.isFinite,
                "an infinite multiple would render as \"inf× more often here\"")
    }

    @Test("Layout counts are positive and preserve the ranking's order")
    func layoutTermsArePositiveAndOrdered() throws {
        injectReference()
        defer { BundledKeynessBaseline.injectForTesting(nil) }
        let r = try #require(ranking(rank([("quemoy", 60), ("treaty", 300)])))
        let layout = KeynessCloud.layoutTerms(r.scores)
        // WordCloudLayout.place returns NOTHING when the largest count is <= 0, and normalises over
        // Ints — a signed Double handed to it directly would empty the cloud.
        let counts = layout.map(\.count)
        let smallest = counts.min() ?? 0
        let descending = counts.sorted().reversed().map { $0 }
        #expect(smallest > 0)
        #expect(layout.map(\.term) == r.scores.map(\.term))
        #expect(counts == descending)
    }

    @Test("A tiny positive score still yields a drawable word")
    func tinyScoresSurviveTheIntConversion() {
        let score = KeynessScore(term: "x", scopeCount: 3, referenceCount: 3,
                                 logLikelihood: 0.0001, logRatio: 0.1)
        // Rounding to Int would give 0, and a 0 as the LARGEST count empties the whole cloud.
        #expect(KeynessCloud.layoutTerms([score]).first?.count == 1)
    }
}
