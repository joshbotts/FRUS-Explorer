// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

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
///   1.5 — Session 161: hover state (`hoveredNodeKey`/`hoveredEdgeKey`) separated from
///          pinned click selection so the macOS info panel survives the pointer
///          travelling to its buttons; cumulative pan/zoom (`steadyScale`/
///          `steadyPanOffset`) so consecutive gestures no longer snap back
///   1.6 — #1799: a node dated by a span is labelled with it, its volume's at the precision of
///          years, and placed at its middle; `makeEntry` gives a page node no entry, since its id
///          names a page
///   1.7 — #1764: `forceDirectedLayout` is Fruchterman–Reingold with a cutoff, scaled to the
///          canvas, and its animated batches follow one cooling schedule; `labelPriority` orders
///          the canvas's labels; `precedesInReferenceList` orders the reference list, with
///          `DisplayNode.documentId` and `isPageNode`
///   1.8 — 2026-11-10 (FRUS Explorer Light, S23b): the display half is FRUSCoreKit's
///          (`CrossReferenceGraphDisplay`, `FRUSCoreKit/CrossReference/CrossReferenceGraphDisplay.swift`):
///          `DisplayNode`, `DisplayEdge`, `GraphLayoutMode` and `TimelineTick` with the display build,
///          the date labels and values, the date clustering, the timeline layout and the reference
///          list's order, `Double` for `CGFloat`; this model calls them with its state, as it called
///          its own statics, and turns the timeline's positions into the `CGPoint`s it publishes.
///          The sparse widening, the unit nodes, their attachment and `timelineEligible` call the
///          kit's rules where their code was inline; `precedesInReferenceList` forwards to the kit's;
///          `loadUnprintedUnits`' doc drops the gloss's paragraphs, which `classGloss` carries in the kit
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

    /// Nodes currently rendered by the canvas. In timeline mode these may
    /// contain `.dateCluster` placeholders standing in for groups of
    /// `baseDisplayNodes`; in network mode they equal the base arrays.
    var displayNodes: [DisplayNode] = []
    var displayEdges: [DisplayEdge] = []
    var nodePositions: [String: CGPoint] = [:]

    /// The unclustered build output: every real document node and aggregated
    /// edge, regardless of timeline date-clustering. The reference list panel
    /// reads these so it always lists actual documents.
    private(set) var baseDisplayNodes: [DisplayNode] = []
    private(set) var baseDisplayEdges: [DisplayEdge] = []

    /// Total corpus-wide reference count per node key (inbound + outbound), loaded
    /// after the graph itself so the layout appears immediately and node sizes
    /// refine when the counts arrive. Drives `nodeRadius(for:)`.
    private(set) var nodeConnectionCounts: [String: Int] = [:]

    /// Unprinted archival units the graph's documents point at (#837), by document node key.
    ///
    /// Fetched AFTER the layout is on screen, like `nodeConnectionCounts` beside it: the join
    /// decodes a ~2 MB authority, and a graph that waited for it would be blank for that long.
    /// Nodes appear when it lands; nothing already drawn moves, because unit nodes attach to
    /// positions the layout has already assigned.
    /// Settable rather than `private(set)` for the same reason `graph` is: the display build
    /// that consumes it is the part with the logic, and a test that cannot seed the input
    /// cannot drive it.
    var unitsByDocument: [String: [DisplayNode]] = [:]

    /// Pre-formatted short date label per node key ("Mar 4, 1962", "Mar 1962", or
    /// "1962"), derived from `CrossReferenceNodeMetadata.dateISO` once per rebuild
    /// so the Canvas draw loop never touches a `DateFormatter`.
    private(set) var nodeDateLabels: [String: String] = [:]

    /// Numeric date per node key (`timeIntervalSinceReferenceDate`), parsed from
    /// `dateISO` once per rebuild. Drives the timeline layout's x positions.
    /// Year-only and year-month dates resolve to the start of their period.
    private(set) var nodeDateValues: [String: TimeInterval] = [:]

    // MARK: - Layout mode

    /// Current layout mode. Defaults to `.timeline` when the loaded graph has
    /// enough dated nodes (see `timelineEligible`); the user's explicit choice
    /// (via `setLayoutMode`) is respected across re-centres.
    var layoutMode: GraphLayoutMode = .network

    /// `true` once the user has explicitly chosen a layout mode, which stops
    /// `rebuildDisplay` from auto-selecting one.
    private var userPickedLayoutMode = false

    /// Ticks for the timeline layout's date axis; empty in network mode.
    private(set) var timelineTicks: [TimelineTick] = []

    /// Y position of the timeline layout's date axis in canvas coordinates.
    private(set) var timelineAxisY: CGFloat = 0

    /// `true` when the timeline layout has parked undated/cluster nodes in the
    /// trailing-edge column (the canvas draws an "Undated" caption above it).
    private(set) var timelineHasParkedNodes = false

    /// Whether the current graph can be laid out chronologically: the central
    /// document and at least two other non-cluster nodes need parseable dates
    /// spanning a non-zero interval.
    var timelineEligible: Bool {
        CrossReferenceGraphDisplay.isTimelineEligible(centralKey: centralKey, dateValues: nodeDateValues,
                                                      nodes: displayNodes)
    }

    /// Sets the layout mode from the toolbar picker and re-runs the layout.
    func setLayoutMode(_ mode: GraphLayoutMode, reduceMotion: Bool) {
        guard mode != layoutMode else { return }
        layoutMode = mode
        userPickedLayoutMode = true
        if canvasSize.width > 0 && canvasSize.height > 0 {
            rerunLayout(reduceMotion: reduceMotion)
        }
    }

    // MARK: - Interaction

    /// Key of the node the user has *pinned* by clicking (macOS) or tapping (iOS).
    /// A pinned selection keeps the info panel visible until explicitly dismissed,
    /// so the pointer can travel to the panel's buttons without losing it.
    /// Transient pointer-hover state lives in `hoveredNodeKey` instead.
    var selectedNodeKey: String?

    /// Key of the node currently under the pointer (macOS hover). Transient: cleared
    /// as soon as the pointer leaves the node. Never set on iOS. Display code should
    /// read `resolvedNodeKey`, which combines hover and pinned state.
    var hoveredNodeKey: String?

    /// Pinch-to-zoom magnification applied to the canvas, clamped to `0.25...4.0`.
    /// `1.0` is the neutral/initial value — the layout's own coordinates (in
    /// `nodePositions`) are rendered at their natural scale.
    ///
    /// During a pinch this holds `steadyScale × gestureValue` (see
    /// `magnificationChanged(_:)`); `magnificationEnded()` commits it back into
    /// `steadyScale` so consecutive pinches accumulate instead of snapping back
    /// to the 1.0 baseline.
    var scale: CGFloat = 1.0

    /// Pan translation applied to the canvas, in canvas points. `.zero` is the
    /// neutral/initial value (canvas centred on the pinned central node).
    /// During a drag this holds `steadyPanOffset + gestureTranslation` (see
    /// `panChanged(_:)`); `panEnded()` commits it so consecutive drags accumulate.
    var panOffset: CGSize = .zero

    /// Committed zoom level carried between magnification gestures. See `scale`.
    private(set) var steadyScale: CGFloat = 1.0

    /// Committed pan offset carried between drag gestures. See `panOffset`.
    private(set) var steadyPanOffset: CGSize = .zero

    var navigationPath: [DocumentBrowserEntry] = []

    // MARK: - Selection

    /// Key of the edge the user has *pinned* by clicking/tapping its midpoint hit
    /// area. Format: `"src->tgt"`. `nil` when no edge is pinned. Setting this should
    /// be accompanied by clearing `selectedNodeKey` (they are mutually exclusive).
    /// Transient pointer-hover state lives in `hoveredEdgeKey` instead.
    var selectedEdgeKey: String?

    /// Key of the edge whose midpoint hit area is currently under the pointer
    /// (macOS hover). Transient; never set on iOS. Display code should read
    /// `resolvedEdgeKey`.
    var hoveredEdgeKey: String?

    // MARK: - Resolved selection

    /// The edge key the info panel and canvas highlighting should treat as active.
    ///
    /// **Pinned state always wins over hover.** Live testing (Session 162) showed
    /// the opposite priority made the UI feel dead: a hover that never received
    /// its exit event — synthetic pointer moves, or the pointer parking on a hit
    /// area — masked every subsequent click. Hover is a preview that only applies
    /// when nothing is pinned; clicks additionally clear hover state at the call
    /// sites so a stale hover can never linger past an explicit action.
    var resolvedEdgeKey: String? {
        if selectedEdgeKey != nil { return selectedEdgeKey }
        if selectedNodeKey != nil { return nil }
        if let hovered = hoveredEdgeKey { return hovered }
        return nil
    }

    /// The node key the info panel and canvas highlighting should treat as active.
    /// Mirror of `resolvedEdgeKey`: pinned wins, hover previews only when nothing
    /// is pinned, and an active edge suppresses the node so the two are mutually
    /// exclusive.
    var resolvedNodeKey: String? {
        if selectedEdgeKey != nil { return nil }
        if let pinned = selectedNodeKey { return pinned }
        if hoveredEdgeKey != nil { return nil }
        return hoveredNodeKey
    }

    // MARK: - Cluster

    var expandedClusterKeys: Set<String> = []

    /// Date clusters the user has expanded in place (timeline mode). Layout-level
    /// state: toggling re-runs the layout pass, not the data build.
    private(set) var expandedDateClusterKeys: Set<String> = []

    /// Expands or collapses a timeline date cluster in place.
    func toggleDateCluster(_ key: String) {
        if expandedDateClusterKeys.contains(key) {
            expandedDateClusterKeys.remove(key)
        } else {
            expandedDateClusterKeys.insert(key)
        }
        refreshLayout()
    }

    /// If `nodeKey` is currently hidden inside a collapsed date cluster, expands
    /// that cluster so the node becomes visible (used when the reference list
    /// selects a document the canvas has folded away).
    func expandDateClusterContaining(_ nodeKey: String) {
        guard layoutMode == .timeline,
              !displayNodes.contains(where: { $0.id == nodeKey }) else { return }
        let containing = displayNodes.first { node in
            if case .dateCluster(_, _, let members) = node.kind {
                return members.contains(nodeKey)
            }
            return false
        }
        guard let cluster = containing else { return }
        expandedDateClusterKeys.insert(cluster.id)
        refreshLayout()
    }

    /// Re-runs the current layout (without re-querying the store) when layout
    /// inputs like date-cluster expansion or the timeline brush change.
    func refreshLayout() {
        if canvasSize.width > 0 && canvasSize.height > 0 {
            rerunLayout(reduceMotion: true)
        }
    }

    // MARK: - Timeline brush

    /// Date window the user has brushed (timeline mode, Session 162): the layout
    /// restricts its x-domain to this range — the axis zooms in and dated nodes
    /// outside the window disappear. `nil` shows the full range.
    private(set) var timelineBrushRange: ClosedRange<TimeInterval>?

    /// Full extent of the graph's dated nodes; the brush strip maps against
    /// this regardless of the current zoom.
    var timelineFullDateRange: ClosedRange<TimeInterval>? {
        let values = nodeDateValues.values
        guard let lower = values.min(), let upper = values.max(), upper > lower else {
            return nil
        }
        return lower...upper
    }

    /// Sets (or clears, with `nil`) the brushed date window and re-lays-out.
    func setTimelineBrush(_ range: ClosedRange<TimeInterval>?) {
        timelineBrushRange = range
        refreshLayout()
    }

    // MARK: - Degree Expansion

    /// Number of reference hops to display (1 = direct neighbours only, 2 or 3 = extended).
    var graphDegree: Int = 1

    /// `true` when the current graph was automatically widened to 2 hops because
    /// the direct neighbourhood was sparse (1–3 references). The degree picker
    /// still shows the user's chosen value; a toolbar note explains the expansion.
    private(set) var autoExpandedSparseGraph = false

    /// Set once the user manually changes the degree picker; disables sparse
    /// auto-expansion for the rest of the session so the picker is never
    /// second-guessed.
    private var userAdjustedDegree = false

    /// Called by the view when the degree picker changes. Records that the user
    /// has taken manual control of the degree, then reloads.
    func degreePickerChanged() {
        userAdjustedDegree = true
        Task { await loadGraph() }
    }

    // MARK: - Navigation History

    /// Documents visited before the current central document, oldest-first.
    /// Populated by `recenterOn`; drained by `navigateBack`.
    var history: [NavigationHistoryEntry] = []

    // MARK: - Animation state (readable by tests)

    /// `true` while the force-directed settling animation task is running.
    private(set) var isAnimatingLayout = false

    // MARK: - Private

    private let crossReferenceStore: CrossReferenceStore?
    /// The pipeline, for the unprinted-pointer fetch only (#837). Optional and separate from
    /// `crossReferenceStore` because the testing init has neither, and because the graph is
    /// fully usable without it — a missing pipeline means no unit nodes, not a broken graph.
    private let indexingPipeline: IndexingPipeline?
    private let downloadedVolumeIds: Set<String>
    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>?

    // MARK: - Init

    /// Production init.
    init(
        centralDocumentId: String,
        centralVolumeId: String,
        crossReferenceStore: CrossReferenceStore,
        indexingPipeline: IndexingPipeline? = nil,
        downloadedVolumeIds: Set<String>
    ) {
        self.centralDocumentId = centralDocumentId
        self.centralVolumeId = centralVolumeId
        self.crossReferenceStore = crossReferenceStore
        self.indexingPipeline = indexingPipeline
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
        self.indexingPipeline = nil
        self.downloadedVolumeIds = downloadedVolumeIds
    }

    // MARK: - Derived

    var hasUndownloadedSources: Bool { graph?.hasUndownloadedSources ?? false }

    /// Volumes citing the central document that the reader has not downloaded (#262), sorted.
    var undownloadedCitingVolumeIds: [String] { graph?.undownloadedCitingVolumeIds ?? [] }

    /// How many citing documents live in those volumes — the figure the banner leads with,
    /// because it is what tells the reader how much is missing rather than merely that some is.
    var undownloadedCitingCount: Int {
        guard let graph else { return 0 }
        let missing = Set(graph.undownloadedCitingVolumeIds)
        return graph.inboundEdges.count { missing.contains($0.sourceVolumeId) }
    }
    var centralKey: String { "\(centralVolumeId)/\(centralDocumentId)" }

    // MARK: - Public API

    func loadGraph() async {
        guard let store = crossReferenceStore else { return }
        isLoading = true
        error = nil
        let degree = graphDegree
        do {
            var loaded = try await store.expandedGraph(
                forDocumentId: centralDocumentId,
                volumeId: centralVolumeId,
                degree: degree,
                downloadedVolumeIds: downloadedVolumeIds
            )
            // Sparse auto-expansion: a 1–3 reference star is the most common (and
            // least informative) first impression, so widen it one hop. The degree
            // *picker* keeps showing the user's chosen value — this only affects
            // the loaded data, and never fires once the user has touched the picker.
            var autoExpanded = false
            if !userAdjustedDegree,
               CrossReferenceGraphDisplay.widensSparseGraph(loadedAtDegree: degree, edgeCount: loaded.edgeCount) {
                let widened = try await store.expandedGraph(
                    forDocumentId: centralDocumentId,
                    volumeId: centralVolumeId,
                    degree: 2,
                    downloadedVolumeIds: downloadedVolumeIds
                )
                if CrossReferenceGraphDisplay.keepsWidenedGraph(widened, over: loaded) {
                    loaded = widened
                    autoExpanded = true
                }
            }
            graph = loaded
            autoExpandedSparseGraph = autoExpanded
            rebuildDisplay()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false

        #if DEBUG
        print("[CrossReferenceGraph] Loaded \(displayNodes.count) nodes, \(displayEdges.count) edges (degree=\(degree)) for \(centralKey)")
        #endif

        // Connection counts arrive after the layout is already on screen; node
        // radii refine in place when the dictionary updates.
        if let graph {
            let keys = graph.nodeMetadata.values.map {
                (volumeId: $0.volumeId, documentId: $0.documentId)
            }
            nodeConnectionCounts = (try? await store.connectionCounts(forKeys: keys)) ?? [:]
            await loadUnprintedUnits(keys: keys)
        }
    }

    /// Fetches every graph document's unprinted pointers and turns them into unit nodes (#837).
    ///
    /// ## Why this covers "expanded nodes too" without a per-node mechanic
    /// `graph.nodeMetadata` already holds the central document, its direct neighbours, and the
    /// degree-2/3 endpoints, and a degree change is a full `loadGraph()` rather than an
    /// incremental fetch. So one pass over that key set is the whole requirement; cluster
    /// expansion is display-only and needs nothing.
    ///
    /// ## What is deliberately dropped
    /// A citation that does not join to an authority record becomes NO node. #837 is explicit —
    /// unmatched citations stay off the graph rather than being drawn as guesses — and the
    /// corpus generator joins 96% at aggregate grain, so misses are certain at this one. A node
    /// the reader cannot open, standing for a match the app did not make, would be a guess drawn
    /// as a finding.
    ///
    /// Several documents citing the same unit produce several nodes, one per citing document:
    /// the edge is what carries meaning here, and a shared node would imply the two documents
    /// are related to each other rather than to the same archive.
    private func loadUnprintedUnits(keys: [(volumeId: String, documentId: String)]) async {
        guard let pipeline = indexingPipeline else { unitsByDocument = [:]; return }
        var rowsByDocument: [String: [ExternalCitation]] = [:]
        for key in keys {
            let rows = (try? await pipeline.externalCitations(volumeId: key.volumeId,
                                                              documentId: key.documentId)) ?? []
            guard !rows.isEmpty else { continue }
            rowsByDocument["\(key.volumeId)/\(key.documentId)"] = rows
        }
        guard !rowsByDocument.isEmpty else { unitsByDocument = [:]; return }
        let snapshot = rowsByDocument
        unitsByDocument = await Task.detached(priority: .userInitiated) {
            guard let authority = CollectionAuthorityStore.shared else { return [:] }
            return CrossReferenceGraphDisplay.unitNodes(rowsByDocument: snapshot, authority: authority)
        }.value
        rebuildDisplay()
    }

    // MARK: - Node sizing

    /// The sizing rule itself, as a pure function of what a node is and how connected it is.
    ///
    /// **Split out of ``nodeRadius(for:)`` so it can be driven at a connection count the app has
    /// not yet fetched.** The counts arrive asynchronously into `nodeConnectionCounts`, which is
    /// `private(set)`, so a test going through the instance method sees every document node at the
    /// same size and cannot reach the cap below. Measured: with the rule inline, raising that cap
    /// from 22 to 30 — above the central node's fixed 24, which would have let a well-connected
    /// document out-size the centre of its own graph — passed the suite unnoticed.
    ///
    /// `nonisolated` because it is arithmetic: it reads nothing from the view model.
    nonisolated static func radius(for kind: DisplayNode.Kind, connectionCount: Int) -> CGFloat {
        switch kind {
        case .central:
            return 24
        case .clusterInbound, .clusterOutbound:
            return 18
        case .dateCluster(_, let count, _):
            // Slightly larger than a document node, growing gently with size.
            return min(16 + 2 * log2(CGFloat(max(count, 2))), 24)
        case .inbound, .outbound, .extended, .unit, .centralFileClass:
            let count  = max(connectionCount, 1)
            let radius = 12.0 + 3.0 * log2(CGFloat(count) + 1)
            let cap: CGFloat
            if case .extended = kind { cap = 18 } else { cap = 22 }
            return min(max(radius, 12), cap)
        }
    }

    // MARK: - Label priority (#1764)

    /// The order the canvas offers node labels to `GraphNodeLabels.place(_:avoiding:settling:)`
    /// (#1764), which places each where it keeps clear of the labels before it and of every disc,
    /// and draws the first, the central document's, whatever lies under it, on its plate.
    ///
    /// After the central document come the node the reader has selected or points at, then its
    /// neighbours, then volume and date clusters, whose labels carry their counts, then every other
    /// node: the most connected first, as the canvas sizes it, then the nearest in hops, then in
    /// the reference list's order (``precedesInReferenceList(_:_:)``), which makes the order total.
    ///
    /// Until #1764 the canvas drew every node's label on a graph of 40 nodes or fewer, overlapping
    /// or not, and above 40 only the central, cluster and focused nodes' labels. A17's archival nodes
    /// and A18b's pages took `frus1952-54v02p1` d16 at three hops to 247 nodes, and the iPad capture
    /// labelled the focus alone.
    /// - Parameters:
    ///   - nodes: The nodes the canvas draws.
    ///   - connectionCounts: Each document's corpus-wide connection count, which sizes its disc.
    ///   - selectedKey: The node selected or pointed at, or `nil`.
    ///   - focusKeys: The selected node and its neighbours, or `nil` when nothing is selected.
    /// - Returns: Every node's id, highest priority first.
    nonisolated static func labelPriority(nodes: [DisplayNode], connectionCounts: [String: Int],
                                          selectedKey: String?, focusKeys: Set<String>?) -> [String] {
        func tier(_ node: DisplayNode) -> Int {
            if node.isCentral { return 0 }
            if node.id == selectedKey { return 1 }
            if focusKeys?.contains(node.id) ?? false { return 2 }
            if node.isCluster || node.isDateCluster { return 3 }
            return 4
        }
        return nodes.sorted { a, b in
            let ta = tier(a), tb = tier(b)
            if ta != tb { return ta < tb }
            let ca = connectionCounts[a.id] ?? 0, cb = connectionCounts[b.id] ?? 0
            if ca != cb { return ca > cb }
            if a.degree != b.degree { return a.degree < b.degree }
            return precedesInReferenceList(a, b)
        }.map(\.id)
    }

    /// One placement request per drawn node, for `GraphNodeLabels.place(_:avoiding:settling:)`
    /// (#1764): the nodes with a label in `order`, then the nodes without one (an archival unit, a
    /// central-file class) at no size, so every label keeps clear of their discs and none gives way
    /// to them. The first node in `order`, the central document, stays first whether or not it has a
    /// label, since the first request is placed whatever lies under it. A node with no position is
    /// left out, since the canvas draws neither its disc nor its label.
    /// - Parameters:
    ///   - order: Every node's id, highest priority first (``labelPriority(focusKeys:)``).
    ///   - positions: Each node's position on the canvas.
    ///   - radii: Each node's disc radius as drawn; 18 pt where none is given.
    ///   - sizes: Each labelled node's measured label block; a node with none has no label.
    /// - Returns: The requests, highest priority first.
    nonisolated static func labelRequests(order: [String], positions: [String: CGPoint],
                                          radii: [String: CGFloat],
                                          sizes: [String: CGSize]) -> [GraphLabelRequest<String>] {
        var labelled: [GraphLabelRequest<String>] = []
        var unlabelled: [GraphLabelRequest<String>] = []
        for (rank, id) in order.enumerated() {
            guard let center = positions[id] else { continue }
            let radius = radii[id] ?? 18
            if let size = sizes[id] {
                labelled.append(GraphLabelRequest(id: id, center: center, radius: radius, size: size))
            } else if rank == 0 {
                labelled.append(GraphLabelRequest(id: id, center: center, radius: radius, size: .zero))
            } else {
                unlabelled.append(GraphLabelRequest(id: id, center: center, radius: radius, size: .zero))
            }
        }
        return labelled + unlabelled
    }

    /// ``labelPriority(nodes:connectionCounts:selectedKey:focusKeys:)`` over the canvas's nodes, with
    /// the node selected or pointed at.
    /// - Parameter focusKeys: The selected node and its neighbours, or `nil`.
    /// - Returns: Every displayed node's id, highest priority first.
    func labelPriority(focusKeys: Set<String>?) -> [String] {
        Self.labelPriority(nodes: displayNodes, connectionCounts: nodeConnectionCounts,
                           selectedKey: resolvedNodeKey, focusKeys: focusKeys)
    }

    /// Visual radius for a node. Central and cluster nodes have fixed sizes;
    /// document nodes scale logarithmically with their corpus-wide connection
    /// count so heavily referenced documents read as hubs at a glance.
    func nodeRadius(for node: DisplayNode) -> CGFloat {
        Self.radius(for: node.kind, connectionCount: nodeConnectionCounts[node.id] ?? 1)
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
        if node.isDateCluster {
            toggleDateCluster(key)
            return
        }
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
        if node.isDateCluster {
            toggleDateCluster(key)
            return
        }
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
        hoveredNodeKey      = nil
        hoveredEdgeKey      = nil
        nodeConnectionCounts = [:]
        nodeDateLabels      = [:]
        nodeDateValues      = [:]
        baseDisplayNodes    = []
        baseDisplayEdges    = []
        timelineTicks       = []
        timelineHasParkedNodes = false
        autoExpandedSparseGraph = false
        expandedClusterKeys = []
        expandedDateClusterKeys = []
        timelineBrushRange  = nil
        // layoutMode and userPickedLayoutMode survive re-centring, like graphDegree:
        // an explicit Timeline/Network choice is a session preference.
        layoutTask?.cancel()
        isAnimatingLayout   = false
        // graphDegree is intentionally preserved so the user's expansion preference
        // survives re-centering on a different document.

        // Re-centering on a new central node rebuilds the layout around it, but a
        // stale pinch/pan transform from the *previous* graph would still be applied
        // on top — potentially leaving the brand-new central node off-screen before
        // the user has even seen it. Resetting the viewport here guarantees every
        // re-centre starts from a clean, predictable view.
        resetViewport(animated: false)
    }

    /// Restores the pan/zoom viewport to its neutral initial state — `scale = 1.0`,
    /// `panOffset = .zero` — re-centring the canvas on the (always-pinned) central
    /// node at its natural size.
    ///
    /// `magnificationChanged`/`panChanged` have no bounds-clamping or rubber-banding,
    /// so an inadvertent pinch or drag can leave the central node arbitrarily far
    /// off-screen; this is the recovery path. Note that the underlying *layout*
    /// (`nodePositions`) never needs touching — the central node is always pinned
    /// to the canvas centre by the layout engine; only the view-level transform
    /// drifts, so resetting the transform state is sufficient and exact.
    ///
    /// - Parameter animated: When `true`, the change is wrapped in a gentle spring
    ///   animation so the view glides back rather than snapping; pass `false` for
    ///   silent resets that happen as a side effect of other state changes (e.g.
    ///   re-centring on a new document, where an additional animation would be
    ///   redundant with the graph-rebuild transition already underway).
    func resetViewport(animated: Bool) {
        guard scale != 1.0 || panOffset != .zero
                || steadyScale != 1.0 || steadyPanOffset != .zero else { return }
        steadyScale = 1.0
        steadyPanOffset = .zero
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scale = 1.0
                panOffset = .zero
            }
        } else {
            scale = 1.0
            panOffset = .zero
        }
    }

    // MARK: - Viewport gestures

    /// Applies an in-flight pinch gesture value on top of the committed zoom level.
    /// Called from the magnification gesture's `onChanged`.
    func magnificationChanged(_ value: CGFloat) {
        scale = Self.clampScale(steadyScale * value)
    }

    /// Commits the current zoom level so the next pinch starts from it rather than
    /// snapping back to the previous baseline. Called from `onEnded`.
    func magnificationEnded() {
        steadyScale = scale
    }

    /// Applies an in-flight drag translation on top of the committed pan offset.
    /// Called from the drag gesture's `onChanged`.
    func panChanged(_ translation: CGSize) {
        panOffset = CGSize(
            width:  steadyPanOffset.width  + translation.width,
            height: steadyPanOffset.height + translation.height
        )
    }

    /// Commits the current pan offset so the next drag continues from it.
    /// Called from `onEnded`.
    func panEnded() {
        steadyPanOffset = panOffset
    }

    /// Multiplies the committed zoom level by `factor` and applies it immediately.
    /// Used by discrete zoom inputs (scroll wheel on macOS) that have no
    /// changed/ended gesture phases.
    func zoom(by factor: CGFloat) {
        steadyScale = Self.clampScale(steadyScale * factor)
        scale = steadyScale
    }

    /// Clamps a zoom level to the supported `0.25...4.0` range.
    private static func clampScale(_ value: CGFloat) -> CGFloat {
        max(0.25, min(4.0, value))
    }

    func toggleCluster(_ key: String) {
        if expandedClusterKeys.contains(key) {
            expandedClusterKeys.remove(key)
        } else {
            expandedClusterKeys.insert(key)
        }
        rebuildDisplay()
    }

    /// The entry that opens a node's document, or `nil` for a node with no document to open: one
    /// with no header, and a page node (#1799), whose header is its title and whose id names a page.
    func makeEntry(for nodeKey: String) -> DocumentBrowserEntry? {
        guard let meta = graph?.nodeMetadata[nodeKey], meta.citedPage == nil,
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

    /// Returns the edge context text for the currently active node, if any.
    ///
    /// For inbound nodes the context is the text of the footnote in the source document
    /// that contained the `<ref>` pointing to the central document.
    /// For outbound nodes it is the text from the central document's footnote.
    /// For extended nodes, returns the context of any edge that connects to or from the node.
    /// Returns `nil` for cluster nodes, the central node, or edges without context.
    func contextForSelectedNode() -> String? {
        guard let key = resolvedNodeKey,
              let node = displayNodes.first(where: { $0.id == key }),
              !node.isCentral, !node.isCluster else { return nil }
        switch node.kind {
        case .inbound:
            return displayEdges.first(where: { $0.source == key && $0.target == centralKey })?.combinedContext
        case .outbound:
            return displayEdges.first(where: { $0.source == centralKey && $0.target == key })?.combinedContext
        case .extended:
            // Return context from any edge touching this node that has context available.
            return displayEdges.first(where: {
                ($0.source == key || $0.target == key) && !$0.contexts.isEmpty
            })?.combinedContext
        default:
            return nil
        }
    }

    /// Returns the edge whose `id` matches `resolvedEdgeKey` (hovered, else pinned),
    /// or `nil` if no edge is active.
    func selectedEdge() -> DisplayEdge? {
        guard let key = resolvedEdgeKey else { return nil }
        return displayEdges.first { $0.id == key }
    }

    /// The aggregated edge that links `nodeKey` to the central document — the
    /// inbound edge first, then the outbound one, then (for extended nodes) any
    /// edge touching the node. Used by the reference list to show per-row
    /// context snippets and reference counts. Searches the *base* (unclustered)
    /// edges so list rows keep their context even while their node is folded
    /// into a timeline date cluster.
    func primaryEdge(for nodeKey: String) -> DisplayEdge? {
        let edges = baseDisplayEdges.isEmpty ? displayEdges : baseDisplayEdges
        if let edge = edges.first(where: { $0.source == nodeKey && $0.target == centralKey }) {
            return edge
        }
        if let edge = edges.first(where: { $0.source == centralKey && $0.target == nodeKey }) {
            return edge
        }
        return edges.first { $0.source == nodeKey || $0.target == nodeKey }
    }

    /// Returns the node key for the first node whose centre is within its hit radius of `point`.
    func nodeAt(point: CGPoint) -> String? {
        for node in displayNodes {
            guard let pos = nodePositions[node.id] else { continue }
            let r = nodeRadius(for: node)
            let dx = pos.x - point.x, dy = pos.y - point.y
            if sqrt(dx * dx + dy * dy) <= r + 4 { return node.id }
        }
        return nil
    }

    // MARK: - Internal (accessible to tests)

    func rebuildDisplay() {
        guard let graph else {
            displayNodes = []; displayEdges = []; nodePositions = [:]
            baseDisplayNodes = []; baseDisplayEdges = []
            nodeDateLabels = [:]
            return
        }
        let built = CrossReferenceGraphDisplay.buildDisplayNodesAndEdges(
            graph: graph,
            centralKey: centralKey,
            expandedClusterKeys: expandedClusterKeys,
            downloadedVolumeIds: downloadedVolumeIds
        )
        // #837: the unit nodes hang off the document nodes the build kept, by citing document's key.
        let (nodes, edges) = CrossReferenceGraphDisplay.attachingUnits(unitsByDocument, to: built.nodes,
                                                                       edges: built.edges)
        baseDisplayNodes = nodes
        baseDisplayEdges = edges
        displayNodes = nodes
        displayEdges = edges
        nodeDateLabels = CrossReferenceGraphDisplay.buildDateLabels(for: nodes)
        nodeDateValues = CrossReferenceGraphDisplay.buildDateValues(for: nodes)

        // Chronology is the more meaningful default whenever the data supports it;
        // an explicit user choice (toolbar picker) is never overridden.
        if !userPickedLayoutMode {
            layoutMode = timelineEligible ? .timeline : .network
        }

        if canvasSize.width > 0 && canvasSize.height > 0 {
            rerunLayout(reduceMotion: true)
        }
    }

    // MARK: - Private layout

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        isAnimatingLayout = false

        // Timeline mode: deterministic chronological placement, no settling
        // animation needed (and therefore Reduce Motion is trivially respected).
        // Same-date pileups collapse into expandable date clusters first
        // (Session 162). Falls through to the network layout when the data
        // can't support chronology.
        // Tests (and any caller that seeds `displayNodes` directly) may not have
        // populated the base arrays; fall back to the current display set so a
        // relayout never silently empties the graph.
        let sourceNodes = baseDisplayNodes.isEmpty ? displayNodes : baseDisplayNodes
        let sourceEdges = baseDisplayEdges.isEmpty ? displayEdges : baseDisplayEdges

        if layoutMode == .timeline && timelineEligible {
            let clustered = CrossReferenceGraphDisplay.dateClusteredDisplay(
                nodes: sourceNodes,
                edges: sourceEdges,
                dateValues: nodeDateValues,
                canvasWidth: Double(canvasSize.width),
                expandedKeys: expandedDateClusterKeys,
                domain: timelineBrushRange
            )
            displayNodes = clustered.nodes
            displayEdges = clustered.edges
            let layoutDates = nodeDateValues.merging(clustered.clusterDateValues) { base, _ in base }
            let result = CrossReferenceGraphDisplay.timelineLayout(
                nodes: displayNodes,
                dateValues: layoutDates,
                centralKey: centralKey,
                canvasWidth: Double(canvasSize.width),
                canvasHeight: Double(canvasSize.height),
                domain: timelineBrushRange
            )
            nodePositions          = result.positions.mapValues { CGPoint(x: $0.x, y: $0.y) }
            timelineTicks          = result.ticks
            timelineAxisY          = CGFloat(result.axisY)
            timelineHasParkedNodes = result.hasParkedNodes
            return
        }
        displayNodes = sourceNodes
        displayEdges = sourceEdges
        timelineTicks = []
        timelineHasParkedNodes = false

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

        let total = Self.layoutIterations
        if reduceMotion {
            nodePositions = Self.forceDirectedLayout(
                nodes: nodes, edges: edges,
                initialPositions: initial,
                centralKey: central, canvasSize: size, iterations: total
            )
            return
        }

        // Animated settling: run in batches, yielding to the main thread each frame. The batches
        // take the one cooling schedule's steps in order (#1764), so the last frame is the layout
        // Reduce Motion draws at once.
        nodePositions = initial
        isAnimatingLayout = true
        layoutTask = Task { [weak self] in
            var current = initial
            let batches = CrossReferenceGraphViewModel.layoutBatches
            let perBatch = total / batches
            for batch in 0..<batches {
                guard !Task.isCancelled else { break }
                current = CrossReferenceGraphViewModel.forceDirectedLayout(
                    nodes: nodes, edges: edges,
                    initialPositions: current,
                    centralKey: central, canvasSize: size, iterations: perBatch,
                    startingAt: batch * perBatch, of: total
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

    /// How many steps the network layout takes to settle: all at once under Reduce Motion, or in
    /// `layoutBatches` batches published a frame apart.
    nonisolated static let layoutIterations = 200

    /// How many batches an animated network layout publishes, each `layoutIterations / layoutBatches`
    /// steps of the same cooling schedule, so its last frame is the layout Reduce Motion draws at once.
    nonisolated static let layoutBatches = 10

    /// The space the network layout keeps between a node's centre and the canvas's edge.
    nonisolated static let layoutPad: CGFloat = 32

    /// The longest ideal distance the network layout gives two nodes (#1764), however much canvas
    /// each node's share of it is. See `forceDirectedLayout`'s *The model*.
    nonisolated static let layoutMaximumDistance: CGFloat = 100

    /// How strongly the canvas's edges repel a node in the network layout, against a node of weight 1
    /// at the same distance (#1764). See `forceDirectedLayout`'s *The canvas's edges*.
    nonisolated static let layoutEdgeRepulsion: CGFloat = 0.5

    /// How much the central document and its direct references weigh in the network layout's
    /// repulsion, against 1 for every other node (#1764). See ``layoutWeight(for:)``.
    nonisolated static let directReferenceWeight: CGFloat = 4

    /// A node's weight in the network layout's repulsion (#1764): ``directReferenceWeight`` for the
    /// central document and the documents and volume clusters it cites or is cited by, which are what
    /// the graph is drawn around, and 1 for a node two or three hops out, an archival unit or a
    /// central-file class.
    /// - Parameter kind: The node's kind.
    /// - Returns: The weight.
    nonisolated static func layoutWeight(for kind: DisplayNode.Kind) -> CGFloat {
        switch kind {
        case .central, .inbound, .outbound, .clusterInbound, .clusterOutbound: return directReferenceWeight
        case .extended, .dateCluster, .unit, .centralFileClass: return 1
        }
    }

    /// The network layout: Fruchterman–Reingold, with its repulsion cut off at twice the ideal
    /// distance (#1764).
    ///
    /// **The model.** The ideal distance between nodes is `k = √(area / n)`, the side of each node's
    /// share of the canvas inside `layoutPad`, so a large graph settles to fill the canvas rather
    /// than outgrow it, and at most `layoutMaximumDistance`, so a small one does not spread to its
    /// edges: at three hops the Long Telegram (`frus1946v06` d475) has 37 nodes, a share 156 pt on a
    /// side, and uncapped it put 15 at an edge where the old layout put 8; capped at 100, tried with
    /// 160, 120 and 80, and with the edges' repulsion below, it puts none there and draws 31 of its
    /// 35 labels (measured in a harness port of this layout and of `GraphNodeLabels`, which gives
    /// d16's figures below exactly). Every edge attracts with `d² / k`. Two nodes of weights `wᵢ` and `wⱼ`
    /// (``layoutWeight(for:)``) repel with `k′² wᵢwⱼ / d` while closer than `2k′√(wᵢwⱼ)`, where
    /// `k′ = k / w̄` and `w̄` is the mean weight, so a graph whose nodes all weigh the same is laid
    /// out as plain Fruchterman–Reingold would lay it out. Each step moves a node along its net force
    /// by at most the temperature, which cools linearly from a tenth of the canvas's shorter side to
    /// nothing over `totalIterations`, so the layout comes to rest. The central node stays pinned at
    /// the centre.
    ///
    /// **What it replaced.** Until #1764 the layout was a damped spring–repulsion simulation with
    /// fixed constants (a 120 pt rest length, repulsion `5000 / d²` between all pairs), clamped to
    /// the canvas with the velocity left running into the wall. A graph of a few dozen nodes fitted;
    /// `frus1952-54v02p1` d16 at three hops has 247 since A17's archival nodes and A18b's pages: 155
    /// documents three hops out, 72 archival units, 9 central-file classes, and 152 of the 247 with
    /// one edge. All-pairs repulsion drove those leaves out to the clamp, the clamp caught each one
    /// where both its coordinates ran out, and two nodes on one point repel in no direction, so they
    /// never parted. Measured on S1's index at the iPad capture's 1055 × 861 pt canvas, in three
    /// orders of the graph's archival nodes (two launches', and the order `rebuildDisplay()` now
    /// fixes), 173 to 185 of the 247 settled in four stacks of up to 52 on the canvas's corners,
    /// drawn as four dark-ringed "hubs" with every edge running to them; 189 or 196 were at an edge,
    /// and 3,781 to 4,256 pairs of discs overlapped. This layout settles it, in the order
    /// `rebuildDisplay()` now fixes, with none at an edge and one overlapping pair, the closest two
    /// 19.5 pt apart. NSC 68 (`frus1950v01` d85) at three hops has 1,259 nodes: the old layout put
    /// 1,225 at an edge, 1,211 of them in four corner stacks of up to 337, and this one, measured in
    /// a harness port of it, puts none at an edge, though 1,259 discs on that canvas cannot all keep
    /// apart.
    ///
    /// **The cutoff** is the grid variant of Fruchterman and Reingold's own paper. Without it, the
    /// same model settled 175 of d16's nodes on the canvas's edges, if none in a stack: every node's
    /// repulsion reaches every leaf, whose one edge cannot hold it against them all. A pull towards
    /// the centre, tried with it, kept every node off the edges and crowded the middle instead.
    ///
    /// **The weights** give the central document's own references room for their labels. With every
    /// node weighing the same, d16's ten references settled in a knot around it, every one of their
    /// labels crowded out by a neighbour's disc (`GraphNodeLabels` keeps a label clear of every
    /// disc), and the labels that fitted were three hops out. Weighing them and the centre 4, chosen
    /// on that graph from 2 to 8, labels 7 of the 10 at the capture's canvas, where 24 labels are
    /// placed in all, and all 10 at the iPad's full width (the harness port). A node's degree as its weight, as
    /// ForceAtlas2 weighs it, labelled more but lined the canvas's edges with leaves.
    ///
    /// **The canvas's edges** repel a node within `2k′` of one, with `k′² / 2d` from the nearest
    /// point on it (`layoutEdgeRepulsion`), so the leaves pushed out of a large graph settle short of
    /// the edge rather than in a row along it, where the clamp held them with their discs
    /// overlapping. d16 at three hops put 19 nodes on the edges of the capture's 1055 × 861 pt canvas
    /// without it, and 33 in rows along the top and bottom of the iPad's full width, 1376 × 860; with
    /// it, none at either. Strengths of 1 and 2 cleared the edges too and labelled fewer.
    ///
    /// **Coincident nodes** are pushed apart along a direction fixed by their pair, so two nodes
    /// that land on one point (two leaves clamped at one corner) separate, where `dx / d` and
    /// `dy / d` alone are both zero, and the result stays the same from run to run.
    ///
    /// - Parameters:
    ///   - nodes: The nodes to place.
    ///   - edges: The edges that attract their ends; an edge to a node not in `nodes` is ignored.
    ///   - initialPositions: Where each node starts; a node with none starts at the centre.
    ///   - centralKey: The node pinned at the canvas's centre.
    ///   - canvasSize: The canvas, whose edges inset by `layoutPad` bound every node.
    ///   - iterations: How many steps to take.
    ///   - firstIteration: The step of the cooling schedule to start from, for an animated layout's
    ///     later batches.
    ///   - totalIterations: The schedule's length, `iterations` when `nil`. Batches that take a
    ///     schedule's steps in order end where one call taking all of them would.
    /// - Returns: Every node's position.
    static func forceDirectedLayout(
        nodes: [DisplayNode],
        edges: [DisplayEdge],
        initialPositions: [String: CGPoint],
        centralKey: String,
        canvasSize: CGSize,
        iterations: Int,
        startingAt firstIteration: Int = 0,
        of totalIterations: Int? = nil
    ) -> [String: CGPoint] {
        let count = nodes.count
        guard count > 0 else { return [:] }
        let schedule = CGFloat(max(totalIterations ?? iterations, 1))
        let pad = layoutPad
        let minX = pad, maxX = max(canvasSize.width - pad, pad)
        let minY = pad, maxY = max(canvasSize.height - pad, pad)
        let k = min((max(maxX - minX, 1) * max(maxY - minY, 1) / CGFloat(count)).squareRoot(),
                    layoutMaximumDistance)
        let weights = nodes.map { layoutWeight(for: $0.kind) }
        let repulsionK = k / (weights.reduce(0, +) / CGFloat(count))
        let repulsionKSquared = repulsionK * repulsionK
        let startTemperature = min(maxX - minX, maxY - minY) / 10

        // Arrays by index: the step is all pairs, and a dictionary lookup per pair cost seconds.
        let ids = nodes.map(\.id)
        let index = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        var x = ids.map { initialPositions[$0]?.x ?? centre.x }
        var y = ids.map { initialPositions[$0]?.y ?? centre.y }
        let pinned = index[centralKey]
        let springs: [(Int, Int)] = edges.compactMap { edge in
            guard let a = index[edge.source], let b = index[edge.target], a != b else { return nil }
            return (a, b)
        }
        var forceX = [CGFloat](repeating: 0, count: count)
        var forceY = [CGFloat](repeating: 0, count: count)
        /// The push away from one edge on a node `gap` points from it, nothing beyond `2k′`.
        func edgeRepulsion(_ gap: CGFloat) -> CGFloat {
            let d = max(gap, 0.5)
            return d < 2 * repulsionK ? layoutEdgeRepulsion * repulsionKSquared / d : 0
        }

        for step in firstIteration..<(firstIteration + max(iterations, 0)) {
            let temperature = startTemperature * max(0, 1 - CGFloat(step) / schedule)
            for i in 0..<count { forceX[i] = 0; forceY[i] = 0 }

            // Repulsion between every pair within reach, which grows with the pair's weight.
            for i in 0..<count {
                for j in (i + 1)..<count {
                    let weight = weights[i] * weights[j]
                    var dx = x[i] - x[j], dy = y[i] - y[j]
                    var d = (dx * dx + dy * dy).squareRoot()
                    if d < 0.01 {
                        // A direction fixed by the pair: the golden angle times a number of its own.
                        let angle = (CGFloat(i * count + j) * 2.399_963_229_728_653)
                            .truncatingRemainder(dividingBy: 2 * .pi)
                        dx = cos(angle) * 0.01; dy = sin(angle) * 0.01; d = 0.01
                    }
                    guard d < 2 * repulsionK * weight.squareRoot() else { continue }
                    let f = repulsionKSquared * weight / d
                    let fx = dx / d * f, fy = dy / d * f
                    forceX[i] += fx; forceY[i] += fy
                    forceX[j] -= fx; forceY[j] -= fy
                }
            }

            // Attraction along every edge.
            for (a, b) in springs {
                let dx = x[a] - x[b], dy = y[a] - y[b]
                let d = max((dx * dx + dy * dy).squareRoot(), 0.01)
                let f = d * d / k
                let fx = dx / d * f, fy = dy / d * f
                forceX[a] -= fx; forceY[a] -= fy
                forceX[b] += fx; forceY[b] += fy
            }

            // The canvas's edges, each repelling a node from its nearest point on it.
            for i in 0..<count {
                let gaps = (x[i] - minX, maxX - x[i], y[i] - minY, maxY - y[i])
                forceX[i] += edgeRepulsion(gaps.0) - edgeRepulsion(gaps.1)
                forceY[i] += edgeRepulsion(gaps.2) - edgeRepulsion(gaps.3)
            }

            // Each node moves along its force by at most the temperature, inside the canvas.
            for i in 0..<count where i != pinned {
                let length = (forceX[i] * forceX[i] + forceY[i] * forceY[i]).squareRoot()
                guard length > 0 else { continue }
                let scale = min(length, temperature) / length
                x[i] = min(maxX, max(minX, x[i] + forceX[i] * scale))
                y[i] = min(maxY, max(minY, y[i] + forceY[i] * scale))
            }
        }

        var positions: [String: CGPoint] = [:]
        for (i, id) in ids.enumerated() { positions[id] = CGPoint(x: x[i], y: y[i]) }
        return positions
    }

    // MARK: - Reference list order (#1764)

    /// Whether `a` comes before `b` in a section of the reference list, and in the graph's VoiceOver
    /// list: the kit's ``CrossReferenceGraphDisplay/precedesInReferenceList(_:_:)``, under the name the
    /// view, the reference list and ``labelPriority(nodes:connectionCounts:selectedKey:focusKeys:)`` call.
    nonisolated static func precedesInReferenceList(_ a: DisplayNode, _ b: DisplayNode) -> Bool {
        CrossReferenceGraphDisplay.precedesInReferenceList(a, b)
    }
}
