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

    /// The `ResearchSession` side of this is no longer hypothetical: R-2b retired that type, so
    /// every store written before it carries an entity this build's model does not declare. That
    /// is exactly `absentFromModel`, and it must read as a benign mismatch rather than a fault.
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

    @Test("The shipped build manages the two real stores")
    func managedStoreURLsAreTheRealStores() {
        let names = ModelContainer.managedStoreURLs(for: .release).map(\.lastPathComponent)
        // These exact names are what the old reset failed to match. Pinning them here means a
        // SwiftData change to the default store name breaks a test rather than the button — and,
        // since #1531, that a shipped build still opens the file every earlier build kept a
        // reader's data in. Read for `.release` explicitly: this test target is a Debug build.
        #expect(names == ["default.store", "FRUSExplorerLocal.store"])
    }
}

// MARK: - A Debug build's own stores (#1531)

/// A Debug build talks to CloudKit Development and the shipped app to Production; until #1531 they
/// shared one store file, so a Debug session expired the Production change token and set off the
/// full re-upload that stopped the owner's Mac syncing. These pin the separation.
///
/// Idiom-agnostic: they read configurations and source, and run alike on any destination. The
/// unit target is compiled in the Debug configuration, so "the running build" below IS a Debug
/// build — the case #1531 is about.
@Suite("Debug store separation (#1531)")
struct DebugStoreSeparationTests {

    @Test("A Debug build's stores are named apart from the shipped app's")
    func debugStoresAreNamedApart() {
        let debug = ModelContainer.managedStoreURLs(for: .debug).map(\.lastPathComponent)
        let release = ModelContainer.managedStoreURLs(for: .release).map(\.lastPathComponent)
        #expect(debug == ["FRUSExplorerDebug.store", "FRUSExplorerLocalDebug.store"])
        #expect(Set(debug).isDisjoint(with: release),
                "a Debug build and the shipped app would open the same file again")
        #expect(ModelContainer.managedStoreURLs(for: .debug).map { $0.deletingLastPathComponent() }
                == ModelContainer.managedStoreURLs(for: .release).map { $0.deletingLastPathComponent() },
                "the separation is by file name in the same container, not a different directory")
    }

    /// The A/B that needs no new API: on `v2` before #1531 this Debug test build managed
    /// `default.store`, the shipped app's file.
    @Test("This Debug test build does not manage the shipped app's store")
    func runningDebugBuildLeavesTheShippedStoreAlone() {
        #if DEBUG
        let names = ModelContainer.managedStoreURLs.map(\.lastPathComponent)
        #expect(!names.contains("default.store"),
                "a Debug build manages default.store — its Fix iCloud Sync would clear the shipped app's data")
        #expect(!names.contains("FRUSExplorerLocal.store"))
        #expect(FRUSStoreConfiguration.current == .debug)
        #else
        Issue.record("the unit target is expected to build in the Debug configuration")
        #endif
    }

    /// The container and the reset must name the same file, or a Debug Fix iCloud Sync would clear
    /// one store while the container kept opening another.
    @Test("The container's mirrored store is the first managed store, in both configurations",
          arguments: FRUSStoreConfiguration.allCases)
    func containerAndResetAgree(configuration: FRUSStoreConfiguration) {
        let cloud = ModelContainer.mirroredStoreConfiguration(
            configuration, schema: Schema(ModelContainer.frusModelTypes),
            cloudKitDatabase: .private("iCloud.bottsywattsy.FRUS-Explorer"))
        let local = ModelContainer.localStoreConfiguration(
            configuration, schema: Schema(ModelContainer.frusModelTypes))
        #expect([cloud.url, local.url] == ModelContainer.managedStoreURLs(for: configuration))
    }

    /// The reset a Debug build performs, against both builds' files side by side as they sit in
    /// one container: only the Debug files go.
    @Test("A Debug build's reset leaves the shipped app's store on disk")
    func debugResetLeavesTheShippedStore() throws {
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-debug-reset-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let suite = "frus.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let everyName = (ModelContainer.managedStoreURLs(for: .debug)
            + ModelContainer.managedStoreURLs(for: .release)).map(\.lastPathComponent)
        for name in everyName { try Data(name.utf8).write(to: directory.appending(path: name)) }
        let debugURLs = ModelContainer.managedStoreURLs(for: .debug)
            .map { directory.appending(path: $0.lastPathComponent) }

        PendingStoreReset.request(defaults: defaults)
        let outcome = try #require(PendingStoreReset.performIfRequested(storeURLs: debugURLs,
                                                                         defaults: defaults))
        #expect(outcome.removed.sorted() == ["FRUSExplorerDebug.store", "FRUSExplorerLocalDebug.store"])
        #expect(fm.fileExists(atPath: directory.appending(path: "default.store").path))
        #expect(fm.fileExists(atPath: directory.appending(path: "FRUSExplorerLocal.store").path))
    }

    /// The review's case: both builds read one `UserDefaults`, so with one request key the reader's
    /// Fix iCloud Sync in the shipped app was consumed by whichever build launched next — a Debug
    /// launch cleared the Debug files, cancelled the request, and the shipped store was never reset.
    /// Each build now reads and clears only its own request.
    @Test("A reset requested in one build is neither performed nor spent by the other")
    func eachBuildKeepsItsOwnRequest() throws {
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-request-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let suite = "frus.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let urls = { (configuration: FRUSStoreConfiguration) in
            ModelContainer.managedStoreURLs(for: configuration)
                .map { directory.appending(path: $0.lastPathComponent) }
        }
        for url in urls(.debug) + urls(.release) { try Data("store".utf8).write(to: url) }

        PendingStoreReset.request(defaults: defaults, configuration: .release)
        #expect(PendingStoreReset.performIfRequested(storeURLs: urls(.debug), defaults: defaults,
                                                     configuration: .debug) == nil,
                "a Debug launch performed the reset the shipped app asked for")
        #expect(PendingStoreReset.isRequested(defaults: defaults, configuration: .release),
                "a Debug launch spent the shipped app's request")
        #expect(fm.fileExists(atPath: urls(.debug)[0].path))

        let outcome = try #require(PendingStoreReset.performIfRequested(
            storeURLs: urls(.release), defaults: defaults, configuration: .release),
            "the shipped build did not find its own request")
        #expect(outcome.removed.sorted() == ["FRUSExplorerLocal.store", "default.store"])
        #expect(fm.fileExists(atPath: urls(.debug)[0].path))
        #expect(!PendingStoreReset.isRequested(defaults: defaults, configuration: .release))
        // The shipped build keeps the key every earlier build wrote, so a request made before an
        // update survives it.
        #expect(PendingStoreReset.requestKey(for: .release) == "frus.pendingStoreReset")
    }

    /// A `FileManager` that refuses to remove one file, as a store held open or a permissions fault
    /// would.
    private final class RefusingFileManager: FileManager, @unchecked Sendable {
        let refusedName: String
        init(refusing name: String) {
            refusedName = name
            super.init()
        }
        override func removeItem(at url: URL) throws {
            if url.lastPathComponent == refusedName {
                throw CocoaError(.fileWriteNoPermission)
            }
            try super.removeItem(at: url)
        }
    }

    /// The remembered upload failure is about changes in the mirrored store. A clean reset has
    /// discarded them, so it ends the failure; a reset that left a store file behind has not shown
    /// that, so the failure — and its Fix iCloud Sync warning — stays. Only the build's own
    /// failure is touched.
    @Test("A performed reset forgets the remembered failure only when it removed every file",
          arguments: [true, false])
    func resetForgetsOnlyWhenClean(clean: Bool) throws {
        let fm = FileManager.default
        let directory = URL.temporaryDirectory.appending(path: "frus-forget-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let suite = "frus.test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let urls = ModelContainer.managedStoreURLs(for: .debug)
            .map { directory.appending(path: $0.lastPathComponent) }
        for url in urls { try Data("store".utf8).write(to: url) }
        for configuration in FRUSStoreConfiguration.allCases {
            SyncExportFailureMemory.recordExport(succeeded: false, at: .now, message: "m",
                                                 schemaIdentifiers: nil, defaults: defaults,
                                                 configuration: configuration)
        }
        PendingStoreReset.request(defaults: defaults, configuration: .debug)

        let fileManager: FileManager = clean ? .default
            : RefusingFileManager(refusing: urls[0].lastPathComponent)
        let outcome = try #require(ModelContainer.performRequestedReset(
            storeURLs: urls, configuration: .debug, defaults: defaults, fileManager: fileManager))
        #expect(outcome.isClean == clean, "fixture guard: the reset did not go as staged")
        let remembered = SyncExportFailureMemory.load(defaults: defaults, configuration: .debug)
        if clean {
            #expect(remembered == nil, "a clean reset left the failure it discarded on screen")
        } else {
            #expect(remembered != nil,
                    "a reset that left the mirrored store behind forgot its unsent changes")
            #expect(fm.fileExists(atPath: urls[0].path))
        }
        #expect(SyncExportFailureMemory.load(defaults: defaults, configuration: .release) != nil,
                "a Debug reset forgot the shipped app's remembered failure")
        #expect(!PendingStoreReset.isRequested(defaults: defaults, configuration: .debug))
    }

    // MARK: Wiring in makeFRUSContainer()

    /// An app source file, by its path from the repository root.
    static func appSource(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The body of the one function declared with `signature`, from its opening brace to the brace
    /// that balances it, read with comments and string literals masked — so a comment naming a call
    /// cannot stand in for the call. `nil` when the signature is absent or declared twice.
    static func functionBody(_ signature: String, in source: String) -> String? {
        let code = String(decoding: CodingStandardsAuditTests.maskedCode(source), as: UTF8.self)
        guard let start = code.range(of: signature),
              code.range(of: signature, range: start.upperBound..<code.endIndex) == nil,
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else { return nil }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// `makeFRUSContainer()` cannot run under a test host (it returns an in-memory store first), so
    /// its order is read from the source, within the function's own balanced braces: the monitor is
    /// installed BEFORE the CloudKit container is built (#1531's first fix), the container's store
    /// configuration comes from the one function the reset also reads, and a requested reset goes
    /// through `performRequestedReset`, whose forgetting `resetForgetsOnlyWhenClean` drives.
    @Test("makeFRUSContainer installs the monitor before the container and resets through the one helper")
    func containerFactoryWiring() throws {
        let body = try #require(Self.functionBody(
            "static func makeFRUSContainer()",
            in: try Self.appSource("FRUSExplorer/Models/ModelContainer+FRUS.swift")),
            "makeFRUSContainer() is not declared exactly once — the scan would read nothing")
        let install = try #require(body.range(of: "SyncEventMonitor.shared.install()"),
                                   "makeFRUSContainer() no longer installs the sync-event monitor")
        let build = try #require(body.range(of: "try ModelContainer(for: cloudSchema, configurations: [cloudConfig])"),
                                 "the CloudKit container is no longer built where this test looks")
        #expect(install.lowerBound < build.lowerBound,
                "the monitor is installed after the CloudKit container starts — a launch's first failure is missed again")
        #expect(body.contains("let cloudConfig = mirroredStoreConfiguration("),
                "the container builds its store configuration by hand, apart from the reset's")
        // The reset goes through the helper the tests drive, and nothing here forgets on its own:
        // only a reset that removed every file discarded the changes the failure was about.
        #expect(body.contains("if let outcome = performRequestedReset(storeURLs: managedStoreURLs)"),
                "makeFRUSContainer() no longer performs a requested reset through performRequestedReset")
        #expect(!body.contains("PendingStoreReset.performIfRequested("),
                "makeFRUSContainer() performs the reset directly again, apart from the tested helper")
        #expect(!body.contains("SyncExportFailureMemory.forget("),
                "makeFRUSContainer() forgets the remembered failure itself, whatever the reset did")
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
