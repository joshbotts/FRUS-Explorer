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
@MainActor
struct MainWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    /// The document navigation stack. Empty path = no document loaded (welcome placeholder).
    @State private var navigationPath: [DocumentBrowserEntry] = []

    /// Controls collapsing of the research strip.
    @State private var isResearchStripCollapsed: Bool = false

    /// Whether the citation popover is showing.
    @State private var showCitationPopover: Bool = false

    // MARK: - Computed

    private var currentEntry: DocumentBrowserEntry? {
        navigationPath.last
    }

    // MARK: - Body

    var body: some View {
        @Bindable var appStateBindable = appState

        VStack(spacing: 0) {

            // Research strip — always rendered; the strip itself handles its
            // collapsed/expanded display state via isCollapsed binding.
            // When collapsed, it shows only a "+" re-expand button at 32pt height.
            ResearchStripView(
                entry: currentEntry,
                isCollapsed: $isResearchStripCollapsed,
                showCitationPopover: $showCitationPopover
            )

            // Document body — NavigationStack owns the back/forward history.
            NavigationStack(path: $navigationPath) {
                DocumentPlaceholderView()
                    .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                        MacDocumentView(entry: entry, navigationPath: $navigationPath)
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
        // Open the search window when a cross-view pendingSearch arrives (e.g. "Find all
        // mentions" from PersonDetailSheet). MacSearchWindowView clears pendingSearch after
        // applying the parameters so both observers don't race.
        .onChange(of: appState.pendingSearch) { _, params in
            guard params != nil else { return }
            openWindow(id: "frus.search")
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
        ToolbarItemGroup(placement: .primaryAction) {
            trailingTools
        }
    }

    // MARK: - Document Title (principal toolbar item)

    private var documentTitle: some View {
        VStack(spacing: 1) {
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

            Divider().frame(height: 20)

            // Cross-reference graph — only when a document is loaded
            Button {
                appState.currentGraphEntry = currentEntry
                openWindow(id: "frus.crossReferenceGraph")
            } label: {
                Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .disabled(currentEntry == nil)

            // Source explorer — shown when the current document has a source note
            if let note = currentEntry?.sourceNote, !note.isEmpty {
                Button {
                    appState.currentSourceNote = note
                    openWindow(id: "frus.sourceExplorer")
                } label: {
                    Label("Sources", systemImage: "archivebox")
                }
            }

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

            Divider().frame(height: 20)

            // Collections window
            Button {
                openWindow(id: "frus.collections")
            } label: {
                Label("Collections", systemImage: "tray.2")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Divider().frame(height: 20)

            // Corpus browser window
            Button {
                openWindow(id: "frus.corpusBrowser")
            } label: {
                Label("Corpus", systemImage: "books.vertical")
            }
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

#endif // os(macOS)
