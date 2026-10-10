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
/// the visible chart and the editable year range. (The provenance-mix table leaves out
/// the zero rows its chart draws only to close its bands.) Formatting is fixed here:
/// years/decades as plain integers without comma grouping, shares as one-decimal
/// percents, counts plain. Display-name resolution (eras, regions, provenance,
/// countries) is done by the caller and either baked into the point types or
/// passed as a closure, keeping these functions free of SwiftUI and the tag store.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
///   1.1 — Analytics SA-2b: adds the Administration Profiles overview tables
///          (documents per administration, volumes per administration-year)
///   1.2 — 2026-09-30: #1483 — the region-trend table's share column reads "Share of volumes",
///          and the provenance-mix and composition tables' "Share of source notes", each its
///          chart's axis text under the same key
///   1.3 — 2026-10-02 (#1543, landing round 3): the provenance-mix table lists
///          `SourceProvenanceData.listed(_:)` of its chart's rows, which now hold a zero row
///          for every category with no notes in a decade
///   1.4 — 2026-10-09: #1587 — every table states the numbers its chart plots
///          (`ChartInspectorData.audioGraph`), which VoiceOver's Audio Graph plays. The card
///          read columns 0 and 1 of each table: right for five, the publication years for the
///          lag chart, and nothing at all for the five whose column 1 is a name
enum ChartInspectorAdapters {

    // MARK: Audio Graph

    /// A share as the tables print it, one decimal of a percent, as a number: `0.423` is `42.3`.
    /// What the Audio Graph speaks for a share, under an axis titled "Share of …".
    ///
    /// - Parameter share: The fractional share.
    /// - Returns: The share in percent, rounded to one decimal.
    static func percentValue(_ share: Double) -> Double {
        (share * 1000).rounded() / 10
    }

    /// A single-series graph over a numeric x (a year or a decade).
    private static func numericGraph(
        title: String, xLabel: String, yLabel: String, points: [(x: Int, y: Double)]
    ) -> ChartAudioGraph {
        ChartAudioGraph(xLabel: xLabel, yLabel: yLabel, series: [
            .init(name: title, points: points.map {
                AXChartPoint(label: plain($0.x), x: Double($0.x), y: $0.y)
            }),
        ])
    }

    /// A single-series graph over named categories.
    private static func categoricalGraph(
        title: String, xLabel: String, yLabel: String, points: [(label: String, y: Double)]
    ) -> ChartAudioGraph {
        ChartAudioGraph(xLabel: xLabel, yLabel: yLabel, series: [
            .init(name: title, points: points.map { AXChartPoint(label: $0.label, x: nil, y: $0.y) }),
        ])
    }

    /// One series per band of a stacked area over decades, in first-appearance order, each
    /// band's share in percent.
    private static func bandedGraph(
        xLabel: String, yLabel: String, rows: [(band: String, decade: Int, share: Double)]
    ) -> ChartAudioGraph {
        var order: [String] = []
        var byBand: [String: [AXChartPoint]] = [:]
        for row in rows {
            if byBand[row.band] == nil { order.append(row.band) }
            byBand[row.band, default: []].append(
                AXChartPoint(label: plain(row.decade), x: Double(row.decade), y: percentValue(row.share)))
        }
        return ChartAudioGraph(xLabel: xLabel, yLabel: yLabel,
                               series: order.map { .init(name: $0, points: byBand[$0] ?? []) })
    }

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
        let title = String(localized: "series.chart.lag.title", defaultValue: "Publication lag over time")
        let columns = [
            String(localized: "series.inspector.col.volume", defaultValue: "Volume"),
            String(localized: "series.chart.lag.x", defaultValue: "Publication year"),
            String(localized: "series.inspector.col.latestDocYear", defaultValue: "Latest document year"),
            String(localized: "series.inspector.col.lagYears", defaultValue: "Lag (years)"),
            String(localized: "series.chart.era.legend", defaultValue: "Era"),
        ]
        // The chart: each volume's lag (column 3) against its publication year (column 1), a
        // scatter. In publication order, so the graph is walked along its x axis; the table
        // keeps the manifest's order.
        let plotted = points.sorted { ($0.printYear, $0.volumeId) < ($1.printYear, $1.volumeId) }
        let graph = ChartAudioGraph(
            xLabel: columns[1], yLabel: columns[3],
            series: [.init(name: title, points: plotted.map {
                AXChartPoint(label: $0.volumeId, x: Double($0.printYear), y: Double($0.lagYears))
            })],
            isContinuous: false)
        return ChartInspectorData(
            id: "sa1.lag",
            title: title,
            columns: columns,
            rowCells: points.map { point in
                [
                    point.volumeId,
                    plain(point.printYear),
                    plain(point.coverageEndYear),
                    plain(point.lagYears),
                    point.coverageEra.label,
                ]
            },
            audioGraph: graph
        )
    }

    /// The volumes-per-print-year bars' table: one row per (year, era) bucket.
    ///
    /// - Parameter buckets: The range-filtered buckets
    ///   (`data.volumesPerPrintYearByEra(in:)`).
    /// - Returns: A `[Print year, Era, Volumes]` table.
    static func perYearTable(_ buckets: [SeriesProductionData.PrintYearCount]) -> ChartInspectorData {
        let title = String(localized: "series.chart.peryear.title", defaultValue: "Volumes published per year")
        let columns = [
            String(localized: "series.chart.peryear.x", defaultValue: "Print year"),
            String(localized: "series.chart.era.legend", defaultValue: "Era"),
            String(localized: "series.chart.peryear.y", defaultValue: "Volumes"),
        ]
        return ChartInspectorData(
            id: "sa1.perYear",
            title: title,
            columns: columns,
            rowCells: buckets.map { bucket in
                [plain(bucket.printYear), bucket.pubEra.label, plain(bucket.count)]
            },
            // One series: a print year is in exactly one era, so each year has one bar.
            audioGraph: numericGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[2],
                points: buckets.map { (x: $0.printYear, y: Double($0.count)) })
        )
    }

    /// The cumulative-growth curve's table: one row per in-range print year.
    ///
    /// - Parameter points: The range-filtered cumulative points
    ///   (`data.cumulativeByPrintYear(in:)`).
    /// - Returns: A `[Print year, Cumulative volumes]` table.
    static func cumulativeTable(_ points: [SeriesProductionData.CumulativePoint]) -> ChartInspectorData {
        let title = String(localized: "series.chart.cumulative.title", defaultValue: "Cumulative volumes published")
        let columns = [
            String(localized: "series.chart.cumulative.x", defaultValue: "Print year"),
            String(localized: "series.inspector.col.cumulativeVolumes", defaultValue: "Cumulative volumes"),
        ]
        return ChartInspectorData(
            id: "sa1.cumulative",
            title: title,
            columns: columns,
            rowCells: points.map { point in
                [plain(point.printYear), plain(point.cumulativeCount)]
            },
            audioGraph: numericGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[1],
                points: points.map { (x: $0.printYear, y: Double($0.cumulativeCount)) })
        )
    }

    // MARK: - SA-2: Geographic Emphasis

    /// The regional-emphasis trend's table: one row per in-range (decade, region)
    /// share.
    ///
    /// - Parameter shares: The range-filtered shares (`data.regionShareByDecade(in:)`).
    /// - Returns: A `[Decade, Region, Share]` table.
    static func regionTrendTable(_ shares: [SeriesGeographyData.RegionDecadeShare]) -> ChartInspectorData {
        let columns = [
            String(localized: "series.geography.trend.x", defaultValue: "Coverage decade"),
            String(localized: "series.geography.region.legend", defaultValue: "Region"),
            String(localized: "series.geography.trend.y", defaultValue: "Share of volumes"),
        ]
        return ChartInspectorData(
            id: "sa2.regionTrend",
            title: String(localized: "series.geography.trend.title", defaultValue: "Regional emphasis over time"),
            columns: columns,
            rowCells: shares.map { share in
                [plain(share.decade), share.region.displayName, percent(share.share)]
            },
            // One series per region: the chart stacks a band for each.
            audioGraph: bandedGraph(
                xLabel: columns[0], yLabel: columns[2],
                rows: shares.map { (band: $0.region.displayName, decade: $0.decade, share: $0.share) })
        )
    }

    /// The overall region-totals bars' table (categorical, unfiltered): one row
    /// per region.
    ///
    /// - Parameter totals: The region overlap totals (`data.regionTotals`).
    /// - Returns: A `[Region, Volumes]` table.
    static func regionTotalsTable(_ totals: [SeriesGeographyData.RegionTotal]) -> ChartInspectorData {
        let title = String(localized: "series.geography.totals.title", defaultValue: "Overall regional emphasis")
        let columns = [
            String(localized: "series.geography.totals.x", defaultValue: "Region"),
            String(localized: "series.geography.totals.y", defaultValue: "Volumes"),
        ]
        return ChartInspectorData(
            id: "sa2.regionTotals",
            title: title,
            columns: columns,
            rowCells: totals.map { total in
                [total.region.displayName, plain(total.volumeCount)]
            },
            audioGraph: categoricalGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[1],
                points: totals.map { (label: $0.region.displayName, y: Double($0.volumeCount)) })
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
        let title = String(localized: "series.geography.countries.title", defaultValue: "Most-covered countries")
        let columns = [
            String(localized: "series.geography.countries.y", defaultValue: "Country"),
            String(localized: "series.geography.countries.x", defaultValue: "Volumes"),
        ]
        return ChartInspectorData(
            id: "sa2.topCountries",
            title: title,
            columns: columns,
            rowCells: countries.map { country in
                [displayName(country.slug), plain(country.volumeCount)]
            },
            audioGraph: categoricalGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[1],
                points: countries.map { (label: displayName($0.slug), y: Double($0.volumeCount)) })
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
        let title = String(localized: "series.admin.docs.title", defaultValue: "Documents per administration")
        let columns = [
            String(localized: "series.admin.col.president", defaultValue: "President"),
            String(localized: "series.admin.col.party", defaultValue: "Party"),
            String(localized: "series.admin.docs.y", defaultValue: "Documents"),
        ]
        return ChartInspectorData(
            id: "sa2b.adminDocuments",
            title: title,
            columns: columns,
            rowCells: profiles.map { profile in
                [profile.president, profile.party.displayName, plain(profile.documentCount)]
            },
            audioGraph: categoricalGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[2],
                points: profiles.map { (label: $0.president, y: Double($0.documentCount)) })
        )
    }

    /// The volumes-per-administration-year bars' table: one row per populated
    /// administration.
    ///
    /// - Parameter profiles: The derived profiles (`data.profiles`).
    /// - Returns: A `[President, Party, Volumes/term-year]` table.
    static func administrationVolumesPerYearTable(_ profiles: [AdministrationProfilesData.Profile]) -> ChartInspectorData {
        let title = String(localized: "series.admin.perYear.title", defaultValue: "Volumes per administration-year")
        let columns = [
            String(localized: "series.admin.col.president", defaultValue: "President"),
            String(localized: "series.admin.col.party", defaultValue: "Party"),
            String(localized: "series.admin.perYear.y", defaultValue: "Volumes per year"),
        ]
        return ChartInspectorData(
            id: "sa2b.adminVolumesPerYear",
            title: title,
            columns: columns,
            rowCells: profiles.map { profile in
                [profile.president, profile.party.displayName, oneDecimal(profile.volumesPerAdministrationYear)]
            },
            // To one decimal, as the table prints it and the bar's own VoiceOver value reads.
            audioGraph: categoricalGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[2],
                points: profiles.map {
                    (label: $0.president, y: ($0.volumesPerAdministrationYear * 10).rounded() / 10)
                })
        )
    }

    // MARK: - SA-3: Archival Sourcing

    /// The provenance-mix trend's table: one row per in-range (decade, category)
    /// share that a reader is told — `SourceProvenanceData.listed(_:)` of the chart's rows.
    ///
    /// The chart's rows give every category a point in every decade, zero where it has no notes,
    /// so that its bands close (#1543). The table leaves those out here, whatever the caller
    /// hands it: a category with no notes in a decade has no line, as it never had, and a decade
    /// the category filter leaves with no notes keeps its `0.0%` lines.
    ///
    /// - Parameter shares: The chart's rows (`data.shareByDecade(in:excluding:)`).
    /// - Returns: A `[Decade, Provenance, Share]` table.
    static func provenanceMixTable(_ shares: [SourceProvenanceData.CategoryDecadeShare]) -> ChartInspectorData {
        let columns = [
            String(localized: "series.provenance.trend.x", defaultValue: "Coverage decade"),
            String(localized: "series.provenance.category.legend", defaultValue: "Provenance"),
            String(localized: "series.provenance.trend.y", defaultValue: "Share of source notes"),
        ]
        return ChartInspectorData(
            id: "sa3.provenanceMix",
            title: String(localized: "series.provenance.trend.title", defaultValue: "Archival provenance over time"),
            columns: columns,
            rowCells: SourceProvenanceData.listed(shares).map { share in
                [plain(share.decade), share.category.displayName, percent(share.share)]
            },
            // One series per category, from the chart's rows and not the table's: a band is at
            // zero in a decade its category has no notes in, and a series without that point
            // would sound straight across the gap.
            audioGraph: bandedGraph(
                xLabel: columns[0], yLabel: columns[2],
                rows: shares.map { (band: $0.category.displayName, decade: $0.decade, share: $0.share) })
        )
    }

    /// The overall-composition bars' table (categorical): one row per provenance
    /// category with its note count and share.
    ///
    /// - Parameter composition: The overall composition (`data.overallComposition`).
    /// - Returns: A `[Provenance, Notes, Share]` table.
    static func compositionTable(_ composition: [SourceProvenanceData.CategoryComposition]) -> ChartInspectorData {
        let title = String(localized: "series.provenance.composition.title", defaultValue: "Overall provenance composition")
        let columns = [
            String(localized: "series.provenance.composition.x", defaultValue: "Provenance"),
            String(localized: "series.provenance.composition.y", defaultValue: "Source notes"),
            String(localized: "series.provenance.trend.y", defaultValue: "Share of source notes"),
        ]
        return ChartInspectorData(
            id: "sa3.composition",
            title: title,
            columns: columns,
            rowCells: composition.map { item in
                [item.category.displayName, plain(item.noteCount), percent(item.share)]
            },
            audioGraph: categoricalGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[1],
                points: composition.map { (label: $0.category.displayName, y: Double($0.noteCount)) })
        )
    }

    /// The documentary-density bars' table: one row per in-range decade.
    ///
    /// - Parameter density: The range-filtered density points (`data.notesByDecade(in:)`).
    /// - Returns: A `[Decade, Source notes, Volumes]` table.
    static func densityTable(_ density: [SourceProvenanceData.DecadeDensity]) -> ChartInspectorData {
        let title = String(localized: "series.provenance.density.title", defaultValue: "The documentary base by decade")
        let columns = [
            String(localized: "series.provenance.density.x", defaultValue: "Coverage decade"),
            String(localized: "series.provenance.density.y", defaultValue: "Source notes"),
            String(localized: "series.geography.totals.y", defaultValue: "Volumes"),
        ]
        return ChartInspectorData(
            id: "sa3.density",
            title: title,
            columns: columns,
            rowCells: density.map { item in
                [plain(item.decade), plain(item.totalNotes), plain(item.volumeCount)]
            },
            audioGraph: numericGraph(
                title: title,
                xLabel: columns[0], yLabel: columns[1],
                points: density.map { (x: $0.decade, y: Double($0.totalNotes)) })
        )
    }
}
