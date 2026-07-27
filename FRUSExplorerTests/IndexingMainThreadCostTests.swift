// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import FRUSExplorer

/// The main-thread work the indexing banner does per body evaluation, and the queue
/// teardown race underneath the owner's on-device report.
///
/// ## Where these came from
/// An on-screen frame probe on an iPad showed p95 75 ms and max 192 ms during a subseries
/// index — 9 and 23 consecutive missed vsyncs — plus a readout that reset once per volume.
/// The readout lives in `@State` inside the backdrop, and `@State` only dies when a view
/// loses structural identity, so "it reset" was evidence of a teardown, not of a slow frame.
///
/// Both turned out to be reachable from the same place: the banner is attached to all five
/// tabs, re-evaluates ~10×/s while indexing, and everything it asked for was O(n) over the
/// 552-entry manifest or a filesystem sweep.
///
/// Version history:
///   1.0 — after the owner's on-device frame-probe run
@Suite("Indexing — main-thread cost and queue teardown")
struct IndexingMainThreadCostTests {

    // MARK: - The teardown race

    /// `unindexedDownloadedVolumeIds()` subtracts everything with rows in `document_cache`,
    /// and a volume that is *mid-store* already has rows. So the backlog can read empty
    /// while work is still in flight, and ending the queue on that reading rebuilt the
    /// banner — and its backdrop, and its `@State` — once per volume.
    @Test("An empty backlog does not end the queue on the spot")
    func emptyBacklogStartsACountdownRatherThanEnding() async throws {
        let restore = await MainActor.run { AppState.indexingBatchSettleSeconds }
        await MainActor.run { AppState.indexingBatchSettleSeconds = 3600 }
        defer { Task { @MainActor in AppState.indexingBatchSettleSeconds = restore } }

        try await withOneVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")
            _ = try await waitUntil(in: appState) { ($0.indexingBatch?.completed ?? 0) >= 1 }

            // The backlog IS empty here — one volume, indexed. With the settle window held
            // open, the queue must still be standing: nothing may tear the banner down on
            // the strength of that query alone.
            try await Task.sleep(for: .milliseconds(400))
            let batch = await MainActor.run { appState.indexingBatch }
            #expect(batch != nil,
                    "ending here is what rebuilt the backdrop once per volume")
        }
    }

    @Test("...but it does end once the settle window passes with nothing happening")
    func emptyBacklogEndsAfterTheSettleWindow() async throws {
        let restore = await MainActor.run { AppState.indexingBatchSettleSeconds }
        await MainActor.run { AppState.indexingBatchSettleSeconds = 0.3 }
        defer { Task { @MainActor in AppState.indexingBatchSettleSeconds = restore } }

        try await withOneVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")
            let ended = try await waitUntil(in: appState, timeout: .seconds(5)) { $0.indexingBatch == nil }
            #expect(ended, "a queue that is genuinely done must still finish, and promptly")
        }
    }

    // MARK: - The O(n) primitive

    @Test("ManifestStore.entry(forVolumeId:) is a map lookup, not a scan of 552 entries")
    @MainActor
    func manifestLookupIsIndexed() {
        // The plain init loads the real bundled manifest.
        let store = ManifestStore()
        let ids = store.bundledEntries.map(\.volumeId)
        #expect(ids.count > 100, "precondition: the bundled manifest is the real one")

        // Correctness first — the index must answer exactly what the scan did.
        for id in ids.prefix(50) {
            #expect(store.entry(forVolumeId: id)?.volumeId == id)
        }
        #expect(store.entry(forVolumeId: "not-a-volume") == nil)

        // Then the property that matters: resolving every volume is not quadratic. The
        // banner does this once per queued volume, five times per body evaluation, ~10×/s.
        //
        // Measured against the OLD implementation rather than a wall-clock threshold. A
        // fixed millisecond budget is not an oracle here — the first attempt allowed 20 ms
        // and the 552×552 scan finished inside it, so the test passed against the very code
        // it was written to reject. A ratio is self-calibrating: it means the same thing on
        // a fast Mac and a loaded CI box, and it collapses to ~1 the moment this regresses.
        let entries = store.bundledEntries
        let scanStart = ContinuousClock.now
        for id in ids { _ = entries.first { $0.volumeId == id } }
        let scanTime = ContinuousClock.now - scanStart

        let lookupStart = ContinuousClock.now
        for id in ids { _ = store.entry(forVolumeId: id) }
        let lookupTime = ContinuousClock.now - lookupStart

        #expect(lookupTime * 10 < scanTime,
                "indexed lookup took \(lookupTime) vs \(scanTime) for the equivalent scan over \(ids.count) entries — that ratio says entry(forVolumeId:) is still scanning")
    }

    // MARK: - The render loop does no I/O

    /// The doc comment claimed this since Session 131 and it was not true: the SQLite query
    /// went away, but `isVolumeDownloaded` is a `stat(2)` and it ran for all 552 entries.
    @Test("unindexedVolumeCount is stored, so reading it cannot touch the filesystem")
    @MainActor
    func badgeCountDoesNoIOWhenRead() {
        #if os(iOS)
        let state = AppState()
        // No download manager, no manifest, nothing seeded — a bare read must still be a
        // plain property load. If this ever becomes computed again it will start doing
        // filesystem work from `MainTabView.body` on all five tabs.
        #expect(state.unindexedVolumeCount == 0)
        #endif
    }

    // MARK: - Harness

    private func withOneVolumePipeline(
        _ body: (IndexingPipeline, AppState) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-cost-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
          <publicationStmt><p>Test</p></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="volume" xml:id="frus1969-76v01">
          <div type="chapter" xml:id="ch1">
          <div type="document" xml:id="doc-1"><head>Doc 1</head><p>body text</p></div>
          </div></div></body></text>
        </TEI>
        """
        try xml.write(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                      atomically: true, encoding: .utf8)

        let dbURL = dir.appendingPathComponent("test.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volDir)
        let appState = await MainActor.run { AppState() }
        await MainActor.run {
            appState.indexingPipeline = pipeline
            appState.connectIndexingProgress(pipeline: pipeline)
        }
        try await body(pipeline, appState)
    }

    private func waitUntil(
        in appState: AppState,
        timeout: Duration = .seconds(10),
        _ predicate: @escaping @MainActor (AppState) -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await MainActor.run(body: { predicate(appState) }) { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
}
