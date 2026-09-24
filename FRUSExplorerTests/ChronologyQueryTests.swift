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
        concurrencyLimit: 2
    )
    return (pipeline, store)
}

/// The four intervals `ChronologyAggregationTests.overflowDirections` classifies against its
/// summer range: one that begins before the range and ends inside it, one that begins inside and
/// ends after, one that encloses the whole range (a year-only date), and one squarely inside.
/// `ChronologyOverflowChipTests` counts the same four, so the direction rule and the chip's
/// counts are pinned on one set of fixtures (#1387).
private enum ChronOverflowFixtures {
    /// Inclusive start of the picked range.
    static let startISO = "1962-06-01"
    /// Inclusive end of the picked range.
    static let endISO = "1962-08-31"
    /// Begins before the range, ends inside it.
    static let leading = row("a", iso: "1962-05-20", isoMax: "1962-07-10")
    /// Begins inside the range, ends after it.
    static let trailing = row("b", iso: "1962-07-01", isoMax: "1962-09-15")
    /// Begins before the range and ends after it.
    static let both = row("c", iso: "1962-01-01", isoMax: "1962-12-31")
    /// Wholly inside the range — not an overflow row at all.
    static let inside = row("d", iso: "1962-07-01", isoMax: "1962-07-31")

    /// A day-precision row in volume `v` with the given interval.
    static func row(_ doc: String, iso: String, isoMax: String) -> ChronologyRow {
        ChronologyRow(
            volumeId: "v", documentId: doc, header: "Header", dateline: nil, summary: nil,
            dateISO: iso, dateISOMax: isoMax,
            precision: .day, certainty: .exact,
            isEditorialNote: false, isFrontMatter: false, documentNumber: nil
        )
    }
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
        let s = ChronOverflowFixtures.startISO, e = ChronOverflowFixtures.endISO
        let leading = ChronOverflowFixtures.leading
        let trailing = ChronOverflowFixtures.trailing
        let both = ChronOverflowFixtures.both
        let inside = ChronOverflowFixtures.inside

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

    @Test("magnifierBarsByBucket builds finer breakdowns from aggregate counts (capped chart)")
    func aggregateMagnifierBars() {
        // Year chart buckets → month bars (volumes summed, chronological key, no series key).
        let monthCounts: [(bucketKey: String, volumeId: String, count: Int)] = [
            ("1972-01", "vA", 3), ("1972-01", "vB", 2), ("1972-03", "vA", 5), ("1973-06", "vA", 4)
        ]
        let byYear = ChronologyViewModel.magnifierBarsByBucket(
            counts: monthCounts, parentPrefix: 4, volumeBreakdown: false)
        #expect(byYear["1972"]?.map(\.count) == [5, 5])        // Jan (3+2) then Mar, ascending key
        #expect(byYear["1972"]?.allSatisfy { $0.seriesKey == nil } == true)
        #expect(byYear["1973"]?.map(\.count) == [4])

        // Day chart bucket → per-volume bars (count desc, carrying the volume series key).
        let dayCounts: [(bucketKey: String, volumeId: String, count: Int)] = [
            ("1972-03-04", "vA", 2), ("1972-03-04", "vB", 5), ("1972-03-05", "vA", 1)
        ]
        let byDay = ChronologyViewModel.magnifierBarsByBucket(
            counts: dayCounts, parentPrefix: 10, volumeBreakdown: true)
        #expect(byDay["1972-03-04"]?.map(\.label) == ["vB", "vA"])
        #expect(byDay["1972-03-04"]?.map(\.count) == [5, 2])
        #expect(byDay["1972-03-04"]?.map(\.seriesKey) == ["vB", "vA"])
    }
}

// MARK: - ChronologyOverflowChipTests

/// #1387: the "extend beyond this range" chip's breakdown must be a split of its headline.
///
/// Before the fix the view counted "before" and "after" separately, so a row that encloses the
/// whole range (a year-only date around a season) was counted on both sides and the chip read
/// "26 documents extend beyond this range (26 before · 24 after)". These tests drive
/// `ChronologyViewModel.overflowCounts` and the copy on `ChronologyOverflowCounts`, which the
/// view draws; the last test pins that it does. None depends on the idiom — the chip is shared
/// SwiftUI — so they fail on any destination when the rule regresses.
@Suite("ChronologyOverflowChipTests")
struct ChronologyOverflowChipTests {

    private typealias F = ChronOverflowFixtures

    private func counts(_ rows: [ChronologyRow]) -> ChronologyOverflowCounts {
        ChronologyViewModel.overflowCounts(rows, startISO: F.startISO, endISO: F.endISO)
    }

    private func counts(_ before: Int, _ after: Int, _ both: Int) -> ChronologyOverflowCounts {
        ChronologyOverflowCounts(beginsBeforeOnly: before, endsAfterOnly: after, spansWholeRange: both)
    }

    @Test("Each overflow row is counted once: one begins before, one ends after, one reaches past both ends")
    func threeFixturesCountOnceEach() {
        let c = counts([F.leading, F.trailing, F.both])
        #expect(c.beginsBeforeOnly == 1)
        #expect(c.endsAfterOnly == 1)
        #expect(c.spansWholeRange == 1)
        #expect(c.total == 3, "the three parts add up to the three rows")
    }

    @Test("A row inside the range adds to no part")
    func insideRowAddsNothing() {
        // Mixed with one leading and one enclosing row, so a mutation that files the inside row
        // under ANY of the three parts changes the result.
        let c = counts([F.leading, F.inside, F.both])
        #expect(c == counts(1, 0, 1))
        #expect(c.total == 2)
    }

    @Test("The captured shape — 2 begin before, 24 enclose — reads as 26 split into 2 and 24")
    func capturedShapeAddsUp() {
        // The macOS manual's Chronology capture (Sep 1 – Nov 30, 1962) printed
        // "26 documents extend beyond this range (26 before · 24 after)".
        let leadingOnly = (0..<2).map { F.row("l\($0)", iso: "1962-05-20", isoMax: "1962-07-10") }
        let enclosing = (0..<24).map { F.row("e\($0)", iso: "1962-01-01", isoMax: "1962-12-31") }
        let c = counts(leadingOnly + enclosing)
        #expect(c == counts(2, 0, 24))
        #expect(c.chipTitle == "26 documents extend beyond this range")
        #expect(c.chipBreakdown == "(2 begin before · 24 reach past both ends)")
    }

    @Test("A part of one is singular")
    func singularParts() {
        let c = counts(1, 1, 1)
        #expect(c.chipBreakdown == "(1 begins before · 1 ends after · 1 reaches past both ends)")
        #expect(c.chipTitle == "3 documents extend beyond this range")
    }

    @Test("Plural parts and the total are grouped")
    func pluralPartsAreGrouped() {
        let c = counts(2, 3, 12_067)
        #expect(c.chipBreakdown == "(2 begin before · 3 end after · 12,067 reach past both ends)")
        #expect(c.chipTitle == "12,072 documents extend beyond this range")
        #expect(c.chipAccessibilityLabel
                == "12,072 documents have uncertain dates that extend beyond this range. Toggle to show them.")
    }

    @Test("A part that is zero is left out, each on its own")
    func zeroPartsAreLeftOut() {
        #expect(counts(0, 3, 4).chipBreakdown == "(3 end after · 4 reach past both ends)")
        #expect(counts(5, 0, 6).chipBreakdown == "(5 begin before · 6 reach past both ends)")
        #expect(counts(2, 3, 0).chipBreakdown == "(2 begin before · 3 end after)")
        #expect(counts(0, 0, 0).chipBreakdown == "")
    }

    @Test("One document reads in the singular, on screen and to VoiceOver")
    func oneDocumentIsSingular() {
        let c = counts([F.both])
        #expect(c == counts(0, 0, 1))
        #expect(c.chipTitle == "1 document extends beyond this range")
        #expect(c.chipBreakdown == "(1 reaches past both ends)")
        #expect(c.chipAccessibilityLabel
                == "1 document has an uncertain date that extends beyond this range. Toggle to show it.")
    }

    // MARK: The view draws these, and counts nowhere else

    /// `ChronologyView.swift`, read from the repository.
    private static func viewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Chronology/ChronologyView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The body of the declaration that starts with `header`, from its first `{` to the `}` that
    /// balances it — the function's own text, never a window that runs into the next one.
    private static func body(of header: String, in source: String) -> String? {
        guard let start = source.range(of: header),
              let open = source[start.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var cursor = open
        while cursor < source.endIndex {
            if source[cursor] == "{" { depth += 1 }
            if source[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(source[start.lowerBound...cursor]) }
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    /// Occurrences of `pattern` (a regular expression) in `text`.
    private static func matches(_ pattern: String, in text: String) throws -> Int {
        try NSRegularExpression(pattern: pattern).numberOfMatches(
            in: text, range: NSRange(text.startIndex..., in: text))
    }

    @Test("The chip draws the shared counts' sentences, and the view counts directions nowhere else")
    func chipDrawsTheSharedCounts() throws {
        let source = try Self.viewSource()
        let chip = try #require(Self.body(of: "private func overflowChip(", in: source),
                                "ChronologyView.overflowChip not found — the scan would read nothing")
        let label = try #require(Self.body(of: "private func overflowDirectionLabel(", in: source),
                                 "ChronologyView.overflowDirectionLabel not found")

        // Counted once, over the rows the section lists, against the range that loaded them.
        #expect(try Self.matches(#"let counts = ChronologyViewModel\.overflowCounts\(\s*displayedOverflowRows,\s*startISO: vm\.loadedStartISO,\s*endISO: vm\.loadedEndISO\s*\)"#, in: chip) == 1,
                "overflowChip must count through ChronologyViewModel.overflowCounts over displayedOverflowRows")
        #expect(try Self.matches(#"Text\(\s*verbatim:\s*counts\.chipTitle\s*\)"#, in: chip) == 1,
                "overflowChip must draw counts.chipTitle")
        #expect(try Self.matches(#"Text\(\s*verbatim:\s*counts\.chipBreakdown\s*\)"#, in: chip) == 1,
                "overflowChip must draw counts.chipBreakdown")
        #expect(try Self.matches(#"\.accessibilityLabel\(\s*Text\(\s*verbatim:\s*counts\.chipAccessibilityLabel\s*\)\s*\)"#, in: chip) == 1,
                "overflowChip must hand counts.chipAccessibilityLabel to VoiceOver")
        #expect(!chip.contains("displayedOverflowRows.count"),
                "the headline's number must be the parts' total, not a second count")

        // A second counter anywhere in the view is how the double count shipped: every direction
        // test left in the file belongs to the per-row label.
        let callsInFile = try Self.matches(#"ChronologyViewModel\.overflowDirection\("#, in: source)
        let callsInLabel = try Self.matches(#"ChronologyViewModel\.overflowDirection\("#, in: label)
        #expect(callsInLabel == 1, "the row label must still read the direction rule")
        #expect(callsInFile == callsInLabel,
                "ChronologyView calls overflowDirection \(callsInFile - callsInLabel) time(s) outside overflowDirectionLabel")
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

    /// The real Appendix I volume. This fixture used to pair that title with `frus1894p1`, an id
    /// the manifest does not have, and pin "· 1894 pt.1" — the Appendix-as-Part misreading #1388
    /// corrected — so it now carries the real id and the reading the tag gives it.
    @Test("Long topics are truncated but the distinct tag is preserved")
    func longTopicTruncated() {
        let result = label("frus1894app1", "1894",
                           "Foreign Relations of the United States, 1894, Appendix I, Chinese-Japanese War, Enforcement of Regulation Respective to Fur Seals, Mosquito Territory, Affairs at Bluefields, Claim of Antonio Maximo Mora, Import Duties on Certain Products of Colombia, Haiti, and Venezuela, Affairs in the Samoan Islands")
        #expect(result.hasSuffix("· 1894 app.1"))
        #expect(result.contains("…"))
        #expect(result.count < 60)
    }

    // MARK: The tag reads the whole id suffix (#1388)

    /// The label's tag half: the text after its last `" · "`. It is the half a unique tag makes
    /// sufficient on its own — which only matters on a surface that KEEPS it when it cuts: the
    /// Cross-Reference matrix head-truncates, and the Mac hover magnifier renders the halves apart
    /// (`distilledVolumeLabelParts`). The one-line surfaces that tail-truncate the joined label
    /// drop this half first.
    private func tag(_ label: String) -> String {
        label.components(separatedBy: " · ").last ?? label
    }

    @Test("A microfiche supplement's tag keeps its volume range and says fiche (#1388)")
    func microficheSupplementTag() {
        let volumeX = label("frus1961-63v10", "1961-63",
                            "Foreign Relations of the United States, 1961–1963, Volume X, Cuba, January 1961–September 1962")
        let supplement = label("frus1961-63v10-12mSupp", "1961-63",
                               "Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath")
        // Both TAGS read "1961-63 v10" before #1388: the tag kept the first v-number and dropped
        // "-12mSupp". The labels still differed — "Cuba · …" against "Microfiche Supplement,
        // American… · …" — but only in the topic half, which a tail-truncating surface cuts
        // first; the 40-character cut had already removed "Republics; Cuba 1961–1962; …".
        #expect(volumeX == "Cuba · 1961-63 v10")
        #expect(supplement == "Microfiche Supplement, American… · 1961-63 v10–12 fiche")
        #expect(tag(volumeX) != tag(supplement))
        // This supplement's title never says "Microfiche Supplement", so only its tag can: before
        // #1388 it read "… · 1961-63 v7", beside Volume VII's own "… · 1961-63 v7".
        let armsSupplement = label("frus1961-63v07-09mSupp", "1961-63",
                                   "Foreign Relations of the United States, 1961–1963, Volumes VII, VIII, IX, Arms Control; National Security Policy; Foreign Economic Policy")
        let volumeVII = label("frus1961-63v07", "1961-63",
                              "Foreign Relations of the United States, 1961–1963, Volume VII, Arms Control and Disarmament")
        #expect(tag(armsSupplement) == "1961-63 v7–9 fiche")
        #expect(tag(volumeVII) == "1961-63 v7")
    }

    @Test("An E-volume's tag keeps its E, and a second edition says so (#1388)")
    func eVolumeAndEditionTags() {
        let first = label("frus1969-76ve15p2", "1969-76",
                          "Foreign Relations of the United States, 1969–1976, Volume E–15, Part 2, Documents on Western Europe, 1973–1976")
        let second = label("frus1969-76ve15p2Ed2", "1969-76",
                           "Foreign Relations of the United States, 1969–1976, Volume E–15, Part 2, Documents on Western Europe, 1973–1976, Second, Revised Edition")
        // Before #1388 both tags were "1969-76 pt.2" — the `(E-)?` branch never matched the ids'
        // lower-case `ve15` — and the two labels differed only in where the topic cut fell.
        #expect(tag(first) == "1969-76 vE-15 pt.2")
        #expect(tag(second) == "1969-76 vE-15 pt.2 ed.2")
        #expect(tag(first) != tag(second))
        // …and every E-volume's first part read "1969-76 pt.1".
        #expect(tag(label("frus1969-76ve05p1", "1969-76", "")) == "1969-76 vE-5 pt.1")
        #expect(tag(label("frus1969-76ve14p1", "1969-76", "")) == "1969-76 vE-14 pt.1")
    }

    /// The shape table below reads only bundled ids, whose subseries always prefixes the id, so
    /// no row of it reaches `volumeTag`'s verbatim fallback. The app does: ChronologyView and the
    /// Cross-Reference matrix pass `entry?.subseries ?? ""` for a volume the manifest lacks.
    /// Measured: a `break` in place of the fallback passed every earlier test in this suite and in
    /// `CorpusAnalyticsServiceTests`, and failed all three assertions here — the first label came
    /// back empty and the `x` was dropped from the second.
    @Test("An id shape the grammar does not know is kept verbatim, not dropped (#1388)")
    func unknownSuffixKeptVerbatim() {
        // No subseries: nothing after `frus` is a token the grammar reads, so all of it is kept.
        #expect(label("frus1969-76v20", "", "") == "1969-76v20")
        // An unknown token after a known one ends the scan and is kept as it stands.
        #expect(label("frus1969-76v20x", "1969-76", "") == "1969-76 v20 x")
        // A subseries that does not prefix the id still drops `frus`; the rest is kept verbatim.
        #expect(label("frus1969-76v20", "1970", "") == "1970 1969-76v20")
    }

    /// `distilledVolumeLabelParts` is what lets a surface truncate the topic and never the tag —
    /// the Mac hover magnifier, which #1388 found cutting the supplement's label to "Microfiche
    /// Supplement, American… ·…", and A2's matrix rows. The topic must come back WHOLE: a surface
    /// fitting it to its own width has no use for the joined label's 40-character pre-cut, and a
    /// topic that arrives already ending in "…" would show two ellipses once the surface cuts it.
    @Test("The label's halves come apart: the whole topic, and the whole tag (#1388)")
    func labelPartsKeepWholeTopicAndTag() {
        let title = "Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath"
        let parts = ChronologyViewModel.distilledVolumeLabelParts(
            volumeId: "frus1961-63v10-12mSupp", subseries: "1961-63", title: title)
        #expect(parts.tag == "1961-63 v10–12 fiche")
        #expect(parts.topic == "Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath")
        #expect(!parts.topic.contains("…"))
        // The joined label is the same two halves, with only the topic cut.
        let joined = label("frus1961-63v10-12mSupp", "1961-63", title)
        #expect(joined == "Microfiche Supplement, American… · 1961-63 v10–12 fiche")
        #expect(tag(joined) == parts.tag)
        #expect(parts.topic.hasPrefix(String(joined.prefix { $0 != "…" })))
        // A topic-less early annual has an empty topic and its whole tag, as the joined label does.
        let annual = ChronologyViewModel.distilledVolumeLabelParts(
            volumeId: "frus1864p1", subseries: "1864",
            title: "Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the Second Session Thirty-eighth Congress, Part I")
        #expect(annual == VolumeLabelParts(topic: "", tag: "1864 pt.1"))
    }

    /// One real volume per id-suffix SHAPE the bundled manifest uses (the suffix after
    /// `frus<subseries>`, digit runs written `N`), with the tag it must read as. An empty title
    /// yields no topic, so the label IS the tag.
    private static let pinnedTags: [(volumeId: String, subseries: String, tag: String)] = [
        ("frus1969-76v20", "1969-76", "1969-76 v20"),                  // vN
        ("frus1952-54v02p1", "1952-54", "1952-54 v2 pt.1"),            // vNpN
        ("frus1870", "1870", "1870"),                                  // (none)
        ("frus1864p1", "1864", "1864 pt.1"),                           // pN
        ("frus1919Parisv01", "1919", "1919 Paris v1"),                 // ParisvN — was "1919 v1", the 1919 annual's tag
        ("frus1969-76ve01", "1969-76", "1969-76 vE-1"),                // veN — was "1969-76 ve01"
        ("frus1969-76ve05p1", "1969-76", "1969-76 vE-5 pt.1"),         // veNpN — was "1969-76 pt.1"
        ("frus1872p2v1", "1872", "1872 pt.2 v1"),                      // pNvN — printed "Part II, Volume I"
        ("frus1917Supp01v01", "1917", "1917 Supp.1 v1"),               // SuppNvN — was "1917 v1 pt.1"
        ("frus1894app1", "1894", "1894 app.1"),                        // appN — Appendix I, was "1894 pt.1"
        ("frus1901China", "1901", "1901 China"),                       // China
        ("frus1914Supp", "1914", "1914 Supp"),                         // Supp
        ("frus1917-72PubDipv06", "1917-72", "1917-72 PubDip v6"),      // PubDipvN
        ("frus1918Russiav01", "1918", "1918 Russia v1"),               // RussiavN
        ("frus1955-57v03mSupp", "1955-57", "1955-57 v3 fiche"),        // vNmSupp — was "1955-57 v3", Volume III's tag
        ("frus1945-50Intel", "1945-50", "1945-50 Intel"),              // Intel
        ("frus1945Berlinv01", "1945", "1945 Berlin v1"),               // BerlinvN — was "1945 v1", the 1945 annual's tag
        ("frus1961-63v07-09mSupp", "1961-63", "1961-63 v7–9 fiche"),   // vN-NmSupp
        ("frus1877app", "1877", "1877 app"),                           // app
        ("frus1894Nicaragua", "1894", "1894 Nicaragua"),               // Nicaragua
        ("frus1917-72PubDip", "1917-72", "1917-72 PubDip"),            // PubDip
        ("frus1918Supp02", "1918", "1918 Supp.2"),                     // SuppN — was "1918 pt.2"
        ("frus1919Russia", "1919", "1919 Russia"),                     // Russia
        ("frus1943CairoTehran", "1943", "1943 CairoTehran"),           // CairoTehran
        ("frus1944Quebec", "1944", "1944 Quebec"),                     // Quebec
        ("frus1945Malta", "1945", "1945 Malta"),                       // Malta
        ("frus1951-54Iran", "1951-54", "1951-54 Iran"),                // Iran
        ("frus1951-54IranEd2", "1951-54", "1951-54 Iran ed.2"),        // IranEdN
        ("frus1952-54Guat", "1952-54", "1952-54 Guat"),                // Guat
        ("frus1969-76ve15p2Ed2", "1969-76", "1969-76 vE-15 pt.2 ed.2"), // veNpNEdN
        ("frus1977-80v09Ed2", "1977-80", "1977-80 v9 ed.2"),           // vNEdN — was "1977-80 v9"
    ]

    /// A volume id's suffix shape: what follows `frus<subseries>`, with every digit run as `N`.
    private static func suffixShape(volumeId: String, subseries: String) -> String {
        let prefix = "frus" + subseries
        let suffix = volumeId.hasPrefix(prefix) ? String(volumeId.dropFirst(prefix.count)) : "!" + volumeId
        return suffix.replacingOccurrences(of: "[0-9]+", with: "N", options: .regularExpression)
    }

    /// Pins the tag GRAMMAR, which the corpus uniqueness test cannot: a tag can be unique and
    /// still misread its volume (`frus1917Supp01v01` was "1917 v1 pt.1" — the `Supp01` read as a
    /// Part). And it fails naming any suffix shape a new volume brings that nobody has pinned,
    /// which is how a volume-id shape broke the analytics subseries derivation once (#208).
    @Test("Every id-suffix shape in the bundled manifest reads as its pinned tag (#1388)")
    @MainActor
    func everySuffixShapeReadsAsItsPinnedTag() throws {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        let manifestIds = Set(entries.map(\.volumeId))
        let pinnedShapes = Set(Self.pinnedTags.map { Self.suffixShape(volumeId: $0.volumeId, subseries: $0.subseries) })
        #expect(pinnedShapes.count == Self.pinnedTags.count, "each pinned row must stand for a different shape")
        for row in Self.pinnedTags {
            #expect(manifestIds.contains(row.volumeId), "\(row.volumeId) is not a bundled volume")
            #expect(label(row.volumeId, row.subseries, "") == row.tag, "\(row.volumeId)")
        }
        var unpinned: [String: [String]] = [:]
        for entry in entries {
            let shape = Self.suffixShape(volumeId: entry.volumeId, subseries: entry.subseries)
            if !pinnedShapes.contains(shape) { unpinned[shape, default: []].append(entry.volumeId) }
        }
        for (shape, volumeIds) in unpinned.sorted(by: { $0.key < $1.key }) {
            Issue.record("Id-suffix shape '\(shape)' has no pinned tag: \(volumeIds.joined(separator: ", "))")
        }
    }
}
