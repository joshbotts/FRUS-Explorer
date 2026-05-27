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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                nameSection
                Divider().padding(.vertical, 16)
                noteSection
                Divider().padding(.vertical, 16)
                documentsSection
            }
            .padding(24)
        }
        .navigationTitle(name.isEmpty ? "Untitled Collection" : name)
        .toolbar { toolbarContent }
        .onChange(of: name) { _, _ in saveMetadata() }
        .onChange(of: note) { _, _ in saveMetadata() }
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
            Text("Documents")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if sortedEntries.isEmpty {
                Text("No documents yet. Use Add by Tag in the toolbar to add documents.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                List {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { idx, entry in
                        MacEntryRow(
                            entry: $sortedEntries[idx],
                            availableNotes: notes(for: entry),
                            volumeTitle: volumeTitle(for: entry),
                            onNewNote: {
                                noteCreateContext = NoteCreateContext(
                                    documentId: entry.documentId,
                                    volumeId: entry.volumeId,
                                    entryIndex: idx)
                            }
                        )
                    }
                    .onMove { from, to in
                        sortedEntries.move(fromOffsets: from, toOffset: to)
                        reindexEntries()
                    }
                    .onDelete { idxSet in
                        for i in idxSet { modelContext.delete(sortedEntries[i]) }
                        sortedEntries.remove(atOffsets: idxSet)
                        reindexEntries()
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 200, maxHeight: CGFloat(sortedEntries.count) * 62 + 20)
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
                Label("Add by Tag", systemImage: "tag")
            }
            .help("Add documents by research note tag")
            .disabled(allTags.isEmpty)

            Button { sortByDate() } label: {
                Label("Sort by Date", systemImage: "calendar")
            }
            .help("Sort documents by volume date")
            .disabled(sortedEntries.isEmpty)

            Divider()

            Button {
                showExport = true
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .help("Export collection as PDF, HTML, or DOCX")
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

    private func sortByDate() {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let dateMap = Dictionary(uniqueKeysWithValues: manifest.compactMap { e -> (String, String)? in
            guard let d = e.dateRange.earliest else { return nil }
            return (e.volumeId, d)
        })
        sortedEntries.sort { (dateMap[$0.volumeId] ?? "9999") < (dateMap[$1.volumeId] ?? "9999") }
        reindexEntries()
    }

    private func saveMetadata() {
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.note = trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - MacEntryRow

private struct MacEntryRow: View {

    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]
    let volumeTitle: String
    let onNewNote: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(documentLabel)
                    .font(.body)
                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let id = entry.researchNoteId,
                   let note = availableNotes.first(where: { $0.id == id }),
                   !note.bodyText.isEmpty {
                    Text(note.bodyText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Open on history.state.gov
            Button {
                if let url = URL(string: "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open on history.state.gov")

            // Note picker
            noteMenu
        }
        .padding(.vertical, 4)
    }

    // MARK: - Note Menu

    private var noteMenu: some View {
        Menu {
            Button {
                entry.researchNoteId = nil
            } label: {
                Label("No Note", systemImage: entry.researchNoteId == nil ? "checkmark" : "")
            }

            if !availableNotes.isEmpty {
                Divider()
                ForEach(availableNotes) { note in
                    Button {
                        entry.researchNoteId = note.id
                    } label: {
                        Label(
                            noteLabel(note),
                            systemImage: entry.researchNoteId == note.id ? "checkmark" : ""
                        )
                    }
                }
            }

            Divider()

            Button {
                onNewNote()
            } label: {
                Label("New Note…", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.caption)
                Text(currentNoteLabel)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(entry.researchNoteId != nil ? .primary : .secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(String(
            localized: "collection.entry.noteMenu.help",
            defaultValue: "Attach an existing research note to this entry, clear it, or create a new note"
        ))
    }

    // MARK: - Helpers

    private var documentLabel: String {
        if entry.documentId.hasPrefix("d"), let n = Int(entry.documentId.dropFirst()) {
            return "Document \(n)"
        }
        return entry.documentId
    }

    private var currentNoteLabel: String {
        guard let id = entry.researchNoteId,
              let note = availableNotes.first(where: { $0.id == id }) else {
            return "No Note"
        }
        return noteLabel(note)
    }

    private func noteLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? "Untitled Note" : String(preview)
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
