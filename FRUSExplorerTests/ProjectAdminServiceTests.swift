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

    // MARK: - Collection membership (#377 Phase 5)

    @Test("toggledMembership attaches then detaches a project, preserving other projects")
    func collectionMembershipToggle() {
        let project = UUID()
        let otherProject = UUID()

        // Absent → appended.
        let attached = ProjectCollectionsEditor.toggledMembership(project, in: [otherProject])
        #expect(attached.contains(project))
        #expect(attached.contains(otherProject))   // the collection's other project is untouched

        // Present → removed, leaving the other project.
        let detached = ProjectCollectionsEditor.toggledMembership(project, in: attached)
        #expect(!detached.contains(project))
        #expect(detached == [otherProject])
    }

    // MARK: - Working-on chrome (#377 Phase 5)

    @Test("WorkingOnBanner.resolvedQuestion gates on an active project with a non-empty question")
    func workingOnResolvedQuestion() {
        let cuba = Project(name: "Cuba"); cuba.researchQuestion = "How was ExComm briefed?"
        let blank = Project(name: "Blank"); blank.researchQuestion = "   "
        let noQuestion = Project(name: "NoQ")   // researchQuestion stays nil
        let padded = Project(name: "Pad"); padded.researchQuestion = "  détente  "
        let projects = [cuba, blank, noQuestion, padded]

        // Active project with a real question → the trimmed question.
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: cuba.id, projects: projects) == "How was ExComm briefed?")
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: padded.id, projects: projects) == "détente")
        // Global Context (nil), a question-less project, or a whitespace-only question → nothing.
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: nil, projects: projects) == nil)
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: noQuestion.id, projects: projects) == nil)
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: blank.id, projects: projects) == nil)
        // A deleted/absent project id → nothing, no crash.
        #expect(WorkingOnBanner.resolvedQuestion(activeProjectId: UUID(), projects: projects) == nil)
    }

    @Test("SecondProjectNudge.shouldNudge fires only at ≥ 2 projects and only when not already shown")
    func secondProjectNudgeShouldNudge() {
        // The 1 → 2 transition is the trigger; a single project never nudges.
        #expect(SecondProjectNudge.shouldNudge(projectCount: 0, alreadyShown: false) == false)
        #expect(SecondProjectNudge.shouldNudge(projectCount: 1, alreadyShown: false) == false)
        #expect(SecondProjectNudge.shouldNudge(projectCount: 2, alreadyShown: false) == true)
        #expect(SecondProjectNudge.shouldNudge(projectCount: 5, alreadyShown: false) == true)
        // Once shown, it never fires again regardless of count.
        #expect(SecondProjectNudge.shouldNudge(projectCount: 2, alreadyShown: true) == false)
        #expect(SecondProjectNudge.shouldNudge(projectCount: 9, alreadyShown: true) == false)
    }

    @Test("SecondProjectNudge.seedAlreadyShown marks pre-existing multi-project users so they are never retro-nudged")
    func secondProjectNudgeSeedAlreadyShown() {
        // A user who already has ≥ 2 projects when the feature ships is seeded as shown.
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 2, currentlyShown: false) == true)
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 7, currentlyShown: false) == true)
        // A user below the threshold is NOT seeded — a genuine 1 → 2 transition can still nudge them.
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 0, currentlyShown: false) == false)
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 1, currentlyShown: false) == false)
        // An already-shown flag is preserved (idempotent) regardless of count.
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 0, currentlyShown: true) == true)
        #expect(SecondProjectNudge.seedAlreadyShown(projectCount: 5, currentlyShown: true) == true)
    }

    @Test("A local fetch reflects a just-inserted, pre-save project (the nudge count-timing contract)")
    func secondProjectNudgeCountSeesPendingInsert() throws {
        // ProjectEditorView.saveProject counts projects immediately after inserting the new one,
        // BEFORE the autosave — so the count must include the pending insert. SwiftData's
        // FetchDescriptor includes pending changes by default; pin that so the nudge never
        // under-counts and silently no-ops at the true 1 → 2 transition.
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        context.insert(Project(name: "First"))
        let afterFirst = try context.fetch(FetchDescriptor<Project>()).count
        #expect(afterFirst == 1)
        #expect(SecondProjectNudge.shouldNudge(projectCount: afterFirst, alreadyShown: false) == false)

        context.insert(Project(name: "Second"))
        let afterSecond = try context.fetch(FetchDescriptor<Project>()).count
        #expect(afterSecond == 2)
        #expect(SecondProjectNudge.shouldNudge(projectCount: afterSecond, alreadyShown: false) == true)
    }
}
