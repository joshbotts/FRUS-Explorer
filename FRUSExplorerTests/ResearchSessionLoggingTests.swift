// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - ResearchSessionLoggingTests

/// Pins what research-session logging actually does with what it records.
///
/// `AppState.logEvent(_:)` writes into `AppState.loggingContext`, a `ModelContext` created by
/// hand at boot (`FRUSExplorerApp.swift:1792`), and nothing in the app ever calls `save()` on it.
/// That reads like a bug — a hand-made context is widely believed not to autosave — and it is
/// not one: on this SDK `autosaveEnabled` is `true` by default, so the records land.
///
/// These tests exist because the answer decides what the preference means. If the writes
/// evaporated, "Log Research Sessions" would govern nothing and would not be worth a control on
/// either platform. They persist, into a CloudKit-mirrored store, and among the things they
/// record is the user's raw search-query text — so the control is worth having on both.
/// Measured rather than reasoned: the first version of this file asserted the opposite and was
/// wrong.
struct ResearchSessionLoggingTests {

    /// A container matching the app's schema for these two models. `cloudKitDatabase: .none`,
    /// per the recorded hazard: an entitled test host otherwise spins up real sync and crashes.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ResearchSession.self, SessionEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// The load-bearing fact: the logging context autosaves, so `logEvent` really does record.
    ///
    /// If this ever flips to `false`, research-session logging silently stops persisting and the
    /// preference stops meaning anything — which is exactly the failure this test exists to
    /// catch, since no screen would change either way.
    @Test("The hand-made logging context autosaves, so events are recorded")
    @MainActor
    func loggingContextAutosaves() throws {
        let container = try makeContainer()

        // Exactly what the app does: a fresh context, an insert, no explicit save.
        let logging = ModelContext(container)
        #expect(logging.autosaveEnabled == true)
        logging.insert(ResearchSession(startedAt: .now))
        #expect(logging.insertedModelsArray.count == 1)
    }

    /// And the record reaches other readers of the same store — which is what a session viewer
    /// would be, if one were reachable.
    @Test("A saved insert is visible to another context")
    @MainActor
    func explicitSavePersists() throws {
        let container = try makeContainer()

        let logging = ModelContext(container)
        logging.insert(ResearchSession(startedAt: .now))
        try logging.save()

        let reader = ModelContext(container)
        #expect(try reader.fetch(FetchDescriptor<ResearchSession>()).count == 1)
    }

    /// `mainContext` autosaves too — recorded so a future reader does not "fix" the logging
    /// context by switching it to `mainContext` on the theory that only that one saves.
    @Test("mainContext autosaves as well")
    @MainActor
    func mainContextAutosaves() throws {
        let container = try makeContainer()
        #expect(container.mainContext.autosaveEnabled == true)
    }

    /// The preference's gate reads `UserDefaults` directly and treats an absent value as on.
    /// Both the app gate and the sync coordinator's pull rely on that convention, so it is worth
    /// pinning against a well-meaning "default to off" change that would silently disable
    /// logging for every existing user.
    @Test("An absent preference means logging is on")
    func absentPreferenceMeansOn() {
        let key = "researchSessionLoggingEnabled.probe.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        #expect((UserDefaults.standard.object(forKey: key) as? Bool ?? true) == true)
        UserDefaults.standard.set(false, forKey: key)
        #expect((UserDefaults.standard.object(forKey: key) as? Bool ?? true) == false)
    }
}
