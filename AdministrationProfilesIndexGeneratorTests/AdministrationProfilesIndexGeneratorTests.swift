// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import AdministrationProfilesIndexGeneratorCore

/// Unit tests for the administration-profiles index generator: half-open point
/// attribution, any-overlap range attribution, aggregation, undated handling, and
/// determinism.
struct AdministrationProfilesIndexGeneratorTests {

    // MARK: - Fixture administrations (a slice of the real table)

    /// FDR → Truman boundary, Nixon, Ford, plus the two Cleveland terms and the current
    /// null-end administration — enough to exercise every rule.
    private static let admins: [Administration] = [
        Administration(id: "cleveland-1", number: 22, president: "Grover Cleveland",
                       party: "Democratic", start: "1885-03-04", end: "1889-03-04"),
        Administration(id: "cleveland-2", number: 24, president: "Grover Cleveland",
                       party: "Democratic", start: "1893-03-04", end: "1897-03-04"),
        Administration(id: "f-roosevelt", number: 32, president: "Franklin D. Roosevelt",
                       party: "Democratic", start: "1933-03-04", end: "1945-04-12"),
        Administration(id: "truman", number: 33, president: "Harry S. Truman",
                       party: "Democratic", start: "1945-04-12", end: "1953-01-20"),
        Administration(id: "nixon", number: 37, president: "Richard M. Nixon",
                       party: "Republican", start: "1969-01-20", end: "1974-08-09"),
        Administration(id: "ford", number: 38, president: "Gerald R. Ford",
                       party: "Republican", start: "1974-08-09", end: "1977-01-20"),
        Administration(id: "trump-2", number: 47, president: "Donald J. Trump",
                       party: "Republican", start: "2025-01-20", end: nil),
    ]

    private func admin(_ id: String) -> Administration {
        Self.admins.first { $0.id == id }!
    }

    // MARK: - Half-open point attribution

    @Test func startInclusiveEndExclusive() {
        let truman = admin("truman")
        // Start day is inclusive.
        #expect(truman.contains(day: "1945-04-12"))
        // Day before start is not.
        #expect(!truman.contains(day: "1945-04-11"))
        // End day is exclusive (belongs to the successor).
        #expect(!truman.contains(day: "1953-01-20"))
        // Day before end is inclusive.
        #expect(truman.contains(day: "1953-01-19"))
    }

    @Test func successionDayGoesToSuccessor() {
        // 1945-04-12 is FDR's death / Truman's accession. Half-open => Truman, not FDR.
        #expect(!admin("f-roosevelt").contains(day: "1945-04-12"))
        #expect(admin("truman").contains(day: "1945-04-12"))
    }

    @Test func nixonFordBoundaryDistinct() {
        // Nixon resigns 1974-08-09; that day is Ford's.
        #expect(!admin("nixon").contains(day: "1974-08-09"))
        #expect(admin("ford").contains(day: "1974-08-09"))
        #expect(admin("nixon").contains(day: "1974-08-08"))
    }

    @Test func clevelandTermsDisambiguatedByYear() {
        // 1886 → first term; 1895 → second term; the gap year 1891 → neither.
        #expect(admin("cleveland-1").contains(day: "1886-06-01"))
        #expect(!admin("cleveland-2").contains(day: "1886-06-01"))
        #expect(admin("cleveland-2").contains(day: "1895-06-01"))
        #expect(!admin("cleveland-1").contains(day: "1895-06-01"))
        #expect(!admin("cleveland-1").contains(day: "1891-06-01"))
        #expect(!admin("cleveland-2").contains(day: "1891-06-01"))
    }

    @Test func nullEndCurrentAdminMatchesAnyLaterDate() {
        let trump2 = admin("trump-2")
        #expect(trump2.contains(day: "2025-01-20"))
        #expect(trump2.contains(day: "2027-12-31"))
        #expect(!trump2.contains(day: "2025-01-19"))
    }

    // MARK: - Any-overlap range attribution

    @Test func rangeSpanningTwoAdminsHitsBoth() {
        // A range 1944-06-01 … 1945-08-01 straddles the FDR→Truman boundary.
        let start = "1944-06-01", end = "1945-08-01"
        #expect(admin("f-roosevelt").rangeOverlaps(rangeStart: start, rangeEnd: end))
        #expect(admin("truman").rangeOverlaps(rangeStart: start, rangeEnd: end))
        // But not Nixon, decades later.
        #expect(!admin("nixon").rangeOverlaps(rangeStart: start, rangeEnd: end))
    }

    @Test func rangeTouchingStartBoundaryOverlaps() {
        // A range ending exactly on an admin's start day overlaps (start is inclusive).
        #expect(admin("truman").rangeOverlaps(rangeStart: "1945-01-01", rangeEnd: "1945-04-12"))
        // A range ending on the day before start does not.
        #expect(!admin("truman").rangeOverlaps(rangeStart: "1945-01-01", rangeEnd: "1945-04-11"))
    }

    @Test func rangeTouchingEndBoundaryHalfOpen() {
        // A range starting exactly on an admin's exclusive end day does NOT overlap it
        // (that day belongs to the successor).
        #expect(!admin("f-roosevelt").rangeOverlaps(rangeStart: "1945-04-12", rangeEnd: "1945-05-01"))
        // A range starting the day before the end does overlap.
        #expect(admin("f-roosevelt").rangeOverlaps(rangeStart: "1945-04-11", rangeEnd: "1945-05-01"))
    }

    @Test func rangeIntoNullEndAdmin() {
        #expect(admin("trump-2").rangeOverlaps(rangeStart: "2024-01-01", rangeEnd: "2026-01-01"))
        #expect(!admin("trump-2").rangeOverlaps(rangeStart: "2020-01-01", rangeEnd: "2025-01-19"))
    }

    // MARK: - DocumentDate classification (mirrors extractDateRange)

    @Test func classifyPointWhenMinEqualsMaxDay() {
        let d = DocumentDateExtractor.classify(
            min: "1945-04-12T00:00:00-05:00", max: "1945-04-12T23:59:59-05:00")
        #expect(d == .point("1945-04-12"))
    }

    @Test func classifyRangeWhenDaysDiffer() {
        let d = DocumentDateExtractor.classify(
            min: "1967-07-29T00:00:00-05:00", max: "1972-11-04T23:59:59-05:00")
        #expect(d == .range(start: "1967-07-29", end: "1972-11-04"))
    }

    @Test func classifyUndatedWhenBothMissing() {
        #expect(DocumentDateExtractor.classify(min: nil, max: nil) == .undated)
    }

    @Test func classifyYearOnlyPadsToJan1() {
        // A bare year (early-volume dateline style) pads to Jan 1, still a point date.
        #expect(DocumentDateExtractor.classify(min: "1861", max: "1861") == .point("1861-01-01"))
    }

    @Test func extractParsesDocumentDivsFromXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"
             xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <text><body>
            <div frus:doc-dateTime-min="1945-04-12T00:00:00-05:00"
                 frus:doc-dateTime-max="1945-04-12T23:59:59-05:00"
                 subtype="historical-document" type="document" xml:id="d1"><p>x</p></div>
            <div frus:doc-dateTime-min="1967-07-29T00:00:00-05:00"
                 frus:doc-dateTime-max="1972-11-04T23:59:59-05:00"
                 subtype="editorial-note" type="document" xml:id="d2"><p>y</p></div>
            <div type="section"><p>not a document</p></div>
          </body></text>
        </TEI>
        """
        let dates = DocumentDateExtractor.extract(fromXML: Data(xml.utf8))
        #expect(dates == [.point("1945-04-12"), .range(start: "1967-07-29", end: "1972-11-04")])
    }

    // MARK: - Aggregation

    /// Two synthetic volumes exercising point/range/undated, per-(admin,volume) tallies,
    /// distinct-volume counts, and the volumeCount vs volumeCountPointOnly distinction.
    private func sampleIndex() -> AdministrationProfilesIndex {
        let volA = ProfileAggregator.VolumeDates(volumeId: "volA", dates: [
            .point("1945-04-12"),                              // Truman
            .point("1946-01-01"),                              // Truman
            .range(start: "1944-06-01", end: "1945-08-01"),    // FDR + Truman
            .undated,
        ])
        let volB = ProfileAggregator.VolumeDates(volumeId: "volB", dates: [
            .range(start: "1944-01-01", end: "1944-12-31"),    // FDR only (range, no point)
            .point("1972-05-01"),                              // Nixon
        ])
        return ProfileAggregator.aggregate(
            administrations: Self.admins, volumes: [volA, volB],
            schemaVersion: 1, generated: "2026-07-05")
    }

    private func profile(_ index: AdministrationProfilesIndex, _ id: String)
        -> AdministrationProfilesIndex.AdministrationProfile {
        index.administrations.first { $0.id == id }!
    }

    @Test func aggregatesPerAdminCounts() {
        let index = sampleIndex()
        let truman = profile(index, "truman")
        #expect(truman.pointDocCount == 2)          // volA two points
        #expect(truman.rangeDocCount == 1)          // volA straddling range
        let fdr = profile(index, "f-roosevelt")
        #expect(fdr.pointDocCount == 0)
        #expect(fdr.rangeDocCount == 2)             // volA straddling range + volB range
        let nixon = profile(index, "nixon")
        #expect(nixon.pointDocCount == 1)
        #expect(nixon.rangeDocCount == 0)
    }

    @Test func volumeCountVsPointOnly() {
        let index = sampleIndex()
        // FDR sees range docs from both volumes but a POINT doc from neither.
        let fdr = profile(index, "f-roosevelt")
        #expect(fdr.volumeCount == 2)
        #expect(fdr.volumeCountPointOnly == 0)
        // Truman sees only volA, and it has point docs there.
        let truman = profile(index, "truman")
        #expect(truman.volumeCount == 1)
        #expect(truman.volumeCountPointOnly == 1)
    }

    @Test func perAdminVolumeBreakdown() {
        let index = sampleIndex()
        let truman = profile(index, "truman")
        #expect(truman.volumes.count == 1)
        #expect(truman.volumes[0].volumeId == "volA")
        #expect(truman.volumes[0].pointDocs == 2)
        #expect(truman.volumes[0].rangeDocs == 1)
    }

    @Test func coverageEarliestLatestFromPointsOnly() {
        let index = sampleIndex()
        let truman = profile(index, "truman")
        #expect(truman.coverageEarliest == 1945)
        #expect(truman.coverageLatest == 1946)
        // FDR has no point docs → nil coverage.
        let fdr = profile(index, "f-roosevelt")
        #expect(fdr.coverageEarliest == nil)
        #expect(fdr.coverageLatest == nil)
    }

    @Test func volumeTotalsAndUndated() {
        let index = sampleIndex()
        let a = index.volumeTotals["volA"]!
        #expect(a.pointDocs == 2)
        #expect(a.rangeDocs == 1)
        #expect(a.undatedDocs == 1)
        let b = index.volumeTotals["volB"]!
        #expect(b.pointDocs == 1)
        #expect(b.rangeDocs == 1)
        #expect(b.undatedDocs == 0)
    }

    @Test func globalTotalsReconcileWithVolumeTotals() {
        let index = sampleIndex()
        let sumPoint = index.volumeTotals.values.reduce(0) { $0 + $1.pointDocs }
        let sumRange = index.volumeTotals.values.reduce(0) { $0 + $1.rangeDocs }
        let sumUndated = index.volumeTotals.values.reduce(0) { $0 + $1.undatedDocs }
        #expect(sumPoint == index.totalDocumentsPointDated)
        #expect(sumRange == index.totalDocumentsRangeDated)
        #expect(sumUndated == index.totalDocumentsUndated)
        #expect(index.totalDocumentsPointDated == 3)
        #expect(index.totalDocumentsRangeDated == 2)
        #expect(index.totalDocumentsUndated == 1)
        #expect(index.volumesCovered == 2)
    }

    // MARK: - Determinism

    @Test func deterministicByteIdenticalRerun() throws {
        let a = sampleIndex()
        let b = sampleIndex()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let da = try encoder.encode(a)
        let db = try encoder.encode(b)
        #expect(da == db)
    }

    @Test func volumeBreakdownSortedByPointDocsDescending() {
        // A volume with more point docs sorts ahead of one with fewer, in the same admin.
        let v1 = ProfileAggregator.VolumeDates(volumeId: "zzz", dates: [
            .point("1946-01-01"), .point("1946-02-01"), .point("1946-03-01"),
        ])
        let v2 = ProfileAggregator.VolumeDates(volumeId: "aaa", dates: [
            .point("1946-04-01"),
        ])
        let index = ProfileAggregator.aggregate(
            administrations: Self.admins, volumes: [v1, v2],
            schemaVersion: 1, generated: "2026-07-05")
        let truman = profile(index, "truman")
        #expect(truman.volumes.map(\.volumeId) == ["zzz", "aaa"])
    }
}
