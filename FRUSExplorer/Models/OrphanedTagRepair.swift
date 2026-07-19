// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - OrphanedTagRepair

/// Reconstructs a visible, renameable `UserTag` for any tag id that is still
/// referenced by a `DocumentTagAssignment` or a `ResearchNote.userTagIds` but has
/// no matching `UserTag` record — i.e. an *orphaned* tag association.
///
/// ## Why this exists (issue #406)
/// Tag→document and tag→note links are stored as plain `UUID`s (`DocumentTagAssignment.tagId`,
/// `ResearchNote.userTagIds`), not SwiftData `@Relationship`s, so SwiftData's object graph
/// cannot cascade or clean them up. When a `UserTag` disappears by any path — a delete that
/// pre-dated the cascade fix, a `DuplicateRecordCleanup` collapse, or a partial CloudKit
/// import — its associations survive as dangling references that no UI surface can render
/// (the tag has no name to show, and no picker lists a deleted tag). The user sees the tags
/// and their document annotations simply vanish, while the export still lists the documents
/// against unknown tag ids.
///
/// This pass heals that state: it re-inserts a `UserTag` **using the exact orphaned id**, so
/// every consumer — which keys on `tagId == UserTag.id` — re-attaches automatically. The
/// original human-readable **name is unrecoverable** once the record is gone (it lived only
/// on the deleted `UserTag`), so the reconstruction uses a deterministic
/// `"Recovered Tag <id-prefix>"` placeholder the user can rename via the tag manager.
///
/// ## Safety contract
/// The pass is **purely additive and id-preserving**, so it can never itself create a new
/// orphan or delete anything. It is safe to run repeatedly because it is *existence-guarded*
/// (it only inserts for ids that have no `UserTag`). All derived values — the placeholder
/// name and `createdAt` — are computed deterministically from already-synced data (the id and
/// the earliest referencing record's date), **never** from `Date.now`, so two devices that run
/// the pass before CloudKit converges emit byte-identical placeholders and
/// `DuplicateRecordCleanup` collapses the accidental duplicate with no cross-device delete war.
///
/// The placeholder `createdAt` is the earliest referencing record's date. A genuine returning
/// `UserTag` is always created *before* its own assignments/notes, so its `createdAt` is
/// earlier — meaning `DuplicateRecordCleanup`'s earliest-`createdAt` keeper rule (reinforced by
/// its explicit non-placeholder preference) keeps the **real** record and drops the placeholder
/// if the true tag ever re-syncs from CloudKit retention. Real name wins, id preserved,
/// associations intact.
///
/// ## When it runs
/// `FRUSExplorerApp.bootApp()` runs it **after** the initial CloudKit import has settled — never
/// in the synchronous boot window, where a not-yet-imported tag would look like an orphan and be
/// wrongly reconstructed (and pushed to CloudKit) as a duplicate of a live record. On local-only
/// stores (CloudKit disabled) the local store is authoritative, so it runs once at boot.
///
/// Version history:
///   1.0 — issue #406: initial implementation — reconstruct orphaned user-tag associations
@MainActor
enum OrphanedTagRepair {

    /// Prefix of the deterministic placeholder name given to a reconstructed tag.
    /// Also the marker `DuplicateRecordCleanup` uses to prefer a real record over a placeholder.
    static let placeholderNamePrefix = "Recovered Tag "

    /// Whether `name` is an auto-generated recovery placeholder (vs. a real/renamed tag).
    static func isPlaceholderName(_ name: String) -> Bool {
        name.hasPrefix(placeholderNamePrefix)
    }

    /// A reconstruction the repair would perform: the orphaned id to re-materialise, the
    /// deterministic placeholder name, and the `createdAt` to stamp (earliest referencing date).
    struct Placeholder: Equatable, Sendable {
        /// The orphaned tag id — the reconstructed `UserTag` MUST carry this exact id so the
        /// existing `DocumentTagAssignment` / `ResearchNote.userTagIds` references re-attach.
        let id: UUID
        /// Deterministic `"Recovered Tag <id-prefix>"` label (never derived from `Date.now`).
        let name: String
        /// Earliest referencing record date — always ≥ a genuine tag's own `createdAt`, so a real
        /// record wins the dedupe keeper contest if it ever returns.
        let createdAt: Date
    }

    /// Pure, deterministic core: given the three reference sources, returns one `Placeholder`
    /// per orphaned id (referenced but absent from `existingTagIds`), sorted by id for a stable
    /// order. Factored out so it can be unit-tested without a live container.
    static func placeholders(
        assignments: [DocumentTagAssignment],
        notes: [ResearchNote],
        existingTagIds: Set<UUID>
    ) -> [Placeholder] {
        // Earliest referencing date per orphaned id — deterministic across devices.
        var earliest: [UUID: Date] = [:]
        func consider(_ id: UUID, _ date: Date?) {
            guard !existingTagIds.contains(id) else { return }
            let candidate = date ?? .distantFuture
            if let current = earliest[id] {
                earliest[id] = min(current, candidate)
            } else {
                earliest[id] = candidate
            }
        }
        for assignment in assignments { consider(assignment.tagId, assignment.createdAt) }
        for note in notes {
            for tagId in note.userTagIds { consider(tagId, note.createdAt) }
        }
        return earliest
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { id, date in
                Placeholder(
                    id: id,
                    name: placeholderNamePrefix + String(id.uuidString.prefix(8)),
                    createdAt: date
                )
            }
    }

    /// Reconstructs placeholders for every orphaned tag id, inserts them, and saves.
    ///
    /// Idempotent and additive: a no-op when there are no orphans, and safe to call on every
    /// launch/import. Returns the number of placeholders created.
    @discardableResult
    static func run(context: ModelContext) -> Int {
        guard
            let tags = try? context.fetch(FetchDescriptor<UserTag>()),
            let assignments = try? context.fetch(FetchDescriptor<DocumentTagAssignment>()),
            let notes = try? context.fetch(FetchDescriptor<ResearchNote>())
        else { return 0 }

        let existing = Set(tags.map(\.id))
        let toCreate = placeholders(assignments: assignments, notes: notes, existingTagIds: existing)
        guard !toCreate.isEmpty else { return 0 }

        for placeholder in toCreate {
            let tag = UserTag(name: placeholder.name)
            // Overwrite the fresh identity/timestamps `UserTag.init` assigned: the placeholder
            // MUST carry the orphaned id (that is what re-attaches the associations), and its
            // dates are the deterministic earliest-referencing value, not `Date.now`.
            tag.id = placeholder.id
            tag.createdAt = placeholder.createdAt
            tag.lastModified = placeholder.createdAt
            context.insert(tag)
        }
        try? context.save()

        // Always-on (not #if DEBUG): reconstructing user records is a CloudKit-propagating
        // recovery event; a persistent log line is the post-hoc evidence that #406 healed.
        // Mirrors the always-on CloudKit-failure logging in `ModelContainer+FRUS`.
        print("[OrphanedTagRepair] Reconstructed \(toCreate.count) orphaned user tag(s).")
        return toCreate.count
    }
}
