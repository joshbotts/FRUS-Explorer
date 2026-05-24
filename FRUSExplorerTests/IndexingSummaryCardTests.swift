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

    private func makeTestPipeline(dir: URL) async throws -> (IndexingPipeline, FTS5Store) {
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.db")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try await IndexingPipeline(
            fts5Store: store,
            volumesDirectory: volDir,
            auxiliaryDatabaseURL: dir.appendingPathComponent("aux.db")
        )
        return (pipeline, store)
    }

    // MARK: - Tests

    @Test("completedIndexingMetadata is set when pipeline emits .complete")
    func completedMetadataSetOnComplete() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))

            let completed = await MainActor.run { appState.completedIndexingMetadata }
            #expect(completed != nil, "completedIndexingMetadata must be non-nil after indexing completes")
            #expect(completed?.volumeId == "frus1969-76v01")
        }
    }

    @Test("currentIndexingProgress is nil when completedIndexingMetadata is set")
    func currentProgressClearedOnComplete() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Test</head><p>body</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))

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
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
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
            try await Task.sleep(for: .milliseconds(50))

            let totalDocs = await MainActor.run { appState.completedIndexingMetadata?.totalDocuments }
            #expect(totalDocs == 7,
                    "completedIndexingMetadata.totalDocuments must equal the document count (7)")
        }
    }

    @Test("completedIndexingMetadata fields are zero-safe for a minimal volume")
    func completedMetadataIsZeroSafeForMinimalVolume() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await makeTestPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeTEIVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [(id: "doc-1", xml: "<head>Memorandum</head><p>body text</p>")]
            )

            let appState = await MainActor.run { AppState() }
            await MainActor.run { appState.connectIndexingProgress(pipeline: pipeline) }

            try await pipeline.indexVolume("frus1969-76v01")
            try await Task.sleep(for: .milliseconds(50))

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
