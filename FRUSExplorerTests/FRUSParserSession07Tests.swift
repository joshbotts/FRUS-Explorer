// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - Helpers

private func makeTEIFixture(body: String) throws -> URL {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
        <publicationStmt><p/></publicationStmt>
        <sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
      <text><body>\(body)</body></text>
    </TEI>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-s07-\(UUID().uuidString).xml")
    try xml.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func makeVolumeFixture(body: String, front: String = "") throws -> URL {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
        <publicationStmt><p/></publicationStmt>
        <sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
      <text>
        <front>\(front)</front>
        <body>\(body)</body>
      </text>
    </TEI>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-vol-\(UUID().uuidString).xml")
    try xml.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func containsCase(in nodes: [FRUSASTNode],
                           where predicate: (FRUSASTNode) -> Bool) -> Bool {
    for node in nodes {
        if predicate(node) { return true }
        let children: [FRUSASTNode]
        switch node {
        case .document(_, _, let c), .head(let c), .dateline(let c),
             .opener(let c), .closer(let c), .salute(let c), .paragraph(let c),
             .footnote(_, _, _, let c), .persName(_, let c), .gloss(_, let c),
             .crossReference(_, _, let c), .emphasis(_, let c), .term(let c),
             .supplied(let c), .sic(let c), .corr(let c),
             .editorialNote(let c), .titlePage(let c), .figure(_, let c),
             .unknown(_, _, let c), .attachment(_, let c):
            children = c
        case .date(_, _, _, _, _, let c):
            children = c
        case .table(let c), .tableRow(let c), .listItem(let c):
            children = c
        case .tableCell(_, _, let c):
            children = c
        case .list(_, let c):
            children = c
        case .text, .lineBreak, .pageBreak, .formula, .elementSpace:
            children = []
        }
        if containsCase(in: children, where: predicate) { return true }
    }
    return false
}

// MARK: - Page Break Tests

@Suite("Page Break Parsing")
struct PageBreakTests {

    @Test("PageNumber: arabic numeral parsed correctly")
    func pageBreakArabic() {
        #expect(PageNumber.parse("47") == .arabic(47))
    }

    @Test("PageNumber: arabic with leading zeros stripped")
    func pageBreakArabicLeadingZeros() {
        #expect(PageNumber.parse("007") == .arabic(7))
    }

    @Test("PageNumber: roman numeral iv parsed correctly")
    func pageBreakRoman() {
        #expect(PageNumber.parse("iv") == .roman(4))
    }

    @Test("PageNumber: roman numeral xlii parsed correctly")
    func pageBreakRomanLarger() {
        #expect(PageNumber.parse("xlii") == .roman(42))
    }

    @Test("PageNumber: prefixed form A-12 preserved")
    func pageBreakPrefixed() {
        #expect(PageNumber.parse("A-12") == .prefixed("A-12"))
    }

    @Test("PageNumber: bracketed roman numeral [X] parsed as roman(10)")
    func pageBreakBracketedRoman() {
        #expect(PageNumber.parse("[X]") == .roman(10))
        #expect(PageNumber.parse("[XII]") == .roman(12))
        #expect(PageNumber.parse("[XVI]") == .roman(16))
        #expect(PageNumber.parse("[XX]") == .roman(20))
        #expect(PageNumber.parse("[XXVI]") == .roman(26))
    }

    @Test("PageNumber: unparseable value preserved, no crash")
    func pageBreakUnparseable() {
        #expect(PageNumber.parse("??") == .unparseable("??"))
    }

    @Test("Parser: <pb n='47'/> produces .pageBreak(.arabic(47))")
    func parserPageBreakArabic() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Text<pb n="47"/>more</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.arabic(47)) = $0 { return true }
            return false
        })
    }

    @Test("Parser: <pb n='iv'/> produces .pageBreak(.roman(4))")
    func parserPageBreakRoman() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Text<pb n="iv"/>more</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.roman(4)) = $0 { return true }
            return false
        })
    }

    @Test("Parser: <pb n='A-12'/> produces .pageBreak(.prefixed('A-12'))")
    func parserPageBreakPrefixed() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Text<pb n="A-12"/>more</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.prefixed("A-12")) = $0 { return true }
            return false
        })
    }

    @Test("Parser: <pb n='??'/> produces .pageBreak(.unparseable) and does not crash")
    func parserPageBreakUnparseable() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Text<pb n="??"/>more</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.unparseable("??")) = $0 { return true }
            return false
        })
    }

    @Test("PageNumber: a bracketed arabic page is the volume's page only when its id says so — [31] with pg_31, not [3] with pg-seq-3 (#1503 review round 1)")
    func pageBreakUnnumbered() {
        #expect(PageNumber.parse("[31]", xmlId: "pg_31") == .unnumbered(31))
        #expect(PageNumber.parse("[31]", xmlId: "pg_031") == .unnumbered(31))
        // frus1865p1's President's message, under a pagination of its own.
        #expect(PageNumber.parse("[3]", xmlId: "pg-seq-3") == .unparseable("[3]"))
        #expect(PageNumber.parse("[31]", xmlId: nil) == .unparseable("[31]"))
        #expect(PageNumber.parse("[31]", xmlId: "pg_32") == .unparseable("[31]"))
        // Everything else reads as it always has, whatever the id — but a digit break with a
        // `pg-seq` id, which is another pagination since #1511 (`pageBreakOtherPagination`).
        #expect(PageNumber.parse("47", xmlId: "pg_47") == .arabic(47))
        #expect(PageNumber.parse("[XII]", xmlId: "pg_XII") == .roman(12))
        #expect(PageNumber.parse("[Map 7]", xmlId: "pg_Map7") == .unparseable("[Map 7]"))
    }

    @Test("Parser: <pb n='[31]' xml:id='pg_31'/> produces .pageBreak(.unnumbered(31)), and a break of another pagination stays unparseable (#1503 review round 1)")
    func parserPageBreakUnnumbered() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Text<pb n="[31]" xml:id="pg_31"/>more<pb n="[3]" xml:id="pg-seq-3"/>end</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.unnumbered(31)) = $0 { return true }
            return false
        })
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.unparseable("[3]")) = $0 { return true }
            return false
        })
    }

    @Test("PageNumber: a digit break with a pg-seq id is another pagination, and a mistyped id of any other shape is still the volume's page (#1511)")
    func pageBreakOtherPagination() {
        // frus1871's second sequence (pg-seq1_20 … pg-seq1_156), and frus1862's President's message,
        // whose page 4 is pg-seq-10 (frus1865p1's message numbers its pages the same way).
        #expect(PageNumber.parse("20", xmlId: "pg-seq1_20") == .otherPagination(20))
        #expect(PageNumber.parse("4", xmlId: "pg-seq-10") == .otherPagination(4))
        #expect(PageNumber.parse(" 156 ", xmlId: "pg-seq1_156") == .otherPagination(156))
        // The volume's own pages whose ids are mistyped: frus1977-80v13's pgg_655 inside d173, and
        // frus1884's pg_13 on n="12" — the number is the page, as before.
        #expect(PageNumber.parse("655", xmlId: "pgg_655") == .arabic(655))
        #expect(PageNumber.parse("12", xmlId: "pg_13") == .arabic(12))
        // No id at all (frus1981-88v16) and the zero-padded pg_001 (frus1977-80v20).
        #expect(PageNumber.parse("1", xmlId: nil) == .arabic(1))
        #expect(PageNumber.parse("001", xmlId: "pg_001") == .arabic(1))
        // A bracketed number on a pg-seq break stays unparseable (frus1871's d1 opens on [19]).
        #expect(PageNumber.parse("[19]", xmlId: "pg-seq1_19") == .unparseable("[19]"))
        // A roman page on a pg-seq break is still roman.
        #expect(PageNumber.parse("[III]", xmlId: "pg-seq-9") == .roman(3))
    }

    @Test("Parser: <pb n='20' xml:id='pg-seq1_20'/> produces .pageBreak(.otherPagination(20)), and the page a document begins on reads its break the same way (#1511)")
    func parserPageBreakOtherPagination() async throws {
        let url = try makeTEIFixture(body: """
        <pb n="19" xml:id="pg-seq1_19"/>
        <div type="document" xml:id="d1" n="1"><head>1. Message</head><p>Text<pb n="20" xml:id="pg-seq1_20"/>more</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .pageBreak(.otherPagination(20)) = $0 { return true }
            return false
        })
        #expect(docs.first?.startPage == .otherPagination(19))
    }

    // MARK: The page a document begins on (#1503)

    @Test("A document carries the page it begins on; a prose section the parser promotes carries none (#1503 review round 1)")
    func startPageIsADocumentsAlone() async throws {
        // frus1905's pp. 236–239: the referral stub ch45 begins at the foot of 238, below d1's end.
        let url = try makeTEIFixture(body: """
        <div type="compilation" xml:id="comp1">
          <pb n="236" xml:id="pg_236"/>
          <div type="document" xml:id="d1" n="1"><head>1. Memorandum</head><pb n="237" xml:id="pg_237"/>
            <p>Text.</p><pb n="238" xml:id="pg_238"/><p>More.</p></div>
          <div subtype="referral" type="chapter" xml:id="ch45"><head>Peace negotiations</head>
            <p rend="center">[Printed under Russia, p. 807.]</p></div>
          <pb n="239" xml:id="pg_239"/>
          <div type="document" xml:id="d2" n="2"><head>2. Telegram</head><p>Text.</p></div>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.first { $0.documentId == "d1" }?.startPage == .arabic(236))
        #expect(docs.first { $0.documentId == "d2" }?.startPage == .arabic(239))
        // The stub is still indexed; it names no page. Before this round it began on 238.
        let stub = try #require(docs.first { $0.documentId == "ch45" })
        #expect(stub.startPage == nil, "\(stub.startPage as Any)")
    }

    @Test("A div that closes before any text — a public-diplomacy volume's video player — takes no later break, and the document around it takes the next one (#1503 review round 1)")
    func aTextlessDivTakesNoLaterBreak() async throws {
        // frus1917-72PubDipv06 embeds XHTML players whose divs hold only an <iframe/>. Twelve such
        // divs sit in three volumes; a break met after one closes, before any text, must reach only
        // the divs still open.
        let url = try makeTEIFixture(body: """
        <pb n="11" xml:id="pg_11"/>
        <div type="document" xml:id="d1" n="1">
          <div style="position: relative;" xmlns="http://www.w3.org/1999/xhtml"><div style="padding-top: 56.25%;"><iframe src="//players.example/video"/></div></div>
          <pb n="12" xml:id="pg_12"/>
          <head>1. Video</head><p>Text.</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.first { $0.documentId == "d1" }?.startPage == .arabic(12))
    }
}

// MARK: - Containers (#1510)

/// A compilation, chapter or subchapter holding sections the parser promotes is a CONTAINER, which
/// history.state.gov shows as a list of what it holds (owner decision D1). One that holds nothing of
/// its own but a heading is not indexed; one with text of its own keeps the breaks within its text;
/// the breaks either leaves go to the section that begins after them.
@Suite("Containers: heading-only ones are left out, prose ones keep their own pages (#1510)")
struct ContainerTests {

    /// The parser's full-volume emission for `body`.
    private func parse(_ body: String) async throws -> [FRUSDocumentAST] {
        let url = try makeTEIFixture(body: body)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await FRUSDocumentParser().parse(volumeURL: url)
    }

    /// Every heading's text in `nodes`, at any depth.
    private func headings(in nodes: [FRUSASTNode]) -> [String] {
        nodes.flatMap { node -> [String] in
            if case .head(let children) = node { return [FRUSASTNode.printedText(of: children)] }
            return headings(in: node.children)
        }
    }

    /// Every page break in `nodes`, at any depth.
    private func pageBreaks(in nodes: [FRUSASTNode]) -> [PageNumber] {
        nodes.flatMap { node -> [PageNumber] in
            if case .pageBreak(let page) = node { return [page] }
            return pageBreaks(in: node.children)
        }
    }

    /// frus1919Parisv13's shapes, cut down: comp1 (heading-only, its own [2] and 3 ahead of ch1, 9
    /// between ch1 and ch2) and comp3 (heading-only, [56] ahead of ch12), and ch12, Part III, which
    /// prints "Notes to Part III" of its own on 134 and holds two sections, the first beginning on 135,
    /// the second on 140 — breaks written in ch12 after its own text.
    private let parisShapes = """
    <pb n="[1]" xml:id="pg_1"/>
    <div type="compilation" xml:id="comp1">
      <head>Introduction</head>
      <pb n="[2]" xml:id="pg_2"/>
      <pb n="3" xml:id="pg_3"/>
      <div subtype="editorial-note" type="chapter" xml:id="ch1"><head>The Paris Peace Conference</head>
        <p>The treaty of peace.</p><pb n="4" xml:id="pg_4"/><p>More.</p></div>
      <pb n="9" xml:id="pg_9"/>
      <div type="chapter" xml:id="ch2"><head>Organization</head><p>The Council of Ten.</p></div>
    </div>
    <div type="compilation" xml:id="comp3">
      <head><hi rend="strong">I: The Treaty of Peace</hi></head>
      <pb n="[56]" xml:id="pg_56"/>
      <div subtype="editorial-note" type="chapter" xml:id="ch12"><head>Part III.—Political Clauses</head>
        <p>Notes to Part III, Articles 31 to 117</p><pb n="134" xml:id="pg_134"/><p>Senate Document 348.</p>
        <pb n="135" xml:id="pg_135"/>
        <div type="subchapter" xml:id="ch12subch1"><head>Section I</head><p>Article 31.</p>
          <pb n="136" xml:id="pg_136"/><p>Article 32.</p></div>
        <pb n="140" xml:id="pg_140"/>
        <div type="subchapter" xml:id="ch12subch2"><head>Section II</head><p>Article 40.</p></div>
      </div>
    </div>
    """

    @Test("A heading-only compilation is not indexed, and its breaks go to the section that begins after each one")
    func headingOnlyContainerIsLeftOut() async throws {
        let docs = try await parse(parisShapes)
        let ids = docs.map(\.documentId)
        #expect(!ids.contains("comp1") && !ids.contains("comp3"), "\(ids)")
        #expect(ids.contains("ch1") && ids.contains("ch2") && ids.contains("ch12"))
        // comp1's [2] and 3 sit before ch1 opens; 9 before ch2; comp3's [56] before ch12.
        #expect(docs.first { $0.documentId == "ch1" }?.carriedPages == [.unnumbered(2), .arabic(3)])
        #expect(docs.first { $0.documentId == "ch2" }?.carriedPages == [.arabic(9)])
        // Risk 1 of the D1 research: the left-out heading must reach no section's text.
        let allHeads = docs.flatMap { headings(in: $0.nodes) }
        #expect(!allHeads.contains("Introduction"), "\(allHeads)")
        #expect(!allHeads.contains { $0.contains("The Treaty of Peace") }, "\(allHeads)")
    }

    @Test("A container with text of its own keeps the breaks within that text, and gives the ones after it to the sections that begin after them")
    func proseContainerIsNarrowedToItsOwnText() async throws {
        let docs = try await parse(parisShapes)
        let ch12 = try #require(docs.first { $0.documentId == "ch12" })
        #expect(pageBreaks(in: ch12.nodes) == [.arabic(134)], "\(pageBreaks(in: ch12.nodes))")
        #expect(ch12.carriedPages == [.unnumbered(56)])
        #expect(docs.first { $0.documentId == "ch12subch1" }?.carriedPages == [.arabic(135)])
        #expect(docs.first { $0.documentId == "ch12subch2" }?.carriedPages == [.arabic(140)])
        // Its text is still indexed.
        #expect(FRUSASTNode.printedText(of: ch12.nodes).contains("Notes to Part III"))
    }

    @Test("A heading-only subchapter inside a chapter with text of its own is left out, and neither its heading nor its break moves into the chapter (frus1919Parisv13 ch21subch3)")
    func headingOnlyContainerInsideAProseOne() async throws {
        let docs = try await parse("""
        <div type="chapter" xml:id="ch21"><head>Part XIII</head><p>Notes to Part XIII.</p>
          <div type="subchapter" xml:id="ch21subch3"><head>Section III</head>
            <div type="subchapter" xml:id="ch21subsubch1"><head>Article 1</head><p>Text one.</p></div>
            <pb n="685" xml:id="pg_685"/>
            <div type="subchapter" xml:id="ch21subsubch2"><head>Article 2</head><p>Text two.</p></div>
          </div>
        </div>
        """)
        let ids = docs.map(\.documentId)
        #expect(!ids.contains("ch21subch3"), "\(ids)")
        let ch21 = try #require(docs.first { $0.documentId == "ch21" })
        #expect(!headings(in: ch21.nodes).contains("Section III"), "\(headings(in: ch21.nodes))")
        #expect(pageBreaks(in: ch21.nodes).isEmpty, "\(pageBreaks(in: ch21.nodes))")
        #expect(ch21.carriedPages.isEmpty)
        #expect(docs.first { $0.documentId == "ch21subsubch2" }?.carriedPages == [.arabic(685)])
    }

    @Test("A container holding its sections through a wrapper div is still a container")
    func containerThroughAWrapper() async throws {
        let docs = try await parse("""
        <div type="compilation" xml:id="comp9"><head>Honduras</head>
          <div type="section" xml:id="wrapper">
            <div type="chapter" xml:id="ch32"><head>Boundary dispute with Nicaragua</head><p>Text.</p></div>
          </div>
        </div>
        """)
        #expect(docs.map(\.documentId) == ["ch32"])
    }

    @Test("A heading-only appendix container keeps v62's treatment: indexed, with its own breaks (D1: frus1917-72PubDip's Appendix A)")
    func headingOnlyAppendixIsKept() async throws {
        let docs = try await parse("""
        <div subtype="appendix" type="section" xml:id="appendix"><head>Appendix A</head>
          <div subtype="historical-document" type="section" xml:id="a1"><head>A.1</head><p>Photograph.</p></div>
          <pb n="95" xml:id="pg_95"/>
          <div subtype="historical-document" type="section" xml:id="a2"><head>A.2</head><p>Pamphlet.</p></div>
        </div>
        """)
        let appendix = try #require(docs.first { $0.documentId == "appendix" })
        #expect(pageBreaks(in: appendix.nodes) == [.arabic(95)])
        #expect(docs.first { $0.documentId == "a2" }?.carriedPages == [])
    }

    @Test("A break a container leaves before a DOCUMENT is not carried: it is already the page the document begins on")
    func aBreakBeforeADocumentStaysItsStart() async throws {
        let docs = try await parse("""
        <div type="compilation" xml:id="c1"><head>Part One</head>
          <div type="chapter" xml:id="c1ch1"><head>Notes</head><p>Text.</p></div>
          <pb n="5" xml:id="pg_5"/>
        </div>
        <div type="compilation" xml:id="c2"><head>Documents</head>
          <div type="document" xml:id="d1" n="1"><head>1. Telegram</head><p>Text.</p></div>
        </div>
        """)
        #expect(docs.map(\.documentId) == ["c1ch1", "d1"])
        #expect(docs.allSatisfy { $0.carriedPages.isEmpty })
        #expect(docs.first { $0.documentId == "d1" }?.startPage == .arabic(5))
    }

    @Test("A break a container leaves with nothing after it goes nowhere")
    func aBreakWithNothingAfterItGoesNowhere() async throws {
        let docs = try await parse("""
        <div type="compilation" xml:id="c1"><head>Part One</head>
          <div type="chapter" xml:id="c1ch1"><head>Notes</head><p>Text.</p></div>
          <pb n="7" xml:id="pg_7"/>
        </div>
        """)
        #expect(docs.map(\.documentId) == ["c1ch1"])
        #expect(docs.allSatisfy { $0.carriedPages.isEmpty })
        #expect(docs.allSatisfy { pageBreaks(in: $0.nodes).isEmpty })
    }

    @Test("A section that holds no promoted section is no container, whatever its kind: its own breaks stay its own")
    func aPlainChapterIsUnchanged() async throws {
        let docs = try await parse("""
        <div type="chapter" xml:id="ch1"><head>Notes</head><p>Text.</p><pb n="8" xml:id="pg_8"/></div>
        """)
        let ch1 = try #require(docs.first)
        #expect(pageBreaks(in: ch1.nodes) == [.arabic(8)])
        #expect(ch1.carriedPages.isEmpty)
    }

    /// The stored documents, page rows, page references' edges and persons-list years changed, so an
    /// installed index must re-parse (#1509, #1510, #1511).
    @Test("The index version is at least 63, the page-citation rebuild of #1509, #1510 and #1511")
    func indexVersionCoversPageCitations() {
        #expect(IndexingPipeline.currentDateIndexVersion >= 63)
    }

    @Test("Opening a left-out container by id still renders everything it holds")
    func aLeftOutContainerStillOpensById() async throws {
        let url = try makeTEIFixture(body: parisShapes)
        defer { try? FileManager.default.removeItem(at: url) }
        let ast = try #require(try await FRUSDocumentParser().parseDocument(documentId: "comp1", volumeURL: url))
        #expect(headings(in: ast.nodes).contains("Introduction"))
        #expect(FRUSASTNode.printedText(of: ast.nodes).contains("The Council of Ten"))
    }
}

// MARK: - Table Tests

@Suite("Table Parsing")
struct TableParsingTests {

    @Test("Parser: basic table produces .table with .tableRow and .tableCell children")
    func basicTable() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <table><row><cell>Alpha</cell><cell>Beta</cell></row></table>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        let nodes = docs.flatMap(\.nodes)
        // Should contain a .table node
        #expect(containsCase(in: nodes) { if case .table = $0 { return true }; return false })
    }

    @Test("Parser: <cell rows='2' cols='3'> produces correct rowSpan and colSpan")
    func mergedCell() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <table><row><cell rows="2" cols="3">Spanning</cell></row></table>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .tableCell(let rs, let cs, _) = $0 { return rs == 2 && cs == 3 }
            return false
        })
    }

    @Test("Converter: .table AST converts to .tableBlock render node")
    func converterTable() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <table><row><cell>A</cell><cell>B</cell></row></table>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])
        let hasTable = model.bodyNodes.contains { if case .tableBlock = $0 { return true }; return false }
        #expect(hasTable)
    }
}

// MARK: - List Tests

@Suite("List Parsing")
struct ListParsingTests {

    @Test("Parser: <list type='ordered'> produces .list with type .ordered")
    func orderedList() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <list type="ordered"><item>First</item><item>Second</item></list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .list(let t, _) = $0 { return t == .ordered }
            return false
        })
    }

    @Test("Parser: <list type='unordered'> produces .list with type .unordered")
    func unorderedList() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <list type="unordered"><item>A</item><item>B</item></list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .list(let t, _) = $0 { return t == .unordered }
            return false
        })
    }

    @Test("Parser: nested list produces inner .list node")
    func nestedList() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <list type="unordered">
            <item>Outer
              <list type="ordered"><item>Inner</item></list>
            </item>
          </list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        var listCount = 0
        func countLists(_ nodes: [FRUSASTNode]) {
            for n in nodes {
                if case .list(_, let items) = n { listCount += 1; countLists(items) }
                if case .listItem(let c) = n { countLists(c) }
            }
        }
        countLists(docs.flatMap(\.nodes))
        #expect(listCount == 2)
    }

    @Test("Parser: list inside table cell is preserved")
    func listInTableCell() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <table><row>
            <cell><list type="simple"><item>X</item></list></cell>
          </row></table>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .list = $0 { return true }; return false
        })
    }

    @Test("Converter: .list AST converts to .listBlock render node")
    func converterList() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <list type="ordered"><item>One</item><item>Two</item></list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])
        let hasList = model.bodyNodes.contains { if case .listBlock = $0 { return true }; return false }
        #expect(hasList)
    }
}

// MARK: - List heads, labels and other list children (#1371)

/// Real corpus shapes of `<list>` and the reader's own pipeline over them (#1371), shared by
/// `ListHeadsAndLabelsTests` below, the web-view parity, selection and layout tests in
/// `FRUSOffsetEngineTests.swift`, and `ListExportTests` in `CollectionTests.swift`, so every
/// suite measures the same markup.
///
/// Measured at corpus `550a8c5c5` over the 553 manifest volumes, counting direct children of
/// `<list>` inside `div[@type="document"]`, each list once under its nearest document div (one
/// list in `frus1902app1` sits in `d174`, itself inside document `s12`): 721,470 `<item>`,
/// 449,659 `<label>`, 52,185 `<head>`
/// (always the first child, never two in one list), 21,891 `<pb/>`, 119 `<lb/>`, 8 `<closer>`,
/// 5 `<gap/>`, 4 `<salute>`, 2 `<note>` and 1 `<figure>`. Every label is followed by an item once
/// any `<pb/>` or `<note>` between them is skipped. The converter used to keep only the items.
enum ListShapeFixtures {

    /// `frus1961-63v05/d84`, the Vienna lunch memorandum of 3 June 1961, trimmed to its three
    /// lists: a `subject` list and a `participants` list that each carry a `<head>`, and a
    /// labelled list inside a paragraph whose `(1)`–`(6)` exist nowhere but in `<label>`, with a
    /// `<pb/>` between the first two items and a footnote inside the third. The list markup is
    /// the volume's own — its heads, its labels, the `<pb facs="0207" n="179">` between items (1)
    /// and (2) and the `d84fn2` note in item (3). The rest is trimmed: the item prose and the
    /// head's source note are shortened, some `<persName>` and `<gloss>` markup and the date's
    /// `@type` are dropped, and the volume's ʼ (U+02BC) is typed as ’ (U+2019). None of that
    /// touches what the list tests measure.
    ///
    /// (#1371 cites this document; the lane brief named `frus1961-63v11/d84`, which is a
    /// Khrushchev letter with no list in it.)
    static let d84 = """
    <div type="document" subtype="historical-document" n="84" xml:id="d84">
      <head>84. Memorandum of Conversation<note n="0" type="source" xml:id="d84fn0">Source: Kennedy Library, President’s Office Files, USSR. Secret; Eyes Only.</note></head>
      <opener><dateline rendition="#right"><placeName>Vienna</placeName>, <date calendar="gregorian" when="1961-06-03">June 3, 1961</date>.</dateline></opener>
      <list type="subject">
        <head>SUBJECT</head>
        <item>Vienna Meeting Between The President and Chairman <persName corresp="#p_KNS1">Khrushchev</persName></item>
      </list>
      <list type="participants">
        <head>PARTICIPANTS:</head>
        <item>Listed on Page 4</item>
      </list>
      <p>During lunch the conversation was mostly of a social nature. The points of significance that emerged were the following: <list>
          <label>(1)</label>
          <item>During the discussion of the history of the Laotian Conference, Mr. <persName corresp="#p_KNS1">Khrushchev</persName> said that the conference had found a good solution for Viet Nam.</item>
          <pb facs="0207" n="179" xml:id="pg_179"/>
          <label>(2)</label>
          <item>In discussing agricultural problems in the Soviet Union, Mr. <persName corresp="#p_KNS1">Khrushchev</persName> stressed the need for a great increase in their chemical production.</item>
          <label>(3)</label>
          <item>With reference to Gagarin’s flight,<note n="2" xml:id="d84fn2">A reference to Major Yuri Gagarin’s orbital flight of the earth in April.</note> Mr. <persName corresp="#p_KNS1">Khrushchev</persName> said that prior to the launching there were many unknown factors.</item>
          <label>(4)</label>
          <item>With regard to the possibility of launching a man to the moon, Mr. Khrushchev said that he was cautious.</item>
          <label>(5)</label>
          <item>In raising his glass to the health of his guest, the President expressed satisfaction.</item>
          <label>(6)</label>
          <item>In response to the toast, Mr. Khrushchev expressed the hope that wisdom would be found.</item>
        </list></p>
    </div>
    """

    /// `d84` with its two list heads and six labels removed — the markup the converter's output
    /// used to be equivalent to, and so the flat text restoring them must not move.
    static var d84WithoutHeadsOrLabels: String {
        d84.replacing(/<head>(SUBJECT|PARTICIPANTS:)<\/head>/, with: "")
            .replacing(/<label>[^<]*<\/label>/, with: "")
    }

    /// One `<list>` holding every element the corpus puts directly inside a list, each where the
    /// corpus puts it: the head first; a `<salute>` before the first item (3 of the 4 salutes);
    /// an `<lb/>` between items; a `<note>` between a label and its item and `<pb/>`s either side
    /// of a `<figure>` (`frus1952-54v02p1/d93` and `frus1948v05p2/d486`); a `<gap/>` and a
    /// `<closer>` after the last item (all 8 closers). The head and a label each carry a footnote
    /// too — 16 list heads and 87 labels do — so a footnote can be lost three ways here.
    static let everyChild = """
    <div type="document" subtype="historical-document" n="1" xml:id="d1">
      <p>Opening paragraph.</p>
      <list>
        <head>Recommendations:<note n="1" xml:id="d1fn1">A note on the heading.</note></head>
        <salute>By desire and on behalf of the meeting:</salute>
        <label>a.<note n="2" xml:id="d1fn2">A note on the label.</note></label>
        <item>First item text.</item>
        <lb/>
        <label>b.</label>
        <note n="3" xml:id="d1fn3"><p>A typewritten notation in the margin.</p></note>
        <item>Second item text.</item>
        <pb facs="0732" n="[map]" xml:id="pg-seq-732"/>
        <figure><graphic url="figure_0732"/></figure>
        <pb facs="0733" n="1241" xml:id="pg_1241"/>
        <label><hi rend="italic">c</hi>.</label>
        <item>Third item text.</item>
        <gap/>
        <closer><signed><persName corresp="#p_KHA1">Henry A. Kissinger</persName></signed></closer>
      </list>
      <p>Closing paragraph.</p>
    </div>
    """

    /// `everyChild` with only its three `<item>`s — the flat text it must still produce.
    static let everyChildItemsOnly = """
    <div type="document" subtype="historical-document" n="1" xml:id="d1">
      <p>Opening paragraph.</p>
      <list>
        <item>First item text.</item>
        <item>Second item text.</item>
        <item>Third item text.</item>
      </list>
      <p>Closing paragraph.</p>
    </div>
    """

    /// Parses `documentXML` — one `<div type="document">` — as a volume and converts it with
    /// `converter` (a fresh one with no lookups by default), exactly as the reader does.
    static func renderModel(
        _ documentXML: String,
        converter: ASTToRenderNodeConverter = ASTToRenderNodeConverter()
    ) async throws -> FRUSDocumentRenderModel {
        let ast = try await Self.ast(documentXML)
        var converter = converter
        return converter.convert(ast)
    }

    /// Parses `documentXML` — one `<div type="document">` — as a volume and returns its AST, the
    /// input the reader converts and `IndexingPipeline` indexes (#1495 reads both).
    static func ast(_ documentXML: String) async throws -> FRUSDocumentAST {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt>
            <publicationStmt><p/></publicationStmt>
            <sourceDesc><p/></sourceDesc></fileDesc></teiHeader>
          <text><body>\(documentXML)</body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-1371-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let documents = try await FRUSDocumentParser().parse(volumeURL: url)
        return try #require(documents.first, "the fixture must parse to a document")
    }

    /// The first of `needles` that does not occur in `haystack` after the one before it, or `nil`
    /// when every needle occurs, in order.
    static func firstOutOfOrder(_ needles: [String], in haystack: String) -> String? {
        var cursor = haystack.startIndex
        for needle in needles {
            guard let hit = haystack.range(of: needle, range: cursor..<haystack.endIndex) else {
                return needle
            }
            cursor = hit.upperBound
        }
        return nil
    }
}

/// #1371: the reader dropped every child of `<list>` except its items, so SUBJECT and
/// PARTICIPANTS heads and printed numbering such as `(1)` vanished from 79,788 documents, and a
/// footnote in a list head, a label, or loose in a list lost both its marker and its body.
///
/// Every test runs the real parser, converter and serializer over corpus markup. The flat text —
/// the highlight coordinate space, hashed into `renderingVersion` — must not move, because a
/// changed hash marks every stored highlight in the document stale.
@Suite("List heads, labels and other list children (#1371)")
struct ListHeadsAndLabelsTests {

    private func html(_ model: FRUSDocumentRenderModel) -> String {
        FRUSRenderNodeHTMLSerializer().serialize(model)
    }

    @Test("d84's SUBJECT and PARTICIPANTS heads and its printed (1)–(6) reach the HTML in order, and renderingVersion does not move")
    func d84ShapesReachTheHTMLInOrder() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.d84)
        let out = html(model)
        let order = [
            "SUBJECT", "Vienna Meeting Between The President", "PARTICIPANTS:", "Listed on Page 4",
            "the following:", "(1)", "During the discussion", "data-page=\"179\"",
            "(2)", "In discussing agricultural", "(3)", "With reference to Gagarin",
            "(4)", "With regard to the possibility", "(5)", "In raising his glass",
            "(6)", "In response to the toast",
        ]
        let missing = ListShapeFixtures.firstOutOfOrder(order, in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the serialized d84, or out of order")

        // The data-skip route: none of it enters the flat text, so the hash every stored
        // highlight carries is the one d84 had while the reader dropped these elements.
        let stripped = ListShapeFixtures.d84WithoutHeadsOrLabels
        #expect(stripped != ListShapeFixtures.d84, "the stripped variant must differ from the fixture")
        #expect(!stripped.contains("<label>") && !stripped.contains("SUBJECT"))
        let baseline = try await ListShapeFixtures.renderModel(stripped)
        #expect(ASTToRenderNodeConverter.kVersion == "1.2")
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: baseline))
        let flat = buildFlatText(from: model)
        #expect(flat.contains("In discussing agricultural problems"), "the items must still be flat text")
        for printed in ["SUBJECT", "PARTICIPANTS", "(1)", "(6)"] {
            #expect(!flat.contains(printed), "\(printed) entered the flat text")
        }
    }

    @Test("One list holding every direct child the corpus uses loses no text and no footnote")
    func everyDirectChildSurvives() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let out = html(model)
        let order = [
            "Opening paragraph.",
            "Recommendations:", "popovertarget=\"fn-x-d1fn1\"",       // head, and its note
            "By desire and on behalf of the meeting:",                 // salute before the first item
            ">a.", "popovertarget=\"fn-x-d1fn2\"", "First item text.", // label, and its note
            "<br>",                                                    // lb between items
            ">b.<", "popovertarget=\"fn-x-d1fn3\"", "Second item text.", // note between label and item
            "data-page=\"[map]\"", "<span class=\"figure-missing\">[Figure]</span>", "data-page=\"1241\"",
            "<em>c</em>.", "Third item text.",
            "data-element-name=\"gap\"", "Henry A. Kissinger",        // gap and closer after the last item
            "Closing paragraph.",
        ]
        let missing = ListShapeFixtures.firstOutOfOrder(order, in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the serialized list, or out of order")

        // A footnote in the head, in a label, and loose between a label and its item: each keeps
        // its body as well as its marker.
        let labels = model.footnotes.map { node -> String? in
            guard case .footnoteBody(_, _, _, _, let label, _) = node else { return nil }
            return label
        }
        #expect(labels == ["1", "2", "3"], "footnotes collected: \(labels)")
        let bodies = flatText(of: model.footnotes)
        for body in ["A note on the heading.", "A note on the label.", "A typewritten notation in the margin."] {
            #expect(bodies.contains(body), "footnote body \"\(body)\" was lost")
        }

        // None of it enters the flat text: the list hashes exactly as its items alone do.
        let itemsOnly = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChildItemsOnly)
        #expect(buildFlatText(from: model)
                == "Opening paragraph.First item text.Second item text.Third item text.Closing paragraph.")
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: itemsOnly))
    }

    @Test("A second <head> in one list is kept, after the first — no list in the corpus has two")
    func aSecondHeadIsKept() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <list type="participants"><head>PARTICIPANTS:</head><head>United States</head><item>The Secretary</item></list>
        </div>
        """)
        let out = html(model)
        let missing = ListShapeFixtures.firstOutOfOrder(["PARTICIPANTS:", "United States", "The Secretary"], in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing or out of order")
        #expect(buildFlatText(from: model) == "The Secretary")
    }

    @Test("A label with no item after it is kept after the last item — no label in the corpus lacks one")
    func aDanglingLabelIsKept() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <list><label>1.</label><item>One.</item><label>2.</label></list>
        </div>
        """)
        let out = html(model)
        let missing = ListShapeFixtures.firstOutOfOrder([">1.<", "One.", ">2.<"], in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing or out of order")
        #expect(buildFlatText(from: model) == "One.")
    }

    /// 1,946 `<gloss>`es sit in list heads; a link the reader draws in a heading, a label or a
    /// closer after the list must resolve when tapped, so the scheme handler's lookup tables have
    /// to be built from those parts too.
    /// Converts `documentXML` with lookups that answer every person and term ref, off the main
    /// actor — the lookups are built here so no main-actor closure crosses into the parse.
    private static func modelWithLookups(_ documentXML: String) async throws -> FRUSDocumentRenderModel {
        let converter = ASTToRenderNodeConverter(
            personLookup: { ref in PersonEntry(ref: ref, name: "Person \(ref)") },
            glossLookup: { ref in GlossEntry(ref: ref, term: "Term \(ref)", definition: nil) })
        return try await ListShapeFixtures.renderModel(documentXML, converter: converter)
    }

    @Test("A term or person linked in a list's heading, a label or a closer after it resolves when tapped")
    @MainActor
    func linksInListPartsResolve() async throws {
        let model = try await Self.modelWithLookups("""
        <div type="document" xml:id="d1">
          <list type="subject">
            <head>SUBJECT: <gloss target="#t_USSR1">USSR</gloss></head>
            <label><persName corresp="#p_LAB1">Label</persName>.</label>
            <item>The item.</item>
            <closer><signed><persName corresp="#p_KHA1">Henry A. Kissinger</persName></signed></closer>
          </list>
        </div>
        """)
        let handler = FRUSURLSchemeHandler()
        handler.register(model: model)
        var glosses: [GlossEntry?] = []
        var persons: [PersonEntry?] = []
        handler.onGlossTap = { glosses.append($0) }
        handler.onPersonTap = { persons.append($0) }
        handler.dispatch(url: try #require(URL(string: "frusexplorer://gloss/t_USSR1")))
        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_LAB1")))
        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_KHA1")))
        #expect(glosses.map { $0?.ref } == ["t_USSR1"], "the heading's term did not resolve")
        #expect(persons.map { $0?.ref } == ["p_LAB1", "p_KHA1"], "a label's or the closer's person did not resolve")
    }

    /// The collection exporter's plain-text walk prints a list in the order the reader draws it.
    /// No document head or dateline holds a list outside a footnote today, so this is the only
    /// thing that reaches the branch.
    @Test("The export's plain-text walk prints a list's heading, labels and closer in order")
    func plainTextWalkPrintsListParts() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let list = try #require(model.bodyNodes.first { if case .listBlock = $0 { return true }; return false })
        let text = CollectionContentResolver.renderNodePlainText(list)
        let missing = ListShapeFixtures.firstOutOfOrder([
            "Recommendations:", "By desire and on behalf of the meeting:", "a.", "First item text.",
            "b.", "Second item text.", "c.", "Third item text.", "Henry A. Kissinger",
        ], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from \"\(text)\", or out of order")
    }

    /// A highlight's stored passage and an excerpt capture are cut from `buildFlatTextBlocks`
    /// (`flatTextExcerpt`), a second walker beside `buildFlatText` that must visit exactly the
    /// same characters — otherwise every passage after a labelled item is sliced at offsets
    /// that index a different string. The manuals promise the passage keeps the words of
    /// numbered paragraphs without their numbers; this is the walker that keeps that promise.
    @Test("A highlight or excerpt across numbered items keeps their words without the numbers or the list's heading")
    func excerptsOmitLabelsAndHeadings() async throws {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.d84)
        let flat = buildFlatText(from: model)
        let blocks = buildFlatTextBlocks(from: model)
        #expect(blocks.joined() == flat, "the block partition must be the flat text cut into blocks, nothing more")

        func offset(of needle: String) throws -> Int {
            let range = try #require(flat.range(of: needle), "\"\(needle)\" is not in the flat text")
            return flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
        }
        // From item (1) into item (2), as a drag across the two would store it — and from the
        // SUBJECT list's item into the PARTICIPANTS list's.
        let across = try #require(flatTextExcerpt(
            from: model, start: try offset(of: "During the discussion"),
            end: try offset(of: "In discussing agricultural") + "In discussing".utf16.count))
        #expect(across.hasPrefix("During the discussion of the history"), "excerpt: \(across.debugDescription)")
        #expect(across.hasSuffix("Viet Nam.\n\nIn discussing"), "each item is its own block: \(across.debugDescription)")
        let headed = try #require(flatTextExcerpt(
            from: model, start: try offset(of: "Vienna Meeting"),
            end: try offset(of: "Listed on Page 4") + "Listed".utf16.count))
        #expect(headed == "Vienna Meeting Between The President and Chairman Khrushchev\n\nListed",
                "excerpt: \(headed.debugDescription)")
        for printed in ["(1)", "(2)", "SUBJECT", "PARTICIPANTS"] {
            #expect(!across.contains(printed) && !headed.contains(printed), "\(printed) entered an excerpt")
        }
    }
}

// MARK: - Table captions (#1495)

/// Real corpus tables whose `<head>` — the caption the volume printed above them — the converter
/// dropped until #1495, shared by `TableCaptionTests` below, the web-view parity, layout and
/// selection tests in `FRUSOffsetEngineTests.swift` (`FRUSOffsetEngineTests.tableCaptionParity`,
/// `TableCaptionLayoutTests`, `ListLabelSelectionTests`), and `TableCaptionExportTests` in
/// `CollectionTests.swift`, so those suites measure the same markup. One suite does not:
/// `FootnoteBlockDocxTests.noteOpeningWithATablePrintsItsNumberFirst`, Word's footnote-story case,
/// reads #1414's own copy of `v41d86`'s note (`FootnoteBlockFixtures.opensWithTable`), which keeps
/// the same three rows and caption with the volume's hard-wrapped lines and the document's head.
///
/// Measured at corpus `550a8c5c5` over the 553 manifest volumes, counting each `<table>` once
/// under its nearest `div[@type="document"]`: 14,690 tables, 216 of them with a `<head>`, in 96
/// documents across 43 volumes. The head is ALWAYS the table's first child and no table has two.
/// Inside the 216 heads sit 91 `<lb/>`, 49 `<hi>`, 43 `<gloss>`, 9 `<note>` and 2 `<persName>`,
/// and nothing else — no `<p>`, no list, no table. One captioned table sits inside a footnote
/// (`v41`'s below). The only other child a table carries is `<pb/>` between rows: 1,557 of them.
///
/// Each fixture is the volume's own markup, trimmed: rows and prose are cut, and the source
/// XML's hard-wrapped indentation is joined onto single lines, which the parser's whitespace
/// normalisation makes equivalent.
enum TableCaptionFixtures {

    /// `frus1951-54Iran/d355` paragraph 10 and the table it introduces, whose caption is its
    /// UNITS — without it the figures read without a scale. Four of its fifteen rows are kept.
    static let d355 = """
    <div type="document" subtype="historical-document" n="355" xml:id="d355">
      <p>10. Iranian foreign exchange requirements and sources of foreign exchange are shown in the following table:</p>
      <table cols="4">
        <head>Millions of Dollars</head>
        <row>
          <cell/>
          <cell>Year Ending March 20, 1950</cell>
          <cell>Year Ending March 20, 1951</cell>
          <cell>“Emergency Basis”<lb/>—annual rate—</cell>
        </row>
        <row>
          <cell cols="3">Requirements</cell>
        </row>
        <row>
          <cell>Imports</cell>
          <cell role="num">192</cell>
          <cell role="num">147</cell>
          <cell role="num">120</cell>
        </row>
        <row>
          <cell>Requirement for Emergency Aid</cell>
          <cell role="num">—</cell>
          <cell role="num">—</cell>
          <cell role="num">52</cell>
        </row>
      </table>
      <p>11. On the basis of the above presentation, U.S. emergency aid at a rate of $50 to $55 million a year along with the continuation of the current technical and economic aid program ($23 million) would meet the minimum budgetary and foreign exchange requirements.</p>
    </div>
    """

    /// `d355` with its caption removed — the markup the converter's output used to be
    /// equivalent to, and so the flat text restoring the caption must not move.
    static var d355WithoutCaption: String {
        d355.replacing("<head>Millions of Dollars</head>", with: "")
    }

    /// `frus1977-80v04/d71`, Huntington to Brzezinski, 1 August 1978, trimmed to footnote 6's
    /// paragraph, the captioned table and footnote 8's paragraph. The caption holds footnote 7
    /// (`d71fn7`), one of the corpus's 9 notes in a table head: while the caption was dropped, the
    /// note's marker AND its body vanished, and the reader's footnotes ran 6, 8. The head's
    /// source note keeps its `n="1"`, as the volume encodes it.
    static let d71 = """
    <div type="document" subtype="historical-document" n="71" xml:id="d71">
      <head>71. Memorandum From Samuel Huntington of the National Security Council Staff to the President’s Assistant for National Security Affairs (Brzezinski)<note n="1" type="source" xml:id="d71fn1">Source: Carter Library, National Security Affairs, Staff Material, Defense/Security, Huntington, Box 64, [PRM–32]: 8/78. Secret. Sent for information. Copies were sent to Utgoff and Molander.</note></head>
      <p>The report cites the 1974 NUWEP<note n="6" xml:id="d71fn6">See <hi rend="italic">Foreign Relations</hi>, 1969–1976, vol. XXXV, National Security Policy, 1973–1976, footnote 4, Document 31.</note> as identifying four principal targets for destruction. Current policy sets forth the priorities in the allocation of weapons against these targets under conditions of day-to-day alert and generated forces as follows:</p>
      <table cols="6" xml:id="table018">
        <head>Table 1 Weapons Allocation Priorities<note n="7" xml:id="d71fn7">Brzezinski added the columns labeled “SU Strike” and “US Strike” by hand.</note></head>
        <row>
          <cell/>
          <cell cols="3">Current Policy</cell>
          <cell/>
          <cell/>
        </row>
        <row>
          <cell>Targets</cell>
          <cell>Day-to-day alert</cell>
          <cell>Generated forces</cell>
          <cell>Desirable Policy</cell>
          <cell>SU Strike</cell>
          <cell>US Strike</cell>
        </row>
        <row>
          <cell>1. Recovery resources</cell>
          <cell>1</cell>
          <cell>1</cell>
          <cell>4</cell>
          <cell>1</cell>
          <cell>3</cell>
        </row>
      </table>
      <pb facs="0332" n="307" xml:id="pg_307"/>
      <p>It would still make much more sense to reorder the priorities as indicated in the third column of Table 1, so as to give top priority to enemy nuclear forces, while relegating recovery resources to a residual fourth place.<note n="8" xml:id="d71fn8">Brzezinski drew a vertical line in the left margin next to this paragraph and wrote below it: “Who strikes first?”</note></p>
    </div>
    """

    /// `frus1969-76ve07/d85`'s `PAKISTAN: FOREIGN AID BY COUNTRY` table, the third of the
    /// document's five captioned tables, trimmed to four of its ten rows. Its caption
    /// runs to three printed lines — a title carrying note `a`, the span, and the units — and a
    /// cell carries note `b`, so the caption's note must be numbered BEFORE the cell's.
    static let ve07d85 = """
    <div type="document" subtype="historical-document" n="85" xml:id="d85">
      <table cols="3" rows="10">
        <head>PAKISTAN: FOREIGN AID BY COUNTRY<note n="a" xml:id="d85fn11">Military aid excluded</note><lb/>1948–1969<lb/>(billion US dollars)</head>
        <row>
          <cell/>
          <cell>Authorized</cell>
          <cell>Drawings</cell>
        </row>
        <row>
          <cell>Free World Consortium<note n="b" xml:id="d85fn12">In addition, Free World countries also provided about $700 million in foreign exchange for the Indus Basin Scheme in West Pakistan.</note></cell>
          <cell/>
          <cell/>
        </row>
        <row>
          <cell>PL 480</cell>
          <cell role="num">1.36</cell>
          <cell role="num">1.36</cell>
        </row>
        <row>
          <cell>Total</cell>
          <cell role="num">7.06</cell>
          <cell role="num">5.72</cell>
        </row>
      </table>
    </div>
    """

    /// `ve07d85` with its caption removed, for the same flat-text comparison as
    /// `d355WithoutCaption`.
    static var ve07d85WithoutCaption: String {
        ve07d85.replacing(/<head>PAKISTAN.*?<\/head>/, with: "")
    }

    /// `frus1969-76v41/d86` footnote 7, the corpus's one captioned table inside a footnote,
    /// trimmed to three of its twenty rows. The note opens with the table and closes on a
    /// paragraph of its own.
    static let v41d86 = """
    <div type="document" subtype="historical-document" n="86" xml:id="d86">
      <p>The most important fact of European economic life is that the <gloss target="#t_EC_1">EC</gloss> partners mean far more to each other than the US means to any of them, and the <gloss target="#t_EC_1">EC</gloss> as a unit means more to the other (non-member) European economies than does the US.<note n="7" xml:id="d86fn7">
          <table>
            <head>SELECTED COUNTRIES’ TRADE WITH THE US AND THE <gloss target="#t_EC_1">EC</gloss> OF NINE* </head>
            <row>
              <cell>Country</cell>
              <cell>Percent of Exports to the US</cell>
              <cell>Percent of Imports from the US</cell>
              <cell>Percent of Exports to <gloss target="#t_EC_1">EC</gloss> of Nine</cell>
              <cell>Percent of Imports from <gloss target="#t_EC_1">EC</gloss> of Nine</cell>
            </row>
            <row>
              <cell>Germany</cell>
              <cell role="num">10</cell>
              <cell role="num">13</cell>
              <cell role="num">47</cell>
              <cell role="num">57</cell>
            </row>
            <row>
              <cell>Spain</cell>
              <cell role="num">15</cell>
              <cell role="num">16</cell>
              <cell role="num">47</cell>
              <cell role="num">42</cell>
            </row>
          </table>
          <p>*All data are for calendar year 1971. [Footnote is in the original.]</p>
        </note> Worries that protectionist or other “neo-isolationist” tendencies are likely to grow in the US, whatever Europe does, are adding psychological weight to the priority accorded intra-European economic relations.</p>
    </div>
    """

    /// `frus1977-80v28/d189`'s attachment, a Bureau of Personnel table, trimmed to four of its 48
    /// rows. Its caption is italic and holds a term found nowhere else in the table (`t_FSO_1`),
    /// and a `<pb/>` sits between two of its rows — the one child besides rows and a head a table
    /// carries in the corpus (1,557 of them). The attachment's head is shortened and its note
    /// dropped.
    static let v28d189 = """
    <div type="document" subtype="historical-document" n="189" xml:id="d189">
      <frus:attachment>
        <head>Table Prepared in the Bureau of Personnel</head>
        <table cols="5">
          <head><hi rend="italic"><gloss target="#t_FSO_1">FSO</gloss> EXAMINATION STATISTICS: 1971–6</hi></head>
          <row>
            <cell/>
            <cell>Total</cell>
            <cell>Men</cell>
            <cell>Women</cell>
            <cell>% Women</cell>
          </row>
          <row>
            <cell cols="5"><hi rend="italic">December 1971 Exam</hi></cell>
          </row>
          <row>
            <cell>Passed Written</cell>
            <cell role="num">1,322</cell>
            <cell role="num">1,096</cell>
            <cell role="num">226</cell>
            <cell>17%</cell>
          </row>
          <pb facs="0776" n="747" xml:id="pg_747"/>
          <row>
            <cell>Took Oral</cell>
            <cell role="num">946</cell>
            <cell role="num">797</cell>
            <cell role="num">149</cell>
            <cell>16%</cell>
          </row>
        </table>
      </frus:attachment>
    </div>
    """

    /// The printed label of every footnote body in `model`, in collection order.
    static func footnoteLabels(_ model: FRUSDocumentRenderModel) -> [String?] {
        model.footnotes.map { node -> String? in
            guard case .footnoteBody(_, _, _, _, let label, _) = node else { return "not a footnote body" }
            return label
        }
    }

    /// The `<table class="frus-table">…</table>` element of `html` that contains `needle`.
    static func table(containing needle: String, in html: String) throws -> String {
        let hit = try #require(html.range(of: needle), "\"\(needle)\" is not in the HTML")
        let open = try #require(html.range(of: "<table class=\"frus-table\">", options: .backwards,
                                           range: html.startIndex..<hit.lowerBound),
                                "\"\(needle)\" is not inside a table")
        let close = try #require(html.range(of: "</table>", range: hit.upperBound..<html.endIndex))
        return String(html[open.lowerBound..<close.upperBound])
    }
}

/// #1495: the converter kept only a `<table>`'s rows, so the caption the volume printed above
/// 216 tables — its title, and often its UNITS (`Millions of Dollars`) — reached no renderer,
/// and a footnote in a caption lost its marker and its body, leaving a gap in the printed
/// numbering (9 notes, in 7 documents).
///
/// Every test runs the real parser, converter and serializer over corpus markup. The caption is
/// drawn under `data-skip` and is not flat text, as a list's heading is not (#1371): the
/// flat text — hashed into `renderingVersion` and stored as `body_hash` — must not move.
@Suite("A table's printed caption and the footnotes in it reach the reader (#1495)")
struct TableCaptionTests {

    private func html(_ model: FRUSDocumentRenderModel) -> String {
        FRUSRenderNodeHTMLSerializer().serialize(model)
    }

    @Test("d355's caption, Millions of Dollars, is drawn above its first row, offset-invisible, and renderingVersion does not move")
    func d355CaptionIsDrawnAboveItsRows() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355)
        let out = html(model)
        #expect(out.contains("<caption class=\"table-caption\" data-skip=\"1\">Millions of Dollars</caption>"),
                "the caption must be the table's own <caption>, under data-skip: \(out)")
        let table = try TableCaptionFixtures.table(containing: "Year Ending March 20, 1950", in: out)
        let missing = ListShapeFixtures.firstOutOfOrder(
            ["<table class=\"frus-table\"><caption", "Millions of Dollars", "</caption><tr>",
             "Year Ending March 20, 1950", "Requirements", "Imports", "Requirement for Emergency Aid"],
            in: table)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from d355's table, or out of order: \(table)")

        // Not flat text: the hash every stored highlight carries is the one d355 had while the
        // reader dropped its caption.
        let baseline = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355WithoutCaption)
        #expect(TableCaptionFixtures.d355WithoutCaption != TableCaptionFixtures.d355)
        #expect(ASTToRenderNodeConverter.kVersion == "1.2")
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: baseline))
        // The index stores that hash as `body_hash`, through the same conversion: no re-index.
        #expect(IndexingPipeline.bodyHash(for: try await ListShapeFixtures.ast(TableCaptionFixtures.d355))
                == IndexingPipeline.bodyHash(for: try await ListShapeFixtures.ast(TableCaptionFixtures.d355WithoutCaption)))
        let flat = buildFlatText(from: model)
        #expect(flat.contains("Year Ending March 20, 1950"), "the cells must still be flat text")
        #expect(!flat.contains("Millions of Dollars"), "the caption entered the flat text")
    }

    @Test("A note in d71's caption keeps its marker and its body, numbered between footnotes 6 and 8")
    func d71CaptionNoteIsCollectedInOrder() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d71)
        #expect(TableCaptionFixtures.footnoteLabels(model) == ["1", "6", "7", "8"],
                "footnotes collected: \(TableCaptionFixtures.footnoteLabels(model))")
        #expect(flatText(of: model.footnotes).contains("Brzezinski added the columns labeled “SU Strike”"),
                "footnote 7's body was lost")
        // The index never lost it: it harvests footnotes from the AST, where the head always was, so
        // the stored footnotes do not change and nothing re-indexes. (The head's source note is
        // not an editorial footnote and is not harvested.)
        let harvested = IndexingPipeline.collectBodyFootnotes(
            from: try await ListShapeFixtures.ast(TableCaptionFixtures.d71).nodes)
        #expect(harvested.map(\.label) == ["6", "7", "8"], "the index's harvest: \(harvested.map(\.label))")

        let out = html(model)
        let missing = ListShapeFixtures.firstOutOfOrder([
            "popovertarget=\"fn-x-d71fn6\"",
            "<caption class=\"table-caption\" data-skip=\"1\">Table 1 Weapons Allocation Priorities",
            "popovertarget=\"fn-x-d71fn7\"", "</caption>",
            "Day-to-day alert", "1. Recovery resources",
            "popovertarget=\"fn-x-d71fn8\"",
            "id=\"fn-x-d71fn7\"", "Brzezinski added the columns",   // the popover
            "id=\"fnote-x-d71fn7\"", "Brzezinski added the columns", // the Footnotes list
        ], in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the serialized d71, or out of order")
        // The marker sits INSIDE the caption, where the volume printed it.
        let caption = try #require(out.firstMatch(of: /<caption[^>]*>(.*?)<\/caption>/),
                                   "d71's table has no caption")
        #expect(caption.output.1.contains("popovertarget=\"fn-x-d71fn7\""),
                "footnote 7's marker is not in the caption: \(caption.output.1)")
    }

    @Test("ve07 d85's three-line caption prints its lines in order, and its note a is numbered before the cell's note b")
    func ve07d85MultiLineCaption() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.ve07d85)
        #expect(TableCaptionFixtures.footnoteLabels(model) == ["a", "b"],
                "footnotes collected: \(TableCaptionFixtures.footnoteLabels(model))")
        let table = try TableCaptionFixtures.table(containing: "Authorized", in: html(model))
        let missing = ListShapeFixtures.firstOutOfOrder([
            "<caption class=\"table-caption\" data-skip=\"1\">PAKISTAN: FOREIGN AID BY COUNTRY",
            "popovertarget=\"fn-x-d85fn11\"", "<br>1948–1969<br>(billion US dollars)</caption>",
            "Authorized", "Free World Consortium", "popovertarget=\"fn-x-d85fn12\"", "7.06",
        ], in: table)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the table, or out of order: \(table)")

        // The caption's two line breaks are not flat text either: a `<br>` walked as flat text
        // counts a character.
        let baseline = try await ListShapeFixtures.renderModel(TableCaptionFixtures.ve07d85WithoutCaption)
        #expect(!TableCaptionFixtures.ve07d85WithoutCaption.contains("PAKISTAN"))
        #expect(buildFlatText(from: model) == buildFlatText(from: baseline))
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: baseline))
    }

    @Test("v41 d86's footnote table prints its caption in the popover and in the Footnotes list")
    func v41d86FootnoteTableCaption() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.v41d86)
        #expect(TableCaptionFixtures.footnoteLabels(model) == ["7"])
        let out = html(model)
        let caption = "<caption class=\"table-caption\" data-skip=\"1\">SELECTED COUNTRIES’ TRADE WITH THE US AND THE "
        let missing = ListShapeFixtures.firstOutOfOrder([
            "id=\"fn-x-d86fn7\"", caption, "OF NINE*", "</caption>", "Country", "Spain",
            "All data are for calendar year 1971",
            "id=\"fnote-x-d86fn7\"", caption, "Country", "Spain",
        ], in: out)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the footnote's two renderings, or out of order")
        #expect(out.components(separatedBy: "SELECTED COUNTRIES").count - 1 == 2,
                "the caption must print once in the popover and once in the Footnotes list")
    }

    @Test("A second <head> in one table is kept after the first, on a line of its own — no table in the corpus has two")
    func aSecondCaptionHeadIsKept() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <table><head>Table 3</head><head>(In millions of dollars)</head><row><cell>Imports</cell><cell>192</cell></row></table>
        </div>
        """)
        let table = try TableCaptionFixtures.table(containing: "Imports", in: html(model))
        #expect(table.contains("<caption class=\"table-caption\" data-skip=\"1\">Table 3<br>(In millions of dollars)</caption>"),
                "\(table)")
        #expect(buildFlatText(from: model) == "Imports192")
    }

    /// The converter keeps a table's head and rows and nothing else. The corpus's only other
    /// table child is a `<pb/>` between rows, and the reader drew none of them before #1495
    /// either: an HTML parser moves a `<span>` between two `<tr>`s out in front of the table.
    @Test("A <pb/> between two rows of a captioned table draws no page break inside the table and loses no row")
    func aPageBreakBetweenRowsIsStillDropped() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.v28d189)
        let table = try TableCaptionFixtures.table(containing: "Passed Written", in: html(model))
        let missing = ListShapeFixtures.firstOutOfOrder([
            "<caption class=\"table-caption\" data-skip=\"1\"><em>", "FSO", "EXAMINATION STATISTICS: 1971–6</em></caption>",
            "% Women", "December 1971 Exam", "Passed Written", "Took Oral",
        ], in: table)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from the table, or out of order: \(table)")
        #expect(!table.contains("page-break"), "a page break was drawn inside the table: \(table)")
    }

    /// 41 `<gloss>`es and 1 `<persName>` sit in table captions outside a note (2 and 1 more sit in
    /// captions' notes, which the scan reaches as footnote bodies); a link the reader draws there
    /// must resolve when tapped, so the scheme handler's lookup tables have to be built from the
    /// caption too. `t_FSO_1` is linked nowhere in d189's table but its caption.
    /// Converts `documentXML` with lookups that answer every person and term ref, off the main
    /// actor — the lookups are built here so no main-actor closure crosses into the parse.
    private static func modelWithLookups(_ documentXML: String) async throws -> FRUSDocumentRenderModel {
        let converter = ASTToRenderNodeConverter(
            personLookup: { ref in PersonEntry(ref: ref, name: "Person \(ref)") },
            glossLookup: { ref in GlossEntry(ref: ref, term: "Term \(ref)", definition: nil) })
        return try await ListShapeFixtures.renderModel(documentXML, converter: converter)
    }

    @Test("A term linked only in a table's caption resolves when tapped")
    @MainActor
    func aTermInACaptionResolves() async throws {
        let model = try await Self.modelWithLookups(TableCaptionFixtures.v28d189)
        let handler = FRUSURLSchemeHandler()
        handler.register(model: model)
        var glosses: [GlossEntry?] = []
        handler.onGlossTap = { glosses.append($0) }
        handler.dispatch(url: try #require(URL(string: "frusexplorer://gloss/t_FSO_1")))
        #expect(glosses.map { $0?.ref } == ["t_FSO_1"], "the caption's term did not resolve: \(glosses)")
    }

    /// The collection exporter's plain-text walk reaches document heads and datelines; no table
    /// sits in either in the corpus, so this is the only thing that reaches the branch.
    @Test("The export's plain-text walk prints a table's caption before its rows")
    func plainTextWalkPrintsTheCaption() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355)
        let table = try #require(model.bodyNodes.first { if case .tableBlock = $0 { return true }; return false })
        let text = CollectionContentResolver.renderNodePlainText(table)
        #expect(text.hasPrefix("Millions of Dollars\n"), "\(text.debugDescription)")
        let missing = ListShapeFixtures.firstOutOfOrder(
            ["Millions of Dollars", "Year Ending March 20, 1950", "Requirement for Emergency Aid"], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from \"\(text)\", or out of order")

        // A table with no caption opens on its first row, with no empty line above it.
        let bare = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355WithoutCaption)
        let bareTable = try #require(bare.bodyNodes.first { if case .tableBlock = $0 { return true }; return false })
        let bareText = CollectionContentResolver.renderNodePlainText(bareTable)
        #expect(bareText.hasPrefix(" | Year Ending March 20, 1950"), "\(bareText.debugDescription)")
    }

    /// A highlight's stored passage and an excerpt are cut from `buildFlatTextBlocks`, which must
    /// visit exactly the characters `buildFlatText` does — or every passage after a captioned
    /// table is sliced at offsets that index a different string.
    @Test("A highlight or excerpt from the paragraph into a captioned table keeps the cells' words without the caption")
    func excerptsOmitTheCaption() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355)
        // The walker must be reached with the caption present, or the rest proves nothing.
        #expect(html(model).contains("Millions of Dollars"), "the fixture's caption is not drawn")
        let flat = buildFlatText(from: model)
        let blocks = buildFlatTextBlocks(from: model)
        #expect(blocks.joined() == flat, "the block partition must be the flat text cut into blocks, nothing more")
        #expect(!blocks.contains { $0.contains("Millions of Dollars") }, "the caption entered a block: \(blocks)")
        let start = try #require(flat.range(of: "the following table:"))
        let end = try #require(flat.range(of: "Year Ending March 20, 1950"))
        let excerpt = try #require(flatTextExcerpt(
            from: model,
            start: flat.utf16.distance(from: flat.utf16.startIndex, to: start.lowerBound),
            end: flat.utf16.distance(from: flat.utf16.startIndex, to: end.upperBound)))
        #expect(excerpt == "the following table:\n\nYear Ending March 20, 1950", "excerpt: \(excerpt.debugDescription)")
    }
}

// MARK: - Editorial Note Tests

@Suite("Editorial Note Parsing")
struct EditorialNoteTests {

    @Test("Parser: <div type='editorialNote'> produces .editorialNote node")
    func editorialNote() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <div type="editorialNote"><p>This is an editorial note.</p></div>
          <p>Body text.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .editorialNote = $0 { return true }; return false
        })
    }
}

// MARK: - Inline Editorial Mark Tests

@Suite("Inline Editorial Marks")
struct InlineEditorialMarkTests {

    @Test("Parser: <supplied> produces .supplied node")
    func suppliedElement() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Text <supplied>inserted</supplied> text.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .supplied = $0 { return true }; return false
        })
    }

    @Test("Parser: <sic> produces .sic node")
    func sicElement() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>An <sic>errror</sic> in the source.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .sic = $0 { return true }; return false
        })
    }

    @Test("Parser: <corr> produces .corr node")
    func corrElement() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>The <corr>correction</corr> is applied.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .corr = $0 { return true }; return false
        })
    }

    @Test("Parser: <lb/> produces .lineBreak node")
    func lineBreak() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Line one.<lb/>Line two.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .lineBreak = $0 { return true }; return false
        })
    }
}

// MARK: - Figure Tests

@Suite("Figure Parsing")
struct FigureTests {

    @Test("Parser: <figure><graphic url='img.png'/></figure> captures graphic URL")
    func figureWithGraphic() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <figure><graphic url="img.png"/><p>Caption</p></figure>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .figure(let g, _) = $0 { return g == "img.png" }
            return false
        })
    }
}

// MARK: - Persons / Terms Parsing Tests

@Suite("Persons and Terms Parsing")
struct PersonsTermsTests {

    @Test("parsePersons: extracts entries from <listPerson>")
    func parsePersonsListPerson() async throws {
        let url = try makeVolumeFixture(body: "", front: """
        <div type="persons">
          <list>
            <item xml:id="Kissinger">Kissinger, Henry A.: Assistant to the President</item>
            <item xml:id="Nixon">Nixon, Richard M.: President</item>
          </list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let persons = try await parser.parsePersons(volumeURL: url)
        #expect(persons.count == 2)
        #expect(persons.contains { $0.ref == "Kissinger" && $0.name.contains("Kissinger") })
    }

    @Test("parseTerms: extracts entries from <div type='terms'>")
    func parseTermsDiv() async throws {
        let url = try makeVolumeFixture(body: "", front: """
        <div type="terms">
          <list>
            <item xml:id="NATO">NATO: North Atlantic Treaty Organization</item>
            <item xml:id="NSC">NSC: National Security Council</item>
          </list>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let terms = try await parser.parseTerms(volumeURL: url)
        #expect(terms.count == 2)
        #expect(terms.contains { $0.ref == "NATO" && $0.term.contains("NATO") })
    }

    @Test("parsePersons: returns empty array when no persons div present")
    func parsePersonsEmpty() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>No persons here.</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let persons = try await parser.parsePersons(volumeURL: url)
        #expect(persons.isEmpty)
    }
}

// MARK: - Regression: All Session 06 Tests Continue to Pass

@Suite("Session 07 Regression: core element handling unchanged")
struct RegressionTests {

    @Test("Regression: <p> still produces .paragraph")
    func paragraphRegression() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Hello</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .paragraph = $0 { return true }; return false
        })
    }

    @Test("Regression: <note type='source'> still produces .footnote(.source)")
    func footnoteRegression() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Text<note type="source" xml:id="fn1">Source note.</note></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        #expect(containsCase(in: docs.flatMap(\.nodes)) {
            if case .footnote(_, .source, _, _) = $0 { return true }; return false
        })
    }
}

// MARK: - Figures (#1516)

/// Real corpus figures, shared by `FigureCaptionTests` and `ElementSpaceTests` below, the web-view
/// tests in `FRUSOffsetEngineTests.swift` (`FigureReaderTests`), `FigureExportTests` in
/// `CollectionTests.swift` and the image-store tests in `DownloadManagerTests.swift`, so those
/// suites measure the same markup.
///
/// Measured at corpus `8e5da08c1` over the 553 manifest volumes (lxml; the scripts are in the
/// session's `durable/w49/work/READ/`): 1,035 `<figure>`s, 532 of them inside a
/// `div[@type="document"]` — 426 a graphic alone, 50 a head and a graphic, 32 a graphic and
/// paragraphs, 20 empty, 2 a graphic and a `<figDesc>`, 1 paragraphs alone, 1 a head and a
/// paragraph with no graphic. Of the 503 outside a document, 403 sit on a title page, which no
/// surface of the app draws, and 20 hold an embedded video player (three public-diplomacy
/// volumes). No figure holds two graphics, none is nested in another and none holds a `<note>`.
///
/// Each fixture is the volume's own markup, trimmed: prose is cut, and the source XML's
/// hard-wrapped indentation is joined onto single lines, which the parser's whitespace
/// normalisation makes equivalent.
enum FigureFixtures {

    /// `frus1946v01/d587`, Annex “A”: a map whose `<head>` is its printed title and also titles
    /// the table after it, then Appendix “B”'s two maps — the second head broken over two lines.
    /// Until #1516 the reader printed `figure_1162` where the title belongs.
    static let d587 = """
    <div type="document" subtype="historical-document" n="587" xml:id="d587">
      <head>587. Memorandum by the Joint Chiefs of Staff</head>
      <frus:attachment>
        <head><hi rend="smallcaps">Appendix</hi> “A”</head>
        <p rend="center">Annex “A” to Appendix “A”</p>
        <figure>
          <head><hi rend="smallcaps">Locations at Which Military Air Transit Rights Are Desired</hi></head>
          <graphic url="figure_1162"/>
        </figure>
        <table cols="2">
          <row><cell>Location</cell><cell>Rights desired</cell></row>
          <row><cell>Azores</cell><cell>Transit and technical stop</cell></row>
        </table>
      </frus:attachment>
      <frus:attachment>
        <head><hi rend="smallcaps">[Appendix “B”]</hi></head>
        <figure>
          <head>Military Air Transit Requirements (Eastern Hemisphere)</head>
          <graphic url="figure_1163"/>
        </figure>
        <pb facs="1166" n="[]" xml:id="pg-seq-1166"/>
        <figure>
          <head>Military Air Transit Requirements (Western Hemisphere – Pacific) <lb/> Revised, 21 January 1946</head>
          <graphic url="figure_1166"/>
        </figure>
      </frus:attachment>
    </div>
    """

    /// `d587` with every figure removed — the markup whose flat text restoring the captions must
    /// not move.
    static var d587WithoutFigures: String { removingFigures(from: d587) }

    /// `frus1951v03p1/d289`: two of its nine photo plates, each captioned by a `<p>` naming its
    /// subject — the second by a linked name alone.
    static let d289 = """
    <div type="document" subtype="historical-document" n="289" xml:id="d289">
      <p>The President has asked me to go to Europe and discuss with you the situation that has developed in Washington with respect to the Command problem.</p>
      <figure>
        <graphic url="figure_0584"/>
        <p>Secretary of State <persName corresp="#p_ADG1">Dean Acheson</persName></p>
      </figure>
      <pb facs="0585" n="[547]" xml:id="pg_547"/>
      <figure>
        <graphic url="figure_0585"/>
        <p><persName corresp="#p_HWA1">W. Averell Harriman</persName></p>
      </figure>
      <p>I have discussed the matter fully with General Marshall.</p>
    </div>
    """

    /// `d289` with its figures removed.
    static var d289WithoutFigures: String { removingFigures(from: d289) }

    /// `frus1864p1/d9`: a sketch the sentence before it points at ("thus:"), a graphic alone — 426
    /// of the 532 figures in documents are.
    static let d9 = """
    <div type="document" subtype="historical-document" n="9" xml:id="d9">
      <p>There are besides four diagonal pieces to strengthen the former and keep it in its place, thus:</p>
      <figure n="1" xml:id="figure1">
        <graphic url="figure1"/>
      </figure>
      <p>The said tranverse beam and diagonals are made movable so they can be taken out and replaced at pleasure.</p>
    </div>
    """

    /// `frus1881/d143`: an empty `<figure/>` standing for printed Chinese characters inside a
    /// sentence — 15 of the corpus's 20 empty figures are in this volume. history.state.gov prints
    /// nothing for one, and so does the app (owner decision D3c).
    static let d143 = """
    <div type="document" subtype="historical-document" n="143" xml:id="d143">
      <p>Without regard to actual superiority or inferiority of relative rank, the characters <figure/> “to correspond officially” should be used, the idea being to avoid the appearance of subordination.</p>
    </div>
    """

    /// `frus1897/d178`: a shipper's mark drawn inside a table cell (24 in the document, 45 figures
    /// in cells corpus-wide).
    static let d178 = """
    <div type="document" subtype="historical-document" n="178" xml:id="d178">
      <table cols="3">
        <row>
          <cell role="num">Jan. 11</cell>
          <cell>1 piece of bacon (short fat backs).</cell>
          <cell>Case <figure><graphic url="figure_0222"/></figure> 17</cell>
        </row>
      </table>
    </div>
    """

    /// `frus1969-76ve16/d77`: a chart INSIDE a paragraph's sentence, captioned by a `<p>`, and a
    /// later figure that is a caption alone ("Figure 2", its graphic not encoded).
    static let d77 = """
    <div type="document" subtype="historical-document" n="77" xml:id="d77">
      <p>2. <persName corresp="#p_AGS_1">Allende</persName>’s policies have largely succeeded, thereby boosting the administration’s popular support. <pb facs="0427" n="387" xml:id="pg_387"/>
        <figure xml:id="d77_fig01">
          <graphic url="frus1969-76ve16_d77_fig01"/>
          <p>CHILE: Cost of Living Indexes</p>
        </figure> A strict price freeze and wage increases have sharply increased consumer demand.</p>
      <pb facs="0428" n="388" xml:id="pg_388"/>
      <figure>
        <p>CHILE: Trends in Money Supply, Central Bank Credit<lb/>to the Public Sector, and Consumer Prices Figure 2</p>
      </figure>
      <p>4. <persName corresp="#p_AGS_1">Allende</persName> has emphasized rapid expropriation of the remaining large farms.</p>
    </div>
    """

    /// `d77` with its figures removed.
    static var d77WithoutFigures: String { removingFigures(from: d77) }

    /// `frus1943CairoTehran/d278`: a facsimile described by a `<figDesc>` — 2 of the figures in
    /// documents carry one.
    static let d278 = """
    <div type="document" subtype="historical-document" n="278" xml:id="d278">
      <p>The Generalissimo raised the question of the Chinese-Soviet frontier.</p>
      <pb facs="0468" n="[Note]" xml:id="pg-seq-0468"/>
      <figure>
        <graphic url="figure_0468"/>
        <figDesc>Notes by Hopkins of a Conversation With Chiang at Cairo (see facing page)</figDesc>
      </figure>
      <pb facs="0469" n="367" xml:id="pg_367"/>
    </div>
    """

    /// `frus1917-72PubDipv06`, Appendix A.1: a title frame (a graphic alone), then the Online
    /// Video Supplement — a figure whose `<head>` is "Reel 1" and whose content is an XHTML
    /// Brightcove player. The corpus holds 20 such players, in three volumes, all in sections
    /// like this one rather than in document divs. The app cannot play them.
    static let appendix1 = """
    <div type="section" subtype="historical-document" xml:id="appendix-1">
      <head>Appendix A.1 <hi rend="italic">Invitation to Pakistan</hi></head>
      <figure>
        <graphic url="Appendix A.1" width="26pc"/>
      </figure>
      <div type="online-supplement">
        <head>Online Video Supplement</head>
        <figure>
          <head>Reel 1</head>
          <div style="position: relative; display: block; max-width: 530px;" xmlns="http://www.w3.org/1999/xhtml">
            <div style="padding-top: 56.25%;">
              <iframe allowfullscreen="allowfullscreen" src="//players.brightcove.net/1705665025/HJ8lQG1Eg_default/index.html?videoId=5625814201001" style="position: absolute; top: 0px; right: 0px; bottom: 0px; left: 0px; width: 100%; height: 100%;"/>
            </div>
          </div>
        </figure>
      </div>
      <div type="online-supplement">
        <head>Transcript</head>
        <p>[MUSIC PLAYING]</p>
      </div>
    </div>
    """

    /// `frus1861/d2`'s head and dateline, as the volume wraps them — `<placeName>` and `<date>`
    /// with only a line break between them — and a sentence in two of the corpus's commonest
    /// shapes: a `<gloss>` then a `<persName>` in a paragraph (4,439 runs), and a `<note>` then an
    /// inline element (in a paragraph: 3,417 before a `<persName>`, 836 before a `<hi>`).
    static let d2 = """
    <div type="document" subtype="historical-document" n="2" xml:id="d2">
      <head><hi rend="italic">Mr. <persName type="from">Black</persName></hi> (<hi rend="italic">Secretary of State</hi>) <hi rend="italic">to all the <gloss type="to">ministers of the United States</gloss>.</hi></head>
      <opener><dateline rendition="#right"><hi rend="smallcaps">Department of State</hi>,<lb/><placeName><hi rend="italic">Washington</hi>,</placeName>
          <date calendar="gregorian" when="1861-02-28"><hi rend="italic">February</hi> 28, 1861</date>.</dateline></opener>
      <p rend="center">CIRCULAR.</p>
      <p>The telegram was read by <gloss target="#t_SecState_1">SecState</gloss>
          <persName corresp="#p_RD_1">Rusk</persName><note n="1" xml:id="d2fn1">See Document 1.</note>
          <hi rend="italic">in extenso</hi>.</p>
    </div>
    """

    /// `d2` with the whitespace between its sibling elements removed: the markup the reader's
    /// flat text has always been equivalent to.
    static var d2Glued: String {
        d2.replacing(/>\s+</, with: "><")
    }

    /// `xml` without its `<figure>` elements (none in the corpus nests another).
    static func removingFigures(from xml: String) -> String {
        xml.replacing(/<figure\b[^>]*\/>/, with: "")
            .replacing(/<figure\b[^>]*>[\s\S]*?<\/figure>/, with: "")
    }

    /// What a reader sees of `html`: its text with every tag removed — a block's edge read as a
    /// space, an inline element's as nothing — footnote popovers and the Footnotes list left out,
    /// and whitespace collapsed as a browser collapses it.
    static func visibleText(_ html: String) -> String {
        html.replacing(/<aside\b[\s\S]*?<\/aside>/, with: "")
            .replacing(/<section class="footnotes-section">[\s\S]*<\/section>/, with: "")
            .replacing(/<br>/, with: "\n")
            .replacing(/<\/?(p|div|figure|figcaption|h2|h3|table|caption|tr|td|ul|ol|li|section)\b[^>]*>/, with: " ")
            .replacing(/<[^>]+>/, with: "")
            .replacing("&amp;", with: "&").replacing("&#39;", with: "'").replacing("&quot;", with: "\"")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// How many times `needle` occurs in `text`.
    static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}

/// #1516: the converter kept a `<figure>`'s graphic name and dropped everything else it holds, so
/// the reader printed the image's FILE NAME as its caption on 510 figures (`figure_1162`) and
/// lost 51 printed heads, 36 caption paragraphs and 2 descriptions.
///
/// Every test runs the real parser, converter and serializer over corpus markup, with the
/// serializer's default image mode — no image store — so each figure that names an image prints
/// the placeholder the reader shows while the image is not on the device. A figure's text is
/// drawn under `data-skip` and is not flat text (owner decision D3a): the flat text — hashed into
/// `renderingVersion` and stored as `body_hash` — must not move, so nothing re-indexes and no
/// stored highlight goes stale. `body_text` already held the words, since the index reads the AST.
@Suite("A figure prints its head and paragraphs as captions, never its file name (#1516)")
struct FigureCaptionTests {

    private func html(_ model: FRUSDocumentRenderModel) -> String {
        FRUSRenderNodeHTMLSerializer().serialize(model)
    }

    /// Asserts the figures of `fixture` are no flat text: its hash is the one the document has
    /// with every figure removed, in the reader's space and in the index's.
    private func expectFlatTextUnmoved(_ fixture: String, without: String) async throws {
        #expect(fixture != without, "the control fixture is the fixture itself")
        let model = try await ListShapeFixtures.renderModel(fixture)
        let baseline = try await ListShapeFixtures.renderModel(without)
        #expect(ASTToRenderNodeConverter.kVersion == "1.2")
        #expect(buildFlatText(from: model) == buildFlatText(from: baseline))
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: baseline))
        #expect(IndexingPipeline.bodyHash(for: try await ListShapeFixtures.ast(fixture))
                == IndexingPipeline.bodyHash(for: try await ListShapeFixtures.ast(without)))
    }

    @Test("d587's maps print their printed titles above the image's place, and no file name")
    func headIsTheCaption() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d587)
        let out = html(model)
        let text = FigureFixtures.visibleText(out)
        let missing = ListShapeFixtures.firstOutOfOrder([
            "Annex “A” to Appendix “A”",
            "Locations at Which Military Air Transit Rights Are Desired", "[Figure]",
            "Location", "Azores",
            "Military Air Transit Requirements (Eastern Hemisphere)", "[Figure]",
            "Military Air Transit Requirements (Western Hemisphere – Pacific)", "Revised, 21 January 1946", "[Figure]",
        ], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from d587, or out of order: \(text)")
        #expect(!out.contains("figure_116"), "an image's file name is printed: \(out)")
        // The head keeps its small capitals and its line break.
        #expect(out.contains("<span class=\"small-caps\">Locations at Which Military Air Transit Rights Are Desired</span>"))
        #expect(out.contains("(Western Hemisphere – Pacific) <br> Revised, 21 January 1946"), "\(out)")
        // Drawn, and no flat text.
        let flat = buildFlatText(from: model)
        #expect(flat.contains("Azores"), "the table's cells must still be flat text")
        #expect(!flat.contains("Locations at Which"), "a figure's head entered the flat text")
        #expect(!flat.contains("[Figure]"), "the placeholder entered the flat text")
        try await expectFlatTextUnmoved(FigureFixtures.d587, without: FigureFixtures.d587WithoutFigures)
    }

    @Test("d289's photographs print their paragraphs as captions under the image's place, the linked name still a link")
    func paragraphsAreCaptions() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d289)
        let out = html(model)
        let text = FigureFixtures.visibleText(out)
        let missing = ListShapeFixtures.firstOutOfOrder([
            "with respect to the Command problem.",
            "[Figure]", "Secretary of State Dean Acheson",
            "[Figure]", "W. Averell Harriman",
            "I have discussed the matter fully",
        ], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from d289, or out of order: \(text)")
        #expect(!out.contains("figure_058"), "an image's file name is printed: \(out)")
        #expect(out.contains("<a class=\"pers-name\" href=\"frusexplorer://person/p_HWA1\">W. Averell Harriman</a>"),
                "the caption's name must stay a link: \(out)")
        let flat = buildFlatText(from: model)
        #expect(!flat.contains("Harriman") && !flat.contains("Acheson"), "a caption entered the flat text: \(flat)")
        try await expectFlatTextUnmoved(FigureFixtures.d289, without: FigureFixtures.d289WithoutFigures)
        // The index always held the words (it reads the AST), so search finds what the reader now shows.
        let body = IndexingPipeline.extractBodyText(from: try await ListShapeFixtures.ast(FigureFixtures.d289).nodes)
        #expect(body.contains("W. Averell Harriman"), "body_text: \(body)")
    }

    /// `documentXML` converted with lookups that resolve every person and term it links. Built
    /// off the main actor, so no main-actor closure crosses into the parse.
    private static func modelWithLookups(_ documentXML: String) async throws -> FRUSDocumentRenderModel {
        let converter = ASTToRenderNodeConverter(
            personLookup: { ref in PersonEntry(ref: ref, name: "Person \(ref)") },
            glossLookup: { ref in GlossEntry(ref: ref, term: "Term \(ref)", definition: nil) })
        return try await ListShapeFixtures.renderModel(documentXML, converter: converter)
    }

    /// The reader draws a caption's name as a link, and a link resolves only if the scheme handler
    /// saw it when the model was registered: without the handler's `.figureBlock` case the page
    /// above is unchanged and the tap finds no one.
    @Test("A person or term linked in a figure's caption or head resolves when tapped")
    @MainActor
    func aLinkInACaptionResolvesWhenTapped() async throws {
        // d289's two photographs, each captioned with a linked name, and a figure whose head
        // links a term: nothing else in the document names these three.
        let model = try await Self.modelWithLookups(FigureFixtures.d289.replacing("</div>", with: """
            <figure><head>Chart of <gloss target="#t_NATO1">NATO</gloss> commands</head><graphic url="chart"/></figure></div>
            """))
        let handler = FRUSURLSchemeHandler()
        handler.register(model: model)
        var persons: [PersonEntry?] = []
        var glosses: [GlossEntry?] = []
        handler.onPersonTap = { persons.append($0) }
        handler.onGlossTap = { glosses.append($0) }
        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_ADG1")))
        handler.dispatch(url: try #require(URL(string: "frusexplorer://person/p_HWA1")))
        handler.dispatch(url: try #require(URL(string: "frusexplorer://gloss/t_NATO1")))
        #expect(persons.map { $0?.ref } == ["p_ADG1", "p_HWA1"], "a caption's person did not resolve: \(persons)")
        #expect(glosses.map { $0?.ref } == ["t_NATO1"], "a figure head's term did not resolve: \(glosses)")
    }

    @Test("A graphic alone prints the placeholder where the sketch belongs, once, and not its file name")
    func graphicAlonePrintsThePlaceholder() async throws {
        let out = html(try await ListShapeFixtures.renderModel(FigureFixtures.d9))
        let text = FigureFixtures.visibleText(out)
        #expect(text.contains("keep it in its place, thus: [Figure] The said tranverse beam"), "\(text)")
        #expect(FigureFixtures.count("[Figure]", in: text) == 1, "\(text)")
        #expect(!text.contains("figure1"), "the file name is printed: \(text)")
    }

    @Test("An empty figure prints nothing: the sentence around it reads on")
    func emptyFigurePrintsNothing() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d143)
        let out = html(model)
        #expect(!out.contains("figure"), "an empty figure left markup behind: \(out)")
        let text = FigureFixtures.visibleText(out)
        #expect(text.contains("the characters “to correspond officially” should be used"), "\(text)")
        #expect(!text.contains("[Figure]"), "an empty figure printed a placeholder: \(text)")
    }

    @Test("A figure in a table cell or inside a sentence is drawn inline, so the cell and the paragraph stay whole")
    func figureInsideALineStaysInline() async throws {
        let cell = html(try await ListShapeFixtures.renderModel(FigureFixtures.d178))
        #expect(FigureFixtures.visibleText(cell).contains("Case [Figure] 17"), "\(cell)")
        #expect(!cell.contains("<figure"), "a block <figure> inside a cell: \(cell)")

        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d77)
        let out = html(model)
        // A <figure> start tag closes an open <p> when the page is parsed, so the sentence's second
        // half would fall out of its paragraph: inside one, the figure is a <span>.
        let paragraph = try #require(out.firstMatch(of: /<p class="body">2\. [\s\S]*?<\/p>/)).output
        #expect(!paragraph.contains("<figure"), "a block <figure> inside a paragraph: \(paragraph)")
        #expect(paragraph.contains("A strict price freeze"), "the sentence's second half left its paragraph: \(paragraph)")
        let text = FigureFixtures.visibleText(out)
        let missing = ListShapeFixtures.firstOutOfOrder([
            "popular support.", "[Figure]", "CHILE: Cost of Living Indexes", "A strict price freeze",
            "CHILE: Trends in Money Supply, Central Bank Credit", "to the Public Sector, and Consumer Prices Figure 2",
            "4. Allende has emphasized",
        ], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from d77, or out of order: \(text)")
        // The caption-only figure names no image, so it prints no placeholder.
        #expect(FigureFixtures.count("[Figure]", in: text) == 1, "\(text)")
        try await expectFlatTextUnmoved(FigureFixtures.d77, without: FigureFixtures.d77WithoutFigures)
    }

    @Test("A figure's description prints as its caption")
    func descriptionIsACaption() async throws {
        let out = html(try await ListShapeFixtures.renderModel(FigureFixtures.d278))
        let text = FigureFixtures.visibleText(out)
        #expect(text.contains("[Figure] Notes by Hopkins of a Conversation With Chiang at Cairo (see facing page)"), "\(text)")
        #expect(!text.contains("figure_0468"), "\(text)")
    }

    @Test("An embedded video prints its head, and none of the player's markup")
    func videoPrintsItsHead() async throws {
        let out = html(try await ListShapeFixtures.renderModel(FigureFixtures.appendix1))
        let text = FigureFixtures.visibleText(out)
        let missing = ListShapeFixtures.firstOutOfOrder(
            ["Appendix A.1", "[Figure]", "Online Video Supplement", "Reel 1", "Transcript", "[MUSIC PLAYING]"],
            in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing from Appendix A.1, or out of order: \(text)")
        #expect(!out.contains("brightcove") && !out.contains("iframe"), "the player's markup is printed: \(out)")
        // The title frame names an image; the player names none, so it prints no placeholder.
        #expect(FigureFixtures.count("[Figure]", in: text) == 1, "\(text)")
    }
}

/// The READ lane's fold-in: the parser discards a whitespace-only run, which is right between two
/// blocks and wrong between two inline elements — `frus1861` d2's dateline read
/// "Washington,February 28, 1861". Measured at corpus `8e5da08c1` over the 553 manifest volumes:
/// 54,025 such runs sit between two inline elements inside documents — 14,193 of them a
/// `<placeName>` then a `<date>` in a dateline, in 9,884 documents; 4,439 a `<gloss>` then a
/// `<persName>` in a paragraph — and 7,337 more between a `<note>` and the inline element after it.
///
/// The space is drawn and is NOT flat text — the contract a list's label has (#1371) — so no
/// stored highlight goes stale and nothing re-indexes; `body_text`, the title and the dateline
/// already spaced these seams (`PrintedText`).
@Suite("A space between two inline elements is drawn, outside the flat text (READ fold-in)")
struct ElementSpaceTests {

    @Test("d2's dateline reads Washington, February 28, 1861 and its sentence SecState Rusk in extenso")
    func theSpaceIsDrawn() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d2)
        let out = FRUSRenderNodeHTMLSerializer().serialize(model)
        let text = FigureFixtures.visibleText(out)
        #expect(text.contains("Washington, February 28, 1861."), "\(text)")
        #expect(text.contains("read by SecState Rusk"), "\(text)")
        // The space after a footnote's marker is kept too: the marker's own label is not text.
        #expect(out.contains("</button><span class=\"element-space\" data-skip=\"1\"> </span><em>in extenso</em>"), "\(out)")
        // A line break needs no space after it, and the head's spaces were always in its text.
        #expect(!out.contains("<br><span class=\"element-space\""), "\(out)")
        #expect(text.contains("Mr. Black (Secretary of State) to all the ministers of the United States."), "\(text)")
    }

    @Test("The drawn spaces are no flat text: the hashes are the ones d2 has with the whitespace removed")
    func theFlatTextDoesNotMove() async throws {
        #expect(FigureFixtures.d2Glued != FigureFixtures.d2)
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d2)
        let glued = try await ListShapeFixtures.renderModel(FigureFixtures.d2Glued)
        let flat = buildFlatText(from: model)
        #expect(flat.contains("Washington,February 28, 1861."), "the flat text moved: \(flat)")
        #expect(flat == buildFlatText(from: glued))
        #expect(ASTToRenderNodeConverter.renderingVersion(for: model)
                == ASTToRenderNodeConverter.renderingVersion(for: glued))
        let ast = try await ListShapeFixtures.ast(FigureFixtures.d2)
        let gluedAST = try await ListShapeFixtures.ast(FigureFixtures.d2Glued)
        #expect(IndexingPipeline.bodyHash(for: ast) == IndexingPipeline.bodyHash(for: gluedAST))
        // What the index stores is built from the same AST and does not move either.
        #expect(IndexingPipeline.extractBodyText(from: ast.nodes) == IndexingPipeline.extractBodyText(from: gluedAST.nodes))
        #expect(IndexingPipeline.extractHeader(from: ast.nodes) == IndexingPipeline.extractHeader(from: gluedAST.nodes))
        #expect(IndexingPipeline.extractDateline(from: ast.nodes) == IndexingPipeline.extractDateline(from: gluedAST.nodes))
        #expect(IndexingPipeline.extractDateline(from: ast.nodes) == "Department of State, Washington, February 28, 1861.")
    }
}

// MARK: - Figure images in the page (#1516)

extension FigureFixtures {

    /// `frus1917-72PubDip`, Appendix A.5: the older player — an `<object>` between two
    /// `<script>`s, opened by a hidden `<div>` holding the player's size. 12 of the corpus's 20
    /// embedded videos are encoded this way, all in this volume. The parser passes an XHTML
    /// `<div>`'s content up to the figure, so the size reaches it as loose text.
    static let appendix5 = """
    <div type="section" subtype="historical-document" xml:id="appendix-5">
      <head>A.5. Movie Still</head>
      <figure>
        <graphic url="Document A.5" width="26pc"/>
      </figure>
      <div type="online-supplement">
        <head>Online Video Supplement</head>
        <figure>
          <head>Reel 1</head>
          <!-- Start of Brightcove Player -->
          <div style="display:none" xmlns="http://www.w3.org/1999/xhtml"> 298x530 </div>
          <script language="JavaScript" src="https://sadmin.brightcove.com/js/BrightcoveExperiences.js" type="text/javascript" xmlns="http://www.w3.org/1999/xhtml"/>
          <object class="BrightcoveExperience" id="myExperience3652221451001" xmlns="http://www.w3.org/1999/xhtml">
            <param name="bgcolor" value="#FFFFFF"/>
            <param name="playerID" value="1336128750001"/>
            <param name="@videoPlayer" value="3652221451001"/>
          </object>
          <script type="text/javascript" xmlns="http://www.w3.org/1999/xhtml">brightcove.createExperiences();</script>
          <!-- End of Brightcove Player -->
        </figure>
      </div>
    </div>
    """
}

/// Where a figure's image comes from, and what an embedded video prints, by who draws the page
/// (#1516): the reader names the image by a `frusexplorer://figure/` URL, the HTML export embeds
/// its bytes, and a serializer given neither prints the placeholder.
@Suite("The reader names a figure's image by its volume, an export embeds it, and a video links to its page (#1516)")
struct FigureImageMarkupTests {

    private func model(_ fixture: String, volume: String?) async throws -> FRUSDocumentRenderModel {
        try await ListShapeFixtures.renderModel(fixture, converter: ASTToRenderNodeConverter(volumeId: volume))
    }

    @Test("In the reader each image is an <img> served by the scheme handler, described by its head, its placeholder beside it")
    func theReaderNamesTheImage() async throws {
        let out = FRUSRenderNodeHTMLSerializer(figureImages: .reader)
            .serialize(try await model(FigureFixtures.d587, volume: "frus1946v01"))
        #expect(out.contains(
            "<img class=\"figure-image\" src=\"frusexplorer://figure/frus1946v01/figure_1162.png\" "
            + "alt=\"Locations at Which Military Air Transit Rights Are Desired\" "
            + "onerror=\"this.parentNode.classList.add('missing')\">"
            + "<span class=\"figure-missing\">[Figure]</span>"), "\(out)")
        #expect(FigureFixtures.count("<img class=\"figure-image\"", in: out) == 3)
        // The reader's page is what HTMLTemplate builds.
        let page = HTMLTemplate.build(model: try await model(FigureFixtures.d587, volume: "frus1946v01"),
                                      colorScheme: .light)
        #expect(page.contains("src=\"frusexplorer://figure/frus1946v01/figure_1166.png\""), "the reader's page names no image")
        #expect(page.contains(".frus-figure.missing img.figure-image"), "the reader's stylesheet has no figure rules")

        // A name with a space is one path component; the description, when there is one, is the alt text.
        let appendix = FRUSRenderNodeHTMLSerializer(figureImages: .reader)
            .serialize(try await model(FigureFixtures.appendix1, volume: "frus1917-72PubDipv06"))
        #expect(appendix.contains("src=\"frusexplorer://figure/frus1917-72PubDipv06/Appendix%20A.1.png\" alt=\"Figure\""),
                "\(appendix)")
        let described = FRUSRenderNodeHTMLSerializer(figureImages: .reader)
            .serialize(try await model(FigureFixtures.d278, volume: "frus1943CairoTehran"))
        #expect(described.contains(
            "alt=\"Notes by Hopkins of a Conversation With Chiang at Cairo (see facing page)\""), "\(described)")
    }

    @Test("A figure whose volume is unknown, or whose name is no file name, prints the placeholder and names no URL")
    func noURLWithoutAVolumeOrAFileName() async throws {
        let unknownVolume = FRUSRenderNodeHTMLSerializer(figureImages: .reader)
            .serialize(try await model(FigureFixtures.d9, volume: nil))
        #expect(!unknownVolume.contains("<img") && unknownVolume.contains("<span class=\"figure-missing\">[Figure]</span>"),
                "\(unknownVolume)")
        let unsafe = FRUSRenderNodeHTMLSerializer(figureImages: .reader).serialize(try await model("""
            <div type="document" xml:id="d1"><p>Text.</p><figure><graphic url="../../frus1946v01"/></figure></div>
            """, volume: "frus1946v01"))
        #expect(!unsafe.contains("<img") && unsafe.contains("[Figure]"), "\(unsafe)")
        #expect(FRUSURLSchemeHandler.figureURL(for: FigureImageName(volumeId: "..", graphic: "figure1")) == nil)
        // And the handler reads back exactly the names it wrote, ignoring a retry's query.
        let url = try #require(FRUSURLSchemeHandler.figureURL(
            for: FigureImageName(volumeId: "frus1917-72PubDip", graphic: "Document A.1")))
        #expect(url.absoluteString == "frusexplorer://figure/frus1917-72PubDip/Document%20A.1.png")
        let retried = try #require(URL(string: url.absoluteString + "?retry=1"))
        let named = try #require(FRUSURLSchemeHandler.figureImage(from: retried))
        #expect(named.volumeId == "frus1917-72PubDip" && named.fileName == "Document A.1.png")
        for notAFigure in ["frusexplorer://figure/only-one", "frusexplorer://doc/a/b.png",
                           "frusexplorer://figure/a/%2E%2E", "https://figure/a/b.png"] {
            let other = try #require(URL(string: notAFigure))
            #expect(FRUSURLSchemeHandler.figureImage(from: other) == nil, "\(notAFigure) was read as a figure's image")
        }
    }

    @Test("An export embeds the image's bytes, and prints the placeholder for one that is not on the device")
    func anExportEmbedsTheImage() async throws {
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02])
        let out = FRUSRenderNodeHTMLSerializer(figureImages: .embedded(load: { image in
            image == FigureImageName(volumeId: "frus1946v01", graphic: "figure_1162") ? bytes : nil
        })).serialize(try await model(FigureFixtures.d587, volume: "frus1946v01"))
        #expect(out.contains("<img class=\"figure-image\" src=\"data:image/png;base64,\(bytes.base64EncodedString())\" "
                             + "alt=\"Locations at Which Military Air Transit Rights Are Desired\">"), "\(out)")
        #expect(FigureFixtures.count("<img", in: out) == 1, "only the image on the device is embedded")
        #expect(FigureFixtures.count("<span class=\"figure-missing\">[Figure]</span>", in: out) == 2)
        #expect(!out.contains("frusexplorer://figure"), "an exported file cannot load from the app's scheme")
        #expect(!out.contains("onerror"), "an exported file runs no script")
    }

    @Test("A video links to its section's page on history.state.gov: through the app in the reader, directly in an export")
    func aVideoLinksToItsPage() async throws {
        let page = "https://history.state.gov/historicaldocuments/frus1917-72PubDipv06/appendix-1"
        let appendix = try await model(FigureFixtures.appendix1, volume: "frus1917-72PubDipv06")
        let reader = FRUSRenderNodeHTMLSerializer(figureImages: .reader).serialize(appendix)
        let link = try #require(reader.firstMatch(of: /<a class="cross-ref figure-video" href="([^"]+)">Watch on history\.state\.gov ↗<\/a>/),
                                "the reader draws no link: \(reader)")
        // The reader's link is a frusexplorer link, and the app hands its target to the browser.
        let href = try #require(URL(string: String(link.output.1)))
        #expect(href.scheme == "frusexplorer" && href.host == "doc")
        let tapped = await MainActor.run { () -> String? in
            let handler = FRUSURLSchemeHandler()
            var target: String?
            handler.onCrossRefTap = { tappedTarget, _, _ in target = tappedTarget }
            handler.dispatch(url: href)
            return target
        }
        #expect(tapped == page)
        let pageURL = try #require(URL(string: page))
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget(tapped ?? "", volumeId: nil) == .external(pageURL))
        let exported = FRUSRenderNodeHTMLSerializer().serialize(appendix)
        #expect(exported.contains("<a class=\"cross-ref figure-video\" href=\"\(page)\">Watch on history.state.gov ↗</a>"),
                "\(exported)")
        let text = FigureFixtures.visibleText(exported)
        let missing = ListShapeFixtures.firstOutOfOrder(
            ["Online Video Supplement", "Reel 1", "Watch on history.state.gov ↗", "Transcript"], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing, or out of order: \(text)")

        // Without its volume the link has no address, and the figure prints its head alone.
        let unplaced = FRUSRenderNodeHTMLSerializer().serialize(try await model(FigureFixtures.appendix1, volume: nil))
        #expect(!unplaced.contains("Watch on history.state.gov") && unplaced.contains("Reel 1"), "\(unplaced)")
    }

    @Test("The older <object> player prints its head and its link, and none of its hidden text or script")
    func theObjectPlayerPrintsNothingOfItsOwn() async throws {
        let out = FRUSRenderNodeHTMLSerializer().serialize(
            try await model(FigureFixtures.appendix5, volume: "frus1917-72PubDip"))
        let text = FigureFixtures.visibleText(out)
        let missing = ListShapeFixtures.firstOutOfOrder(
            ["A.5. Movie Still", "[Figure]", "Online Video Supplement", "Reel 1", "Watch on history.state.gov ↗"], in: text)
        #expect(missing == nil, "\"\(missing ?? "")\" is missing, or out of order: \(text)")
        for leaked in ["298x530", "brightcove", "createExperiences", "BrightcoveExperience"] {
            #expect(!out.contains(leaked), "the player's own \(leaked) is printed: \(text)")
        }
        #expect(out.contains("href=\"https://history.state.gov/historicaldocuments/frus1917-72PubDip/appendix-5\""))
    }

    @Test("A document's figure images are listed once each, in reading order, for an export to fetch")
    func aDocumentListsItsImages() async throws {
        let d587 = try await model(FigureFixtures.d587, volume: "frus1946v01")
        #expect(d587.figureImages == [
            FigureImageName(volumeId: "frus1946v01", graphic: "figure_1162"),
            FigureImageName(volumeId: "frus1946v01", graphic: "figure_1163"),
            FigureImageName(volumeId: "frus1946v01", graphic: "figure_1166"),
        ])
        // In a cell, in a list between two items, and twice over: found wherever a figure can sit.
        let nested = try await model("""
            <div type="document" xml:id="d1">
              <table><row><cell>Case <figure><graphic url="mark"/></figure> 17</cell></row></table>
              <list><item>One</item><figure><graphic url="between"/></figure><item>Two <figure><graphic url="mark"/></figure></item></list>
              <p>Text<note n="1" xml:id="d1fn1">A note <figure><graphic url="in_a_note"/><p>Its caption.</p></figure></note>.</p>
            </div>
            """, volume: "v")
        #expect(nested.figureImages.map(\.graphic) == ["mark", "between", "in_a_note"])
        #expect(try await model(FigureFixtures.d143, volume: "frus1881").figureImages.isEmpty)
    }
}

/// Where the parser keeps the whitespace between two elements, and where it must not
/// (`TEIParserDelegate.keepsElementSpace`): one fixture for each clause of the rule.
@Suite("The parser keeps a whitespace-only run only between two inline elements (READ fold-in)")
struct ElementSpaceRuleTests {

    /// How many `.elementSpace` nodes `body`'s document holds, at any depth.
    private func spaces(_ body: String) async throws -> Int {
        let ast = try await ListShapeFixtures.ast("<div type=\"document\" xml:id=\"d1\">\(body)</div>")
        func count(_ nodes: [FRUSASTNode]) -> Int {
            nodes.reduce(0) { total, node in
                if case .elementSpace = node { return total + 1 }
                return total + count(node.children)
            }
        }
        return count(ast.nodes)
    }

    /// The reader's visible text for `body`'s document.
    private func text(_ body: String) async throws -> String {
        let model = try await ListShapeFixtures.renderModel("<div type=\"document\" xml:id=\"d1\">\(body)</div>")
        return FigureFixtures.visibleText(FRUSRenderNodeHTMLSerializer().serialize(model))
    }

    @Test("Kept between two inline elements, whatever they are, and after a footnote")
    func keptBetweenInlineElements() async throws {
        #expect(try await spaces("<p><hi rend=\"italic\">a</hi>\n  <hi rend=\"italic\">b</hi></p>") == 1)
        #expect(try await spaces("<p><placeName>Paris,</placeName> <date when=\"1861-02-28\">February 28</date></p>") == 1)
        #expect(try await spaces("<p><del>one</del> <del>two</del> <del>three</del></p>") == 2)
        #expect(try await spaces("<p>Text<note n=\"1\" xml:id=\"fn1\">Note.</note> <persName>Rusk</persName></p>") == 1)
        #expect(try await text("<p><gloss target=\"#t_A\">SecState</gloss>\n<persName corresp=\"#p_R\">Rusk</persName></p>")
                == "SecState Rusk")
    }

    @Test("Not kept between two blocks, beside a block, or where text already carries the space")
    func notKeptBesideABlockOrText() async throws {
        #expect(try await spaces("<p>One.</p>\n<p>Two.</p>") == 0)
        #expect(try await spaces("<p><hi>a</hi>\n<quote><p>b</p></quote></p>") == 0, "a block after")
        #expect(try await spaces("<closer><signed>A</signed>\n<signed>B</signed></closer>") == 0, "two blocks")
        #expect(try await spaces("<p><hi>a</hi> and <hi>b</hi></p>") == 0, "the text between carries its own spaces")
        #expect(try await spaces("<p>\n  <hi>a</hi></p>") == 0, "nothing precedes the run")
        #expect(try await spaces("<p><hi>a</hi>\n</p>") == 0, "nothing follows the run")
    }

    /// The rule's backward walk: what precedes the run. Every fixture here has an inline element
    /// on the right, so the `next` guard lets the run through and only the left side can refuse it
    /// — which the "beside a block" fixtures above, all refused at that guard, never reach.
    @Test("Not kept after a block, whether the parser knows the block by type or only by name")
    func notKeptAfterABlock() async throws {
        // Blocks the parser builds as nodes of their own: a paragraph, a list, a table.
        #expect(try await spaces("<p>Text<note n=\"1\" xml:id=\"fn1\"><p>One.</p>\n<hi>b</hi></note></p>") == 0, "a paragraph before")
        #expect(try await spaces("<p><list><item>One</item></list>\n<hi>b</hi></p>") == 0, "a list before")
        #expect(try await spaces("<p><table><row><cell>a</cell></row></table>\n<hi>b</hi></p>") == 0, "a table before")
        // Blocks it knows only by name (`.unknown`): a quotation, a signature.
        #expect(try await spaces("<p><quote>q</quote>\n<hi>b</hi></p>") == 0, "a quote before")
        #expect(try await spaces("<closer><signed>A</signed>\n<hi>b</hi></closer>") == 0, "a signature before")
        // And the same right-hand element after an inline one, known by type or only by name, is kept.
        #expect(try await spaces("<p><persName>A</persName>\n<hi>b</hi></p>") == 1)
        #expect(try await spaces("<p><placeName>A</placeName>\n<hi>b</hi></p>") == 1, "an inline element known only by name")
    }

    @Test("Not kept beside a line break, and kept once across a page break")
    func lineBreaksAndPageBreaks() async throws {
        #expect(try await spaces("<p><hi>a</hi>\n<lb/>\n<hi>b</hi></p>") == 0)
        // </hi> ws <pb/> ws <hi>: the first run is the space; the second would double it.
        #expect(try await spaces("<p><hi>a</hi>\n<pb n=\"2\" xml:id=\"pg_2\"/>\n<hi>b</hi></p>") == 1)
        #expect(try await text("<p><hi>a</hi>\n<pb n=\"2\" xml:id=\"pg_2\"/>\n<hi>b</hi></p>") == "a b")
        // Text, a break, then whitespace before an element: the break took the text's space with it.
        #expect(try await spaces("<p>word<pb n=\"2\" xml:id=\"pg_2\"/> <hi>b</hi></p>") == 1)
        #expect(try await text("<p>word<pb n=\"2\" xml:id=\"pg_2\"/> <hi>b</hi></p>") == "word b")
        // …but not when the text before the break already ends in one.
        #expect(try await spaces("<p>word <pb n=\"2\" xml:id=\"pg_2\"/> <hi>b</hi></p>") == 0)
    }

    @Test("Not kept in a container whose children are picked by position: a choice, a list, a table, a figure")
    func notKeptInPositionalContainers() async throws {
        // buildNode takes a choice's first child that is not a <sic>: a marker there would become it.
        #expect(try await spaces("<p>the <choice><sic>frist</sic> <abbr>first</abbr></choice> word</p>") == 0)
        #expect(try await text("<p>the <choice><sic>frist</sic> <abbr>first</abbr></choice> word</p>") == "the first word")
        #expect(try await spaces("<list><label>(1)</label> <item>One</item> <label>(2)</label> <item>Two</item></list>") == 0)
        #expect(try await spaces("<table><row><cell>a</cell> <cell>b</cell></row> <row><cell>c</cell></row></table>") == 0)
        #expect(try await spaces("<figure><graphic url=\"a\"/> <figDesc>d</figDesc></figure>") == 0)
        #expect(try await spaces("<frus:attachment><note n=\"1\" xml:id=\"fn1\">N.</note> <pb n=\"2\" xml:id=\"pg_2\"/><p>P.</p></frus:attachment>") == 0)
        // Inside a cell or an item, between two inline elements, it is kept.
        #expect(try await spaces("<table><row><cell><hi>a</hi> <hi>b</hi></cell></row></table>") == 1)
        #expect(try await spaces("<list><item><gloss target=\"#t\">A</gloss> <persName>B</persName></item></list>") == 1)
    }

    @Test("A kept space is no text: the index stores what it stored, and the highlight space does not move")
    func aKeptSpaceIsNoText() async throws {
        let spaced = "<div type=\"document\" xml:id=\"d1\"><p>(<hi>a</hi> <hi>b</hi> <hi>.</hi>)</p></div>"
        let glued = "<div type=\"document\" xml:id=\"d1\"><p>(<hi>a</hi><hi>b</hi><hi>.</hi>)</p></div>"
        let ast = try await ListShapeFixtures.ast(spaced)
        let gluedAST = try await ListShapeFixtures.ast(glued)
        // The printed rule spaces "a b" and glues the stop, whether or not the run was kept: adding a
        // space for the marker would store "a b ." where the index has always stored "a b.".
        #expect(IndexingPipeline.extractBodyText(from: ast.nodes) == "(a b.)")
        #expect(IndexingPipeline.extractBodyText(from: ast.nodes) == IndexingPipeline.extractBodyText(from: gluedAST.nodes))
        #expect(IndexingPipeline.bodyHash(for: ast) == IndexingPipeline.bodyHash(for: gluedAST))
        #expect(buildFlatText(from: try await ListShapeFixtures.renderModel(spaced)) == "(ab.)")
    }
}
