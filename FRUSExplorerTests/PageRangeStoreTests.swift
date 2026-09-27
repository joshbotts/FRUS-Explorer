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
            page_number_raw TEXT NOT NULL,
            is_start INTEGER NOT NULL DEFAULT 0
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
        type: String, intVal: Int?, raw: String, isStart: Bool = false
    ) {
        let intStr = intVal.map { "\($0)" } ?? "NULL"
        exec("INSERT INTO page_ranges (volume_id, document_id, section_id, page_number_type, page_number_int, page_number_raw, is_start) VALUES ('\(volumeId)', '\(documentId)', '\(sectionId)', '\(type)', \(intStr), '\(raw)', \(isStart ? 1 : 0))", db: db)
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

    @Test("PageRangeStoreTest: overlapping page numbers in different sections are both returned, as an ambiguous answer")
    func paginationRestartTest() async throws {
        let (db, url) = try Self.makeDB()
        // Part 1 (s1): doc1 pages 1–5, doc2 pages 6–10
        for p in 1...5  { Self.insert(db: db, volumeId: "v1", documentId: "d1", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        for p in 6...10 { Self.insert(db: db, volumeId: "v1", documentId: "d2", sectionId: "s1", type: "arabic", intVal: p, raw: "\(p)") }
        // Part 2 (s2): doc3 pages 1–5 (restarts at 1)
        for p in 1...5  { Self.insert(db: db, volumeId: "v1", documentId: "d3", sectionId: "s2", type: "arabic", intVal: p, raw: "\(p)") }
        let store = try Self.closeAndMakeStore(db: db, url: url)

        // Page 3 is printed in d1 and in d3, and nothing in the rows says which a citation means
        // (#1503: `section_id` groups nothing, and the lookup never reads it). Both are returned, in
        // the order the index stored them — until #1503, whichever section a Swift Dictionary
        // reached first — and a page link opens the first.
        let result = try await store.documents(forPage: 3, inVolume: "v1")
        #expect(result?.documents.map(\.documentId) == ["d1", "d3"])
        #expect(result?.isAmbiguous == true)
        #expect(try await store.document(forPage: 3, inVolume: "v1") == "d1")
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

    // MARK: - printedPages (#1474 review round 3, #1503)

    /// A store over documents written the way the index writes them since #1503: per document, in
    /// the order given, its start row when it has one — the page it begins on, flagged `is_start` —
    /// then one row per page break inside it, each read as the parser reads a break whose id is the
    /// volume's own for its page and classified as `IndexingPipeline.pageRangeRow` classifies it
    /// (`"12"` arabic, `"ii"` roman, `"[31]"` — with `xml:id="pg_31"` — the arabic page 31).
    private static func makeOrderedStore(
        _ documents: [(volumeId: String, documentId: String, start: String?, breaks: [String])]
    ) throws -> PageRangeStore {
        let (db, url) = try makeDB()
        for document in documents {
            let rows = (document.start.map { [($0, true)] } ?? []) + document.breaks.map { ($0, false) }
            for (raw, isStart) in rows {
                let id = "pg_" + raw.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                let row = IndexingPipeline.pageRangeRow(volumeId: document.volumeId,
                                                        documentId: document.documentId,
                                                        pageNumber: PageNumber.parse(raw, xmlId: id),
                                                        isStart: isStart)
                insert(db: db, volumeId: row.volumeId, documentId: row.documentId, sectionId: row.sectionId,
                       type: row.pageNumberType, intVal: row.pageNumberInt, raw: row.pageNumberRaw,
                       isStart: row.isStart)
            }
        }
        return try closeAndMakeStore(db: db, url: url)
    }

    @Test("PageRangeStoreTest: printedPages never starts below page 1 — a document whose first break is page 1 is not on page 0 (#1474 review round 3)")
    func printedPagesNeverStartsBelowPageOne() async throws {
        // No start recorded — an index built before #1503 — so only the breaks place them.
        let store = try Self.makeOrderedStore([
            ("v1", "d1", nil, ["1", "2", "3"]),
            ("v1", "d2", nil, ["7"]),
        ])
        // The page before the first break, except that there is none before page 1.
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == 1...3)
        // The control: any other first break still admits the page before it.
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 6...7)
    }

    @Test("PageRangeStoreTest: printedPages runs from the page a document begins on — one page for a document with no break of its own, a pagination restart included (#1503)")
    func printedPagesRunsFromThePageADocumentBeginsOn() async throws {
        let store = try Self.makeOrderedStore([
            ("v1", "d1", "9", ["10", "11"]),
            ("v1", "d2", "11", []),          // no break of its own, below d1's end
            ("v1", "d3", "1", ["2"]),         // a new pagination, on a break between documents
            ("v1", "d4", "2", []),            // past the restart, below d3's end
            ("v1", "d5", "[31]", ["33"]),     // a page printed without its number
            ("v1", "d6", "34", []),           // and on: one restart in six documents, a printed volume
        ])
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == 9...11)
        // Until #1503, d2 was bounded by its neighbours' breaks — 11 before it and page 1 of the new
        // pagination after it, an empty bound, so it went unchecked: 735 documents sat so.
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 11...11)
        #expect(try await store.printedPages(forDocument: "d3", inVolume: "v1") == 1...2)
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == 2...2)
        // From [31], page 31, through its break 33 — read as unparseable, the start would place
        // nothing, and d5 would be on 32–33 by its own break (#1503 review round 1: with a first
        // break of 32 the two readings gave the same 31–32, so this pinned nothing).
        #expect(try await store.printedPages(forDocument: "d5", inVolume: "v1") == 31...33)
        #expect(try await store.documents(forPage: 31, inVolume: "v1")?.documents.map(\.documentId) == ["d5"])
    }

    @Test("PageRangeStoreTest: a start its own breaks run below does not place a document — its breaks do (#1503)")
    func printedPagesIgnoresAStartFromAnotherPagination() async throws {
        // d2 numbers its pages from 1, but its first break follows its heading, so the page in
        // effect when it began is d1's last, 7, of another numbering — as at 20 out-of-order
        // breaks in the printed volumes of 1948–51. Three more documents follow in order, so the
        // volume is a printed one: one restart in five documents (#1503 review round 1).
        let store = try Self.makeOrderedStore([
            ("v1", "d1", "5", ["6", "7"]),
            ("v1", "d2", "7", ["1", "2"]),
            ("v1", "d3", "3", ["4"]),
            ("v1", "d4", "5", []),
            ("v1", "d5", "6", []),
        ])
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 1...2)
        // The control: a start its breaks do not run below places the document.
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == 5...7)
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == 5...5)
    }

    @Test("PageRangeStoreTest: in a volume that numbers its pages per document, a start other than page 1 places nothing, and every page-only answer is ambiguous (#1503 review round 1)")
    func perDocumentVolumePlacesOnlyFromPageOne() async throws {
        // frus1969-76ve05p1's shapes: d1's page 1 before its div, d2's inside after its heading,
        // d3 with no break of its own after d2 (d239 after d238), d4 one page, inside.
        let store = try Self.makeOrderedStore([
            ("v1", "d1", "1", ["2", "3"]),
            ("v1", "d2", "3", ["1", "2"]),
            ("v1", "d3", "2", []),
            ("v1", "d4", "2", ["1"]),
        ])
        // d3's start is d2's page 2, in d2's numbering: nothing places d3, so a cited page is not
        // checked against it. Reading d3's rows alone, the store placed it on page 2.
        #expect(try await store.printedPages(forDocument: "d3", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == 1...3)
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 1...2)
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == 1...1)
        let two = try await store.documents(forPage: 2, inVolume: "v1")
        #expect(two?.documents.map(\.documentId) == ["d1", "d2"])
        #expect(two?.claim == .numberedPerDocument)
        let three = try await store.documents(forPage: 3, inVolume: "v1")
        #expect(three?.documents.map(\.documentId) == ["d1"])
        #expect(three?.isAmbiguous == true)
    }

    @Test("PageRangeStoreTest: printedPages is nil for a document nothing places — no arabic start and no arabic break of its own (#1474 review round 3, #1503)")
    func printedPagesIsNilWhenNothingPlacesTheDocument() async throws {
        let store = try Self.makeOrderedStore([
            ("v1", "d0", nil, []),          // no break before its text anywhere in the volume
            ("v1", "d1", "ii", []),         // it begins on a front-matter roman page
            ("v1", "d2", "3", []),          // the control: it begins on 3
            ("v1", "d3", nil, ["iii", "iv"]), // its breaks are none of them arabic
            ("v1", "d4", nil, ["iv", "5"]), // the control: one arabic break among roman ones
        ])
        #expect(try await store.printedPages(forDocument: "d0", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d1", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d2", inVolume: "v1") == 3...3)
        #expect(try await store.printedPages(forDocument: "d3", inVolume: "v1") == nil)
        #expect(try await store.printedPages(forDocument: "d4", inVolume: "v1") == 4...5)
        // And a document the index does not hold.
        #expect(try await store.printedPages(forDocument: "d9", inVolume: "v1") == nil)
    }
}
