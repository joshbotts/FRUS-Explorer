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
import WordCloudKit
@testable import CloudVectorsGeneratorCore

// MARK: - A host's tagger, and a corpus to run it over

/// A tagger of a host's own for the run (FRUS Explorer Light, S29a): words split by rule, and lemmas and
/// lexical classes from tables. It names no one, as the run counts no names.
private struct RunTagger: WordCloudTagger {
    var identity = WordCloudTokenizerIdentity(name: "RunTagger", version: "1")
    var health = NaturalLanguageHealth(lemmatizes: true, classifiesWords: true, recognizesNames: false)
    /// A fault for the verification to find: a walk that reads no lemma misses each text's first word,
    /// so a printed count is not what the one pass counted as printed.
    var missesFirstWordWithoutLemmas = false

    static let lemmas: [String: String] = [
        "negotiated": "negotiate", "treaties": "treaty", "delegations": "delegation", "signed": "sign",
        "agreements": "agreement", "passed": "pass", "officials": "official", "debated": "debate",
        "telegrams": "telegram", "warned": "warn", "returned": "return", "governments": "government",
        "expanded": "expand", "approved": "approve", "loans": "loan",
    ]

    static let classes: [String: WordCloudLexicalClass] = [
        "secretary": .noun, "treaties": .noun, "treaty": .noun, "delegations": .noun, "agreements": .noun,
        "crisis": .noun, "officials": .noun, "telegrams": .noun, "peace": .noun, "ambassador": .noun,
        "sovereignty": .noun, "security": .noun, "governments": .noun, "assistance": .noun, "loans": .noun,
        "negotiated": .verb, "signed": .verb, "passed": .verb, "debated": .verb, "warned": .verb,
        "returned": .verb, "expanded": .verb, "approved": .verb,
        "dangerous": .adjective, "economic": .adjective, "confidential": .adjective,
    ]

    /// Runs of letters and digits, an apostrophe or a hyphen kept between two of them.
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
        let words = Self.words(in: text)
        for range in missesFirstWordWithoutLemmas && !reading.contains(.lemmas) ? Array(words.dropFirst()) : words {
            let key = text[range].lowercased()
            let lemma = reading.contains(.lemmas) && health.lemmatizes ? Self.lemmas[key] : nil
            let goOn = body(range, lemma) { health.classifiesWords ? (Self.classes[key] ?? .other) : nil }
            if !goOn { return }
        }
    }

    func enumerateNames(in text: String,
                        using body: (_ range: Range<String.Index>, _ nameType: WordCloudNameType?) -> Bool) {
        for range in Self.words(in: text) where !body(range, nil) { return }
    }
}

/// A corpus of three volumes in two subseries, a fourth file the manifest does not ship, and the word
/// lists, each in a folder of its own; the run writes into `output`.
private struct HostedRunCorpus {
    let root: URL
    var output: URL { root.appending(path: "out") }

    /// Volume id → its subseries and its documents' paragraphs.
    static let volumes: [(id: String, subseries: String, documents: [String])] = [
        ("frus1969-76v01", "1969-76", [
            "The Secretary negotiated the treaties, and the delegations signed the agreements. A dangerous crisis passed.",
            "Officials debated the treaty. Confidential telegrams warned of a crisis; peace returned.",
        ]),
        ("frus1969-76v02", "1969-76", [
            "The Ambassador negotiated sovereignty and security; the governments signed a treaty.",
        ]),
        ("frus1977-80v01", "1977-80", [
            "Economic assistance expanded. Officials approved loans and debated agreements.",
        ]),
    ]

    static let lexicons = #"{"concepts":["treaty","crisis","sovereignty","security"],"sentimentPositive":["agreement","peace"],"sentimentNegative":["crisis","dangerous"]}"#
    static let stopwords = #"{"english":["the","and","of","a","in","to"],"diplomatic":["department","telegram"],"markings":["secret","confidential"]}"#

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "CloudVectorsHostedRunTests-\(UUID().uuidString)")
        let volumesFolder = root.appending(path: "volumes")
        try FileManager.default.createDirectory(at: volumesFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for volume in Self.volumes {
            let divs = volume.documents.enumerated().map { n, text in
                #"<div type="document" xml:id="d\#(n + 1)"><p>\#(text)</p></div>"#
            }
            try Data("<TEI><text><body>\(divs.joined())</body></text></TEI>".utf8)
                .write(to: volumesFolder.appending(path: "\(volume.id).xml"))
        }
        try Data(#"<TEI><text><body><div type="document" xml:id="d1"><p>Nothing here ships.</p></div></body></text></TEI>"#.utf8)
            .write(to: volumesFolder.appending(path: "frus2001-04v99.xml"))
        let manifest = Self.volumes.map { #"{"volumeId":"\#($0.id)","subseries":"\#($0.subseries)"}"# }
        try Data("[\(manifest.joined(separator: ","))]".utf8).write(to: root.appending(path: "manifest.json"))
        try Data(Self.lexicons.utf8).write(to: root.appending(path: "lexicons.json"))
        try Data(Self.stopwords.utf8).write(to: root.appending(path: "stopwords.json"))
    }

    /// The run's environment, every path in this corpus, and a fixed date.
    func environment(_ extra: [String: String] = [:]) -> [String: String] {
        ["VOLUMES_DIR": root.appending(path: "volumes").path,
         "MANIFEST": root.appending(path: "manifest.json").path,
         "LEXICONS": root.appending(path: "lexicons.json").path,
         "STOPWORDS": root.appending(path: "stopwords.json").path,
         "OUTPUT_DIR": output.path,
         "GENERATED_DATE": "2026-11-23"].merging(extra) { _, given in given }
    }

    /// The files the run wrote, by name, with their bytes.
    func written() throws -> [String: Data] {
        let names = try FileManager.default.contentsOfDirectory(atPath: output.path)
        return try Dictionary(uniqueKeysWithValues: names.map { ($0, try Data(contentsOf: output.appending(path: $0))) })
    }

    func cloud(_ name: String) throws -> CloudVectorsFile {
        try CloudVectorsFile(contentsOf: output.appending(path: "\(name).json"))
    }

    func reference(_ wordForm: WordCloudWordForm) throws -> KeynessBaselineFile {
        try KeynessBaselineFile(contentsOf: output.appending(path: KeynessBaselineFile.resourceName(for: wordForm) + ".json"))
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

// MARK: - The run over a host's tagger

/// `CloudVectorsRunner.run(tagger:cloudLenses:environment:)` over a host's tagger (S29a): the run takes its
/// tagger, the tagger's health and identity, and the lenses its clouds carry from its caller, and writes
/// what the kit's tokenizer counts with that tagger, stamped with its identity.
///
/// Until S29a `run()` could not be driven from a test: it read the local corpus and wrote into the app's
/// resources. Given its environment and a tagger, it runs here, on every platform, over a corpus of its own.
///
/// Version history:
///   1.0 — 2026-11-23 (FRUS Explorer Light, S29a): initial implementation
@Suite("CloudVectors — the run over a host's tagger (S29a)")
struct CloudVectorsHostedRunTests {

    /// What the kit's one pass counts in `volume` with `tagger`, in both forms, as the run counts it.
    private static func counted(_ volume: (id: String, subseries: String, documents: [String]),
                                tagger: RunTagger) throws
    -> (dictionary: [WordCloudLens: [String: Int]], printed: [WordCloudLens: [String: Int]]) {
        let stopwords = try WordCloudStopwordSet(payload: JSONDecoder().decode(
            WordCloudStopwordSet.Payload.self, from: Data(HostedRunCorpus.stopwords.utf8)))
        let lexicons = try WordCloudLexiconSet(payload: JSONDecoder().decode(
            WordCloudLexiconSet.Payload.self, from: Data(HostedRunCorpus.lexicons.utf8)))
        let tokenizer = try #require(WordCloudMultiLensTokenizer(
            lenses: CloudVectorsRunner.baselineLenses, tuning: .standard,
            stopwords: stopwords.active(includeDiplomatic: true), lexicons: lexicons,
            markings: stopwords.markings))
        var dictionary: [WordCloudLens: [String: Int]] = [:]
        var printed: [WordCloudLens: [String: Int]] = [:]
        let xml = #"<TEI><text><body>"# + volume.documents.enumerated().map { n, text in
            #"<div type="document" xml:id="d\#(n + 1)"><p>\#(text)</p></div>"#
        }.joined() + "</body></text></TEI>"
        for document in TEIBodyTextExtractor.documents(in: xml) {
            tokenizer.accumulate(from: document.bodyText, into: &dictionary, printedInto: &printed, tagger: tagger)
        }
        return (dictionary, printed)
    }

    /// A list of `file` resolved to term → count.
    private static func terms(_ file: CloudVectorsFile, _ scope: String, _ lens: WordCloudLens) -> [String: Int] {
        guard let list = file.scopes[scope]?.lists[lens.rawValue] else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.entries.map { (file.vocabulary[$0.term], $0.count) })
    }

    @Test("The run writes the four files, each naming the host's tagger as the tokenizer that counted it")
    func filesNameTheTokenizer() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        let tagger = RunTagger()
        try CloudVectorsRunner.run(tagger: tagger, environment: corpus.environment())

        #expect(Set(try corpus.written().keys) == ["cloud-vectors-core.json", "cloud-vectors-volumes.json",
                                                   "keyness-baseline.json", "keyness-baseline-printed.json"])
        let core = try corpus.cloud("cloud-vectors-core")
        let volumes = try corpus.cloud("cloud-vectors-volumes")
        #expect(core.provenance.tokenizer == tagger.identity)
        #expect(volumes.provenance.tokenizer == tagger.identity)
        for form in WordCloudWordForm.allCases {
            let reference = try corpus.reference(form)
            #expect(reference.configuration.tokenizer == tagger.identity)
            #expect(reference.provenance.tokenizer == tagger.identity)
            #expect(reference.configuration.wordForm == form)
        }
        // Only the manifest's volumes are counted, in their subseries.
        #expect(Set(volumes.scopes.keys) == ["frus1969-76v01", "frus1969-76v02", "frus1977-80v01"])
        #expect(Set(core.scopes.keys) == ["corpus", "1969-76", "1977-80"])
        #expect(core.provenance.volumeCount == 3 && core.provenance.documentCount == 4)
        #expect(core.generated == "2026-11-23")
    }

    @Test("The clouds carry the four lenses by default, and every lens the run counts when the caller asks")
    func cloudLensesAreTheCallers() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment())
        #expect(try corpus.cloud("cloud-vectors-core").lenses == WordCloudLens.bundledCloudLenses.map(\.rawValue))
        // The reference prices every lens the run counts, whichever the clouds carry.
        #expect(Set(try corpus.reference(.dictionary).lenses.keys) == Set(CloudVectorsRunner.baselineLenses.map(\.rawValue)))

        try CloudVectorsRunner.run(tagger: RunTagger(), cloudLenses: CloudVectorsRunner.baselineLenses,
                                   environment: corpus.environment())
        let six = try corpus.cloud("cloud-vectors-volumes")
        #expect(six.lenses == CloudVectorsRunner.baselineLenses.map(\.rawValue))
        #expect(six.scopes["frus1969-76v01"]?.lists[WordCloudLens.allTerms.rawValue]?.entries.isEmpty == false)
    }

    @Test("Each volume's clouds are what the kit's tokenizer counts with the tagger, and the reference is their sum")
    func countsAreTheTokenizers() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        let tagger = RunTagger()
        try CloudVectorsRunner.run(tagger: tagger, cloudLenses: CloudVectorsRunner.baselineLenses,
                                   environment: corpus.environment())
        let volumes = try corpus.cloud("cloud-vectors-volumes")
        var corpusDictionary: [WordCloudLens: [String: Int]] = [:]
        var corpusPrinted: [WordCloudLens: [String: Int]] = [:]
        for volume in HostedRunCorpus.volumes {
            let counts = try Self.counted(volume, tagger: tagger)
            for lens in CloudVectorsRunner.baselineLenses {
                // Fewer than fifty terms a list, so no list is cut.
                #expect(Self.terms(volumes, volume.id, lens) == (counts.dictionary[lens] ?? [:]),
                        "\(volume.id) \(lens.rawValue)")
            }
            CloudVectorsRunner.add(counts.dictionary, to: &corpusDictionary)
            CloudVectorsRunner.add(counts.printed, to: &corpusPrinted)
        }
        for (form, tally) in [(WordCloudWordForm.dictionary, corpusDictionary), (.printed, corpusPrinted)] {
            let reference = try corpus.reference(form)
            for lens in CloudVectorsRunner.baselineLenses {
                #expect(reference.lenses[lens.rawValue]?.terms == tally[lens], "\(form.rawValue) \(lens.rawValue)")
            }
        }
        // Not vacuous: the two forms differ, and Topics counted the tagger's nouns.
        #expect(corpusDictionary[.allTerms]?["negotiate"] == 2 && corpusPrinted[.allTerms]?["negotiated"] == 2)
        #expect(corpusDictionary[.topics]?["treaty"] == 3)
    }

    @Test("The reference refuses a scope counted by NaturalLanguage, and takes one counted by its own tagger")
    func referenceRefusesAnotherTokenizer() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        let tagger = RunTagger()
        try CloudVectorsRunner.run(tagger: tagger, environment: corpus.environment())
        let lexicons = try #require(WordCloudPayloadDigest.digest(ofFileAt: corpus.root.appending(path: "lexicons.json")))
        let stopwords = try #require(WordCloudPayloadDigest.digest(ofFileAt: corpus.root.appending(path: "stopwords.json")))
        let configuration = try corpus.reference(.dictionary).configuration
        #expect(configuration.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: lexicons,
                                         stopwordsDigest: stopwords, tokenizer: tagger.identity).isEmpty)
        #expect(configuration.mismatches(against: .standard, includeDiplomatic: true, lexiconsDigest: lexicons,
                                         stopwordsDigest: stopwords, tokenizer: .naturalLanguage) == [.tokenizer])
    }

    @Test("A tagger that lacks lemmas or lexical classes is refused before anything is written",
          arguments: [NaturalLanguageHealth(lemmatizes: false, classifiesWords: true, recognizesNames: false),
                      NaturalLanguageHealth(lemmatizes: true, classifiesWords: false, recognizesNames: false)])
    func refusesALesserTagger(health: NaturalLanguageHealth) throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        #expect(throws: CloudVectorsRunner.RunError.self) {
            try CloudVectorsRunner.run(tagger: RunTagger(health: health), environment: corpus.environment())
        }
        #expect(try corpus.written().isEmpty)
    }

    @Test("Lenses the run does not count, none at all, or one twice are refused before anything is written",
          arguments: [[WordCloudLens](), [.people], [.topics, .topics], [.concepts, .places]])
    func refusesCloudLensesTheRunDoesNotCount(lenses: [WordCloudLens]) throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        #expect {
            try CloudVectorsRunner.run(tagger: RunTagger(), cloudLenses: lenses, environment: corpus.environment())
        } throws: { error in
            guard case CloudVectorsRunner.RunError.cloudLenses(let named) = error else { return false }
            return named == lenses
        }
        #expect(try corpus.written().isEmpty)
    }

    @Test("Every lens the run counts may be carried, in the caller's order")
    func everyCountedLensIsAccepted() throws {
        try CloudVectorsRunner.requireCloudLenses(CloudVectorsRunner.baselineLenses)
        try CloudVectorsRunner.requireCloudLenses(CloudVectorsRunner.baselineLenses.reversed())
        try CloudVectorsRunner.requireCloudLenses([.allTerms])
        let description = CloudVectorsRunner.RunError.cloudLenses([.people]).description
        #expect(description.contains("people") && description.contains("refusing to write"))
    }

    @Test("Two runs write the same bytes, and the printed walk's verification passes over the host's tagger and changes none")
    func deterministicAndVerified() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment())
        let first = try corpus.written()
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment())
        #expect(try corpus.written() == first)
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment(["VERIFY_PRINTED_WALK": "1"]))
        #expect(try corpus.written() == first)
        #expect(first.count == 4)
    }

    @Test("The printed walk's verification refuses a tagger whose walk without lemmas is not its one pass's, and writes nothing")
    func verificationFindsADivergentTagger() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        let faulty = RunTagger(missesFirstWordWithoutLemmas: true)
        // Without the verification the run writes, as a run with the fault would ship.
        try CloudVectorsRunner.run(tagger: faulty, environment: corpus.environment())
        #expect(try corpus.written().count == 4)
        for name in try corpus.written().keys { try FileManager.default.removeItem(at: corpus.output.appending(path: name)) }
        #expect {
            try CloudVectorsRunner.run(tagger: faulty, environment: corpus.environment(["VERIFY_PRINTED_WALK": "1"]))
        } throws: { error in
            guard case CloudVectorsRunner.RunError.printedWalkDiverged(let volume, _) = error else { return false }
            return volume == "frus1969-76v01"
        }
        #expect(try corpus.written().isEmpty)
    }

    @Test("A tagger of NaturalLanguage's first identity writes files that name no tokenizer, as the app's always have")
    func legacyIdentityWritesNoKey() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        try CloudVectorsRunner.run(tagger: RunTagger(identity: .legacyNaturalLanguage), environment: corpus.environment())
        for (name, data) in try corpus.written() {
            #expect(!String(decoding: data, as: UTF8.self).contains(#""tokenizer""#), "\(name)")
        }
        #expect(try corpus.reference(.dictionary).configuration.tokenizer == .legacyNaturalLanguage)
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment())
        for (name, data) in try corpus.written() {
            #expect(String(decoding: data, as: UTF8.self).contains(#""tokenizer":{"name":"RunTagger","version":"1"}"#), "\(name)")
        }
    }

    @Test("Another tagger's identity writes other stamps over the same counts")
    func identityIsTheTaggers() throws {
        let corpus = try HostedRunCorpus()
        defer { corpus.remove() }
        try CloudVectorsRunner.run(tagger: RunTagger(), environment: corpus.environment())
        let first = try corpus.cloud("cloud-vectors-core")
        let other = WordCloudTokenizerIdentity(name: "RunTagger", version: "2")
        try CloudVectorsRunner.run(tagger: RunTagger(identity: other), environment: corpus.environment())
        let second = try corpus.cloud("cloud-vectors-core")
        #expect(second.provenance.tokenizer == other)
        #expect(second.scopes == first.scopes)
        #expect(try corpus.reference(.printed).configuration.tokenizer == other)
    }
}
