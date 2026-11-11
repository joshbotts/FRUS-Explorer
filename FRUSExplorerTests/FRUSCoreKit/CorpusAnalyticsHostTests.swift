// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - CorpusAnalyticsHostTests

/// Corpus Analytics and the method block as a host drives them (FRUS Explorer Light's S24a): the service
/// over an index the kit builds, the volume folding at a series count the host chooses, the series table,
/// the methods statement rendered for a host's own version, locale, calendar and time zone, and the search
/// the "View N documents" link opens, counted by Search's own service.
///
/// The moved suites render through the app's names, which pass the app's host (`AnalyticsTestSupport.swift`
/// gives the package the same names). These call the kit's own forms, with a host that fixes what the app
/// takes from the reader, which is what a server does. Like every kit suite they import the kit
/// `@testable`, so they show what a host gets, not that it is public: FRUS Explorer Light's access proof,
/// a file of its server's that imports the kit without `@testable`, shows that.
///
/// Version history:
///   1.0 — 2026-11-11 (FRUS Explorer Light, S24a): initial implementation, when Corpus Analytics and the
///          method block moved into the kit
@Suite("Corpus Analytics as a host drives it")
struct CorpusAnalyticsHostTests {

    /// A host that fixes everything the app takes from the reader.
    static let host = AnalyticsProvenance.Host(
        appVersion: "1.0", locale: Locale(identifier: "en_US"),
        calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC")!)

    /// 2026-11-11 15:30 UTC.
    static let exportDate = Date(timeIntervalSince1970: 1_794_411_000)

    static func provenance(indexedVolumeCount: Int = 1_234) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: "\"treaty\" — By Year", terms: ["treaty"], axisLabel: "By Year",
            indexedVolumeCount: indexedVolumeCount, yearRange: 1861...1992, valueMode: "Raw count",
            countingUnit: "Documents", exportDate: exportDate)
    }

    // MARK: - The host

    @Test("The credit line names the host's version, and a dash when it has none")
    func creditIsTheHosts() {
        #expect(AnalyticsProvenance.appCredit(for: Self.host) == "FRUS Explorer 1.0")
        #expect(AnalyticsProvenance.appCredit(for: AnalyticsProvenance.Host(appVersion: nil)) == "FRUS Explorer —")
    }

    @Test("The export date is written in the host's locale, calendar and time zone")
    func dateIsTheHosts() throws {
        let p = Self.provenance()
        let utc = p.formattedDate(for: Self.host)
        #expect(utc.contains("Nov 11, 2026") && utc.contains("3:30"), "\(utc)")
        var tokyo = Self.host
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let later = p.formattedDate(for: tokyo)
        #expect(later.contains("Nov 12, 2026") && later.contains("12:30"), "\(later)")
    }

    @Test("The corpus caveat groups the volume count for the host's locale")
    func corpusCountIsTheHosts() {
        let p = Self.provenance()
        #expect(p.corpusCaveat(for: Self.host).contains("1,234 volumes"))
        var german = Self.host
        german.locale = Locale(identifier: "de_DE")
        #expect(p.corpusCaveat(for: german).contains("1.234"))
    }

    @Test("The app's host writes what the renderings wrote before they took a host")
    func theAppsHostIsTheReaders() {
        let p = Self.provenance()
        let reader = AnalyticsProvenance.Host(appVersion: nil)
        // `ByDayTimeZoneTests` sets the process's zone while it runs, so the pair is taken again if the zone
        // moved while it was taken: two renderings either side of a move would differ for that reason alone.
        var pair = ("", "")
        for _ in 0..<3 {
            let zone = TimeZone.current.identifier
            pair = (p.formattedDate(for: reader), p.exportDate.formatted(date: .abbreviated, time: .shortened))
            if TimeZone.current.identifier == zone { break }
        }
        #expect(pair.0 == pair.1)
        #expect(p.corpusCaveat(for: reader).contains(CountCopy.volumes(1_234)))
    }

    @Test("Every rendering that names the credit or the date takes them from the host")
    func renderingsReadTheHost() throws {
        let p = Self.provenance()
        let date = p.formattedDate(for: Self.host)
        let caption = p.captionLines(for: Self.host)
        #expect(caption.count == 2)
        #expect(caption[1].hasSuffix("FRUS Explorer 1.0 · \(date)"), "\(caption[1])")
        let preamble = p.csvPreambleLines(for: Self.host)
        #expect(preamble.contains("# Exported: FRUS Explorer 1.0, \(date)"), "\(preamble)")
        #expect(preamble.contains("# \(p.corpusCaveat(for: Self.host))"))
        #expect(p.allCaveats(for: Self.host).contains(p.corpusCaveat(for: Self.host)))
        let plate = p.plateLines(for: Self.host)
        #expect(plate.first == AnalyticsPlateLine(role: .title, text: caption[0]))
        #expect(plate.contains(AnalyticsPlateLine(role: .facts, text: caption[1])))
        #expect(plate.filter { $0.role == .caveat }.map(\.text) == p.plateCaveatLines(for: Self.host))
    }

    @Test("A stamped CSV is the host's method block above the bare table")
    func stampedCSV() {
        let table = ChartInspectorData(id: "t", title: "T", columns: ["Year", "Count"],
                                       rowCells: [["1969", "2"], ["1977", "1"]])
        let text = table.provenancedCSV(Self.provenance(), for: Self.host)
        #expect(text.hasPrefix("# FRUS Explorer — analytics export\n#\n"))
        #expect(text.hasSuffix("\n" + table.csv + "\n"))
        #expect(text == (Self.provenance().csvPreambleLines(for: Self.host) + [table.csv]).joined(separator: "\n") + "\n")
    }

    // MARK: - The folding

    @Test("The folding keeps the heaviest volumes and folds the rest into one Other series")
    func folding() {
        let raw: [(period: Int, volumeId: String, count: Int)] = [
            (1969, "frus1969-76v01", 5), (1969, "frus1969-76v02", 1), (1970, "frus1969-76v02", 3),
            (1970, "frus1969-76v03", 2), (1970, "frus1969-76v04", 1),
        ]
        let three = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: 3)
        // Four volumes, three colours: the first two by total, and Other for the rest.
        #expect(three.series.map(\.key) == ["frus1969-76v01", "frus1969-76v02", AnalyticsSourceColoring.otherSourceKey])
        #expect(three.series.map(\.total) == [5, 4, 3])
        #expect(three.segments.map(\.id) == ["1969/frus1969-76v01", "1969/frus1969-76v02",
                                             "1970/\(AnalyticsSourceColoring.otherSourceKey)", "1970/frus1969-76v02"])
        #expect(three.segments.map(\.count) == [5, 1, 3, 3])
        // As many colours as volumes: nothing folds.
        let four = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: 4)
        #expect(!four.series.contains { $0.key == AnalyticsSourceColoring.otherSourceKey })
        #expect(four.series.count == 4)
        #expect(AnalyticsSourceColoring.sourceColoring([], seriesCount: 3).series.isEmpty)
        // One colour, the floor: every volume folds into Other.
        let one = AnalyticsSourceColoring.sourceColoring(raw, seriesCount: 1)
        #expect(one.series.map(\.key) == [AnalyticsSourceColoring.otherSourceKey])
        #expect(one.series.map(\.total) == [12])
    }

    // MARK: - The link

    @Test("The link passes years only on a date axis whose range the reader narrowed, over document text alone")
    func linkParameters() {
        let narrowed = AnalyticsSearchHandoff.parameters(term: "treaty", axis: .byYear, startYear: 1953,
                                                         endYear: 1961, yearsNarrowed: true, scopeVolumeIds: nil)
        #expect(narrowed.dateRange == DateRange(earliest: "1953-01-01", latest: "1961-12-31"))
        #expect(!narrowed.includeSummaries && !narrowed.includeNotes)
        #expect(AnalyticsSearchHandoff.parameters(term: "treaty", axis: .byYear, startYear: 1953, endYear: 1961,
                                                  yearsNarrowed: false, scopeVolumeIds: nil).dateRange == nil)
        let categorical = AnalyticsSearchHandoff.parameters(term: "treaty", axis: .byVolume, startYear: 1953,
                                                            endYear: 1961, yearsNarrowed: true,
                                                            scopeVolumeIds: ["frus1969-76v01"])
        #expect(categorical.dateRange == nil)
        #expect(categorical.volumeIds == ["frus1969-76v01"])
    }

    // MARK: - The whole path

    @Test("A host charts a term over an index it built, folds it, tables it, stamps it and counts its link")
    func wholePath() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volumes = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volumes.appendingPathComponent("frus1969-76v01.xml"), volumeId: "frus1969-76v01",
                documents: [("d1", "<head>1. Memorandum</head><p>The treaty was signed.</p>"),
                            ("d2", "<head>2. Memorandum</head><p>A treaty draft circulated.</p>"),
                            ("d3", "<head>3. Memorandum</head><p>Economic policy only.</p>")])
            try writeAnalyticsVolume(
                to: volumes.appendingPathComponent("frus1977-80v01.xml"), volumeId: "frus1977-80v01",
                documents: [("d1", "<head>1. Memorandum</head><p>The treaty was ratified.</p>")])
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            // Undated documents sit at their volume's first year, in the counts and the totals alike.
            let byYear = try await service.termFrequencyByYear(term: "treaty")
            #expect(byYear.map(\.year) == [1969, 1977])
            #expect(byYear.map(\.count) == [2, 1])
            let totals = try await service.documentTotalsByYear()
            #expect(totals == [1969: 3, 1977: 1])
            let segments = try await service.termFrequencyByYearAndVolume(term: "treaty")
            let folded = AnalyticsSourceColoring.sourceColoring(
                segments.map { (period: $0.year, volumeId: $0.volumeId, count: $0.count) }, seriesCount: 6)
            #expect(folded.series.map(\.key) == ["frus1969-76v01", "frus1977-80v01"])

            let table = AnalyticsChartTables.corpusSeriesTable(
                id: "corpus.byYear", title: "\"treaty\" — By Year", periodColumn: "Year",
                seriesByTerm: [(term: "treaty", points: byYear.map {
                    CorpusSeriesPoint(periodLabel: "\($0.year)", denominatorKey: $0.year, count: $0.count)
                })],
                totals: totals, isNormalized: true, locale: Locale(identifier: "en_US"))
            #expect(table.rows.map(\.cells) == [["treaty", "1969", "2", "3", "66.7", "66.7"],
                                                ["treaty", "1977", "1", "1", "100", "100"]])
            #expect(table.audioGraph?.series.first?.points.map(\.y) == [66.7, 100])
            let stamped = table.provenancedCSV(Self.provenance(indexedVolumeCount: 2), for: Self.host)
            #expect(stamped.contains("# Corpus: counts cover only the 2 volumes indexed on this device"))

            // The link counts what Search lists for the parameters it opens.
            let parameters = AnalyticsSearchHandoff.parameters(term: "treaty", axis: .byYear, startYear: 1861,
                                                               endYear: 1992, yearsNarrowed: false,
                                                               scopeVolumeIds: nil)
            let match = try await AnalyticsSearchHandoff.match(
                for: parameters, in: SearchService(fts5Store: store, pipeline: pipeline))
            #expect(match.count == 3)
            #expect(match.volumeCounts == [2, 1])
            #expect(CorpusDispersion.make(volumeCounts: match.volumeCounts, indexedVolumeCount: 2)?.volumes == 2)
        }
    }

    // MARK: - The ranking labels

    @Test("A ranking's shared names are told apart, and a unique one is left as it is")
    func rankingLabels() {
        let labels = disambiguatedRankingLabels([
            (id: "v1/d1", name: "Memorandum of Conversation", shortSuffix: "d1"),
            (id: "v2/d1", name: "Memorandum of Conversation", shortSuffix: "d1"),
            (id: "v1/d2", name: "Editorial Note", shortSuffix: "d2"),
        ])
        #expect(labels["v1/d2"] == "Editorial Note")
        #expect(labels["v1/d1"] == "Memorandum of Conversation · v1/d1")
        #expect(labels["v2/d1"] == "Memorandum of Conversation · v2/d1")
    }
}
