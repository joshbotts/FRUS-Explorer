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
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds WordCloudKit as a module of its own; Xcode compiles it into the app.
#if canImport(WordCloudKit)
import WordCloudKit
#endif

// What the word cloud's, keyness's, Collocates' and the shared-word chips' suites share since those
// moved into FRUSCoreKit (FRUS Explorer Light, S29b): the bundled files read as a host reads them, the
// tagger a count walks, and the references a case ranks against.
//
// Version history:
//   1.0 — 2026-11-24 (FRUS Explorer Light, S29b): initial implementation

// MARK: - WordCloudResources

/// The bundled word-cloud files, read where each build has them: in Xcode from the test host's bundle,
/// the files the app's loaders read; in the package, where `Bundle.main` is the test runner, from the
/// repository's `FRUSExplorer/Resources`, as a host outside the app reads them.
enum WordCloudResources {

    /// The bundled file `resource`.json, or `nil` when the build has none.
    static func url(_ resource: String) -> URL? {
        #if SWIFT_PACKAGE
        // `FRUSExplorer/Resources`, from this file's place in the repository.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/\(resource).json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
        #else
        return Bundle.main.url(forResource: resource, withExtension: "json")
        #endif
    }

    /// The bytes of the bundled file `resource`.json.
    static func data(_ resource: String) throws -> Data {
        let url = try #require(
            url(resource),
            "\(resource).json is not in the app bundle. If it was just regenerated, it needs `xcodegen generate` to be enrolled — followed by `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.")
        return try Data(contentsOf: url)
    }

    /// The bundled stopword lists, decoded by the kit as the app's loader decodes them.
    static func stopwords() throws -> WordCloudStopwordSet {
        try WordCloudStopwordSet(contentsOf: try #require(url("word-cloud-stopwords")))
    }

    /// The bundled lexicons, decoded by the kit as the app's loader decodes them.
    static func lexicons() throws -> WordCloudLexiconSet {
        try WordCloudLexiconSet(contentsOf: try #require(url("word-cloud-lexicons")))
    }

    /// The bundled references and the payloads' digests, read by URL through the kit, as a host reads its own.
    static func references() -> KeynessReferences {
        KeynessReferences(dictionaryAt: url(KeynessBaselineFile.resourceName(for: .dictionary)),
                          printedAt: url(KeynessBaselineFile.resourceName(for: .printed)),
                          lexiconsAt: url("word-cloud-lexicons"), stopwordsAt: url("word-cloud-stopwords"))
    }
}

// MARK: - The tagger a count walks

/// The tagger the moved suites count with: NaturalLanguage's where the platform has it, through the
/// readiness gate, as the app counts; and where it does not (Linux), the stand-in below, as S29a's
/// suites count there. A case's expectations hold for both, since the stand-in splits and lemmatises
/// the fixtures' words as NaturalLanguage does (``StandInWordCloudTaggerTests``).
enum WordCloudTestTagging {

    /// The tagger a moved suite's count walks.
    static var tagger: some WordCloudTagger & Sendable {
        #if canImport(NaturalLanguage)
        NaturalLanguageWordCloudTagger()
        #else
        StandInWordCloudTagger.fixtures
        #endif
    }
}

/// A tagger of tables, for the moved suites' counts where NaturalLanguage is missing.
///
/// A word is a run of letters and digits, with an apostrophe or a hyphen kept between two letters; its
/// lemma is the table's, or none, and its lexical class the table's, or `.other`; it names no one. So it
/// gives the fixtures' texts the words, lemmas and classes NaturalLanguage gives them, and the kit's
/// tokenizer counts them alike: the plural fold, the stopwords, the length and the lexicons are the
/// tokenizer's own, whatever the tagger.
struct StandInWordCloudTagger: WordCloudTagger, Sendable {

    let identity: WordCloudTokenizerIdentity
    let health: NaturalLanguageHealth
    /// Each word's lemma, by the word lowercased.
    let lemmas: [String: String]
    /// Each word's lexical class, by the word lowercased.
    let classes: [String: WordCloudLexicalClass]

    /// The tables the fixtures' texts need: the printed-form fallback's three documents and the
    /// suites' passages, with NaturalLanguage's lemmas for the words a dictionary-form count reads.
    static let fixtures = StandInWordCloudTagger(
        identity: WordCloudTokenizerIdentity(name: "StandIn", version: "1"),
        health: .fullyWorking,
        // NaturalLanguage's own lemmas, its quirks included: it gives "admirals" the abbreviation "adm.",
        // which the tokenizer refuses, so a dictionary-form count has no admirals.
        lemmas: ["negotiated": "negotiate", "negotiating": "negotiate", "negotiates": "negotiate",
                 "ratified": "ratify", "were": "be", "was": "be", "is": "be", "are": "be",
                 "delegates": "delegate", "envoys": "envoy", "admirals": "adm.", "terms": "term",
                 "memorandum": "memorandum", "last": "last"],
        classes: ["treaty": .noun, "delegates": .noun, "envoys": .noun, "admirals": .noun, "terms": .noun,
                  "memorandum": .noun, "negotiated": .verb, "negotiating": .verb, "ratified": .verb,
                  "were": .verb])

    func enumerateWords(in text: String, reading: WordCloudTagReading,
                        using body: (_ range: Range<String.Index>, _ lemma: String?,
                                     _ lexicalClass: () -> WordCloudLexicalClass?) -> Bool) {
        for range in Self.words(in: text) {
            let word = text[range].lowercased()
            let lemma = reading.contains(.lemmas) ? lemmas[word] : nil
            guard body(range, lemma, { classes[word] ?? .other }) else { return }
        }
    }

    func enumerateNames(in text: String,
                        using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        for range in Self.words(in: text) {
            guard body(range, nil) else { return }
        }
    }

    /// Each word of `text`, in order: a run of letters and digits, an apostrophe or a hyphen kept between
    /// two letters.
    static func words(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex
        func isWordCharacter(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        while index < text.endIndex {
            guard isWordCharacter(text[index]) else { index = text.index(after: index); continue }
            let start = index
            while index < text.endIndex {
                let c = text[index]
                if isWordCharacter(c) { index = text.index(after: index); continue }
                let next = text.index(after: index)
                if c == "'" || c == "’" || c == "-", next < text.endIndex, text[next].isLetter,
                   index > start, text[text.index(before: index)].isLetter {
                    index = next
                    continue
                }
                break
            }
            ranges.append(start..<index)
        }
        return ranges
    }
}

#if canImport(NaturalLanguage)
/// The stand-in counts the fixtures' texts as NaturalLanguage counts them, so a case that holds where
/// NaturalLanguage counts holds where the stand-in does. On Apple platforms only, where both exist.
@Suite("The stand-in tagger counts the fixtures as NaturalLanguage does (S29b)")
struct StandInWordCloudTaggerTests {

    @Test("Every fixture text, counted as printed and in dictionary forms, gives NaturalLanguage's counts",
          arguments: [WordCloudWordForm.printed, .dictionary])
    func countsAsNaturalLanguageDoes(wordForm: WordCloudWordForm) async throws {
        // The verdict before the first walk, as the app awaits it.
        let health = await NaturalLanguageReadiness.verdictWhenReady().health
        // A host whose language analysis gives no lemmas has no dictionary forms to compare with; its
        // printed forms are compared all the same.
        guard wordForm == .printed || health.lemmatizes else { return }
        let tokenizer = WordCloudTokenizer.configured(
            tuning: .standard, lens: .allTerms, includeDiplomatic: true, wordForm: wordForm,
            stopwords: try WordCloudResources.stopwords(), lexicons: try WordCloudResources.lexicons())
        for text in StandInFixtureTexts.all {
            var natural: [String: Int] = [:]
            var standIn: [String: Int] = [:]
            let naturalTotal = tokenizer.accumulate(from: text, into: &natural, tagger: NaturalLanguageWordCloudTagger())
            let standInTotal = tokenizer.accumulate(from: text, into: &standIn, tagger: StandInWordCloudTagger.fixtures)
            #expect(standIn == natural, "\(wordForm.rawValue): \(text.prefix(60))")
            #expect(standInTotal == naturalTotal)
        }
    }
}

/// The texts the moved suites count, which the stand-in is held to.
enum StandInFixtureTexts {
    static let all: [String] = [
        "1. Memorandum The delegates negotiated the treaty in Geneva. The envoys negotiated the treaty in Paris.",
        "2. Memorandum The admirals negotiated the treaty in London while the envoys were negotiating the treaty terms.",
        "3. Memorandum The delegates negotiated the treaty and the admirals ratified the treaty at last.",
    ]
}
#endif

// MARK: - The references a case ranks against

/// The keyness references the moved suites rank against: a value of the kit's, and in Xcode the same
/// files put in the app's loader, so that there each case also holds the app's lookup and ranking,
/// which read the loader, to the kit's answer.
///
/// One static, as the app's loader is one: a case injects, reads and clears on the main actor with no
/// suspension between, as the suites that inject into the loader always have.
@MainActor
enum KeynessFixtureReferences {

    /// What a case injected, as the kit reads it.
    static var current: KeynessReferences = .none

    /// Puts `dictionary` and `printed` in place with `digests`, each under the form its own stamp names,
    /// as `BundledKeynessBaseline.injectForTesting` puts them in the app's loader.
    static func inject(_ dictionary: KeynessBaselineFile?, printed: KeynessBaselineFile? = nil,
                       digests: (lexicons: String, stopwords: String)) {
        current = KeynessReferences(dictionary: dictionary, printed: printed,
                                    lexiconsDigest: digests.lexicons, stopwordsDigest: digests.stopwords)
        #if !SWIFT_PACKAGE
        BundledKeynessBaseline.injectForTesting(dictionary, printed: printed, digests: digests)
        #endif
    }

    /// Takes them away, as `BundledKeynessBaseline.injectForTesting(nil)` does.
    static func clear() {
        current = .none
        #if !SWIFT_PACKAGE
        BundledKeynessBaseline.injectForTesting(nil)
        #endif
    }

    /// Whether a reference is held: the kit's answer, and in Xcode the loader's, held to it.
    static var isAvailable: Bool {
        #if !SWIFT_PACKAGE
        #expect(BundledKeynessBaseline.isAvailable == current.isAvailable, "the app's loader holds what the kit holds")
        #endif
        return current.isAvailable
    }

    /// The kit's lookup over what a case injected, for NaturalLanguage's counts, as the app looks up;
    /// and in Xcode the app's, held to it.
    static func baseline(for lens: WordCloudLens, tuning: WordCloudTuning, includeDiplomatic: Bool,
                         languageAnalysis: NaturalLanguageHealth) -> KeynessReferences.Availability {
        let kit = current.baseline(for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                                   languageAnalysis: languageAnalysis, tokenizer: .naturalLanguage)
        #if !SWIFT_PACKAGE
        #expect(BundledKeynessBaseline.baseline(for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                                                languageAnalysis: languageAnalysis) == kit,
                "the app's lookup answers as the kit's")
        #endif
        return kit
    }

    /// The kit's ranking against what a case injected, for NaturalLanguage's counts; and in Xcode the
    /// app's, which reads the loader, held to it.
    static func rank(terms: [TermCount], scopeTotal: Int, fetchedTermCount: Int, termLimit: Int,
                     lens: WordCloudLens, tuning: WordCloudTuning, includeDiplomatic: Bool,
                     languageAnalysis: NaturalLanguageHealth) -> KeynessCloud.Outcome {
        let kit = KeynessCloud.rank(terms: terms, scopeTotal: scopeTotal, fetchedTermCount: fetchedTermCount,
                                    termLimit: termLimit, lens: lens, tuning: tuning,
                                    includeDiplomatic: includeDiplomatic, languageAnalysis: languageAnalysis,
                                    references: current, tokenizer: .naturalLanguage)
        #if !SWIFT_PACKAGE
        #expect(KeynessCloud.rank(terms: terms, scopeTotal: scopeTotal, fetchedTermCount: fetchedTermCount,
                                  termLimit: termLimit, lens: lens, tuning: tuning,
                                  includeDiplomatic: includeDiplomatic, languageAnalysis: languageAnalysis) == kit,
                "the app's ranking answers as the kit's")
        #endif
        return kit
    }
}
