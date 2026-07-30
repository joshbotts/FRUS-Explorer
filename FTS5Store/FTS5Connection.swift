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

    /// The current schema generation, tracked with `PRAGMA user_version`.
    ///
    /// - 0–2: pre-version-tracking databases (application-layer stemming, standard
    ///   FTS5 table, possibly missing `is_editorial_note`).
    /// - 3: `is_editorial_note` column present (Session 48 migration).
    /// - 4: external-content redesign (Session 2026-06-09) — `frus_documents` is an
    ///   external-content table over `document_cache` using the built-in
    ///   `porter unicode61` tokenizer, and user text lives in `user_content`.
    static let currentSchemaGeneration = 4

    /// Creates (or migrates) the FTS5 virtual table.
    ///
    /// ## Tokenizer Strategy (generation 4)
    /// The schema uses SQLite's built-in `porter unicode61` tokenizer. Stemming
    /// happens inside FTS5 symmetrically at index and query time, so stored column
    /// values remain the *original* text. The previous application-layer Porter
    /// stemming (which stored stemmed text and required `document_cache` lookups to
    /// repair display values) is gone.
    ///
    /// ## Migration
    /// Migration state is tracked with `PRAGMA user_version`:
    /// - `user_version >= 4`: schema is current; the table is created with
    ///   `IF NOT EXISTS` and nothing else happens.
    /// - `user_version < 4` **and the table already exists**: the table predates the
    ///   external-content redesign (its shadow tables hold app-layer-stemmed text).
    ///   It is dropped and recreated; the method returns `true` so the caller can
    ///   rebuild the index from the content table (no XML re-parse is required —
    ///   `document_cache` already holds the original text).
    /// - `user_version < 4` and the table does not exist: fresh database; the table
    ///   is created and the version stamped without signalling a rebuild.
    ///
    /// FTS5 virtual tables cannot be altered with `ALTER TABLE`, which is why every
    /// schema change is a drop-and-recreate. Dropping an FTS5 table also removes its
    /// shadow tables (`_data`, `_idx`, `_content`, `_docsize`, `_config`).
    ///
    /// - Returns: `true` if an existing FTS5 table was dropped and recreated; the
    ///   caller should rebuild the index contents (for external-content schemas, via
    ///   the FTS5 `rebuild` command against the populated content table).
    func createSchema(schema: FTS5Schema) throws -> Bool {
        let version = userVersion()

        if version >= Self.currentSchemaGeneration {
            do {
                try exec(schema.createTableSQL(ifNotExists: true))
                try exec(schema.createVocabTableSQL(ifNotExists: true))
            } catch {
                throw FTS5Error.schemaCreationFailed(message: "\(error)")
            }
            return false
        }

        let existed = tableExists(schema.tableName)
        do {
            if existed {
                // The vocab table goes first. SQLite does not cascade: dropping
                // `frus_documents` while `frus_documents_vocab` survives leaves a table
                // that fails every query with "no such fts5 table" (verified — the error
                // surfaces at SELECT, not at DROP, because `fts5vocab` resolves its
                // source by name at query time).
                //
                // Being precise about what this ordering does and does not buy: because
                // the source table is recreated under the same name three lines below,
                // that dangling state would heal itself here anyway, and `createSchema`
                // is the only place in the app that drops this table at all. So this is
                // defensive ordering that keeps the two objects' lifetimes coupled — not
                // a fix for a failure the current code paths can reach. Written down so
                // nobody later "simplifies" it believing it was load-bearing, and so
                // nobody believes it is tested more deeply than it is.
                try exec("DROP TABLE IF EXISTS \(schema.vocabTableName)")
                try exec("DROP TABLE IF EXISTS \(schema.tableName)")
            }
            try exec(schema.createTableSQL(ifNotExists: true))
            try exec(schema.createVocabTableSQL(ifNotExists: true))
        } catch {
            throw FTS5Error.schemaCreationFailed(message: "\(error)")
        }
        try setUserVersion(Self.currentSchemaGeneration)

        #if DEBUG
        if existed {
            print("[FTS5Connection] Rebuilt \(schema.tableName) for schema generation \(Self.currentSchemaGeneration) (was v\(version))")
        }
        #endif
        return existed
    }

    // MARK: - Stem Probe

    /// Whether the scratch tokenizing tables have been created on this connection.
    private var stemProbeReady = false

    /// Whether the temp instance-mode `fts5vocab` companion exists on this connection.
    private var instanceVocabReady = false

    /// Creates the scratch tables that let us ask SQLite what a word tokenizes to.
    ///
    /// Two `temp`-schema virtual tables: a one-column FTS5 table declared with the
    /// *caller's* tokenizer, and an `fts5vocab` view over it. Writing a word into the
    /// first and reading the second returns the exact term FTS5 wrote to its index.
    ///
    /// They live in `temp` so they never touch the on-disk database, vanish with the
    /// connection, and cannot collide with a real table name. They are created once and
    /// reused: emptying and refilling the probe is a two-statement round trip, whereas
    /// creating and dropping a virtual table per lookup would not be.
    func ensureStemProbe(tokenizer: String) throws {
        guard !stemProbeReady else { return }
        try exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS temp.fts5_stem_probe \
            USING fts5(t, tokenize = '\(tokenizer)')
            """)
        try exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS temp.fts5_stem_probe_vocab \
            USING fts5vocab('fts5_stem_probe', 'row')
            """)
        stemProbeReady = true
    }

    /// Creates the per-connection `fts5vocab` companion in **`instance`** mode, once.
    ///
    /// Instance mode yields one row per posting — `(term, doc, col, offset)` — where `doc` is the
    /// content rowid. `row` mode, which the persistent `…_vocab` table uses, is a set: one row per
    /// term for the whole index, with no document and no position. So `row` mode can say "this stem
    /// occurs 92 times in the corpus" and can never say "…in documents dated 1949". Instance mode is
    /// the only route to a scoped or dated occurrence count.
    ///
    /// ## Why `temp.`, and why this needs no migration
    /// `fts5vocab` stores nothing — it is a view over the FTS5 index. So a companion in the **temp**
    /// database is exactly as capable as one in `main`, costs 6 ms to create (measured on the real
    /// 6.3 GB index), and cannot outlive its connection. That last property is the point: a
    /// persistent companion would need a schema-generation bump, a DDL site, a matching DROP ordered
    /// against the source table's lifetime, and it would go stale the moment the FTS5 table was
    /// dropped and rebuilt — the failure pattern of #275. None of that exists here.
    ///
    /// Requires the source table's schema to store positions (no `detail=none`/`columnsize=0`),
    /// which `FTS5Schema.frusDocuments` does.
    ///
    /// - Parameter tableName: the FTS5 table to read, in `main`.
    func ensureInstanceVocab(tableName: String) throws {
        guard !instanceVocabReady else { return }
        try exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS temp.\(Self.instanceVocabTableName) \
            USING fts5vocab('main', '\(tableName)', 'instance')
            """)
        instanceVocabReady = true
    }

    /// Name of the temp instance-mode companion created by ``ensureInstanceVocab(tableName:)``.
    static let instanceVocabTableName = "fts5_instance_vocab"

    /// Returns the index terms SQLite's tokenizer produces for `text`.
    ///
    /// The probe is emptied first and after, so a lookup can never be contaminated by
    /// the previous one — a leftover row would silently add its terms to this answer.
    /// `ensureStemProbe` must have been called.
    func stems(of text: String) throws -> [String] {
        try exec("DELETE FROM temp.fts5_stem_probe")
        defer { try? exec("DELETE FROM temp.fts5_stem_probe") }

        let insert = try prepare("INSERT INTO temp.fts5_stem_probe(t) VALUES (?)")
        sqlite3_bind_text(insert, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let rc = sqlite3_step(insert)
        sqlite3_finalize(insert)
        guard rc == SQLITE_DONE else {
            throw FTS5Error.sqliteError(code: rc, message: String(cString: sqlite3_errmsg(db)))
        }

        let select = try prepare("SELECT term FROM temp.fts5_stem_probe_vocab ORDER BY term")
        defer { sqlite3_finalize(select) }
        var terms: [String] = []
        while sqlite3_step(select) == SQLITE_ROW {
            if let raw = sqlite3_column_text(select, 0) {
                terms.append(String(cString: raw))
            }
        }
        return terms
    }

    // MARK: - Schema Helpers

    /// Returns `true` if a table (or virtual table) with the given name exists.
    func tableExists(_ table: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(
            db, "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?",
            -1, &stmt, nil
        ) == SQLITE_OK, let s = stmt else { return false }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_text(s, 1, table, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(s) == SQLITE_ROW
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
