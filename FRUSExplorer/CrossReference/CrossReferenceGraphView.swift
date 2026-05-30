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
/// ## Node Labels
/// Each node displays a short text label: the document number (e.g. "42") or the
/// first 20 characters of the document header, rendered below the node circle.
/// Cluster nodes show "N refs".
///
/// ## Edge Labels
/// When there are 10 or fewer visible edges and an edge carries context text,
/// a truncated snippet (up to 40 characters) is drawn at the edge midpoint.
/// The full context is always available in the node info panel.
///
/// ## Degree Expansion
/// A segmented picker in the filter bar lets users toggle between 1st, 2nd, and 3rd
/// degree neighbourhoods. Extended nodes (degree 2+) appear in grey; extended edges
/// are drawn thinner and lighter than degree-1 edges.
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
///   1.4 — Interactive re-centering: breadcrumb history bar; macOS "View Document"
///          sets `appState.pendingBrowseDocument` to open in the main window rather
///          than pushing inline; macOS click re-centres instead of navigating
///   1.5 — Session 129: node labels, edge context-snippet labels, degree picker,
///          extended node colours
///   1.6 — Session 130:
///          • Filter controls removed; toolbar shows degree picker only
///          • 2nd-degree bug fixed (force-directed layout now used when extended nodes present)
///          • Edge context labels replaced by hover/tap disclosure on edge midpoint hit areas
///          • Node hit areas gain `.contextMenu` with Recenter Graph / Open in Main Window
///          • macOS primary click changed from immediate re-centre to node selection;
///            re-centre moved to context menu and info panel
///          • Info button added (popover explaining the graph)
///          • `GraphFilterMode` removed; `filterMode` state dropped
struct CrossReferenceGraphView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var vm: CrossReferenceGraphViewModel
    @State private var showInfoPopover = false

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
                if !vm.history.isEmpty { breadcrumbBar }
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInfoPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .accessibilityLabel(
                                String(localized: "graph.info.a11y",
                                       defaultValue: "About this graph")
                            )
                    }
                    .help(String(
                        localized: "graph.info.help",
                        defaultValue: "Learn what this graph shows and how to interact with it"
                    ))
                    .popover(isPresented: $showInfoPopover, arrowEdge: .top) {
                        graphInfoPopoverContent
                    }
                }
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
                MacDocumentView(entry: entry, navigationPath: .constant([]), highlightCoordinator: HighlightCoordinator())
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task { await vm.loadGraph() }
        .onChange(of: vm.graphDegree) {
            Task { await vm.loadGraph() }
        }
    }

    // MARK: - Graph Content

    @ViewBuilder
    private var graphContentArea: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    graphCanvas
                    edgeHitAreas    // invisible hit areas at each edge midpoint
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

            // Info / edge-context panel floats above the canvas at a fixed location.
            infoPanel
                .padding()
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                    value: vm.selectedNodeKey
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                    value: vm.selectedEdgeKey
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
        let extended = vm.displayNodes.filter {
            if case .extended = $0.kind { return true }
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
            if !extended.isEmpty {
                Text(String(localized: "graph.a11y.section.extended",
                            defaultValue: "Extended References"))
                    .accessibilityAddTraits(.isHeader)
                ForEach(extended) { node in
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
            // Draw edges first (below nodes). Context snippets are no longer drawn inline;
            // they appear in the info panel when the user hovers over or taps an edge midpoint.
            for edge in vm.displayEdges {
                guard let from = vm.nodePositions[edge.source],
                      let to   = vm.nodePositions[edge.target] else { continue }
                let isSelected = vm.selectedEdgeKey == edge.id
                drawEdge(&context, from: from, to: to,
                         referenceType: edge.referenceType,
                         degree: edge.degree,
                         isSelected: isSelected)
            }
            // Draw nodes on top
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

    /// Invisible hit areas positioned at the midpoint of each edge that carries context.
    /// Hover (macOS) or tap (iOS) discloses the context text in the info panel.
    @ViewBuilder
    private var edgeHitAreas: some View {
        ForEach(vm.displayEdges.filter { $0.context != nil }) { edge in
            if let from = vm.nodePositions[edge.source],
               let to   = vm.nodePositions[edge.target] {
                let mid = CGPoint(x: (from.x + to.x) / 2,
                                  y: (from.y + to.y) / 2)
                edgeHitArea(edge: edge, at: mid)
            }
        }
    }

    @ViewBuilder
    private func edgeHitArea(edge: DisplayEdge, at pos: CGPoint) -> some View {
        Button {
            // Tap/click toggles edge context panel; clears any node selection.
            let key = edge.id
            if vm.selectedEdgeKey == key {
                vm.selectedEdgeKey = nil
            } else {
                vm.selectedEdgeKey = key
                vm.selectedNodeKey = nil
            }
        } label: {
            Circle()
                .fill(Color.clear)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(pos)
        #if os(macOS)
        .onHover { hovering in
            vm.selectedEdgeKey = hovering ? edge.id : nil
            if hovering { vm.selectedNodeKey = nil }
        }
        .help(edge.context ?? "")
        #endif
        .accessibilityLabel(String(
            localized: "graph.edge.a11y",
            defaultValue: "Reference context — tap to view"
        ))
    }

    /// Node hit areas — accessibility elements and tap/click interaction targets.
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
            ? String(localized: "graph.node.cluster.hint", defaultValue: "Right-click or long-press for options")
            : String(localized: "graph.node.hint", defaultValue: "Tap to see details; right-click or long-press for actions")
        // Using Button (not Circle+onTapGesture) so the hit area participates in the
        // SwiftUI focus system. Tab-key and Full Keyboard Access users can now navigate
        // between nodes without VoiceOver (F-018).
        Button {
            #if os(macOS)
            // Toggle selection so the info panel stays visible until dismissed.
            // Re-centre action has moved to the context menu and the info panel.
            vm.selectedEdgeKey = nil
            vm.selectedNodeKey = (vm.selectedNodeKey == node.id) ? nil : node.id
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
            // Show info panel transiently on hover; respect a click-pinned selection.
            if hovering {
                vm.selectedEdgeKey = nil
                if vm.selectedNodeKey == nil { vm.selectedNodeKey = node.id }
            } else if vm.selectedNodeKey == node.id {
                vm.selectedNodeKey = nil
            }
        }
        #endif
        .contextMenu {
            nodeContextMenuItems(for: node)
        }
        .accessibilityLabel(node.accessibilityLabel)
        .accessibilityHint(isHint)
    }

    @ViewBuilder
    private func nodeContextMenuItems(for node: DisplayNode) -> some View {
        if node.isCluster {
            Button {
                vm.toggleCluster(node.id)
                vm.selectedNodeKey = nil
            } label: {
                Label(
                    String(localized: "graph.contextMenu.expandCluster",
                           defaultValue: "Expand Cluster"),
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
            }
        } else if !node.isCentral {
            Button {
                vm.navigateToNode(node.id)
            } label: {
                Label(
                    String(localized: "graph.contextMenu.recenter",
                           defaultValue: "Recenter Graph"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }

            Divider()

            Button {
                guard let entry = vm.makeEntry(for: node.id) else { return }
                #if os(macOS)
                appState.pendingBrowseDocument = entry
                #else
                vm.navigationPath.append(entry)
                #endif
                vm.selectedNodeKey = nil
            } label: {
                Label(
                    String(localized: "graph.contextMenu.openDocument",
                           defaultValue: "Open in Main Window"),
                    systemImage: "arrow.up.right.square"
                )
            }
            .disabled(!node.isDownloaded)
        }
    }

    // MARK: - Info Panel

    /// Unified info panel: shows node details when a node is selected, or edge
    /// context when an edge midpoint is hovered / tapped. Edge selection takes
    /// priority over node selection (they are mutually exclusive in practice).
    @ViewBuilder
    private var infoPanel: some View {
        if let edge = vm.selectedEdge(), let context = edge.context {
            edgeInfoPanel(edge: edge, context: context)
        } else if let key = vm.selectedNodeKey,
                  let node = vm.displayNodes.first(where: { $0.id == key }) {
            nodeInfoPanel(node: node, key: key)
        }
    }

    @ViewBuilder
    private func edgeInfoPanel(edge: DisplayEdge, context: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                // Source → Target header
                HStack(spacing: 4) {
                    Text(vm.displayNodes.first(where: { $0.id == edge.source })?.metadata?.header
                         ?? edge.source)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(vm.displayNodes.first(where: { $0.id == edge.target })?.metadata?.header
                         ?? edge.target)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)

                Divider()

                let directionLabel = edge.degree > 1
                    ? String(localized: "graph.context.extendedRef", defaultValue: "Extended reference")
                    : (edge.source == vm.centralKey
                        ? String(localized: "graph.context.referencesFrom", defaultValue: "References from")
                        : String(localized: "graph.context.referencedIn",   defaultValue: "Referenced in"))
                EdgeContextView(context: context, directionLabel: directionLabel)

                Button {
                    vm.selectedEdgeKey = nil
                } label: {
                    Text(String(localized: "graph.edge.dismiss", defaultValue: "Dismiss"))
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .frame(maxWidth: 280)
        .fixedSize()
        .transition(reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
    }

    @ViewBuilder
    private func nodeInfoPanel(node: DisplayNode, key: String) -> some View {
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
                        directionLabel: nodeEdgeContextLabel(for: node)
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
                } else if !node.isCentral {
                    HStack(spacing: 8) {
                        Button {
                            vm.navigateToNode(key)
                        } label: {
                            Text(String(localized: "graph.node.recenter",
                                        defaultValue: "Recenter"))
                        }
                        .buttonStyle(.bordered)

                        Button {
                            if let entry = vm.makeEntry(for: key) {
                                #if os(macOS)
                                appState.pendingBrowseDocument = entry
                                #else
                                vm.navigationPath.append(entry)
                                #endif
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
        }
        .frame(maxWidth: 280)
        .fixedSize()
        .transition(reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
    }

    // MARK: - Node Edge Context Helper

    private func nodeEdgeContextLabel(for node: DisplayNode) -> String {
        switch node.kind {
        case .inbound:
            return String(localized: "graph.context.referencedIn",
                          defaultValue: "Referenced in")
        case .outbound:
            return String(localized: "graph.context.referencesFrom",
                          defaultValue: "References from")
        case .extended:
            return String(localized: "graph.context.extendedRef",
                          defaultValue: "Extended reference")
        default:
            return String(localized: "graph.context.context",
                          defaultValue: "Context")
        }
    }

    // MARK: - Breadcrumb Bar

    /// Horizontal strip shown when the user has navigated away from the original document.
    /// Tapping ← goes back one step; tapping a chip jumps directly to that position.
    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    vm.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go back")

                ForEach(Array(vm.history.enumerated()), id: \.offset) { index, entry in
                    Button {
                        // Pop history back to this entry (inclusive)
                        let stepsBack = vm.history.count - index
                        for _ in 0..<stepsBack { vm.navigateBack() }
                    } label: {
                        Text(entry.header ?? "\(entry.volumeId)/\(entry.documentId)")
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                // Current document (non-interactive)
                if let header = vm.graph?.nodeMetadata[vm.centralKey]?.header {
                    Text(header)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Degree Toolbar

    private var filterToolbar: some View {
        HStack(spacing: 8) {
            Text(String(localized: "graph.degree.label", defaultValue: "Neighbourhood:"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker(
                String(localized: "graph.degree.a11y", defaultValue: "Neighbourhood degree"),
                selection: Binding(
                    get: { vm.graphDegree },
                    set: { vm.graphDegree = $0 }
                )
            ) {
                Text(String(localized: "graph.degree.1", defaultValue: "1°"))
                    .tag(1)
                    .help(String(localized: "graph.degree.1.help",
                                 defaultValue: "Direct inbound and outbound references only"))
                Text(String(localized: "graph.degree.2", defaultValue: "2°"))
                    .tag(2)
                    .help(String(localized: "graph.degree.2.help",
                                 defaultValue: "Add references to and from each direct neighbour"))
                Text(String(localized: "graph.degree.3", defaultValue: "3°"))
                    .tag(3)
                    .help(String(localized: "graph.degree.3.help",
                                 defaultValue: "Extend one further hop from each 2nd-degree node"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 140)
            .help(String(localized: "graph.degree.picker.help",
                         defaultValue: "Choose how many hops of cross-references to display"))

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Info Popover

    private var graphInfoPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "graph.info.heading",
                        defaultValue: "About the Cross-Reference Graph"))
                .font(.headline)

            graphInfoRow(
                title: String(localized: "graph.info.what.title",
                              defaultValue: "What the graph shows"),
                body:  String(localized: "graph.info.what.body",
                              defaultValue: "Each node is a FRUS document. Blue nodes reference the central document (inbound); green nodes are referenced by the central document (outbound). Grey nodes are 2nd- or 3rd-degree neighbours.")
            )
            graphInfoRow(
                title: String(localized: "graph.info.edges.title",
                              defaultValue: "Edge context"),
                body:  String(localized: "graph.info.edges.body",
                              defaultValue: "Many edges carry the original footnote or editorial-note text where the reference appeared. Hover over (or tap) a line between nodes to read that text.")
            )
            graphInfoRow(
                title: String(localized: "graph.info.degree.title",
                              defaultValue: "Neighbourhood degree"),
                body:  String(localized: "graph.info.degree.body",
                              defaultValue: "1° shows only direct neighbours of the central document. 2° adds neighbours of those neighbours. 3° extends one further hop. Resize the window to see denser graphs more clearly.")
            )
            graphInfoRow(
                title: String(localized: "graph.info.interact.title",
                              defaultValue: "Navigating the graph"),
                body:  String(localized: "graph.info.interact.body",
                              defaultValue: "Click a node to see its details. Right-click (or long-press) to recenter the graph on that document or open it in the main window. Use pinch-to-zoom and drag to pan.")
            )
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder
    private func graphInfoRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

    /// Draws a single directed edge as an S-curve Bézier.
    ///
    /// When `isSelected` is `true` (the edge's midpoint hit area is being hovered or
    /// was tapped), the stroke is drawn slightly brighter to provide visual feedback.
    /// Context text is no longer drawn inline; it appears in the info panel instead.
    private func drawEdge(
        _ ctx: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        referenceType: ReferenceType,
        degree: Int,
        isSelected: Bool
    ) {
        let cp1 = CGPoint(x: from.x + (to.x - from.x) * 0.5, y: from.y)
        let cp2 = CGPoint(x: to.x   - (to.x - from.x) * 0.5, y: to.y)
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: cp1, control2: cp2)

        let isExtended = degree > 1
        let lineWidth: CGFloat = isSelected ? 2.5 : (isExtended ? 1.0 : 1.5)
        let color: Color
        if isSelected {
            color = .accentColor.opacity(0.7)
        } else if isExtended {
            color = .secondary.opacity(0.2)
        } else if referenceType == .editorialNote {
            color = .accentColor.opacity(0.4)
        } else {
            color = .secondary.opacity(0.35)
        }
        ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawNode(
        _ ctx: inout GraphicsContext,
        node: DisplayNode,
        at pos: CGPoint,
        isSelected: Bool
    ) {
        let r: CGFloat
        switch node.kind {
        case .central:                     r = 24
        case .inbound, .outbound:          r = 18
        case .extended:                    r = 14
        case .clusterInbound, .clusterOutbound: r = 18
        }
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)

        // Background circle
        let fillColor: Color
        switch node.kind {
        case .central:                     fillColor = .accentColor
        case .inbound:                     fillColor = isSelected ? .blue.opacity(0.7) : .blue.opacity(0.3)
        case .outbound:                    fillColor = isSelected ? .green.opacity(0.7) : .green.opacity(0.3)
        case .extended:                    fillColor = isSelected ? .secondary.opacity(0.5) : .secondary.opacity(0.2)
        case .clusterInbound:              fillColor = isSelected ? .blue.opacity(0.5) : .blue.opacity(0.2)
        case .clusterOutbound:             fillColor = isSelected ? .green.opacity(0.5) : .green.opacity(0.2)
        }
        ctx.fill(Path(ellipseIn: rect), with: .color(fillColor))

        // Border ring for selected / undownloaded
        if isSelected || !node.isDownloaded {
            let borderColor: Color = !node.isDownloaded ? .orange : .white
            ctx.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(borderColor),
                lineWidth: 2
            )
        }

        // SF Symbol icon
        let symbolName = node.isCluster ? "folder" : "doc.text"
        let symbolRect = rect.insetBy(dx: r * 0.3, dy: r * 0.3)
        let image = Image(systemName: symbolName)
        ctx.draw(image, in: symbolRect)

        // Node label — document number or truncated header drawn below the circle.
        let labelText: String
        switch node.kind {
        case .clusterInbound(_, let count):
            labelText = String(
                format: String(localized: "graph.node.cluster.label %lld",
                               defaultValue: "%lld refs"),
                Int64(count)
            )
        case .clusterOutbound(_, let count):
            labelText = String(
                format: String(localized: "graph.node.cluster.label %lld",
                               defaultValue: "%lld refs"),
                Int64(count)
            )
        default:
            if let num = node.metadata?.documentNumber {
                labelText = String(
                    format: String(localized: "graph.node.docNumber %@",
                                   defaultValue: "Doc. %@"),
                    num
                )
            } else if let header = node.metadata?.header {
                let trimmed = header.trimmingCharacters(in: .whitespaces)
                labelText = trimmed.count > 20
                    ? String(trimmed.prefix(18)) + "…"
                    : trimmed
            } else {
                labelText = ""
            }
        }

        if !labelText.isEmpty {
            let isExtendedNode: Bool
            if case .extended = node.kind { isExtendedNode = true } else { isExtendedNode = false }
            let labelStyle: AnyShapeStyle = isExtendedNode
                ? AnyShapeStyle(Color.secondary.opacity(0.6))
                : AnyShapeStyle(Color.primary.opacity(0.75))
            let label = Text(verbatim: labelText)
                .font(.system(size: node.isCentral ? 10 : 8))
                .foregroundStyle(labelStyle)
            ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y + r + 4), anchor: .top)
        }
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
