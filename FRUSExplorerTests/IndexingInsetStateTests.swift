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

// MARK: - IndexingInsetStateTests

/// Who owns the tab bar's bottom inset (B-6).
///
/// These drive `IndexingInsetState.resolve` — the real decision `MainTabView.indexingBanner`
/// switches on. Before B-6 the same precedence lived inside that view body as an `if`/`else if`
/// chain with no seam, which is precisely why the hole survived: a queued download with no
/// indexing batch matched no branch, the `@ViewBuilder` yielded nothing, and the inset collapsed
/// to zero height while `CloudSurfaceArbiter` had already refused the splash for the same window.
///
/// Version history:
///   1.0 — B-6: initial implementation
@Suite("Which occupant owns the bottom inset")
struct IndexingInsetStateTests {

    /// Every argument false — the ordinary idle app.
    private func resolve(keyboard: Bool = false, batch: Bool = false, metadata: Bool = false,
                         queueEmpty: Bool = true, sync: Bool = false) -> IndexingInsetState {
        IndexingInsetState.resolve(
            keyboardIsVisible: keyboard,
            hasBatch: batch,
            hasCompletedMetadata: metadata,
            downloadQueueIsEmpty: queueEmpty,
            syncIsWorthShowing: sync)
    }

    // MARK: - The B-6 regression

    /// THE DEFECT. A relaunch during a corpus download, before the first volume has finished
    /// transferring: `downloadQueue` is non-empty and `indexingBatch` is still nil, because the
    /// batch is minted only on the first `IndexingProgressUpdate`. Every branch used to fall
    /// through and the app said nothing at all about work it was doing.
    @Test("A queued download with no batch yet claims the inset")
    func queuedDownloadIsReported() {
        #expect(resolve(queueEmpty: false) == .downloadsQueued)
    }

    /// The window has no ceiling: the downloader sets `waitsForConnectivity`, so a relaunch on a
    /// bad network sits here indefinitely rather than for the second or two a good one costs.
    @Test("It stays claimed however long the transfer takes — nothing else fills the gap")
    func queuedDownloadOutranksAnEmptyApp() {
        #expect(resolve(metadata: false, queueEmpty: false, sync: false) == .downloadsQueued)
        #expect(resolve() == .none)
    }

    // MARK: - Precedence

    /// A live batch reports real progress; the queue line reports only a count. Once the batch
    /// exists it must win, or the reader would watch a static count while indexing ran.
    @Test("A live batch outranks the queue line")
    func batchOutranksQueue() {
        #expect(resolve(batch: true, queueEmpty: false) == .batch)
    }

    /// The card describes work that FINISHED; the queue describes work that is happening. iOS has
    /// no auto-clear for the card, so without this an undismissed card would hide a live queue.
    @Test("Newly queued work supersedes an undismissed summary card")
    func queueOutranksSummary() {
        #expect(resolve(metadata: true, queueEmpty: false) == .downloadsQueued)
        #expect(resolve(metadata: true) == .summary)
    }

    /// Extends the rule #665 already wrote for indexing rather than inventing a second one:
    /// transient work finishes, a failed-sync state waits and re-announces.
    @Test("Transient work outranks a sync state that will still be true later")
    func queueOutranksSync() {
        #expect(resolve(queueEmpty: false, sync: true) == .downloadsQueued)
        #expect(resolve(batch: true, sync: true) == .batch)
        #expect(resolve(sync: true) == .sync)
    }

    // MARK: - #1070 non-regression

    /// The inset floats onto the keyboard's accessory row and occluded the #861 Done bar. Nothing
    /// added here may reach the screen while the keyboard is up — including the new banner.
    @Test("The keyboard hides every occupant, the new one included")
    func keyboardHidesEverything() {
        #expect(resolve(keyboard: true, queueEmpty: false) == .hidden)
        #expect(resolve(keyboard: true, batch: true) == .hidden)
        #expect(resolve(keyboard: true, metadata: true) == .hidden)
        #expect(resolve(keyboard: true, sync: true) == .hidden)
    }

    // MARK: - The view uses it

    /// The extraction is worth nothing if `MainTabView` re-tests the conditions instead of
    /// switching on the result — a mirrored decision would stay green while the view drifted,
    /// which is the shape of the bug this file exists for.
    @Test("MainTabView switches on the state rather than re-testing the conditions")
    func viewSwitchesOnTheState() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/App/MainTabView.swift"),
            encoding: .utf8)
        #expect(source.contains("switch IndexingInsetState.resolve("))
        #expect(source.contains("case .downloadsQueued:"))
        #expect(source.contains("DownloadQueueBannerView(count: appState.downloadQueue.count)"))
        // The old chain's conditions must be GONE from the body, or both would be live.
        #expect(!source.contains("else if appState.indexingBatch == nil, appState.completedIndexingMetadata == nil,"))
    }
}
