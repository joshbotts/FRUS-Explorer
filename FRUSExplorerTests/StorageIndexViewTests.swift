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

// MARK: - IndexRemainingSelectionTests (#1689)

/// Index Remaining takes each downloaded volume the index holds no document of, and each one whose last store pass was
/// cut short (#1689, plan of record A14).
///
/// Both hubs had picked with `isVolumeIndexed(_:)` alone, which a volume cut short answers `true`: the batches its pass
/// wrote are in the index. So Index Remaining passed it over, though the iPhone and iPad hub's failure row says to try
/// Index Remaining again. These drive the rule both hubs now call, `IndexRemainingSelection`, over a real index, with the
/// store ended by the pipeline's own test hook after a batch, as `UnfinishedStoreTests` ends it. The hubs are views
/// nothing in this target hosts, and the Mac's is not compiled here, so the last test reads their calls from source.
///
/// Version history:
///   1.0 — #1689: initial implementation
@Suite("Index Remaining takes the volumes not yet fully indexed (#1689)")
struct IndexRemainingSelectionTests {

    /// What the hook throws to end a pass.
    private struct CutShort: Error {}

    /// A temporary directory for one test's index and volumes, removed by the caller.
    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-1689-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes `volumeId` to `volumes` with `count` documents, each holding a word no other document holds.
    private func writeVolume(_ volumeId: String, documents count: Int, to volumes: URL) throws {
        let documents = (1...count).map { n in
            "<div type=\"document\" xml:id=\"d\(n)\"><head>Paper \(n)</head><p>The text holds \(volumeId)word\(n) once.</p></div>"
        }.joined(separator: "\n")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
              <publicationStmt><date>2003</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text><body>
                <div type="compilation" xml:id="comp1">
                  \(documents)
                </div>
              </body></text>
            </TEI>
            """
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
    }

    /// Ends `volumeId`'s next pass after its batch `batch` is stored, with batches of two documents.
    private func cutShort(_ volumeId: String, afterBatch batch: Int, in pipeline: IndexingPipeline) async {
        await pipeline.setTestBatchSize(2)
        await pipeline.setDocumentBatchStoredTestHook { id, stored in
            if id == volumeId, stored == batch { throw CutShort() }
        }
        await #expect(throws: CutShort.self) { try await pipeline.indexVolume(volumeId) }
        await pipeline.setDocumentBatchStoredTestHook(nil)
    }

    @Test("A first pass cut short after its first batch is taken, with the volume not yet indexed, and a whole volume is not")
    func takesAFirstPassCutShort() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        let volumes = dir.appendingPathComponent("volumes")
        try writeVolume("fruswhole", documents: 2, to: volumes)
        try writeVolume("frusshort", documents: 5, to: volumes)
        try writeVolume("frusnever", documents: 2, to: volumes)
        try await pipeline.indexVolume("fruswhole")
        await cutShort("frusshort", afterBatch: 1, in: pipeline)

        // The state the issue names: part of the volume, and a volume that reads as indexed.
        #expect(try pipeline.isVolumeIndexed("frusshort"), "the cut must leave the first batch, or nothing was cut short")
        #expect(try pipeline.volumesWithUnfinishedStore() == ["frusshort"])
        let listed = ["fruswhole", "frusshort", "frusnever"]
        // What both hubs took until #1689: the volume with no document in the index, alone.
        #expect(listed.filter { (try? pipeline.isVolumeIndexed($0)) != true } == ["frusnever"])

        #expect(IndexRemainingSelection.volumeIds(among: listed, pipeline: pipeline) == ["frusshort", "frusnever"],
                "in the order the hub lists them, and without the whole volume")
    }

    @Test("A re-index cut short is taken, though every document of the volume is still in the index")
    func takesAReindexCutShort() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        try writeVolume("frusagain", documents: 5, to: dir.appendingPathComponent("volumes"))
        try await pipeline.indexVolume("frusagain")
        #expect(IndexRemainingSelection.volumeIds(among: ["frusagain"], pipeline: pipeline).isEmpty,
                "a volume whose pass finished is not taken")

        await cutShort("frusagain", afterBatch: 2, in: pipeline)

        // Its earlier pass's rows stand, so only the withdrawn record tells.
        #expect(try await pipeline.documents(forVolume: "frusagain").count == 5)
        #expect(try pipeline.isStoreUnfinished("frusagain"))
        #expect(IndexRemainingSelection.volumeIds(among: ["frusagain"], pipeline: pipeline) == ["frusagain"])
    }

    @Test("A volume the sentinel names is taken, which the launch's reconcile leaves to the reader")
    func takesAVolumeTheSentinelNames() async throws {
        let dir = try makeDirectory()
        let suiteName = "frus.test.indexRemaining.\(UUID().uuidString)"
        defer {
            removeIsolatedStamps(suiteName)
            try? FileManager.default.removeItem(at: dir)
        }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volumes = dir.appendingPathComponent("volumes")
        try writeVolume("frusquit", documents: 5, to: volumes)
        let tracker = IndexingStateTracker(store: makeIsolatedStamps(suiteName))
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL), databaseURL: dbURL,
                                            volumesDirectory: volumes, stateTracker: tracker, concurrencyLimit: 2)
        await cutShort("frusquit", afterBatch: 1, in: pipeline)

        let interrupted = Set(await tracker.interruptedVolumeIds())
        #expect(interrupted == ["frusquit"], "a pass that ends with the app running leaves its sentinel")
        #expect(try pipeline.volumesAwaitingIndex(excluding: interrupted).isEmpty,
                "the launch's reconcile leaves it to the reader")
        #expect(IndexRemainingSelection.volumeIds(among: ["frusquit"], pipeline: pipeline) == ["frusquit"])
    }

    @Test("Pressing Index Remaining again after a pass failed partway finishes the volume, and then takes nothing")
    func aSecondPressFinishesTheVolume() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        let volumes = dir.appendingPathComponent("volumes")
        try writeVolume("frusshort", documents: 5, to: volumes)
        try writeVolume("frusnever", documents: 2, to: volumes)
        let listed = ["frusshort", "frusnever"]

        // The first press: its pass over `frusshort` fails after one batch, as the hub's failure row reports.
        await cutShort("frusshort", afterBatch: 1, in: pipeline)
        try await pipeline.indexVolume("frusnever")

        // The second press takes what the first left, and indexes it as the hubs do, one volume after another.
        let second = IndexRemainingSelection.volumeIds(among: listed, pipeline: pipeline)
        #expect(second == ["frusshort"])
        for volumeId in second { try await pipeline.indexVolume(volumeId) }

        #expect(try await pipeline.documents(forVolume: "frusshort").map(\.documentId) == ["d1", "d2", "d3", "d4", "d5"])
        #expect(try pipeline.volumesWithUnfinishedStore().isEmpty)
        #expect(IndexRemainingSelection.volumeIds(among: listed, pipeline: pipeline).isEmpty)
    }

    /// The two hubs' Index Remaining are views nothing in this target hosts, and the Mac's is compiled for the Mac alone,
    /// so their calls are read here: each picks through the rule, indexes what it returns and nothing else, and asks
    /// `isVolumeIndexed(_:)` nothing of its own.
    @Test("Both hubs' Index Remaining index what the rule picks")
    func bothHubsCallTheRule() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in ["FRUSExplorer/Settings/VolumesStorageHubView.swift", "FRUSExplorer/Settings/MacVolumesStorageHub.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            let start = try #require(source.range(of: "private func indexRemaining() async {"), "\(path) has no Index Remaining")
            let body = try #require(WindowTargetingTests.balancedBlock(in: source, from: start.lowerBound))
            let pick = try #require(body.range(of: """
                let remaining = IndexRemainingSelection.volumeIds(among: report.perVolume.map(\\.volumeId), pipeline: pipeline)
                """), "\(path) does not pick through the rule")
            let loop = try #require(body.range(of: "for (idx, volumeId) in remaining.enumerated() {"), "\(path) indexes something else")
            let index = try #require(body.range(of: "try await pipeline.indexVolume(volumeId)"), "\(path) indexes something else")
            #expect(pick.upperBound < loop.lowerBound && loop.upperBound < index.lowerBound, "\(path)")
            #expect(!body.contains("isVolumeIndexed"), "\(path) picks by `isVolumeIndexed(_:)` beside the rule")
        }
    }
}
