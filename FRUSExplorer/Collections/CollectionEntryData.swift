// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - CollectionDateSortScope

/// The two scopes the "Sort by Date" control offers, surfaced identically on the macOS
/// manager ribbon and the iPad/iOS toolbar.
///
/// - ``wholeCollection`` — the original (and default) behavior: documents flow through the
///   fixed structural anchors in ONE global chronology, so a document can cross a heading
///   boundary into a neighboring section.
/// - ``withinSections`` — documents sort by date *within* their heading-delimited section
///   only, and never cross a heading. When the collection has no headings, this is
///   identical to ``wholeCollection``.
enum CollectionDateSortScope: CaseIterable, Sendable {
    /// Sort every document into one global chronology (documents may cross headings).
    case wholeCollection
    /// Sort documents chronologically within each heading-delimited section only.
    case withinSections

    /// The localized menu-item title for this scope.
    var displayLabel: String {
        switch self {
        case .wholeCollection:
            return String(localized: "collection.sort.date.scope.whole",
                          defaultValue: "Across the Whole Collection")
        case .withinSections:
            return String(localized: "collection.sort.date.scope.sections",
                          defaultValue: "Within Each Section")
        }
    }

    /// A one-line help/tooltip clarifying the scope's effect.
    var helpText: String {
        switch self {
        case .wholeCollection:
            return String(localized: "collection.sort.date.scope.whole.help",
                          defaultValue: "Order every document into one chronology — a document may move past a section heading")
        case .withinSections:
            return String(localized: "collection.sort.date.scope.sections.help",
                          defaultValue: "Order documents chronologically within each section — documents stay under their heading")
        }
    }

    /// The SF Symbol paired with this scope's menu item.
    var systemImage: String {
        switch self {
        case .wholeCollection: return "arrow.up.arrow.down"
        case .withinSections:  return "list.bullet.indent"
        }
    }
}

// MARK: - CollectionEntryData

/// Shared data plumbing for the two collection managers (iOS `CollectionEditorView` and
/// macOS `MacCollectionManagerView`): bulk-loads per-document display data (headers and
/// ISO dates) and provides the canonical date sort, so both platforms render identical
/// entry rows and sort identically.
///
/// Version history:
///   1.0 — Authoring Phase 1 (Session 2026-07-02): extracted from the macOS pane-level
///          loader and `sortByDate`; iOS previously showed bare ids and sorted by volume
///          dates only
///   1.1 — Sort modes (Collections): `sortedByDate` gains a `withinSections` scope. When
///          false (the default) the global path is byte-identical to 1.0; when true the
///          flat entry list is partitioned into heading-delimited runs and the global
///          sort is applied to each run independently, so documents never cross a heading.
///          A shared `CollectionDateSortScope` enum drives the two UI surfaces.
enum CollectionEntryData {

    /// Bulk-loads document headers (from `document_cache` via `CrossReferenceStore`) and
    /// per-document ISO dates (from `document_dates`) for the given entries, keyed by
    /// `"volumeId/documentId"`. Documents from unindexed volumes are simply absent from
    /// the returned maps; callers fall back to ids / volume dates.
    @MainActor
    static func load(
        for entries: [CollectionEntry],
        appState: AppState
    ) async -> (headers: [String: String], dates: [String: String]) {
        let keys = entries.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        var headers: [String: String] = [:]
        var dates: [String: String] = [:]
        if let store = appState.crossReferenceStore,
           let h = try? await store.documentHeaders(for: keys) {
            headers = h
        }
        if let pipeline = appState.indexingPipeline,
           let d = try? await pipeline.datesByDocumentKey(keys) {
            dates = d
        }
        return (headers, dates)
    }

    /// Returns `entries` with the DOCUMENT entries reordered by date while heading/prose
    /// entries keep their positions, so the authored structure survives the sort (dateless
    /// structural entries would otherwise all clump at the sentinel).
    ///
    /// Date precedence per document (the canonical three tiers):
    /// 1. Per-document `date_iso` from `documentDates` — individual-document precision
    ///    within a volume.
    /// 2. The volume's `dateRange.earliest` from the manifest — keeps documents from
    ///    unindexed volumes in the right volume-level neighborhood.
    /// 3. A `"9999"` sentinel — documents with no date information sort to the end.
    ///
    /// - Parameter withinSections: when `false` (the default) the sort is GLOBAL — every
    ///   document flows through the fixed non-document anchors in one chronology, so a
    ///   document can cross a heading into a neighboring section. When `true` the sort is
    ///   SECTION-AWARE — the flat list is partitioned into heading-delimited runs and the
    ///   global sort is applied to each run independently, so documents sort by date within
    ///   their section and never cross a heading. With no headings the two scopes are
    ///   identical (one run = the whole collection).
    static func sortedByDate(
        _ entries: [CollectionEntry],
        documentDates: [String: String],
        manifest: [VolumeManifestEntry],
        withinSections: Bool = false
    ) -> [CollectionEntry] {
        // Built with a loop (not `uniqueKeysWithValues`) so a duplicate manifest row can
        // never crash the sort.
        var volumeDateMap: [String: String] = [:]
        for entry in manifest {
            if let d = entry.dateRange.earliest {
                volumeDateMap[entry.volumeId] = d
            }
        }

        guard withinSections else {
            return globalSortedByDate(entries, documentDates: documentDates,
                                      volumeDateMap: volumeDateMap)
        }

        // Section-aware: split the flat list into consecutive runs, beginning a new run
        // BEFORE each heading (of ANY depth). The leading run is everything before the
        // first heading; each subsequent run is [heading, …up to the next heading]. Apply
        // the global sort to each run independently, then concatenate in original order.
        // A sub-heading therefore starts its own run, so documents sort within their
        // immediate (deepest) section. With no headings there is a single run — the whole
        // collection — so this reduces exactly to the global path.
        var result: [CollectionEntry] = []
        result.reserveCapacity(entries.count)
        var run: [CollectionEntry] = []
        for entry in entries {
            if entry.entryKind == .heading, !run.isEmpty {
                result.append(contentsOf: globalSortedByDate(
                    run, documentDates: documentDates, volumeDateMap: volumeDateMap))
                run = []
            }
            run.append(entry)
        }
        if !run.isEmpty {
            result.append(contentsOf: globalSortedByDate(
                run, documentDates: documentDates, volumeDateMap: volumeDateMap))
        }
        return result
    }

    /// The canonical global sort over one entry list: reorders DOCUMENT entries by date
    /// into the doc-slots they already occupy while every non-document entry stays put as a
    /// fixed anchor. Shared by the whole-collection scope and by each run of the
    /// section-aware scope so the two paths cannot diverge.
    private static func globalSortedByDate(
        _ entries: [CollectionEntry],
        documentDates: [String: String],
        volumeDateMap: [String: String]
    ) -> [CollectionEntry] {
        let sortedDocs = entries
            .filter { $0.entryKind == .document }
            .sorted { a, b in
                let aDate = documentDates["\(a.volumeId)/\(a.documentId)"] ?? volumeDateMap[a.volumeId] ?? "9999"
                let bDate = documentDates["\(b.volumeId)/\(b.documentId)"] ?? volumeDateMap[b.volumeId] ?? "9999"
                return aDate < bDate
            }
        var docs = sortedDocs.makeIterator()
        return entries.map { $0.entryKind == .document ? (docs.next() ?? $0) : $0 }
    }
}

// MARK: - CollectionEntryOrdering

/// Where a collection's entries sit, for every writer at once (#1416): the position a new entry takes, how an open
/// editor's outline follows the entries the MODEL holds, and how an editor numbers them after it changes the outline.
///
/// **Why a shared rule.** Both collection editors — iOS `CollectionEditorView` and the Mac manager's
/// `CollectionDetailPane` — load the collection's entries once into their own outline (`sortedEntries`), and the
/// outline is what their rows, the live preview and the export sheet read. Other writers add to the same collection
/// while an editor is open: a document's Add to Collection picker on another tab
/// (`CollectionDocumentDiscovery.appendToCollection`), a highlight's Add to Collection
/// (`CollectionExcerpts.appendToCollection`), another iPad window, iCloud. Before #1416:
/// - the outline never heard of such an entry, so the editor did not show it and an export made from the editor left
///   it out, until the collection was reopened;
/// - the editor's own next append took `sortedEntries.count` as its position — the number the picker had just given
///   the other entry as `max + 1` — so the two shared a position, and a reader that orders entries by position (the
///   export resolver, the trip packet, the research-data export, a reopened editor) could put either first;
/// - the editor renumbered only the entries it held, `0..<n`, which could hand one of them the other entry's position
///   again.
///
/// So every append takes ``nextSortOrder(in:outline:)``, the open editors seed their outline from
/// ``modelOrder(of:outline:)`` and follow the model through `CollectionEntriesModelSync` and ``reconciled(_:with:)``,
/// and every other change they make — a reorder, a delete, Sort by Date, an added heading, note or apparatus block —
/// numbers through ``renumber(_:in:)``. An appended document or excerpt renumbers nothing.
///
/// **What it cannot promise.** ``nextSortOrder(in:outline:)`` reads one context's view of the model, so it keeps apart
/// the appends one device sees. Two devices that append to the same collection before either has synced both take the
/// same `max + 1`; after the import the follow shows the pair by id at their shared position, and nothing renumbers
/// them until an editor's next reorder, delete, sort or block insert. So do positions already shared in stored data.
///
/// Version history:
///   1.0 — #1416: initial implementation
enum CollectionEntryOrdering {

    /// The entries `collection` holds that its context has not deleted, in no particular order. An entry deleted from
    /// the context is still listed by `documentEntries` straight after the delete (measured for #1359) — until the
    /// context processes the deletion, which a save does, and which hosting an editor did with nothing saved (#1416
    /// review) — and it is not content.
    @MainActor
    static func liveEntries(of collection: Collection) -> [CollectionEntry] {
        (collection.documentEntries ?? []).filter { !$0.isDeleted }
    }

    /// The position a new entry appended to `collection` takes: one past the highest position held by any entry in the
    /// model or in `outline`, or `0` when there is none. Never a count — a count collides with an entry another writer
    /// appended at `max + 1` while the outline was not looking, and with every gap a deletion left.
    ///
    /// - Parameters:
    ///   - collection: The collection the entry joins.
    ///   - outline: The appending editor's outline, when there is one; its entries are normally in the model too.
    @MainActor
    static func nextSortOrder(in collection: Collection, outline: [CollectionEntry] = []) -> Int {
        let highest = ((collection.documentEntries ?? []) + outline).map(\.sortOrder).max()
        return (highest ?? -1) + 1
    }

    /// `collection`'s live entries in the order they sit: by position; at a shared position, in the order `outline`
    /// lists them, and after them, by id, the ones it does not list. Both editors seed their outline from it (with no
    /// outline yet), and `CollectionEntriesModelSync` watches it, so the two agree from the first frame.
    @MainActor
    static func modelOrder(of collection: Collection, outline: [CollectionEntry] = []) -> [CollectionEntry] {
        let listed = Dictionary(outline.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        return liveEntries(of: collection).sorted { a, b in
            if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
            switch (listed[a.id], listed[b.id]) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.id.uuidString < b.id.uuidString
            }
        }
    }

    /// `outline` brought into step with the entries `collection` holds, or `nil` when it already is — so following
    /// writes nothing and re-renders nothing when nothing moved.
    ///
    /// The result is ``modelOrder(of:outline:)``: every live entry exactly once, in position order. An entry another
    /// writer added joins at its position; one another writer deleted, or moved to another collection, leaves; one
    /// another window moved takes its new place. At a shared position the outline's own order is kept and an entry it
    /// did not hold goes after, so data that already carries #1416's collision reads the way the editor showed it.
    @MainActor
    static func reconciled(_ outline: [CollectionEntry], with collection: Collection) -> [CollectionEntry]? {
        let followed = modelOrder(of: collection, outline: outline)
        return followed.map(\.id) == outline.map(\.id) ? nil : followed
    }

    /// Numbers `outline` `0..<n` in its order — the tail of every change an editor makes to its outline — and then
    /// numbers `n…`, in model order, every live entry of `collection` the outline does not hold yet. The follow runs on
    /// the view's next update, so an entry another writer added in the same turn as the editor's change is not in the
    /// outline yet; numbering the outline alone would give one of its entries that entry's position.
    @MainActor
    static func renumber(_ outline: [CollectionEntry], in collection: Collection) {
        let held = Set(outline.map(\.id))
        let unfollowed = modelOrder(of: collection, outline: outline).filter { !held.contains($0.id) }
        for (index, entry) in outline.enumerated() { entry.sortOrder = index }
        for (offset, entry) in unfollowed.enumerated() { entry.sortOrder = outline.count + offset }
    }

    /// Appends an empty section heading or note block (`kind`) to `collection` at ``nextSortOrder(in:outline:)``,
    /// inserting it into `modelContext` and at the end of `outline` — the structural sibling of
    /// `CollectionDocumentDiscovery.appendEntries` and `CollectionExcerpts.append`, called by both editors' Add Section
    /// Heading and Add Note Block. Structural entries carry empty document identifiers and use `text`.
    ///
    /// - Returns: The inserted entry.
    @MainActor
    @discardableResult
    static func appendBlock(kind: CollectionEntryKind, to collection: Collection,
                            outline: inout [CollectionEntry], modelContext: ModelContext) -> CollectionEntry {
        let entry = CollectionEntry(collectionId: collection.id, documentId: "", volumeId: "",
                                    sortOrder: nextSortOrder(in: collection, outline: outline))
        entry.entryKind = kind
        entry.text = ""
        entry.collection = collection
        modelContext.insert(entry)
        outline.append(entry)
        return entry
    }
}
