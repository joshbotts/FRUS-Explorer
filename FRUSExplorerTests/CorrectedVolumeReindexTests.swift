// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3
import Testing
@testable import FRUSExplorer

// MARK: - CorrectedVolumeReindexTests

/// What a **corrected** volume leaves behind in the index (R-1a).
///
/// The Office of the Historian revises published volumes. A correction that REMOVES a document
/// re-indexes in place, and four per-volume tables are written with plain `INSERT OR REPLACE`:
/// `document_dates`, `persons`, `terms`, `document_sources`. `REPLACE` overwrites a row with the
/// same key and does nothing about a key that stopped being produced, so before R-1a the removed
/// document's rows survived forever — while `auxDeleteVolume` scrubbed all four, making
/// *delete-then-re-download* clean and *Update* not.
///
/// **These tests read the raw tables, deliberately.** The public accessors
/// (`documentDates(for:)`, `documentSourcesByKey(_:)`) join `document_cache`, which *is* scrubbed —
/// so a test written through them would pass over an orphan it never saw.
@Suite("Corrected volume re-index (R-1a)")
struct CorrectedVolumeReindexTests {

    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("R1aTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    private func makePipeline(dir: URL) async throws -> (IndexingPipeline, URL) {
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 2)
        return (pipeline, dbURL)
    }

    /// A volume whose documents each carry a date and a source note.
    private func volumeXML(documentIDs: [String]) -> String {
        let divs = documentIDs.enumerated().map { index, id in
            """
              <div type="document" xml:id="\(id)" n="\(index + 1)"
                   frus:doc-dateTime-min="1951-06-0\(index + 1)"
                   frus:doc-dateTime-max="1951-06-0\(index + 1)">
                <head>Memorandum \(id)
                  <note type="source">Source: Department of State, Central Files, 611.5\(index)/6-151.</note>
                </head>
                <p>Negotiations continued.</p>
              </div>
            """
        }.joined(separator: "\n")
        let ns = "xmlns=\"http://www.tei-c.org/ns/1.0\" "
            + "xmlns:frus=\"http://history.state.gov/frus/ns/1.0\""
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI \(ns) xml:id="frus1951v01">
          <teiHeader><fileDesc><titleStmt><title>frus1951v01</title></titleStmt></fileDesc></teiHeader>
          <text><body>
        \(divs)
          </body></text>
        </TEI>
        """
    }

    /// Raw row count for one document, bypassing every join.
    private func rawCount(_ dbURL: URL, table: String,
                          volumeID: String, documentID: String) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db,
                              SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else { return -1 }
        defer { sqlite3_close_v2(db) }
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM \(table) WHERE volume_id = ? AND document_id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, volumeID, -1, transient)
        sqlite3_bind_text(stmt, 2, documentID, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return -1 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// A correction that drops a document must leave none of its per-volume rows behind.
    ///
    /// This is the test that fails without R-1a's `auxDeletePerVolumeRows`. Both halves matter: the
    /// first re-index proves the fixture really produced the rows, so the second assertion cannot
    /// pass vacuously over a document that never had any.
    @Test("A correction that removes a document leaves no dates or source rows behind")
    func removedDocumentLeavesNoOrphans() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makePipeline(dir: dir)
            let file = dir.appendingPathComponent("volumes/frus1951v01.xml")

            try volumeXML(documentIDs: ["d1", "d2"]).write(to: file, atomically: true, encoding: .utf8)
            try await pipeline.indexVolume("frus1951v01")

            // The fixture must actually populate both tables, or the removal assertion is vacuous.
            let datesBefore = rawCount(dbURL, table: "document_dates",
                                       volumeID: "frus1951v01", documentID: "d2")
            let sourcesBefore = rawCount(dbURL, table: "document_sources",
                                         volumeID: "frus1951v01", documentID: "d2")
            #expect(datesBefore == 1, "fixture produced \(datesBefore) date rows for d2")
            #expect(sourcesBefore == 1, "fixture produced \(sourcesBefore) source rows for d2")

            // The correction: d2 is gone.
            try volumeXML(documentIDs: ["d1"]).write(to: file, atomically: true, encoding: .utf8)
            try await pipeline.indexVolume("frus1951v01")

            #expect(rawCount(dbURL, table: "document_dates",
                             volumeID: "frus1951v01", documentID: "d2") == 0,
                    "a removed document kept its document_dates row")
            #expect(rawCount(dbURL, table: "document_sources",
                             volumeID: "frus1951v01", documentID: "d2") == 0,
                    "a removed document kept its document_sources row")

            // The surviving document must still be there — a scrub that took everything would
            // satisfy the assertions above and break the index.
            #expect(rawCount(dbURL, table: "document_dates",
                             volumeID: "frus1951v01", documentID: "d1") == 1,
                    "the surviving document lost its date row")
            #expect(rawCount(dbURL, table: "document_sources",
                             volumeID: "frus1951v01", documentID: "d1") == 1,
                    "the surviving document lost its source row")
        }
    }

    /// The scrub must be per volume, never global.
    @Test("Re-indexing one volume does not scrub another's rows")
    func scrubIsScopedToTheVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await makePipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try volumeXML(documentIDs: ["d1"]).write(
                to: volDir.appendingPathComponent("frus1951v01.xml"), atomically: true, encoding: .utf8)
            let other = volumeXML(documentIDs: ["d1"])
                .replacingOccurrences(of: "frus1951v01", with: "frus1952v01")
            try other.write(to: volDir.appendingPathComponent("frus1952v01.xml"),
                            atomically: true, encoding: .utf8)
            try await pipeline.indexVolume("frus1951v01")
            try await pipeline.indexVolume("frus1952v01")
            #expect(rawCount(dbURL, table: "document_dates",
                             volumeID: "frus1952v01", documentID: "d1") == 1)

            // Re-index the FIRST volume; the second must be untouched.
            try await pipeline.indexVolume("frus1951v01")
            #expect(rawCount(dbURL, table: "document_dates",
                             volumeID: "frus1952v01", documentID: "d1") == 1,
                    "re-indexing one volume scrubbed another's rows")
            #expect(rawCount(dbURL, table: "document_sources",
                             volumeID: "frus1952v01", documentID: "d1") == 1,
                    "re-indexing one volume scrubbed another's source rows")
        }
    }
}
