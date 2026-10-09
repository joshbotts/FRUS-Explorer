// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - GlossaryAssemblyTests

/// Grouping, counting and ranking corpus-wide glossary results (#265).
///
/// The SQL hands back one row per glossary entry; everything the sheet prints is worked out from
/// those rows afterwards, so `assemble` is pure and this suite drives it with no database.
/// `GlossaryLookupIndexTests` below runs the lookup itself over an index.
///
/// Version history:
///   1.0 — Session 2026-08-10: #265 (F-11)
///   1.1 — Session 2026-10-09: #1582 — a row is one volume's entry, where it was a wording with a
///          count; the two volume-count fixtures replace `volumeCountDoesNotDoubleCount`, which
///          pinned the widest wording's count; whitespace and the query filter
@Suite("Glossary assembly (#265)")
struct GlossaryAssemblyTests {

    private typealias Row = (term: String, definition: String, volume: String)

    private func assemble(_ rows: [Row], query: String = "", limit: Int = 60) -> [GlossaryEntry] {
        IndexingPipeline.assemble(rows: rows, query: query, limit: limit)
    }

    /// `term` defined as `definition` by `count` volumes, named `prefix1`, `prefix2`, ….
    private func rows(_ term: String, _ definition: String, in count: Int, prefix: String) -> [Row] {
        (1...count).map { (term, definition, "\(prefix)\($0)") }
    }

    @Test("A term's competing definitions are all carried, most used first")
    func variantsAreCarried() {
        // The shape of the real data: `EUR` has 16 distinct definitions across 231 volumes.
        // Showing one would pick an editor's wording and hide the rest.
        let entries = assemble(
            rows("EUR", "European Affairs", in: 2, prefix: "b")
                + rows("EUR", "Bureau of European Affairs", in: 4, prefix: "a")
                + rows("EUR", "Office of European Regional Affairs", in: 1, prefix: "c"))
        #expect(entries.count == 1)
        let eur = entries[0]
        #expect(eur.variants.map(\.definition) == ["Bureau of European Affairs", "European Affairs",
                                                   "Office of European Regional Affairs"])
        #expect(eur.variants.map(\.volumeCount) == [4, 2, 1])
        #expect(eur.variants.map(\.sampleVolumeId) == ["a1", "b1", "c1"])
        #expect(eur.isContested, "three wordings is exactly the case a single answer would hide")
    }

    @Test("A term defined one way is not contested")
    func singleDefinition() {
        let entries = assemble(rows("NATO", "North Atlantic Treaty Organization", in: 5, prefix: "v"))
        #expect(entries[0].isContested == false)
        #expect(entries[0].volumeCount == 5)
    }

    @Test("An exact match outranks a longer term that merely starts the same")
    func exactBeatsPrefix() {
        // Someone typing "NSC" wants NSC, not "NSC Action No." above it — even though the latter
        // is defined in more volumes.
        let entries = assemble(
            rows("NSC Action No.", "Numbered NSC decision", in: 5, prefix: "a")
                + rows("NSC", "National Security Council", in: 2, prefix: "b"),
            query: "NSC")
        #expect(entries.map(\.term) == ["NSC", "NSC Action No."], "got \(entries.map(\.term))")
    }

    @Test("A prefix match outranks a mid-word match")
    func prefixBeatsContains() {
        let entries = assemble(
            rows("USNSC", "contains it mid-word", in: 5, prefix: "a")
                + rows("NSCX", "starts with it", in: 2, prefix: "b"),
            query: "NSC")
        #expect(entries.map(\.term) == ["NSCX", "USNSC"])
    }

    @Test("Within a rank, breadth wins")
    func breadthBreaksTies() {
        // No frequency data exists in a glossary, so the number of volumes defining a term is the
        // best available proxy for "this is the one you meant". The names sort the other way.
        let entries = assemble(
            rows("AIDA", "an opera", in: 2, prefix: "a")
                + rows("AIDE", "aide-mémoire", in: 5, prefix: "b"),
            query: "AID")
        #expect(entries.map(\.term) == ["AIDE", "AIDA"])
    }

    @Test("An empty query returns the most widely defined terms")
    func emptyQueryRanksByBreadth() {
        // This is what makes the surface useful before the user has typed anything. The names
        // sort the other way.
        let entries = assemble(
            rows("AAA", "seldom defined", in: 1, prefix: "a")
                + rows("JCS", "Joint Chiefs of Staff", in: 4, prefix: "b"))
        #expect(entries.map(\.term) == ["JCS", "AAA"])
    }

    @Test("A volume that gives two wordings of a term is counted once (#1582)")
    func aVolumeWithTwoWordingsIsCountedOnce() {
        // v2's glossary gives both wordings. Three volumes define the term: the sum of the two
        // wordings' counts is 4, the widest wording's is 2, and there are 2 wordings.
        let entries = assemble([
            ("EUR", "A", "v1"), ("EUR", "A", "v2"),
            ("EUR", "B", "v2"), ("EUR", "B", "v3"),
        ])
        #expect(entries.map(\.volumeCount) == [3], "got \(entries.map(\.volumeCount))")
        #expect(entries[0].variants.map(\.volumeCount) == [2, 2])
    }

    @Test("Wordings that sit in different volumes add up (#1582)")
    func wordingsInDifferentVolumesAddUp() {
        // The case the widest wording undercounts, which is most of them: `EUR` read 82 where 231
        // volumes define it. Five volumes here; the widest wording has 3, and there are 2 wordings.
        let entries = assemble(rows("EUR", "A", in: 3, prefix: "a") + rows("EUR", "B", in: 2, prefix: "b"))
        #expect(entries.map(\.volumeCount) == [5], "got \(entries.map(\.volumeCount))")
    }

    @Test("The same entry given twice counts once (#1582)")
    func aRepeatedRowCountsOnce() {
        let entries = assemble([("EUR", "A", "v1"), ("EUR", "A", "v1"), ("EUR", "A", "v2")])
        #expect(entries.map(\.volumeCount) == [2])
        #expect(entries[0].variants.map(\.volumeCount) == [2])
    }

    @Test("Terms are ranked by the volumes that define them, not by their widest wording (#1582)")
    func rankingUsesTheVolumeCount() {
        // SPREAD is defined by six volumes, three to each of two wordings; NARROW by four volumes
        // in one wording. The figure the list was ranked by until #1582, the larger of the widest
        // wording's count and the number of wordings, is 3 for SPREAD and 4 for NARROW, and the
        // names sort NARROW first too.
        let entries = assemble(
            rows("NARROW", "one wording", in: 4, prefix: "n")
                + rows("SPREAD", "first wording", in: 3, prefix: "a")
                + rows("SPREAD", "second wording", in: 3, prefix: "b"))
        #expect(entries.map(\.term) == ["SPREAD", "NARROW"])
        #expect(entries.map(\.volumeCount) == [6, 4])
    }

    @Test("A wording the source wraps at another word is the same wording (#1582)")
    func sourceLineBreaksAreFolded() {
        // The terms parser keeps the TEI file's line break and indentation inside a definition.
        let entries = assemble([
            ("EUR", "Bureau\n                                of European Affairs", "v1"),
            ("EUR", "Bureau of European\n\t  Affairs", "v2"),
            ("EUR", "Bureau of European Affairs", "v3"),
        ])
        #expect(entries.count == 1)
        #expect(entries[0].variants.map(\.definition) == ["Bureau of European Affairs"])
        #expect(entries[0].variants.map(\.volumeCount) == [3])
        #expect(entries[0].isContested == false)
    }

    @Test("A term the source wraps is one term, found by its words (#1582)")
    func aWrappedTermIsFoundByItsWords() {
        let entries = assemble([
            ("113\n                                    Committee", "an interagency group", "v1"),
            ("113 Committee", "an interagency group", "v2"),
            ("113th Congress Committee", "holds both words, not the phrase", "v3"),
        ], query: "113  committee")
        #expect(entries.map(\.term) == ["113 Committee"])
        #expect(entries.map(\.volumeCount) == [2])
    }

    @Test("A no-break space is the editors', and is not folded")
    func noBreakSpaceIsKept() {
        let entries = assemble([("NSC", "Action No.\u{00A0}5", "v1"), ("NSC", "Action No. 5", "v2")])
        #expect(entries[0].variants.count == 2)
    }

    @Test("Rows with no term or no definition are dropped, not shown blank")
    func emptyRowsDropped() {
        let entries = assemble([
            ("", "orphan definition", "v1"),
            ("TERM", "", "v2"),
            ("BLANK", " \n\t ", "v3"),
            ("REAL", "a real definition", "v4"),
        ])
        #expect(entries.map(\.term) == ["REAL"])
    }

    @Test("The limit is honoured")
    func limitApplies() {
        let rows: [Row] = (1...100).map { ("T\($0)", "d", "v") }
        #expect(assemble(rows, limit: 10).count == 10)
    }
}

// MARK: - GlossaryLookupIndexTests

/// `IndexingPipeline.glossaryLookup(query:limit:)` over an index it built (#1582).
///
/// `GlossaryAssemblyTests` hands `assemble` its rows. This suite is what reads them: three small
/// volumes are indexed and the lookup's own SQL runs, so the columns it selects, the order it
/// binds them in and the pattern it builds from the query are the shipped ones.
///
/// Version history:
///   1.0 — Session 2026-10-09: #1582
@Suite("Glossary lookup over an index (#1582)")
struct GlossaryLookupIndexTests {

    /// Writes a volume whose glossary holds `items`, each an `<item>` as the TEI source gives it.
    private func writeVolume(_ volumeId: String, items: [String], in volumes: URL) throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
              <publicationStmt><date>1970</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text>
                <front>
                  <div type="section" subtype="index" xml:id="terms"><head>Abbreviations and Terms</head>
                    <list>
                      \(items.joined(separator: "\n"))
                    </list>
                  </div>
                </front>
                <body><div type="compilation" xml:id="comp1">
                  <div type="document" xml:id="d1" n="1"><head>1. Memorandum</head><p>Text.</p></div>
                </div></body>
              </text>
            </TEI>
            """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
    }

    /// Indexes three volumes and runs `body` on the pipeline.
    ///
    /// - `frus1970v01` wraps both `EUR`'s definition and the term `113 Committee` across lines.
    /// - `frus1970v02` gives two wordings of `EUR`.
    /// - `frus1970v03` gives the second of them.
    ///
    /// So three volumes define `EUR` in two wordings of two volumes each: the sum is 4, the widest
    /// is 2 and there are 2 wordings.
    private func withIndex<T>(_ body: (IndexingPipeline) async throws -> T) async throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSGlossary-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeVolume("frus1970v01", items: [
            "<item><term xml:id=\"t_EUR1\">EUR</term>, Bureau\n                        of European Affairs</item>",
            "<item><term xml:id=\"t_113C1\">113\n                        Committee</term>, an interagency group</item>",
            "<item><term xml:id=\"t_NSC1\">NSC</term>, National Security Council</item>",
        ], in: volumes)
        try writeVolume("frus1970v02", items: [
            "<item><term xml:id=\"t_EUR1\">EUR</term>, Bureau of European Affairs</item>",
            "<item><term xml:id=\"t_EUR2\">EUR</term>, Office of European Affairs</item>",
            "<item><term xml:id=\"t_NSC1\">NSC</term>, National Security Council</item>",
        ], in: volumes)
        try writeVolume("frus1970v03", items: [
            "<item><term xml:id=\"t_EUR1\">EUR</term>, Office of European Affairs</item>",
            "<item><term xml:id=\"t_EURATOM1\">EURATOM</term>, European Atomic Energy Community</item>",
        ], in: volumes)
        let database = dir.appendingPathComponent("frus.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: database),
                                            databaseURL: database, volumesDirectory: volumes,
                                            resources: .none, defaults: InMemoryIndexingStampStore())
        for volume in ["frus1970v01", "frus1970v02", "frus1970v03"] {
            try await pipeline.indexVolume(volume)
        }
        return try await body(pipeline)
    }

    @Test("The opening list counts each term's volumes once and ranks by that count")
    func theOpeningListCountsVolumes() async throws {
        try await withIndex { pipeline in
            let entries = try await pipeline.glossaryLookup(query: "")
            #expect(entries.map(\.term) == ["EUR", "NSC", "113 Committee", "EURATOM"],
                    "got \(entries.map(\.term))")
            #expect(entries.map(\.volumeCount) == [3, 2, 1, 1], "got \(entries.map(\.volumeCount))")
            let eur = try #require(entries.first)
            #expect(eur.variants.map(\.definition) == ["Bureau of European Affairs",
                                                       "Office of European Affairs"])
            #expect(eur.variants.map(\.volumeCount) == [2, 2])
            #expect(eur.variants.map(\.sampleVolumeId) == ["frus1970v01", "frus1970v02"])
        }
    }

    @Test("A typed term is matched without case, exact first, and other terms are left out")
    func aTypedTermIsMatched() async throws {
        try await withIndex { pipeline in
            let entries = try await pipeline.glossaryLookup(query: "eur")
            #expect(entries.map(\.term) == ["EUR", "EURATOM"], "got \(entries.map(\.term))")
            #expect(entries.map(\.volumeCount) == [3, 1])
        }
    }

    @Test("A term the source wraps is found by typing its words with a space")
    func aWrappedTermIsFound() async throws {
        try await withIndex { pipeline in
            let entries = try await pipeline.glossaryLookup(query: "113 committee")
            #expect(entries.map(\.term) == ["113 Committee"], "got \(entries.map(\.term))")
        }
    }

    @Test("A wildcard the reader types is searched for, not interpreted")
    func aTypedWildcardMatchesNothing() async throws {
        try await withIndex { pipeline in
            // `_` would match the U of EUR, and `%` every term.
            let underscore = try await pipeline.glossaryLookup(query: "E_R")
            #expect(underscore.isEmpty, "got \(underscore.map(\.term))")
            let percent = try await pipeline.glossaryLookup(query: "%")
            #expect(percent.isEmpty, "got \(percent.map(\.term))")
        }
    }
}

// MARK: - GlossaryEscapeTests

/// LIKE-wildcard handling (#265).
///
/// Version history:
///   1.0 — Session 2026-08-10: #265 (F-11)
@Suite("Glossary LIKE escaping (#265)")
struct GlossaryEscapeTests {

    @Test("Wildcards a user types are searched for, not interpreted")
    func escapesWildcards() {
        // `S/S_` and `100%` are plausible things to type into a glossary box. Unescaped, `_`
        // matches any character and `%` matches everything, so the search silently returns the
        // wrong set rather than nothing — the worse failure, because it looks like an answer.
        #expect(IndexingPipeline.escapeLike("100%") == #"100\%"#)
        #expect(IndexingPipeline.escapeLike("S_S") == #"S\_S"#)
        #expect(IndexingPipeline.escapeLike(#"a\b"#) == #"a\\b"#)
        #expect(IndexingPipeline.escapeLike("NSC") == "NSC", "ordinary text is untouched")
    }
}
