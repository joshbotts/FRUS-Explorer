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
/// knowing its position in the hierarchy. Tool-window navigations arrive as a
/// `routedBrowse` aimed at the producer's provenance host (or, for legacy origin-less
/// producers, via `pendingBrowseDocument` translated through the fallback chain —
/// `routeLegacyPendingBrowse`); the host it targets appends the entry to its own path.
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
///   1.6 — Session 2026-08-09 (#652): **Complete History…** joins the My Research
///          toolbar menu — the History window's only other door is the menu bar's
///          Research ▸ History submenu, which a mouse-driven reader never opens. It is
///          also the first host-bound `.history` provenance producer, so a document
///          re-opened from History now lands in the window it was launched from.
///          Tooltip re-keyed `.v2` (the string's meaning changed, not just its wording).
///   1.7 — Session 2026-08-09 (#795): **Archival Analytics** joins the toolbar Analytics
///          menu. The menu-bar Analytics menu has carried it since the feature shipped;
///          the toolbar menu — the discoverable door — never did. Tooltip re-keyed `.v2`.
@MainActor
struct MainWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    /// Whether this (main) window is key — bumps this host's ADVISORY recency stamp in the
    /// live-host registry (fallback resolution only; provenance routing never samples focus).
    @Environment(\.controlActiveState) private var controlActiveState

    /// This window's session-scoped routing identity (owner decision D4) — each ⌘N main window
    /// mints its own token, so two main windows are distinct provenance hosts.
    @State private var hostToken = UUID()
    /// The `NSWindow` hosting this view (captured by `HostWindowAccessor`) — used to front this
    /// window when a routed navigation lands in it while it is buried or miniaturized (FM-G).
    @State private var hostWindow: NSWindow?

    /// The document navigation stack. Empty path = no document loaded (welcome placeholder).
    @State private var navigationPath: [DocumentBrowserEntry] = []
    /// Shared research-panel visibility (⌘⇧R) — the C2 titlebar rail toggle writes the same
    /// `@AppStorage` key the mounted rail reads (MacDocumentView / MacDocumentWindowView), so the
    /// toolbar toggle and the rail stay in lock-step.
    @AppStorage("frus.document.researchPanel.visible") private var researchPanelVisible = true

    /// Shared highlight state passed to MacDocumentView (text selection, floating selection bar, and SwiftData insertion).
    @State private var highlightCoordinator = HighlightCoordinator()

    /// Measured window content width (≈ titlebar width) and trailing-tools width, driving the
    /// centred identity pill's yield behaviour (see `pillBudget`).
    @State private var contentWidth: CGFloat = 0
    @State private var trailingWidth: CGFloat = 0

    // MARK: - Computed

    /// This window's routing identity — a per-instance provenance host (never the old shared `.main`).
    private var hostID: DocumentHostID { .main(hostToken) }

    /// How wide the centred identity pill is allowed to be before it must yield (truncate, then
    /// hide) so the trailing tool buttons never collapse into the overflow chevron — the handoff's
    /// "identity pill yields first" behaviour, which the default `.principal` layout inverts.
    ///
    /// A centred item reserves SYMMETRIC margins, so the wider of the two flanks bounds it: the
    /// trailing tools (measured) vs the leading traffic-lights + back chrome (~120 pt). The pill may
    /// occupy what's left after mirroring that flank on both sides: `content − 2·max(trailing, 120)`,
    /// minus a little slack. Below ~60 pt it hides entirely rather than showing a useless sliver.
    private var pillBudget: CGFloat {
        guard contentWidth > 0, trailingWidth > 0 else { return 0 }
        return max(0, contentWidth - 2 * max(trailingWidth, 120) - 24)
    }

    private var currentEntry: DocumentBrowserEntry? {
        navigationPath.last
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Measures the window content width (≈ titlebar width) for the pill-yield budget.
            Color.clear.frame(height: 0)
                .background(GeometryReader { proxy in
                    Color.clear
                        .task(id: proxy.size.width) { contentWidth = proxy.size.width }
                })

            // The research strip is retired (Research-rail C1) — the per-document research surface
            // is now the trailing rail mounted inside MacDocumentView, toggled from `trailingTools`
            // (C2a) or ⌘⇧R.

            // Document body — NavigationStack owns the back/forward history.
            NavigationStack(path: $navigationPath) {
                DocumentPlaceholderView { navigationPath.append($0) }
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
        // Provenance plumbing: every launcher mounted in this window (titlebar tools, rail tiles,
        // sheets) reads this window's identity from the environment to stamp tool provenance.
        .environment(\.documentHostID, hostID)
        // Capture the NSWindow (fronting on routed delivery) and ride willClose for reliable
        // host deregistration (onDisappear below is belt-and-braces).
        .background(HostWindowAccessor(
            onWindow: { hostWindow = $0 },
            onWillClose: { appState.unregisterHost(hostID) }
        ))
        .onAppear {
            appState.registerHost(hostID)
            // Drain a legacy navigation written while NO host was mounted (e.g. a search-window
            // click with every document window closed) — registration above makes this host the
            // fallback, so the pending value routes here instead of stranding until the next
            // distinct click (the iOS BrowserView adopt-on-appear discipline).
            appState.routeLegacyPendingBrowse { orphan in
                openWindow(value: DocumentWindowID(entry: orphan))
            }
        }
        .onDisappear { appState.unregisterHost(hostID) }
        // Translate a LEGACY (origin-less, not-yet-migrated) tool-window navigation through the
        // fallback chain. Every open document host runs the same translation; the clear-first step
        // keeps it exactly-once, and it survives any particular window being closed.
        .onChange(of: appState.pendingBrowseDocument) { _, entry in
            guard entry != nil else { return }
            appState.routeLegacyPendingBrowse { orphan in
                openWindow(value: DocumentWindowID(entry: orphan))
            }
        }
        // Bump this host's ADVISORY recency stamp while key — consulted only by the fallback
        // chain (originless opens, dead provenance); provenance routing never samples focus.
        .onChange(of: controlActiveState, initial: true) { _, state in
            if state == .key { appState.hostBecameKey(hostID) }
        }
        // Consume a navigation routed to THIS main window (per-instance identity — no cross-window
        // race). Re-read live state before consuming so a stale captured value can't double-apply,
        // and front the window so a routed delivery is never invisible (FM-G).
        .onChange(of: appState.routedBrowse) { _, routed in
            guard let routed, routed.host == hostID, appState.routedBrowse == routed else { return }
            navigationPath.append(routed.entry)
            appState.routedBrowse = nil
            // makeKeyAndOrderFront does NOT restore a miniaturized window — deminiaturize first
            // or a route into a docked window stays invisible (FM-G's second half).
            if hostWindow?.isMiniaturized == true { hostWindow?.deminiaturize(nil) }
            hostWindow?.makeKeyAndOrderFront(nil)
        }
        // Reset highlight state whenever the user navigates to a different document.
        .onChange(of: currentEntry) { _, _ in
            highlightCoordinator.reset()
        }
        // The pendingSearch / pendingAnalytics / pendingWordCloud opening relays that
        // lived here are retired (provenance PR 2): every macOS producer now opens its
        // target window DIRECTLY (openWindow + bringMacWindowToFront) alongside the
        // hand-off and stamps the tool's provenance — so a hand-off no longer dead-drops
        // when every main window is closed, and tool→tool provenance is exact at each hop.
        // The pending* values themselves survive as the parameter channel each target
        // window consumes and clears.
        //
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
            if let entry = currentEntry, pillBudget >= 60 {
                // Condensed "volumeId/documentId" identifier (e.g. "frus1977-1980v28/d217"). As the
                // centred .principal item it must YIELD before the trailing tools under width
                // pressure (handoff: "the identity pill yields first"). `pillBudget` caps its width
                // so it truncates within the room the tools leave, and below ~60 pt it drops out
                // entirely — freeing the whole flank so the buttons never collapse into the overflow
                // chevron. (Default `.principal` layout inverts this, overflowing the tools first —
                // the bug this replaces.) ("Info" removed Session 2026-06-08 — duplicated the rail's Cite.)
                Text(entry.id)
                    // LEAVE-FIXED (Mac W-11): the identity pill is width-budgeted (`pillBudget`)
                    // and monospaced for grid-stable truncation — the worklist's designated
                    // monospaced-tally carve-out. Scaling it would fight the budget arithmetic.
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: pillBudget)
                    .help(entry.header.isEmpty ? entry.documentId : entry.header)
            } else if currentEntry == nil {
                Text("FRUS Explorer")
                    .font(.body.weight(.medium))
            }
            // A document is open but the window is too narrow to centre the pill without shoving
            // the tools into overflow → render nothing; the tools win the space.
        }
    }

    // MARK: - Trailing Tools

    private var trailingTools: some View {
        HStack(spacing: 6) {

            // Search — shortcut owned by the "frus.search" Window scene (⌘F).
            // Every tool launch below stamps this window's identity as the tool's
            // provenance (bindTool), so the tool's document opens route back HERE.
            Button {
                appState.bindTool(.search, to: hostID)
                appState.searchQueryFocusToken &+= 1   // put the caret in the query field (#749)
                openWindow.fronting(id: "frus.search")
            } label: {
                Label(String(localized: "mainwindow.tools.search", defaultValue: "Search"),
                      systemImage: "magnifyingglass")
            }
            // Handoff: Search stays icon-only (the toolbar's default). Explicit so it holds even
            // though its labelled siblings force `.titleAndIcon`.
            .labelStyle(.iconOnly)
            .help(String(localized: "mainwindow.tools.search.help",
                         defaultValue: "Open the full-text search window (⌘F)"))

            Divider().frame(height: 20)

            // Browse (was "Corpus") — shortcut owned by the "frus.corpusBrowser" scene (⌘⇧B)
            Button {
                appState.bindTool(.corpusBrowser, to: hostID)
                openWindow.fronting(id: "frus.corpusBrowser")
            } label: {
                Label(String(localized: "mainwindow.tools.browse", defaultValue: "Browse"),
                      systemImage: "books.vertical")
            }
            // Owner override of the handoff (2026-07-18): the Corpus Browser button stays
            // icon-only like Search, not a labelled "Browse" button.
            .labelStyle(.iconOnly)
            .help(String(localized: "mainwindow.tools.browse.help",
                         defaultValue: "Browse volumes by subseries in the Corpus Browser (⌘⇧B)"))

            Divider().frame(height: 20)

            // Analytics — Corpus / Person / Cross-Reference / Archival / Semantic analytics ·
            // Chronology · Word Cloud. Membership and ORDER mirror the menu-bar Analytics menu
            // (`AnalyticsMenuContent`) deliberately: #795 is what happens when the two drift.
            Menu {
                Button {
                    appState.bindTool(.analytics, to: hostID)
                    openWindow.fronting(id: "frus.analytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.corpusAnalytics",
                                 defaultValue: "Corpus Analytics"), systemImage: "chart.bar.xaxis")
                }
                Button {
                    appState.bindTool(.personAnalytics, to: hostID)
                    openWindow.fronting(id: "frus.personAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.personAnalytics",
                                 defaultValue: "Person Analytics"), systemImage: "person.2")
                }
                Button {
                    appState.bindTool(.crossRefAnalytics, to: hostID)
                    openWindow.fronting(id: "frus.crossRefAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.crossRefAnalytics",
                                 defaultValue: "Cross-Reference Analytics"), systemImage: "square.grid.3x3")
                }
                // #795: the window has existed since the archival family shipped and the menu-bar
                // Analytics menu has always listed it — this menu never did, so the feature was
                // unreachable from the main window. `hostID`, not `nil`: a toolbar launch binds THIS
                // window as provenance, where the menu bar deliberately clears it (no spawning
                // window → recency fallback).
                Button {
                    appState.bindTool(.archivalAnalytics, to: hostID)
                    openWindow.fronting(id: "frus.archivalAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.archivalAnalytics",
                                 defaultValue: "Archival Analytics"), systemImage: "archivebox")
                }
                Button {
                    appState.bindTool(.semanticAnalytics, to: hostID)
                    openWindow.fronting(id: "frus.semanticAnalytics")
                } label: {
                    Label(String(localized: "mainwindow.tools.semanticAnalytics",
                                 defaultValue: "Semantic Analytics"),
                          systemImage: SemanticGlyph.feature)
                }
                Divider()
                Button {
                    appState.bindTool(.chronology, to: hostID)
                    openWindow.fronting(id: "frus.chronology")
                } label: {
                    Label(String(localized: "mainwindow.tools.chronology",
                                 defaultValue: "Chronology"), systemImage: "calendar.day.timeline.left")
                }
                Button {
                    appState.openWordCloud(.corpus, from: nil)   // #338: macOS singleton window
                    appState.bindTool(.wordCloud, to: hostID)
                    openWindow.fronting(id: "frus.wordcloud")
                } label: {
                    Label { Text(String(localized: "mainwindow.tools.wordcloud", defaultValue: "Word Cloud")) }
                        icon: { Image(systemName: WordCloudGlyph.symbol) }
                }
            } label: {
                Label(String(localized: "mainwindow.tools.analytics", defaultValue: "Analytics"),
                      systemImage: "chart.bar.xaxis")
            }
            // Handoff: "Analytics menu (▾)" — visible name + the default disclosure chevron.
            .labelStyle(.titleAndIcon)
            // `.v3`: the menu gained Semantic Analytics, so the string's meaning changed again — a
            // new key, not an edit under the old one. This lagged one release behind its iOS twin
            // (`browse.analysisTools.help`), which is the same drift #795 is cited for three lines
            // below, so the entry-point suite now pins both.
            .help(String(localized: "mainwindow.tools.analytics.menu.help.v3",
                         defaultValue: "Corpus, Person, Cross-Reference, Archival, and Semantic analytics, Chronology, and Word Cloud"))

            Divider().frame(height: 20)

            // My Research — Research window (⌘⌥R), Collections (⌘⇧K), and Complete History. The key
            // equivalents live solely on the Research command menu (#363 #2 — they were previously
            // ALSO declared here, a duplicate binding); these buttons keep the click action and name
            // the shortcut in the menu-bar Research menu + the tooltip below for discoverability.
            // History is the one item here with no key equivalent at all.
            Menu {
                Button {
                    appState.bindTool(.research, to: hostID)
                    openWindow.fronting(id: "frus.research")
                } label: {
                    Label(String(localized: "mainwindow.tools.research", defaultValue: "Research"),
                          systemImage: "note.text")
                }
                // Collections never routes document opens — no provenance bind.
                Button { openWindow.fronting(id: "frus.collections") } label: {
                    Label(String(localized: "mainwindow.tools.collections", defaultValue: "Collections"),
                          systemImage: "tray.2")
                }
                // Archive Visits (Phase 3, §4a) — like Collections, never routes document
                // opens, so no provenance bind.
                Button { openWindow.fronting(id: "frus.archiveVisits") } label: {
                    Label(String(localized: "mainwindow.tools.archiveVisits",
                                 defaultValue: "Archive Visits"),
                          systemImage: "building.columns")
                }
                // #652: the History window's second door. Until now it was reachable only from the
                // menu bar (Research ▸ History ▸ Complete History…), which a reader working with the
                // mouse never opens — the same discoverability gap #795 records for Archival
                // Analytics one menu to the left.
                //
                // This is the FIRST host-bound `.history` producer. Binding it matters: HistoryView
                // resolves `provenance(of: .history)` when it re-opens a document and when it hands a
                // recalled search back to Search, and that lookup has always resolved nil because
                // nothing ever bound the tool. A document re-opened from History now lands in the
                // window the History window was launched from, instead of falling through to the
                // recency chain.
                Button {
                    appState.bindTool(.history, to: hostID)
                    openWindow.fronting(id: "frus.history")
                } label: {
                    Label(String(localized: "menu.history.completeHistory",
                                 defaultValue: "Complete History\u{2026}"),
                          systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Label(String(localized: "mainwindow.tools.myResearch", defaultValue: "My Research"),
                      systemImage: "note.text")
            }
            // Handoff: "My Research menu (▾)" — visible name + the default disclosure chevron.
            .labelStyle(.titleAndIcon)
            // `.v3`: the string names a fourth window now, so its meaning changed — reusing the
            // old key with new text is a silent i18n collision, the failure this repo versions
            // around (`.v2` was minted for the same reason when History joined).
            .help(String(localized: "mainwindow.tools.myResearch.help.v3",
                         defaultValue: "Research window (⌘⌥R), Collections (⇧⌘K), Archive Visits, and Complete History"))

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
            .accessibilityIdentifier("researchRailToggle")
        }
        // Measure the trailing tools' natural width so the centred pill can size itself to never
        // push them into overflow (the pill-yields-first budget).
        .background(GeometryReader { proxy in
            Color.clear
                .task(id: proxy.size.width) { trailingWidth = proxy.size.width }
        })
    }

}

// MARK: - DocumentPlaceholderView

/// Shown in the document column when no document has been selected yet.
private struct DocumentPlaceholderView: View {

    /// Opens the resumed document in this window's stack (#754).
    let onResume: (DocumentBrowserEntry) -> Void

    /// Hero-glyph scaling (Mac W-11): tracks the text-size setting, capped so an
    /// accessibility size does not blow the empty state off the column.
    @ScaledMetric(relativeTo: .largeTitle) private var heroGlyphSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: FRUSTheme.cappedGlyphSize(heroGlyphSize, base: 40)))
                .foregroundStyle(.tertiary)
            Text("Select a document to begin")
                .font(.title3)
                .foregroundStyle(.secondary)
            // ⌘S, not ⌘F: Search moved to ⌘S in #363 #5 and ⌘F became Find in Document. This
            // string kept the old shortcut — the same stale claim #749 corrected in the manual,
            // still wrong in the app itself.
            Text("Use Search (⌘S) or open the Corpus Browser (⇧⌘B)")
                .font(.callout)
                .foregroundStyle(.tertiary)

            // #754: resume the last document read, offered rather than auto-opened.
            ResumeReadingRow { entry in
                onResume(entry)
            }
            .padding(.top, 8)
            .frame(maxWidth: 420)
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

extension OpenWindowAction {

    /// Opens a singleton `Window(id:)` scene **and** raises it if it was already open (#749).
    ///
    /// Use this instead of `openWindow(id:)` for every singleton tool window. The two calls are not
    /// independent choices — `openWindow(id:)` alone leaves an already-open window buried, per the
    /// measured gap documented on ``bringMacWindowToFront(id:)`` — so pairing them by hand at every
    /// site is a rule that gets forgotten, and was: the 2026-08 navigation audit found **11 of 56
    /// sites** unpaired, including seven of the nine main-window toolbar launchers.
    ///
    /// The consequences were worse than a dead button, because several tool windows retarget their
    /// content from shared state the moment a producer writes it, visible or not. A buried Word
    /// Cloud silently lost the volume or collection scope the researcher had set up; a buried
    /// Cross-Reference Graph silently switched to a different document, so bringing it forward later
    /// showed someone else's graph with no explanation.
    ///
    /// Making the pair a single call is the point: there is no longer a second step to omit.
    /// `MacWindowFrontingTests` fails the suite if a bare `openWindow(id:)` reappears.
    @MainActor
    func fronting(id: String) {
        self(id: id)
        bringMacWindowToFront(id: id)
    }

    /// Opens a value-based `WindowGroup(id:for:)` scene **and** raises it if already open (#824).
    ///
    /// The id-only overload above cannot serve these: `openWindow(id:)` does not match a scene that
    /// takes a value. Without this pair, moving a window out of the macOS Window menu — which means
    /// becoming a `WindowGroup` — would silently forfeit the #749 fronting guarantee, and choosing
    /// the item again while its window sat buried would appear to do nothing. That is the exact
    /// defect #749 fixed at 11 of 56 call sites, so it is not a hypothetical.
    func fronting<V: Codable & Hashable>(id: String, value: V) {
        self(id: id, value: value)
        bringMacWindowToFront(id: id)
    }
}

#endif // os(macOS)
