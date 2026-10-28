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
/// decodes, a version-7 file of every type decodes whole, the encoder writes what it always wrote,
/// and a truncated file still fails.
///
/// `ResearchDataExporterTests` (the app's) builds envelopes from a SwiftData store; these need no
/// store, so they run under `swift test` on every platform the kit builds on.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the envelope moved into the kit
///   1.1 — FRUS Explorer Light: format version 7
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

        // Nothing version 7 added is invented for an earlier file: its types are empty and its
        // fields absent, which a reader tells from "none" by the file's version.
        #expect(envelope.savedSearches.isEmpty && envelope.workingCorpora.isEmpty
                    && envelope.customVolumeScopes.isEmpty && envelope.classificationOverrides.isEmpty
                    && envelope.personClusterOverrides.isEmpty && envelope.annotationReviews.isEmpty
                    && envelope.projectLeads.isEmpty && envelope.syncedPreferences.isEmpty)
        #expect(envelope.notes.first?.richText == nil)
        #expect(envelope.projects.first?.defaultUserTagIds == nil)
        #expect(envelope.summaries.first?.isHeadnoteDraft == nil)
        #expect(envelope.collections.first?.defaultBodyDepth == nil)
        #expect(envelope.collections.first?.entries.allSatisfy { $0.kind == nil && $0.level == nil } == true)
    }

    @Test("The format is at version 7")
    func currentVersion() {
        #expect(ResearchDataEnvelope.currentFormatVersion == 7)
    }

    /// The file a library holding every type exports at version 7, read back whole: each of the
    /// eight types 6 left out, and each field 6 dropped from the types it carried.
    @Test("A version-7 file of every type decodes, with every field version 7 added")
    func version7Decodes() throws {
        let envelope = try decode(ResearchDataFixtures.version7)
        let id = ResearchDataFixtures.id
        #expect(envelope.formatVersion == 7)

        // A note's rich text, as stored: RTF, base64 in the file.
        let rtf = try #require(envelope.notes.first?.richText)
        #expect(String(decoding: rtf, as: UTF8.self) == #"{\rtf1\ansi Key {\b turning} point in the negotiations.}"#)
        #expect(envelope.notes.first?.bodyText == "Key turning point in the negotiations.",
                "the plain text stays beside the rich text")

        // A project's focus tags and lead weights; a summary's headnote flag.
        #expect(envelope.projects.first?.defaultUserTagIds == [id(2)])
        #expect(envelope.projects.first?.leadAxisWeights == "subject=0.5;person=0.3;crossref=0.2")
        #expect(envelope.summaries.map(\.isHeadnoteDraft) == [false, true])
        #expect(envelope.summaries.last?.authorship == .userWritten)

        // A collection's front matter, composition and settings.
        let collection = try #require(envelope.collections.first)
        #expect(collection.subtitle == "The Paris talks")
        #expect(collection.authorLine == "A. Researcher")
        #expect(collection.introductionText == "Why these documents.")
        #expect(collection.introductionRichText != nil)
        #expect(collection.includeColophon == true && collection.includeProjectProvenance == false
                    && collection.includeMethodAppendix == false)
        #expect(collection.defaultBodyDepth == "full" && collection.footnoteStyle == "all"
                    && collection.tocStyle == "citation")
        #expect(collection.includeFootnotes == true && collection.includeSourceNote == true)
        #expect(collection.applyHighlights == true && collection.includeNotes == true
                    && collection.includeWordCloud == false && collection.defaultIncludeHeadnote == false)
        #expect(collection.summaryPromptId == id(9))

        // Each entry's kind, level, text, rich text, excerpt anchors, block type and overrides,
        // in order: the heading version 6 wrote as an entry with no document, then the document.
        #expect(collection.entries.map(\.kind) == ["heading", "document", "prose", "excerpt", "generated"])
        #expect(collection.entries.map(\.sortOrder) == [0, 1, 2, 3, 4])
        let heading = collection.entries[0], document = collection.entries[1]
        let prose = collection.entries[2], excerpt = collection.entries[3], block = collection.entries[4]
        #expect(heading.id == id(8) && heading.level == 1 && heading.text == "Chapter 3")
        #expect(document.titleOverride == "The turning point")
        #expect(document.bodyDepthOverride == "summaryOnly")
        #expect(document.applyHighlightsOverride == true && document.includeNotesOverride == false)
        #expect(document.includeSourceNoteOverride == true && document.includeFootnotesOverride == false)
        #expect(document.summaryPromptIdOverride == id(9))
        #expect(document.selectedHighlightIds == [id(4)])
        #expect(document.includeRelatedDocuments == true)
        #expect(document.includeHeadnote == true && document.headnoteSummaryId == id(21))
        #expect(prose.text == "What follows." && prose.richText != nil)
        #expect(excerpt.documentId == "d1" && excerpt.text == "a key turning point")
        #expect(excerpt.excerptStart == 10 && excerpt.excerptEnd == 29)
        #expect(excerpt.excerptRenderingVersion == "0123456789abcdef" && excerpt.excerptColorTag == "yellow")
        #expect(block.generatedBlockType == "chronology" && block.documentId == "")

        // The eight types version 6 left out.
        let search = try #require(envelope.savedSearches.first)
        #expect(search.id == id(22) && search.name == "Arms control, Nixon years")
        #expect(search.parameters == SearchParameters(
            keywords: "arms control", booleanMode: .and, excludedTerms: ["salt"],
            dateRange: DateRange(earliest: "1969-01-20", latest: "1974-08-09"),
            subjectTagIds: ["subject-arms-control"], userTagIds: [id(2).uuidString.lowercased()],
            volumeIds: ["frus1969-76v01"], includeSummaries: false,
            documentTypeFilter: .documentsOnly, includeFrontMatter: false))
        #expect(search.matchCountAtLastRun == 412 && search.indexedVolumeCountAtLastRun == 553)
        #expect(search.lastRunAt != nil)
        let corpus = try #require(envelope.workingCorpora.first)
        #expect(corpus.documentKeys == ["frus1969-76v01/d1", "frus1969-76v01/d2"])
        #expect(corpus.sourceQuery == "détente" && corpus.wasTruncatedAtCapture == false
                    && corpus.totalMatchCountAtCapture == 2 && corpus.indexedVolumeCountAtCapture == 553)
        #expect(envelope.customVolumeScopes.map(\.volumeIds) == [["frus1969-76v01", "frus1969-76v12"]])
        let classification = try #require(envelope.classificationOverrides.first)
        #expect(classification.documentId == "d3" && classification.isEditorialNote
                    && !classification.parsedIsEditorialNote)
        let person = try #require(envelope.personClusterOverrides.first)
        #expect(person.kind == "merge" && person.refA == "p_KH1" && person.refB == "p_KHA1")
        let review = try #require(envelope.annotationReviews.first)
        #expect(review.annotationType == "document" && review.annotationId == nil
                    && review.contentHash == "9f86d081884c7d65" && review.changeKind == "text")
        let lead = try #require(envelope.projectLeads.first)
        #expect(lead.projectId == id(1) && lead.aggregateScore == 1.75 && lead.dismissed)
        #expect(lead.contributingSeedKeys == ["frus1969-76v01/d1"] && lead.documentNumber == "9")
        let preferences = try #require(envelope.syncedPreferences.first)
        #expect(preferences.wcMinCount == 2 && !preferences.wcExcludeBoilerplate)
        #expect(preferences.wcGlobalStopwordsJSON == #"["telegram"]"#)
        #expect(preferences.citationStyleRaw == "chicago" && preferences.defaultDocumentModeRaw == "research")
    }

    /// The app's own file, read by the kit: Mac check 10 exports a library holding every type and
    /// names the file in `FRUS_RESEARCH_EXPORT` (`TEST_RUNNER_FRUS_RESEARCH_EXPORT` under Xcode),
    /// and the file must decode, at a version this decoder knows, and encode back to itself. With
    /// no file named there is nothing to read, and the test checks nothing.
    @Test("An export named by FRUS_RESEARCH_EXPORT decodes, and encodes back to itself")
    func namedExportDecodes() throws {
        guard let path = ProcessInfo.processInfo.environment["FRUS_RESEARCH_EXPORT"], !path.isEmpty else {
            return
        }
        let envelope = try ResearchDataEnvelope.makeDecoder()
            .decode(ResearchDataEnvelope.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect((1...ResearchDataEnvelope.currentFormatVersion).contains(envelope.formatVersion))
        let again = try ResearchDataEnvelope.makeDecoder()
            .decode(ResearchDataEnvelope.self, from: try envelope.jsonData())
        #expect(again == envelope)
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
        // The fourteen arrays and two numbers every file at version 7 writes, with the header's
        // two names, which this file has.
        #expect(topLevel.count == 24, "\(topLevel)")
    }

    @Test("An envelope of every type encodes and decodes back to itself, to the byte",
          arguments: [6, 7])
    func roundTrip(version: Int) throws {
        let envelope = try decode(version == 7 ? ResearchDataFixtures.version7 : ResearchDataFixtures.version6)
        let data = try envelope.jsonData()
        let again = try ResearchDataEnvelope.makeDecoder().decode(ResearchDataEnvelope.self, from: data)
        #expect(again == envelope)
        #expect(try again.jsonData() == data, "a second encoding differs from the first")
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
/// in their order, and what they leave of a copy of a real index, in its rows, its indexes and its
/// bytes.
///
/// The app's `IndexDatabaseExporterTests` runs the strip through the export; this runs the steps
/// alone, on a copy made with `sqlite3_backup` as the export makes one, so a host that strips with
/// them on its own connection is held to the same result.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the steps moved into the kit
///   1.1 — FRUS Explorer Light: `secure_delete` first and your-content index emptied before
///          `VACUUM`, and a stripped copy's bytes searched for the words of its notes and summaries,
///          against the strip as it was, at `FAST`
@Suite("Research database strip")
struct ResearchDatabaseStripTests {

    private let noteText = "Zebrafish marginalia — a phrase that occurs nowhere in the corpus."
    private let summaryText = "Kumquat synopsis, likewise unique."

    @Test("The steps are the export's seven statements, in their order")
    func stepsInOrder() {
        #expect(ResearchDatabaseStrip.steps.map(\.action) == [
            "preparing to overwrite freed space",
            "removing your notes and summaries",
            "removing your tag names",
            "emptying your-content index",
            "reclaiming freed pages",
            "rebuilding the document index",
            "rebuilding your-content index",
        ])
        #expect(ResearchDatabaseStrip.steps.first?.sql == "PRAGMA secure_delete = ON")
        #expect(ResearchDatabaseStrip.steps[1].sql
                    == "UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL")
        #expect(Array(ResearchDatabaseStrip.steps.map(\.sql)[2...]) == [
            "DELETE FROM user_tags",
            "INSERT INTO user_content(user_content) VALUES('delete-all')",
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

    /// No word of the notes and summaries is anywhere in a stripped copy's bytes, free pages
    /// included. The control runs the strip as it was, without the two statements this test came
    /// with, and finds words of both: the rebuild of `user_content` after the `VACUUM` freed the
    /// pages that held the index's terms, and at `FAST`, the default of macOS's SQLite, a freed page
    /// keeps what it held, though the copy's rows and indexes hold none. Every strip here starts
    /// from `FAST`, so the steps are all that differ on every platform: Ubuntu's SQLite starts on.
    ///
    /// Each of the two keeps the words out alone, and each is held to what it does: with the pragma
    /// alone the pages the rebuild freed are there, written over; with the index emptied alone the
    /// `VACUUM` reclaims its pages, and the copy is smaller than the control's.
    ///
    /// The notes and summaries name 1,000 words each, so that the index outgrows one page.
    /// `stepsStripACopy`'s one note and one summary fit in its root page, which a rebuild clears
    /// rather than frees, and `FAST` zeroes what it deletes inside a page.
    @Test("A stripped copy's bytes hold no word of the notes and summaries, where the strip as it was left some")
    func strippedCopyKeepsNoWordInFreedPages() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSStripPages-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let written = try await Self.indexWithWriting(in: dir)
        let held = (notes: try Self.occurrences(of: "zqnote", in: written),
                    summaries: try Self.occurrences(of: "xvsumm", in: written))
        #expect(held.notes >= 1_000 && held.summaries >= 1_000, "precondition: the copy holds the writing: \(held)")

        let pragma = "PRAGMA secure_delete = ON"
        let emptying = "INSERT INTO user_content(user_content) VALUES('delete-all')"
        let steps = ResearchDatabaseStrip.steps
        let asItWas = try Self.strip(written, as: "as-it-was", with: steps.filter { $0.sql != pragma && $0.sql != emptying })
        let stripped = try Self.strip(written, as: "stripped", with: steps)
        let pragmaAlone = try Self.strip(written, as: "pragma-alone", with: steps.filter { $0.sql != emptying })
        let emptiedAlone = try Self.strip(written, as: "emptied-alone", with: steps.filter { $0.sql != pragma })

        #expect(asItWas.notes > 0 && asItWas.summaries > 0 && asItWas.freeLeavesHoldingData > 0,
                "control: the strip as it was, at FAST, leaves words of both in the pages it frees: \(asItWas)")
        for copy in [stripped, pragmaAlone, emptiedAlone] {
            #expect(copy.notes == 0 && copy.summaries == 0 && copy.freeLeavesHoldingData == 0,
                    "the writing's words are still in the copy: \(copy)")
        }
        #expect(stripped.secureDelete == "1" && stripped.pages < asItWas.pages, "\(stripped), against \(asItWas)")
        #expect(pragmaAlone.secureDelete == "1" && pragmaAlone.freePages > 0,
                "the pages the rebuild freed are there, written over with zeros: \(pragmaAlone)")
        #expect(emptiedAlone.secureDelete == "2" && emptiedAlone.pages < asItWas.pages,
                "the VACUUM reclaims the index's pages: \(emptiedAlone), against \(asItWas)")
    }

    /// What one strip left of a copy, read when its steps were done.
    private struct Stripped: CustomStringConvertible {
        /// The copy's name.
        let name: String
        /// How many times its bytes hold `zqnote`, which begins each of the notes' own words.
        let notes: Int
        /// How many times its bytes hold `xvsumm`, which begins each of the summaries' own words.
        let summaries: Int
        /// Its size in pages.
        let pages: Int
        /// How many of its pages are free.
        let freePages: Int
        /// How many of the freelist's leaf pages hold a byte that is not zero.
        let freeLeavesHoldingData: Int
        /// What `PRAGMA secure_delete` answered on its connection after the steps.
        let secureDelete: String

        var description: String {
            "\(name): \(notes) and \(summaries) of the words, \(pages) pages, \(freePages) free, "
                + "\(freeLeavesHoldingData) free leaves holding data, secure_delete \(secureDelete)"
        }
    }

    /// An index of one volume of 40 documents, copied as the export copies one, whose notes and
    /// summaries name 25 words each that the corpus lacks, written in one statement: `zqnote00000`
    /// to `zqnote00999` in the notes, and `xvsumm00000` to `xvsumm00999` in the summaries. Returns
    /// the copy, closed.
    private static func indexWithWriting(in dir: URL) async throws -> URL {
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        for index in 0..<40 {
            xml += """
            <div type="document" xml:id="d\(index)"><head>\(index + 1). Item</head>
            <p>Document number \(index) discusses containment.</p></div>

            """
        }
        xml += "</body></text></TEI>"
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let live = dir.appendingPathComponent("live.sqlite")
        let fts5 = try FTS5Store(databaseURL: live)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: live,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")

        let written = dir.appendingPathComponent("written.sqlite")
        let writer = try backup(live, to: written)
        let refused = exec(writer, """
            WITH RECURSIVE k(j) AS (SELECT 0 UNION ALL SELECT j + 1 FROM k WHERE j < 24)
            UPDATE document_cache SET
                note_text = (SELECT 'A note naming ' || group_concat(printf('zqnote%05d',
                    CAST(substr(document_id, 2) AS INTEGER) * 25 + j), ' ') FROM k),
                summary_text = (SELECT 'A summary naming ' || group_concat(printf('xvsumm%05d',
                    CAST(substr(document_id, 2) AS INTEGER) * 25 + j), ' ') FROM k)
            """)
        sqlite3_close(writer)
        #expect(refused == nil, "writing the notes and summaries: \(refused ?? "")")
        return written
    }

    /// Strips a copy of `written` with `steps`, all on one connection, from `FAST`; checks that its
    /// rows and its index hold none of the writing; and reads what the strip left.
    private static func strip(_ written: URL, as name: String,
                              with steps: [ResearchDatabaseStrip.Step]) throws -> Stripped {
        let url = written.deletingLastPathComponent().appendingPathComponent("\(name).sqlite")
        let db = try backup(written, to: url)
        #expect(exec(db, "PRAGMA secure_delete = FAST") == nil)
        for step in steps {
            let failure = exec(db, step.sql)
            #expect(failure == nil, "\(name), \(step.action): \(failure ?? "")")
        }
        #expect(rows(db, """
            SELECT count(*) FROM document_cache WHERE note_text IS NOT NULL OR summary_text IS NOT NULL
            """) == ["0"], "\(name): the rows kept the writing")
        #expect(rows(db, "SELECT count(*) FROM user_content WHERE user_content MATCH 'zqnote00999 OR xvsumm00999'")
                    == ["0"], "\(name): the index kept the writing")
        #expect(rows(db, "PRAGMA quick_check") == ["ok"])
        let pages = Int(rows(db, "PRAGMA page_count").first ?? "") ?? 0
        let freePages = Int(rows(db, "PRAGMA freelist_count").first ?? "") ?? 0
        let secureDelete = rows(db, "PRAGMA secure_delete").first ?? ""
        sqlite3_close(db)
        return Stripped(name: name, notes: try occurrences(of: "zqnote", in: url),
                        summaries: try occurrences(of: "xvsumm", in: url),
                        pages: pages, freePages: freePages,
                        freeLeavesHoldingData: try freeLeavesHoldingData(in: url), secureDelete: secureDelete)
    }

    /// How many of the freelist's leaf pages in the file at `url` hold a byte that is not zero, read
    /// from the file's header and the freelist's trunk pages, as SQLite's file format lays them out.
    private static func freeLeavesHoldingData(in url: URL) throws -> Int {
        let bytes = [UInt8](try Data(contentsOf: url))
        func number(at offset: Int) -> Int { bytes[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) } }
        let size = Int(bytes[16]) << 8 | Int(bytes[17])
        let pageSize = size == 1 ? 65_536 : size
        var holding = 0
        var trunk = number(at: 32)
        while trunk != 0 {
            let base = (trunk - 1) * pageSize
            for index in 0..<number(at: base + 4) {
                let leaf = (number(at: base + 8 + 4 * index) - 1) * pageSize
                if bytes[leaf..<leaf + pageSize].contains(where: { $0 != 0 }) { holding += 1 }
            }
            trunk = number(at: base)
        }
        return holding
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

    /// Runs `sql` with `sqlite3_exec`, as the app's export runs each step, and returns SQLite's
    /// message when it fails.
    private static func exec(_ db: OpaquePointer, _ sql: String) -> String? {
        var message: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(message) }
        guard sqlite3_exec(db, sql, nil, nil, &message) != SQLITE_OK else { return nil }
        return message.map { String(cString: $0) } ?? "no message"
    }

    /// How many times the file at `url` holds `needle` in its bytes, free pages included.
    private static func occurrences(of needle: String, in url: URL) throws -> Int {
        let bytes = try Data(contentsOf: url)
        let pattern = Data(needle.utf8)
        var count = 0
        var start = bytes.startIndex
        while let found = bytes.range(of: pattern, in: start..<bytes.endIndex) {
            count += 1
            start = found.upperBound
        }
        return count
    }
}
