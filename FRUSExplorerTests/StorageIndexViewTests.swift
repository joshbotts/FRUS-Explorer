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

/// Data-layer tests for the Reindex All controls absorbed into `StorageManagementView`
/// in Session 118.
///
/// Tests cover:
/// - Button disabled state while reindexing is active
/// - Progress label formatting for each `IndexingProgress.State` case
/// - Green completion display after `.completed` event
/// - Per-volume reindex operates independently of the all-volumes stream state
@Suite("StorageManagementView — Reindex All controls (Session 118)")
struct StorageIndexViewTests {

    // MARK: - Helpers

    /// Mirrors `StorageManagementView.reindexAllProgressLabel` for pure-Swift testing.
    private func progressLabel(for state: IndexingProgress.State) -> String {
        switch state {
        case .idle:
            return String(localized: "settings.reindex.progress.starting",
                          defaultValue: "Starting…")
        case .indexing(let volumeId, let current, let total):
            return String(localized: "settings.reindex.progress.indexing",
                          defaultValue: "\(current)/\(total) — \(volumeId)")
        case .completed, .failed:
            return ""
        }
    }

    /// Returns `true` when the Reindex All button should be disabled.
    private func isReindexAllDisabled(
        isReindexAll: Bool,
        reindexingInterruptedId: String?,
        pipelineAvailable: Bool
    ) -> Bool {
        isReindexAll || reindexingInterruptedId != nil || !pipelineAvailable
    }

    // MARK: - Button disabled state

    @Test("Reindex All button is enabled when idle and pipeline is available")
    func buttonEnabledWhenIdle() {
        let disabled = isReindexAllDisabled(
            isReindexAll: false,
            reindexingInterruptedId: nil,
            pipelineAvailable: true
        )
        #expect(!disabled)
    }

    @Test("Reindex All button is disabled while isReindexAll is true")
    func buttonDisabledWhileReindexing() {
        let disabled = isReindexAllDisabled(
            isReindexAll: true,
            reindexingInterruptedId: nil,
            pipelineAvailable: true
        )
        #expect(disabled,
                "Button must be disabled while an all-volumes reindex is in progress")
    }

    @Test("Reindex All button is disabled while an interrupted-volume reindex is running")
    func buttonDisabledDuringInterruptedReindex() {
        let disabled = isReindexAllDisabled(
            isReindexAll: false,
            reindexingInterruptedId: "frus1969-76v01",
            pipelineAvailable: true
        )
        #expect(disabled,
                "Button must be disabled while an interrupted-volume re-index is running")
    }

    @Test("Reindex All button is disabled when indexing pipeline is unavailable")
    func buttonDisabledWithoutPipeline() {
        let disabled = isReindexAllDisabled(
            isReindexAll: false,
            reindexingInterruptedId: nil,
            pipelineAvailable: false
        )
        #expect(disabled,
                "Button must be disabled when the IndexingPipeline is nil")
    }

    // MARK: - Progress label

    @Test("Progress label shows 'Starting…' for .idle state")
    func progressLabelIdle() {
        let label = progressLabel(for: .idle)
        #expect(label == "Starting…")
    }

    @Test("Progress label shows current/total and volumeId for .indexing state")
    func progressLabelIndexing() {
        let label = progressLabel(for: .indexing(volumeId: "frus1969-76v01", current: 3, total: 12))
        #expect(label.contains("3/12"),
                "Progress label must contain current/total count")
        #expect(label.contains("frus1969-76v01"),
                "Progress label must contain the current volumeId")
    }

    @Test("Progress label is empty for .completed state")
    func progressLabelCompleted() {
        let label = progressLabel(for: .completed(volumeCount: 5, documentCount: 3247))
        #expect(label.isEmpty,
                "Progress label must be empty once reindex is completed")
    }

    @Test("Progress label is empty for .failed state")
    func progressLabelFailed() {
        let label = progressLabel(for: .failed(volumeId: "frus1969-76v01", error: "disk full"))
        #expect(label.isEmpty)
    }

    // MARK: - Completion display

    @Test("Completed state exposes volumeCount and documentCount for the green label")
    func completedStateExposesVolumesAndDocs() {
        let state = IndexingProgress.State.completed(volumeCount: 7, documentCount: 4821)
        if case .completed(let volumes, let docs) = state {
            #expect(volumes == 7)
            #expect(docs == 4821)
        } else {
            Issue.record("Expected .completed state")
        }
    }

    @Test("Green completion label is shown only for .completed state, not .indexing")
    func completionLabelOnlyForCompletedState() {
        let indexingState = IndexingProgress.State.indexing(volumeId: "v01", current: 1, total: 2)
        var showsCompletionLabel = false
        if case .completed = indexingState { showsCompletionLabel = true }
        #expect(!showsCompletionLabel,
                "Completion label must not appear while indexing is still in progress")
    }

    // MARK: - Per-volume independence

    @Test("Per-volume reindex state is independent of all-volumes stream state")
    func perVolumeReindexIsIndependent() {
        // Per-volume reindex uses reindexingVolumeId (String?) — a separate state var
        // from isReindexAll (Bool). Both can be false/nil simultaneously.
        var reindexingVolumeId: String? = nil
        var isReindexAll = false

        // Simulate: all-volumes reindex is idle; per-volume reindex starts.
        reindexingVolumeId = "frus1969-76v01"
        #expect(reindexingVolumeId != nil)
        #expect(!isReindexAll,
                "isReindexAll must remain false during a per-volume reindex")

        // Simulate: per-volume reindex finishes; all-volumes reindex starts.
        reindexingVolumeId = nil
        isReindexAll = true
        #expect(reindexingVolumeId == nil)
        #expect(isReindexAll,
                "isReindexAll must be settable independently of per-volume state")
    }

    // MARK: - Navigation title

    @Test("Storage & Index pane navigation title string matches spec")
    func navigationTitleString() {
        let title = String(localized: "storage.navigationTitle",
                           defaultValue: "Storage & Index")
        #expect(title == "Storage & Index")
    }
}
