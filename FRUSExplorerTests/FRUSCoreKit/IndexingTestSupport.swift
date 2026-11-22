// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
// SQLite3 is the system's on Apple platforms; on Linux the web edition supplies CSQLite.
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

// MARK: - What the app's test host gives a pipeline, for the package

// In Xcode the suites run inside the app, so a test pipeline built with the app's initialiser
// (`IndexingPipeline+App.swift`) reads the app's bundled data files and keeps its stamps in
// `UserDefaults.standard`. The package has neither, so it gets the same data files from the
// repository and one stamp store that every pipeline in the run shares, as they share `.standard`.
// The suites then build pipelines with the same calls under both compilers.

#if SWIFT_PACKAGE
/// The app's bundled data files, read from the repository's `FRUSExplorer/Resources` and decoded
/// once per run, as the test host's bundle supplies them in Xcode.
let testIndexingResources: IndexingResources = {
    let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources")
    do {
        return try IndexingResources.loading(fromDirectory: resources)
    } catch {
        fatalError("the suites read the app's data files from the repository: \(error)")
    }
}()

/// The stamps of every pipeline the package's suites build without a store of their own, shared
/// as `UserDefaults.standard` is in Xcode. Parallel tests write it (`consolidatePersonRollup` stamps
/// the rollup), so a test whose result depends on a stamp builds its pipeline over a store of its own
/// (`makeIsolatedStamps(_:)`) instead.
let testIndexingStamps = InMemoryIndexingStampStore()

extension IndexingPipeline {

    /// The app's initialiser, as the package's suites need it: the repository's data files, and
    /// the run's shared stamps unless the test passes a store.
    init(
        fts5Store: FTS5Store,
        databaseURL: URL,
        volumesDirectory: URL,
        stateTracker: IndexingStateTracker? = nil,
        concurrencyLimit: Int = 4,
        defaults: (any IndexingStampStore)? = nil
    ) throws {
        try self.init(fts5Store: fts5Store, databaseURL: databaseURL, volumesDirectory: volumesDirectory,
                      resources: testIndexingResources, stateTracker: stateTracker,
                      concurrencyLimit: concurrencyLimit, defaults: defaults ?? testIndexingStamps)
    }
}
#endif

/// A stamp store of a test's own, so a test's stamps meet no other test's: a fresh `UserDefaults`
/// suite in Xcode, removed by `removeIsolatedStamps(_:)`, and a fresh in-memory store in the package.
/// `makeTestPipeline(dir:volumesDir:isolatedStamps:)` builds a pipeline over one. A test pipeline
/// built without one shares the run's store (`testIndexingStamps` in the package, and in Xcode
/// `UserDefaults.standard`, the default of the app's initialiser), which parallel tests write.
func makeIsolatedStamps(_ suite: String) -> any IndexingStampStore {
    #if SWIFT_PACKAGE
    InMemoryIndexingStampStore()
    #else
    UserDefaults(suiteName: suite)!
    #endif
}

/// Removes what `makeIsolatedStamps(_:)` made for `suite`: the `UserDefaults` suite in Xcode;
/// nothing in the package, whose store goes with the test.
func removeIsolatedStamps(_ suite: String) {
    #if !SWIFT_PACKAGE
    UserDefaults.standard.removePersistentDomain(forName: suite)
    #endif
}

// MARK: - A host's copy of the index, with its readers' writing in a store of its own

/// One reader's row of a host's `user_search`: the text the app's writers put in the index's columns
/// for a document (`SearchUserSource.attachedStore(userId:)`).
struct HostStoreRow: Sendable {
    let user: String
    let volumeId: String
    let documentId: String
    let summary: String?
    let note: String?
}

/// The index and the store a host serves, as FRUS Explorer Light serves them, for the suites that read
/// a reader's summaries from a store attached to the index: a line's (`ProjectHomeHostTests`, which keeps
/// copies of its own), a related row's (`RelatedDocumentsHostTests`) and a Chronology row's
/// (`ChronologyUserSourceTests`), FRUS-Explorer#1907 and #1927.
enum HostServedIndex {

    /// Copies the app's index at `built` page for page with SQLite's backup API, out of write-ahead-log
    /// mode, strips the copy with `ResearchDatabaseStrip.steps` on one connection, as an export made
    /// without the writing is stripped and as FRUS Explorer Light strips one made with it, and opens it
    /// read-only, as such a host serves it, with the host's store of its readers' writing attached when
    /// `userStore` names one. The copy is `served/frus.db` under `dir`.
    static func servedCopy(of built: URL, volumes: URL, in dir: URL, userStore: URL? = nil) throws -> IndexingPipeline {
        let served = dir.appendingPathComponent("served", isDirectory: true)
        try FileManager.default.createDirectory(at: served, withIntermediateDirectories: true)
        let database = served.appendingPathComponent("frus.db")
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(database.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        for step in ResearchDatabaseStrip.steps {
            #expect(sqlite3_exec(target, step.sql, nil, nil, nil) == SQLITE_OK, "\(step.action)")
        }
        let targetClosed = sqlite3_close(target), sourceClosed = sqlite3_close(source)
        #expect(targetClosed == SQLITE_OK && sourceClosed == SQLITE_OK)
        try? FileManager.default.removeItem(at: served.appendingPathComponent("frus.db-shm"))

        let pipeline = try IndexingPipeline(readingIndexAt: database, fts5Store: try FTS5Store(readingDatabaseAt: database),
                                            resources: .none, volumesDirectory: volumes, userStore: userStore)
        #expect(pipeline.isReadOnly)
        return pipeline
    }

    /// Adds `rows` to the store at `url`, made first with the two tables
    /// `SearchUserSource.attachedStore(userId:)` names when it does not exist, as a host keeps one; the
    /// connection is the host's, closed after the write.
    static func writeStore(at url: URL, rows: [HostStoreRow]) throws {
        let isNew = !FileManager.default.fileExists(atPath: url.path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        try #require(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        if isNew {
            try #require(sqlite3_exec(db, """
                CREATE VIRTUAL TABLE user_search USING fts5(user_id UNINDEXED, document_id UNINDEXED,
                    volume_id UNINDEXED, summary_text, note_text, tokenize = 'porter unicode61');
                CREATE TABLE tag_assignments (user_id TEXT NOT NULL, id TEXT NOT NULL, volume_id TEXT NOT NULL,
                    document_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at TEXT, PRIMARY KEY (user_id, id));
                """, nil, nil, nil) == SQLITE_OK)
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for row in rows {
            var stmt: OpaquePointer?
            try #require(sqlite3_prepare_v2(db, """
                INSERT INTO user_search (user_id, document_id, volume_id, summary_text, note_text) VALUES (?, ?, ?, ?, ?)
                """, -1, &stmt, nil) == SQLITE_OK)
            defer { sqlite3_finalize(stmt) }
            for (index, value) in [row.user, row.documentId, row.volumeId, row.summary, row.note].enumerated() {
                if let value {
                    sqlite3_bind_text(stmt, Int32(index + 1), value, -1, transient)
                } else {
                    sqlite3_bind_null(stmt, Int32(index + 1))
                }
            }
            try #require(sqlite3_step(stmt) == SQLITE_DONE)
        }
    }

    /// Sets the summary of one user's row of the store's `user_search` for a document, through a
    /// connection of the host's own, closed after the write, as a host rewrites a document's row.
    static func setSummary(at url: URL, user: String, volumeId: String, documentId: String, summary: String) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        try #require(sqlite3_prepare_v2(
            db, "UPDATE user_search SET summary_text = ? WHERE user_id = ? AND volume_id = ? AND document_id = ?",
            -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in [summary, user, volumeId, documentId].enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), value, -1, transient)
        }
        try #require(sqlite3_step(stmt) == SQLITE_DONE)
        try #require(sqlite3_changes(db) == 1, "the store held \(sqlite3_changes(db)) rows of \(user)'s text for \(documentId)")
    }
}
