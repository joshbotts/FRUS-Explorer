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
///   1.1 — W-5 (#266): freshness — rows carry a NEW capsule and an exact "+N since last
///         run" caption when the search matches more than it did at its last run.
///         Evaluated sequentially from a cancellable task (a cold filtered count can take
///         seconds; fanning out one per row at once would contend the index).
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
    /// W-5 (#266): per-record new-result counts. A missing key means "no badge" — never
    /// run, nothing new, or not yet evaluated.
    @State private var freshCounts: [UUID: Int] = [:]

    // MARK: - Body

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
        }
        // Re-evaluates when the set changes or any watermark is stamped (a run through
        // `onSelect` updates `freshnessData`, which changes this identity). The backfill a
        // first pass performs restarts the task once; the second pass writes nothing.
        .task(id: freshnessIdentity) { await evaluateFreshness() }
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
                        openWindow.fronting(id: "frus.wordcloud")
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
            HStack(spacing: 6) {
                Text(search.name)
                    .font(.body)
                if freshCounts[search.id] != nil {
                    SavedSearchNewBadge()
                }
            }
            if !search.queryText.isEmpty {
                Text(search.queryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let fresh = freshCounts[search.id] {
                // The count is exact (`searchCount`, uncapped) — which is what licenses
                // printing a number here rather than a vague "new results".
                Text(String(format: String(localized: "savedSearches.row.fresh %@",
                                           defaultValue: "+%@ since last run"),
                            fresh.formatted()))
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
        // #312 follow-up: full-row tap target. Both modifiers, in this order — a saved-search name
        // is usually short, so without the frame most of the row is dead to a finger (the enclosing
        // row Button is `.buttonStyle(.plain)`, which hit-tests only opaque content).
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Freshness (W-5 / #266)

    /// Identity for the evaluation task: the record set plus each watermark blob, so a
    /// stamp or backfill re-triggers evaluation while a plain re-render does not.
    private var freshnessIdentity: [String] {
        savedSearches.map { "\($0.id)|\($0.freshnessData?.hashValue ?? 0)" }
    }

    /// Evaluates every row SEQUENTIALLY, publishing counts as they arrive; cancelled
    /// mid-list when the identity changes or the sheet dismisses.
    private func evaluateFreshness() async {
        for search in savedSearches {
            guard !Task.isCancelled else { return }
            let id = search.id
            let count = await SavedSearchFreshnessEvaluator.newResultCount(
                for: search, service: appState.searchService, context: modelContext)
            guard !Task.isCancelled else { return }
            if let count {
                freshCounts[id] = count
            } else {
                freshCounts.removeValue(forKey: id)
            }
        }
    }
}

// MARK: - SavedSearchNewBadge

/// The NEW capsule a fresh saved search carries (W-5 / #266) — `ProjectHomeView`'s lead
/// capsule grammar, shared here because two surfaces (this sheet and the sidebar
/// shortcuts) would otherwise hand-maintain twins.
///
/// Version history:
///   1.0 — W-5 (#266): initial implementation
struct SavedSearchNewBadge: View {
    var body: some View {
        Text(String(localized: "savedSearches.row.new", defaultValue: "NEW"))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundStyle(Color.accentColor)
    }
}
