// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - Supporting Types

/// Toolbar filter mode for the cross-reference graph view.
enum GraphFilterMode: String, CaseIterable, Sendable {
    case unfiltered
    case custom
    case projectLevel

    var label: String {
        switch self {
        case .unfiltered:   return String(localized: "graph.filter.unfiltered",   defaultValue: "All")
        case .custom:       return String(localized: "graph.filter.custom",       defaultValue: "Custom")
        case .projectLevel: return String(localized: "graph.filter.projectLevel", defaultValue: "Project")
        }
    }
}

/// A node visible in the cross-reference graph canvas.
struct DisplayNode: Identifiable, Sendable {
    enum Kind: Sendable {
        case central
        case inbound
        case outbound
        case clusterInbound(volumeId: String, count: Int)
        case clusterOutbound(volumeId: String, count: Int)
    }

    let id: String   // nodeKey ("volId/docId") or cluster key ("cluster/inbound/volId")
    let kind: Kind
    let metadata: CrossReferenceNodeMetadata?
    let isDownloaded: Bool

    var isCentral: Bool { if case .central = kind { true } else { false } }

    var isCluster: Bool {
        switch kind {
        case .clusterInbound, .clusterOutbound: true
        default: false
        }
    }

    var accessibilityLabel: String {
        switch kind {
        case .central:
            metadata?.header ?? id
        case .inbound:
            String(
                format: String(localized: "graph.a11y.inbound %@", defaultValue: "Inbound: %@"),
                metadata?.header ?? id
            )
        case .outbound:
            String(
                format: String(localized: "graph.a11y.outbound %@", defaultValue: "Outbound: %@"),
                metadata?.header ?? id
            )
        case .clusterInbound(let vol, let count):
            String(
                format: String(localized: "graph.a11y.clusterInbound %lld %@",
                               defaultValue: "%lld inbound documents from volume %@"),
                Int64(count), vol
            )
        case .clusterOutbound(let vol, let count):
            String(
                format: String(localized: "graph.a11y.clusterOutbound %lld %@",
                               defaultValue: "%lld outbound documents to volume %@"),
                Int64(count), vol
            )
        }
    }
}

/// A directed edge to render in the cross-reference graph canvas.
struct DisplayEdge: Sendable {
    let source: String
    let target: String
    let referenceType: ReferenceType
    /// Plain text of the footnote or editorial note that contained the `<ref>`.
    /// `nil` when the reference was not inside a note block, or for edges indexed
    /// before Session 37 populated this column.
    let context: String?
}

// MARK: - CrossReferenceGraphViewModel

/// ViewModel for the cross-reference graph view.
///
/// Loads the `CrossReferenceGraph` from `CrossReferenceStore`, computes display nodes
/// and edges (with optional volume-based clustering for large graphs), and runs the
/// appropriate layout algorithm:
///   - **Standard layout** (≤20 cross-references): three-column static distribution.
///   - **Force-directed layout** (21–100): iterative spring-repulsion simulation;
///     animated settling unless system Reduce Motion is active.
///
/// All mutable state is `@MainActor`-isolated. The layout algorithms are `nonisolated static`
/// so they can be called from off-actor contexts (animated task) and unit tests.
///
/// Version history:
///   1.0 — Session 18: initial implementation
///   1.1 — Session 37: `DisplayEdge.context` added; `contextForSelectedNode()` helper
///          surfaces footnote text in the info panel
@Observable
@MainActor
final class CrossReferenceGraphViewModel {

    // MARK: - Identity

    let centralDocumentId: String
    let centralVolumeId: String

    // MARK: - Data

    var graph: CrossReferenceGraph?
    var isLoading = false
    var error: String?

    // MARK: - Display

    var displayNodes: [DisplayNode] = []
    var displayEdges: [DisplayEdge] = []
    var nodePositions: [String: CGPoint] = [:]

    // MARK: - Interaction

    var selectedNodeKey: String?
    var scale: CGFloat = 1.0
    var panOffset: CGSize = .zero
    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Filter & Cluster

    var filterMode: GraphFilterMode = .unfiltered
    var expandedClusterKeys: Set<String> = []

    // MARK: - Animation state (readable by tests)

    /// `true` while the force-directed settling animation task is running.
    private(set) var isAnimatingLayout = false

    // MARK: - Private

    private let crossReferenceStore: CrossReferenceStore?
    private let downloadedVolumeIds: Set<String>
    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>?

    // MARK: - Init

    /// Production init.
    init(
        centralDocumentId: String,
        centralVolumeId: String,
        crossReferenceStore: CrossReferenceStore,
        downloadedVolumeIds: Set<String>
    ) {
        self.centralDocumentId = centralDocumentId
        self.centralVolumeId = centralVolumeId
        self.crossReferenceStore = crossReferenceStore
        self.downloadedVolumeIds = downloadedVolumeIds
    }

    /// Testing init — no store; set `graph` directly then call `rebuildDisplay()`.
    init(
        centralDocumentId: String,
        centralVolumeId: String,
        downloadedVolumeIds: Set<String> = []
    ) {
        self.centralDocumentId = centralDocumentId
        self.centralVolumeId = centralVolumeId
        self.crossReferenceStore = nil
        self.downloadedVolumeIds = downloadedVolumeIds
    }

    // MARK: - Derived

    var hasUndownloadedSources: Bool { graph?.hasUndownloadedSources ?? false }
    var centralKey: String { "\(centralVolumeId)/\(centralDocumentId)" }

    // MARK: - Public API

    func loadGraph() async {
        guard let store = crossReferenceStore else { return }
        isLoading = true
        error = nil
        do {
            graph = try await store.graph(
                forDocumentId: centralDocumentId,
                volumeId: centralVolumeId,
                downloadedVolumeIds: downloadedVolumeIds
            )
            rebuildDisplay()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false

        #if DEBUG
        print("[CrossReferenceGraph] Loaded \(displayNodes.count) nodes, \(displayEdges.count) edges for \(centralKey)")
        #endif
    }

    func onCanvasSizeChanged(_ size: CGSize, reduceMotion: Bool) {
        canvasSize = size
        if !displayNodes.isEmpty && size.width > 0 && size.height > 0 {
            rerunLayout(reduceMotion: reduceMotion)
        }
    }

    func selectNode(_ key: String?) {
        selectedNodeKey = key
    }

    /// iOS: first tap selects node (shows info panel); second tap navigates.
    func tapNode(_ key: String, reduceMotion: Bool) {
        guard let node = displayNodes.first(where: { $0.id == key }) else { return }
        if node.isCluster {
            toggleCluster(key)
            return
        }
        if selectedNodeKey == key {
            if let entry = makeEntry(for: key) {
                navigationPath.append(entry)
            }
            selectedNodeKey = nil
        } else {
            selectedNodeKey = key
        }
    }

    /// macOS: click navigates immediately (hover already showed the info panel).
    func navigateToNode(_ key: String) {
        guard let node = displayNodes.first(where: { $0.id == key }) else { return }
        if node.isCluster {
            toggleCluster(key)
            return
        }
        if let entry = makeEntry(for: key) {
            navigationPath.append(entry)
        }
        selectedNodeKey = nil
    }

    func toggleCluster(_ key: String) {
        if expandedClusterKeys.contains(key) {
            expandedClusterKeys.remove(key)
        } else {
            expandedClusterKeys.insert(key)
        }
        rebuildDisplay()
    }

    func makeEntry(for nodeKey: String) -> DocumentBrowserEntry? {
        guard let meta = graph?.nodeMetadata[nodeKey],
              let header = meta.header else { return nil }
        return DocumentBrowserEntry(
            documentId: meta.documentId,
            volumeId: meta.volumeId,
            documentNumber: meta.documentNumber,
            header: header,
            dateline: meta.dateline,
            sourceNote: nil
        )
    }

    /// Returns the edge context text for the currently selected node, if any.
    ///
    /// For inbound nodes the context is the text of the footnote in the source document
    /// that contained the `<ref>` pointing to the central document.
    /// For outbound nodes it is the text from the central document's footnote.
    /// Returns `nil` for cluster nodes, the central node, or edges without context.
    func contextForSelectedNode() -> String? {
        guard let key = selectedNodeKey,
              let node = displayNodes.first(where: { $0.id == key }),
              !node.isCentral, !node.isCluster else { return nil }
        switch node.kind {
        case .inbound:
            return displayEdges.first(where: { $0.source == key && $0.target == centralKey })?.context
        case .outbound:
            return displayEdges.first(where: { $0.source == centralKey && $0.target == key })?.context
        default:
            return nil
        }
    }

    /// Returns the node key for the first node whose centre is within its hit radius of `point`.
    func nodeAt(point: CGPoint) -> String? {
        for node in displayNodes {
            guard let pos = nodePositions[node.id] else { continue }
            let r: CGFloat = node.isCentral ? 24 : 18
            let dx = pos.x - point.x, dy = pos.y - point.y
            if sqrt(dx * dx + dy * dy) <= r + 4 { return node.id }
        }
        return nil
    }

    // MARK: - Internal (accessible to tests)

    func rebuildDisplay() {
        guard let graph else {
            displayNodes = []; displayEdges = []; nodePositions = [:]; return
        }
        let (nodes, edges) = Self.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: expandedClusterKeys,
            downloadedVolumeIds: downloadedVolumeIds
        )
        displayNodes = nodes
        displayEdges = edges

        if canvasSize.width > 0 && canvasSize.height > 0 {
            rerunLayout(reduceMotion: true)
        }
    }

    // MARK: - Private layout

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        isAnimatingLayout = false

        let useForce = displayNodes.count > 21
        let nodes = displayNodes
        let edges = displayEdges
        let central = centralKey
        let size = canvasSize

        if !useForce {
            nodePositions = Self.standardLayout(nodes: nodes, centralKey: central, canvasSize: size)
            return
        }

        let initial = Self.initialPositions(nodes: nodes, centralKey: central, canvasSize: size)

        if reduceMotion {
            nodePositions = Self.forceDirectedLayout(
                nodes: nodes, edges: edges,
                initialPositions: initial,
                centralKey: central, canvasSize: size, iterations: 200
            )
            return
        }

        // Animated settling: run in batches, yielding to the main thread each frame.
        // Each batch runs 20 iterations (~1 visual frame of progress).
        nodePositions = initial
        isAnimatingLayout = true
        layoutTask = Task { [weak self] in
            var current = initial
            for _ in 0..<10 {
                guard !Task.isCancelled else { break }
                current = CrossReferenceGraphViewModel.forceDirectedLayout(
                    nodes: nodes, edges: edges,
                    initialPositions: current,
                    centralKey: central, canvasSize: size, iterations: 20
                )
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.nodePositions = current
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
            await MainActor.run { [weak self] in self?.isAnimatingLayout = false }
        }
    }

    // MARK: - Layout algorithms (nonisolated static for testability)

    /// Three-column static layout for graphs with ≤20 cross-references.
    /// Inbound nodes fill the left column, outbound the right, central is centred.
    /// Minimum 60 pt vertical separation is enforced between nodes in each column.
    static func standardLayout(
        nodes: [DisplayNode],
        centralKey: String,
        canvasSize: CGSize
    ) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let cx = canvasSize.width / 2, cy = canvasSize.height / 2
        positions[centralKey] = CGPoint(x: cx, y: cy)

        let inbound  = nodes.filter { if case .inbound = $0.kind { true }
                                      else if case .clusterInbound = $0.kind { true }
                                      else { false } }
        let outbound = nodes.filter { if case .outbound = $0.kind { true }
                                      else if case .clusterOutbound = $0.kind { true }
                                      else { false } }
        let minSep: CGFloat = 60

        func placeColumn(_ col: [DisplayNode], x: CGFloat) {
            guard !col.isEmpty else { return }
            if col.count == 1 {
                positions[col[0].id] = CGPoint(x: x, y: cy)
                return
            }
            let step = max(minSep, (canvasSize.height - 60) / CGFloat(col.count + 1))
            let totalH = step * CGFloat(col.count - 1)
            let startY = cy - totalH / 2
            for (i, node) in col.enumerated() {
                positions[node.id] = CGPoint(x: x, y: startY + CGFloat(i) * step)
            }
        }

        placeColumn(inbound,  x: canvasSize.width / 4)
        placeColumn(outbound, x: canvasSize.width * 3 / 4)
        return positions
    }

    /// Distributes nodes on a circle around the centre as starting positions
    /// for the force-directed solver.
    static func initialPositions(
        nodes: [DisplayNode],
        centralKey: String,
        canvasSize: CGSize
    ) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let cx = canvasSize.width / 2, cy = canvasSize.height / 2
        let r = min(canvasSize.width, canvasSize.height) * 0.35
        positions[centralKey] = CGPoint(x: cx, y: cy)
        let others = nodes.filter { $0.id != centralKey }
        for (i, node) in others.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(max(others.count, 1))
            positions[node.id] = CGPoint(
                x: cx + r * CGFloat(cos(angle)),
                y: cy + r * CGFloat(sin(angle))
            )
        }
        return positions
    }

    /// Force-directed spring-repulsion layout.
    ///
    /// **Physics model**:
    /// - **Spring force** (connected node pairs): `F = k_s × (d − L₀)` where `d` is the
    ///   current distance and `L₀` is the rest length. Attractive when `d > L₀`.
    /// - **Repulsion force** (all node pairs): `F = k_r / d²`. Always repulsive.
    /// - **Central node** is pinned to the canvas centre — no force is applied to it.
    /// - **Damped velocity integration**: `v ← (v + F × dt) × damping`, then `p ← p + v`.
    ///   Positions are clamped to canvas bounds each iteration.
    static func forceDirectedLayout(
        nodes: [DisplayNode],
        edges: [DisplayEdge],
        initialPositions: [String: CGPoint],
        centralKey: String,
        canvasSize: CGSize,
        iterations: Int
    ) -> [String: CGPoint] {
        let k_s:     CGFloat = 0.012   // spring constant
        let L0:      CGFloat = 120     // spring rest length (pt)
        let k_r:     CGFloat = 5_000   // repulsion constant
        let damping: CGFloat = 0.85
        let dt:      CGFloat = 1.0
        let pad:     CGFloat = 32

        var pos = initialPositions
        var vel: [String: CGVector] = nodes.reduce(into: [:]) { $0[$1.id] = .zero }
        let ids = nodes.map(\.id)
        let edgePairs = edges.map { ($0.source, $0.target) }

        for _ in 0..<iterations {
            var forces: [String: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

            // Spring forces between connected nodes.
            for (src, tgt) in edgePairs {
                guard let ps = pos[src], let pt = pos[tgt] else { continue }
                let dx = pt.x - ps.x, dy = pt.y - ps.y
                let d = max(hypot(dx, dy), 1)
                let f = k_s * (d - L0)
                let ux = dx / d, uy = dy / d
                forces[src]?.dx += ux * f;  forces[src]?.dy += uy * f
                forces[tgt]?.dx -= ux * f;  forces[tgt]?.dy -= uy * f
            }

            // Repulsion between all node pairs.
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let pa = pos[ids[i]], let pb = pos[ids[j]] else { continue }
                    let dx = pa.x - pb.x, dy = pa.y - pb.y
                    let d = max(hypot(dx, dy), 1)
                    let f = k_r / (d * d)
                    let ux = dx / d, uy = dy / d
                    forces[ids[i]]?.dx += ux * f;  forces[ids[i]]?.dy += uy * f
                    forces[ids[j]]?.dx -= ux * f;  forces[ids[j]]?.dy -= uy * f
                }
            }

            // Integrate velocity and position (central node stays pinned).
            for id in ids where id != centralKey {
                guard var v = vel[id], var p = pos[id], let f = forces[id] else { continue }
                v.dx = (v.dx + f.dx * dt) * damping
                v.dy = (v.dy + f.dy * dt) * damping
                p.x  = max(pad, min(canvasSize.width  - pad, p.x + v.dx))
                p.y  = max(pad, min(canvasSize.height - pad, p.y + v.dy))
                vel[id] = v;  pos[id] = p
            }
        }
        return pos
    }

    // MARK: - Display node builder (static for testability)

    /// Computes the `DisplayNode` and `DisplayEdge` arrays from a `CrossReferenceGraph`.
    /// When `totalEdges > 30`, same-volume nodes are collapsed into cluster nodes unless
    /// their key is in `expandedClusterKeys`.
    static func buildDisplayNodesAndEdges(
        graph: CrossReferenceGraph,
        centralKey: String,
        expandedClusterKeys: Set<String>,
        downloadedVolumeIds: Set<String>
    ) -> (nodes: [DisplayNode], edges: [DisplayEdge]) {
        let threshold = 30
        let useClusters = graph.inboundEdges.count + graph.outboundEdges.count > threshold

        var nodes: [DisplayNode] = [
            DisplayNode(
                id: centralKey, kind: .central,
                metadata: graph.nodeMetadata[centralKey],
                isDownloaded: downloadedVolumeIds.contains(graph.centralVolumeId)
            )
        ]
        var edges: [DisplayEdge] = []

        func addInbound(_ inboundEdges: [CrossReferenceEdge]) {
            if useClusters {
                let byVol = Dictionary(grouping: inboundEdges, by: \.sourceVolumeId)
                for (vol, volEdges) in byVol.sorted(by: { $0.key < $1.key }) {
                    let clusterKey = "cluster/inbound/\(vol)"
                    if expandedClusterKeys.contains(clusterKey) {
                        for e in volEdges {
                            let key = "\(e.sourceVolumeId)/\(e.sourceDocumentId)"
                            nodes.append(DisplayNode(id: key, kind: .inbound,
                                metadata: graph.nodeMetadata[key],
                                isDownloaded: downloadedVolumeIds.contains(e.sourceVolumeId)))
                            edges.append(DisplayEdge(source: key, target: centralKey,
                                referenceType: e.referenceType, context: e.context))
                        }
                    } else {
                        nodes.append(DisplayNode(id: clusterKey,
                            kind: .clusterInbound(volumeId: vol, count: volEdges.count),
                            metadata: nil,
                            isDownloaded: downloadedVolumeIds.contains(vol)))
                        edges.append(DisplayEdge(source: clusterKey, target: centralKey,
                            referenceType: .footnote, context: nil))
                    }
                }
            } else {
                for e in inboundEdges {
                    let key = "\(e.sourceVolumeId)/\(e.sourceDocumentId)"
                    nodes.append(DisplayNode(id: key, kind: .inbound,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: downloadedVolumeIds.contains(e.sourceVolumeId)))
                    edges.append(DisplayEdge(source: key, target: centralKey,
                        referenceType: e.referenceType, context: e.context))
                }
            }
        }

        func addOutbound(_ outboundEdges: [CrossReferenceEdge]) {
            if useClusters {
                let byVol = Dictionary(grouping: outboundEdges, by: \.targetVolumeId)
                for (vol, volEdges) in byVol.sorted(by: { $0.key < $1.key }) {
                    let clusterKey = "cluster/outbound/\(vol)"
                    if expandedClusterKeys.contains(clusterKey) {
                        for e in volEdges {
                            let key = "\(e.targetVolumeId)/\(e.targetDocumentId)"
                            nodes.append(DisplayNode(id: key, kind: .outbound,
                                metadata: graph.nodeMetadata[key],
                                isDownloaded: downloadedVolumeIds.contains(e.targetVolumeId)))
                            edges.append(DisplayEdge(source: centralKey, target: key,
                                referenceType: e.referenceType, context: e.context))
                        }
                    } else {
                        nodes.append(DisplayNode(id: clusterKey,
                            kind: .clusterOutbound(volumeId: vol, count: volEdges.count),
                            metadata: nil,
                            isDownloaded: downloadedVolumeIds.contains(vol)))
                        edges.append(DisplayEdge(source: centralKey, target: clusterKey,
                            referenceType: .footnote, context: nil))
                    }
                }
            } else {
                for e in outboundEdges {
                    let key = "\(e.targetVolumeId)/\(e.targetDocumentId)"
                    nodes.append(DisplayNode(id: key, kind: .outbound,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: downloadedVolumeIds.contains(e.targetVolumeId)))
                    edges.append(DisplayEdge(source: centralKey, target: key,
                        referenceType: e.referenceType, context: e.context))
                }
            }
        }

        addInbound(graph.inboundEdges)
        addOutbound(graph.outboundEdges)
        return (nodes, edges)
    }
}
