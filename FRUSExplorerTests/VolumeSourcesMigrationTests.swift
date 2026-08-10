// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - VolumeSourcesMigrationTests

/// That an existing database gains new `volume_sources` columns (the #807 regression).
///
/// `CREATE TABLE IF NOT EXISTS` does nothing to a table that already exists, so the drop-and-
/// recreate guard above it **is** the migration. #733 added `job_number`/`job_number_norm` to the
/// CREATE and not to the guard. On a fresh database everything passed — every test, the full
/// corpus regeneration, both platform builds — because a fresh database takes the CREATE.
///
/// On an existing one the table kept its old columns, `auxInsertVolumeSources` named two it did
/// not have, every insert threw, and since the indexer deletes a volume's rows before reinserting
/// them, **the table emptied**: measured on the owner's index, 33,764 rows across 258 volumes went
/// to 0 and every volume's Sources tab read "No Sources Listed".
///
/// These tests run the migration against a **deliberately old-shaped** table, which is the only
/// shape that reproduces it.
///
/// Version history:
///   1.0 — Session 2026-08-10: repair for #807
@Suite("volume_sources migration")
struct VolumeSourcesMigrationTests {

    /// The pre-#733 table, verbatim from the owner's database.
    private static let legacySchema = """
        CREATE TABLE volume_sources (
            volume_id     TEXT NOT NULL,
            repository    TEXT,
            record_group  TEXT,
            lot_file      TEXT,
            lot_file_norm TEXT,
            series_name   TEXT,
            decimal_class TEXT,
            entry_text    TEXT NOT NULL,
            kind          TEXT NOT NULL DEFAULT 'item',
            depth         INTEGER NOT NULL DEFAULT 0,
            is_heading    INTEGER NOT NULL DEFAULT 0,
            sort_order    INTEGER NOT NULL DEFAULT 0,
            note          TEXT,
            PRIMARY KEY (volume_id, sort_order)
        )
        """

    /// Creates a database carrying the legacy table, then opens a pipeline over it so
    /// `auxCreateTables` runs its migration against a pre-existing table.
    private func migratedColumns() throws -> Set<String> {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vsmig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")

        var handle: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, Self.legacySchema, nil, nil, nil) == SQLITE_OK,
                "the fixture must start from the OLD shape, or it cannot reproduce the bug")
        sqlite3_close(handle)

        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let store = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)

        var read: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &read) == SQLITE_OK)
        defer { sqlite3_close(read) }
        var stmt: OpaquePointer?
        #expect(sqlite3_prepare_v2(read, "PRAGMA table_info(volume_sources)", -1, &stmt, nil)
                == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var names = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 1) { names.insert(String(cString: c)) }
        }
        return names
    }

    @Test("An existing table gains the columns the insert writes")
    func legacyTableIsMigrated() throws {
        let columns = try migratedColumns()
        #expect(columns.contains("job_number"), """
            The migration guard did not fire. This is the #807 regression exactly: the table keeps \
            its old columns, auxInsertVolumeSources names two that do not exist, every insert \
            throws, and the delete-then-insert empties the table.
            """)
        #expect(columns.contains("job_number_norm"))
    }

    @Test("Every column the insert writes exists after migration")
    func insertColumnsAllExist() throws {
        // The general rule, not just today's two. Any column added to the INSERT must also be
        // named in the drop-and-recreate guard; this asserts the two lists agree rather than
        // trusting whoever adds the next one to remember.
        let columns = try migratedColumns()
        let written = ["volume_id", "repository", "record_group", "lot_file", "lot_file_norm",
                       "series_name", "decimal_class", "job_number", "job_number_norm",
                       "entry_text", "kind", "depth", "is_heading", "sort_order", "note"]
        let missing = written.filter { !columns.contains($0) }
        #expect(missing.isEmpty, "columns written by auxInsertVolumeSources but absent: \(missing)")
    }

    @Test("The index version was bumped, or the repair never runs")
    func repairRequiresAVersionBump() {
        // A device that already ran the v39 reindex has `installed == 39`, so `needsDateReindex`
        // is false and the corrected schema would be created empty and stay empty. Fixing the
        // guard without bumping the version fixes nothing a user can see.
        #expect(IndexingPipeline.currentDateIndexVersion >= 40, """
            v39 is the bump that shipped the regression. The repair needs its own bump or no \
            existing install ever repopulates volume_sources.
            """)
    }
}
