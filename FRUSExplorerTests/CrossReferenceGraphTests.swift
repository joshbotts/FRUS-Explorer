// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - Fixture Helpers

/// Builds a `CrossReferenceGraph` suitable for layout tests without a real database.
private func makeTestGraph(
    inboundCount: Int,
    outboundCount: Int,
    inboundVolumeIds: [String] = ["vol-src"],
    outboundVolumeIds: [String] = ["vol-tgt"],
    centralVolumeId: String = "vol1",
    centralDocumentId: String = "d0"
) -> CrossReferenceGraph {
    let centralKey = "\(centralVolumeId)/\(centralDocumentId)"
    var inboundEdges:  [CrossReferenceEdge] = []
    var outboundEdges: [CrossReferenceEdge] = []
    var meta: [String: CrossReferenceNodeMetadata] = [:]

    meta[centralKey] = CrossReferenceNodeMetadata(
        documentId: centralDocumentId, volumeId: centralVolumeId,
        documentNumber: "0", header: "Central Document", dateline: "Washington, 1969."
    )

    // Distribute inbound edges across the provided volume IDs
    for i in 0..<inboundCount {
        let vol = inboundVolumeIds[i % inboundVolumeIds.count]
        let doc = "d-in-\(i)"
        let key = "\(vol)/\(doc)"
        inboundEdges.append(CrossReferenceEdge(
            sourceDocumentId: doc, sourceVolumeId: vol,
            targetDocumentId: centralDocumentId, targetVolumeId: centralVolumeId,
            context: nil, referenceType: .footnote
        ))
        meta[key] = CrossReferenceNodeMetadata(
            documentId: doc, volumeId: vol,
            documentNumber: "\(i + 1)", header: "Source Document \(i + 1)", dateline: nil
        )
    }

    // Distribute outbound edges across the provided volume IDs
    for i in 0..<outboundCount {
        let vol = outboundVolumeIds[i % outboundVolumeIds.count]
        let doc = "d-out-\(i)"
        let key = "\(vol)/\(doc)"
        outboundEdges.append(CrossReferenceEdge(
            sourceDocumentId: centralDocumentId, sourceVolumeId: centralVolumeId,
            targetDocumentId: doc, targetVolumeId: vol,
            context: nil, referenceType: .footnote
        ))
        meta[key] = CrossReferenceNodeMetadata(
            documentId: doc, volumeId: vol,
            documentNumber: "\(i + 1)", header: "Target Document \(i + 1)", dateline: nil
        )
    }

    return CrossReferenceGraph(
        centralDocumentId: centralDocumentId,
        centralVolumeId: centralVolumeId,
        inboundEdges: inboundEdges,
        outboundEdges: outboundEdges,
        hasUndownloadedSources: false,
        nodeMetadata: meta
    )
}

// MARK: - CrossReferenceGraphTests

@MainActor
struct CrossReferenceGraphTests {

    let canvasSize = CGSize(width: 800, height: 600)

    // MARK: - StandardLayoutTest

    @Test("StandardLayoutTest: all 10 nodes within bounds with ≥60pt vertical separation")
    @MainActor
    func standardLayoutPositionsAllNodesWithinBounds() throws {
        let graph = makeTestGraph(inboundCount: 5, outboundCount: 4)
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d0", centralVolumeId: "vol1"
        )
        vm.graph = graph
        vm.rebuildDisplay()
        vm.onCanvasSizeChanged(canvasSize, reduceMotion: true)

        #expect(vm.displayNodes.count == 10)
        #expect(vm.nodePositions.count == 10)

        // All nodes within canvas bounds
        for (_, pos) in vm.nodePositions {
            #expect(pos.x >= 0 && pos.x <= canvasSize.width,
                    "x=\(pos.x) out of bounds [0, \(canvasSize.width)]")
            #expect(pos.y >= 0 && pos.y <= canvasSize.height,
                    "y=\(pos.y) out of bounds [0, \(canvasSize.height)]")
        }

        // Inbound column: ≥60pt vertical separation between consecutive nodes
        let inboundPositions = vm.displayNodes
            .filter { if case .inbound = $0.kind { true } else { false } }
            .compactMap { vm.nodePositions[$0.id] }
            .sorted { $0.y < $1.y }

        for i in 1..<inboundPositions.count {
            let sep = inboundPositions[i].y - inboundPositions[i - 1].y
            #expect(sep >= 60, "Inbound separation \(sep)pt < 60pt minimum")
        }

        // Outbound column: same check
        let outboundPositions = vm.displayNodes
            .filter { if case .outbound = $0.kind { true } else { false } }
            .compactMap { vm.nodePositions[$0.id] }
            .sorted { $0.y < $1.y }

        for i in 1..<outboundPositions.count {
            let sep = outboundPositions[i].y - outboundPositions[i - 1].y
            #expect(sep >= 60, "Outbound separation \(sep)pt < 60pt minimum")
        }
    }

    // MARK: - FallbackLayoutTest

    @Test("FallbackLayoutTest: force-directed positions within bounds; no node overlap")
    @MainActor
    func forceDirectedLayoutPositionsWithinBounds() throws {
        // Pass one unique volume per edge so volume-based clustering produces a
        // size-1 cluster per edge (50 display nodes total), which exercises the
        // force-directed layout path without collapsing nodes into a few clusters.
        let graph = makeTestGraph(
            inboundCount: 25,
            outboundCount: 24,
            inboundVolumeIds:  (0..<25).map { "vol-in-\($0)" },
            outboundVolumeIds: (0..<24).map { "vol-out-\($0)" }
        )
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d0", centralVolumeId: "vol1"
        )
        vm.graph = graph
        vm.rebuildDisplay()
        vm.onCanvasSizeChanged(canvasSize, reduceMotion: true)

        #expect(vm.displayNodes.count == 50)
        #expect(vm.nodePositions.count == 50)

        let nodeRadius: CGFloat = 18
        let padding: CGFloat = 32

        // All nodes within padded canvas bounds
        for (_, pos) in vm.nodePositions {
            #expect(pos.x >= padding && pos.x <= canvasSize.width  - padding)
            #expect(pos.y >= padding && pos.y <= canvasSize.height - padding)
        }

        // No two nodes overlap (centre-to-centre distance > 2 × radius)
        let positions = Array(vm.nodePositions)
        var overlapCount = 0
        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let dx = positions[i].value.x - positions[j].value.x
                let dy = positions[i].value.y - positions[j].value.y
                if hypot(dx, dy) < nodeRadius * 2 { overlapCount += 1 }
            }
        }
        // Tolerate up to 5% overlap pairs — force-directed layouts may not be perfect
        let pairCount = positions.count * (positions.count - 1) / 2
        #expect(overlapCount <= pairCount / 20, "Too many overlapping nodes: \(overlapCount)")
    }

    // MARK: - ClusteringTest

    @Test("ClusteringTest: >30 nodes from 3 volumes are grouped into cluster nodes")
    func clusteringGroupsSameVolumeNodes() throws {
        // 35 inbound edges from 3 different volumes (12, 12, 11 each)
        let graph = makeTestGraph(
            inboundCount: 35,
            outboundCount: 0,
            inboundVolumeIds: ["vol-a", "vol-b", "vol-c"]
        )
        let centralKey = "vol1/d0"

        let (nodes, edges) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: []
        )

        // Should have 1 central + 3 cluster nodes (not 36 individual nodes)
        #expect(nodes.count == 4, "Expected 4 nodes (central + 3 clusters), got \(nodes.count)")

        let clusterNodes = nodes.filter(\.isCluster)
        #expect(clusterNodes.count == 3)

        // All cluster keys present as edges to central
        #expect(edges.count == 3)
        for edge in edges {
            #expect(edge.target == centralKey)
            #expect(edge.source.hasPrefix("cluster/inbound/"))
        }

        // Expanding one cluster reveals its individual nodes
        let firstClusterKey = clusterNodes[0].id
        let (expandedNodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: [firstClusterKey],
            downloadedVolumeIds: []
        )
        #expect(expandedNodes.count > 4, "Expanding cluster should add individual nodes")
    }

    // MARK: - ReduceMotionTest

    @Test("ReduceMotionTest: layout completes synchronously when reduce motion is active")
    @MainActor
    func reduceMotionProducesImmediateLayout() throws {
        let graph = makeTestGraph(inboundCount: 25, outboundCount: 24)
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d0", centralVolumeId: "vol1"
        )
        vm.graph = graph
        vm.rebuildDisplay()
        vm.onCanvasSizeChanged(canvasSize, reduceMotion: true)

        // With reduceMotion=true the settling animation task must NOT be running.
        #expect(!vm.isAnimatingLayout)
        // Positions must be populated immediately.
        #expect(!vm.nodePositions.isEmpty)
        #expect(vm.nodePositions.count == vm.displayNodes.count)
    }

    // MARK: - InteractionTest

    @Test("InteractionTest: tapping a node selects it; second tap re-centres the graph")
    @MainActor
    func tapSelectsNodeThenRecentres() throws {
        let graph = makeTestGraph(inboundCount: 3, outboundCount: 2)
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d0", centralVolumeId: "vol1"
        )
        vm.graph = graph
        vm.rebuildDisplay()
        vm.onCanvasSizeChanged(canvasSize, reduceMotion: true)

        // Pick a non-central node with metadata (so nodeMetadata lookup succeeds)
        let target = try #require(
            vm.displayNodes.first { !$0.isCentral && $0.metadata?.header != nil }
        )
        let targetDocId  = try #require(target.metadata?.documentId)
        let targetVolId  = try #require(target.metadata?.volumeId)

        // First tap: select (shows info panel)
        #expect(vm.selectedNodeKey == nil)
        vm.tapNode(target.id, reduceMotion: true)
        #expect(vm.selectedNodeKey == target.id)

        // Second tap: re-centres the graph (version 1.2 behavior).
        // recenterOn() pushes the old centre onto history and resets state.
        let prevDocId = vm.centralDocumentId
        vm.tapNode(target.id, reduceMotion: true)
        #expect(vm.selectedNodeKey == nil,    "selectedNodeKey should be cleared on re-centre")
        #expect(vm.centralDocumentId == targetDocId, "graph should re-centre on the tapped document")
        #expect(vm.centralVolumeId   == targetVolId, "volume should also update on re-centre")
        #expect(vm.history.count == 1,        "old centre should be pushed to history")
        #expect(vm.history.last?.documentId == prevDocId, "history entry should record old centre")
    }

    // MARK: - AccessibilityTest

    @Test("AccessibilityTest: all display nodes have non-empty accessibility labels")
    func allDisplayNodesHaveAccessibilityLabels() throws {
        let graph = makeTestGraph(
            inboundCount: 5, outboundCount: 4,
            inboundVolumeIds: ["vol-src"]
        )
        let centralKey = "vol1/d0"

        let (nodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: ["vol1"]
        )

        for node in nodes {
            #expect(!node.accessibilityLabel.isEmpty,
                    "Node \(node.id) has empty accessibility label")
        }

        // Cluster nodes (when applicable) also have labels
        let largeGraph = makeTestGraph(
            inboundCount: 35, outboundCount: 0,
            inboundVolumeIds: ["vol-a", "vol-b", "vol-c"]
        )
        let (clusterNodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: largeGraph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: []
        )
        for node in clusterNodes {
            #expect(!node.accessibilityLabel.isEmpty,
                    "Cluster node \(node.id) has empty accessibility label")
        }
    }

    // MARK: - ExtendedNodesTest

    @Test("ExtendedNodesTest: buildDisplayNodesAndEdges includes extended nodes for degree-2 graphs")
    func extendedNodesAppearsInDisplay() throws {
        let centralKey = "vol1/d0"

        // Build a graph that already has extendedEdges (simulating what expandedGraph returns).
        let baseGraph = makeTestGraph(inboundCount: 2, outboundCount: 2)

        // Manually add an extended edge connecting an inbound node to a new 2nd-degree node.
        let extEdge = CrossReferenceEdge(
            sourceDocumentId: "d-ext-99",
            sourceVolumeId:   "vol-ext",
            targetDocumentId: "d-in-0",    // connects to the 1st-degree inbound node
            targetVolumeId:   "vol-src",
            context:          "Extended context for testing.",
            referenceType:    .footnote
        )

        let extendedGraph = CrossReferenceGraph(
            centralDocumentId: baseGraph.centralDocumentId,
            centralVolumeId:   baseGraph.centralVolumeId,
            inboundEdges:      baseGraph.inboundEdges,
            outboundEdges:     baseGraph.outboundEdges,
            hasUndownloadedSources: false,
            nodeMetadata:      baseGraph.nodeMetadata,
            extendedEdges:     [extEdge],
            fetchedDegree:     2
        )

        let (nodes, edges) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: extendedGraph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: ["vol1", "vol-src", "vol-tgt"]
        )

        // Should have the 1 central + 2 inbound + 2 outbound + 1 extended = 6 nodes.
        #expect(nodes.count == 6, "Expected 6 nodes (5 base + 1 extended), got \(nodes.count)")

        // The extended node (d-ext-99 / vol-ext) should be present with .extended kind.
        let extNode = nodes.first { $0.id == "vol-ext/d-ext-99" }
        #expect(extNode != nil, "Extended node vol-ext/d-ext-99 must appear in display nodes")
        if let n = extNode {
            if case .extended = n.kind { /* expected */ } else {
                Issue.record("Expected .extended kind for node \(n.id), got \(n.kind)")
            }
            #expect(n.degree == 2, "Extended node should have degree 2")
        }

        // The extended edge should appear in displayEdges with degree == 2.
        let extDisplayEdge = edges.first { $0.source == "vol-ext/d-ext-99" }
        #expect(extDisplayEdge != nil, "Extended edge must appear in displayEdges")
        #expect(extDisplayEdge?.degree == 2, "Extended edge should have degree 2")
        #expect(extDisplayEdge?.context == "Extended context for testing.",
                "Edge context must be preserved for extended edges")

        // Extended node must have a non-empty accessibility label.
        if let extN = extNode {
            #expect(!extN.accessibilityLabel.isEmpty,
                    "Extended node must have a non-empty accessibility label")
        }
    }

    // MARK: - TimelineLayoutTest

    /// Builds a small graph whose nodes carry ISO dates for timeline-layout tests.
    private func makeDatedGraph() -> CrossReferenceGraph {
        let centralKey = "vol1/d0"
        var meta: [String: CrossReferenceNodeMetadata] = [:]
        meta[centralKey] = CrossReferenceNodeMetadata(
            documentId: "d0", volumeId: "vol1",
            documentNumber: "168", header: "Central Document", dateline: nil,
            dateISO: "1962-07-25"
        )
        meta["vol1/dEarly"] = CrossReferenceNodeMetadata(
            documentId: "dEarly", volumeId: "vol1",
            documentNumber: "95", header: "Early Document", dateline: nil,
            dateISO: "1962-03-04"
        )
        meta["vol1/dMid"] = CrossReferenceNodeMetadata(
            documentId: "dMid", volumeId: "vol1",
            documentNumber: "142", header: "Mid Document", dateline: nil,
            dateISO: "1962-05-30"
        )
        meta["vol1/dLate"] = CrossReferenceNodeMetadata(
            documentId: "dLate", volumeId: "vol1",
            documentNumber: "201", header: "Late Document", dateline: nil,
            dateISO: "1962-11-02"
        )
        meta["vol1/dUndated"] = CrossReferenceNodeMetadata(
            documentId: "dUndated", volumeId: "vol1",
            documentNumber: "7", header: "Undated Document", dateline: nil,
            dateISO: nil
        )

        func edge(_ src: String, _ tgt: String) -> CrossReferenceEdge {
            CrossReferenceEdge(
                sourceDocumentId: src, sourceVolumeId: "vol1",
                targetDocumentId: tgt, targetVolumeId: "vol1",
                context: nil, referenceType: .footnote
            )
        }
        return CrossReferenceGraph(
            centralDocumentId: "d0", centralVolumeId: "vol1",
            inboundEdges:  [edge("dLate", "d0"), edge("dUndated", "d0")],
            outboundEdges: [edge("d0", "dEarly"), edge("d0", "dMid")],
            hasUndownloadedSources: false, nodeMetadata: meta
        )
    }

    @Test("TimelineLayoutTest: dated nodes order left-to-right by date; undated nodes park at the trailing edge")
    func timelineLayoutOrdersByDate() throws {
        let graph = makeDatedGraph()
        let centralKey = "vol1/d0"
        let (nodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph, centralKey: centralKey,
            expandedClusterKeys: [], downloadedVolumeIds: ["vol1"]
        )
        let dateValues = CrossReferenceGraphViewModel.buildDateValues(for: nodes)
        let result = CrossReferenceGraphViewModel.timelineLayout(
            nodes: nodes, dateValues: dateValues,
            centralKey: centralKey, canvasSize: canvasSize
        )

        let xEarly   = try #require(result.positions["vol1/dEarly"]?.x)
        let xMid     = try #require(result.positions["vol1/dMid"]?.x)
        let xCentral = try #require(result.positions[centralKey]?.x)
        let xLate    = try #require(result.positions["vol1/dLate"]?.x)
        let parked   = try #require(result.positions["vol1/dUndated"])

        #expect(xEarly < xMid,     "Mar 4 must sit left of May 30")
        #expect(xMid < xCentral,   "May 30 must sit left of Jul 25")
        #expect(xCentral < xLate,  "Jul 25 must sit left of Nov 2")
        #expect(parked.x > xLate,  "Undated node must park right of all dated nodes")
        #expect(result.hasParkedNodes, "Parking flag must be set when undated nodes exist")
        #expect(!result.ticks.isEmpty, "A multi-month span must produce axis ticks")

        // All positions stay within the canvas and above the axis label area.
        for (_, pos) in result.positions {
            #expect(pos.x >= 0 && pos.x <= canvasSize.width)
            #expect(pos.y >= 0 && pos.y <= result.axisY)
        }

        // The central document owns the middle lane of the usable vertical band.
        let yCentral = try #require(result.positions[centralKey]?.y)
        let yTop: CGFloat = 64
        let yBottom = result.axisY - 60
        #expect(abs(yCentral - (yTop + yBottom) / 2) < 0.5,
                "Central node must sit on the centre lane")
    }

    @Test("TimelineBrushTest: a brush domain hides out-of-range dated nodes without parking them")
    func timelineBrushFiltersDomain() throws {
        let graph = makeDatedGraph()  // Mar 4 … Nov 2, 1962; one undated node
        let centralKey = "vol1/d0"
        let (nodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph, centralKey: centralKey,
            expandedClusterKeys: [], downloadedVolumeIds: ["vol1"]
        )
        let dateValues = CrossReferenceGraphViewModel.buildDateValues(for: nodes)
        let calendar = Calendar(identifier: .gregorian)
        let domainStart = try #require(
            CrossReferenceGraphViewModel.date(fromISO: "1962-05-01", calendar: calendar)
        ).timeIntervalSinceReferenceDate
        let domainEnd = try #require(
            CrossReferenceGraphViewModel.date(fromISO: "1962-08-01", calendar: calendar)
        ).timeIntervalSinceReferenceDate

        let result = CrossReferenceGraphViewModel.timelineLayout(
            nodes: nodes, dateValues: dateValues,
            centralKey: centralKey, canvasSize: canvasSize,
            domain: domainStart...domainEnd
        )

        // In-domain: dMid (May 30) and central (Jul 25). Out: dEarly (Mar 4),
        // dLate (Nov 2) — hidden, NOT parked. Undated still parks.
        #expect(result.positions["vol1/dMid"] != nil)
        #expect(result.positions[centralKey] != nil)
        #expect(result.positions["vol1/dEarly"] == nil, "Out-of-domain node must be hidden")
        #expect(result.positions["vol1/dLate"] == nil, "Out-of-domain node must be hidden")
        #expect(result.positions["vol1/dUndated"] != nil, "Undated node still parks")
        #expect(result.hasParkedNodes)

        // The axis spans the brushed window, not the full extent.
        let xMid = try #require(result.positions["vol1/dMid"]?.x)
        let xCentral = try #require(result.positions[centralKey]?.x)
        #expect(xCentral > xMid, "Chronological order preserved inside the domain")
    }

    @Test("TimelineLayoutTest: layout is empty when dates are missing or identical")
    func timelineLayoutRequiresDateSpan() throws {
        let graph = makeTestGraph(inboundCount: 3, outboundCount: 2)  // no dateISO values
        let centralKey = "vol1/d0"
        let (nodes, _) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph, centralKey: centralKey,
            expandedClusterKeys: [], downloadedVolumeIds: ["vol1"]
        )
        let dateValues = CrossReferenceGraphViewModel.buildDateValues(for: nodes)
        #expect(dateValues.isEmpty)
        let result = CrossReferenceGraphViewModel.timelineLayout(
            nodes: nodes, dateValues: dateValues,
            centralKey: centralKey, canvasSize: canvasSize
        )
        #expect(result.positions.isEmpty, "Undated graphs cannot be laid out chronologically")
        #expect(result.ticks.isEmpty)
    }

    @Test("TimelineLayoutTest: lenient ISO parsing accepts year, year-month, and full dates")
    func dateParsingHandlesPartialISO() throws {
        let calendar = Calendar(identifier: .gregorian)
        let full  = CrossReferenceGraphViewModel.date(fromISO: "1962-07-25", calendar: calendar)
        let month = CrossReferenceGraphViewModel.date(fromISO: "1962-07", calendar: calendar)
        let year  = CrossReferenceGraphViewModel.date(fromISO: "1962", calendar: calendar)
        let bad   = CrossReferenceGraphViewModel.date(fromISO: "n.d.", calendar: calendar)

        let fullDate = try #require(full)
        let monthDate = try #require(month)
        let yearDate = try #require(year)
        #expect(bad == nil)
        #expect(yearDate <= monthDate && monthDate <= fullDate,
                "Partial dates resolve to the start of their period")
        #expect(calendar.component(.year, from: fullDate) == 1962)
        #expect(calendar.component(.day,  from: fullDate) == 25)
    }

    // MARK: - DateClusterTest

    @Test("DateClusterTest: four-plus docs in one x-window collapse into an expandable cluster with rerouted, aggregated edges")
    func dateClusteringCollapsesPileups() throws {
        let centralKey = "vol1/d0"
        var meta: [String: CrossReferenceNodeMetadata] = [:]
        meta[centralKey] = CrossReferenceNodeMetadata(
            documentId: "d0", volumeId: "vol1",
            documentNumber: "0", header: "Central", dateline: nil,
            dateISO: "1967-08-15"
        )
        // Five inbound documents dated within four days (a pileup), plus one
        // outbound document months later that must stay individual.
        var inbound: [CrossReferenceEdge] = []
        for (index, day) in [4, 5, 5, 6, 8].enumerated() {
            let doc = "m\(index)"
            inbound.append(CrossReferenceEdge(
                sourceDocumentId: doc, sourceVolumeId: "vol1",
                targetDocumentId: "d0", targetVolumeId: "vol1",
                context: "Context \(index).", referenceType: .footnote
            ))
            meta["vol1/\(doc)"] = CrossReferenceNodeMetadata(
                documentId: doc, volumeId: "vol1",
                documentNumber: "\(index + 1)", header: "Member \(index)", dateline: nil,
                dateISO: String(format: "1967-06-%02d", day)
            )
        }
        let outbound = [CrossReferenceEdge(
            sourceDocumentId: "d0", sourceVolumeId: "vol1",
            targetDocumentId: "far", targetVolumeId: "vol1",
            context: nil, referenceType: .footnote
        )]
        meta["vol1/far"] = CrossReferenceNodeMetadata(
            documentId: "far", volumeId: "vol1",
            documentNumber: "99", header: "Far Document", dateline: nil,
            dateISO: "1967-11-04"
        )
        let graph = CrossReferenceGraph(
            centralDocumentId: "d0", centralVolumeId: "vol1",
            inboundEdges: inbound, outboundEdges: outbound,
            hasUndownloadedSources: false, nodeMetadata: meta
        )
        let (nodes, edges) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph, centralKey: centralKey,
            expandedClusterKeys: [], downloadedVolumeIds: ["vol1"]
        )
        let dateValues = CrossReferenceGraphViewModel.buildDateValues(for: nodes)

        let clustered = CrossReferenceGraphViewModel.dateClusteredDisplay(
            nodes: nodes, edges: edges, dateValues: dateValues,
            canvasWidth: 800, expandedKeys: []
        )

        // One date cluster replaces the five members; central + far survive.
        let clusterNode = try #require(clustered.nodes.first { $0.isDateCluster })
        guard case .dateCluster(let label, let count, let members) = clusterNode.kind else {
            Issue.record("Expected dateCluster kind")
            return
        }
        #expect(count == 5)
        #expect(members.count == 5)
        #expect(!label.isEmpty)
        #expect(clustered.nodes.count == 3, "central + far + cluster, got \(clustered.nodes.count)")
        #expect(!clustered.nodes.contains { $0.id == "vol1/m0" }, "Members must be hidden")
        #expect(clustered.clusterDateValues[clusterNode.id] != nil,
                "Cluster needs a date value for x placement")

        // The five member→central edges aggregate into one cluster→central edge.
        let clusterEdge = try #require(clustered.edges.first {
            $0.source == clusterNode.id && $0.target == centralKey
        })
        #expect(clusterEdge.referenceCount == 5)
        #expect(clusterEdge.contexts.count == 5)
        #expect(Set(clustered.edges.map(\.id)).count == clustered.edges.count,
                "Edge IDs must stay unique after rerouting")

        // Expanding the cluster restores the original display.
        let expanded = CrossReferenceGraphViewModel.dateClusteredDisplay(
            nodes: nodes, edges: edges, dateValues: dateValues,
            canvasWidth: 800, expandedKeys: [clusterNode.id]
        )
        #expect(!expanded.nodes.contains { $0.isDateCluster })
        #expect(expanded.nodes.count == nodes.count)
    }

    // MARK: - AggregationTest

    @Test("AggregationTest: parallel references collapse into one weighted edge; node and edge IDs are unique")
    func parallelReferencesAggregate() throws {
        let centralKey = "vol1/d0"
        var meta: [String: CrossReferenceNodeMetadata] = [:]
        meta[centralKey] = CrossReferenceNodeMetadata(
            documentId: "d0", volumeId: "vol1",
            documentNumber: "0", header: "Central Document", dateline: nil
        )
        meta["vol-src/dA"] = CrossReferenceNodeMetadata(
            documentId: "dA", volumeId: "vol-src",
            documentNumber: "1", header: "Document A", dateline: nil
        )

        // Document A references the centre in two separate footnotes (two raw rows),
        // and the centre also references document A back (bidirectional pair).
        let inbound = [
            CrossReferenceEdge(
                sourceDocumentId: "dA", sourceVolumeId: "vol-src",
                targetDocumentId: "d0", targetVolumeId: "vol1",
                context: "First footnote.", referenceType: .footnote
            ),
            CrossReferenceEdge(
                sourceDocumentId: "dA", sourceVolumeId: "vol-src",
                targetDocumentId: "d0", targetVolumeId: "vol1",
                context: "Second footnote.", referenceType: .footnote
            ),
        ]
        let outbound = [
            CrossReferenceEdge(
                sourceDocumentId: "d0", sourceVolumeId: "vol1",
                targetDocumentId: "dA", targetVolumeId: "vol-src",
                context: nil, referenceType: .footnote
            ),
        ]
        let graph = CrossReferenceGraph(
            centralDocumentId: "d0", centralVolumeId: "vol1",
            inboundEdges: inbound, outboundEdges: outbound,
            hasUndownloadedSources: false, nodeMetadata: meta
        )

        let (nodes, edges) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: ["vol1", "vol-src"]
        )

        // Document A must appear exactly once even though it is inbound twice and
        // outbound once; node and edge identifiers must be unique (ForEach contract).
        #expect(nodes.count == 2, "Expected central + 1 unique neighbour, got \(nodes.count)")
        #expect(Set(nodes.map(\.id)).count == nodes.count, "Node IDs must be unique")
        #expect(Set(edges.map(\.id)).count == edges.count, "Edge IDs must be unique")

        // The two inbound rows aggregate into one edge with both context passages.
        let inEdge = try #require(edges.first { $0.source == "vol-src/dA" && $0.target == centralKey })
        #expect(inEdge.referenceCount == 2)
        #expect(inEdge.contexts == ["First footnote.", "Second footnote."])
        #expect(inEdge.combinedContext == "First footnote.\n\nSecond footnote.")

        // The reverse direction stays a separate edge (distinct id).
        let outEdge = try #require(edges.first { $0.source == centralKey && $0.target == "vol-src/dA" })
        #expect(outEdge.referenceCount == 1)
        #expect(outEdge.contexts.isEmpty)
    }

    // MARK: - DeterminismTest

    @Test("DeterminismTest: display build output is stable across repeated invocations")
    func displayBuildIsDeterministic() throws {
        let graph = makeTestGraph(
            inboundCount: 8, outboundCount: 7,
            inboundVolumeIds: ["vol-b", "vol-a"], outboundVolumeIds: ["vol-d", "vol-c"]
        )
        let centralKey = "vol1/d0"

        let first = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph, centralKey: centralKey,
            expandedClusterKeys: [], downloadedVolumeIds: []
        )
        for _ in 0..<5 {
            let again = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
                graph: graph, centralKey: centralKey,
                expandedClusterKeys: [], downloadedVolumeIds: []
            )
            #expect(again.nodes.map(\.id) == first.nodes.map(\.id),
                    "Node order must be deterministic so layouts are stable across visits")
            #expect(again.edges.map(\.id) == first.edges.map(\.id),
                    "Edge order must be deterministic")
        }
    }

    // MARK: - NodeDegreeTest

    @Test("NodeDegreeTest: degree-1 nodes carry degree 1; central node carries degree 0")
    func nodeDegreeValues() throws {
        let graph = makeTestGraph(inboundCount: 3, outboundCount: 2)
        let centralKey = "vol1/d0"

        let (nodes, edges) = CrossReferenceGraphViewModel.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: [],
            downloadedVolumeIds: ["vol1"]
        )

        let centralNode = nodes.first { $0.isCentral }
        #expect(centralNode?.degree == 0, "Central node should have degree 0")

        let inboundNodes = nodes.filter { if case .inbound = $0.kind { true } else { false } }
        for n in inboundNodes {
            #expect(n.degree == 1, "Inbound node \(n.id) should have degree 1")
        }

        let outboundNodes = nodes.filter { if case .outbound = $0.kind { true } else { false } }
        for n in outboundNodes {
            #expect(n.degree == 1, "Outbound node \(n.id) should have degree 1")
        }

        for e in edges {
            #expect(e.degree == 1, "Degree-1 display edges should carry degree 1")
        }
    }

    // MARK: - #837: unprinted archival units on the canvas

    /// A unit node attaches to its citing document and carries an edge to it.
    @Test("Unit nodes join the display with an edge from their citing document")
    @MainActor
    func unitNodesAttachToTheirDocument() throws {
        let graph = makeTestGraph(inboundCount: 2, outboundCount: 2)
        let vm = CrossReferenceGraphViewModel(centralDocumentId: "d0", centralVolumeId: "vol1")
        vm.graph = graph
        vm.unitsByDocument = ["vol1/d0": [
            DisplayNode(id: "unit/vol1/d0/lot:60D627",
                        kind: .unit(collectionId: "lot:60D627", name: "Conference Files"),
                        metadata: nil, isDownloaded: true)
        ]]
        vm.rebuildDisplay()

        let unit = try #require(vm.displayNodes.first { $0.isUnit })
        #expect(unit.unitCollectionId == "lot:60D627")
        #expect(vm.displayEdges.contains { $0.source == "vol1/d0" && $0.target == unit.id }, """
            The unit node is on the canvas with no edge to the document that cites it — a \
            floating node saying nothing about who pointed at it.
            """)
    }

    /// A unit whose citing document is NOT on the canvas must not be drawn: the canvas would
    /// otherwise carry an archival node with no visible reason for being there.
    @Test("A unit whose document is absent is not drawn")
    @MainActor
    func unitWithoutItsDocumentIsDropped() throws {
        let graph = makeTestGraph(inboundCount: 1, outboundCount: 1)
        let vm = CrossReferenceGraphViewModel(centralDocumentId: "d0", centralVolumeId: "vol1")
        vm.graph = graph
        vm.unitsByDocument = ["vol9/dNotOnCanvas": [
            DisplayNode(id: "unit/vol9/dNotOnCanvas/lot:X",
                        kind: .unit(collectionId: "lot:X", name: "Elsewhere"),
                        metadata: nil, isDownloaded: true)
        ]]
        vm.rebuildDisplay()
        #expect(!vm.displayNodes.contains { $0.isUnit })
    }

    /// A unit node is `isDownloaded: true` BY CONSTRUCTION — it has no volume, so every
    /// not-downloaded affordance (dashed ring, icloud.slash, the two disabled menu items)
    /// would be lying about it. The drawing code additionally guards on `isUnit`, so this
    /// pins the invariant the guard depends on.
    @Test("A unit node never presents as an undownloaded document")
    @MainActor
    func unitNodeIsNeverUndownloaded() throws {
        let vm = CrossReferenceGraphViewModel(centralDocumentId: "d0", centralVolumeId: "vol1")
        vm.graph = makeTestGraph(inboundCount: 1, outboundCount: 1)
        vm.unitsByDocument = ["vol1/d0": [
            DisplayNode(id: "unit/vol1/d0/lot:A",
                        kind: .unit(collectionId: "lot:A", name: "A Collection"),
                        metadata: nil, isDownloaded: true)
        ]]
        vm.rebuildDisplay()
        let unit = try #require(vm.displayNodes.first { $0.isUnit })
        #expect(unit.isDownloaded, """
            A unit node built as not-downloaded would take the dashed ring and the icloud.slash \
            glyph, offering a download for a node that has no volume.
            """)
        #expect(unit.metadata == nil, "a unit stands for an archive, not a document")
    }

    /// The VoiceOver label is the only description a screen-reader user gets — the canvas is
    /// accessibilityHidden — so it must say both what the node is and what happens on tap.
    @Test("A unit node's accessibility label names it and its action")
    @MainActor
    func unitAccessibilityLabelSaysWhatItDoes() throws {
        let unit = DisplayNode(id: "unit/vol1/d0/lot:A",
                               kind: .unit(collectionId: "lot:A", name: "Conference Files"),
                               metadata: nil, isDownloaded: true)
        let label = unit.accessibilityLabel
        #expect(label.contains("Conference Files"))
        #expect(label.lowercased().contains("collection"), """
            The label does not say tapping opens the collection record. On a canvas that is \
            accessibilityHidden, this string is the whole affordance.
            """)
    }
}

// MARK: - CentralFileClassNodeTests

/// Pins the central-file class node the cross-reference graph gained in #834.
///
/// ## Why this node exists
/// Until #834 the graph dropped any footnote citation without a collection-authority record, and a
/// central-file class has none — the authority holds classes only as id-less display children. So a
/// document whose editors cited by decimal number showed NO teal nodes however many archival
/// footnotes it carried, and the help text had to apologise for it. Citing by number is the usual
/// practice before 1946 and still the majority channel through the 1950s.
///
/// Version history:
///   1.0 — Session 2026-08-20: #834
@Suite("Central-file class graph nodes (#834)")
struct CentralFileClassNodeTests {

    private func classNode(_ key: String, gloss: String? = nil) -> DisplayNode {
        DisplayNode(id: "class/vol1/d1/\(key)",
                    kind: .centralFileClass(key: key, gloss: gloss),
                    metadata: nil, isDownloaded: true)
    }

    /// **A class is not a unit, and the distinction is load-bearing.** `unitCollectionId` feeds an
    /// authority lookup that cannot answer for a class; if a class ever reported itself as a unit,
    /// every existing unit path would try to resolve it and quietly get nothing.
    @Test("A class node is archival but is not an authority-backed unit")
    func classIsNotAUnit() {
        let node = classNode("763.72")
        #expect(!node.isUnit, """
            A central-file class reported itself as a unit. `unitCollectionId` feeds the collection \
            authority, which holds no class records — every unit path would resolve it to nothing.
            """)
        #expect(node.unitCollectionId == nil)
        #expect(node.centralFileClassKey == "763.72")
        #expect(node.terminatesWalk, """
            The walk must stop at a class: there is no document behind a file number, exactly as \
            there is none behind a lot.
            """)
    }

    /// The canvas is `accessibilityHidden`, so this label is the ONLY description a VoiceOver
    /// reader gets. A bare key is a string of digits read aloud.
    @Test("The accessibility label speaks the class, with its gloss when there is one")
    func accessibilityLabelSpeaks() {
        let bare = classNode("763.72").accessibilityLabel
        #expect(bare.contains("763.72"))
        #expect(!bare.isEmpty)
        let glossed = classNode("763.72", gloss: "China and Japan").accessibilityLabel
        #expect(glossed.contains("763.72") && glossed.contains("China and Japan"), """
            The gloss must reach the label when present: "central file 763.72, China and Japan" is \
            speech; the key alone is digits.
            """)
    }

    /// A document citing several classes in one footnote must yield several nodes. They share a
    /// repository and carry no collection, so an id built from anything but the key collides.
    @Test("Two classes on one document are distinct nodes")
    func twoClassesAreDistinct() {
        let a = classNode("763.72")
        let b = classNode("811.24546")
        #expect(a.id != b.id, """
            Two class nodes collided on id. `Identifiable` collisions render as one node, so the \
            reader silently loses a citation — the same defect the external_citations row id had.
            """)
    }

    /// The gloss is `nil` by decision, not by omission (#828): the classification was renumbered in
    /// 1950 and only the 1910-49 schedule ships, so glossing a post-1949 key against it would
    /// confidently mislabel it. This pins that a MISSING gloss still produces a usable label.
    @Test("A node with no gloss still labels itself")
    func noGlossStillLabels() {
        let node = classNode("611.93")
        #expect(!node.accessibilityLabel.isEmpty, """
            Where the label table cannot place a key the app says nothing rather than something \
            wrong — but the node must still describe itself, or it is unreachable by VoiceOver.
            """)
    }
}

// MARK: - VolumeConnectionHoverSelectionTests (#1383)

/// The volume connection graph's hover and click rules, driven through the view model methods the
/// view's closures call (#1383). The graph carried the co-mention graph's handler, which wrote the
/// pointer's hover into the clicked selection, so it gets the same rules and the same fixtures
/// (`PersonCoMentionHoverSelectionTests`), plus one this graph alone needs: its info panel floats
/// over the canvas, so the view must know when the panel is only a hover preview.
///
/// The two fixtures that pin a click dropping the hover whatever it names and whichever way it
/// toggles are the co-mention suite's too, for the same two partial versions of the rule.
///
/// Version history:
///   1.0 — 2026-09-23: #1383 hover separated from the clicked selection
///   1.1 — 2026-09-24: #1383 review — a click under another volume's stale hover, and an unpin
///          after re-entry, one fixture each
@MainActor
struct VolumeConnectionHoverSelectionTests {

    private let a = "frus1969-76v01", b = "frus1969-76v02", c = "frus1969-76v03"

    @Test("A hover over another volume and off it leaves the clicked volume pinned")
    func hoverElsewhereKeepsTheClickedVolume() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.toggleSelection(a)
        vm.hoverChanged(b, hovering: true)
        vm.hoverChanged(b, hovering: false)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("A click on the volume the pointer has just entered pins it, not clears it")
    func clickAfterHoverPins() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("The panel previews the hovered volume, then returns to the clicked one")
    func panelPreviewsThenReturns() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.toggleSelection(a)
        vm.hoverChanged(b, hovering: true)
        #expect(vm.displayedPartnerId == b)
        #expect(vm.selectedPartnerId == a)
        vm.hoverChanged(b, hovering: false)
        #expect(vm.displayedPartnerId == a)
    }

    @Test("An exit from an earlier volume arriving after the next one's entry keeps that one's preview")
    func lateExitKeepsTheLaterPreview() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.toggleSelection(c)
        vm.hoverChanged(a, hovering: true)
        vm.hoverChanged(b, hovering: true)
        vm.hoverChanged(a, hovering: false)
        #expect(vm.hoveredPartnerId == b)
        #expect(vm.displayedPartnerId == b)
        #expect(vm.selectedPartnerId == c)
    }

    @Test("A hover alone pins nothing: the panel is gone once the pointer leaves")
    func hoverAlonePinsNothing() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.hoverChanged(a, hovering: true)
        vm.hoverChanged(a, hovering: false)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("A click that unpins the volume under the pointer closes the panel at once")
    func unpinUnderThePointerClosesThePanel() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("A click on one volume while another is hovered selects the clicked volume and drops the hover")
    func clickUnderAnotherVolumesHoverSelectsTheClickedVolume() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        // A hover on b whose exit never arrived, then a click on a.
        vm.hoverChanged(b, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == a)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == a)
        #expect(!vm.isPreviewingHover)
    }

    @Test("A click that unpins the volume after the pointer re-enters it closes the panel at once")
    func unpinAfterReenteringThePinnedVolumeClosesThePanel() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.toggleSelection(a)
        // Off the node and back on: the hover is live again when the unpinning click lands.
        vm.hoverChanged(a, hovering: false)
        vm.hoverChanged(a, hovering: true)
        vm.toggleSelection(a)
        #expect(vm.selectedPartnerId == nil)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }

    @Test("The panel is a hover preview only while it shows a hovered volume that is not the pinned one")
    func previewFlagFollowsEachConjunct() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        // Nothing hovered: the pinned panel is the real one.
        vm.toggleSelection(a)
        #expect(!vm.isPreviewingHover)
        // Hovering the pinned volume itself shows what is pinned: not a preview.
        vm.hoverChanged(a, hovering: true)
        #expect(!vm.isPreviewingHover)
        // Hovering another volume while one is pinned: a preview.
        vm.hoverChanged(b, hovering: true)
        #expect(vm.isPreviewingHover)
        // Hovering with nothing pinned: a preview.
        let bare = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        bare.hoverChanged(b, hovering: true)
        #expect(bare.isPreviewingHover)
    }

    @Test("A reload drops the hover, whose volume may be gone")
    func loadDropsTheHover() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSVolumeHover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)
        let store = try CrossReferenceStore(databaseURL: dbURL)

        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v01")
        vm.hoverChanged(a, hovering: true)
        await vm.load(from: store)
        #expect(vm.error == nil)
        #expect(vm.hoveredPartnerId == nil)
        #expect(vm.displayedPartnerId == nil)
    }
}

// MARK: - VolumeConnectionGraphRecentreTests (#1500, #1471)

/// The volume graph after Explore connections and Back, and the Mac window that titles it (#1500,
/// #1471), driven through the real view model over a real store.
///
/// **#1500.** The Mac Cross-Reference Graph window titled its Volume Connections stage with the
/// volume the stage OPENED on, while the graph's own Explore connections
/// (`recenterOn(volumeId:from:)`) and Back (`navigateBack(from:)`) moved the view model's
/// `centralVolumeId` — the view's private `@State`, out of the window's reach — so after an Explore
/// the title named volume A over volume B's discs and figures. The window now keeps the view model
/// in its stage and titles the stage through ``VolumeConnectionGraphViewModel/centreTitle(in:)``.
/// `exploreAndBackMoveTheTitleAndOpenWithAnEmptyPanel` drives two Explores and two Backs and reads
/// the title after each; `aCentreTheManifestDoesNotListIsTitledByItsId` is the lookup's fallback.
///
/// **#1471.** After Explore connections or Back the panel showed a partner no click had chosen —
/// the last-sorted one — and no click on empty canvas closed it. The view model already dropped the
/// pin and the hover on every reload; the first fixture pins that it still does — the first Explore
/// over a pin and a lingering hover both, the second over a pin, the first Back over a hover and the
/// second over a pin — since the fault was never here: each node hit area wrote its
/// `.onHover` after `.position(pos)`, so its hover region was the whole canvas and the rebuilt hit
/// areas re-reported a hover at once
/// (`CodingStandardsAuditTests.pointerModifiersPrecedeTheirPosition` is that half). The
/// empty-canvas click is new: ``VolumeConnectionGraphViewModel/clearSelection()``, one fixture per
/// state it drops.
///
/// `theWindowTitlesTheStageFromTheGraphsCentre` reads the window and the graph view themselves,
/// with comments and strings masked, because the window is `#if os(macOS)` and the unit tests run
/// on iOS: the stage holds the view model, the title reads its centre, the graph view is handed
/// that model and keyed on it, both ways onto the stage — the mode choice and the Corpus Browser's
/// `pendingVolumeGraph` hand-off — make a fresh one, and the Mac canvas's empty space takes the
/// clearing click, being a clear view given a content shape and nothing that turns its hits off.
/// Every fixture here reads source or drives models, so each fails the same way on
/// any destination, iPhone or iPad; that the Mac title bar and panel redraw is the owner's by-eye
/// check.
///
/// Version history:
///   1.0 — 2026-09-26: #1500, #1471
///   1.1 — 2026-09-26: review round 1 — the empty canvas must be hit-testable, not only call
///          `clearSelection()`
@MainActor
struct VolumeConnectionGraphRecentreTests {

    /// The volume the graph opens on.
    private let opening = "frus1961-63v05"
    /// A partner of the opening volume, explored first.
    private let explored = "frus1961-63v14"
    /// A partner of `explored` only, explored second.
    private let further = "frus1961-63v07"
    /// The partner that sorts last in both the opening and the explored graph — #1471's
    /// `frus1961-63v25`, the volume the panel showed unasked.
    private let lastSorted = "frus1961-63v25"

    /// A manifest entry titled "Title <volumeId>".
    private func entry(_ volumeId: String) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId, filename: "\(volumeId).xml", subseries: "1961-63",
            title: "Title \(volumeId)",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2000", status: .published,
            editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: []
        )
    }

    /// The four fixture volumes' manifest entries.
    private var entries: [VolumeManifestEntry] {
        [opening, explored, further, lastSorted].map(entry)
    }

    /// A store whose cross-references give the opening volume the partners `explored` and
    /// `lastSorted`, `explored` the partners `opening`, `further` and `lastSorted`, and `further`
    /// the partner `explored` — so each Explore and Back below lands on a graph with partners.
    private func makeStore() throws -> (dir: URL, store: CrossReferenceStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSVolumeRecentre-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        let fts5 = try FTS5Store(databaseURL: dbURL)
        _ = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                 volumesDirectory: volDir, concurrencyLimit: 1)

        var db: OpaquePointer?
        try #require(sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
                     "fixture: cannot open \(dbURL.path)")
        defer { sqlite3_close_v2(db) }
        let edges: [(source: String, target: String, count: Int)] = [
            (opening, explored, 3), (explored, opening, 1), (lastSorted, opening, 2),
            (lastSorted, explored, 1), (explored, further, 1), (further, explored, 1),
        ]
        var document = 0
        for edge in edges {
            for _ in 0..<edge.count {
                document += 1
                let sql = """
                    INSERT INTO cross_references
                        (source_volume_id, source_document_id, target_volume_id, target_document_id)
                    VALUES ('\(edge.source)', 'd\(document)', '\(edge.target)', 'd\(document + 1000)')
                    """
                try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK,
                             "fixture: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        return (dir, try CrossReferenceStore(databaseURL: dbURL))
    }

    @Test("Explore connections and Back move the title to the graph's centre, and each opens with nothing in the panel")
    func exploreAndBackMoveTheTitleAndOpenWithAnEmptyPanel() async throws {
        let (dir, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let graph = VolumeConnectionGraphViewModel(centralVolumeId: opening)
        await graph.load(from: store)
        try #require(graph.error == nil && graph.partnerVolumeIds == [explored, lastSorted],
                     "fixture: \(graph.error ?? "no error"), partners \(graph.partnerVolumeIds)")
        #expect(graph.centreTitle(in: entries) == "Title \(opening)")

        // The reader clicks the explored volume, and a hover lingers on the last-sorted one.
        graph.toggleSelection(explored)
        graph.hoverChanged(lastSorted, hovering: true)
        // Explore connections, in the panel.
        await graph.recenterOn(volumeId: explored, from: store)
        #expect(graph.partnerVolumeIds == [opening, further, lastSorted], "fixture: the graph did not re-centre")
        #expect(graph.centreTitle(in: entries) == "Title \(explored)",
                "after Explore connections the title reads \(graph.centreTitle(in: entries)), the graph is on \(graph.centralVolumeId)")
        #expect(graph.selectedPartnerId == nil && graph.hoveredPartnerId == nil,
                "Explore connections opened with \(graph.displayedPartnerId ?? "nothing") in the panel")

        // A second Explore goes one further.
        graph.toggleSelection(further)
        await graph.recenterOn(volumeId: further, from: store)
        #expect(graph.centreTitle(in: entries) == "Title \(further)",
                "after a second Explore the title reads \(graph.centreTitle(in: entries)), the graph is on \(graph.centralVolumeId)")
        #expect(graph.displayedPartnerId == nil)

        // Back, twice — each over a pin or a hover.
        graph.hoverChanged(explored, hovering: true)
        await graph.navigateBack(from: store)
        #expect(graph.centreTitle(in: entries) == "Title \(explored)",
                "after Back the title reads \(graph.centreTitle(in: entries)), the graph is on \(graph.centralVolumeId)")
        #expect(graph.selectedPartnerId == nil && graph.hoveredPartnerId == nil,
                "Back opened with \(graph.displayedPartnerId ?? "nothing") in the panel")
        graph.toggleSelection(lastSorted)
        await graph.navigateBack(from: store)
        #expect(graph.centreTitle(in: entries) == "Title \(opening)",
                "after the second Back the title reads \(graph.centreTitle(in: entries)), the graph is on \(graph.centralVolumeId)")
        #expect(graph.selectedPartnerId == nil && graph.hoveredPartnerId == nil,
                "the second Back opened with \(graph.displayedPartnerId ?? "nothing") in the panel")
        #expect(!graph.canNavigateBack)
        #expect(!graph.isPreviewingHover)
    }

    @Test("A centre the manifest does not list is titled by its volume id")
    func aCentreTheManifestDoesNotListIsTitledByItsId() async throws {
        let (dir, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let graph = VolumeConnectionGraphViewModel(centralVolumeId: opening)
        await graph.load(from: store)
        await graph.recenterOn(volumeId: explored, from: store)
        let withoutTheCentre = entries.filter { $0.volumeId != explored }
        #expect(graph.centreTitle(in: withoutTheCentre) == explored,
                "a centre with no manifest entry is titled \(graph.centreTitle(in: withoutTheCentre))")
    }

    @Test("A click on empty canvas unpins the pinned volume, closing the panel")
    func anEmptyCanvasClickUnpins() throws {
        let graph = VolumeConnectionGraphViewModel(centralVolumeId: opening)
        graph.toggleSelection(explored)
        try #require(graph.displayedPartnerId == explored, "fixture: the click did not pin the volume")
        graph.clearSelection()
        #expect(graph.selectedPartnerId == nil)
        #expect(graph.displayedPartnerId == nil)
    }

    @Test("A click on empty canvas drops a hover preview, closing the panel")
    func anEmptyCanvasClickDropsAHoverPreview() {
        let graph = VolumeConnectionGraphViewModel(centralVolumeId: opening)
        graph.hoverChanged(lastSorted, hovering: true)
        graph.clearSelection()
        #expect(graph.hoveredPartnerId == nil)
        #expect(graph.displayedPartnerId == nil)
        #expect(!graph.isPreviewingHover)
    }

    // MARK: - The window's wiring, read from source

    @Test("The Mac window titles the volume graph from its view model's centre, which its stage holds")
    func theWindowTitlesTheStageFromTheGraphsCentre() throws {
        let window = try Self.source("FRUSExplorer/CrossReference/CrossReferenceGraphWindowView.swift")
        let windowCode = String(decoding: CodingStandardsAuditTests.maskedCode(window), as: UTF8.self)

        // The stage holds the graph's view model, and only one function makes one.
        let stages = try Self.body("private enum PickerStage {", in: window)
        #expect(Self.count("case volumeGraph(VolumeConnectionGraphViewModel)", in: stages) == 1,
                "PickerStage's volume-graph case does not hold the view model")
        let maker = try Self.body("private func volumeGraphStage(_ volumeId: String) -> PickerStage {", in: window)
        #expect(Self.count(".volumeGraph(VolumeConnectionGraphViewModel(centralVolumeId: volumeId))", in: maker) == 1,
                "volumeGraphStage does not make a fresh view model on the volume it is given")
        #expect(Self.count("VolumeConnectionGraphViewModel(", in: windowCode) == 1,
                "the window makes a view model outside volumeGraphStage")

        // Both ways onto the stage make a fresh graph: the mode choice and the Corpus Browser's
        // hand-off, which on `v2` left a window already showing a volume graph on its old volume.
        let handOff = try Self.body("private func consumePendingVolumeGraph() {", in: window)
        #expect(Self.count("stage = volumeGraphStage(volumeId)", in: handOff) == 1,
                "the pendingVolumeGraph hand-off does not open a fresh volume graph")
        let modeChoice = try Self.body("private func modeChoiceView(volumeId: String) -> some View {", in: window)
        #expect(Self.count("stage = volumeGraphStage(volumeId)", in: modeChoice) == 1,
                "the mode choice does not open a fresh volume graph")
        #expect(Self.count("stage = .volumeGraph(", in: windowCode) == 0,
                "the window sets the volume-graph stage without volumeGraphStage")

        // The title reads the graph's centre, which Explore connections and Back move.
        let content = try Self.body("private var pickerContent: some View {", in: window)
        #expect(Self.count(".navigationTitle(pickerNavigationTitle)", in: content) == 1,
                "the picker is not titled by pickerNavigationTitle")
        let title = try Self.body("private var pickerNavigationTitle: String {", in: window)
        #expect(try Self.matches(#"case\s+\.volumeGraph\(let\s+graph\):\s*return\s+graph\.centreTitle\(in:\s*allEntries\)"#,
                                 in: title) == 1,
                "the volume-graph stage's title does not read graph.centreTitle(in: allEntries)")

        // The graph view draws that same view model, and a new one is a new view whose load runs.
        let stageView = try Self.body("private var pickerStageView: some View {", in: window)
        #expect(try Self.matches(#"case\s+\.volumeGraph\(let\s+graph\):\s*if\s+appState\.crossReferenceStore\s*!=\s*nil\s*\{\s*VolumeConnectionGraphView\(vm:\s*graph\)\s*\.id\(ObjectIdentifier\(graph\)\)"#,
                                 in: stageView) == 1,
                "the volume-graph stage does not draw VolumeConnectionGraphView(vm: graph) keyed .id(ObjectIdentifier(graph))")
        #expect(Self.count("VolumeConnectionGraphView(volumeId:", in: windowCode) == 0,
                "the window makes a graph view with a view model of its own, which its title cannot read")

        // The graph view keeps the model it is handed, and on the Mac its empty canvas clears.
        let view = try Self.source("FRUSExplorer/CrossReference/VolumeConnectionGraphView.swift")
        let handedIn = try Self.body("init(vm: VolumeConnectionGraphViewModel) {", in: view)
        #expect(Self.count("_vm = State(initialValue: vm)", in: handedIn) == 1,
                "init(vm:) does not keep the view model it is handed")
        let emptyCanvas = try Self.body("private var emptyCanvas: some View {", in: view)
        // A clear view takes no hits without a content shape, and `graphCanvas` takes none at all,
        // so the click, drag and double-click reach empty canvas only through a clear view given a
        // content shape, with nothing turning its hits off (review round 1).
        #expect(try Self.matches(#"Color\.clear\s*\.contentShape\(Rectangle\(\)\)\s*\.onTapGesture\s*\{\s*vm\.clearSelection\(\)\s*\}"#,
                                 in: emptyCanvas) == 1,
                "the empty canvas is not Color.clear.contentShape(Rectangle()).onTapGesture { vm.clearSelection() }")
        #expect(Self.count("allowsHitTesting", in: emptyCanvas) == 0,
                "the empty canvas turns its hits off, so no click, drag or double-click reaches it")
        let graphContent = try Self.body("private var graphContent: some View {", in: view)
        // After the pan offset, so the empty canvas stays under the window however far the graph
        // is panned; before the gestures, so a drag or double-click on it still pans or resets.
        #expect(try Self.matches(#"\.offset\(vm\.panOffset\)\s*#if\s+os\(macOS\)\s*\.background\s*\{\s*emptyCanvas\s*\}\s*#endif\s*\.gesture\(magnificationGesture\)"#,
                                 in: graphContent) == 1,
                "the Mac canvas does not lay emptyCanvas behind the graph, between .offset and the gestures")
    }

    // MARK: - Source reading

    /// The file at `relativePath` under the repository root.
    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// The masked body of the one declaration in `source` whose header is `header`.
    private static func body(_ header: String, in source: String) throws -> String {
        try #require(CodingStandardsAuditTests.maskedDeclarationBody(header, in: source),
                     "`\(header)` is not declared exactly once")
    }

    /// How many times `needle` occurs in `haystack`.
    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.ranges(of: needle).count
    }

    /// How many times the regular expression `pattern` matches `text`.
    private static func matches(_ pattern: String, in text: String) throws -> Int {
        try NSRegularExpression(pattern: pattern)
            .numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}

// MARK: - VolumeConnectionLabelTests (#1384)

/// The volume connection graph's side of #1384. It drew each label as the volume id's first ten
/// characters, unmarked and unplaced — the co-mention graph's two defects — and now draws through
/// the same `GraphNodeLabels` rules, whose own fixtures are `GraphNodeLabelTests`.
///
/// Version history:
///   1.0 — 2026-09-24: #1384
///   1.1 — 2026-09-24: #1384 review — the laid-out graphs hold the central label to the disc rule
///          and pin their counts
///   1.2 — 2026-09-24: #1384 review round 2 — by the owner's decision the central label is always
///          placed, on the one plate, which no partner label overlaps
@MainActor
struct VolumeConnectionLabelTests {

    @Test("The shipped limit draws every bundled volume id whole, and marks a longer id's cut")
    func theShippedLimitDrawsEveryBundledVolumeIdWhole() throws {
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self, from: Data(contentsOf: url))
        #expect(entries.count > 500, "read \(entries.count) manifest entries")
        let limit = VolumeConnectionGraphViewModel.labelLimit
        let cut = entries.map(\.volumeId).filter { GraphNodeLabels.shortLabel($0, limit: limit) != $0 }
        #expect(cut.isEmpty, "\(cut.count) volume id(s) drawn cut, e.g. \(cut.prefix(5))")
        // An id longer than any in the manifest — a side-loaded volume's, say — is cut hard, since
        // an id has no spaces, and the cut is marked.
        let long = "frus1969-76v99-longer-than-any-id"
        let drawn = GraphNodeLabels.shortLabel(long, limit: limit)
        #expect(drawn.hasSuffix("…"))
        #expect(drawn.count == limit)
    }

    @Test("Labels are ranked: the central volume, the displayed partner, then partners by references")
    func labelsAreRankedCentralDisplayedThenReferences() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "frus1961-63v05")
        // v01: 3 in + 4 out = 7; v02: 9 in; v03: 2 out; v04: 9 out, tied with v02 and after it by id.
        vm.inboundEdges = [
            VolumeConnectionEdge(sourceVolumeId: "frus1961-63v01", targetVolumeId: "frus1961-63v05", count: 3),
            VolumeConnectionEdge(sourceVolumeId: "frus1961-63v02", targetVolumeId: "frus1961-63v05", count: 9),
        ]
        vm.outboundEdges = [
            VolumeConnectionEdge(sourceVolumeId: "frus1961-63v05", targetVolumeId: "frus1961-63v01", count: 4),
            VolumeConnectionEdge(sourceVolumeId: "frus1961-63v05", targetVolumeId: "frus1961-63v03", count: 2),
            VolumeConnectionEdge(sourceVolumeId: "frus1961-63v05", targetVolumeId: "frus1961-63v04", count: 9),
        ]
        #expect(vm.labelPriority == ["frus1961-63v05", "frus1961-63v02", "frus1961-63v04",
                                     "frus1961-63v01", "frus1961-63v03"])
        vm.toggleSelection("frus1961-63v03")
        #expect(vm.labelPriority == ["frus1961-63v05", "frus1961-63v03", "frus1961-63v02",
                                     "frus1961-63v04", "frus1961-63v01"])
        vm.hoverChanged("frus1961-63v01", hovering: true)
        #expect(vm.labelPriority == ["frus1961-63v05", "frus1961-63v01", "frus1961-63v02",
                                     "frus1961-63v04", "frus1961-63v03"])
    }

    @Test("A node with no position or no measured size asks for no label")
    func aNodeWithNoPositionOrSizeAsksForNoLabel() {
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: "c")
        vm.inboundEdges = [VolumeConnectionEdge(sourceVolumeId: "a", targetVolumeId: "c", count: 2),
                           VolumeConnectionEdge(sourceVolumeId: "b", targetVolumeId: "c", count: 1)]
        vm.nodePositions = ["c": CGPoint(x: 200, y: 200), "a": CGPoint(x: 300, y: 200)]
        let size = CGSize(width: 40, height: 10)
        // "b" has a size and no position.
        #expect(vm.labelRequests(sizes: ["a": size, "b": size, "c": size]).map(\.id) == ["c", "a"])
        // "a" has a position and no size.
        #expect(vm.labelRequests(sizes: ["b": size, "c": size]).map(\.id) == ["c"])
        // Each request carries the radius the canvas draws the disc at.
        #expect(vm.labelRequests(sizes: ["a": size, "c": size]).map(\.radius)
                == [VolumeConnectionGraphViewModel.centralRadius, 18])
        vm.toggleSelection("a")
        #expect(vm.labelRequests(sizes: ["a": size, "c": size]).map(\.radius)
                == [VolumeConnectionGraphViewModel.centralRadius, 22])
    }

    /// One laid-out case: a canvas and how many of the 49 labels fit on it.
    struct LayoutCase: CustomTestStringConvertible, Sendable {
        /// The canvas.
        let canvas: CGSize
        /// Labels placed there, the central volume's counted.
        let placed: Int
        /// The case name Swift Testing shows.
        var testDescription: String { "\(Int(canvas.width)) × \(Int(canvas.height)) places \(placed)" }
    }

    @Test("Over a layout the graph produces, the central volume is labelled on its plate, and no partner label touches a label, the plate or a disc",
          arguments: [LayoutCase(canvas: CGSize(width: 700, height: 520), placed: 18),
                      LayoutCase(canvas: CGSize(width: 360, height: 420), placed: 11)])
    func aLaidOutGraphPlacesClearLabels(_ layoutCase: LayoutCase) {
        // Forty-eight partners of one Nixon–Ford volume, half citing it and half cited by it, with the
        // corpus's commonest id length (14 characters) — the ids the ten-character cut drew as one.
        let central = "frus1969-76v17"
        let vm = VolumeConnectionGraphViewModel(centralVolumeId: central)
        let partners = (1...48).map { String(format: "frus1969-76v%02d", $0 + 17) }
        vm.inboundEdges = partners.prefix(24).enumerated().map {
            VolumeConnectionEdge(sourceVolumeId: $0.element, targetVolumeId: central, count: 48 - $0.offset)
        }
        vm.outboundEdges = partners.suffix(24).enumerated().map {
            VolumeConnectionEdge(sourceVolumeId: central, targetVolumeId: $0.element, count: 24 - $0.offset)
        }
        // Reduce Motion settles the layout synchronously through the same `runPhysics` the view runs.
        vm.onCanvasSizeChanged(layoutCase.canvas, reduceMotion: true)
        #expect(vm.nodePositions.count == 49)

        var sizes: [String: CGSize] = [:]
        for id in vm.allVolumeIds {
            sizes[id] = GraphNodeLabelTests.estimatedSize(vm.label(for: id),
                                                          fontSize: id == central ? 9 : 8)
        }
        let requests = vm.labelRequests(sizes: sizes)
        let placed = GraphNodeLabels.place(requests)

        #expect(requests.count == 49)
        // Measured: in both layouts the central label keeps clear of every partner's disc. It is
        // placed whatever lies under it (the owner's decision), on the one plate, which no partner
        // label overlaps.
        let centralRect = GraphNodeLabels.labelRect(for: requests[0])
        let under = GraphNodeLabelTests.discsUnder(centralRect, of: central, requests: requests)
        #expect(under.isEmpty, "a partner's disc now lies under the central label: \(under)")
        #expect(placed[central] == centralRect)
        #expect(GraphNodeLabels.plate(for: requests, placed: placed)
                == GraphNodeLabels.plateRect(behind: centralRect))
        let overlaps = GraphNodeLabelTests.plateOverlaps(placed: placed, requests: requests)
        #expect(overlaps.isEmpty, "\(overlaps)")
        // Pinned, so the counts `labelLimit`'s comment states cannot drift unnoticed; the sizes are
        // `estimatedSize`'s, not a font's.
        #expect(placed.count == layoutCase.placed, "placed \(placed.count) of \(requests.count)")
        let violations = GraphNodeLabelTests.clearanceViolations(placed: placed, requests: requests)
        #expect(violations.isEmpty, "\(violations.count) violation(s): \(violations.prefix(5))")
    }
}

// MARK: - The info popover's gestures (#1481)

/// #1481 (lane WB): iPhone and iPad read the graph's "Navigating the graph" in touch gestures. One
/// shared key used to tell them to click and right-click. This reads what the iOS host's popover
/// is given; `CodingStandardsAuditTests.macClickVariantsStayOffIOS` holds the Mac branch apart.
///
/// Version history:
///   1.0 — 2026-09-30: #1481
@Suite("Cross-reference graph — interaction help")
struct CrossReferenceGraphHelpTests {

    @Test("On iOS the graph's help says long-press and pinch, not right-click (#1481)")
    @MainActor
    func helpNamesTouchGestures() {
        let help = CrossReferenceGraphView.interactHelp
        #expect(help.contains("Long-press to recenter"), "\(help)")
        #expect(help.contains("pinch-to-zoom"), "\(help)")
        #expect(!help.contains("Right-click"), "the touch text names a Mac gesture: \(help)")
    }
}
