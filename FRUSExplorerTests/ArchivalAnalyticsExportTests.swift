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

    /// A pointers export must not carry the drawn-from methods statement.
    ///
    /// `baseCaveat` says the figures come from the source note on each published document and record
    /// where the editors drew documents from — a description of work a pointers export did not do.
    /// The precedent for branching rather than appending is `flows(...)` in the same file: two
    /// contradictory methods statements in one file is worse than one wrong one, because the reader
    /// trusts the first.
    @Test("A pointers export swaps the base caveat rather than appending a correction")
    func pointerExportSwapsItsBaseCaveat() {
        let pointers = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[0], lens: .namedCollections, weight: .unprintedPointers,
            hiddenUmbrella: nil, unitsReached: 12, bandVolumeCount: 40, indexedVolumeCount: 0)
        #expect(pointers.extraCaveats.contains(ArchivalAnalyticsExport.pointerBaseCaveat))
        #expect(!pointers.extraCaveats.contains(ArchivalAnalyticsExport.baseCaveat), """
            The pointers export carries the drawn-from methods statement, which describes work it \
            did not do.
            """)

        // And the printed weights keep theirs.
        for weight in [ArchivalWeight.documents, .volumes] {
            let printed = ArchivalAnalyticsExport.ranking(
                band: ArchivalEraBand.all[0], lens: .namedCollections, weight: weight,
                hiddenUmbrella: nil, unitsReached: 12, bandVolumeCount: 40, indexedVolumeCount: 0)
            #expect(printed.extraCaveats.contains(ArchivalAnalyticsExport.baseCaveat))
            #expect(!printed.extraCaveats.contains(ArchivalAnalyticsExport.pointerBaseCaveat),
                    "\(weight.title) carries the pointers methods statement")
        }
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
        #expect(view.contains("Task { @MainActor in open(row, data: presentation.data) }"), """
            Dismissing the all-units sheet and presenting the collection record in the SAME \
            state change drops the second presentation. `presentation.data` because the sheet \
            now holds a snapshot — the live derivation may be gone by the time this runs.
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
            "init(mode: ArchivalAnalyticsMode = .collections, focusCollectionId: String? = nil,"),
                """
                Every parameter must be defaulted: the macOS window scene still opens the surface \
                as `ArchivalAnalyticsView()`, and that call site is pinned by a source-scan test \
                in ArchivalLibraryQueryTests.
                """)
        #expect(source.contains("initialScope: ArchivalScopeRequest? = nil,"), """
            The iOS presenter consumes the hand-off before this view mounts, so a scope that can \
            only arrive through `pendingArchivalScope` cannot reach it there at all.
            """)
        #expect(source.contains("onNavigateAway: (() -> Void)? = nil) {"), """
            #835: a presenter that is ITSELF a sheet — the Research Guide — has to close behind \
            a hand-off, or it sits over the surface that just navigated.
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

    @Test("The scope reaches the label, the caveats, and the uncapped list (#827)")
    func exportsCarryTheScope() throws {
        let scoped = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[2], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 214, bandVolumeCount: 11,
            indexedVolumeCount: 5, noteCount: 8_124, shownValue: 1_616,
            scopeLabel: "Vietnam volumes")
        #expect(scoped.scopeLabel?.contains("Vietnam volumes") == true, """
            A CSV headed only with an era is read as the whole series' era, which is a different \
            and much larger population than a scoped one.
            """)
        let caveats = scoped.extraCaveats.joined(separator: " ")
        #expect(caveats.contains("only the volumes in"))
        #expect(caveats.contains("not narrowed to what this device has downloaded"), """
            The scope is over the SERIES, not the library. Without that sentence a reader would \
            reasonably assume a scoped figure reflects their own downloads.
            """)

        let unscoped = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[2], lens: .namedCollections, weight: .documents,
            hiddenUmbrella: nil, unitsReached: 214, bandVolumeCount: 64, indexedVolumeCount: 5)
        #expect(!unscoped.extraCaveats.joined().contains("only the volumes in"),
                "an unscoped export must not claim a scope")
    }

    @Test("Collections scopes over the series, never over the local index")
    func scopeIsCorpusWide() throws {
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("indexedVolumeIds: scopableVolumeIds"), """
            Passing `appState.indexedVolumeIds` here would silently answer a different question \
            for every reader: "the collections of the 1969–76 subseries" would mean whichever of \
            its volumes they happen to hold. This mode's derivation is the bundled corpus-wide \
            authority and is honest with nothing downloaded.
            """)
        #expect(source.contains("private var scopableVolumeIds: Set<String>"))
        #expect(source.contains("volumeCoverage(limitedTo: scopeVolumeIds)"), """
            The scope must be applied to the coverage map — the derivation's own input — so every \
            figure narrows together instead of one of them being filtered downstream.
            """)
    }

    @Test("Changing the scope actually rebuilds the derivation")
    func scopeChangeInvalidatesTheDerivation() throws {
        // THIS IS THE TEST #827 SHIPPED WITHOUT, and the bug it would have caught was total:
        // `loadCollections` early-returns while `collectionsData` is non-nil, and the load task
        // was NOT keyed on the scope — so picking a scope changed the chip and nothing else.
        // Every #827 test passed, because they drove `make()` directly or scanned for the
        // presence of `volumeCoverage(limitedTo:)`. Neither touches the view's lifecycle.
        //
        // All three parts are required and none is sufficient alone.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains(".task(id: scopeSignature) { await loadCollections() }"), """
            The load task must be KEYED on the scope. `.task` without an id runs once per \
            appearance, so with the early return in `loadCollections` a scope change would \
            leave the chart exactly as it was.
            """)
        #expect(source.contains("private var scopeSignature: String"), """
            The key must change when the LABEL changes too: two topics can select the same \
            volumes, and the chart's sentences name the label.
            """)
        // `setScope` must drop the derivation. Without it the keyed task re-runs and the early
        // return in `loadCollections` sends it straight back out.
        let setter = try #require(source.range(of: "private func setScope("))
        let setterBody = source[setter.lowerBound...].prefix(320)
        #expect(setterBody.contains("invalidateCollections()"), """
            setScope does not invalidate the derivation, so a keyed reload would early-return \
            and the chart would keep the previous scope's figures.
            """)
        // And the scope bar must write through the setter rather than around it.
        #expect(source.contains("set: { setScope($0, label: scopeLabel) }"))
        #expect(!source.contains("set: { scopeVolumeIds = $0 }"), """
            Assigning the scope state directly bypasses the invalidation — which is exactly how \
            the chip came to change without the chart changing.
            """)
    }

    @Test("A scope handed in from elsewhere is applied once, and an empty one is not a filter")
    func pendingScopeIsConsumedOnce() throws {
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("appState.pendingArchivalScope = nil"), """
            The hand-off must be CONSUMED. Left in place it would re-apply on every re-entry, \
            overriding a scope the reader has since changed.
            """)
        #expect(source.contains("guard !handoff.payload.volumeIds.isEmpty else { return }"), """
            A topic that matches no volume is a fact about the topic. Scoping to an empty set \
            would draw an empty chart under its name, which reads as a broken filter.
            """)
        #expect(source.contains("mode = .collections"),
                "the scope only means anything in the mode that has a scope")
    }

    @Test("The search facet panel's dead end becomes a door (#833)")
    func searchResultsOpenAnArchivalProfile() throws {
        let panel = try Self.source("../FRUSExplorer/Search/FacetPanelView.swift")
        #expect(panel.contains("facets.provenance.openProfile"))
        #expect(panel.contains("whole volumes, not the matches themselves"), """
            The distinction this copy must keep: the profile is of the VOLUMES the matches sit \
            in, not of the matches. A volume enters whole or not at all, and a reader who takes \
            it for a profile of their results would over-read every figure.
            """)
        // Withheld rather than inert when the host cannot present it.
        #expect(panel.contains("if let onOpenArchivalProfile, !facets.volumes.isEmpty"))
        for host in ["../FRUSExplorer/Search/SearchView.swift",
                     "../FRUSExplorer/App/SearchSheet.swift"] {
            let source = try Self.source(host)
            #expect(source.contains("openArchivalProfile(volumeIds: $0, query: $1)"),
                    "\(host) does not offer the door")
            #expect(source.contains("appState.openArchivalScope("),
                    "\(host) must route through the scene-addressed hand-off")
        }
    }

    @Test("A subject opens the archival profile of the volumes covering it (#833)")
    func subjectsOpenAnArchivalProfile() throws {
        let sheet = try Self.source("../FRUSExplorer/Browser/VolumeSubjectsView.swift")
        #expect(sheet.contains("appState.openArchivalScope("),
                "the subject sheet must offer the topic door")
        // The scope is the FULL covering set. The list above the button excludes the volume being
        // viewed, and reusing that array would drop one volume from every profile opened from a
        // volume page — a silent under-count no figure on the destination would reveal.
        #expect(sheet.contains("volumesBySubjectRef[subject.ref]"), """
            The scope must be every volume covering the subject. `otherVolumeIds` excludes the \
            volume in hand, so scoping to it would under-count by one on every volume-page open.
            """)
        #expect(!sheet.contains("volumeIds: otherVolumeIds"), """
            Scoping to the displayed list drops the current volume from the profile while the \
            button's own count includes it.
            """)
        #expect(sheet.contains("if coveringVolumeIds.count > 1"), """
            A one-volume "profile of volumes on this subject" is that volume's own profile under \
            a topic's name — the exact misreading the footer exists to prevent.
            """)
        // #833 requires the door to inherit the subject profile's own caveats, so the reader
        // is not handed a chart built on tags they were never told are machine-derived.
        #expect(sheet.contains("detected automatically, not editorial headings"), """
            The scope rests on automatically detected subject tags. A chart offered without that \
            clause presents a derived topic set as if it were an editorial subject heading.
            """)
        #expect(sheet.contains("not the documents about this subject inside them"), """
            The load-bearing sentence. The scope is whole volumes whose profile ranks the \
            subject; a reader will otherwise take the chart for the archives behind the \
            documents on the topic.
            """)
    }

    @Test("The iOS tab shell is the single presenter of Archival Analytics (#833)")
    func theHandoffHasAPresenterOniOS() throws {
        // WHY THIS EXISTS. Before #833 the ONLY iOS presenter of ArchivalAnalyticsView was a
        // private `@State` bool inside BrowserView. The search door therefore switched to the
        // Browse tab and nothing opened — a door that led nowhere, and no data-layer test could
        // see it, because the defect is entirely in which view owns the presentation.
        let shell = try Self.source("../FRUSExplorer/App/MainTabView.swift")
        #expect(shell.contains("$presentedArchivalScope"), "the shell must present the surface")
        #expect(shell.contains("ArchivalAnalyticsView(initialScope: handoff.payload)"), """
            The shell consumes the hand-off in order to decide whether to present at all, so the \
            payload has to travel through the initializer — by mount time the slot is empty.
            """)
        // The two-presenter arrangement is only safe because the shell declines while a sheet is
        // already up, leaving the mounted view to re-scope in place.
        #expect(shell.contains("guard presentedArchivalScope == nil else { return }"), """
            Without this the shell could present a SECOND archival sheet over one already open \
            when a scope arrives, and which presenter wins would depend on onChange ordering.
            """)
        let browser = try Self.source("../FRUSExplorer/Browser/BrowserView.swift")
        #expect(browser.contains("appState.openArchivalScope(.unscoped, from: sceneID)"), """
            Browse's own menu item must go through the same hand-off, or iOS has two presenters \
            of one surface and a scope can land in the one that is not on screen.
            """)
        #expect(!browser.contains("showArchivalAnalytics"),
                "the private presentation state must be gone, not merely unused")
    }

    @Test("A door that dismisses its own sheet hands off on the next turn (#833)")
    func doorsDoNotDismissAndPresentAtOnce() throws {
        // Dismissing one sheet and presenting another in the SAME state change drops the second.
        // Both iOS doors close a sheet (the facet panel; the subject sheet) and both land on a
        // sheet, so both have to hop. macOS lands on a window and does not.
        for (file, hint) in [("../FRUSExplorer/Search/SearchView.swift", "the facet panel"),
                             ("../FRUSExplorer/Browser/VolumeSubjectsView.swift",
                              "the subject sheet")] {
            let source = try Self.source(file)
            #expect(source.contains("Task { @MainActor in appState.openArchivalScope("), """
                \(hint) closes itself and opens a sheet; done in one state change the second \
                presentation is dropped and the door appears to do nothing.
                """)
        }
        // And the search door must no longer merely switch tabs — the shell hosts the sheet.
        let search = try Self.source("../FRUSExplorer/Search/SearchView.swift")
        #expect(!search.contains("appState.openTab(.browse, from: sceneID)\n    }"), """
            Switching to Browse was the old no-op: the surface's only presenter lived inside \
            that tab and nothing asked it to open.
            """)
    }

    @Test("Re-picking the scope that is already active still rebuilds (#833 review)")
    func idempotentRescopeStillReloads() throws {
        // The wedge this prevents was introduced BY the #827 fix and is total. `setScope` drops
        // the derivation; the only thing that rebuilds it is `.task(id: scopeSignature)`; and a
        // signature made only of the scope VALUE is unchanged when the reader taps the already-
        // checked "Whole corpus" row, re-picks the active administration, or uses the same door
        // twice for the same query. The chart then sits on its spinner for the life of the view —
        // and the scope chip is inside the `if let data` branch, so the control that could undo
        // it has vanished along with the data.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("@State private var scopeGeneration = 0"))
        #expect(source.contains(#""\(scopeGeneration)|\(scopeLabel ?? "")"#), """
            The generation must be IN the key. Dropping the data without moving the key is \
            exactly the wedge.
            """)
        #expect(source.contains("""
                private func invalidateCollections() {
                        collectionsData = nil
                        scopeGeneration += 1
                    }
            """.replacingOccurrences(of: "\n        ", with: "\n    ")) ||
                (source.contains("collectionsData = nil") && source.contains("scopeGeneration += 1")))
        // Every invalidation path goes through the one function — including the scope bar's own
        // `onChange`, which nils the data without passing through `setScope` at all.
        #expect(source.contains("onChange: { invalidateCollections() }"), """
            The scope bar's onChange nils the derivation directly. Left as a bare assignment it \
            is a second wedge with the same signature.
            """)
        #expect(!source.contains("onChange: { collectionsData = nil }"))
    }

    @Test("A superseded derivation cannot land on top of the scoped one (#833 review)")
    func staleLoadCannotOverwrite() throws {
        // `Task.detached` does not inherit cancellation and `Task.value` does not throw, so a
        // load `.task(id:)` has cancelled still finishes and still resumes past its `await`. The
        // macOS window reproduces the overlap on every scoped open: it mounts unscoped, starts a
        // corpus-wide build, then consumes the hand-off. An unconditional assignment lets the
        // UNSCOPED figures land last, under the scope's own name.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("let requested = scopeSignature"))
        #expect(source.contains("guard requested == scopeSignature else { return }"), """
            Without the re-check the chart can show corpus-wide numbers under a scope's label, \
            with nothing on screen indicating it.
            """)
        #expect(!source.contains("""
            collectionsData = await Task.detached(priority: .userInitiated) {
            """), "the assignment must not be the await itself")
    }

    @Test("The search door is reachable without opening the Volumes facet first (#833 review)")
    func theDoorDoesNotDependOnAnotherSection() throws {
        // Facet sections are computed lazily, one per disclosure. The door lives in Provenance but
        // is built from `facets.volumes`, so without this the button renders only for a reader who
        // happened to open Volumes first — and Provenance, the dead-end section this door exists
        // to open a way out of, would be the one hiding it.
        //
        // **Retargeted by #850, which moved where the rule is enforced rather than whether.** The
        // companion request used to live in the disclosure closure, which fires once; that is
        // exactly the shape #850 fixed, because a section outlives the search that filled it and
        // the door vanished with the data after any new search. The rule now lives in
        // `FacetPanelController.sectionsNeedingLoad(expanded:)`, which answers "what is open and
        // has no data" — so the door is rebuilt on recovery too, not only on first disclosure.
        //
        // The behavioural half is pinned in `FacetPanelControllerTests.provenancePullsVolumes`;
        // this keeps the structural half, so the rule cannot quietly move back into a one-shot.
        let panel = try Self.source("../FRUSExplorer/Search/FacetPanelView.swift")
        #expect(panel.contains("if wanted.contains(.provenance) { wanted.insert(.volumes) }"), """
            An open Provenance must also ask for the volume breakdown the door is made of. If this \
            moved again, point the assertion at its new home — do not delete it: the door renders \
            only for a reader who opened Volumes by hand without it.
            """)
        // And it must be derived from what is OPEN, not re-attached to the one-shot disclosure
        // that #850 removed.
        #expect(!panel.contains("if kind == .provenance { onDiscloseSection(.volumes) }"), """
            The companion request is back in the disclosure closure, which fires once — so after \
            any new search the archival door is missing until the reader collapses and re-opens \
            Provenance (#850).
            """)
    }

    @Test("A scope handed in from elsewhere moves the era band to match (#833 review)")
    func theDoorLandsOnAnEraTheScopeCovers() throws {
        // The band opens on 1948–1960 and is otherwise moved only by the reader. A subject like
        // Vietnamization selects volumes no part of that band covers, so the door would land on an
        // empty chart under the topic's name — which reads as "FRUS cites no archives for this",
        // not "wrong decade".
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains("private func moveToTheBandTheScopeLivesIn(_ ids: [String])"))
        #expect(source.contains("moveToTheBandTheScopeLivesIn(handoff.payload.volumeIds)"), """
            The hand-off path must move the band, or every post-1960 topic opens empty.
            """)
        #expect(source.contains("if initialScopeNeedsBand, let ids = scopeVolumeIds"), """
            The iOS path delivers the scope through the initializer, which has no manifest to \
            read — so the move has to happen on first appearance or iOS keeps the empty chart.
            """)
        // Applied to arriving scopes only: moving the band under a reader working the scope bar
        // would be a control changing itself while it is used.
        let barSetter = try #require(source.range(of: "private func setScope("))
        #expect(!source[barSetter.lowerBound...].prefix(340)
                    .contains("moveToTheBandTheScopeLivesIn"))
    }

    @Test("Two hand-off doc comments stayed with the types they document (#833 review)")
    func docCommentsWereNotOrphaned() throws {
        // Inserting a type or a function between a doc comment and its declaration silently
        // re-attributes the whole comment. Both happened in this change: `ArchivalScopeRequest`
        // landed inside `Handoff`'s comment, and `archivalSheet` inside the word-cloud consumer's.
        let appState = try Self.source("../FRUSExplorer/App/AppState.swift")
        let handoffDoc = try #require(appState.range(of:
            "/// There is intentionally **no** \"every window\" broadcast target"))
        let handoffDecl = try #require(appState.range(of: "struct Handoff<Payload"))
        let scopeDecl = try #require(appState.range(of: "struct ArchivalScopeRequest"))
        #expect(handoffDoc.lowerBound < handoffDecl.lowerBound
                && !(scopeDecl.lowerBound > handoffDoc.lowerBound
                     && scopeDecl.lowerBound < handoffDecl.lowerBound), """
            `Handoff`'s doc comment must sit directly above `Handoff`; with another type between \
            them the comment documents that type and `Handoff` has none.
            """)
        let shell = try Self.source("../FRUSExplorer/App/MainTabView.swift")
        let wcDoc = try #require(shell.range(of: "/// Adopts a pending word-cloud hand-off"))
        let wcDecl = try #require(shell.range(of: "private func consumePendingWordCloud()"))
        let between = shell[wcDoc.upperBound..<wcDecl.lowerBound]
        #expect(!between.contains("func ") && !between.contains("private "), """
            Nothing may sit between the word-cloud consumer's doc comment and the function it \
            documents — a declaration inserted there takes the whole comment with it.
            """)
    }

    @Test("The band a scope lands on is the one holding most of it (#833 review)")
    func bandChoiceIsMeasuredNotAsserted() throws {
        // A REAL test of the decision, not a source scan for the function's name. The first
        // version of this could have had the plurality, the tie-break and the empty case all
        // wrong and still passed, because it only checked that the call appeared.
        #expect(ArchivalEraBand.bandHoldingMost(of: [:]) == nil,
                "no coverage is no answer, not band zero")

        // Two volumes in 1969–1976 against one in 1948–1960: the plurality wins, and it is NOT
        // the band the surface opens on, which is the whole point.
        let seventies = ArchivalEraBand.bandHoldingMost(of: [
            "a": ArchivalVolumeCoverage(firstYear: 1969, lastYear: 1972),
            "b": ArchivalVolumeCoverage(firstYear: 1973, lastYear: 1976),
            "c": ArchivalVolumeCoverage(firstYear: 1950, lastYear: 1954),
        ])
        #expect(seventies?.startYear == 1969)
        #expect(seventies != ArchivalEraBand.all[1], """
            If the plurality band were also the default, this test could not tell a working \
            move from no move at all.
            """)

        // A tie goes to the EARLIER band. Named against the expectation: if ties resolved by
        // dictionary order the answer would vary between runs.
        let tied = ArchivalEraBand.bandHoldingMost(of: [
            "later": ArchivalVolumeCoverage(firstYear: 1970, lastYear: 1974),
            "earlier": ArchivalVolumeCoverage(firstYear: 1962, lastYear: 1966),
        ])
        #expect(tied?.startYear == 1961, "ties must resolve to the earlier band, deterministically")

        // Every band is reachable, so no scope can be sent somewhere it does not belong.
        for band in ArchivalEraBand.all {
            let midpoint = (band.startYear + band.endYear) / 2
            let chosen = ArchivalEraBand.bandHoldingMost(of: [
                "x": ArchivalVolumeCoverage(firstYear: midpoint, lastYear: midpoint),
            ])
            #expect(chosen == band, "a volume dated inside \(band.title) must select it")
        }
    }

    @Test("The iOS hand-off is observed, not merely consumable (#833 review)")
    func theShellActuallyObservesTheSlot() throws {
        // consumePendingArchivalScope could be perfect and never called. Deleting these two
        // observers leaves every other test on this branch green while every door opens nothing —
        // the exact regression #833 exists to fix, one level up.
        let shell = try Self.source("../FRUSExplorer/App/MainTabView.swift")
        #expect(shell.contains(".onChange(of: appState.pendingArchivalScope) { _, _ in consumePendingArchivalScope() }"), """
            Without the observer a scope produced while the shell is on screen is never adopted.
            """)
        #expect(shell.contains(".onAppear { consumePendingArchivalScope() }"), """
            Without the appear hook a scope produced before the shell exists is stranded in the \
            slot forever — it is never re-published, so no later change would deliver it.
            """)
        // And the producer must address the scene the shell actually answers to.
        let appState = try Self.source("../FRUSExplorer/App/AppState.swift")
        #expect(appState.contains("pendingArchivalScope = Handoff(target: .macArchivalAnalytics"),
                "macOS must address the singleton window")
        #expect(appState.contains("""
            pendingArchivalScope = Handoff(target: sceneID ?? SceneID("frus.sceneID.unreached"),
            """.trimmingCharacters(in: .whitespacesAndNewlines)), """
            iOS must address the PRODUCING scene, or an iPad opens the profile in every window.
            """)
    }

    @Test("The uncapped list survives a scope arriving underneath it (#833 review)")
    func allUnitsSheetIsSnapshotted() throws {
        // The sheet owns its only Done button. Reading the live derivation, it emptied whenever a
        // scope arrived from another window — on macOS leaving a window-modal sheet with no
        // dismiss control at all.
        let source = try Self.source("Analytics/ArchivalAnalyticsView.swift")
        #expect(source.contains(".sheet(item: $allUnits)"), """
            An `isPresented` sheet whose body is `if let data = collectionsData` goes blank the \
            moment the derivation is dropped, taking its Done button with it.
            """)
        #expect(source.contains("private struct ArchivalAllUnitsPresentation: Identifiable"))
        #expect(!source.contains(".sheet(isPresented: $showsAllUnits)"))
        // The snapshot carries the chart state too: the list says "same as the chart", and an
        // arriving scope now moves the band.
        for field in ["let band: ArchivalEraBand", "let lens: ArchivalUnitLens",
                      "let weight: ArchivalWeight", "let hidingUmbrella: Bool"] {
            #expect(source.contains(field), "the snapshot must capture \(field)")
        }
    }

    @Test("The search door names the query its facets describe (#833 review)")
    func theScopeLabelNamesTheExecutedQuery() throws {
        // Both hosts' query properties are LIVE text-field buffers — macOS documents its own as
        // such — so a reader who types a new term without committing it would get the OLD result
        // set's volumes under the NEW term's name.
        let panel = try Self.source("../FRUSExplorer/Search/FacetPanelView.swift")
        #expect(panel.contains("private(set) var loadedQuery: String"))
        #expect(panel.contains("onOpenArchivalProfile(ids, controller.loadedQuery)"))
        #expect(panel.contains("var onOpenArchivalProfile: (([String], String) -> Void)?"))
        for host in ["../FRUSExplorer/Search/SearchView.swift",
                     "../FRUSExplorer/App/SearchSheet.swift"] {
            let source = try Self.source(host)
            #expect(source.contains("openArchivalProfile(volumeIds: $0, query: $1)"),
                    "\(host) must take the label from the panel, not from its own text field")
            // Scoped to the door's own body: `vm.keywords` legitimately appears elsewhere in
            // these files, and a whole-file negative would forbid an unrelated feature.
            let door = try #require(source.range(of: "private func openArchivalProfile("))
            let body = source[door.lowerBound...].prefix(420)
            #expect(body.contains("let term = query.trimmingCharacters"), """
                The label must come from the handed-over query, not from a live text field.
                """)
        }
    }

    @Test("The door outlives an empty provenance breakdown (#833 review)")
    func theDoorIsNotHostedByTheRowsItIsNotMadeOf() throws {
        // The door is built from the result set's VOLUMES, not from this section's rows. Nested
        // in the non-empty branch it vanished exactly when the section had nothing to say — which
        // is when a reader most needs somewhere to go.
        let panel = try Self.source("../FRUSExplorer/Search/FacetPanelView.swift")
        let emptyBranch = try #require(panel.range(of: "facets.none"))
        let door = try #require(panel.range(of: "archivalProfileButton(facets)"))
        let caveat = try #require(panel.range(of: "provenanceCaveat(facets.provenanceCoverage)"))
        #expect(door.lowerBound > emptyBranch.lowerBound)
        #expect(door.lowerBound > caveat.lowerBound, """
            The door must sit outside the branch the caveat lives in, or an empty breakdown \
            takes it down with the rows.
            """)
        // Position alone is not the property — a row-count guard ON the door would restore the
        // defect while leaving the door exactly where it sits. The condition must be the section
        // kind and nothing else.
        let before = panel[..<door.lowerBound]
        let lastIf = try #require(before.range(of: "if kind == ", options: .backwards))
        let headerLine = before[lastIf.lowerBound...]
            .prefix { $0 != "\n" }
            .trimmingCharacters(in: .whitespaces)
        #expect(headerLine == "if kind == .provenance {", """
            The door's only condition may be the section it belongs to; found "\(headerLine)". \
            Any predicate over this section's ROWS re-couples it to a breakdown it is not made \
            of, which is the defect — and it would leave the door exactly where it sits, so \
            position alone does not pin this.
            """)
        #expect(panel.contains("facets.provenance.openProfile.preparing"), """
            The volume breakdown loads in the background, so the wait must be stated rather than \
            leaving a control to materialise seconds later.
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
