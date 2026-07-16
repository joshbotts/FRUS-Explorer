// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - CustomVolumeScope

/// A user-defined, named set of volumes usable as a search/analytics scope (#258).
///
/// Design per the reviewed sketch (`Planning/258-Custom-Volume-Scopes-Design.md`, PR #327):
/// a **flat, all-defaulted record whose membership is a `[String]` of manifest `volumeId`s** —
/// the `Collection.projectIds` value-array pattern. No child `@Model`, no relationship, no
/// non-optional custom enum (the #297 trap). Membership is a **static snapshot** (§8-Q2(a));
/// ids are **raw manifest ids** (§8-Q1(a)) so a scope keeps its meaning as the user downloads
/// more volumes — FTS surfaces intersect with the indexed set at resolution time, via
/// `CustomScopeResolver`, whose `IndexedResolution` contract is this feature's load-bearing
/// invariant.
///
/// ## CloudKit compatibility
/// All properties have default values or are optional (the repo's hard rule — see
/// `SavedSearch`). Enrolled in `frusModelTypes` (**a new CloudKit record type: deploy the
/// schema to Production before shipping**, per the standing note in `ModelContainer+FRUS`)
/// and in `DuplicateRecordCleanup` (`dedupeSimple` — no children to re-parent), because a
/// schema-change import can materialize duplicate records sharing one logical `id`.
///
/// ## Editing rule
/// Replace `volumeIds` **wholesale** on every edit — never mutate the array in place
/// (`Project.swift`'s shipped warning: in-place array mutation has a documented sync hazard).
/// Deduplicate on write; order is not meaningful.
///
/// Version history:
///   1.0 — #258 Phase 1: initial implementation (model + resolver + editor + iOS Search
///          + iOS management pane)
@Model final class CustomVolumeScope {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display

    /// User-visible scope name. Not unique — duplicates are allowed and disambiguated by
    /// `id` (uniqueness across CloudKit devices is un-guaranteeable; see the sketch §3).
    var name: String = ""

    // MARK: - Membership

    /// Member volumes as **raw manifest `volumeId`s** (§8-Q1(a)): stable across downloads,
    /// meaningful to both the indexed-corpus and whole-manifest grains. May legitimately
    /// name volumes the user has not downloaded — which is exactly why FTS consumers must
    /// go through `CustomScopeResolver.indexedResolution` and never treat the raw array as
    /// a query filter directly.
    var volumeIds: [String] = []

    // MARK: - Bookkeeping

    /// Creation timestamp; optional for CloudKit schema compatibility. Also the
    /// `DuplicateRecordCleanup` stable-keeper key.
    var createdAt: Date?
    /// Last membership/name edit; optional for CloudKit schema compatibility.
    var lastModified: Date?

    /// Creates a named scope. Membership is deduplicated and sorted on write.
    init(name: String, volumeIds: [String] = []) {
        self.id = UUID()
        self.name = name
        self.volumeIds = Array(Set(volumeIds)).sorted()
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

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
enum IndexedResolution: Equatable {
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
enum CustomScopeResolver {

    /// FTS-grain resolution: intersect membership with the indexed set, with
    /// empty-after-intersection as an **explicit, non-passthrough outcome**.
    ///
    /// - Parameters:
    ///   - memberVolumeIds: The scope's raw membership (may include un-downloaded ids).
    ///   - indexed: The currently indexed volume ids (`AppState.indexedVolumeIds`).
    /// - Returns: `.resolved` (non-empty) or `.noIndexedMembers`. (`.scopeUnavailable` is
    ///   produced by identity-based lookups — `resolve(scopeId:context:indexed:)` — when
    ///   the referenced record no longer exists.)
    static func indexedResolution(memberVolumeIds: [String],
                                  indexed: Set<String>) -> IndexedResolution {
        let hits = Set(memberVolumeIds).intersection(indexed)
        return hits.isEmpty ? .noIndexedMembers : .resolved(hits)
    }

    /// Series/manifest-grain resolution: raw membership filtered to ids the current
    /// manifest actually knows, so a dangling id (manifest churn — measured byte-stable
    /// across all six historical revisions, tolerated anyway) is skipped rather than
    /// silently counted.
    static func manifestVolumeIds(memberVolumeIds: [String],
                                  manifestIds: Set<String>) -> Set<String> {
        Set(memberVolumeIds).intersection(manifestIds)
    }

    /// Identity-based FTS-grain resolution for adopters that persist a scope *reference*
    /// (`.custom(UUID)` cases — word cloud signatures, future bars): dereferences the id
    /// and maps a missing record to `.scopeUnavailable` (the deletion story — sketch §8),
    /// never to an unscoped query.
    @MainActor
    static func resolve(scopeId: UUID, context: ModelContext,
                        indexed: Set<String>) -> IndexedResolution {
        var descriptor = FetchDescriptor<CustomVolumeScope>(
            predicate: #Predicate { $0.id == scopeId })
        descriptor.fetchLimit = 1
        guard let scope = try? context.fetch(descriptor).first else { return .scopeUnavailable }
        return indexedResolution(memberVolumeIds: scope.volumeIds, indexed: indexed)
    }
}
