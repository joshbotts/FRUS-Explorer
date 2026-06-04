// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

/// The root view of the main document window on macOS.
///
/// ## Layout
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │  Unified titlebar  (toolbar items via .toolbar)     │
/// ├─────────────────────────────────────────────────────┤
/// │  ResearchStripView    (collapsible second row)       │
/// ├─────────────────────────────────────────────────────┤
/// │                                                     │
/// │  MacDocumentView  (NavigationStack<DocumentBrowser  │
/// │                    Entry> — replaces in-place)      │
/// │                                                     │
/// ├─────────────────────────────────────────────────────┤
/// │  StatusBarView        (index count · task · sync)   │
/// └─────────────────────────────────────────────────────┘
/// ```
///
/// ## Navigation
/// `navigationPath` is owned here so that cross-reference taps and search result
/// selections can push entries without `MacDocumentView` knowing its position in the
/// hierarchy. `AppState.pendingBrowseDocument` is consumed here via `.onChange`
/// and appended to the path, then cleared.
///
/// ## Search
/// Opening search calls `openWindow(id: "frus.search")`. The search window is a
/// separate `Window` scene that persists independently of the document stack.
///
/// ## Window toggling
/// Graph, source explorer, and corpus browser windows are opened via `openWindow(id:)`.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 99: Analytics toolbar button; opens frus.analytics Window
///   1.2 — Session 120: CitationLookupView sheet wired to appState.showCitationLookup
///          so the menu command (⌘⇧F) and any code path that sets the flag works on macOS
@MainActor
struct MainWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    /// The document navigation stack. Empty path = no document loaded (welcome placeholder).
    @State private var navigationPath: [DocumentBrowserEntry] = []

    /// Whether the citation popover is showing.
    @State private var showCitationPopover: Bool = false

    /// NARA Catalog Lookup sheet item.
    ///
    /// Using `.sheet(item:)` rather than `.sheet(isPresented:)` ensures SwiftUI creates
    /// a fresh `NARACatalogLookupView` on every open. With `.sheet(isPresented:)` SwiftUI
    /// can reuse the cached view between sessions, causing `@State(initialValue:)` to be
    /// ignored and leaving the query field empty or stale. Each `NARACatalogLookupItem`
    /// carries a unique `UUID` so the view identity changes on every call.
    @State private var naraLookupItem: NARACatalogLookupItem? = nil

    /// Shared highlight state passed to ResearchStripView (buttons) and MacDocumentView (text selection / SwiftData insertion).
    @State private var highlightCoordinator = HighlightCoordinator()

    // MARK: - Computed

    private var currentEntry: DocumentBrowserEntry? {
        navigationPath.last
    }

    // MARK: - Body

    var body: some View {
        @Bindable var appStateBindable = appState

        VStack(spacing: 0) {

            // Research strip — always rendered at full height.
            ResearchStripView(
                entry: currentEntry,
                showCitationPopover: $showCitationPopover,
                highlightCoordinator: highlightCoordinator,
                onNARALookup: { text in
                    // New UUID every time → SwiftUI treats it as a new view identity
                    // → @State(initialValue:) is honoured → query field shows the text.
                    naraLookupItem = NARACatalogLookupItem(text: text)
                }
            )
            .sheet(item: $naraLookupItem) { item in
                NARACatalogLookupView(initialText: item.text)
            }

            // Document body — NavigationStack owns the back/forward history.
            NavigationStack(path: $navigationPath) {
                DocumentPlaceholderView()
                    .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                        MacDocumentView(
                            entry: entry,
                            navigationPath: $navigationPath,
                            highlightCoordinator: highlightCoordinator
                        )
                    }
            }

            // Status bar — always visible, reports background activity.
            StatusBarView()
        }
        .toolbar { mainToolbar }
        // Consume pending navigation from cross-reference taps and search result selections.
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard let entry else { return }
            navigationPath.append(entry)
            appState.pendingBrowseDocument = nil
        }
        // Reset highlight state whenever the user navigates to a different document.
        .onChange(of: currentEntry) { _, _ in
            highlightCoordinator.reset()
        }
        // Open the search window when a cross-view pendingSearch arrives (e.g. "Find all
        // mentions" from PersonDetailSheet). MacSearchWindowView clears pendingSearch after
        // applying the parameters so both observers don't race.
        .onChange(of: appState.pendingSearch) { _, params in
            guard params != nil else { return }
            openWindow(id: "frus.search")
        }
        // Citation Lookup sheet — responds to both the menu command (⌘⇧F) and any
        // code that sets appState.showCitationLookup = true.
        .sheet(isPresented: $appStateBindable.showCitationLookup) {
            CitationLookupView()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        // Note: NO custom .navigation placement items here.
        // NavigationStack already provides its own back button in the toolbar when
        // a destination is pushed. Adding a second .navigation group creates a
        // duplicate back button that appears alongside the stack's own control.

        // Centre: document title + series subtitle
        ToolbarItem(placement: .principal) {
            documentTitle
        }

        // Trailing: tool launchers
        // .automatic is the correct macOS placement — .primaryAction is an iOS concept
        // that maps to the same position on macOS but carries incorrect semantics.
        ToolbarItemGroup(placement: .automatic) {
            trailingTools
        }
    }

    // MARK: - Document Title (principal toolbar item)

    private var documentTitle: some View {
        VStack(spacing: 2) {
            if let entry = currentEntry {
                Text(entry.header.isEmpty ? entry.documentId : entry.header)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let volumeEntry = appState.manifestStore.entry(forVolumeId: entry.volumeId) {
                    Text(volumeEntry.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text("FRUS Explorer")
                    .font(.system(size: 13, weight: .medium))
            }
        }
    }

    // MARK: - Trailing Tools

    private var trailingTools: some View {
        HStack(spacing: 6) {

            // Search — shortcut owned by the "frus.search" Window scene
            Button {
                openWindow(id: "frus.search")
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help(String(
                localized: "mainwindow.tools.search.help",
                defaultValue: "Open the full-text search window (⌘F)"
            ))

            Divider().frame(height: 20)

            // Cross-reference graph — only when a document is loaded
            Button {
                appState.currentGraphEntry = currentEntry
                openWindow(id: "frus.crossReferenceGraph")
            } label: {
                Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .disabled(currentEntry == nil)
            .help(String(
                localized: "mainwindow.tools.graph.help",
                defaultValue: "Show cross-references for the current document in a separate window"
            ))

            Divider().frame(height: 20)

            // Info / citation popover
            Button {
                showCitationPopover = true
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .disabled(currentEntry == nil)
            .popover(isPresented: $showCitationPopover, arrowEdge: .bottom) {
                if let entry = currentEntry {
                    CitationPopoverView(entry: entry)
                }
            }
            .help(String(
                localized: "mainwindow.tools.info.help",
                defaultValue: "Show document citation and metadata"
            ))

            Divider().frame(height: 20)

            // Research window — annotated documents and tags
            Button {
                openWindow(id: "frus.research")
            } label: {
                Label(String(localized: "mainwindow.tools.research", defaultValue: "Research"),
                      systemImage: "note.text")
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .help(String(
                localized: "mainwindow.tools.research.help",
                defaultValue: "Open the Research window — browse annotated documents by tag (⌘⌥R)"
            ))

            Divider().frame(height: 20)

            // Collections window
            Button {
                openWindow(id: "frus.collections")
            } label: {
                Label("Collections", systemImage: "tray.2")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .help(String(
                localized: "mainwindow.tools.collections.help",
                defaultValue: "Open the Collections window (⇧⌘K)"
            ))

            Divider().frame(height: 20)

            // Corpus browser window
            Button {
                openWindow(id: "frus.corpusBrowser")
            } label: {
                Label("Corpus", systemImage: "books.vertical")
            }
            .help(String(
                localized: "mainwindow.tools.corpus.help",
                defaultValue: "Open the Corpus Browser to browse volumes by subseries"
            ))

            // Analytics window
            Button {
                openWindow(id: "frus.analytics")
            } label: {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }
            .help(String(
                localized: "mainwindow.tools.analytics.help",
                defaultValue: "Open Corpus Analytics — chart term frequency over time"
            ))
        }
    }

}

// MARK: - DocumentPlaceholderView

/// Shown in the document column when no document has been selected yet.
private struct DocumentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a document to begin")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Text("Use Search (⌘F) or open the Corpus Browser (⇧⌘B)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - NARACatalogLookupItem

/// Thin `Identifiable` wrapper used by `MainWindowView` to drive the NARA Catalog Lookup
/// sheet via `.sheet(item:)`.
///
/// Each lookup creates a new instance with a fresh `UUID`. SwiftUI sees a new item
/// identity each time and creates a brand-new `NARACatalogLookupView`, ensuring that
/// `@State(initialValue:)` is honoured and the query field shows the newly selected text.
struct NARACatalogLookupItem: Identifiable {
    let id  = UUID()
    let text: String
}

#endif // os(macOS)
