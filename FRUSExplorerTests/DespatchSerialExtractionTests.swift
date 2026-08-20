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

// MARK: - DespatchSerialExtractionTests

/// Pins `IndexingPipeline.extractDespatchSerial` — the wiring between #965's grammar and the
/// `document_cache.despatch_serial` column.
///
/// ## Why this suite exists separately from the grammar's own
/// `DespatchSerialGrammarTests` proves that `"No. 74.]"` reads as serial 74. It says nothing about
/// whether anything ever *hands* that string to the grammar. This suite parses real TEI through
/// `FRUSDocumentParser` and drives the real extractor over the resulting AST, so a green grammar
/// suite plus a broken traversal cannot both pass — the mirrored-test failure this repo has been
/// bitten by before.
///
/// It matters more than usual here because the column costs a full re-index (v44 → v45). Shipping
/// that on the strength of a grammar unit test would be asking every tester to rebuild their index
/// for a value nothing had been shown to write.
///
/// ## The traversal facts being pinned
/// `<seg>` is **not** a first-class AST node — the parser preserves it as `.unknown("seg", …)`, the
/// same route `segSourceText` takes for source notes. No TEI parser change was needed for #965,
/// and this suite is what would notice if that ever stopped being true.
///
/// Version history:
///   1.0 — Session 2026-08-20: #965
@Suite("Pre-1906 serial extraction")
struct DespatchSerialExtractionTests {

    /// Parses a document body through the real parser and returns its AST nodes.
    private func nodes(body: String) async throws -> [FRUSASTNode] {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text><body>\(body)</body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-serial-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        return try #require(docs.first?.nodes, "the fixture must parse to one document")
    }

    private func serial(body: String) async throws -> String? {
        IndexingPipeline.extractDespatchSerial(from: try await nodes(body: body))
    }

    // MARK: - The wiring

    @Test("A printed serial reaches the extractor through the real parser")
    func serialIsExtractedFromParsedTEI() async throws {
        let found = try await serial(body: """
        <div type="document" n="12" xml:id="d12">
          <head>1. Letter From the Minister</head>
          <seg rendition="#left">No. 74.]</seg>
          <p>Sir: I have the honor to report…</p>
        </div>
        """)
        #expect(found == "74", """
            The grammar reads "No. 74.]" in isolation; this proves the AST traversal actually \
            hands it over. A green grammar suite with a broken traversal is the failure this \
            suite exists to catch.
            """)
    }

    /// The qualifier is stored because a bare serial is ambiguous where a post kept several
    /// sequences — a "4" in the Greek Series is a different despatch from a "4" in the main one.
    @Test("A series qualifier is carried into the stored value")
    func qualifierIsStored() async throws {
        let found = try await serial(body: """
        <div type="document" n="3" xml:id="d3">
          <seg rendition="#left">No. 4, Greek Series.]</seg>
          <p>Text.</p>
        </div>
        """)
        #expect(found == "4 (Greek Series)")
    }

    @Test("A half-step fraction survives the round trip to a stored string")
    func halfStepSurvives() async throws {
        let found = try await serial(body: """
        <div type="document" n="9" xml:id="d9">
          <seg rendition="#left">No. 25½.]</seg>
          <p>Text.</p>
        </div>
        """)
        #expect(found == "25½", "dropping the fraction would merge two distinct despatches")
    }

    // MARK: - What must NOT be extracted

    /// The defect the grammar's whole-segment rule prevents, proven end to end: a document whose
    /// only `<seg>` is an enclosure marker must store NO serial, not the parent despatch's.
    @Test("A document carrying only an inclosure marker stores no serial")
    func inclosureMarkerYieldsNothing() async throws {
        let found = try await serial(body: """
        <div type="document" n="13" xml:id="d13">
          <head>13. Enclosure</head>
          <seg rendition="#left">[Inclosure 1 in No. 74.]</seg>
          <p>Text of the enclosure.</p>
        </div>
        """)
        #expect(found == nil, """
            The document stored serial 74, which belongs to the despatch this enclosure travelled \
            in. 17,078 such markers exist corpus-wide.
            """)
    }

    @Test("The other bracketed markers yield nothing")
    func otherMarkersYieldNothing() async throws {
        for marker in ["[Translation.]", "[Telegram.]", "[Extract.]"] {
            let found = try await serial(body: """
            <div type="document" n="1" xml:id="d1">
              <seg rendition="#left">\(marker)</seg>
              <p>Text.</p>
            </div>
            """)
            #expect(found == nil, "\(marker) is not a serial")
        }
    }

    /// The overwhelming majority of the corpus — post-1906 documents print no serial at all, and
    /// the extractor must return nil rather than reaching for something else on the page.
    @Test("A document with no seg at all yields nil")
    func noSegYieldsNil() async throws {
        let found = try await serial(body: """
        <div type="document" n="1" xml:id="d1">
          <head>1. Telegram</head>
          <p>No. 74 appears in the prose here, which is not a printed serial.</p>
        </div>
        """)
        #expect(found == nil, "prose containing a number must not be mistaken for a printed serial")
    }

    /// **A real shape, not a hypothetical.** Measured over the pre-1906 corpus, 44 of 28,107
    /// serial-bearing segments sit inside a `<p>`/`<list>`/`<item>` wrapper rather than directly
    /// under the document div. Without this fixture the recursion in `extractDespatchSerial` is
    /// unfalsifiable — a mutation removing it SURVIVED, because every other fixture here puts the
    /// segment at the top level.
    @Test("A serial nested inside a paragraph wrapper is still found")
    func nestedSerialIsFound() async throws {
        let found = try await serial(body: """
        <div type="document" n="7" xml:id="d7">
          <head>7. Despatch</head>
          <p><seg rendition="#left">No. 31.]</seg></p>
          <p>Sir: …</p>
        </div>
        """)
        #expect(found == "31", "44 real documents wrap the serial; dropping the recursion loses them")
    }

    // MARK: - Order

    /// A document prints its own serial above the text and carries its enclosures' markers below.
    /// Taking the first ACCEPTED segment gets the document's own; the enclosure marker is refused
    /// by the grammar rather than by position, so the order and the refusal are independent.
    @Test("The document's own serial wins over an enclosure marker further down")
    func ownSerialWinsOverLaterEnclosure() async throws {
        let found = try await serial(body: """
        <div type="document" n="20" xml:id="d20">
          <seg rendition="#left">No. 86.]</seg>
          <p>Sir: I transmit herewith…</p>
          <seg rendition="#left">[Inclosure 1 in No. 86.]</seg>
          <p>Enclosed text.</p>
        </div>
        """)
        #expect(found == "86")
    }

    // MARK: - The column, end to end

    /// Indexes a fixture volume through the real pipeline and reads the value back out of
    /// `document_cache.despatch_serial`.
    ///
    /// **This is the test that justifies the re-index.** Every other case here calls
    /// `extractDespatchSerial` directly, which leaves the row construction, the UPSERT column list,
    /// the bind index and the migration entirely unexercised — a mutation that simply never
    /// populated the column SURVIVED the whole suite until this existed. That is the mirrored-test
    /// failure this repo keeps producing, and it would have shipped a column that costs every
    /// tester a full rebuild and was always NULL.
    @Test("The serial survives indexing and comes back out of document_cache")
    func serialRoundTripsThroughTheDatabase() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSerial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

        // Shaped like `UserTagCountTests.makeFixture`, one div per block. (The packed-onto-one-line
        // form indexed fine too — the "only d0 appeared" symptom was the dictionary bug below, not
        // the XML. Kept in this shape because it reads better beside its sibling suites.)
        var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
        let bodies = [
            ("d0", "<seg rendition=\"#left\">No. 74.]</seg>\n  <p>Sir: I have the honor to report.</p>"),
            ("d1", "<seg rendition=\"#left\">[Inclosure 1 in No. 74.]</seg>\n  <p>The enclosed memorandum follows.</p>"),
            ("d2", "<p>This document prints no serial at all in its body.</p>"),
        ]
        for (index, entry) in bodies.enumerated() {
            xml += """
            <div type="document" xml:id="\(entry.0)">
              <head>\(index + 1). Item</head>
              \(entry.1)
            </div>

            """
        }
        xml += "</body></text></TEI>"
        try xml.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")

        var handle: OpaquePointer?
        #expect(sqlite3_open(dbURL.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        var stmt: OpaquePointer?
        #expect(sqlite3_prepare_v2(handle,
            "SELECT document_id, despatch_serial FROM document_cache WHERE volume_id = 'vol1' ORDER BY document_id",
            -1, &stmt, nil) == SQLITE_OK, "the column must exist — the migration is part of this")
        defer { sqlite3_finalize(stmt) }

        var stored: [String: String?] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let did = String(cString: sqlite3_column_text(stmt, 0))
            let raw = sqlite3_column_text(stmt, 1)
            // `updateValue`, NOT `stored[did] = …`. For a `[String: String?]`, assigning a nil
            // value through the subscript REMOVES the key rather than storing "present but NULL".
            // That cost a debugging round: `d1` and `d2` were in the table with NULL exactly as
            // intended, and the dictionary silently dropped them, so the test reported one row and
            // I briefly blamed the fixture's XML.
            stored.updateValue(raw.map { String(cString: $0) }, forKey: did)
        }
        #expect(stored.count == 3, "fixture guard: all three documents must be indexed — got \(stored)")
        #expect(stored["d0"] == "74", "the printed serial must reach the column")
        #expect(stored["d1"] == .some(nil),
                "the enclosure marker names another document's serial and must store NULL")
        #expect(stored["d2"] == .some(nil), "a document with no serial stores NULL, not an empty string")
    }
}
