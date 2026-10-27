// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
///   1.1 — #1791: a note stored as several copies under one id is counted once (in the fetch, which
///          stays in the app)
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with ``tally(noteProjectIds:noteTagIds:collectionProjectIds:assignmentTagIds:)``
///          and the rows' summaries unchanged, for the web edition's Settings ▸ Tags and Research page;
///          `fetch(from:)`, the three fetches, stays in the app's `ResearchItemCounts+App.swift`
public struct ResearchItemCounts: Equatable, Sendable {

    /// What a single project row reports.
    public struct ProjectTally: Equatable, Sendable {
        /// Research notes carrying this project's id.
        public var notes: Int = 0
        /// Collections carrying this project's id.
        public var collections: Int = 0

        /// Creates a tally, zero unless given.
        public init(notes: Int = 0, collections: Int = 0) {
            self.notes = notes
            self.collections = collections
        }
    }

    /// What a single tag row reports.
    public struct TagTally: Equatable, Sendable {
        /// Research notes carrying this tag's id.
        public var notes: Int = 0
        /// Documents tagged directly with this tag.
        public var documents: Int = 0

        /// Creates a tally, zero unless given.
        public init(notes: Int = 0, documents: Int = 0) {
            self.notes = notes
            self.documents = documents
        }
    }

    /// Per-project tallies, keyed by project id. A project with nothing attached is absent.
    public let projects: [UUID: ProjectTally]
    /// Per-tag tallies, keyed by tag id. A tag applied to nothing is absent.
    public let tags: [UUID: TagTally]

    /// Creates a tally set from its two maps, as ``tally(noteProjectIds:noteTagIds:collectionProjectIds:assignmentTagIds:)``
    /// counts them.
    public init(projects: [UUID: ProjectTally], tags: [UUID: TagTally]) {
        self.projects = projects
        self.tags = tags
    }

    /// An empty tally set, for the state before the first fetch.
    public static let empty = ResearchItemCounts(projects: [:], tags: [:])

    /// The tally for `projectId`, or a zeroed one when nothing hangs off it.
    public func project(_ projectId: UUID) -> ProjectTally { projects[projectId] ?? ProjectTally() }

    /// The tally for `tagId`, or a zeroed one when nothing carries it.
    public func tag(_ tagId: UUID) -> TagTally { tags[tagId] ?? TagTally() }

    // MARK: - Building

    /// The pure counting step, separated from the fetch (the app's `fetch(from:)`) so it can be tested
    /// without a container, and so a host with its own store counts as the app does.
    ///
    /// - Parameters:
    ///   - noteProjectIds: Each note's project ids.
    ///   - noteTagIds: Each note's user-tag ids, in the same order as `noteProjectIds`.
    ///   - collectionProjectIds: Each collection's project ids.
    ///   - assignmentTagIds: One tag id per direct document-tag assignment.
    public static func tally(noteProjectIds: [[UUID]],
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
    public var summary: String {
        guard notes > 0 || collections > 0 else {
            return String(localized: "settings.list.project.empty", defaultValue: "Nothing filed yet")
        }
        var parts: [String] = []
        if notes > 0 {
            parts.append(ResearchItemCounts.notesPhrase(notes))
        }
        if collections > 0 {
            parts.append(CountCopy.phrase(
                collections,
                one: String(localized: "settings.list.count.collection.one", defaultValue: "%@ collection"),
                many: String(localized: "settings.list.count.collection.many",
                             defaultValue: "%@ collections")))
        }
        return parts.joined(separator: " · ")
    }
}

extension ResearchItemCounts {

    /// "1 note" / "N notes", grouped past 999 through `CountCopy` (#1374). The Projects and Tags
    /// rows and the Notes pane's header all say it this way; the two forms had carried the number
    /// through a `%lld`.
    ///
    /// - Parameter count: How many research notes.
    /// - Returns: The phrase.
    public static func notesPhrase(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "settings.list.count.note.one", defaultValue: "%@ note"),
                         many: String(localized: "settings.list.count.note.many", defaultValue: "%@ notes"))
    }
}

extension ResearchItemCounts.TagTally {

    /// The row's secondary line — "12 notes · 3 documents", or nothing when the tag is unused.
    ///
    /// An unused tag is worth naming plainly: it is the one a reader is most likely to be deciding
    /// whether to delete.
    public var summary: String {
        guard notes > 0 || documents > 0 else {
            return String(localized: "settings.list.tag.unused", defaultValue: "Not applied to anything")
        }
        var parts: [String] = []
        if notes > 0 {
            parts.append(ResearchItemCounts.notesPhrase(notes))
        }
        if documents > 0 {
            parts.append(CountCopy.documents(documents))
        }
        return parts.joined(separator: " · ")
    }
}
