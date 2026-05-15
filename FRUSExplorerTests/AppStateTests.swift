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

/// Tests for `AppState` initialisation and persistence behaviour.
///
/// All tests run on the main actor because `AppState` is `@MainActor`-isolated.
/// Each test clears the `activeProjectId` UserDefaults key before and after to
/// avoid cross-test contamination from persisted state.
@MainActor
struct AppStateTests {

    // MARK: - Helpers

    private func clearPersistedProjectId() {
        UserDefaults.standard.removeObject(forKey: "activeProjectId")
    }

    // MARK: - Tests

    @Test("AppState initialises with nil activeProjectId when no value is persisted")
    func initialActiveProjectIdIsNilWhenNothingPersisted() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.activeProjectId == nil)
        clearPersistedProjectId()
    }

    @Test("AppState initialises with non-nil activeProjectId when a valid UUID is persisted")
    func initialActiveProjectIdRestoredFromUserDefaults() {
        let testId = UUID()
        UserDefaults.standard.set(testId.uuidString, forKey: "activeProjectId")
        let state = AppState()
        #expect(state.activeProjectId == testId)
        clearPersistedProjectId()
    }

    @Test("AppState ignores malformed persisted activeProjectId and defaults to nil")
    func malformedPersistedValueDefaultsToNil() {
        UserDefaults.standard.set("not-a-uuid", forKey: "activeProjectId")
        let state = AppState()
        #expect(state.activeProjectId == nil)
        clearPersistedProjectId()
    }

    @Test("Setting activeProjectId persists the UUID string to UserDefaults")
    func settingActiveProjectIdPersistsToUserDefaults() {
        clearPersistedProjectId()
        let state = AppState()
        let testId = UUID()
        state.activeProjectId = testId
        let stored = UserDefaults.standard.string(forKey: "activeProjectId")
        #expect(stored == testId.uuidString)
        clearPersistedProjectId()
    }

    @Test("Setting activeProjectId to nil removes the persisted value")
    func settingActiveProjectIdToNilClearsPersistence() {
        let testId = UUID()
        UserDefaults.standard.set(testId.uuidString, forKey: "activeProjectId")
        let state = AppState()
        state.activeProjectId = nil
        let stored = UserDefaults.standard.string(forKey: "activeProjectId")
        #expect(stored == nil)
        clearPersistedProjectId()
    }

    @Test("AppState defaults isOnline to true")
    func isOnlineDefaultsToTrue() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.isOnline == true)
    }

    @Test("AppState initialises with an empty downloadQueue")
    func downloadQueueInitiallyEmpty() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.downloadQueue.isEmpty)
    }
}
