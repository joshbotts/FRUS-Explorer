// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionOutline

/// The **single linearizer** for a collection's derived section tree (Authoring Phase 4).
///
/// A collection's entries are a flat, globally `sortOrder`-ed list; nesting is encoded
/// purely as `CollectionEntry.level` on `.heading` entries (see the level-encoding
/// rationale on that property). This type is the only place structure is derived from
/// levels: the editor's outline rows, `CollectionContentResolver`'s body-depth cascade,
/// the exporters' nested ToC, and the `.fruscollection` serializer all consume it —
/// **nothing else may re-derive structure**, so every consumer agrees on the tree even
/// for malformed level sequences synced from other builds.
///
/// ## Resolution rules (defensive, never mutating unless asked)
/// - Levels clamp to `1...maxLevel` (3).
/// - No orphan jumps: a heading deeper than its predecessor + 1 clamps to predecessor + 1
///   (the first heading always resolves to level 1). Degradation is a shallower heading,
///   never corruption — the model value is untouched unless `normalize` is called.
/// - Non-heading entries take the resolved level of the heading that owns them
///   (`0` for entries before the first heading).
///
/// Version history:
///   1.0 — Authoring Phase 4: initial implementation (linearize, normalize, section
///          ranges, indent/outdent predicates, ancestor body-depth cascade)
///   1.1 — Authoring Phase 4 (editor step): the shared move engine (`movedOrder` /
///          `applyingMove` — a heading drags its whole section as one block, self-drops
///          are forbidden, documents keep single-row moves), `indentSection` /
///          `outdentSection` (shift the heading *and* its descendant headings, then
///          normalize), and `visibleIndices` (collapse-state derivation for the editors'
///          chevrons — view state only, never persisted)
enum CollectionOutline {

    /// The maximum heading nesting depth (locked decision A6: cap at 3, enforced in the
    /// UI and by read-time clamping only — the model never migrates).
    static let maxLevel = 3

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

    // MARK: - StructuralRef

    /// The minimal structural facts about one entry, decoupled from SwiftData, so the
    /// resolver's value-snapshot pipeline (`EntryRef`) can run the exact same algorithms
    /// as the model-backed API without touching `@Model` instances. All heavier helpers
    /// delegate to the `StructuralRef`-based cores below — the algorithm exists once.
    struct StructuralRef {
        /// Whether the entry is a `.heading` (only headings carry structure).
        let isHeading: Bool
        /// The stored heading level (unclamped; ignored for non-headings).
        let level: Int
        /// The entry's `bodyDepthOverride` raw value, if any (a heading's acts as its
        /// section's default; a document's is its own override, resolved elsewhere).
        let bodyDepthOverride: String?

        /// Creates a structural reference.
        init(isHeading: Bool, level: Int, bodyDepthOverride: String?) {
            self.isHeading = isHeading
            self.level = level
            self.bodyDepthOverride = bodyDepthOverride
        }

        /// Snapshots the structural facts of a model entry.
        init(_ entry: CollectionEntry) {
            self.init(isHeading: entry.entryKind == .heading,
                      level: entry.level,
                      bodyDepthOverride: entry.bodyDepthOverride)
        }
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

    /// The `StructuralRef` core of `linearize`: resolves each position's depth (heading →
    /// clamped/orphan-corrected level; non-heading → owning heading's resolved level, 0
    /// before the first heading). Input order is taken as collection order.
    ///
    /// - Parameter refs: Structural facts in collection order.
    /// - Returns: One resolved depth per input position.
    static func resolvedDepths(_ refs: [StructuralRef]) -> [Int] {
        var depths: [Int] = []
        depths.reserveCapacity(refs.count)
        // The resolved level of the most recent heading (0 before any heading exists).
        var currentLevel = 0
        for ref in refs {
            if ref.isHeading {
                let clamped = min(max(ref.level, 1), maxLevel)
                // Orphan-jump clamp: a heading may nest at most one level deeper than
                // the heading before it (the first heading resolves to 1).
                currentLevel = min(clamped, currentLevel + 1)
                depths.append(currentLevel)
            } else {
                depths.append(currentLevel)
            }
        }
        return depths
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

    /// The `StructuralRef` core of `sectionRange(of:in:)` — the same ownership rule for
    /// callers holding raw structural facts (the move engine, `visibleIndices`). Depths
    /// are resolved defensively via `resolvedDepths`.
    ///
    /// - Parameters:
    ///   - headingIndex: Index of a heading ref in `refs`.
    ///   - refs: Structural facts in collection order.
    /// - Returns: The section's range (degenerate single-item range for non-headings).
    static func sectionRange(of headingIndex: Int, refs: [StructuralRef]) -> Range<Int> {
        sectionRangeCore(of: headingIndex,
                         isHeading: refs.map(\.isHeading),
                         depths: resolvedDepths(refs))
    }

    /// The single section-ownership walk both `sectionRange` overloads delegate to:
    /// the heading plus everything until (excluding) the next heading at the same or a
    /// shallower resolved depth.
    private static func sectionRangeCore(of headingIndex: Int,
                                         isHeading: [Bool],
                                         depths: [Int]) -> Range<Int> {
        guard depths.indices.contains(headingIndex), isHeading[headingIndex] else {
            return headingIndex ..< (headingIndex + 1)
        }
        let level = depths[headingIndex]
        var end = headingIndex + 1
        while end < depths.count {
            if isHeading[end] && depths[end] <= level { break }
            end += 1
        }
        return headingIndex ..< end
    }

    // MARK: - Move engine

    /// The shared move engine's pure core (Phase 4 editor step): computes the new
    /// ordering after dragging the row at `fromIndex` to `toOffset`, in **SwiftUI
    /// `onMove` semantics** (`toOffset` is an insertion offset in the *pre-removal*
    /// list, `0...count`).
    ///
    /// - A **heading** moves its entire `sectionRange` as one contiguous block.
    /// - Any other entry moves as a single row.
    /// - A drop *inside the moved block's own range* (or immediately back onto itself)
    ///   is forbidden / a no-op — the function returns `nil` and callers change nothing.
    ///
    /// - Parameters:
    ///   - refs: Structural facts in collection order.
    ///   - fromIndex: Index of the dragged row.
    ///   - toOffset: Insertion offset (`0...refs.count`) in pre-removal coordinates.
    /// - Returns: The new ordering as indices into the input, or `nil` when the move is
    ///   invalid or changes nothing.
    static func movedOrder(_ refs: [StructuralRef], fromIndex: Int, toOffset: Int) -> [Int]? {
        guard refs.indices.contains(fromIndex), (0...refs.count).contains(toOffset) else {
            return nil
        }
        let block = refs[fromIndex].isHeading
            ? sectionRange(of: fromIndex, refs: refs)
            : fromIndex ..< (fromIndex + 1)
        // Offsets from the block's start through the slot just past its end either drop
        // the section into itself (forbidden) or leave the order unchanged (no-op).
        if toOffset >= block.lowerBound && toOffset <= block.upperBound { return nil }
        var order = Array(refs.indices)
        let moved = Array(block)
        order.removeSubrange(block)
        let insertAt = toOffset > block.upperBound ? toOffset - moved.count : toOffset
        order.insert(contentsOf: moved, at: insertAt)
        return order
    }

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

    /// The visible positions of an outline given the set of collapsed heading positions
    /// — the editors' collapse/expand chevron state is **view state only** (never
    /// persisted): a collapsed heading hides every row of its `sectionRange` except the
    /// heading itself. Collapsed positions that are not headings are ignored.
    ///
    /// - Parameters:
    ///   - refs: Structural facts in collection order.
    ///   - collapsedHeadingIndices: Positions of collapsed headings.
    /// - Returns: Indices into `refs` of the rows the editor shows, in order.
    static func visibleIndices(_ refs: [StructuralRef],
                               collapsedHeadingIndices: Set<Int>) -> [Int] {
        var hidden = Set<Int>()
        for index in collapsedHeadingIndices
        where refs.indices.contains(index) && refs[index].isHeading {
            let range = sectionRange(of: index, refs: refs)
            hidden.formUnion((range.lowerBound + 1) ..< range.upperBound)
        }
        return refs.indices.filter { !hidden.contains($0) }
    }

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

    /// Per-position effective **section** body-depth overrides — the ancestor-walking
    /// extension of Phase 3c's "nearest preceding heading" rule (D5 per-level overrides
    /// fall out here). For each position, the value is the `bodyDepthOverride` of the
    /// nearest *ancestor* heading that has one, walking up the derived tree: the owning
    /// heading first, then its parent, and so on. A deeper heading's override therefore
    /// beats (shadows) a shallower ancestor's; a heading without one inherits its
    /// ancestor's. `nil` when no ancestor sets an override (fall through to the
    /// collection default).
    ///
    /// For a heading position, the returned value is the override in effect *inside*
    /// that heading's section (including the heading's own, when set) — the value the
    /// resolver applies to the documents that follow.
    ///
    /// Behavior-identical to the flat Phase 3c tracking for all-level-1 collections:
    /// with no nesting the ancestor chain is exactly the nearest preceding heading, and
    /// a nil override on it resets the section (no inheritance across siblings).
    ///
    /// - Parameter refs: Structural facts in collection order (levels may be raw; they
    ///   are resolved defensively via `resolvedDepths`).
    /// - Returns: One effective section override (raw `CollectionBodyDepth` value or
    ///   `nil`) per input position.
    static func sectionBodyDepthOverrides(_ refs: [StructuralRef]) -> [String?] {
        let depths = resolvedDepths(refs)
        var overrides: [String?] = []
        overrides.reserveCapacity(refs.count)
        // Ancestor stack: (resolved level, that heading's own override or nil).
        var stack: [(level: Int, override: String?)] = []
        for (i, ref) in refs.enumerated() {
            if ref.isHeading {
                let level = depths[i]
                // Pop siblings/deeper sections: the new heading closes every section at
                // its level or deeper, keeping only true ancestors on the stack.
                while let top = stack.last, top.level >= level { stack.removeLast() }
                stack.append((level, ref.bodyDepthOverride))
            }
            // Nearest ancestor with a set override wins (scan from the deepest up).
            overrides.append(stack.last(where: { $0.override != nil })?.override)
        }
        return overrides
    }

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
