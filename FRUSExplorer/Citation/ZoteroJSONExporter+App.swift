// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ZoteroJSONExporter + the library's tags and notes

/// The half of `ZoteroJSONExporter` that reads the research library, which is SwiftData's and so the
/// app's. The exporter and its items are FRUSCoreKit's (`FRUSCoreKit/Citation/ZoteroJSONExporter.swift`).
///
/// Version history:
///   1.0 — FRUS Explorer Light: moved out of `ZoteroJSONExporter.swift` unchanged, when that moved
///          into the kit
extension ZoteroJSONExporter {

    // MARK: - Tags & Notes

    /// Resolves the Zotero `tags` and `notes` for a single FRUS document.
    ///
    /// `tags` combines `DocumentTagAssignment`s made directly on the document
    /// with tags applied to any of the document's `ResearchNote`s. `notes`
    /// carries the body text of every `ResearchNote` for the document.
    @MainActor
    public static func fetchTagsAndNotes(
        documentId: String,
        volumeId: String,
        context: ModelContext
    ) -> (tags: [String], notes: [String]) {
        let allTags = (try? context.fetch(FetchDescriptor<UserTag>())) ?? []
        // uniquingKeysWith: CloudKit sync can transiently surface duplicate ids;
        // uniqueKeysWithValues would crash on them.
        let tagNameById = Dictionary(allTags.map { ($0.id, $0.name) },
                                     uniquingKeysWith: { first, _ in first })

        let assignments = (try? context.fetch(FetchDescriptor<DocumentTagAssignment>(
            predicate: #Predicate { $0.volumeId == volumeId && $0.documentId == documentId }
        ))) ?? []

        let notes = (try? context.fetch(FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.volumeId == volumeId && $0.documentId == documentId }
        ))) ?? []

        var tagNames = Set<String>()
        for assignment in assignments {
            if let name = tagNameById[assignment.tagId] {
                tagNames.insert(name)
            }
        }
        for note in notes {
            for tagId in note.userTagIds {
                if let name = tagNameById[tagId] {
                    tagNames.insert(name)
                }
            }
        }

        let noteBodies = notes.map(\.bodyText).filter { !$0.isEmpty }
        return (tags: tagNames.sorted(), notes: noteBodies)
    }
}
