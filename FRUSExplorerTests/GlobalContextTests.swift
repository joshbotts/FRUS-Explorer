// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - GlobalContextTests

@MainActor
struct GlobalContextTests {

    // MARK: - AggregationTest

    @Test("AggregationTest: all activity across two projects and untagged is visible in global view")
    func aggregationShowsAllActivity() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Project A")
        let projectB = Project(name: "Project B")
        context.insert(projectA)
        context.insert(projectB)

        // Notes: one per project, one untagged
        let noteA = ResearchNote(documentId: "d1", volumeId: "vol1", projectIds: [projectA.id])
        let noteB = ResearchNote(documentId: "d2", volumeId: "vol1", projectIds: [projectB.id])
        let noteNone = ResearchNote(documentId: "d3", volumeId: "vol2", projectIds: [])
        context.insert(noteA)
        context.insert(noteB)
        context.insert(noteNone)

        // Collections: one per project
        let colA = Collection(name: "Col A", projectIds: [projectA.id])
        let colB = Collection(name: "Col B", projectIds: [projectB.id])
        context.insert(colA)
        context.insert(colB)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        // Global view (no filter) should show all 3 notes and 2 collections
        #expect(vm.allNotes.count == 3)
        #expect(vm.allCollections.count == 2)
        #expect(vm.filteredNotes.count == 3)
        #expect(vm.filteredCollections.count == 2)
    }

    @Test("AggregationTest: untagged note count is correct")
    func untaggedNoteCountIsCorrect() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Alpha")
        context.insert(projectA)

        let tagged = ResearchNote(documentId: "d1", volumeId: "v1", projectIds: [projectA.id])
        let untagged1 = ResearchNote(documentId: "d2", volumeId: "v1", projectIds: [])
        let untagged2 = ResearchNote(documentId: "d3", volumeId: "v2", projectIds: [])
        context.insert(tagged)
        context.insert(untagged1)
        context.insert(untagged2)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        #expect(vm.untaggedNotesCount == 2)
    }

    // MARK: - NotesBrowserFilterTest

    @Test("NotesBrowserFilterTest: filtering by project A shows only project A notes")
    func notesBrowserFilterByProject() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Alpha")
        let projectB = Project(name: "Beta")
        context.insert(projectA)
        context.insert(projectB)

        let noteA1 = ResearchNote(documentId: "d1", volumeId: "v1", projectIds: [projectA.id])
        let noteA2 = ResearchNote(documentId: "d2", volumeId: "v1", projectIds: [projectA.id])
        let noteB1 = ResearchNote(documentId: "d3", volumeId: "v2", projectIds: [projectB.id])
        let noteNone = ResearchNote(documentId: "d4", volumeId: "v2", projectIds: [])
        context.insert(noteA1)
        context.insert(noteA2)
        context.insert(noteB1)
        context.insert(noteNone)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        // Set filter to project A
        vm.selectedProjectFilter = projectA.id
        let filtered = vm.filteredNotes

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.projectIds.contains(projectA.id) })
        #expect(!filtered.contains(where: { $0.projectIds.contains(projectB.id) }))
    }

    @Test("NotesBrowserFilterTest: filtering by user tag shows only notes with that tag")
    func notesBrowserFilterByUserTag() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = UserTag(name: "Primary Source")
        context.insert(tag)

        let noteTagged1 = ResearchNote(documentId: "d1", volumeId: "v1", userTagIds: [tag.id])
        let noteTagged2 = ResearchNote(documentId: "d2", volumeId: "v1", userTagIds: [tag.id])
        let noteUntagged = ResearchNote(documentId: "d3", volumeId: "v1", userTagIds: [])
        context.insert(noteTagged1)
        context.insert(noteTagged2)
        context.insert(noteUntagged)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        vm.selectedUserTagFilter = tag.id
        let filtered = vm.filteredNotes

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.userTagIds.contains(tag.id) })
    }

    @Test("NotesBrowserFilterTest: AND logic — project + tag filter both must match")
    func notesBrowserANDFilter() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Alpha")
        context.insert(projectA)
        let tag = UserTag(name: "Important")
        context.insert(tag)

        let bothMatch = ResearchNote(documentId: "d1", volumeId: "v1",
                                     projectIds: [projectA.id], userTagIds: [tag.id])
        let onlyProject = ResearchNote(documentId: "d2", volumeId: "v1",
                                       projectIds: [projectA.id], userTagIds: [])
        let onlyTag = ResearchNote(documentId: "d3", volumeId: "v1",
                                   projectIds: [], userTagIds: [tag.id])
        context.insert(bothMatch)
        context.insert(onlyProject)
        context.insert(onlyTag)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        vm.selectedProjectFilter = projectA.id
        vm.selectedUserTagFilter = tag.id
        let filtered = vm.filteredNotes

        #expect(filtered.count == 1)
        #expect(filtered.first?.documentId == "d1")
    }

    // MARK: - CollectionsBrowserTest

    @Test("CollectionsBrowserTest: all collections are visible in global context (no filter)")
    func collectionsVisibleInGlobalContext() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Alpha")
        let projectB = Project(name: "Beta")
        context.insert(projectA)
        context.insert(projectB)

        let colA = Collection(name: "Col A", projectIds: [projectA.id])
        let colB = Collection(name: "Col B", projectIds: [projectB.id])
        let colNone = Collection(name: "Col None", projectIds: [])
        context.insert(colA)
        context.insert(colB)
        context.insert(colNone)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        // No filter = all visible
        #expect(vm.filteredCollections.count == 3)
    }

    @Test("CollectionsBrowserTest: filtering collections by project shows only matching collections")
    func collectionsFilterByProject() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let projectA = Project(name: "Alpha")
        let projectB = Project(name: "Beta")
        context.insert(projectA)
        context.insert(projectB)

        let colA = Collection(name: "Col A", projectIds: [projectA.id])
        let colB = Collection(name: "Col B", projectIds: [projectB.id])
        context.insert(colA)
        context.insert(colB)

        let vm = GlobalContextViewModel()
        vm.load(context: context)

        vm.selectedProjectFilter = projectA.id
        let filtered = vm.filteredCollections

        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Col A")
    }

    // MARK: - Helper

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ResearchNote.self,
            Collection.self,
            CollectionEntry.self,
            UserTag.self,
            ReadingHistoryEntry.self,
            GeneratedSummary.self,
            SummarizationPrompt.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}

// MARK: - ResearchNote test convenience init

private extension ResearchNote {
    /// Convenience initialiser for tests — omits `bodyText` and `selectedSummaryIds`.
    /// Calls the designated initialiser explicitly to avoid infinite self-recursion.
    convenience init(
        documentId: String,
        volumeId: String,
        projectIds: [UUID] = [],
        userTagIds: [UUID] = []
    ) {
        self.init(
            documentId: documentId,
            volumeId: volumeId,
            bodyText: "",
            projectIds: projectIds,
            userTagIds: userTagIds,
            selectedSummaryIds: []
        )
    }
}

// Note: Collection.init(name:note:projectIds:) already accepts projectIds directly;
// no convenience init needed — tests call the production initialiser.
