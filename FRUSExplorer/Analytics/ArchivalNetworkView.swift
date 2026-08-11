// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ArchivalNetworkView

/// The co-citation neighbourhood of one archival collection, drawn in four custodian sectors —
/// the Network mode of Archival Analytics (#765, design direction 2a).
///
/// The layout is **deterministic**: the sector comes from who holds the records and the radius
/// from how strongly the neighbour is co-cited, so the same focus always draws the same picture
/// and two readers comparing screens are comparing the same thing. There is no physics to settle,
/// which also means Reduce Motion has nothing to suppress in the layout itself.
///
/// It reuses CA-8's chrome — `Canvas` for the drawing, transparent buttons over each node for
/// hit-testing and VoiceOver, a permanently reserved info dock so the canvas never resizes under
/// a selection, pinch/pan with a double-tap reset, and `ScrollWheelZoomCatcher` on macOS.
///
/// ## What a link means
/// Volume-grain co-citation: two collections are linked when the same volumes drew on both. A
/// document has exactly one source note, so there is no document-level co-citation to draw — the
/// "shared documents" measure is how much material the two *jointly* supplied to the volumes they
/// share, not documents that cite both.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
struct ArchivalNetworkView: View {

    /// Every authority record, for the neighbourhood scan and the focus search.
    let collections: [AuthorityCollectionRecord]
    /// Volumes indexed on this device, for the export's provenance line.
    let indexedVolumeCount: Int
    /// The usage index, for the document measure and the umbrella expansion.
    let usage: CollectionUsageIndex?
    /// Opens Archival Neighbors for a collection.
    let onOpenNeighbors: (AuthorityCollectionRecord) -> Void
    /// Opens a collection's own authority record (#825b).
    let onOpenCollection: (AuthorityCollectionRecord) -> Void
    /// An authority collection id to open focused on, or `nil` to open unfocused (#825e).
    var initialFocusId: String?
    /// Opens Archival Neighbors for a central-file class.
    let onOpenClassNeighbors: (String) -> Void
    /// Hands a table and its methods statement up to the shell, which owns the share sheet.
    let onExport: (ArchivalExportRequest) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Compact height is iPhone landscape, where the fixed dock and a 240pt canvas would not both
    /// fit inside the sheet and the controls would be pushed off the top.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The collection at the centre.
    /// The collection whose neighbourhood is drawn. Seeded from ``initialFocusId`` on first
    /// appearance so a deep link can arrive focused (#825e); user-driven after that.
    @State private var focus: AuthorityCollectionRecord?
    /// Whether the initial focus has been applied, so re-appearing does not undo the reader's
    /// own choice of focus.
    @State private var hasSeededFocus = false
    /// Where the user has been, so re-centring is reversible.
    @State private var history: [AuthorityCollectionRecord] = []
    /// The computed neighbourhood.
    @State private var graph: ArchivalNetworkGraph?
    /// The selected node's id, which drives the dock and the node's ring.
    @State private var selectedNodeId: String?
    /// The focus search field's text.
    @State private var searchText = ""
    /// Whether the focus picker is showing.
    @State private var isChoosingFocus = false

    /// The edge measure. Persisted — it is a way of reading, not a per-visit choice.
    @AppStorage("frus.archivalAnalytics.edgeMeasure")
    private var measureRaw: String = ArchivalEdgeMeasure.sharedVolumes.rawValue
    /// The threshold slider, as a fraction of the focus's strongest link.
    @State private var minimumStrength: Double = 0.25
    /// How the Central Files umbrella is drawn.
    @State private var expansionRaw: String = ArchivalUmbrellaExpansion.collapsed.rawValue

    /// Live pinch value.
    @State private var scale: CGFloat = 1
    /// Committed zoom.
    @State private var steadyScale: CGFloat = 1
    /// Live drag value.
    @State private var panOffset: CGSize = .zero
    /// Committed pan.
    @State private var steadyPan: CGSize = .zero
    private var measure: ArchivalEdgeMeasure {
        let stored = ArchivalEdgeMeasure(rawValue: measureRaw) ?? .sharedVolumes
        // The document measure needs the usage index; without it every edge would weigh zero and
        // the graph would collapse to a ring of identical nodes.
        return (stored == .sharedDocuments && usage == nil) ? .sharedVolumes : stored
    }
    private var expansion: ArchivalUmbrellaExpansion {
        ArchivalUmbrellaExpansion(rawValue: expansionRaw) ?? .collapsed
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if let graph, !graph.nodes.isEmpty {
                graphRegion(graph)
                Divider()
                infoDock(graph)
                    .frame(height: isShortScreen ? 116 : 168)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $isChoosingFocus) {
            // #498: the picker's `.searchable` field is exactly the shape that wedges — a text
            // field inside a sheet's own NavigationStack. The preference is authored HERE, on the
            // view handed to `.sheet`, outside that stack. BrowserView's comment predicted this
            // surface by name.
            focusPicker
                #if os(iOS)
                .statusBarHidden(false)
                #endif
        }
        // One trigger, keyed on everything the graph depends on. `.task(id:)` also *cancels* a
        // rebuild that is still running when the reader drags the threshold slider again, which
        // an `.onChange` per input would not.
        // Seeded before the first rebuild, so a deep link draws its focus immediately rather
        // than drawing an unfocused graph and then replacing it. Guarded, because this view
        // re-appears whenever the mode picker returns to Network and the reader's own focus
        // must survive that.
        .task {
            guard !hasSeededFocus else { return }
            hasSeededFocus = true
            if let initialFocusId,
               let record = collections.first(where: { $0.id == initialFocusId }) {
                focus = record
            }
        }
        .task(id: rebuildToken) { await rebuild() }
    }

    /// Everything the neighbourhood depends on, as one comparable value.
    private var rebuildToken: String {
        "\(focus?.id ?? "")|\(measure.rawValue)|\(expansion.rawValue)|\(minimumStrength)"
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { controlChips; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 8) { controlChips }
            }
            thresholdSlider
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var controlChips: some View {
        Button {
            isChoosingFocus = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "scope").font(.caption2)
                Text(String(localized: "archival.network.focus", defaultValue: "Focus"))
                    .font(.caption).foregroundStyle(.secondary)
                Text(focus?.name ?? String(localized: "archival.network.focus.none",
                                           defaultValue: "Choose…"))
                    .font(.caption.weight(.medium)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
            Picker(String(localized: "archival.network.measure", defaultValue: "Link strength"),
                   selection: $measureRaw) {
                ForEach(ArchivalEdgeMeasure.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .disabled(usage == nil)
        } label: {
            chip(systemImage: "link",
                 caption: String(localized: "archival.network.measure",
                                 defaultValue: "Link strength"),
                 value: measure.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
            Picker(String(localized: "archival.network.umbrella",
                          defaultValue: "Central Files"), selection: $expansionRaw) {
                ForEach(ArchivalUmbrellaExpansion.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .disabled(usage == nil)
        } label: {
            chip(systemImage: "square.on.square.dashed",
                 caption: String(localized: "archival.network.umbrella",
                                 defaultValue: "Central Files"),
                 value: expansion.title)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if let graph, !graph.nodes.isEmpty {
            // CSV only. Nothing in this app has ever rendered a `Canvas` through
            // `AnalyticsFigureExporter`, so a figure here would be an unproven render path
            // shipped as a finished feature.
            AnalyticsSectionExportControl(exportCSV: { exportNeighbourhood(graph) })
        }

        if !history.isEmpty {
            Button {
                guard let previous = history.popLast() else { return }
                selectedNodeId = nil
                focus = previous
            } label: {
                Label(String(localized: "archival.network.back", defaultValue: "Back"),
                      systemImage: "chevron.backward")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func chip(systemImage: String, caption: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.caption2)
            Text(caption).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
            Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var thresholdSlider: some View {
        HStack(spacing: 10) {
            Text(String(localized: "archival.network.threshold", defaultValue: "Show links above"))
                .font(.caption).foregroundStyle(.secondary)
            Slider(value: $minimumStrength, in: 0.05...0.60, step: 0.05)
                .frame(maxWidth: 220)
            Text(minimumStrength, format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit())
                .frame(width: 38, alignment: .leading)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "archival.network.threshold.a11y",
                                   defaultValue: "Minimum link strength, as a share of the strongest link"))
    }

    // MARK: - Graph

    /// The canvas and its floating viewport button.
    ///
    /// The layout is derived from the `GeometryReader`'s own proxy rather than from state the
    /// reader writes back. Routing it through `@State` deadlocked: the only writer sat inside the
    /// branch that the state gated, so the geometry never entered the hierarchy, the size stayed
    /// zero, and the mode drew a spinner forever. `ArchivalNetworkBuilder.layout` is pure and
    /// runs over at most thirty nodes, so computing it here costs nothing.
    private func graphRegion(_ graph: ArchivalNetworkGraph) -> some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                let layout = ArchivalNetworkBuilder.layout(graph, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    canvas(graph, layout: layout)
                    hitAreas(graph, layout: layout)
                }
                .scaleEffect(scale, anchor: .center)
                .offset(panOffset)
                .gesture(MagnificationGesture()
                    .onChanged { scale = max(0.5, min(steadyScale * $0, 4)) }
                    .onEnded { _ in steadyScale = scale })
                .gesture(DragGesture(minimumDistance: 5)
                    .onChanged { panOffset = CGSize(width: steadyPan.width + $0.translation.width,
                                                    height: steadyPan.height + $0.translation.height) }
                    .onEnded { _ in steadyPan = panOffset })
                .gesture(TapGesture(count: 2).onEnded { resetViewport() })
                #if os(macOS)
                .background {
                    ScrollWheelZoomCatcher { factor in
                        scale = max(0.5, min(scale * factor, 4))
                        steadyScale = scale
                    }
                    .allowsHitTesting(false)
                }
                #endif
            }
            if scale != 1 || panOffset != .zero {
                Button {
                    resetViewport()
                } label: {
                    Label(String(localized: "archival.network.resetView", defaultValue: "Reset View"),
                          systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding()
            }
        }
        .frame(minHeight: isShortScreen ? 150 : 240)
    }

    /// `true` on iPhone landscape; always `false` on macOS and regular-height iOS.
    private var isShortScreen: Bool {
        #if os(iOS)
        return verticalSizeClass == .compact
        #else
        return false
        #endif
    }

    private func canvas(_ graph: ArchivalNetworkGraph,
                        layout: ArchivalNetworkLayout) -> some View {
        Canvas { context, _ in
            drawSectors(&context, layout: layout)
            drawRings(&context, layout: layout)
            drawHull(&context, graph: graph, layout: layout)
            drawSpokes(&context, graph: graph, layout: layout)
            drawNodes(&context, graph: graph, layout: layout)
            drawFocus(&context, graph: graph, layout: layout)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// The four custodian wedges, tinted so a node's colour and its position agree.
    private func drawSectors(_ context: inout GraphicsContext, layout: ArchivalNetworkLayout) {
        let starts: [(ArchivalRepositoryCategory, Double)] = [
            (.stateDepartment, 180), (.lotFile, 270), (.presidentialLibrary, 0),
            (.otherInstitution, 90),
        ]
        for (category, start) in starts {
            var path = Path()
            path.move(to: layout.center)
            path.addArc(center: layout.center, radius: layout.outerRadius,
                        startAngle: .degrees(start), endAngle: .degrees(start + 90),
                        clockwise: false)
            path.closeSubpath()
            context.fill(path, with: .color(category.color.opacity(0.07)))
        }
    }

    /// The dashed guide rings. Each marks a fraction of the *strongest* link in this graph, so
    /// the axis is self-scaling — the labels below the dock say what the fraction is worth here.
    private func drawRings(_ context: inout GraphicsContext, layout: ArchivalNetworkLayout) {
        for radius in layout.ringRadii {
            let rect = CGRect(x: layout.center.x - radius, y: layout.center.y - radius,
                              width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        }
    }

    /// The dashed hull around the expanded umbrella's classes, with its label.
    ///
    /// The rectangle comes from ``ArchivalNetworkLayout/classHull``, which the layout computes
    /// after placing the classes in their own sub-arc. Deriving it here from a bounding box of
    /// the class positions also enclosed whatever collection circles happened to fall inside it,
    /// and a dashed outline labelled "Central Files" drawn around a presidential library is the
    /// unit confusion the square-versus-circle distinction exists to prevent.
    private func drawHull(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,
                          layout: ArchivalNetworkLayout) {
        guard let rect = layout.classHull, graph.expandedUmbrella != nil else { return }
        context.stroke(Path(roundedRect: rect, cornerRadius: 18),
                       with: .color(ArchivalRepositoryCategory.stateDepartment.color.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        context.draw(
            Text(String(format: String(localized: "archival.network.hull %@",
                                       defaultValue: "Central Files — %@"),
                        expansion.title.lowercased()))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ArchivalRepositoryCategory.stateDepartment.color),
            at: CGPoint(x: rect.midX, y: rect.minY - 8), anchor: .center)
    }

    private func drawSpokes(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,
                            layout: ArchivalNetworkLayout) {
        for node in graph.nodes {
            guard let position = layout.positions[node.id] else { continue }
            var path = Path()
            path.move(to: layout.center)
            path.addLine(to: position)
            let weight = CGFloat(node.relativeStrength)
            context.stroke(path,
                           with: .color(node.category.color.opacity(0.2 + weight * 0.45)),
                           lineWidth: 0.5 + weight * 3)
        }
    }

    private func drawNodes(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,
                           layout: ArchivalNetworkLayout) {
        for node in graph.nodes {
            guard let position = layout.positions[node.id] else { continue }
            let isSelected = selectedNodeId == node.id
            let radius = ArchivalNetworkBuilder.radius(for: node) + (isSelected ? 3 : 0)
            let rect = CGRect(x: position.x - radius, y: position.y - radius,
                              width: radius * 2, height: radius * 2)
            // Circle for a collection, rounded square for a class. The shapes carry the unit
            // distinction on their own, so a reader who never opens the legend still cannot
            // mistake a subject heading for a body of records.
            let shape = node.kind == .collection
                ? Path(ellipseIn: rect)
                : Path(roundedRect: rect, cornerRadius: radius * 0.35)
            context.fill(shape, with: .color(isSelected
                                             ? node.category.color
                                             : node.category.color.opacity(0.62)))
            if isSelected {
                let outline = node.kind == .collection
                    ? Path(ellipseIn: rect.insetBy(dx: -2, dy: -2))
                    : Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: radius * 0.4)
                context.stroke(outline, with: .color(.white), lineWidth: 1.5)
            }
            context.draw(
                Text(shortLabel(node.label))
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary),
                at: CGPoint(x: position.x, y: position.y + radius + 8), anchor: .center)
        }
    }

    private func drawFocus(_ context: inout GraphicsContext, graph: ArchivalNetworkGraph,
                           layout: ArchivalNetworkLayout) {
        let radius: CGFloat = 26
        let rect = CGRect(x: layout.center.x - radius, y: layout.center.y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(Color.accentColor))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white),
                       lineWidth: 2)
        context.draw(Image(systemName: "archivebox.fill"),
                     in: rect.insetBy(dx: radius * 0.42, dy: radius * 0.42))
        context.draw(
            Text(shortLabel(graph.focus.name))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.primary),
            at: CGPoint(x: layout.center.x, y: layout.center.y + radius + 8), anchor: .center)
    }

    /// The drawn caption for a node.
    ///
    /// Truncation happens at the END and is marked, because the disambiguator this graph relies
    /// on is a suffix: cutting `White House Central Files · Ford Library` at sixteen characters
    /// draws it identically to the Carter Library record beside it, which is exactly the
    /// collision `disambiguate` exists to prevent. Long labels are cut in the middle so both the
    /// name and the repository survive.
    private func shortLabel(_ label: String) -> String {
        guard label.count > 26 else { return label }
        guard let separator = label.range(of: " · ") else {
            return String(label.prefix(25)) + "…"
        }
        let name = label[label.startIndex..<separator.lowerBound]
        let qualifier = label[separator.upperBound...]
        return String(name.prefix(14)) + "… · " + String(qualifier.prefix(10))
    }

    // MARK: - Hit areas

    @ViewBuilder
    private func hitAreas(_ graph: ArchivalNetworkGraph,
                          layout: ArchivalNetworkLayout) -> some View {
        ForEach(graph.nodes) { node in
            if let position = layout.positions[node.id] {
                Button {
                    selectedNodeId = selectedNodeId == node.id ? nil : node.id
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(position)
                .contextMenu { nodeActions(node) }
                .accessibilityLabel(node.label)
                .accessibilityValue(accessibilityValue(for: node, in: graph))
                .accessibilityHint(String(localized: "archival.network.node.hint",
                                          defaultValue: "Select to see this link's detail; long-press for actions"))
            }
        }
    }

    private func accessibilityValue(for node: ArchivalNetworkNode,
                                    in graph: ArchivalNetworkGraph) -> String {
        let kind = node.kind == .collection
            ? String(localized: "archival.network.kind.collection", defaultValue: "collection")
            : String(localized: "archival.network.kind.class",
                     defaultValue: "central-file class")
        return String(format: String(localized: "archival.network.node.a11y %@ %@ %@",
                                     defaultValue: "%1$@, %2$@, %3$@"),
                      kind, node.category.displayName,
                      measure.detail(shared: node.sharedVolumeCount,
                                     documents: node.sharedDocumentCount))
    }

    @ViewBuilder
    private func nodeActions(_ node: ArchivalNetworkNode) -> some View {
        switch node.kind {
        case .collection:
            if let record = collections.first(where: { $0.id == node.id }) {
                Button {
                    recentre(on: record)
                } label: {
                    Label(String(localized: "archival.network.recentre",
                                 defaultValue: "Explore This Collection"),
                          systemImage: "point.3.connected.trianglepath.dotted")
                }
                Button {
                    onOpenNeighbors(record)
                } label: {
                    Label(String(localized: "archival.network.neighbors",
                                 defaultValue: "Show Archival Neighbors"),
                          systemImage: "square.stack.3d.up")
                }
                // #825b: the approved dock listed this beside the other two and it was dropped
                // unrecorded. Archival Neighbors reads the LOCAL index, so for a reader with few
                // volumes indexed it answers honestly-empty — and without this the dock had no
                // route at all to what the app knows about the collection corpus-wide.
                Button {
                    onOpenCollection(record)
                } label: {
                    Label(String(localized: "archival.network.openCollection",
                                 defaultValue: "Open Collection"),
                          systemImage: "archivebox")
                }
            }
        case .centralFileClass:
            // A class routes to the class-keyed neighbours query, never to a collection detail —
            // it is not a collection and has no record to open.
            Button {
                onOpenClassNeighbors(node.name)
            } label: {
                Label(String(localized: "archival.network.classNeighbors",
                             defaultValue: "Show Documents in This Class"),
                      systemImage: "square.stack.3d.up")
            }
        }
    }

    // MARK: - Info dock

    /// Permanently reserved (CA-8 Win-6): the canvas must not resize when a node is selected, or
    /// every other node moves under the reader's finger at the moment they tap one.
    private func infoDock(_ graph: ArchivalNetworkGraph) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let node = graph.nodes.first(where: { $0.id == selectedNodeId }) {
                    selectedCard(node, in: graph)
                } else {
                    dockPlaceholder(graph)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private func selectedCard(_ node: ArchivalNetworkNode,
                              in graph: ArchivalNetworkGraph) -> some View {
        Text(node.label).font(.headline)
        Text(node.kind == .collection
             ? node.category.displayName
             : String(localized: "archival.network.class.caption",
                      defaultValue: "Central-file class — a subject heading inside the State Department's filing system, not a collection"))
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        Text(String(format: String(localized: "archival.network.card.detail %lld %lld %@",
                                   defaultValue: "%1$lld volumes cite both this and %3$@; together they supplied %2$lld documents to those volumes."),
                    Int64(node.sharedVolumeCount), Int64(node.sharedDocumentCount),
                    graph.focus.name))
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 12) { nodeActions(node) }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private func dockPlaceholder(_ graph: ArchivalNetworkGraph) -> some View {
        Text(String(localized: "archival.network.dock.title",
                    defaultValue: "Select a node to see the link"))
            .font(.subheadline.weight(.medium))
        Text(dockSummary(graph))
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 14) {
            legendKey(shape: "circle.fill",
                      text: String(localized: "archival.network.legend.collection",
                                   defaultValue: "Collection"))
            legendKey(shape: "square.fill",
                      text: String(localized: "archival.network.legend.class",
                                   defaultValue: "Central-file class"))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendKey(shape: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: shape).foregroundStyle(ArchivalRepositoryCategory.stateDepartment.color)
            Text(text)
        }
    }

    /// The dock's standing sentence — what is drawn, what the rings mean here, and what the cap
    /// withheld. It is the mode's whole disclosure, so it is always visible when nothing is
    /// selected rather than tucked behind an info button.
    private func dockSummary(_ graph: ArchivalNetworkGraph) -> String {
        let strongest: String
        switch measure {
        case .sharedVolumes:
            strongest = graph.strongestMeasureValue
                .formatted(.percent.precision(.fractionLength(0)))
        case .sharedDocuments:
            strongest = Int(graph.strongestMeasureValue).formatted(.number)
        }
        // Numerator and denominator count the same population. The first draft put the drawn
        // nodes — class squares included — over a count of collections only, so an expanded
        // umbrella could report drawing more collections than were co-cited at all.
        var text = String(format: String(
            localized: "archival.network.dock.summary.v2 %lld %lld %@",
            defaultValue: "%1$lld of the %2$lld nodes above the current threshold are drawn. Distance from the center shows link strength. The dashed rings mark three quarters, one half, and one quarter of the strongest link here (%3$@)."),
            Int64(graph.nodes.count), Int64(graph.nodesAboveThreshold), strongest)
        text += " " + String(format: String(
            localized: "archival.network.dock.grain %lld",
            defaultValue: "%lld collections share two or more volumes with this one. Links are volume-grain — the same volumes drew on both — which is not document-level affinity."),
            Int64(graph.partnersTotal))
        if graph.isCapped {
            text += " " + String(format: String(
                localized: "archival.network.dock.capped.v2 %lld",
                defaultValue: "%lld more are held back so each custodian's quadrant stays readable; every quadrant keeps its strongest. Raise the threshold to narrow the neighbourhood rather than to see more of it."),
                Int64(graph.withheldCount))
        }
        if graph.classNodeCount > 0 {
            text += " " + String(format: String(
                localized: "archival.network.dock.classes %lld",
                defaultValue: "The %lld squares are central-file classes drawn from inside the Central Files record, which is hidden while they are shown."),
                Int64(graph.classNodeCount))
        }
        return text
    }

    // MARK: - Empty states

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            if focus == nil {
                ContentUnavailableView(
                    String(localized: "archival.network.empty.title",
                           defaultValue: "Choose a Collection"),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text(String(localized: "archival.network.empty.detail",
                                             defaultValue: "Pick a collection to see which other bodies of records the same volumes drew on."))
                )
            } else if graph?.nodes.isEmpty == true {
                ContentUnavailableView(
                    String(localized: "archival.network.none.title",
                           defaultValue: "No Co-Cited Collections"),
                    systemImage: "circle.dashed",
                    description: Text(String(format: String(
                        localized: "archival.network.none.detail.v2 %@ %@",
                        defaultValue: "No other collection shares two or more volumes with %1$@ above the current threshold. %2$@"),
                        focus?.name ?? "",
                        minimumStrength > 0.05
                            ? String(localized: "archival.network.none.lower",
                                     defaultValue: "Lower the threshold, or choose a more widely cited collection.")
                            : String(localized: "archival.network.none.floor",
                                     defaultValue: "The threshold is already at its lowest, so this collection simply shares no volumes with another — choose a more widely cited one.")))
                )
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Focus picker

    private var focusPicker: some View {
        NavigationStack {
            List(focusCandidates, id: \.id) { record in
                Button {
                    recentre(on: record)
                    isChoosingFocus = false
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(record.name).font(.callout)
                        Text(String(format: String(
                            localized: "archival.network.picker.caption %@ %lld",
                            defaultValue: "%1$@ · cited by %2$lld volumes"),
                            record.repository ?? ArchivalRepositoryCategory.from(record).displayName,
                            Int64(record.volumeIds.count)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText,
                        prompt: Text(String(localized: "archival.network.picker.prompt",
                                            defaultValue: "Set focus collection…")))
            .navigationTitle(String(localized: "archival.network.picker.title",
                                    defaultValue: "Focus Collection"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                        isChoosingFocus = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    /// Collections offered as a focus: those citing enough volumes to have a neighbourhood at
    /// all, most widely cited first, narrowed by the search field.
    private var focusCandidates: [AuthorityCollectionRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return collections
            .filter { $0.volumeIds.count >= ArchivalNetworkBuilder.minimumSharedVolumes }
            .filter {
                query.isEmpty || $0.name.lowercased().contains(query)
                    || ($0.repository?.lowercased().contains(query) ?? false)
            }
            .sorted { a, b in
                if a.volumeIds.count != b.volumeIds.count {
                    return a.volumeIds.count > b.volumeIds.count
                }
                return a.id < b.id
            }
            .prefix(200)
            .map { $0 }
    }

    // MARK: - Actions

    private func recentre(on record: AuthorityCollectionRecord) {
        if let focus, focus.id != record.id { history.append(focus) }
        selectedNodeId = nil
        resetViewport()
        focus = record
    }

    private func resetViewport() {
        let apply = {
            scale = 1; steadyScale = 1; panOffset = .zero; steadyPan = .zero
        }
        if reduceMotion { apply() } else { withAnimation(.easeOut(duration: 0.25)) { apply() } }
    }

    /// Opens on the most widely cited collection that is not the umbrella — the umbrella is a
    /// neighbour of nearly everything, so centring on it would open the mode on its least
    /// informative picture.
    private func seedFocus() -> AuthorityCollectionRecord? {
        collections
            .filter { $0.id != ArchivalCollectionsData.umbrellaCollectionId }
            .max { a, b in
                if a.volumeIds.count != b.volumeIds.count {
                    return a.volumeIds.count < b.volumeIds.count
                }
                return a.id > b.id
            }
    }

    /// Rebuilds the neighbourhood **off the main actor**.
    ///
    /// The scan touches every one of the 4,423 authority records with two set intersections, and
    /// an expanded umbrella additionally walks 10,435 class keys. That is not main-thread work,
    /// and the threshold slider fires it on every step.
    /// Exports the drawn neighbourhood — exactly what the graph shows, with the caveats that
    /// make a link readable.
    private func exportNeighbourhood(_ graph: ArchivalNetworkGraph) {
        let table = ChartInspectorData(
            id: "archival.network",
            title: String(format: String(localized: "archival.export.title.network %@",
                                         defaultValue: "Co-cited with %@"), graph.focus.name),
            columns: [
                String(localized: "archival.table.unit", defaultValue: "Archival unit"),
                String(localized: "archival.export.column.kind", defaultValue: "Kind"),
                String(localized: "archival.table.custodian", defaultValue: "Custodian"),
                String(localized: "archival.export.column.sharedVolumes",
                       defaultValue: "Shared volumes"),
                String(localized: "archival.export.column.sharedDocuments",
                       defaultValue: "Jointly supplied documents"),
                String(localized: "archival.export.column.strength",
                       defaultValue: "Share of strongest link"),
            ],
            rowCells: graph.nodes.map { node in
                [node.label,
                 node.kind == .collection
                    ? String(localized: "archival.network.kind.collection",
                             defaultValue: "collection")
                    : String(localized: "archival.network.kind.class",
                             defaultValue: "central-file class"),
                 node.category.displayName,
                 "\(node.sharedVolumeCount)",
                 "\(node.sharedDocumentCount)",
                 node.relativeStrength.formatted(.percent.precision(.fractionLength(0)))]
            })
        onExport(ArchivalExportRequest(
            table: table,
            provenance: ArchivalAnalyticsExport.network(
                focusName: graph.focus.name, measure: measure, drawn: graph.nodes.count,
                aboveThreshold: graph.nodesAboveThreshold, partnersTotal: graph.partnersTotal,
                indexedVolumeCount: indexedVolumeCount)))
    }

    private func rebuild() async {
        if focus == nil { focus = seedFocus() }
        guard let focus else {
            graph = nil
            return
        }
        let inputs = (collections: collections, usage: usage, focus: focus, measure: measure,
                      threshold: minimumStrength, expansion: expansion)
        let built = await Task.detached(priority: .userInitiated) {
            ArchivalNetworkBuilder.graph(
                focus: inputs.focus, in: inputs.collections, usage: inputs.usage,
                measure: inputs.measure, minimumRelativeStrength: inputs.threshold,
                expansion: inputs.expansion)
        }.value
        // `.task(id:)` cancels this Task when the token changes, but a *detached* child is not
        // cancelled with it — so a superseded scan can still return, and the slower of two
        // overlapping rebuilds would win. Dropping a cancelled result is what makes the last
        // token the one on screen.
        guard !Task.isCancelled else { return }
        graph = built
        if !built.nodes.contains(where: { $0.id == selectedNodeId }) { selectedNodeId = nil }
    }
}
