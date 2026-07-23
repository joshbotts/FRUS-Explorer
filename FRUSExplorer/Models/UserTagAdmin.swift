// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - UserTagAdmin

/// Shared, referential-integrity-preserving administration of `UserTag` records.
///
/// ## Why this exists (issue #406)
/// A `UserTag`'s associations live in places that SwiftData cannot see as a relationship:
/// `DocumentTagAssignment.tagId` (a plain `UUID`), `ResearchNote.userTagIds` (a plain `[UUID]`),
/// and — since #377 Phase 3 — `Project.defaultUserTagIds` (a plain `[UUID]` tag-focus). Deleting a
/// tag with a bare `modelContext.delete(tag)` therefore leaves those references dangling — the exact
/// orphaned-association state reported in #406. The two Settings delete affordances used to do
/// exactly that (the macOS delete dialog even *promised* cleanup it never performed). The *merge*
/// path already re-points the note/assignment reference kinds before deleting; deletion never did.
/// `deleteCascading` closes that gap — including the project-focus reference — so tag deletion can
/// never orphan.
///
/// ## Relationship to `OrphanedTagRepair`
/// These are complementary: `deleteCascading` prevents *new* orphans at the delete site;
/// `OrphanedTagRepair` heals any orphan that still slips through (a partial CloudKit import, a
/// legacy record from before this fix). Because a cascading delete removes the assignments, it
/// leaves nothing for the boot-time repair to resurrect — so a deliberate delete stays deleted
/// and does not turn into an un-deletable "Recovered Tag" that reappears every launch.
///
/// Version history:
///   1.0 — issue #406: initial implementation — cascading (orphan-free) user-tag deletion
@MainActor
enum UserTagAdmin {

    /// Deletes `tag` and removes every dangling reference to it, so the deletion can never
    /// leave an orphaned `DocumentTagAssignment` row or a stale id inside a
    /// `ResearchNote.userTagIds` array. Saves the context.
    ///
    /// The FTS5 mirror (`document_cache.user_tag_ids`) is intentionally **not** touched here:
    /// it is rebuilt from `DocumentTagAssignment` at every launch by `FRUSExplorerApp.bootApp()`,
    /// so removing the assignments is sufficient and this matches the existing merge path, which
    /// likewise defers the FTS5 reconciliation to the next boot. (An orphaned id lingering in the
    /// column until then is unreachable anyway — no picker lists a deleted tag.)
    ///
    /// - Parameters:
    ///   - tag: The `UserTag` to delete.
    ///   - context: The SwiftData context owning `tag`.
    static func deleteCascading(_ tag: UserTag, context: ModelContext) {
        let id = tag.id

        // Strip the id from every note that carries it. In-memory filter, NOT a `#Predicate`
        // on `userTagIds` — `array.contains` on the transformable `[UUID]` column traps in
        // SwiftData (see the same note on `mergeTag`).
        let notes = (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? []
        for note in notes where note.userTagIds.contains(id) {
            note.userTagIds.removeAll { $0 == id }
        }

        // Delete every direct-tag assignment referencing it.
        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        for assignment in assignments where assignment.tagId == id {
            context.delete(assignment)
        }

        // Remove the id from every project's tag focus (#377 Phase 3), so a deleted tag can't linger
        // as a dead focus id (which would silently stop contributing to that project's leads seed).
        stripTagFromProjectFocus(id, in: context)

        context.delete(tag)
        try? context.save()
    }

    /// Removes `tagId` from every `Project.defaultUserTagIds` (#377 Phase 3 tag focus). Reassigns the
    /// array (not an in-place `removeAll`) so `Project.lastModified` / CloudKit conflict resolution
    /// fires (see `Project.swift`). Does **not** save — the caller batches the save.
    static func stripTagFromProjectFocus(_ tagId: UUID, in context: ModelContext) {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        for project in projects where project.defaultUserTagIds.contains(tagId) {
            project.defaultUserTagIds = project.defaultUserTagIds.filter { $0 != tagId }
        }
    }

    /// Re-points a project tag focus from `sourceId` to `targetId` in every `Project.defaultUserTagIds`
    /// (#377 Phase 3) — the merge counterpart of `stripTagFromProjectFocus`, so merging a tag doesn't
    /// strand a project's focus on the now-deleted source id. Reassigns the array (didSet / CloudKit).
    /// De-duplicates when the project already focuses on the target. Does **not** save.
    static func repointTagInProjectFocus(from sourceId: UUID, to targetId: UUID, in context: ModelContext) {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        for project in projects where project.defaultUserTagIds.contains(sourceId) {
            var ids = project.defaultUserTagIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            project.defaultUserTagIds = ids
        }
    }
}
