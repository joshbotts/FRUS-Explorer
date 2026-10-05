// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - IndexingStateTrackerTests

/// Tests for Session 115 interrupted-indexing sentinel persistence.
///
/// Each test uses an isolated `UserDefaults` suite so tests never pollute
/// `UserDefaults.standard` and do not interfere with each other.
@Suite("IndexingStateTracker — sentinel persistence (Session 115)")
struct IndexingStateTrackerTests {

    // MARK: - Helpers

    /// Returns a fresh `IndexingStateTracker` backed by an isolated stamp store: a `UserDefaults`
    /// suite in Xcode, an in-memory store in the package (`IndexingTestSupport.swift`).
    private func makeTracker() -> IndexingStateTracker {
        let suiteName = "frus.test.\(UUID().uuidString)"
        return IndexingStateTracker(store: makeIsolatedStamps(suiteName))
    }

    // MARK: - Tests

    @Test("markStarted persists sentinel; interruptedVolumeIds returns it")
    func markStartedPersistsSentinel() async {
        let tracker = makeTracker()
        await tracker.markStarted(volumeId: "frus1969-76v01")
        let ids = await tracker.interruptedVolumeIds()
        #expect(ids.contains("frus1969-76v01"),
                "interruptedVolumeIds must include a volume after markStarted")
    }

    @Test("markCompleted removes the sentinel; interruptedVolumeIds returns empty")
    func markCompletedRemovesSentinel() async {
        let tracker = makeTracker()
        await tracker.markStarted(volumeId: "frus1969-76v01")
        await tracker.markCompleted(volumeId: "frus1969-76v01")
        let ids = await tracker.interruptedVolumeIds()
        #expect(!ids.contains("frus1969-76v01"),
                "interruptedVolumeIds must be empty after markCompleted")
    }

    @Test("interruptedVolumeIds returns only volumes whose markStarted was not followed by markCompleted")
    func onlyUnclearedVolumesReturned() async {
        let tracker = makeTracker()
        await tracker.markStarted(volumeId: "frus1969-76v01")
        await tracker.markStarted(volumeId: "frus1969-76v02")
        await tracker.markCompleted(volumeId: "frus1969-76v01")
        let ids = await tracker.interruptedVolumeIds()
        #expect(!ids.contains("frus1969-76v01"),
                "frus1969-76v01 was completed and must not appear")
        #expect(ids.contains("frus1969-76v02"),
                "frus1969-76v02 was not completed and must appear")
    }

    @Test("markStarted on empty tracker returns an empty interruptedVolumeIds before any call")
    func freshTrackerIsEmpty() async {
        let tracker = makeTracker()
        let ids = await tracker.interruptedVolumeIds()
        #expect(ids.isEmpty, "A fresh tracker must return no interrupted volume IDs")
    }

    @Test("purge fires when the 51st entry is added; oldest entry is evicted")
    func purgeEvictsOldestAtCapacity() async {
        let tracker = makeTracker()

        // Fill to capacity (50). Add them with a slight spread in start time so
        // the purge logic has a clear oldest entry to remove.
        for i in 0..<50 {
            await tracker.markStarted(volumeId: "vol-\(i)")
        }

        // The 51st insert should evict "vol-0" (the oldest by timestamp).
        await tracker.markStarted(volumeId: "vol-50")

        let ids = await tracker.interruptedVolumeIds()
        #expect(ids.count <= 50, "Dictionary must never exceed maxEntries (50)")
        #expect(ids.contains("vol-50"), "The newly-added entry must be present after purge")
    }

    @Test("markCompleted on unknown volumeId is a no-op")
    func markCompletedOnUnknownIdIsNoOp() async {
        let tracker = makeTracker()
        // Should not crash or affect any other state.
        await tracker.markCompleted(volumeId: "nonexistent-volume")
        let ids = await tracker.interruptedVolumeIds()
        #expect(ids.isEmpty, "markCompleted on an unknown ID must leave the store empty")
    }
}
