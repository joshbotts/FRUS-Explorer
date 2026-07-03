// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - CollectionExcerptCapture

/// The value snapshot every excerpt creation path produces (Authoring Phase 5): the
/// frozen verbatim passage, its provenance, and whatever anchoring metadata the source
/// exposed. Three paths build one of these — a `DocumentHighlight` (full anchors + colour),
/// the document view's live text selection (offsets + renderingVersion when the selection
/// is in-document, text-only otherwise), and the entry inspector's highlight rows — and
/// all three funnel into `CollectionExcerpts.makeEntry`, so field copying exists once.
///
/// ## The capture contract (all creation paths, both platforms)
/// When flat-text offsets exist, `text` is re-extracted from the render model with
/// `flatTextExcerpt(from:start:end:)` — block-aware, so paragraph breaks survive as
/// `"\n\n"` (the renderers' paragraph separator) and `data-skip` content the offsets
/// exclude (footnote-marker digits, figure captions) never enters the passage. The
/// offsets are pure flat-space anchors: they delimit the flat-text *span*, not the
/// stored string (which contains separators the flat text does not); a future A9
/// precision-rendering flip must resolve them through `renderingVersion`, never by
/// slicing the stored text. Offset-less captures (footnote selections) freeze the raw
/// selection text with `nil` anchors.
///
/// Version history:
///   1.0 — Authoring Phase 5 (excerpts): initial implementation
///   1.1 — Authoring Phase 5 review fixes: block-aware capture contract documented
struct CollectionExcerptCapture: Sendable, Equatable {
    /// The frozen verbatim passage — the excerpt's rendering source of truth (A9).
    let text: String
    /// The source volume identifier (provenance).
    let volumeId: String
    /// The source FRUS document identifier (provenance).
    let documentId: String
    /// Unicode-scalar start offset in the source document's flat text, when the source
    /// exposed offsets (`DocumentHighlight.startOffset` coordinate space); else `nil`.
    let start: Int?
    /// Unicode-scalar end offset (exclusive), when available; else `nil`.
    let end: Int?
    /// The source document's `renderingVersion` at capture, when available; else `nil`.
    let renderingVersion: String?
    /// The source highlight's colour raw value, when captured from a highlight; else `nil`.
    let colorTag: String?
}

// MARK: - CollectionExcerpts

/// The single excerpt-entry factory (Authoring Phase 5): turns captures into `.excerpt`
/// `CollectionEntry` records. Pure field copying lives here so every creation path —
/// bulk "Add Highlighted Passages", the document view's selection action, and the
/// inspector's per-highlight insert — freezes exactly the same fields.
///
/// Serialization note: entries reference their source only by content + provenance +
/// anchors. The source highlight's device-local UUID is deliberately never stored.
///
/// Version history:
///   1.0 — Authoring Phase 5 (excerpts): initial implementation
enum CollectionExcerpts {

    /// Builds a capture from a stored highlight, copying the verbatim passage, offsets,
    /// rendering version, and colour.
    ///
    /// - Parameter highlight: The source `DocumentHighlight`.
    /// - Returns: The capture, or `nil` when the highlight has no `selectedText`
    ///   (pre-Session-131 highlights) — there is no passage to freeze, so no excerpt
    ///   can be made from it.
    @MainActor
    static func capture(from highlight: DocumentHighlight) -> CollectionExcerptCapture? {
        guard !highlight.selectedText.isEmpty else { return nil }
        return CollectionExcerptCapture(
            text: highlight.selectedText,
            volumeId: highlight.volumeId,
            documentId: highlight.documentId,
            start: highlight.startOffset,
            end: highlight.endOffset,
            renderingVersion: highlight.renderingVersion.isEmpty
                ? nil : highlight.renderingVersion,
            colorTag: highlight.colorTag)
    }

    /// Creates an `.excerpt` entry from a capture: `text` = the frozen passage,
    /// `documentId`/`volumeId` = provenance, and the anchor fields copied verbatim.
    /// The caller inserts the entry into a context and links `entry.collection`.
    ///
    /// - Parameters:
    ///   - capture: The excerpt capture to freeze into an entry.
    ///   - collectionId: The owning collection's id.
    ///   - sortOrder: The entry's position within the collection.
    /// - Returns: The new (not yet inserted) entry.
    @MainActor
    static func makeEntry(
        from capture: CollectionExcerptCapture,
        collectionId: UUID,
        sortOrder: Int
    ) -> CollectionEntry {
        let entry = CollectionEntry(
            collectionId: collectionId,
            documentId: capture.documentId,
            volumeId: capture.volumeId,
            sortOrder: sortOrder)
        entry.entryKind = .excerpt
        entry.text = capture.text
        entry.excerptStart = capture.start
        entry.excerptEnd = capture.end
        entry.excerptRenderingVersion = capture.renderingVersion
        entry.excerptColorTag = capture.colorTag
        return entry
    }

    /// Appends excerpt entries for `captures` at the end of `sortedEntries` in the
    /// given order, inserting each into `modelContext` — the excerpt sibling of
    /// `CollectionDocumentDiscovery.appendEntries`, sharing its end-of-list semantics.
    ///
    /// - Parameters:
    ///   - captures: The excerpt captures, in insertion order.
    ///   - collection: The owning collection.
    ///   - sortedEntries: The editor's pane-level entry array, appended in place.
    ///   - modelContext: The SwiftData context the new entries are inserted into.
    @MainActor
    static func append(
        _ captures: [CollectionExcerptCapture],
        to collection: Collection,
        sortedEntries: inout [CollectionEntry],
        modelContext: ModelContext
    ) {
        var next = sortedEntries.count
        for capture in captures {
            let entry = makeEntry(from: capture, collectionId: collection.id, sortOrder: next)
            entry.collection = collection
            modelContext.insert(entry)
            sortedEntries.append(entry)
            next += 1
        }
    }

    /// Appends a single excerpt entry at the end of a collection **without** a
    /// pane-level entries array — the path used by the document-view picker and the
    /// entry inspector, which mutate the collection directly. The new entry's
    /// `sortOrder` is `max + 1`, so no existing entry is renumbered.
    ///
    /// - Parameters:
    ///   - capture: The excerpt capture to append.
    ///   - collection: The target collection.
    ///   - modelContext: The SwiftData context the new entry is inserted into.
    /// - Returns: The inserted entry (so callers can surface or select it).
    @MainActor
    @discardableResult
    static func appendToCollection(
        _ capture: CollectionExcerptCapture,
        collection: Collection,
        modelContext: ModelContext
    ) -> CollectionEntry {
        let nextOrder = ((collection.documentEntries ?? []).map(\.sortOrder).max() ?? -1) + 1
        let entry = makeEntry(from: capture, collectionId: collection.id, sortOrder: nextOrder)
        entry.collection = collection
        modelContext.insert(entry)
        collection.documentEntries?.append(entry)
        return entry
    }
}

// MARK: - CollectionAddHighlightsSheet

/// Bulk excerpt creation (Authoring Phase 5, creation path a): lists the user's
/// highlighted passages from the documents already in the collection, with multi-select
/// insert. Selected passages become `.excerpt` entries appended at the end of the entry
/// list in list order.
///
/// **Why the editors' add menu (not the Add Documents sheet).** The add menu is the
/// established home for inserting non-document entries (headings, note blocks) — an
/// excerpt is exactly that: a structural entry, not a document membership. The Add
/// Documents sheet's contract is document *discovery* (its selection is
/// `CollectionDocumentPick`s that become `.document` entries), so grafting an excerpt
/// tab onto it would conflate two different insert semantics. Scoping the list to the
/// collection's own documents keeps the sheet simple and the offering relevant; a
/// passage from an outside document is added from that document's view (creation path b).
///
/// Highlights with no stored `selectedText` (pre-Session-131) are omitted — there is no
/// passage to freeze.
///
/// Version history:
///   1.0 — Authoring Phase 5 (excerpts): initial implementation
struct CollectionAddHighlightsSheet: View {

    /// One offered highlight row: the source highlight's capture plus display metadata.
    private struct HighlightRow: Identifiable {
        /// The source highlight's id — row identity and selection key only,
        /// never serialized onto the created entry.
        let id: UUID
        /// The ready-to-insert capture.
        let capture: CollectionExcerptCapture
        /// The grouping label (indexed document header, else the document id).
        let documentLabel: String
    }

    /// Document keys (`"volumeId/documentId"`) of the collection's document entries,
    /// in collection order — scopes and orders the offered highlights.
    let documentKeys: [String]

    /// Display labels per document key (the editors' indexed-header map); missing keys
    /// fall back to the raw document id.
    let documentLabels: [String: String]

    /// Receives the selected captures, in list order, when the user confirms.
    let onInsert: ([CollectionExcerptCapture]) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Every highlight in the store, newest last (stable, matches creation order).
    @Query(sort: \DocumentHighlight.createdAt) private var allHighlights: [DocumentHighlight]

    /// Ids of the highlights the user has ticked.
    @State private var selectedIds: Set<UUID> = []

    /// The offered rows: highlights on the collection's documents, with text, grouped
    /// in collection-document order.
    private var rows: [HighlightRow] {
        let keyOrder = Dictionary(uniqueKeysWithValues:
            documentKeys.enumerated().map { ($1, $0) })
        return allHighlights
            .compactMap { highlight -> (order: Int, row: HighlightRow)? in
                let key = "\(highlight.volumeId)/\(highlight.documentId)"
                guard let order = keyOrder[key],
                      let capture = CollectionExcerpts.capture(from: highlight) else {
                    return nil
                }
                return (order, HighlightRow(
                    id: highlight.id,
                    capture: capture,
                    documentLabel: documentLabels[key] ?? highlight.documentId))
            }
            .sorted { $0.order < $1.order }
            .map(\.row)
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Shared pieces

    /// The multi-select list of highlight rows (or the empty state).
    @ViewBuilder
    private var rowList: some View {
        let offered = rows
        if offered.isEmpty {
            ContentUnavailableView(
                String(localized: "collection.addHighlights.empty.title",
                       defaultValue: "No Highlighted Passages"),
                systemImage: "highlighter",
                description: Text(String(localized: "collection.addHighlights.empty.detail",
                                         defaultValue: "Highlight passages in this collection's documents to insert them here as excerpts."))
            )
        } else {
            List(offered) { row in
                Toggle(isOn: Binding(
                    get: { selectedIds.contains(row.id) },
                    set: { on in
                        if on { selectedIds.insert(row.id) } else { selectedIds.remove(row.id) }
                    }
                )) {
                    HStack(alignment: .top, spacing: 8) {
                        if let color = DocumentHighlight.Color(rawValue: row.capture.colorTag ?? "") {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)
                                .accessibilityLabel(color.displayName)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.capture.text)
                                .font(.callout)
                                .lineLimit(3)
                            Text(row.documentLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
            }
        }
    }

    /// Inserts the current selection (list order preserved) and dismisses.
    private func insertSelection() {
        let captures = rows.filter { selectedIds.contains($0.id) }.map(\.capture)
        guard !captures.isEmpty else { return }
        onInsert(captures)
        dismiss()
    }

    /// The localized Insert button title, carrying the selection count.
    private var insertTitle: String {
        String(localized: "collection.addHighlights.insert",
               defaultValue: "Insert \(selectedIds.count) Excerpt\(selectedIds.count == 1 ? "" : "s")")
    }

    // MARK: - macOS body

    #if os(macOS)
    /// macOS layout: plain VStack + button bar (a `NavigationStack { List }` inside a
    /// macOS sheet renders as a collapsed split-column — the house sheet pattern).
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "collection.addHighlights.title",
                            defaultValue: "Add Highlighted Passages"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            rowList

            Divider()

            HStack {
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(insertTitle) { insertSelection() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 360)
    }
    #endif

    // MARK: - iOS body

    /// iOS layout: NavigationStack with inline title and Cancel / Insert toolbar buttons.
    private var iOSBody: some View {
        NavigationStack {
            rowList
                .navigationTitle(String(localized: "collection.addHighlights.title",
                                        defaultValue: "Add Highlighted Passages"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(insertTitle) { insertSelection() }
                            .disabled(selectedIds.isEmpty)
                    }
                }
        }
    }
}
