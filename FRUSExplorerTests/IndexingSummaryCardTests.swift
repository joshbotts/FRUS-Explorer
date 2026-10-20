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
        // update that would have asked for an activity has been. Its handling writes the volume
        // into the indexed set. (This read `completedIndexingMetadata` until #1695, which the
        // metadata stream's own task fills: when the progress task handled `.complete` first it
        // stayed nil, and the test timed out, twice in 23 runs of A11's mutation sweep.)
        let deadline = ContinuousClock.now + .seconds(30)
        while !appState.indexedVolumeIds.contains(volumeId), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(appState.indexedVolumeIds.contains(volumeId))
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
        // One request, in the system's host, which both kinds of job ask through (#1695).
        #expect(filesThatRequest == ["AppState.swift": 1])

        let source = try String(contentsOf: repoRoot.appendingPathComponent("FRUSExplorer/App/AppState.swift"),
                                encoding: .utf8)
        let host = try Self.body(of: "final class SystemLiveActivityHost: LiveActivityHosting", in: source)
        let policy = "LiveActivityPolicy.mayShow(in: ProcessInfo.processInfo.environment)"
        // The request's first statement is the rule, so a test's process asks the system for nothing
        // whatever its caller does.
        // Read inside the host, where the protocol's requirement of the same name is not.
        let requestBody = try Self.body(of: "func request(showing state: IndexingActivityAttributes.ContentState) -> String?",
                                        in: String(host))
        #expect(requestBody.drop(while: \.isWhitespace).hasPrefix("guard \(policy) else { return nil }"),
                "the request does not ask the rule first")
        #expect(requestBody.matches(of: request).count == 1, "the host no longer makes the one request")
        // Whether the host may show one is the rule first, then the system's switch.
        let mayShow = try Self.body(of: "var mayShow: Bool", in: String(host))
        let mayShowCode = mayShow.split(separator: "\n").filter { !$0.drop(while: \.isWhitespace).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(mayShowCode.drop(while: \.isWhitespace).hasPrefix(policy), "the host's answer does not ask the rule first")
        // And both sync functions ask the host first, so nothing in them runs in a test's process.
        for signature in ["private func syncIndexingLiveActivity(update: IndexingProgressUpdate)",
                          "func syncSummarizationLiveActivity()"] {
            let body = try Self.body(of: signature, in: source)
            #expect(body.drop(while: \.isWhitespace).hasPrefix("guard liveActivityHost.mayShow else { return }"),
                    "\(signature) does not ask the host first")
        }
    }

    @Test("The system's host shows none, and asks the system for none, in a test's process")
    func theSystemHostAsksTheRule() {
        let host = SystemLiveActivityHost()
        let before = Self.activityIds
        #expect(!host.mayShow)
        let state = IndexingActivityAttributes.ContentState(
            kind: .indexing, volumeTitle: "Volume", progressFraction: nil, etaSeconds: nil,
            completedDocuments: 0, totalDocuments: 0, isOptimizing: false, queueCurrent: nil, queueTotal: nil)
        #expect(host.request(showing: state) == nil, "a test's process was given an activity")
        #expect(Self.activityIds.subtracting(before).isEmpty)
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
        // One place builds content, and the system host's request and update both go through it
        // (the keep-alive sends through the update).
        #expect(filesThatBuildContent == ["AppState.swift": 1])
        let source = try Self.code("FRUSExplorer/App/AppState.swift")
        let host = try Self.body(of: "final class SystemLiveActivityHost: LiveActivityHosting", in: source)
        let helper = try Self.body(of: "private static func content(", in: String(host))
        #expect(helper.contains("ActivityContent(state: state, staleDate: LiveActivityLifecycle.staleDate(after: Date()))"))
        #expect(host.components(separatedBy: "Self.content(state)").count - 1 == 2,
                "the request and the update no longer both build their content in one place")
        let request = try Self.body(of: "func request(showing state: IndexingActivityAttributes.ContentState) -> String?",
                                    in: String(host))
        #expect(request.contains("content: Self.content(state)"), "the request is made with other content")
    }

    @Test("A leftover is dismissed at once and taken over by no run, and this process's own activity is not swept")
    func theSweepDismissesAtOnce() throws {
        let appState = AppState()
        let host = RecordingLiveActivityHost()
        appState.liveActivityHost = host
        // An end that has not landed: the system still lists the activity as live.
        host.endsLand = false
        host.leave(Self.listed("left", .summarizing))

        appState.endLeftoverLiveActivities()
        // At once: a dismissal that comes due after the app has gone makes the system open the app
        // again in the background.
        #expect(host.ends.map(\.dismissal) == [.immediately])
        #expect(host.ends.map(\.id) == ["left"])

        // A run that starts before that end lands takes over nothing the sweep has ended: it asks
        // for an activity of its own.
        appState.backgroundSummarizationProgress.state = .running(tally: .zero, currentDocumentId: nil, step: nil)
        appState.syncSummarizationLiveActivity()
        #expect(host.requests.count == 1, "the run took over the leftover the sweep had ended")
        #expect(!host.updates.contains { $0.id == "left" })

        // That activity is this process's own: when its run ends it lingers, ended, and a sweep
        // in that time does not cut it short.
        host.endsLand = true
        appState.backgroundSummarizationProgress.state = .completed(tally: .zero)
        appState.syncSummarizationLiveActivity()
        let own = try #require(host.grantedIDs.first)
        #expect(host.ends.last?.id == own && host.ends.last?.dismissal == .afterLinger)
        appState.endLeftoverLiveActivities()
        #expect(host.ends.filter { $0.id == own }.count == 1, "the sweep ended this process's own lingering activity")
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
        // The sentences are the shared file's, where a unit test reads them (#1695,
        // `LiveActivityQueueTests`), and the widget declares none of its own.
        #expect(!source.contains("liveactivity.stopped."))
        // The seconds left are printed through the rule that hides a count under five (#1695),
        #expect(source.contains("if let eta = state.shownSecondsLeft {"))
        #expect(!source.contains("state.etaSeconds"))
        // and the finishing merge's words are its title, which the app sets, not a line under it.
        #expect(!source.contains("liveactivity.optimizing"))
    }
}

// MARK: - RecordingLiveActivityHost

/// A stand-in for the system's Live Activities (#1695): it lists what `AppState` asked for, ends
/// what it is told to end, and records every call.
///
/// It lists an activity as the system was measured to on 2026-10-12: a requested one is live; an
/// ended one stays listed, ended, until its dismissal comes due (here, never); one dismissed at once
/// leaves the list. `endsLand = false` holds every end back, so the activity still reads as live, as
/// the system's does for a moment after the call.
@MainActor
final class RecordingLiveActivityHost: LiveActivityHosting {

    /// One call `AppState` made.
    enum Call: Equatable {
        /// A request, and the id it was given, or `nil` when it was refused.
        case request(Requested)
        /// An update.
        case update(Updated)
        /// An end.
        case end(Ended)
    }

    /// A request, and the id it was given, or `nil` when it was refused.
    struct Requested: Equatable {
        let id: String?
        let state: IndexingActivityAttributes.ContentState
    }

    /// An update, and whether the activity it was sent to was live: no update reaches an ended one.
    struct Updated: Equatable {
        let id: String
        let state: IndexingActivityAttributes.ContentState
        let reachedALiveOne: Bool
    }

    /// An end, and how the activity was to leave the screen.
    struct Ended: Equatable {
        let id: String
        let dismissal: LiveActivityLifecycle.Dismissal
    }

    var mayShow = true
    var isInForeground = true
    /// Whether a request is refused, as the system refuses one from an app in the background.
    var refusesRequests = false
    /// A request for a state this answers `true` for is refused too.
    var refusesState: (IndexingActivityAttributes.ContentState) -> Bool = { _ in false }
    /// Whether an end lands at once.
    var endsLand = true
    /// Every call, in order.
    private(set) var calls: [Call] = []
    /// The activities as the system would list them.
    private(set) var listed: [LiveActivityLifecycle.Listed] = []
    private var granted = 0

    func listedActivities() -> [LiveActivityLifecycle.Listed] { listed }

    func request(showing state: IndexingActivityAttributes.ContentState) -> String? {
        guard !refusesRequests, !refusesState(state) else {
            calls.append(.request(Requested(id: nil, state: state)))
            return nil
        }
        granted += 1
        let id = "activity-\(granted)"
        listed.append(LiveActivityLifecycle.Listed(id: id, kind: state.resolvedKind, phase: .live))
        calls.append(.request(Requested(id: id, state: state)))
        return id
    }

    func update(_ id: String, to state: IndexingActivityAttributes.ContentState) {
        let live = listed.contains { $0.id == id && $0.phase == .live }
        calls.append(.update(Updated(id: id, state: state, reachedALiveOne: live)))
    }

    func end(_ id: String, dismissal: LiveActivityLifecycle.Dismissal) {
        calls.append(.end(Ended(id: id, dismissal: dismissal)))
        guard endsLand, let index = listed.firstIndex(where: { $0.id == id }) else { return }
        switch dismissal {
        case .immediately:
            listed.remove(at: index)
        case .afterLinger:
            listed[index] = LiveActivityLifecycle.Listed(id: id, kind: listed[index].kind, phase: .ended)
        }
    }

    /// Lists `activity` as an earlier process would have left it.
    func leave(_ activity: LiveActivityLifecycle.Listed) {
        listed.append(activity)
    }

    // MARK: What was asked

    /// Every request, granted or refused.
    var requests: [Requested] {
        calls.compactMap { if case .request(let request) = $0 { return request }; return nil }
    }

    /// The ids of the requests that were granted, in order.
    var grantedIDs: [String] { requests.compactMap(\.id) }

    /// Every update.
    var updates: [Updated] {
        calls.compactMap { if case .update(let update) = $0 { return update }; return nil }
    }

    /// Every end.
    var ends: [Ended] {
        calls.compactMap { if case .end(let end) = $0 { return end }; return nil }
    }

    /// What a reader saw, in order: the state of each granted request and of each update that
    /// reached a live activity.
    var shown: [IndexingActivityAttributes.ContentState] {
        calls.compactMap {
            switch $0 {
            case .request(let request) where request.id != nil: return request.state
            case .update(let update) where update.reachedALiveOne: return update.state
            default: return nil
            }
        }
    }
}

// MARK: - LiveActivityQueueTests

/// One Live Activity follows a whole indexing queue, a run takes over only a live activity, a
/// refused request is not made again in a background run, a pass that throws ends its banner and
/// its activity, and an activity says what is true (#1695, plan of record decisions 63 and 64, and
/// the plan's default for the issue's other lines).
///
/// The rules are driven with values. The queue's activity is driven through `AppState`'s own
/// progress path, with a real pipeline indexing small volumes and `RecordingLiveActivityHost` in
/// place of the system's activities, so each test reads what `AppState` asked for. What the system
/// then shows was looked at on a simulator; the session entry of 2026-10-20 in
/// `Planning/DEVELOPMENT-PLAN.md` says what was seen.
///
/// Version history:
///   1.0 — 2026-10-20 (#1695): initial implementation
@Suite("One Live Activity follows a whole queue, and says what is true (#1695)")
@MainActor
struct LiveActivityQueueTests {

    private typealias Rule = LiveActivityLifecycle
    private typealias State = IndexingActivityAttributes.ContentState

    /// An activity as the system lists it. With no kind or phase: a live indexing activity.
    private static func listed(_ id: String, _ kind: LiveActivityJobKind = .indexing,
                               _ phase: Rule.Phase = .live) -> Rule.Listed {
        Rule.Listed(id: id, kind: kind, phase: phase)
    }

    // MARK: The take-over rule

    @Test("A run takes over only a live activity of its kind, and none this process has asked to end")
    func theTakeOverRule() {
        // The defect: the last volume's activity, ended and lingering, is all the system lists.
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a", .indexing, .ended)], ended: []) == nil)
        // A live one listed after it is the one.
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a", .indexing, .ended), Self.listed("b")],
                                        ended: []) == "b")
        // Live as listed, but this process has asked for its end, which has not landed.
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a")], ended: ["a"]) == nil)
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a"), Self.listed("b")], ended: ["a"]) == "b")
        // Dismissed.
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a", .indexing, .dismissed)], ended: []) == nil)
        // Another kind's, either way round.
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("s", .summarizing)], ended: []) == nil)
        #expect(Rule.activityToTakeOver(.summarizing, among: [Self.listed("a")], ended: []) == nil)
        // The pass a launch resumes keeps the live activity the last process left (#1642).
        #expect(Rule.activityToTakeOver(.indexing, among: [Self.listed("a")], ended: []) == "a")
        #expect(Rule.activityToTakeOver(.summarizing, among: [Self.listed("s", .summarizing)], ended: []) == "s")
    }

    // MARK: The request gate

    @Test("After a refusal in the background no request is made until the app is in the foreground again")
    func theRequestGate() {
        // Each answer is read into a constant first: `#expect` cannot call a mutating member.
        var gate = Rule.RequestGate()
        let first = gate.mayRequest(inForeground: false)
        #expect(first, "a background run may ask once")
        gate.noteRefusal(inForeground: false)
        let again = gate.mayRequest(inForeground: false)
        let andAgain = gate.mayRequest(inForeground: false)
        #expect(!again, "and not again in that run")
        #expect(!andAgain)
        let inFront = gate.mayRequest(inForeground: true)
        #expect(inFront, "the foreground opens the gate again")
        let nextRun = gate.mayRequest(inForeground: false)
        #expect(nextRun, "for the next background run too")
        // A refusal in the foreground closes nothing.
        var foreground = Rule.RequestGate()
        foreground.noteRefusal(inForeground: true)
        let behind = foreground.mayRequest(inForeground: false)
        let ahead = foreground.mayRequest(inForeground: true)
        #expect(behind)
        #expect(ahead)
    }

    // MARK: What an activity shows

    /// An indexing update. With no volume or stage: a store batch of `frus1969-76v01`.
    private static func update(_ volumeId: String = "frus1969-76v01",
                               _ stage: IndexingStage = .storingBatch(current: 1, total: 2),
                               done: Int, of total: Int, at rate: Double) -> IndexingProgressUpdate {
        IndexingProgressUpdate(volumeId: volumeId, stage: stage, completedDocuments: done,
                               totalDocuments: total, docsPerSecond: rate)
    }

    @Test("Seconds left are rounded up, and the widget prints none under five")
    func secondsLeft() {
        // 2.5 seconds is 3; cut down to a whole second, as before, it read 2.
        #expect(Rule.secondsLeft(of: Self.update(done: 90, of: 100, at: 4)) == 3)
        // Half a second is 1; cut down it read "~0s", which #1642's session saw for most of a volume.
        #expect(Rule.secondsLeft(of: Self.update(done: 0, of: 10, at: 20)) == 1)
        // A whole number stays as it is.
        #expect(Rule.secondsLeft(of: Self.update(done: 0, of: 100, at: 25)) == 4)
        // Nothing left, or no rate yet: no count.
        #expect(Rule.secondsLeft(of: Self.update(done: 100, of: 100, at: 25)) == nil)
        #expect(Rule.secondsLeft(of: Self.update(done: 0, of: 100, at: 0)) == nil)

        func shown(_ eta: Int?) -> Int? {
            State(kind: .indexing, volumeTitle: "Volume", progressFraction: 0.5, etaSeconds: eta,
                  completedDocuments: 1, totalDocuments: 2, isOptimizing: false, queueCurrent: nil,
                  queueTotal: nil).shownSecondsLeft
        }
        #expect(State.fewestSecondsShown == 5)
        #expect(shown(4) == nil)
        #expect(shown(5) == 5)
        #expect(shown(61) == 61)
        #expect(shown(nil) == nil)
    }

    @Test("The finishing merge is titled Finalizing index…, a volume by the catalogue, and a finished volume is full")
    func whatAnIndexingUpdateShows() {
        let merge = Rule.indexingState(for: Self.update("", .optimizing, done: 0, of: 0, at: 0),
                                       catalogueTitle: nil, queue: nil)
        #expect(merge.volumeTitle == "Finalizing index…")
        #expect(merge.isOptimizing)
        #expect(merge.detail(isStale: false) == .finishing)

        let volume = Rule.indexingState(for: Self.update(done: 1, of: 2, at: 1),
                                        catalogueTitle: "Foundations of Foreign Policy", queue: (current: 2, total: 3))
        #expect(volume.volumeTitle == "Foundations of Foreign Policy")
        #expect(volume.queueCurrent == 2 && volume.queueTotal == 3)
        #expect(volume.continuesInBackground == nil)
        // A volume the catalogue does not name is titled by its id.
        let sideLoaded = Rule.indexingState(for: Self.update("frus-sideloaded", done: 1, of: 2, at: 1),
                                            catalogueTitle: nil, queue: nil)
        #expect(sideLoaded.volumeTitle == "frus-sideloaded")
        // A finished volume: its bar full and no seconds left.
        let finished = Rule.indexingState(for: Self.update("frus1969-76v01", .complete, done: 740, of: 740, at: 50),
                                          catalogueTitle: "Foundations of Foreign Policy", queue: (current: 1, total: 3))
        #expect(finished.progressFraction == 1)
        #expect(finished.etaSeconds == nil)
        #expect(!finished.isOptimizing)
        // One with no documents is full too, where it would read as not yet counted ("Parsing…").
        let empty = Rule.indexingState(for: Self.update("frus1969-76v01", .complete, done: 0, of: 0, at: 0),
                                       catalogueTitle: nil, queue: nil)
        #expect(empty.progressFraction == 1)
        #expect(empty.detail(isStale: false) == .progress(1))
    }

    @Test("A summarization run that goes on in the background says so once the app stops updating it (decision 64)")
    func theSummarizingSentence() throws {
        let tally = BatchRunTally(succeeded: 2, failed: 1, skipped: 4, attemptable: 6)
        let goesOn = Rule.summarizationState(tally: tally, continuesInBackground: true)
        #expect(goesOn.continuesInBackground == true)
        #expect(goesOn.stoppedLabel
                == "Summarizing will continue in the background. Open FRUS Explorer to continue now.")
        #expect(goesOn.completedDocuments == 3 && goesOn.totalDocuments == 6)
        #expect(goesOn.progressFraction == 0.5)
        // With Continue in the background off, the sentence stands.
        let stops = Rule.summarizationState(tally: tally, continuesInBackground: false)
        #expect(stops.stoppedLabel == "Summarizing has stopped. Open FRUS Explorer to continue.")
        // Content from before the field existed decodes with none, and reads as a run that stops.
        let older = try JSONDecoder().decode(State.self, from: Data(#"""
            {"kind":"summarizing","volumeTitle":"Summarizing FRUS documents","completedDocuments":3,\#
            "totalDocuments":6,"isOptimizing":false}
            """#.utf8))
        #expect(older.continuesInBackground == nil)
        #expect(older.stoppedLabel == "Summarizing has stopped. Open FRUS Explorer to continue.")
        // An indexing run's sentence is its own, whatever the field says.
        var indexing = Rule.indexingState(for: Self.update(done: 1, of: 2, at: 1), catalogueTitle: "V", queue: nil)
        indexing.continuesInBackground = true
        #expect(indexing.stoppedLabel == "Indexing has stopped. Open FRUS Explorer to continue.")
    }

    @Test("The summarization activity is told whether its run goes on in the background, and told again when the setting changes")
    func theSummarizingFlagIsWired() throws {
        // Read in the source: the flag is `BackgroundSummarizationRequestStore.hasPending`, which a
        // test cannot set without racing `BackgroundSummarizationRequestStoreTests` on the same
        // defaults. The builder it feeds is driven above.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let appState = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/App/AppState.swift"),
                                  encoding: .utf8)
        let sync = try liveActivityTestBody(of: "func syncSummarizationLiveActivity()", in: appState)
        #expect(liveActivityTestCode(sync).contains("continuesInBackground: BackgroundSummarizationRequestStore.hasPending"))
        let settings = try String(contentsOf: root.appendingPathComponent(
            "FRUSExplorer/Summarization/BackgroundSummarizationSettingsView.swift"), encoding: .utf8)
        let onChange = try liveActivityTestBody(of: ".onChange(of: continueInBackground) { _, on in", in: settings)
        #expect(liveActivityTestCode(onChange).contains("appState.syncSummarizationLiveActivity()"))
    }

    @Test("Turning Show Indexing Live Activity off ends the activities this process holds at once")
    func theSwitchOffEndsTheActivitiesAtOnce() throws {
        let appState = AppState()
        let host = RecordingLiveActivityHost()
        appState.liveActivityHost = host
        appState.backgroundSummarizationProgress.state = .running(tally: .zero, currentDocumentId: nil, step: nil)
        appState.syncSummarizationLiveActivity()
        let id = try #require(host.grantedIDs.first)
        // On ends nothing.
        appState.liveActivitySwitchDidChange(isOn: true)
        #expect(host.ends.isEmpty)
        // Off ends it now, where it had waited for the run's next update.
        appState.liveActivitySwitchDidChange(isOn: false)
        #expect(host.ends.map(\.id) == [id])
        // Settings' switch says so when it changes.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let hub = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Settings/VolumesStorageHubView.swift"),
                             encoding: .utf8)
        let onChange = try liveActivityTestBody(of: ".onChange(of: liveActivityEnabled) { _, on in", in: hub)
        #expect(liveActivityTestCode(onChange).contains("appState.liveActivitySwitchDidChange(isOn: on)"))
    }

    // MARK: A queue, through AppState's own progress path

    /// Writes a volume of `documentCount` small documents into `directory`.
    private static func writeVolume(_ volumeId: String, in directory: URL, documentCount: Int = 3) throws {
        let documents = (1...documentCount).map {
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

    /// `volumeIds` on disk, an `AppState` subscribed to their pipeline as the app's boot subscribes
    /// it, and the stand-in in place of the system's activities.
    private func withLibrary(
        _ volumeIds: [String],
        _ body: (IndexingPipeline, AppState, RecordingLiveActivityHost, URL) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-live-activity-queue-\(UUID().uuidString)")
        let volumes = directory.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for volumeId in volumeIds { try Self.writeVolume(volumeId, in: volumes) }
        let databaseURL = directory.appendingPathComponent("test.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: databaseURL),
                                            databaseURL: databaseURL, volumesDirectory: volumes)
        let appState = AppState()
        let host = RecordingLiveActivityHost()
        appState.liveActivityHost = host
        // The queue asks the pipeline what is left on disk; without it the queue would end at its
        // first volume.
        appState.indexingPipeline = pipeline
        appState.connectIndexingProgress(pipeline: pipeline)
        try await body(pipeline, appState, host, volumes)
    }

    /// Whether `predicate` holds within `timeout`. The progress stream and the queue's backlog
    /// query are asynchronous, so every reading here is of eventual state.
    private func eventually(within timeout: Duration = .seconds(10), _ predicate: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if predicate() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return predicate()
    }

    /// `volumeId`'s title as the activity shows it.
    private static func title(_ volumeId: String, in appState: AppState) -> String {
        appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    @Test("One activity follows a three-volume queue: asked for once, each volume shown on it in turn, ended with the queue (decision 63)")
    func oneActivityFollowsTheQueue() async throws {
        let volumeIds = ["frus1969-76v01", "frus1969-76v02", "frus1969-76v03"]
        try await withLibrary(volumeIds) { pipeline, appState, host, _ in
            // One volume after another, as the launch's pass over waiting volumes indexes them.
            for volumeId in volumeIds { try await pipeline.indexVolume(volumeId) }
            #expect(try await eventually { appState.indexingBatch == nil }, "the queue never ended")

            #expect(host.requests.count == 1, "asked for \(host.requests.count) activities")
            let id = try #require(host.grantedIDs.first)
            #expect(host.updates.allSatisfy { $0.id == id && $0.reachedALiveOne },
                    "an update went to another activity, or to one that had ended")
            // Each volume named in turn, and each shown finished.
            let titles = volumeIds.map { Self.title($0, in: appState) }
            try #require(Set(titles).count == 3, "the premise: three titles a reader can tell apart")
            var named: [String] = []
            for state in host.shown where named.last != state.volumeTitle { named.append(state.volumeTitle) }
            #expect(named == titles)
            for title in titles {
                #expect(host.shown.contains { $0.volumeTitle == title && $0.progressFraction == 1 },
                        "\(title) was never shown finished")
            }
            // One end, the queue's, and nothing after it.
            #expect(host.ends == [RecordingLiveActivityHost.Ended(id: id, dismissal: .afterLinger)])
            #expect(host.calls.last == .end(RecordingLiveActivityHost.Ended(id: id, dismissal: .afterLinger)))
        }
    }

    @Test("A queue that goes on in the background keeps the activity it was given in the foreground (decision 63)")
    func aQueueInTheBackgroundKeepsItsActivity() async throws {
        let volumeIds = ["frus1969-76v01", "frus1969-76v02", "frus1969-76v03"]
        try await withLibrary(volumeIds) { pipeline, appState, host, _ in
            try await pipeline.indexVolume(volumeIds[0])
            // The reader leaves the app, and the system starts no activity from the background.
            host.isInForeground = false
            host.refusesRequests = true
            for volumeId in volumeIds.dropFirst() { try await pipeline.indexVolume(volumeId) }
            #expect(try await eventually { appState.indexingBatch == nil }, "the queue never ended")

            #expect(host.requests.count == 1, "the queue asked again from the background")
            let id = try #require(host.grantedIDs.first)
            let last = Self.title(volumeIds[2], in: appState)
            #expect(host.updates.contains { $0.id == id && $0.reachedALiveOne && $0.state.volumeTitle == last },
                    "the queue's last volume, indexed in the background, was not shown")
            #expect(host.ends.map(\.id) == [id])
        }
    }

    @Test("A queue that starts while the last queue's activity lingers asks for one of its own")
    func aNewQueueDoesNotTakeOverAnEndedActivity() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, volumes in
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch == nil }, "the first queue never ended")
            let first = try #require(host.grantedIDs.first)
            // The premise: its activity lingers, ended, and the system still lists it.
            #expect(host.listed.contains { $0.id == first && $0.phase == .ended })

            try Self.writeVolume("frus1969-76v02", in: volumes)
            try await pipeline.indexVolume("frus1969-76v02")
            #expect(try await eventually { appState.indexingBatch == nil }, "the second queue never ended")
            #expect(host.grantedIDs.count == 2, "the second queue took over the first queue's ended activity")
            #expect(host.updates.allSatisfy { $0.reachedALiveOne }, "an update went to an ended activity")
        }
    }

    @Test("Nor one the system lists as ended that this process never held")
    func aQueueDoesNotTakeOverAnotherProcesssEndedActivity() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, _ in
            // An earlier process's activity, ended and still on the Lock Screen: that process was
            // killed in the seconds its activity lingered, or the system ended it at eight hours.
            host.leave(Self.listed("earlier", .indexing, .ended))
            try await pipeline.indexVolume("frus1969-76v01")
            let ended = try await eventually { appState.indexingBatch == nil }
            #expect(ended, "the queue never ended")
            #expect(host.grantedIDs.count == 1, "the queue took over the ended activity")
            #expect(!host.updates.contains { $0.id == "earlier" }, "a state was sent to the ended activity")
        }
    }

    @Test("A queue takes over a live activity an earlier process left, as a resumed pass does (#1642)")
    func aQueueTakesOverALiveLeftover() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, _ in
            host.leave(Self.listed("earlier"))
            try await pipeline.indexVolume("frus1969-76v01")
            let ended = try await eventually { appState.indexingBatch == nil }
            #expect(ended, "the queue never ended")
            #expect(host.requests.isEmpty, "the queue asked for an activity of its own")
            #expect(host.updates.contains { $0.id == "earlier" && $0.reachedALiveOne },
                    "the queue's states did not reach the activity it took over")
            #expect(host.ends.map(\.id) == ["earlier"], "the activity it took over did not end with it")
        }
    }

    @Test("Nor one whose end this process has asked for and the system has not yet carried out")
    func aNewQueueDoesNotTakeOverAnActivityBeingEnded() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, volumes in
            host.endsLand = false
            try await pipeline.indexVolume("frus1969-76v01")
            #expect(try await eventually { appState.indexingBatch == nil }, "the first queue never ended")
            let first = try #require(host.grantedIDs.first)
            // The premise: the system still lists it as live.
            #expect(host.listed.contains { $0.id == first && $0.phase == .live })

            try Self.writeVolume("frus1969-76v02", in: volumes)
            try await pipeline.indexVolume("frus1969-76v02")
            #expect(try await eventually { appState.indexingBatch == nil }, "the second queue never ended")
            #expect(host.grantedIDs.count == 2, "the second queue took over an activity about to go")
            let second = host.grantedIDs.last
            let endOfFirst = try #require(host.calls.firstIndex(of: .end(.init(id: first, dismissal: .afterLinger))))
            #expect(!host.calls[endOfFirst...].contains { if case .update(let update) = $0 { return update.id == first }; return false },
                    "the second queue's states went to the first queue's activity")
            #expect(second != first)
        }
    }

    @Test("A pass that throws ends its banner, and its queue ends its activity, in seconds (#1695)")
    func aPassThatThrowsEndsItsBannerAndActivity() async throws {
        try await withLibrary(["frus1969-76v01", "frus1969-76v02"]) { pipeline, appState, host, _ in
            try await pipeline.indexVolume("frus1969-76v01")
            struct Stop: Error {}
            await pipeline.setDocumentBatchStoredTestHook { _, _ in throw Stop() }
            await #expect(throws: Stop.self) { try await pipeline.indexVolume("frus1969-76v02") }
            // The premise: the volume had been shown as under way.
            let second = Self.title("frus1969-76v02", in: appState)
            #expect(host.shown.contains { $0.volumeTitle == second && $0.progressFraction != 1 })

            #expect(try await eventually { appState.currentIndexingProgress == nil },
                    "the banner went on showing the volume as under way")
            // The failed volume stays unindexed, and nothing in this queue will index it, so nothing
            // is left to wait for: the queue ends in the seconds the backlog's settle takes, well
            // inside the stall timeout's fifteen.
            #expect(try await eventually(within: .seconds(8)) { appState.indexingBatch == nil },
                    "the queue went on waiting for the volume whose pass failed")
            #expect(host.ends.map(\.dismissal) == [.afterLinger], "the activity did not end with the queue")
        }
    }

    @Test("A volume's end starts no activity the queue did not already hold")
    func aVolumesEndStartsNoActivity() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, _ in
            // Every state but a finished volume's is refused, so only a request made at the volume's
            // end could be granted. In the foreground a refusal closes nothing, and the queue asks
            // again at its next updates.
            host.refusesState = { $0.progressFraction != 1 }
            try await pipeline.indexVolume("frus1969-76v01")
            let ended = try await eventually { appState.indexingBatch == nil }
            #expect(ended, "the queue never ended")
            #expect(!host.requests.isEmpty, "the premise: the queue asked while the volume indexed")
            #expect(host.grantedIDs.isEmpty, "the volume's end asked for an activity, and was given one")
        }
    }

    @Test("A volume whose parse fails is not waited for: its queue ends in seconds, not after the stall timeout")
    func aVolumeThatCannotBeParsedIsNotWaitedFor() async throws {
        try await withLibrary(["frus1969-76v01"]) { pipeline, appState, host, volumes in
            // Not XML: its pass throws before it stores a row, so the pipeline still lists the volume
            // as waiting to be indexed, which a failure in its store would not leave it.
            try "<TEI><text><body><div type=\"document\" xml:id=\"d1\"><p>cut short"
                .write(to: volumes.appendingPathComponent("frus1969-76v02.xml"), atomically: true, encoding: .utf8)
            try await pipeline.indexVolume("frus1969-76v01")
            await #expect(throws: (any Error).self) { try await pipeline.indexVolume("frus1969-76v02") }
            #expect(try await pipeline.unindexedDownloadedVolumeIds().contains("frus1969-76v02"),
                    "the premise: the volume is still waiting")
            // The backlog's settle is two seconds; the stall timeout, fifteen (not read here:
            // `IndexingBatchLifecycleTests` shortens it while one of its tests runs).
            let ended = try await eventually(within: .seconds(8)) { appState.indexingBatch == nil }
            #expect(ended, "the queue went on waiting for the volume whose parse failed")
            #expect(appState.currentIndexingProgress == nil)
            #expect(host.ends.map(\.dismissal) == [.afterLinger], "the activity did not end with the queue")
        }
    }

    @Test("In the background a refused request is not made again in that run, and in the foreground it is")
    func aRefusedRequestIsNotRepeatedInTheBackground() async throws {
        let volumeIds = ["frus1969-76v01", "frus1969-76v02", "frus1969-76v03"]
        try await withLibrary(volumeIds) { pipeline, appState, host, volumes in
            host.isInForeground = false
            host.refusesRequests = true
            for volumeId in volumeIds { try await pipeline.indexVolume(volumeId) }
            #expect(try await eventually { appState.indexingBatch == nil }, "the queue never ended")
            #expect(host.requests.count == 1, "asked \(host.requests.count) times in one background run")

            // In the foreground again, the next queue asks, and is given one.
            host.isInForeground = true
            host.refusesRequests = false
            try Self.writeVolume("frus1969-76v04", in: volumes)
            try await pipeline.indexVolume("frus1969-76v04")
            #expect(try await eventually { appState.indexingBatch == nil }, "the second queue never ended")
            #expect(host.grantedIDs.count == 1, "the foreground's queue was given no activity")
        }
    }

    @Test("A whole-library pass's finishing merge is shown under its title, and nothing it shows is untitled")
    func theFinishingMergeIsTitled() async throws {
        try await withLibrary(["frus1969-76v01", "frus1969-76v02"]) { pipeline, appState, host, _ in
            await appState.indexAllVolumes(with: pipeline)
            // Read first: a closure whose only `try` is inside `#expect` is not taken to throw.
            let ended = try await eventually { appState.indexingBatch == nil }
            #expect(ended, "the pass's queue never ended")
            #expect(host.shown.contains { $0.isOptimizing && $0.volumeTitle == "Finalizing index…" },
                    "the merge was not shown under its title")
            #expect(!host.shown.contains { $0.volumeTitle.isEmpty }, "an untitled state was shown")
            #expect(host.grantedIDs.count == 1 && host.ends.count == 1)
        }
    }
}

/// `text` without the lines that are only a comment, so a scan cannot be met by a comment.
private func liveActivityTestCode(_ text: some StringProtocol) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.drop(while: \.isWhitespace).hasPrefix("//") }
        .joined(separator: "\n")
}

/// The body of the declaration or closure `signature` opens in `source`, braces matched: from the
/// first brace at or after the signature's start, which is a closure's own, before its `in`.
private func liveActivityTestBody(of signature: String, in source: String) throws -> Substring {
    let start = try #require(source.range(of: signature), "\(signature) is gone")
    let open = try #require(source[start.lowerBound...].firstIndex(of: "{"))
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
