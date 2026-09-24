// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ProjectAdminService

/// Shared SwiftData mutations for deleting and merging `Project` records.
///
/// Extracted from the macOS `SettingsProjectsPane` in Session 153 so the iOS
/// Projects settings group can offer the same delete/merge actions with
/// identical semantics.
///
/// ## Delete
/// Deleting a project does not touch any other record. `ResearchNote`,
/// `Collection`, `ArchiveVisitPlan`, `GeneratedSummary`, `ReadingHistoryEntry`,
/// `SearchHistoryEntry` and `ExportHistoryEntry` rows that reference the deleted
/// project's `id` keep that now-orphaned reference and remain visible in Global
/// Context — "Activity records are kept but unlinked from this project," per the
/// delete confirmation copy on both platforms. (A plan whose project is gone offers
/// no Re-seed from Project: the editor gates it on `owningProject(among:)`.)
///
/// ## Merge
/// Reassigns `ResearchNote.projectIds`, `Collection.projectIds`,
/// `ArchiveVisitPlan.projectIds`, `GeneratedSummary.projectId`,
/// `ReadingHistoryEntry.projectId`, `SearchHistoryEntry.projectId` and
/// `ExportHistoryEntry.projectId` from `source` to `target`, then deletes
/// `source`. A merge into the same project (`source.id == target.id`) is a
/// no-op.
///
/// In both cases, if `source`/the deleted project is the active project,
/// `appState.activeProjectId` is updated so the user is never left pointing at
/// a deleted `Project` record.
///
/// Version history:
///   1.0 — Session 153: extracted from `SettingsProjectsPane`
///   1.1 — Session 158: merge also reassigns `SearchHistoryEntry.projectId`
///          (previously left dangling at the deleted source project's id)
///   1.2 — Wave R-2a: merge also reassigns `ExportHistoryEntry.projectId`, the research
///          trail's third type
///   1.3 — #1366 review: merge also reassigns `ArchiveVisitPlan.projectIds` (previously left
///          at the deleted source's id, so the target's Project Home could not find the plan
///          and its Re-seed from Project found nothing behind it)
@MainActor
struct ProjectAdminService {

    private init() {}

    /// Deletes `project`, switching `appState.activeProjectId` to `nil`
    /// (Global Context) first if `project` was active.
    static func delete(_ project: Project, context: ModelContext, appState: AppState) {
        if appState.activeProjectId == project.id {
            appState.activeProjectId = nil
        }
        context.delete(project)
    }

    /// Reassigns activity records referencing `source` to reference `target`,
    /// then deletes `source`. If `source` was the active project,
    /// `appState.activeProjectId` is switched to `target.id`.
    ///
    /// No-op when `source.id == target.id`.
    static func merge(_ source: Project, into target: Project, context: ModelContext, appState: AppState) {
        guard source.id != target.id else { return }

        let sourceId = source.id
        let targetId = target.id

        // Array-valued columns ([UUID]) can't be queried with a #Predicate
        // `contains` on SwiftData — fetch and filter in memory.
        let allNotes = (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? []
        for note in allNotes where note.projectIds.contains(sourceId) {
            var ids = note.projectIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.projectIds = ids
        }

        let allCollections = (try? context.fetch(FetchDescriptor<Collection>())) ?? []
        for collection in allCollections where collection.projectIds.contains(sourceId) {
            var ids = collection.projectIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            collection.projectIds = ids
        }

        // #1366 review: an Archives Visit belongs to the project it was made under. Re-pointed IN
        // PLACE rather than filtered-then-appended like the two arrays above, because a plan's
        // FIRST id is its owning project — the one Re-seed from Project and the caption read — so
        // appending would hand a plan that also names a third project to that third project.
        let allPlans = (try? context.fetch(FetchDescriptor<ArchiveVisitPlan>())) ?? []
        for plan in allPlans where plan.projectIds.contains(sourceId) {
            var ids: [UUID] = []
            for id in plan.projectIds.map({ $0 == sourceId ? targetId : $0 }) where !ids.contains(id) {
                ids.append(id)
            }
            plan.projectIds = ids
        }

        let allSummaries = (try? context.fetch(FetchDescriptor<GeneratedSummary>())) ?? []
        for summary in allSummaries where summary.projectId == sourceId {
            summary.projectId = targetId
        }

        let allHistory = (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>())) ?? []
        for entry in allHistory where entry.projectId == sourceId {
            entry.projectId = targetId
        }

        let allSearchHistory = (try? context.fetch(FetchDescriptor<SearchHistoryEntry>())) ?? []
        for entry in allSearchHistory where entry.projectId == sourceId {
            entry.projectId = targetId
        }

        // Wave R-2a: the trail's third type. Attribution is stamped at write time on all three,
        // so a merge that re-pointed two of them would leave exports stranded on a project that
        // no longer exists — invisible in every scope but "All".
        let allExportHistory = (try? context.fetch(FetchDescriptor<ExportHistoryEntry>())) ?? []
        for entry in allExportHistory where entry.projectId == sourceId {
            entry.projectId = targetId
        }

        if appState.activeProjectId == sourceId {
            appState.activeProjectId = targetId
        }

        context.delete(source)
    }
}
