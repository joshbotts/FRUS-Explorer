// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

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
///   1.4 — Session 83: `markdownItalics(_:)` applies `_text_` → `<em>text</em>`
///          conversion to the collection note field
///   1.5 — Session 128: `markdownItalics(_:)` now applied to citation labels in ToC and
///          section headings, and to research note paragraphs; `options: CollectionExportOptions`
///          parameter controls ToC label style; `noteTexts: [String]` and `includeDocumentBody`
///          respected for per-entry content selection
///   1.6 — Session 146: document body rendered via `FRUSRenderNodeHTMLSerializer` (replaces
///          private `renderModelToHTML` / `blockNodeToHTML` / `inlineNodeToHTML`); CSS replaced
///          by shared `HTMLTemplate.documentCSS` + `FRUSTheme.cssVariables` + print overrides
final class HTMLCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        let cloudBase64: String? = options.includeWordCloud
            ? WordCloudExporter.collectionCloudImage(
                texts: items.documents.map(\.bodyText), title: metadata.name
              )?.pngBase64
            : nil
        let html = buildHTML(collection: metadata, items: items,
                             options: options, wordCloudPNGBase64: cloudBase64)
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

    private func buildHTML(
        collection: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions,
        wordCloudPNGBase64: String? = nil
    ) -> String {
        let title = escaped(collection.name)
        var body = ""

        // Header
        body += "<header>\n"
        body += "  <h1>\(title)</h1>\n"
        if let note = collection.note, !note.isEmpty {
            body += "  <p class=\"collection-note\">\(markdownItalics(escaped(note)))</p>\n"
        }
        body += "</header>\n\n"

        // Word-cloud overview (optional), embedded as a base64 PNG
        if let base64 = wordCloudPNGBase64 {
            body += "<figure class=\"word-cloud\">\n"
            body += "  <img alt=\"Word cloud of the most frequent terms in this collection\" "
            body += "src=\"data:image/png;base64,\(base64)\" style=\"max-width:100%;height:auto;\" />\n"
            body += "  <figcaption>Most frequent terms in this collection</figcaption>\n"
            body += "</figure>\n\n"
        }

        // Table of contents — label style controlled by options.tocStyle.
        // Headings appear as (non-link) section labels; prose blocks are omitted.
        body += "<nav>\n  <h2>Contents</h2>\n  <ol>\n"
        for item in items {
            switch item {
            case .document(let doc):
                let anchor = anchorId(doc: doc)
                let label = doc.tocLabel(style: options.tocStyle)
                body += "    <li><a href=\"#\(anchor)\">\(markdownItalics(escaped(label)))</a></li>\n"
            case .heading(let heading):
                body += "    <li class=\"toc-section\">\(markdownItalics(escaped(heading)))</li>\n"
            case .prose:
                break
            }
        }
        body += "  </ol>\n</nav>\n\n"

        // Body items — documents render as sections; headings and prose interleave in order.
        for item in items {
            switch item {
            case .heading(let heading):
                body += "<h2 class=\"section-heading\">\(markdownItalics(escaped(heading)))</h2>\n\n"
            case .prose(let prose):
                body += "<div class=\"prose-block\">\n"
                for para in prose.components(separatedBy: "\n\n")
                where !para.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body += "  <p>\(markdownItalics(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines))))</p>\n"
                }
                body += "</div>\n\n"
            case .document(let doc):
            let anchor = anchorId(doc: doc)
            // Section heading always shows the citation (regardless of ToC style).
            let heading = doc.citation.isEmpty ? doc.title : doc.citation
            body += "<section id=\"\(anchor)\">\n"

            // Citation as heading with external link — apply markdownItalics for _text_ spans.
            if !doc.historyStateGovURL.isEmpty {
                body += "  <h2><a href=\"\(escaped(doc.historyStateGovURL))\" "
                body +=     "class=\"doc-ext-link\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body +=     "\(markdownItalics(escaped(heading)))</a></h2>\n"
                body += "  <p class=\"doc-url\">"
                body +=     "<a href=\"\(escaped(doc.historyStateGovURL))\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body +=     "\(escaped(doc.historyStateGovURL))</a></p>\n"
            } else {
                body += "  <h2>\(markdownItalics(escaped(heading)))</h2>\n"
            }

            // Body — controlled by doc.bodyDepth (per-entry effective depth).
            switch doc.bodyDepth {
            case .full:
                let includeFootnotes = (options.footnoteStyle == .all)
                if let model = doc.renderModel {
                    body += FRUSRenderNodeHTMLSerializer().serialize(
                        model,
                        includeFootnotes: includeFootnotes,
                        highlights: options.applyHighlights ? doc.highlights : []
                    )
                } else if !doc.bodyText.isEmpty {
                    let paragraphs = doc.bodyText
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in paragraphs {
                        body += "  <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                    }
                }
            case .summaryOnly:
                if let summary = doc.summaryText, !summary.isEmpty {
                    body += "  <div class=\"summary-block\">\n"
                    body += "    <p class=\"summary-label\">Summary</p>\n"
                    let summaryParas = summary
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in summaryParas {
                        body += "    <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                    }
                    body += "  </div>\n"
                }
            case .index:
                break  // no body content
            }

            // Source note (footnoteStyle == .sourceNoteOnly)
            if let sourceNote = doc.sourceNoteText, !sourceNote.isEmpty {
                body += "  <p class=\"source-note\"><strong>Source:</strong> \(escaped(sourceNote))</p>\n"
            }

            // Research notes — respects options.includeNotes.
            if options.includeNotes {
                for note in doc.noteTexts where !note.isEmpty {
                    body += "  <aside class=\"research-note\">\n"
                    body += "    <strong>Research Note</strong>\n"
                    let noteParagraphs = note
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in noteParagraphs {
                        body += "    <p>\(markdownItalics(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines))))</p>\n"
                    }
                    body += "  </aside>\n"
                }
            }

            body += "</section>\n\n"
            }
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

    // MARK: - Embedded CSS (Session 146)

    /// Combined CSS for the exported HTML file.
    ///
    /// Layer 1: CSS custom properties (light mode, medium text size) from `FRUSTheme`.
    /// Layer 2: Document body styles shared with the in-app WKWebView renderer
    ///          (`HTMLTemplate.documentCSS`).
    /// Layer 3: Collection-export-specific layout (header, nav, section, research-note).
    /// Layer 4: Print overrides.
    private var embeddedCSS: String {
        FRUSTheme.cssVariables(colorScheme: .light, textSize: .large)
        + "\n" + HTMLTemplate.documentCSS
        + "\n" + Self.collectionExportCSS
        + "\n" + FRUSRenderNodeHTMLSerializer.highlightCSS
        + "\n" + Self.printCSS
    }

    /// Collection-specific layout styles not covered by `HTMLTemplate.documentCSS`.
    private static let collectionExportCSS = """
    /* ── Page layout ─────────────────────────────────────────────────────── */
    body {
      font-family: Georgia, 'Times New Roman', serif;
      background: #fff;
      max-width: 780px;
      margin: 0 auto;
      padding: 2rem 1.5rem;
    }

    /* ── Collection header ────────────────────────────────────────────────── */
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

    /* ── Table of contents ────────────────────────────────────────────────── */
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
    nav li  { margin: 0.3rem 0; }
    nav a   { color: #1a4c8f; text-decoration: none; }
    nav a:hover { text-decoration: underline; }
    .toc-entry { display: flex; justify-content: space-between; }
    .toc-page  { color: #888; font-size: 0.9em; }

    /* ── Document sections ────────────────────────────────────────────────── */
    section {
      border-top: 1px solid #ddd;
      padding-top: 2rem;
      margin-bottom: 3rem;
    }
    section > h2 {
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

    /* ── Research notes ───────────────────────────────────────────────────── */
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

    /* ── Summary block (bodyDepth == summaryOnly) ──────────────────────────── */
    .summary-block {
      background: #f0f4ff;
      border-left: 3px solid #3a6bc9;
      padding: 1rem 1.25rem;
      margin: 1rem 0;
      border-radius: 2px;
    }
    .summary-label {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: #3a6bc9;
      font-weight: 600;
      margin-bottom: 0.5rem;
    }

    /* ── Source note (footnoteStyle == sourceNoteOnly) ─────────────────────── */
    .source-note {
      margin-top: 1rem;
      font-size: 0.85rem;
      color: #555;
      border-top: 1px solid #ddd;
      padding-top: 0.6rem;
    }
    """

    /// Print-specific overrides (Session 146).
    /// Canonical source: `FRUSExplorer/Resources/frus-print.css`
    private static let printCSS = """
    @media print {
      .frus-document { page-break-after: always; }
      .fn-marker     { display: none; }
      .footnote {
        display: block !important;
        font-size: 0.85em;
        margin-top: 1em;
        border: 1px solid #ccc;
        border-radius: 0;
        box-shadow: none;
        padding: 0.5em 0.75em;
      }
      .toc-entry { display: flex; justify-content: space-between; }
      body    { max-width: 100%; padding: 0; }
      nav     { break-after: page; }
      section { break-inside: avoid; }
    }
    """

    // MARK: - Helpers

    /// Converts `_text_` spans (already HTML-escaped) to `<em>text</em>`.
    /// Apply to `escaped(note)` so that `_` in the original text is still present
    /// after escaping (no HTML entity conflicts) but `<em>` tags are safe.
    private func markdownItalics(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "_([^_\\n]+)_") else { return input }
        return regex.stringByReplacingMatches(
            in: input,
            range: NSRange(input.startIndex..., in: input),
            withTemplate: "<em>$1</em>"
        )
    }

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
