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
    ///
    /// Version history:
    ///   1.0 — Session 04: initial implementation
    ///   1.1 — Session 130: `makeFRUSContainer()` returns `(container:, cloudKitEnabled:)` tuple;
    ///          CloudKit error logging promoted from #if DEBUG to always-on for diagnostics
    ///   1.2 — Session 2026-06-07: added `SearchHistoryEntry` (mirrors `ReadingHistoryEntry`
    ///          for executed search queries) — backs the new macOS "History" menu and
    ///          "Complete History" window
    ///   1.3 — Session 2026-06-07: `makeFRUSContainer()` return tuple gained `initError: NSError?`
    ///          so callers can run the actual CloudKit init failure through
    ///          `FRUSExplorerApp.cloudKitDiagnostic(_:)` and surface the real domain/code/
    ///          description in the UI, instead of a hardcoded "check console" placeholder
    ///
    /// ## A note on schema migrations
    /// Every new `PersistentModel` type added to this list — most recently
    /// `SearchHistoryEntry` (1.2) and, before it, `DocumentTagAssignment` (Session 130) and
    /// `DocumentHighlight` (Session 102) — introduces a *new CloudKit record type* that does
    /// not yet exist in the deployed CloudKit schema. Per the "CloudKit schema note" below,
    /// SwiftData/`NSPersistentCloudKitContainer` creates these record types lazily in the
    /// **Development** schema the first time a record of that type is pushed; they must then
    /// be promoted via CloudKit Dashboard → Schema → "Deploy Schema Changes to Production"
    /// before Production/TestFlight/App Store builds can sync them. Until that promotion
    /// happens, Production builds will see sync failures for the new record type — typically
    /// `serverRejectedRequest` (15), `incompatibleVersion` (18), or `invalidArguments` (12) —
    /// surfaced by `cloudKitDiagnostic(_:)` as e.g. "CKErrorDomain serverRejectedRequest: …".
    /// **Whenever you add a model type here, deploy the CloudKit schema before shipping.**
    private static var frusModelTypes: [any PersistentModel.Type] {
        [
            Project.self,
            ResearchNote.self,
            GeneratedSummary.self,
            UserTag.self,
            Collection.self,
            CollectionEntry.self,
            ReadingHistoryEntry.self,
            SearchHistoryEntry.self,
            SummarizationPrompt.self,
            SavedSearch.self,
            ResearchSession.self,
            SessionEvent.self,
            DocumentHighlight.self,
            DocumentTagAssignment.self,
            PersonClusterOverride.self,
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
    /// ## Return value
    /// Returns a named tuple `(container:, cloudKitEnabled:)` so the caller can
    /// surface the CloudKit status in `AppState` and the status bar without
    /// re-querying the container. `cloudKitEnabled` is `false` whenever the
    /// container fell back to the local store.
    ///
    /// ## Calling convention
    /// Call once at app startup from `FRUSExplorerApp`. The resulting container
    /// is injected into the SwiftUI environment via `.modelContainer(_:)`.
    // MARK: - CloudKit schema note
    //
    // SwiftData's NSPersistentCloudKitContainer.initializeCloudKitSchema(options:) cannot
    // be called directly because SwiftData wraps the container and does not expose it in
    // any public API. The container's managed object model is generated internally and is
    // not accessible via Schema or ModelContainer public interfaces.
    //
    // Instead, CloudKit record types are created lazily when the first record of each
    // type is pushed. This means model types that have never had a record (e.g.
    // SavedSearch if no user has saved a search, DocumentHighlight if no one has
    // highlighted text) will be ABSENT from the CloudKit schema until that happens.
    //
    // To proactively populate the CloudKit schema with all 13 record types:
    //   1. Run a Development build with a real iCloud account signed in.
    //   2. Save at least one search → creates SavedSearch schema entry.
    //   3. Highlight text in a document → creates DocumentHighlight schema entry.
    //   4. CloudKit Dashboard → Deploy Schema Changes to Production.
    //
    // See Planning/130-CloudKit-SchemaInit.md for full context.

    static func makeFRUSContainer() -> (container: ModelContainer, cloudKitEnabled: Bool, initError: NSError?) {
        // Skip CloudKit when running under the unit-test host (XCTestConfigurationFilePath)
        // or the UI-test app process (FRUS_UI_TEST_MODE injected via launchEnvironment).
        // Without this, CloudKit's background sync fires a SIGTRAP ~30 s after launch
        // when the entitlement is absent, crashing the host before tests can run.
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
        guard !isTestHost else {
            let reason = ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
                ? "UI test mode" : "XCTest host"
            print("[SwiftData] \(reason) detected — using local store (no CloudKit)")
            return (makeLocalContainer(), false, nil)
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
            print("[SwiftData] ModelContainer created — CloudKit sync ENABLED")
            return (container, true, nil)
        } catch {
            // CloudKit unavailable: log the full error so developers/testers can diagnose
            // the exact failure reason (schema migration, entitlement, sign-in, etc.).
            // This is intentionally NOT gated on #if DEBUG because sync failures are
            // critical operational events that must be visible in all build configurations.
            //
            // The NSError is also returned (not just logged) so the caller can run it
            // through `FRUSExplorerApp.cloudKitDiagnostic(_:)` and surface the actual
            // domain/code/description in the UI — `AppState.cloudKitInitError` previously
            // held a hardcoded "check console for details" placeholder, which left users
            // and testers with literally no way to self-diagnose an init failure (e.g. a
            // CloudKit schema migration that hasn't been deployed to Production yet) from
            // the running app; the only record was this console line.
            let nsError = error as NSError
            print("[SwiftData] ⚠️  CloudKit container FAILED — falling back to local-only store")
            print("[SwiftData] ⚠️  Error: \(nsError)")
            print("[SwiftData] ⚠️  localizedDescription: \(nsError.localizedDescription)")
            print("[SwiftData] ⚠️  Data changes will NOT sync across devices until this is resolved.")
            return (makeLocalContainer(), false, nsError)
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
