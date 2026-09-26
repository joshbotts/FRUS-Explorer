// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeConnectionGraphViewModel

/// ViewModel for the per-volume cross-reference ego graph.
///
/// Loads inbound and outbound cross-volume reference counts for `centralVolumeId`
/// from `CrossReferenceStore.volumeEgoGraph(forVolumeId:)`, then runs a pinned
/// spring-repulsion layout — the central volume node is fixed at the canvas centre
/// while partner volume nodes settle around it.
///
/// ## Navigation
/// Tapping a partner node opens an info panel with a reference count breakdown and
/// an "Explore connections" button that recenters the graph on that volume. A history
/// stack supports back-navigation.
///
/// ## Node colour coding
/// - Central volume: accent colour
/// - Inbound-only: blue (other volume references this one)
/// - Outbound-only: green (this volume references the other)
/// - Bidirectional: indigo (mutual references in both directions)
///
/// ## Hover and selection (#1383)
/// A click or tap pins a partner (`selectedPartnerId`, written only by `toggleSelection(_:)`
/// and `load`); on macOS the pointer previews one (`hoveredPartnerId`, written by
/// `hoverChanged(_:hovering:)`). The info panel and the node emphasis read
/// `displayedPartnerId` — the same rules as `PersonCoMentionGraphViewModel`.
///
/// Version history:
///   1.0 — Corpus-wide free-layout graph
///   2.0 — Redesigned as per-volume ego graph with pinned centre and navigation history
///   2.1 — #1383: hover (`hoveredPartnerId`) separated from the clicked selection, which only
///          `toggleSelection(_:)` writes; `displayedPartnerId` and `isPreviewingHover`
///   2.2 — #1384: the label rules the canvas places through `GraphNodeLabels` — `labelLimit`,
///          `labelPriority`, `label(for:)`, `labelRequests(sizes:)` — and `nodeRadius(for:)`, the
///          disc radius the canvas draws and the placement keeps clear of
@Observable
@MainActor
final class VolumeConnectionGraphViewModel {

    // MARK: - Data

    private(set) var centralVolumeId: String
    var inboundEdges:  [VolumeConnectionEdge] = []
    var outboundEdges: [VolumeConnectionEdge] = []
    var isLoading = false
    var error: String? = nil

    // MARK: - Navigation

    private(set) var history: [String] = []

    // MARK: - Interaction

    /// The partner volume the reader pinned by clicking (macOS) or tapping (iOS) its node. Only
    /// `toggleSelection(_:)` and `load` write it — never the pointer (#1383).
    private(set) var selectedPartnerId: String? = nil

    /// The partner node under the pointer (macOS hover; never set on iOS). Transient:
    /// `hoverChanged(_:hovering:)` sets and clears it, and a click and a reload drop it.
    private(set) var hoveredPartnerId: String? = nil

    /// The partner the info panel and the node emphasis show: the hovered one while the pointer
    /// is over a node, otherwise the pinned one (#1383). The precedence, and why a click is never
    /// masked by it, are `PersonCoMentionGraphViewModel.displayedPartnerId`'s.
    var displayedPartnerId: String? { hoveredPartnerId ?? selectedPartnerId }

    /// Whether the info panel shows a hover preview rather than the pinned volume (#1383).
    ///
    /// This graph's panel floats over the canvas, unlike the co-mention graph's dock, so a preview
    /// can appear over the very node being hovered. The view stops a previewing panel from taking
    /// the pointer, so it cannot come between the pointer and that node — which, if SwiftUI then
    /// reported the node's exit, would close the preview and reopen it as the pointer re-entered.
    /// A pinned panel still takes the pointer, or its Explore button could not be clicked.
    var isPreviewingHover: Bool { hoveredPartnerId != nil && hoveredPartnerId != selectedPartnerId }

    /// The pointer entered (`hovering`) or left a partner node's hit area (#1383). Entry previews
    /// the node; exit clears the preview only while it still names this node, so an exit that
    /// arrives after an overlapping neighbour's entry keeps the neighbour's preview. Never writes
    /// the selection.
    /// - Parameters:
    ///   - volumeId: The partner volume whose hit area the pointer entered or left.
    ///   - hovering: `true` on entry, `false` on exit.
    func hoverChanged(_ volumeId: String, hovering: Bool) {
        if hovering {
            hoveredPartnerId = volumeId
        } else if hoveredPartnerId == volumeId {
            hoveredPartnerId = nil
        }
    }

    /// A click or tap on a partner node: pins it, or unpins it when it is the pinned one (#1383).
    /// It also drops the hover preview, so the panel shows what the click did at once.
    /// - Parameter volumeId: The partner volume clicked.
    func toggleSelection(_ volumeId: String) {
        selectedPartnerId = (selectedPartnerId == volumeId) ? nil : volumeId
        hoveredPartnerId = nil
    }

    /// Pinch-to-zoom magnification applied to the canvas; `1.0` is neutral.
    /// Holds `steadyScale × gestureValue` during a pinch (see `magnificationChanged(_:)`).
    var scale: CGFloat    = 1.0

    /// Pan translation applied to the canvas; `.zero` is neutral.
    /// Holds `steadyPanOffset + gestureTranslation` during a drag (see `panChanged(_:)`).
    var panOffset: CGSize = .zero

    /// Committed zoom level carried between magnification gestures, so consecutive
    /// pinches accumulate instead of snapping back to the 1.0 baseline.
    private(set) var steadyScale: CGFloat = 1.0

    /// Committed pan offset carried between drag gestures.
    private(set) var steadyPanOffset: CGSize = .zero

    // MARK: - Layout

    var nodePositions: [String: CGPoint] = [:]

    // MARK: - Private

    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>? = nil

    // MARK: - Init

    init(centralVolumeId: String) {
        self.centralVolumeId = centralVolumeId
    }

    // MARK: - Derived

    var partnerVolumeIds: [String] {
        var seen = Set<String>()
        var ids:  [String] = []
        for edge in inboundEdges  { if seen.insert(edge.sourceVolumeId).inserted { ids.append(edge.sourceVolumeId) } }
        for edge in outboundEdges { if seen.insert(edge.targetVolumeId).inserted { ids.append(edge.targetVolumeId) } }
        return ids.sorted()
    }

    var allVolumeIds: [String] { [centralVolumeId] + partnerVolumeIds }

    var bidirectionalVolumeIds: Set<String> {
        Set(inboundEdges.map(\.sourceVolumeId)).intersection(Set(outboundEdges.map(\.targetVolumeId)))
    }

    var maxCount: Int {
        (inboundEdges.map(\.count) + outboundEdges.map(\.count)).max() ?? 1
    }

    func inboundCount(for volumeId: String) -> Int {
        inboundEdges.first(where: { $0.sourceVolumeId == volumeId })?.count ?? 0
    }

    func outboundCount(for volumeId: String) -> Int {
        outboundEdges.first(where: { $0.targetVolumeId == volumeId })?.count ?? 0
    }

    var canNavigateBack: Bool { !history.isEmpty }

    // MARK: - Labels (#1384)

    /// The most characters a node's label may have, the "…" of a cut included.
    ///
    /// Twenty-two, where every label was the id's first ten characters before #1384. Ten cut 482
    /// of the 553 bundled volume ids, and the part it cut is the part that tells volumes apart —
    /// every Nixon–Ford volume read "frus1969-7". The longest bundled id is 22 characters
    /// (`frus1961-63v07-09mSupp`), so this draws every one whole; a longer id, a side-loaded
    /// volume's, is cut hard and marked, since an id has no word boundary. The width costs labels,
    /// since `GraphNodeLabels.place(_:)` drops a label that would crowd another: over
    /// `VolumeConnectionLabelTests`' two laid-out graphs of 49 nodes, sized by that suite's
    /// estimate rather than a font, it keeps 18 labels on a 700 × 520 canvas and 11 on a
    /// 360 × 420 one (pinned there), where ten characters kept 25 and 11 — but every one of those
    /// 25 read "frus1969-…".
    static let labelLimit = 22

    /// The radius of the central volume's disc.
    static let centralRadius: CGFloat = 28

    /// The radius a node's disc is drawn at, which the canvas and the label placement both read: the
    /// central volume's `centralRadius`, or a partner's 18 pt, 22 pt while it is the displayed
    /// partner (#1383).
    /// - Parameter volumeId: The node.
    /// - Returns: The disc's radius in points.
    func nodeRadius(for volumeId: String) -> CGFloat {
        if volumeId == centralVolumeId { return Self.centralRadius }
        return displayedPartnerId == volumeId ? 22 : 18
    }

    /// The order the labels are placed in (#1384): the central volume, then the partner the panel
    /// shows (`displayedPartnerId`), then the other partners by references in both directions,
    /// most first, and by id among equals — the co-mention graph's rule, with this graph's weight in
    /// place of shared documents (`PersonCoMentionGraphViewModel.labelPriority` says why the
    /// displayed partner, not the pinned one, ranks second).
    var labelPriority: [String] {
        var references: [String: Int] = [:]
        for edge in inboundEdges { references[edge.sourceVolumeId, default: 0] += edge.count }
        for edge in outboundEdges { references[edge.targetVolumeId, default: 0] += edge.count }
        let ranked = partnerVolumeIds.sorted { a, b in
            let ra = references[a, default: 0], rb = references[b, default: 0]
            return ra != rb ? ra > rb : a < b
        }
        return [centralVolumeId]
            + ranked.filter { $0 == displayedPartnerId }
            + ranked.filter { $0 != displayedPartnerId }
    }

    /// The label a node draws: its volume id, cut to `labelLimit`.
    /// - Parameter volumeId: The node.
    /// - Returns: The label text.
    func label(for volumeId: String) -> String {
        GraphNodeLabels.shortLabel(volumeId, limit: Self.labelLimit)
    }

    /// One placement request per laid-out node, in `labelPriority` order, for
    /// `GraphNodeLabels.place(_:)`. A node with no position or no measured size is left out, since
    /// the canvas draws neither its disc nor its label.
    /// - Parameter sizes: Each node's measured label size, keyed by volume id.
    /// - Returns: The requests, highest priority first.
    func labelRequests(sizes: [String: CGSize]) -> [GraphLabelRequest<String>] {
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
    func magnificationEnded() {
        steadyScale = scale
    }

    /// Applies an in-flight drag translation on top of the committed pan offset.
    func panChanged(_ translation: CGSize) {
        panOffset = CGSize(
            width:  steadyPanOffset.width  + translation.width,
            height: steadyPanOffset.height + translation.height
        )
    }

    /// Commits the current pan offset so the next drag continues from it.
    func panEnded() {
        steadyPanOffset = panOffset
    }

    /// Restores the pan/zoom viewport to its neutral state. The layout itself never
    /// needs touching — the central volume node is pinned to the canvas centre.
    /// - Parameter animated: When `true`, the change glides back with a spring.
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

    func load(from store: CrossReferenceStore) async {
        isLoading = true
        error = nil
        inboundEdges  = []
        outboundEdges = []
        nodePositions = [:]
        selectedPartnerId = nil
        // The hit areas are rebuilt for the new centre, and a removed one is not guaranteed to
        // report the pointer's exit, so a hover would otherwise outlive its node.
        hoveredPartnerId = nil
        // A stale pinch/pan transform from the previous volume would otherwise be
        // applied on top of the freshly built layout.
        resetViewport(animated: false)
        do {
            let ego = try await store.volumeEgoGraph(forVolumeId: centralVolumeId)
            inboundEdges  = ego.inboundEdges
            outboundEdges = ego.outboundEdges
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        if canvasSize.width > 0 { rerunLayout(reduceMotion: false) }
    }

    // MARK: - Navigation

    func recenterOn(volumeId: String, from store: CrossReferenceStore) async {
        history.append(centralVolumeId)
        centralVolumeId = volumeId
        await load(from: store)
    }

    func navigateBack(from store: CrossReferenceStore) async {
        guard let prev = history.popLast() else { return }
        centralVolumeId = prev
        await load(from: store)
    }

    // MARK: - Canvas size / layout

    func onCanvasSizeChanged(_ size: CGSize, reduceMotion: Bool) {
        canvasSize = size
        guard size.width > 0, size.height > 0,
              !inboundEdges.isEmpty || !outboundEdges.isEmpty else { return }
        rerunLayout(reduceMotion: reduceMotion)
    }

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        let central  = centralVolumeId
        let ids      = allVolumeIds
        let inbound  = inboundEdges
        let outbound = outboundEdges
        let size     = canvasSize
        guard ids.count > 1 else {
            nodePositions = [central: CGPoint(x: size.width / 2, y: size.height / 2)]
            return
        }

        let cx = size.width / 2, cy = size.height / 2
        let r  = min(size.width, size.height) * 0.35
        var initial: [String: CGPoint] = [central: CGPoint(x: cx, y: cy)]
        let partners = ids.filter { $0 != central }
        for (i, id) in partners.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(partners.count)
            initial[id] = CGPoint(x: cx + r * CGFloat(cos(angle)),
                                  y: cy + r * CGFloat(sin(angle)))
        }

        let allEdges = inbound + outbound

        if reduceMotion || ids.count <= 3 {
            nodePositions = Self.runPhysics(
                ids: ids, centralId: central, edges: allEdges,
                positions: initial, size: size, iterations: 300)
            return
        }

        nodePositions = initial
        layoutTask = Task { [weak self] in
            var current = initial
            for _ in 0..<15 {
                guard !Task.isCancelled else { break }
                current = VolumeConnectionGraphViewModel.runPhysics(
                    ids: ids, centralId: central, edges: allEdges,
                    positions: current, size: size, iterations: 20)
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.nodePositions = current
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: - Physics (static for testability)

    /// Spring-repulsion layout with the central node pinned at the canvas centre.
    static func runPhysics(
        ids: [String],
        centralId: String,
        edges: [VolumeConnectionEdge],
        positions: [String: CGPoint],
        size: CGSize,
        iterations: Int
    ) -> [String: CGPoint] {
        let k_s:     CGFloat = 0.008
        let L0:      CGFloat = 150
        let k_r:     CGFloat = 6_000
        let damping: CGFloat = 0.82
        let pad:     CGFloat = 48
        let center   = CGPoint(x: size.width / 2, y: size.height / 2)

        var pos = positions
        var vel: [String: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

        for _ in 0..<iterations {
            var forces: [String: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

            for edge in edges {
                guard let ps = pos[edge.sourceVolumeId],
                      let pt = pos[edge.targetVolumeId] else { continue }
                let dx = pt.x - ps.x, dy = pt.y - ps.y
                let d  = max(hypot(dx, dy), 1)
                let f  = k_s * (d - L0)
                let ux = dx / d, uy = dy / d
                forces[edge.sourceVolumeId]?.dx += ux * f
                forces[edge.sourceVolumeId]?.dy += uy * f
                forces[edge.targetVolumeId]?.dx  -= ux * f
                forces[edge.targetVolumeId]?.dy  -= uy * f
            }

            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let pa = pos[ids[i]], let pb = pos[ids[j]] else { continue }
                    let dx = pa.x - pb.x, dy = pa.y - pb.y
                    let d  = max(hypot(dx, dy), 1)
                    let f  = k_r / (d * d)
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
                p.x  = max(pad, min(size.width  - pad, p.x + v.dx))
                p.y  = max(pad, min(size.height - pad, p.y + v.dy))
                vel[id] = v; pos[id] = p
            }
        }
        return pos
    }

    // MARK: - Hit testing

    func volumeAt(point: CGPoint) -> String? {
        for id in allVolumeIds {
            guard let pos = nodePositions[id] else { continue }
            let r: CGFloat = (id == centralVolumeId) ? 28 : 20
            if hypot(pos.x - point.x, pos.y - point.y) <= r { return id }
        }
        return nil
    }
}

// MARK: - VolumeConnectionGraphView

/// Canvas-based ego graph showing one volume's incoming and outgoing cross-references.
///
/// The central volume node is pinned at the canvas centre. Partner nodes orbit it in
/// a force-directed spring-repulsion layout. Inbound partners (volumes that reference
/// this one) are blue; outbound partners (volumes this one references) are green;
/// bidirectional partners are indigo.
///
/// Tapping a partner node opens an info panel with reference counts and an "Explore
/// connections" button that recenters the graph on that partner volume. A back button
/// returns to the previous centre.
///
/// Version history:
///   1.0 — Corpus-wide free-layout graph
///   2.0 — Per-volume ego graph with pinned centre and navigation history
///   2.1 — #1383: a hit area's click calls `toggleSelection(_:)` and its hover
///          `hoverChanged(_:hovering:)`; the panel and node emphasis read `displayedPartnerId`,
///          and a previewing panel does not take the pointer (`isPreviewingHover`)
///   2.2 — #1384: labels are measured and placed by `GraphNodeLabels.place(_:)` — the central
///          volume's always, on a plate over whatever lies under it, and every partner's only where
///          it keeps clear of every other label and of every other disc — and each is the whole
///          volume id, where every label was the id's first ten characters, unmarked
struct VolumeConnectionGraphView: View {

    @State private var vm: VolumeConnectionGraphViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(volumeId: String) {
        _vm = State(initialValue: VolumeConnectionGraphViewModel(centralVolumeId: volumeId))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading connections…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.error {
                ContentUnavailableView(
                    "Graph Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err)
                )
            } else if vm.partnerVolumeIds.isEmpty {
                ContentUnavailableView(
                    "No Cross-Volume References",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("\(vm.centralVolumeId) has no cross-references to other indexed volumes.")
                )
            } else {
                graphContent
            }
        }
        .task {
            if let store = appState.crossReferenceStore {
                await vm.load(from: store)
            }
        }
        // Reload against the reopened store after an in-session reindex settles (#275): the boot
        // connection this graph read through can be left stale by the rebuild.
        .onChange(of: appState.readOnlyStoresGeneration) { _, _ in
            Task {
                if let store = appState.crossReferenceStore {
                    await vm.load(from: store)
                }
            }
        }
    }

    // MARK: - Graph Content

    private var graphContent: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    graphCanvas
                    nodeHitAreas
                }
                .scaleEffect(vm.scale, anchor: .center)
                .offset(vm.panOffset)
                .gesture(magnificationGesture)
                .gesture(panGesture)
                .gesture(resetViewportGesture)
                .onChange(of: geo.size, initial: true) { _, size in
                    vm.onCanvasSizeChanged(size, reduceMotion: reduceMotion)
                }
            }
            overlayControls
                .padding()
        }
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        Canvas { context, _ in
            let maxCount  = CGFloat(vm.maxCount)
            let centralId = vm.centralVolumeId

            // Inbound edges — blue, pointing toward central
            for edge in vm.inboundEdges {
                guard let from = vm.nodePositions[edge.sourceVolumeId],
                      let to   = vm.nodePositions[centralId] else { continue }
                drawEdge(&context, from: from, to: to,
                         color: .blue, weight: CGFloat(edge.count) / maxCount)
            }

            // Outbound edges — green, pointing away from central
            for edge in vm.outboundEdges {
                guard let from = vm.nodePositions[centralId],
                      let to   = vm.nodePositions[edge.targetVolumeId] else { continue }
                drawEdge(&context, from: from, to: to,
                         color: .green, weight: CGFloat(edge.count) / maxCount)
            }

            // Partner nodes (draw before central so central renders on top)
            let bidir = vm.bidirectionalVolumeIds
            for id in vm.partnerVolumeIds {
                guard let pos = vm.nodePositions[id] else { continue }
                // The panel's volume — hovered or pinned (#1383) — is the one emphasised.
                let isEmphasized = vm.displayedPartnerId == id
                // 18 pt, 22 pt when emphasised: the radius the label placement keeps clear of (#1384).
                let r = vm.nodeRadius(for: id)
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)

                let nodeColor: Color
                if bidir.contains(id) {
                    nodeColor = .indigo
                } else if vm.inboundEdges.contains(where: { $0.sourceVolumeId == id }) {
                    nodeColor = .blue
                } else {
                    nodeColor = .green
                }

                context.fill(Path(ellipseIn: rect),
                             with: .color(isEmphasized ? nodeColor : nodeColor.opacity(0.6)))
                if isEmphasized {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 1.5)
                }
            }

            // Central node — drawn above the partner nodes
            if let cp = vm.nodePositions[centralId] {
                let cr = vm.nodeRadius(for: centralId)
                let centralRect = CGRect(x: cp.x - cr, y: cp.y - cr, width: cr * 2, height: cr * 2)
                context.fill(Path(ellipseIn: centralRect), with: .color(Color.accentColor))
                context.stroke(Path(ellipseIn: centralRect.insetBy(dx: -2, dy: -2)),
                               with: .color(.white), lineWidth: 2)
                context.draw(Image(systemName: "books.vertical.fill"),
                             in: centralRect.insetBy(dx: cr * 0.35, dy: cr * 0.35))
            }

            // Labels (#1384): each measured as it will be drawn, then placed in priority order —
            // the central volume always, on its plate, then the panel's volume and the partners by
            // references, each only where it keeps clear of the labels already placed and of every
            // other disc.
            var resolved: [String: GraphicsContext.ResolvedText] = [:]
            var sizes: [String: CGSize] = [:]
            for id in vm.labelPriority {
                let text = context.resolve(labelText(for: id, isCentral: id == centralId))
                resolved[id] = text
                sizes[id] = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                    height: .greatestFiniteMagnitude))
            }
            let requests = vm.labelRequests(sizes: sizes)
            let placed = GraphNodeLabels.place(requests)
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

    /// A node's label styled as the canvas draws it (#1384): the central volume's in 9 pt
    /// semibold, a partner's in 8 pt secondary. The canvas measures exactly this text before
    /// placing it.
    /// - Parameters:
    ///   - volumeId: The node.
    ///   - isCentral: Whether the node is the central volume.
    /// - Returns: The styled label.
    private func labelText(for volumeId: String, isCentral: Bool) -> Text {
        let text = Text(verbatim: vm.label(for: volumeId))
        return isCentral
            ? text.font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.primary)
            : text.font(.system(size: 8)).foregroundStyle(Color.secondary)
    }

    private func drawEdge(
        _ context: inout GraphicsContext,
        from: CGPoint, to: CGPoint,
        color: Color, weight: CGFloat
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path,
                       with: .color(color.opacity(0.2 + weight * 0.5)),
                       lineWidth: 0.5 + weight * 3.5)
    }

    // MARK: - Hit Areas

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.partnerVolumeIds, id: \.self) { id in
            if let pos = vm.nodePositions[id] {
                Button {
                    vm.toggleSelection(id)
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(pos)
                #if os(macOS)
                // Hover previews and never pins (#1383): only the click above selects.
                .onHover { hovering in
                    vm.hoverChanged(id, hovering: hovering)
                }
                #endif
                .accessibilityLabel(id)
                .accessibilityHint(String(localized: "volumeGraph.node.hint",
                                          defaultValue: "Shows this volume’s connections"))
                .help(String(
                    localized: "volumeGraph.node.help",
                    defaultValue: "View cross-volume reference counts for this volume — click for details and to explore its connections"
                ))
            }
        }
    }

    // MARK: - Overlay Controls

    @ViewBuilder
    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.scale != 1.0 || vm.panOffset != .zero {
                Button {
                    vm.resetViewport(animated: !reduceMotion)
                } label: {
                    Label(String(localized: "volumeGraph.resetView", defaultValue: "Reset View"),
                          systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .help(String(localized: "volumeGraph.resetView.help",
                             defaultValue: "Restore the graph’s pan and zoom to their original position"))
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }

            if vm.canNavigateBack {
                Button {
                    if let store = appState.crossReferenceStore {
                        Task { await vm.navigateBack(from: store) }
                    }
                } label: {
                    Label(String(localized: "volumeGraph.back", defaultValue: "Back"),
                          systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .help(String(localized: "volumeGraph.back.help",
                             defaultValue: "Return to the previous volume in the navigation history"))
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }

            if let sel = vm.displayedPartnerId {
                infoPanel(for: sel)
                    // A hover preview floats over the canvas without taking the pointer (#1383).
                    .allowsHitTesting(!vm.isPreviewingHover)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.canNavigateBack)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.displayedPartnerId)
    }

    @ViewBuilder
    private func infoPanel(for partnerId: String) -> some View {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let title    = manifest.first(where: { $0.volumeId == partnerId })?.title ?? partnerId
        let inCount  = vm.inboundCount(for: partnerId)
        let outCount = vm.outboundCount(for: partnerId)

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(partnerId)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.headline)
                    .lineLimit(3)

                Divider()

                if inCount > 0 {
                    Label("\(inCount) reference\(inCount == 1 ? "" : "s") into \(vm.centralVolumeId)",
                          systemImage: "arrow.left")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if outCount > 0 {
                    Label("\(outCount) reference\(outCount == 1 ? "" : "s") from \(vm.centralVolumeId)",
                          systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if let store = appState.crossReferenceStore {
                    Button(String(localized: "volumeGraph.exploreConnections",
                                  defaultValue: "Explore connections")) {
                        Task { await vm.recenterOn(volumeId: partnerId, from: store) }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .padding(.top, 2)
                    .help(String(localized: "volumeGraph.exploreConnections.help",
                                 defaultValue: "Recenter the graph on this volume to explore its own cross-volume references"))
                }
            }
        }
        .frame(maxWidth: 260)
        .fixedSize()
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

    /// Double-tap anywhere on the canvas restores the neutral viewport — the same
    /// recovery convention as the document-level graph.
    private var resetViewportGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded { vm.resetViewport(animated: !reduceMotion) }
    }
}
