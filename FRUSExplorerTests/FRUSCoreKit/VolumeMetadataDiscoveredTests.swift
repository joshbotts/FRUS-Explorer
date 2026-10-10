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

// MARK: - VolumeMetadataDiscoveredTests

/// Tests for `IndexingPipeline.metadataStream` introduced in Session 113.
///
/// Verifies that `VolumeMetadataDiscovered` is emitted exactly once per
/// `indexVolume()` call, that its field values match the parsed document set,
/// and that the event has been sent by the time the volume's first batch is stored.
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
            volumesDirectory: volDir
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
                for await meta in pipeline.metadataStream {
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
                for await m in pipeline.metadataStream {
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
                for await m in pipeline.metadataStream {
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

    /// The pipeline's two ways in. Each sends the metadata event itself, so each is held to the
    /// order below.
    enum EntryPoint: String, CaseIterable, Sendable, CustomTestStringConvertible {
        /// `indexVolume(_:)`, which a download runs.
        case oneVolume = "indexVolume"
        /// `indexAllVolumes()`, which a re-index of the library runs.
        case everyVolume = "indexAllVolumes"

        /// The method's name, which is how a failure names its case.
        var testDescription: String { rawValue }
    }

    /// Whether `stream` gives an element within `limit`. One already sent is read at once, so the
    /// limit is only how long a stream that holds none is waited on.
    private static func givesAnElement<Element: Sendable>(
        _ stream: AsyncStream<Element>, within limit: Duration
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in stream { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: limit)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    /// The metadata event has been sent by the time a volume's first batch of documents is stored,
    /// so a progress display has the volume's counts while its batches are still being written.
    ///
    /// ## Why the pipeline is stopped to ask (#1601)
    /// The metadata event and the batch updates travel on two streams, and each stream wakes its
    /// own task: which of two tasks runs first is the scheduler's choice, whatever order the
    /// pipeline sent in. Until #1601 this test stamped the clock in a task per stream and compared
    /// the stamps, and failed about one full `swift test` run in five with the pipeline unchanged.
    ///
    /// It now holds the pipeline where the first batch has just been written
    /// (`setDocumentBatchStoredTestHook`) and reads the metadata stream there. The pipeline is
    /// suspended in the hook, so an event it has not sent yet cannot arrive and the read gives up
    /// after `limit`; one it has sent is read at once. That is the order as the pipeline ran it,
    /// read in one place. What it cannot tell apart is an event sent after the first batch's own
    /// `.storingBatch` update and before that batch's write: nothing outside the pipeline happens
    /// between the two.
    @Test("The metadata event has been sent by the time the first batch is stored", arguments: EntryPoint.allCases)
    func metadataIsSentBeforeTheFirstBatchIsStored(_ entryPoint: EntryPoint) async throws {
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

            let atFirstBatch = FirstBatchReadings()
            let metadata = pipeline.metadataStream
            await pipeline.setDocumentBatchStoredTestHook { _, batch in
                guard batch == 1 else { return }
                await atFirstBatch.append(await Self.givesAnElement(metadata, within: .seconds(30)))
            }
            switch entryPoint {
            case .oneVolume: try await pipeline.indexVolume("frus1969-76v01")
            case .everyVolume: try await pipeline.indexAllVolumes()
            }
            await pipeline.setDocumentBatchStoredTestHook(nil)

            // One reading, taken at the one volume's first batch: none means the pass stored no
            // batch and nothing was read.
            #expect(await atFirstBatch.values == [true], """
                \(entryPoint.rawValue) had not sent the volume's metadata when its first batch was \
                stored: the event must go out after the parse and before the store pass.
                """)
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
                for await m in pipeline.metadataStream { box.meta = m }
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

/// What the hook found each time the pipeline stopped at a volume's first batch: whether the
/// metadata event was already on its stream.
private actor FirstBatchReadings {
    /// One reading per first batch, in order.
    private(set) var values: [Bool] = []
    /// Records a reading.
    func append(_ value: Bool) { values.append(value) }
}
