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

// MARK: - MacCollectionManagerView

/// Root view for the "Collections" window on macOS.
///
/// Presents a `NavigationSplitView`:
///   - **Sidebar** — list of all collections (filtered to active project); supports
///     selection, deletion via context menu, and creating new collections.
///   - **Detail** — inline editor for the selected collection: editable name and note
///     (auto-saved), reorderable document list, per-document note management, and
///     toolbar actions for Add by Tag, Sort by Date, and Export.
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
struct MacCollectionManagerView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Collection.lastModified, order: .reverse) private var allCollections: [Collection]
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]

    @State private var selectedId: UUID? = nil
    @State private var showNewCollection = false

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
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedId) {
            ForEach(filteredCollections) { c in
                CollectionSidebarRow(collection: c)
                    .tag(c.id)
                    .contextMenu {
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

    @State private var name: String
    @State private var note: String
    @State private var sortedEntries: [CollectionEntry]
    @State private var showAddByTag = false
    @State private var showExport = false
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
        _sortedEntries = State(initialValue:
            (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder })
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed-height header: name field + collection note.
            // Padded on all sides except the bottom (the divider provides separation).
            VStack(alignment: .leading, spacing: 0) {
                nameSection
                Divider().padding(.vertical, 16)
                noteSection
                Divider().padding(.vertical, 16)
            }
            .padding([.horizontal, .top], 24)

            // Document list fills the rest of the available window height.
            documentsSection
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .navigationTitle(name.isEmpty ? "Untitled Collection" : name)
        .toolbar { toolbarContent }
        .onChange(of: name) { _, _ in saveMetadata() }
        .onChange(of: note) { _, _ in saveMetadata() }
        // Reload document headers and per-document dates whenever the entry list changes.
        .task(id: sortedEntries.map(\.id)) {
            let keys = sortedEntries.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            if let store = appState.crossReferenceStore,
               let headers = try? await store.documentHeaders(for: keys) {
                documentHeaders = headers
            }
            if let pipeline = appState.indexingPipeline,
               let dates = try? await pipeline.datesByDocumentKey(keys) {
                documentDates = dates
            }
        }
        .sheet(isPresented: $showAddByTag) {
            AddByTagSheet(allTags: allTags, allNotes: allNotes) { newEntries in
                appendEntries(newEntries)
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
        }
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
            }

            if sortedEntries.isEmpty {
                Text(String(localized: "collection.documents.empty",
                            defaultValue: "No documents yet. Use Add by Tag in the toolbar to add documents."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                List {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { idx, entry in
                        let nodeKey = "\(entry.volumeId)/\(entry.documentId)"
                        MacEntryRow(
                            entry: $sortedEntries[idx],
                            availableNotes: notes(for: entry),
                            volumeTitle: volumeTitle(for: entry),
                            documentHeader: documentHeaders[nodeKey],
                            onNewNote: {
                                noteCreateContext = NoteCreateContext(
                                    documentId: entry.documentId,
                                    volumeId: entry.volumeId,
                                    entryIndex: idx)
                            },
                            onDelete: {
                                modelContext.delete(sortedEntries[idx])
                                sortedEntries.remove(at: idx)
                                reindexEntries()
                            }
                        )
                    }
                    .onMove { from, to in
                        sortedEntries.move(fromOffsets: from, toOffset: to)
                        reindexEntries()
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showAddByTag = true
            } label: {
                Label(String(localized: "collection.toolbar.addByTag",
                             defaultValue: "Add by Tag"),
                      systemImage: "tag")
            }
            .help(String(localized: "collection.toolbar.addByTag.help",
                         defaultValue: "Add documents to this collection by selecting a research note tag — all notes with that tag are added at once"))
            .disabled(allTags.isEmpty)

            Divider()

            Button {
                showExport = true
            } label: {
                Label(String(localized: "collection.toolbar.export",
                             defaultValue: "Export…"),
                      systemImage: "square.and.arrow.up")
            }
            .help(String(localized: "collection.toolbar.export.help",
                         defaultValue: "Export this collection as a PDF, HTML page, or Word document — includes document text and any attached research notes"))
            .disabled(sortedEntries.isEmpty)
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

    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) {
        var next = sortedEntries.count
        for pair in pairs {
            guard !sortedEntries.contains(where: {
                $0.documentId == pair.documentId && $0.volumeId == pair.volumeId
            }) else { continue }
            let entry = CollectionEntry(
                collectionId: collection.id,
                documentId: pair.documentId,
                volumeId: pair.volumeId,
                sortOrder: next
            )
            entry.collection = collection
            modelContext.insert(entry)
            sortedEntries.append(entry)
            next += 1
        }
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
        // Volume-level dates as a fallback for documents that lack a date_iso row.
        var volumeDateMap: [String: String] = [:]
        for entry in manifest {
            if let d = entry.dateRange.earliest {
                volumeDateMap[entry.volumeId] = d
            }
        }
        sortedEntries.sort { a, b in
            let aKey = "\(a.volumeId)/\(a.documentId)"
            let bKey = "\(b.volumeId)/\(b.documentId)"
            let aDate = documentDates[aKey]
                     ?? volumeDateMap[a.volumeId]
                     ?? "9999"
            let bDate = documentDates[bKey]
                     ?? volumeDateMap[b.volumeId]
                     ?? "9999"
            return aDate < bDate
        }
        reindexEntries()
    }

    private func saveMetadata() {
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.note = trimmed.isEmpty ? nil : trimmed
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
    let onNewNote: () -> Void
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL

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
