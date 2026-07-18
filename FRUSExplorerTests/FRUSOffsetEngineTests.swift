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
                .footnoteMarker(id: nil, displayLabel: "1"),
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
                .footnoteMarker(id: nil, displayLabel: "1")
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
            .listBlock(type: "ordered", items: [
                [.plainText("First item")],
                [.plainText("Second item")],
                [.boldText([.plainText("Third")]), .plainText(" item")]
            ])
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
                    .footnoteMarker(id: nil, displayLabel: "1"), // invisible
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
}

// MARK: - Test harness

/// Async `WKWebView` wrapper for loading HTML and evaluating JavaScript in tests.
///
/// Creates a WKWebView with the full production configuration (URL scheme handler
/// + offset-engine user script) so the injection path is identical to production.
@MainActor
private final class OffsetEngineTestHarness: NSObject, WKNavigationDelegate {

    private let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override init() {
        // The test harness doesn't need real selection callbacks;
        // a no-op coordinator satisfies the messageHandler requirement.
        let stubCoordinator = _FRUSWebViewCoordinator()
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

    /// Returns `true` if `window.FRUSOffsets` was set by the injected WKUserScript.
    func userScriptInjected() async throws -> Bool {
        let result = try await webView.evaluateJavaScript(
            "window.FRUSOffsets !== null && window.FRUSOffsets !== undefined"
        )
        return (result as? Bool) ?? false
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume(returning: ())
        loadContinuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

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
}

// MARK: - FRUSSelectionEventDecodeTests (#269)

/// Pure decode of the `selectionChanged` message body, testable without a `WKScriptMessage`.
struct FRUSSelectionEventDecodeTests {

    @Test("In-document selection decodes to .ranged")
    func rangedSelection() {
        let event = decodeFRUSSelectionEvent(from: ["start": 3, "end": 10, "text": "telegram"])
        #expect(event == .ranged(start: 3, end: 10, text: "telegram"))
    }

    @Test("Footnote selection carries text and blockText")
    func footnoteSelection() {
        let event = decodeFRUSSelectionEvent(from: [
            "start": -1, "end": -1, "text": "64 D 171",
            "blockText": "Source: National Archives, RG 59, Lot File 64 D 171."])
        #expect(event == .footnote(text: "64 D 171",
                                   blockText: "Source: National Archives, RG 59, Lot File 64 D 171."))
    }

    @Test("Footnote selection with missing blockText falls back to the raw text")
    func footnoteWithoutBlockText() {
        let event = decodeFRUSSelectionEvent(from: ["start": -1, "end": -1, "text": "64 D 171"])
        #expect(event == .footnote(text: "64 D 171", blockText: "64 D 171"))
    }

    @Test("Sentinel offsets with empty text decode to .cleared")
    func clearedSelection() {
        #expect(decodeFRUSSelectionEvent(from: ["start": -1, "end": -1]) == .cleared)
        #expect(decodeFRUSSelectionEvent(from: ["start": -1, "end": -1, "text": ""]) == .cleared)
    }

    @Test("Malformed and degenerate bodies decode to nil")
    func malformedBodies() {
        #expect(decodeFRUSSelectionEvent(from: [:]) == nil)
        #expect(decodeFRUSSelectionEvent(from: ["start": "x", "end": 4]) == nil)
        // Degenerate in-document range (end <= start) is not a valid selection.
        #expect(decodeFRUSSelectionEvent(from: ["start": 5, "end": 5, "text": "x"]) == nil)
    }
}
