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
import NaturalLanguage
@testable import WordCloudKit

/// The printed-form count (#1608): what a `.printed` tokenizer counts, and that the generator's one
/// pass counts the same thing.
///
/// The fallback is exact only if three counts agree, and each is made by different code:
///
/// 1. **the device's**, a single-lens `WordCloudTokenizer` told `.printed`, which asks for a tagger
///    with no lemma scheme and walks it by `.tokenType`;
/// 2. **the direct multi-lens walk**, `WordCloudMultiLensTokenizer` told `.printed`, which the
///    generator's `VERIFY_PRINTED_WALK=1` run makes over every document of the corpus;
/// 3. **the one-pass tally**, `accumulate(from:into:printedInto:)`, which derives the printed form
///    of each token inside the `.lemma` walk and is what the shipped reference is written from.
///
/// 1 = 2 = 3 here, lens for lens and count for count, and the dictionary tally of the one pass is
/// the tally of the single-form pass, so counting printed forms alongside changes nothing the
/// existing reference is written from. `WordCloudMultiLensParityTests` is untouched: this suite adds
/// to that guard and does not stand in for it.
///
/// These run on the macOS host, whose lemmatiser works, which is what makes the difference between
/// the two forms visible; ``theTwoFormsDifferHere()`` requires it.
///
/// Version history:
///   1.0 — #1608: initial implementation
@Suite("WordCloudKit — printed forms: the device's count, the direct walk and the one pass (#1608)")
struct WordCloudPrintedFormParityTests {

    // MARK: - Fixtures

    /// Prose with something for every rule that separates the two forms: inflected verbs the fold
    /// leaves alone, regular plurals it folds, an irregular plural, a name that ends in s, a
    /// stopword's inflection, lexicon hits in base and plural form, a marking, digits, a hyphenate.
    private static let diplomaticProse = """
    The Secretary of State negotiated the treaty in Geneva, and the delegations \
    considered several proposals concerning sovereignty and security. Top Secret \
    telegrams described the crises as dangerous, while Dulles and the Ambassador urged \
    restraint. The men said that peace depends on mutual deterrence and on the legitimacy \
    of the settlements; treaties signed in 1954 established the framework. The committee \
    reviewed 27 documents and recommended that the governments accept the agreements, \
    though hostility persisted and the negotiating parties nearly collapsed. He says so.
    """

    /// A second passage with different vocabulary, so one lucky text cannot carry the suite.
    private static let economicProse = """
    Economic assistance programs expanded rapidly. The Bank approved loans, and \
    officials debated whether aid strengthened cooperation or produced dependence. \
    Trade agreements reduced tariffs; exports grew while deficits worsened. \
    Confidential memoranda warned that instability threatened the alliances, but \
    prosperity and confidence returned after the currencies stabilised. Rogers agreed.
    """

    private static let stopwords: Set<String> = [
        "the", "of", "and", "in", "that", "as", "on", "or", "but", "while",
        "several", "though", "after", "whether", "nearly", "say", "so", "he"
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

    /// Every lens the generator counts, as `WordCloudMultiLensParityTests` lists them.
    private static let lenses = [WordCloudLens.allTerms, .descriptors] + WordCloudLens.bundledCloudLenses

    // MARK: - Helpers

    private func multiLens(_ tuning: WordCloudTuning,
                           wordForm: WordCloudWordForm) throws -> WordCloudMultiLensTokenizer {
        try #require(WordCloudMultiLensTokenizer(
            lenses: Self.lenses, tuning: tuning, stopwords: Self.stopwords, lexicons: Self.lexicons,
            markings: tuning.filterMarkings ? Self.markings : [], wordForm: wordForm))
    }

    /// Count 1: each lens through its own `.printed` single-lens tokenizer, as the app counts it.
    private func devicePrinted(_ texts: [String], tuning: WordCloudTuning) -> [WordCloudLens: [String: Int]] {
        var result: [WordCloudLens: [String: Int]] = [:]
        for lens in Self.lenses {
            var counts: [String: Int] = [:]
            let tokenizer = WordCloudTokenizer(
                stopwords: Self.stopwords, minimumLength: tuning.minimumLength,
                foldPlurals: tuning.foldPlurals, lens: lens, lexicon: Self.lexicons.filter(for: lens),
                markings: tuning.filterMarkings ? Self.markings : [], wordForm: .printed)
            for text in texts { tokenizer.accumulate(from: text, into: &counts) }
            if !counts.isEmpty { result[lens] = counts }
        }
        return result
    }

    /// Count 2: every lens from one walk of a tagger with no lemma scheme.
    private func directPrinted(_ texts: [String], tuning: WordCloudTuning) throws -> [WordCloudLens: [String: Int]] {
        let tokenizer = try multiLens(tuning, wordForm: .printed)
        var counts: [WordCloudLens: [String: Int]] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts) }
        return counts
    }

    /// Count 3, with the dictionary tally the same pass makes.
    private func onePass(_ texts: [String], tuning: WordCloudTuning) throws
    -> (dictionary: [WordCloudLens: [String: Int]], printed: [WordCloudLens: [String: Int]]) {
        let tokenizer = try multiLens(tuning, wordForm: .dictionary)
        var counts: [WordCloudLens: [String: Int]] = [:]
        var printed: [WordCloudLens: [String: Int]] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts, printedInto: &printed) }
        return (counts, printed)
    }

    /// The dictionary tally of the single-form pass, which the shipped reference has been written
    /// from since S-1.
    private func singleForm(_ texts: [String], tuning: WordCloudTuning) throws -> [WordCloudLens: [String: Int]] {
        let tokenizer = try multiLens(tuning, wordForm: .dictionary)
        var counts: [WordCloudLens: [String: Int]] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts) }
        return counts
    }

    private func expectEqual(_ lhs: [WordCloudLens: [String: Int]], _ rhs: [WordCloudLens: [String: Int]],
                             _ what: String) {
        #expect(Set(lhs.keys) == Set(rhs.keys), "\(what): lens sets differ")
        for lens in Set(lhs.keys).union(rhs.keys) {
            let left = lhs[lens] ?? [:]
            let right = rhs[lens] ?? [:]
            #expect(left == right, """
                \(what), \(lens.rawValue):
                  only in the first:  \(left.filter { right[$0.key] != $0.value })
                  only in the second: \(right.filter { left[$0.key] != $0.value })
                """)
        }
    }

    private func expectThreeWayParity(_ texts: [String], tuning: WordCloudTuning = .standard) throws {
        let device = devicePrinted(texts, tuning: tuning)
        let direct = try directPrinted(texts, tuning: tuning)
        let both = try onePass(texts, tuning: tuning)
        expectEqual(device, direct, "the device's count against the direct multi-lens walk")
        expectEqual(direct, both.printed, "the direct walk against the one-pass printed tally")
        expectEqual(try singleForm(texts, tuning: tuning), both.dictionary,
                    "the single-form pass against the one-pass dictionary tally")
    }

    // MARK: - Parity

    @Test("The device's count, the direct walk and the one pass agree on diplomatic prose")
    func parityDiplomatic() throws {
        try expectThreeWayParity([Self.diplomaticProse])
    }

    @Test("They agree on economic prose")
    func parityEconomic() throws {
        try expectThreeWayParity([Self.economicProse])
    }

    @Test("They agree when many documents fold into one running tally")
    func parityAcrossAccumulatedDocuments() throws {
        try expectThreeWayParity([Self.diplomaticProse, Self.economicProse, Self.diplomaticProse])
    }

    @Test("They agree under a tuning that folds no plurals and one that keeps the markings")
    func parityUnderAlternativeTuning() throws {
        try expectThreeWayParity([Self.diplomaticProse, Self.economicProse],
                                 tuning: WordCloudTuning(minimumLength: 5, foldPlurals: false))
        try expectThreeWayParity([Self.diplomaticProse],
                                 tuning: WordCloudTuning(minimumLength: 3, filterMarkings: false))
    }

    // MARK: - The suite must not be vacuous

    @Test("The fixtures give every lens a printed tally")
    func fixturesAreNotEmpty() throws {
        let printed = try onePass([Self.diplomaticProse, Self.economicProse], tuning: .standard).printed
        for lens in Self.lenses {
            #expect(!(printed[lens] ?? [:]).isEmpty,
                    "\(lens.rawValue) counted no printed form — parity would be vacuous")
        }
    }

    @Test("On this host the two forms are different counts, in the ways the fallback's wording says")
    func theTwoFormsDifferHere() throws {
        // The premise: a host whose lemmatiser works. Without it the dictionary tally is the
        // printed tally and nothing below could tell one pass from two.
        try #require(NaturalLanguageReadiness.health.lemmatizes,
                     "this host has no lemmatiser, so the two forms cannot be told apart here")
        let both = try onePass([Self.diplomaticProse], tuning: .standard)
        let dictionary = try #require(both.dictionary[.allTerms])
        let printed = try #require(both.printed[.allTerms])
        #expect(dictionary != printed)

        // An inflected verb: one dictionary form, and each printed form its own word.
        #expect(dictionary["negotiate"] == 2, "\(dictionary)")
        #expect(printed["negotiated"] == 1 && printed["negotiating"] == 1, "\(printed)")
        #expect(printed["negotiate"] == nil)
        #expect(dictionary["negotiated"] == nil)

        // A regular plural: the tuning's fold reduces it in the printed tally too, so "treaties"
        // joins "treaty" in both. This is why the wording gives a verb as its example.
        #expect(dictionary["treaty"] == 2)
        #expect(printed["treaty"] == 2)
        #expect(printed["treaties"] == nil)

        // An irregular plural the fold does not know: apart as printed.
        #expect(dictionary["man"] == 1)
        #expect(printed["men"] == 1)
        #expect(printed["man"] == nil)

        // A name that ends in s: the fold knows no names, and the printed tally clips it.
        #expect(dictionary["dulles"] == 1, "\(dictionary)")
        #expect(printed["dulle"] == 1, "\(printed)")
        #expect(printed["dulles"] == nil)

        // A stopword met only through its lemma: "says" is "say" to the dictionary tally and is
        // dropped there, and is a word of its own as printed.
        #expect(dictionary["say"] == nil && dictionary["says"] == nil)
        #expect(printed["says"] == 1)
    }

    @Test("With the fold off, a regular plural is counted apart as printed")
    func withoutTheFoldPluralsAreApart() throws {
        let printed = try #require(try onePass(
            [Self.diplomaticProse],
            tuning: WordCloudTuning(minimumLength: 3, foldPlurals: false)).printed[.allTerms])
        #expect(printed["treaty"] == 1)
        #expect(printed["treaties"] == 1)
        #expect(printed["dulles"] == 1, "with no fold the name is whole")
    }

    // MARK: - A printed tokenizer never asks for the lemma scheme

    @Test("A printed tokenizer asks for the token-type scheme where a dictionary one asks for lemmas",
          arguments: [WordCloudLens.allTerms, .concepts, .sentiment])
    func printedAsksForNoLemmaScheme(lens: WordCloudLens) {
        let printed = WordCloudTokenizer(stopwords: [], lens: lens, wordForm: .printed)
        let dictionary = WordCloudTokenizer(stopwords: [], lens: lens, wordForm: .dictionary)
        #expect(printed.wordSchemes == [.tokenType])
        #expect(dictionary.wordSchemes == [.lemma])
    }

    @Test("A part-of-speech lens keeps the lexical-class scheme in either form",
          arguments: [WordCloudLens.topics, .actions, .descriptors])
    func partOfSpeechLensKeepsItsClassScheme(lens: WordCloudLens) {
        #expect(WordCloudTokenizer(stopwords: [], lens: lens, wordForm: .printed).wordSchemes
                == [.tokenType, .lexicalClass])
        #expect(WordCloudTokenizer(stopwords: [], lens: lens, wordForm: .dictionary).wordSchemes
                == [.lemma, .lexicalClass])
    }

    @Test("The multi-lens tokenizer asks for the same schemes, form by form")
    func multiLensSchemes() throws {
        #expect(try multiLens(.standard, wordForm: .printed).schemes == [.tokenType, .lexicalClass])
        #expect(try multiLens(.standard, wordForm: .dictionary).schemes == [.lemma, .lexicalClass])
        let lexiconOnly = try #require(WordCloudMultiLensTokenizer(
            lenses: [.concepts, .sentiment], tuning: .standard, stopwords: [], lexicons: Self.lexicons,
            markings: [], wordForm: .printed))
        #expect(lexiconOnly.schemes == [.tokenType])
    }

    @Test("The lenses that read the lexical class are the three part-of-speech lenses, and no other")
    func readsLexicalClassNamesThePartOfSpeechLenses() {
        let reading = WordCloudLens.allCases.filter(WordCloudMultiLensTokenizer.readsLexicalClass)
        #expect(reading == [.topics, .actions, .descriptors])
    }

    @Test("A printed tokenizer over the lenses that read no lexical class asks for the token type alone",
          arguments: [[WordCloudLens.allTerms], [.concepts], [.sentiment], [.allTerms, .concepts, .sentiment]])
    func plainLensesAskForTheTokenTypeAlone(lenses: [WordCloudLens]) throws {
        // What `CloudVectorsGenerator`'s second verification walk rests on: these are the lenses a
        // device counts with a tagger that holds no lexical class, and a multi-lens tokenizer over
        // them builds that same tagger — the one a single-lens tokenizer builds for each.
        #expect(!lenses.contains(where: WordCloudMultiLensTokenizer.readsLexicalClass))
        let multi = try #require(WordCloudMultiLensTokenizer(
            lenses: lenses, tuning: .standard, stopwords: [], lexicons: Self.lexicons,
            markings: [], wordForm: .printed))
        #expect(multi.schemes == [.tokenType])
        for lens in lenses {
            #expect(WordCloudTokenizer(stopwords: [], lens: lens, wordForm: .printed).wordSchemes
                    == [.tokenType], "\(lens.rawValue)")
        }
    }

    @Test("One part-of-speech lens among them is enough to add the lexical-class scheme",
          arguments: [WordCloudLens.topics, .actions, .descriptors])
    func aPartOfSpeechLensAddsTheLexicalClass(lens: WordCloudLens) throws {
        let multi = try #require(WordCloudMultiLensTokenizer(
            lenses: [.allTerms, lens], tuning: .standard, stopwords: [], lexicons: Self.lexicons,
            markings: [], wordForm: .printed))
        #expect(multi.schemes == [.tokenType, .lexicalClass])
    }

    @Test("The default form is the dictionary one, so no existing caller changed what it counts")
    func defaultFormIsDictionary() throws {
        #expect(WordCloudTokenizer(stopwords: []).wordForm == .dictionary)
        let multi = try #require(WordCloudMultiLensTokenizer(
            lenses: [.allTerms], tuning: .standard, stopwords: [], lexicons: .empty, markings: []))
        #expect(multi.wordForm == .dictionary)
    }

    @Test("A printed count on a host whose lemmatiser works is still a count of printed forms")
    func printedIsPrintedWhereLemmasExist() throws {
        // The reason the form is a parameter and not read off the tagger: a count begun as printed
        // must stay printed if the lemmatiser answers while it runs. Here the lemmatiser works
        // throughout, and the printed tokenizer still reads none of it.
        try #require(NaturalLanguageReadiness.health.lemmatizes)
        let text = "The ministers negotiated the treaties."
        var printed: [String: Int] = [:]
        WordCloudTokenizer(stopwords: ["the"], wordForm: .printed).accumulate(from: text, into: &printed)
        #expect(printed == ["minister": 1, "negotiated": 1, "treaty": 1], "\(printed)")
        var dictionary: [String: Int] = [:]
        WordCloudTokenizer(stopwords: ["the"], wordForm: .dictionary).accumulate(from: text, into: &dictionary)
        #expect(dictionary == ["minister": 1, "negotiate": 1, "treaty": 1], "\(dictionary)")
    }

    // MARK: - The two framework assumptions, on a harder sentence

    /// The sentence `NaturalLanguageReadiness.wordWalkScheme(of:)`'s note describes: possessives,
    /// hyphens, abbreviations, numbers, an accented word and contractions.
    private static let awkward = """
    Mr. O'Brien's note of Jan. 5 said the U.S.-U.K. talks weren't over: the chargé d'affaires \
    hadn't seen telegram No. 1,204, and the so-called "stand-still" agreement's text was re-drafted.
    """

    @Test("A walk by lemma and a walk by token type find the same words")
    func theTwoWalksFindTheSameWords() {
        func ranges(_ schemes: [NLTagScheme], walk: NLTagScheme) -> [String] {
            let tagger = NaturalLanguageReadiness.tagger(tagSchemes: schemes)
            let text = Self.awkward
            tagger.string = text
            tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
            var found: [String] = []
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: walk,
                                 options: [.omitPunctuation, .omitWhitespace, .omitOther]) { _, range in
                found.append(String(text[range]))
                return true
            }
            return found
        }
        let byLemma = ranges([.lemma, .lexicalClass], walk: .lemma)
        let byTokenType = ranges([.tokenType, .lexicalClass], walk: .tokenType)
        #expect(byLemma.count > 20, "the sentence tokenised to almost nothing: \(byLemma)")
        #expect(byLemma == byTokenType)
    }

    @Test("A word's lexical class is the same with and without the lemma scheme on the tagger")
    func lexicalClassDoesNotDependOnTheLemmaScheme() {
        func classes(_ schemes: [NLTagScheme], walk: NLTagScheme) -> [String] {
            let tagger = NaturalLanguageReadiness.tagger(tagSchemes: schemes)
            var found: [String] = []
            for text in [Self.awkward, Self.diplomaticProse, Self.economicProse] {
                tagger.string = text
                tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
                tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: walk,
                                     options: [.omitPunctuation, .omitWhitespace, .omitOther]) { _, range in
                    let cls = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
                    found.append("\(text[range])/\(cls?.rawValue ?? "nil")")
                    return true
                }
            }
            return found
        }
        let withLemma = classes([.lemma, .lexicalClass], walk: .lemma)
        let without = classes([.tokenType, .lexicalClass], walk: .tokenType)
        #expect(withLemma.contains { $0.hasSuffix("/Noun") } && withLemma.contains { $0.hasSuffix("/Verb") },
                "no noun or no verb was classed, so equality below would say nothing: \(withLemma)")
        #expect(withLemma == without)
    }
}

/// The form a verdict's word lenses count in (#1608).
@Suite("WordCloudKit — the word form a verdict counts in (#1608)")
struct NaturalLanguageHealthWordFormTests {

    @Test("A verdict with a lemmatiser counts dictionary forms, whatever else it lacks")
    func lemmatiserGivesDictionaryForms() {
        #expect(NaturalLanguageHealth.fullyWorking.wordForm == .dictionary)
        #expect(NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: false)
            .wordForm == .dictionary)
    }

    @Test("A verdict with no lemmatiser counts printed forms, whatever else works")
    func noLemmatiserGivesPrintedForms() {
        // The owner's iPhone under iOS 27.0.1: classes and names work, lemmas do not.
        #expect(NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: true)
            .wordForm == .printed)
        // The iOS 26 simulators: nothing tags.
        #expect(NaturalLanguageHealth(lemmatizes: false, classifiesWords: false, recognizesNames: false)
            .wordForm == .printed)
    }

    @Test("The form's raw values are the ones the artifacts carry")
    func rawValuesArePinned() {
        // `keyness-baseline.json` and `keyness-baseline-printed.json` write these strings; renaming
        // a case would make every shipped reader refuse both files.
        #expect(WordCloudWordForm.dictionary.rawValue == "dictionary")
        #expect(WordCloudWordForm.printed.rawValue == "printed")
        #expect(WordCloudWordForm.allCases == [.dictionary, .printed])
    }
}

/// The debug launch that leaves the lemma request unanswered (#1608), which is how the launch the
/// fallback is for is had on demand: the owner's iPhone logged
/// `Lemma=timedOut@30.005s withheld=[Lemma]; canary lemmas=false classes=true names=true`.
///
/// The engine is the real one and so are its framework calls, on this host, but for the one request
/// the switch leaves out, so what is pinned here is the verdict a device in that state reaches, by
/// the code a device runs.
@Suite("WordCloudKit — a launch whose lemma request is never answered (#1608)")
struct UnansweredLemmaRequestTests {

    /// An engine over the live calls with a five-second budget, reporting nothing.
    ///
    /// The budget is how long the unanswered request is waited for, so it is what the first test
    /// costs; it is also how long the two requests that DO answer are given, and those are this
    /// host's own framework calls. They answer in milliseconds on an idle Mac. One second was the
    /// first budget, and the #1608 review asked what a loaded Mac, or the first request after a
    /// restart, does with it: a slow answer would have been recorded as a second scheme withheld,
    /// failing a test of the switch for a reason that is not the switch.
    private func engine(leavingLemmaRequestUnanswered: Bool) -> NaturalLanguageReadinessEngine {
        var dependencies = NaturalLanguageReadinessEngine.Dependencies
            .live(leavingLemmaRequestUnanswered: leavingLemmaRequestUnanswered)
        dependencies.asksForAssets = true
        dependencies.budget = 5
        dependencies.report = { _ in }
        dependencies.statusDidChange = {}
        return NaturalLanguageReadinessEngine(dependencies: dependencies)
    }

    @Test("With the lemma request unanswered, the verdict has no lemmatiser and keeps its classes and names")
    func theVerdictOfAnUnansweredLemmaRequest() {
        let engine = engine(leavingLemmaRequestUnanswered: true)
        let verdict = engine.waitForVerdict()
        // The iPhone's line: the other two answer, the lemma request times out and is withheld.
        #expect(verdict.warmUp.assetRequests.map(\.scheme) == ["LexicalClass", "NameType", "Lemma"])
        #expect(verdict.warmUp.assetRequests.last?.answer == .timedOut)
        #expect(verdict.warmUp.assetRequests.first?.answer == .available)
        #expect(verdict.warmUp.withheld == ["Lemma"])
        #expect(!verdict.health.lemmatizes)
        #expect(verdict.health.classifiesWords)
        #expect(verdict.health.recognizesNames)
        #expect(verdict.health.wordForm == .printed)
        // Every tagger is then built without the lemma scheme, so every word is counted as printed.
        #expect(engine.taggingSchemes(for: [.lemma, .lexicalClass]) == [.lexicalClass, .tokenType])
        #expect(engine.taggingSchemes(for: [.lemma]) == [.tokenType])
        // A tokenizer told to count as printed asks for no lemma scheme, and loses nothing to it.
        #expect(engine.taggingSchemes(for: [.tokenType, .lexicalClass]) == [.tokenType, .lexicalClass])
    }

    @Test("Without the switch the same engine on this host has its lemmatiser")
    func theControl() {
        let verdict = engine(leavingLemmaRequestUnanswered: false).waitForVerdict()
        #expect(verdict.warmUp.withheld.isEmpty)
        #expect(verdict.warmUp.assetRequests.allSatisfy { $0.answer == .available },
                "\(verdict.warmUp.assetRequests)")
        #expect(verdict.health.lemmatizes)
        #expect(verdict.health.wordForm == .dictionary)
    }

    @Test("Only a debug build reads the switch, and only the value 1 turns it on")
    func theSwitchIsRead() {
        let key = NaturalLanguageReadiness.unansweredLemmaRequestEnvironmentKey
        #expect(key == "FRUS_DEBUG_NO_LEMMA_ANSWER")
        #expect(!NaturalLanguageReadiness.leavesLemmaRequestUnanswered(in: [:]))
        #expect(!NaturalLanguageReadiness.leavesLemmaRequestUnanswered(in: [key: "0"]))
        #expect(!NaturalLanguageReadiness.leavesLemmaRequestUnanswered(in: [key: ""]))
        #if DEBUG
        #expect(NaturalLanguageReadiness.leavesLemmaRequestUnanswered(in: [key: "1"]))
        #else
        #expect(!NaturalLanguageReadiness.leavesLemmaRequestUnanswered(in: [key: "1"]))
        #endif
        // This test process was not launched with it, so the engine every other suite reads is live.
        #expect(!NaturalLanguageReadiness.leavesLemmaRequestUnanswered())
    }
}
