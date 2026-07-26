// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - NotesPaneSnapshot

/// Every research note, flattened into display-ready rows (S-5b).
///
/// ## Why this exists
/// The macOS Notes pane used to hold three live `@Query`s — one over *every* `ResearchNote`, one
/// over projects, one over tags — filter them in a computed property on every render, and resolve
/// each row's project and tag names with a linear scan per row. That is the shape this codebase
/// has been bitten by twice already (the Tags pane's per-row full-table fetch; the Storage pane's
/// per-row `isVolumeIndexed()`, which pegged a CPU core overnight in Session 160), and a `@Query`
/// re-renders its whole pane on every CloudKit drip-import.
///
/// This does the work **once**: three fetches, name resolution done during the build, rows that
/// are plain `Sendable` values afterwards. The view holds it as `@State` and refreshes it on
/// appear and after every mutation — the one-shot cadence `ResearchItemCounts` established.
///
/// ## Why in-memory filtering, not `#Predicate`
/// `projectIds` and `userTagIds` are transformable `[UUID]` columns, and a `#Predicate` using
/// `array.contains` on those traps in SwiftData — the same hazard documented on
/// ``ResearchItemCounts`` and on `UserTagAdmin.deleteCascading`. Fetch, then filter in Swift.
///
/// Version history:
///   1.0 — S-5b: initial implementation
struct NotesPaneSnapshot: Equatable, Sendable {

    /// One note, with everything the row needs already resolved.
    struct Row: Identifiable, Equatable, Sendable {
        /// The note's own id — also the identity the editor sheet is keyed on.
        let id: UUID
        /// FRUS volume identifier the note is attached to.
        let volumeId: String
        /// Document identifier within the volume.
        let documentId: String
        /// The note's body text, as stored. Empty for a note that was never written into.
        let bodyText: String
        /// Names of the projects this note is filed under, in the order the ids appear.
        let projectNames: [String]
        /// Names of the user tags on this note.
        let tagNames: [String]
        /// When the note was last edited. `nil` on legacy rows written before the field existed.
        let lastModified: Date?
        /// Project ids, kept for filtering.
        let projectIds: [UUID]
        /// User-tag ids, kept for filtering.
        let userTagIds: [UUID]

        /// The row's primary line: the note's first non-empty line, or a placeholder.
        var title: String {
            let firstLine = bodyText
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            return firstLine.isEmpty
                ? String(localized: "settings.notes.emptyNote", defaultValue: "Empty note")
                : firstLine
        }

        /// The row's secondary line: where the note lives, then what it is filed under.
        ///
        /// "frus1969-76v01 / d42 · Berlin Crisis · Cables" — one line rather than the capsule
        /// chips the old row drew, because `SettingsNavRow` is the settled list grammar and a
        /// row of coloured capsules inside a grouped Form reads as a different component.
        var detail: String {
            var parts = ["\(volumeId) / \(documentId)"]
            parts.append(contentsOf: projectNames)
            parts.append(contentsOf: tagNames)
            return parts.joined(separator: " · ")
        }
    }

    /// Every note, newest first.
    let rows: [Row]
    /// Project ids paired with their names, sorted by name — the filter picker's options.
    let projects: [(id: UUID, name: String)]
    /// Tag ids paired with their names, sorted by name.
    let tags: [(id: UUID, name: String)]

    /// The state before the first fetch.
    static let empty = NotesPaneSnapshot(rows: [], projects: [], tags: [])

    /// How many notes exist in total, before any filter.
    var total: Int { rows.count }

    static func == (lhs: NotesPaneSnapshot, rhs: NotesPaneSnapshot) -> Bool {
        lhs.rows == rhs.rows
            && lhs.projects.map(\.id) == rhs.projects.map(\.id)
            && lhs.projects.map(\.name) == rhs.projects.map(\.name)
            && lhs.tags.map(\.id) == rhs.tags.map(\.id)
            && lhs.tags.map(\.name) == rhs.tags.map(\.name)
    }

    // MARK: - Building

    /// Builds the snapshot in three fetches, resolving every row's names as it goes.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> NotesPaneSnapshot {
        let notes = (try? context.fetch(
            FetchDescriptor<ResearchNote>(
                sortBy: [SortDescriptor(\.lastModified, order: .reverse)]))) ?? []
        let projects = (try? context.fetch(
            FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let tags = (try? context.fetch(
            FetchDescriptor<UserTag>(sortBy: [SortDescriptor(\.name)]))) ?? []

        // One dictionary each, so resolving a row's names is a lookup rather than a scan over
        // every project for every id on every note.
        let projectNamesById = Dictionary(projects.map { ($0.id, $0.name) },
                                          uniquingKeysWith: { first, _ in first })
        let tagNamesById = Dictionary(tags.map { ($0.id, $0.name) },
                                      uniquingKeysWith: { first, _ in first })

        let rows = notes.map { note in
            Row(id: note.id,
                volumeId: note.volumeId,
                documentId: note.documentId,
                bodyText: note.bodyText,
                projectNames: note.projectIds.compactMap { projectNamesById[$0] },
                tagNames: note.userTagIds.compactMap { tagNamesById[$0] },
                lastModified: note.lastModified,
                projectIds: note.projectIds,
                userTagIds: note.userTagIds)
        }

        return NotesPaneSnapshot(
            rows: rows,
            projects: projects.map { (id: $0.id, name: $0.name) },
            tags: tags.map { (id: $0.id, name: $0.name) })
    }

    /// Re-reads one note by id, for the editor sheet.
    ///
    /// Rows are plain values, so opening the editor needs the live model back. Scalar `==` on a
    /// UUID is safe in a `#Predicate` — the trap documented above is `contains` on a
    /// transformable array column, not equality on a stored scalar.
    ///
    /// - Parameters:
    ///   - id: The note's id.
    ///   - context: The SwiftData context to read.
    /// - Returns: The note, or `nil` if it has since been deleted.
    @MainActor
    static func note(id: UUID, in context: ModelContext) -> ResearchNote? {
        var descriptor = FetchDescriptor<ResearchNote>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Filtering

    /// The rows matching both filters.
    ///
    /// - Parameters:
    ///   - project: What to match on the project axis.
    ///   - tagId: A tag id every returned row must carry, or `nil` for any.
    func filtered(project: ProjectFilter = .any, tagId: UUID? = nil) -> [Row] {
        rows.filter { row in
            let matchesProject: Bool
            switch project {
            case .any:            matchesProject = true
            case .unfiled:        matchesProject = row.projectIds.isEmpty
            case .id(let projectId): matchesProject = row.projectIds.contains(projectId)
            }
            let matchesTag = tagId.map { row.userTagIds.contains($0) } ?? true
            return matchesProject && matchesTag
        }
    }

    /// What the project filter is asking for.
    ///
    /// `unfiled` is its own case rather than a sentinel UUID. The old pane tagged its "Untagged"
    /// menu item with the all-zeros UUID and then asked whether a note's `projectIds` *contained*
    /// it — which no note ever does, so selecting it always produced zero results and the
    /// "no notes match" empty state. (`GlobalContextView` has the same defect in a worse form:
    /// it mints a fresh `UUID()` per render, so the selection cannot even stick.)
    enum ProjectFilter: Hashable, Sendable {
        /// No project constraint.
        case any
        /// Only notes filed under no project at all.
        case unfiled
        /// Only notes filed under this project.
        case id(UUID)
    }
}

// MARK: - Row copy

extension NotesPaneSnapshot {

    /// "1 note" / "N notes". The app ships no String Catalog, so `^[…](inflect:)` agreement does
    /// nothing and the two forms are spelled out — the same shape as `HubCopy`. Reuses the keys
    /// ``ResearchItemCounts`` already defines rather than minting a third copy of the sentence.
    static func noteCount(_ count: Int) -> String {
        count == 1
            ? String(localized: "settings.list.count.note.one", defaultValue: "1 note")
            : String(format: String(localized: "settings.list.count.note.many %lld",
                                    defaultValue: "%lld notes"), Int64(count))
    }

    /// "Showing 5 of 312 notes" — the honest version of a list that shows only its head.
    ///
    /// - Parameters:
    ///   - shown: How many rows the pane is actually drawing.
    ///   - total: How many match the current filters.
    static func showingCount(shown: Int, of total: Int) -> String {
        guard shown < total else { return noteCount(total) }
        return String(format: String(localized: "settings.notes.showing %lld %@",
                                     defaultValue: "Showing %lld of %@"),
                      Int64(shown), noteCount(total))
    }
}
