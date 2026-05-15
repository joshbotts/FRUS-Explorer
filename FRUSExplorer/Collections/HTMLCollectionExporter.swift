// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HTMLCollectionExporter

/// Exports a `Collection` to a self-contained HTML file with embedded CSS.
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
public final class HTMLCollectionExporter: CollectionExporter {

    // MARK: - CollectionExporter

    public func export(
        collection: Collection,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        let html = buildHTML(collection: collection, documents: documents)
        let filename = sanitized(collection.name) + ".html"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - HTML Construction

    private func buildHTML(collection: Collection, documents: [CollectionExportDocument]) -> String {
        let title = escaped(collection.name)
        var body = ""

        // Header
        body += "<header>\n"
        body += "  <h1>\(title)</h1>\n"
        if let note = collection.note, !note.isEmpty {
            body += "  <p class=\"collection-note\">\(escaped(note))</p>\n"
        }
        body += "</header>\n\n"

        // Table of contents
        body += "<nav>\n  <h2>Contents</h2>\n  <ol>\n"
        for doc in documents {
            let anchor = anchorId(doc: doc)
            body += "    <li><a href=\"#\(anchor)\">\(escaped(doc.title))</a></li>\n"
        }
        body += "  </ol>\n</nav>\n\n"

        // Document sections
        for doc in documents {
            let anchor = anchorId(doc: doc)
            body += "<section id=\"\(anchor)\">\n"
            body += "  <h2>\(escaped(doc.title))</h2>\n"
            if let date = doc.date, !date.isEmpty {
                body += "  <p class=\"doc-date\">\(escaped(date))</p>\n"
            }
            if !doc.bodyText.isEmpty {
                let paragraphs = doc.bodyText
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in paragraphs {
                    body += "  <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                }
            }
            if let note = doc.noteText, !note.isEmpty {
                body += "  <aside class=\"research-note\">\n"
                body += "    <strong>Research Note</strong>\n"
                body += "    <p>\(escaped(note))</p>\n"
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
          font-size: 1.4rem;
          font-weight: bold;
          margin-bottom: 0.4rem;
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
        @media print {
          body { max-width: 100%; padding: 0; }
          nav { break-after: page; }
          section { break-inside: avoid; }
        }
        """
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
