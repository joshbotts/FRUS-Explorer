// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionEditorView

/// Full editor for a `Collection`: name, optional note, ordered documents, and export.
///
/// ## Layout (Form sections)
/// 1. **Name** — text field for the collection title
/// 2. **Note** — optional free-text note for the whole collection
/// 3. **Documents** — reorderable list of `CollectionEntry` records; each row
///    lets the user pick an associated `ResearchNote` for that document
/// 4. **Add by Tag** — query notes with a chosen `UserTag` and append their
///    documents to the collection
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

    // MARK: - State

    @State private var collection: Collection
    private let isNewCollection: Bool

    @State private var collectionName: String
    @State private var collectionNote: String
    @State private var sortedEntries: [CollectionEntry]
    @State private var linkedSavedSearchId: UUID?

    @State private var showAddByTag       = false
    @State private var showExport         = false
    @State private var showTimeline       = false
    @State private var showLinkSavedSearch = false
    @State private var exportError: String?

    // MARK: - Init

    init(collection: Collection?) {
        if let c = collection {
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: c.name)
            _collectionNote = State(initialValue: c.note ?? "")
            _sortedEntries = State(initialValue:
                (c.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder })
            _linkedSavedSearchId = State(initialValue: c.savedSearchId)
            isNewCollection = false
        } else {
            let c = Collection(name: "")
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: "")
            _collectionNote = State(initialValue: "")
            _sortedEntries = State(initialValue: [])
            _linkedSavedSearchId = State(initialValue: nil)
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
        .sheet(isPresented: $showTimeline) {
            #if os(macOS)
            // macOS: plain content + bottom button bar (no NavigationStack chrome)
            VStack(spacing: 0) {
                DocumentTimelineView(
                    items: sortedEntries.map {
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
                    items: sortedEntries.map {
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
                compositionSection
                smartCollectionSection
                documentsSection
                addByTagSection
                if !sortedEntries.isEmpty || linkedSavedSearchId != nil {
                    actionsSection
                }
            }
            .formStyle(.grouped)

            Divider()

            // Button bar
            HStack {
                Button(String(localized: "collection.editor.cancel", defaultValue: "Cancel")) {
                    if isNewCollection {
                        for entry in sortedEntries { modelContext.delete(entry) }
                        modelContext.delete(collection)
                    }
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "collection.editor.save", defaultValue: "Save")) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 460)
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
        NavigationStack {
            Group {
                #if os(iOS)
                if sizeClass == .regular {
                    iPadCollectionLayout
                } else {
                    iPhoneCollectionForm
                }
                #else
                iPhoneCollectionForm
                #endif
            }
            .navigationTitle(isNewCollection
                ? String(localized: "collection.editor.title.new", defaultValue: "New Collection")
                : String(localized: "collection.editor.title.edit", defaultValue: "Edit Collection"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.editor.cancel", defaultValue: "Cancel")) {
                        if isNewCollection {
                            for entry in sortedEntries { modelContext.delete(entry) }
                            modelContext.delete(collection)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "collection.editor.save", defaultValue: "Save")) {
                        save()
                        dismiss()
                    }
                    .disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    // MARK: - iOS Form Variants

    private var iPhoneCollectionForm: some View {
        Form {
            nameSection
            noteSection
            compositionSection
            smartCollectionSection
            documentsSection
            addByTagSection
            if !sortedEntries.isEmpty || linkedSavedSearchId != nil { actionsSection }
        }
    }

    /// Two-column layout for iPad (`horizontalSizeClass == .regular`).
    /// Left column: document list + add-by-tag. Right column: name, note, smart collection, actions.
    private var iPadCollectionLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                documentsSection
                addByTagSection
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            Form {
                nameSection
                noteSection
                compositionSection
                smartCollectionSection
                if !sortedEntries.isEmpty || linkedSavedSearchId != nil { actionsSection }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Smart Collection Section

    @ViewBuilder
    private var smartCollectionSection: some View {
        Section {
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
        } header: {
            Text(String(localized: "collection.editor.smart.header",
                        defaultValue: "Smart Collection"))
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

    private var nameSection: some View {
        Section(String(localized: "collection.editor.name.header", defaultValue: "Name")) {
            TextField(
                String(localized: "collection.editor.name.placeholder", defaultValue: "Collection Name"),
                text: $collectionName
            )
            .accessibilityLabel(String(localized: "collection.editor.name.accessibility",
                                       defaultValue: "Collection name"))
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Section(String(localized: "collection.editor.note.header", defaultValue: "Note")) {
            TextField(
                String(localized: "collection.editor.note.placeholder",
                       defaultValue: "Optional note about this collection…"),
                text: $collectionNote,
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "collection.editor.note.accessibility",
                                       defaultValue: "Collection note"))
        }
    }

    // MARK: - Composition Section

    /// The persisted export-content settings (body depth, footnotes, notes, highlights, etc.).
    /// These determine *what an export of this collection contains*, independent of format.
    private var compositionSection: some View {
        Section {
            CollectionCompositionRows(collection: collection)
        } header: {
            Text(String(localized: "composition.header", defaultValue: "Composition"))
        } footer: {
            Text(String(localized: "composition.footer",
                        defaultValue: "Determines what an export of this collection contains. Applied to every format."))
        }
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
                                defaultValue: "No documents yet. Add some using a subject tag below."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach($sortedEntries, id: \.id) { $entry in
                    EntryRow(
                        entry: $entry,
                        availableNotes: notes(for: entry)
                    )
                }
                .onMove { indices, newOffset in
                    sortedEntries.move(fromOffsets: indices, toOffset: newOffset)
                    reindexEntries()
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        modelContext.delete(sortedEntries[i])
                    }
                    sortedEntries.remove(atOffsets: indexSet)
                    reindexEntries()
                }
            }
        } header: {
            HStack {
                Text(String(localized: "collection.editor.docs.header", defaultValue: "Documents"))
                Spacer()
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

    // MARK: - Add by Tag Section

    private var addByTagSection: some View {
        Section {
            Button {
                showAddByTag = true
            } label: {
                Label(
                    String(localized: "collection.editor.addByTag.button",
                           defaultValue: "Add Documents by Tag…"),
                    systemImage: "tag"
                )
            }
            .disabled(allTags.isEmpty)
        } footer: {
            if allTags.isEmpty {
                Text(String(localized: "collection.editor.addByTag.noTags",
                            defaultValue: "Create user tags on research notes to use this feature."))
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
                Button {
                    sortByDate()
                } label: {
                    Label(
                        String(localized: "collection.editor.actions.sortByDate",
                               defaultValue: "Sort by Date"),
                        systemImage: "calendar"
                    )
                }
            }

            Button {
                applyEditsForExport()
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

    private func notes(for entry: CollectionEntry) -> [ResearchNote] {
        allNotes.filter {
            $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }
    }

    private func reindexEntries() {
        for (i, entry) in sortedEntries.enumerated() {
            entry.sortOrder = i
        }
    }

    private func appendEntries(_ pairs: [(documentId: String, volumeId: String)]) {
        var next = sortedEntries.count
        for pair in pairs {
            let alreadyPresent = sortedEntries.contains {
                $0.documentId == pair.documentId && $0.volumeId == pair.volumeId
            }
            guard !alreadyPresent else { continue }
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
        let volumeDateMap = Dictionary(uniqueKeysWithValues: manifest.compactMap { entry -> (String, String)? in
            guard let earliest = entry.dateRange.earliest else { return nil }
            return (entry.volumeId, earliest)
        })
        sortedEntries.sort { a, b in
            let aDate = volumeDateMap[a.volumeId] ?? "9999"
            let bDate = volumeDateMap[b.volumeId] ?? "9999"
            return aDate < bDate
        }
        reindexEntries()
    }

    private func save() {
        collection.name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = collectionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.note = trimmedNote.isEmpty ? nil : trimmedNote
        collection.savedSearchId = linkedSavedSearchId
        if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) {
            collection.projectIds.append(projectId)
        }
        try? modelContext.save()
    }

    /// Syncs the editor's pending edits onto the in-memory `collection` so the
    /// export sheet sees the current state without requiring a prior Save.
    ///
    /// The exporter's smart-collection path reads `collection.savedSearchId`, so
    /// that link must be applied before presenting `ExportSheetView` — otherwise
    /// exporting a freshly-linked (but unsaved) smart collection would resolve no
    /// documents. The collection is already in the model context (inserted in
    /// `onAppear` for new collections), and nothing is persisted here, so Cancel
    /// still discards a new collection.
    ///
    /// Name/note are copied only for a brand-new collection, whose Save step
    /// hasn't run yet; for an existing collection they are left untouched so that
    /// exporting after an unsaved field edit doesn't silently leak that edit —
    /// matching the static-entry export behavior, which also exports the
    /// persisted name/note.
    private func applyEditsForExport() {
        collection.savedSearchId = linkedSavedSearchId
        if isNewCollection {
            collection.name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = collectionNote.trimmingCharacters(in: .whitespacesAndNewlines)
            collection.note = trimmedNote.isEmpty ? nil : trimmedNote
        }
    }
}

// MARK: - EntryRow

/// A single row in the documents list that lets the user configure per-entry export options.
///
/// Users can:
/// - Toggle whether the document body is included in the export.
/// - Select zero or more research notes to include alongside the document.
private struct EntryRow: View {
    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Document identity
            Text(entry.documentId)
                .font(.body)
                .accessibilityLabel(
                    String(localized: "collection.entry.document.accessibility",
                           defaultValue: "Document \(entry.documentId)")
                )

            Text(entry.volumeId)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Per-note selection (multi-select)
            if !availableNotes.isEmpty {
                Text(String(localized: "collection.entry.notes.header",
                            defaultValue: "Include notes:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(availableNotes) { note in
                        let isOn = Binding<Bool>(
                            get: {
                                // Prefer selectedNoteIds when non-empty; fall back to researchNoteId.
                                if !entry.selectedNoteIds.isEmpty {
                                    return entry.selectedNoteIds.contains(note.id)
                                }
                                return entry.researchNoteId == note.id
                            },
                            set: { include in
                                // Migrate from legacy single-note to multi-note on first edit.
                                if entry.selectedNoteIds.isEmpty, let legacy = entry.researchNoteId {
                                    entry.selectedNoteIds = [legacy]
                                    entry.researchNoteId = nil
                                }
                                if include {
                                    if !entry.selectedNoteIds.contains(note.id) {
                                        entry.selectedNoteIds.append(note.id)
                                    }
                                } else {
                                    entry.selectedNoteIds.removeAll { $0 == note.id }
                                }
                            }
                        )
                        Toggle(isOn: isOn) {
                            Text(noteLabel(note))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func noteLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? String(localized: "collection.entry.note.emptyPreview",
                                        defaultValue: "Untitled Note") : String(preview)
    }
}

// MARK: - AddByTagSheet

/// Sheet that lets the user pick a `UserTag` then appends all tagged documents.
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders as a split-column
/// layout — the list becomes a collapsed sidebar and the detail area appears blank.
/// The macOS body uses a plain `VStack` with an explicit button bar (the same pattern
/// used by `CollectionEditorView.macBody`) so all controls are always visible.
///
/// Version history:
///   1.0 — Session 88: initial implementation
///   1.1 — Session 129: split macOS / iOS bodies; macOS uses VStack + button-bar
///          pattern to prevent NavigationStack sidebar from hiding list content
struct AddByTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allTags: [UserTag]
    let allNotes: [ResearchNote]
    let onAdd: ([(documentId: String, volumeId: String)]) -> Void

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(String(localized: "collection.addByTag.nav.title",
                            defaultValue: "Add by Tag"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            // Tag list
            List(allTags) { tag in
                Button {
                    let pairs = allNotes
                        .filter { $0.userTagIds.contains(tag.id) }
                        .map { (documentId: $0.documentId, volumeId: $0.volumeId) }
                    onAdd(pairs)
                    dismiss()
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        let count = allNotes.filter { $0.userTagIds.contains(tag.id) }.count
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)

            Divider()

            // Button bar
            HStack {
                Spacer()
                Button(String(localized: "collection.addByTag.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 320, minHeight: 260)
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            List(allTags) { tag in
                Button {
                    let pairs = allNotes
                        .filter { $0.userTagIds.contains(tag.id) }
                        .map { (documentId: $0.documentId, volumeId: $0.volumeId) }
                    onAdd(pairs)
                    dismiss()
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        let count = allNotes.filter { $0.userTagIds.contains(tag.id) }.count
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(String(localized: "collection.addByTag.nav.title",
                                    defaultValue: "Add by Tag"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.addByTag.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ExportSheetView

/// Picker + progress view that runs the chosen exporter and presents a share sheet.
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let collection: Collection
    let entries: [CollectionEntry]
    let allNotes: [ResearchNote]
    let appState: AppState

    @State private var selectedFormat: ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportedURL: URL? = nil
    @State private var exportError: String? = nil
    /// Non-nil while volumes need to be downloaded/indexed before export can proceed.
    @State private var preparingMessage: String? = nil
    /// Non-nil while summaries are being generated on demand.
    @State private var summaryGeneratingMessage: String? = nil
    /// Non-nil after a successful "Send to Zotero Library" run (drives the result alert).
    @State private var zoteroResult: ZoteroSendResult? = nil

    // MARK: - Ephemeral document reference (smart collection path)

    /// Lightweight document reference used for smart-collection resolution.
    /// Avoids creating SwiftData model instances outside a context.
    private struct SmartEntry {
        let documentId: String
        let volumeId: String
        let sortOrder: Int
    }

    var body: some View {
        #if os(macOS)
        macExportBody
        #else
        iOSExportBody
        #endif
    }

    // MARK: - macOS body

    /// macOS-native export dialog.
    ///
    /// Replaces the `NavigationStack { Form }` pattern used on iOS, which adds
    /// an unwanted navigation bar on macOS. Changes from the iOS layout:
    /// - Title row + Divider + content area + Divider + button bar
    /// - Format uses `.pickerStyle(.radioGroup)` — the HIG-correct control for
    ///   2–5 mutually exclusive options in a dialog body (segmented is correct
    ///   for toolbars/control strips, not dialog content areas)
    /// - Contents List uses a `LabeledContent` row with `.pickerStyle(.menu)`
    /// - Progress spinner sits inline in the button bar next to Export
    /// - Error message appears above the button bar, not in a Form section
    /// - Export is the default action (↩) via `.keyboardShortcut(.defaultAction)`
    #if os(macOS)
    private var macExportBody: some View {
        VStack(spacing: 0) {

            // Title
            Text(String(localized: "export.nav.title", defaultValue: "Export Collection"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            // Options
            VStack(alignment: .leading, spacing: 18) {

                // Format — radio buttons (HIG: mutually exclusive choices in a dialog)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.format.header", defaultValue: "Format"))
                        .font(.callout.weight(.medium))
                    Picker(
                        String(localized: "export.format.picker", defaultValue: "Format"),
                        selection: $selectedFormat
                    ) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                // Content composition (body depth, footnotes, notes, highlights, word cloud)
                // now lives in the collection manager's Composition section and is persisted
                // on the collection — this sheet is purely format + destination.
                Text(String(localized: "export.compositionHint",
                            defaultValue: "Body, footnotes, notes, and other content options are set in the collection's Composition section."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Inline error — shown above the button bar when present
            if let error = exportError {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            Divider()

            // Button bar
            HStack(spacing: 12) {
                Button(String(localized: "export.close", defaultValue: "Close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                // Progress feedback — inline in the button bar when busy
                if let msg = preparingMessage ?? summaryGeneratingMessage {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(msg).font(.callout).foregroundStyle(.secondary)
                    }
                } else if isExporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "export.progress.label",
                                    defaultValue: "Exporting…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                zoteroSendButton

                Button {
                    Task { await runExport() }
                } label: {
                    Label(
                        String(localized: "export.button.label", defaultValue: "Export"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isExporting
                          || preparingMessage != nil
                          || (entries.isEmpty && collection.savedSearchId == nil))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 260)
        .sheet(item: $exportedURL) { url in
            MacExportCompleteView(url: url)
        }
        .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
    }
    #endif

    // MARK: - iOS body

    /// iOS/iPadOS export sheet.
    ///
    /// Retains `NavigationStack { Form }` which is the correct pattern on iOS:
    /// the navigation bar provides title and Cancel/Close button placement,
    /// and the Form renders correctly as an inset-grouped table.
    #if os(iOS)
    private var iOSExportBody: some View {
        NavigationStack {
            Form {
                Section(String(localized: "export.format.header", defaultValue: "Format")) {
                    Picker("", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { fmt in Text(fmt.displayName).tag(fmt) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text(String(localized: "export.compositionHint",
                                defaultValue: "Body, footnotes, notes, and other content options are set in the collection's Composition section."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if let msg = preparingMessage ?? summaryGeneratingMessage {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(msg).foregroundStyle(.secondary)
                        }
                    } else if isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 8)
                            Text(String(localized: "export.progress.label",
                                        defaultValue: "Exporting…"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await runExport() }
                        } label: {
                            Label(
                                String(localized: "export.button.label", defaultValue: "Export"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(entries.isEmpty && collection.savedSearchId == nil)
                        zoteroSendButton
                    }
                }

                if let error = exportError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle(String(localized: "export.nav.title", defaultValue: "Export Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "export.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exportedURL) { url in
                ShareSheet(url: url)
                    .ignoresSafeArea()
            }
            .zoteroResultAlert(result: $zoteroResult, message: zoteroResultMessage, openURL: openURL)
        }
    }
    #endif // os(iOS)

    private func runExport() async {
        exportError = nil

        // Smart collection path: resolve documents via the linked SavedSearch.
        if let searchId = collection.savedSearchId {
            isExporting = true
            defer { isExporting = false; summaryGeneratingMessage = nil }

            guard let searchService = appState.searchService else {
                exportError = String(localized: "export.smart.noSearchService",
                                     defaultValue: "Search service unavailable. Please try again.")
                return
            }
            let descriptor = FetchDescriptor<SavedSearch>(
                predicate: #Predicate { $0.id == searchId }
            )
            guard let savedSearch = try? modelContext.fetch(descriptor).first else {
                exportError = String(localized: "export.smart.missingSearch",
                                     defaultValue: "The linked saved search could not be found. It may have been deleted.")
                return
            }
            do {
                // Resolve the full result set (not just the first page) — the default
                // `search` limit is `defaultPageSize` (20), which silently truncated
                // smart-collection exports. Mirror the live saved search's hard limit.
                let results = try await searchService.search(
                    parameters: savedSearch.searchParameters,
                    limit: SearchViewModel.searchHardLimit
                )
                let smartEntries = results.enumerated().map { i, r in
                    SmartEntry(documentId: r.documentId, volumeId: r.volumeId, sortOrder: i)
                }
                var docs = await resolveSmartDocuments(smartEntries)
                let options = buildExportOptions()

                // Resolve AI summaries on demand when exporting at .summaryOnly depth,
                // mirroring the static-collection path below. Without this, a smart
                // collection exported as "Summary only" would carry no summary text
                // even when the user has generated summaries for the saved search.
                if options.bodyDepth == .summaryOnly {
                    guard let promptId = options.summaryPromptId else {
                        exportError = String(localized: "export.summaryNoPrompt",
                                             defaultValue: "Choose a summarization prompt to export as summaries.")
                        return
                    }
                    let bodyTexts = Dictionary(uniqueKeysWithValues:
                        docs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) })
                    let summaries = try await resolveSummaries(for: docs, promptId: promptId,
                                                               bodyTexts: bodyTexts)
                    docs = docs.map { doc in
                        let key = "\(doc.volumeId)/\(doc.documentId)"
                        guard let text = summaries[key] else { return doc }
                        return CollectionExportDocument(
                            documentId: doc.documentId, volumeId: doc.volumeId,
                            sortOrder: doc.sortOrder, title: doc.title, date: doc.date,
                            bodyText: doc.bodyText, noteTexts: doc.noteTexts,
                            citation: doc.citation, historyStateGovURL: doc.historyStateGovURL,
                            renderModel: doc.renderModel, header: doc.header, dateline: doc.dateline,
                            summaryText: text, highlights: doc.highlights,
                            sourceNoteText: doc.sourceNoteText, zoteroItem: doc.zoteroItem
                        )
                    }
                }

                let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
                let exporter = selectedFormat.makeExporter()
                let url = try await exporter.export(metadata: metadata, documents: docs, options: options)
                exportedURL = url
                appState.logEvent(.export(
                    format: selectedFormat.rawValue,
                    documentCount: docs.count
                ))
            } catch {
                exportError = error.localizedDescription
            }
            return
        }

        // Static collection path.
        // Phase 1: ensure every volume referenced by the collection is downloaded and indexed.
        await prepareVolumes()

        // Phase 2: resolve document content.
        isExporting = true
        do {
            var docs = try await resolveDocuments()
            let opts = buildExportOptions()

            // Phase 2b: generate summaries on demand when bodyDepth == .summaryOnly.
            if opts.bodyDepth == .summaryOnly {
                guard let promptId = opts.summaryPromptId else {
                    exportError = String(localized: "export.summaryNoPrompt",
                                        defaultValue: "Choose a summarization prompt to export as summaries.")
                    isExporting = false
                    return
                }
                let bodyTexts = Dictionary(uniqueKeysWithValues:
                    docs.map { ("\($0.volumeId)/\($0.documentId)", $0.bodyText) })
                let summaries = try await resolveSummaries(for: docs, promptId: promptId,
                                                           bodyTexts: bodyTexts)
                docs = docs.map { doc in
                    let key = "\(doc.volumeId)/\(doc.documentId)"
                    guard let text = summaries[key] else { return doc }
                    return CollectionExportDocument(
                        documentId: doc.documentId, volumeId: doc.volumeId,
                        sortOrder: doc.sortOrder, title: doc.title, date: doc.date,
                        bodyText: doc.bodyText, noteTexts: doc.noteTexts,
                        citation: doc.citation, historyStateGovURL: doc.historyStateGovURL,
                        renderModel: doc.renderModel, header: doc.header, dateline: doc.dateline,
                        summaryText: text, highlights: doc.highlights,
                        sourceNoteText: doc.sourceNoteText
                    )
                }
            }

            let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
            let exporter = selectedFormat.makeExporter()
            let url = try await exporter.export(metadata: metadata, documents: docs, options: opts)
            exportedURL = url
            appState.logEvent(.export(
                format: selectedFormat.rawValue,
                documentCount: docs.count
            ))
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
        summaryGeneratingMessage = nil
    }

    /// Assembles `CollectionExportOptions` from the collection's persisted composition
    /// (edited in the manager's Composition section) plus the format-dependent word-cloud gate.
    private func buildExportOptions() -> CollectionExportOptions {
        CollectionExportOptions(
            tocStyle:        CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
            bodyDepth:       CollectionBodyDepth(rawValue: collection.defaultBodyDepth) ?? .full,
            footnoteStyle:   CollectionFootnoteStyle(rawValue: collection.footnoteStyle) ?? .all,
            applyHighlights: collection.applyHighlights,
            includeNotes:    collection.includeNotes,
            summaryPromptId: collection.summaryPromptId,
            includeWordCloud: collection.includeWordCloud && (selectedFormat == .pdf || selectedFormat == .html)
        )
    }

    // MARK: - Send to Zotero Library (Web API)

    /// `true` when a Zotero account is connected (Settings → Integrations → Zotero).
    private var isZoteroConnected: Bool { ZoteroAccountStore.shared.isConnected }

    /// A "Send to Zotero Library…" button, shown only when a Zotero account is
    /// connected. Pushes the collection's documents — with tags and research notes —
    /// straight into the user's Zotero library via the Web API.
    @ViewBuilder
    private var zoteroSendButton: some View {
        if isZoteroConnected {
            Button {
                Task { await sendToZoteroLibrary() }
            } label: {
                Label(String(localized: "export.zotero.send",
                             defaultValue: "Send to Zotero Library…"),
                      systemImage: "books.vertical")
            }
            .disabled(isExporting)
        }
    }

    /// Resolves the collection's documents (static or smart) and POSTs them to the
    /// user's Zotero library, then surfaces a result alert.
    private func sendToZoteroLibrary() async {
        let store = ZoteroAccountStore.shared
        guard let apiKey = store.retrieveKey(), let userID = store.userID else {
            exportError = ZoteroAPIError.missingCredentials.errorDescription
            return
        }
        isExporting = true
        defer { isExporting = false; preparingMessage = nil }
        do {
            let docs = try await resolvedZoteroDocuments()
            let items = docs.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.zoteroItem)
            guard !items.isEmpty else {
                exportError = String(localized: "export.zotero.empty",
                                     defaultValue: "This collection has no documents to send.")
                return
            }
            let result = try await ZoteroAPIClient().send(
                items: items,
                collectionName: collection.name.isEmpty ? nil : collection.name,
                apiKey: apiKey,
                userID: userID,
                username: store.username
            ) { message in
                Task { @MainActor in preparingMessage = message }
            }
            appState.logEvent(.export(format: "zotero-api", documentCount: result.addedItems))
            zoteroResult = result
        } catch is CancellationError {
            return
        } catch {
            exportError = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Resolves the collection's export documents for the Zotero send, handling both
    /// the smart (saved-search) and static collection paths.
    private func resolvedZoteroDocuments() async throws -> [CollectionExportDocument] {
        if let searchId = collection.savedSearchId {
            guard let searchService = appState.searchService else {
                throw ZoteroAPIError.network(String(localized: "export.smart.noSearchService",
                                                    defaultValue: "Search service unavailable."))
            }
            let descriptor = FetchDescriptor<SavedSearch>(predicate: #Predicate { $0.id == searchId })
            guard let savedSearch = try? modelContext.fetch(descriptor).first else { return [] }
            // Full result set, not the 20-item default page (see runExport).
            let results = try await searchService.search(
                parameters: savedSearch.searchParameters,
                limit: SearchViewModel.searchHardLimit
            )
            let smart = results.enumerated().map {
                SmartEntry(documentId: $0.element.documentId, volumeId: $0.element.volumeId, sortOrder: $0.offset)
            }
            return await resolveSmartDocuments(smart)
        }
        await prepareVolumes()
        return try await resolveDocuments()
    }

    /// Localised body for the Zotero result alert.
    private func zoteroResultMessage(_ result: ZoteroSendResult) -> String {
        var line = String(format: String(localized: "export.zotero.result %lld %lld",
                                          defaultValue: "Added %lld documents and %lld notes to Zotero."),
                          Int64(result.addedItems), Int64(result.addedNotes))
        if result.failedItems > 0 {
            line += " " + String(format: String(localized: "export.zotero.result.failed %lld",
                                                defaultValue: "%lld failed."),
                                 Int64(result.failedItems))
        }
        return line
    }

    /// Downloads and indexes any volumes referenced by the collection that are not yet
    /// available locally. Updates `preparingMessage` to give the user live feedback.
    private func prepareVolumes() async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }

        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let neededVolumeIds = Set(entries.map(\.volumeId))

        // Classify each needed volume.
        var toDownload: [(volumeId: String, downloadUrl: String)] = []
        var toIndex: [String] = []
        for vid in neededVolumeIds {
            if !dm.isVolumeDownloaded(vid) {
                if let entry = manifest.first(where: { $0.volumeId == vid }) {
                    toDownload.append((vid, entry.downloadUrl))
                }
            } else if (try? !pipeline.isVolumeIndexed(vid)) == true {
                toIndex.append(vid)
            }
        }

        guard !toDownload.isEmpty || !toIndex.isEmpty else { return }

        let totalNeeded = toDownload.count + toIndex.count
        preparingMessage = String(
            localized: "export.preparing.volumes",
            defaultValue: "Preparing \(totalNeeded) volume\(totalNeeded == 1 ? "" : "s")…"
        )

        // Kick off indexing for downloaded-but-unindexed volumes.
        for vid in toIndex {
            Task { try? await pipeline.indexVolume(vid) }
        }
        // Enqueue downloads; indexing follows automatically via onVolumeDownloaded.
        for (vid, url) in toDownload {
            await dm.enqueueDownload(volumeId: vid, downloadUrl: url)
        }

        // Poll until every needed volume is indexed (or we time out after ~5 min).
        let waitSet = Set(toDownload.map(\.volumeId) + toIndex)
        var remaining = waitSet
        var elapsedMs = 0
        let pollInterval = 1_000_000_000   // 1 second in nanoseconds
        let timeoutMs   = 300_000          // 5 minutes

        while !remaining.isEmpty && elapsedMs < timeoutMs {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval))
            elapsedMs += 1_000
            remaining = remaining.filter { vid in
                (try? !pipeline.isVolumeIndexed(vid)) != false
            }
            let ready = waitSet.count - remaining.count
            let total = waitSet.count
            preparingMessage = String(
                localized: "export.preparing.progress",
                defaultValue: "Preparing volumes: \(ready) of \(total) ready…"
            )
        }

        preparingMessage = nil
    }

    private func resolveDocuments() async throws -> [CollectionExportDocument] {
        let opts    = buildExportOptions()
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let manifestMap = Dictionary(uniqueKeysWithValues: manifest.map { ($0.volumeId, $0) })
        let formatter = HistoryAtStateCitationFormatter()

        // Pre-load body texts: SQLite cache (fast) then XML fallback (slow).
        // Group by volume so each volume XML is opened at most once on the fallback path.
        var bodyTexts: [String: String] = [:]

        let volumeIds = Set(entries.map(\.volumeId))
        for volumeId in volumeIds {
            let docsInVolume = entries.filter { $0.volumeId == volumeId }

            // SQLite cache path
            if let pipeline = appState.indexingPipeline {
                for entry in docsInVolume {
                    let key = "\(entry.volumeId)/\(entry.documentId)"
                    if let text = try? await pipeline.fetchDocumentBodyText(
                        volumeId: entry.volumeId, documentId: entry.documentId) {
                        bodyTexts[key] = text
                    }
                }
            }

            // XML fallback for anything still uncached
            let uncached = docsInVolume.filter {
                bodyTexts["\($0.volumeId)/\($0.documentId)"] == nil
            }
            if !uncached.isEmpty, let dm = appState.downloadManager {
                let volumeURL = dm.volumeURL(for: volumeId)
                if FileManager.default.fileExists(atPath: volumeURL.path) {
                    let parser = FRUSDocumentParser()
                    for entry in uncached {
                        let key = "\(entry.volumeId)/\(entry.documentId)"
                        if let ast = try? await parser.parseDocument(
                            documentId: entry.documentId, volumeURL: volumeURL) {
                            bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                        }
                    }
                }
            }
        }

        // Render models: parse each volume XML to obtain structured render output.
        // One parse per document — acceptable cost for a user-initiated export.
        // Falls back gracefully (nil) when the volume file is unavailable.
        var renderModels: [String: FRUSDocumentRenderModel] = [:]
        for volumeId in volumeIds {
            guard let dm = appState.downloadManager else { continue }
            let volumeURL = dm.volumeURL(for: volumeId)
            guard FileManager.default.fileExists(atPath: volumeURL.path) else { continue }
            let docsInVolume = entries.filter { $0.volumeId == volumeId }
            for entry in docsInVolume {
                let key = "\(entry.volumeId)/\(entry.documentId)"
                if let ast = try? await FRUSDocumentParser().parseDocument(
                    documentId: entry.documentId, volumeURL: volumeURL) {
                    var converter = ASTToRenderNodeConverter()
                    renderModels[key] = converter.convert(ast)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: volumeIds, pipeline: appState.indexingPipeline)

        return entries.sorted { $0.sortOrder < $1.sortOrder }.map { entry in
            let manifestEntry = manifestMap[entry.volumeId]
            let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
            let key = "\(entry.volumeId)/\(entry.documentId)"
            let renderModel = renderModels[key]

            // Extract header and dateline from the render model when available.
            let (header, dateline) = renderModelHeadAndDateline(renderModel)

            let docNum: String? = entry.documentId.hasPrefix("d")
                ? Int(entry.documentId.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: entry.documentId, documentNumber: docNum,
                header: header, dateline: dateline)
            let citation = volMeta.map { formatter.format(document: docMeta, volume: $0) }
                ?? "\(entry.volumeId)/\(entry.documentId)"
            let urlString = "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
            let volumeTitle = manifestEntry?.title ?? entry.volumeId
            let bodyText = bodyTexts[key] ?? ""

            // Resolve note texts: selectedNoteIds takes precedence over legacy researchNoteId.
            let resolvedNoteTexts: [String]
            if !entry.selectedNoteIds.isEmpty {
                resolvedNoteTexts = entry.selectedNoteIds.compactMap { nid in
                    allNotes.first { $0.id == nid }?.bodyText
                }.filter { !$0.isEmpty }
            } else if let legacyNote = entry.researchNoteId.flatMap({ nid in allNotes.first { $0.id == nid } }) {
                resolvedNoteTexts = legacyNote.bodyText.isEmpty ? [] : [legacyNote.bodyText]
            } else {
                resolvedNoteTexts = []
            }

            // Highlights (when applyHighlights and body is full)
            let resolvedHighlights: [ExportHighlight]
            if opts.applyHighlights && opts.bodyDepth == .full {
                let allHL = (try? modelContext.fetch(FetchDescriptor<DocumentHighlight>())) ?? []
                resolvedHighlights = allHL
                    .filter { $0.volumeId == entry.volumeId && $0.documentId == entry.documentId }
                    .map { ExportHighlight(startOffset: $0.startOffset,
                                          endOffset:   $0.endOffset,
                                          color:       $0.color) }
            } else {
                resolvedHighlights = []
            }

            // Source note (footnoteStyle == .sourceNoteOnly)
            let resolvedSourceNote: String?
            if opts.footnoteStyle == .sourceNoteOnly {
                resolvedSourceNote = try? appState.indexingPipeline?
                    .fetchDocumentSourceNote(volumeId: entry.volumeId,
                                             documentId: entry.documentId)
            } else {
                resolvedSourceNote = nil
            }

            // Zotero JSON item (for ExportFormat.zoteroJSON)
            let zoteroItem: ZoteroJSONExporter.Item?
            if let volMeta {
                let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
                let (tags, _) = ZoteroJSONExporter.fetchTagsAndNotes(
                    documentId: entry.documentId, volumeId: entry.volumeId, context: modelContext)
                zoteroItem = ZoteroJSONExporter.makeItem(
                    document: docMeta,
                    volume: volMeta,
                    year: year,
                    url: urlString,
                    isEditorialNote: editorialNoteFlags[key] ?? false,
                    tags: tags,
                    notes: resolvedNoteTexts
                )
            } else {
                zoteroItem = nil
            }

            return CollectionExportDocument(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                title: "\(volumeTitle) — \(entry.documentId)",
                date: manifestEntry?.dateRange.earliest,
                bodyText: bodyText,
                noteTexts: resolvedNoteTexts,
                citation: citation,
                historyStateGovURL: urlString,
                renderModel: renderModel,
                header: header,
                dateline: dateline,
                highlights: resolvedHighlights,
                sourceNoteText: resolvedSourceNote,
                zoteroItem: zoteroItem
            )
        }
    }

    /// Generates or fetches summaries for all entries when bodyDepth == .summaryOnly.
    /// Returns a [key: summaryText] map. Throws if any generation fails.
    private func resolveSummaries(
        for docs: [CollectionExportDocument],
        promptId: UUID,
        bodyTexts: [String: String]
    ) async throws -> [String: String] {
        guard AppleIntelligenceProvider.shared.isAvailable else {
            throw ExportError.renderingFailed
        }
        guard let service = appState.summarizationService else {
            throw ExportError.renderingFailed
        }
        guard let prompt = (try? modelContext.fetch(
            FetchDescriptor<SummarizationPrompt>(
                predicate: #Predicate { $0.id == promptId }
            )))?.first else {
            throw ExportError.renderingFailed
        }
        let snapshot = SummarizationPromptSnapshot(from: prompt)

        var result: [String: String] = [:]
        let total = docs.count

        for (i, doc) in docs.enumerated() {
            let key = "\(doc.volumeId)/\(doc.documentId)"
            await MainActor.run {
                summaryGeneratingMessage = String(
                    localized: "export.summaryProgress",
                    defaultValue: "Generating summaries (\(i + 1) of \(total))…")
            }

            // Check for existing summary first (capture scalars — #Predicate can't use struct fields).
            let vid = doc.volumeId
            let did = doc.documentId
            let pid = promptId
            let existingDesc = FetchDescriptor<GeneratedSummary>(
                predicate: #Predicate<GeneratedSummary> { s in
                    s.volumeId == vid && s.documentId == did && s.promptId == pid
                }
            )
            if let existing = try? modelContext.fetch(existingDesc).first,
               !existing.responseText.isEmpty {
                result[key] = existing.responseText
                continue
            }

            // Generate on demand.
            let text = bodyTexts[key] ?? doc.bodyText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ExportError.renderingFailed
            }
            let generated = try await service.summarize(
                documentId:    doc.documentId,
                volumeId:      doc.volumeId,
                documentText:  text,
                prompt:        snapshot,
                provider:      AppleIntelligenceProvider.shared,
                activeProjectId: appState.activeProjectId
            )
            result[key] = generated.responseText
        }
        await MainActor.run { summaryGeneratingMessage = nil }
        return result
    }

    // MARK: - Render Model Extraction Helpers

    /// Extracts the first heading and first dateline from a render model's body nodes.
    private func renderModelHeadAndDateline(_ model: FRUSDocumentRenderModel?) -> (header: String, dateline: String?) {
        guard let model else { return ("", nil) }
        var header = ""
        var dateline: String? = nil
        for node in model.bodyNodes {
            if case .heading(let c) = node, header.isEmpty {
                header = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if case .dateline(let c) = node, dateline == nil {
                let text = renderNodePlainText(c).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { dateline = text }
            }
            if !header.isEmpty && dateline != nil { break }
        }
        return (header, dateline)
    }

    /// Recursively extracts plain text from an array of `FRUSRenderNode` values.
    private func renderNodePlainText(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { renderNodePlainText($0) }.joined()
    }

    /// Recursively extracts plain text from a single `FRUSRenderNode`.
    private func renderNodePlainText(_ node: FRUSRenderNode) -> String {
        switch node {
        case .plainText(let s):
            return s
        case .boldText(let c), .italicText(let c), .smallCapsText(let c),
             .underlineText(let c), .termText(let c), .corrText(let c),
             .suppliedText(let c), .sicText(let c):
            return renderNodePlainText(c)
        case .heading(let c), .dateline(let c), .salutation(let c),
             .paragraph(let c), .attachmentHeading(let c):
            return renderNodePlainText(c)
        case .letterOpener(let c), .letterCloser(let c),
             .editorialNoteBlock(let c), .titlePageBlock(let c):
            return renderNodePlainText(c)
        case .attachmentBlock(_, let c), .unknown(_, let c):
            return renderNodePlainText(c)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _),
             .crossRefLink(_, _, let c):
            return renderNodePlainText(c)
        case .formulaText(let s):
            return s
        case .lineBreak:
            return " "
        case .footnoteMarker(_, let label):
            return "[\(label)]"
        case .listBlock(_, let items):
            return items.map { renderNodePlainText($0) }.joined(separator: " ")
        case .tableBlock(let rows):
            return rows.map { row in row.map { renderNodePlainText($0.children) }.joined(separator: " | ") }.joined(separator: "\n")
        case .footnoteBody, .pageBreak, .figureBlock:
            return ""
        }
    }

    // MARK: - Smart Document Resolution

    /// Resolves documents from a smart collection using pre-fetched search result entries.
    /// Unlike `resolveDocuments()`, this path has no `prepareVolumes` phase — search results
    /// are already indexed — and produces no `noteText` since smart entries carry no research note links.
    private func resolveSmartDocuments(_ smartEntries: [SmartEntry]) async -> [CollectionExportDocument] {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        let manifestMap = Dictionary(uniqueKeysWithValues: manifest.map { ($0.volumeId, $0) })
        let formatter = HistoryAtStateCitationFormatter()

        var bodyTexts: [String: String] = [:]
        let volumeIds = Set(smartEntries.map(\.volumeId))

        for volumeId in volumeIds {
            let docsInVolume = smartEntries.filter { $0.volumeId == volumeId }

            if let pipeline = appState.indexingPipeline {
                for entry in docsInVolume {
                    let key = "\(entry.volumeId)/\(entry.documentId)"
                    if let text = try? await pipeline.fetchDocumentBodyText(
                        volumeId: entry.volumeId, documentId: entry.documentId) {
                        bodyTexts[key] = text
                    }
                }
            }

            let uncached = docsInVolume.filter { bodyTexts["\($0.volumeId)/\($0.documentId)"] == nil }
            if !uncached.isEmpty, let dm = appState.downloadManager {
                let volumeURL = dm.volumeURL(for: volumeId)
                if FileManager.default.fileExists(atPath: volumeURL.path) {
                    let parser = FRUSDocumentParser()
                    for entry in uncached {
                        let key = "\(entry.volumeId)/\(entry.documentId)"
                        if let ast = try? await parser.parseDocument(
                            documentId: entry.documentId, volumeURL: volumeURL) {
                            bodyTexts[key] = IndexingPipeline.extractBodyText(from: ast.nodes)
                        }
                    }
                }
            }
        }

        var renderModels: [String: FRUSDocumentRenderModel] = [:]
        for volumeId in volumeIds {
            guard let dm = appState.downloadManager else { continue }
            let volumeURL = dm.volumeURL(for: volumeId)
            guard FileManager.default.fileExists(atPath: volumeURL.path) else { continue }
            let docsInVolume = smartEntries.filter { $0.volumeId == volumeId }
            for entry in docsInVolume {
                let key = "\(entry.volumeId)/\(entry.documentId)"
                if let ast = try? await FRUSDocumentParser().parseDocument(
                    documentId: entry.documentId, volumeURL: volumeURL) {
                    var converter = ASTToRenderNodeConverter()
                    renderModels[key] = converter.convert(ast)
                }
            }
        }

        // Editorial-note flags from the index, so collection-level Zotero items
        // carry the same "Editorial note" extra line as document-level exports.
        let editorialNoteFlags = await ZoteroJSONExporter.editorialNoteFlags(
            volumeIds: volumeIds, pipeline: appState.indexingPipeline)

        return smartEntries.sorted { $0.sortOrder < $1.sortOrder }.map { entry in
            let manifestEntry = manifestMap[entry.volumeId]
            let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
            let key = "\(entry.volumeId)/\(entry.documentId)"
            let renderModel = renderModels[key]

            let (header, dateline) = renderModelHeadAndDateline(renderModel)

            let docNum: String? = entry.documentId.hasPrefix("d")
                ? Int(entry.documentId.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: entry.documentId, documentNumber: docNum,
                header: header, dateline: dateline)
            let citation = volMeta.map { formatter.format(document: docMeta, volume: $0) }
                ?? "\(entry.volumeId)/\(entry.documentId)"
            let urlString = "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
            let volumeTitle = manifestEntry?.title ?? entry.volumeId
            let bodyText = bodyTexts[key] ?? ""

            let zoteroItem: ZoteroJSONExporter.Item?
            if let volMeta {
                let year = FRUSVolumeMetadata.firstYear(in: volMeta.publicationDate).map(String.init) ?? "n.d."
                let (tags, notes) = ZoteroJSONExporter.fetchTagsAndNotes(
                    documentId: entry.documentId, volumeId: entry.volumeId, context: modelContext)
                zoteroItem = ZoteroJSONExporter.makeItem(
                    document: docMeta,
                    volume: volMeta,
                    year: year,
                    url: urlString,
                    isEditorialNote: editorialNoteFlags[key] ?? false,
                    tags: tags,
                    notes: notes
                )
            } else {
                zoteroItem = nil
            }

            return CollectionExportDocument(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                title: "\(volumeTitle) — \(entry.documentId)",
                date: manifestEntry?.dateRange.earliest,
                bodyText: bodyText,
                citation: citation,
                historyStateGovURL: urlString,
                renderModel: renderModel,
                header: header,
                dateline: dateline,
                zoteroItem: zoteroItem
            )
        }
    }
}

// MARK: - MacExportCompleteView

#if os(macOS)
/// Shown after a successful export on macOS.
///
/// Offers two actions:
/// - **Reveal in Finder** — opens the file's containing folder with the file selected.
/// - **Save To…** — presents an `NSSavePanel` so the user can copy the exported file
///   to a permanent location of their choice.
///
/// The file lives in `FileManager.temporaryDirectory` and will be cleaned up by
/// the OS; using the Save panel is the recommended path for keeping the output.
struct MacExportCompleteView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Success content
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text(String(localized: "export.mac.success.title",
                            defaultValue: "Export Complete"))
                    .font(.headline)

                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            // Button bar — Done (left, Escape), Reveal in Finder (secondary),
            // Save To… (primary, Return). Standard macOS success dialog layout.
            HStack(spacing: 8) {
                Button(String(localized: "export.mac.done",
                              defaultValue: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "export.mac.reveal",
                              defaultValue: "Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    dismiss()
                }

                Button(String(localized: "export.mac.saveTo",
                              defaultValue: "Save To\u{2026}")) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = url.lastPathComponent
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let dest = panel.url {
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: url, to: dest)
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 340)
    }
}
#endif

// MARK: - ShareSheet

#if os(iOS)
/// Thin wrapper around the iOS share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - URL: Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Zotero result alert

/// Presents the outcome of a "Send to Zotero Library" run, with an optional
/// "View in Zotero" link. Shared by the export sheet's macOS and iOS bodies.
private struct ZoteroResultAlertModifier: ViewModifier {
    @Binding var result: ZoteroSendResult?
    let message: (ZoteroSendResult) -> String
    let openURL: OpenURLAction

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "export.zotero.result.title", defaultValue: "Sent to Zotero"),
            isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } }),
            presenting: result
        ) { result in
            if let url = result.webURL {
                Button(String(localized: "export.zotero.viewInZotero",
                              defaultValue: "View in Zotero")) { openURL(url) }
            }
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: { result in
            Text(message(result))
        }
    }
}

extension View {
    /// Attaches the Zotero "Sent to Zotero" result alert.
    func zoteroResultAlert(
        result: Binding<ZoteroSendResult?>,
        message: @escaping (ZoteroSendResult) -> String,
        openURL: OpenURLAction
    ) -> some View {
        modifier(ZoteroResultAlertModifier(result: result, message: message, openURL: openURL))
    }
}

// MARK: - CollectionCompositionRows

/// The editorial controls that determine *what an exported product contains* — persisted on
/// the `Collection` and edited in the manager (not the export sheet). Renders as a group of
/// form rows shared by the iOS editor (inside a `Section`) and the macOS manager (inside a
/// `DisclosureGroup`). Enum-backed fields are stored as raw-value strings on the model, so the
/// pickers bind through small mapping `Binding`s.
///
/// Edits apply **live** to the model, matching the iOS editor's other content edits (document
/// add/remove/reorder and smart-collection linkage) and the fully-live macOS manager. Only a
/// collection's name and note use the iOS editor's draft/Save step; composition, like the
/// document list itself, is not part of that draft.
///
/// Version history:
///   1.0 — Collections rework Phase 1a: composition moved out of the ephemeral export sheet
struct CollectionCompositionRows: View {

    /// The collection whose persisted composition is being edited.
    @Bindable var collection: Collection

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    private var bodyDepth: Binding<CollectionBodyDepth> {
        Binding(get: { CollectionBodyDepth(rawValue: collection.defaultBodyDepth) ?? .full },
                set: { collection.defaultBodyDepth = $0.rawValue })
    }

    /// Body-depth choices: those available on this device, plus the currently-persisted value
    /// even when it isn't otherwise offered here. A `"summaryOnly"` collection synced from a
    /// device with Apple Intelligence must still render with a selected row (and stay editable)
    /// on a device without it — otherwise the picker would show a blank selection.
    private var bodyDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        let current = bodyDepth.wrappedValue
        return available.contains(current) ? available : available + [current]
    }
    private var footnoteStyle: Binding<CollectionFootnoteStyle> {
        Binding(get: { CollectionFootnoteStyle(rawValue: collection.footnoteStyle) ?? .all },
                set: { collection.footnoteStyle = $0.rawValue })
    }
    private var tocStyle: Binding<CollectionToCStyle> {
        Binding(get: { CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation },
                set: { collection.tocStyle = $0.rawValue })
    }

    var body: some View {
        Picker(String(localized: "composition.bodyDepth", defaultValue: "Document body"),
               selection: bodyDepth) {
            ForEach(bodyDepthOptions) { Text($0.displayName).tag($0) }
        }

        if bodyDepth.wrappedValue == .summaryOnly {
            Picker(String(localized: "composition.summaryPrompt", defaultValue: "Summary prompt"),
                   selection: Binding(get: { collection.summaryPromptId },
                                      set: { collection.summaryPromptId = $0 })) {
                Text(String(localized: "composition.summaryPrompt.none", defaultValue: "Select…"))
                    .tag(UUID?.none)
                ForEach(allPrompts) { Text($0.name).tag(UUID?.some($0.id)) }
            }
            Text(String(localized: "composition.summaryPrompt.hint",
                        defaultValue: "Summaries are generated on demand for documents that don't already have one for this prompt. Requires Apple Intelligence."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Picker(String(localized: "composition.footnotes", defaultValue: "Footnotes"),
               selection: footnoteStyle) {
            ForEach(CollectionFootnoteStyle.allCases) { Text($0.displayName).tag($0) }
        }

        Picker(String(localized: "composition.tocStyle", defaultValue: "Contents list"),
               selection: tocStyle) {
            ForEach(CollectionToCStyle.allCases) { Text($0.displayName).tag($0) }
        }

        Toggle(String(localized: "composition.applyHighlights",
                      defaultValue: "Apply highlights to document body"),
               isOn: $collection.applyHighlights)
            .disabled(bodyDepth.wrappedValue != .full)

        Toggle(String(localized: "composition.includeNotes",
                      defaultValue: "Include research notes"),
               isOn: $collection.includeNotes)

        Toggle(String(localized: "composition.includeWordCloud",
                      defaultValue: "Include word-cloud overview (PDF and HTML)"),
               isOn: $collection.includeWordCloud)
    }
}
