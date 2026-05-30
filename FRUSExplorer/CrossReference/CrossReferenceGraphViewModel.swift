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

/// A node visible in the cross-reference graph canvas.
struct DisplayNode: Identifiable, Sendable {
    enum Kind: Sendable {
        case central
        case inbound
        case outbound
        /// A node reachable in 2 or more hops from the central document.
        case extended
        case clusterInbound(volumeId: String, count: Int)
        case clusterOutbound(volumeId: String, count: Int)
    }

    let id: String   // nodeKey ("volId/docId") or cluster key ("cluster/inbound/volId")
    let kind: Kind
    let metadata: CrossReferenceNodeMetadata?
    let isDownloaded: Bool
    /// Shortest hop distance from the central node (0 for central, 1 for direct neighbours, 2+ for extended).
    let degree: Int

    /// Designated initializer. `degree` defaults to 1 so that pre-existing call sites
    /// (tests and cluster builders) that do not specify degree remain valid.
    init(
        id: String,
        kind: Kind,
        metadata: CrossReferenceNodeMetadata?,
        isDownloaded: Bool,
        degree: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.metadata = metadata
        self.isDownloaded = isDownloaded
        self.degree = degree
    }

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
        case .extended:
            String(
                format: String(localized: "graph.a11y.extended %@ %lld",
                               defaultValue: "Degree %2$lld: %1$@"),
                metadata?.header ?? id, Int64(degree)
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
struct DisplayEdge: Identifiable, Sendable {
    /// Stable identity for use in `ForEach` and `selectedEdgeKey` lookups.
    var id: String { "\(source)->\(target)" }
    let source: String
    let target: String
    let referenceType: ReferenceType
    /// Plain text of the footnote or editorial note that contained the `<ref>`.
    /// `nil` when the reference was not inside a note block, or for edges indexed
    /// before Session 37 populated this column.
    let context: String?
    /// The degree of this edge: 1 for direct (inbound/outbound), 2+ for extended.
    /// Defaults to 1 so pre-existing call sites remain valid.
    let degree: Int

    init(
        source: String,
        target: String,
        referenceType: ReferenceType,
        context: String?,
        degree: Int = 1
    ) {
        self.source = source
        self.target = target
        self.referenceType = referenceType
        self.context = context
        self.degree = degree
    }
}

// MARK: - CrossReferenceGraphViewModel

// MARK: - NavigationHistoryEntry

/// One step in the cross-reference graph's interactive navigation history.
struct NavigationHistoryEntry: Sendable {
    let documentId: String
    let volumeId: String
    /// Display header, if already loaded when this entry was pushed.
    let header: String?
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
/// ## Degree Expansion
/// `graphDegree` controls how many hops from the central document are loaded:
/// - **1** (default) — direct inbound and outbound references only.
/// - **2** — additionally loads edges for each 1st-degree node (capped at 20 nodes).
/// - **3** — extends further from 2nd-degree nodes (capped at 15).
/// Extended nodes render as `.extended` (grey) and with thinner, lighter edges.
///
/// ## Interactive Re-centering
/// Clicking a non-cluster node on macOS (or second-tapping on iOS) calls `recenterOn`,
/// which pushes the current central document onto `history`, updates the central identity,
/// resets layout state, and re-loads the ego graph for the new centre. `navigateBack()`
/// pops the previous entry and re-centres without pushing to history (going back).
///
/// All mutable state is `@MainActor`-isolated. The layout algorithms are `nonisolated static`
/// so they can be called from off-actor contexts (animated task) and unit tests.
///
/// Version history:
///   1.0 — Session 18: initial implementation
///   1.1 — Session 37: `DisplayEdge.context` added; `contextForSelectedNode()` helper
///          surfaces footnote text in the info panel
///   1.2 — Interactive re-centering: mutable central identity, history stack,
///          `recenterOn()`, `navigateBack()`; macOS navigateToNode re-centres instead
///          of pushing to navigationPath
///   1.3 — Session 129: `graphDegree` (1/2/3) for multi-hop expansion; node labels;
///          edge context-snippet labels; `DisplayNode.Kind.extended`; `DisplayEdge.degree`
///   1.4 — Session 130: removed `GraphFilterMode`/`filterMode`; added `selectedEdgeKey`;
///          fixed `rerunLayout` to force-direct whenever extended nodes are present
@Observable
@MainActor
final class CrossReferenceGraphViewModel {

    // MARK: - Identity

    /// Mutable so `recenterOn` can replace the central document without creating a new VM instance.
    var centralDocumentId: String
    var centralVolumeId: String

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

    // MARK: - Selection

    /// Key of the edge currently selected (hovered or tapped). Format: `"src->tgt"`.
    /// `nil` when no edge is selected. Setting this clears `selectedNodeKey`.
    var selectedEdgeKey: String?

    // MARK: - Cluster

    var expandedClusterKeys: Set<String> = []

    // MARK: - Degree Expansion

    /// Number of reference hops to display (1 = direct neighbours only, 2 or 3 = extended).
    var graphDegree: Int = 1

    // MARK: - Navigation History

    /// Documents visited before the current central document, oldest-first.
    /// Populated by `recenterOn`; drained by `navigateBack`.
    var history: [NavigationHistoryEntry] = []

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
        let degree = graphDegree
        do {
            graph = try await store.expandedGraph(
                forDocumentId: centralDocumentId,
                volumeId: centralVolumeId,
                degree: degree,
                downloadedVolumeIds: downloadedVolumeIds
            )
            rebuildDisplay()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false

        #if DEBUG
        print("[CrossReferenceGraph] Loaded \(displayNodes.count) nodes, \(displayEdges.count) edges (degree=\(degree)) for \(centralKey)")
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

    /// iOS: first tap selects node (shows info panel); second tap re-centres on that document.
    /// The info panel's "View Document" button remains the path for inline document navigation.
    func tapNode(_ key: String, reduceMotion: Bool) {
        guard let node = displayNodes.first(where: { $0.id == key }) else { return }
        if node.isCluster {
            toggleCluster(key)
            return
        }
        if selectedNodeKey == key {
            // Second tap — re-centre on the tapped document.
            guard let meta = graph?.nodeMetadata[key] else { return }
            recenterOn(documentId: meta.documentId, volumeId: meta.volumeId, header: meta.header)
        } else {
            selectedNodeKey = key
        }
    }

    /// macOS: click re-centres the graph on the clicked document (hover already showed the info panel).
    /// Cluster nodes still expand/collapse rather than re-centring.
    func navigateToNode(_ key: String) {
        guard let node = displayNodes.first(where: { $0.id == key }) else { return }
        if node.isCluster {
            toggleCluster(key)
            return
        }
        guard let meta = graph?.nodeMetadata[key] else { return }
        recenterOn(documentId: meta.documentId, volumeId: meta.volumeId, header: meta.header)
    }

    /// Replaces the central document with `(documentId, volumeId)`, pushes the current
    /// centre onto `history`, resets all layout state, and reloads the ego graph.
    func recenterOn(documentId: String, volumeId: String, header: String?) {
        history.append(NavigationHistoryEntry(
            documentId: centralDocumentId,
            volumeId:   centralVolumeId,
            header:     graph?.nodeMetadata[centralKey]?.header
        ))
        resetGraphState(documentId: documentId, volumeId: volumeId)
        Task { await loadGraph() }
    }

    /// Pops the most-recent history entry and re-centres on it without pushing to history.
    func navigateBack() {
        guard let prev = history.popLast() else { return }
        resetGraphState(documentId: prev.documentId, volumeId: prev.volumeId)
        Task { await loadGraph() }
    }

    private func resetGraphState(documentId: String, volumeId: String) {
        centralDocumentId   = documentId
        centralVolumeId     = volumeId
        graph               = nil
        displayNodes        = []
        displayEdges        = []
        nodePositions       = [:]
        selectedNodeKey     = nil
        selectedEdgeKey     = nil
        expandedClusterKeys = []
        layoutTask?.cancel()
        isAnimatingLayout   = false
        // graphDegree is intentionally preserved so the user's expansion preference
        // survives re-centering on a different document.
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
    /// For extended nodes, returns the context of any edge that connects to or from the node.
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
        case .extended:
            // Return context from any edge touching this node that has context available.
            return displayEdges.first(where: {
                ($0.source == key || $0.target == key) && $0.context != nil
            })?.context
        default:
            return nil
        }
    }

    /// Returns the edge whose `id` matches `selectedEdgeKey`, or `nil` if none.
    func selectedEdge() -> DisplayEdge? {
        guard let key = selectedEdgeKey else { return nil }
        return displayEdges.first { $0.id == key }
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

        // Use force-directed layout when the graph is large OR when extended (degree 2+)
        // nodes are present.  The three-column `standardLayout` does not place extended
        // nodes, so they would be invisible without this override.
        let hasExtended = displayNodes.contains { if case .extended = $0.kind { true } else { false } }
        let useForce = displayNodes.count > 21 || hasExtended
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
    ///
    /// Extended edges (degree ≥ 2) are added after degree-1 edges. Extended nodes
    /// not already present in the degree-1 set are given `.extended` kind.
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
                isDownloaded: downloadedVolumeIds.contains(graph.centralVolumeId),
                degree: 0
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
                                isDownloaded: downloadedVolumeIds.contains(e.sourceVolumeId),
                                degree: 1))
                            edges.append(DisplayEdge(source: key, target: centralKey,
                                referenceType: e.referenceType, context: e.context, degree: 1))
                        }
                    } else {
                        nodes.append(DisplayNode(id: clusterKey,
                            kind: .clusterInbound(volumeId: vol, count: volEdges.count),
                            metadata: nil,
                            isDownloaded: downloadedVolumeIds.contains(vol),
                            degree: 1))
                        edges.append(DisplayEdge(source: clusterKey, target: centralKey,
                            referenceType: .footnote, context: nil, degree: 1))
                    }
                }
            } else {
                for e in inboundEdges {
                    let key = "\(e.sourceVolumeId)/\(e.sourceDocumentId)"
                    nodes.append(DisplayNode(id: key, kind: .inbound,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: downloadedVolumeIds.contains(e.sourceVolumeId),
                        degree: 1))
                    edges.append(DisplayEdge(source: key, target: centralKey,
                        referenceType: e.referenceType, context: e.context, degree: 1))
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
                                isDownloaded: downloadedVolumeIds.contains(e.targetVolumeId),
                                degree: 1))
                            edges.append(DisplayEdge(source: centralKey, target: key,
                                referenceType: e.referenceType, context: e.context, degree: 1))
                        }
                    } else {
                        nodes.append(DisplayNode(id: clusterKey,
                            kind: .clusterOutbound(volumeId: vol, count: volEdges.count),
                            metadata: nil,
                            isDownloaded: downloadedVolumeIds.contains(vol),
                            degree: 1))
                        edges.append(DisplayEdge(source: centralKey, target: clusterKey,
                            referenceType: .footnote, context: nil, degree: 1))
                    }
                }
            } else {
                for e in outboundEdges {
                    let key = "\(e.targetVolumeId)/\(e.targetDocumentId)"
                    nodes.append(DisplayNode(id: key, kind: .outbound,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: downloadedVolumeIds.contains(e.targetVolumeId),
                        degree: 1))
                    edges.append(DisplayEdge(source: centralKey, target: key,
                        referenceType: e.referenceType, context: e.context, degree: 1))
                }
            }
        }

        addInbound(graph.inboundEdges)
        addOutbound(graph.outboundEdges)

        // --- Extended edges (degree 2+) ---
        if !graph.extendedEdges.isEmpty {
            var addedNodeKeys: Set<String> = Set(nodes.map(\.id))

            for extEdge in graph.extendedEdges {
                let srcKey = "\(extEdge.sourceVolumeId)/\(extEdge.sourceDocumentId)"
                let tgtKey = "\(extEdge.targetVolumeId)/\(extEdge.targetDocumentId)"

                // Determine degree of each endpoint.
                // A node that was already present at degree 1 is still degree 1.
                // A new node connected to a degree-1 node is degree 2.
                // A new node connected only to other new nodes is degree 3+.
                for key in [srcKey, tgtKey] where !addedNodeKeys.contains(key) {
                    addedNodeKeys.insert(key)
                    nodes.append(DisplayNode(
                        id: key, kind: .extended,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: {
                            let vPart = key.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
                            return downloadedVolumeIds.contains(vPart)
                        }(),
                        degree: graph.fetchedDegree
                    ))
                }

                // Only add the edge if both endpoints are present.
                edges.append(DisplayEdge(
                    source: srcKey, target: tgtKey,
                    referenceType: extEdge.referenceType, context: extEdge.context,
                    degree: graph.fetchedDegree
                ))
            }
        }

        return (nodes, edges)
    }
}
