// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import SwiftData

// MARK: - HistoryWindowView

/// "Complete History" window — the full reading and search history, each
/// section independently sortable by recency and filterable by project.
///
/// Reachable via the macOS "History" menu's "Complete History…" item
/// (`frus.history` window scene). The History menu itself shows only the ten
/// most-recent documents visited and searches executed across all projects;
/// this window shows the complete record with an optional project filter so
/// researchers can review their full activity within a single project's scope.
///
/// Selecting a document re-opens it in the main window
/// (`AppState.pendingBrowseDocument`); selecting a search re-runs it in the
/// Search window (`AppState.pendingSearch`) — the same mechanisms used
/// throughout the app for cross-window navigation.
///
/// Version history:
///   1.0 — Session 2026-06-07: initial implementation
struct HistoryWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse)
    private var allDocumentVisits: [ReadingHistoryEntry]

    @Query(sort: \SearchHistoryEntry.executedAt, order: .reverse)
    private var allSearches: [SearchHistoryEntry]

    @Query(sort: \Project.name) private var projects: [Project]

    @State private var projectFilter: HistoryProjectFilter = .all

    private var filteredVisits: [ReadingHistoryEntry] {
        allDocumentVisits.filter { projectFilter.matches($0.projectId) }
    }

    private var filteredSearches: [SearchHistoryEntry] {
        allSearches.filter { projectFilter.matches($0.projectId) }
    }

    var body: some View {
        List {
            documentsSection
            searchesSection
        }
        .listStyle(.inset)
        .navigationTitle(String(localized: "history.window.title", defaultValue: "History"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                projectFilterPicker
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    // MARK: - Sections

    private var documentsSection: some View {
        Section {
            if filteredVisits.isEmpty {
                ContentUnavailableView(
                    String(localized: "history.documents.empty.title",
                           defaultValue: "No Documents Visited"),
                    systemImage: "doc.text",
                    description: Text(String(localized: "history.documents.empty.detail",
                                             defaultValue: "Documents you open will appear here."))
                )
            } else {
                ForEach(filteredVisits) { entry in
                    Button {
                        openDocument(entry)
                    } label: {
                        documentRow(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(String(localized: "history.documents.header",
                        defaultValue: "Documents Visited (\(filteredVisits.count))"))
        }
    }

    private var searchesSection: some View {
        Section {
            if filteredSearches.isEmpty {
                ContentUnavailableView(
                    String(localized: "history.searches.empty.title",
                           defaultValue: "No Searches Executed"),
                    systemImage: "magnifyingglass",
                    description: Text(String(localized: "history.searches.empty.detail",
                                             defaultValue: "Searches you run will appear here."))
                )
            } else {
                ForEach(filteredSearches) { entry in
                    Button {
                        runSearch(entry)
                    } label: {
                        searchRow(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text(String(localized: "history.searches.header",
                        defaultValue: "Searches Executed (\(filteredSearches.count))"))
        }
    }

    // MARK: - Rows

    private func documentRow(_ entry: ReadingHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Captured display title preferred; pre-1.1 entries fall back to
            // "volumeId · documentId" (mirrors ReadingHistoryListView in
            // ProjectContextView).
            Text(entry.displayTitle ?? "\(entry.volumeId) · \(entry.documentId)")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                Text(entry.volumeId)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let date = entry.accessedAt {
                    Text("·").foregroundStyle(.tertiary)
                    Text(date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func searchRow(_ entry: SearchHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.queryText)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)
            HStack(spacing: 6) {
                Text(String(localized: "history.searches.resultCount",
                            defaultValue: "\(entry.resultCount) results"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let date = entry.executedAt {
                    Text("·").foregroundStyle(.tertiary)
                    Text(date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Filter Picker

    private var projectFilterPicker: some View {
        Picker(String(localized: "history.filter.project.label", defaultValue: "Project"),
               selection: $projectFilter) {
            Text(String(localized: "history.filter.project.all", defaultValue: "All Projects"))
                .tag(HistoryProjectFilter.all)
            Text(String(localized: "history.filter.project.untagged", defaultValue: "Untagged"))
                .tag(HistoryProjectFilter.untagged)
            ForEach(projects) { project in
                Text(project.name).tag(HistoryProjectFilter.project(project.id))
            }
        }
        .accessibilityLabel(
            String(localized: "history.filter.project.a11y", defaultValue: "Filter history by project")
        )
        .help(String(localized: "history.filter.project.help",
                     defaultValue: "Show only history recorded while a specific project was active"))
    }

    // MARK: - Navigation

    /// Re-opens the document in the main window, mirroring
    /// `FRUSExplorerApp.navigateToDocument` and the History menu's document items.
    private func openDocument(_ entry: ReadingHistoryEntry) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            header: entry.displayTitle ?? entry.documentId
        )
    }

    /// Re-runs the search in the Search window via `AppState.pendingSearch`,
    /// the same hand-off mechanism used by saved searches and cross-references.
    private func runSearch(_ entry: SearchHistoryEntry) {
        appState.pendingSearch = SearchParameters(keywords: entry.queryText)
        openWindow(id: "frus.search")
    }
}

// MARK: - HistoryMenuContent

/// Content of the macOS "History" `CommandMenu` — the last ten documents
/// visited and last ten searches executed, plus a "Complete History…" item
/// that opens the standalone `HistoryWindowView` (`frus.history` window).
///
/// `appState` and `openWindow` are taken as explicit initializer parameters
/// rather than read via `@Environment`, mirroring how the neighboring
/// `CommandGroup` blocks in `FRUSExplorerApp` capture them directly from the
/// app struct's own stored properties — this avoids any uncertainty about
/// whether `@Environment(AppState.self)` propagates into `.commands` content.
///
/// Version history:
///   1.0 — Session 2026-06-07: initial implementation
struct HistoryMenuContent: View {

    let appState: AppState
    let openWindow: OpenWindowAction

    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse)
    private var allDocumentVisits: [ReadingHistoryEntry]

    @Query(sort: \SearchHistoryEntry.executedAt, order: .reverse)
    private var allSearches: [SearchHistoryEntry]

    /// The ten most recently visited documents, most recent first.
    private var recentVisits: [ReadingHistoryEntry] {
        Array(allDocumentVisits.prefix(10))
    }

    /// The ten most recently executed searches, most recent first.
    private var recentSearches: [SearchHistoryEntry] {
        Array(allSearches.prefix(10))
    }

    var body: some View {
        Menu(String(localized: "menu.history.documentsVisited", defaultValue: "Documents Visited")) {
            if recentVisits.isEmpty {
                Text(String(localized: "menu.history.documentsVisited.empty",
                            defaultValue: "No Documents Visited Yet"))
            } else {
                ForEach(recentVisits) { entry in
                    Button(entry.displayTitle ?? "\(entry.volumeId) · \(entry.documentId)") {
                        openDocument(entry)
                    }
                }
            }
        }

        Menu(String(localized: "menu.history.searchesExecuted", defaultValue: "Searches Executed")) {
            if recentSearches.isEmpty {
                Text(String(localized: "menu.history.searchesExecuted.empty",
                            defaultValue: "No Searches Executed Yet"))
            } else {
                ForEach(recentSearches) { entry in
                    Button(entry.queryText) {
                        runSearch(entry)
                    }
                }
            }
        }

        Divider()

        Button(String(localized: "menu.history.completeHistory", defaultValue: "Complete History\u{2026}")) {
            openWindow(id: "frus.history")
        }
    }

    // MARK: - Navigation

    /// Re-opens the document in the active document window via `AppState.pendingBrowseDocument`,
    /// mirroring `FRUSExplorerApp.navigateToDocument`.
    private func openDocument(_ entry: ReadingHistoryEntry) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            header: entry.displayTitle ?? entry.documentId
        )
    }

    /// Re-runs the search in the Search window via `AppState.pendingSearch`.
    private func runSearch(_ entry: SearchHistoryEntry) {
        appState.pendingSearch = SearchParameters(keywords: entry.queryText)
        openWindow(id: "frus.search")
    }
}

// MARK: - HistoryProjectFilter

/// Three-way project filter for `HistoryWindowView`: all projects, entries
/// recorded with no active project ("Untagged"), or a specific project.
///
/// A dedicated enum (rather than the `UUID?` + sentinel-UUID convention seen
/// in `GlobalContextView`) so "all" and "untagged" are represented exactly,
/// without relying on an unmatchable random UUID standing in for "untagged".
private enum HistoryProjectFilter: Hashable {
    case all
    case untagged
    case project(UUID)

    /// Whether a history entry's `projectId` satisfies this filter.
    func matches(_ projectId: UUID?) -> Bool {
        switch self {
        case .all:                 return true
        case .untagged:            return projectId == nil
        case .project(let target): return projectId == target
        }
    }
}

#endif // os(macOS)
