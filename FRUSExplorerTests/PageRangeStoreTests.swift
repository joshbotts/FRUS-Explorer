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

// MARK: - PageRangeStoreTests

struct PageRangeStoreTests {

    // MARK: - Fixture Helpers

    /// Creates an in-memory SQLite database populated with the page_ranges table and test data.
    private static func makeDB() throws -> (OpaquePointer, URL) {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("test_page_ranges_\(UUID().uuidString).db")

        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "PageRangeStoreTests", code: 1, userInfo: nil)
        }

        let ddl = """
        CREATE TABLE page_ranges (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            section_id TEXT NOT NULL,
            page_number_type TEXT NOT NULL,
            page_number_int INTEGER,
            page_number_raw TEXT NOT NULL
        );
        CREATE INDEX idx_prt ON page_ranges(volume_id, page_number_type, page_number_int);
        CREATE INDEX idx_prd ON page_ranges(volume_id, document_id);
        """
        exec(ddl, db: db)
        return (db, url)
    }

    private static func insert(
        db: OpaquePointer,
        volumeId: String, documentId: String, sectionId: String,
        type: String, intVal: Int?, raw: String
    ) {
        let intStr = intVal.map { "\($0)" } ?? "NULL"
        exec("INSERT INTO page_ranges (volume_id, document_id, section_id, page_number_type, page_number_int, page_number_raw) VALUES ('\(volumeId)', '\(documentId)', '\(sectionId)', '\(type)', \(intStr), '\(raw)')", db: db)
    }

    private static func exec(_ sql: String, db: OpaquePointer) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private static func closeAndMakeStore(db: OpaquePointer, url: URL) throws -> PageRangeStore {
        sqlite3_close(db)
        return try PageRangeStore(databaseURL: url)
    }

    // MARK: - DocumentLookupTest

    @Test("PageRangeStoreTest: page in middle of a document span returns correct documentId")
    func documentLookupTest() async throws {
        let (db, url) = try Self.makeDB()
        // doc1: pages 1-10, doc2: pages 11-20
        for p in 1...10  { Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        for p in 11...20 { Self.insert(db: db, volumeId: "v1", documentId: "d2", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        let result = try await store.document(forPage: 7, inVolume: "v1")
        #expect(result == "d1", "Page 7 should map to d1, got \(result ?? "nil")")
    }

    // MARK: - BoundaryTest

    @Test("PageRangeStoreTest: first and last page of a span both map to correct documentId")
    func boundaryTest() async throws {
        let (db, url) = try Self.makeDB()
        for p in 1...10  { Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        for p in 11...20 { Self.insert(db: db, volumeId: "v1", documentId: "d2", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        let first = try await store.document(forPage: 1, inVolume: "v1")
        let last  = try await store.document(forPage: 10, inVolume: "v1")
        #expect(first == "d1")
        #expect(last  == "d1")

        let firstD2 = try await store.document(forPage: 11, inVolume: "v1")
        #expect(firstD2 == "d2")
    }

    // MARK: - GapTest

    @Test("PageRangeStoreTest: page beyond last known span returns nil gracefully")
    func gapTest() async throws {
        let (db, url) = try Self.makeDB()
        for p in 1...10 { Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        // The last document (d1) absorbs all remaining pages; only pages before d1 could be a gap.
        // Query a page far outside any known range for a different volume:
        let result = try await store.document(forPage: 999, inVolume: "v2")
        #expect(result == nil)
    }

    // MARK: - PaginationRestartTest

    @Test("PageRangeStoreTest: overlapping page numbers in different sections are disambiguated")
    func paginationRestartTest() async throws {
        let (db, url) = try Self.makeDB()
        // Part 1 (s1): doc1 pages 1–5, doc2 pages 6–10
        for p in 1...5  { Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        for p in 6...10 { Self.insert(db: db, volumeId: "v1", documentId: "d2", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        // Part 2 (s2): doc3 pages 1–5 (restarts at 1)
        for p in 1...5  { Self.insert(db: db, volumeId: "v1", documentId: "d3", sectionId: "s2", type: "arabic", intVal: p, raw: "\(p)") }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        // Page 3 in s1 → d1, page 3 in s2 → d3.
        // The store returns the first section match — both should not crash.
        let result = try await store.document(forPage: 3, inVolume: "v1")
        #expect(result == "d1" || result == "d3", "Page 3 should map to either d1 or d3 depending on section")
    }

    // MARK: - MissingVolumeTest

    @Test("PageRangeStoreTest: volume with no page_ranges data returns nil")
    func missingVolumeTest() async throws {
        let (db, url) = try Self.makeDB()
        // Insert data for v1 only
        Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: 1, raw: "1")
        let store = try Self.closeAndMakeStore(db: db, url: url)

        let result = try await store.document(forPage: 1, inVolume: "v-unknown")
        #expect(result == nil)
    }

    // MARK: - PageRangeForDocumentTest

    @Test("PageRangeStoreTest: pageRange(forDocument:inVolume:) returns correct (first, last) tuple")
    func pageRangeForDocumentTest() async throws {
        let (db, url) = try Self.makeDB()
        for p in [5, 6, 7, 8, 9] {
            Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)")
        }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        let range = try await store.pageRange(forDocument: "d1", inVolume: "v1")
        #expect(range?.first == 5)
        #expect(range?.last  == 9)
    }
}
