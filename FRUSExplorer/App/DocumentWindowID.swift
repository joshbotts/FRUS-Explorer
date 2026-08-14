// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Typed identifier for iPadOS Stage Manager document windows.
///
/// Passed to `WindowGroup(for: DocumentWindowID.self)` so SwiftUI can
/// open and restore individual document windows on M-chip iPads running
/// Stage Manager. Each value uniquely identifies one document in the corpus.
///
/// `Codable` conformance lets SwiftUI persist and restore window state
/// across scene lifecycle events (backgrounding, system kills, etc.).
///
/// ## Identity
/// Equality and hashing are deliberately keyed on `(volumeId, documentId)` only —
/// `header` is a display placeholder, not part of the document's identity. SwiftUI
/// reuses an existing window when the presented value compares equal, so without
/// this the *same* document opened with a different placeholder header (e.g. from a
/// search result vs. a cross-reference tap, which build entries with different
/// header strings) would wrongly spawn a duplicate window instead of focusing the
/// one already open.
struct DocumentWindowID: Codable, Hashable {
    var volumeId: String
    var documentId: String
    /// Placeholder heading shown in the window title bar while the document loads.
    /// Not part of the value's identity — see the `Equatable`/`Hashable` note above.
    var header: String
    /// Non-identity display payload (provenance PR 2): carried so a window minted from a full
    /// `DocumentBrowserEntry` renders the same document chrome as a routed open, instead of a thin
    /// 3-field reconstruction. Wired at the sites where a full entry is in scope: the D3 mint tail
    /// (`AppState.openDocument`/`routeLegacyPendingBrowse` + the Handoff/Spotlight tail), the host
    /// drain closures, File ▸ Open Document in New Window, and Search's Open-in-New-Window. (Citation
    /// Lookup's per-result windows stay thin — `CitationMatch` has no richer payload to carry.)
    /// Optionals decode cleanly from pre-widening restoration payloads (the GraphWindowRequest pattern).
    var documentNumber: String? = nil
    /// Dateline string, if the minting surface had one.
    var dateline: String? = nil
    /// Source note, if the minting surface had one.
    var sourceNote: String? = nil
    /// Whether the entry is a FRUS editorial note (nil = unknown → treated as a document).
    var isEditorialNote: Bool? = nil

    /// Builds the id from a full `DocumentBrowserEntry`, preserving its display payload.
    init(entry: DocumentBrowserEntry) {
        self.volumeId = entry.volumeId
        self.documentId = entry.documentId
        self.header = entry.header
        self.documentNumber = entry.documentNumber
        self.dateline = entry.dateline
        self.sourceNote = entry.sourceNote
        self.isEditorialNote = entry.isEditorialNote
    }

    /// Memberwise-style init for the pre-widening 3-field call sites.
    init(volumeId: String, documentId: String, header: String) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.header = header
    }

    /// The `DocumentBrowserEntry` this window renders at its root.
    var rootEntry: DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: documentId, volumeId: volumeId, documentNumber: documentNumber,
            header: header, dateline: dateline, sourceNote: sourceNote,
            isEditorialNote: isEditorialNote ?? false)
    }

    static func == (lhs: DocumentWindowID, rhs: DocumentWindowID) -> Bool {
        lhs.volumeId == rhs.volumeId && lhs.documentId == rhs.documentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(volumeId)
        hasher.combine(documentId)
    }
}

// MARK: - DocumentHostID / RoutedBrowse (macOS per-window navigation routing)

/// Identifies which document-hosting window a tool-window navigation should land in: a specific
/// main window, or a specific standalone document window (`MacDocumentWindowView`). Used so a
/// document selected in a tool window (search, cross-reference graph, corpus browser, …) opens in
/// the window the user launched the tool from — its **provenance host** — instead of whichever
/// window happened to be active (`Planning/Completed/Window-Routing-Provenance.md`).
///
/// Every ⌘N main window mints its own per-instance token (session-scoped `@State` UUID — owner
/// decision D4), so two main windows are distinct routing targets; the pre-provenance design's
/// shared `.main` identity (and its whichever-observer-runs-first consumption race) is retired.
enum DocumentHostID: Hashable {
    /// One specific `MainWindowView` instance, keyed by its session-scoped identity token.
    case main(UUID)
    /// A standalone document window, keyed by its `DocumentWindowID`.
    case window(DocumentWindowID)
}

/// A tool-window document selection routed to a specific `DocumentHostID`. The matching host
/// consumes it (appends `entry` to its navigation path, fronts itself) and clears it. macOS only —
/// iOS routes through `AppState.pendingBrowseDocument`.
struct RoutedBrowse: Equatable {
    /// The window that should receive the navigation (the producer's provenance host, resolved
    /// against the live-host registry at delivery time).
    let host: DocumentHostID
    /// The document to open there.
    let entry: DocumentBrowserEntry
}

// MARK: - ToolWindowID / DocumentOpenSource (provenance routing vocabulary)

/// A tool surface whose document opens are routed to a provenance host (macOS).
///
/// Singleton `Window` scenes get one case each — every explicit launch **re-binds** their
/// provenance (last-spawner-wins; merely focusing the window never re-binds). Value-based
/// `WindowGroup` scenes are keyed per-instance by their request value, which is also how SwiftUI
/// identifies the window itself. Citation Lookup is deliberately absent: its result taps always
/// mint standalone document windows (#239 — owner decision D2 blessed the exception), so it never
/// routes and spawns no tools.
enum ToolWindowID: Hashable {
    case search
    case corpusBrowser
    case graph
    case sourceExplorer
    case analytics
    case personAnalytics
    case crossRefAnalytics
    case archivalAnalytics
    /// The Semantic Analytics window (`frus.semanticAnalytics`) — the map, its lenses and slices.
    case semanticAnalytics
    case wordCloud
    case chronology
    case research
    case people
    case history
    case archivalNeighbors(ArchivalNeighborsRequest)
    case relatedDocuments(RelatedDocumentsRequest)
    case crossVolumeProvenance(CrossVolumeProvenanceRequest)
}

/// Who is asking `AppState.openDocument(_:from:mintWindow:)` to open a document.
enum DocumentOpenSource {
    /// A tool window — resolved through its (transitive) provenance binding.
    case tool(ToolWindowID)
    /// A launcher with no spawning window (History menu, Handoff/Spotlight, scene shortcuts) —
    /// resolved straight through the fallback chain (owner decision D3).
    case global
}

#if os(macOS)

// MARK: - documentHostID environment (provenance plumbing)

private struct DocumentHostIDEnvironmentKey: EnvironmentKey {
    static let defaultValue: DocumentHostID? = nil
}

extension EnvironmentValues {
    /// The identity of the document-hosting window this view is mounted in, set at each host root
    /// (`MainWindowView`, `MacDocumentWindowView`). Launchers anywhere inside a host (rail tiles,
    /// titlebar buttons, sheets) read it to stamp tool provenance — the launcher never needs to
    /// know which window it lives in. `nil` outside a document host (tool windows resolve their
    /// provenance from `AppState.toolProvenance` instead).
    var documentHostID: DocumentHostID? {
        get { self[DocumentHostIDEnvironmentKey.self] }
        set { self[DocumentHostIDEnvironmentKey.self] = newValue }
    }
}

// MARK: - HostWindowAccessor (reliable close signal + fronting)

/// Captures the `NSWindow` hosting a document-host view and reports `willClose` — the reliable
/// close signal host deregistration rides on (`onDisappear` is a known-unreliable close proxy in
/// this codebase: popped `MacDocumentView`s are retained). Mount via `.background(...)`; the
/// captured window also lets the `.main` consumer front itself on a routed delivery (FM-G).
struct HostWindowAccessor: NSViewRepresentable {
    /// Called (async, post-mount) with the hosting window, and again with `nil` on `willClose`.
    var onWindow: (NSWindow?) -> Void
    /// Called exactly once when the hosting window is about to close.
    var onWillClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onWindow: onWindow, onWillClose: onWillClose) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            context.coordinator.attach(to: view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The window can attach after makeNSView (SwiftUI mounts the view tree before the window
        // exists during scene creation) — re-check on update until captured.
        if context.coordinator.window == nil {
            DispatchQueue.main.async { [weak nsView] in
                context.coordinator.attach(to: nsView?.window)
            }
        }
    }

    @MainActor final class Coordinator {
        let onWindow: (NSWindow?) -> Void
        let onWillClose: () -> Void
        private(set) weak var window: NSWindow?
        /// The willClose registration. Stored (not captured by the handler as a mutable local —
        /// that pattern trips three strict-concurrency warnings and retains an observer→block→box
        /// cycle) and removed inside the handler, so nothing non-Sendable reaches the nonisolated
        /// deinit. `nonisolated(unsafe)` is sound: every touch happens on the main actor
        /// (willClose posts on the main thread and delivery is `queue: .main`).
        nonisolated(unsafe) private var willCloseToken: NSObjectProtocol?

        init(onWindow: @escaping (NSWindow?) -> Void, onWillClose: @escaping () -> Void) {
            self.onWindow = onWindow
            self.onWillClose = onWillClose
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            self.window = window
            onWindow(window)
            // Re-attach (the view landing in a second window) drops the stale registration first.
            if let stale = willCloseToken {
                NotificationCenter.default.removeObserver(stale)
                willCloseToken = nil
            }
            willCloseToken = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let token = self.willCloseToken {
                        NotificationCenter.default.removeObserver(token)
                        self.willCloseToken = nil
                    }
                    self.onWindow(nil)
                    self.onWillClose()
                }
            }
        }
    }
}

#endif // os(macOS)

// MARK: - SourceExplorerRequest

/// Value-based request describing which document's source note the iPad Source Explorer
/// window shows (#317).
///
/// Passed to `WindowGroup(for: SourceExplorerRequest.self)` so the `.ios` Source Explorer scene
/// restores CORRECTLY after backgrounding / a system kill: the payload fully describes the
/// content, so SwiftUI rebuilds the window from the restored value with no `AppState` hand-off.
/// The old id-based scene read the process-global `currentSourceNote` + 5 siblings, which died
/// with the process and left a restored window blank. Same pattern as `DocumentWindowID` and the
/// `ArchivalNeighborsRequest` scene ported in #241.
///
/// Identity is the full payload (each distinct source note / document gets its own window),
/// matching the multi-instance value-based behaviour of the Archival Neighbors window.
struct SourceExplorerRequest: Codable, Hashable, Sendable {
    /// The raw source-note XML the Source Explorer parses.
    var rawSourceNote: String
    /// Coverage year parsed from the dateline, seeding NARA finding-aid period routing.
    var documentYear: Int?
    /// Document heading, for display.
    var documentHeader: String?
    /// Document dateline, for display.
    var documentDateline: String?
    /// The document's volume id.
    var documentVolumeId: String?
    /// The document's `xml:id`.
    var documentId: String?
}

// MARK: - GraphWindowRequest

/// Value-based request describing which document's cross-reference graph the iPad graph window
/// shows (#317).
///
/// Passed to `WindowGroup(for: GraphWindowRequest.self)` so the `.ios` graph scene restores
/// correctly — the old id-based scene read the process-global `currentGraphEntry`, which died
/// with the process. Carries the `DocumentBrowserEntry` display fields so the graph rebuilds from
/// the value; the cross-reference store, manifest, and download state stay read from `AppState`
/// inside the scene (live services, not restorable payload).
///
/// ## Identity
/// Like `DocumentWindowID`, equality/hashing key on `(volumeId, documentId)` ONLY — the display
/// fields are not identity, so reopening the *same* document's graph focuses its existing window
/// rather than spawning a duplicate when a different entry-source supplies a different
/// header/sourceNote. Note this is a deliberate behaviour change from the old id-based scene,
/// which was a *single* window that retargeted via `.id(entry.id)`: value-based windows are
/// one-per-document, so graphs for different documents now open side by side (the
/// `DocumentWindowID` document-window model). The scene's `.id(request.entry.id)` is therefore
/// redundant now — identity is frozen per window — but harmless.
struct GraphWindowRequest: Codable, Hashable, Sendable {
    /// The document's `xml:id`.
    var documentId: String
    /// The document's volume id.
    var volumeId: String
    /// Printed document number, if present.
    var documentNumber: String?
    /// Document heading / title line.
    var header: String
    /// Dateline string, if present.
    var dateline: String?
    /// Source note, if present.
    var sourceNote: String?
    /// Whether the entry is a FRUS editorial note rather than a primary-source document.
    var isEditorialNote: Bool

    /// Flattens a `DocumentBrowserEntry` into the restorable payload.
    init(entry: DocumentBrowserEntry) {
        documentId = entry.documentId
        volumeId = entry.volumeId
        documentNumber = entry.documentNumber
        header = entry.header
        dateline = entry.dateline
        sourceNote = entry.sourceNote
        isEditorialNote = entry.isEditorialNote
    }

    /// Rebuilds the `DocumentBrowserEntry` the graph view renders.
    var entry: DocumentBrowserEntry {
        DocumentBrowserEntry(
            documentId: documentId, volumeId: volumeId, documentNumber: documentNumber,
            header: header, dateline: dateline, sourceNote: sourceNote,
            isEditorialNote: isEditorialNote
        )
    }

    static func == (lhs: GraphWindowRequest, rhs: GraphWindowRequest) -> Bool {
        lhs.volumeId == rhs.volumeId && lhs.documentId == rhs.documentId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(volumeId)
        hasher.combine(documentId)
    }
}
