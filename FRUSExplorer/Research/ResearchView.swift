// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResearchSidebarItem

/// Identifies a selection in the Research sidebar.
enum ResearchSidebarItem: Hashable {
    /// Synthetic "all annotated documents" entry — shows every document with at least one note.
    case allNotes
    /// A specific user tag — shows only documents whose notes carry this tag ID.
    case tag(UUID)
}

// MARK: - ResearchDocumentEntry

/// One row in the Research document list, aggregating all annotations for a single
/// `(volumeId, documentId)` pair from BOTH data sources:
///
/// - `ResearchNote` records in SwiftData (`latestNote`, `noteCount`, note-level tags)
/// - Direct user tags stored in `document_cache.user_tag_ids` (SQLite/FTS5)
///
/// `latestNote` is `nil` when a document has only direct tags (no notes). Both
/// annotation types contribute to `allTagIds` so the Research window reflects the
/// complete tagging picture regardless of how the tag was applied.
struct ResearchDocumentEntry: Identifiable {
    /// Stable key: `"volumeId/documentId"`.
    let id: String
    let volumeId: String
    let documentId: String
    /// Most-recently-modified note, or `nil` if this document has only direct tags.
    let latestNote: ResearchNote?
    /// Total number of `ResearchNote` records for this document.
    let noteCount: Int
    /// Union of tags from all notes (`ResearchNote.userTagIds`) and direct
    /// `document_cache.user_tag_ids` assignments.
    let allTagIds: Set<UUID>
}

// MARK: - ResearchView

/// Cross-platform Research view.
///
/// On macOS this is presented inside the `Window("Research", id: "frus.research")` scene.
/// On iOS it fills the Research tab (replacing the former Activity tab).
///
/// ## Layout
/// `NavigationSplitView` with two columns:
/// - **Sidebar**: "All Annotated Documents" synthetic entry, then per-tag rows sorted by
///   distinct-document count descending (most-used tags first).
/// - **Detail**: Document list for the selected sidebar item. Each row shows the document
///   header, volume title, latest note preview, tag chips, and relative note date.
///   Tapping a row opens the document in the main window; right-click (macOS) / long-press
///   (iOS) exposes a context menu for cross-reference graph and further actions.
///
/// ## Data
/// `@Query` for all `ResearchNote` and `UserTag` records. Document headers are loaded
/// asynchronously from `document_cache` via `CrossReferenceStore.documentHeaders(for:)`
/// and cached in `documentHeaders` state. The header load fires on `.task` whenever the
/// selected sidebar item changes.
///
/// Version history:
///   1.0 — Session 130: initial implementation
///   1.1 — Session 130: explicit context saves + onChange triggers for note reactivity
///   1.2 — Session 130: directly-tagged documents (document_cache.user_tag_ids) merged
///          as a first-class data source alongside SwiftData notes; tags and notes are
///          now independent annotation types in the Research window
struct ResearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]

    /// Direct tag-to-document assignments from SwiftData (CloudKit-synced).
    /// Reactive via `@Observable` — the Research window updates automatically when
    /// the user tags a document on any device.
    @Query private var allTagAssignments: [DocumentTagAssignment]

    @State private var selectedItem: ResearchSidebarItem? = .allNotes
    /// Document header text keyed by `"volumeId/documentId"`, loaded from `document_cache`.
    @State private var documentHeaders: [String: String] = [:]

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let item = selectedItem {
                documentList(for: item)
            } else {
                ContentUnavailableView(
                    String(localized: "research.empty.noSelection",
                           defaultValue: "Select a category"),
                    systemImage: "note.text",
                    description: Text(String(localized: "research.empty.noSelection.detail",
                                             defaultValue: "Choose a tag or All Annotated Documents from the sidebar."))
                )
            }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
        // Reload headers when the selected item or the visible document set changes.
        .task(id: selectedItemDocumentIds) { await loadHeaders() }
        // Reload note-sourced headers when any note changes.
        .onChange(of: allNotes.count)              { _, _ in Task { await loadHeaders() } }
        .onChange(of: allNotes.first?.lastModified){ _, _ in Task { await loadHeaders() } }
        // directlyTaggedDocs is now derived from @Query allTagAssignments which is
        // reactive natively — no explicit reload needed.
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            // Synthetic "all notes" entry
            Section {
                Label {
                    HStack {
                        Text(String(localized: "research.sidebar.allNotes",
                                    defaultValue: "All Annotated Documents"))
                        Spacer()
                        Text("\(allAnnotatedDocumentCount)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "note.text")
                }
                .tag(ResearchSidebarItem.allNotes)
            }

            // Tags sorted by document count descending
            if !sortedTagsWithCounts.isEmpty {
                Section(String(localized: "research.sidebar.tags", defaultValue: "By Tag")) {
                    ForEach(sortedTagsWithCounts, id: \.tag.id) { item in
                        Label {
                            HStack {
                                Text(item.tag.name)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Text("◆")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentColor)
                        }
                        .tag(ResearchSidebarItem.tag(item.tag.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(String(localized: "research.title", defaultValue: "Research"))
    }

    // MARK: - Document List

    @ViewBuilder
    private func documentList(for item: ResearchSidebarItem) -> some View {
        let docs = documents(for: item)
        Group {
            if docs.isEmpty {
                ContentUnavailableView(
                    String(localized: "research.empty.noDocs", defaultValue: "No Annotated Documents"),
                    systemImage: "note.text",
                    description: Text(
                        item == .allNotes
                            ? String(localized: "research.empty.noDocs.allNotes",
                                     defaultValue: "Research notes you add from the document view will appear here.")
                            : String(localized: "research.empty.noDocs.tag",
                                     defaultValue: "No documents have notes with this tag.")
                    )
                )
            } else {
                List {
                    ForEach(docs) { entry in
                        documentRow(entry)
                            .contentShape(Rectangle())
                            .onTapGesture { openDocument(entry) }
                            .contextMenu { contextMenuItems(for: entry) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(listTitle(for: item))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Document Row

    private func documentRow(_ entry: ResearchDocumentEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Document header (or fallback to documentId)
            let header = documentHeaders[entry.id]
            if let h = header, !h.isEmpty {
                Text(h)
                    .font(.body)
                    .lineLimit(1)
            } else {
                Text(entry.documentId)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Volume title + relative date
            HStack(spacing: 6) {
                let volumeTitle = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title
                Text(volumeTitle ?? entry.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let date = entry.latestNote?.lastModified {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Latest note preview (nil when document has only direct tags, no notes)
            if let note = entry.latestNote, !note.bodyText.isEmpty {
                Text(note.bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Tag chips + note count
            let tagNames = entry.allTagIds
                .compactMap { id in allTags.first(where: { $0.id == id })?.name }
                .sorted()
            if !tagNames.isEmpty || entry.noteCount > 1 {
                HStack(spacing: 4) {
                    ForEach(tagNames, id: \.self) { name in
                        Text("◆ \(name)")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                    if entry.noteCount > 1 {
                        Text(String(
                            format: String(localized: "research.row.noteCount %lld",
                                           defaultValue: "%lld notes"),
                            Int64(entry.noteCount)
                        ))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for entry: ResearchDocumentEntry) -> some View {
        Button {
            openDocument(entry)
        } label: {
            Label(
                String(localized: "research.action.openDocument",
                       defaultValue: "Open in Main Window"),
                systemImage: "arrow.up.right.square"
            )
        }

        #if os(macOS)
        Button {
            let header = documentHeaders[entry.id] ?? entry.documentId
            let browsEntry = DocumentBrowserEntry(
                documentId: entry.documentId,
                volumeId: entry.volumeId,
                header: header
            )
            appState.currentGraphEntry = browsEntry
            openWindow(id: "frus.crossReferenceGraph")
        } label: {
            Label(
                String(localized: "research.action.showGraph",
                       defaultValue: "Show Cross-References"),
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
        #endif
    }

    // MARK: - Actions

    /// Opens the document in the main window (macOS) or navigates to Browse (iOS).
    private func openDocument(_ entry: ResearchDocumentEntry) {
        let header = documentHeaders[entry.id] ?? entry.documentId
        let browsEntry = DocumentBrowserEntry(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            header: header
        )
        appState.pendingBrowseDocument = browsEntry
        #if os(iOS)
        appState.activeTab = .browse
        #endif
    }

    // MARK: - Header Loading

    /// Flat list of document keys for the current selection, used as `.task(id:)` key.
    private var selectedItemDocumentIds: [String] {
        guard let item = selectedItem else { return [] }
        return documents(for: item).map(\.id)
    }

    private func loadHeaders() async {
        guard let store = appState.crossReferenceStore,
              let item = selectedItem else { return }
        let pairs = documents(for: item)
            .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        guard !pairs.isEmpty else { return }
        if let headers = try? await store.documentHeaders(for: pairs) {
            documentHeaders.merge(headers) { _, new in new }
        }
    }

    /// Loads all documents that have user tags set in `document_cache` (SQLite/FTS5).
    /// Called on first appear and whenever `AppState.documentTaggingGeneration` changes.
    /// Directly-tagged documents derived from the reactive `@Query allTagAssignments`.
    /// Keyed by `"volumeId/documentId"` → `[UUID]` tag IDs.
    private var directlyTaggedDocs: [String: [UUID]] {
        var result: [String: [UUID]] = [:]
        for a in allTagAssignments {
            let key = "\(a.volumeId)/\(a.documentId)"
            result[key, default: []].append(a.tagId)
        }
        return result
    }

    // MARK: - Computed Data

    /// Total distinct documents that have at least one note OR at least one direct tag.
    private var allAnnotatedDocumentCount: Int {
        let noteKeys = Set(allNotes.map { "\($0.volumeId)/\($0.documentId)" })
        let tagKeys  = Set(directlyTaggedDocs.keys)
        return noteKeys.union(tagKeys).count
    }

    /// Tags paired with their distinct-document count (from BOTH notes and direct tags),
    /// sorted most-used first, filtering out tags with zero annotated documents.
    private var sortedTagsWithCounts: [(tag: UserTag, count: Int)] {
        allTags.compactMap { tag in
            let fromNotes = Set(
                allNotes
                    .filter { $0.userTagIds.contains(tag.id) }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
            let fromDirect = Set(
                directlyTaggedDocs
                    .filter { $0.value.contains(tag.id) }
                    .map(\.key)
            )
            let count = fromNotes.union(fromDirect).count
            guard count > 0 else { return nil }
            return (tag: tag, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    /// Aggregates annotations (notes + direct tags) by document for the given sidebar
    /// item. Documents with only direct tags (no notes) appear with `latestNote == nil`.
    /// Sorted newest-note-first; directly-tagged-only documents sort after noted ones.
    private func documents(for item: ResearchSidebarItem) -> [ResearchDocumentEntry] {
        // Collect relevant document keys from notes.
        let relevantNotes: [ResearchNote]
        switch item {
        case .allNotes:    relevantNotes = Array(allNotes)
        case .tag(let id): relevantNotes = allNotes.filter { $0.userTagIds.contains(id) }
        }

        // Collect relevant document keys from directly-tagged docs.
        let directKeys: Set<String>
        switch item {
        case .allNotes:
            directKeys = Set(directlyTaggedDocs.keys)
        case .tag(let id):
            directKeys = Set(directlyTaggedDocs.filter { $0.value.contains(id) }.map(\.key))
        }

        // Group notes by document key.
        var grouped: [String: [ResearchNote]] = [:]
        for note in relevantNotes {
            grouped["\(note.volumeId)/\(note.documentId)", default: []].append(note)
        }
        // Add directly-tagged documents that have no notes in this selection.
        for key in directKeys where grouped[key] == nil {
            grouped[key] = []
        }

        return grouped.compactMap { key, notes -> ResearchDocumentEntry? in
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }

            let sortedNotes = notes.sorted {
                ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
            }
            let directTagIds = Set(directlyTaggedDocs[key] ?? [])
            let noteTagIds   = Set(notes.flatMap { $0.userTagIds })

            return ResearchDocumentEntry(
                id: key,
                volumeId: parts[0],
                documentId: parts[1],
                latestNote: sortedNotes.first,   // nil for directly-tagged-only docs
                noteCount: notes.count,
                allTagIds: noteTagIds.union(directTagIds)
            )
        }
        .sorted {
            // Documents with notes sort by most-recent note; directly-tagged-only
            // documents (latestNote == nil) sort after all noted documents.
            let lhs = $0.latestNote?.lastModified ?? .distantPast
            let rhs = $1.latestNote?.lastModified ?? .distantPast
            return lhs > rhs
        }
    }

    /// Navigation title for the document list column.
    private func listTitle(for item: ResearchSidebarItem) -> String {
        switch item {
        case .allNotes:
            return String(localized: "research.sidebar.allNotes",
                          defaultValue: "All Annotated Documents")
        case .tag(let id):
            return allTags.first(where: { $0.id == id })?.name
                ?? String(localized: "research.list.unknownTag", defaultValue: "Tag")
        }
    }
}
