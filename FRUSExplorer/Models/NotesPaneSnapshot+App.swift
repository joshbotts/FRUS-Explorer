// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - NotesPaneSnapshot + the store

/// The fetches behind ``NotesPaneSnapshot``: they read the store, so they stay in the app, while All
/// Notes' rows, filters and counts are FRUSCoreKit's (`FRUSCoreKit/Models/NotesPaneSnapshot.swift`),
/// where FRUS Explorer Light builds and filters its All Notes by them too.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): `fetch(from:)` and `note(id:in:)`, moved here
///          from `Models/NotesPaneSnapshot.swift` when the rest of it moved into the kit, with #1791's one
///          copy of each note; `fetch` passes what it read to the kit's `build(notes:projects:tags:)`
extension NotesPaneSnapshot {

    /// Builds the snapshot in three fetches, resolving every row's names as it goes.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> NotesPaneSnapshot {
        // One row per note, not per stored copy of one, so no two rows share an id (#1791).
        let notes = ResearchNote.oneCopyEach((try? context.fetch(
            FetchDescriptor<ResearchNote>(
                sortBy: [SortDescriptor(\.lastModified, order: .reverse)]))) ?? [])
        let projects = (try? context.fetch(
            FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let tags = (try? context.fetch(
            FetchDescriptor<UserTag>(sortBy: [SortDescriptor(\.name)]))) ?? []

        // The kit resolves every row's names as it builds them (`build(notes:projects:tags:)`), in the
        // order these fetches give.
        return build(
            notes: notes.map {
                Note(id: $0.id, volumeId: $0.volumeId, documentId: $0.documentId, bodyText: $0.bodyText,
                     lastModified: $0.lastModified, projectIds: $0.projectIds, userTagIds: $0.userTagIds)
            },
            projects: projects.map { (id: $0.id, name: $0.name) },
            tags: tags.map { (id: $0.id, name: $0.name) })
    }

    /// Re-reads one note by id, for the editor sheet.
    ///
    /// Rows are plain values, so opening the editor needs the live model back. Scalar `==` on a
    /// UUID is safe in a `#Predicate` — the trap documented above is `contains` on a
    /// transformable array column, not equality on a stored scalar. A note stored as several
    /// copies under one id returns the copy last modified (``ResearchNote/copies(of:in:)``, #1791).
    ///
    /// - Parameters:
    ///   - id: The note's id.
    ///   - context: The SwiftData context to read.
    /// - Returns: The note, or `nil` if it has since been deleted.
    @MainActor
    static func note(id: UUID, in context: ModelContext) -> ResearchNote? {
        ResearchNote.copies(of: id, in: context).first
    }
}
