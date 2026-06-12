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
/// Version history:
///   1.0 — Corpus-wide free-layout graph
///   2.0 — Redesigned as per-volume ego graph with pinned centre and navigation history
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

    var selectedPartnerId: String? = nil

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
                let isSelected = vm.selectedPartnerId == id
                let r: CGFloat = isSelected ? 22 : 18
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
                             with: .color(isSelected ? nodeColor : nodeColor.opacity(0.6)))
                if isSelected {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 1.5)
                }

                context.draw(
                    Text(String(id.prefix(10))).font(.system(size: 8)).foregroundStyle(Color.secondary),
                    at: CGPoint(x: pos.x, y: pos.y + r + 8),
                    anchor: .center
                )
            }

            // Central node — drawn last so it renders above partner nodes
            guard let cp = vm.nodePositions[centralId] else { return }
            let cr: CGFloat = 28
            let centralRect = CGRect(x: cp.x - cr, y: cp.y - cr, width: cr * 2, height: cr * 2)
            context.fill(Path(ellipseIn: centralRect), with: .color(Color.accentColor))
            context.stroke(Path(ellipseIn: centralRect.insetBy(dx: -2, dy: -2)),
                           with: .color(.white), lineWidth: 2)
            context.draw(Image(systemName: "books.vertical.fill"),
                         in: centralRect.insetBy(dx: cr * 0.35, dy: cr * 0.35))
            context.draw(
                Text(String(centralId.prefix(10)))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary),
                at: CGPoint(x: cp.x, y: cp.y + cr + 8),
                anchor: .center
            )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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
                    vm.selectedPartnerId = (vm.selectedPartnerId == id) ? nil : id
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(pos)
                #if os(macOS)
                .onHover { hovering in
                    if hovering { vm.selectedPartnerId = id }
                }
                #endif
                .accessibilityLabel(id)
                .accessibilityHint(String(localized: "volumeGraph.node.hint",
                                          defaultValue: "Tap to view connections"))
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
                             defaultValue: "Restore the graph's pan and zoom to their original position"))
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

            if let sel = vm.selectedPartnerId {
                infoPanel(for: sel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.canNavigateBack)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.selectedPartnerId)
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
