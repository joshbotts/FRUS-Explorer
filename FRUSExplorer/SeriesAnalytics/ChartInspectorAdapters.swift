// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ChartInspectorAdapters

/// Pure, testable adapters that map each Series-dashboard chart's plotted data
/// into a `ChartInspectorData` table.
///
/// Every adapter takes the *same* array its chart draws — for the range-filtered
/// time-series charts the caller passes the in-domain array, so the table tracks
/// the visible chart and the editable year range. Formatting is fixed here:
/// years/decades as plain integers without comma grouping, shares as one-decimal
/// percents, counts plain. Display-name resolution (eras, regions, provenance,
/// countries) is done by the caller and either baked into the point types or
/// passed as a closure, keeping these functions free of SwiftUI and the tag store.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
///   1.1 — Analytics SA-2b: adds the Administration Profiles overview tables
///          (documents per administration, volumes per administration-year)
enum ChartInspectorAdapters {

    // MARK: Formatting

    /// A plain integer with no grouping separators (years/decades: `1950`).
    private static let plainInt = IntegerFormatStyle<Int>.number.grouping(.never)

    /// Formats an integer year/decade/count without comma grouping.
    ///
    /// - Parameter value: The integer to format.
    /// - Returns: The grouping-free string (e.g. `"1950"`).
    static func plain(_ value: Int) -> String {
        value.formatted(plainInt)
    }

    /// Formats a `0.0...1.0` share as a one-decimal percent (e.g. `0.423` →
    /// `"42.3%"`).
    ///
    /// - Parameter share: The fractional share.
    /// - Returns: The localised percent string.
    static func percent(_ share: Double) -> String {
        share.formatted(
            FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(1))
        )
    }

    // MARK: - SA-1: Production & Timeliness

    /// The lag scatter's table: one row per in-range volume.
    ///
    /// - Parameter points: The range-filtered lag points (`data.lagPoints(in:)`).
    /// - Returns: A `[Volume, Publication year, Latest document year, Lag (years),
    ///   Era]` table.
    static func lagTable(_ points: [SeriesProductionData.LagPoint]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa1.lag",
            title: String(localized: "series.chart.lag.title", defaultValue: "Publication lag over time"),
            columns: [
                String(localized: "series.inspector.col.volume", defaultValue: "Volume"),
                String(localized: "series.chart.lag.x", defaultValue: "Publication year"),
                String(localized: "series.inspector.col.latestDocYear", defaultValue: "Latest document year"),
                String(localized: "series.inspector.col.lagYears", defaultValue: "Lag (years)"),
                String(localized: "series.chart.era.legend", defaultValue: "Era"),
            ],
            rowCells: points.map { point in
                [
                    point.volumeId,
                    plain(point.printYear),
                    plain(point.coverageEndYear),
                    plain(point.lagYears),
                    point.coverageEra.label,
                ]
            }
        )
    }

    /// The volumes-per-print-year bars' table: one row per (year, era) bucket.
    ///
    /// - Parameter buckets: The range-filtered buckets
    ///   (`data.volumesPerPrintYearByEra(in:)`).
    /// - Returns: A `[Print year, Era, Volumes]` table.
    static func perYearTable(_ buckets: [SeriesProductionData.PrintYearCount]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa1.perYear",
            title: String(localized: "series.chart.peryear.title", defaultValue: "Volumes published per year"),
            columns: [
                String(localized: "series.chart.peryear.x", defaultValue: "Print year"),
                String(localized: "series.chart.era.legend", defaultValue: "Era"),
                String(localized: "series.chart.peryear.y", defaultValue: "Volumes"),
            ],
            rowCells: buckets.map { bucket in
                [plain(bucket.printYear), bucket.pubEra.label, plain(bucket.count)]
            }
        )
    }

    /// The cumulative-growth curve's table: one row per in-range print year.
    ///
    /// - Parameter points: The range-filtered cumulative points
    ///   (`data.cumulativeByPrintYear(in:)`).
    /// - Returns: A `[Print year, Cumulative volumes]` table.
    static func cumulativeTable(_ points: [SeriesProductionData.CumulativePoint]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa1.cumulative",
            title: String(localized: "series.chart.cumulative.title", defaultValue: "Cumulative volumes published"),
            columns: [
                String(localized: "series.chart.cumulative.x", defaultValue: "Print year"),
                String(localized: "series.inspector.col.cumulativeVolumes", defaultValue: "Cumulative volumes"),
            ],
            rowCells: points.map { point in
                [plain(point.printYear), plain(point.cumulativeCount)]
            }
        )
    }

    // MARK: - SA-2: Geographic Emphasis

    /// The regional-emphasis trend's table: one row per in-range (decade, region)
    /// share.
    ///
    /// - Parameter shares: The range-filtered shares (`data.regionShareByDecade(in:)`).
    /// - Returns: A `[Decade, Region, Share]` table.
    static func regionTrendTable(_ shares: [SeriesGeographyData.RegionDecadeShare]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa2.regionTrend",
            title: String(localized: "series.geography.trend.title", defaultValue: "Regional emphasis over time"),
            columns: [
                String(localized: "series.geography.trend.x", defaultValue: "Coverage decade"),
                String(localized: "series.geography.region.legend", defaultValue: "Region"),
                String(localized: "series.geography.trend.y", defaultValue: "Share"),
            ],
            rowCells: shares.map { share in
                [plain(share.decade), share.region.displayName, percent(share.share)]
            }
        )
    }

    /// The overall region-totals bars' table (categorical, unfiltered): one row
    /// per region.
    ///
    /// - Parameter totals: The region overlap totals (`data.regionTotals`).
    /// - Returns: A `[Region, Volumes]` table.
    static func regionTotalsTable(_ totals: [SeriesGeographyData.RegionTotal]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa2.regionTotals",
            title: String(localized: "series.geography.totals.title", defaultValue: "Overall regional emphasis"),
            columns: [
                String(localized: "series.geography.totals.x", defaultValue: "Region"),
                String(localized: "series.geography.totals.y", defaultValue: "Volumes"),
            ],
            rowCells: totals.map { total in
                [total.region.displayName, plain(total.volumeCount)]
            }
        )
    }

    /// The most-covered-countries bars' table (categorical): one row per place
    /// tag, resolved to a display name by the caller's `displayName` closure.
    ///
    /// - Parameters:
    ///   - countries: The top country counts (`data.topCountries`).
    ///   - displayName: Resolves a place-tag slug to its display name.
    /// - Returns: A `[Country, Volumes]` table.
    static func topCountriesTable(
        _ countries: [SeriesGeographyData.CountryCount],
        displayName: (String) -> String
    ) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa2.topCountries",
            title: String(localized: "series.geography.countries.title", defaultValue: "Most-covered countries"),
            columns: [
                String(localized: "series.geography.countries.y", defaultValue: "Country"),
                String(localized: "series.geography.countries.x", defaultValue: "Volumes"),
            ],
            rowCells: countries.map { country in
                [displayName(country.slug), plain(country.volumeCount)]
            }
        )
    }

    /// A `0.0...` proportion formatted as a whole-number percent (e.g. `1.234` →
    /// `"123%"`) — the per-volume administration proportion, which can exceed
    /// 100% across administrations under any-overlap.
    ///
    /// - Parameter proportion: The fractional proportion.
    /// - Returns: The localised percent string.
    static func wholePercent(_ proportion: Double) -> String {
        proportion.formatted(
            FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0))
        )
    }

    /// A one-decimal plain number (e.g. `2.35` → `"2.3"`) for volumes-per-year.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: The localised one-decimal string.
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(1)))
    }

    // MARK: - SA-2b: Administration Profiles

    /// The documents-per-administration bars' table: one row per populated
    /// administration.
    ///
    /// - Parameter profiles: The derived profiles (`data.profiles`).
    /// - Returns: A `[President, Party, Documents]` table.
    static func administrationDocumentsTable(_ profiles: [AdministrationProfilesData.Profile]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa2b.adminDocuments",
            title: String(localized: "series.admin.docs.title", defaultValue: "Documents per administration"),
            columns: [
                String(localized: "series.admin.col.president", defaultValue: "President"),
                String(localized: "series.admin.col.party", defaultValue: "Party"),
                String(localized: "series.admin.docs.y", defaultValue: "Documents"),
            ],
            rowCells: profiles.map { profile in
                [profile.president, profile.party.displayName, plain(profile.documentCount)]
            }
        )
    }

    /// The volumes-per-administration-year bars' table: one row per populated
    /// administration.
    ///
    /// - Parameter profiles: The derived profiles (`data.profiles`).
    /// - Returns: A `[President, Party, Volumes/term-year]` table.
    static func administrationVolumesPerYearTable(_ profiles: [AdministrationProfilesData.Profile]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa2b.adminVolumesPerYear",
            title: String(localized: "series.admin.perYear.title", defaultValue: "Volumes per administration-year"),
            columns: [
                String(localized: "series.admin.col.president", defaultValue: "President"),
                String(localized: "series.admin.col.party", defaultValue: "Party"),
                String(localized: "series.admin.perYear.y", defaultValue: "Volumes per year"),
            ],
            rowCells: profiles.map { profile in
                [profile.president, profile.party.displayName, oneDecimal(profile.volumesPerAdministrationYear)]
            }
        )
    }

    // MARK: - SA-3: Archival Sourcing

    /// The provenance-mix trend's table: one row per in-range (decade, category)
    /// share.
    ///
    /// - Parameter shares: The range-filtered shares (`data.shareByDecade(in:)`).
    /// - Returns: A `[Decade, Provenance, Share]` table.
    static func provenanceMixTable(_ shares: [SourceProvenanceData.CategoryDecadeShare]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa3.provenanceMix",
            title: String(localized: "series.provenance.trend.title", defaultValue: "Archival provenance over time"),
            columns: [
                String(localized: "series.provenance.trend.x", defaultValue: "Coverage decade"),
                String(localized: "series.provenance.category.legend", defaultValue: "Provenance"),
                String(localized: "series.provenance.trend.y", defaultValue: "Share"),
            ],
            rowCells: shares.map { share in
                [plain(share.decade), share.category.displayName, percent(share.share)]
            }
        )
    }

    /// The overall-composition bars' table (categorical): one row per provenance
    /// category with its note count and share.
    ///
    /// - Parameter composition: The overall composition (`data.overallComposition`).
    /// - Returns: A `[Provenance, Notes, Share]` table.
    static func compositionTable(_ composition: [SourceProvenanceData.CategoryComposition]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa3.composition",
            title: String(localized: "series.provenance.composition.title", defaultValue: "Overall provenance composition"),
            columns: [
                String(localized: "series.provenance.composition.x", defaultValue: "Provenance"),
                String(localized: "series.provenance.composition.y", defaultValue: "Source notes"),
                String(localized: "series.provenance.trend.y", defaultValue: "Share"),
            ],
            rowCells: composition.map { item in
                [item.category.displayName, plain(item.noteCount), percent(item.share)]
            }
        )
    }

    /// The documentary-density bars' table: one row per in-range decade.
    ///
    /// - Parameter density: The range-filtered density points (`data.notesByDecade(in:)`).
    /// - Returns: A `[Decade, Source notes, Volumes]` table.
    static func densityTable(_ density: [SourceProvenanceData.DecadeDensity]) -> ChartInspectorData {
        ChartInspectorData(
            id: "sa3.density",
            title: String(localized: "series.provenance.density.title", defaultValue: "The documentary base by decade"),
            columns: [
                String(localized: "series.provenance.density.x", defaultValue: "Coverage decade"),
                String(localized: "series.provenance.density.y", defaultValue: "Source notes"),
                String(localized: "series.geography.totals.y", defaultValue: "Volumes"),
            ],
            rowCells: density.map { item in
                [plain(item.decade), plain(item.totalNotes), plain(item.volumeCount)]
            }
        )
    }
}
