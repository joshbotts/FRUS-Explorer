// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - PersonCoMentionNode

/// One node in the co-mention ego graph: the focus person or one of their partners (CA-8).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonCoMentionNode: Identifiable, Equatable {
    /// The rollup id (the People-browser identity), unique within the graph.
    let rollupId: Int
    /// The person's canonical display name.
    let name: String
    /// Shared-document count with the focus person (`0` for the focus node itself).
    let sharedWithFocus: Int

    var id: Int { rollupId }
}

// MARK: - PersonCoMentionEdge

/// One weighted edge in the co-mention ego graph: two rollups sharing `sharedDocuments`
/// documents (CA-8). `a`/`b` are rollup ids; the pair is undirected.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonCoMentionEdge: Equatable {
    /// One endpoint rollup id.
    let a: Int
    /// The other endpoint rollup id.
    let b: Int
    /// Distinct documents mentioning both endpoints (the edge weight).
    let sharedDocuments: Int
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
/// count. There is no silent truncation: the view shows the cap and how many partners the
/// focus person actually has when the cap bites.
///
/// ## Navigation
/// Tapping a partner node re-centres the graph on that person (changing the focus). A
/// history stack supports back-navigation, mirroring the volume graph.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
@Observable
@MainActor
final class PersonCoMentionGraphViewModel {

    // MARK: - Configuration

    /// The disclosed top-N partner cap (decision CA-8-1). Mirrors the volume graph's degree
    /// limits — bounded so the physics and self-join stay fast and the canvas stays legible.
    static let partnerLimit = 24

    // MARK: - Data

    private(set) var focusRollupId: Int
    private(set) var focusName: String
    var nodes: [PersonCoMentionNode] = []
    var edges: [PersonCoMentionEdge] = []
    var isLoading = false
    var error: String? = nil

    /// The focus person's total distinct partner count (before the cap), so the view can
    /// disclose "showing top N of M" when the cap bites.
    private(set) var totalPartnerCount = 0

    // MARK: - Navigation

    private(set) var history: [(id: Int, name: String)] = []

    // MARK: - Interaction

    var selectedPartnerId: Int? = nil

    /// Pinch-to-zoom magnification applied to the canvas; `1.0` is neutral.
    var scale: CGFloat = 1.0
    /// Pan translation applied to the canvas; `.zero` is neutral.
    var panOffset: CGSize = .zero

    private(set) var steadyScale: CGFloat = 1.0
    private(set) var steadyPanOffset: CGSize = .zero

    // MARK: - Layout

    var nodePositions: [Int: CGPoint] = [:]

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

    /// Partner nodes (everything but the focus), ordered by shared-document count desc.
    var partners: [PersonCoMentionNode] {
        nodes.filter { $0.rollupId != focusRollupId }
            .sorted { $0.sharedWithFocus != $1.sharedWithFocus
                ? $0.sharedWithFocus > $1.sharedWithFocus
                : $0.name < $1.name }
    }

    /// All rollup ids in the graph (focus first).
    var allRollupIds: [Int] { [focusRollupId] + partners.map(\.rollupId) }

    /// Whether the top-N cap actually elided partners (drives the disclosure text).
    var capApplied: Bool { totalPartnerCount > partners.count }

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

    // MARK: - Viewport gestures

    /// Applies an in-flight pinch gesture value on top of the committed zoom level.
    func magnificationChanged(_ value: CGFloat) {
        scale = max(0.25, min(4.0, steadyScale * value))
    }

    /// Commits the current zoom level so the next pinch starts from it.
    func magnificationEnded() { steadyScale = scale }

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
    func load(from store: PersonMentionStore) async {
        isLoading = true
        error = nil
        nodes = []
        edges = []
        nodePositions = [:]
        selectedPartnerId = nil
        totalPartnerCount = 0
        resetViewport(animated: false)
        do {
            // The disclosed top-N partners (bounded to the focus person's own documents).
            let partnerRows = try await store.topCoMentionedPeople(
                forRollupId: focusRollupId, limit: Self.partnerLimit)
            // A cheap over-limit probe: fetch one more than the cap to know whether the cap
            // actually elided anyone (so the disclosure is accurate), without an unbounded
            // count query.
            let probe = try await store.topCoMentionedPeople(
                forRollupId: focusRollupId, limit: Self.partnerLimit + 1)
            totalPartnerCount = probe.count

            var built: [PersonCoMentionNode] = [
                PersonCoMentionNode(rollupId: focusRollupId, name: focusName, sharedWithFocus: 0)
            ]
            for row in partnerRows {
                built.append(PersonCoMentionNode(rollupId: row.rollupId,
                                                 name: row.canonicalName,
                                                 sharedWithFocus: row.sharedDocuments))
            }
            nodes = built

            // Partner-partner edges + focus-partner edges, within the bounded ego set only.
            let ids = built.map(\.rollupId)
            let edgeRows = try await store.coMentionEdges(amongRollupIds: ids)
            edges = edgeRows.map { PersonCoMentionEdge(a: $0.a, b: $0.b, sharedDocuments: $0.sharedDocuments) }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        if canvasSize.width > 0 { rerunLayout(reduceMotion: false) }
    }

    // MARK: - Navigation

    /// Re-centres the graph on `rollupId`, pushing the current focus onto the history stack.
    func recenterOn(rollupId: Int, from store: PersonMentionStore) async {
        guard rollupId != focusRollupId else { return }
        let newName = name(for: rollupId)
        history.append((id: focusRollupId, name: focusName))
        focusRollupId = rollupId
        focusName = newName
        await load(from: store)
    }

    /// Pops the history stack and re-centres on the previous focus person.
    func navigateBack(from store: PersonMentionStore) async {
        guard let prev = history.popLast() else { return }
        focusRollupId = prev.id
        focusName = prev.name
        await load(from: store)
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
        layoutTask = Task { [weak self] in
            var current = initial
            for _ in 0..<15 {
                guard !Task.isCancelled else { break }
                current = PersonCoMentionGraphViewModel.runPhysics(
                    ids: ids, centralId: focus, edges: edgeList,
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

// MARK: - PersonCoMentionGraphView

/// Canvas-based co-mention ego graph (CA-8): the focus person at the centre with their
/// top-N co-mentioned partners orbiting in a spring-repulsion layout, edges weighted by
/// shared-document count.
///
/// The focus node is pinned at the canvas centre; partner node size encodes shared
/// documents with the focus, and edge thickness encodes pairwise co-mention weight.
/// Tapping a partner node opens an info panel with the shared-document count, an "Explore
/// connections" button that re-centres the graph on that person, and an "Open in Search"
/// button that deep-links to their mentions.
///
/// Accessibility mirrors `VolumeConnectionGraphView`: the `Canvas` is hidden from
/// VoiceOver and a transparent per-node hit-area button carries the label/hint. Reduce
/// Motion settles the layout instantly. The disclosed top-N cap and a legend appear below
/// the canvas.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonCoMentionGraphView: View {

    @State private var vm: PersonCoMentionGraphViewModel

    /// The store, injected by the host so no-index degradation happens above this view.
    let store: PersonMentionStore
    /// Opens a person's mentions in Search (reuses the CA-5 person deep-link).
    let onOpenPerson: (_ rollupId: Int, _ name: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the graph centred on the given focus person.
    init(focusRollupId: Int, focusName: String, store: PersonMentionStore,
         onOpenPerson: @escaping (_ rollupId: Int, _ name: String) -> Void) {
        _vm = State(initialValue: PersonCoMentionGraphViewModel(
            focusRollupId: focusRollupId, focusName: focusName))
        self.store = store
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
                            defaultValue: "\(vm.focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently mentioned focus person.")))
                } else {
                    graphContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !vm.partners.isEmpty && vm.error == nil && !vm.isLoading {
                legendBar
            }
        }
        .task(id: vm.focusRollupId) {
            await vm.load(from: store)
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
            let maxShared = CGFloat(vm.maxSharedWithFocus)
            for node in vm.partners {
                guard let pos = vm.nodePositions[node.rollupId] else { continue }
                let isSelected = vm.selectedPartnerId == node.rollupId
                // Size scales with shared documents (12…22 pt radius).
                let base = 12 + 10 * (CGFloat(node.sharedWithFocus) / maxShared)
                let r = isSelected ? base + 3 : base
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(isSelected ? .teal : Color.teal.opacity(0.6)))
                if isSelected {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 1.5)
                }
                context.draw(
                    Text(shortLabel(node.name)).font(.system(size: 8)).foregroundStyle(Color.secondary),
                    at: CGPoint(x: pos.x, y: pos.y + r + 8), anchor: .center)
            }

            // Focus node — drawn last, on top.
            guard let cp = vm.nodePositions[focusId] else { return }
            let cr: CGFloat = 26
            let centralRect = CGRect(x: cp.x - cr, y: cp.y - cr, width: cr * 2, height: cr * 2)
            context.fill(Path(ellipseIn: centralRect), with: .color(Color.accentColor))
            context.stroke(Path(ellipseIn: centralRect.insetBy(dx: -2, dy: -2)),
                           with: .color(.white), lineWidth: 2)
            context.draw(Image(systemName: "person.fill"),
                         in: centralRect.insetBy(dx: cr * 0.4, dy: cr * 0.4))
            context.draw(
                Text(shortLabel(vm.focusName))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.primary),
                at: CGPoint(x: cp.x, y: cp.y + cr + 8), anchor: .center)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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

    /// A compact node label — the first 14 characters of the canonical name.
    private func shortLabel(_ name: String) -> String { String(name.prefix(14)) }

    // MARK: - Hit Areas (accessibility + tap-to-select)

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.partners) { node in
            if let pos = vm.nodePositions[node.rollupId] {
                Button {
                    vm.selectedPartnerId = (vm.selectedPartnerId == node.rollupId) ? nil : node.rollupId
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(pos)
                #if os(macOS)
                .onHover { hovering in if hovering { vm.selectedPartnerId = node.rollupId } }
                #endif
                .accessibilityLabel(node.name)
                .accessibilityValue(String(
                    localized: "personCoMention.node.a11yValue",
                    defaultValue: "\(node.sharedWithFocus) shared documents with \(vm.focusName)"))
                .accessibilityHint(String(localized: "personCoMention.node.hint",
                                          defaultValue: "Tap to see the connection and re-centre the network on this person"))
                .help(String(localized: "personCoMention.node.help",
                             defaultValue: "Co-mention count with the focus person — click for details and to explore this person's own network"))
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
                    Task { await vm.navigateBack(from: store) }
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

            if let sel = vm.selectedPartnerId {
                infoPanel(for: sel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.canNavigateBack)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.selectedPartnerId)
    }

    @ViewBuilder
    private func infoPanel(for partnerId: Int) -> some View {
        let name = vm.name(for: partnerId)
        let shared = vm.sharedWithFocus(for: partnerId)
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.headline).lineLimit(3)
                Divider()
                Label(String(localized: "personCoMention.info.shared",
                             defaultValue: "\(shared) shared document\(shared == 1 ? "" : "s") with \(vm.focusName)"),
                      systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button(String(localized: "personCoMention.info.explore",
                                  defaultValue: "Explore connections")) {
                        Task { await vm.recenterOn(rollupId: partnerId, from: store) }
                    }
                    .buttonStyle(.bordered)
                    Button(String(localized: "personCoMention.info.openSearch",
                                  defaultValue: "Open in Search")) {
                        onOpenPerson(partnerId, name)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: 280)
        .fixedSize()
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
                Text(String(localized: "personCoMention.cap.disclosed",
                            defaultValue: "Showing the top \(vm.partners.count) co-mentioned people (of \(vm.totalPartnerCount)+ ) by shared-document count."))
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
