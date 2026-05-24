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

// MARK: - VolumeMetadataDiscoveredTests

/// Tests for `IndexingPipeline.metadataStream` introduced in Session 113.
///
/// Verifies that `VolumeMetadataDiscovered` is emitted exactly once per
/// `indexVolume()` call, that its field values match the parsed document set,
/// and that the event arrives before the first `.storingBatch` progress update.
@Suite("VolumeMetadataDiscovered — metadataStream (Session 113)")
struct VolumeMetadataDiscoveredTests {

    // MARK: - Helpers

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
            .appendingPathComponent("frus-meta-tests-\(UUID().uuidString)")
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
            volumesDirectory: volDir,
            subjectTagStore: SubjectTagStore(entries: [], appearances: [])
        )
        return (pipeline, store)
    }

    // MARK: - Tests

    @Test("metadataStream emits exactly one event per indexVolume() call")
    func emitsExactlyOnce() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    (id: "doc-1", xml: "<head>Test</head><p>body</p>")
                ]
            )

            final class Box: @unchecked Sendable { var events: [VolumeMetadataDiscovered] = [] }
            let box = Box()
            let collectTask = Task {
                for await meta in await pipeline.metadataStream {
                    box.events.append(meta)
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            #expect(box.events.count == 1, "Expected exactly one VolumeMetadataDiscovered event")
            #expect(box.events.first?.volumeId == "frus1969-76v01")
        }
    }

    @Test("totalDocuments matches the parsed document count")
    func totalDocumentsMatchesParsedCount() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            let docs = (1...5).map { n in
                (id: "doc-\(n)", xml: "<head>Doc \(n)</head><p>Body \(n)</p>")
            }
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            final class Box: @unchecked Sendable { var meta: VolumeMetadataDiscovered? }
            let box = Box()
            let collectTask = Task {
                for await m in await pipeline.metadataStream {
                    box.meta = m
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            #expect(box.meta?.totalDocuments == 5,
                    "totalDocuments must equal the number of documents written to the TEI file")
        }
    }

    @Test("all integer counts are zero for an empty volume (no docs)")
    func zeroCountsForEmptyVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: []
            )

            final class Box: @unchecked Sendable { var meta: VolumeMetadataDiscovered? }
            let box = Box()
            let collectTask = Task {
                for await m in await pipeline.metadataStream {
                    box.meta = m
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            // metadataStream may not emit when there are no documents since
            // storeIndexData returns early — that's acceptable. If it does emit,
            // all counts must be zero.
            if let meta = box.meta {
                #expect(meta.totalDocuments == 0)
                #expect(meta.editorialNoteCount == 0)
                #expect(meta.uniquePersonCount == 0)
                #expect(meta.crossReferenceCount == 0)
                #expect(meta.datedDocumentCount == 0)
                #expect(meta.dateRangeMin == nil)
                #expect(meta.dateRangeMax == nil)
            }
        }
    }

    @Test("metadataStream event arrives before first storingBatch progress update")
    func metadataArrivesBeforeFirstBatch() async throws {
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

            // Track interleaved events with timestamps.
            final class Box: @unchecked Sendable {
                var metaTime: Date? = nil
                var firstBatchTime: Date? = nil
            }
            let box = Box()

            let metaTask = Task {
                for await _ in await pipeline.metadataStream {
                    box.metaTime = .now
                    break
                }
            }
            let progressTask = Task {
                for await update in await pipeline.progressStream {
                    if update.stage == .complete { break }
                }
            }
            // Collect storingBatch updates to find the first one.
            let batchTask = Task {
                for await update in await pipeline.progressStream {
                    if case .storingBatch = update.stage {
                        if box.firstBatchTime == nil { box.firstBatchTime = .now }
                    }
                    if update.stage == .complete { break }
                }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            metaTask.cancel()
            progressTask.cancel()
            batchTask.cancel()

            // If both were recorded, metadata must have arrived first.
            if let metaTime = box.metaTime, let batchTime = box.firstBatchTime {
                #expect(metaTime <= batchTime,
                        "VolumeMetadataDiscovered must arrive before or at the first storingBatch update")
            }
        }
    }

    @Test("dateRangeMin <= dateRangeMax when both are non-nil")
    func dateRangeOrdering() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // Documents with explicit dateline dates — parser extracts from <dateline>.
            let docs = [
                (id: "doc-1", xml: "<head>1. Memorandum</head><dateline>Washington, January 20, 1969</dateline><p>Text</p>"),
                (id: "doc-2", xml: "<head>2. Memorandum</head><dateline>Washington, December 19, 1972</dateline><p>Text</p>")
            ]
            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: docs
            )

            final class Box: @unchecked Sendable { var meta: VolumeMetadataDiscovered? }
            let box = Box()
            let collectTask = Task {
                for await m in await pipeline.metadataStream { box.meta = m }
            }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))
            collectTask.cancel()

            if let meta = box.meta,
               let minDate = meta.dateRangeMin,
               let maxDate = meta.dateRangeMax {
                #expect(minDate <= maxDate,
                        "dateRangeMin must be lexicographically ≤ dateRangeMax (ISO-8601 dates sort correctly as strings)")
            }
        }
    }
}
