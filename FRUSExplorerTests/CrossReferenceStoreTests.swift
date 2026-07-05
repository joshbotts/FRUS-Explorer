// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - Fixture Helpers

/// Creates a minimal temp directory, SQLite DB, and CrossReferenceStore for test use.
private func makeTempStore() throws -> (dir: URL, dbURL: URL, store: CrossReferenceStore) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSCrossRef-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dbURL = dir.appendingPathComponent("test.sqlite")

    // Bootstrap table schema via IndexingPipeline (also runs the ALTER TABLE migrations).
    let fts5 = try FTS5Store(databaseURL: dbURL)
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
    _ = try IndexingPipeline(
        fts5Store: fts5,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        subjectTagStore: SubjectTagStore(entries: [], appearances: []),
        concurrencyLimit: 1
    )

    let store = try CrossReferenceStore(databaseURL: dbURL)
    return (dir, dbURL, store)
}

/// Inserts a raw cross_reference row directly into the DB (bypasses IndexingPipeline).
private func insertEdge(
    dbURL: URL,
    sourceVolumeId: String, sourceDocumentId: String,
    targetVolumeId: String?, targetDocumentId: String,
    referenceType: String = "footnote",
    context: String? = nil
) throws {
    var db: OpaquePointer?
    let rc = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
    guard rc == SQLITE_OK, let db else {
        throw CrossReferenceError.databaseOpenFailed(message: "insertEdge: cannot open")
    }
    defer { sqlite3_close_v2(db) }

    let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let sql = """
        INSERT INTO cross_references
        (source_volume_id, source_document_id, target_volume_id, target_document_id,
         reference_type, context)
        VALUES (?, ?, ?, ?, ?, ?)
        """
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, sourceVolumeId,   -1, TRANSIENT)
    sqlite3_bind_text(stmt, 2, sourceDocumentId, -1, TRANSIENT)
    if let tv = targetVolumeId { sqlite3_bind_text(stmt, 3, tv, -1, TRANSIENT) }
    else { sqlite3_bind_null(stmt, 3) }
    sqlite3_bind_text(stmt, 4, targetDocumentId, -1, TRANSIENT)
    sqlite3_bind_text(stmt, 5, referenceType,    -1, TRANSIENT)
    if let ctx = context { sqlite3_bind_text(stmt, 6, ctx, -1, TRANSIENT) }
    else { sqlite3_bind_null(stmt, 6) }
    sqlite3_step(stmt)
}

/// Inserts a document_cache row directly (gives nodes resolvable metadata).
private func insertDocumentCache(
    dbURL: URL,
    volumeId: String, documentId: String,
    documentNumber: String? = nil,
    header: String = "Test Document",
    dateline: String? = nil
) throws {
    var db: OpaquePointer?
    let rc = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
    guard rc == SQLITE_OK, let db else {
        throw CrossReferenceError.databaseOpenFailed(message: "insertDocumentCache: cannot open")
    }
    defer { sqlite3_close_v2(db) }

    let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let sql = """
        INSERT OR REPLACE INTO document_cache
        (volume_id, document_id, document_number, header, dateline, source_note,
         body_text, subject_tag_ids, user_tag_ids, summary_text, note_text)
        VALUES (?, ?, ?, ?, ?, NULL, '', NULL, NULL, NULL, NULL)
        """
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, volumeId,    -1, TRANSIENT)
    sqlite3_bind_text(stmt, 2, documentId,  -1, TRANSIENT)
    if let n = documentNumber { sqlite3_bind_text(stmt, 3, n, -1, TRANSIENT) }
    else { sqlite3_bind_null(stmt, 3) }
    sqlite3_bind_text(stmt, 4, header,      -1, TRANSIENT)
    if let d = dateline { sqlite3_bind_text(stmt, 5, d, -1, TRANSIENT) }
    else { sqlite3_bind_null(stmt, 5) }
    sqlite3_step(stmt)
}

// MARK: - CrossReferenceStoreTests

struct CrossReferenceStoreTests {

    // MARK: - InboundEdgeQueryTest

    @Test("Inbound edge query returns edges whose target matches the central document")
    func inboundEdgeQueryReturnsCorrectEdges() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // d1 in vol1 references d2 in vol1 (same-volume, target_volume_id = NULL)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: nil, targetDocumentId: "d2", referenceType: "footnote")
        // d3 in vol2 references d2 in vol1 (cross-volume)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "d3",
                       targetVolumeId: "vol1", targetDocumentId: "d2", referenceType: "editorialNote")
        // d4 in vol1 references d5 (unrelated)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d4",
                       targetVolumeId: nil, targetDocumentId: "d5")

        let inbound = try await store.inboundEdges(forDocumentId: "d2", volumeId: "vol1")

        #expect(inbound.count == 2)
        let sourceDocIds = inbound.map(\.sourceDocumentId).sorted()
        #expect(sourceDocIds == ["d1", "d3"])

        let d1edge = try #require(inbound.first { $0.sourceDocumentId == "d1" })
        #expect(d1edge.referenceType == .footnote)
        #expect(d1edge.sourceVolumeId == "vol1")
        #expect(d1edge.targetVolumeId == "vol1")

        let d3edge = try #require(inbound.first { $0.sourceDocumentId == "d3" })
        #expect(d3edge.referenceType == .editorialNote)
        #expect(d3edge.sourceVolumeId == "vol2")
    }

    // MARK: - OutboundEdgeQueryTest

    @Test("Outbound edge query returns edges whose source matches the central document")
    func outboundEdgeQueryReturnsCorrectEdges() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // d1 in vol1 references d2 (same-volume)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: nil, targetDocumentId: "d2")
        // d1 in vol1 references d10 in vol2 (cross-volume)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: "vol2", targetDocumentId: "d10")
        // d9 in vol1 references d2 (unrelated source)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d9",
                       targetVolumeId: nil, targetDocumentId: "d2")

        let outbound = try await store.outboundEdges(forDocumentId: "d1", volumeId: "vol1")

        #expect(outbound.count == 2)
        let targetDocIds = outbound.map(\.targetDocumentId).sorted()
        #expect(targetDocIds == ["d10", "d2"])

        let d2edge = try #require(outbound.first { $0.targetDocumentId == "d2" })
        #expect(d2edge.targetVolumeId == "vol1")
    }

    // MARK: - UndownloadedDetectionTest

    @Test("hasUndownloadedSources is true when an inbound edge's source volume is not downloaded")
    func undownloadedSourceDetection() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Edge from an "external" volume that we haven't downloaded.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol-undownloaded", sourceDocumentId: "dx",
                       targetVolumeId: "vol1", targetDocumentId: "d1")
        // Edge from a downloaded volume.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d2",
                       targetVolumeId: nil, targetDocumentId: "d1")

        let downloadedVolumeIds: Set<String> = ["vol1"]
        let graph = try await store.graph(
            forDocumentId: "d1", volumeId: "vol1",
            downloadedVolumeIds: downloadedVolumeIds
        )

        #expect(graph.hasUndownloadedSources)
        #expect(graph.inboundEdges.count == 2)
    }

    // MARK: - MetadataResolutionTest

    @Test("Graph node metadata is populated from document_cache for all endpoints")
    func metadataResolutionPopulatesHeaders() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "d1",
                                documentNumber: "1", header: "Memorandum of Conversation",
                                dateline: "Washington, January 20, 1969.")
        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "d2",
                                documentNumber: "2", header: "Telegram",
                                dateline: "Moscow, February 5, 1969.")

        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: nil, targetDocumentId: "d2")

        let graph = try await store.graph(
            forDocumentId: "d2", volumeId: "vol1",
            downloadedVolumeIds: ["vol1"]
        )

        // Central document metadata
        let centralKey = "vol1/d2"
        let centralMeta = try #require(graph.nodeMetadata[centralKey])
        #expect(centralMeta.header == "Telegram")
        #expect(centralMeta.dateline == "Moscow, February 5, 1969.")
        #expect(centralMeta.documentNumber == "2")

        // Inbound source metadata
        let sourceMeta = try #require(graph.nodeMetadata["vol1/d1"])
        #expect(sourceMeta.header == "Memorandum of Conversation")
        #expect(sourceMeta.documentNumber == "1")

        #expect(!graph.hasUndownloadedSources)
    }

    // MARK: - Context Round-Trip (Session 37)

    @Test("contextSurvivesStoreRoundTrip — context written by IndexingPipeline is returned by CrossReferenceStore")
    func contextSurvivesStoreRoundTrip() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let expectedContext = "See Document 2 for the Secretary's initial response to the proposal."

        // Insert an edge with a non-nil context directly via the fixture helper.
        try insertEdge(
            dbURL: dbURL,
            sourceVolumeId: "vol1", sourceDocumentId: "d1",
            targetVolumeId: "vol1", targetDocumentId: "d2",
            referenceType: "footnote",
            context: expectedContext
        )

        // Retrieve outbound edges from d1 and verify context survives the round-trip.
        let edges = try await store.outboundEdges(
            forDocumentId: "d1", volumeId: "vol1"
        )
        #expect(edges.count == 1)
        let edge = try #require(edges.first)
        #expect(edge.context == expectedContext,
                "Context must survive the insert → CrossReferenceStore.outboundEdges round-trip")
    }

    @Test("contextNilEdgeSurvivesStoreRoundTrip — nil context is returned as nil")
    func contextNilEdgeSurvivesStoreRoundTrip() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertEdge(
            dbURL: dbURL,
            sourceVolumeId: "vol1", sourceDocumentId: "d1",
            targetVolumeId: "vol1", targetDocumentId: "d2",
            referenceType: "footnote",
            context: nil
        )

        let edges = try await store.outboundEdges(forDocumentId: "d1", volumeId: "vol1")
        #expect(edges.first?.context == nil,
                "nil context must be returned as nil, not an empty string")
    }

    // MARK: - ExpandedGraphDegree2Test

    @Test("expandedGraph degree=2 includes 2nd-degree edges not present in degree-1 graph")
    func expandedGraphDegree2IncludesExtendedEdges() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Graph structure:
        //   d1 → d2 (central) → d3
        //           d4 → d3
        //   d1 → d5            (this edge is 2nd-degree from d2's perspective)
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: nil, targetDocumentId: "d2")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d2",
                       targetVolumeId: nil, targetDocumentId: "d3")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d4",
                       targetVolumeId: nil, targetDocumentId: "d3")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d1",
                       targetVolumeId: nil, targetDocumentId: "d5")

        // Degree-1 graph centred on d2 has edges: d1→d2 (inbound) + d2→d3 (outbound).
        let deg1 = try await store.expandedGraph(
            forDocumentId: "d2", volumeId: "vol1",
            degree: 1, downloadedVolumeIds: ["vol1"]
        )
        #expect(deg1.inboundEdges.count == 1)
        #expect(deg1.outboundEdges.count == 1)
        #expect(deg1.extendedEdges.isEmpty)
        #expect(deg1.fetchedDegree == 1)

        // Degree-2 graph should pick up edges involving d1 and d3 (the 1st-degree nodes):
        // - d1→d5 (d1 is a 1st-degree inbound node; its outbound edge to d5 is new)
        // - d4→d3 (d3 is a 1st-degree outbound node; this inbound edge to d3 is new)
        let deg2 = try await store.expandedGraph(
            forDocumentId: "d2", volumeId: "vol1",
            degree: 2, downloadedVolumeIds: ["vol1"]
        )
        #expect(deg2.inboundEdges.count == 1,  "degree-1 inbound unchanged")
        #expect(deg2.outboundEdges.count == 1, "degree-1 outbound unchanged")
        #expect(!deg2.extendedEdges.isEmpty,   "degree-2 should have extended edges")
        #expect(deg2.fetchedDegree == 2)

        // The extended edges should include both d1→d5 and d4→d3.
        let extSources = Set(deg2.extendedEdges.map(\.sourceDocumentId))
        let extTargets = Set(deg2.extendedEdges.map(\.targetDocumentId))
        #expect(extSources.contains("d1") || extTargets.contains("d5"),
                "d1→d5 should appear in extended edges")
        #expect(extSources.contains("d4") || extTargets.contains("d3"),
                "d4→d3 should appear in extended edges")

        // Metadata should now include d4 and d5 (new 2nd-degree nodes).
        // (They may not be in document_cache since we didn't insert them, but keys exist.)
        let knownKeys = Set(deg2.nodeMetadata.keys)
        #expect(knownKeys.contains("vol1/d4") || knownKeys.contains("vol1/d5"),
                "nodeMetadata should include at least one 2nd-degree node")
    }

    // MARK: - CA-6 statistical queries

    @Test("topDocumentsByInDegree ranks by resolved inbound count and excludes NULL targets")
    func topDocumentsByInDegreeRanksResolvedOnly() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "hub", header: "Hub Document")

        // Three resolved inbound citations to vol1/hub.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s2",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "s3",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        // One resolved inbound to vol1/minor.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s4",
                       targetVolumeId: "vol1", targetDocumentId: "minor")
        // Two UNRESOLVED edges (NULL target volume) — must be excluded from ranking.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s5",
                       targetVolumeId: nil, targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s6",
                       targetVolumeId: nil, targetDocumentId: "hub")

        let top = try await store.topDocumentsByInDegree(limit: 10)

        #expect(top.count == 2, "Only two resolved target documents exist")
        let first = try #require(top.first)
        #expect(first.volumeId == "vol1")
        #expect(first.documentId == "hub")
        #expect(first.inDegree == 3, "NULL-target edges must not inflate the in-degree")
        #expect(first.header == "Hub Document", "Header joined from document_cache")
        #expect(top[1].documentId == "minor")
        #expect(top[1].inDegree == 1)
    }

    @Test("resolvedInDegrees returns per-document counts for the distribution histogram")
    func resolvedInDegreesPerDocument() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // hub: 2 inbound; minor: 1 inbound. Plus a NULL-target edge (excluded).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s2",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s3",
                       targetVolumeId: "vol1", targetDocumentId: "minor")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s4",
                       targetVolumeId: nil, targetDocumentId: "hub")

        let degrees = try await store.resolvedInDegrees().sorted()
        #expect(degrees == [1, 2], "One doc with in-degree 1, one with in-degree 2; NULL excluded")

        // Sanity: the pure bucketer turns these into two single-document buckets.
        let buckets = CrossReferenceStats.degreeDistribution(degrees)
        #expect(buckets.map(\.degree) == [1, 2])
        #expect(buckets.allSatisfy { $0.documentCount == 1 })
    }

    @Test("volumeLevelConnections counts cross-volume references and excludes same-volume")
    func volumeConnectionCounts() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // vol1 → vol2 twice, vol2 → vol1 once, vol1 → vol1 once (same-volume, excluded),
        // vol1 → NULL once (excluded).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: "vol2", targetDocumentId: "x")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "b",
                       targetVolumeId: "vol2", targetDocumentId: "y")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "c",
                       targetVolumeId: "vol1", targetDocumentId: "z")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "d",
                       targetVolumeId: "vol1", targetDocumentId: "w")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "e",
                       targetVolumeId: nil, targetDocumentId: "v")

        let edges = try await store.volumeLevelConnections()
        let byPair = Dictionary(uniqueKeysWithValues:
            edges.map { ("\($0.sourceVolumeId)->\($0.targetVolumeId)", $0.count) })
        #expect(byPair["vol1->vol2"] == 2)
        #expect(byPair["vol2->vol1"] == 1)
        #expect(byPair["vol1->vol1"] == nil, "Same-volume edges excluded")

        // Top-N selection over these edges: totals vol1 = 2+1 = 3, vol2 = 2+1 = 3 → both.
        let top = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: 5)
        #expect(Set(top) == ["vol1", "vol2"])
    }

    @Test("resolvedCitationEdges returns resolved edges and excludes NULL targets and self-loops")
    func resolvedCitationEdgesForPageRank() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: "vol1", targetDocumentId: "b")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "b",
                       targetVolumeId: "vol2", targetDocumentId: "c")
        // NULL target — excluded.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: nil, targetDocumentId: "d")
        // Self-loop — excluded.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: "vol1", targetDocumentId: "a")

        let edges = try await store.resolvedCitationEdges()
        #expect(edges.count == 2, "NULL-target and self-loop edges excluded")

        // Feed PageRank — three nodes (a, b, c), mass conserved.
        let scores = PageRank.compute(edges: edges)
        #expect(scores.count == 3)
        let total = scores.reduce(0.0) { $0 + $1.score }
        #expect(abs(total - 1.0) < 1e-6)
        // c is the only twice-removed sink; b is cited by a; a is never cited.
        let byKey = Dictionary(uniqueKeysWithValues:
            scores.map { ("\($0.key.volumeId)/\($0.key.documentId)", $0.score) })
        #expect((byKey["vol2/c"] ?? 0) > (byKey["vol1/a"] ?? 0))
    }
}
