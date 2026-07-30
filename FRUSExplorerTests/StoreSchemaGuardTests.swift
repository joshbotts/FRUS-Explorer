// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreData
import Foundation
import SwiftData
import Testing

@testable import FRUSExplorer

// MARK: - StoreSchemaDiagnostic

/// The guard that names a store/build record-type mismatch, and the reset that clears a store.
///
/// Both exist because of the 2026-07-25 outage: `default.store` was created by a build with 12
/// record types, the running build declared 19, `ModelContainer` init threw, and the app ran on an
/// empty fallback store for 31 launches across four days without saying why.
@Suite("Store schema guard")
struct StoreSchemaDiagnosticTests {

    // MARK: Comparison

    @Test("Missing record types are reported in the model-has/store-lacks direction")
    func missingFromStore() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["Project", "UserTag"],
            modelEntityNames: ["ExportHistoryEntry", "Project", "UserTag"]
        )
        #expect(diagnostic.missingFromStore == ["ExportHistoryEntry"])
        #expect(diagnostic.absentFromModel.isEmpty)
        #expect(diagnostic.isMismatch)
    }

    @Test("A store written by a newer build reports the opposite direction")
    func absentFromModel() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["ExportHistoryEntry", "Project", "UserTag"],
            modelEntityNames: ["Project", "UserTag"]
        )
        #expect(diagnostic.absentFromModel == ["ExportHistoryEntry"])
        #expect(diagnostic.missingFromStore.isEmpty)
        #expect(diagnostic.isMismatch)
    }

    @Test("Both directions at once — an older store and an older build")
    func mismatchInBothDirections() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["ResearchSession", "UserTag"],
            modelEntityNames: ["ExportHistoryEntry", "UserTag"]
        )
        #expect(diagnostic.missingFromStore == ["ExportHistoryEntry"])
        #expect(diagnostic.absentFromModel == ["ResearchSession"])
    }

    @Test("Identical lists are not a mismatch, whatever the order they arrive in")
    func matchingListsAreNotAMismatch() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["Project", "UserTag"],
            modelEntityNames: ["UserTag", "Project"]
        )
        #expect(!diagnostic.isMismatch)
        #expect(diagnostic.missingFromStore.isEmpty)
        #expect(diagnostic.absentFromModel.isEmpty)
    }

    // MARK: Summary

    @Test("The summary names the missing record types, both counts, and the store")
    func summaryCarriesTheDiagnosis() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["Project", "UserTag"],
            modelEntityNames: ["ExportHistoryEntry", "Project", "SearchHistoryEntry", "UserTag"]
        )
        let summary = diagnostic.summary
        // The names are the whole value of the diagnostic: they are what turned a four-day
        // mystery into a one-line diagnosis, so a summary without them is a regression.
        #expect(summary.contains("ExportHistoryEntry"))
        #expect(summary.contains("SearchHistoryEntry"))
        #expect(summary.contains("default.store"))
        #expect(summary.contains("2 record types"))
        #expect(summary.contains("declares 4"))
    }

    @Test("A matching summary states the lists agree and rules the cause out")
    func matchingSummaryRulesTheCauseOut() {
        let diagnostic = StoreSchemaDiagnostic(
            storeName: "default.store",
            storeEntityNames: ["Project", "UserTag"],
            modelEntityNames: ["Project", "UserTag"]
        )
        #expect(diagnostic.summary.contains("not the cause"))
        // Must not carry the mismatch consequence text, which would contradict itself.
        #expect(!diagnostic.summary.contains("cannot open"))
    }

    // MARK: Reading a real store

    @Test("Metadata is read from a real on-disk store, and a full-schema store matches")
    func diagnoseReadsRealStoreMetadata() throws {
        let directory = URL.temporaryDirectory.appending(path: "frus-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "probe.store")

        // Build a real store with the app's full schema, then close it.
        let names: [String] = try {
            let schema = Schema(ModelContainer.frusModelTypes)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            _ = try ModelContainer(for: schema, configurations: [config])
            return schema.entities.map(\.name)
        }()

        let diagnostic = try #require(
            StoreSchemaDiagnostic.diagnose(storeURL: storeURL, modelEntityNames: names)
        )
        // The read has to produce the real list, not merely a non-nil value — an empty
        // `storeEntityNames` would also be non-nil and would report every type as missing.
        #expect(diagnostic.storeEntityNames == names.sorted())
        #expect(!diagnostic.isMismatch)
        #expect(diagnostic.storeName == "probe.store")
    }

    @Test("A store built with fewer types reports exactly the difference")
    func diagnoseDetectsARealMismatch() throws {
        let directory = URL.temporaryDirectory.appending(path: "frus-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "old.store")

        // A store created by a "previous build": one self-contained model type. This reproduces
        // the July failure's shape — a store that predates types the running build declares.
        try {
            let schema = Schema([SummarizationPrompt.self])
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            _ = try ModelContainer(for: schema, configurations: [config])
        }()

        let fullNames = Schema(ModelContainer.frusModelTypes).entities.map(\.name)
        let diagnostic = try #require(
            StoreSchemaDiagnostic.diagnose(storeURL: storeURL, modelEntityNames: fullNames)
        )
        #expect(diagnostic.isMismatch)
        #expect(diagnostic.storeEntityNames == ["SummarizationPrompt"])
        #expect(diagnostic.absentFromModel.isEmpty)
        #expect(diagnostic.missingFromStore.count == fullNames.count - 1)
        #expect(diagnostic.missingFromStore.contains("UserTag"))
        #expect(!diagnostic.missingFromStore.contains("SummarizationPrompt"))
    }

    @Test("No store means no finding — which is not the same as no mismatch")
    func diagnoseReturnsNilForAMissingStore() {
        let absent = URL.temporaryDirectory.appending(path: "does-not-exist-\(UUID().uuidString).store")
        #expect(StoreSchemaDiagnostic.diagnose(storeURL: absent, modelEntityNames: ["UserTag"]) == nil)
    }

    @Test("A file that is not a store yields no finding rather than an empty entity list")
    func diagnoseReturnsNilForGarbage() throws {
        let directory = URL.temporaryDirectory.appending(path: "frus-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let junk = directory.appending(path: "junk.store")
        try Data("not a database".utf8).write(to: junk)
        #expect(StoreSchemaDiagnostic.diagnose(storeURL: junk, modelEntityNames: ["UserTag"]) == nil)
    }

    // MARK: The store locations

    @Test("managedStoreURLs names the two real stores")
    func managedStoreURLsAreTheRealStores() {
        let names = ModelContainer.managedStoreURLs.map(\.lastPathComponent)
        // These exact names are what the old reset failed to match. Pinning them here means a
        // SwiftData change to the default store name breaks a test rather than the button.
        #expect(names == ["default.store", "FRUSExplorerLocal.store"])
    }
}

// MARK: - PendingStoreReset

@Suite("Pending store reset")
struct PendingStoreResetTests {

    /// A `UserDefaults` domain private to one test, so nothing touches the real one.
    private func makeDefaults() -> UserDefaults {
        let suite = "frus.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("The request round-trips and can be withdrawn")
    func requestLifecycle() {
        let defaults = makeDefaults()
        #expect(!PendingStoreReset.isRequested(defaults: defaults))
        PendingStoreReset.request(defaults: defaults)
        #expect(PendingStoreReset.isRequested(defaults: defaults))
        PendingStoreReset.cancel(defaults: defaults)
        #expect(!PendingStoreReset.isRequested(defaults: defaults))
    }

    @Test("No request means no work and no outcome")
    func noRequestIsANoOp() throws {
        let defaults = makeDefaults()
        let directory = URL.temporaryDirectory.appending(path: "frus-reset-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "default.store")
        try Data("store".utf8).write(to: store)

        #expect(PendingStoreReset.performIfRequested(storeURLs: [store], defaults: defaults) == nil)
        // The file must still be there: a no-op that deletes is the worst possible failure here.
        #expect(FileManager.default.fileExists(atPath: store.path))
    }

    @Test("A requested reset removes the store, both sidecars, and the two CloudKit directories")
    func resetRemovesEveryArtifact() throws {
        let defaults = makeDefaults()
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-reset-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }

        let store = directory.appending(path: "default.store")
        try Data("store".utf8).write(to: store)
        try Data("wal".utf8).write(to: directory.appending(path: "default.store-wal"))
        try Data("shm".utf8).write(to: directory.appending(path: "default.store-shm"))
        try fm.createDirectory(at: directory.appending(path: "default_ckAssets"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: directory.appending(path: ".default_SUPPORT"),
                               withIntermediateDirectories: true)

        PendingStoreReset.request(defaults: defaults)
        let outcome = try #require(
            PendingStoreReset.performIfRequested(storeURLs: [store], defaults: defaults)
        )

        #expect(outcome.isClean)
        #expect(outcome.removed.count == 5)
        for name in ["default.store", "default.store-wal", "default.store-shm",
                     "default_ckAssets", ".default_SUPPORT"] {
            #expect(!fm.fileExists(atPath: directory.appending(path: name).path),
                    "\(name) survived the reset")
        }
        // A partly-completed reset must not retry forever.
        #expect(!PendingStoreReset.isRequested(defaults: defaults))
    }

    @Test("The reset cannot touch the FTS index, the volumes, or any other neighbour")
    func resetLeavesEverythingElseAlone() throws {
        let defaults = makeDefaults()
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-reset-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }

        let store = directory.appending(path: "default.store")
        try Data("store".utf8).write(to: store)

        // The real Application Support directory holds all of these beside the stores. `frus.db` is
        // 6.3 GB on the owner's Mac and can only be rebuilt by re-parsing every volume, so this is
        // the test that matters most in the file.
        let bystanders = ["frus.db", "frus.db-wal", "frus.db-shm", "collections.json",
                          "summaries.json", "sync-diagnostics.json", "default.store.backup"]
        for name in bystanders {
            try Data(name.utf8).write(to: directory.appending(path: name))
        }
        try fm.createDirectory(at: directory.appending(path: "volumes"),
                               withIntermediateDirectories: true)

        PendingStoreReset.request(defaults: defaults)
        let outcome = try #require(
            PendingStoreReset.performIfRequested(storeURLs: [store], defaults: defaults)
        )

        #expect(outcome.removed == ["default.store"])
        for name in bystanders {
            #expect(fm.fileExists(atPath: directory.appending(path: name).path),
                    "\(name) was deleted by the reset")
        }
        #expect(fm.fileExists(atPath: directory.appending(path: "volumes").path))
    }

    @Test("Both stores are cleared, and absent artifacts are not reported as removed")
    func resetClearsBothStores() throws {
        let defaults = makeDefaults()
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-reset-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }

        let cloud = directory.appending(path: "default.store")
        let local = directory.appending(path: "FRUSExplorerLocal.store")
        try Data("cloud".utf8).write(to: cloud)
        try Data("local".utf8).write(to: local)

        PendingStoreReset.request(defaults: defaults)
        let outcome = try #require(
            PendingStoreReset.performIfRequested(storeURLs: [cloud, local], defaults: defaults)
        )
        // Exactly two: the sidecars and CloudKit directories never existed, and reporting files
        // that were never there would make the log unreadable on a first-run reset.
        #expect(outcome.removed.sorted() == ["FRUSExplorerLocal.store", "default.store"])
        #expect(!fm.fileExists(atPath: cloud.path))
        #expect(!fm.fileExists(atPath: local.path))
    }

    @Test("artifactPaths derives the CloudKit directory names from the store's own base name")
    func artifactPathsDerivesNames() {
        let paths = PendingStoreReset
            .artifactPaths(for: URL(fileURLWithPath: "/tmp/frus/custom.store"))
            .map(\.lastPathComponent)
        #expect(paths == ["custom.store", "custom.store-wal", "custom.store-shm",
                          "custom_ckAssets", ".custom_SUPPORT"])
    }
}
