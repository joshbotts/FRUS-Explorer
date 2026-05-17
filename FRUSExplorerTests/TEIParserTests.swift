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
             .unknown(_, _, let c):
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
             .unknown(_, _, let c):
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
                     .unknown(_, _, let c):
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

    @Test("Converter: footnotes are numbered sequentially in document order")
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
            #expect(l1 == "1")
        }
        if case .footnoteBody(_, _, _, let n2, let l2, _) = model.footnotes[1] {
            #expect(n2 == 2)
            #expect(l2 == "2")
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
                if case .footnoteMarker(_, let label) = node { return label }
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

    // MARK: - Session 54: Cross-Ref AttributedString Rendering

    @Test("Paragraph with crossRefLink renders AttributedString with frusexplorer:// link")
    @MainActor
    func crossRefLinkAttributedStringContainsURL() throws {
        // Build a minimal render model containing a crossRefLink node.
        let nodes: [FRUSRenderNode] = [
            .plainText("See "),
            .crossRefLink(target: "#d185", volumeId: "frus1989-92v31",
                          children: [.plainText("Document 185")]),
            .plainText(".")
        ]
        let renderer = FRUSDocumentRenderer(
            model: FRUSDocumentRenderModel(documentId: "d186", bodyNodes: [], footnotes: [])
        )

        // Access the AttributedString via the internal helper.
        // We test the public observable effect: containsCrossRef must return true
        // and the attributed string must carry a .link attribute on the cross-ref run.
        let attrStr = renderer.testInlineAttributedString(nodes)
        var foundLink = false
        for run in attrStr.runs {
            if let url = run.link, url.scheme == "frusexplorer" {
                foundLink = true
                #expect(url.absoluteString.contains("d185"), "URL should encode target doc ID")
                #expect(url.absoluteString.contains("frus1989-92v31"), "URL should encode volume ID")
            }
        }
        #expect(foundLink, "No frusexplorer:// link found in AttributedString runs")
    }
}
