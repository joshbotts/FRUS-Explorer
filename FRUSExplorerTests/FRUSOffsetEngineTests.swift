// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
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
            .figureBlock(altText: "Map of South-East Asia"),
            .paragraph([.plainText("After figure.")])
        ])
        let swift = buildFlatText(from: m)
        let js    = try await jsFlatText(for: m)
        // Figure alt text must NOT appear in flat text
        #expect(!swift.contains("Map"))
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
        let m = model(body: [.tableBlock(rows: cells)])
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
                .figureBlock(altText: "Invisible figure")   // invisible
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
}

// MARK: - ListLabelSelectionTests (#1371)

/// A selection whose start or end falls inside an offset-invisible (`data-skip`) node maps to −1
/// in `kSelectionJS`, so the selection bar treats it as a footnote selection and disables
/// Highlight and Excerpt. A drag from the left edge of a numbered item commonly starts on its
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

    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?

    /// The production message handler the page's scripts post to. Kept (#1371) so a test can
    /// read the `selectionChanged` payload the real bridge sends — see
    /// ``selectionPayload(timeout:after:)``. Nothing else in the harness reads it.
    let coordinator: _FRUSWebViewCoordinator

    /// Builds an 800×600 web view on the production configuration, delegating to `self`.
    override init() {
        // A coordinator with no callbacks set satisfies the messageHandler requirement; a test
        // that wants the selection payload sets `onSelectionChanged` through
        // `selectionPayload(timeout:after:)`.
        let stubCoordinator = _FRUSWebViewCoordinator()
        coordinator = stubCoordinator
        let config = WKWebViewConfiguration.frusExplorerConfiguration(
            schemeHandler:  FRUSURLSchemeHandler(),
            messageHandler: stubCoordinator
        )
        // Give the web view a concrete frame so WebKit allocates a proper
        // rendering surface for script execution.
        webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            configuration: config
        )
        super.init()
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
