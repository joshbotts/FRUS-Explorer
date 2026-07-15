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

// MARK: - IndexingStageTests

/// Tests for the `IndexingStage` two-phase model introduced in Session 112.
///
/// Verifies the stream emission sequence for a single-volume index pass:
///   1. `.reading` (totalDocuments == 0) — parse started
///   2. `.reading` (totalDocuments > 0) — parse complete, count now known
///   3. `.storingBatch(current: n, total: N)` — one or more write batches
///   4. `.complete` — final emission
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
                }
            }
            #expect(seenComplete, "Must observe .complete before stream ends")
        }
    }
}
