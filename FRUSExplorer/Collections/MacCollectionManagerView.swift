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
import UniformTypeIdentifiers

// MARK: - MacCollectionManagerView

/// Root view for the "Collections" window on macOS.
///
/// Presents a `NavigationSplitView`:
///   - **Sidebar** — list of all collections (filtered to active project); supports
///     selection, deletion via context menu, and creating new collections.
///   - **Detail** — inline editor for the selected collection: editable name and note
///     (auto-saved), reorderable document list, per-document note management, and
///     toolbar actions for Add Documents, Sort by Date, and Export.
///
/// Version history:
///   1.0 — Session 73: initial implementation replacing CollectionListView in the
///          Collections window scene; NavigationSplitView with inline editing.
///   1.1 — Session 74: two-line research note preview added to MacEntryRow beneath
///          volume title; caption2/tertiary styling; fixedSize for correct wrapping
///   1.2 — Session 89: manual entry deletion before collection delete (deleteRule .nullify)
///   1.3 — Session 130: drop outer ScrollView from CollectionDetailPane so the document
///          List fills available window height instead of being fixed to entry-count height
///   1.4 — Session 130: document header (from document_cache) shown in each row;
///          per-row delete button; multi-note support via selectedNoteIds; inline
///          Sort by Date control in Documents section header; toolbar tooltip improvements
///   1.5 — Session 2026-07-02: consumes appState.pendingCollectionSelection so an
///          open-with .fruscollection import lands on the imported collection
///   1.5 — Authoring Phase 1: header/date loading and Sort by Date moved to the shared
///          `CollectionEntryData` (behavior-identical; now also used by the iOS editor);
///          `.unrecognized` entries render as an inert row; import fileImporter narrowed
///          from `.data` to the declared `.fruscollection` UTI
///   1.6 — Authoring Phase 1 shell: Composition moved from a bounded popover to an inline
///          collapsed disclosure at the top of the entries List — inline as the scope asks,
///          but inside the scrolling region so expansion can never grow the fixed header
///          past the window (the constraint that forced the popover)
///   1.7 — Authoring Phase 2b: detail pane gains a toolbar-toggled side-by-side live
///          preview (`CollectionPreviewView`) to the right of the editor column
///   1.8 — Authoring Phase 3: toolbar "Add by Tag" replaced by "Add Documents…"
///          (`CollectionAddDocumentsSheet`: Search | Browse | Citations | Tags, ⇧⌘A);
///          added documents append at the end of the entry list in selection order;
///          `appendEntries` allows duplicates (A4) via the shared
///          `CollectionDocumentDiscovery.appendEntries`, with repeated documents
///          badged "Also in collection" on their rows
///   1.9 — Authoring Phase 4 (editor step): the entries List renders the derived outline
///          (rows indent by `CollectionOutline` depth; headings step typography, gain
///          collapse chevrons — view state only — and the section context menu with
///          rename / indent / outdent / delete-heading vs delete-section); dragging a
///          heading moves its whole section as one block via the shared
///          `CollectionOutline.applyingMove` engine; the fixed header gains compact
///          subtitle/author fields and a Front Matter disclosure (introduction rich text
///          + colophon toggle) joins Composition inside the scrolling list (respecting
///          the no-fixed-header-growth constraint), all live-autosaved
///   1.10 — Authoring Phase 4 review fix: `finishOutlineMutation` reindexes `sortOrder`
///          BEFORE `CollectionOutline.normalize` (matching iOS) — normalize linearizes
///          by `sortOrder`, so the previous order made the post-move normalization pass
///          a silent no-op and let orphan heading levels persist
///   1.11 — Authoring Phase 5 (excerpts): the structural add menu gains "Add Highlighted
///          Passages…" (`CollectionAddHighlightsSheet`); `.excerpt` entries render as
///          `CollectionExcerptRow` (inline trash; movable like prose); `MacEntryRow`'s
///          inspector gains the per-highlight "Insert as Excerpt" callback
///   1.12 — Authoring Phase 6 (generated apparatus): the structural add menu gains an
///          "Apparatus" submenu listing the five `CollectionGeneratedBlockType`s;
///          insertion honors the type's default position hint (front matter → before
///          the first entry, back matter → the end — fully movable afterwards);
///          `.generated` entries render as `CollectionGeneratedEntryRow` (inline trash;
///          movable like prose; no body-depth or inspector controls)
struct MacCollectionManagerView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]

    @State private var selectedId: UUID? = nil
    @State private var showNewCollection = false
    /// Drives the `.fruscollection` file importer.
    @State private var isImporting = false
    /// Non-nil to present an import-failure alert.
    @State private var importError: String? = nil
    /// Non-nil to present a smart-collection snapshot-failure alert.
    @State private var snapshotError: String? = nil

    private var filteredCollections: [Collection] {
        guard let pid = appState.activeProjectId else { return allCollections }
        return allCollections.filter { $0.projectIds.contains(pid) }
    }

    private var selectedCollection: Collection? {
        allCollections.first { $0.id == selectedId }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            if let c = selectedCollection {
                CollectionDetailPane(collection: c, allNotes: allNotes, allTags: allTags)
                    .id(c.id)
            } else {
                ContentUnavailableView {
                    Label("No Collection Selected", systemImage: "folder.badge.person.crop")
                } description: {
                    Text("Select a collection from the sidebar, or create a new one.")
                } actions: {
                    Button("New Collection") { showNewCollection = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showNewCollection) {
            NewCollectionSheet { id in selectedId = id }
                .environment(appState)
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.fruscollection],
                      allowsMultipleSelection: false) { result in
            importCollection(from: result)
        }
        .alert(String(localized: "collections.import.error.title",
                      defaultValue: "Couldn’t Import Collection"),
               isPresented: Binding(get: { importError != nil },
                                    set: { if !$0 { importError = nil } })) {
            Button(String(localized: "collections.import.error.ok", defaultValue: "OK"),
                   role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert(String(localized: "collection.snapshot.error.title",
                      defaultValue: "Couldn’t Create Snapshot"),
               isPresented: Binding(get: { snapshotError != nil },
                                    set: { if !$0 { snapshotError = nil } })) {
            Button(String(localized: "collections.import.error.ok", defaultValue: "OK"),
                   role: .cancel) { snapshotError = nil }
        } message: {
            Text(snapshotError ?? "")
        }
        // Select a collection handed off from another surface — today the open-with
        // `.fruscollection` import in FRUSExplorerApp, which sets the hand-off right
        // before opening this window. `.task` consumes a hand-off already pending when
        // the window is freshly created by that `openWindow(id:)`; `.onChange` consumes
        // one arriving while the window is already open. Consume-and-clear, mirroring
        // the `pendingSearch` pattern, so each hand-off fires once.
        .task { consumePendingCollectionSelection() }
        .onChange(of: appState.pendingCollectionSelection) { _, id in
            if id != nil { consumePendingCollectionSelection() }
        }
    }

    /// Applies a `pendingCollectionSelection` hand-off to the sidebar selection, then
    /// clears it so it fires once.
    private func consumePendingCollectionSelection() {
        guard let id = appState.pendingCollectionSelection else { return }
        appState.pendingCollectionSelection = nil
        selectedId = id
    }

    /// Resolves a smart collection's saved search now and materializes the results into a new
    /// static collection (D8), then selects it. Non-destructive: the smart collection is untouched.
    private func snapshotSmartCollection(_ collection: Collection) async {
        guard let searchId = collection.savedSearchId else { return }
        guard let searchService = appState.searchService else {
            snapshotError = String(localized: "export.smart.noSearchService",
                                   defaultValue: "Search service unavailable. Please try again.")
            return
        }
        let descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == searchId })
        guard let savedSearch = try? modelContext.fetch(descriptor).first else {
            snapshotError = String(localized: "export.smart.missingSearch",
                                   defaultValue: "The linked saved search could not be found. It may have been deleted.")
            return
        }
        do {
            let results = try await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: SearchViewModel.searchHardLimit)
            let refs = results.map { (documentId: $0.documentId, volumeId: $0.volumeId) }
            let snapshot = SmartCollectionSnapshot.create(from: collection, results: refs, into: modelContext)
            if let pid = appState.activeProjectId, !snapshot.projectIds.contains(pid) {
                snapshot.projectIds.append(pid)
            }
            try modelContext.save()
            selectedId = snapshot.id
        } catch {
            snapshotError = error.localizedDescription
        }
    }

    /// Imports a user-picked `.fruscollection` file, then selects the reconstructed collection.
    private func importCollection(from result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let imported = try NativeCollectionSerializer.importCollection(from: url, into: modelContext)
                // Scope the import to the active project (as new collections are) so it isn't
                // hidden by the sidebar's active-project filter; imported files carry no projectIds.
                if let pid = appState.activeProjectId { imported.projectIds = [pid] }
                try modelContext.save()
                selectedId = imported.id
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedId) {
            ForEach(filteredCollections) { c in
                CollectionSidebarRow(collection: c)
                    .tag(c.id)
                    .contextMenu {
                        Button {
                            appState.pendingWordCloud = .collection(id: c.id)
                        } label: {
                            Label { Text(String(localized: "collection.wordCloud", defaultValue: "Word Cloud")) }
                                icon: { Image(systemName: WordCloudGlyph.symbol) }
                        }
                        if c.savedSearchId != nil {
                            Button {
                                Task { await snapshotSmartCollection(c) }
                            } label: {
                                Label(String(localized: "collection.snapshot.action",
                                             defaultValue: "Create Static Snapshot"),
                                      systemImage: "camera")
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            if selectedId == c.id { selectedId = nil }
                            for entry in c.documentEntries ?? [] { modelContext.delete(entry) }
                            modelContext.delete(c)
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewCollection = true } label: {
                    Label("New Collection", systemImage: "plus")
                }
                .help("Create a new collection")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isImporting = true } label: {
                    Label(String(localized: "collections.toolbar.import",
                                 defaultValue: "Import Collection…"),
                          systemImage: "square.and.arrow.down")
                }
                .help(String(localized: "collections.toolbar.import.help",
                             defaultValue: "Import a shared .fruscollection file"))
            }
        }
    }
}

// MARK: - CollectionSidebarRow

private struct CollectionSidebarRow: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(collection.name.isEmpty ? "Untitled Collection" : collection.name)
                .font(.body)
            let count = collection.documentEntries?.count ?? 0
            Text("\(count) document\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - NewCollectionSheet

private struct NewCollectionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onCreated: (UUID) -> Void

    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Collection").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                Section("Name") {
                    TextField("Collection Name", text: $name)
                        .onSubmit { createAndDismiss() }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 360, minHeight: 150)
    }

    private func createAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let c = Collection(name: trimmed)
        if let pid = appState.activeProjectId { c.projectIds = [pid] }
        modelContext.insert(c)
        try? modelContext.save()
        onCreated(c.id)
        dismiss()
    }
}

// MARK: - CollectionDetailPane

/// Detail pane that lets the user edit a single selected collection.
private struct CollectionDetailPane: View {

    let collection: Collection
    let allNotes: [ResearchNote]
    let allTags: [UserTag]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// Projects, for the author-line placeholder (the active project's name is offered
    /// as a suggestion only — never persisted automatically).
    @Query(sort: \Project.name) private var allProjects: [Project]

    @State private var name: String
    @State private var note: String
    @State private var sortedEntries: [CollectionEntry]
    /// Front matter (Authoring Phase 4): title-page subtitle, live-autosaved like name.
    @State private var subtitle: String
    /// Front matter: title-page author line (placeholder = active Project name).
    @State private var authorLine: String
    /// Front matter: whether exports end with the colophon (default off).
    @State private var includeColophon: Bool
    /// Headings whose sections are collapsed in the outline — VIEW STATE only (Phase 4):
    /// never persisted, never synced; keyed by entry id so it survives moves.
    @State private var collapsedHeadingIds: Set<UUID> = []
    @State private var showAddDocuments = false
    /// Presents the bulk "Add Highlighted Passages" sheet (Authoring Phase 5).
    @State private var showAddHighlights = false
    @State private var showExport = false
    /// Expansion state of the inline Composition disclosure at the top of the entries list.
    @State private var showComposition = false
    /// Expansion state of the inline Front Matter disclosure (introduction + colophon) —
    /// inside the scrolling list, like Composition, so expansion never grows the fixed header.
    @State private var showFrontMatter = false
    /// Live preview pane visibility (Authoring Phase 2b; toolbar-toggled, not persisted).
    @State private var showPreview = false
    /// The preview's "Render All" cap lift, hoisted here so hiding/showing the pane
    /// doesn't reset it (one detail-pane session = one lift).
    @State private var previewRenderAll = false
    @State private var noteCreateContext: NoteCreateContext? = nil
    /// Document headers loaded asynchronously from `document_cache`.
    /// Keyed by `"volumeId/documentId"`.
    @State private var documentHeaders: [String: String] = [:]
    /// Per-document ISO-8601 dates loaded from `document_dates` for chronological sorting.
    /// Keyed by `"volumeId/documentId"`. Documents without a parseable date are absent.
    @State private var documentDates: [String: String] = [:]

    private struct NoteCreateContext: Identifiable {
        let id = UUID()
        let documentId: String
        let volumeId: String
        let entryIndex: Int
    }

    init(collection: Collection, allNotes: [ResearchNote], allTags: [UserTag]) {
        self.collection = collection
        self.allNotes = allNotes
        self.allTags = allTags
        _name = State(initialValue: collection.name)
        _note = State(initialValue: collection.note ?? "")
        _subtitle = State(initialValue: collection.subtitle ?? "")
        _authorLine = State(initialValue: collection.authorLine ?? "")
        _includeColophon = State(initialValue: collection.includeColophon)
        _sortedEntries = State(initialValue:
            (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder })
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            editorColumn
                .frame(maxWidth: .infinity)

            // Live preview pane (Authoring Phase 2b) — side-by-side, toolbar-toggled.
            if showPreview {
                Divider()
                CollectionPreviewView(collection: collection,
                                      entries: sortedEntries,
                                      allNotes: allNotes,
                                      renderAll: $previewRenderAll)
                    .frame(minWidth: 360, maxWidth: .infinity)
            }
        }
        .navigationTitle(name.isEmpty ? "Untitled Collection" : name)
        .toolbar { toolbarContent }
        .onChange(of: name) { _, _ in saveMetadata() }
        .onChange(of: note) { _, _ in saveMetadata() }
        .onChange(of: subtitle) { _, _ in saveMetadata() }
        .onChange(of: authorLine) { _, _ in saveMetadata() }
        .onChange(of: includeColophon) { _, _ in saveMetadata() }
        // Reload document headers and per-document dates whenever the entry list changes.
        .task(id: sortedEntries.map(\.id)) {
            (documentHeaders, documentDates) =
                await CollectionEntryData.load(for: sortedEntries, appState: appState)
        }
        .sheet(isPresented: $showAddDocuments) {
            CollectionAddDocumentsSheet(
                allTags: allTags,
                allNotes: allNotes,
                existingDocumentKeys: existingDocumentKeys
            ) { picks in
                appendEntries(picks.map { (documentId: $0.documentId, volumeId: $0.volumeId) })
            }
            .environment(appState)
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
        .sheet(item: $noteCreateContext) { ctx in
            InlineNoteCreateSheet(
                documentId: ctx.documentId,
                volumeId: ctx.volumeId,
                activeProjectId: appState.activeProjectId
            ) { newNote in
                // Associate new note with the entry
                if ctx.entryIndex < sortedEntries.count {
                    sortedEntries[ctx.entryIndex].researchNoteId = newNote.id
                }
            }
            .environment(appState)
        }
    }

    /// The editing column (name, note, entries list) — the pre-Phase-2b pane body,
    /// hoisted so the live preview can sit beside it.
    private var editorColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed-height header: name field + collection note.
            // Padded on all sides except the bottom (the divider provides separation).
            VStack(alignment: .leading, spacing: 0) {
                nameSection
                Divider().padding(.vertical, 16)
                noteSection
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 16)

            // Document list fills the rest of the available window height.
            documentsSection
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField("Collection Name", text: $name)
                .font(.title3.bold())
                .textFieldStyle(.plain)
            // Front matter (Phase 4), compactly: one fixed-height row of subtitle +
            // author-line fields — the header must never grow with content.
            HStack(spacing: 12) {
                TextField(String(localized: "collection.frontmatter.subtitle.placeholder",
                                 defaultValue: "Subtitle (title page)"),
                          text: $subtitle)
                    .textFieldStyle(.plain)
                    .font(.callout)
                TextField(authorPlaceholder, text: $authorLine)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(maxWidth: 220)
            }
            .foregroundStyle(.secondary)
        }
    }

    /// The active project's name as the author-line placeholder (suggestion only —
    /// never written to the model unless the user types it).
    private var authorPlaceholder: String {
        if let pid = appState.activeProjectId,
           let project = allProjects.first(where: { $0.id == pid }),
           !project.name.isEmpty {
            return project.name
        }
        return String(localized: "collection.frontmatter.author.placeholder",
                      defaultValue: "Author")
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Collection Note")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 200)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Optional note about this collection…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Documents

    @ViewBuilder
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header with inline sort control
            HStack(spacing: 8) {
                Text(String(localized: "collection.section.documents",
                            defaultValue: "Documents"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    sortByDate()
                } label: {
                    Label(String(localized: "collection.sort.date",
                                 defaultValue: "Sort by Date"),
                          systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(sortedEntries.isEmpty ? .tertiary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(sortedEntries.isEmpty)
                .help(String(localized: "collection.sort.date.help",
                             defaultValue: "Re-order documents chronologically by volume date"))

                Menu {
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
                    // Apparatus (Authoring Phase 6): placeable generated blocks —
                    // inserted at the type's default position, movable afterwards.
                    Menu {
                        ForEach(CollectionGeneratedBlockType.allCases) { blockType in
                            Button {
                                addGeneratedEntry(type: blockType)
                            } label: {
                                Label(blockType.displayName, systemImage: blockType.systemImage)
                            }
                        }
                    } label: {
                        Label(String(localized: "collection.add.apparatus",
                                     defaultValue: "Apparatus"),
                              systemImage: "list.bullet.rectangle")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.add.structural",
                             defaultValue: "Add a section heading, a note block, highlighted passages, or an apparatus block"))
            }

            List {
                // Composition — inline (Authoring Phase 1 shell), inside the scrolling
                // list rather than the fixed header, so an expanded group can never grow
                // the header past the window (the constraint that previously forced a
                // popover — Session 2026-07-01 layout fix).
                Section {
                    DisclosureGroup(isExpanded: $showComposition) {
                        CollectionCompositionRows(collection: collection)
                    } label: {
                        Label(String(localized: "composition.header", defaultValue: "Composition"),
                              systemImage: "slider.horizontal.3")
                            .font(.callout)
                    }
                }

                // Front matter (Phase 4) — the introduction editor and colophon toggle,
                // inside the scrolling list like Composition so expansion never grows
                // the fixed header (subtitle/author live compactly in the header above).
                Section {
                    DisclosureGroup(isExpanded: $showFrontMatter) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "collection.frontmatter.introduction.label",
                                        defaultValue: "Introduction"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            RichTextEditor(initialRTF: collection.introductionRichText,
                                           plainFallback: collection.introductionText ?? "") { rtf, plain in
                                saveIntroduction(rtf: rtf, plain: plain)
                            }
                            .frame(minHeight: 80, maxHeight: 220)
                        }
                        Toggle(isOn: $includeColophon) {
                            Text(String(localized: "collection.frontmatter.colophon.toggle",
                                        defaultValue: "Include colophon"))
                        }
                        .toggleStyle(.checkbox)
                    } label: {
                        Label(String(localized: "collection.frontmatter.disclosure",
                                     defaultValue: "Front Matter"),
                              systemImage: "text.book.closed")
                            .font(.callout)
                    }
                }

                if sortedEntries.isEmpty {
                    Text(String(localized: "collection.documents.empty",
                                defaultValue: "No documents yet. Use Add Documents in the toolbar to add documents."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    let duplicateKeys = duplicateDocumentKeys
                    let outline = CollectionOutline.linearize(sortedEntries)
                    let rows = CollectionOutline.visibleRows(
                        in: outline, collapsedHeadingIds: collapsedHeadingIds)
                    ForEach(rows) { row in
                        outlineRow(row, outline: outline, duplicateKeys: duplicateKeys)
                            .padding(.leading, outlineIndent(for: row))
                    }
                    .onMove { from, to in
                        moveVisibleRows(from, to: to, visible: rows.map(\.index))
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 200, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Outline rows (Authoring Phase 4)

    /// Builds the view for one visible outline row (see the iOS editor's counterpart).
    /// Bindings index into `sortedEntries`, kept in `sortOrder` order (reindexed 0..n
    /// after every mutation), so positions align with the linearized outline.
    @ViewBuilder
    private func outlineRow(_ row: CollectionOutline.VisibleRow,
                            outline: [CollectionOutline.OutlineItem],
                            duplicateKeys: Set<String>) -> some View {
        let entry = sortedEntries[row.index]
        switch entry.entryKind {
        case .document:
            let nodeKey = "\(entry.volumeId)/\(entry.documentId)"
            MacEntryRow(
                entry: $sortedEntries[row.index],
                availableNotes: notes(for: entry),
                volumeTitle: volumeTitle(for: entry),
                documentHeader: documentHeaders[nodeKey],
                isDuplicate: duplicateKeys.contains(nodeKey),
                onInsertExcerpt: { capture in appendExcerpts([capture]) },
                onNewNote: {
                    noteCreateContext = NoteCreateContext(
                        documentId: entry.documentId,
                        volumeId: entry.volumeId,
                        entryIndex: row.index)
                },
                onDelete: { deleteEntry(at: row.index) }
            )
        case .heading:
            let range = CollectionOutline.sectionRange(of: row.index, in: outline)
            CollectionHeadingRow(
                entry: $sortedEntries[row.index],
                onDelete: { deleteEntry(at: row.index) },
                showsInlineDelete: true,
                depth: row.depth,
                isCollapsed: collapsedHeadingIds.contains(row.id),
                sectionEntryCount: range.count - 1,
                onToggleCollapse: { toggleCollapse(row.id) },
                canIndent: CollectionOutline.canIndent(row.index, in: outline),
                canOutdent: CollectionOutline.canOutdent(row.index, in: outline),
                onIndent: { indentSection(at: row.index) },
                onOutdent: { outdentSection(at: row.index) },
                onDeleteSection: { deleteSection(at: row.index) }
            )
        case .prose:
            CollectionProseRow(entry: $sortedEntries[row.index],
                               onDelete: { deleteEntry(at: row.index) })
        case .excerpt:
            CollectionExcerptRow(entry: entry,
                                 volumeTitle: volumeTitle(for: entry),
                                 onDelete: { deleteEntry(at: row.index) })
        case .generated:
            CollectionGeneratedEntryRow(entry: entry,
                                        onDelete: { deleteEntry(at: row.index) })
        case .unrecognized:
            UnrecognizedEntryRow()
        }
    }

    /// Leading indentation for a row: headings indent by their depth above level 1;
    /// body rows indent one step inside their owning section.
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
    /// alone; a section dropped into its own range is refused.
    private func moveVisibleRows(_ indices: IndexSet, to newOffset: Int, visible: [Int]) {
        guard let firstVisible = indices.min(), visible.indices.contains(firstVisible) else { return }
        let from = visible[firstVisible]
        let to = newOffset >= visible.count ? sortedEntries.count : visible[newOffset]
        guard let reordered = CollectionOutline.applyingMove(
            sortedEntries, fromIndex: from, toOffset: to) else { return }
        sortedEntries = reordered
        finishOutlineMutation()
    }

    /// Deletes a single entry (a document/prose row's inline trash, or a heading's
    /// "Delete Heading Only" — its contents stay and sub-headings bubble up).
    private func deleteEntry(at index: Int) {
        guard sortedEntries.indices.contains(index) else { return }
        collapsedHeadingIds.remove(sortedEntries[index].id)
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

    /// The shared tail of every outline mutation: reindex `sortOrder` 0..n, normalize
    /// heading levels (no orphan jumps persist), and save — in that order, matching the
    /// iOS editor (`CollectionEditorView.finishOutlineMutation`). Reindexing must come
    /// FIRST: `CollectionOutline.normalize` linearizes by `sortOrder`, so running it
    /// against stale pre-mutation orders would reconstruct the old arrangement and
    /// silently no-op, persisting orphan levels.
    private func finishOutlineMutation() {
        for (i, entry) in sortedEntries.enumerated() { entry.sortOrder = i }
        CollectionOutline.normalize(sortedEntries)
        try? modelContext.save()
    }

    /// Writes the introduction onto the model, live. An effectively empty introduction
    /// stores `nil` in both fields, so exports omit the block entirely.
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showAddDocuments = true
            } label: {
                Label(String(localized: "collection.toolbar.addDocuments",
                             defaultValue: "Add Documents…"),
                      systemImage: "plus.rectangle.on.folder")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .help(String(localized: "collection.toolbar.addDocuments.help",
                         defaultValue: "Add documents to this collection (⇧⌘A) — search the index, browse volumes, paste citations or history.state.gov links, or gather a tag"))

            Divider()

            Button {
                showPreview.toggle()
            } label: {
                Label(String(localized: "collection.toolbar.preview",
                             defaultValue: "Preview"),
                      systemImage: showPreview ? "eye.fill" : "eye")
            }
            .help(String(localized: "collection.toolbar.preview.help",
                         defaultValue: "Show a live preview of this collection as it will export — updates as you edit"))

            Button {
                showExport = true
            } label: {
                Label(String(localized: "collection.toolbar.export",
                             defaultValue: "Export…"),
                      systemImage: "square.and.arrow.up")
            }
            .help(String(localized: "collection.toolbar.export.help",
                         defaultValue: "Export this collection as a PDF, HTML page, or Word document — includes document text and any attached research notes"))
            // A smart collection (savedSearchId set) has no static entries — its
            // documents are resolved from the linked saved search at export time —
            // so allow export when it is smart even though sortedEntries is empty.
            .disabled(sortedEntries.isEmpty && collection.savedSearchId == nil)
        }
    }

    // MARK: - Helpers

    private func notes(for entry: CollectionEntry) -> [ResearchNote] {
        allNotes.filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }
    }

    private func volumeTitle(for entry: CollectionEntry) -> String {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return manifest.first(where: { $0.volumeId == entry.volumeId })?.title ?? entry.volumeId
    }

    private func reindexEntries() {
        for (i, entry) in sortedEntries.enumerated() { entry.sortOrder = i }
        // Persist the new sort orders immediately so they survive the next render cycle.
        try? modelContext.save()
    }

    /// Appends a structural entry (a section heading or a prose block) to the collection.
    /// Heading/prose entries carry empty document identifiers and use `text` (Phase 3a).
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

    /// Appends document entries at the end of the entry list in the given order.
    /// Duplicates are allowed (A4) — repeats get an "Also in collection" badge instead
    /// of being silently skipped.
    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) {
        CollectionDocumentDiscovery.appendEntries(
            pairs, collection: collection,
            sortedEntries: &sortedEntries, modelContext: modelContext)
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
    /// `appendEntries`.
    private func appendExcerpts(_ captures: [CollectionExcerptCapture]) {
        CollectionExcerpts.append(captures, to: collection,
                                  sortedEntries: &sortedEntries, modelContext: modelContext)
        try? modelContext.save()
    }

    /// Sorts `sortedEntries` in ascending chronological order, then persists the new
    /// `sortOrder` values to SwiftData.
    ///
    /// **Sort key hierarchy (most precise wins):**
    /// 1. Per-document `date_iso` from `document_dates` (loaded asynchronously at pane entry).
    ///    This gives individual-document precision within a volume — e.g. memoranda from
    ///    the same subseries sort correctly relative to each other.
    /// 2. Volume `dateRange.earliest` from the manifest. Used when a document isn't indexed
    ///    or genuinely lacks a date, so all documents from a later volume still sort after
    ///    those from an earlier volume.
    /// 3. `"9999"` sentinel — documents with no date information sort to the end.
    private func sortByDate() {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        sortedEntries = CollectionEntryData.sortedByDate(
            sortedEntries, documentDates: documentDates, manifest: manifest)
        reindexEntries()
    }

    private func saveMetadata() {
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.note = trimmed.isEmpty ? nil : trimmed
        // Front matter (Phase 4): empty fields store nil so untouched collections keep
        // exporting byte-identically to pre-Phase-4 output.
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
        let trimmedAuthor = authorLine.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.authorLine = trimmedAuthor.isEmpty ? nil : trimmedAuthor
        collection.includeColophon = includeColophon
    }
}

// MARK: - MacEntryRow

/// A single row in the collection's document list.
///
/// Displays document number, header (loaded from `document_cache`), volume title,
/// and note previews. Provides:
/// - A multi-note picker backed by `CollectionEntry.selectedNoteIds`
/// - A delete button that removes this entry from the collection
/// - An external-link button to open the document on history.state.gov
private struct MacEntryRow: View {

    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]
    let volumeTitle: String
    /// Document header fetched from `document_cache` by `CollectionDetailPane`.
    let documentHeader: String?
    /// Whether this document appears on more than one entry of the collection — shows
    /// the subtle "Also in collection" badge (A4, duplicates allowed).
    var isDuplicate: Bool = false
    /// Appends an excerpt entry to the owning collection (Authoring Phase 5) — threads
    /// the pane's append action into the inspector's "Insert as Excerpt" rows.
    var onInsertExcerpt: ((CollectionExcerptCapture) -> Void)? = nil
    let onNewNote: () -> Void
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(AppState.self) private var appState
    @State private var showInspector = false

    /// This entry's body-depth override (`nil` = follow the collection default).
    private var bodyDepthOverride: Binding<String?> {
        Binding(get: { entry.bodyDepthOverride }, set: { entry.bodyDepthOverride = $0 })
    }

    /// Depths offered here: those available on this device, plus the entry's current override
    /// even when it isn't otherwise offered (a synced `.summaryOnly` on an AI-less device).
    private var entryDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        if let raw = entry.bodyDepthOverride, let d = CollectionBodyDepth(rawValue: raw),
           !available.contains(d) {
            return available + [d]
        }
        return available
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Document info column
            VStack(alignment: .leading, spacing: 2) {
                Text(documentLabel)
                    .font(.body)

                if let header = documentHeader, !header.isEmpty {
                    Text(header)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Duplicate marker (A4): the same document appears on another entry.
                if isDuplicate {
                    Label(String(localized: "collection.entry.duplicate",
                                 defaultValue: "Also in collection"),
                          systemImage: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Per-entry body depth (overrides the collection default for this document)
                Picker(selection: bodyDepthOverride) {
                    Text(String(localized: "collection.entry.bodyDepth.default",
                                defaultValue: "Default")).tag(String?.none)
                    ForEach(entryDepthOptions) { Text($0.displayName).tag(String?.some($0.rawValue)) }
                } label: {
                    Text(String(localized: "collection.entry.bodyDepth.label",
                                defaultValue: "Body depth"))
                }
                .pickerStyle(.menu)
                .font(.caption)
                .fixedSize()
                .padding(.top, 2)

                // Note preview(s)
                let effective = effectiveNoteIds
                if !effective.isEmpty {
                    let attached = effective.compactMap { id in
                        availableNotes.first(where: { $0.id == id })
                    }
                    if attached.count == 1, let n = attached.first, !n.bodyText.isEmpty {
                        Text(n.bodyText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if attached.count > 1 {
                        Text(String(
                            format: String(localized: "collection.entry.noteCount %lld",
                                           defaultValue: "%lld notes attached"),
                            Int64(attached.count)
                        ))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Action controls
            HStack(spacing: 6) {
                // Document details inspector
                Button {
                    showInspector = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.entry.inspect.help",
                             defaultValue: "Show this document's notes, highlights, tags, and provenance"))

                // Open on history.state.gov
                Button {
                    if let url = URL(string:
                        "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
                    ) {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.entry.openExternal.help",
                             defaultValue: "Open this document on history.state.gov"))

                // Multi-note picker
                noteMenu

                // Delete from collection
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help(String(localized: "collection.entry.delete.help",
                             defaultValue: "Remove this document from the collection"))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showInspector) {
            CollectionEntryInspector(entry: entry, onInsertExcerpt: onInsertExcerpt)
                .environment(appState)
        }
    }

    // MARK: - Note Menu

    /// The effective set of attached note IDs.
    ///
    /// Uses `selectedNoteIds` when non-empty (new multi-note path); otherwise falls back
    /// to `researchNoteId` (legacy single-note path) for backward compatibility.
    private var effectiveNoteIds: [UUID] {
        if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds }
        if let id = entry.researchNoteId  { return [id] }
        return []
    }

    private var noteMenu: some View {
        Menu {
            // Clear all
            Button {
                entry.selectedNoteIds = []
                entry.researchNoteId  = nil
            } label: {
                Label(
                    String(localized: "collection.entry.noteMenu.clearAll",
                           defaultValue: "No Notes"),
                    systemImage: effectiveNoteIds.isEmpty ? "checkmark" : ""
                )
            }

            if !availableNotes.isEmpty {
                Divider()
                ForEach(availableNotes) { note in
                    Button {
                        toggleNote(note.id)
                    } label: {
                        Label(
                            noteLabel(note),
                            systemImage: effectiveNoteIds.contains(note.id) ? "checkmark" : ""
                        )
                    }
                }
            }

            Divider()

            Button {
                onNewNote()
            } label: {
                Label(
                    String(localized: "collection.entry.noteMenu.newNote",
                           defaultValue: "New Note…"),
                    systemImage: "plus"
                )
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.caption)
                Text(noteMenuLabel)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(effectiveNoteIds.isEmpty ? .secondary : .primary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(String(
            localized: "collection.entry.noteMenu.help",
            defaultValue: "Attach one or more research notes to this entry for inclusion in exports"
        ))
    }

    // MARK: - Helpers

    /// Toggles a note in/out of `selectedNoteIds`, migrating from `researchNoteId` if needed.
    private func toggleNote(_ id: UUID) {
        // Migrate legacy single-note to selectedNoteIds on first multi-note interaction.
        var current = entry.selectedNoteIds
        if current.isEmpty, let legacy = entry.researchNoteId {
            current = [legacy]
        }
        if let idx = current.firstIndex(of: id) {
            current.remove(at: idx)
        } else {
            current.append(id)
        }
        entry.selectedNoteIds = current
        // Keep researchNoteId in sync with the first selected note for export backward compat.
        entry.researchNoteId = current.first
    }

    private var documentLabel: String {
        if entry.documentId.hasPrefix("d"), let n = Int(entry.documentId.dropFirst()) {
            return String(
                format: String(localized: "collection.entry.documentLabel %lld",
                               defaultValue: "Document %lld"),
                Int64(n)
            )
        }
        return entry.documentId
    }

    private var noteMenuLabel: String {
        let ids = effectiveNoteIds
        switch ids.count {
        case 0:
            return String(localized: "collection.entry.noteMenu.noNote",
                          defaultValue: "No Notes")
        case 1:
            if let note = availableNotes.first(where: { $0.id == ids[0] }) {
                return noteLabel(note)
            }
            return String(localized: "collection.entry.noteMenu.noNote",
                          defaultValue: "No Notes")
        default:
            return String(
                format: String(localized: "collection.entry.noteMenu.count %lld",
                               defaultValue: "%lld Notes"),
                Int64(ids.count)
            )
        }
    }

    private func noteLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? String(localized: "collection.entry.noteMenu.untitled",
                                        defaultValue: "Untitled Note")
                               : String(preview)
    }
}

// MARK: - InlineNoteCreateSheet

/// Focused sheet for creating a new `ResearchNote` from within the collection editor.
/// For full note editing (tags, projects, summaries) use `ResearchNoteEditorView` from
/// the document view.
private struct InlineNoteCreateSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let documentId: String
    let volumeId: String
    let activeProjectId: UUID?
    let onCreated: (ResearchNote) -> Void

    @State private var bodyText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Research Note").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            TextEditor(text: $bodyText)
                .font(.body)
                .padding(12)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Note") {
                    let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = ResearchNote(
                        documentId: documentId,
                        volumeId: volumeId,
                        bodyText: trimmed,
                        projectIds: activeProjectId.map { [$0] } ?? []
                    )
                    modelContext.insert(note)
                    try? modelContext.save()   // ensure Research window @Query updates promptly
                    // Push immediately so note text is searchable in this session.
                    if let pipeline = appState.indexingPipeline {
                        let vid = volumeId
                        let did = documentId
                        Task { try? await pipeline.updateNoteText(
                            volumeId: vid, documentId: did,
                            bodyText: trimmed, userTagIds: nil
                        ) }
                    }
                    onCreated(note)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 440, minHeight: 280)
    }
}
#endif
