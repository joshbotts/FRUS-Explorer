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
        // No trailing newline — compact HTML to avoid spurious DOM text nodes
        #expect(out.hasSuffix("</div>"))
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

    @Test("Footnote marker emits button.fn-marker with data-skip=1, popovertarget, and aria-label")
    func footnoteMarker() {
        let out = html([.paragraph([
            .plainText("Text"),
            .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1")
        ])])
        #expect(out.contains("class=\"fn-marker\""))
        #expect(out.contains("data-skip=\"1\""))
        // #985: the target is the DOM key, not the label. This node carries no xml:id, so it
        // takes the synthesised branch of `FRUSRenderNode.footnoteDOMKey`.
        #expect(out.contains("popovertarget=\"fn-n-1\""))
        #expect(out.contains("aria-label=\"Footnote 1\""))
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
        // #985: this fixture always supplied an xml:id ("fn1") that the old serializer discarded
        // in favour of the label. The id now comes from it.
        #expect(out.contains("<aside class=\"footnote fn-footnote\" id=\"fn-x-fn1\" popover data-skip=\"1\">"))
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
        let marker = FRUSRenderNode.footnoteMarker(id: nil, type: .footnote, sequentialNumber: 7, displayLabel: "7")
        let fn = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: "7",
            sequentialNumber: 7, displayLabel: "7",
            children: [.plainText("Footnote text.")]
        )
        let out = s.serialize(model(body: [.paragraph([marker])], footnotes: [fn]))
        #expect(out.contains("popovertarget=\"fn-n-7\""))
        #expect(out.contains("id=\"fn-n-7\""))
    }

    /// #985: the test above passed throughout the lifetime of the duplicate-id bug, because a
    /// model holding one footnote cannot express a collision. This is the two-note version — an
    /// unnumbered source note ahead of a real footnote 1, which is what shipped.
    @Test("Two notes sharing a display label still get distinct ids")
    func collidingLabelsGetDistinctIDs() {
        let sourceMarker = FRUSRenderNode.footnoteMarker(
            id: nil, type: .source, sequentialNumber: 1, displayLabel: nil)
        let bodyMarker = FRUSRenderNode.footnoteMarker(
            id: "d1fn1", type: .footnote, sequentialNumber: 2, displayLabel: "1")
        let sourceNote = FRUSRenderNode.footnoteBody(
            id: nil, type: .source, printedNumber: nil, sequentialNumber: 1,
            displayLabel: nil, children: [.plainText("782.022/5-350")])
        let bodyNote = FRUSRenderNode.footnoteBody(
            id: "d1fn1", type: .footnote, printedNumber: "1", sequentialNumber: 2,
            displayLabel: "1", children: [.plainText("Not printed.")])

        let out = s.serialize(model(body: [.paragraph([sourceMarker, bodyMarker])],
                                    footnotes: [sourceNote, bodyNote]))

        let ids = out.matches(of: /id="([^"]*)"/).map { String($0.1) }
        #expect(Set(ids).count == ids.count, "duplicate ids emitted: \(ids)")

        let targets = out.matches(of: /popovertarget="([^"]*)"/).map { String($0.1) }
        #expect(targets == ["fn-n-1", "fn-x-d1fn1"],
                "each marker must target its own note, got \(targets)")
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

    @Test("crossRefLink with volumeId emits frusexplorer://doc/docId/vol (target first)")
    func crossRefLinkWithVolume() {
        let out = html([.crossRefLink(
            target: "d42",
            volumeId: "frus1969-76v02",
            broken: nil,
            children: [.plainText("Doc 42")]
        )])
        #expect(out.contains("class=\"cross-ref\""))
        // Target is first so FRUSURLSchemeHandler can extract it as pathComponents[0].
        #expect(out.contains("href=\"frusexplorer://doc/d42/frus1969-76v02\""))
    }

    @Test("crossRefLink without volumeId emits frusexplorer://doc/docId")
    func crossRefLinkNoVolume() {
        let out = html([.crossRefLink(
            target: "d5",
            volumeId: nil,
            broken: nil,
            children: [.plainText("Doc 5")]
        )])
        #expect(out.contains("href=\"frusexplorer://doc/d5\""))
    }

    @Test("A broken crossRefLink emits a non-navigable brokenref span, not a doc link")
    func crossRefLinkBroken() {
        let info = BrokenRefInfo(target: "frus1877#pg_1077", reason: "unknownPage",
                                 resolvedVolume: "frus1877", resolvedAnchor: "pg_1077")
        let out = html([.crossRefLink(
            target: "frus1877#pg_1077",
            volumeId: "frus1877",
            broken: info,
            children: [.plainText("page 1077")]
        )])
        #expect(out.contains("class=\"cross-ref-broken\""))
        #expect(out.contains("frusexplorer://brokenref/"))
        #expect(!out.contains("frusexplorer://doc/"))
        // The marker glyph must be offset-invisible so it doesn't shift highlight offsets.
        #expect(out.contains("cross-ref-broken-mark") && out.contains("data-skip=\"1\""))
        #expect(out.contains("role=\"button\""))
        // The display text (children) is preserved as real flat text.
        #expect(out.contains("page 1077"))
    }

    @Test("brokenref href round-trips hostile targets through the scheme handler dispatch")
    @MainActor
    func brokenRefRoundTrip() throws {
        // Targets with '/', '%', '#', and spaces — the strict alphanumeric encoding plus the
        // dispatch's single decode must recover the verbatim string in every case.
        for target in ["frus1877#pg_1077", "#dX", "a/b#pg_1", "we%2Fird#x", "sp ace#1"] {
            let info = BrokenRefInfo(target: target, reason: "unknownAnchor",
                                     resolvedVolume: nil, resolvedAnchor: nil)
            let out = html([.crossRefLink(target: target, volumeId: nil,
                                          broken: info, children: [.plainText("t")])])
            // Extract the emitted href.
            guard let range = out.range(of: "href=\"frusexplorer://brokenref/"),
                  let end = out[range.upperBound...].firstIndex(of: "\"") else {
                Issue.record("no brokenref href for \(target)"); continue
            }
            let encoded = String(out[range.upperBound..<end])
            let url = try #require(URL(string: "frusexplorer://brokenref/\(encoded)"))

            let handler = FRUSURLSchemeHandler()
            let model = FRUSDocumentRenderModel(
                documentId: "d1",
                bodyNodes: [.crossRefLink(target: target, volumeId: nil,
                                          broken: info, children: [.plainText("t")])],
                footnotes: [])
            handler.register(model: model)
            var received: BrokenRefInfo?
            handler.onBrokenRefTap = { received = $0 }
            handler.dispatch(url: url)
            #expect(received?.target == target, "round-trip failed for \(target)")
        }
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
        let marker = FRUSRenderNode.footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1")
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
            .paragraph([.plainText("Content."), .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1")])
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
        #expect(out == "<div class=\"frus-document\"></div>")
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
        let out = html([.footnoteMarker(id: nil, type: .footnote, sequentialNumber: 2, displayLabel: "2")])
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

// MARK: - ClassificationChipSerializationTests (Source Explorer Phase 5)

/// Verifies the opt-in classification chip on `.source` footnotes: present in both
/// the popover aside and the visible footnotes section when the serializer is
/// created with `annotateSourceClassification: true` and the note carries a
/// confident marking sentence; absent by default (exports byte-identical), absent
/// for non-source footnotes, and absent when the note has no marking sentence.
///
/// Version history:
///   1.0 — Session 2026-07-04: Source Explorer Phase 5 step 1
@Suite("FRUSRenderNodeHTMLSerializer — classification chip")
struct ClassificationChipSerializationTests {

    /// A source footnote whose sentence 2 is a classification-markings sentence.
    private let sourceWithMarking = FRUSRenderNode.footnoteBody(
        id: "fn1", type: .source, printedNumber: "1",
        sequentialNumber: 1, displayLabel: "1",
        children: [.paragraph([.plainText(
            "Source: National Archives, RG 59, Central Files 1967-69, POL 27 ARAB-ISR. Secret; Nodis. Drafted by Read.")])]
    )

    private func serialize(_ footnote: FRUSRenderNode, annotate: Bool) -> String {
        FRUSRenderNodeHTMLSerializer(annotateSourceClassification: annotate)
            .serialize(FRUSDocumentRenderModel(documentId: "doc-1", bodyNodes: [], footnotes: [footnote]))
    }

    @Test("Annotated source footnote gets the chip in aside AND footnotes section")
    func chipPresentWhenAnnotated() {
        let out = serialize(sourceWithMarking, annotate: true)
        let occurrences = out.components(separatedBy: "class=\"classification-chip\"").count - 1
        #expect(occurrences == 2,
                "the chip must appear in the popover aside and the visible footnotes section; got \(occurrences)")
        #expect(out.contains(">Secret; Nodis</span>"),
                "the chip text is the extracted marking sentence")
        #expect(out.contains("aria-label=\"Classification markings: Secret; Nodis\""),
                "assistive tech gets an explicit prefix")
    }

    @Test("Default serializer (exports) emits no chip")
    func chipAbsentByDefault() {
        let out = serialize(sourceWithMarking, annotate: false)
        #expect(!out.contains("classification-chip"),
                "export output must be unchanged by the Phase 5 chip")
    }

    @Test("Non-source footnotes never get a chip")
    func chipAbsentForRegularFootnote() {
        let fn = FRUSRenderNode.footnoteBody(
            id: "fn2", type: .footnote, printedNumber: "2",
            sequentialNumber: 2, displayLabel: "2",
            children: [.paragraph([.plainText("See document 12. Secret; Nodis.")])]
        )
        let out = serialize(fn, annotate: true)
        #expect(!out.contains("classification-chip"))
    }

    @Test("Source note without a marking sentence gets no chip")
    func chipAbsentWithoutMarking() {
        let fn = FRUSRenderNode.footnoteBody(
            id: "fn3", type: .source, printedNumber: "1",
            sequentialNumber: 1, displayLabel: "1",
            children: [.paragraph([.plainText(
                "Source: Department of State, Central Files, 711.11/3-1545.")])]
        )
        let out = serialize(fn, annotate: true)
        #expect(!out.contains("classification-chip"),
                "a citation-only note has no sentence 2 marking — no chip, no junk")
    }

    @Test("Bracket-wrapped [Source: …] notes normalize before marking extraction")
    func chipHandlesBracketWrapper() {
        let fn = FRUSRenderNode.footnoteBody(
            id: "fn4", type: .source, printedNumber: "1",
            sequentialNumber: 1, displayLabel: "1",
            children: [.paragraph([.plainText(
                "[Source: Johnson Library, National Security File, Country File, Vietnam. Top Secret; Sensitive.]")])]
        )
        let out = serialize(fn, annotate: true)
        #expect(out.contains(">Top Secret; Sensitive</span>"),
                "the [Source: …] wrapper must collapse exactly as indexing does before extraction")
    }
}

// MARK: - HighlightInjectionTests (Session 7 #240B follow-up)

/// Verifies that `injectHighlights` places `<mark>` elements using the same
/// flat-text coordinate space as `frus-offset-engine.js` — i.e. it excludes every
/// `data-skip="1"` subtree (footnote-marker labels, figure captions, page-break
/// spans, the broken cross-reference dagger) and counts `<br>` as one character.
///
/// This guards the pre-existing offset-shift bug found in the Session 7 #240B
/// adversarial review: a flat position counter that counted skipped text would
/// drag every highlight after a footnote marker to the left and could emit a
/// boundary-crossing `<mark>` (opened inside a `<button>`, closed outside it).
///
/// Each test derives the highlight's offsets from the document's own flat text
/// (`flatText(of:)`, the offset coordinate space) so the assertions can't drift
/// out of sync with a hand-counted index.
@Suite("FRUSRenderNodeHTMLSerializer — highlight injection")
struct HighlightInjectionTests {

    private let s = FRUSRenderNodeHTMLSerializer()

    private func model(_ body: [FRUSRenderNode]) -> FRUSDocumentRenderModel {
        FRUSDocumentRenderModel(documentId: "doc-1", bodyNodes: body, footnotes: [])
    }

    /// Serialises `body` with a single yellow highlight over the flat-text range of
    /// `substring`. Offsets come from `flatText(of:)`, the exact space stored
    /// `DocumentHighlight` offsets live in.
    private func highlighted(_ body: [FRUSRenderNode], mark substring: String,
                             color: DocumentHighlight.Color = .yellow) -> String {
        let flat = flatText(of: body)
        guard let r = flat.range(of: substring) else {
            Issue.record("substring \(substring) not present in flat text \(flat)")
            return ""
        }
        let start = flat.distance(from: flat.startIndex, to: r.lowerBound)
        let end   = flat.distance(from: flat.startIndex, to: r.upperBound)
        return s.serialize(model(body), includeFootnotes: true,
                           highlights: [ExportHighlight(startOffset: start, endOffset: end, color: color)])
    }

    // MARK: - Baselines (no skipped subtrees)

    @Test("A whole-word highlight wraps exactly that word")
    func baselineWholeWord() {
        let out = highlighted([.paragraph([.plainText("Hello world")])], mark: "world")
        #expect(out.contains("<mark class=\"hl-yellow\">world</mark>"))
        #expect(out.contains("<p class=\"body\">Hello <mark class=\"hl-yellow\">world</mark></p>"))
    }

    @Test("A highlight over an HTML entity counts the entity as one character")
    func highlightOverEntity() {
        // "AT&T" serialises to "AT&amp;T"; flat text is "AT&T", so "&T" is 2..4.
        let out = highlighted([.paragraph([.plainText("AT&T")])], mark: "&T")
        #expect(out.contains("AT<mark class=\"hl-yellow\">&amp;T</mark>"))
    }

    // MARK: - Footnote markers (the reported bug)

    @Test("A highlight after a footnote marker is not dragged onto the marker label")
    func highlightAfterFootnoteMarker() {
        // Flat text = "Text more text" — the marker label "12" is offset-invisible.
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("Text "),
            .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 12, displayLabel: "12"),
            .plainText("more text")
        ])]
        let out = highlighted(body, mark: "more")
        // The mark opens *after* the button, on the real word "more".
        #expect(out.contains(">12</button><mark class=\"hl-yellow\">more</mark> text"))
        // It must NOT open inside the button on the "12" label (the old bug).
        #expect(!out.contains("<mark class=\"hl-yellow\">12"))
    }

    @Test("A highlight spanning a footnote marker is hoisted around the button")
    func highlightSpanningFootnoteMarker() {
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("Text "),
            .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 12, displayLabel: "12"),
            .plainText("more text")
        ])]
        // Highlight "Text more" — it straddles the offset-invisible marker.
        let out = highlighted(body, mark: "Text more")
        // The mark closes before the button and reopens after — never wrapping it,
        // so the <mark>/<button> nesting is well-formed.
        #expect(out.contains("<mark class=\"hl-yellow\">Text </mark><button"))
        #expect(out.contains(">12</button><mark class=\"hl-yellow\">more</mark> text"))
        // The button label is never inside a mark.
        #expect(!out.contains("<mark class=\"hl-yellow\">Text <button"))
        #expect(!out.contains("<mark class=\"hl-yellow\">12"))
    }

    // MARK: - Figure captions

    @Test("A highlight after a figure caption ignores the caption text")
    func highlightAfterFigcaption() {
        // Flat text = "After text" — the figcaption "Map of X" is offset-invisible.
        let body: [FRUSRenderNode] = [
            .figureBlock(altText: "Map of X"),
            .paragraph([.plainText("After text")])
        ]
        let out = highlighted(body, mark: "After")
        // The caption text survives verbatim, un-marked …
        #expect(out.contains("<figcaption>Map of X</figcaption>"))
        // … and the mark lands on the real word after the figure.
        #expect(out.contains("<mark class=\"hl-yellow\">After</mark> text"))
        #expect(!out.contains("<mark class=\"hl-yellow\">Map"))
    }

    // MARK: - Broken cross-reference dagger (data-skip span)

    @Test("A highlight after a broken cross-reference dagger ignores the dagger")
    func highlightAfterBrokenRefDagger() {
        // Flat text = "See page 1077 now" — the dagger glyph is offset-invisible.
        let broken = BrokenRefInfo(target: "frus1877#pg_1077", reason: "unknownPage",
                                   resolvedVolume: "frus1877", resolvedAnchor: "pg_1077")
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("See "),
            .crossRefLink(target: "frus1877#pg_1077", volumeId: "frus1877",
                          broken: broken, children: [.plainText("page 1077")]),
            .plainText(" now")
        ])]
        let out = highlighted(body, mark: "now")
        // The dagger span is present and offset-invisible …
        #expect(out.contains("cross-ref-broken-mark") && out.contains("data-skip=\"1\""))
        // … the mark lands on "now", never on the dagger or the link text.
        #expect(out.contains("<mark class=\"hl-yellow\">now</mark>"))
        #expect(!out.contains("<mark class=\"hl-yellow\">\u{2020}"))
        #expect(!out.contains("hl-yellow\">page"))
    }

    @Test("A highlight spanning into the broken-ref link hoists around the dagger")
    func highlightSpanningBrokenRefDagger() {
        let broken = BrokenRefInfo(target: "frus1877#pg_1077", reason: "unknownPage",
                                   resolvedVolume: "frus1877", resolvedAnchor: "pg_1077")
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("See "),
            .crossRefLink(target: "frus1877#pg_1077", volumeId: "frus1877",
                          broken: broken, children: [.plainText("page 1077")]),
            .plainText(" now")
        ])]
        // "1077 now" straddles the link's trailing dagger and the following text.
        let out = highlighted(body, mark: "1077 now")
        // The mark closes before the dagger span (inside the <a>) and reopens after
        // it (after the </a>) — the dagger is never inside a mark.
        #expect(out.contains("<mark class=\"hl-yellow\">1077</mark>"))
        #expect(!out.contains("<mark class=\"hl-yellow\">\u{2020}"))
        // "now" is still highlighted after the link closes.
        #expect(out.contains("<mark class=\"hl-yellow\"> now</mark>")
                || out.contains("<mark class=\"hl-yellow\">now</mark>"))
    }

    // MARK: - Line breaks (br counts as one flat character)

    @Test("A highlight after a line break lands on the right characters")
    func highlightAfterLineBreak() {
        // Flat text = "ab\ncd" — <br> counts as one "\n" character.
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("ab"), .lineBreak, .plainText("cd")
        ])]
        let out = highlighted(body, mark: "cd")
        #expect(out.contains("<br><mark class=\"hl-yellow\">cd</mark>"))
        #expect(!out.contains("<mark class=\"hl-yellow\">ab"))
    }

    @Test("A highlight before a line break stops at the break")
    func highlightBeforeLineBreak() {
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("ab"), .lineBreak, .plainText("cd")
        ])]
        let out = highlighted(body, mark: "ab")
        #expect(out.contains("<mark class=\"hl-yellow\">ab</mark><br>"))
    }

    // MARK: - Page break span

    @Test("A highlight after an empty page-break span ignores it")
    func highlightAfterPageBreak() {
        // Flat text = "abcd" — the page-break span contributes nothing.
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("ab"), .pageBreak(pageNumber: .arabic(5)), .plainText("cd")
        ])]
        let out = highlighted(body, mark: "cd")
        #expect(out.contains("</span><mark class=\"hl-yellow\">cd</mark>"))
        #expect(!out.contains("<mark class=\"hl-yellow\">ab"))
    }

    // MARK: - Footnote aside (data-skip subtree inside .frus-document)

    @Test("A body-spanning highlight is unaffected by the footnote aside popover")
    func highlightWithFootnoteAside() {
        // The aside popover is emitted inside .frus-document with data-skip="1";
        // its text must not shift or absorb a body highlight.
        let body: [FRUSRenderNode] = [.paragraph([
            .plainText("Alpha"),
            .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1"),
            .plainText("Bravo")
        ])]
        let footnote = FRUSRenderNode.footnoteBody(
            id: nil, type: .footnote, printedNumber: "1",
            sequentialNumber: 1, displayLabel: "1",
            children: [.paragraph([.plainText("Aside body text.")])]
        )
        let flat = flatText(of: body)   // "AlphaBravo"
        let r = flat.range(of: "Bravo")!
        let start = flat.distance(from: flat.startIndex, to: r.lowerBound)
        let end   = flat.distance(from: flat.startIndex, to: r.upperBound)
        let out = s.serialize(
            FRUSDocumentRenderModel(documentId: "doc-1", bodyNodes: body, footnotes: [footnote]),
            includeFootnotes: true,
            highlights: [ExportHighlight(startOffset: start, endOffset: end, color: .green)])
        #expect(out.contains(">1</button><mark class=\"hl-green\">Bravo</mark>"))
        // The aside's own text is never wrapped in a mark.
        #expect(out.contains("Aside body text."))
        #expect(!out.contains("<mark class=\"hl-green\">Aside"))
    }
}

// MARK: - ExternalRefTargetRoundTripTests

/// An external `<ref target>` must survive the trip from serializer to tap handler intact.
///
/// ## The bug
/// The cross-ref href was built with `.urlPathAllowed`, which permits **both `/` and `:`**. An
/// external target therefore arrived at `FRUSURLSchemeHandler.dispatch(url:)` already split:
/// `http://would.be` became `frusexplorer://doc/http://would.be`, whose path components are
/// `["http:", "would.be"]` — read as target `"http:"` in a **volume named `would.be`**. Tapping an
/// external link offered to download a volume that does not exist. The broken-ref branch of the
/// same function already guarded this and said so in a comment; the ordinary branch did not.
///
/// Corpus scale: 83 of 1,964,788 `<ref target>` values contain `/` or `:` — 53 `http`, 14 `https`,
/// 16 `mailto`. Some are real (`https://history.state.gov/historicaldocuments`,
/// `mailto:history@state.gov`); the 18 inside document bodies are autolink noise (#659). Both kinds
/// were broken the same way.
///
/// ## Why a round trip
/// Asserting the emitted string alone would pin an encoding without proving it decodes back, and
/// asserting the resolver alone would pass while the serializer still split the value. The two
/// halves are only correct *together*, so the test walks the real path: serialize → parse the href
/// exactly as `dispatch(url:)` does → resolve.
///
/// Version history:
///   1.0 — build 38: external targets misrouted as volume ids
@Suite("External ref target round trip")
struct ExternalRefTargetRoundTripTests {

    private let serializer = FRUSRenderNodeHTMLSerializer()

    /// Extracts the `frusexplorer://` href the serializer emitted for a cross-ref.
    private func emittedHref(target: String, volumeId: String? = nil) throws -> URL {
        let node = FRUSRenderNode.crossRefLink(
            target: target, volumeId: volumeId, broken: nil,
            children: [.plainText("link")])
        let html = serializer.serialize(
            FRUSDocumentRenderModel(documentId: "d303", bodyNodes: [node], footnotes: []))
        let match = try #require(html.firstMatch(of: /href="(frusexplorer:\/\/[^"]+)"/),
                                 "no frusexplorer href emitted for \(target)")
        return try #require(URL(string: String(match.1)), "emitted href is not a URL")
    }

    /// Reproduces `FRUSURLSchemeHandler.dispatch(url:)`'s parse, then resolves.
    private func resolve(_ url: URL) -> CrossRefDestination {
        let parts = url.pathComponents.filter { $0 != "/" }.map { $0.removingPercentEncoding ?? $0 }
        let target = parts.first ?? ""
        let volumeId: String? = parts.count >= 2 ? parts[1] : nil
        return FRUSURLSchemeHandler.resolveCrossRefTarget(target, volumeId: volumeId)
    }

    @Test("An http target round-trips to .external, not to a volume named after its host",
          arguments: ["http://would.be",
                      "http://bookstore.gpo.gov",
                      "https://history.state.gov/historicaldocuments",
                      "mailto:history@state.gov"])
    func externalTargetsSurvive(_ target: String) throws {
        let url = try emittedHref(target: target)
        guard case .external(let resolved) = resolve(url) else {
            Issue.record("""
                \(target) did not resolve to .external — it resolved to \(resolve(url)). Before the \
                fix this became a document lookup in a volume named after the URL's host, which \
                offered to download a volume that does not exist.
                """)
            return
        }
        #expect(resolved.absoluteString == target,
                "the target was mangled in transit: \(resolved.absoluteString) != \(target)")
    }

    /// The other 1.96M targets must be unaffected — including the two-component form, where the
    /// separating slash between target and volume id is structural and must stay literal.
    @Test("Ordinary cross-references are unchanged")
    func ordinaryTargetsUnaffected() throws {
        let sameVolume = try emittedHref(target: "d42")
        guard case .document(let vol, let doc) = resolve(sameVolume) else {
            Issue.record("d42 no longer resolves to a document"); return
        }
        #expect(vol == nil && doc == "d42")

        let crossVolume = try emittedHref(target: "d42", volumeId: "frus1969-76v01")
        guard case .document(let vol2, let doc2) = resolve(crossVolume) else {
            Issue.record("cross-volume target no longer resolves to a document"); return
        }
        #expect(doc2 == "d42")
        #expect(vol2 == "frus1969-76v01",
                "the separator between target and volume id must stay a literal '/'")
    }
}
