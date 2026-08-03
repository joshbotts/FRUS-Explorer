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

// MARK: - EnvironmentSelfReferenceTests

/// A view may not READ an environment key whose value it also INSTALLS, when that value is a
/// closure-wrapping action.
///
/// ## The hang this prevents
/// `DocumentView` installs an `OpenURLAction` to route `frusexplorer://` links
/// (`.environment(\.openURL, OpenURLAction { … })`) and *also* declared
/// `@Environment(\.openURL)`, which its own action's `.external` branch then called.
/// `OpenURLAction` wraps a closure and — confirmed against the SDK interface — conforms only to
/// `Sendable`, never `Equatable`. SwiftUI therefore cannot prove a freshly-built one equal to the
/// last, so **every body evaluation published a "new" `\.openURL`, invalidating the view that read
/// it, which rebuilt the action.** Self-sustaining.
///
/// Measured on an iPad with a body counter armed: **750+ `DocumentView.body` evaluations for one
/// document open, accelerating 3/s → 31/s**, `_printChanges` naming `_openURL` nearly every time.
/// Downstream that was 90s of CPU in 101s, SwiftUI's "Update NavigationRequestObserver tried to
/// update multiple times per frame", and a `0x8BADF00D` scene-update watchdog kill — the app
/// showing a stale spinner and accepting no touches while the document had in fact loaded.
///
/// ## Why a source audit
/// There is no runtime coverage of the reader: `UIObstructionTests` Scenario 7 was written for
/// this surface and withdrawn because every XCUI query over the document reader times out after
/// ~180s (the WKWebView's accessibility tree defeats the query engine). A source rule is what is
/// available, and the declaration it forbids reads as entirely ordinary — which is exactly why it
/// survived review.
///
/// Version history:
///   1.0 — build 38: the iPad document-reader render loop
@Suite("Environment self-reference")
struct EnvironmentSelfReferenceTests {

    private static func documentViewSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appending(path: "FRUSExplorer/DocumentView/DocumentView.swift"),
            encoding: .utf8)
        #expect(text.count > 10_000, "DocumentView moved?")
        return text
    }

    /// The `DocumentView` struct's own source — from its declaration to the next top-level type.
    ///
    /// Scoped to the struct on purpose: `DocumentShareMenu`, further down the same file, reads
    /// `\.openURL` legitimately. It is a CHILD of the installed action, which is the whole point of
    /// installing one. Only the installing view must not also read it.
    private static func documentViewStruct(in text: String) throws -> Substring {
        let start = try #require(text.range(of: "\nstruct DocumentView: View {")).lowerBound
        let after = text.index(start, offsetBy: 30)
        let end = text.range(of: "\nstruct ", range: after..<text.endIndex)?.lowerBound
            ?? text.range(of: "\nprivate struct ", range: after..<text.endIndex)?.lowerBound
            ?? text.endIndex
        return text[start..<end]
    }

    @Test("DocumentView does not read the openURL action it installs")
    func documentViewDoesNotReadItsOwnOpenURL() throws {
        let text = try Self.documentViewSource()
        let view = try Self.documentViewStruct(in: text)

        // Anti-vacuity: if the install ever moves, this test is checking nothing and must say so
        // rather than passing.
        //
        // NON-COMMENT LINES ONLY, and that is not fussiness — the first version of this check was
        // a plain `contains`, and it passed with the install deleted, because the comment beside
        // the fix QUOTES `.environment(\.openURL, OpenURLAction { … })` while explaining it. A
        // guard satisfied by prose about the thing it guards is worse than no guard.
        let installs = view.split(separator: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///")
                && trimmed.contains(".environment(\\.openURL, OpenURLAction")
        }
        #expect(installs,
                """
                DocumentView no longer installs an OpenURLAction. If frusexplorer:// routing moved, \
                move this guard with it — as written it now proves nothing.
                """)

        let reads = view.split(separator: "\n").first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("@Environment(\\.openURL)") && !trimmed.hasPrefix("//")
        }
        #expect(reads == nil,
                """
                DocumentView declares `@Environment(\\.openURL)` while also installing an \
                `OpenURLAction`. OpenURLAction is not Equatable, so each body evaluation publishes \
                a value SwiftUI must treat as new — invalidating this view, which rebuilds the \
                action. That loop hung the iPad reader until the watchdog killed it. External links \
                go to `UIApplication.shared.open`. Offending line: \(reads.map(String.init) ?? "")
                """)
    }

    /// The replacement has to still open external links, or the guard above is satisfied by a
    /// regression that simply drops the behaviour.
    @Test("External cross-reference links still reach the system opener")
    func externalLinksStillOpen() throws {
        let text = try Self.documentViewSource()
        let handler = try #require(text.range(of: "func handleCrossRefTap")).lowerBound
        // Slice to the NEXT declaration, not a fixed prefix. A fixed 1,600-character window was
        // the first thing written here and it failed immediately: the comment explaining why
        // `UIApplication.shared.open` replaced `openURL` is itself long enough to push the call
        // out of the window. A test whose reach depends on how much prose sits above the line it
        // checks is a test that will start lying the next time someone documents something.
        let after = text.index(handler, offsetBy: 40)
        let end = text.range(of: "\n    private func ", range: after..<text.endIndex)?.lowerBound
            ?? text.endIndex
        let body = text[handler..<end]
        #expect(body.contains("case .external"), "the external branch is gone")
        #expect(body.contains("UIApplication.shared.open"),
                "the .external branch no longer opens the URL — links now go nowhere")
    }
}
