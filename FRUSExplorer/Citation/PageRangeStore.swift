// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - PageRangeStore

/// Queries the `page_ranges` SQLite table to resolve page numbers to documents.
///
/// ## Section-aware span computation
/// FRUS volumes may restart page numbering between major sections (e.g., a
/// "Part 1" and "Part 2" with overlapping arabic numerals). The `section_id`
/// column groups pages within a section. When a volume shows no section
/// variation, all rows share the same `section_id` and the algorithm degrades
/// gracefully to a simple whole-volume span lookup.
///
/// ## Span definition
/// A document's "span" is the range from its first `<pb>` element to the page
/// immediately before the first `<pb>` of the next document within the same
/// section. This is computed at query time from the ordered `page_ranges` rows.
///
/// ## Log prefix
/// `[PageRangeStore]`
///
/// Version history:
///   1.0 — Session 30: initial implementation (table built in Session 09)
///   1.1 — Session 32: database opened with `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX`
///          directly in `init` (previously delegated to a private `openDatabase()` helper)
///   1.2 — Session 2026-07-05: the private `span(containing:in:)` now delegates to the
///          shared `PageSpanResolver.documentContaining(page:in:)` (extracted verbatim,
///          Session-162 max-page behaviour preserved) so the reader and the indexing-time
///          page-reference resolver (`IndexingPipeline.resolvePageBasedCrossReferences`)
///          share one algorithm and can never diverge. No behavioural change to this path.
///   1.3 — #1474 review round 2: `printedPages(forDocument:inVolume:)`, the pages a document may
///          be printed on — the rule Citation Lookup checks a cited page against, including for a
///          document with no page break of its own, which `pageRange(forDocument:inVolume:)` cannot
///          answer. It reads `document_cache` beside `page_ranges` (the two share one database)
///          for the order of the volume's documents.
///   1.4 — #1474 review round 3: `printedPages` never starts below page 1 — a document whose first
///          break is page 1 read "0–N"
public actor PageRangeStore {

    // MARK: - State

    private let databaseURL: URL
    private nonisolated(unsafe) var db: OpaquePointer?

    // MARK: - Init

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var dbPtr: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(databaseURL.path, &dbPtr, flags, nil)
        guard rc == SQLITE_OK else {
            throw PageRangeStoreError.databaseOpenFailed(code: rc)
        }
        // Wait up to 5 s instead of failing instantly with SQLITE_BUSY when a WAL
        // checkpoint or recovery briefly locks the file.
        sqlite3_busy_timeout(dbPtr, 5000)
        self.db = dbPtr
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Public API

    /// Returns the `documentId` whose page span contains `pageNumber` within `volumeId`.
    ///
    /// Uses section grouping to handle pagination restarts. Returns `nil` when:
    /// - No page range data exists for this volume
    /// - The page number falls outside all known spans
    /// - The volume uses non-arabic page numbers (roman-numeral front matter)
    ///
    /// A microfiche supplement's facsimile page numbers are recorded as arabic and restart with
    /// every document, so for one this would answer with any of the documents that carry the page,
    /// whichever it reaches first. Citation Lookup does not ask it about one
    /// (`CitationMatchingEngine.isMicroficheSupplement`, #1474 review round 3).
    public func document(forPage pageNumber: Int, inVolume volumeId: String) throws -> String? {
        guard let db else { return nil }

        // Fetch all arabic page rows for this volume ordered by section and page
        let sql = """
            SELECT document_id, section_id, page_number_int
            FROM page_ranges
            WHERE volume_id = ? AND page_number_type = 'arabic' AND page_number_int IS NOT NULL
            ORDER BY section_id, page_number_int, rowid
        """
        guard let stmt = prepare(sql, db: db) else { return nil }
        defer { sqlite3_finalize(stmt) }

        bind(text: volumeId, at: 1, stmt: stmt)

        // Group by section_id; within each section, rows are ordered by page number.
        // A document "owns" all pages from its first pb up to (but not including)
        // the first pb of the next document in the same section.
        var sections: [String: [(documentId: String, pageInt: Int)]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let docId   = string(at: 0, stmt: stmt)
            let section = string(at: 1, stmt: stmt)
            let page    = Int(sqlite3_column_int(stmt, 2))
            sections[section, default: []].append((docId, page))
        }

        if sections.isEmpty {
            #if DEBUG
            print("[PageRangeStore] no arabic page data for volume \(volumeId)")
            #endif
            return nil
        }

        for (_, rows) in sections {
            if let docId = span(containing: pageNumber, in: rows) {
                return docId
            }
        }

        return nil
    }

    /// Returns the (first, last) arabic page numbers for `documentId` in `volumeId`.
    ///
    /// Useful for displaying "pages X–Y" alongside a matched document.
    /// Returns `nil` when no arabic page range data exists for the document.
    public func pageRange(forDocument documentId: String, inVolume volumeId: String) throws -> (first: Int, last: Int)? {
        guard let db else { return nil }

        let sql = """
            SELECT MIN(page_number_int), MAX(page_number_int)
            FROM page_ranges
            WHERE volume_id = ? AND document_id = ?
              AND page_number_type = 'arabic' AND page_number_int IS NOT NULL
        """
        guard let stmt = prepare(sql, db: db) else { return nil }
        defer { sqlite3_finalize(stmt) }

        bind(text: volumeId, at: 1, stmt: stmt)
        bind(text: documentId, at: 2, stmt: stmt)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }

        let first = Int(sqlite3_column_int(stmt, 0))
        let last  = Int(sqlite3_column_int(stmt, 1))
        return (first, last)
    }

    /// The pages `documentId` of `volumeId` may be printed on, as far as the recorded page breaks
    /// can tell, or `nil` when they cannot tell (#1474 review round 2). Citation Lookup checks a
    /// cited page against it.
    ///
    /// The index records a page break only inside the document that contains it (one
    /// `page_ranges` row per `<pb>`, owned by its document), so:
    ///
    /// - **A document with arabic page breaks of its own** may be printed on the page before its
    ///   first break through its last break. The page it begins on, when it begins part-way down
    ///   a page, is the break before it — the previous document's, or one between the two — so
    ///   that page counts: a citation of the page a document begins on is the commonest way to
    ///   cite one. There is no page before page 1, so a document whose first break is page 1 may
    ///   be printed on pages 1 through its last (#1474 review round 3: the range, and the label
    ///   Citation Lookup draws from it, read "0–N" for such a document — 1,435 of the documents
    ///   the check reaches at corpus `550a8c5c5`).
    /// - **A document with no page break of its own** is printed on one page, the last break
    ///   before it, and that break is often recorded nowhere: it sits between two documents,
    ///   outside both. Over the local corpus at `550a8c5c5`, outside the five microfiche
    ///   supplements, 105,472 of 311,245 document divs carry no break, 122,637 breaks sit outside
    ///   every document div, and for 49,902 of those documents the last break the index records
    ///   before them is NOT the page they are on — so "the last recorded break before it" would
    ///   demote a correct citation almost half the time. The answer is a bound instead: from the
    ///   last break a document before it records to the page before the first break a document
    ///   after it records. Pagination runs forward, so the page it is on lies between them; the
    ///   measurement is in the #1474 entry of `Planning/DEVELOPMENT-PLAN.md`, review rounds 2
    ///   and 3.
    /// - **`nil`** when the document's own breaks are none of them arabic (front matter), when the
    ///   index does not hold the document, when either side of a no-break document has no arabic
    ///   break nearest it, or when that bound is empty — a pagination restart between the sides.
    ///
    /// "Before" and "after" are the order the volume's documents entered `document_cache` —
    /// source order when the volume was first indexed. **That is a limit.** A re-index keeps each
    /// surviving document's row and deletes the vanished ones, so a document a republished volume
    /// ADDS sorts last, not where it is printed. Take a surviving document with no break of its
    /// own, after which no surviving document with a break follows: its upper bound comes from
    /// the first newcomer with a break. When that newcomer is printed before it, the bound ends
    /// below the page it is on: a citation of its true page is reported as a best guess (or goes
    /// unchecked, when the bound empties), and a wrong page inside the shifted bound goes
    /// uncaught. It takes a republication that adds documents; and nothing else the index keeps
    /// says where a document with no break stands in source order (`page_ranges` is rewritten in
    /// source order on a re-index, but holds no row for it), so the order cannot be recovered here.
    public func printedPages(forDocument documentId: String,
                             inVolume volumeId: String) throws -> ClosedRange<Int>? {
        guard let db else { return nil }

        let ownSQL = """
            SELECT COUNT(*),
                   MIN(CASE WHEN page_number_type = 'arabic' THEN page_number_int END),
                   MAX(CASE WHEN page_number_type = 'arabic' THEN page_number_int END)
            FROM page_ranges
            WHERE volume_id = ? AND document_id = ?
        """
        guard let own = prepare(ownSQL, db: db) else { return nil }
        defer { sqlite3_finalize(own) }
        bind(text: volumeId, at: 1, stmt: own)
        bind(text: documentId, at: 2, stmt: own)
        guard sqlite3_step(own) == SQLITE_ROW else { return nil }

        if sqlite3_column_int(own, 0) > 0 {
            guard sqlite3_column_type(own, 1) != SQLITE_NULL else { return nil }
            let first = Int(sqlite3_column_int(own, 1))
            let last = Int(sqlite3_column_int(own, 2))
            // The page before the first break, except that no page precedes page 1.
            return (first > 1 ? first - 1 : first)...last
        }

        // No break of its own: the nearest recorded break on each side, in document order.
        guard let before = neighbouringBreak(of: documentId, inVolume: volumeId, after: false, db: db),
              let after = neighbouringBreak(of: documentId, inVolume: volumeId, after: true, db: db),
              before <= after - 1
        else {
            #if DEBUG
            print("[PageRangeStore] \(volumeId)/\(documentId) has no page break of its own and no arabic bound around it")
            #endif
            return nil
        }
        return before...(after - 1)
    }

    /// The arabic page of the recorded break nearest to `documentId` on one side — the last break
    /// of the nearest earlier document that has any, or the first break of the nearest later one
    /// — or `nil` when that side has none, or its nearest break is not arabic (a front-matter
    /// roman page, or a bracketed unnumbered one, neither of which the body's numbering can bound).
    private func neighbouringBreak(of documentId: String, inVolume volumeId: String,
                                   after: Bool, db: OpaquePointer) -> Int? {
        let sql = """
            SELECT pr.page_number_type, pr.page_number_int
            FROM document_cache dc
            JOIN page_ranges pr ON pr.volume_id = dc.volume_id AND pr.document_id = dc.document_id
            WHERE dc.volume_id = ?1
              AND dc.rowid \(after ? ">" : "<")
                  (SELECT rowid FROM document_cache WHERE volume_id = ?1 AND document_id = ?2)
            ORDER BY dc.rowid \(after ? "ASC" : "DESC"), pr.rowid \(after ? "ASC" : "DESC")
            LIMIT 1
        """
        guard let stmt = prepare(sql, db: db) else { return nil }
        defer { sqlite3_finalize(stmt) }
        bind(text: volumeId, at: 1, stmt: stmt)
        bind(text: documentId, at: 2, stmt: stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              string(at: 0, stmt: stmt) == "arabic",
              sqlite3_column_type(stmt, 1) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(stmt, 1))
    }

    // MARK: - Private Helpers

    /// Returns the documentId whose span contains `target`, or `nil` if none.
    ///
    /// Delegates to the shared ``PageSpanResolver/documentContaining(page:in:)`` so the
    /// reader (this store) and the indexing-time page-reference resolver
    /// (`IndexingPipeline.resolvePageBasedCrossReferences`) apply identical span logic.
    /// The shared resolver sorts internally, so passing rows already ordered by
    /// `page_number_int, rowid` (as the SQL query does) yields the same result.
    ///
    /// The span for document D is [D.firstPage, nextDoc.firstPage − 1]; the final
    /// document's span is **closed** at the section's highest recorded page
    /// (every printed page carries a `<pb>` marker, so the maximum row is the
    /// section's last real page).
    ///
    /// Session 162 link audit: the final span used to extend to `Int.max`, so a
    /// section whose pagination ends early (e.g. front matter ending at page 9)
    /// claimed every later page of the volume — and because sections are probed
    /// in dictionary order, page lookups could return a document from the wrong
    /// section entirely (p. 313 of frus1955-57v17 resolved to a page-9 document).
    private func span(containing target: Int, in rows: [(documentId: String, pageInt: Int)]) -> String? {
        PageSpanResolver.documentContaining(page: target, in: rows)
    }

    private func openDatabase() throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(databaseURL.path, &db, flags, nil)
        guard rc == SQLITE_OK else {
            throw PageRangeStoreError.databaseOpenFailed(code: rc)
        }
        // Wait up to 5 s instead of failing instantly with SQLITE_BUSY when a WAL
        // checkpoint or recovery briefly locks the file.
        sqlite3_busy_timeout(db, 5000)
    }

    private func prepare(_ sql: String, db: OpaquePointer) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        return stmt
    }

    private func bind(text: String, at index: Int32, stmt: OpaquePointer) {
        sqlite3_bind_text(stmt, index, (text as NSString).utf8String, -1, nil)
    }

    private func string(at column: Int32, stmt: OpaquePointer) -> String {
        guard let ptr = sqlite3_column_text(stmt, column) else { return "" }
        return String(cString: ptr)
    }
}

// MARK: - PageRangeStoreError

public enum PageRangeStoreError: Error, Sendable {
    case databaseOpenFailed(code: Int32)
    case queryFailed(description: String)
}
