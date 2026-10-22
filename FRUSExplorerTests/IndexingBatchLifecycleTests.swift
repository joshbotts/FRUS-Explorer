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

/// Browse's **Index Now** leaves `AppState` hearing the indexing pipeline, because the app reads the
/// pipeline's `progressStream` in one place, `AppState.connectIndexingProgress(pipeline:)`.
///
/// ## What broke
/// `BrowserViewModel.indexVolume(_:)` read the stream in a task of its own, beside the loop `AppState`
/// starts at launch. An `AsyncStream` hands each update to ONE of the readers waiting on it, so the two
/// split the volume's updates between them, and the view model cancelled its task when the pass
/// returned. When that task had not had the volume's last update (`.complete`, or since #1695
/// `.failed`) it was still waiting in the stream's `next()`, and cancelling a task that waits there ends
/// the stream for every reader. `AppState` then heard nothing more until the app was launched again: no
/// banner, no Live Activity, no queue, and no volume recorded as indexed. Found by reading in A11
/// (#1695) and shown there with a standalone script; these tests show it in the app, on iOS's Browse ▸
/// compilation ▸ Index Now path.
///
/// ## Which reader the fixture gives the last update to
/// Index Now's volume has four documents, stored two at a time, and the pipeline is held after each
/// batch until the main actor has run, so both readers are waiting again before the next update goes
/// out. `AppState` has waited longest (it heard a volume indexed before Index Now), so it takes the
/// first update, the view model's task the second, and so on: the fifth and last is `AppState`'s. That
/// is the case that cut `AppState` off, and on the code before the fix the first test then fails at the
/// next volume. The two `.reading` updates and the first batch's go out unheld; if the turns slip there,
/// the task takes the last update instead, `AppState` never hears the volume end, and the test fails at
/// the volume itself. Either way it fails on that code, every run: measured 6 runs of 6, each in the
/// first case (three of each kind of pass, iPhone 17 simulator, iOS 27.0).
///
/// ## The rest
/// The view model now shows `AppState.currentIndexingProgress` for its volume, which `CompilationView`
/// hands it as that changes; the second test holds it to that. The last two read the source: each of
/// the pipeline's two streams is read in one place in the app, `AppState`'s subscription, and the
/// compilation passes `AppState`'s progress on.
///
/// Version history:
///   1.0 — 2026-10-20: initial implementation
@Suite("Index Now — AppState stays the indexing pipeline's one reader", .serialized)
@MainActor
struct IndexNowProgressReaderTests {

    /// Indexed through the pipeline before Index Now, so `AppState` is the reader waiting longest.
    private static let earlier = "frus1969-76v01"
    /// The volume Index Now indexes.
    private static let indexedNow = "frus1969-76v02"
    /// Indexed through the pipeline after Index Now.
    private static let later = "frus1969-76v03"

    /// How the Index Now pass ends.
    enum PassEnd: String, CaseIterable, Sendable {
        /// The pass stores every document and sends `.complete`.
        case completes
        /// The pass throws after its second batch and sends `.failed` (#1695).
        case fails
    }

    /// Thrown by the batch hook to end a pass, as a store that fails does.
    private struct StoreStopped: Error {}

    /// What `AppState` showed while the later volume's pass was held after its store.
    @MainActor
    private final class Sighting {
        /// The volume `AppState.currentIndexingProgress` named.
        var progressVolumeId: String?
        /// The volume of the indexing queue's latest update.
        var queueVolumeId: String?

        /// Reads `appState`, and answers `true` once its progress names `volumeId`.
        func look(at appState: AppState, for volumeId: String) -> Bool {
            progressVolumeId = appState.currentIndexingProgress?.volumeId
            queueVolumeId = appState.indexingBatch?.latest.volumeId
            return progressVolumeId == volumeId
        }
    }

    /// What the view model kept while its Index Now pass was held after its store.
    @MainActor
    private final class Readings {
        /// The volume the view model said it was indexing.
        var indexingVolumeId: String?
        /// Its progress once handed `AppState.currentIndexingProgress`.
        var fromAppState: IndexingProgressUpdate?
        /// Its progress once then handed another volume's update.
        var afterAnotherVolume: IndexingProgressUpdate?
        /// Its progress once then handed `nil`, as `AppState` sets at a volume's end.
        var afterNil: IndexingProgressUpdate?
    }

    // MARK: - Harness

    private func writeVolume(_ volumeId: String, documents: Int, in directory: URL) throws {
        let docs = (1...documents).map {
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
        try xml.write(to: directory.appendingPathComponent("\(volumeId).xml"), atomically: true, encoding: .utf8)
    }

    private static func entry(_ volumeId: String) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId, filename: "\(volumeId).xml", subseries: "1969-76",
            title: "Fixture \(volumeId)",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2000", status: .published,
            editors: [], generalEditor: nil,
            sizeBytes: 0, tags: []
        )
    }

    /// Polls until `predicate` holds or the timeout passes, yielding the main actor between polls so
    /// the progress subscription can run.
    private func waitUntil(timeout: Duration = .seconds(5), _ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return predicate()
    }

    /// Three volumes on disk, a pipeline over them that `AppState` reads as boot connects it, the
    /// earlier volume indexed and heard, and a view model on the same pipeline, as Browse builds it.
    private func withLibrary(
        _ body: (IndexingPipeline, AppState, BrowserViewModel) async throws -> Void
    ) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-index-now-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try writeVolume(Self.earlier, documents: 3, in: volDir)
        try writeVolume(Self.indexedNow, documents: 4, in: volDir)
        try writeVolume(Self.later, documents: 3, in: volDir)
        let dbURL = dir.appendingPathComponent("test.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volDir)
        let appState = AppState()
        appState.indexingPipeline = pipeline
        appState.connectIndexingProgress(pipeline: pipeline)
        try await pipeline.indexVolume(Self.earlier)
        let heard = await waitUntil { appState.indexedVolumeIds.contains(Self.earlier) }
        try #require(heard, "precondition: AppState hears a pass made before Index Now")
        let viewModel = BrowserViewModel(manifestStore: ManifestStore(bundledEntries: []),
                                         tagStore: VolumeLevelTagStore(), downloadManager: nil,
                                         indexingPipeline: pipeline)
        try await body(pipeline, appState, viewModel)
    }

    // MARK: - Tests

    @Test("After Index Now, AppState hears its volume end and hears the volume indexed next",
          arguments: PassEnd.allCases)
    func appStateHearsIndexNowAndTheVolumeAfterIt(_ end: PassEnd) async throws {
        try await withLibrary { pipeline, appState, viewModel in
            // Index Now's volume in two batches, each held until the main actor has run.
            let indexedNow = Self.indexedNow
            await pipeline.setTestBatchSize(2)
            await pipeline.setDocumentBatchStoredTestHook { volumeId, batch in
                guard volumeId == indexedNow else { return }
                for _ in 0..<3 { await MainActor.run {} }
                if end == .fails, batch == 2 { throw StoreStopped() }
            }
            await viewModel.indexVolume(Self.entry(indexedNow))
            await pipeline.setDocumentBatchStoredTestHook(nil)
            switch end {
            case .completes:
                #expect(viewModel.indexingError == nil,
                        "fixture: the pass threw \(String(describing: viewModel.indexingError))")
            case .fails:
                #expect(viewModel.indexingError is StoreStopped,
                        "fixture: the pass did not end at the hook's throw")
            }

            // AppState heard Index Now's pass end.
            let heardTheEnd = await waitUntil {
                switch end {
                case .completes: return appState.indexedVolumeIds.contains(indexedNow)
                case .fails: return appState.indexingBatch?.failedVolumeIds.contains(indexedNow) == true
                }
            }
            #expect(heardTheEnd, """
                AppState did not hear the volume Index Now indexed \(end == .completes ? "finish" : "fail"): \
                its progress still names \(appState.currentIndexingProgress?.volumeId ?? "no volume") \
                at \(String(describing: appState.currentIndexingProgress?.stage)). Another reader of the \
                pipeline's progress stream took that update; each update reaches one reader.
                """)

            // And it hears the volume indexed next while that pass is under way: the pass is held after
            // its store, before its `.complete`, until AppState's progress names it.
            let later = Self.later
            let sighting = Sighting()
            await pipeline.setVolumeStoredTestHook { volumeId in
                guard volumeId == later else { return }
                let deadline = ContinuousClock.now + .seconds(10)
                while ContinuousClock.now < deadline {
                    if await MainActor.run(body: { sighting.look(at: appState, for: later) }) { return }
                    try? await Task.sleep(for: .milliseconds(20))
                }
            }
            try await pipeline.indexVolume(later)
            await pipeline.setVolumeStoredTestHook(nil)
            #expect(sighting.progressVolumeId == later, """
                AppState showed no progress for the volume indexed after Index Now (it showed \
                \(sighting.progressVolumeId ?? "none")): it had stopped hearing the pipeline. Cancelling a \
                reader that waits on an AsyncStream ends the stream for every reader.
                """)
            #expect(sighting.queueVolumeId == later,
                    "and the indexing queue did not move on to it (\(sighting.queueVolumeId ?? "no queue"))")
            let recorded = await waitUntil { appState.indexedVolumeIds.contains(later) }
            #expect(recorded, "AppState did not record the later volume indexed: \(appState.indexedVolumeIds.sorted())")
        }
    }

    @Test("Index Now shows AppState's progress for its own volume, and keeps the last of it until its pass returns")
    func indexNowShowsAppStatesProgressForItsVolume() async throws {
        try await withLibrary { pipeline, appState, viewModel in
            let indexedNow = Self.indexedNow
            let another = IndexingProgressUpdate(volumeId: Self.later, stage: .reading,
                                                 completedDocuments: 0, totalDocuments: 3, docsPerSecond: 0)
            viewModel.updateIndexingProgress(from: IndexingProgressUpdate(
                volumeId: indexedNow, stage: .reading, completedDocuments: 0, totalDocuments: 4, docsPerSecond: 0))
            #expect(viewModel.indexingProgress == nil, "progress was kept while no Index Now was running")

            // The pass is held after its store, with its updates sent and AppState's progress on it, and
            // the view model is handed what CompilationView hands it as that progress changes.
            let readings = Readings()
            await pipeline.setVolumeStoredTestHook { volumeId in
                guard volumeId == indexedNow else { return }
                await MainActor.run {
                    readings.indexingVolumeId = viewModel.indexingVolumeId
                    viewModel.updateIndexingProgress(from: appState.currentIndexingProgress)
                    readings.fromAppState = viewModel.indexingProgress
                    viewModel.updateIndexingProgress(from: another)
                    readings.afterAnotherVolume = viewModel.indexingProgress
                    viewModel.updateIndexingProgress(from: nil)
                    readings.afterNil = viewModel.indexingProgress
                }
            }
            await viewModel.indexVolume(Self.entry(indexedNow))
            await pipeline.setVolumeStoredTestHook(nil)

            #expect(readings.indexingVolumeId == indexedNow, "the view model did not name the volume it was indexing")
            let shown = try #require(readings.fromAppState, """
                The view model kept none of AppState's progress for the volume it was indexing, so Index Now \
                would draw "Preparing…" for the whole pass.
                """)
            #expect(shown.volumeId == indexedNow)
            #expect(readings.afterAnotherVolume == shown, "another volume's update replaced Index Now's")
            #expect(readings.afterNil == shown,
                    "AppState's nil at a volume's end cleared Index Now's progress before its pass returned")
            #expect(viewModel.indexingProgress == nil && viewModel.indexingVolumeId == nil && !viewModel.isIndexing,
                    "the pass's end did not clear Index Now's progress")
        }
    }

    @Test("The app reads each of the pipeline's two progress streams in one place, AppState's subscription")
    func eachProgressStreamHasOneReader() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let files = AppSourceTree.swiftFiles(in: root)
        #expect(files.count > 100, "scanned only \(files.count) app files")
        // Each stream, and what anything else that wants its news reads instead.
        let streams = [".progressStream": "currentIndexingProgress", ".metadataStream": "lastDiscoveredMetadata"]
        var readers: [String: [String]] = [:]
        for url in files {
            let path = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                // The code before any `//`: a comment that names a stream is not a reader of it.
                let code = line.components(separatedBy: "//")[0]
                for stream in streams.keys where code.contains(stream) {
                    readers[stream, default: []].append("\(path):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        for (stream, instead) in streams.sorted(by: { $0.key < $1.key }) {
            let found = readers[stream] ?? []
            #expect(found.count == 1 && found.first?.hasPrefix("FRUSExplorer/App/AppState.swift:") == true, """
                The app must read `IndexingPipeline\(stream)` in one place, \
                `AppState.connectIndexingProgress(pipeline:)`. An AsyncStream hands each element to one of \
                the readers waiting on it, so another reader takes elements AppState never sees, and \
                cancelling one that waits ends the stream for AppState too. Read `AppState.\(instead)` \
                instead. Found:
                \(found.joined(separator: "\n"))
                """)
        }
    }

    @Test("Browse's compilation passes AppState's progress to the view model as it changes")
    func theCompilationPassesAppStatesProgressOn() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Browser/CompilationView.swift"),
                              encoding: .utf8)
        let code = text.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let forward = try Regex(#"\.onChange\(of: appState\.currentIndexingProgress\) \{ _, progress in\s*vm\.updateIndexingProgress\(from: progress\)"#)
        #expect(code.contains(forward), """
            CompilationView no longer hands AppState's progress to the view model as it changes, so Index \
            Now's progress section would read "Preparing…" for the whole pass. The view model reads no \
            stream of its own (`IndexNowProgressReaderTests`).
            """)
    }
}

// MARK: - IndexingQueueCountTests

/// The queue counts every volume it holds, its downloads included (#1757), driven through
/// `AppState`'s own progress path with a real pipeline.
///
/// ## What broke
/// The total was the download queue's length plus one, taken when the first volume began
/// indexing, and raised afterwards only by the backlog on disk, which a volume reaches only once
/// it has landed. Measured on an iPhone 17 simulator (iOS 27.0) on 2026-10-22, a 27-volume
/// subseries still being queued opened at "Volume 1 of 20" and read "20 of 20" with seven volumes
/// to come; the volume that opened a queue, still listed as downloading, was counted twice
/// ("Volume 1 of 12" for eleven); and the Live Activity took a new total only with the next
/// volume's first update.
///
/// A volume named here and not written to disk stands for a download still to come. The queue
/// learns of it as the app's download manager reports it: through `downloadQueue`, which its
/// `onStateChanged` sets, and `indexingQueueTransferDidFinish(_:outcome:)`, which its
/// `onTransferFinished` calls.
///
/// Version history:
///   1.0 — #1757: initial implementation
@Suite("Indexing — the queue counts what is still to download (#1757)")
@MainActor
struct IndexingQueueCountTests {

    /// Writes a volume of three small documents into `directory`.
    private static func writeVolume(_ volumeId: String, in directory: URL) throws {
        let documents = (1...3).map {
            "<div type=\"document\" xml:id=\"d\($0)\"><head>Document \($0)</head><p>Body \($0).</p></div>"
        }.joined()
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
          <publicationStmt><p>Test</p></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="volume" xml:id="\(volumeId)">
          <div type="chapter" xml:id="ch1">\(documents)</div>
          </div></body></text>
        </TEI>
        """.write(to: directory.appendingPathComponent("\(volumeId).xml"), atomically: true, encoding: .utf8)
    }

    /// `onDisk` written to a volumes folder, an `AppState` subscribed to their pipeline as the
    /// app's boot subscribes it, and the stand-in in place of the system's Live Activities.
    private func withLibrary(
        _ onDisk: [String],
        _ body: (IndexingPipeline, AppState, RecordingLiveActivityHost) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-queue-count-\(UUID().uuidString)")
        let volumes = directory.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for volumeId in onDisk { try Self.writeVolume(volumeId, in: volumes) }
        let databaseURL = directory.appendingPathComponent("test.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: databaseURL),
                                            databaseURL: databaseURL, volumesDirectory: volumes)
        let appState = AppState()
        let host = RecordingLiveActivityHost()
        appState.liveActivityHost = host
        // The queue asks the pipeline what waits on disk.
        appState.indexingPipeline = pipeline
        appState.connectIndexingProgress(pipeline: pipeline)
        try await body(pipeline, appState, host)
    }

    /// Whether `predicate` holds within `timeout`: the progress stream and the backlog query are
    /// asynchronous, so the queue's state is read as it comes to be.
    private func eventually(within timeout: Duration = .seconds(10), _ predicate: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return predicate()
    }

    @Test("A queue counts the downloads still to come, those queued after it began included, and a landing moves nothing")
    func countsTheDownloadsToCome() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, _ in
            // Two more of the subseries are still downloading as the first begins to index.
            appState.downloadQueue = ["frus1969-76v02", "frus1969-76v03"]
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch?.completed == 1 }, "the queue never saw its first volume finish")
            #expect(appState.indexingBatch?.total == 3)

            // The download sheet was still queuing: a fourth joins the queue after it began.
            appState.downloadQueue = ["frus1969-76v02", "frus1969-76v03", "frus1969-76v04"]
            #expect(appState.indexingBatch?.total == 4, "a volume queued after the queue began went uncounted")

            // The second lands: it leaves the download queue for the disk, and the total holds.
            appState.downloadQueue = ["frus1969-76v03", "frus1969-76v04"]
            appState.indexingQueueTransferDidFinish("frus1969-76v02", outcome: .succeeded)
            let position = appState.indexingQueuePosition
            #expect(position?.current == 2)
            #expect(position?.total == 4)
            #expect(appState.indexingBatch?.volumeIds
                    == ["frus1969-76v02", "frus1969-76v03", "frus1969-76v01", "frus1969-76v04"])
        }
    }

    @Test("The volume that opens a queue is counted once while it is still listed as downloading")
    func theOpeningVolumeCountsOnce() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, _ in
            // Its own download's state change has not arrived yet when its first update does.
            appState.downloadQueue = ["frus1969-76v01", "frus1969-76v02"]
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch?.completed == 1 }, "the queue never saw its first volume finish")
            #expect(appState.indexingBatch?.total == 2, "counted twice, it read Volume 1 of 3")
        }
    }

    @Test("A download cancelled or failed for good leaves the count, and a volume already indexed stays in it")
    func aCancelledDownloadLeavesTheCount() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, _ in
            appState.downloadQueue = ["frus1969-76v02", "frus1969-76v03", "frus1969-76v04"]
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch?.completed == 1 }, "the queue never saw its first volume finish")
            #expect(appState.indexingBatch?.total == 4)

            // Cancelled in Volumes & Storage's Active Downloads.
            appState.downloadQueue = ["frus1969-76v02", "frus1969-76v03"]
            appState.indexingQueueTransferDidFinish("frus1969-76v04", outcome: .cancelled)
            #expect(appState.indexingBatch?.total == 3)
            // Failed with its retries spent.
            appState.downloadQueue = ["frus1969-76v02"]
            appState.indexingQueueTransferDidFinish(
                "frus1969-76v03",
                outcome: .failed(DownloadFailure(urlErrorCode: .timedOut, description: "The request timed out.")))
            #expect(appState.indexingBatch?.total == 2)
            // A download of the volume already indexed in this queue, cancelled: its pass stands.
            appState.indexingQueueTransferDidFinish("frus1969-76v01", outcome: .cancelled)
            #expect(appState.indexingBatch?.total == 2)
            let position = appState.indexingQueuePosition
            #expect(position?.current == 2)
            #expect(position?.total == 2)
        }
    }

    @Test("A download that landed before the queue began is counted when it begins")
    func aLandedDownloadIsCounted() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, _ in
            // frus1969-76v09 landed a moment before: it has left the download queue, and in this
            // fixture it is not on disk, so only its landing names it, as for a re-downloaded volume
            // whose index rows keep it out of the backlog while its pass begins.
            appState.indexingQueueTransferDidFinish("frus1969-76v09", outcome: .succeeded)
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch?.completed == 1 }, "the queue never saw its first volume finish")
            #expect(appState.indexingBatch?.total == 2)
            #expect(appState.indexingBatch?.volumeIds == ["frus1969-76v09", "frus1969-76v01"])
        }
    }

    @Test("The queue's Live Activity takes a new total at once, while the queue waits between two volumes")
    func theLiveActivityKeepsInStep() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host in
            appState.downloadQueue = ["frus1969-76v02"]
            try await pipeline.indexVolume("frus1969-76v01")
            // The first volume shown finished, as the first of two.
            #expect(try await eventually {
                host.shown.last.map { $0.queueCurrent == 1 && $0.queueTotal == 2 && $0.progressFraction == 1 } ?? false
            }, "the activity never showed the first volume finished")
            let sent = host.updates.count

            // Two more queued while nothing indexes: no progress update comes until one lands.
            appState.downloadQueue = ["frus1969-76v02", "frus1969-76v03", "frus1969-76v04"]
            #expect(host.updates.count > sent, "the new total did not reach the activity")
            let shown = try #require(host.shown.last)
            #expect(shown.queueTotal == 4)
            #expect(shown.queueCurrent == 1)
            #expect(shown.progressFraction == 1, "it still shows the volume that finished")
            #expect(host.requests.count == 1, "a new total starts no second activity")

            // A cancellation takes one out, on the activity as on the banner.
            appState.indexingQueueTransferDidFinish("frus1969-76v04", outcome: .cancelled)
            #expect(host.shown.last?.queueTotal == 3)
            #expect(appState.indexingQueuePosition?.total == 3)
        }
    }
}
