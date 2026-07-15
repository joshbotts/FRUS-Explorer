// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import TipKit

// MARK: - CompactGraphContent

#if os(iOS)
/// What the compact-width (iPhone) graph sheet shows: the reference list or the
/// canvas. The list is the default — it is the more usable presentation on a
/// small screen — with the canvas one tap away.
private enum CompactGraphContent {
    case graph
    case list
}
#endif

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
///   1.7 — Session 130: "Documents from Same Lot File" context menu item; uses
///          CrossReferenceStore.documentsFromSameLotFile() on the new document_sources table
///   1.6 — Session 130:
///          • Filter controls removed; toolbar shows degree picker only
///          • 2nd-degree bug fixed (force-directed layout now used when extended nodes present)
///          • Edge context labels replaced by hover/tap disclosure on edge midpoint hit areas
///          • Node hit areas gain `.contextMenu` with Recenter Graph / Open in Main Window
///          • macOS primary click changed from immediate re-centre to node selection;
///            re-centre moved to context menu and info panel
///          • Info button added (popover explaining the graph)
///          • `GraphFilterMode` removed; `filterMode` state dropped
///   1.8 — Session 161:
///          • Hover and pinned selection separated (macOS): hovering previews the
///            info panel; clicking pins it so its buttons are reachable by mouse
///          • Pan/zoom gestures accumulate across gestures instead of snapping back
///   1.9 — Session 166: the "Documents from Same Lot File" context-menu item is
///          generalized to "Archival Neighbors", backed by
///          `IndexingPipeline.archivalNeighbors(forVolumeId:documentId:)` (lot file,
///          central decimal file, record-group series, or presidential-library
///          collection) and the shared `ArchivalNeighborsSheet`. The lot-file-only
///          `LotFileDocumentsSheet`/`LotFileSheetID` were removed.
///   2.0 — Session 2026-07-04 (Source Explorer Phase 5 S6): the node context-menu
///          "Archival Neighbors…" opens the value-based window on macOS
///          (`openWindow(value: ArchivalNeighborsRequest.document…)`); the sheet and
///          its target state are now iOS-only
struct CrossReferenceGraphView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    /// Opens the S6 Archival Neighbors window (`WindowGroup(for: ArchivalNeighborsRequest.self)`)
    /// — macOS, and iPad with Stage Manager as of #241.
    @Environment(\.openWindow) private var openWindow
    #if os(iOS)
    /// Gates the neighbors window on iOS: true on Stage-Manager iPads, false on iPhone and
    /// iPads without it, where the sheet remains the presentation (#241).
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    #endif

    @State private var vm: CrossReferenceGraphViewModel
    @State private var showInfoPopover = false
    #if os(iOS)
    /// When set, presents the "Archival Neighbors" discovery sheet for a node's document
    /// (iOS only — macOS opens the S6 Archival Neighbors window instead).
    @State private var archivalNeighborsTarget: ArchivalNeighborsDocKey? = nil
    #endif
    /// Volumes the user queued for download from this graph during the current
    /// presentation; drives the "Download queued" state in the node info panel.
    @State private var requestedDownloadVolumeIds: Set<String> = []
    /// Whether the regular-width layout shows the reference list side panel.
    @State private var showReferenceList = false
    #if os(iOS)
    /// Compact-width content choice. The list is the default on iPhone, where
    /// the canvas is hardest to read and operate; the Graph/List picker in the
    /// filter bar switches between them.
    @State private var compactContentMode: CompactGraphContent = .list
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

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
                    contentArea
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
                    #if os(iOS)
                    if horizontalSizeClass != .compact {
                        referenceListToggleButton
                    }
                    #else
                    referenceListToggleButton
                    #endif
                }
                ToolbarItem(placement: .primaryAction) {
                    resetViewportButton
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInfoPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .controlHelp(
                        String(localized: "graph.info.a11y",
                               defaultValue: "About this graph"),
                        detail: String(localized: "graph.info.help",
                                       defaultValue: "Learn what this graph shows and how to interact with it"),
                        systemImage: "info.circle"
                    )
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
            vm.degreePickerChanged()
            // Deep neighbourhoods read better as a list — surface it alongside.
            if vm.graphDegree >= 3 {
                revealDetailPanelIfNeeded()
            }
        }
        #if os(iOS)
        .sheet(item: $archivalNeighborsTarget) { target in
            ArchivalNeighborsSheet(appState: appState, docKey: target)
                .environment(appState)
        }
        #endif
    }

    // MARK: - Content Area

    /// Chooses between canvas, list, or side-by-side presentation based on
    /// platform width and user toggles. On compact widths (iPhone) the list and
    /// canvas are alternatives; on regular widths the list is a trailing panel.
    @ViewBuilder
    private var contentArea: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            if compactContentMode == .list {
                ReferenceListPanel(vm: vm, openDocument: openDocument)
            } else {
                graphWithLegend
            }
        } else {
            regularContentArea
        }
        #else
        regularContentArea
        #endif
    }

    /// `true` when node/edge details belong in the reference side panel instead
    /// of a floating card over the canvas (Session 162: regular widths fold
    /// details into the panel; compact iPhone keeps the floating card because
    /// there is no side panel real estate).
    private var usesSidePanelForDetails: Bool {
        #if os(iOS)
        return horizontalSizeClass != .compact
        #else
        return true
        #endif
    }

    /// Pins are most useful when their details are visible — called after any
    /// pinning interaction to reveal the side panel on regular widths.
    private func revealDetailPanelIfNeeded() {
        guard usesSidePanelForDetails, !showReferenceList else { return }
        withAnimation { showReferenceList = true }
    }

    /// Canvas with the time brush and legend strip docked beneath it (outside
    /// the canvas, so they can never obscure nodes).
    private var graphWithLegend: some View {
        VStack(spacing: 0) {
            graphContentArea
            if vm.layoutMode == .timeline && vm.timelineEligible {
                TimelineBrushView(vm: vm)
            }
            legendFooter
        }
    }

    /// Canvas with the optional reference-list side panel (regular widths).
    private var regularContentArea: some View {
        HStack(spacing: 0) {
            graphWithLegend
            if showReferenceList {
                Divider()
                ReferenceListPanel(vm: vm, openDocument: openDocument)
                    .frame(width: 320)
            }
        }
    }

    /// Opens a document using the platform's navigation convention and clears
    /// any pinned selection. macOS opens in the main window; iOS pushes inline.
    private func openDocument(_ entry: DocumentBrowserEntry) {
        #if os(macOS)
        appState.pendingBrowseDocument = entry
        #else
        vm.navigationPath.append(entry)
        #endif
        vm.selectedNodeKey = nil
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
                .gesture(resetViewportGesture)
                .onChange(of: geo.size, initial: true) { _, size in
                    vm.onCanvasSizeChanged(size, reduceMotion: reduceMotion)
                }
                #if os(macOS)
                .background {
                    // Scroll-wheel / trackpad-scroll zoom (spec Section 11:
                    // "Pinch or scroll wheel"). Event-monitor based, so it never
                    // intercepts clicks, drags, or hover.
                    ScrollWheelZoomCatcher { factor in
                        vm.zoom(by: factor)
                    }
                    .allowsHitTesting(false)
                }
                #endif
            }

            // Compact widths only: details float over the canvas at the
            // bottom-trailing corner (the least node-dense region). On regular
            // widths details live in the reference side panel instead, which
            // auto-opens on click (Session 162) — nothing floats over the graph.
            if !usesSidePanelForDetails {
                infoPanel
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .bottomTrailing)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                        value: vm.resolvedNodeKey
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                        value: vm.resolvedEdgeKey
                    )
            }
        }
        // Q3: VoiceOver alternative — structured inbound/outbound reference list
        .accessibilityRepresentation { graphAccessibilityList }
        #if os(macOS)
        // Escape clears any pinned node/edge selection (and dismisses the panel).
        .onExitCommand {
            vm.selectedNodeKey = nil
            vm.selectedEdgeKey = nil
        }
        #endif
    }

    // MARK: - Accessibility List Representation (Q3)

    @ViewBuilder
    private var graphAccessibilityList: some View {
        // Reads the *base* nodes so VoiceOver always lists real documents, even
        // while the canvas folds some of them into timeline date clusters.
        let inbound = vm.baseDisplayNodes.filter {
            if case .inbound = $0.kind { return true }
            if case .clusterInbound = $0.kind { return true }
            return false
        }
        let outbound = vm.baseDisplayNodes.filter {
            if case .outbound = $0.kind { return true }
            if case .clusterOutbound = $0.kind { return true }
            return false
        }
        let extended = vm.baseDisplayNodes.filter {
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

    // MARK: - Render Snapshot

    /// Immutable copy of everything the canvas draws, captured during body
    /// evaluation.
    ///
    /// Reads inside a `Canvas` rendering closure are **not** tracked by
    /// Observation — the closure runs at render time, outside body — so a canvas
    /// that reads the view model directly never invalidates when hover or
    /// selection change. That was the "hovering and clicking does nothing" bug
    /// found in live testing (Session 162): every interaction mutated the view
    /// model, but nothing re-rendered until an unrelated change forced it.
    /// Building this snapshot in body registers all the dependencies and hands
    /// the renderer stable value types.
    private struct GraphRenderSnapshot {
        let nodes: [DisplayNode]
        let edges: [DisplayEdge]
        let positions: [String: CGPoint]
        let radii: [String: CGFloat]
        let dateLabels: [String: String]
        let resolvedNodeKey: String?
        let resolvedEdgeKey: String?
        let isTimeline: Bool
        let ticks: [TimelineTick]
        let axisY: CGFloat
        let hasParkedNodes: Bool
        /// Below this node count every node gets its text labels; above it only
        /// the central, focused, and cluster nodes do (dense-graph thinning).
        let showAllLabels: Bool
        /// When the user has a node or edge active: that element's key set plus
        /// every adjacent node. Everything outside the set draws dimmed so the
        /// active neighbourhood pops out of a dense graph. `nil` = no focus.
        let focusKeys: Set<String>?

        /// `true` when `key` should draw at full strength.
        func isFocused(_ key: String) -> Bool {
            focusKeys?.contains(key) ?? true
        }
    }

    /// Captures the render snapshot. Every `vm` read here is intentional: it
    /// registers the Observation dependency that keeps the canvas live.
    private func makeRenderSnapshot() -> GraphRenderSnapshot {
        let resolvedNode = vm.resolvedNodeKey
        let resolvedEdge = vm.resolvedEdgeKey

        var focusKeys: Set<String>? = nil
        if let key = resolvedNode {
            var keys: Set<String> = [key]
            for edge in vm.displayEdges where edge.source == key || edge.target == key {
                keys.insert(edge.source)
                keys.insert(edge.target)
            }
            focusKeys = keys
        } else if let edgeKey = resolvedEdge,
                  let edge = vm.displayEdges.first(where: { $0.id == edgeKey }) {
            focusKeys = [edge.source, edge.target]
        }

        return GraphRenderSnapshot(
            nodes: vm.displayNodes,
            edges: vm.displayEdges,
            positions: vm.nodePositions,
            radii: Dictionary(uniqueKeysWithValues: vm.displayNodes.map {
                ($0.id, vm.nodeRadius(for: $0))
            }),
            dateLabels: vm.nodeDateLabels,
            resolvedNodeKey: resolvedNode,
            resolvedEdgeKey: resolvedEdge,
            isTimeline: vm.layoutMode == .timeline && !vm.timelineTicks.isEmpty,
            ticks: vm.timelineTicks,
            axisY: vm.timelineAxisY,
            hasParkedNodes: vm.timelineHasParkedNodes,
            showAllLabels: vm.displayNodes.count <= 40,
            focusKeys: focusKeys
        )
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        let snapshot = makeRenderSnapshot()
        return Canvas { context, size in
            // Date axis first so nodes and labels draw above it (timeline mode only).
            if snapshot.isTimeline {
                drawTimelineAxis(snapshot, in: &context, size: size)
            }
            // Draw edges first (below nodes). Context snippets are no longer drawn inline;
            // they appear in the info panel when the user hovers over or taps an edge midpoint.
            for edge in snapshot.edges {
                guard let from = snapshot.positions[edge.source],
                      let to   = snapshot.positions[edge.target] else { continue }
                let isFocused = snapshot.isFocused(edge.source) && snapshot.isFocused(edge.target)
                var edgeContext = context
                if !isFocused { edgeContext.opacity = 0.15 }
                drawEdge(&edgeContext, from: from, to: to,
                         referenceType: edge.referenceType,
                         degree: edge.degree,
                         isSelected: snapshot.resolvedEdgeKey == edge.id,
                         referenceCount: edge.referenceCount,
                         targetRadius: snapshot.radii[edge.target] ?? 18)
            }
            // Draw nodes on top
            for node in snapshot.nodes {
                guard let pos = snapshot.positions[node.id] else { continue }
                let isFocused = snapshot.isFocused(node.id)
                var nodeContext = context
                if !isFocused { nodeContext.opacity = 0.3 }
                let showLabels = snapshot.showAllLabels
                    || node.isCentral
                    || node.isCluster
                    || (snapshot.focusKeys?.contains(node.id) ?? false)
                drawNode(&nodeContext, node: node, at: pos,
                         isSelected: snapshot.resolvedNodeKey == node.id,
                         radius: snapshot.radii[node.id] ?? 18,
                         dateLabel: snapshot.dateLabels[node.id],
                         showLabels: showLabels)
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
            // Tap/click toggles edge context panel; clears any node selection and
            // any stale hover (pinned state wins in resolution).
            let key = edge.id
            vm.hoveredEdgeKey = nil
            vm.hoveredNodeKey = nil
            if vm.selectedEdgeKey == key {
                vm.selectedEdgeKey = nil
            } else {
                vm.selectedEdgeKey = key
                vm.selectedNodeKey = nil
                revealDetailPanelIfNeeded()
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
            // Transient hover preview only — pinned selections are untouched, so
            // a panel the user clicked open survives the pointer moving on.
            if hovering {
                vm.hoveredEdgeKey = edge.id
                vm.hoveredNodeKey = nil
            } else if vm.hoveredEdgeKey == edge.id {
                vm.hoveredEdgeKey = nil
            }
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

    /// Accessibility hint matching the node's interaction (expand vs. details).
    private func nodeHitAreaHint(for node: DisplayNode) -> String {
        if node.isDateCluster {
            return String(localized: "graph.node.dateCluster.hint",
                          defaultValue: "Tap to expand this date group")
        }
        if node.isCluster {
            return String(localized: "graph.node.cluster.hint",
                          defaultValue: "Right-click or long-press for options")
        }
        return String(localized: "graph.node.hint",
                      defaultValue: "Tap to see details; right-click or long-press for actions")
    }

    @ViewBuilder
    private func nodeHitArea(node: DisplayNode, at pos: CGPoint) -> some View {
        let isHint = nodeHitAreaHint(for: node)
        // Using Button (not Circle+onTapGesture) so the hit area participates in the
        // SwiftUI focus system. Tab-key and Full Keyboard Access users can now navigate
        // between nodes without VoiceOver (F-018).
        Button {
            #if os(macOS)
            // Toggle selection so the details stay visible until dismissed.
            // Hover state is cleared too: pinned wins in resolution, and a stale
            // hover must never resurface after an explicit click (Session 162).
            vm.selectedEdgeKey = nil
            vm.hoveredEdgeKey = nil
            vm.hoveredNodeKey = nil
            vm.selectedNodeKey = (vm.selectedNodeKey == node.id) ? nil : node.id
            if vm.selectedNodeKey != nil {
                revealDetailPanelIfNeeded()
            }
            #else
            vm.tapNode(node.id, reduceMotion: reduceMotion)
            if vm.selectedNodeKey == node.id {
                revealDetailPanelIfNeeded()
            }
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
        // Double-click re-centres directly (single click pins the info panel;
        // the same action also lives in the context menu and the panel button).
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if !node.isCentral {
                vm.navigateToNode(node.id)
            }
        })
        .onHover { hovering in
            // Transient hover preview. Pinned state (`selectedNodeKey`) is managed
            // exclusively by clicks, so the panel a user pins stays put while the
            // pointer travels to its buttons (the pre-1.5 behaviour cleared the
            // pinned key on un-hover, making those buttons unreachable).
            if hovering {
                vm.hoveredNodeKey = node.id
                vm.hoveredEdgeKey = nil
            } else if vm.hoveredNodeKey == node.id {
                vm.hoveredNodeKey = nil
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
        if node.isDateCluster {
            Button {
                vm.toggleDateCluster(node.id)
                vm.selectedNodeKey = nil
            } label: {
                Label(
                    String(localized: "graph.contextMenu.expandDateCluster",
                           defaultValue: "Expand Date Group"),
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
            }
        } else if node.isCluster {
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

            // Archival provenance: show documents sharing this one's original archival
            // source — lot file, central decimal file, record-group series, or
            // presidential-library collection (the Source Explorer "archival neighbors"
            // protocol, a strict superset of the former lot-file-only discovery). The
            // sheet loads on present; an undownloaded/unindexed node has no stored source
            // note, so the action is disabled there.
            Divider()

            Button {
                guard let meta = vm.graph?.nodeMetadata[node.id] else { return }
                // S6/#241: a window wherever windows exist (macOS; iPad with Stage
                // Manager) — it survives row navigation and sits beside the graph, which
                // is the point. Sheet only where windows are unavailable.
                #if os(iOS)
                guard supportsMultipleWindows else {
                    archivalNeighborsTarget = ArchivalNeighborsDocKey(
                        volumeId:     meta.volumeId,
                        documentId:   meta.documentId,
                        documentYear: meta.dateISO.flatMap { Int($0.prefix(4)) }
                    )
                    return
                }
                #endif
                openWindow(value: ArchivalNeighborsRequest.document(
                    volumeId:     meta.volumeId,
                    documentId:   meta.documentId,
                    documentYear: meta.dateISO.flatMap { Int($0.prefix(4)) }
                ))
            } label: {
                Label(
                    String(localized: "graph.contextMenu.archivalNeighbors",
                           defaultValue: "Archival Neighbors…"),
                    systemImage: "archivebox"
                )
            }
            .disabled(!node.isDownloaded)
            .help(String(localized: "graph.contextMenu.archivalNeighbors.help",
                         defaultValue: "Find other FRUS documents drawn from the same archival source — lot file, central file, collection, or library"))
        }
    }

    // MARK: - Legend

    /// One-line legend strip rendered *below* the canvas (never over it —
    /// the floating overlay version obscured nodes; Session 162 live-testing
    /// feedback). Decodes node colour, the arrow convention, and node size.
    private var legendFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                legendItem(color: .blue, text: String(
                    localized: "graph.legend.inbound",
                    defaultValue: "Cites this document"))
                legendItem(color: .orange, text: String(
                    localized: "graph.legend.outbound",
                    defaultValue: "Cited by this document"))
                legendItem(color: .secondary.opacity(0.5), text: String(
                    localized: "graph.legend.extended",
                    defaultValue: "Further hops"))
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text(String(localized: "graph.legend.arrow.short",
                                defaultValue: "Points to the cited document"))
                }
                Text(String(localized: "graph.legend.size",
                            defaultValue: "Size = connection count"))
            }
            // Narrow fallback (iPhone graph mode): colours + arrow only.
            HStack(spacing: 12) {
                legendItem(color: .blue, text: String(
                    localized: "graph.legend.inbound.short",
                    defaultValue: "Cites"))
                legendItem(color: .orange, text: String(
                    localized: "graph.legend.outbound.short",
                    defaultValue: "Cited by"))
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                    Text(String(localized: "graph.legend.arrow.shorter",
                                defaultValue: "To the cited document"))
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "graph.legend.a11y",
                                   defaultValue: "Graph legend"))
    }

    /// One colour-swatch item of the legend strip.
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.45))
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: - Info Panel

    /// Unified info panel: shows node details when a node is active, or edge
    /// context when an edge midpoint is hovered / pinned. The view model's
    /// `resolvedEdgeKey`/`resolvedNodeKey` guarantee the two are mutually
    /// exclusive (hover wins over pinned state).
    @ViewBuilder
    private var infoPanel: some View {
        if let edge = vm.selectedEdge(), let context = edge.combinedContext {
            edgeInfoPanel(edge: edge, context: context)
        } else if let key = vm.resolvedNodeKey,
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

                if edge.referenceCount > 1 {
                    Text(String(
                        format: String(localized: "graph.edge.refCount %lld",
                                       defaultValue: "%lld separate references"),
                        Int64(edge.referenceCount)
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Divider()

                let directionLabel = edge.degree > 1
                    ? String(localized: "graph.context.extendedRef", defaultValue: "Extended reference")
                    : (edge.source == vm.centralKey
                        ? String(localized: "graph.context.referencesFrom", defaultValue: "References from")
                        : String(localized: "graph.context.referencedIn",   defaultValue: "Referenced in"))
                EdgeContextView(context: context, directionLabel: directionLabel)

                Button {
                    vm.selectedEdgeKey = nil
                    vm.hoveredEdgeKey = nil
                    vm.hoveredNodeKey = nil
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
            : .opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
    }

    @ViewBuilder
    private func nodeInfoPanel(node: DisplayNode, key: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.metadata?.header
                     ?? ((node.isCluster || node.isDateCluster) ? node.accessibilityLabel : key))
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

                // On-device summary, when the user has generated one — lets each
                // node visit answer "is this document worth opening?" in place.
                if let summary = node.metadata?.summary,
                   !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                // Context passage — shown only when the edge carries footnote text.
                if let context = vm.contextForSelectedNode() {
                    EdgeContextView(
                        context: context,
                        directionLabel: nodeEdgeContextLabel(for: node)
                    )
                }

                if !node.isDownloaded && !node.isCentral && !node.isDateCluster {
                    undownloadedSection(for: node)
                }

                if node.isDateCluster {
                    Button {
                        vm.toggleDateCluster(key)
                        vm.selectedNodeKey = nil
                    } label: {
                        Text(String(localized: "graph.dateCluster.expand",
                                    defaultValue: "Expand Date Group"))
                    }
                    .buttonStyle(.bordered)
                } else if node.isCluster {
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
        .overlay(alignment: .topTrailing) { panelCloseButton }
        .transition(reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
    }

    /// Small dismiss control in the node info panel's corner — clears the pinned
    /// selection (and any hover) so the panel can always be put away explicitly.
    private var panelCloseButton: some View {
        Button {
            vm.selectedNodeKey = nil
            vm.selectedEdgeKey = nil
            vm.hoveredNodeKey = nil
            vm.hoveredEdgeKey = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "graph.panel.close.a11y",
                                   defaultValue: "Close details panel"))
        .padding(6)
        .controlHelp(
            String(localized: "graph.panel.close.a11y", defaultValue: "Close details"),
            detail: String(localized: "graph.panel.close.help",
                           defaultValue: "Hide this document's details panel"),
            systemImage: "xmark.circle.fill"
        )
    }

    // MARK: - Undownloaded Volume Section

    /// Info-panel block for nodes whose volume is not downloaded: a status label plus
    /// a "Download Volume" action (spec Section 11: navigating to a node in an
    /// undownloaded volume initiates download). Once tapped, shows a queued state —
    /// the graph itself refreshes only after the volume downloads and is indexed.
    @ViewBuilder
    private func undownloadedSection(for node: DisplayNode) -> some View {
        Label(
            String(localized: "graph.node.notDownloaded",
                   defaultValue: "Volume not downloaded"),
            systemImage: "icloud.slash"
        )
        .font(.caption)
        .foregroundStyle(.orange)

        if let volumeId = node.volumeId {
            if requestedDownloadVolumeIds.contains(volumeId) {
                Label(
                    String(localized: "graph.node.downloadQueued",
                           defaultValue: "Download queued"),
                    systemImage: "arrow.down.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(String(localized: "graph.node.downloadQueued.detail",
                            defaultValue: "This document becomes available here after the volume downloads and is indexed."))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let entry = manifestEntry(for: volumeId),
                      let downloadManager = appState.downloadManager {
                Button {
                    requestedDownloadVolumeIds.insert(volumeId)
                    Task {
                        await downloadManager.enqueueDownload(
                            volumeId: volumeId,
                            downloadUrl: entry.downloadUrl
                        )
                    }
                } label: {
                    Label(
                        String(localized: "graph.node.downloadVolume",
                               defaultValue: "Download Volume"),
                        systemImage: "arrow.down.circle"
                    )
                }
                .buttonStyle(.bordered)
                .help(String(localized: "graph.node.downloadVolume.help",
                             defaultValue: "Download and index this volume so its documents can be opened from the graph"))
            }
        }
    }

    /// Manifest entry for `volumeId`, if the manifest knows it.
    private func manifestEntry(for volumeId: String) -> VolumeManifestEntry? {
        let entries = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return entries.first { $0.volumeId == volumeId }
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
                        .accessibilityLabel(String(localized: "graph.navigateBack.a11y",
                                                   defaultValue: "Back to previous focus"))
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .controlHelp(
                    String(localized: "graph.breadcrumb.back", defaultValue: "Go back"),
                    detail: String(localized: "graph.breadcrumb.back.help",
                                   defaultValue: "Return to the previous document in the graph's history"),
                    systemImage: "chevron.left"
                )

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
            Picker(
                String(localized: "graph.layout.a11y", defaultValue: "Graph layout"),
                selection: Binding(
                    get: { vm.layoutMode },
                    set: {
                        TimelineLayoutTip().invalidate(reason: .actionPerformed)
                        vm.setLayoutMode($0, reduceMotion: reduceMotion)
                    }
                )
            ) {
                Text(String(localized: "graph.layout.timeline", defaultValue: "Timeline"))
                    .tag(GraphLayoutMode.timeline)
                Text(String(localized: "graph.layout.network", defaultValue: "Network"))
                    .tag(GraphLayoutMode.network)
            }
            .popoverTip(TimelineLayoutTip())
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 170)
            .disabled(!vm.timelineEligible)
            .help(String(localized: "graph.layout.help",
                         defaultValue: "Timeline arranges documents chronologically along a date axis; Network uses the spring layout. Timeline is unavailable when too few documents have dates."))

            Divider()
                .frame(height: 16)

            Text(String(localized: "graph.degree.depthLabel", defaultValue: "Depth:"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker(
                String(localized: "graph.degree.a11y", defaultValue: "Reference depth"),
                selection: Binding(
                    get: { vm.graphDegree },
                    set: { vm.graphDegree = $0 }
                )
            ) {
                Text(String(localized: "graph.degree.oneHop", defaultValue: "1 hop"))
                    .tag(1)
                    .help(String(localized: "graph.degree.1.help",
                                 defaultValue: "Direct inbound and outbound references only"))
                Text(String(localized: "graph.degree.twoHops", defaultValue: "2 hops"))
                    .tag(2)
                    .help(String(localized: "graph.degree.2.help",
                                 defaultValue: "Add references to and from each direct neighbour"))
                Text(String(localized: "graph.degree.threeHops", defaultValue: "3 hops"))
                    .tag(3)
                    .help(String(localized: "graph.degree.3.help",
                                 defaultValue: "Extend one further hop from each 2nd-degree node"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 190)
            .help(String(localized: "graph.degree.picker.help",
                         defaultValue: "Choose how many hops of cross-references to display"))

            if vm.autoExpandedSparseGraph {
                Text(String(localized: "graph.autoExpanded.note",
                            defaultValue: "Few direct references — showing 2 hops"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            #if os(iOS)
            if horizontalSizeClass == .compact {
                Picker(
                    String(localized: "graph.content.a11y", defaultValue: "Content style"),
                    selection: $compactContentMode
                ) {
                    Image(systemName: "list.bullet")
                        .tag(CompactGraphContent.list)
                        .accessibilityLabel(String(localized: "graph.content.list",
                                                   defaultValue: "List"))
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .tag(CompactGraphContent.graph)
                        .accessibilityLabel(String(localized: "graph.content.graph",
                                                   defaultValue: "Graph"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 100)
            }
            #endif
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// Toolbar button toggling the reference-list side panel (regular widths).
    private var referenceListToggleButton: some View {
        Button {
            GraphReferenceListTip().invalidate(reason: .actionPerformed)
            withAnimation { showReferenceList.toggle() }
        } label: {
            Image(systemName: "sidebar.trailing")
        }
        .popoverTip(GraphReferenceListTip())
        .controlHelp(
            String(localized: "graph.list.toggle.a11y",
                   defaultValue: "Toggle reference list"),
            detail: String(localized: "graph.list.toggle.help",
                           defaultValue: "Show or hide the reference list panel"),
            systemImage: "sidebar.trailing"
        )
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
                              defaultValue: "Each node is a FRUS document. Blue nodes cite the central document; orange nodes are cited by it. Grey nodes are 2nd- or 3rd-degree neighbours. Larger nodes have more connections across the corpus, and each arrow points at the document being cited.")
            )
            graphInfoRow(
                title: String(localized: "graph.info.edges.title",
                              defaultValue: "Edge context"),
                body:  String(localized: "graph.info.edges.body",
                              defaultValue: "Many edges carry the original footnote or editorial-note text where the reference appeared — hover over (or tap) the middle of a line to read it. Thicker lines mean the pair is linked by several separate references.")
            )
            graphInfoRow(
                title: String(localized: "graph.info.timeline.title",
                              defaultValue: "Timeline and Network layouts"),
                body:  String(localized: "graph.info.timeline.body",
                              defaultValue: "Timeline places each document at its date along a time axis — documents this one cites usually sit to the left (earlier), documents citing it to the right (later). Documents without a recorded date park in the Undated column. Network uses a spring layout based purely on connections.")
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
            graphInfoRow(
                title: String(localized: "graph.info.undownloaded.title",
                              defaultValue: "Undownloaded volumes"),
                body:  String(localized: "graph.info.undownloaded.body",
                              defaultValue: "References pointing to documents in volumes you haven't downloaded are still shown — the connection was recorded when the source volume was indexed. Those nodes appear with a dashed border and a struck-through cloud icon; select one to download its volume directly from the info panel.\n\nReferences from volumes you haven't indexed yet are not shown at all, because those volumes have never been parsed. An orange banner at the top of the graph appears when your inbound connections may be incomplete for this reason. Download and index additional volumes to fill in the missing edges.")
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
                vm.magnificationChanged(value)
            }
            .onEnded { _ in
                vm.magnificationEnded()
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                vm.panChanged(value.translation)
            }
            .onEnded { _ in
                vm.panEnded()
            }
    }

    /// Double-tap anywhere on the canvas to restore the pan/zoom viewport to its
    /// neutral state.
    ///
    /// `magnificationGesture`/`panGesture` have no bounds-clamping or rubber-banding
    /// — an inadvertent pinch or drag can leave the (always-centred) central node
    /// arbitrarily far off-screen with no way back. This mirrors the familiar
    /// double-tap-to-reset-zoom convention from Maps/Photos and is the gesture-level
    /// counterpart to the toolbar "Reset View" button (`resetViewportButton`), which
    /// remains available for users who prefer (or need, for accessibility reasons) a
    /// discoverable on-screen control instead of a gesture.
    private var resetViewportGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                vm.resetViewport(animated: !reduceMotion)
            }
    }

    /// Toolbar button that restores the pan/zoom viewport to its neutral state.
    ///
    /// This is the discoverable, on-screen counterpart to `resetViewportGesture`
    /// (double-tap) — important for users who don't know the gesture exists, who
    /// can't perform it reliably (e.g. motor-control accessibility needs), or who
    /// simply prefer an explicit control. Both paths call the same
    /// `vm.resetViewport(animated:)`, which itself no-ops when the viewport is
    /// already neutral, so tapping this when nothing has drifted is harmless.
    private var resetViewportButton: some View {
        Button {
            vm.resetViewport(animated: !reduceMotion)
        } label: {
            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
        }
        .controlHelp(
            String(localized: "graph.resetView.a11y", defaultValue: "Reset view"),
            detail: String(localized: "graph.resetView.help",
                           defaultValue: "Restore the graph's pan and zoom to their original position"),
            systemImage: "arrow.up.left.and.down.right.magnifyingglass"
        )
    }

    // MARK: - Canvas Drawing Helpers

    /// Draws the timeline layout's date axis: a horizontal baseline near the
    /// bottom edge, adaptive tick marks with labels, and — when undated nodes are
    /// parked at the trailing edge — a caption above that column. Reads only the
    /// snapshot (never the view model) so Observation tracking stays in body.
    private func drawTimelineAxis(
        _ snapshot: GraphRenderSnapshot,
        in ctx: inout GraphicsContext,
        size: CGSize
    ) {
        let axisY = snapshot.axisY
        var axis = Path()
        axis.move(to: CGPoint(x: 40, y: axisY))
        axis.addLine(to: CGPoint(x: size.width - 64, y: axisY))
        ctx.stroke(axis, with: .color(.secondary.opacity(0.35)), lineWidth: 0.75)

        for tick in snapshot.ticks {
            var mark = Path()
            mark.move(to: CGPoint(x: tick.x, y: axisY - 4))
            mark.addLine(to: CGPoint(x: tick.x, y: axisY + 4))
            ctx.stroke(mark, with: .color(.secondary.opacity(0.5)), lineWidth: 0.75)
            let label = Text(verbatim: tick.label)
                .font(.system(size: 9))
                .foregroundStyle(Color.secondary)
            ctx.draw(label, at: CGPoint(x: tick.x, y: axisY + 7), anchor: .top)
        }

        if snapshot.hasParkedNodes {
            let caption = Text(String(localized: "graph.timeline.undated",
                                      defaultValue: "Undated"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.secondary)
            ctx.draw(caption, at: CGPoint(x: size.width - 44, y: 46), anchor: .center)
        }
    }

    /// Point on a cubic Bézier at parameter `t`.
    private func cubicPoint(
        _ t: CGFloat, _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint
    ) -> CGPoint {
        let mt = 1 - t
        let a = mt * mt * mt, b = 3 * mt * mt * t, c = 3 * mt * t * t, d = t * t * t
        return CGPoint(
            x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
        )
    }

    /// Draws a single directed edge as an S-curve Bézier with an arrowhead at the
    /// target node's rim.
    ///
    /// - Thickness encodes `referenceCount` — an edge aggregating three footnote
    ///   references draws heavier than a single reference.
    /// - The arrowhead always points at the *cited* document, making direction
    ///   readable without relying on node colour alone.
    /// - When `isSelected` is `true` (the edge's midpoint hit area is hovered or
    ///   pinned), the stroke is drawn brighter for feedback.
    private func drawEdge(
        _ ctx: inout GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        referenceType: ReferenceType,
        degree: Int,
        isSelected: Bool,
        referenceCount: Int,
        targetRadius: CGFloat
    ) {
        let cp1 = CGPoint(x: from.x + (to.x - from.x) * 0.5, y: from.y)
        let cp2 = CGPoint(x: to.x   - (to.x - from.x) * 0.5, y: to.y)
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: cp1, control2: cp2)

        let isExtended = degree > 1
        let baseWidth: CGFloat = isSelected ? 2.5 : (isExtended ? 1.0 : 1.5)
        let lineWidth = baseWidth + min(CGFloat(referenceCount - 1) * 0.5, 2.0)
        let color: Color
        if isSelected {
            color = .accentColor.opacity(0.7)
        } else if isExtended {
            color = .secondary.opacity(0.25)
        } else if referenceType == .editorialNote {
            color = .accentColor.opacity(0.4)
        } else {
            color = .secondary.opacity(0.4)
        }
        ctx.stroke(path, with: .color(color), lineWidth: lineWidth)

        // Arrowhead: walk back along the curve from the target until just outside
        // its rim, then draw a chevron oriented along the local tangent.
        guard hypot(to.x - from.x, to.y - from.y) > targetRadius * 2 else { return }
        var tHit: CGFloat = 1.0
        while tHit > 0.5 {
            let p = cubicPoint(tHit, from, cp1, cp2, to)
            if hypot(p.x - to.x, p.y - to.y) >= targetRadius + 2 { break }
            tHit -= 0.02
        }
        let tip  = cubicPoint(tHit, from, cp1, cp2, to)
        let back = cubicPoint(max(tHit - 0.05, 0), from, cp1, cp2, to)
        let angle = atan2(tip.y - back.y, tip.x - back.x)
        let arm: CGFloat = 5 + lineWidth
        var head = Path()
        head.move(to: CGPoint(x: tip.x - arm * cos(angle - 0.5),
                              y: tip.y - arm * sin(angle - 0.5)))
        head.addLine(to: tip)
        head.addLine(to: CGPoint(x: tip.x - arm * cos(angle + 0.5),
                                 y: tip.y - arm * sin(angle + 0.5)))
        ctx.stroke(head, with: .color(color), lineWidth: max(lineWidth, 1.5))
    }

    private func drawNode(
        _ ctx: inout GraphicsContext,
        node: DisplayNode,
        at pos: CGPoint,
        isSelected: Bool,
        radius: CGFloat,
        dateLabel: String?,
        showLabels: Bool
    ) {
        let r = radius
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)

        // Background circle. Outbound nodes are orange (not green) so the
        // inbound/outbound distinction survives red-green colour blindness;
        // edge arrowheads carry direction redundantly.
        let fillColor: Color
        switch node.kind {
        case .central:                     fillColor = .accentColor
        case .inbound:                     fillColor = isSelected ? .blue.opacity(0.7) : .blue.opacity(0.3)
        case .outbound:                    fillColor = isSelected ? .orange.opacity(0.7) : .orange.opacity(0.3)
        case .extended:                    fillColor = isSelected ? .secondary.opacity(0.5) : .secondary.opacity(0.2)
        case .clusterInbound:              fillColor = isSelected ? .blue.opacity(0.5) : .blue.opacity(0.2)
        case .clusterOutbound:             fillColor = isSelected ? .orange.opacity(0.5) : .orange.opacity(0.2)
        case .dateCluster:                 fillColor = isSelected ? .purple.opacity(0.5) : .purple.opacity(0.25)
        }
        ctx.fill(Path(ellipseIn: rect), with: .color(fillColor))

        // Border ring: solid white when selected; dashed grey when the node's
        // volume is not downloaded (dashed = "outline only", reinforced by the
        // icloud.slash icon below — colour is not the only carrier).
        if isSelected {
            ctx.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(.white),
                lineWidth: 2
            )
        } else if !node.isDownloaded {
            ctx.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                with: .color(.secondary.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5])
            )
        }

        // SF Symbol icon
        let symbolName: String
        if node.isDateCluster {
            symbolName = "calendar"
        } else if node.isCluster {
            symbolName = "folder"
        } else if !node.isDownloaded {
            symbolName = "icloud.slash"
        } else {
            symbolName = "doc.text"
        }
        let symbolRect = rect.insetBy(dx: r * 0.3, dy: r * 0.3)
        let image = Image(systemName: symbolName)
        ctx.draw(image, in: symbolRect)

        // Node label — document number or truncated header drawn below the circle,
        // with the document date (when known) on a second line. Suppressed on
        // dense graphs except for central/cluster/focused nodes (`showLabels`).
        guard showLabels else { return }
        let labelText: String
        switch node.kind {
        case .clusterInbound(_, let count):
            labelText = String(
                format: String(localized: "graph.node.cluster.docsLabel %lld",
                               defaultValue: "%lld docs"),
                Int64(count)
            )
        case .clusterOutbound(_, let count):
            labelText = String(
                format: String(localized: "graph.node.cluster.docsLabel %lld",
                               defaultValue: "%lld docs"),
                Int64(count)
            )
        case .dateCluster(let periodLabel, let count, _):
            labelText = String(
                format: String(localized: "graph.node.dateCluster.label %lld %@",
                               defaultValue: "%lld docs · %@"),
                Int64(count), periodLabel
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

        let isExtendedNode: Bool
        if case .extended = node.kind { isExtendedNode = true } else { isExtendedNode = false }
        let primaryStyle: AnyShapeStyle = isExtendedNode
            ? AnyShapeStyle(Color.secondary.opacity(0.6))
            : AnyShapeStyle(Color.primary.opacity(0.75))
        let fontSize: CGFloat = node.isCentral ? 10 : 8
        var labelY = pos.y + r + 4

        if !labelText.isEmpty {
            let label = Text(verbatim: labelText)
                .font(.system(size: fontSize))
                .foregroundStyle(primaryStyle)
            ctx.draw(label, at: CGPoint(x: pos.x, y: labelY), anchor: .top)
            labelY += fontSize + 3
        }

        if let dateText = dateLabel {
            let dateLabelText = Text(verbatim: dateText)
                .font(.system(size: fontSize - 1))
                .foregroundStyle(Color.secondary.opacity(isExtendedNode ? 0.6 : 0.9))
            ctx.draw(dateLabelText, at: CGPoint(x: pos.x, y: labelY), anchor: .top)
        }
    }
}

// MARK: - TimelineBrushView

/// Interactive time-range brush docked beneath the timeline canvas
/// (Session 162, dense-graph deconfliction recommendation 2).
///
/// The strip shows the graph's full date extent with a faint density mark per
/// dated document. Dragging across empty space selects a window; dragging
/// inside the window moves it; dragging its edges resizes it. While a window
/// is active the timeline axis zooms to it, dated nodes outside disappear,
/// and date clusters recompute on the zoomed scale — zooming in naturally
/// dissolves them. The clear button (and a brush narrower than 2% of the
/// range) resets to the full extent.
struct TimelineBrushView: View {

    @Bindable var vm: CrossReferenceGraphViewModel

    /// Drag interpretation, chosen from the gesture's start location.
    private enum DragMode {
        case create(anchor: TimeInterval)
        case move(offset: TimeInterval)
        case resizeLower
        case resizeUpper
    }
    @State private var dragMode: DragMode? = nil

    var body: some View {
        if let fullRange = vm.timelineFullDateRange {
            HStack(spacing: 8) {
                Text(Self.endpointLabel(fullRange.lowerBound))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                brushTrack(fullRange: fullRange)
                    .frame(height: 22)
                Text(Self.endpointLabel(fullRange.upperBound))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if vm.timelineBrushRange != nil {
                    Button {
                        vm.setTimelineBrush(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .controlHelp(
                        String(localized: "graph.brush.clear.a11y",
                               defaultValue: "Clear time range"),
                        detail: String(localized: "graph.brush.clear.help",
                                       defaultValue: "Show the full date range again"),
                        systemImage: "xmark.circle.fill"
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    /// The draggable track: density marks, the selection window, edge handles.
    private func brushTrack(fullRange: ClosedRange<TimeInterval>) -> some View {
        // Captured in body so the Canvas closure never reads the view model.
        let dates = Array(vm.nodeDateValues.values)
        let brush = vm.timelineBrushRange
        let fullSpan = fullRange.upperBound - fullRange.lowerBound

        return GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.1))

                // Density marks — one faint tick per dated document.
                Canvas { ctx, size in
                    for t in dates {
                        let x = CGFloat((t - fullRange.lowerBound) / fullSpan) * size.width
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: 4))
                        line.addLine(to: CGPoint(x: x, y: size.height - 4))
                        ctx.stroke(line, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                    }
                }

                if let brush {
                    let lowerX = CGFloat((brush.lowerBound - fullRange.lowerBound) / fullSpan) * width
                    let upperX = CGFloat((brush.upperBound - fullRange.lowerBound) / fullSpan) * width
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
                        )
                        .frame(width: max(upperX - lowerX, 4))
                        .offset(x: lowerX)
                }
            }
            .contentShape(Rectangle())
            .gesture(brushGesture(fullRange: fullRange, width: width))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "graph.brush.a11y",
                                   defaultValue: "Timeline range filter"))
        .accessibilityHint(String(localized: "graph.brush.a11y.hint",
                                  defaultValue: "Drag to zoom the timeline to a date range; use the clear button to reset"))
    }

    /// Create / move / resize gesture over the track.
    private func brushGesture(
        fullRange: ClosedRange<TimeInterval>,
        width: CGFloat
    ) -> some Gesture {
        let fullSpan = fullRange.upperBound - fullRange.lowerBound
        let minSpan = fullSpan * 0.02

        func time(atX x: CGFloat) -> TimeInterval {
            fullRange.lowerBound + Double(min(max(x / width, 0), 1)) * fullSpan
        }
        func xPosition(_ t: TimeInterval) -> CGFloat {
            CGFloat((t - fullRange.lowerBound) / fullSpan) * width
        }

        return DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragMode == nil {
                    let startX = value.startLocation.x
                    if let brush = vm.timelineBrushRange {
                        let lowerX = xPosition(brush.lowerBound)
                        let upperX = xPosition(brush.upperBound)
                        if abs(startX - lowerX) < 10 {
                            dragMode = .resizeLower
                        } else if abs(startX - upperX) < 10 {
                            dragMode = .resizeUpper
                        } else if startX > lowerX && startX < upperX {
                            dragMode = .move(offset: time(atX: startX) - brush.lowerBound)
                        } else {
                            dragMode = .create(anchor: time(atX: startX))
                        }
                    } else {
                        dragMode = .create(anchor: time(atX: startX))
                    }
                }
                let current = time(atX: value.location.x)
                switch dragMode {
                case .create(let anchor):
                    let lower = min(anchor, current)
                    let upper = max(anchor, current)
                    if upper - lower >= minSpan {
                        vm.setTimelineBrush(lower...upper)
                    }
                case .move(let offset):
                    guard let brush = vm.timelineBrushRange else { return }
                    let span = brush.upperBound - brush.lowerBound
                    var lower = current - offset
                    lower = min(max(lower, fullRange.lowerBound),
                                fullRange.upperBound - span)
                    vm.setTimelineBrush(lower...(lower + span))
                case .resizeLower:
                    guard let brush = vm.timelineBrushRange else { return }
                    let lower = max(min(current, brush.upperBound - minSpan),
                                    fullRange.lowerBound)
                    vm.setTimelineBrush(lower...brush.upperBound)
                case .resizeUpper:
                    guard let brush = vm.timelineBrushRange else { return }
                    let upper = min(max(current, brush.lowerBound + minSpan),
                                    fullRange.upperBound)
                    vm.setTimelineBrush(brush.lowerBound...upper)
                case nil:
                    break
                }
            }
            .onEnded { _ in dragMode = nil }
    }

    /// Short month-year label for the strip's endpoints.
    private static func endpointLabel(_ t: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("MMM y")
        return formatter.string(from: Date(timeIntervalSinceReferenceDate: t))
    }
}

#if os(macOS)

// MARK: - ScrollWheelZoomCatcher

/// Invisible AppKit view that converts scroll-wheel (and trackpad scroll)
/// deltas over the graph canvas into multiplicative zoom commands — the
/// "scroll wheel" half of spec Section 11's "Pinch or scroll wheel" zoom row.
///
/// Implemented with a local `NSEvent` monitor instead of overriding
/// `scrollWheel(with:)` so the view never has to win hit-testing: clicks,
/// drags, and hover continue to reach the SwiftUI layer beneath. Scroll events
/// outside this view's bounds (or in other windows) pass through untouched.
private struct ScrollWheelZoomCatcher: NSViewRepresentable {

    /// Receives a multiplicative zoom factor (> 1 zooms in).
    let onZoom: (CGFloat) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onZoom = onZoom
    }

    /// NSView that owns the event monitor for its window's lifetime.
    final class TrackingView: NSView {
        /// Forwarded zoom callback; set by the representable.
        var onZoom: ((CGFloat) -> Void)?
        /// Local scroll-wheel monitor token; installed while in a window.
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                removeMonitorIfNeeded()
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    // The monitor runs on the main thread; assumeIsolated lets us
                    // touch MainActor-isolated NSView state. NSEvent itself is not
                    // Sendable, so only a Bool decision crosses the boundary.
                    let consumed = MainActor.assumeIsolated { () -> Bool in
                        guard let self,
                              let window = self.window,
                              event.window === window else { return false }
                        let location = self.convert(event.locationInWindow, from: nil)
                        guard self.bounds.contains(location),
                              event.scrollingDeltaY != 0 else { return false }
                        self.onZoom?(1 + event.scrollingDeltaY * 0.0035)
                        return true
                    }
                    return consumed ? nil : event
                }
            }
        }

        /// Never participates in hit testing; interaction stays with SwiftUI.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        /// Removes the event monitor; safe to call repeatedly.
        private func removeMonitorIfNeeded() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

#endif // os(macOS)

// MARK: - EdgeContextView

/// Displays the plain-text passage from the footnote or editorial note that contained
/// a cross-reference `<ref>` element, with a directional label and "Show more" disclosure.
///
/// Shows up to 3 lines by default; the DisclosureGroup reveals the full text.
/// Only rendered when the edge's `context` is non-nil.
///
/// Version history:
///   1.0 — Session 37: initial implementation
///   1.1 — Session 162: made internal so the reference side panel's detail
///          section (ReferenceListPanel) can reuse it
struct EdgeContextView: View {

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


