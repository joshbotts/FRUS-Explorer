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