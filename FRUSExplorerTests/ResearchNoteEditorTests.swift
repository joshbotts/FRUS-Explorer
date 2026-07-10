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

private func makeEditorEntry(
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

// MARK: - ResearchNoteEditorTests

@MainActor
struct ResearchNoteEditorTests {

    // MARK: - Note Creation

    @Test("Created note carries the active project ID in projectIds")
    func noteCreationAppliesActiveProjectTag() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let projectId = UUID()

        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: projectId
        )
        vm.bodyText = "Test note."
        vm.save(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<ResearchNote>())
        #expect(all.count == 1)
        let note = try #require(all.first)
        #expect(note.projectIds.contains(projectId))
        #expect(note.bodyText == "Test note.")
    }

    // MARK: - Tag Inheritance

    @Test("Active project tag is auto-applied at init and removable via toggleProjectTag")
    func tagInheritanceAutoAppliedAndRemovable() {
        let projectId = UUID()
        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: projectId
        )

        // Auto-applied
        #expect(vm.projectIds.contains(projectId))

        // User removes it
        vm.toggleProjectTag(projectId)
        #expect(!vm.projectIds.contains(projectId))
    }

    // MARK: - Summary Promotion

    @Test("Promoting a summary inserts its text into the body and records its ID")
    func summaryPromotionInsertsTextIntoBody() {
        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: UUID(),
            responseText: "Key finding about the memo."
        )
        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: nil
        )

        vm.promoteSummary(summary)

        #expect(vm.bodyText == "Key finding about the memo.")
        #expect(vm.selectedSummaryIds.contains(summary.id))
    }

    @Test("Promoting the same summary twice is idempotent")
    func summaryPromotionIdempotent() {
        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: UUID(),
            responseText: "Summary text."
        )
        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: nil
        )

        vm.promoteSummary(summary)
        vm.promoteSummary(summary)

        #expect(vm.selectedSummaryIds.filter { $0 == summary.id }.count == 1)
        #expect(vm.bodyText == "Summary text.")
    }

    // MARK: - Cross-Project Reveal

    @Test("Cross-project notes are visible, revealable, and promotable to the active project")
    func crossProjectNotesHiddenRevealableAndPromotable() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let projectA = UUID()
        let projectB = UUID()

        let note = ResearchNote(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            projectIds: [projectA]
        )
        ctx.insert(note)

        let docVM = DocumentViewModel(
            entry: makeEditorEntry(documentId: "d1", volumeId: "frus1969-76v01"),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        )

        // With projectB active, note should appear as cross-project
        docVM.refreshCrossProjectNoteCount(activeProjectId: projectB, context: ctx)
        #expect(docVM.crossProjectNoteCount == 1)
        #expect(docVM.crossProjectNotes.count == 1)

        // Promote: add projectB to the note's projectIds
        let crossNote = try #require(docVM.crossProjectNotes.first)
        crossNote.projectIds = crossNote.projectIds + [projectB]

        // Refresh — note now belongs to projectB, no longer cross-project
        docVM.refreshCrossProjectNoteCount(activeProjectId: projectB, context: ctx)
        #expect(docVM.crossProjectNoteCount == 0)
        #expect(docVM.crossProjectNotes.isEmpty)
    }
}
