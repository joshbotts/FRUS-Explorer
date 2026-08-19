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
#endif
