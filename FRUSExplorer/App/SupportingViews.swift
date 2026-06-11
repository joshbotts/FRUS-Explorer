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

    /// The `DocumentHighlight.id` of the most recently created highlight.
    /// Non-nil while the "Add Note to Highlight" button should be enabled.
    var pendingHighlightLink: UUID? = nil

    func reset() {
        webKitSelectionRange = nil
        webKitSelectedText   = nil
        pendingHighlightLink = nil
        createWebKitHighlightAction = nil
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
                       let m = dl.range(of: #"\b(19[0-9]{2}|20[0-2][0-9])\b"#,
                                        options: .regularExpression) {
                        appState.currentSourceNoteYear = Int(dl[m])
                    }
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
private struct CollectionPickerSheet: View {

    let entry: DocumentBrowserEntry

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
                Text(String(localized: "collection.picker.nav.title",
                            defaultValue: "Add to Collection"))
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
            .navigationTitle(String(localized: "collection.picker.nav.title",
                                    defaultValue: "Add to Collection"))
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
struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    @State private var showQueuePopover = false
    @State private var showWhileIndexing = false
    /// Reset each app session so a deliberate rebuild always shows the sheet.
    /// `hasSeen` (AppStorage) is not used here because it persists across launches
    /// and silently blocked the sheet after the first install.
    @State private var hasShownThisSession = false

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
            // giving persistent access to the educational sheet even when the
            // queue panel (which also has the button) isn't open.
            if appState.currentIndexingProgress != nil {
                Button {
                    showWhileIndexing = true
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
        // Auto-open the educational sheet the first time any indexing starts this session.
        // Uses currentIndexingProgress (set for ALL indexing paths including manual rebuild)
        // rather than indexingQueuePosition (nil for rebuild — only set by download-triggered indexing).
        // hasShownThisSession resets on each app launch so a deliberate rebuild sees the sheet.
        .onChange(of: appState.currentIndexingProgress != nil) { _, isActive in
            guard isActive, !hasShownThisSession else { return }
            hasShownThisSession = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showWhileIndexing = true
            }
        }
        .sheet(isPresented: $showWhileIndexing) {
            WhileIndexingSheet()
        }
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
                        showQueuePopover = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showWhileIndexing = true
                        }
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
    /// Called when the user taps "Learn about FRUS while you wait". The popover
    /// dismisses itself before calling this so the sheet can open cleanly.
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

    private var volumeEntry: VolumeManifestEntry? {
        appState.manifestStore.entry(forVolumeId: entry.volumeId)
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
                Text("Doc \(entry.documentNumber ?? entry.documentId) · \(entry.volumeId)")
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
                    if let docNum = entry.documentNumber {
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
                    Divider()
                    Button {
                        if let vol = volumeEntry { sendToZoteroBibtex(vol: vol) }
                    } label: {
                        Label("Send to Zotero (BibTeX)\u{2026}", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        if let vol = volumeEntry { sendToZoteroJSON(vol: vol) }
                    } label: {
                        Label("Send to Zotero (JSON)\u{2026}", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    ShareLink(item: shareableCitationMessage) {
                        Label("Share Citation\u{2026}", systemImage: "square.and.arrow.up")
                    }
                    .help(String(
                        localized: "citation.popover.shareCitation.help",
                        defaultValue: "Share the formatted citation and its history.state.gov URL"
                    ))
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up").font(.system(size: 11))
                }
                .menuStyle(.button)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(volumeEntry == nil)
                .help(String(
                    localized: "citation.popover.export.help",
                    defaultValue: "Export this citation as BibTeX or RIS, or save a .bib file to disk"
                ))
            }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 440)
        // Load the publication year from the volume's own TEI header when available.
        // The bundled manifest may have a coverage range in publicationDate rather than
        // the actual print year; the live XML is authoritative.
        .task(id: entry.id) { await loadPublicationYear() }
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

        let docMeta = FRUSDocumentMetadata(entry)
        var volMeta = FRUSVolumeMetadata(vol)
        if let liveYear = parsedPublicationYear {
            volMeta = volMeta.overridingPublicationYear(liveYear)
        }
        return selectedStyle.makeFormatter().format(document: docMeta, volume: volMeta)
    }

    /// Plain-text version of `formattedCitation` with Markdown italic markers stripped.
    ///
    /// `formattedCitation` uses `_..._` and `*...*` for the series title; the view
    /// renders these via `AttributedString(markdown:)` (producing actual italics), but
    /// the clipboard and share sheet should receive clean text without raw underscore/
    /// asterisk characters.  `AttributedString.characters` extracts the character
    /// sequence after Markdown parsing, giving the plain text automatically.
    private var plainTextCitation: String {
        if let attrStr = try? AttributedString(
            markdown: formattedCitation,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return String(attrStr.characters)
        }
        // Fallback: strip paired delimiters via regex if markdown parsing fails.
        return formattedCitation
            .replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
    }

    // MARK: - Publication Year

    /// Returns the best available publication year for `vol`.
    ///
    /// Priority: (1) `parsedPublicationYear` extracted live from the volume XML's
    /// `<publicationStmt><date>` element; (2) the first plausible 4-digit year
    /// found in the manifest's `publicationDate` string; (3) "n.d."
    private func effectiveYear(for vol: VolumeManifestEntry) -> String {
        if let live = parsedPublicationYear, !live.isEmpty { return live }
        guard let pd = vol.publicationDate else { return "n.d." }
        // Extract the first 4-digit number that looks like a year (post-1750).
        let segments = pd.components(separatedBy: .init(charactersIn: "0123456789").inverted)
        if let yr = segments.first(where: { $0.count == 4 }),
           let y = Int(yr), y > 1750 { return yr }
        return "n.d."
    }

    private func effectivePublisher(year: String) -> String {
        let y = Int(year) ?? 0
        return y >= 2014
            ? "United States Government Publishing Office"
            : "Government Printing Office"
    }

    // MARK: - Live Publication Year Extraction

    /// Reads the first portion of the downloaded volume XML and extracts the
    /// publication year from `<publicationStmt><date @when>` or its text content.
    private func loadPublicationYear() async {
        guard let dm = appState.downloadManager,
              dm.isVolumeDownloaded(entry.volumeId) else { return }
        let url = dm.volumeURL(for: entry.volumeId)
        parsedPublicationYear = await Self.extractPublicationYear(from: url)
    }

    private static func extractPublicationYear(from url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let stream = InputStream(url: url) else { return nil }
            stream.open()
            defer { stream.close() }
            // 8 KB covers the teiHeader which always appears at the top of the file.
            var buffer = [UInt8](repeating: 0, count: 8_192)
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0,
                  let text = String(bytes: Array(buffer[0..<n]), encoding: .utf8) else { return nil }

            // Isolate the <publicationStmt> block.
            guard let blockStart = text.range(of: "<publicationStmt"),
                  let blockEnd   = text.range(of: "</publicationStmt>"),
                  blockStart.lowerBound < blockEnd.lowerBound else { return nil }
            let block = String(text[blockStart.lowerBound..<blockEnd.upperBound])

            // Prefer @when="YYYY" — most authoritative, always the actual publication year.
            if let yr = regexFirstCapture(#"when="(\d{4})""#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            // Fall back to bare year as text content, e.g. <date>2010</date>.
            if let yr = regexFirstCapture(#">(\d{4})\s*<"#, in: block),
               let y = Int(yr), y > 1750, y < 2100 { return yr }
            return nil
        }.value
    }

    private nonisolated static func regexFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - BibTeX / RIS Export

    private func bibtexString(vol: VolumeManifestEntry) -> String {
        let year = effectiveYear(for: vol)
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = FRUSVolumeMetadata(vol)
        return BibtexExporter().export(
            volumeId: entry.volumeId,
            document: docMeta,
            volume: volMeta,
            year: year,
            url: canonicalURL
        )
    }

    private func risString(vol: VolumeManifestEntry) -> String {
        let year = effectiveYear(for: vol)
        let docMeta = FRUSDocumentMetadata(entry)
        let volMeta = FRUSVolumeMetadata(vol)
        return RISExporter().export(
            document: docMeta,
            volume: volMeta,
            year: year,
            url: canonicalURL
        )
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

    // MARK: - Send to Zotero

    /// Builds a Zotero JSON item for this document and hands it to `sendToZotero(_:suggestedName:contentType:)`.
    @MainActor
    private func sendToZoteroJSON(vol: VolumeManifestEntry) {
        let docMeta = FRUSDocumentMetadata(entry)
        var volMeta = FRUSVolumeMetadata(vol)
        if let liveYear = parsedPublicationYear {
            volMeta = volMeta.overridingPublicationYear(liveYear)
        }
        let (tags, notes) = ZoteroJSONExporter.fetchTagsAndNotes(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            context: modelContext
        )
        let item = ZoteroJSONExporter.makeItem(
            document: docMeta,
            volume: volMeta,
            year: effectiveYear(for: vol),
            url: canonicalURL,
            isEditorialNote: entry.isEditorialNote,
            tags: tags,
            notes: notes
        )
        guard let data = try? ZoteroJSONExporter().exportData(items: [item]) else { return }
        sendToZotero(data: data, suggestedName: "\(entry.volumeId)-\(entry.documentId)-zotero.json", contentType: .json)
    }

    /// Builds a BibTeX record for this document and hands it to `sendToZotero(_:suggestedName:contentType:)`.
    @MainActor
    private func sendToZoteroBibtex(vol: VolumeManifestEntry) {
        guard let data = bibtexString(vol: vol).data(using: .utf8) else { return }
        sendToZotero(data: data, suggestedName: "\(entry.volumeId)-\(entry.documentId).bib", contentType: .init(filenameExtension: "bib") ?? .data)
    }

    /// Saves `data` to a user-chosen location via `NSSavePanel`, then opens the
    /// saved file in Zotero (if installed) or reveals it in Finder.
    @MainActor
    private func sendToZotero(data: Data, suggestedName: String, contentType: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = suggestedName
        panel.title = "Send to Zotero"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                return
            }
            if let zoteroURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.zotero.zotero") {
                NSWorkspace.shared.open([url], withApplicationAt: zoteroURL, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    // MARK: - Helpers

    private var canonicalURL: String? {
        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
    }

    /// A formatted citation plus its canonical `history.state.gov` URL,
    /// suitable for sharing via the system share sheet (Mail, Messages,
    /// AirDrop, etc.). Uses `plainTextCitation` so markdown italic markers
    /// (_..._  / *...*) do not appear as raw syntax in the share payload.
    /// Falls back to `plainTextCitation` alone if no canonical URL is available.
    private var shareableCitationMessage: String {
        guard let url = canonicalURL else { return plainTextCitation }
        return "\(plainTextCitation)\n\n\(url)"
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

/// Standalone macOS window listing all FRUS subseries and their volumes.
///
/// Uses a `NavigationSplitView`: subseries in the sidebar, volumes in the detail
/// column. Selecting a volume opens `CorpusVolumeDetailSheet` which shows the volume
/// structure (chapters, compilations) and handles download/indexing when needed.
///
/// ## Sidebar controls
/// - **Sort**: toggle between newest-first (descending) and oldest-first (ascending)
/// - **Filter**: hide subseries that have no volumes downloaded to this device
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — sort and filter sidebar controls; volume-structure sheet with in-app
///          download/indexing; `CorpusVolumeDocumentListView` replaced by
///          `CorpusVolumeDetailSheet` + `CorpusSectionDocumentListView`
///   1.2 — Session 87: People toolbar button opens `PersonIndexView` sheet
struct CorpusBrowserWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubseries: String? = nil
    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true
    @State private var filterDownloaded: Bool = false
    @State private var showPeopleSheet: Bool = false

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
                    Button { showPeopleSheet = true } label: {
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
        .frame(minWidth: 540, minHeight: 440)
        .sheet(isPresented: $showPeopleSheet) {
            VStack(spacing: 0) {
                PersonIndexView()
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "common.done", defaultValue: "Done")) {
                        showPeopleSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(minWidth: 480, minHeight: 520)
        }
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
            searchText: $searchText
        )
    }
}

// MARK: - SubseriesVolumeListView

/// Volume list for a selected FRUS subseries with per-volume cross-reference graph access.
///
/// Each volume row has a small graph button (⌘-tap opens the graph sheet without
/// navigating away from the list). The graph sheet shows `VolumeConnectionGraphView`
/// pre-selected to that volume — corpus-wide edges, not restricted to the subseries —
/// so the user can see every volume that cross-references the chosen volume regardless
/// of which subseries it belongs to.
///
/// Version history:
///   1.0 — extracted from `CorpusBrowserWindowView`
///   1.1 — Session 75: added subseries-scoped `VolumeConnectionGraphView` toolbar toggle
///   1.2 — Session 75: subseries filter removed; per-volume graph button replaces toolbar
///          toggle; volume detail and graph sheets unified under a single `SheetContent` enum
private struct SubseriesVolumeListView: View {
    let subseries: String
    let filteredVolumes: [VolumeManifestEntry]

    @Binding var searchText: String

    @Environment(AppState.self) private var appState

    // MARK: - Sheet

    private enum SheetContent: Identifiable {
        case detail(VolumeManifestEntry)
        case graph(VolumeManifestEntry)
        var id: String {
            switch self {
            case .detail(let v): return "detail-\(v.volumeId)"
            case .graph(let v):  return "graph-\(v.volumeId)"
            }
        }
    }
    @State private var sheetContent: SheetContent?

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
        .sheet(item: $sheetContent) { content in
            switch content {
            case .detail(let vol):
                CorpusVolumeDetailSheet(volume: vol)
            case .graph(let vol):
                // macOS: remove NavigationStack chrome; Done button in bottom bar
                VStack(spacing: 0) {
                    VolumeConnectionGraphView(volumeId: vol.volumeId)
                        .environment(appState)
                    Divider()
                    HStack {
                        Spacer()
                        Button(String(localized: "corpus.graph.done",
                                      defaultValue: "Done")) {
                            sheetContent = nil
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .frame(minWidth: 680, minHeight: 520)
            }
        }
    }

    // MARK: - Volume Row

    private func volumeRow(_ vol: VolumeManifestEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vol.title)
                    .font(.system(size: 12))
                    .lineLimit(3)
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
                sheetContent = .graph(vol)
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityLabel(
                String(localized: "corpus.volume.graphButton.a11y",
                       defaultValue: "Cross-reference graph for \(vol.volumeId)")
            )
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { sheetContent = .detail(vol) }
    }
}

// MARK: - CorpusVolumeDetailSheet

/// Sheet showing a volume's structural overview (chapters, compilations) in the corpus browser.
///
/// ## Phase machine
/// ```
/// notDownloaded ──(Download)──► downloading
/// downloading ──(complete)──► indexing   [app auto-indexes after download]
/// notIndexed ──(Index Now)──► indexing
/// indexing ──(pipeline done)──► loadingStructure ──► ready
/// ready ──(tap section)──► CorpusSectionDocumentListView sheet
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
private struct CorpusVolumeDetailSheet: View {
    let volume: VolumeManifestEntry
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case notDownloaded, downloading, indexing, loadingStructure, notIndexed, interrupted
        case ready(VolumeStructure)
        case error(String)
    }

    @State private var phase: Phase = .notDownloaded
    @State private var liveProgress: IndexingProgressUpdate? = nil
    @State private var selectedSection: VolumeSection? = nil
    @State private var showingSummaryCard = false
    private let parser = FRUSDocumentParser()

    var body: some View {
        // macOS-native layout: title + Close button in header row, content below.
        // NavigationStack is not appropriate inside a sheet on macOS.
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(volume.title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            phaseContent
        }
        .frame(minWidth: 500, minHeight: 440)
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
                appState.pendingSearch = SearchParameters(volumeIds: [volumeId])
                appState.completedIndexingMetadata = nil
                dismiss()
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
                            Button { selectedSection = section } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !contentSections.isEmpty {
                    Section("Contents") {
                        ForEach(contentSections) { section in
                            Button { selectedSection = section } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !backMatterItems.isEmpty {
                    Section("Back Matter") {
                        ForEach(backMatterItems) { section in
                            Button { selectedSection = section } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .sheet(item: $selectedSection) { section in
                CorpusSectionDocumentListView(volume: volume, section: section) { doc in
                    appState.pendingBrowseDocument = doc
                    dismiss()
                }
            }
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

/// Two-column grid of aggregate discovery counts shown inside `CorpusVolumeDetailSheet`
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

// MARK: - CorpusSectionDocumentListView

/// Sheet presenting the content for a single section selected from `CorpusVolumeDetailSheet`.
///
/// Routes to the appropriate view based on section type:
/// - **Prose sections** (`preface`, `intro`, `introduction`, `errata`, `prefatoryNote`,
///   `terms`) with an explicit `xml:id` show a "Read" button that opens the section as a
///   document via `onDocumentSelected`.
/// - **`"persons"`** sections embed `FrontMatterPersonsView` inside a `List` (since that
///   view emits `Section` content rather than a root container).
/// - **`"sources"`** sections embed `VolumeSourcesView` inside a `List` for the same reason.
/// - All other sections fetch the indexed document list and display rows.
///
/// Tapping a document (or the "Read" button) calls `onDocumentSelected`, which posts the
/// entry to `AppState.pendingBrowseDocument` and dismisses all corpus browser sheets so the
/// main window can navigate to the document.
///
/// Version history:
///   1.0 — Session 11: initial implementation (document list only)
///   1.1 — Session 2026-06-09: front-matter routing — persons, sources, prose sections
private struct CorpusSectionDocumentListView: View {
    let volume: VolumeManifestEntry
    let section: VolumeSection
    let onDocumentSelected: (DocumentBrowserEntry) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var documents: [DocumentBrowserEntry] = []
    @State private var isLoading = true

    // MARK: - Section Routing

    /// `true` when this section is a prose-only front-matter div that can be opened
    /// directly as a document, bypassing the indexed document list.
    /// Delegates to the shared `VolumeSection.canReadDirectly` kind helper.
    private var canReadSectionDirectly: Bool { section.canReadDirectly }

    /// `true` when this section is the structured Persons list.
    private var isPersonsSection: Bool { section.isPersonsList }

    /// `true` when this section is the structured archival Sources list.
    private var isSourcesSection: Bool { section.isSourcesList }

    // MARK: - Body

    var body: some View {
        // macOS-native layout: section title row + content + Done button bar.
        // NavigationStack is not appropriate inside a sheet on macOS.
        VStack(spacing: 0) {
            Text(section.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            if canReadSectionDirectly {
                // Prose front-matter section — bypass document list and open directly.
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
                        let entry = DocumentBrowserEntry(
                            documentId: section.sectionId,
                            volumeId: volume.volumeId,
                            documentNumber: nil,
                            header: section.title,
                            dateline: nil,
                            sourceNote: nil
                        )
                        dismiss()
                        onDocumentSelected(entry)
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
            } else if isPersonsSection {
                // Persons section — FrontMatterPersonsView emits Section content
                // and must be embedded inside a List.
                List {
                    FrontMatterPersonsView(volumeId: volume.volumeId)
                }
                .listStyle(.inset)
            } else if isSourcesSection {
                // Sources section — VolumeSourcesView emits Section content
                // and must be embedded inside a List.
                List {
                    VolumeSourcesView(volumeId: volume.volumeId)
                }
                .listStyle(.inset)
            } else if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if documents.isEmpty {
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "doc.text",
                    description: Text("No indexed documents found in this section.")
                )
            } else {
                List(documents, id: \.documentId) { doc in
                    Button {
                        dismiss()
                        onDocumentSelected(doc)
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
                .listStyle(.inset)
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
        .frame(minWidth: 460, minHeight: 400)
        .task {
            // Skip the document-list fetch for sections handled by dedicated views.
            if canReadSectionDirectly || isPersonsSection || isSourcesSection {
                isLoading = false
            } else {
                await loadDocuments()
            }
        }
    }

    private func loadDocuments() async {
        guard let pipeline = appState.indexingPipeline else { isLoading = false; return }
        let all = (try? await pipeline.documents(forVolume: volume.volumeId)) ?? []
        let sectionIds = Set(section.allDocumentIds)
        documents = all.filter { sectionIds.contains($0.documentId) }
        isLoading = false
    }
}

struct SourceExplorerWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
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
                }
            )
        } else {
            ContentUnavailableView(
                "No Document Selected",
                systemImage: "archivebox",
                description: Text("Open a document with a source note, then tap Sources in the toolbar.")
            )
        }
    }
}

#endif // os(macOS)
