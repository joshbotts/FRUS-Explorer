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
        case .text, .lineBreak, .pageBreak, .formula:
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
            "data-page=\"[map]\"", "<figcaption>figure_0732</figcaption>", "data-page=\"1241\"",
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
