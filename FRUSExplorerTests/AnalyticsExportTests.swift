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

    /// A word cloud is not a chart; filing both families under one prefix would make a download
    /// folder unsortable (D3 Phase 4).
    @Test("A caller can file an export under its own family prefix")
    func customPrefix() {
        let stem = AnalyticsExportDelivery.filenameStem(title: "Berlin Crisis",
                                                        prefix: "FRUS-WordCloud", date: date)
        #expect(stem.hasPrefix("FRUS-WordCloud-Berlin-Crisis-"))
        #expect(!stem.contains("Analytics"))
    }
}

// MARK: - PersonTrajectoryExportPeriodTests

/// Tests the period→source-years mapping the Person trajectory CSV depends on (D3 Phase 4).
///
/// The bug this guards: in **By Decade** mode a plotted point is keyed by the decade's start, but the
/// raw dictionaries are keyed by single year. Reading them with the decade start alone put a single
/// year's Mentions / Documents / Dated-documents next to a whole-decade Plotted value, so a reader
/// could not recompute the plotted share from the file — which is the entire reason those columns
/// are exported.
struct PersonTrajectoryExportPeriodTests {

    @Test("Year mode maps a period to exactly its own year")
    func yearMode() {
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1962, byDecade: false, range: 1861...1992)
        #expect(years == [1962])
    }

    @Test("Decade mode spans the whole decade")
    func decadeMode() {
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1960, byDecade: true, range: 1861...1992)
        #expect(years == Array(1960...1969))
    }

    /// The plotted point was built from in-range years only, so a leading edge decade must not pick
    /// up years the chart never counted — otherwise the summed columns overstate the plotted value.
    @Test("A leading edge decade is clipped to the range start")
    func clipsToRangeStart() {
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1960, byDecade: true, range: 1965...1992)
        #expect(years == Array(1965...1969))
    }

    @Test("A trailing edge decade is clipped to the range end")
    func clipsToRangeEnd() {
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1990, byDecade: true, range: 1861...1992)
        #expect(years == Array(1990...1992))
    }

    /// A decade wholly outside the range cannot produce a plotted point, but the mapping must still
    /// return something usable rather than trapping on an inverted range.
    @Test("A decade outside the range degrades to the period itself, never an inverted range")
    func outOfRangeDoesNotTrap() {
        #expect(PersonAnalyticsMath.sourceYears(forPeriod: 1800, byDecade: true, range: 1861...1992) == [1800])
        #expect(PersonAnalyticsMath.sourceYears(forPeriod: 2100, byDecade: true, range: 1861...1992) == [2100])
    }

    /// A decade's summed denominator has to be the sum of its years, not one year's — the concrete
    /// arithmetic the export now performs.
    @Test("Summing over the mapped years reproduces the decade, not its first year")
    func summingOverSpan() {
        let datedTotals = [1960: 100, 1961: 120, 1962: 140, 1963: 0, 1964: 90]
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1960, byDecade: true, range: 1960...1964)
        let total = years.compactMap { datedTotals[$0] }.reduce(0, +)
        #expect(total == 450)
        #expect(total != datedTotals[1960])
    }

    /// Pins the behaviour the decade-share caveat describes, because a first attempt at that caveat
    /// asserted the opposite and would have shipped a false methods statement.
    ///
    /// A decade's plotted share averages ONLY the years that produced a point. `sharePoints` emits
    /// nothing for a year the person was not mentioned in (the store groups by year and returns no
    /// zero rows), so those years never reach the divisor.
    @Test("A decade's share averages only the mentioned years, not the decade's years")
    func decadeShareAveragesMentionedYearsOnly() {
        // 100 dated documents in every year of the 1960s; the person appears in 50 documents in
        // 1961 and in no other year — so exactly one point exists for the decade.
        let totals = Dictionary(uniqueKeysWithValues: (1960...1969).map { ($0, 100) })
        let points = PersonAnalyticsMath.sharePoints(
            mentioningDocs: [7: [1961: 50]], totals: totals, names: [7: "A"], range: 1861...1992)
        #expect(points.count == 1)

        let decade = PersonAnalyticsMath.bucketByDecade(points, isShare: true)
        #expect(decade.count == 1)
        // The mean over the ONE mentioned year — 50% — not the decade's own 50/1000 = 5%.
        #expect(abs(decade[0].value - 0.5) < 0.0001)

        // What a reader recomputing from the exported columns would get instead.
        let years = PersonAnalyticsMath.sourceYears(forPeriod: 1960, byDecade: true, range: 1861...1992)
        let docs = years.compactMap { [1961: 50][$0] }.reduce(0, +)
        let dated = years.compactMap { totals[$0] }.reduce(0, +)
        #expect(dated == 1000)
        #expect(abs(Double(docs) / Double(dated) - 0.05) < 0.0001)
        // The two differ by 10x with IDENTICAL yearly denominators — which is why the caveat cannot
        // blame the gap on uneven denominators.
        #expect(decade[0].value > Double(docs) / Double(dated) * 9)
    }

    /// The raw path has no such asymmetry: a decade's raw value is a plain sum, so the exported
    /// column and the plotted value agree exactly.
    @Test("A decade's raw value equals the sum of its mapped years")
    func decadeRawIsExact() {
        let points = PersonAnalyticsMath.rawPoints(
            trajectories: [7: [1961: 12, 1965: 7, 1969: 31]], names: [7: "A"], range: 1861...1992)
        let decade = PersonAnalyticsMath.bucketByDecade(points, isShare: false)
        #expect(decade.count == 1)
        #expect(decade[0].value == 50)
    }
}

// MARK: - AnalyticsWordCloudExportTests

/// Tests the word cloud's D3 Phase 4 export surface — the one analytics artifact that is **not**
/// date-based, and whose table has to carry a denominator the picture cannot.
struct AnalyticsWordCloudExportTests {

    private func cloudProvenance(caveats: [String] = []) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: "Berlin Crisis",
            axisLabel: "Ranked by frequency across the scope's documents",
            scopeLabel: "Berlin Crisis",
            indexedVolumeCount: 552,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            extraCaveats: caveats,
            exportDate: Date(timeIntervalSince1970: 0)
        )
    }

    /// The point of the flag: a word cloud never reads a document date, so claiming the TEI dating
    /// rule — or reporting a year range — would describe work the export did not do.
    @Test("A non-dating export omits the dating rule and the year-range line")
    func nonDatingOmitsDateClaims() {
        let lines = cloudProvenance().csvPreambleLines
        #expect(!lines.contains { $0.contains("TEI <date>") })
        #expect(!lines.contains { $0.contains("Year range") })
        // Everything not about dating still has to be there.
        #expect(lines.contains { $0.contains("552") })
        #expect(lines.contains { $0.contains("Scope: Berlin Crisis") })
    }

    /// Guards the default: every dashboard chart IS date-based and must keep both disclosures.
    @Test("A dating export still carries both date disclosures")
    func datingKeepsDateClaims() {
        var dated = cloudProvenance()
        dated.appliesDocumentDating = true
        dated.yearRange = 1945...1949
        let lines = dated.csvPreambleLines
        #expect(lines.contains { $0.contains("TEI <date>") })
        #expect(lines.contains { $0.contains("Year range") && $0.contains("1945") })
    }

    /// Hand-hidden words are the user's own editorial judgement; a reader cannot infer them from
    /// anything else in the file, so the caveat has to survive into the preamble verbatim.
    @Test("View-supplied caveats reach the preamble")
    func caveatsReachPreamble() {
        let lines = cloudProvenance(caveats: ["Hidden words: 3 word(s) were hidden by hand in this cloud and are absent from this export."]).csvPreambleLines
        #expect(lines.contains { $0.contains("Hidden words: 3") })
    }

    /// The share column carries the denominator a picture cannot: a word's size is relative to the
    /// other words and says nothing about how much of the scope it accounts for.
    @Test("The term table ranks, counts, and shares against the token total")
    func tableShape() {
        let table = AnalyticsChartTables.wordCloudTable(
            title: "Berlin Crisis",
            terms: [(term: "berlin", count: 250), (term: "soviet", count: 125)],
            totalTokens: 1000)
        #expect(table.columns.count == 4)
        #expect(table.columns.last?.contains("%") == true)
        #expect(table.rows[0].cells == ["1", "berlin", "250", "25"])
        #expect(table.rows[1].cells == ["2", "soviet", "125", "12.5"])
    }

    /// With no token total there is nothing honest to divide by, so the column is dropped rather
    /// than filled with zeros or a division by zero.
    @Test("An unknown token total drops the share column entirely")
    func tableWithoutDenominator() {
        let table = AnalyticsChartTables.wordCloudTable(
            title: "Berlin Crisis",
            terms: [(term: "berlin", count: 250)],
            totalTokens: 0)
        #expect(table.columns.count == 3)
        #expect(!table.columns.contains { $0.contains("%") })
        #expect(table.rows[0].cells == ["1", "berlin", "250"])
    }

    /// A term containing a comma or a quote must survive into the CSV as one field.
    @Test("Term text is CSV-escaped, not concatenated into neighbouring columns")
    func termEscaping() {
        let csv = AnalyticsChartTables.wordCloudTable(
            title: "T", terms: [(term: "a,b\"c", count: 1)], totalTokens: 0).csv
        #expect(csv.contains("\"a,b\"\"c\""))
    }
}
