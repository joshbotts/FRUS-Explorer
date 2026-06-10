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

    @Test("Merge reassigns GeneratedSummary and ReadingHistoryEntry projectId")
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

        ProjectAdminService.merge(source, into: target, context: ctx, appState: appState)

        #expect(summary.projectId == target.id)
        #expect(history.projectId == target.id)
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
