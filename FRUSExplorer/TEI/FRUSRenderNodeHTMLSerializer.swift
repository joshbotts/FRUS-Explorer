// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FRUSRenderNodeHTMLSerializer

/// Converts a `FRUSDocumentRenderModel` into a self-contained HTML fragment.
///
/// ## Output structure
/// ```html
/// <div class="frus-document">
///   <!-- body nodes -->
///   <!-- footnote <aside popover> elements (if any) -->
/// </div>
/// ```
/// The output contains no `<html>`, `<head>`, or `<body>` wrappers — it is
/// designed to be embedded inside an HTML template supplied by
/// `FRUSDocumentWebView` (Session 141).
///
/// ## Offset compatibility
/// Elements that `ASTToRenderNodeConverter.flatText()` skips are emitted with
/// `data-skip="1"` so the JavaScript flat-text DFS (Session 143) mirrors the
/// Swift traversal rules exactly:
///
/// | Skipped element    | HTML output                        |
/// |--------------------|------------------------------------|
/// | `.pageBreak`       | `<span data-skip="1" …>`           |
/// | `.footnoteMarker`  | `<button data-skip="1" …>`         |
/// | `.figureBlock`     | `<figure data-skip="1" …>`         |
/// | `.footnoteBody`    | `<aside data-skip="1" …>`          |
///
/// `.lineBreak` contributes `"\n"` in Swift and is emitted as `<br>` (no
/// `data-skip`) so the JS engine also counts it as a newline character.
///
/// ## Footnote popovers
/// The HTML Popover API (Safari 17+, no JavaScript required) handles show/hide,
/// focus trapping, and light-dismiss natively:
/// ```html
/// <!-- inline marker in body -->
/// <button class="fn-marker" data-skip="1" popovertarget="fn-1">1</button>
/// <!-- aside at end of .frus-document -->
/// <aside class="footnote fn-footnote" id="fn-1" popover data-skip="1">…</aside>
/// ```
///
/// ## Interactive links
/// persName, gloss, and cross-reference links are emitted with `frusexplorer://`
/// custom URLs, dispatched by `FRUSURLSchemeHandler` (Session 142).
///
/// ## Relation to HTMLCollectionExporter
/// Session 146 will refactor `HTMLCollectionExporter` to delegate document-body
/// rendering to this type, eliminating the divergent HTML-generation paths.
///
/// Version history:
///   1.0 — Session 140: initial implementation
public struct FRUSRenderNodeHTMLSerializer {

    public init() {}

    // MARK: - Public API

    /// Serialises `model` to an HTML fragment string.
    ///
    /// The returned string is a `<div class="frus-document">` element containing
    /// the document body followed by all footnote `<aside popover>` elements.
    public func serialize(_ model: FRUSDocumentRenderModel) -> String {
        // IMPORTANT: no whitespace is added between elements. Any inter-element
        // newline or space creates a DOM text node that the JS flat-text DFS
        // (frus-offset-engine.js) would count as a character, breaking the
        // Swift–JS offset equivalence. All formatting whitespace is deliberately
        // omitted to keep the DOM clean.
        var html = "<div class=\"frus-document\">"

        for node in model.bodyNodes {
            html += nodeToHTML(node)
        }
        for footnote in model.footnotes {
            html += footnoteAsideHTML(footnote)
        }

        html += "</div>"
        return html
    }

    // MARK: - Node Rendering

    /// Recursively converts a single `FRUSRenderNode` to an HTML string.
    ///
    /// ## Whitespace policy
    /// No formatting whitespace (newlines, indentation) is inserted between or
    /// around elements. Every inter-element `\n` or space would create a DOM text
    /// node that `frus-offset-engine.js` counts as a character, breaking the
    /// Swift–JS offset equivalence. All HTML is deliberately compact.
    ///
    /// The only `\n` characters in the output are those explicitly contributed by
    /// `.lineBreak` nodes (via `<br>` elements) — exactly matching the Swift DFS
    /// which appends `"\n"` only for `.lineBreak`.
    private func nodeToHTML(_ node: FRUSRenderNode) -> String {
        switch node {

        // MARK: Block elements — no trailing newline (whitespace = spurious text node)

        case .heading(let children):
            return "<h2 class=\"doc-heading\">\(inline(children))</h2>"

        case .dateline(let children):
            return "<p class=\"dateline\">\(inline(children))</p>"

        case .paragraph(let children):
            return "<p class=\"body\">\(inline(children))</p>"

        case .letterOpener(let children):
            return "<div class=\"letter-opener\">\(inline(children))</div>"

        case .letterCloser(let children):
            return "<div class=\"letter-closer\">\(inline(children))</div>"

        case .salutation(let children):
            return "<p class=\"salutation\">\(inline(children))</p>"

        case .editorialNoteBlock(let children):
            return "<div class=\"editorial-note\" role=\"note\">\(block(children))</div>"

        case .titlePageBlock(let children):
            return "<div class=\"title-page\">\(block(children))</div>"

        case .attachmentBlock(let n, let children):
            let attr = n.map { " data-n=\"\(escaped($0))\"" } ?? ""
            return "<section class=\"attachment\"\(attr)>\(block(children))</section>"

        case .attachmentHeading(let children):
            return "<h3 class=\"attachment-heading\">\(inline(children))</h3>"

        case .tableBlock(let rows):
            // No whitespace between table elements — every character inside
            // <table> that is not inside a <td> is a spurious text node.
            var t = "<table class=\"frus-table\">"
            for row in rows {
                t += "<tr>"
                for cell in row {
                    var attrs = " class=\"frus-cell\""
                    if cell.rowSpan > 1 { attrs += " rowspan=\"\(cell.rowSpan)\"" }
                    if cell.colSpan > 1 { attrs += " colspan=\"\(cell.colSpan)\"" }
                    t += "<td\(attrs)>\(inline(cell.children))</td>"
                }
                t += "</tr>"
            }
            t += "</table>"
            return t

        case .listBlock(let type, let items):
            let tag: String
            let extraClass: String
            switch type {
            case "ordered":  tag = "ol"; extraClass = ""
            case "simple":   tag = "ul"; extraClass = " simple"
            default:         tag = "ul"; extraClass = ""
            }
            // No whitespace between <ul>/<ol> and <li> elements.
            let inner = items.map { "<li>\(inline($0))</li>" }.joined()
            return "<\(tag) class=\"frus-list\(extraClass)\">\(inner)</\(tag)>"

        // MARK: Inline elements

        case .plainText(let text):
            return escaped(text)

        case .boldText(let children):
            return "<strong>\(inline(children))</strong>"

        case .italicText(let children):
            return "<em>\(inline(children))</em>"

        case .smallCapsText(let children):
            return "<span class=\"small-caps\">\(inline(children))</span>"

        case .underlineText(let children):
            return "<span class=\"underline\">\(inline(children))</span>"

        case .termText(let children):
            return "<span class=\"term\">\(inline(children))</span>"

        case .suppliedText(let children):
            return "<span class=\"supplied\">[\(inline(children))]</span>"

        case .sicText(let children):
            return "<s class=\"sic\">\(inline(children))</s>"

        case .corrText(let children):
            return "<span class=\"corr\">\(inline(children))</span>"

        case .formulaText(let text):
            return "<em class=\"formula\">\(escaped(text))</em>"

        case .lineBreak:
            // <br> contributes "\n" to flat text — the JS walker handles
            // <br> specially, emitting "\n". No trailing whitespace here.
            return "<br>"

        // MARK: Offset-invisible leaf elements (data-skip="1")

        case .pageBreak(let number):
            let label = pageLabel(number)
            return "<span class=\"page-break\" data-skip=\"1\" data-page=\"\(escaped(label))\"></span>"

        case .figureBlock(let altText):
            if let alt = altText, !alt.isEmpty {
                return "<figure data-skip=\"1\"><figcaption>\(escaped(alt))</figcaption></figure>"
            } else {
                return "<figure data-skip=\"1\"></figure>"
            }

        case .footnoteMarker(_, let label):
            // data-skip="1" — marker text is excluded from flat-text offset count.
            // aria-label provides a meaningful VoiceOver announcement ("Footnote 1").
            return "<button class=\"fn-marker\" data-skip=\"1\" popovertarget=\"fn-\(escaped(label))\" aria-label=\"Footnote \(escaped(label))\">\(escaped(label))</button>"

        case .footnoteBody:
            // Footnote bodies appear in model.footnotes, not model.bodyNodes.
            // If one appears here via an unexpected path, render it as an aside.
            return footnoteAsideHTML(node)

        // MARK: Interactive links

        case .persNameLink(let ref, let children, _):
            let href = ref.map { "frusexplorer://person/\(urlEncoded($0.hasPrefix("#") ? String($0.dropFirst()) : $0))" } ?? "#"
            return "<a class=\"pers-name\" href=\"\(href)\">\(inline(children))</a>"

        case .glossLink(let ref, let children, _):
            let href = ref.map { "frusexplorer://gloss/\(urlEncoded($0.hasPrefix("#") ? String($0.dropFirst()) : $0))" } ?? "#"
            return "<a class=\"gloss\" href=\"\(href)\">\(inline(children))</a>"

        case .crossRefLink(let target, let volumeId, let children):
            // URL: frusexplorer://doc/{target}/{volumeId} (target first so
            // FRUSURLSchemeHandler can extract it as pathComponents[0]).
            let path: String
            if let vol = volumeId, !vol.isEmpty {
                path = "\(urlEncoded(target))/\(urlEncoded(vol))"
            } else {
                path = urlEncoded(target)
            }
            return "<a class=\"cross-ref\" href=\"frusexplorer://doc/\(path)\">\(inline(children))</a>"

        // MARK: Unknown / passthrough

        case .unknown(let name, let children):
            return "<span class=\"unknown\" data-element-name=\"\(escaped(name))\">\(inline(children))</span>"
        }
    }

    // MARK: - Footnote Aside

    /// Renders a `footnoteBody` node as an `<aside popover>` element.
    ///
    /// Called for nodes in `model.footnotes`. `data-skip="1"` marks the aside
    /// as offset-invisible so the JS flat-text engine excludes its text.
    private func footnoteAsideHTML(_ node: FRUSRenderNode) -> String {
        guard case .footnoteBody(_, let type, _, _, let label, let children) = node else {
            return ""
        }
        let typeClass = footnoteTypeClass(type)
        // No whitespace inside or after the aside — it has data-skip="1" so the
        // JS walker skips the element, but sibling text nodes (e.g. "\n" after
        // </aside>) ARE visible to the walker and would cause mismatches.
        return "<aside class=\"footnote \(typeClass)\" id=\"fn-\(escaped(label))\" popover data-skip=\"1\">\(block(children))</aside>"
    }

    // MARK: - Aggregation Helpers

    /// Renders an array of nodes as concatenated HTML (inline context).
    private func inline(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { nodeToHTML($0) }.joined()
    }

    /// Renders an array of nodes as concatenated HTML (block context, no separator).
    private func block(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { nodeToHTML($0) }.joined()
    }

    // MARK: - Type Helpers

    private func footnoteTypeClass(_ type: FootnoteType) -> String {
        switch type {
        case .footnote:      return "fn-footnote"
        case .editorial:     return "fn-editorial"
        case .source:        return "fn-source"
        case .unclassified:  return "fn-unclassified"
        }
    }

    private func pageLabel(_ number: PageNumber) -> String {
        switch number {
        case .arabic(let n):       return "\(n)"
        case .roman(let n):        return "\(n)"
        case .prefixed(let s):     return s
        case .unparseable(let s):  return s
        }
    }

    // MARK: - String Escaping

    /// HTML-escapes the five characters that are special in HTML text and attributes.
    private func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'",  with: "&#39;")
    }

    /// Percent-encodes a string for inclusion in a URL path component.
    private func urlEncoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
    }
}
