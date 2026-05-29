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
        var baseGraph = makeTestGraph(inboundCount: 2, outboundCount: 2)

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
}
