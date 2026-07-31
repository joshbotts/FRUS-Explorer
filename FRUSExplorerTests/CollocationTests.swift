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

// MARK: - CollocationWindowTests

/// The window scan: which words count as "near" a match, and how overlapping neighbourhoods combine.
@Suite("Collocation window")
struct CollocationWindowTests {

    private func scan(_ body: String, _ stems: [String], window: Int = 2) -> CollocationWindow.DocumentScan {
        CollocationWindow.scan(body: body, stems: stems, windowSize: window)
    }

    /// The words a run contributes, for assertions that care about membership rather than spacing.
    private func words(_ scan: CollocationWindow.DocumentScan) -> [String] {
        scan.runs.flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init) }
    }

    @Test("The window is measured in WORDS, not characters")
    func windowIsWords() {
        // KWICBuilder's radius is characters; a measure needs words. With ±2, exactly two words
        // either side survive — regardless of how long they are.
        let result = scan("alpha extraordinarily circumstantial treaty determined subsequent negotiations",
                        ["treati"], window: 2)
        #expect(words(result) == ["extraordinarily", "circumstantial", "determined", "subsequent"],
                "got \(words(result)) — a character radius would cut a different set entirely")
    }

    @Test("The match itself is not one of its own neighbours")
    func anchorIsExcluded() {
        let result = scan("the treaty was signed", ["treati"], window: 5)
        #expect(!words(result).contains("treaty"),
                "a term is not a collocate of itself; leaving the centre in makes every query its own top result")
    }

    @Test("Overlapping windows are merged, so a shared neighbour is counted once")
    func overlapsMerge() {
        // Two matches three words apart with ±5: their windows overlap heavily. `between` sits in
        // both. Counting it twice would inflate it exactly where the query term is densest.
        let result = scan("treaty alpha between beta treaty", ["treati"], window: 5)
        let counted = words(result).filter { $0 == "between" }.count
        #expect(counted == 1, "‘between’ appeared \(counted) times — overlapping windows are double-counting")
        #expect(Set(words(result)) == ["alpha", "between", "beta"])
    }

    @Test("A gap between neighbourhoods starts a new run, so distant prose is never spliced")
    func gapsSplitRuns() {
        // Two matches far apart: the collected text must not read as one continuous passage, or the
        // lemmatiser sees an adjacency the document never contained.
        let filler = Array(repeating: "filler", count: 30).joined(separator: " ")
        let result = scan("treaty alpha \(filler) beta treaty", ["treati"], window: 1)
        #expect(result.runs.count == 2, "got \(result.runs.count) run(s): \(result.runs)")
        #expect(result.runs[0].contains("alpha"))
        #expect(result.runs[1].contains("beta"))
    }

    @Test("Contiguous coverage stays ONE run, carrying the document's own punctuation")
    func contiguousCoverageIsOneRun() {
        let result = scan("the alliance, signed in haste, preceded the treaty", ["treati"], window: 4)
        #expect(result.runs.count == 1)
        #expect(result.runs[0].contains(","),
                "runs are spans of the document's prose — stripping punctuation would hand the lemmatiser a word list")
    }

    @Test("Matches at the edges clamp instead of trapping")
    func edgeMatches() {
        let atStart = scan("Treaty obligations were reviewed", ["treati"], window: 10)
        #expect(words(atStart) == ["obligations", "were", "reviewed"])
        let atEnd = scan("the parties reviewed the treaty", ["treati"], window: 10)
        #expect(words(atEnd) == ["the", "parties", "reviewed", "the"])
    }

    @Test("Matching is by Porter stem, so the words counted are the words the reader sees highlighted")
    func matchesByStem() {
        // `alli`, not `allianc`: the app's Swift PorterStemmer and SQLite's porter unicode61
        // disagree on this word, and the anchor set comes from the Swift one because that is what
        // the highlighter and the concordance use. Using SQLite's stem here finds nothing.
        let hit = scan("their alliances were reaffirmed quickly", ["alli"], window: 1)
        #expect(!hit.runs.isEmpty, "the Swift stem of ‘alliances’ is `alli`; `allianc` is SQLite's and matches nothing here")
        #expect(hit.anchorCount == 1)
        let miss = scan("their alliances were reaffirmed quickly", ["allianc"], window: 1)
        #expect(miss.anchorCount == 0)
    }

    @Test("A word whose stem merely looks similar is not a match")
    func nearMissesAreNotMatches() {
        #expect(scan("the treatment was described", ["treati"]).anchorCount == 0)
    }

    @Test("The per-document match bound is applied and REPORTED")
    func anchorBoundIsReported() {
        let body = Array(repeating: "treaty filler", count: CollocationWindow.maxAnchorsPerDocument + 17)
            .joined(separator: " ")
        let result = scan(body, ["treati"], window: 1)
        #expect(result.anchorCount == CollocationWindow.maxAnchorsPerDocument + 17,
                "the true match count is reported even when the window bound bites")
        #expect(result.omittedAnchorCount == 17,
                "one memo using the term 200+ times would otherwise describe the corpus; the bound has to be visible")
    }

    @Test("Degenerate inputs yield nothing rather than trapping")
    func degenerateInputs() {
        #expect(scan("", ["treati"]).runs.isEmpty)
        #expect(scan("the treaty", []).runs.isEmpty)
        #expect(scan("the treaty", ["treati"], window: 0).runs.isEmpty)
        #expect(scan("treaty", ["treati"], window: 5).runs.isEmpty,
                "a lone match with no neighbours contributes no window")
    }
}

// MARK: - CollocationAnalysisTests

/// Turning window text into a ranking — and refusing to when the two sides are not comparable.
@Suite("Collocation analysis")
struct CollocationAnalysisTests {

    private let reference = (terms: ["treaty": 50_000, "ratify": 400, "government": 20_000,
                                     "commitment": 900],
                             totalTokens: 1_000_000, cutoffCount: 12)

    private func rank(
        _ counts: [String: Int],
        windowTokens: Int = 10_000,
        anchors: Set<String> = [],
        scanned: Int = 40,
        inScope: Int = 40,
        anchorCount: Int = 60,
        omitted: Int = 0
    ) -> CollocationAnalysis.Outcome {
        CollocationAnalysis.rank(
            counts: counts, windowTokenCount: windowTokens, anchorLemmas: anchors,
            windowSize: 10, documentsScanned: scanned, documentsInScope: inScope,
            anchorCount: anchorCount, omittedAnchorCount: omitted,
            reference: reference, generated: "2026-07-27")
    }

    private func result(_ outcome: CollocationAnalysis.Outcome) -> CollocationResult? {
        if case .ranked(let r) = outcome { return r }
        return nil
    }

    @Test("A neighbour concentrated beside the query outranks one that is common everywhere")
    func distinctivenessRanks() throws {
        // `ratify` is rare corpus-wide (400 in a million) and frequent in these windows — 75x
        // over-represented. `government` is mild corpus boilerplate at 1.2x. Both are
        // over-represented, so this is a test of ORDERING, not of filtering.
        let r = try #require(result(rank(["ratify": 300, "government": 250])))
        #expect(r.scores.count == 2, "precondition: both must rank, or this tests filtering")
        #expect(r.scores.first?.term == "ratify",
                "ranked \(r.scores.map(\.term)) — leading with corpus boilerplate is a frequency list")
    }

    @Test("Ranking is by EVIDENCE, and a frequent neighbour can outrank a more concentrated one")
    func rankingIsByEvidenceNotEffect() throws {
        // Not a defect — a documented property of log-likelihood, and the reason a collocation
        // surface must show the effect size rather than the score alone. `government` here is 15x
        // over-represented across 3,000 window tokens; `ratify` is 22x across 90. G² prefers the
        // evidence (10,277 vs 371); the effect size prefers the concentration.
        //
        // Collocation feels this harder than the word cloud did: window corpora are small, so a
        // merely-common word with a modest lift can sit above the word a researcher would call the
        // actual collocate. Whatever ranks the list on screen, BOTH numbers have to be on it.
        let r = try #require(result(rank(["ratify": 90, "government": 3_000])))
        let ratify = try #require(r.scores.first(where: { $0.term == "ratify" }))
        let government = try #require(r.scores.first(where: { $0.term == "government" }))
        #expect(government.logLikelihood > ratify.logLikelihood)
        #expect(ratify.foldOverRepresentation > government.foldOverRepresentation)
        #expect(r.scores.first?.term == "government",
                "the shipped order follows G²; a surface that wants the other order must sort on foldOverRepresentation explicitly")
    }

    @Test("The query's own lemmas are excluded from its collocates")
    func anchorLemmasExcluded() throws {
        // With two matches within 2N words, each falls inside the other's window — so the query term
        // reaches the tally as a legitimate co-occurrence and would top its own list.
        let r = try #require(result(rank(["treaty": 1_500, "ratify": 90], anchors: ["treaty"])))
        #expect(r.scores.map(\.term) == ["ratify"],
                "got \(r.scores.map(\.term)) — at 3x over-represented the anchor is the TOP score, so only the exclusion can remove it")
        // Precondition, stated rather than assumed: without the exclusion `treaty` would rank first.
        let unfiltered = try #require(result(rank(["treaty": 1_500, "ratify": 90])))
        #expect(unfiltered.scores.first?.term == "treaty")
    }

    @Test("The denominator is the window token total, not the sum of the ranked terms")
    func denominatorIsTheWindowTotal() throws {
        let counts = ["ratify": 90, "government": 250]
        let tight = try #require(result(rank(counts, windowTokens: 340)))
        let real = try #require(result(rank(counts, windowTokens: 200_000)))
        let a = try #require(tight.scores.first(where: { $0.term == "ratify" }))
        let b = try #require(real.scores.first(where: { $0.term == "ratify" }))
        #expect(a.logLikelihood != b.logLikelihood,
                "using the sum of the counts would inflate every relative frequency — and unevenly against the reference")
        #expect(real.windowTokenCount == 200_000)
    }

    @Test("Under-represented neighbours are dropped, so the list means one thing")
    func onlyOverRepresented() throws {
        // `government` at 0.05% of the windows against 2% of the corpus is strongly UNDER-used.
        let r = try #require(result(rank(["ratify": 90, "government": 5])))
        #expect(r.scores.map(\.term) == ["ratify"])
    }

    @Test("A neighbourhood too thin to rank says so, rather than showing an empty list")
    func floorReported() {
        #expect(rank(["ratify": 2, "commitment": 1])
                == .unavailable(.noNeighboursAboveFloor(minimum: Keyness.defaultMinimumScopeCount)))
    }

    @Test("No matches is distinct from nothing distinctive")
    func distinctEmptyStates() {
        #expect(rank([:], anchorCount: 0) == .unavailable(.noMatches))
        #expect(rank(["ratify": 90], anchorCount: 0) == .unavailable(.noMatches))
        // Everything present but nothing over-used: a real result about ordinary prose.
        #expect(rank(["government": 5]) == .unavailable(.nothingDistinctive))
    }

    @Test("The bounds travel with the result, so a partial scan can never read as a complete one")
    func boundsTravel() throws {
        let r = try #require(result(rank(["ratify": 90], scanned: 280, inScope: 1_000, omitted: 44)))
        #expect(r.wasBounded)
        #expect(r.documentsScanned == 280)
        #expect(r.documentsInScope == 1_000)
        #expect(r.omittedAnchorCount == 44)
        let whole = try #require(result(rank(["ratify": 90], scanned: 40, inScope: 40)))
        #expect(!whole.wasBounded)
    }

    @Test("The reference's unpriced cutoff travels too")
    func cutoffTravels() throws {
        let r = try #require(result(rank(["ratify": 90])))
        #expect(r.referenceCutoffCount == 12,
                "without it the view cannot distinguish a word the corpus never used from one it never priced")
        #expect(r.generated == "2026-07-27")
    }
}

// MARK: - CollocationVocabularyPairingTests

/// The guard against the failure this feature is most likely to have: counting the neighbours in one
/// vocabulary and pricing them in another.
///
/// Three tokenisations meet in collocation — SQLite `porter unicode61` chose the documents, the app's
/// Swift `PorterStemmer` finds the match, and the neighbours must be **NLTagger lemmas** to be
/// priceable against the bundled reference. Landing the neighbours in stem space instead compiles,
/// runs, and produces a confident ranking in which almost nothing is found in the reference — so
/// every term scores as unique to the scope. `Keyness.vocabularyOverlap` exists to catch exactly
/// that, and this suite points it at the shipped artifact.
@Suite("Collocation vocabulary pairing")
struct CollocationVocabularyPairingTests {

    /// Decodes the shipped reference straight from the bundle.
    ///
    /// Deliberately NOT through ``BundledKeynessBaseline``: that type holds one static that
    /// `BundledKeynessBaselineTests` injects fixtures into, and a suite reading it in the same test
    /// run sees whatever the other suite last injected. These two cases passed in isolation and
    /// failed in the full suite for exactly that reason — the artifact is the fixed point, the
    /// loader is not.
    private func referenceTerms() throws -> [String: Int] {
        let url = try #require(Bundle.main.url(forResource: "keyness-baseline", withExtension: "json"))
        let file = try JSONDecoder().decode(KeynessBaselineFile.self, from: Data(contentsOf: url))
        return try #require(file.lenses[WordCloudLens.allTerms.rawValue]).terms
    }

    /// Ordinary FRUS-register prose, of the kind a window would actually collect.
    private let passage = """
    The Secretary said that the proposed treaty would commit the United States to consult its \
    partners before any decision affecting the security of Western Europe, and that the Senate \
    would expect the commitment to be discharged through constitutional processes rather than \
    by automatic obligation. The Ambassador replied that his government sought a guarantee of \
    military assistance, and that anything less would be read in Paris as a withdrawal of \
    American support for the defense of the continent.
    """

    @Test("Neighbours counted the app's way are found in the corpus reference")
    @MainActor
    func lemmaCountsPairWithTheBaseline() throws {
        let reference = try referenceTerms()
        // The SAME construction the word cloud counts with, which is what the reference was built by.
        let tokenizer = WordCloudTokenizer.configured(
            tuning: .standard, lens: .allTerms, includeDiplomatic: true)
        var counts: [String: Int] = [:]
        let total = tokenizer.accumulate(from: passage, into: &counts)

        #expect(total > 20, "the passage produced only \(total) surviving tokens")
        let overlap = Keyness.vocabularyOverlap(scopeCounts: counts, referenceCounts: reference)
        #expect(overlap > 0.8,
                "only \(overlap) of these neighbours are priced by the reference — the signature of counting in the wrong vocabulary, not of a rare passage")
    }

    @Test("Counting the neighbours as Porter stems instead would be caught")
    func stemCountsWouldFailThePairing() throws {
        let reference = try referenceTerms()
        // The plausible wrong turn: the anchor IS found by Porter stem, so a reader might reasonably
        // count the neighbours the same way. This asserts the guard would notice.
        var stems: [String: Int] = [:]
        for word in passage.split(whereSeparator: { !$0.isLetter }) where word.count >= 3 {
            stems[PorterStemmer.stem(word.lowercased()), default: 0] += 1
        }
        let overlap = Keyness.vocabularyOverlap(scopeCounts: stems, referenceCounts: reference)
        #expect(overlap < 0.8,
                "Porter stems scored \(overlap) against a lemma reference — if this ever rises, the guard in the sibling test has stopped discriminating and both are vacuous")
    }
}
