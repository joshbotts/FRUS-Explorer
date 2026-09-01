// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG
import Foundation
import SwiftData

// MARK: - CaptureStateSeeder

/// Puts a device into **State C** — a library that has been *worked in* — so a capture session is
/// reproducible instead of an afternoon of typing (visual-marketing plan §6, §7 step 6).
///
/// ## Why a third state exists at all
/// §2(a) establishes that the splash and a corpus-bearing device are mutually exclusive by
/// construction, which makes the capture program a two-state plan: corpus-empty and corpus-full.
/// §6 records that those two are *incomplete*, because the surfaces a research app most needs to
/// show — a project header, a collection with entries, tagged documents, saved searches — are
/// **none of them downloaded and none of them bundled**. On a corpus-full device every one of those
/// screens is still an empty state.
///
/// ## What this seeds, and what it deliberately does not
/// It seeds the **structure**: a project, two collections with entries, tags with assignments,
/// notes attached to real documents, and saved searches. Every list then has rows, every badge a
/// count, and every layout can be judged.
///
/// **It does not write the words.** `placeholderText` is exactly that, and it says so on screen.
/// The prose in a store screenshot of a research tool is a historian's to write: a note that reads
/// plausibly but says something slightly wrong about the record is worse than an obvious
/// placeholder, and it would be wrong in a place nobody re-reads. Edit `Content.notes`,
/// `Content.collections` and the rest, re-run, and shoot.
///
/// ## Contract — mirrors the two existing seeders deliberately
/// Gated twice over: the whole file is `#if DEBUG`, so it is absent from AppStore and
/// DirectDistribution builds; and it is inert unless `FRUS_CAPTURE_SEED=1`. **Idempotent by project
/// name**, because the capture store survives between launches and a second run must not mint a
/// second copy of everything.
///
/// The documents it references are real and in the bundled manifest. It does not check whether they
/// are *downloaded*: a note or a tag on an unindexed document is a legitimate state (the row shows
/// its identifier and offers to download), and refusing to seed on a partly-stocked device would
/// make the seeder useless exactly where it is most wanted.
///
/// Version history:
///   1.0 — visual-marketing plan §7 step 6: initial implementation
enum CaptureStateSeeder {

    /// The launch-environment key that requests the seed.
    static let environmentKey = "FRUS_CAPTURE_SEED"

    /// The text every seeded record carries until someone replaces it.
    ///
    /// Deliberately visible as a placeholder **on screen**. The existing UI-test seeder makes its
    /// note implausible so nobody mistakes a seeded store for a used one; this one has the opposite
    /// job — the layout must look real — so the honesty has to live in the words rather than in the
    /// shape.
    static let placeholderText = "Replace before capture."

    // MARK: - Content

    /// Everything the seeder creates, in one place, so the owner edits data and never code.
    enum Content {

        /// The project every seeded record belongs to. Also the idempotency key.
        static let projectName = "Working project"

        /// The project's research question, shown in the project header.
        static let researchQuestion = placeholderText

        /// Tag names, in the order they should appear.
        static let tags = ["To read", "Key document", "Follow up"]

        /// Collections: a name, and the documents in it.
        static let collections: [(name: String, documents: [(volume: String, document: String)])] = [
            ("First collection", [("frus1961-63v06", "d1"), ("frus1969-76v13", "d1")]),
            ("Second collection", [("frus1977-80v06", "d1")]),
        ]

        /// Notes: the document each is attached to. The body is `placeholderText`.
        static let notes: [(volume: String, document: String)] = [
            ("frus1961-63v06", "d1"),
            ("frus1969-76v13", "d1"),
            ("frus1977-80v06", "d1"),
        ]

        /// Documents to tag, and which tag (by index into `tags`).
        static let tagged: [(volume: String, document: String, tag: Int)] = [
            ("frus1961-63v06", "d1", 0),
            ("frus1969-76v13", "d1", 1),
            ("frus1977-80v06", "d1", 2),
        ]

        /// Saved searches: a name and the keywords it runs.
        static let searches: [(name: String, keywords: String)] = [
            ("First saved search", "placeholder"),
            ("Second saved search", "placeholder"),
        ]
    }

    // MARK: - Seeding

    /// Seeds State C if requested. Runs on the same main-actor boot path as the other two seeders.
    ///
    /// - Parameter context: The container's `mainContext`.
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1" else { return }
        seed(context: context)
    }

    /// Seeds unconditionally.
    ///
    /// Split from `seedIfRequested` so the suite drives the real writer rather than a copy of it —
    /// a test that reproduced this logic would pass while the boot path wrote something else.
    ///
    /// - Parameter context: The container's `mainContext`.
    @MainActor
    static func seed(context: ModelContext) {
        let name = Content.projectName
        let existing = (try? context.fetchCount(FetchDescriptor<Project>(
            predicate: #Predicate { $0.name == name }))) ?? 0
        guard existing == 0 else {
            print("[CaptureStateSeeder] Already seeded; nothing to do")
            return
        }

        let project = Project(name: Content.projectName,
                              researchQuestion: Content.researchQuestion)
        context.insert(project)

        let tags = Content.tags.map { tagName -> UserTag in
            let tag = UserTag(name: tagName)
            context.insert(tag)
            return tag
        }

        for entry in Content.collections {
            let collection = Collection(name: entry.name,
                                        note: placeholderText,
                                        projectIds: [project.id])
            context.insert(collection)
            for (position, document) in entry.documents.enumerated() {
                context.insert(CollectionEntry(collectionId: collection.id,
                                               documentId: document.document,
                                               volumeId: document.volume,
                                               sortOrder: position))
            }
        }

        for note in Content.notes {
            context.insert(ResearchNote(documentId: note.document,
                                        volumeId: note.volume,
                                        bodyText: placeholderText,
                                        projectIds: [project.id]))
        }

        for assignment in Content.tagged where assignment.tag < tags.count {
            context.insert(DocumentTagAssignment(volumeId: assignment.volume,
                                                 documentId: assignment.document,
                                                 tagId: tags[assignment.tag].id))
        }

        for search in Content.searches {
            var parameters = SearchParameters()
            parameters.keywords = search.keywords
            context.insert(SavedSearch(name: search.name, parameters: parameters))
        }

        do {
            try context.save()
            print("""
                [CaptureStateSeeder] Seeded State C: 1 project, \(tags.count) tags, \
                \(Content.collections.count) collections, \(Content.notes.count) notes, \
                \(Content.searches.count) saved searches. \
                EVERY BODY READS "\(placeholderText)" — edit CaptureStateSeeder.Content and re-run \
                before shooting.
                """)
        } catch {
            print("[CaptureStateSeeder] Failed to seed: \(error)")
        }
    }
}
#endif
