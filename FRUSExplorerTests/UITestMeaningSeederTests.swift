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

// MARK: - The bundled artifacts, read for these suites

/// The bundled semantic index and sign bits, decoded from the test host's bundle with the kit's
/// own readers. Not `BundledSemanticVectors`: that is one process-wide load which another suite
/// resets, and these suites need the shipped artifacts whatever it does.
private enum ShippedVectors {

    /// The volume the UI suites seed (`FRUS_UI_TEST_SEED_VOLUME`).
    static let fixtureVolume = "frus1961-63v06"

    /// The fixture's documents that have a bundled row, and those that have none
    /// (`UITestVolumeSeeder.fixtureXML`).
    static let withRows = ["d1", "d2", "d3"]
    static let withoutRows = ["n1", "n2", "t1"]

    static func load() throws -> (index: SemanticVectorIndex, corpus: SemanticCorpusVectors) {
        let indexURL = try #require(Bundle.main.url(forResource: "semantic-vectors-index", withExtension: "json"),
                                    "the test host's bundle has no semantic index")
        let binaryURL = try #require(Bundle.main.url(forResource: "semantic-vectors-binary", withExtension: "bin"),
                                     "the test host's bundle has no semantic binary")
        let file = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self, from: Data(contentsOf: indexURL))
        let index = SemanticVectorIndex(file: file)
        return (index, try SemanticCorpusVectors(contentsOf: binaryURL, expecting: index.provenance))
    }

    /// A folder name of this test's own, not yet made: where a seam's store goes.
    static func storeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MeaningSeam-\(UUID().uuidString)", isDirectory: true)
    }

    /// The seam a launch that asks would be given, with its store in `directory`.
    static func seam(_ index: SemanticVectorIndex, _ corpus: SemanticCorpusVectors,
                     in directory: URL) async throws -> UITestMeaningSeeder.Seam {
        let prepared = await UITestMeaningSeeder.prepare(
            environment: asking, index: index, corpus: corpus, storeDirectory: directory)
        return try #require(prepared, "a launch that asks, for a volume with bundled rows, is given a seam")
    }

    /// The launch environment of a UI test that asks for the seam.
    static let asking = [UITestVolumeSeeder.environmentKey: fixtureVolume,
                         UITestMeaningSeeder.environmentKey: "1"]
}

// MARK: - UITestMeaningSeederTests

/// The stand-in vectors and the synthetic match file of the UI-test Meaning seam (#1577 lane 3),
/// and the figures its design rests on, held against the artifacts the app ships.
///
/// The seam answers a question with a vector made of one document's bundled sign bits, and plants a
/// match file made of the fixture volume's. Which fixture documents a search then lists is a fact
/// about the bundle: the UI suite that uses the seam expects three rows in one order, and a bundle
/// regenerated with other bits would move them. These tests fail first, and say which figure moved.
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
@Suite("The UI-test Meaning seam: its vectors, its match file, and what the bundle makes of them")
struct UITestMeaningSeederTests {

    @Test("The seam is asked for by its own key, which is the one the UI suite sets, and a far question holds its marker in any case")
    func whenItIsAskedFor() {
        // A UI suite cannot name the app's constants, so it spells the key. This is that spelling.
        #expect(UITestMeaningSeeder.environmentKey == "FRUS_UI_TEST_SEED_MEANING")
        #expect(UITestVolumeSeeder.environmentKey == "FRUS_UI_TEST_SEED_VOLUME")
        #expect(UITestMeaningSeeder.isRequested(ShippedVectors.asking))
        #expect(!UITestMeaningSeeder.isRequested([UITestVolumeSeeder.environmentKey: ShippedVectors.fixtureVolume]))
        #expect(!UITestMeaningSeeder.isRequested([UITestMeaningSeeder.environmentKey: "0"]))
        #expect(UITestMeaningSeeder.isFar("a question from far afield"))
        #expect(UITestMeaningSeeder.isFar("AFIELD"))
        #expect(!UITestMeaningSeeder.isFar("how did the exchange of letters begin"))
    }

    /// The convention is restated here in its own arithmetic, and not by calling the kit's packer
    /// alone: a packer and an unpacker that were both least-significant first would agree with
    /// each other and with nothing the bundle holds.
    @Test("A row's sign vector is +1 where its bit is set, most significant bit first, and packs back to the row")
    func signVectorReadsTheRowsBits() throws {
        let (index, corpus) = try ShippedVectors.load()
        #expect(corpus.bytesPerRow * 8 == index.dims)
        for row in [0, 1, 260_020, corpus.documentCount - 1] {
            let vector = try #require(UITestMeaningSeeder.signVector(ofRow: row, in: corpus))
            #expect(vector.count == index.dims)
            let bytes: [UInt8] = corpus.withSignBits { pointer, _ in
                [UInt8](UnsafeRawBufferPointer(start: pointer.advanced(by: row * corpus.bytesPerRow),
                                               count: corpus.bytesPerRow))
            }
            var agreed = 0
            for position in 0..<index.dims {
                let bit = (bytes[position / 8] >> UInt8(7 - position % 8)) & 1
                if vector[position] == (bit == 1 ? 1 : -1) { agreed += 1 }
            }
            #expect(agreed == index.dims, "row \(row): \(index.dims - agreed) components disagree with the row's bits")
            #expect(SemanticQuantization.packSignBits(vector.map { Float($0) }) == bytes, "row \(row) does not pack back")
            #expect(vector.contains(1) && vector.contains(-1), "row \(row) reads as one sign throughout")
        }
        #expect(UITestMeaningSeeder.signVector(ofRow: -1, in: corpus) == nil)
        #expect(UITestMeaningSeeder.signVector(ofRow: corpus.documentCount, in: corpus) == nil)
    }

    @Test("The stand-in encoder answers with the fixture's d2, and with frus1861's d1 for a far question")
    func theEncoderAnswersWithOneOfTwoDocuments() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let embed = try #require(UITestMeaningSeeder.standInEncoder(
            for: ShippedVectors.fixtureVolume, index: index, corpus: corpus))
        let nearRow = try #require(index.row(documentID: "d2", volumeID: ShippedVectors.fixtureVolume))
        let farRow = try #require(index.row(documentID: "d1", volumeID: "frus1861"))
        let near = try #require(UITestMeaningSeeder.signVector(ofRow: nearRow, in: corpus))
        let far = try #require(UITestMeaningSeeder.signVector(ofRow: farRow, in: corpus))
        #expect(near != far)
        let first = try await embed("how did the exchange of letters begin")
        let second = try await embed("anything else at all")
        let distant = try await embed("a question from far afield")
        #expect(first == near)
        #expect(second == near)
        #expect(distant == far)
        #expect(UITestMeaningSeeder.standInEncoder(for: "no-such-volume", index: index, corpus: corpus) == nil)
    }

    /// The near question's figures. `d2`'s own row is at distance nothing, and the fixture's other
    /// two documents with rows are the next two of 314,616: so all three are well inside the 800
    /// candidates a plain search scores, with room for a bundle that moves them a little.
    @Test("Near: the fixture's three documents with rows are the first three candidates of the whole corpus")
    func theNearQuestionsCandidates() async throws {
        let (index, corpus) = try ShippedVectors.load()
        #expect(index.file.retrieval.rerankPool == 800, "the candidates a plain search scores")
        let embed = try #require(UITestMeaningSeeder.standInEncoder(
            for: ShippedVectors.fixtureVolume, index: index, corpus: corpus))
        let question = try await embed("how did the exchange of letters begin").map { Float($0) }
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryBits: SemanticQuantization.packSignBits(question), in: corpus, limit: 800)
        let firstThree = candidates.prefix(3).compactMap { index.document(at: $0) }
        #expect(firstThree.map(\.volumeID) == Array(repeating: ShippedVectors.fixtureVolume, count: 3))
        #expect(firstThree.map(\.documentID) == ["d2", "d1", "d3"])
    }

    /// The counts the seeder's comments, the runbook and the UI suite's header quote. On their own,
    /// because a re-pack of the bundle that changes a count and moves no candidate breaks the
    /// quoted figures and nothing the seam does.
    @Test("The counts the seam's documents quote: 314,616 documents, and 120 rows for the fixture volume")
    func theCountsTheDocumentsQuote() throws {
        let (index, corpus) = try ShippedVectors.load()
        #expect(index.documentCount == 314_616)
        #expect(corpus.documentCount == 314_616)
        #expect(index.rows(forVolume: ShippedVectors.fixtureVolume)?.count == 120)
    }

    @Test("Far: none of the fixture volume's rows is among the 800 candidates")
    func theFarQuestionsCandidates() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let embed = try #require(UITestMeaningSeeder.standInEncoder(
            for: ShippedVectors.fixtureVolume, index: index, corpus: corpus))
        let question = try await embed("a question from far afield").map { Float($0) }
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryBits: SemanticQuantization.packSignBits(question), in: corpus, limit: 800)
        #expect(candidates.count == 800)
        let fixtureRows = try #require(index.rows(forVolume: ShippedVectors.fixtureVolume))
        #expect(candidates.filter { fixtureRows.contains($0) }.isEmpty)
    }

    /// The store opens a match file only under the bundled provenance digest and with the bundled
    /// row count (and the kit's own checks of the file's shape). The planted file has to pass them
    /// as a published one does, and then score a row as `1 − 2h/512`: 1 for the question's own row,
    /// and 90 and 100 bits away for the other two.
    @Test("The synthetic match file opens under the bundled pin and row count, and scores a row by its Hamming distance")
    func theSyntheticMatchFile() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let bytes = try #require(UITestMeaningSeeder.syntheticShard(
            for: ShippedVectors.fixtureVolume, index: index, corpus: corpus))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("MeaningSeam-\(UUID().uuidString).vec")
        try bytes.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let shard = try SemanticShard(contentsOf: file, provenance: index.provenance, expectedDocumentCount: 120)
        #expect(shard.documentCount == 120)
        #expect(shard.dims == 512)

        let embed = try #require(UITestMeaningSeeder.standInEncoder(
            for: ShippedVectors.fixtureVolume, index: index, corpus: corpus))
        let embedding = try await embed("how did the exchange of letters begin")
        let cut = try #require(SemanticQuantization.truncate(embedding, to: index.dims))
        let query = try #require(SemanticQuantization.quantizeInt8(cut))
        // d1, d2 and d3 are the volume's first three rows.
        let scores = try (0..<3).map { try #require(shard.cosine(row: $0, query: query.codes, queryScale: query.scale)) }
        #expect(abs(scores[1] - 1) < 1e-4, "the question's own row scores \(scores[1])")
        #expect(abs(scores[0] - (1 - 2 * 90.0 / 512)) < 1e-4, "d1 scores \(scores[0])")
        #expect(abs(scores[2] - (1 - 2 * 100.0 / 512)) < 1e-4, "d3 scores \(scores[2])")
        // What the chip shows for the three.
        #expect(scores.map(SemanticScoreCopy.percent(for:)) == [65, 100, 61])

        #expect(UITestMeaningSeeder.syntheticShard(for: "no-such-volume", index: index, corpus: corpus) == nil)
    }
}

// MARK: - UITestMeaningSeamSearchTests

/// The app's own searcher, built by the function the launch builds it with under the seam
/// (`UITestMeaningSeeder.makeSearcher`) and run as a UI test's launch runs it (#1577 lane 3). What
/// these return is what the UI suite's rows are made from.
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
@Suite("The UI-test Meaning seam: the real searcher run through it")
struct UITestMeaningSeamSearchTests {

    /// The seam's searcher over the shipped artifacts, with its store in `directory`.
    private func makeSearcher(
        _ index: SemanticVectorIndex, _ corpus: SemanticCorpusVectors, in directory: URL
    ) async throws -> SemanticQuerySearcher {
        let seam = try await ShippedVectors.seam(index, corpus, in: directory)
        return UITestMeaningSeeder.makeSearcher(
            seam, index: index, corpus: corpus,
            modelStore: SemanticModelStore(directory: directory.appendingPathComponent("model"),
                                           expectedSHA256: index.provenance.modelFileSHA256))
    }

    /// What the UI suite's plain searches read: the near question's first three hits, in order and
    /// with their percentages, and for the far question no hit at all and 800 candidates unscored,
    /// which is the figure the suite reads from the strip.
    @Test("A plain search puts the fixture's three documents first for a near question, and scores nothing for a far one")
    func aPlainSearchThroughTheSeam() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = try await makeSearcher(index, corpus, in: directory)

        let near = try await searcher.search("how did the exchange of letters begin", limit: 100)
        #expect(near.hits.prefix(3).map(\.documentID) == ["d2", "d1", "d3"])
        #expect(near.hits.prefix(3).map { SemanticScoreCopy.percent(for: $0.score) } == [100, 65, 61])
        #expect(!near.hits.isEmpty && near.hits.allSatisfy { $0.volumeID == ShippedVectors.fixtureVolume },
                "the seam's store holds the fixture volume's file alone, so nothing else can be scored")
        #expect(near.downloadingVolumes == 0, "the seam's fetch request declines every volume")

        let far = try await searcher.search("a question from far afield", limit: 100)
        #expect(far.hits.isEmpty, "a far question's 800 candidates hold none of the fixture volume's rows")
        #expect(far.unscoredCandidates == 800)
        #expect(far.downloadingVolumes == 0)
    }

    /// The near question's three rows are the first three of 78: the real volume has 120 documents,
    /// 78 of their rows are among the candidates, and the planted file scores every one. The strip
    /// a reader sees counts the 75 the fixture does not hold, and the 722 candidates elsewhere.
    ///
    /// These are the figures the seeder's comment, the UI suite's header and the runbook quote. A
    /// re-pack of the bundle that moves one of them and nothing in the test above changes what
    /// those say and nothing the UI suite reads: correct the figure in all three.
    @Test("The figures the seam's documents quote of a plain search: 78 hits and 722 unscored in 179 volumes; 800 unscored in 134")
    func theFiguresTheDocumentsQuoteOfAPlainSearch() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = try await makeSearcher(index, corpus, in: directory)

        let near = try await searcher.search("how did the exchange of letters begin", limit: 100)
        #expect(near.hits.count == 78, "three are the fixture's; the strip counts the other 75 as not listed")
        #expect(near.unscoredCandidates == 722)
        #expect(near.unscoredVolumes == 179)

        let far = try await searcher.search("a question from far afield", limit: 100)
        #expect(far.unscoredVolumes == 134, "the volumes a match file in the simulator's own store could have scored")
    }

    /// What #1577 lane 1 changed, through the seam: inside a set, every member with a row is
    /// scored, whether or not the corpus-wide search would have reached it.
    @Test("A far question inside a set of the fixture's documents ranks every member that has a row, and counts the rest")
    func aSearchInsideASetThroughTheSeam() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = try await makeSearcher(index, corpus, in: directory)
        let members = (ShippedVectors.withRows + ShippedVectors.withoutRows)
            .map { "\(ShippedVectors.fixtureVolume)/\($0)" }

        let ranked = try await searcher.search("a question from far afield", within: members, limit: 100)
        #expect(ranked.hits.map(\.documentID) == ["d2", "d3", "d1"],
                "d2 and d3 are 194 bits from the far question and tie, the lower row first; d1 is 214")
        #expect(ranked.hits.map { SemanticScoreCopy.percent(for: $0.score) } == [24, 24, 16])
        #expect(ranked.withoutVector == 3, "n1, n2 and t1 are the fixture's own and have no bundled row")
        #expect(ranked.unscoredCandidates == 0)
    }

    /// The seam's store is its own: one file, the fixture volume's, in a folder made again at each
    /// launch that asks. A match file the simulator's app holds for another volume is not in it, so
    /// it cannot put a row into a list the UI suite reads.
    @Test("The seam's store holds the planted file and nothing else, and is made afresh each time")
    func theSeamsStoreIsItsOwn() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let seam = try await ShippedVectors.seam(index, corpus, in: directory)
        #expect(seam.volumeID == ShippedVectors.fixtureVolume)
        let folder = await seam.shardStore.directory
        #expect(folder == directory)
        let held = await seam.shardStore.volumeIDsOnDisk()
        #expect(held == [ShippedVectors.fixtureVolume])
        let opened = await seam.shardStore.shard(for: ShippedVectors.fixtureVolume)
        #expect(opened?.documentCount == 120)

        // What an earlier launch, or anything else, left in the folder does not survive the next.
        let stray = directory.appendingPathComponent("frus1861.vec")
        try Data("not a match file".utf8).write(to: stray)
        let again = try await ShippedVectors.seam(index, corpus, in: directory)
        #expect(!FileManager.default.fileExists(atPath: stray.path))
        let heldAgain = await again.shardStore.volumeIDsOnDisk()
        #expect(heldAgain == [ShippedVectors.fixtureVolume])
    }

    @Test("A launch that does not ask for both is given no seam, and no folder is made")
    func aLaunchThatDoesNotAskMakesNothing() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let environments: [[String: String]] = [
            [:],
            // The seam's key without a seeded volume: there is no volume to plant for.
            [UITestMeaningSeeder.environmentKey: "1"],
            // The fixture volume seeded and the seam not asked for, as every other UI suite launches.
            [UITestVolumeSeeder.environmentKey: ShippedVectors.fixtureVolume],
            [UITestVolumeSeeder.environmentKey: ShippedVectors.fixtureVolume, UITestMeaningSeeder.environmentKey: "0"],
            [UITestVolumeSeeder.environmentKey: "", UITestMeaningSeeder.environmentKey: "1"],
        ]
        for environment in environments {
            let seam = await UITestMeaningSeeder.prepare(
                environment: environment, index: index, corpus: corpus, storeDirectory: directory)
            #expect(seam == nil, "a seam was made for \(environment)")
            #expect(!FileManager.default.fileExists(atPath: directory.path), "a folder was made for \(environment)")
        }
    }

    /// A seam is whole or it is not made: a searcher over a store with no file in it would list
    /// nothing for every question, which a UI test would read as the app's answer.
    @Test("A seam whose file cannot be planted is not made")
    func aSeamWhoseFileCannotBePlantedIsNotMade() async throws {
        let (index, corpus) = try ShippedVectors.load()
        // A regular file where the store's parent folder would be: no folder can be made under it.
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeaningSeam-blocker-\(UUID().uuidString)")
        try Data("in the way".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let seam = await UITestMeaningSeeder.prepare(
            environment: ShippedVectors.asking, index: index, corpus: corpus,
            storeDirectory: blocker.appendingPathComponent("store", isDirectory: true))
        #expect(seam == nil)
    }

    @Test("A fixture volume the bundle holds no rows for gets no seam, and what the folder held is left alone")
    func aVolumeWithNoRowsGetsNoSeam() async throws {
        let (index, corpus) = try ShippedVectors.load()
        let directory = ShippedVectors.storeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try await ShippedVectors.seam(index, corpus, in: directory)
        let planted = directory.appendingPathComponent("\(ShippedVectors.fixtureVolume).vec")
        #expect(FileManager.default.fileExists(atPath: planted.path))

        let asking = [UITestVolumeSeeder.environmentKey: "uitest-bulk-01", UITestMeaningSeeder.environmentKey: "1"]
        let seam = await UITestMeaningSeeder.prepare(
            environment: asking, index: index, corpus: corpus, storeDirectory: directory)
        #expect(seam == nil)
        #expect(FileManager.default.fileExists(atPath: planted.path),
                "the folder is made again only once both stand-ins are in hand")
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("uitest-bulk-01.vec").path))
    }
}

// MARK: - SemanticScoreCopyTests

/// The score's percentage and the words a row's accessibility value says (#1577 lane 3).
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
@Suite("The semantic score, as a percentage and in words")
struct SemanticScoreCopyTests {

    @Test("The percentage is the score clamped to 0…1 and rounded")
    func percent() {
        #expect(SemanticScoreCopy.percent(for: 1) == 100)
        #expect(SemanticScoreCopy.percent(for: 0.6484375) == 65)
        #expect(SemanticScoreCopy.percent(for: 0.609375) == 61)
        #expect(SemanticScoreCopy.percent(for: 0.004) == 0)
        #expect(SemanticScoreCopy.percent(for: 0.005) == 1)
        #expect(SemanticScoreCopy.percent(for: -0.3) == 0)
        #expect(SemanticScoreCopy.percent(for: 1.2) == 100)
    }

    @Test("The accessibility value says the chip's figure in words")
    func accessibilityValue() {
        #expect(SemanticScoreCopy.accessibilityValue(for: 0.6484375) == "Semantic match 65 percent")
        #expect(SemanticScoreCopy.accessibilityValue(for: 1) == "Semantic match 100 percent")
        #expect(SemanticScoreCopy.accessibilityValue(for: -1) == "Semantic match 0 percent")
    }

    @Test("The iPhone's result row gives its score as its accessibility value, and the chip draws the same figure")
    func theRowSaysItsScore() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SearchView.swift"), encoding: .utf8)
        let squeezed = view.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined().filter { !$0.isWhitespace }
        #expect(squeezed.contains(
            ".accessibilityLabel(result.header)"
            + ".accessibilityValue(result.semanticScore.map(SemanticScoreCopy.accessibilityValue(for:))??\"\")"),
                "the row's value does not follow its label, or is not the score's words")
        let chip = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Search/SemanticSearchSharedViews.swift"),
                              encoding: .utf8)
        #expect(chip.contains("Int64(SemanticScoreCopy.percent(for: score))"),
                "the chip no longer draws the figure the accessibility value says")
    }
}

// MARK: - UITestMeaningSeamWiringTests

/// Where the launch asks the seam, read from source (#1577 lane 3). The launch itself cannot be
/// driven by a unit test. What the seam's searcher is made of is not read here: the search suite
/// above builds it with the function the launch calls.
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
@Suite("The UI-test Meaning seam: where the launch asks it")
struct UITestMeaningSeamWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `text` without its comment lines and without whitespace.
    private static func squeezedCode(_ text: String) -> String {
        text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined().filter { !$0.isWhitespace }
    }

    @Test("In DEBUG the launch takes the seam's searcher when there is one, and builds its own otherwise and in every other build")
    func theLaunchTakesTheSeamsSearcherInDebugOnly() throws {
        let code = Self.squeezedCode(try Self.source("FRUSExplorer/App/FRUSExplorerApp.swift"))
        #expect(code.contains("""
            #ifDEBUGvarseededSearcher:SemanticQuerySearcher?ifletseam=awaitUITestMeaningSeeder.prepare(\
            index:semanticIndex,corpus:semanticCorpus){seededSearcher=UITestMeaningSeeder.makeSearcher(\
            seam,index:semanticIndex,corpus:semanticCorpus,modelStore:modelStore)}\
            #elseletseededSearcher:SemanticQuerySearcher?=nil#endif\
            appState.semanticQuerySearcher=seededSearcher??searcherStore.map{shardStorein\
            SemanticQuerySearcher(index:semanticIndex,corpus:semanticCorpus,modelStore:modelStore,shardStore:shardStore,
            """), "the seam is not asked inside DEBUG alone, or the app's own searcher is not what a launch without it builds")
        // The searcher every other launch gets still asks the app for a match file.
        #expect(code.contains("returnawaitappState.requestSemanticShardForSearch(volumeID)"))
        #expect(code.components(separatedBy: "UITestMeaningSeeder.").count - 1 == 2,
                "the launch names the seeder elsewhere than the one DEBUG block")
    }

    /// The seam's searcher, read where it is made. The search suite proves the three by what they do
    /// (nothing fetched, the stand-in's ranking, the planted file's scores); this holds the text, so
    /// that the launch's searcher and the suite's cannot part.
    @Test("The seam's searcher is made in one place, of the seam's store, its encoder and a fetch request that declines")
    func theSeamsSearcherIsMadeInOnePlace() throws {
        let seeder = Self.squeezedCode(try Self.source("FRUSExplorer/App/UITestMeaningSeeder.swift"))
        #expect(seeder.contains("""
            SemanticQuerySearcher(index:index,corpus:corpus,modelStore:modelStore,shardStore:seam.shardStore,\
            requestShardFetch:{_infalse},embedOverride:seam.embed)
            """))
        #expect(seeder.components(separatedBy: "SemanticQuerySearcher(").count - 1 == 1)
        // The seam's store is one the seeder makes. It is handed none, so it cannot be the app's.
        #expect(seeder.contains("letstore=SemanticShardStore(directory:storeDirectory,provenance:index.provenance,"))
        #expect(!seeder.contains("appState"), "the seeder reaches into the app's state")
        #expect(!seeder.contains("removeShard"), "the seeder removes a match file from a store")
    }

    @Test("The seeder is compiled in DEBUG builds alone")
    func theSeederIsDebugOnly() throws {
        let seeder = try Self.source("FRUSExplorer/App/UITestMeaningSeeder.swift")
        let lines = seeder.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
        #expect(lines.first == "#if DEBUG")
        #expect(lines.last == "#endif")
        #expect(lines.filter { $0.hasPrefix("#if") || $0.hasPrefix("#endif") || $0.hasPrefix("#else") }.count == 2,
                "another conditional inside the file would let part of it out of the DEBUG block")
    }
}
