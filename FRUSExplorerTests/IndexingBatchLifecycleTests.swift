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

/// The indexing queue's lifecycle, driven by a real `IndexingPipeline` over two volumes.
///
/// ## Why this needs a real pipeline
/// `IndexingBatchPositionTests` covers the shape of the state; this covers the thing that
/// actually broke, which was the *transition* between two volumes. Both prior defects
/// lived exclusively in that transition and neither was reachable from a unit test that
/// assigned the state directly:
///
/// - #541: the batch counters reset on every volume because the "is this a new batch?"
///   test consulted the download queue, which drains before indexing does. The total was
///   pinned at 1 and the queue banner never appeared.
/// - This change: the banner's *presence* followed `currentIndexingProgress`, which goes
///   `nil` in that same transition — so it strobed once per volume.
///
/// Both are only observable by running two volumes through the stream in sequence, which
/// is exactly what these tests do.
///
/// Version history:
///   1.0 — queue-grained indexing banner
@Suite("Indexing — queue lifecycle across volumes")
struct IndexingBatchLifecycleTests {

    // MARK: - Harness

    private func writeTEIVolume(to url: URL, volumeId: String, documentCount: Int) throws {
        let docs = (1...documentCount).map {
            "<div type=\"document\" xml:id=\"doc-\($0)\"><head>Doc \($0)</head><p>body text</p></div>"
        }.joined()
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
          <publicationStmt><p>Test</p></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="volume" xml:id="\(volumeId)">
          <div type="chapter" xml:id="ch1">\(docs)</div>
          </div></body></text>
        </TEI>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func withTwoVolumePipeline(
        _ body: (IndexingPipeline, AppState) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-batch-lifecycle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                           volumeId: "frus1969-76v01", documentCount: 3)
        try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                           volumeId: "frus1969-76v02", documentCount: 3)

        let dbURL = dir.appendingPathComponent("test.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volDir)
        let appState = await MainActor.run { AppState() }
        await MainActor.run {
            // The queue consults the pipeline for the real backlog; without this the
            // batch would end on the first volume for want of anything to ask.
            appState.indexingPipeline = pipeline
            appState.connectIndexingProgress(pipeline: pipeline)
        }
        try await body(pipeline, appState)
    }

    /// Polls the main actor until `predicate` holds, or the deadline passes.
    ///
    /// The progress stream delivers asynchronously and the backlog query hops off the
    /// main actor and back, so every assertion here is on eventual state. A fixed sleep
    /// flakes under full-suite load.
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

    // MARK: - Tests

    @Test("A queue opens on the first volume and covers the whole backlog")
    func queueOpensAndCoversTheBacklog() async throws {
        try await withTwoVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")

            // The backlog query is what raises the total past the provisional 1.
            let sawQueue = try await waitUntil(in: appState) { ($0.indexingBatch?.total ?? 0) >= 2 }
            #expect(sawQueue, "the queue must count the volume still waiting on disk, not just the one indexing")
            let position = await MainActor.run { appState.indexingQueuePosition }
            #expect(position != nil, "which is what makes the multi-volume banner appear at all")
        }
    }

    @Test("The queue survives the first volume finishing — the banner does not strobe")
    func queueSurvivesTheFirstVolume() async throws {
        try await withTwoVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")
            _ = try await waitUntil(in: appState) { ($0.indexingBatch?.completed ?? 0) >= 1 }

            // The per-volume signal is gone. The queue must not be.
            let progress = await MainActor.run { appState.currentIndexingProgress }
            #expect(progress == nil, "precondition: the pipeline clears the per-volume signal here")

            let batch = await MainActor.run { appState.indexingBatch }
            #expect(batch != nil,
                    "the queue must outlive the volume — this nil is the strobe the owner saw")
            #expect(batch?.latest.volumeId == "frus1969-76v01",
                    "and it must retain an update, or the banner would render an empty name")
        }
    }

    @Test("The second volume accumulates rather than restarting the count (#541 regression)")
    func secondVolumeAccumulates() async throws {
        try await withTwoVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")
            _ = try await waitUntil(in: appState) { ($0.indexingBatch?.completed ?? 0) >= 1 }

            try await pipeline.indexVolume("frus1969-76v02")
            let accumulated = try await waitUntil(in: appState) { ($0.indexingBatch?.completed ?? 0) >= 2 }
            #expect(accumulated,
                    "the old code reset the count to 0 at every gap, so it never reached 2")
        }
    }

    @Test("The queue ends once nothing on disk is left unindexed")
    func queueEndsWhenTheBacklogEmpties() async throws {
        try await withTwoVolumePipeline { pipeline, appState in
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")

            let ended = try await waitUntil(in: appState) { $0.indexingBatch == nil }
            #expect(ended, "with an empty backlog the queue must tear down, or the banner is permanent")

            // Only now may the summary card take the screen — and it should speak for
            // the queue, not for whichever volume happened to finish last.
            let count = await MainActor.run { appState.completedIndexingBatchVolumeCount }
            #expect(count == 2, "\"2 volumes ready to search\" is the fact the user was waiting for")

            // And the other half of the same contract, asserted here rather than in its
            // own test: on its own, `#expect(count == nil)` also passes when the queue
            // never exists at all, so it proves nothing without the `== 2` above it.
            try await pipeline.indexVolume("frus1969-76v01")
            _ = try await waitUntil(in: appState) {
                $0.indexingBatch == nil && $0.completedIndexingBatchVolumeCount == nil
            }
            let single = await MainActor.run { appState.completedIndexingBatchVolumeCount }
            #expect(single == nil, "one volume is not a queue; the card keeps its volume title")
        }
    }

    @Test("A queue whose backlog never empties still ends — the banner cannot get stuck")
    func wedgedQueueEndsOnTheWatchdog() async throws {
        let restore = await MainActor.run { AppState.indexingBatchStallTimeout }
        await MainActor.run { AppState.indexingBatchStallTimeout = 0.4 }
        defer { Task { @MainActor in AppState.indexingBatchStallTimeout = restore } }

        try await withTwoVolumePipeline { pipeline, appState in
            // Index one of two. The backlog keeps the other volume in it forever, which
            // is exactly the shape of a corrupt download the pipeline can never finish —
            // and the shape of a manual one-volume reindex while others sit unindexed.
            try await pipeline.indexVolume("frus1969-76v01")
            let stillQueued = try await waitUntil(in: appState) { ($0.indexingBatch?.completed ?? 0) >= 1 }
            #expect(stillQueued)
            #expect(await MainActor.run { appState.indexingBatch } != nil,
                    "precondition: the non-empty backlog is holding the queue open")

            let ended = try await waitUntil(in: appState, timeout: .seconds(5)) { $0.indexingBatch == nil }
            #expect(ended, "the watchdog must tear a stalled queue down; a permanent banner is worse than an early one")
        }
    }
}
