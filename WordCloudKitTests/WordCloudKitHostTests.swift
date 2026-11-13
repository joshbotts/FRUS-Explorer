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
@testable import WordCloudKit

// MARK: - What a host reads, on any platform

/// The repository's bundled resources, read from disk as a host reads its own copies: a host has no
/// app bundle, and these suites run on Linux too, where the kit is all a host has.
private enum RepositoryResources {

    /// The repository's root: this file is in `WordCloudKitTests/`.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// The bundled JSON resource `name`, without its extension.
    static func json(_ name: String) -> URL {
        root.appending(path: "FRUSExplorer/Resources/\(name).json")
    }

    /// A file that is not there.
    static let missing = root.appending(path: "FRUSExplorer/Resources/no-such-artifact.json")
}

/// The bundled clouds and keyness references, loaded by URL (FRUS Explorer Light, S24d).
///
/// The app decodes them from its bundle with a plain `JSONDecoder` (`BundledCloudVectors`,
/// `BundledKeynessBaseline`), as these initialisers do; a host decodes the same files where it keeps
/// them. What is held here is what a host relies on when it reads them.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24d): initial implementation
@Suite("WordCloudKit — the bundled clouds and references, loaded by URL")
struct CloudVectorsLoadingTests {

    @Test("Each cloud file loads by URL, and every list in it is one the app's reader resolves whole",
          arguments: ["cloud-vectors-core", "cloud-vectors-volumes"])
    func cloudFileLoadsByURL(resource: String) throws {
        let file = try CloudVectorsFile(contentsOf: RepositoryResources.json(resource))
        #expect(file.lenses == WordCloudLens.bundledCloudLenses.map(\.rawValue))
        #expect(!file.vocabulary.isEmpty)
        var lists = 0
        var outOfRange: [String] = [], unranked: [String] = [], shortTotals: [String] = [], polarities: [String] = []
        for (scope, vectors) in file.scopes {
            for (lens, list) in vectors.lists {
                lists += 1
                let name = "\(scope)/\(lens)"
                // The app's reader (`BundledCloudVectors.list(in:scope:lens:)`) drops an entry whose
                // index is outside the vocabulary, so a list with one would lose a word silently.
                if !list.entries.allSatisfy({ $0.term >= 0 && $0.term < file.vocabulary.count }) { outOfRange.append(name) }
                // Ranked: descending by count, so the first is the largest, which a renderer scales by.
                if !zip(list.entries, list.entries.dropFirst()).allSatisfy({ $0.count >= $1.count }) { unranked.append(name) }
                // The total counts every match before the list was cut, so it is never less than the kept.
                if list.total < list.entries.reduce(0, { $0 + $1.count }) { shortTotals.append(name) }
                // A polarity on the sentiment lens alone, and there always +1 or -1.
                let signed = lens == WordCloudLens.sentiment.rawValue
                if !list.entries.allSatisfy({ signed ? ($0.polarity == 1 || $0.polarity == -1) : $0.polarity == nil }) {
                    polarities.append(name)
                }
            }
        }
        #expect(lists >= file.scopes.count * 4, "\(lists) lists in \(file.scopes.count) scopes")
        #expect(outOfRange.isEmpty, "entries outside the vocabulary in \(outOfRange.prefix(5))")
        #expect(unranked.isEmpty, "lists not ranked by count: \(unranked.prefix(5))")
        #expect(shortTotals.isEmpty, "totals below the kept entries' sum: \(shortTotals.prefix(5))")
        #expect(polarities.isEmpty, "polarities off the sentiment lens, or not +1 or -1: \(polarities.prefix(5))")
    }

    @Test("The core file holds the corpus and the subseries, and the volumes file the volumes alone")
    func theTwoFilesSplitTheScopes() throws {
        let core = try CloudVectorsFile(contentsOf: RepositoryResources.json("cloud-vectors-core"))
        let volumes = try CloudVectorsFile(contentsOf: RepositoryResources.json("cloud-vectors-volumes"))
        #expect(core.scopes["corpus"] != nil)
        #expect(core.scopes.count > 100, "the corpus and the subseries: \(core.scopes.count) scopes")
        #expect(core.scopes.keys.allSatisfy { !$0.hasPrefix("frus") })
        #expect(volumes.scopes["corpus"] == nil)
        #expect(volumes.scopes.keys.allSatisfy { $0.hasPrefix("frus") })
        #expect(volumes.scopes.count > 500, "one scope a volume: \(volumes.scopes.count)")
    }

    @Test("Each keyness reference loads by URL, its stamp names its form, and it is the clouds' companion",
          arguments: WordCloudWordForm.allCases)
    func referenceLoadsByURL(wordForm: WordCloudWordForm) throws {
        let reference = try KeynessBaselineFile(
            contentsOf: RepositoryResources.json(KeynessBaselineFile.resourceName(for: wordForm)))
        let core = try CloudVectorsFile(contentsOf: RepositoryResources.json("cloud-vectors-core"))
        #expect(reference.configuration.wordForm == wordForm)
        #expect(reference.configuration.tuning == .standard)
        #expect(reference.configuration.includeDiplomatic)
        // One generator run wrote the clouds and both references, as the app's own artifact suite holds
        // (`KeynessBaselineArtifactTests.matchesTheCloudVectors`).
        #expect(reference.generated == core.generated)
        #expect(reference.provenance == core.provenance)
        // Every lens it prices has a corpus behind it.
        #expect(!reference.lenses.isEmpty)
        #expect(reference.lenses.values.allSatisfy { $0.totalTokens > 0 && !$0.terms.isEmpty })
    }

    @Test("A file that is not there, or is not the format, throws: the app's loaders answer that none is there")
    func failuresThrow() throws {
        #expect(throws: (any Error).self) { try CloudVectorsFile(contentsOf: RepositoryResources.missing) }
        #expect(throws: (any Error).self) { try KeynessBaselineFile(contentsOf: RepositoryResources.missing) }

        let folder = FileManager.default.temporaryDirectory
            .appending(path: "WordCloudKitHostTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let notTheFormat = folder.appending(path: "empty-object.json")
        try Data("{}".utf8).write(to: notTheFormat)
        #expect(throws: (any Error).self) { try CloudVectorsFile(contentsOf: notTheFormat) }
        #expect(throws: (any Error).self) { try KeynessBaselineFile(contentsOf: notTheFormat) }
    }
}

/// The payload digest, by CryptoKit on Apple platforms and swift-crypto where CryptoKit is missing
/// (FRUS Explorer Light, S24d).
///
/// The references record the digests the generator computed on a Mac; a host that checks a reference
/// against its payloads computes them here, so the two must agree byte for byte.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24d): initial implementation
@Suite("WordCloudKit — the payload digest on every platform")
struct WordCloudPayloadDigestTests {

    @Test("The digest is SHA-256, in lowercase hex")
    func digestIsSHA256() {
        // FIPS 180-2's test vector, and the digest of nothing.
        #expect(WordCloudPayloadDigest.digest(of: Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(WordCloudPayloadDigest.digest(of: Data())
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("The bundled payloads' digests are the ones each reference was built under",
          arguments: WordCloudWordForm.allCases)
    func bundledPayloadsMatchTheReferences(wordForm: WordCloudWordForm) throws {
        let reference = try KeynessBaselineFile(
            contentsOf: RepositoryResources.json(KeynessBaselineFile.resourceName(for: wordForm)))
        let lexicons = try #require(WordCloudPayloadDigest.digest(ofFileAt: RepositoryResources.json("word-cloud-lexicons")))
        let stopwords = try #require(WordCloudPayloadDigest.digest(ofFileAt: RepositoryResources.json("word-cloud-stopwords")))
        #expect(reference.configuration.lexiconsDigest == lexicons)
        #expect(reference.configuration.stopwordsDigest == stopwords)
        // So a scope counted as the generator counted is comparable, as the app's check finds it.
        #expect(reference.configuration.mismatches(
            against: .standard, includeDiplomatic: true,
            lexiconsDigest: lexicons, stopwordsDigest: stopwords).isEmpty)
    }

    @Test("A payload that cannot be read has no digest, so it matches no reference")
    func unreadablePayloadHasNoDigest() {
        #expect(WordCloudPayloadDigest.digest(ofFileAt: RepositoryResources.missing) == nil)
    }
}

/// The tuning a reader's settings give, read as the app reads them (FRUS Explorer Light, S24d): the
/// app's `WordCloudSettings` reads its stored values through these rules, and a host its synced ones.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24d): initial implementation
@Suite("WordCloudKit — the tuning from a reader's settings")
struct WordCloudTuningSettingsTests {

    @Test("Settings that hold nothing give the shipped tuning")
    func nothingStoredIsTheShippedTuning() {
        #expect(WordCloudTuning(settingsMinimumLength: nil, minimumCount: nil,
                                foldPlurals: nil, filterMarkings: nil) == .standard)
        #expect(WordCloudTuning.minimumLength(fromSetting: nil) == 3)
        #expect(WordCloudTuning.minimumCount(fromSetting: nil) == 1)
        #expect(WordCloudTuning.foldPlurals(fromSetting: nil))
        #expect(WordCloudTuning.filterMarkings(fromSetting: nil))
    }

    @Test("A minimum length below 2 reads as 2, and a minimum count below 1 as 1")
    func floorsHold() {
        for stored in [-5, 0, 1, 2] { #expect(WordCloudTuning.minimumLength(fromSetting: stored) == 2) }
        for stored in [-3, 0, 1] { #expect(WordCloudTuning.minimumCount(fromSetting: stored) == 1) }
    }

    @Test("Every other stored value is read as it is stored")
    func storedValuesPassThrough() {
        let tuning = WordCloudTuning(settingsMinimumLength: 7, minimumCount: 4,
                                     foldPlurals: false, filterMarkings: false)
        #expect(tuning == WordCloudTuning(minimumLength: 7, minimumCount: 4,
                                          foldPlurals: false, filterMarkings: false))
        #expect(WordCloudTuning(settingsMinimumLength: 3, minimumCount: 1,
                                foldPlurals: true, filterMarkings: true) == .standard)
    }
}

/// The tokenizer's filters, which read no tagger (FRUS Explorer Light, S24d): where NaturalLanguage is
/// missing the tokenizer counts nothing, but a host still asks it which terms a reader's settings keep,
/// as the app's settings bench does over the bundled clouds (`WordCloudBench`).
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24d): initial implementation
@Suite("WordCloudKit — the tokenizer's filters on every platform")
struct WordCloudTokenizerFilterTests {

    @Test("A word lens keeps letters at the minimum length or longer, and drops stopwords, markings and digits")
    func wordLensFilters() {
        let tokenizer = WordCloudTokenizer(stopwords: ["state"], minimumLength: 4, markings: ["secret"])
        #expect(tokenizer.accepts("treaty"))
        #expect(tokenizer.accepts("cease-fire") && tokenizer.accepts("nation's"))
        #expect(!tokenizer.accepts("war"), "shorter than the minimum length")
        #expect(!tokenizer.accepts("state"), "a stopword")
        #expect(!tokenizer.accepts("secret"), "a marking")
        #expect(!tokenizer.accepts("1969") && !tokenizer.accepts("nsc-68"), "a digit")
    }

    @Test("A lexicon lens keeps its lexicon's words alone, and an entity lens keeps names that are not all stopwords")
    func lexiconAndEntityFilters() {
        let concepts = WordCloudTokenizer(stopwords: [], lens: .concepts, lexicon: ["sovereignty"])
        #expect(concepts.accepts("sovereignty"))
        #expect(!concepts.accepts("treaty"))
        let places = WordCloudTokenizer(stopwords: ["the"], lens: .places, markings: ["top", "secret"])
        #expect(places.accepts("San Salvador"))
        #expect(!places.accepts("top secret"), "a phrase of markings alone")
        #expect(!places.accepts("Area 51"), "a digit")
    }

    @Test("A regular plural folds to its singular, and the exceptions and short words do not")
    func pluralsFold() {
        #expect(WordCloudTokenizer.singularize("treaties") == "treaty")
        #expect(WordCloudTokenizer.singularize("boxes") == "box")
        #expect(WordCloudTokenizer.singularize("missiles") == "missile")
        #expect(WordCloudTokenizer.singularize("series") == "series")
        #expect(WordCloudTokenizer.singularize("analysis") == "analysis")
        #expect(WordCloudTokenizer.singularize("arms") == "arms", "four letters or fewer are left alone")
    }
}

/// The word cloud's two measures (FRUS Explorer Light, S24d). Their labels are the app's.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24d): initial implementation
@Suite("WordCloudKit — the cloud's measures")
struct KeynessCloudMeasureTests {

    @Test("Frequency then Distinctive, under the raw values the app stores")
    func measuresAndRawValues() {
        #expect(KeynessCloudMeasure.allCases == [.frequency, .keyness])
        #expect(KeynessCloudMeasure.allCases.map(\.rawValue) == ["frequency", "keyness"])
        #expect(KeynessCloudMeasure(rawValue: "keyness") == .keyness)
        #expect(KeynessCloudMeasure(rawValue: "distinctive") == nil)
    }
}
