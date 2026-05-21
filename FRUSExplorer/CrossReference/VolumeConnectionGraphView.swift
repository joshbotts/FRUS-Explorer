// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - VolumeConnectionGraphViewModel

/// ViewModel for the volume-level cross-reference graph in the Corpus Browser.
///
/// Loads all cross-volume reference counts from `CrossReferenceStore.volumeLevelConnections()`,
/// builds a node/edge representation, and runs a force-directed layout. Edge line width is
/// scaled to the reference count relative to the maximum count in the dataset, giving a
/// visual indication of connection strength.
///
/// ## Interaction
/// Clicking/tapping a volume node selects it and shows a ranked list of its connections
/// in the info panel. Clicking again deselects. Pinch-to-zoom and drag-to-pan work the
/// same as in `CrossReferenceGraphView`.
///
/// Version history:
///   1.0 — Initial implementation for CorpusBrowserWindowView Connections mode
@Observable
@MainActor
final class VolumeConnectionGraphViewModel {

    // MARK: - Data

    var connections: [VolumeConnectionEdge] = []
    var isLoading = false
    var error: String? = nil

    // MARK: - Layout

    var nodePositions: [String: CGPoint] = [:]

    // MARK: - Interaction

    var selectedVolumeId: String? = nil
    var scale: CGFloat = 1.0
    var panOffset: CGSize = .zero

    // MARK: - Private

    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>? = nil

    // MARK: - Derived

    var volumeIds: [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for edge in connections {
            if seen.insert(edge.sourceVolumeId).inserted { ids.append(edge.sourceVolumeId) }
            if seen.insert(edge.targetVolumeId).inserted { ids.append(edge.targetVolumeId) }
        }
        return ids.sorted()
    }

    var maxCount: Int { connections.map(\.count).max() ?? 1 }

    /// Ranked connections for the selected volume: (partnerVolumeId, count, isOutbound).
    var selectedConnections: [(volumeId: String, count: Int, isOutbound: Bool)] {
        guard let sel = selectedVolumeId else { return [] }
        var result: [(String, Int, Bool)] = []
        for edge in connections {
            if edge.sourceVolumeId == sel {
                result.append((edge.targetVolumeId, edge.count, true))
            } else if edge.targetVolumeId == sel {
                result.append((edge.sourceVolumeId, edge.count, false))
            }
        }
        return result.sorted { $0.1 > $1.1 }
    }

    var totalEdgesForSelected: Int {
        selectedConnections.reduce(0) { $0 + $1.count }
    }

    // MARK: - Load

    func load(from store: CrossReferenceStore, limitToVolumeIds: [String]? = nil) async {
        guard connections.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            connections = try await store.volumeLevelConnections(limitToVolumeIds: limitToVolumeIds)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        if canvasSize.width > 0 { rerunLayout(reduceMotion: false) }
    }

    func reload(from store: CrossReferenceStore, limitToVolumeIds: [String]? = nil) async {
        connections = []
        nodePositions = [:]
        await load(from: store, limitToVolumeIds: limitToVolumeIds)
    }

    // MARK: - Canvas size / layout

    func onCanvasSizeChanged(_ size: CGSize, reduceMotion: Bool) {
        canvasSize = size
        if !connections.isEmpty && size.width > 0 && size.height > 0 {
            rerunLayout(reduceMotion: reduceMotion)
        }
    }

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        let ids  = volumeIds
        let edges = connections
        let size = canvasSize
        guard !ids.isEmpty else { return }

        // Circular seed positions
        let cx = size.width / 2, cy = size.height / 2
        let r  = min(size.width, size.height) * 0.35
        var initial: [String: CGPoint] = [:]
        for (i, id) in ids.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(ids.count)
            initial[id] = CGPoint(x: cx + r * CGFloat(cos(angle)),
                                  y: cy + r * CGFloat(sin(angle)))
        }

        if reduceMotion || ids.count <= 2 {
            nodePositions = Self.runPhysics(ids: ids, edges: edges,
                                            positions: initial, size: size, iterations: 300)
            return
        }

        nodePositions = initial
        layoutTask = Task { [weak self] in
            var current = initial
            for _ in 0..<15 {
                guard !Task.isCancelled else { break }
                current = VolumeConnectionGraphViewModel.runPhysics(
                    ids: ids, edges: edges, positions: current, size: size, iterations: 20)
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

    /// Spring-repulsion force-directed layout.
    /// Same physics model as `CrossReferenceGraphViewModel.forceDirectedLayout` but without
    /// a pinned central node — all volume nodes are free to move.
    static func runPhysics(
        ids: [String],
        edges: [VolumeConnectionEdge],
        positions: [String: CGPoint],
        size: CGSize,
        iterations: Int
    ) -> [String: CGPoint] {
        let k_s:     CGFloat = 0.006
        let L0:      CGFloat = 150
        let k_r:     CGFloat = 7_000
        let damping: CGFloat = 0.82
        let pad:     CGFloat = 44

        var pos = positions
        var vel: [String: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

        for _ in 0..<iterations {
            var forces: [String: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

            // Spring forces
            for edge in edges {
                guard let ps = pos[edge.sourceVolumeId],
                      let pt = pos[edge.targetVolumeId] else { continue }
                let dx = pt.x - ps.x, dy = pt.y - ps.y
                let d  = max(hypot(dx, dy), 1)
                let f  = k_s * (d - L0)
                let ux = dx / d, uy = dy / d
                forces[edge.sourceVolumeId]?.dx += ux * f
                forces[edge.sourceVolumeId]?.dy += uy * f
                forces[edge.targetVolumeId]?.dx -= ux * f
                forces[edge.targetVolumeId]?.dy -= uy * f
            }

            // Repulsion between all pairs
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
        for id in volumeIds {
            guard let pos = nodePositions[id] else { continue }
            let dx = pos.x - point.x, dy = pos.y - point.y
            if sqrt(dx * dx + dy * dy) <= 22 { return id }
        }
        return nil
    }
}

// MARK: - VolumeConnectionGraphView

/// Canvas-based force-directed graph of volume-to-volume cross-reference relationships.
///
/// Displayed inside the Corpus Browser's subseries detail pane. Each node represents
/// a FRUS volume; each edge represents one or more document-level cross-references
/// between those volumes. Edge line width is proportional to the reference count.
///
/// When `limitToVolumeIds` is non-nil, only edges between volumes in that set are shown
/// (subseries-scoped view). Pass `nil` for a corpus-wide view (not recommended — the
/// full corpus produces hundreds of nodes that overwhelm both the layout and the user).
///
/// ## Layout
/// Force-directed spring-repulsion (same physics as the document-level ego graph).
/// All nodes are free — no central node is pinned. Animated settling unless system
/// Reduce Motion is active.
///
/// ## Interaction
/// - **macOS**: hover selects; click-selects and shows info panel with ranked connections
/// - **iOS/iPadOS**: tap selects; second tap deselects
/// - Pinch-to-zoom and drag-to-pan on all platforms
///
/// Version history:
///   1.0 — Initial implementation for CorpusBrowserWindowView Connections mode
///   1.1 — Session 75: `limitToVolumeIds` parameter added; graph moved from corpus-level
///          to subseries detail pane to prevent overwhelming node counts
struct VolumeConnectionGraphView: View {

    /// When non-nil, restricts edges to those where both endpoints are in this set.
    /// Pass the volume IDs of the selected subseries to scope to that subseries.
    var limitToVolumeIds: [String]?

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var vm = VolumeConnectionGraphViewModel()

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
            } else if vm.volumeIds.isEmpty {
                ContentUnavailableView(
                    "No Volume Connections",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Cross-references between volumes appear here after indexing. Download and index at least two volumes to see connections.")
                )
            } else {
                graphContent
            }
        }
        .task {
            if let store = appState.crossReferenceStore {
                await vm.load(from: store, limitToVolumeIds: limitToVolumeIds)
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
                .onChange(of: geo.size, initial: true) { _, size in
                    vm.onCanvasSizeChanged(size, reduceMotion: reduceMotion)
                }
            }
            infoPanelOverlay
                .padding()
        }
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        Canvas { context, _ in
            let maxCount = CGFloat(vm.maxCount)

            // Draw edges
            for edge in vm.connections {
                guard let from = vm.nodePositions[edge.sourceVolumeId],
                      let to   = vm.nodePositions[edge.targetVolumeId] else { continue }
                let weight = CGFloat(edge.count) / maxCount
                let lineWidth = 0.5 + weight * 3.5
                let alpha     = 0.15 + weight * 0.45
                let isSelectedEdge = vm.selectedVolumeId == edge.sourceVolumeId
                    || vm.selectedVolumeId == edge.targetVolumeId
                let color: Color = isSelectedEdge
                    ? .accentColor.opacity(0.6 + weight * 0.3)
                    : .secondary.opacity(alpha)

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }

            // Draw nodes
            for id in vm.volumeIds {
                guard let pos = vm.nodePositions[id] else { continue }
                let isSelected = vm.selectedVolumeId == id
                let r: CGFloat = isSelected ? 22 : 16
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)

                // Fill
                context.fill(Path(ellipseIn: rect), with: .color(
                    isSelected ? Color.accentColor : Color.accentColor.opacity(0.25)
                ))

                // Selection ring
                if isSelected {
                    context.stroke(
                        Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                        with: .color(.white),
                        lineWidth: 1.5
                    )
                }

                // Volume label — first 8 chars of volumeId to fit in node
                let label = String(id.prefix(8))
                let image = Image(systemName: "books.vertical")
                context.draw(image, in: rect.insetBy(dx: r * 0.3, dy: r * 0.3))

                // Text label below node
                context.draw(
                    Text(label).font(.system(size: 8)).foregroundStyle(Color.secondary),
                    at: CGPoint(x: pos.x, y: pos.y + r + 8),
                    anchor: .center
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    // MARK: - Hit Areas

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.volumeIds, id: \.self) { id in
            if let pos = vm.nodePositions[id] {
                Button {
                    vm.selectedVolumeId = (vm.selectedVolumeId == id) ? nil : id
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(pos)
                #if os(macOS)
                .onHover { hovering in
                    if hovering { vm.selectedVolumeId = id }
                }
                #endif
                .accessibilityLabel(id)
                .accessibilityHint("Tap to see connections")
            }
        }
    }

    // MARK: - Info Panel

    @ViewBuilder
    private var infoPanelOverlay: some View {
        if let sel = vm.selectedVolumeId {
            let manifest = appState.manifestStore.diffResult?.known
                ?? appState.manifestStore.bundledEntries
            let title = manifest.first(where: { $0.volumeId == sel })?.title ?? sel

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text(title)
                        .font(.headline)
                        .lineLimit(3)

                    if vm.totalEdgesForSelected > 0 {
                        Text("\(vm.totalEdgesForSelected) total cross-references")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        ForEach(vm.selectedConnections.prefix(8), id: \.volumeId) { conn in
                            HStack(spacing: 4) {
                                Image(systemName: conn.isOutbound
                                      ? "arrow.right" : "arrow.left")
                                    .font(.system(size: 9))
                                    .foregroundStyle(conn.isOutbound ? .green : .blue)
                                Text(conn.volumeId)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(conn.count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if vm.selectedConnections.count > 8 {
                            Text("+ \(vm.selectedConnections.count - 8) more")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("No cross-volume references recorded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 260)
            .fixedSize()
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: sel)
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { vm.scale = max(0.25, min(4.0, $0)) }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { vm.panOffset = $0.translation }
    }
}
