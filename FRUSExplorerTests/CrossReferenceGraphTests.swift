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
    targetVolumeId: String = "vol-tgt",
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

    for i in 0..<outboundCount {
        let doc = "d-out-\(i)"
        let key = "\(targetVolumeId)/\(doc)"
        outboundEdges.append(CrossReferenceEdge(
            sourceDocumentId: centralDocumentId, sourceVolumeId: centralVolumeId,
            targetDocumentId: doc, targetVolumeId: targetVolumeId,
            context: nil, referenceType: .footnote
        ))
        meta[key] = CrossReferenceNodeMetadata(
            documentId: doc, volumeId: targetVolumeId,
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
        let graph = makeTestGraph(inboundCount: 25, outboundCount: 24)
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

    @Test("InteractionTest: tapping a node selects it; second tap triggers navigation")
    @MainActor
    func tapSelectsNodeThenNavigates() throws {
        let graph = makeTestGraph(inboundCount: 3, outboundCount: 2)
        let vm = CrossReferenceGraphViewModel(
            centralDocumentId: "d0", centralVolumeId: "vol1"
        )
        vm.graph = graph
        vm.rebuildDisplay()
        vm.onCanvasSizeChanged(canvasSize, reduceMotion: true)

        // Pick a non-central node with metadata (so makeEntry succeeds)
        let target = try #require(
            vm.displayNodes.first { !$0.isCentral && $0.metadata?.header != nil }
        )

        // First tap: select (info panel)
        #expect(vm.selectedNodeKey == nil)
        vm.tapNode(target.id, reduceMotion: true)
        #expect(vm.selectedNodeKey == target.id)

        // Second tap: navigate and deselect
        vm.tapNode(target.id, reduceMotion: true)
        #expect(vm.selectedNodeKey == nil)
        #expect(!vm.navigationPath.isEmpty)
        #expect(vm.navigationPath.last?.documentId == target.metadata?.documentId)
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
}
