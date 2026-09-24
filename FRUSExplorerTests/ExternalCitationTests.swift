// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - ExternalCitationTests

/// The `external_citations` table (#784): what the app writes when it indexes a volume, and the
/// three things it must never do.
///
/// The negative tests carry the weight here. Giving footnote citations a table is what makes the
/// capability possible; it is also what would let an editor's *mention* of an archive be counted
/// as a document *drawn from* one — the exact defect #783 removed from `document_sources` — or let
/// the document's own provenance be re-reported as an external pointer.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
@Suite("External citations (#784)")
struct ExternalCitationTests {

    // MARK: - The bundled index's per-target rows (#829)

    /// **The first consumer of these two methods owes this test, and #829 says so.**
    /// `referenceCount(forCollectionId:)` and `volumeCounts(forCollectionId:)` shipped with the
    /// artifact and had zero callers and zero tests until the collection record started drawing
    /// them. The rows are **parallel arrays under one-letter wire names** (`k`/`v`/`n`), so a
    /// generator that emitted volumes and counts out of step, or a decoder that zipped them wrongly,
    /// would produce a screen full of plausible numbers attached to the wrong volumes — and nothing
    /// anywhere would have noticed.
    @Test("Per-target rows zip volumes to counts, and agree with the row's own total")
    func perTargetRowsZipCorrectly() throws {
        let index = try #require(ExternalCitationIndexStore.shared,
                                 "the bundled external-citation index failed to load")

        // A target the artifact actually carries — take the heaviest, so the assertions have
        // something to bite on rather than passing over an empty row.
        let heaviest = try #require(
            index.heaviestPairs(limit: 1).first,
            "the shipped artifact has no between-unit pairs")
        let id = heaviest.targetId

        let total = index.referenceCount(forCollectionId: id)
        let perVolume = index.volumeCounts(forCollectionId: id)
        #expect(total > 0)
        #expect(!perVolume.isEmpty, "a target with references must name the volumes making them")

        // The two APIs read the same row two ways; they cannot disagree.
        #expect(perVolume.reduce(0) { $0 + $1.count } == total, """
            volumeCounts and referenceCount describe the same row and disagree — the parallel \
            arrays are out of step, or one of them is being read against the wrong index.
            """)

        // Every volume must be a real volume id, and every count positive. A zip that ran off the
        // end of the shorter array is what produces an empty or malformed id here.
        for entry in perVolume {
            #expect(!entry.volumeId.isEmpty)
            #expect(entry.volumeId.hasPrefix("frus"), "\(entry.volumeId) is not a volume id")
            #expect(entry.count > 0)
        }
        #expect(Set(perVolume.map(\.volumeId)).count == perVolume.count,
                "a volume appears twice in one target's row")

        // An id the artifact does not carry must return nothing rather than someone else's row —
        // the failure mode of an index lookup that falls back to a default position.
        #expect(index.referenceCount(forCollectionId: "lot:no-such-unit") == 0)
        #expect(index.volumeCounts(forCollectionId: "lot:no-such-unit").isEmpty)
    }

    /// The counts the collection record shows must be a subset of what the coverage block claims,
    /// or the screen is quoting a bigger number than the scan found.
    @Test("Per-target totals stay within the artifact's own coverage")
    func perTargetTotalsRespectCoverage() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        let sampled = index.heaviestPairs(limit: 25).map(\.targetId)
        #expect(!sampled.isEmpty)
        for id in Set(sampled) {
            let total = index.referenceCount(forCollectionId: id)
            #expect(total <= index.coverage.referencesJoined, """
                \(id) claims \(total) references, more than the \
                \(index.coverage.referencesJoined) the scan joined in total.
                """)
        }
    }

    // MARK: - The render-time join (#829a)

    /// Every unit endpoint must exist in the shipped authority (#832a).
    ///
    /// Its two sibling artifacts have carried this guard since #763 —
    /// `CollectionUsageIndexTests.collectionIdsJoinToTheAuthority` and
    /// `ProvenanceFlowIndexTests.endpointsJoinToTheAuthority` — and this index, which keys on the
    /// same authority ids, had none. The gap was not theoretical: the #832a separator fix
    /// re-clustered the authority and stranded **2 of this index's 1,236 ids**
    /// (`txt:central intelligence agency|dci (mccone) file`, `lot:68D323`) while the whole suite
    /// stayed green. The #832a audit had reasoned this artifact was "likely safe" because none of
    /// its ids carried a seam — true, and beside the point, since re-clustering moves ids that
    /// never carried one.
    @MainActor
    @Test("Every unit endpoint exists in the shipped authority")
    func endpointsJoinToTheAuthority() throws {
        let index = try #require(ExternalCitationIndexStore.shared,
                                 "the bundled external-citation index failed to load")
        let authority = try #require(CollectionAuthorityStore.shared,
                                     "the bundled collection authority failed to load")
        let known = Set(authority.collections.map(\.id))
        let orphans = (index.sourceIds + index.targetIds).filter { !known.contains($0) }
        #expect(orphans.isEmpty, """
            \(orphans.count) external-citation endpoints are absent from \
            collection-authority.json — the two artifacts were built against different \
            clusterings. Regenerate the external-citation index. First few: \
            \(orphans.prefix(5).joined(separator: ", "))
            """)
    }

    /// The stored rows carry **no authority id**, so the document section joins them at render time.
    /// Two things can go wrong and both are silent: a lot citation matching nothing when the
    /// authority holds it, and a presidential-library citation matching a *lot* record that happens
    /// to share a leading word — the #351 domain confusion. The second is why the guard exists.
    @MainActor
    @Test("The render-time join takes the lot key first and refuses a library-to-lot match")
    func renderTimeJoinFollowsTheGuard() throws {
        let authority = try #require(CollectionAuthorityStore.shared,
                                     "the bundled collection authority failed to load")

        // A lot citation resolves through the lot key, and to a lot record.
        let lotRecord = try #require(
            authority.collections.first { $0.id.hasPrefix("lot:") && $0.lotFileNorm != nil },
            "the authority carries no lot record to test against")
        let lotNorm = try #require(lotRecord.lotFileNorm)
        let lotCitation = ExternalCitation(
            anchor: "lotFile", repository: nil, collection: nil,
            lotFile: lotNorm, lotFileNorm: lotNorm, fileId: nil,
            inherited: false, rawText: "Lot \(lotNorm)", noteOrdinal: 0)
        #expect(SourceExplorerView.resolve(lotCitation, authority: authority)?.id
                == authority.record(forLotNorm: lotNorm)?.id)

        // **The guard.** A library citation whose leading segment happens to match a lot record must
        // resolve to nothing rather than to that record — a presidential library is not a lot file,
        // and the row renders inert instead of sending the reader somewhere wrong.
        let libraryCitation = ExternalCitation(
            anchor: "presidentialLibrary", repository: "Truman Library",
            collection: "Papers of Clark M. Clifford", lotFile: nil, lotFileNorm: nil,
            fileId: "Box 15", inherited: false,
            rawText: "Truman Library, Papers of Clark M. Clifford", noteOrdinal: 1)
        let resolved = SourceExplorerView.resolve(libraryCitation, authority: authority)
        #expect(resolved?.id.hasPrefix("lot:") != true,
                "a presidential-library citation resolved to a lot record — the #351 guard is off")

        // A citation naming nothing resolvable resolves to nothing, rather than to a first row.
        let empty = ExternalCitation(
            anchor: "lotFile", repository: nil, collection: nil, lotFile: nil, lotFileNorm: nil,
            fileId: nil, inherited: true, rawText: "Ibid.", noteOrdinal: 2)
        #expect(SourceExplorerView.resolve(empty, authority: authority) == nil)
    }

    /// The join uses the collection's **leading segment**, because that is the level the authority
    /// clusters on — passing the whole comma-joined series name matches nothing.
    @MainActor
    @Test("The join keys on the collection's leading segment, not the whole series name")
    func renderTimeJoinUsesLeadingSegment() throws {
        let authority = try #require(CollectionAuthorityStore.shared)
        // Find a library record the authority really carries, and cite it with a longer series name
        // than the record's own — the shape a footnote actually takes.
        guard let record = authority.collections.first(where: {
            $0.id.hasPrefix("txt:") && $0.repository != nil && !$0.name.isEmpty
        }) else { return }
        let deeper = ExternalCitation(
            anchor: "presidentialLibrary", repository: record.repository,
            collection: "\(record.name), Subject File, Box 3",
            lotFile: nil, lotFileNorm: nil, fileId: nil, inherited: false,
            rawText: "…", noteOrdinal: 0)
        // Either it resolves to that record, or the guard refused it — never to something else.
        if let hit = SourceExplorerView.resolve(deeper, authority: authority) {
            #expect(hit.id == record.id,
                    "the leading segment matched a different record than the one it names")
        }
    }

    // MARK: - #1322: the label the volume printed

    /// A document shaped like a real post-1945 one: the source note is printed as footnote 1
    /// INSIDE `<head>`, so the harvest's ordinals and the printed numbers differ by one from the
    /// start — and then differ by more, because an empty note is skipped.
    ///
    /// Notes: head `n="1"` (source, skipped) · `n="2"` · `n="3"` · `n="4"` blank (skipped) ·
    /// `n="5"` · `n="6"` citing a lot. The citing note is at ORDINAL 3 and prints **6**.
    private func labelledVolumeXML() -> String {
        """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d1" n="1">
            <head>A memorandum<note n="1" type="source" xml:id="d1fn1">Source: Lot 99 Z 9.</note></head>
            <p>Body.<note n="2" xml:id="d1fn2">A plain note.</note>\
        <note n="3" xml:id="d1fn3">Another plain note.</note>\
        <note n="4" xml:id="d1fn4"> </note>\
        <note n="5" xml:id="d1fn5">A third plain note.</note>\
        <note n="6" xml:id="d1fn6">Not printed. (Department of State, Lot 63 D 351, CF 1)</note></p>
          </div>
        </body></text></TEI>
        """
    }

    @Test("The stored citation carries the label the volume printed, not its ordinal (#1322)")
    func storesThePrintedLabel() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-label-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = try await index(labelledVolumeXML(), in: dir)

        let citations = try await pipeline.externalCitations(
            volumeId: "frus1952-54v01", documentId: "d1")
        let citation = try #require(citations.first)
        #expect(citations.count == 1)
        #expect(citation.noteOrdinal == 3, """
            The harvest skips the head source note and the blank note, so the citing note is the \
            fourth it keeps. Got ordinal \(citation.noteOrdinal).
            """)
        #expect(citation.noteLabel == "6", """
            Expected the printed label "6"; got \(citation.noteLabel ?? "nil"). `noteOrdinal + 1` \
            would give "4" and `+ 2` "5" — the reason this column exists.
            """)
    }

    /// One fixture per label shape, because a fixture that violated two rules would test neither.
    @Test("A printed label is stored as printed, trimmed, and never invented (#1322)",
          arguments: [("*", "*"), (" 7", "7"), ("", nil), (nil, nil)] as [(String?, String?)])
    func labelShapes(printed: String?, expected: String?) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-shape-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let attribute = printed.map { " n=\"\($0)\"" } ?? ""
        let xml = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d1" n="1">
            <note type="source">Source: Lot 99 Z 9.</note>
            <head>A memorandum</head>
            <p>Body.<note\(attribute) xml:id="d1fn1">Not printed. (Department of State, Lot 63 D 351, CF 1)</note></p>
          </div>
        </body></text></TEI>
        """
        let pipeline = try await index(xml, in: dir)
        let citation = try #require(try await pipeline.externalCitations(
            volumeId: "frus1952-54v01", documentId: "d1").first)
        #expect(citation.noteLabel == expected, """
            n=\(printed.map { "\"\($0)\"" } ?? "absent") stored as \
            \(citation.noteLabel.map { "\"\($0)\"" } ?? "nil"), expected \
            \(expected.map { "\"\($0)\"" } ?? "nil"). A raw store keeps " 7" and "", and a \
            synthesised one invents a digit where the volume printed none.
            """)
    }

    @Test("The stored label is the one the reader draws (#1322)")
    func storedLabelMatchesTheReader() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-parity-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let xml = labelledVolumeXML()
        let pipeline = try await index(xml, in: dir)
        let stored = try #require(try await pipeline.externalCitations(
            volumeId: "frus1952-54v01", documentId: "d1").first).noteLabel

        // The reader's own path: real parser, real converter, the marker's displayLabel.
        let volumeURL = dir.appendingPathComponent("volumes/frus1952-54v01.xml")
        let ast = try #require(try await FRUSDocumentParser().parse(volumeURL: volumeURL).first)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(ast)
        var labels: [String?] = []
        func walk(_ nodes: [FRUSRenderNode]) {
            for node in nodes {
                if case .footnoteBody(_, let type, _, _, let displayLabel, _) = node,
                   type != .source {
                    labels.append(displayLabel)
                }
                if case .paragraph(let c) = node { walk(c) }
            }
        }
        walk(model.bodyNodes); walk(model.footnotes)
        #expect(labels.contains(stored), """
            The packet stored \(stored ?? "nil") while the reader shows \(labels). The two \
            normalise `@n` through one function for exactly this reason.
            """)
    }

    @Test("The exported packet prints the volume's own footnote number (#1322)")
    func exportedPacketPrintsThePrintedLabel() async throws {
        // End to end through the REAL emitter: pipeline -> TripPacketDataSource -> builder ->
        // exporter text. A mirrored stub would have kept passing while the shipped path printed
        // the ordinal.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-packet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = try await index(labelledVolumeXML(), in: dir)

        let dataSource = await TripPacketDataSource(pipeline: pipeline, manifestMap: [:])
        let model = await TripPacketBuilder.build(
            documents: [("frus1952-54v01", "d1")], researchQuestion: nil, dataSource: dataSource)
        let text = await TripPacketExporter(model: model, projectName: "Test").export()

        #expect(text.contains(", footnote 6"), """
            The packet does not cite the printed number. Text was:
            \(text.prefix(1200))
            """)
        #expect(!text.contains(", footnote 4"), """
            The packet printed the ordinal + 1 — the defect #1322 is about.
            """)
    }

    @Test("A database written before v53 gains the column and still stores rows (#1322)")
    func legacyTableGainsTheLabelColumn() async throws {
        // The v40 defect class: a column added to the CREATE but not ALTERed makes every insert
        // throw, and because a volume's rows are DELETED before the insert, the table empties
        // while the build stays green. This is the guard.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extcit-migrate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(labelledVolumeXML().utf8)
            .write(to: volumes.appendingPathComponent("frus1952-54v01.xml"))
        let dbURL = dir.appendingPathComponent("legacy.sqlite")

        // The 13-column table exactly as it shipped before this change.
        var legacy: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &legacy) == SQLITE_OK)
        #expect(sqlite3_exec(legacy, """
            CREATE TABLE external_citations (
                volume_id TEXT NOT NULL, document_id TEXT NOT NULL,
                note_ordinal INTEGER NOT NULL, citation_index INTEGER NOT NULL,
                anchor TEXT NOT NULL, repository TEXT, collection TEXT, lot_file TEXT,
                lot_file_norm TEXT, file_id TEXT, inherited INTEGER NOT NULL DEFAULT 0,
                raw_text TEXT NOT NULL, decimal_class TEXT,
                PRIMARY KEY (volume_id, document_id, note_ordinal, citation_index))
            """, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(legacy)

        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("frus1952-54v01")

        var db: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var columns: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(external_citations)", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 1) { columns.append(String(cString: name)) }
            }
        }
        sqlite3_finalize(stmt)
        #expect(columns.contains("note_label"), """
            The legacy table did not gain note_label: \(columns). Without the ALTER every insert \
            names a missing column, throws, and leaves the table EMPTY after the delete.
            """)

        let citations = try await pipeline.externalCitations(
            volumeId: "frus1952-54v01", documentId: "d1")
        #expect(citations.count == 1, "the migrated table stored nothing")
        #expect(citations.first?.noteLabel == "6")
        #expect(IndexingPipeline.currentDateIndexVersion >= 53, """
            A new parse output needs its own index version, or no installed index re-parses.
            """)
    }

    // MARK: - Fixtures

    /// A volume whose one document carries a source note and the given body footnotes.
    private func volumeXML(sourceNote: String, footnotes: [String],
                           headNote: String? = nil) -> String {
        let notes = footnotes.enumerated().map { i, text in
            "<note n=\"\(i + 1)\" xml:id=\"d1fn\(i + 1)\">\(text)</note>"
        }.joined()
        let head = headNote.map {
            "<head>A memorandum<note n=\"0\" xml:id=\"d1fn0\">\($0)</note></head>"
        } ?? "<head>A memorandum</head>"
        return """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d1" n="1">
            <note type="source">\(sourceNote)</note>
            \(head)
            <p>Body.\(notes)</p>
          </div>
        </body></text></TEI>
        """
    }

    /// Indexes one fixture volume and returns its pipeline.
    private func index(_ xml: String, volumeId: String = "frus1952-54v01",
                       in dir: URL) async throws -> IndexingPipeline {
        try await indexReturningDatabase(xml, volumeId: volumeId, in: dir).pipeline
    }

    /// Indexes one fixture volume, returning the database URL too for raw-SQL assertions.
    private func indexReturningDatabase(
        _ xml: String, volumeId: String = "frus1952-54v01", in dir: URL
    ) async throws -> (pipeline: IndexingPipeline, dbURL: URL) {
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume(volumeId)
        return (pipeline, dbURL)
    }

    /// Counts rows in one aux table, straight from the file.
    ///
    /// Read with SQL rather than through a pipeline accessor on purpose: the claim is about the
    /// *table*, and an accessor that filtered would hide exactly the rows this asserts are absent.
    private func rowCount(in table: String, dbURL: URL) throws -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let handle = db else {
            sqlite3_close(db)
            throw NSError(domain: "ExternalCitationTests", code: 1)
        }
        defer { sqlite3_close_v2(handle) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM \(table)", -1, &stmt, nil) == SQLITE_OK
        else { throw NSError(domain: "ExternalCitationTests", code: 2) }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExtCit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    // MARK: - The decimal channel (#834 commit 3)

    /// **The test that justifies the reindex.** The column costs every tester a full rebuild, and a
    /// column that ships always-NULL while the build exits 0 is precisely what #965's suite exists
    /// to catch. So this drives the real pipeline over real TEI and reads the value back out.
    ///
    /// **The fixture's shape is load-bearing.** `decimalClassLocation` scans a clause's COMMA
    /// SEGMENTS and needs the class to LEAD one. A first version of this test wrote
    /// `"… is in file 763.72/9732."`, burying the number behind prose inside its segment, and the
    /// pipeline correctly found nothing — the test failed for a reason that was about the fixture,
    /// not the feature. The corpus writes these as `Memorandum of conversation by Campbell,
    /// February 6, 641.64/2-651`, which is the shape used here.
    @Test("A footnote citing a central file by number is indexed with its class")
    func indexesACentralFileClass() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.61/5-1052.",
                footnotes: [
                    "Telegram 1345 from Moscow, March 5, 763.72/9732.",
                ]), in: dir)

            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            let classes = citations.filter { $0.anchor == "centralFileClass" }
            #expect(classes.count == 1, """
                The footnote names one central file and it must reach the table. Before #834 this \
                row did not exist, so a document citing this way showed no archival footnotes at \
                all — and citing by number is the usual practice before 1946.
                """)
            #expect(classes.first?.decimalClass == "763.72")
            #expect(classes.first?.displayLabel == "763.72", """
                A class row's repository is "Department of State", the same as every lot's, so a \
                displayLabel falling through to the repository would label the citation with the \
                department and lose the only identifying thing about it.
                """)
        }
    }

    /// The id must separate two classes in one footnote. They share a repository, carry no lot and
    /// no collection, so every other component of the key is identical — duplicate `Identifiable`
    /// ids, which a SwiftUI list silently renders as one row.
    @Test("Two classes in one footnote get distinct ids")
    func twoClassesInOneFootnoteAreDistinct() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.61/5-1052.",
                footnotes: [
                    "Despatch 296, 763.72/9732; memorandum of conversation, 811.24546/1c.",
                ]), in: dir)
            let classes = try await pipeline
                .externalCitations(volumeId: "frus1952-54v01", documentId: "d1")
                .filter { $0.anchor == "centralFileClass" }
            #expect(classes.count == 2, "fixture guard: both clauses must yield a class")
            #expect(Set(classes.map(\.id)).count == 2, """
                Two class citations in one footnote produced the same id. A SwiftUI ForEach shows \
                one row and warns at runtime; the reader silently loses a citation.
                """)
        }
    }

    /// Subject-numeric stays out of the table exactly as it stays out of the artifact — one scope
    /// decision applied in both places, or the two surfaces disagree about the same footnote.
    @Test("A subject-numeric designator is not indexed as a class")
    func subjectNumericIsNotIndexed() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.61/5-1052.",
                footnotes: ["See Department of State, Central Files, POL 27 VIET S/8-1256."]), in: dir)
            let classes = try await pipeline
                .externalCitations(volumeId: "frus1952-54v01", documentId: "d1")
                .filter { $0.anchor == "centralFileClass" }
            #expect(classes.isEmpty, """
                Subject-numeric designators are out of scope by owner decision and #784 measured \
                them 87.2% out of vocabulary. Indexing one would put a citation in the table that \
                the bundled artifact refused.
                """)
        }
    }

    // MARK: - What it writes

    @Test("Indexing writes one row per unit per footnote, in reading order")
    func writesARowPerCitation() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Conference Files: Lot 60 D 627, CF 200.",
                footnotes: [
                    "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351, NSC 68 Series.",
                    "Another copy is in the Johnson Library, National Security File, Komer Files.",
                ]), in: dir)

            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            #expect(citations.count == 2)
            #expect(citations[0].lotFileNorm == "63D351", """
                The normal form is the join key to `document_sources.lot_file_norm` and the \
                authority's `lot:` records. Without it the row resolves to nothing.
                """)
            #expect(citations[0].noteOrdinal == 0)
            #expect(citations[1].repository == "Johnson Library")
            #expect(citations[1].collection == "National Security File")
            #expect(citations[1].noteOrdinal == 1)
            #expect(citations.allSatisfy { !$0.inherited })
        }
    }

    /// The Phase 4 sparsity measure, driven over a real fixture index: three documents,
    /// where one carries a lot footnote (counts), one carries ONLY a decimal-class
    /// footnote (must NOT count — the class anchor is outside the packet's channel, and
    /// counting it would overstate the sparsity the captions caption), and one carries no
    /// footnotes at all.
    @Test("externalCitationSparsity counts lot/library documents over all indexed documents")
    func sparsityCountsChannelDocumentsOnly() async throws {
        try await withTempDir { dir in
            let xml = """
            <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
              <div type="document" xml:id="d1" n="1">
                <note type="source">Source: Department of State, Central Files, 611.41/3–553.</note>
                <head>A memorandum</head>
                <p>Body.<note n="1" xml:id="d1fn1">A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.</note></p>
              </div>
              <div type="document" xml:id="d2" n="2">
                <note type="source">Source: Department of State, Central Files, 611.41/3–553.</note>
                <head>A telegram</head>
                <p>Body.<note n="1" xml:id="d2fn1">Telegram 1345 from Moscow, March 5, 763.72/9732.</note></p>
              </div>
              <div type="document" xml:id="d3" n="3">
                <note type="source">Source: Department of State, Central Files, 611.41/3–553.</note>
                <head>A letter</head>
                <p>Body with no footnotes.</p>
              </div>
            </body></text></TEI>
            """
            let pipeline = try await index(xml, in: dir)
            let measured = try await pipeline.externalCitationSparsity()
            #expect(measured.indexedDocuments == 3)
            #expect(measured.documentsWithReferences == 1, """
                Only d1's lot citation is in the packet's channel — d2's class citation is \
                the anchor the channel excludes, and counting it would report a sparsity the \
                captions do not describe.
                """)
        }
    }

    @Test("A footnote naming two units writes both")
    func keepsEveryCitationInANote() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: [
                    "Drafts are in Conference Files: Lot 60 D 627, CF 200; another is in the Eisenhower Library, Whitman File.",
                ]), in: dir)
            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            #expect(citations.count == 2, """
                The old editorial-note code kept `citations.first` and discarded the rest — \
                measured at 1,182 of 3,208. The composite key is what makes keeping both possible.
                """)
            #expect(citations.map(\.noteOrdinal) == [0, 0])
        }
    }

    @Test("An Ibid. is stored, and marked as inherited")
    func marksInheritedCitations() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: [
                    "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.",
                    "Ibid.",
                ]), in: dir)
            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            #expect(citations.count == 2)
            #expect(citations[1].inherited, """
                A surface that treats an inherited unit as if the editor had spelled it out is \
                overstating the evidence; the flag is what lets it say so.
                """)
            #expect(citations[1].lotFileNorm == "63D351")
        }
    }

    @Test("A bare Ibid. inherits a central-file class from the preceding footnote (#1014)")
    func classInheritsViaBareIbid() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: [
                    "Department of State, Central Files, 763.72/9732.",
                    "Ibid.",
                ]), in: dir)
            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
                .filter { $0.anchor == "centralFileClass" }
            #expect(citations.count == 2, "the direct reference and the inherited one")
            #expect(!citations[0].inherited)
            #expect(citations[0].decimalClass == "763.72")
            #expect(citations[1].inherited, """
                The class came from a bare Ibid., not from a class written in the clause — the \
                same disclosure the lot/library rows carry, through the same shared walker the \
                artifact's generator runs.
                """)
            #expect(citations[1].decimalClass == "763.72")
            #expect(citations[1].noteOrdinal == 1)
        }
    }

    @Test("Ibid. state does not leak from one document into the next")
    func ibidStateResetsBetweenDocuments() async throws {
        try await withTempDir { dir in
            // Two documents. The first names a lot; the second opens with a bare `Ibid.` that in
            // print refers to nothing — footnote 1 of document 2 cannot mean footnote 3 of
            // document 1, because the printed page renumbers.
            //
            // The mutation sweep is why this test has two documents. Every other fixture here has
            // one, so removing the pipeline's `beginDocument()` call changed no result and the
            // wiring was unpinned — the scanner's own reset test proves the scanner, not the pass
            // that drives it.
            let xml = """
            <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
              <div type="document" xml:id="d1" n="1">
                <note type="source">Source: Department of State, Central Files, 611.41/3–553.</note>
                <head>First</head>
                <p>Body.<note n="1" xml:id="d1fn1">A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.</note></p>
              </div>
              <div type="document" xml:id="d2" n="2">
                <note type="source">Source: Department of State, Central Files, 611.41/3–554.</note>
                <head>Second</head>
                <p>Body.<note n="1" xml:id="d2fn1">Ibid.</note></p>
              </div>
            </body></text></TEI>
            """
            let pipeline = try await index(xml, in: dir)
            #expect(try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                         documentId: "d1").count == 1)
            #expect(try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                         documentId: "d2").isEmpty, """
                Document 2's `Ibid.` inherited document 1's lot file. That is a citation the \
                editor never made, attached to a document that never named an archive.
                """)
        }
    }

    // MARK: - The three things it must not do

    @Test("Footnote citations never reach document_sources")
    func neverWritesToDocumentSources() async throws {
        try await withTempDir { dir in
            let (pipeline, dbURL) = try await indexReturningDatabase(volumeXML(
                sourceNote: "Source: Department of State, Conference Files: Lot 60 D 627, CF 200.",
                footnotes: [
                    "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.",
                    "Another is in the Johnson Library, National Security File.",
                ]), in: dir)
            #expect(try rowCount(in: "document_sources", dbURL: dbURL) == 1, """
                One row, for the document's own source note. #783 removed the footnote write \
                because every provenance query over this table counts rows without filtering the \
                era, so a footnote's archive would be counted as a document drawn from it.
                """)
            #expect(try rowCount(in: "external_citations", dbURL: dbURL) == 2,
                    "and both footnote citations landed in the table that is allowed to hold them")
            let source = try await pipeline.documentSourcesByKey([("frus1952-54v01", "d1")])
            #expect(source["frus1952-54v01/d1"]?.lotFile == "60 D 627",
                    "the one row is the document's own unit, not a footnote's")
        }
    }

    @Test("A head-nested note is the document's own provenance, not an external citation")
    func ignoresHeadNestedProvenance() async throws {
        try await withTempDir { dir in
            // frus1937v01/d29's real shape.
            let pipeline = try await index(volumeXML(
                sourceNote: "740.00/95½",
                footnotes: ["Assistant Under Secretary in the British Foreign Office."],
                headNote: "Photostatic copy obtained from the Franklin D. Roosevelt Library, Hyde Park, N. Y."),
                in: dir)
            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            #expect(citations.isEmpty, """
                Harvesting the head note would report the editors pointing *outside* the printed \
                record when they were saying where the printed record itself came from.
                """)
        }
    }

    @Test("An absence claim is not a citation")
    func ignoresAbsenceClaims() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: [
                    "No record of this discussion found in Department files or at the Franklin D. Roosevelt Library, Hyde Park, N. Y.",
                ]), in: dir)
            #expect(try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                         documentId: "d1").isEmpty)
        }
    }

    // MARK: - Re-index hygiene

    @Test("Re-indexing a volume replaces its citations rather than accumulating them")
    func reindexReplacesRows() async throws {
        try await withTempDir { dir in
            let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
            try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
            let url = volumes.appendingPathComponent("frus1952-54v01.xml")
            try Data(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: [
                    "A copy is in Department of State, S/S – NSC Files: Lot 63 D 351.",
                    "Another is in the Johnson Library, National Security File.",
                ]).utf8).write(to: url)
            let dbURL = dir.appendingPathComponent("test.sqlite")
            let store = try FTS5Store(databaseURL: dbURL)
            let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                                volumesDirectory: volumes, concurrencyLimit: 1)
            try await pipeline.indexVolume("frus1952-54v01")

            // The upstream volume is revised and one citation goes away.
            try Data(volumeXML(
                sourceNote: "Source: Department of State, Central Files, 611.41/3–553.",
                footnotes: ["A copy is in Department of State, S/S – NSC Files: Lot 63 D 351."]).utf8)
                .write(to: url)
            try await pipeline.indexVolume("frus1952-54v01")

            let citations = try await pipeline.externalCitations(volumeId: "frus1952-54v01",
                                                                 documentId: "d1")
            #expect(citations.count == 1, """
                `INSERT OR REPLACE` keys on (note_ordinal, citation_index), so without the \
                delete the vanished second citation would survive as a phantom row.
                """)
        }
    }

    // MARK: - The local stats read

    @Test("Citation stats count documents and volumes, and stay separate from provenance")
    func countsCitingDocumentsSeparately() async throws {
        try await withTempDir { dir in
            let pipeline = try await index(volumeXML(
                sourceNote: "Source: Department of State, Conference Files: Lot 60 D 627, CF 200.",
                footnotes: ["A copy is in Department of State, S/S – NSC Files: Lot 63 D 351."]),
                in: dir)
            let stats = try await pipeline.externalCitationStats(
                lotFileNorm: "63D351", repository: nil, collection: nil)
            #expect(stats.documents == 1)
            #expect(stats.volumes == 1)

            // The unit the document was *drawn from* has no footnote pointing at it.
            let ownUnit = try await pipeline.externalCitationStats(
                lotFileNorm: "60D627", repository: nil, collection: nil)
            #expect(ownUnit.documents == 0, """
                "Documents drawn from this collection" and "documents whose footnotes point at \
                it" are different claims over different tables. Reading one method for the other \
                is the blend #783 removed.
                """)
        }
    }
}

// MARK: - RealTEIFootnoteParityTests

/// Two volumes chosen for **citation density**, not convenience: `frus1958-60v03` carries 218
/// harvested references in 5.4 MB and `frus1955-57v19` 180 in 4.6 MB, so a parity failure has
/// hundreds of chances to show. The first draft used `frus1952-54v01p1`, which yields four —
/// a fixture that agrees with itself proves nothing about a grammar this size, and the sanity
/// floor below is what caught it.
private let footnoteParityVolumes = ["frus1955-57v19", "frus1958-60v03"]

/// Generator ↔ app parity for the #784 footnote harvest.
///
/// `DocumentFootnoteExtractor` (the generator's XML pass, compiled into this test bundle from the
/// SPM source) must produce the **same citations** as `IndexingPipeline`'s AST walk over the same
/// volumes. The two read different representations of the same file, so nothing but a test over
/// real TEI can catch a divergence — and a divergence would mean the bundled corpus-wide artifact
/// and the on-device table disagree about what the editors wrote, with no symptom anywhere.
@Suite("External citations — generator/app parity (#784)",
       .enabled(if: RealTEICorpus.hasVolumes(footnoteParityVolumes),
                "requires FRUS_TEI_MIRROR pointing at a local frus TEI volumes mirror"))
struct RealTEIFootnoteParityTests {

    @Test("The generator's footnote citations equal the pipeline's stored rows")
    func extractorMatchesStoredCitations() async throws {
        let volDir = try #require(RealTEICorpus.volumesDirectory)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExtCitParity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 2)
        for volumeId in footnoteParityVolumes { try await pipeline.indexVolume(volumeId) }

        for volumeId in footnoteParityVolumes {
            let xml = try Data(contentsOf: volDir.appendingPathComponent("\(volumeId).xml"))

            // Generator side: the same scanner over the same notes, keyed the same way.
            var expected: [String: [String]] = [:]
            var scanner = FootnoteCitationScanner()
            for document in DocumentFootnoteExtractor.extract(fromXML: xml)
            where !document.documentId.isEmpty {
                scanner.beginDocument()
                var keys: [String] = []
                for (ordinal, note) in document.footnotes.enumerated() {
                    for citation in scanner.scan(note: note) {
                        keys.append("\(ordinal)|\(Self.unitKey(citation))")
                    }
                }
                if !keys.isEmpty { expected[document.documentId] = keys }
            }
            #expect(expected.count > 50, """
                \(volumeId): sanity — a parity test over a volume with a handful of citations \
                agrees with itself and proves nothing. Both volumes carry well over a hundred.
                """)

            let actual = try await Self.storedCitationKeys(pipeline: pipeline, volumeId: volumeId,
                                                           documentIds: Set(expected.keys))
            let missing = expected.keys.filter { actual[$0] == nil }.sorted()
            #expect(missing.isEmpty,
                    "\(volumeId): generator found citations the app stored none for: \(missing.prefix(5))")
            var mismatches = 0
            for (documentId, keys) in expected where actual[documentId] != keys {
                mismatches += 1
                if mismatches <= 3 {
                    Issue.record("""
                        \(volumeId)/\(documentId): generator \(keys) vs app \(actual[documentId] ?? [])
                        """)
                }
            }
            #expect(mismatches == 0, "\(volumeId): \(mismatches) citation mismatches")
        }
    }

    /// The unit identity a row and a parse must agree on.
    private static func unitKey(_ citation: FootnoteArchivalCitation) -> String {
        switch citation.parsed {
        case .lotFile(_, let lot, _):
            return "lot:\(SourceNoteParser.lotFileNorm(lot))|\(citation.inherited)"
        case .presidentialLibrary(let library, let collection, _):
            return "lib:\(library)|\(collection)|\(citation.inherited)"
        default:
            return "other"
        }
    }

    /// The app's stored rows in the same key shape, for the documents the generator found.
    private static func storedCitationKeys(pipeline: IndexingPipeline, volumeId: String,
                                           documentIds: Set<String>) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for documentId in documentIds {
            let rows = try await pipeline.externalCitations(volumeId: volumeId,
                                                            documentId: documentId)
            guard !rows.isEmpty else { continue }
            result[documentId] = rows.map { row in
                if let norm = row.lotFileNorm, !norm.isEmpty {
                    return "\(row.noteOrdinal)|lot:\(norm)|\(row.inherited)"
                }
                return "\(row.noteOrdinal)|lib:\(row.repository ?? "")|\(row.collection ?? "")|\(row.inherited)"
            }
        }
        return result
    }


    // MARK: - #837: the shared row→authority join

    /// The rule shipped TWICE, identically and independently — `SourceExplorerView` for a
    /// document's unprinted pointers and `ArchivalLibraryProfile` for the library profile's
    /// citation groups — and #837 would have added a third for the graph's unit nodes. Three
    /// copies of a matching rule is three places for a resolution to drift, and the drift is
    /// invisible: each surface resolves a slightly different set and nothing compares them.
    ///
    /// Driven against the REAL bundled authority rather than a synthetic index: the lookup it
    /// calls carries alias bridging and two uniqueness guards, and a fixture simple enough to
    /// hand-write would exercise none of them.
    @Test("A lot number wins outright, before any name matching")
    func lotKeyWinsFirst() throws {
        let authority = try #require(CollectionAuthorityStore.shared)
        let record = ExternalCitationAuthorityJoin.record(
            lotFileNorm: "60D627", collectionName: "Something Else Entirely",
            repository: "Department of State", authority: authority)
        #expect(record?.id == "lot:60D627", """
            The name was matched ahead of the lot key. lot_file_norm is the canonical compact key \
            both sides of the corpus write, so an exact hit needs no disambiguation — and a \
            deliberately non-matching name must not be able to beat it.
            """)
    }

    /// The level-1 key is the LEADING comma segment: `Conference Files, Lot 60 D 627` clusters
    /// under `Conference Files`. Pure, so it needs no authority.
    @Test("The leading comma segment is the name key")
    func leadingSegmentIsTheKey() {
        #expect(ExternalCitationAuthorityJoin.leadingSegment(of: "Conference Files, Lot 60 D 627")
                == "Conference Files")
        #expect(ExternalCitationAuthorityJoin.leadingSegment(of: "  Padded Name  ") == "Padded Name")
        #expect(ExternalCitationAuthorityJoin.leadingSegment(of: "   ") == nil)
    }

    /// The #351 guard — the one step that REFUSES rather than resolves. A presidential library's
    /// series and a State lot file can carry the same words; answering the first with the second
    /// sends a reader to College Park for boxes that are in Boston.
    @Test("A library citation is never answered with a State lot record")
    func libraryOverLotGuardHolds() throws {
        let authority = try #require(CollectionAuthorityStore.shared)
        let refused = ExternalCitationAuthorityJoin.record(
            lotFileNorm: nil, collectionName: "Conference Files, Lot 60 D 627",
            repository: "Kennedy Library", authority: authority)
        #expect(refused?.id.hasPrefix("lot:") != true, """
            A Kennedy Library citation resolved to a State lot record — the #351 defect the guard \
            exists to prevent.
            """)
    }
}
// MARK: - DecimalChannelArtifactTests

/// Pins the decimal channel the shipped artifact carries at schema 2 (#834).
///
/// ## The coupling these guard
/// `ExternalCitationIndex.Coverage` is decoded from non-optional `let`s with a synthesized
/// `Decodable`. Adding a field to the struct without shipping the regenerated JSON throws
/// `keyNotFound`, `load()` catches it and returns nil with only a `#if DEBUG` print, and `shared`
/// is a `static let` evaluated once per process — never retried. Of the consumers only
/// `ArchivalAnalyticsView` discloses the nil; the Flows layer and the collection section simply
/// vanish. **Nothing fails loudly**, which is why the decode is asserted here.
///
/// Version history:
///   1.0 — Session 2026-08-20: #834 commit 2
@Suite("Decimal channel artifact (#834)")
struct DecimalChannelArtifactTests {

    @MainActor
    @Test("The bundled artifact decodes at schema 2 with a populated class axis")
    func artifactDecodesAtSchemaTwo() throws {
        let index = try #require(ExternalCitationIndexStore.shared, """
            The bundled external-citation index failed to load. A Coverage field added without \
            shipping the regenerated JSON does exactly this, and every consumer reads nil as \
            "footnote citations unavailable" without a build failure.
            """)
        #expect(index.schemaVersion >= 2, "the decimal channel ships at schema 2")
        #expect(!index.classTargetKeys.isEmpty, "the class axis must carry a vocabulary")
        #expect(!index.classTargets.isEmpty)
        #expect(!index.classPairs.isEmpty)
        #expect(index.coverage.decimalReferences > 0)
        #expect(index.coverage.decimalReferencesInherited > 0, """
            #1014 W-1b: the bare-Ibid. inheritance shipped, measured at 1,169 references. Zero \
            here means the regenerated artifact was built without the walker.
            """)
    }

    /// The class vocabulary must be keys the REST OF THE LENS can join to.
    ///
    /// This is a joinability guard, and it caught a real defect. The class lens merges the pointer
    /// weight with the documents and volumes weights, which are keyed by
    /// `collection-usage-index.json`'s vocabulary — built through `decimalClassKey`. But
    /// `decimalClassLocation`, which finds the citations, admits bare dotless numbers via its
    /// `bareClassCandidate` path that `decimalClassKey` rejects. The first run of this test found
    /// **63 such keys carrying 344 of 29,065 references**, every one of which would have ranked
    /// with pointer counts against zero documents.
    ///
    /// They are refused for that reason and not because they are fake: `222` composes as
    /// *Extradition / Ecuador* and dotless file numbers are a real filing form. Restoring them
    /// means giving them a home in the shared vocabulary, not relaxing this.

    // MARK: - Vocabulary parity with decimal-class-labels.json (#1201 drift)

    /// The class and country KEYS the shipped schedule admits through, digested the way the
    /// generator digests them.
    private func shippedVocabularyFingerprint() throws -> (classes: Int, countries: Int,
                                                           digest: String) {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root
            .appending(path: "FRUSExplorer/Resources/decimal-class-labels.json"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schedules = try #require(object["schedules"] as? [[String: Any]])
        // The 1910-1949 schedule specifically, mirroring `ScheduleValidator.init`. Falling back to
        // the first would silently digest a different era if one were ever prepended.
        let schedule = try #require(
            schedules.first { $0["id"] as? String == "1910-1949" } ?? schedules.first)
        let classes = try #require(schedule["classes"] as? [String: String]).keys.sorted()
        let countries = try #require(schedule["countries"] as? [String: String])
            .keys.map { $0.lowercased() }.sorted()
        let joined = "classes:" + classes.joined(separator: ",")
            + "|countries:" + countries.joined(separator: ",")
        let digest = SHA256.hash(data: Data(joined.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return (classes.count, countries.count, digest)
    }

    /// The two bundled artifacts must name the same admission vocabulary.
    ///
    /// **This is the test that was missing, and its absence cost ten days.** #1201 took the
    /// 1910-49 country table from 198 codes to 217 on 2026-09-05;
    /// `external-citation-index.json`, built 2026-08-27, went on shipping a class axis whose
    /// admission gate had refused 93 references the shipped schedule now admits. Nothing noticed,
    /// and `classKeysParse` structurally could not: it checks the shared class GRAMMAR, never the
    /// schedule.
    ///
    /// The obvious cheaper check cannot replace this one. Asserting that every stored
    /// `classTargetKey` still composes catches a vocabulary that SHRANK; #1201's drift GREW, and
    /// under a grown vocabulary every already-stored key goes on composing. That check is kept
    /// below as a second, independent assertion — it catches the other direction — but it is not
    /// this one.
    @MainActor
    @Test("The class axis was built through the schedule that ships beside it")
    func decimalVocabularyMatchesTheShippedSchedule() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root
            .appending(path: "FRUSExplorer/Resources/external-citation-index.json"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let coverage = try #require(object["coverage"] as? [String: Any])
        let recorded = try #require(coverage["decimalVocabulary"] as? [String: Any])
        let shipped = try shippedVocabularyFingerprint()

        #expect(recorded["digest"] as? String == shipped.digest, """
            The class axis was built through a different schedule than the one shipping beside it. \
            Re-run `swift run -c release ExternalCitationIndexGenerator` and commit both artifacts \
            together. Recorded \(recorded["classes"] ?? "?") classes / \
            \(recorded["countries"] ?? "?") countries; shipped \(shipped.classes) / \
            \(shipped.countries).
            """)
        // The counts are not the check — the digest is — but they are what a failure needs to be
        // readable, so they are pinned too rather than left to drift into decoration.
        #expect(recorded["classes"] as? Int == shipped.classes)
        #expect(recorded["countries"] as? Int == shipped.countries)
    }

    /// Every stored class key still composes under the shipped schedule.
    ///
    /// The other direction from the digest test, and genuinely independent of it: this fails when
    /// the vocabulary loses a code the index was built on — a re-parse that drops rows, or a
    /// schedule swapped for a different era — which a digest match would never reach, because a
    /// regenerated pair matches itself by construction.
    @MainActor
    @Test("No stored class key has lost its footing in the shipped schedule")
    func storedClassKeysStillCompose() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root
            .appending(path: "FRUSExplorer/Resources/decimal-class-labels.json"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schedules = try #require(object["schedules"] as? [[String: Any]])
        let schedule = try #require(
            schedules.first { $0["id"] as? String == "1910-1949" } ?? schedules.first)
        let classes = Set(try #require(schedule["classes"] as? [String: String]).keys)
        let countries = Set(try #require(schedule["countries"] as? [String: String])
            .keys.map { $0.lowercased() })

        // The TARGET side only. Source keys are the citing document's own class and are not
        // composes-gated — measured on this artifact, `797.00` rides along as a source although
        // country 97 is in no shipped vocabulary — so asserting over them would fail on data the
        // generator never claimed to admit.
        let orphaned = index.classTargetKeys.filter {
            !DecimalScheduleComposition.composes($0, classes: classes, countries: countries)
        }
        #expect(orphaned.isEmpty, """
            \(orphaned.count) stored class targets no longer compose under the shipped schedule — \
            the vocabulary lost codes this index was built on. First few: \
            \(orphaned.prefix(5).joined(separator: ", "))
            """)
    }

    @MainActor
    @Test("Every class key parses under the shared class grammar")
    func classKeysParse() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        let unparsed = (index.classTargetKeys + index.classSourceKeys)
            .filter { SourceNoteParser.decimalClassKey($0) == nil }
        #expect(unparsed.isEmpty, """
            \(unparsed.count) class keys do not parse as class keys. They would render bare and \
            join to nothing. First few: \(unparsed.prefix(5).joined(separator: ", "))
            """)
    }

    /// **The two axes are separate vocabularies and must stay so.** A class key is not an authority
    /// id; if class keys ever reached `targetIds`, `endpointsJoinToTheAuthority` would fail — and
    /// the reason that test still passes is that this separation holds.
    @MainActor
    @Test("Class keys never leak into the authority-id vocabulary")
    func axesDoNotMix() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        let authorityIds = Set(index.sourceIds + index.targetIds)
        let leaked = (index.classTargetKeys + index.classSourceKeys).filter { authorityIds.contains($0) }
        #expect(leaked.isEmpty, """
            \(leaked.count) class keys appear in the authority-id vocabulary. The axes have \
            different meanings and different index spaces; mixing them would index a class key \
            into targetIds. First few: \(leaked.prefix(5).joined(separator: ", "))
            """)
    }

    /// **The number every surface quoting this channel owes.** Most of what the decimal channel
    /// finds is a document citing its own file. If this ever reads near zero the harvest has
    /// changed meaning, and copy quoting the raw count would be overstating the layer ~3x.
    @MainActor
    @Test("Self-citation is stored and is the dominant share")
    func selfCitationIsStoredAndDisclosed() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        let coverage = index.coverage
        #expect(coverage.decimalSameClassReferences > 0, """
            Same-class references are stored rather than excluded, exactly as the collection axis \
            stores same-unit ones — an artifact that had already dropped them could not disclose \
            what the exclusion removed.
            """)
        #expect(coverage.decimalSameClassShare > 0.4, """
            Self-citation is \(String(format: "%.1f%%", coverage.decimalSameClassShare * 100)) of \
            the two-ended decimal channel; it was 62% when this shipped. A large drop means the \
            own-class comparison broke, which would make the channel look far more outward-facing \
            than it is.
            """)
        #expect(coverage.betweenClassReferences > 0, "there must be genuinely outward references too")
    }

    /// The feature this commit exists to ship: the class lens can rank the pointer weight.
    @MainActor
    @Test("The class lens has a pointer vocabulary to rank")
    func classLensRanksPointers() throws {
        let index = try #require(ExternalCitationIndexStore.shared)
        var totals: [String: Int] = [:]
        index.forEachClassReference { key, _, count in totals[key, default: 0] += count }
        #expect(totals.count > 100, """
            The class lens's pointer weight ranks \(totals.count) keys. Before #834 this was \
            EMPTY and the weight was withheld in the picker — that hole is what this fills.
            """)
        // Broken into locals deliberately: a nested `reduce` inside the `#expect` macro blows the
        // type checker ("unable to type-check this expression in reasonable time").
        var walked = 0
        for count in totals.values { walked += count }
        var stored = 0
        for row in index.classTargets {
            for count in row.counts { stored += count }
        }
        #expect(walked == stored, "the walk must visit every stored count exactly once")
    }
}

// MARK: - UnprintedMaterialRowTests

/// Source Explorer's Unprinted Material rows (#1390): every row its own id, and every row saying
/// something the others do not.
///
/// ## The defect
/// `frus1952-54v02p1` d41 lists five rows — "Lot 66 D 95" twice and "Lot 63 D 351" three times —
/// with nothing to tell them apart. The harvest is right: footnote 2 cites lot 66 D 95 in two
/// parentheticals, and footnotes 3, 4 and 5 each say, word for word, that a copy of the memorandum
/// is in S/S–NSC files, lot 63 D 351. The row drew the unit label, a box/folder that is nil here, an
/// Ibid. marker that is false here, and the same provenance chip on all five. And the two footnote-2
/// rows had the SAME SwiftUI id, because `ExternalCitation.id` was the note plus the unit fields —
/// which the Mac's `VStack` draws twice and the iOS `Form` may draw once.
///
/// ## Why the fixture is d41 and read through the real pipeline
/// The id collision needs one note citing one lot twice, the row-text collision needs three notes
/// citing a lot in identical words, and the marker needs that lot to be the source note's. Hand-built
/// `ExternalCitation`s would test the rule against whatever the test author believed the harvest
/// writes; this indexes TEI shaped like the real document (glosses, a head-nested footnote, notes
/// inside a `<list>`) and reads it back through BOTH index readers, then takes the source note the
/// way the reader hands it to Source Explorer — `extractSourceNote` over the parsed AST — and parses
/// it with the parser both twins use.
///
/// ## Where the twins can still drift
/// The text is computed once, in `SourceExplorerView.UnprintedPointer.rowText`; each twin still lays
/// the row out itself (a `Form` row on iOS, a `GroupBox` stack on the Mac). The source scans at the
/// end pin that both twins draw the function's output and neither reaches past it to the citation's
/// own label — a patch to one twin has no-opped on the other before.
///
/// Version history:
///   1.0 — Session 2026-09-24: #1390
@Suite("Unprinted Material rows (#1390)")
struct UnprintedMaterialRowTests {

    private static let volumeId = "frus1952-54v02p1"
    private static let documentId = "d41"

    /// d41 of `frus1952-54v02p1`, cut to the parts the harvest reads: the source note (glossed, as
    /// printed), the head with its own footnote 1, and the four referenced items whose footnotes 2–5
    /// carry the five citations. The enclosure and the body paragraphs carry no citations and are
    /// omitted. The wording of every note is the volume's.
    private static let d41XML = """
    <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
      <div subtype="historical-document" type="document" xml:id="d41" n="41">
        <note rend="inline" type="source"><gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140</note>
        <head><hi rend="italic">Report to the National Security Council by the Executive Secretary (<persName corresp="#p_LAYJSJ1">Lay</persName>)</hi><note n="1" xml:id="d41fn1">Copies to the Secretary of the Treasury, the Attorney General, the Director of Defense Mobilization, and the Acting Federal Civil Defense Administrator.</note></head>
        <opener>
          <dateline rendition="#right"><placeName><hi rend="smallcaps">Washington</hi></placeName>, <date calendar="gregorian" when="1953-01-19">January 19, 1953</date>.</dateline>
        </opener>
        <list type="references">
          <head>References:</head>
          <label>A.</label>
          <item><gloss target="#t_NSC1">NSC</gloss> Action Nos. 687 and 699<note n="2" xml:id="d41fn2">In <gloss target="#t_NSC1">NSC</gloss> Action No. 543, taken on Aug. 30, 1951, the National Security Council approved a draft directive on “A Project To Provide a More Adequate Basis for Planning for the Security of the United States”, prepared by the Director of Central Intelligence pursuant to <gloss target="#t_NSC1">NSC</gloss> Action No. 519. <gloss target="#t_NSC1">NSC</gloss> Action No. 687, taken at the Council meeting of Nov. 26, 1952, noted that a summary evaluation was limited and inadequate in several respects. (<gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> (Miscellaneous) files, lot 66 D 95, “Record of Actions”) <gloss target="#t_NSC1">NSC</gloss> Action No. 699, taken by the Council on Jan. 16, 1953, accepted a draft National Security Council directive for a special evaluation subcommittee. (<gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> (Miscellaneous) files, lot 66 D 95, “<gloss target="#t_NSC1">NSC</gloss> Record of Actions”)</note></item>
          <label>B.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Executive Secretary, dated January 15, 1953<note n="3" xml:id="d41fn3">Reference is to the memorandum enclosing the draft National Security Council directive for a special evaluation subcommittee which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 699. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
          <label>C.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Acting Executive Secretary, dated October 21, 1952<note n="4" xml:id="d41fn4">Reference is to the memorandum enclosing the summary evaluation which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 687 discussed in footnote 2 above. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
          <label>D.</label>
          <item>Memo for <gloss target="#t_NSC1">NSC</gloss> from Executive Secretary, dated November 25, 1952<note n="5" xml:id="d41fn5">Reference is to the memorandum containing amendments to the summary evaluation which became the subject of <gloss target="#t_NSC1">NSC</gloss> Action No. 687 discussed in footnote 2 above. A copy of this memorandum is in <gloss target="#t_SS1">S/S</gloss>–<gloss target="#t_NSC1">NSC</gloss> files, lot 63 D 351, <gloss target="#t_NSC1">NSC</gloss> 140 Series.</note></item>
        </list>
        <p>The draft directive, together with the above action, was subsequently submitted to the President for consideration.</p>
      </div>
    </body></text></TEI>
    """

    // MARK: Fixture plumbing

    /// Indexes d41 into a fresh database under `dir` and returns the pipeline and the volume file.
    private func indexD41(in dir: URL) async throws -> (pipeline: IndexingPipeline, volumeURL: URL) {
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let volumeURL = volumes.appendingPathComponent("\(Self.volumeId).xml")
        try Data(Self.d41XML.utf8).write(to: volumeURL)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume(Self.volumeId)
        return (pipeline, volumeURL)
    }

    /// The source note exactly as the reader hands it to Source Explorer — `extractSourceNote` over
    /// the parsed document, the path `DocumentViewModel` takes — parsed the way both twins parse it.
    private func parsedSourceNote(volumeURL: URL) async throws -> ParsedSourceNote {
        let documents = try await FRUSDocumentParser().parse(volumeURL: volumeURL)
        let ast = try #require(documents.first { $0.documentId == Self.documentId },
                               "the fixture volume lost its document")
        let raw = try #require(extractSourceNote(from: ast.nodes),
                               "the reader found no source note on d41")
        return SourceNoteParser().parse(raw)
    }

    /// d41's five pointers as both twins build them: the single-document reader's rows, each
    /// carrying the parsed source note.
    private func d41Pointers(in dir: URL) async throws -> [SourceExplorerView.UnprintedPointer] {
        let (pipeline, volumeURL) = try await indexD41(in: dir)
        let note = try await parsedSourceNote(volumeURL: volumeURL)
        let rows = try await pipeline.externalCitations(volumeId: Self.volumeId,
                                                        documentId: Self.documentId)
        return rows.map { SourceExplorerView.UnprintedPointer(citation: $0, record: nil,
                                                              sourceNote: note) }
    }

    private func withTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnprintedRow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }

    /// The ids that occur more than once, for a failure message that names them.
    private static func duplicates(_ ids: [String]) -> [String] {
        Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
    }

    // MARK: Ids

    /// The fixture has to reproduce d41's shape before any assertion about it means anything: five
    /// citations, two of them in footnote 2.
    @Test("The fixture reproduces d41: five citations, two of them in footnote 2")
    func fixtureReproducesD41() async throws {
        try await withTempDir { dir in
            let (pipeline, volumeURL) = try await indexD41(in: dir)
            let rows = try await pipeline.externalCitations(volumeId: Self.volumeId,
                                                            documentId: Self.documentId)
            try #require(rows.count == 5, "d41 carries five citations; the harvest found \(rows.count)")
            #expect(rows.map(\.noteLabel) == ["2", "2", "3", "4", "5"])
            #expect(rows.map(\.lotFileNorm) == ["66D95", "66D95", "63D351", "63D351", "63D351"])
            #expect(Set(rows[2...].map(\.rawText)).count == 1, """
                Footnotes 3, 4 and 5 must cite the lot in the same words, or the fixture no longer \
                needs the printed footnote number to tell the rows apart. Got \
                \(rows[2...].map(\.rawText)).
                """)
            let note = try await parsedSourceNote(volumeURL: volumeURL)
            guard case .lotFile(_, let lot, _) = note else {
                Issue.record("d41's source note must parse as a lot file; got \(note)")
                return
            }
            #expect(lot == "63 D 351")
        }
    }

    /// The single-document reader — the one both Source Explorer twins call.
    @Test("The document reader gives two citations of one lot in one note different ids")
    func documentReaderIdsAreUnique() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await indexD41(in: dir)
            let rows = try await pipeline.externalCitations(volumeId: Self.volumeId,
                                                            documentId: Self.documentId)
            #expect(rows.count == 5, "fixture guard: d41 carries five citations")
            #expect(rows.map(\.citationIndex) == [0, 1, 0, 0, 0], """
                `citation_index` is stored as part of the table's primary key; the reader must \
                select it. Got \(rows.map(\.citationIndex)).
                """)
            let ids = rows.map(\.id)
            #expect(Set(ids).count == ids.count, """
                Duplicate ExternalCitation ids: \(Self.duplicates(ids)). The iOS Source Explorer \
                is a Form, where a duplicate id can show as a missing row rather than a repeated one.
                """)
        }
    }

    /// The batched reader — the one the trip packet calls. It builds the same struct, so it owes the
    /// same column; a reader that selected it in one place and not the other would give the packet
    /// and Source Explorer different ids for one citation.
    @Test("The batched reader selects the same citation index")
    func batchedReaderIdsAreUnique() async throws {
        try await withTempDir { dir in
            let (pipeline, _) = try await indexD41(in: dir)
            let byKey = try await pipeline.externalCitationsByKey(
                [(volumeId: Self.volumeId, documentId: Self.documentId)])
            let rows = try #require(byKey["\(Self.volumeId)/\(Self.documentId)"])
            #expect(rows.count == 5, "fixture guard: d41 carries five citations")
            #expect(rows.map(\.citationIndex) == [0, 1, 0, 0, 0], """
                externalCitationsByKey does not select citation_index. Got \
                \(rows.map(\.citationIndex)).
                """)
            let ids = rows.map(\.id)
            #expect(Set(ids).count == ids.count, "Duplicate ids: \(Self.duplicates(ids))")
            let single = try await pipeline.externalCitations(volumeId: Self.volumeId,
                                                              documentId: Self.documentId)
            #expect(rows == single, "the two readers disagree about d41's citations")
        }
    }

    /// The id SwiftUI actually keys the rows on is the pointer's, not the citation's.
    @Test("Every d41 pointer — the id the Source Explorer rows are keyed on — is unique")
    func pointerIdsAreUnique() async throws {
        try await withTempDir { dir in
            let pointers = try await d41Pointers(in: dir)
            #expect(pointers.count == 5, "fixture guard: d41 carries five citations")
            let ids = pointers.map(\.id)
            #expect(Set(ids).count == ids.count, """
                Duplicate UnprintedPointer ids: \(Self.duplicates(ids)). `ForEach(unprintedPointers)` \
                draws one row per id.
                """)
        }
    }

    // MARK: Row text

    /// Every row must say something the others do not — the whole of #1390's first complaint.
    @Test("Every d41 row's text is distinct, and each starts with the printed footnote")
    func everyRowTextIsDistinct() async throws {
        try await withTempDir { dir in
            let texts = try await d41Pointers(in: dir).map(\.rowText)
            #expect(texts.map(\.title) == [
                "fn 2 · Lot 66 D 95", "fn 2 · Lot 66 D 95",
                "fn 3 · Lot 63 D 351", "fn 4 · Lot 63 D 351", "fn 5 · Lot 63 D 351",
            ])
            // Footnote 2's two rows share a title; the clause is what separates them.
            #expect(texts.count == 5, "fixture guard")
            #expect(texts.first?.clause?.contains("“Record of Actions”") == true,
                    "footnote 2's first citation must show its own clause: \(texts.first?.clause ?? "nil")")
            // Not "“NSC Record of Actions”" whole: the stored clause reads "“ NSC Record…" today,
            // because the footnote text gains a space at the `<gloss>` boundary — a harvest
            // defect this suite should not pin in either direction.
            #expect(texts.dropFirst().first?.clause?.contains("NSC Record of Actions") == true,
                    "footnote 2's second citation must show its own clause: \(texts.map(\.clause))")
            let visible = texts.map { text in
                [text.title, text.clause, text.sameLotNote].compactMap { $0 }.joined(separator: "\n")
            }
            #expect(Set(visible).count == visible.count, """
                Two rows print the same text: \(Self.duplicates(visible)). A reader cannot tell \
                them apart and will read the list as duplicated data.
                """)
            #expect(texts.map(\.spokenTitle).allSatisfy { $0.hasPrefix("Footnote ") }, """
                VoiceOver must hear "Footnote 2", not the letters of "fn": \
                \(texts.map(\.spokenTitle)).
                """)
        }
    }

    /// The source note names lot 63 D 351; the three footnotes pointing into that lot say so.
    @Test("The three rows citing the source note's own lot are marked, and only they")
    func sameLotRowsAreMarked() async throws {
        try await withTempDir { dir in
            let texts = try await d41Pointers(in: dir).map(\.rowText)
            #expect(texts.map { $0.sameLotNote != nil } == [false, false, true, true, true], """
                Only footnotes 3, 4 and 5 cite lot 63 D 351, the source note's own lot. Got \
                \(texts.map(\.sameLotNote)).
                """)
            #expect(texts.last?.sameLotNote == "Same lot as the source note")
        }
    }

    /// `noteLabel` is nil for a row written before index v53, and for the handful of notes the
    /// volume printed without a number. Either way the row may not claim one — least of all
    /// `noteOrdinal + 1`, which is the wrong number for most notes (#1322).
    @Test("A row with no recorded footnote number claims none",
          arguments: [nil, ""] as [String?])
    func unlabelledRowClaimsNoNumber(label: String?) {
        // A lot number with no 5 in it, so the ordinal-plus-one check below cannot match the lot.
        let citation = ExternalCitation(
            anchor: "lotFile", repository: "Department of State", collection: nil,
            lotFile: "64 D 199", lotFileNorm: "64D199", fileId: nil, inherited: false,
            rawText: "A copy is in S/S files, lot 64 D 199", noteOrdinal: 4,
            noteLabel: label)
        let text = SourceExplorerView.UnprintedPointer(citation: citation, record: nil,
                                                       sourceNote: nil).rowText
        #expect(text.title == "Lot 64 D 199", "got \(text.title)")
        #expect(text.spokenTitle == "Lot 64 D 199", "got \(text.spokenTitle)")
        #expect(!text.title.contains("fn") && !text.title.contains("5"),
                "the row claimed a footnote number — ordinal 4 plus one is 5: \(text.title)")
    }

    /// The clause is dropped only when it would say nothing the title has not: an empty clause, or
    /// a citation whose unit label IS its clause (no lot, no repository, no class). One fixture each.
    @Test("The clause line is dropped when empty or when it only repeats the unit")
    func clauseIsDroppedOnlyWhenRedundant() {
        func text(_ citation: ExternalCitation) -> SourceExplorerView.UnprintedPointer.RowText {
            SourceExplorerView.UnprintedPointer(citation: citation, record: nil, sourceNote: nil).rowText
        }
        let blank = ExternalCitation(
            anchor: "lotFile", repository: nil, collection: nil, lotFile: "66 D 95",
            lotFileNorm: "66D95", fileId: nil, inherited: false, rawText: "  ",
            noteOrdinal: 0, noteLabel: "2")
        #expect(text(blank).clause == nil, "a blank clause drew an empty line")

        let bare = ExternalCitation(
            anchor: "lotFile", repository: nil, collection: nil, lotFile: nil,
            lotFileNorm: nil, fileId: nil, inherited: false, rawText: "Conference Files",
            noteOrdinal: 0, noteLabel: "2")
        #expect(bare.displayLabel == "Conference Files", "fixture guard: the label IS the clause")
        #expect(text(bare).clause == nil, "the row printed its unit twice")

        let named = ExternalCitation(
            anchor: "lotFile", repository: nil, collection: nil, lotFile: "66 D 95",
            lotFileNorm: "66D95", fileId: nil, inherited: false, rawText: " files, lot 66 D 95 ",
            noteOrdinal: 0, noteLabel: "2")
        #expect(text(named).clause == "files, lot 66 D 95")
    }

    /// Every way the marker can fire or stay silent, one fixture per case. The `nil == nil` case is
    /// the trap: a library citation under a library source note has no lot on either side, and a
    /// bare equality would call it "the same lot". The d41 tests above reach the marker through a
    /// real parse; these build the parsed note directly, because the National Archives arm must
    /// fire too and a note naming both the Archives and a lot usually parses as a lot file first
    /// ("Source: National Archives, RG 59, S/S–NSC Files: Lot 63 D 351, Box 12." does).
    @Test("The same-lot marker needs a lot on both sides, and the same one",
          arguments: [
            ("63D351", .lotFile(recordGroup: "RG-59", lotNumber: "63 D 351", fileIdentifier: nil), true),
            ("64D199", .naraCollection(recordGroup: "59", series: "S/S Files", lotFile: "64 D 199",
                                       box: "3"), true),
            ("66D95", .lotFile(recordGroup: "RG-59", lotNumber: "63 D 351", fileIdentifier: nil), false),
            (nil, .presidentialLibrary(library: "Eisenhower Library", collection: "Whitman File",
                                       fileIdentifier: nil), false),
            ("63D351", .presidentialLibrary(library: "Eisenhower Library", collection: "Whitman File",
                                            fileIdentifier: nil), false),
            (nil, .lotFile(recordGroup: "RG-59", lotNumber: "63 D 351", fileIdentifier: nil), false),
            ("63D351", nil, false),
          ] as [(String?, ParsedSourceNote?, Bool)])
    func sameLotMarkerNeedsTheSameLot(citationLot: String?, sourceNote: ParsedSourceNote?,
                                      marked: Bool) {
        let citation = ExternalCitation(
            anchor: citationLot == nil ? "presidentialLibrary" : "lotFile",
            repository: citationLot == nil ? "Eisenhower Library" : "Department of State",
            collection: citationLot == nil ? "Whitman File" : nil,
            lotFile: citationLot, lotFileNorm: citationLot,
            fileId: nil, inherited: false, rawText: "a clause", noteOrdinal: 0, noteLabel: "3")
        let text = SourceExplorerView.UnprintedPointer(citation: citation, record: nil,
                                                       sourceNote: sourceNote).rowText
        #expect((text.sameLotNote != nil) == marked, """
            citation lot \(citationLot ?? "nil") under \(sourceNote.map { "\($0)" } ?? "no note"): \
            marker \(text.sameLotNote ?? "absent"), expected \(marked ? "present" : "absent")
            """)
    }

    /// The source note's lot is read from exactly the cases `document_sources.lot_file_norm` is
    /// written from (`IndexingPipeline.baseDocumentSourceRow`): a lot file, and a National Archives
    /// citation that names a lot. One fixture per arm, and the empty-lot guard.
    @Test("The source note's lot is read from the same cases the index stores it for")
    func sourceNoteLotNormFollowsTheIndex() {
        typealias Pointer = SourceExplorerView.UnprintedPointer
        #expect(Pointer.lotNorm(ofSourceNote: .lotFile(recordGroup: "RG-59", lotNumber: "63 D 351",
                                                       fileIdentifier: nil)) == "63D351")
        #expect(Pointer.lotNorm(ofSourceNote: .naraCollection(recordGroup: "59", series: nil,
                                                              lotFile: "64 D 199", box: "3")) == "64D199")
        #expect(Pointer.lotNorm(ofSourceNote: .naraCollection(recordGroup: "59", series: "Central Files",
                                                              lotFile: nil, box: nil)) == nil)
        #expect(Pointer.lotNorm(ofSourceNote: .presidentialLibrary(
            library: "Eisenhower Library", collection: "Whitman File", fileIdentifier: nil)) == nil)
        #expect(Pointer.lotNorm(ofSourceNote: nil) == nil)
        #expect(Pointer.lotNorm(ofSourceNote: .lotFile(recordGroup: nil, lotNumber: "",
                                                       fileIdentifier: nil)) == nil,
                "an empty lot must not read as a lot every lot-less citation shares")
    }

    // MARK: Footer

    /// The footer called the section "separate from the source note" while listing the source
    /// note's own lot. The claims are separate; the units need not be.
    @Test("The footer says the claims are separate, not the units")
    func footerSeparatesClaimsNotUnits() {
        let footer = SourceExplorerView.UnprintedPointer.sectionFooter
        #expect(footer.contains("separate claim"), "got: \(footer)")
        #expect(footer.contains("same unit"), "the footer must allow the two to name one unit: \(footer)")
        #expect(!footer.contains("Separate from the source note above"),
                "the sentence #1390 quotes as false is still shipping: \(footer)")
    }

    // MARK: Twin wiring (source scans)

    private static let iOSTwin = "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"
    private static let macTwin = "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"

    /// Each twin's row, by the declaration that draws it.
    private static let rowMembers = [
        iOSTwin: "private func unprintedRow(",
        macTwin: "private var unprintedBox:",
    ]

    /// Both twins draw the one function's output — the title, its spoken form, the clause and the
    /// marker — and neither reaches past it to the citation's own label, which is how the rows came
    /// to print nothing but the unit.
    @Test("Both twins draw the row text from the one shared function")
    func bothTwinsDrawTheSharedRowText() throws {
        var swept = 0
        for (path, signature) in Self.rowMembers.sorted(by: { $0.key < $1.key }) {
            let member = try Self.declaration(signature, in: Self.code(try Self.source(path)), file: path)
            #expect(member.contains("let text = pointer.rowText"),
                    "\(path): the row does not read UnprintedPointer.rowText")
            let texts = Self.calls(of: "Text", in: member)
            #expect(texts.contains("(verbatim: text.title)"),
                    "\(path): the title is not drawn from rowText — Text calls: \(texts)")
            #expect(member.contains("if let clause = text.clause") && texts.contains("(verbatim: clause)"),
                    "\(path): the clause line is not drawn — Text calls: \(texts)")
            #expect(Self.calls(of: ".accessibilityLabel", in: member).contains("(Text(verbatim: text.spokenTitle))"),
                    "\(path): VoiceOver does not hear the spoken title")
            #expect(member.contains("if let sameLot = text.sameLotNote")
                        && Self.calls(of: "Label", in: member).contains { $0.hasPrefix("(sameLot,") },
                    "\(path): the same-lot marker is not drawn")
            #expect(!member.contains("displayLabel"),
                    "\(path): the row reaches past rowText to the citation's own label")
            swept += 1
        }
        #expect(swept == 2, "the row sweep ran over \(swept) twins")
    }

    /// The marker is only as good as the note the pointer carries. Every pointer in both twins is
    /// built by the load, from the note that load parsed — never `nil`, which would compile and mark
    /// nothing — and the section footer is the one declared on the pointer type.
    @Test("Both twins build every pointer with the loaded source note, and share the footer")
    func bothTwinsCarryTheSourceNote() throws {
        var sites = 0
        for path in [Self.iOSTwin, Self.macTwin] {
            let code = Self.code(try Self.source(path))
            let loads = Self.calls(of: "loadUnprintedPointers", in: code)
            #expect(!loads.isEmpty && loads.allSatisfy { $0 == "(sourceNote: note)" },
                    "\(path): loadUnprintedPointers must be handed the parsed note — got \(loads)")
            let builds = Self.calls(of: "UnprintedPointer", in: code)
                .filter { $0.contains("citation:") }
            #expect(builds.count == 2, "\(path): expected the loader's two pointer builds, got \(builds)")
            for build in builds {
                #expect(build.contains("sourceNote: sourceNote"),
                        "\(path): a pointer is built without the loaded note: \(build)")
            }
            sites += builds.count
        }
        #expect(sites == 4, "the loader sweep found \(sites) pointer builds across both twins")

        // The footer, scoped to each twin's section: the iOS file also hosts the shared type, so a
        // file-wide search would find the one declaration this asserts both twins read.
        var sections = 0
        for (path, signature) in [(Self.iOSTwin, "private var unprintedPointersSection:"),
                                  (Self.macTwin, "private var unprintedBox:")] {
            let section = try Self.declaration(signature, in: Self.code(try Self.source(path)), file: path)
            #expect(section.contains("UnprintedPointer.sectionFooter"),
                    "\(path): the section footer is not the shared one")
            #expect(!section.contains("\"source.explorer.unprinted.footer"),
                    "\(path): declares its own footer string, which can drift from its twin's")
            sections += 1
        }
        #expect(sections == 2, "the footer sweep ran over \(sections) sections")
    }

    // MARK: Source reading

    /// The contents of a repository file, by its path from the repository root.
    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
        // A truncated or moved file would make every negative assertion pass.
        #expect(text.count > 5_000, "\(relativePath) read back as \(text.count) characters")
        return text
    }

    /// `text` with whole-line comments blanked, so a comment can neither satisfy a positive
    /// assertion nor break a negative one.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
    }

    /// The declaration beginning at `signature`, from its first brace to the brace that closes it.
    private static func declaration(_ signature: String, in source: String,
                                    file: String) throws -> String {
        let start = try #require(source.range(of: signature), "\(file): no declaration \(signature)")
        guard let brace = source[start.lowerBound...].firstIndex(of: "{"),
              let body = balanced(from: brace, open: "{", close: "}", in: source) else {
            Issue.record("\(file): unbalanced braces after \(signature)")
            return ""
        }
        return String(source[start.lowerBound..<brace]) + body
    }

    /// The argument list of every call of `name` in `scope`, in order. A call counts only when
    /// `name` is not the tail of a longer identifier, so `RichText(` is not a call of `Text`, and
    /// only when it is not the name's own `func` declaration.
    private static func calls(of name: String, in scope: String) -> [String] {
        var found: [String] = []
        var searchStart = scope.startIndex
        while let range = scope.range(of: name + "(", range: searchStart..<scope.endIndex) {
            searchStart = range.upperBound
            // A declaration is not a call: `func loadUnprintedPointers(sourceNote: …)` must not
            // count as a site handing the loader its note.
            if scope[..<range.lowerBound].hasSuffix("func ") { continue }
            if range.lowerBound > scope.startIndex, !name.hasPrefix(".") {
                let before = scope[scope.index(before: range.lowerBound)]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }
            if let list = balanced(from: scope.index(before: range.upperBound), open: "(", close: ")",
                                   in: scope) {
                found.append(list)
            }
        }
        return found
    }

    /// The text from the `open` character at `start` to the `close` that balances it, or `nil`
    /// when nothing does.
    private static func balanced(from start: String.Index, open: Character, close: Character,
                                 in scope: String) -> String? {
        var depth = 0
        var cursor = start
        while cursor < scope.endIndex {
            if scope[cursor] == open { depth += 1 }
            if scope[cursor] == close {
                depth -= 1
                if depth == 0 { return String(scope[start...cursor]) }
            }
            cursor = scope.index(after: cursor)
        }
        return nil
    }
}
