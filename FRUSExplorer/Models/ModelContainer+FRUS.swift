// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ModelContainer Factory

extension ModelContainer {

    /// Returns the ordered list of model types for the FRUS schema.
    ///
    /// A fresh `Schema` is constructed from this list each time `makeFRUSContainer`
    /// or `makeTestContainer` is called. Sharing a single `Schema` instance across
    /// a CloudKit config attempt and a local/test config can cause SwiftData to
    /// apply CloudKit validation to every subsequent container, so we never reuse
    /// a Schema that has been passed to a CloudKit `ModelConfiguration`.
    private static var frusModelTypes: [any PersistentModel.Type] {
        [
            Project.self,
            ResearchNote.self,
            GeneratedSummary.self,
            UserTag.self,
            Collection.self,
            CollectionEntry.self,
            ReadingHistoryEntry.self,
            SummarizationPrompt.self,
            SavedSearch.self,
        ]
    }

    /// Creates the production `ModelContainer` backed by CloudKit private database.
    ///
    /// CloudKit container: `iCloud.bottsywattsy.FRUS-Explorer`
    /// All model types are synced. The container falls back to a local-only store
    /// if CloudKit is unavailable (e.g., user not signed in), logging a warning.
    ///
    /// When running under the XCTest host (detected via `XCTestConfigurationFilePath`)
    /// or the UI test app process (detected via `FRUS_UI_TEST_MODE = "1"`), CloudKit
    /// is skipped entirely. Without a CloudKit entitlement the background sync setup
    /// fires a SIGTRAP ~30 s after launch, crashing the host before tests can run.
    ///
    /// ## Calling convention
    /// Call once at app startup from `FRUSExplorerApp`. The resulting container
    /// is injected into the SwiftUI environment via `.modelContainer(_:)`.
    static func makeFRUSContainer() -> ModelContainer {
        // Skip CloudKit when running under the unit-test host (XCTestConfigurationFilePath)
        // or the UI-test app process (FRUS_UI_TEST_MODE injected via launchEnvironment).
        // Without this, CloudKit's background sync fires a SIGTRAP ~30 s after launch
        // when the entitlement is absent, crashing the host before tests can run.
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
        guard !isTestHost else {
            #if DEBUG
            let reason = ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
                ? "UI test mode" : "XCTest host"
            print("[SwiftData] \(reason) detected — using local store (no CloudKit)")
            #endif
            return makeLocalContainer()
        }

        // Use a fresh schema for the CloudKit attempt.
        let cloudSchema = Schema(frusModelTypes)
        let cloudConfig = ModelConfiguration(
            schema: cloudSchema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.bottsywattsy.FRUS-Explorer")
        )
        do {
            let container = try ModelContainer(for: cloudSchema, configurations: [cloudConfig])
            #if DEBUG
            print("[SwiftData] ModelContainer created with CloudKit sync")
            #endif
            return container
        } catch {
            // CloudKit unavailable (e.g., simulator without iCloud account, entitlement missing,
            // or schema not yet fully CloudKit-compatible). Fall back to a local SQLite store.
            #if DEBUG
            print("[SwiftData] CloudKit container failed (\(error)); falling back to local store")
            #endif
            return makeLocalContainer()
        }
    }

    /// Creates an ephemeral in-memory container for unit tests.
    ///
    /// Each call returns a fresh container with an independent Schema instance.
    /// Using a fresh Schema ensures that any CloudKit-validation state from a prior
    /// container attempt does not affect this container. CloudKit sync is disabled.
    static func makeTestContainer() throws -> ModelContainer {
        let schema = Schema(frusModelTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates a persistent local-only (non-CloudKit) container.
    ///
    /// Used as the fallback when CloudKit init fails, and as the primary container
    /// when running under the XCTest host.
    private static func makeLocalContainer() -> ModelContainer {
        do {
            let localSchema = Schema(frusModelTypes)
            let localConfig = ModelConfiguration(
                "FRUSExplorerLocal",
                schema: localSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: localSchema, configurations: [localConfig])
            #if DEBUG
            print("[SwiftData] ModelContainer created with local store")
            #endif
            return container
        } catch {
            // Schema is fundamentally broken — use in-memory so the app can at least start.
            // Data won't persist across launches; this path should not occur in production.
            #if DEBUG
            print("[SwiftData] Local store failed (\(error)); using in-memory store")
            #endif
            let memSchema = Schema(frusModelTypes)
            let memConfig = ModelConfiguration(schema: memSchema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: memSchema, configurations: [memConfig])
        }
    }
}
