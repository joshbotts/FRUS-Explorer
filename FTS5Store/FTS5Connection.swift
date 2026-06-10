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
        // Wait up to 5 s for a competing writer instead of failing immediately with
        // SQLITE_BUSY. Multiple connections share this database file (FTS5Store,
        // IndexingPipeline's auxiliary connection, and the read-only stores); without
        // a busy timeout a write that collides with another connection's transaction
        // errors out instantly and the update is silently dropped by `try?` callers.
        try exec("PRAGMA busy_timeout = 5000")
        // Keep temporary structures (sort buffers, CTE materializations) in RAM.
        // Avoids the overhead of creating a transient temp-file for short-lived data.
        try exec("PRAGMA temp_store=MEMORY")
        // Increase page cache to 8 MB (negative value = kibibytes).
        // Reduces re-reads of hot FTS5 index and B-tree pages between queries.
        try exec("PRAGMA cache_size = -8000")
        // Map up to 128 MB of the database file into virtual address space.
        // Reads bypass the read() syscall entirely; the OS page cache handles
        // eviction. On 64-bit iOS/macOS this consumes virtual address space only
        // (not physical RSS) and is safe under memory pressure.
        try exec("PRAGMA mmap_size = 134217728")
    }

    // MARK: - Schema Creation

    /// Creates (or migrates) the FTS5 virtual table.
    ///
    /// ## Stemming Tokenizer Strategy
    /// The FTS5 schema uses the `unicode61` built-in tokenizer. Porter stemming is
    /// applied at the application layer:
    ///   - **Indexing**: `FTS5Store` stems each word in document text before insertion.
    ///   - **Querying**: `FTS5Query.toFTS5MatchExpression()` stems each keyword term.
    ///
    /// This gives equivalent search recall to a custom C tokenizer without requiring
    /// the `fts5.h` C header, which is not exposed in the macOS system SQLite headers.
    ///
    /// ## Migration (schema version 3)
    /// FTS5 virtual tables cannot be altered via `ALTER TABLE ADD COLUMN` — the
    /// statement is silently ignored by SQLite. When the `is_editorial_note` column
    /// (added in Session 38) is found to be absent from an existing `frus_documents`
    /// table, this method drops the table and recreates it with the correct schema.
    ///
    /// Migration state is tracked with `PRAGMA user_version` on the database file:
    ///   - 0 (default): schema predates version tracking; column presence is checked.
    ///   - 3 (current): schema is correct; no action needed.
    ///
    /// - Returns: `true` if the FTS5 table was dropped and recreated; `false` otherwise.
    ///   A `true` return means the caller should enqueue a full re-index of all
    ///   downloaded volumes so that `is_editorial_note` data is populated correctly.
    func createSchema(schema: FTS5Schema) throws -> Bool {
        let columnDefs = buildColumnDefs(for: schema)
        let tokenizerName = resolvedTokenizerName(for: schema)

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

        // Fast path: user_version = 3 means schema is already current.
        let version = userVersion()
        if version >= 3 { return false }

        // Detect missing column. A freshly created table has all columns, so this
        // only returns false for databases created before Session 38.
        let hasColumn = tableHasColumn("is_editorial_note", inTable: schema.tableName)
        if hasColumn {
            try setUserVersion(3)
            return false
        }

        // Column is absent — drop and recreate the FTS5 table.
        // Dropping a FTS5 virtual table also removes all its shadow tables
        // (`_data`, `_idx`, `_content`, `_docsize`, `_config`).
        try exec("DROP TABLE IF EXISTS \(schema.tableName)")
        try exec("""
        CREATE VIRTUAL TABLE \(schema.tableName) USING fts5(
            \(columnDefs),
            tokenize = '\(tokenizerName)'
        )
        """)
        try setUserVersion(3)

        #if DEBUG
        print("[FTS5Connection] Rebuilt \(schema.tableName): is_editorial_note was absent (schema v\(version) → 3)")
        #endif
        return true
    }

    // MARK: - Schema Helpers

    private func buildColumnDefs(for schema: FTS5Schema) -> String {
        schema.columns.map { col -> String in
            FTS5Schema.unindexedColumns.contains(col) ? "\(col.rawValue) UNINDEXED" : col.rawValue
        }.joined(separator: ",\n    ")
    }

    private func resolvedTokenizerName(for schema: FTS5Schema) -> String {
        // Substitute "unicode61" for "frus_english": the custom tokenizer name
        // requires the fts5.h C API which is not exposed in system SQLite headers.
        schema.tokenizerName == "frus_english" ? "unicode61" : schema.tokenizerName
    }

    /// Returns `true` if the named column exists in the named SQLite table.
    ///
    /// Uses `PRAGMA table_info`, which works on both regular tables and FTS5 virtual tables.
    func tableHasColumn(_ column: String, inTable table: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK,
              let s = stmt else { return false }
        defer { sqlite3_finalize(s) }
        while sqlite3_step(s) == SQLITE_ROW {
            // Column index 1 is `name` in PRAGMA table_info rows.
            if let ptr = sqlite3_column_text(s, 1), String(cString: ptr) == column { return true }
        }
        return false
    }

    /// Reads `PRAGMA user_version` from the database. Returns `0` if unavailable.
    func userVersion() -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil) == SQLITE_OK,
              let s = stmt else { return 0 }
        defer { sqlite3_finalize(s) }
        return sqlite3_step(s) == SQLITE_ROW ? Int(sqlite3_column_int64(s, 0)) : 0
    }

    /// Sets `PRAGMA user_version` on the database.
    ///
    /// `PRAGMA user_version` cannot be set with a bound parameter; the value is
    /// interpolated directly. Since `version` is an `Int` (not user input), there is
    /// no SQL injection risk.
    func setUserVersion(_ version: Int) throws {
        try exec("PRAGMA user_version = \(version)")
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
