// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
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

        let vm = DocumentViewModel(
            entry: makeEntry(),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
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

        let vm = DocumentViewModel(
            entry: makeEntry(documentId: "d42", volumeId: "frus1969-76v01"),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        )
        vm.recordReadingHistory(projectId: projectId, in: ctx)

        let all = try ctx.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(all.count == 1)
        let record = try #require(all.first)
        #expect(record.documentId == "d42")
        #expect(record.volumeId == "frus1969-76v01")
        #expect(record.projectId == projectId)
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

        let vm = DocumentViewModel(
            entry: makeEntry(documentId: "d1", volumeId: "frus1969-76v01"),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        )
        vm.refreshCrossProjectNoteCount(activeProjectId: activeProjectId, context: ctx)

        #expect(vm.crossProjectNoteCount == 2)
    }
}

// MARK: - PersonMentionBadgeTests

@MainActor
struct PersonMentionBadgeTests {

    // MARK: - MentionCountLoadedFromStore

    @Test("loadPersonMentionCount populates selectedPersonMentionCount from the store")
    func mentionCountLoadedFromStore() async throws {
        let (dir, dbURL, personStore) = try makePersonMentionStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Insert two documents that mention the same person ref
        try insertPersonMention(dbURL: dbURL, volumeId: "vol1", documentId: "d1", personRef: "kissinger-henry-a")
        try insertPersonMention(dbURL: dbURL, volumeId: "vol1", documentId: "d2", personRef: "kissinger-henry-a")
        try insertPersonMention(dbURL: dbURL, volumeId: "vol1", documentId: "d3", personRef: "nixon-richard-m")

        let entry = DocumentBrowserEntry(
            documentId: "d1", volumeId: "vol1",
            documentNumber: "1", header: "Test", dateline: nil, sourceNote: nil
        )
        let vm = DocumentViewModel(
            entry: entry,
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            personMentionStore: personStore
        )

        let person = PersonEntry(ref: "kissinger-henry-a", name: "Kissinger, Henry A.", description: nil)
        await vm.loadPersonMentionCount(for: person)

        #expect(vm.selectedPersonMentionCount == 2)
    }

    // MARK: - MentionCountZeroWithoutStore

    @Test("loadPersonMentionCount sets count to 0 when personMentionStore is nil")
    func mentionCountZeroWithoutStore() async throws {
        let entry = DocumentBrowserEntry(
            documentId: "d1", volumeId: "vol1",
            documentNumber: "1", header: "Test", dateline: nil, sourceNote: nil
        )
        let vm = DocumentViewModel(
            entry: entry,
            volumeEntry: nil,
            parser: FRUSDocumentParser(),
            personMentionStore: nil
        )

        let person = PersonEntry(ref: "kissinger-henry-a", name: "Kissinger, Henry A.", description: nil)
        await vm.loadPersonMentionCount(for: person)

        #expect(vm.selectedPersonMentionCount == 0)
    }
}

// MARK: - PersonMentionBadge Fixture Helpers

private func makePersonMentionStore() throws -> (dir: URL, dbURL: URL, store: PersonMentionStore) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSPersonBadge-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dbURL = dir.appendingPathComponent("test.sqlite")

    let fts5 = try FTS5Store(databaseURL: dbURL)
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
    _ = try IndexingPipeline(
        fts5Store: fts5,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        concurrencyLimit: 1
    )
    let store = try PersonMentionStore(databaseURL: dbURL)
    return (dir, dbURL, store)
}

private func insertPersonMention(
    dbURL: URL,
    volumeId: String,
    documentId: String,
    personRef: String
) throws {
    var db: OpaquePointer?
    let rc = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
    guard rc == SQLITE_OK, let db else {
        throw PersonMentionError.databaseOpenFailed(message: "insertPersonMention: cannot open")
    }
    defer { sqlite3_close_v2(db) }
    let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    var stmt: OpaquePointer?
    sqlite3_prepare_v2(db,
        "INSERT OR IGNORE INTO person_mentions (volume_id, document_id, person_ref) VALUES (?, ?, ?)",
        -1, &stmt, nil)
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, volumeId,   -1, TRANSIENT)
    sqlite3_bind_text(stmt, 2, documentId, -1, TRANSIENT)
    sqlite3_bind_text(stmt, 3, personRef,  -1, TRANSIENT)
    sqlite3_step(stmt)
}

// MARK: - SummarizationErrorSurfacingTests

/// A provider that always fails — used to verify that generation failures reach
/// `DocumentViewModel.summarizationError` instead of being silently logged.
private actor FailingSummarizationProvider: SummarizationProvider {
    var isAvailable: Bool = true
    var contextWindowTokenLimit: Int = 3_072

    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult {
        throw SummarizationError.providerUnavailable
    }
}

@Suite("DocumentViewModel — summarization error surfacing")
@MainActor
struct SummarizationErrorSurfacingTests {

    @Test("A failed generation sets summarizationError; a new attempt clears it first")
    func failureSetsError() async throws {
        let schema = Schema([
            ResearchNote.self, UserTag.self, Collection.self, GeneratedSummary.self,
            SummarizationPrompt.self, Project.self, ReadingHistoryEntry.self,
            SearchHistoryEntry.self, DocumentHighlight.self, DocumentTagAssignment.self,
            SavedSearch.self, ResearchSession.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let vm = DocumentViewModel(
            entry: DocumentBrowserEntry(
                documentId: "d1", volumeId: "frus1969-76v01", header: "Memo"),
            volumeEntry: nil,
            parser: FRUSDocumentParser()
        )
        vm.documentPlainText = "Some document text to summarize."

        let prompt = SummarizationPrompt(
            name: "Test", promptText: "Summarize: {document_text}")
        context.insert(prompt)

        let service = SummarizationService(modelContainer: container)
        await vm.generateSummary(
            prompt: prompt,
            provider: FailingSummarizationProvider(),
            service: service,
            activeProjectId: nil,
            context: context
        )

        #expect(vm.summarizationError != nil,
                "generation failure must surface to the UI, not just the console")
        #expect(vm.isSummarizing == false)
    }
}
