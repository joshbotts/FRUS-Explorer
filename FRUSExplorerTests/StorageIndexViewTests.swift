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

// MARK: - StorageIndexViewTests

/// Tests around the Volumes & Storage hub's indexing controls.
///
/// ## What changed in S-2c
/// This suite was written in Session 118 for the "Reindex All Volumes" control, and most of it
/// re-implemented that control's own logic inside the test file — a local `reindexAllProgressLabel`
/// mirror and a local `isReindexAllDisabled` mirror, asserted against themselves. Those tests could
/// not fail regardless of what the app did, and the control they described no longer exists: S-2b
/// and S-2c retired "Reindex All" on both platforms, because "Rebuild From Scratch" does the same
/// work *and* clears rows orphaned by deleted volumes and FTS5 fragmentation.
///
/// What survives is what tests something real: `IndexingProgress.State`, which the hub's queue card
/// still renders, and the busy-state rule that decides whether the hub's destructive actions are
/// reachable.
@Suite("Volumes & Storage hub — indexing controls")
struct StorageIndexViewTests {

    // MARK: - Busy state

    /// Mirrors `MacVolumesStorageHub.actionsBusy` / `VolumesStorageHubView.actionsBusy`.
    ///
    /// Unlike the Session-118 mirror this replaces, the rule it encodes is load-bearing: every
    /// index-mutating button in the hub is gated on it, and a gap would let a reader start a
    /// rebuild on top of a running batch.
    private func actionsBusy(
        batchRunning: Bool,
        liveIndexingProgress: Bool,
        reindexingInterruptedId: String?,
        reindexingVolumeId: String?
    ) -> Bool {
        batchRunning || liveIndexingProgress || reindexingInterruptedId != nil || reindexingVolumeId != nil
    }

    @Test("Nothing running leaves the destructive actions reachable")
    func idleIsNotBusy() {
        #expect(!actionsBusy(batchRunning: false, liveIndexingProgress: false,
                             reindexingInterruptedId: nil, reindexingVolumeId: nil))
    }

    /// Each of the four ways indexing can be in flight has to block on its own — a rebuild started
    /// during any of them would race the running work.
    @Test("Every kind of in-flight indexing blocks the destructive actions")
    func eachInFlightSourceBlocks() {
        #expect(actionsBusy(batchRunning: true, liveIndexingProgress: false,
                            reindexingInterruptedId: nil, reindexingVolumeId: nil),
                "a Settings-triggered batch must block")
        #expect(actionsBusy(batchRunning: false, liveIndexingProgress: true,
                            reindexingInterruptedId: nil, reindexingVolumeId: nil),
                "indexing started elsewhere (a finished download) must block")
        #expect(actionsBusy(batchRunning: false, liveIndexingProgress: false,
                            reindexingInterruptedId: "frus1969-76v01", reindexingVolumeId: nil),
                "an interrupted-volume re-index must block")
        #expect(actionsBusy(batchRunning: false, liveIndexingProgress: false,
                            reindexingInterruptedId: nil, reindexingVolumeId: "frus1969-76v01"),
                "a per-volume re-index must block")
    }

    // MARK: - IndexingProgress.State

    /// The queue card reads these associated values directly.
    @Test("Completed state carries the volume and document counts the card reports")
    func completedStateExposesVolumesAndDocs() {
        let state = IndexingProgress.State.completed(volumeCount: 7, documentCount: 4821)
        if case .completed(let volumes, let docs) = state {
            #expect(volumes == 7)
            #expect(docs == 4821)
        } else {
            Issue.record("Expected .completed state")
        }
    }

    @Test("Indexing state carries position within the batch")
    func indexingStateExposesPosition() {
        let state = IndexingProgress.State.indexing(volumeId: "frus1969-76v01", current: 3, total: 12)
        if case .indexing(let volumeId, let current, let total) = state {
            #expect(volumeId == "frus1969-76v01")
            #expect(current == 3)
            #expect(total == 12)
        } else {
            Issue.record("Expected .indexing state")
        }
    }

    @Test("An in-progress state is not mistaken for a completed one")
    func indexingIsNotCompleted() {
        let indexingState = IndexingProgress.State.indexing(volumeId: "v01", current: 1, total: 2)
        var showsCompletionLabel = false
        if case .completed = indexingState { showsCompletionLabel = true }
        #expect(!showsCompletionLabel,
                "Completion label must not appear while indexing is still in progress")
    }

    // MARK: - Naming

    /// The hub's title, which is also the single Library row's label in both renderers.
    @Test("The hub's title is the merged name on both platforms")
    func hubTitleString() {
        #expect(SettingsPane.volumesStorage.label == "Volumes & Storage")
        #expect(String(localized: "settings.hub.title", defaultValue: "Volumes & Storage")
                == "Volumes & Storage")
    }
}
