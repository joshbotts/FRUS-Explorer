// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchItemCounts

/// How much research data hangs off each project and each tag (S-3).
///
/// ## Why this exists
/// The North Star's list grammar puts counts on every row — "12 notes · 3 collections" — so that
/// the consequence of deleting or merging something is visible *before* the user commits. Computing
/// those counts naively is a trap this codebase has already been bitten by twice:
///
/// - The macOS Tags pane's `noteCount(for:)` fetched **every** `ResearchNote` once per row, inside
///   the view body. Ten tags meant ten full-table fetches per render pass, and SwiftUI re-renders
///   far more often than anyone expects.
/// - The Storage pane's per-row `isVolumeIndexed()` was the same shape of mistake and pegged a CPU
///   core overnight (Session 160).
///
/// This type does the work **once**: three fetches total, regardless of how many projects or tags
/// are on screen. Views hold it as `@State` and refresh it on appear and after a mutation — the
/// same one-shot cadence the Volumes & Storage hub uses, and deliberately not a `@Query`.
///
/// ## Why in-memory filtering, not `#Predicate`
/// `projectIds` and `userTagIds` are transformable `[UUID]` columns. A `#Predicate` using
/// `array.contains` on those traps in SwiftData — the same hazard already documented on
/// `UserTagAdmin.deleteCascading` and both merge paths. Fetch, then filter in Swift.
///
/// Version history:
///   1.0 — S-3a: initial implementation
struct ResearchItemCounts: Equatable, Sendable {

    /// What a single project row reports.
    struct ProjectTally: Equatable, Sendable {
        /// Research notes carrying this project's id.
        var notes: Int = 0
        /// Collections carrying this project's id.
        var collections: Int = 0
    }

    /// What a single tag row reports.
    struct TagTally: Equatable, Sendable {
        /// Research notes carrying this tag's id.
        var notes: Int = 0
        /// Documents tagged directly with this tag.
        var documents: Int = 0
    }

    /// Per-project tallies, keyed by project id. A project with nothing attached is absent.
    let projects: [UUID: ProjectTally]
    /// Per-tag tallies, keyed by tag id. A tag applied to nothing is absent.
    let tags: [UUID: TagTally]

    /// An empty tally set, for the state before the first fetch.
    static let empty = ResearchItemCounts(projects: [:], tags: [:])

    /// The tally for `projectId`, or a zeroed one when nothing hangs off it.
    func project(_ projectId: UUID) -> ProjectTally { projects[projectId] ?? ProjectTally() }

    /// The tally for `tagId`, or a zeroed one when nothing carries it.
    func tag(_ tagId: UUID) -> TagTally { tags[tagId] ?? TagTally() }

    // MARK: - Building

    /// Tallies every project and tag reference in three fetches.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> ResearchItemCounts {
        let notes = (try? context.fetch(FetchDescriptor<ResearchNote>())) ?? []
        let collections = (try? context.fetch(FetchDescriptor<Collection>())) ?? []
        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        return tally(noteProjectIds: notes.map(\.projectIds),
                     noteTagIds: notes.map(\.userTagIds),
                     collectionProjectIds: collections.map(\.projectIds),
                     assignmentTagIds: assignments.map(\.tagId))
    }

    /// The pure counting step, separated from the fetch so it can be tested without a container.
    ///
    /// - Parameters:
    ///   - noteProjectIds: Each note's project ids.
    ///   - noteTagIds: Each note's user-tag ids, in the same order as `noteProjectIds`.
    ///   - collectionProjectIds: Each collection's project ids.
    ///   - assignmentTagIds: One tag id per direct document-tag assignment.
    static func tally(noteProjectIds: [[UUID]],
                      noteTagIds: [[UUID]],
                      collectionProjectIds: [[UUID]],
                      assignmentTagIds: [UUID]) -> ResearchItemCounts {
        var projects: [UUID: ProjectTally] = [:]
        var tags: [UUID: TagTally] = [:]

        for ids in noteProjectIds {
            // A note listing the same project twice is malformed data, not two notes.
            for projectId in Set(ids) {
                projects[projectId, default: ProjectTally()].notes += 1
            }
        }
        for ids in collectionProjectIds {
            for projectId in Set(ids) {
                projects[projectId, default: ProjectTally()].collections += 1
            }
        }
        for ids in noteTagIds {
            for tagId in Set(ids) {
                tags[tagId, default: TagTally()].notes += 1
            }
        }
        for tagId in assignmentTagIds {
            tags[tagId, default: TagTally()].documents += 1
        }

        return ResearchItemCounts(projects: projects, tags: tags)
    }
}

// MARK: - Row summaries

extension ResearchItemCounts.ProjectTally {

    /// The row's secondary line — "12 notes · 3 collections", or nothing when the project is empty.
    ///
    /// An empty project says so in words rather than showing "0 notes · 0 collections", which reads
    /// as a broken counter rather than a new project.
    var summary: String {
        guard notes > 0 || collections > 0 else {
            return String(localized: "settings.list.project.empty", defaultValue: "Nothing filed yet")
        }
        var parts: [String] = []
        if notes > 0 {
            parts.append(notes == 1
                ? String(localized: "settings.list.count.note.one", defaultValue: "1 note")
                : String(format: String(localized: "settings.list.count.note.many %lld",
                                        defaultValue: "%lld notes"), Int64(notes)))
        }
        if collections > 0 {
            parts.append(collections == 1
                ? String(localized: "settings.list.count.collection.one", defaultValue: "1 collection")
                : String(format: String(localized: "settings.list.count.collection.many %lld",
                                        defaultValue: "%lld collections"), Int64(collections)))
        }
        return parts.joined(separator: " · ")
    }
}

extension ResearchItemCounts.TagTally {

    /// The row's secondary line — "12 notes · 3 documents", or nothing when the tag is unused.
    ///
    /// An unused tag is worth naming plainly: it is the one a reader is most likely to be deciding
    /// whether to delete.
    var summary: String {
        guard notes > 0 || documents > 0 else {
            return String(localized: "settings.list.tag.unused", defaultValue: "Not applied to anything")
        }
        var parts: [String] = []
        if notes > 0 {
            parts.append(notes == 1
                ? String(localized: "settings.list.count.note.one", defaultValue: "1 note")
                : String(format: String(localized: "settings.list.count.note.many %lld",
                                        defaultValue: "%lld notes"), Int64(notes)))
        }
        if documents > 0 {
            parts.append(documents == 1
                ? String(localized: "settings.list.count.document.one", defaultValue: "1 document")
                : String(format: String(localized: "settings.list.count.document.many %lld",
                                        defaultValue: "%lld documents"), Int64(documents)))
        }
        return parts.joined(separator: " · ")
    }
}
