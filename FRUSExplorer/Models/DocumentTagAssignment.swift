// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - DocumentTagAssignment

/// A direct tag-to-document association created when the user taps "Tag Document"
/// in the document view toolbar.
///
/// ## Why this model exists
/// `document_cache.user_tag_ids` (the SQLite FTS5 index) was the original storage
/// for direct tag assignments, but it is a local-only derived artifact that does not
/// sync via CloudKit. `DocumentTagAssignment` stores the same information in SwiftData
/// so it participates in the existing CloudKit private-database sync alongside
/// `UserTag` and `ResearchNote` records.
///
/// ## Relationship to `ResearchNote.userTagIds`
/// These are independent annotation types:
/// - `ResearchNote.userTagIds` — tags applied through the note editor (carries note text)
/// - `DocumentTagAssignment` — tags applied directly to a document (no note body)
///
/// Both are reflected in the Research window and FTS5 search. Neither depends on the other.
///
/// ## CloudKit compatibility
/// - All stored properties have default values
/// - No `@Relationship` declarations (avoids cascade issues)
/// - `tagId` is a plain `UUID`, not a `@Relationship` to `UserTag`, matching the same
///   pattern used by `ResearchNote.userTagIds: [UUID]`
///
/// ## FTS5 synchronisation
/// `document_cache.user_tag_ids` is the index's copy of these records, one string per document.
/// ``reconcileTagColumn(container:pipeline:sweepingStaleRows:)`` brings it level with them at
/// launch and each time an iCloud import settles, and since #1591 it also clears the rows of
/// documents that no longer have an assignment.
///
/// Version history:
///   1.0 — Session 130: initial implementation, replacing `document_cache.user_tag_ids`
///          as the canonical store for direct document-level tag associations
///   1.1 — Session 2026-10-09: #1591 — `tagColumnPlan`, `reconcileTagColumn` and
///          `reindexTagColumn`: the launch pass wrote the column for documents that had an
///          assignment and never cleared it for one that had lost its last
@Model final class DocumentTagAssignment {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    /// The volume containing the tagged document.
    var volumeId: String = ""

    /// The document within the volume (e.g. `"d42"`).
    var documentId: String = ""

    // MARK: - Tag Reference

    /// The `UserTag.id` this assignment links to.
    ///
    /// Stored as a plain `UUID` (not a `@Relationship`) for CloudKit compatibility,
    /// matching the pattern used by `ResearchNote.userTagIds`.
    var tagId: UUID = UUID()

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date? = nil

    // MARK: - Initialiser

    init(volumeId: String, documentId: String, tagId: UUID) {
        self.id         = UUID()
        self.volumeId   = volumeId
        self.documentId = documentId
        self.tagId      = tagId
        self.createdAt  = .now

        #if DEBUG
        print("[SwiftData] DocumentTagAssignment created: \(volumeId)/\(documentId) tag=\(tagId)")
        #endif
    }
}

// MARK: - The index's tag column (#1591)

extension DocumentTagAssignment {

    /// One document's key in the index.
    typealias DocumentKey = (volumeId: String, documentId: String)

    /// The column's value for a set of tags: their ids in a fixed order, a space between, or `nil`
    /// for none. The order is fixed so that two passes over the same assignments write one string.
    nonisolated static func tagColumnValue(_ tagIds: Set<UUID>) -> String? {
        tagIds.isEmpty ? nil : tagIds.map(\.uuidString).sorted().joined(separator: " ")
    }

    /// What bringing `document_cache.user_tag_ids` level with the assignments takes: the rows to
    /// write and the rows to clear. The tag column's twin of `ResearchNote.noteTextPlan`.
    ///
    /// **A row is written only when its tags differ as a SET.** The column's writers do not agree
    /// on an order (the tag picker writes the order of its selection), and a rewrite of a
    /// `document_cache` row re-syncs its FTS5 rows, so a row that already names the document's
    /// tags is left as it is.
    ///
    /// **The clear half has the note plan's floor**, for the note plan's reason: an empty or
    /// unreadable assignment set while the index still carries rows is far likelier to be a store
    /// that was reset, swapped or has not loaded than a reader who removed every tag, and clearing
    /// on it would empty every tagged row at the moment the tags are safe in iCloud and have not
    /// arrived. So nothing is cleared when there is no assignment at all. The cost is the same as
    /// the note plan's: a reader whose LAST assignment anywhere is removed on another device keeps
    /// that one row. A tag deleted in Settings does not wait for this: `UserTagAdmin.deleteCascading`
    /// rewrites the rows it touched at once.
    ///
    /// **A clear removes an id no assignment accounts for, whoever wrote it.** Until #1275 the note
    /// editor pushed a note's tags into this per-document column; a row that still carries such an
    /// id, on a document with no assignment, is cleared with the rest.
    ///
    /// - Parameters:
    ///   - assignments: Every assignment in the store, or `nil` when they could not be read, in
    ///     which case nothing is planned.
    ///   - carrying: The rows whose column is not NULL, with what each holds:
    ///     `IndexingPipeline.documentsWithUserTagIds()`.
    ///   - sweepingStaleRows: Whether to plan clears. See `reconcileTagColumn` for when.
    /// - Returns: The rows to write, sorted by document, and the rows to clear, in `carrying`'s order.
    nonisolated static func tagColumnPlan(
        for assignments: [(volumeId: String, documentId: String, tagId: UUID)]?,
        carrying: [(volumeId: String, documentId: String, userTagIds: String)],
        sweepingStaleRows: Bool
    ) -> (writes: [(volumeId: String, documentId: String, userTagIds: String)],
          clears: [DocumentKey]) {
        guard let assignments else { return (writes: [], clears: []) }
        struct Key: Hashable { let volumeId: String; let documentId: String }
        var live: [Key: Set<UUID>] = [:]
        for assignment in assignments where !assignment.volumeId.isEmpty && !assignment.documentId.isEmpty {
            live[Key(volumeId: assignment.volumeId, documentId: assignment.documentId), default: []]
                .insert(assignment.tagId)
        }
        var stored: [Key: Set<UUID>] = [:]
        for row in carrying {
            stored[Key(volumeId: row.volumeId, documentId: row.documentId)] =
                Set(row.userTagIds.split(separator: " ").compactMap { UUID(uuidString: String($0)) })
        }
        let writes = live
            .filter { stored[$0.key] != $0.value }
            .compactMap { key, tagIds in
                tagColumnValue(tagIds).map { (volumeId: key.volumeId, documentId: key.documentId, userTagIds: $0) }
            }
            .sorted { ($0.volumeId, $0.documentId) < ($1.volumeId, $1.documentId) }
        // The floor: no assignment at all plans no clear.
        guard sweepingStaleRows, !live.isEmpty else { return (writes: writes, clears: []) }
        let clears = carrying
            .filter { live[Key(volumeId: $0.volumeId, documentId: $0.documentId)] == nil }
            .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        return (writes: writes, clears: clears)
    }

    /// Brings the index's tag column level with the assignments in `container`, and, when asked,
    /// clears the rows no assignment accounts for. The only caller of
    /// ``tagColumnPlan(for:carrying:sweepingStaleRows:)``, and the tag column's twin of
    /// `ResearchNote.reconcileNoteText(container:pipeline:sweepingStaleRows:)`.
    ///
    /// The sweep is a parameter for the reason it is one there. The write half is safe anywhere.
    /// The clear half's floor is disarmed by a store that is PARTLY loaded: one assignment arrived
    /// from iCloud makes the set non-empty, and every document whose assignment is in a later batch
    /// would be cleared until the next pass wrote it back. So with iCloud on the sweep runs when an
    /// import has settled, and at launch only with iCloud off, when no import can arrive.
    ///
    /// - Parameters:
    ///   - container: The model container to read the assignments from.
    ///   - pipeline: The index to write through.
    ///   - sweepingStaleRows: Whether to apply the clear half.
    /// - Returns: How many rows were written and how many cleared.
    @discardableResult
    nonisolated static func reconcileTagColumn(
        container: ModelContainer,
        pipeline: IndexingPipeline,
        sweepingStaleRows: Bool
    ) async -> (written: Int, cleared: Int) {
        let context = ModelContext(container)
        // Both sides of the subtraction before any suspension, as the note reconcile reads its own.
        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>()))?
            .map { (volumeId: $0.volumeId, documentId: $0.documentId, tagId: $0.tagId) }
        let plan = tagColumnPlan(for: assignments,
                                 carrying: (try? pipeline.documentsWithUserTagIds()) ?? [],
                                 sweepingStaleRows: sweepingStaleRows)
        for row in plan.clears {
            try? await pipeline.updateUserTagIds(volumeId: row.volumeId, documentId: row.documentId,
                                                 userTagIds: nil)
        }
        for row in plan.writes {
            try? await pipeline.updateUserTagIds(volumeId: row.volumeId, documentId: row.documentId,
                                                 userTagIds: row.userTagIds)
        }
        return (written: plan.writes.count, cleared: plan.clears.count)
    }

    /// Rewrites the tag column of each of `documents` from the assignments it still has, clearing
    /// it for a document that has none.
    ///
    /// For a caller that has just removed assignments from documents it can name, and saved:
    /// `UserTagAdmin.deleteCascading`. It has no floor, because the caller, not a subtraction,
    /// says which rows changed. It re-reads rather than being told, since a document can carry
    /// other tags. When the assignments cannot be read, nothing is written.
    ///
    /// - Parameters:
    ///   - documents: The documents whose rows to rewrite.
    ///   - container: The model container to read their remaining assignments from.
    ///   - pipeline: The index to write through.
    nonisolated static func reindexTagColumn(
        documents: [DocumentKey],
        container: ModelContainer,
        pipeline: IndexingPipeline
    ) async {
        guard !documents.isEmpty,
              let assignments = try? ModelContext(container).fetch(FetchDescriptor<DocumentTagAssignment>())
        else { return }
        var remaining: [String: Set<UUID>] = [:]
        for assignment in assignments {
            remaining["\(assignment.volumeId)/\(assignment.documentId)", default: []].insert(assignment.tagId)
        }
        for document in documents {
            let tagIds = remaining["\(document.volumeId)/\(document.documentId)"] ?? []
            try? await pipeline.updateUserTagIds(volumeId: document.volumeId,
                                                 documentId: document.documentId,
                                                 userTagIds: tagColumnValue(tagIds))
        }
    }
}
