// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import UIKit
import WebKit
@testable import FRUSExplorer

// MARK: - FRUSOffsetEngineTests

/// Swift–JS flat-text equivalence tests for the offset engine.
///
/// Each test builds a `FRUSDocumentRenderModel`, obtains the Swift flat text via
/// `buildFlatText(from:)`, serializes the model to HTML, loads it into a real
/// `WKWebView` (with the `frus-offset-engine.js` user script injected), evaluates
/// `window.FRUSOffsets.flatText`, and asserts the two strings are identical.
///
/// If any test fails, the `data-skip` attributes emitted by
/// `FRUSRenderNodeHTMLSerializer` are inconsistent with the Swift traversal rules.
/// The fix is always in the serializer — never patch the JS to paper over a
/// mismatch.
///
/// These tests are `@MainActor` because `WKWebView` must be created and used on
/// the main thread.
@Suite("FRUSOffsetEngine — Swift/JS flat-text equivalence")
@MainActor
struct FRUSOffsetEngineTests {

    // MARK: - Convenience

    private func model(
        body: [FRUSRenderNode],
        footnotes: [FRUSRenderNode] = []
    ) -> FRUSDocumentRenderModel {
        FRUSDocumentRenderModel(documentId: "test", bodyNodes: body, footnotes: footnotes)
    }

    /// Loads `html` into a WKWebView, waits for completion, and returns
    /// `window.FRUSOffsets.flatText` evaluated via JavaScript.
    private func jsFlatText(
        for model: FRUSDocumentRenderModel
    ) async throws -> String {
        let html = HTMLTemplate.build(model: model, colorScheme: .light)
        let harness = OffsetEngineTestHarness()
        try await harness.load(html)
        return try await harness.evalFlatText()
    }

    // MARK: - Tests

    @Test("WKUserScript injection sets window.FRUSOffsets global")
    func userScriptInjectionSetsGlobal() async throws {
        let m = model(body: [.paragraph([.plainText("Hello.")])])
        let html = HTMLTemplate.build(model: m, colorScheme: .light)
        let harness = OffsetEngineTestHarness()
        try await harness.load(html)
        let injected = try await harness.userScriptInjected()
        // If this test fails, WKUserScript injection is broken — Sessions 144/145
        // depend on window.FRUSOffsets being set at document end.
        #expect(injected, "window.FRUSOffsets should be set by the injected WKUserScript")
    }

    @Test("Empty document produces empty flat text")
    func emptyDocument() async throws {
        let m = model(body: [])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift.isEmpty)
        #expect(swift == js)
    }

    @Test("Plain prose: heading + paragraphs")
    func plainProse() async throws {
        let m = model(body: [
            .heading([.plainText("Memorandum From Secretary Kissinger")]),
            .paragraph([.plainText("Washington, January 15, 1972.")]),
            .paragraph([.plainText("The meeting began at 10 a.m.")])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == js)
    }

    @Test("Inline formatting: bold, italic, underline, small-caps are transparent")
    func inlineFormatting() async throws {
        let m = model(body: [
            .paragraph([
                .plainText("See "),
                .boldText([.plainText("Document 42")]),
                .plainText(", "),
                .italicText([.plainText("supra")]),
                .plainText(", "),
                .underlineText([.plainText("p. 17")]),
                .plainText(" and "),
                .smallCapsText([.plainText("nsc")]),
                .plainText(".")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == js)
    }

    @Test("lineBreak contributes '\\n' to both")
    func lineBreak() async throws {
        let m = model(body: [
            .paragraph([
                .plainText("First line."),
                .lineBreak,
                .plainText("Second line.")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift.contains("\n"))
        #expect(swift == js)
    }

    @Test("pageBreak is offset-invisible (data-skip=1)")
    func pageBreak() async throws {
        let m = model(body: [
            .paragraph([.plainText("Before")]),
            .pageBreak(pageNumber: .arabic(17)),
            .paragraph([.plainText("After")])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // "Before" and "After" should be contiguous — no page number in flat text
        #expect(!swift.contains("17"))
        #expect(swift == js)
    }

    @Test("footnoteMarker is offset-invisible (data-skip=1)")
    func footnoteMarker() async throws {
        let m = model(body: [
            .paragraph([
                .plainText("Body text"),
                .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1"),
                .plainText(" continues.")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // The marker "1" should NOT appear in the flat text
        #expect(swift == "Body text continues.")
        #expect(swift == js)
    }

    @Test("figureBlock is offset-invisible (data-skip=1)")
    func figureBlock() async throws {
        let m = model(body: [
            .paragraph([.plainText("Before figure.")]),
            .figureBlock(FigureBlock(image: FigureImageName(volumeId: "frus1946v01", graphic: "figure_1162"),
                                     head: [.plainText("Map of South-East Asia")],
                                     captions: [[.plainText("Scale 1:1,000,000")]])),
            .paragraph([.plainText("After figure.")])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // A figure's head, placeholder and caption must NOT appear in flat text
        #expect(!swift.contains("Map") && !swift.contains("Scale") && !swift.contains("Figure"))
        #expect(swift == "Before figure.After figure.")
        #expect(swift == js)
    }

    @Test("footnoteBody in model.footnotes is offset-invisible (aside has data-skip=1)")
    func footnoteBodyIsInvisible() async throws {
        let footnote = FRUSRenderNode.footnoteBody(
            id: nil,
            type: .footnote,
            printedNumber: "1",
            sequentialNumber: 1,
            displayLabel: "1",
            children: [.paragraph([.plainText("Footnote content here.")])]
        )
        let m = model(
            body: [.paragraph([
                .plainText("Main text."),
                .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1")
            ])],
            footnotes: [footnote]
        )
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // Footnote content must NOT appear in flat text
        #expect(!swift.contains("Footnote content"))
        // Footnote marker ("1") must also not appear
        #expect(swift == "Main text.")
        #expect(swift == js)
    }

    @Test("persNameLink: children contribute, ref and PersonEntry do not")
    func persNameLink() async throws {
        let m = model(body: [
            .paragraph([
                .persNameLink(
                    ref: "#p_HK1",
                    children: [.plainText("Henry Kissinger")],
                    person: nil
                ),
                .plainText(" met with the President.")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == "Henry Kissinger met with the President.")
        #expect(swift == js)
    }

    @Test("glossLink: children contribute, ref does not")
    func glossLink() async throws {
        let m = model(body: [
            .paragraph([
                .plainText("The "),
                .glossLink(ref: "#t_NSC1", children: [.plainText("NSC")], entry: nil),
                .plainText(" meeting was brief.")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == "The NSC meeting was brief.")
        #expect(swift == js)
    }

    @Test("crossRefLink: children contribute, target URL does not")
    func crossRefLink() async throws {
        let m = model(body: [
            .paragraph([
                .plainText("See "),
                .crossRefLink(target: "d42", volumeId: "frus1969-76v02",
                              broken: nil, children: [.plainText("Document 42")]),
                .plainText(".")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == "See Document 42.")
        #expect(swift == js)
    }

    @Test("Broken crossRefLink: dagger marker is offset-invisible, children still contribute (#240B)")
    func brokenCrossRefLink() async throws {
        let info = BrokenRefInfo(target: "#pg_700", reason: "unknownPage",
                                 resolvedVolume: "frus1872p2v3", resolvedAnchor: "pg_700")
        let m = model(body: [
            .paragraph([
                .plainText("See "),
                .crossRefLink(target: "#pg_700", volumeId: nil,
                              broken: info, children: [.plainText("700")]),
                .plainText(".")
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // The serializer-injected dagger (†) must not enter the JS flat text — a counted
        // dagger would shift every downstream highlight offset in the document.
        #expect(swift == "See 700.")
        #expect(!js.contains("\u{2020}"))
        #expect(swift == js)
    }

    @Test("tableBlock: cell text contributes in row-major order")
    func tableBlock() async throws {
        let cells: [[TableCell]] = [
            [
                TableCell(rowSpan: 1, colSpan: 1, children: [.plainText("R1C1")]),
                TableCell(rowSpan: 1, colSpan: 2, children: [.plainText("R1C2-3")])
            ],
            [
                TableCell(rowSpan: 2, colSpan: 1, children: [.plainText("R2C1")]),
                TableCell(rowSpan: 1, colSpan: 1, children: [.plainText("R2C2")])
            ]
        ]
        let m = model(body: [.tableBlock(caption: nil, rows: cells)])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift.contains("R1C1"))
        #expect(swift.contains("R2C2"))
        #expect(swift == js)
    }

    @Test("listBlock: item text contributes")
    func listBlock() async throws {
        let m = model(body: [
            .listBlock(type: "ordered", heading: nil, items: [
                ListItemEntry(children: [.plainText("First item")]),
                ListItemEntry(children: [.plainText("Second item")]),
                ListItemEntry(children: [.boldText([.plainText("Third")]), .plainText(" item")])
            ], trailing: [])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift.contains("First item"))
        #expect(swift.contains("Third item"))
        #expect(swift == js)
    }

    @Test("attachmentBlock: nested content contributes")
    func attachmentBlock() async throws {
        let m = model(body: [
            .paragraph([.plainText("Main document.")]),
            .attachmentBlock(n: "A", children: [
                .attachmentHeading([.plainText("Attachment A")]),
                .paragraph([.plainText("Attachment content.")])
            ])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift.contains("Attachment A"))
        #expect(swift.contains("Attachment content."))
        #expect(swift == js)
    }

    @Test("Mixed: all skip-invisible nodes in one document")
    func allSkipInvisibleTogether() async throws {
        let footnoteBody = FRUSRenderNode.footnoteBody(
            id: nil, type: .source, printedNumber: nil,
            sequentialNumber: 1, displayLabel: "Source",
            children: [.paragraph([.plainText("NARA RG 59.")])]
        )
        let m = model(
            body: [
                .heading([.plainText("Title")]),
                .pageBreak(pageNumber: .roman(5)),         // invisible
                .paragraph([
                    .plainText("Text "),
                    .footnoteMarker(id: nil, type: .footnote, sequentialNumber: 1, displayLabel: "1"), // invisible
                    .plainText("here.")
                ]),
                .figureBlock(FigureBlock(head: [.plainText("Invisible figure")]))   // invisible
            ],
            footnotes: [footnoteBody]                        // invisible
        )
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == "TitleText here.")
        #expect(swift == js)
    }

    @Test("HTML special characters are identical in both representations")
    func htmlSpecialCharacters() async throws {
        let m = model(body: [
            .paragraph([.plainText("Costs < $10 & profits > $5; label: \"value\".")])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // Swift flat text has the raw characters; JS text node values are
        // decoded (WebKit un-escapes &lt; → <, etc.)
        #expect(swift.contains("<"))
        #expect(swift.contains("&"))
        #expect(swift == js)
    }

    @Test("Long document: hundreds of paragraphs maintain offset alignment")
    func longDocument() async throws {
        let paragraphs: [FRUSRenderNode] = (1...200).map { i in
            .paragraph([.plainText("Paragraph \(i): The meeting resumed at noon.")])
        }
        let m = model(body: paragraphs)
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        #expect(swift == js)
        #expect(swift.contains("Paragraph 200"))
    }

    // MARK: List heads, labels and other list children (#1371)

    /// What the page's own DOM carries for a list fixture, read after load.
    private struct ListDOMReport: Decodable {
        /// `textContent` of `.frus-document` — everything drawn, including `data-skip` text.
        let documentText: String
        /// `textContent` of each element the reader draws but the offset engine skips.
        let skippedTexts: [String]
    }

    /// Loads `fixture` through the reader's real pipeline and returns the Swift flat text, the
    /// offset engine's flat text, and what the DOM draws.
    private func listParity(
        _ fixture: String
    ) async throws -> (swift: String, js: String, dom: ListDOMReport) {
        let m = try await ListShapeFixtures.renderModel(fixture)
        let html = HTMLTemplate.build(model: m, colorScheme: .light)
        let harness = OffsetEngineTestHarness()
        try await harness.load(html)
        let js = try await harness.evalFlatText()
        let raw = try #require(try await harness.evaluateString("""
        (() => {
          const root = document.querySelector('.frus-document');
          const skipped = Array.from(root.querySelectorAll('[data-skip="1"]'))
            .filter(e => !e.parentElement.closest('[data-skip="1"]'))
            .map(e => e.textContent);
          return JSON.stringify({ documentText: root.textContent, skippedTexts: skipped });
        })()
        """), "the DOM report script must return a string")
        let dom = try JSONDecoder().decode(ListDOMReport.self, from: Data(raw.utf8))
        return (buildFlatText(from: m), js, dom)
    }

    /// `renderingVersion` hashes only the converter's flat text, so it cannot see a list label
    /// that reaches the DOM OUTSIDE its `data-skip` span: the hash stays put while the offset
    /// engine counts "(1)" and every highlight after it lands three characters early. Only this
    /// parity catches that, so it runs on the real d84 markup and on a list holding every child.
    @Test("d84's list heads and labels are drawn, and Swift and JS still agree on the flat text (#1371)")
    func d84ListHeadsAndLabelsParity() async throws {
        let (swift, js, dom) = try await listParity(ListShapeFixtures.d84)
        for printed in ["SUBJECT", "PARTICIPANTS:", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)"] {
            #expect(dom.documentText.contains(printed), "the page does not draw \(printed)")
            #expect(dom.skippedTexts.contains { $0.contains(printed) },
                    "\(printed) is drawn outside every data-skip element")
            #expect(!swift.contains(printed), "\(printed) entered the Swift flat text")
        }
        #expect(swift.contains("In discussing agricultural problems"))
        #expect(swift == js, "Swift/JS flat text diverged on d84's lists")
    }

    @Test("A list holding every direct child the corpus uses keeps Swift and JS flat text equal (#1371)")
    func everyListChildParity() async throws {
        let (swift, js, dom) = try await listParity(ListShapeFixtures.everyChild)
        for drawn in ["Recommendations:", "By desire and on behalf of the meeting:", "a.", "b.",
                      "Henry A. Kissinger"] {
            #expect(dom.documentText.contains(drawn), "the page does not draw \(drawn)")
            #expect(dom.skippedTexts.contains { $0.contains(drawn) },
                    "\(drawn) is drawn outside every data-skip element")
        }
        #expect(swift == "Opening paragraph.First item text.Second item text.Third item text.Closing paragraph.")
        #expect(swift == js, "Swift/JS flat text diverged on a list with every child")
    }

    // MARK: Table captions (#1495)

    /// `renderingVersion` hashes only the converter's flat text, so it cannot see a caption that
    /// reaches the DOM outside its `data-skip` element: the hash stays put while the offset engine
    /// counts "Millions of Dollars" and every highlight after the table is misplaced by 19 characters.
    /// Only this parity catches that. d71's caption holds a footnote marker and ve07 d85's two
    /// line breaks, each a way for the caption to leak a character.
    @Test("Real table captions are drawn, offset-invisible, and Swift and JS still agree on the flat text (#1495)")
    func tableCaptionParity() async throws {
        let cases = [
            (TableCaptionFixtures.d355, "Millions of Dollars", "Year Ending March 20, 1950"),
            (TableCaptionFixtures.d71, "Table 1 Weapons Allocation Priorities", "Day-to-day alert"),
            (TableCaptionFixtures.ve07d85, "(billion US dollars)", "Authorized"),
        ]
        for (fixture, caption, cell) in cases {
            let (swift, js, dom) = try await listParity(fixture)
            #expect(dom.documentText.contains(caption), "the page does not draw \(caption)")
            #expect(dom.skippedTexts.contains { $0.contains(caption) },
                    "\(caption) is drawn outside every data-skip element")
            #expect(!swift.contains(caption), "\(caption) entered the Swift flat text")
            #expect(swift.contains(cell), "the cells must still be flat text")
            #expect(swift == js, "Swift/JS flat text diverged on the table captioned \(caption)")
        }
    }
}

// MARK: - TableCaptionLayoutTests (#1495)

/// Measures, through the reader's own stylesheet, that a table's caption prints the way
/// history.state.gov prints a table's head: above the table, in italics, from the table's left
/// edge. The `<caption>` element's own default is centred.
@Suite("A table's caption prints above the table, in italics, from its left edge (#1495)")
@MainActor
struct TableCaptionLayoutTests {

    /// What the page drew for the caption.
    private struct CaptionReport: Decodable {
        /// Computed `font-style` of the caption.
        let fontStyle: String
        /// The caption's bottom edge and the table's first row's top edge.
        let captionBottom: Double, firstRowTop: Double
        /// The left edge of the caption's first character, and of the table.
        let textLeft: Double, tableLeft: Double
    }

    @Test("d355's caption sits above its first row, italic, starting at the table's left edge")
    func captionSitsAboveTheTable() async throws {
        let model = try await ListShapeFixtures.renderModel(TableCaptionFixtures.d355)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        let raw = try #require(try await harness.evaluateString("""
        (() => {
          const caption = document.querySelector('.frus-document table.frus-table > caption');
          if (!caption) return null;
          const table = caption.closest('table');
          const row = table.querySelector('tr');
          const text = document.createTreeWalker(caption, NodeFilter.SHOW_TEXT).nextNode();
          const r = document.createRange(); r.setStart(text, 0); r.setEnd(text, 1);
          return JSON.stringify({
            fontStyle: getComputedStyle(caption).fontStyle,
            captionBottom: caption.getBoundingClientRect().bottom,
            firstRowTop: row.getBoundingClientRect().top,
            textLeft: r.getBoundingClientRect().left,
            tableLeft: table.getBoundingClientRect().left
          });
        })()
        """), "d355's table has no caption on the page")
        let report = try JSONDecoder().decode(CaptionReport.self, from: Data(raw.utf8))
        #expect(report.fontStyle == "italic", "the caption must print in italics: \(report.fontStyle)")
        #expect(report.captionBottom <= report.firstRowTop + 0.5,
                "the caption must sit above the first row (caption bottom \(report.captionBottom), row top \(report.firstRowTop))")
        #expect(abs(report.textLeft - report.tableLeft) < 1,
                "the caption must start at the table's left edge, not centred (text \(report.textLeft), table \(report.tableLeft))")
    }
}

// MARK: - ListLabelSelectionTests (#1371)

/// A selection whose start or end falls inside an offset-invisible (`data-skip`) node maps to −1
/// in `kSelectionJS`, so the reader treats it as a footnote selection: the Mac's selection bar
/// disables Highlight and Excerpt, and the iPhone and iPad edit menu leaves them out (#1540).
/// A drag from the left edge of a numbered item commonly starts on its
/// printed label, so restoring the labels under `data-skip` (#1371) would have made numbered
/// paragraphs harder to highlight than they were while the labels were missing.
///
/// These tests hit-test the reader's page with `document.caretRangeFromPoint` — the same
/// point → `VisiblePosition` path a macOS mouse-down and an iOS selection gesture take, which a
/// unit-test web view cannot synthesise natively — make the selection a drag between those two
/// points would make, and read the payload the production bridge posts to the coordinator.
@Suite("List labels and heads do not block a highlightable selection (#1371)")
@MainActor
struct ListLabelSelectionTests {

    /// What the drag script found, so a failure names what it hit.
    private struct DragReport: Decodable {
        /// Why the script could not run the drag, when it could not.
        let error: String?
        /// Where the start caret landed: its container, the element holding it, and the offset.
        let startCaret: String?
        /// Where the end caret landed, described the same way.
        let endCaret: String?
    }

    /// Loads d84 and returns the harness plus the Swift flat text its offsets index.
    private func loadedD84() async throws -> (OffsetEngineTestHarness, String) {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.d84)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        return (harness, buildFlatText(from: model))
    }

    /// The UTF-16 offset of `needle` in `flat`.
    private func offset(of needle: String, in flat: String) throws -> Int {
        let range = try #require(flat.range(of: needle), "\"\(needle)\" is not in the flat text")
        return flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
    }

    /// A script that drags from one point to another and reports what it hit.
    ///
    /// `from` and `to` are JS expressions, evaluated in the page, that each yield
    /// `{ el, x, y }` — a point in viewport coordinates and the drawn element it aims at (or
    /// `null`). The target is scrolled to the middle of the viewport first, because
    /// `caretRangeFromPoint` only hit-tests what is on screen.
    private func dragScript(scrollTo: String, from: String, to: String) -> String {
        """
        (() => {
          const scrollTarget = \(scrollTo);
          if (!scrollTarget) return JSON.stringify({ error: 'the element to drag over is not on the page' });
          scrollTarget.scrollIntoView({ block: 'center' });
          const centre = (el) => { const r = el.getBoundingClientRect(); return { el, x: r.left + r.width / 2, y: r.top + r.height / 2 }; };
          const inText = (li, skipEl, n) => {
            const walker = document.createTreeWalker(li, NodeFilter.SHOW_TEXT,
              { acceptNode: t => (skipEl && skipEl.contains(t)) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT });
            let t = walker.nextNode();
            while (t && t.nodeValue.trim().length <= n) t = walker.nextNode();
            if (!t) return null;
            const r = document.createRange(); r.setStart(t, n); r.setEnd(t, n + 1);
            const b = r.getBoundingClientRect();
            return { el: null, x: b.left + 0.5, y: b.top + b.height / 2 };
          };
          const from = \(from);
          const to = \(to);
          if (!from || !to) return JSON.stringify({ error: 'a drag endpoint could not be placed' });
          const a = document.caretRangeFromPoint(from.x, from.y);
          const b = document.caretRangeFromPoint(to.x, to.y);
          if (!a || !b) return JSON.stringify({ error: 'caretRangeFromPoint returned no caret' });
          const describe = (c) => {
            const n = c.startContainer;
            const el = n.nodeType === Node.ELEMENT_NODE ? n : n.parentElement;
            const what = n.nodeType === Node.TEXT_NODE ? '#text "' + n.nodeValue.slice(0, 16) + '"' : n.nodeName;
            return what + ' in ' + el.tagName.toLowerCase() + (el.className ? '.' + el.className : '') + ' @' + c.startOffset;
          };
          getSelection().removeAllRanges();
          getSelection().setBaseAndExtent(a.startContainer, a.startOffset, b.startContainer, b.startOffset);
          return JSON.stringify({ error: null, startCaret: describe(a), endCaret: describe(b) });
        })()
        """
    }

    /// The label element reading `text`, as a JS expression.
    private func label(_ text: String) -> String {
        "Array.from(document.querySelectorAll('.list-label')).find(e => e.textContent.trim() === '\(text)')"
    }

    /// Runs `script` and returns the report and the payload the bridge posted.
    private func drag(
        _ harness: OffsetEngineTestHarness, _ script: String
    ) async throws -> (DragReport, SelectionPayload?) {
        var report: DragReport?
        let payload = try await harness.selectionPayload {
            let raw = try await harness.evaluateString(script)
            report = try JSONDecoder().decode(DragReport.self, from: Data((raw ?? "{\"error\":\"no result\"}").utf8))
        }
        return (try #require(report), payload)
    }

    @Test("A drag that starts on a printed label selects from the item's first word, highlightably")
    func dragStartingOnALabel() async throws {
        let (harness, flat) = try await loadedD84()
        let script = dragScript(
            scrollTo: label("(2)"),
            from: "centre(\(label("(2)")))",
            to: "inText(\(label("(2)")).closest('li'), \(label("(2)")), 20)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag starting on (2) must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        let itemStart = try offset(of: "In discussing agricultural", in: flat)
        #expect(selection.start == itemStart, "the selection should begin at the item's first word")
        #expect(selection.end == itemStart + 20)
    }

    /// "(1)" is the list's first label, and it opens the list inside d84's `<p>`: the snap must
    /// find the item after it, not the paragraph text before it.
    @Test("A drag that starts on the first label, (1), selects from its item's first word, highlightably")
    func dragStartingOnTheFirstLabel() async throws {
        let (harness, flat) = try await loadedD84()
        let script = dragScript(
            scrollTo: label("(1)"),
            from: "centre(\(label("(1)")))",
            to: "inText(\(label("(1)")).closest('li'), \(label("(1)")), 20)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag starting on (1) must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        let itemStart = try offset(of: "During the discussion", in: flat)
        #expect(selection.start == itemStart, "the selection should begin at item (1)'s first word")
        #expect(selection.end == itemStart + 20)
    }

    @Test("A drag that ends on a printed label keeps its offsets, ending where that item begins")
    func dragEndingOnALabel() async throws {
        let (harness, flat) = try await loadedD84()
        let script = dragScript(
            scrollTo: label("(3)"),
            from: "inText(\(label("(2)")).closest('li'), \(label("(2)")), 5)",
            to: "centre(\(label("(3)")))")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag ending on (3) must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        #expect(selection.start == (try offset(of: "In discussing agricultural", in: flat)) + 5)
        #expect(selection.end == (try offset(of: "With reference to Gagarin", in: flat)))
    }

    /// A selection that spans labels — both ends inside items — was always mappable; this pins
    /// that the labels between its ends do not disturb its offsets, and that the text WebKit
    /// hands the bridge — what Look Up and Copy receive — keeps the labels it crosses. That text
    /// is the cost `user-select: none` on the list parts would have had: measured, it drops them.
    @Test("A selection across several labelled items keeps its offsets, and its text keeps the labels")
    func aSelectionAcrossLabelsKeepsItsOffsets() async throws {
        let (harness, flat) = try await loadedD84()
        let script = dragScript(
            scrollTo: label("(2)"),
            from: "inText(\(label("(1)")).closest('li'), \(label("(1)")), 4)",
            to: "inText(\(label("(3)")).closest('li'), \(label("(3)")), 4)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets, "start \(selection.start), end \(selection.end)")
        #expect(selection.start == (try offset(of: "During the discussion", in: flat)) + 4)
        #expect(selection.end == (try offset(of: "With reference to Gagarin", in: flat)) + 4)
        #expect(selection.text.contains("In discussing agricultural problems"))
        #expect(selection.text.contains("(2)") && selection.text.contains("(3)"),
                "the selection's own text lost a label it crosses: \(selection.text.debugDescription)")
    }

    @Test("A drag that starts on a list heading selects from the list's first item, highlightably")
    func dragStartingOnAHeading() async throws {
        let (harness, flat) = try await loadedD84()
        let heading = "Array.from(document.querySelectorAll('.list-heading')).find(e => e.textContent.trim() === 'SUBJECT')"
        let script = dragScript(
            scrollTo: heading,
            from: "centre(\(heading))",
            to: "inText(\(heading).nextElementSibling.querySelector('li'), null, 12)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag starting on SUBJECT must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        let itemStart = try offset(of: "Vienna Meeting Between", in: flat)
        #expect(selection.start == itemStart)
        #expect(selection.end == itemStart + 12)
    }

    // MARK: The move is scoped to list parts in the document body

    /// A body footnote, a labelled list inside that footnote, and a list whose closer is the last
    /// thing in the document — the three places a list part's endpoint must NOT move, or has
    /// nothing mapped after it to move to.
    private static let scopeFixture = """
    <div type="document" xml:id="d1">
      <p>Body text with a note.<note n="1" xml:id="d1fn1"><p>The enclosures were:</p><list><label>(a)</label><item>A memorandum of conversation.</item><label>(b)</label><item>A draft reply.</item></list></note> More body text.</p>
      <list><label>1.</label><item>The last item.</item><closer><signed>Henry A. Kissinger</signed></closer></list>
    </div>
    """

    /// Selects from `startOffset` in the first text node under the element `start` names to
    /// `endOffset` in the first text node under `end` — the endpoints themselves, no hit-testing,
    /// because a popover and the Footnotes list are not on screen to hit-test.
    /// `prepare` runs first — it opens the footnote popover, which is not rendered until shown.
    private func selectScript(prepare: String = "", start: String, startOffset: Int,
                              end: String, endOffset: Int) -> String {
        """
        (() => {
          \(prepare);
          const firstText = (el) => el && document.createTreeWalker(el, NodeFilter.SHOW_TEXT).nextNode();
          const a = firstText(\(start));
          const b = firstText(\(end));
          if (!a || !b) return JSON.stringify({ error: 'an endpoint element is not on the page' });
          getSelection().removeAllRanges();
          getSelection().setBaseAndExtent(a, \(startOffset), b, \(endOffset));
          return JSON.stringify({ error: null, startCaret: a.nodeValue, endCaret: b.nodeValue });
        })()
        """
    }

    /// Loads the scope fixture and returns the harness plus its Swift flat text.
    private func loadedScopeFixture() async throws -> (OffsetEngineTestHarness, String) {
        let model = try await ListShapeFixtures.renderModel(Self.scopeFixture)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        return (harness, buildFlatText(from: model))
    }

    @Test("A selection starting on a footnote marker is still a footnote selection")
    func aFootnoteMarkerStillMapsToNothing() async throws {
        let (harness, _) = try await loadedScopeFixture()
        let (report, payload) = try await drag(harness, selectScript(
            start: Self.bodyParagraph, startOffset: 5,
            end: "document.querySelector('.frus-document button.fn-marker')", endOffset: 0))
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(!selection.hasOffsets, "a marker endpoint must stay unmapped: start \(selection.start), end \(selection.end)")
    }

    /// The body paragraph the next two tests start in: its first text node is mapped.
    private static let bodyParagraph =
        "Array.from(document.querySelectorAll('.frus-document p.body')).find(p => p.textContent.includes('Body text'))"

    /// Nothing mapped follows a popover, so a label inside one would move to the end of the flat
    /// text and turn a drag from the body into the popover into a highlight of the rest of the
    /// document. It must stay unmapped, as it was.
    @Test("A selection ending on a label inside a footnote popover is still a footnote selection")
    func aLabelInAFootnotePopoverStillMapsToNothing() async throws {
        let (harness, _) = try await loadedScopeFixture()
        let (report, payload) = try await drag(harness, selectScript(
            prepare: "document.querySelector('aside.footnote').showPopover()",
            start: Self.bodyParagraph, startOffset: 5,
            end: "document.querySelector('aside.footnote .list-label')", endOffset: 1))
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(!selection.hasOffsets, "a popover label must stay unmapped: start \(selection.start), end \(selection.end)")
    }

    @Test("A selection ending on a label in the Footnotes list is still a footnote selection")
    func aLabelInTheFootnotesListStillMapsToNothing() async throws {
        let (harness, _) = try await loadedScopeFixture()
        let (report, payload) = try await drag(harness, selectScript(
            start: Self.bodyParagraph, startOffset: 5,
            end: "document.querySelector('.footnotes-section .list-label')", endOffset: 1))
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(!selection.hasOffsets, "a Footnotes-list label must stay unmapped: start \(selection.start), end \(selection.end)")
    }

    @Test("A drag that ends on a closer after the document's last item ends at the end of the flat text")
    func aDragEndingOnTheLastCloserEndsAtTheEnd() async throws {
        let (harness, flat) = try await loadedScopeFixture()
        let (report, payload) = try await drag(harness, selectScript(
            start: "Array.from(document.querySelectorAll('.frus-document li')).find(li => li.textContent.includes('The last item'))",
            startOffset: 0,
            end: "document.querySelector('.frus-document .list-trailing')", endOffset: 5))
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets, "start \(selection.start), end \(selection.end) for \"\(selection.text)\"")
        #expect(selection.start == (try offset(of: "The last item.", in: flat)))
        #expect(selection.end == flat.utf16.count, "nothing mapped follows the closer, so the end is the flat text's end")
    }

    // MARK: The list's other children, and a footnote marker inside a list part

    /// Loads `everyChild` — a salute, a line break, a loose note, page breaks and a figure among
    /// the items — and returns the harness plus its Swift flat text.
    private func loadedEveryChild() async throws -> (OffsetEngineTestHarness, String) {
        let model = try await ListShapeFixtures.renderModel(ListShapeFixtures.everyChild)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        return (harness, buildFlatText(from: model))
    }

    /// A list child that is neither its head nor a label — a salute before the first item, a loose
    /// note, a line break, a figure, a page break — is drawn in a `.list-aside` inside the item it
    /// precedes, where no heading or label encloses it; only the aside's own rule moves it.
    @Test("A drag that starts on a salute inside a list selects from the first item's first word, highlightably")
    func dragStartingOnAListAside() async throws {
        let (harness, flat) = try await loadedEveryChild()
        let aside = "Array.from(document.querySelectorAll('.frus-document .list-aside')).find(e => e.textContent.includes('By desire'))"
        let script = dragScript(
            scrollTo: aside,
            from: "centre(\(aside).querySelector('.salutation'))",
            to: "inText(\(aside).closest('li'), \(aside), 5)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag starting on the salute must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        let itemStart = try offset(of: "First item text.", in: flat)
        #expect(selection.start == itemStart, "the selection should begin at the first item's first word")
        #expect(selection.end == itemStart + 5)
    }

    /// A footnote marker drawn inside a list part — a note in a label, as 87 labels in 51
    /// documents carry, or in a head — is part of that part, so an endpoint on it moves with the
    /// part to the item's first letter rather than mapping to −1. (Only a marker outside every
    /// list part stays unmapped: `aFootnoteMarkerStillMapsToNothing`.)
    @Test("A selection starting on a footnote marker inside a label moves to that label's item, highlightably")
    func aFootnoteMarkerInsideALabelMovesWithIt() async throws {
        let (harness, flat) = try await loadedEveryChild()
        let (report, payload) = try await drag(harness, selectScript(
            start: "document.querySelector('.frus-document .list-label button.fn-marker')", startOffset: 0,
            end: "Array.from(document.querySelectorAll('.frus-document p.body')).find(p => p.textContent.includes('Closing paragraph'))",
            endOffset: 7))
        #expect(report.error == nil, "\(report.error ?? "")")
        #expect(report.startCaret == "2", "the start must sit in the label's footnote marker, not \(report.startCaret ?? "nothing")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets, "start \(selection.start), end \(selection.end) for \"\(selection.text)\"")
        #expect(selection.start == (try offset(of: "First item text.", in: flat)))
        #expect(selection.end == (try offset(of: "Closing paragraph.", in: flat)) + 7)
    }

    // MARK: A table's caption (#1495)

    /// Loads `fixture` and returns the harness plus its Swift flat text.
    private func loaded(_ fixture: String) async throws -> (OffsetEngineTestHarness, String) {
        let model = try await ListShapeFixtures.renderModel(fixture)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        return (harness, buildFlatText(from: model))
    }

    /// A table's caption is drawn under `data-skip` like a list's heading, so a drag that starts
    /// on "Millions of Dollars" — the natural place to start selecting a table — would otherwise
    /// map to −1 and lose Highlight and Excerpt. d355's first cell is empty, so the selection
    /// begins at the first cell that holds text.
    @Test("A drag that starts on a table's caption selects from its first cell's first word, highlightably")
    func dragStartingOnACaption() async throws {
        let (harness, flat) = try await loaded(TableCaptionFixtures.d355)
        let caption = "document.querySelector('.frus-document caption.table-caption')"
        let cell = "Array.from(document.querySelectorAll('.frus-document td')).find(td => td.textContent.includes('Year Ending March 20, 1950'))"
        let script = dragScript(
            scrollTo: caption,
            from: "centre(\(caption))",
            to: "inText(\(cell), null, 10)")
        let (report, payload) = try await drag(harness, script)
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "a drag starting on the caption must stay highlightable; the bridge posted start \(selection.start), end \(selection.end) for \"\(selection.text)\"; carets \(report.startCaret ?? "?") → \(report.endCaret ?? "?")")
        let cellStart = try offset(of: "Year Ending March 20, 1950", in: flat)
        #expect(selection.start == cellStart, "the selection should begin at the first cell's first word")
        #expect(selection.end == cellStart + 10)
    }

    /// v41 d86's captioned table sits in a footnote. Nothing mapped follows a popover, so a caption
    /// there that moved like a body caption would turn a drag from the body into the popover into
    /// a highlight of the rest of the document. It must stay unmapped, as a label there does.
    @Test("A selection ending on a table caption inside a footnote popover is still a footnote selection")
    func aCaptionInAFootnotePopoverStillMapsToNothing() async throws {
        let (harness, _) = try await loaded(TableCaptionFixtures.v41d86)
        let (report, payload) = try await drag(harness, selectScript(
            prepare: "document.querySelector('aside.footnote').showPopover()",
            start: "document.querySelector('.frus-document p.body')", startOffset: 5,
            end: "document.querySelector('aside.footnote caption.table-caption')", endOffset: 3))
        #expect(report.error == nil, "\(report.error ?? "")")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(!selection.hasOffsets, "a popover caption must stay unmapped: start \(selection.start), end \(selection.end)")
    }
}

// MARK: - ListLabelLayoutTests (#1371)

/// Measures, through the reader's own stylesheet, that a printed label sits where the bullet
/// went: a labelled list draws no bullet, and each label hangs left of its item's first line —
/// including an item that opens with a `<p>`, which 11,343 labelled items in the corpus do and
/// which an inline label would push onto a line of its own.
@Suite("A printed list label hangs where the bullet went (#1371)")
@MainActor
struct ListLabelLayoutTests {

    /// One label and the box of its item's first line of text.
    private struct LabelBox: Decodable {
        /// The label's text, so a failure names it.
        let label: String
        /// The label's border box, left and right edges and vertical middle.
        let left: Double, right: Double, middle: Double
        /// The item's first character: its left edge, top and bottom.
        let textLeft: Double, textTop: Double, textBottom: Double
    }

    /// What the page drew for the labelled list.
    private struct LayoutReport: Decodable {
        /// Computed `list-style-type` of each labelled list.
        let listStyles: [String]
        /// Each label and its item's first line.
        let labels: [LabelBox]
    }

    @Test("A labelled list draws no bullet, and each label hangs beside its item's first line")
    func labelsHangBesideTheirItems() async throws {
        let model = try await ListShapeFixtures.renderModel("""
        <div type="document" xml:id="d1">
          <p>The points were these: <list>
            <label>(1)</label>
            <item>An item that runs inline, long enough to wrap onto a second line of the reading column so the hang can be seen.</item>
            <label>(2)</label>
            <item><p>An item that opens with its own paragraph, the shape 11,343 labelled items take.</p></item>
            <label>Article 12.</label>
            <item>An item whose label is wider than the space a bullet takes.</item>
          </list></p>
        </div>
        """)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        let raw = try #require(try await harness.evaluateString("""
        (() => {
          const lists = Array.from(document.querySelectorAll('.frus-document ul.labelled, .frus-document ol.labelled'));
          const labels = Array.from(document.querySelectorAll('.frus-document li > .list-label')).map(label => {
            const box = label.getBoundingClientRect();
            const li = label.closest('li');
            const walker = document.createTreeWalker(li, NodeFilter.SHOW_TEXT,
              { acceptNode: t => (label.contains(t) || !t.nodeValue.trim()) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT });
            const text = walker.nextNode();
            const r = document.createRange(); r.setStart(text, 0); r.setEnd(text, 1);
            const t = r.getBoundingClientRect();
            return { label: label.textContent, left: box.left, right: box.right, middle: (box.top + box.bottom) / 2,
                     textLeft: t.left, textTop: t.top, textBottom: t.bottom };
          });
          return JSON.stringify({ listStyles: lists.map(l => getComputedStyle(l).listStyleType), labels });
        })()
        """), "the layout script must return a string")
        let report = try JSONDecoder().decode(LayoutReport.self, from: Data(raw.utf8))

        #expect(report.listStyles == ["none"], "the labelled list must draw no bullet: \(report.listStyles)")
        try #require(report.labels.map(\.label) == ["(1)", "(2)", "Article 12."],
                     "measured the wrong labels: \(report.labels.map(\.label))")
        for box in report.labels {
            #expect(box.right <= box.textLeft + 0.5,
                    "\(box.label) overlaps its item's text (label right \(box.right), text left \(box.textLeft))")
            #expect(box.middle >= box.textTop && box.middle <= box.textBottom,
                    "\(box.label) is not on its item's first line (label middle \(box.middle), line \(box.textTop)–\(box.textBottom))")
        }
        // The two short labels hang in the same column, so their items start flush.
        #expect(abs(report.labels[0].textLeft - report.labels[1].textLeft) < 0.5,
                "items (1) and (2) must start at the same x: \(report.labels[0].textLeft) vs \(report.labels[1].textLeft)")
    }
}

// MARK: - Test harness

/// Async `WKWebView` wrapper for loading HTML and evaluating JavaScript in tests.
///
/// Creates a WKWebView with the full production configuration (URL scheme handler
/// + offset-engine user script) so the injection path is identical to production.
///
/// Internal rather than private since #1386: `FootnoteListIndentRenderTests` loads the
/// reader's real stylesheet through it and measures computed style and layout, which no
/// string assertion on the serializer's markup can see.
@MainActor
final class OffsetEngineTestHarness: NSObject, WKNavigationDelegate {

    /// The iPhone and iPad reader's own web view (#1540), wired to ``coordinator`` as
    /// `_FRUSDocumentWebViewiOS.makeUIView` wires it, so a test can build the edit menu's group
    /// from what the page reported and see what choosing an item does to the page.
    let webView: _FRUSEditMenuWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?

    /// The production message handler the page's scripts post to. Kept (#1371) so a test can
    /// read the `selectionChanged` payload the real bridge sends — see
    /// ``selectionPayload(timeout:after:)``. Nothing else in the harness reads it.
    let coordinator: _FRUSWebViewCoordinator

    /// Builds an 800×600 web view on the production configuration, delegating to `self`, whose
    /// scheme handler serves no figure image and fetches none: an empty store of its own, never
    /// the app's (#1516), so no test reaches the device's figures or the network through it.
    override convenience init() {
        self.init(figureImages: FigureImageStore())
    }

    /// Builds the web view with a scheme handler that serves figure images from `figureImages`.
    init(figureImages: FigureImageStore) {
        // A coordinator with no callbacks set satisfies the messageHandler requirement; a test
        // that wants the selection payload sets `onSelectionChanged` through
        // `selectionPayload(timeout:after:)`.
        let stubCoordinator = _FRUSWebViewCoordinator()
        coordinator = stubCoordinator
        let handler = FRUSURLSchemeHandler()
        handler.figureImages = figureImages
        let config = WKWebViewConfiguration.frusExplorerConfiguration(
            schemeHandler:  handler,
            messageHandler: stubCoordinator
        )
        // Give the web view a concrete frame so WebKit allocates a proper
        // rendering surface for script execution.
        webView = _FRUSEditMenuWebView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            configuration: config
        )
        super.init()
        webView.selectionReports = stubCoordinator
        webView.navigationDelegate = self
    }

    /// Loads an HTML string and waits until `webView(_:didFinish:)` fires.
    func load(_ html: String) async throws {
        try await withCheckedThrowingContinuation { cont in
            loadContinuation = cont
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// Runs the offset engine JS inline and returns the flat text.
    ///
    /// We execute the DFS inline rather than reading `window.FRUSOffsets.flatText`
    /// (set by the injected WKUserScript) because `WKUserScript` injection timing
    /// can be unreliable in unit-test environments where the WebKit process runs
    /// without a foreground window. The inline execution is semantically identical
    /// — same traversal logic, same DOM state — and produces the correct result for
    /// the equivalence assertion. A separate test (`userScriptInjectionSetsGlobal`)
    /// specifically verifies that the injected script sets `window.FRUSOffsets`.
    func evalFlatText() async throws -> String {
        // Mirror of frus-offset-engine.js, executed after didFinish guarantees
        // the DOM is ready. Uses chars.join('') instead of string concatenation
        // to avoid O(n²) string growth for large documents.
        let js = """
        (() => {
          const root = document.querySelector('.frus-document');
          if (!root) return '';
          const chars = [];
          function walk(n) {
            if (n.nodeType === 3) { chars.push(n.nodeValue); return; }
            if (n.nodeType !== 1) return;
            if (n.dataset && n.dataset.skip === '1') return;
            if (n.tagName === 'BR') { chars.push('\\n'); return; }
            for (const c of n.childNodes) walk(c);
          }
          walk(root);
          return chars.join('');
        })()
        """
        let result = try await webView.evaluateJavaScript(js)
        return (result as? String) ?? ""
    }

    /// Evaluates `script` in the loaded page and returns its result as a string.
    ///
    /// The script must evaluate to a string — typically `JSON.stringify(...)` of whatever
    /// the caller measured — because the async `evaluateJavaScript` bridge cannot carry
    /// `undefined` or a DOM object back to Swift. A non-string result returns `nil`, so a
    /// caller that `#require`s it fails naming the script rather than decoding an empty
    /// string.
    func evaluateString(_ script: String) async throws -> String? {
        let result = try await webView.evaluateJavaScript(script)
        return result as? String
    }

    /// Runs `action` — which must change the page's selection — and returns the first
    /// `selectionChanged` payload the production bridge posts afterwards, or `nil` when none
    /// arrives within `timeout`.
    ///
    /// This is the path the reader takes end to end: WebKit fires `selectionchange`,
    /// `kSelectionJS` maps the range through `window.FRUSOffsets`, posts `selectionChanged`, and
    /// the coordinator decodes it with `decodeFRUSSelectionEvent` — the same payload whose
    /// `hasOffsets` decides whether `DocumentView` enables Highlight and Excerpt. A cleared
    /// selection is not a payload and is skipped.
    func selectionPayload(
        timeout: Duration = .seconds(5),
        after action: () async throws -> Void
    ) async throws -> SelectionPayload? {
        let (events, continuation) = AsyncStream.makeStream(of: SelectionPayload.self)
        coordinator.onSelectionChanged = { continuation.yield($0) }
        defer { coordinator.onSelectionChanged = nil }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            continuation.finish()
        }
        defer { timer.cancel() }
        try await action()
        for await payload in events {
            return payload
        }
        return nil
    }

    /// Runs `action` and returns whether the production bridge reports the page's selection cleared
    /// within `timeout`: the `{ start: -1, end: -1 }` message `postCleared` sends, which the
    /// coordinator turns into `onSelectionCleared` (#1540).
    func selectionCleared(
        timeout: Duration = .seconds(5),
        after action: () async throws -> Void
    ) async throws -> Bool {
        let (events, continuation) = AsyncStream.makeStream(of: Void.self)
        coordinator.onSelectionCleared = { continuation.yield(()) }
        defer { coordinator.onSelectionCleared = nil }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            continuation.finish()
        }
        defer { timer.cancel() }
        try await action()
        for await _ in events {
            return true
        }
        return false
    }

    /// Returns `true` if `window.FRUSOffsets` was set by the injected WKUserScript.
    func userScriptInjected() async throws -> Bool {
        let result = try await webView.evaluateJavaScript(
            "window.FRUSOffsets !== null && window.FRUSOffsets !== undefined"
        )
        return (result as? Bool) ?? false
    }

    // MARK: WKNavigationDelegate

    /// Resumes a pending `load(_:)` once the page has finished loading.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume(returning: ())
        loadContinuation = nil
    }

    /// Fails a pending `load(_:)` with the navigation's error.
    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    /// Fails a pending `load(_:)` when the navigation fails before it commits.
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
}

// MARK: - SelectionScriptParityTests (#269)

/// Guards the two copies of the text-selection bridge script — the embedded Swift constant
/// `kSelectionJS` (the copy actually injected) and the reference `Resources/frus-selection.js`
/// — against drift. They diverged before #269 (the constant had gained `text`/footnote handling
/// the file lacked); this suite fails loudly if the file's body ever falls out of sync again.
struct SelectionScriptParityTests {

    /// The JS body below any leading `/** … */` JSDoc header, whitespace-trimmed. `kSelectionJS`
    /// has no block comment, so it is just trimmed; the resource file's header is stripped.
    private func jsBody(_ source: String) -> String {
        if let close = source.range(of: "*/") {
            return String(source[close.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("kSelectionJS and frus-selection.js share an identical body")
    func selectionScriptsInSync() throws {
        let url = try #require(
            Bundle.main.url(forResource: "frus-selection", withExtension: "js"),
            "frus-selection.js must ship in the app bundle for the parity guard to run")
        let fileSource = try String(contentsOf: url, encoding: .utf8)
        #expect(jsBody(fileSource) == jsBody(kSelectionJS))
    }

    @Test("both copies capture blockText in the footnote branch")
    func bothCaptureBlockText() throws {
        let url = try #require(Bundle.main.url(forResource: "frus-selection", withExtension: "js"))
        let fileSource = try String(contentsOf: url, encoding: .utf8)
        // A regression tripwire independent of the byte-parity check above.
        for source in [kSelectionJS, fileSource] {
            #expect(source.contains("enclosingBlockText"))
            #expect(source.contains("start: -1, end: -1, text, blockText"))
        }
    }

    @Test("both copies carry the selection rect and post the scroll hide-signal")
    func bothCaptureRectAndScroll() throws {
        let url = try #require(Bundle.main.url(forResource: "frus-selection", withExtension: "js"))
        let fileSource = try String(contentsOf: url, encoding: .utf8)
        // Research-rail Phase A: rect/scale on selections + a throttled selectionScrolled signal.
        for source in [kSelectionJS, fileSource] {
            #expect(source.contains("getBoundingClientRect"))
            #expect(source.contains("rect: geom.rect, scale: geom.scale"))
            #expect(source.contains("selectionScrolled"))
        }
    }
}

// MARK: - FRUSSelectionEventDecodeTests (#269 + Research-rail Phase A)

/// Pure decode of the `selectionChanged` message body, testable without a `WKScriptMessage`.
struct FRUSSelectionEventDecodeTests {

    @Test("In-document selection decodes to a .selection payload with offsets")
    func rangedSelection() {
        let event = decodeFRUSSelectionEvent(from: ["start": 3, "end": 10, "text": "telegram"])
        #expect(event == .selection(SelectionPayload(start: 3, end: 10, text: "telegram")))
        if case .selection(let p) = event { #expect(p.hasOffsets) } else { Issue.record("expected .selection") }
    }

    @Test("Footnote selection carries text and blockText, no offsets")
    func footnoteSelection() {
        let event = decodeFRUSSelectionEvent(from: [
            "start": -1, "end": -1, "text": "64 D 171",
            "blockText": "Source: National Archives, RG 59, Lot File 64 D 171."])
        #expect(event == .selection(SelectionPayload(
            start: -1, end: -1, text: "64 D 171",
            blockText: "Source: National Archives, RG 59, Lot File 64 D 171.")))
        if case .selection(let p) = event { #expect(!p.hasOffsets) } else { Issue.record("expected .selection") }
    }

    @Test("Footnote selection with missing blockText falls back to the raw text")
    func footnoteWithoutBlockText() {
        let event = decodeFRUSSelectionEvent(from: ["start": -1, "end": -1, "text": "64 D 171"])
        #expect(event == .selection(SelectionPayload(start: -1, end: -1, text: "64 D 171", blockText: "64 D 171")))
    }

    @Test("Sentinel offsets with empty text decode to .cleared, even with a stray blockText")
    func clearedSelection() {
        #expect(decodeFRUSSelectionEvent(from: ["start": -1, "end": -1]) == .cleared)
        #expect(decodeFRUSSelectionEvent(from: ["start": -1, "end": -1, "text": ""]) == .cleared)
        // The empty-text guard precedes the blockText read, so a stray key can't resurrect it.
        #expect(decodeFRUSSelectionEvent(
            from: ["start": -1, "end": -1, "text": "", "blockText": "junk"]) == .cleared)
    }

    @Test("In-document selection ignores a stray blockText key")
    func rangedIgnoresBlockText() {
        let event = decodeFRUSSelectionEvent(
            from: ["start": 2, "end": 6, "text": "abc", "blockText": "junk"])
        #expect(event == .selection(SelectionPayload(start: 2, end: 6, text: "abc")))
    }

    @Test("Malformed and degenerate bodies decode to nil")
    func malformedBodies() {
        #expect(decodeFRUSSelectionEvent(from: [:]) == nil)
        #expect(decodeFRUSSelectionEvent(from: ["start": "x", "end": 4]) == nil)
        // Degenerate in-document range (end <= start) is not a valid selection.
        #expect(decodeFRUSSelectionEvent(from: ["start": 5, "end": 5, "text": "x"]) == nil)
    }

    @Test("Selection carries the bounding rect + scale when present (both branches)")
    func selectionCarriesRect() {
        let ranged = decodeFRUSSelectionEvent(from: [
            "start": 3, "end": 10, "text": "t",
            "rect": ["x": 12.0, "y": 40.0, "w": 100.0, "h": 18.0], "scale": 1.0])
        #expect(ranged == .selection(SelectionPayload(
            start: 3, end: 10, text: "t", rect: CGRect(x: 12, y: 40, width: 100, height: 18), scale: 1)))

        let footnote = decodeFRUSSelectionEvent(from: [
            "start": -1, "end": -1, "text": "x", "blockText": "b",
            "rect": ["x": 5.0, "y": 6.0, "w": 7.0, "h": 8.0], "scale": 2.0])
        #expect(footnote == .selection(SelectionPayload(
            start: -1, end: -1, text: "x", blockText: "b",
            rect: CGRect(x: 5, y: 6, width: 7, height: 8), scale: 2)))
    }

    @Test("Absent or partial rect tolerates to nil rect, scale 1 (old payloads still decode)")
    func rectTolerant() {
        // Pre-rect payload shape (no rect/scale keys).
        #expect(decodeFRUSSelectionEvent(from: ["start": 3, "end": 10, "text": "t"])
                == .selection(SelectionPayload(start: 3, end: 10, text: "t", rect: nil, scale: 1)))
        // Rect present but missing a field → nil rect, scale still defaults.
        #expect(decodeFRUSSelectionEvent(from: [
            "start": 3, "end": 10, "text": "t", "rect": ["x": 1.0, "y": 2.0, "w": 3.0]])
                == .selection(SelectionPayload(start: 3, end: 10, text: "t", rect: nil, scale: 1)))
    }
}

// MARK: - NARACitationStrategyTests (#269)

/// The strategy routing for a footnote's detected citation quick-fills — F1 of the #269 review
/// (route by the citation's own record group, not a hardcoded RG 59).
struct NARACitationStrategyTests {

    @Test("Lot strategy honours an explicit record group")
    func lotHonoursExplicitRG() {
        #expect(LookupStrategy.lotStrategy(recordGroup: "84", lotFile: "64 D 171") == .lotFileRG84)
        #expect(LookupStrategy.lotStrategy(recordGroup: "59", lotFile: "55 F 44") == .lotFileRG59)
    }

    @Test("Lot strategy infers RG 84 from an F-designator when the RG is absent")
    func lotInfersFDesignator() {
        #expect(LookupStrategy.lotStrategy(recordGroup: nil, lotFile: "55 F 44") == .lotFileRG84)
        #expect(LookupStrategy.lotStrategy(recordGroup: nil, lotFile: "57–F103") == .lotFileRG84)
        // A D-designator (or any non-F) lot without an explicit RG stays RG 59 (the default).
        #expect(LookupStrategy.lotStrategy(recordGroup: nil, lotFile: "64 D 171") == .lotFileRG59)
    }

    @Test("Keyword strategy scopes to the named RG, else general")
    func keywordStrategyRouting() {
        #expect(LookupStrategy.keywordStrategy(recordGroup: "59") == .keywordRG59)
        #expect(LookupStrategy.keywordStrategy(recordGroup: "84") == .keywordRG84)
        // A presidential-library collection (no record group) gets a general keyword search.
        #expect(LookupStrategy.keywordStrategy(recordGroup: nil) == .keyword)
        #expect(LookupStrategy.keywordStrategy(recordGroup: "256") == .keyword)
    }
}

// MARK: - FloatingSelectionBarGeometryTests (Research-rail Phase B)

/// Pure clamping/flip geometry for the floating selection bar's ``FloatingSelectionBar/anchorCenter``.
struct FloatingSelectionBarGeometryTests {

    private let container = CGSize(width: 800, height: 600)
    private let barSize = CGSize(width: 200, height: 40)   // halfW 100, halfH 20

    @Test("Below anchoring centres the bar under the selection")
    @MainActor
    func belowCentred() {
        let center = FloatingSelectionBar.anchorCenter(
            selection: CGRect(x: 100, y: 200, width: 60, height: 20),   // midX 130, maxY 220
            barSize: barSize, in: container, below: true)
        // x = midX (well within bounds); y = maxY + gap(8) + halfH(20) = 248.
        #expect(center == CGPoint(x: 130, y: 248))
    }

    @Test("A selection near the left edge clamps the bar fully on-screen")
    @MainActor
    func clampsLeft() {
        let center = FloatingSelectionBar.anchorCenter(
            selection: CGRect(x: 0, y: 200, width: 20, height: 20),     // midX 10
            barSize: barSize, in: container, below: true)
        // minX = halfW(100) + margin(8) = 108 wins over midX 10.
        #expect(center.x == 108)
    }

    @Test("A selection near the right edge clamps the bar fully on-screen")
    @MainActor
    func clampsRight() {
        let center = FloatingSelectionBar.anchorCenter(
            selection: CGRect(x: 780, y: 200, width: 20, height: 20),   // midX 790
            barSize: barSize, in: container, below: true)
        // maxX = width(800) - halfW(100) - margin(8) = 692 wins over midX 790.
        #expect(center.x == 692)
    }

    @Test("Below anchoring flips above when it would clip past the container bottom")
    @MainActor
    func flipsAboveNearBottom() {
        let center = FloatingSelectionBar.anchorCenter(
            selection: CGRect(x: 100, y: 560, width: 60, height: 20),   // maxY 580, minY 560
            barSize: barSize, in: container, below: true)
        // centreBelow 608 would clip (608+20+8 > 600) → flip to centreAbove = 560 - 8 - 20 = 532.
        #expect(center.y == 532)
    }

    @Test("Above anchoring (macOS) flips below when it would clip past the container top")
    @MainActor
    func flipsBelowNearTop() {
        let center = FloatingSelectionBar.anchorCenter(
            selection: CGRect(x: 100, y: 10, width: 60, height: 20),    // minY 10, maxY 30
            barSize: barSize, in: container, below: false)
        // centreAbove -18 would clip (-18-20-8 < 0) → flip to centreBelow = 30 + 8 + 20 = 58.
        #expect(center.y == 58)
    }
}

// MARK: - SelectionBarStateTests (Research-rail Phase B)

/// Visibility + the false-clear debounce for ``SelectionBarState`` — the bar must survive the
/// spurious `selectioncleared` a bar tap fires, yet dismiss on a real clear.
@MainActor
struct SelectionBarStateTests {

    @Test("present shows the bar with its anchor + footnote flag; hideNow clears it")
    func presentAndHide() {
        let state = SelectionBarState()
        #expect(state.isVisible == false)

        let rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        state.present(rect: rect, atFootnote: true)
        #expect(state.isVisible)
        #expect(state.anchor == rect)
        #expect(state.atFootnote)

        state.hideNow()
        #expect(state.isVisible == false)
        #expect(state.anchor == nil)
    }

    @Test("A re-present cancels a pending debounced hide (bar survives the false clear)")
    func presentCancelsScheduledHide() async {
        let state = SelectionBarState()
        state.present(rect: CGRect(x: 0, y: 0, width: 10, height: 10), atFootnote: false)
        state.scheduleHide(after: 50)   // false-clear opens the debounce window…
        let reanchored = CGRect(x: 5, y: 5, width: 10, height: 10)
        state.present(rect: reanchored, atFootnote: false)   // …but a fresh selection re-presents
        try? await Task.sleep(for: .milliseconds(120))       // let the cancelled window elapse
        #expect(state.isVisible)
        #expect(state.anchor == reanchored)
    }

    @Test("scheduleHide dismisses the bar once its window elapses with no intervening present")
    func scheduleHideDismisses() async {
        let state = SelectionBarState()
        state.present(rect: CGRect(x: 0, y: 0, width: 10, height: 10), atFootnote: false)
        state.scheduleHide(after: 30)
        try? await Task.sleep(for: .milliseconds(120))
        #expect(state.isVisible == false)
    }
}

// MARK: - SelectionEditMenuItemTests (#1540)

/// The iPhone and iPad edit menu's own items (#1540): which verbs a selection offers, in what order,
/// under what spoken names, and what each performs — and the web view's rule for adding them.
///
/// `SelectionEditMenuTests` in the UI target is the half that drives UIKit: it selects a word in a
/// real document and reads the menu UIKit drew. This half pins what that test cannot reach — a
/// footnote selection (the fixture has no footnote), each colour's action, the three guards in
/// `_FRUSEditMenuWebView.selectionGroup()` (a handler, a reported selection, text in it), and the
/// clear that follows a chosen item, read from a page through the real selection bridge.
///
/// Two pieces of the wiring are reached by no test here or in the UI suite: `buildMenu(with:)`'s
/// `builder.system == .context` guard, which keeps the items out of the iPad's menu bar (a
/// `UIMenuBuilder` cannot be built in a test), and the representables' `forgetSelection()` call
/// when a new page loads (`updateUIView` needs a SwiftUI context). The insertion at the start of
/// the menu is the UI suite's.
@MainActor
struct SelectionEditMenuItemTests {

    /// Collects what the menu's items perform, so a test can read it back.
    @MainActor
    private final class Recorder {
        var verbs: [SelectionVerb] = []
        var changed = 0
        var cleared = 0
    }

    /// The names the edit menu speaks, in the order #1540's decision puts them.
    private static let spokenNames = ["Highlight Yellow", "Highlight Green", "Highlight Blue",
                                      "Highlight Pink", "Excerpt", "Look Up in NARA", "Note"]

    /// A selection in the document body, as the selection bridge reports one.
    private static let bodySelection = SelectionPayload(start: 3, end: 12, text: "Synthetic")

    /// A selection inside a footnote: text, its note, no offsets.
    private static let footnoteSelection = SelectionPayload(
        start: -1, end: -1, text: "Lot 61 D 233", blockText: "Source: Lot 61 D 233.")

    /// What each item is called aloud: its title, or for an untitled colour dot its image's label,
    /// which is where the menu reads an untitled item's name (the UI suite measured "Circle" when
    /// the name was on the action instead).
    private func spokenName(_ action: UIAction) -> String {
        action.title.isEmpty ? (action.image?.accessibilityLabel ?? "") : action.title
    }

    @Test("A selection in the document body offers all seven verbs, the colours first")
    func bodySelectionOffersEveryVerb() {
        #expect(SelectionEditMenu.verbs(hasDocumentOffsets: true) == [
            .highlight(.yellow), .highlight(.green), .highlight(.blue), .highlight(.pink),
            .excerpt, .lookUpInNARA, .note,
        ])
    }

    @Test("A footnote selection offers only Look Up in NARA and Note")
    func footnoteSelectionOffersLookUpAndNote() {
        #expect(SelectionEditMenu.verbs(hasDocumentOffsets: false) == [.lookUpInNARA, .note])
    }

    @Test("The group is inline, and each item carries the name VoiceOver reads")
    func itemsCarryTheirSpokenNames() {
        let group = SelectionEditMenu.menu(hasDocumentOffsets: true) { _ in }
        #expect(group.identifier == SelectionEditMenu.identifier)
        #expect(group.options.contains(.displayInline))
        let actions = group.children.compactMap { $0 as? UIAction }
        #expect(actions.count == group.children.count)
        #expect(actions.map(spokenName) == Self.spokenNames)
        // A colour is an untitled dot with an image; the three verbs are titled.
        for dot in actions.prefix(4) {
            #expect(dot.title.isEmpty)
            #expect(dot.image != nil)
        }
        for verb in actions.suffix(3) {
            #expect(!verb.title.isEmpty)
        }
    }

    @Test("Choosing an item performs its own verb")
    func eachItemPerformsItsVerb() {
        let recorder = Recorder()
        let group = SelectionEditMenu.menu(hasDocumentOffsets: true) { recorder.verbs.append($0) }
        for case let action as UIAction in group.children {
            action.performWithSender(nil, target: nil)
        }
        #expect(recorder.verbs == SelectionVerb.allInOrder)
        #expect(recorder.verbs.count == 7)
    }

    @Test("The Mac bar and the iOS menu share one name per verb; Look Up says NARA")
    func verbNames() {
        #expect(SelectionVerb.allInOrder.map(\.title) == Self.spokenNames)
        #expect(SelectionVerb.lookUpInNARA.title == "Look Up in NARA")
        #expect(SelectionVerb.allInOrder.filter(\.needsDocumentOffsets).count == 5)
    }

    @Test("The coordinator keeps the selection the page reported last, and forgets it on a clear")
    func coordinatorTracksTheLiveSelection() {
        let coordinator = _FRUSWebViewCoordinator()
        let recorder = Recorder()
        coordinator.onSelectionChanged = { _ in recorder.changed += 1 }
        coordinator.onSelectionCleared = { recorder.cleared += 1 }
        #expect(coordinator.liveSelection == nil)

        coordinator.receive(.selection(Self.bodySelection))
        #expect(coordinator.liveSelection == Self.bodySelection)
        coordinator.receive(.selection(Self.footnoteSelection))
        #expect(coordinator.liveSelection == Self.footnoteSelection)
        coordinator.receive(.cleared)
        #expect(coordinator.liveSelection == nil)
        // The view's callbacks still hear every report.
        #expect(recorder.changed == 2)
        #expect(recorder.cleared == 1)

        coordinator.receive(.selection(Self.bodySelection))
        coordinator.forgetSelection()
        #expect(coordinator.liveSelection == nil)
    }

    /// A web view wired to a coordinator, as `makeUIView` builds it.
    private func webView(reporting selection: SelectionPayload?,
                         recorder: Recorder?) -> (_FRUSEditMenuWebView, _FRUSWebViewCoordinator) {
        let coordinator = _FRUSWebViewCoordinator()
        let webView = _FRUSEditMenuWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.selectionReports = coordinator
        if let recorder {
            webView.onSelectionVerb = { recorder.verbs.append($0) }
        }
        if let selection {
            coordinator.receive(.selection(selection))
        }
        return (webView, coordinator)
    }

    @Test("The web view adds all seven items for a selection in the document body")
    func webViewGroupForABodySelection() throws {
        let recorder = Recorder()
        let (webView, coordinator) = webView(reporting: Self.bodySelection, recorder: recorder)
        let group = try #require(webView.selectionGroup())
        let actions = group.children.compactMap { $0 as? UIAction }
        #expect(actions.map(spokenName) == Self.spokenNames)
        actions[5].performWithSender(nil, target: nil)
        #expect(recorder.verbs == [.lookUpInNARA])
        withExtendedLifetime(coordinator) {}
    }

    @Test("The web view adds only Look Up in NARA and Note for a footnote selection")
    func webViewGroupForAFootnoteSelection() throws {
        let (webView, coordinator) = webView(reporting: Self.footnoteSelection, recorder: Recorder())
        let group = try #require(webView.selectionGroup())
        #expect(group.children.compactMap { $0 as? UIAction }.map(spokenName)
                == ["Look Up in NARA", "Note"])
        withExtendedLifetime(coordinator) {}
    }

    @Test("The web view adds nothing before the page has reported a selection")
    func webViewGroupWithNoReportedSelection() {
        let (webView, coordinator) = webView(reporting: nil, recorder: Recorder())
        #expect(webView.selectionGroup() == nil)
        withExtendedLifetime(coordinator) {}
    }

    @Test("The web view adds nothing after the page reports a clear")
    func webViewGroupAfterAClear() {
        let (webView, coordinator) = webView(reporting: Self.bodySelection, recorder: Recorder())
        coordinator.receive(.cleared)
        #expect(webView.selectionGroup() == nil)
        // Held to here, as in the tests beside it: the web view holds the coordinator weakly, and a
        // coordinator released early would make the group nil whether or not the clear was recorded.
        withExtendedLifetime(coordinator) {}
    }

    /// A one-paragraph document to select a word in, through the real selection bridge.
    private static let pageFixture = """
    <div type="document" xml:id="d1"><p>Synthetic text for the edit menu.</p></div>
    """

    @Test("Choosing an item performs its verb and clears the page's selection, which the page reports")
    func choosingAnItemClearsTheSelection() async throws {
        let model = try await ListShapeFixtures.renderModel(Self.pageFixture)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        let recorder = Recorder()
        harness.webView.onSelectionVerb = { recorder.verbs.append($0) }

        let reported = try await harness.selectionPayload {
            _ = try await harness.evaluateString("""
                (() => {
                  const walker = document.createTreeWalker(
                    document.querySelector('.frus-document'), NodeFilter.SHOW_TEXT);
                  let t = walker.nextNode();
                  while (t && !t.nodeValue.includes('Synthetic')) t = walker.nextNode();
                  if (!t) return 'no text';
                  const at = t.nodeValue.indexOf('Synthetic');
                  getSelection().removeAllRanges();
                  getSelection().setBaseAndExtent(t, at, t, at + 9);
                  return getSelection().toString();
                })()
                """)
        }
        let selection = try #require(reported, "the selection bridge posted nothing")
        #expect(selection.hasOffsets && selection.text == "Synthetic",
                "start \(selection.start), end \(selection.end), \"\(selection.text)\"")
        #expect(harness.coordinator.liveSelection == selection)

        let group = try #require(harness.webView.selectionGroup())
        let yellow = try #require(group.children.compactMap { $0 as? UIAction }
            .first { spokenName($0) == "Highlight Yellow" })
        let cleared = try await harness.selectionCleared {
            yellow.performWithSender(nil, target: nil)
        }
        #expect(recorder.verbs == [.highlight(.yellow)])
        #expect(cleared, "choosing Highlight Yellow reported no clear: the page kept its selection")
        #expect(harness.coordinator.liveSelection == nil)
        let collapsed = try await harness.evaluateString("String(getSelection().isCollapsed)")
        #expect(collapsed == "true", "the page still holds a selection after Highlight Yellow")
    }

    @Test("The web view adds nothing for a reported selection with no text")
    func webViewGroupForAnEmptySelection() {
        let (webView, coordinator) = webView(
            reporting: SelectionPayload(start: 3, end: 12, text: ""), recorder: Recorder())
        #expect(webView.selectionGroup() == nil)
        withExtendedLifetime(coordinator) {}
    }

    @Test("The web view adds nothing when no handler is attached")
    func webViewGroupWithNoHandler() {
        let (webView, coordinator) = webView(reporting: Self.bodySelection, recorder: nil)
        #expect(webView.selectionGroup() == nil)
        withExtendedLifetime(coordinator) {}
    }
}

// MARK: - SelectionBarRetirementTests (#1540)

/// The iPhone and iPad reader mounts no floating selection bar, and routes the selection's verbs
/// through the edit menu instead (#1540).
///
/// A source read, because the bar's absence has no runtime value a unit test can observe. The
/// runtime guard is the UI suite `SelectionEditMenuTests`, which fails on iPhone and iPad when a
/// button named like one of the bar's is on screen beside the edit menu. This pins the two calls
/// the fix turns on, so a bar mounted again fails here with its site named.
struct SelectionBarRetirementTests {

    /// `DocumentView.swift`, the iPhone and iPad reader.
    private static func readerSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/DocumentView/DocumentView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The 1-based lines of `source` holding `needle`.
    private static func lines(of needle: String, in source: String) -> [Int] {
        source.components(separatedBy: "\n").enumerated()
            .filter { $0.element.contains(needle) }.map { $0.offset + 1 }
    }

    @Test("The iOS reader mounts no FloatingSelectionBar and wires the edit menu's verbs")
    func readerUsesTheEditMenu() throws {
        let source = try Self.readerSource()
        #expect(source.count > 50_000, "read too little of DocumentView.swift to judge it")
        let barSites = Self.lines(of: "FloatingSelectionBar(", in: source)
            + Self.lines(of: "FloatingSelectionBarPositioner(", in: source)
        #expect(barSites.isEmpty, "DocumentView.swift mounts the retired bar at lines \(barSites)")
        let menuSites = Self.lines(of: ".onSelectionVerb {", in: source)
        #expect(menuSites.count == 1,
                "DocumentView.swift should hand the edit menu's verbs to the reader once; found \(menuSites)")
    }
}

// MARK: - TextNodeEndSelectionTests (#1540 review round 1)

/// A selection endpoint just past a text node's last character maps to the offset after that
/// character, not to −1 (#1540 review round 1).
///
/// The offset engine holds one `charToNode` entry per character, so an endpoint at
/// `(textNode, textNode.length)` — where a drag that ends a paragraph, or ends just before a
/// footnote marker or a name, puts its end — had no entry, and the whole selection took the
/// footnote branch: on iPhone and iPad the edit menu left out the colours and Excerpt, and the
/// Mac's bar drew them dimmed. `buildRanges` in `frus-highlights.js` ends a highlight's range at
/// exactly that endpoint, so the reverse mapping now accepts what the forward one produces.
///
/// The endpoints are placed directly, as `ListLabelSelectionTests`' scope tests place theirs, and
/// the payload read is the one the production bridge posts.
@Suite("A selection ending at a text node's end keeps its offsets (#1540)")
@MainActor
struct TextNodeEndSelectionTests {

    /// A paragraph whose first text node ends at a footnote marker, the text after the marker, a
    /// second paragraph, and a footnote shorter than the body's first text node, so that a rule
    /// matching a character by its position alone would find one in the body.
    private static let fixture = """
    <div type="document" xml:id="d1">
      <p>Body text with a note.<note n="1" xml:id="d1fn1"><p>Lot 61 D 233.</p></note> More body text.</p>
      <p>A second paragraph.</p>
    </div>
    """

    /// Loads the fixture and returns the harness plus the Swift flat text its offsets index.
    private func loaded() async throws -> (OffsetEngineTestHarness, String) {
        let model = try await ListShapeFixtures.renderModel(Self.fixture)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        return (harness, buildFlatText(from: model))
    }

    /// The UTF-16 offset of `needle` in `flat`.
    private func offset(of needle: String, in flat: String) throws -> Int {
        let range = try #require(flat.range(of: needle), "\"\(needle)\" is not in the flat text")
        return flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
    }

    /// A JS expression: the first text node under `root` holding `needle`, outside any `data-skip`
    /// element (so the body's text, not a footnote popover's).
    private func textNode(_ needle: String,
                          under root: String = "document.querySelector('.frus-document')") -> String {
        """
        (() => {
          const walker = document.createTreeWalker(\(root), NodeFilter.SHOW_TEXT, { acceptNode: t =>
            t.parentElement.closest('[data-skip="1"]') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT });
          let t = walker.nextNode();
          while (t && !t.nodeValue.includes('\(needle)')) t = walker.nextNode();
          return t;
        })()
        """
    }

    /// Selects from `startOffset` in the text node `start` to `endOffset` in `end`, and returns the
    /// payload the bridge posts. The offsets are JS expressions, so `a.length` and `b.length` name
    /// the ends of the start and end nodes.
    private func select(_ harness: OffsetEngineTestHarness,
                        from start: String, _ startOffset: String,
                        to end: String, _ endOffset: String) async throws -> SelectionPayload? {
        try await harness.selectionPayload {
            let result = try await harness.evaluateString("""
                (() => {
                  const a = \(start);
                  const b = \(end);
                  if (!a || !b) return 'an endpoint text node is not on the page';
                  getSelection().removeAllRanges();
                  getSelection().setBaseAndExtent(a, \(startOffset), b, \(endOffset));
                  return 'ok';
                })()
                """)
            #expect(result == "ok", "\(result ?? "the script returned nothing")")
        }
    }

    @Test("A selection ending just before a footnote marker, at its text node's end, keeps its offsets")
    func endAtATextNodesEndBeforeAMarker() async throws {
        let (harness, flat) = try await loaded()
        let node = textNode("Body text")
        let payload = try await select(harness, from: node, "5", to: node, "b.length")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "start \(selection.start), end \(selection.end) for \"\(selection.text)\": took the footnote branch")
        let base = try offset(of: "Body text with a note.", in: flat)
        #expect(selection.start == base + 5)
        #expect(selection.end == base + 22)
        #expect(selection.text == "text with a note.")
    }

    @Test("A selection ending at the end of a paragraph keeps its offsets")
    func endAtTheEndOfAParagraph() async throws {
        let (harness, flat) = try await loaded()
        let node = textNode("A second")
        let payload = try await select(harness, from: node, "2", to: node, "b.length")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "start \(selection.start), end \(selection.end) for \"\(selection.text)\": took the footnote branch")
        let base = try offset(of: "A second paragraph.", in: flat)
        #expect(selection.start == base + 2)
        #expect(selection.end == base + 19)
    }

    @Test("A selection starting at a text node's end starts at the next character in the flat text")
    func startAtATextNodesEnd() async throws {
        let (harness, flat) = try await loaded()
        let payload = try await select(harness, from: textNode("Body text"), "a.length",
                                       to: textNode("More body"), "5")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "start \(selection.start), end \(selection.end) for \"\(selection.text)\": took the footnote branch")
        let next = try offset(of: " More body text.", in: flat)
        #expect(selection.start == next, "the marker between adds nothing to the flat text")
        #expect(selection.end == next + 5)
    }

    /// Nothing in the Footnotes list is in the offset map, so the end of one of its text nodes must
    /// stay unmapped: a rule that matched the character before it by position, or moved it to the
    /// next mapped character, would turn a drag into a footnote into a highlight of the body.
    @Test("A selection ending at the end of a footnote's text is still a footnote selection")
    func endAtTheEndOfAFootnoteStaysAFootnoteSelection() async throws {
        let (harness, _) = try await loaded()
        let payload = try await select(
            harness, from: textNode("Body text"), "5",
            to: textNode("Lot 61", under: "document.querySelector('.footnotes-section')"), "b.length")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(!selection.hasOffsets,
                "a footnote endpoint must stay unmapped: start \(selection.start), end \(selection.end)")
    }
}

// MARK: - FigureReaderTests (#1516)

/// The reader's own page, in a real web view, drawing figures: the image through the scheme
/// handler, the placeholder for an image that is not on the device, and the parts of the page —
/// a figure's text, the space between two inline elements — that are drawn outside the flat text.
///
/// Every test loads `HTMLTemplate.build`, the page the reader loads, into the production web-view
/// configuration with a scheme handler whose figure store is the test's own folder. Nothing here
/// reads the device's figures or reaches the network. The suite runs on any iOS destination.
@Suite("The reader draws a figure's image from the device, and its text outside the flat text (#1516)")
@MainActor
struct FigureReaderTests {

    /// What the page drew for one figure.
    private struct DrawnFigure: Decodable {
        /// The `<img>`'s `src`, or `nil` when the figure has no image element.
        let src: String?
        /// The image's decoded width in pixels: 0 until, or unless, it loads.
        let naturalWidth: Int
        /// Whether the image element is displayed.
        let imageShown: Bool
        /// Whether the placeholder is displayed.
        let placeholderShown: Bool
        /// The figure's visible text.
        let text: String
    }

    private static let figuresScript = """
    JSON.stringify(Array.from(document.querySelectorAll('.frus-figure')).map(f => {
      const i = f.querySelector('img.figure-image');
      const m = f.querySelector('.figure-missing');
      return {
        src: i ? i.getAttribute('src') : null,
        naturalWidth: i ? i.naturalWidth : 0,
        imageShown: !!i && getComputedStyle(i).display !== 'none',
        placeholderShown: !!m && getComputedStyle(m).display !== 'none',
        text: f.innerText
      };
    }))
    """

    /// What the page drew for each figure, in document order.
    private func figures(_ harness: OffsetEngineTestHarness) async throws -> [DrawnFigure] {
        let raw = try #require(try await harness.evaluateString(Self.figuresScript), "the page returned nothing")
        return try JSONDecoder().decode([DrawnFigure].self, from: Data(raw.utf8))
    }

    /// d587 converted in its volume. That the reader's own load converts a document in its
    /// volume is ``theReadersLoadNamesImagesByItsVolume()``'s to show; this is the fixture.
    private func d587() async throws -> FRUSDocumentRenderModel {
        try await ListShapeFixtures.renderModel(
            FigureFixtures.d587, converter: ASTToRenderNodeConverter(volumeId: "frus1946v01"))
    }

    /// The reader shows an image only because `DocumentViewModel.load` tells the converter its
    /// document's volume: without it every figure is named with no volume, the page gets no
    /// `<img>` for it, and "[Figure]" prints for every image in every document. Driven through
    /// the real load, since a test that builds its own converter cannot see that line.
    @Test("The reader's own load names each figure's image by the document's volume, and the page draws it")
    func theReadersLoadNamesImagesByItsVolume() async throws {
        try await FigureTestImages.withLibrary { library in
            try FigureTestImages.seedVolume("frus1946v01", in: library)
            #expect(library.store(try FigureTestImages.png(width: 120, height: 80),
                                  volumeId: "frus1946v01", fileName: "figure_1162.png"))
            let viewModel = DocumentViewModel(
                entry: DocumentBrowserEntry(documentId: "d587", volumeId: "frus1946v01", header: ""),
                volumeEntry: nil, parser: FRUSDocumentParser())
            await viewModel.load(volumeURL: library.volumesDirectory.appendingPathComponent("frus1946v01.xml"))
            let model = try #require(viewModel.renderModel, "d587 did not load: \(String(describing: viewModel.loadError))")
            #expect(model.figureImages == [
                FigureImageName(volumeId: "frus1946v01", graphic: "figure_1162"),
                FigureImageName(volumeId: "frus1946v01", graphic: "figure_1163"),
                FigureImageName(volumeId: "frus1946v01", graphic: "figure_1166"),
            ])

            let harness = OffsetEngineTestHarness(figureImages: FigureImageStore(library: library))
            try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
            let first = try #require(try await figures(harness).first, "the page drew no figure")
            #expect(first.src == "frusexplorer://figure/frus1946v01/figure_1162.png")
            #expect(first.naturalWidth == 120 && first.imageShown && !first.placeholderShown, "\(first)")
        }
    }

    /// Where the page is scrolled to, and where a footnote's entry sits in the window.
    private struct FootnotePlace: Decodable {
        let scrollY: Double
        let top: Double
        let bottom: Double
        let windowHeight: Double
        /// Whether the whole entry is inside the window.
        var inView: Bool { top >= 0 && bottom <= windowHeight }
    }

    private func footnotePlace(_ harness: OffsetEngineTestHarness, id: String) async throws -> FootnotePlace {
        let raw = try #require(try await harness.evaluateString("""
            (() => {
              const r = document.getElementById("\(id)").getBoundingClientRect();
              return JSON.stringify({ scrollY: window.scrollY, top: r.top, bottom: r.bottom, windowHeight: window.innerHeight });
            })()
            """), "the page has no element \(id)")
        return try JSONDecoder().decode(FootnotePlace.self, from: Data(raw.utf8))
    }

    /// #988 brings the reader to a footnote when the page has loaded. An image that is not on the
    /// device is fetched after that and laid out when it lands, which pushes everything under it —
    /// the footnotes among it — down by its height. The reader must still be at the footnote.
    @Test("An image fetched after the reader was brought to a footnote leaves that footnote in view")
    func aLateImageKeepsARevealedFootnoteInView() async throws {
        try await FigureTestImages.withLibrary { library in
            // Three windows tall: nothing a scroll margin could absorb.
            let png = try FigureTestImages.png(width: 400, height: 1_800)
            let gate = FigureTestImages.Gate()
            let store = FigureImageStore(library: library) { volumeId, fileName in
                await gate.wait()
                return library.store(png, volumeId: volumeId, fileName: fileName)
            }
            let paragraphs = (1...60).map { "<p>Paragraph \($0) of a document long enough to scroll.</p>" }.joined()
            let model = try await ListShapeFixtures.renderModel("""
                <div type="document" xml:id="d1">
                  <p>A map:</p><figure><graphic url="map"/></figure>
                  <p>A sentence with a note.<note n="1" xml:id="d1fn1">The note the reader is brought to.</note></p>
                  \(paragraphs)
                </div>
                """, converter: ASTToRenderNodeConverter(volumeId: "v"))
            let harness = OffsetEngineTestHarness(figureImages: store)
            try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))

            // The reader arrives at the note while the map is still its placeholder.
            harness.coordinator.pendingFootnoteAnchor = "d1fn1"
            #expect(await harness.coordinator.revealFootnote(on: harness.webView), "the note is not on the page")
            let before = try await footnotePlace(harness, id: "fnote-x-d1fn1")
            #expect(before.inView && before.scrollY > 0, "the reveal did not bring the note into view: \(before)")

            // The map lands, and is drawn.
            await gate.open()
            var drawn = try await figures(harness).first
            for _ in 0..<400 where drawn?.naturalWidth != 400 {
                try await Task.sleep(for: .milliseconds(50))
                drawn = try await figures(harness).first
            }
            #expect(drawn?.naturalWidth == 400, "the fetched image was never drawn: \(String(describing: drawn))")
            var after = try await footnotePlace(harness, id: "fnote-x-d1fn1")
            for _ in 0..<40 where !after.inView {
                try await Task.sleep(for: .milliseconds(50))
                after = try await footnotePlace(harness, id: "fnote-x-d1fn1")
            }
            #expect(after.inView, "the map pushed the note out of view: it is \(after.top) pt down a \(after.windowHeight) pt window")
            #expect(after.scrollY > before.scrollY + 1_000, "the page did not follow the note down past the map: \(before) then \(after)")
        }
    }

    @Test("A late image does not bring the reader back to a footnote they have since scrolled away from")
    func aLateImageLeavesAReaderWhoMovedOn() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 400, height: 1_800)
            let gate = FigureTestImages.Gate()
            let store = FigureImageStore(library: library) { volumeId, fileName in
                await gate.wait()
                return library.store(png, volumeId: volumeId, fileName: fileName)
            }
            let paragraphs = (1...60).map { "<p>Paragraph \($0) of a document long enough to scroll.</p>" }.joined()
            let model = try await ListShapeFixtures.renderModel("""
                <div type="document" xml:id="d1">
                  <p>A map:</p><figure><graphic url="map"/></figure>
                  <p>A sentence with a note.<note n="1" xml:id="d1fn1">The note the reader is brought to.</note></p>
                  \(paragraphs)
                </div>
                """, converter: ASTToRenderNodeConverter(volumeId: "v"))
            let harness = OffsetEngineTestHarness(figureImages: store)
            try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
            harness.coordinator.pendingFootnoteAnchor = "d1fn1"
            #expect(await harness.coordinator.revealFootnote(on: harness.webView))
            // The reader turns the wheel and goes back to the top of the document.
            _ = try await harness.evaluateString("""
                (() => { window.dispatchEvent(new WheelEvent("wheel", { deltaY: -400 })); window.scrollTo(0, 0); return "ok"; })()
                """)
            await gate.open()
            var drawn = try await figures(harness).first
            for _ in 0..<400 where drawn?.naturalWidth != 400 {
                try await Task.sleep(for: .milliseconds(50))
                drawn = try await figures(harness).first
            }
            #expect(drawn?.naturalWidth == 400, "the fetched image was never drawn")
            try await Task.sleep(for: .milliseconds(300))
            let after = try await footnotePlace(harness, id: "fnote-x-d1fn1")
            #expect(after.scrollY == 0, "the page was scrolled back to a note the reader had left: \(after)")
        }
    }

    @Test("An image on the device is drawn through the scheme handler; one that is not shows the placeholder in its place")
    func imageOnTheDeviceIsDrawn() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 120, height: 80)
            #expect(library.store(png, volumeId: "frus1946v01", fileName: "figure_1162.png"))
            let harness = OffsetEngineTestHarness(figureImages: FigureImageStore(library: library))
            try await harness.load(HTMLTemplate.build(model: try await d587(), colorScheme: .light))

            let drawn = try await figures(harness)
            #expect(drawn.count == 3, "d587 has three figures: \(drawn)")
            let first = try #require(drawn.first)
            #expect(first.src == "frusexplorer://figure/frus1946v01/figure_1162.png")
            #expect(first.naturalWidth == 120, "the image did not load: \(first)")
            #expect(first.imageShown && !first.placeholderShown, "\(first)")
            #expect(!first.text.contains("[Figure]"), "the placeholder shows beside a loaded image: \(first.text)")
            #expect(first.text.localizedCaseInsensitiveContains("Locations at Which Military Air Transit Rights Are Desired"))

            // figure_1163 is one of the 13 names history.state.gov does not serve.
            let second = drawn[1]
            #expect(second.src == "frusexplorer://figure/frus1946v01/figure_1163.png")
            #expect(second.naturalWidth == 0)
            #expect(!second.imageShown && second.placeholderShown, "\(second)")
            #expect(second.text.contains("[Figure]"), "\(second.text)")
            #expect(second.text.contains("Military Air Transit Requirements (Eastern Hemisphere)"))
        }
    }

    @Test("An image fetched after the page asked for it replaces its placeholder without a reload, asked for once")
    func imageFetchedLaterIsDrawn() async throws {
        try await FigureTestImages.withLibrary { library in
            let png = try FigureTestImages.png(width: 64, height: 48)
            let asked = FigureTestImages.Counter()
            let store = FigureImageStore(library: library) { volumeId, fileName in
                await asked.add("\(volumeId)/\(fileName)")
                switch fileName {
                // As history.state.gov answers: this volume's first map, and not its third.
                case "figure_1162.png": return library.store(png, volumeId: volumeId, fileName: fileName)
                // An image reported fetched that is then not there (removed with its volume, say):
                // the page asks once more, and that request must not start a fetch of its own.
                case "figure_1163.png": return true
                default: return false
                }
            }
            let harness = OffsetEngineTestHarness(figureImages: store)
            try await harness.load(HTMLTemplate.build(model: try await d587(), colorScheme: .light))

            // Up to twenty seconds, here and below (#1516 review, round 1): a five-second wait
            // of this shape timed out once in the first run of a newly built test host.
            var first: DrawnFigure?
            for _ in 0..<400 {
                first = try await figures(harness).first
                if first?.naturalWidth == 64 { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            let drawn = try #require(first)
            #expect(drawn.naturalWidth == 64, "the fetched image was never drawn: \(drawn)")
            #expect(drawn.imageShown && !drawn.placeholderShown, "\(drawn)")
            // The second was asked for again by the page, found absent, and is back to its placeholder.
            var all = try await figures(harness)
            for _ in 0..<400 where !(all[1].src?.hasSuffix("?retry=1") == true && all[1].placeholderShown) {
                try await Task.sleep(for: .milliseconds(50))
                all = try await figures(harness)
            }
            #expect(all[1].src == "frusexplorer://figure/frus1946v01/figure_1163.png?retry=1", "\(all[1])")
            // The third was refused and never asked for again. Both keep their placeholders.
            #expect(all[2].src == "frusexplorer://figure/frus1946v01/figure_1166.png", "\(all[2])")
            #expect(all.dropFirst().allSatisfy { !$0.imageShown && $0.placeholderShown }, "\(all)")
            // Each image asked for once: the retry's own request starts no second fetch.
            #expect(await asked.values.sorted() == [
                "frus1946v01/figure_1162.png", "frus1946v01/figure_1163.png", "frus1946v01/figure_1166.png",
            ])
        }
    }

    /// `renderingVersion` hashes only the converter's flat text, so it cannot see a caption, a
    /// placeholder or a drawn space that reaches the DOM outside a `data-skip` element: the hash
    /// would stay put while the offset engine counted the text, and every highlight after it would
    /// be misplaced. Only this parity catches that.
    @Test("Swift and JS agree on the flat text of real figures and of the drawn spaces, which are drawn under data-skip")
    func flatTextParity() async throws {
        let cases: [(fixture: String, volume: String, drawn: [String], flat: String)] = [
            (FigureFixtures.d587, "frus1946v01", ["Locations at Which Military Air Transit", "[Figure]"], "Azores"),
            (FigureFixtures.d289, "frus1951v03p1", ["W. Averell Harriman", "[Figure]"], "General Marshall"),
            (FigureFixtures.d77, "frus1969-76ve16", ["CHILE: Cost of Living Indexes", "Figure 2"], "A strict price freeze"),
            (FigureFixtures.d278, "frus1943CairoTehran", ["Notes by Hopkins"], "Generalissimo"),
            (FigureFixtures.d178, "frus1897", ["[Figure]"], "Case  17"),
            (FigureFixtures.appendix1, "frus1917-72PubDipv06", ["Reel 1", "Watch on history.state.gov"], "[MUSIC PLAYING]"),
            (FigureFixtures.d2, "frus1861", [], "Washington,February 28, 1861."),
        ]
        for (fixture, volume, drawn, flatNeedle) in cases {
            let model = try await ListShapeFixtures.renderModel(
                fixture, converter: ASTToRenderNodeConverter(volumeId: volume))
            let harness = OffsetEngineTestHarness()
            try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
            let swift = buildFlatText(from: model)
            let js = try await harness.evalFlatText()
            #expect(swift == js, "Swift/JS flat text diverged on \(model.documentId) of \(volume)")
            #expect(swift.contains(flatNeedle), "\(flatNeedle) must be flat text in \(model.documentId): \(swift)")
            let skipped = try #require(try await harness.evaluateString("""
                Array.from(document.querySelectorAll('.frus-document [data-skip="1"]')).map(e => e.textContent).join('\\u0001')
                """))
            for text in drawn {
                #expect(skipped.contains(text), "\(text) is not drawn under data-skip in \(model.documentId)")
                #expect(!swift.contains(text), "\(text) entered the Swift flat text of \(model.documentId)")
            }
        }
        // d2's three drawn spaces — after a place name, a term and a footnote's marker.
        let d2 = try await ListShapeFixtures.renderModel(FigureFixtures.d2)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: d2, colorScheme: .light))
        let spaces = try await harness.evaluateString(
            "String(document.querySelectorAll('.frus-document span.element-space[data-skip]').length)")
        #expect(spaces == "3", "d2 draws a space after Washington, after SecState and after its footnote's marker")
        let line = try await harness.evaluateString("document.querySelector('p.dateline').innerText")
        #expect(line?.contains("Washington, February 28, 1861.") == true, "\(line ?? "")")
    }

    @Test("A figure inside a sentence leaves its paragraph whole when the page is parsed")
    func figureInsideAParagraphDoesNotSplitIt() async throws {
        let model = try await ListShapeFixtures.renderModel(
            FigureFixtures.d77, converter: ASTToRenderNodeConverter(volumeId: "frus1969-76ve16"))
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        // Parsed, not serialized: a <figure> start tag inside the <p> would have closed it, leaving
        // "A strict price freeze" outside every paragraph.
        let report = try await harness.evaluateString("""
            JSON.stringify(Array.from(document.querySelectorAll('.frus-document > p.body')).map(p => p.textContent))
            """)
        let paragraphs = try JSONDecoder().decode([String].self, from: Data((report ?? "[]").utf8))
        #expect(paragraphs.count == 2, "d77 has two paragraphs: \(paragraphs)")
        let first = try #require(paragraphs.first)
        #expect(first.contains("popular support.") && first.contains("A strict price freeze"),
                "the sentence was split around its figure: \(paragraphs)")
        let loose = try await harness.evaluateString("""
            Array.from(document.querySelector('.frus-document').childNodes)
              .filter(n => n.nodeType === Node.TEXT_NODE).map(n => n.nodeValue).join('|')
            """)
        #expect(loose == "", "text fell out of its paragraph: \(loose ?? "")")
    }

    /// The UTF-16 offset of `needle` in `flat`.
    private func offset(of needle: String, in flat: String) throws -> Int {
        let range = try #require(flat.range(of: needle), "\"\(needle)\" is not in the flat text")
        return flat.utf16.distance(from: flat.utf16.startIndex, to: range.lowerBound)
    }

    /// Sets the page's selection between two JS-expressed boundary points and returns the payload
    /// the production bridge posts.
    ///
    /// The wait is 20 seconds, not the harness's 5: it starts before the script runs, and in the
    /// first run of a newly built test host, with twelve suites running, 5 was not enough once
    /// (iPhone 17, iOS 26.4: "the selection bridge posted nothing"; the next three runs passed).
    private func select(_ harness: OffsetEngineTestHarness, from start: String, _ startOffset: String,
                        to end: String, _ endOffset: String) async throws -> SelectionPayload? {
        try await harness.selectionPayload(timeout: .seconds(20)) {
            let result = try await harness.evaluateString("""
                (() => {
                  const a = \(start);
                  const b = \(end);
                  if (!a || !b) return 'an endpoint node is not on the page';
                  getSelection().removeAllRanges();
                  getSelection().setBaseAndExtent(a, \(startOffset), b, \(endOffset));
                  return 'ok';
                })()
                """)
            #expect(result == "ok", "\(result ?? "the script returned nothing")")
        }
    }

    /// A JS expression: the first text node holding `needle` anywhere in the document's body.
    private func textNode(_ needle: String) -> String {
        """
        (() => {
          const walker = document.createTreeWalker(document.querySelector('.frus-document'), NodeFilter.SHOW_TEXT);
          let t = walker.nextNode();
          while (t && !t.nodeValue.includes('\(needle)')) t = walker.nextNode();
          return t;
        })()
        """
    }

    @Test("A selection that starts on a figure's caption starts at the first letter after the figure, highlightably")
    func selectionStartingOnACaption() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d289)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        let flat = buildFlatText(from: model)
        let payload = try await select(harness, from: textNode("W. Averell Harriman"), "3",
                                       to: textNode("I have discussed"), "16")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "start \(selection.start), end \(selection.end) for \"\(selection.text)\": took the footnote branch")
        let after = try offset(of: "I have discussed the matter", in: flat)
        #expect(selection.start == after, "a start on a caption must move to the first letter after its figure")
        #expect(selection.end == after + 16)
    }

    @Test("A selection that ends on the space drawn between two inline elements ends before the next word")
    func selectionEndingOnADrawnSpace() async throws {
        let model = try await ListShapeFixtures.renderModel(FigureFixtures.d2)
        let harness = OffsetEngineTestHarness()
        try await harness.load(HTMLTemplate.build(model: model, colorScheme: .light))
        let flat = buildFlatText(from: model)
        let space = "document.querySelector('p.dateline span.element-space').firstChild"
        let payload = try await select(harness, from: textNode("Washington"), "0", to: space, "1")
        let selection = try #require(payload, "the selection bridge posted nothing")
        #expect(selection.hasOffsets,
                "start \(selection.start), end \(selection.end) for \"\(selection.text)\": took the footnote branch")
        #expect(selection.start == (try offset(of: "Washington,", in: flat)))
        #expect(selection.end == (try offset(of: "February 28, 1861", in: flat)),
                "the drawn space is no flat text: the selection ends at the next word's first letter")
        // What the reader copies has the space; what a highlight stores is the flat text.
        #expect(selection.text == "Washington, ")
    }
}

// MARK: - HighlightTextRenderTests (#1602)

/// What WebKit computes for text inside one of the reader's highlights (#1602).
///
/// `ReaderPageTests` reads the stylesheet as text: each `::highlight(frus-…)` rule names
/// `--color-highlight-text`, and that colour is at least 4.5:1 over every tint. Neither says the
/// engine applies a `color` written with a variable inside `::highlight()`. If it did not, the
/// declaration would be dropped, a link in a highlight would keep its own colour, and every
/// arithmetic test would still pass. So this loads the real variables and stylesheet in the
/// reader's web view, highlights a link, a person's name and plain text through the CSS Custom
/// Highlight API the reader uses, and asks the page what colour each is drawn in.
///
/// Measured first outside the app, in WebKit on macOS 27.0.1, where a snapshot's pixels agreed
/// with these computed values: a link in a highlight was painted rgb(0,124,213) with no colour
/// rule and rgb(29,40,50) with one.
///
/// Version history:
///   1.0 — 2026-10-09: #1602 — initial implementation
@Suite("Text inside a reader highlight is drawn in the highlight text colour, in a web view (#1602)")
@MainActor
struct HighlightTextRenderTests {

    /// What the page reports for one element.
    private struct Drawn: Decodable {
        /// The element's own colour, outside any highlight.
        let own: String
        /// The colour of its text inside the highlight.
        let highlighted: String
        /// The highlight's tint.
        let tint: String
        /// The colour reported for a highlight no rule names: the element's own.
        let unnamed: String
    }

    /// The reader's variables and stylesheet around a paragraph holding a cross-reference, a
    /// person's name and plain text, as the serializer writes each.
    private static func page(_ appearance: ReaderAppearance) -> String {
        """
        <!DOCTYPE html><html><head><style>
        \(ReaderPage.cssVariables(appearance: appearance))
        \(ReaderPage.documentCSS)
        </style></head><body><div class="frus-document"><p class="body">See \
        <a class="cross-ref" id="link" href="#">Document 12</a>, sent by \
        <a class="pers-name" id="person" href="#">Kennan</a> <span id="plain">from Moscow</span>.</p></div></body></html>
        """
    }

    private static let script = """
    (() => {
      const ids = ['link', 'person', 'plain'];
      const ranges = ids.map(id => { const r = new Range(); r.selectNodeContents(document.getElementById(id)); return r; });
      CSS.highlights.set('frus-blue', new Highlight(...ranges));
      const out = {};
      for (const id of ids) {
        const el = document.getElementById(id);
        const inside = getComputedStyle(el, '::highlight(frus-blue)');
        out[id] = { own: getComputedStyle(el).color, highlighted: inside.color, tint: inside.backgroundColor,
                    unnamed: getComputedStyle(el, '::highlight(frus-no-such-colour)').color };
      }
      return JSON.stringify(out);
    })()
    """

    @Test("A link, a person's name and plain text in a highlight are all drawn in the highlight text colour, in both palettes")
    func highlightedTextTakesTheHighlightTextColour() async throws {
        let expected: [ReaderAppearance: (text: String, link: String, person: String)] = [
            .light: ("rgb(0, 0, 0)", "rgb(0, 102, 204)", "rgb(0, 121, 107)"),
            .dark: ("rgb(255, 255, 255)", "rgb(64, 156, 255)", "rgb(0, 179, 161)"),
        ]
        for appearance in ReaderAppearance.allCases {
            let harness = OffsetEngineTestHarness()
            try await harness.load(Self.page(appearance))
            let raw = try #require(try await harness.evaluateString(Self.script), "\(appearance): the page returned nothing")
            let drawn = try JSONDecoder().decode([String: Drawn].self, from: Data(raw.utf8))
            let want = try #require(expected[appearance])
            let link = try #require(drawn["link"]), person = try #require(drawn["person"]), plain = try #require(drawn["plain"])

            // Outside a highlight the two links have the colours #1602 measured over the tints.
            #expect(link.own == want.link, "\(appearance): the cross-reference's own colour is \(link.own)")
            #expect(person.own == want.person, "\(appearance): the person's own colour is \(person.own)")
            // Inside one, all three are the highlight text colour.
            for (name, element) in [("the cross-reference", link), ("the person's name", person), ("plain text", plain)] {
                #expect(element.highlighted == want.text,
                        "\(appearance): \(name) in a highlight is drawn in \(element.highlighted)")
                #expect(element.tint == "rgba(0, 122, 255, 0.4)", "\(appearance): the highlight's tint is \(element.tint)")
                // The reading is of the rule: a highlight no rule names reports the element's own colour.
                #expect(element.unnamed == element.own,
                        "\(appearance): an unnamed highlight reports \(element.unnamed), not the element's \(element.own)")
            }
        }
    }
}
