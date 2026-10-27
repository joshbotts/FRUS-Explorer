// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchTrailSessions + the store

/// The trail's loaders: they read the three typed tables, ``ReadingHistoryEntry``,
/// ``SearchHistoryEntry`` and ``ExportHistoryEntry``, so they stay in the app, while the grouping, the
/// newest window's merge and the session log's page are FRUSCoreKit's
/// (`FRUSCoreKit/Models/ResearchTrailSessions.swift`), where FRUS Explorer Light reads them too.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): the loaders of `ResearchTrailSessions` and
///          `SessionLogSnapshot.fetch(from:limit:)`, moved here unchanged from
///          `Models/ResearchTrailSessions.swift` when the rest of it moved into the kit; the merge
///          is the kit's `newestFirst(_:limit:)`
extension ResearchTrailSessions {

    // MARK: - Loading

    /// Reads a bounded, newest-first window of the whole trail as activities.
    ///
    /// ## Why the window is computed twice
    /// Each table is fetched with its own `fetchLimit`, and the merged result is then truncated to
    /// `limit` again, by FRUSCoreKit's ``ResearchTrailSessions/newestFirst(_:limit:)``, which says
    /// why the second truncation is needed and sound.
    ///
    /// Rows with a `nil` timestamp are skipped. Every one of those columns is optional only for
    /// CloudKit schema compatibility and is non-nil in practice; an activity with no time cannot
    /// be placed on a timeline, and guessing one would fabricate a session boundary.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - limit: How many activities to load, at most.
    /// - Returns: The activities, newest first. Fetch failures degrade to an empty section rather
    ///   than throwing — a log that cannot read is a log that shows nothing, not a crash.
    @MainActor
    static func activities(in context: ModelContext, limit: Int) -> [ResearchTrailActivity] {
        var visitPage = FetchDescriptor<ReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)])
        visitPage.fetchLimit = limit
        var searchPage = FetchDescriptor<SearchHistoryEntry>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)])
        searchPage.fetchLimit = limit
        var exportPage = FetchDescriptor<ExportHistoryEntry>(
            sortBy: [SortDescriptor(\.exportedAt, order: .reverse)])
        exportPage.fetchLimit = limit

        var merged: [ResearchTrailActivity] = []
        for visit in (try? context.fetch(visitPage)) ?? [] {
            guard let at = visit.accessedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: visit.id,
                kind: .documentOpen(volumeId: visit.volumeId,
                                    documentId: visit.documentId,
                                    displayTitle: visit.displayTitle),
                timestamp: at,
                projectId: visit.projectId))
        }
        for query in (try? context.fetch(searchPage)) ?? [] {
            guard let at = query.executedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: query.id,
                kind: .search(query: query.queryText, resultCount: query.resultCount),
                timestamp: at,
                projectId: query.projectId))
        }
        for export in (try? context.fetch(exportPage)) ?? [] {
            guard let at = export.exportedAt else { continue }
            merged.append(ResearchTrailActivity(
                id: export.id,
                kind: .export(format: export.format,
                              documentCount: export.documentCount,
                              collectionName: export.collectionName),
                timestamp: at,
                projectId: export.projectId))
        }

        return newestFirst(merged, limit: limit)
    }

    /// How many **rows** the whole trail holds, across all three tables — timestamp or not.
    ///
    /// Three `fetchCount`s. This is the number a delete would remove, so it is what the Settings
    /// row quotes and what decides whether the delete control is enabled. It is deliberately *not*
    /// what the session log compares its page against; see ``datedActivityCount(in:)``.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func totalActivityCount(in context: ModelContext) -> Int {
        let visits = (try? context.fetchCount(FetchDescriptor<ReadingHistoryEntry>())) ?? 0
        let searches = (try? context.fetchCount(FetchDescriptor<SearchHistoryEntry>())) ?? 0
        let exports = (try? context.fetchCount(FetchDescriptor<ExportHistoryEntry>())) ?? 0
        return visits + searches + exports
    }

    /// How many trail rows carry a timestamp, and can therefore appear in a session.
    ///
    /// ## Why this is separate from ``totalActivityCount(in:)``
    /// ``activities(in:limit:)`` skips rows with a `nil` timestamp — it has to, since an activity
    /// with no time cannot be placed on a timeline. Comparing that page against a count that
    /// *included* those rows desynchronises the two: `loadedActivities < totalActivities` stays
    /// true no matter how far the reader pages, so "Show More" never exhausts, and a store whose
    /// rows are all undated reports itself non-empty and draws a blank list instead of the empty
    /// state. Counting the same population the page is drawn from removes both.
    ///
    /// The three predicates compare an optional column against a **typed** `nil` binding, the form
    /// `HistoryScope.unfiled` established here — `$0.accessedAt != nil` alone leaves the macro
    /// without a type for the literal.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func datedActivityCount(in context: ModelContext) -> Int {
        let noDate: Date? = nil
        let visits = (try? context.fetchCount(FetchDescriptor<ReadingHistoryEntry>(
            predicate: #Predicate { $0.accessedAt != noDate }))) ?? 0
        let searches = (try? context.fetchCount(FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { $0.executedAt != noDate }))) ?? 0
        let exports = (try? context.fetchCount(FetchDescriptor<ExportHistoryEntry>(
            predicate: #Predicate { $0.exportedAt != noDate }))) ?? 0
        return visits + searches + exports
    }
}

// MARK: - SessionLogSnapshot + the store

extension SessionLogSnapshot {

    /// Reads one page of the trail and groups it.
    ///
    /// - Parameters:
    ///   - context: The SwiftData context to read.
    ///   - limit: Maximum activities to load. Defaults to ``defaultPageLimit``.
    @MainActor
    static func fetch(from context: ModelContext,
                      limit: Int = defaultPageLimit) -> SessionLogSnapshot {
        let activities = ResearchTrailSessions.activities(in: context, limit: limit)
        return page(of: activities,
                    datedActivityCount: ResearchTrailSessions.datedActivityCount(in: context),
                    limit: limit)
    }
}
