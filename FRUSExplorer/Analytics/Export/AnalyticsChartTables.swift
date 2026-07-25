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

    // MARK: - Person Analytics

    /// The most-mentioned-people ranking table.
    ///
    /// `axisLabel` is the chart's own y-axis text (`disambiguatedRankingLabels`), so a row whose
    /// canonical name is shared by two unmerged rollups reads the same here as on the figure — and
    /// the rollup id is carried so the two are still distinguishable.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - rows: Each ranked person's rollup id, canonical name, chart axis label, and mention count.
    /// - Returns: The table backing the ranking chart.
    static func personRankingTable(
        title: String,
        rows: [(rollupId: Int, name: String, axisLabel: String, mentions: Int)]
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.rank", defaultValue: "Rank"),
            String(localized: "analytics.export.column.person", defaultValue: "Person"),
            String(localized: "analytics.export.column.chartLabel", defaultValue: "Chart label"),
            String(localized: "analytics.export.column.rollupId", defaultValue: "Person id"),
            String(localized: "analytics.export.column.mentions", defaultValue: "Mentions in dated documents"),
        ]
        let cells = rows.enumerated().map { index, row in
            ["\(index + 1)", row.name, row.axisLabel, "\(row.rollupId)", "\(row.mentions)"]
        }
        return ChartInspectorData(id: "person.ranking", title: title, columns: columns, rowCells: cells)
    }

    /// The mention-trajectory table — the one that genuinely lets a reader check the figure.
    ///
    /// Both numerators the view holds are carried (raw mentions **and** the distinct mentioning
    /// documents that the share is actually computed from), alongside the dated-document
    /// denominator, so the plotted share can be recomputed from the file rather than trusted.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - periodColumn: `Year` or `Decade`, matching the by-decade toggle.
    ///   - series: Each compared person with their per-period values.
    ///   - isNormalized: Whether the chart plots shares rather than raw mention counts.
    /// - Returns: The table backing the trajectory chart.
    static func personTrajectoryTable(
        title: String,
        periodColumn: String,
        series: [(rollupId: Int, name: String, points: [(period: Int, mentions: Int, mentioningDocs: Int?, datedTotal: Int?, plotted: Double)])],
        isNormalized: Bool
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.person", defaultValue: "Person"),
            String(localized: "analytics.export.column.rollupId", defaultValue: "Person id"),
            periodColumn,
            String(localized: "analytics.export.column.mentions", defaultValue: "Mentions in dated documents"),
            String(localized: "analytics.export.column.mentioningDocs", defaultValue: "Documents mentioning this person"),
            String(localized: "analytics.export.column.datedTotal", defaultValue: "Dated documents in period"),
            String(localized: "analytics.export.column.plotted", defaultValue: "Plotted value"),
        ]
        var cells: [[String]] = []
        for person in series {
            for point in person.points {
                cells.append([
                    person.name,
                    "\(person.rollupId)",
                    "\(point.period)",
                    "\(point.mentions)",
                    point.mentioningDocs.map(String.init) ?? "",
                    point.datedTotal.map(String.init) ?? "",
                    isNormalized ? formatShare(point.plotted * 100) : "\(Int(point.plotted))",
                ])
            }
        }
        return ChartInspectorData(id: "person.trajectory", title: title, columns: columns, rowCells: cells)
    }

    /// The two-person relationship table: documents co-mentioning both people, per period.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - periodColumn: `Year` or `Decade`.
    ///   - personA: The first compared person's name.
    ///   - personB: The second compared person's name.
    ///   - points: Each period's co-mention document count.
    /// - Returns: The table backing the relationship chart.
    static func personRelationshipTable(
        title: String,
        periodColumn: String,
        personA: String,
        personB: String,
        points: [(period: Int, coMentions: Int)]
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.personA", defaultValue: "Person A"),
            String(localized: "analytics.export.column.personB", defaultValue: "Person B"),
            periodColumn,
            String(localized: "analytics.export.column.coMentions", defaultValue: "Documents mentioning both"),
        ]
        let cells = points.map { [personA, personB, "\($0.period)", "\($0.coMentions)"] }
        return ChartInspectorData(id: "person.relationship", title: title, columns: columns, rowCells: cells)
    }

    // MARK: - Cross-Reference Analytics

    /// The most-referenced-documents ranking table (in-degree).
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - rows: Each ranked document's volume, document id, display label, and inbound count.
    /// - Returns: The table backing the ranking chart.
    static func crossRefRankingTable(
        title: String,
        rows: [(volumeId: String, documentId: String, label: String, inDegree: Int)]
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.rank", defaultValue: "Rank"),
            String(localized: "analytics.export.column.document", defaultValue: "Document"),
            String(localized: "analytics.export.column.volumeId", defaultValue: "Volume id"),
            String(localized: "analytics.export.column.documentId", defaultValue: "Document id"),
            String(localized: "analytics.export.column.inDegree", defaultValue: "Inbound references"),
        ]
        let cells = rows.enumerated().map { index, row in
            ["\(index + 1)", row.label, row.volumeId, row.documentId, "\(row.inDegree)"]
        }
        return ChartInspectorData(id: "crossref.ranking", title: title, columns: columns, rowCells: cells)
    }

    /// The citation-degree distribution table.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - rows: Each degree bucket's label, inbound document count, and optional outbound count.
    /// - Returns: The table backing the histogram.
    static func crossRefDistributionTable(
        title: String,
        rows: [(bucket: String, inDegreeDocuments: Int, outDegreeDocuments: Int?)]
    ) -> ChartInspectorData {
        var columns = [
            String(localized: "analytics.export.column.degreeBucket", defaultValue: "References received"),
            String(localized: "analytics.export.column.docsInBucket", defaultValue: "Documents (inbound)"),
        ]
        let hasOut = rows.contains { $0.outDegreeDocuments != nil }
        if hasOut {
            columns.append(String(localized: "analytics.export.column.docsOutBucket", defaultValue: "Documents (outbound)"))
        }
        let cells = rows.map { row -> [String] in
            var cells = [row.bucket, "\(row.inDegreeDocuments)"]
            if hasOut { cells.append(row.outDegreeDocuments.map(String.init) ?? "") }
            return cells
        }
        return ChartInspectorData(id: "crossref.distribution", title: title, columns: columns, rowCells: cells)
    }

    /// The volume heat matrix as edge rows — one row per ordered (citing, cited) volume pair.
    ///
    /// A long edge list rather than a wide grid: it stays readable as a table, and it is the shape a
    /// reader would load to reproduce the matrix. The on-screen matrix encodes a cell's value only as
    /// opacity plus a tooltip, so these counts are otherwise unreadable.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - rows: Each cell's citing/cited volume (id, resolved title) and reference count.
    ///   - includingZeroes: When `false`, pairs with no references are omitted.
    /// - Returns: The table backing the heat matrix.
    static func crossRefMatrixTable(
        title: String,
        rows: [(sourceId: String, sourceTitle: String, targetId: String, targetTitle: String, count: Int)],
        includingZeroes: Bool = false
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.citingVolume", defaultValue: "Citing volume"),
            String(localized: "analytics.export.column.citingVolumeId", defaultValue: "Citing volume id"),
            String(localized: "analytics.export.column.citedVolume", defaultValue: "Cited volume"),
            String(localized: "analytics.export.column.citedVolumeId", defaultValue: "Cited volume id"),
            String(localized: "analytics.export.column.references", defaultValue: "References"),
        ]
        let cells = rows
            .filter { includingZeroes || $0.count > 0 }
            .map { [$0.sourceTitle, $0.sourceId, $0.targetTitle, $0.targetId, "\($0.count)"] }
        return ChartInspectorData(id: "crossref.matrix", title: title, columns: columns, rowCells: cells)
    }

    /// The PageRank landmark table.
    ///
    /// The score is otherwise reachable only through the chart's `accessibilityValue`, so this is the
    /// only way to read the actual influence numbers.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - rows: Each landmark's volume, document id, display label, and PageRank score.
    /// - Returns: The table backing the landmark chart.
    static func crossRefLandmarkTable(
        title: String,
        rows: [(volumeId: String, documentId: String, label: String, score: Double)]
    ) -> ChartInspectorData {
        let columns = [
            String(localized: "analytics.export.column.rank", defaultValue: "Rank"),
            String(localized: "analytics.export.column.document", defaultValue: "Document"),
            String(localized: "analytics.export.column.volumeId", defaultValue: "Volume id"),
            String(localized: "analytics.export.column.documentId", defaultValue: "Document id"),
            String(localized: "analytics.export.column.pageRank", defaultValue: "PageRank influence score"),
        ]
        let cells = rows.enumerated().map { index, row in
            ["\(index + 1)", row.label, row.volumeId, row.documentId,
             row.score.formatted(.number.precision(.significantDigits(1...6)))]
        }
        return ChartInspectorData(id: "crossref.landmarks", title: title, columns: columns, rowCells: cells)
    }
}
