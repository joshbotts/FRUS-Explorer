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

/// "Complete History" window — the macOS host for the shared ``HistoryView``.
///
/// Reachable via the macOS "History" menu's "Complete History…" item
/// (`frus.history` window scene). The History menu itself shows only the ten
/// most-recent documents visited and searches executed across all projects;
/// this window shows the complete record, scopeable by project, searchable
/// within itself, and with per-entry delete.
///
/// ## Why this is now a wrapper
/// Wave R-3 moved the body into ``HistoryView``, which both platforms render — macOS here,
/// iOS pushed from the Research tab. Before that this view was `#if os(macOS)` and iPhone and
/// iPad had no view over the research trail at all, which the Wave R contract identified as the
/// largest remaining "my Mac can do things my iPad cannot". This type survives rather than being
/// deleted because the scene and its menu items are wired to the name, and because the window's
/// minimum size is a macOS concern that does not belong in the shared view.
///
/// Selecting a document re-opens it in this window's provenance host
/// (`AppState.openDocument(_:from: .tool(.history))`); selecting a search re-runs it
/// in the Search window (`AppState.pendingSearch` + a direct `openWindow`) — both still
/// live in ``HistoryView``, unchanged.
///
/// Version history:
///   1.0 — Session 2026-06-07: initial implementation
///   2.0 — Wave R-3: body extracted to the cross-platform `HistoryView`; the two unbounded
///          live `@Query`s and the local `HistoryProjectFilter` retire with it
struct HistoryWindowView: View {

    var body: some View {
        HistoryView()
            .frame(minWidth: 480, minHeight: 420)
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

    /// Re-opens the document via `AppState.openDocument(_:from: .global)` — the menu has no
    /// spawning window, so the open resolves straight through the fallback chain (owner
    /// decision D3: most-recently-key live host, else a fresh standalone document window).
    private func openDocument(_ entry: ReadingHistoryEntry) {
        appState.openDocument(DocumentBrowserEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            header: entry.displayTitle ?? entry.documentId
        ), from: .global, using: openWindow)
    }

    /// Re-runs the search in the Search window via `AppState.pendingSearch`.
    private func runSearch(_ entry: SearchHistoryEntry) {
        appState.openSearch(SearchParameters(keywords: entry.queryText), from: nil)
        // The menu-bar History menu has no spawning window — clear the search binding so results
        // open via the D3 recency fallback (the window-hosted History runSearch binds `.history`).
        appState.bindTool(.search, to: nil)
        openWindow(id: "frus.search")
        bringMacWindowToFront(id: "frus.search")   // #369 BUG-9: match the eight sibling producers
    }
}

#endif // os(macOS)
