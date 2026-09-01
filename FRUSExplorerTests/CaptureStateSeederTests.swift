// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import SwiftData
@testable import FRUSExplorer

// MARK: - CaptureStateSeederTests

/// State C's seeder (visual-marketing plan §7 step 6).
///
/// The seeding itself is env-gated and runs on the boot path, so what these pin is the shape it
/// produces and the two properties a capture session depends on: that it is idempotent, and that
/// nothing it writes pretends to be finished prose.
///
/// Version history:
///   1.0 — visual-marketing plan §7 step 6: initial implementation
@Suite("Capture state seeder")
@MainActor
struct CaptureStateSeederTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(ModelContainer.frusModelTypes),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none))
        return ModelContext(container)
    }

    /// **Idempotent by project name.** The capture store survives between launches, and a second
    /// run must not mint a second copy of everything — a device with two "Working project"s and
    /// four collections is not the state anyone meant to shoot.
    @Test("Seeding twice leaves one of everything")
    func seedingIsIdempotent() throws {
        let context = try makeContext()
        CaptureStateSeeder.seed(context: context)
        CaptureStateSeeder.seed(context: context)

        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Collection>())
                == CaptureStateSeeder.Content.collections.count)
        #expect(try context.fetchCount(FetchDescriptor<ResearchNote>())
                == CaptureStateSeeder.Content.notes.count)
        #expect(try context.fetchCount(FetchDescriptor<UserTag>())
                == CaptureStateSeeder.Content.tags.count)
        #expect(try context.fetchCount(FetchDescriptor<SavedSearch>())
                == CaptureStateSeeder.Content.searches.count)
    }

    /// Every list must have rows, because an empty state is exactly what State C exists to escape:
    /// on a corpus-full device the project, collection and tag screens are all still empty.
    @Test("It seeds structure: entries, assignments, and a project every record belongs to")
    func seedsTheStructure() throws {
        let context = try makeContext()
        CaptureStateSeeder.seed(context: context)

        let entries = try context.fetch(FetchDescriptor<CollectionEntry>())
        #expect(entries.count == CaptureStateSeeder.Content.collections
            .reduce(0) { $0 + $1.documents.count })
        #expect(try context.fetchCount(FetchDescriptor<DocumentTagAssignment>())
                == CaptureStateSeeder.Content.tagged.count)

        // The project is the thread: a capture of the project screen has to show its collections
        // and notes, which means both must carry its id.
        let project = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        let collections = try context.fetch(FetchDescriptor<Collection>())
        #expect(collections.allSatisfy { $0.projectIds.contains(project.id) })
        let notes = try context.fetch(FetchDescriptor<ResearchNote>())
        #expect(notes.allSatisfy { $0.projectIds.contains(project.id) })
    }

    /// **Nothing seeded may read as finished prose.**
    ///
    /// This is the property that keeps the seeder honest. Its job is to make the layout real, and
    /// a note that reads plausibly but says something slightly wrong about the record would be
    /// wrong in a store screenshot — the one place nobody re-reads. Every body says so on screen,
    /// and this fails the moment one does not.
    @Test("Every seeded body is visibly a placeholder")
    func nothingPretendsToBeFinished() throws {
        let context = try makeContext()
        CaptureStateSeeder.seed(context: context)
        let placeholder = CaptureStateSeeder.placeholderText

        // **The constant must INSTRUCT replacement, not merely be shared.** Asserting that every
        // body equals `placeholderText` proves only that one constant is used everywhere — swap
        // finished-looking prose into that constant and the assertion still passes, which is what
        // the mutation showed. This is the half that bites: the words have to tell the reader they
        // are provisional, on screen, in a screenshot.
        #expect(placeholder.localizedCaseInsensitiveContains("replace"),
                "The seeded placeholder no longer tells anyone to replace it. Its job is to make the layout real WITHOUT putting prose in a store screenshot that reads as a historian's finished note.")

        let notes = try context.fetch(FetchDescriptor<ResearchNote>())
        #expect(!notes.isEmpty)
        #expect(notes.allSatisfy { $0.bodyText == placeholder })

        let collections = try context.fetch(FetchDescriptor<Collection>())
        #expect(collections.allSatisfy { $0.note == placeholder })

        let project = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        #expect(project.researchQuestion == placeholder)
    }

    /// The documents it points at are real entries in the bundled manifest. A seeded note on a
    /// volume that does not exist would render an identifier the reader cannot act on.
    @Test("Every referenced volume is in the bundled manifest")
    func referencedVolumesExist() throws {
        let manifest = Set(ManifestStore().bundledEntries.map(\.volumeId))
        try #require(!manifest.isEmpty, "the bundled manifest must load")
        var referenced = Set(CaptureStateSeeder.Content.notes.map(\.volume))
        referenced.formUnion(CaptureStateSeeder.Content.tagged.map(\.volume))
        for collection in CaptureStateSeeder.Content.collections {
            referenced.formUnion(collection.documents.map(\.volume))
        }
        #expect(!referenced.isEmpty)
        for volume in referenced {
            #expect(manifest.contains(volume), "\(volume) is not in the bundled manifest")
        }
    }
}
