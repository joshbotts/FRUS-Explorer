// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit and FTS5Store as modules of their own; Xcode compiles them
// into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - SemanticSimilarityHostTests

/// Related Documents' semantic axis and Project Home's reach as a host calls them (FRUS Explorer Light's
/// S26a): ``SemanticVectorsSimilaritySource`` and ``SemanticProjectReach/reach(seedKeys:weights:host:)``
/// over a ``SemanticSimilarityHost`` of the suite's own — the real bundled tiers, shards it writes for
/// three of the bundled index's volumes (``SyntheticShardFolder``), an index the kit's pipeline builds of
/// one of them, and a log of the shards the passes ask the host for.
///
/// `SemanticAxisTests` drives the same re-score over the packer's own shards, in Xcode, where they are
/// on disk; the repository ignores them, so this suite is the passes' end to end everywhere else,
/// Linux among them. The three volumes are the web edition's fixtures: `frus1894Nicaragua`, 138
/// documents, which is held and indexed; `frus1969-76ve09p1`, 128, which is not; and `frus1961-63v06`,
/// 120, which is held but whose shard is never written.
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
@Suite("FRUSCoreKit — the semantic axis over a host's tiers and shards")
@MainActor
struct SemanticSimilarityHostTests {

    /// Held, indexed and given a shard.
    static let anchorVolume = "frus1894Nicaragua"
    /// Given a shard, never held.
    static let candidateVolume = "frus1969-76ve09p1"
    /// Held, and never given a shard.
    static let absentVolume = "frus1961-63v06"

    private static func key(_ volumeID: String, _ documentID: String) -> DocumentKey {
        DocumentKey(volumeId: volumeID, documentId: documentID)
    }

    /// A host over the bundled tiers and `shards`, holding `indexed`, that logs what it is asked for.
    private static func host(
        index: SemanticVectorIndex?, corpus: SemanticCorpusVectors?, shards: SyntheticShardFolder?,
        indexed: Set<String>, pipeline: IndexingPipeline? = nil, log: ShardRequestLog
    ) -> SemanticSimilarityHost {
        SemanticSimilarityHost(
            index: index, corpusVectors: corpus, shardStore: shards,
            indexedVolumeIds: indexed, indexingPipeline: pipeline,
            requestShard: { log.record($0) })
    }

    /// The anchor volume indexed by the kit's pipeline, as a TEI file of its documents by the bundled
    /// index's ids, each a numbered head and a line of text.
    private static func withAnchorVolumeIndexed<T>(
        _ index: SemanticVectorIndex, _ body: (IndexingPipeline) async throws -> T
    ) async throws -> T {
        let ids = try #require(index.documentIDs(forVolume: anchorVolume))
        let documents = ids.enumerated().map { offset, id in
            """
                <div type="document" xml:id="\(id)" n="\(offset + 1)">
                  <head>\(offset + 1). Despatch \(id)</head><p>The canal question, again.</p></div>
            """
        }.joined(separator: "\n")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(anchorVolume)</title></titleStmt>
              <publicationStmt><date>1895</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
            \(documents)
              </body></text>
            </TEI>
            """
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSemanticHost-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(anchorVolume).xml"))
        let database = dir.appendingPathComponent("index.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database), databaseURL: database,
                                            volumesDirectory: volumes, resources: .none,
                                            defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(anchorVolume)
        return try await body(pipeline)
    }

    /// The calibrated cosine of `anchor` against `candidate`, read straight from the shards.
    private static func expectedScore(
        _ anchor: DocumentKey, _ candidate: DocumentKey, index: SemanticVectorIndex, shards: SyntheticShardFolder
    ) async throws -> Double {
        let anchorEntry = try #require(index.volume(anchor.volumeId))
        let anchorRow = try #require(index.row(documentID: anchor.documentId, volumeID: anchor.volumeId))
        let query = try #require(await shards.shard(for: anchor.volumeId)?.vector(at: anchorRow - anchorEntry.rowOffset))
        let entry = try #require(index.volume(candidate.volumeId))
        let row = try #require(index.row(documentID: candidate.documentId, volumeID: candidate.volumeId))
        let shard = try #require(await shards.shard(for: candidate.volumeId))
        let cosine = try #require(shard.cosine(row: row - entry.rowOffset, query: query.codes, queryScale: query.scale))
        return index.file.retrieval.calibratedDocumentScore(cosine)
    }

    // MARK: - The generation

    @Test("Without the anchor's own shard the generation offers nothing and asks for the anchor's volume")
    func theGenerationNeedsTheAnchorsShard() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        let log = ShardRequestLog()
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))
        try await Self.withAnchorVolumeIndexed(index) { pipeline in
            let source = SemanticVectorsSimilaritySource(host: Self.host(
                index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume],
                pipeline: pipeline, log: log))
            let pool = try await source.candidates(for: anchor, anchorYear: nil, limit: 30, scopeVolumeIds: nil)
            #expect(pool.candidates.isEmpty)
            #expect(log.volumes == [Self.anchorVolume], """
                The anchor's shard is the query vector, so its absence is the one a host is asked to mend: \
                asked for \(log.volumes).
                """)
        }
    }

    @Test("The generation scores what the host holds, by the shards' own cosines, and asks once for each volume it lacks")
    func theGenerationScoresWhatTheHostHolds() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.anchorVolume], index: index, corpus: corpus)
        let log = ShardRequestLog()
        let ids = try #require(index.documentIDs(forVolume: Self.anchorVolume))
        let anchor = Self.key(Self.anchorVolume, ids[0])
        try await Self.withAnchorVolumeIndexed(index) { pipeline in
            // The absent volume is held, so its rows are candidates; the host has no shard for it.
            let source = SemanticVectorsSimilaritySource(host: Self.host(
                index: index, corpus: corpus, shards: shards,
                indexed: [Self.anchorVolume, Self.absentVolume], pipeline: pipeline, log: log))
            let pool = try await source.candidates(for: anchor, anchorYear: nil, limit: 30, scopeVolumeIds: nil)

            // The two held volumes hold 258 rows, under the rerank pool of 800, so every one is a
            // candidate: the anchor's volume's 137 others are scored, and the 30 best kept.
            #expect(pool.candidates.count == 30)
            #expect(pool.availableTotal == nil)
            #expect(pool.candidates.allSatisfy { $0.key.volumeId == Self.anchorVolume && $0.key != anchor })
            for candidate in pool.candidates {
                let expected = try await Self.expectedScore(anchor, candidate.key, index: index, shards: shards)
                #expect(candidate.strength == expected, "\(candidate.key.compositeString)")
                #expect(candidate.evidenceLabel == SemanticSimilarityGenerator.evidenceLabel(for: candidate.strength))
                #expect(candidate.record.header.hasSuffix("Despatch \(candidate.key.documentId)"))
            }
            let strengths = pool.candidates.map(\.strength)
            #expect(strengths == strengths.sorted(by: >), "the pool is the shards' order, best first")
            // The 30 kept are the best of the 137: nothing left out scores above the last one kept.
            let kept = Set(pool.candidates.map(\.key))
            let weakestKept = try #require(strengths.last)
            for id in ids.dropFirst() where !kept.contains(Self.key(Self.anchorVolume, id)) {
                let left = try await Self.expectedScore(anchor, Self.key(Self.anchorVolume, id), index: index, shards: shards)
                #expect(left <= weakestKept, "\(id) scored \(left), above the cut at \(weakestKept)")
            }
            #expect(log.volumes == [Self.absentVolume], """
                The generation asks for each candidate volume whose shard is missing, once, after it has \
                scored the rest: asked for \(log.volumes).
                """)
        }
    }

    @Test("The generation keeps to the held volumes inside the caller's scope")
    func theGenerationKeepsToTheScope() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.anchorVolume, Self.candidateVolume], index: index, corpus: corpus)
        let log = ShardRequestLog()
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))
        try await Self.withAnchorVolumeIndexed(index) { pipeline in
            let source = SemanticVectorsSimilaritySource(host: Self.host(
                index: index, corpus: corpus, shards: shards,
                indexed: [Self.anchorVolume, Self.absentVolume], pipeline: pipeline, log: log))
            // A scope of the absent volume alone: its rows are the only candidates, and none can be
            // scored. The candidate volume has a shard but is not held, so it is never a candidate.
            let scoped = try await source.candidates(
                for: anchor, anchorYear: nil, limit: 30, scopeVolumeIds: [Self.absentVolume, Self.candidateVolume])
            #expect(scoped.candidates.isEmpty)
            #expect(log.volumes == [Self.absentVolume])
            #expect(!(await shards.asked).contains(Self.candidateVolume), """
                A volume the host does not hold must not be read: the fence is applied inside the scan.
                """)
        }
    }

    // MARK: - The re-score

    @Test("The re-score admits exactly the candidates at or above the floor, each at its own cosine, and asks for nothing")
    func theReScoreAdmitsWhatClearsTheFloor() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.anchorVolume, Self.candidateVolume], index: index, corpus: corpus)
        let log = ShardRequestLog()
        let source = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume], log: log))
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))
        let candidates = Set(try #require(index.documentIDs(forVolume: Self.candidateVolume))
            .prefix(60).map { Self.key(Self.candidateVolume, $0) })

        let all = await source.reScore(anchor: anchor, candidates: candidates, floor: -1.1)
        try #require(all.count == candidates.count, "every candidate's shard is written, so every one must score")
        for (key, score) in all {
            let expected = try await Self.expectedScore(anchor, key, index: index, shards: shards)
            #expect(score == expected, "\(key.compositeString)")
        }
        let sorted = all.values.sorted()
        let floor = sorted[sorted.count / 2]
        let expected = all.filter { $0.value >= floor }
        try #require(!expected.isEmpty && expected.count < all.count)
        let kept = await source.reScore(anchor: anchor, candidates: candidates, floor: floor)
        #expect(Set(kept.keys) == Set(expected.keys))
        #expect(kept.allSatisfy { all[$0.key] == $0.value })
        #expect(log.volumes.isEmpty, "the re-score must ask the host for nothing: asked for \(log.volumes)")
    }

    @Test("The anchor scores 1.0 against itself and nothing else in its volume does")
    func theAnchorIsItsOwnNearestNeighbour() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.anchorVolume], index: index, corpus: corpus)
        let source = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume], log: ShardRequestLog()))
        let ids = try #require(index.documentIDs(forVolume: Self.anchorVolume))
        // Local row 0, which makes a query or candidate row read from the wrong place land on another
        // document rather than on the same one.
        let anchor = Self.key(Self.anchorVolume, ids[0])
        let scored = await source.reScore(
            anchor: anchor, candidates: Set(ids.map { Self.key(Self.anchorVolume, $0) }), floor: -1.1)
        #expect(scored.count == ids.count)
        let own = try #require(scored[anchor])
        #expect(own > 0.999, "the anchor scored \(own) against itself")
        #expect(scored.filter { $0.key != anchor }.values.allSatisfy { $0 < 0.999 })
    }

    @Test("A candidate whose shard the host lacks is a silent miss, read once a volume")
    func anAbsentShardIsASilentMiss() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.anchorVolume, Self.candidateVolume], index: index, corpus: corpus)
        let log = ShardRequestLog()
        let source = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume], log: log))
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))
        let held = Set(try #require(index.documentIDs(forVolume: Self.candidateVolume))
            .prefix(20).map { Self.key(Self.candidateVolume, $0) })
        let absent = Set(try #require(index.documentIDs(forVolume: Self.absentVolume))
            .prefix(20).map { Self.key(Self.absentVolume, $0) })

        let scored = await source.reScore(anchor: anchor, candidates: held.union(absent), floor: -1.1)
        #expect(Set(scored.keys) == held)
        #expect(log.volumes.isEmpty)
        // Twenty candidates in a volume without a shard ask for it once: a missing shard is remembered
        // across the loop, where a dictionary of optionals would forget it (the pass's own note).
        #expect((await shards.asked).filter { $0 == Self.absentVolume }.count == 1)
    }

    @Test("Without the anchor's shard, or without a store, the re-score scores nothing")
    func noQueryVectorMeansNoReScore() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        try await shards.write([Self.candidateVolume], index: index, corpus: corpus)
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))
        let candidates = Set(try #require(index.documentIDs(forVolume: Self.candidateVolume))
            .prefix(20).map { Self.key(Self.candidateVolume, $0) })
        let withoutAnchor = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume], log: ShardRequestLog()))
        #expect(await withoutAnchor.reScore(anchor: anchor, candidates: candidates, floor: -1.1).isEmpty)
        let withoutStore = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: nil, indexed: [Self.anchorVolume], log: ShardRequestLog()))
        #expect(await withoutStore.reScore(anchor: anchor, candidates: candidates, floor: -1.1).isEmpty)
    }

    // MARK: - Beyond the library

    @Test("The off-index section counts volumes from the sign bits alone, and names documents only where both shards are held")
    func theOffIndexSectionsTwoChannels() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let shards = try SyntheticShardFolder(index: index)
        let log = ShardRequestLog()
        let source = SemanticVectorsSimilaritySource(host: Self.host(
            index: index, corpus: corpus, shards: shards, indexed: [Self.anchorVolume], log: log))
        let anchor = Self.key(Self.anchorVolume, try #require(index.documentIDs(forVolume: Self.anchorVolume)?.first))

        // No shard at all: the volume channel still answers.
        let volumesOnly = await source.offIndexSection(for: anchor, limit: 120, scopeVolumeIds: nil)
        #expect(volumesOnly.documentCount > 0)
        #expect(!volumesOnly.volumes.isEmpty)
        #expect(volumesOnly.volumes.allSatisfy { $0.volumeID != Self.anchorVolume })
        #expect(volumesOnly.volumes.reduce(0) { $0 + $1.count } == volumesOnly.documentCount)
        #expect(volumesOnly.documents.isEmpty)

        // The anchor's shard and the first lead volume's: the documents named are that volume's, best
        // first, at most five, each at its calibrated cosine.
        let leadVolume = try #require(volumesOnly.volumes.first?.volumeID)
        try await shards.write([Self.anchorVolume, leadVolume], index: index, corpus: corpus)
        let named = await source.offIndexSection(for: anchor, limit: 120, scopeVolumeIds: nil)
        #expect(named.documentCount == volumesOnly.documentCount)
        #expect(named.volumes == volumesOnly.volumes)
        #expect(!named.documents.isEmpty && named.documents.count <= SemanticSimilarityGenerator.offIndexDocumentLimit)
        #expect(named.documents.allSatisfy { $0.volumeID == leadVolume })
        #expect(named.documents.map(\.score) == named.documents.map(\.score).sorted(by: >))
        for lead in named.documents {
            let expected = try await Self.expectedScore(
                anchor, Self.key(lead.volumeID, lead.documentID), index: index, shards: shards)
            #expect(lead.score == expected, "\(lead.id)")
        }
        #expect(log.volumes.isEmpty, "the off-index scan must ask the host for nothing: asked for \(log.volumes)")
    }

    // MARK: - Project Home's reach

    @Test("The reach looks past the held volumes alone, from the sign bits, and asks for nothing")
    func theReachLooksPastTheLibrary() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let log = ShardRequestLog()
        let host = Self.host(index: index, corpus: corpus, shards: nil, indexed: [Self.anchorVolume], log: log)
        let seeds = try #require(index.documentIDs(forVolume: Self.anchorVolume))
            .prefix(10).map { "\(Self.anchorVolume)/\($0)" }

        let reach = await SemanticProjectReach.reach(seedKeys: Array(seeds), weights: .default, host: host)
        #expect(!reach.isEmpty)
        #expect(reach.seedsProbed == 10)
        #expect(reach.volumes.count <= SemanticProjectReach.volumeLimit)
        #expect(reach.volumes.allSatisfy { $0.volumeID != Self.anchorVolume })
        #expect(reach.volumes == SemanticProjectReach.rank(reach.volumes), "the finding is in the reach's order")
        #expect(log.volumes.isEmpty)
    }

    @Test("The reach is off at zero weight, and empty without the tiers")
    func theReachsGates() async throws {
        let (index, corpus) = try BundledTiersFixture.tiers()
        let seeds = try #require(index.documentIDs(forVolume: Self.anchorVolume))
            .prefix(10).map { "\(Self.anchorVolume)/\($0)" }
        var zero = AxisWeights.default
        zero[.semanticSimilarity] = 0
        let held = Self.host(index: index, corpus: corpus, shards: nil, indexed: [Self.anchorVolume], log: ShardRequestLog())
        #expect(await SemanticProjectReach.reach(seedKeys: Array(seeds), weights: zero, host: held) == .none)
        let unloaded = Self.host(index: nil, corpus: nil, shards: nil, indexed: [Self.anchorVolume], log: ShardRequestLog())
        #expect(await SemanticProjectReach.reach(seedKeys: Array(seeds), weights: .default, host: unloaded) == .none)
    }
}
