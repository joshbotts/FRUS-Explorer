// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - RefreshReadOnlyStoresTests

/// Tests `AppState.refreshReadOnlyStores`, the core of the #275 fix: after an in-session index
/// rebuild leaves the boot-time read-only connections stale, this reopens them against the settled
/// database and bumps `readOnlyStoresGeneration` so dashboards on screen reload.
@MainActor
struct RefreshReadOnlyStoresTests {

    /// Builds a minimal valid `frus.db` (schema bootstrapped via `FTS5Store` + `IndexingPipeline`,
    /// including the ALTER TABLE migrations) so the read-only stores open successfully.
    private func makeValidDB() throws -> (dir: URL, dbURL: URL, volumesDir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRefresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("frus.db")
        let volumesDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumesDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(
            fts5Store: fts5,
            databaseURL: dbURL,
            volumesDirectory: volumesDir,
            concurrencyLimit: 1
        )
        return (dir, dbURL, volumesDir)
    }

    @Test("refreshReadOnlyStores reopens the cross-reference store and bumps the generation")
    func refreshReopensAndBumps() throws {
        let (dir, dbURL, volumesDir) = try makeValidDB()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.databaseURL = dbURL
        appState.volumesDirectory = volumesDir

        let before = appState.readOnlyStoresGeneration
        appState.refreshReadOnlyStores()

        // The generation bump is what drives the dashboards' .onChange reload.
        #expect(appState.readOnlyStoresGeneration == before + 1)
        // The store reopened successfully against the valid DB.
        let firstStore = try #require(appState.crossReferenceStore)

        // A second refresh yields a *fresh* store instance and bumps again (the old connection is
        // released via the previous store's deinit).
        appState.refreshReadOnlyStores()
        #expect(appState.readOnlyStoresGeneration == before + 2)
        #expect(appState.crossReferenceStore !== firstStore)
    }

    @Test("refreshReadOnlyStores is a no-op when databaseURL is unset")
    func refreshNoOpWithoutURL() {
        let appState = AppState()
        let before = appState.readOnlyStoresGeneration
        appState.refreshReadOnlyStores()
        #expect(appState.readOnlyStoresGeneration == before)
        #expect(appState.crossReferenceStore == nil)
    }
}
