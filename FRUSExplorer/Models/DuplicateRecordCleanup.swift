// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

/// A user-data record this cleanup can collapse: an `id` to group by and a
/// `createdAt` to pick a stable keeper.
fileprivate protocol DeduplicableRecord: PersistentModel {
    var id: UUID { get }
    var createdAt: Date? { get }
}

extension UserTag: DeduplicableRecord {}
extension Project: DeduplicableRecord {}
extension CollectionEntry: DeduplicableRecord {}
extension CustomVolumeScope: DeduplicableRecord {}   // #258 — flat record, dedupeSimple suffices

/// Collapses duplicate user-data records that share the same `id`.
///
/// ## Why duplicates exist
/// `UserTag`, `Project`, `Collection`, and `CollectionEntry` carry a `var id: UUID`
/// but **cannot** declare `@Attribute(.unique)` — SwiftData backed by
/// `NSPersistentCloudKitContainer` doesn't support unique constraints. So a
/// CloudKit import (notably the initial sync after a schema change) can
/// materialise two store records for one logical item, sharing its `id`. The app
/// keys relationships on the `id` UUID, so the duplicates behave identically
/// ("selecting one selects the other"), but every `@Query` returns both, so they
/// appear twice in lists.
///
/// ## What this does
/// Run at boot: for each model, group by `id` and keep one record per group,
/// deleting the rest. For `Collection`, the keeper is the record with the most
/// entries (so the richer copy survives) and the duplicates' `CollectionEntry`
/// children are re-parented to the keeper first — `documentEntries` is a `.nullify`
/// relationship, so deleting a duplicate would otherwise orphan its entries.
/// `CollectionEntry` duplicates are then collapsed by `id` as well.
///
/// ## Caveat
/// Deletion is the right call for genuine duplicates (byte-identical copies of one
/// logical record). The remaining edge case — two devices independently creating
/// the *same* item offline — is rare for these app-created records; this pass keeps
/// the earliest-created record (tie-broken deterministically) so the choice is
/// stable across devices and CloudKit converges.
///
/// Version history:
///   1.0 — iOS testing fixes: CloudKit duplicate collapse
///   1.1 — #406: `UserTag` now uses a placeholder-aware keeper (a real/renamed tag beats an
///          `OrphanedTagRepair` "Recovered Tag …" placeholder that shares its id); the
///          removal-count log is promoted from `#if DEBUG` to always-on, since deleting synced
///          records is a destructive, CloudKit-propagating event worth a durable trace.
@MainActor
enum DuplicateRecordCleanup {

    /// Runs the cleanup and saves. Idempotent and a no-op when there are no
    /// duplicates, so it's safe to call on every launch.
    static func run(context: ModelContext) {
        let removed = dedupeUserTags(context: context)
            + dedupeSimple(Project.self, context: context)
            + dedupeCollections(context: context)
            + dedupeSimple(CollectionEntry.self, context: context)
            + dedupeSimple(CustomVolumeScope.self, context: context)
        guard removed > 0 else { return }
        try? context.save()
        // Always-on (not #if DEBUG): deleting synced user records is a destructive,
        // CloudKit-propagating operation; a persistent log line is the only post-hoc evidence
        // if a pass ever removes more than expected (cf. #406). Mirrors the always-on
        // CloudKit-failure logging in `ModelContainer+FRUS`.
        print("[DuplicateRecordCleanup] Removed \(removed) duplicate record(s).")
    }

    /// Collapses duplicate `UserTag` records (same `id`), keeping a placeholder-aware keeper.
    ///
    /// Identical to `dedupeSimple` except for keeper selection: a real (or user-renamed) tag
    /// always beats an `OrphanedTagRepair` `"Recovered Tag …"` placeholder that shares its id, so
    /// if a genuine tag ever re-syncs from CloudKit retention it replaces the stand-in the repair
    /// created — the real name wins, the id (and therefore every association) is preserved.
    private static func dedupeUserTags(context: ModelContext) -> Int {
        guard let all = try? context.fetch(FetchDescriptor<UserTag>()) else { return 0 }
        var deleted = 0
        for (_, group) in Dictionary(grouping: all, by: \.id) where group.count > 1 {
            let keeper = userTagKeeper(group)
            for extra in group where extra.persistentModelID != keeper.persistentModelID {
                context.delete(extra)
                deleted += 1
            }
        }
        return deleted
    }

    /// The stable keeper for a duplicate `UserTag` group: prefer a non-placeholder (real) name,
    /// then earliest `createdAt`, then a deterministic id ordering so independent devices agree.
    private static func userTagKeeper(_ group: [UserTag]) -> UserTag {
        group.min { lhs, rhs in
            let lhsPlaceholder = OrphanedTagRepair.isPlaceholderName(lhs.name)
            let rhsPlaceholder = OrphanedTagRepair.isPlaceholderName(rhs.name)
            if lhsPlaceholder != rhsPlaceholder { return !lhsPlaceholder }  // real record sorts first (kept)
            let l = lhs.createdAt ?? .distantFuture
            let r = rhs.createdAt ?? .distantFuture
            if l != r { return l < r }
            return lhs.id.uuidString < rhs.id.uuidString
        }!
    }

    /// Keeps the stable keeper per `id`, deleting the rest. Returns the count deleted.
    private static func dedupeSimple<T: DeduplicableRecord>(_ type: T.Type, context: ModelContext) -> Int {
        guard let all = try? context.fetch(FetchDescriptor<T>()) else { return 0 }
        var deleted = 0
        for (_, group) in Dictionary(grouping: all, by: \.id) where group.count > 1 {
            let keeper = stableKeeper(group)
            for extra in group where extra.persistentModelID != keeper.persistentModelID {
                context.delete(extra)
                deleted += 1
            }
        }
        return deleted
    }

    /// Collapses `Collection` duplicates, re-parenting entries to the keeper first.
    private static func dedupeCollections(context: ModelContext) -> Int {
        guard let all = try? context.fetch(FetchDescriptor<Collection>()) else { return 0 }
        var deleted = 0
        for (_, group) in Dictionary(grouping: all, by: \.id) where group.count > 1 {
            // Prefer the copy with the most entries; tie-break on earliest creation.
            let keeper = group.max { lhs, rhs in
                let l = lhs.documentEntries?.count ?? 0
                let r = rhs.documentEntries?.count ?? 0
                if l != r { return l < r }
                return (lhs.createdAt ?? .distantFuture) > (rhs.createdAt ?? .distantFuture)
            }!
            for extra in group where extra.persistentModelID != keeper.persistentModelID {
                for entry in extra.documentEntries ?? [] {
                    entry.collection = keeper
                }
                context.delete(extra)
                deleted += 1
            }
        }
        return deleted
    }

    /// The stable keeper for a duplicate group: earliest `createdAt`, tie-broken by
    /// a deterministic id ordering so independent devices agree.
    private static func stableKeeper<T: DeduplicableRecord>(_ group: [T]) -> T {
        group.min { lhs, rhs in
            let l = lhs.createdAt ?? .distantFuture
            let r = rhs.createdAt ?? .distantFuture
            if l != r { return l < r }
            return lhs.id.uuidString < rhs.id.uuidString
        }!
    }
}
