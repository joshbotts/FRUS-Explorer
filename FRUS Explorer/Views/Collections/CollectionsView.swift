// Views/Collections/CollectionsView.swift
// Left-pane list of all collections with create / rename / delete actions.

import SwiftUI
import FRUSKit

struct CollectionsView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore

    @State private var selectedCollectionID: UUID?
    @State private var showingNewSheet = false
    @State private var newName = ""
    @State private var renamingCollection: DocumentCollection?
    @State private var renameText = ""

    var body: some View {
        NavigationSplitView {
            sidebarList
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            if let id = selectedCollectionID,
               let col = collectionStore.collections.first(where: { $0.id == id }) {
                CollectionEditorView(collectionID: col.id)
            } else {
                emptyDetail
            }
        }
        .navigationTitle("Collections")
        .sheet(isPresented: $showingNewSheet) { newSheet }
        .sheet(item: $renamingCollection) { renameSheet($0) }
    }

    // MARK: - Sidebar

    private var sidebarList: some View {
        List(selection: $selectedCollectionID) {
            ForEach(collectionStore.collections) { col in
                CollectionSidebarRow(collection: col)
                    .tag(col.id)
                    .contextMenu {
                        Button("Rename…") {
                            renamingCollection = col
                            renameText = col.name
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            if selectedCollectionID == col.id { selectedCollectionID = nil }
                            collectionStore.delete(col)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if collectionStore.collections.isEmpty {
                ContentUnavailableView(
                    "No Collections",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Tap + to create a collection, then right-click any document in the outline to add it.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newName = ""; showingNewSheet = true } label: {
                    Image(systemName: "plus")
                }
                .help("New collection")
            }
        }
    }

    // MARK: - Empty detail

    private var emptyDetail: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Select a collection to view and manage its documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sheets

    private var newSheet: some View {
        NameInputSheet(title: "New Collection", actionLabel: "Create", name: $newName) {
            createCollection()
        } onCancel: {
            showingNewSheet = false
        }
    }

    private func renameSheet(_ col: DocumentCollection) -> some View {
        NameInputSheet(title: "Rename Collection", actionLabel: "Rename", name: $renameText) {
            applyRename(col)
        } onCancel: {
            renamingCollection = nil
        }
    }

    // MARK: - Actions

    private func createCollection() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let col = collectionStore.create(name: name)
        showingNewSheet = false
        selectedCollectionID = col.id
    }

    private func applyRename(_ col: DocumentCollection) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        collectionStore.rename(col, to: name)
        renamingCollection = nil
    }
}

// MARK: - NameInputSheet

private struct NameInputSheet: View {
    let title: String
    let actionLabel: String
    @Binding var name: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(title).font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 270)
                .onSubmit(onCommit)
            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button(actionLabel, action: onCommit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
    }
}

// MARK: - CollectionSidebarRow

private struct CollectionSidebarRow: View {
    let collection: DocumentCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(collection.name)
                .font(.system(.callout, design: .serif))
                .fontWeight(.medium)
                .lineLimit(1)
            let plural = collection.items.count == 1 ? "" : "s"
            Text("\(collection.items.count) document\(plural)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
