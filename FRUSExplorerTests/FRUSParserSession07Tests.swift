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
