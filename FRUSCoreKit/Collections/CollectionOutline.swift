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
///   1.2 — Authoring Phase 5 (overrides): the ancestor cascade generalized —
///          `sectionOverrideValues(_:headingValues:)` is the type-safe generic core
///          (one walk, any `Value`), and `sectionBodyDepthOverrides` now delegates to
///          it. The resolver runs the same core once per override field (highlights,
///          notes, source note, footnotes, summary prompt, related documents), so every
///          per-section default cascades by exactly the body-depth rule
///   1.3 — #1465: `exportLevels(_:untitled:)` — the levels an export emits once it leaves out every heading saved
///          with no text, each named heading under one lifted a level
///   1.4 — #1619, decision 22: `contentsRows(in:collapsedHeadingIds:savedSearchId:)` — a smart collection's Contents
///          lists only the entries it keeps; its entries from before its link are listed apart
///   1.5 — 2026-10-25 (FRUS Explorer Light, S18a): the value core — `maxLevel`, `StructuralRef` and every rule over it,
///          the depths, export levels, section ranges, move order, collapse and cascades — is FRUSCoreKit's and public,
///          unchanged, so a host outside the app nests a collection three deep by the same rules; what reads or writes a
///          `CollectionEntry` stays in the app (`CollectionOutline+App.swift`)
public enum CollectionOutline {

    /// The maximum heading nesting depth (locked decision A6: cap at 3, enforced in the
    /// UI and by read-time clamping only — the model never migrates).
    public static let maxLevel = 3

    // MARK: - StructuralRef

    /// The minimal structural facts about one entry, decoupled from SwiftData, so the
    /// resolver's value-snapshot pipeline (`EntryRef`) can run the exact same algorithms
    /// as the model-backed API without touching `@Model` instances. All heavier helpers
    /// delegate to the `StructuralRef`-based cores below — the algorithm exists once.
    public struct StructuralRef: Sendable {
        /// Whether the entry is a `.heading` (only headings carry structure).
        public let isHeading: Bool
        /// The stored heading level (unclamped; ignored for non-headings).
        public let level: Int
        /// The entry's `bodyDepthOverride` raw value, if any (a heading's acts as its
        /// section's default; a document's is its own override, resolved elsewhere).
        public let bodyDepthOverride: String?

        /// Creates a structural reference.
        public init(isHeading: Bool, level: Int, bodyDepthOverride: String?) {
            self.isHeading = isHeading
            self.level = level
            self.bodyDepthOverride = bodyDepthOverride
        }
    }

    // MARK: - Depths

    /// The `StructuralRef` core of `linearize`: resolves each position's depth (heading →
    /// clamped/orphan-corrected level; non-heading → owning heading's resolved level, 0
    /// before the first heading). Input order is taken as collection order.
    ///
    /// - Parameter refs: Structural facts in collection order.
    /// - Returns: One resolved depth per input position.
    public static func resolvedDepths(_ refs: [StructuralRef]) -> [Int] {
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

    // MARK: - Export levels (#1465)

    /// The level each position takes in an EXPORT, which leaves out every heading saved with no text (#1465).
    ///
    /// The owner's decision D4 (2026-09-28): the live preview shows such a heading as "Untitled section", every
    /// export drops it — whether or not documents sit under it — and a named heading under it moves up one level. So
    /// a heading's export level is its resolved level less the number of dropped headings among its ancestors, and a
    /// dropped heading has none. It runs over the resolved depths, never the stored levels, so it inherits the clamp
    /// and the orphan-jump correction; and since a dropped heading lifts everything it owns by the same one level,
    /// what it returns has no orphan jump either.
    ///
    /// Only the emitted levels change. The resolver still runs the section cascades
    /// (`sectionOverrideValues(_:headingValues:)`) over the whole outline, so the documents under a dropped heading
    /// keep the Section defaults it set.
    ///
    /// - Parameters:
    ///   - refs: Structural facts in collection order.
    ///   - untitled: For each position, whether it is a heading the export drops; ignored for any other entry.
    /// - Returns: One level per position: `nil` for a dropped heading, the lifted level for every other heading, and
    ///   for any other entry its owning heading's lifted level (`0` when no kept heading owns it).
    public static func exportLevels(_ refs: [StructuralRef], untitled: [Bool]) -> [Int?] {
        let depths = resolvedDepths(refs)
        // The headings open above the current position, outermost first: each one's resolved level and whether the
        // export drops it.
        var open: [(level: Int, dropped: Bool)] = []
        var levels: [Int?] = []
        levels.reserveCapacity(refs.count)
        for (index, ref) in refs.enumerated() {
            let depth = depths[index]
            if ref.isHeading {
                while let innermost = open.last, innermost.level >= depth { open.removeLast() }
                let lift = open.filter(\.dropped).count
                let dropped = untitled.indices.contains(index) && untitled[index]
                open.append((level: depth, dropped: dropped))
                levels.append(dropped ? nil : max(depth - lift, 1))
            } else {
                // Owned by the innermost open heading, so lifted by every dropped heading open above it — that one
                // included, when it is dropped.
                levels.append(max(depth - open.filter(\.dropped).count, 0))
            }
        }
        return levels
    }

    // MARK: - Section ranges

    /// The `StructuralRef` core of `sectionRange(of:in:)` — the same ownership rule for
    /// callers holding raw structural facts (the move engine, `visibleIndices`). Depths
    /// are resolved defensively via `resolvedDepths`.
    ///
    /// - Parameters:
    ///   - headingIndex: Index of a heading ref in `refs`.
    ///   - refs: Structural facts in collection order.
    /// - Returns: The section's range (degenerate single-item range for non-headings).
    public static func sectionRange(of headingIndex: Int, refs: [StructuralRef]) -> Range<Int> {
        sectionRangeCore(of: headingIndex,
                         isHeading: refs.map(\.isHeading),
                         depths: resolvedDepths(refs))
    }

    /// The single section-ownership walk both `sectionRange` overloads delegate to:
    /// the heading plus everything until (excluding) the next heading at the same or a
    /// shallower resolved depth.
    static func sectionRangeCore(of headingIndex: Int,
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
    public static func movedOrder(_ refs: [StructuralRef], fromIndex: Int, toOffset: Int) -> [Int]? {
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
    public static func visibleIndices(_ refs: [StructuralRef],
                                      collapsedHeadingIndices: Set<Int>) -> [Int] {
        var hidden = Set<Int>()
        for index in collapsedHeadingIndices
        where refs.indices.contains(index) && refs[index].isHeading {
            let range = sectionRange(of: index, refs: refs)
            hidden.formUnion((range.lowerBound + 1) ..< range.upperBound)
        }
        return refs.indices.filter { !hidden.contains($0) }
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
    public static func sectionBodyDepthOverrides(_ refs: [StructuralRef]) -> [String?] {
        sectionOverrideValues(refs, headingValues: refs.map {
            $0.isHeading ? $0.bodyDepthOverride : nil
        })
    }

    /// The **generic ancestor cascade** (Authoring Phase 5): per-position effective
    /// section values for any per-heading override field, by exactly the body-depth
    /// rule. `headingValues[i]` is the heading at position `i`'s own value (`nil` for
    /// non-headings and headings that don't set one); the result at each position is the
    /// nearest *ancestor* heading's non-nil value, walking up the derived tree — a
    /// deeper heading's value shadows a shallower ancestor's, a heading without one
    /// inherits its ancestor's, and a sibling heading with no value resets its section.
    /// `nil` means "no ancestor sets it — fall through to the collection default".
    ///
    /// Type-safe by construction: callers pass typed values (`Bool?`, `UUID?`, raw-value
    /// `String?`), never stringly-encoded field names, and the resolver runs this once
    /// per override field so all of them cascade identically.
    ///
    /// - Parameters:
    ///   - refs: Structural facts in collection order (levels may be raw; they are
    ///     resolved defensively via `resolvedDepths`).
    ///   - headingValues: One optional value per position — the heading's own override
    ///     at heading positions, `nil` elsewhere. Must be `refs.count` long.
    /// - Returns: One effective section value (or `nil`) per input position.
    public static func sectionOverrideValues<Value>(
        _ refs: [StructuralRef],
        headingValues: [Value?]
    ) -> [Value?] {
        let depths = resolvedDepths(refs)
        var overrides: [Value?] = []
        overrides.reserveCapacity(refs.count)
        // Ancestor stack: (resolved level, that heading's own value or nil).
        var stack: [(level: Int, value: Value?)] = []
        for (i, ref) in refs.enumerated() {
            if ref.isHeading {
                let level = depths[i]
                // Pop siblings/deeper sections: the new heading closes every section at
                // its level or deeper, keeping only true ancestors on the stack.
                while let top = stack.last, top.level >= level { stack.removeLast() }
                stack.append((level, headingValues.indices.contains(i) ? headingValues[i] : nil))
            }
            // Nearest ancestor with a set value wins (scan from the deepest up).
            overrides.append(stack.last(where: { $0.value != nil })?.value)
        }
        return overrides
    }
}
