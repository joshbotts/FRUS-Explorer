// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionPickerSheet

/// Sheet that adds a document (or a frozen selection excerpt) to an existing collection,
/// or creates a new one.
///
/// Presents a searchable list of all collections. Tapping a row adds the document as a new
/// `CollectionEntry` at the end of that collection and dismisses the sheet; the "New Collection"
/// button opens `CollectionEditorView`. When `excerpt` is non-nil the picker runs in excerpt mode
/// (Authoring Phase 5) and freezes the capture into a `.excerpt` entry instead (no duplicate guard).
///
/// ## Platform layout
/// One shared struct, two platform bodies (Research-rail Phase C1 unified the former macOS
/// `CollectionPickerSheet` and iOS `CollectionPickerSheetView` twins). On macOS a plain `VStack`
/// with an inline search `TextField` + explicit button bar (a `NavigationStack { List }` inside a
/// macOS sheet collapses into an empty-detail sidebar). On iOS a `NavigationStack` with
/// `.searchable`, inset-grouped list, inline title, and medium/large presentation detents.
///
/// Version history:
///   1.0 — Session 35+: initial macOS implementation
///   1.1 — Session 129: split macOS / iOS bodies (NavigationStack sidebar fix)
///   1.2 — Authoring Phase 5 (excerpts): optional `excerpt` capture → `.excerpt` entry
///   1.3 — Research-rail Phase C1: the two per-platform twins unified into this one shared
///          cross-platform struct; the document-count row now counts only `.document`
///          entries (D5), so co-provenanced excerpts don't inflate the membership count.
struct CollectionPickerSheet: View {

    /// The document being added (its `volumeId`/`documentId` provenance).
    let entry: DocumentBrowserEntry

    /// When non-nil, the picker runs in excerpt mode: the chosen collection receives this capture
    /// as a `.excerpt` entry rather than the document.
    var excerpt: CollectionExcerptCapture? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.lastModified, order: .reverse) private var collections: [Collection]

    @State private var searchText: String = ""
    @State private var showNewCollection = false
    @State private var addedCollectionId: UUID? = nil

    private var filtered: [Collection] {
        guard !searchText.isEmpty else { return collections }
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// The sheet title — names the excerpt mode when active.
    private var pickerTitle: String {
        excerpt == nil
            ? String(localized: "collection.picker.nav.title",
                     defaultValue: "Add to Collection")
            : String(localized: "collection.picker.title.excerpt",
                     defaultValue: "Add Excerpt to Collection")
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Shared collection row

    /// One collection row: name + document count + an added checkmark. The count is restricted to
    /// `.document` entries (D5) so excerpt/heading/prose/generated entries co-provenanced to this
    /// document don't inflate the collection's document total.
    private func collectionRow(_ collection: Collection) -> some View {
        Button {
            addDocument(to: collection)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    let count = (collection.documentEntries ?? [])
                        .filter { $0.entryKind == .document }.count
                    Text(String(localized: "collection.picker.docCount",
                                defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if addedCollectionId == collection.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(String(localized: "collection.picker.added.a11y",
                                                   defaultValue: "Added"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(collection.name)
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(pickerTitle)
                    .font(.headline)
                Spacer()
                Button {
                    showNewCollection = true
                } label: {
                    Label(String(localized: "collection.picker.newCollection",
                                 defaultValue: "New Collection"),
                          systemImage: "folder.badge.plus")
                }
                .labelStyle(.iconOnly)
                .help(String(localized: "collection.picker.newCollection.help",
                             defaultValue: "Create a new collection"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Inline search field
            if !collections.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "collection.picker.search.placeholder",
                                     defaultValue: "Search collections…"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()

            // Collection list or empty state
            if collections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(String(localized: "collection.picker.empty",
                                defaultValue: "No Collections"))
                        .font(.headline)
                    Text(String(localized: "collection.picker.empty.hint",
                                defaultValue: "Use the button above to create one."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(String(localized: "collection.picker.noResults",
                                defaultValue: "No collections match \"\(searchText)\"."))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(filtered) { collection in
                    collectionRow(collection)
                }
                .listStyle(.inset)
            }

            Divider()

            // Button bar
            HStack {
                Spacer()
                Button(String(localized: "collection.picker.cancel",
                              defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 340)
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }
    #endif

    // MARK: - iOS Body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.picker.empty.title",
                               defaultValue: "No Collections"),
                        systemImage: "folder",
                        description: Text(
                            String(localized: "collection.picker.empty.detail",
                                   defaultValue: "Create a collection using the button above.")
                        )
                    )
                } else {
                    List(filtered) { collection in
                        collectionRow(collection)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        prompt: String(localized: "collection.picker.search.prompt",
                                       defaultValue: "Search collections")
                    )
                }
            }
            .navigationTitle(pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.picker.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewCollection = true
                    } label: {
                        Label(
                            String(localized: "collection.picker.newCollection",
                                   defaultValue: "New Collection"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                    .accessibilityLabel(
                        String(localized: "collection.picker.newCollection.a11y",
                               defaultValue: "Create a new collection")
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }
    #endif

    // MARK: - Add action

    private func addDocument(to collection: Collection) {
        // Excerpt mode (Authoring Phase 5): freeze the capture into a `.excerpt` entry.
        // No duplicate guard — several excerpts from one document are expected.
        if let excerpt {
            CollectionExcerpts.appendToCollection(excerpt, collection: collection,
                                                  modelContext: modelContext)
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            return
        }

        // Guard against duplicates — show checkmark and dismiss if already a member.
        let existing = collection.documentEntries ?? []
        guard !existing.contains(where: {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }) else {
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            return
        }

        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let collectionEntry = CollectionEntry(
            collectionId: collection.id,
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            sortOrder: nextOrder
        )
        modelContext.insert(collectionEntry)
        collection.documentEntries?.append(collectionEntry)

        addedCollectionId = collection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}
