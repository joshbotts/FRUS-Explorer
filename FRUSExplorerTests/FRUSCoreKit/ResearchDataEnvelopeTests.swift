// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
// SQLite3 is the system's on Apple platforms; on Linux the web edition supplies CSQLite.
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

// MARK: - ResearchDataEnvelopeTests

/// The research data export's file as FRUSCoreKit holds it: every earlier version's file still
/// decodes, the encoder writes what it always wrote, and a truncated file still fails.
///
/// `ResearchDataExporterTests` (the app's) builds envelopes from a SwiftData store; these need no
/// store, so they run under `swift test` on every platform the kit builds on.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the envelope moved into the kit
@Suite("Research data envelope")
struct ResearchDataEnvelopeTests {

    private func decode(_ json: String) throws -> ResearchDataEnvelope {
        try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: Data(json.utf8))
    }

    /// Each version's file, as its version wrote it, decodes with today's decoder, with every
    /// record it holds and the fields that version added.
    @Test("Every earlier version's file still decodes", arguments: 1...6)
    func earlierVersionDecodes(version: Int) throws {
        let json = try #require(ResearchDataFixtures.earlierVersions.first { $0.version == version }?.json)
        let envelope = try decode(json)
        let id = ResearchDataFixtures.id
        #expect(envelope.formatVersion == version)
        #expect(envelope.notes.map(\.id) == [id(3)])
        #expect(envelope.notes.first?.linkedHighlightIds == [id(4)])
        #expect(envelope.tags.map(\.name) == ["Primary Source"])
        #expect(envelope.tagAssignments.map(\.tagId) == [id(2)])
        #expect(envelope.highlights.first?.noteId == id(3))
        #expect(envelope.collections.first?.entries.last?.researchNoteId == id(3))
        #expect(envelope.prompts.first?.responseFormat
                    == .structured(schema: .init(fields: [.init(name: "Background",
                                                                 description: "Who they were")])))
        #expect(envelope.projects.first?.defaultCountryTagIds == ["country-ussr"])
        #expect(envelope.summaries.first?.responseFormat == .general)

        // The header (version 2), the trail (3), its capture provenance (4), authorship (5) and
        // archive visits (6): present from their version on, and absent, not guessed, before it.
        #expect((envelope.exportedForProjectName != nil) == (version >= 2))
        #expect(envelope.readingHistory.count == (version >= 3 ? 1 : 0))
        #expect(envelope.searchHistory.count == (version >= 3 ? 1 : 0))
        #expect(envelope.exportHistory.count == (version >= 3 ? 1 : 0))
        #expect(envelope.searchHistory.first?.resultCount == (version >= 3 ? 0 : nil),
                "a recorded zero is evidence, and must survive as a zero")
        #expect((envelope.searchHistory.first?.fetchLimit != nil) == (version >= 4))
        #expect(envelope.summaries.first?.authorship == (version >= 5 ? .aiEdited : nil))
        #expect(envelope.archiveVisits.count == (version >= 6 ? 1 : 0))
        if version >= 6 {
            let plan = try #require(envelope.archiveVisits.first)
            #expect(plan.tiers == [ArchiveVisitTier(id: id(17), label: "First morning", order: 0)])
            #expect(plan.deliverables == ArchiveVisitDeliverables())
            #expect(plan.targets.first?.tierId == id(17))
            // Version 6 writes a heading or a prose block as an entry with no document.
            #expect(envelope.collections.first?.entries.first?.documentId == "")
        }
    }

    @Test("A file that lacks a required key fails, rather than decoding as an empty backup")
    func truncatedFileFails() throws {
        var object = try #require(try JSONSerialization.jsonObject(
            with: Data(ResearchDataFixtures.version6.utf8)) as? [String: Any])
        object.removeValue(forKey: "notes")
        let truncated = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) {
            try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: truncated)
        }
    }

    /// The encoder's settings, as the app's `ResearchDataExporter.exportJSONData(_:)` wrote with
    /// them before the move: ISO-8601 dates, sorted keys, pretty-printed.
    @Test("The encoder writes ISO-8601 dates, sorted keys and indented lines")
    func encoderSettings() throws {
        let envelope = try decode(ResearchDataFixtures.version6)
        let text = try #require(String(data: try envelope.jsonData(), encoding: .utf8))
        #expect(text.contains(#""exportedAt" : "2026-08-26T12:00:00Z""#))
        #expect(text.contains("\n  \"formatVersion\" : 6,\n"))
        let topLevel = text.split(separator: "\n")
            .filter { $0.hasPrefix("  \"") }
            .map { String($0.dropFirst(3).prefix { $0 != "\"" }) }
        #expect(topLevel == topLevel.sorted(), "the keys are not sorted")
        #expect(topLevel.count == 16, "\(topLevel)")
    }

    @Test("An envelope encodes and decodes back to itself")
    func roundTrip() throws {
        let envelope = try decode(ResearchDataFixtures.version6)
        let again = try ResearchDataEnvelope.makeDecoder()
            .decode(ResearchDataEnvelope.self, from: try envelope.jsonData())
        #expect(again == envelope)
    }
}

// MARK: - ResearchNoteMarkdownExportTests

/// One note's Markdown file, in the app's format to the byte, as the app's Export Notes as
/// Markdown writes it and as a host outside the app must.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the file moved into the kit
@Suite("Research note Markdown file")
struct ResearchNoteMarkdownExportTests {

    private let noteId = UUID(uuidString: "ABCDEF01-2345-4678-9ABC-DEF012345678")!
    private let primary = UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
    private let quoted = UUID(uuidString: "10000000-0000-4000-8000-000000000012")!

    @Test("The front matter names the document, its link, citation, tags and dates; the body follows")
    func everyField() {
        let file = ResearchNoteMarkdownExport.render(
            noteId: noteId, documentId: "d1", volumeId: "frus1969-76v01",
            bodyText: "Key turning point.",
            userTagIds: [quoted, UUID(), primary],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastModified: Date(timeIntervalSince1970: 1_700_003_600),
            citation: #"Foreign Relations, 1969–1976, Volume I, "Foundations", Document 1"#,
            tagNamesById: [primary: "Primary Source", quoted: #"a "quoted" \ tag: [x]"#])
        #expect(file.id == noteId)
        #expect(file.filename == "frus1969-76v01-d1-ABCDEF01.md")
        // A tag the dictionary does not name (the middle id) is left out, not written blank.
        #expect(file.content == #"""
            ---
            documentId: d1
            volumeId: frus1969-76v01
            url: https://history.state.gov/historicaldocuments/frus1969-76v01/d1
            citation: "Foreign Relations, 1969–1976, Volume I, \"Foundations\", Document 1"
            tags: ["a \"quoted\" \\ tag: [x]", "Primary Source"]
            created: 2023-11-14T22:13:20Z
            modified: 2023-11-14T23:13:20Z
            ---

            Key turning point.

            """#)
    }

    @Test("Without a citation, tags or dates, the front matter leaves them out")
    func fewestFields() {
        let file = ResearchNoteMarkdownExport.render(
            noteId: noteId, documentId: "d2", volumeId: "frus1861", bodyText: "",
            userTagIds: [], createdAt: nil, lastModified: nil, citation: nil, tagNamesById: [:])
        #expect(file.content == """
            ---
            documentId: d2
            volumeId: frus1861
            url: https://history.state.gov/historicaldocuments/frus1861/d2
            ---



            """)
    }
}

// MARK: - ResearchDatabaseStripTests

/// The strip Export Research Database… runs on its copy, as FRUSCoreKit holds it: its statements
/// in their order, and what they leave of a copy of a real index.
///
/// The app's `IndexDatabaseExporterTests` runs the strip through the export; this runs the steps
/// alone, on a copy made with `sqlite3_backup` as the export makes one, so a host that strips with
/// them on its own connection is held to the same result.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the steps moved into the kit
@Suite("Research database strip")
struct ResearchDatabaseStripTests {

    private let noteText = "Zebrafish marginalia — a phrase that occurs nowhere in the corpus."
    private let summaryText = "Kumquat synopsis, likewise unique."

    @Test("The steps are the export's five statements, in their order")
    func stepsInOrder() {
        #expect(ResearchDatabaseStrip.steps.map(\.action) == [
            "removing your notes and summaries",
            "removing your tag names",
            "reclaiming freed pages",
            "rebuilding the document index",
            "rebuilding your-content index",
        ])
        #expect(ResearchDatabaseStrip.steps.first?.sql
                    == "UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL")
        #expect(Array(ResearchDatabaseStrip.steps.map(\.sql)[2...]) == [
            "VACUUM",
            "INSERT INTO frus_documents(frus_documents) VALUES('rebuild')",
            "INSERT INTO user_content(user_content) VALUES('rebuild')",
        ])
    }

    @Test("Run on a copy, the steps remove notes, summaries and tag names from the rows and the index")
    func stepsStripACopy() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSStrip-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Two volumes, the first removed, so the copy has the rowid gap a real store has.
        for (name, prefix) in [("vol0", "Discarded"), ("vol1", "Document")] {
            var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
            for index in 0..<6 {
                xml += """
                <div type="document" xml:id="d\(index)"><head>\(index + 1). Item</head>
                <p>\(prefix) number \(index) discusses containment.</p></div>

                """
            }
            xml += "</body></text></TEI>"
            try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(name).xml"))
        }
        let live = dir.appendingPathComponent("live.sqlite")
        let fts5 = try FTS5Store(databaseURL: live)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: live,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol0")
        try await pipeline.indexVolume("vol1")
        try await pipeline.removeVolume("vol0")
        let tagId = "DDDDDDDD-0000-0000-0000-00000000000D"
        try await pipeline.updateNoteText(volumeId: "vol1", documentId: "d3", bodyText: noteText)
        try await pipeline.updateSummaryText(volumeId: "vol1", documentId: "d4", responseText: summaryText)
        try await pipeline.updateUserTagIds(volumeId: "vol1", documentId: "d5", userTagIds: tagId)
        try await pipeline.replaceUserTagNames([(id: tagId, name: "escalation-rhetoric")])

        let copy = dir.appendingPathComponent("copy.sqlite")
        let db = try Self.backup(live, to: copy)
        defer { sqlite3_close(db) }
        #expect(Self.rows(db, "SELECT name FROM user_tags") == ["escalation-rhetoric"],
                "precondition: the copy holds the writing")
        for step in ResearchDatabaseStrip.steps {
            var message: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(db, step.sql, nil, nil, &message)
            #expect(code == SQLITE_OK, "\(step.action): \(message.map { String(cString: $0) } ?? "?")")
            sqlite3_free(message)
        }

        for column in ["note_text", "summary_text", "user_tag_ids"] {
            #expect(Self.rows(db, "SELECT \(column) FROM document_cache WHERE \(column) IS NOT NULL").isEmpty,
                    "\(column) survived the strip")
        }
        #expect(Self.rows(db, "SELECT name FROM user_tags").isEmpty)
        #expect(Self.rows(db, "SELECT rowid FROM user_content WHERE user_content MATCH 'zebrafish OR kumquat'")
                    .isEmpty, "the writing survived in the index")
        for index in 0..<6 {
            #expect(Self.rows(db, """
                SELECT dc.document_id FROM frus_documents JOIN document_cache dc ON dc.rowid = frus_documents.rowid
                WHERE frus_documents MATCH 'body_text : "document number \(index)"'
                """) == ["d\(index)"], "a match no longer resolves to its document")
        }
        #expect(Self.rows(db, "PRAGMA quick_check") == ["ok"])
    }

    /// Copies `source` to a new file with `sqlite3_backup`, as Export Research Database… does, and
    /// returns a writing connection to the copy, in rollback-journal mode as the export's is.
    private static func backup(_ source: URL, to destination: URL) throws -> OpaquePointer {
        var src: OpaquePointer?
        guard sqlite3_open_v2(source.path, &src, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(src) }
        var dst: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &dst, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
                == SQLITE_OK, let dst else { throw CocoaError(.fileWriteUnknown) }
        let backup = sqlite3_backup_init(dst, "main", src, "main")
        let stepped = sqlite3_backup_step(backup, -1)
        let finished = sqlite3_backup_finish(backup)
        guard stepped == SQLITE_DONE, finished == SQLITE_OK,
              sqlite3_exec(dst, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(dst)
            throw CocoaError(.fileWriteUnknown)
        }
        return dst
    }

    private static func rows(_ db: OpaquePointer, _ sql: String) -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return ["(refused)"] }
        defer { sqlite3_finalize(statement) }
        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "")
        }
        return rows
    }
}
