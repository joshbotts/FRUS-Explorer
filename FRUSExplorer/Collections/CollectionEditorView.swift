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

    /// Bulk-loaded per-document display data (headers + ISO dates from the index), keyed
    /// `"volumeId/documentId"` — the same pane-level pattern as the macOS manager, so
    /// entry rows show real document identities and Sort by Date has per-document
    /// precision (Authoring Phase 1 row parity).
    @State private var documentHeaders: [String: String] = [:]
    @State private var documentDates: [String: String] = [:]

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
        // Reload document headers and per-document dates whenever the entry list changes.
        // (The Group has exactly one child per platform, so this task attaches once.)
        .task(id: sortedEntries.map(\.id)) {
            (documentHeaders, documentDates) =
                await CollectionEntryData.load(for: sortedEntries, appState: appState)
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
                    switch entry.entryKind {
                    case .document:
                        let key = "\(entry.volumeId)/\(entry.documentId)"
                        EntryRow(entry: $entry,
                                 availableNotes: notes(for: entry),
                                 documentHeader: documentHeaders[key],
                                 volumeTitle: volumeTitle(for: entry),
                                 documentDate: documentDates[key])
                    case .heading:
                        CollectionHeadingRow(entry: $entry)
                    case .prose:
                        CollectionProseRow(entry: $entry)
                    case .unrecognized:
                        UnrecognizedEntryRow()
                    }
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
                } label: {
                    Image(systemName: "plus").font(.caption)
                }
                .accessibilityLabel(String(localized: "collection.add.structural",
                                           defaultValue: "Add a section heading or note block"))
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
        // Shared canonical sort (Authoring Phase 1): per-document `date_iso` first, then
        // volume earliest date, then the "9999" sentinel — previously iOS sorted by volume
        // dates only, so documents within one volume kept insertion order.
        sortedEntries = CollectionEntryData.sortedByDate(
            sortedEntries, documentDates: documentDates, manifest: manifest)
        reindexEntries()
    }

    /// The manifest display title for an entry's volume, falling back to the raw volume id
    /// (matches the macOS manager's helper).
    private func volumeTitle(for entry: CollectionEntry) -> String {
        let manifest = appState.manifestStore.diffResult?.known
            ?? appState.manifestStore.bundledEntries
        return manifest.first(where: { $0.volumeId == entry.volumeId })?.title ?? entry.volumeId
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
