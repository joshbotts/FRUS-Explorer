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
/// `<list>` inside `div[@type="document"]`: 721,476 `<item>`, 449,665 `<label>`, 52,185 `<head>`
/// (always the first child, never two in one list), 21,891 `<pb/>`, 119 `<lb/>`, 8 `<closer>`,
/// 5 `<gap/>`, 4 `<salute>`, 2 `<note>` and 1 `<figure>`. Every label is followed by an item once
/// any `<pb/>` or `<note>` between them is skipped. The converter used to keep only the items.
enum ListShapeFixtures {

    /// `frus1961-63v05/d84`, the Vienna lunch memorandum of 3 June 1961, trimmed to its three
    /// lists: a `subject` list and a `participants` list that each carry a `<head>`, and a
    /// labelled list inside a paragraph whose `(1)`–`(6)` exist nowhere but in `<label>`, with a
    /// `<pb/>` between the first two items and a footnote inside the third. The markup of each
    /// element is the volume's own; only the item prose is shortened.
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
        let ast = try #require(documents.first, "the fixture must parse to a document")
        var converter = converter
        return converter.convert(ast)
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
/// PARTICIPANTS heads and printed numbering such as `(1)` vanished from 79,789 documents, and a
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
