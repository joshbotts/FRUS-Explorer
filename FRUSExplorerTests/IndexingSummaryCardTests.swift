// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import ActivityKit
import os
@testable import FRUSExplorer

// MARK: - IndexingSummaryCardTests

/// Tests for Session 114 post-index summary card behaviour.
///
/// These tests operate on the data-layer contracts (AppState state transitions,
/// pipeline emission, SearchParameters construction) rather than on the SwiftUI
/// view rendering, which requires a running simulator.
@Suite("IndexingSummaryCard — data-layer contracts (Session 114)")
struct IndexingSummaryCardTests {

    // MARK: - Helpers

    private func makeMeta(
        volumeId: String = "frus1969-76v01",
        totalDocuments: Int = 847,
        editorialNoteCount: Int = 43,
        uniquePersonCount: Int = 312,
        crossReferenceCount: Int = 1247,
        datedDocumentCount: Int = 841,
        dateRangeMin: String? = "1969-01-20",
        dateRangeMax: String? = "1972-12-19",
        glossaryPersonCount: Int = 0,
        glossaryTermCount: Int = 0
    ) -> VolumeMetadataDiscovered {
        VolumeMetadataDiscovered(
            volumeId: volumeId,
            totalDocuments: totalDocuments,
            editorialNoteCount: editorialNoteCount,
            uniquePersonCount: uniquePersonCount,
            crossReferenceCount: crossReferenceCount,
            datedDocumentCount: datedDocumentCount,
            dateRangeMin: dateRangeMin,
            dateRangeMax: dateRangeMax,
            glossaryPersonCount: glossaryPersonCount,
            glossaryTermCount: glossaryTermCount
        )
    }

    private func writeTEIVolume(
        to url: URL,
        volumeId: String,
        documents: [(id: String, xml: String)]
    ) throws {
        let docsXML = documents.map { doc in
            "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
        }.joined()
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
          <publicationStmt><p>Test</p></publicationStmt>
          <sourceDesc><p>Test</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="volume" xml:id="\(volumeId)">
          <div type="chapter" xml:id="ch1">\(docsXML)</div>
          </div></body></text>
        </TEI>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-summary-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    private func makeTestPipeline(dir: URL) throws -> (IndexingPipeline, FTS5Store) {
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: store,
            databaseURL: dbURL,
            volumesDirectory: volDir
        )
        return (pipeline, store)
    }

    /// Polls the main actor until `appState.completedIndexingMetadata` is non-nil,
    /// up to `timeout`. The pipeline's progress stream delivers the `.complete`
    /// update asynchronously after `indexVolume` returns; a fixed sleep flaked
    /// under full-suite load (observed 2026-06-11), so wait on the observable
    /// state instead. On timeout the caller's own assertion reports the failure.
    private func waitForCompletedMetadata(
        in appState: AppState,
        timeout: Duration = .seconds(5)
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let done = await MainActor.run { appState.completedIndexingMetadata != nil }
            if done { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - Tests

    @Test("completedIndexingMetadata is set when pipeline emits .complete")
    func completedMetadataSetOnComplete() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await waitForCompletedMetadata(in: appState)

            let completed = await MainActor.run { appState.completedIndexingMetadata }
            #expect(completed != nil, "completedIndexingMetadata must be non-nil after indexing completes")
            #expect(completed?.volumeId == "frus1969-76v01")
        }
    }

    @Test("currentIndexingProgress is nil when completedIndexingMetadata is set")
    func currentProgressClearedOnComplete() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await waitForCompletedMetadata(in: appState)

            let (progress, completed) = await MainActor.run {
                (appState.currentIndexingProgress, appState.completedIndexingMetadata)
            }
            #expect(progress == nil, "currentIndexingProgress must be nil after completion")
            #expect(completed != nil, "completedIndexingMetadata must be set after completion")
        }
    }

    @Test("SearchParameters built for onSearchVolume has the correct volumeId scope")
    func searchParametersHasCorrectVolumeScope() {
        let meta = makeMeta(volumeId: "frus1969-76v01")
        var capturedParams: SearchParameters?
        let onSearch: (String) -> Void = { volumeId in
            capturedParams = SearchParameters(volumeIds: [volumeId])
        }
        onSearch(meta.volumeId)
        #expect(capturedParams?.volumeIds == ["frus1969-76v01"],
                "SearchParameters must scope to the indexed volumeId")
    }

    @Test("completedIndexingMetadata totalDocuments matches indexed count")
    func completedMetadataTotalDocumentsMatchesParsed() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            let docs = (1...7).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await waitForCompletedMetadata(in: appState)

            let totalDocs = await MainActor.run { appState.completedIndexingMetadata?.totalDocuments }
            #expect(totalDocs == 7,
                    "completedIndexingMetadata.totalDocuments must equal the document count (7)")
        }
    }

    @Test("completedIndexingMetadata fields are zero-safe for a minimal volume")
    func completedMetadataIsZeroSafeForMinimalVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Memorandum</head><p>body text</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await waitForCompletedMetadata(in: appState)

            let meta = await MainActor.run { appState.completedIndexingMetadata }
            guard let meta else {
                Issue.record("completedIndexingMetadata was nil")
                return
            }
            // All integer counts should be non-negative (zero is fine — no persons, no xrefs, etc.).
            #expect(meta.uniquePersonCount >= 0)
            #expect(meta.crossReferenceCount >= 0)
            #expect(meta.datedDocumentCount >= 0)
            #expect(meta.editorialNoteCount >= 0)
            #expect(meta.glossaryPersonCount >= 0)
            #expect(meta.glossaryTermCount >= 0)
        }
    }
}

// MARK: - LiveActivityPolicyTests

/// A test's process starts no Live Activity (`LiveActivityPolicy`).
///
/// Held three ways. The rule has its fixtures. The app's own indexing progress path is driven
/// here, in the unit target's host, which is itself a test's process, and no activity may appear.
/// And every place the app requests an activity is found in its source and must sit behind the
/// rule, since a process the rule allows cannot be made inside a test.
///
/// What the rule is for is on `LiveActivityPolicy`: an activity a test leaves behind hands the
/// next run's first test a process without its launch arguments.
///
/// Version history:
///   1.0 — 2026-10-11: initial implementation
@Suite("A test's process shows no Live Activity")
@MainActor
struct LiveActivityPolicyTests {

    // MARK: The rule

    @Test("Any process may show one but a unit test's host and a UI test's app")
    func theRule() {
        #expect(LiveActivityPolicy.mayShow(in: [:]))
        #expect(LiveActivityPolicy.mayShow(in: ["HOME": "/var/mobile"]))
        // A unit test's host, alone.
        #expect(!LiveActivityPolicy.mayShow(in: ["XCTestConfigurationFilePath": "/tmp/a.xctestconfiguration"]))
        // A UI test's app, alone.
        #expect(!LiveActivityPolicy.mayShow(in: ["FRUS_UI_TEST_MODE": "1"]))
        // Only "1" is UI-test mode, as it is everywhere else the app reads the variable.
        #expect(LiveActivityPolicy.mayShow(in: ["FRUS_UI_TEST_MODE": "0"]))
        #expect(LiveActivityPolicy.mayShow(in: ["FRUS_UI_TEST_MODE": ""]))
    }

    // MARK: The app's own path

    /// The ids of the app's Live Activities, read from ActivityKit.
    private static var activityIds: Set<String> {
        Set(Activity<IndexingActivityAttributes>.activities.map(\.id))
    }

    @Test("Indexing through the app's own progress path starts none in a test's process")
    func indexingStartsNoActivityHere() async throws {
        // The premise: this process is one the rule refuses.
        #expect(!LiveActivityPolicy.mayShow(in: ProcessInfo.processInfo.environment))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-live-activity-tests-\(UUID().uuidString)")
        let volumes = directory.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let volumeId = "frus1969-76v01"
        let documents = (1...5).map {
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
        """.write(to: volumes.appendingPathComponent("\(volumeId).xml"), atomically: true, encoding: .utf8)

        let databaseURL = directory.appendingPathComponent("test.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: databaseURL),
                                            databaseURL: databaseURL,
                                            volumesDirectory: volumes)
        let appState = AppState()

        // The queue is made by the branch that handles a progress update, the one that goes on to
        // sync the Live Activity, and by nothing else here: with no pipeline of its own this
        // `AppState` ends a queue it has, and a `.complete` alone makes none.
        let sawAProgressUpdate = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = appState.indexingBatch
        } onChange: {
            sawAProgressUpdate.withLock { $0 = true }
        }

        let before = Self.activityIds
        appState.connectIndexingProgress(pipeline: pipeline)
        try await pipeline.indexVolume(volumeId)

        // `.complete` is the stream's last update for the volume, so once it is handled every
        // update that would have asked for an activity has been.
        let deadline = ContinuousClock.now + .seconds(30)
        while appState.completedIndexingMetadata == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(appState.completedIndexingMetadata?.volumeId == volumeId)
        #expect(sawAProgressUpdate.withLock { $0 },
                "No progress update reached the branch that syncs the Live Activity, so this run proves nothing")
        #expect(Self.activityIds.subtracting(before).isEmpty,
                "Indexing in a test's process started a Live Activity")
    }

    // MARK: Every request site

    /// The body of the function declared by `signature` in `source`, braces matched.
    private static func body(of signature: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: signature), "\(signature) is gone")
        let open = try #require(source[start.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return source[source.index(after: open)..<index] }
            }
            index = source.index(after: index)
        }
        Issue.record("\(signature) has no closing brace")
        return ""
    }

    @Test("Every request for a Live Activity sits behind the rule")
    func everyRequestSiteAsksTheRule() throws {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        // `Activity.request(` as the app writes it, and with the attributes spelled out.
        let request = try Regex(#"Activity(<[^>]+>)?\.request\("#)
        // Every directory the app targets compile, since a request anywhere in them is the app's.
        let files = AppSourceTree.swiftFiles(in: repoRoot, directories: AppSourceTree.compiledDirectories)
        // 560 on 2026-10-11. A walk that reads nothing finds no request to hold.
        try #require(files.count > 400, "read only \(files.count) source files")
        var filesThatRequest: [String: Int] = [:]
        for file in files {
            let count = try String(contentsOf: file, encoding: .utf8).matches(of: request).count
            if count > 0 { filesThatRequest[file.lastPathComponent] = count }
        }
        // Two requests, both in `AppState`: one for indexing, one for summarizing.
        #expect(filesThatRequest == ["AppState.swift": 2])

        let source = try String(contentsOf: repoRoot.appendingPathComponent("FRUSExplorer/App/AppState.swift"),
                                encoding: .utf8)
        let guardLine = "guard LiveActivityPolicy.mayShow(in: ProcessInfo.processInfo.environment),"
        for signature in ["private func syncIndexingLiveActivity(update: IndexingProgressUpdate)",
                          "private func syncSummarizationLiveActivity()"] {
            let body = try Self.body(of: signature, in: source)
            // The rule is the function's first statement, so nothing in it runs in a test's process.
            #expect(body.drop(while: \.isWhitespace).hasPrefix(guardLine), "\(signature) does not ask the rule first")
            #expect(body.matches(of: request).count == 1, "\(signature) no longer makes the one request")
        }
    }
}

// MARK: - LiveActivityLifecycleTests

/// A Live Activity nothing is driving is ended at launch, and every update carries a stale date
/// (#1642, `LiveActivityLifecycle`).
///
/// The leftover rule is driven here with values, one fixture for each of its conditions alone, and
/// so are the stale date and what the widget shows for a stale activity. What a test's process
/// cannot do is hold an activity: `LiveActivityPolicy` refuses it one. So the bookkeeping that
/// tells the rule a launch's pass is about to resume is driven on an `AppState`, and the calls
/// that need a real activity (each update's stale date, the sweep's dismissal, the boot's order)
/// are found in the source. What the Lock Screen then shows was looked at on a simulator; the
/// session entry of 2026-10-12 in `Planning/DEVELOPMENT-PLAN.md` says what was seen.
///
/// Version history:
///   1.0 — 2026-10-12 (#1642): initial implementation
@Suite("A Live Activity nothing is driving is ended, and an update goes stale (#1642)")
@MainActor
struct LiveActivityLifecycleTests {

    private typealias Rule = LiveActivityLifecycle

    /// An activity as the system lists it. With no argument: a live indexing activity, "a".
    private static func listed(_ id: String = "a", _ kind: LiveActivityJobKind = .indexing,
                               _ phase: LiveActivityLifecycle.Phase = .live) -> LiveActivityLifecycle.Listed {
        LiveActivityLifecycle.Listed(id: id, kind: kind, phase: phase)
    }

    // MARK: The leftover rule

    @Test("An activity an earlier process left, with nothing here to take it over, is a leftover")
    func whatALeftoverIs() {
        // The issue's case: the app was killed while it indexed, and this launch indexes nothing.
        #expect(Rule.isLeftover(Self.listed(), driver: Rule.Driver()))
        #expect(Rule.isLeftover(Self.listed("s", .summarizing), driver: Rule.Driver()))
        // One the system ended and still shows: after eight hours it ends an activity itself and
        // leaves it on the Lock Screen for up to four more.
        #expect(Rule.isLeftover(Self.listed("a", .indexing, .ended), driver: Rule.Driver()))
    }

    @Test("One already dismissed is no leftover: nothing of it is on the screen")
    func dismissedIsNotALeftover() {
        // Dismissed alone: not driven here, and nothing running, as in the first fixture above.
        #expect(!Rule.isLeftover(Self.listed("a", .indexing, .dismissed), driver: Rule.Driver()))
    }

    @Test("One this process drove is its own, live or ended")
    func drivenIsNotALeftover() {
        // Driven alone: live, nothing running.
        #expect(!Rule.isLeftover(Self.listed("a"), driver: Rule.Driver(driven: ["a"])))
        // Ended and lingering its three seconds: a sweep must not cut that short.
        #expect(!Rule.isLeftover(Self.listed("a", .indexing, .ended), driver: Rule.Driver(driven: ["a"])))
        // It is the id that makes it this process's: with another id driven, "a" is a leftover.
        #expect(Rule.isLeftover(Self.listed("a"), driver: Rule.Driver(driven: ["b"])))
    }

    @Test("A live one of a kind whose run is under way or due here is spared, for that run to take over")
    func aRunAboutToResumeKeepsItsActivity() {
        // The pass a launch is about to resume: live, not yet taken over, and its kind running.
        let resuming = Rule.Driver(running: [.indexing])
        #expect(!Rule.isLeftover(Self.listed(), driver: resuming))
        let summarizing = Rule.Driver(running: [.summarizing])
        #expect(!Rule.isLeftover(Self.listed("s", .summarizing), driver: summarizing))
    }

    @Test("It is spared only while live, only for its own kind's run, and only where a run may show one")
    func eachConditionOfBeingSpared() {
        let resuming = Rule.Driver(running: [.indexing])
        // The premise: this fixture is spared, so each line below changes one thing in it.
        #expect(!Rule.isLeftover(Self.listed(), driver: resuming))

        // Ended, alone: no update reaches it, so the run takes nothing over.
        #expect(Rule.isLeftover(Self.listed("a", .indexing, .ended), driver: resuming))
        // Another kind's run, alone: an indexing pass takes no summarization activity over,
        #expect(Rule.isLeftover(Self.listed("s", .summarizing), driver: resuming))
        // and a summarization run no indexing one.
        #expect(Rule.isLeftover(Self.listed(), driver: Rule.Driver(running: [.summarizing])))
        // A process that may show none, alone: the reader's switch is off, or it is a test's
        // process. Its run takes none over, so the activity would sit through the whole pass.
        #expect(Rule.isLeftover(Self.listed(), driver: Rule.Driver(running: [.indexing], mayShow: false)))
    }

    @Test("The system's states: stale and pending are live, ended is ended, dismissed is dismissed")
    func phases() {
        #expect(Rule.Phase(ActivityState.active) == .live)
        // Stale is the state this change makes: an update makes a stale activity current again,
        // so a resumed pass takes one over like any other.
        #expect(Rule.Phase(ActivityState.stale) == .live)
        #expect(Rule.Phase(ActivityState.pending) == .live)
        #expect(Rule.Phase(ActivityState.ended) == .ended)
        #expect(Rule.Phase(ActivityState.dismissed) == .dismissed)
    }

    // MARK: The stale date

    @Test("An update goes stale two minutes after it is sent, four turns of the keep-alive")
    func staleDate() {
        let sent = Date(timeIntervalSinceReferenceDate: 813_531_099)
        #expect(Rule.staleDate(after: sent) == sent.addingTimeInterval(120))
        // Two minutes is the soonest the system marks an activity stale: asked for less, it
        // schedules two (measured, on `LiveActivityLifecycle.staleAfter`). A shorter value here
        // would say something the system does not do.
        #expect(Rule.staleAfter == 120)
        #expect(Rule.keepAliveEvery == 30)
        // Three turns of the keep-alive may be late or lost before a running app reads as stopped.
        #expect(Rule.staleAfter >= 4 * Rule.keepAliveEvery)
    }

    // MARK: What a stale activity shows

    /// A state with the given progress, as the app sends it.
    private static func state(fraction: Double? = nil, isOptimizing: Bool = false,
                              kind: LiveActivityJobKind? = .indexing) -> IndexingActivityAttributes.ContentState {
        IndexingActivityAttributes.ContentState(
            kind: kind, volumeTitle: "Volume", progressFraction: fraction, etaSeconds: fraction == nil ? nil : 12,
            completedDocuments: 310, totalDocuments: 740, isOptimizing: isOptimizing,
            queueCurrent: nil, queueTotal: nil)
    }

    @Test("A stale activity shows that the work stopped, whatever its last update said")
    func staleComesFirst() {
        // Over a fraction, with its count and its seconds left,
        #expect(Self.state(fraction: 0.42).detail(isStale: true) == .stopped)
        // over the finishing phase's moving bar,
        #expect(Self.state(fraction: 1, isOptimizing: true).detail(isStale: true) == .stopped)
        // and over the parse phase's.
        #expect(Self.state().detail(isStale: true) == .stopped)
        #expect(Self.state(kind: .summarizing).detail(isStale: true) == .stopped)
    }

    @Test("An activity the app is updating shows what it showed before")
    func currentIsUnchanged() {
        #expect(Self.state(fraction: 0.42).detail(isStale: false) == .progress(0.42))
        // The finishing phase comes before a fraction: the pass's last update carries both.
        #expect(Self.state(fraction: 1, isOptimizing: true).detail(isStale: false) == .finishing)
        #expect(Self.state(isOptimizing: true).detail(isStale: false) == .finishing)
        #expect(Self.state().detail(isStale: false) == .indeterminate)
        // Content encoded before `kind` existed.
        #expect(Self.state(fraction: 0, kind: nil).detail(isStale: false) == .progress(0))
    }

    // MARK: What a launch tells the rule

    @Test("A launch's index pass is a run from the moment it is decided on until it ends")
    func aLaunchPassIsARunUntilItEnds() {
        let appState = AppState()
        #expect(appState.liveActivityDriver.running.isEmpty)

        // Decided on, and not yet begun: the window in which a sweep must keep the activity.
        appState.launchIndexPassWillBegin()
        #expect(appState.liveActivityDriver.running == [.indexing])

        // Two passes can be due at one launch (the rebuild from the cache, and the pass over
        // volumes left unindexed): the first to end does not end the second.
        appState.launchIndexPassWillBegin()
        appState.launchIndexPassDidEnd()
        #expect(appState.liveActivityDriver.running == [.indexing])
        appState.launchIndexPassDidEnd()
        #expect(appState.liveActivityDriver.running.isEmpty)

        // An end with no beginning leaves it at none, and a later pass still counts.
        appState.launchIndexPassDidEnd()
        #expect(appState.liveActivityDriver.running.isEmpty)
        appState.launchIndexPassWillBegin()
        #expect(appState.liveActivityDriver.running == [.indexing])
    }

    @Test("A summarization run under way is a run, and a finished one is not")
    func aSummarizationRunIsARunWhileItRuns() {
        let appState = AppState()
        appState.backgroundSummarizationProgress.state = .running(tally: .zero, currentDocumentId: nil, step: nil)
        #expect(appState.liveActivityDriver.running == [.summarizing])
        appState.launchIndexPassWillBegin()
        #expect(appState.liveActivityDriver.running == [.indexing, .summarizing])
        appState.backgroundSummarizationProgress.state = .completed(tally: .zero)
        #expect(appState.liveActivityDriver.running == [.indexing])
    }

    @Test("A test's process drives no activity and may show none, so it spares none")
    func aTestsProcessSparesNone() {
        let appState = AppState()
        appState.launchIndexPassWillBegin()
        let driver = appState.liveActivityDriver
        #expect(driver.driven.isEmpty)
        #expect(!driver.mayShow)
        // So a leftover met by a test's app is ended at its launch, pass or no pass, and is not
        // there for the next run's install to stop (`LiveActivityPolicy`).
        #expect(Rule.isLeftover(Self.listed(), driver: driver))
    }

    // MARK: The calls a test's process cannot make

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    /// `relativePath`'s text, without the lines that are only a comment.
    private static func code(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.drop(while: \.isWhitespace).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The body of the function declared by `signature` in `source`, braces matched.
    private static func body(of signature: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: signature), "\(signature) is gone")
        let open = try #require(source[start.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return source[source.index(after: open)..<index] }
            }
            index = source.index(after: index)
        }
        Issue.record("\(signature) has no closing brace")
        return ""
    }

    @Test("Every content the app gives an activity carries the rule's stale date")
    func everyContentCarriesAStaleDate() throws {
        // `ActivityContent(` as a call: the helper's own name ends in the same letters.
        let construction = try Regex(#"(^|[^A-Za-z])ActivityContent\("#)
        let files = AppSourceTree.swiftFiles(in: Self.repoRoot, directories: AppSourceTree.compiledDirectories)
        try #require(files.count > 400, "read only \(files.count) source files")
        var filesThatBuildContent: [String: Int] = [:]
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let count = source.matches(of: construction).count
            if count > 0 { filesThatBuildContent[file.lastPathComponent] = count }
            #expect(!source.contains("staleDate: nil"), "\(file.lastPathComponent) gives an activity no stale date")
        }
        // One place builds content, and both updates and both requests go through it.
        #expect(filesThatBuildContent == ["AppState.swift": 1])
        let source = try Self.code("FRUSExplorer/App/AppState.swift")
        let helper = try Self.body(of: "private static func liveActivityContent(", in: source)
        #expect(helper.contains("ActivityContent(state: state, staleDate: LiveActivityLifecycle.staleDate(after: Date()))"))
        #expect(source.components(separatedBy: "Self.liveActivityContent(").count - 1 == 4,
                "the two requests, the update and the keep-alive no longer all build their content in one place")
        for signature in ["private func syncIndexingLiveActivity(update: IndexingProgressUpdate)",
                          "private func syncSummarizationLiveActivity()"] {
            let body = try Self.body(of: signature, in: source)
            #expect(body.contains("content: Self.liveActivityContent("), "\(signature) requests with other content")
        }
    }

    @Test("A leftover is dismissed at once, and a finished run's activity is not swept")
    func theSweepDismissesAtOnce() throws {
        let source = try Self.code("FRUSExplorer/App/AppState.swift")
        let sweep = try Self.body(of: "func endLeftoverLiveActivities()", in: source)
        #expect(sweep.contains("LiveActivityLifecycle.isLeftover(LiveActivityLifecycle.Listed(activity), driver: driver)"))
        // At once: a dismissal that comes due after the app has gone makes the system open the app
        // again in the background.
        #expect(sweep.contains("await activity.end(nil, dismissalPolicy: .immediate)"))
        // The end takes a moment to land. A run that starts in that moment takes over no
        // activity the sweep has just ended: the sweep records it, and both take-overs ask.
        #expect(sweep.contains("endedLeftoverLiveActivityIDs.insert(activity.id)"))
        #expect(source.components(separatedBy: "&& !endedLeftoverLiveActivityIDs.contains($0.id) }) {").count - 1 == 2)
        // The ids the rule reads are recorded where an activity becomes this process's: at each
        // request that succeeded, and at each taking over.
        #expect(source.components(separatedBy: "drivenLiveActivityIDs.insert(").count - 1 == 3)
        let requested = try Self.body(of: "private func noteLiveActivityRequested(", in: source)
        #expect(requested.contains("drivenLiveActivityIDs.insert(activity.id)"))
        for signature in ["private func syncIndexingLiveActivity(update: IndexingProgressUpdate)",
                          "private func syncSummarizationLiveActivity()"] {
            let body = try Self.body(of: signature, in: source)
            #expect(body.contains("drivenLiveActivityIDs.insert(existing.id)"), "\(signature) takes one over unrecorded")
            #expect(body.contains("noteLiveActivityRequested("), "\(signature) requests one unrecorded")
        }
    }

    @Test("The launch sweeps once, after each of its passes has said it will run, and each pass says when it ends")
    func theBootSweepsAfterItsPassesAreDecided() throws {
        let source = try Self.code("FRUSExplorer/App/FRUSExplorerApp.swift")
        let begins = source.ranges(of: "appState.launchIndexPassWillBegin()")
        let ends = source.ranges(of: "appState.launchIndexPassDidEnd()")
        let sweeps = source.ranges(of: "appState.endLeftoverLiveActivities()")
        // The whole-library pass, the rebuild from the cache, and the pass over volumes left unindexed.
        #expect(begins.count == 3)
        #expect(ends.count == 3)
        #expect(sweeps.count == 1)
        let sweep = try #require(sweeps.first)
        // Decided before the sweep reads it: a pass announced after would find its activity ended.
        #expect(begins.allSatisfy { $0.upperBound < sweep.lowerBound })
        // Each is said on the boot's own path, before the pass's task is made, and each pass's end
        // follows the call that runs it.
        let saidBeforeItsTask = try Regex(#"appState\.launchIndexPassWillBegin\(\)\n\s*#endif\n\s*Task \{"#)
        #expect(source.matches(of: saidBeforeItsTask).count == 3)
        // The rebuild's call sits in an `if`, so its end follows that `if`'s closing brace.
        for pass in [#"await appState\.indexAllVolumes\(with: pipeline\)"#,
                     #"await pipeline\.markFTSRebuildReindexComplete\(\)\n\s*\}"#,
                     #"await pipeline\.finishIndexing\(of: waiting\)"#] {
            let endAfterIt = try Regex(pass + #"\n\s*#if os\(iOS\)\n\s*appState\.launchIndexPassDidEnd\(\)"#)
            #expect(source.matches(of: endAfterIt).count == 1, "no end follows \(pass)")
        }
    }

    @Test("The widget draws a stale activity as stopped in each of its presentations")
    func theWidgetDrawsStale() throws {
        let source = try Self.code("FRUSExplorerWidgets/IndexingLiveActivity.swift")
        // The Lock Screen and the expanded island share one view, which reads the rule.
        #expect(source.contains("IndexingLockScreenView(state: context.state, isStale: context.isStale)"))
        #expect(source.contains("IndexingExpandedView(state: context.state, isStale: context.isStale)"))
        #expect(source.contains("IndexingExpandedView(state: state, isStale: isStale)"))
        // That view and the compact island each switch on it, so neither can draw a stale activity
        // as progress.
        #expect(source.components(separatedBy: "detail(isStale:").count - 1 == 2)
        #expect(source.contains("switch state.detail(isStale: isStale) {"))
        #expect(source.contains("switch context.state.detail(isStale: context.isStale) {"))
        #expect(source.contains("Text(state.stoppedLabel)"))
        // The small island has room for a mark and no words, so the mark carries the sentence
        // for VoiceOver, in the compact presentation and in the minimal one.
        #expect(source.components(separatedBy: ".accessibilityLabel(context.state.stoppedLabel)").count - 1 == 2)
        // The two sentences, one for each kind of job.
        #expect(source.contains(#"defaultValue: "Indexing has stopped. Open FRUS Explorer to continue.""#))
        #expect(source.contains(#"defaultValue: "Summarizing has stopped. Open FRUS Explorer to continue.""#))
    }
}
