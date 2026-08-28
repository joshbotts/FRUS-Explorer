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

/// Records the volumes the searcher queues for fetch.
private actor FetchCollector {
    var volumeIDs: [String] = []
    func record(_ volumeID: String) { volumeIDs.append(volumeID) }
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
            queueShardFetch: { volumeID in
                Task { await collector.record(volumeID) }
            },
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

    @Test("Missing-shard volumes are queued bounded and once, the Related-axis warm-up rule")
    func missingVolumesQueuedOnce() async throws {
        let vector = try SearcherFixtures.fixtureVector(forQueryContaining: "Anglo-Venezuelan")
        let collector = FetchCollector()
        let searcher = try await makeSearcher(
            adopting: ["frus1895p1"], collector: collector,
            embed: { _ in vector })

        _ = try await searcher.search("q")
        try await Task.sleep(for: .milliseconds(100))
        let first = await collector.volumeIDs
        #expect(!first.isEmpty, "a nearly-empty store must queue warm-up fetches")
        #expect(Set(first).count == first.count, "no volume queued twice in one search")

        _ = try await searcher.search("q")
        try await Task.sleep(for: .milliseconds(100))
        let second = await collector.volumeIDs
        #expect(second.count == first.count,
                "the same misses must not re-queue on the next search")
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
            queueShardFetch: { _ in })

        await #expect(throws: SemanticQuerySearcher.SearchUnavailable.modelNotDownloaded) {
            _ = try await searcher.search("anything")
        }
    }
}
