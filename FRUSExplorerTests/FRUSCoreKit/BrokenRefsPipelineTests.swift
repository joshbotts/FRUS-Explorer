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
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
// SQLite3 is the system's on Apple platforms; on Linux the web edition supplies CSQLite.
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

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
// MARK: - Index version 66: what a reference that names no document is stored as (#1613)

/// A `<ref>` to a footnote, to a whole volume, or to a web or mail address names no document, and
/// until index version 66 each was stored as an edge to a document named after it. These tests
/// index a volume through the pipeline's own store pass and read the rows it leaves.
///
/// The fixture's first document cites, in this order: a document, a footnote of that document, a
/// footnote in another volume, a whole volume, a web address, a mail address, and a footnote of a
/// document the volume does not hold.
@Suite("Index version 66: references that name no document (#1613)")
struct SettledCrossReferenceTests {

    private static let volumeId = "frus1969-76v01"

    private static let volumeXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text><body>
            <div type="compilation" xml:id="comp1"><head>Compilation</head>
              <div type="document" xml:id="d1" n="1"><head>1. Telegram</head>
                <p>Text.<note n="1" xml:id="d1fn1">See <ref target="#d2">Document 2</ref>,
                  <ref target="#d2fn1">footnote 1, Document 2</ref>,
                  <ref target="frus1955-57v09#d12fn3">footnote 3, Document 12</ref>,
                  <ref target="frus1961-63v05">volume V</ref>,
                  <ref target="https://history.state.gov/historicaldocuments">the site</ref>,
                  <ref target="mailto:history@state.gov">the office</ref> and
                  <ref target="#d999fn1">a note that is not here</ref>.</note></p>
              </div>
              <div type="document" xml:id="d2" n="2"><head>2. Memorandum</head>
                <p>Text.<note n="1" xml:id="d2fn1">A note.</note></p>
              </div>
            </div>
          </body></text>
        </TEI>
        """

    /// One stored row of `cross_references`.
    private struct Stored: Equatable {
        var targetVolume: String?
        var targetDocument: String
        var isBroken: Bool
    }

    /// A pipeline over a temporary index and the fixture volume, with `broken` as its
    /// broken-reference index, or none.
    private func makeIndexedPipeline(
        broken: BrokenRefsIndex? = nil
    ) async throws -> (dir: URL, dbURL: URL, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSettledRefs-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Self.volumeXML.write(to: volumes.appendingPathComponent("\(Self.volumeId).xml"),
                                 atomically: true, encoding: .utf8)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let resources = IndexingResources(
            personAuthority: { nil }, documentSubjects: { nil },
            decimalClassLabels: { nil }, brokenRefs: { broken })
        let pipeline = try IndexingPipeline(
            fts5Store: try FTS5Store(databaseURL: dbURL), databaseURL: dbURL,
            volumesDirectory: volumes, resources: resources, concurrencyLimit: 1,
            defaults: InMemoryIndexingStampStore())
        try await pipeline.indexVolume(Self.volumeId)
        return (dir, dbURL, pipeline)
    }

    /// The rows document `d1` left, in the order its references are written.
    private func storedRows(_ dbURL: URL) throws -> [Stored] {
        try withDB(dbURL) { db in
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, """
                SELECT target_volume_id, target_document_id, is_broken FROM cross_references
                WHERE source_volume_id = '\(Self.volumeId)' AND source_document_id = 'd1'
                ORDER BY rowid
                """, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            var rows: [Stored] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(Stored(
                    targetVolume: sqlite3_column_text(stmt, 0).map { String(cString: $0) },
                    targetDocument: String(cString: sqlite3_column_text(stmt, 1)),
                    isBroken: sqlite3_column_int(stmt, 2) != 0))
            }
            return rows
        }
    }

    /// A broken-reference index naming `target` in the fixture volume.
    private func brokenIndex(naming target: String) throws -> BrokenRefsIndex {
        let json = """
            {"schemaVersion":1,"generated":"2026-10-11","corpusVolumeCount":1,"seriesVolumeCount":1,\
            "totalBroken":1,"fullDetail":true,"records":[\
            {"sv":"\(Self.volumeId)","sd":"d1","t":"\(target)","r":"unknownAnchor",\
            "rv":"\(Self.volumeId)","ra":"\(target.dropFirst())"}]}
            """
        return try JSONDecoder().decode(BrokenRefsIndex.self, from: Data(json.utf8))
    }

    @Test("A footnote is stored as its document, a volume as a volume, and an address not at all")
    func storedAsWhatTheyName() async throws {
        let (dir, dbURL, _) = try await makeIndexedPipeline()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try storedRows(dbURL) == [
            Stored(targetVolume: nil, targetDocument: "d2", isBroken: false),
            // `#d2fn1`: the document that holds the note, where it was `d2fn1`.
            Stored(targetVolume: nil, targetDocument: "d2", isBroken: false),
            // `frus1955-57v09#d12fn3`: its volume is kept, and the id was `d12fn3`.
            Stored(targetVolume: "frus1955-57v09", targetDocument: "d12", isBroken: false),
            // `frus1961-63v05`: a volume and no document, where it was a document of that name
            // with no volume.
            Stored(targetVolume: "frus1961-63v05", targetDocument: "", isBroken: false),
            // The web and mail addresses left no row. `#d999fn1` is its document's too.
            Stored(targetVolume: nil, targetDocument: "d999", isBroken: false),
        ])
    }

    @Test("A reference the broken-reference index names keeps its raw target and its mark")
    func aBrokenReferenceStaysRaw() async throws {
        let index = try brokenIndex(naming: "#d999fn1")
        let (dir, dbURL, pipeline) = try await makeIndexedPipeline(broken: index)
        defer { try? FileManager.default.removeItem(at: dir) }
        let rows = try storedRows(dbURL)
        #expect(rows.count == 5)
        #expect(rows.last == Stored(targetVolume: nil, targetDocument: "d999fn1", isBroken: true))
        // The rows the index does not name are settled as before.
        #expect(rows.dropLast().map(\.targetDocument) == ["d2", "d2", "d12", ""])
        #expect(rows.dropLast().allSatisfy { !$0.isBroken })

        // The library-wide pass clears every mark and matches raw targets again: it finds the row.
        try await pipeline.applyBrokenRefsIndex(
            targets: [(sourceVolume: Self.volumeId, rawTarget: "#d999fn1")])
        #expect(try storedRows(dbURL).last
                == Stored(targetVolume: nil, targetDocument: "d999fn1", isBroken: true))
    }

    @Test("A whole-volume reference the index names keeps its raw target too")
    func aBrokenWholeVolumeReferenceStaysRaw() async throws {
        // The volume form has no `#`, and the store pass settles it by a statement of its own.
        let index = try brokenIndex(naming: "frus1961-63v05")
        let (dir, dbURL, _) = try await makeIndexedPipeline(broken: index)
        defer { try? FileManager.default.removeItem(at: dir) }
        let rows = try storedRows(dbURL)
        #expect(rows.count == 5)
        #expect(rows[3] == Stored(targetVolume: nil, targetDocument: "frus1961-63v05", isBroken: true))
        #expect(rows.map(\.targetDocument) == ["d2", "d2", "d12", "frus1961-63v05", "d999"])
    }

    @Test("Both walks collect the same rows, with what each settles as")
    func bothWalksAgree() {
        let nodes: [FRUSASTNode] = [
            .footnote(id: nil, type: .footnote, printedNumber: nil, children: [
                .crossReference(target: "#d2", targetVolumeId: nil, children: [.text("a")]),
                .crossReference(target: "#d2fn1", targetVolumeId: nil, children: [.text("b")]),
                .crossReference(target: "frus1955-57v09#d12fn3", targetVolumeId: "frus1955-57v09",
                                children: [.text("c")]),
                .crossReference(target: "frus1961-63v05", targetVolumeId: nil, children: [.text("d")]),
                .crossReference(target: "https://history.state.gov/x", targetVolumeId: nil,
                                children: [.text("e")]),
                .crossReference(target: "mailto:history@state.gov", targetVolumeId: nil,
                                children: [.text("f")]),
                .crossReference(target: "#pg_12", targetVolumeId: nil, children: [.text("g")]),
            ])
        ]
        let extracted = IndexingPipeline.extractCrossReferences(
            from: nodes, sourceVolumeId: "v", sourceDocumentId: "d1")
        var collected: [CrossReferenceRow] = []
        var persons = Set<String>(), lists = Set<String>(), pages: [PageRangeRow] = []
        IndexingPipeline.collectDocumentRefs(
            from: nodes, volumeId: "v", documentId: "d1", crossRefs: &collected,
            personRefs: &persons, personListVolumes: &lists, pageRanges: &pages)

        // As written, with nothing for the two addresses.
        #expect(extracted.map(\.targetDocumentId) == ["d2", "d2fn1", "d12fn3", "frus1961-63v05", "pg_12"])
        #expect(extracted.map(\.settled) == [
            nil, .document("d2"), .document("d12"), .volume("frus1961-63v05"), nil,
        ])
        #expect(collected.map(\.targetDocumentId) == extracted.map(\.targetDocumentId))
        #expect(collected.map(\.targetVolumeId) == extracted.map(\.targetVolumeId))
        #expect(collected.map(\.settled) == extracted.map(\.settled))
    }
}
