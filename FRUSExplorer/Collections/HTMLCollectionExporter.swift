// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HTMLCollectionExporter

/// Exports a collection's metadata and documents to a self-contained HTML file with embedded CSS.
///
/// Receives a `CollectionExportMetadata` snapshot (name, optional note) together with
/// pre-resolved `CollectionExportDocument` payloads so no SwiftData access is needed
/// during rendering.
///
/// The output is a single `.html` file — no external resources required.
/// Structure:
///   - `<header>` — collection title and optional note
///   - `<nav>` — table of contents with anchor links to each document section
///   - One `<section>` per document, with an optional research-note callout
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 32: replaced `Collection` parameter with `CollectionExportMetadata`
///   1.2 — Session 73: citation headings link to history.state.gov (target=_blank);
///          URL displayed as `.doc-url` paragraph; body text split on "\n\n" into `<p>` tags;
///          research note split into paragraphs; new CSS for `.doc-ext-link` and `.doc-url`
///   1.3 — Session 81: rich rendering via `FRUSDocumentRenderModel` when available;
///          `renderModelToHTML` walks render nodes emitting semantic HTML; flat-text
///          fallback preserved; new CSS for headings, datelines, footnotes, attachments
final class HTMLCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        let html = buildHTML(collection: metadata, documents: documents)
        let filename = sanitized(metadata.name) + ".html"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - HTML Construction

    private func buildHTML(collection: CollectionExportMetadata, documents: [CollectionExportDocument]) -> String {
        let title = escaped(collection.name)
        var body = ""

        // Header
        body += "<header>\n"
        body += "  <h1>\(title)</h1>\n"
        if let note = collection.note, !note.isEmpty {
            body += "  <p class=\"collection-note\">\(escaped(note))</p>\n"
        }
        body += "</header>\n\n"

        // Table of contents — shows citations with internal anchor links
        body += "<nav>\n  <h2>Contents</h2>\n  <ol>\n"
        for doc in documents {
            let anchor = anchorId(doc: doc)
            let label = doc.citation.isEmpty ? doc.title : doc.citation
            body += "    <li><a href=\"#\(anchor)\">\(escaped(label))</a></li>\n"
        }
        body += "  </ol>\n</nav>\n\n"

        // Document sections
        for doc in documents {
            let anchor = anchorId(doc: doc)
            let heading = doc.citation.isEmpty ? doc.title : doc.citation
            body += "<section id=\"\(anchor)\">\n"

            // Citation as heading with external link
            if !doc.historyStateGovURL.isEmpty {
                body += "  <h2><a href=\"\(escaped(doc.historyStateGovURL))\" "
                body +=     "class=\"doc-ext-link\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body +=     "\(escaped(heading))</a></h2>\n"
                body += "  <p class=\"doc-url\">"
                body +=     "<a href=\"\(escaped(doc.historyStateGovURL))\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body +=     "\(escaped(doc.historyStateGovURL))</a></p>\n"
            } else {
                body += "  <h2>\(escaped(heading))</h2>\n"
            }

            // Body — rich rendering if available, else flat-text fallback
            if let model = doc.renderModel {
                body += renderModelToHTML(model)
            } else if !doc.bodyText.isEmpty {
                let paragraphs = doc.bodyText
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in paragraphs {
                    body += "  <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                }
            }

            // Research note
            if let note = doc.noteText, !note.isEmpty {
                body += "  <aside class=\"research-note\">\n"
                body += "    <strong>Research Note</strong>\n"
                let noteParagraphs = note
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in noteParagraphs {
                    body += "    <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                }
                body += "  </aside>\n"
            }

            body += "</section>\n\n"
        }

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>\(title)</title>
          <style>
            \(embeddedCSS)
          </style>
        </head>
        <body>
          \(body)
        </body>
        </html>
        """
    }

    // MARK: - Embedded CSS

    private var embeddedCSS: String {
        """
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: Georgia, 'Times New Roman', serif;
          font-size: 16px;
          line-height: 1.65;
          color: #222;
          max-width: 780px;
          margin: 0 auto;
          padding: 2rem 1.5rem;
          background: #fff;
        }
        header {
          border-bottom: 2px solid #222;
          padding-bottom: 1.5rem;
          margin-bottom: 2rem;
        }
        header h1 {
          font-size: 2rem;
          font-weight: bold;
          letter-spacing: -0.02em;
        }
        .collection-note {
          margin-top: 0.75rem;
          font-style: italic;
          color: #555;
        }
        nav {
          background: #f7f7f5;
          border: 1px solid #ddd;
          border-radius: 4px;
          padding: 1.25rem 1.5rem;
          margin-bottom: 2.5rem;
        }
        nav h2 {
          font-size: 1rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          margin-bottom: 0.75rem;
          color: #555;
        }
        nav ol { padding-left: 1.25rem; }
        nav li { margin: 0.3rem 0; }
        nav a { color: #1a4c8f; text-decoration: none; }
        nav a:hover { text-decoration: underline; }
        section {
          border-top: 1px solid #ddd;
          padding-top: 2rem;
          margin-bottom: 3rem;
        }
        section h2 {
          font-size: 1.25rem;
          font-weight: bold;
          margin-bottom: 0.3rem;
          line-height: 1.4;
        }
        a.doc-ext-link { color: inherit; text-decoration: none; }
        a.doc-ext-link:hover { text-decoration: underline; }
        .doc-url {
          font-size: 0.8rem;
          color: #1a4c8f;
          margin-bottom: 1rem;
          word-break: break-all;
        }
        .doc-date {
          font-size: 0.9rem;
          color: #666;
          margin-bottom: 1rem;
        }
        section p {
          margin-bottom: 0.85rem;
          text-align: justify;
          hyphens: auto;
        }
        aside.research-note {
          margin-top: 1.5rem;
          padding: 1rem 1.25rem;
          background: #fffbea;
          border-left: 3px solid #d4a017;
          border-radius: 2px;
        }
        aside.research-note strong {
          display: block;
          font-size: 0.85rem;
          text-transform: uppercase;
          letter-spacing: 0.06em;
          margin-bottom: 0.4rem;
          color: #7a5c00;
        }
        aside.research-note p { color: #444; }
        /* Rich document body elements (Session 81) */
        h3.doc-heading {
          font-size: 1.05rem;
          font-weight: bold;
          margin-top: 1rem;
          margin-bottom: 0.25rem;
          line-height: 1.4;
        }
        p.dateline {
          font-style: italic;
          color: #555;
          margin-bottom: 0.5rem;
        }
        p.salutation { margin-bottom: 0.5rem; }
        .letter-block { margin-bottom: 0.75rem; }
        blockquote.editorial-note {
          border-left: 3px solid #aaa;
          padding: 0.5rem 1rem;
          margin: 1rem 0;
          color: #555;
          font-style: italic;
        }
        section.attachment { margin-top: 2.5rem; }
        h4.attachment-heading {
          font-size: 0.95rem;
          font-weight: 600;
          margin-bottom: 0.5rem;
        }
        .title-page {
          text-align: center;
          padding: 1.5rem 0;
        }
        .small-caps { font-variant: small-caps; }
        table {
          border-collapse: collapse;
          margin: 0.75rem 0;
          width: 100%;
          font-size: 0.9rem;
        }
        td, th {
          border: 1px solid #ccc;
          padding: 0.3rem 0.5rem;
          vertical-align: top;
        }
        ol.footnotes {
          margin-top: 1.5rem;
          padding-top: 0.75rem;
          border-top: 1px solid #ccc;
          font-size: 0.85rem;
          color: #444;
          padding-left: 1.5rem;
        }
        ol.footnotes li { margin-bottom: 0.4rem; }
        sup.fn-label { font-size: 0.7em; margin-right: 0.2em; }
        sup a { color: #1a4c8f; text-decoration: none; }
        sup a:hover { text-decoration: underline; }
        code.formula { font-style: italic; font-family: Georgia, serif; }
        @media print {
          body { max-width: 100%; padding: 0; }
          nav { break-after: page; }
          section { break-inside: avoid; }
        }
        """
    }

    // MARK: - Rich Rendering (Session 81)

    /// Renders a `FRUSDocumentRenderModel` to an HTML string.
    /// Body nodes come first; footnote bodies are appended as a numbered list.
    private func renderModelToHTML(_ model: FRUSDocumentRenderModel) -> String {
        var html = ""
        for node in model.bodyNodes {
            html += blockNodeToHTML(node)
        }
        if !model.footnotes.isEmpty {
            html += "<ol class=\"footnotes\">\n"
            for note in model.footnotes {
                if case .footnoteBody(let id, _, _, _, let label, let children) = note {
                    let anchorAttr = id.map { "id=\"fn-\(escaped($0))\"" } ?? "id=\"fn-\(escaped(label))\""
                    let bodyHTML = children.map { blockNodeToHTML($0) }.joined()
                    html += "  <li \(anchorAttr)><sup class=\"fn-label\">\(escaped(label))</sup> \(bodyHTML)</li>\n"
                }
            }
            html += "</ol>\n"
        }
        return html
    }

    private func blockNodeToHTML(_ node: FRUSRenderNode) -> String {
        switch node {
        case .heading(let c):
            return "<h3 class=\"doc-heading\">\(inlineHTML(c))</h3>\n"
        case .dateline(let c):
            return "<p class=\"dateline\">\(inlineHTML(c))</p>\n"
        case .salutation(let c):
            return "<p class=\"salutation\">\(inlineHTML(c))</p>\n"
        case .paragraph(let c):
            return "<p>\(inlineHTML(c))</p>\n"
        case .letterOpener(let c), .letterCloser(let c):
            return "<div class=\"letter-block\">\(c.map { blockNodeToHTML($0) }.joined())</div>\n"
        case .editorialNoteBlock(let c):
            return "<blockquote class=\"editorial-note\">\(c.map { blockNodeToHTML($0) }.joined())</blockquote>\n"
        case .attachmentBlock(_, let c):
            return "<section class=\"attachment\"><hr>\n\(c.map { blockNodeToHTML($0) }.joined())</section>\n"
        case .attachmentHeading(let c):
            return "<h4 class=\"attachment-heading\">\(inlineHTML(c))</h4>\n"
        case .titlePageBlock(let c):
            return "<div class=\"title-page\">\(c.map { blockNodeToHTML($0) }.joined())</div>\n"
        case .tableBlock(let rows):
            var t = "<table>\n"
            for row in rows {
                t += "  <tr>"
                for cell in row {
                    var attrs = ""
                    if cell.rowSpan > 1 { attrs += " rowspan=\"\(cell.rowSpan)\"" }
                    if cell.colSpan > 1 { attrs += " colspan=\"\(cell.colSpan)\"" }
                    t += "<td\(attrs)>\(inlineHTML(cell.children))</td>"
                }
                t += "</tr>\n"
            }
            t += "</table>\n"
            return t
        case .listBlock(let type, let items):
            let tag = type == "ordered" ? "ol" : "ul"
            let inner = items.map { "  <li>\(inlineHTML($0))</li>\n" }.joined()
            return "<\(tag)>\n\(inner)</\(tag)>\n"
        case .figureBlock(let alt):
            guard let alt, !alt.isEmpty else { return "" }
            return "<figure><figcaption>\(escaped(alt))</figcaption></figure>\n"
        case .footnoteBody:
            return "" // rendered separately via model.footnotes
        case .pageBreak:
            return ""
        case .unknown(_, let c):
            return c.map { blockNodeToHTML($0) }.joined()
        default:
            // Inline node at block level — wrap in a paragraph
            return "<p>\(inlineNodeToHTML(node))</p>\n"
        }
    }

    private func inlineHTML(_ nodes: [FRUSRenderNode]) -> String {
        nodes.map { inlineNodeToHTML($0) }.joined()
    }

    private func inlineNodeToHTML(_ node: FRUSRenderNode) -> String {
        switch node {
        case .plainText(let s):
            return escaped(s)
        case .boldText(let c):
            return "<strong>\(inlineHTML(c))</strong>"
        case .italicText(let c):
            return "<em>\(inlineHTML(c))</em>"
        case .smallCapsText(let c):
            return "<span class=\"small-caps\">\(inlineHTML(c))</span>"
        case .underlineText(let c):
            return "<u>\(inlineHTML(c))</u>"
        case .termText(let c), .corrText(let c):
            return inlineHTML(c)
        case .suppliedText(let c):
            return "[\(inlineHTML(c))]"
        case .sicText(let c):
            return "<del>\(inlineHTML(c))</del>"
        case .formulaText(let s):
            return "<code class=\"formula\">\(escaped(s))</code>"
        case .lineBreak:
            return "<br>"
        case .footnoteMarker(let id, let label):
            let anchor = id ?? label
            return "<sup><a href=\"#fn-\(escaped(anchor))\" id=\"fnref-\(escaped(anchor))\">\(escaped(label))</a></sup>"
        case .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, let c):
            return inlineHTML(c)
        case .pageBreak:
            return ""
        case .unknown(_, let c):
            return inlineHTML(c)
        default:
            // Block node inside inline context — extract children as inline
            return blockNodeToHTML(node)
        }
    }

    // MARK: - Helpers

    private func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func anchorId(doc: CollectionExportDocument) -> String {
        "doc-\(doc.volumeId)-\(doc.documentId)"
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
    }

    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }
}
