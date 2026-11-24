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
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
@testable import WordCloudKit

// MARK: - A host's tagger, as a test writes one

/// A tagger of a host's own (FRUS Explorer Light, S29a): words split by rule, and lemmas, lexical classes
/// and names looked up in tables. It runs wherever the kit builds, Linux too, so the tokenizers' rules are
/// held there over it; and it records what each walk asked of it.
final class TableTagger: WordCloudTagger {
    let identity: WordCloudTokenizerIdentity
    let health: NaturalLanguageHealth
    /// Printed word, lowercased → its lemma.
    let lemmas: [String: String]
    /// Printed word, lowercased → its lexical class; a word not here is `.other`.
    let classes: [String: WordCloudLexicalClass]
    /// Names, each its words lowercased, with their type; the longest that fits is taken.
    let names: [(words: [String], type: WordCloudNameType)]

    /// What each word walk asked for, in order.
    private(set) var readings: [WordCloudTagReading] = []
    /// How many lexical classes the walks read.
    private(set) var classReads = 0
    /// How many of them a walk read without asking for classes, which the protocol forbids.
    private(set) var unaskedClassReads = 0
    /// Whether it gives a word's lemma to a walk that did not ask for lemmas, as a careless host's might.
    let givesLemmasUnasked: Bool

    init(identity: WordCloudTokenizerIdentity = HostTaggerFixtures.identity,
         health: NaturalLanguageHealth = .fullyWorking,
         lemmas: [String: String] = HostTaggerFixtures.lemmas,
         classes: [String: WordCloudLexicalClass] = HostTaggerFixtures.classes,
         names: [(words: [String], type: WordCloudNameType)] = HostTaggerFixtures.names,
         givesLemmasUnasked: Bool = false) {
        self.identity = identity
        self.health = health
        self.lemmas = lemmas
        self.classes = classes
        self.names = names.sorted { $0.words.count > $1.words.count }
        self.givesLemmasUnasked = givesLemmasUnasked
    }

    /// The words of `text`: runs of letters and digits, an apostrophe or a hyphen kept between two of them.
    static func words(in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if character.isLetter || character.isNumber {
                if start == nil { start = index }
            } else if start != nil, character == "'" || character == "-", next < text.endIndex,
                      text[next].isLetter || text[next].isNumber {
                // Inside a word.
            } else if let begun = start {
                found.append(begun..<index)
                start = nil
            }
            index = next
        }
        if let begun = start { found.append(begun..<text.endIndex) }
        return found
    }

    func enumerateWords(in text: String, reading: WordCloudTagReading,
                        using body: (_ range: Range<String.Index>, _ lemma: String?,
                                     _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        readings.append(reading)
        for range in Self.words(in: text) {
            let key = text[range].lowercased()
            let lemma = (reading.contains(.lemmas) || givesLemmasUnasked) && health.lemmatizes ? lemmas[key] : nil
            let goOn = body(range, lemma) {
                self.classReads += 1
                if !reading.contains(.lexicalClasses) { self.unaskedClassReads += 1 }
                return self.health.classifiesWords ? (self.classes[key] ?? .other) : nil
            }
            if !goOn { return }
        }
    }

    func enumerateNames(in text: String,
                        using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        let words = Self.words(in: text)
        var at = 0
        while at < words.count {
            let name = health.recognizesNames ? names.first { name in
                at + name.words.count <= words.count
                    && name.words.indices.allSatisfy { text[words[at + $0]].lowercased() == name.words[$0] }
            } : nil
            let length = name?.words.count ?? 1
            if !body(words[at].lowerBound..<words[at + length - 1].upperBound, name?.type) { return }
            at += length
        }
    }
}

/// The tables and texts the suites below count.
enum HostTaggerFixtures {
    static let identity = WordCloudTokenizerIdentity(name: "TableTagger", version: "1")

    static let lemmas: [String: String] = [
        "negotiated": "negotiate", "treaties": "treaty", "delegations": "delegation", "signed": "sign",
        "agreements": "agreement", "telegrams": "telegram", "warned": "warn", "says": "say",
        "officials": "official", "debated": "debate", "loans": "loan", "approved": "approve",
        // A lemmatiser gives a name as its lemma, so the fold, which knows no names, does not clip it.
        "dulles": "Dulles",
    ]

    static let classes: [String: WordCloudLexicalClass] = [
        "secretary": .noun, "negotiated": .verb, "treaties": .noun, "geneva": .noun, "delegations": .noun,
        "signed": .verb, "agreements": .noun, "top": .adjective, "secret": .adjective, "telegrams": .noun,
        "warned": .verb, "dangerous": .adjective, "crisis": .noun, "says": .verb, "bank": .noun,
        "approved": .verb, "loans": .noun, "officials": .noun, "debated": .verb, "economic": .adjective,
        "assistance": .noun,
    ]

    static let names: [(words: [String], type: WordCloudNameType)] = [
        (["geneva"], .place), (["top", "secret"], .place), (["world", "bank"], .organization),
        (["dulles"], .person),
    ]

    /// Something for every rule: lemmas, plurals for the fold, stopwords, a digit, markings, a class of
    /// each kind, lexicon words, and names.
    static let diplomatic = "The Secretary negotiated the treaties in Geneva, and the delegations signed 2 "
        + "agreements. Top Secret telegrams warned of a dangerous crisis. Dulles says so."

    /// Other words, so one lucky text cannot carry a suite.
    static let economic = "Economic assistance expanded. The World Bank approved loans, and officials "
        + "debated the agreements in Geneva."

    static let stopwords: Set<String> = ["the", "in", "and", "of", "a", "so", "say"]

    static let markings: Set<String> = ["secret", "top"]

    static let lexicons = WordCloudLexiconSet(payload: .init(
        concepts: ["treaty", "crisis", "assistance"],
        sentimentPositive: ["agreement"],
        sentimentNegative: ["crisis", "dangerous"]))

    /// Every word lens, as the generator counts them.
    static let wordLenses: [WordCloudLens] = [.allTerms, .descriptors] + WordCloudLens.bundledCloudLenses

    static func tokenizer(_ lens: WordCloudLens, tuning: WordCloudTuning = .standard,
                          wordForm: WordCloudWordForm = .dictionary) -> WordCloudTokenizer {
        WordCloudTokenizer(stopwords: stopwords, minimumLength: tuning.minimumLength,
                           foldPlurals: tuning.foldPlurals, lens: lens, lexicon: lexicons.filter(for: lens),
                           markings: tuning.filterMarkings ? markings : [], wordForm: wordForm)
    }

    static func multiLens(_ lenses: [WordCloudLens] = wordLenses, tuning: WordCloudTuning = .standard,
                          wordForm: WordCloudWordForm = .dictionary) -> WordCloudMultiLensTokenizer? {
        WordCloudMultiLensTokenizer(lenses: lenses, tuning: tuning, stopwords: stopwords, lexicons: lexicons,
                                    markings: tuning.filterMarkings ? markings : [], wordForm: wordForm)
    }
}

// MARK: - The single-lens tokenizer over a host's tagger

/// `WordCloudTokenizer` over a host's tagger (FRUS Explorer Light, S29a): the kit's rules, whatever the
/// tagger, on every platform. Each expected count is worked out by hand from the fixtures' tables.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
@Suite("WordCloudKit — the tokenizer over a host's tagger (S29a)")
struct WordCloudHostTaggerTokenizerTests {

    private func count(_ lens: WordCloudLens, _ text: String = HostTaggerFixtures.diplomatic,
                       wordForm: WordCloudWordForm = .dictionary, tuning: WordCloudTuning = .standard,
                       tagger: TableTagger = TableTagger()) -> [String: Int] {
        var counts: [String: Int] = [:]
        HostTaggerFixtures.tokenizer(lens, tuning: tuning, wordForm: wordForm)
            .accumulate(from: text, into: &counts, tagger: tagger)
        return counts
    }

    @Test("All terms: the lemma where the tagger gives one, the word lowercased and folded where not, without stopwords, short words, digits or markings")
    func allTermsInDictionaryForms() {
        var counts: [String: Int] = [:]
        let added = HostTaggerFixtures.tokenizer(.allTerms)
            .accumulate(from: HostTaggerFixtures.diplomatic, into: &counts, tagger: TableTagger())
        #expect(counts == ["secretary": 1, "negotiate": 1, "treaty": 1, "geneva": 1, "delegation": 1,
                           "sign": 1, "agreement": 1, "telegram": 1, "warn": 1, "dangerous": 1, "crisis": 1,
                           "dulles": 1], "\(counts)")
        #expect(added == 12)
    }

    @Test("Counted as printed, no lemma is read, though the tagger gives them; the fold still joins regular plurals")
    func allTermsAsPrinted() {
        let tagger = TableTagger()
        let counts = count(.allTerms, wordForm: .printed, tagger: tagger)
        #expect(counts == ["secretary": 1, "negotiated": 1, "treaty": 1, "geneva": 1, "delegation": 1,
                           "signed": 1, "agreement": 1, "telegram": 1, "warned": 1, "dangerous": 1, "crisis": 1,
                           "dulle": 1, "says": 1], "\(counts)")
        // A stopword met only through its lemma ("says", under "say") is a word of its own as printed.
        #expect(tagger.readings == [[]])
    }

    @Test("A count of printed forms reads no lemma from a tagger that gives one unasked, in either tokenizer")
    func printedIgnoresLemmasGivenUnasked() throws {
        let careless = TableTagger(givesLemmasUnasked: true)
        #expect(count(.allTerms, wordForm: .printed, tagger: careless)
                == count(.allTerms, wordForm: .printed, tagger: TableTagger()))
        #expect(count(.allTerms, wordForm: .printed, tagger: careless)["negotiated"] == 1)
        let printedPass = try #require(HostTaggerFixtures.multiLens(wordForm: .printed))
        var fromCareless: [WordCloudLens: [String: Int]] = [:]
        var fromCareful: [WordCloudLens: [String: Int]] = [:]
        printedPass.accumulate(from: HostTaggerFixtures.diplomatic, into: &fromCareless, tagger: careless)
        printedPass.accumulate(from: HostTaggerFixtures.diplomatic, into: &fromCareful, tagger: TableTagger())
        #expect(fromCareless == fromCareful)
        #expect(fromCareless[.actions]?["negotiated"] == 1)
    }

    @Test("With the fold off a plural with no lemma is its own word")
    func withoutTheFold() {
        let counts = count(.allTerms, wordForm: .printed, tuning: WordCloudTuning(minimumLength: 3, foldPlurals: false))
        #expect(counts["treaties"] == 1 && counts["treaty"] == nil, "\(counts)")
        #expect(counts["dulles"] == 1, "\(counts)")
    }

    @Test("Topics keeps nouns, Actions verbs and Descriptors adjectives, by the tagger's classes")
    func partOfSpeechLenses() {
        #expect(count(.topics) == ["secretary": 1, "treaty": 1, "geneva": 1, "delegation": 1, "agreement": 1,
                                   "telegram": 1, "crisis": 1])
        #expect(count(.actions) == ["negotiate": 1, "sign": 1, "warn": 1])
        // "Top" and "Secret" are adjectives here, and markings, so only "dangerous" is left.
        #expect(count(.descriptors) == ["dangerous": 1])
    }

    @Test("A tagger that classes nothing keeps nothing in a part-of-speech lens, and All terms is untouched")
    func noClasses() {
        let tagger = TableTagger(health: NaturalLanguageHealth(lemmatizes: true, classifiesWords: false,
                                                               recognizesNames: true))
        #expect(count(.topics, tagger: tagger).isEmpty)
        #expect(count(.allTerms, tagger: tagger).count == 12)
    }

    @Test("Concepts and Sentiment keep their lexicons' words, in the form the count is in")
    func lexiconLenses() {
        #expect(count(.concepts) == ["treaty": 1, "crisis": 1])
        #expect(count(.sentiment) == ["agreement": 1, "dangerous": 1, "crisis": 1])
        // As printed "treaties" folds to "treaty", a lexicon word, and "agreements" to "agreement".
        #expect(count(.concepts, wordForm: .printed) == ["treaty": 1, "crisis": 1])
        #expect(count(.sentiment, wordForm: .printed) == ["agreement": 1, "dangerous": 1, "crisis": 1])
    }

    @Test("An entity lens counts the names the tagger joins, in title case, and drops a name made of markings")
    func entityLenses() {
        #expect(count(.places) == ["Geneva": 1], "\"Top Secret\" is a phrase of markings, which no name is")
        #expect(count(.people) == ["Dulles": 1])
        #expect(count(.organizations, HostTaggerFixtures.economic) == ["World Bank": 1])
    }

    @Test("A tagger that names no one keeps nothing in an entity lens")
    func noNames() {
        let tagger = TableTagger(health: NaturalLanguageHealth(lemmatizes: true, classifiesWords: true,
                                                               recognizesNames: false))
        #expect(count(.places, tagger: tagger).isEmpty)
        #expect(count(.people, tagger: tagger).isEmpty)
    }

    @Test("A walk asks for lemmas only in dictionary forms, and for classes only for a part-of-speech lens")
    func whatAWalkAsksFor() {
        #expect(HostTaggerFixtures.tokenizer(.allTerms).wordReading == [.lemmas])
        #expect(HostTaggerFixtures.tokenizer(.concepts, wordForm: .printed).wordReading == [])
        for lens in [WordCloudLens.topics, .actions, .descriptors] {
            #expect(HostTaggerFixtures.tokenizer(lens).wordReading == [.lemmas, .lexicalClasses])
            #expect(HostTaggerFixtures.tokenizer(lens, wordForm: .printed).wordReading == [.lexicalClasses])
        }
        // An entity lens walks names, never words.
        let tagger = TableTagger()
        _ = count(.people, tagger: tagger)
        #expect(tagger.readings.isEmpty)
    }

    @Test("A lens that reads no class reads none; a part-of-speech lens reads one a word, and asked for them")
    func classesAreReadOnlyWhenAskedFor() {
        let plain = TableTagger()
        _ = count(.allTerms, tagger: plain)
        #expect(plain.classReads == 0)
        let topics = TableTagger()
        _ = count(.topics, tagger: topics)
        #expect(topics.classReads == TableTagger.words(in: HostTaggerFixtures.diplomatic).count)
        #expect(topics.unaskedClassReads == 0)
    }

    @Test("An empty text asks the tagger for nothing")
    func emptyText() {
        let tagger = TableTagger()
        #expect(count(.allTerms, "", tagger: tagger).isEmpty)
        #expect(count(.places, "", tagger: tagger).isEmpty)
        #expect(tagger.readings.isEmpty)
    }

    @Test("Counts fold into one running tally across texts")
    func accumulates() {
        var counts: [String: Int] = [:]
        let tokenizer = HostTaggerFixtures.tokenizer(.allTerms)
        let tagger = TableTagger()
        for text in [HostTaggerFixtures.diplomatic, HostTaggerFixtures.economic] {
            tokenizer.accumulate(from: text, into: &counts, tagger: tagger)
        }
        #expect(counts["agreement"] == 2)
        #expect(counts["geneva"] == 2)
        #expect(counts["loan"] == 1 && counts["approve"] == 1)
    }
}

// MARK: - The one pass over a host's tagger

/// `WordCloudMultiLensTokenizer` over a host's tagger (S29a): the one pass is the single-lens passes, and
/// its printed tally is a printed tokenizer's, as `WordCloudMultiLensParityTests` and
/// `WordCloudPrintedFormParityTests` hold for NaturalLanguage's; here on every platform, over a tagger whose
/// answers are fixed, so the parity is the kit's rules alone.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
@Suite("WordCloudKit — the one pass over a host's tagger (S29a)")
struct WordCloudHostTaggerMultiLensTests {

    private static let texts = [HostTaggerFixtures.diplomatic, HostTaggerFixtures.economic, HostTaggerFixtures.diplomatic]

    private func singlePasses(_ texts: [String], tuning: WordCloudTuning,
                              wordForm: WordCloudWordForm) -> [WordCloudLens: [String: Int]] {
        var result: [WordCloudLens: [String: Int]] = [:]
        for lens in HostTaggerFixtures.wordLenses {
            var counts: [String: Int] = [:]
            let tokenizer = HostTaggerFixtures.tokenizer(lens, tuning: tuning, wordForm: wordForm)
            for text in texts { tokenizer.accumulate(from: text, into: &counts, tagger: TableTagger()) }
            if !counts.isEmpty { result[lens] = counts }
        }
        return result
    }

    @Test("One pass equals a pass for each lens, under the standard tuning and two others",
          arguments: [WordCloudTuning.standard, WordCloudTuning(minimumLength: 5, foldPlurals: false),
                      WordCloudTuning(minimumLength: 3, filterMarkings: false)])
    func onePassIsTheSinglePasses(tuning: WordCloudTuning) throws {
        let tokenizer = try #require(HostTaggerFixtures.multiLens(tuning: tuning))
        var counts: [WordCloudLens: [String: Int]] = [:]
        for text in Self.texts { tokenizer.accumulate(from: text, into: &counts, tagger: TableTagger()) }
        #expect(counts == singlePasses(Self.texts, tuning: tuning, wordForm: .dictionary))
    }

    @Test("The printed tally of the one pass is a printed tokenizer's, and its dictionary tally is the single-form pass's",
          arguments: [WordCloudTuning.standard, WordCloudTuning(minimumLength: 5, foldPlurals: false)])
    func bothFormsFromOnePass(tuning: WordCloudTuning) throws {
        let dictionary = try #require(HostTaggerFixtures.multiLens(tuning: tuning))
        let printedPass = try #require(HostTaggerFixtures.multiLens(tuning: tuning, wordForm: .printed))
        var counts: [WordCloudLens: [String: Int]] = [:]
        var printed: [WordCloudLens: [String: Int]] = [:]
        var singleForm: [WordCloudLens: [String: Int]] = [:]
        var direct: [WordCloudLens: [String: Int]] = [:]
        for text in Self.texts {
            dictionary.accumulate(from: text, into: &counts, printedInto: &printed, tagger: TableTagger())
            dictionary.accumulate(from: text, into: &singleForm, tagger: TableTagger())
            printedPass.accumulate(from: text, into: &direct, tagger: TableTagger())
        }
        #expect(counts == singleForm)
        #expect(printed == direct)
        #expect(direct == singlePasses(Self.texts, tuning: tuning, wordForm: .printed))
        // Not vacuous: the two forms differ, and every lens counted something.
        #expect(counts != printed)
        for lens in HostTaggerFixtures.wordLenses { #expect(printed[lens]?.isEmpty == false, "\(lens.rawValue)") }
    }

    @Test("The pass reads a word's class once, only for a word every lens's filters left, and only when it asked")
    func classesReadOnceAWord() throws {
        let tagger = TableTagger()
        let tokenizer = try #require(HostTaggerFixtures.multiLens([.concepts, .topics, .actions]))
        var counts: [WordCloudLens: [String: Int]] = [:]
        tokenizer.accumulate(from: HostTaggerFixtures.diplomatic, into: &counts, tagger: tagger)
        // Twelve words survive the stopwords, the length, the digit and the markings (All terms' twelve).
        #expect(tagger.classReads == 12)
        #expect(tagger.unaskedClassReads == 0)
        #expect(tagger.readings == [[.lemmas, .lexicalClasses]])

        let lexiconOnly = TableTagger()
        let plain = try #require(HostTaggerFixtures.multiLens([.concepts, .sentiment]))
        plain.accumulate(from: HostTaggerFixtures.diplomatic, into: &counts, tagger: lexiconOnly)
        #expect(lexiconOnly.classReads == 0)
        #expect(lexiconOnly.readings == [[.lemmas]])
        #expect(plain.reading == [.lemmas])
    }

    @Test("A printed pass asks for no lemma, and over a tagger with no lemmatiser both tallies are the printed count")
    func printedAndNoLemmatiser() throws {
        let printedPass = try #require(HostTaggerFixtures.multiLens(wordForm: .printed))
        #expect(printedPass.reading == [.lexicalClasses])
        let noLemmas = TableTagger(health: NaturalLanguageHealth(lemmatizes: false, classifiesWords: true,
                                                                 recognizesNames: true))
        let dictionary = try #require(HostTaggerFixtures.multiLens())
        var counts: [WordCloudLens: [String: Int]] = [:]
        var printed: [WordCloudLens: [String: Int]] = [:]
        dictionary.accumulate(from: HostTaggerFixtures.diplomatic, into: &counts, printedInto: &printed, tagger: noLemmas)
        #expect(counts == printed)
    }

    @Test("Entity lenses and no lenses are refused, and duplicates collapse, on every platform")
    func contract() throws {
        #expect(HostTaggerFixtures.multiLens([.topics, .people]) == nil)
        #expect(HostTaggerFixtures.multiLens([]) == nil)
        let tokenizer = try #require(HostTaggerFixtures.multiLens([.topics, .concepts, .topics]))
        #expect(tokenizer.lenses == [.topics, .concepts])
        var counts: [WordCloudLens: [String: Int]] = [:]
        tokenizer.accumulate(from: HostTaggerFixtures.diplomatic, into: &counts, tagger: TableTagger())
        var single: [String: Int] = [:]
        HostTaggerFixtures.tokenizer(.topics).accumulate(from: HostTaggerFixtures.diplomatic, into: &single,
                                                         tagger: TableTagger())
        #expect(counts[.topics] == single)
    }
}

// MARK: - The tokenizer's identity in the files

/// The tokenizer's identity, which the clouds and the keyness references record, and the mismatch that
/// refuses a scope counted by another (S29a).
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
@Suite("WordCloudKit — the tokenizer's identity in the clouds and the references (S29a)")
struct WordCloudTokenizerIdentityTests {

    /// The repository's bundled resource `name`, read from disk as a host reads its copy.
    private static func resource(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer/Resources/\(name).json")
    }

    private static let stamp = KeynessBaselineFile.Configuration(
        tuning: .standard, includeDiplomatic: true, lexiconsDigest: "l", stopwordsDigest: "s")

    @Test("NaturalLanguage's identity is pinned, and an identity encodes as its name and version")
    func naturalLanguageIsPinned() throws {
        #expect(WordCloudTokenizerIdentity.naturalLanguage.name == "NaturalLanguage")
        #expect(WordCloudTokenizerIdentity.naturalLanguage.version == "1")
        #expect(WordCloudTokenizerIdentity.legacyNaturalLanguage == WordCloudTokenizerIdentity(name: "NaturalLanguage", version: "1"))
        // Today the app counts as every file before S29a was counted. A new version of NaturalLanguage's
        // identity is a change to what the app counts, and comes with the bundled files counted again.
        #expect(WordCloudTokenizerIdentity.naturalLanguage == .legacyNaturalLanguage,
                "NaturalLanguage's version moved: count the bundled clouds and references again")
        #expect(HostTaggerFixtures.identity.description == "TableTagger 1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(HostTaggerFixtures.identity)
        #expect(String(decoding: data, as: UTF8.self) == #"{"name":"TableTagger","version":"1"}"#)
        #expect(try JSONDecoder().decode(WordCloudTokenizerIdentity.self, from: data) == HostTaggerFixtures.identity)
    }

    private static let configurationJSON = #"{"includeDiplomatic":true,"lexiconsDigest":"l","stopwordsDigest":"s","tuning":{"filterMarkings":true,"foldPlurals":true,"minimumCount":1,"minimumLength":3},"wordForm":"printed"}"#
    private static let provenanceJSON = #"{"documentCount":9,"topTermsPerList":50,"tuning":{"filterMarkings":true,"foldPlurals":true,"minimumCount":1,"minimumLength":3},"volumeCount":2}"#

    private static func sorted<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test("A stamp that names no tokenizer was counted by NaturalLanguage as it was before S29a")
    func noTokenizerIsNaturalLanguage() throws {
        let decoded = try JSONDecoder().decode(KeynessBaselineFile.Configuration.self, from: Data(Self.configurationJSON.utf8))
        #expect(decoded.tokenizer == .legacyNaturalLanguage)
        #expect(decoded.wordForm == .printed)
        let stamp = try JSONDecoder().decode(CloudVectorsFile.Provenance.self, from: Data(Self.provenanceJSON.utf8))
        #expect(stamp.tokenizer == .legacyNaturalLanguage)
        #expect(stamp == CloudVectorsFile.Provenance(volumeCount: 2, documentCount: 9, tuning: .standard,
                                                     topTermsPerList: 50))
    }

    @Test("A stamp of the tokenizer a stamp without one reads as is written without the key, and as it was read")
    func legacyStampsAreWrittenAsTheyWere() throws {
        let configuration = try JSONDecoder().decode(KeynessBaselineFile.Configuration.self, from: Data(Self.configurationJSON.utf8))
        #expect(try Self.sorted(configuration) == Self.configurationJSON)
        let provenance = try JSONDecoder().decode(CloudVectorsFile.Provenance.self, from: Data(Self.provenanceJSON.utf8))
        #expect(try Self.sorted(provenance) == Self.provenanceJSON)
        // Another tokenizer's stamp names it, after the keys it had.
        let host = KeynessBaselineFile.Configuration(tuning: .standard, includeDiplomatic: true, lexiconsDigest: "l",
                                                     stopwordsDigest: "s", wordForm: .printed,
                                                     tokenizer: HostTaggerFixtures.identity)
        #expect(try Self.sorted(host) == #"{"includeDiplomatic":true,"lexiconsDigest":"l","stopwordsDigest":"s","tokenizer":{"name":"TableTagger","version":"1"},"tuning":{"filterMarkings":true,"foldPlurals":true,"minimumCount":1,"minimumLength":3},"wordForm":"printed"}"#)
        let hostProvenance = CloudVectorsFile.Provenance(volumeCount: 2, documentCount: 9, tuning: .standard,
                                                         topTermsPerList: 50, tokenizer: HostTaggerFixtures.identity)
        #expect(try Self.sorted(hostProvenance).contains(#""tokenizer":{"name":"TableTagger","version":"1"}"#))
        // NaturalLanguage's own stamp is written without the key while it is the legacy one.
        let app = KeynessBaselineFile.Configuration(tuning: .standard, includeDiplomatic: true, lexiconsDigest: "l",
                                                    stopwordsDigest: "s", wordForm: .printed, tokenizer: .naturalLanguage)
        #expect(try Self.sorted(app) == Self.configurationJSON)
    }

    @Test("The bundled references and clouds, decoded and encoded again, are the stamps they were",
          arguments: ["keyness-baseline", "keyness-baseline-printed", "cloud-vectors-core"])
    func bundledFilesReencodeAsTheyWere(resource: String) throws {
        let data = try Data(contentsOf: Self.resource(resource))
        if resource.hasPrefix("keyness") {
            let file = try JSONDecoder().decode(KeynessBaselineFile.self, from: data)
            let again = try JSONDecoder().decode(KeynessBaselineFile.self, from: try JSONEncoder().encode(file))
            #expect(again == file)
            #expect(!(try Self.sorted(file.configuration)).contains(#""tokenizer""#))
            #expect(!(try Self.sorted(file.provenance)).contains(#""tokenizer""#))
            #if canImport(Darwin)
            // As the app's writer-reader parity holds them: the generator's own encoder gives the file's bytes.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            #expect(try encoder.encode(file) == data)
            #endif
        } else {
            let file = try JSONDecoder().decode(CloudVectorsFile.self, from: data)
            #expect(!(try Self.sorted(file.provenance)).contains(#""tokenizer""#))
            #if canImport(Darwin)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            #expect(try encoder.encode(file) == data)
            #endif
        }
    }

    @Test("A stamp carries its tokenizer through an encode and a decode, and into the other form's")
    func tokenizerRoundTrips() throws {
        let configuration = KeynessBaselineFile.Configuration(
            tuning: .standard, includeDiplomatic: true, lexiconsDigest: "l", stopwordsDigest: "s",
            tokenizer: HostTaggerFixtures.identity)
        let data = try JSONEncoder().encode(configuration)
        #expect(try JSONDecoder().decode(KeynessBaselineFile.Configuration.self, from: data) == configuration)
        #expect(configuration.counted(as: .printed).tokenizer == HostTaggerFixtures.identity)
        let provenance = CloudVectorsFile.Provenance(volumeCount: 1, documentCount: 2, tuning: .standard,
                                                     topTermsPerList: 50, tokenizer: HostTaggerFixtures.identity)
        let encoded = try JSONEncoder().encode(provenance)
        #expect(try JSONDecoder().decode(CloudVectorsFile.Provenance.self, from: encoded) == provenance)
    }

    @Test("A scope counted by the reference's tokenizer has no mismatch, and one counted by another has the tokenizer's")
    func anotherTokenizerIsAMismatch() {
        #expect(Self.stamp.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: "l",
                                      stopwordsDigest: "s", tokenizer: .naturalLanguage).isEmpty)
        #expect(Self.stamp.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: "l",
                                      stopwordsDigest: "s", tokenizer: HostTaggerFixtures.identity) == [.tokenizer])
        // Another version of the same tokenizer is another tokenizer.
        #expect(Self.stamp.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: "l",
                                      stopwordsDigest: "s",
                                      tokenizer: WordCloudTokenizerIdentity(name: "NaturalLanguage", version: "2"))
                == [.tokenizer])
        // With a setting's mismatch it is named too, after the settings'.
        #expect(Self.stamp.mismatches(against: .standard, includeDiplomatic: false, lexiconsDigest: "l",
                                      stopwordsDigest: "s", tokenizer: HostTaggerFixtures.identity)
                == [.diplomaticLayer, .tokenizer])
        #expect(KeynessBaselineFile.Configuration.Mismatch.tokenizer.rawValue == "tokenizer")
    }

    @Test("The bundled clouds and references name no tokenizer, so they read as NaturalLanguage's, and refuse a host's count",
          arguments: WordCloudWordForm.allCases)
    func bundledFilesAreNaturalLanguages(wordForm: WordCloudWordForm) throws {
        let reference = try KeynessBaselineFile(contentsOf: Self.resource(KeynessBaselineFile.resourceName(for: wordForm)))
        let core = try CloudVectorsFile(contentsOf: Self.resource("cloud-vectors-core"))
        #expect(reference.configuration.tokenizer == .legacyNaturalLanguage)
        #expect(reference.provenance.tokenizer == .legacyNaturalLanguage)
        #expect(core.provenance.tokenizer == .legacyNaturalLanguage)
        let configuration = reference.configuration
        let mismatches = configuration.mismatches(
            against: configuration.tuning, includeDiplomatic: configuration.includeDiplomatic,
            lexiconsDigest: configuration.lexiconsDigest, stopwordsDigest: configuration.stopwordsDigest,
            tokenizer: HostTaggerFixtures.identity)
        #expect(mismatches == [.tokenizer])
    }
}

#if canImport(NaturalLanguage)
// MARK: - NaturalLanguage's taggers

/// The readiness gate's taggers as `WordCloudTagger`s (S29a): what each walk asks the gate for, and how
/// NaturalLanguage's tags read as the kit's classes and name types.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
@Suite("WordCloudKit — NaturalLanguage's taggers (S29a)")
struct NaturalLanguageWordCloudTaggerTests {

    @Test("A word walk asks the gate for the schemes it reads: the lemma or the token type, and the class when it reads classes")
    func wordSchemes() {
        #expect(NaturalLanguageWordCloudTagger.wordSchemes(for: [.lemmas]) == [.lemma])
        #expect(NaturalLanguageWordCloudTagger.wordSchemes(for: []) == [.tokenType])
        #expect(NaturalLanguageWordCloudTagger.wordSchemes(for: [.lemmas, .lexicalClasses]) == [.lemma, .lexicalClass])
        #expect(NaturalLanguageWordCloudTagger.wordSchemes(for: [.lexicalClasses]) == [.tokenType, .lexicalClass])
        #expect(NaturalLanguageWordCloudTagger.nameSchemes == [.nameType])
    }

    @Test("A printed count asks the gate for no lemma scheme, and the two tokenizers ask for the same schemes",
          arguments: WordCloudLens.allCases.filter { !$0.isEntity })
    func tokenizersAskForTheSameSchemes(lens: WordCloudLens) throws {
        for wordForm in WordCloudWordForm.allCases {
            let single = WordCloudTokenizer(stopwords: [], lens: lens, wordForm: wordForm)
            #expect(single.wordSchemes.contains(.lemma) == (wordForm == .dictionary))
            #expect(single.wordSchemes.contains(.lexicalClass) == WordCloudMultiLensTokenizer.readsLexicalClass(lens))
            let multi = try #require(WordCloudMultiLensTokenizer(lenses: [lens], tuning: .standard, stopwords: [],
                                                                 lexicons: .empty, markings: [], wordForm: wordForm))
            #expect(multi.schemes == single.wordSchemes)
        }
    }

    @Test("NaturalLanguage's lexical classes read as the three the lenses keep, and every other as other")
    func lexicalClasses() {
        #expect(WordCloudLexicalClass(NLTag.noun) == .noun)
        #expect(WordCloudLexicalClass(NLTag.verb) == .verb)
        #expect(WordCloudLexicalClass(NLTag.adjective) == .adjective)
        for other in [NLTag.adverb, .pronoun, .determiner, .number, .otherWord] {
            #expect(WordCloudLexicalClass(other) == .other, "\(other.rawValue)")
        }
        #expect(WordCloudLexicalClass(nil) == nil)
    }

    @Test("NaturalLanguage's name types read as the three the entity lenses keep, and every other tag as no name")
    func nameTypes() {
        #expect(WordCloudNameType(NLTag.personalName) == .person)
        #expect(WordCloudNameType(NLTag.placeName) == .place)
        #expect(WordCloudNameType(NLTag.organizationName) == .organization)
        #expect(WordCloudNameType(NLTag.otherWord) == nil)
        #expect(WordCloudNameType(nil) == nil)
    }

    @Test("NaturalLanguage's tagger is the gate's verdict, and an NLTagger the verdict for the schemes it holds")
    func identityAndHealth() {
        let verdict = NaturalLanguageReadiness.health
        #expect(NaturalLanguageWordCloudTagger().identity == .naturalLanguage)
        #expect(NaturalLanguageWordCloudTagger().health == verdict)
        for schemes: [NLTagScheme] in [[.lemma], [.lemma, .lexicalClass], [.tokenType], [.lexicalClass, .tokenType],
                                       [.nameType], [.lemma, .lexicalClass, .nameType]] {
            let tagger = NaturalLanguageReadiness.tagger(tagSchemes: schemes)
            #expect(tagger.identity == .naturalLanguage)
            #expect(tagger.health == NaturalLanguageHealth(
                lemmatizes: verdict.lemmatizes && schemes.contains(.lemma),
                classifiesWords: verdict.classifiesWords && schemes.contains(.lexicalClass),
                recognizesNames: verdict.recognizesNames && schemes.contains(.nameType)), "\(schemes)")
        }
    }

    // MARK: - NLTagger's walks are the calls the tokenizers made of it

    /// The texts the walks are held over: possessives, hyphens, abbreviations, numbers, an accented word
    /// and contractions, and the two fixtures' prose.
    private static let walkTexts = [
        "Mr. O'Brien's note of Jan. 5 said the U.S.-U.K. talks weren't over: the chargé d'affaires hadn't seen "
            + "telegram No. 1,204, and the so-called \"stand-still\" agreement's text was re-drafted.",
        HostTaggerFixtures.diplomatic, HostTaggerFixtures.economic,
        "President Eisenhower met Prime Minister Churchill and Secretary Dulles in Geneva; the United Nations noted it.",
    ]

    /// One word of a walk, as the tokenizer reads it.
    private struct Walked: Equatable, CustomStringConvertible {
        let word: String
        let lemma: String?
        let lexicalClass: WordCloudLexicalClass?
        var description: String { "\(word)/\(lemma ?? "-")/\(lexicalClass.map { "\($0)" } ?? "-")" }
    }

    /// NaturalLanguage's word walk as `v2`'s tokenizers made it, call for call: the walk scheme the gate's
    /// tagger gives, the string set and English pinned, the same options, the lemma the walk's tag when it
    /// is by `.lemma`, and the class asked at the word's first character.
    private static func walkedAsBefore(_ tagger: NLTagger, _ text: String) -> [Walked] {
        let walk = NaturalLanguageReadiness.wordWalkScheme(of: tagger)
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var found: [Walked] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: walk,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            let lexicalClass = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
            found.append(Walked(word: String(text[range]), lemma: walk == .lemma ? tag?.rawValue : nil,
                                lexicalClass: WordCloudLexicalClass(lexicalClass)))
            return true
        }
        return found
    }

    @Test("An NLTagger's word walk gives the words, lemmas and classes NaturalLanguage's own walk gives",
          arguments: [[NLTagScheme.lemma, .lexicalClass], [.lemma], [.tokenType, .lexicalClass],
                      [.tokenType], [.lexicalClass, .tokenType]])
    func wordWalkIsTheOldWalk(schemes: [NLTagScheme]) {
        for text in Self.walkTexts {
            let tagger = NaturalLanguageReadiness.tagger(tagSchemes: schemes)
            var found: [Walked] = []
            tagger.enumerateWords(in: text, reading: [.lemmas, .lexicalClasses]) { range, lemma, lexicalClass in
                found.append(Walked(word: String(text[range]), lemma: lemma, lexicalClass: lexicalClass()))
                return true
            }
            let expected = Self.walkedAsBefore(NaturalLanguageReadiness.tagger(tagSchemes: schemes), text)
            #expect(found == expected, "\(schemes): \(found.prefix(8)) against \(expected.prefix(8))")
            #expect(found.count > 10, "the text tokenised to almost nothing: \(found)")
        }
    }

    @Test("A walk that reads no lemma is given none, over a tagger that holds the lemma scheme too")
    func noLemmaUnlessAsked() {
        let text = HostTaggerFixtures.diplomatic
        var lemmas: [String?] = []
        NaturalLanguageReadiness.tagger(tagSchemes: [.lemma, .lexicalClass])
            .enumerateWords(in: text, reading: [.lexicalClasses]) { _, lemma, _ in
                lemmas.append(lemma)
                return true
            }
        #expect(!lemmas.isEmpty && lemmas.allSatisfy { $0 == nil })
    }

    @Test("An NLTagger's name walk gives the names NaturalLanguage's own walk gives, joined")
    func nameWalkIsTheOldWalk() {
        for text in Self.walkTexts {
            let tagger = NaturalLanguageReadiness.tagger(tagSchemes: [.nameType])
            var found: [String] = []
            tagger.enumerateNames(in: text) { range, type in
                found.append("\(text[range])/\(type.map { "\($0)" } ?? "-")")
                return true
            }
            let before = NaturalLanguageReadiness.tagger(tagSchemes: [.nameType])
            before.string = text
            before.setLanguage(.english, range: text.startIndex..<text.endIndex)
            var expected: [String] = []
            before.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                                 options: [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]) { tag, range in
                expected.append("\(text[range])/\(WordCloudNameType(tag).map { "\($0)" } ?? "-")")
                return true
            }
            #expect(found == expected)
        }
    }
}
#endif
