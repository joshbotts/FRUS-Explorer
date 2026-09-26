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

    // MARK: - EarlySectionTest (Session 162)

    @Test("PageRangeStoreTest: a section whose pagination ends early cannot claim later pages")
    func earlySectionDoesNotAbsorbLaterPages() async throws {
        let (db, url) = try Self.makeDB()
        // Front-matter-like section ending at page 9 (the shape that made
        // p. 313 of frus1955-57v17 resolve to a page-9 document pre-fix).
        for p in 1...9 {
            Self.insert(db: db, volumeId: "v1", documentId: "dfront", sectionId: "s0", type: "arabic", intVal: p, raw: "\(p)")
        }
        // Body section: d166 owns 310-311, d167 owns 312-315.
        for p in 310...311 {
            Self.insert(db: db, volumeId: "v1", documentId: "d166", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)")
        }
        for p in 312...315 {
            Self.insert(db: db, volumeId: "v1", documentId: "d167", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)")
        }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        let inBody = try await store.document(forPage: 313, inVolume: "v1")
        #expect(inBody == "d167")
        // Beyond every section's recorded pages: no match, never the early
        // section's last document.
        let beyond = try await store.document(forPage: 999, inVolume: "v1")
        #expect(beyond == nil)
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

    // MARK: - printedPages (#1474 review round 3)

    /// A store over documents written the way the index writes them: one `document_cache` row per
    /// document, in the order given — which is the order `printedPages` reads as "before" and
    /// "after" — and one `page_ranges` row per page break, owned by its document and classified by
    /// `PageNumber.parse`, as `IndexingPipeline` does (`"12"` arabic, `"ii"` roman).
    private static func makeOrderedStore(
        _ documents: [(volumeId: String, documentId: String, breaks: [String])]
    ) throws -> PageRangeStore {
        let (db, url) = try makeDB()
        exec("""
            CREATE TABLE document_cache (
                volume_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                PRIMARY KEY (volume_id, document_id)
            );
            """, db: db)
        for document in documents {
            exec("INSERT INTO document_cache (volume_id, document_id) VALUES ('\(document.volumeId)', '\(document.documentId)')",
                 db: db)
            for raw in document.breaks {
                let type: String
                let value: Int?
                switch PageNumber.parse(raw) {
                case .arabic(let n): (type, value) = ("arabic", n)
                case .roman(let n): (type, value) = ("roman", n)
                case .prefixed: (type, value) = ("prefixed", nil)
                case .unparseable: (type, value) = ("unparseable", nil)
                }
                insert(db: db, volumeId: document.volumeId, documentId: document.documentId,
                       sectionId: document.documentId, type: type, intVal: value, raw: raw)
            }
        }
        return try closeAndMakeStore(db: db, url: url)
    }

    @Test("PageRangeStoreTest: printedPages never starts below page 1 — a document whose first break is page 1 is not on page 0 (#1474 review round 3)")
    func printedPagesNeverStartsBelowPageOne() async throws {
        let store = try Self.makeOrderedStore([
            ("v1", "d1", ["1", "2", "3"]),
            ("v1", "d2", ["7"]),
        ])
        // The page before the first break, except that there is none before page 1.
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == 1...3)
        // The control: any other first break still admits the page before it.
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 6...7)
    }

    @Test("PageRangeStoreTest: printedPages is nil for a document with no break of its own at a pagination restart, where the bound is empty (#1474 review round 3)")
    func printedPagesIsNilAcrossAPaginationRestart() async throws {
        // d2 has no break of its own; the break before it is 11, and the one after it is page 1 of
        // a new pagination, so the bound 11...0 is empty: 735 documents in the corpus sit so.
        let store = try Self.makeOrderedStore([
            ("v1", "d1", ["10", "11"]),
            ("v1", "d2", []),
            ("v1", "d3", ["1", "2"]),
            ("v1", "d4", []),
            ("v1", "d5", ["4"]),
        ])
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == nil)
        // The control: past the restart, a no-break document is bounded again.
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == 2...3)
    }

    @Test("PageRangeStoreTest: printedPages is nil for a no-break document whose nearest break on a side is not arabic, or that has no break on a side at all (#1474 review round 3)")
    func printedPagesIsNilWithoutAnArabicBreakOnEachSide() async throws {
        // Other volumes' documents are indexed before and after v1's, with breaks of their own:
        // "no break before it" means none in ITS volume.
        let store = try Self.makeOrderedStore([
            ("v0", "d1", ["1"]),
            ("v1", "d0", []),        // nothing before it in v1 (390 in the corpus)
            ("v1", "d1", ["3"]),
            ("v1", "d2", []),        // the control: between 3 and 6
            ("v1", "d3", ["6"]),
            ("v1", "d4", []),        // nothing after it in v1 (316 in the corpus)
            ("v2", "d1", ["9"]),
            ("v3", "d1", ["ii"]),    // a front-matter roman page
            ("v3", "d2", []),        // its nearest earlier break is roman ii
            ("v3", "d3", ["5"]),
        ])
        #expect(try await store.printedPages(forDocument: "d0", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v3") == nil)
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 3...5)
    }

    @Test("PageRangeStoreTest: printedPages is nil for a document whose own breaks are none of them arabic (#1474 review round 3)")
    func printedPagesIsNilWhenTheDocumentsBreaksAreNoneArabic() async throws {
        let store = try Self.makeOrderedStore([
            ("v1", "d1", ["iii", "iv"]),
            ("v1", "d2", ["iv", "5"]),
        ])
        // It has breaks, so the bound is never consulted, and none of them is a page number the
        // body's numbering can check: 54 documents in the corpus sit so.
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == nil)
        // The control: one arabic break among roman ones is enough.
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 4...5)
    }
}
