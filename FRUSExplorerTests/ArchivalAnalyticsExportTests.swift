// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ArchivalAnalyticsExportTests

/// The D3 provenance statements the archival surfaces stamp on their exports (#787).
///
/// Version history:
///   1.0 — Session 2026-08-09: #787
@Suite("Archival analytics — export provenance")
struct ArchivalAnalyticsExportTests {

    private func profile(noteCount: Int = 1_200, volumeCount: Int = 12) -> ArchivalLibraryProfile {
        ArchivalLibraryProfile(
            noteCount: noteCount, volumeCount: volumeCount,
            composition: [], bands: [], collections: [],
            centralFileNoteCount: 300, unresolvedCollectionNoteCount: 40)
    }

    private func flowsData(footnoteShare: Double = 0.953,
                           sameUnit: Int = 900) -> ArchivalFlowsData {
        ArchivalFlowsData(
            focus: nil, focusCategory: nil, endpoints: [], allEndpoints: [],
            totalReferences: 100, sameUnitReferences: sameUnit, topPairs: [],
            footnoteShare: footnoteShare, volumesWithEdges: 254, volumesScanned: 552,
            classBetweenReferences: 4_663, classBetweenPairs: 2_730)
    }

    // MARK: - No figure claims a dating rule it never applied

    @Test("Not one archival export claims to have placed documents on a timeline")
    func nothingAppliesDocumentDating() {
        // The word cloud set this precedent for exactly this reason: printing "each document is
        // placed at its TEI <date>…" above a table that never read a date is a methods statement
        // about work the export did not do — worse than omitting one, because a reader cannot
        // tell a boilerplate caveat from a true one. Nothing here reads a document date: the era
        // comes from the VOLUME's coverage span and the counts are of source notes.
        let statements = [
            ArchivalAnalyticsExport.ranking(
                band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
                hiddenUmbrella: nil, unitsReached: 10, bandVolumeCount: 120,
                indexedVolumeCount: 5),
            ArchivalAnalyticsExport.collectionTimeline(collectionName: "C", eraCount: 4,
                                                       indexedVolumeCount: 5),
            ArchivalAnalyticsExport.library(title: "T", axisLabel: "A", profile: profile(),
                                            indexedVolumeCount: 5, corpusVolumeCount: 552),
            ArchivalAnalyticsExport.network(focusName: "F", measure: .sharedVolumes, drawn: 6,
                                            aboveThreshold: 20, partnersTotal: 40,
                                            indexedVolumeCount: 5),
            ArchivalAnalyticsExport.flows(title: "T", axisLabel: "A", data: flowsData(),
                                          indexedVolumeCount: 5),
        ]
        for statement in statements {
            #expect(!statement.appliesDocumentDating,
                    "\(statement.figureTitle) claims a dating rule it never applied")
        }
        #expect(statements.count == 5, "every archival provenance builder must be in this sweep")
    }

    // MARK: - The collection timeline's statement (#832b)

    @Test("A collection timeline export says it is series-wide, counts volumes, and names its buckets")
    func collectionTimelineStatesItsScope() {
        let provenance = ArchivalAnalyticsExport.collectionTimeline(
            collectionName: "NSC Files", eraCount: 4, indexedVolumeCount: 3)
        #expect(provenance.figureTitle.contains("NSC Files"))
        #expect(provenance.scopeLabel == "NSC Files")
        #expect(provenance.countingUnit == "Volumes", """
            The bars count citing volumes. A CSV headed "Documents" over volume counts is the \
            weight confusion this whole caveat block exists to prevent.
            """)
        let caveats = provenance.extraCaveats.joined(separator: " ")
        #expect(caveats.contains(ArchivalAnalyticsExport.baseCaveat), """
            Every archival export carries the parsed-from-source-notes statement.
            """)
        // The three claims a reader of this CSV alone cannot check for themselves.
        #expect(caveats.contains("not this device's library"), """
            The chart is corpus-wide; a reader who assumes it reflects their own library would \
            read a partial download as a gap in the record.
            """)
        #expect(caveats.contains("4 eras"))
        #expect(caveats.lowercased().contains("subseries"), """
            The buckets are FRUS's own subseries, not decades — the distinction the era table \
            exists for.
            """)
    }

    // MARK: - The ranking states what it withheld

    @Test("A ranking that hid the umbrella says so, with the number")
    func umbrellaWithholdingIsStated() {
        let hidden = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: 12_060, unitsReached: 749, bandVolumeCount: 120,
            indexedVolumeCount: 5)
        let text = hidden.extraCaveats.joined(separator: " ")
        #expect(text.contains("12,060") || text.contains("12060"), """
            The withheld figure is missing from the caveats: \(hidden.extraCaveats). A ranking \
            that omits its largest member without saying so reads as a complete ranking.
            """)

        let nothingHidden = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[0], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 131, bandVolumeCount: 261, indexedVolumeCount: 5)
        #expect(!nothingHidden.extraCaveats.contains { $0.contains("Withheld") }, """
            A withholding caveat appeared for a band the umbrella contributes nothing to. It \
            supplies no documents before 1948, so a fixed sentence would be wrong in three bands \
            of five.
            """)
    }

    @Test("Every ranking export carries the weights-count-different-populations caveat")
    func weightCaveatIsAlwaysPresent() {
        for weight in ArchivalWeight.allCases {
            for lens in ArchivalUnitLens.allCases {
                let statement = ArchivalAnalyticsExport.ranking(
                    band: ArchivalEraBand.all[2], lens: lens, weight: weight,
                    hiddenUmbrella: nil, unitsReached: 5, bandVolumeCount: 64,
                    indexedVolumeCount: 5)
                #expect(statement.extraCaveats.contains(ArchivalAnalyticsExport.weightCaveat),
                        "\(lens.title)/\(weight.title) omits the weight caveat")
                #expect(statement.countingUnit == weight.title,
                        "the unit is a fact about every figure and must be stated")
            }
        }
    }

    // MARK: - Flows leads with the sentence it owes

    @Test("The Flows export leads with the footnote share, computed rather than written")
    func flowsLeadsWithTheFootnoteShare() {
        let statement = ArchivalAnalyticsExport.flows(
            title: "T", axisLabel: "A", data: flowsData(footnoteShare: 0.42),
            indexedVolumeCount: 5)
        let first = statement.extraCaveats.first ?? ""
        #expect(first.contains("42"), """
            The leading caveat is \(statement.extraCaveats.first ?? "none"). It must quote the \
            share the data actually reports — hard-coding 95.3% would survive a regeneration \
            that changed it.
            """)
        #expect(first.contains("footnotes"))
    }

    @Test("The Flows export states the same-unit exclusion only when there is one")
    func sameUnitExclusionIsConditional() {
        let excluded = ArchivalAnalyticsExport.flows(
            title: "T", axisLabel: "A", data: flowsData(sameUnit: 900), indexedVolumeCount: 5)
        #expect(excluded.extraCaveats.contains { $0.contains("900") })

        let none = ArchivalAnalyticsExport.flows(
            title: "T", axisLabel: "A", data: flowsData(sameUnit: 0), indexedVolumeCount: 5)
        #expect(!none.extraCaveats.contains { $0.contains("to itself") }, """
            An exclusion was disclosed for a collection that has none. A caveat that fires \
            unconditionally teaches a reader to skip caveats.
            """)
    }

    // MARK: - Your Library states both of its denominators

    @Test("A library export states the note total, the volume total, and that they differ")
    func libraryStatesItsDenominators() {
        let statement = ArchivalAnalyticsExport.library(
            title: "Where your documents come from", axisLabel: "A",
            profile: profile(noteCount: 1_200, volumeCount: 12),
            indexedVolumeCount: 14, corpusVolumeCount: 552)
        let text = statement.extraCaveats.joined(separator: " ")
        #expect(text.contains("1,200") || text.contains("1200"))
        #expect(text.contains("552"))
        #expect(statement.extraCaveats.contains { $0.contains("source note is not a document") },
                """
                The note-versus-document caveat is missing. That total is smaller than the \
                indexed document count, and a reader who takes it for a document count has been \
                misled by the export rather than the app.
                """)
        #expect(statement.indexedVolumeCount == 14)
    }

    // MARK: - End to end

    @Test("The delivered CSV carries the preamble above the table")
    func provenancedCSVCarriesItsMethod() {
        let table = ChartInspectorData(
            id: "archival.ranking", title: "Top collections by era",
            columns: ["Archival unit", "Custodian", "Documents"],
            rowCells: [["Whitman File", "Presidential libraries", "1643"]])
        let statement = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: 12_060, unitsReached: 749, bandVolumeCount: 120,
            indexedVolumeCount: 5)
        let csv = table.provenancedCSV(statement)

        #expect(csv.hasPrefix("#"), "the method must precede the numbers, not follow them")
        #expect(csv.contains("Whitman File"), "the table itself must survive the stamping")
        #expect(csv.contains("Archival unit,Custodian,Documents"))
        #expect(csv.contains(ArchivalAnalyticsExport.weightCaveat),
                "the weight caveat reaches the file")
        // The one line that must NOT be there.
        #expect(!csv.contains("TEI"), """
            The dating caveat reached an archival CSV. Nothing on this surface reads a document \
            date, so that sentence would describe work the export did not do.
            """)
    }
}

// MARK: - ArchivalExportWiringTests

/// Every archival card offers its export (#787).
///
/// A source-reading suite, because the failure it guards against is a control that was written
/// and never mounted — the class of defect this project has shipped before.
///
/// Version history:
///   1.0 — Session 2026-08-09: #787
@Suite("Archival analytics — export wiring")
struct ArchivalExportWiringTests {

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("All four chart cards mount an export control")
    func everyCardExports() throws {
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        // Call sites only: the helper's own declaration matches the same string.
        let mounted = source.split(separator: "\n")
            .filter { $0.contains("exportControl(table:") && !$0.contains("private func") }
            .count
        #expect(mounted == 4, """
            \(mounted) cards mount an export control; there are four: the ranking and the three \
            Your Library cards. The lifecycles card was removed in #832(c).
            """)
        // The slot exists on SeriesChartCard and was unused across the whole tree until now.
        #expect(source.contains("controls: {"),
                "the controls are in SeriesChartCard's slot, not floating above the card")
    }

    @Test("The collections list is a chart card now, so it has a table and an export")
    func collectionsListHasAnInspector() throws {
        // #765 shipped it as a bare VStack — the one card on this surface with neither a table
        // inspector nor an export, and the one whose rows a reader is most likely to want.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        let start = try #require(source.range(of: "private func libraryCollectionsCard"))
        let body = source[start.lowerBound...].prefix(2_000)
        #expect(body.contains("SeriesChartCard"))
        #expect(body.contains("libraryCollectionsTable"))
    }

    @Test("Both Canvas modes export data and deliberately not a figure")
    func canvasModesAreCSVOnly() throws {
        for relative in ["Analytics/ArchivalNetworkView.swift",
                         "Analytics/ArchivalFlowsView.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("AnalyticsSectionExportControl(exportCSV:"),
                    "\(relative) offers no export")
            #expect(!source.contains("exportFigure:"), """
                \(relative) offers a figure export. No `Canvas` in this app has ever been \
                rendered through AnalyticsFigureExporter; shipping that path unproven would be \
                worse than a CSV that works.
                """)
        }
    }

    @Test("The share sheet and the error alert are anchored outside the mode switch")
    func deliverySurfacesAreAnchoredOnce() throws {
        // The Group-modifier gotcha: a `.sheet` on a Group applies once per child, so anchoring
        // the share sheet inside the mode switch would mount four of them.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        let sheet = try #require(source.range(of: ".sheet(item: $exportShareItem)"))
        let switchRange = try #require(source.range(of: "switch mode {"))
        #expect(sheet.lowerBound > switchRange.upperBound,
                "the share sheet must be anchored on the outermost view")
        #expect(source.contains("analytics.export.error.title"),
                "an export failure must be surfaced, not swallowed")
    }
}
