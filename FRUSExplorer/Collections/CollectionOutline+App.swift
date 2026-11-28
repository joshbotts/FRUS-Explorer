// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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

// MARK: - CollectionApparatusRows (L44)

/// The apparatus rows step 2 ticks (L44; the Collections design's §4.3), one rule for the iOS editor and the Mac window,
/// each of which keeps its own outline in step with its rows (#1416): which block types the outline has a row of, a
/// row inserted at its block's usual place, a whole apparatus applied, and *Undo*.
///
/// A tick is not a setting. It says the outline has that block's row: ticking inserts one, and unticking removes every
/// row of that type, since a block can be in a collection twice (the outline's Apparatus menu adds one each time). A
/// row stores its type and its place, so its place is all an untick loses, and *Undo* puts it back.
///
/// Version history:
///   1.0 — L44: initial implementation, from the two editors' `addGeneratedEntry(type:)`, which inserted a block at
///          its default position and are now this type's `insert`
@MainActor
enum CollectionApparatusRows {

    /// The block type `entry` is a row of, or `nil` for any other row, a block type this build does not know among them.
    static func blockType(of entry: CollectionEntry) -> CollectionGeneratedBlockType? {
        guard entry.entryKind == .generated, let raw = entry.generatedBlockType else { return nil }
        return CollectionGeneratedBlockType(rawValue: raw)
    }

    /// `collection`'s rows as the model holds them now, in their order, without a row deleted and not yet saved: what
    /// the settings read, live, wherever they are pushed, since a model read is observed and a copy handed to a pushed
    /// screen is not (L44).
    static func liveOutline(of collection: Collection) -> [CollectionEntry] {
        (collection.documentEntries ?? []).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The block types `outline` has a row of.
    static func blocks(in outline: [CollectionEntry]) -> Set<CollectionGeneratedBlockType> {
        Set(outline.compactMap(blockType(of:)))
    }

    /// Step 2's state: `collection`'s contents style and word cloud, and the blocks `outline` has.
    static func settings(of collection: Collection, outline: [CollectionEntry]) -> CollectionApparatusSettings {
        CollectionApparatusSettings(contentsStyle: CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation,
                                    wordCloud: collection.includeWordCloud, blocks: blocks(in: outline))
    }

    /// Where a new row of `type` goes in `outline` (the design's §4.3): a Chronology first; the Note on the Text last;
    /// any other block at the end, but ahead of the Note on the Text where the outline ends with one, so that the Note
    /// stays last.
    static func insertionIndex(for type: CollectionGeneratedBlockType, in outline: [CollectionEntry]) -> Int {
        switch type.defaultPosition {
        case .frontMatter:
            return 0
        case .backMatter:
            guard type != .noteOnTheText else { return outline.count }
            var index = outline.count
            while index > 0, blockType(of: outline[index - 1]) == .noteOnTheText { index -= 1 }
            return index
        }
    }

    /// Inserts a new row of `type` into `collection` and `outline`, at its usual place. The caller renumbers and saves,
    /// as after any outline mutation.
    @discardableResult
    static func insert(_ type: CollectionGeneratedBlockType, into collection: Collection,
                       outline: inout [CollectionEntry], at index: Int? = nil,
                       modelContext: ModelContext) -> CollectionEntry {
        let entry = CollectionEntry(collectionId: collection.id, documentId: "", volumeId: "", sortOrder: 0)
        entry.entryKind = .generated
        entry.generatedBlockType = type.rawValue
        entry.collection = collection
        modelContext.insert(entry)
        let place = min(max(index ?? insertionIndex(for: type, in: outline), 0), outline.count)
        outline.insert(entry, at: place)
        return entry
    }

    /// What *Undo* needs to put one of step 2's changes back.
    struct Undo {
        /// The rows the change removed, each with its place in the outline before the change, in the outline's order.
        let removed: [(index: Int, type: CollectionGeneratedBlockType)]
        /// The rows the change inserted.
        let added: [UUID]
        /// The contents list's style before the change, as stored.
        let tocStyle: String
        /// The word cloud before the change.
        let includeWordCloud: Bool
        /// What the change did, which the line where it was made says.
        let change: CollectionApparatusChange
    }

    /// Applies `target` to `collection` and its outline: every row of a block type it does not have is removed, a row
    /// of each type it has and the outline does not is inserted at its usual place, and the contents style and the word
    /// cloud are written. The caller renumbers and saves.
    ///
    /// - Returns: What *Undo* needs.
    @discardableResult
    static func apply(_ target: CollectionApparatusSettings, to collection: Collection,
                      outline: inout [CollectionEntry], modelContext: ModelContext) -> Undo {
        let before = settings(of: collection, outline: outline)
        let tocStyle = collection.tocStyle, wordCloud = collection.includeWordCloud
        var removed: [(index: Int, type: CollectionGeneratedBlockType)] = []
        for (index, entry) in outline.enumerated() {
            if let type = blockType(of: entry), !target.blocks.contains(type) { removed.append((index, type)) }
        }
        for item in removed.reversed() {
            modelContext.delete(outline[item.index])
            outline.remove(at: item.index)
        }
        var added: [UUID] = []
        for type in target.orderedBlocks where !blocks(in: outline).contains(type) {
            added.append(insert(type, into: collection, outline: &outline, modelContext: modelContext).id)
        }
        if collection.tocStyle != target.contentsStyle.rawValue { collection.tocStyle = target.contentsStyle.rawValue }
        if collection.includeWordCloud != target.wordCloud { collection.includeWordCloud = target.wordCloud }
        return Undo(removed: removed, added: added, tocStyle: tocStyle, includeWordCloud: wordCloud,
                    change: CollectionApparatusChange(from: before, to: target))
    }

    /// Puts back what `undo` records: the rows the change inserted are removed, each row it removed is inserted again at
    /// its place, and the contents style and the word cloud are written back. The caller renumbers and saves.
    static func undo(_ undo: Undo, collection: Collection, outline: inout [CollectionEntry],
                     modelContext: ModelContext) {
        let added = Set(undo.added)
        for index in outline.indices.reversed() where added.contains(outline[index].id) {
            modelContext.delete(outline[index])
            outline.remove(at: index)
        }
        for item in undo.removed {
            insert(item.type, into: collection, outline: &outline, at: item.index, modelContext: modelContext)
        }
        if collection.tocStyle != undo.tocStyle { collection.tocStyle = undo.tocStyle }
        if collection.includeWordCloud != undo.includeWordCloud { collection.includeWordCloud = undo.includeWordCloud }
    }
}

// MARK: - CollectionOwnSettings (L44)

/// The rows of a collection that set a setting for themselves (L44; the design's §4.2): *Footnotes: On · 2 set their
/// own*, at the collection, is the count of them, and opens the list of them with *Clear*, which returns the ones chosen
/// to following. A section's own value and a document's are each counted, since each is a row that decides for itself.
///
/// A heading's `includeHeadnote` is never a section's headnote default, which is its own field (`headnoteDefault`;
/// the third review's J24): headings of the builds of 2026-07-01 to 07-11 hold an unseen `false` there.
///
/// Version history:
///   1.0 — L44: initial implementation
@MainActor
enum CollectionOwnSettings {

    /// Whether `setting` can be set by a section or a document: every setting a template sets but the opening, which is
    /// the collection's alone, and the summary prompt and *See also*.
    static func cascades(_ setting: CollectionSetting) -> Bool {
        setting != .opening
    }

    /// The value `entry` sets for itself, or `nil` where it follows: a section's or a document's own, never another
    /// kind of row's.
    static func ownValue(_ setting: CollectionSetting, of entry: CollectionEntry) -> AnyHashable? {
        let isHeading = entry.entryKind == .heading
        guard isHeading || entry.entryKind == .document else { return nil }
        switch setting {
        case .opening:       return nil
        case .bodyDepth:     return entry.bodyDepthOverride
        case .summaryPrompt: return entry.summaryPromptIdOverride
        case .footnotes:     return entry.includeFootnotesOverride
        case .sourceNote:    return entry.includeSourceNoteOverride
        case .seeAlso:       return entry.includeRelatedDocuments
        case .notes:         return entry.includeNotesOverride
        case .highlights:    return entry.applyHighlightsOverride
        case .headnotes:     return isHeading ? entry.headnoteDefault : entry.includeHeadnote
        }
    }

    /// The rows of `outline` that set `setting` for themselves, in the outline's order.
    static func rows(setting: CollectionSetting, in outline: [CollectionEntry]) -> [CollectionEntry] {
        outline.filter { ownValue(setting, of: $0) != nil }
    }

    /// The words for the value `entry` sets: *On*, *Off*, a body depth's name, or a prompt's (`promptName`).
    static func valueName(_ setting: CollectionSetting, of entry: CollectionEntry,
                          promptName: (UUID) -> String) -> String {
        switch ownValue(setting, of: entry) {
        case let value as Bool:
            return CollectionSetting.onOff(value)
        case let raw as String:
            return CollectionBodyDepth(rawValue: raw)?.displayName ?? raw
        case let id as UUID:
            return promptName(id)
        default:
            return ""
        }
    }

    /// Returns `entries` to following for `setting`: each one's own value is cleared.
    static func clear(_ setting: CollectionSetting, of entries: [CollectionEntry]) {
        for entry in entries {
            switch setting {
            case .opening:       break
            case .bodyDepth:     entry.bodyDepthOverride = nil
            case .summaryPrompt: entry.summaryPromptIdOverride = nil
            case .footnotes:     entry.includeFootnotesOverride = nil
            case .sourceNote:    entry.includeSourceNoteOverride = nil
            case .seeAlso:       entry.includeRelatedDocuments = nil
            case .notes:         entry.includeNotesOverride = nil
            case .highlights:    entry.applyHighlightsOverride = nil
            case .headnotes:
                if entry.entryKind == .heading { entry.headnoteDefault = nil } else { entry.includeHeadnote = nil }
            }
        }
    }

    /// What `entry`'s choice for `setting` follows where it sets none (the design's §4.2): the value of the nearest
    /// section around it that sets one, else the collection's. A section's own value is never what it follows, so a
    /// section's sheet reads the sections around it; a document reads the sections it is in. The cascade is the kit's
    /// (`CollectionOutline.sectionOverrideValues`), the one the export resolves with.
    ///
    /// - Returns: The value in force there (a `Bool`, a body depth's raw value or a prompt's id, `nil` for no prompt),
    ///   and whether a section sets it rather than the collection.
    static func followed(_ setting: CollectionSetting, by entry: CollectionEntry) -> (value: AnyHashable?, fromSection: Bool) {
        guard let collection = entry.collection else { return (nil, false) }
        let ordered = (collection.documentEntries ?? []).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
        if let index = ordered.firstIndex(where: { $0.id == entry.id }) {
            let values: [AnyHashable?] = ordered.enumerated().map { position, row in
                row.entryKind == .heading && position != index ? ownValue(setting, of: row) : nil
            }
            if let value = CollectionOutline.sectionOverrideValues(ordered.map(CollectionOutline.StructuralRef.init),
                                                                   headingValues: values)[index] {
                return (value, true)
            }
        }
        return (collectionValue(setting, of: collection), false)
    }

    /// The collection's own value for `setting`.
    static func collectionValue(_ setting: CollectionSetting, of collection: Collection) -> AnyHashable? {
        switch setting {
        case .opening:       return collection.opening
        case .bodyDepth:     return collection.defaultBodyDepth
        case .summaryPrompt: return collection.summaryPromptId
        case .footnotes:     return collection.effectiveIncludeFootnotes
        case .sourceNote:    return collection.effectiveIncludeSourceNote
        case .seeAlso:       return collection.defaultIncludeRelatedDocuments
        case .notes:         return collection.includeNotes
        case .highlights:    return collection.applyHighlights
        case .headnotes:     return collection.defaultIncludeHeadnote
        }
    }

    /// A choice's first item, which says what it follows and what that is: *Follow the section: On*, *Follow the
    /// collection: Full document*, *Follow the collection: None* for no summary prompt.
    static func followedWords(_ setting: CollectionSetting, by entry: CollectionEntry,
                              promptName: (UUID) -> String) -> String {
        let followed = followed(setting, by: entry)
        let words: String
        switch followed.value {
        case let value as Bool:
            words = CollectionSetting.onOff(value)
        case let raw as String:
            words = (CollectionBodyDepth(rawValue: raw) ?? .full).displayName
        case let id as UUID:
            words = promptName(id)
        default:
            words = String(localized: "collection.inspector.override.prompt.none", defaultValue: "None")
        }
        return CollectionSetting.follows(words, fromSection: followed.fromSection)
    }

    /// A row's name in the list of the rows that set their own: a section's heading, else the name an untitled one
    /// goes by; a document's title, else its heading from the index (`headers`, keyed `"volumeId/documentId"`, as both
    /// editors load them), else its volume and number.
    static func rowName(_ entry: CollectionEntry, headers: [String: String]) -> String {
        if entry.entryKind == .heading {
            let text = entry.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? CollectionEditorNaming.untitledSection : text
        }
        if let title = entry.titleOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return headers["\(entry.volumeId)/\(entry.documentId)"] ?? "\(entry.volumeId) \(entry.documentId)"
    }

    /// "1 sets its own" / "2 set their own", the count's words.
    static func countPhrase(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "collection.setting.ownCount.one", defaultValue: "%@ sets its own"),
                         many: String(localized: "collection.setting.ownCount.many", defaultValue: "%@ set their own"))
    }
}
