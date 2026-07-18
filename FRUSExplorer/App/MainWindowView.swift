// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import AppKit

/// The root view of the main document window on macOS.
///
/// ## Layout
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │  Unified titlebar  (toolbar items via .toolbar)     │
/// ├─────────────────────────────────────────────────────┤
/// │                                                     │
/// │  MacDocumentView  (NavigationStack<DocumentBrowser  │
/// │    Entry>) — document column + trailing Research    │
/// │    rail (C1); replaces in-place                     │
/// ├─────────────────────────────────────────────────────┤
/// │  StatusBarView        (index count · task · sync)   │
/// └─────────────────────────────────────────────────────┘
/// ```
///
/// ## Navigation
/// `navigationPath` is owned here so entries can be pushed without `MacDocumentView`
/// knowing its position in the hierarchy. Tool-window navigations arrive via
/// `AppState.pendingBrowseDocument`; every document host translates that into a
/// `routedBrowse` aimed at the last active window (`routeBrowseToActiveHost`), and the
/// host it targets appends the entry to its own path.
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
///   1.3 — Session 2026-06-07: opens frus.analytics on a `pendingAnalytics` handoff
///          (Search's over-cap "Visualize in Corpus Analytics" suggestion); mirrors
///          the existing `pendingSearch` → frus.search window-opening observer
///   1.4 — Word Cloud fixes: pendingWordCloud is now consumed and cleared by
///          WordCloudWindowContent, so repeated hand-offs to an identical scope
///          reopen the window instead of being dropped by `.onChange`
///   1.5 — Session 2026-07-04 (macOS UI audit B3/B4): NARA Catalog Lookup sheet
///          replaced by the Source Explorer window's NARA Lookup segment
///          (`pendingNARALookup` hand-off); Citation Lookup sheet replaced by the
///          frus.citationLookup Window scene, which owns ⌘⇧F itself
@MainActor
struct MainWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    /// Whether this (main) window is key — drives `activeDocumentHost` so tool-window navigation
    /// routes back here when the user launched the tool from the main window.
    @Environment(\.controlActiveState) private var controlActiveState

    /// The document navigation stack. Empty path = no document loaded (welcome placeholder).
    @State private var navigationPath: [DocumentBrowserEntry] = []
    /// Shared research-panel visibility (⌘⇧R) — the C2 titlebar rail toggle writes the same
    /// `@AppStorage` key the mounted rail reads (MacDocumentView / MacDocumentWindowView), so the
    /// toolbar toggle and the rail stay in lock-step.
    @AppStorage("frus.document.researchPanel.visible") private var researchPanelVisible = true

    /// Shared highlight state passed to MacDocumentView (text selection, floating selection bar, and SwiftData insertion).
    @State private var highlightCoordinator = HighlightCoordinator()

    // MARK: - Computed

    private var currentEntry: DocumentBrowserEntry? {
        navigationPath.last
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // The research strip is retired (Research-rail C1) — the per-document research surface
            // is now the trailing rail mounted inside MacDocumentView. The rail-toggle affordance
            // moves into `trailingTools` in the C2 titlebar collapse; until then ⌘⇧R toggles it.

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
        // Translate every tool-window navigation (search, cross-reference graph, corpus browser,
        // related, history, …) into a routed navigation aimed at the last active document window,
        // instead of always hijacking this main window. Every open document host runs the same
        // translation (see `routeBrowseToActiveHost`); the clear-first step keeps it exactly-once, so
        // producers stay window-agnostic and the translation survives even if this window is closed.
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard entry != nil else { return }
            appState.routeBrowseToActiveHost()
        }
        // Track this window as the active document host while it is key.
        .onChange(of: controlActiveState, initial: true) { _, state in
            if state == .key {
                appState.activeDocumentHost = .main
                #if DEBUG
                print("[MainWindowView] active document host → .main")
                #endif
            }
        }
        // Consume a tool-window navigation routed to the main window.
        .onChange(of: appState.routedBrowse) { _, routed in
            guard let routed, routed.host == .main else { return }
            navigationPath.append(routed.entry)
            appState.routedBrowse = nil
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
            bringMacWindowToFront(id: "frus.search")
        }
        // Open the Corpus Analytics window when a cross-view pendingAnalytics
        // arrives (Search's "Visualize in Corpus Analytics" over-cap suggestion).
        // AnalyticsView itself observes pendingAnalytics, applies the parameters,
        // and clears it — so both observers don't race (mirrors pendingSearch).
        .onChange(of: appState.pendingAnalytics) { _, params in
            guard params != nil else { return }
            openWindow(id: "frus.analytics")
            bringMacWindowToFront(id: "frus.analytics")
        }
        // Open the Word Cloud window when a cross-view pendingWordCloud arrives.
        // WordCloudWindowContent applies the scope and clears pendingWordCloud
        // (mirroring pendingSearch), so a later hand-off to the *same* scope is
        // still an Equatable change and re-fires this observer.
        .onChange(of: appState.pendingWordCloud) { _, scope in
            guard scope != nil else { return }
            openWindow(id: "frus.wordcloud")
            bringMacWindowToFront(id: "frus.wordcloud")
        }
        // Citation Lookup (⌘⇧F) is the frus.citationLookup Window scene (UI audit
        // B4) — no sheet here; the scene shortcut opens it directly.
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
        Group {
            if let entry = currentEntry {
                // Condensed "volumeId/documentId" identifier (e.g.
                // "frus1977-1980v28/d217") in place of the previous two-line
                // header + volume-title stack. This keeps the centred toolbar
                // item compact at a fixed width regardless of how long the
                // document's prose header or volume title happen to be —
                // leaving the leading back button and the five trailing tool
                // launchers (Search / Browse / Analytics ▾ / My Research ▾ /
                // rail toggle, C2) enough room that they no longer collapse into
                // the system overflow chevron at typical window widths. As the
                // centred .principal item it also yields (truncates) first under
                // width pressure, before the trailing tools. ("Info" was removed in
                // Session 2026-06-08 — it duplicated ResearchStripView's "Cite"
                // button, which presents the identical CitationPopoverView and
                // is always visible rather than tucked in the toolbar.)
                Text(entry.id)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(entry.header.isEmpty ? entry.documentId : entry.header)
            } else {
                Text("FRUS Explorer")
                    .font(.system(size: 13, weight: .medium))
            }
        }
    }

    // MARK: - Trailing Tools

    private var trailingTools: some View {
        HStack(spacing: 6) {

            // Search — shortcut owned by the "frus.search" Window scene (⌘F)
            Button {
                openWindow(id: "frus.search")
            } label: {
                Label(String(localized: "mainwindow.tools.search", defaultValue: "Search"),
                      systemImage: "magnifyingglass")
            }
            .help(String(localized: "mainwindow.tools.search.help",
                         defaultValue: "Open the full-text search window (⌘F)"))

            Divider().frame(height: 20)

            // Browse (was "Corpus") — shortcut owned by the "frus.corpusBrowser" scene (⌘⇧B)
            Button {
                openWindow(id: "frus.corpusBrowser")
            } label: {
                Label(String(localized: "mainwindow.tools.browse", defaultValue: "Browse"),
                      systemImage: "books.vertical")
            }
            .help(String(localized: "mainwindow.tools.browse.help",
                         defaultValue: "Browse volumes by subseries in the Corpus Browser (⌘⇧B)"))

            Divider().frame(height: 20)

            // Analytics — Corpus / Person / Cross-Reference analytics · Chronology · Word Cloud
            Menu {
                Button { openWindow(id: "frus.analytics") } label: {
                    Label(String(localized: "mainwindow.tools.corpusAnalytics",
                                 defaultValue: "Corpus Analytics"), systemImage: "chart.bar.xaxis")
                }
                Button {
                    openWindow(id: "frus.personAnalytics")
                    bringMacWindowToFront(id: "frus.personAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.personAnalytics",
                                 defaultValue: "Person Analytics"), systemImage: "person.2")
                }
                Button {
                    openWindow(id: "frus.crossRefAnalytics")
                    bringMacWindowToFront(id: "frus.crossRefAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.crossRefAnalytics",
                                 defaultValue: "Cross-Reference Analytics"), systemImage: "square.grid.3x3")
                }
                Divider()
                Button { openWindow(id: "frus.chronology") } label: {
                    Label(String(localized: "mainwindow.tools.chronology",
                                 defaultValue: "Chronology"), systemImage: "calendar.day.timeline.left")
                }
                Button {
                    appState.pendingWordCloud = .corpus
                    openWindow(id: "frus.wordcloud")
                } label: {
                    Label { Text(String(localized: "mainwindow.tools.wordcloud", defaultValue: "Word Cloud")) }
                        icon: { Image(systemName: WordCloudGlyph.symbol) }
                }
            } label: {
                Label(String(localized: "mainwindow.tools.analytics", defaultValue: "Analytics"),
                      systemImage: "chart.bar.xaxis")
            }
            .menuIndicator(.hidden)
            .help(String(localized: "mainwindow.tools.analytics.menu.help",
                         defaultValue: "Corpus, Person, and Cross-Reference analytics, Chronology, and Word Cloud"))

            Divider().frame(height: 20)

            // My Research — Research window (⌘⌥R) and Collections (⌘⇧K). The Window scenes own the
            // shortcuts; the menu items carry them for discoverability in the dropdown.
            Menu {
                Button { openWindow(id: "frus.research") } label: {
                    Label(String(localized: "mainwindow.tools.research", defaultValue: "Research"),
                          systemImage: "note.text")
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                Button { openWindow(id: "frus.collections") } label: {
                    Label(String(localized: "mainwindow.tools.collections", defaultValue: "Collections"),
                          systemImage: "tray.2")
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            } label: {
                Label(String(localized: "mainwindow.tools.myResearch", defaultValue: "My Research"),
                      systemImage: "note.text")
            }
            .menuIndicator(.hidden)
            .help(String(localized: "mainwindow.tools.myResearch.help",
                         defaultValue: "Research window (⌘⌥R) and Collections (⇧⌘K)"))

            Divider().frame(height: 20)

            // Research-panel rail toggle — flips the shared key the mounted rail reads. ⌘⇧R lives on
            // the Document menu, so this button only names it in the tooltip (no redeclaration).
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { researchPanelVisible.toggle() }
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(researchPanelVisible ? Color.accentColor : Color.secondary)
                    .padding(4)
                    .background(researchPanelVisible ? Color.accentColor.opacity(0.12) : .clear,
                                in: RoundedRectangle(cornerRadius: 6))
            }
            .disabled(currentEntry == nil)
            .help(String(localized: "researchRail.toggle.help",
                         defaultValue: "Research panel (⌘⇧R)"))
            .accessibilityLabel(String(localized: "researchRail.toggle.a11y",
                                       defaultValue: "Research panel"))
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

/// Thin `Identifiable` wrapper used by `SourceExplorerWindowView` to key its embedded
/// `NARACatalogLookupView` (the NARA Lookup segment, UI audit B3).
///
/// Each hand-off creates a new instance with a fresh `UUID`. SwiftUI sees a new view
/// identity each time (via `.id`) and creates a brand-new `NARACatalogLookupView`,
/// ensuring that `@State(initialValue:)` is honoured and the query field shows the
/// newly selected text. (Originally the `.sheet(item:)` item for the modal lookup
/// sheets `MainWindowView` and `MacDocumentWindowView` carried before B3.)
struct NARACatalogLookupItem: Identifiable {
    let id  = UUID()
    let text: String
    /// The enclosing footnote body for a footnote selection (#269), forwarded to
    /// `NARACatalogLookupView` for its candidate-citation scan; `nil` otherwise.
    var blockContext: String? = nil
}

// MARK: - Window foregrounding

/// Brings an already-open SwiftUI `Window(id:)` scene to the foreground.
///
/// `openWindow(id:)` reliably *creates* a closed singleton window (and a freshly created
/// window comes forward on its own), but it does not always re-raise a window that is
/// already open behind another one. That gap shows up in cross-window hand-offs — e.g.
/// Corpus Analytics → Search — where the parameters fire into a Search window that stays
/// buried behind the window the user is looking at. Calling this immediately after
/// `openWindow(id:)` activates the app and raises the matching window, so the handed-off
/// window always surfaces (rather than spawning a duplicate, which singleton `Window`
/// scenes cannot do anyway).
///
/// SwiftUI assigns each `Window(id:)` scene's `NSWindow.identifier` from the scene id, so
/// we match on that (with a prefix fallback for any suffix SwiftUI appends). It is a safe
/// no-op when no window matches — the just-issued `openWindow(id:)` has already created or
/// raised the window in that case.
@MainActor
func bringMacWindowToFront(id: String) {
    NSApplication.shared.activate()
    let target = NSApplication.shared.windows.first { window in
        guard let raw = window.identifier?.rawValue else { return false }
        return raw == id || raw.hasPrefix(id)
    }
    target?.makeKeyAndOrderFront(nil)
}

#endif // os(macOS)
