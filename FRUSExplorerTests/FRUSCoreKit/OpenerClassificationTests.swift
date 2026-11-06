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
// The package builds these as modules of their own; Xcode compiles them into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif
#if canImport(SourceNoteKit)
import SourceNoteKit
#endif

// MARK: - OpenerClassificationTests

/// The classification marking the volumes covering 1932–1954 print in a document's opener, above the
/// dateline (index version 72): the rule over a seg's lines
/// (`SourceNoteParser.classificationMarking(fromOpenerLines:)`), the walk that finds the seg
/// (`IndexingPipeline.extractOpenerClassification(from:)`), what `document_sources.classification`
/// stores, and what a search row and Source Explorer read back.
///
/// Every opener here is the corpus's own XML, copied verbatim from the volumes at corpus `6170e4b32`
/// with each document's body cut after its first paragraph. The one exception says so: no document in
/// the corpus prints a marking in both its opener and its source note, so the case that the note
/// comes first is built from a real opener and a real note of the later form.
///
/// Version history:
///   1.0 — index version 72: initial implementation
@Suite("FRUSCoreKit — the classification marking printed in the opener")
struct OpenerClassificationTests {

    // MARK: The rule over a seg's lines

    /// Lines as the corpus prints them, each with the document it comes from.
    @Test("A seg's lines read as the source notes write a marking: precedence and handling words kept after their level, joined by and, other lines set aside")
    func theRuleOverASegsLines() {
        let cases: [(lines: [String], marking: String?, source: String)] = [
            (["secret"], "Secret", "frus1952-54v13p1 d12"),
            (["top secret"], "Top Secret", "frus1952-54v13p1"),
            (["secret", "priority"], "Secret; Priority", "two lines"),
            (["secret priority"], "Secret; Priority", "one line, two phrases"),
            (["top secret", "us urgent", "niact"], "Top Secret; US Urgent; Niact", "frus1946"),
            (["secret u.s. urgent"], "Secret; U.S. Urgent", "the dotted spelling"),
            (["confidential personal", "official–informal"], "Confidential; Personal; Official–Informal",
             "frus1952-54v11p1 d95"),
            (["personal and", "most secret"], "Personal and Most Secret", "frus1941-43 d133"),
            (["personal", "and secret"], "Personal and Secret", "frus1943 d616"),
            (["most secret & personal"], "Most Secret & Personal", "frus1943CairoTehran d34"),
            (["us urgent", "restricted"], "US Urgent; Restricted", "frus1946v06 d631, printed order kept"),
            (["No. 1574", "secret"], "Secret", "frus1946v06 d216, a despatch number set aside"),
            (["[Extract]", "secret"], "Secret", "frus1949v02 d299"),
            (["top secret", "NSC 138/1"], "Top Secret", "frus1952-54v01p2 d159, a paper's symbol set aside"),
            (["Confidential", "No. 95"], "Confidential", "frus1919Parisv12 d220, before 1932"),
            // Precedence alone is no marking.
            (["us urgent"], nil, "frus1946v06 d81"),
            (["priority"], nil, "a precedence alone"),
            // A line that mixes a marking with anything else is set aside whole.
            (["[top secret]"], nil, "frus1948v06 d683, supplied in brackets"),
            (["[Confidential.]"], nil, "frus1862 d22, the bracketed form before 1932"),
            (["No. 1709, confidential.]"], nil, "frus1866p1 d59"),
            (["secret ߓ urgent"], nil, "frus1946v01 d517, a stray character"),
            (["secret priorty"], nil, "frus1949v07p1 d362, a slip"),
            (["secretariat"], nil, "a word that begins with a level"),
            ([], nil, "no lines"),
        ]
        for (lines, marking, source) in cases {
            #expect(SourceNoteParser.classificationMarking(fromOpenerLines: lines) == marking, "\(source): \(lines)")
        }
    }

    // MARK: The shown marking

    @Test("A surface shows the note's marking first, then the stored one, and nothing for a blank")
    func theShownMarking() {
        let laterNote = "Source: Department of State, Central Files, 751G.00/2–1554. Secret; Priority."
        #expect(IndexingPipeline.classificationMarking(sourceNote: laterNote, stored: "Confidential") == "Secret; Priority")
        #expect(IndexingPipeline.classificationMarking(sourceNote: "751G.00/2–152: Telegram", stored: "Secret") == "Secret")
        #expect(IndexingPipeline.classificationMarking(sourceNote: nil, stored: "Top Secret") == "Top Secret")
        #expect(IndexingPipeline.classificationMarking(sourceNote: "751G.00/2–152: Telegram", stored: nil) == nil)
        #expect(IndexingPipeline.classificationMarking(sourceNote: nil, stored: "  ") == nil)
    }

    // MARK: Real openers through the index

    /// The fixture volumes: each real volume's id, with its documents as the corpus prints them.
    static let volumes: [(id: String, documents: [String])] = [
        ("frus1952-54v13p1", [
            """
            <div frus:doc-dateTime-max="1952-01-31T21:00:00-05:00"
                frus:doc-dateTime-min="1952-01-31T21:00:00-05:00" n="12"
                subtype="historical-document" type="document" xml:id="d12">
                <note rend="inline" type="source">751G.00/2–152: Telegram</note>
                <head><hi rend="italic">The Minister at Saigon</hi> (<persName corresp="#p_HDR1"
                        type="from"><hi rend="italic">Heath</hi></persName>) <hi rend="italic"
                        >to the <gloss type="to">Department of State</gloss></hi></head>
                <opener>
                    <seg rendition="#left"><hi rend="smallcaps">secret</hi></seg>
                    <dateline rendition="#right"><placeName><hi rend="smallcaps"
                            >Saigon</hi></placeName>, <date calendar="gregorian"
                            when="1952-02-01T10:00:00+08:00">February 1, 1952—10
                        a.m.</date></dateline>
                </opener>
                <p>1515. Rptd info Paris 562. <persName corresp="#p_LJ2">Letourneau</persName>
                    gave luncheon for ranking Amers here and included Ginsberg, natl comm Jewish
                    war vets presently visiting Saigon.</p>
            </div>
            """,
        ]),
        ("frus1952-54v11p1", [
            """
            <div frus:doc-dateTime-max="1952-10-08T23:59:59-05:00"
                frus:doc-dateTime-min="1952-10-08T00:00:00-05:00" n="95"
                subtype="historical-document" type="document" xml:id="d95">
                <note rend="inline" type="source">Accra Consulate files, lot 59 F 7,
                    “350–Political Affairs”</note>
                <head><hi rend="italic">The Officer in Charge of West, Central, and East
                        Africa Affairs</hi> (<persName corresp="#p_FN1" type="from"><hi
                            rend="italic">Feld</hi></persName>) <hi rend="italic">to the
                        Consul at Accra</hi> (<persName corresp="#p_CWE1" type="to"><hi
                            rend="italic">Cole</hi></persName>)</head>
                <opener>
                    <seg rendition="#left"><hi rend="smallcaps">confidential
                            personal<lb/>official–informal</hi></seg>
                    <dateline rendition="#right"><placeName><hi rend="smallcaps"
                                >Washington</hi></placeName>, <date calendar="gregorian"
                            when="1952-10-08">October 8, 1952</date>.</dateline>
                </opener>
                <p>Dear Bill: The text of the letter is cut here.</p>
            </div>
            """,
        ]),
        ("frus1941-43", [
            """
            <div frus:doc-dateTime-max="1941-12-31T23:59:59-05:00"
                frus:doc-dateTime-min="1941-12-31T00:00:00-05:00" n="133"
                subtype="historical-document" type="document" xml:id="d133">
                <note rend="inline" type="source">Roosevelt Papers</note>
                <head>
                    <hi rend="italic">The British Ambassador</hi> (<persName
                        type="from"><hi rend="italic">Halifax</hi></persName>) <hi
                        rend="italic">to the <gloss type="to">President</gloss>
                    </hi>
                </head>
                <opener>
                    <seg rendition="#left">
                        <hi rend="smallcaps">personal and</hi>
                        <lb/>
                        <hi rend="smallcaps">most secret</hi>
                    </seg>
                    <dateline rendition="#right">
                        <placeName>
                            <hi rend="smallcaps">Washington</hi></placeName>, <date
                            calendar="gregorian" when="1941-12-31">December 31,
                            1941</date>.</dateline>
                </opener>
                <p>Dear Mr. President: The text of the letter is cut here.</p>
            </div>
            """,
            // The enclosure is marked; the document's own opener prints a dateline alone.
            """
            <div frus:doc-dateTime-max="1941-12-27T23:59:59-05:00"
                frus:doc-dateTime-min="1941-12-27T00:00:00-05:00" n="188"
                subtype="historical-document" type="document" xml:id="d188">
                <note rend="inline" type="source">Roosevelt Papers</note>
                <head><hi rend="italic">The British Minister of Supply</hi> (<persName
                        type="from"><hi rend="italic">Beaverbrook</hi></persName>) <hi
                        rend="italic">to President <persName type="to"
                            >Roosevelt</persName>
                    </hi>
                </head>
                <opener>
                    <dateline rendition="#right">
                        <placeName><hi rend="smallcaps">Washington</hi></placeName>,
                            <date calendar="gregorian" when="1941-12-27">December 27,
                            1941</date>.</dateline>
                </opener>
                <p><hi rend="smallcaps">Dear Mr. President</hi>: I am so anxious to step
                    up the production of war weapons in the United States and Britain.</p>
                <frus:attachment>
                    <opener>
                        <seg rendition="#center">[Enclosure]</seg>
                    </opener>
                    <opener>
                        <seg rendition="#left">
                            <hi rend="smallcaps">secret</hi>
                        </seg>
                        <dateline rendition="#right">
                            <date calendar="gregorian" when="1941-12-27">
                                <hi rend="smallcaps">December</hi> 27,
                            1941</date>.</dateline>
                    </opener>
                    <p>The production of weapons in the United States, Britain and
                        Canada is entirely inadequate.</p>
                </frus:attachment>
            </div>
            """,
        ]),
        ("frus1946v06", [
            """
            <div frus:doc-dateTime-max="1946-06-11T23:59:59-05:00"
                frus:doc-dateTime-min="1946-06-11T00:00:00-05:00" n="216"
                subtype="historical-document" type="document" xml:id="d216">
                <note rend="inline" type="source">864.00/6–1146</note>
                <head><hi rend="italic">The Minister in Hungary</hi> (<persName type="from"
                            ><hi rend="italic">Schoenfeld</hi></persName>) <hi rend="italic"
                        >to the <gloss type="to">Secretary of State</gloss></hi></head>
                <opener>
                    <seg rendition="#left">No. 1574 <lb/>
                        <hi rend="smallcaps">secret</hi></seg>
                    <dateline rendition="#right"><placeName><hi rend="smallcaps"
                                >Budapest</hi></placeName>, <date calendar="gregorian"
                            when="1946-06-11">June 11, 1946</date>.<lb/>[Received July
                        2.]</dateline>
                </opener>
                <p>Sir: The text of the despatch is cut here.</p>
            </div>
            """,
            """
            <div frus:doc-dateTime-max="1946-07-19T23:59:59-05:00"
                frus:doc-dateTime-min="1946-07-19T00:00:00-05:00" n="81"
                subtype="historical-document" type="document" xml:id="d81">
                <note rend="inline" type="source">874.00/7–1646: Telegram</note>
                <head><hi rend="italic">The <gloss type="from">Secretary of State</gloss> to
                        the Representative in Bulgaria</hi> (<persName type="to"><hi
                            rend="italic">Barnes</hi></persName>)</head>
                <opener>
                    <seg rendition="#left"><hi rend="smallcaps">us urgent</hi></seg>
                    <dateline rendition="#right"><placeName><hi rend="smallcaps"
                                >Washington</hi></placeName>, <date calendar="gregorian"
                            when="1946-07-19">July 19, 1946</date>.</dateline>
                </opener>
                <p>The text of the telegram is cut here.</p>
            </div>
            """,
        ]),
        ("frus1948v01p2", [
            // No source note: the inline note carries no `type="source"`, so the document has no
            // `document_sources` row, and its opener's marking is not stored.
            """
            <div frus:doc-dateTime-max="1948-02-11T23:59:59-05:00"
                frus:doc-dateTime-min="1948-02-11T00:00:00-05:00" n="187"
                subtype="historical-document" type="document" xml:id="d187">
                <note rend="inline">International Trade Files, Lot 57D284, Box 108<note n="1"
                        xml:id="d187fn1">Folder “First Session <gloss target="#t_GATT1"
                            >GATT</gloss>: Agenda and Position Papers”.</note>
                </note>
                <head>
                    <hi rend="italic">United States Delegation Position Paper</hi> (<hi
                        rend="italic">First Session of the Contracting Parties</hi>)</head>
                <opener>
                    <seg rendition="#left">
                        <hi rend="smallcaps">secret</hi>
                    </seg>
                    <dateline rendition="#right">[<placeName><hi rend="smallcaps"
                                >Washington</hi></placeName>,] <date calendar="gregorian"
                            when="1948-02-11">February 11, 1948</date>.</dateline>
                </opener>
                <p>The text of the paper is cut here.</p>
            </div>
            """,
        ]),
        // NOT a corpus document: the corpus has none with a marking in both places. Its opener is
        // frus1952-54v13p1 d12's with `confidential`, its note the later form's.
        ("frus1955-57v99", [
            """
            <div n="1" subtype="historical-document" type="document" xml:id="d1">
                <head>1. Telegram From the Embassy in Saigon to the Department of State<note n="1"
                        type="source" xml:id="d1fn1">Source: Department of State, Central Files,
                        751G.00/2–1555. Secret; Nodis.</note></head>
                <opener>
                    <seg rendition="#left"><hi rend="smallcaps">confidential</hi></seg>
                    <dateline rendition="#right"><placeName><hi rend="smallcaps"
                            >Saigon</hi></placeName>, February 15, 1955.</dateline>
                </opener>
                <p>The text of the telegram is cut here.</p>
            </div>
            """,
        ]),
    ]

    /// Writes each fixture volume and indexes it.
    private static func indexFixture(in dir: URL) async throws -> (IndexingPipeline, FTS5Store) {
        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        let volumesDirectory = dir.appendingPathComponent("volumes")
        for volume in volumes {
            let xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
                  <teiHeader><fileDesc><titleStmt><title>\(volume.id)</title></titleStmt>
                  <publicationStmt><date>1990</date></publicationStmt>
                  <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
                  <text><body><div type="compilation" xml:id="comp1">
                  \(volume.documents.joined(separator: "\n"))
                  </div></body></text>
                </TEI>
                """
            try Data(xml.utf8).write(to: volumesDirectory.appendingPathComponent("\(volume.id).xml"))
            try await pipeline.indexVolume(volume.id)
        }
        return (pipeline, store)
    }

    @Test("The index stores the opener's marking where the note prints none, the note's where it prints one, and nothing for a precedence alone, an enclosure's marking or a document with no source row")
    func theIndexStoresTheOpenersMarking() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSOpenerClassification-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await Self.indexFixture(in: dir)

        let expected: [(volume: String, document: String, marking: String?)] = [
            ("frus1952-54v13p1", "d12", "Secret"),
            ("frus1952-54v11p1", "d95", "Confidential; Personal; Official–Informal"),
            ("frus1941-43", "d133", "Personal and Most Secret"),
            ("frus1946v06", "d216", "Secret"),
            ("frus1946v06", "d81", nil),
            ("frus1941-43", "d188", nil),
            ("frus1948v01p2", "d187", nil),
            ("frus1955-57v99", "d1", "Secret; Nodis"),
        ]
        for (volume, document, marking) in expected {
            #expect(try await pipeline.storedClassification(volumeId: volume, documentId: document) == marking,
                    "\(volume) \(document)")
        }
        // The notes the index stores: d12's, which prints no marking, and none for d187, which is why
        // d187 has no source row to hold its opener's marking.
        #expect(try await pipeline.fetchDocumentSourceNote(volumeId: "frus1952-54v13p1", documentId: "d12")
                == "751G.00/2–152: Telegram")
        #expect(try await pipeline.fetchDocumentSourceNote(volumeId: "frus1948v01p2", documentId: "d187") == nil)
        #expect(try await pipeline.storedClassification(volumeId: "frus1952-54v13p1", documentId: "d999") == nil)
    }

    @Test("The walk reads the opener's own seg, split at every line break, and never the dateline or an enclosure's opener")
    func theWalkReadsTheOpenersOwnSeg() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSOpenerClassificationWalk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let parser = FRUSDocumentParser()
        func nodes(_ volume: String, _ document: String) async throws -> [FRUSASTNode] {
            let fixture = try #require(Self.volumes.first { $0.id == volume })
            let div = try #require(fixture.documents.first { $0.contains("xml:id=\"\(document)\"") })
            let xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
                <text><body><div type="compilation" xml:id="comp1">\(div)</div></body></text></TEI>
                """
            let url = dir.appendingPathComponent("\(volume)-\(document).xml")
            try Data(xml.utf8).write(to: url)
            let parsed = try await parser.parse(volumeURL: url)
            return try #require(parsed.first { $0.documentId == document }).nodes
        }
        let d95 = try await nodes("frus1952-54v11p1", "d95")
        let opener = try #require(d95.compactMap { node -> [FRUSASTNode]? in
            if case .opener(let children) = node { return children }
            return nil
        }.first)
        let seg = try #require(opener.compactMap { node -> [FRUSASTNode]? in
            if case .unknown(let name, _, let children) = node, name == "seg" { return children }
            return nil
        }.first)
        // The `<lb/>` inside `<hi>` splits the line, as one between two `<hi>`s does.
        #expect(IndexingPipeline.openerSegLines(seg) == ["confidential personal", "official–informal"])
        #expect(IndexingPipeline.extractOpenerClassification(from: d95) == "Confidential; Personal; Official–Informal")
        // A dateline alone, its place in small capitals, and an enclosure's marked opener: nothing.
        #expect(IndexingPipeline.extractOpenerClassification(from: try await nodes("frus1941-43", "d188")) == nil)
        #expect(IndexingPipeline.extractOpenerClassification(from: try await nodes("frus1946v06", "d216")) == "Secret")
    }

    @Test("A search row, a Meaning row and a filter-only row carry the stored marking, and the row shows it")
    func searchRowsCarryTheStoredMarking() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSOpenerClassificationSearch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, store) = try await Self.indexFixture(in: dir)
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        // A keyword search: d12 prints "Letourneau", and its note prints no marking.
        let results = try await service.search(parameters: SearchParameters(keywords: "Letourneau"))
        let d12 = try #require(results.first { $0.volumeId == "frus1952-54v13p1" && $0.documentId == "d12" })
        #expect(d12.indexedClassification == "Secret")
        #expect(d12.classificationMarking == "Secret")
        // The note's marking comes first where the note prints one.
        let telegrams = try await service.search(parameters: SearchParameters(keywords: "Saigon"))
        let later = try #require(telegrams.first { $0.volumeId == "frus1955-57v99" })
        #expect(later.classificationMarking == "Secret; Nodis")
        // A precedence alone shows nothing.
        let bulgaria = try await service.search(parameters: SearchParameters(keywords: "Barnes"))
        let d81 = try #require(bulgaria.first { $0.documentId == "d81" })
        #expect(d81.indexedClassification == nil)
        #expect(d81.classificationMarking == nil)

        // A Meaning search's rows, looked up by key.
        let rows = try await service.semanticResultRows(forKeys: [
            (volumeId: "frus1941-43", documentId: "d133"), (volumeId: "frus1941-43", documentId: "d188"),
        ])
        #expect(rows["frus1941-43/d133"]?.classification == "Personal and Most Secret")
        #expect(rows["frus1941-43/d188"] != nil)
        #expect(rows["frus1941-43/d188"]?.classification == nil)

        // The filter-only path, which a volume scope alone with no words takes.
        var filters = SearchSQLFilters()
        filters.volumeIds = ["frus1946v06"]
        let scoped = try await pipeline.searchDocuments(corpusMatch: nil, userContentMatch: nil, filters: filters,
                                                        limit: 10, offset: 0)
        #expect(scoped.first { $0.documentId == "d216" }?.classification == "Secret")
        #expect(scoped.contains { $0.documentId == "d81" })
    }
}
