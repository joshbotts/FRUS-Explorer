// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - Support

/// Records the volumes a search asks to fetch and answers each ask as `AppState` would.
private actor FetchRecorder {
    private(set) var asked: [String] = []
    private let accepts: Bool
    init(accepts: Bool = true) { self.accepts = accepts }
    func record(_ volumeID: String) -> Bool {
        asked.append(volumeID)
        return accepts
    }
}

/// Counts the embed step's calls, so a test can show the encoder was never asked.
private actor EmbedCounter {
    private(set) var calls = 0
    func embed() -> [Double] {
        calls += 1
        return SemanticSetFixture.queryEmbedding
    }
}

/// A new temporary directory. Each test removes its own in a `defer`: a closure-taking helper
/// would have a main-actor test hand its body to a nonisolated function.
private func makeSetDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SemanticSet-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// A searcher over artifacts written by ``SemanticSetFixture``, with the embedding injected.
private func makeSetSearcher(
    _ artifacts: SemanticSetFixture.Artifacts,
    recorder: FetchRecorder = FetchRecorder(),
    embed: (@Sendable (String) async throws -> [Double])? = { _ in SemanticSetFixture.queryEmbedding }
) -> SemanticQuerySearcher {
    SemanticQuerySearcher(
        index: artifacts.index,
        corpus: artifacts.corpus,
        modelStore: artifacts.modelStore,
        shardStore: artifacts.shardStore,
        requestShardFetch: { volumeID in await recorder.record(volumeID) },
        embedOverride: embed)
}

private func key(_ hit: SemanticQuerySearcher.Hit) -> String { "\(hit.volumeID)/\(hit.documentID)" }
private func key(_ result: SearchResult) -> String { "\(result.volumeId)/\(result.documentId)" }

// MARK: - The searcher

/// A Meaning search inside a document set (#1577 lane 1), on a synthetic index, corpus tier and
/// shards written with the kit's own writers. The suite has no enabling condition: it needs no
/// model, no bundled artifact and no gitignored file, so it runs on every checkout.
///
/// The fixture's set is one the corpus-wide search never returns: 120 documents of another volume
/// are nearer the query than any member, and they fill the whole candidate pool.
@Suite("Meaning search inside a document set")
struct SemanticSetSearchTests {

    // MARK: Ranking

    @Test("A search inside a set returns only its members, in brute-force cosine order")
    func membersInBruteForceOrder() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)
        try #require(expected.count == 12, "the fixture plants twelve rankable members")

        let results = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 100)

        #expect(results.hits.map(key) == expected.map(\.key), """
            the hits must be the set's rankable members in brute-force cosine order, a tie \
            going to the lower row
            """)
        for (hit, wanted) in zip(results.hits, expected) {
            #expect(abs(hit.score - wanted.score) < 1e-6,
                    "\(wanted.key) scored \(hit.score); its cosine with the query is \(wanted.score)")
        }
        let members = Set(SemanticSetFixture.documentSet)
        #expect(results.hits.allSatisfy { members.contains(key($0)) },
                "a document outside the set was returned")
        // `d11` and `d12` are nearer the query than every member, and are not in the set.
        #expect(!results.hits.contains { $0.volumeID == SemanticSetFixture.held
            && ["d11", "d12"].contains($0.documentID) })
    }

    /// The two ties are planted so that a tie broken by key would order them the other way round:
    /// `"…/d10"` sorts before `"…/d9"`, and the first edition's id sorts before the second's,
    /// while the rows run `d9`, `d10` and second edition, first edition.
    @Test("A tie goes to the lower corpus row, which is not key order")
    func tiesGoToTheLowerRow() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let hits = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 100).hits
        let keys = hits.map(key)

        let nine = "\(SemanticSetFixture.held)/d9", ten = "\(SemanticSetFixture.held)/d10"
        let nineAt = try #require(keys.firstIndex(of: nine))
        let tenAt = try #require(keys.firstIndex(of: ten))
        #expect(hits[nineAt].score == hits[tenAt].score, "precondition: d9 and d10 tie")
        #expect(ten < nine, "precondition: key order puts d10 first")
        #expect(nineAt + 1 == tenAt, "d9 holds the lower row, so it comes first")

        let second = "\(SemanticSetFixture.twinSecond)/d1", first = "\(SemanticSetFixture.twinFirst)/d1"
        let secondAt = try #require(keys.firstIndex(of: second))
        let firstAt = try #require(keys.firstIndex(of: first))
        #expect(hits[secondAt].score == hits[firstAt].score, "precondition: the twins tie")
        #expect(first < second, "precondition: key order puts the first edition first")
        #expect(secondAt + 1 == firstAt, "the second edition holds the lower rows, so it comes first")
    }

    @Test("Edition twins are both kept: the set is the reader's")
    func twinsAreNotFolded() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let hits = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 100).hits
        let foldKeys = hits.map {
            SemanticEditionTwins.foldKey(volumeID: $0.volumeID, documentID: $0.documentID)
        }
        #expect(foldKeys.count - Set(foldKeys).count == 1,
                "the set holds one edition pair, and both of its documents must be listed")
    }

    /// The control inside this tree: the same question asked of the whole series returns a hundred
    /// documents, none of them in the set. Filtering that list down to the set, which is what the
    /// Meaning backend did before #1577, leaves nothing.
    @Test("The corpus-wide search returns none of the set, so filtering it down leaves nothing")
    func corpusWideSearchMissesTheSet() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let corpusWide = try await searcher.search("q", limit: 100)
        #expect(corpusWide.hits.count == 100)
        #expect(corpusWide.hits.allSatisfy { $0.volumeID == SemanticSetFixture.crowd })
        #expect(corpusWide.rankedWithin == nil)
        #expect(corpusWide.withoutVector == 0)

        let members = Set(SemanticSetFixture.documentSet)
        #expect(corpusWide.hits.filter { members.contains(key($0)) }.isEmpty)
    }

    // MARK: Accounting

    @Test("Every member is ranked, without a vector, or without its match file, and the three sum to the set")
    func everyMemberIsAccountedFor() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let results = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 100)

        #expect(results.rankedWithin == SemanticSetFixture.documentSetSize,
                "a repeated key counts once")
        #expect(results.withoutVector == SemanticSetFixture.plantedWithoutVector)
        #expect(results.unscoredCandidates == SemanticSetFixture.plantedWithoutShard)
        #expect(results.unscoredVolumes == 1)
        #expect(results.downloadingVolumes == 1, "the one missing file was asked for, and the ask accepted")
        #expect(results.hits.count + results.withoutVector + results.unscoredCandidates
                == results.rankedWithin)
    }

    @Test("The limit cuts the list and leaves the accounting alone")
    func limitCutsTheListOnly() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory))
        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)
        let results = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 5)

        #expect(results.hits.map(key) == expected.prefix(5).map(\.key))
        #expect(results.rankedWithin == SemanticSetFixture.documentSetSize)
        #expect(results.withoutVector == SemanticSetFixture.plantedWithoutVector)
        #expect(results.unscoredCandidates == SemanticSetFixture.plantedWithoutShard)
    }

    // MARK: The encoder

    /// Three sets with nothing to score: an empty one, one with no vectors, and one whose every
    /// rankable member is in a volume with no match file here. None reaches the encoder, and the
    /// third still asks for its file.
    @Test("A set with nothing to score never asks the encoder, and still asks for its missing file")
    func nothingToScoreNeverEncodes() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = EmbedCounter()
        let recorder = FetchRecorder()
        let searcher = makeSetSearcher(
            try SemanticSetFixture.writeArtifacts(in: directory), recorder: recorder,
            embed: { _ in await counter.embed() })

        let empty = try await searcher.search("q", within: [], limit: 100)
        #expect(empty.hits.isEmpty)
        #expect(empty.rankedWithin == 0, "an empty set is a set of none, not no set")

        let vectorless = try await searcher.search(
            "q", within: ["\(SemanticSetFixture.held)/frontmatter", "not-a-key"], limit: 100)
        #expect(vectorless.hits.isEmpty)
        #expect(vectorless.rankedWithin == 2)
        #expect(vectorless.withoutVector == 2)
        #expect(await recorder.asked.isEmpty, "precondition: no file has been asked for yet")

        let fileless = try await searcher.search(
            "q", within: ["\(SemanticSetFixture.absent)/d2", "\(SemanticSetFixture.absent)/d5",
                          "\(SemanticSetFixture.held)/frontmatter"], limit: 100)
        #expect(fileless.hits.isEmpty)
        #expect(fileless.rankedWithin == 3)
        #expect(fileless.unscoredCandidates == 2)
        #expect(fileless.unscoredVolumes == 1)
        #expect(fileless.withoutVector == 1)
        #expect(fileless.downloadingVolumes == 1)
        #expect(await recorder.asked == [SemanticSetFixture.absent],
                "a set that cannot be scored for want of a file must still ask for the file")

        #expect(await counter.calls == 0, "nothing could be scored, so nothing was encoded")

        _ = try await searcher.search("q", within: ["\(SemanticSetFixture.held)/d1"], limit: 100)
        #expect(await counter.calls == 1, "precondition: a rankable member does reach the encoder")
    }

    /// The model's absence is reported only where the model is what stands between the reader
    /// and a ranking. A set with nothing to score is told about the set, not offered 229 MB.
    @Test("With no model, a set that can be ranked names the download and one that cannot does not")
    func modelAbsentIsReportedOnlyWhereItMatters() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // No embed override, and a model store over an empty directory: the real door.
        let searcher = makeSetSearcher(
            try SemanticSetFixture.writeArtifacts(in: directory), embed: nil)

        let empty = try await searcher.search("q", within: [], limit: 100)
        #expect(empty.rankedWithin == 0)

        let fileless = try await searcher.search(
            "q", within: ["\(SemanticSetFixture.absent)/d2"], limit: 100)
        #expect(fileless.unscoredCandidates == 1)

        await #expect(throws: SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded) {
            _ = try await searcher.search(
                "q", within: ["\(SemanticSetFixture.held)/d1"], limit: 100)
        }
    }

    // MARK: Missing match files

    /// The plan both fetch tests share: thirty-three volumes with unranked members.
    ///
    /// Two with ten members sort last by id and must be asked for. One with a single member sorts
    /// first by id and must not be. Thirty tie at five, and the bound of 24 leaves room for
    /// twenty-two of them: the twenty-two whose ids sort first. A rule by id alone would ask for
    /// the single-member volume; a tie left to dictionary order would pick the right twenty-two
    /// of thirty about once in six million.
    private static let unrankedPlan: [(id: String, members: Int)] = {
        var plan: [(id: String, members: Int)] = [("frus1900v98", 10), ("frus1900v99", 10)]
        // Listed in descending id order, so that slot order in an index built from this plan is
        // the reverse of id order within the tie.
        for number in (1...30).reversed() {
            plan.append((String(format: "frus1900v%02d", number), 5))
        }
        plan.append(("frus1900v00", 1))
        return plan
    }()

    /// The volumes ``unrankedPlan`` must have asked for, most unranked members first.
    private static let expectedFetches: [String] =
        ["frus1900v98", "frus1900v99"] + (1...22).map { String(format: "frus1900v%02d", $0) }

    @Test("The volumes asked for are those with most unranked members, a tie going to the lower id")
    func volumesWorthFetchingRule() {
        #expect(SemanticQuerySearcher.setFetchVolumeLimit == 24,
                "precondition: the plan is built for a bound of 24")
        let unranked = Dictionary(uniqueKeysWithValues: Self.unrankedPlan.map { ($0.id, $0.members) })
        #expect(SemanticQuerySearcher.volumesWorthFetching(unranked) == Self.expectedFetches)
        #expect(SemanticQuerySearcher.volumesWorthFetching([:]).isEmpty)
        #expect(SemanticQuerySearcher.volumesWorthFetching(["v": 3]) == ["v"])
    }

    /// The same plan through the searcher, with no match file on the device at all. In the index
    /// the tied volumes' slots run opposite to their ids, so a tie broken by slot would ask for
    /// `v30` down to `v09`.
    @Test("A search asks for the bounded choice of missing match files, each once")
    func fetchesAreBoundedAndMostMembersFirst() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let volumes = Self.unrankedPlan.map { plan in
            SemanticSetFixture.Volume(
                id: plan.id,
                vectors: (0..<plan.members).map { _ in SemanticSetFixture.vector(positives: 8) })
        }
        let set = volumes.flatMap { volume in volume.documentIDs.map { "\(volume.id)/\($0)" } }
        let recorder = FetchRecorder(accepts: true)
        let searcher = makeSetSearcher(
            try SemanticSetFixture.writeArtifacts(in: directory, volumes: volumes, withShards: []),
            recorder: recorder)

        let results = try await searcher.search("q", within: set, limit: 100)

        let asked = await recorder.asked
        #expect(Set(asked) == Set(Self.expectedFetches))
        #expect(asked.count == 24, "each volume is asked for once")
        #expect(results.hits.isEmpty)
        #expect(results.unscoredCandidates == set.count)
        #expect(results.unscoredVolumes == 33)
        #expect(results.downloadingVolumes == 24,
                "only the volumes asked for can be downloading")
    }

    @Test("A declined fetch is not a download")
    func declinedFetchesCountAsNothing() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = FetchRecorder(accepts: false)
        let searcher = makeSetSearcher(
            try SemanticSetFixture.writeArtifacts(in: directory), recorder: recorder)
        let results = try await searcher.search(
            "q", within: SemanticSetFixture.documentSet, limit: 100)
        #expect(await recorder.asked == [SemanticSetFixture.absent])
        #expect(results.unscoredVolumes == 1)
        #expect(results.downloadingVolumes == 0)
    }
}

// MARK: - The backend and the view model

/// The Meaning backend with a document set among its parameters, over the synthetic artifacts and
/// a real index of the same documents (#1577 lane 1).
@Suite("Meaning backend inside a document set")
@MainActor
struct SemanticSetBackendTests {

    /// A backend over the fixture: the synthetic vectors, and an index holding every planted
    /// document.
    private func makeBackend(
        in directory: URL,
        indexed: Set<String> = Set(SemanticSetFixture.volumes.map(\.id)),
        omittingFromTheIndex omitted: Set<String> = [],
        embed: @escaping @Sendable (String) async throws -> [Double] = { _ in SemanticSetFixture.queryEmbedding }
    ) async throws -> (backend: SemanticSearchBackend, service: SearchService) {
        let volumesDirectory = directory.appendingPathComponent("volumes", isDirectory: true)
        try SemanticSetFixture.writeTEIVolumes(to: volumesDirectory, omitting: omitted)
        let databaseURL = directory.appendingPathComponent("index.sqlite")
        let store = try FTS5Store(databaseURL: databaseURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: databaseURL,
                                            volumesDirectory: volumesDirectory, concurrencyLimit: 1)
        for volume in SemanticSetFixture.volumes { try await pipeline.indexVolume(volume.id) }
        let service = SearchService(fts5Store: store, pipeline: pipeline)
        let searcher = makeSetSearcher(try SemanticSetFixture.writeArtifacts(in: directory), embed: embed)
        let backend = SemanticSearchBackend(
            searcher: searcher, searchService: service,
            manifestStore: ManifestStore(bundledEntries: []),
            indexedVolumeIds: { indexed })
        return (backend, service)
    }

    /// The acceptance test. On the code before #1577 the same call returned no rows and reported
    /// a hundred matches removed by "your filters": the series' closest hundred, all outside the
    /// set. The failure message carries both figures so the control run can be quoted.
    @Test("A document set is ranked inside: the rows are its members, closest first")
    func documentSetIsRankedInside() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, _) = try await makeBackend(in: directory)
        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)

        let outcome = try await backend.run(
            query: "q", parameters: SearchParameters(documentIds: SemanticSetFixture.documentSet))

        #expect(outcome.results.map(key) == expected.map(\.key), """
            a Meaning search inside a document set must list the set's members, closest first; \
            it listed \(outcome.results.count) row(s), with filteredOut \
            \(outcome.disclosure.filteredOut)
            """)
        #expect(outcome.beyondLibrary.isEmpty)
    }

    @Test("The disclosure carries the set's accounting, and the set is not counted as a filter")
    func disclosureCarriesTheAccounting() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, _) = try await makeBackend(in: directory)
        let outcome = try await backend.run(
            query: "q", parameters: SearchParameters(documentIds: SemanticSetFixture.documentSet))
        let disclosure = outcome.disclosure

        #expect(disclosure.rankedWithin == SemanticSetFixture.documentSetSize)
        #expect(disclosure.withoutVector == SemanticSetFixture.plantedWithoutVector)
        #expect(disclosure.unscoredCandidates == SemanticSetFixture.plantedWithoutShard)
        #expect(disclosure.unscoredVolumes == 1)
        #expect(disclosure.rankedCount == 12)
        #expect(!disclosure.filtersApplied, "the set was ranked inside; nothing else constrains")
        #expect(disclosure.filteredOut == 0)
    }

    @Test("Each row carries its cosine for display and its negation for ordering")
    func rowsCarryBothScores() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, _) = try await makeBackend(in: directory)
        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)
        let outcome = try await backend.run(
            query: "q", parameters: SearchParameters(documentIds: SemanticSetFixture.documentSet))
        try #require(outcome.results.count == expected.count)
        for (row, wanted) in zip(outcome.results, expected) {
            let score = try #require(row.semanticScore)
            #expect(abs(score - wanted.score) < 1e-6)
            #expect(row.bm25Score == -score)
        }
    }

    /// The set is ranked inside; a volume scope is still a filter, applied to the ranked list.
    @Test("Other filters still narrow after ranking")
    func otherFiltersNarrowAfterRanking() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, _) = try await makeBackend(in: directory)
        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)
            .filter { $0.key.hasPrefix("\(SemanticSetFixture.held)/") }
        try #require(expected.count == 10)

        let outcome = try await backend.run(
            query: "q",
            parameters: SearchParameters(volumeIds: [SemanticSetFixture.held],
                                         documentIds: SemanticSetFixture.documentSet))

        #expect(outcome.results.map(key) == expected.map(\.key))
        #expect(outcome.disclosure.filtersApplied)
        #expect(outcome.disclosure.filteredOut == 2, "the edition pair is outside the volume scope")
        #expect(outcome.disclosure.rankedWithin == SemanticSetFixture.documentSetSize)
    }

    @Test("With no document set the run is the corpus-wide search, unchanged")
    func noSetIsTheCorpusWideSearch() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, _) = try await makeBackend(in: directory)
        let outcome = try await backend.run(query: "q", parameters: SearchParameters())
        #expect(outcome.results.count == SemanticSearchBackend.hitLimit)
        #expect(outcome.results.allSatisfy { $0.volumeId == SemanticSetFixture.crowd })
        #expect(outcome.disclosure.rankedWithin == nil)
        #expect(outcome.disclosure.rankedCount == nil)
        #expect(outcome.disclosure.withoutVector == 0)
    }

    @Test("An empty set lists nothing, says so, and asks nothing of the encoder")
    func emptySetListsNothing() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = EmbedCounter()
        let (backend, _) = try await makeBackend(in: directory, embed: { _ in await counter.embed() })
        let outcome = try await backend.run(query: "q", parameters: SearchParameters(documentIds: []))
        #expect(outcome.results.isEmpty)
        #expect(outcome.beyondLibrary.isEmpty)
        #expect(outcome.disclosure.rankedWithin == 0)
        #expect(await counter.calls == 0)
    }

    @Test("A member in a volume this device has not indexed is listed beyond the library")
    func unindexedMemberIsBeyondTheLibrary() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexed = Set(SemanticSetFixture.volumes.map(\.id))
            .subtracting([SemanticSetFixture.twinFirst])
        let (backend, _) = try await makeBackend(in: directory, indexed: indexed)
        let outcome = try await backend.run(
            query: "q", parameters: SearchParameters(documentIds: SemanticSetFixture.documentSet))
        #expect(outcome.results.count == 11)
        #expect(outcome.beyondLibrary.map(\.id) == ["\(SemanticSetFixture.twinFirst)/d1"])
    }

    // MARK: Hits the index does not hold

    /// The vectors name two documents the device's copy of the volume does not hold. They are
    /// ranked and cannot be listed. They are counted as that, and with no other filter set
    /// nothing says a filter removed them.
    @Test("Ranked documents the index does not hold are counted, and not blamed on filters")
    func rankedButUnindexedIsCounted() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lost: Set<String> = ["\(SemanticSetFixture.held)/d11", "\(SemanticSetFixture.held)/d12"]
        let (backend, _) = try await makeBackend(in: directory, omittingFromTheIndex: lost)

        let outcome = try await backend.run(
            query: "q", parameters: SearchParameters(documentIds: lost.sorted()))

        #expect(outcome.results.isEmpty)
        #expect(outcome.beyondLibrary.isEmpty)
        #expect(outcome.disclosure.rankedCount == 2)
        #expect(outcome.disclosure.notIndexedHere == 2)
        #expect(outcome.disclosure.filteredOut == 0)
        #expect(!outcome.disclosure.filtersApplied)
        let english = Locale(identifier: "en_US")
        let statement = SemanticMeaningEmptyState.emptyStatement(
            disclosure: outcome.disclosure, locale: english)
        #expect(statement.contains("is indexed on this device"))
        #expect(!statement.contains("filters"))
        let strip = SemanticModeStrip.caption(
            disclosure: outcome.disclosure, beyondCount: 0, locale: english)
        #expect(strip.contains("2 close matches are not listed"))
        #expect(!strip.contains("Your filters removed"))
    }

    /// The same two, beside one member the index does hold, under a volume scope that removes
    /// that one. The filter removed one match, not three: until #1577 the two the index lacks
    /// were absent from the filter's key set as well, and were counted with it.
    @Test("A filter is charged only with the matches it removed")
    func unindexedHitsAreNotCountedAsFiltered() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lost: Set<String> = ["\(SemanticSetFixture.held)/d11", "\(SemanticSetFixture.held)/d12"]
        let (backend, _) = try await makeBackend(in: directory, omittingFromTheIndex: lost)

        let outcome = try await backend.run(
            query: "q",
            parameters: SearchParameters(
                volumeIds: [SemanticSetFixture.twinFirst],
                documentIds: lost.sorted() + ["\(SemanticSetFixture.held)/d1"]))

        #expect(outcome.results.isEmpty)
        #expect(outcome.disclosure.rankedCount == 3)
        #expect(outcome.disclosure.filtersApplied)
        #expect(outcome.disclosure.filteredOut == 1, "the volume scope removed d1 and nothing else")
        #expect(outcome.disclosure.notIndexedHere == 2)
    }

    /// The rule is the backend's, not the set's: a search of the whole series whose closest
    /// hundred include two documents the index lacks lists ninety-eight and says why.
    @Test("Across the series too, a close match the index does not hold is counted and not listed")
    func corpusWideUnindexedHitsAreCounted() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lost: Set<String> = ["\(SemanticSetFixture.crowd)/d1", "\(SemanticSetFixture.crowd)/d2"]
        let (backend, _) = try await makeBackend(in: directory, omittingFromTheIndex: lost)

        let outcome = try await backend.run(query: "q", parameters: SearchParameters())

        #expect(outcome.results.count == SemanticSearchBackend.hitLimit - 2)
        #expect(outcome.disclosure.notIndexedHere == 2)
        #expect(outcome.disclosure.filteredOut == 0)
        #expect(outcome.disclosure.rankedWithin == nil)
        let strip = SemanticModeStrip.caption(
            disclosure: outcome.disclosure, beyondCount: 0, locale: Locale(identifier: "en_US"))
        #expect(strip.contains("across the whole series"))
        #expect(strip.contains("2 close matches are not listed"))
    }

    // MARK: Through the view model

    /// The emitter itself: the iPhone and iPad view model with a working corpus applied, running a
    /// Meaning search through the real backend, and recording it.
    @Test("With a working corpus applied, the view model lists its members and signs the set")
    func viewModelRanksInsideAnAppliedCorpus() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (backend, service) = try await makeBackend(in: directory)
        let viewModel = SearchViewModel(searchService: service)
        viewModel.semanticBackend = backend
        viewModel.appliedWorkingCorpusKeys = SemanticSetFixture.documentSet
        viewModel.searchMode = .meaning
        viewModel.keywords = "how did the mission report"
        #expect(viewModel.documentSetSize == SemanticSetFixture.documentSet.count)

        await viewModel.search()

        let expected = SemanticSetFixture.bruteForceRanking(of: SemanticSetFixture.documentSet)
        #expect(viewModel.results.map(key) == expected.map(\.key))
        #expect(viewModel.semanticDisclosure?.rankedWithin == SemanticSetFixture.documentSetSize)
        #expect(viewModel.searchError == nil)

        let container = try ModelContainer(
            for: SearchHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let defaults = try #require(UserDefaults(suiteName: "semantic-set-\(UUID().uuidString)"))
        defaults.set(true, forKey: AppState.researchLoggingPreferenceKey)
        viewModel.recordSearchHistory(projectId: nil, indexedVolumeCount: 5,
                                      in: context, defaults: defaults)
        let row = try #require(try context.fetch(FetchDescriptor<SearchHistoryEntry>()).first)
        let signature = try #require(row.scopeSignature)
        #expect(signature.hasPrefix("route=semantic;engine=on-device;docs="),
                "the trail row must sign the set; it signed \(signature)")
        #expect(signature == SearchScopeSignature.semanticSignature(
            for: SearchParameters(documentIds: SemanticSetFixture.documentSet)))
        _ = container
    }

    @Test("The live set's size is nil with no set, zero for an empty one, and the count otherwise")
    func documentSetSizeFollowsTheGate() async throws {
        let directory = try makeSetDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, service) = try await makeBackend(in: directory)
        let viewModel = SearchViewModel(searchService: service)
        #expect(viewModel.documentSetSize == nil)
        viewModel.appliedWorkingCorpusKeys = []
        #expect(viewModel.documentSetSize == 0)
        viewModel.appliedWorkingCorpusKeys = ["v/d1", "v/d2", "v/d3"]
        #expect(viewModel.documentSetSize == 3)
        viewModel.clearWorkingCorpus()
        #expect(viewModel.documentSetSize == nil)
    }
}

// MARK: - The record, the copy and the wiring

/// What a Meaning search inside a document set records and says (#1577 lane 1).
@Suite("Meaning search inside a document set: the record and the copy")
struct SemanticSetRecordAndCopyTests {

    private static let enUS = Locale(identifier: "en_US")

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `text` with every run of whitespace removed, so a scan matches a call however it is wrapped.
    private static func squeezed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    // MARK: The signature

    @Test("With no set the Meaning signature is the route signature, byte for byte")
    func ungatedSignatureIsUnchanged() {
        #expect(SearchScopeSignature.semanticSignature(for: SearchParameters(keywords: "q"))
                == SearchScopeSignature.semanticRouteSignature)
        #expect(SearchScopeSignature.semanticRouteSignature == "route=semantic;engine=on-device")
    }

    @Test("Inside a set the signature names the set, whatever order its keys came in")
    func gatedSignatureNamesTheSet() throws {
        let one = SearchScopeSignature.semanticSignature(
            for: SearchParameters(documentIds: ["v1/d1", "v2/d7"]))
        let permuted = SearchScopeSignature.semanticSignature(
            for: SearchParameters(documentIds: ["v2/d7", "v1/d1"]))
        let other = SearchScopeSignature.semanticSignature(
            for: SearchParameters(documentIds: ["v1/d1", "v2/d8"]))

        let shape = #/route=semantic;engine=on-device;docs=2/[0-9a-f]{12}/#
        #expect(one.wholeMatch(of: shape) != nil, "unexpected signature: \(one)")
        #expect(one == permuted, "member order carries no scope meaning")
        #expect(one != other, "two different sets of one size must not sign alike")
        #expect(SearchScopeSignature.semanticSignature(for: SearchParameters(documentIds: []))
                == "route=semantic;engine=on-device;docs=empty")
    }

    /// The set's part is the keyword grammar's own, so one set signs the same way on both routes.
    @Test("The set is signed as a keyword search signs it")
    func setIsSignedAsTheKeywordGrammarSignsIt() throws {
        let parameters = SearchParameters(keywords: "q", documentIds: ["v1/d1", "v2/d7"])
        let keyword = SearchScopeSignature.signature(for: parameters)
        let part = try #require(keyword.split(separator: ";").first { $0.hasPrefix("docs=") })
        #expect(SearchScopeSignature.semanticSignature(for: parameters).hasSuffix(";\(part)"))
    }

    @Test("The appendix says a Meaning search ran inside a set, and how large")
    func describeNamesTheSet() throws {
        let ungated = try #require(SearchScopeSignature.describe(SearchScopeSignature.semanticRouteSignature))
        #expect(ungated.count == 1, "a corpus-wide Meaning row reads as it always has")

        let gated = try #require(SearchScopeSignature.describe(
            SearchScopeSignature.semanticSignature(for: SearchParameters(documentIds: ["v1/d1", "v2/d7"]))))
        #expect(gated.count == 2)
        #expect(gated[0] == ungated[0], "the method sentence is the same one")
        #expect(gated[1].contains("2 documents"))
        #expect(gated[1].contains("inside"))

        let empty = try #require(SearchScopeSignature.describe(
            SearchScopeSignature.semanticSignature(for: SearchParameters(documentIds: []))))
        #expect(empty.count == 2)
        #expect(empty[1].contains("no documents"))
    }

    @Test("A Meaning search inside a set that found nothing is never read as a term's absence")
    func gatedZeroIsNotATermAbsence() {
        let gatedZero = SearchHistoryEntry(
            queryText: "why did the talks fail", resultCount: 0,
            executedAt: Date(timeIntervalSince1970: 20),
            loadedCount: 0, matchCount: nil, fetchLimit: 100, indexedVolumeCount: 12,
            scopeSignature: SearchScopeSignature.semanticSignature(
                for: SearchParameters(documentIds: ["v1/d1", "v2/d7"])))
        let appendix = QueryMethodAppendix.make(
            searches: [gatedZero], corpusNames: [:], projectName: nil, researchQuestion: nil,
            generatedAt: Date(timeIntervalSince1970: 1_000))
        #expect(appendix.keywordZeroResultRowCount == 0)
        #expect(appendix.semanticRowCount == 1)
        #expect(!appendix.markdown.contains("the term is absent"))
        #expect(appendix.markdown.contains("2 documents"), "the appendix names the set's size")
    }

    /// `submittedSearchParameters` freezes the query text and reads the rest live, for a Meaning
    /// row as for a keyword row, so the set signed is the one applied when the row is recorded,
    /// which is in the same turn as the run's completion.
    @Test("Both view models sign a Meaning run with the set in the parameters they record")
    func bothViewModelsSignTheSet() throws {
        let call = Self.squeezed("""
            signatureOverride: lastRunWasSemantic
                ? SearchScopeSignature.semanticSignature(for: submittedSearchParameters) : nil
            """)
        for path in ["FRUSExplorer/Search/SearchViewModel.swift", "FRUSExplorer/App/MacSearchViewModel.swift"] {
            #expect(Self.squeezed(try Self.source(path)).contains(call),
                    "\(path) must sign a Meaning run through semanticSignature(for:)")
        }
    }

    // MARK: The strip

    private static func disclosure(
        unscored: Int = 0, volumes: Int = 0, downloading: Int = 0,
        rankedWithin: Int? = nil, withoutVector: Int = 0, filteredOut: Int = 0,
        notIndexedHere: Int = 0
    ) -> SemanticSearchBackend.Disclosure {
        SemanticSearchBackend.Disclosure(
            unscoredCandidates: unscored, unscoredVolumes: volumes, downloadingVolumes: downloading,
            filtersApplied: filteredOut > 0, filteredOut: filteredOut,
            beyondUncheckedByFilters: false,
            rankedWithin: rankedWithin, withoutVector: withoutVector,
            notIndexedHere: notIndexedHere)
    }

    @Test("The strip says where the ranking ran: the whole series, or the set and its size")
    @MainActor
    func stripSaysWhereTheRankingRan() {
        let series = SemanticModeStrip.caption(disclosure: nil, beyondCount: 0, locale: Self.enUS)
        #expect(series.contains("across the whole series"))

        let pending = SemanticModeStrip.caption(
            disclosure: nil, beyondCount: 0, pendingSetSize: 212, locale: Self.enUS)
        #expect(pending.contains("inside the 212 documents you are searching within"))
        #expect(!pending.contains("across the whole series"))

        let one = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 1), beyondCount: 0, locale: Self.enUS)
        #expect(one.contains("inside the 1 document you are searching within"))

        let grouped = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 1_204), beyondCount: 0, locale: Self.enUS)
        #expect(grouped.contains("inside the 1,204 documents you are searching within"))

        let none = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 0), beyondCount: 0, locale: Self.enUS)
        #expect(none.contains("holds no documents"))
        #expect(!none.contains("0 documents"))
    }

    /// A run's own record outranks the live set: rows ranked across the series stay described so
    /// after a corpus is applied, until the next run, and the other way round.
    @Test("Once a run has rows, the strip describes that run and not the set applied since")
    @MainActor
    func stripDescribesTheRunThatProducedTheRows() {
        let seriesRun = SemanticModeStrip.caption(
            disclosure: Self.disclosure(), beyondCount: 0, pendingSetSize: 212, locale: Self.enUS)
        #expect(seriesRun.contains("across the whole series"))
        #expect(!seriesRun.contains("212"))

        let setRun = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 40), beyondCount: 0, pendingSetSize: nil,
            locale: Self.enUS)
        #expect(setRun.contains("inside the 40 documents"))
    }

    @Test("Inside a set the strip counts the members with no vector, in the singular at one")
    @MainActor
    func stripCountsMembersWithoutAVector() {
        let clean = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 40), beyondCount: 0, locale: Self.enUS)
        #expect(!clean.contains("cannot be ranked"))

        let one = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 40, withoutVector: 1), beyondCount: 0,
            locale: Self.enUS)
        #expect(one.contains("1 document in the set has no match data and cannot be ranked."))

        let many = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 4_000, withoutVector: 1_015), beyondCount: 0,
            locale: Self.enUS)
        #expect(many.contains("1,015 documents in the set have no match data and cannot be ranked."))
    }

    @Test("The strip counts close matches the index does not hold, in either kind of search")
    @MainActor
    func stripCountsMatchesTheIndexLacks() {
        let none = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 40), beyondCount: 0, locale: Self.enUS)
        #expect(!none.contains("not listed"))

        let one = SemanticModeStrip.caption(
            disclosure: Self.disclosure(notIndexedHere: 1), beyondCount: 0, locale: Self.enUS)
        #expect(one.contains("1 close match is not listed: this device's index does not hold that document."))

        let many = SemanticModeStrip.caption(
            disclosure: Self.disclosure(rankedWithin: 4_000, notIndexedHere: 1_047),
            beyondCount: 0, locale: Self.enUS)
        #expect(many.contains(
            "1,047 close matches are not listed: this device's index does not hold those documents."))
    }

    /// The same counts, worded for the run they describe. Inside a set the files wanted are for the
    /// reader's own volumes, so the sentence names Download Missing Vectors; across the series it
    /// keeps the #1527 sentence, which names Download Vectors for Every Volume.
    @Test("The unranked sentence names Download Missing Vectors inside a set, and only there")
    @MainActor
    func unrankedSentenceNamesTheRightControl() {
        let inSet = SemanticModeStrip.caption(
            disclosure: Self.disclosure(unscored: 12, volumes: 3, rankedWithin: 40),
            beyondCount: 0, locale: Self.enUS)
        #expect(inSet.contains("12 documents in 3 volumes could not be ranked"))
        #expect(inSet.contains("Download Missing Vectors"))
        #expect(!inSet.contains("Download Vectors for Every Volume"))
        #expect(!inSet.contains("possible match"))

        let series = SemanticModeStrip.caption(
            disclosure: Self.disclosure(unscored: 12, volumes: 3), beyondCount: 0, locale: Self.enUS)
        #expect(series.contains("12 possible matches in 3 volumes"))
        #expect(series.contains("Download Vectors for Every Volume"))
        #expect(!series.contains("Download Missing Vectors"))
    }

    @Test("Inside a set the strip says downloading only when every unranked volume is")
    @MainActor
    func unrankedSentenceClaimsADownloadOnlyWhenTrue() {
        let some = SemanticUnscoredCopy.unranked(members: 12, volumes: 3, downloading: 2, locale: Self.enUS)
        #expect(!some.contains("downloading"))
        let all = SemanticUnscoredCopy.unranked(members: 12, volumes: 3, downloading: 3, locale: Self.enUS)
        #expect(all == "12 documents in 3 volumes could not be ranked yet; their match files are downloading.")
        let single = SemanticUnscoredCopy.unranked(members: 1, volumes: 1, downloading: 1, locale: Self.enUS)
        #expect(single.hasPrefix("1 document in 1 volume "))
    }

    // MARK: The empty state

    /// One cause of an empty list inside a set, and words its sentence must hold.
    struct EmptyCase: Sendable, CustomTestStringConvertible {
        let name: String
        let setSize: Int
        let ranked: Int
        var filteredOut = 0
        let volumes: Int
        let downloading: Int
        let expected: String
        var testDescription: String { name }
    }

    /// One fixture per branch of `SemanticUnscoredCopy.emptyInsideSet`. The two "ranked" fixtures
    /// differ in the filtered count alone, and both carry unranked volumes, which must not win.
    /// The fixtures that rank nothing carry a filtered count, which must not win either.
    static let emptyCases: [EmptyCase] = [
        EmptyCase(name: "the set is empty on this device",
                  setSize: 0, ranked: 0, filteredOut: 4, volumes: 0, downloading: 0,
                  expected: "holds no documents"),
        EmptyCase(name: "members were ranked and the other filters removed some",
                  setSize: 40, ranked: 12, filteredOut: 1, volumes: 3, downloading: 0,
                  expected: "passes your other filters"),
        EmptyCase(name: "members were ranked, no filter removed any, and none is indexed here",
                  setSize: 40, ranked: 12, volumes: 3, downloading: 0,
                  expected: "is indexed on this device"),
        EmptyCase(name: "no member has a vector",
                  setSize: 40, ranked: 0, filteredOut: 4, volumes: 0, downloading: 0,
                  expected: "the app has no match data for them"),
        EmptyCase(name: "every missing match file is downloading",
                  setSize: 40, ranked: 0, volumes: 3, downloading: 3, expected: "still downloading"),
        EmptyCase(name: "match files are missing and not all are downloading",
                  setSize: 40, ranked: 0, filteredOut: 4, volumes: 3, downloading: 2,
                  expected: "Download Missing Vectors"),
    ]

    @Test("The empty state inside a set names what became of the set", arguments: emptyCases)
    func emptyStateInsideASet(_ fixture: EmptyCase) {
        let text = SemanticUnscoredCopy.emptyInsideSet(
            setSize: fixture.setSize, ranked: fixture.ranked, filteredOut: fixture.filteredOut,
            volumes: fixture.volumes, downloading: fixture.downloading, locale: Self.enUS)
        #expect(text.contains(fixture.expected), "\(fixture.name) read: \(text)")
        #expect(!text.contains("scorable corpus"),
                "an empty list inside a set never means nothing was close")
        // Each sentence is its branch's own: no other fixture's words appear in it.
        for other in Self.emptyCases where other.expected != fixture.expected {
            #expect(!text.contains(other.expected), "\(fixture.name) also read as \(other.name): \(text)")
        }
    }

    @Test("The empty state reads the set's sentence for a run inside a set, and the old one otherwise")
    @MainActor
    func emptyStateFollowsTheRun() {
        #expect(SemanticMeaningEmptyState.emptyStatement(disclosure: nil, locale: Self.enUS)
                .contains("scorable corpus"))
        #expect(SemanticMeaningEmptyState.emptyStatement(
            disclosure: Self.disclosure(), locale: Self.enUS).contains("scorable corpus"))
        #expect(SemanticMeaningEmptyState.emptyStatement(
            disclosure: Self.disclosure(unscored: 5, volumes: 2), locale: Self.enUS)
            .contains("Download Vectors for Every Volume"))

        // Forty in the set, thirty with no vector, ten without their file: none ranked, and the
        // files are what can be fetched.
        let missingFiles = SemanticMeaningEmptyState.emptyStatement(
            disclosure: Self.disclosure(unscored: 10, volumes: 2, rankedWithin: 40, withoutVector: 30),
            locale: Self.enUS)
        #expect(missingFiles.contains("match files for 2 volumes are not on this device"))

        // Forty in the set, five with no vector, the rest ranked: the list is empty because the
        // other filters removed the closest of them. Where no filter removed any, the app does
        // not blame one.
        let filtered = SemanticMeaningEmptyState.emptyStatement(
            disclosure: Self.disclosure(rankedWithin: 40, withoutVector: 5, filteredOut: 35),
            locale: Self.enUS)
        #expect(filtered.contains("passes your other filters"))
        let unfiltered = SemanticMeaningEmptyState.emptyStatement(
            disclosure: Self.disclosure(rankedWithin: 40, withoutVector: 5, notIndexedHere: 35),
            locale: Self.enUS)
        #expect(!unfiltered.contains("filters"))
        #expect(unfiltered.contains("is indexed on this device"))
    }

    // MARK: The prompt

    @Test("The pre-search prompt names the set in Meaning mode, and stands aside otherwise")
    func promptNamesTheSet() {
        #expect(SearchMode.keywords.documentSetPrompt(size: 212) == nil,
                "the keyword prompt is left as it was")
        #expect(SearchMode.meaning.documentSetPrompt(size: nil) == nil)
        let prompt = SearchMode.meaning.documentSetPrompt(size: 212)
        #expect(prompt?.contains("212 documents you are searching within") == true)
        #expect(SearchMode.meaning.documentSetPrompt(size: 1)?.contains("1 document you") == true)
        #expect(SearchMode.meaning.documentSetPrompt(size: 0)?.contains("holds no documents") == true)
    }

    // MARK: The wiring

    @Test("Both hosts hand the strip the live set's size, and the iPhone prompt reads it first")
    func hostsPassTheLiveSet() throws {
        let iOS = Self.squeezed(try Self.source("FRUSExplorer/Search/SearchView.swift"))
        let mac = Self.squeezed(try Self.source("FRUSExplorer/App/SearchSheet.swift"))
        #expect(iOS.contains(Self.squeezed("""
            SemanticModeStrip(disclosure: vm.semanticDisclosure,
                              beyondCount: vm.beyondLibraryHits.count,
                              pendingSetSize: vm.documentSetSize)
            """)))
        #expect(mac.contains(Self.squeezed("""
            SemanticModeStrip(disclosure: searchVM.semanticDisclosure,
                              beyondCount: searchVM.beyondLibraryHits.count,
                              pendingSetSize: searchVM.documentSetSize)
            """)))
        #expect(iOS.contains(Self.squeezed("""
            Text(vm.searchMode.documentSetPrompt(size: vm.documentSetSize)
                 ?? vm.searchMode.initialPrompt(scoped: !vm.effectiveVolumeIds.isEmpty))
            """)))
    }

    /// The strip's live size and the engine's set are read from one value on each platform: the
    /// parameters the Meaning run is handed. Were the run given other parameters, the strip would
    /// name a set the search does not rank inside.
    @Test("Each view model hands the engine the parameters whose set the strip counts")
    func engineIsHandedTheParametersTheStripCounts() throws {
        let iOS = Self.squeezed(try Self.source("FRUSExplorer/Search/SearchViewModel.swift"))
        let mac = Self.squeezed(try Self.source("FRUSExplorer/App/MacSearchViewModel.swift"))
        #expect(iOS.contains(Self.squeezed(
            "let outcome = try await backend.run(query: submittedQuery, parameters: searchParameters)")))
        #expect(iOS.contains(Self.squeezed(
            "var documentSetSize: Int? { searchParameters.documentIds?.count }")))
        #expect(mac.contains(Self.squeezed(
            "let outcome = try await backend.run(query: query, parameters: parameters)")))
        #expect(mac.contains(Self.squeezed(
            "var documentSetSize: Int? { parameters.documentIds?.count }")))
    }

    /// Two places clear a search's rows without running one: the emptied field on iPhone and
    /// iPad, and a rebuilt index on the Mac. Each must clear the Meaning disclosure with the
    /// rows, or the strip goes on describing a run whose rows are gone. Matched on the handler's
    /// own block, from its condition to the statement.
    @Test("Where rows are cleared without a run, the last Meaning run's disclosure goes with them")
    func clearedRowsTakeTheDisclosureWithThem() throws {
        let iOS = try Self.source("FRUSExplorer/Search/SearchView.swift")
        let handler = try #require(iOS.range(of: ".onChange(of: vm.keywords) { _, newValue in"))
        let afterHandler = iOS[handler.upperBound...]
        let block = try #require(afterHandler.range(of: "if newValue.isEmpty {"))
        let blockEnd = try #require(afterHandler[block.upperBound...].range(of: "\n                    }\n"))
        let body = afterHandler[block.upperBound..<blockEnd.lowerBound]
        #expect(body.contains("vm.results    = []"), "precondition: this is the block that clears the rows")
        #expect(body.contains("vm.semanticDisclosure = nil"))

        let mac = try Self.source("FRUSExplorer/App/SearchSheet.swift")
        let rebuilt = try #require(mac.range(of: ".onChange(of: appState.indexGeneration) { _, _ in"))
        let afterRebuilt = mac[rebuilt.upperBound...]
        let rebuiltEnd = try #require(afterRebuilt.range(of: "\n        }\n"))
        let rebuiltBody = afterRebuilt[..<rebuiltEnd.lowerBound]
        #expect(rebuiltBody.contains("searchVM.results = []"), "precondition: this is the block that clears the rows")
        #expect(rebuiltBody.contains("searchVM.semanticDisclosure = nil"))
    }

    // MARK: The timing lines

    @Test("The Meaning line carries the set's counts and four stage times, in milliseconds")
    func meaningLine() {
        let line = SearchTimingLog.line(SearchTimingLog.MeaningInSet(
            setSize: 1_000, withVector: 987, volumes: 14, ranked: 950,
            encode: .microseconds(412_340), resolve: .microseconds(1_210),
            shards: .milliseconds(38), score: .microseconds(940)))
        #expect(line == "meaning-in-set docs=1000 vectors=987 volumes=14 ranked=950"
                + " encode_ms=412.3 resolve_ms=1.2 shards_ms=38.0 score_ms=0.9")
    }

    @Test("The keyword line carries the set's size, the rows, and the two waits")
    func keywordLine() {
        let line = SearchTimingLog.line(SearchTimingLog.GatedKeyword(
            setSize: 100, rowCount: 37, rows: .microseconds(812_500), total: .seconds(2)))
        #expect(line == "gated-keyword docs=100 rows=37 rows_ms=812.5 total_ms=2000.0")
    }

    /// Matched on the call inside the condition, not on a window of text: each view model records
    /// the keyword line where the executed parameters carry a set, and nowhere else.
    @Test("Both view models time a keyword search only where it ran inside a set")
    func bothViewModelsTimeAGatedKeywordSearch() throws {
        let iOS = Self.squeezed(try Self.source("FRUSExplorer/Search/SearchViewModel.swift"))
        let mac = Self.squeezed(try Self.source("FRUSExplorer/App/MacSearchViewModel.swift"))
        #expect(iOS.contains(Self.squeezed("""
            if let documentSet = params.documentIds {
                SearchTimingLog.record(SearchTimingLog.GatedKeyword(
                    setSize: documentSet.count, rowCount: results.count,
                    rows: rowsTime, total: clock.now - sent))
            }
            """)))
        #expect(mac.contains(Self.squeezed("""
            if let documentSet = frozenParams.documentIds {
                SearchTimingLog.record(SearchTimingLog.GatedKeyword(
                    setSize: documentSet.count, rowCount: fetched.count,
                    rows: rowsTime, total: clock.now - sent))
            }
            """)))
        for source in [iOS, mac] {
            #expect(source.components(separatedBy: "SearchTimingLog.record(").count == 2,
                    "one timing call in each view model")
        }
    }

    /// The Meaning line is written on the path that scored something, with the stage times that
    /// path took. Matched on the call and its arguments.
    @Test("The searcher writes the Meaning line from the stages it timed")
    func searcherWritesTheMeaningLine() throws {
        let searcher = Self.squeezed(try Self.source("FRUSExplorer/Semantic/SemanticQuerySearcher.swift"))
        #expect(searcher.contains(Self.squeezed("""
            SearchTimingLog.record(SearchTimingLog.MeaningInSet(
                setSize: distinct.count,
                withVector: members.count,
                volumes: volumesAsked,
                ranked: ranked.count,
                encode: encodeTime,
                resolve: resolveTime,
                shards: shardTime,
                score: scoreTime))
            """)))
        #expect(searcher.components(separatedBy: "SearchTimingLog.record(").count == 2)
    }
}
