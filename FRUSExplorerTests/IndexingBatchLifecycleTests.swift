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

/// `AppState.indexedVolumeIds` across whole-index passes (#1526), driven by a real
/// `IndexingPipeline` and `AppState`'s own progress subscription.
///
/// ## What broke, and why only a real pass shows it
/// `indexAllVolumes()` reports no volume as it finishes it: its one `.complete` names the empty
/// volume id, at the very end. Settings ▸ Rebuild Index emptied the set before such a pass, so the
/// set read `[""]` until a relaunch — every reader of it (Add Documents, working corpora, the
/// Browse-tab badge, the Mac Search window's saved-search run records) saw nothing indexed. A boot
/// re-index kept its boot-seeded set and gained `""`, one too many. Neither is reachable without
/// the pass's own progress stream feeding the subscription the app installs, so these tests run
/// both.
///
/// ## The re-read's journal
/// The re-read runs off the main actor, and a volume can finish indexing or be removed while it
/// does. Its journal is driven through `reseedIndexedVolumeIds(reading:)`, whose reader makes the
/// change mid-read — one test per kind of change, one for a read that fails, and one for a change
/// made before the read began.
///
/// The hubs and boot are pinned to the routing these drive by the source scan at the end.
///
/// Version history:
///   1.0 — #1526: initial implementation
@Suite("Indexing — the indexed-volume set across whole-index passes")
@MainActor
struct IndexedVolumeSetTests {

    private static let volumeIds: Set<String> = ["frus1969-76v01", "frus1969-76v02"]

    private func writeTEIVolume(to url: URL, volumeId: String) throws {
        let docs = (1...3).map {
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

    /// Two volumes, both indexed one at a time and seen by `AppState` as they finish, as a
    /// library is before anyone presses Rebuild Index.
    private func withIndexedLibrary(
        _ body: (IndexingPipeline, AppState) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-indexed-set-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        for volumeId in Self.volumeIds {
            try writeTEIVolume(to: volDir.appendingPathComponent("\(volumeId).xml"), volumeId: volumeId)
        }
        let dbURL = dir.appendingPathComponent("test.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volDir,
                                            concurrencyLimit: 1)
        let appState = AppState()
        appState.indexingPipeline = pipeline
        appState.connectIndexingProgress(pipeline: pipeline)
        for volumeId in Self.volumeIds.sorted() {
            try await pipeline.indexVolume(volumeId)
        }
        let seen = await waitUntil(timeout: .seconds(10)) { appState.indexedVolumeIds == Self.volumeIds }
        try #require(seen, "precondition: the per-volume passes reach the set (\(appState.indexedVolumeIds.sorted()))")
        try await body(pipeline, appState)
    }

    /// Polls until `predicate` holds or the timeout passes, yielding the main actor between polls
    /// so the progress subscription can run.
    private func waitUntil(timeout: Duration, _ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return predicate()
    }

    /// Gives a pass's end-of-pass `.complete` — the empty id — time to reach the set, which it does
    /// within milliseconds when nothing refuses it. `true` when it got there.
    private func emptyIdArrives(in appState: AppState) async -> Bool {
        await waitUntil(timeout: .seconds(3)) { appState.indexedVolumeIds.contains("") }
    }

    @Test("After Rebuild Index the set is what the index holds, not empty and not [\"\"]")
    func rebuildLeavesTheSetEqualToTheIndex() async throws {
        try await withIndexedLibrary { pipeline, appState in
            let rebuilt = await appState.rebuildSearchIndex(pipeline: pipeline)
            #expect(rebuilt, "the wipe failed")
            let leaked = await emptyIdArrives(in: appState)

            let held = try pipeline.allIndexedVolumeIds()
            #expect(held == Self.volumeIds, "precondition: the pass re-indexed both volumes (\(held.sorted()))")
            #expect(appState.indexedVolumeIds == held, """
                After Rebuild Index the app's set reads \(appState.indexedVolumeIds.sorted()) while \
                the index holds \(held.sorted()). The pass reports no volume as it finishes it, so \
                without a re-read the set stays as the wipe left it until a relaunch (#1526).
                """)
            #expect(!leaked, "the pass's end-of-pass signal was stored as a volume id")
        }
    }

    @Test("A boot re-index leaves the set's count as it was, not one too high")
    func bootPassDoesNotAddAVolume() async throws {
        try await withIndexedLibrary { pipeline, appState in
            await appState.indexAllVolumes(with: pipeline)
            let leaked = await emptyIdArrives(in: appState)

            #expect(appState.indexedVolumeIds == Self.volumeIds, """
                After a whole-index pass over an indexed library the set reads \
                \(appState.indexedVolumeIds.sorted()); it should still name the two volumes \
                (#1526: build 48's boot re-index left it one too high).
                """)
            #expect(!leaked)
        }
    }

    @Test("A pass's end-of-pass signal, which names no volume, is never stored")
    func endOfPassSignalIsNotAVolume() async throws {
        try await withIndexedLibrary { pipeline, appState in
            // The boot FTS-rebuild branch: a whole pass with no re-read after it, so only the
            // subscription's own refusal keeps its empty id out.
            try await pipeline.rebuildSearchIndexFromCache()
            let leaked = await emptyIdArrives(in: appState)

            #expect(!leaked, """
                The set gained an empty volume id from the pass's closing `.complete`: \
                \(appState.indexedVolumeIds.sorted()). Every count read from the set is one too high \
                until a relaunch (#1526).
                """)
            #expect(appState.indexedVolumeIds == Self.volumeIds)
        }
    }

    @Test("A volume that finishes indexing while the index is re-read stays in the set")
    func anIndexingDuringTheReadSurvivesIt() async {
        let appState = AppState()
        appState.indexedVolumeIds = ["a"]
        await appState.reseedIndexedVolumeIds(reading: {
            // Finishes while the read is in flight: the read's answer predates it.
            await MainActor.run { appState.markVolumeIndexed("late") }
            return ["a"]
        })
        #expect(appState.indexedVolumeIds == ["a", "late"], """
            A volume that finished indexing during the re-read was dropped by it: \
            \(appState.indexedVolumeIds.sorted()). It would read "not indexed" until a relaunch.
            """)
    }

    @Test("A volume removed while the index is re-read stays out of the set")
    func aRemovalDuringTheReadSurvivesIt() async {
        let appState = AppState()
        appState.indexedVolumeIds = ["a", "b"]
        await appState.reseedIndexedVolumeIds(reading: {
            await MainActor.run { appState.markVolumeUnindexed("b") }
            return ["a", "b"]
        })
        #expect(appState.indexedVolumeIds == ["a"], """
            A volume removed during the re-read came back with it: \
            \(appState.indexedVolumeIds.sorted()).
            """)
    }

    @Test("An index wiped while it is re-read leaves only what was indexed after the wipe")
    func aWipeDuringTheReadSurvivesIt() async {
        let appState = AppState()
        appState.indexedVolumeIds = ["a", "b"]
        await appState.reseedIndexedVolumeIds(reading: {
            await MainActor.run {
                appState.clearIndexedVolumeIds()
                appState.markVolumeIndexed("after")
            }
            return ["a", "b"]
        })
        #expect(appState.indexedVolumeIds == ["after"], """
            An erase during the re-read was undone by it, or the indexing after the erase was lost: \
            \(appState.indexedVolumeIds.sorted()).
            """)
    }

    @Test("A re-read that fails leaves the set as it was")
    func aFailedReadKeepsTheSet() async {
        let appState = AppState()
        appState.indexedVolumeIds = ["a"]
        await appState.reseedIndexedVolumeIds(reading: { nil })
        #expect(appState.indexedVolumeIds == ["a"], "a failed read emptied the set")
    }

    @Test("A re-read never stores an empty volume id")
    func aReadNeverStoresAnEmptyId() async {
        let appState = AppState()
        await appState.reseedIndexedVolumeIds(reading: { ["a", ""] })
        #expect(appState.indexedVolumeIds == ["a"])
    }

    @Test("A change made before a re-read began is not replayed over its answer")
    func theJournalHoldsOnlyChangesDuringARead() async {
        let appState = AppState()
        appState.markVolumeIndexed("before")
        await appState.reseedIndexedVolumeIds(reading: { ["a"] })
        #expect(appState.indexedVolumeIds == ["a"], """
            A change made before the re-read began was replayed over its answer: \
            \(appState.indexedVolumeIds.sorted()). The read already saw it, or it was undone since.
            """)
    }

    // MARK: - The routing

    /// The app's Swift sources, `FRUSExplorer/` and `FRUSCoreKit/` through `AppSourceTree`, for the
    /// scan, with their repository-relative paths: the pipeline whose pass the rule routes is in the kit.
    private static func appSources() throws -> [(path: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var sources: [(String, String)] = []
        for url in AppSourceTree.swiftFiles(in: root) {
            let text = try String(contentsOf: url, encoding: .utf8)
            sources.append((url.path.replacingOccurrences(of: root.path + "/", with: ""), text))
        }
        return sources
    }

    /// The lines of `text` that are code, not `//` comments, with their 1-based numbers.
    private static func codeLines(_ text: String) -> [(number: Int, line: String)] {
        text.components(separatedBy: "\n").enumerated().compactMap { index, line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? nil : (index + 1, line)
        }
    }

    @Test("Every whole-index pass in the app re-reads the set, and every write to the set is journalled")
    func everyPassAndEveryWriteGoesThroughAppState() throws {
        let sources = try Self.appSources()
        #expect(sources.count > 100, "scanned only \(sources.count) app files")

        var passes: [String] = []
        var writes: [String] = []
        var appStateWrites = 0
        let write = try Regex(#"appState\.indexedVolumeIds\s*(=[^=]|\.(insert|remove|formUnion|subtract|removeAll)\()"#)
        for source in sources {
            for (number, line) in Self.codeLines(source.text) {
                if line.contains(".indexAllVolumes()"), source.path != "FRUSExplorer/App/AppState.swift",
                   source.path != "FRUSCoreKit/Search/IndexingPipeline.swift" {
                    passes.append("\(source.path):\(number): \(line)")
                }
                if line.contains(write) { writes.append("\(source.path):\(number): \(line)") }
                if line.contains("appState.markVolumeUnindexed(") || line.contains("appState.clearIndexedVolumeIds()") {
                    appStateWrites += 1
                }
            }
        }
        #expect(passes.isEmpty, """
            These run a whole-index pass without `AppState.indexAllVolumes(with:)`, so the set is not \
            re-read after it (#1526):
            \(passes.joined(separator: "\n"))
            """)
        #expect(writes.isEmpty, """
            These write AppState's indexed-volume set directly, so a re-read in flight undoes them. \
            Use markVolumeIndexed / markVolumeUnindexed / clearIndexedVolumeIds:
            \(writes.joined(separator: "\n"))
            """)
        // The removal routing, the deleted-volume hook and Erase Local Data: the scan must have
        // found the writers it is about, or it passes over code that no longer looks like this.
        #expect(appStateWrites >= 3, "found only \(appStateWrites) journalled writes outside AppState")

        // Calls read from code lines only, so one that has been commented out does not count.
        let byPath = Dictionary(uniqueKeysWithValues: sources.map { source in
            (source.path, Self.codeLines(source.text).map(\.line).joined(separator: "\n"))
        })
        for hub in ["FRUSExplorer/Settings/VolumesStorageHubView.swift",
                    "FRUSExplorer/Settings/MacVolumesStorageHub.swift"] {
            let text = try #require(byPath[hub], "\(hub) moved")
            #expect(text.contains("await appState.rebuildSearchIndex(pipeline: pipeline)"),
                    "\(hub)'s Rebuild Index does not go through AppState.rebuildSearchIndex(pipeline:)")
        }
        let app = try #require(byPath["FRUSExplorer/App/FRUSExplorerApp.swift"])
        #expect(app.contains("await appState.indexAllVolumes(with: pipeline)"),
                "boot's date re-index does not go through AppState.indexAllVolumes(with:)")
    }
}
