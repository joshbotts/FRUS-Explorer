// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(Accessibility)
import Accessibility
#endif
import SwiftUI

// MARK: - AXChartPoint

/// One plotted point, as VoiceOver's Audio Graph needs it (#268).
///
/// Numeric on purpose. `ChartInspectorData` — the table behind every "show the data" pop-up — holds
/// **already-formatted, already-localised** strings, and reading an axis range back out of them
/// means parsing "1,204" and "38%" in whatever locale rendered them. That silently yields a wrong
/// range rather than an error, which on an audio graph is inaudible: the tones simply describe the
/// wrong shape. So the builder takes numbers, and the bridge below refuses rather than guesses.
struct AXChartPoint: Sendable, Equatable {
    /// The x label as the chart shows it (a year, a decade, a category).
    let label: String
    /// The x value when the axis is numeric; `nil` for a categorical axis.
    let x: Double?
    /// The plotted value.
    let y: Double
}

// MARK: - AXChartDescriptorBuilder

/// Builds the `AXChartDescriptor` VoiceOver's Audio Graph reads (#268).
///
/// Nothing in the app had one before this: measured on the tree, **zero** occurrences of
/// `AXChartDescriptor` or `accessibilityChartDescriptor` against five analytics chart families
/// (corpus, person, cross-reference, archival, About-the-Series). Every chart was a single opaque
/// element to VoiceOver, describable only by whatever label its container carried.
///
/// ## What it deliberately does not do
/// It does not invent a range. An empty series produces `nil`, not a descriptor over `0...0` — an
/// Audio Graph with one flat tone reads as data rather than as absence, and the chart's own empty
/// state is the honest surface for that.
///
/// Version history:
///   1.0 — Session 2026-08-10: #268 (I-1)
enum AXChartDescriptorBuilder {

    /// Builds a descriptor for a single-series chart.
    ///
    /// - Parameters:
    ///   - title: The chart's localised title, spoken when the graph is entered.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - points: The plotted points, in chart order.
    /// - Returns: A descriptor, or `nil` when there is nothing to describe.
    #if canImport(Accessibility)
    @MainActor
    static func descriptor(
        title: String,
        xLabel: String,
        yLabel: String,
        points: [AXChartPoint]
    ) -> AXChartDescriptor? {
        guard !points.isEmpty else { return nil }

        let yValues = points.map(\.y)
        // `lowerBound == upperBound` makes the audio graph silent-flat and VoiceOver's own
        // range arithmetic divide by zero, so a genuinely constant series is widened by one.
        // Widening upward rather than symmetrically keeps a series of zeroes anchored at zero,
        // which is what a reader expects of a count.
        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 0
        let yAxis = AXNumericDataAxisDescriptor(
            title: yLabel,
            range: minY...(maxY > minY ? maxY : minY + 1),
            gridlinePositions: []
        ) { value in
            // Spoken per value. Counts are integral; a share is not, so the format follows the
            // data rather than assuming one.
            value == value.rounded()
                ? String(Int(value))
                : String(format: "%.1f", value)
        }

        let xAxis: AXDataAxisDescriptor
        if points.allSatisfy({ $0.x != nil }) {
            let xValues = points.compactMap(\.x)
            let minX = xValues.min() ?? 0
            let maxX = xValues.max() ?? 0
            xAxis = AXNumericDataAxisDescriptor(
                title: xLabel,
                range: minX...(maxX > minX ? maxX : minX + 1),
                gridlinePositions: []
            ) { String(Int($0)) }
        } else {
            // A categorical axis keeps the labels the chart shows — subseries and volume axes
            // have no numeric x, and forcing an index onto them would read as a meaningless
            // coordinate.
            xAxis = AXCategoricalDataAxisDescriptor(
                title: xLabel,
                categoryOrder: points.map(\.label)
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: points.allSatisfy { $0.x != nil },
            dataPoints: points.map { point in
                AXDataPoint(x: point.x ?? Double(points.firstIndex(of: point) ?? 0),
                            y: point.y,
                            additionalValues: [],
                            label: point.label)
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
    #endif

    /// Points parsed out of an inspector table, or `nil` when they cannot be read as numbers.
    ///
    /// The bridge exists so a chart that already builds a `ChartInspectorData` gets a descriptor
    /// without a second data path — but it **refuses** rather than guessing. `ChartInspectorData`
    /// cells are localised display strings, and a cell that will not parse means the descriptor
    /// would describe a shape the chart does not have.
    ///
    /// - Parameters:
    ///   - data: The inspector table.
    ///   - labelColumn: Index of the column holding the x label.
    ///   - valueColumn: Index of the column holding the plotted value.
    static func points(
        from data: ChartInspectorData,
        labelColumn: Int = 0,
        valueColumn: Int = 1
    ) -> [AXChartPoint]? {
        guard data.columns.indices.contains(labelColumn),
              data.columns.indices.contains(valueColumn),
              !data.rows.isEmpty else { return nil }
        var points: [AXChartPoint] = []
        for row in data.rows {
            guard row.cells.indices.contains(labelColumn),
                  row.cells.indices.contains(valueColumn),
                  let y = numeric(row.cells[valueColumn]) else { return nil }
            let label = row.cells[labelColumn]
            points.append(AXChartPoint(label: label, x: numeric(label), y: y))
        }
        return points
    }

    /// Reads a formatted cell back to a number, or `nil`.
    ///
    /// Handles the three shapes the adapters emit — a plain count, a grouped count (`1,204`), and
    /// a percentage (`38%`, read as 38). Anything else is a refusal, not a zero: a zero would put
    /// a point on the graph that the chart does not plot.
    static func numeric(_ cell: String) -> Double? {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let stripped = trimmed
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return nil }
        // Reject anything with a letter — "n/a", "—", a volume id — rather than letting a lenient
        // parser pull a leading digit out of it.
        guard !stripped.contains(where: { $0.isLetter }) else { return nil }
        return Double(stripped)
    }
}
