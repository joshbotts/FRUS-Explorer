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

    var body: some View {
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

    /// Non-central display nodes matching `predicate`, in display order.
    private func nodes(matching predicate: (DisplayNode) -> Bool) -> [DisplayNode] {
        vm.displayNodes.filter { !$0.isCentral && predicate($0) }
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
