// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
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
/// Porter stemming is applied at the application layer before text reaches SQLite:
///   - **Indexing**: `stemForIndex(_:)` stems each whitespace-delimited word in
///     document text before the string is bound to the INSERT statement.
///   - **Querying**: `FTS5Query.toFTS5MatchExpression()` stems each keyword term
///     before embedding it in the FTS5 MATCH expression.
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
public actor FTS5Store {

    private let connection: FTS5Connection
    private let schema: FTS5Schema

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

        #if DEBUG
        print("[FTS5Store] Opened database at \(databaseURL.path)")
        #endif
    }

    // MARK: - Insertion

    /// Inserts a single document into the FTS5 index.
    ///
    /// All indexed text fields are Porter-stemmed before insertion.
    /// Calling `insert` for a document whose `id` already exists will create a
    /// duplicate row; use `update` to replace an existing document.
    public func insert(document: FTS5Document) throws {
        let sql = insertSQL()
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(document: document, to: stmt)
        try connection.step(stmt)

        #if DEBUG
        print("[FTS5Store] Inserted document \(document.id) in volume \(document.volumeId)")
        #endif
    }

    /// Replaces an existing document in the FTS5 index.
    ///
    /// Implemented as `delete` + `insert`. FTS5 does not support in-place row
    /// updates via a stable rowid when `content=` is not used.
    public func update(document: FTS5Document) throws {
        try delete(documentId: document.id)
        try insert(document: document)

        #if DEBUG
        print("[FTS5Store] Updated document \(document.id)")
        #endif
    }

    /// Removes a document from the FTS5 index by its identifier.
    ///
    /// Uses the FTS5 `DELETE` extension syntax. If the document does not exist,
    /// the operation succeeds silently.
    public func delete(documentId: String) throws {
        let sql = "DELETE FROM \(schema.tableName) WHERE document_id = ?"
        let stmt = try connection.prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, documentId, -1, SQLITE_TRANSIENT)
        try connection.step(stmt)

        #if DEBUG
        print("[FTS5Store] Deleted document \(documentId)")
        #endif
    }

    /// Inserts a batch of documents in a single transaction.
    ///
    /// Using a transaction around bulk inserts is significantly faster than
    /// individual inserts because SQLite flushes WAL pages only on `COMMIT`.
    /// `optimize()` is called automatically after the batch to merge FTS5
    /// b-tree segments, improving subsequent query performance.
    ///
    /// - Parameter documents: One or more documents to insert. Must be non-empty.
    public func insertBatch(_ documents: [FTS5Document]) throws {
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

        try optimize()

        #if DEBUG
        print("[FTS5Store] Batch inserted \(documents.count) documents; optimize complete")
        #endif
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

        let sql = """
        SELECT
            document_id, volume_id, header, dateline, source_note,
            subject_tag_ids, user_tag_ids,
            snippet(\(schema.tableName), 6, '<b>', '</b>', '…', 3) AS snip,
            bm25(\(schema.tableName)) AS score,
            is_editorial_note
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
                documentId:   columnString(stmt, 0) ?? "",
                volumeId:     columnString(stmt, 1) ?? "",
                header:       columnString(stmt, 2) ?? "",
                dateline:     columnString(stmt, 3),
                sourceNote:   columnString(stmt, 4),
                snippet:      columnString(stmt, 7) ?? "",
                bm25Score:    sqlite3_column_double(stmt, 8),
                subjectTagIds: subjectIds,
                userTagIds:   userIds,
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

    // MARK: - Maintenance

    /// Runs the FTS5 `optimize` command to merge b-tree segments.
    ///
    /// Should be called after any bulk insert. The operation can be slow on large
    /// indexes; run it on a background task when the index is not actively queried.
    /// `insertBatch` calls this automatically.
    public func optimize() throws {
        try connection.exec("INSERT INTO \(schema.tableName)(\(schema.tableName)) VALUES('optimize')")
        #if DEBUG
        print("[FTS5Store] optimize complete")
        #endif
    }

    /// Rebuilds the entire FTS5 index from its content shadow tables.
    ///
    /// Equivalent to dropping and recreating the index. Use after detecting index
    /// corruption or after a schema migration. This is a slow, blocking operation
    /// and should be run on a background task.
    public func rebuild() throws {
        try connection.exec("INSERT INTO \(schema.tableName)(\(schema.tableName)) VALUES('rebuild')")
        #if DEBUG
        print("[FTS5Store] rebuild complete")
        #endif
    }

    /// Returns the size of the database file in bytes.
    ///
    /// Used by the Settings storage management UI to display the search index size.
    public func storageSize() throws -> Int {
        let path = connection.databaseURL.path
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return (attrs[.size] as? Int) ?? 0
    }

    // MARK: - Application-Layer Stemming

    /// Stems a body-text string for insertion into the FTS5 index.
    ///
    /// Splits on whitespace, lowercases each word, applies Porter stemming, and
    /// rejoins. Non-alphabetic tokens (numbers, punctuation fragments) are preserved
    /// as-is to ensure numeric references and dates remain searchable.
    ///
    /// This function is `nonisolated` so callers can stem text concurrently
    /// before calling the isolated `insert` / `insertBatch` methods.
    nonisolated public func stemForIndex(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .map { token -> String in
                let lower = String(token).lowercased()
                // Strip non-ASCII-alphabetic characters (trailing periods, hyphens, etc.)
                // to get the word's alphabetic core for Porter stemming. Tokens with no
                // alphabetic content (e.g. "1969-76") are passed through as-is so numeric
                // references remain searchable via FTS5's own tokenizer.
                let alpha = lower.filter { ($0.asciiValue ?? 0) >= 97 && ($0.asciiValue ?? 0) <= 122 }
                guard !alpha.isEmpty else { return lower }
                return PorterStemmer.stem(alpha)
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Private Helpers

    private func insertSQL() -> String {
        let cols = schema.columns.map(\.rawValue).joined(separator: ", ")
        let placeholders = schema.columns.map { _ in "?" }.joined(separator: ", ")
        return "INSERT INTO \(schema.tableName) (\(cols)) VALUES (\(placeholders))"
    }

    private func bind(document doc: FTS5Document, to stmt: OpaquePointer) {
        // Column order must match FTS5Column.allCases
        sqlite3_bind_text(stmt, 1,  doc.id,                        -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2,  doc.volumeId,                  -1, SQLITE_TRANSIENT)
        bindOptional(stmt, 3,  doc.documentNumber)
        sqlite3_bind_text(stmt, 4,  stemForIndex(doc.header),      -1, SQLITE_TRANSIENT)
        bindOptional(stmt, 5,  doc.dateline.map { stemForIndex($0) })
        bindOptional(stmt, 6,  doc.sourceNote.map { stemForIndex($0) })
        sqlite3_bind_text(stmt, 7,  stemForIndex(doc.bodyText),    -1, SQLITE_TRANSIENT)
        bindOptional(stmt, 8,  doc.subjectTagIds)
        bindOptional(stmt, 9,  doc.userTagIds)
        bindOptional(stmt, 10, doc.summaryText.map { stemForIndex($0) })
        bindOptional(stmt, 11, doc.noteText.map { stemForIndex($0) })
        sqlite3_bind_int(stmt, 12, doc.isEditorialNote ? 1 : 0)
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
            #if DEBUG
            print("[FTS5Store] Warning: could not set isExcludedFromBackupKey on \(url.path): \(error)")
            #endif
        }
    }
}
