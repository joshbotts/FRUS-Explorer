// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - AnalyticsProvenanceTests

/// Tests the methods statement stamped onto exported analytics (D3): an exported figure or table is
/// a citable artifact, so what it claims about its own method has to be right — and the caveats the
/// app shows only conditionally on screen must appear unconditionally here.
struct AnalyticsProvenanceTests {

    private func sample(yearRange: ClosedRange<Int>? = 1861...1992,
                        valueMode: String? = "Raw count",
                        scope: String? = nil) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: "\"sovereignty\" — By Year",
            terms: ["sovereignty"],
            axisLabel: "By Year",
            scopeLabel: scope,
            indexedVolumeCount: 552,
            yearRange: yearRange,
            valueMode: valueMode,
            exportDate: Date(timeIntervalSince1970: 0)
        )
    }

    /// The dating caveat states the rule the service actually implements — including the
    /// volume-start-year fallback, which the pre-D3 on-screen copy omitted.
    @Test("Dating caveat discloses the volume-start-year fallback")
    func datingCaveatDisclosesFallback() {
        let text = sample().datingCaveat
        #expect(text.contains("TEI <date>"))
        #expect(text.lowercased().contains("falls back to the start year of its volume"))
        #expect(text.lowercased().contains("denominator"))
    }

    /// The selective-corpus caveat names the actual indexed count and is emitted in raw mode too —
    /// on screen it only appears with the `%` caption.
    @Test("Corpus caveat names the indexed volume count in every mode")
    func corpusCaveatAlwaysPresent() {
        let raw = sample(valueMode: "Raw count")
        #expect(raw.corpusCaveat.contains("552"))
        #expect(raw.csvPreambleLines.contains { $0.contains("552") })
    }

    /// A categorical axis ignores the year range; the block says so explicitly rather than omitting
    /// the line (an absent line reads as "not applicable" when the fact still matters).
    @Test("Categorical axes state that the year range was not applied")
    func categoricalRangeIsExplicit() {
        let p = sample(yearRange: nil)
        #expect(p.yearRangeDescription.lowercased().contains("not applied"))
        #expect(p.csvPreambleLines.contains { $0.contains("Year range") && $0.lowercased().contains("not applied") })
        // …and the figure caption omits the range rather than printing a misleading one.
        #expect(!p.captionLines[1].contains("1861"))
    }

    /// The figure caption is two lines: the title, then the identifying facts including the credit.
    @Test("Caption is two lines and self-identifying")
    func captionShape() {
        let lines = sample(scope: "1969-76").captionLines
        #expect(lines.count == 2)
        #expect(lines[0] == "\"sovereignty\" — By Year")
        #expect(lines[1].contains("1969-76"))
        #expect(lines[1].contains("1861–1992"))
        #expect(lines[1].contains("Raw count"))
        #expect(lines[1].contains("FRUS Explorer"))
    }

    /// Every preamble line is a `#` comment so a parser told `comment='#'` sees only the table.
    @Test("Preamble lines are all CSV comments")
    func preambleIsComments() {
        #expect(sample().csvPreambleLines.allSatisfy { $0 == "#" || $0.hasPrefix("# ") })
    }

    /// Scope defaults to the whole corpus when no volume scope is set.
    @Test("Absent scope reads as the whole corpus")
    func scopeDefault() {
        #expect(sample(scope: nil).scopeDescription == "Whole corpus")
        #expect(sample(scope: "Berlin Crisis").scopeDescription == "Berlin Crisis")
    }

    /// The stamped CSV keeps the underlying table intact below the preamble.
    @Test("Provenanced CSV preserves the table verbatim")
    func provenancedCSVKeepsTable() {
        let table = ChartInspectorData(id: "t", title: "T", columns: ["a", "b"], rowCells: [["1", "2"]])
        let text = table.provenancedCSV(sample())
        #expect(text.contains("\na,b\n1,2\n"))
        #expect(text.hasPrefix("# "))
    }
}

// MARK: - AnalyticsChartTablesTests

/// Tests the Corpus Analytics data table behind an exported figure (D3) — one schema for a single
/// term and for a D1 comparison, carrying every intermediate value so the figure is checkable.
struct AnalyticsChartTablesTests {

    private let columns = 6

    private func table(isNormalized: Bool,
                       series: [(term: String, points: [CorpusSeriesPoint])],
                       totals: [Int: Int]) -> ChartInspectorData {
        AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.byYear", title: "T", periodColumn: "Year",
            seriesByTerm: series, totals: totals, isNormalized: isNormalized)
    }

    /// Raw mode: the plotted value is the count, and the denominator/share are still reported.
    @Test("Raw mode reports count, denominator, share, and plots the count")
    func rawMode() {
        let t = table(isNormalized: false,
                      series: [(term: "war", points: [CorpusSeriesPoint(periodLabel: "1900", denominatorKey: 1900, count: 25)])],
                      totals: [1900: 200])
        #expect(t.columns.count == columns)
        #expect(t.rows.count == 1)
        #expect(t.rows[0].cells == ["war", "1900", "25", "200", "12.5", "25"])
    }

    /// Normalized mode: the plotted value is the share.
    @Test("Normalized mode plots the share")
    func normalizedMode() {
        let t = table(isNormalized: true,
                      series: [(term: "war", points: [CorpusSeriesPoint(periodLabel: "1900", denominatorKey: 1900, count: 25)])],
                      totals: [1900: 200])
        #expect(t.rows[0].cells == ["war", "1900", "25", "200", "12.5", "12.5"])
    }

    /// The regression this schema exists to expose: in `%` mode a period with no denominator is
    /// silently DROPPED from the chart. The table still lists it, with an empty plotted value.
    @Test("A period the chart drops still appears, with an empty plotted value")
    func missingDenominatorStillListed() {
        let t = table(isNormalized: true,
                      series: [(term: "war", points: [CorpusSeriesPoint(periodLabel: "1901", denominatorKey: 1901, count: 7)])],
                      totals: [:])   // no corpus total for 1901
        #expect(t.rows.count == 1)
        #expect(t.rows[0].cells == ["war", "1901", "7", "", "", ""])
    }

    /// A zero denominator produces no share (the chart's divide-by-zero guard) but is still
    /// REPORTED as `0` — blanking it would hide the reason the share is empty.
    @Test("Zero denominator is reported, and yields no share")
    func zeroDenominator() {
        let t = table(isNormalized: false,
                      series: [(term: "war", points: [CorpusSeriesPoint(periodLabel: "1902", denominatorKey: 1902, count: 3)])],
                      totals: [1902: 0])
        #expect(t.rows[0].cells == ["war", "1902", "3", "0", "", "3"])
    }

    /// A comparison exports the same shape as a single term — one row per (term, period), in chip order.
    @Test("Compare mode uses the same schema, one row per term and period")
    func compareShape() {
        let t = table(isNormalized: false,
                      series: [
                        (term: "war", points: [CorpusSeriesPoint(periodLabel: "1900", denominatorKey: 1900, count: 25),
                                               CorpusSeriesPoint(periodLabel: "1901", denominatorKey: 1901, count: 30)]),
                        (term: "peace", points: [CorpusSeriesPoint(periodLabel: "1900", denominatorKey: 1900, count: 5)]),
                      ],
                      totals: [1900: 200, 1901: 100])
        #expect(t.rows.count == 3)
        #expect(t.rows.map { $0.cells[0] } == ["war", "war", "peace"])
        #expect(t.rows[2].cells == ["peace", "1900", "5", "200", "2.5", "5"])
    }

    /// Axes with no corpus denominator (month/day/categorical) report counts and leave the
    /// denominator and share blank.
    @Test("Axes without a denominator leave those columns blank")
    func noDenominatorAxis() {
        let t = table(isNormalized: false,
                      series: [(term: "war", points: [CorpusSeriesPoint(periodLabel: "Berlin Crisis", denominatorKey: nil, count: 12)])],
                      totals: [:])
        #expect(t.rows[0].cells == ["war", "Berlin Crisis", "12", "", "", "12"])
    }

    /// Nothing committed yields an empty table rather than a crash.
    @Test("Empty series yields an empty table")
    func emptySeries() {
        let t = table(isNormalized: false, series: [], totals: [:])
        #expect(t.rows.isEmpty)
        #expect(t.columns.count == columns)
    }
}

// MARK: - AnalyticsExportDeliveryTests

/// Tests the export filename stem (D3) — repeat exports of the same chart must be distinguishable
/// in a download folder, and the stem must survive a title full of punctuation.
struct AnalyticsExportDeliveryTests {

    private let date = Date(timeIntervalSince1970: 1_753_000_000)   // 2025-07-20

    @Test("Stem is sanitized, hyphenated, and date-stamped")
    func stemShape() {
        let stem = AnalyticsExportDelivery.filenameStem(title: "\"sovereignty\", \"war\" — By Year", date: date)
        #expect(!stem.contains("\""))
        #expect(!stem.contains(","))
        #expect(!stem.contains(" "))
        #expect(stem.hasPrefix("FRUS-Analytics-"))
        #expect(stem.contains("sovereignty"))
        #expect(stem.contains("war"))
        // Date-stamped so two exports of the same chart do not collide.
        #expect(stem.contains("2025"))
    }

    @Test("A title with no usable characters still yields a filename")
    func degenerateTitle() {
        let stem = AnalyticsExportDelivery.filenameStem(title: "—  …", date: date)
        #expect(stem.hasPrefix("FRUS-Analytics-chart-"))
    }
}
