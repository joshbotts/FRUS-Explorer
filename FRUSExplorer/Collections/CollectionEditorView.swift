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
///    pasted citations, or tags) and appends the selection to the collection; left out
///    for a smart collection, which takes no hand-added document (#1619)
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
///   2026-09-11 — iOS: a document opened from a collection reads inside the collection's own
///          stack (`readingChain`), so Back returns to the editor instead of Browse's history
///   2026-09-23 — #1359: the iOS title is the collection's saved name (`CollectionEditorNaming`),
///          not "New Collection" / "Edit Collection"; the name field follows a rename made elsewhere
///          and saves only when an edit changes the saved name (`FrontMatterModelSync`)
///   2026-09-24 — #1359 review: a new collection is discarded or named "Untitled Collection" only when
///          the editor is dismissed (`NewCollectionDismissal`, `NewCollectionSession`) — no longer when
///          Collection settings, the entry inspector or a document is pushed over the pushed editor
///   2026-09-24 — #1359 review, round 2: whether a new collection was touched is read from the model, so an entry
///          added from another tab while the editor waits there keeps the collection (`NewCollectionSession`)
///   2026-09-25 — #1415 / #1413: each field commits itself from its own binding as it is edited (`committing`), and
///          writes only itself (`CollectionEditorCommit`), replacing `saveLive()`, which ran from `onChange` — never,
///          under a covered, pushed editor — and wrote every field from the copies taken when the editor opened. The
///          editor follows the description, subtitle and author line a heading's Section defaults sheet writes
///          (`FrontMatterModelSync`), and following never saves
///   2026-09-25 — #1416: the outline follows entries another writer adds, removes or moves
///          (`CollectionEntriesModelSync`), so the rows, the preview and the export sheet see them, and is seeded in
///          the follow's own order; every append takes one past the highest position, and every reorder, delete, sort
///          and block insert renumbers, through `CollectionEntryOrdering`, so an editor's append no longer shares a
///          position with the Add to Collection picker's on the same device; the inline New Note sheet names its
///          entry by id, since the outline can now change under it
///   2026-10-15 — #1619: a smart collection takes no hand-added document, heading, note block or passage
///          (`SmartCollectionRule`): both Add menus disable those four items, the Add Documents section is left out, the
///          inspector offers no Insert as Excerpt, and Contents opens with the picker's sentence, whether or not the
///          collection holds entries (the sentence it replaces, `collection.editor.docs.smartEmpty`, showed only while
///          it held none); Add to Archives Visit… says why when a smart collection's search cannot run
///   2026-10-15 — #1619 review: Collection settings offers Unlink for a link whose saved search was deleted too
///          (`SmartCollectionLinkRows`), and reads the link from the model, not the editor's copy
///   2026-10-16 — #1619, decision 22 of the 2026-10-14 plan of record: a smart collection's Contents lists only the
///          entries it keeps (`CollectionOutline.contentsRows`), and its entries from before its link follow in a section
///          of their own under a dimmed heading, with Remove These Entries, which asks first
///          (`SmartCollectionEntriesFromBeforeLink`); its apparatus rows print no document count and its Contents no
///          timeline button, since both read those entries
///   2026-10-17 — #1704: Collection settings presents the Link to Saved Search picker, the iPad's sheet and the
///          compact layout's pushed screen alike, where the editor had, so on iPad it opens over the settings sheet
///          rather than once Done has closed it; the identifier `collection.editor.smart.link` on its button
///   2026-10-20 — #1687, decision 70 of the 2026-10-14 plan of record: Link to Saved Search… and its picker are views
///          of their own (`SmartCollectionLinkButton`, `LinkSavedSearchPicker`), which the Mac Collections window's ⚙
///          popover mounts too; on the Mac the dimmed button's line names the Search window, not the Search tab
///   2026-10-25 — #1791: the editor reads one copy of each note and saved search, however many are stored under one
///          id, so an entry's notes, the exports and Link to Saved Search… list each once
///   2026-11-18 — L25 (decision 139): the iPhone's Collection settings row names the template in force by its name
///          alone, which now says how the documents are presented, where it added the chip's tag
///   2026-11-28 — L58: the collection's settings, on the iPhone, in the iPad's sheet and in a document's settings, offer
///          the Note on the Text where it would say something (`CollectionCompositionRows.wantsNoteOnTheText`), its Add
///          putting the row at the end of the outline as the Apparatus menu does
///   2026-11-28 — L44 (the design's §5.2, decision 153): Collection settings opens on ten controls, the two steps' rows
///          among them (`CollectionSettingsSteps`), each step a screen pushed in the settings' own stack; the colophon,
///          the project stamp and the query log are step 2's (decision 170); the Mac's New Collection form is a name and
///          the two steps, each a menu; a smart collection's Contents sentence offers Create Static Snapshot, which
///          opens the snapshot (the design's §4.5); a block from the Apparatus menu goes where step 2's ticks put it, the
///          Note on the Text last (`CollectionApparatusRows`)
struct CollectionEditorView: View {

    @Environment(AppState.self) private var appState
    /// This scene's identity, so an iPad hand-off addresses the window the user is looking at.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    // MARK: - SwiftData queries

    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNoteCopies: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    @Query(sort: \SavedSearch.createdAt, order: .reverse) private var allSavedSearchCopies: [SavedSearch]
    @Query(sort: \Project.name) private var allProjects: [Project]

    // MARK: - State

    @State private var collection: Collection
    private let isNewCollection: Bool
    /// A new collection's editing session, which discards it or names it once the editor is dismissed
    /// (`NewCollectionSession`); `nil` for a collection the editor opened.
    @State private var newCollectionSession: NewCollectionSession?

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
    /// Front matter: whether exports stamp the active project on the title page (#377 Phase 4, default off).
    @State private var includeProjectProvenance: Bool
    @State private var includeMethodAppendix: Bool
    /// Headings whose sections are currently collapsed in the outline — VIEW STATE only
    /// (Phase 4): never persisted, never synced; keyed by entry id so it survives moves.
    @State private var collapsedHeadingIds: Set<UUID> = []

    @State private var showAddDocuments   = false
    /// A transient "Added N documents" confirmation toast after the Add Documents sheet commits (5).
    @State private var addDocumentsToast: String?
    /// Presents the bulk "Add Highlighted Passages" sheet (Authoring Phase 5).
    @State private var showAddHighlights  = false
    /// Presents the Add-to-Archive-Visit picker over this collection's resolved documents
    /// (Phase 3 — the ephemeral packet verb this replaced lives on in the plan's own export).
    @State private var planPickerRequest: PlanPickerRequest?
    /// Why Add to Archives Visit… could not resolve this smart collection's search, while its alert shows (#1619).
    @State private var addToVisitError: String?
    @State private var showExport         = false
    @State private var showTimeline       = false
    @State private var showLinkSavedSearch = false
    @State private var exportError: String?
    /// A smart collection's static snapshot, opened above this editor once Create Static Snapshot has made it (L44).
    @State private var snapshotToOpen: Collection?
    /// Why Create Static Snapshot could not make one, while its alert shows (L44).
    @State private var snapshotError: String?

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
    /// A row's deletion waiting on its dialog, for a row that holds the reader's work (L19, MAC-2).
    @State private var pendingEntryDeletion: PendingEntryDeletion?
    /// The document read above the iPhone's per-entry drill-in, from its Open Document (L19, IPA-4). A
    /// chain of its own: the editor's `readingChain` is presented from the editor, beneath the drill-in.
    /// Declared on every platform, as the drill-in is; only iOS reads in place.
    @State private var inspectorReadingChain: [DocumentBrowserEntry] = []
    /// The entry whose document the iPad's Configure sheet asked to open, read once the sheet has
    /// closed (L19, IPA-4).
    @State private var openAfterInspectorCloses: UUID?
    #if os(iOS)
    /// The documents opened from this collection, read INSIDE the stack hosting the editor (2026-09-11):
    /// the Collections tab when pushed, the sheet's own stack otherwise. See `InPlaceDocumentReader`.
    @State private var readingChain: [DocumentBrowserEntry] = []
    #endif
    /// Pending inline note-create context (Collections Manager M2, D5): the "New Note…"
    /// affordance in the entry inspector's per-note list opens `InlineNoteCreateSheet`
    /// for this document, linking the created note to the entry when appropriate.
    @State private var noteCreateContext: NoteCreateContext?

    /// Identifies the document an inline `InlineNoteCreateSheet` is creating a note for
    /// (Collections Manager M2, D5); `entryId` names the owning entry to link — an id, not an outline index, since
    /// the outline can change under the open sheet when another writer adds or removes an entry (#1416).
    private struct NoteCreateContext: Identifiable {
        let id = UUID()
        let documentId: String
        let volumeId: String
        let entryId: UUID
    }
    /// iPhone Outline | Preview pane selection (Authoring Phase 2b; view-local).
    @State private var editorPane: EditorPane = .outline
    /// The preview's "Render All" cap lift, hoisted here so it survives pane toggles
    /// that recreate `CollectionPreviewView` (one editor session = one lift).
    @State private var previewRenderAll = false
    /// The preview's place and chosen row (L36), hoisted with `previewRenderAll` so a rebuilt preview keeps them.
    @State private var previewPlace = CollectionPreviewPlace()

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
            // The follow's own order (#1416): its `onChange` never runs for the value it starts on, so an outline seeded
            // any other way — an entry deleted but not yet saved, a shared position — would stay until the model moved.
            _sortedEntries = State(initialValue: CollectionEntryOrdering.modelOrder(of: c))
            _linkedSavedSearchId = State(initialValue: c.savedSearchId)
            _collectionSubtitle = State(initialValue: c.subtitle ?? "")
            _collectionAuthorLine = State(initialValue: c.authorLine ?? "")
            _includeColophon = State(initialValue: c.includeColophon)
            _includeProjectProvenance = State(initialValue: c.includeProjectProvenance)
            _includeMethodAppendix = State(initialValue: c.includeMethodAppendix)
            _newCollectionSession = State(initialValue: nil)
            isNewCollection = false
        } else {
            let c = Collection(name: "")
            // L43 (decisions 159 and 160): a new collection opens on the volume's heading, in the style chosen in
            // Settings ▸ Display.
            c.applyNewCollectionDefaults(citationStyle: .current)
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: "")
            _collectionNote = State(initialValue: "")
            _sortedEntries = State(initialValue: [])
            _linkedSavedSearchId = State(initialValue: nil)
            _collectionSubtitle = State(initialValue: "")
            _collectionAuthorLine = State(initialValue: "")
            _includeColophon = State(initialValue: false)
            _includeProjectProvenance = State(initialValue: false)
            _includeMethodAppendix = State(initialValue: false)
            _newCollectionSession = State(initialValue: NewCollectionSession(collection: c))
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
        // #830 / Phase 3: attached to the SHARED body, not to a per-platform one — the
        // Phase 0 lesson (the ephemeral packet's presenter shipped inside `macBody` while its
        // control lived in `iPhoneAddMenu`, dead on every platform) holds for its successor.
        // Membership is resolved through the ONE `TripPacketSeed.resolve` rule the Mac window
        // uses too (smart → `smartRefs`; static → documents + excerpts, de-duplicated), so this
        // surface and the export cannot describe different membership.
        .sheet(item: $planPickerRequest) { request in
            PlanPickerSheet(request: request)
                .environment(appState)
        }
        // #1619 (#1558's reading): a smart collection whose search cannot run says why, where the item did nothing.
        .alert(
            String(localized: "archiveVisit.collection.error.title", defaultValue: "Couldn’t Add to Archives Visit"),
            isPresented: Binding(
                get: { addToVisitError != nil },
                set: { if !$0 { addToVisitError = nil } }
            ),
            presenting: addToVisitError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .transientToast($addDocumentsToast)
        // Reload document headers and per-document dates whenever the entry list changes.
        // (The Group has exactly one child per platform, so this task attaches once.)
        .task(id: sortedEntries.map(\.id)) {
            (documentHeaders, documentDates) =
                await CollectionEntryData.load(for: sortedEntries, appState: appState)
        }
        // All-live autosave (A1): every edit lands on the model as it is made, the same semantics as the macOS
        // manager (and what CloudKit sync implies anyway). Each field commits itself, from its own binding
        // (`committing`, #1415), and writes only itself (`CollectionEditorCommit`, #1413) — never from an `onChange`
        // here: on the iPhone, Collection settings is pushed OVER this view, and a covered, pushed view runs no
        // `onChange`, so an edit made there reached the model only when the editor came back, and never if it did not.
        // Follow the model when a second writer changes what this view holds as one-time `@State` copies: another
        // iPad window or iCloud writing the name (#1359), the description, subtitle, author line or the three export
        // switches, which until L44 a heading row's Section defaults sheet also wrote directly on the model (#1413). The follow writes only these copies, never the model — so the field the reader edits next starts
        // from the value the collection holds. (A `ViewModifier` so its `.onChange`s don't overflow the body's
        // type-checker.)
        .modifier(FrontMatterModelSync(
            collectionName: $collectionName,
            collectionNote: $collectionNote,
            collectionSubtitle: $collectionSubtitle,
            collectionAuthorLine: $collectionAuthorLine,
            includeColophon: $includeColophon,
            includeProjectProvenance: $includeProjectProvenance,
            includeMethodAppendix: $includeMethodAppendix,
            collection: collection))
        // #1416: the outline follows entries another writer adds, removes or moves — the Add to Collection picker on
        // another tab, another iPad window, iCloud — so the rows, the live preview and the export sheet all see them.
        .modifier(CollectionEntriesModelSync(outline: $sortedEntries, collection: collection))
        // The one special case: a brand-new collection the user backed out of without
        // touching anything is discarded; a kept-but-unnamed one gets a default name so
        // it doesn't render as a blank list row — once the editor is really dismissed, not
        // when a screen is pushed over it (#1359 review; see `NewCollectionDismissal`).
        .modifier(NewCollectionDismissal(session: newCollectionSession,
                                         isPushed: presentationStyle == .pushed))
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

            // Form content. L44 (the design's §5.2): Add to Collection's New Collection form is a name and the two steps,
            // each a menu. Everything else is set in the Collections window, where the new collection opens.
            Form {
                nameSection
                Section {
                    CollectionDocumentsMenu(collection: collection)
                    CollectionApparatusMenu(collection: collection, host: settingsHost)
                } header: {
                    Text(String(localized: "collection.settings.steps.header", defaultValue: "Template"))
                }
            }
            .formStyle(.grouped)

            Divider()

            // Button bar. All edits save live (A1); Done just dismisses (see `NewCollectionDismissal`).
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
        .frame(minWidth: 460, minHeight: 260)
        .sheet(isPresented: $showAddDocuments) {
            CollectionAddDocumentsSheet(
                allTags: allTags,
                allNotes: allNotes,
                existingDocumentKeys: existingDocumentKeys
            ) { picks in
                if appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) }) {
                    addDocumentsToast = CollectionDocumentDiscovery.addedToastMessage(picks.count)
                }
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
                newCollectionSession?.begin(in: modelContext)
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
        // #1359: the collection's name, read from the model so a rename made elsewhere retitles it too.
        .navigationTitle(CollectionEditorNaming.navigationTitle(savedName: collection.name,
                                                                isNewCollection: isNewCollection))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // Declared on `iOSContent`, which both presentation branches render, so the pushed editor
        // and the sheet editor read the same way.
        .inPlaceReader($readingChain)
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
                if appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) }) {
                    addDocumentsToast = CollectionDocumentDiscovery.addedToastMessage(picks.count)
                }
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
        // The Link to Saved Search picker is not presented from here but from Collection settings, which holds its
        // button (`iPhoneCollectionSettingsScreen`, `iPadCollectionSettingsSheet`; #1704).
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
                drillInInspector(entry)
            }
        }
        // L44 (the design's §4.5): a smart collection's snapshot opens above its editor, so Back returns to the smart
        // collection.
        .navigationDestination(item: $snapshotToOpen) { snapshot in
            CollectionEditorView(collection: snapshot, presentationStyle: .pushed)
        }
        .alert(
            String(localized: "collection.snapshot.error.title", defaultValue: "Couldn’t Create Snapshot"),
            isPresented: Binding(get: { snapshotError != nil }, set: { if !$0 { snapshotError = nil } }),
            presenting: snapshotError
        ) { _ in
            Button(String(localized: "collection.editor.export.error.dismiss", defaultValue: "OK")) {}
        } message: { message in
            Text(message)
        }
        // L19 (IPA-4): a reader opened from one entry's drill-in is not left for the next one's. L36: the entry
        // whose settings open is the preview's chosen row, whose document it brings into view.
        .onChange(of: inspectedEntryId) { _, id in inspectorReadingChain = []; previewPlace.choose(id) }
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
                if let entry = sortedEntries.first(where: { $0.id == ctx.entryId }),
                   !entry.selectedNoteIds.isEmpty {
                    entry.selectedNoteIds.append(newNote.id)
                }
            }
            .environment(appState)
        }
        .onAppear {
            if isNewCollection {
                modelContext.insert(collection)
                newCollectionSession?.begin(in: modelContext)
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
                                      renderAll: $previewRenderAll, place: previewPlace)
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
        // Caption names the active template when one matches, by its name alone, which says how the
        // documents are presented (L25, the owner's choice), else the plain-language composition summary.
        let activePreset = CollectionPreset.allCases.first { $0.matches(collection) }
        let caption = activePreset.map(\.displayName)
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
            // `CollectionEditorTitleTests` (#1359): the iPhone route to the name field.
            .accessibilityIdentifier("collection.editor.settings.row")
        }
    }

    /// The pushed Collection Settings screen (iPhone drill-in): Collection settings' ten controls
    /// (`collectionSettingsSections`, L44), the name first (#309), as the iPad's ⚙ sheet and the Mac's popover have them.
    /// This screen COVERS the editor, which — pushed, as the Collections tab shows it — runs no `onChange` meanwhile,
    /// so every field on it commits from its own binding as it is edited (`committing`, #1415), however it is left; so
    /// do step 2's three switches, which this editor's bindings commit.
    private var iPhoneCollectionSettingsScreen: some View {
        Form {
            collectionSettingsSections
        }
        .navigationTitle(String(localized: "collection.editor.settings.title",
                                defaultValue: "Collection settings"))
        // `noteField` is a `.vertical`-axis TextField with `.lineLimit(3...6)`, so Return inserts
        // a newline and never dismisses. Additive to the Done now in the rich-text editor's own
        // accessory bar — each serves a different first responder on this same screen.
        .keyboardDismissBar()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // From the screen that holds Link to Saved Search…, as the iPad's settings sheet presents it (#1704).
        .sheet(isPresented: $showLinkSavedSearch) {
            linkSavedSearchSheet
        }
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
                                  renderAll: $previewRenderAll, place: previewPlace)
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
        ), onDismiss: openDocumentAfterInspector) {
            if let entry = inspectedEntry {
                // L19 (IPA-4): Open Document closes the sheet and reads the document in the editor's
                // stack, where a row's long press reads it, rather than inside a form sheet.
                entryInspectorContent(entry,
                                      onOpenDocument: { openWhenInspectorCloses(entry) })
            }
        }
    }

    /// The iPad ⚙ Collection settings sheet (Composer v2 §A): a dismissible form sheet holding Collection settings' ten
    /// controls (`collectionSettingsSections`, L44), each step a screen pushed in the sheet's own stack.
    private var iPadCollectionSettingsSheet: some View {
        NavigationStack {
            Form {
                collectionSettingsSections
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "collection.editor.settings.title",
                                    defaultValue: "Collection settings"))
            .keyboardDismissBar()
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
        // #1704: the Link to Saved Search picker opens over this sheet, from the sheet itself. SwiftUI presents one
        // sheet at a time from a view, and the picker had hung on the editor, which is already presenting this one: the
        // tap opened nothing, and the picker came up only once Done had closed the settings. The pushed settings screen
        // on a compact width presents it the same way.
        .sheet(isPresented: $showLinkSavedSearch) {
            linkSavedSearchSheet
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
    ///
    /// A linked collection shows its link and Unlink whether or not the saved search can still be found
    /// (`SmartCollectionLinkRows`, #1619 review): a smart collection takes nothing by hand, so a link to a deleted
    /// search that could not be undone left the collection unable to take anything again. The link is read from the
    /// model, which `linkSavedSearch` writes at once and which follows a link made on another device.
    @ViewBuilder
    private var smartCollectionRows: some View {
        Group {
            if let searchId = collection.savedSearchId {
                SmartCollectionLinkRows(
                    savedSearchName: allSavedSearches.first(where: { $0.id == searchId })?.name,
                    onUnlink: { linkSavedSearch(nil) })
            } else {
                SmartCollectionLinkButton(hasSavedSearches: !allSavedSearches.isEmpty) {
                    showLinkSavedSearch = true
                }
            }
        }
    }

    // MARK: - Link Saved Search Sheet

    /// The picker Link to Saved Search… opens (`LinkSavedSearchPicker`, which the Mac Collections window's ⚙ popover
    /// opens too, #1687). Picking a search links the collection through `linkSavedSearch`.
    private var linkSavedSearchSheet: some View {
        LinkSavedSearchPicker(
            savedSearches: allSavedSearches,
            onLink: { searchId in
                linkSavedSearch(searchId)
                showLinkSavedSearch = false
            },
            onCancel: { showLinkSavedSearch = false })
    }

    // MARK: - Name Section

    /// The bare name field, usable inside any container (iPhone Details disclosure,
    /// iPad inspector's `nameSection`, macOS form). Commits as it is typed (#1415).
    private var nameField: some View {
        TextField(
            String(localized: "collection.editor.name.placeholder", defaultValue: "Collection Name"),
            text: committing($collectionName) { CollectionEditorCommit.name($0, to: collection) }
        )
        .accessibilityLabel(String(localized: "collection.editor.name.accessibility",
                                   defaultValue: "Collection name"))
        // `CollectionEditorTitleTests` (#1359) types the name here on both idioms.
        .accessibilityIdentifier("collection.editor.name.field")
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
    /// several lines of vertical space by default. Commits as it is typed (#1415).
    @ViewBuilder private var noteField: some View {
        if isAddingNote || !collectionNote.isEmpty {
            TextField(
                String(localized: "collection.editor.note.placeholder",
                       defaultValue: "Optional note about this collection…"),
                text: committing($collectionNote) { CollectionEditorCommit.text($0, to: \.note, of: collection) },
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "collection.editor.note.accessibility",
                                       defaultValue: "Collection note"))
            // `CollectionEditorTitleTests` (#1415) types and reads the note here.
            .accessibilityIdentifier("collection.editor.note.field")
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
            .accessibilityIdentifier("collection.editor.note.add")
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

    /// Title-page and introduction fields (Authoring Phase 4): the subtitle, the author line and the introduction, which
    /// with the name and the note are the title page's five (L44). All commit as they are edited (#1415); an empty field
    /// stores `nil`, keeping exports byte-identical to pre-Phase-4 output until something is actually set.
    @ViewBuilder
    private var frontMatterRows: some View {
        TextField(
            String(localized: "collection.frontmatter.subtitle.placeholder",
                   defaultValue: "Subtitle (title page)"),
            text: committing($collectionSubtitle) { CollectionEditorCommit.text($0, to: \.subtitle, of: collection) }
        )
        .accessibilityLabel(String(localized: "collection.frontmatter.subtitle.accessibility",
                                   defaultValue: "Collection subtitle"))
        // `CollectionEditorTitleTests` (#1415, #1413) types and reads the subtitle here.
        .accessibilityIdentifier("collection.editor.subtitle.field")
        TextField(authorPlaceholder, text: committing($collectionAuthorLine) {
            CollectionEditorCommit.text($0, to: \.authorLine, of: collection)
        })
            .accessibilityLabel(String(localized: "collection.frontmatter.author.accessibility",
                                       defaultValue: "Author line"))
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "collection.frontmatter.introduction.label",
                        defaultValue: "Introduction"))
                .font(.caption)
                .foregroundStyle(.secondary)
            RichTextEditor(initialRTF: collection.introductionRichText,
                           plainFallback: collection.introductionText ?? "",
                           restingCap: .introduction) { rtf, plain in
                saveIntroduction(rtf: rtf, plain: plain)
            }
        }
        // L44 (decision 170): the colophon, the project stamp and the query log are step 2's, under its blocks.
    }

    /// The front-matter rows as a titled form section (the iPhone's settings screen and the iPad's sheet).
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

    // MARK: - Collection settings (L44)

    /// Collection settings' ten controls (L44; the design's §5.2), on the iPhone's pushed screen and in the iPad's
    /// sheet: the name; the two steps' rows, each opening its step as a screen pushed in the settings' own stack; the
    /// note and the title page; *Citation style* and *Wording*; and the linked saved search. The name stays first, as
    /// #309 put it on every platform.
    @ViewBuilder
    private var collectionSettingsSections: some View {
        nameSection
        CollectionSettingsSteps(collection: collection, host: settingsHost, presentation: .pushed)
        noteSection
        frontMatterSection
        CollectionCitationsRows(collection: collection, presentation: .pushed)
        smartCollectionSection
    }

    /// What the collection's settings need of this editor (L44): a row's name, its apparatus edits through its outline, and the
    /// three export switches step 2 holds, each committed from its own binding as the settings' other fields are (#1415).
    private var settingsHost: CollectionSettingsHost {
        CollectionSettingsHost(
            name: { CollectionOwnSettings.rowName($0, headers: documentHeaders) },
            applyApparatus: { applyApparatus($0) },
            undoApparatus: { undoApparatus($0) },
            colophon: committing($includeColophon) { CollectionEditorCommit.flag($0, to: \.includeColophon, of: collection) },
            projectStamp: committing($includeProjectProvenance) {
                CollectionEditorCommit.flag($0, to: \.includeProjectProvenance, of: collection)
            },
            queryLog: committing($includeMethodAppendix) {
                CollectionEditorCommit.flag($0, to: \.includeMethodAppendix, of: collection)
            })
    }

    // MARK: - Documents Section

    @ViewBuilder
    private var documentsSection: some View {
        // #1619, decision 22: the rows Contents lists. A smart collection's are only the entries it keeps, its
        // apparatus; its entries from before its link are listed apart, in the section after this one.
        let outline = CollectionOutline.linearize(sortedEntries)
        let rows = CollectionOutline.contentsRows(
            in: outline, collapsedHeadingIds: collapsedHeadingIds, savedSearchId: collection.savedSearchId)
        Section {
            // #1619: a smart collection says what it is first, whatever it holds. Its documents come from its saved
            // search, so the Add menus take no hand-added document, heading, note block or passage into it.
            if !takesHandAddedEntries {
                Label(SmartCollectionRule.sentence, systemImage: "bolt.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // L44 (the design's §4.5): the way to a collection whose documents can be set one by one, where the
                // reader meets the sentence, and not only in the Collections list.
                Button {
                    Task { await createSnapshot() }
                } label: {
                    Label(String(localized: "collection.snapshot.action", defaultValue: "Create Static Snapshot"),
                          systemImage: "camera")
                }
                .accessibilityIdentifier("collection.editor.snapshot")
            }
            if sortedEntries.isEmpty {
                if takesHandAddedEntries {
                    Text(String(localized: "collection.editor.docs.empty",
                                defaultValue: "No content yet. Add documents, headings, notes, and apparatus from the toolbar above."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                let duplicateKeys = duplicateDocumentKeys
                ForEach(rows) { row in
                    outlineRow(row, outline: outline, duplicateKeys: duplicateKeys,
                               rows: rows)
                        .padding(.leading, outlineIndent(for: row))
                        // L19 (MAC-2): the swipe's Delete, which asks first for a row that holds the
                        // reader's work. Red by tint, NOT `role: .destructive`: a destructive swipe
                        // button — the one `.onDelete` makes included — animates its row out of the
                        // list as if deleted, and takes the row's dialog with it. Measured on iOS
                        // 27.0: the note block vanished, no dialog showed, and the block came back
                        // when the collection was opened again (`VolumesStorageHubView` met the same).
                        .swipeActions(edge: .trailing) {
                            Button {
                                requestDelete(at: row.index)
                            } label: {
                                Label(String(localized: "common.delete", defaultValue: "Delete"),
                                      systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        // L19 (MAC-2): a row that holds the reader's work asks before a swipe, Edit's
                        // delete or its trash deletes it.
                        .collectionEntryDeleteConfirmation(for: sortedEntries[row.index].id,
                                                           pending: $pendingEntryDeletion,
                                                           delete: deleteConfirmed)
                }
                .onMove { indices, newOffset in
                    moveVisibleRows(indices, to: newOffset, visible: rows.map(\.index))
                }
                // What gives each row Edit mode's minus, which reveals the row's own swipe action above
                // rather than this one's (measured on iOS 27.0, L19).
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
                // Not for a smart collection (#1619, decision 22): the timeline plots the collection's document
                // entries, and a smart collection's documents come from its saved search; the ones it holds are entries
                // from before its link, which it leaves out.
                if takesHandAddedEntries && !sortedEntries.isEmpty {
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
                // On macOS, onMove works without explicit edit mode (drag handles appear automatically).
                // A Mac List's onDelete is a trackpad swipe and VoiceOver's Delete only, which no mouse
                // or key reaches (measured on macOS 27.2, #1823), so each row there carries its own delete.
                // Only over rows it can edit: the entries from before a smart collection's link take neither.
                if !rows.isEmpty {
                    EditButton()
                        .font(.caption)
                }
                #endif
            }
        }
        // #1619, decision 22: a smart collection's entries from before its link, under a dimmed heading that says why
        // they are not part of it, with a button that removes them once the reader confirms. Nothing else removes them.
        let fromBeforeLink = SmartCollectionRule.entriesFromBeforeLink(
            in: sortedEntries, savedSearchId: collection.savedSearchId)
        if !fromBeforeLink.isEmpty {
            SmartCollectionEntriesFromBeforeLink(entries: fromBeforeLink, documentHeaders: documentHeaders) {
                removeEntriesFromBeforeLink()
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
                // `CollectionEditorTitleTests` (#1359): the iPad route to the name field.
                .accessibilityIdentifier("collection.editor.settings.button")
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
            // #1619: the four hand-added kinds are disabled for a smart collection, whose Contents says why; the
            // Apparatus blocks are not, since a smart collection's exports build them over its search's documents.
            Button {
                showAddDocuments = true
            } label: {
                Label(String(localized: "collection.editor.addDocuments.button",
                             defaultValue: "Add Documents…"),
                      systemImage: "plus.rectangle.on.folder")
            }
            .disabled(!takesHandAddedEntries)
            Divider()
            Button {
                addStructuralEntry(kind: .heading)
            } label: {
                Label(String(localized: "collection.add.heading", defaultValue: "Add Section Heading"),
                      systemImage: "number")
            }
            .disabled(!takesHandAddedEntries)
            Button {
                addStructuralEntry(kind: .prose)
            } label: {
                Label(String(localized: "collection.add.prose", defaultValue: "Add Note Block"),
                      systemImage: "text.alignleft")
            }
            .disabled(!takesHandAddedEntries)
            Button {
                showAddHighlights = true
            } label: {
                Label(String(localized: "collection.add.highlights",
                             defaultValue: "Add Highlighted Passages…"),
                      systemImage: "text.quote")
            }
            .disabled(orderedDocumentKeys.isEmpty || !takesHandAddedEntries)
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
            // #830 T-2: the packet is built from this collection's documents. Disabled with none,
            // rather than hidden, so the action is discoverable before a collection has content.
            Button {
                Task {
                    do {
                        let docs = try await TripPacketSeed.resolve(
                            collection: collection, appState: appState,
                            modelContext: modelContext)
                        planPickerRequest = PlanPickerRequest(
                            documents: docs, includeSource: true, includeExternalRefs: true,
                            // The collection as every list row names it, and the plan after its trimmed name — an
                            // unnamed one makes an untitled plan (#1464 review, round 1).
                            basis: String(format: String(
                                localized: "archiveVisit.basis.collection %@",
                                defaultValue: "from the collection “%@”"),
                                CollectionEditorNaming.listName(savedName: collection.name)),
                            suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))
                    } catch {
                        addToVisitError = error.localizedDescription
                    }
                }
            } label: {
                Label(String(localized: "collection.addToVisit",
                             defaultValue: "Add to Archives Visit…"),
                      systemImage: "building.columns")
            }
            // Content or a saved search — the export sheet's own rule. A smart collection's
            // membership resolves from its search at build time (its static entries are
            // ignored, as the editor itself tells the user), and excerpt entries carry real
            // document provenance, so neither may leave this disabled (Phase 0).
            .disabled(orderedDocumentKeys.isEmpty
                      && !sortedEntries.contains { $0.entryKind == .excerpt
                          && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                      && linkedSavedSearchId == nil)
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
            // #1619: as in `iPhoneAddMenu`, a smart collection takes none of the four hand-added kinds.
            Button {
                showAddDocuments = true
            } label: {
                Label(String(localized: "collection.editor.addDocuments.button",
                             defaultValue: "Add Documents…"),
                      systemImage: "plus.rectangle.on.folder")
            }
            .disabled(!takesHandAddedEntries)
            Divider()
            Button {
                addStructuralEntry(kind: .heading)
            } label: {
                Label(String(localized: "collection.add.heading", defaultValue: "Add Section Heading"),
                      systemImage: "number")
            }
            .disabled(!takesHandAddedEntries)
            Button {
                addStructuralEntry(kind: .prose)
            } label: {
                Label(String(localized: "collection.add.prose", defaultValue: "Add Note Block"),
                      systemImage: "text.alignleft")
            }
            .disabled(!takesHandAddedEntries)
            Button {
                showAddHighlights = true
            } label: {
                Label(String(localized: "collection.add.highlights",
                             defaultValue: "Add Highlighted Passages…"),
                      systemImage: "text.quote")
            }
            .disabled(orderedDocumentKeys.isEmpty || !takesHandAddedEntries)
            Divider()
            // #830: the same item `iPhoneAddMenu` carries, reusing the SAME localization key so the
            // two menus cannot state different things. It was absent here, so at regular width —
            // every iPad, and the larger iPhones in landscape — a collection had no route to the
            // packet at all.
            Button {
                Task {
                    do {
                        let docs = try await TripPacketSeed.resolve(
                            collection: collection, appState: appState,
                            modelContext: modelContext)
                        planPickerRequest = PlanPickerRequest(
                            documents: docs, includeSource: true, includeExternalRefs: true,
                            // The collection as every list row names it, and the plan after its trimmed name — an
                            // unnamed one makes an untitled plan (#1464 review, round 1).
                            basis: String(format: String(
                                localized: "archiveVisit.basis.collection %@",
                                defaultValue: "from the collection “%@”"),
                                CollectionEditorNaming.listName(savedName: collection.name)),
                            suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))
                    } catch {
                        addToVisitError = error.localizedDescription
                    }
                }
            } label: {
                Label(String(localized: "collection.addToVisit",
                             defaultValue: "Add to Archives Visit…"),
                      systemImage: "building.columns")
            }
            // Content or a saved search — the export sheet's own rule. A smart collection's
            // membership resolves from its search at build time (its static entries are
            // ignored, as the editor itself tells the user), and excerpt entries carry real
            // document provenance, so neither may leave this disabled (Phase 0).
            .disabled(orderedDocumentKeys.isEmpty
                      && !sortedEntries.contains { $0.entryKind == .excerpt
                          && !$0.volumeId.isEmpty && !$0.documentId.isEmpty }
                      && linkedSavedSearchId == nil)
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
                     onOpenDocument: { openInReader(entry) },
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
                onDelete: { requestDelete(at: row.index) },
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
                                 onDelete: isMacOS ? { requestDelete(at: row.index) } : nil,
                                 onMoveUp: moveUp,
                                 onMoveDown: moveDown)
        case .generated:
            // Movable/deletable like prose; no body-depth or inspector controls —
            // the block resolves at export and in the live preview (Phase 6). No count for a smart collection's
            // (#1619, decision 22): the block lists the saved search's documents, and the ones the collection holds
            // are entries from before its link, which it leaves out.
            CollectionGeneratedEntryRow(entry: entry,
                                        documentCount: takesHandAddedEntries
                                            ? sortedEntries.count { $0.entryKind == .document } : nil,
                                        onDelete: isMacOS ? { requestDelete(at: row.index) } : nil,
                                        onMoveUp: moveUp,
                                        onMoveDown: moveDown)
        case .unrecognized:
            // Deliberately no reorder actions: the entry belongs to a newer build
            // (Authoring Phase 1 sync guard) and offers no controls at all.
            UnrecognizedEntryRow()
        }
    }

    /// One row's delete — a heading's Delete Heading Only, or a row's trash on the macOS sheet
    /// editor — at a full-outline index: at once, or after the row's dialog when it holds the
    /// reader's work (L19, MAC-2, ``CollectionEntryDeletion``). A heading deleted this way leaves its
    /// entries, and its sub-headings bubble up (normalize's orphan clamp).
    private func requestDelete(at index: Int) {
        guard sortedEntries.indices.contains(index) else { return }
        let entry = sortedEntries[index]
        if let holding = CollectionEntryDeletion.holding(entry, in: modelContext) {
            pendingEntryDeletion = PendingEntryDeletion(entryId: entry.id, holding: holding)
        } else {
            removeEntry(at: index)
            finishOutlineMutation()
        }
    }

    /// Deletes the entry the reader confirmed in its row's dialog, wherever the outline has it now.
    private func deleteConfirmed(_ entryId: UUID) {
        guard let index = sortedEntries.firstIndex(where: { $0.id == entryId }) else { return }
        removeEntry(at: index)
        finishOutlineMutation()
    }

    /// Removes the entry at a full-outline index, with the headnote draft it owns. The caller
    /// finishes the outline mutation.
    private func removeEntry(at index: Int) {
        collapsedHeadingIds.remove(sortedEntries[index].id)
        GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[index], in: modelContext)
        modelContext.delete(sortedEntries[index])
        sortedEntries.remove(at: index)
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

    /// Whether the visible row at `pos` can move down: a listed row must sit past its moved
    /// block (a heading's block is its whole `sectionRange`), which `moveVisibleRowDown`
    /// moves it after. In an outline every entry after the block is listed whenever this row
    /// is (a block is followed by a same-or-shallower item whose ancestors are also this row's
    /// ancestors); a smart collection's Contents leaves out its entries from before its link
    /// (`CollectionOutline.contentsRows`, #1619), so the rows are asked rather than the entries.
    private func canMoveVisibleRowDown(_ pos: Int, rows: [CollectionOutline.VisibleRow]) -> Bool {
        guard rows.indices.contains(pos) else { return false }
        let blockEnd = movedBlockEnd(of: rows[pos].index)
        return rows[(pos + 1)...].contains { $0.index >= blockEnd }
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

    /// Deletes the visible rows `.onDelete` names (mapped to full-outline coordinates). Deleting a
    /// heading this way removes the heading only — its entries stay and any sub-headings bubble up
    /// via normalize.
    ///
    /// L19 (MAC-2): since each row has a swipe action of its own, a swipe — a full one included —
    /// and Edit mode's minus reach ``requestDelete(at:)`` through it, not this: `.onDelete`'s own
    /// Delete is destructive, and the list took its row away before the row's dialog could show
    /// (measured on iOS 27.0). Any route that still arrives here asks the same way: a row that holds
    /// the reader's work is not deleted but asked about in its row's dialog
    /// (``CollectionEntryDeletion``), and the rows that hold nothing go at once, as before.
    private func deleteVisibleRows(_ indices: IndexSet, visible: [Int]) {
        let full = indices.compactMap { visible.indices.contains($0) ? visible[$0] : nil }
        var going: [Int] = []
        for i in full {
            if let holding = CollectionEntryDeletion.holding(sortedEntries[i], in: modelContext) {
                // One dialog at a time: a swipe deletes one row, and only Edit could pass more.
                if pendingEntryDeletion == nil {
                    pendingEntryDeletion = PendingEntryDeletion(entryId: sortedEntries[i].id, holding: holding)
                }
            } else {
                going.append(i)
            }
        }
        guard !going.isEmpty else { return }
        for i in going.sorted(by: >) { removeEntry(at: i) }
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

    /// Removes a smart collection's entries from before its link (the reader confirmed in
    /// `SmartCollectionEntriesFromBeforeLink`'s dialog; #1619, decision 22), through the rule the Mac
    /// Collections window calls too, then forgets any view state that named them.
    private func removeEntriesFromBeforeLink() {
        let removed = CollectionEntryOrdering.removeEntriesFromBeforeLink(
            of: collection, outline: &sortedEntries, modelContext: modelContext)
        guard !removed.isEmpty else { return }
        collapsedHeadingIds.subtract(removed)
        if let inspected = inspectedEntryId, removed.contains(inspected) { inspectedEntryId = nil }
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
    ///
    /// Left out for a smart collection (#1619), which takes no hand-added document: its Contents
    /// section says why, and a disabled button here would sit over a footer promising an add.
    @ViewBuilder
    private var addDocumentsSection: some View {
        if takesHandAddedEntries {
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

    /// Whether this collection takes documents, headings, note blocks and passages added by hand: not when it is linked
    /// to a saved search (`SmartCollectionRule`, #1619). Read from the model, which `linkSavedSearch` writes at once and
    /// which follows a link made on another device.
    private var takesHandAddedEntries: Bool {
        SmartCollectionRule.takesHandAddedEntries(savedSearchId: collection.savedSearchId)
    }

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
    /// `appendEntries`. A smart collection takes none, and nothing is saved (#1619).
    private func appendExcerpts(_ captures: [CollectionExcerptCapture]) {
        guard CollectionExcerpts.append(captures, to: collection,
                                        sortedEntries: &sortedEntries, modelContext: modelContext) else { return }
        try? modelContext.save()
    }

    /// Appends a structural entry (a section heading or a prose block) to the collection, through the append the Mac
    /// pane shares (`CollectionEntryOrdering.appendBlock`, #1416). Heading/prose entries carry empty document
    /// identifiers and use `text` (Phase 3a). A smart collection takes neither (#1619), and its outline is not
    /// renumbered for nothing: a position written, even unchanged, stamps the entry modified.
    private func addStructuralEntry(kind: CollectionEntryKind) {
        guard CollectionEntryOrdering.appendBlock(kind: kind, to: collection, outline: &sortedEntries,
                                                  modelContext: modelContext) != nil else { return }
        reindexEntries()
    }

    /// Inserts a generated apparatus entry (Authoring Phase 6) at the block type's usual place, through the rule step 2
    /// ticks by (`CollectionApparatusRows.insert`, L44): a Chronology first, the others at the end, and the Note on the
    /// Text last. The entry stores only the block TYPE; it stays fully movable and deletable like a prose block afterwards.
    private func addGeneratedEntry(type: CollectionGeneratedBlockType) {
        CollectionApparatusRows.insert(type, into: collection, outline: &sortedEntries, modelContext: modelContext)
        reindexEntries()
    }

    /// Applies a whole apparatus from step 2 (L44): its shortcuts, its ticks, the one tap on its row and the Mac's New
    /// Collection menu, through `CollectionApparatusRows`, so the outline mirror and `sortOrder` stay consistent (a
    /// model-direct insert would reach the outline only on the next update, through `CollectionEntriesModelSync`, and
    /// skip the block's usual place); then renumbers, normalizes and saves.
    private func applyApparatus(_ target: CollectionApparatusSettings) -> CollectionApparatusRows.Undo {
        let undo = CollectionApparatusRows.apply(target, to: collection, outline: &sortedEntries,
                                                 modelContext: modelContext)
        finishOutlineMutation()
        return undo
    }

    /// Puts one of step 2's changes back (L44), then renumbers, normalizes and saves.
    private func undoApparatus(_ undo: CollectionApparatusRows.Undo) {
        CollectionApparatusRows.undo(undo, collection: collection, outline: &sortedEntries, modelContext: modelContext)
        finishOutlineMutation()
    }

    /// Makes this smart collection's static snapshot and opens it above the editor (L44; the design's §4.5), through the
    /// sequence the Collections list runs (`SmartCollectionSnapshot.createFromLinkedSearch`).
    private func createSnapshot() async {
        do {
            snapshotToOpen = try await SmartCollectionSnapshot.createFromLinkedSearch(of: collection, appState: appState,
                                                                                    in: modelContext)
        } catch {
            snapshotError = error.localizedDescription
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
    /// Opens a collection entry in the app's own reader (#755 / audit M-18, M-19).
    ///
    /// Collections was the only document list in the app with no route into the reader: the whole
    /// module contained no `openDocument`, `openBrowseDocument` or `DocumentView` reference, so a
    /// researcher reviewing a collection they had deliberately curated had to remember each
    /// document's volume and re-find it through Browse or Search. On macOS the one "open" control
    /// launched history.state.gov in a web browser — the published text, not the app's reader with
    /// its notes, highlights and cross-references.
    ///
    /// On macOS, the provenance chain (which mints a window when no host is live). On iOS the
    /// document reads inside the stack hosting the editor, so Back returns to the collection — the
    /// tab the reader is working in — rather than unwinding Browse's history (2026-09-11).
    private func openInReader(_ entry: CollectionEntry) {
        let browseEntry = readerEntry(for: entry)
        #if os(macOS)
        appState.openDocument(browseEntry, from: .global, using: openWindow)
        #else
        readingChain = [browseEntry]
        #endif
    }

    /// The reader's entry for a collection entry's document.
    private func readerEntry(for entry: CollectionEntry) -> DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: entry.documentId, volumeId: entry.volumeId,
                             header: entry.titleOverride ?? entry.documentId)
    }

    /// The iPhone's per-entry drill-in (Composer redesign 4), with Open Document reading the document
    /// above it, so Back returns to the entry's settings (L19, IPA-4). The reader is iOS's; the Mac's
    /// sheet editor drills in with no Open Document, as its row has its own.
    @ViewBuilder
    private func drillInInspector(_ entry: CollectionEntry) -> some View {
        #if os(iOS)
        entryInspectorContent(entry, isPushed: true,
                              onOpenDocument: { inspectorReadingChain = [readerEntry(for: entry)] })
            .inPlaceReader($inspectorReadingChain)
        #else
        entryInspectorContent(entry, isPushed: true)
        #endif
    }

    /// Open Document in the iPad's Configure sheet (L19, IPA-4): closes the sheet, which opens the
    /// document once it has gone (``openDocumentAfterInspector()``).
    private func openWhenInspectorCloses(_ entry: CollectionEntry) {
        openAfterInspectorCloses = entry.id
        inspectedEntryId = nil
    }

    /// The Configure sheet's `onDismiss`: reads the document Open Document asked for, if any, in the
    /// editor's stack. After the sheet has gone, so the push is not made under a closing sheet.
    private func openDocumentAfterInspector() {
        guard let id = openAfterInspectorCloses else { return }
        openAfterInspectorCloses = nil
        if let entry = sortedEntries.first(where: { $0.id == id }) { openInReader(entry) }
    }

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
                                       onOpenDocument: (() -> Void)? = nil) -> some View {
        CollectionEntryInspector(
            entry: entry,
            // #1619: no Insert as Excerpt into a smart collection, which leaves hand-added passages out of every export.
            onInsertExcerpt: takesHandAddedEntries ? { capture in appendExcerpts([capture]) } : nil,
            onNewNote: {
                if sortedEntries.contains(where: { $0.id == entry.id }) {
                    noteCreateContext = NoteCreateContext(
                        documentId: entry.documentId,
                        volumeId: entry.volumeId,
                        entryId: entry.id)
                }
            },
            // iPhone presents the inspector as a drill-in push (Composer redesign 4), so it omits
            // its own navigation stack + Done button.
            isPushed: isPushed,
            // L19 (IPA-4): the reader, from the screen a row's tap opens.
            onOpenDocument: onOpenDocument
        )
        .id(entry.id)
        .environment(appState)
    }

    /// Numbers the outline `0..<n` in its order, and after it any entry the model holds that the outline has not
    /// followed yet (`CollectionEntryOrdering.renumber`, #1416) — so no two entries are left sharing a position.
    private func reindexEntries() {
        CollectionEntryOrdering.renumber(sortedEntries, in: collection)
    }

    /// Appends document entries at the end of the entry list in the given order.
    /// Duplicates are allowed (A4) — repeats get an "Also in collection" badge instead
    /// of being silently skipped.
    ///
    /// - Returns: Whether the collection took them: `false` for a smart collection (#1619), so
    ///   the Add Documents sheet's commit confirms nothing it did not add.
    @discardableResult
    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) -> Bool {
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

    // MARK: - Committing edits (#1415, #1413)

    /// A binding to one of the editor's own fields whose setter also commits the reader's edit to the collection:
    /// `commit` writes the new value when it changes what is saved (`CollectionEditorCommit`) and says whether it did,
    /// and a write is then recorded (`recordEdit()`). All-live autosave (A1): the export sheet and every other consumer
    /// see the edit at once, with no separate Save step.
    ///
    /// **Why the setter, and not `onChange`.** On a compact width Collection settings is a screen PUSHED over the
    /// editor, and SwiftUI runs no `onChange` on a covered, pushed view: measured at #1359 on iPhone 17 (iOS 26.5), a
    /// name typed there reached the model 14 ms before the editor's `onAppear`, seconds after the typing. (An editor at
    /// the ROOT of its own stack — the sheet presentation — went on running `onChange` under the same screen, measured
    /// by `CollectionEditorNamingTests`' host; the Collections tab pushes it.) So an edit made there and left
    /// by the Collections tab — which pops the stack without the editor ever reappearing — or by the app being killed
    /// never reached the model, and an unnamed new collection given only such edits was discarded as untouched
    /// (#1415). A binding's setter runs when its control changes, wherever the control is drawn.
    ///
    /// Only the reader's edits come through here. `FrontMatterModelSync` follows a change made elsewhere by writing the
    /// `@State` directly, so following never commits anything.
    private func committing<Value>(_ field: Binding<Value>,
                                   _ commit: @escaping (Value) -> Bool) -> Binding<Value> {
        Binding(get: { field.wrappedValue }, set: { newValue in
            field.wrappedValue = newValue
            if commit(newValue) { recordEdit() }
        })
    }

    /// Links the collection to a saved search, or unlinks it (`nil`), and commits the change — the one collection
    /// field the editor sets from buttons rather than from a bound control, so it commits here, not via `committing`.
    private func linkSavedSearch(_ id: UUID?) {
        linkedSavedSearchId = id
        if CollectionEditorCommit.savedSearch(id, to: collection) { recordEdit() }
    }

    /// Records an edit the reader has just written onto the collection: tags the collection into the active project, as
    /// the editor's saves always have, and saves — so the edit survives the app being killed.
    private func recordEdit() {
        if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) {
            collection.projectIds.append(projectId)
        }
        try? modelContext.save()
    }
}

// MARK: - FrontMatterModelSync

/// Keeps `CollectionEditorView`'s one-time `@State` copies of the collection's name, description, subtitle, author line
/// and three front-matter flags in step with the model when something else writes them — and, since MACCOL, the Mac
/// Collections window detail pane's (`CollectionDetailPane`), whose copies of the same seven fields another writer
/// changes through the Manage Collections sheet's rename or iCloud. It only ever FOLLOWS: it writes
/// the editor's copies and never the collection, so following a change never saves anything (#1413).
///
/// - **The description, subtitle, author line and flags (#1413):** another iPad window or iCloud. Until L44 a heading
///   row's Section defaults sheet (`CollectionAttributesRows`) wrote all six directly on the model, the text as the
///   reader typed it, untrimmed; since L44 that sheet holds the section's own settings and nothing of the collection's.
/// - **The name (#1359):** another iPad window editing the same collection, or iCloud bringing a rename from another
///   device. Nothing on iOS renames a collection while its editor is open in the same window: the editor's own "Untitled
///   Collection" default is written only once the editor is dismissed (`NewCollectionSession`), never when a screen is
///   pushed over it.
///
/// **Why the editor needs the follow.** Its fields show these copies, and the reader's next edit to a field builds on
/// what the field shows. Without the follow, a subtitle set in Section defaults was invisible in the editor's own
/// Subtitle field, and typing there started from the value the editor opened with. The editor used to have a second,
/// worse reason: its old `saveLive()` wrote EVERY copy back on every edit, so any rename or toggle put the stale copies
/// over the sheet's writes — including the toggle's own follow here, which fired the editor's save. The reader's edits
/// now commit one field at a time (`CollectionEditorCommit`), so a stale copy of one field no longer rides along on an
/// edit to another; the follow is what keeps the field being edited current.
///
/// **Each text follow passes through agreement** (`CollectionEditorNaming.fieldAgrees`,
/// `CollectionEditorCommit.fieldAgrees`): a change to the saved value is followed only when the field says something
/// else once both are trimmed. The editor saves a field trimmed, so its own commit comes back through `onChange` as a
/// value the field already agrees with, and a trailing space the reader has just typed stays under their cursor. The
/// flags keep their `!=` guard.
///
/// **The smart-collection link is not followed.** It is written only when the reader links or unlinks in this editor
/// (`CollectionEditorCommit.savedSearch`), never alongside another field, so a stale copy of it is never written back.
///
/// A `ViewModifier` so its `.onChange`s are type-checked apart from the (long) editor body; `internal` rather than
/// `private` so `CollectionEditorNamingTests` can host it in a window and drive it through SwiftUI's own `onChange`.
struct FrontMatterModelSync: ViewModifier {
    /// The editor's name field.
    @Binding var collectionName: String
    /// The editor's description (note) field.
    @Binding var collectionNote: String
    /// The editor's subtitle field.
    @Binding var collectionSubtitle: String
    /// The editor's author-line field.
    @Binding var collectionAuthorLine: String
    /// The editor's colophon toggle.
    @Binding var includeColophon: Bool
    /// The editor's project-provenance toggle.
    @Binding var includeProjectProvenance: Bool
    /// The editor's method-appendix toggle.
    @Binding var includeMethodAppendix: Bool
    /// The collection the editor writes.
    let collection: Collection

    func body(content: Content) -> some View {
        content
            // #1359: follow a rename made elsewhere, unless the field already says it.
            .onChange(of: collection.name) { _, newValue in
                if !CollectionEditorNaming.fieldAgrees(collectionName, withSavedName: newValue) {
                    collectionName = newValue
                }
            }
            // #1413: the three text fields another window or iCloud writes (a heading's Section defaults sheet did until L44).
            .onChange(of: collection.note) { _, newValue in
                if !CollectionEditorCommit.fieldAgrees(collectionNote, withSaved: newValue) {
                    collectionNote = newValue ?? ""
                }
            }
            .onChange(of: collection.subtitle) { _, newValue in
                if !CollectionEditorCommit.fieldAgrees(collectionSubtitle, withSaved: newValue) {
                    collectionSubtitle = newValue ?? ""
                }
            }
            .onChange(of: collection.authorLine) { _, newValue in
                if !CollectionEditorCommit.fieldAgrees(collectionAuthorLine, withSaved: newValue) {
                    collectionAuthorLine = newValue ?? ""
                }
            }
            .onChange(of: collection.includeColophon) { _, newValue in
                if newValue != includeColophon { includeColophon = newValue }
            }
            .onChange(of: collection.includeMethodAppendix) { _, newValue in
                if newValue != includeMethodAppendix { includeMethodAppendix = newValue }
            }
            .onChange(of: collection.includeProjectProvenance) { _, newValue in
                if newValue != includeProjectProvenance { includeProjectProvenance = newValue }
            }
    }
}

// MARK: - CollectionEntriesModelSync

/// Keeps a collection editor's outline — its `sortedEntries`, which its rows, live preview and export sheet all read —
/// in step with the entries its collection holds in the model, when another writer adds, removes or moves one (#1416):
/// a document's Add to Collection picker on another tab, another iPad window, iCloud. Applied by `CollectionEditorView`
/// and by the Mac manager's `CollectionDetailPane`, the two editors that hold an outline.
///
/// It watches the ids of ``CollectionEntryOrdering/modelOrder(of:outline:)`` — the collection's live entries in
/// position order, so a change of position alone fires it as well as an entry coming or going — and when they change
/// replaces the outline with ``CollectionEntryOrdering/reconciled(_:with:)``. The editors' own changes arrive here
/// already in the outline's order: an appended document or excerpt takes the position after every entry
/// (``CollectionEntryOrdering/nextSortOrder(in:outline:)``) and goes at the outline's end, renumbering nothing, and a
/// reorder, a delete, Sort by Date or an added heading, note or apparatus block renumbers the model to the outline
/// (``CollectionEntryOrdering/renumber(_:in:)``). So they replace nothing, apart from bringing in an entry another
/// writer added that the outline had not followed yet. Following writes nothing to the model.
///
/// It does not fire for the value it starts on (`onChange` never does), which is why both editors seed their outline
/// from ``CollectionEntryOrdering/modelOrder(of:outline:)`` too: an outline seeded any other way would stay out of step
/// until the model next moved.
///
/// A `ViewModifier`, like `FrontMatterModelSync`, so its `.onChange` is type-checked apart from the editors' long
/// bodies; `internal` so `CollectionEntryOrderingTests` can host it and drive it through SwiftUI's own `onChange`.
struct CollectionEntriesModelSync: ViewModifier {
    /// The editor's outline.
    @Binding var outline: [CollectionEntry]
    /// The collection the editor shows.
    let collection: Collection

    func body(content: Content) -> some View {
        content
            .onChange(of: CollectionEntryOrdering.modelOrder(of: collection, outline: outline).map(\.id)) { _, _ in
                if let followed = CollectionEntryOrdering.reconciled(outline, with: collection) { outline = followed }
            }
    }
}

// MARK: - NewCollectionDismissal

/// Ends a new collection's editing session (`NewCollectionSession`) when `CollectionEditorView` is really dismissed — and
/// not when a screen is pushed over it (#1359 review).
///
/// **Why `onDisappear` alone was wrong.** The Collections tab pushes the editor (`.pushed`) onto its own stack, and the
/// editor pushes onto that same stack: the iPhone Collection settings screen, the iPhone per-entry inspector, a
/// document opened in place. Each push fires the editor's `onDisappear`. Measured on iPhone 17 (iOS 26.5), before this
/// modifier: opening Collection settings on an UNTOUCHED new collection deleted it — the model object left its context
/// while the user named it there, and came back only because the editor's `onAppear` inserts it again — and on a new
/// collection with content it wrote "Untitled Collection", which the title showed on return and the name field then
/// followed.
///
/// **What tells the two apart.** `isPresented` reads `true` in `onDisappear` when a screen is pushed over the pushed
/// editor (the stack still holds it) and `false` when Back pops it — and turns `false` BEFORE that `onDisappear`, so
/// Back ends the session through `onChange`. It does NOT tell the SHEET's dismissal apart: it read `true` there too.
/// Only `.pushed` asks, which is safe because the sheet's `onDisappear` sits outside the sheet's own `NavigationStack`
/// (`iOSBody`), and pushing Collection settings inside that stack did not fire it (measured).
///
/// **The third signal is the session's own `deinit`.** A pushed editor taken off the stack while something it pushed
/// still covers it — the Collections tab tapped again from Collection settings — gets neither signal: a covered view
/// is not updated, so `isPresented` never changes where `onChange` could see it, and there is no second
/// `onDisappear` (measured). Its state is torn down all the same.
///
/// **A tab switch is not a dismissal, and that has a price.** Switching tabs fires the pushed editor's `onDisappear`
/// with `isPresented` still `true` (measured), the same as a push-over, and the editor IS still on its tab's stack: the
/// reader comes back to it. Ending the session there would name a kept collection "Untitled Collection" before they
/// return — the title and the name field would then show it, the defect this modifier exists to stop — or delete one
/// they are still editing. So while the editor waits in a background tab, its collection is in the store with no
/// name, where other screens can list it. The lists that printed the name bare now print
/// `CollectionEditorNaming.listName`, and the session judges "untouched" from the model, so a document added to the
/// collection from another tab keeps it. If the app is killed meanwhile, an untouched collection outlives it as an
/// empty "Untitled Collection" row — as one did on `v2` when the app was killed with the editor on screen.
private struct NewCollectionDismissal: ViewModifier {
    /// The editor's session; `nil` for a collection it opened, which has nothing to end.
    let session: NewCollectionSession?
    /// Whether the editor is pushed onto its presenter's stack (`CollectionEditorView.PresentationStyle.pushed`).
    let isPushed: Bool
    /// Whether the editor is still presented: `true` while its presenter's stack holds it, covered or not.
    @Environment(\.isPresented) private var isPresented

    func body(content: Content) -> some View {
        content
            .onDisappear {
                // A screen pushed over the pushed editor, or a tab switch: it is still on the stack.
                if isPushed && isPresented { return }
                session?.end()
            }
            .onChange(of: isPresented) { _, presented in
                if isPushed && !presented { session?.end() }
            }
    }
}

// MARK: - NewCollectionSession

/// A collection `CollectionEditorView` created, from the moment the editor inserts it until the editor is dismissed —
/// which ends the session exactly once: an untouched collection is discarded, and a kept one with no name is named
/// "Untitled Collection" so it does not render as a blank list row.
///
/// **"Untouched" is read from the MODEL when the session ends — every field and every entry — never from the
/// editor's own copies.** While the editor waits in a background tab (a tab switch does not end the session; see
/// `NewCollectionDismissal`) the collection can gain an entry somewhere else: a document's Add to Collection picker
/// lists it. When #1359 added this rule the editor's outline was loaded once and never followed the model, so, judged
/// from the outline, that collection was deleted at Back, and because `documentEntries` is `.nullify` the new entry
/// was left pointing at nothing (#1359 review, round 2). The outline follows the model since #1416
/// (`CollectionEntriesModelSync`), but only when the editor's view is next updated, and a session can end with no
/// update to come — so the rule still reads the model. An entry the context has deleted does not count: measured,
/// until the context saves, `documentEntries` still lists an entry deleted from it, so a plain `isEmpty` kept — and
/// named — a new collection whose only entry had been added and removed again.
///
/// A class, held in the editor's `@State`, so that its `deinit` can end the session when the editor's state is torn
/// down without any view event saying so — see `NewCollectionDismissal`. The editor's `init` runs on every parent
/// update and builds a session each time; only the first is kept, and the rest end without doing anything because
/// only the kept one is ever given a context (`begin(in:)`, from the editor's `onAppear`).
@MainActor
final class NewCollectionSession {
    /// The collection the editor created.
    private let collection: Collection
    /// The context the editor inserted it into; `nil` until `begin(in:)`.
    private var context: ModelContext?
    /// Whether the session has ended; a dismissal can report itself twice.
    private var hasEnded = false

    /// A session for `collection`, which the editor has created and not yet inserted.
    init(collection: Collection) {
        self.collection = collection
    }

    /// Starts the session: the editor has inserted the collection into `context`.
    func begin(in context: ModelContext) {
        self.context = context
    }

    /// Ends the session, once: discards the collection when nothing in it was touched, and names it "Untitled
    /// Collection" when it was kept with no name. Does nothing before `begin(in:)`.
    func end() {
        guard let context, !hasEnded else { return }
        hasEnded = true
        if Self.isUntouched(collection) {
            context.delete(collection)
        } else if collection.name.isEmpty {
            collection.name = String(localized: "collection.editor.untitled",
                                     defaultValue: "Untitled Collection")
        }
    }

    /// Whether `collection` holds nothing a reader put in it: no name, no front matter, no linked saved search, no
    /// front-matter flag turned on, and no entry the context still holds.
    private static func isUntouched(_ collection: Collection) -> Bool {
        collection.name.isEmpty && collection.note == nil
            && collection.savedSearchId == nil
            && collection.subtitle == nil && collection.authorLine == nil
            && collection.introductionText == nil && !collection.includeColophon
            && !collection.includeProjectProvenance && !collection.includeMethodAppendix
            && !(collection.documentEntries ?? []).contains { !$0.isDeleted }
    }

    /// Ends a session no view event ended: the editor's state is being torn down, so the editor is gone.
    isolated deinit {
        end()
    }
}

// MARK: - SmartCollectionLinkRows

/// A linked collection's Smart Collection rows: the saved search it is linked to, with Unlink, and what the link does;
/// or, when no saved search has the linked id any more, that it could not be found, with Unlink all the same (#1619
/// review).
///
/// A smart collection takes no hand-added document, heading, note block or passage (`SmartCollectionRule`), so Unlink is
/// the way back to taking them. These rows showed only while the linked search could be found; otherwise the section
/// offered Link to Saved Search…, disabled when no search is saved, so a collection whose search was deleted could not be
/// unlinked, and after #1619 could not take a hand-added entry again. Shared by the iOS editor's Collection settings
/// (`CollectionEditorView.smartCollectionRows`, also the Mac's New Collection sheet) and the Mac Collections window's
/// ⚙ Collection popover (`CollectionDetailPane`), which had no Smart Collection rows at all.
///
/// Version history:
///   1.0 — #1619 review, round 1: initial implementation, from `CollectionEditorView.smartCollectionRows`' linked rows
struct SmartCollectionLinkRows: View {

    /// The linked saved search's name, or `nil` when no saved search has the linked id: it was deleted, on this device
    /// or another.
    let savedSearchName: String?
    /// Removes the link. The caller commits it.
    let onUnlink: () -> Void

    var body: some View {
        HStack {
            if let savedSearchName {
                Label(savedSearchName, systemImage: "bolt.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Label(String(localized: "collection.editor.smart.missing", defaultValue: "Saved search not found"),
                      systemImage: "bolt.slash")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "collection.editor.smart.unlink", defaultValue: "Unlink"), action: onUnlink)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
                .font(.callout)
        }
        Text(savedSearchName == nil
             ? String(localized: "collection.editor.smart.missing.explanation",
                      defaultValue: "The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.")
             : String(localized: "collection.editor.smart.explanation",
                      defaultValue: "Documents are resolved from this saved search at export time. Static entries are ignored."))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - SmartCollectionLinkButton

/// An unlinked collection's Smart Collection row: **Link to Saved Search…**, which opens `LinkSavedSearchPicker`, dimmed
/// with a line that says how to save a search when none is saved.
///
/// Shared by the iOS editor's Collection settings (`CollectionEditorView.smartCollectionRows`, also the Mac's New
/// Collection sheet) and the Mac Collections window's ⚙ Collection popover (`CollectionDetailPane`). Until #1687 the
/// popover had only `SmartCollectionLinkRows`, so on the Mac a collection could be linked only while Add to Collection's
/// New Collection created it. The line names the Search window on the Mac, which has no Search tab.
///
/// Version history:
///   1.0 — #1687, decision 70 of the 2026-10-14 plan of record: from `CollectionEditorView.smartCollectionRows`' unlinked
///          rows, with the Mac's own line
struct SmartCollectionLinkButton: View {

    /// Whether any search is saved. With none the button is dimmed, and the line under it says how to save one.
    let hasSavedSearches: Bool
    /// Opens the picker. The caller presents it.
    let onLink: () -> Void

    var body: some View {
        Button(action: onLink) {
            Label(String(localized: "collection.editor.smart.link",
                         defaultValue: "Link to Saved Search\u{2026}"),
                  systemImage: "bolt")
        }
        // `CollectionEditorTitleTests` (#1704) opens the picker from Collection settings with it.
        .accessibilityIdentifier("collection.editor.smart.link")
        .disabled(!hasSavedSearches)
        if !hasSavedSearches {
            #if os(macOS)
            Text(String(localized: "collection.editor.smart.noSearches.mac",
                        defaultValue: "Save a search from the Search window to enable smart collections."))
                .font(.caption)
                .foregroundStyle(.secondary)
            #else
            Text(String(localized: "collection.editor.smart.noSearches",
                        defaultValue: "Save a search from the Search tab to enable smart collections."))
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
        }
    }
}

// MARK: - LinkSavedSearchPicker

/// The Link to Saved Search picker: the saved searches, newest first, each a row that links the collection to it, and
/// Cancel.
///
/// Presented by the iOS editor (`CollectionEditorView.linkSavedSearchSheet`): from Collection settings, which on iPad is
/// a sheet that presents it itself since #1704, and from the Mac's New Collection sheet. Since #1687 also by the Mac
/// Collections window, from its ⚙ Collection popover's Link to Saved Search… (`CollectionDetailPane`), so both Mac
/// surfaces open one picker. Each presenter commits the link through `CollectionEditorCommit.savedSearch(_:to:)`.
///
/// Version history:
///   1.0 — Session 129: `linkSavedSearchSheet`'s macOS and iOS bodies, inside `CollectionEditorView`
///   1.1 — #1687, decision 70 of the 2026-10-14 plan of record: a view of its own, so the Mac Collections window
///          presents the picker the editor presents
struct LinkSavedSearchPicker: View {

    /// The saved searches to offer, in the order they are listed.
    let savedSearches: [SavedSearch]
    /// Links the collection to the saved search with this id. The caller commits the link and closes the picker.
    let onLink: (UUID) -> Void
    /// Closes the picker and links nothing.
    let onCancel: () -> Void

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    #if os(macOS)
    /// macOS variant: plain VStack + button bar avoids the NavigationStack sidebar issue.
    private var macBody: some View {
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

            if savedSearches.isEmpty {
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
                List(savedSearches) { search in
                    Button {
                        onLink(search.id)
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
                        // #312 follow-up: full-row tap target — both modifiers, in this order.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "collection.editor.smart.picker.cancel",
                              defaultValue: "Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 360, minHeight: 280)
    }
    #endif

    /// iOS / iPadOS variant: NavigationStack with inline title and Cancel toolbar button.
    private var iOSBody: some View {
        NavigationStack {
            List(savedSearches) { search in
                Button {
                    onLink(search.id)
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
                                  defaultValue: "Cancel"), action: onCancel)
                }
            }
        }
    }
}

// MARK: - SmartCollectionEntriesFromBeforeLink

/// A smart collection's entries from before its link, listed apart from its Contents under a dimmed heading that says
/// they are not part of it and why, with a button that removes them once the reader confirms (#1619; decision 22 of the
/// 2026-10-14 plan of record).
///
/// A smart collection takes no hand-added document, heading, note block or passage (`SmartCollectionRule`), so an entry
/// of those kinds is one it held before it was linked, and everything it produces leaves it out. Until decision 22 both
/// editors listed such entries in Contents among the ones it keeps, with nothing to say they were ignored. Each row here
/// is a report: the entry's kind by its icon, and its words, dimmed. Nothing is removed without the reader's tap: the
/// button asks first, saying how many go, and nothing else removes them. Unlinked, the collection counts them again.
///
/// A `Section`, so it sits in the iOS editor's `Form` (also the Mac's New Collection sheet) and in the Mac Collections
/// window's Contents `List`, each of which mounts it under its Contents rows. The heading is the section's header in a
/// form, and its first row in the Mac window's list (`headingIsRow`), whose header is one line high.
///
/// Version history:
///   1.0 — #1619, decision 22: initial implementation
///   1.1 — #1704, from #1702's visual review on the iOS 27.0 simulators: the heading is drawn in the secondary label
///          colour, where the hierarchical style put it a level below a form header's own; Remove These Entries' icon
///          is red on iPhone and iPad, where it took the accent colour; and a row's caption wraps rather than being cut
///   1.2 — 2026-10-21: #1761 — at an accessibility text size a row's title wraps whole, where two lines held a few
///          words of a document's title on an iPhone 17
struct SmartCollectionEntriesFromBeforeLink: View {

    /// The entries, in the outline's order (`SmartCollectionRule.entriesFromBeforeLink`).
    let entries: [CollectionEntry]
    /// The documents' indexed headers, keyed `"volumeId/documentId"`, as the editors load them for their rows; a
    /// document with none reads by its id, as its row in Contents does.
    let documentHeaders: [String: String]
    /// Removes the entries. Called only by the dialog's destructive action; the caller numbers and saves what is left.
    let onRemove: () -> Void
    /// Whether the heading is the section's first row rather than its header. The Mac window's inset `List` sets a
    /// section header on one line and cut this one at the column's width, "…linked to its save…", where the grouped
    /// forms wrap it (seen in the Mac check copy, 2026-10-16); a row wraps.
    var headingIsRow = false

    /// Whether the dialog that asks before the entries are removed is showing.
    @State private var isConfirmingRemoval = false
    /// The reader's text size: at an accessibility size a row's title wraps whole.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if headingIsRow {
            Section {
                heading
                    .selectionDisabled()
                content
            }
        } else {
            Section {
                content
            } header: {
                heading
            }
        }
    }

    /// The dimmed heading: why these entries are not part of the smart collection.
    ///
    /// Drawn in the secondary label colour itself (`Color.secondary`), the colour of a form's own section headers, as
    /// a header and as a row alike. The hierarchical `.secondary` it had resolves one level below whatever holds it,
    /// and a form's header is already drawn at secondary, so on iPhone and iPad it drew the heading at tertiary
    /// strength: 1.71:1 on the grouped background, where Contents' header beside it measured 3.29:1 (#1704).
    private var heading: some View {
        Text(SmartCollectionRule.entriesFromBeforeLinkHeading)
            .font(headingIsRow ? .callout.weight(.semibold) : nil)
            .foregroundStyle(Color.secondary)
            // A sentence, which a list's uppercase header style would set in capitals.
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// The entries' rows and the button that removes them.
    @ViewBuilder
    private var content: some View {
        ForEach(entries, id: \.id) { entry in
            row(for: entry)
                // A `ForEach` row is tagged with its id, which in the Mac window's Contents `List` is the
                // selection's type: unmarked, a row could be selected, and ↩ would open the entry inspector on
                // an entry the collection leaves out (seen in the Mac check copy, 2026-10-16).
                .selectionDisabled()
        }
        Button(role: .destructive) {
            isConfirmingRemoval = true
        } label: {
            // The icon is red itself. In a form row the destructive role reds the title alone, and the icon was drawn
            // in the accent blue beside it on iPhone and iPad; a red tint on the button left it blue too (#1704).
            Label {
                Text(SmartCollectionRule.removeEntriesFromBeforeLink)
            } icon: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
        #endif
        .confirmationDialog(SmartCollectionRule.removeEntriesFromBeforeLinkTitle,
                            isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button(SmartCollectionRule.removeEntriesFromBeforeLink, role: .destructive, action: onRemove)
        } message: {
            Text(SmartCollectionRule.removeEntriesFromBeforeLinkMessage(count: entries.count))
        }
    }

    /// One entry's row: its kind by its icon, its words, and for a document or passage where it comes from, dimmed.
    private func row(for entry: CollectionEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: Self.systemImage(for: entry.entryKind))
                .font(.caption)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // Two lines, as Contents gives a title, or as many as it needs at an accessibility size: at the largest
                // on an iPhone 17 two lines held a few words of a document's title (#1761).
                Text(title(for: entry))
                    .font(entry.entryKind == .excerpt ? .callout.italic() : .callout)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                // Wraps where one line cannot hold it: held to one, it read "d172 · frus19…" at the largest
                // accessibility size on an iPhone, cutting the volume it names (#1704).
                if let caption = Self.caption(for: entry, documentHeader: documentHeader(for: entry)) {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    /// The indexed header of a document entry, or `nil`.
    private func documentHeader(for entry: CollectionEntry) -> String? {
        entry.entryKind == .document ? documentHeaders["\(entry.volumeId)/\(entry.documentId)"] : nil
    }

    /// An entry's words: a document's header or id, as its row in Contents reads; a heading's text, or "Untitled
    /// section"; a note block's text, or `SmartCollectionRule.emptyNoteBlock`; a passage's text.
    private func title(for entry: CollectionEntry) -> String {
        let text = (entry.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch entry.entryKind {
        case .document:
            return documentHeader(for: entry) ?? entry.documentId
        case .heading:
            return text.isEmpty ? CollectionEditorNaming.untitledSection : text
        case .prose:
            return text.isEmpty ? SmartCollectionRule.emptyNoteBlock : text
        case .excerpt:
            return text
        case .generated, .unrecognized:
            // Never listed here: a smart collection keeps both (`SmartCollectionRule.leavesOut`).
            return ""
        }
    }

    /// Where a document or passage comes from — its id when its header is the title, and its volume — or `nil` for a
    /// heading, a note block, and a passage that names neither.
    static func caption(for entry: CollectionEntry, documentHeader: String?) -> String? {
        let parts: [String?]
        switch entry.entryKind {
        case .document:
            parts = [documentHeader != nil ? entry.documentId : nil, entry.volumeId]
        case .excerpt:
            parts = [entry.documentId, entry.volumeId]
        case .heading, .prose, .generated, .unrecognized:
            return nil
        }
        let named = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return named.isEmpty ? nil : named.joined(separator: " · ")
    }

    /// The icon this group gives an entry of `kind`: a heading's, a note block's and a passage's are the ones their rows
    /// in Contents and their Add menu items carry, and a document's is the system's page.
    static func systemImage(for kind: CollectionEntryKind) -> String {
        switch kind {
        case .document: return "doc.text"
        case .heading: return "number"
        case .prose: return "text.alignleft"
        case .excerpt: return "text.quote"
        case .generated: return "list.bullet.rectangle"
        case .unrecognized: return "questionmark.square.dashed"
        }
    }
}

// MARK: - CollectionEditorCommit

/// The collection editor's rules for writing the reader's edits onto the collection (#1415, #1413): each field is
/// written ON ITS OWN, and only when the edit changes what is saved.
///
/// **Per field, because a stale copy of one field must never ride along on an edit to another (#1413).** The editor
/// shows each field from a `@State` copy it took when it opened. Its old `saveLive()` wrote EVERY copy onto the
/// collection on every edit, so a description, subtitle or author line that a heading's Section defaults sheet had
/// since written straight onto the model was put back as it was by the next rename, toggle or keystroke — and by the
/// editor following a toggle flipped in that same sheet, because following a flag fired the same save. Written per
/// field, an edit writes the field it edits and nothing else.
///
/// **Only on a change to what is saved.** The editor saves a text field trimmed, `nil` when empty, and a field that
/// differs from the saved value only in surrounding whitespace says the same thing (`fieldAgrees`). So a keystroke that
/// adds only a space writes nothing, and a value another writer saved untrimmed is not rewritten trimmed under them.
///
/// **Where they run.** The editor calls these from its fields' own bindings (`CollectionEditorView.committing`), as the
/// reader edits, and records the edit — the active project and a save — when one returns `true`. Never from `onChange`:
/// on the compact layout Collection settings is pushed OVER the editor, and a covered, pushed editor runs none (#1415).
/// The Mac Collections window's detail pane (`CollectionDetailPane`) calls them the same way, from its ⚙ popover's
/// controls, and saves when one returns `true` (MACCOL); since #1619's review its Unlink is one of them.
///
/// Pure and `internal` so `CollectionEditorNamingTests` calls the rules the editor calls.
///
/// Version history:
///   1.0 — #1415 / #1413: initial implementation, replacing `CollectionEditorView.saveLive()`
///   1.1 — MACCOL: the Mac detail pane commits through these too, replacing its `saveMetadata()`
///   1.2 — #1619 review: the Mac pane's ⚙ popover unlinks a smart collection through `savedSearch`
///   1.3 — #1823: `rename`, the Rename alert's commit on the iPhone and iPad Collections list and the Mac window's
///          Collection menu, and the Mac's Manage Collections rows commit through `name`
enum CollectionEditorCommit {

    /// Whether a text field and the optional value saved for it say the same thing: equal once both are trimmed, with
    /// no saved value reading as empty — the editor saves an empty field as `nil`.
    static func fieldAgrees(_ fieldText: String, withSaved saved: String?) -> Bool {
        CollectionEditorNaming.fieldAgrees(fieldText, withSavedName: saved ?? "")
    }

    /// Writes the name field's text onto `collection`, trimmed, when it says something the saved name does not.
    /// Returns whether it wrote.
    static func name(_ fieldText: String, to collection: Collection) -> Bool {
        guard !CollectionEditorNaming.fieldAgrees(fieldText, withSavedName: collection.name) else { return false }
        collection.name = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    /// Writes the Rename alert's text onto `collection` as `name(_:to:)` does, except that a name left empty keeps the
    /// one it had: the alert renames, and a list's New Collection asks for a name too (#1823). Returns whether it wrote.
    static func rename(_ fieldText: String, to collection: Collection) -> Bool {
        guard !fieldText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return name(fieldText, to: collection)
    }

    /// Writes an optional text field — the description (`note`), subtitle or author line — onto `collection`: trimmed,
    /// or `nil` when nothing is left, and only when it says something the saved value does not. Returns whether it
    /// wrote.
    static func text(_ fieldText: String, to keyPath: ReferenceWritableKeyPath<Collection, String?>,
                     of collection: Collection) -> Bool {
        guard !fieldAgrees(fieldText, withSaved: collection[keyPath: keyPath]) else { return false }
        let trimmed = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        collection[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
        return true
    }

    /// Writes a front-matter toggle onto `collection` when it differs from the saved flag. Returns whether it wrote.
    static func flag(_ isOn: Bool, to keyPath: ReferenceWritableKeyPath<Collection, Bool>,
                     of collection: Collection) -> Bool {
        guard collection[keyPath: keyPath] != isOn else { return false }
        collection[keyPath: keyPath] = isOn
        return true
    }

    /// Writes the linked saved search — `nil` to unlink — onto `collection` when it differs from the saved link.
    /// Returns whether it wrote.
    static func savedSearch(_ id: UUID?, to collection: Collection) -> Bool {
        guard collection.savedSearchId != id else { return false }
        collection.savedSearchId = id
        return true
    }
}

// MARK: - One copy of each note and saved search (#1791)

extension CollectionEditorView {
    /// Every note, one copy of each however many are stored under its id (`DuplicateCopies`),
    /// newest first: what the entries' note rows, the note pickers and the exports read.
    private var allNotes: [ResearchNote] { ResearchNote.oneCopyEach(allNoteCopies) }

    /// Every saved search, one copy of each, newest first: what Link to Saved Search… offers and
    /// what names a smart collection's search.
    private var allSavedSearches: [SavedSearch] { SavedSearch.oneCopyEach(allSavedSearchCopies) }
}
