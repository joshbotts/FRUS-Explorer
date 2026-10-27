// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
///   1.1 — #1275: a second consumer — the Research tab's notes destination. The Settings pane
///          this type is named for is retired; the snapshot outlived it.
///   1.2 — #1791: one row per note however many copies of it are stored, and `note(id:in:)`
///          returns the copy last modified (both in the fetch, which stays in the app)
///   1.3 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit, public, with All Notes'
///          rows, filters and counts unchanged, the build from a note's values (``build(notes:projects:tags:)``)
///          and the search field's filter, which was `AllNotesScreen`'s (``filtered(project:tagId:query:)``),
///          for the web edition's All Notes; `fetch(from:)` and `note(id:in:)` stay in the app's
///          `NotesPaneSnapshot+App.swift`
public struct NotesPaneSnapshot: Equatable, Sendable {

    /// One note, with everything the row needs already resolved.
    public struct Row: Identifiable, Equatable, Sendable {
        /// The note's own id — also the identity the editor sheet is keyed on.
        public let id: UUID
        /// FRUS volume identifier the note is attached to.
        public let volumeId: String
        /// Document identifier within the volume.
        public let documentId: String
        /// The note's body text, as stored. Empty for a note that was never written into.
        public let bodyText: String
        /// Names of the projects this note is filed under, in the order the ids appear.
        public let projectNames: [String]
        /// Names of the user tags on this note.
        public let tagNames: [String]
        /// When the note was last edited. `nil` on legacy rows written before the field existed.
        public let lastModified: Date?
        /// Project ids, kept for filtering.
        public let projectIds: [UUID]
        /// User-tag ids, kept for filtering.
        public let userTagIds: [UUID]

        /// Creates a row from a note's values and its resolved names.
        public init(id: UUID, volumeId: String, documentId: String, bodyText: String,
                    projectNames: [String], tagNames: [String], lastModified: Date?,
                    projectIds: [UUID], userTagIds: [UUID]) {
            self.id = id
            self.volumeId = volumeId
            self.documentId = documentId
            self.bodyText = bodyText
            self.projectNames = projectNames
            self.tagNames = tagNames
            self.lastModified = lastModified
            self.projectIds = projectIds
            self.userTagIds = userTagIds
        }

        /// How many characters of the first line the row shows before eliding.
        ///
        /// A note is free-form text and a great many are a single paragraph with no newline in
        /// them at all — `TextEditor` soft-wraps, so only a pressed Return puts one there. Without
        /// a bound, "first line" is the whole note, and a settings row grows as tall as it. The
        /// row it replaced was `Text(note.bodyText).lineLimit(2)`; this keeps that promise in the
        /// value type, where it can be tested.
        public static let titleLimit = 90

        /// The row's primary line: the note's first non-empty line, bounded, or a placeholder.
        public var title: String {
            // Split on the newline *character set*, not "\n": Swift stores a CRLF as one grapheme
            // that does not equal "\n", so a note pasted from Windows or Word would otherwise
            // never split and would smear its whole body across the row.
            let firstLine = bodyText
                .components(separatedBy: .newlines)
                .lazy
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
            guard !firstLine.isEmpty else {
                return String(localized: "settings.notes.emptyNote", defaultValue: "Empty note")
            }
            guard firstLine.count > Self.titleLimit else { return firstLine }
            return firstLine.prefix(Self.titleLimit).trimmingCharacters(in: .whitespaces) + "…"
        }

        /// The row's secondary line: where the note lives, then what it is filed under.
        ///
        /// "frus1969-76v01 / d42 · Berlin Crisis · Cables" — one line rather than the capsule
        /// chips the old row drew, because `SettingsNavRow` is the settled list grammar and a
        /// row of coloured capsules inside a grouped Form reads as a different component.
        public var detail: String {
            var parts = ["\(volumeId) / \(documentId)"]
            parts.append(contentsOf: projectNames)
            parts.append(contentsOf: tagNames)
            return parts.joined(separator: " · ")
        }
    }

    /// Every note, newest first.
    public let rows: [Row]
    /// Project ids paired with their names, sorted by name — the filter picker's options.
    public let projects: [(id: UUID, name: String)]
    /// Tag ids paired with their names, sorted by name.
    public let tags: [(id: UUID, name: String)]

    /// Creates a snapshot from its rows and the filter picker's options.
    public init(rows: [Row], projects: [(id: UUID, name: String)], tags: [(id: UUID, name: String)]) {
        self.rows = rows
        self.projects = projects
        self.tags = tags
    }

    /// The state before the first fetch.
    public static let empty = NotesPaneSnapshot(rows: [], projects: [], tags: [])

    /// How many notes exist in total, before any filter.
    public var total: Int { rows.count }

    public static func == (lhs: NotesPaneSnapshot, rhs: NotesPaneSnapshot) -> Bool {
        lhs.rows == rhs.rows
            && lhs.projects.map(\.id) == rhs.projects.map(\.id)
            && lhs.projects.map(\.name) == rhs.projects.map(\.name)
            && lhs.tags.map(\.id) == rhs.tags.map(\.id)
            && lhs.tags.map(\.name) == rhs.tags.map(\.name)
    }

    // MARK: - Building

    /// A note's values, as a row is built from them (`ResearchNote`'s).
    public struct Note: Sendable, Equatable {
        /// The note's id.
        public var id: UUID
        /// FRUS volume identifier the note is attached to.
        public var volumeId: String
        /// Document identifier within the volume.
        public var documentId: String
        /// The note's body text, as stored.
        public var bodyText: String
        /// When the note was last edited, `nil` on legacy rows.
        public var lastModified: Date?
        /// The projects the note is filed under, in the note's order.
        public var projectIds: [UUID]
        /// The user tags on the note, in the note's order.
        public var userTagIds: [UUID]

        /// Creates a note's values.
        public init(id: UUID, volumeId: String, documentId: String, bodyText: String,
                    lastModified: Date?, projectIds: [UUID], userTagIds: [UUID]) {
            self.id = id
            self.volumeId = volumeId
            self.documentId = documentId
            self.bodyText = bodyText
            self.lastModified = lastModified
            self.projectIds = projectIds
            self.userTagIds = userTagIds
        }
    }

    /// Builds the snapshot, resolving every row's names as it goes.
    ///
    /// The order is the host's, as its fetch gives it: the app's `fetch(from:)` passes the notes newest
    /// first (`lastModified`, descending) and the projects and tags each sorted by name. A row names
    /// its projects and tags in the order its note holds their ids, and leaves out an id with no
    /// project or tag of that id; where two share an id, the first one's name is used.
    ///
    /// - Parameters:
    ///   - notes: Every note, in the order the rows show them.
    ///   - projects: Every project, as the filter picker lists them.
    ///   - tags: Every tag, as the filter picker lists them.
    /// - Returns: The snapshot.
    public static func build(notes: [Note], projects: [(id: UUID, name: String)],
                             tags: [(id: UUID, name: String)]) -> NotesPaneSnapshot {
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

        return NotesPaneSnapshot(rows: rows, projects: projects, tags: tags)
    }

    // MARK: - Filtering

    /// The rows matching both filters.
    ///
    /// - Parameters:
    ///   - project: What to match on the project axis.
    ///   - tagId: A tag id every returned row must carry, or `nil` for any.
    public func filtered(project: ProjectFilter = .any, tagId: UUID? = nil) -> [Row] {
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

    /// The rows matching both filters and the search field's text (All Notes, #1275).
    ///
    /// The text is trimmed of spaces and tabs, and a row matches when its text, its volume's id or its
    /// document's holds it, whatever the case, as `localizedCaseInsensitiveContains` finds it. Empty
    /// text filters nothing. Moved here from `AllNotesScreen.filtered` in S17b (FRUS Explorer Light).
    ///
    /// - Parameters:
    ///   - project: What to match on the project axis.
    ///   - tagId: A tag id every returned row must carry, or `nil` for any.
    ///   - query: The search field's text, as typed.
    public func filtered(project: ProjectFilter = .any, tagId: UUID? = nil, query: String) -> [Row] {
        let matches = filtered(project: project, tagId: tagId)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return matches }
        return matches.filter {
            $0.bodyText.localizedCaseInsensitiveContains(trimmed)
                || $0.volumeId.localizedCaseInsensitiveContains(trimmed)
                || $0.documentId.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// What the project filter is asking for.
    ///
    /// `unfiled` is its own case rather than a sentinel UUID. The old pane tagged its "Untagged"
    /// menu item with the all-zeros UUID and then asked whether a note's `projectIds` *contained*
    /// it — which no note ever does, so selecting it always produced zero results and the
    /// "no notes match" empty state. (`GlobalContextView`, since deleted, had it in a worse form:
    /// it minted a fresh `UUID()` per render, so the selection could not even stick.)
    public enum ProjectFilter: Hashable, Sendable {
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
    /// nothing and the two forms are spelled out. Reuses ``ResearchItemCounts/notesPhrase(_:)``
    /// rather than minting a third copy of the sentence; it groups the number through `CountCopy`
    /// since #1374, where both forms had carried it through a `%lld`.
    public static func noteCount(_ count: Int) -> String {
        ResearchItemCounts.notesPhrase(count)
    }

    /// "Showing 5 of 312 notes" — the honest version of a list that shows only its head.
    ///
    /// - Parameters:
    ///   - shown: How many rows the pane is actually drawing.
    ///   - total: How many match the current filters.
    public static func showingCount(shown: Int, of total: Int) -> String {
        guard shown < total else { return noteCount(total) }
        return String(format: String(localized: "settings.notes.showing %lld %@",
                                     defaultValue: "Showing %lld of %@"),
                      Int64(shown), noteCount(total))
    }
}
