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
    /// This is the *only* API that mutates levels; every read path clamps transiently
    /// instead, so a level synced from a future build degrades without being destroyed.
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
        guard items.indices.contains(headingIndex),
              items[headingIndex].entry.entryKind == .heading else {
            return headingIndex ..< (headingIndex + 1)
        }
        let level = items[headingIndex].depth
        var end = headingIndex + 1
        while end < items.count {
            let item = items[end]
            if item.entry.entryKind == .heading && item.depth <= level { break }
            end += 1
        }
        return headingIndex ..< end
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
