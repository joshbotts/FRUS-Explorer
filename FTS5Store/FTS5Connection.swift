// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - FTS5Connection
//
// FTS5Connection owns the raw SQLite database handle and exposes a thin,
// synchronous API used exclusively by FTS5Store (an actor). Because FTS5Store
// serialises all calls onto its actor executor, FTS5Connection itself does not
// need additional synchronisation.

/// Manages the lifecycle of a SQLite database connection for FTS5Store.
///
/// ## WAL Mode
/// Write-Ahead Logging is enabled immediately after opening the connection.
/// WAL allows readers and a single writer to proceed concurrently without
/// blocking each other, which is important for the indexing pipeline that runs
/// alongside live UI queries.
///
/// ## Thread Safety
/// FTS5Connection is not thread-safe. It is always accessed through `FTS5Store`,
/// which is an actor that serialises all database calls onto a single executor.
///
/// Version history:
///   1.0 — Session 03: initial implementation
final class FTS5Connection {

    private(set) var db: OpaquePointer?
    let databaseURL: URL

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        let path = databaseURL.path
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw FTS5Error.openFailed(path: path, message: msg)
        }
        self.db = h
        try enableWAL()
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - WAL

    private func enableWAL() throws {
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
    }

    // MARK: - Schema Creation

    /// Creates the FTS5 virtual table and auxiliary tables if they do not exist.
    ///
    /// ## Stemming Tokenizer Strategy
    /// The FTS5 schema uses the `unicode61` built-in tokenizer. Porter stemming is
    /// applied at the application layer:
    ///   - **Indexing**: `FTS5Store` stems each word in document text before insertion.
    ///   - **Querying**: `FTS5Query.toFTS5MatchExpression()` stems each keyword term.
    ///
    /// This gives equivalent search recall to a custom C tokenizer without requiring
    /// the `fts5.h` C header, which is not exposed in the macOS system SQLite headers.
    /// If snippet highlighting accuracy of un-stemmed terms becomes a priority in a
    /// future release, a C tokenizer shim target can be added to expose the FTS5 API.
    func createSchema(schema: FTS5Schema) throws {
        // Build the column list. UNINDEXED columns are not tokenized but are stored
        // for retrieval alongside search results.
        let columnDefs = schema.columns.map { col -> String in
            if FTS5Schema.unindexedColumns.contains(col) {
                return "\(col.rawValue) UNINDEXED"
            }
            return col.rawValue
        }.joined(separator: ",\n    ")

        // The tokenizer name in the schema is treated as a hint. If the registered
        // name is "frus_english" we substitute "unicode61" since registration requires
        // the fts5.h C API. Application-layer stemming compensates for this.
        let tokenizerName = schema.tokenizerName == "frus_english" ? "unicode61" : schema.tokenizerName

        var createSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS \(schema.tableName) USING fts5(
            \(columnDefs),
            tokenize = '\(tokenizerName)'
        )
        """
        if let content = schema.contentTable {
            createSQL = createSQL.replacingOccurrences(
                of: "tokenize = '\(tokenizerName)'",
                with: "content='\(content)', tokenize = '\(tokenizerName)'"
            )
        }

        do {
            try exec(createSQL)
        } catch {
            throw FTS5Error.schemaCreationFailed(message: "\(error)")
        }

        // Cross-reference edge table and page-range table are created by the
        // Session 09 indexing pipeline. FTS5Store only creates the FTS5 table here.
    }

    // MARK: - Execute Helpers

    /// Executes a SQL statement that returns no rows.
    func exec(_ sql: String) throws {
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errmsg)
            throw FTS5Error.sqliteError(code: rc, message: msg)
        }
    }

    /// Prepares a SQL statement for repeated execution.
    func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw FTS5Error.sqliteError(code: rc, message: msg)
        }
        return s
    }

    /// Steps a prepared statement, throwing on any result other than SQLITE_ROW or SQLITE_DONE.
    @discardableResult
    func step(_ stmt: OpaquePointer) throws -> Bool {
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_ROW { return true }
        if rc == SQLITE_DONE { return false }
        let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        throw FTS5Error.sqliteError(code: rc, message: msg)
    }

    // MARK: - Transaction Helpers

    func beginTransaction() throws { try exec("BEGIN") }
    func commitTransaction() throws { try exec("COMMIT") }
    func rollbackTransaction() { try? exec("ROLLBACK") }
}
