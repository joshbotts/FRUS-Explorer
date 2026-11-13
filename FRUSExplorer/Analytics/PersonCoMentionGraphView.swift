// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - GraphNodeLabels: the plate

/// The app's half of `GraphNodeLabels`, which is FRUSCoreKit's (`FRUSCoreKit/Analytics/GraphNodeLabels.swift`):
/// the plate is drawn into SwiftUI's `GraphicsContext`, so its drawing stays here.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): `drawPlate(_:in:)` out of `GraphNodeLabels`,
///          unchanged, when the label rules moved into FRUSCoreKit
extension GraphNodeLabels {

    /// Draws the centre label's plate: the background at 85% opacity, with rounded corners, so the
    /// label stays legible over the disc or edges under it. The canvases draw it after every node
    /// and before any label.
    /// - Parameters:
    ///   - context: The canvas to draw into.
    ///   - plate: The plate's rect, from `plate(for:placed:)`.
    static func drawPlate(_ context: inout GraphicsContext, in plate: CGRect) {
        context.fill(Path(roundedRect: plate, cornerRadius: 3),
                     with: .style(BackgroundStyle().opacity(0.85)))
    }
}

// MARK: - PersonCoMentionGraphViewModel

/// ViewModel for the person co-mention ego graph (CA-8).
///
/// Loads the focus person's top-N co-mentioned partners plus the partner-partner
/// co-mention edges from `PersonMentionStore`, then runs a pinned spring-repulsion layout
/// (a parallel of `VolumeConnectionGraphViewModel.runPhysics` — the two graph views each
/// carry their own layout engine; there is no shared engine to refactor into). The focus
/// person is pinned at the canvas centre while partner nodes settle around it.
///
/// ## Bound (decision CA-8-1)
/// The partner set is capped at `partnerLimit` — the disclosed top-N by shared-document
/// count. There is no silent truncation: when the cap bites the view says so. It cannot say by
/// how much. `totalPartnerCount` comes from a probe capped at `partnerLimit + 1`, so it is a
/// lower bound, and the footer reads "(of 25+)" rather than a total (#1385).
///
/// ## Hover and selection (#1383)
/// A click or tap pins or unpins a partner (`selectedPartnerId`, written only by
/// `toggleSelection(_:)` and `load`); on macOS the pointer previews one (`hoveredPartnerId`,
/// written by `hoverChanged(_:hovering:)`). The dock and node emphasis read `displayedPartnerId`.
///
/// ## Navigation
/// Explore connections, in the info dock or a node's context menu, re-centres the graph on that
/// person (changing the focus); a click or tap on a node only selects it, or deselects it when it
/// is the pinned one. A history stack supports back-navigation, mirroring the volume graph.
/// Person Analytics keeps this view model in `PersonNetworkFocus` and its Focus bar reads
/// ``focusName``, so the two navigations move the bar too (#1433).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — #307: `zoom(by:)` — the multiplicative scroll-wheel zoom path, mirroring
///          `CrossReferenceGraphViewModel.zoom(by:)` for cross-graph parity
///   1.2 — #1383: hover (`hoveredPartnerId`) separated from the clicked selection, which only
///          `toggleSelection(_:)` writes; the dock and node emphasis read `displayedPartnerId`.
///          #1385: `capDisclosure`, and `totalPartnerCount` documented as the probe's lower bound
///   1.3 — #1384: the label rules the canvas places through `GraphNodeLabels` — `labelLimit`,
///          `labelPriority`, `label(for:)`, `labelRequests(sizes:)` — and `nodeRadius(for:)`, the
///          disc radius the canvas draws and the placement keeps clear of
///   1.4 — #1433: owned by the host's `PersonNetworkFocus` rather than the graph view's `@State`
///   1.5 — #1434: `isLayoutSettling`, set while an animated layout runs and cleared by its last pass
///   1.6 — 2026-11-12 (FRUS Explorer Light, S24b): the choice of nodes and edges — `partnerLimit`, what
///          `load(from:volumeIds:)` reads from the store, `partners`, `capApplied` and `capDisclosure` —
///          is FRUSCoreKit's `PersonCoMentionNetwork`, with `PersonCoMentionNode` and `PersonCoMentionEdge`;
///          these names forward there, and the layout, labels and viewport stay here
@Observable
@MainActor
final class PersonCoMentionGraphViewModel {

    // MARK: - Configuration

    /// The disclosed top-N partner cap (decision CA-8-1): the kit's `PersonCoMentionNetwork.partnerLimit`,
    /// under the name it had here.
    static let partnerLimit = PersonCoMentionNetwork.partnerLimit

    // MARK: - Data

    private(set) var focusRollupId: Int
    private(set) var focusName: String
    var nodes: [PersonCoMentionNode] = []
    var edges: [PersonCoMentionEdge] = []
    var isLoading = false
    var error: String? = nil

    /// A lower bound on the focus person's distinct partner count: the size of a probe capped at
    /// `partnerLimit + 1` (#1385). It is the true count while that is at most `partnerLimit`; once
    /// the cap bites it is always `partnerLimit + 1`, which is why the footer can say "of 25+"
    /// and never the total.
    private(set) var totalPartnerCount = 0

    // MARK: - Navigation

    private(set) var history: [(id: Int, name: String)] = []

    // MARK: - Interaction

    /// The partner the reader pinned by clicking (macOS) or tapping (iOS) its node. Only
    /// `toggleSelection(_:)` and `load` write it — never the pointer (#1383) — so the partner a
    /// reader clicked is still pinned when the pointer reaches the dock's buttons, whatever nodes
    /// it crossed on the way.
    private(set) var selectedPartnerId: Int? = nil

    /// The partner node under the pointer (macOS hover; never set on iOS). Transient:
    /// `hoverChanged(_:hovering:)` sets and clears it, and a click and a reload drop it.
    private(set) var hoveredPartnerId: Int? = nil

    /// The partner the info dock and the node emphasis show: the hovered one while the pointer is
    /// over a node, otherwise the pinned one (#1383). Hover previews and never pins, so the pinned
    /// partner is back the moment the pointer leaves the node, in time for the dock's buttons.
    ///
    /// Hover wins here, where `CrossReferenceGraphViewModel.resolvedNodeKey` lets the pinned node
    /// win. That graph's Session 162 note gives its reason: a hover whose exit never arrived
    /// masked every later click. Here a click drops the hover (`toggleSelection(_:)`), so a click
    /// is never masked, and #1383 asked for the preview.
    var displayedPartnerId: Int? { hoveredPartnerId ?? selectedPartnerId }

    /// The pointer entered (`hovering`) or left a partner node's hit area (#1383).
    ///
    /// Entry previews the node. Exit clears the preview only while it still names this node:
    /// two nodes' 48 pt hit areas can overlap, and an exit arriving after the next node's entry
    /// must not erase that node's preview. Never writes the selection.
    /// - Parameters:
    ///   - rollupId: The partner whose hit area the pointer entered or left.
    ///   - hovering: `true` on entry, `false` on exit.
    func hoverChanged(_ rollupId: Int, hovering: Bool) {
        if hovering {
            hoveredPartnerId = rollupId
        } else if hoveredPartnerId == rollupId {
            hoveredPartnerId = nil
        }
    }

    /// A click or tap on a partner node: pins it, or unpins it when it is the pinned one (#1383).
    ///
    /// It also drops the hover preview, so the dock shows what the click did at once: unpinning
    /// the node the pointer rests on empties the dock, rather than leaving it on that node's
    /// preview until the pointer moves off.
    /// - Parameter rollupId: The partner clicked.
    func toggleSelection(_ rollupId: Int) {
        selectedPartnerId = (selectedPartnerId == rollupId) ? nil : rollupId
        hoveredPartnerId = nil
    }

    /// The footer sentence shown while `capApplied` (#1385): "Showing the top 24 co-mentioned
    /// people (of 25+) by shared-document count."
    ///
    /// `totalPartnerCount` is the probe's lower bound, so here it always reads `partnerLimit + 1`
    /// and the "+" is the whole of what the view knows: that there are more.
    var capDisclosure: String {
        PersonCoMentionNetwork.capDisclosure(partnerCount: partners.count, totalPartnerCount: totalPartnerCount)
    }

    /// Pinch-to-zoom magnification applied to the canvas; `1.0` is neutral.
    var scale: CGFloat = 1.0
    /// Pan translation applied to the canvas; `.zero` is neutral.
    var panOffset: CGSize = .zero

    private(set) var steadyScale: CGFloat = 1.0
    private(set) var steadyPanOffset: CGSize = .zero

    // MARK: - Layout

    var nodePositions: [Int: CGPoint] = [:]

    /// Whether the spring layout is still animating toward its settled positions (#1434): `true`
    /// from the moment `rerunLayout` starts an animated layout until its last pass is published, and
    /// `false` for a layout settled at once (Reduce Motion, or three nodes or fewer). The canvas
    /// hands it to `GraphNodeLabels.place(_:avoiding:settling:)`, which places only the focus's
    /// label while it is set, so the partner labels are chosen once, from the settled layout, and
    /// do not flicker.
    private(set) var isLayoutSettling = false

    /// How many passes an animated layout publishes before it rests: each runs `runPhysics` for 20
    /// iterations, then waits a frame (16 ms).
    static let layoutSteps = 15

    // MARK: - Private

    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>? = nil

    // MARK: - Init

    /// Creates the view model centred on `focusRollupId`.
    /// - Parameters:
    ///   - focusRollupId: The starting focus person's rollup id.
    ///   - focusName: The focus person's canonical name (for the centre label).
    init(focusRollupId: Int, focusName: String) {
        self.focusRollupId = focusRollupId
        self.focusName = focusName
    }

    // MARK: - Derived

    /// Partner nodes (everything but the focus), ordered by shared-document count desc: the kit's
    /// `PersonCoMentionNetwork.partners(of:focusRollupId:)`.
    var partners: [PersonCoMentionNode] {
        PersonCoMentionNetwork.partners(of: nodes, focusRollupId: focusRollupId)
    }

    /// All rollup ids in the graph (focus first).
    var allRollupIds: [Int] { [focusRollupId] + partners.map(\.rollupId) }

    /// Whether the top-N cap actually elided partners (drives the disclosure text).
    var capApplied: Bool {
        PersonCoMentionNetwork.capApplied(partnerCount: partners.count, totalPartnerCount: totalPartnerCount)
    }

    /// The largest edge weight, for edge-thickness normalisation (never zero).
    var maxEdgeWeight: Int { edges.map(\.sharedDocuments).max() ?? 1 }

    /// The largest partner shared-with-focus count, for node-size normalisation.
    var maxSharedWithFocus: Int { max(1, partners.map(\.sharedWithFocus).max() ?? 1) }

    func name(for rollupId: Int) -> String {
        nodes.first { $0.rollupId == rollupId }?.name ?? ""
    }

    func sharedWithFocus(for rollupId: Int) -> Int {
        nodes.first { $0.rollupId == rollupId }?.sharedWithFocus ?? 0
    }

    var canNavigateBack: Bool { !history.isEmpty }

    // MARK: - Labels (#1384)

    /// The most characters a node's label may have, the "…" of a cut included.
    ///
    /// Sixteen, where every label was cut to fourteen before #1384: a trade between how much of a
    /// name each label says and how many labels fit, since a longer label crowds more neighbours
    /// and `GraphNodeLabels.place(_:avoiding:settling:)` drops a label that fits neither under
    /// nor above.
    ///
    /// The name a node draws is its rollup's canonical name: the bundled person authority's name
    /// for the person (`person-authority-index.json`'s `n`, "Kennan, George Frost") wherever the
    /// rollup has an authority id — the rollup builder prefers it — and otherwise the longest name
    /// a persons list gives them ("Kennan, George F."). Both are "Surname, Given". A word-boundary
    /// cut leaves a bare surname ("Kennan…") for 57.0% of the 12,836 authority names at fourteen,
    /// 29.3% at sixteen ("Kennan, George…") and 6.1% at twenty; over the 62,898 persons-list names
    /// in the 553 shippable volumes (tags stripped, whitespace folded) the figures are 56.7%, 29.8%
    /// and 5.5%. Over `PersonCoMentionLabelTests`' two laid-out graphs of 25 nodes, named as the
    /// authority stores them and sized by that suite's estimate rather than a font, the placement
    /// keeps 20 labels at fourteen, 18 at sixteen and 11 at twenty on a 700 × 520 canvas, and 21,
    /// 17 and 9 on a 360 × 420 one, the focus's counted — #1384's figures, with one place per label.
    /// Sixteen keeps a given name for most people at a cost of two to four labels. With the place
    /// above a node (#1438) sixteen keeps 21 and 19, and those counts are pinned there.
    static let labelLimit = 16

    /// The radius of the focus node's disc.
    static let focusRadius: CGFloat = 26

    /// The radius a node's disc is drawn at, which the canvas and the label placement both read: the
    /// focus's fixed `focusRadius`, or a partner's 12–22 pt scaled by its shared documents with the
    /// focus, 3 pt more while it is the displayed partner (#1383).
    /// - Parameter rollupId: The node.
    /// - Returns: The disc's radius in points.
    func nodeRadius(for rollupId: Int) -> CGFloat {
        if rollupId == focusRollupId { return Self.focusRadius }
        let base = 12 + 10 * (CGFloat(sharedWithFocus(for: rollupId)) / CGFloat(maxSharedWithFocus))
        return displayedPartnerId == rollupId ? base + 3 : base
    }

    /// The order the labels are placed in (#1384): the focus, then the partner the dock shows
    /// (`displayedPartnerId` — the hovered one on the Mac, otherwise the pinned one), then the other
    /// partners by shared documents with the focus (the `partners` order).
    ///
    /// #1384 asked for the *selected* partner second. This ranks the displayed one, because that
    /// is the partner the dock names and the canvas emphasises (#1383), and its label now yields
    /// only to the focus's label or to a disc. On iOS, where nothing hovers, the two are the same
    /// partner.
    var labelPriority: [Int] {
        let ranked = partners.map(\.rollupId)
        return [focusRollupId]
            + ranked.filter { $0 == displayedPartnerId }
            + ranked.filter { $0 != displayedPartnerId }
    }

    /// The label a node draws: its name, cut to `labelLimit`.
    /// - Parameter rollupId: The node.
    /// - Returns: The label text.
    func label(for rollupId: Int) -> String {
        GraphNodeLabels.shortLabel(name(for: rollupId), limit: Self.labelLimit)
    }

    /// One placement request per laid-out node, in `labelPriority` order, for
    /// `GraphNodeLabels.place(_:avoiding:settling:)`. A node with no position or no measured size
    /// is left out, since the canvas draws neither its disc nor its label.
    /// - Parameter sizes: Each node's measured label size, keyed by rollup id.
    /// - Returns: The requests, highest priority first.
    func labelRequests(sizes: [Int: CGSize]) -> [GraphLabelRequest<Int>] {
        labelPriority.compactMap { id in
            guard let center = nodePositions[id], let size = sizes[id] else { return nil }
            return GraphLabelRequest(id: id, center: center, radius: nodeRadius(for: id), size: size)
        }
    }

    // MARK: - Viewport gestures

    /// Applies an in-flight pinch gesture value on top of the committed zoom level.
    func magnificationChanged(_ value: CGFloat) {
        scale = max(0.25, min(4.0, steadyScale * value))
    }

    /// Commits the current zoom level so the next pinch starts from it.
    func magnificationEnded() { steadyScale = scale }

    /// Applies a multiplicative zoom factor (> 1 zooms in) — the macOS scroll-wheel path (#307),
    /// mirroring `CrossReferenceGraphViewModel.zoom(by:)` so the two graphs feel identical.
    /// Commits immediately: wheel deltas arrive as a stream of small factors, not a gesture
    /// with a distinct end.
    func zoom(by factor: CGFloat) {
        steadyScale = max(0.25, min(4.0, steadyScale * factor))
        scale = steadyScale
    }

    /// Applies an in-flight drag translation on top of the committed pan offset.
    func panChanged(_ translation: CGSize) {
        panOffset = CGSize(width: steadyPanOffset.width + translation.width,
                           height: steadyPanOffset.height + translation.height)
    }

    /// Commits the current pan offset so the next drag continues from it.
    func panEnded() { steadyPanOffset = panOffset }

    /// Restores the pan/zoom viewport to its neutral state.
    /// - Parameter animated: When `true`, glides back with a spring.
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

    // MARK: - Load

    /// Loads the ego (focus + top-N partners + partner-partner edges) from the store, then
    /// runs the layout. Degrades to an empty graph on any query failure.
    /// - Parameter store: The person mention store.
    func load(from store: PersonMentionStore, volumeIds: [String]? = nil) async {
        isLoading = true
        error = nil
        nodes = []
        edges = []
        nodePositions = [:]
        selectedPartnerId = nil
        // The hit areas are rebuilt for the new ego, and a removed one is not guaranteed to
        // report the pointer's exit, so a hover would otherwise outlive its node.
        hoveredPartnerId = nil
        totalPartnerCount = 0
        resetViewport(animated: false)
        do {
            // The kit's choice of nodes and edges (`PersonCoMentionNetwork`), in its two halves, so a
            // failed edge query leaves the nodes and the probe's count in place, as before.
            let ego = try await PersonCoMentionNetwork.nodes(
                focusRollupId: focusRollupId, focusName: focusName, store: store, volumeIds: volumeIds)
            totalPartnerCount = ego.totalPartnerCount
            nodes = ego.nodes
            edges = try await PersonCoMentionNetwork.edges(among: ego.nodes, store: store, volumeIds: volumeIds)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        if canvasSize.width > 0 { rerunLayout(reduceMotion: false) }
    }

    // MARK: - Navigation

    /// Re-centres the graph on `rollupId`, pushing the current focus onto the history stack.
    ///
    /// Mutating `focusRollupId` re-fires the view's `.task(id:)`, which is the sole loader —
    /// this method must NOT call `load` itself, or the ego would load twice per navigation.
    func recenterOn(rollupId: Int) {
        guard rollupId != focusRollupId else { return }
        let newName = name(for: rollupId)
        history.append((id: focusRollupId, name: focusName))
        focusRollupId = rollupId
        focusName = newName
    }

    /// Pops the history stack and re-centres on the previous focus person.
    ///
    /// Mutating `focusRollupId` re-fires the view's `.task(id:)`, which is the sole loader —
    /// this method must NOT call `load` itself, or the ego would load twice per navigation.
    func navigateBack() {
        guard let prev = history.popLast() else { return }
        focusRollupId = prev.id
        focusName = prev.name
    }

    // MARK: - Canvas size / layout

    /// Reacts to a canvas-size change, (re)running the layout when a graph is present.
    func onCanvasSizeChanged(_ size: CGSize, reduceMotion: Bool) {
        canvasSize = size
        guard size.width > 0, size.height > 0, !partners.isEmpty else { return }
        rerunLayout(reduceMotion: reduceMotion)
    }

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        // Every layout settled at once leaves the labels free (#1434); only the animated one below
        // holds them back, and only until its last pass.
        isLayoutSettling = false
        let focus = focusRollupId
        let ids = allRollupIds
        let edgeList = edges
        let size = canvasSize
        guard ids.count > 1 else {
            nodePositions = [focus: CGPoint(x: size.width / 2, y: size.height / 2)]
            return
        }

        let cx = size.width / 2, cy = size.height / 2
        let r = min(size.width, size.height) * 0.35
        var initial: [Int: CGPoint] = [focus: CGPoint(x: cx, y: cy)]
        let partnerIds = ids.filter { $0 != focus }
        for (i, id) in partnerIds.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(partnerIds.count)
            initial[id] = CGPoint(x: cx + r * CGFloat(cos(angle)),
                                  y: cy + r * CGFloat(sin(angle)))
        }

        // Reduce Motion (or a tiny graph): settle instantly, no animated relaxation.
        if reduceMotion || ids.count <= 3 {
            nodePositions = Self.runPhysics(
                ids: ids, centralId: focus, edges: edgeList,
                positions: initial, size: size, iterations: 300)
            return
        }

        nodePositions = initial
        isLayoutSettling = true
        layoutTask = Task { [weak self] in
            var current = initial
            for step in 0..<Self.layoutSteps {
                guard !Task.isCancelled else { break }
                current = PersonCoMentionGraphViewModel.runPhysics(
                    ids: ids, centralId: focus, edges: edgeList,
                    positions: current, size: size, iterations: 20)
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.nodePositions = current
                    // The last pass is the settled layout, published with the flag in one change,
                    // so the frame that draws it places every label (#1434). A cancelled layout
                    // never gets here: the one that cancelled it owns the flag.
                    if step == Self.layoutSteps - 1 { self.isLayoutSettling = false }
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: - Physics (static for testability)

    /// Spring-repulsion layout with the focus node pinned at the canvas centre — a parallel
    /// of `VolumeConnectionGraphViewModel.runPhysics` for rollup-id nodes and undirected
    /// co-mention edges. Deterministic for fixed inputs; bounded by `iterations`.
    ///
    /// - Parameters:
    ///   - ids: All node rollup ids (focus + partners).
    ///   - centralId: The pinned focus rollup id.
    ///   - edges: Undirected weighted co-mention edges.
    ///   - positions: Initial positions (focus pre-placed at centre).
    ///   - size: Canvas size.
    ///   - iterations: Fixed iteration count (bounded — never spins).
    /// - Returns: Settled positions keyed by rollup id.
    static func runPhysics(
        ids: [Int],
        centralId: Int,
        edges: [PersonCoMentionEdge],
        positions: [Int: CGPoint],
        size: CGSize,
        iterations: Int
    ) -> [Int: CGPoint] {
        let k_s: CGFloat = 0.008
        let L0: CGFloat = 150
        let k_r: CGFloat = 6_000
        let damping: CGFloat = 0.82
        let pad: CGFloat = 48
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var pos = positions
        var vel: [Int: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

        for _ in 0..<iterations {
            var forces: [Int: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

            // Attractive spring along every edge.
            for edge in edges {
                guard let ps = pos[edge.a], let pt = pos[edge.b] else { continue }
                let dx = pt.x - ps.x, dy = pt.y - ps.y
                let d = max(hypot(dx, dy), 1)
                let f = k_s * (d - L0)
                let ux = dx / d, uy = dy / d
                forces[edge.a]?.dx += ux * f
                forces[edge.a]?.dy += uy * f
                forces[edge.b]?.dx -= ux * f
                forces[edge.b]?.dy -= uy * f
            }

            // Repulsion between every node pair.
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let pa = pos[ids[i]], let pb = pos[ids[j]] else { continue }
                    let dx = pa.x - pb.x, dy = pa.y - pb.y
                    let d = max(hypot(dx, dy), 1)
                    let f = k_r / (d * d)
                    let ux = dx / d, uy = dy / d
                    forces[ids[i]]?.dx += ux * f; forces[ids[i]]?.dy += uy * f
                    forces[ids[j]]?.dx -= ux * f; forces[ids[j]]?.dy -= uy * f
                }
            }

            for id in ids {
                if id == centralId {
                    pos[id] = center
                    vel[id] = .zero
                    continue
                }
                guard var v = vel[id], var p = pos[id], let f = forces[id] else { continue }
                v.dx = (v.dx + f.dx) * damping
                v.dy = (v.dy + f.dy) * damping
                p.x = max(pad, min(size.width - pad, p.x + v.dx))
                p.y = max(pad, min(size.height - pad, p.y + v.dy))
                vel[id] = v; pos[id] = p
            }
        }
        return pos
    }

    // MARK: - Hit testing

    /// Returns the partner rollup id whose node contains `point`, if any (focus excluded —
    /// tapping the focus is a no-op).
    func partnerAt(point: CGPoint) -> Int? {
        for node in partners {
            guard let pos = nodePositions[node.rollupId] else { continue }
            if hypot(pos.x - point.x, pos.y - point.y) <= 22 { return node.rollupId }
        }
        return nil
    }
}

// MARK: - PersonNetworkFocus

/// Who Person Analytics' Network mode is centred on (#1433): the graph the host draws, owned by
/// the host, and the one place its Focus bar reads a name from.
///
/// ## The defect it ends
/// The graph navigates by itself. Explore connections, in the info dock or a node's context menu,
/// calls ``PersonCoMentionGraphViewModel/recenterOn(rollupId:)``, and the graph's Back calls
/// ``PersonCoMentionGraphViewModel/navigateBack()``; both move the view model's focus and nothing
/// else. The view model used to be the graph view's own `@State`, out of the host's reach, so the
/// host's "Focus:" bar went on naming the person the host had seeded the graph with while the discs,
/// the dock's "N shared documents with …" and the centre's label belonged to someone else.
///
/// ## One source of truth
/// The host now keeps the view model here and hands it to ``PersonCoMentionGraphView``, and the
/// bar reads ``focusName``, which is the view model's own ``PersonCoMentionGraphViewModel/focusName``.
/// Explore and Back move the bar because they move the only focus there is: nothing reports a
/// focus back, so nothing can report it late or miss one.
///
/// ## When the graph is replaced
/// A graph is seeded from a ``Seed``: a person's rollup id and canonical name, and a stores
/// generation. ``follow(topRanked:storesGeneration:)`` replaces it only when the seed changes — the
/// ranking's top person while nothing is picked, or a reindex settling (#275's reason to rebuild
/// against the reopened store) — so a ranking reload that keeps the same top person leaves the
/// reader's Explore and Back history where it was. The NAME is part of the seed: a correction that
/// renames the top person without renumbering them re-seeds the graph and drops that history, where
/// the graph's old `.id`, on the rollup id and the generation alone, kept it and left an unexplored
/// graph's centre label on the old name. The host calls `follow` from an `.onChange` of
/// ``seed(topRanked:storesGeneration:)``, so there an unchanged seed never reaches it; the same-seed
/// guard decides the call that follows a pick, whose seed the pick has already applied.
/// ``pick(_:storesGeneration:)`` always replaces it, even with the person the graph was seeded with:
/// a reader who has explored away and then picks that person in the focus search is asking to go
/// back to them. ``graphSerial`` moves with every replacement and is the graph view's identity, so
/// a new graph is a new view whose load runs.
///
/// Version history:
///   1.0 — #1433: initial implementation
@Observable
@MainActor
final class PersonNetworkFocus {

    /// What a graph is seeded from: the person at its centre when it opens, and the read-only
    /// stores generation it opened in. Every field takes part in equality, the name included.
    struct Seed: Equatable {
        /// The person's rollup id.
        let rollupId: Int
        /// The person's canonical name, for the centre label until the graph navigates. A new name
        /// for the same rollup id is a new seed, so the label is never left on the old one.
        let name: String
        /// `AppState.readOnlyStoresGeneration` when the graph was seeded.
        let storesGeneration: Int
    }

    /// The person the reader chose in the focus search, or `nil` while the graph follows the
    /// ranking's top person.
    private(set) var picked: PersonMentionRanking?

    /// The graph Network mode draws, or `nil` when there is no one to centre it on.
    private(set) var graph: PersonCoMentionGraphViewModel?

    /// Moves each time ``graph`` is replaced. The host keys the graph view's identity on it.
    private(set) var graphSerial = 0

    /// The seed ``graph`` was made from, or `nil` when there is no graph.
    private(set) var seededFrom: Seed?

    /// The name the Focus bar shows: the graph's own focus, which Explore connections and Back move.
    var focusName: String? { graph?.focusName }

    /// Creates the state with no pick and no graph.
    init() {}

    /// The seed Network mode wants: the picked person, else `topRanked`, in `storesGeneration`.
    /// - Parameters:
    ///   - topRanked: The ranking's top person, or `nil` when the ranking is empty.
    ///   - storesGeneration: `AppState.readOnlyStoresGeneration`.
    /// - Returns: The seed, or `nil` when there is no one to centre on.
    func seed(topRanked: PersonMentionRanking?, storesGeneration: Int) -> Seed? {
        (picked ?? topRanked).map {
            Seed(rollupId: $0.rollupId, name: $0.canonicalName, storesGeneration: storesGeneration)
        }
    }

    /// The reader picked `person` in the focus search: the graph is replaced by one centred on them,
    /// even when it was seeded with them, since a reader who has explored away and picks the seed
    /// is asking to go back to it.
    /// - Parameters:
    ///   - person: The person picked.
    ///   - storesGeneration: `AppState.readOnlyStoresGeneration`.
    func pick(_ person: PersonMentionRanking, storesGeneration: Int) {
        picked = person
        reseed(Seed(rollupId: person.rollupId, name: person.canonicalName, storesGeneration: storesGeneration))
    }

    /// Brings the graph up to date with the ranking and the stores, replacing it only when the
    /// seed changed, and dropping it when there is no one to centre on.
    /// - Parameters:
    ///   - topRanked: The ranking's top person, or `nil` when the ranking is empty.
    ///   - storesGeneration: `AppState.readOnlyStoresGeneration`.
    func follow(topRanked: PersonMentionRanking?, storesGeneration: Int) {
        guard let wanted = seed(topRanked: topRanked, storesGeneration: storesGeneration) else {
            graph = nil
            seededFrom = nil
            return
        }
        guard wanted != seededFrom else { return }
        reseed(wanted)
    }

    /// Replaces the graph with a new one centred on `seed`.
    private func reseed(_ seed: Seed) {
        graph = PersonCoMentionGraphViewModel(focusRollupId: seed.rollupId, focusName: seed.name)
        seededFrom = seed
        graphSerial &+= 1
    }
}

// MARK: - PersonCoMentionGraphView

/// Canvas-based co-mention ego graph (CA-8): the focus person at the centre with their
/// top-N co-mentioned partners orbiting in a spring-repulsion layout, edges weighted by
/// shared-document count.
///
/// The focus node is pinned at the canvas centre; partner node size encodes shared
/// documents with the focus, and edge thickness encodes pairwise co-mention weight.
/// Tapping a partner node pins it (tapping it again unpins it), and the info dock shows its
/// shared-document count, an "Explore connections" button that re-centres the graph on that
/// person, and an "Open in Search" button that deep-links to their mentions.
///
/// Accessibility mirrors `VolumeConnectionGraphView`: the `Canvas` is hidden from
/// VoiceOver and a transparent per-node hit-area button carries the label/hint. Reduce
/// Motion settles the layout instantly. The disclosed top-N cap and a legend appear below
/// the canvas.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — #307 (parity with the cross-reference graph): macOS scroll-wheel/trackpad zoom
///          via the shared `ScrollWheelZoomCatcher` (now internal in
///          CrossReferenceGraphView.swift), and a node context menu (Explore Connections /
///          Open in Search) mirroring the tap-selected info card's actions
///   1.2 — #1383: a hit area's click calls `toggleSelection(_:)` and its hover
///          `hoverChanged(_:hovering:)`, and the dock and node emphasis read
///          `displayedPartnerId`, so hovering no longer replaces the clicked partner, and the node's
///          VoiceOver hint says activation selects or deselects (Explore re-centres). #1385: the
///          footer reads the view model's `capDisclosure`
///   1.3 — #1384: labels are measured and placed by `GraphNodeLabels.place(_:)` — the focus's
///          always, on a plate over whatever lies under it, and every partner's only where it keeps
///          clear of every other label and of every other disc — and a name over 16 characters is
///          cut at a word boundary and marked "…", where every name was its first 14 characters
///   1.4 — #1433: the view model is the host's, handed in, where it was this view's own `@State`,
///          so the host's Focus bar reads the focus Explore connections and Back move
///   1.5 — #1471: a hit area writes its `.onHover` and `.help` before `.position(pos)`, so it
///          answers the pointer at its disc and not over the whole canvas, where the topmost hit
///          area — the last partner drawn — took every hover (`tools/hover-region-probe`)
///   1.6 — 2026-10-01: #1434, the partner labels wait for the settled layout; #1517, a drag, pinch
///          or double-tap can start on empty canvas (`GraphEmptyCanvas`); #1518, a node's context
///          menu comes before `.position(pos)`, so iOS lifts the node and not the canvas
struct PersonCoMentionGraphView: View {

    /// The graph's view model. The host owns it (`PersonNetworkFocus`, #1433) and reads its focus
    /// for the Focus bar; this view navigates it — Explore connections and Back — and loads it.
    let vm: PersonCoMentionGraphViewModel

    /// The store, injected by the host so no-index degradation happens above this view.
    let store: PersonMentionStore
    /// Active volume scope (`nil` = whole corpus). Changing it reloads the ego graph (#189-B).
    let volumeIds: [String]?
    /// Opens a person's mentions in Search (reuses the CA-5 person deep-link).
    let onOpenPerson: (_ rollupId: Int, _ name: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the graph over the host's view model, loading it from `store` on appear.
    /// - Parameters:
    ///   - vm: The view model, owned by the host.
    ///   - store: The person mention store.
    ///   - volumeIds: The active volume scope, or `nil` for the whole corpus.
    ///   - onOpenPerson: Opens a person's mentions in Search.
    init(vm: PersonCoMentionGraphViewModel, store: PersonMentionStore,
         volumeIds: [String]? = nil,
         onOpenPerson: @escaping (_ rollupId: Int, _ name: String) -> Void) {
        self.vm = vm
        self.store = store
        self.volumeIds = volumeIds
        self.onOpenPerson = onOpenPerson
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if vm.isLoading {
                    ProgressView(String(localized: "personCoMention.loading",
                                        defaultValue: "Loading co-mention network…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.error {
                    ContentUnavailableView(
                        String(localized: "personCoMention.error.title", defaultValue: "Graph Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(err))
                } else if vm.partners.isEmpty {
                    ContentUnavailableView(
                        String(localized: "personCoMention.empty.title", defaultValue: "No Co-Mentions"),
                        systemImage: "person.2.slash",
                        description: Text(String(
                            localized: "personCoMention.empty.detail",
                            defaultValue: "\(vm.focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently tagged focus person.")))
                } else {
                    graphContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !vm.partners.isEmpty && vm.error == nil && !vm.isLoading {
                legendBar
            }
        }
        .task(id: "\(vm.focusRollupId)#\(volumeIds?.sorted().joined(separator: ",") ?? "*")") {
            await vm.load(from: store, volumeIds: volumeIds)
        }
    }

    // MARK: - Graph Content

    /// Graph + a PERMANENTLY-reserved info dock (Win 6). Reserving the dock at all times — an
    /// empty-state placeholder when nothing is selected — keeps the graph canvas region a constant
    /// size, so selecting/deselecting a node never resizes the canvas. That matters because a canvas
    /// resize fires `onCanvasSizeChanged` → the spring layout re-runs and nodes visibly jump; a fixed
    /// region avoids it. A side dock on wide layouts (≥640pt), a bottom dock when narrow.
    private var graphContent: some View {
        GeometryReader { outer in
            let sideDock = outer.size.width >= 640
            if sideDock {
                HStack(spacing: 0) {
                    graphRegion
                    Divider()
                    infoDock.frame(width: 300)
                }
            } else {
                VStack(spacing: 0) {
                    graphRegion
                    Divider()
                    infoDock.frame(height: 190)
                }
            }
        }
    }

    /// The graph canvas plus its floating viewport buttons, occupying all space not taken by the
    /// info dock. The inner `GeometryReader` measures ONLY this reduced region, so the layout settles
    /// into it from the first frame (no post-hoc shrink) and is stable across selection changes.
    private var graphRegion: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    graphCanvas
                    nodeHitAreas
                }
                .scaleEffect(vm.scale, anchor: .center)
                .offset(vm.panOffset)
                // The empty canvas takes hits, so a drag, pinch or double-tap can start there as
                // well as on a node (#1517); a click or tap on it does nothing.
                .background { GraphEmptyCanvas() }
                .gesture(magnificationGesture)
                .gesture(panGesture)
                .gesture(resetViewportGesture)
                .onChange(of: geo.size, initial: true) { _, size in
                    vm.onCanvasSizeChanged(size, reduceMotion: reduceMotion)
                }
                #if os(macOS)
                .background {
                    // Scroll-wheel / trackpad-scroll zoom (#307) — the same event-monitor
                    // catcher the cross-reference graph uses (shared from
                    // CrossReferenceGraphView.swift), so it never intercepts clicks,
                    // drags, or hover.
                    ScrollWheelZoomCatcher { factor in
                        vm.zoom(by: factor)
                    }
                    .allowsHitTesting(false)
                }
                #endif
            }
            viewportControls
                .padding()
        }
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        // Read here, in body, where Observation registers it: a read inside the Canvas closure runs
        // at render time and registers nothing (#1434).
        let settling = vm.isLayoutSettling
        return Canvas { context, _ in
            let maxWeight = CGFloat(vm.maxEdgeWeight)
            let focusId = vm.focusRollupId

            // Edges — grey, weighted by shared-document count.
            for edge in vm.edges {
                guard let from = vm.nodePositions[edge.a],
                      let to = vm.nodePositions[edge.b] else { continue }
                // Focus-incident edges are tinted the accent colour to read as spokes.
                let isSpoke = edge.a == focusId || edge.b == focusId
                drawEdge(&context, from: from, to: to,
                         color: isSpoke ? Color.accentColor : .gray,
                         weight: CGFloat(edge.sharedDocuments) / maxWeight)
            }

            // Partner nodes (drawn before the focus so the focus renders on top).
            for node in vm.partners {
                guard let pos = vm.nodePositions[node.rollupId] else { continue }
                // The dock's partner — hovered or pinned (#1383) — is the one emphasised.
                let isEmphasized = vm.displayedPartnerId == node.rollupId
                // 12…22 pt by shared documents, 3 pt more when emphasised: the radius the label
                // placement keeps clear of (#1384).
                let r = vm.nodeRadius(for: node.rollupId)
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(isEmphasized ? .teal : Color.teal.opacity(0.6)))
                if isEmphasized {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 1.5)
                }
            }

            // Focus node — drawn on top of the partners.
            if let cp = vm.nodePositions[focusId] {
                let cr = vm.nodeRadius(for: focusId)
                let centralRect = CGRect(x: cp.x - cr, y: cp.y - cr, width: cr * 2, height: cr * 2)
                context.fill(Path(ellipseIn: centralRect), with: .color(Color.accentColor))
                context.stroke(Path(ellipseIn: centralRect.insetBy(dx: -2, dy: -2)),
                               with: .color(.white), lineWidth: 2)
                context.draw(Image(systemName: "person.fill"),
                             in: centralRect.insetBy(dx: cr * 0.4, dy: cr * 0.4))
            }

            // Labels (#1384): each measured as it will be drawn, then placed in priority order —
            // the focus always, on its plate, then the dock's partner and the partners by shared
            // documents, each only where it keeps clear of the labels already placed and of every
            // other disc. While the layout animates, the focus's alone (#1434).
            var resolved: [Int: GraphicsContext.ResolvedText] = [:]
            var sizes: [Int: CGSize] = [:]
            for id in vm.labelPriority {
                let text = context.resolve(labelText(for: id, isFocus: id == focusId))
                resolved[id] = text
                sizes[id] = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                    height: .greatestFiniteMagnitude))
            }
            let requests = vm.labelRequests(sizes: sizes)
            let placed = GraphNodeLabels.place(requests, settling: settling)
            if let plate = GraphNodeLabels.plate(for: requests, placed: placed) {
                GraphNodeLabels.drawPlate(&context, in: plate)
            }
            for (id, rect) in placed {
                if let text = resolved[id] {
                    context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// A node's label styled as the canvas draws it (#1384): the focus's in 9 pt semibold, a
    /// partner's in 8 pt secondary. The canvas measures exactly this text before placing it.
    /// - Parameters:
    ///   - rollupId: The node.
    ///   - isFocus: Whether the node is the focus.
    /// - Returns: The styled label.
    private func labelText(for rollupId: Int, isFocus: Bool) -> Text {
        let text = Text(verbatim: vm.label(for: rollupId))
        return isFocus
            ? text.font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.primary)
            : text.font(.system(size: 8)).foregroundStyle(Color.secondary)
    }

    private func drawEdge(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint,
                          color: Color, weight: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path,
                       with: .color(color.opacity(0.2 + weight * 0.5)),
                       lineWidth: 0.5 + weight * 3.5)
    }

    // MARK: - Hit Areas (accessibility + tap-to-select)

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.partners) { node in
            if let pos = vm.nodePositions[node.rollupId] {
                Button {
                    vm.toggleSelection(node.rollupId)
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                #if os(macOS)
                // Hover previews and never pins (#1383): only the click above selects.
                .onHover { hovering in vm.hoverChanged(node.rollupId, hovering: hovering) }
                #endif
                .help(String(localized: "personCoMention.node.help",
                             defaultValue: "Co-mention count with the focus person — click for details, right-click for actions"))
                // Right-click / long-press parity with the cross-reference graph's node
                // context menu (#307): the same two actions the tap-selected info card
                // offers, reachable without first pinning the card. Before `.position`, as the
                // pointer modifiers are (#1518): written after it, the menu's view is the whole
                // canvas. Measured on an iPhone 17 simulator (iOS 26.5): written after, a long press
                // on a partner opened the menu under the canvas's bottom-left corner; before, beside
                // the partner.
                .contextMenu {
                    Button {
                        vm.recenterOn(rollupId: node.rollupId)
                    } label: {
                        Label(String(localized: "personCoMention.contextMenu.recenter",
                                     defaultValue: "Explore Connections"),
                              systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    Button {
                        onOpenPerson(node.rollupId, node.name)
                    } label: {
                        Label(String(localized: "personCoMention.contextMenu.openSearch",
                                     defaultValue: "Open in Search"),
                              systemImage: "magnifyingglass")
                    }
                }
                // After the pointer modifiers (#1471): `.position` returns a view that fills the
                // canvas, so a hover or help written after it answers the pointer anywhere on the
                // canvas, and the topmost hit area took every hover.
                .position(pos)
                .accessibilityLabel(node.name)
                .accessibilityValue(String(
                    localized: "personCoMention.node.a11yValue",
                    defaultValue: "\(node.sharedWithFocus) shared documents with \(vm.focusName)"))
                // Activating the node selects or deselects it (`toggleSelection`); only Explore
                // connections re-centres (#1383 corrected the old claim that a tap re-centred).
                .accessibilityHint(String(localized: "personCoMention.node.hint",
                                          defaultValue: "Selects or deselects this person. While they are selected, the network shows how many documents they share with the focus person, and Explore connections re-centers it on them. Right-click or long-press for actions"))
            }
        }
    }

    // MARK: - Viewport Controls

    /// The small floating viewport buttons (Reset View / Back) pinned at the graph's top-leading
    /// corner. The selected-person info no longer lives here — it moved to the docked panel (Win 6) —
    /// so these buttons never obscure a node's neighbourhood.
    @ViewBuilder
    private var viewportControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.scale != 1.0 || vm.panOffset != .zero {
                Button {
                    vm.resetViewport(animated: !reduceMotion)
                } label: {
                    Label(String(localized: "personCoMention.resetView", defaultValue: "Reset View"),
                          systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }

            if vm.canNavigateBack {
                Button {
                    vm.navigateBack()
                } label: {
                    Label(String(localized: "personCoMention.back", defaultValue: "Back"),
                          systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.canNavigateBack)
    }

    // MARK: - Info Dock

    /// The permanently-reserved info region beside (wide) or below (narrow) the graph. It shows the
    /// hovered or pinned partner's card (`displayedPartnerId`, #1383), or a prompt when there is
    /// neither. The placeholder is what keeps the graph canvas a constant size across selection
    /// changes (see `graphContent`). Only the dock CONTENT cross-fades; its frame never changes.
    private var infoDock: some View {
        ZStack {
            if let sel = vm.displayedPartnerId {
                // Scroll within the fixed-height reserve so the action buttons stay reachable when the
                // card exceeds the dock — a long name, or large Dynamic Type in the ~190pt bottom dock
                // (which would otherwise overflow past the panel onto the legend). The dock FRAME stays
                // fixed; only its content scrolls, so the canvas-stability reservation is preserved.
                ScrollView { dockedInfoPanel(for: sel) }
            } else {
                infoDockEmptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: vm.displayedPartnerId)
    }

    /// The displayed partner's card — hovered or pinned (#1383) — with its name, shared-document
    /// count, and the Explore/Open actions, filling the dock width (no fixed 280pt frame, unlike the
    /// former floating panel).
    @ViewBuilder
    private func dockedInfoPanel(for partnerId: Int) -> some View {
        let name = vm.name(for: partnerId)
        let shared = vm.sharedWithFocus(for: partnerId)
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline).lineLimit(3)
            Divider()
            Label(String(localized: "personCoMention.info.shared",
                         defaultValue: "\(shared) shared document\(shared == 1 ? "" : "s") with \(vm.focusName)"),
                  systemImage: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Full-width stacked buttons so the titles never truncate at any Dynamic Type size or
            // dock width (the old side-by-side HStack was ~7pt from clipping in the 300pt side dock).
            VStack(spacing: 6) {
                Button(String(localized: "personCoMention.info.explore",
                              defaultValue: "Explore connections")) {
                    vm.recenterOn(rollupId: partnerId)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                Button(String(localized: "personCoMention.info.openSearch",
                              defaultValue: "Open in Search")) {
                    onOpenPerson(partnerId, name)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .font(.caption)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    /// The dock's empty state, shown while no partner is hovered or pinned.
    private var infoDockEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: FRUSTheme.selectGlyph)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(String(localized: "personCoMention.dock.empty",
                        defaultValue: "Select a person to see their shared documents and connections."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Legend / Disclosure

    private var legendBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                legendItem(color: Color.accentColor,
                           text: String(localized: "personCoMention.legend.focus", defaultValue: "Focus person"))
                legendItem(color: .teal,
                           text: String(localized: "personCoMention.legend.partner", defaultValue: "Co-mentioned (size = shared documents)"))
            }
            .font(.caption2)
            if vm.capApplied {
                Text(vm.capDisclosure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "personCoMention.cap.all",
                            defaultValue: "Showing all \(vm.partners.count) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).foregroundStyle(.secondary)
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { vm.magnificationChanged($0) }
            .onEnded { _ in vm.magnificationEnded() }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { vm.panChanged($0.translation) }
            .onEnded { _ in vm.panEnded() }
    }

    private var resetViewportGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded { vm.resetViewport(animated: !reduceMotion) }
    }
}
