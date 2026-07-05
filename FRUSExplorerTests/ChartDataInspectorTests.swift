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

// MARK: - ChartDataInspectorTests

/// Tests for the Series-dashboard chart table inspector (Analytics SA): the pure
/// per-chart adapters that map (range-filtered) chart data into a
/// `ChartInspectorData`, plus the CSV serialisation. Verifies column headers, row
/// counts matching the filtered input, comma-free year cells, percent-formatted
/// share cells, and correct CSV joining with quoting. No SwiftUI is instantiated.
///
/// Version history:
///   1.0 — Analytics SA (chart table inspector): initial implementation
struct ChartDataInspectorTests {

    // MARK: - Fixtures

    /// Builds a manifest entry with just the fields the production/geography data
    /// read (date range + publication date + tags); all others neutral.
    private func entry(
        id: String,
        earliest: String?,
        latest: String?,
        publication: String?,
        tags: [String] = []
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id,
            filename: "\(id).xml",
            subseries: "1969-76",
            title: "Title \(id)",
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: publication,
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: 0,
            tags: tags
        )
    }

    // MARK: - Time-series adapter with a narrowed range (SA-1 cumulative)

    @Test("Cumulative table: headers, filtered row count, comma-free years")
    func cumulativeTableFilteredByRange() {
        // Print years spanning 1900…2020, one volume each.
        let entries = [
            entry(id: "v1900", earliest: "1899", latest: "1899", publication: "1900"),
            entry(id: "v1950", earliest: "1949", latest: "1949", publication: "1950"),
            entry(id: "v2000", earliest: "1999", latest: "1999", publication: "2000"),
            entry(id: "v2020", earliest: "2019", latest: "2019", publication: "2020"),
        ]
        let data = SeriesProductionData(entries: entries)

        // Narrow to 1940…2005 → keeps the 1950 and 2000 print years only.
        let filtered = data.cumulativeByPrintYear(in: 1940...2005)
        #expect(filtered.count == 2)

        let table = ChartInspectorAdapters.cumulativeTable(filtered)
        #expect(table.id == "sa1.cumulative")
        #expect(table.columns == ["Print year", "Cumulative volumes"])
        // Row count matches the filtered input exactly.
        #expect(table.rows.count == filtered.count)
        // Year cell has no comma grouping (1950, not 1,950).
        #expect(table.rows.first?.cells.first == "1950")
        #expect(table.rows.allSatisfy { !($0.cells.first?.contains(",") ?? true) })
        // Every row has one cell per column.
        #expect(table.rows.allSatisfy { $0.cells.count == table.columns.count })
    }

    @Test("Lag table tracks the filtered lag points")
    func lagTableFiltered() {
        let entries = [
            entry(id: "vA", earliest: "1930", latest: "1935", publication: "1960"),
            entry(id: "vB", earliest: "1970", latest: "1975", publication: "2005"),
        ]
        let data = SeriesProductionData(entries: entries)
        // Publication-year filter 1950…1970 keeps only vA (pub 1960).
        let filtered = data.lagPoints(in: 1950...1970)
        #expect(filtered.count == 1)

        let table = ChartInspectorAdapters.lagTable(filtered)
        #expect(table.columns == [
            "Volume", "Publication year", "Latest document year", "Lag (years)", "Era",
        ])
        #expect(table.rows.count == 1)
        let cells = table.rows[0].cells
        #expect(cells[0] == "vA")
        #expect(cells[1] == "1960")            // no comma
        #expect(cells[2] == "1935")
        #expect(cells[3] == "25")              // 1960 − 1935
        #expect(!cells[1].contains(","))
    }

    // MARK: - Categorical adapter (SA-2 region totals)

    @Test("Region totals table: headers, row count, plain counts")
    func regionTotalsTable() {
        let regions: [String: GeographicRegion] = [
            "france": .europe,
            "japan": .eastAsiaPacific,
            "brazil": .westernHemisphere,
        ]
        let entries = [
            entry(id: "v1", earliest: "1940", latest: "1945", publication: "1960", tags: ["france", "japan"]),
            entry(id: "v2", earliest: "1950", latest: "1955", publication: "1970", tags: ["france", "brazil"]),
        ]
        let data = SeriesGeographyData(entries: entries, placeRegions: regions)

        let table = ChartInspectorAdapters.regionTotalsTable(data.regionTotals)
        #expect(table.id == "sa2.regionTotals")
        #expect(table.columns == ["Region", "Volumes"])
        // One row per region present (Europe, East Asia & Pacific, Western Hemisphere).
        #expect(table.rows.count == data.regionTotals.count)
        #expect(table.rows.count == 3)
        // Europe touched by both volumes → count 2, plain integer.
        let europeRow = table.rows.first { $0.cells.first == GeographicRegion.europe.displayName }
        #expect(europeRow?.cells[1] == "2")
    }

    // MARK: - Share-based adapter (SA-3 provenance mix)

    @Test("Provenance mix table: percent-formatted share cells")
    func provenanceMixSharePercent() {
        // One decade (1940), 3:1 split between two categories → 75% / 25%.
        let index = SourceProvenanceIndex(
            schemaVersion: 1,
            generated: "2026-07-04",
            totalSourceNotes: 4,
            volumesCovered: 1,
            categories: SourceProvenanceCategory.allCases.map(\.rawValue),
            byDecade: [
                DecadeProvenance(
                    decade: 1940,
                    totalNotes: 4,
                    volumeCount: 1,
                    counts: [
                        SourceProvenanceCategory.centralDecimalFile.rawValue: 3,
                        SourceProvenanceCategory.lotFile.rawValue: 1,
                    ]
                )
            ]
        )
        let data = SourceProvenanceData(index: index)
        let filtered = data.shareByDecade(in: 1900...1993)
        #expect(filtered.count == 2)

        let table = ChartInspectorAdapters.provenanceMixTable(filtered)
        #expect(table.columns == ["Coverage decade", "Provenance", "Share"])
        #expect(table.rows.count == filtered.count)
        // Decade cell has no comma.
        #expect(table.rows.first?.cells.first == "1940")
        // Share cells are percents ending in "%".
        let shareCells = table.rows.map { $0.cells[2] }
        #expect(shareCells.allSatisfy { $0.contains("%") })
        #expect(shareCells.contains("75.0%"))
        #expect(shareCells.contains("25.0%"))
    }

    // MARK: - Formatting helpers

    @Test("plain() suppresses comma grouping")
    func plainNoCommas() {
        #expect(ChartInspectorAdapters.plain(1950) == "1950")
        #expect(ChartInspectorAdapters.plain(2026) == "2026")
        #expect(!ChartInspectorAdapters.plain(12345).contains(","))
    }

    @Test("percent() renders one-decimal percents")
    func percentFormat() {
        #expect(ChartInspectorAdapters.percent(0.423) == "42.3%")
        #expect(ChartInspectorAdapters.percent(1.0) == "100.0%")
        #expect(ChartInspectorAdapters.percent(0.0) == "0.0%")
    }

    // MARK: - CSV serialisation

    @Test("CSV joins header + rows, quoting cells with commas")
    func csvSerialisation() {
        let data = ChartInspectorData(
            id: "test",
            title: "T",
            columns: ["Country", "Volumes"],
            rowCells: [
                ["France", "12"],
                ["Korea, Republic of", "3"],   // embedded comma → must be quoted
            ]
        )
        let csv = data.csv
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.count == 3)                       // header + 2 rows
        #expect(lines[0] == "Country,Volumes")
        #expect(lines[1] == "France,12")
        #expect(lines[2] == "\"Korea, Republic of\",3") // comma-bearing cell quoted
    }

    @Test("CSV doubles embedded quotes")
    func csvQuoteEscaping() {
        let data = ChartInspectorData(
            id: "test",
            title: "T",
            columns: ["Label"],
            rowCells: [["He said \"hi\""]]
        )
        let csv = data.csv
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines[1] == "\"He said \"\"hi\"\"\"")
    }

    @Test("ChartInspectorData indexes rows positionally")
    func rowIdentity() {
        let data = ChartInspectorData(
            id: "test",
            title: "T",
            columns: ["A"],
            rowCells: [["x"], ["y"], ["z"]]
        )
        #expect(data.rows.map(\.id) == [0, 1, 2])
        #expect(data.rows.map { $0.cells[0] } == ["x", "y", "z"])
    }
}
