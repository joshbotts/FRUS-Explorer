// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionListView

/// Displays all `Collection` records visible in the current project context.
///
/// ## Filtering
/// When `activeProjectId` is non-nil, only collections whose `projectIds`
/// contains that ID are shown. When nil, all collections are shown (global view).
///
/// ## Navigation
/// Tapping a row navigates to `CollectionEditorView` for that collection.
/// The "+" toolbar button creates a new collection and navigates to its editor.
///
/// ## Deletion
/// Swipe-to-delete removes the collection and all its entries. Entries are deleted
/// explicitly before the parent collection because `deleteRule: .nullify` is used for
/// CloudKit compatibility (cascade rules are not supported by CloudKit).
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 35: macOS compatibility — guard `.insetGrouped` list style
///   1.2 — Session 55: add Done toolbar button on macOS (previously no close control)
///   1.3 — Add `showDoneButton` parameter; set to `false` when hosted in a Window scene
///   1.4 — Session 89: manual entry deletion before collection delete (deleteRule .nullify)
struct CollectionListView: View {

    /// Pass `false` when this view is the root content of a `Window` scene; in that
    /// context the OS window chrome (red button / ⌘W) already provides dismissal.
    var showDoneButton: Bool = true

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]

    @State private var collectionToEdit: Collection? = nil
    @State private var isCreating = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if filteredCollections.isEmpty {
                    emptyState
                } else {
                    collectionList
                }
            }
            .navigationTitle(String(localized: "collections.nav.title",
                                    defaultValue: "Collections"))
            .toolbar {
                #if !os(iOS)
                if showDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "collections.toolbar.done",
                                      defaultValue: "Done")) {
                            dismiss()
                        }
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Label(String(localized: "collections.toolbar.new",
                                     defaultValue: "New Collection"),
                              systemImage: "plus")
                    }
                    .accessibilityLabel(String(localized: "collections.toolbar.new.accessibility",
                                               defaultValue: "Create new collection"))
                }
            }
            .sheet(isPresented: $isCreating) {
                CollectionEditorView(collection: nil)
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionEditorView(collection: collection)
            }
        }
    }

    // MARK: - Subviews

    private var collectionList: some View {
        List {
            ForEach(filteredCollections) { collection in
                CollectionRow(collection: collection)
                    .contentShape(Rectangle())
                    .onTapGesture { collectionToEdit = collection }
            }
            .onDelete { indexSet in
                deleteCollections(at: indexSet)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "collections.empty.title", defaultValue: "No Collections"),
                systemImage: "tray"
            )
        } description: {
            Text(String(localized: "collections.empty.description",
                        defaultValue: "Create a collection to group documents for export."))
        } actions: {
            Button(String(localized: "collections.empty.action",
                          defaultValue: "New Collection")) {
                isCreating = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Filtering

    private var filteredCollections: [Collection] {
        guard let projectId = appState.activeProjectId else {
            return allCollections
        }
        return allCollections.filter { $0.projectIds.contains(projectId) }
    }

    // MARK: - Actions

    private func deleteCollections(at indexSet: IndexSet) {
        for index in indexSet {
            let c = filteredCollections[index]
            for entry in c.documentEntries ?? [] { modelContext.delete(entry) }
            modelContext.delete(c)
        }
        try? modelContext.save()
    }
}

// MARK: - CollectionRow

private struct CollectionRow: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(collection.name.isEmpty
                 ? String(localized: "collections.row.untitled", defaultValue: "Untitled Collection")
                 : collection.name)
                .font(.body)

            HStack(spacing: 6) {
                let count = collection.documentEntries?.count ?? 0
                Text(String(localized: "collections.row.count",
                            defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let date = collection.lastModified {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
