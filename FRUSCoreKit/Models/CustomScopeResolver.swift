// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - IndexedResolution

/// The FTS-grain resolution contract (#258, review finding — HIGH, found independently by
/// two lenses): **never a bare, possibly-empty set.**
///
/// Every pre-existing scope consumer in the app treats an empty/`nil` volume set as
/// "no filter" (e.g. `SearchViewModel` maps empty → `nil` → whole corpus) — so a custom
/// scope whose members are not yet downloaded would silently *invert* into a whole-corpus
/// query under the scope's own label. This enum makes that state unrepresentable: an FTS
/// surface either gets a non-empty set, or an explicit outcome it must render as an empty
/// state / warning — never pass through as unscoped.
///
/// Version history:
///   1.0 — #258 Phase 1: initial implementation, in the app's `Models/CustomVolumeScope.swift`
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, unchanged,
///          for the web edition's volume scopes
public enum IndexedResolution: Equatable, Sendable {
    /// The scope resolves to these indexed volumes. Non-empty by construction.
    case resolved(Set<String>)
    /// The scope has members, but none are indexed yet — show "no volumes of this scope
    /// are indexed" (or warn in the picker); NEVER fall back to unscoped.
    case noIndexedMembers
    /// The scope reference did not resolve (deleted on another device; dangling
    /// `.custom(UUID)`) — show "this scope is no longer available"; NEVER unscoped.
    case scopeUnavailable
}

// MARK: - CustomScopeResolver

/// Resolves a `CustomVolumeScope` to a volume-id set at one of the two grains the scope
/// census identified (sketch §2): **indexed** (FTS surfaces — search, analytics) and
/// **manifest** (the Series dashboards, which render undownloaded volumes).
///
/// The grain methods are pure static functions over plain values so the `IndexedResolution`
/// invariant is unit-testable without a SwiftData container.
///
/// Version history:
///   1.0 — #258 Phase 1: initial implementation, in the app's `Models/CustomVolumeScope.swift`
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with its two
///          grains unchanged, for the web edition's volume scopes; the identity-based
///          `resolve(scopeId:context:indexed:)`, which reads the store, stays in the app's extension
public enum CustomScopeResolver {

    /// FTS-grain resolution: intersect membership with the indexed set, with
    /// empty-after-intersection as an **explicit, non-passthrough outcome**.
    ///
    /// - Parameters:
    ///   - memberVolumeIds: The scope's raw membership (may include un-downloaded ids).
    ///   - indexed: The currently indexed volume ids (`AppState.indexedVolumeIds`).
    /// - Returns: `.resolved` (non-empty) or `.noIndexedMembers`. (`.scopeUnavailable` is
    ///   produced by identity-based lookups — `resolve(scopeId:context:indexed:)` — when
    ///   the referenced record no longer exists.)
    public static func indexedResolution(memberVolumeIds: [String],
                                         indexed: Set<String>) -> IndexedResolution {
        let hits = Set(memberVolumeIds).intersection(indexed)
        return hits.isEmpty ? .noIndexedMembers : .resolved(hits)
    }

    /// Series/manifest-grain resolution: raw membership filtered to ids the current
    /// manifest actually knows, so a dangling id (manifest churn — measured byte-stable
    /// across all six historical revisions, tolerated anyway) is skipped rather than
    /// silently counted.
    public static func manifestVolumeIds(memberVolumeIds: [String],
                                         manifestIds: Set<String>) -> Set<String> {
        Set(memberVolumeIds).intersection(manifestIds)
    }
}
