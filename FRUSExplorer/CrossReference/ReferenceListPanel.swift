// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ReferenceListPanel

/// Scrollable, selectable list of every reference in the current cross-reference
/// graph — the "scent" complement to the canvas. Rows show what the canvas can
/// only hint at: full headers, dates, volume IDs, and the footnote passage that
/// carried the reference.
///
/// ## Synchronization
/// Tapping a row pins the node (`selectedNodeKey`), highlighting it on the
/// canvas; pinning a node on the canvas scrolls the list to its row. Cluster
/// rows expand/collapse their volume group, mirroring cluster taps on the canvas.
///
/// ## Platforms
/// - macOS / iPad (regular width): trailing side panel toggled from the toolbar.
/// - iPhone (compact width): full-content alternative to the canvas via the
///   Graph/List picker in the filter bar; the list is the default there.
///
/// Version history:
///   1.0 — Session 161: initial implementation
struct ReferenceListPanel: View {

    @Bindable var vm: CrossReferenceGraphViewModel
    /// Invoked when the user opens a document from a row or its context menu.
    let openDocument: (DocumentBrowserEntry) -> Void

    @Environment(AppState.self) private var appState
    /// Volumes the user queued for download from the detail section during this
    /// presentation; drives its "Download queued" state.
    @State private var requestedDownloadVolumeIds: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            detailSection
            Divider()
            referenceList
        }
    }

    // MARK: - Detail Section (Session 162)

    /// Details for the active node or edge, docked at the top of the panel.
    /// This replaced the floating canvas info card on regular widths — details
    /// now live where they can never obscure the graph, and clicking a node
    /// auto-opens this panel.
    @ViewBuilder
    private var detailSection: some View {
        Group {
            if let edge = vm.selectedEdge(), let context = edge.combinedContext {
                GraphEdgeDetailView(vm: vm, edge: edge, context: context)
            } else if let key = vm.resolvedNodeKey,
                      let node = vm.displayNodes.first(where: { $0.id == key })
                        ?? vm.baseDisplayNodes.first(where: { $0.id == key }) {
                GraphNodeDetailView(
                    vm: vm,
                    node: node,
                    openDocument: openDocument,
                    requestedDownloadVolumeIds: $requestedDownloadVolumeIds
                )
            } else {
                Text(String(localized: "graph.detail.placeholder",
                            defaultValue: "Select a document in the graph or the list below to see its details."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .animation(nil, value: vm.resolvedNodeKey)
    }

    /// The synchronized reference list.
    private var referenceList: some View {
        ScrollViewReader { proxy in
            List {
                referenceSection(
                    title: String(localized: "graph.list.inbound",
                                  defaultValue: "Cites This Document"),
                    nodes: nodes(matching: { node in
                        if case .inbound = node.kind { return true }
                        if case .clusterInbound = node.kind { return true }
                        return false
                    })
                )
                referenceSection(
                    title: String(localized: "graph.list.outbound",
                                  defaultValue: "Cited By This Document"),
                    nodes: nodes(matching: { node in
                        if case .outbound = node.kind { return true }
                        if case .clusterOutbound = node.kind { return true }
                        return false
                    })
                )
                referenceSection(
                    title: String(localized: "graph.list.extended",
                                  defaultValue: "Further Hops"),
                    nodes: nodes(matching: { node in
                        if case .extended = node.kind { return true }
                        return false
                    })
                )
            }
            .listStyle(.plain)
            .onChange(of: vm.selectedNodeKey) { _, newKey in
                guard let newKey else { return }
                withAnimation { proxy.scrollTo(newKey, anchor: .center) }
            }
        }
    }

    // MARK: - Sections

    /// Non-central nodes matching `predicate`, in display order. Reads the
    /// *base* (unclustered) nodes so the list always shows real documents,
    /// even while the canvas folds some into timeline date clusters.
    private func nodes(matching predicate: (DisplayNode) -> Bool) -> [DisplayNode] {
        vm.baseDisplayNodes.filter { !$0.isCentral && predicate($0) }
    }

    @ViewBuilder
    private func referenceSection(title: String, nodes: [DisplayNode]) -> some View {
        if !nodes.isEmpty {
            Section {
                ForEach(nodes) { node in
                    if node.isCluster {
                        clusterRow(node)
                    } else {
                        nodeRow(node)
                    }
                }
            } header: {
                Text(title)
            }
        }
    }

    // MARK: - Rows

    /// One document row: selectable, with an open shortcut and a context menu.
    @ViewBuilder
    private func nodeRow(_ node: DisplayNode) -> some View {
        let isSelected = vm.selectedNodeKey == node.id
        let edge = vm.primaryEdge(for: node.id)

        HStack(alignment: .top, spacing: 8) {
            Button {
                vm.selectedEdgeKey = nil
                vm.selectedNodeKey = isSelected ? nil : node.id
                if vm.selectedNodeKey == node.id {
                    // If the canvas has folded this document into a collapsed
                    // date cluster, expand it so the highlight is visible.
                    vm.expandDateClusterContaining(node.id)
                }
            } label: {
                rowContent(node: node, edge: edge)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(node.accessibilityLabel)
            .accessibilityHint(String(localized: "graph.list.row.hint",
                                      defaultValue: "Highlights this document in the graph"))

            Spacer(minLength: 0)

            Button {
                if let entry = vm.makeEntry(for: node.id) {
                    openDocument(entry)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(node.isDownloaded ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!node.isDownloaded || vm.makeEntry(for: node.id) == nil)
            .controlHelp(
                String(localized: "graph.list.open.a11y", defaultValue: "Open document"),
                detail: String(localized: "graph.list.open.help",
                               defaultValue: "Open this document"),
                systemImage: "arrow.up.right.square"
            )
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)
        .id(node.id)
        .contextMenu {
            Button {
                vm.navigateToNode(node.id)
            } label: {
                Label(String(localized: "graph.contextMenu.recenter",
                             defaultValue: "Recenter Graph"),
                      systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                if let entry = vm.makeEntry(for: node.id) {
                    openDocument(entry)
                }
            } label: {
                Label(String(localized: "graph.contextMenu.openDocument",
                             defaultValue: "Open in Main Window"),
                      systemImage: "arrow.up.right.square")
            }
            .disabled(!node.isDownloaded || vm.makeEntry(for: node.id) == nil)
        }
    }

    /// Header, date/volume caption, context snippet, and status markers for a row.
    @ViewBuilder
    private func rowContent(node: DisplayNode, edge: DisplayEdge?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(kindColor(node).opacity(0.55))
                    .frame(width: 7, height: 7)
                    .padding(.top, 1)
                if let num = node.metadata?.documentNumber {
                    Text(verbatim: "\(num).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(node.metadata?.header ?? node.id)
                    .font(.callout)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let date = vm.nodeDateLabels[node.id] {
                    Text(date)
                }
                if let volume = node.metadata?.volumeId {
                    Text(volume)
                }
                if let edge, edge.referenceCount > 1 {
                    Text(String(
                        format: String(localized: "graph.list.refCount %lld",
                                       defaultValue: "×%lld"),
                        Int64(edge.referenceCount)
                    ))
                }
                if !node.isDownloaded {
                    Image(systemName: "icloud.slash")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let snippet = edge?.contexts.first {
                Text(snippet)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
    }

    /// One cluster row: tapping expands the volume group in place.
    @ViewBuilder
    private func clusterRow(_ node: DisplayNode) -> some View {
        Button {
            vm.toggleCluster(node.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(kindColor(node).opacity(0.8))
                Text(node.accessibilityLabel)
                    .font(.callout)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            // #312 follow-up: the Spacer already makes this HStack full width; this makes
            // the gaps hit-testable under `.buttonStyle(.plain)`.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(node.id)
        .accessibilityHint(String(localized: "graph.list.cluster.hint",
                                  defaultValue: "Expands this volume's documents"))
    }

    /// Role colour matching the canvas encoding (blue inbound, orange outbound,
    /// grey extended).
    private func kindColor(_ node: DisplayNode) -> Color {
        switch node.kind {
        case .inbound, .clusterInbound:   return .blue
        case .outbound, .clusterOutbound: return .orange
        default:                          return .secondary
        }
    }
}

// MARK: - GraphNodeDetailView

/// Details for the active graph node, shown at the top of `ReferenceListPanel`
/// (Session 162: replaced the floating canvas card on regular widths).
///
/// Mirrors the compact-width floating panel's content: header, dateline, volume,
/// on-device summary, the footnote context that carried the reference, the
/// Download Volume action for undownloaded nodes, and Recenter / View Document /
/// dismiss actions.
struct GraphNodeDetailView: View {

    @Bindable var vm: CrossReferenceGraphViewModel
    let node: DisplayNode
    /// Invoked when the user opens the document.
    let openDocument: (DocumentBrowserEntry) -> Void
    /// Shared queued-download record, owned by the hosting panel.
    @Binding var requestedDownloadVolumeIds: Set<String>

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text(detailTitle)
                    .font(.headline)
                    .lineLimit(3)
                Spacer(minLength: 4)
                Button {
                    vm.selectedNodeKey = nil
                    vm.selectedEdgeKey = nil
                    vm.hoveredNodeKey = nil
                    vm.hoveredEdgeKey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .controlHelp(
                    String(localized: "graph.panel.close.a11y", defaultValue: "Close details"),
                    detail: String(localized: "graph.panel.close.help",
                                   defaultValue: "Hide this document's details panel"),
                    systemImage: "xmark.circle.fill"
                )
            }

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

            if let summary = node.metadata?.summary,
               !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            if let context = vm.contextForSelectedNode() {
                EdgeContextView(context: context, directionLabel: directionLabel)
            }

            if !node.isDownloaded && !node.isCentral && !node.isDateCluster {
                downloadSection
            }

            if node.isDateCluster {
                Button {
                    vm.toggleDateCluster(node.id)
                    vm.selectedNodeKey = nil
                } label: {
                    Text(String(localized: "graph.dateCluster.expand",
                                defaultValue: "Expand Date Group"))
                }
                .buttonStyle(.bordered)
            } else if node.isCluster {
                Button {
                    vm.toggleCluster(node.id)
                    vm.selectedNodeKey = nil
                } label: {
                    Text(String(localized: "graph.cluster.expand",
                                defaultValue: "Expand Cluster"))
                }
                .buttonStyle(.bordered)
            } else if !node.isCentral {
                HStack(spacing: 8) {
                    Button {
                        vm.navigateToNode(node.id)
                    } label: {
                        Text(String(localized: "graph.node.recenter",
                                    defaultValue: "Recenter"))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        if let entry = vm.makeEntry(for: node.id) {
                            openDocument(entry)
                        }
                    } label: {
                        Text(String(localized: "graph.node.viewDocument",
                                    defaultValue: "View Document"))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!node.isDownloaded || vm.makeEntry(for: node.id) == nil)
                }
                .padding(.top, 2)
            }
        }
    }

    /// Title for the detail header: document header when known, the descriptive
    /// cluster label for cluster nodes (never the raw "datecluster/…" key).
    private var detailTitle: String {
        if let header = node.metadata?.header { return header }
        if node.isCluster || node.isDateCluster { return node.accessibilityLabel }
        return node.id
    }

    /// Direction label for the context passage (mirrors the floating panel's).
    private var directionLabel: String {
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

    /// Undownloaded status + Download Volume action (spec §11). Mirrors the
    /// compact floating panel's section; duplicated here because each host owns
    /// its queued-state record.
    @ViewBuilder
    private var downloadSection: some View {
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
            } else if let entry = manifestEntry(for: volumeId),
                      let downloadManager = appState.downloadManager {
                Button {
                    requestedDownloadVolumeIds.insert(volumeId)
                    Task {
                        await downloadManager.enqueueDownload(entry)
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
}

// MARK: - GraphEdgeDetailView

/// Details for the active graph edge — the source→target pair, reference count,
/// and the footnote/editorial passages that carried the references — shown at
/// the top of `ReferenceListPanel` (Session 162).
struct GraphEdgeDetailView: View {

    @Bindable var vm: CrossReferenceGraphViewModel
    let edge: DisplayEdge
    let context: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                Spacer(minLength: 4)
                Button {
                    vm.selectedEdgeKey = nil
                    vm.hoveredEdgeKey = nil
                    vm.hoveredNodeKey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .controlHelp(
                    String(localized: "graph.panel.close.a11y", defaultValue: "Close details"),
                    detail: String(localized: "graph.panel.close.help",
                                   defaultValue: "Hide this document's details panel"),
                    systemImage: "xmark.circle.fill"
                )
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

            EdgeContextView(context: context, directionLabel: edgeDirectionLabel)
        }
    }

    /// Direction label mirroring the floating edge panel's logic.
    private var edgeDirectionLabel: String {
        if edge.degree > 1 {
            return String(localized: "graph.context.extendedRef",
                          defaultValue: "Extended reference")
        }
        return edge.source == vm.centralKey
            ? String(localized: "graph.context.referencesFrom", defaultValue: "References from")
            : String(localized: "graph.context.referencedIn",   defaultValue: "Referenced in")
    }
}
