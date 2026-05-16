// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

// MARK: - PersonMentionStore

/// Queries the `person_mentions` table to support person-filtered search
/// and cross-volume person navigation.
///
/// Opens a read-only SQLite connection to the shared database file.
/// All query methods are synchronous (non-async) because they run on the
/// actor's executor and use a dedicated read-only connection — they never
/// block a writer.
///
/// Version history:
///   1.0 — Session 39: initial implementation
public actor PersonMentionStore {

    // nonisolated(unsafe): deinit is nonisolated and must close the handle.
    // Safe because the actor serialises all access and the handle is never
    // read from outside the actor while it is live.
    nonisolated(unsafe) private var db: OpaquePointer?
    private let databaseURL: URL

    // MARK: - Initialisation

    /// Opens a read-only SQLite connection to the shared database file.
    ///
    /// - Parameter databaseURL: The shared database used by `IndexingPipeline`.
    /// - Throws: `PersonMentionError.databaseOpenFailed` if the file cannot be opened.
    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            databaseURL.path, &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw PersonMentionError.databaseOpenFailed(message: msg)
        }
        db = h

        #if DEBUG
        print("[PersonMentionStore] Opened read-only connection to \(databaseURL.lastPathComponent)")
        #endif
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public API

    /// Returns all (volumeId, documentId) pairs that mention the given ref.
    ///
    /// Results are ordered by volume_id, then document_id.
    public func documents(forPersonRef ref: String) throws -> [(volumeId: String, documentId: String)] {
        let sql = """
            SELECT volume_id, document_id FROM person_mentions
            WHERE person_ref = ?
            ORDER BY volume_id, document_id
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, ref)
        var results: [(volumeId: String, documentId: String)] = []
        while step(stmt) {
            let vid = columnString(stmt, 0) ?? ""
            let did = columnString(stmt, 1) ?? ""
            results.append((volumeId: vid, documentId: did))
        }
        return results
    }

    /// Returns all unique person refs mentioned in the given document.
    ///
    /// Results are returned in alphabetical order.
    public func personRefs(forDocumentId documentId: String, volumeId: String) throws -> [String] {
        let sql = """
            SELECT person_ref FROM person_mentions
            WHERE volume_id = ? AND document_id = ?
            ORDER BY person_ref
            """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, volumeId)
        bind(stmt, 2, documentId)
        var refs: [String] = []
        while step(stmt) {
            if let ref = columnString(stmt, 0) { refs.append(ref) }
        }
        return refs
    }

    /// Returns the count of documents (across all indexed volumes) that mention the given ref.
    ///
    /// Used to display a mention count badge in the Document view person sheet.
    public func documentCount(forPersonRef ref: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM person_mentions WHERE person_ref = ?"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, ref)
        guard step(stmt) else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - SQLite Helpers

    private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw PersonMentionError.sqliteError(code: rc, message: msg)
        }
        return s
    }

    @discardableResult
    private func step(_ stmt: OpaquePointer) -> Bool {
        sqlite3_step(stmt) == SQLITE_ROW
    }

    private func bind(_ stmt: OpaquePointer, _ col: Int32, _ value: String) {
        sqlite3_bind_text(stmt, col, value, -1, TRANSIENT)
    }

    private func columnString(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - PersonMentionError

/// Errors thrown by `PersonMentionStore`.
public enum PersonMentionError: Error, Sendable {
    case databaseOpenFailed(message: String)
    case sqliteError(code: Int32, message: String)
}
