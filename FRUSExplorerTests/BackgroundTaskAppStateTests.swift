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

#if os(iOS) && DEBUG
import Foundation
import os
import Testing
@testable import FRUSExplorer

/// The iOS background task's launch handler holds the AppState the launch boots (plan of record
/// L11, decision 121).
///
/// ## The defect
/// The handler `FRUSExplorerApp.init()` registers for `bottsywattsy.FRUS-Explorer.indexing` indexes
/// and summarizes through `state.indexingPipeline`, which only the launch's boot sets, and only on
/// the AppState SwiftUI installed. Builds 47 to 1787 gave the handler an AppState of its own. Since
/// Xcode 27.0, `@State` is a macro over `LazyState`, which holds a property's initial value as a
/// closure until SwiftUI installs the property: the `init()`'s read of `appState` ran that closure,
/// and installation ran it again. No line of the app changed; the toolchain did. Every background wake then
/// ended at the handler's first guard with `setTaskCompleted(success: false)`.
///
/// ## Why the instances, and not the source
/// A scan for a `@State` read in an `init` would not have caught this: the read was correct under
/// Xcode 26, whose property wrapper kept the instance the `init()` saw. What the handler depends on
/// is that its AppState IS the booted one, so that is what this compares, in the app this target
/// runs in: whatever separates the two, an edit or the next toolchain, fails it.
///
/// The unit tests run inside the app, so its `init()` has run and its first scene boots on its own.
/// `init()` records the instance it gave the handler (`debugBackgroundTaskAppState`), and the first
/// `bootSearchInfrastructureOnce()` the instance it ran on (`debugBootedAppState`), both DEBUG only.
/// A recorded verdict and a failing test, rather than an `assert` in the app: a trap at launch
/// would kill the host and every test in it.
///
/// Measured on 2026-11-09 against the unfixed `init()` (`7f24463e` with this suite and the two
/// records): it failed at the identity check, both records set and the host booted 4.9 s in.
///
/// Version history:
///   1.0 — L11: the handler's AppState is the booted one
///   1.1 — L12: `BackgroundTaskLaunchBootTests`, below, for a launch made to run the task
///   1.2 — L13: `BackgroundTaskNextRunTests`, below, for the next run a run asks for. L12's suite
///          ends its runs through `IndexingTaskRunEnd` and gives them a batch of summaries that
///          finds nothing to do, where it gave them a model context for the app's batch
@MainActor
struct BackgroundTaskAppStateTests {

    /// How long the host's first boot may take to reach `bootSearchInfrastructureOnce()`, the main
    /// scene's first `.task`. It has normally run before the first test starts.
    private static let bootWait: Duration = .seconds(60)

    @Test("The background task's launch handler holds the AppState the launch boots")
    func handlerHoldsTheBootedAppState() async throws {
        let deadline = ContinuousClock.now + Self.bootWait
        while FRUSExplorerApp.debugBootedAppState == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        let handlerState = try #require(FRUSExplorerApp.debugBackgroundTaskAppState,
                                        "FRUSExplorerApp.init() recorded no AppState for the background task's handler")
        let bootedState = try #require(FRUSExplorerApp.debugBootedAppState,
                                       "The host app's first boot did not reach bootSearchInfrastructureOnce() within \(Self.bootWait)")
        #expect(handlerState === bootedState,
                "The background task's handler holds an AppState the launch never boots, so every background wake ends at its first guard. Never read a @State in an init: make the instance there and hand it to _appState (L11).")
    }
}

/// A launch the system makes to run the background task indexes, as a wake of a booted app does
/// (plan of record L12, decision 122).
///
/// ## The defect
/// A launch made for `bottsywattsy.FRUS-Explorer.indexing` hands the task to the handler at
/// `-[BGTaskScheduler _handleAppLaunch]`, before the main scene's first `.task` has started the
/// boot that sets `indexingPipeline`. The handler read the pipeline first, so such a launch
/// completed `false` at its first guard, 58 ms after the hand-over (measured on L11's code), and
/// only a wake of an app the launch had already booted did any work.
///
/// ## What these drive
/// `FRUSExplorerApp.runIndexingWake(appState:bootSearchInfrastructure:summarizeBatch:end:)`, the
/// handler's whole run, with a boot of their own. It publishes a pipeline over a temporary
/// folder holding one volume that nothing has indexed, after a pause, as the app's boot publishes
/// its pipeline some time after a launch has handed the task over. The handler passes the app's
/// boot, which a test cannot run, since it opens the app's own index. Each test reads what the
/// wake left of the volume and how it ended the run: what it passed to the task's
/// `setTaskCompleted(success:)`, through `IndexingTaskRunEnd`.
@MainActor
struct BackgroundTaskLaunchBootTests {

    /// The fixture's one volume: a catalogue id, which names a downloaded volume's file.
    private static let volumeId = "frus1969-76v01"

    @Test("A launch made to run the task waits for the boot, then indexes")
    func aLaunchWaitsForTheBootThenIndexes() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        try #require(state.indexingPipeline == nil, "A launch made to run the task finds no pipeline")
        let boot = BootProbe()
        let run = TaskRunRecord()
        await FRUSExplorerApp.runIndexingWake(
            appState: state,
            bootSearchInfrastructure: {
                boot.calls += 1
                try? await Task.sleep(for: .milliseconds(50))
                state.indexingPipeline = fixture.pipeline
            },
            summarizeBatch: { false },
            end: run.end)
        #expect(boot.calls == 1, "The wake did not wait for the launch's boot before reading the pipeline")
        #expect(run.completions == [true])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The wake indexed nothing: \(left) is still unindexed")
    }

    @Test("A wake of an app the launch has booted indexes")
    func aWakeOfABootedAppIndexes() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        let run = TaskRunRecord()
        // The boot has run, so waiting for it returns at once, as awaiting its finished task does.
        await FRUSExplorerApp.runIndexingWake(
            appState: state,
            bootSearchInfrastructure: {},
            summarizeBatch: { false },
            end: run.end)
        #expect(run.completions == [true])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The wake indexed nothing: \(left) is still unindexed")
    }

    @Test("A wake whose time runs out during the boot starts no indexing, and the boot finishes")
    func expiryDuringTheBootStartsNoIndexing() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        let boot = BootProbe()
        let run = TaskRunRecord()
        let wake = Task { @MainActor in
            await FRUSExplorerApp.runIndexingWake(
                appState: state,
                bootSearchInfrastructure: {
                    boot.calls += 1
                    // The app's boot is a task of its own, which a scene awaits too, so the wake's
                    // expiry does not cancel it: it runs on and publishes the pipeline.
                    await Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        state.indexingPipeline = fixture.pipeline
                    }.value
                },
                summarizeBatch: { false },
                end: run.end)
        }
        // Expire the wake while it waits for the boot, as the task's expiration handler does.
        let deadline = ContinuousClock.now + .seconds(10)
        while boot.calls == 0, run.completions.isEmpty, ContinuousClock.now < deadline {
            await Task.yield()
        }
        wake.cancel()
        await wake.value
        #expect(boot.calls == 1, "The wake did not wait for the launch's boot")
        #expect(state.indexingPipeline != nil, "The boot did not finish")
        #expect(run.completions == [false])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left == [Self.volumeId], "The wake started indexing after its time ran out")
    }
}

/// A run of the background task that leaves work asks for the next run before it completes the
/// task (plan of record L13, decision 123).
///
/// ## The defect
/// A `BGProcessingTaskRequest` runs once, and only the background-entry observer submitted one. A
/// launch the system makes to run the task never passes through the foreground, so nothing asked
/// for the next run: *Continue in the background* summarized one batch of six each time the reader
/// left the app, and a volume a run's expiry cut short waited until then too.
///
/// ## What these drive
/// `FRUSExplorerApp.handleIndexingTask`, the launch handler's body, around the app's
/// `runIndexingWake` over one volume nothing has indexed. It is given records of the task's
/// completion and of the next run's request, and a batch of summaries of the test's own, since the
/// app's calls the on-device model. Each test reads what the run asked, in order: the request has
/// to come first, since the system may suspend the app as soon as the task completes. The expiry
/// tests call the expiration handler the run set from a queue of their own, as the system calls a
/// task's. Two runs that leave nothing they can advance must ask for nothing, each in a state the
/// background-entry observer's condition reads as work: the indexing queue still showing, and a
/// volume whose pass failed.
@MainActor
struct BackgroundTaskNextRunTests {

    /// The fixture's one volume, which nothing has indexed.
    private static let volumeId = "frus1969-76v01"

    /// A volume the interrupted-indexing sentinel names whose file is not on disk, so its pass
    /// throws (`IndexingError.volumeNotFound`) and no `.complete` removes it.
    private static let missingVolumeId = "frus1969-76v02"

    @Test("A run whose batch of summaries left more asks for the next run, then completes the task")
    func summariesLeftAskForTheNextRun() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        let record = TaskRunRecord()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: { _ in },
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {},
                    // A batch that summarized documents and left the request stored.
                    summarizeBatch: { true },
                    end: end)
            })
        await run.value
        #expect(record.events == [.requestedNextRun, .completed(true)],
                "A run that summarized documents and left more must ask for the next run before it completes the task, or the rest waits until the reader next leaves the app")
    }

    @Test("A run that leaves nothing asks for nothing, though the queue its pass opened is still showing")
    func aFinishedRunAsksForNothing() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        // The app's one reader of the pipeline's progress, which opens the indexing queue
        // (`indexingBatch`) at the pass's first update and ends it after two seconds of quiet.
        state.connectIndexingProgress(pipeline: fixture.pipeline)
        let probe = RunProbe()
        let record = TaskRunRecord()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: { _ in },
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {},
                    summarizeBatch: {
                        // The run's pass has finished by its batch, and the queue it opened shows.
                        probe.queueShowing = await Self.waitUntil { state.indexingBatch != nil }
                        return false
                    },
                    end: end)
            })
        await run.value
        try #require(probe.queueShowing,
                     "The run's pass opened no indexing queue, so this test reads none of what the background-entry observer reads as work")
        #expect(record.events == [.completed(true)],
                "A run that indexed its volume and has no summaries left asked for the next run: the indexing queue still showing is not work")
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The run indexed nothing: \(left) is still unindexed")
    }

    @Test("A run whose volume cannot be indexed asks for nothing, though the volume stays interrupted")
    func aFailedVolumeAsksForNothing() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        state.interruptedVolumeIds = [Self.missingVolumeId]
        let record = TaskRunRecord()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: { _ in },
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {},
                    summarizeBatch: { false },
                    end: end)
            })
        await run.value
        try #require(state.interruptedVolumeIds == [Self.missingVolumeId],
                     "The volume the run could not index left the interrupted set, so this test reads none of what the background-entry observer reads as work")
        #expect(record.events == [.completed(true)],
                "A run asked for the next run on a volume that cannot be indexed, which would wake the app for it as often as the system allows")
    }

    @Test("A run whose time runs out during the boot asks for the next run, then completes the task")
    func expiryDuringTheBootAsksForTheNextRun() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        let probe = RunProbe()
        let record = TaskRunRecord()
        let expiration = ExpirationHandlerBox()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: expiration.keep,
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {
                        probe.bootCalls += 1
                        // The app's boot is a task of its own, which the run's expiry does not
                        // cancel: it runs on and publishes the pipeline.
                        await Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            state.indexingPipeline = fixture.pipeline
                        }.value
                    },
                    summarizeBatch: { false },
                    end: end)
            })
        let waiting = await Self.waitUntil { probe.bootCalls > 0 }
        try #require(waiting, "The run never reached its boot")
        let expired = await expiration.callOffTheMainActor()
        try #require(expired, "The launch handler set no expiration handler on the task")
        await run.value
        #expect(record.events == [.requestedNextRun, .completed(false)],
                "A run whose time ran out did not ask for the next run before completing the task, so the work it was given waits until the reader next leaves the app")
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left == [Self.volumeId], "The run started indexing after its time ran out")
    }

    @Test("A run whose time runs out during its batch of summaries asks for the next run")
    func expiryDuringTheBatchAsksForTheNextRun() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        let probe = RunProbe()
        let record = TaskRunRecord()
        let expiration = ExpirationHandlerBox()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: expiration.keep,
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {},
                    summarizeBatch: {
                        probe.batchCalls += 1
                        // A batch at work until its time runs out, which the app's notices
                        // between documents; it summarized nothing by then.
                        let deadline = ContinuousClock.now + .seconds(10)
                        while !Task.isCancelled, ContinuousClock.now < deadline {
                            try? await Task.sleep(for: .milliseconds(10))
                        }
                        return false
                    },
                    end: end)
            })
        let batching = await Self.waitUntil { probe.batchCalls > 0 }
        try #require(batching, "The run never reached its batch of summaries")
        let expired = await expiration.callOffTheMainActor()
        try #require(expired, "The launch handler set no expiration handler on the task")
        await run.value
        #expect(record.events == [.requestedNextRun, .completed(false)],
                "A run cut short in its batch did not ask for the next run, or asked twice, or completed the task twice")
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The pass the run finished before its batch is not in the index: \(left)")
    }

    @Test("An expiration handler called after the run has ended asks for nothing and completes nothing")
    func expiryAfterTheEndDoesNothing() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        let record = TaskRunRecord()
        let expiration = ExpirationHandlerBox()
        let run = FRUSExplorerApp.handleIndexingTask(
            requestNextRun: record.requestNextRun,
            completeTask: record.completeTask,
            setExpirationHandler: expiration.keep,
            run: { end in
                await FRUSExplorerApp.runIndexingWake(
                    appState: state,
                    bootSearchInfrastructure: {},
                    summarizeBatch: { false },
                    end: end)
            })
        await run.value
        try #require(record.events == [.completed(true)], "The run did not end as a run that leaves nothing does")
        // The system clears a task's expiration handler once the task completes, but it can be
        // calling it as the run ends.
        let expired = await expiration.callOffTheMainActor()
        try #require(expired, "The launch handler set no expiration handler on the task")
        #expect(record.events == [.completed(true)],
                "The expiration handler asked for a run, or completed the task, after the run had ended it")
    }

    /// Polls `predicate` on the main actor until it holds or `timeout` passes, sleeping between
    /// polls so that the run and the progress stream's reader can go on.
    private static func waitUntil(timeout: Duration = .seconds(10), _ predicate: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return predicate()
    }
}

/// How often a wake called the boot it was given.
@MainActor
private final class BootProbe {
    /// The number of calls.
    var calls = 0
}

/// What a run's stand-ins saw, for `BackgroundTaskNextRunTests`.
@MainActor
private final class RunProbe {
    /// The number of calls to the run's boot.
    var bootCalls = 0
    /// The number of calls to the run's batch of summaries.
    var batchCalls = 0
    /// Whether the indexing queue was showing when the run reached its batch of summaries.
    var queueShowing = false
}

/// What a run asked of the system, in order: the next run's request and the task's completion,
/// which `IndexingTaskRunEnd` lets through once between them.
private final class TaskRunRecord: Sendable {
    /// One thing a run asked.
    enum Event: Equatable, Sendable {
        /// A request for the next run: `requestIndexingTaskRun()` in the app.
        case requestedNextRun
        /// The task's completion, with its success: `setTaskCompleted(success:)` in the app.
        case completed(Bool)
    }

    /// Everything asked so far.
    private let recorded: OSAllocatedUnfairLock<[Event]>

    /// An end for `runIndexingWake` that records here, as the launch handler's ends the task.
    let end: FRUSExplorerApp.IndexingTaskRunEnd

    /// An empty record.
    init() {
        let recorded = OSAllocatedUnfairLock<[Event]>(initialState: [])
        self.recorded = recorded
        end = FRUSExplorerApp.IndexingTaskRunEnd(
            requestNextRun: { recorded.withLock { $0.append(.requestedNextRun) } },
            completeTask: { success in recorded.withLock { $0.append(.completed(success)) } })
    }

    /// Everything asked, in order.
    var events: [Event] { recorded.withLock { $0 } }

    /// The values passed to the task's completion, in order.
    var completions: [Bool] {
        events.compactMap { event in
            if case .completed(let success) = event { return success }
            return nil
        }
    }

    /// What `handleIndexingTask` is given as the next run's request.
    var requestNextRun: @Sendable () -> Void {
        { [recorded] in recorded.withLock { $0.append(.requestedNextRun) } }
    }

    /// What `handleIndexingTask` is given as the task's completion.
    var completeTask: @Sendable (Bool) -> Void {
        { [recorded] success in recorded.withLock { $0.append(.completed(success)) } }
    }
}

/// The expiration handler a launch handler set on its task, kept as a `BGProcessingTask` keeps it,
/// for a test to call as the system does.
private final class ExpirationHandlerBox: Sendable {
    /// The handler, once one is set.
    private let handler = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

    /// Keeps `handler`: what `handleIndexingTask` is given as `setExpirationHandler`.
    func keep(_ handler: @escaping @Sendable () -> Void) {
        self.handler.withLock { $0 = handler }
    }

    /// Calls the kept handler on a queue of its own, as the system calls a task's, and waits for it
    /// to return.
    ///
    /// - Returns: Whether a handler had been set.
    func callOffTheMainActor() async -> Bool {
        guard let handler = handler.withLock({ $0 }) else { return false }
        await Task.detached { handler() }.value
        return true
    }
}

/// One volume on disk that nothing has indexed, and a pipeline over it.
private struct WakeFixture: Sendable {
    /// The temporary folder holding the volume and the index.
    let folder: URL
    /// The pipeline a boot publishes.
    let pipeline: IndexingPipeline

    /// Writes one volume, `volumeId`, with one document, and opens a pipeline over it.
    @MainActor
    init(volumeId: String) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-background-wake-tests-\(UUID().uuidString)")
        let volumes = folder.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
          <publicationStmt><p>Test</p></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="volume" xml:id="\(volumeId)">
          <div type="chapter" xml:id="ch1">
          <div type="document" xml:id="d1"><head>Doc 1</head><p>body text</p></div>
          </div></div></body></text>
        </TEI>
        """
        try xml.write(to: volumes.appendingPathComponent("\(volumeId).xml"), atomically: true, encoding: .utf8)
        let database = folder.appendingPathComponent("frus.db")
        self.folder = folder
        pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database),
                                        databaseURL: database, volumesDirectory: volumes)
    }

    /// Removes the folder.
    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}
#endif
