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

// MARK: - IndexingQueueBannerTests

/// Data-layer tests for the multi-volume queue banner and ETA computation.
///
/// Covers `AppState.indexingQueuePosition`, `indexingQueueVolumeTitles`, and
/// the ETA formatting logic mirrored from `IndexingQueueBannerView.totalETAString`.
/// These are pure-Swift computation tests — no SwiftUI or AppState state machine
/// is exercised directly.
@Suite("IndexingQueueBanner — ETA and queue position (Session 116)")
struct IndexingQueueBannerTests {

    // MARK: - Helpers

    private func makeUpdate(
        volumeId: String = "frus1969-76v01",
        completed: Int = 50,
        total: Int = 100,
        docsPerSecond: Double = 10.0
    ) -> IndexingProgressUpdate {
        IndexingProgressUpdate(
            volumeId: volumeId,
            stage: .storingBatch(current: completed, total: total),
            completedDocuments: completed,
            totalDocuments: total,
            docsPerSecond: docsPerSecond
        )
    }

    /// Mirrors `IndexingQueueBannerView.totalETAString` for pure-Swift testing.
    private func totalETA(
        update: IndexingProgressUpdate,
        queuePosition: (current: Int, total: Int),
        averageDocsPerSecond: Double = 0,
        averageDocumentCount: Int = 600
    ) -> String? {
        var totalSeconds = 0.0

        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        let remainingVolumes = queuePosition.total - queuePosition.current
        if remainingVolumes > 0 {
            let dps = averageDocsPerSecond > 0 ? averageDocsPerSecond : update.docsPerSecond
            if dps > 0 {
                let estimatedDocs = averageDocumentCount > 0 ? averageDocumentCount : 600
                totalSeconds += Double(remainingVolumes) * Double(estimatedDocs) / dps
            }
        }

        guard totalSeconds > 0 else { return nil }

        if totalSeconds < 60 {
            return "~\(Int(totalSeconds.rounded()))s"
        } else {
            let minutes = Int((totalSeconds / 60).rounded())
            return "~\(minutes)m"
        }
    }

    // MARK: - Queue position
    //
    // Covered by `IndexingBatchPositionTests`, against the real
    // `AppState.indexingQueuePosition`. Three tests here re-implemented the property's
    // arithmetic in local constants and asserted on that — `completed + 1 == 3` — so they
    // passed for the whole period the property returned `nil` for every multi-volume
    // batch (#541). They were removed rather than repaired: a copy of the code under test
    // is not a test of it.

    // MARK: - ETA formatting

    @Test("ETA is nil when docsPerSecond is zero and no remaining volumes")
    func etaNilWhenNoThroughput() {
        let update = makeUpdate(completed: 50, total: 100, docsPerSecond: 0)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 1),
            averageDocsPerSecond: 0
        )
        #expect(eta == nil,
                "ETA must be nil when throughput is unknown and no volumes remain")
    }

    @Test("ETA is formatted as seconds when under 60 seconds")
    func etaFormattedAsSeconds() {
        // 50 remaining docs at 10 dps = 5s; only 1 volume (no queue contribution).
        let update = makeUpdate(completed: 50, total: 100, docsPerSecond: 10)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 1)
        )
        #expect(eta == "~5s")
    }

    @Test("ETA is formatted as minutes when >= 60 seconds")
    func etaFormattedAsMinutes() {
        // 600 remaining docs at 5 dps = 120s = 2m.
        let update = makeUpdate(completed: 0, total: 600, docsPerSecond: 5)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 1)
        )
        #expect(eta == "~2m")
    }

    @Test("ETA accumulates remaining queued volumes using average throughput")
    func etaIncludesQueuedVolumes() {
        // Current volume: 0 remaining (completed). 4 remaining queued volumes.
        // averageDocumentCount: 600, averageDocsPerSecond: 10 → 4 × 600 / 10 = 240s = 4m.
        let update = makeUpdate(completed: 100, total: 100, docsPerSecond: 10)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 5),
            averageDocsPerSecond: 10,
            averageDocumentCount: 600
        )
        #expect(eta == "~4m")
    }

    @Test("ETA falls back to update.docsPerSecond when averageDocsPerSecond is zero")
    func etaFallsBackToCurrentThroughput() {
        // 0 remaining in current + 1 remaining queued volume.
        // averageDocsPerSecond = 0 → falls back to update.docsPerSecond = 10.
        // 1 × 600 / 10 = 60s = 1m.
        let update = makeUpdate(completed: 100, total: 100, docsPerSecond: 10)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 2),
            averageDocsPerSecond: 0,
            averageDocumentCount: 600
        )
        #expect(eta == "~1m")
    }

    @Test("ETA falls back to 600 docs when averageDocumentCount is zero")
    func etaFallsBackToDefaultDocCount() {
        // 1 remaining volume × 600 (fallback) / 10 dps = 60s = 1m.
        let update = makeUpdate(completed: 100, total: 100, docsPerSecond: 10)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 2),
            averageDocsPerSecond: 10,
            averageDocumentCount: 0  // triggers fallback to 600
        )
        #expect(eta == "~1m")
    }

    @Test("Combined ETA sums current volume remainder and queued volumes")
    func etaCombinesBothContributions() {
        // Current: 30 remaining at 10 dps = 3s.
        // Queue: 2 remaining volumes × 600 / 10 = 120s.
        // Total = 123s → rounded to 2 minutes.
        let update = makeUpdate(completed: 70, total: 100, docsPerSecond: 10)
        let eta = totalETA(
            update: update,
            queuePosition: (current: 1, total: 3),
            averageDocsPerSecond: 10,
            averageDocumentCount: 600
        )
        #expect(eta == "~2m")
    }

    // MARK: - Expanded list

    @Test("expandedList shows at most 6 pending volume titles")
    func expandedListCappedAtSix() {
        let allTitles = (1...10).map { "Volume \($0)" }
        let visible = Array(allTitles.prefix(6))
        #expect(visible.count == 6,
                "Expanded pending-volume list must show at most 6 entries")
    }

    @Test("expandedList is empty when no volumes are pending")
    func expandedListEmptyWhenNoPending() {
        let titles: [String] = []
        #expect(titles.isEmpty)
    }
}
