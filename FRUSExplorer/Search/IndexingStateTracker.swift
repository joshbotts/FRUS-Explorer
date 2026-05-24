// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - IndexingStateTracker

/// Persists a `[volumeId: startDate]` sentinel dictionary to `UserDefaults` so
/// interrupted indexing passes are detectable across app restarts.
///
/// ## Sentinel lifecycle
/// `markStarted(volumeId:)` records a start timestamp under `"frus.indexingInProgress"`.
/// `markCompleted(volumeId:)` removes the entry. If the app is killed between those
/// two calls the entry survives, and `interruptedVolumeIds()` returns it on the next launch.
///
/// ## Purge policy
/// The dictionary is capped at `maxEntries` (50). When `markStarted` would push the count
/// over the cap, the oldest entry (by start timestamp) is removed first to prevent
/// unbounded `UserDefaults` growth in pathological cases.
///
/// ## Testability
/// A custom `UserDefaults` suite can be injected at init time so tests never pollute
/// `UserDefaults.standard`.
///
/// Version history:
///   1.0 — Session 115: initial implementation
public actor IndexingStateTracker {

    // MARK: - Configuration

    static let userDefaultsKey = "frus.indexingInProgress"
    static let maxEntries = 50

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Init

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - API

    /// Records that indexing has begun for `volumeId`.
    ///
    /// If the dictionary already contains `maxEntries`, the entry with the oldest
    /// start timestamp is removed before the new entry is written.
    public func markStarted(volumeId: String) {
        var dict = loadDict()
        if dict.count >= Self.maxEntries,
           let oldest = dict.min(by: { $0.value < $1.value }) {
            dict.removeValue(forKey: oldest.key)
        }
        dict[volumeId] = Date()
        save(dict)
    }

    /// Records that indexing completed successfully for `volumeId`.
    ///
    /// Removes the sentinel entry so the volume is no longer treated as interrupted.
    public func markCompleted(volumeId: String) {
        var dict = loadDict()
        dict.removeValue(forKey: volumeId)
        save(dict)
    }

    /// Returns the volume IDs of any indexing passes that started but never completed.
    ///
    /// Call once at app launch to seed `AppState.interruptedVolumeIds`.
    public func interruptedVolumeIds() -> [String] {
        Array(loadDict().keys)
    }

    // MARK: - Persistence (private)

    private func loadDict() -> [String: Date] {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ dict: [String: Date]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }
}
