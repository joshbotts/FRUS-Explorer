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
///          (IndexingPipeline.fetchDocumentBodyText) with XML fallback for un-indexed volumes;
///          citation built via HistoryAtStateCitationFormatter; AddByTagSheet, ExportSheetView,
///          and MacExportCompleteView made internal (non-private) for use in MacCollectionManagerView
///   1.3 — Session 74: two-line research note preview (caption2, tertiary) added to EntryRow
///          beneath the volume ID; same preview added to MacEntryRow in MacCollectionManagerView
struct CollectionEditorView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - SwiftData queries

    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]

    // MARK: - State

    @State private var collection: Collection
    private let isNewCollection: Bool

    @State private var collectionName: String
    @State private var collectionNote: String
    @State private var sortedEntries: [CollectionEntry]

    @State private var showAddByTag  = false
    @State private var showExport    = false
    @State private var exportError: String?

    // MARK: - Init

    init(collection: Collection?) {
        if let c = collection {
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: c.name)
            _collectionNote = State(initialValue: c.note ?? "")
            _sortedEntries = State(initialValue:
                (c.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder })
            isNewCollection = false
        } else {
            let c = Collection(name: "")
            _collection = State(initialValue: c)
            _collectionName = State(initialValue: "")
            _collectionNote = State(initialValue: "")
            _sortedEntries = State(initialValue: [])
            isNewCollection = true
        }
    }

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
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
                documentsSection
                addByTagSection
                if !sortedEntries.isEmpty {
                    actionsSection
                }
            }
            .formStyle(.grouped)

            Divider()

            // Button bar
            HStack {
                Button(String(localized: "collection.editor.cancel", defaultValue: "Cancel")) {
                    if isNewCollection {
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
            Form {
                nameSection
                noteSection
                documentsSection
                addByTagSection
                if !sortedEntries.isEmpty {
                    actionsSection
                }
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

    // MARK: - Documents Section

    @ViewBuilder
    private var documentsSection: some View {
        Section {
            if sortedEntries.isEmpty {
                Text(String(localized: "collection.editor.docs.empty",
                            defaultValue: "No documents yet. Add some using a subject tag below."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
            Button {
                sortByDate()
            } label: {
                Label(
                    String(localized: "collection.editor.actions.sortByDate",
                           defaultValue: "Sort by Date"),
                    systemImage: "calendar"
                )
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
        if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) {
            collection.projectIds.append(projectId)
        }
        try? modelContext.save()
    }
}

// MARK: - EntryRow

/// A single row in the documents list that lets the user associate a `ResearchNote`.
private struct EntryRow: View {
    @Binding var entry: CollectionEntry
    let availableNotes: [ResearchNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.documentId)
                .font(.body)
                .accessibilityLabel(
                    String(localized: "collection.entry.document.accessibility",
                           defaultValue: "Document \(entry.documentId)")
                )

            Text(entry.volumeId)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let id = entry.researchNoteId,
               let note = availableNotes.first(where: { $0.id == id }),
               !note.bodyText.isEmpty {
                Text(note.bodyText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !availableNotes.isEmpty {
                Picker(
                    String(localized: "collection.entry.notePicker.label",
                           defaultValue: "Note"),
                    selection: Binding(
                        get: { entry.researchNoteId },
                        set: { entry.researchNoteId = $0 }
                    )
                ) {
                    Text(String(localized: "collection.entry.notePicker.none",
                                defaultValue: "None")).tag(UUID?.none)
                    ForEach(availableNotes) { note in
                        Text(noteLabel(note)).tag(Optional(note.id))
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    private func noteLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? String(localized: "collection.entry.note.emptyPreview",
                                        defaultValue: "Untitled Note") : String(preview)
    }
}

// MARK: - AddByTagSheet

/// Sheet that lets the user pick a `UserTag` then appends all tagged documents.
struct AddByTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allTags: [UserTag]
    let allNotes: [ResearchNote]
    let onAdd: ([(documentId: String, volumeId: String)]) -> Void

    @State private var selectedTagId: UUID? = nil

    var body: some View {
        NavigationStack {
            List(allTags) { tag in
                Button {
                    selectedTagId = tag.id
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

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "export.format.header", defaultValue: "Format")) {
                    Picker(
                        String(localized: "export.format.picker", defaultValue: "Format"),
                        selection: $selectedFormat
                    ) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if let msg = preparingMessage {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(msg)
                                .foregroundStyle(.secondary)
                        }
                    } else if isExporting {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
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
                        .disabled(entries.isEmpty)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "export.close", defaultValue: "Close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $exportedURL) { url in
                #if os(iOS)
                ShareSheet(url: url)
                    .ignoresSafeArea()
                #else
                MacExportCompleteView(url: url)
                #endif
            }
        }
    }

    private func runExport() async {
        exportError = nil

        // Phase 1: ensure every volume referenced by the collection is downloaded and indexed.
        await prepareVolumes()

        // Phase 2: resolve document content (now that all volumes should be available).
        isExporting = true
        do {
            let docs = await resolveDocuments()
            let metadata = CollectionExportMetadata(name: collection.name, note: collection.note)
            let exporter = selectedFormat.makeExporter()
            let url = try await exporter.export(metadata: metadata, documents: docs)
            exportedURL = url
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
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

    private func resolveDocuments() async -> [CollectionExportDocument] {
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

        return entries.sorted { $0.sortOrder < $1.sortOrder }.map { entry in
            let note = entry.researchNoteId.flatMap { nid in allNotes.first { $0.id == nid } }
            let manifestEntry = manifestMap[entry.volumeId]
            let volMeta = manifestEntry.map { FRUSVolumeMetadata($0) }
            let docNum: String? = entry.documentId.hasPrefix("d")
                ? Int(entry.documentId.dropFirst()).map { String($0) }
                : nil
            let docMeta = FRUSDocumentMetadata(
                documentId: entry.documentId, documentNumber: docNum,
                header: "", dateline: nil)
            let citation = volMeta.map { formatter.format(document: docMeta, volume: $0) }
                ?? "\(entry.volumeId)/\(entry.documentId)"
            let urlString = "https://history.state.gov/historicaldocuments/\(entry.volumeId)/\(entry.documentId)"
            let volumeTitle = manifestEntry?.title ?? entry.volumeId
            let bodyText = bodyTexts["\(entry.volumeId)/\(entry.documentId)"] ?? ""

            return CollectionExportDocument(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                sortOrder: entry.sortOrder,
                title: "\(volumeTitle) — \(entry.documentId)",
                date: manifestEntry?.dateRange.earliest,
                bodyText: bodyText,
                noteText: note?.bodyText,
                citation: citation,
                historyStateGovURL: urlString
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
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)

            Text(String(localized: "export.mac.success.title",
                        defaultValue: "Export Complete"))
                .font(.headline)

            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(String(localized: "export.mac.reveal",
                              defaultValue: "Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    dismiss()
                }

                Button(String(localized: "export.mac.saveTo",
                              defaultValue: "Save To\u{2026}")) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = url.lastPathComponent
                    // Allow the OS to infer the content type from the extension.
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let dest = panel.url {
                        try? FileManager.default.removeItem(at: dest)
                        try? FileManager.default.copyItem(at: url, to: dest)
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
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
