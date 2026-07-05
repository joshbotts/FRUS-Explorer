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

// MARK: - SeriesAxisRangeTests

/// Tests for the Series-dashboard x-axis bounds fix (Analytics SA, x-axis
/// bounds): the shared `SeriesChartKind` default domains and `effectiveDomain`
/// coverage-clamp rule, plus the per-model year-range data filters on
/// `SeriesProductionData`, `SeriesGeographyData`, and `SourceProvenanceData`.
///
/// These assert pure values only — no SwiftUI view is instantiated.
///
/// Version history:
///   1.0 — Analytics SA (x-axis bounds): initial implementation
struct SeriesAxisRangeTests {

    // MARK: - Default domains

    @Test("Coverage default domain is 1861…1993; production is 1861…2026")
    func defaultDomains() {
        #expect(SeriesChartKind.coverage.defaultDomain == 1861...1993)
        #expect(SeriesChartKind.production.defaultDomain == 1861...2026)
        #expect(SeriesChartKind.floorYear == 1861)
        #expect(SeriesChartKind.coverageCeilingYear == 1993)
        #expect(SeriesChartKind.productionCeilingYear == 2026)
    }

    // MARK: - effectiveDomain

    @Test("effectiveDomain: production passes the user range through unchanged")
    func productionPassThrough() {
        #expect(effectiveDomain(userStart: 1861, userEnd: 2026, kind: .production) == 1861...2026)
        #expect(effectiveDomain(userStart: 1900, userEnd: 1980, kind: .production) == 1900...1980)
    }

    @Test("effectiveDomain: coverage clamps the end to 1993 even when the user range runs to 2026")
    func coverageClampsEnd() {
        // The core rule: a coverage chart never extends past 1993, so SA-1's
        // 1861…2026 default collapses to 1861…1993 for its coverage charts.
        #expect(effectiveDomain(userStart: 1861, userEnd: 2026, kind: .coverage) == 1861...1993)
        // A user end already below the ceiling is untouched.
        #expect(effectiveDomain(userStart: 1900, userEnd: 1950, kind: .coverage) == 1900...1950)
        // A user end exactly at the ceiling is untouched.
        #expect(effectiveDomain(userStart: 1861, userEnd: 1993, kind: .coverage) == 1861...1993)
    }

    @Test("effectiveDomain: coverage start above the ceiling still yields a valid non-empty range")
    func coverageStartAboveCeiling() {
        // userStart 2000, coverage → the end clamps to 1993 below the start; the
        // guard must reorder into a valid non-empty range rather than crash.
        let domain = effectiveDomain(userStart: 2000, userEnd: 2026, kind: .coverage)
        #expect(domain.lowerBound <= domain.upperBound)
        #expect(domain == 1993...2000)
    }

    @Test("effectiveDomain: an inverted user range is guarded into a valid range")
    func invertedRangeGuarded() {
        let domain = effectiveDomain(userStart: 1990, userEnd: 1900, kind: .production)
        #expect(domain == 1900...1990)
    }

    // MARK: - SeriesProductionData filters

    /// A production-data fixture spanning coverage 1850…1980 and print 1900…2020.
    private func productionData() -> SeriesProductionData {
        SeriesProductionData(entries: [
            // Coverage-end 1850 (below 1861 floor), print 1900.
            prodEntry(id: "a", earliest: "1840", latest: "1850", pub: "1900"),
            // Coverage-end 1900, print 1930.
            prodEntry(id: "b", earliest: "1890", latest: "1900", pub: "1930"),
            // Coverage-end 1970, print 1995.
            prodEntry(id: "c", earliest: "1960", latest: "1970", pub: "1995"),
            // Coverage-end 1980, print 2020 (past coverage ceiling on print).
            prodEntry(id: "d", earliest: "1975", latest: "1980", pub: "2020"),
        ])
    }

    private func prodEntry(id: String, earliest: String?, latest: String?, pub: String?) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: "s", title: "T\(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: pub, status: .published, editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: []
        )
    }

    @Test("SeriesProductionData.lagPoints(in:) keeps only publication (print) years in range")
    func lagPointsFilter() {
        let data = productionData()
        // The lag chart now uses the production domain and filters by print year.
        // Print years are a→1900, b→1930, c→1995, d→2020.
        // 1861…1993 keeps only the volumes printed in-range (a, b); c (1995) and
        // d (2020) print past the ceiling.
        let clipped = data.lagPoints(in: 1861...1993)
        #expect(Set(clipped.map(\.volumeId)) == ["a", "b"])
        // The full production default keeps every print year (1900…2020).
        let full = data.lagPoints(in: 1861...2026)
        #expect(Set(full.map(\.volumeId)) == ["a", "b", "c", "d"])
        // Narrowed to 1861…1920: only the 1900 print-year point (a).
        let narrow = data.lagPoints(in: 1861...1920)
        #expect(narrow.map(\.volumeId) == ["a"])
    }

    @Test("SeriesProductionData print-year filters key off the print year, not coverage")
    func printYearFilters() {
        let data = productionData()
        // Production default 1861…2026 keeps every print year (1900..2020).
        let byEra = data.volumesPerPrintYearByEra(in: 1861...2026)
        #expect(byEra.map(\.printYear).sorted() == [1900, 1930, 1995, 2020])
        // Narrowed to 1861…1993 drops the 1995 and 2020 print years.
        let narrow = data.volumesPerPrintYearByEra(in: 1861...1993)
        #expect(narrow.map(\.printYear).sorted() == [1900, 1930])
        // Cumulative filter behaves the same on print year.
        let cumNarrow = data.cumulativeByPrintYear(in: 1861...1993)
        #expect(cumNarrow.map(\.printYear).sorted() == [1900, 1930])
    }

    // MARK: - SeriesGeographyData decade filter

    @Test("SeriesGeographyData.regionShareByDecade(in:) drops out-of-range decades (incl. pre-1861 outlier)")
    func geographyDecadeFilter() {
        // Two volumes: one covering the 1740s (a retrospective outlier), one the
        // 1940s. Both carry a single europe place tag.
        let regions = ["fr": GeographicRegion.europe]
        let entries = [
            geoEntry(id: "old", earliest: "1740", latest: "1749", tags: ["fr"]),
            geoEntry(id: "mid", earliest: "1940", latest: "1949", tags: ["fr"]),
        ]
        let data = SeriesGeographyData(entries: entries, placeRegions: regions)
        // Unfiltered, the raw derivation includes the stray 1740 decade.
        #expect(Set(data.regionShareByDecade.map(\.decade)).contains(1740))
        // Filtered to the coverage default, the 1740 outlier is gone.
        let filtered = data.regionShareByDecade(in: 1861...1993)
        #expect(!filtered.map(\.decade).contains(1740))
        #expect(filtered.map(\.decade).contains(1940))
    }

    private func geoEntry(id: String, earliest: String?, latest: String?, tags: [String]) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: "s", title: "T\(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: "2000", status: .published, editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: tags
        )
    }

    // MARK: - SourceProvenanceData decade filters

    @Test("SourceProvenanceData decade filters keep only decades within the range")
    func provenanceDecadeFilters() {
        let index = SourceProvenanceIndex(
            schemaVersion: 1, generated: "2026-07-04",
            totalSourceNotes: 320, volumesCovered: 9,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [
                DecadeProvenance(decade: 1910, totalNotes: 200, volumeCount: 4,
                                 counts: ["centralDecimalFile": 200]),
                DecadeProvenance(decade: 1950, totalNotes: 80, volumeCount: 3,
                                 counts: ["lotFile": 80]),
                DecadeProvenance(decade: 1970, totalNotes: 40, volumeCount: 2,
                                 counts: ["presidentialLibrary": 40]),
            ]
        )
        let data = SourceProvenanceData(index: index)
        // Full coverage default keeps all three decades.
        #expect(Set(data.notesByDecade(in: 1861...1993).map(\.decade)) == [1910, 1950, 1970])
        #expect(Set(data.shareByDecade(in: 1861...1993).map(\.decade)) == [1910, 1950, 1970])
        // Narrowed to 1900…1955 keeps only 1910 and 1950.
        #expect(Set(data.notesByDecade(in: 1900...1955).map(\.decade)) == [1910, 1950])
        #expect(Set(data.shareByDecade(in: 1900...1955).map(\.decade)) == [1910, 1950])
    }
}
