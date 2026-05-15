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

// MARK: - Fixture Helper

private func makeProjectEntry(
    documentId: String = "d1",
    volumeId: String = "frus1969-76v01"
) -> DocumentBrowserEntry {
    DocumentBrowserEntry(
        documentId: documentId,
        volumeId: volumeId,
        documentNumber: "1",
        header: "Memorandum of Conversation",
        dateline: "Washington, January 20, 1969.",
        sourceNote: nil
    )
}

// MARK: - ProjectContextTests

@MainActor
struct ProjectContextTests {

    // MARK: - Project Switching

    @Test("Switching active project updates AppState.activeProjectId")
    func projectSwitchUpdatesActiveProjectId() {
        let appState = AppState()
        let projectA = UUID()
        let projectB = UUID()

        appState.activeProjectId = projectA
        #expect(appState.activeProjectId == projectA)

        appState.activeProjectId = projectB
        #expect(appState.activeProjectId == projectB)

        // Switch to global context
        appState.activeProjectId = nil
        #expect(appState.activeProjectId == nil)
    }

    // MARK: - Global Context

    @Test("ReadingHistoryEntry created with nil projectId in global context")
    func globalContextReadingHistoryHasNilProjectId() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let store = SubjectTagStore(entries: [], appearances: [])
        let vm = DocumentViewModel(
            entry: makeProjectEntry(),
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        vm.recordReadingHistory(projectId: nil, in: ctx)

        let all = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(all.count == 1)
        let record = try #require(all.first)
        #expect(record.projectId == nil)
    }

    // MARK: - Activity Tagging Integration

    @Test("ReadingHistoryEntry records the active project ID at time of document open")
    func activityTaggingRecordsActiveProjectId() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let projectId = UUID()

        let store = SubjectTagStore(entries: [], appearances: [])
        let vm = DocumentViewModel(
            entry: makeProjectEntry(documentId: "d42", volumeId: "frus1969-76v01"),
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        vm.recordReadingHistory(projectId: projectId, in: ctx)

        let all = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(all.count == 1)
        let record = try #require(all.first)
        #expect(record.projectId == projectId)
        #expect(record.documentId == "d42")
        #expect(record.volumeId == "frus1969-76v01")
    }

    // MARK: - Project Deletion

    @Test("Deleting a project leaves activity records with the orphaned projectId")
    func deletedProjectActivityRecordsRemain() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext

        let project = Project(name: "Nixon Administration")
        ctx.insert(project)

        let note = ResearchNote(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            projectIds: [project.id]
        )
        ctx.insert(note)

        let historyEntry = ReadingHistoryEntry(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            projectId: project.id
        )
        ctx.insert(historyEntry)

        // Delete the project
        let projectId = project.id
        ctx.delete(project)

        // Activity records must still exist with the orphaned projectId
        let notes = try ctx.fetch(FetchDescriptor<ResearchNote>())
        #expect(notes.count == 1)
        #expect(notes.first?.projectIds.contains(projectId) == true)

        let history = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(history.count == 1)
        #expect(history.first?.projectId == projectId)
    }
}
