// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SavedSearchesView

/// Sheet that lists all saved searches and lets the user recall, rename, or delete them.
///
/// ## Usage
/// Present as a sheet from `SearchView`. Pass an `onSelect` closure — it is called with
/// the tapped `SavedSearch` record, after which the sheet auto-dismisses. The caller
/// is responsible for applying the record's `searchParameters` to the search view model.
///
/// ## Rename
/// Long-pressing (or using the context menu) on a row opens an alert that lets the user
/// rename the saved search in place.
///
/// ## Delete
/// Swipe-to-delete on iOS; context-menu Delete on macOS.
///
/// Version history:
///   1.0 — Session 96: initial implementation
struct SavedSearchesView: View {

    // MARK: - Input

    let onSelect: (SavedSearch) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Data

    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]

    // MARK: - State

    @State private var renaming: SavedSearch? = nil
    @State private var renameText: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if savedSearches.isEmpty {
                    ContentUnavailableView(
                        String(localized: "savedSearches.empty.title",
                               defaultValue: "No Saved Searches"),
                        systemImage: "bookmark",
                        description: Text(
                            String(localized: "savedSearches.empty.detail",
                                   defaultValue: "Tap the bookmark button in Search to save a search for quick access later.")
                        )
                    )
                } else {
                    list
                }
            }
            .navigationTitle(String(localized: "savedSearches.title",
                                    defaultValue: "Saved Searches"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "savedSearches.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            .alert(
                String(localized: "savedSearches.rename.title", defaultValue: "Rename"),
                isPresented: Binding(
                    get: { renaming != nil },
                    set: { if !$0 { renaming = nil } }
                )
            ) {
                TextField(
                    String(localized: "savedSearches.rename.placeholder",
                           defaultValue: "Name"),
                    text: $renameText
                )
                Button(String(localized: "savedSearches.rename.save",
                              defaultValue: "Save")) {
                    renaming?.name = renameText
                    renaming = nil
                }
                Button(String(localized: "savedSearches.rename.cancel",
                              defaultValue: "Cancel"),
                       role: .cancel) {
                    renaming = nil
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(savedSearches) { search in
                Button {
                    onSelect(search)
                    dismiss()
                } label: {
                    row(for: search)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(String(localized: "savedSearches.row.rename",
                                  defaultValue: "Rename")) {
                        renaming = search
                        renameText = search.name
                    }
                    Button(String(localized: "savedSearches.row.delete",
                                  defaultValue: "Delete"),
                           role: .destructive) {
                        modelContext.delete(search)
                    }
                }
            }
            .onDelete { offsets in
                for i in offsets { modelContext.delete(savedSearches[i]) }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    // MARK: - Row

    private func row(for search: SavedSearch) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(search.name)
                .font(.body)
            if !search.queryText.isEmpty {
                Text(search.queryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
