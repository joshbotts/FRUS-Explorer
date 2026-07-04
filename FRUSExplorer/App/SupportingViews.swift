// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - HighlightCoordinator

/// Shared observable state for the document highlight workflow on macOS.
///
/// Owned by `MainWindowView` and passed by reference to both `ResearchStripView`
/// (which hosts the toolbar buttons) and `MacDocumentView` (which performs text
/// selection and SwiftData insertion). Resetting on document navigation is handled
/// by `MainWindowView.onChange(of: currentEntry)`.
@Observable
/// Shared observable state for the document highlight workflow on macOS.
///
/// Owned by `MainWindowView` and passed by reference to both `ResearchStripView`
/// (which hosts the toolbar buttons) and `MacDocumentView` (which performs text
/// selection and SwiftData insertion). Resetting on document navigation is handled
/// by `MainWindowView.onChange(of: currentEntry)`.
///
/// Session 147: removed `showHighlightMode`, `highlightTextSelection`, and
/// `createHighlightAction` — the WebKit renderer uses `webKitSelectionRange` instead.
///
/// Authoring Phase 5 review fixes: `currentRenderingVersion` removed in favour of
/// `makeExcerptCaptureAction` — MacDocumentView builds the whole excerpt capture,
/// re-extracting the frozen passage from the flat text next to its anchors.
final class HighlightCoordinator {

    /// WebKit selection range — `(start, end)` Unicode-scalar offsets.
    /// Non-nil when the user has an active selection in `FRUSDocumentWebView`.
    /// Cleared after a highlight is created or the selection is collapsed.
    var webKitSelectionRange: (Int, Int)? = nil

    /// The raw text of the current WebKit selection, as reported by
    /// `window.getSelection().toString()`. Pre-populates the NARA Catalog lookup field.
    var webKitSelectedText: String? = nil

    /// Called by `MacDocumentView` to create a `DocumentHighlight` from the
    /// WebKit selection range and colour chosen in `highlightColorPicker`.
    var createWebKitHighlightAction: ((DocumentHighlight.Color) -> Void)? = nil

    /// Builds an excerpt capture from the current selection (Authoring Phase 5).
    /// Registered by `MacDocumentView` — which owns the render model — so the frozen
    /// passage is re-extracted block-aware from the flat text alongside its offsets
    /// and rendering version (decision A9), never frozen from the raw
    /// `sel.toString()` string (which includes `data-skip` footnote-marker digits
    /// the offsets exclude). Returns `nil` when no selection text is available.
    var makeExcerptCaptureAction: (() -> CollectionExcerptCapture?)? = nil

    /// The `DocumentHighlight.id` of the most recently created highlight.
    /// Non-nil while the "Add Note to Highlight" button should be enabled.
    var pendingHighlightLink: UUID? = nil

    func reset() {
        webKitSelectionRange = nil
        webKitSelectedText   = nil
        pendingHighlightLink = nil
        createWebKitHighlightAction = nil
        makeExcerptCaptureAction = nil
    }
}

// MARK: - ResearchStripView

/// Persistent research action toolbar displayed between the titlebar and the document body.
///
/// Contains: Add to collection · Add note · Tag · Graph · Sources · Highlight Mode ·
/// Create Highlight · Add Note to Highlight · Cite (popover).
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Removed collapse behaviour
///   1.2 — Sources, Highlight Mode, Create Highlight, Add Note to Highlight moved here
///          from MacDocumentView toolbar and MainWindowView trailingTools
///   1.3 — Session 129: `CollectionPickerSheet` and `MacTagPickerSheet` split into
///          macOS/iOS bodies; macOS variants use VStack + button-bar to prevent
///          NavigationStack sidebar from hiding list content in sheet presentations
///   1.4 — Authoring Phase 5 (excerpts): Excerpt button while text is selected —
///          freezes the selection (offsets + rendering version when in-document) into
///          a `.excerpt` entry via the collection picker's excerpt mode
///   1.5 — Authoring Phase 5 review fixes: the Excerpt button delegates capture to
///          `HighlightCoordinator.makeExcerptCaptureAction` (built by MacDocumentView
///          from the flat text) so the frozen passage matches its stored anchors and
///          never embeds `data-skip` footnote-marker digits from `sel.toString()`
struct ResearchStripView: View {

    let entry: DocumentBrowserEntry?
    /// Whether the Cite button's citation popover is showing.
    ///
    /// Owned privately rather than passed in as a `@Binding` — it formerly shared
    /// `MainWindowView.showCitationPopover` with that window's toolbar "Info"
    /// button's own `.popover(isPresented:)`. Two `.popover` modifiers anchored to
    /// different source views but driven by the same boolean confused SwiftUI's
    /// presentation machinery: it couldn't determine which anchor to use, and in
    /// practice *neither* popover appeared — giving each trigger an independent
    /// boolean fixed it. The toolbar "Info" button was removed entirely in Session
    /// 2026-06-08 (it duplicated this button's `CitationPopoverView`, just less
    /// discoverably), so this is now the sole presenter — the private `@State`
    /// remains simply because there's no longer any reason to share it.
    @State private var showCitationPopover: Bool = false
    /// Whether the document Share / Export popover is showing.
    @State private var showSharePopover: Bool = false
    let highlightCoordinator: HighlightCoordinator
    /// Called when the user taps "Look Up in NARA Catalog" with text selected.
    /// The argument is the selected text string from the WebKit renderer.
    var onNARALookup: ((String) -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @State private var showAddToCollection: Bool = false
    @State private var showAddNote: Bool = false
    @State private var showTagPicker: Bool = false
    @State private var showHighlightColorPicker: Bool = false
    @State private var showHighlightNoteEditor: Bool = false
    /// The selection capture pending collection choice — non-nil presents the picker
    /// in excerpt mode (Authoring Phase 5, creation path b).
    @State private var pendingExcerptCapture: CollectionExcerptCapture? = nil
    /// Presents the collection picker in excerpt mode for `pendingExcerptCapture`.
    @State private var showAddExcerpt: Bool = false

    /// Persisted preference shared with MacDocumentView via AppStorage.
    @AppStorage("frus.document.researchPanel.visible") private var researchPanelVisible = true

    /// Current tag assignments for the visible document — used to pre-fill the tag
    /// picker so it opens with the correct state instead of an empty list.
    @Query private var currentDocumentAssignments: [DocumentTagAssignment]

    init(entry: DocumentBrowserEntry?,
         highlightCoordinator: HighlightCoordinator,
         onNARALookup: ((String) -> Void)? = nil) {
        self.entry = entry
        self.highlightCoordinator = highlightCoordinator
        self.onNARALookup = onNARALookup
        let vId = entry?.volumeId ?? ""
        let dId = entry?.documentId ?? ""
        _currentDocumentAssignments = Query(
            filter: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
    }

    private var isDisabled: Bool { entry == nil }
    private var canCreateHighlight: Bool {
        highlightCoordinator.webKitSelectionRange != nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Research")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.8)
                .padding(.leading, 16)

            ResearchStripButton(
                title: "Add to collection",
                systemImage: "folder.badge.plus",
                isDisabled: isDisabled
            ) { showAddToCollection = true }
            .help(String(
                localized: "researchStrip.addToCollection.help",
                defaultValue: "Add this document to an existing collection or create a new one"
            ))

            ResearchStripButton(
                title: "Add note",
                systemImage: "note.text.badge.plus",
                isDisabled: isDisabled
            ) { showAddNote = true }
            .help(String(
                localized: "researchStrip.addNote.help",
                defaultValue: "Create a research note attached to this document"
            ))

            ResearchStripButton(
                title: "Tag",
                systemImage: "tag",
                isDisabled: isDisabled
            ) { showTagPicker = true }
            .help(String(
                localized: "researchStrip.tag.help",
                defaultValue: "Apply user tags to this document"
            ))

            ResearchStripButton(
                title: "Graph",
                systemImage: "point.3.connected.trianglepath.dotted",
                isDisabled: isDisabled
            ) {
                if let entry {
                    appState.currentGraphEntry = entry
                    openWindow(id: "frus.crossReferenceGraph")
                }
            }
            .help(String(
                localized: "researchStrip.graph.help",
                defaultValue: "Show this document's cross-reference graph (inbound and outbound references)"
            ))

            // Word Cloud — document-scoped. Lives here (next to Graph) rather than in
            // the window toolbar so it reads clearly as "this document" and doesn't
            // collide with the corpus-scoped Word Cloud button in the main toolbar.
            ResearchStripButton(
                title: "Word Cloud",
                systemImage: WordCloudGlyph.symbol,
                isDisabled: isDisabled
            ) {
                if let entry {
                    appState.pendingWordCloud = .document(
                        volumeId: entry.volumeId, documentId: entry.documentId)
                }
            }
            .help(String(
                localized: "researchStrip.wordCloud.help",
                defaultValue: "Visualise the most frequent terms in this document"
            ))

            // Sources — always available for all documents.
            // appState.currentSourceNote is pre-set by MacDocumentView.loadDocument()
            // from vm.sourceNote (live XML parse) after each document loads, so the
            // Source Explorer always has the correct value regardless of how the
            // DocumentBrowserEntry was created (corpus browser vs cross-reference tap).
            // entry?.sourceNote is only populated when navigating via the corpus browser;
            // cross-reference navigation creates entries without sourceNote.
            ResearchStripButton(
                title: "Sources",
                systemImage: "archivebox",
                isDisabled: isDisabled
            ) {
                // Only override if currentSourceNote wasn't set by the load path
                // (safety fallback for edge cases where loadDocument hasn't run yet).
                if appState.currentSourceNote == nil {
                    appState.currentSourceNote = entry?.sourceNote ?? ""
                    if let dl = entry?.dateline,
                       let m = dl.range(of: #"\b(1[89][0-9]{2}|20[0-2][0-9])\b"#,
                                        options: .regularExpression) {
                        appState.currentSourceNoteYear = Int(dl[m])
                    }
                    // Prime the classifier context (pre-1906 country-series resolution).
                    appState.currentSourceNoteHeader = entry?.header
                    appState.currentSourceNoteDateline = entry?.dateline
                    appState.currentSourceNoteVolumeId = entry?.volumeId
                    appState.currentSourceNoteDocumentId = entry?.documentId
                }
                openWindow(id: "frus.sourceExplorer")
            }
            .help(String(
                localized: "researchStrip.sources.help",
                defaultValue: "Resolve this document's source note in the NARA Catalog or RG-59 records"
            ))

            // Highlight — enabled when the user has an active text selection.
            ResearchStripButton(
                title: "Highlight",
                systemImage: "paintbrush.pointed",
                isDisabled: !canCreateHighlight
            ) {
                showHighlightColorPicker = true
            }
            .help(String(
                localized: "researchStrip.createHighlight.help",
                defaultValue: "Save the current selection as a coloured highlight"
            ))
            .popover(isPresented: $showHighlightColorPicker) {
                highlightColorPicker
            }

            // Add Note to Highlight — enabled after a highlight is created
            if highlightCoordinator.pendingHighlightLink != nil {
                ResearchStripButton(
                    title: "Add Note",
                    systemImage: "note.text.badge.plus",
                    isDisabled: false
                ) { showHighlightNoteEditor = true }
                .help(String(
                    localized: "researchStrip.highlightNote.help",
                    defaultValue: "Attach a research note to the highlight you just created"
                ))
            }

            // Excerpt — enabled while text is selected: freezes the selection into a
            // `.excerpt` collection entry via the collection picker (Authoring Phase 5).
            // The capture is built by MacDocumentView (`makeExcerptCaptureAction`),
            // which re-extracts the passage from the flat text with its offsets +
            // rendering version when the selection is in-document; a footnote
            // selection freezes text only.
            if highlightCoordinator.webKitSelectedText != nil {
                ResearchStripButton(
                    title: String(localized: "researchStrip.excerpt",
                                  defaultValue: "Excerpt"),
                    systemImage: "text.quote",
                    isDisabled: isDisabled
                ) {
                    guard let capture = highlightCoordinator.makeExcerptCaptureAction?()
                    else { return }
                    pendingExcerptCapture = capture
                    showAddExcerpt = true
                }
                .help(String(
                    localized: "researchStrip.excerpt.help",
                    defaultValue: "Add the selected passage to a collection as a quoted excerpt with its citation"
                ))
            }

            // NARA Catalog Lookup — enabled when text is selected anywhere in the
            // document, including footnotes (webKitSelectedText != nil). Also shows
            // after the selection is released if the More-menu blur cleared the range
            // but the text was preserved for lookup.
            let hasLookupText = highlightCoordinator.webKitSelectedText != nil
            if hasLookupText, let onLookup = onNARALookup {
                ResearchStripButton(
                    title: "NARA Lookup",
                    systemImage: "magnifyingglass.circle",
                    isDisabled: false
                ) {
                    let text = highlightCoordinator.webKitSelectedText ?? ""
                    highlightCoordinator.webKitSelectedText = nil  // clear after capture
                    onLookup(text)
                }
                .help(String(
                    localized: "researchStrip.naraLookup.help",
                    defaultValue: "Query the NARA Catalog using the selected text"
                ))
            }

            // Cite — opens citation popover
            Button {
                showCitationPopover = true
            } label: {
                Label("Cite", systemImage: "quote.closing")
                    .font(.system(size: 11))
                    .foregroundStyle(isDisabled ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isDisabled ? Color.clear : Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isDisabled ? Color.clear : Color.accentColor.opacity(0.3),
                        lineWidth: 0.5
                    )
            )
            .disabled(isDisabled)
            .help(String(
                localized: "researchStrip.cite.help",
                defaultValue: "Show this document's formatted citation; copy or export to BibTeX/RIS"
            ))
            .popover(isPresented: $showCitationPopover, arrowEdge: .bottom) {
                if let entry { CitationPopoverView(entry: entry) }
            }

            // Share / Export — send this document to Zotero, export a Zotero file,
            // or share the citation. Kept separate from Cite so "save this source"
            // is discoverable on its own.
            ResearchStripButton(
                title: "Share",
                systemImage: "square.and.arrow.up",
                isDisabled: isDisabled
            ) {
                showSharePopover = true
            }
            .help(String(
                localized: "researchStrip.share.help",
                defaultValue: "Send this document to your Zotero library, export a Zotero file, or share its citation"
            ))
            .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                if let entry { DocumentSharePopover(entry: entry) }
            }

            // Open in New Window — opens this document in its own window. macOS
            // gathers windows from the same WindowGroup into native tabs (Window ▸
            // Merge All Windows / the window tab bar), so this is how a researcher
            // views several documents as tabs or side by side.
            ResearchStripButton(
                title: "New Window",
                systemImage: "square.on.square",
                isDisabled: isDisabled
            ) {
                if let entry {
                    openWindow(value: DocumentWindowID(
                        volumeId: entry.volumeId,
                        documentId: entry.documentId,
                        header: entry.header
                    ))
                }
            }
            .help(String(
                localized: "researchStrip.newWindow.help",
                defaultValue: "Open this document in its own window — drag windows together for tabs"
            ))

            Spacer()

            // Research panel toggle — segmented Read / Research picker.
            // Persisted via AppStorage so the preference survives document navigation.
            Picker(
                String(localized: "researchStrip.panelMode",
                       defaultValue: "View mode"),
                selection: Binding(
                    get: { researchPanelVisible },
                    set: { newVal in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            researchPanelVisible = newVal
                        }
                    }
                )
            ) {
                Text(String(localized: "researchStrip.panelMode.read",
                            defaultValue: "Read"))
                    .tag(false)
                Text(String(localized: "researchStrip.panelMode.research",
                            defaultValue: "Research"))
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            #if os(macOS)
            .controlSize(.small)
            #endif
            .padding(.horizontal, 6)
            .help(researchPanelVisible
                  ? String(localized: "researchStrip.panel.hide.help",
                           defaultValue: "Switch to focused reading view")
                  : String(localized: "researchStrip.panel.show.help",
                           defaultValue: "Open the Notes, Tags, and Summary panel"))
        }
        .frame(minHeight: 32)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showAddToCollection) {
            if let entry {
                CollectionPickerSheet(entry: entry)
            }
        }
        .sheet(isPresented: $showAddExcerpt, onDismiss: { pendingExcerptCapture = nil }) {
            if let entry, let capture = pendingExcerptCapture {
                CollectionPickerSheet(entry: entry, excerpt: capture)
            }
        }
        .sheet(isPresented: $showAddNote) {
            if let entry {
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    indexingPipeline: appState.indexingPipeline
                )
            }
        }
        .sheet(isPresented: $showTagPicker) {
            if let entry {
                MacTagPickerSheet(
                    entry: entry,
                    indexingPipeline: appState.indexingPipeline,
                    initialTagIds: Set(currentDocumentAssignments.map(\.tagId))
                )
            }
        }
        .sheet(isPresented: $showHighlightNoteEditor, onDismiss: {
            highlightCoordinator.pendingHighlightLink = nil
        }) {
            if let hlId = highlightCoordinator.pendingHighlightLink, let entry {
                ResearchNoteEditorView(
                    documentId: entry.documentId,
                    volumeId: entry.volumeId,
                    activeProjectId: appState.activeProjectId,
                    linkedHighlightId: hlId,
                    indexingPipeline: appState.indexingPipeline
                )
            }
        }
    }

    // MARK: - Highlight Color Picker

    private var highlightColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "doc.highlight.pickColor", defaultValue: "Highlight Color"))
                .font(.headline)
            HStack(spacing: 10) {
                ForEach(DocumentHighlight.Color.allCases, id: \.rawValue) { color in
                    Button {
                        highlightCoordinator.createWebKitHighlightAction?(color)
                        showHighlightColorPicker = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(highlightSwiftUIColor(for: color))
                                .frame(width: 32, height: 32)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(color.rawValue.capitalized)
                }
            }
        }
        .padding(16)
    }

    private func highlightSwiftUIColor(for color: DocumentHighlight.Color) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        }
    }
}

// MARK: - CollectionPickerSheet

/// Sheet that lets the user add a document to an existing collection or create a new one.
///
/// Presents a searchable list of all collections. Tapping a row adds the document as
/// a new `CollectionEntry` at the end of that collection and dismisses the sheet.
/// The "New Collection" button opens `CollectionEditorView` to create a collection
/// first; the document is not automatically added to the new collection (the user
/// manages membership via the Collections window).
/// Sheet for adding a document to an existing or new collection.
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders the list as a
/// collapsed sidebar with an empty detail area. The macOS body uses a plain `VStack`
/// with an inline search `TextField`, an explicit button bar, and a "New Collection"
/// button replacing the toolbar primary-action button. The iOS body retains
/// `NavigationStack` with `.searchable` and toolbar buttons.
///
/// Version history:
///   1.0 — Session 35+: initial implementation
///   1.1 — Session 129: split macOS / iOS bodies to prevent NavigationStack sidebar
///          from hiding list content; macOS replaces `.searchable` with inline TextField
///   1.2 — Authoring Phase 5 (excerpts): optional `excerpt` capture — when set, picking
///          a collection inserts a frozen `.excerpt` entry (via `CollectionExcerpts`)
///          instead of a document entry; no duplicate guard in excerpt mode
private struct CollectionPickerSheet: View {

    let entry: DocumentBrowserEntry

    /// When non-nil, the picker runs in excerpt mode (Authoring Phase 5): the chosen
    /// collection receives this capture as a `.excerpt` entry rather than the document.
    var excerpt: CollectionExcerptCapture? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.lastModified, order: .reverse) private var collections: [Collection]

    @State private var searchText: String = ""
    @State private var showNewCollection = false
    @State private var addedCollectionId: UUID? = nil

    private var filtered: [Collection] {
        guard !searchText.isEmpty else { return collections }
        return collections.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// The sheet title — names the excerpt mode when active.
    private var pickerTitle: String {
        excerpt == nil
            ? String(localized: "collection.picker.nav.title",
                     defaultValue: "Add to Collection")
            : String(localized: "collection.picker.title.excerpt",
                     defaultValue: "Add Excerpt to Collection")
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Shared collection row

    private func collectionRow(_ collection: Collection) -> some View {
        Button {
            addDocument(to: collection)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    let count = collection.documentEntries?.count ?? 0
                    Text(String(localized: "collection.picker.docCount",
                                defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if addedCollectionId == collection.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(pickerTitle)
                    .font(.headline)
                Spacer()
                Button {
                    showNewCollection = true
                } label: {
                    Label(String(localized: "collection.picker.newCollection",
                                 defaultValue: "New Collection"),
                          systemImage: "folder.badge.plus")
                }
                .labelStyle(.iconOnly)
                .help(String(localized: "collection.picker.newCollection.help",
                             defaultValue: "Create a new collection"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Inline search field
            if !collections.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "collection.picker.search.placeholder",
                                     defaultValue: "Search collections…"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()

            // Collection list or empty state
            if collections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(String(localized: "collection.picker.empty",
                                defaultValue: "No Collections"))
                        .font(.headline)
                    Text(String(localized: "collection.picker.empty.hint",
                                defaultValue: "Use the button above to create one."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(String(localized: "collection.picker.noResults",
                                defaultValue: "No collections match \"\(searchText)\"."))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(filtered) { collection in
                    collectionRow(collection)
                }
                .listStyle(.inset)
            }

            Divider()

            // Button bar
            HStack {
                Spacer()
                Button(String(localized: "collection.picker.cancel",
                              defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 340)
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.picker.empty",
                               defaultValue: "No Collections"),
                        systemImage: "folder",
                        description: Text(String(localized: "collection.picker.empty.hint",
                                                 defaultValue: "Create a collection first using the button below."))
                    )
                } else {
                    List(filtered) { collection in
                        collectionRow(collection)
                    }
                    .listStyle(.inset)
                    .searchable(text: $searchText,
                                prompt: String(localized: "collection.picker.search.placeholder",
                                               defaultValue: "Search collections…"))
                }
            }
            .navigationTitle(pickerTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.picker.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewCollection = true
                    } label: {
                        Label(String(localized: "collection.picker.newCollection",
                                     defaultValue: "New Collection"),
                              systemImage: "folder.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }

    // MARK: - Add action

    private func addDocument(to collection: Collection) {
        // Excerpt mode (Authoring Phase 5): freeze the capture into a `.excerpt` entry.
        // No duplicate guard — several excerpts from one document are expected.
        if let excerpt {
            CollectionExcerpts.appendToCollection(excerpt, collection: collection,
                                                  modelContext: modelContext)
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            return
        }

        // Guard against duplicates
        let existing = collection.documentEntries ?? []
        guard !existing.contains(where: {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }) else {
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            return
        }

        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        let collectionEntry = CollectionEntry(
            collectionId: collection.id,
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            sortOrder: nextOrder
        )
        modelContext.insert(collectionEntry)
        collection.documentEntries?.append(collectionEntry)

        addedCollectionId = collection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }
}

// MARK: - ResearchStripButton

private struct ResearchStripButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(isDisabled ? .tertiary : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(isDisabled ? 0 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.secondary.opacity(isDisabled ? 0 : 0.2), lineWidth: 0.5)
        )
        .disabled(isDisabled)
    }
}

// MARK: - SummaryBlockView

/// Inline AI summary block rendered within the document body.
///
/// Shows the most recent summary with prompt label and history cycling controls.
/// Collapses to a "Summarize" prompt when no summary exists.
/// Hidden entirely when `SummarizationService` is unavailable.
///
/// Version history:
///   1.0 — New UI scaffolding
struct SummaryBlockView: View {
    @Bindable var vm: DocumentViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showPromptPicker: Bool = false

    /// Whether the on-device model can generate new summaries right now.
    /// Existing summaries (possibly synced from other devices) are always shown;
    /// only the generate/regenerate affordances are gated.
    private var aiAvailable: Bool { AppleIntelligenceProvider.shared.isAvailable }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(alignment: .center) {
                Label("AI summary", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.7)

                if vm.activeSummary != nil {
                    Text("· custom prompt")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    if aiAvailable {
                        Button("Change prompt") { showPromptPicker = true }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .popover(isPresented: $showPromptPicker) {
                                SummaryPromptPickerView(vm: vm)
                            }
                    }

                    if vm.summaries.count > 1 {
                        Text("·").foregroundStyle(.tertiary).font(.system(size: 10))
                        HStack(spacing: 2) {
                            Button {
                                if vm.activeSummaryIndex < vm.summaries.count - 1 {
                                    vm.activeSummaryIndex += 1
                                }
                            } label: {
                                Image(systemName: "chevron.left").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex >= vm.summaries.count - 1)
                            .help(String(
                                localized: "summary.history.older.help",
                                defaultValue: "Show older summary"
                            ))
                            .accessibilityLabel(String(
                                localized: "summary.history.older.a11y",
                                defaultValue: "Older summary"
                            ))

                            Text("\(vm.activeSummaryIndex + 1)/\(vm.summaries.count)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            Button {
                                if vm.activeSummaryIndex > 0 { vm.activeSummaryIndex -= 1 }
                            } label: {
                                Image(systemName: "chevron.right").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.activeSummaryIndex <= 0)
                            .help(String(
                                localized: "summary.history.newer.help",
                                defaultValue: "Show newer summary"
                            ))
                            .accessibilityLabel(String(
                                localized: "summary.history.newer.a11y",
                                defaultValue: "Newer summary"
                            ))
                        }
                    }

                    if aiAvailable {
                        Button("Regenerate") { Task { await regenerateSummary() } }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .disabled(vm.isSummarizing)
                    }
                }
            }

            // Error from the most recent generation attempt — visible regardless
            // of whether a previous summary exists below it.
            if let error = vm.summarizationError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(String(
                        localized: "summary.error.a11y",
                        defaultValue: "Summarization failed: \(error)"
                    ))
            }

            // Body
            if vm.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Summarizing…").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            } else if let summary = vm.activeSummary {
                Text(summary.responseText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            } else if aiAvailable {
                Button("Summarize this document") { Task { await regenerateSummary() } }
                    .font(.system(size: 13))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            } else {
                // No summary and no way to make one on this hardware — explain
                // instead of offering a button that fails silently.
                Text(String(
                    localized: "summary.unavailable.explanation",
                    defaultValue: "Apple Intelligence is not available on this device, so new summaries cannot be generated. Summaries created on your other devices still appear here via iCloud."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func regenerateSummary() async {
        guard let service = appState.summarizationService else { return }
        let provider = AppleIntelligenceProvider.shared
        // Default prompt nil — picked in prompt picker popover.
        // If no prompt is selected, SummarizationService uses the standard prompt.
        if let prompts = try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(sortBy: [SortDescriptor(\.createdAt)])
        ), let prompt = prompts.first {
            await vm.generateSummary(
                prompt: prompt,
                provider: provider,
                service: service,
                activeProjectId: appState.activeProjectId,
                context: modelContext
            )
        }
    }
}

// FootnoteSectionView removed in Session 147.
// Footnotes are now rendered inline via the HTML Popover API in FRUSDocumentWebView.

// MARK: - StatusBarView

/// Persistent status bar at the bottom of the main macOS window.
///
/// Three zones:
/// - Left: indexed volume count (stable, low-noise)
/// - Centre: active background task with progress bar and ETA
/// - Right: CloudKit sync state
///
/// Progress is driven by `AppState.currentIndexingProgress` (now cross-platform)
/// and `AppState.downloadQueue`.
///
/// When a multi-volume batch is in progress (`AppState.indexingQueuePosition` is
/// non-nil) a `↑` chevron appears next to the centre zone label. Clicking the
/// centre zone opens `MacIndexingQueuePopover` with the full queue detail.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 118: centre zone tappable during multi-volume batches; opens
///          `MacIndexingQueuePopover` with position, progress, ETA, and pending list;
///          auto-closes when indexing completes
///   1.2 — Session 2026-07-04 (macOS UI audit B7): the WhileIndexing sheet is gone —
///          it auto-presented 0.6 s after indexing started, interrupting whatever the
///          user was doing. The "Learn" button (and the queue panel's) now opens the
///          existing frus.researchGuide window instead; nothing auto-presents. iOS
///          keeps its banner-driven education sheet (`IndexingQueueBannerView`).
struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var showQueuePopover = false

    var body: some View {
        HStack(spacing: 16) {

            // Left: index count
            HStack(spacing: 5) {
                Circle()
                    .fill(indexedCount > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(indexedCount) volume\(indexedCount == 1 ? "" : "s") indexed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Centre: active task.
            // Tappable when a multi-volume batch is in progress — opens
            // MacIndexingQueuePanel with full queue detail.
            if let task = activeTask {
                activeTaskView(task)
            }

            // "Learn" button — always visible while any indexing is active,
            // giving persistent access to the research guide even when the
            // queue panel (which also has the button) isn't open. Opens the
            // frus.researchGuide window (UI audit B7) — a click-through, never
            // an auto-presented modal.
            if appState.currentIndexingProgress != nil {
                Button {
                    openResearchGuide()
                } label: {
                    Label(String(localized: "statusbar.learn.label", defaultValue: "Learn"),
                          systemImage: "book.pages")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help(String(localized: "statusbar.learn.help",
                             defaultValue: "Learn about FRUS and set up your research context"))
            }

            Spacer()

            // Right: iCloud sync state.
            // Layer 1 — container init: shows "Local Only" if CloudKit init failed.
            // Layer 2 — live events: reflects the most recent import/export event.
            cloudKitStatusChip
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        // Auto-clear the completion summary after 6 seconds.
        .task(id: appState.completedIndexingMetadata?.volumeId) {
            guard appState.completedIndexingMetadata != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            appState.completedIndexingMetadata = nil
        }
        // Close the queue popover when indexing finishes.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            if progress == nil { showQueuePopover = false }
        }
        // No auto-presented education modal on macOS (UI audit B7): the sheet that
        // popped 0.6 s after indexing started interrupted first-run exploration.
        // The "Learn" button above is the click-through to the research guide window.
    }

    /// Opens (and foregrounds) the standalone Research Guide window — the same
    /// educational pages the removed WhileIndexing sheet showed (UI audit B7).
    private func openResearchGuide() {
        openWindow(id: "frus.researchGuide")
        bringMacWindowToFront(id: "frus.researchGuide")
    }

    // MARK: - Computed

    /// Volumes that are both downloaded and present in the FTS5 index.
    ///
    /// Uses `appState.indexedVolumeIds` (Set, seeded at boot) for O(1) lookups instead
    /// of per-volume SQLite queries. The previous implementation ran `isVolumeIndexed()`
    /// (prepare/step/finalize) for every downloaded volume on every body re-evaluation.
    /// Because StatusBarView observes `currentIndexingProgress` (updated ~10×/s), this
    /// caused hundreds of SQLite calls per second on the main thread, making the education
    /// sheet laggy when scrolling or advancing pages.
    private var indexedCount: Int {
        guard let dm = appState.downloadManager else { return 0 }
        return appState.indexedVolumeIds.filter { dm.isVolumeDownloaded($0) }.count
    }

    private struct ActiveTask {
        let label: String
        let systemImage: String
        let progress: Double?
        let eta: String?
        var isSuccess: Bool = false
    }

    private var activeTask: ActiveTask? {
        // Post-index summary (highest priority — replaces the in-progress task).
        if let meta = appState.completedIndexingMetadata {
            let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
                ?? meta.volumeId
            var summary = "Indexed \(title)"
            let statsParts = [
                meta.totalDocuments > 0 ? "\(meta.totalDocuments) docs" : nil,
                meta.uniquePersonCount > 0 ? "\(meta.uniquePersonCount) persons" : nil,
                meta.crossReferenceCount > 0 ? "\(meta.crossReferenceCount) links" : nil
            ].compactMap { $0 }
            if !statsParts.isEmpty { summary += " · " + statsParts.joined(separator: " · ") }
            return ActiveTask(
                label: summary,
                systemImage: "checkmark.circle.fill",
                progress: nil,
                eta: nil,
                isSuccess: true
            )
        }

        if let update = appState.currentIndexingProgress {
            // Special case: during the post-batch FTS5 optimise phase the update
            // carries an empty volumeId and stage == .optimizing. Render a clear
            // "Finalizing index…" label so the status bar doesn't show
            // "Indexing … (5/5)" with a blank volume name and a frozen-looking bar.
            if update.stage == .optimizing {
                return ActiveTask(
                    label: String(
                        localized: "indexing.queue.statusbar.finalizing",
                        defaultValue: "Finalizing index…"
                    ),
                    systemImage: "wand.and.stars",
                    progress: nil,  // indeterminate; optimise() has no sub-progress
                    eta: nil
                )
            }
            let progress: Double? = update.totalDocuments > 0
                ? Double(update.completedDocuments) / Double(update.totalDocuments)
                : nil
            let eta: String? = {
                guard update.docsPerSecond > 0,
                      update.totalDocuments > update.completedDocuments else { return nil }
                let remaining = update.totalDocuments - update.completedDocuments
                let seconds = Double(remaining) / update.docsPerSecond
                var base = "~\(Int(seconds.rounded()))s"
                if let meta = appState.lastDiscoveredMetadata,
                   meta.volumeId == update.volumeId {
                    let summary = statusBarMetaSummary(meta)
                    if !summary.isEmpty { base += " · " + summary }
                }
                return base
            }()
            let label: String = {
                if let qp = appState.indexingQueuePosition {
                    return "Indexing \(update.volumeId)… (\(qp.current)/\(qp.total))"
                }
                return "Indexing \(update.volumeId)…"
            }()
            return ActiveTask(
                label: label,
                systemImage: appState.indexingQueuePosition != nil
                    ? "square.and.arrow.down.on.square"
                    : "square.and.arrow.down",
                progress: progress,
                eta: eta
            )
        }

        if case .running(let processed, let total, let docId) =
            appState.backgroundSummarizationProgress.state {
            let progress: Double? = total > 0
                ? Double(processed) / Double(total)
                : nil
            let label: String = {
                if total == 0 {
                    return "Summarizing…"
                }
                let base = "Summarizing \(processed)/\(total)"
                if let id = docId { return "\(base) — \(id)" }
                return base
            }()
            return ActiveTask(
                label: label,
                systemImage: "sparkles",
                progress: progress,
                eta: nil
            )
        }

        if !appState.downloadQueue.isEmpty {
            return ActiveTask(
                label: "\(appState.downloadQueue.count) download\(appState.downloadQueue.count == 1 ? "" : "s") queued",
                systemImage: "arrow.down.circle",
                progress: nil,
                eta: nil
            )
        }

        return nil
    }

    private func statusBarMetaSummary(_ meta: VolumeMetadataDiscovered) -> String {
        var segments: [String] = []
        if meta.uniquePersonCount > 0 { segments.append("\(meta.uniquePersonCount) persons") }
        if meta.crossReferenceCount > 0 { segments.append("\(meta.crossReferenceCount) links") }
        if meta.datedDocumentCount > 0 {
            segments.append("\(meta.datedDocumentCount)/\(meta.totalDocuments) dated")
        }
        return segments.joined(separator: " · ")
    }

    // MARK: - CloudKit Status Chip

    /// Renders a compact sync-state label for the right side of the status bar.
    ///
    /// Shows "Local Only" when CloudKit init failed, a spinning indicator while a
    /// sync event is in flight, and the error message (with tooltip) when the most
    /// recent event failed.  Falls back to the plain "iCloud Sync" label when no
    /// events have fired yet (i.e. all is well and quiet).
    @ViewBuilder
    private var cloudKitStatusChip: some View {
        if !appState.cloudKitSyncEnabled {
            // Container fell back to local SQLite — CloudKit init failed at launch.
            // Append the actual diagnostic (CloudKit error domain + code name +
            // description) to the tooltip when AppState has one, so the failure's
            // error code is visible directly in the app — not just in Console.app.
            // See AppState.cloudKitInitError / FRUSExplorerApp.cloudKitDiagnostic(_:).
            let guidance = String(
                localized: "statusBar.sync.disabled.help",
                defaultValue: "iCloud sync is unavailable — notes, collections, and tags won't sync across devices. Check that you are signed in to iCloud and that the app has iCloud permissions in System Settings."
            )
            // Computed via an immediately-invoked closure (not an `if`/`else` directly
            // in this @ViewBuilder body) — a plain `if let … else …` whose branches
            // only assign to `help` makes the result-builder transform try to coerce
            // each branch's `()` result to `View`, producing "Type '()' cannot conform
            // to 'View'". Wrapping the assignment in a closure keeps it a normal
            // expression the builder evaluates once, outside the View-producing chain.
            let help: String = {
                guard let initError = appState.cloudKitInitError else { return guidance }
                return "\(guidance)\n\n\(String(localized: "statusBar.sync.disabled.diagnostic.label", defaultValue: "Diagnostic")): \(initError)"
            }()
            Label(
                String(localized: "statusBar.sync.disabled", defaultValue: "Local Only"),
                systemImage: "icloud.slash"
            )
            .font(.system(size: 11))
            .foregroundStyle(.orange)
            .help(help)
        } else {
            switch appState.cloudKitSyncState {
            case .unknown:
                // Waiting for the first event; assume OK until proven otherwise.
                Label(
                    String(localized: "statusBar.sync.enabled", defaultValue: "iCloud Sync"),
                    systemImage: "checkmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .help(String(localized: "statusBar.sync.enabled.help",
                             defaultValue: "User data syncs via iCloud across your devices"))

            case .syncing:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.55, anchor: .center).frame(width: 11, height: 11)
                    Text(String(localized: "statusBar.sync.syncing", defaultValue: "Syncing…"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .help(String(localized: "statusBar.sync.syncing.help",
                             defaultValue: "iCloud is syncing your notes, collections, and tags"))

            case .succeeded:
                Label(
                    String(localized: "statusBar.sync.synced", defaultValue: "Synced"),
                    systemImage: "checkmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .help(String(localized: "statusBar.sync.synced.help",
                             defaultValue: "iCloud sync completed successfully"))

            case .failed(let message):
                Label(
                    String(localized: "statusBar.sync.error", defaultValue: "Sync Error"),
                    systemImage: "exclamationmark.icloud"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .help(message)
            }

            // Zone-missing warning — overlaid when zone verification has completed
            // and the private zone is absent. This is separate from sync-event failures
            // because zone deletion is a silent failure the event system never reports.
            if appState.cloudKitZoneVerified == false {
                Label(
                    String(localized: "statusBar.sync.zoneMissing", defaultValue: "Zone Missing"),
                    systemImage: "exclamationmark.icloud.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .help(String(localized: "statusBar.sync.zoneMissing.help",
                             defaultValue: "The iCloud sync zone is missing — data cannot upload or download. Force-quit the app and relaunch to trigger zone recreation, or reset iCloud sync in Settings → Danger Zone."))
            }

            // Account warning — shown when health check detected a non-available status
            if let status = appState.cloudKitAccountStatus, status != .available {
                Label(
                    String(localized: "statusBar.sync.accountIssue", defaultValue: "Not Signed In"),
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .help(AppState.accountStatusDescription(status))
            }
        }
    }

    @ViewBuilder
    private func activeTaskView(_ task: ActiveTask) -> some View {
        if appState.indexingQueuePosition != nil,
           let update = appState.currentIndexingProgress {
            Button {
                showQueuePopover.toggle()
            } label: {
                taskLabel(task, showDisclosure: true)
            }
            .buttonStyle(.plain)
            .help(String(
                localized: "statusbar.indexingQueue.help",
                defaultValue: "Show indexing-queue progress and ETA"
            ))
            .popover(isPresented: $showQueuePopover, arrowEdge: .top) {
                MacIndexingQueuePanel(
                    update: update,
                    queuePosition: appState.indexingQueuePosition!,
                    volumeTitles: appState.indexingQueueVolumeTitles,
                    averageDocsPerSecond: appState.indexingQueueAverageDocsPerSecond,
                    averageDocumentCount: appState.indexingQueueAverageDocumentCount,
                    onLearnTapped: {
                        // B7: a window, not a sheet — no presentation conflict with
                        // the closing popover, so no async-after dance is needed.
                        showQueuePopover = false
                        openResearchGuide()
                    }
                )
            }
        } else {
            taskLabel(task, showDisclosure: false)
        }
    }

    @ViewBuilder
    private func taskLabel(_ task: ActiveTask, showDisclosure: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: task.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(task.isSuccess ? Color.green : .secondary)
            Text(task.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let progress = task.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .tint(.green)
                if let eta = task.eta {
                    Text(eta)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            if showDisclosure {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - MacIndexingQueuePanel

/// Popover panel showing multi-volume batch indexing progress on macOS.
///
/// Triggered by clicking the active-task zone in `StatusBarView` when
/// `AppState.indexingQueuePosition` is non-nil. Mirrors the information density
/// of `IndexingQueueBannerView` (the iOS equivalent) in a macOS-native popover.
///
/// ## Layout
/// ```
/// [icon] Indexing Queue          Volume 3 of 12
/// ─────────────────────────────────────────────
/// frus1969-76v03
/// ████████████░░░░░░░░  142 / 380 docs    ~4m
/// ─────────────────────────────────────────────
/// [clock] 9 volumes remaining         [chevron]
///   [clock] Volume 4 title…
///   [clock] Volume 5 title…
/// ```
///
/// Version history:
///   1.0 — initial implementation
private struct MacIndexingQueuePanel: View {

    /// Current volume's indexing progress.
    let update: IndexingProgressUpdate
    /// Position in the multi-volume batch (1-based current and fixed total).
    let queuePosition: (current: Int, total: Int)
    /// Titles of volumes still waiting in the queue (not including current).
    let volumeTitles: [String]
    /// Rolling average docs/s from completed volumes in this batch.
    var averageDocsPerSecond: Double = 0
    /// Rolling average document count from completed volumes; falls back to 600.
    var averageDocumentCount: Int = 600
    /// Called when the user taps "Learn about FRUS while you wait" — the presenting
    /// status bar closes this popover and opens the frus.researchGuide window
    /// (UI audit B7; formerly the auto-presenting WhileIndexing sheet).
    var onLearnTapped: (() -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(String(
                    localized: "indexing.queue.mac.header",
                    defaultValue: "Indexing Queue"
                ))
                .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(
                    localized: "indexing.queue.mac.position",
                    defaultValue: "Volume \(queuePosition.current) of \(queuePosition.total)"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Divider()

            // Current volume progress (or batch-wide "Finalizing" state during
            // the post-storage FTS5 optimise phase, when stage == .optimizing).
            VStack(alignment: .leading, spacing: 5) {
                if update.stage == .optimizing {
                    Label {
                        Text(String(
                            localized: "indexing.queue.mac.finalizing",
                            defaultValue: "Finalizing index — applying optimisations…"
                        ))
                        .font(.system(size: 11, weight: .medium))
                    } icon: {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.mini)
                    }
                    Text(String(
                        localized: "indexing.queue.mac.finalizing.detail",
                        defaultValue: "Merging FTS5 segments for \(update.totalDocuments.formatted()) indexed documents. This may take 30–60 seconds."
                    ))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(update.volumeId)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if update.totalDocuments > 0 {
                        ProgressView(
                            value: Double(update.completedDocuments),
                            total: Double(update.totalDocuments)
                        )
                        .progressViewStyle(.linear)
                        .tint(.accentColor)

                        HStack {
                            Text(String(
                                localized: "indexing.queue.mac.docs",
                                defaultValue: "\(update.completedDocuments) / \(update.totalDocuments) docs"
                            ))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            Spacer()
                            if let eta = totalETAString {
                                Text(eta)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .controlSize(.small)
                    }
                }
            }

            // Pending volumes
            if !volumeTitles.isEmpty {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(String(
                            localized: "indexing.queue.mac.remaining",
                            defaultValue: "\(volumeTitles.count) volume\(volumeTitles.count == 1 ? "" : "s") remaining"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(
                    localized: "indexing.queue.mac.expand.a11y",
                    defaultValue: isExpanded ? "Collapse queue list" : "Expand queue list"
                ))
                .help(isExpanded
                      ? String(localized: "indexing.queue.mac.expand.collapse.help",
                               defaultValue: "Collapse the pending-volumes list")
                      : String(localized: "indexing.queue.mac.expand.expand.help",
                               defaultValue: "Expand to see the next volumes waiting to be indexed"))

                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(volumeTitles.prefix(6), id: \.self) { title in
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            // "Learn while you wait" — opens the educational flow from StatusBarView.
            if let onLearn = onLearnTapped {
                Divider()
                Button {
                    onLearn()
                } label: {
                    Label(
                        String(localized: "indexing.learnWhileWaiting",
                               defaultValue: "Learn about FRUS while you wait →"),
                        systemImage: "book.pages"
                    )
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 300)
    }

    // MARK: - ETA

    /// Combined ETA: remaining docs in current volume + remaining queued volumes.
    private var totalETAString: String? {
        var totalSeconds = 0.0

        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        let remainingVolumes = queuePosition.total - queuePosition.current
        if remainingVolumes > 0 {
            let dps = averageDocsPerSecond > 0 ? averageDocsPerSecond : update.docsPerSecond
            if dps > 0 {
                let estimatedDocs = averageDocumentCount > 0 ? averageDocumentCount : 600
                totalSeconds += Double(remainingVolumes) * Double(estimatedDocs) / dps
            }
        }

        guard totalSeconds > 0 else { return nil }

        if totalSeconds < 60 {
            return "~\(Int(totalSeconds.rounded()))s"
        } else {
            let minutes = Int((totalSeconds / 60).rounded())
            return "~\(minutes)m"
        }
    }
}

// MARK: - CitationPopoverView

/// Pure builders for a document's citation/export artifacts, shared by the citation
/// popover (which owns its style + resolved-metadata state) and the document Share
/// popover (which owns its own). Keeping these stateless avoids the two views drifting.
///
/// Version history:
///   1.0 — Document Share/Export control split out from the citation popover
@MainActor
enum DocumentExportSupport {

    /// Canonical history.state.gov URL for a document.
    static func canonicalURL(entry: DocumentBrowserEntry) -> String {
        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
    }

    /// Citation metadata carrying the effective (entry-or-index) document number.
    static func docMeta(entry: DocumentBrowserEntry, documentNumber: String?) -> FRUSDocumentMetadata {
        FRUSDocumentMetadata(
            documentId: entry.documentId,
            documentNumber: documentNumber ?? entry.documentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
    }

    /// Best available publication year: live-parsed first, then a plausible 4-digit
    /// year from the manifest's `publicationDate`, then "n.d.".
    static func effectiveYear(parsed: String?, volume: VolumeManifestEntry) -> String {
        if let live = parsed, !live.isEmpty { return live }
        guard let pd = volume.publicationDate else { return "n.d." }
        let segments = pd.components(separatedBy: .init(charactersIn: "0123456789").inverted)
        if let yr = segments.first(where: { $0.count == 4 }), let y = Int(yr), y > 1750 { return yr }
        return "n.d."
    }

    /// Reads the volume XML header and extracts the publication year.
    static func extractPublicationYear(volumeURL url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let stream = InputStream(url: url) else { return nil }
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0, let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }
            guard let blockStart = text.range(of: "<publicationStmt"),
                  let blockEnd = text.range(of: "</publicationStmt>"),
                  blockStart.lowerBound < blockEnd.lowerBound else { return nil }
            let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])
            if let yr = regexFirstCapture(#"when="(\d{4})""#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            if let yr = regexFirstCapture(#">(\d{4})\s*<"#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            return nil
        }.value
    }

    private nonisolated static func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// BibTeX record for the document.
    static func bibtex(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                       documentNumber: String?, year: String) -> String {
        BibtexExporter().export(
            volumeId: entry.volumeId,
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry)
        )
    }

    /// RIS record for the document (citation only, no annotations).
    static func ris(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                    documentNumber: String?, year: String) -> String {
        RISExporter().export(
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry)
        )
    }

    /// Zotero item carrying the document's FRUS Explorer tags and research notes.
    static func zoteroItem(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                           documentNumber: String?, year: String,
                           context: ModelContext) -> ZoteroJSONExporter.Item {
        let resolved = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: entry.documentId, volumeId: entry.volumeId, context: context)
        return ZoteroJSONExporter.makeItem(
            document: docMeta(entry: entry, documentNumber: documentNumber),
            volume: FRUSVolumeMetadata(volume),
            year: year,
            url: canonicalURL(entry: entry),
            isEditorialNote: entry.isEditorialNote,
            tags: resolved.tags,
            notes: resolved.notes
        )
    }

    /// Formatted citation (with Markdown italics) for a style and live year.
    static func formatted(entry: DocumentBrowserEntry, volume: VolumeManifestEntry,
                          documentNumber: String?, parsedYear: String?,
                          style: CitationStyle) -> String {
        var volMeta = FRUSVolumeMetadata(volume)
        if let parsedYear { volMeta = volMeta.overridingPublicationYear(parsedYear) }
        return style.makeFormatter().format(
            document: docMeta(entry: entry, documentNumber: documentNumber), volume: volMeta)
    }

    /// Plain-text citation with Markdown italic markers removed.
    static func plainText(_ formatted: String) -> String {
        if let attr = try? AttributedString(
            markdown: formatted, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return String(attr.characters)
        }
        return formatted
            .replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
    }
}

/// Popover displaying a formatted FRUS citation for the current document.
///
/// Three styles: history.state.gov (default), Chicago, Turabian.
/// Volume editors are sourced from `VolumeManifestEntry.editors`.
/// The general editor is intentionally excluded per history.state.gov guidance.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 86: Export menu (Copy BibTeX, Copy RIS, Save as .bib)
///   1.2 — Session 2026-06-07: Export menu gained "Share Citation…" — a
///         `ShareLink` presenting the system share sheet with a message
///         combining the formatted citation and its canonical
///         history.state.gov URL (`shareableCitationMessage`), mirroring
///         the new "Share Citation" toolbar item on iOS.
///   1.3 — Session 155: Export menu gained "Send to Zotero (BibTeX)…" and
///         "Send to Zotero (JSON)…" — saves a file via `NSSavePanel`, then
///         opens it in Zotero (if installed) or reveals it in Finder.
struct CitationPopoverView: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// Initial selection mirrors the user's persisted preference
    /// (Settings → Display → Citations); the segmented control below lets the
    /// user switch styles per-presentation for comparison without changing
    /// that preference.
    @State private var selectedStyle: CitationStyle = CitationStyle.current
    /// Publication year extracted live from the volume's TEI `<publicationStmt><date>`.
    /// Preferred over the manifest value, which may contain a coverage range rather
    /// than the actual print year.
    @State private var parsedPublicationYear: String? = nil
    /// Authoritative document number resolved from the index (`document_cache.document_number`),
    /// used when `entry.documentNumber` is `nil` (e.g. the document was opened via a
    /// cross-reference, which builds the entry without the number). Resolved in `.task`.
    @State private var resolvedDocumentNumber: String? = nil

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }

    /// The document number to cite — the entry's, or the index-resolved value as a fallback.
    private var effectiveDocumentNumber: String? {
        entry.documentNumber ?? resolvedDocumentNumber
    }

    /// Citation metadata for every formatter/exporter in this popover, carrying the
    /// effective (entry-or-index) document number so the number is never dropped.
    private var docMeta: FRUSDocumentMetadata {
        FRUSDocumentMetadata(
            documentId: entry.documentId,
            documentNumber: effectiveDocumentNumber,
            header: entry.header,
            dateline: entry.dateline
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Label("Citation", systemImage: "quote.closing")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }

            // Document identity
            VStack(alignment: .leading, spacing: 2) {
                Text("Doc \(effectiveDocumentNumber ?? entry.documentId) · \(entry.volumeId)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(entry.header)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }

            // Style picker
            Picker("Style", selection: $selectedStyle) {
                ForEach(CitationStyle.allCases) { style in
                    Text(style.shortDisplayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(String(
                localized: "citation.popover.stylePicker.help",
                defaultValue: "Choose citation style (history.state.gov, Chicago, Turabian) for this view — change the default in Settings → Display"
            ))

            // Citation text — rendered as Markdown so _series title_ displays as italic.
            Group {
                if let attrStr = try? AttributedString(
                    markdown: formattedCitation,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attrStr)
                } else {
                    Text(formattedCitation)
                }
            }
            .font(.custom("Georgia", size: 12))
            .lineSpacing(4)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )

            // Metadata
            if let vol = volumeEntry {
                VStack(alignment: .leading, spacing: 3) {
                    if !vol.editors.isEmpty {
                        metaRow("Volume editors", vol.editors.joined(separator: ", "))
                    }
                    let yr = effectiveYear(for: vol)
                    metaRow("Published", "\(effectivePublisher(year: yr)), \(yr)")
                    if let docNum = effectiveDocumentNumber {
                        metaRow("Document no.", docNum)
                    }
                }
                .font(.system(size: 11))
            }

            // Canonical URL
            if let url = canonicalURL {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            // Actions
            HStack(spacing: 6) {
                Button {
                    // Copy plain text — markdown italic markers (_..._ / *...*) are
                    // stripped so the clipboard receives clean text without raw syntax.
                    copyToClipboard(plainTextCitation)
                } label: {
                    Label("Copy citation", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(
                    localized: "citation.popover.copyCitation.help",
                    defaultValue: "Copy the formatted citation to the clipboard"
                ))

                if let url = canonicalURL {
                    Button {
                        copyToClipboard(url)
                    } label: {
                        Label("Copy URL", systemImage: "link").font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(String(
                        localized: "citation.popover.copyURL.help",
                        defaultValue: "Copy the canonical history.state.gov URL for this document"
                    ))
                }

                Spacer()

                Menu {
                    Button {
                        if let vol = volumeEntry { copyToClipboard(bibtexString(vol: vol)) }
                    } label: {
                        Label("Copy BibTeX", systemImage: "doc.plaintext")
                    }
                    Button {
                        if let vol = volumeEntry { copyToClipboard(risString(vol: vol)) }
                    } label: {
                        Label("Copy RIS", systemImage: "doc.plaintext")
                    }
                    Divider()
                    Button {
                        if let vol = volumeEntry { saveBibFile(bibtexString(vol: vol)) }
                    } label: {
                        Label("Save as .bib\u{2026}", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Copy as\u{2026}", systemImage: "doc.on.doc").font(.system(size: 11))
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(volumeEntry == nil)
                .help(String(
                    localized: "citation.popover.copyAs.help",
                    defaultValue: "Copy this citation as BibTeX or RIS, or save a .bib file. Sharing and Zotero are on the document’s Share button."
                ))
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 440)
        // Load the publication year from the volume's own TEI header when available.
        // The bundled manifest may have a coverage range in publicationDate rather than
        // the actual print year; the live XML is authoritative.
        .task(id: entry.id) {
            await loadPublicationYear()
            // Backfill the document number from the index when the entry lacks it.
            if entry.documentNumber == nil, let pipeline = appState.indexingPipeline {
                resolvedDocumentNumber = (try? await pipeline.documentNumber(
                    volumeId: entry.volumeId, documentId: entry.documentId)) ?? nil
            }
        }
    }

    // MARK: - Formatted Citation

    /// Builds the formatted citation string for `selectedStyle` via the shared
    /// `CitationFormatter` conformers in `Citation/CitationFormatter.swift`
    /// (relocated here from inline string-building in Session 153).
    ///
    /// The returned string contains Markdown italic markers (`_..._` or `*...*`).
    /// Use `plainTextCitation` when the destination is the clipboard or a share sheet.
    private var formattedCitation: String {
        guard let vol = volumeEntry else {
            return "Citation unavailable — volume metadata not loaded."
        }
        return DocumentExportSupport.formatted(
            entry: entry, volume: vol, documentNumber: effectiveDocumentNumber,
            parsedYear: parsedPublicationYear, style: selectedStyle)
    }

    /// Plain-text version of `formattedCitation` with Markdown italic markers stripped.
    private var plainTextCitation: String {
        DocumentExportSupport.plainText(formattedCitation)
    }

    // MARK: - Publication Year

    /// Best available publication year for `vol` (live-parsed, else manifest, else n.d.).
    private func effectiveYear(for vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.effectiveYear(parsed: parsedPublicationYear, volume: vol)
    }

    private func effectivePublisher(year: String) -> String {
        let y = Int(year) ?? 0
        return y >= 2014
            ? "United States Government Publishing Office"
            : "Government Printing Office"
    }

    /// Reads the publication year live from the volume's TEI header.
    private func loadPublicationYear() async {
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        parsedPublicationYear = await DocumentExportSupport.extractPublicationYear(
            volumeURL: dm.volumeURL(for: entry.volumeId))
    }

    // MARK: - BibTeX / RIS Export

    private func bibtexString(vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.bibtex(entry: entry, volume: vol,
                                     documentNumber: effectiveDocumentNumber,
                                     year: effectiveYear(for: vol))
    }

    private func risString(vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.ris(entry: entry, volume: vol,
                                  documentNumber: effectiveDocumentNumber,
                                  year: effectiveYear(for: vol))
    }

    @MainActor
    private func saveBibFile(_ content: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bib") ?? .data]
        panel.nameFieldStringValue = "\(entry.volumeId)-\(entry.documentId).bib"
        panel.title = "Save BibTeX Citation"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helpers

    private var canonicalURL: String? {
        DocumentExportSupport.canonicalURL(entry: entry)
    }

    private var accessedDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value).foregroundStyle(.primary)
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - DocumentSharePopover

/// Document-level Share / Export popover, presented from the Research strip's
/// "Share" button — independent of the citation popover. Gathers the actions that
/// *send the document somewhere*: into the user's Zotero library via the Web API,
/// out as a Zotero-importable file, or via the system share sheet. Citation copying
/// stays on the Cite popover.
///
/// Version history:
///   1.0 — Document Share/Export control split out from the citation popover
struct DocumentSharePopover: View {
    let entry: DocumentBrowserEntry

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var parsedPublicationYear: String?
    @State private var resolvedDocumentNumber: String?
    @State private var zoteroResult: ZoteroSendResult?
    @State private var zoteroSending = false
    @State private var zoteroError: String?

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
    }
    private var effectiveDocumentNumber: String? {
        entry.documentNumber ?? resolvedDocumentNumber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Share / Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            Text(entry.header)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Divider()

            if let vol = volumeEntry {
                if ZoteroAccountStore.shared.isConnected {
                    actionRow("Send to Zotero Library", systemImage: "books.vertical",
                              busy: zoteroSending) {
                        Task { await sendToZoteroLibrary(vol: vol) }
                    }
                    Text("Adds this document — with your tags and research notes — straight to your Zotero library.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                actionRow("Export Zotero file (RIS)\u{2026}", systemImage: "doc.badge.arrow.up") {
                    sendToZoteroFile(zoteroRIS(vol: vol), ext: "ris", type: .init(filenameExtension: "ris") ?? .text)
                }
                actionRow("Export Zotero file (BibTeX)\u{2026}", systemImage: "doc.badge.arrow.up") {
                    sendToZoteroFile(DocumentExportSupport.bibtex(entry: entry, volume: vol,
                                                                 documentNumber: effectiveDocumentNumber,
                                                                 year: year(vol)),
                                     ext: "bib", type: .init(filenameExtension: "bib") ?? .data)
                }
                ShareLink(item: shareMessage(vol: vol)) {
                    Label("Share Citation\u{2026}", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Document metadata isn’t loaded yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .task(id: entry.id) {
            if let dm = appState.downloadManager, dm.isVolumeDownloaded(entry.volumeId) {
                parsedPublicationYear = await DocumentExportSupport.extractPublicationYear(
                    volumeURL: dm.volumeURL(for: entry.volumeId))
            }
            if entry.documentNumber == nil, let pipeline = appState.indexingPipeline {
                resolvedDocumentNumber = (try? await pipeline.documentNumber(
                    volumeId: entry.volumeId, documentId: entry.documentId)) ?? nil
            }
        }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        .alert(
            String(localized: "document.share.zotero.error.title", defaultValue: "Couldn't Send to Zotero"),
            isPresented: Binding(get: { zoteroError != nil }, set: { if !$0 { zoteroError = nil } }),
            presenting: zoteroError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { Text($0) }
    }

    // MARK: - Rows

    @ViewBuilder
    private func actionRow(_ title: String, systemImage: String,
                           busy: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage).font(.system(size: 11))
                Spacer()
                if busy { ProgressView().controlSize(.mini) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(busy)
    }

    // MARK: - Builders

    private func year(_ vol: VolumeManifestEntry) -> String {
        DocumentExportSupport.effectiveYear(parsed: parsedPublicationYear, volume: vol)
    }

    private func zoteroItem(vol: VolumeManifestEntry) -> ZoteroJSONExporter.Item {
        DocumentExportSupport.zoteroItem(entry: entry, volume: vol,
                                         documentNumber: effectiveDocumentNumber,
                                         year: year(vol), context: modelContext)
    }

    private func zoteroRIS(vol: VolumeManifestEntry) -> String {
        RISExporter().export(zoteroItem: zoteroItem(vol: vol))
    }

    private func shareMessage(vol: VolumeManifestEntry) -> String {
        let formatted = DocumentExportSupport.formatted(
            entry: entry, volume: vol, documentNumber: effectiveDocumentNumber,
            parsedYear: parsedPublicationYear, style: CitationStyle.current)
        return "\(DocumentExportSupport.plainText(formatted))\n\n\(DocumentExportSupport.canonicalURL(entry: entry))"
    }

    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        String(format: String(localized: "document.share.zotero.result %lld %lld",
                              defaultValue: "Added %lld document and %lld notes to Zotero."),
               Int64(result.addedItems), Int64(result.addedNotes))
    }

    // MARK: - Send

    /// Pushes the document into the user's Zotero library via the Web API (no collection).
    private func sendToZoteroLibrary(vol: VolumeManifestEntry) async {
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            zoteroError = ZoteroAPIError.missingCredentials.errorDescription
            return
        }
        zoteroSending = true
        defer { zoteroSending = false }
        do {
            let result = try await ZoteroAPIClient().send(
                items: [zoteroItem(vol: vol)], collectionName: nil,
                apiKey: apiKey, userID: userID, username: store.username)
            zoteroResult = result
        } catch {
            zoteroError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Saves a Zotero-importable file via `NSSavePanel`, then opens it in Zotero
    /// (if installed) or reveals it in Finder.
    private func sendToZoteroFile(_ content: String, ext: String, type: UTType) {
        guard let data = content.data(using: .utf8) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "\(entry.volumeId)-\(entry.documentId).\(ext)"
        panel.title = "Export for Zotero"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Could Not Save File"
                alert.informativeText = error.localizedDescription
                alert.runModal()
                return
            }
            if let zoteroURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.zotero.zotero") {
                NSWorkspace.shared.open([url], withApplicationAt: zoteroURL,
                                        configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}

// MARK: - MacTagPickerSheet

/// Document-level user-tag picker presented from `ResearchStripView`.
///
/// Lists all `UserTag` records from SwiftData and lets the user toggle which tags
/// apply to this document. A "New Tag" field lets the user create tags inline.
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders the list as a
/// collapsed sidebar with an empty detail area, hiding all controls. The macOS body
/// uses a plain `VStack` with explicit Cancel / Done buttons so all controls are always
/// visible. The iOS body retains the `NavigationStack` toolbar approach.
///
/// ## Persistence
/// On appear the view reads existing tag IDs from `IndexingPipeline.currentUserTagIds`
/// and pre-populates the toggle list. When the user taps/clicks Done, the updated set is
/// written back to both `document_cache` and the FTS5 index via
/// `IndexingPipeline.updateUserTagIds`. If `indexingPipeline` is nil (document not yet
/// indexed), the selection is a no-op and the sheet dismisses normally.
///
/// Version history:
///   1.0 — Session 60+: initial scaffold (save was a no-op; stale comment referenced a
///          non-existent DocumentUserTag model)
///   1.1 — Session 121: loads existing tags on appear; saves via IndexingPipeline.updateUserTagIds
///          on Done (Bug 2 — selection was stored in @State only, lost on dismiss)
///   1.2 — Session 129: split macOS / iOS bodies; macOS uses VStack + button-bar to prevent
///          NavigationStack sidebar from hiding list content in a sheet presentation
///   1.3 — Session 130: `documentTaggingGeneration` increment added so `ResearchView`
///          reloads its SQLite-sourced tag data whenever tags are applied or removed
struct MacTagPickerSheet: View {
    let entry: DocumentBrowserEntry
    let indexingPipeline: IndexingPipeline?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @State private var selectedTagIds: Set<UUID>
    @State private var newTagName: String = ""
    /// Tags inserted during this session — deleted if the user cancels rather than
    /// saves, preventing orphan UserTag records when Cancel is tapped.
    @State private var newlyCreatedTags: [UserTag] = []

    init(entry: DocumentBrowserEntry,
         indexingPipeline: IndexingPipeline?,
         initialTagIds: Set<UUID>) {
        self.entry = entry
        self.indexingPipeline = indexingPipeline
        _selectedTagIds = State(initialValue: initialTagIds)
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Tag List Content (shared between both platforms)

    /// The toggle rows and new-tag field — same content on both platforms.
    private var tagListContent: some View {
        Group {
            if allTags.isEmpty {
                Section {
                    Text(String(localized: "tags.picker.empty",
                                defaultValue: "No user tags yet. Type a name below to create one."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                Section(String(localized: "tags.picker.section.yourTags",
                               defaultValue: "Your Tags")) {
                    ForEach(allTags) { tag in
                        Toggle(isOn: Binding(
                            get: { selectedTagIds.contains(tag.id) },
                            set: { on in
                                if on { selectedTagIds.insert(tag.id) }
                                else  { selectedTagIds.remove(tag.id) }
                            }
                        )) {
                            Text(tag.name)
                        }
                    }
                }
            }

            Section(String(localized: "tags.picker.section.newTag", defaultValue: "New Tag")) {
                HStack {
                    TextField(String(localized: "tags.picker.newTag.placeholder",
                                     defaultValue: "Tag name…"), text: $newTagName)
                        .onSubmit { createTag() }
                    Button(String(localized: "tags.picker.newTag.add",
                                  defaultValue: "Add"), action: createTag)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(String(localized: "tags.picker.nav.title",
                            defaultValue: "Tags"))
                    .font(.headline)
                if let docNum = entry.documentNumber {
                    Text("— Doc \(docNum)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            List {
                tagListContent
            }
            .listStyle(.inset)

            Divider()

            // Button bar
            HStack {
                Button(String(localized: "tags.picker.cancel", defaultValue: "Cancel")) {
                    cancelAndDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "tags.picker.done", defaultValue: "Done")) {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 340, minHeight: 300)
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            List {
                tagListContent
            }
            .listStyle(.inset)
            .navigationTitle(String(localized: "tags.picker.nav.title", defaultValue: "Tags"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "tags.picker.cancel",
                                  defaultValue: "Cancel")) { cancelAndDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "tags.picker.done",
                                  defaultValue: "Done")) { saveAndDismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        newlyCreatedTags.append(tag)
        selectedTagIds.insert(tag.id)
        newTagName = ""
    }

    private func cancelAndDismiss() {
        for tag in newlyCreatedTags { modelContext.delete(tag) }
        dismiss()
    }

    private func saveAndDismiss() {
        // SwiftData write and dismissal happen immediately on the main thread.
        // The FTS5 virtual table update (delete + full re-insert) can take 100–500 ms
        // on iPhone storage; running it in the background eliminates visible lag.
        // For unindexed documents the FTS5 path is skipped entirely.
        syncAssignmentsToSwiftData()
        dismiss()
        guard let pipeline = indexingPipeline else { return }
        let tagString = selectedTagIds.isEmpty
            ? nil
            : selectedTagIds.map(\.uuidString).joined(separator: " ")
        let vId = entry.volumeId
        let dId = entry.documentId
        Task.detached(priority: .utility) {
            try? await pipeline.updateUserTagIds(
                volumeId: vId,
                documentId: dId,
                userTagIds: tagString
            )
        }
    }

    /// Replaces all `DocumentTagAssignment` records for the current document with the
    /// current `selectedTagIds` selection, then saves the context.
    ///
    /// This keeps `DocumentTagAssignment` (SwiftData/CloudKit) in sync with
    /// `document_cache.user_tag_ids` (SQLite/FTS5) written by the pipeline.
    private func syncAssignmentsToSwiftData() {
        let vId = entry.volumeId
        let dId = entry.documentId

        // Delete all existing assignments for this document.
        let descriptor = FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate<DocumentTagAssignment> { a in
                a.volumeId == vId && a.documentId == dId
            }
        )
        for assignment in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(assignment)
        }

        // Insert a new assignment for each selected tag.
        for tagId in selectedTagIds {
            modelContext.insert(DocumentTagAssignment(
                volumeId: vId, documentId: dId, tagId: tagId
            ))
        }

        try? modelContext.save()
    }
}

/// Popover that lists available summarization prompts for the document view.
///
/// Presented by `SummaryBlockView`'s "Change prompt" button. Tapping a prompt
/// dismisses the popover and immediately generates a new summary using that prompt.
/// A "New Prompt…" toolbar button opens `PromptEditorView` in a sheet so the user
/// can create a prompt without leaving the document context.
///
/// Version history:
///   1.0 — Session 75: initial implementation (replaces stub)
struct SummaryPromptPickerView: View {
    @Bindable var vm: DocumentViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @State private var showNewPromptEditor = false

    var body: some View {
        // macOS popovers should not contain NavigationStack chrome. The native
        // pattern is a title row + action button at the top, list below.
        VStack(spacing: 0) {
            // Header row: title left, "New Prompt…" button right
            HStack {
                Text(String(localized: "document.summarize.picker.title",
                            defaultValue: "Choose a Prompt"))
                    .font(.headline)
                Spacer()
                Button {
                    showNewPromptEditor = true
                } label: {
                    Label(
                        String(localized: "document.summarize.picker.newPrompt",
                               defaultValue: "New Prompt…"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Prompt list
            List {
                ForEach(allPrompts) { prompt in
                    Button {
                        dismiss()
                        guard let service = appState.summarizationService else { return }
                        Task {
                            await vm.generateSummary(
                                prompt: prompt,
                                provider: AppleIntelligenceProvider.shared,
                                service: service,
                                activeProjectId: appState.activeProjectId,
                                context: modelContext
                            )
                        }
                    } label: {
                        PromptPickerRowMac(prompt: prompt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if allPrompts.isEmpty {
                    ContentUnavailableView(
                        String(localized: "document.summarize.picker.empty.title",
                               defaultValue: "No Prompts"),
                        systemImage: "sparkles",
                        description: Text(
                            String(localized: "document.summarize.picker.empty.detail",
                                   defaultValue: "Add a prompt in Settings → Summarization Prompts.")
                        )
                    )
                }
            }
        }
        .frame(minWidth: 340, minHeight: 280)
        .sheet(isPresented: $showNewPromptEditor) {
            PromptEditorView(promptToEdit: nil)
        }
    }
}

// MARK: - PromptPickerRowMac

/// Single row in `SummaryPromptPickerView`'s list.
///
/// Displays the prompt name, a "Standard" badge for seeded prompts, and a
/// secondary line describing the response format.
private struct PromptPickerRowMac: View {
    let prompt: SummarizationPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(prompt.name).font(.body)
                if prompt.isStandard {
                    Text(String(localized: "prompt.picker.row.standard",
                                defaultValue: "Standard"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text(formatLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var formatLabel: String {
        switch prompt.responseFormat {
        case .general:
            return String(localized: "prompt.picker.row.format.general",
                          defaultValue: "General prose")
        case .structured(let schema):
            let names = schema.fields.map(\.name).joined(separator: ", ")
            return String(localized: "prompt.picker.row.format.structured",
                          defaultValue: "Structured: \(names)")
        }
    }
}

// MARK: - PersonDetailSheet (macOS)
// The iOS PersonDetailSheet is private to DocumentView/DocumentView.swift.
// This macOS version is used by MacDocumentView.

struct PersonDetailSheet: View {
    let person: PersonEntry
    let mentionCount: Int
    let onFindAllMentions: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Native macOS sheet layout: content area + Divider + bottom button bar.
        // NavigationStack inside a sheet adds unwanted nav-bar chrome on macOS.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(person.name)
                        .font(.headline)
                    if let desc = person.description {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                        .padding(.vertical, 4)
                    Text("In Indexed Documents")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    if mentionCount > 0 {
                        Label(
                            "Mentioned in \(mentionCount) indexed \(mentionCount == 1 ? "document" : "documents")",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        Button {
                            dismiss()
                            onFindAllMentions()
                        } label: {
                            Label("Find all mentions", systemImage: "magnifyingglass")
                        }
                    } else {
                        Text("Not found in indexed documents")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 400, minHeight: 260)
    }
}

// MARK: - GlossDetailSheet (macOS)

struct GlossDetailSheet: View {
    let gloss: GlossEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Native macOS sheet layout: content area + Divider + bottom button bar.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(gloss.term)
                        .font(.headline)
                    if let def = gloss.definition {
                        Text(def)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 360, minHeight: 200)
    }
}

// MARK: - CorpusBrowserWindowView

/// A value pushed onto the corpus browser's detail-column navigation stack, so deeper
/// levels (a volume's structure, a section's documents) open in the resizable window
/// instead of progressively smaller fixed-size sheets.
///
/// Version history:
///   1.0 — Session 170: replaces the nested volume/section sheets with push navigation
enum CorpusNavValue: Hashable {
    /// A volume's structural overview, keyed by id (the entry is re-looked-up from the manifest).
    case volume(volumeId: String)
    /// A section's document list or structured front-matter view within a volume.
    case section(volumeId: String, section: VolumeSection)
}

/// Standalone macOS window listing all FRUS subseries and their volumes.
///
/// Uses a `NavigationSplitView`: subseries in the sidebar, volumes in the detail column.
/// The detail column hosts a `NavigationStack` (`detailPath`), so selecting a volume — and
/// then a section within it — **pushes** progressively deeper views that each fill the
/// resizable window, rather than opening a stack of progressively smaller fixed-size sheets.
/// The People index and the per-volume connection graph open in their own windows
/// (`frus.people`, `frus.crossReferenceGraph`) — no sheets remain here.
///
/// ## Sidebar controls
/// - **Sort**: toggle between newest-first (descending) and oldest-first (ascending)
/// - **Filter**: hide subseries that have no volumes downloaded to this device
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — sort and filter sidebar controls; volume-structure sheet with in-app
///          download/indexing; `CorpusVolumeDocumentListView` replaced by
///          `CorpusVolumeDetailView` + `CorpusSectionDocumentView`
///   1.2 — Session 87: People toolbar button opens `PersonIndexView` sheet
///   1.3 — Session 170: volume/section drill-down became a resizable detail-column
///          `NavigationStack` (`CorpusNavValue`) instead of nested fixed-size sheets
///   1.4 — Session 2026-07-04 (macOS UI audit gap 12): consumes the
///          `AppState.pendingBrowseVolume` hand-off (Cross-Volume Provenance rows) —
///          selects the volume's subseries and pushes the volume onto the detail path
///   1.5 — Session 2026-07-04 (macOS UI audit B5): the People toolbar button opens the
///          frus.people window instead of a `PersonIndexView` sheet (which stacked the
///          person-detail sheet on top of itself)
struct CorpusBrowserWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var selectedSubseries: String? = nil
    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true
    @State private var filterDownloaded: Bool = false
    /// Drill-down path for the detail column: volume → section → deeper section. Owned by
    /// the window so it survives detail re-renders and is shared by every pushed level.
    @State private var detailPath: [CorpusNavValue] = []
    /// A volume push deferred until the subseries selection change lands (see
    /// `consumePendingVolume`): the `.onChange(of: selectedSubseries)` observer resets
    /// `detailPath` after every selection change, so pushing the volume synchronously
    /// alongside the selection would be wiped by that reset. The observer applies this
    /// push instead of the reset when it is set.
    @State private var pendingVolumePush: String? = nil

    private var allEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    private var subseries: [String] {
        var seen = Set<String>()
        var all = allEntries.compactMap { e in
            seen.insert(e.subseries).inserted ? e.subseries : nil
        }
        if filterDownloaded {
            let dm = appState.downloadManager
            all = all.filter { sub in
                allEntries.filter { $0.subseries == sub }
                    .contains { dm?.isVolumeDownloaded($0.volumeId) ?? false }
            }
        }
        return all.sorted {
            let a = Int(String($0.prefix(4))) ?? 0
            let b = Int(String($1.prefix(4))) ?? 0
            return sortDescending ? a > b : a < b
        }
    }

    private func volumes(for sub: String) -> [VolumeManifestEntry] {
        allEntries.filter { $0.subseries == sub }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSubseries) {
                ForEach(subseries, id: \.self) { sub in
                    subseriesRow(sub).tag(sub)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Corpus Browser")
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        // B5: the People index is a window (frus.people), browsable
                        // alongside documents — not a modal over this browser.
                        openWindow(id: "frus.people")
                        bringMacWindowToFront(id: "frus.people")
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .help("Browse people mentioned in indexed volumes")
                }
                ToolbarItem(placement: .automatic) {
                    Button { sortDescending.toggle() } label: {
                        Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                    }
                    .help(sortDescending ? "Sort oldest first" : "Sort newest first")
                }
                ToolbarItem(placement: .automatic) {
                    Button { filterDownloaded.toggle() } label: {
                        Image(systemName: filterDownloaded
                              ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    .help(filterDownloaded ? "Show all subseries" : "Show downloaded only")
                }
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let sub = selectedSubseries {
                        volumeList(for: sub)
                    } else {
                        ContentUnavailableView(
                            "Select a Subseries",
                            systemImage: "books.vertical",
                            description: Text("Choose a subseries from the list to browse its volumes.")
                        )
                    }
                }
                .navigationDestination(for: CorpusNavValue.self) { value in
                    switch value {
                    case .volume(let volumeId):
                        if let entry = allEntries.first(where: { $0.volumeId == volumeId }) {
                            CorpusVolumeDetailView(volume: entry, path: $detailPath)
                        }
                    case .section(let volumeId, let section):
                        CorpusSectionDocumentView(volumeId: volumeId, section: section, path: $detailPath)
                    }
                }
            }
        }
        // Switching subseries returns to the volume-list root (avoids a stale pushed
        // volume) — unless the change was made by `consumePendingVolume`, whose
        // deferred volume push is applied here instead of the reset.
        .onChange(of: selectedSubseries) { _, _ in
            if let volumeId = pendingVolumePush {
                detailPath = [.volume(volumeId: volumeId)]
                pendingVolumePush = nil
            } else {
                detailPath = []
            }
        }
        // Consume a volume hand-off (Cross-Volume Provenance rows, UI audit gap 12):
        // `.task` covers a window freshly created by the hand-off (`.onChange` misses
        // a value that was already set), `.onChange` covers one already open —
        // mirroring MacSearchWindowView's pendingSearch pattern.
        .task { consumePendingVolume() }
        .onChange(of: appState.pendingBrowseVolume) { _, volumeId in
            guard volumeId != nil else { return }
            consumePendingVolume()
        }
        .frame(minWidth: 540, minHeight: 440)
    }

    /// Applies (and clears) `AppState.pendingBrowseVolume`: selects the volume's
    /// subseries in the sidebar and pushes the volume onto the detail path. When the
    /// subseries selection has to change, the push is deferred through
    /// `pendingVolumePush` so the selection observer's path reset doesn't wipe it.
    private func consumePendingVolume() {
        guard let volumeId = appState.pendingBrowseVolume,
              let entry = allEntries.first(where: { $0.volumeId == volumeId }) else { return }
        appState.pendingBrowseVolume = nil
        if selectedSubseries == entry.subseries {
            detailPath = [.volume(volumeId: volumeId)]
        } else {
            pendingVolumePush = volumeId
            selectedSubseries = entry.subseries
        }
        #if DEBUG
        print("[CorpusBrowserWindowView] pendingBrowseVolume consumed: \(volumeId)")
        #endif
    }

    private func subseriesRow(_ sub: String) -> some View {
        let vols = volumes(for: sub)
        let dlCount = vols.filter {
            appState.downloadManager?.isVolumeDownloaded($0.volumeId) ?? false
        }.count
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(sub).font(.system(size: 13))
                Text(dlCount > 0
                     ? "\(dlCount)/\(vols.count) downloaded"
                     : "\(vols.count) volumes")
                    .font(.system(size: 10))
                    .foregroundStyle(dlCount > 0 ? Color.secondary : Color.secondary.opacity(0.5))
            }
            Spacer()
            Button {
                appState.pendingWordCloud = .subseries(subseriesId: sub)
            } label: {
                Image(systemName: WordCloudGlyph.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "corpus.subseries.wordCloudButton.help",
                         defaultValue: "Word cloud for this subseries"))
            .accessibilityLabel(
                String(localized: "corpus.subseries.wordCloudButton.a11y",
                       defaultValue: "Word cloud for \(sub)")
            )
        }
        .contextMenu {
            Button {
                appState.pendingWordCloud = .subseries(subseriesId: sub)
            } label: {
                Label { Text(String(localized: "corpus.subseries.wordCloud", defaultValue: "Word Cloud")) }
                    icon: { Image(systemName: WordCloudGlyph.symbol) }
            }
        }
    }

    @ViewBuilder
    private func volumeList(for subseries: String) -> some View {
        let vols = volumes(for: subseries)
        let filtered: [VolumeManifestEntry] = searchText.isEmpty ? vols : vols.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.volumeId.localizedCaseInsensitiveContains(searchText)
        }
        SubseriesVolumeListView(
            subseries: subseries,
            filteredVolumes: filtered,
            searchText: $searchText,
            path: $detailPath
        )
    }
}

// MARK: - SubseriesVolumeListView

/// Volume list for a selected FRUS subseries with per-volume cross-reference graph access.
///
/// Each volume row has a small graph button that opens the Cross-Reference Graph
/// *window* (`frus.crossReferenceGraph`) in its volume-connections stage, pre-selected
/// to that volume — corpus-wide edges, not restricted to the subseries — so the user
/// can see every volume that cross-references the chosen volume regardless of which
/// subseries it belongs to, while this browser stays open beside it.
///
/// Version history:
///   1.0 — extracted from `CorpusBrowserWindowView`
///   1.1 — Session 75: added subseries-scoped `VolumeConnectionGraphView` toolbar toggle
///   1.2 — Session 75: subseries filter removed; per-volume graph button replaces toolbar
///          toggle; volume detail and graph sheets unified under a single `SheetContent` enum
///   1.3 — Session 2026-07-03: volume titles wrap to their full value (three-line clip removed)
///   1.4 — Session 2026-07-04 (macOS UI audit B6): the graph button routes to the
///          frus.crossReferenceGraph window via the `pendingVolumeGraph` hand-off
///          instead of presenting `VolumeConnectionGraphView` in a local sheet — the
///          graph is browsable content, and the window precedent already existed
private struct SubseriesVolumeListView: View {
    let subseries: String
    let filteredVolumes: [VolumeManifestEntry]

    @Binding var searchText: String
    /// The window's detail-column drill-down path; tapping a volume pushes onto it.
    @Binding var path: [CorpusNavValue]

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    // MARK: - Body

    var body: some View {
        List {
            ForEach(filteredVolumes) { vol in
                volumeRow(vol)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search volumes…")
        .navigationTitle(subseries)
    }

    // MARK: - Volume Row

    private func volumeRow(_ vol: VolumeManifestEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vol.title)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(vol.volumeId)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if let dm = appState.downloadManager, dm.isVolumeDownloaded(vol.volumeId) {
                        Label("Downloaded", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                        if (try? appState.indexingPipeline?.isVolumeIndexed(vol.volumeId)) == true {
                            Label("Indexed", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                                .labelStyle(.titleAndIcon)
                        }
                    } else if appState.downloadQueue.contains(vol.volumeId) {
                        Label("Downloading", systemImage: "arrow.down.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            Spacer()
            Button {
                appState.pendingWordCloud = .volume(volumeId: vol.volumeId)
            } label: {
                Image(systemName: WordCloudGlyph.symbol)
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help(String(localized: "corpus.volume.wordCloudButton.help",
                         defaultValue: "Word cloud for this volume"))
            .accessibilityLabel(
                String(localized: "corpus.volume.wordCloudButton.a11y",
                       defaultValue: "Word cloud for \(vol.volumeId)")
            )
            Button {
                // B6: hand the volume to the graph window's volume-connections stage
                // (a window, so this list stays open while exploring the graph). The
                // window consumes and clears pendingVolumeGraph.
                appState.pendingVolumeGraph = vol.volumeId
                openWindow(id: "frus.crossReferenceGraph")
                bringMacWindowToFront(id: "frus.crossReferenceGraph")
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help(String(localized: "corpus.volume.graphButton.help",
                         defaultValue: "Cross-reference graph for this volume"))
            .accessibilityLabel(
                String(localized: "corpus.volume.graphButton.a11y",
                       defaultValue: "Cross-reference graph for \(vol.volumeId)")
            )
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { path.append(.volume(volumeId: vol.volumeId)) }
        .contextMenu {
            Button {
                appState.pendingWordCloud = .volume(volumeId: vol.volumeId)
            } label: {
                Label { Text(String(localized: "corpus.volume.wordCloud", defaultValue: "Word Cloud")) }
                    icon: { Image(systemName: WordCloudGlyph.symbol) }
            }
        }
    }
}

// MARK: - CorpusVolumeDetailView

/// A volume's structural overview (chapters, compilations), pushed into the corpus browser
/// window's resizable detail column.
///
/// ## Phase machine
/// ```
/// notDownloaded ──(Download)──► downloading
/// downloading ──(complete)──► indexing   [app auto-indexes after download]
/// notIndexed ──(Index Now)──► indexing
/// indexing ──(pipeline done)──► loadingStructure ──► ready
/// ready ──(tap section)──► pushes CorpusSectionDocumentView onto the detail path
/// ```
///
/// Download progress is inferred from `AppState.downloadQueue` transitions.
/// Indexing progress is read from `AppState.currentIndexingProgress`.
/// Both are `@Observable` properties so the view re-renders automatically.
///
/// Version history:
///   1.0 — Session 51: initial implementation
///   1.1 — Session 113: `DiscoveredMetadataRow` added to indexing phase view
///   1.2 — Session 115: `.interrupted` phase added; amber warning view with Re-index Now button
///   1.3 — Session 2026-06-09: `frontMatterTypes` + `extractFrontMatter` added; `structureView`
///          now splits sections into "Front Matter" and "Contents" headers, matching `VolumeView`
///   1.4 — Session 2026-07-03: full-title header above the phase content — the window
///          title truncates the long appended clauses older volume titles carry
private struct CorpusVolumeDetailView: View {
    let volume: VolumeManifestEntry
    /// The window's detail-column path; opening a section pushes onto it.
    @Binding var path: [CorpusNavValue]
    @Environment(AppState.self) private var appState

    enum Phase {
        case notDownloaded, downloading, indexing, loadingStructure, notIndexed, interrupted
        case ready(VolumeStructure)
        case error(String)
    }

    @State private var phase: Phase = .notDownloaded
    @State private var liveProgress: IndexingProgressUpdate? = nil
    @State private var showingSummaryCard = false
    private let parser = FRUSDocumentParser()

    var body: some View {
        // Pushed into the browser window's resizable detail column (not a sheet), so the
        // structure list, and any section drilled into, inherit the window's size.
        // The full volume title heads the content — the window/navigation title truncates
        // the long appended clauses older volumes carry, so the complete value must be
        // readable (and selectable) in the content area.
        VStack(alignment: .leading, spacing: 0) {
            Text(volume.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            phaseContent
        }
            .navigationTitle(volume.title)
            .task { await determinePhase() }
        // Download completion: queue no longer contains volumeId AND file now exists → auto-index begins
        .onChange(of: appState.downloadQueue) { _, queue in
            if case .downloading = phase,
               !queue.contains(volume.volumeId),
               appState.downloadManager?.isVolumeDownloaded(volume.volumeId) == true {
                phase = .indexing
                liveProgress = nil
            }
        }
        // Indexing progress: update display; when complete → show summary card.
        // Also handle external indexing: when a batch operation running outside this
        // sheet indexes our volume, progress transitions through our volumeId and
        // eventually becomes nil. We re-evaluate the phase so the sheet doesn't remain
        // stuck on `.notIndexed` after external indexing completes.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            guard case .indexing = phase else {
                // External indexing finished — re-evaluate if our volume may now be indexed.
                if progress == nil {
                    if case .notIndexed = phase { Task { await determinePhase() } }
                    else if case .interrupted = phase { Task { await determinePhase() } }
                }
                return
            }
            if let progress, progress.volumeId == volume.volumeId {
                liveProgress = progress
            } else if progress == nil {
                // Indexing ended — show the summary card if it was our volume, else load directly.
                if appState.completedIndexingMetadata?.volumeId == volume.volumeId {
                    showingSummaryCard = true
                } else {
                    Task { await loadStructure() }
                }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .notDownloaded:    notDownloadedView
        case .downloading:      downloadingView
        case .interrupted:      interruptedView
        case .indexing:
            if showingSummaryCard, let meta = appState.completedIndexingMetadata {
                summaryCardView(meta)
            } else {
                indexingView
            }
        case .loadingStructure:
            ProgressView("Loading contents…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notIndexed:       notIndexedView
        case .ready(let s):     structureView(s)
        case .error(let msg):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(msg)
            )
        }
    }

    // MARK: Phase logic

    private func determinePhase() async {
        if appState.downloadQueue.contains(volume.volumeId) { phase = .downloading; return }
        if let p = appState.currentIndexingProgress, p.volumeId == volume.volumeId {
            phase = .indexing; liveProgress = p; return
        }
        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volume.volumeId) else {
            phase = .notDownloaded; return
        }
        // Interrupted: sentinel present from a prior incomplete indexing pass.
        if appState.interruptedVolumeIds.contains(volume.volumeId) {
            phase = .interrupted; return
        }
        guard let pipeline = appState.indexingPipeline else { phase = .notIndexed; return }
        if (try? pipeline.isVolumeIndexed(volume.volumeId)) == true {
            await loadStructure()
        } else {
            phase = .notIndexed
        }
    }

    private func loadStructure() async {
        guard let dm = appState.downloadManager else { return }
        phase = .loadingStructure
        // Fast path: structure persisted at index time — a single SQLite read
        // instead of a SAX pass over the whole volume XML.
        if let pipeline = appState.indexingPipeline,
           let cached = try? await pipeline.cachedVolumeStructure(forVolumeId: volume.volumeId),
           !cached.isEmpty {
            phase = .ready(cached)
            return
        }
        let url = dm.volumeURL(for: volume.volumeId)
        do {
            let structure = try await parser.parseVolumeStructure(volumeURL: url)
            phase = .ready(structure)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: Phase views

    private var notDownloadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Volume Not Downloaded")
                .font(.headline)
            if volume.sizeBytes > 0 {
                Text("Approx. \(formattedMB(volume.sizeBytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Download this volume to browse its chapters, compilations, and documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let dm = appState.downloadManager else { return }
                phase = .downloading
                Task { await dm.enqueueDownload(volumeId: volume.volumeId,
                                                downloadUrl: volume.downloadUrl) }
            } label: {
                Label("Download Volume", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.downloadManager == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var downloadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Downloading…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Indexing will begin automatically when the download completes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var indexingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Indexing Volume", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            if let prog = liveProgress, prog.totalDocuments > 0 {
                ProgressView(value: Double(prog.completedDocuments),
                             total: Double(prog.totalDocuments))
                HStack {
                    Text(indexingStageLabel(prog.stage))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(prog.completedDocuments) / \(prog.totalDocuments)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparing…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if let meta = appState.lastDiscoveredMetadata,
               meta.volumeId == volume.volumeId {
                DiscoveredMetadataRow(metadata: meta)
            }
            IndexingContextCard(
                volume: volume,
                metadata: appState.lastDiscoveredMetadata.flatMap {
                    $0.volumeId == volume.volumeId ? $0 : nil
                }
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func summaryCardView(_ meta: VolumeMetadataDiscovered) -> some View {
        let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
        IndexingSummaryCard(
            metadata: meta,
            volumeTitle: title,
            onSearchVolume: { volumeId in
                // Setting pendingSearch triggers MainWindowView.onChange to open the search window.
                // The browser stays where it is (this view is pushed, not a sheet to dismiss).
                appState.pendingSearch = SearchParameters(volumeIds: [volumeId])
                appState.completedIndexingMetadata = nil
            },
            onDismiss: {
                showingSummaryCard = false
                appState.completedIndexingMetadata = nil
                Task { await loadStructure() }
            }
        )
    }

    private var notIndexedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Index Required")
                .font(.headline)
            Text("This volume has been downloaded but must be indexed before you can browse its documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let pipeline = appState.indexingPipeline else { return }
                phase = .indexing
                liveProgress = nil
                Task {
                    do {
                        try await pipeline.indexVolume(volume.volumeId)
                        await loadStructure()
                    } catch {
                        phase = .error(error.localizedDescription)
                    }
                }
            } label: {
                Label("Index Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var interruptedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Indexing Interrupted")
                .font(.headline)
            Text("The previous indexing pass did not complete. Re-index this volume to restore full search coverage.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let pipeline = appState.indexingPipeline else { return }
                phase = .indexing
                liveProgress = nil
                Task {
                    do {
                        try await pipeline.indexVolume(volume.volumeId)
                        await loadStructure()
                    } catch {
                        phase = .error(error.localizedDescription)
                    }
                }
            } label: {
                Label("Re-index Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(appState.indexingPipeline == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Flattens front-matter sections for display under the "Front Matter" header.
    ///
    /// A `"front"` wrapper is expanded so its subsections appear directly (one fewer
    /// tap); a wrapper carrying direct documents (1861-era volumes place the
    /// President's annual message in `<front>`) is kept alongside them. Any other
    /// top-level section whose kind is front matter is included as-is.
    private static func extractFrontMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections {
            if section.divType == "front" {
                if section.subsections.isEmpty || !section.documentIds.isEmpty {
                    items.append(section)
                }
                items.append(contentsOf: section.subsections)
            } else if section.isFrontMatterKind {
                items.append(section)
            }
        }
        return items
    }

    /// Flattens back-matter sections (errata, index) by expanding the `<back>`
    /// wrapper, mirroring `extractFrontMatter`.
    private static func extractBackMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections where section.divType == "back" {
            if section.subsections.isEmpty || !section.documentIds.isEmpty {
                items.append(section)
            }
            items.append(contentsOf: section.subsections)
        }
        return items
    }

    /// Handles a tap on a section row in the volume structure list.
    ///
    /// Prose-readable sections (preface, introduction, errata, etc.) open straight
    /// into the main window on the first tap — the same one-tap behaviour as a
    /// numbered document — by posting to `AppState.pendingBrowseDocument`. Sections that
    /// need an intermediate list or a structured view (compilations with documents, the
    /// Persons glossary, the Sources list) push `CorpusSectionDocumentView` onto the
    /// detail-column path instead.
    private func openSection(_ section: VolumeSection) {
        if section.canReadDirectly {
            appState.pendingBrowseDocument = DocumentBrowserEntry(
                documentId: section.sectionId,
                volumeId: volume.volumeId,
                header: section.title
            )
        } else {
            path.append(.section(volumeId: volume.volumeId, section: section))
        }
    }

    @ViewBuilder
    private func structureView(_ structure: VolumeStructure) -> some View {
        if structure.isEmpty {
            ContentUnavailableView(
                "No Contents",
                systemImage: "doc.text",
                description: Text("No structural sections were found in this volume.")
            )
        } else {
            let frontMatterItems = Self.extractFrontMatter(from: structure.sections)
            let backMatterItems = Self.extractBackMatter(from: structure.sections)
            let contentSections = structure.sections.filter {
                !$0.isFrontMatterKind && $0.divType != "back"
            }
            List {
                if !frontMatterItems.isEmpty {
                    Section("Front Matter") {
                        ForEach(frontMatterItems) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !contentSections.isEmpty {
                    Section("Contents") {
                        ForEach(contentSections) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !backMatterItems.isEmpty {
                    Section("Back Matter") {
                        ForEach(backMatterItems) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: Helpers

    private func formattedMB(_ bytes: Int) -> String {
        String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }

    private func indexingStageLabel(_ stage: IndexingStage) -> String {
        switch stage {
        case .reading:
            return String(localized: "corpus.detail.indexing.stage.reading",
                          defaultValue: "Reading…")
        case .storingBatch(let current, let total):
            return String(localized: "corpus.detail.indexing.stage.storingBatch",
                          defaultValue: "Storing batch \(current) of \(total)…")
        case .optimizing:
            return String(localized: "corpus.detail.indexing.stage.optimizing",
                          defaultValue: "Finalizing index…")
        case .complete:
            return String(localized: "corpus.detail.indexing.stage.complete",
                          defaultValue: "Complete")
        }
    }
}

// MARK: - DiscoveredMetadataRow

/// Two-column grid of aggregate discovery counts shown inside `CorpusVolumeDetailView`
/// once `VolumeMetadataDiscovered` arrives from the pipeline's metadata stream.
///
/// Omits any row whose value is zero. Includes a date-range line when present.
///
/// Version history:
///   1.0 — Session 113: initial implementation
private struct DiscoveredMetadataRow: View {
    let metadata: VolumeMetadataDiscovered

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                if metadata.uniquePersonCount > 0 {
                    GridRow {
                        Text("Persons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.uniquePersonCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.crossReferenceCount > 0 {
                    GridRow {
                        Text("Cross-references")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.crossReferenceCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.datedDocumentCount > 0 {
                    GridRow {
                        Text("Dated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.datedDocumentCount) / \(metadata.totalDocuments)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.editorialNoteCount > 0 {
                    GridRow {
                        Text("Editorial notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.editorialNoteCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
            if let dateRange = formattedDateRange {
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedDateRange: String? {
        guard let minISO = metadata.dateRangeMin,
              let maxISO = metadata.dateRangeMax else { return nil }
        let minFormatted = formatISODate(minISO) ?? minISO
        let maxFormatted = formatISODate(maxISO) ?? maxISO
        return "\(minFormatted) – \(maxFormatted)"
    }

    private func formatISODate(_ iso: String) -> String? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM yyyy"
        return out.string(from: date)
    }
}

// MARK: - CorpusSectionDocumentView

/// The content for a single section, pushed into the corpus browser window's detail column
/// from `CorpusVolumeDetailView`.
///
/// Routes to the appropriate view based on section type:
/// - **Prose sections** (`preface`, `intro`, `introduction`, `errata`, `prefatoryNote`,
///   `terms`) with an explicit `xml:id` show a "Read" button that opens the section as a
///   document.
/// - **`"persons"`** sections embed `FrontMatterPersonsView` inside a `List` (since that
///   view emits `Section` content rather than a root container).
/// - **`"sources"`** sections embed `VolumeSourcesView` inside a `List` for the same reason.
/// - All other sections fetch the indexed document list and display rows.
///
/// Tapping a document (or the "Read" button) posts the entry to
/// `AppState.pendingBrowseDocument` so the main window navigates to it; the browser window
/// stays where it is. The system back button returns to the volume overview.
///
/// Version history:
///   1.0 — Session 11: initial implementation (document list only)
///   1.1 — Session 2026-06-09: front-matter routing — persons, sources, prose sections
///   1.2 — Session 170: pushed into the detail column instead of presented as a sheet
///   1.3 — Session 2026-07-03: full-title header above the routed content — the window
///          title truncates long chapter/compilation titles
///   1.4 — Session 2026-07-04 (Source Explorer Phase 5 S6): the Archival Neighbors
///          sheet for volume-source rows removed — `VolumeSourcesView` opens the
///          value-based Archival Neighbors window directly on macOS, so the hoisted
///          binding is never set here anymore
///   1.5 — Session 2026-07-04 (macOS UI audit B2): the Cross-Volume Provenance sheet
///          removed the same way — `VolumeSourcesView` opens the value-based
///          Cross-Volume Provenance window directly on macOS, so `crossVolumeTarget`
///          is never set here anymore either
private struct CorpusSectionDocumentView: View {
    let volumeId: String
    let section: VolumeSection
    /// The window's detail-column path; a subsection row pushes deeper onto it.
    @Binding var path: [CorpusNavValue]

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @State private var documents: [DocumentBrowserEntry] = []
    @State private var isLoading = true
    /// Hoisted presentation targets for the section-emitting front-matter subviews —
    /// the sheets anchor on this view's Lists, exactly once (see the body comments).
    /// `sourceNeighborsTarget` and `crossVolumeTarget` are required by
    /// `VolumeSourcesView`'s shared init but are never written on macOS (S6/B2): the
    /// row actions open the Archival Neighbors / Cross-Volume Provenance windows
    /// directly, so no sheets anchor for them here.
    @State private var sourceNeighborsTarget: VolumeSourceNeighborsTarget? = nil
    @State private var crossVolumeTarget: CrossVolumeTarget? = nil
    /// Hoisted Collection-detail target (Phase 4) — presented on this view's List.
    @State private var collectionDetailTarget: AuthorityCollectionRecord? = nil
    @State private var selectedPerson: PersonIndexEntry? = nil

    // MARK: - Section Routing

    /// `true` when this section is a prose-only front-matter div that can be opened
    /// directly as a document, bypassing the indexed document list.
    private var canReadSectionDirectly: Bool { section.canReadDirectly }

    /// `true` when this section is the structured Persons list.
    private var isPersonsSection: Bool { section.isPersonsList }

    /// `true` when this section is the structured archival Sources list.
    private var isSourcesSection: Bool { section.isSourcesList }

    // MARK: - Body

    var body: some View {
        // Pushed into the browser window's resizable detail column (not a sheet), so the
        // title comes from `.navigationTitle` and the system back button handles dismissal.
        // The full section title heads the content — the window/navigation title truncates
        // long chapter/compilation titles, so the complete value must be readable here.
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            sectionContent
        }
        .navigationTitle(section.title)
        .task {
            // Skip the document-list fetch for sections handled by dedicated views.
            if canReadSectionDirectly || isPersonsSection || isSourcesSection {
                isLoading = false
            } else {
                await loadDocuments()
            }
        }
    }

    /// The routed per-kind content (prose Read button, persons list, sources list, or the
    /// structural subsection/document list) shown below the full-title header.
    @ViewBuilder
    private var sectionContent: some View {
        Group {
            if canReadSectionDirectly {
                proseSectionView
            } else if isPersonsSection {
                // FrontMatterPersonsView emits Section content and must live inside a List.
                // Its detail sheet anchors HERE on the List — presentation modifiers inside
                // section-emitting list content apply per row (the Archival Neighbors
                // open/close-loop class), so the subview only sets the binding.
                List { FrontMatterPersonsView(volumeId: volumeId, selectedPerson: $selectedPerson) }
                    .listStyle(.inset)
                    .sheet(item: $selectedPerson) { entry in
                        PersonIndexDetailSheet(indexEntry: entry)
                    }
            } else if isSourcesSection {
                // VolumeSourcesView emits Section content and must live inside a List.
                // The remaining sheet anchors HERE on the List (see above). No sheets
                // for `sourceNeighborsTarget` / `crossVolumeTarget`: on macOS those
                // row affordances open the S6 Archival Neighbors / B2 Cross-Volume
                // Provenance windows directly, so the bindings are never set (they
                // exist only for the shared iOS init).
                List {
                    VolumeSourcesView(volumeId: volumeId,
                                      sourceNeighborsTarget: $sourceNeighborsTarget,
                                      crossVolumeTarget: $crossVolumeTarget,
                                      collectionDetailTarget: $collectionDetailTarget)
                }
                .listStyle(.inset)
                .sheet(item: $collectionDetailTarget) { record in
                    CollectionDetailSheet(record: record)
                        .environment(appState)
                }
            } else {
                structuralList
            }
        }
    }

    /// Prose front-matter section — a single "Read" action that opens it in the main window.
    private var proseSectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "corpus.section.proseSection",
                        defaultValue: "Prose Section"))
                .font(.headline)
            Text(String(localized: "corpus.section.proseSection.detail",
                        defaultValue: "This section contains prose content rather than individual numbered documents."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                appState.pendingBrowseDocument = DocumentBrowserEntry(
                    documentId: section.sectionId,
                    volumeId: volumeId,
                    documentNumber: nil,
                    header: section.title,
                    dateline: nil,
                    sourceNote: nil
                )
            } label: {
                Label(
                    String(
                        format: String(localized: "browser.compilation.readSection",
                                       defaultValue: "Read %@"),
                        section.title
                    ),
                    systemImage: "doc.text"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// A structural section: its child subsections as drill-down rows, plus its own *direct*
    /// documents — mirroring history.state.gov, where an interior grouping node shows its
    /// child groups (and any documents attached directly to it), while a leaf lists its
    /// documents. Drilling into a subsection pushes a deeper `CorpusSectionDocumentView`, so
    /// arbitrarily-nested volumes work with no new screens.
    @ViewBuilder
    private var structuralList: some View {
        List {
            if !section.subsections.isEmpty {
                Section(String(localized: "corpus.section.subsections", defaultValue: "Sections")) {
                    ForEach(section.subsections) { sub in
                        Button {
                            path.append(.section(volumeId: volumeId, section: sub))
                        } label: {
                            SectionRowLabel(section: sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(String(localized: "corpus.section.loading", defaultValue: "Loading…"))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !documents.isEmpty {
                Section(String(format: String(localized: "corpus.section.documents %lld",
                                              defaultValue: "Documents (%lld)"), Int64(documents.count))) {
                    ForEach(documents, id: \.documentId) { doc in
                        documentButton(doc)
                    }
                }
            } else if section.subsections.isEmpty {
                Section {
                    Text(String(localized: "corpus.section.noDocuments",
                                defaultValue: "No documents in this section."))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset)
    }

    /// A tappable document row that opens the document in the main window.
    private func documentButton(_ doc: DocumentBrowserEntry) -> some View {
        Button {
            appState.pendingBrowseDocument = doc
        } label: {
            DocumentRowLabel(doc: doc)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.currentGraphEntry = doc
                openWindow(id: "frus.crossReferenceGraph")
            } label: {
                Label("Show Cross-Reference Graph",
                      systemImage: "point.3.connected.trianglepath.dotted")
            }
        }
    }

    private func loadDocuments() async {
        guard let pipeline = appState.indexingPipeline else { isLoading = false; return }
        let all = (try? await pipeline.documents(forVolume: volumeId)) ?? []
        // Direct documents only (`documentIds`, not `allDocumentIds`); subsections list and
        // load their own, so a compilation with chapters isn't flattened into one long list.
        let sectionIds = Set(section.documentIds)
        documents = all.filter { sectionIds.contains($0.documentId) }
        isLoading = false
    }
}

/// Content for the macOS **Source Explorer window** (`frus.sourceExplorer`) — the
/// app's home for NARA integration, in three segments:
/// - **Source Note**: the current document's parsed source note
///   (`MacSourceExplorerView`), targeted by the `appState.currentSourceNote*`
///   pending-state hand-off.
/// - **Collections**: the corpus-wide browse-by-collection authority list
///   (Source Explorer Phase 4).
/// - **NARA Lookup**: the live catalog query form (`NARACatalogLookupView`),
///   targeted by the `appState.pendingNARALookup` hand-off — a window segment, not
///   a modal, so the researcher can read the document text they are checking the
///   citation against while querying (UI audit B3).
///
/// Version history:
///   1.0 — New UI scaffolding: source-note window content
///   1.1 — Session 2026-07-04 (Source Explorer Phase 4): Collections segment added
///   1.2 — Session 2026-07-04 (macOS UI audit B3): NARA Lookup segment added,
///          replacing the modal `NARACatalogLookupView` sheets in `MainWindowView`
///          and `MacDocumentWindowView`; consumes `pendingNARALookup` (`.task` +
///          `.onChange`, mirroring MacSearchWindowView's pendingSearch) and re-keys
///          the lookup view's identity per hand-off so `@State(initialValue:)`
///          repopulates the query field (the NARACatalogLookupItem rationale)
struct SourceExplorerWindowView: View {
    @Environment(AppState.self) private var appState

    /// The window's three views: the parsed document note, the corpus-wide
    /// browse-by-collection list (Source Explorer Phase 4), or the live NARA
    /// Catalog lookup form (UI audit B3).
    private enum Mode: Hashable { case note, collections, naraLookup }
    @State private var mode: Mode = .note

    /// The current NARA Lookup hand-off, wrapped for view identity: a fresh `UUID`
    /// per hand-off makes SwiftUI create a brand-new `NARACatalogLookupView`, so
    /// `@State(initialValue:)` is honoured and the query field shows the newly
    /// selected text (see `NARACatalogLookupItem`). `nil` when the user switched to
    /// the segment manually — the form opens empty.
    @State private var naraLookupItem: NARACatalogLookupItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "source.explorer.window.mode", defaultValue: "View"),
                   selection: $mode) {
                Text(String(localized: "source.explorer.window.mode.note",
                            defaultValue: "Source Note")).tag(Mode.note)
                Text(String(localized: "source.explorer.window.mode.collections",
                            defaultValue: "Collections")).tag(Mode.collections)
                Text(String(localized: "source.explorer.window.mode.naraLookup",
                            defaultValue: "NARA Lookup")).tag(Mode.naraLookup)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 400)
            .padding(.vertical, 8)
            Divider()
            switch mode {
            case .note:
                noteContent
            case .collections:
                // The searchable, repository-grouped authority list; rows open the
                // shared Collection detail.
                NavigationStack {
                    CollectionBrowserView()
                }
            case .naraLookup:
                // Live catalog query form. `.id` re-keys the view per hand-off so a
                // new selection replaces a stale query field (fresh @State identity).
                NARACatalogLookupView(initialText: naraLookupItem?.text ?? "")
                    .id(naraLookupItem?.id)
            }
        }
        // Consume a NARA Lookup hand-off: `.task` covers a window freshly created by
        // the hand-off (`.onChange` misses a value that was already set), `.onChange`
        // covers one already open — mirroring MacSearchWindowView's pendingSearch.
        .task { consumePendingNARALookup() }
        .onChange(of: appState.pendingNARALookup) { _, text in
            guard text != nil else { return }
            consumePendingNARALookup()
        }
    }

    /// Applies (and clears) `AppState.pendingNARALookup`: switches to the NARA Lookup
    /// segment with a fresh lookup-view identity carrying the handed-off query text.
    private func consumePendingNARALookup() {
        guard let text = appState.pendingNARALookup else { return }
        appState.pendingNARALookup = nil
        naraLookupItem = NARACatalogLookupItem(text: text)
        mode = .naraLookup
    }

    /// The pre-Phase-4 window content: the current document's parsed source note.
    @ViewBuilder
    private var noteContent: some View {
        if let note = appState.currentSourceNote {
            MacSourceExplorerView(
                rawSourceNote: note,
                documentYear: appState.currentSourceNoteYear,
                indexingPipeline: appState.indexingPipeline,
                onRelatedDocumentTapped: { vid, did in
                    let entry = DocumentBrowserEntry(
                        documentId: did, volumeId: vid,
                        documentNumber: nil, header: did, dateline: nil, sourceNote: nil
                    )
                    appState.pendingBrowseDocument = entry
                },
                documentHeader: appState.currentSourceNoteHeader,
                documentDateline: appState.currentSourceNoteDateline,
                documentVolumeId: appState.currentSourceNoteVolumeId,
                documentId: appState.currentSourceNoteDocumentId
            )
        } else {
            ContentUnavailableView(
                String(localized: "source.explorer.window.empty",
                       defaultValue: "No Document Selected"),
                systemImage: "archivebox",
                description: Text(String(localized: "source.explorer.window.empty.detail",
                    defaultValue: "Open a document with a source note, then tap Sources in the toolbar. Or switch to Collections to browse the archival collections FRUS cites."))
            )
        }
    }
}

#endif // os(macOS)
