// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - CrossReferenceGraphView

/// Cross-reference graph renderer for a single FRUS document.
///
/// ## Layout
/// Uses a three-column directed layout:
///   [Inbound nodes] → [Central document] → [Outbound nodes]
///
/// For graphs with ≤20 cross-references the columns are statically distributed.
/// For 21–100 cross-references a force-directed spring layout is used with animated
/// settling that respects the system Reduce Motion setting.
///
/// When the total node count exceeds 30, same-volume nodes are grouped into cluster
/// nodes. Clusters expand on tap/click.
///
/// ## Accessibility
/// The `Canvas` is hidden from VoiceOver. Transparent hit-area buttons overlaid at
/// each node position serve as accessibility elements, each labelled with the document
/// title and its role (inbound / outbound / cluster). This satisfies the requirement for
/// explicit accessibility element overlays on custom Canvas views.
///
/// ## Reduce Motion
/// The force-directed settling animation is disabled when the system Reduce Motion
/// setting is active. Nodes appear immediately in their final positions.
///
/// Version history:
///   1.0 — Session 18: initial implementation
///   1.1 — Session 27: Q3 structured-list a11y representation; Q4 Reduce Motion transition fix
///   1.2 — Session 37: context passage shown in node info panel when available
///   1.3 — Session 61: node hit areas converted from Circle+onTapGesture to Button
///          so Tab-key keyboard navigation can reach individual nodes (F-018)
struct CrossReferenceGraphView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var vm: CrossReferenceGraphViewModel

    init(
        entry: DocumentBrowserEntry,
        crossReferenceStore: CrossReferenceStore,
        downloadedVolumeIds: Set<String>
    ) {
        _vm = State(initialValue: CrossReferenceGraphViewModel(
            centralDocumentId: entry.documentId,
            centralVolumeId: entry.volumeId,
            crossReferenceStore: crossReferenceStore,
            downloadedVolumeIds: downloadedVolumeIds
        ))
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack(path: $vm.navigationPath) {
            VStack(spacing: 0) {
                if vm.hasUndownloadedSources { undownloadedBanner }
                filterToolbar

                if vm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else if let err = vm.error {
                    Spacer()
                    ContentUnavailableView(
                        String(localized: "graph.error.title", defaultValue: "Graph Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(err)
                    )
                    Spacer()
                } else if vm.displayNodes.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        String(localized: "graph.empty.title", defaultValue: "No References"),
                        systemImage: "arrow.triangle.branch",
                        description: Text(String(localized: "graph.empty.detail",
                            defaultValue: "This document has no recorded cross-references."))
                    )
                    Spacer()
                } else {
                    graphContentArea
                }
            }
            .navigationTitle(
                String(localized: "graph.title", defaultValue: "Cross-References")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "graph.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                #if os(iOS)
                DocumentView(entry: entry)
                #else
                MacDocumentView(entry: entry, navigationPath: .constant([]))
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task { await vm.loadGraph() }
    }

    // MARK: - Graph Content

    @ViewBuilder
    private var graphContentArea: some View {
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

            // Info panel floats above the scaled canvas at a fixed location.
            nodeInfoPanel
                .padding()
                // Q4: suppress scale animation under Reduce Motion
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                    value: vm.selectedNodeKey
                )
        }
        // Q3: VoiceOver alternative — structured inbound/outbound reference list
        .accessibilityRepresentation { graphAccessibilityList }
    }

    // MARK: - Accessibility List Representation (Q3)

    @ViewBuilder
    private var graphAccessibilityList: some View {
        let inbound = vm.displayNodes.filter {
            if case .inbound = $0.kind { return true }
            if case .clusterInbound = $0.kind { return true }
            return false
        }
        let outbound = vm.displayNodes.filter {
            if case .outbound = $0.kind { return true }
            if case .clusterOutbound = $0.kind { return true }
            return false
        }

        VStack(alignment: .leading, spacing: 0) {
            if !inbound.isEmpty {
                Text(String(localized: "graph.a11y.section.inbound",
                            defaultValue: "Inbound References"))
                    .accessibilityAddTraits(.isHeader)
                ForEach(inbound) { node in
                    Button {
                        #if os(macOS)
                        vm.navigateToNode(node.id)
                        #else
                        vm.tapNode(node.id, reduceMotion: reduceMotion)
                        #endif
                    } label: {
                        Text(node.accessibilityLabel)
                    }
                }
            }
            if !outbound.isEmpty {
                Text(String(localized: "graph.a11y.section.outbound",
                            defaultValue: "Outbound References"))
                    .accessibilityAddTraits(.isHeader)
                ForEach(outbound) { node in
                    Button {
                        #if os(macOS)
                        vm.navigateToNode(node.id)
                        #else
                        vm.tapNode(node.id, reduceMotion: reduceMotion)
                        #endif
                    } label: {
                        Text(node.accessibilityLabel)
                    }
                }
            }
        }
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        Canvas { context, size in
            // Draw edges
            for edge in vm.displayEdges {
                guard let from = vm.nodePositions[edge.source],
                      let to   = vm.nodePositions[edge.target] else { continue }
                drawEdge(&context, from: from, to: to, referenceType: edge.referenceType)
            }
            // Draw nodes
            for node in vm.displayNodes {
                guard let pos = vm.nodePositions[node.id] else { continue }
                drawNode(&context, node: node, at: pos,
                         isSelected: vm.selectedNodeKey == node.id)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    // MARK: - Hit Areas (accessibility elements + interaction)

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.displayNodes) { node in
            if let pos = vm.nodePositions[node.id] {
                nodeHitArea(node: node, at: pos)
            }
        }
    }

    @ViewBuilder
    private func nodeHitArea(node: DisplayNode, at pos: CGPoint) -> some View {
        let isHint = node.isCluster
            ? String(localized: "graph.node.cluster.hint", defaultValue: "Tap to expand")
            : String(localized: "graph.node.hint", defaultValue: "Tap to see details")
        // Using Button (not Circle+onTapGesture) so the hit area participates in the
        // SwiftUI focus system. Tab-key and Full Keyboard Access users can now navigate
        // between nodes without VoiceOver (F-018).
        Button {
            #if os(macOS)
            vm.navigateToNode(node.id)
            #else
            vm.tapNode(node.id, reduceMotion: reduceMotion)
            #endif
        } label: {
            Circle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(pos)
        #if os(macOS)
        .onHover { hovering in
            vm.selectNode(hovering ? node.id : nil)
        }
        #endif
        .accessibilityLabel(node.accessibilityLabel)
        .accessibilityHint(isHint)
        // Button already carries .isButton implicitly — no addTraits needed.
    }

    // MARK: - Info Panel

    @ViewBuilder
    private var nodeInfoPanel: some View {
        if let key = vm.selectedNodeKey,
           let node = vm.displayNodes.first(where: { $0.id == key }) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text(node.metadata?.header ?? key)
                        .font(.headline)
                        .lineLimit(2)

                    if let dateline = node.metadata?.dateline {
                        Text(dateline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let volId = node.metadata?.volumeId {
                        Text(volId)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // Context passage — shown only when the edge carries footnote text.
                    if let context = vm.contextForSelectedNode() {
                        EdgeContextView(
                            context: context,
                            directionLabel: edgeContextLabel(for: node)
                        )
                    }

                    if !node.isDownloaded && !node.isCentral {
                        Label(
                            String(localized: "graph.node.notDownloaded",
                                   defaultValue: "Volume not downloaded"),
                            systemImage: "icloud.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }

                    if node.isCluster {
                        Button {
                            vm.toggleCluster(key)
                            vm.selectedNodeKey = nil
                        } label: {
                            Text(String(localized: "graph.cluster.expand",
                                        defaultValue: "Expand Cluster"))
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            if let entry = vm.makeEntry(for: key) {
                                vm.navigationPath.append(entry)
                            }
                            vm.selectedNodeKey = nil
                        } label: {
                            Text(String(localized: "graph.node.viewDocument",
                                        defaultValue: "View Document"))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!node.isDownloaded)
                    }
                }
            }
            .frame(maxWidth: 280)
            .fixedSize()
            // Q4: scale part of transition is decorative; suppress it under Reduce Motion
            .transition(reduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
        }
    }

    // MARK: - Edge Context Helpers

    /// Returns the direction label for the context disclosure based on node kind.
    private func edgeContextLabel(for node: DisplayNode) -> String {
        switch node.kind {
        case .inbound:
            return String(localized: "graph.context.referencedIn",
                          defaultValue: "Referenced in")
        case .outbound:
            return String(localized: "graph.context.referencesFrom",
                          defaultValue: "References from")
        default:
            return String(localized: "graph.context.context",
                          defaultValue: "Context")
        }
    }

    // MARK: - Filter Toolbar

    private var filterToolbar: some View {
        Picker(
            String(localized: "graph.filter.label", defaultValue: "Filter"),
            selection: Binding(
                get: { vm.filterMode },
                set: { vm.filterMode = $0 }
            )
        ) {
            ForEach(GraphFilterMode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Undownloaded Banner

    private var undownloadedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
            Text(String(localized: "graph.banner.undownloaded",
                        defaultValue: "Some volumes that may reference this document have not been downloaded."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.08))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                vm.scale = max(0.25, min(4.0, value))
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                vm.panOffset = value.translation
            }
    }

    // MARK: - Canvas Drawing Helpers

    private func drawEdge(
        _ context: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        referenceType: ReferenceType
    ) {
        let cp1 = CGPoint(x: from.x + (to.x - from.x) * 0.5, y: from.y)
        let cp2 = CGPoint(x: to.x   - (to.x - from.x) * 0.5, y: to.y)
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: cp1, control2: cp2)

        let color: Color = referenceType == .editorialNote
            ? .accentColor.opacity(0.4)
            : .secondary.opacity(0.35)
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    private func drawNode(
        _ context: inout GraphicsContext,   // shadows the outer `context` intentionally
        node: DisplayNode,
        at pos: CGPoint,
        isSelected: Bool
    ) {
        let r: CGFloat = node.isCentral ? 24 : 18
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)

        // Background circle
        let fillColor: Color
        switch node.kind {
        case .central:                     fillColor = .accentColor
        case .inbound:                     fillColor = isSelected ? .blue.opacity(0.7) : .blue.opacity(0.3)
        case .outbound:                    fillColor = isSelected ? .green.opacity(0.7) : .green.opacity(0.3)
        case .clusterInbound:              fillColor = isSelected ? .blue.opacity(0.5) : .blue.opacity(0.2)
        case .clusterOutbound:             fillColor = isSelected ? .green.opacity(0.5) : .green.opacity(0.2)
        }
        context.fill(Path(ellipseIn: rect), with: .color(fillColor))

        // Border ring for selected / undownloaded
        if isSelected || !node.isDownloaded {
            let borderColor: Color = !node.isDownloaded ? .orange : .white
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(borderColor),
                lineWidth: 2
            )
        }

        // SF Symbol icon
        let symbolName = node.isCluster ? "folder" : "doc.text"
        let symbolRect = rect.insetBy(dx: r * 0.3, dy: r * 0.3)
        let image = Image(systemName: symbolName)
        context.draw(image, in: symbolRect)
    }
}

// MARK: - EdgeContextView

/// Displays the plain-text passage from the footnote or editorial note that contained
/// a cross-reference `<ref>` element, with a directional label and "Show more" disclosure.
///
/// Shows up to 3 lines by default; the DisclosureGroup reveals the full text.
/// Only rendered when the edge's `context` is non-nil.
///
/// Version history:
///   1.0 — Session 37: initial implementation
private struct EdgeContextView: View {

    let context: String
    let directionLabel: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()

            Text(directionLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isExpanded {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(isExpanded
                     ? String(localized: "graph.context.showLess", defaultValue: "Show less")
                     : String(localized: "graph.context.showMore", defaultValue: "Show more"))
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.top, 2)
    }
}
