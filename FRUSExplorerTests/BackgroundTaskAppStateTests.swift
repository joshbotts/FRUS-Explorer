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
import SwiftData
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
/// `FRUSExplorerApp.runIndexingWake(appState:bootSearchInfrastructure:modelContext:complete:)`,
/// the handler's whole run, with a boot of their own. It publishes a pipeline over a temporary
/// folder holding one volume that nothing has indexed, after a pause, as the app's boot publishes
/// its pipeline some time after a launch has handed the task over. The handler passes the app's
/// boot, which a test cannot run, since it opens the app's own index. Each test reads what the
/// wake left of the volume and what it passed to `complete`, the handler's
/// `setTaskCompleted(success:)`.
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
        let completions = CompletionRecord()
        await FRUSExplorerApp.runIndexingWake(
            appState: state,
            bootSearchInfrastructure: {
                boot.calls += 1
                try? await Task.sleep(for: .milliseconds(50))
                state.indexingPipeline = fixture.pipeline
            },
            modelContext: fixture.modelContext,
            complete: completions.record)
        #expect(boot.calls == 1, "The wake did not wait for the launch's boot before reading the pipeline")
        #expect(completions.values == [true])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The wake indexed nothing: \(left) is still unindexed")
    }

    @Test("A wake of an app the launch has booted indexes")
    func aWakeOfABootedAppIndexes() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        state.indexingPipeline = fixture.pipeline
        let completions = CompletionRecord()
        // The boot has run, so waiting for it returns at once, as awaiting its finished task does.
        await FRUSExplorerApp.runIndexingWake(
            appState: state,
            bootSearchInfrastructure: {},
            modelContext: fixture.modelContext,
            complete: completions.record)
        #expect(completions.values == [true])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left.isEmpty, "The wake indexed nothing: \(left) is still unindexed")
    }

    @Test("A wake whose time runs out during the boot starts no indexing, and the boot finishes")
    func expiryDuringTheBootStartsNoIndexing() async throws {
        let fixture = try WakeFixture(volumeId: Self.volumeId)
        defer { fixture.remove() }
        let state = AppState()
        let boot = BootProbe()
        let completions = CompletionRecord()
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
                modelContext: fixture.modelContext,
                complete: completions.record)
        }
        // Expire the wake while it waits for the boot, as the task's expiration handler does.
        let deadline = ContinuousClock.now + .seconds(10)
        while boot.calls == 0, completions.values.isEmpty, ContinuousClock.now < deadline {
            await Task.yield()
        }
        wake.cancel()
        await wake.value
        #expect(boot.calls == 1, "The wake did not wait for the launch's boot")
        #expect(state.indexingPipeline != nil, "The boot did not finish")
        #expect(completions.values == [false])
        let left = try await fixture.pipeline.unindexedDownloadedVolumeIds()
        #expect(left == [Self.volumeId], "The wake started indexing after its time ran out")
    }
}

/// How often a wake called the boot it was given.
@MainActor
private final class BootProbe {
    /// The number of calls.
    var calls = 0
}

/// What a wake passed to `complete`, in order: the handler's `setTaskCompleted(success:)`, which
/// the handler's lock lets through once.
private final class CompletionRecord: Sendable {
    private let calls = OSAllocatedUnfairLock<[Bool]>(initialState: [])

    /// Every value passed, in order.
    var values: [Bool] { calls.withLock { $0 } }

    /// The closure a wake is given as `complete`.
    var record: @Sendable (Bool) -> Void {
        { [calls] success in calls.withLock { $0.append(success) } }
    }
}

/// One volume on disk that nothing has indexed, a pipeline over it, and a model context for the
/// summaries' batch, which finds nothing to do here: no request, no download manager.
private struct WakeFixture: Sendable {
    /// The temporary folder holding the volume and the index.
    let folder: URL
    /// The pipeline a boot publishes.
    let pipeline: IndexingPipeline
    /// An in-memory store for the summaries' prompt.
    let container: ModelContainer

    /// The context a wake is given.
    @MainActor var modelContext: ModelContext { container.mainContext }

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
        container = try ModelContainer(
            for: SummarizationPrompt.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// Removes the folder.
    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }
}
#endif
