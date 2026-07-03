// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - CollectionItemHTMLRenderer

/// Shared per-item HTML renderer for collection content — the single code path that turns
/// a `CollectionExportItem` into an HTML fragment, used by BOTH `HTMLCollectionExporter`
/// (file export) and the live collection preview (Authoring Phase 2b).
///
/// Because both consumers call the exact same `itemHTML(_:)` function, the preview and the
/// HTML export cannot drift by construction: a new `CollectionExportItem` case added in a
/// later phase gets one HTML function here and appears identically in both surfaces.
///
/// The type is a pure string builder — no file I/O, no SwiftData access, no main-actor
/// requirement. Responsibilities:
///   - `itemHTML(_:)` — one item → one HTML fragment (heading / prose / document section).
///     Documents keep their stable `anchorId(doc:)` anchors, inline highlight injection
///     (via `FRUSRenderNodeHTMLSerializer`), body-depth handling, source-note and
///     research-note blocks — exactly as the HTML export has always emitted them.
///   - `headerHTML(metadata:)`, `tableOfContentsHTML(for:)` — the page header and ToC nav.
///   - `pageHTML(metadata:items:wordCloudPNGBase64:)` — assembles a complete standalone
///     HTML page (shared `<head>`/CSS + header + ToC + every item fragment) — the exporter
///     writes this string to disk; the preview loads it into a `WKWebView`.
///   - `embeddedCSS` — the shared stylesheet: `FRUSTheme.cssVariables` +
///     `HTMLTemplate.documentCSS` + collection layout + highlight + print layers.
///
/// Version history:
///   1.0 — Authoring Phase 2b: extracted verbatim from `HTMLCollectionExporter.buildHTML`
///          (v1.7) so the file exporter and the live preview share one item renderer
///   1.1 — Authoring Phase 2b (preview pane): `citationOnlyVolumeIds` — documents from
///          these volumes render a bordered citation card instead of a body (the live
///          preview's un-downloaded-volume treatment; exporters never set it, so export
///          output is unchanged)
///   1.2 — Authoring Phase 2b (preview-review fixes): `showsSummaryPlaceholders` — the
///          preview-only placeholder card for a `.summaryOnly` document with no stored
///          summary (exports still either attach a summary or throw); the preview-only
///          card CSS (citation card + summary placeholder) moved out of the shared
///          stylesheet into `previewCSS`, emitted only when a preview affordance is
///          configured — exported HTML is byte-identical to the pre-Phase-2b output
///   1.3 — Authoring Phase 4 (publication frame): leveled section headings
///          (level 1 → the exact pre-Phase-4 `<h2>`, 2/3 → stepped `<h3>`/`<h4>`);
///          nested ToC lists driven by heading levels (all-level-1 output unchanged);
///          title-page subtitle/author lines and the opt-in colophon footer, all
///          metadata-driven; the frame stylesheet (`frameCSS`) is emitted ONLY when a
///          frame feature is actually used, so a collection using none exports
///          byte-identically to the pre-Phase-4 output
struct CollectionItemHTMLRenderer {

    /// Rendering options shared with the exporters — controls the ToC label style,
    /// footnote inclusion, inline highlight annotation, and research-note visibility.
    let options: CollectionExportOptions

    /// Volume ids whose documents render as **citation-only cards** — a bordered card
    /// carrying the citation and a "Volume not downloaded" note — instead of a body.
    /// Set only by the live preview (whose `.preview` resolution yields empty bodies
    /// for un-downloaded volumes); exporters leave it empty, so the HTML export byte
    /// output is unaffected.
    var citationOnlyVolumeIds: Set<String> = []

    /// When `true`, a `.summaryOnly` document with no stored summary renders a
    /// **summary-placeholder card** (styled like the citation card) noting that the
    /// summary will be generated at export, instead of an empty body. Set only by the
    /// live preview, whose `.preview` resolution never generates summaries; exporters
    /// leave it `false` — an `.export` resolve either attaches a summary or throws, so
    /// export output never contains the placeholder.
    var showsSummaryPlaceholders: Bool = false

    /// `true` when any preview-only affordance is configured — the gate for emitting the
    /// preview-only card stylesheet (`previewCSS`). Exporters set neither property, so
    /// exported HTML stays byte-identical to the pre-preview output.
    private var isPreviewConfigured: Bool {
        showsSummaryPlaceholders || !citationOnlyVolumeIds.isEmpty
    }

    /// Creates a renderer with the given export options.
    ///
    /// - Parameter options: Rendering options; defaults preserve the standard export look.
    init(options: CollectionExportOptions = CollectionExportOptions()) {
        self.options = options
    }

    // MARK: - Per-Item Fragment

    /// Renders one collection item to its HTML fragment — THE shared per-item function.
    ///
    /// - `.heading` → a level-stepped heading element with class `section-heading`:
    ///   level 1 → `<h2>` (byte-identical to the pre-Phase-4 output), level 2 → `<h3>`,
    ///   level 3 → `<h4>`. Out-of-range levels clamp defensively.
    /// - `.prose` → a `<div class="prose-block">` of formatted paragraphs (or empty when
    ///   the payload decodes to nothing).
    /// - `.document` → a full `<section id="doc-…">` with citation heading, external link,
    ///   body (per the document's `bodyDepth`), highlights, source note, and research notes.
    ///
    /// - Parameter item: The resolved item to render.
    /// - Returns: An HTML fragment string (may be empty for an empty prose payload).
    func itemHTML(_ item: CollectionExportItem) -> String {
        switch item {
        case .heading(let heading, let level):
            let tag = "h\(Self.clampedLevel(level) + 1)"   // level 1 → h2 (pre-Phase-4), 2 → h3, 3 → h4
            return "<\(tag) class=\"section-heading\">\(markdownItalics(escaped(heading)))</\(tag)>\n\n"
        case .prose(let prose):
            return proseHTML(prose)
        case .document(let doc):
            return documentSectionHTML(doc)
        }
    }

    /// Defensively clamps a heading level to `1...CollectionOutline.maxLevel` — producers
    /// already emit outline-resolved levels, so this only guards direct callers.
    private static func clampedLevel(_ level: Int) -> Int {
        min(max(level, 1), CollectionOutline.maxLevel)
    }

    /// Renders a resolved document as a `<section>` fragment: citation heading (linked to
    /// history.state.gov when available), body per the document's effective `bodyDepth`
    /// (full render model / flat-text fallback / summary / none), optional source note,
    /// and optional research-note asides.
    ///
    /// - Parameter doc: The pre-resolved document payload.
    /// - Returns: The document's `<section id="doc-…">…</section>` HTML fragment.
    private func documentSectionHTML(_ doc: CollectionExportDocument) -> String {
        var body = ""
        let anchor = Self.anchorId(doc: doc)
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

        // Preview: a document whose volume is not downloaded has no resolvable body —
        // render a visibly distinct citation card in its place (never taken by exports).
        // Research notes still render below: they live in SwiftData, not the volume.
        if citationOnlyVolumeIds.contains(doc.volumeId) {
            body += citationOnlyCardHTML(doc)
        } else {
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
            } else if showsSummaryPlaceholders {
                // Preview only: no stored summary, and .preview resolution never
                // generates one — show the promised placeholder card instead of an
                // empty body. Never taken by exports (the flag is preview-set only).
                body += summaryPlaceholderCardHTML()
            }
        case .index:
            break  // no body content
        }
        }  // end citation-only else (body kept at original indentation for diff clarity)

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
        return body
    }

    /// The citation-only card emitted (preview only) for a document whose volume is not
    /// downloaded: a bordered card with the citation and a localized "Volume not
    /// downloaded" note. The *download* affordance is native (a bar above the preview's
    /// web view), never in-page JS.
    ///
    /// - Parameter doc: The citation-only document (empty body, no render model).
    /// - Returns: The card's `<div class="citation-card">…</div>` HTML fragment.
    private func citationOnlyCardHTML(_ doc: CollectionExportDocument) -> String {
        let note = String(localized: "collection.preview.volumeNotDownloaded",
                          defaultValue: "Volume not downloaded — citation only")
        let citation = doc.citation.isEmpty ? doc.title : doc.citation
        var body = ""
        body += "  <div class=\"citation-card\">\n"
        body += "    <p class=\"citation-card-citation\">\(markdownItalics(escaped(citation)))</p>\n"
        body += "    <p class=\"citation-card-note\">\(escaped(note))</p>\n"
        body += "  </div>\n"
        return body
    }

    /// The placeholder card emitted (preview only) for a `.summaryOnly` document with no
    /// stored summary: `.preview` resolution never generates summaries, so the preview
    /// shows a card (styled like the citation card) noting that the summary will be
    /// generated at export. Exports never reach this — an `.export` resolve either
    /// attaches a summary or throws before rendering.
    ///
    /// - Returns: The card's `<div class="summary-placeholder">…</div>` HTML fragment.
    private func summaryPlaceholderCardHTML() -> String {
        let note = String(localized: "collection.preview.summaryPlaceholder",
                          defaultValue: "Summary will be generated at export")
        var body = ""
        body += "  <div class=\"summary-placeholder\">\n"
        body += "    <p class=\"summary-placeholder-note\">\(escaped(note))</p>\n"
        body += "  </div>\n"
        return body
    }

    // MARK: - Assembly

    /// Renders the collection header block: title `<h1>`, the optional Phase 4 title-page
    /// lines (subtitle, author) — emitted ONLY when set, so an unset collection's header
    /// is byte-identical to the pre-Phase-4 output — plus the optional collection note.
    ///
    /// - Parameter metadata: The collection's display snapshot.
    /// - Returns: The `<header>…</header>` HTML fragment.
    func headerHTML(metadata: CollectionExportMetadata) -> String {
        var body = ""
        body += "<header>\n"
        body += "  <h1>\(escaped(metadata.name))</h1>\n"
        if let subtitle = metadata.subtitle, !subtitle.isEmpty {
            body += "  <p class=\"collection-subtitle\">\(markdownItalics(escaped(subtitle)))</p>\n"
        }
        if let author = metadata.authorLine, !author.isEmpty {
            body += "  <p class=\"collection-author\">\(escaped(author))</p>\n"
        }
        if let note = metadata.note, !note.isEmpty {
            body += "  <p class=\"collection-note\">\(markdownItalics(escaped(note)))</p>\n"
        }
        body += "</header>\n\n"
        return body
    }

    /// Renders the table of contents `<nav>` — label style controlled by `options.tocStyle`.
    /// Documents become anchor links; headings appear as (non-link) section labels; prose
    /// blocks are omitted.
    ///
    /// Heading levels drive **nested lists** (Authoring Phase 4): a deeper heading opens a
    /// `<li class="toc-sub"><ol>` wrapper (valid nesting — the sub-list lives inside an
    /// `<li>`), and documents nest inside the list of their owning section. A ToC whose
    /// headings are all level 1 never opens a nested list, so its output is byte-identical
    /// to the pre-Phase-4 flat markup.
    ///
    /// - Parameter items: The ordered items whose documents and headings populate the ToC.
    /// - Returns: The `<nav>…</nav>` HTML fragment.
    func tableOfContentsHTML(for items: [CollectionExportItem]) -> String {
        /// Line indentation for list items at a nesting level (level 1 = the pre-Phase-4
        /// four spaces; each deeper level adds two).
        func indent(_ level: Int) -> String { String(repeating: "  ", count: level + 1) }

        var body = ""
        body += "<nav>\n  <h2>Contents</h2>\n  <ol>\n"
        var level = 1
        for item in items {
            switch item {
            case .document(let doc):
                let anchor = Self.anchorId(doc: doc)
                let label = doc.tocLabel(style: options.tocStyle)
                body += "\(indent(level))<li><a href=\"#\(anchor)\">\(markdownItalics(escaped(label)))</a></li>\n"
            case .heading(let heading, let rawLevel):
                let target = Self.clampedLevel(rawLevel)
                while level > target {
                    level -= 1
                    body += "\(indent(level))</ol></li>\n"
                }
                while level < target {
                    body += "\(indent(level))<li class=\"toc-sub\"><ol>\n"
                    level += 1
                }
                body += "\(indent(level))<li class=\"toc-section\">\(markdownItalics(escaped(heading)))</li>\n"
            case .prose:
                break
            }
        }
        while level > 1 {
            level -= 1
            body += "\(indent(level))</ol></li>\n"
        }
        body += "  </ol>\n</nav>\n\n"
        return body
    }

    /// Assembles a complete standalone HTML page: shared `<head>` (title + embedded CSS),
    /// header block, optional word-cloud figure, ToC, and every item fragment in order.
    ///
    /// The HTML export writes this string to a file; the live preview loads the identical
    /// string into a `WKWebView` — one assembly path for both consumers.
    ///
    /// - Parameters:
    ///   - metadata: The collection's display snapshot.
    ///   - items: The ordered, pre-resolved items to render.
    ///   - wordCloudPNGBase64: Optional base64-encoded PNG for the word-cloud overview
    ///     figure (export-only; the preview passes `nil`).
    /// - Returns: A full `<!DOCTYPE html>…</html>` document string.
    func pageHTML(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        wordCloudPNGBase64: String? = nil
    ) -> String {
        let title = escaped(metadata.name)
        var body = ""

        // Header
        body += headerHTML(metadata: metadata)

        // Word-cloud overview (optional), embedded as a base64 PNG
        if let base64 = wordCloudPNGBase64 {
            body += "<figure class=\"word-cloud\">\n"
            body += "  <img alt=\"Word cloud of the most frequent terms in this collection\" "
            body += "src=\"data:image/png;base64,\(base64)\" style=\"max-width:100%;height:auto;\" />\n"
            body += "  <figcaption>Most frequent terms in this collection</figcaption>\n"
            body += "</figure>\n\n"
        }

        // Table of contents — label style controlled by options.tocStyle.
        body += tableOfContentsHTML(for: items)

        // Body items — documents render as sections; headings and prose interleave in order.
        for item in items {
            body += itemHTML(item)
        }

        // Colophon footer (Authoring Phase 4) — opt-in only, so collections that never
        // enable it keep their pre-Phase-4 bytes.
        if metadata.includeColophon {
            body += "<footer class=\"colophon\">\n"
            body += "  <p>\(escaped(CollectionColophon.text(for: items)))</p>\n"
            body += "</footer>\n\n"
        }

        // Frame styles (Authoring Phase 4) are appended ONLY when a frame feature is
        // actually used; a no-frame collection interpolates an empty string, keeping the
        // exported file byte-identical to the pre-Phase-4 output.
        let frameStyles = Self.usesFrameFeatures(metadata: metadata, items: items)
            ? "\n" + Self.frameCSS : ""
        // Preview-only card styles are appended ONLY when a preview affordance is
        // configured; the export path interpolates an empty string here, keeping the
        // exported file byte-identical to the pre-preview output (v1.2).
        let previewStyles = isPreviewConfigured ? "\n" + Self.previewCSS : ""
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>\(title)</title>
          <style>
            \(Self.embeddedCSS)\(frameStyles)\(previewStyles)
          </style>
        </head>
        <body>
          \(body)
        </body>
        </html>
        """
    }

    /// `true` when the page uses any Phase 4 publication-frame feature — a set subtitle or
    /// author line, the colophon opt-in, or a heading nested deeper than level 1. Gates
    /// `frameCSS` so a collection using no new feature emits the exact pre-Phase-4 bytes.
    static func usesFrameFeatures(metadata: CollectionExportMetadata,
                                  items: [CollectionExportItem]) -> Bool {
        if let subtitle = metadata.subtitle, !subtitle.isEmpty { return true }
        if let author = metadata.authorLine, !author.isEmpty { return true }
        if metadata.includeColophon { return true }
        return items.contains {
            if case .heading(_, let level) = $0 { return level > 1 }
            return false
        }
    }

    // MARK: - Anchors

    /// Stable per-document anchor id (`doc-{volumeId}-{documentId}`, non-alphanumerics
    /// collapsed to `-`) — shared by the ToC links, the exported sections, and the
    /// preview's scroll-to-row targets.
    ///
    /// - Parameter doc: The document whose anchor id to compute.
    /// - Returns: A sanitized HTML id string.
    static func anchorId(doc: CollectionExportDocument) -> String {
        "doc-\(doc.volumeId)-\(doc.documentId)"
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
    }

    // MARK: - Embedded CSS (Session 146)

    /// Combined CSS for the assembled HTML page.
    ///
    /// Layer 1: CSS custom properties (light mode, medium text size) from `FRUSTheme`.
    /// Layer 2: Document body styles shared with the in-app WKWebView renderer
    ///          (`HTMLTemplate.documentCSS`).
    /// Layer 3: Collection-export-specific layout (header, nav, section, research-note).
    /// Layer 4: Print overrides.
    static var embeddedCSS: String {
        FRUSTheme.cssVariables(colorScheme: .light, textSize: .large)
        + "\n" + HTMLTemplate.documentCSS
        + "\n" + collectionExportCSS
        + "\n" + FRUSRenderNodeHTMLSerializer.highlightCSS
        + "\n" + printCSS
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

    /// Publication-frame styles (v1.3) — title-page subtitle/author lines, nested-ToC
    /// sub-lists, stepped sub-section headings, and the colophon footer. Emitted by
    /// `pageHTML` **only when a frame feature is used** (`usesFrameFeatures`), so a
    /// collection using none exports byte-identically to the pre-Phase-4 output.
    private static let frameCSS = """
    /* ── Publication frame (Authoring Phase 4) ─────────────────────────────── */
    .collection-subtitle {
      margin-top: 0.6rem;
      font-size: 1.2rem;
      color: #333;
    }
    .collection-author {
      margin-top: 0.4rem;
      font-size: 0.95rem;
      color: #555;
    }
    nav li.toc-sub { list-style: none; }
    nav .toc-sub > ol { padding-left: 1.25rem; margin-top: 0.3rem; }
    h3.section-heading { font-size: 1.35rem; margin-left: 0.75rem; }
    h4.section-heading { font-size: 1.15rem; margin-left: 1.5rem; }
    footer.colophon {
      margin-top: 3rem;
      border-top: 1px solid #ddd;
      padding-top: 1rem;
      font-size: 0.8rem;
      color: #777;
    }
    """

    /// Preview-only card styles (v1.2) — the citation-only card (volume not downloaded)
    /// and the summary-placeholder card. Emitted by `pageHTML` **only when a preview
    /// affordance is configured** (`isPreviewConfigured`), never by exporters, so the
    /// exported stylesheet — and therefore the exported file's bytes — are identical to
    /// the pre-Phase-2b output (`htmlExportMatchesSharedRenderer` holds this line).
    private static let previewCSS = """
    /* ── Citation-only card (preview: volume not downloaded) ──────────────── */
    .citation-card {
      border: 1px dashed #b08c3e;
      background: #fdf8ee;
      border-radius: 6px;
      padding: 1rem 1.25rem;
      margin: 1rem 0;
    }
    .citation-card-citation { font-style: italic; color: #444; }
    .citation-card-note {
      margin-top: 0.5rem;
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #a06a00;
    }

    /* ── Summary-placeholder card (preview: summary pending at export) ─────── */
    .summary-placeholder {
      border: 1px dashed #3a6bc9;
      background: #f0f4ff;
      border-radius: 6px;
      padding: 1rem 1.25rem;
      margin: 1rem 0;
    }
    .summary-placeholder-note {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: #3a6bc9;
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

    /// Renders a rich-text prose block — supplied as **RTF** (or a legacy Phase 3b JSON blob,
    /// which the shared decoder recovers rather than dropping) — to an HTML fragment:
    /// bold/italic/underline/colour runs map to `<strong>`/`<em>`/`<u>`/`<span style=color>`,
    /// blank lines to `<p>` boundaries, single newlines to `<br>`. Formatting is decoded once
    /// by the shared `CollectionProse.paragraphs(fromRTF:)`, which resolves paragraph breaks
    /// *before* spans are emitted so open/close tags never straddle a `<p>`.
    private func proseHTML(_ rtf: Data) -> String {
        let paragraphs = CollectionProse.paragraphs(fromRTF: rtf)
        guard !paragraphs.isEmpty else { return "" }

        var out = "<div class=\"prose-block\">\n"
        for paragraph in paragraphs {
            let html = paragraph.map { span -> String in
                var open = "", close = ""
                if span.bold      { open += "<strong>"; close = "</strong>" + close }
                if span.italic    { open += "<em>";     close = "</em>" + close }
                if span.underline { open += "<u>";      close = "</u>" + close }
                if let hex = span.colorHex { open += "<span style=\"color:#\(hex)\">"; close = "</span>" + close }
                return open + escaped(span.text).replacingOccurrences(of: "\n", with: "<br>\n") + close
            }.joined()
            if !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out += "  <p>\(html)</p>\n"
            }
        }
        out += "</div>\n\n"
        return out
    }

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

    /// Escapes the four HTML-reserved characters (`&`, `<`, `>`, `"`) in `text`.
    private func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
