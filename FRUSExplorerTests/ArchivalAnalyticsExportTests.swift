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

    @Test("Cited Over Time carries the table, the export, and the Audio Graph descriptor (#832b)")
    func collectionTimelineIsAFullChart() throws {
        // It was the one chart in the archival family with none of the three. The scan is on the
        // wiring rather than on rendered output because each piece is a single call that a later
        // edit can drop silently: the chart still draws, and nothing fails.
        let source = try Self.source("SourceExplorer/CollectionDetailView.swift")
        #expect(source.contains("timelineInspector = timelineTable"),
                "the \"View as table\" button no longer opens the inspector")
        #expect(source.contains("AnalyticsSectionExportControl("),
                "the chart offers no export")
        #expect(source.contains("ArchivalAnalyticsExport.collectionTimeline("), """
            The CSV must carry the collection-timeline methods statement. The generic archival \
            base caveat alone would head a series-wide volume count with a statement about \
            document source notes and say nothing about which population the bars count.
            """)
        #expect(source.contains(".axChartDescriptor(inspector: timelineTable"), """
            Without the descriptor the chart is one opaque element to VoiceOver — the gap #268 \
            closed everywhere SeriesChartCard reaches, which this chart deliberately does not.
            """)
    }

    @Test("Cited Over Time's sheets are anchored on the List, not on its Section")
    func collectionTimelineSheetsAreAnchoredOnce() throws {
        // A presentation modifier inside a Section (or a Group) mounts once per child. Both of
        // this chart's presentations must sit on the outermost List, which is where the
        // navigation title is — every Section builder is below the first `// MARK:`.
        let source = try Self.source("SourceExplorer/CollectionDetailView.swift")
        let inspectorSheet = try #require(source.range(of: ".sheet(item: $timelineInspector)"))
        let exportBox = try #require(source.range(of: ".seriesExportPresentation(timelineExportBox)"))
        let firstSectionBuilder = try #require(source.range(of: "// MARK: - Overview"))
        #expect(inspectorSheet.upperBound < firstSectionBuilder.lowerBound,
                "the inspector sheet is anchored below a Section builder, so it mounts per row")
        #expect(exportBox.upperBound < firstSectionBuilder.lowerBound,
                "the export presentation is anchored below a Section builder")
    }

    @Test("Ranking rows open something, and the exported figure does not carry the hit test")
    func rankingRowsAreNavigable() throws {
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("func interactiveRankingChart("), """
            The tap-through must live on its own wrapper. Putting `.chartOverlay` inside \
            `rankingChart` would bake a hit-test region into the rasterised figure export.
            """)
        #expect(source.contains("interactiveRankingChart(ranking, data: data)"),
                "the screen must mount the interactive chart, not the bare one")
        // The interactive wrapper must be mounted EXACTLY once — on screen. A second call site
        // means it reached the figure exporter, which renders the same chart body into a PNG.
        let interactiveCalls = source.components(separatedBy: "interactiveRankingChart(").count - 1
        #expect(interactiveCalls == 2, """
            `interactiveRankingChart` appears \(interactiveCalls) times (its declaration plus \
            call sites). Exactly one call site is expected: the on-screen chart.
            """)
        #expect(source.contains("private func open(_ row: ArchivalRankingRow"),
                "one routing function decides where a row goes")
    }

    @Test("The uncapped table exists, lifts the cap, and exports what it shows")
    func everyUnitIsReachable() throws {
        let view = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(view.contains("showAllUnitsButton("), "no way out of the 12-row cap")
        #expect(view.contains("ArchivalAllUnitsSheet("), "the button opens nothing")

        let sheet = try Self.source("Analytics/ArchivalAllUnitsSheet.swift")
        #expect(sheet.contains("limit: .max"), """
            The sheet must ask for the uncapped ranking. Without the lifted limit it would draw \
            the same twelve rows under a title promising every unit.
            """)
        #expect(sheet.contains("AnalyticsSectionExportControl("), """
            #825(c) is "the export follows it": a CSV that still carried twelve rows while the \
            screen showed hundreds would be the same defect one layer down.
            """)
        #expect(sheet.contains("Text(row.label)"), """
            The uncapped list must draw the DISAMBIGUATED label. `disambiguate` appends the \
            repository to names carried by more than one record, and drawing `name` prints \
            "White House Central Files" six times in one band — six identical rows, each \
            opening a different collection.
            """)
        #expect(!sheet.contains("Text(row.name)"))
        #expect(sheet.contains("rowCapApplied: false"), """
            The uncapped table's methods statement must not blame a row cap for its shortfall: \
            it has no rows below a cap.
            """)
        #expect(view.contains("Task { @MainActor in open(row, data: data) }"), """
            Dismissing the all-units sheet and presenting the collection record in the SAME \
            state change drops the second presentation.
            """)
    }

    @Test("The uncapped export gets its own denominator sentence")
    func uncappedExportDoesNotBlameTheRowCap() {
        let capped = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 700, bandVolumeCount: 120,
            indexedVolumeCount: 5, noteCount: 59_973, shownValue: 5_655)
        let uncapped = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 700, bandVolumeCount: 120,
            indexedVolumeCount: 5, noteCount: 59_973, shownValue: 13_238,
            rowCapApplied: false)
        #expect(capped.extraCaveats.joined().contains("below the row cap"))
        #expect(!uncapped.extraCaveats.joined().contains("below the row cap"), """
            The uncapped table listed every unit the era reaches, so "a unit below the row cap" \
            names a population that does not exist in it.
            """)
        #expect(uncapped.extraCaveats.joined().contains("uncapped"))
    }

    @Test("The collection record's citing volumes open the volume (#825d)")
    func citingVolumesAreNavigable() throws {
        let source = try Self.source("SourceExplorer/CollectionDetailView.swift")
        #expect(source.contains("openVolume(volumeId)"), """
            These rows were inert from the section's first commit while the sibling list in \
            VolumeSourcesView, showing the same volumes for the same collection, has been \
            navigable since the UI audit that recorded "the rows used to be dead ends".
            """)
        #expect(source.contains("appState.openBrowseVolume(volumeId, from: sceneID)"),
                "navigation must go through the hand-off both platforms consume")
        // The cap and its disclosure are pinned by CollectionRelationsTests; this only checks
        // that making the rows navigable did not displace them.
        #expect(source.contains("CollectionRelations.previewRowCap"))
    }

    @Test("Network and Flows can open a collection's own record (#825b)")
    func networkAndFlowsOpenCollections() throws {
        // Both surfaces already RESOLVED an AuthorityCollectionRecord to offer Archival
        // Neighbors; neither offered the record itself. That matters most for a reader with few
        // volumes indexed, because Neighbors reads the LOCAL index and answers honestly-empty,
        // leaving the dock with no route at all to what the app knows corpus-wide.
        for relative in ["Analytics/ArchivalNetworkView.swift",
                         "Analytics/ArchivalFlowsView.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("onOpenCollection(record)"),
                    "\(relative) resolves a record but still offers no way to open it")
            #expect(source.contains("let onOpenCollection: (AuthorityCollectionRecord) -> Void"),
                    "\(relative) must take the action from its host, not present it itself")
        }
        let host = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(host.components(separatedBy: "onOpenCollection: { collectionDetail = $0 }")
                    .count - 1 == 2,
                "both modes must be wired to the host's collection-detail presentation")
    }

    @Test("The surface is addressable, and the bare initializer still works (#825e)")
    func archivalAnalyticsIsAddressable() throws {
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains(
            "init(mode: ArchivalAnalyticsMode = .collections, focusCollectionId: String? = nil)"),
                """
                Every parameter must be defaulted: both existing call sites use \
                `ArchivalAnalyticsView()`, and one of them is pinned by a source-scan test in \
                ArchivalLibraryQueryTests.
                """)
        #expect(source.contains("_mode = State(initialValue: mode)"), """
            The mode is @State seeded by the initializer. Assigning it as a plain property would \
            reset the reader's own mode switch on every re-render.
            """)
        let network = try Self.source("Analytics/ArchivalNetworkView.swift")
        #expect(network.contains("guard !hasSeededFocus else { return }"), """
            The seed must apply once. Network re-appears whenever the mode picker returns to it, \
            and re-seeding would throw away the focus the reader chose.
            """)
    }

    @Test("Opening a collection is withheld when there is no AppState to give it")
    func collectionDetailIsGuardedOnAppState() throws {
        // `CollectionDetailView` declares a NON-optional `@Environment(AppState.self)`, and that
        // traps on DECLARATION rather than on first use. This surface holds AppState optionally
        // on purpose — its whole defensive pattern is to degrade to an empty state — so
        // presenting the detail unguarded would crash exactly the configuration the optional
        // exists for.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("if let appState {\n                CollectionDetailSheet("),
                "the detail sheet must be withheld rather than presented without an AppState")
        #expect(source.contains("guard appState != nil, let record = data.record(forId: row.id)"),
                "a row must not set a detail target it cannot present")
    }

    @Test("The chart says it can be tapped, and names the route that works without tapping")
    func rankingAdvertisesItsTapTarget() throws {
        // A `chartOverlay` tap is not an accessibility element, so an unannounced tap target is
        // both undiscoverable and unreachable by VoiceOver. Two other charts in this app pair
        // the same overlay with a hint; this one names the list as the alternative route.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("private func drillInHint("))
        #expect(source.contains("archival.ranking.drillIn.collections"))
        #expect(source.contains("archival.ranking.drillIn.classes"))
        // The sub-numbers disclosure is GONE, and its absence is the assertion: #841 made the
        // query follow the fold, so a folded row's documents are now exactly its own family and
        // a sentence warning otherwise would be false. ClassFamilyDefinitionTests holds the
        // guarantee that replaced it.
        #expect(!source.contains("include its sub-numbers"), """
            The screen still warns that a grouped row's documents include its sub-numbers. Since \
            #841 that is not true, and a stale caveat is worse than none: it tells a reader the \
            number in front of them is wrong when it is right.
            """)
    }

    @Test("A collection row's hand-off can close the host that presented it (#825d)")
    func navigatingAwayClosesThePresentingHost() throws {
        let detail = try Self.source("SourceExplorer/CollectionDetailView.swift")
        #expect(detail.contains("var onNavigateAway: (() -> Void)?"))
        #expect(detail.contains("onNavigateAway?()"), "the hook must actually fire")
        let host = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(host.contains(".onNavigateAwayFromCollection {"), """
            On iOS the analytics surface is itself a sheet, so a hand-off to the Browse tab lands \
            underneath it: dismissing only the collection record leaves the reader looking at \
            the analytics sheet, with nothing appearing to have happened.
            """)
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
