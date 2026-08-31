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
import SQLite3
@testable import FRUSExplorer

// MARK: - ResearchDataExporterTests

/// Tests for `ResearchDataExporter` (Session 154 Task 2 — Research Data Export).
@MainActor
struct ResearchDataExporterTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ResearchNote.self,
            Collection.self,
            CollectionEntry.self,
            UserTag.self,
            DocumentTagAssignment.self,
            DocumentHighlight.self,
            GeneratedSummary.self,
            SummarizationPrompt.self,
            // Wave R-5: the three research-trail tables the envelope now carries.
            ReadingHistoryEntry.self,
            SearchHistoryEntry.self,
            ExportHistoryEntry.self,
        ])
        // `cloudKitDatabase: .none` — the test host is entitled, and an in-memory container
        // without it spins up real sync and crashes.
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Seeds one record of every exported type, with cross-references
    /// (highlight → note, collection → entry) so the round trip can verify them.
    @discardableResult
    private func seedFixtures(in context: ModelContext) -> (note: ResearchNote, highlight: DocumentHighlight) {
        let project = Project(name: "Cold War Diplomacy")
        context.insert(project)

        let tag = UserTag(name: "Primary Source")
        context.insert(tag)

        let note = ResearchNote(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            bodyText: "Key turning point in the negotiations.",
            projectIds: [project.id],
            userTagIds: [tag.id]
        )
        context.insert(note)

        let highlight = DocumentHighlight(
            volumeId: "frus1969-76v01",
            documentId: "d1",
            startOffset: 10,
            endOffset: 42,
            colorTag: "yellow",
            noteId: note.id,
            selectedText: "a key turning point",
            renderingVersion: "abc123"
        )
        context.insert(highlight)

        let assignment = DocumentTagAssignment(volumeId: "frus1969-76v01", documentId: "d2", tagId: tag.id)
        context.insert(assignment)

        let collection = Collection(name: "Vietnam Negotiations", projectIds: [project.id])
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1", volumeId: "frus1969-76v01", sortOrder: 0)
        entry.collection = collection
        context.insert(entry)

        let userPrompt = SummarizationPrompt(name: "My Prompt", promptText: "Summarize {{DOCUMENT}}", isStandard: false)
        context.insert(userPrompt)

        let standardPrompt = SummarizationPrompt(name: "Standard Prompt", promptText: "Standard {{DOCUMENT}}", isStandard: true)
        context.insert(standardPrompt)

        let summary = GeneratedSummary(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            promptId: userPrompt.id,
            responseText: "This document discusses..."
        )
        context.insert(summary)

        // The research trail (Wave R-5). Inserted **out of chronological order** on purpose: the
        // exporter sorts oldest-first in the fetch descriptor, and a fixture already in order
        // would let a sort that does nothing pass.
        let visitLater = ReadingHistoryEntry(documentId: "d2", volumeId: "frus1969-76v01",
                                             displayTitle: "Memorandum of Conversation",
                                             projectId: project.id)
        visitLater.accessedAt = Self.t(200)
        context.insert(visitLater)

        let visitEarlier = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01",
                                               displayTitle: "Telegram 1234", projectId: nil)
        visitEarlier.accessedAt = Self.t(100)
        context.insert(visitEarlier)

        // A recorded zero — the absence assertion the method appendix exists to preserve.
        context.insert(SearchHistoryEntry(queryText: "mobilization base", resultCount: 0,
                                          projectId: project.id, executedAt: Self.t(150)))
        context.insert(SearchHistoryEntry(queryText: "Buy American", resultCount: 9,
                                          projectId: nil, executedAt: Self.t(50)))

        context.insert(ExportHistoryEntry(format: "zotero-api", documentCount: 3,
                                          collectionName: "Vietnam Negotiations",
                                          projectId: project.id, exportedAt: Self.t(250)))

        return (note, highlight)
    }

    /// A fixed instant `offset` seconds after a stable epoch, so trail ordering is deterministic.
    private static func t(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(offset)
    }

    // MARK: - makeEnvelope

    @Test("makeEnvelope excludes GeneratedSummary by default and excludes standard prompts")
    func makeEnvelopeDefaultExcludesSummariesAndStandardPrompts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)

        #expect(envelope.formatVersion == ResearchDataExporter.currentFormatVersion)
        #expect(envelope.notes.count == 1)
        #expect(envelope.tags.count == 1)
        #expect(envelope.tagAssignments.count == 1)
        #expect(envelope.highlights.count == 1)
        #expect(envelope.collections.count == 1)
        #expect(envelope.collections.first?.entries.count == 1)
        #expect(envelope.projects.count == 1)
        #expect(envelope.prompts.count == 1)
        #expect(envelope.prompts.first?.name == "My Prompt")
        #expect(envelope.summaries.isEmpty)
    }

    @Test("makeEnvelope includes GeneratedSummary when opted in")
    func makeEnvelopeIncludesSummariesWhenRequested() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: true)

        #expect(envelope.summaries.count == 1)
        #expect(envelope.summaries.first?.responseText == "This document discusses...")
    }

    @Test("makeEnvelope links highlights back to their note via linkedHighlightIds")
    func makeEnvelopeLinksHighlightsToNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixtures = seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)

        let exportedNote = try #require(envelope.notes.first)
        #expect(exportedNote.id == fixtures.note.id)
        #expect(exportedNote.linkedHighlightIds == [fixtures.highlight.id])
    }

    // MARK: - JSON round trip

    @Test("exportJSONData round-trips through JSONDecoder and preserves the envelope")
    func exportJSONDataRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: true)
        let data = try ResearchDataExporter.exportJSONData(envelope)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: data)

        #expect(decoded.formatVersion == envelope.formatVersion)
        #expect(decoded.notes.map(\.id) == envelope.notes.map(\.id))
        #expect(decoded.tags.map(\.id) == envelope.tags.map(\.id))
        #expect(decoded.tagAssignments.map(\.id) == envelope.tagAssignments.map(\.id))
        #expect(decoded.highlights.map(\.id) == envelope.highlights.map(\.id))
        #expect(decoded.collections.map(\.id) == envelope.collections.map(\.id))
        #expect(decoded.prompts.map(\.id) == envelope.prompts.map(\.id))
        #expect(decoded.projects.map(\.id) == envelope.projects.map(\.id))
        #expect(decoded.summaries.map(\.id) == envelope.summaries.map(\.id))

        // ISO 8601 without fractional seconds rounds Date fields to whole
        // seconds, so a single round trip can differ from `envelope` (which
        // carries `Date.now`'s sub-second precision). Verify the JSON format
        // itself is lossless: re-encoding `decoded` and decoding again should
        // be idempotent.
        let decodedAgain = try decoder.decode(ResearchDataEnvelope.self, from: try ResearchDataExporter.exportJSONData(decoded))
        #expect(decodedAgain == decoded)
    }

    // MARK: - #377 Phase 4: active-project header

    @Test("makeEnvelope stamps the active project's name/question header; nil/non-matching id → none; projects[] unchanged")
    func makeEnvelopeStampsActiveProject() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = seedFixtures(in: context)
        let project = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        project.researchQuestion = "How did détente evolve?"
        try context.save()

        // With the active project id → the header carries its name + question…
        let withProject = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: project.id)
        #expect(withProject.exportedForProjectName == "Cold War Diplomacy")
        #expect(withProject.exportedForProjectResearchQuestion == "How did détente evolve?")
        #expect(withProject.projects.count == 1)   // …and the full project backup array is unchanged.

        // No active project (Global Context) → no header project.
        let noProject = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: nil)
        #expect(noProject.exportedForProjectName == nil)
        #expect(noProject.exportedForProjectResearchQuestion == nil)
        #expect(noProject.projects.count == 1)

        // A stale/non-matching id → no header project (not a crash).
        let bad = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false, activeProjectId: UUID())
        #expect(bad.exportedForProjectName == nil)
    }

    @Test("A pre-Phase-4 JSON (no header-project keys) still decodes")
    func legacyJSONDecodes() throws {
        let json = Data(#"{"formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","notes":[],"tags":[],"tagAssignments":[],"highlights":[],"collections":[],"prompts":[],"projects":[],"summaries":[]}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: json)
        #expect(decoded.formatVersion == 1)
        #expect(decoded.exportedForProjectName == nil)
        #expect(decoded.exportedForProjectResearchQuestion == nil)
    }

    @Test("exportJSONData top-level keys match the documented envelope schema")
    func exportJSONDataKeysMatchSchema() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(modelContext: context, includeGeneratedSummaries: false)
        let data = try ResearchDataExporter.exportJSONData(envelope)

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expectedKeys: Set<String> = [
            "formatVersion", "exportedAt", "notes", "tags", "tagAssignments",
            "highlights", "collections", "prompts", "projects", "summaries",
            // Wave R-5.
            "readingHistory", "searchHistory", "exportHistory",
            // Archive Visits Phase 2 (format version 6).
            "archiveVisits",
        ]
        #expect(Set(json.keys) == expectedKeys)
    }

    // MARK: - Wave R-5: the research trail

    @Test("makeEnvelope carries all three trail tables, oldest first, unconditionally")
    func makeEnvelopeCarriesTheTrail() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        // `includeGeneratedSummaries: false` — the trail is NOT behind that opt-in, or any other.
        // Contract D5: the export is the method appendix, and an appendix behind an opt-out is
        // not an appendix.
        let envelope = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false)

        #expect(envelope.summaries.isEmpty)

        #expect(envelope.readingHistory.count == 2)
        #expect(envelope.readingHistory.map(\.documentId) == ["d1", "d2"])       // oldest first
        #expect(envelope.readingHistory.first?.displayTitle == "Telegram 1234")
        #expect(envelope.readingHistory.first?.projectId == nil)
        #expect(envelope.readingHistory.last?.projectId != nil)

        #expect(envelope.searchHistory.count == 2)
        #expect(envelope.searchHistory.map(\.queryText) == ["Buy American", "mobilization base"])
        // The zero survives as evidence rather than being dropped as "no result".
        #expect(envelope.searchHistory.last?.resultCount == 0)
        #expect(envelope.searchHistory.first?.resultCount == 9)

        #expect(envelope.exportHistory.count == 1)
        #expect(envelope.exportHistory.first?.format == "zotero-api")
        #expect(envelope.exportHistory.first?.documentCount == 3)
        #expect(envelope.exportHistory.first?.collectionName == "Vietnam Negotiations")
    }

    @Test("The trail round-trips through JSON with its query text and counts intact")
    func trailRoundTripsThroughJSON() throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedFixtures(in: context)

        let envelope = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            ResearchDataEnvelope.self, from: try ResearchDataExporter.exportJSONData(envelope))

        #expect(decoded.readingHistory.map(\.id) == envelope.readingHistory.map(\.id))
        #expect(decoded.searchHistory.map(\.queryText) == envelope.searchHistory.map(\.queryText))
        #expect(decoded.searchHistory.map(\.resultCount) == envelope.searchHistory.map(\.resultCount))
        #expect(decoded.exportHistory.map(\.format) == envelope.exportHistory.map(\.format))
    }

    @Test("A version-2 JSON (no trail keys) still decodes, with the trail empty")
    func version2JSONDecodesWithEmptyTrail() throws {
        // Swift's synthesized `Decodable` ignores a property's default value, so a non-optional
        // array would have made every previously-exported file undecodable. This is the guard on
        // `ResearchDataEnvelope.init(from:)`'s hand-written `decodeIfPresent … ?? []`.
        let json = Data(#"{"formatVersion":2,"exportedAt":"2024-01-01T00:00:00Z","exportedForProjectName":"Cold War","notes":[],"tags":[],"tagAssignments":[],"highlights":[],"collections":[],"prompts":[],"projects":[],"summaries":[]}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: json)

        #expect(decoded.formatVersion == 2)
        #expect(decoded.exportedForProjectName == "Cold War")
        #expect(decoded.readingHistory.isEmpty)
        #expect(decoded.searchHistory.isEmpty)
        #expect(decoded.exportHistory.isEmpty)
    }

    @Test("A truncated file still fails loudly — only the trail keys are optional")
    func missingRequiredKeyStillThrows() throws {
        // The tolerance added for the trail must not have quietly made the whole envelope
        // optional: a corrupt backup should not decode into a plausible-looking empty one.
        let json = Data(#"{"formatVersion":3,"exportedAt":"2024-01-01T00:00:00Z","tags":[],"tagAssignments":[],"highlights":[],"collections":[],"prompts":[],"projects":[],"summaries":[]}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: (any Error).self) {
            try decoder.decode(ResearchDataEnvelope.self, from: json)
        }
    }

    @Test("trailCounts reports each table separately, and zero on an empty store")
    func trailCountsReportsEachTable() throws {
        let empty = try makeContainer()
        let emptyCounts = ResearchDataExporter.trailCounts(modelContext: empty.mainContext)
        #expect(emptyCounts == (visits: 0, searches: 0, exports: 0))

        let container = try makeContainer()
        seedFixtures(in: container.mainContext)
        let counts = ResearchDataExporter.trailCounts(modelContext: container.mainContext)
        #expect(counts == (visits: 2, searches: 2, exports: 1))
    }

    // MARK: - Markdown export

    @Test("markdownExports renders YAML front matter with canonical URL and tags, without a citation when unindexed")
    func markdownExportsRenderFrontMatter() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fixtures = seedFixtures(in: context)

        let allTags = try context.fetch(FetchDescriptor<UserTag>())
        let appState = AppState()

        let exports = await ResearchDataExporter.markdownExports(notes: [fixtures.note], tags: allTags, appState: appState)

        let export = try #require(exports.first)
        #expect(export.id == fixtures.note.id)
        #expect(export.filename == "frus1969-76v01-d1-\(fixtures.note.id.uuidString.prefix(8)).md")
        #expect(export.content.contains("documentId: d1"))
        #expect(export.content.contains("volumeId: frus1969-76v01"))
        #expect(export.content.contains("url: https://history.state.gov/historicaldocuments/frus1969-76v01/d1"))
        // Tag names are quoted YAML scalars (Session 158): user-authored names
        // can contain ':'/'"'/']', which break unquoted flow-sequence entries.
        #expect(export.content.contains("tags: [\"Primary Source\"]"))
        #expect(export.content.contains("Key turning point in the negotiations."))
        #expect(!export.content.contains("citation:"))
    }
}

// MARK: - Index database export (W-19 row L-2)

/// The SQLite index export: a correct copy of a live WAL database, and the consent strip.
///
/// Every test here works on a real temp-file database built through the real pipeline, because the
/// three things that can go wrong — a torn copy, a strip that does not erase, and an index whose
/// rowids no longer match its content table — are all invisible to a mock.
///
/// Version history:
///   1.0 — W-19 L-2: initial implementation
@Suite("Index database export")
struct IndexDatabaseExporterTests {

    private let noteText = "Zebrafish marginalia — a phrase that occurs nowhere in the corpus."
    private let summaryText = "Kumquat synopsis, likewise unique."

    /// One indexed volume, with a note, a summary and a tag name attached — the three things the
    /// strip has to remove.
    private func makeIndexed() async throws -> (dir: URL, db: URL, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSDbExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("live.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        func write(_ name: String, prefix: String) throws {
            var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
            for index in 0..<8 {
                xml += """
                <div type="document" xml:id="d\(index)">
                  <head>\(index + 1). Item</head>
                  <p>\(prefix) number \(index) discusses containment and the marshall plan.</p>
                </div>

                """
            }
            xml += "</body></text></TEI>"
            try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("\(name).xml"))
        }
        try write("vol0", prefix: "Discarded")
        try write("vol1", prefix: "Document")

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        // Index two volumes and drop the first. THE GAP IS THE POINT: `VACUUM` renumbers rowids
        // only where they are not already contiguous, so a fixture indexed once in order cannot
        // exercise the hazard the rebuild exists for. A real store has had volumes removed.
        try await pipeline.indexVolume("vol0")
        try await pipeline.indexVolume("vol1")
        try await pipeline.removeVolume("vol0")

        let tagId = "DDDDDDDD-0000-0000-0000-00000000000D"
        try await pipeline.updateNoteText(volumeId: "vol1", documentId: "d3", bodyText: noteText)
        try await pipeline.updateSummaryText(volumeId: "vol1", documentId: "d4",
                                             responseText: summaryText)
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d5", userTagIds: tagId)
        try await pipeline.replaceUserTagNames([(id: tagId, name: "escalation-rhetoric")])
        return (dir, dbURL, pipeline)
    }

    /// The stamp every export writes, built by the production factory rather than by hand, so a
    /// field the factory stops populating fails here too.
    private func stamp(_ pipeline: IndexingPipeline?,
                       semanticDigest: String? = "0123456789abcdef") -> ResearchStateRecord {
        ResearchStateRecord.make(pipeline: pipeline, semanticDigest: semanticDigest)
    }

    /// Whether SQLite REFUSES to prepare the statement.
    ///
    /// This exists because `query` returns `[]` both for "no rows" and for "that column does not
    /// exist", so an absence test written on `query` would pass against a view that still exposed
    /// the column it was meant to hide. The point of the views is that the column is *gone*, and
    /// only a refused prepare shows that.
    private func rejects(_ url: URL, _ sql: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        let prepared = sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK
        sqlite3_finalize(stmt)
        return !prepared
    }

    /// Queries the exported copy the way the guide teaches — a plain read-only connection.
    private func query(_ url: URL, _ sql: String) -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var rows: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "")
        }
        return rows
    }

    @Test("Including my writing copies it verbatim, and the copy verifies")
    func exportWithWritingIsFaithful() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("with.sqlite")

        let report = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: true,
                                                      stamp: stamp(pipeline))
        #expect(report.strippedWriting == false)
        #expect(report.byteCount > 0)
        #expect(report.integrityProblems.isEmpty, "\(report.integrityProblems)")

        #expect(query(out, "SELECT note_text FROM document_cache WHERE document_id='d3'")
                    .first == noteText)
        #expect(query(out, "SELECT name FROM user_tags").first == "escalation-rhetoric")
    }

    @Test("Stripping removes notes, summaries and tag names from the rows AND the index")
    func stripRemovesWritingEverywhere() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("stripped.sqlite")

        let report = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: false,
                                                      stamp: stamp(pipeline))
        #expect(report.strippedWriting)
        #expect(report.integrityProblems.isEmpty, "\(report.integrityProblems)")

        #expect(query(out, "SELECT note_text FROM document_cache WHERE note_text IS NOT NULL").isEmpty)
        #expect(query(out, "SELECT summary_text FROM document_cache WHERE summary_text IS NOT NULL").isEmpty)
        #expect(query(out, "SELECT user_tag_ids FROM document_cache WHERE user_tag_ids IS NOT NULL").isEmpty)
        #expect(query(out, "SELECT name FROM user_tags").isEmpty,
                "tag NAMES are the most legible writing in the file; nulling the ids is not enough")

        // Removed from the search index too, not merely from the rows: the user_content rebuild is
        // what makes the strip real rather than cosmetic.
        let hits = query(out, "SELECT document_id FROM user_content WHERE user_content MATCH 'zebrafish'")
        #expect(hits.isEmpty, "the note text must not survive in the index")
    }

    /// An end-to-end check that the exported copy is usable: matches resolve to the documents whose
    /// text they matched, across a strip, a `VACUUM` and two index rebuilds.
    ///
    /// **What this does NOT do, stated because the obvious reading is wrong.** It does not prove the
    /// post-`VACUUM` rebuild is necessary. Measured on this SQLite build, `VACUUM` does not renumber
    /// `document_cache`'s rowids — verified directly, including over a table with a rowid gap left
    /// by a removed volume — so this test passes with the `frus_documents` rebuild removed. It was
    /// written believing otherwise and mutation-testing caught it. The fixture keeps the gap anyway,
    /// because it is the shape a real store has and the closest this suite can get to the hazard.
    @Test("An exported copy's full-text matches resolve to the right documents")
    func exportedMatchesResolveCorrectly() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("aligned.sqlite")

        _ = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: false,
                                             stamp: stamp(pipeline))

        // Each body says "Document number N", so the match's own text names the document it must
        // resolve to. A misaligned index returns a row whose header disagrees with its body.
        for index in 0..<8 {
            let sql = """
                SELECT dc.document_id FROM frus_documents
                JOIN document_cache dc ON dc.rowid = frus_documents.rowid
                WHERE frus_documents MATCH 'body_text : "document number \(index)"'
                """
            let hits = query(out, sql)
            #expect(hits == ["d\(index)"],
                    "match for document \(index) resolved to \(hits)")
        }
    }

    // MARK: - Provenance stamp and research views (W-19 L-8 residue)

    /// A fixture shaped like the places the views have to make a decision: a second edition whose
    /// first edition is present, a second edition whose first edition is NOT (the corpus ships one
    /// of those, `frus1977-80v09Ed2`), a promoted front-matter section, an editorial note, and a
    /// cross-reference.
    private func makeCorpusShaped() async throws -> (dir: URL, db: URL, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSDbViews-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("live.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        func write(_ name: String, apparatus: Bool) throws {
            var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
            for index in 0..<3 {
                xml += """
                <div type="document" xml:id="d\(index)">
                  <head>\(index + 1). Item</head>
                  <p>Telegram number \(index) from the embassy.
                     <ref target="d0">See document 1.</ref></p>
                </div>

                """
            }
            if apparatus {
                xml += """
                <div type="document" subtype="editorial-note" xml:id="dNote">
                  <head>Editorial Note</head>
                  <p>The editors record a gap in the file.</p>
                </div>
                <div type="preface" xml:id="preface">
                  <head>Preface</head>
                  <p>About this volume and how it was compiled.</p>
                </div>

                """
            }
            xml += "</body></text></TEI>"
            try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("\(name).xml"))
        }
        try write("frus1951-54Iran", apparatus: true)
        try write("frus1951-54IranEd2", apparatus: false)
        try write("frus1977-80v09Ed2", apparatus: false)

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        for volume in ["frus1951-54Iran", "frus1951-54IranEd2", "frus1977-80v09Ed2"] {
            try await pipeline.indexVolume(volume)
        }
        return (dir, dbURL, pipeline)
    }

    /// Runs one statement against a database file.
    ///
    /// Used only to put a fixture into a state its own XML cannot reach: `is_broken` is written
    /// from the bundled exclusion index, not derived from the volume being parsed, so a fixture
    /// volume has no way to produce a broken reference.
    @discardableResult
    private func exec(_ url: URL, _ sql: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    @Test("The copy carries a provenance stamp, and it records the strip decision")
    func provenanceStampRecordsWhatTheCopyIs() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }

        let stripped = dir.appendingPathComponent("stamped-stripped.sqlite")
        let kept = dir.appendingPathComponent("stamped-kept.sqlite")
        _ = try IndexDatabaseExporter.export(from: live, to: stripped, includeMyWriting: false,
                                             stamp: stamp(pipeline))
        _ = try IndexDatabaseExporter.export(from: live, to: kept, includeMyWriting: true,
                                             stamp: stamp(pipeline))

        func value(_ url: URL, _ key: String) -> String? {
            query(url, "SELECT value FROM research_provenance WHERE key='\(key)'").first
        }

        // The row the table exists for: nothing else in the file distinguishes these two copies,
        // because a stripped column and an un-annotated document both read NULL.
        #expect(value(stripped, "my_writing_included") == "0")
        #expect(value(kept, "my_writing_included") == "1")

        // The versions that decide whether a number from this copy is still comparable.
        #expect(value(stripped, "current_index_version")
                    == String(IndexingPipeline.currentDateIndexVersion))
        #expect(value(stripped, "current_fts_schema_version")
                    == String(IndexingPipeline.currentFTSSchemaVersion))
        #expect(value(stripped, "semantic_provenance_digest") == "0123456789abcdef")
        #expect(value(stripped, "exported_at")?.isEmpty == false)
        #expect(value(stripped, "documentation")?.contains("Agentic-Analysis-Guide") == true)

        // The two ARRAYS the clipboard record carries are deliberately absent: both are answerable
        // from the rows beside them, and a stored second copy is a second place to be wrong.
        #expect(query(stripped, "SELECT key FROM research_provenance WHERE key LIKE '%volume%'")
                    .isEmpty)
    }

    @Test("Unloaded vectors are stamped as NULL, not as a missing key")
    func provenanceStampDistinguishesUnloadedVectors() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("nodigest.sqlite")

        _ = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: false,
                                             stamp: stamp(pipeline, semanticDigest: nil))

        // The KEY is present — an absent key would be ambiguous between an export taken before the
        // stamp existed and one taken with the vectors unloaded.
        #expect(query(out, "SELECT key FROM research_provenance WHERE key='semantic_provenance_digest'")
                    == ["semantic_provenance_digest"])
        #expect(query(out, """
            SELECT 'nonnull' FROM research_provenance
            WHERE key='semantic_provenance_digest' AND value IS NOT NULL
            """).isEmpty)
    }

    @Test("research_documents drops the apparatus and the Ed2 twin that has a first edition")
    func researchViewsApplyTheExclusions() async throws {
        let (dir, live, pipeline) = try await makeCorpusShaped()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("views.sqlite")
        _ = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: true,
                                             stamp: stamp(pipeline))

        // Fixture preconditions, asserted so a failure below localises to the view rather than to
        // the parser having stopped flagging apparatus.
        #expect(query(out, "SELECT COUNT(*) FROM document_cache WHERE is_editorial_note=1").first == "1")
        #expect(query(out, "SELECT COUNT(*) FROM document_cache WHERE is_front_matter=1").first == "1")

        // The fold names exactly the twin whose first edition is here. `frus1977-80v09Ed2` has no
        // first edition — in this fixture as in the shipped corpus — and must survive, or the view
        // would be deleting documents that are not duplicates.
        #expect(query(out, "SELECT volume_id FROM research_suppressed_volumes")
                    == ["frus1951-54IranEd2"])

        let volumes = query(out, "SELECT DISTINCT volume_id FROM research_documents ORDER BY 1")
        #expect(volumes == ["frus1951-54Iran", "frus1977-80v09Ed2"])

        // 3 documents in each surviving volume; the editorial note and the preface are gone.
        #expect(query(out, "SELECT COUNT(*) FROM research_documents").first == "6")
        #expect(query(out, "SELECT COUNT(*) FROM document_cache").first == "11")
        #expect(query(out, "SELECT document_id FROM research_documents WHERE document_id='dNote'")
                    .isEmpty)
    }

    @Test("research_documents cannot reach the reader's writing, or a rowid")
    func researchDocumentsRemovesTheColumnsRatherThanForbiddingThem() async throws {
        let (dir, live, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = dir.appendingPathComponent("shape.sqlite")

        // includeMyWriting: TRUE — the point is that the view hides the writing even in the copy
        // that still contains it. In a stripped copy every one of these would be NULL anyway, and
        // the test would pass against a view that offered the column.
        _ = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: true,
                                             stamp: stamp(pipeline))
        #expect(query(out, "SELECT note_text FROM document_cache WHERE document_id='d3'").first
                    == noteText,
                "precondition: the copy still holds the writing the view has to hide")

        for column in ["summary_text", "note_text", "subject_tag_ids", "rowid"] {
            #expect(rejects(out, "SELECT \(column) FROM research_documents"),
                    "research_documents must not offer \(column)")
        }
        // The surfaces §4.6 does offer are still there.
        #expect(!rejects(out, "SELECT user_tag_ids, body_text, despatch_serial FROM research_documents"))
    }

    @Test("research_cross_references drops broken edges")
    func researchCrossReferencesDropsBrokenEdges() async throws {
        let (dir, live, pipeline) = try await makeCorpusShaped()
        defer { try? FileManager.default.removeItem(at: dir) }

        let before = query(live, "SELECT COUNT(*) FROM cross_references").first
        #expect(before != "0", "precondition: the fixture produced cross-references")
        #expect(exec(live, "UPDATE cross_references SET is_broken = 1 WHERE source_document_id = 'd1'"))

        let out = dir.appendingPathComponent("refs.sqlite")
        _ = try IndexDatabaseExporter.export(from: live, to: out, includeMyWriting: true,
                                             stamp: stamp(pipeline))

        #expect(query(out, "SELECT COUNT(*) FROM cross_references WHERE is_broken=1").first != "0",
                "precondition: broken edges are in the copy")
        #expect(query(out, "SELECT source_document_id FROM research_cross_references WHERE source_document_id='d1'")
                    .isEmpty)
        #expect(rejects(out, "SELECT is_broken FROM research_cross_references"))
    }
}

// MARK: - Research-state record (W-19 row L-7)

/// The §13 reproducibility record: what makes a machine-assisted run citable.
///
/// Version history:
///   1.0 — W-19 L-7: initial implementation
@Suite("Research-state record")
struct ResearchStateRecordTests {

    /// One indexed volume through the real pipeline, so the two SQLite reads answer for real.
    private func makeIndexed() async throws -> (dir: URL, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSState-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        // Two volumes, written in an order that is NOT the sorted order, so a record that forgot
        // to sort would still look plausible.
        for name in ["vol9", "vol2"] {
            let xml = """
            <?xml version="1.0"?>
            <TEI><text><body>
            <div type="document" xml:id="d0"><head>1. Item</head><p>containment</p></div>
            </body></text></TEI>
            """
            try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("\(name).xml"))
        }
        let dbURL = dir.appendingPathComponent("state.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol9")
        try await pipeline.indexVolume("vol2")
        return (dir, pipeline)
    }

    @Test("The record carries §13's facts, and the volume list is sorted")
    func recordIsCompleteAndSorted() async throws {
        let (dir, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }

        let record = ResearchStateRecord.make(
            pipeline: pipeline, semanticDigest: "deadbeef",
            now: Date(timeIntervalSince1970: 1_700_000_000))

        // §13 says to save the LIST, not the count — and sorted, because the in-memory form is a
        // Set whose order varies per process. Unsorted, two records of an unchanged library would
        // diff against each other.
        #expect(record.indexedVolumeIds == ["vol2", "vol9"])
        #expect(record.currentIndexVersion == IndexingPipeline.currentDateIndexVersion)
        #expect(record.currentFTSSchemaVersion == IndexingPipeline.currentFTSSchemaVersion)
        #expect(record.semanticProvenanceDigest == "deadbeef")
        #expect(record.recordedAt.hasPrefix("2023-11-14"), "the stamp is §13's first row")
        #expect(!record.appBuild.isEmpty)
    }

    @Test("The JSON is stable, so two records of one state are diffable")
    func jsonIsStableAndSorted() async throws {
        let (dir, pipeline) = try await makeIndexed()
        defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let a = ResearchStateRecord.make(pipeline: pipeline, semanticDigest: nil, now: now).jsonText()
        let b = ResearchStateRecord.make(pipeline: pipeline, semanticDigest: nil, now: now).jsonText()
        #expect(a == b, "a record that re-orders itself between takes cannot be cited")

        // Keys sorted, and the JSON round-trips — a wire format a tool has to parse.
        let decoded = try JSONDecoder().decode(ResearchStateRecord.self, from: Data(a.utf8))
        #expect(decoded.indexedVolumeIds == ["vol2", "vol9"])
        #expect(a.range(of: "\"appBuild\"")!.lowerBound < a.range(of: "\"appVersion\"")!.lowerBound,
                "keys must be sorted so two records diff cleanly")
    }

    @Test("A record with no pipeline still records what it can")
    func degradesWithoutAPipeline() {
        // The two SQLite reads degrade to empty rather than throwing: a record missing one field
        // is worth more than no record, and an empty array is visibly not an answer.
        let record = ResearchStateRecord.make(pipeline: nil, semanticDigest: nil)
        #expect(record.indexedVolumeIds.isEmpty)
        #expect(record.subjectVocabularyDigests.isEmpty)
        #expect(record.currentIndexVersion == IndexingPipeline.currentDateIndexVersion)
        #expect(!record.recordedAt.isEmpty)
    }
}
