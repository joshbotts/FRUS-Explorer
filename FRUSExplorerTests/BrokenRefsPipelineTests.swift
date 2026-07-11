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

// MARK: - Harness

/// Temp-DB pipeline harness for the `is_broken` marking tests (#240B review): bootstraps the
/// schema via `IndexingPipeline` (which also runs the ALTER migrations) and inserts raw
/// cross_reference rows directly.
private func makePipeline() throws -> (dir: URL, dbURL: URL, pipeline: IndexingPipeline) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSBrokenRefs-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let fts5 = try FTS5Store(databaseURL: dbURL)
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
    let pipeline = try IndexingPipeline(
        fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
    return (dir, dbURL, pipeline)
}

private func withDB<T>(_ dbURL: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
    var db: OpaquePointer?
    guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
          let db else { fatalError("cannot open test DB") }
    defer { sqlite3_close_v2(db) }
    return try body(db)
}

private func insertRef(_ dbURL: URL, sv: String, sd: String, tvol: String?, tdoc: String) throws {
    try withDB(dbURL) { db in
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, """
            INSERT INTO cross_references
            (source_volume_id, source_document_id, target_volume_id, target_document_id)
            VALUES (?, ?, ?, ?)
            """, -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sv, -1, T)
        sqlite3_bind_text(stmt, 2, sd, -1, T)
        if let tvol { sqlite3_bind_text(stmt, 3, tvol, -1, T) } else { sqlite3_bind_null(stmt, 3) }
        sqlite3_bind_text(stmt, 4, tdoc, -1, T)
        sqlite3_step(stmt)
    }
}

/// `(is_broken, target_document_id)` rows for a source volume, ordered by rowid.
private func brokenStates(_ dbURL: URL, sv: String) throws -> [(broken: Int, tdoc: String)] {
    try withDB(dbURL) { db in
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db,
            "SELECT is_broken, target_document_id FROM cross_references WHERE source_volume_id = ? ORDER BY rowid",
            -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sv, -1, T)
        var out: [(Int, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append((Int(sqlite3_column_int64(stmt, 0)),
                        String(cString: sqlite3_column_text(stmt, 1))))
        }
        return out
    }
}

// MARK: - targetColumns

struct BrokenRefsTargetColumnsTests {

    @Test("targetColumns reconstructs the stored split for every target shape")
    func shapes() {
        // Same-volume anchor.
        var c = IndexingPipeline.targetColumns(forRawTarget: "#d42")
        #expect(c.volumeId == nil && c.documentId == "d42")
        // Cross-volume anchor.
        c = IndexingPipeline.targetColumns(forRawTarget: "frus1877#pg_1077")
        #expect(c.volumeId == "frus1877" && c.documentId == "pg_1077")
        // Empty anchor after '#': documentId empty — callers skip.
        c = IndexingPipeline.targetColumns(forRawTarget: "frus1901#")
        #expect(c.volumeId == "frus1901" && c.documentId.isEmpty)
        // http targets never reach marking, but the split must not crash or fabricate a volume.
        c = IndexingPipeline.targetColumns(forRawTarget: "http://example.com#frag")
        #expect(c.volumeId == nil)
    }
}

// MARK: - Marking + backfill

struct BrokenRefsMarkingTests {

    @Test("Per-volume marking flags same-volume and cross-volume rows, scoped to the volume")
    func perVolumeMarking() async throws {
        let (dir, dbURL, pipeline) = try makePipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertRef(dbURL, sv: "volA", sd: "d1", tvol: nil, tdoc: "dX")            // broken same-vol
        try insertRef(dbURL, sv: "volA", sd: "d1", tvol: "volB", tdoc: "pg_99")      // broken cross-vol
        try insertRef(dbURL, sv: "volA", sd: "d1", tvol: nil, tdoc: "d5")            // valid
        try insertRef(dbURL, sv: "volC", sd: "d1", tvol: nil, tdoc: "dX")            // other volume — untouched

        try await pipeline.markBrokenCrossReferences(volumeId: "volA", brokenTargets: [
            (sourceVolume: "volA", rawTarget: "#dX"),
            (sourceVolume: "volA", rawTarget: "volB#pg_99"),
            (sourceVolume: "volC", rawTarget: "#dX"),   // filtered: not this volume
        ])

        #expect(try brokenStates(dbURL, sv: "volA").map(\.broken) == [1, 1, 0])
        #expect(try brokenStates(dbURL, sv: "volC").map(\.broken) == [0])
    }

    @Test("Backfill resets then re-marks: a shrinking target set un-marks fixed refs")
    func backfillResetSemantics() async throws {
        let (dir, dbURL, pipeline) = try makePipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        try insertRef(dbURL, sv: "volA", sd: "d1", tvol: nil, tdoc: "dX")
        try insertRef(dbURL, sv: "volB", sd: "d2", tvol: "volA", tdoc: "pg_7")

        // Full set: both marked.
        var marked = try await pipeline.applyBrokenRefsIndex(targets: [
            (sourceVolume: "volA", rawTarget: "#dX"),
            (sourceVolume: "volB", rawTarget: "volA#pg_7"),
        ])
        #expect(marked == 2)
        #expect(try brokenStates(dbURL, sv: "volA").map(\.broken) == [1])
        #expect(try brokenStates(dbURL, sv: "volB").map(\.broken) == [1])

        // The editors fixed volA's ref: re-apply with the shrunk set — volA un-marks.
        marked = try await pipeline.applyBrokenRefsIndex(targets: [
            (sourceVolume: "volB", rawTarget: "volA#pg_7"),
        ])
        #expect(marked == 1)
        #expect(try brokenStates(dbURL, sv: "volA").map(\.broken) == [0])
        #expect(try brokenStates(dbURL, sv: "volB").map(\.broken) == [1])

        // Idempotent: same set again, same result.
        marked = try await pipeline.applyBrokenRefsIndex(targets: [
            (sourceVolume: "volB", rawTarget: "volA#pg_7"),
        ])
        #expect(marked == 1)
    }
}

// MARK: - Cross-volume page refs survive the resolve pass (v22 regression net)

struct CrossVolumePageRefResolveTests {

    /// v21 and earlier resolved cross-volume page refs against the SOURCE volume's pagination
    /// (missing `target_volume_id IS NULL` guard) — fabricating edges and defeating the broken-ref
    /// matching. This indexes a fixture volume whose own pages span the referenced number and
    /// asserts the cross-volume anchor survives verbatim while the same-volume one resolves.
    @Test("Indexing leaves cross-volume page anchors unresolved; same-volume anchors still resolve")
    func crossVolumeAnchorSurvives() async throws {
        let (dir, dbURL, pipeline) = try makePipeline()
        defer { try? FileManager.default.removeItem(at: dir) }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="volS">
        <teiHeader><fileDesc><titleStmt><title>Fixture</title></titleStmt>
        <publicationStmt><p/></publicationStmt><sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
        <text><body>
        <div type="document" xml:id="d1" n="1">
          <head>Doc 1</head>
          <pb n="10" xml:id="pg_10"/>
          <p>Cross-volume: <ref target="volT#pg_12">page 12 of T</ref>.
             Same-volume: <ref target="#pg_12">page 12 here</ref>.</p>
        </div>
        <div type="document" xml:id="d2" n="2">
          <head>Doc 2</head>
          <pb n="12" xml:id="pg_12"/>
          <p>Content.</p>
        </div>
        </body></text></TEI>
        """
        let volDir = dir.appendingPathComponent("volumes")
        try Data(xml.utf8).write(to: volDir.appendingPathComponent("volS.xml"))

        try await pipeline.indexVolume("volS")

        let rows = try brokenStates(dbURL, sv: "volS")
        let tdocs = rows.map(\.tdoc).sorted()
        // The same-volume #pg_12 resolved to its containing document d2; the cross-volume
        // volT#pg_12 kept its raw page anchor (volT is not indexed — resolution must not
        // consult volS's pagination).
        #expect(tdocs.contains("pg_12"), "cross-volume page anchor must survive verbatim")
        #expect(tdocs.contains("d2"), "same-volume page anchor must resolve to its document")
        #expect(!tdocs.filter { $0 == "pg_12" }.isEmpty)
        #expect(rows.count == 2)
    }
}