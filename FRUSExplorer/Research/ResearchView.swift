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
    /// Synthetic "all research documents" entry — union of notes, direct tags, collections, and highlights.
    case allNotes
    /// A specific user tag — shows only documents whose notes or direct assignments carry this tag ID.
    case tag(UUID)
    /// A specific named collection — shows only documents in that `Collection`.
    case collection(UUID)
    /// A specific highlight color — shows documents that have at least one highlight of this color.
    case highlightColor(DocumentHighlight.Color)
}

// MARK: - ResearchDocumentEntry

/// One row in the Research document list, aggregating all researcher engagement for a single
/// `(volumeId, documentId)` pair from four independent sources:
///
/// - `ResearchNote` records in SwiftData (`latestNote`, `noteCount`, note-level tags)
/// - `DocumentTagAssignment` records in SwiftData (direct user tags)
/// - `CollectionEntry` records in SwiftData (collection membership)
/// - `DocumentHighlight` records in SwiftData (highlighted passages, newest-first)
///
/// `latestNote` is `nil` when a document has only direct tags, collection entries, or highlights.
/// `collectionIds` is empty when the document has not been added to any collection.
/// `highlights` is empty when the document has no saved highlights.
struct ResearchDocumentEntry: Identifiable {
    /// Stable key: `"volumeId/documentId"`.
    let id: String
    let volumeId: String
    let documentId: String
    /// Most-recently-modified note, or `nil` if this document has no notes.
    let latestNote: ResearchNote?
    /// Total number of `ResearchNote` records for this document.
    let noteCount: Int
    /// Union of tags from all notes and direct `DocumentTagAssignment` records.
    let allTagIds: Set<UUID>
    /// IDs of `Collection` records this document belongs to.
    let collectionIds: Set<UUID>
    /// Highlights for this document, newest first. May be empty.
    let highlights: [DocumentHighlight]
}

// MARK: - ResearchView

/// Cross-platform Research view.
///
/// On macOS this is presented inside the `Window("Research", id: "frus.research")` scene.
/// On iOS it fills the Research tab (replacing the former Activity tab).
///
/// ## Layout
/// Two levels, composed per platform by `navigationContainer` (#272): macOS keeps a
/// two-column `NavigationSplitView`; iOS uses a `NavigationStack` whose root is the category
/// list, pushing the document list on selection (a split nested in the `.sidebarAdaptable`
/// TabView overlays content on iPadOS — see MainTabView's #238 guard rule).
/// - **Category list** (macOS sidebar column / iOS stack root): "All Research Documents"
///   synthetic entry, then per-tag rows sorted by distinct-document count descending
///   (most-used tags first).
/// - **Document list** (macOS detail column / iOS pushed level): documents for the selected
///   category. Each row shows the document header, volume title, latest note preview, tag
///   chips, and relative note date. Tapping a row opens the document in the main window;
///   right-click (macOS) / long-press (iOS) exposes a context menu for cross-reference graph
///   and further actions.
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
///   1.2 — Session 130: directly-tagged documents merged as a first-class data source
///   1.3 — Session 130: collection membership merged as a third data source; "By Collection"
///          sidebar section; collection chips in document rows; ResearchSidebarItem.collection
///   1.4 — Dynamic Type (UI-Audit A1): sidebar count badges + tag/collection glyphs moved
///          off fixed points onto scalable caption tokens so this shared iOS-tab / macOS-window
///          surface tracks the reader's text-size setting.
struct ResearchView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query(sort: \UserTag.name) private var allTags: [UserTag]
    /// Direct tag-to-document assignments from SwiftData (CloudKit-synced).
    @Query private var allTagAssignments: [DocumentTagAssignment]
    /// Collections and their entries — the third annotation source.
    @Query(sort: \Collection.name) private var allCollections: [Collection]
    @Query private var allCollectionEntries: [CollectionEntry]
    /// Saved highlights — the fourth annotation source; newest-first for display ordering.
    @Query(sort: \DocumentHighlight.createdAt, order: .reverse) private var allHighlights: [DocumentHighlight]

    @State private var selectedItem: ResearchSidebarItem? = .allNotes
    /// Document header text keyed by `"volumeId/documentId"`, loaded from `document_cache`.
    @State private var documentHeaders: [String: String] = [:]

    // MARK: - Body

    var body: some View {
        navigationContainer
            // Reload headers when the selected item or the visible document set changes.
            .task(id: selectedItemDocumentIds) { await loadHeaders() }
            // Reload note-sourced headers when any note changes.
            .onChange(of: allNotes.count)              { _, _ in Task { await loadHeaders() } }
            .onChange(of: allNotes.first?.lastModified){ _, _ in Task { await loadHeaders() } }
            // directlyTaggedDocs is now derived from @Query allTagAssignments which is
            // reactive natively — no explicit reload needed.
    }

    /// The navigation container. macOS keeps the two-column `NavigationSplitView`; iOS flattens to a
    /// `NavigationStack` (#272 / #238 Fix B): a `NavigationSplitView` nested inside the
    /// `.sidebarAdaptable` TabView is an unsupported composition on iPadOS 26 — the collapsed
    /// floating-top-tab-bar representation mis-computes the detail column's top safe area and overlays
    /// content that can't be scrolled into view. NavigationStack-per-tab is the shape Apple documents
    /// for `.sidebarAdaptable`: the category list is the stack root and the document list is pushed on
    /// selection. The path projects `selectedItem`, so a push sets it (header loading keys on it) and a
    /// pop clears it. Mirrors BrowserView's Fix B.
    @ViewBuilder
    private var navigationContainer: some View {
        #if os(macOS)
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
        .frame(minWidth: 640, minHeight: 480)
        #else
        NavigationStack(path: researchNavigationPath) {
            sidebar
                .navigationDestination(for: ResearchSidebarItem.self) { item in
                    documentList(for: item)
                }
        }
        #endif
    }

    /// A sidebar row that navigates correctly per platform: a `NavigationLink` push in the iOS
    /// `NavigationStack` (#272), a selection `.tag` in the macOS `NavigationSplitView` sidebar.
    @ViewBuilder
    private func sidebarRow<Content: View>(_ item: ResearchSidebarItem,
                                           @ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        NavigationLink(value: item) { content() }
        #else
        content().tag(item)
        #endif
    }

    #if os(iOS)
    /// One-deep navigation path projecting `selectedItem` (#272): a push appends the tapped category
    /// (setting `selectedItem`, which drives header loading); a pop empties the path (clearing it).
    private var researchNavigationPath: Binding<[ResearchSidebarItem]> {
        Binding(get: { selectedItem.map { [$0] } ?? [] },
                set: { selectedItem = $0.last })
    }
    #endif

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            // Synthetic "all notes" entry
            Section {
                sidebarRow(.allNotes) {
                    Label {
                        HStack {
                            Text(String(localized: "research.sidebar.allNotes",
                                        defaultValue: "All Research Documents"))
                            Spacer()
                            Text("\(allAnnotatedDocumentCount)")
                                .font(FRUSTheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "note.text")
                    }
                }
            }

            // Collections sorted alphabetically by name
            if !sortedCollectionsWithCounts.isEmpty {
                Section(String(localized: "research.sidebar.collections", defaultValue: "By Collection")) {
                    ForEach(sortedCollectionsWithCounts, id: \.collection.id) { item in
                        sidebarRow(.collection(item.collection.id)) {
                            Label {
                                HStack {
                                    Text(item.collection.name.isEmpty
                                         ? String(localized: "research.sidebar.collections.untitled",
                                                  defaultValue: "Untitled Collection")
                                         : item.collection.name)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(FRUSTheme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "tray.2")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contextMenu {
                            wordCloudButton(.collection(id: item.collection.id))
                        }
                    }
                }
            }

            // Tags sorted by document count descending
            if !sortedTagsWithCounts.isEmpty {
                Section(String(localized: "research.sidebar.tags", defaultValue: "By Tag")) {
                    ForEach(sortedTagsWithCounts, id: \.tag.id) { item in
                        sidebarRow(.tag(item.tag.id)) {
                            Label {
                                HStack {
                                    Text(item.tag.name)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(FRUSTheme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Text("◆")
                                    .font(FRUSTheme.captionSmallFont)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contextMenu {
                            wordCloudButton(.userTag(id: item.tag.id))
                        }
                    }
                }
            }

            // Highlight colors present in the user's corpus
            if !sortedHighlightColorsWithCounts.isEmpty {
                Section(String(localized: "research.sidebar.highlights",
                               defaultValue: "By Highlight")) {
                    ForEach(sortedHighlightColorsWithCounts, id: \.color) { item in
                        sidebarRow(.highlightColor(item.color)) {
                            Label {
                                HStack {
                                    Text(item.color.displayName)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(FRUSTheme.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Circle()
                                    .fill(item.color.swiftUIColor.opacity(0.75))
                                    .frame(width: 10, height: 10)
                            }
                        }
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
        let emptyDescription: String = {
            switch item {
            case .allNotes:
                return String(localized: "research.empty.noDocs.allNotes",
                              defaultValue: "Research notes, tags, highlights, and collections you add from the document view will appear here.")
            case .tag:
                return String(localized: "research.empty.noDocs.tag",
                              defaultValue: "No documents have notes or tags matching this tag.")
            case .collection:
                return String(localized: "research.empty.noDocs.collection",
                              defaultValue: "This collection has no documents.")
            case .highlightColor:
                return String(localized: "research.empty.noDocs.highlight",
                              defaultValue: "No documents have highlights in this color.")
            }
        }()
        Group {
            if docs.isEmpty {
                ContentUnavailableView(
                    String(localized: "research.empty.noDocs", defaultValue: "No Documents"),
                    systemImage: "note.text",
                    description: Text(emptyDescription)
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
        VStack(alignment: .leading, spacing: 4) {
            // Document header (or fallback to documentId)
            let header = documentHeaders[entry.id]
            if let h = header, !h.isEmpty {
                Text(h)
                    .font(.body)
                    .lineLimit(2)
            } else {
                Text(entry.documentId)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Volume title + most-recent annotation date
            HStack(spacing: 6) {
                let volumeTitle = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title
                Text(volumeTitle ?? entry.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                // Show the date of whichever annotation is newest
                let annotationDate = [
                    entry.latestNote?.lastModified,
                    entry.highlights.first?.createdAt
                ].compactMap { $0 }.max()
                if let date = annotationDate {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Highlight strips — displayed first so the user sees the document's
            // own words before their note commentary. Up to 3 strips; overflow
            // is indicated by a count line.
            if !entry.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(entry.highlights.prefix(3)) { hl in
                        highlightStrip(hl)
                    }
                    if entry.highlights.count > 3 {
                        Text(String(
                            format: String(localized: "research.row.moreHighlights %lld",
                                           defaultValue: "and %lld more"),
                            Int64(entry.highlights.count - 3)
                        ))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 10)
                    }
                }
                .padding(.top, 2)
            }

            // Latest note preview
            if let note = entry.latestNote, !note.bodyText.isEmpty {
                Text(note.bodyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .italic()
            }

            // Footer: tags · note count · collections
            let tagNames = entry.allTagIds
                .compactMap { id in allTags.first(where: { $0.id == id })?.name }
                .sorted()
            let collectionNames = entry.collectionIds
                .compactMap { id in allCollections.first(where: { $0.id == id })?.name }
                .sorted()
            let hasFooter = !tagNames.isEmpty || entry.noteCount > 1 || !collectionNames.isEmpty
            if hasFooter {
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
                    ForEach(collectionNames, id: \.self) { name in
                        HStack(spacing: 2) {
                            Image(systemName: "tray.2")
                            Text(name.isEmpty
                                 ? String(localized: "research.row.untitledCollection",
                                          defaultValue: "Untitled Collection")
                                 : name)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Highlight Strip

    /// A single highlighted passage displayed in a Research document row.
    ///
    /// Shows a narrow color accent bar on the left, the verbatim selected text
    /// (or a placeholder for pre-Session 131 highlights), and a tinted background.
    private func highlightStrip(_ highlight: DocumentHighlight) -> some View {
        let color = highlight.color.swiftUIColor
        return HStack(spacing: 0) {
            Rectangle()
                .fill(color.opacity(0.75))
                .frame(width: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 2, bottomLeadingRadius: 2,
                    bottomTrailingRadius: 0, topTrailingRadius: 0
                ))
            Group {
                if highlight.selectedText.isEmpty {
                    Text(String(localized: "research.highlight.noText",
                                defaultValue: "Highlighted passage"))
                        .italic()
                        .foregroundStyle(.tertiary)
                } else {
                    Text(highlight.selectedText)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .lineLimit(2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Word Cloud

    /// A context-menu button that opens a word cloud for the given scope.
    @ViewBuilder
    private func wordCloudButton(_ scope: WordCloudScope) -> some View {
        Button {
            appState.pendingWordCloud = scope
        } label: {
            Label { Text(String(localized: "research.wordCloud", defaultValue: "Word Cloud")) }
                icon: { Image(systemName: WordCloudGlyph.symbol) }
        }
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

    /// Doc key → Set of Collection IDs the document belongs to, derived from `allCollectionEntries`.
    private var collectionMemberships: [String: Set<UUID>] {
        var result: [String: Set<UUID>] = [:]
        for entry in allCollectionEntries {
            guard !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { continue }
            result["\(entry.volumeId)/\(entry.documentId)", default: []].insert(entry.collectionId)
        }
        return result
    }

    /// Collections paired with their document count, sorted alphabetically.
    /// Filters out smart collections (savedSearchId != nil) and empty collections.
    private var sortedCollectionsWithCounts: [(collection: Collection, count: Int)] {
        allCollections.compactMap { collection in
            // Exclude smart collections — their document list is dynamic, not curated entries.
            guard collection.savedSearchId == nil else { return nil }
            let count = (collection.documentEntries ?? []).count
            guard count > 0 else { return nil }
            return (collection: collection, count: count)
        }
        .sorted {
            $0.collection.name.localizedCaseInsensitiveCompare($1.collection.name) == .orderedAscending
        }
    }

    /// Total distinct documents across all four annotation sources.
    private var allAnnotatedDocumentCount: Int {
        Set(allNotes.map { "\($0.volumeId)/\($0.documentId)" })
            .union(directlyTaggedDocs.keys)
            .union(collectionMemberships.keys)
            .union(highlightedDocs.keys)
            .count
    }

    /// Tags paired with their distinct-document count (notes + direct tags), sorted most-used first.
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

    /// Doc key → highlights array (newest-first), built from `allHighlights`.
    private var highlightedDocs: [String: [DocumentHighlight]] {
        var result: [String: [DocumentHighlight]] = [:]
        for h in allHighlights {
            let key = "\(h.volumeId)/\(h.documentId)"
            result[key, default: []].append(h)
        }
        return result
    }

    /// Highlight colors that have at least one document, paired with distinct-document
    /// count, in the canonical order: yellow, green, blue, pink.
    private var sortedHighlightColorsWithCounts: [(color: DocumentHighlight.Color, count: Int)] {
        DocumentHighlight.Color.allCases.compactMap { color in
            let docs = Set(
                allHighlights
                    .filter { $0.color == color }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
            return docs.isEmpty ? nil : (color: color, count: docs.count)
        }
    }

    /// Aggregates all four annotation sources by document for the given sidebar item.
    ///
    /// - `.allNotes`: union of notes, direct tags, collection entries, and highlights
    /// - `.tag(id)`: documents whose notes or direct assignments carry this tag
    /// - `.collection(id)`: documents in this specific collection
    /// - `.highlightColor(color)`: documents with at least one highlight of this color
    ///
    /// Documents with no notes have `latestNote == nil`. Sorted by newest annotation
    /// date (considering both `lastModified` of notes and `createdAt` of highlights).
    private func documents(for item: ResearchSidebarItem) -> [ResearchDocumentEntry] {
        let matchingKeys: Set<String>
        switch item {
        case .allNotes:
            matchingKeys = Set(allNotes.map { "\($0.volumeId)/\($0.documentId)" })
                .union(directlyTaggedDocs.keys)
                .union(collectionMemberships.keys)
                .union(highlightedDocs.keys)
        case .tag(let id):
            let fromNotes  = Set(allNotes.filter { $0.userTagIds.contains(id) }
                                         .map { "\($0.volumeId)/\($0.documentId)" })
            let fromDirect = Set(directlyTaggedDocs.filter { $0.value.contains(id) }.map(\.key))
            matchingKeys = fromNotes.union(fromDirect)
        case .collection(let collId):
            matchingKeys = Set(collectionMemberships.filter { $0.value.contains(collId) }.map(\.key))
        case .highlightColor(let color):
            matchingKeys = Set(
                allHighlights
                    .filter { $0.color == color }
                    .map { "\($0.volumeId)/\($0.documentId)" }
            )
        }

        // Seed the grouped notes dictionary.
        var grouped: [String: [ResearchNote]] = [:]
        for key in matchingKeys { grouped[key] = [] }
        for note in allNotes {
            let key = "\(note.volumeId)/\(note.documentId)"
            if matchingKeys.contains(key) {
                grouped[key, default: []].append(note)
            }
        }

        return grouped.compactMap { key, notes -> ResearchDocumentEntry? in
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }

            let sortedNotes  = notes.sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
            let directTagIds = Set(directlyTaggedDocs[key] ?? [])
            let noteTagIds   = Set(notes.flatMap { $0.userTagIds })
            let colIds       = collectionMemberships[key] ?? []
            let docHighlights = (highlightedDocs[key] ?? [])
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }

            return ResearchDocumentEntry(
                id: key,
                volumeId: parts[0],
                documentId: parts[1],
                latestNote: sortedNotes.first,
                noteCount: notes.count,
                allTagIds: noteTagIds.union(directTagIds),
                collectionIds: colIds,
                highlights: docHighlights
            )
        }
        .sorted { lhs, rhs in
            // Sort by the most recent annotation of any type.
            let lhsDate = [lhs.latestNote?.lastModified,
                           lhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast
            let rhsDate = [rhs.latestNote?.lastModified,
                           rhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    /// Navigation title for the document list column.
    private func listTitle(for item: ResearchSidebarItem) -> String {
        switch item {
        case .allNotes:
            return String(localized: "research.sidebar.allNotes",
                          defaultValue: "All Research Documents")
        case .tag(let id):
            return allTags.first(where: { $0.id == id })?.name
                ?? String(localized: "research.list.unknownTag", defaultValue: "Tag")
        case .collection(let id):
            let name = allCollections.first(where: { $0.id == id })?.name ?? ""
            return name.isEmpty
                ? String(localized: "research.list.untitledCollection",
                         defaultValue: "Untitled Collection")
                : name
        case .highlightColor(let color):
            return color.displayName + " " + String(localized: "research.list.highlights",
                                                    defaultValue: "Highlights")
        }
    }
}
