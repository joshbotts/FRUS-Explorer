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
public actor PageRangeStore {

    // MARK: - State

    private let databaseURL: URL
    private var db: OpaquePointer?

    // MARK: - Init

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try openDatabase()
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
    /// - The volume uses non-arabic page numbers (microfiche, roman-numeral front matter)
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

    // MARK: - Private Helpers

    /// Returns the documentId whose span contains `target`, or `nil` if none.
    ///
    /// `rows` must be sorted by page number ascending (as provided by the SQL query).
    /// The span for document D is [D.firstPage, nextDoc.firstPage − 1].
    private func span(containing target: Int, in rows: [(documentId: String, pageInt: Int)]) -> String? {
        // Deduplicate: keep only first occurrence of each document (its first <pb>)
        var seen = Set<String>()
        var boundaries: [(documentId: String, firstPage: Int)] = []
        for row in rows {
            if seen.insert(row.documentId).inserted {
                boundaries.append((row.documentId, row.pageInt))
            }
        }
        guard !boundaries.isEmpty else { return nil }

        for i in 0..<boundaries.count {
            let start = boundaries[i].firstPage
            let end   = i + 1 < boundaries.count ? boundaries[i + 1].firstPage - 1 : Int.max
            if target >= start && target <= end {
                return boundaries[i].documentId
            }
        }
        return nil
    }

    private func openDatabase() throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(databaseURL.path, &db, flags, nil)
        guard rc == SQLITE_OK else {
            throw PageRangeStoreError.databaseOpenFailed(code: rc)
        }
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
