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
/// Design per the reviewed sketch (`Planning/Completed/258-Custom-Volume-Scopes-Design.md`, PR #327):
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
///   1.1 — #258 Phase 4: `ScopeFacets` pure facet→volume-set helpers (subject / manifest
///          tag / coverage+editor); #332 review: subject-catalog name derivation made
///          order-deterministic
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): `IndexedResolution` and the resolver's two
///          grains are FRUSCoreKit's; `resolve(scopeId:context:indexed:)` stays here, in an extension.
///          No stored property changed
///   1.3 — 2026-11-14 (FRUS Explorer Light, S21g's follow-up): `ScopeFacets` is FRUSCoreKit's, public and
///          unchanged, beside the resolver (`Models/CustomScopeResolver.swift`)
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

// MARK: - CustomScopeResolver + the store

// `IndexedResolution` and the two grains of `CustomScopeResolver` (`indexedResolution` and
// `manifestVolumeIds`) moved to FRUSCoreKit for FRUS Explorer Light (S17b):
// `FRUSCoreKit/Models/CustomScopeResolver.swift`. The identity-based resolution reads the store, so it
// stays here.

extension CustomScopeResolver {

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

// MARK: - ScopeFacets

// `ScopeFacets`, the facets' pure volume-set rules, moved to FRUSCoreKit for FRUS Explorer Light (S21g's
// follow-up): `FRUSCoreKit/Models/CustomScopeResolver.swift`.
