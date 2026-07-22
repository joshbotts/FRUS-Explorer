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
    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    /// Opens the Word Cloud window directly for the row context-menu action (the
    /// MainWindowView relay is retired — provenance PR 2).
    @Environment(\.openWindow) private var openWindow
    #endif

    // MARK: - Data

    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearches: [SavedSearch]

    // MARK: - State

    @State private var renaming: SavedSearch? = nil
    @State private var renameText: String = ""

    // MARK: - Body

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
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

    // MARK: - macOS body

    #if os(macOS)
    /// macOS-native layout: title row + list + Done button bar (no NavigationStack chrome).
    private var macBody: some View {
        VStack(spacing: 0) {
            Text(String(localized: "savedSearches.title", defaultValue: "Saved Searches"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

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

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "savedSearches.done", defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iOSBody: some View {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "savedSearches.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    #endif // os(iOS)

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
                    Button {
                        appState.openWordCloud(.savedSearch(id: search.id), from: sceneID)
                        #if os(macOS)
                        // Direct open (the MainWindowView relay is retired — provenance
                        // PR 2). This sheet is presented from the Search window, so the
                        // cloud inherits Search's provenance (transitive bind).
                        appState.bindTool(.wordCloud, to: appState.provenance(of: .search))
                        openWindow(id: "frus.wordcloud")
                        bringMacWindowToFront(id: "frus.wordcloud")
                        #endif
                        dismiss()
                    } label: {
                        Label { Text(String(localized: "savedSearches.row.wordCloud",
                                            defaultValue: "Word Cloud")) }
                            icon: { Image(systemName: WordCloudGlyph.symbol) }
                    }
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
