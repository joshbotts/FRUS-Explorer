// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import OSLog
import SQLite3

// SQLITE_TRANSIENT is a C macro ((sqlite3_destructor_type)-1) not exposed in Swift's
// SQLite3 module. It tells SQLite to copy the string immediately rather than hold a
// pointer, which is required whenever the Swift string's storage may be released.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - FTS5Store

/// Full-text search store for FRUS documents, backed by SQLite FTS5.
///
/// ## Design
/// `FTS5Store` is an actor. All SQLite calls are serialised onto the actor's
/// executor, satisfying SQLite's single-threaded connection requirement without
/// additional locks. The async/await interface is compatible with Swift 6 strict
/// concurrency (`Sendable` types throughout).
///
/// ## Stemming
/// Stemming is performed by SQLite's built-in `porter unicode61` tokenizer,
/// symmetrically at index and query time. Stored column values are the original
/// (unstemmed) text, so values returned by `search` are display-quality.
///
/// ## External-Content Schemas
/// When the schema declares a `contentTable`, the FTS5 table holds only the
/// inverted index; rows are maintained by SQL triggers on the content table (see
/// `FTS5Schema.externalContentTriggerSQL()`). The write methods on this store
/// (`insert`, `insertBatch`, `update`, `delete`, `deleteVolume`, `deleteAll`)
/// throw `FTS5Error.externalContentWrite` — write to the content table instead.
///
/// ## Usage
/// ```swift
/// let store = try await FTS5Store(
///     databaseURL: url,
///     schema: .frusDocuments
/// )
/// try await store.insert(document: doc)
/// let results = try await store.search(
///     query: FTS5Query(keywords: ["negotiate"]),
///     limit: 20,
///     offset: 0
/// )
/// ```
///
/// ## Reuse
/// `FTS5Store` is designed for reuse outside FRUS Explorer. Pass a custom
/// `FTS5Schema` to control the table name and tokenizer.
///
/// Version history:
///   1.0 — Session 03: initial implementation
///   1.1 — Session 98: added `matchedDocumentKeys(query:limit:)` for analytics
///   1.2 — Session 118: removed automatic `optimize()` from `insertBatch()`;
///          callers are now responsible for calling `optimize()` once per batch;
///          `#if DEBUG` prints replaced with `os.Logger`
///   1.3 — Session 119: `matchedDocumentKeys` default limit raised from 20,000 to
///          500,000 so corpus-wide analytics cover the full FRUS series for high-frequency
///          terms like "security" or "rights". (That entry said "~83,000 docs maximum"; the
///          measured corpus is 316,839 documents — see `matchedDocumentKeys`.)
///   1.4 — Session 123: `search` no longer calls `snippet()`. FTS5's `snippet()`
///          function traversed the inverted index and extracted context per row, but
///          `SearchService` replaced every snippet with TEI-derived body text anyway.
///          Skipping it eliminates the most expensive per-row operation for large
///          result sets. `FTS5Result.snippet` now carries an empty string; callers
///          that care about snippets (e.g. `SearchService`) must supply their own.
///   1.5 — Session 2026-06-09: `delete(documentId:)` replaced by
///          `delete(documentId:volumeId:)`. FRUS document IDs (e.g. "d1") repeat in
///          every volume, so the unscoped delete removed rows from all volumes —
///          every summary/note/tag update and every per-document volume removal
///          silently corrupted the index for other volumes.
///   2.0 — Session 2026-06-09: external-content redesign. Application-layer Porter
///          stemming removed (`stemForIndex` deleted); the `porter unicode61`
///          tokenizer stems inside SQLite and stored values stay unstemmed. Write
///          methods throw `FTS5Error.externalContentWrite` for external-content
///          schemas — index maintenance happens via content-table triggers.
public actor FTS5Store {

    // Module-internal rather than private so `FTS5Vocabulary.swift`'s extension can
    // reach them. Still invisible outside the FTS5Store module.
    let connection: FTS5Connection
    let schema: FTS5Schema
    private let logger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "FTS5Store")

    /// `true` if the FTS5 virtual table was dropped and recreated on this launch
    /// because the `is_editorial_note` column was absent (schema migration from
    /// pre–Session 38 databases).
    ///
    /// Immutable after `init`; safe to read from any concurrency context without
    /// `await`. When `true`, the caller should trigger a full re-index of all
    /// downloaded volumes so that `is_editorial_note` data is populated correctly.
    public nonisolated let didRebuildSchema: Bool

    // MARK: - Initialisation

    /// Opens (or creates) the SQLite database at `databaseURL` and creates (or
    /// migrates) the FTS5 virtual table.
    ///
    /// The database file is excluded from iCloud Backup immediately after creation
    /// via `isExcludedFromBackupKey`. This exclusion is silent (non-fatal) if the
    /// resource value cannot be set.
    ///
    /// - Parameters:
    ///   - databaseURL: File URL for the SQLite database. Parent directory must exist.
    ///   - schema: FTS5 table definition. Defaults to `FTS5Schema.frusDocuments`.
    public init(databaseURL: URL, schema: FTS5Schema = .frusDocuments) throws {
        self.schema = schema
        self.connection = try FTS5Connection(databaseURL: databaseURL)
        self.didRebuildSchema = try connection.createSchema(schema: schema)
        FTS5Store.excludeFromBackup(url: databaseURL)

        logger.debug("Opened database at \(databaseURL.path, privacy: .public)")
    }

    // MARK: - Insertion

    /// Throws `FTS5Error.externalContentWrite` when this store's schema is an
    /// external-content table. Rows of external-content tables are maintained by
    /// triggers on the content table; writing through the FTS5 table directly
    /// would desynchronise the index from the content.
    private func requireStandardSchema() throws {
        if schema.contentTable != nil {
            throw FTS5Error.externalContentWrite(tableName: schema.tableName)
        }
    }

    /// Inserts a single document into the FTS5 index.
    ///
    /// Text is stored as-is; the `porter unicode61` tokenizer stems at index time.
    /// Calling `insert` for a document whose `id` already exists will create a
    /// duplicate row; use `update` to replace an existing document.
    ///
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas.
    public func insert(document: FTS5Document) throws {
        try requireStandardSchema()
        let sql = insertSQL()
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(document: document, to: stmt)
        try connection.step(stmt)

        logger.debug("Inserted document \(document.id, privacy: .public) in volume \(document.volumeId, privacy: .public)")
    }

    /// Replaces an existing document in the FTS5 index.
    ///
    /// Implemented as `delete` + `insert`. FTS5 does not support in-place row
    /// updates via a stable rowid when `content=` is not used. The delete is
    /// scoped to the document's `volumeId` — FRUS document IDs (e.g. `"d1"`)
    /// repeat in every volume, so an unscoped delete would remove rows from
    /// other volumes.
    ///
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas.
    public func update(document: FTS5Document) throws {
        try requireStandardSchema()
        try delete(documentId: document.id, volumeId: document.volumeId)
        try insert(document: document)

        logger.debug("Updated document \(document.volumeId, privacy: .public)/\(document.id, privacy: .public)")
    }

    /// Removes a single document from the FTS5 index.
    ///
    /// The delete is scoped by both `documentId` and `volumeId` because FRUS
    /// document IDs (e.g. `"d1"`) are only unique within a volume — an unscoped
    /// `document_id` delete would silently remove matching rows from every
    /// indexed volume. If the document does not exist, the operation succeeds
    /// silently.
    ///
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas.
    public func delete(documentId: String, volumeId: String) throws {
        try requireStandardSchema()
        let sql = "DELETE FROM \(schema.tableName) WHERE document_id = ? AND volume_id = ?"
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, volumeId, -1, SQLITE_TRANSIENT)
        try connection.step(stmt)

        logger.debug("Deleted document \(volumeId, privacy: .public)/\(documentId, privacy: .public)")
    }

    /// Removes all FTS5 rows belonging to a given volume.
    ///
    /// Called before re-indexing a volume so that a second pass does not produce
    /// duplicate search results. Document IDs (e.g. "d1") are not globally unique
    /// across volumes, so this delete must be scoped by `volume_id`.
    ///
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas.
    public func deleteVolume(volumeId: String) throws {
        try requireStandardSchema()
        let sql = "DELETE FROM \(schema.tableName) WHERE volume_id = ?"
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, volumeId, -1, SQLITE_TRANSIENT)
        try connection.step(stmt)

        logger.debug("Deleted volume \(volumeId, privacy: .public)")
    }

    /// Inserts a batch of documents in a single transaction.
    ///
    /// Using a transaction around bulk inserts is significantly faster than
    /// individual inserts because SQLite flushes WAL pages only on `COMMIT`.
    ///
    /// **Important**: `optimize()` is NOT called automatically. For bulk corpus
    /// indexing, call `optimize()` exactly once after all volumes are inserted —
    /// calling it after every volume is O(n²) on the total index size.
    ///
    /// - Parameter documents: One or more documents to insert. Must be non-empty.
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas.
    public func insertBatch(_ documents: [FTS5Document]) throws {
        try requireStandardSchema()
        guard !documents.isEmpty else { throw FTS5Error.emptyBatch }

        let sql = insertSQL()
        try connection.beginTransaction()
        do {
            let stmt = try connection.prepare(sql)
            defer { sqlite3_finalize(stmt) }
            for doc in documents {
                bind(document: doc, to: stmt)
                try connection.step(stmt)
                sqlite3_reset(stmt)
            }
            try connection.commitTransaction()
        } catch {
            connection.rollbackTransaction()
            throw error
        }

        logger.debug("Batch inserted \(documents.count, privacy: .public) documents into \(self.schema.tableName, privacy: .public)")
    }

    // MARK: - Search

    /// Executes a full-text search and returns ranked results.
    ///
    /// Results are ordered by BM25 score (lower = more relevant). Results whose
    /// `subject_tag_ids` or `user_tag_ids` do not match the query's tag filters
    /// are excluded in post-processing after the FTS5 query returns.
    ///
    /// - Parameters:
    ///   - query: Structured search parameters.
    ///   - limit: Maximum results to return (applied after tag filtering).
    ///   - offset: Number of results to skip (for pagination).
    /// - Returns: Array of results ordered by relevance.
    public func search(query: FTS5Query, limit: Int, offset: Int) throws -> [FTS5Result] {
        guard let matchExpr = query.toFTS5MatchExpression() else {
            throw FTS5Error.emptyQuery
        }

        // Note: snippet() is intentionally omitted. SearchService replaces every
        // FTS5 snippet with TEI-derived body text via documentBodyTextsAndDates(),
        // making snippet() pure overhead. Column 7 (snip) is a fixed empty string
        // so the column offsets of subsequent result-row bindings are unchanged.
        // Column ordering (0-based):
        //   0  document_id
        //   1  volume_id
        //   2  header
        //   3  dateline
        //   4  source_note
        //   5  subject_tag_ids
        //   6  user_tag_ids
        //   7  snip (always '')
        //   8  score (bm25)
        //   9  is_editorial_note
        //  10  document_number
        //
        // document_number is appended last so existing column indices are unchanged.
        let sql = """
        SELECT
            document_id, volume_id, header, dateline, source_note,
            subject_tag_ids, user_tag_ids,
            '' AS snip,
            bm25(\(schema.tableName)) AS score,
            is_editorial_note,
            document_number
        FROM \(schema.tableName)
        WHERE \(schema.tableName) MATCH ?
        ORDER BY score
        LIMIT \(limit + 200)
        OFFSET \(offset)
        """

        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, matchExpr, -1, SQLITE_TRANSIENT)

        var results: [FTS5Result] = []
        while try connection.step(stmt) {
            let rawSubjectIds = columnString(stmt, 5)
            let rawUserIds    = columnString(stmt, 6)
            let subjectIds    = FTS5Result.splitTagIds(rawSubjectIds)
            let userIds       = FTS5Result.splitTagIds(rawUserIds)

            // Tag filter post-processing
            if let tagId = query.subjectTagId, !subjectIds.contains(tagId) { continue }
            if let tagId = query.userTagId,    !userIds.contains(tagId)    { continue }

            let result = FTS5Result(
                documentId:     columnString(stmt, 0) ?? "",
                volumeId:       columnString(stmt, 1) ?? "",
                documentNumber: columnString(stmt, 10),
                header:         columnString(stmt, 2) ?? "",
                dateline:       columnString(stmt, 3),
                sourceNote:     columnString(stmt, 4),
                snippet:        columnString(stmt, 7) ?? "",
                bm25Score:      sqlite3_column_double(stmt, 8),
                subjectTagIds:  subjectIds,
                userTagIds:     userIds,
                isEditorialNote: sqlite3_column_int(stmt, 9) != 0
            )
            results.append(result)
            if results.count >= limit { break }
        }
        return results
    }

    /// Returns the total number of documents matching the query (for pagination UI).
    public func searchCount(query: FTS5Query) throws -> Int {
        guard let matchExpr = query.toFTS5MatchExpression() else {
            throw FTS5Error.emptyQuery
        }
        let sql = "SELECT COUNT(*) FROM \(schema.tableName) WHERE \(schema.tableName) MATCH ?"
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, matchExpr, -1, SQLITE_TRANSIENT)
        guard try connection.step(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Returns (documentId, volumeId) pairs for all documents matching the query.
    ///
    /// Unlike `search(query:limit:offset:)`, this method omits `snippet()` and
    /// `bm25()` calls, making it significantly cheaper for analytics workloads
    /// that need document identifiers but not ranked snippets.
    ///
    /// - Parameters:
    ///   - query: Structured search parameters.
    ///   - limit: Hard cap on returned rows. Defaults to 500,000. One row per matching document, so
    ///     the ceiling that matters is the corpus size: **316,839 documents** across 552 volumes,
    ///     measured 2026-07-30 (`SELECT COUNT(*) FROM document_cache` on the full local index). The
    ///     cap therefore cannot be reached today — but the margin is 1.58×, not the ~6× the previous
    ///     "~83,000 documents" figure implied, and that figure was wrong by 3.8×. If the corpus grows
    ///     past 500,000 this silently truncates the match set, which for analytics means a chart that
    ///     under-reports without saying so. Pass a smaller value only when a hard upper bound is
    ///     intentionally required.
    /// - Returns: Array of (documentId, volumeId) tuples in FTS5 scan order.
    public func matchedDocumentKeys(query: FTS5Query, limit: Int = 500_000) throws -> [(documentId: String, volumeId: String)] {
        guard let matchExpr = query.toFTS5MatchExpression() else {
            throw FTS5Error.emptyQuery
        }
        let sql = """
        SELECT document_id, volume_id
        FROM \(schema.tableName)
        WHERE \(schema.tableName) MATCH ?
        LIMIT \(limit)
        """
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, matchExpr, -1, SQLITE_TRANSIENT)
        var results: [(documentId: String, volumeId: String)] = []
        while try connection.step(stmt) {
            let docId = columnString(stmt, 0) ?? ""
            let volId = columnString(stmt, 1) ?? ""
            guard !docId.isEmpty, !volId.isEmpty else { continue }
            results.append((documentId: docId, volumeId: volId))
        }
        return results
    }

    // MARK: - Maintenance

    /// Runs the FTS5 `optimize` command to merge b-tree segments.
    ///
    /// This operation is O(total index size) — it merges ALL b-tree segments into one.
    /// For a full 552-volume corpus, this takes tens of seconds. Call it **once** after
    /// all volumes have been inserted; never call it inside a per-volume loop.
    ///
    /// The operation is logged with elapsed time so you can observe it in Console.app
    /// (`subsystem: bottsywattsy.FRUS-Explorer`, `category: FTS5Store`).
    public func optimize() throws {
        let start = Date()
        logger.info("optimize: starting on \(self.schema.tableName, privacy: .public)")
        try connection.exec("INSERT INTO \(schema.tableName)(\(schema.tableName)) VALUES('optimize')")
        let elapsed = Date().timeIntervalSince(start)
        logger.info("optimize: complete in \(String(format: "%.1f", elapsed), privacy: .public)s on \(self.schema.tableName, privacy: .public)")
    }

    /// Deletes every document from the FTS5 index in a single SQL statement.
    ///
    /// Use this instead of calling `delete(documentId:volumeId:)` in a loop when
    /// resetting all data — one statement is orders of magnitude faster than
    /// per-document deletes.
    ///
    /// - Throws: `FTS5Error.externalContentWrite` for external-content schemas
    ///   (delete the content-table rows instead, or use the FTS5 `delete-all`
    ///   command with triggers disabled).
    public func deleteAll() throws {
        try requireStandardSchema()
        try connection.exec("DELETE FROM \(schema.tableName)")
        logger.info("deleteAll complete on \(self.schema.tableName, privacy: .public)")
    }

    /// Rebuilds the entire FTS5 index from its content shadow tables.
    ///
    /// Equivalent to dropping and recreating the index. Use after detecting index
    /// corruption or after a schema migration. This is a slow, blocking operation
    /// and should be run on a background task.
    public func rebuild() throws {
        let start = Date()
        logger.info("rebuild: starting on \(self.schema.tableName, privacy: .public)")
        try connection.exec("INSERT INTO \(schema.tableName)(\(schema.tableName)) VALUES('rebuild')")
        let elapsed = Date().timeIntervalSince(start)
        logger.info("rebuild: complete in \(String(format: "%.1f", elapsed), privacy: .public)s on \(self.schema.tableName, privacy: .public)")
    }

    /// Returns the size of the database file in bytes.
    ///
    /// Used by the Settings storage management UI to display the search index size.
    public func storageSize() throws -> Int {
        let path = connection.databaseURL.path
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return (attrs[.size] as? Int) ?? 0
    }

    // MARK: - Private Helpers

    private func insertSQL() -> String {
        let cols = schema.columns.map(\.rawValue).joined(separator: ", ")
        let placeholders = schema.columns.map { _ in "?" }.joined(separator: ", ")
        return "INSERT INTO \(schema.tableName) (\(cols)) VALUES (\(placeholders))"
    }

    private func bind(document doc: FTS5Document, to stmt: OpaquePointer) {
        // Text is bound as-is; the porter tokenizer stems at index time.
        // Bind positions follow the schema's column order. Standard schemas only —
        // external-content schemas reject writes before reaching this point.
        for (i, column) in schema.columns.enumerated() {
            let position = Int32(i + 1)
            switch column {
            case .documentId:      sqlite3_bind_text(stmt, position, doc.id, -1, SQLITE_TRANSIENT)
            case .volumeId:        sqlite3_bind_text(stmt, position, doc.volumeId, -1, SQLITE_TRANSIENT)
            case .documentNumber:  bindOptional(stmt, position, doc.documentNumber)
            case .header:          sqlite3_bind_text(stmt, position, doc.header, -1, SQLITE_TRANSIENT)
            case .dateline:        bindOptional(stmt, position, doc.dateline)
            case .sourceNote:      bindOptional(stmt, position, doc.sourceNote)
            case .bodyText:        sqlite3_bind_text(stmt, position, doc.bodyText, -1, SQLITE_TRANSIENT)
            case .subjectTagIds:   bindOptional(stmt, position, doc.subjectTagIds)
            case .userTagIds:      bindOptional(stmt, position, doc.userTagIds)
            case .summaryText:     bindOptional(stmt, position, doc.summaryText)
            case .noteText:        bindOptional(stmt, position, doc.noteText)
            case .isEditorialNote: sqlite3_bind_int(stmt, position, doc.isEditorialNote ? 1 : 0)
            }
        }
    }

    private func bindOptional(_ stmt: OpaquePointer, _ col: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, col, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, col)
        }
    }

    private func columnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }

    private static func excludeFromBackup(url: URL) {
        do {
            try (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        } catch {
            // Non-fatal: log and continue. The database is still usable; the only
            // consequence is that it may be included in iCloud Backup until the
            // next successful open.
            let logger = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "FTS5Store")
            logger.warning("Could not set isExcludedFromBackupKey on \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
