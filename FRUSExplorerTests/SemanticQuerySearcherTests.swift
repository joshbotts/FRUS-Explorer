// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// Where the searcher tests find their inputs: the committed query-vector fixture (so no 229 MB
/// model is needed — the embed step is injected) and the gitignored local shards (so the suite
/// self-skips on a checkout that has not regenerated them, the shard-fetcher tests' rule).
private enum SearcherFixtures {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    static func shardURL(_ volumeID: String) -> URL {
        repoRoot.appendingPathComponent("Planning/semantic-vectors/shards/\(volumeID).vec")
    }

    static var shardsPresent: Bool {
        FileManager.default.fileExists(atPath: shardURL("frus1895p1").path)
            && FileManager.default.fileExists(atPath: shardURL("frus1951-54IranEd2").path)
    }

    /// The committed reference vectors from `make_query_parity_fixture.py`, by query text.
    static func fixtureVector(forQueryContaining needle: String) throws -> [Double] {
        struct Fixture: Decodable {
            struct Row: Decodable { let text: String; let vector: [Double] }
            let queries: [Row]
        }
        let data = try Data(contentsOf: repoRoot
            .appendingPathComponent("FRUSExplorerTests/Fixtures/query-parity-fixture.json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        guard let row = fixture.queries.first(where: { $0.text.contains(needle) }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return row.vector
    }
}

/// Records the volumes the searcher asks to fetch, and answers each request as `AppState` would:
/// `accepts` says whether a download starts (#1527 review round 1: a declined ask is the switch
/// off, offline, or a fetch that failed).
private actor FetchCollector {
    var volumeIDs: [String] = []
    var accepts: Bool
    init(accepts: Bool = true) { self.accepts = accepts }
    func record(_ volumeID: String) -> Bool {
        volumeIDs.append(volumeID)
        return accepts
    }
    func setAccepts(_ value: Bool) { accepts = value }
}

/// The typed-query searcher (V-5 s3), driven through the injected embed seam with the committed
/// fixture vectors — the funnel, the drop-and-queue rule, and the twin fold, against the real
/// bundled corpus and real packer shards. The encoder half has its own gated acceptance suite;
/// injecting fixture vectors here tests everything DOWNSTREAM of it deterministically.
@Suite("Semantic query searcher", .enabled(if: SearcherFixtures.shardsPresent))
struct SemanticQuerySearcherTests {

    /// A searcher over a temp store holding exactly the given volumes' real shards.
    @MainActor
    private func makeSearcher(
        adopting volumeIDs: [String],
        collector: FetchCollector,
        embed: @escaping @Sendable (String) async throws -> [Double]
    ) async throws -> SemanticQuerySearcher {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let corpus = try #require(BundledSemanticVectors.corpusVectors)

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("searcher-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let shardStore = SemanticShardStore(
            directory: directory,
            provenance: index.provenance,
            expectedCounts: Dictionary(
                index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first }))
        for volumeID in volumeIDs {
            try await shardStore.adoptShard(
                from: SearcherFixtures.shardURL(volumeID), for: volumeID)
        }
        let modelStore = SemanticModelStore(
            directory: directory.appendingPathComponent("model"),
            expectedSHA256: index.provenance.modelFileSHA256)
        return SemanticQuerySearcher(
            index: index,
            corpus: corpus,
            modelStore: modelStore,
            shardStore: shardStore,
            requestShardFetch: { volumeID in await collector.record(volumeID) },
            embedOverride: embed)
    }

    @Test("The sitting's known-item transfers: the Olney query's hits land in frus1895p1")
    func olneyQueryFindsItsVolume() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let collector = FetchCollector()
        let searcher = try await makeSearcher(
            adopting: ["frus1895p1"], collector: collector,
            embed: { _ in vector })

        let results = try await searcher.search("Which document related to the Anglo-Venezuelan boundary dispute expanded the Monroe Doctrine?")

        // Only frus1895p1's shard is on "disk", so every scored hit is that volume's — and the
        // sitting's finding (the Olney correspondence at the top for this query) means the
        // volume MUST produce hits at all: an empty list here is a funnel regression.
        #expect(!results.hits.isEmpty)
        #expect(results.hits.allSatisfy { $0.volumeID == "frus1895p1" })
        let scores = results.hits.map(\.score)
        #expect(scores == scores.sorted(by: >), "hits arrive best-first")
        // The 800-candidate pool reaches far beyond the one shard held; the drop must be
        // disclosed, never silent.
        #expect(results.unscoredCandidates > 0)
        #expect(results.unscoredVolumes > 0)
    }

    /// The warm-up rule: missing-shard volumes are asked for, bounded to the top of the order and
    /// once per search, and asked for again on the next search — since #1527's review round 1,
    /// because the answer can change between searches (the switch turned on, a reconnect, a
    /// failure). The fetcher de-duplicates a fetch already running, so asking again costs nothing.
    /// The asks are awaited, so no sleep stands between a search and what it asked.
    @Test("Missing-shard volumes are asked for bounded, once per search, and again on the next")
    func missingVolumesAskedEachSearch() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let collector = FetchCollector()
        let searcher = try await makeSearcher(
            adopting: ["frus1895p1"], collector: collector,
            embed: { _ in vector })

        _ = try await searcher.search("q")
        let first = await collector.volumeIDs
        #expect(!first.isEmpty, "a nearly-empty store must ask for warm-up fetches")
        #expect(Set(first).count == first.count, "no volume asked for twice in one search")

        _ = try await searcher.search("q")
        let both = await collector.volumeIDs
        #expect(Array(both.dropFirst(first.count)) == first,
                "the next search must ask for the same misses again, in the same order")
    }

    /// #1527: the result counts the unscored volumes with a download under way, and that is not
    /// all of them. The pool is 800 but only the top 100 of the order are asked for, so with one
    /// shard held some unscored volumes are never asked for — the case in which "their match files
    /// are downloading" was false even with Download With Volumes on.
    @Test("The result counts the unscored volumes whose fetch started, fewer than all of them (#1527)")
    func downloadingVolumesAreTheStartedSubset() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let collector = FetchCollector(accepts: true)
        let searcher = try await makeSearcher(
            adopting: ["frus1895p1"], collector: collector,
            embed: { _ in vector })

        let first = try await searcher.search("q")
        let asked = Set(await collector.volumeIDs)
        #expect(first.downloadingVolumes == asked.count, """
            downloadingVolumes (\(first.downloadingVolumes)) must be the volumes whose fetch started \
            (\(asked.count))
            """)
        #expect(first.downloadingVolumes > 0)
        #expect(first.downloadingVolumes < first.unscoredVolumes, """
            every unscored volume was asked for (\(first.downloadingVolumes) of \
            \(first.unscoredVolumes)): the fixture no longer reaches past the fetch depth, so this \
            test no longer shows the case
            """)
    }

    /// #1527, review round 1: an ask the app declined — Download With Volumes off, offline, or a
    /// fetch that already failed — is not a download, and it is asked again once the answer can
    /// change. The first build recorded every ask for the searcher's lifetime and never asked
    /// again, so after the reader turned the switch on (as the caption now tells them to) every
    /// earlier-declined volume counted as downloading while nothing downloaded.
    @Test("A declined fetch counts as nothing, and is asked again and counted once it starts (#1527)")
    func declinedAsksAreAskedAgain() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let collector = FetchCollector(accepts: false)
        let searcher = try await makeSearcher(
            adopting: ["frus1895p1"], collector: collector,
            embed: { _ in vector })

        let declined = try await searcher.search("q")
        let asked = Set(await collector.volumeIDs)
        #expect(!asked.isEmpty, "precondition: the search asked for fetches")
        #expect(declined.downloadingVolumes == 0,
                "every ask was declined, yet \(declined.downloadingVolumes) volume(s) count as downloading")

        await collector.setAccepts(true)
        let accepted = try await searcher.search("q")
        let askedAgain = await collector.volumeIDs.count - asked.count
        #expect(askedAgain == asked.count, "the declined volumes were asked again \(askedAgain) time(s), not \(asked.count)")
        #expect(accepted.downloadingVolumes == asked.count, """
            once the app starts the fetches, the \(asked.count) volumes count as downloading; \
            the result said \(accepted.downloadingVolumes)
            """)

        // And declined again (a failure, or the switch back off): nothing downloads.
        await collector.setAccepts(false)
        let again = try await searcher.search("q")
        #expect(again.downloadingVolumes == 0,
                "a volume counted as downloading after its fetch was declined: \(again.downloadingVolumes)")
    }

    /// #1527, review round 1: the Meaning mode's disclosure carries the searcher's own count, run
    /// through `SemanticSearchBackend.run` itself. The first build gated an ask count on the switch
    /// read at caption time, and no test reached that line.
    @Test("The Meaning backend discloses the searcher's downloading count (#1527)")
    @MainActor
    func backendDisclosesTheDownloadingCount() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("backend-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        for accepts in [false, true] {
            let collector = FetchCollector(accepts: accepts)
            let searcher = try await makeSearcher(
                adopting: ["frus1895p1"], collector: collector,
                embed: { _ in vector })
            let backend = SemanticSearchBackend(
                searcher: searcher, searchService: service,
                manifestStore: ManifestStore(bundledEntries: []),
                indexedVolumeIds: { [] })
            let outcome = try await backend.run(query: "q", parameters: SearchParameters())
            let asked = Set(await collector.volumeIDs)
            #expect(outcome.disclosure.unscoredVolumes > asked.count,
                    "precondition: some unscored volumes rank below the fetch depth")
            #expect(outcome.disclosure.downloadingVolumes == (accepts ? asked.count : 0), """
                with every fetch \(accepts ? "started" : "declined"), the disclosure counts \
                \(outcome.disclosure.downloadingVolumes) downloading of \(asked.count) asked
                """)
        }
    }

    @Test("Edition twins fold: with both Iran editions held, no document appears twice")
    func editionTwinsFold() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Deposing shah")
        let collector = FetchCollector()
        let searcher = try await makeSearcher(
            adopting: ["frus1951-54Iran", "frus1951-54IranEd2"], collector: collector,
            embed: { _ in vector })

        let results = try await searcher.search("Deposing shah")
        #expect(!results.hits.isEmpty)
        // The two editions carry the same documents at identical vectors, so an unfolded list
        // would pair every hit with its twin in the adjacent slot. The fold must leave each
        // printed document exactly once.
        let foldKeys = results.hits.map {
            SemanticEditionTwins.foldKey(volumeID: $0.volumeID, documentID: $0.documentID)
        }
        #expect(Set(foldKeys).count == foldKeys.count,
                "an edition twin survived the fold — the same document is listed twice")
    }

    @Test("No model and no embed override: the searcher names the download, not a failure")
    func modelAbsentThrowsTheOfferCue() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(await MainActor.run(body: { BundledSemanticVectors.index }))
        let corpus = try #require(await MainActor.run(body: { BundledSemanticVectors.corpusVectors }))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("searcher-nomodel-\(UUID().uuidString)", isDirectory: true)
        let searcher = SemanticQuerySearcher(
            index: index, corpus: corpus,
            modelStore: SemanticModelStore(directory: directory, expectedSHA256: "00"),
            shardStore: SemanticShardStore(
                directory: directory, provenance: index.provenance, expectedCounts: [:]),
            requestShardFetch: { _ in false })

        await #expect(throws: SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded) {
            _ = try await searcher.search("anything")
        }
    }
}

/// The request loop behind `SemanticQuerySearcher.Results.downloadingVolumes`, driven without the
/// shard fixtures the searcher suite needs, so a clean checkout exercises #1527's rule too.
@Suite("Semantic query searcher — fetch requests")
struct SemanticFetchRequestTests {

    /// Only a request answered `true` is a download; each volume is asked once, in a stable order.
    @Test("Only the volumes whose fetch started count, each asked once in order (#1527)")
    func onlyStartedFetchesCount() async {
        let collector = FetchCollector()
        let started: Set<String> = ["frus1950v02", "frus1861"]
        let downloading = await SemanticQuerySearcher.requestFetches(
            for: ["frus1950v02", "frus1861", "frus1969-76v01"],
            using: { volumeID in
                _ = await collector.record(volumeID)
                return started.contains(volumeID)
            })
        #expect(downloading == started, "the declined frus1969-76v01 was counted: \(downloading.sorted())")
        #expect(await collector.volumeIDs == ["frus1861", "frus1950v02", "frus1969-76v01"])
    }
}
