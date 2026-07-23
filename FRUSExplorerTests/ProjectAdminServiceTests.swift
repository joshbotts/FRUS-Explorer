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

// MARK: - ProjectAdminServiceTests

@MainActor
struct ProjectAdminServiceTests {

    // MARK: - Delete

    @Test("Deleting the active project switches AppState to Global Context")
    func deleteActiveProjectClearsActiveProjectId() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let project = Project(name: "Nixon Administration")
        ctx.insert(project)
        appState.activeProjectId = project.id

        ProjectAdminService.delete(project, context: ctx, appState: appState)

        #expect(appState.activeProjectId == nil)
        #expect(try ctx.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    @Test("Deleting a non-active project leaves AppState.activeProjectId unchanged")
    func deleteInactiveProjectLeavesActiveProjectIdUnchanged() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let active = Project(name: "Active Project")
        let other = Project(name: "Other Project")
        ctx.insert(active)
        ctx.insert(other)
        appState.activeProjectId = active.id

        ProjectAdminService.delete(other, context: ctx, appState: appState)

        #expect(appState.activeProjectId == active.id)
        #expect(try ctx.fetch(FetchDescriptor<Project>()).count == 1)
    }

    @Test("Deleting a project orphans referencing records instead of deleting them")
    func deleteOrphansActivityRecords() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let project = Project(name: "Nixon Administration")
        ctx.insert(project)

        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", projectIds: [project.id])
        ctx.insert(note)
        let history = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01", projectId: project.id)
        ctx.insert(history)

        ProjectAdminService.delete(project, context: ctx, appState: appState)

        let notes = try ctx.fetch(FetchDescriptor<ResearchNote>())
        #expect(notes.first?.projectIds == [project.id])

        let histories = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(histories.first?.projectId == project.id)
    }

    // MARK: - Merge

    @Test("Merge reassigns ResearchNote and Collection projectIds and deletes the source")
    func mergeReassignsArrayProjectIds() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let source = Project(name: "Source")
        let target = Project(name: "Target")
        ctx.insert(source)
        ctx.insert(target)

        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", projectIds: [source.id])
        ctx.insert(note)
        let collection = Collection(name: "My Collection", projectIds: [source.id, target.id])
        ctx.insert(collection)

        ProjectAdminService.merge(source, into: target, context: ctx, appState: appState)

        #expect(note.projectIds == [target.id])
        // Already referenced target — must not be duplicated.
        #expect(collection.projectIds == [target.id])

        let remaining = try ctx.fetch(FetchDescriptor<Project>())
        #expect(remaining.map(\.id) == [target.id])
    }

    @Test("Merge reassigns GeneratedSummary, ReadingHistoryEntry, and SearchHistoryEntry projectId")
    func mergeReassignsScalarProjectIds() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let source = Project(name: "Source")
        let target = Project(name: "Target")
        ctx.insert(source)
        ctx.insert(target)

        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: UUID(),
            responseText: "Summary text",
            projectId: source.id
        )
        ctx.insert(summary)
        let history = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01", projectId: source.id)
        ctx.insert(history)
        let searchHistory = SearchHistoryEntry(queryText: "détente", resultCount: 3, projectId: source.id)
        ctx.insert(searchHistory)
        // A search made in another project must keep its own reference.
        let unrelatedSearch = SearchHistoryEntry(queryText: "berlin", resultCount: 1, projectId: target.id)
        ctx.insert(unrelatedSearch)

        ProjectAdminService.merge(source, into: target, context: ctx, appState: appState)

        #expect(summary.projectId == target.id)
        #expect(history.projectId == target.id)
        #expect(searchHistory.projectId == target.id)
        #expect(unrelatedSearch.projectId == target.id)
    }

    @Test("Merging the active project redirects AppState.activeProjectId to the target")
    func mergeRedirectsActiveProjectId() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let source = Project(name: "Source")
        let target = Project(name: "Target")
        ctx.insert(source)
        ctx.insert(target)
        appState.activeProjectId = source.id

        ProjectAdminService.merge(source, into: target, context: ctx, appState: appState)

        #expect(appState.activeProjectId == target.id)
    }

    @Test("Merging a project into itself is a no-op")
    func mergeIntoSelfIsRejected() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let appState = AppState()

        let project = Project(name: "Solo")
        ctx.insert(project)
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", projectIds: [project.id])
        ctx.insert(note)
        appState.activeProjectId = project.id

        ProjectAdminService.merge(project, into: project, context: ctx, appState: appState)

        #expect(try ctx.fetch(FetchDescriptor<Project>()).count == 1)
        #expect(note.projectIds == [project.id])
        #expect(appState.activeProjectId == project.id)
    }
}

// MARK: - ProjectHomeSummaryTests (#377 Phase 1)

/// Pure-logic tests for the Project Home dashboard's activity summary. No SwiftData
/// container is needed: the summary only reads stored properties off model objects.
@MainActor
struct ProjectHomeSummaryTests {

    private func note(_ vol: String, _ doc: String) -> ResearchNote {
        ResearchNote(documentId: doc, volumeId: vol)
    }
    private func visit(_ vol: String, _ doc: String) -> ReadingHistoryEntry {
        ReadingHistoryEntry(documentId: doc, volumeId: vol)
    }

    @Test("Counts reflect the supplied records")
    func counts() {
        let s = ProjectHomeSummary(
            notes: [note("v1", "d1"), note("v1", "d2")],
            collections: [Collection(name: "A"), Collection(name: "B"), Collection(name: "C")],
            visits: [visit("v1", "d1")],
            searches: [SearchHistoryEntry(queryText: "détente")]
        )
        #expect(s.noteCount == 2)
        #expect(s.collectionCount == 3)
        #expect(s.searchCount == 1)
        #expect(!s.isEmpty)
    }

    @Test("documentsVisitedCount counts DISTINCT documents (re-reads don't inflate)")
    func distinctVisits() {
        let s = ProjectHomeSummary(
            notes: [], collections: [],
            visits: [visit("v1", "d1"), visit("v1", "d1"), visit("v1", "d2"), visit("v2", "d1")],
            searches: []
        )
        // (v1/d1 twice), v1/d2, v2/d1 → 3 distinct.
        #expect(s.documentsVisitedCount == 3)
    }

    @Test("recentVisits de-duplicates by document and caps at recentLimit")
    func recentVisitsDedupAndCap() {
        // A duplicate of the newest doc at the front, then 7 distinct docs.
        var visits = [visit("v1", "dup"), visit("v1", "dup")]
        for i in 0..<7 { visits.append(visit("v1", "d\(i)")) }
        let s = ProjectHomeSummary(notes: [], collections: [], visits: visits, searches: [])
        let recent = s.recentVisits
        #expect(recent.count == ProjectHomeSummary.recentLimit)
        // The duplicate collapses to one entry, and it's first (newest).
        #expect(recent.first?.documentId == "dup")
        let keys = recent.map { "\($0.volumeId)/\($0.documentId)" }
        #expect(Set(keys).count == keys.count)   // no duplicates survive
    }

    @Test("Recent feeds cap notes/searches at recentLimit; isEmpty when nothing tagged")
    func recentCapsAndEmpty() {
        let manyNotes = (0..<9).map { note("v1", "n\($0)") }
        let manySearches = (0..<9).map { SearchHistoryEntry(queryText: "q\($0)") }
        let s = ProjectHomeSummary(notes: manyNotes, collections: [], visits: [], searches: manySearches)
        #expect(s.recentNotes.count == ProjectHomeSummary.recentLimit)
        #expect(s.recentSearches.count == ProjectHomeSummary.recentLimit)

        let empty = ProjectHomeSummary(notes: [], collections: [], visits: [], searches: [])
        #expect(empty.isEmpty)
    }
}
