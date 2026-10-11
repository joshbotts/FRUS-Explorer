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
