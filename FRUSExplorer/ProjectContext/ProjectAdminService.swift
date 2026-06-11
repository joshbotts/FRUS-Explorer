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
/// `Collection`, `GeneratedSummary`, `ReadingHistoryEntry`, and
/// `SearchHistoryEntry` rows that reference the deleted project's `id` keep
/// that now-orphaned reference and remain visible in Global Context — "Activity
/// records are kept but unlinked from this project," per the delete
/// confirmation copy on both platforms.
///
/// ## Merge
/// Reassigns `ResearchNote.projectIds`, `Collection.projectIds`,
/// `GeneratedSummary.projectId`, `ReadingHistoryEntry.projectId`, and
/// `SearchHistoryEntry.projectId` from `source` to `target`, then deletes
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

        if appState.activeProjectId == sourceId {
            appState.activeProjectId = targetId
        }

        context.delete(source)
    }
}
