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

// MARK: - SeriesGeographyDataTests

/// Pure derivation tests for `SeriesGeographyData` (Analytics SA-2): the
/// subcategory → region mapping, per-decade fractional attribution (a k-region
/// volume contributes 1/k to each; shares sum to ~1.0 per decade), region
/// overlap totals, top-country ranking with tie handling, zero-region exclusion,
/// and empty-input safety. No SwiftUI is instantiated.
///
/// Version history:
///   1.0 — Analytics SA-2: initial implementation
struct SeriesGeographyDataTests {

    // MARK: - Fixtures

    /// Builds a manifest entry with just the fields `SeriesGeographyData`
    /// reads (tags + date range); all others are neutral.
    private func entry(
        id: String,
        earliest: String?,
        latest: String?,
        tags: [String]
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id,
            filename: "\(id).xml",
            subseries: "1969-76",
            title: "Title \(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: nil,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: tags
        )
    }

    /// A place-region map covering the fixtures' slugs.
    private let regions: [String: GeographicRegion] = [
        "france": .europe,
        "germany": .europe,
        "japan": .eastAsiaPacific,
        "china": .eastAsiaPacific,
        "iran": .nearEast,
        "brazil": .westernHemisphere,
        "kenya": .subSaharanAfrica,
        "india": .southCentralAsia,
        "greenland": .other,
    ]

    // MARK: - Region mapping

    @Test("GeographicRegion.from maps the six bureau slugs plus the .other fallback")
    func regionMapping() {
        #expect(GeographicRegion.from(subcategory: "europe") == .europe)
        #expect(GeographicRegion.from(subcategory: "near-east") == .nearEast)
        #expect(GeographicRegion.from(subcategory: "south-and-central-asia") == .southCentralAsia)
        #expect(GeographicRegion.from(subcategory: "east-asia-and-pacific") == .eastAsiaPacific)
        #expect(GeographicRegion.from(subcategory: "sub-saharan-africa") == .subSaharanAfrica)
        #expect(GeographicRegion.from(subcategory: "western-hemisphere") == .westernHemisphere)
        // Unknown / dependency / "other" all fall back.
        #expect(GeographicRegion.from(subcategory: "other") == .other)
        #expect(GeographicRegion.from(subcategory: "bermuda") == .other)
        #expect(GeographicRegion.from(subcategory: "") == .other)
        // Ordered + labelled.
        #expect(GeographicRegion.ordered == [
            .europe, .nearEast, .southCentralAsia, .eastAsiaPacific,
            .subSaharanAfrica, .westernHemisphere, .other,
        ])
        #expect(GeographicRegion.ordered.allSatisfy { !$0.displayName.isEmpty })
    }

    // MARK: - Coverage decade bucketing

    @Test("coverageDecade floors the coverage midpoint to a decade")
    func decadeBucketing() {
        // 1946–1952 → midpoint 1949 → 1940s.
        #expect(SeriesGeographyData.coverageDecade(
            for: entry(id: "x", earliest: "1946", latest: "1952", tags: [])) == 1940)
        // 1950–1959 → midpoint 1954 → 1950s.
        #expect(SeriesGeographyData.coverageDecade(
            for: entry(id: "y", earliest: "1950", latest: "1959", tags: [])) == 1950)
        // Only one endpoint parses → stands in for both.
        #expect(SeriesGeographyData.coverageDecade(
            for: entry(id: "z", earliest: nil, latest: "1963", tags: [])) == 1960)
        // Neither parses → nil.
        #expect(SeriesGeographyData.coverageDecade(
            for: entry(id: "w", earliest: "n.d.", latest: "unknown", tags: [])) == nil)
    }

    // MARK: - Fractional attribution

    @Test("A two-region volume contributes 0.5 to each region")
    func twoRegionVolumeSplitsEvenly() {
        // One volume, 1946–1952 (1940s), touching Europe + East Asia.
        let data = SeriesGeographyData(
            entries: [entry(id: "a", earliest: "1946", latest: "1952", tags: ["france", "japan"])],
            placeRegions: regions
        )
        let byRegion = Dictionary(
            uniqueKeysWithValues: data.regionShareByDecade
                .filter { $0.decade == 1940 }
                .map { ($0.region, $0.share) }
        )
        #expect(byRegion[.europe] == 0.5)
        #expect(byRegion[.eastAsiaPacific] == 0.5)
        // Shares within the decade sum to ~1.0.
        let sum = data.regionShareByDecade.filter { $0.decade == 1940 }.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 1e-9)
    }

    @Test("A single-region decade yields that region a 1.0 share")
    func singleRegionDecade() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1950", latest: "1955", tags: ["france"]),
                entry(id: "b", earliest: "1951", latest: "1956", tags: ["germany"]),
            ],
            placeRegions: regions
        )
        // Both volumes are Europe-only, in the 1950s → Europe share == 1.0.
        let europe = data.regionShareByDecade.first { $0.decade == 1950 && $0.region == .europe }
        #expect(europe?.share == 1.0)
        // No other region appears in that decade.
        #expect(data.regionShareByDecade.filter { $0.decade == 1950 }.count == 1)
    }

    @Test("Per-decade shares sum to ~1.0 across a mixed corpus")
    func perDecadeSharesSumToOne() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1946", latest: "1952", tags: ["france", "japan"]),   // 1940s
                entry(id: "b", earliest: "1947", latest: "1951", tags: ["iran"]),               // 1940s
                entry(id: "c", earliest: "1948", latest: "1950", tags: ["brazil", "kenya", "india"]), // 1940s, 3 regions
            ],
            placeRegions: regions
        )
        let sum = data.regionShareByDecade.filter { $0.decade == 1940 }.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 1e-9)
        // The 3-region volume contributes 1/3 each; combined with the divisor of 3.
        let byRegion = Dictionary(
            uniqueKeysWithValues: data.regionShareByDecade
                .filter { $0.decade == 1940 }
                .map { ($0.region, $0.share) }
        )
        // Europe: (0.5) / 3.
        #expect(abs((byRegion[.europe] ?? 0) - (0.5 / 3.0)) < 1e-9)
        // Near East: (1.0) / 3.
        #expect(abs((byRegion[.nearEast] ?? 0) - (1.0 / 3.0)) < 1e-9)
        // Western Hemisphere: (1/3) / 3.
        #expect(abs((byRegion[.westernHemisphere] ?? 0) - ((1.0 / 3.0) / 3.0)) < 1e-9)
    }

    // MARK: - Region overlap totals

    @Test("regionTotals count a multi-region volume in each region it touches")
    func regionTotalsOverlap() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1950", latest: "1955", tags: ["france", "japan"]), // Europe + East Asia
                entry(id: "b", earliest: "1951", latest: "1956", tags: ["germany"]),          // Europe
            ],
            placeRegions: regions
        )
        let byRegion = Dictionary(uniqueKeysWithValues: data.regionTotals.map { ($0.region, $0.volumeCount) })
        #expect(byRegion[.europe] == 2)          // both volumes
        #expect(byRegion[.eastAsiaPacific] == 1) // volume a only
        // Regions with zero volumes are absent.
        #expect(byRegion[.nearEast] == nil)
        // In stable region order.
        #expect(data.regionTotals.map(\.region) == [.europe, .eastAsiaPacific])
    }

    // MARK: - Top countries

    @Test("topCountries ranks by volume count, ties broken by slug")
    func topCountriesRankingAndTies() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1950", latest: "1951", tags: ["france", "japan"]),
                entry(id: "b", earliest: "1952", latest: "1953", tags: ["france", "china"]),
                entry(id: "c", earliest: "1954", latest: "1955", tags: ["france"]),
                // china and japan each appear once; germany once.
                entry(id: "d", earliest: "1956", latest: "1957", tags: ["germany"]),
            ],
            placeRegions: regions
        )
        // france: 3, then a four-way tie at 1 → broken alphabetically by slug.
        #expect(data.topCountries.first?.slug == "france")
        #expect(data.topCountries.first?.volumeCount == 3)
        let tail = data.topCountries.dropFirst().map(\.slug)
        #expect(tail == ["china", "germany", "japan"])
    }

    @Test("topCountries is capped at the limit")
    func topCountriesCapped() {
        // 20 distinct slugs, each mapped to Europe, one volume each.
        var map: [String: GeographicRegion] = [:]
        var entries: [VolumeManifestEntry] = []
        for i in 0..<20 {
            let slug = String(format: "c%02d", i)
            map[slug] = .europe
            entries.append(entry(id: "v\(i)", earliest: "1950", latest: "1950", tags: [slug]))
        }
        let data = SeriesGeographyData(entries: entries, placeRegions: map)
        #expect(data.topCountries.count == SeriesGeographyData.topCountryLimit)
    }

    // MARK: - Zero-region exclusion

    @Test("A zero-region volume is excluded from shares but counted in volumesWithoutRegion")
    func zeroRegionVolumeExcluded() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1950", latest: "1955", tags: ["france"]),   // Europe
                entry(id: "none", earliest: "1950", latest: "1955", tags: []),        // no tags
                entry(id: "unmapped", earliest: "1950", latest: "1955", tags: ["atlantis"]), // slug absent from map
            ],
            placeRegions: regions
        )
        #expect(data.totalVolumes == 3)
        #expect(data.volumesWithAnyRegion == 1)
        #expect(data.volumesWithoutRegion == 2)
        // The 1950s decade divisor is 1 (only the Europe volume) → Europe 1.0.
        let europe = data.regionShareByDecade.first { $0.decade == 1950 && $0.region == .europe }
        #expect(europe?.share == 1.0)
        #expect(data.regionShareByDecade.filter { $0.decade == 1950 }.count == 1)
    }

    @Test("An .other-mapped volume is region-bearing and shares as Other")
    func otherRegionIsBearing() {
        let data = SeriesGeographyData(
            entries: [entry(id: "g", earliest: "1950", latest: "1955", tags: ["greenland"])],
            placeRegions: regions
        )
        #expect(data.volumesWithAnyRegion == 1)
        #expect(data.volumesWithoutRegion == 0)
        let other = data.regionShareByDecade.first { $0.region == .other }
        #expect(other?.share == 1.0)
    }

    // MARK: - Decade bounds

    @Test("earliestDecade and latestDecade bracket the region-bearing decades")
    func decadeBounds() {
        let data = SeriesGeographyData(
            entries: [
                entry(id: "a", earliest: "1861", latest: "1865", tags: ["france"]), // 1860s
                entry(id: "b", earliest: "1990", latest: "1992", tags: ["japan"]),  // 1990s
            ],
            placeRegions: regions
        )
        #expect(data.earliestDecade == 1860)
        #expect(data.latestDecade == 1990)
    }

    // MARK: - Empty-input safety

    @Test("Empty input yields empty collections and nil bounds, no crash")
    func emptyInputSafe() {
        let data = SeriesGeographyData(entries: [], placeRegions: [:])
        #expect(data.totalVolumes == 0)
        #expect(data.regionShareByDecade.isEmpty)
        #expect(data.regionTotals.isEmpty)
        #expect(data.topCountries.isEmpty)
        #expect(data.volumesWithAnyRegion == 0)
        #expect(data.volumesWithoutRegion == 0)
        #expect(data.earliestDecade == nil)
        #expect(data.latestDecade == nil)
    }

    @Test("Entries with an empty place-region map contribute no regions")
    func emptyMapSafe() {
        let data = SeriesGeographyData(
            entries: [entry(id: "a", earliest: "1950", latest: "1955", tags: ["france"])],
            placeRegions: [:]
        )
        #expect(data.totalVolumes == 1)
        #expect(data.volumesWithAnyRegion == 0)
        #expect(data.volumesWithoutRegion == 1)
        #expect(data.regionShareByDecade.isEmpty)
        #expect(data.regionTotals.isEmpty)
        #expect(data.topCountries.isEmpty)
    }
}
