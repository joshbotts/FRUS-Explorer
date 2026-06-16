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

// MARK: - Test Helpers

/// Writes a minimal FRUS volume XML fixture (a single compilation div of documents).
private func writeAnalyticsVolume(
    to url: URL,
    volumeId: String,
    documents: [(id: String, xml: String)]
) throws {
    let docBlocks = documents.map { doc in
        "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
    }.joined(separator: "\n")

    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date>2003</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation" xml:id="comp1">
          \(docBlocks)
        </div>
      </body></text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

/// Creates a temporary directory, calls `body`, and cleans up after.
private func withAnalyticsTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSAnalyticsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// Builds a pipeline + store pair backed by a temp database, with a `volumes/` dir.
private func makeAnalyticsPipeline(dir: URL) async throws -> (pipeline: IndexingPipeline, store: FTS5Store) {
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

    let store = try FTS5Store(databaseURL: dbURL)
    let pipeline = try IndexingPipeline(
        fts5Store: store,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        subjectTagStore: SubjectTagStore(entries: [], appearances: []),
        concurrencyLimit: 2
    )
    return (pipeline, store)
}

// MARK: - CorpusAnalyticsServiceTests

/// Verifies the By-Volume analytics axis (`termFrequencyByVolume`).
///
/// Version history:
///   1.0 — Session 163: initial implementation
@Suite("CorpusAnalyticsService — By Volume")
struct CorpusAnalyticsServiceTests {

    /// A term that appears in two of three indexed volumes must yield exactly those
    /// two `VolumeFrequency` rows (with correct per-volume counts), omit the volume
    /// with no match entirely, and be sorted ascending by volume ID.
    @Test("termFrequencyByVolume buckets matches per volume and omits non-matching volumes")
    func byVolumeBucketsAndOmits() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // frus1969-76v01 mentions "treaty" in two documents.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>Negotiation of the treaty continued.</p>"),
                    ("d2", "<head>2. Memorandum</head><p>A second treaty draft circulated.</p>"),
                ]
            )
            // frus1969-76v02 (same subseries) does NOT mention the term.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                volumeId: "frus1969-76v02",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>Economic policy discussion only.</p>"),
                ]
            )
            // frus1977-80v01 (different subseries) mentions the term once.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1977-80v01.xml"),
                volumeId: "frus1977-80v01",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>The treaty was ratified.</p>"),
                ]
            )

            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let result = try await service.termFrequencyByVolume(term: "treaty")

            let counts = Dictionary(uniqueKeysWithValues: result.map { ($0.volumeId, $0.count) })
            #expect(counts["frus1969-76v01"] == 2, "v01 mentions the term in two documents")
            #expect(counts["frus1977-80v01"] == 1, "frus1977-80v01 mentions the term once")
            #expect(counts["frus1969-76v02"] == nil, "Volume with no match must be omitted")
            #expect(result.count == 2, "Only matching volumes appear")
            #expect(result.map(\.volumeId) == ["frus1969-76v01", "frus1977-80v01"],
                    "Results are sorted ascending by volume ID")
        }
    }

    /// An empty / whitespace-only term yields no rows (no searchable keywords).
    @Test("termFrequencyByVolume returns empty for a blank term")
    func byVolumeEmptyForBlankTerm() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>1. Memorandum</head><p>Some content here.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let result = try await service.termFrequencyByVolume(term: "   ")
            #expect(result.isEmpty, "A blank term has no searchable keywords")
        }
    }
}
