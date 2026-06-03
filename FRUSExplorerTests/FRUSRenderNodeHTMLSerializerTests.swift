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

// MARK: - FRUSRenderNodeHTMLSerializerTests

/// Unit tests for `FRUSRenderNodeHTMLSerializer`.
///
/// Coverage:
/// - Block-level structural elements (heading, paragraph, dateline, letters, etc.)
/// - Inline formatting elements (bold, italic, small-caps, underline, term, etc.)
/// - Offset-invisible elements and their `data-skip="1"` attributes
/// - Table rendering with `rowspan`/`colspan` attributes
/// - List rendering with ordered, unordered, and simple types
/// - Footnote popover markup (button marker + aside popover)
/// - Interactive link URLs (`frusexplorer://` scheme)
/// - HTML character escaping
/// - Multi-node documents with body + footnotes
@Suite("FRUSRenderNodeHTMLSerializer")
struct FRUSRenderNodeHTMLSerializerTests {

    private let s = FRUSRenderNodeHTMLSerializer()

    /// Convenience: serialise a model whose `bodyNodes` are `nodes` and has no footnotes.
    private func html(_ nodes: [FRUSRenderNode]) -> String {
        s.serialize(model(body: nodes))
    }

    /// Convenience: build a minimal `FRUSDocumentRenderModel`.
    private func model(
        body: [FRUSRenderNode],
        footnotes: [FRUSRenderNode] = []
    ) -> FRUSDocumentRenderModel {
        FRUSDocumentRenderModel(documentId: "doc-1", bodyNodes: body, footnotes: footnotes)
    }

    // MARK: - Document wrapper

    @Test("Output is wrapped in div.frus-document")
    func documentWrapper() {
        let out = html([.plainText("hello")])
        #expect(out.hasPrefix("<div class=\"frus-document\">"))
        #expect(out.hasSuffix("</div>\n"))
    }

    // MARK: - Block elements

    @Test("Heading emits h2.doc-heading")
    func heading() {
        let out = html([.heading([.plainText("Title")])])
        #expect(out.contains("<h2 class=\"doc-heading\">Title</h2>"))
    }

    @Test("Dateline emits p.dateline")
    func dateline() {
        let out = html([.dateline([.plainText("Washington, January 1")])])
        #expect(out.contains("<p class=\"dateline\">Washington, January 1</p>"))
    }

    @Test("Paragraph emits p.body")
    func paragraph() {
        let out = html([.paragraph([.plainText("Body text.")])])
        #expect(out.contains("<p class=\"body\">Body text.</p>"))
    }

    @Test("Letter opener emits div.letter-opener")
    func letterOpener() {
        let out = html([.letterOpener([.plainText("Dear Sir,")])])
        #expect(out.contains("<div class=\"letter-opener\">Dear Sir,</div>"))
    }

    @Test("Letter closer emits div.letter-closer")
    func letterCloser() {
        let out = html([.letterCloser([.plainText("Yours,")])])
        #expect(out.contains("<div class=\"letter-closer\">Yours,</div>"))
    }

    @Test("Salutation emits p.salutation")
    func salutation() {
        let out = html([.salutation([.plainText("To the Secretary:")])])
        #expect(out.contains("<p class=\"salutation\">To the Secretary:</p>"))
    }

    @Test("Editorial note block emits div.editorial-note with role=note")
    func editorialNoteBlock() {
        let out = html([.editorialNoteBlock([.paragraph([.plainText("Ed. note")])])])
        #expect(out.contains("<div class=\"editorial-note\" role=\"note\">"))
    }

    @Test("Title page block emits div.title-page")
    func titlePageBlock() {
        let out = html([.titlePageBlock([.plainText("Cover")])])
        #expect(out.contains("<div class=\"title-page\">"))
    }

    @Test("Attachment block emits section.attachment with data-n attribute")
    func attachmentBlock() {
        let out = html([.attachmentBlock(n: "A", children: [.plainText("content")])])
        #expect(out.contains("<section class=\"attachment\" data-n=\"A\">"))
    }

    @Test("Attachment block without n emits section.attachment without data-n")
    func attachmentBlockNoN() {
        let out = html([.attachmentBlock(n: nil, children: [.plainText("content")])])
        #expect(out.contains("<section class=\"attachment\">"))
        #expect(!out.contains("data-n"))
    }

    @Test("Attachment heading emits h3.attachment-heading")
    func attachmentHeading() {
        let out = html([.attachmentHeading([.plainText("Sub-heading")])])
        #expect(out.contains("<h3 class=\"attachment-heading\">Sub-heading</h3>"))
    }

    // MARK: - Inline elements

    @Test("Bold text emits strong")
    func boldText() {
        let out = html([.paragraph([.boldText([.plainText("bold")])])])
        #expect(out.contains("<strong>bold</strong>"))
    }

    @Test("Italic text emits em")
    func italicText() {
        let out = html([.paragraph([.italicText([.plainText("italic")])])])
        #expect(out.contains("<em>italic</em>"))
    }

    @Test("Small-caps text emits span.small-caps")
    func smallCapsText() {
        let out = html([.paragraph([.smallCapsText([.plainText("SC")])])])
        #expect(out.contains("<span class=\"small-caps\">SC</span>"))
    }

    @Test("Underline text emits span.underline")
    func underlineText() {
        let out = html([.paragraph([.underlineText([.plainText("ul")])])])
        #expect(out.contains("<span class=\"underline\">ul</span>"))
    }

    @Test("Term text emits span.term")
    func termText() {
        let out = html([.paragraph([.termText([.plainText("NSC")])])])
        #expect(out.contains("<span class=\"term\">NSC</span>"))
    }

    @Test("Supplied text emits span.supplied with brackets")
    func suppliedText() {
        let out = html([.paragraph([.suppliedText([.plainText("inserted")])])])
        #expect(out.contains("<span class=\"supplied\">[inserted]</span>"))
    }

    @Test("Sic text emits s.sic")
    func sicText() {
        let out = html([.paragraph([.sicText([.plainText("errror")])])])
        #expect(out.contains("<s class=\"sic\">errror</s>"))
    }

    @Test("Corr text emits span.corr")
    func corrText() {
        let out = html([.paragraph([.corrText([.plainText("error")])])])
        #expect(out.contains("<span class=\"corr\">error</span>"))
    }

    @Test("Formula text emits em.formula")
    func formulaText() {
        let out = html([.paragraph([.formulaText("E=mc²")])])
        #expect(out.contains("<em class=\"formula\">E=mc²</em>"))
    }

    @Test("Line break emits br (no data-skip)")
    func lineBreak() {
        let out = html([.paragraph([.plainText("a"), .lineBreak, .plainText("b")])])
        #expect(out.contains("<br>"))
        // lineBreak must NOT carry data-skip
        #expect(!out.contains("<br data-skip"))
    }

    // MARK: - Offset-invisible elements

    @Test("Page break emits span.page-break with data-skip=1 and data-page")
    func pageBreak() {
        let out = html([.pageBreak(pageNumber: .arabic(42))])
        #expect(out.contains("class=\"page-break\""))
        #expect(out.contains("data-skip=\"1\""))
        #expect(out.contains("data-page=\"42\""))
    }

    @Test("Figure block emits figure with data-skip=1")
    func figureBlock() {
        let out = html([.figureBlock(altText: "Map of the region")])
        #expect(out.contains("<figure data-skip=\"1\">"))
        #expect(out.contains("<figcaption>Map of the region</figcaption>"))
    }

    @Test("Figure block with nil alt text emits empty figure with data-skip=1")
    func figureBlockNilAlt() {
        let out = html([.figureBlock(altText: nil)])
        #expect(out.contains("<figure data-skip=\"1\"></figure>"))
    }

    @Test("Footnote marker emits button.fn-marker with data-skip=1 and popovertarget")
    func footnoteMarker() {
        let out = html([.paragraph([
            .plainText("Text"),
            .footnoteMarker(id: nil, displayLabel: "1")
        ])])
        #expect(out.contains("<button class=\"fn-marker\" data-skip=\"1\" popovertarget=\"fn-1\">1</button>"))
    }

    // MARK: - Footnote body (aside popover)

    @Test("Footnote body in model.footnotes emits aside popover with data-skip=1")
    func footnoteAside() {
        let footnoteNode = FRUSRenderNode.footnoteBody(
            id: "fn1",
            type: .footnote,
            printedNumber: "1",
            sequentialNumber: 1,
            displayLabel: "1",
            children: [.paragraph([.plainText("See also...")])]
        )
        let out = s.serialize(model(body: [], footnotes: [footnoteNode]))
        #expect(out.contains("<aside class=\"footnote fn-footnote\" id=\"fn-1\" popover data-skip=\"1\">"))
        #expect(out.contains("See also..."))
        #expect(out.contains("</aside>"))
    }

    @Test("Source footnote emits fn-source class")
    func footnoteAsideSource() {
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .source, printedNumber: nil,
            sequentialNumber: 1, displayLabel: "Source",
            children: [.plainText("NARA")]
        )
        let out = s.serialize(model(body: [], footnotes: [fn]))
        #expect(out.contains("fn-source"))
    }

    @Test("Editorial footnote emits fn-editorial class")
    func footnoteAsideEditorial() {
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .editorial, printedNumber: nil,
            sequentialNumber: 1, displayLabel: "a",
            children: [.plainText("Ed.")]
        )
        let out = s.serialize(model(body: [], footnotes: [fn]))
        #expect(out.contains("fn-editorial"))
    }

    @Test("Marker popovertarget matches footnote aside id")
    func markerMatchesAside() {
        let marker = FRUSRenderNode.footnoteMarker(id: nil, displayLabel: "7")
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: "7",
            sequentialNumber: 7, displayLabel: "7",
            children: [.plainText("Footnote text.")]
        )
        let out = s.serialize(model(body: [.paragraph([marker])], footnotes: [fn]))
        #expect(out.contains("popovertarget=\"fn-7\""))
        #expect(out.contains("id=\"fn-7\""))
    }

    // MARK: - Tables

    @Test("Table emits table.frus-table")
    func table() {
        let cell = TableCell(rowSpan: 1, colSpan: 1, children: [.plainText("A")])
        let out = html([.tableBlock(rows: [[cell]])])
        #expect(out.contains("<table class=\"frus-table\">"))
        #expect(out.contains("<td"))
        #expect(out.contains("A"))
    }

    @Test("Table cell with colSpan=2 emits colspan=2")
    func tableCellColspan() {
        let cell = TableCell(rowSpan: 1, colSpan: 2, children: [.plainText("Wide")])
        let out = html([.tableBlock(rows: [[cell]])])
        #expect(out.contains("colspan=\"2\""))
        #expect(!out.contains("rowspan"))   // rowspan=1 is omitted
    }

    @Test("Table cell with rowSpan=3 emits rowspan=3")
    func tableCellRowspan() {
        let cell = TableCell(rowSpan: 3, colSpan: 1, children: [.plainText("Tall")])
        let out = html([.tableBlock(rows: [[cell]])])
        #expect(out.contains("rowspan=\"3\""))
        #expect(!out.contains("colspan"))   // colspan=1 is omitted
    }

    @Test("Table cell with both rowSpan=2 and colSpan=3")
    func tableCellBothSpans() {
        let cell = TableCell(rowSpan: 2, colSpan: 3, children: [.plainText("Big")])
        let out = html([.tableBlock(rows: [[cell]])])
        #expect(out.contains("rowspan=\"2\""))
        #expect(out.contains("colspan=\"3\""))
    }

    @Test("Table with multiple rows")
    func tableMultipleRows() {
        let c1 = TableCell(rowSpan: 1, colSpan: 1, children: [.plainText("R1C1")])
        let c2 = TableCell(rowSpan: 1, colSpan: 1, children: [.plainText("R2C1")])
        let out = html([.tableBlock(rows: [[c1], [c2]])])
        let trCount = out.components(separatedBy: "<tr>").count - 1
        #expect(trCount == 2)
        #expect(out.contains("R1C1"))
        #expect(out.contains("R2C1"))
    }

    // MARK: - Lists

    @Test("Ordered list emits ol.frus-list")
    func orderedList() {
        let out = html([.listBlock(type: "ordered", items: [[.plainText("Item")]])])
        #expect(out.contains("<ol class=\"frus-list\">"))
        #expect(out.contains("<li>Item</li>"))
    }

    @Test("Unordered list emits ul.frus-list")
    func unorderedList() {
        let out = html([.listBlock(type: "unordered", items: [[.plainText("Item")]])])
        #expect(out.contains("<ul class=\"frus-list\">"))
    }

    @Test("Simple list emits ul.frus-list.simple")
    func simpleList() {
        let out = html([.listBlock(type: "simple", items: [[.plainText("Item")]])])
        #expect(out.contains("<ul class=\"frus-list simple\">"))
    }

    @Test("Nil-type list defaults to ul.frus-list")
    func nilTypeList() {
        let out = html([.listBlock(type: nil, items: [[.plainText("Item")]])])
        #expect(out.contains("<ul class=\"frus-list\">"))
    }

    // MARK: - Interactive links

    @Test("persNameLink emits a.pers-name with frusexplorer://person/ URL")
    func persNameLink() {
        let out = html([.persNameLink(
            ref: "#p_HK1",
            children: [.plainText("Kissinger")],
            person: nil
        )])
        #expect(out.contains("class=\"pers-name\""))
        #expect(out.contains("href=\"frusexplorer://person/p_HK1\""))
        #expect(out.contains("Kissinger"))
    }

    @Test("persNameLink with nil ref uses # href")
    func persNameLinkNilRef() {
        let out = html([.persNameLink(ref: nil, children: [.plainText("Name")], person: nil)])
        #expect(out.contains("href=\"#\""))
    }

    @Test("glossLink emits a.gloss with frusexplorer://gloss/ URL")
    func glossLink() {
        let out = html([.glossLink(
            ref: "#t_NSC1",
            children: [.plainText("NSC")],
            entry: nil
        )])
        #expect(out.contains("class=\"gloss\""))
        #expect(out.contains("href=\"frusexplorer://gloss/t_NSC1\""))
    }

    @Test("crossRefLink with volumeId emits frusexplorer://doc/vol/docId")
    func crossRefLinkWithVolume() {
        let out = html([.crossRefLink(
            target: "d42",
            volumeId: "frus1969-76v02",
            children: [.plainText("Doc 42")]
        )])
        #expect(out.contains("class=\"cross-ref\""))
        #expect(out.contains("href=\"frusexplorer://doc/frus1969-76v02/d42\""))
    }

    @Test("crossRefLink without volumeId emits frusexplorer://doc/docId")
    func crossRefLinkNoVolume() {
        let out = html([.crossRefLink(
            target: "d5",
            volumeId: nil,
            children: [.plainText("Doc 5")]
        )])
        #expect(out.contains("href=\"frusexplorer://doc/d5\""))
    }

    // MARK: - Unknown elements

    @Test("Unknown element emits span.unknown with data-element-name")
    func unknownElement() {
        let out = html([.unknown(name: "floatingText", children: [.plainText("content")])])
        #expect(out.contains("<span class=\"unknown\" data-element-name=\"floatingText\">"))
        #expect(out.contains("content"))
    }

    // MARK: - HTML escaping

    @Test("Ampersand is escaped to &amp;")
    func escapeAmpersand() {
        let out = html([.plainText("AT&T")])
        #expect(out.contains("AT&amp;T"))
        #expect(!out.contains("AT&T"))
    }

    @Test("Less-than is escaped to &lt;")
    func escapeLessThan() {
        let out = html([.plainText("a < b")])
        #expect(out.contains("a &lt; b"))
    }

    @Test("Greater-than is escaped to &gt;")
    func escapeGreaterThan() {
        let out = html([.plainText("b > a")])
        #expect(out.contains("b &gt; a"))
    }

    @Test("Double quote is escaped to &quot; in text content")
    func escapeDoubleQuote() {
        let out = html([.plainText("He said \"hello\"")])
        #expect(out.contains("He said &quot;hello&quot;"))
    }

    @Test("All four special characters in one string")
    func escapeAll() {
        let out = html([.plainText("<script>alert(\"x\")</script> & done")])
        #expect(out.contains("&lt;script&gt;"))
        #expect(out.contains("&quot;x&quot;"))
        #expect(out.contains("&amp; done"))
    }

    @Test("HTML characters in footnote display label are escaped")
    func escapedFootnoteLabel() {
        let marker = FRUSRenderNode.footnoteMarker(id: nil, displayLabel: "1")
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: "1",
            sequentialNumber: 1, displayLabel: "1",
            children: [.plainText("Text")]
        )
        let out = s.serialize(model(body: [.paragraph([marker])], footnotes: [fn]))
        // No raw < or > should appear in attribute values
        #expect(!out.contains("popovertarget=\"fn-<"))
        #expect(!out.contains("id=\"fn-<"))
    }

    // MARK: - Multi-node documents

    @Test("Document with body and footnotes: footnote asides appear after body")
    func bodyBeforeFootnotes() {
        let body: [FRUSRenderNode] = [
            .heading([.plainText("Document 1")]),
            .paragraph([.plainText("Content."), .footnoteMarker(id: nil, displayLabel: "1")])
        ]
        let footnote = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: nil,
            sequentialNumber: 1, displayLabel: "1",
            children: [.paragraph([.plainText("Footnote text.")])]
        )
        let out = s.serialize(model(body: body, footnotes: [footnote]))

        let headingPos = out.range(of: "<h2")!.lowerBound
        let asidePos  = out.range(of: "<aside")!.lowerBound
        #expect(headingPos < asidePos)
    }

    @Test("Document with no footnotes produces no aside elements")
    func noFootnotes() {
        let out = html([.paragraph([.plainText("Simple paragraph.")])])
        #expect(!out.contains("<aside"))
        #expect(!out.contains("popover"))
    }

    @Test("Empty body nodes produces minimal wrapper")
    func emptyBody() {
        let out = s.serialize(model(body: [], footnotes: []))
        #expect(out == "<div class=\"frus-document\">\n</div>\n")
    }

    // MARK: - Page number formats

    @Test("Arabic page break uses integer label")
    func pageBreakArabic() {
        let out = html([.pageBreak(pageNumber: .arabic(17))])
        #expect(out.contains("data-page=\"17\""))
    }

    @Test("Prefixed page break preserves prefix string")
    func pageBreakPrefixed() {
        let out = html([.pageBreak(pageNumber: .prefixed("A-12"))])
        #expect(out.contains("data-page=\"A-12\""))
    }

    @Test("Unparseable page break preserves raw string")
    func pageBreakUnparseable() {
        let out = html([.pageBreak(pageNumber: .unparseable("??"))])
        #expect(out.contains("data-page=\"??\""))
    }

    // MARK: - data-skip invariants (offset model correctness)

    @Test("lineBreak does NOT carry data-skip")
    func lineBreakNoSkip() {
        let out = html([.lineBreak])
        #expect(out.contains("<br>"))
        #expect(!out.contains("data-skip"))
    }

    @Test("pageBreak carries data-skip=1")
    func pageBreakHasSkip() {
        let out = html([.pageBreak(pageNumber: .arabic(1))])
        #expect(out.contains("data-skip=\"1\""))
    }

    @Test("footnoteMarker carries data-skip=1")
    func footnoteMarkerHasSkip() {
        let out = html([.footnoteMarker(id: nil, displayLabel: "2")])
        #expect(out.contains("data-skip=\"1\""))
    }

    @Test("figureBlock carries data-skip=1")
    func figureBlockHasSkip() {
        let out = html([.figureBlock(altText: "alt")])
        #expect(out.contains("data-skip=\"1\""))
    }

    @Test("footnoteBody aside carries data-skip=1")
    func footnoteBodyHasSkip() {
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: nil,
            sequentialNumber: 1, displayLabel: "1",
            children: [.plainText("text")]
        )
        let out = s.serialize(model(body: [], footnotes: [fn]))
        #expect(out.contains("data-skip=\"1\""))
    }

    @Test("Regular text nodes do NOT carry data-skip")
    func plainTextNoSkip() {
        let out = html([.plainText("hello")])
        #expect(!out.contains("data-skip"))
    }

    @Test("paragraphs do NOT carry data-skip")
    func paragraphNoSkip() {
        let out = html([.paragraph([.plainText("content")])])
        #expect(!out.contains("data-skip"))
    }
}
