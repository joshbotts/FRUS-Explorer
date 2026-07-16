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

/// Inserts a `document_dates` row so an edge's SOURCE (or target) document has a date for the
/// year-range filter. Pass `dateISO: nil` to exercise the undated-drop path.
private func insertDocumentDate(
    dbURL: URL,
    volumeId: String, documentId: String,
    dateISO: String?
) throws {
    var db: OpaquePointer?
    let rc = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
    guard rc == SQLITE_OK, let db else {
        throw CrossReferenceError.databaseOpenFailed(message: "insertDocumentDate: cannot open")
    }
    defer { sqlite3_close_v2(db) }

    let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let sql = """
        INSERT OR REPLACE INTO document_dates
        (volume_id, document_id, date_iso, date_iso_max, date_precision, date_certainty)
        VALUES (?, ?, ?, NULL, NULL, NULL)
        """
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, volumeId,   -1, TRANSIENT)
    sqlite3_bind_text(stmt, 2, documentId, -1, TRANSIENT)
    if let d = dateISO { sqlite3_bind_text(stmt, 3, d, -1, TRANSIENT) } else { sqlite3_bind_null(stmt, 3) }
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

    @Test("topDocumentsByInDegree counts same-volume references, attributed to the source volume")
    func topDocumentsByInDegreeCountsSameVolume() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "hub", header: "Hub Document")

        // Two cross-volume inbound citations to vol1/hub.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s2",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        // One SAME-VOLUME inbound citation to hub (NULL target volume, source = vol1). This is
        // how the parser stores a bare `#hub` fragment and a resolved page reference — it must
        // now be attributed to (vol1, hub) and count toward hub's in-degree (#188-B).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "s3",
                       targetVolumeId: nil, targetDocumentId: "hub")
        // One cross-volume inbound to vol1/minor.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s4",
                       targetVolumeId: "vol1", targetDocumentId: "minor")

        let top = try await store.topDocumentsByInDegree(limit: 10)

        #expect(top.count == 2, "Two distinct target documents: vol1/hub and vol1/minor")
        let first = try #require(top.first)
        #expect(first.volumeId == "vol1")
        #expect(first.documentId == "hub")
        #expect(first.inDegree == 3, "2 cross-volume + 1 same-volume citation all count")
        #expect(first.header == "Hub Document", "Header joined from document_cache")
        #expect(top[1].documentId == "minor")
        #expect(top[1].inDegree == 1)
    }

    @Test("Non-document anchors (page, footnote, index, chapter) are excluded from every degree/edge query (#209)")
    func nonDocumentAnchorsExcludedFromDegreeQueries() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Real document targets d1 (2 inbound) and d2 (1 inbound) in vol1.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1",
                       targetVolumeId: "vol1", targetDocumentId: "d1")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s2",
                       targetVolumeId: "vol1", targetDocumentId: "d1")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s3",
                       targetVolumeId: "vol1", targetDocumentId: "d2")
        // Non-document anchors that ALSO live in target_document_id and used to be crowned as
        // "landmark documents": a roman-numeral page (pg_III), a front-matter fragment (pg_fm12),
        // a footnote (d197fn2 — shares the d-prefix), a back-of-book index item (in5), and a
        // chapter anchor (ch3). Each is the SOLE target of its source, so the source also drops out.
        let anchors = ["pg_III", "pg_fm12", "d197fn2", "in5", "ch3"]
        for (i, anchor) in anchors.enumerated() {
            try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "sa\(i)",
                           targetVolumeId: "vol1", targetDocumentId: anchor)
        }

        // (a) In-degree ranking includes only real documents — no page, footnote, index, or
        // chapter anchors.
        let top = try await store.topDocumentsByInDegree(limit: 10)
        #expect(Set(top.map(\.documentId)) == ["d1", "d2"], "Only real documents ranked; no anchors")
        #expect(!top.contains { anchors.contains($0.documentId) })

        // (b) In-degree distribution feeder is filtered identically — so ranking and histogram stay
        // lockstep.
        #expect(try await store.resolvedInDegrees().sorted() == [1, 2])

        // (c) Out-degree feeder drops edges TARGETING an anchor (same edge population as in-degree),
        // so the anchor-only sources (sa0…sa4) disappear entirely; only s1,s2,s3 remain.
        let outDeg = try await store.resolvedOutDegrees()
        #expect(outDeg.count == 3, "Only s1,s2,s3 remain; the anchor-only sources drop out")
        #expect(outDeg.allSatisfy { $0 == 1 })

        // (d) PageRank edge set excludes all anchor targets.
        let edges = try await store.resolvedCitationEdges()
        #expect(edges.count == 3, "Only the 3 real document-target edges feed PageRank")
        #expect(!edges.contains { anchors.contains($0.target.documentId) })
    }

    @Test("resolvedInDegrees returns per-document counts, including same-volume references")
    func resolvedInDegreesPerDocument() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // vol1/hub: 2 cross-volume inbound; vol1/minor: 1 cross-volume inbound.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s2",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s3",
                       targetVolumeId: "vol1", targetDocumentId: "minor")
        // A same-volume edge from vol1 → hub (NULL target) is attributed to (vol1, hub),
        // raising hub's in-degree to 3 (#188-B).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "s4",
                       targetVolumeId: nil, targetDocumentId: "hub")

        let degrees = try await store.resolvedInDegrees().sorted()
        #expect(degrees == [1, 3], "minor: 1; hub: 2 cross-volume + 1 same-volume = 3")

        // Sanity: the pure bucketer turns these into two single-document buckets.
        let buckets = CrossReferenceStats.degreeDistribution(degrees)
        #expect(buckets.map(\.degree) == [1, 3])
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

    @Test("resolvedCitationEdges includes same-volume edges (attributed to source) and excludes self-loops")
    func resolvedCitationEdgesForPageRank() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: "vol1", targetDocumentId: "b")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "b",
                       targetVolumeId: "vol2", targetDocumentId: "c")
        // Same-volume edge (NULL target) — attributed to (vol1, d) and now INCLUDED (#188-B).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: nil, targetDocumentId: "d")
        // Self-loop — still excluded (COALESCE resolves target to the source volume + doc).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a",
                       targetVolumeId: "vol1", targetDocumentId: "a")

        let edges = try await store.resolvedCitationEdges()
        #expect(edges.count == 3, "a→b, b→c, and the same-volume a→d; self-loop excluded")
        // The same-volume edge resolves its target volume to the source's own volume.
        #expect(edges.contains { $0.source.volumeId == "vol1" && $0.source.documentId == "a"
                                  && $0.target.volumeId == "vol1" && $0.target.documentId == "d" },
                "same-volume a→d attributed to (vol1, d)")

        // Feed PageRank — four nodes (a, b, c, d), mass conserved.
        let scores = PageRank.compute(edges: edges)
        #expect(scores.count == 4)
        let total = scores.reduce(0.0) { $0 + $1.score }
        #expect(abs(total - 1.0) < 1e-6)
        // c and d are cited; a is never cited.
        let byKey = Dictionary(uniqueKeysWithValues:
            scores.map { ("\($0.key.volumeId)/\($0.key.documentId)", $0.score) })
        #expect((byKey["vol2/c"] ?? 0) > (byKey["vol1/a"] ?? 0))
    }

    // MARK: - CA-6 filter tests (#189-B)

    @Test("CA-6 year-range filter is source-anchored: only edges whose source is dated in range count")
    func yearRangeFilterIsSourceAnchored() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "hub", header: "Hub")
        // Two documents cite vol1/hub: sA (dated 1970, in range) and sB (dated 1985, out of range).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "sA",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "sB",
                       targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "sA", dateISO: "1970-05-01")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol3", documentId: "sB", dateISO: "1985-05-01")

        // Whole corpus (nil): both citations count → hub in-degree 2.
        let all = try await store.topDocumentsByInDegree(limit: 10)
        #expect(all.first(where: { $0.documentId == "hub" })?.inDegree == 2)

        // 1969–1976: only the sA (1970) citation counts → hub in-degree 1.
        let ranged = try await store.topDocumentsByInDegree(limit: 10, yearRange: 1969...1976)
        #expect(ranged.count == 1)
        #expect(ranged.first?.documentId == "hub")
        #expect(ranged.first?.inDegree == 1)

        // Degree distributions + PageRank edges track the SAME source-anchored population.
        #expect(try await store.resolvedInDegrees(yearRange: 1969...1976) == [1])
        #expect(try await store.resolvedOutDegrees(yearRange: 1969...1976) == [1])   // only sA emits
        #expect(try await store.resolvedCitationEdges(yearRange: 1969...1976).count == 1)
        // Unfiltered: hub in-degree 2, two sources each out-degree 1, two edges.
        #expect(try await store.resolvedInDegrees() == [2])
        #expect(try await store.resolvedOutDegrees().sorted() == [1, 1])
        #expect(try await store.resolvedCitationEdges().count == 2)
    }

    @Test("CA-6 year-range filter drops edges whose source document is undated")
    func undatedSourceDroppedUnderYearRange() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // vol2/sU cites vol1/hub, but sU has NO document_dates row.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "sU",
                       targetVolumeId: "vol1", targetDocumentId: "hub")

        // No year filter: the undated-source edge is present.
        #expect(try await store.resolvedCitationEdges().count == 1)
        #expect(try await store.resolvedInDegrees() == [1])

        // With a year filter: the INNER JOIN to document_dates drops the undated source entirely.
        #expect(try await store.resolvedCitationEdges(yearRange: 1900...2000).isEmpty)
        #expect(try await store.resolvedInDegrees(yearRange: 1900...2000).isEmpty)
    }

    @Test("CA-6 volume scope is source-anchored: gates the citing (source) volume, not the target")
    func volumeScopeIsSourceAnchored() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "vol1", documentId: "hub", header: "Hub")
        // vol2/sA cites vol1/hub: source in vol2, target in vol1.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "sA",
                       targetVolumeId: "vol1", targetDocumentId: "hub")

        // Scope to the SOURCE volume (vol2): the edge is KEPT — hub surfaces as a foundational
        // out-of-slice target (it lives in vol1, outside the scope).
        let sourceScoped = try await store.topDocumentsByInDegree(limit: 10, volumeIds: ["vol2"])
        #expect(sourceScoped.first?.documentId == "hub")
        #expect(sourceScoped.first?.inDegree == 1)

        // Scope to the TARGET volume (vol1): the edge is DROPPED — its source (vol2) is out of scope.
        let targetScoped = try await store.topDocumentsByInDegree(limit: 10, volumeIds: ["vol1"])
        #expect(targetScoped.isEmpty)
    }

    @Test("volumeLevelConnections honors the source-date filter and its both-endpoints scope")
    func volumeLevelConnectionsHonorsDateAndScope() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // vol1→vol2 twice (sources a@1970, b@1985), vol2→vol1 once (source c@1970).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a", targetVolumeId: "vol2", targetDocumentId: "x")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "b", targetVolumeId: "vol2", targetDocumentId: "y")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "c", targetVolumeId: "vol1", targetDocumentId: "z")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol1", documentId: "a", dateISO: "1970-01-01")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol1", documentId: "b", dateISO: "1985-01-01")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "c", dateISO: "1970-01-01")

        func pairs(_ edges: [VolumeConnectionEdge]) -> [String: Int] {
            Dictionary(uniqueKeysWithValues: edges.map { ("\($0.sourceVolumeId)->\($0.targetVolumeId)", $0.count) })
        }

        // Unfiltered: vol1->vol2 = 2, vol2->vol1 = 1.
        let all = pairs(try await store.volumeLevelConnections())
        #expect(all["vol1->vol2"] == 2)
        #expect(all["vol2->vol1"] == 1)

        // Year 1969–1976 (source-dated): b@1985 drops → vol1->vol2 = 1, vol2->vol1 = 1.
        let ranged = pairs(try await store.volumeLevelConnections(yearRange: 1969...1976))
        #expect(ranged["vol1->vol2"] == 1)
        #expect(ranged["vol2->vol1"] == 1)

        // Both-endpoints scope to {vol1, vol2}: all three edges qualify (same as unfiltered).
        let scoped = pairs(try await store.volumeLevelConnections(limitToVolumeIds: ["vol1", "vol2"]))
        #expect(scoped["vol1->vol2"] == 2)
        #expect(scoped["vol2->vol1"] == 1)

        // Scope to a single volume {vol1}: both endpoints must be vol1, but these are cross-volume → empty.
        #expect(try await store.volumeLevelConnections(limitToVolumeIds: ["vol1"]).isEmpty)

        // Combined date + scope (exercises the year-then-double-bind offset): 1969–1976 within {vol1,vol2}.
        let combined = pairs(try await store.volumeLevelConnections(limitToVolumeIds: ["vol1", "vol2"], yearRange: 1969...1976))
        #expect(combined["vol1->vol2"] == 1)
        #expect(combined["vol2->vol1"] == 1)
    }

    @Test("topDocumentsByInDegree LIMIT truncates correctly under combined year+volume filters")
    func topDocumentsByInDegreeLimitUnderCombinedFilters() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // In-scope (vol2), in-range sources: hubA cited twice, hubB cited once.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1", targetVolumeId: "vol1", targetDocumentId: "hubA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s2", targetVolumeId: "vol1", targetDocumentId: "hubA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s3", targetVolumeId: "vol1", targetDocumentId: "hubB")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "s1", dateISO: "1970-01-01")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "s2", dateISO: "1971-01-01")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "s3", dateISO: "1972-01-01")

        // LIMIT 1 over TWO qualifying targets, with both filters active (year cols 1-2, scope col 3,
        // LIMIT last): must truncate to the top target hubA (in-degree 2) — proves the LIMIT bind
        // lands at the final column, not colliding with the year/scope binds.
        let top1 = try await store.topDocumentsByInDegree(limit: 1, yearRange: 1969...1976, volumeIds: ["vol2"])
        #expect(top1.count == 1)
        #expect(top1.first?.documentId == "hubA")
        #expect(top1.first?.inDegree == 2)

        // LIMIT 10 returns both, ordered by in-degree descending.
        let top10 = try await store.topDocumentsByInDegree(limit: 10, yearRange: 1969...1976, volumeIds: ["vol2"])
        #expect(top10.map(\.documentId) == ["hubA", "hubB"])
    }

    @Test("Document-level queries AND the year and volume predicates (an edge failing either is dropped)")
    func combinedFilterDropsEdgeFailingEitherPredicate() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Edge A: in-range (1970) but OUT-of-scope source (vol3).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "a", targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol3", documentId: "a", dateISO: "1970-01-01")
        // Edge B: in-scope source (vol2) but OUT-of-range (1985).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "b", targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "b", dateISO: "1985-01-01")

        // scope=vol2 AND year 1969–76: A fails scope, B fails year → nothing survives.
        #expect(try await store.topDocumentsByInDegree(limit: 10, yearRange: 1969...1976, volumeIds: ["vol2"]).isEmpty)
        #expect(try await store.resolvedInDegrees(yearRange: 1969...1976, volumeIds: ["vol2"]).isEmpty)
        #expect(try await store.resolvedCitationEdges(yearRange: 1969...1976, volumeIds: ["vol2"]).isEmpty)

        // Edge C: in-scope AND in-range → the only survivor.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "c", targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertDocumentDate(dbURL: dbURL, volumeId: "vol2", documentId: "c", dateISO: "1972-01-01")
        let survivor = try await store.topDocumentsByInDegree(limit: 10, yearRange: 1969...1976, volumeIds: ["vol2"])
        #expect(survivor.count == 1)
        #expect(survivor.first?.inDegree == 1)
    }

    @Test("resolvedInDegrees and resolvedOutDegrees honor a volume scope with no year range")
    func degreeQueriesHonorVolumeScopeAlone() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Two sources in different volumes cite the same target.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "s1", targetVolumeId: "vol1", targetDocumentId: "hub")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol3", sourceDocumentId: "s2", targetVolumeId: "vol1", targetDocumentId: "hub")

        // Volume scope ALONE (no year): the scope predicate binds at column 1. Only vol2's source counts.
        #expect(try await store.resolvedOutDegrees(volumeIds: ["vol2"]) == [1])
        #expect(try await store.resolvedInDegrees(volumeIds: ["vol2"]) == [1])
        // Unfiltered: two sources each out-degree 1; hub in-degree 2.
        #expect(try await store.resolvedOutDegrees().sorted() == [1, 1])
        #expect(try await store.resolvedInDegrees() == [2])
    }

    // MARK: - Broken-reference exclusion (#240B)

    @Test("Broken edges are excluded from graph, degree, and count queries")
    func brokenEdgesExcluded() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // A live edge and a broken edge sharing the same source document.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "src", targetVolumeId: nil, targetDocumentId: "d5")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "src", targetVolumeId: nil, targetDocumentId: "dX")
        try setBroken(dbURL: dbURL, sourceVolumeId: "vol1", targetDocumentId: "dX")

        // Outbound edges: only the live d5 survives.
        let out = try await store.outboundEdges(forDocumentId: "src", volumeId: "vol1")
        #expect(out.map(\.targetDocumentId) == ["d5"])

        // Inbound to the broken target returns nothing.
        #expect(try await store.inboundEdges(forDocumentId: "dX", volumeId: "vol1").isEmpty)
        // Inbound to the live target still resolves.
        #expect(try await store.inboundEdges(forDocumentId: "d5", volumeId: "vol1").count == 1)

        // edgeCount excludes the broken edge (1 live outbound, not 2).
        #expect(try await store.edgeCount(forDocumentId: "src", volumeId: "vol1") == 1)

        // Degree queries and the disclosure count.
        #expect(try await store.resolvedOutDegrees() == [1])
        #expect(try await store.excludedBrokenCount() == 1)
    }

    @Test("excludedBrokenCount honors the source volume scope")
    func excludedBrokenCountScoped() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol1", sourceDocumentId: "a", targetVolumeId: nil, targetDocumentId: "bad1")
        try setBroken(dbURL: dbURL, sourceVolumeId: "vol1", targetDocumentId: "bad1")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "vol2", sourceDocumentId: "b", targetVolumeId: nil, targetDocumentId: "bad2")
        try setBroken(dbURL: dbURL, sourceVolumeId: "vol2", targetDocumentId: "bad2")

        #expect(try await store.excludedBrokenCount() == 2)
        #expect(try await store.excludedBrokenCount(volumeIds: ["vol1"]) == 1)
    }

    // MARK: - relatedByCitation (#308 Phase 2b find-related generator)

    @Test("relatedByCitation unions both ego directions, ranks by citation multiplicity, filters non-document and unindexed targets")
    func relatedByCitationBasic() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Candidates need a document_cache row (INNER JOIN → indexed/navigable only).
        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dA", header: "Doc A")
        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dB", header: "Doc B")
        // dC deliberately has NO document_cache row.

        // Anchor v1/d0 cites dA twice (multiplicity 2, outbound); dB cites the anchor once (inbound);
        // anchor cites dC once (unindexed → dropped) and a page anchor pg_5 (non-document → filtered).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "dB", targetVolumeId: "v1", targetDocumentId: "d0")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dC")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "pg_5")

        let results = try await store.relatedByCitation(forDocumentId: "d0", volumeId: "v1", limit: 30)
        let byId = Dictionary(uniqueKeysWithValues: results.map { ($0.documentId, $0) })
        #expect(results.map(\.documentId) == ["dA", "dB"])  // dA (count 2) ranks above dB (count 1)
        #expect(byId["dA"]?.citationCount == 2)
        #expect(byId["dB"]?.citationCount == 1)
        #expect(byId["dA"]?.header == "Doc A")
        #expect(byId["dC"] == nil)    // unindexed (no document_cache) → excluded by the INNER JOIN
        #expect(byId["pg_5"] == nil)  // page anchor → dropped by documentTargetPredicate
        #expect(byId["d0"] == nil)    // the anchor is never its own candidate
    }

    @Test("relatedByCitation restricts candidates to the scope volume set")
    func relatedByCitationScoped() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dA", header: "A")
        try insertDocumentCache(dbURL: dbURL, volumeId: "v2", documentId: "dB", header: "B")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v2", targetDocumentId: "dB")

        let unscoped = try await store.relatedByCitation(forDocumentId: "d0", volumeId: "v1", limit: 30)
        #expect(Set(unscoped.map(\.documentId)) == ["dA", "dB"])

        let scoped = try await store.relatedByCitation(
            forDocumentId: "d0", volumeId: "v1", scopeVolumeIds: ["v2"], limit: 30)
        #expect(scoped.map(\.documentId) == ["dB"])   // only the v2 candidate survives the scope
    }

    @Test("relatedByCitation excludes broken edges")
    func relatedByCitationExcludesBroken() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dA", header: "A")
        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dB", header: "B")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dA")
        try setBroken(dbURL: dbURL, sourceVolumeId: "v1", targetDocumentId: "dA")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dB")

        let results = try await store.relatedByCitation(forDocumentId: "d0", volumeId: "v1", limit: 30)
        #expect(results.map(\.documentId) == ["dB"])   // the broken dA edge is excluded
    }

    @Test("relatedByCitation resolves same-volume (NULL target_volume_id) edges on both arms")
    func relatedByCitationSameVolumeNullTarget() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dA", header: "A")
        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dB", header: "B")
        // The dominant corpus shape: a same-volume ref stores NULL target_volume_id.
        // Outbound: anchor cites dA (NULL target volume → COALESCE to source v1).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: nil, targetDocumentId: "dA")
        // Inbound: dB cites the anchor (NULL target volume → COALESCE to source v1 == anchor volume).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "dB", targetVolumeId: nil, targetDocumentId: "d0")

        let results = try await store.relatedByCitation(forDocumentId: "d0", volumeId: "v1", limit: 30)
        let byId = Dictionary(uniqueKeysWithValues: results.map { ($0.documentId, $0) })
        #expect(Set(results.map(\.documentId)) == ["dA", "dB"])
        #expect(byId["dA"]?.volumeId == "v1")       // outbound candidate attributed to the resolved volume
        #expect(byId["dB"]?.volumeId == "v1")       // inbound candidate is the citing source
        #expect(byId["dA"]?.citationCount == 1)
        #expect(byId["dB"]?.citationCount == 1)
    }

    @Test("relatedByCitation counts a bidirectional pair by multiplicity and excludes self-loops")
    func relatedByCitationBidirectionalAndSelfLoop() async throws {
        let (dir, dbURL, store) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "d0", header: "Anchor")
        try insertDocumentCache(dbURL: dbURL, volumeId: "v1", documentId: "dC", header: "C")
        // Bidirectional: anchor cites dC and dC cites anchor → multiplicity 2.
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "dC")
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "dC", targetVolumeId: "v1", targetDocumentId: "d0")
        // Self-loop: anchor cites itself (d0 has a document_cache row, so only the exclusion clause
        // — not the INNER JOIN — can drop it).
        try insertEdge(dbURL: dbURL, sourceVolumeId: "v1", sourceDocumentId: "d0", targetVolumeId: "v1", targetDocumentId: "d0")

        let results = try await store.relatedByCitation(forDocumentId: "d0", volumeId: "v1", limit: 30)
        #expect(results.map(\.documentId) == ["dC"])   // the self-loop anchor is excluded
        #expect(results.first?.citationCount == 2)      // cite + cited counted once each
    }
}

// MARK: - Broken-flag helper

/// Sets `is_broken = 1` on cross_reference rows matching `(sourceVolumeId, targetDocumentId)`.
private func setBroken(dbURL: URL, sourceVolumeId: String, targetDocumentId: String) throws {
    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
          let db else {
        throw CrossReferenceError.databaseOpenFailed(message: "setBroken: cannot open")
    }
    defer { sqlite3_close_v2(db) }
    let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db, "UPDATE cross_references SET is_broken = 1 WHERE source_volume_id = ? AND target_document_id = ?", -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, sourceVolumeId, -1, TRANSIENT)
    sqlite3_bind_text(stmt, 2, targetDocumentId, -1, TRANSIENT)
    sqlite3_step(stmt)
}
