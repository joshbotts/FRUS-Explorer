// OutlineView.swift
// Middle column: expandable/collapsible tree of the selected FRUS volume.

import SwiftUI
import FRUSKit

struct OutlineView: View {
    @Environment(AppStore.self) private var store: AppStore

    @State private var showingSearch = false

    private var volume: LoadedVolume? { store.selectedVolume }

    var body: some View {
        Group {
            if showingSearch {
                SearchView()
            } else if let volume {
                LoadedOutlineView(volume: volume)
            } else {
                emptyState
            }
        }
        .navigationTitle(showingSearch ? "Search" : (store.selectedVolume?.info.id ?? "Outline"))
        .toolbar { searchToolbarItem }
    }

    @ToolbarContentBuilder
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSearch.toggle()
                    if !showingSearch { store.searchResults = [] }
                }
            } label: {
                Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
            }
            .help(showingSearch ? "Close search" : "Search across all downloaded volumes")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.squares.left")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a downloaded volume to explore its structure.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - LoadedOutlineView

private struct LoadedOutlineView: View {
    @Environment(AppStore.self) private var store: AppStore
    let volume: LoadedVolume

    @State private var nodes: [OutlineNode] = []
    @State private var expanded: Set<String> = []

    var body: some View {
        // @Environment properties on @Observable types are not directly bindable.
        // Wrapping in @Bindable re-enables the $ projected-value syntax so that
        // List(selection: $store.selectedNodeID) compiles correctly.
        @Bindable var store = store
        return VStack(spacing: 0) {
            // Volume title header
            VStack(alignment: .leading, spacing: 4) {
                Text(volume.volume.seriesTitle ?? "Foreign Relations of the United States")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.secondary)
                Text(volume.volume.volumeTitle ?? volume.info.id)
                    .font(.system(.subheadline, design: .serif))
                    .fontWeight(.semibold)
                    .lineLimit(3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)

            Divider()

            // Stats strip
            HStack(spacing: 16) {
                statChip(
                    label: "Docs",
                    value: "\(volume.volume.documents.count)"
                )
                statChip(
                    label: "Chapters",
                    value: "\(volume.volume.chapters.count)"
                )
                Spacer()
                Button {
                    withAnimation { expanded = [] }
                } label: {
                    Text("Collapse All")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quinary)

            Divider()

            // Outline tree
            List(nodes, children: \.optionalChildren, selection: $store.selectedNodeID) { node in
                OutlineRowView(node: node)
                    .tag(node.id)
            }
            .listStyle(.sidebar)
            .onChange(of: store.selectedNodeID) { _, newID in
                if let id = newID,
                   let node = findNode(id: id, in: nodes),
                   let div = node.division {
                    store.summarise(div, volumeID: volume.id)
                }
            }
        }
        .task(id: volume.id) {
            nodes = OutlineBuilder.build(from: volume.volume)
            // Auto-expand the top level
            expanded = Set(nodes.map(\.id))
        }
    }

    private func statChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func findNode(id: String, in nodes: [OutlineNode]) -> OutlineNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(id: id, in: node.children) { return found }
        }
        return nil
    }
}

// MARK: - OutlineRowView

struct OutlineRowView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    let node: OutlineNode

    // Show inline add-to-collection button on hover for documents and notes
    @State private var isHovered = false
    @State private var showingAddToCollection = false

    private var isCollectable: Bool {
        node.kind == .document || node.kind == .editorialNote
    }

    private var summary: SummaryState? {
        guard let div = node.division,
              let volID = store.selectedVolumeID else { return nil }
        return store.summary(for: div, volumeID: volID)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: node.icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 16)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                // ── Primary label ──────────────────────────────────────
                Text(node.title)
                    .font(.system(.caption, design: .serif))
                    .fontWeight(node.kind == .document ? .medium : .regular)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Dateline / subtitle ────────────────────────────────
                if let sub = node.subtitle {
                    Text(sub)
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(1)
                }

                // ── Source note first sentence ─────────────────────────
                if let src = node.sourceNote {
                    Text(src)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── AI summary preview ─────────────────────────────────
                if let summary {
                    summaryPreview(summary)
                }
            }

            Spacer(minLength: 0)

            // ── Visible "Add to Collection" button ─────────────────────
            // Shown for documents and editorial notes; always visible (not
            // hover-only) so it works on touch and is discoverable.
            if isCollectable {
                addToCollectionButton
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            if isCollectable { addToCollectionMenu }
        }
    }

    // MARK: - Visible Add to Collection button

    @ViewBuilder
    private var addToCollectionButton: some View {
        Menu {
            addToCollectionMenu
        } label: {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .help("Add to collection")
        // Keep button from triggering list row selection
        .onTapGesture { } // consumed by Menu
    }

    // MARK: - Add to Collection menu content

    @ViewBuilder
    private var addToCollectionMenu: some View {
        if collectionStore.collections.isEmpty {
            Button("Add to New Collection") {
                guard let div = node.division else { return }
                let col = collectionStore.create(name: "My Collection")
                addNodeToCollection(div, collection: col)
            }
        } else {
            ForEach(collectionStore.collections) { col in
                Button(col.name) {
                    guard let div = node.division else { return }
                    addNodeToCollection(div, collection: col)
                }
            }
            Divider()
            Button("New Collection…") {
                guard let div = node.division else { return }
                let col = collectionStore.create(name: node.title)
                addNodeToCollection(div, collection: col)
            }
        }
    }

    private func addNodeToCollection(_ div: Division, collection: DocumentCollection) {
        guard let divID = div.id else { return }
        guard let volID = store.selectedVolumeID else { return }
        let item = CollectionItem(
            volumeID: volID,
            divisionID: divID,
            cachedTitle: node.title,
            cachedDateline: node.subtitle,
            isEditorialNote: node.kind == .editorialNote
        )
        collectionStore.addItem(item, to: collection)
    }

    // MARK: - Summary preview

    @ViewBuilder
    private func summaryPreview(_ state: SummaryState) -> some View {
        switch state {
        case .generating:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                Text("Summarising…")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        case .ready(let text):
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        case .failed:
            EmptyView()
        }
    }

    private var iconColor: Color {
        switch node.kind {
        case .compilation:   return .orange
        case .chapter:       return .blue
        case .document:      return .primary
        case .editorialNote: return .purple
        case .frontMatter, .backMatter: return .gray
        case .section:       return .teal
        default:             return .secondary
        }
    }
}

// MARK: - Children helper for List

extension OutlineNode {
    /// SwiftUI `List(children:)` requires `[Element]?`.
    var optionalChildren: [OutlineNode]? {
        children.isEmpty ? nil : children
    }
}
