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
}
#endif
