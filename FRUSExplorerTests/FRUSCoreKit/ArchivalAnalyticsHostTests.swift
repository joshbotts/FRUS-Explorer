// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - ArchivalAnalyticsHostTests

/// The archival derivations as a host drives them (FRUS Explorer Light's S24c): the bundled tables loaded
/// by URL and passed as values, the network laid out with a caption measure of the host's own and its
/// labels placed by the graphs' rules, a graph narrowed as the app's group filter narrows one, the flows
/// over the indexes loaded by URL, the reader's library profile from the index's two grouped queries, and
/// an export stamped for the host.
///
/// The moved suites call the app's names, which read the app's stores (`ArchivalTestSupport.swift` gives
/// the package the same names). These call the kit's own forms with the tables a host loads, and hold
/// what they give to what the app's names give. Like every kit suite they import the kit `@testable`, so
/// they show what a host gets, not that it is public: FRUS Explorer Light's access proof, a file of its
/// server's that imports the kit without `@testable`, shows that.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): initial implementation, when the archival derivations
///          moved into the kit
@Suite("FRUSCoreKit — the archival derivations as a host drives them")
struct ArchivalAnalyticsHostTests {

    /// The bundled tables and the manifest, loaded by URL as a host loads them.
    struct Tables {
        let authority: CollectionAuthorityIndex
        let usage: CollectionUsageIndex
        let external: ExternalCitationIndex
        let flows: ProvenanceFlowIndex
        let labels: DecimalClassLabelTable
        let subjectNumeric: SubjectNumericLabelTable
        let entries: [VolumeManifestEntry]
    }

    /// Each table from its shipped file, through the kit's loader.
    static func tables() throws -> Tables {
        Tables(
            authority: try CollectionAuthorityIndex(contentsOf: try sourceExplorerShippedFile("collection-authority")),
            usage: try CollectionUsageIndex(contentsOf: try sourceExplorerShippedFile("collection-usage-index")),
            external: try ExternalCitationIndex(contentsOf: try sourceExplorerShippedFile("external-citation-index")),
            flows: try ProvenanceFlowIndex(contentsOf: try sourceExplorerShippedFile("provenance-flow-index")),
            labels: try DecimalClassLabelTable(contentsOf: try sourceExplorerShippedFile("decimal-class-labels")),
            subjectNumeric: try SubjectNumericLabelTable(
                contentsOf: try sourceExplorerShippedFile("subject-numeric-labels")),
            entries: try testManifestEntries())
    }

    /// A caption or label measure of a host's own: an estimate of its font, as a server without font
    /// metrics makes one, a little wider than the one the package's suites inject.
    static func hostSize(_ text: String, fontSize: CGFloat) -> CGSize {
        CGSize(width: (CGFloat(text.count) * fontSize * 0.57).rounded(.up),
               height: (fontSize * 1.25).rounded(.up))
    }

    @Test("Tables loaded by URL and passed as values rank every band, lens and weight as the app's stores do")
    func valuesRankAsTheStoresDo() throws {
        let tables = try Self.tables()
        let coverage = ArchivalVolumeCoverage.map(from: tables.entries)
        let host = ArchivalCollectionsData.make(
            authority: tables.authority.collections, usage: tables.usage, coverage: coverage,
            external: tables.external, labels: tables.labels, subjectNumericLabels: tables.subjectNumeric)
        let app = ArchivalCollectionsData.make(authority: CollectionAuthorityStore.shared?.collections ?? [],
                                               usage: CollectionUsageIndexStore.shared, coverage: coverage)
        var glossed = 0
        var leavesGlossed = 0
        for band in ArchivalEraBand.all {
            for lens in ArchivalUnitLens.allCases {
                for weight in ArchivalWeight.allCases {
                    let mine = host.ranking(band: band, lens: lens, weight: weight, hidingUmbrella: true,
                                            limit: .max)
                    let theirs = app.ranking(band: band, lens: lens, weight: weight, hidingUmbrella: true,
                                             limit: .max)
                    #expect(mine == theirs, "\(band.title), \(lens), \(weight)")
                    glossed += mine.rows.count { $0.gloss != nil }
                    leavesGlossed += mine.rows.flatMap(\.leaves).count { $0.gloss != nil }
                }
            }
        }
        // Both tables were read: decimal keys and subject-numeric families read in words, and their leaves.
        #expect(glossed > 0 && leavesGlossed > 0, "\(glossed) rows and \(leavesGlossed) leaves read in words")
        #expect(host.supportsDocumentWeight && host.supportsPointerWeight)
        #expect(host.volumesPlaced == app.volumesPlaced && host.authorityVolumeReach == app.authorityVolumeReach)
        #expect(host.volumesScanned == app.volumesScanned)
    }

    @Test("A host lays the network out with its own caption measure and places its labels clear of what the canvas draws")
    func aHostLaysOutAndLabelsTheNetwork() throws {
        let tables = try Self.tables()
        let records = tables.authority.collections
        let whitman = try #require(tables.authority.collections.first {
            $0.name == "Whitman File" && $0.repository == "Eisenhower Library"
        })
        #expect(tables.authority.record(id: whitman.id) == whitman)
        let graph = ArchivalNetworkBuilder.graph(focus: whitman, in: records, usage: tables.usage,
                                                 measure: .sharedVolumes, minimumRelativeStrength: 0.25,
                                                 expansion: .decimalClasses)
        #expect(graph.expansion == .decimalClasses && graph.classNodeCount > 0)

        let canvas = CGSize(width: 1000, height: 640)
        var measured: [String] = []
        let layout = ArchivalNetworkBuilder.layout(graph, in: canvas) { text in
            measured.append(text)
            return Self.hostSize(text, fontSize: ArchivalNetworkBuilder.captionPointSize)
        }
        // The layout asks the host to measure the four custodians' captions and the class box's.
        let captions = ArchivalRepositoryCategory.ordered.map(ArchivalNetworkBuilder.captionText(for:))
            + [ArchivalNetworkBuilder.hullCaptionText(for: .decimalClasses)]
        #expect(Set(measured) == Set(captions), "measured \(measured)")
        // The nodes sit where the app puts them: only the captions follow the measure.
        let app = ArchivalNetworkBuilder.layout(graph, in: canvas)
        #expect(layout.positions == app.positions && layout.ringRadii == app.ringRadii
                && layout.classHull == app.classHull)
        let bounds = CGRect(origin: .zero, size: canvas)
        for category in ArchivalRepositoryCategory.ordered {
            let caption = try #require(layout.captions[category])
            let size = Self.hostSize(caption.text, fontSize: ArchivalNetworkBuilder.captionPointSize)
            #expect(caption.rect.width == size.width + 2 * ArchivalNetworkBuilder.captionPadding.width)
            #expect(bounds.contains(caption.rect), "\(category) at \(caption.rect)")
        }
        let hullCaption = try #require(layout.hullCaption)
        #expect(hullCaption.text == ArchivalNetworkBuilder.hullCaptionText(for: .decimalClasses))

        // The labels, measured by the host, placed by the graphs' rules clear of the captions and the box.
        let drawn = ArchivalNetworkBuilder.drawnLabels(in: graph)
        let priority = ArchivalNetworkBuilder.labelPriority(graph, selectedNodeId: nil)
        var sizes: [String: CGSize] = [:]
        for id in priority {
            sizes[id] = Self.hostSize(drawn[id] ?? "", fontSize: id == whitman.id ? 9 : 8)
        }
        let requests = ArchivalNetworkBuilder.labelRequests(graph, layout: layout, selectedNodeId: nil, sizes: sizes)
        let obstacles = ArchivalNetworkBuilder.labelObstacles(layout)
        let placed = GraphNodeLabels.place(requests, avoiding: obstacles)
        #expect(placed[whitman.id] == GraphNodeLabels.labelRect(for: requests[0]), "the focus is always labelled")
        #expect(placed.count > 1, "placed \(placed.count) of \(requests.count)")
        let onObstacles = placed.filter { id, rect in
            id != whitman.id && obstacles.contains { ArchivalNetworkBuilder.rectGap(rect, $0) < GraphNodeLabels.clearance }
        }
        #expect(onObstacles.isEmpty, "\(onObstacles)")
        #expect(GraphNodeLabels.plate(for: requests, placed: placed)
                == GraphNodeLabels.plateRect(behind: GraphNodeLabels.labelRect(for: requests[0])))

        // Narrowed to one custodian, as the app's "Show only this group" narrows it: the graph is the host's.
        let category = try #require(graph.nodes.first?.category)
        let kept = graph.nodes.filter { $0.category == category }
        let narrowed = ArchivalNetworkGraph(
            focus: graph.focus, focusCategory: graph.focusCategory, nodes: kept,
            nodesAboveThreshold: graph.nodesAboveThreshold, partnersTotal: graph.partnersTotal,
            strongestMeasureValue: kept.map(\.measureValue).max() ?? graph.strongestMeasureValue,
            expandedUmbrella: graph.expandedUmbrella, expansion: graph.expansion)
        let narrowedLayout = ArchivalNetworkBuilder.layout(narrowed, in: canvas) {
            Self.hostSize($0, fontSize: ArchivalNetworkBuilder.captionPointSize)
        }
        #expect(Set(narrowedLayout.positions.keys) == Set(kept.map(\.id) + [whitman.id]))
        #expect(narrowed.nodes.allSatisfy { $0.category == category } && narrowed.withheldCount >= graph.withheldCount)
    }

    @Test("A graph of a host's own places its labels through the same rules")
    func aHostsOwnGraphPlacesItsLabels() {
        let requests = [
            GraphLabelRequest(id: "centre", center: CGPoint(x: 100, y: 100), radius: 20,
                              size: CGSize(width: 60, height: 10)),
            GraphLabelRequest(id: "partner", center: CGPoint(x: 100, y: 140), radius: 10, shape: .square,
                              size: CGSize(width: 60, height: 10)),
            // Its label would sit on the centre's, under and above alike, so it is not drawn.
            GraphLabelRequest(id: "crowded", center: CGPoint(x: 104, y: 100), radius: 2,
                              size: CGSize(width: 60, height: 10)),
        ]
        let placed = GraphNodeLabels.place(requests)
        #expect(placed["centre"] == GraphNodeLabels.labelRect(for: requests[0]))
        #expect(placed["partner"] == GraphNodeLabels.labelRect(for: requests[1]))
        #expect(placed["crowded"] == nil, "\(placed)")
        #expect(requests[1].shape == .square && requests[0].shape == .disc)
    }

    @Test("The flows over the indexes loaded by URL are the app's, on both layers")
    func flowsAsTheStoresGiveThem() throws {
        let tables = try Self.tables()
        let storedFlows = try #require(ProvenanceFlowIndexStore.shared)
        let storedAuthority = try #require(CollectionAuthorityStore.shared)
        #expect(ArchivalFlowsData.corpusWide(index: tables.flows, authority: tables.authority)
                == ArchivalFlowsData.corpusWide(index: storedFlows, authority: storedAuthority))
        let candidates = ArchivalFlowsData.focusCandidates(index: tables.flows, authority: tables.authority)
        let focus = try #require(candidates.first?.record)
        for direction in ArchivalFlowDirection.allCases {
            #expect(ArchivalFlowsData.focused(on: focus, direction: direction, index: tables.flows,
                                              authority: tables.authority)
                    == ArchivalFlowsData.focused(on: focus, direction: direction, index: storedFlows,
                                                 authority: storedAuthority))
        }
        let entriesById = Dictionary(uniqueKeysWithValues: tables.entries.map { ($0.volumeId, $0) })
        let unprinted = ArchivalFlowsData.corpusWideExternal(index: tables.external, authority: tables.authority,
                                                             entriesById: entriesById)
        #expect(unprinted.layer == .toUnprinted && !unprinted.topPairs.isEmpty)
        #expect(unprinted.externalFacts?.eraSpan != nil, "the unprinted layer states the span the manifest gives")
        #expect(!ArchivalFlowsData.externalFocusCandidates(index: tables.external, authority: tables.authority).isEmpty)
    }

    @Test("The reader's library profile, from the rows the index's two grouped queries return")
    func theLibraryProfileFromTheIndexRows() throws {
        let tables = try Self.tables()
        let coverage = ArchivalVolumeCoverage.map(from: tables.entries)
        let volume = try #require(coverage.keys.sorted().first)
        // A lot record the stored lot key resolves to, as the authority's first lookup step resolves it.
        let lot = try #require(tables.authority.collections.first { record in
            record.lotFileNorm.map { "lot:" + $0 } == record.id
        })
        let profile = ArchivalLibraryProfile.make(
            groups: [IndexingPipeline.ArchivalLibraryGroup(volumeId: volume, citationEra: "lot_file",
                                                           repository: "Department of State", documentCount: 4),
                     IndexingPipeline.ArchivalLibraryGroup(volumeId: volume, citationEra: "decimal",
                                                           repository: "Department of State", documentCount: 3)],
            collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: lot.lotFileNorm, repository: nil, seriesName: nil, documentCount: 4)],
            coverage: coverage, authority: tables.authority)
        #expect(profile.noteCount == 7 && profile.volumeCount == 1)
        #expect(profile.centralFileNoteCount == 3 && profile.unresolvedCollectionNoteCount == 0)
        #expect(profile.collections.map(\.record.id) == [lot.id] && profile.collections.first?.documentCount == 4)
        #expect(profile.bands.count == 1 && profile.bands.first?.documentCount == 7)
        #expect(profile.composition.map(\.documentCount) == [4, 3])
    }

    @Test("An export is stamped for the host: its version, and the archival statement's caveats")
    func anExportStampedForAHost() {
        let host = AnalyticsProvenance.Host(appVersion: "Light 1.0", locale: Locale(identifier: "en_US"),
                                            calendar: Calendar(identifier: .gregorian),
                                            timeZone: TimeZone(secondsFromGMT: 0) ?? .current)
        let statement = ArchivalAnalyticsExport.ranking(
            band: ArchivalEraBand.all[1], lens: .namedCollections, weight: .documents, hiddenUmbrella: 12_060,
            unitsReached: 749, bandVolumeCount: 120, indexedVolumeCount: 553)
        let table = ChartInspectorData(id: "archival.ranking", title: "Top collections by era",
                                       columns: ["Archival unit", "Documents"],
                                       rowCells: [["Whitman File", "1643"]])
        let csv = table.provenancedCSV(statement, for: host)
        #expect(csv.hasPrefix("#"), "the method precedes the numbers")
        #expect(csv.contains("Light 1.0"), "the host's version is the one stamped")
        #expect(csv.contains(ArchivalAnalyticsExport.weightCaveat))
        #expect(csv.contains("Archival unit,Documents") && csv.contains("Whitman File"))
        #expect(!csv.contains("TEI"), "no archival figure claims a document's date")
    }
}
