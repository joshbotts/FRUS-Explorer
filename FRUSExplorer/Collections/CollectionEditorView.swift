// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CollectionEditorView

/// Full editor for a `Collection`: name, optional note, ordered documents, and export.
///
/// ## Layout (Form sections)
/// 1. **Name** — text field for the collection title
/// 2. **Note** — optional free-text note for the whole collection
/// 3. **Documents** — reorderable list of `CollectionEntry` records; each row
///    lets the user pick an associated `ResearchNote` for that document
/// 4. **Add Documents** — opens `CollectionAddDocumentsSheet` (search, browse,
///    pasted citations, or tags) and appends the selection to the collection
/// 5. **Actions** — Sort by date, Export buttons
///
/// ## Creating vs Editing
/// When `collection` is `nil`, a new `Collection` is inserted when the view appears.
/// When non-nil, the existing record is edited in place.
///
/// ## Export
/// Tapping Export opens `ExportSheetView`, which resolves document content,
/// runs the selected exporter, and presents a share sheet.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 35: macOS compatibility — guard navigationBarTitleDisplayMode,
///          EditButton, and export sheet; add NSSavePanel / Reveal in Finder on macOS
///   1.2 — Session 73: resolveDocuments() made async; body text loaded via SQLite cache
///   1.3 — Session 88: timeline button in Documents section header opens `DocumentTimelineView`
///          (IndexingPipeline.fetchDocumentBodyText) with XML fallback for un-indexed volumes;
///          citation built via HistoryAtStateCitationFormatter; AddByTagSheet, ExportSheetView,
///          and MacExportCompleteView made internal (non-private) for use in MacCollectionManagerView
///   1.3 — Session 74: two-line research note preview (caption2, tertiary) added to EntryRow
///          beneath the volume ID; same preview added to MacEntryRow in MacCollectionManagerView
///   1.4 — Session 89: Cancel on new collection deletes entries explicitly before the collection
///          (deleteRule .nullify replaces .cascade for CloudKit compatibility)
///   1.5 — Session 97: smart collection — `savedSearchId` field on `Collection`; link/unlink UI
///          in editor; smart export path in `ExportSheetView` resolves documents via `SearchService`
///   1.6 — Session 129: `AddByTagSheet` and `LinkSavedSearchSheet` split into macOS/iOS bodies;
///          macOS uses VStack + button-bar to prevent NavigationStack sidebar from hiding list
///          content inside a `.sheet()` presentation
///   1.7 — Session 157: collection Zotero items resolve `isEditorialNote` from the index
///          (`ZoteroJSONExporter.editorialNoteFlags`) instead of hardcoding `false`,
///          restoring parity with the document-level export path
///   1.8 — Session 2026-07-02 (Collections Authoring Phase 1): mechanical file split —
///          EntryRow, CollectionHeadingRow, CollectionProseRow, structuralDeleteButton →
///          CollectionEntryRows.swift; ProseRichText, RichTextEditor → CollectionRichTextEditor.swift;
///          AddByTagSheet → CollectionAddByTagSheet.swift; ExportSheetView, MacExportCompleteView,
///          ShareSheet, URL: Identifiable, Zotero result alert → CollectionExportSheet.swift;
///          CollectionEntryInspector → CollectionEntryInspector.swift; CollectionCompositionRows →
///          CollectionCompositionRows.swift. EntryRow made internal (was private) for the
///          cross-file reference; no behavior changes.
///   1.9 — Authoring Phase 1: entry rows show indexed document headers, volume titles, and
///          dates (parity with the macOS manager) via the shared `CollectionEntryData`
///          pane-level loader; Sort by Date gains per-document `date_iso` precision (was
///          volume-dates-only); `.unrecognized` entries render as an inert row
///   2.0 — Authoring Phase 1 shell: `PresentationStyle` (.pushed from the Collections tab,
///          .sheet elsewhere); all-live autosave replaces the hybrid Save/Cancel draft
///          model (A1) — an untouched new collection is discarded on dismiss, a kept
///          unnamed one gets a default name; iPhone layout is entry-list-primary with
///          collapsible Details/Composition disclosures; iPad uses a system `.inspector`
///          for metadata + composition instead of the two-Form HStack;
///          `applyEditsForExport` deleted (redundant under live saves)
///   2.1 — Authoring Phase 2b: live preview pane — iPhone gains a segmented
///          Outline | Preview control above the Form; iPad gains a toolbar-toggled
///          side-by-side `CollectionPreviewView` next to the entries Form (the
///          metadata `.inspector` keeps working alongside); the preview's Render All
///          state is hoisted here so pane toggles don't reset it
///   2.2 — Authoring Phase 3: `AddByTagSheet` replaced by `CollectionAddDocumentsSheet`
///          (Search | Browse | Citations | Tags); added documents append at the end of
///          the entry list in selection order; `appendEntries` allows duplicates (A4)
///          via the shared `CollectionDocumentDiscovery.appendEntries`, with repeated
///          documents badged "Also in collection" on their rows
///   2.3 — Authoring Phase 4 (editor step): the documents list renders the derived
///          outline (rows indent by `CollectionOutline` depth, headings step typography
///          and gain collapse chevrons — view state only) with the section context menu
///          (rename / indent / outdent / delete-heading vs delete-section); dragging a
///          heading moves its whole section as one block via the shared
///          `CollectionOutline.applyingMove` engine; front-matter editing (subtitle,
///          author line, introduction rich text, colophon toggle) joins the iPhone
///          Details disclosure / iPad inspector / macOS sheet form, all live-autosaved,
///          with the active Project name as the author-line placeholder (never persisted)
///   2.4 — Authoring Phase 4 review fix: front-matter footer copy corrected — the
///          introduction opens the body AFTER the table of contents (it is the
///          resolver's leading `.prose` item), not before it
///   2.5 — Authoring Phase 5 (excerpts): the add menu gains "Add Highlighted Passages…"
///          (`CollectionAddHighlightsSheet` — see its doc for why it lives here rather
///          than in Add Documents); `.excerpt` entries render as `CollectionExcerptRow`
///          (movable/deletable like prose, no body-depth controls); document rows'
///          inspector gains a per-highlight "Insert as Excerpt" callback that appends
///          via the shared `CollectionExcerpts` factory
///   2.6 — Authoring Phase 5 review fixes: the timeline sheets map only `.document`
///          entries — excerpt entries carry their source document's provenance ids, so
///          mapping them too double-counted that document's year and duplicated the
///          timeline `Item` id
///   2.7 — Authoring Phase 6 (generated apparatus): the add menu gains an "Apparatus"
///          submenu listing the five `CollectionGeneratedBlockType`s; insertion honors
///          the type's default position hint (front-matter types before the first
///          entry, back matter at the end — fully movable afterwards); `.generated`
///          entries render as `CollectionGeneratedEntryRow` (movable/deletable like
///          prose, no body-depth or inspector controls)
///   2.8 — Session 2026-07-04 (UI audit A4): every entry row exposes Move Up /
///          Move Down as VoiceOver actions + context-menu items via the shared
///          `entryMoveControls`; `moveVisibleRowUp/Down` reuse the drag engine
///          (`moveVisibleRows`) in visible-row coordinates, so headings carry their
///          sections and collapsed sections are hopped whole — reordering no longer
///          requires EditButton drag handles
///   2.9 — Collections Manager M2 (D3/D5): document rows became pure reports; the
///          per-entry editor promoted from a per-row `.sheet` to a shared trailing
///          `.inspector` column on iPad (regular width) — a `.sheet` on iPhone — driven by
///          `inspectedEntryId`; adds the `NoteCreateContext` struct + `noteCreateContext`
///          state so the inspector's "New Note…" opens a shared `InlineNoteCreateSheet`
///          targeting the entry
///   3.0 — Sort modes: every Sort by Date control (iPad toolbar item, iPhone add-menu,
///          compact Actions section) becomes a `Menu` offering the two
///          `CollectionDateSortScope`s via the shared `sortByDateScopeItems`; `sortByDate`
///          gains a `withinSections` parameter (default false = the original global sort)
struct CollectionEditorView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    // MARK: - SwiftData queries

    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var allSavedSearches: [SavedSearch]
    @Query(sort: \Project.name) private var allProjects: [Project]

    // MARK: - State

    @State private var collection: Collection
    private let isNewCollection: Bool

    @State private var collectionName: String
    @State private var collectionNote: String
    /// Reveals the collection-note editor. The note collapses to a compact
    /// "Add a note" button until it holds text or the user taps to add one, so
    /// the optional note no longer occupies several lines of space by default.
    @State private var isAddingNote = false
    @State private var sortedEntries: [CollectionEntry]
    @State private var linkedSavedSearchId: UUID?
    /// Front matter (Authoring Phase 4): title-page subtitle, live-autosaved like name/note.
    @State private var collectionSubtitle: String
    /// Front matter: title-page author line. The active Project name is offered as the
    /// field's *placeholder* only — a suggestion, never persisted automatically.
    @State private var collectionAuthorLine: String
    /// Front matter: whether exports end with the colophon page/footer (default off).
    @State private var includeColophon: Bool
    /// Headings whose sections are currently collapsed in the outline — VIEW STATE only
    /// (Phase 4): never persisted, never synced; keyed by entry id so it survives moves.
    @State private var collapsedHeadingIds: Set<UUID> = []

    @State private var showAddDocuments   = false
    /// A transient "Added N documents" confirmation toast after the Add Documents sheet commits (5).
    @State private var addDocumentsToast: String?
    /// Presents the bulk "Add Highlighted Passages" sheet (Authoring Phase 5).
    @State private var showAddHighlights  = false
    @State private var showExport         = false
    @State private var showTimeline       = false
    @State private var showLinkSavedSearch = false
    @State private var exportError: String?

    /// Bulk-loaded per-document display data (headers + ISO dates from the index), keyed
    /// `"volumeId/documentId"` — the same pane-level pattern as the macOS manager, so
    /// entry rows show real document identities and Sort by Date has per-document
    /// precision (Authoring Phase 1 row parity).
    @State private var documentHeaders: [String: String] = [:]
    @State private var documentDates: [String: String] = [:]

    /// iPad Collection settings sheet visibility (Composer v2 §A: the ⚙ Collection toolbar sheet
    /// replaces the persistent metadata/composition inspector column).
    @State private var showCollectionSettings = false
    /// The document entry whose per-entry inspector is open (Collections Manager M2, D3/
    /// M2.4). On iPad (regular width) this drives the shared trailing `.inspector` column
    /// — set = show the entry inspector, `nil` = show the collection-metadata inspector
    /// (one inspector surface, either/or). On iPhone (compact) it drives the `.sheet`.
    @State private var inspectedEntryId: UUID?
    /// Pending inline note-create context (Collections Manager M2, D5): the "New Note…"
    /// affordance in the entry inspector's per-note list opens `InlineNoteCreateSheet`
    /// for this document, linking the created note to the entry when appropriate.
    @State private var noteCreateContext: NoteCreateContext?

    /// Identifies the document an inline `InlineNoteCreateSheet` is creating a note for
    /// (Collections Manager M2, D5); `entryIndex` locates the owning entry to link.
    private struct NoteCreateContext: Identifiable {
        let id = UUID()
        let documentId: String
        let volumeId: String
        let entryIndex: Int
    }
    /// iPhone Outline | Preview pane selection (Authoring Phase 2b; view-local).
    @State private var editorPane: EditorPane = .outline
    /// The preview's "Render All" cap lift, hoisted here so it survives pane toggles
    /// that recreate `CollectionPreviewView` (one editor session = one lift).
    @State private var previewRenderAll = false

    /// Which surface the compact-width (iPhone) editor shows (Authoring Phase 2b).
    private enum EditorPane: String, CaseIterable {
        /// The entries outline — the editing Form.
        case outline
        /// The live HTML preview.
        case preview
    }

    /// How the editor is presented, which decides its navigation chrome (Authoring
    /// Phase 1 shell).
    enum PresentationStyle {
        /// Modal sheet (Document view, project context, Stage Manager scenes): the editor
        /// provides its own `NavigationStack` and a Done button.
        case sheet
        /// Pushed onto an existing `NavigationStack` (the Collections tab): no nested
        /// stack; the back button dismisses.
        case pushed
    }
    private let presentationStyle: PresentationStyle

    // MARK: - Init

    init(collection: Collection?, presentationStyle: PresentationStyle = .sheet) {
        self.presentationStyle = presentationStyle
        if let c = collection {
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: c.name)
            _collectionNote = State(initialValue: c.note ?? "")
            _sortedEntries = State(initialValue:
                (c.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder })
            _linkedSavedSearchId = State(initialValue: c.savedSearchId)
            _collectionSubtitle = State(initialValue: c.subtitle ?? "")
            _collectionAuthorLine = State(initialValue: c.authorLine ?? "")
            _includeColophon = State(initialValue: c.includeColophon)
            isNewCollection = false
        } else {
            let c = Collection(name: "")
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: "")
            _collectionNote = State(initialValue: "")
            _sortedEntries = State(initialValue: [])
            _linkedSavedSearchId = State(initialValue: nil)
            _collectionSubtitle = State(initialValue: "")
            _collectionAuthorLine = State(initialValue: "")
            _includeColophon = State(initialValue: false)
            isNewCollection = true
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
        }
        .transientToast($addDocumentsToast)
        // Reload document headers and per-document dates whenever the entry list changes.
        // (The Group has exactly one child per platform, so this task attaches once.)
        .task(id: sortedEntries.map(\.id)) {
            (documentHeaders, documentDates) =
                await CollectionEntryData.load(for: sortedEntries, appState: appState)
        }
        // All-live autosave (A1): every field edit lands on the model immediately, the
        // same semantics as the macOS manager (and what CloudKit sync implies anyway).
        .onChange(of: collectionName) { _, _ in saveLive() }
        .onChange(of: collectionNote) { _, _ in saveLive() }
        .onChange(of: linkedSavedSearchId) { _, _ in saveLive() }
        .onChange(of: collectionSubtitle) { _, _ in saveLive() }
        .onChange(of: collectionAuthorLine) { _, _ in saveLive() }
        .onChange(of: includeColophon) { _, _ in saveLive() }
        // The one special case: a brand-new collection the user backed out of without
        // touching anything is discarded; a kept-but-unnamed one gets a default name so
        // it doesn't render as a blank list row.
        .onDisappear {
            guard isNewCollection else { return }
            let untouched = collection.name.isEmpty && collection.note == nil
                && sortedEntries.isEmpty && collection.savedSearchId == nil
                && collection.subtitle == nil && collection.authorLine == nil
                && collection.introductionText == nil && !collection.includeColophon
            if untouched {
                modelContext.delete(collection)
            } else if collection.name.isEmpty {
                collection.name = String(localized: "collection.editor.untitled",
                                         defaultValue: "Untitled Collection")
            }
        }
        .sheet(isPresented: $showTimeline) {
            #if os(macOS)
            // macOS: plain content + bottom button bar (no NavigationStack chrome)
            VStack(spacing: 0) {
                DocumentTimelineView(
                    // Document entries only — matching how orderedDocumentKeys and the
                    // export document counts scope. Excerpts carry their source
                    // document's provenance ids, so mapping them too would double-count
                    // that document's year and duplicate the Item id ("volume/doc").
                    items: sortedEntries.filter { $0.entryKind == .document }.map {
                        DocumentTimelineView.Item(
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            header: $0.documentId
                        )
                    }
                )
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "common.done", defaultValue: "Done")) {
                        showTimeline = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(minWidth: 480, minHeight: 440)
            #else
            NavigationStack {
                DocumentTimelineView(
                    // Document entries only — see the macOS branch above for why
                    // excerpt entries must not contribute timeline items.
                    items: sortedEntries.filter { $0.entryKind == .document }.map {
                        DocumentTimelineView.Item(
                            volumeId: $0.volumeId,
                            documentId: $0.documentId,
                            header: $0.documentId
                        )
                    }
                )
                .navigationTitle(
                    String(localized: "timeline.sheet.title", defaultValue: "Timeline")
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) {
                            showTimeline = false
                        }
                    }
                }
            }
            #endif
        }
    }

    // MARK: - macOS Body
    //
    // NavigationStack inside a macOS sheet renders with sidebar chrome that pushes
    // form content leftward past the window edge. Use a plain VStack with an explicit
    // button bar instead.

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar row
            HStack {
                Text(isNewCollection
                     ? String(localized: "collection.editor.title.new", defaultValue: "New Collection")
                     : String(localized: "collection.editor.title.edit", defaultValue: "Edit Collection"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            // Form content
            Form {
                nameSection
                noteSection
                frontMatterSection
                compositionSection
                smartCollectionSection
                documentsSection
                addDocumentsSection
                if !sortedEntries.isEmpty || linkedSavedSearchId != nil {
                    actionsSection
                }
            }
            .formStyle(.grouped)

            Divider()

            // Button bar. All edits save live (A1); Done just dismisses. The untouched
            // new-collection discard happens in the shared `onDisappear`.
            HStack {
                Spacer()

                Button(String(localized: "common.done", defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 460)
        .sheet(isPresented: $showAddDocuments) {
            CollectionAddDocumentsSheet(
                allTags: allTags,
                allNotes: allNotes,
                existingDocumentKeys: existingDocumentKeys
            ) { picks in
                appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) })
                addDocumentsToast = CollectionDocumentDiscovery.addedToastMessage(picks.count)
            }
        }
        .sheet(isPresented: $showAddHighlights) {
            CollectionAddHighlightsSheet(
                documentKeys: orderedDocumentKeys,
                documentLabels: documentHeaders
            ) { captures in
                appendExcerpts(captures)
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSheetView(
                collection: collection,
                entries: sortedEntries,
                allNotes: allNotes,
                appState: appState
            )
        }
        .sheet(isPresented: $showLinkSavedSearch) {
            linkSavedSearchSheet
        }
        .alert(
            String(localized: "collection.editor.export.error.title", defaultValue: "Export Failed"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            ),
            presenting: exportError
        ) { _ in
            Button(String(localized: "collection.editor.export.error.dismiss", defaultValue: "OK")) {}
        } message: { msg in
            Text(msg)
        }
        .onAppear {
            if isNewCollection {
                modelContext.insert(collection)
            }
        }
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        Group {
            if presentationStyle == .pushed {
                // Pushed onto the presenting context's NavigationStack (the Collections
                // tab): no nested stack, the back button dismisses.
                iOSContent
            } else {
                // Modal sheet (Document view, project context, Stage Manager scenes):
                // the editor provides its own stack and a Done button.
                NavigationStack {
                    iOSContent
                }
                #if os(iOS)
                .presentationDetents([.large])
                #endif
            }
        }
    }

    /// The editor's iOS content and chrome, shared by the pushed and sheet presentations.
    private var iOSContent: some View {
        Group {
            #if os(iOS)
            if sizeClass == .regular {
                iPadCollectionLayout
            } else {
                iPhoneCollectionLayout
            }
            #else
            iPhoneCollectionLayout
            #endif
        }
        .navigationTitle(isNewCollection
            ? String(localized: "collection.editor.title.new", defaultValue: "New Collection")
            : String(localized: "collection.editor.title.edit", defaultValue: "Edit Collection"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // All edits save live (A1); a sheet still needs an explicit dismissal control.
            if presentationStyle == .sheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        // Collections Manager M1: the list-level authoring verbs in native chrome —
        // iPad labeled toolbar items, iPhone labeled nav-bar menu.
        #if os(iOS)
        .toolbar { collectionAuthoringToolbar }
        #endif
        .sheet(isPresented: $showAddDocuments) {
            CollectionAddDocumentsSheet(
                allTags: allTags,
                allNotes: allNotes,
                existingDocumentKeys: existingDocumentKeys
            ) { picks in
                appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) })
                addDocumentsToast = CollectionDocumentDiscovery.addedToastMessage(picks.count)
            }
        }
        .sheet(isPresented: $showAddHighlights) {
            CollectionAddHighlightsSheet(
                documentKeys: orderedDocumentKeys,
                documentLabels: documentHeaders
            ) { captures in
                appendExcerpts(captures)
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSheetView(
                collection: collection,
                entries: sortedEntries,
                allNotes: allNotes,
                appState: appState
            )
        }
        .sheet(isPresented: $showLinkSavedSearch) {
            linkSavedSearchSheet
        }
        .alert(
            String(localized: "collection.editor.export.error.title", defaultValue: "Export Failed"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            ),
            presenting: exportError
        ) { _ in
            Button(String(localized: "collection.editor.export.error.dismiss", defaultValue: "OK")) {}
        } message: { msg in
            Text(msg)
        }
        // Per-entry inspector (Collections Manager M2, D3): iPhone (compact) drills IN — a push onto
        // the editor's navigation stack (Composer redesign 4); iPad (regular) hosts it in the shared
        // trailing `.inspector` column instead (see `iPadCollectionLayout`), so the outline stays
        // visible while it edits.
        .navigationDestination(isPresented: Binding(
            get: { inspectedEntryId != nil && !isRegularWidth },
            set: { if !$0 { inspectedEntryId = nil } }
        )) {
            if let entry = inspectedEntry {
                // Composer v2 §C: document-only — the collection's settings/composition live in the
                // top Collection Settings drill-in now, so the per-document push omits the collection
                // section (mirroring the iPad Configure sheet).
                entryInspectorContent(entry, isPushed: true, documentOnly: true)
            }
        }
        // Inline note-create (Collections Manager M2, D5): the entry inspector's
        // "New Note…" affordance links the created note to its document entry.
        .sheet(item: $noteCreateContext) { ctx in
            InlineNoteCreateSheet(
                documentId: ctx.documentId,
                volumeId: ctx.volumeId,
                activeProjectId: appState.activeProjectId
            ) { newNote in
                // D5: the note is on this document, so an untouched entry (empty = all)
                // already includes it. Only append when the user has an explicit partial
                // selection so the new note joins it.
                if ctx.entryIndex < sortedEntries.count,
                   !sortedEntries[ctx.entryIndex].selectedNoteIds.isEmpty {
                    sortedEntries[ctx.entryIndex].selectedNoteIds.append(newNote.id)
                }
            }
            .environment(appState)
        }
        .onAppear {
            if isNewCollection {
                modelContext.insert(collection)
            }
        }
    }

    // MARK: - iOS Form Variants

    /// iPhone (compact width) shell: a segmented Outline | Preview control pinned above
    /// the content (Authoring Phase 2b). Outline shows the editing Form; Preview swaps
    /// in the live `CollectionPreviewView`. Selection is view-local.
    private var iPhoneCollectionLayout: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "collection.editor.pane.picker", defaultValue: "View"),
                   selection: $editorPane) {
                Text(String(localized: "collection.editor.pane.outline",
                            defaultValue: "Outline")).tag(EditorPane.outline)
                Text(String(localized: "collection.editor.pane.preview",
                            defaultValue: "Preview")).tag(EditorPane.preview)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if editorPane == .outline {
                iPhoneCollectionForm
            } else {
                CollectionPreviewView(collection: collection,
                                      entries: sortedEntries,
                                      allNotes: allNotes,
                                      renderAll: $previewRenderAll)
            }
        }
    }

    /// iPhone (compact width): the entry list is the primary surface. Metadata lives in a
    /// collapsible Details group above it (expanded for a new collection so the name field
    /// is immediately available, collapsed to a single row otherwise), and Composition in
    /// a collapsed disclosure below.
    private var iPhoneCollectionForm: some View {
        Form {
            // Composer v2 §C: one Collection Settings drill-in pinned at the top (front matter +
            // presets + the three composition groups + smart link), then the Contents outline as the
            // primary surface. Replaces the old inline Details disclosure + bottom composition row.
            collectionSettingsDrillInSection
            documentsSection
            addDocumentsSection
            if !sortedEntries.isEmpty || linkedSavedSearchId != nil { actionsSection }
        }
    }

    /// The single **Collection Settings** drill-in row (Composer v2 §C, iPhone): the top entry on the
    /// Outline screen, captioned with the plain-language composition summary. Tapping pushes the full
    /// settings screen. Replaces the old inline Details disclosure (which carried an info.circle glyph)
    /// and the composition-only drill-in — one clearly labeled collection-scope entry, the compact
    /// equivalent of the iPad ⚙ Collection sheet.
    private var collectionSettingsDrillInSection: some View {
        // Caption leads with the active preset when one matches (canvas: "Briefing packet ·
        // summaries"), else the plain-language composition summary for a customized composition.
        let activePreset = CollectionPreset.allCases.first { $0.matches(collection) }
        let caption = activePreset.map { "\($0.displayName) · \($0.shortTag)" }
            ?? collection.compositionSummarySentence
        return Section {
            NavigationLink {
                iPhoneCollectionSettingsScreen
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "collection.editor.settings.title",
                                    defaultValue: "Collection settings"))
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    /// The pushed Collection Settings screen (iPhone drill-in): leads with the presets + the three
    /// grouped composition sections, then title-page front matter, then the collection's name / note
    /// and the smart-collection link — the compact-platform equivalent of the iPad ⚙ Collection sheet.
    /// `CollectionCompositionRows` is placed directly (not via `compositionSection`, which forces the
    /// 2×2 preset grid for the wide iPad sheet) so its presets render as the compact 3-chip row here.
    private var iPhoneCollectionSettingsScreen: some View {
        Form {
            // Composer v2 §C: lead with the presets + three composition groups (compact 3-chip
            // presets — see the note above), then title-page front matter, then name / note / smart.
            CollectionCompositionRows(collection: collection, onApplyPreset: { applyPreset($0) })
            frontMatterSection
            nameSection
            noteSection
            smartCollectionSection
        }
        .navigationTitle(String(localized: "collection.editor.settings.title",
                                defaultValue: "Collection settings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// iPad (regular width) — Composer v2 §A: two roomy permanent columns, **Contents** (the outline)
    /// and the **live preview**, with all settings summoned on demand as dismissible sheets — the
    /// ⚙ Collection toolbar button and each row's ⚙ Configure — so the reading surface stays clear.
    /// Replaces the earlier 3-pane layout (a persistent metadata/composition `.inspector` column plus
    /// a toggled preview).
    private var iPadCollectionLayout: some View {
        HStack(spacing: 0) {
            // Contents outline — bounded width so the live preview takes the rest.
            Form {
                documentsSection
                addDocumentsSection
            }
            .formStyle(.grouped)
            .frame(maxWidth: 460)

            Divider()

            // Live preview (permanent) — the collection rendered exactly as its HTML export.
            CollectionPreviewView(collection: collection,
                                  entries: sortedEntries,
                                  allNotes: allNotes,
                                  renderAll: $previewRenderAll)
                .frame(maxWidth: .infinity)
        }
        // Collection-wide settings — from the ⚙ Collection toolbar button.
        .sheet(isPresented: $showCollectionSettings) {
            iPadCollectionSettingsSheet
        }
        // Per-document settings — from a row's ⚙ Configure. Document-only (composition lives in the
        // ⚙ Collection sheet). iPhone (compact) drills in instead — see the editor's
        // per-entry `.navigationDestination`.
        .sheet(isPresented: Binding(
            get: { inspectedEntryId != nil && isRegularWidth },
            set: { if !$0 { inspectedEntryId = nil } }
        )) {
            if let entry = inspectedEntry {
                entryInspectorContent(entry, documentOnly: true)
            }
        }
    }

    /// The iPad ⚙ Collection settings sheet (Composer v2 §A): a dismissible form sheet holding the
    /// collection's name/note, title-page front matter, presets + the three grouped composition
    /// sections, and the smart-collection link — everything that lived in the old persistent
    /// metadata/composition inspector column.
    private var iPadCollectionSettingsSheet: some View {
        NavigationStack {
            Form {
                // Composer v2 §A (03-prototype): the settings sheet leads with the presets +
                // composition groups ("Start from a template"), then title-page front matter, then the
                // collection's name / note / smart-link. The canvas edits name via the toolbar title;
                // the sheet keeps it reachable at the end for rename.
                compositionSection
                frontMatterSection
                nameSection
                noteSection
                smartCollectionSection
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "collection.editor.settings.title",
                                    defaultValue: "Collection settings"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) {
                        showCollectionSettings = false
                    }
                }
            }
        }
    }

    // MARK: - Smart Collection Section

    @ViewBuilder
    private var smartCollectionSection: some View {
        Section {
            smartCollectionRows
        } header: {
            Text(String(localized: "collection.editor.smart.header",
                        defaultValue: "Smart Collection"))
        }
    }

    /// The smart-collection link/unlink rows, usable inside any container (the iPhone
    /// Details disclosure or the sectioned forms).
    @ViewBuilder
    private var smartCollectionRows: some View {
        Group {
            if let searchId = linkedSavedSearchId,
               let savedSearch = allSavedSearches.first(where: { $0.id == searchId }) {
                HStack {
                    Label(savedSearch.name, systemImage: "bolt.fill")
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Button(String(localized: "collection.editor.smart.unlink",
                                  defaultValue: "Unlink")) {
                        linkedSavedSearchId = nil
                    }
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                    .font(.callout)
                }
                Text(String(localized: "collection.editor.smart.explanation",
                            defaultValue: "Documents are resolved from this saved search at export time. Static entries are ignored."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showLinkSavedSearch = true
                } label: {
                    Label(String(localized: "collection.editor.smart.link",
                                 defaultValue: "Link to Saved Search\u{2026}"),
                          systemImage: "bolt")
                }
                .disabled(allSavedSearches.isEmpty)
                if allSavedSearches.isEmpty {
                    Text(String(localized: "collection.editor.smart.noSearches",
                                defaultValue: "Save a search from the Search tab to enable smart collections."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Link Saved Search Sheet

    private var linkSavedSearchSheet: some View {
        #if os(macOS)
        linkSavedSearchMacBody
        #else
        linkSavedSearchiOSBody
        #endif
    }

    #if os(macOS)
    /// macOS variant: plain VStack + button bar avoids the NavigationStack sidebar issue.
    private var linkSavedSearchMacBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "collection.editor.smart.picker.title",
                            defaultValue: "Link to Saved Search"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            if allSavedSearches.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(String(localized: "collection.editor.smart.picker.empty",
                                defaultValue: "No saved searches yet. Save a search from the Search window first."))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
            } else {
                List(allSavedSearches) { search in
                    Button {
                        linkedSavedSearchId = search.id
                        showLinkSavedSearch = false
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(search.name).font(.body)
                            if !search.queryText.isEmpty {
                                Text(search.queryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "collection.editor.smart.picker.cancel",
                              defaultValue: "Cancel")) {
                    showLinkSavedSearch = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 360, minHeight: 280)
    }
    #endif

    /// iOS / iPadOS variant: NavigationStack with inline title and Cancel toolbar button.
    private var linkSavedSearchiOSBody: some View {
        NavigationStack {
            List(allSavedSearches) { search in
                Button {
                    linkedSavedSearchId = search.id
                    showLinkSavedSearch = false
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(search.name).font(.body)
                        if !search.queryText.isEmpty {
                            Text(search.queryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(String(localized: "collection.editor.smart.picker.title",
                                    defaultValue: "Link to Saved Search"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.editor.smart.picker.cancel",
                                  defaultValue: "Cancel")) {
                        showLinkSavedSearch = false
                    }
                }
            }
        }
    }

    // MARK: - Name Section

    /// The bare name field, usable inside any container (iPhone Details disclosure,
    /// iPad inspector's `nameSection`, macOS form).
    private var nameField: some View {
        TextField(
            String(localized: "collection.editor.name.placeholder", defaultValue: "Collection Name"),
            text: $collectionName
        )
        .accessibilityLabel(String(localized: "collection.editor.name.accessibility",
                                   defaultValue: "Collection name"))
    }

    private var nameSection: some View {
        Section(String(localized: "collection.editor.name.header", defaultValue: "Name")) {
            nameField
        }
    }

    // MARK: - Note Section

    /// The bare note field, usable inside any container (see `nameField`).
    ///
    /// Collapses to a compact "Add a note" button until the collection has a
    /// note (or the user taps to add one), so the optional note does not consume
    /// several lines of vertical space by default.
    @ViewBuilder private var noteField: some View {
        if isAddingNote || !collectionNote.isEmpty {
            TextField(
                String(localized: "collection.editor.note.placeholder",
                       defaultValue: "Optional note about this collection…"),
                text: $collectionNote,
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "collection.editor.note.accessibility",
                                       defaultValue: "Collection note"))
        } else {
            Button {
                isAddingNote = true
            } label: {
                Label(String(localized: "collection.editor.note.add",
                             defaultValue: "Add a note"),
                      systemImage: "note.text")
            }
            .accessibilityLabel(String(localized: "collection.editor.note.add.accessibility",
                                       defaultValue: "Add a collection note"))
        }
    }

    private var noteSection: some View {
        Section(String(localized: "collection.editor.note.header", defaultValue: "Note")) {
            noteField
        }
    }

    // MARK: - Front Matter (Authoring Phase 4)

    /// The active project's name, offered as the author-line *placeholder* — a
    /// suggestion only, never written to the model unless the user types it.
    private var authorPlaceholder: String {
        if let pid = appState.activeProjectId,
           let project = allProjects.first(where: { $0.id == pid }),
           !project.name.isEmpty {
            return project.name
        }
        return String(localized: "collection.frontmatter.author.placeholder",
                      defaultValue: "Author")
    }

    /// Title-page and introduction fields (Authoring Phase 4), usable inside any
    /// container (iPhone Details disclosure, iPad inspector, macOS sheet form). All
    /// live-autosave; an empty field stores `nil`, keeping exports byte-identical to
    /// pre-Phase-4 output until something is actually set.
    @ViewBuilder
    private var frontMatterRows: some View {
        TextField(
            String(localized: "collection.frontmatter.subtitle.placeholder",
                   defaultValue: "Subtitle (title page)"),
            text: $collectionSubtitle
        )
        .accessibilityLabel(String(localized: "collection.frontmatter.subtitle.accessibility",
                                   defaultValue: "Collection subtitle"))
        TextField(authorPlaceholder, text: $collectionAuthorLine)
            .accessibilityLabel(String(localized: "collection.frontmatter.author.accessibility",
                                       defaultValue: "Author line"))
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "collection.frontmatter.introduction.label",
                        defaultValue: "Introduction"))
                .font(.caption)
                .foregroundStyle(.secondary)
            RichTextEditor(initialRTF: collection.introductionRichText,
                           plainFallback: collection.introductionText ?? "") { rtf, plain in
                saveIntroduction(rtf: rtf, plain: plain)
            }
            .frame(minHeight: 80, maxHeight: 200)
        }
        Toggle(isOn: $includeColophon) {
            Text(String(localized: "collection.frontmatter.colophon.toggle",
                        defaultValue: "Include colophon"))
        }
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
    }

    /// The front-matter rows as a titled form section (iPad inspector, macOS sheet form).
    private var frontMatterSection: some View {
        Section {
            frontMatterRows
        } header: {
            Text(String(localized: "collection.frontmatter.header",
                        defaultValue: "Title Page & Introduction"))
        } footer: {
            Text(String(localized: "collection.frontmatter.footer",
                        defaultValue: "Rendered on the exported title page; the introduction opens the body, after the table of contents and before the first document. Leave blank to keep the plain document layout."))
        }
    }

    /// Writes the introduction onto the model, live (the rich-text editor reports every
    /// edit). An effectively empty introduction stores `nil` in both fields, so exports
    /// omit the block entirely.
    private func saveIntroduction(rtf: Data?, plain: String) {
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            collection.introductionText = nil
            collection.introductionRichText = nil
        } else {
            collection.introductionText = plain
            collection.introductionRichText = rtf
        }
        try? modelContext.save()
    }

    // MARK: - Composition Section

    /// The persisted export-content settings (body depth, footnotes, notes, highlights, etc.),
    /// as the three labeled Composer groups. `CollectionCompositionRows` owns its own Sections, so
    /// this host places it directly rather than wrapping it in one Composition section.
    private var compositionSection: some View {
        // The iPad ⚙ Collection sheet is wide enough for the 2×2 preset grid even though an iPadOS
        // form sheet reports a compact size class — force the grid so all four presets (including
        // Scholarly edition) are reachable.
        CollectionCompositionRows(collection: collection, onApplyPreset: { applyPreset($0) },
                                  presetsCompact: false)
    }

    // MARK: - Documents Section

    @ViewBuilder
    private var documentsSection: some View {
        Section {
            if sortedEntries.isEmpty {
                if linkedSavedSearchId != nil {
                    Text(String(localized: "collection.editor.docs.smartEmpty",
                                defaultValue: "This is a smart collection. Its documents are resolved from the linked saved search when you export — use Export in Actions below."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "collection.editor.docs.empty",
                                defaultValue: "No content yet. Add documents, headings, notes, and apparatus from the toolbar above."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                let duplicateKeys = duplicateDocumentKeys
                let outline = CollectionOutline.linearize(sortedEntries)
                let rows = CollectionOutline.visibleRows(
                    in: outline, collapsedHeadingIds: collapsedHeadingIds)
                ForEach(rows) { row in
                    outlineRow(row, outline: outline, duplicateKeys: duplicateKeys,
                               rows: rows)
                        .padding(.leading, outlineIndent(for: row))
                }
                .onMove { indices, newOffset in
                    moveVisibleRows(indices, to: newOffset, visible: rows.map(\.index))
                }
                .onDelete { indexSet in
                    deleteVisibleRows(indexSet, visible: rows.map(\.index))
                }
            }
        } header: {
            HStack {
                // Collections Manager M1 (D1): the region is "Contents" — it holds
                // documents plus headings, prose, excerpts, and apparatus.
                Text(String(localized: "collection.editor.docs.header", defaultValue: "Contents"))
                Spacer()
                // M1: the structural/apparatus verbs move to native chrome — the iPad
                // toolbar (labeled `ToolbarItem`s, gated to regular width) and the
                // iPhone nav-bar `primaryAction` menu (labeled, not a bare "+" glyph),
                // both wired in `collectionAuthoringToolbar`. The in-list header keeps
                // only the timeline glance and the edit-mode toggle.
                if !sortedEntries.isEmpty {
                    Button {
                        showTimeline = true
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "collection.editor.docs.timeline.a11y",
                               defaultValue: "Show document timeline")
                    )
                }
                #if os(iOS)
                // EditButton toggles edit mode so drag-handles and swipe-to-delete appear.
                // On macOS, onMove and onDelete are accessible without explicit edit mode
                // (drag handles appear automatically; Delete key / context menu handles deletion).
                if !sortedEntries.isEmpty {
                    EditButton()
                        .font(.caption)
                }
                #endif
            }
        }
    }

    // MARK: - Authoring toolbar (Collections Manager M1)

    /// The list-level authoring verbs promoted into native chrome (M1): on iPad
    /// (regular width) each verb is a labeled `ToolbarItem`; on iPhone (compact
    /// width) they collapse into one labeled `primaryAction` nav-bar menu — no bare
    /// glyphs on either. The parity win is text+glyph labels everywhere.
    #if os(iOS)
    @ToolbarContentBuilder
    private var collectionAuthoringToolbar: some ToolbarContent {
        if sizeClass == .regular {
            // iPad (Composer v2 §A): a consolidated toolbar — ⚙ Collection (opens the settings
            // sheet), ＋ Add (a menu of the content verbs), Sort by Date, and Export.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCollectionSettings = true
                } label: {
                    Label(String(localized: "collection.editor.settings.button", defaultValue: "Collection"),
                          systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                iPadAddMenu
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    sortByDateScopeItems
                } label: {
                    // Composer v2 §Export toolbar: the trigger reads "Sort" (the menu supplies the ⌄);
                    // the two date-sort scopes live inside. VoiceOver keeps the fuller description.
                    Label(String(localized: "collection.sort.short", defaultValue: "Sort"),
                          systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel(String(localized: "collection.sort.date.accessibility",
                                           defaultValue: "Sort by date"))
                .disabled(sortedEntries.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showExport = true
                } label: {
                    Label(String(localized: "collection.editor.actions.export", defaultValue: "Export…"),
                          systemImage: "square.and.arrow.up")
                }
            }
        } else {
            // iPhone: one labeled nav-bar menu (Labels, not a bare "+" glyph).
            ToolbarItem(placement: .primaryAction) {
                iPhoneAddMenu
            }
        }
    }

    /// iPhone (compact width): a single labeled `primaryAction` menu carrying every
    /// list-level authoring verb — Add Documents plus the structural/apparatus items
    /// (M1). The Outline | Preview segmented control stays put in the layout.
    private var iPhoneAddMenu: some View {
        Menu {
            Button {
                showAddDocuments = true
            } label: {
                Label(String(localized: "collection.editor.addDocuments.button",
                             defaultValue: "Add Documents…"),
                      systemImage: "plus.rectangle.on.folder")
            }
            Divider()
            Button {
                addStructuralEntry(kind: .heading)
            } label: {
                Label(String(localized: "collection.add.heading", defaultValue: "Add Section Heading"),
                      systemImage: "number")
            }
            Button {
                addStructuralEntry(kind: .prose)
            } label: {
                Label(String(localized: "collection.add.prose", defaultValue: "Add Note Block"),
                      systemImage: "text.alignleft")
            }
            Button {
                showAddHighlights = true
            } label: {
                Label(String(localized: "collection.add.highlights",
                             defaultValue: "Add Highlighted Passages…"),
                      systemImage: "text.quote")
            }
            .disabled(orderedDocumentKeys.isEmpty)
            Menu {
                ForEach(CollectionGeneratedBlockType.allCases) { blockType in
                    Button {
                        addGeneratedEntry(type: blockType)
                    } label: {
                        Label(blockType.displayName, systemImage: blockType.systemImage)
                    }
                }
            } label: {
                Label(String(localized: "collection.add.apparatus", defaultValue: "Apparatus"),
                      systemImage: "list.bullet.rectangle")
            }
            Divider()
            Menu {
                sortByDateScopeItems
            } label: {
                Label(String(localized: "collection.sort.date", defaultValue: "Sort by Date"),
                      systemImage: "arrow.up.arrow.down")
            }
            .disabled(sortedEntries.isEmpty)
        } label: {
            Label(String(localized: "collection.add.menu.label", defaultValue: "Add"),
                  systemImage: "plus")
        }
        .accessibilityLabel(String(localized: "collection.add.menu",
                                   defaultValue: "Add documents, a section heading, a note block, highlighted passages, or an apparatus block"))
    }

    /// iPad (Composer v2 §A): the ＋ Add toolbar menu — the content verbs (Documents plus the
    /// structural / apparatus items). Sort by Date and Export are their own iPad toolbar items.
    private var iPadAddMenu: some View {
        Menu {
            Button {
                showAddDocuments = true
            } label: {
                Label(String(localized: "collection.editor.addDocuments.button",
                             defaultValue: "Add Documents…"),
                      systemImage: "plus.rectangle.on.folder")
            }
            Divider()
            Button {
                addStructuralEntry(kind: .heading)
            } label: {
                Label(String(localized: "collection.add.heading", defaultValue: "Add Section Heading"),
                      systemImage: "number")
            }
            Button {
                addStructuralEntry(kind: .prose)
            } label: {
                Label(String(localized: "collection.add.prose", defaultValue: "Add Note Block"),
                      systemImage: "text.alignleft")
            }
            Button {
                showAddHighlights = true
            } label: {
                Label(String(localized: "collection.add.highlights",
                             defaultValue: "Add Highlighted Passages…"),
                      systemImage: "text.quote")
            }
            .disabled(orderedDocumentKeys.isEmpty)
            Menu {
                ForEach(CollectionGeneratedBlockType.allCases) { blockType in
                    Button {
                        addGeneratedEntry(type: blockType)
                    } label: {
                        Label(blockType.displayName, systemImage: blockType.systemImage)
                    }
                }
            } label: {
                Label(String(localized: "collection.add.apparatus", defaultValue: "Apparatus"),
                      systemImage: "list.bullet.rectangle")
            }
        } label: {
            Label(String(localized: "collection.add.menu.label", defaultValue: "Add"),
                  systemImage: "plus")
        }
    }
    #endif

    // MARK: - Outline rows (Authoring Phase 4)

    /// Builds the view for one visible outline row. Document/prose rows are unchanged
    /// from Phase 3; heading rows gain the outline controls (depth typography, collapse
    /// chevron, section context menu). Bindings index into `sortedEntries`, which is
    /// kept in `sortOrder` order (reindexed 0..n after every mutation), so positions
    /// align with the linearized outline. `rows` (the full visible-row list) locates
    /// this row's visible position for the A4 Move Up / Move Down actions.
    @ViewBuilder
    private func outlineRow(_ row: CollectionOutline.VisibleRow,
                            outline: [CollectionOutline.OutlineItem],
                            duplicateKeys: Set<String>,
                            rows: [CollectionOutline.VisibleRow]) -> some View {
        let entry = sortedEntries[row.index]
        // A4 reorder closures: nil at the outline's edges so the actions disappear
        // rather than silently no-op.
        let pos = rows.firstIndex { $0.id == row.id } ?? 0
        let moveUp: (() -> Void)? = pos > 0
            ? { moveVisibleRowUp(pos, rows: rows) } : nil
        let moveDown: (() -> Void)? = canMoveVisibleRowDown(pos, rows: rows)
            ? { moveVisibleRowDown(pos, rows: rows) } : nil
        switch entry.entryKind {
        case .document:
            let key = "\(entry.volumeId)/\(entry.documentId)"
            EntryRow(entry: $sortedEntries[row.index],
                     availableNotes: notes(for: entry),
                     documentHeader: documentHeaders[key],
                     volumeTitle: volumeTitle(for: entry),
                     documentDate: documentDates[key],
                     isDuplicate: duplicateKeys.contains(key),
                     onInspect: { presentEntryInspector(for: entry.id) },
                     // iPad (regular) and the macOS sheet editor show the ⚙ Configure pill; only iPhone
                     // (compact) drills in via the whole-row chevron disclosure (Composer v2 §D).
                     // `isRegularWidth` is false on macOS too, so OR in `isMacOS` to keep the pill there
                     // (macBody has no drill-in destination — a chevron would imply a push that doesn't exist).
                     showsConfigurePill: isRegularWidth || isMacOS,
                     onMoveUp: moveUp,
                     onMoveDown: moveDown)
        case .heading:
            let range = CollectionOutline.sectionRange(of: row.index, in: outline)
            CollectionHeadingRow(
                entry: $sortedEntries[row.index],
                onDelete: { deleteHeadingOnly(at: row.index) },
                showsInlineDelete: isMacOS,
                depth: row.depth,
                isCollapsed: collapsedHeadingIds.contains(row.id),
                sectionEntryCount: range.count - 1,
                onToggleCollapse: { toggleCollapse(row.id) },
                canIndent: CollectionOutline.canIndent(row.index, in: outline),
                canOutdent: CollectionOutline.canOutdent(row.index, in: outline),
                onIndent: { indentSection(at: row.index) },
                onOutdent: { outdentSection(at: row.index) },
                onDeleteSection: { deleteSection(at: row.index) },
                onMoveUp: moveUp,
                onMoveDown: moveDown
            )
        case .prose:
            CollectionProseRow(entry: $sortedEntries[row.index],
                               onMoveUp: moveUp,
                               onMoveDown: moveDown)
        case .excerpt:
            // Movable/deletable like prose; iOS deletion stays on swipe (no inline trash).
            CollectionExcerptRow(entry: entry,
                                 volumeTitle: volumeTitle(for: entry),
                                 onDelete: isMacOS ? { deleteVisibleRow(row.index) } : nil,
                                 onMoveUp: moveUp,
                                 onMoveDown: moveDown)
        case .generated:
            // Movable/deletable like prose; no body-depth or inspector controls —
            // the block resolves at export and in the live preview (Phase 6).
            CollectionGeneratedEntryRow(entry: entry,
                                        documentCount: sortedEntries.count { $0.entryKind == .document },
                                        onDelete: isMacOS ? { deleteVisibleRow(row.index) } : nil,
                                        onMoveUp: moveUp,
                                        onMoveDown: moveDown)
        case .unrecognized:
            // Deliberately no reorder actions: the entry belongs to a newer build
            // (Authoring Phase 1 sync guard) and offers no controls at all.
            UnrecognizedEntryRow()
        }
    }

    /// Deletes the single entry at a full-outline index (the excerpt row's inline trash
    /// on the macOS sheet editor; iOS deletion stays on swipe via `deleteVisibleRows`).
    private func deleteVisibleRow(_ index: Int) {
        guard sortedEntries.indices.contains(index) else { return }
        collapsedHeadingIds.remove(sortedEntries[index].id)
        GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[index], in: modelContext)
        modelContext.delete(sortedEntries[index])
        sortedEntries.remove(at: index)
        finishOutlineMutation()
    }

    /// Whether this build renders the macOS sheet editor (its List has no swipe-to-delete,
    /// so heading rows show the inline trash).
    private var isMacOS: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// Whether the layout is at regular width (iPad) — where the per-entry inspector is
    /// promoted to the shared trailing `.inspector` column rather than an iPhone `.sheet`
    /// (Collections Manager M2, M2.4). `false` on iPhone (compact) and on macOS (the
    /// macOS sheet editor keeps the per-entry `.sheet`).
    private var isRegularWidth: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        false
        #endif
    }

    /// Leading indentation for a row: headings indent by their depth above level 1;
    /// body rows indent one step inside their owning section (depth 0 — before any
    /// heading — keeps the flush pre-Phase-4 position).
    private func outlineIndent(for row: CollectionOutline.VisibleRow) -> CGFloat {
        let steps = sortedEntries[row.index].entryKind == .heading
            ? max(0, row.depth - 1)
            : row.depth
        return CGFloat(steps) * 16
    }

    /// Toggles a section's collapse chevron (view state only).
    private func toggleCollapse(_ headingId: UUID) {
        if collapsedHeadingIds.contains(headingId) {
            collapsedHeadingIds.remove(headingId)
        } else {
            collapsedHeadingIds.insert(headingId)
        }
    }

    /// Moves the dragged visible row (mapped back to full-outline coordinates) through
    /// the shared engine: a heading takes its whole section with it, a document moves
    /// alone; a section dropped into its own range is refused. Reindexes and normalizes
    /// after — global `sortOrder` semantics are untouched.
    private func moveVisibleRows(_ indices: IndexSet, to newOffset: Int, visible: [Int]) {
        guard let firstVisible = indices.min(), visible.indices.contains(firstVisible) else { return }
        let from = visible[firstVisible]
        let to = newOffset >= visible.count ? sortedEntries.count : visible[newOffset]
        guard let reordered = CollectionOutline.applyingMove(
            sortedEntries, fromIndex: from, toOffset: to) else { return }
        sortedEntries = reordered
        finishOutlineMutation()
    }

    // MARK: - Move Up / Move Down (UI audit A4)

    /// Moves the visible row at `pos` one visible position up — inserts it before the
    /// previous visible row (hopping a collapsed section whole, matching what the user
    /// sees). Drives the rows' VoiceOver/context-menu Move Up action; the same engine
    /// as drag reorder, so heading rows carry their sections.
    private func moveVisibleRowUp(_ pos: Int, rows: [CollectionOutline.VisibleRow]) {
        guard pos > 0 else { return }
        moveVisibleRows(IndexSet(integer: pos), to: pos - 1, visible: rows.map(\.index))
    }

    /// Whether the visible row at `pos` can move down: something must exist after its
    /// moved block (a heading's block is its whole `sectionRange`). Any entry after the
    /// block is visible whenever this row is (a block is followed by a same-or-shallower
    /// item whose ancestors are also this row's ancestors), so this is exactly "a
    /// visible target exists".
    private func canMoveVisibleRowDown(_ pos: Int, rows: [CollectionOutline.VisibleRow]) -> Bool {
        guard rows.indices.contains(pos) else { return false }
        return movedBlockEnd(of: rows[pos].index) < sortedEntries.count
    }

    /// Moves the visible row at `pos` one visible position down — inserts it after the
    /// first visible row past its own moved block (so an expanded heading hops its next
    /// sibling block, and a collapsed section below is hopped whole). Drives the rows'
    /// VoiceOver/context-menu Move Down action.
    private func moveVisibleRowDown(_ pos: Int, rows: [CollectionOutline.VisibleRow]) {
        let visible = rows.map(\.index)
        guard rows.indices.contains(pos) else { return }
        let blockEnd = movedBlockEnd(of: visible[pos])
        guard let nextPos = visible.indices.first(where: { visible[$0] >= blockEnd }) else { return }
        moveVisibleRows(IndexSet(integer: pos), to: nextPos + 1, visible: visible)
    }

    /// The exclusive end of the block `applyingMove` would carry for the entry at
    /// `fullIndex`: a heading's whole `sectionRange`, any other row just itself.
    private func movedBlockEnd(of fullIndex: Int) -> Int {
        guard sortedEntries.indices.contains(fullIndex) else { return sortedEntries.count }
        if sortedEntries[fullIndex].entryKind == .heading {
            let items = CollectionOutline.linearize(sortedEntries)
            return CollectionOutline.sectionRange(of: fullIndex, in: items).upperBound
        }
        return fullIndex + 1
    }

    /// Deletes the swiped visible rows (mapped to full-outline coordinates). Deleting a
    /// heading this way removes the heading only — its entries stay and any sub-headings
    /// bubble up via normalize.
    private func deleteVisibleRows(_ indices: IndexSet, visible: [Int]) {
        let full = indices.compactMap { visible.indices.contains($0) ? visible[$0] : nil }
        for i in full.sorted(by: >) {
            collapsedHeadingIds.remove(sortedEntries[i].id)
            GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[i], in: modelContext)
            modelContext.delete(sortedEntries[i])
            sortedEntries.remove(at: i)
        }
        finishOutlineMutation()
    }

    /// Indents the section at `index` one level via the shared outline mutation.
    private func indentSection(at index: Int) {
        CollectionOutline.indentSection(at: index, in: sortedEntries)
        try? modelContext.save()
    }

    /// Outdents the section at `index` one level via the shared outline mutation.
    private func outdentSection(at index: Int) {
        CollectionOutline.outdentSection(at: index, in: sortedEntries)
        try? modelContext.save()
    }

    /// Deletes the heading at `index` ONLY — its contents stay and sub-headings bubble
    /// up one level (normalize's orphan clamp).
    private func deleteHeadingOnly(at index: Int) {
        guard sortedEntries.indices.contains(index) else { return }
        collapsedHeadingIds.remove(sortedEntries[index].id)
        GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[index], in: modelContext)
        modelContext.delete(sortedEntries[index])
        sortedEntries.remove(at: index)
        finishOutlineMutation()
    }

    /// Deletes the heading at `index` and every entry in its section range (the user
    /// confirmed in the row's dialog).
    private func deleteSection(at index: Int) {
        let items = CollectionOutline.linearize(sortedEntries)
        let range = CollectionOutline.sectionRange(of: index, in: items)
        guard range.upperBound <= sortedEntries.count else { return }
        for i in range.reversed() {
            collapsedHeadingIds.remove(sortedEntries[i].id)
            GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[i], in: modelContext)
            modelContext.delete(sortedEntries[i])
            sortedEntries.remove(at: i)
        }
        finishOutlineMutation()
    }

    /// The shared tail of every outline mutation: reindex `sortOrder` 0..n, normalize
    /// heading levels (no orphan jumps persist), and save.
    private func finishOutlineMutation() {
        reindexEntries()
        CollectionOutline.normalize(sortedEntries)
        try? modelContext.save()
    }

    // MARK: - Add Documents Section

    /// Opens the Phase 3 discovery sheet (Search | Browse | Citations | Tags). Added
    /// documents are appended at the end of the entry list in selection order.
    private var addDocumentsSection: some View {
        Section {
            Button {
                showAddDocuments = true
            } label: {
                Label(
                    String(localized: "collection.editor.addDocuments.button",
                           defaultValue: "Add Documents…"),
                    systemImage: "plus.rectangle.on.folder"
                )
            }
        } footer: {
            Text(String(localized: "collection.editor.addDocuments.footer",
                        defaultValue: "Search the index, browse volumes, paste citations or history.state.gov links, or gather a tag. New documents are added to the end of the list."))
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section(String(localized: "collection.editor.actions.header", defaultValue: "Actions")) {
            // "Sort by Date" reorders static entries; a smart collection has none
            // (its documents are resolved from the saved search at export time),
            // so only offer it when there are static entries to sort.
            if !sortedEntries.isEmpty {
                Menu {
                    sortByDateScopeItems
                } label: {
                    Label(
                        String(localized: "collection.editor.actions.sortByDate",
                               defaultValue: "Sort by Date"),
                        systemImage: "calendar"
                    )
                }
            }

            Button {
                showExport = true
            } label: {
                Label(
                    String(localized: "collection.editor.actions.export",
                           defaultValue: "Export…"),
                    systemImage: "square.and.arrow.up"
                )
            }
        }
    }

    // MARK: - Helpers

    /// Document keys appearing on more than one entry, for the "Also in collection"
    /// badge (A4). Cheap O(n) recompute over the pane-level entry list.
    private var duplicateDocumentKeys: Set<String> {
        CollectionDocumentDiscovery.duplicateDocumentKeys(in: sortedEntries)
    }

    /// Keys of every document currently in the collection, handed to the Add Documents
    /// sheet for its "In collection" row indicator.
    private var existingDocumentKeys: Set<String> {
        Set(sortedEntries.filter { $0.entryKind == .document }
            .map { CollectionDocumentDiscovery.documentKey(volumeId: $0.volumeId,
                                                           documentId: $0.documentId) })
    }

    /// Ordered (deduplicated) keys of the collection's document entries — scopes the
    /// Add Highlighted Passages sheet to this collection's documents, in reading order.
    private var orderedDocumentKeys: [String] {
        var seen: Set<String> = []
        return sortedEntries.filter { $0.entryKind == .document }
            .map { CollectionDocumentDiscovery.documentKey(volumeId: $0.volumeId,
                                                           documentId: $0.documentId) }
            .filter { seen.insert($0).inserted }
    }

    /// Appends excerpt entries (Authoring Phase 5) at the end of the entry list via the
    /// shared `CollectionExcerpts` factory, then saves — the excerpt sibling of
    /// `appendEntries`.
    private func appendExcerpts(_ captures: [CollectionExcerptCapture]) {
        CollectionExcerpts.append(captures, to: collection,
                                  sortedEntries: &sortedEntries, modelContext: modelContext)
        try? modelContext.save()
    }

    /// Appends a structural entry (a section heading or a prose block) to the collection.
    /// Mirrors the document-entry creation path; heading/prose entries carry empty document
    /// identifiers and use `text` (Phase 3a).
    private func addStructuralEntry(kind: CollectionEntryKind) {
        let entry = CollectionEntry(
            collectionId: collection.id,
            documentId: "",
            volumeId: "",
            sortOrder: sortedEntries.count
        )
        entry.entryKind = kind
        entry.text = ""
        entry.collection = collection
        modelContext.insert(entry)
        sortedEntries.append(entry)
        reindexEntries()
    }

    /// Inserts a generated apparatus entry (Authoring Phase 6) at the block type's
    /// default position — front-matter types before the first entry, back-matter types
    /// at the end. The entry stores only the block TYPE; it stays fully movable and
    /// deletable like a prose block afterwards.
    private func addGeneratedEntry(type: CollectionGeneratedBlockType) {
        let entry = CollectionEntry(
            collectionId: collection.id,
            documentId: "",
            volumeId: "",
            sortOrder: 0
        )
        entry.entryKind = .generated
        entry.generatedBlockType = type.rawValue
        entry.collection = collection
        modelContext.insert(entry)
        switch type.defaultPosition {
        case .frontMatter: sortedEntries.insert(entry, at: 0)
        case .backMatter:  sortedEntries.append(entry)
        }
        reindexEntries()
    }

    /// Applies a one-tap composition preset (Composer redesign 4a): overwrites the collection's
    /// composition fields, then inserts the preset's not-yet-present apparatus blocks through
    /// `addGeneratedEntry` — so the `sortedEntries` outline mirror and `sortOrder` stay consistent
    /// (a model-direct insert would be invisible until reload and could corrupt ordering).
    /// Non-destructive: existing apparatus and document entries are kept.
    private func applyPreset(_ preset: CollectionPreset) {
        preset.applyFields(to: collection)
        let present = Set(sortedEntries.compactMap {
            $0.entryKind == .generated ? $0.generatedBlockType : nil
        })
        for block in preset.apparatusBlocks(notAlreadyIn: present) {
            addGeneratedEntry(type: block)
        }
    }

    private func notes(for entry: CollectionEntry) -> [ResearchNote] {
        allNotes.filter {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }
    }

    // MARK: - Per-entry inspector (Collections Manager M2, D3 / M2.4)

    /// The document entry currently shown in the per-entry inspector, if any.
    private var inspectedEntry: CollectionEntry? {
        inspectedEntryId.flatMap { id in sortedEntries.first { $0.id == id } }
    }

    /// Opens the per-entry inspector for a row's ⓘ (Collections Manager M2). On iPad
    /// (regular width) it takes over the shared trailing `.inspector` column — so it
    /// also ensures the inspector is visible and hands the column to the entry (versus
    /// collection metadata); on iPhone (compact) it drives the `.sheet`.
    private func presentEntryInspector(for entryId: UUID) {
        // Composer v2: iPad (regular) presents the Configure sheet, iPhone (compact) drills in —
        // both driven purely by `inspectedEntryId` (see `iPadCollectionLayout` and the editor's
        // per-entry `.navigationDestination`).
        inspectedEntryId = entryId
    }

    /// The shared per-entry inspector content — the same `CollectionEntryInspector` used
    /// as an iPhone `.sheet` and an iPad `.inspector` column. `onNewNote` opens the inline
    /// note-create sheet for the entry's document (D5); `onInsertExcerpt` keeps the entry
    /// list in sync when a highlight is inserted as an excerpt.
    @ViewBuilder
    private func entryInspectorContent(_ entry: CollectionEntry, isPushed: Bool = false,
                                       documentOnly: Bool = false) -> some View {
        CollectionEntryInspector(
            entry: entry,
            onInsertExcerpt: { capture in appendExcerpts([capture]) },
            onNewNote: {
                if let idx = sortedEntries.firstIndex(where: { $0.id == entry.id }) {
                    noteCreateContext = NoteCreateContext(
                        documentId: entry.documentId,
                        volumeId: entry.volumeId,
                        entryIndex: idx)
                }
            },
            // Composer v2 §A/§C: the Document | Composition segment is gone — composition now lives in
            // the ⚙ Collection sheet (iPad) / the top Collection Settings drill-in (iPhone). Both the
            // iPad Configure sheet and the iPhone drill-in pass `documentOnly: true`, so this per-entry
            // surface never re-shows the collection section.
            showsCompositionSegment: false,
            showsCollectionSettings: !documentOnly,
            // Presets route apparatus through this host's entry-list management (4a).
            onApplyPreset: { applyPreset($0) },
            // iPhone presents the inspector as a drill-in push (Composer redesign 4), so it omits
            // its own navigation stack + Done button.
            isPushed: isPushed
        )
        .id(entry.id)
        .environment(appState)
    }

    private func reindexEntries() {
        for (i, entry) in sortedEntries.enumerated() {
            entry.sortOrder = i
        }
    }

    /// Appends document entries at the end of the entry list in the given order.
    /// Duplicates are allowed (A4) — repeats get an "Also in collection" badge instead
    /// of being silently skipped.
    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) {
        CollectionDocumentDiscovery.appendEntries(
            pairs, collection: collection,
            sortedEntries: &sortedEntries, modelContext: modelContext)
    }

    /// The two `CollectionDateSortScope` menu items shared by every Sort by Date surface
    /// (iPad toolbar menu, iPhone add-menu, and the compact Actions section) — mirrors the
    /// macOS ribbon's Sort ▾ menu so both platforms offer the identical two-way choice.
    @ViewBuilder
    private var sortByDateScopeItems: some View {
        ForEach(CollectionDateSortScope.allCases, id: \.self) { scope in
            Button {
                sortByDate(withinSections: scope == .withinSections)
            } label: {
                Label(scope.displayLabel, systemImage: scope.systemImage)
            }
        }
    }

    /// Re-orders the entries chronologically. Defaults to the whole-collection scope so
    /// the internal auto-sort-on-add call sites keep the original global behavior; only the
    /// user-facing Sort by Date control passes a scope.
    private func sortByDate(withinSections: Bool = false) {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        // Shared canonical sort (Authoring Phase 1): per-document `date_iso` first, then
        // volume earliest date, then the "9999" sentinel — previously iOS sorted by volume
        // dates only, so documents within one volume kept insertion order. `withinSections`
        // (Sort modes) keeps documents inside their heading-delimited section.
        sortedEntries = CollectionEntryData.sortedByDate(
            sortedEntries, documentDates: documentDates, manifest: manifest,
            withinSections: withinSections)
        reindexEntries()
    }

    /// The manifest display title for an entry's volume, falling back to the raw volume id
    /// (matches the macOS manager's helper).
    private func volumeTitle(for entry: CollectionEntry) -> String {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return manifest.first(where: { $0.volumeId == entry.volumeId })?.title ?? entry.volumeId
    }

    /// Writes the editor's field state onto the model. Called from `onChange` for every
    /// name/note/smart-link edit (all-live autosave, A1) — the export sheet and every
    /// other consumer always see the current state, with no separate Save step.
    private func saveLive() {
        collection.name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = collectionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.note = trimmedNote.isEmpty ? nil : trimmedNote
        collection.savedSearchId = linkedSavedSearchId
        // Front matter (Phase 4): empty fields store nil so untouched collections keep
        // exporting byte-identically to pre-Phase-4 output.
        let trimmedSubtitle = collectionSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
        let trimmedAuthor = collectionAuthorLine.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.authorLine = trimmedAuthor.isEmpty ? nil : trimmedAuthor
        collection.includeColophon = includeColophon
        if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) {
            collection.projectIds.append(projectId)
        }
        try? modelContext.save()
    }
}
