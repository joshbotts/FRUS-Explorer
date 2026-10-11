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

// MARK: - AXChartNumericParsingTests

/// Reading an inspector cell back to a number (#268).
///
/// The bridge from `ChartInspectorData` is the tempting shortcut and the dangerous one: those
/// cells are localised display strings, and a lenient parse yields a **wrong axis range** rather
/// than an error — which on an audio graph is inaudible. The tones simply describe a shape the
/// chart does not have.
///
/// Version history:
///   1.0 — Session 2026-08-10: #268 (I-1)
@Suite("AX chart numeric parsing (#268)")
struct AXChartNumericParsingTests {

    @Test("The three shapes the adapters emit all parse")
    func parsesRealCells() {
        #expect(AXChartDescriptorBuilder.numeric("42") == 42)
        #expect(AXChartDescriptorBuilder.numeric("1,204") == 1204)
        #expect(AXChartDescriptorBuilder.numeric("38%") == 38)
        #expect(AXChartDescriptorBuilder.numeric(" 7 ") == 7)
        #expect(AXChartDescriptorBuilder.numeric("12.5") == 12.5)
    }

    @Test("Anything with a letter is refused, not partially read")
    func refusesNonNumeric() {
        // A lenient parser pulls 1969 out of "frus1969-76v01" and puts a point on the graph that
        // the chart does not plot.
        for cell in ["frus1969-76v01", "n/a", "—", "", "  ", "12 volumes", "N"] {
            #expect(AXChartDescriptorBuilder.numeric(cell) == nil,
                    "\(cell) must be refused, got \(String(describing: AXChartDescriptorBuilder.numeric(cell)))")
        }
    }

    @Test("A table whose values do not parse yields no points at all")
    func tableRefusalIsWholesale() {
        // Partial parsing would drop rows silently, and an audio graph missing a third of its
        // points still sounds like a complete graph.
        let data = ChartInspectorData(
            id: "t", title: "T", columns: ["Year", "Count"],
            rowCells: [["1969", "12"], ["1970", "n/a"], ["1971", "8"]])
        #expect(AXChartDescriptorBuilder.points(from: data) == nil)
    }

    @Test("A clean table yields a point per row, with numeric x where the label is a year")
    func parsesAWholeTable() {
        let data = ChartInspectorData(
            id: "t", title: "T", columns: ["Year", "Count"],
            rowCells: [["1969", "12"], ["1970", "1,204"], ["1971", "8"]])
        let points = AXChartDescriptorBuilder.points(from: data)
        #expect(points?.count == 3)
        #expect(points?.map(\.y) == [12, 1204, 8])
        #expect(points?.map(\.x) == [1969, 1970, 1971], "a year label is a numeric x axis")
        #expect(points?.first?.label == "1969")
    }

    @Test("A categorical table has no numeric x")
    func categoricalLabels() {
        // Subseries and volume axes have no numeric x; forcing an index onto them would read as a
        // meaningless coordinate.
        let data = ChartInspectorData(
            id: "t", title: "T", columns: ["Subseries", "Documents"],
            rowCells: [["Truman", "120"], ["Eisenhower", "340"]])
        let points = AXChartDescriptorBuilder.points(from: data)
        #expect(points?.allSatisfy { $0.x == nil } == true)
        #expect(points?.map(\.label) == ["Truman", "Eisenhower"])
    }

    @Test("An empty or malformed table is refused")
    func emptyTable() {
        let empty = ChartInspectorData(id: "t", title: "T", columns: ["A", "B"], rowCells: [])
        #expect(AXChartDescriptorBuilder.points(from: empty) == nil)
        let oneColumn = ChartInspectorData(id: "t", title: "T", columns: ["A"],
                                           rowCells: [["1969"]])
        #expect(AXChartDescriptorBuilder.points(from: oneColumn) == nil,
                "a value column that does not exist must refuse, not crash")
    }
}

#if canImport(Accessibility)
import Accessibility

// MARK: - AXChartDescriptorShapeTests

/// The descriptor itself (#268).
///
/// Version history:
///   1.0 — Session 2026-08-10: #268 (I-1)
@Suite("AX chart descriptor (#268)")
@MainActor
struct AXChartDescriptorShapeTests {

    private func points(_ pairs: [(String, Double?, Double)]) -> [AXChartPoint] {
        pairs.map { AXChartPoint(label: $0.0, x: $0.1, y: $0.2) }
    }

    @Test("An empty series yields no descriptor")
    func emptyIsNil() {
        // A descriptor over 0...0 is one flat tone, which reads as data rather than as absence.
        #expect(AXChartDescriptorBuilder.descriptor(
            title: "T", xLabel: "Year", yLabel: "Count", points: []) == nil)
    }

    @Test("A constant series still gets a usable range")
    func constantSeriesIsWidened() throws {
        // lowerBound == upperBound makes the audio graph silent-flat and VoiceOver's own range
        // arithmetic divide by zero.
        let d = AXChartDescriptorBuilder.descriptor(
            title: "T", xLabel: "Year", yLabel: "Count",
            points: points([("1969", 1969, 5), ("1970", 1970, 5)]))
        let y = try #require(d?.yAxis as? AXNumericDataAxisDescriptor)
        #expect(y.range.lowerBound == 5)
        #expect(y.range.upperBound > 5, "a constant series must not have a zero-width range")
    }

    @Test("A numeric x axis is numeric; a categorical one is categorical")
    func axisKindFollowsTheData() {
        let numeric = AXChartDescriptorBuilder.descriptor(
            title: "T", xLabel: "Year", yLabel: "Count",
            points: points([("1969", 1969, 5), ("1970", 1970, 9)]))
        #expect(numeric?.xAxis is AXNumericDataAxisDescriptor)

        let categorical = AXChartDescriptorBuilder.descriptor(
            title: "T", xLabel: "Subseries", yLabel: "Documents",
            points: points([("Truman", nil, 120), ("Eisenhower", nil, 340)]))
        #expect(categorical?.xAxis is AXCategoricalDataAxisDescriptor)
    }

    @Test("Every plotted point reaches the series")
    func allPointsCarried() {
        let d = AXChartDescriptorBuilder.descriptor(
            title: "T", xLabel: "Year", yLabel: "Count",
            points: points([("1969", 1969, 5), ("1970", 1970, 9), ("1971", 1971, 2)]))
        #expect(d?.series.first?.dataPoints.count == 3,
                "a graph missing points still sounds complete — the failure is inaudible")
    }

    // MARK: - #268 adoption wave: column overrides, series splits, blank-skipping

    /// THE YEAR TRAP, pinned against the real corpus table. Under the default mapping the
    /// label column is the TERM and the value column is the PERIOD — and "1969" parses, so
    /// the descriptor would sonify years as values without a sound of complaint. This is why
    /// every corpus adoption states (labelColumn: 1, valueColumn: 5), and why this test
    /// drives the real builder rather than a hand-made fixture.
    @Test("The corpus table's default mapping mis-reads years as values; the override reads Plotted")
    func corpusTableNeedsColumnOverride() {
        let table = AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.byYear", title: "Berlin \u{2014} by Year", periodColumn: "Year",
            seriesByTerm: [(term: "Berlin", points: [
                CorpusSeriesPoint(periodLabel: "1969", denominatorKey: 1969, count: 40),
                CorpusSeriesPoint(periodLabel: "1970", denominatorKey: 1970, count: 55),
            ])],
            totals: [1969: 400, 1970: 500], isNormalized: false)

        // The trap parses: default columns yield "points" whose y-values are YEARS.
        let trapped = AXChartDescriptorBuilder.points(from: table)
        #expect(trapped != nil, "if this starts refusing, the trap is gone and the doc comments should say so")
        #expect(trapped?.map(\.y) == [1969, 1970], "the mis-read shape: periods as values")

        // The stated mapping reads (Period, Plotted).
        let points = AXChartDescriptorBuilder.points(from: table, labelColumn: 1, valueColumn: 5)
        #expect(points?.map(\.label) == ["1969", "1970"])
        #expect(points?.map(\.y) == [40, 55])
    }

    /// The interleaved multi-series shape, against the real trajectory builder: fed whole it
    /// parses into one zig-zag; split by the person column it yields one series per person in
    /// first-appearance order.
    @Test("seriesSplit separates the trajectory table by person")
    func trajectoryTableSplitsByPerson() {
        let table = AnalyticsChartTables.personTrajectoryTable(
            title: "Mention Trajectories", periodColumn: "Year",
            series: [
                (rollupId: 1, name: "Acheson", points: [
                    (period: 1949, mentions: 10, mentioningDocs: 8, datedTotal: 100, plotted: 10),
                    (period: 1950, mentions: 20, mentioningDocs: 15, datedTotal: 120, plotted: 20)]),
                (rollupId: 2, name: "Dulles", points: [
                    (period: 1949, mentions: 5, mentioningDocs: 4, datedTotal: 100, plotted: 5)]),
            ], isNormalized: false)

        let split = AXChartDescriptorBuilder.seriesSplit(
            from: table, seriesColumn: 0, labelColumn: 2, valueColumn: 6)
        #expect(split?.map(\.name) == ["Acheson", "Dulles"], "first-appearance order")
        #expect(split?.first?.points.map(\.y) == [10, 20])
        #expect(split?.last?.points.map(\.y) == [5])

        // The zig-zag the split exists to prevent: fed whole, the table still parses.
        let whole = AXChartDescriptorBuilder.points(from: table, labelColumn: 2, valueColumn: 6)
        #expect(whole?.count == 3, "which is why splitBySeriesColumn is mandatory for this chart")
    }

    /// The distribution's optional outbound column: blank cells SKIP under
    /// `skippingBlankValues`, and still refuse without it — absence is optional, garbage is not.
    @Test("Blank optional cells skip when asked, refuse otherwise")
    func distributionBlankOutboundCells() {
        let table = AnalyticsChartTables.crossRefDistributionTable(
            title: "Citation Degree Distribution",
            rows: [(bucket: "1", inDegreeDocuments: 900, outDegreeDocuments: 700),
                   (bucket: "2\u{2013}5", inDegreeDocuments: 400, outDegreeDocuments: nil)])
        #expect(AXChartDescriptorBuilder.points(from: table, labelColumn: 0, valueColumn: 2) == nil,
                "a blank cell refuses by default")
        let out = AXChartDescriptorBuilder.points(from: table, labelColumn: 0, valueColumn: 2,
                                                  skippingBlankValues: true)
        #expect(out?.map(\.y) == [700], "the blank row is skipped, not zero-filled")
        let inbound = AXChartDescriptorBuilder.points(from: table, labelColumn: 0, valueColumn: 1)
        #expect(inbound?.map(\.y) == [900, 400])
    }

    /// The person ranking's stated columns, against the real builder — label is the
    /// disambiguated chart label, value the mention count; the default would read (Rank,
    /// Person) and sonify rank positions.
    @Test("The person ranking's stated columns read label and mentions")
    func personRankingColumns() {
        let table = AnalyticsChartTables.personRankingTable(
            title: "Most-Mentioned People",
            rows: [(rollupId: 7, name: "Kissinger, Henry", axisLabel: "Kissinger, Henry",
                    mentions: 3200)])
        let points = AXChartDescriptorBuilder.points(from: table, labelColumn: 2, valueColumn: 4)
        #expect(points?.first?.label == "Kissinger, Henry")
        #expect(points?.first?.y == 3200)
    }

    /// The multi-series descriptor itself: one AXDataSeriesDescriptor per named series.
    @Test("The multi-series descriptor carries one series per name")
    @MainActor
    func multiSeriesDescriptorShape() {
        let a = [AXChartPoint(label: "1969", x: 1969, y: 1),
                 AXChartPoint(label: "1970", x: 1970, y: 2)]
        let b = [AXChartPoint(label: "1969", x: 1969, y: 3)]
        let d = AXChartDescriptorBuilder.descriptor(
            title: "Compare", xLabel: "Year", yLabel: "Documents",
            namedSeries: [("Berlin", a), ("Vietnam", b)])
        #expect(d?.series.count == 2)
        #expect(d?.series.map(\.name) == ["Berlin", "Vietnam"])
    }
}

// MARK: - SeriesAudioGraphTests

/// The About the Series charts' Audio Graphs, against the arrays the charts draw (#1587).
///
/// The shared card built each chart's descriptor from columns 0 and 1 of its "View as table" data,
/// and none of the four dashboards said otherwise. For six of the eleven tables column 1 is not the
/// plotted value: the Publication lag chart played each volume's publication year, and five charts
/// whose column 1 is a name were refused and got no descriptor. No test drove a Series adapter
/// through the descriptor builder, which is how the default went unchecked.
///
/// Each adapter now states the numbers its chart plots (`ChartInspectorData.audioGraph`). These
/// tests build every one of the eleven real tables and compare that statement with the property
/// the chart's mark reads, then with what the descriptor carries.
///
/// Version history:
///   1.0 — 2026-10-09: #1587 — initial implementation
@Suite("About the Series Audio Graphs (#1587)")
@MainActor
struct SeriesAudioGraphTests {

    // MARK: Fixtures

    /// Lag values no print year, coverage year or row index could be mistaken for, in an order
    /// that is not publication order.
    private static let lagPoints: [SeriesProductionData.LagPoint] = [
        .init(volumeId: "frus1969-76v01", subseries: "1969-76", coverageEndYear: 1972,
              printYear: 2003, lagYears: 31, coverageEra: .coldWar),
        .init(volumeId: "frus1861", subseries: "1861", coverageEndYear: 1861,
              printYear: 1861, lagYears: 0, coverageEra: .pre1900),
        .init(volumeId: "frus1945v05", subseries: "1945", coverageEndYear: 1945,
              printYear: 1967, lagYears: 22, coverageEra: .coldWar),
        .init(volumeId: "frus1945v02", subseries: "1945", coverageEndYear: 1945,
              printYear: 1967, lagYears: 23, coverageEra: .coldWar),
    ]

    private static func profile(_ id: String, _ president: String, _ party: PoliticalParty,
                                documents: Int, perYear: Double) -> AdministrationProfilesData.Profile {
        .init(id: id, number: 1, president: president, party: party, start: "1961-01-20", end: nil,
              pointDocCount: documents, rangeDocCount: 0, documentCount: documents, volumeCount: 3,
              termYears: 4, volumesPerAdministrationYear: perYear,
              coverageEarliest: nil, coverageLatest: nil)
    }

    private static let profiles = [
        profile("kennedy", "John F. Kennedy", .democratic, documents: 12_345, perYear: 8.66),
        profile("nixon", "Richard M. Nixon", .republican, documents: 20_001, perYear: 10.04),
    ]

    /// The y values of each series in `table`'s graph, by series name.
    private func plotted(_ table: ChartInspectorData) throws -> [(name: String, y: [Double])] {
        let graph = try #require(table.audioGraph, "\(table.id) states no graph: the card would read columns 0 and 1")
        return graph.series.map { ($0.name, $0.points.map(\.y)) }
    }

    /// The y values the descriptor carries for `table`, by series, through the call the card makes.
    private func described(_ table: ChartInspectorData) throws -> [[Double]] {
        let graph = try #require(table.audioGraph)
        let descriptor = try #require(AXChartDescriptorBuilder.descriptor(title: table.title, graph: graph),
                                      "\(table.id) builds no descriptor")
        // `__number`: the header marks `number` as refined for Swift and the overlay gives no reader.
        return descriptor.series.map { $0.dataPoints.compactMap { $0.yValue?.__number } }
    }

    // MARK: The lag chart: the wrong series

    @Test("Publication lag plays each volume's lag against its publication year, as a scatter")
    func lagPlaysTheLag() throws {
        let table = ChartInspectorAdapters.lagTable(Self.lagPoints)
        let graph = try #require(table.audioGraph)
        let points = try #require(graph.series.first).points

        // In publication order, ties by volume id; the table keeps the order it was given.
        #expect(points.map(\.label) == ["frus1861", "frus1945v02", "frus1945v05", "frus1969-76v01"])
        #expect(points.map(\.y) == [0, 23, 22, 31], "the lag, which is what the chart plots")
        #expect(points.map(\.x) == [1861, 1967, 1967, 2003], "against the publication year")
        #expect(table.rows.map { $0.cells[0] } == Self.lagPoints.map(\.volumeId))
        #expect(graph.xLabel == "Publication year")
        #expect(graph.yLabel == "Lag (years)")

        // Two volumes share 1967, so no line joins the points.
        let descriptor = try #require(AXChartDescriptorBuilder.descriptor(title: table.title, graph: graph))
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(try described(table) == [[0, 23, 22, 31]])
        #expect(descriptor.yAxis?.title == "Lag (years)")
        #expect((descriptor.xAxis as? AXNumericDataAxisDescriptor)?.range == 1861...2003)

        // What the card's default columns read from this same table, and played until #1587:
        // the volume id as the label and the PUBLICATION YEAR as the value.
        let old = try #require(AXChartDescriptorBuilder.points(from: table))
        #expect(old.map(\.y) == [2003, 1861, 1967, 1967])
        #expect(old.map(\.label) == Self.lagPoints.map(\.volumeId))
    }

    // MARK: The five that had no descriptor

    @Test("Volumes published per year plays the count of each year, not its era's name")
    func perYearPlaysCounts() throws {
        let buckets: [SeriesProductionData.PrintYearCount] = [
            .init(printYear: 1899, pubEra: .pre1900, count: 2),
            .init(printYear: 1946, pubEra: .coldWar, count: 7),
            .init(printYear: 2014, pubEra: .contemporary, count: 11),
        ]
        let table = ChartInspectorAdapters.perYearTable(buckets)
        #expect(AXChartDescriptorBuilder.points(from: table) == nil, "the default columns refused this table")
        let series = try plotted(table)
        #expect(series.count == 1)
        #expect(series.first?.y == [2, 7, 11])
        #expect(table.audioGraph?.series.first?.points.map(\.x) == [1899, 1946, 2014])
        #expect(try described(table) == [[2, 7, 11]])
        #expect(table.audioGraph?.yLabel == "Volumes")
    }

    @Test("Regional emphasis over time plays one series per region, each its share by decade")
    func regionTrendSplitsByRegion() throws {
        let shares: [SeriesGeographyData.RegionDecadeShare] = [
            .init(decade: 1940, region: .europe, share: 0.5),
            .init(decade: 1940, region: .nearEast, share: 0.125),
            .init(decade: 1950, region: .europe, share: 0.423),
            .init(decade: 1950, region: .nearEast, share: 0.2),
        ]
        let table = ChartInspectorAdapters.regionTrendTable(shares)
        #expect(AXChartDescriptorBuilder.points(from: table) == nil, "the default columns refused this table")
        let series = try plotted(table)
        #expect(series.map { $0.name } == [GeographicRegion.europe.displayName, GeographicRegion.nearEast.displayName])
        // The share in percent, to the decimal the table prints.
        #expect(series.map { $0.y } == [[50, 42.3], [12.5, 20]])
        #expect(try described(table) == [[50, 42.3], [12.5, 20]])
        #expect(table.audioGraph?.series.allSatisfy { $0.points.map(\.x) == [1940, 1950] } == true)
        // Read flat, by the columns that do hold the decade and the share, the four rows are one
        // series that crosses both regions.
        #expect(AXChartDescriptorBuilder.points(from: table, labelColumn: 0, valueColumn: 2)?.count == 4)
    }

    @Test("The two administration charts play documents and volumes per year, not the party's name")
    func administrationChartsPlayTheirValues() throws {
        let documents = ChartInspectorAdapters.administrationDocumentsTable(Self.profiles)
        #expect(AXChartDescriptorBuilder.points(from: documents) == nil, "the default columns refused this table")
        #expect(try plotted(documents).first?.y == [12_345, 20_001])
        #expect(documents.audioGraph?.series.first?.points.map(\.label) == ["John F. Kennedy", "Richard M. Nixon"])
        #expect(try described(documents) == [[12_345, 20_001]])

        let perYear = ChartInspectorAdapters.administrationVolumesPerYearTable(Self.profiles)
        #expect(AXChartDescriptorBuilder.points(from: perYear) == nil, "the default columns refused this table")
        // To one decimal, the figure the table prints and the bar's VoiceOver value reads.
        #expect(try plotted(perYear).first?.y == [8.7, 10])
        #expect(try described(perYear) == [[8.7, 10]])
        #expect(perYear.audioGraph?.yLabel == "Volumes per year")
    }

    @Test("Archival provenance over time plays one series per category, zero where the band is at zero")
    func provenanceMixKeepsItsZeroRows() throws {
        // The chart's rows: every category in every decade (#1543). The Lot File has no notes
        // in the 1950s here.
        let shares: [SourceProvenanceData.CategoryDecadeShare] = [
            .init(decade: 1940, category: .centralDecimalFile, share: 0.75),
            .init(decade: 1940, category: .lotFile, share: 0.25),
            .init(decade: 1950, category: .centralDecimalFile, share: 1),
            .init(decade: 1950, category: .lotFile, share: 0),
            .init(decade: 1960, category: .centralDecimalFile, share: 0.4),
            .init(decade: 1960, category: .lotFile, share: 0.6),
        ]
        let table = ChartInspectorAdapters.provenanceMixTable(shares)
        #expect(AXChartDescriptorBuilder.points(from: table) == nil, "the default columns refused this table")
        // The table leaves the zero row out, as it always has.
        #expect(table.rows.count == 5)

        let series = try plotted(table)
        #expect(series.map { $0.name } == [SourceProvenanceCategory.centralDecimalFile.displayName,
                                       SourceProvenanceCategory.lotFile.displayName])
        #expect(series.map { $0.y } == [[75, 100, 40], [25, 0, 60]],
                "the lot file's series passes through zero in the 1950s, where its band closes")
        #expect(try described(table) == [[75, 100, 40], [25, 0, 60]])
        #expect(table.audioGraph?.series.allSatisfy { $0.points.map(\.x) == [1940, 1950, 1960] } == true)
    }

    // MARK: The five that were read correctly: nothing they played has changed

    @Test("The five tables the default columns read correctly state the same points")
    func theFiveUnchangedTables() throws {
        let tables: [ChartInspectorData] = [
            ChartInspectorAdapters.cumulativeTable([
                .init(printYear: 1861, cumulativeCount: 1), .init(printYear: 1862, cumulativeCount: 3),
                .init(printYear: 2026, cumulativeCount: 553)]),
            ChartInspectorAdapters.regionTotalsTable([
                .init(region: .europe, volumeCount: 212), .init(region: .eastAsiaPacific, volumeCount: 97)]),
            ChartInspectorAdapters.topCountriesTable(
                [.init(slug: "soviet-union", volumeCount: 68), .init(slug: "china", volumeCount: 41)],
                displayName: { $0 == "china" ? "China" : "Soviet Union" }),
            ChartInspectorAdapters.compositionTable([
                .init(category: .centralDecimalFile, noteCount: 135_668, share: 0.52),
                .init(category: .lotFile, noteCount: 40_112, share: 0.154)]),
            ChartInspectorAdapters.densityTable([
                .init(decade: 1940, totalNotes: 30_524, volumeCount: 64),
                .init(decade: 1950, totalNotes: 59_973, volumeCount: 120)]),
        ]
        #expect(tables.map(\.id) == ["sa1.cumulative", "sa2.regionTotals", "sa2.topCountries",
                                     "sa3.composition", "sa3.density"])
        for table in tables {
            let graph = try #require(table.audioGraph, "\(table.id) states no graph")
            let fromColumns = try #require(AXChartDescriptorBuilder.points(from: table),
                                           "\(table.id) was readable by column")
            #expect(graph.series.count == 1)
            #expect(graph.series.first?.points == fromColumns, "\(table.id) plays different points")
            #expect(graph.series.first?.name == table.title)
            #expect(graph.xLabel == table.columns[0])
            #expect(graph.yLabel == table.columns[1])
            #expect(graph.isContinuous == nil)
            #expect(try described(table) == [fromColumns.map(\.y)])
        }
    }

    // MARK: Every table states its graph

    @Test("All eleven About the Series tables state a graph, and the card reads it first")
    func everySeriesTableStatesAGraph() throws {
        let tables: [ChartInspectorData] = [
            ChartInspectorAdapters.lagTable(Self.lagPoints),
            ChartInspectorAdapters.perYearTable([.init(printYear: 1946, pubEra: .coldWar, count: 7)]),
            ChartInspectorAdapters.cumulativeTable([.init(printYear: 1861, cumulativeCount: 1)]),
            ChartInspectorAdapters.regionTrendTable([.init(decade: 1940, region: .europe, share: 0.5)]),
            ChartInspectorAdapters.regionTotalsTable([.init(region: .europe, volumeCount: 212)]),
            ChartInspectorAdapters.topCountriesTable([.init(slug: "china", volumeCount: 41)], displayName: { $0 }),
            ChartInspectorAdapters.administrationDocumentsTable(Self.profiles),
            ChartInspectorAdapters.administrationVolumesPerYearTable(Self.profiles),
            ChartInspectorAdapters.provenanceMixTable([.init(decade: 1940, category: .lotFile, share: 1)]),
            ChartInspectorAdapters.compositionTable([.init(category: .lotFile, noteCount: 9, share: 1)]),
            ChartInspectorAdapters.densityTable([.init(decade: 1940, totalNotes: 9, volumeCount: 1)]),
        ]
        #expect(Set(tables.map(\.id)).count == 11)
        for table in tables {
            let graph = try #require(table.audioGraph, "\(table.id) states no graph")
            #expect(AXChartDescriptorBuilder.descriptor(title: table.title, graph: graph) != nil,
                    "\(table.id) builds no descriptor")
            #expect(!graph.xLabel.isEmpty && !graph.yLabel.isEmpty)
        }
        // A table that states none is still read by column, as the archival cards' are.
        let plain = ChartInspectorData(id: "t", title: "T", columns: ["Year", "Count"], rowCells: [["1969", "12"]])
        #expect(plain.audioGraph == nil)

        // The card's modifier asks the table before it reads any column.
        let card = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/SeriesAnalytics/SeriesChartCard.swift"), encoding: .utf8)
        let asks = try #require(card.range(of: "if let graph = inspector.audioGraph {"))
        let columns = try #require(card.range(of: "let xLabel = inspector.columns.indices.contains(labelColumn)"))
        #expect(asks.lowerBound < columns.lowerBound)
        #expect(card.contains("return AXChartDescriptorBuilder.descriptor(title: title, graph: graph)"))
    }

    @Test("A scatter is not continuous; a series left to the rule is continuous when its x is numeric")
    func continuityFollowsTheGraph() throws {
        let numeric = [AXChartPoint(label: "1969", x: 1969, y: 1), AXChartPoint(label: "1970", x: 1970, y: 2)]
        let named = [AXChartPoint(label: "Europe", x: nil, y: 1)]
        func continuous(_ points: [AXChartPoint], _ flag: Bool?) -> Bool? {
            AXChartDescriptorBuilder.descriptor(
                title: "T", graph: ChartAudioGraph(xLabel: "x", yLabel: "y",
                                                   series: [.init(name: "T", points: points)],
                                                   isContinuous: flag))?.series.first?.isContinuous
        }
        #expect(continuous(numeric, nil) == true)
        #expect(continuous(named, nil) == false)
        #expect(continuous(numeric, false) == false)
        // Several series take the flag too.
        let two = ChartAudioGraph(xLabel: "x", yLabel: "y",
                                  series: [.init(name: "A", points: numeric), .init(name: "B", points: numeric)],
                                  isContinuous: false)
        let descriptor = try #require(AXChartDescriptorBuilder.descriptor(title: "T", graph: two))
        #expect(descriptor.series.map(\.isContinuous) == [false, false])
        #expect(descriptor.series.map { $0.name } == ["A", "B"])
    }
}

// MARK: - AnalyticsAudioGraphTests

/// The Corpus Analytics and mention-trajectory Audio Graphs where decimals take a comma (#1616).
///
/// Both charts' descriptors read the Plotted column of their table back to numbers. In % of
/// documents that column holds a share written for the reader's region, and the reader takes a
/// comma for a thousands separator: `12,4` read as 124 and `12` as 12, so the series was ten times
/// too large wherever a share had a decimal digit. Each table now states the numbers its chart
/// plots. These tests build the real tables for a comma-decimal locale, read them by column to
/// show what was played, and compare the stated graph with the shares; then they hold the graph to
/// the columns where the columns were right, so nothing else the charts played has changed.
///
/// Version history:
///   1.0 — 2026-10-11: #1616 — initial implementation
@Suite("Analytics Audio Graphs where decimals take a comma (#1616)")
@MainActor
struct AnalyticsAudioGraphTests {

    private static let german = Locale(identifier: "de_DE")
    private static let american = Locale(identifier: "en_US")

    /// The y values the descriptor carries for `table`, by series, through the call the modifier makes.
    private func described(_ table: ChartInspectorData) throws -> [[Double]] {
        let descriptor = try built(table)
        // `__number`: the header marks `number` as refined for Swift and the overlay gives no reader.
        return descriptor.series.map { $0.dataPoints.compactMap { $0.yValue?.__number } }
    }

    /// The descriptor the modifier builds for a table that states its graph.
    private func built(_ table: ChartInspectorData) throws -> AXChartDescriptor {
        let graph = try #require(table.audioGraph, "\(table.id) states no graph: its cells would be read back")
        return try #require(AXChartDescriptorBuilder.descriptor(title: table.title, graph: graph),
                            "\(table.id) builds no descriptor")
    }

    /// One term by year in % of documents: 12.4%, 12%, and 6.25%, which prints as 6.2.
    private static func berlinShares(locale: Locale, withAnUncountedYear: Bool = false) -> ChartInspectorData {
        var points = [
            CorpusSeriesPoint(periodLabel: "1969", denominatorKey: 1969, count: 31),
            CorpusSeriesPoint(periodLabel: "1970", denominatorKey: 1970, count: 60),
            CorpusSeriesPoint(periodLabel: "1971", denominatorKey: 1971, count: 1),
        ]
        if withAnUncountedYear {
            points.append(CorpusSeriesPoint(periodLabel: "1972", denominatorKey: 1972, count: 3))
        }
        return AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.byYear", title: "\u{201C}Berlin\u{201D} \u{2014} By Year", periodColumn: "Year",
            seriesByTerm: [(term: "Berlin", points: points)],
            totals: [1969: 250, 1970: 500, 1971: 16], isNormalized: true, locale: locale)
    }

    // MARK: Corpus Analytics

    @Test("Where decimals take a comma, the corpus table prints 12,4 and the Audio Graph plays 12.4")
    func corpusSharesAreNotReadBackFromTheirCells() throws {
        let table = Self.berlinShares(locale: Self.german)

        // The premise, printed: the Plotted and Share cells take the region's comma.
        #expect(table.rows.map { $0.cells[5] } == ["12,4", "12", "6,2"])
        #expect(table.rows.map { $0.cells[4] } == ["12,4", "12", "6,2"])

        // What the descriptor played: the columns the ten chart sites name, read back. A share
        // with a decimal digit is ten times too large, and one without is right.
        let readBack = try #require(AXChartDescriptorBuilder.points(from: table, labelColumn: 1, valueColumn: 5))
        #expect(readBack.map(\.y) == [124, 12, 62])

        // What it plays now: the shares, to the decimal the table prints.
        let graph = try #require(table.audioGraph)
        #expect(graph.series.count == 1)
        #expect(graph.series.first?.points.map(\.y) == [12.4, 12, 6.2])
        #expect(graph.series.first?.points.map(\.x) == [1969, 1970, 1971])
        #expect(graph.series.first?.points.map(\.label) == ["1969", "1970", "1971"])
        #expect(graph.xLabel == "Year")
        #expect(graph.yLabel == table.columns[5])

        let descriptor = try built(table)
        #expect(try described(table) == [[12.4, 12, 6.2]])
        #expect(descriptor.yAxis?.range == 6.2...12.4, "the y axis ran to 124")
        #expect(descriptor.series.map { $0.name } == [table.title], "one term is the chart's one series")
        #expect(descriptor.xAxis is AXNumericDataAxisDescriptor)
    }

    @Test("A year with no denominator has a row and no point, where it used to refuse the whole graph")
    func aYearTheChartDoesNotPlotIsNotPlayed() throws {
        let table = Self.berlinShares(locale: Self.american, withAnUncountedYear: true)
        #expect(table.rows.count == 4)
        #expect(table.rows.last?.cells == ["Berlin", "1972", "3", "", "", ""])

        // The chart draws three marks (`AnalyticsView.normalizedValue` returns nil for 1972).
        let graph = try #require(table.audioGraph)
        #expect(graph.series.first?.points.map(\.label) == ["1969", "1970", "1971"])
        #expect(try described(table) == [[12.4, 12, 6.2]])
        // Read by column, the empty cell refused the table, so this chart had no Audio Graph.
        #expect(AXChartDescriptorBuilder.points(from: table, labelColumn: 1, valueColumn: 5) == nil)

        // With no denominator at all there is nothing to play, by either route.
        let none = AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.byYear", title: "T", periodColumn: "Year",
            seriesByTerm: [(term: "Berlin", points: [
                CorpusSeriesPoint(periodLabel: "1969", denominatorKey: 1969, count: 31)])],
            totals: [:], isNormalized: true, locale: Self.american)
        let empty = try #require(none.audioGraph)
        #expect(empty.series.map(\.points) == [[]])
        #expect(AXChartDescriptorBuilder.descriptor(title: none.title, graph: empty) == nil)
    }

    @Test("Where decimals take a point, the graph is what the chart sites' columns read")
    func theCorpusGraphIsItsColumns() throws {
        let years = [CorpusSeriesPoint(periodLabel: "1969", denominatorKey: 1969, count: 31),
                     CorpusSeriesPoint(periodLabel: "1970", denominatorKey: 1970, count: 1_204)]
        let decades = [CorpusSeriesPoint(periodLabel: "1960s", denominatorKey: 1960, count: 31),
                       CorpusSeriesPoint(periodLabel: "1970s", denominatorKey: 1970, count: 60)]
        let subseries = [CorpusSeriesPoint(periodLabel: "1969\u{2013}76", denominatorKey: nil, count: 9),
                         CorpusSeriesPoint(periodLabel: "Kennedy", denominatorKey: nil, count: 4)]
        var compared = 0
        for (points, totals, isNormalized) in [
            (years, [1969: 250, 1970: 9_000], false), (years, [1969: 250, 1970: 9_000], true),
            (decades, [1960: 250, 1970: 500], false), (decades, [1960: 250, 1970: 500], true),
            (subseries, [:], false),
        ] as [([CorpusSeriesPoint], [Int: Int], Bool)] {
            let table = AnalyticsChartTables.corpusSeriesTable(
                id: "corpus", title: "T", periodColumn: "Period",
                seriesByTerm: [(term: "Berlin", points: points)],
                totals: totals, isNormalized: isNormalized, locale: Self.american)
            let fromColumns = try #require(
                AXChartDescriptorBuilder.points(from: table, labelColumn: 1, valueColumn: 5))
            #expect(table.audioGraph?.series.map(\.points) == [fromColumns],
                    "normalized \(isNormalized), \(points.map(\.periodLabel))")
            #expect(table.audioGraph?.xLabel == table.columns[1])
            #expect(table.audioGraph?.yLabel == table.columns[5])
            compared += 1
        }
        #expect(compared == 5)

        // A year is a numeric x; a decade's label and a subseries' name are categories, as before.
        let byDecade = AnalyticsChartTables.corpusSeriesTable(
            id: "corpus", title: "T", periodColumn: "Decade",
            seriesByTerm: [(term: "Berlin", points: decades)],
            totals: [:], isNormalized: false, locale: Self.american)
        #expect(byDecade.audioGraph?.series.first?.points.map(\.x) == [nil, nil])
        #expect(try built(byDecade).xAxis is AXCategoricalDataAxisDescriptor)

        // A comparison: one series a term, in chip order, as the split by the Term column gave.
        let comparison = AnalyticsChartTables.corpusSeriesTable(
            id: "corpus", title: "T", periodColumn: "Year",
            seriesByTerm: [(term: "Berlin", points: years), (term: "Saigon", points: [years[0]])],
            totals: [1969: 250, 1970: 9_000], isNormalized: true, locale: Self.american)
        let split = try #require(AXChartDescriptorBuilder.seriesSplit(
            from: comparison, seriesColumn: 0, labelColumn: 1, valueColumn: 5))
        #expect(split.map(\.name) == ["Berlin", "Saigon"])
        #expect(comparison.audioGraph?.series.map(\.name) == split.map(\.name))
        #expect(comparison.audioGraph?.series.map(\.points) == split.map(\.points))
        #expect(try built(comparison).series.map { $0.name } == ["Berlin", "Saigon"])
    }

    @Test("The number the graph plays for a share is the number its cell prints, ties included")
    func shareValueIsTheCellsNumber() {
        // Every share a count of 0...n documents in n gives, n up to 400.
        var shares = 0, withADecimal = 0, ties = 0
        for total in 1...400 {
            for count in 0...total {
                let share = Double(count) / Double(total) * 100
                let cell = AnalyticsChartTables.formatShare(share, locale: Self.american)
                let value = AnalyticsChartTables.shareValue(share)
                shares += 1
                if cell.contains(".") { withADecimal += 1 }
                // A tie is where rounding half away from zero would differ: 6.25 prints 6.2.
                if (share * 10).rounded() / 10 != value { ties += 1 }
                guard AXChartDescriptorBuilder.numeric(cell) == value else {
                    Issue.record("\(count)/\(total): the cell prints \(cell) and the graph plays \(value)")
                    return
                }
                // The comma region prints the same digits.
                guard AnalyticsChartTables.formatShare(share, locale: Self.german)
                        == cell.replacingOccurrences(of: ".", with: ",") else {
                    Issue.record("\(count)/\(total): de_DE prints another number than \(cell)")
                    return
                }
            }
        }
        #expect(shares == 80_600)
        #expect(withADecimal > 60_000, "only \(withADecimal) shares had a decimal digit")
        #expect(ties > 0, "no tie was met, so the rounding rule went untested")
        #expect(AnalyticsChartTables.shareValue(6.25) == 6.2)
        #expect(AnalyticsChartTables.shareValue(6.35) == 6.4)
        #expect(AnalyticsChartTables.formatShare(6.25, locale: Self.american) == "6.2")
    }

    // MARK: Person Analytics

    private typealias Person = (rollupId: Int, name: String,
                                points: [(period: Int, mentions: Int, mentioningDocs: Int?,
                                          datedTotal: Int?, plotted: Double)])

    /// Acheson at 12.4% and 12%, Dulles at 6.25%: shares as the trajectory holds them, fractions.
    private static let shares: [Person] = [
        (rollupId: 1, name: "Acheson", points: [
            (period: 1949, mentions: 40, mentioningDocs: 31, datedTotal: 250, plotted: 0.124),
            (period: 1950, mentions: 70, mentioningDocs: 60, datedTotal: 500, plotted: 0.12)]),
        (rollupId: 2, name: "Dulles", points: [
            (period: 1949, mentions: 1, mentioningDocs: 1, datedTotal: 16, plotted: 0.0625)]),
    ]

    @Test("Where decimals take a comma, the trajectory table prints 12,4 and the Audio Graph plays 12.4")
    func trajectorySharesAreNotReadBackFromTheirCells() throws {
        let table = AnalyticsChartTables.personTrajectoryTable(
            title: "Mention Trajectories", periodColumn: "Year", series: Self.shares,
            isNormalized: true, locale: Self.german)
        #expect(table.rows.map { $0.cells[6] } == ["12,4", "12", "6,2"])

        // What the descriptor played: the split the chart's site names, read back.
        let readBack = try #require(AXChartDescriptorBuilder.seriesSplit(
            from: table, seriesColumn: 0, labelColumn: 2, valueColumn: 6))
        #expect(readBack.map { $0.points.map(\.y) } == [[124, 12], [62]])

        let graph = try #require(table.audioGraph)
        #expect(graph.series.map(\.name) == ["Acheson", "Dulles"])
        #expect(graph.series.map { $0.points.map(\.y) } == [[12.4, 12], [6.2]])
        #expect(graph.series.map { $0.points.map(\.x) } == [[1949, 1950], [1949]])
        #expect(graph.xLabel == "Year")
        #expect(graph.yLabel == table.columns[6])
        #expect(try described(table) == [[12.4, 12], [6.2]])
        #expect(try built(table).series.map { $0.name } == ["Acheson", "Dulles"])
    }

    @Test("In raw mentions, and where decimals take a point, the trajectory graph is its columns")
    func theTrajectoryGraphIsItsColumns() throws {
        let counts: [Person] = [
            (rollupId: 1, name: "Acheson", points: [
                (period: 1949, mentions: 10, mentioningDocs: 8, datedTotal: 100, plotted: 10),
                (period: 1950, mentions: 1_204, mentioningDocs: 900, datedTotal: 9_000, plotted: 1_204)]),
            (rollupId: 2, name: "Dulles", points: [
                (period: 1949, mentions: 5, mentioningDocs: 4, datedTotal: 100, plotted: 5)]),
        ]
        var compared = 0
        for (series, isNormalized) in [(counts, false), (Self.shares, true)] {
            let table = AnalyticsChartTables.personTrajectoryTable(
                title: "Mention Trajectories", periodColumn: "Year", series: series,
                isNormalized: isNormalized, locale: Self.american)
            let split = try #require(AXChartDescriptorBuilder.seriesSplit(
                from: table, seriesColumn: 0, labelColumn: 2, valueColumn: 6))
            #expect(table.audioGraph?.series.map(\.name) == split.map(\.name))
            #expect(table.audioGraph?.series.map(\.points) == split.map(\.points), "normalized \(isNormalized)")
            compared += 1
        }
        #expect(compared == 2)
    }

    @Test("One person charted is spoken as that person, not as the chart")
    func aLoneTrajectoryKeepsItsPersonsName() throws {
        let table = AnalyticsChartTables.personTrajectoryTable(
            title: "Mention Trajectories", periodColumn: "Year", series: [Self.shares[0]],
            isNormalized: true, locale: Self.american)
        let graph = try #require(table.audioGraph)
        #expect(graph.namesEverySeries)
        #expect(graph.series.count == 1)
        #expect(try built(table).series.map { $0.name } == ["Acheson"],
                "the split by the person column named a lone series for its person")

        // The flag is what keeps the name: the same graph without it takes the chart's title, as
        // a corpus chart of one term does.
        var untitled = graph
        untitled.namesEverySeries = false
        let titled = try #require(AXChartDescriptorBuilder.descriptor(title: table.title, graph: untitled))
        #expect(titled.series.map { $0.name } == ["Mention Trajectories"])
        #expect(Self.berlinShares(locale: Self.american).audioGraph?.namesEverySeries == false)
    }

    @Test("Two people who share a name are two series, where the split by name made them one")
    func twoPeopleOfOneNameAreTwoSeries() throws {
        let namesakes: [Person] = [
            (rollupId: 7, name: "Smith, John", points: [
                (period: 1949, mentions: 3, mentioningDocs: 3, datedTotal: 100, plotted: 3),
                (period: 1950, mentions: 4, mentioningDocs: 4, datedTotal: 100, plotted: 4)]),
            (rollupId: 9, name: "Smith, John", points: [
                (period: 1949, mentions: 8, mentioningDocs: 8, datedTotal: 100, plotted: 8)]),
        ]
        let table = AnalyticsChartTables.personTrajectoryTable(
            title: "Mention Trajectories", periodColumn: "Year", series: namesakes,
            isNormalized: false, locale: Self.american)
        let split = try #require(AXChartDescriptorBuilder.seriesSplit(
            from: table, seriesColumn: 0, labelColumn: 2, valueColumn: 6))
        #expect(split.map { $0.points.map(\.y) } == [[3, 4, 8]], "one series that ran 1949, 1950, 1949")
        #expect(try described(table) == [[3, 4], [8]])
    }

    // MARK: The views hand the modifier these tables

    @Test("Corpus Analytics and Person Analytics build the tables their Audio Graphs are given through these builders")
    func theViewsBuildTheirTablesHere() throws {
        typealias Scan = NaturalLanguageReadinessScanTests
        func squeezed(_ text: some StringProtocol) -> String {
            String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
                .map(Character.init))
        }
        func code(_ path: String) throws -> String {
            Scan.code(try String(contentsOf: Scan.repoRoot.appending(path: path), encoding: .utf8))
        }
        /// The body of `declaration` in `text`, whitespace removed, or `nil` when it is not there.
        func body(of declaration: String, in text: String) -> String? {
            guard let found = text.range(of: declaration),
                  let braces = Scan.braceBody(in: text, after: found.upperBound) else { return nil }
            return squeezed(text[braces])
        }

        // Corpus Analytics: every chart site is given `exportTable`, which is the series table.
        let corpus = try code("FRUSExplorer/Analytics/AnalyticsView.swift")
        let sites = squeezed(corpus).components(separatedBy: ".axChartDescriptor(").dropFirst()
        #expect(sites.count == 10)
        #expect(sites.allSatisfy { $0.hasPrefix("inspector:exportTable,title:exportFigureTitle,") },
                "a Corpus Analytics chart reads another table")
        let exportTable = try #require(body(of: "private var exportTable: ChartInspectorData?", in: corpus))
        #expect(exportTable.contains("returnAnalyticsChartTables.corpusSeriesTable("))

        // Person Analytics: the trajectory chart is given the trajectory table.
        let person = try code("FRUSExplorer/Analytics/PersonAnalyticsView.swift")
        let chart = try #require(body(of: "private var trajectoryChart: some View", in: person))
        #expect(chart.contains(".axChartDescriptor(inspector:trajectoryInspectorTable("))
        let table = try #require(body(of: "private func trajectoryInspectorTable(", in: person))
        #expect(table.contains("AnalyticsChartTables.personTrajectoryTable("))
    }
}
#endif
