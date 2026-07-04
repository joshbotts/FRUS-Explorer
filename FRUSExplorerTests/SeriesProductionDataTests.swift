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

// MARK: - SeriesProductionDataTests

/// Pure derivation tests for `SeriesProductionData` (Analytics SA-1b): lag math
/// across the three date forms in the corpus, per-year and cumulative counts,
/// coverage spans, era/lag bucket boundaries, and empty-input safety. No SwiftUI
/// is instantiated.
///
/// Version history:
///   1.0 — Analytics SA-1b: initial implementation
struct SeriesProductionDataTests {

    // MARK: - Fixtures

    /// Builds a manifest entry with just the fields `SeriesProductionData`
    /// reads; all others are neutral.
    private func entry(
        id: String,
        subseries: String = "1969-76",
        earliest: String?,
        latest: String?,
        publicationDate: String?
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id,
            filename: "\(id).xml",
            subseries: subseries,
            title: "Title \(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: publicationDate,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: []
        )
    }

    // MARK: - Lag math + date-form parsing

    @Test("Lag = printYear − coverageEndYear across all three date forms")
    func lagMathAndDateForms() {
        let entries = [
            // Bare year print date, ISO datetime coverage.
            entry(id: "a", earliest: "1969-01-01T00:00:00", latest: "1976-12-31T00:00:00", publicationDate: "2003"),
            // Full ISO publication date (the frus1969-76v32 shape).
            entry(id: "b", earliest: "1969", latest: "1976", publicationDate: "2010-11-05"),
            // Negative lag: printed before the latest document year (early near-
            // contemporaneous volume).
            entry(id: "c", earliest: "1861", latest: "1865", publicationDate: "1861"),
        ]
        let data = SeriesProductionData(entries: entries)

        let byId = Dictionary(uniqueKeysWithValues: data.lagPoints.map { ($0.volumeId, $0) })
        #expect(byId["a"]?.lagYears == 2003 - 1976)  // 27
        #expect(byId["a"]?.coverageEndYear == 1976)
        #expect(byId["a"]?.printYear == 2003)
        #expect(byId["b"]?.lagYears == 2010 - 1976)  // 34, parsed from "2010-11-05"
        #expect(byId["c"]?.lagYears == 1861 - 1865)  // -4, honest negative
        #expect(data.lagPoints.count == 3)
    }

    @Test("An entry missing a print year or coverage-end contributes no lag point")
    func lagRequiresBothYears() {
        let entries = [
            entry(id: "noPub", earliest: "1900", latest: "1905", publicationDate: nil),
            entry(id: "noLatest", earliest: "1900", latest: nil, publicationDate: "1950"),
            entry(id: "ok", earliest: "1900", latest: "1905", publicationDate: "1950"),
        ]
        let data = SeriesProductionData(entries: entries)
        #expect(data.lagPoints.map(\.volumeId) == ["ok"])
        #expect(data.countLagComputable == 1)
        #expect(data.countWithPrintYear == 2)      // noLatest + ok
        #expect(data.countWithCoverage == 2)       // noPub + ok (both have earliest+latest)
        #expect(data.total == 3)
    }

    // MARK: - Per-print-year counts

    @Test("volumesPerPrintYear counts and ascending order")
    func volumesPerPrintYearCounts() {
        let entries = [
            entry(id: "a", earliest: "1900", latest: "1905", publicationDate: "1950"),
            entry(id: "b", earliest: "1901", latest: "1906", publicationDate: "1950"),
            entry(id: "c", earliest: "1902", latest: "1907", publicationDate: "1948"),
            entry(id: "d", earliest: "1903", latest: "1908", publicationDate: nil),
        ]
        let data = SeriesProductionData(entries: entries)
        #expect(data.volumesPerPrintYear.count == 2)
        #expect(data.volumesPerPrintYear[0].printYear == 1948)
        #expect(data.volumesPerPrintYear[0].count == 1)
        #expect(data.volumesPerPrintYear[1].printYear == 1950)
        #expect(data.volumesPerPrintYear[1].count == 2)
        // by-era breakdown sums to the same totals.
        let byEraTotal = data.volumesPerPrintYearByEra.reduce(0) { $0 + $1.count }
        #expect(byEraTotal == 3)
    }

    // MARK: - Coverage spans

    @Test("coverageSpans require earliest+latest and are sorted by start year")
    func coverageSpansSorted() {
        let entries = [
            entry(id: "late", earliest: "1990", latest: "1992", publicationDate: "2015"),
            entry(id: "early", earliest: "1861", latest: "1865", publicationDate: "1900"),
            entry(id: "mid", earliest: "1945", latest: "1950", publicationDate: "1980"),
            entry(id: "nospan", earliest: nil, latest: "1970", publicationDate: "2000"),
        ]
        let data = SeriesProductionData(entries: entries)
        #expect(data.coverageSpans.map(\.volumeId) == ["early", "mid", "late"])
        #expect(data.coverageSpans.first?.startYear == 1861)
        #expect(data.coverageSpans.first?.endYear == 1865)
        // Lag bucket is populated when a print year exists.
        #expect(data.coverageSpans.first?.lagBucket == LagBucket.bucket(lag: 1900 - 1865))
    }

    @Test("A coverage span without a print year has a nil lag bucket")
    func coverageSpanNilLagBucket() {
        let entries = [entry(id: "x", earliest: "1900", latest: "1905", publicationDate: nil)]
        let data = SeriesProductionData(entries: entries)
        #expect(data.coverageSpans.count == 1)
        #expect(data.coverageSpans.first?.lagBucket == nil)
    }

    // MARK: - Cumulative running total

    @Test("cumulativeByPrintYear is monotonic and ends at the print-year count")
    func cumulativeMonotonic() {
        let entries = [
            entry(id: "a", earliest: "1900", latest: "1905", publicationDate: "1948"),
            entry(id: "b", earliest: "1901", latest: "1906", publicationDate: "1950"),
            entry(id: "c", earliest: "1902", latest: "1907", publicationDate: "1950"),
            entry(id: "d", earliest: "1903", latest: "1908", publicationDate: "1955"),
            entry(id: "e", earliest: "1904", latest: "1909", publicationDate: nil),  // no print year
        ]
        let data = SeriesProductionData(entries: entries)
        let counts = data.cumulativeByPrintYear.map(\.cumulativeCount)
        // Monotonic non-decreasing.
        #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(data.cumulativeByPrintYear.map(\.printYear) == [1948, 1950, 1955])
        #expect(counts == [1, 3, 4])
        // Final cumulative equals total volumes WITH a print year.
        #expect(data.cumulativeByPrintYear.last?.cumulativeCount == data.countWithPrintYear)
        #expect(data.countWithPrintYear == 4)
    }

    // MARK: - Era + lag bucket boundaries

    @Test("CoverageEra boundaries")
    func eraBoundaries() {
        #expect(CoverageEra.bucket(year: 1899) == .pre1900)
        #expect(CoverageEra.bucket(year: 1900) == .earlyTwentieth)
        #expect(CoverageEra.bucket(year: 1944) == .earlyTwentieth)
        #expect(CoverageEra.bucket(year: 1945) == .coldWar)
        #expect(CoverageEra.bucket(year: 1990) == .coldWar)
        #expect(CoverageEra.bucket(year: 1991) == .contemporary)
        #expect(CoverageEra.bucket(year: 2025) == .contemporary)
        // Ordered + labelled.
        #expect(CoverageEra.ordered == [.pre1900, .earlyTwentieth, .coldWar, .contemporary])
        #expect(CoverageEra.ordered.allSatisfy { !$0.label.isEmpty })
    }

    @Test("LagBucket boundaries including negative lag")
    func lagBucketBoundaries() {
        #expect(LagBucket.bucket(lag: -4) == .under10)
        #expect(LagBucket.bucket(lag: 9) == .under10)
        #expect(LagBucket.bucket(lag: 10) == .tenToTwenty)
        #expect(LagBucket.bucket(lag: 19) == .tenToTwenty)
        #expect(LagBucket.bucket(lag: 20) == .twentyToThirty)
        #expect(LagBucket.bucket(lag: 29) == .twentyToThirty)
        #expect(LagBucket.bucket(lag: 30) == .thirtyPlus)
        #expect(LagBucket.bucket(lag: 95) == .thirtyPlus)
        #expect(LagBucket.ordered == [.under10, .tenToTwenty, .twentyToThirty, .thirtyPlus])
        #expect(LagBucket.ordered.allSatisfy { !$0.label.isEmpty })
    }

    // MARK: - Lag stats

    @Test("Lag min/max/median over an odd and an even count")
    func lagStats() {
        // Lags: 5, 10, 30 → median 10 (odd count).
        let odd = [
            entry(id: "a", earliest: "1900", latest: "1900", publicationDate: "1905"),  // 5
            entry(id: "b", earliest: "1900", latest: "1900", publicationDate: "1910"),  // 10
            entry(id: "c", earliest: "1900", latest: "1900", publicationDate: "1930"),  // 30
        ]
        let oddData = SeriesProductionData(entries: odd)
        #expect(oddData.lagMin == 5)
        #expect(oddData.lagMax == 30)
        #expect(oddData.lagMedian == 10)

        // Lags: 5, 10, 20, 30 → even → (10+20)/2 = 15.
        let even = odd + [entry(id: "d", earliest: "1900", latest: "1900", publicationDate: "1920")]
        let evenData = SeriesProductionData(entries: even)
        #expect(evenData.lagMedian == 15)
    }

    @Test("median helper of an empty array is nil")
    func medianEmptyIsNil() {
        #expect(SeriesProductionData.median(of: []) == nil)
        #expect(SeriesProductionData.median(of: [7]) == 7)
    }

    // MARK: - Empty-input safety

    @Test("Empty input yields empty collections and nil stats, no crash")
    func emptyInputSafe() {
        let data = SeriesProductionData(entries: [])
        #expect(data.total == 0)
        #expect(data.lagPoints.isEmpty)
        #expect(data.volumesPerPrintYear.isEmpty)
        #expect(data.volumesPerPrintYearByEra.isEmpty)
        #expect(data.coverageSpans.isEmpty)
        #expect(data.cumulativeByPrintYear.isEmpty)
        #expect(data.countWithPrintYear == 0)
        #expect(data.countWithCoverage == 0)
        #expect(data.countLagComputable == 0)
        #expect(data.lagMin == nil)
        #expect(data.lagMax == nil)
        #expect(data.lagMedian == nil)
    }

    @Test("All-unparseable input is safe")
    func unparseableInputSafe() {
        let entries = [
            entry(id: "junk", earliest: "n.d.", latest: "unknown", publicationDate: "forthcoming"),
        ]
        let data = SeriesProductionData(entries: entries)
        #expect(data.total == 1)
        #expect(data.lagPoints.isEmpty)
        #expect(data.coverageSpans.isEmpty)
        #expect(data.cumulativeByPrintYear.isEmpty)
        #expect(data.lagMedian == nil)
    }
}
