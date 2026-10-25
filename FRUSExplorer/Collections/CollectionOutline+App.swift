// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The model-backed half of `CollectionOutline` (FRUS Explorer Light, S18a): every rule that reads or writes a
// SwiftData `CollectionEntry`, over the value core in `FRUSCoreKit/Collections/CollectionOutline.swift`, which
// holds the rules over `StructuralRef` that the resolver and a host outside the app share.

extension CollectionOutline.StructuralRef {

    /// Snapshots the structural facts of a model entry.
    init(_ entry: CollectionEntry) {
        self.init(isHeading: entry.entryKind == .heading,
                  level: entry.level,
                  bodyDepthOverride: entry.bodyDepthOverride)
    }
}

extension CollectionOutline {

    // MARK: - OutlineItem

    /// One linearized entry with its resolved depth.
    struct OutlineItem {
        /// The underlying entry, unmodified.
        let entry: CollectionEntry
        /// The resolved depth: for a `.heading` entry, its clamped/orphan-corrected level
        /// (`1...maxLevel`); for any other kind, the resolved level of the owning heading
        /// (`0` when the entry precedes every heading).
        let depth: Int
    }

    // MARK: - Linearize

    /// Linearizes entries into outline items — **the** `[CollectionEntry] → [OutlineItem]`
    /// function. Entries are sorted by `sortOrder`, then each is assigned its resolved
    /// depth per the type-doc rules. Never mutates the entries.
    ///
    /// - Parameter entries: The collection's entries, in any order.
    /// - Returns: Outline items in collection order, each carrying its resolved depth.
    static func linearize(_ entries: [CollectionEntry]) -> [OutlineItem] {
        let sorted = entries.sorted { $0.sortOrder < $1.sortOrder }
        let depths = resolvedDepths(sorted.map(StructuralRef.init))
        return zip(sorted, depths).map { OutlineItem(entry: $0, depth: $1) }
    }

    // MARK: - Normalize

    /// Writes resolved levels back onto `.heading` entries — the pass the editor runs
    /// after any mutation (indent/outdent, move, delete) so persisted levels always
    /// satisfy the invariants (`1...maxLevel`, no orphan jumps). Only headings whose
    /// stored level differs from the resolved one are written, so an already-normal
    /// collection is untouched (no spurious `lastModified` bumps / CloudKit uploads).
    ///
    /// Levels are only ever mutated here and by `indentSection`/`outdentSection` (which
    /// write shifted levels and immediately delegate back to this pass); every read path
    /// clamps transiently instead, so a level synced from a future build degrades
    /// without being destroyed.
    ///
    /// - Parameter entries: The collection's entries, in any order.
    static func normalize(_ entries: [CollectionEntry]) {
        for item in linearize(entries) where item.entry.entryKind == .heading {
            if item.entry.level != item.depth {
                item.entry.level = item.depth
            }
        }
    }

    // MARK: - Section ranges

    /// The contiguous index range the heading at `headingIndex` owns: the heading itself
    /// plus every following item until (excluding) the next heading of the same or a
    /// shallower resolved level. This is the unit the editor moves, deletes, collapses,
    /// and re-levels as a whole ("move section as a unit", Phase 4 step 3).
    ///
    /// - Parameters:
    ///   - headingIndex: Index of a `.heading` item in `items`.
    ///   - items: A linearized outline (from `linearize`).
    /// - Returns: The section's range within `items`. When `headingIndex` is not a
    ///   heading, returns the degenerate single-item range `headingIndex..<headingIndex+1`.
    static func sectionRange(of headingIndex: Int, in items: [OutlineItem]) -> Range<Int> {
        sectionRangeCore(of: headingIndex,
                         isHeading: items.map { $0.entry.entryKind == .heading },
                         depths: items.map(\.depth))
    }

    // MARK: - Move engine

    /// The model-backed move engine both editors call from their `onMove` handlers:
    /// applies `movedOrder` to the collection's entries and returns the reordered array.
    /// The caller reindexes `sortOrder` (0..n), runs `normalize`, and saves — this
    /// function itself never mutates the entries.
    ///
    /// - Parameters:
    ///   - entries: The collection's entries, in any order.
    ///   - fromIndex: Index of the dragged row, in collection (sorted) order.
    ///   - toOffset: Insertion offset in pre-removal collection coordinates.
    /// - Returns: The reordered entries, or `nil` when the move is invalid/a no-op.
    static func applyingMove(_ entries: [CollectionEntry],
                             fromIndex: Int, toOffset: Int) -> [CollectionEntry]? {
        let sorted = entries.sorted { $0.sortOrder < $1.sortOrder }
        guard let order = movedOrder(sorted.map(StructuralRef.init),
                                     fromIndex: fromIndex, toOffset: toOffset) else { return nil }
        return order.map { sorted[$0] }
    }

    // MARK: - Indent / outdent mutations

    /// Indents the section at `headingIndex` one level: the heading *and* every
    /// descendant heading in its `sectionRange` shift +1 (clamped to `maxLevel`, so a
    /// descendant already at the cap merges up — A6 degradation, never corruption),
    /// then the whole list is normalized. No-op when `canIndent` is false.
    ///
    /// - Parameters:
    ///   - headingIndex: Index of the heading in the collection's sorted order.
    ///   - entries: The collection's entries, in any order.
    static func indentSection(at headingIndex: Int, in entries: [CollectionEntry]) {
        let items = linearize(entries)
        guard canIndent(headingIndex, in: items) else { return }
        shiftSection(at: headingIndex, by: +1, items: items)
        normalize(entries)
    }

    /// Outdents the section at `headingIndex` one level: the heading and its descendant
    /// headings shift −1 (clamped to level 1), then the list is normalized (following
    /// entries re-clamp as needed). No-op when `canOutdent` is false.
    ///
    /// - Parameters:
    ///   - headingIndex: Index of the heading in the collection's sorted order.
    ///   - entries: The collection's entries, in any order.
    static func outdentSection(at headingIndex: Int, in entries: [CollectionEntry]) {
        let items = linearize(entries)
        guard canOutdent(headingIndex, in: items) else { return }
        shiftSection(at: headingIndex, by: -1, items: items)
        normalize(entries)
    }

    /// Shifts every heading inside the section at `headingIndex` (the heading itself
    /// included) by `delta`, clamping to `1...maxLevel`. Shifting from *resolved* depths
    /// keeps the section's internal shape even when stored levels were malformed.
    private static func shiftSection(at headingIndex: Int, by delta: Int, items: [OutlineItem]) {
        let range = sectionRange(of: headingIndex, in: items)
        for i in range where items[i].entry.entryKind == .heading {
            items[i].entry.level = min(max(items[i].depth + delta, 1), maxLevel)
        }
    }

    // MARK: - Collapse derivation

    /// The model-backed convenience over `visibleIndices(_:collapsedHeadingIndices:)`
    /// for the editors, which key their collapse state by entry id (stable across moves).
    ///
    /// - Parameters:
    ///   - items: A linearized outline (from `linearize`).
    ///   - collapsedHeadingIds: Ids of the headings the user has collapsed.
    /// - Returns: Indices into `items` of the rows to show, in order.
    static func visibleIndices(in items: [OutlineItem],
                               collapsedHeadingIds: Set<UUID>) -> [Int] {
        let collapsed = Set(items.indices.filter {
            items[$0].entry.entryKind == .heading
                && collapsedHeadingIds.contains(items[$0].entry.id)
        })
        return visibleIndices(items.map { StructuralRef($0.entry) },
                              collapsedHeadingIndices: collapsed)
    }

    /// One visible editor row: the entry's position in the full outline, its resolved
    /// depth, and a stable identity for `ForEach` (the entry id, so row identity — and
    /// the collapse state keyed on it — survives moves and reindexing).
    struct VisibleRow: Identifiable {
        /// Index into the full linearized outline (== the sorted entries array).
        let index: Int
        /// The row's resolved outline depth (see `OutlineItem.depth`).
        let depth: Int
        /// The underlying entry's id.
        let id: UUID
    }

    /// The rows both editors list: `visibleIndices` joined with each row's depth and
    /// identity.
    ///
    /// - Parameters:
    ///   - items: A linearized outline (from `linearize`).
    ///   - collapsedHeadingIds: Ids of the headings the user has collapsed.
    /// - Returns: The visible rows, in order.
    static func visibleRows(in items: [OutlineItem],
                            collapsedHeadingIds: Set<UUID>) -> [VisibleRow] {
        visibleIndices(in: items, collapsedHeadingIds: collapsedHeadingIds).map {
            VisibleRow(index: $0, depth: items[$0].depth, id: items[$0].entry.id)
        }
    }

    /// The rows a collection's Contents lists in both editors (#1619; decision 22 of the 2026-10-14 plan of record).
    ///
    /// For a collection with no saved search, every visible row, as ``visibleRows(in:collapsedHeadingIds:)`` gives
    /// them. For a smart collection, only the entries it keeps — its generated apparatus, and an entry of a kind this
    /// build does not know — each flush and none hidden by a collapsed heading: every heading in a smart collection is an
    /// entry from before its link (`SmartCollectionRule.leavesOut`), which the editors list apart, under their own
    /// heading, so no row they keep sits in a section on screen.
    ///
    /// Each row's `index` is still its place in `items`, so a move, a delete and a binding reach the entry they did.
    ///
    /// - Parameters:
    ///   - items: A linearized outline (from `linearize`).
    ///   - collapsedHeadingIds: Ids of the headings the user has collapsed.
    ///   - savedSearchId: The collection's saved-search link, `nil` when it has none.
    /// - Returns: The rows, in order.
    static func contentsRows(in items: [OutlineItem], collapsedHeadingIds: Set<UUID>,
                             savedSearchId: UUID?) -> [VisibleRow] {
        guard savedSearchId != nil else {
            return visibleRows(in: items, collapsedHeadingIds: collapsedHeadingIds)
        }
        return items.indices.compactMap { index in
            let entry = items[index].entry
            return SmartCollectionRule.leavesOut(entry.entryKind, savedSearchId: savedSearchId)
                ? nil : VisibleRow(index: index, depth: 0, id: entry.id)
        }
    }

    // MARK: - Indent / outdent predicates

    /// Whether the heading at `headingIndex` may indent one level (level + 1). True only
    /// when the result stays within `maxLevel` *and* creates no orphan jump — i.e. the
    /// nearest preceding heading's resolved level is at least the heading's current level
    /// (the first heading can never indent). The editor re-normalizes the heading's
    /// section after applying, so descendants re-clamp as needed.
    ///
    /// - Parameters:
    ///   - headingIndex: Index of a `.heading` item in `items`.
    ///   - items: A linearized outline (from `linearize`).
    /// - Returns: `true` when indenting is a valid outline mutation; `false` for
    ///   non-heading indices.
    static func canIndent(_ headingIndex: Int, in items: [OutlineItem]) -> Bool {
        guard items.indices.contains(headingIndex),
              items[headingIndex].entry.entryKind == .heading else { return false }
        let level = items[headingIndex].depth
        guard level < maxLevel else { return false }
        // Nearest preceding heading's resolved level must be >= level, so that
        // level + 1 <= predecessor + 1 (no orphan jump).
        for i in stride(from: headingIndex - 1, through: 0, by: -1)
        where items[i].entry.entryKind == .heading {
            return items[i].depth >= level
        }
        return false   // first heading: indenting would orphan it above level 1
    }

    /// Whether the heading at `headingIndex` may outdent one level (level − 1): any
    /// heading deeper than level 1 can. `false` for non-heading indices. The editor
    /// re-normalizes after applying (an outdented heading may promote what followed it).
    ///
    /// - Parameters:
    ///   - headingIndex: Index of a `.heading` item in `items`.
    ///   - items: A linearized outline (from `linearize`).
    /// - Returns: `true` when outdenting is a valid outline mutation.
    static func canOutdent(_ headingIndex: Int, in items: [OutlineItem]) -> Bool {
        guard items.indices.contains(headingIndex),
              items[headingIndex].entry.entryKind == .heading else { return false }
        return items[headingIndex].depth > 1
    }

    // MARK: - Ancestor body-depth cascade

    /// The effective section body-depth override for the single entry at `index` in a
    /// linearized outline — the model-backed convenience over
    /// `sectionBodyDepthOverrides(_:)` for callers holding `[OutlineItem]` (e.g. the
    /// editor's inspector showing a document's inherited depth).
    ///
    /// - Parameters:
    ///   - index: Position within `items`.
    ///   - items: A linearized outline (from `linearize`).
    /// - Returns: The ancestor-cascaded override raw value, or `nil` (collection default).
    static func sectionBodyDepthOverride(at index: Int, in items: [OutlineItem]) -> String? {
        guard items.indices.contains(index) else { return nil }
        let refs = items.map { StructuralRef($0.entry) }
        return sectionBodyDepthOverrides(refs)[index]
    }
}
