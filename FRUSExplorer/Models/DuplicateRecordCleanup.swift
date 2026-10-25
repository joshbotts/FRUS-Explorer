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
// Archive Visits Phase 2 — the two child types carry DERIVED ids (a namespace hash over
// `planId | key`), so two devices minting state for the same target create the same id
// deterministically: exactly the duplicate this pass exists to collapse, and the reason the
// ids are not random (Archive-Visit-Plan-Design §2a).
extension ArchiveVisitDocument: DeduplicableRecord {}
extension ArchiveVisitTarget: DeduplicableRecord {}
// W-4 (#279) — flat record, dedupeSimple suffices. Ids are random, so this collapses only a
// CloudKit re-import of the SAME record; two devices overriding the same document mint two
// records with different ids, which the apply order resolves (newest assertion applied last).
extension DocumentClassificationOverride: DeduplicableRecord {}
// R-5 P3b-2 — the review ledger carries a DERIVED id (a namespace hash over kind, annotation,
// document and the content hash reviewed), so two devices reviewing the same change at the same
// text mint a byte-identical row. That is exactly the duplicate this pass collapses, and it is
// lossless here: the rows agree in every field, which is why the id includes the hash.
extension AnnotationReview: DeduplicableRecord {}

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
/// the earliest-created record so the choice is stable across devices and CloudKit
/// converges. The tie-break on `id` decides nothing inside a group, whose copies all
/// share it, so copies that also share `createdAt` are kept in the device's own fetch
/// order, which two devices need not share.
///
/// ## What it leaves alone
/// `ResearchNote`, `SavedSearch` and the three research-trail types keep copies under one
/// `id` too, and this pass does not collapse them: for those, every reader takes one copy
/// of each id instead (``DuplicateCopies``, which says why).
///
/// Version history:
///   1.0 — iOS testing fixes: CloudKit duplicate collapse
///   1.1 — #406: `UserTag` now uses a placeholder-aware keeper (a real/renamed tag beats an
///          `OrphanedTagRepair` "Recovered Tag …" placeholder that shares its id); the
///          removal-count log is promoted from `#if DEBUG` to always-on, since deleting synced
///          records is a destructive, CloudKit-propagating event worth a durable trace.
///   1.2 — decision 62 (A15): `isKept(_:over:)`, the keeper order, shared with the Archives Visit
///          overlay's choice of which stored row a target shows.
///   1.3 — #1791: `DuplicateCopies`, the read side, for the five types this pass leaves alone;
///          the caveat no longer says the `id` tie-break decides between copies
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
            + dedupeArchiveVisitPlans(context: context)
            + dedupeSimple(ArchiveVisitDocument.self, context: context)
            + dedupeSimple(ArchiveVisitTarget.self, context: context)
            + dedupeSimple(DocumentClassificationOverride.self, context: context)
            + dedupeSimple(AnnotationReview.self, context: context)
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
    /// Identical to `dedupeSimple` except for keeper selection (see `userTagKeeper`): a real,
    /// non-`"Recovered Tag …"`-named record beats an *un-renamed* `OrphanedTagRepair` placeholder
    /// that shares its id, so if a genuine tag re-materialises with the same id — another device
    /// that still holds it, or CloudKit retention *within the same environment* — it replaces the
    /// stand-in: the real name wins, the id (and every association) preserved. Between two
    /// non-placeholder names (e.g. after the user renames a recovered tag) the keeper falls to the
    /// `createdAt`/id tiebreak, so the *original* record is not guaranteed to win — but the two
    /// rows are the same tag (same id, same associations), so whichever survives loses nothing.
    /// Neither path recovers a tag stranded in a *different* CloudKit environment (e.g. a
    /// Development record that never reached Production); that record cannot re-sync, so its
    /// placeholder keeps the "Recovered Tag" name until the user renames it.
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

    /// Collapses `ArchiveVisitPlan` duplicates, re-parenting both child arrays to the keeper
    /// first — the `dedupeCollections` shape, for the same `.nullify` reason: deleting a
    /// duplicate without re-parenting would orphan its children.
    ///
    /// The keeper is the copy with the most stored state (documents + targets), tie-broken on
    /// earliest creation, so the richer copy survives. Child rows re-parented onto the keeper
    /// may then themselves be duplicates by derived id; the two `dedupeSimple` passes that run
    /// after this in `run(context:)` collapse them in the same launch.
    private static func dedupeArchiveVisitPlans(context: ModelContext) -> Int {
        guard let all = try? context.fetch(FetchDescriptor<ArchiveVisitPlan>()) else { return 0 }
        var deleted = 0
        for (_, group) in Dictionary(grouping: all, by: \.id) where group.count > 1 {
            let keeper = group.max { lhs, rhs in
                let l = (lhs.documents?.count ?? 0) + (lhs.targets?.count ?? 0)
                let r = (rhs.documents?.count ?? 0) + (rhs.targets?.count ?? 0)
                if l != r { return l < r }
                return (lhs.createdAt ?? .distantFuture) > (rhs.createdAt ?? .distantFuture)
            }!
            for extra in group where extra.persistentModelID != keeper.persistentModelID {
                for document in extra.documents ?? [] { document.plan = keeper }
                for target in extra.targets ?? [] { target.plan = keeper }
                context.delete(extra)
                deleted += 1
            }
        }
        return deleted
    }

    /// The stable keeper for a duplicate group: earliest `createdAt`, tie-broken by
    /// a deterministic id ordering so independent devices agree.
    private static func stableKeeper<T: DeduplicableRecord>(_ group: [T]) -> T {
        group.min { isKept(($0.createdAt, $0.id), over: ($1.createdAt, $1.id)) }!
    }

    /// Whether a record created at `record.createdAt` with id `record.id` is kept over `other`:
    /// the earlier creation, a missing date sorting last, then the lower id, so independent
    /// devices agree. The order ``stableKeeper(_:)`` keeps a duplicate by, and the one an Archives
    /// Visit target shows one of several stored rows by (`ArchiveVisitTargetKeys.shownRow`,
    /// decision 62), so the row a target shows is the one this pass would keep.
    nonisolated static func isKept(_ record: (createdAt: Date?, id: UUID),
                                   over other: (createdAt: Date?, id: UUID)) -> Bool {
        let l = record.createdAt ?? .distantFuture
        let r = other.createdAt ?? .distantFuture
        if l != r { return l < r }
        return record.id.uuidString < other.id.uuidString
    }
}

// MARK: - DuplicateCopies

/// One copy of each id, for whatever shows, counts or exports records (#1791). Nothing here
/// deletes.
///
/// ## Why five types are read this way rather than collapsed
/// `ResearchNote`, `SavedSearch` and the three research-trail types (`ReadingHistoryEntry`,
/// `SearchHistoryEntry`, `ExportHistoryEntry`) keep copies under one `id`, and
/// ``DuplicateRecordCleanup`` leaves them in the store on purpose. Its keeper is the earliest
/// `createdAt`, then the lower `id`. Every copy in a group shares the `id`, and exact copies share
/// the `createdAt`, so the copy it keeps is whichever the device's own fetch returns first. It runs
/// at launch, before any import arrives, so a device that updates later can keep a different copy
/// and delete the one the first device kept, and after sync no copy is left. A tag can be rebuilt
/// from its assignments (`OrphanedTagRepair`); a note cannot, and contract D5 forbids anything from
/// silently deleting the trail (`HistoryRowID`).
///
/// Measured on 2026-10-25 in the owner's library: copies in exactly these five types, each an exact
/// copy in every field and its own CloudKit record, and none made after 2026-07-28. The trail's came
/// from R-2a's migration running on two devices, and the rest from re-uploads in June and July.
///
/// So the copies stay, and what reads these types takes one copy of each id: the lists and their
/// counts, Data & Recovery's **Contents**, the JSON, Markdown and Zotero exports and the indexed note
/// text. An edit to a note or a saved search is written to every copy, so the copies keep one text,
/// and a delete removes every copy (`ResearchNote.copies(of:in:)`, `SavedSearch.copies(of:in:)`).
/// The History pane already shows each copy of a trail row with an identity of its own and deletes
/// every copy (`HistoryRowID`, `HistoryTrailAdmin`), and is unchanged.
///
/// ## Which copy
/// The one last modified, for a type that records it; among copies modified at the same moment,
/// which exact copies are, the first in the caller's order. It stands where its id first appears.
///
/// Version history:
///   1.0 — #1791: initial implementation
enum DuplicateCopies {

    /// `records` with one copy of each id, in the order their ids first appear.
    ///
    /// - Parameters:
    ///   - records: The records, copies included, in the caller's order.
    ///   - id: A record's identity.
    ///   - lastModified: When a record was last changed, for a type that records it: a later date
    ///     is kept over an earlier one, and a missing date counts as the earliest. Without it, the
    ///     first copy is kept.
    /// - Returns: One record per id.
    static func oneEach<Record>(_ records: [Record], id: (Record) -> UUID,
                               lastModified: ((Record) -> Date?)? = nil) -> [Record] {
        var position: [UUID: Int] = [:]
        position.reserveCapacity(records.count)
        var kept: [Record] = []
        kept.reserveCapacity(records.count)
        for record in records {
            let key = id(record)
            guard let index = position[key] else {
                position[key] = kept.count
                kept.append(record)
                continue
            }
            if let lastModified,
               (lastModified(record) ?? .distantPast) > (lastModified(kept[index]) ?? .distantPast) {
                kept[index] = record
            }
        }
        return kept
    }

    /// How many distinct ids `records` holds: what `oneEach(_:id:lastModified:)` would return.
    ///
    /// - Parameters:
    ///   - records: The records, copies included.
    ///   - id: A record's identity.
    /// - Returns: The number of distinct ids.
    static func count<Record>(_ records: [Record], id: (Record) -> UUID) -> Int {
        Set(records.map(id)).count
    }
}
