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

/// Exercises `SettingsSyncCoordinator`'s mirror logic against an in-memory store.
///
/// Serialised because the cases inject and read shared `UserDefaults.standard` keys;
/// each case restores the keys it touches.
@MainActor
@Suite(.serialized)
struct SettingsSyncCoordinatorTests {

    /// Each test must hold the returned container for its whole body: `mainContext`
    /// does not keep its container alive, and fetching on a context whose container
    /// has deallocated SIGTRAPs the test host.
    ///
    /// `cloudKitDatabase: .none` keeps the container from adopting the test host's
    /// iCloud entitlement (the default `.automatic` starts real CloudKit mirroring,
    /// which has no account in the simulator).
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SyncedPreferences.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: SettingsSyncCoordinator.enabledKey)
    }

    /// Removes every `UserDefaults` key a coordinator pull can write, so tests that
    /// trigger a pull leave no state behind for other suites or later runs (the
    /// host app's defaults persist across test invocations in the simulator).
    private func removePulledKeys() {
        let defaults = UserDefaults.standard
        for key in [
            WordCloudSettings.Keys.minLength,
            WordCloudSettings.Keys.minCount,
            WordCloudSettings.Keys.foldPlurals,
            WordCloudSettings.Keys.filterMarkings,
            WordCloudSettings.Keys.excludeBoilerplate,
            WordCloudSettings.Keys.globalStopwords,
            WordCloudSettings.Keys.lensStopwords,
            WordCloudSettings.Keys.revision,
            SettingsKeys.citationStyle,
            SettingsKeys.defaultDocumentMode,
            AppState.researchLoggingPreferenceKey,
        ] { defaults.removeObject(forKey: key) }
    }

    @Test("Enabling sync with no cloud record seeds one from local settings")
    func seedsOnEnable() throws {
        let defaults = UserDefaults.standard
        defaults.set(5, forKey: WordCloudSettings.Keys.minLength)
        defaults.set("chicago", forKey: SettingsKeys.citationStyle)
        setEnabled(true)
        defer {
            defaults.removeObject(forKey: WordCloudSettings.Keys.minLength)
            defaults.removeObject(forKey: SettingsKeys.citationStyle)
            setEnabled(false)
        }

        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = SettingsSyncCoordinator(context: context)
        coordinator.handleEnabledChange(true)

        let records = try context.fetch(FetchDescriptor<SyncedPreferences>())
        #expect(records.count == 1)
        #expect(records.first?.wcMinLength == 5)
        #expect(records.first?.citationStyleRaw == "chicago")
    }

    @Test("A pull copies synced values into UserDefaults")
    func pullsIntoDefaults() throws {
        let defaults = UserDefaults.standard
        setEnabled(true)
        defer {
            removePulledKeys()
            setEnabled(false)
        }

        let container = try makeContainer()
        let context = container.mainContext
        let record = SyncedPreferences()
        record.wcMinCount = 4
        record.citationStyleRaw = "turabian"
        context.insert(record)

        let coordinator = SettingsSyncCoordinator(context: context)
        coordinator.syncNowIfEnabled()

        #expect(defaults.integer(forKey: WordCloudSettings.Keys.minCount) == 4)
        #expect(defaults.string(forKey: SettingsKeys.citationStyle) == "turabian")
    }

    @Test("Duplicate records collapse to the earliest-created one")
    func collapsesDuplicates() throws {
        setEnabled(true)
        defer {
            removePulledKeys()
            setEnabled(false)
        }

        let container = try makeContainer()
        let context = container.mainContext
        let older = SyncedPreferences()
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        older.wcMinCount = 2
        let newer = SyncedPreferences()
        newer.createdAt = Date(timeIntervalSince1970: 2_000)
        newer.wcMinCount = 7
        context.insert(older)
        context.insert(newer)

        let coordinator = SettingsSyncCoordinator(context: context)
        coordinator.syncNowIfEnabled()

        let records = try context.fetch(FetchDescriptor<SyncedPreferences>())
        #expect(records.count == 1)
        // The earliest record is canonical, so its value is what propagates.
        #expect(records.first?.wcMinCount == 2)
    }

    @Test("A disabled coordinator never writes UserDefaults")
    func disabledIsNoOp() throws {
        let defaults = UserDefaults.standard
        setEnabled(false)
        defaults.removeObject(forKey: WordCloudSettings.Keys.minCount)

        let container = try makeContainer()
        let context = container.mainContext
        let record = SyncedPreferences()
        record.wcMinCount = 9
        context.insert(record)

        let coordinator = SettingsSyncCoordinator(context: context)
        coordinator.syncNowIfEnabled()

        #expect(defaults.object(forKey: WordCloudSettings.Keys.minCount) == nil)
    }
}
