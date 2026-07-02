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
/// All HTML construction lives in the shared `CollectionItemHTMLRenderer` (also consumed
/// by the live collection preview); this type only adds the export-specific concerns:
/// the optional word-cloud figure image and writing the assembled page to disk.
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
///   1.7 — Session 2026-07-02 data-loss fix: `proseHTML` no longer silently drops a prose
///          block whose payload predates the RTF storage format — the shared
///          `CollectionProse.paragraphs(fromRTF:)` now decodes legacy Phase 3b JSON
///          `AttributedString` blobs (bold/italic preserved) instead of returning `[]`
///   1.8 — Authoring Phase 2b: all HTML construction (`buildHTML`, embedded CSS, prose /
///          escaping / anchor helpers) extracted verbatim into the shared
///          `CollectionItemHTMLRenderer`; this type is now a thin assemble-and-write wrapper
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
        let renderer = CollectionItemHTMLRenderer(options: options)
        let html = renderer.pageHTML(metadata: metadata, items: items,
                                     wordCloudPNGBase64: cloudBase64)
        let filename = sanitized(metadata.name) + ".html"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - Helpers

    /// Strips filesystem-hostile characters from the collection name for use as a filename.
    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }
}
