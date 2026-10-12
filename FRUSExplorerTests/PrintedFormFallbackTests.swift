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

// The printed-form fallback (#1608).
//
// On a launch whose language analysis has no lemmatiser, Collocates used to refuse, and the word
// cloud's Distinctive sizing and Related Documents' shared-word chips were withheld. They now
// compare printed forms with a corpus reference counted as printed, and each says that it did, why,
// and that the result can differ from a device whose language analysis reduces words to their
// dictionary forms. A launch with a working lemmatiser does what it did.
//
// Every suite below runs the code a surface runs, under a verdict the test names, so none depends
// on what the host's own language analysis can do: the three counts take the verdict or the
// reference as a parameter (`CollocationConfiguration`, `WordFrequencyService.topTerms(…countedUnder:)`,
// `SemanticSharedTerms.evidence`). A control that needs a working lemmatiser asks the host first.
//
// Version history:
//   1.0 — #1608: initial implementation

// MARK: - Fixtures

/// The two verdicts the fallback turns on, and the references and the small index the suites share.
enum PrintedFormFixture {

    /// The owner's iPhone under iOS 27.0.1: lexical classes and names work, lemmas do not.
    static let unlemmatised = NaturalLanguageHealth(lemmatizes: false, classifiesWords: true,
                                                    recognizesNames: true)
    /// The iOS 26 simulators: nothing tags.
    static let nothingWorks = NaturalLanguageHealth(lemmatizes: false, classifiesWords: false,
                                                    recognizesNames: false)
    /// A lemmatiser with no lexical classes.
    static let unclassified = NaturalLanguageHealth(lemmatizes: true, classifiesWords: false,
                                                    recognizesNames: true)

    static let lexiconsDigest = "lexicons-1608"
    static let stopwordsDigest = "stopwords-1608"

    /// A reference file of `form`. The two differ in every figure, so a read of the wrong one shows.
    static func file(_ form: WordCloudWordForm,
                     tuning: WordCloudTuning = .standard,
                     includeDiplomatic: Bool = true,
                     stampedAs stamp: WordCloudWordForm? = nil) -> KeynessBaselineFile {
        let lenses: [WordCloudLens: (total: Int, distinct: Int, terms: [String: Int])]
        switch form {
        case .dictionary:
            lenses = [.allTerms: (1_000_000, 1_000, ["negotiate": 900, "treaty": 400, "envoy": 60]),
                      .topics: (500_000, 700, ["treaty": 400]),
                      .concepts: (40_000, 20, ["sovereignty": 40])]
        case .printed:
            lenses = [.allTerms: (1_000_100, 2_000, ["negotiated": 500, "negotiating": 300,
                                                    "negotiate": 100, "treaty": 380, "envoy": 55]),
                      .topics: (480_000, 900, ["treaty": 380]),
                      .concepts: (39_000, 20, ["sovereignty": 39])]
        }
        var packed: [String: KeynessBaselineFile.Lens] = [:]
        for (lens, value) in lenses {
            packed[lens.rawValue] = KeynessBaselineFile.Lens(
                totalTokens: value.total, distinctTerms: value.distinct, terms: value.terms,
                cutoffCount: value.terms.values.min() ?? 0)
        }
        return KeynessBaselineFile(
            version: 1,
            // A stamp of its own for each, so a ranking that says when its reference was made is
            // seen to read the file it ranked against.
            generated: form == .printed ? "2026-10-13" : "2026-10-12",
            provenance: CloudVectorsFile.Provenance(volumeCount: 553, documentCount: 314_616,
                                                    tuning: .standard, topTermsPerList: 50),
            termsPerLens: 20_000,
            configuration: .init(tuning: tuning, includeDiplomatic: includeDiplomatic,
                                 lexiconsDigest: lexiconsDigest, stopwordsDigest: stopwordsDigest,
                                 wordForm: stamp ?? form),
            lenses: packed)
    }

    /// Injects the references named, with digests that match them.
    @MainActor
    static func inject(dictionary: Bool = true, printed: Bool = true) {
        BundledKeynessBaseline.injectForTesting(
            dictionary ? file(.dictionary) : nil,
            printed: printed ? file(.printed) : nil,
            digests: (lexicons: lexiconsDigest, stopwords: stopwordsDigest))
    }

    /// Clears the seam, so the next `prepare()` reads the bundle.
    @MainActor
    static func clear() { BundledKeynessBaseline.injectForTesting(nil) }

    /// A reference value of `form` for the passes that take one, pricing the fixture index's words.
    static func reference(_ form: WordCloudWordForm, pricingTreaty: Bool = true) -> KeynessReference {
        var terms: [String: Int]
        switch form {
        case .dictionary: terms = ["negotiate": 44_000, "delegate": 9_000, "envoy": 500]
        case .printed: terms = ["negotiated": 40, "delegate": 9_000, "envoy": 500]
        }
        if pricingTreaty { terms["treaty"] = 50_000 }
        return KeynessReference(terms: terms, totalTokens: 1_000_000, cutoffCount: 12, wordForm: form,
                                distinctTerms: 250_000, generated: "2026-10-12")
    }

    /// Three short documents about one treaty. "negotiated" stands near "treaty" four times and
    /// "negotiating" once: four and one as printed, and five of "negotiate" in dictionary forms.
    /// None of the other words is a bundled stopword in either form.
    static let volumeXML = """
    <?xml version="1.0"?>
    <TEI><text><body>
    <div type="document" xml:id="d1">
      <head>1. Memorandum</head>
      <p>The delegates negotiated the treaty in Geneva. The envoys negotiated the treaty in Paris.</p>
    </div>
    <div type="document" xml:id="d2">
      <head>2. Memorandum</head>
      <p>The admirals negotiated the treaty in London while the envoys were negotiating the treaty terms.</p>
    </div>
    <div type="document" xml:id="d3">
      <head>3. Memorandum</head>
      <p>The delegates negotiated the treaty and the admirals ratified the treaty at last.</p>
    </div>
    </body></text></TEI>
    """

    /// An index of ``volumeXML`` in a temporary directory, with its pipeline and a search service.
    /// On the main actor, as its body is: a suite that injects a reference and ranks against it
    /// has to do both without a suspension between them.
    @MainActor
    static func withIndex(
        _ body: @MainActor (IndexingPipeline, SearchService) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSPrintedForms1608-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(volumeXML.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let databaseURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: databaseURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: databaseURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        try await body(pipeline, SearchService(fts5Store: store, pipeline: pipeline))
    }

    static let keys = ["d1", "d2", "d3"].map { WordCloudDocumentKey(volumeId: "vol1", documentId: $0) }
}

// MARK: - Which reference a verdict reads

/// `BundledKeynessBaseline.baseline` reads the reference counted in the form the verdict counts in.
///
/// `.serialized`, and no test awaits between injecting and reading: the loader holds one static, as
/// `BundledKeynessBaselineTests` says of its own cases.
@Suite("Printed-form fallback — which reference a verdict reads (#1608)", .serialized)
@MainActor
struct PrintedFormReferenceSelectionTests {

    private func ask(_ lens: WordCloudLens, _ health: NaturalLanguageHealth,
                     tuning: WordCloudTuning = .standard,
                     includeDiplomatic: Bool = true) -> BundledKeynessBaseline.Availability {
        BundledKeynessBaseline.baseline(for: lens, tuning: tuning, includeDiplomatic: includeDiplomatic,
                                        languageAnalysis: health)
    }

    private func reference(_ availability: BundledKeynessBaseline.Availability) -> KeynessReference? {
        if case .available(let reference) = availability { return reference }
        return nil
    }

    @Test("A verdict with a lemmatiser reads the dictionary-form reference, as it always has")
    func workingLemmatiserReadsDictionaryForms() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let found = try #require(reference(ask(.allTerms, .fullyWorking)))
        #expect(found.wordForm == .dictionary)
        #expect(found.terms == ["negotiate": 900, "treaty": 400, "envoy": 60])
        #expect(found.totalTokens == 1_000_000)
        #expect(found.distinctTerms == 1_000)
        #expect(found.generated == "2026-10-12")
        #expect(found.cutoffCount == 60)
    }

    @Test("A verdict with no lemmatiser reads the reference counted as printed, with that file's own figures")
    func noLemmatiserReadsPrintedForms() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let found = try #require(reference(ask(.allTerms, PrintedFormFixture.unlemmatised)))
        #expect(found.wordForm == .printed)
        #expect(found.terms["negotiated"] == 500)
        #expect(found.terms["negotiate"] == 100, "the printed file's own count, not the dictionary file's 900")
        #expect(found.totalTokens == 1_000_100)
        #expect(found.distinctTerms == 2_000)
        #expect(found.generated == "2026-10-13")
        #expect(found.cutoffCount == 55)
    }

    @Test("The printed reference serves every word lens the verdict can count",
          arguments: [WordCloudLens.allTerms, .topics, .concepts])
    func printedReferenceServesEveryCountableLens(lens: WordCloudLens) throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let printed = try #require(reference(ask(lens, PrintedFormFixture.unlemmatised)),
                                   "\(lens.rawValue) has no reference on a launch with no lemmatiser")
        #expect(printed.wordForm == .printed)
        // The control: the same lens with a working lemmatiser reads the other file.
        let dictionary = try #require(reference(ask(lens, .fullyWorking)))
        #expect(dictionary.wordForm == .dictionary)
        #expect(printed.totalTokens != dictionary.totalTokens)
    }

    @Test("Where nothing tags, All terms still reads the printed reference and a part-of-speech lens has none")
    func nothingWorking() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        // The iOS 26 simulators. All terms counts every word as printed, so it can be compared.
        #expect(reference(ask(.allTerms, PrintedFormFixture.nothingWorks))?.wordForm == .printed)
        #expect(reference(ask(.concepts, PrintedFormFixture.nothingWorks))?.wordForm == .printed)
        // Topics counted nothing without lexical classes: there is nothing to compare in any form.
        #expect(ask(.topics, PrintedFormFixture.nothingWorks) == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("A part-of-speech lens counted without lexical classes has no reference though both files are loaded")
    func noLexicalClasses() {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        #expect(ask(.topics, PrintedFormFixture.unclassified) == .unavailable(.languageAnalysisUnavailable))
        #expect(reference(ask(.allTerms, PrintedFormFixture.unclassified))?.wordForm == .dictionary)
    }

    @Test("With no printed reference loaded, a launch with no lemmatiser is refused as it was before")
    func printedFileMissing() {
        PrintedFormFixture.inject(printed: false)
        defer { PrintedFormFixture.clear() }
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised) == .unavailable(.languageAnalysisUnavailable))
        // The control: the dictionary file still answers a verdict that lemmatises.
        #expect(reference(ask(.allTerms, .fullyWorking))?.wordForm == .dictionary)
    }

    @Test("With only the printed reference loaded, a verdict that lemmatises has no artifact")
    func dictionaryFileMissing() {
        PrintedFormFixture.inject(dictionary: false)
        defer { PrintedFormFixture.clear() }
        #expect(ask(.allTerms, .fullyWorking) == .unavailable(.noArtifact))
        #expect(reference(ask(.allTerms, PrintedFormFixture.unlemmatised))?.wordForm == .printed)
    }

    @Test("A file is the reference of the form its own stamp names, never of the form it was offered as")
    func aFileIsHeldToItsOwnStamp() {
        let dictionary = PrintedFormFixture.file(.dictionary)
        let printed = PrintedFormFixture.file(.printed)
        #expect(BundledKeynessBaseline.isReference(dictionary, for: .dictionary))
        #expect(BundledKeynessBaseline.isReference(printed, for: .printed))
        #expect(!BundledKeynessBaseline.isReference(dictionary, for: .printed))
        #expect(!BundledKeynessBaseline.isReference(printed, for: .dictionary))

        // Offered as the printed reference, a file of dictionary-form counts is not used: printed
        // forms scored against it is the error the second file exists to end.
        BundledKeynessBaseline.injectForTesting(
            dictionary, printed: PrintedFormFixture.file(.printed, stampedAs: .dictionary),
            digests: (lexicons: PrintedFormFixture.lexiconsDigest, stopwords: PrintedFormFixture.stopwordsDigest))
        defer { PrintedFormFixture.clear() }
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised) == .unavailable(.languageAnalysisUnavailable))
        #expect(reference(ask(.allTerms, .fullyWorking))?.wordForm == .dictionary)
    }

    @Test("A printed scope is held to the reference's settings like any other")
    func settingsStillApplyToThePrintedReference() {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        // One setting a reader can restore, per case; the fallback does not waive any of them.
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised, includeDiplomatic: false)
                == .unavailable(.configurationMismatch([.diplomaticLayer])))
        // The plural fold above all: in a printed count it is the only thing joining "treaties" to
        // "treaty", so a scope that folds differently differs from the reference in every plural.
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised, tuning: .init(foldPlurals: false))
                == .unavailable(.configurationMismatch([.foldPlurals])))
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised, tuning: .init(filterMarkings: false))
                == .unavailable(.configurationMismatch([.filterMarkings])))
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised, tuning: .init(minimumLength: 2))
                == .unavailable(.configurationMismatch([.minimumLength])))
        // A longer minimum only trims the scope, in this form as in the other.
        #expect(reference(ask(.allTerms, PrintedFormFixture.unlemmatised, tuning: .init(minimumLength: 5)))?
            .wordForm == .printed)
    }

    @Test("An entity lens keeps its structural answer on a launch with no lemmatiser")
    func entityLensIsStillNotPriced() {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        #expect(ask(.people, PrintedFormFixture.unlemmatised) == .unavailable(.lensNotPriced(.people)))
    }

    @Test("Nothing loaded still reads as missing, whichever form the verdict counts in")
    func nothingLoaded() {
        PrintedFormFixture.clear()
        #expect(ask(.allTerms, PrintedFormFixture.unlemmatised) == .unavailable(.noArtifact))
        #expect(ask(.allTerms, .fullyWorking) == .unavailable(.noArtifact))
        #expect(!BundledKeynessBaseline.isAvailable)
    }
}

// MARK: - Distinctive

/// The word cloud's Distinctive sizing over a cloud counted as printed.
@Suite("Printed-form fallback — the word cloud's Distinctive sizing (#1608)", .serialized)
@MainActor
struct PrintedFormKeynessTests {

    private func rank(_ terms: [(String, Int)], _ health: NaturalLanguageHealth,
                      lens: WordCloudLens = .allTerms) -> KeynessCloud.Outcome {
        KeynessCloud.rank(terms: terms.map { TermCount(term: $0.0, count: $0.1) }, scopeTotal: 10_000,
                          fetchedTermCount: terms.count, termLimit: 220, lens: lens, tuning: .standard,
                          includeDiplomatic: true, languageAnalysis: health)
    }

    private func ranking(_ outcome: KeynessCloud.Outcome) -> KeynessCloud.Ranking? {
        if case .ranked(let ranking) = outcome { return ranking }
        return nil
    }

    @Test("Terms counted as printed are ranked against the printed reference, and the ranking says so")
    func printedTermsAreRankedAgainstThePrintedReference() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let ranked = try #require(ranking(rank([("negotiated", 60), ("treaty", 300)],
                                               PrintedFormFixture.unlemmatised)))
        #expect(ranked.wordForm == .printed)
        let negotiated = try #require(ranked.scores.first { $0.term == "negotiated" })
        // Priced by the printed file. Against the dictionary file it would have been 0: a word the
        // corpus never used, at the top of the list.
        #expect(negotiated.referenceCount == 500)
        // What the caveat and the CSV state about the reference is the printed file's.
        #expect(ranked.referenceRetained == 5)
        #expect(ranked.referenceDistinct == 2_000)
        #expect(ranked.referenceCutoffCount == 55)
        #expect(ranked.generated == "2026-10-13")
    }

    @Test("The same terms under a verdict that lemmatises are ranked against the dictionary reference")
    func dictionaryTermsAreUnchanged() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let ranked = try #require(ranking(rank([("negotiate", 60), ("treaty", 300)], .fullyWorking)))
        #expect(ranked.wordForm == .dictionary)
        #expect(ranked.scores.first { $0.term == "negotiate" }?.referenceCount == 900)
        #expect(ranked.referenceRetained == 3)
        #expect(ranked.referenceDistinct == 1_000)
        #expect(ranked.generated == "2026-10-12")
    }

    @Test("With no printed reference, a cloud counted as printed still has no ranking")
    func refusedWithoutThePrintedFile() {
        PrintedFormFixture.inject(printed: false)
        defer { PrintedFormFixture.clear() }
        #expect(rank([("negotiated", 60)], PrintedFormFixture.unlemmatised)
                == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("A part-of-speech lens counted as printed is ranked too, where its lexical classes work")
    func partOfSpeechLens() throws {
        PrintedFormFixture.inject()
        defer { PrintedFormFixture.clear() }
        let ranked = try #require(ranking(rank([("treaty", 300)], PrintedFormFixture.unlemmatised, lens: .topics)))
        #expect(ranked.wordForm == .printed)
        #expect(ranked.scores.first?.referenceCount == 380)
        #expect(rank([("treaty", 300)], PrintedFormFixture.nothingWorks, lens: .topics)
                == .unavailable(.languageAnalysisUnavailable))
    }
}

// MARK: - Collocates

/// Collocates over neighbours counted as printed.
@Suite("Printed-form fallback — Collocates (#1608)")
struct PrintedFormCollocationTests {

    private func rank(counted form: WordCloudWordForm, against reference: WordCloudWordForm,
                      counts: [String: Int] = ["negotiated": 40, "delegate": 12],
                      anchorCount: Int = 60) -> CollocationAnalysis.Outcome {
        CollocationAnalysis.rank(
            counts: counts, windowTokenCount: 10_000, anchorLemmas: [], windowSize: 10,
            documentsScanned: 40, documentsInScope: 40, documentsOffered: 40,
            anchorCount: anchorCount, omittedAnchorCount: 0,
            wordForm: form, reference: PrintedFormFixture.reference(reference))
    }

    private func result(_ outcome: CollocationAnalysis.Outcome) -> CollocationResult? {
        if case .ranked(let result) = outcome { return result }
        return nil
    }

    @Test("Neighbours counted as printed are ranked against a printed reference, and the result carries the note")
    func printedAgainstPrinted() throws {
        let ranked = try #require(result(rank(counted: .printed, against: .printed)))
        #expect(ranked.wordForm == .printed)
        #expect(ranked.scores.first { $0.term == "negotiated" }?.referenceCount == 40)
        #expect(ranked.generated == "2026-10-12")
        #expect(ranked.printedFormsNote != nil)
    }

    @Test("Neighbours counted in dictionary forms are ranked as before, and carry no note")
    func dictionaryAgainstDictionary() throws {
        // 800 in 10,000 window tokens against 44,000 in a million: used more here than corpus-wide.
        let ranked = try #require(result(rank(counted: .dictionary, against: .dictionary,
                                              counts: ["negotiate": 800, "delegate": 12])))
        #expect(ranked.wordForm == .dictionary)
        #expect(ranked.scores.first { $0.term == "negotiate" }?.referenceCount == 44_000)
        #expect(ranked.printedFormsNote == nil)
    }

    @Test("Neighbours counted as printed are never ranked against a dictionary-form reference")
    func printedAgainstDictionaryIsRefused() {
        #expect(rank(counted: .printed, against: .dictionary) == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("Neighbours counted in dictionary forms are never ranked against a printed reference")
    func dictionaryAgainstPrintedIsRefused() {
        #expect(rank(counted: .dictionary, against: .printed) == .unavailable(.languageAnalysisUnavailable))
    }

    @Test("The refusal comes before anything is said about the query")
    func theFormCheckPrecedesNoMatches() {
        // No anchors at all, which alone is "no matches". Said of a count that could not have been
        // compared, that would be a claim about the query that nothing measured.
        #expect(rank(counted: .printed, against: .dictionary, anchorCount: 0)
                == .unavailable(.languageAnalysisUnavailable))
        // The control: the same empty scan against a comparable reference is "no matches".
        #expect(rank(counted: .printed, against: .printed, anchorCount: 0) == .unavailable(.noMatches))
    }

    @Test("The live configuration counts in the form of the verdict it is handed, and keeps the verdict")
    @MainActor
    func liveConfigurationFollowsTheVerdict() {
        let printed = CollocationConfiguration.live(languageAnalysis: PrintedFormFixture.unlemmatised)
        #expect(printed.tokenizer.wordForm == .printed)
        #expect(printed.languageAnalysis == PrintedFormFixture.unlemmatised)
        let dictionary = CollocationConfiguration.live(languageAnalysis: .fullyWorking)
        #expect(dictionary.tokenizer.wordForm == .dictionary)
        #expect(dictionary.languageAnalysis == .fullyWorking)
        // A lemmatiser with no lexical classes still counts dictionary forms.
        #expect(CollocationConfiguration.live(languageAnalysis: PrintedFormFixture.unclassified)
            .tokenizer.wordForm == .dictionary)
    }

    /// A configuration at the standard settings, built as `live(languageAnalysis:)` builds one, so
    /// the scans below do not read whatever settings another test left in the host's defaults.
    private func configuration(_ health: NaturalLanguageHealth) -> CollocationConfiguration {
        CollocationConfiguration(
            tuning: .standard, includeDiplomatic: true, languageAnalysis: health,
            tokenizer: WordCloudTokenizer.configured(
                tuning: .standard, lens: .allTerms, includeDiplomatic: true,
                wordForm: health.wordForm))
    }

    @Test("A real scan under a verdict with no lemmatiser ranks the printed forms near the matches")
    func scanCountsPrintedForms() async throws {
        try await PrintedFormFixture.withIndex { _, service in
            let parameters = SearchParameters(keywords: "treaty")
            let results = try await service.search(parameters: parameters)
            #expect(results.count == 3)

            let outcome = try await service.collocation(
                for: results, parameters: parameters, windowSize: 10,
                configuration: configuration(PrintedFormFixture.unlemmatised),
                reference: PrintedFormFixture.reference(.printed))
            let ranked = try #require(result(outcome), "\(outcome)")
            #expect(ranked.wordForm == .printed)
            // Four of "negotiated", which clears the floor of three; "negotiating" is a word of its
            // own and does not. In dictionary forms the two are five of "negotiate". True on every
            // host: the tokenizer was told to count as printed, and reads no lemma if there is one.
            let negotiated = try #require(ranked.scores.first { $0.term == "negotiated" }, "\(ranked.scores)")
            #expect(negotiated.scopeCount == 4)
            #expect(negotiated.referenceCount == 40)
            #expect(!ranked.scores.contains { $0.term == "negotiate" })
            #expect(!ranked.scores.contains { $0.term == "treaty" }, "the query's own word is not its collocate")
            #expect(ranked.printedFormsNote != nil)
        }
    }

    @Test("The same scan under this host's own verdict is ranked in its form, or refused against the other")
    func scanUnderTheHostsVerdict() async throws {
        let health = await NaturalLanguageReadiness.verdictWhenReady().health
        try await PrintedFormFixture.withIndex { _, service in
            let parameters = SearchParameters(keywords: "treaty")
            let results = try await service.search(parameters: parameters)
            let outcome = try await service.collocation(
                for: results, parameters: parameters, windowSize: 10,
                configuration: configuration(health),
                reference: PrintedFormFixture.reference(.dictionary))
            if health.lemmatizes {
                let ranked = try #require(result(outcome), "\(outcome)")
                #expect(ranked.wordForm == .dictionary)
                #expect(ranked.scores.first { $0.term == "negotiate" }?.scopeCount == 5, "\(ranked.scores)")
                #expect(!ranked.scores.contains { $0.term == "negotiated" })
                #expect(ranked.printedFormsNote == nil)
            } else {
                // A host with no lemmatiser counted as printed, and was handed the dictionary-form
                // reference: the scan refuses rather than rank one against the other.
                #expect(outcome == .unavailable(.languageAnalysisUnavailable))
            }
        }
    }
}

// MARK: - The cloud's count

/// `WordFrequencyService` counts in the form of the verdict it stamps the result with, and
/// Distinctive ranks that result against the reference of the same form.
@Suite("Printed-form fallback — the cloud's count and its ranking (#1608)", .serialized)
@MainActor
struct PrintedFormCloudCountTests {

    private func count(_ service: WordFrequencyService,
                       under health: NaturalLanguageHealth) async throws -> WordCloudResult {
        try await service.topTerms(
            signature: "test-1608-\(UUID().uuidString)", keys: PrintedFormFixture.keys, limit: 50,
            includeDiplomaticStopwords: true, countedUnder: health)
    }

    @Test("A cloud counted under a verdict with no lemmatiser is a count of printed forms, stamped with that verdict, and Distinctive ranks it")
    func countedAsPrintedAndRanked() async throws {
        try await PrintedFormFixture.withIndex { pipeline, _ in
            let result = try await count(WordFrequencyService(pipeline: pipeline),
                                         under: PrintedFormFixture.unlemmatised)
            let counts = Dictionary(uniqueKeysWithValues: result.terms.map { ($0.term, $0.count) })
            #expect(result.documentCount == 3)
            #expect(counts["negotiated"] == 4, "\(counts)")
            #expect(counts["negotiating"] == 1)
            #expect(counts["negotiate"] == nil, "a lemma was read on a count told to be printed")
            #expect(counts["treaty"] == 6)
            // The plural fold still applies, as it always has to a word with no lemma.
            #expect(counts["delegate"] == 2 && counts["delegates"] == nil)
            #expect(result.languageAnalysis == PrintedFormFixture.unlemmatised)
            #expect(WordCloudDisplayState.countedAsPrinted(result, lens: .allTerms))
            // Not written to the disk cache: another launch's lemmatiser may work.
            #expect(!WordFrequencyService.isPersistable(countedUnder: PrintedFormFixture.unlemmatised,
                                                        lens: .allTerms))

            // The view's own call, with the result's own stamp. No await from here to the end.
            PrintedFormFixture.inject()
            defer { PrintedFormFixture.clear() }
            let stamp = try #require(result.languageAnalysis)
            let outcome = KeynessCloud.rank(
                terms: result.terms, scopeTotal: result.totalTokenCount,
                fetchedTermCount: result.terms.count, termLimit: 50, lens: .allTerms,
                tuning: .standard, includeDiplomatic: true, languageAnalysis: stamp)
            guard case .ranked(let ranking) = outcome else {
                Issue.record("a cloud counted as printed has no Distinctive ranking: \(outcome)")
                return
            }
            #expect(ranking.wordForm == .printed)
            #expect(ranking.scores.first { $0.term == "negotiated" }?.referenceCount == 500)
            #expect(WordCloudDisplayState.comparedAsPrintedNote(ranking) != nil)
        }
    }

    @Test("Under this host's own verdict the cloud is counted in its form")
    func countedUnderTheHostsVerdict() async throws {
        let health = await NaturalLanguageReadiness.verdictWhenReady().health
        try await PrintedFormFixture.withIndex { pipeline, _ in
            let result = try await count(WordFrequencyService(pipeline: pipeline), under: health)
            let counts = Dictionary(uniqueKeysWithValues: result.terms.map { ($0.term, $0.count) })
            #expect(result.languageAnalysis == health)
            if health.lemmatizes {
                #expect(counts["negotiate"] == 5, "\(counts)")
                #expect(counts["negotiated"] == nil)
                #expect(!WordCloudDisplayState.countedAsPrinted(result, lens: .allTerms))
            } else {
                #expect(counts["negotiated"] == 4, "\(counts)")
                #expect(WordCloudDisplayState.countedAsPrinted(result, lens: .allTerms))
            }
        }
    }
}

// MARK: - Related Documents

/// Related Documents' shared-word chips, compared as printed.
@Suite("Printed-form fallback — Related Documents' shared-word chips (#1608)")
@MainActor
struct PrintedFormSharedTermsTests {

    private let d1 = DocumentKey(volumeId: "vol1", documentId: "d1")
    private let d2 = DocumentKey(volumeId: "vol1", documentId: "d2")
    private let d3 = DocumentKey(volumeId: "vol1", documentId: "d3")

    @Test("Against the printed reference, two documents share the words both print, rarest first, in the anchor's spelling")
    func chipsComparePrintedForms() async throws {
        try await PrintedFormFixture.withIndex { pipeline, _ in
            let evidence = await SemanticSharedTerms.evidence(
                anchor: d1, candidates: [d2, d3], pipeline: pipeline,
                reference: PrintedFormFixture.reference(.printed))
            #expect(evidence.wordForm == .printed)
            // d1 and d2 both print "negotiated" (40 corpus-wide), "envoys" (500) and "treaty"
            // (50,000). d2's "negotiating" is no match for d1's "negotiated".
            #expect(evidence.terms[d2] == ["negotiated", "envoys", "treaty"], "\(evidence.terms)")
            // d1 and d3 both print "negotiated", "delegates" (9,000) and "treaty". The plural is
            // counted folded and shown as the anchor prints it.
            #expect(evidence.terms[d3] == ["negotiated", "delegates", "treaty"], "\(evidence.terms)")
            #expect(evidence.printedFormsNote != nil)
        }
    }

    @Test("A word the printed reference does not price is skipped, not shown as the rarest")
    func unpricedPrintedWordIsSkipped() async throws {
        try await PrintedFormFixture.withIndex { pipeline, _ in
            let evidence = await SemanticSharedTerms.evidence(
                anchor: d1, candidates: [d2], pipeline: pipeline,
                reference: PrintedFormFixture.reference(.printed, pricingTreaty: false))
            #expect(evidence.terms[d2] == ["negotiated", "envoys"], "\(evidence.terms)")
        }
    }

    @Test("Against the dictionary-form reference, a host that lemmatises shares the dictionary forms")
    func chipsCompareDictionaryFormsWhereTheHostCan() async throws {
        let health = await NaturalLanguageReadiness.verdictWhenReady().health
        try await PrintedFormFixture.withIndex { pipeline, _ in
            let evidence = await SemanticSharedTerms.evidence(
                anchor: d1, candidates: [d2], pipeline: pipeline,
                reference: PrintedFormFixture.reference(.dictionary))
            #expect(evidence.wordForm == .dictionary)
            #expect(evidence.printedFormsNote == nil)
            // Only a host with a lemmatiser can say what the dictionary forms are.
            if health.lemmatizes {
                // "envoy" (500), then "negotiate" (44,000), then "treaty" (50,000): d2's
                // "negotiating" is now a match for d1's "negotiated".
                #expect(evidence.terms[d2] == ["envoys", "negotiated", "treaty"], "\(evidence.terms)")
            }
        }
    }

    @Test("A printed form the plural fold clipped is shown as the anchor prints it")
    func clippedFormsWearTheAnchorsSpelling() {
        // The fold knows no names, so "Dulles" is counted as "dulle". The chip is the page's word.
        #expect(WordCloudTokenizer.singularize("dulles") == "dulle")
        #expect(SemanticSharedTerms.displayForm(for: "dulle", in: "Secretary Dulles replied at once.") == "Dulles")
        #expect(SemanticSharedTerms.displayForm(for: "envoy", in: "The envoys met.") == "envoys")
    }

    // One fixture for each conjunct of the note's rule.

    @Test("The note is for chips compared as printed")
    func noteForPrintedChips() {
        #expect(SemanticSharedTerms.Evidence(terms: [d2: ["envoys"]], wordForm: .printed)
            .printedFormsNote != nil)
    }

    @Test("Chips compared in dictionary forms carry no note")
    func noNoteForDictionaryChips() {
        #expect(SemanticSharedTerms.Evidence(terms: [d2: ["envoys"]], wordForm: .dictionary)
            .printedFormsNote == nil)
    }

    @Test("A printed pass that put no chip on any row says nothing")
    func noNoteWithoutChips() {
        #expect(SemanticSharedTerms.Evidence(terms: [:], wordForm: .printed).printedFormsNote == nil)
        #expect(SemanticSharedTerms.Evidence.none.printedFormsNote == nil)
    }
}

// MARK: - What each surface says

/// The owner's condition (2026-09-29, restated 2026-10-12): every surface that falls back says that
/// it did, says why, and says that results can differ from a device whose language analysis
/// reduces words to their dictionary forms — a Mac, or another iPhone or iPad.
@Suite("Printed-form fallback — what each surface says (#1608)")
struct PrintedFormWordingTests {

    private func printedRanking(_ form: WordCloudWordForm) -> KeynessCloud.Ranking {
        KeynessCloud.Ranking(scores: [], candidateCount: 1, rankedAmongTopFrequent: false,
                             minimumScopeCount: 3, referenceRetained: 5, referenceDistinct: 2_000,
                             referenceCutoffCount: 55, generated: "2026-10-12", wordForm: form)
    }

    private func cloud(_ health: NaturalLanguageHealth?, terms: Int = 5) -> WordCloudResult {
        var result = WordCloudResult(
            terms: (0..<terms).map { TermCount(term: "term\($0)", count: 10 - $0) },
            documentCount: 3, totalTokenCount: 100)
        result.languageAnalysis = health
        return result
    }

    private func collocation(_ form: WordCloudWordForm) -> CollocationResult {
        CollocationResult(scores: [], windowSize: 10, documentsScanned: 3, documentsInScope: 3,
                          documentsOffered: 3, anchorCount: 6, omittedAnchorCount: 0,
                          windowTokenCount: 20, minimumCount: 3, referenceCutoffCount: 12,
                          generated: "2026-10-12", wordForm: form)
    }

    /// Every on-screen note of the fallback, and the CSV's caveat, with the name it fails under.
    private var fallbackNotes: [(name: String, text: String?)] {
        [("Collocates", collocation(.printed).printedFormsNote),
         ("Word Cloud, Distinctive", WordCloudDisplayState.comparedAsPrintedNote(printedRanking(.printed))),
         ("Word Cloud, counted as printed",
          WordCloudDisplayState.countedAsPrintedNote(cloud(PrintedFormFixture.unlemmatised), lens: .allTerms)),
         ("Related Documents",
          SemanticSharedTerms.Evidence(terms: [DocumentKey(volumeId: "v", documentId: "d"): ["envoys"]],
                                       wordForm: .printed).printedFormsNote),
         ("Word Cloud CSV, keyness", WordCloudDisplayState.comparedAsPrintedCaveat(printedRanking(.printed)))]
    }

    @Test("Each surface says that it compared or counted as printed, why, and that another device can differ")
    func everySurfaceMeetsTheOwnersCondition() throws {
        #expect(fallbackNotes.count == 5)
        for (name, text) in fallbackNotes {
            let note = try #require(text, "\(name) says nothing when it falls back")
            // That it did.
            #expect(note.localizedCaseInsensitiveContains("as printed"), "\(name) does not say it fell back: \(note)")
            // Why: the device's language analysis is not reducing words to their dictionary forms.
            #expect(note.contains("dictionary forms"), "\(name) does not say why: \(note)")
            // That results can differ, and from what.
            #expect(note.contains("a Mac, or another iPhone or iPad"),
                    "\(name) does not name the devices its result can differ from: \(note)")
            #expect(note.contains("differ"), "\(name) does not say the result can differ: \(note)")
        }
    }

    @Test("The on-screen notes give a verb as their example, which a printed count does keep apart")
    func examplesAreTrueOfAPrintedCount() throws {
        // "negotiation" and "negotiations" would be a false example: with plural folding on, a
        // printed count folds the plural by rule and counts one word, as a dictionary count does.
        for (name, text) in fallbackNotes where name != "Word Cloud, counted as printed"
            && name != "Word Cloud CSV, keyness" {
            let note = try #require(text)
            #expect(note.contains("“negotiate”") && note.contains("“negotiated”"), "\(name): \(note)")
            #expect(!note.contains("negotiations"), "\(name): \(note)")
        }
        let caveat = try #require(WordCloudDisplayState.countedAsPrintedCaveat(
            cloud(PrintedFormFixture.unlemmatised), lens: .allTerms))
        #expect(caveat.contains("“negotiate” and “negotiated” are two words"), "\(caveat)")
        #expect(!caveat.contains("negotiations"), "\(caveat)")
        // And the claim itself, on the tokenizer: the pair is one word folded, and two as printed.
        #expect(WordCloudTokenizer.singularize("negotiations") == "negotiation")
        #expect(WordCloudTokenizer.singularize("negotiated") == "negotiated")
    }

    @Test("A ranking or a count in dictionary forms says none of it")
    func dictionaryFormsSayNothing() {
        #expect(collocation(.dictionary).printedFormsNote == nil)
        #expect(WordCloudDisplayState.comparedAsPrintedNote(printedRanking(.dictionary)) == nil)
        #expect(WordCloudDisplayState.comparedAsPrintedNote(nil) == nil)
        #expect(WordCloudDisplayState.comparedAsPrintedCaveat(printedRanking(.dictionary)) == nil)
        #expect(WordCloudDisplayState.comparedAsPrintedCaveat(nil) == nil)
        #expect(!WordCloudDisplayState.comparedAsPrinted(nil))
        #expect(!WordCloudDisplayState.comparedAsPrinted(printedRanking(.dictionary)))
        #expect(WordCloudDisplayState.comparedAsPrinted(printedRanking(.printed)))
        #expect(WordCloudDisplayState.printedFormsNote(cloud(.fullyWorking), lens: .allTerms,
                                                       ranking: printedRanking(.dictionary)) == nil)
        #expect(WordCloudDisplayState.printedFormsCaptionSegment(cloud(.fullyWorking), lens: .allTerms,
                                                                 ranking: printedRanking(.dictionary)) == nil)
    }

    @Test("The cloud's header prints the ranking's line under Distinctive and the count's under Frequency")
    func headerLineFollowsTheMeasure() {
        let counted = cloud(PrintedFormFixture.unlemmatised)
        let underDistinctive = WordCloudDisplayState.printedFormsNote(
            counted, lens: .allTerms, ranking: printedRanking(.printed))
        let underFrequency = WordCloudDisplayState.printedFormsNote(counted, lens: .allTerms, ranking: nil)
        #expect(underDistinctive == WordCloudDisplayState.comparedAsPrintedNote(printedRanking(.printed)))
        #expect(underFrequency == WordCloudDisplayState.countedAsPrintedNote(counted, lens: .allTerms))
        #expect(underDistinctive != underFrequency)
        #expect(underDistinctive?.hasPrefix("Counted and compared as printed") == true)
        #expect(underFrequency?.hasPrefix("Counted as printed") == true)
    }

    @Test("A Distinctive export names the printed reference in its axis label and its caption")
    func exportsNameThePrintedReference() {
        let counted = cloud(PrintedFormFixture.unlemmatised)
        #expect(WordCloudDisplayState.keynessAxisLabel(for: printedRanking(.printed))
                == "Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference, both counted as printed")
        #expect(WordCloudDisplayState.keynessAxisLabel(for: printedRanking(.dictionary))
                == "Ranked by keyness (log-likelihood) against the bundled FRUS corpus reference")
        #expect(WordCloudDisplayState.printedFormsCaptionSegment(counted, lens: .allTerms,
                                                                 ranking: printedRanking(.printed))
                == "counted and compared as printed, not in dictionary forms")
        // Under Frequency the caption keeps the segment it has had since #1373.
        #expect(WordCloudDisplayState.printedFormsCaptionSegment(counted, lens: .allTerms, ranking: nil)
                == "counted as printed, not in dictionary forms")
    }
}

// MARK: - Wiring

/// The calls each surface has to make, read where they are written. The rules are run above; a
/// surface that stopped making the call would compile and pass them.
@Suite("Printed-form fallback — wiring (#1608)")
struct PrintedFormWiringTests {

    private typealias Scan = NaturalLanguageReadinessScanTests

    private func code(_ path: String) throws -> String {
        let text = Scan.code(try String(contentsOf: Scan.repoRoot.appending(path: path), encoding: .utf8))
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    /// The body of the declaration that begins `header`, with all whitespace removed.
    private func body(of header: String, in path: String) throws -> String {
        let source = try code(path)
        let declaration = try #require(source.range(of: header), "\(header) is no longer in \(path)")
        let range = try #require(Scan.braceBody(in: source, after: declaration.upperBound))
        return squeezed(source[range])
    }

    private func squeezed(_ text: some StringProtocol) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(Character.init))
    }

    @Test("Both Search hosts take the tokenizer and the reference from one verdict",
          arguments: ["FRUSExplorer/Search/SearchView.swift", "FRUSExplorer/App/SearchSheet.swift"])
    func hostsUseOneVerdict(path: String) throws {
        let rebuild = try body(of: "private func rebuildCollocation() async", in: path)
        #expect(rebuild.contains(squeezed(
            "let configuration = CollocationConfiguration.live(languageAnalysis: languageAnalysis)")))
        // The reference is read for the verdict the configuration holds: the value its tokenizer
        // was built from. Handing the lookup a verdict read separately is how the two diverge.
        #expect(rebuild.contains(squeezed(
            "includeDiplomatic: configuration.includeDiplomatic, languageAnalysis: configuration.languageAnalysis)")),
                "\(path) does not read the reference for the configuration's own verdict")
        #expect(rebuild.contains(squeezed("configuration: configuration, reference: reference)")),
                "\(path) does not hand the scan the reference it read")
        // Exactly one verdict is awaited in the rebuild.
        #expect(rebuild.components(separatedBy: "verdictWhenReady()").count == 2)
    }

    @Test("The collocates list opens with the note of a ranking of printed forms")
    func collocatesListShowsTheNote() throws {
        let list = try body(of: "private func list(_ result: CollocationResult) -> some View",
                            in: "FRUSExplorer/Search/CollocationView.swift")
        let note = try #require(list.range(of: squeezed("if let note = result.printedFormsNote {")))
        let rows = try #require(list.range(of: "ForEach("))
        #expect(note.upperBound <= rows.lowerBound, "the note is not above the rows")
    }

    @Test("The scan tells the ranking the form its own tokenizer counted in")
    func scanReportsTheTokenizersForm() throws {
        let scan = try body(of: "func collocation(",
                            in: "FRUSExplorer/Search/SearchService+Collocation.swift")
        #expect(scan.contains(squeezed("wordForm: configuration.tokenizer.wordForm, reference: reference")))
    }

    @Test("The cloud's count is made in the form of the verdict it is stamped with")
    func cloudCountsInItsStampsForm() throws {
        let source = try code("FRUSExplorer/Analytics/WordCloud/WordFrequencyService.swift")
        // The second `topTerms`: the count itself, which takes the verdict.
        let declaration = try #require(source.range(of: "countedUnder languageAnalysis: NaturalLanguageHealth,"))
        let count = squeezed(source[try #require(Scan.braceBody(in: source, after: declaration.upperBound))])
        #expect(count.contains(squeezed("wordForm: languageAnalysis.wordForm")))
        #expect(count.contains(squeezed("result.languageAnalysis = languageAnalysis")))
        // And the one the app calls hands the count the verdict it awaited.
        let wrapper = try body(of: "func topTerms(", in: "FRUSExplorer/Analytics/WordCloud/WordFrequencyService.swift")
        #expect(wrapper.contains(squeezed(
            "let languageAnalysis = await NaturalLanguageReadiness.verdictWhenReady().health")))
        #expect(wrapper.contains(squeezed("countedUnder: languageAnalysis")))
    }

    @Test("A collection export's cloud is counted in the form of the verdict its plate line reads")
    func collectionCloudCountsInItsVerdictsForm() throws {
        let export = try body(of: "static func collectionCloudImage(",
                              in: "FRUSExplorer/Analytics/WordCloud/WordCloudExport.swift")
        #expect(export.contains(squeezed("wordForm: languageAnalysis.wordForm")))
    }

    @Test("Related Documents reads the reference for the verdict, counts in the reference's form, and shows the note")
    func relatedDocumentsWiring() throws {
        let path = "FRUSExplorer/RelatedDocuments/SemanticSharedTerms.swift"
        let entry = try body(of: "static func sharedTerms(", in: path)
        #expect(entry.contains(squeezed("languageAnalysis: languageAnalysis)")))
        #expect(entry.contains(squeezed("return await evidence(anchor: anchor, candidates: candidates, pipeline: pipeline, reference: reference)")))
        let pass = try body(of: "static func evidence(", in: path)
        #expect(pass.contains(squeezed("wordForm: reference.wordForm)")))
        #expect(pass.contains(squeezed("corpusCounts: reference.terms")))
        #expect(pass.contains(squeezed("return Evidence(terms: result, wordForm: reference.wordForm)")))

        let view = "FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift"
        let attach = try body(of: "private func attachSemanticEvidence(claimedKey: String) async", in: view)
        #expect(attach.contains(squeezed("sharedTermsNote = evidence.printedFormsNote")))
        // The chips are compared again when a re-check adopts a better verdict, so "right now" in
        // the note stays true.
        let key = try body(of: "private var reloadKey: String", in: view)
        #expect(key.contains("LanguageAnalysisMonitor.shared.revision"))
        let source = squeezed(try code(view))
        let note = try #require(source.range(of: squeezed("if let sharedTermsNote {")))
        let rows = try #require(source.range(of: squeezed("ForEach(rows) { row in")))
        #expect(note.upperBound <= rows.lowerBound, "the note is not above the rows")
    }

    @Test("The loader reads a file for each form, by the name the generator writes it under")
    func loaderReadsBothFiles() throws {
        let load = try body(of: "nonisolated static func loadBundled()",
                            in: "FRUSExplorer/Analytics/WordCloud/BundledKeynessBaseline.swift")
        #expect(load.contains(squeezed("for wordForm in WordCloudWordForm.allCases {")))
        #expect(load.contains(squeezed("KeynessBaselineFile.resourceName(for: wordForm)")))
        #expect(load.contains(squeezed("guard Self.isReference(file, for: wordForm) else {")))
    }
}

// MARK: - The shipped references

/// The shipped `keyness-baseline-printed.json`, and what it has to share with
/// `keyness-baseline.json`, which `KeynessBaselineArtifactTests` reads.
///
/// Like that suite it decodes the files straight from the bundle, so it shares no state with the
/// suites that inject fixtures, and it is what fails when the new resource was never enrolled: a
/// resource missing from the bundle is no build error, only a fallback that silently refuses on
/// every launch it was built for.
@Suite("Printed-form fallback — the shipped reference counted as printed (#1608)")
struct PrintedKeynessBaselineArtifactTests {

    private func bundledData(_ resource: String) throws -> Data {
        let url = try #require(
            Bundle.main.url(forResource: resource, withExtension: "json"),
            "\(resource).json is not in the app bundle. If it was just generated, it needs `xcodegen generate` to be enrolled — followed by `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.")
        return try Data(contentsOf: url)
    }

    private func load(_ form: WordCloudWordForm) throws -> KeynessBaselineFile {
        try JSONDecoder().decode(KeynessBaselineFile.self,
                                 from: bundledData(KeynessBaselineFile.resourceName(for: form)))
    }

    @Test("Each bundled reference says in its own bytes which form it is counted in",
          arguments: WordCloudWordForm.allCases)
    func eachFileStatesItsForm(form: WordCloudWordForm) throws {
        let data = try bundledData(KeynessBaselineFile.resourceName(for: form))
        // In the bytes, not only in the decoded value: a file with no key decodes as dictionary
        // forms, and the dictionary-form file has to say so of itself too.
        #expect(String(decoding: data, as: UTF8.self).contains(#""wordForm":"\#(form.rawValue)""#))
        #expect(try load(form).configuration.wordForm == form)
    }

    @Test("The two references are companions: one run's stamp, provenance, budget and pin")
    func theTwoAreCompanions() throws {
        let dictionary = try load(.dictionary)
        let printed = try load(.printed)
        #expect(printed.version == dictionary.version)
        #expect(printed.generated == dictionary.generated)
        #expect(printed.provenance == dictionary.provenance)
        #expect(printed.termsPerLens == dictionary.termsPerLens)
        // Everything a scope must match is the same for both; only the form differs.
        #expect(printed.configuration == dictionary.configuration.counted(as: .printed))
        #expect(printed.configuration != dictionary.configuration)
        // And both are the cloud vectors' companions, as `matchesTheCloudVectors` holds the first.
        let core = try JSONDecoder().decode(CloudVectorsFile.self, from: bundledData("cloud-vectors-core"))
        #expect(printed.generated == core.generated)
        #expect(printed.provenance == core.provenance)
    }

    @Test("It prices every lens the dictionary-form reference prices")
    func pricesTheSameLenses() throws {
        let printed = try load(.printed)
        #expect(Set(printed.lenses.keys) == Set(try load(.dictionary).lenses.keys))
        #expect(Set(printed.lenses.keys)
                == ["allTerms", "descriptors", "concepts", "topics", "actions", "sentiment"])
    }

    @Test("Its configuration is pinned to the payloads in the bundle")
    func configurationPinsTheBundledPayloads() throws {
        let printed = try load(.printed)
        #expect(printed.configuration.lexiconsDigest
                == WordCloudPayloadDigest.digest(of: try bundledData("word-cloud-lexicons")))
        #expect(printed.configuration.stopwordsDigest
                == WordCloudPayloadDigest.digest(of: try bundledData("word-cloud-stopwords")))
        #expect(printed.configuration.tuning == .standard)
        #expect(printed.configuration.includeDiplomatic)
    }

    @Test("Every lens has a real corpus behind it, cut on a count boundary")
    func lensesAreWellFormed() throws {
        let printed = try load(.printed)
        #expect(printed.termsPerLens == 20_000)
        for (name, lens) in printed.lenses {
            #expect(!lens.terms.isEmpty, "\(name) retained no terms")
            #expect(lens.totalTokens > 0)
            #expect(lens.distinctTerms >= lens.terms.count)
            #expect(lens.totalTokens >= lens.terms.values.reduce(0, +))
            #expect(lens.terms.count >= min(printed.termsPerLens, lens.distinctTerms))
            #expect(lens.terms.count <= printed.termsPerLens * 2)
            #expect(lens.terms.values.min() == lens.cutoffCount, "\(name): the cut did not land on a count boundary")
        }
    }

    @Test("The head of the distribution is priced")
    func retainsTheHead() throws {
        let allTerms = try #require(try load(.printed).lenses["allTerms"])
        // Printed forms spread the same tokens over more distinct words than dictionary forms do,
        // so the same 20,000-term budget prices a little less of them: 0.9761 measured on the
        // artifact of 2026-10-12, against 0.9815 for the dictionary-form reference.
        let priced = Double(allTerms.terms.values.reduce(0, +)) / Double(allTerms.totalTokens)
        #expect(priced > 0.96, "the retained terms price only \(priced) of the corpus")
    }

    @Test("It is a count of printed forms, by the rule a launch with no lemmatiser counts by")
    func itIsCountedAsPrinted() throws {
        let dictionary = try #require(try load(.dictionary).lenses["allTerms"])
        let printed = try #require(try load(.printed).lenses["allTerms"])
        // An inflected verb is a word of its own as printed, and no word at all in dictionary forms.
        #expect(try #require(printed.terms["negotiated"]) > 1_000)
        #expect(try #require(printed.terms["negotiating"]) > 1_000)
        #expect(dictionary.terms["negotiated"] == nil)
        #expect(dictionary.terms["negotiating"] == nil)
        // The dictionary form holds them all; the printed "negotiate" is the bare form alone.
        #expect(try #require(dictionary.terms["negotiate"]) > (try #require(printed.terms["negotiate"])))
        // A regular plural is folded by rule in a printed count too, under the standard tuning.
        #expect(printed.terms["missile"] != nil)
        #expect(printed.terms["missiles"] == nil)
        #expect(printed.terms["treaties"] == nil)
        // The rule knows no names. The reference is clipped where the device's count is clipped,
        // which is what makes the two comparable; a change to the rule has to regenerate this file.
        #expect(printed.terms["dulle"] != nil)
        #expect(printed.terms["dulles"] == nil)
        #expect(dictionary.terms["dulles"] != nil)
        // The same corpus, so nearly the same number of tokens, spread over more distinct words.
        #expect(printed.distinctTerms > dictionary.distinctTerms)
        let ratio = Double(printed.totalTokens) / Double(dictionary.totalTokens)
        #expect(ratio > 0.95 && ratio < 1.05, "printed / dictionary token total is \(ratio)")
    }

    @Test("The generator's bytes are exactly what the app reads back")
    func writerReaderByteParity() throws {
        let onDisk = try bundledData(KeynessBaselineFile.resourceName(for: .printed))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]        // what CloudVectorsRunner.writeBaseline uses
        #expect(try encoder.encode(try load(.printed)) == onDisk)
    }

    @Test("The app's loader reads both files from the bundle, each under the form it states")
    func theLoaderReadsBoth() {
        let loaded = BundledKeynessBaseline.loadBundled()
        #expect(Set(loaded.keys) == Set(WordCloudWordForm.allCases))
        for (form, file) in loaded {
            #expect(file.configuration.wordForm == form)
            #expect(file.lenses["allTerms"]?.totalTokens ?? 0 > 0)
        }
    }
}
