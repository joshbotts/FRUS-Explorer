// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ChartInspectorRow

/// One row of a chart's underlying data table.
///
/// `cells` holds the already-formatted, already-localised string value for each
/// column, in the same order as the owning `ChartInspectorData.columns`, so
/// `cells.count == columns.count`. Formatting (years without commas, shares as
/// percents, plain counts) is the adapter's responsibility — the row is a pure
/// presentation value.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): out of `ChartDataInspector.swift`, a SwiftUI file,
///          into FRUSCoreKit, public
public struct ChartInspectorRow: Identifiable, Sendable, Hashable {
    /// The row's stable position (also its `Identifiable` id), 0-based in the
    /// order the adapter produced.
    public let id: Int
    /// The formatted cell strings, one per column in `columns` order.
    public let cells: [String]
}

// MARK: - ChartAudioGraph

/// What VoiceOver's Audio Graph plays for a chart: the numbers the chart plots, written by the
/// adapter that builds the chart's table, from the same array (#1587).
///
/// The other route to a descriptor reads a table's formatted cells back to numbers, by column
/// index (`AXChartDescriptorBuilder.points(from:labelColumn:valueColumn:)`). For the About the
/// Series tables that route went wrong in three ways no column index could repair: the card's
/// default columns (0 and 1) gave the Publication lag chart its publication years as the series,
/// and gave five charts whose column 1 is a name no descriptor at all; the provenance table
/// leaves out the zero rows its chart draws, so a band would have sounded across a decade it is
/// absent from; and a scatter has no "continuous" reading. A table that carries its graph has
/// none of the three, and its adapter's test compares these numbers with the array the chart
/// draws (`SeriesAudioGraphTests`).
///
/// Version history:
///   1.0 — 2026-10-09: #1587 — initial implementation
///   1.1 — 2026-10-11: #1616 — `namesEverySeries`, for the mention-trajectory chart, whose one
///          series is still a person
///   1.2 — 2026-11-11 (FRUS Explorer Light, S24a): out of `ChartDataInspector.swift`, a SwiftUI file,
///          into FRUSCoreKit, public
public struct ChartAudioGraph: Sendable, Hashable {

    /// One series: a name VoiceOver speaks, and its points in x order.
    public struct Series: Sendable, Hashable {
        /// The series' name: the chart's title for a single series, the region or category for
        /// one band of a stacked chart.
        public let name: String
        /// The plotted points.
        public let points: [AXChartPoint]
    }

    /// The x axis's title.
    public let xLabel: String
    /// The y axis's title.
    public let yLabel: String
    /// The series, in legend order. One for most charts; one per band for a stacked area.
    public let series: [Series]
    /// `false` for a scatter, whose points no line joins. `nil` leaves it to the descriptor
    /// builder's rule: a series is continuous when every point has a numeric x.
    public var isContinuous: Bool? = nil
    /// Whether a lone series is spoken under its own name. `false`, the default, gives it the
    /// chart's title: a chart of one series is that series. `true` is for a chart whose series
    /// are the things it compares, the people of a mention trajectory, where one person charted
    /// is still spoken as that person (#1616).
    public var namesEverySeries: Bool = false
}

// MARK: - ChartInspectorData

/// The full underlying-data table for a single Series-dashboard chart, ready to
/// be shown in a pop-up via `ChartDataInspectorView`.
///
/// Adapters build this from the *same* arrays their chart plots — for the
/// range-filtered time-series charts that means the in-domain arrays, so the
/// table matches the visible chart and updates with the year range. Column
/// headers arrive already-localised; cell values arrive already-formatted.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
///   1.1 — 2026-10-09: #1587 — `audioGraph`, the numbers the chart plots, for a table whose
///          adapter states them; `nil` for every table that does not
///   1.2 — 2026-11-11 (FRUS Explorer Light, S24a): out of `ChartDataInspector.swift`, a SwiftUI file,
///          into FRUSCoreKit, public
public struct ChartInspectorData: Identifiable, Sendable, Hashable {
    /// A stable per-chart key (e.g. `"sa1.lag"`), also the `Identifiable` id used
    /// to drive the presenting `.sheet(item:)`.
    public let id: String
    /// The chart's localised title, shown at the top of the pop-up.
    public let title: String
    /// The localised column headers, in table order.
    public let columns: [String]
    /// The data rows; each row's `cells.count` equals `columns.count`.
    public let rows: [ChartInspectorRow]
    /// The numbers the chart plots, for VoiceOver's Audio Graph, when the table's adapter states
    /// them (#1587). `nil` leaves the descriptor to the columns its chart's view names.
    public let audioGraph: ChartAudioGraph?

    /// Builds an inspector table, wrapping each raw cell array into a
    /// positionally-identified `ChartInspectorRow`.
    ///
    /// - Parameters:
    ///   - id: The stable per-chart key.
    ///   - title: The localised chart title.
    ///   - columns: The localised column headers.
    ///   - rowCells: Each row's formatted cell strings (each the same length as
    ///     `columns`).
    ///   - audioGraph: The numbers the chart plots, or `nil`, the default.
    public init(id: String, title: String, columns: [String], rowCells: [[String]],
         audioGraph: ChartAudioGraph? = nil) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rowCells.enumerated().map { ChartInspectorRow(id: $0.offset, cells: $0.element) }
        self.audioGraph = audioGraph
    }

    /// A CSV serialisation of the table (header row + data rows), RFC-4180-style:
    /// a cell containing a comma, a double quote, or a newline is wrapped in
    /// double quotes with any embedded quotes doubled. Rows are joined with `\n`.
    public var csv: String {
        var lines: [String] = []
        lines.append(columns.map(Self.escapeCSV).joined(separator: ","))
        for row in rows {
            lines.append(row.cells.map(Self.escapeCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Escapes one CSV field, quoting it when it contains a comma, quote, or
    /// newline and doubling any embedded quotes.
    ///
    /// - Parameter field: The raw cell text.
    /// - Returns: The CSV-safe field.
    public static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
