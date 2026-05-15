// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftData

// MARK: - GlobalContextViewModel

/// Aggregates all user activity across every project and the untagged context.
///
/// ## Filtering
/// `selectedProjectFilter` and `selectedUserTagFilter` are independent. When both
/// are set, notes must satisfy both conditions (AND logic). Setting either to `nil`
/// removes that filter axis, showing all records on that axis.
///
/// ## Stats
/// `perProjectBreakdown` maps project name → unique document count from reading
/// history. The "Untagged" bucket collects entries whose `projectId` is `nil`.
///
/// ## Load
/// `load(context:)` fetches all records in one pass. Call it on appear and whenever
/// the context changes (e.g. after adding a note).
///
/// ## Log prefix
/// `[GlobalContext]`
///
/// Version history:
///   1.0 — Session 25: initial implementation
@Observable
@MainActor
final class GlobalContextViewModel {

    // MARK: - Filter State

    /// Selected project filter. `nil` = all projects (global context).
    var selectedProjectFilter: UUID? = nil

    /// Selected user tag filter. `nil` = all user tags.
    var selectedUserTagFilter: UUID? = nil

    // MARK: - Raw Data

    var allNotes: [ResearchNote] = []
    var allCollections: [Collection] = []
    var allHistory: [ReadingHistoryEntry] = []
    var projects: [Project] = []
    var userTags: [UserTag] = []

    // MARK: - Filtered Views

    /// Notes matching the active project + user-tag filters.
    var filteredNotes: [ResearchNote] {
        allNotes.filter { note in
            let matchesProject: Bool = {
                guard let pid = selectedProjectFilter else { return true }
                return note.projectIds.contains(pid)
            }()
            let matchesTag: Bool = {
                guard let tid = selectedUserTagFilter else { return true }
                return note.userTagIds.contains(tid)
            }()
            return matchesProject && matchesTag
        }
    }

    /// Collections matching the active project filter.
    var filteredCollections: [Collection] {
        allCollections.filter { collection in
            guard let pid = selectedProjectFilter else { return true }
            return collection.projectIds.contains(pid)
        }
    }

    // MARK: - Summary Stats

    /// Total unique (volumeId, documentId) pairs accessed across all history.
    var totalDocumentsAccessed: Int {
        Set(allHistory.map { "\($0.volumeId)/\($0.documentId)" }).count
    }

    /// Per-project document access counts, sorted by count descending.
    /// Includes an "Untagged" bucket for entries with `projectId == nil`.
    var perProjectBreakdown: [ProjectBreakdownEntry] {
        var buckets: [UUID?: Set<String>] = [:]
        for entry in allHistory {
            let key = entry.projectId
            buckets[key, default: []].insert("\(entry.volumeId)/\(entry.documentId)")
        }
        var result: [ProjectBreakdownEntry] = []
        for (pid, docs) in buckets {
            let name: String
            if let pid {
                name = projects.first(where: { $0.id == pid })?.name
                    ?? String(localized: "global.context.breakdown.orphaned",
                              defaultValue: "Deleted Project")
            } else {
                name = String(localized: "global.context.breakdown.untagged",
                              defaultValue: "Untagged")
            }
            result.append(ProjectBreakdownEntry(projectId: pid, name: name, documentCount: docs.count))
        }
        return result.sorted { $0.documentCount > $1.documentCount }
    }

    /// Per-volume document access counts, sorted by count descending.
    var perVolumeBreakdown: [VolumeBreakdownEntry] {
        var buckets: [String: Set<String>] = [:]
        for entry in allHistory {
            buckets[entry.volumeId, default: []].insert(entry.documentId)
        }
        return buckets.map { VolumeBreakdownEntry(volumeId: $0.key, documentCount: $0.value.count) }
            .sorted { $0.documentCount > $1.documentCount }
    }

    /// Count of history entries with no project tag.
    var untaggedHistoryCount: Int {
        allHistory.filter { $0.projectId == nil }.count
    }

    /// Count of notes with no project tag.
    var untaggedNotesCount: Int {
        allNotes.filter { $0.projectIds.isEmpty }.count
    }

    // MARK: - Loading

    /// Fetches all records from `context` and repopulates all arrays.
    func load(context: ModelContext) {
        allNotes = (try? context.fetch(FetchDescriptor<ResearchNote>(
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        ))) ?? []

        allCollections = (try? context.fetch(FetchDescriptor<Collection>(
            sortBy: [SortDescriptor(\.lastModified, order: .reverse)]
        ))) ?? []

        allHistory = (try? context.fetch(FetchDescriptor<ReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)]
        ))) ?? []

        projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []

        userTags = (try? context.fetch(FetchDescriptor<UserTag>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? []

        #if DEBUG
        print("[GlobalContext] Loaded: \(allNotes.count) notes, \(allCollections.count) collections, \(allHistory.count) history, \(projects.count) projects")
        #endif
    }
}

// MARK: - ProjectBreakdownEntry

/// One row in the per-project document access breakdown.
///
/// Version history:
///   1.0 — Session 25: initial implementation
struct ProjectBreakdownEntry: Identifiable {
    let projectId: UUID?
    let name: String
    let documentCount: Int

    var id: String { projectId?.uuidString ?? "untagged" }
}

// MARK: - VolumeBreakdownEntry

/// One row in the per-volume document access breakdown.
///
/// Version history:
///   1.0 — Session 25: initial implementation
struct VolumeBreakdownEntry: Identifiable {
    let volumeId: String
    let documentCount: Int

    var id: String { volumeId }
}
