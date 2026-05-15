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

// MARK: - Fixture Helpers

private func makeDocumentFixture(documentId: String = "d1", bodyText: String = "The document body.") throws -> URL {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test Volume</title></titleStmt></fileDesc></teiHeader>
      <text><body>
        <div type="document" xml:id="\(documentId)">
          <head>1. Memorandum of Conversation</head>
          <dateline>Washington, January 20, 1969.</dateline>
          <p>\(bodyText)</p>
        </div>
      </body></text>
    </TEI>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-docview-test-\(UUID().uuidString).xml")
    try xml.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func makeEntry(documentId: String = "d1", volumeId: String = "frus1969-76v01") -> DocumentBrowserEntry {
    DocumentBrowserEntry(
        documentId: documentId,
        volumeId: volumeId,
        documentNumber: "1",
        header: "Memorandum of Conversation",
        dateline: "Washington, January 20, 1969.",
        sourceNote: nil
    )
}

// MARK: - DocumentViewTests

@MainActor
struct DocumentViewTests {

    // MARK: - Render Model

    @Test("DocumentViewModel renders model after loading a fixture document")
    func renderModelPopulatedAfterLoad() async throws {
        let url = try makeDocumentFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = SubjectTagStore(entries: [], appearances: [])
        let vm = DocumentViewModel(
            entry: makeEntry(),
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        await vm.load(volumeURL: url)

        #expect(vm.renderModel != nil)
        #expect(vm.loadError == nil)
        #expect(!vm.isLoading)
    }

    // MARK: - Reading History

    @Test("recordReadingHistory inserts a ReadingHistoryEntry with the correct projectId")
    func recordReadingHistoryInsertsEntry() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let projectId = UUID()

        let store = SubjectTagStore(entries: [], appearances: [])
        let vm = DocumentViewModel(
            entry: makeEntry(documentId: "d42", volumeId: "frus1969-76v01"),
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        vm.recordReadingHistory(projectId: projectId, in: ctx)

        let all = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(all.count == 1)
        let record = try #require(all.first)
        #expect(record.documentId == "d42")
        #expect(record.volumeId == "frus1969-76v01")
        #expect(record.projectId == projectId)
    }

    // MARK: - Subject Tags

    @Test("DocumentViewModel loads subject tags from the store after parsing")
    func subjectTagsLoadedAfterParse() async throws {
        let url = try makeDocumentFixture(documentId: "d1")
        defer { try? FileManager.default.removeItem(at: url) }

        let entries = [
            SubjectTagEntry(subjectId: "kissinger-henry-a", displayName: "Kissinger, Henry A.", category: "people"),
        ]
        let appearances = [
            SubjectAppearance(subjectId: "kissinger-henry-a", documentId: "d1",
                              volumeId: "frus1969-76v01", confidence: .curated),
        ]
        let store = SubjectTagStore(entries: entries, appearances: appearances)
        let vm = DocumentViewModel(
            entry: makeEntry(documentId: "d1", volumeId: "frus1969-76v01"),
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        await vm.load(volumeURL: url)

        #expect(vm.subjectTags.count == 1)
        #expect(vm.subjectTags.first?.displayName == "Kissinger, Henry A.")
        #expect(vm.subjectTags.first?.category == .people)
    }

    // MARK: - Cross-Project Note Indicator

    @Test("refreshCrossProjectNoteCount counts notes not belonging to the active project")
    func crossProjectNoteCountReflectsOtherProjectNotes() throws {
        let container = try ModelContainer.makeTestContainer()
        let ctx = container.mainContext
        let activeProjectId = UUID()
        let otherProjectId = UUID()

        // Note belonging to active project — should not count
        let ownNote = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01")
        ownNote.projectIds = [activeProjectId]
        ctx.insert(ownNote)

        // Two notes belonging to a different project — should count
        for _ in 0..<2 {
            let foreignNote = ResearchNote(documentId: "d1", volumeId: "frus1969-76v01")
            foreignNote.projectIds = [otherProjectId]
            ctx.insert(foreignNote)
        }

        let store = SubjectTagStore(entries: [], appearances: [])
        let vm = DocumentViewModel(
            entry: makeEntry(documentId: "d1", volumeId: "frus1969-76v01"),
            parser: FRUSDocumentParser(),
            subjectTagStore: store
        )
        vm.refreshCrossProjectNoteCount(activeProjectId: activeProjectId, context: ctx)

        #expect(vm.crossProjectNoteCount == 2)
    }
}
