// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchItemCounts + the store

/// The three fetches behind ``ResearchItemCounts``: they read the store, so they stay in the app,
/// while the tally and the rows' summaries are FRUSCoreKit's (`FRUSCoreKit/Models/ResearchItemCounts.swift`),
/// where FRUS Explorer Light counts by them too.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): `fetch(from:)`, moved here from
///          `Models/ResearchItemCounts.swift` when the rest of it moved into the kit, with #1791's one
///          copy of each note
extension ResearchItemCounts {

    /// Tallies every project and tag reference in three fetches.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> ResearchItemCounts {
        // One copy of each note, so a note stored twice is counted once (#1791).
        let notes = ResearchNote.oneCopyEach((try? context.fetch(FetchDescriptor<ResearchNote>())) ?? [])
        let collections = (try? context.fetch(FetchDescriptor<Collection>())) ?? []
        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        return tally(noteProjectIds: notes.map(\.projectIds),
                     noteTagIds: notes.map(\.userTagIds),
                     collectionProjectIds: collections.map(\.projectIds),
                     assignmentTagIds: assignments.map(\.tagId))
    }
}
