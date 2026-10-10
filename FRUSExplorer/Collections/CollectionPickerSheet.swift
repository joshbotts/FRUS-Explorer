// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionPickerSheet

/// Sheet that adds a document (or a frozen selection excerpt) to an existing collection,
/// or creates a new one.
///
/// Presents a searchable list of all collections. Tapping a row adds the document as a new
/// `CollectionEntry` at the end of that collection and dismisses the sheet; the "New Collection"
/// button opens `CollectionEditorView`. When `excerpt` is non-nil the picker runs in excerpt mode
/// (Authoring Phase 5) and freezes the capture into a `.excerpt` entry instead (no duplicate guard).
///
/// ## Platform layout
/// One shared struct, two platform bodies (Research-rail Phase C1 unified the former macOS
/// `CollectionPickerSheet` and iOS `CollectionPickerSheetView` twins). On macOS a plain `VStack`
/// with an inline search `TextField` + explicit button bar (a `NavigationStack { List }` inside a
/// macOS sheet collapses into an empty-detail sidebar). On iOS a `NavigationStack` with
/// `.searchable`, inset-grouped list, inline title, and medium/large presentation detents.
///
/// Version history:
///   1.0 — Session 35+: initial macOS implementation
///   1.1 — Session 129: split macOS / iOS bodies (NavigationStack sidebar fix)
///   1.2 — Authoring Phase 5 (excerpts): optional `excerpt` capture → `.excerpt` entry
///   1.3 — Research-rail Phase C1: the two per-platform twins unified into this one shared
///          cross-platform struct; the document-count row now counts only `.document`
///          entries (D5), so co-provenanced excerpts don't inflate the membership count.
///   1.4 — The document branch attaches its entry through
///          `CollectionDocumentDiscovery.appendToCollection` (the inverse assignment) instead
///          of `collection.documentEntries?.append`, which is a silent no-op — and leaves the
///          entry permanently orphaned — on a collection that has not been saved since it was
///          inserted. The excerpt branch already did this via `CollectionExcerpts`.
///   1.5 — 2026-09-23: #1358 — the row's count reads `Collection.documentCount`, the same
///          `.document`-entries rule it applied inline, now shared with the Collections list
///          and the macOS manager, which had never applied it
///   1.6 — 2026-09-24: #1359 review, round 2 — the row prints `CollectionEditorNaming.listName`,
///          so a new collection whose editor waits in the Collections tab reads "Untitled
///          Collection" rather than a blank row
///   1.7 — 2026-10-09: #1593 — a smart collection's row says what it is and takes no tap
///          (`CollectionPickerRow`). The picker had accepted the document and confirmed "Added",
///          though a smart collection's preview, exports and Archives Visit list come from its
///          saved search and never showed it
///   1.8 — #1576 lane 2: documents mode (`init(documents:fromMeaningSearch:)`), for a command
///          chosen on search results. It adds through
///          `CollectionDocumentDiscovery.appendDocuments`, which skips what the collection holds
///          and saves; the title carries the count past one; a list from a Meaning search shows
///          the model's chip beside the volumes'; a failed add is said in an alert. The two
///          older modes keep their initialiser's shape, so no caller changed. In every mode a
///          row now takes a tap anywhere on it (it took one only on its name and caption), the
///          list keeps the order it opened in, and a presentation adds once
struct CollectionPickerSheet: View {

    /// The document being added (its `volumeId`/`documentId` provenance), in the single-document
    /// and excerpt modes; `nil` in documents mode.
    let entry: DocumentBrowserEntry?

    /// When non-nil, the picker runs in excerpt mode: the chosen collection receives this capture
    /// as a `.excerpt` entry rather than the document.
    let excerpt: CollectionExcerptCapture?

    /// Documents mode (#1576 lane 2): the documents a command on search results adds, frozen when
    /// the command was chosen and in the order they were on screen. `nil` in the other two modes.
    let documents: [CollectionDocumentRef]?

    /// Whether `documents` came from a Meaning search's results: the documents are the volumes',
    /// and that these are the ones listed is this app's model's doing (#1576, decision 6).
    let fromMeaningSearch: Bool

    /// The picker for one document, or for an excerpt of it.
    ///
    /// - Parameters:
    ///   - entry: The document.
    ///   - excerpt: A capture to add as a `.excerpt` entry in place of the document, or `nil`.
    init(entry: DocumentBrowserEntry, excerpt: CollectionExcerptCapture? = nil) {
        self.entry = entry
        self.excerpt = excerpt
        self.documents = nil
        self.fromMeaningSearch = false
    }

    /// The picker in documents mode (#1576 lane 2): the chosen collection takes every document it
    /// does not already hold.
    ///
    /// - Parameters:
    ///   - documents: The documents to add, already frozen by the caller.
    ///   - fromMeaningSearch: Whether a Meaning search listed them.
    init(documents: [CollectionDocumentRef], fromMeaningSearch: Bool = false) {
        self.entry = nil
        self.excerpt = nil
        self.documents = documents
        self.fromMeaningSearch = fromMeaningSearch
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Collection.lastModified, order: .reverse) private var collections: [Collection]

    @State private var searchText: String = ""
    @State private var showNewCollection = false
    @State private var addedCollectionId: UUID? = nil
    /// Why a documents-mode add wrote nothing or could not be saved, while its alert is up.
    @State private var addFailure: String? = nil
    /// The collections' ids in the order the sheet opened with (#1576 lane 2), or `nil` before
    /// its first appearance. See ``ordered``.
    @State private var orderAtOpen: [UUID]? = nil

    /// The collections in the order the sheet opened with, most recently modified first, with any
    /// made since (the New Collection button) ahead of them.
    ///
    /// The query's own order is live, and an add changes it: documents mode stamps the
    /// collection it adds to, so the tapped row would leave for the top of the list at the tap,
    /// taking its checkmark out of sight on a long list and putting another collection under the
    /// reader's finger.
    private var ordered: [Collection] {
        CollectionPickerOrder.held(collections, id: \.id, listed: orderAtOpen)
    }

    /// The collections the search lists: each whose row's name — not its raw saved name — holds the text (#1464).
    private var filtered: [Collection] {
        guard !searchText.isEmpty else { return ordered }
        return ordered.filter {
            CollectionEditorNaming.listNameMatches(savedName: $0.name, searchText: searchText)
        }
    }

    /// The sheet title: names the excerpt mode when active, and in documents mode the count.
    private var pickerTitle: String {
        if let documents { return CollectionPickerCopy.documentsTitle(count: documents.count) }
        return excerpt == nil
            ? CollectionPickerCopy.title
            : String(localized: "collection.picker.title.excerpt",
                     defaultValue: "Add Excerpt to Collection")
    }

    var body: some View {
        platformBody
            .onAppear {
                if orderAtOpen == nil { orderAtOpen = collections.map(\.id) }
            }
            // Documents mode's add can be refused, and its save can fail (#1576 lane 2). One
            // alert on the body, so that neither platform's layout carries a line for it.
            .alert(CollectionPickerCopy.addFailedTitle,
                   isPresented: Binding(get: { addFailure != nil },
                                        set: { if !$0 { addFailure = nil } })) {
                Button(String(localized: "collection.picker.addFailed.ok", defaultValue: "OK")) {
                    addFailure = nil
                }
            } message: {
                Text(addFailure ?? "")
            }
    }

    @ViewBuilder
    private var platformBody: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Shared collection row

    /// One collection row: name + document count + an added checkmark. The count is restricted to
    /// `.document` entries (D5) so excerpt/heading/prose/generated entries co-provenanced to this
    /// document don't inflate the collection's document total.
    private func collectionRow(_ collection: Collection) -> some View {
        let row = CollectionPickerRow(collection)
        return Button {
            addDocument(to: collection)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.body)
                        // A plain button does not dim its own label when it is disabled.
                        .foregroundStyle(row.takesEntries ? .primary : .secondary)
                    Text(row.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if addedCollectionId == collection.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(String(localized: "collection.picker.added.a11y",
                                                   defaultValue: "Added"))
                }
            }
            // The whole row takes the tap (#1576 lane 2). A plain button is hit only where its
            // label draws, and between the name and the trailing edge this one draws nothing:
            // a tap there did nothing, which on an iPad's wide sheet is most of the row.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // #1593: a smart collection is listed, so it can be found, and takes no tap. Its caption
        // says why.
        .disabled(!row.takesEntries)
        // No explicit label override: let the button announce name + document count together (the
        // count is meaningful post-D5), plus the "Added" checkmark when present (C1a review F2).
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(pickerTitle)
                    .font(.headline)
                // **In the sheet's chrome, not in a row and not after the tap** (wave PV-4). This
                // is the moment a screen becomes a claim: the reader is about to put something
                // into a collection they will later export, and PV-1 gives that export a colophon
                // naming its sources. Saying it here means the two agree, and it must be readable
                // from presentation until dismissal rather than appearing as confirmation.
                //
                // `.frusText` is not conditional, because what is captured is always FRUS's: the
                // entry is a FRUS document, an excerpt is a frozen span of that document's own
                // text (`CollectionExcerptCapture` stores offsets into it), and documents mode
                // adds documents. What documents mode can add to the claim is WHICH documents: a
                // list a Meaning search made is the model's grouping, so its chip joins this one
                // (#1576, decision 6).
                ProvenanceChip(source: .frusText)
                if fromMeaningSearch { ProvenanceChip(source: .appModel) }
                Spacer()
                Button {
                    showNewCollection = true
                } label: {
                    Label(String(localized: "collection.picker.newCollection",
                                 defaultValue: "New Collection"),
                          systemImage: "folder.badge.plus")
                }
                .labelStyle(.iconOnly)
                .help(String(localized: "collection.picker.newCollection.help",
                             defaultValue: "Create a new collection"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Inline search field
            if !collections.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "collection.picker.search.placeholder",
                                     defaultValue: "Search collections…"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()

            // Collection list or empty state
            if collections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(String(localized: "collection.picker.empty",
                                defaultValue: "No Collections"))
                        .font(.headline)
                    Text(String(localized: "collection.picker.empty.hint",
                                defaultValue: "Use the button above to create one."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(String(localized: "collection.picker.noResults",
                                defaultValue: "No collections match “\(searchText)”."))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(filtered) { collection in
                    collectionRow(collection)
                }
                .listStyle(.inset)
            }

            Divider()

            // Button bar
            HStack {
                Spacer()
                Button(String(localized: "collection.picker.cancel",
                              defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 380, minHeight: 340)
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }
    #endif

    // MARK: - iOS Body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        String(localized: "collection.picker.empty.title",
                               defaultValue: "No Collections"),
                        systemImage: "folder",
                        description: Text(
                            String(localized: "collection.picker.empty.detail",
                                   defaultValue: "Create a collection using the button above.")
                        )
                    )
                } else {
                    List(filtered) { collection in
                        collectionRow(collection)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        prompt: String(localized: "collection.picker.search.prompt",
                                       defaultValue: "Search collections")
                    )
                }
            }
            .safeAreaInset(edge: .top) {
                // The iOS twin of the macOS title-bar chip. It cannot go in the navigation title —
                // that slot is a `String` — and a toolbar item would compete with Cancel and the
                // inline title, so it rides directly under the bar where it is visible for the
                // life of the sheet. `.safeAreaInset(edge: .top)` INSIDE the `NavigationStack`,
                // which is the placement that composites under the bar rather than over it (#486).
                HStack {
                    ProvenanceChip(source: .frusText)
                    // #1576, decision 6: see the macOS title bar's note.
                    if fromMeaningSearch { ProvenanceChip(source: .appModel) }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.bar)
            }
            .navigationTitle(pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.picker.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewCollection = true
                    } label: {
                        Label(
                            String(localized: "collection.picker.newCollection",
                                   defaultValue: "New Collection"),
                            systemImage: "folder.badge.plus"
                        )
                    }
                    .accessibilityLabel(
                        String(localized: "collection.picker.newCollection.a11y",
                               defaultValue: "Create a new collection")
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }
    #endif

    // MARK: - Add action

    private func addDocument(to collection: Collection) {
        // #1593: a smart collection's contents are its saved search's results, so an entry added
        // here would be counted, listed in its outline and left out of everything it produces.
        // The row is disabled; this holds the rule for any caller that is not the row.
        guard CollectionPickerRow(collection).takesEntries else { return }
        // One add to a presentation, in every mode. The sheet closes itself a moment after a
        // tap; until it has, a second tap is on a row the reader did not choose it for.
        guard addedCollectionId == nil else { return }

        // Documents mode (#1576 lane 2): the frozen list a command on search results carries.
        if let documents {
            addDocuments(documents, to: collection)
            return
        }
        guard let entry else { return }

        // Excerpt mode (Authoring Phase 5): freeze the capture into a `.excerpt` entry.
        // No duplicate guard — several excerpts from one document are expected.
        if let excerpt {
            CollectionExcerpts.appendToCollection(excerpt, collection: collection,
                                                  modelContext: modelContext)
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            return
        }

        // Guard against duplicates — show checkmark and dismiss if already a member. Match only
        // `.document` entries: an *excerpt* from this document carries the same provenance
        // (volumeId/documentId), so without the kind filter a prior excerpt would spuriously block
        // adding the document itself — leaving the collection with "0 documents" (C1a review F1).
        let existing = collection.documentEntries ?? []
        guard !existing.contains(where: {
            $0.entryKind == .document
                && $0.documentId == entry.documentId && $0.volumeId == entry.volumeId
        }) else {
            addedCollectionId = collection.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
            return
        }

        // Through the shared factory, which links the entry by assigning the INVERSE. Appending
        // to `collection.documentEntries` — what this line used to do — is a silent no-op on a
        // collection whose relationship is still `nil`, which is every collection that has not
        // been saved since it was inserted: including one this very sheet's "New Collection"
        // button created moments ago. The entry then carries only `collectionId` and is orphaned
        // permanently. See `CollectionDocumentDiscovery.appendToCollection` for the measurement.
        CollectionDocumentDiscovery.appendToCollection(
            documentId: entry.documentId,
            volumeId: entry.volumeId,
            collection: collection,
            modelContext: modelContext
        )

        addedCollectionId = collection.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }

    /// Documents mode's add (#1576 lane 2): every document the collection does not hold, in the
    /// order given, saved before the sheet says so.
    ///
    /// The row's checkmark is the confirmation, as it is for one document, and the sheet leaves
    /// after the same pause: a little longer when every document was there already, which is
    /// the pause the single-document add gives a duplicate.
    private func addDocuments(_ documents: [CollectionDocumentRef], to collection: Collection) {
        do {
            let outcome = try CollectionDocumentDiscovery.appendDocuments(
                documents, to: collection, modelContext: modelContext)
            addedCollectionId = collection.id
            let pause = outcome.insertedCount == 0 ? 0.8 : 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + pause) { dismiss() }
        } catch {
            // Said, and the sheet stays: the reader can pick another collection or cancel.
            addFailure = CollectionPickerCopy.addFailure(error)
        }
    }
}

// MARK: - CollectionPickerCopy

/// The picker's words that a rule chooses, apart from the view so that a test can read them off
/// the main actor (#1576 lane 2).
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
enum CollectionPickerCopy {

    /// The picker's title for one document.
    static var title: String {
        String(localized: "collection.picker.nav.title", defaultValue: "Add to Collection")
    }

    /// The picker's title in documents mode: "Add to Collection" for one document, which is what
    /// the document's own picker says, and "Add 37 Documents to Collection" for several.
    ///
    /// - Parameters:
    ///   - count: The documents the command carries.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The title.
    static func documentsTitle(count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        // The singular form is the plain title, which has no place for a count: one document
        // reads here as it does in the document's own picker.
        CountCopy.phrase(
            count,
            one: title,
            many: String(localized: "collection.picker.title.documents.many",
                         defaultValue: "Add %@ Documents to Collection"),
            locale: locale)
    }

    /// The title of the alert a failed documents-mode add shows.
    static var addFailedTitle: String {
        String(localized: "collection.picker.addFailed.title", defaultValue: "Not Added")
    }

    /// What a failed documents-mode add says.
    ///
    /// - Parameters:
    ///   - error: What `CollectionDocumentDiscovery.appendDocuments` threw.
    ///   - locale: The locale that groups the counts; the user's own unless a test passes one.
    /// - Returns: The alert's message.
    static func addFailure(_ error: any Error, locale: Locale = .autoupdatingCurrent) -> String {
        switch error as? CollectionDocumentAppendRefusal {
        case .smartCollection:
            return String(localized: "collection.picker.addFailed.smart",
                          defaultValue: "This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.")
        case .overLimit(let count, let limit):
            return String(format: String(
                localized: "collection.picker.addFailed.overLimit %@ %@",
                defaultValue: "A collection takes up to %2$@ at a time, and %1$@ were chosen."),
                CountCopy.documents(count, locale: locale),
                CountCopy.documents(limit, locale: locale))
        case nil:
            return String(format: String(
                localized: "collection.picker.addFailed.save %@",
                defaultValue: "The collection could not be saved, so nothing was added. %@"),
                error.localizedDescription)
        }
    }
}

// MARK: - CollectionPickerOrder

/// The order the picker lists its collections in while it is open (#1576 lane 2).
///
/// A value apart from the view so that a test can run it: the view hands it the query's results
/// and the ids it opened with.
///
/// Version history:
///   1.0 — #1576 lane 2: initial implementation
enum CollectionPickerOrder {

    /// `items` in the order `listed` names them, with any `listed` does not name ahead of those,
    /// in the order given.
    ///
    /// - Parameters:
    ///   - items: The collections now, in the query's live order.
    ///   - id: An item's identifier.
    ///   - listed: The identifiers in the order the sheet opened with, or `nil` before it has
    ///     appeared, when the live order is the answer.
    /// - Returns: The items, each once, in the held order.
    static func held<Item>(_ items: [Item], id: (Item) -> UUID, listed: [UUID]?) -> [Item] {
        guard let listed else { return items }
        let place = Dictionary(listed.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var known: [(place: Int, item: Item)] = []
        var new: [Item] = []
        for item in items {
            if let at = place[id(item)] { known.append((at, item)) } else { new.append(item) }
        }
        // Stable: two items cannot share a place, since each id has one.
        return new + known.sorted { $0.place < $1.place }.map(\.item)
    }
}

// MARK: - CollectionPickerRow

/// What one row of the Add to Collection picker says, and whether it takes the document or
/// excerpt (#1593).
///
/// A collection linked to a saved search is a smart collection: its preview, every export, its
/// Archives Visit list and its static snapshot are built from the search's results
/// (`CollectionContentResolver`, `Collection.savedSearchId`), and its hand-added entries are
/// ignored there. The picker listed one like any other, under a count of those ignored entries
/// ("0 documents" for a search that returns hundreds), took the tap and showed the green Added
/// checkmark. So the row says what the collection is, and takes no tap.
///
/// A value type apart from the view so that a test asks it which rows accept: the view's row is
/// `.disabled(!row.takesEntries)` and `addDocument(to:)` returns early on the same answer.
///
/// Version history:
///   1.0 — 2026-10-09: #1593 — initial implementation
struct CollectionPickerRow: Equatable {

    /// The row's title: the name the Collections list shows.
    let name: String
    /// The line under it: the document count, or what a smart collection is.
    let caption: String
    /// Whether tapping the row adds the document or excerpt. `false` for a smart collection.
    let takesEntries: Bool

    /// The row for `collection`.
    ///
    /// - Parameter collection: A collection the picker lists.
    init(_ collection: Collection) {
        self.init(savedName: collection.name, documentCount: collection.documentCount,
                  isSmart: collection.savedSearchId != nil)
    }

    /// The row for a collection's three facts.
    ///
    /// - Parameters:
    ///   - savedName: The collection's stored name; an empty one reads "Untitled Collection".
    ///   - documentCount: Its `.document` entries (`Collection.documentCount`).
    ///   - isSmart: Whether it is linked to a saved search.
    init(savedName: String, documentCount: Int, isSmart: Bool) {
        name = CollectionEditorNaming.listName(savedName: savedName)
        takesEntries = !isSmart
        caption = isSmart
            ? String(localized: "collection.picker.smart",
                     defaultValue: "Smart collection. Its documents come from its saved search.")
            : String(localized: "collection.picker.docCount",
                     defaultValue: "\(documentCount) document\(documentCount == 1 ? "" : "s")")
    }
}
