// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// MARK: - FTS5Error

/// Typed errors thrown by `FTS5Store` and its helpers.
///
/// All errors include a `String` message describing the failure context in
/// enough detail to diagnose the problem without a debugger.
///
/// Version history:
///   1.0 — Session 03: initial implementation
public enum FTS5Error: Error, Sendable {

    /// SQLite returned a non-SQLITE_OK result code from an operation.
    /// `code` is the SQLite result code integer; `message` is the
    /// value of `sqlite3_errmsg` at the time of failure.
    case sqliteError(code: Int32, message: String)

    /// The database file could not be opened or created at the given path.
    case openFailed(path: String, message: String)

    /// The FTS5 schema creation statement failed.
    case schemaCreationFailed(message: String)

    /// An FTS5 MATCH expression was empty or could not be constructed from
    /// the provided `FTS5Query` parameters. Callers should validate that the
    /// query has at least one positive search term.
    case emptyQuery

    /// A batch insert operation contained zero documents.
    case emptyBatch

    /// The backup exclusion resource value could not be set on the database URL.
    case backupExclusionFailed(message: String)
}
