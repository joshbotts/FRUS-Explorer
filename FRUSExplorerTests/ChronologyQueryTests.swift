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

private func writeChronVolume(
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

private func withChronTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSChronTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

private func makeChronPipeline(dir: URL) async throws -> (pipeline: IndexingPipeline, store: FTS5Store) {
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

// MARK: - ChronologyQueryTests

/// Verifies the corpus-wide date-range queries that back the Chronology browser.
@Suite("ChronologyQueryTests")
struct ChronologyQueryTests {

    /// Indexes documents across two volumes and dates, then exercises the range query
    /// (overlap + ordering + out-of-range exclusion) and the bucket-count query.
    private func seed(_ dir: URL) async throws -> IndexingPipeline {
        let (pipeline, _) = try await makeChronPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        try writeChronVolume(
            to: volDir.appendingPathComponent("frus1969-76v01.xml"),
            volumeId: "frus1969-76v01",
            documents: [
                ("d1", "<dateline><date when=\"1969-02-15\">February 15, 1969</date></dateline><head>1. Memo</head><p>Body.</p>"),
                ("d2", "<dateline><date when=\"1969-02-15\">February 15, 1969</date></dateline><head>2. Memo</head><p>Body.</p>"),
                ("d3", "<dateline><date from=\"1969-03-03\" to=\"1969-03-05\">March 3–5, 1969</date></dateline><head>3. Meeting</head><p>Body.</p>"),
                ("d4", "<dateline><date when=\"1969\">1969</date></dateline><head>4. Year only</head><p>Body.</p>"),
            ]
        )
        try writeChronVolume(
            to: volDir.appendingPathComponent("frus1977-80v01.xml"),
            volumeId: "frus1977-80v01",
            documents: [
                ("d1", "<dateline><date when=\"1978-05-05\">May 5, 1978</date></dateline><head>1. Later memo</head><p>Body.</p>"),
            ]
        )
        try await pipeline.indexVolume("frus1969-76v01")
        try await pipeline.indexVolume("frus1977-80v01")
        return pipeline
    }

    @Test("documentsInDateRange returns in-range docs ordered by date and excludes out-of-range")
    func rangeQueryOrderingAndExclusion() async throws {
        try await withChronTempDir { dir in
            let pipeline = try await seed(dir)

            let rows = try await pipeline.documentsInDateRange(
                DateRange(earliest: "1969-01-01", latest: "1969-12-31"),
                scopeVolumeIds: nil,
                ascending: true,
                limit: 1000
            )
            let ids = rows.map(\.id)
            #expect(rows.count == 4, "All four 1969 documents are in range")
            #expect(!ids.contains("frus1977-80v01/d1"), "The 1978 document is excluded")
            // Ascending by date_iso: d4 (1969-01-01) before the Feb 15 pair before d3 (Mar 3).
            #expect(rows.first?.documentId == "d4")
            #expect(rows.last?.documentId == "d3")
            // Precision carries through.
            let d4 = try #require(rows.first { $0.documentId == "d4" })
            #expect(d4.precision == .year)
        }
    }

    @Test("documentsInDateRange includes a multi-day document via interval overlap")
    func rangeQueryOverlap() async throws {
        try await withChronTempDir { dir in
            let pipeline = try await seed(dir)
            // A single day inside the March 3–5 meeting's range.
            let rows = try await pipeline.documentsInDateRange(
                DateRange(earliest: "1969-03-04", latest: "1969-03-04"),
                scopeVolumeIds: nil,
                ascending: true,
                limit: 1000
            )
            #expect(rows.contains { $0.documentId == "d3" },
                    "The March 3–5 meeting overlaps March 4 and must be included")
        }
    }

    @Test("dateBucketCounts groups by month")
    func bucketCountsByMonth() async throws {
        try await withChronTempDir { dir in
            let pipeline = try await seed(dir)
            let buckets = try await pipeline.dateBucketCounts(
                DateRange(earliest: "1969-01-01", latest: "1969-12-31"),
                bucket: .month,
                scopeVolumeIds: nil
            )
            let counts = Dictionary(uniqueKeysWithValues: buckets.map { ($0.key, $0.count) })
            #expect(counts["1969-01"] == 1, "Year-only d4 buckets at its January start")
            #expect(counts["1969-02"] == 2, "The two Feb 15 memos share a month bucket")
            #expect(counts["1969-03"] == 1, "The March meeting buckets at its start month")
        }
    }

    @Test("scopeVolumeIds restricts the range query to a volume")
    func rangeQueryVolumeScope() async throws {
        try await withChronTempDir { dir in
            let pipeline = try await seed(dir)
            let rows = try await pipeline.documentsInDateRange(
                DateRange(earliest: "1900-01-01", latest: "2000-12-31"),
                scopeVolumeIds: ["frus1977-80v01"],
                ascending: true,
                limit: 1000
            )
            #expect(rows.count == 1)
            #expect(rows.first?.volumeId == "frus1977-80v01")
        }
    }
}
