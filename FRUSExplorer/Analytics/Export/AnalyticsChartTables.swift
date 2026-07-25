// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CorpusSeriesPoint

/// One plotted point of a Corpus Analytics series, in the neutral form the CSV adapter consumes (D3).
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
struct CorpusSeriesPoint: Sendable, Equatable {
    /// The period as the chart labels it (`1969`, `1960s`, `February 1969`, `Berlin Crisis`…).
    let periodLabel: String
    /// The key into the corpus-totals denominator (a year, or a decade's start year) — `nil` on the
    /// axes that have no per-period corpus total (By Month / By Day / the categorical breakdowns).
    let denominatorKey: Int?
    /// Documents matching the term in this period.
    let count: Int
}

// MARK: - AnalyticsChartTables

/// Builds `ChartInspectorData` tables for the analytics charts (D3), so every figure has a citable
/// data table behind it.
///
/// SwiftUI-free and dependency-free — the caller pre-resolves labels — so the row shapes are
/// directly unit-testable, matching `ChartInspectorAdapters` in the Series dashboards.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
enum AnalyticsChartTables {

    /// The Corpus Analytics series table: one row per (term, period).
    ///
    /// The schema is the same whether one term or several are charted — the `Term` column is always
    /// present — so a single-term export and a D1 comparison export are the same file shape.
    ///
    /// Every intermediate value is carried, not just the plotted one: the raw matching-document
    /// count, the corpus denominator for that period, the derived share, and finally the value the
    /// chart actually plots. That makes the figure checkable, and it **exposes the periods the chart
    /// silently drops** — in `% of documents` mode a period whose denominator is missing or zero is
    /// omitted from the chart (a divide-by-zero guard), and here it appears as a row with a count
    /// but an empty share and an empty plotted value.
    ///
    /// - Parameters:
    ///   - id: A stable per-chart key, also the inspector sheet's identity.
    ///   - title: The chart's title.
    ///   - periodColumn: The localized header for the period column (`Year`, `Decade`, …).
    ///   - seriesByTerm: Each charted term with its points, in chip (color) order.
    ///   - totals: The corpus document totals keyed the same way as `denominatorKey`; empty when the
    ///     axis has no denominator.
    ///   - isNormalized: Whether the chart is plotting shares rather than raw counts.
    /// - Returns: The table backing this chart.
    static func corpusSeriesTable(
        id: String,
        title: String,
        periodColumn: String,
        seriesByTerm: [(term: String, points: [CorpusSeriesPoint])],
        totals: [Int: Int],
        isNormalized: Bool
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.term", defaultValue: "Term"),
            periodColumn,
            String(localized: "analytics.export.column.matching", defaultValue: "Matching documents"),
            String(localized: "analytics.export.column.corpusTotal", defaultValue: "Indexed documents in period"),
            String(localized: "analytics.export.column.share", defaultValue: "Share of indexed documents (%)"),
            String(localized: "analytics.export.column.plotted", defaultValue: "Plotted value"),
        ]
        var rows: [[String]] = []
        for series in seriesByTerm {
            for point in series.points {
                let total = point.denominatorKey.flatMap { totals[$0] }
                let share: Double? = {
                    guard let total, total > 0 else { return nil }
                    return Double(point.count) / Double(total) * 100
                }()
                let plotted: String = {
                    guard isNormalized else { return "\(point.count)" }
                    // Matches `normalizedValue`: no denominator ⇒ the chart plots nothing here.
                    guard let share else { return "" }
                    return formatShare(share)
                }()
                rows.append([
                    series.term,
                    point.periodLabel,
                    "\(point.count)",
                    total.map(String.init) ?? "",
                    share.map(formatShare) ?? "",
                    plotted,
                ])
            }
        }
        return ChartInspectorData(id: id, title: title, columns: columns, rowCells: rows)
    }

    /// A share formatted to one decimal place, matching the chart's axis labels.
    ///
    /// - Parameter share: A percentage in `0...100`.
    /// - Returns: The formatted value, e.g. `12.4`.
    static func formatShare(_ share: Double) -> String {
        share.formatted(.number.precision(.fractionLength(0...1)))
    }
}
