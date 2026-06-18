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

// MARK: - ChronologyAggregationTests

/// Verifies the in-memory partitioning (wide-span separation) and chart aggregation that
/// back the Chronology distribution chart and "spans this period" section.
@Suite("ChronologyAggregationTests")
struct ChronologyAggregationTests {

    private func row(_ vol: String, _ doc: String, iso: String, isoMax: String? = nil, editorial: Bool = false) -> ChronologyRow {
        ChronologyRow(
            volumeId: vol, documentId: doc, header: "Header", dateline: nil, summary: nil,
            dateISO: iso, dateISOMax: isoMax ?? iso,
            precision: .day, certainty: .exact,
            isEditorialNote: editorial, isFrontMatter: false, documentNumber: nil
        )
    }

    @Test("spanDays and partition separate multi-year documents from day-placeable ones")
    func partitionBySpan() {
        let exact = row("v1", "d1", iso: "1962-09-10")                       // span 0
        let yearOnly = row("v1", "d2", iso: "1962-01-01", isoMax: "1962-12-31") // span 364
        let editorial = row("v2", "d3", iso: "1952-01-11", isoMax: "1975-05-12") // ~23 years

        #expect(exact.spanDays == 0)
        #expect(yearOnly.spanDays <= ChronologyViewModel.maxSpanDaysForPlacement)
        #expect(editorial.spanDays > ChronologyViewModel.maxSpanDaysForPlacement)

        let parts = ChronologyViewModel.partition([exact, yearOnly, editorial])
        #expect(parts.placed.map(\.id) == ["v1/d1", "v1/d2"])
        #expect(parts.spanning.map(\.id) == ["v2/d3"], "The multi-year editorial note is separated out")
    }

    @Test("makeChart buckets by volume and folds the long tail into Other")
    func chartAggregationFoldsTail() {
        let g = ChronologyDateGroup(
            bucketKey: "1962-10-22", granularity: .day, sortDate: .now, displayLabel: "Oct 22, 1962",
            rows: [
                row("vA", "1", iso: "1962-10-22"), row("vA", "2", iso: "1962-10-22"),
                row("vB", "3", iso: "1962-10-22"),
                row("vC", "4", iso: "1962-10-22")
            ],
            volumeCount: 3, subseriesCount: 1, editorialNoteCount: 0
        )

        // maxSeries 2 → top volume (vA) + Other (vB + vC).
        let folded = ChronologyViewModel.makeChart(from: [g], maxSeries: 2)
        #expect(folded.series.map(\.key) == ["vA", chronologyOtherSeriesKey])
        #expect(folded.series.map(\.total) == [2, 2])
        let seg = Dictionary(uniqueKeysWithValues: folded.buckets[0].segments.map { ($0.seriesKey, $0.count) })
        #expect(seg["vA"] == 2)
        #expect(seg[chronologyOtherSeriesKey] == 2)

        // Within budget → every volume is its own series, no Other.
        let full = ChronologyViewModel.makeChart(from: [g], maxSeries: 8)
        #expect(Set(full.series.map(\.key)) == ["vA", "vB", "vC"])
        #expect(!full.series.contains { $0.key == chronologyOtherSeriesKey })
    }

    @Test("splitOverflow separates boundary-straddling uncertain documents from contained ones")
    func overflowSplit() {
        let yearOnly = row("v1", "d1", iso: "1962-01-01", isoMax: "1962-12-31") // encloses a summer range
        let contained = row("v1", "d2", iso: "1962-07-15")                       // squarely inside
        let split = ChronologyViewModel.splitOverflow(
            [yearOnly, contained], startISO: "1962-06-01", endISO: "1962-08-31")
        #expect(split.inRange.map(\.id) == ["v1/d2"])
        #expect(split.overflow.map(\.id) == ["v1/d1"])
    }

    @Test("overflowDirection flags leading, trailing, enclosing, and contained intervals")
    func overflowDirections() {
        let s = "1962-06-01", e = "1962-08-31"
        let leading = row("v", "a", iso: "1962-05-20", isoMax: "1962-07-10")
        let trailing = row("v", "b", iso: "1962-07-01", isoMax: "1962-09-15")
        let both = row("v", "c", iso: "1962-01-01", isoMax: "1962-12-31")
        let inside = row("v", "d", iso: "1962-07-01", isoMax: "1962-07-31")

        let l = ChronologyViewModel.overflowDirection(leading, startISO: s, endISO: e)
        #expect(l.leading && !l.trailing)
        let t = ChronologyViewModel.overflowDirection(trailing, startISO: s, endISO: e)
        #expect(!t.leading && t.trailing)
        let b = ChronologyViewModel.overflowDirection(both, startISO: s, endISO: e)
        #expect(b.leading && b.trailing)
        let c = ChronologyViewModel.overflowDirection(inside, startISO: s, endISO: e)
        #expect(!c.leading && !c.trailing)
    }

    @Test("magnifierBreakdown re-buckets a group one granularity finer")
    func magnifierFinerBreakdown() {
        let yearGroup = ChronologyDateGroup(
            bucketKey: "1965", granularity: .year, sortDate: .now, displayLabel: "1965",
            rows: [row("v", "1", iso: "1965-02-10"), row("v", "2", iso: "1965-02-20"), row("v", "3", iso: "1965-08-05")],
            volumeCount: 1, subseriesCount: 1, editorialNoteCount: 0)
        let months = ChronologyViewModel.magnifierBreakdown(for: yearGroup)
        #expect(months.map(\.count) == [2, 1])                 // Feb (2) before Aug (1), ascending key
        #expect(months.allSatisfy { $0.seriesKey == nil })

        let monthGroup = ChronologyDateGroup(
            bucketKey: "1965-03", granularity: .month, sortDate: .now, displayLabel: "March 1965",
            rows: [row("v", "1", iso: "1965-03-04"), row("v", "2", iso: "1965-03-04"), row("v", "3", iso: "1965-03-19")],
            volumeCount: 1, subseriesCount: 1, editorialNoteCount: 0)
        let days = ChronologyViewModel.magnifierBreakdown(for: monthGroup)
        #expect(days.map(\.label) == ["4", "19"])
        #expect(days.map(\.count) == [2, 1])

        let dayGroup = ChronologyDateGroup(
            bucketKey: "1965-03-04", granularity: .day, sortDate: .now, displayLabel: "March 4, 1965",
            rows: [row("vA", "1", iso: "1965-03-04"), row("vA", "2", iso: "1965-03-04"), row("vB", "3", iso: "1965-03-04")],
            volumeCount: 2, subseriesCount: 1, editorialNoteCount: 0)
        let volumes = ChronologyViewModel.magnifierBreakdown(for: dayGroup)
        #expect(volumes.map(\.label) == ["vA", "vB"])          // per-volume, by count desc
        #expect(volumes.map(\.count) == [2, 1])
        #expect(volumes.map(\.seriesKey) == ["vA", "vB"])
    }
}

// MARK: - Volume Label Distillation

@Suite("ChronologyVolumeLabelTests")
struct ChronologyVolumeLabelTests {

    private func label(_ vid: String, _ sub: String, _ title: String) -> String {
        ChronologyViewModel.distilledVolumeLabel(volumeId: vid, subseries: sub, title: title)
    }

    @Test("Modern volume distills to topic + period/volume tag")
    func modernTopicTag() {
        #expect(label("frus1969-76v20", "1969-76",
                      "Foreign Relations of the United States, 1969–1976, Volume XX, Southeast Asia, 1969–1972")
                == "Southeast Asia · 1969-76 v20")
        #expect(label("frus1981-88v06", "1981-88",
                      "Foreign Relations of the United States, 1981–1988, Volume VI, Soviet Union, October 1986–January 1989")
                == "Soviet Union · 1981-88 v6")
    }

    @Test("Topic before the volume number is still extracted, with Part")
    func topicBeforeVolumeAndPart() {
        #expect(label("frus1945v06", "1945",
                      "Foreign Relations of the United States, Diplomatic Papers, 1945, The British Commonwealth, The Far East, Volume VI")
                == "The British Commonwealth, The Far East · 1945 v6")
        #expect(label("frus1952-54v02p1", "1952-54",
                      "Foreign Relations of the United States, 1952–1954, National Security Affairs, Volume II, Part 1")
                == "National Security Affairs · 1952-54 v2 pt.1")
    }

    @Test("Early annual volumes with no topic reduce to the period/part tag")
    func earlyAnnualNoTopic() {
        #expect(label("frus1864p1", "1864",
                      "Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the Second Session Thirty-eighth Congress, Part I")
                == "1864 pt.1")
        #expect(label("frus1870", "1870",
                      "Papers Relating to the Foreign Relations of the United States, Transmitted to Congress with the Annual Message of the President, December 5, 1870")
                == "1870")
        #expect(label("frus1861", "1861",
                      "Message of the President of the United States to the Two Houses of Congress, at the Commencement of the Second Session of the Thirty-seventh Congress")
                == "1861")
    }

    @Test("Same topic in different subseries stays distinct via the tag")
    func distinctAcrossSubseries() {
        let a = label("frus1969-76v01", "1969-76",
                      "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972")
        let b = label("frus1977-80v01", "1977-80",
                      "Foreign Relations of the United States, 1977–1980, Volume I, Foundations of Foreign Policy")
        #expect(a == "Foundations of Foreign Policy · 1969-76 v1")
        #expect(b == "Foundations of Foreign Policy · 1977-80 v1")
        #expect(a != b)
    }

    @Test("Long topics are truncated but the distinct tag is preserved")
    func longTopicTruncated() {
        let result = label("frus1894p1", "1894",
                           "Papers Relating to the Foreign Relations of the United States, 1894, Appendix I, Chinese-Japanese War, Enforcement of Regulation Respective to Fur Seals, Mosquito Territory, Affairs at Bluefields")
        #expect(result.hasSuffix("· 1894 pt.1"))
        #expect(result.contains("…"))
        #expect(result.count < 60)
    }
}
