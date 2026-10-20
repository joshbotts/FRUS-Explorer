// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

// MARK: - IndexingStageTests

/// Tests for the `IndexingStage` two-phase model introduced in Session 112.
///
/// Verifies the stream emission sequence for a single-volume index pass:
///   1. `.reading` (totalDocuments == 0) — parse started
///   2. `.reading` (totalDocuments > 0) — parse complete, count now known
///   3. `.storingBatch(current: n, total: N)` — one or more write batches
///   4. `.complete` — final emission
///
/// and, for a pass that throws after its first update, `.failed` in place of the rest (#1695).
@Suite("IndexingStage — emission sequence (Session 112)")
struct IndexingStageTests {

    // MARK: - Helpers (shared with IndexingPipelineTests)

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
            .appendingPathComponent("frus-stage-tests-\(UUID().uuidString)")
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

    // MARK: - Tests

    @Test(".reading emitted at start with totalDocuments == 0")
    func readingEmittedAtStartWithZeroTotal() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
            let box = Box()
            let collectTask = Task {
                for await update in pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            // The very first update must be .reading with totalDocuments == 0.
            let first = box.updates.first
            guard case .reading = first?.stage else {
                Issue.record("First emitted stage must be .reading, got \(String(describing: first?.stage))")
                return
            }
            #expect(first?.totalDocuments == 0, "First .reading update must have totalDocuments == 0")
        }
    }

    @Test(".reading emitted second time with totalDocuments > 0 after parse completes")
    func readingEmittedSecondTimeWithKnownTotal() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            let docs = (1...3).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
            let box = Box()
            let collectTask = Task {
                for await update in pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            let readingUpdates = box.updates.filter { if case .reading = $0.stage { return true }; return false }
            #expect(readingUpdates.count >= 2, "Must emit at least two .reading updates (before and after parse)")

            let withTotal = readingUpdates.filter { $0.totalDocuments > 0 }
            #expect(!withTotal.isEmpty, "At least one .reading update must have totalDocuments > 0")
            #expect(withTotal.allSatisfy { $0.totalDocuments == 3 },
                    "totalDocuments in post-parse .reading update must equal the document count (3)")
        }
    }

    @Test(".storingBatch increments current on each batch")
    func storingBatchCurrentIncrements() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // Use enough documents to guarantee at least one batch; the test env
            // uses a small batchSize on iOS so even a few documents trigger batching.
            let docs = (1...5).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
            let box = Box()
            let collectTask = Task {
                for await update in pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            let batchUpdates: [(current: Int, total: Int)] = box.updates.compactMap {
                if case .storingBatch(let c, let t) = $0.stage { return (c, t) }
                return nil
            }

            #expect(!batchUpdates.isEmpty, "At least one .storingBatch update must be emitted")

            // current values must be strictly increasing and start at 1.
            let currents = batchUpdates.map(\.current)
            #expect(currents.first == 1, "First batch current must be 1")
            for i in 1..<currents.count {
                #expect(currents[i] > currents[i - 1], "batch current must increase monotonically")
            }

            // total must be consistent across all batch updates.
            let totals = Set(batchUpdates.map(\.total))
            #expect(totals.count == 1, "total must be the same in every .storingBatch update")
            #expect(batchUpdates.last?.current == batchUpdates.last?.total,
                    "last batch current must equal total")
        }
    }

    @Test(".complete is the final emitted stage")
    func completeIsFinalStage() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
            let box = Box()
            let collectTask = Task {
                for await update in pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            #expect(box.updates.last?.stage == .complete,
                    "The last emitted update must have stage .complete")
        }
    }

    @Test("emission order: .reading → .storingBatch → .complete")
    func emissionOrderIsCorrect() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
            let box = Box()
            let collectTask = Task {
                for await update in pipeline.progressStream {
                    box.updates.append(update)
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            // Verify no old stage names survive. `.optimizing` is emitted by the
            // bulk `indexAllVolumes` path (see `IndexingStage.optimizing` doc
            // comment), not by the single-volume `indexVolume` exercised here,
            // but the switch must remain exhaustive over `IndexingStage`.
            for update in box.updates {
                switch update.stage {
                case .reading, .storingBatch, .optimizing, .complete:
                    break // expected
                case .failed:
                    Issue.record("a pass that succeeded reported .failed")
                }
            }

            // Verify ordering: all .reading before any .storingBatch,
            // all .storingBatch/.optimizing before .complete.
            var seenBatch = false
            var seenComplete = false
            for update in box.updates {
                switch update.stage {
                case .reading:
                    #expect(!seenBatch, ".reading must not appear after .storingBatch")
                    #expect(!seenComplete, ".reading must not appear after .complete")
                case .storingBatch:
                    seenBatch = true
                    #expect(!seenComplete, ".storingBatch must not appear after .complete")
                case .optimizing:
                    #expect(!seenComplete, ".optimizing must not appear after .complete")
                case .complete:
                    seenComplete = true
                case .failed:
                    Issue.record("a pass that succeeded reported .failed")
                }
            }
            #expect(seenComplete, "Must observe .complete before stream ends")
        }
    }

    // MARK: - A pass that throws (#1695)

    /// What `pipeline.progressStream` carries while `run` runs, up to and including its
    /// `.complete` or `.failed`.
    ///
    /// The collector ends at that update, and is awaited before its list is read. A run that
    /// reports nothing never sends one, so its collector is stopped a second after the run returns;
    /// stopping a collector that waits ends the stream, so use this last on a pipeline when it may.
    private func updates(of pipeline: IndexingPipeline,
                         during run: () async throws -> Void) async throws -> [IndexingProgressUpdate] {
        final class Box: @unchecked Sendable { var updates: [IndexingProgressUpdate] = [] }
        let box = Box()
        let collectTask = Task {
            for await update in pipeline.progressStream {
                box.updates.append(update)
                if update.stage == .complete || update.stage == .failed { break }
            }
        }
        try? await run()
        let stop = Task {
            try await Task.sleep(for: .seconds(1))
            collectTask.cancel()
        }
        await collectTask.value
        stop.cancel()
        return box.updates
    }

    @Test("A pass whose parse throws ends its updates with .failed, and no .complete")
    func aParseThatThrowsReportsFailed() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Not XML at all: the parser throws once the pass has sent its first update.
            try "<TEI><text><body><div type=\"document\" xml:id=\"d1\"><p>cut short"
                .write(to: volDir.appendingPathComponent("frus1969-76v01.xml"), atomically: true, encoding: .utf8)

            var threw = false
            let updates = try await updates(of: pipeline) {
                do { try await pipeline.indexVolume("frus1969-76v01") } catch { threw = true; throw error }
            }
            #expect(threw, "the premise: this volume's pass throws")
            // The premise of the defect: the pass had said it was under way.
            #expect(updates.first?.stage == .reading)
            #expect(updates.last?.stage == .failed, "the stream's last word on a pass that threw is .failed")
            #expect(updates.last?.volumeId == "frus1969-76v01")
            #expect(!updates.contains { $0.stage == .complete })
        }
    }

    @Test("A pass whose store throws partway ends its updates with .failed, counting what it stored")
    func aStoreThatThrowsReportsFailed() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            // Three write batches on every platform (the default is 50 on iOS and one batch on the
            // Mac), and the store stops after its second, so it has made progress when it throws.
            let docs = (1...300).map { n in (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>") }
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01", documents: docs)
            await pipeline.setTestBatchSize(100)
            struct Stop: Error {}
            await pipeline.setDocumentBatchStoredTestHook { _, batch in
                if batch == 2 { throw Stop() }
            }

            let updates = try await updates(of: pipeline) {
                try await pipeline.indexVolume("frus1969-76v01")
            }
            let last = try #require(updates.last)
            #expect(last.stage == .failed)
            #expect(updates.contains { if case .storingBatch = $0.stage { return true }; return false },
                    "the premise: the store had begun")
            #expect(last.totalDocuments == 300)
            // The first batch was counted; the hook stopped the second before its count.
            #expect(last.completedDocuments == 100, "the count is as far as the store got")
            #expect(!updates.contains { $0.stage == .complete })
        }
    }

    @Test("A pass that succeeds sends no .failed, and a missing file sends nothing at all")
    func aPassThatSucceedsOrNeverStartsSendsNoFailed() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeTEIVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                               volumeId: "frus1969-76v01",
                               documents: [(id: "doc-1", xml: "<head>Doc</head><p>Body</p>")])
            let succeeded = try await updates(of: pipeline) {
                try await pipeline.indexVolume("frus1969-76v01")
            }
            #expect(succeeded.last?.stage == .complete)
            #expect(!succeeded.contains { $0.stage == .failed })

            // The file is checked before the first update, so there is nothing to take back.
            let missing = try await updates(of: pipeline) {
                try await pipeline.indexVolume("frus1969-76v99")
            }
            #expect(missing.isEmpty, "a pass that never started reported \(missing.map(\.stage))")
        }
    }
}
