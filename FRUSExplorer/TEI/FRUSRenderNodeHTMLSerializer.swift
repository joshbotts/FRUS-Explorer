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
///   1.1 — Session 2026-07-04 (Source Explorer Phase 5 step 1): opt-in classification
///          chips. When `annotateSourceClassification` is `true` (the reading views,
///          via `HTMLTemplate.build`), each `.source` footnote whose text carries a
///          classification-markings sentence (`SourceNoteParser.classificationMarking`)
///          gets a quiet `<span class="classification-chip">` appended — in both the
///          popover aside (already `data-skip="1"`) and the visible footnotes section
///          (outside the offset engine's DFS root), so flat-text offsets and existing
///          highlights are untouched. Default `false` keeps every export byte-identical.
///   1.2 — Session 7 / #240B: broken cross-references (non-nil `broken` payload) emit a
///          non-navigable `frusexplorer://brokenref/` explained span — dotted underline,
///          muted colour, and a `data-skip="1"` dagger so highlight offsets never shift.
public struct FRUSRenderNodeHTMLSerializer {

    /// When `true`, `.source` footnotes are annotated with a classification chip
    /// (see the version-1.1 note above). Reading views pass `true`; exports keep
    /// the default `false` so exported HTML/PDF/DOCX output is unchanged.
    private let annotateSourceClassification: Bool

    /// Creates a serializer.
    ///
    /// - Parameter annotateSourceClassification: Whether `.source` footnotes get a
    ///   classification-markings chip. Default `false` (exports).
    public init(annotateSourceClassification: Bool = false) {
        self.annotateSourceClassification = annotateSourceClassification
    }

    // MARK: - Public API

    /// Serialises `model` to an HTML fragment string.
    ///
    /// The returned string is a `<div class="frus-document">` element followed
    /// by an optional `<section class="footnotes-section">` for visible footnote
    /// display.
    ///
    /// ## Footnote rendering (dual representation)
    /// Footnotes are rendered in two complementary ways:
    ///
    /// 1. **Popover** (`<aside popover data-skip="1">`) — emitted inside
    ///    `.frus-document`. Browser-native: clicking the `<button popovertarget>`
    ///    marker shows a floating card near the insertion point. Has `data-skip="1"`
    ///    so the JS offset engine excludes its text from the character count.
    ///
    /// 2. **Visible section** (`<section class="footnotes-section">`) — emitted
    ///    *outside* `.frus-document` as a traditional numbered list visible at
    ///    the bottom of the document. Because it is outside the DFS root, the JS
    ///    flat-text offset engine does not walk it and the character offsets are
    ///    unaffected.
    ///
    /// Both representations exist simultaneously. Users can click a marker for the
    /// inline popup view or scroll to the section for reading in context.
    public func serialize(_ model: FRUSDocumentRenderModel) -> String {
        serialize(model, includeFootnotes: true, highlights: [])
    }

    /// Serialises `model` with optional footnote suppression and inline highlight annotation.
    ///
    /// - Parameters:
    ///   - model: The render model to serialise.
    ///   - includeFootnotes: When `false`, all `<aside>` popover elements and the
    ///     `<section class="footnotes-section">` are omitted from the output.
    ///     Use `false` when the export handles footnotes separately (e.g. source-note-only mode).
    ///   - highlights: Flat-text character ranges to annotate with `<mark>` elements.
    ///     The serialiser injects highlight markup by post-processing the rendered HTML
    ///     using the same flat-text coordinate space as the JS offset engine.
    func serialize(
        _ model: FRUSDocumentRenderModel,
        includeFootnotes: Bool,
        highlights: [ExportHighlight]
    ) -> String {
        // IMPORTANT: no whitespace is added between elements. Any inter-element
        // newline or space creates a DOM text node that the JS flat-text DFS
        // (frus-offset-engine.js) would count as a character, breaking the
        // Swift–JS offset equivalence. All formatting whitespace is deliberately
        // omitted to keep the DOM clean.
        var html = "<div class=\"frus-document\">"

        for node in model.bodyNodes {
            html += nodeToHTML(node)
        }

        if includeFootnotes {
            // Footnote popovers (inline popup behavior) — inside .frus-document,
            // marked data-skip="1" so the offset engine skips them.
            for footnote in model.footnotes {
                html += footnoteAsideHTML(footnote)
            }
        }

        html += "</div>"

        if includeFootnotes, !model.footnotes.isEmpty {
            html += footnoteSectionHTML(model.footnotes)
        }

        // Inject inline highlight annotations if any were requested.
        if !highlights.isEmpty {
            html = injectHighlights(into: html, highlights: highlights)
        }

        return html
    }

    // MARK: - Highlight Injection

    /// Injects `<mark class="hl-{color}">` elements into a serialised HTML string.
    ///
    /// The algorithm walks the HTML character by character, tracking a `flatPos`
    /// counter that increments for each character that would appear in the JS offset
    /// engine's flat text (i.e. real text characters; HTML tags and entities count as
    /// zero or one respectively). At each highlight boundary the algorithm inserts
    /// `<mark>` or `</mark>` tags.
    ///
    /// Limitations of the post-processing approach:
    /// - A highlight that spans across an HTML element boundary (e.g. `<em>`) will
    ///   have its mark split across the element, which is valid HTML.
    /// - Overlapping highlights are handled by prioritising the one that opens first.
    func injectHighlights(into html: String, highlights: [ExportHighlight]) -> String {
        // Sort highlights by start offset ascending for clean insertion.
        let sorted = highlights.sorted { $0.startOffset < $1.startOffset }
        guard !sorted.isEmpty else { return html }

        var result   = ""
        var flatPos  = 0           // position in the flat-text coordinate space
        var idx      = html.startIndex
        var openIdx  = 0           // which highlight is currently open (-1 = none)
        var openEnd  = -1
        var openCSS  = ""

        func cssClass(_ color: DocumentHighlight.Color) -> String {
            "hl-\(color.rawValue)"
        }

        while idx < html.endIndex {
            let ch = html[idx]

            // ── Inside an HTML tag — copy verbatim, don't advance flatPos ──
            if ch == "<" {
                var tagEnd = idx
                // Scan to closing `>`
                while tagEnd < html.endIndex && html[tagEnd] != ">" {
                    tagEnd = html.index(after: tagEnd)
                }
                if tagEnd < html.endIndex { tagEnd = html.index(after: tagEnd) }
                result += html[idx..<tagEnd]
                idx = tagEnd
                continue
            }

            // ── HTML entity — counts as 1 flat-text character ──
            if ch == "&" {
                var entEnd = idx
                while entEnd < html.endIndex && html[entEnd] != ";" {
                    entEnd = html.index(after: entEnd)
                }
                if entEnd < html.endIndex { entEnd = html.index(after: entEnd) }
                let entity = String(html[idx..<entEnd])

                // Open highlights at this position if needed
                if openEnd < 0 {
                    for (i, hl) in sorted.enumerated() where hl.startOffset == flatPos {
                        result += "<mark class=\"\(cssClass(hl.color))\">"
                        openIdx = i; openEnd = hl.endOffset; openCSS = cssClass(hl.color)
                        break
                    }
                }

                result += entity
                flatPos += 1
                idx = entEnd

                if openEnd == flatPos {
                    result += "</mark>"; openEnd = -1; openCSS = ""
                }
                continue
            }

            // ── Regular text character ──
            // Open a highlight if one starts here
            if openEnd < 0 {
                for (i, hl) in sorted.enumerated() where hl.startOffset == flatPos {
                    result += "<mark class=\"\(cssClass(hl.color))\">"
                    openIdx = i; openEnd = hl.endOffset; openCSS = cssClass(hl.color)
                    break
                }
            }

            result += String(ch)
            flatPos += 1
            idx = html.index(after: idx)

            // Close a highlight if it ends here
            if openEnd == flatPos {
                result += "</mark>"; openEnd = -1; openCSS = ""
            }
        }

        // Close any highlight still open at end of document
        if openEnd >= 0 { result += "</mark>" }

        return result
    }

    /// CSS for the five highlight colours. Embed in the export stylesheet.
    public static let highlightCSS = """
    mark.hl-yellow   { background: rgba(255,230, 50,0.45); color: inherit; }
    mark.hl-green    { background: rgba( 80,200, 80,0.35); color: inherit; }
    mark.hl-blue     { background: rgba( 80,150,240,0.35); color: inherit; }
    mark.hl-pink     { background: rgba(240, 80,160,0.30); color: inherit; }
    mark.hl-orange   { background: rgba(255,160, 30,0.40); color: inherit; }
    """

    /// Renders a traditional numbered footnote section for visible display below
    /// the document body. This section is outside `.frus-document` and therefore
    /// excluded from the JS flat-text offset engine.
    private func footnoteSectionHTML(_ footnotes: [FRUSRenderNode]) -> String {
        var html = "<section class=\"footnotes-section\"><hr class=\"fn-rule\"><h2 class=\"fn-section-heading\">Footnotes</h2><ol class=\"fn-list\">"
        for footnote in footnotes {
            guard case .footnoteBody(_, let type, _, _, let label, let children) = footnote else { continue }
            html += "<li class=\"fn-list-item\" id=\"fnote-\(escaped(label))\"><span class=\"fn-list-label\">\(escaped(label))</span>"
            html += block(children)
            // The footnotes section sits outside .frus-document (the offset engine's
            // DFS root), so the chip cannot perturb flat-text offsets.
            html += classificationChipHTML(type: type, children: children)
            html += "</li>"
        }
        html += "</ol></section>"
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

        case .crossRefLink(let target, let volumeId, let broken, let children):
            // URL: frusexplorer://doc/{target}/{volumeId} (target first so
            // FRUSURLSchemeHandler can extract it as pathComponents[0]).
            let path: String
            if let vol = volumeId, !vol.isEmpty {
                path = "\(urlEncoded(target))/\(urlEncoded(vol))"
            } else {
                path = urlEncoded(target)
            }
            if let broken {
                // A dead reference (issue #240): still an <a> so the tap is captured, but the
                // `brokenref` host routes to the explanation sheet and never navigates a document.
                // Dotted underline + muted colour + a data-skip'd marker glyph is a non-colour-only
                // affordance. The marker MUST carry data-skip="1" so the JS flat-text walker doesn't
                // count it and shift every downstream highlight offset.
                //
                // The target is encoded with the strict alphanumeric charset (NOT urlPathAllowed):
                // `.urlPathAllowed` leaves '/' bare — a target containing one would split into two
                // path components and the dispatch registry lookup would silently miss.
                let a11y = Self.brokenRefAriaLabel(reason: broken.reason)
                let strictTarget = target.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? target
                return "<a class=\"cross-ref-broken\" href=\"frusexplorer://brokenref/\(strictTarget)\" "
                    + "role=\"button\" aria-label=\"\(escaped(a11y))\">\(inline(children))"
                    + "<span class=\"cross-ref-broken-mark\" data-skip=\"1\" aria-hidden=\"true\">\u{2020}</span></a>"
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
        // The chip rides inside the (already offset-invisible) aside.
        return "<aside class=\"footnote \(typeClass)\" id=\"fn-\(escaped(label))\" popover data-skip=\"1\">\(block(children))\(classificationChipHTML(type: type, children: children))</aside>"
    }

    // MARK: - Classification Chip (Source Explorer Phase 5)

    /// Builds the classification chip for a `.source` footnote, or `""` when chips
    /// are disabled (exports), the footnote is not a source note, or the note carries
    /// no confident classification-markings sentence.
    ///
    /// The note text is recovered with the shared flat-text DFS, its `[Source: …]`
    /// wrapper collapsed exactly as indexing does (`normalizeSourceNoteWrapper`),
    /// and the marking extracted by the same S1 derivation stored in
    /// `document_sources.classification` — so the chip in the reading view always
    /// matches the Source Explorer's.
    private func classificationChipHTML(type: FootnoteType, children: [FRUSRenderNode]) -> String {
        guard annotateSourceClassification, type == .source else { return "" }
        // Collapse whitespace the same way indexing's `normalizedWhitespace` does
        // (that helper is file-private to IndexingPipeline.swift).
        let collapsed = flatText(of: children)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let note = IndexingPipeline.normalizeSourceNoteWrapper(collapsed)
        guard let marking = SourceNoteParser.classificationMarking(fromSourceNote: note) else {
            return ""
        }
        // data-skip is belt-and-suspenders: both insertion points are already
        // offset-invisible (aside data-skip; footnotes section outside the DFS root).
        return "<span class=\"classification-chip\" data-skip=\"1\" aria-label=\"Classification markings: \(escaped(marking))\">\(escaped(marking))</span>"
    }

    // MARK: - Broken cross-references

    /// A concise localized VoiceOver label for a broken cross-reference, by failure reason.
    /// The full explanation is in the tap-through sheet; this is the inline announcement.
    static func brokenRefAriaLabel(reason: String) -> String {
        let detail: String
        switch reason {
        case "unknownPage":
            detail = String(localized: "the referenced page could not be found")
        case "unknownVolume":
            detail = String(localized: "the referenced volume isn't part of this collection")
        case "emptyTarget":
            detail = String(localized: "it has no destination")
        default:   // unknownAnchor and any future reason
            detail = String(localized: "the referenced document or section no longer exists")
        }
        return String(localized: "Unresolved cross-reference: \(detail). Activate for details.")
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
