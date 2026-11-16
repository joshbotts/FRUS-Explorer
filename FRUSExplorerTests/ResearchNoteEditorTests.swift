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

    /// Removal goes through the SELECTION, as the picker does, since #1275 retired the per-row
    /// toggles: `NoteAssignmentPicker` binds `vm.projectIds` wholesale, so `toggleProjectTag` lost
    /// its last caller and was deleted. A test that kept calling it would have gone on advertising
    /// a removal path nothing ships.
    @Test("Active project tag is auto-applied at init and removable from the selection")
    func tagInheritanceAutoAppliedAndRemovable() {
        let projectId = UUID()
        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: projectId
        )

        // Auto-applied
        #expect(vm.projectIds.contains(projectId))

        // User removes it — exactly what the picker's binding does.
        vm.projectIds.removeAll { $0 == projectId }
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

    /// Not its stored JSON (2026-10-31): a structured summary goes into the note as its fields.
    @Test("Promoting a structured summary inserts its fields, a Label: text paragraph each")
    func structuredSummaryPromotionInsertsFields() {
        let schema = StructuredSummarySchema(fields: [
            .init(name: "Subject", description: "The document's subject"),
            .init(name: "KeyDecision", description: "What was decided"),
        ])
        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: UUID(),
            responseText: #"{"KeyDecision": "The quarantine stands.", "Subject": "Cuba."}"#,
            responseFormat: .structured(schema: schema)
        )
        let vm = ResearchNoteEditorViewModel(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            activeProjectId: nil
        )
        vm.bodyText = "My reading."

        vm.promoteSummary(summary)

        #expect(vm.bodyText == "My reading.\n\nSubject: Cuba.\n\nKey Decision: The quarantine stands.")
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

    // MARK: - Unsaved changes (L19, #1919, IPA-2)

    /// A new note's editor opens with nothing to lose — the active project it files the note under
    /// is the editor's own doing, not the reader's — and typing is a change that undoing undoes.
    @Test("A new note has changes once text is typed, and none once it is cleared again")
    func newNoteChangesFollowTheText() {
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: UUID())
        #expect(!vm.hasChanges, "a new note's editor asks before closing though nothing was done")
        vm.setPlainBody("A first thought.")
        #expect(vm.hasChanges)
        vm.setPlainBody("")
        #expect(!vm.hasChanges, "an emptied new note still counts as a change")
    }

    /// An existing note opens unchanged. Its tags, projects and inserted summaries are compared as
    /// sets: a picker that takes a tag off and puts it back reorders the array and loses nothing.
    @Test("An existing note's tags, projects and summaries are changes, and their order is not")
    func existingNoteAssignmentsAreChanges() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let tagA = UUID(), tagB = UUID(), project = UUID()
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Body.",
                                projectIds: [project], userTagIds: [tagA, tagB])
        ctx.insert(note)
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil, noteToEdit: note)
        #expect(!vm.hasChanges)

        vm.userTagIds = [tagB]
        #expect(vm.hasChanges, "taking a tag off is not a change")
        vm.userTagIds = [tagB, tagA]
        #expect(!vm.hasChanges, "the same tags in another order count as a change")

        vm.projectIds = []
        #expect(vm.hasChanges, "taking the note out of its project is not a change")
        vm.projectIds = [project]
        #expect(!vm.hasChanges)

        vm.selectedSummaryIds = [UUID()]
        #expect(vm.hasChanges, "an inserted summary's link is not a change")
    }

    /// Formatting alone is a change while there is text to carry it, and the record of what the
    /// editor opened with does not move when the editor appears again.
    @Test("Formatting alone is a change on a note with text, and none on an empty one")
    func formattingAloneIsAChangeOnlyWithText() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Body.")
        note.richText = Data("{\\rtf1 plain}".utf8)
        ctx.insert(note)
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil, noteToEdit: note)
        vm.load(context: ctx)
        #expect(!vm.hasChanges, "opening and appearing count as a change")
        #expect(vm.opening.richText == Data("{\\rtf1 plain}".utf8))

        vm.richText = Data("{\\rtf1 \\b bold}".utf8)   // what the rich editor reports for a bolded word
        #expect(vm.hasChanges, "bolding a word is not a change")
        vm.load(context: ctx)
        #expect(vm.hasChanges, "appearing again put the stored formatting back")
        #expect(vm.opening.richText == Data("{\\rtf1 plain}".utf8), "the opening record moved")

        let empty = ResearchNoteEditorViewModel(documentId: "d2", volumeId: "frus1969-76v01",
                                                activeProjectId: nil)
        empty.richText = Data("{\\rtf1 }".utf8)   // a letter typed and deleted in the rich editor
        #expect(!empty.hasChanges, "an empty new note asks before closing")
    }

    /// Inserting a summary changes the body and links the summary, and both are what Save writes.
    @Test("Inserting a summary into a new note is a change")
    func insertingASummaryIsAChange() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let summary = GeneratedSummary(documentId: "d1", volumeId: "frus1969-76v01",
                                       promptId: UUID(), responseText: "A summary.")
        ctx.insert(summary)
        let vm = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                             activeProjectId: nil)
        vm.promoteSummary(summary)
        #expect(vm.hasChanges)
    }

    /// A note the editor has deleted is built into an editor once more as the sheet that showed it
    /// closes. All Notes' sheet did so on the iPad Pro 13-inch (M5) under iOS 27.0, and the model's
    /// reading the deleted note's `projectIds` trapped: the model must read such a note as none.
    @Test("A deleted note is read as none, so building its editor again does not trap")
    func deletedNoteIsReadAsNone() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let note = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01", bodyText: "Body.",
                                projectIds: [UUID()], userTagIds: [UUID()])
        ctx.insert(note)
        try ctx.save()
        let editor = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                                 activeProjectId: nil, noteToEdit: note)
        #expect(editor.noteToEdit === note, "a stored note is not read")
        editor.delete(context: ctx)
        try ctx.save()

        let rebuilt = ResearchNoteEditorViewModel(documentId: "d1", volumeId: "frus1969-76v01",
                                                  activeProjectId: nil, noteToEdit: note)
        #expect(rebuilt.noteToEdit == nil)
        #expect(rebuilt.bodyText.isEmpty && rebuilt.projectIds.isEmpty && rebuilt.userTagIds.isEmpty)
        #expect(!rebuilt.hasChanges)
        #expect(ResearchNoteEditorViewModel.readable(ResearchNote(documentId: "d1", volumeId: "v")) == nil,
                "a note in no context is read")
    }
}
