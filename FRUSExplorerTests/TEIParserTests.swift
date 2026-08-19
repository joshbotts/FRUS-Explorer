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

// MARK: - Fixture Helpers

/// Wraps fragment XML in minimal FRUS TEI scaffolding and writes it to a temp file.
/// The fragment should be one or more `<div type="document">` elements.
private func makeTEIFixture(body: String) throws -> URL {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
      <text><body>\(body)</body></text>
    </TEI>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-test-\(UUID().uuidString).xml")
    try xml.write(to: url, atomically: true, encoding: .utf8)
    return url
}

/// Like `makeTEIFixture` but includes the FRUS namespace declaration so that
/// `<frus:attachment>` elements are accepted by the XML parser without error.
private func makeFRUSFixture(body: String) throws -> URL {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0"
         xmlns:frus="http://history.state.gov/frus/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
      <text><body>\(body)</body></text>
    </TEI>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-frus-\(UUID().uuidString).xml")
    try xml.write(to: url, atomically: true, encoding: .utf8)
    return url
}

/// Returns `true` if an AST node array contains a node matching the given case.
/// Uses a simple recursive visitor.
private func containsCase(in nodes: [FRUSASTNode], where predicate: (FRUSASTNode) -> Bool) -> Bool {
    for node in nodes {
        if predicate(node) { return true }
        let children: [FRUSASTNode]
        switch node {
        case .document(_, _, let c), .head(let c), .dateline(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .paragraph(let c), .footnote(_, _, _, let c),
             .persName(_, let c), .gloss(_, let c), .crossReference(_, _, let c),
             .emphasis(_, let c), .term(let c),
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

/// Flattens all `.text` values in an AST tree into a single string.
private func extractAllText(from nodes: [FRUSASTNode]) -> String {
    var result = ""
    for node in nodes {
        switch node {
        case .text(let s):
            result += s
        case .formula(let s):
            result += s
        case .document(_, _, let c), .head(let c), .dateline(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .paragraph(let c), .footnote(_, _, _, let c),
             .persName(_, let c), .gloss(_, let c), .crossReference(_, _, let c),
             .emphasis(_, let c), .term(let c),
             .supplied(let c), .sic(let c), .corr(let c),
             .editorialNote(let c), .titlePage(let c), .figure(_, let c),
             .unknown(_, _, let c), .attachment(_, let c):
            result += extractAllText(from: c)
        case .date(_, _, _, _, _, let c):
            result += extractAllText(from: c)
        case .table(let c), .tableRow(let c), .listItem(let c):
            result += extractAllText(from: c)
        case .tableCell(_, _, let c):
            result += extractAllText(from: c)
        case .list(_, let c):
            result += extractAllText(from: c)
        case .lineBreak, .pageBreak:
            break
        }
    }
    return result
}

// MARK: - Test Suite

struct TEIParserTests {

    // MARK: - ParseCoreElementsTest

    @Test("Parser: <p> produces .paragraph node")
    func parseParagraph() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Hello world.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)
        let doc = docs[0]
        #expect(doc.documentId == "d1")
        #expect(containsCase(in: doc.nodes) { if case .paragraph = $0 { return true }; return false })
    }

    @Test("Parser: <head> produces .head node")
    func parseHead() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <head>1. Memorandum</head>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) { if case .head = $0 { return true }; return false })
    }

    @Test("Parser: <dateline> produces .dateline node")
    func parseDateline() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <dateline>Washington, January 20, 1969.</dateline>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) { if case .dateline = $0 { return true }; return false })
    }

    @Test("Parser: <opener>/<closer>/<salute> produce their respective nodes")
    func parseLetterElements() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <opener><salute>Dear Mr. President,</salute></opener>
          <p>Body text.</p>
          <closer><salute>Respectfully yours,</salute></closer>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let nodes = docs[0].nodes
        #expect(containsCase(in: nodes) { if case .opener = $0 { return true }; return false })
        #expect(containsCase(in: nodes) { if case .closer = $0 { return true }; return false })
        #expect(containsCase(in: nodes) { if case .salute = $0 { return true }; return false })
    }

    @Test("Parser: <note type='footnote'> produces .footnote with correct type")
    func parseFootnote() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Text.<note xml:id="fn1" type="footnote">Source: NSC Files.</note></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var found = false
        for node in docs[0].nodes {
            if case .paragraph(let children) = node {
                for child in children {
                    if case .footnote(let id, let type, _, _) = child {
                        #expect(id == "fn1")
                        #expect(type == .footnote)
                        found = true
                    }
                }
            }
        }
        #expect(found, "Expected .footnote node inside paragraph")
    }

    @Test("Parser: <note type='source'> produces .footnote with type .source")
    func parseSourceNote() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <note type="source">Source: NSC Files.</note>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) {
            if case .footnote(_, let t, _, _) = $0, t == .source { return true }
            return false
        })
    }

    @Test("Parser: <hi rend='italic'> produces .emphasis(.italic)")
    func parseEmphasisItalic() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>See <hi rend="italic">détente</hi> policy.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) {
            if case .emphasis(let s, _) = $0, s == .italic { return true }
            return false
        })
    }

    @Test("Parser: <hi rend='bold'> produces .emphasis(.bold)")
    func parseEmphasisBold() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><hi rend="bold">Important.</hi></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) {
            if case .emphasis(let s, _) = $0, s == .bold { return true }
            return false
        })
    }

    @Test("Parser: <persName ref='Kissinger'> produces .persName with correct ref")
    func parsePersName() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><persName ref="Kissinger">Dr. Kissinger</persName> attended.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var foundRef: String?
        if containsCase(in: docs[0].nodes, where: {
            if case .persName(let ref, _) = $0 { foundRef = ref; return true }
            return false
        }) { }
        #expect(foundRef == "Kissinger")
    }

    @Test("Parser: <gloss ref='NATO'> produces .gloss with correct ref")
    func parseGloss() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><gloss ref="NATO">NATO</gloss> forces.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var foundRef: String?
        if containsCase(in: docs[0].nodes, where: {
            if case .gloss(let ref, _) = $0 { foundRef = ref; return true }
            return false
        }) { }
        #expect(foundRef == "NATO")
    }

    @Test("Parser: <term> produces .term node")
    func parseTerm() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>The <term>backchannel</term> was used.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) { if case .term = $0 { return true }; return false })
    }

    // MARK: - CrossReferenceExtractionTest

    @Test("Parser: <ref target='#d42'> produces .crossReference with nil volumeId")
    func parseSameVolumeRef() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>See <ref target="#d42">document 42</ref>.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var found = false
        if containsCase(in: docs[0].nodes, where: {
            if case .crossReference(let target, let volId, _) = $0 {
                found = (target == "#d42" && volId == nil)
                return true
            }
            return false
        }) { }
        #expect(found, "Expected .crossReference with target '#d42' and nil volumeId")
    }

    @Test("Parser: <ref target='frus1969-76v01#d42'> extracts volumeId")
    func parseCrossVolumeRef() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>See <ref target="frus1969-76v01#d42">Volume I, doc 42</ref>.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var foundVolId: String?
        if containsCase(in: docs[0].nodes, where: {
            if case .crossReference(_, let volId, _) = $0 { foundVolId = volId; return true }
            return false
        }) { }
        #expect(foundVolId == "frus1969-76v01")
    }

    // MARK: - WhitespaceTest

    @Test("Whitespace: XML indentation noise does not produce multi-space or newline artefacts")
    func whitespaceIndentationNoise() async throws {
        // A paragraph whose text content is surrounded by XML indentation whitespace
        // ("\n  Hello world.\n  ") should not produce newline characters or multiple
        // consecutive spaces in the AST. Single boundary spaces are acceptable
        // (they are visually invisible in SwiftUI Text) but newlines and multi-space
        // runs must be collapsed.
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>
            Hello world.
          </p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("Hello world."), "Core text content must be present")
        #expect(!text.contains("\n"), "Newlines must be collapsed; found: \"\(text)\"")
        #expect(!text.contains("  "), "Multiple consecutive spaces must be collapsed; found: \"\(text)\"")
    }

    @Test("Whitespace: multiple spaces collapsed to single space")
    func whitespaceCollapsed() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Word1   Word2   Word3</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(!text.contains("  "), "Consecutive spaces must be collapsed to a single space")
    }

    @Test("Whitespace: whitespace-only text nodes between block elements are discarded")
    func whitespaceOnlyNodesDiscarded() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <head>Title</head>
          <p>Body.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        // Check that no .text nodes contain only whitespace.
        func hasWhitespaceOnlyText(_ nodes: [FRUSASTNode]) -> Bool {
            for node in nodes {
                if case .text(let s) = node, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
                let children: [FRUSASTNode]
                switch node {
                case .document(_, _, let c), .head(let c), .dateline(let c),
                     .opener(let c), .closer(let c), .salute(let c),
                     .paragraph(let c), .footnote(_, _, _, let c),
                     .persName(_, let c), .gloss(_, let c), .crossReference(_, _, let c),
                     .emphasis(_, let c), .term(let c),
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
                if hasWhitespaceOnlyText(children) { return true }
            }
            return false
        }
        #expect(!hasWhitespaceOnlyText(docs[0].nodes), "Whitespace-only text nodes must be discarded by the parser")
    }

    // MARK: - DeepNestingTest

    @Test("Deep nesting: 20-level nested <hi> elements parse without crash")
    func deepNestingNoCrash() async throws {
        // Build 20 levels of nested <hi rend="italic"> — tests the explicit stack approach.
        var inner = "deep text"
        for _ in 0..<20 {
            inner = "<hi rend=\"italic\">\(inner)</hi>"
        }
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>\(inner)</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1, "Parser must not crash on deeply nested elements")
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("deep text"), "Deep text content must be preserved through nesting")
    }

    // MARK: - UnknownElementTest

    @Test("Unknown element: unrecognized element produces .unknown node, not a crash")
    func unknownElementPreserved() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Before <futureElement rend="special">content</futureElement> after.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(containsCase(in: docs[0].nodes) {
            if case .unknown(let name, _, _) = $0, name == "futureElement" { return true }
            return false
        }, "Unknown element must produce a .unknown node, not be dropped or crash")
    }

    @Test("Unknown element: text content of unknown element is preserved")
    func unknownElementTextPreserved() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><unknownTag>preserved text</unknownTag></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("preserved text"), "Text content inside unknown elements must not be dropped")
    }

    // MARK: - Multiple Documents

    @Test("Parser: multiple <div type='document'> in one volume produces multiple FRUSDocumentAST")
    func multipleDocuments() async throws {
        let url = try makeTEIFixture(body: """
        <div type="compilation">
          <div type="document" xml:id="d1"><p>First document.</p></div>
          <div type="document" xml:id="d2"><p>Second document.</p></div>
          <div type="document" xml:id="d3"><p>Third document.</p></div>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 3, "Should produce one FRUSDocumentAST per <div type='document'>")
        #expect(docs[0].documentId == "d1")
        #expect(docs[1].documentId == "d2")
        #expect(docs[2].documentId == "d3")
    }

    @Test("parseDocument: returns only the target document and stops early")
    func parseDocumentTargeted() async throws {
        let url = try makeTEIFixture(body: """
        <div type="compilation">
          <div type="document" xml:id="d1"><p>First.</p></div>
          <div type="document" xml:id="d2"><p>Target.</p></div>
          <div type="document" xml:id="d3"><p>Third.</p></div>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try await FRUSDocumentParser().parseDocument(documentId: "d2", volumeURL: url)
        #expect(doc != nil, "parseDocument must return the requested document")
        #expect(doc?.documentId == "d2")
        let text = extractAllText(from: doc?.nodes ?? [])
        #expect(text.contains("Target"))
    }

    @Test("parseDocument: returns nil for a non-existent documentId")
    func parseDocumentNotFound() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1"><p>Only doc.</p></div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try await FRUSDocumentParser().parseDocument(documentId: "d999", volumeURL: url)
        #expect(doc == nil, "parseDocument must return nil when the documentId does not exist")
    }

    // MARK: - PersNameLookupTest

    @Test("PersName lookup: converter resolves persName ref via personLookup closure")
    func persNameLookupResolved() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><persName ref="Kissinger">Kissinger</persName></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let fixture = PersonEntry(ref: "Kissinger", name: "Henry A. Kissinger", description: "National Security Advisor")
        var converter = ASTToRenderNodeConverter(
            personLookup: { ref in ref == "Kissinger" ? fixture : nil }
        )
        let model = converter.convert(docs[0])

        var foundPerson: PersonEntry?
        func findPerson(_ nodes: [FRUSRenderNode]) {
            for node in nodes {
                if case .persNameLink(_, _, let p) = node { foundPerson = p; return }
                switch node {
                case .paragraph(let c), .heading(let c), .italicText(let c), .boldText(let c),
                     .unknown(_, let c), .persNameLink(_, let c, _): findPerson(c)
                default: break
                }
            }
        }
        findPerson(model.bodyNodes)
        #expect(foundPerson?.name == "Henry A. Kissinger")
    }

    @Test("PersName lookup: nil personLookup produces .persNameLink with nil person")
    func persNameLookupNilFallback() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><persName ref="Kissinger">Kissinger</persName></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()  // no lookup
        let model = converter.convert(docs[0])

        var foundPerson: PersonEntry?? = .some(nil)
        func findPerson(_ nodes: [FRUSRenderNode]) {
            for node in nodes {
                if case .persNameLink(_, _, let p) = node { foundPerson = p; return }
                switch node {
                case .paragraph(let c), .heading(let c): findPerson(c)
                default: break
                }
            }
        }
        findPerson(model.bodyNodes)
        // foundPerson should be .some(nil) — the node exists but person is nil.
        if let outer = foundPerson {
            #expect(outer == nil, "persNameLink person must be nil when no lookup is provided")
        }
    }

    // MARK: - RenderingConfigLoadTest

    @Test("RenderingConfig: loads and decodes tei-rendering-config.json from bundle")
    func renderingConfigLoads() {
        let config = TEIRenderingConfig.loadFromBundle()
        // The bundled config has at least the core elements defined in Session 06.
        #expect(config.elements.count >= 5, "Config must contain at least the core Session 06 elements")
        #expect(!config.schemaVersion.isEmpty, "Config must specify a schemaVersion")
    }

    @Test("RenderingConfig: known elements return correct RenderBehavior")
    func renderingConfigKnownElements() {
        var config = TEIRenderingConfig.loadFromBundle()
        // <p> should be a block element.
        let pBehavior = config.behavior(for: "p")
        #expect(pBehavior.renderAs == .block)
        // <hi> should be an inline element.
        let hiBehavior = config.behavior(for: "hi")
        #expect(hiBehavior.renderAs == .inline)
    }

    @Test("RenderingConfig: unknown element returns passThrough default")
    func renderingConfigUnknownFallback() {
        var config = TEIRenderingConfig.loadFromBundle()
        let behavior = config.behavior(for: "someFutureElement")
        #expect(behavior.renderAs == .passThrough)
    }

    // MARK: - Converter: Footnote Numbering

    /// #985 changed this test's expectation, deliberately.
    ///
    /// It used to assert that two `@n`-less notes are *labelled* "1" and "2" — the fabrication
    /// this issue removed. The sequential counter survives and is still asserted, because the DOM
    /// key falls back to it; what no longer happens is showing it to the reader as though the
    /// volume had printed it.
    @Test("Converter: notes without @n get sequential numbers but no display label")
    func footnoteSequentialNumbering() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>First<note type="footnote">Note one.</note> second<note type="footnote">Note two.</note>.</p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])

        #expect(model.footnotes.count == 2, "Two footnotes in source must produce two footnote bodies")
        if case .footnoteBody(_, _, _, let n1, let l1, _) = model.footnotes[0] {
            #expect(n1 == 1)
            #expect(l1 == nil, "A note with no @n has no printed number; the counter is not a label")
        }
        if case .footnoteBody(_, _, _, let n2, let l2, _) = model.footnotes[1] {
            #expect(n2 == 2)
            #expect(l2 == nil)
        }
    }

    @Test("Converter: footnoteMarker appears in body, footnoteBody in footnotes array")
    func footnoteMarkerInBody() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p>Text.<note type="footnote">Footnote body.</note></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])

        // Check that a footnoteMarker appears in the body nodes.
        func hasMarker(_ nodes: [FRUSRenderNode]) -> Bool {
            for node in nodes {
                if case .footnoteMarker = node { return true }
                switch node {
                case .paragraph(let c), .heading(let c), .boldText(let c),
                     .italicText(let c), .unknown(_, let c): if hasMarker(c) { return true }
                default: break
                }
            }
            return false
        }
        #expect(hasMarker(model.bodyNodes), "footnoteMarker must appear in the body nodes")
        #expect(model.footnotes.count == 1, "footnoteBody must appear in the footnotes array")
    }
}

// MARK: - DateAttributeParsingTests

/// Verifies that `<date>` elements inside `<dateline>` and document body are
/// captured in the AST with their machine-readable attributes intact.
///
/// Version history:
///   1.0 — Session 36: initial implementation
@Suite("DateAttributeParsingTests")
struct DateAttributeParsingTests {

    // MARK: - Helpers

    /// Recursively finds the first `.date` node in an AST.
    private func firstDate(in nodes: [FRUSASTNode]) -> FRUSASTNode? {
        for node in nodes {
            if case .date = node { return node }
            if let found = firstDate(in: node.children) { return found }
        }
        return nil
    }

    // MARK: - Tests

    @Test("exactDateWhenAttribute — @when inside dateline produces .date(when:)")
    func exactDateWhenAttribute() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <dateline>Washington, <date when="1969-01-15">January 15, 1969</date></dateline>
              <p>Body.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)

        guard let dateNode = firstDate(in: docs[0].nodes) else {
            Issue.record("No .date node found in AST")
            return
        }
        guard case .date(let when, _, _, _, _, _) = dateNode else {
            Issue.record("Node is not .date")
            return
        }
        #expect(when == "1969-01-15")
    }

    @Test("dateRangeFromTo — @from and @to both captured")
    func dateRangeFromTo() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <dateline>Washington, <date from="1969-01" to="1969-03">January–March 1969</date></dateline>
              <p>Body.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        guard let dateNode = firstDate(in: docs[0].nodes),
              case .date(_, let from, let to, _, _, _) = dateNode else {
            Issue.record("No .date node with from/to found")
            return
        }
        #expect(from == "1969-01")
        #expect(to   == "1969-03")
    }

    @Test("approximateDateNotBefore — @notBefore captured")
    func approximateDateNotBefore() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <dateline><date notBefore="1952">circa 1952</date></dateline>
              <p>Body.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        guard let dateNode = firstDate(in: docs[0].nodes),
              case .date(_, _, _, let notBefore, _, _) = dateNode else {
            Issue.record("No .date node with notBefore found")
            return
        }
        #expect(notBefore == "1952")
    }

    @Test("dateWithNoAttributes — no machine-readable attrs, text in children")
    func dateWithNoAttributes() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <dateline><date>January 1969</date></dateline>
              <p>Body.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        guard let dateNode = firstDate(in: docs[0].nodes),
              case .date(let when, let from, let to, let notBefore, let notAfter, let children) = dateNode else {
            Issue.record("No .date node found")
            return
        }
        #expect(when == nil)
        #expect(from == nil)
        #expect(to == nil)
        #expect(notBefore == nil)
        #expect(notAfter == nil)
        #expect(children.map(\.plainText).joined() == "January 1969")
    }

    @Test("dateOutsideDateline — @when in body paragraph produces .date node")
    func dateOutsideDateline() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <p>The meeting took place on <date when="1969-05-01">May 1</date>.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        guard let dateNode = firstDate(in: docs[0].nodes),
              case .date(let when, _, _, _, _, _) = dateNode else {
            Issue.record("No .date node found in body")
            return
        }
        #expect(when == "1969-05-01")
    }

    @Test("dateRendersAsPlainText — .date children appear in dateline display text")
    func dateRendersAsPlainText() async throws {
        let url = try makeTEIFixture(body: """
            <div type="document" xml:id="d1">
              <dateline>Washington, <date when="1969-01-15">January 15, 1969</date></dateline>
              <p>Body.</p>
            </div>
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(docs[0])

        // The dateline render node should contain the display text, not be empty.
        func datelineText(_ nodes: [FRUSRenderNode]) -> String? {
            for node in nodes {
                if case .dateline(let children) = node {
                    return children.compactMap { n -> String? in
                        if case .plainText(let s) = n { return s }
                        return nil
                    }.joined(separator: " ")
                }
            }
            return nil
        }
        let text = datelineText(model.bodyNodes) ?? ""
        #expect(text.contains("January 15, 1969"),
                "Dateline should contain the display text of the <date> element")
    }
}

// MARK: - EditorialNoteIndexingTests

/// Verifies that `<div type="editorialNote">` elements are promoted to separate
/// `FRUSDocumentAST` instances with the top-level `.editorialNote([...])` wrapper.
///
/// Version history:
///   1.0 — Session 38: initial implementation
@Suite("EditorialNoteIndexingTests")
struct EditorialNoteIndexingTests {

    private func parseEditorialNoteXML(_ xml: String) async throws -> [FRUSDocumentAST] {
        let data = xml.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).xml")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        return try await parser.parse(volumeURL: url)
    }

    @Test("editorialNoteProducesSeparateAST — <div type=editorialNote xml:id=en1> yields its own FRUSDocumentAST")
    func editorialNoteProducesSeparateAST() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1"><head>1. Document One</head><p>Body text.</p></div>
        <div type="editorialNote" xml:id="en1"><p>This is an editorial note.</p></div>
        </body></text></TEI>
        """
        let docs = try await parseEditorialNoteXML(xml)
        #expect(docs.count == 2, "Both the document and editorial note must be promoted to FRUSDocumentAST entries")
        let en = try #require(docs.first { $0.documentId == "en1" })
        #expect(en.documentId == "en1")
    }

    @Test("editorialNoteNodesWrappedInEditorialNoteCase — top-level node is .editorialNote")
    func editorialNoteNodesWrappedInEditorialNoteCase() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="editorialNote" xml:id="en2"><p>Editorial content here.</p></div>
        </body></text></TEI>
        """
        let docs = try await parseEditorialNoteXML(xml)
        let en = try #require(docs.first { $0.documentId == "en2" })
        // The first node must be .editorialNote wrapping the paragraph.
        guard case .editorialNote(let children) = en.nodes.first else {
            Issue.record("First node must be .editorialNote; got \(String(describing: en.nodes.first))")
            return
        }
        #expect(!children.isEmpty, "Editorial note must contain its children")
    }

    @Test("editorialNoteAppearsInStructure — parseVolumeStructure includes en1 in parent section documentIds")
    func editorialNoteAppearsInStructure() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="compilation" xml:id="c1">
          <head>Compilation One</head>
          <div type="document" xml:id="d1"><head>1. Doc</head><p>Body.</p></div>
          <div type="editorialNote" xml:id="en1"><p>Note.</p></div>
        </div>
        </body></text></TEI>
        """
        let data = xml.data(using: .utf8)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("struct-\(UUID().uuidString).xml")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        let structure = try await parser.parseVolumeStructure(volumeURL: url)

        let c1 = try #require(structure.sections.first { $0.sectionId == "c1" })
        #expect(c1.documentIds.contains("d1"), "Normal document must appear in documentIds")
        #expect(c1.documentIds.contains("en1"), "Editorial note must also appear in documentIds")
    }

    @Test("earlyVolumeStructureParses — a front-matter doc + nested compilation/chapter/subchapter yields non-empty structure (#214)")
    func earlyVolumeStructureParses() async throws {
        // Shape of a pre-1906 "Papers Relating to Foreign Affairs" volume: the President's
        // annual message sits directly under <front>, and correspondence nests
        // compilation → country chapter → subject subchapter. #214 relies on this parsing
        // straight from the downloaded XML (no index) so macOS can browse early volumes.
        let xml = """
        <?xml version="1.0"?>
        <TEI><text>
        <front>
          <div type="document" xml:id="d1"><head>Annual Message</head><p>Message text.</p></div>
        </front>
        <body>
        <div type="compilation" xml:id="comp1">
          <head>Correspondence.</head>
          <div type="chapter" xml:id="ch1">
            <head>Great Britain.</head>
            <div type="subchapter" xml:id="sub1">
              <head>Correspondence respecting the capture of the Saxon.</head>
              <div type="document" xml:id="d229"><head>229. Doc</head><p>Body.</p></div>
            </div>
          </div>
        </div>
        </body></text></TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("early-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        let structure = try await parser.parseVolumeStructure(volumeURL: url)

        #expect(!structure.isEmpty, "Early-volume structure must not be empty")
        // The <front> annual-message document must survive (parser drops only stack-less docs).
        let front = structure.sections.first { $0.divType == "front" }
        #expect(front != nil, "A <front> section must be present")
        #expect(front?.documentIds.contains("d1") == true
                || front?.subsections.contains { $0.documentIds.contains("d1") } == true,
                "The front-matter annual message (d1) must be reachable")
        // The nested subject subchapter with its document must be reachable through the chain.
        let comp = try #require(structure.sections.first { $0.sectionId == "comp1" })
        let chapter = try #require(comp.subsections.first { $0.sectionId == "ch1" })
        let sub = try #require(chapter.subsections.first { $0.sectionId == "sub1" })
        #expect(sub.documentIds.contains("d229"), "Deeply nested document must appear in its subchapter")
    }
}

// MARK: - FootnoteNumberTests (Session 42)

struct FootnoteNumberTests {

    private func parseFixture(_ xml: String) async throws -> FRUSDocumentRenderModel? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fn-test-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let parser = FRUSDocumentParser()
        guard let ast = try await parser.parseDocument(documentId: "d1", volumeURL: url) else {
            return nil
        }
        var converter = ASTToRenderNodeConverter()
        return converter.convert(ast)
    }

    @Test("noteWithNAttributeCaptured — @n value stored as printedNumber in AST")
    func noteWithNAttributeCaptured() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <p>Body<note type="footnote" n="3">Third footnote.</note></p>
        </div>
        </body></text></TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fn-ast-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        guard let ast = try await parser.parseDocument(documentId: "d1", volumeURL: url) else {
            Issue.record("AST parse returned nil"); return
        }
        // Walk nodes to find the footnote AST node
        func findFootnote(_ nodes: [FRUSASTNode]) -> FRUSASTNode? {
            for node in nodes {
                if case .footnote = node { return node }
                if let found = findFootnote(node.children) { return found }
            }
            return nil
        }
        guard let fn = findFootnote(ast.nodes) else {
            Issue.record("No .footnote node found in AST"); return
        }
        guard case .footnote(_, _, let printedNumber, _) = fn else {
            Issue.record("Node is not .footnote"); return
        }
        #expect(printedNumber == "3", "printedNumber must equal the @n attribute value")
    }

    @Test("noteWithoutNAttributeIsNil — missing @n produces nil printedNumber")
    func noteWithoutNAttributeIsNil() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <p>Body<note type="footnote">No number.</note></p>
        </div>
        </body></text></TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fn-nil-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        guard let ast = try await parser.parseDocument(documentId: "d1", volumeURL: url) else {
            Issue.record("AST parse returned nil"); return
        }
        func findFootnote(_ nodes: [FRUSASTNode]) -> FRUSASTNode? {
            for node in nodes {
                if case .footnote = node { return node }
                if let found = findFootnote(node.children) { return found }
            }
            return nil
        }
        guard let fn = findFootnote(ast.nodes) else {
            Issue.record("No .footnote node found"); return
        }
        guard case .footnote(_, _, let printedNumber, _) = fn else {
            Issue.record("Node is not .footnote"); return
        }
        #expect(printedNumber == nil, "printedNumber must be nil when @n is absent")
    }

    @Test("nonSequentialNValues — displayLabel uses @n; sequential counter still increments")
    func nonSequentialNValues() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <p>A<note type="footnote" n="1">First.</note>
             B<note type="footnote" n="3">Third.</note>
             C<note type="footnote" n="5">Fifth.</note></p>
        </div>
        </body></text></TEI>
        """
        guard let model = try await parseFixture(xml) else {
            Issue.record("Model is nil"); return
        }
        #expect(model.footnotes.count == 3)

        // displayLabels should follow @n values: 1, 3, 5
        let labels: [String] = model.footnotes.compactMap {
            if case .footnoteBody(_, _, _, _, let label, _) = $0 { return label }
            return nil
        }
        #expect(labels == ["1", "3", "5"],
                "displayLabels must reflect @n values, not the sequential counter")

        // sequentialNumbers should be 1, 2, 3
        let seqs: [Int] = model.footnotes.compactMap {
            if case .footnoteBody(_, _, _, let seq, _, _) = $0 { return seq }
            return nil
        }
        #expect(seqs == [1, 2, 3], "sequentialNumbers must still increment 1–3")
    }

    @Test("renderNodeDisplayLabelMatchesPrintedNumber — marker displayLabel matches body displayLabel")
    func renderNodeDisplayLabelMatchesPrintedNumber() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <p>Text<note type="footnote" n="7">Note text.</note></p>
        </div>
        </body></text></TEI>
        """
        guard let model = try await parseFixture(xml) else {
            Issue.record("Model is nil"); return
        }
        // The body should have displayLabel "7"
        guard case .footnoteBody(_, _, _, _, let bodyLabel, _) = model.footnotes.first else {
            Issue.record("No footnoteBody"); return
        }
        #expect(bodyLabel == "7")

        // The inline marker in bodyNodes should also have displayLabel "7"
        func findMarker(_ nodes: [FRUSRenderNode]) -> String? {
            for node in nodes {
                if case .footnoteMarker(_, _, _, let label) = node { return label }
                switch node {
                case .paragraph(let c), .boldText(let c), .italicText(let c),
                     .smallCapsText(let c), .underlineText(let c), .termText(let c):
                    if let found = findMarker(c) { return found }
                default: break
                }
            }
            return nil
        }
        let markerLabel = findMarker(model.bodyNodes)
        #expect(markerLabel == "7", "footnoteMarker displayLabel must match footnoteBody displayLabel")
    }

    // MARK: - Session 54: Inline Whitespace Preservation

    @Test("normalizedText preserves leading space")
    func normalizedTextLeadingSpace() async throws {
        // The private normalizedText is exercised via the full parse pipeline.
        // A paragraph containing " word" (leading space) should produce a plainText
        // node that starts with a space — verifiable by checking the rendered text
        // includes the space between adjacent nodes.
        //
        // We test this end-to-end: a paragraph with italic text adjacent to plain text
        // must not lose the space between them.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>T</title></titleStmt></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1">
              <p>Secretary <hi rend="italic">Kissinger</hi> said hello.</p>
            </div>
          </body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ws-test-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        guard let doc = docs.first else { Issue.record("No document parsed"); return }

        // Extract all text content from the first paragraph node.
        func paragraphText(in nodes: [FRUSASTNode]) -> String? {
            for node in nodes {
                if case .paragraph(let children) = node {
                    return children.map(\.plainText).joined()
                }
                if case .document(_, _, let ch) = node, let t = paragraphText(in: ch) { return t }
            }
            return nil
        }
        let text = paragraphText(in: doc.nodes) ?? ""
        // The space between "Secretary" and "Kissinger" and between "Kissinger"
        // and "said" must be preserved — no word-cramming.
        #expect(text.contains("Secretary Kissinger"), "Space before italic run lost: \"\(text)\"")
        #expect(text.contains("Kissinger said"), "Space after italic run lost: \"\(text)\"")
    }

    @Test("normalizedText discards whitespace-only nodes")
    func normalizedTextDiscardsWhitespaceOnly() async throws {
        // Inter-element indentation (newlines + spaces between tags) must not become
        // spurious plainText(" ") or plainText("\n") nodes in the AST.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>T</title></titleStmt></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1">
              <p>Word.</p>
            </div>
          </body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ws-test2-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        let docs = try await parser.parse(volumeURL: url)
        guard let doc = docs.first else { Issue.record("No document parsed"); return }

        // The body text for the single-paragraph document must be just "Word." with no
        // leading or trailing whitespace injected from XML indentation.
        let body = IndexingPipeline.extractBodyText(from: doc.nodes)
        #expect(body.trimmingCharacters(in: .whitespacesAndNewlines) == body,
                "Body text has spurious leading/trailing whitespace: \"\(body)\"")
    }

    // MARK: - Session 79: Converter test (uses private parseFixture)

    @Test("Converter: .titlePage converts to .titlePageBlock render node")
    func titlePageConvertsToTitlePageBlock() async throws {
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <titlePage>
            <docTitle><titlePart>FRUS Title</titlePart></docTitle>
          </titlePage>
        </div>
        </body></text></TEI>
        """
        guard let model = try await parseFixture(xml) else {
            Issue.record("parseFixture returned nil"); return
        }
        // Walk bodyNodes (may be one level deep if the .document wrapper is present)
        func hasTitlePageBlock(_ nodes: [FRUSRenderNode]) -> Bool {
            for node in nodes {
                if case .titlePageBlock = node { return true }
                // Recurse into unknown wrappers (document-level passthrough)
                if case .unknown(_, let c) = node, hasTitlePageBlock(c) { return true }
            }
            return false
        }
        #expect(hasTitlePageBlock(model.bodyNodes),
                ".titlePage must convert to .titlePageBlock in the render model")
    }
}

// MARK: - Session 64: parseVolumeFull

/// Verifies that `parseVolumeFull` produces the same documents, persons, and terms
/// as three separate `parse` / `parsePersons` / `parseTerms` calls over the same file,
/// confirming the composite-delegate consolidation is semantically equivalent.
@Suite("parseVolumeFull")
struct ParseVolumeFullTests {

    /// Writes a minimal TEI volume fixture containing one document, one person entry,
    /// and one term entry to a temporary file, then returns its URL.
    private func makeFullVolumeFixture() throws -> URL {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test Volume</title></titleStmt></fileDesc></teiHeader>
          <text>
            <front>
              <div type="persons">
                <list>
                  <item xml:id="p1">Kissinger, Henry A.: Secretary of State, 1973–1977</item>
                </list>
              </div>
              <div type="terms">
                <list>
                  <item xml:id="t1"><term>NSSM</term>: National Security Study Memorandum</item>
                </list>
              </div>
            </front>
            <body>
              <div type="compilation">
                <div type="document" xml:id="d1">
                  <head>Memorandum From the President</head>
                  <dateline>Washington, January 1, 1973</dateline>
                  <p>Body text mentioning <persName ref="p1">Kissinger</persName>.</p>
                </div>
              </div>
            </body>
          </text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-full-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("parseVolumeFull returns the same documents as parse(volumeURL:)")
    func documentsMatchSeparateParse() async throws {
        let url = try makeFullVolumeFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        async let fullResult = parser.parseVolumeFull(volumeURL: url)
        async let separateDocs = parser.parse(volumeURL: url)

        let full = try await fullResult
        let docs = try await separateDocs

        #expect(full.documents.count == docs.count,
                "parseVolumeFull returned \(full.documents.count) docs; parse returned \(docs.count)")
        let fullIds = full.documents.map(\.documentId).sorted()
        let sepIds  = docs.map(\.documentId).sorted()
        #expect(fullIds == sepIds,
                "Document IDs differ: full=\(fullIds) sep=\(sepIds)")
    }

    @Test("parseVolumeFull returns persons from <div type=\"persons\">")
    func personsExtracted() async throws {
        let url = try makeFullVolumeFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await FRUSDocumentParser().parseVolumeFull(volumeURL: url)

        #expect(result.persons.count == 1,
                "Expected 1 person entry, got \(result.persons.count)")
        #expect(result.persons.first?.ref == "p1",
                "Expected ref 'p1', got '\(result.persons.first?.ref ?? "nil")'")
        #expect(result.persons.first?.name.contains("Kissinger") == true,
                "Expected name containing 'Kissinger'")
    }

    @Test("parseVolumeFull returns terms from <div type=\"terms\">")
    func termsExtracted() async throws {
        let url = try makeFullVolumeFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await FRUSDocumentParser().parseVolumeFull(volumeURL: url)

        #expect(result.terms.count == 1,
                "Expected 1 term entry, got \(result.terms.count)")
        #expect(result.terms.first?.ref == "t1",
                "Expected ref 't1', got '\(result.terms.first?.ref ?? "nil")'")
        #expect(result.terms.first?.term == "NSSM",
                "Expected term 'NSSM', got '\(result.terms.first?.term ?? "nil")'")
    }

    // MARK: - Session 77: <choice> and small caps

    @Test("Parser: <choice> renders only <corr>, suppresses <sic>")
    func choiceRendersCorr() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><choice><sic>colour</sic><corr>color</corr></choice></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)
        let text = extractAllText(from: docs[0].nodes)
        // Preferred form present exactly once
        #expect(text.contains("color"))
        // Struck-through form must be absent
        #expect(!text.contains("colour"))
        // No .sic node anywhere in the tree
        let hasSic = containsCase(in: docs[0].nodes) { if case .sic = $0 { return true }; return false }
        #expect(!hasSic)
    }

    @Test("Parser: <choice> with no <corr> renders first non-sic child")
    func choiceFallsBackToFirstNonSic() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><choice><sic>colour</sic><reg>color</reg></choice></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("color"))
        #expect(!text.contains("colour"))
    }

    @Test("Parser: <hi rend=\"smallcaps\"> produces .emphasis(.smallCaps) node")
    func smallCapsProducesCorrectASTNode() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <p><hi rend="smallcaps">NATO</hi></p>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let hasSmallCaps = containsCase(in: docs[0].nodes) {
            if case .emphasis(let style, _) = $0 { return style == .smallCaps }
            return false
        }
        #expect(hasSmallCaps, "Expected .emphasis(.smallCaps) node for <hi rend=\"smallcaps\">")
    }

    // MARK: - Session 78: frus:attachment and note[@rend="inline"]

    @Test("Parser: <frus:attachment> produces .attachment AST node")
    func attachmentProducesASTNode() async throws {
        let url = try makeFRUSFixture(body: """
        <div type="document" xml:id="d1">
          <head>1. Telegram</head>
          <p>Body text.</p>
          <frus:attachment>
            <head>Enclosure</head>
            <p>Attachment body.</p>
          </frus:attachment>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)
        let hasAttachment = containsCase(in: docs[0].nodes) {
            if case .attachment = $0 { return true }; return false
        }
        #expect(hasAttachment, "Expected .attachment node for <frus:attachment>")
    }

    @Test("Parser: <frus:attachment> body text is accessible")
    func attachmentBodyTextAccessible() async throws {
        let url = try makeFRUSFixture(body: """
        <div type="document" xml:id="d1">
          <p>Main body.</p>
          <frus:attachment>
            <head>Attachment</head>
            <p>Enclosure content here.</p>
          </frus:attachment>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("Enclosure content here"))
        #expect(text.contains("Main body"))
    }

    @Test("Parser: multiple <frus:attachment> siblings all parsed")
    func multipleAttachmentsSiblings() async throws {
        let url = try makeFRUSFixture(body: """
        <div type="document" xml:id="d1">
          <p>Main body.</p>
          <frus:attachment>
            <head>Tab A</head>
            <p>First attachment.</p>
          </frus:attachment>
          <frus:attachment>
            <head>Tab B</head>
            <p>Second attachment.</p>
          </frus:attachment>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        var attachmentCount = 0
        func countAttachments(_ nodes: [FRUSASTNode]) {
            for node in nodes {
                if case .attachment(_, let c) = node {
                    attachmentCount += 1
                    countAttachments(c)
                } else {
                    countAttachments(node.children)
                }
            }
        }
        countAttachments(docs[0].nodes)
        #expect(attachmentCount == 2, "Expected 2 .attachment nodes, got \(attachmentCount)")
    }

    @Test("Parser: <note rend=\"inline\"> is transparent — children hoisted inline")
    func inlineNoteIsTransparent() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <head><note rend="inline"><hi rend="bold">Attachment</hi></note> Memo</head>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        // No .footnote node should be produced
        let hasFootnote = containsCase(in: docs[0].nodes) {
            if case .footnote = $0 { return true }; return false
        }
        #expect(!hasFootnote, "<note rend=\"inline\"> must not produce a .footnote node")
        // Bold emphasis from the <hi> child must survive into the AST
        let hasBold = containsCase(in: docs[0].nodes) {
            if case .emphasis(.bold, _) = $0 { return true }; return false
        }
        #expect(hasBold, "Expected bold .emphasis from <hi rend=\"bold\"> inside inline note")
    }

    // MARK: - Session 79: <ab> and <titlePage>

    @Test("Parser: <ab> produces .paragraph node (not .unknown)")
    func abProducesParagraphNode() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <ab>Short prose block.</ab>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)
        let hasParagraph = containsCase(in: docs[0].nodes) {
            if case .paragraph = $0 { return true }; return false
        }
        #expect(hasParagraph, "<ab> must produce a .paragraph AST node")
        let hasUnknownAb = containsCase(in: docs[0].nodes) {
            if case .unknown(let name, _, _) = $0 { return name == "ab" }; return false
        }
        #expect(!hasUnknownAb, "<ab> must not fall through to .unknown(name: \"ab\")")
    }

    @Test("Parser: <ab> text content is accessible")
    func abTextIsAccessible() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <ab>Anonymous block content.</ab>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        let text = extractAllText(from: docs[0].nodes)
        #expect(text.contains("Anonymous block content"), "Text inside <ab> must be reachable")
    }

    @Test("Parser: <titlePage> produces .titlePage AST node")
    func titlePageProducesASTNode() async throws {
        let url = try makeTEIFixture(body: """
        <div type="document" xml:id="d1">
          <titlePage>
            <docTitle><titlePart>Foreign Relations of the United States</titlePart></docTitle>
          </titlePage>
        </div>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        #expect(docs.count == 1)
        let hasTitlePage = containsCase(in: docs[0].nodes) {
            if case .titlePage = $0 { return true }; return false
        }
        #expect(hasTitlePage, "<titlePage> must produce a .titlePage AST node")
    }

    @Test("parseVolumeFull does not produce document entries for persons or terms divs")
    func noSpuriousDocumentsFromFrontMatter() async throws {
        let url = try makeFullVolumeFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await FRUSDocumentParser().parseVolumeFull(volumeURL: url)

        // Only the <div type="document" xml:id="d1"> should appear in documents.
        #expect(result.documents.count == 1,
                "Expected exactly 1 document, got \(result.documents.count): \(result.documents.map(\.documentId))")
        #expect(result.documents.first?.documentId == "d1",
                "Expected document ID 'd1'")
    }
}

// MARK: - PersonRoleEraTests (person rollup Phase 1)

/// Covers the persons-list role/active-year extraction added in person rollup Phase 1: the trailing
/// role text after a `<persName>` (previously discarded), colon-delimited roles, year-range parsing,
/// and the light non-person filter.
struct PersonRoleEraTests {

    /// Parses a persons-only volume built from raw `<item>…</item>` fragments.
    private func parsePersons(items: [String]) async throws -> [PersonEntry] {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Persons</title></titleStmt></fileDesc></teiHeader>
          <text><front>
            <div type="persons"><list>
            \(items.joined(separator: "\n"))
            </list></div>
          </front></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("persons-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).persons
    }

    @Test("Format A: trailing role text after </persName> is captured, not discarded")
    func formatATrailingRole() async throws {
        let people = try await parsePersons(items: [
            "<item><persName xml:id=\"p_k\">Kissinger, Henry A.</persName>, Assistant to the President for National Security Affairs</item>"
        ])
        let k = try #require(people.first)
        #expect(k.ref == "p_k")
        #expect(k.name == "Kissinger, Henry A.")
        #expect(k.role == "Assistant to the President for National Security Affairs")
        #expect(k.startYear == nil)
    }

    @Test("Role text wrapped across indented source lines is whitespace-normalized")
    func multilineRoleNormalized() async throws {
        // The live FRUS List of Persons wraps the trailing role text across indented source lines,
        // so the parser captures embedded newlines and run-on indentation (e.g. the rendered
        // "Assistant⏎      to the President…"). PersonEntry must collapse internal whitespace.
        let people = try await parsePersons(items: [
            "<item><persName xml:id=\"p_k\">Kissinger, Henry A.</persName>, Assistant\n"
            + "                        to the President for National Security Affairs</item>"
        ])
        let k = try #require(people.first)
        #expect(k.role == "Assistant to the President for National Security Affairs")
        #expect(!(k.role ?? "").contains("\n"))
        #expect(!(k.role ?? "").contains("  "))
    }

    @Test("Format B with full year range: role and start/end years are split out")
    func formatBYearRange() async throws {
        let people = try await parsePersons(items: [
            "<item xml:id=\"p_a\">Acheson, Dean: Secretary of State, 1949–1953</item>"
        ])
        let a = try #require(people.first)
        #expect(a.name == "Acheson, Dean")
        #expect(a.role == "Secretary of State")
        #expect(a.startYear == 1949)
        #expect(a.endYear == 1953)
        #expect(a.eraText == "1949–1953")
    }

    @Test("Two-digit end year is grafted onto the start century (1947–49 → 1949)")
    func twoDigitEndYear() async throws {
        let people = try await parsePersons(items: [
            "<item xml:id=\"p_m\">Marshall, George C.: Secretary of State, 1947–49</item>"
        ])
        let m = try #require(people.first)
        #expect(m.startYear == 1947)
        #expect(m.endYear == 1949)
    }

    @Test("Single year yields startYear with nil endYear and a single-year era")
    func singleYear() async throws {
        let people = try await parsePersons(items: [
            "<item xml:id=\"p_x\">Bohlen, Charles E.: Ambassador to France, 1962</item>"
        ])
        let b = try #require(people.first)
        #expect(b.role == "Ambassador to France")
        #expect(b.startYear == 1962)
        #expect(b.endYear == nil)
        #expect(b.eraText == "1962")
    }

    @Test("Non-person filter drops 'See …' cross-reference redirects but keeps real names")
    func nonPersonFilter() async throws {
        let people = try await parsePersons(items: [
            "<item xml:id=\"r1\">See Kissinger, Henry A.</item>",
            "<item xml:id=\"p_s\">Seeckt, Hans von: German general</item>"
        ])
        #expect(people.count == 1, "the 'See …' redirect must be dropped")
        #expect(people.first?.name == "Seeckt, Hans von")
    }

    @Test("Non-person filter drops leading-bracket parenthetical fragments but keeps mid-string parentheticals")
    func leadingParentheticalFilter() async throws {
        let people = try await parsePersons(items: [
            // A parenthetical prose fragment lifted out of the list — must be dropped.
            "<item xml:id=\"x1\">(together with political, military and technical advisers).</item>",
            // A lone opening bracket — letterless, must be dropped.
            "<item xml:id=\"x2\">(</item>",
            // A real name that merely *contains* a parenthetical mid-string — must be kept.
            "<item><persName xml:id=\"p_mck\">McKeown (MacEoin), Sean</persName>, Major General</item>"
        ])
        #expect(people.count == 1, "leading-bracket fragments are dropped; mid-string parentheticals are kept")
        let kept = try #require(people.first)
        #expect(kept.name == "McKeown (MacEoin), Sean")
        #expect(kept.role == "Major General")
    }
}

// MARK: - TermsDefinitionTests (Session 162)

/// Covers the terms-list definition extraction fixed in the Session 162 link
/// audit: FRUS separates term and definition with a comma after the nested
/// `<term>` element, not with a colon.
struct TermsDefinitionTests {

    @Test("Terms parser captures the definition text after the nested <term> element")
    func definitionsAreCaptured() async throws {
        let xml = """
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <text><body>
            <div type="section" xml:id="terms">
              <list>
                <item><hi rend="strong"><term xml:id="t_POL1">POL</term>,</hi> petroleum, oil, lubricants; political</item>
                <item><hi rend="strong"><term xml:id="t_UAR1">UAR</term>,</hi> United Arab Republic</item>
                <item><term xml:id="t_BARE1">BARE</term></item>
              </list>
            </div>
          </body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("terms-test-\(UUID().uuidString).xml")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = FRUSDocumentParser()
        let terms = try await parser.parseTerms(volumeURL: url)

        let pol = try #require(terms.first { $0.ref == "t_POL1" })
        #expect(pol.term == "POL")
        #expect(pol.definition == "petroleum, oil, lubricants; political")

        let uar = try #require(terms.first { $0.ref == "t_UAR1" })
        #expect(uar.definition == "United Arab Republic")

        let bare = try #require(terms.first { $0.ref == "t_BARE1" })
        #expect(bare.definition == nil, "No trailing text means no definition")
    }
}

// MARK: - CrossRefResolverTests (Session 162)

/// Covers `FRUSURLSchemeHandler.resolveCrossRefTarget` — the normaliser behind
/// every in-document cross-reference tap (Session 162 link audit).
struct CrossRefResolverTests {

    @Test("Same-volume document anchors resolve with the caller's volume untouched")
    func sameVolumeDocument() {
        let dest = FRUSURLSchemeHandler.resolveCrossRefTarget("#d80", volumeId: nil)
        #expect(dest == .document(volumeId: nil, documentId: "d80"))
    }

    @Test("Cross-volume targets extract both volume and document, even with no volume hint")
    func crossVolumeDocument() {
        // macOS used to pass the raw target through and navigate to
        // "frus1964-68v18#d65" as a document ID.
        let dest = FRUSURLSchemeHandler.resolveCrossRefTarget("frus1964-68v18#d65", volumeId: nil)
        #expect(dest == .document(volumeId: "frus1964-68v18", documentId: "d65"))

        let withHint = FRUSURLSchemeHandler.resolveCrossRefTarget(
            "frus1964-68v18#d65", volumeId: "frus1964-68v18")
        #expect(withHint == .document(volumeId: "frus1964-68v18", documentId: "d65"))
    }

    @Test("Footnote-suffixed document ids resolve to the base document")
    func footnoteSuffixedDocument() {
        let dest = FRUSURLSchemeHandler.resolveCrossRefTarget("#d100fn2", volumeId: nil)
        #expect(dest == .document(volumeId: nil, documentId: "d100"))
    }

    @Test("Printed-page anchors resolve to page numbers; roman numerals are unresolved")
    func pageAnchors() {
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget("#pg_313", volumeId: nil)
                == .page(volumeId: nil, page: 313))
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget("frus1955-57v17#pg_313", volumeId: nil)
                == .page(volumeId: "frus1955-57v17", page: 313))
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget("#pg_XIII", volumeId: nil)
                == .unresolved)
    }

    @Test("Bare footnote/figure anchors and external URLs classify correctly")
    func otherAnchors() {
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget("#fn3", volumeId: nil) == .unresolved)
        #expect(FRUSURLSchemeHandler.resolveCrossRefTarget("", volumeId: nil) == .unresolved)
        if case .external(let url) = FRUSURLSchemeHandler.resolveCrossRefTarget(
            "http://bookstore.gpo.gov", volumeId: nil) {
            #expect(url.host == "bookstore.gpo.gov")
        } else {
            Issue.record("Expected .external for an http target")
        }
    }
}

// MARK: - SpuriousAutolinkTests

/// #659: upstream autolink noise renders as plain text, and nothing else does.
///
/// Drives the **real converter**, not a hand-built `FRUSRenderNode` — the bug is in the AST →
/// render-node step, so a test that constructs the output node cannot see it. (That is what
/// `ExternalRefTargetRoundTripTests` does, correctly, for the serializer half; it is parameterised
/// over `http://would.be`, one of the very targets de-linked here, and still passes because it
/// never asks the converter anything.)
///
/// The **kept** cases matter more than the de-linked ones. The failure this predicate invites is
/// over-reach: a rule that de-links every external link in the app would satisfy every negative
/// assertion below and break real navigation in twenty-eight volumes.
///
/// Version history:
///   1.0 — Session 2026-08-09: #659
@Suite("Spurious autolinks (#659)")
struct SpuriousAutolinkTests {

    /// Converts one `<ref>` in isolation and reports whether a link node survived.
    private func renders(target: String, text: String) -> (isLink: Bool, flat: String) {
        var converter = ASTToRenderNodeConverter()
        let model = converter.convert(FRUSDocumentAST(documentId: "d1", nodes: [
            .paragraph(children: [
                .crossReference(target: target, targetVolumeId: nil, children: [.text(text)]),
            ]),
        ]))
        var foundLink = false
        var flat = ""
        func walk(_ nodes: [FRUSRenderNode]) {
            for node in nodes {
                switch node {
                case .crossRefLink(_, _, _, let c): foundLink = true; walk(c)
                case .plainText(let s): flat += s
                case .paragraph(let c): walk(c)
                default: break
                }
            }
        }
        walk(model.bodyNodes)
        return (foundLink, flat)
    }

    @Test("An autolinked prose phrase renders as text, keeping its words", arguments: [
        // Every distinct shape in the corpus: two words, one word, an OCR-mangled word, a word
        // that is its own host, and a phrase carrying punctuation.
        ("http://must.be", "must be"),
        ("http://presen.ce", "presence"),
        ("http://pha.ll", "Shall"),
        ("http://would.be", "would.be"),
        ("http://felt.it", "felt. it"),
    ])
    func autolinkNoiseIsDelinked(target: String, text: String) {
        let result = renders(target: target, text: text)
        #expect(!result.isLink, """
            \(target) survived as a link. It is upstream autolink noise over the prose \
            "\(text)" — the host does not exist, so the tap leaves the app for nothing.
            """)
        #expect(result.flat == text, "the words must still be readable, only unlinked")
    }

    @Test("A real external link survives", arguments: [
        // Deep target, prose link text — the five frus1917-72PubDip supplement PDFs. The
        // "link text is not a URL" half of the predicate would de-link these on its own.
        ("https://static.history.state.gov/frus/frus1917-72PubDip/Document%20A.6.pdf",
         "a high resolution color PDF"),
        // Bare host, URL link text — thirty of these ship. The "bare host" half of the predicate
        // would de-link these on its own.
        ("http://bookstore.gpo.gov", "http://bookstore.gpo.gov"),
        ("http://www.un.org", "http://www.un.org"),
        // Deep target AND URL text.
        ("http://foia.state.gov/documents/kissinger/0000CF5A.pdf",
         "http://foia.state.gov/documents/kissinger/0000CF5A.pdf"),
    ])
    func realExternalLinksSurvive(target: String, text: String) {
        #expect(renders(target: target, text: text).isLink, """
            \(target) was de-linked. Both halves of the predicate are load-bearing: bare-host \
            alone kills the GPO bookstore links, non-URL-text alone kills the supplement PDFs.
            """)
    }

    @Test("In-corpus cross-references are untouched")
    func internalReferencesSurvive() {
        #expect(renders(target: "#d42", text: "Document 42").isLink)
        #expect(renders(target: "frus1969-76v01#d42", text: "Document 42").isLink)
        #expect(renders(target: "mailto:history@state.gov", text: "history@state.gov").isLink,
                "the scheme gate is http(s) only — mailto refs are real and 46 of them ship")
    }

    @Test("Flat text is unchanged, so no stored highlight goes stale")
    func flatTextIsUnchanged() {
        // The reason `ASTToRenderNodeConverter.kVersion` must NOT be bumped for #659: a link node
        // and its de-linked children contribute identical characters, so every stored
        // `DocumentHighlight.renderingVersion` still matches.
        #expect(renders(target: "http://must.be", text: "must be").flat
                == renders(target: "#d42", text: "must be").flat)
        #expect(ASTToRenderNodeConverter.kVersion == "1.2", """
            kVersion changed. If that was for #659 it is wrong — de-linking moves no characters, \
            and a bump marks every highlight in every indexed volume stale.
            """)
    }
}
