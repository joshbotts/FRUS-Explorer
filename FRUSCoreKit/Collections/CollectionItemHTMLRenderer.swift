// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

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
///     Documents keep their stable `anchorId(doc:)` anchors (a later entry numbered), inline highlight injection
///     (via `FRUSRenderNodeHTMLSerializer`), body-depth handling, source-note and
///     research-note blocks — exactly as the HTML export has always emitted them.
///   - `headerHTML(metadata:)`, `tableOfContentsHTML(for:)` — the page header and ToC nav.
///   - `pageHTML(metadata:items:wordCloudPNGBase64:)` — assembles a complete standalone
///     HTML page (shared `<head>`/CSS + header + ToC + every item fragment) — the exporter
///     writes this string to disk; the preview loads it into a `WKWebView`.
///   - `embeddedCSS` — the shared stylesheet: the reader page's variables and document layer
///     (FRUSCoreKit's `ReaderPage`, which the app's `FRUSTheme.cssVariables` and
///     `HTMLTemplate.documentCSS` forward to) + collection layout + highlight + print layers.
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
///   1.4 — Authoring Phase 5: footnote inclusion keys off `options.includeFootnotes`
///          (previously `footnoteStyle == .all`; the caller-side nil-pair derivation
///          keeps every legacy tri-state value byte-identical); opt-in headnote block —
///          an italic abstract above the body, or a placeholder note when the entry
///          requested one and no summary is stored — with its stylesheet (`headnoteCSS`)
///          emitted ONLY when some document carries a headnote request
///   1.5 — Authoring Phase 5 (excerpts): `.excerpt` items render as a styled
///          `<figure class="excerpt-block">` — blockquote passage + source-citation
///          line, with a per-colour accent class when the source highlight's colour is
///          known — omitted from the ToC like prose; the stylesheet (`excerptCSS`) is
///          emitted ONLY when the item list contains an excerpt, so excerpt-free
///          collections keep exporting byte-identically
///   1.6 — Authoring Phase 5 (overrides + related documents): footnote, highlight, and
///          research-note gates honor the document's resolved per-entry override when
///          present (`doc.x ?? options.x` — nil payloads keep the collection-level
///          behavior bit-for-bit); a non-empty `relatedDocumentCitations` renders the
///          "See also:" line after the source note, with its stylesheet (`relatedCSS`)
///          emitted ONLY when some document carries the line
///   1.7 — Authoring Phase 6 (generated apparatus): `.generated` items render as a
///          titled `<section class="generated-block">` with a plain row list (text +
///          optional secondary text, linked when the row carries a URL, stepped by
///          indent level); ToCs list the block by title like a section. The stylesheet
///          (`generatedCSS`) is emitted ONLY when the item list contains a generated
///          block, so block-free collections keep exporting byte-identically
///   1.8 — Session 2026-07-03 (prose links): a prose span carrying a `.link` attribute
///          (the rich-text editor's Link control, round-tripped through RTF) renders as
///          an outermost `<a href>` around its formatted text; link-free prose is
///          byte-identical to the 1.7 output
///   1.9 — Session 2026-07-03 (AI attribution): every rendered generated summary — a
///          `.summaryOnly` body block or a filled headnote — carries the shared
///          `CollectionAIAttribution` caption line, with its stylesheet
///          (`attributionCSS`) emitted ONLY when some item actually renders one
///          (`usesAIAttribution`), so a summary-free collection exports byte-identically
///   1.10 — Collections Manager M3 (D4 + review finding 2): the document heading and the
///          citation-only preview card both render `doc.exportHeading` (title override when
///          set, else `citation.isEmpty ? title : citation`), so an entry's `titleOverride`
///          shows in the exported heading AND the un-downloaded preview card; byte-identical
///          to the prior output when no override is set
///   1.11 — #1392: the "See also:" line takes each citation's closing period off before
///          the "; " join (`CitationPunctuation`) and ends in one, instead of printing
///          "…, Document 3.; …"
///   1.12 — #1465: a heading with no text prints as "Untitled section", set apart by the preview stylesheet, in its
///          body element and its Contents row. Only the preview meets one — an export's resolve leaves it out — so
///          exported HTML is unchanged for every heading that has text
///   1.13 — 2026-10-09: #1602 — four of this layer's text colours reach 4.5:1 against the
///          backgrounds they are drawn on: the contents panel's page numbers and the
///          AI-attribution caption (#888 to #6e6e6e), the colophon and the "See also" label
///          (#777 to #757575), and the preview's citation-only card note (#a06a00 to #986500)
///   1.14 — 2026-10-25 (FRUS Explorer Light, S18a): a prose item carries the spans the resolver
///          decoded, which `proseHTML` renders as it rendered `CollectionProse`'s; the colophon is
///          dated by `CollectionExportMetadata.exportDate`, `nil` being now, as before
///   1.15 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public. The stylesheet's
///          first two layers are `ReaderPage`'s, which `FRUSTheme.cssVariables` and
///          `HTMLTemplate.documentCSS` forward to, so the page is the same to the byte; a figure's
///          image comes from the `FigureImageSource` the host passes in (`figureImages`), where it
///          came from the app's `FigureImageStore.shared`, which the app now passes
///   1.16 — 2026-10-31: a structured summary, in a `.summaryOnly` body or a headnote, prints as its
///          fields (`StructuredSummaryDisplay`), a paragraph each opening with its label in
///          `<strong>`, where it printed its stored JSON; a `.general` summary prints as before
///   1.17 — L29 (#2000): a document's research notes print by `CollectionExportDocument.includesNotes(options:)`,
///          the rule BibTeX, RIS, the Zotero send and a shared file now carry them by; no change to the page
///   1.18 — L34: the page draws the export's plan (`CollectionExportPlan`). A document prints its plan's
///          lines in order: a title of the author's leads, with the citation as a line of its own and
///          *As published:* inside the volume's heading (#1998); the source note prints once (#1991); a
///          call whose note does not print is its number as text (#2007); each heading takes its level
///          in the collection's outline (J32); and a requested headnote with nothing stored prints
///          nothing, the preview alone showing its author the placeholder (J10). The contents list
///          writes its own numbers, the documents' alone (#1993), from the plan's rows
///   1.19 — L36 (#2004): a document entered twice is two places. Its second entry's anchor is the first's
///          with `_2` (`anchorIds(forDocuments:)`), its third's `_3`, and so for its section, its contents
///          row and its notes' ids, which the anchor scopes; a document entered once keeps its anchor
public struct CollectionItemHTMLRenderer {

    /// Rendering options shared with the exporters — controls the ToC label style,
    /// footnote inclusion, inline highlight annotation, and research-note visibility.
    public let options: CollectionExportOptions

    /// Volume ids whose documents render as **citation-only cards** — a bordered card
    /// carrying the citation and a "Volume not downloaded" note — instead of a body.
    /// Set only by the live preview (whose `.preview` resolution yields empty bodies
    /// for un-downloaded volumes); exporters leave it empty, so the HTML export byte
    /// output is unaffected.
    public var citationOnlyVolumeIds: Set<String> = []

    /// When `true`, a `.summaryOnly` document with no stored summary renders a
    /// **summary-placeholder card** (styled like the citation card) noting that the
    /// summary will be generated at export, instead of an empty body. Set only by the
    /// live preview, whose `.preview` resolution never generates summaries; exporters
    /// leave it `false` — an `.export` resolve either attaches a summary or throws, so
    /// export output never contains the placeholder.
    public var showsSummaryPlaceholders: Bool = false

    /// Where a figure's image comes from (#1516): the page embeds each one's bytes, so an
    /// exported file carries its images and the preview draws them without the reader's scheme
    /// handler. The host's source: the app passes its `FigureImageStore.shared`, a test its own,
    /// and a renderer given none prints each figure's placeholder.
    public var figureImages: any FigureImageSource = NoFigureImages()

    /// `true` when any preview-only affordance is configured — the gate for emitting the
    /// preview-only card stylesheet (`previewCSS`). Exporters set neither property, so
    /// exported HTML stays byte-identical to the pre-preview output.
    private var isPreviewConfigured: Bool {
        showsSummaryPlaceholders || !citationOnlyVolumeIds.isEmpty
    }

    /// Creates a renderer with the given export options.
    ///
    /// - Parameter options: Rendering options; defaults preserve the standard export look.
    public init(options: CollectionExportOptions = CollectionExportOptions()) {
        self.options = options
    }

    // MARK: - Per-Item Fragment

    /// Renders one collection item to its HTML fragment — THE shared per-item function.
    ///
    /// - `.heading` → a level-stepped heading element with class `section-heading`:
    ///   level 1 → `<h2>` (byte-identical to the pre-Phase-4 output), level 2 → `<h3>`,
    ///   level 3 → `<h4>`. Out-of-range levels clamp defensively. A heading with no text — which only the preview
    ///   receives — prints as "Untitled section" (#1465).
    /// - `.prose` → a `<div class="prose-block">` of formatted paragraphs (or empty when
    ///   the payload decodes to nothing).
    /// - `.excerpt` → a `<figure class="excerpt-block">`: blockquote passage + a
    ///   source-citation line, with a colour-accent class when the source highlight's
    ///   colour is known (Authoring Phase 5).
    /// - `.generated` → a titled `<section class="generated-block">` with a plain row
    ///   list (Authoring Phase 6).
    /// - `.document` → a full `<section id="doc-…">` with citation heading, external link,
    ///   body (per the document's `bodyDepth`), highlights, source note, and research notes.
    ///
    /// - Parameter item: The resolved item to render; a document takes the anchor of its first entry.
    /// - Returns: An HTML fragment string (may be empty for an empty prose payload).
    public func itemHTML(_ item: CollectionExportItem) -> String {
        itemHTML(CollectionExportPlan(items: [item], options: options, forPreview: isPreviewConfigured).items[0])
    }

    /// Renders one item of an export's plan: a document as its plan's lines, at the level its section
    /// gives it (L34), under `anchor`, its entry's place on the page (L36, #2004).
    ///
    /// - Parameters:
    ///   - planned: The item and its plan.
    ///   - anchor: A document's anchor on the page (`anchorIds(forDocuments:)`); `nil` for its first entry's.
    /// - Returns: An HTML fragment string.
    func itemHTML(_ planned: CollectionExportPlan.Item, anchor: String? = nil) -> String {
        switch planned.item {
        case .heading(let heading, let level):
            let tag = "h\(Self.clampedLevel(level) + 1)"   // level 1 → h2 (pre-Phase-4), 2 → h3, 3 → h4
            return "<\(tag) class=\"\(Self.headingClass("section-heading", heading))\">"
                + "\(headingText(heading))</\(tag)>\n\n"
        case .prose(let prose):
            return proseHTML(prose)
        case .excerpt(let excerpt):
            return excerptHTML(excerpt)
        case .generated(let block):
            return generatedBlockHTML(block)
        case .document(let doc):
            guard let plan = planned.document else { return "" }
            return documentSectionHTML(doc, plan: plan, anchor: anchor ?? Self.anchorId(doc: doc))
        }
    }

    /// Renders a generated apparatus block (Authoring Phase 6): a titled section with a
    /// plain row list — per-block designed layouts are a later exporter-local upgrade.
    /// Rows render their text (linked when the row carries a URL), optional secondary
    /// text, and an `indent-{n}` class when nested.
    ///
    /// - Parameter block: The pre-resolved block payload.
    /// - Returns: The `<section class="generated-block …">…</section>` HTML fragment.
    private func generatedBlockHTML(_ block: CollectionGeneratedBlock) -> String {
        var body = ""
        body += "<section class=\"generated-block generated-\(block.type.rawValue)\">\n"
        body += "  <h2 class=\"generated-title\">\(markdownItalics(escaped(block.title)))</h2>\n"
        body += "  <ul class=\"generated-rows\">\n"
        for row in block.rows {
            let indentClass = row.indentLevel > 0 ? " indent-\(min(row.indentLevel, 4))" : ""
            body += "    <li class=\"generated-row\(indentClass)\">"
            if let url = row.url, !url.isEmpty {
                body += "<a href=\"\(escaped(url))\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body += markdownItalics(escaped(row.text))
                body += "</a>"
            } else {
                body += markdownItalics(escaped(row.text))
            }
            if let secondary = row.secondaryText, !secondary.isEmpty {
                body += " <span class=\"generated-secondary\">\(markdownItalics(escaped(secondary)))</span>"
            }
            body += "</li>\n"
        }
        body += "  </ul>\n"
        body += "</section>\n\n"
        return body
    }

    /// Renders an excerpt item (Authoring Phase 5): the frozen passage as a blockquote
    /// (paragraphs split on blank lines, verbatim — no markdown transforms, the text is
    /// primary-source material) followed by the auto-citation source line. When the
    /// excerpt carries a known highlight colour, the figure gains an
    /// `excerpt-{color}` accent class; an empty citation omits the source line.
    ///
    /// - Parameter excerpt: The resolved excerpt payload.
    /// - Returns: The `<figure class="excerpt-block">…</figure>` HTML fragment.
    private func excerptHTML(_ excerpt: CollectionExportExcerpt) -> String {
        var classes = "excerpt-block"
        if let color = excerpt.color { classes += " excerpt-\(color.rawValue)" }
        var body = ""
        body += "<figure class=\"\(classes)\">\n"
        body += "  <blockquote>\n"
        let paragraphs = excerpt.text
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for para in paragraphs {
            body += "    <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
        }
        body += "  </blockquote>\n"
        if !excerpt.citation.isEmpty {
            body += "  <figcaption class=\"excerpt-source\">"
            body += markdownItalics(escaped(excerpt.citation))
            body += "</figcaption>\n"
        }
        body += "</figure>\n\n"
        return body
    }

    /// Defensively clamps a heading level to `1...CollectionOutline.maxLevel` — producers
    /// already emit outline-resolved levels, so this only guards direct callers.
    private static func clampedLevel(_ level: Int) -> Int {
        min(max(level, 1), CollectionOutline.maxLevel)
    }

    /// Whether a heading has no text once trimmed — a Section heading its author has not named (#1465).
    private static func isUntitled(_ heading: String) -> Bool {
        heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The class list of a heading's element, body or Contents row: `base`, and `untitled-section` beside it for a
    /// heading with no text, which the preview's stylesheet sets apart (#1465).
    private static func headingClass(_ base: String, _ heading: String) -> String {
        isUntitled(heading) ? "\(base) untitled-section" : base
    }

    /// A heading's text as the page prints it, in its body element and its Contents row: its own, or "Untitled
    /// section" when it has none (#1465).
    ///
    /// Only the live preview meets an untitled heading — an export's resolve leaves it out
    /// (`CollectionContentResolver`, decision D4) — so the HTML export prints what it always did, and the preview shows
    /// its author a section they made and have not named, where it printed an empty heading and a Contents row of
    /// "1." and nothing.
    private func headingText(_ heading: String) -> String {
        Self.isUntitled(heading)
            ? escaped(CollectionEditorNaming.untitledSection)
            : markdownItalics(escaped(heading))
    }

    /// Renders a resolved document as a `<section>` fragment: its plan's lines in order (L34). The
    /// leading line (a title of the author's, or the citation linked to history.state.gov) is a heading
    /// at the level the document's section gives it; the volume's heading follows inside the text, or as
    /// a line of its own where the text does not print. A requested headnote with nothing stored prints
    /// nothing in an export (J10); the live preview shows its author the placeholder.
    ///
    /// - Parameters:
    ///   - doc: The pre-resolved document payload.
    ///   - plan: The document's plan.
    ///   - anchor: The section's id, its entry's own (#2004), which also scopes the ids of its notes.
    /// - Returns: The document's `<section id="doc-…">…</section>` HTML fragment.
    private func documentSectionHTML(_ doc: CollectionExportDocument, plan: CollectionDocumentPlan,
                                     anchor: String) -> String {
        var body = ""
        // Where the volume's heading leads, the region carries the citation's number, which a reader
        // moving by landmarks hears where the headings repeat (J16).
        let region = plan.regionName.map { " aria-label=\"\(escaped($0))\"" } ?? ""
        body += "<section id=\"\(anchor)\"\(region)>\n"

        // The preview's own lines stand where the document's body begins: the missing headnote's
        // placeholder, then the citation-only card of a volume not downloaded, or the summary card of a
        // summary not yet generated. An export sets none of them.
        let citationOnly = citationOnlyVolumeIds.contains(doc.volumeId)
        var bodyBegun = false
        func beginBody() {
            guard !bodyBegun else { return }
            bodyBegun = true
            if plan.isHeadnoteMissing { body += headnoteMissingHTML() }
            if citationOnly {
                body += citationOnlyCardHTML(doc)
            } else if doc.bodyDepth == .summaryOnly, showsSummaryPlaceholders,
                      !plan.lines.contains(where: { $0.role == .summary }) {
                body += summaryPlaceholderCardHTML()
            }
        }

        for line in plan.lines {
            switch line.role {
            case .title, .titleDateLine, .citation, .address, .headnote:
                break
            default:
                beginBody()
            }
            switch line.role {
            case .title:
                body += "  " + Self.headingHTML(level: line.headingLevel ?? plan.documentLevel, cssClass: "doc-lead",
                                                content: markdownItalics(escaped(line.text))) + "\n"
            case .titleDateLine:
                // The author's date line under their title (L43), drawn as a dateline is; its own class names it.
                body += "  <p class=\"dateline title-date-line\">\(escaped(line.text))</p>\n"
            case .citation:
                let text = markdownItalics(escaped(line.text))
                let linked = line.link.map {
                    "<a href=\"\(escaped($0))\" class=\"doc-ext-link\" target=\"_blank\" rel=\"noopener noreferrer\">\(text)</a>"
                } ?? text
                if let level = line.headingLevel {
                    body += "  " + Self.headingHTML(level: level, cssClass: "doc-lead", content: linked) + "\n"
                } else {
                    body += "  <p class=\"doc-citation\">\(linked)</p>\n"
                }
            case .address:
                body += "  <p class=\"doc-url\">"
                body +=     "<a href=\"\(escaped(line.link ?? line.text))\" target=\"_blank\" rel=\"noopener noreferrer\">"
                body +=     "\(escaped(line.text))</a></p>\n"
            case .headnote:
                body += headnoteHTML(line)
            case .text:
                // A document whose volume is not downloaded has its card in the preview instead.
                guard !citationOnly else { break }
                if let drawing = line.drawing, let model = doc.renderModel {
                    // #985: this page carries many documents, and a footnote DOM key is only unique
                    // within one, so each document's ids are scoped by its anchor, its entry's own since
                    // #2004. #1516: a figure's image is embedded in the page, from the device's figure store.
                    let images = figureImages
                    body += FRUSRenderNodeHTMLSerializer(
                        idScope: "\(anchor)-",
                        figureImages: .embedded(load: { images.data(for: $0) }),
                        headings: .init(document: drawing.headingLevel, attachment: drawing.attachmentHeadingLevel,
                                        notes: drawing.notesHeadingLevel, label: drawing.headingLabel)
                    ).serialize(
                        model,
                        footnotes: drawing.footnotes,
                        highlights: drawing.appliesHighlights ? doc.highlights : []
                    )
                } else {
                    let paragraphs = line.text
                        .components(separatedBy: "\n\n")
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    for para in paragraphs {
                        body += "  <p>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</p>\n"
                    }
                }
            case .volumeHeading:
                let label = line.label.map { "<span class=\"as-published\">\(escaped($0)) </span>" } ?? ""
                body += "  " + Self.headingHTML(level: line.headingLevel ?? plan.documentLevel + 1,
                                                cssClass: "doc-heading", content: label + escaped(line.text)) + "\n"
            case .dateline:
                body += "  <p class=\"dateline\">\(escaped(line.text))</p>\n"
            case .summary:
                guard !citationOnly else { break }
                body += "  <div class=\"summary-block\">\n"
                body += "    <p class=\"summary-label\">\(escaped(line.label ?? ""))</p>\n"
                for para in summaryParagraphsHTML(line.text, format: line.format) {
                    body += "    <p>\(para)</p>\n"
                }
                // AI attribution (v1.9) — generated text is always labeled in exports,
                // mirroring the in-app "AI summary" badge.
                if let attribution = line.attribution {
                    body += "    <p class=\"ai-attribution\">\(escaped(attribution))</p>\n"
                }
                body += "  </div>\n"
            case .sourceNote:
                body += "  <p class=\"source-note\"><strong>\(escaped(line.label ?? ""))</strong> "
                    + "\(escaped(line.text))</p>\n"
            case .seeAlso:
                body += "  <p class=\"see-also\"><strong>\(escaped(line.label ?? ""))</strong> "
                    + "\(markdownItalics(escaped(line.text)))</p>\n"
            case .researchNote:
                body += "  <aside class=\"research-note\">\n"
                body += "    <strong>\(escaped(line.label ?? ""))</strong>\n"
                let noteParagraphs = line.text
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                for para in noteParagraphs {
                    body += "    <p>\(markdownItalics(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines))))</p>\n"
                }
                body += "  </aside>\n"
            }
        }
        beginBody()

        body += "</section>\n\n"
        return body
    }

    /// A heading element at `level`: `h1` to `h6`, or past six a paragraph with the heading role and its
    /// level (J32), as the serializer writes the document's own.
    static func headingHTML(level: Int, cssClass: String, content: String) -> String {
        let level = max(level, 1)
        if level <= 6 { return "<h\(level) class=\"\(cssClass)\">\(content)</h\(level)>" }
        return "<p class=\"\(cssClass)\" role=\"heading\" aria-level=\"\(level)\">\(content)</p>"
    }

    /// The citation-only card emitted (preview only) for a document whose volume is not
    /// downloaded: a bordered card with the document heading and a localized "Volume not
    /// downloaded" note. The *download* affordance is native (a bar above the preview's
    /// web view), never in-page JS.
    ///
    /// Uses `exportHeading` (M3, finding 2) so a `titleOverride` set on the entry shows here
    /// too — matching the heading the same document renders once its volume is downloaded and
    /// in the exported HTML/PDF/DOCX. When no override is set this is byte-identical to the
    /// former `citation.isEmpty ? title : citation`.
    ///
    /// - Parameter doc: The citation-only document (empty body, no render model).
    /// - Returns: The card's `<div class="citation-card">…</div>` HTML fragment.
    private func citationOnlyCardHTML(_ doc: CollectionExportDocument) -> String {
        let note = String(localized: "collection.preview.volumeNotDownloaded",
                          defaultValue: "Volume not downloaded — citation only")
        let citation = doc.exportHeading
        var body = ""
        body += "  <div class=\"citation-card\">\n"
        body += "    <p class=\"citation-card-citation\">\(markdownItalics(escaped(citation)))</p>\n"
        body += "    <p class=\"citation-card-note\">\(escaped(note))</p>\n"
        body += "  </div>\n"
        return body
    }

    /// The headnote block (Authoring Phase 5): a labeled, italic abstract rendered above the volume's
    /// words, and the caption that says who wrote it. It is drawn only where a headnote is stored: since
    /// L34 an export prints nothing for a requested headnote with nothing stored (J10), where 1.0 printed
    /// the author an instruction in a file made for a reader.
    ///
    /// - Parameter line: The plan's headnote line: its text, the format it was written in, its label and
    ///   its attribution.
    /// - Returns: The `<div class="headnote">…</div>` HTML fragment.
    private func headnoteHTML(_ line: CollectionDocumentPlan.Line) -> String {
        var body = ""
        body += "  <div class=\"headnote\">\n"
        body += "    <p class=\"headnote-label\">\(escaped(line.label ?? ""))</p>\n"
        for para in summaryParagraphsHTML(line.text, format: line.format) {
            body += "    <p><em>\(para)</em></p>\n"
        }
        // Attribution honors the headnote's authorship (Composer redesign): an AI headnote keeps
        // the AI label, an AI-edited one discloses the edit, a user-written one shows none.
        if let attribution = line.attribution {
            body += "    <p class=\"ai-attribution\">\(escaped(attribution))</p>\n"
        }
        body += "  </div>\n"
        return body
    }

    /// The live preview's placeholder for a requested headnote with nothing stored: the label, and a
    /// sentence telling the author how to fill it. An export never draws it (J10).
    private func headnoteMissingHTML() -> String {
        let label = String(localized: "collection.headnote.label", defaultValue: "Headnote")
        let missing = String(localized: "collection.headnote.missing",
                             defaultValue: "No stored summary for this document — generate one in the document view to fill this headnote.")
        return "  <div class=\"headnote\">\n"
            + "    <p class=\"headnote-label\">\(escaped(label))</p>\n"
            + "    <p class=\"headnote-missing\">\(escaped(missing))</p>\n"
            + "  </div>\n"
    }

    /// A stored summary's paragraphs, escaped, without their `<p>`: a structured summary's fields, each
    /// opening with its label in `<strong>` (`StructuredSummaryDisplay`), else the text's own
    /// paragraphs (split at blank lines and trimmed), as they printed before 2026-10-31.
    ///
    /// - Parameters:
    ///   - text: The summary's stored text.
    ///   - format: The format it was written in.
    /// - Returns: The inner HTML of each paragraph, in order.
    private func summaryParagraphsHTML(_ text: String, format: ResponseFormat) -> [String] {
        if let fields = StructuredSummaryDisplay.fields(responseText: text, format: format) {
            return fields.map { field in
                let label = "<strong>\(escaped(field.label)):</strong>"
                return field.text.isEmpty ? label : "\(label) \(escaped(field.text))"
            }
        }
        return text
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { escaped($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
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
    public func headerHTML(metadata: CollectionExportMetadata) -> String {
        var body = ""
        body += "<header>\n"
        body += "  <h1>\(escaped(metadata.name))</h1>\n"
        if let subtitle = metadata.subtitle, !subtitle.isEmpty {
            body += "  <p class=\"collection-subtitle\">\(markdownItalics(escaped(subtitle)))</p>\n"
        }
        if let author = metadata.authorLine, !author.isEmpty {
            body += "  <p class=\"collection-author\">\(escaped(author))</p>\n"
        }
        if let projectName = metadata.projectName, !projectName.isEmpty {
            let label = String(localized: "export.frontmatter.project", defaultValue: "Project")
            body += "  <p class=\"collection-project\">\(escaped(label)): \(escaped(projectName))</p>\n"
            if let question = metadata.projectResearchQuestion, !question.isEmpty {
                body += "  <p class=\"collection-project-question\">\(markdownItalics(escaped(question)))</p>\n"
            }
        }
        if let note = metadata.note, !note.isEmpty {
            body += "  <p class=\"collection-note\">\(markdownItalics(escaped(note)))</p>\n"
        }
        body += "</header>\n\n"
        return body
    }

    /// Renders the table of contents `<nav>`: the export plan's rows (`CollectionContentsRow`, L34).
    /// Documents become anchor links; headings appear as (non-link) section labels; prose
    /// blocks are omitted.
    ///
    /// **The list writes its own numbers, and numbers the documents alone** (#1993): "4. " before the
    /// fourth document's row, none before a section's heading or a block's title. Until L34 the browser
    /// numbered every row of the ordered list, so the fourth document was row 6 where the PDF and Word
    /// call it 4. The list keeps `role="list"`, which WebKit drops from a list drawn without markers.
    /// A row's lines in small type (*As published:* and the volume's heading under a title of the
    /// author's, #1998) are inside its link, so a reader moving by links hears them with the row.
    ///
    /// Heading levels drive **nested lists** (Authoring Phase 4): a deeper heading opens a
    /// `<li class="toc-sub"><ol>` wrapper (valid nesting — the sub-list lives inside an
    /// `<li>`), and documents nest inside the list of their owning section.
    ///
    /// Each document row links to its entry's own section (#2004), so a document entered twice has two rows
    /// that lead to two places.
    ///
    /// - Parameter items: The ordered items whose documents and headings populate the ToC.
    /// - Returns: The `<nav>…</nav>` HTML fragment.
    public func tableOfContentsHTML(for items: [CollectionExportItem]) -> String {
        tableOfContentsHTML(rows: CollectionContentsRow.rows(for: items, style: options.tocStyle),
                            anchors: Self.anchorIds(forDocuments: items.documents))
    }

    /// Renders the table of contents `<nav>` from the plan's rows, the document numbered *n* linking to
    /// `anchors[n - 1]`, its entry's anchor.
    func tableOfContentsHTML(rows: [CollectionContentsRow], anchors: [String]) -> String {
        /// Line indentation for list items at a nesting level (level 1 = the pre-Phase-4
        /// four spaces; each deeper level adds two).
        func indent(_ level: Int) -> String { String(repeating: "  ", count: level + 1) }

        var body = ""
        body += "<nav>\n  <h2>\(escaped(options.wording.text(for: .contents)))</h2>\n  <ol role=\"list\">\n"
        var level = 1
        for row in rows {
            switch row.kind {
            case .document(let number):
                guard let doc = row.document else { continue }
                let anchor = anchors.indices.contains(number - 1) ? anchors[number - 1] : Self.anchorId(doc: doc)
                let lines = row.lines.map { "<span class=\"toc-line\">\(markdownItalics(escaped($0)))</span>" }.joined()
                body += "\(indent(level))<li class=\"toc-document\"><a href=\"#\(anchor)\">"
                    + "<span class=\"toc-number\">\(number).</span> \(markdownItalics(escaped(row.text)))\(lines)</a></li>\n"
            case .section:
                let target = row.level
                while level > target {
                    level -= 1
                    body += "\(indent(level))</ol></li>\n"
                }
                while level < target {
                    body += "\(indent(level))<li class=\"toc-sub\"><ol role=\"list\">\n"
                    level += 1
                }
                body += "\(indent(level))<li class=\"\(Self.headingClass("toc-section", row.text))\">"
                    + "\(headingText(row.text))</li>\n"
            case .block:
                // A generated block is listed by title, like a section label (Phase 6);
                // it inherits the current nesting level without changing it.
                body += "\(indent(level))<li class=\"toc-section\">\(markdownItalics(escaped(row.text)))</li>\n"
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
    public func pageHTML(
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

        // The export's plan (L34): the contents rows and each document's lines, decided once for the
        // three formats.
        let plan = CollectionExportPlan(items: items, options: options, forPreview: isPreviewConfigured)
        // Each document's entry is a place of its own (#2004): one numbering for its row and its section.
        let anchors = Self.anchorIds(forDocuments: items.documents)

        // Table of contents — label style controlled by options.tocStyle.
        body += tableOfContentsHTML(rows: plan.contents, anchors: anchors)

        // Body items — documents render as sections; headings and prose interleave in order.
        var documents = 0
        for planned in plan.items {
            var anchor: String?
            if case .document = planned.item, anchors.indices.contains(documents) {
                anchor = anchors[documents]
                documents += 1
            }
            body += itemHTML(planned, anchor: anchor)
        }

        // Method appendix (M-2) — the project's query log, opt-in only. Placed before the
        // colophon: the colophon says how the artifact was produced, and this says how the
        // research inside it was done, which belongs with the content rather than after the
        // production note.
        if !metadata.methodAppendixLines.isEmpty {
            body += "<section class=\"method-appendix\">\n"
            for (index, line) in metadata.methodAppendixLines.enumerated() {
                if line.isEmpty { continue }
                if index == 0 {
                    body += "  <h2>\(escaped(line))</h2>\n"
                } else {
                    body += "  <p>\(escaped(line))</p>\n"
                }
            }
            body += "</section>\n\n"
        }

        // Colophon footer (Authoring Phase 4) — opt-in only, so collections that never
        // enable it keep their pre-Phase-4 bytes.
        if metadata.includeColophon {
            body += "<footer class=\"colophon\">\n"
            body += "  <p>\(escaped(CollectionColophon.text(for: items, dated: metadata.exportDate)))</p>\n"
            // PV-1: the sources block travels with the colophon, in all three rich formats.
            for line in CollectionColophon.sourceLines(for: items, embedsWordCloud: wordCloudPNGBase64 != nil) {
                body += "  <p>\(escaped(line))</p>\n"
            }
            body += "</footer>\n\n"
        }

        // Frame styles (Authoring Phase 4) are appended ONLY when a frame feature is
        // actually used; a no-frame collection interpolates an empty string, keeping the
        // exported file byte-identical to the pre-Phase-4 output.
        let frameStyles = Self.usesFrameFeatures(metadata: metadata, items: items)
            ? "\n" + Self.frameCSS : ""
        // Headnote styles (Authoring Phase 5) are appended ONLY when some document
        // carries a headnote request — same byte-compat discipline as the frame layer.
        let headnoteStyles = Self.usesHeadnotes(items: items) ? "\n" + Self.headnoteCSS : ""
        // Excerpt styles (Authoring Phase 5) are appended ONLY when the item list
        // contains an excerpt — same byte-compat discipline again.
        let excerptStyles = Self.usesExcerpts(items: items) ? "\n" + Self.excerptCSS : ""
        // Related-documents styles (Authoring Phase 5) are appended ONLY when some
        // document carries a "See also:" line — same byte-compat discipline again.
        let relatedStyles = Self.usesRelatedDocuments(items: items) ? "\n" + Self.relatedCSS : ""
        // Generated-block styles (Authoring Phase 6) are appended ONLY when the item
        // list contains a generated apparatus block — same byte-compat discipline again.
        let generatedStyles = Self.usesGeneratedBlocks(items: items) ? "\n" + Self.generatedCSS : ""
        // AI-attribution styles (v1.9) are appended ONLY when some item actually
        // renders a generated summary's attribution caption — same discipline again.
        let attributionStyles = Self.usesAIAttribution(items: items) ? "\n" + Self.attributionCSS : ""
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
            \(Self.embeddedCSS)\(frameStyles)\(headnoteStyles)\(excerptStyles)\(relatedStyles)\(generatedStyles)\(attributionStyles)\(previewStyles)
          </style>
        </head>
        <body>
          \(body)
        </body>
        </html>
        """
    }

    /// `true` when the page uses any Phase 4 publication-frame feature — a set subtitle or
    /// author line, the colophon opt-in, the M-2 method appendix, or a heading nested deeper
    /// than level 1. Gates
    /// `frameCSS` so a collection using no new feature emits the exact pre-Phase-4 bytes.
    public static func usesFrameFeatures(metadata: CollectionExportMetadata,
                                         items: [CollectionExportItem]) -> Bool {
        if let subtitle = metadata.subtitle, !subtitle.isEmpty { return true }
        if let author = metadata.authorLine, !author.isEmpty { return true }
        if metadata.includeColophon { return true }
        if !metadata.methodAppendixLines.isEmpty { return true }
        return items.contains {
            if case .heading(_, let level) = $0 { return level > 1 }
            return false
        }
    }

    /// `true` when any document item carries a headnote request (Authoring Phase 5).
    /// Gates `headnoteCSS` so a collection with no headnotes emits the exact
    /// pre-Phase-5 stylesheet bytes.
    public static func usesHeadnotes(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .document(let doc) = $0 { return doc.includeHeadnote }
            return false
        }
    }

    /// `true` when the item list contains an excerpt (Authoring Phase 5). Gates
    /// `excerptCSS` so an excerpt-free collection emits the exact prior stylesheet bytes.
    public static func usesExcerpts(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .excerpt = $0 { return true }
            return false
        }
    }

    /// `true` when some document carries a related-documents line (Authoring Phase 5).
    /// Gates `relatedCSS` so a collection with none emits the exact prior stylesheet bytes.
    public static func usesRelatedDocuments(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .document(let doc) = $0 { return !doc.relatedDocumentCitations.isEmpty }
            return false
        }
    }

    /// `true` when the item list contains a generated apparatus block (Authoring
    /// Phase 6). Gates `generatedCSS` so a block-free collection emits the exact prior
    /// stylesheet bytes.
    public static func usesGeneratedBlocks(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .generated = $0 { return true }
            return false
        }
    }

    /// `true` when some document actually renders an AI-attribution caption (v1.9) — a
    /// non-empty `.summaryOnly` summary body or a filled (non-placeholder) headnote.
    /// Gates `attributionCSS` so a collection rendering no generated summary emits the
    /// exact prior stylesheet bytes.
    public static func usesAIAttribution(items: [CollectionExportItem]) -> Bool {
        items.contains {
            guard case .document(let doc) = $0 else { return false }
            if doc.bodyDepth == .summaryOnly,
               let summary = doc.summaryText, !summary.isEmpty { return true }
            if doc.includeHeadnote,
               let headnote = doc.headnoteText, !headnote.isEmpty { return true }
            return false
        }
    }

    // MARK: - Anchors

    /// Stable per-document anchor id (`doc-{volumeId}-{documentId}`, non-alphanumerics
    /// collapsed to `-`): the anchor of a document's first entry on the page. A later entry of the
    /// same document takes ``anchorIds(forDocuments:)``'s numbered form.
    ///
    /// - Parameter doc: The document whose anchor id to compute.
    /// - Returns: A sanitized HTML id string.
    public static func anchorId(doc: CollectionExportDocument) -> String {
        anchorId(volumeId: doc.volumeId, documentId: doc.documentId)
    }

    /// The anchor of a document's first entry, from its volume and its id (see ``anchorId(doc:)``).
    public static func anchorId(volumeId: String, documentId: String) -> String {
        "doc-\(volumeId)-\(documentId)"
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
    }

    /// The anchor of each of `documents` on the page, in their order (L36, #2004): ``anchorId(doc:)`` for
    /// the first entry of a document, and that anchor with `_2`, `_3` … for each later entry with the same
    /// anchor, so that a document entered twice is two places: two sections, two contents rows that lead
    /// to them, and two sets of note ids, which the anchor scopes.
    ///
    /// **A document entered once keeps the anchor it has always had,** so an export of such a collection
    /// writes the bytes it wrote. `_` is never in a first entry's anchor, whose every character outside
    /// letters and digits is `-`, so a numbered anchor is no other document's, and the ids its anchor
    /// scopes are no other document's either. The live preview reads the same numbering over its entries
    /// to bring a chosen row's own copy into view.
    ///
    /// - Parameter documents: The page's documents, in its order.
    /// - Returns: One anchor per document, in the same order.
    public static func anchorIds(forDocuments documents: [CollectionExportDocument]) -> [String] {
        anchorIds(forKeys: documents.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
    }

    /// The anchor of each document named by its volume and its id, in order, numbered as
    /// ``anchorIds(forDocuments:)`` numbers them: what the preview reads over its entries.
    public static func anchorIds(forKeys keys: [(volumeId: String, documentId: String)]) -> [String] {
        var entered: [String: Int] = [:]
        return keys.map { document in
            let anchor = anchorId(volumeId: document.volumeId, documentId: document.documentId)
            let copy = (entered[anchor] ?? 0) + 1
            entered[anchor] = copy
            return copy == 1 ? anchor : "\(anchor)_\(copy)"
        }
    }

    // MARK: - Embedded CSS (Session 146)

    /// Combined CSS for the assembled HTML page.
    ///
    /// Layer 1: CSS custom properties (light mode, large text size) from `ReaderPage`, which
    ///          `FRUSTheme.cssVariables(colorScheme:textSize:)` forwards to.
    /// Layer 2: Document body styles shared with the in-app WKWebView renderer
    ///          (`ReaderPage.documentCSS`, which `HTMLTemplate.documentCSS` forwards to).
    /// Layer 3: Collection-export-specific layout (header, nav, section, research-note).
    /// Layer 4: Print overrides.
    public static var embeddedCSS: String {
        ReaderPage.cssVariables(appearance: .light, textSize: .large)
        + "\n" + ReaderPage.documentCSS
        + "\n" + collectionExportCSS
        + "\n" + FRUSRenderNodeHTMLSerializer.highlightCSS
        + "\n" + printCSS
    }

    /// Every stylesheet layer this renderer writes of its own, joined: the layout layer every
    /// page carries and the seven a page carries only when it uses them. What
    /// `CollectionExportContrastTests` measures (#1602); no page is built from it.
    public static var ownLayersCSS: String {
        [collectionExportCSS, frameCSS, headnoteCSS, excerptCSS, relatedCSS, attributionCSS,
         generatedCSS, previewCSS].joined(separator: "\n")
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
    /* L34 (#1993): the list writes its own numbers, the documents' alone. */
    nav ol { list-style: none; padding-left: 0; }
    nav li  { margin: 0.3rem 0; }
    nav a   { color: #1a4c8f; text-decoration: none; }
    nav a:hover { text-decoration: underline; }
    .toc-entry { display: flex; justify-content: space-between; }
    /* #1602: #6e6e6e is 4.75:1 on the contents panel's #f7f7f5; #888 was 3.30. */
    .toc-page  { color: #6e6e6e; font-size: 0.9em; }
    /* L34 (#1998): under a title of the author's, the volume's heading in small type. #555 is 6.92:1 on
       the contents panel's #f7f7f5. */
    nav .toc-line { display: block; font-size: 0.85em; color: #555; }

    /* ── Document sections ────────────────────────────────────────────────── */
    section {
      border-top: 1px solid #ddd;
      padding-top: 2rem;
      margin-bottom: 3rem;
    }
    section > h2, section > .doc-lead {
      font-size: 1.25rem;
      font-weight: bold;
      margin-bottom: 0.3rem;
      line-height: 1.4;
    }
    a.doc-ext-link { color: inherit; text-decoration: none; }
    a.doc-ext-link:hover { text-decoration: underline; }
    /* L34: the citation as a line of its own, under a title of the author's. */
    .doc-citation { font-size: 0.9rem; line-height: 1.4; margin: 0 0 0.3rem; }
    /* `<hi rend="strong">` serialises to <strong> (#1323). Pinned for the same reason the
       reader's template pins it: WebKit's UA `bolder` is relative, so inside a bold heading
       it climbs. Georgia ships no 900 face, so the visible effect here is smaller than in the
       reader's -apple-system stack — pinned anyway, because the export is a file the reader
       keeps and may open in a browser with a different font stack. */
    strong { font-weight: 700; }
    section > h2 strong,
    section > .doc-lead strong,
    .doc-heading strong,
    .attachment-heading strong,
    h3.section-heading strong,
    h4.section-heading strong { font-weight: inherit; }
    .doc-url {
      font-size: 0.8rem;
      color: #1a4c8f;
      margin-bottom: 1rem;
      word-break: break-all;
    }

    /* ── Heading levels (L34, J32) ──────────────────────────────────────────── */
    /* In an export a document's heading, an attachment's and the notes' take the level the
       collection's outline gives them, so the reader's h2 and h3 rules are given to every level. */
    .doc-heading { font-size: var(--font-size-heading); font-weight: 600; line-height: 1.3; margin: 0 0 0.65em; }
    .attachment-heading { font-size: calc(var(--font-size-body) * 1.1); font-weight: 600; margin: 0 0 0.7em; line-height: 1.3; }
    .fn-section-heading {
      font-size: calc(var(--font-size-body) * 0.9);
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: var(--color-secondary);
      margin: 0 0 0.75em;
    }
    /* The words that mark where the volume's begin (decision 154), lighter than the heading's own. */
    .as-published { font-weight: 400; }

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
    .collection-project {
      margin-top: 0.4rem;
      font-size: 0.9rem;
      color: #666;
    }
    .collection-project-question {
      margin-top: 0.1rem;
      font-size: 0.9rem;
      font-style: italic;
      color: #666;
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
      /* #1602: #757575 is 4.61:1 on white; #777 was 4.48. */
      color: #757575;
    }
    section.method-appendix {
      margin-top: 3rem;
      border-top: 1px solid #ddd;
      padding-top: 1rem;
      font-size: 0.8rem;
      color: #555;
    }
    section.method-appendix h2 { font-size: 1rem; color: #333; }
    section.method-appendix p { margin: 0.35rem 0; }
    """

    /// Headnote styles (v1.4, Authoring Phase 5) — the labeled italic abstract above a
    /// document body and its missing-summary placeholder. Emitted by `pageHTML` **only
    /// when a document carries a headnote request** (`usesHeadnotes`), so a collection
    /// with no headnotes exports byte-identically to the pre-Phase-5 output. Kept
    /// visually consistent with the design's block furniture (`summary-block` accents).
    private static let headnoteCSS = """
    /* ── Headnote (Authoring Phase 5) ──────────────────────────────────────── */
    .headnote {
      border-left: 3px solid #8a8a86;
      background: #f7f7f5;
      padding: 0.9rem 1.25rem;
      margin: 1rem 0 1.5rem;
      border-radius: 2px;
    }
    .headnote-label {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: #666;
      font-weight: 600;
      margin-bottom: 0.5rem;
    }
    .headnote em { color: #333; }
    .headnote-missing {
      font-size: 0.85rem;
      font-style: italic;
      color: #8a6d1f;
    }
    """

    /// Excerpt styles (v1.5, Authoring Phase 5) — the quoted-passage figure and its
    /// source-citation caption, with per-colour accent borders matching the app's
    /// highlight palette (`FRUSRenderNodeHTMLSerializer.highlightCSS` hues). Emitted by
    /// `pageHTML` **only when the item list contains an excerpt** (`usesExcerpts`), so a
    /// collection with none exports byte-identically to the prior output.
    private static let excerptCSS = """
    /* ── Excerpt quotation (Authoring Phase 5) ─────────────────────────────── */
    figure.excerpt-block {
      margin: 1.5rem 0 1.5rem 1.25rem;
      padding: 0.9rem 1.25rem;
      border-left: 3px solid #8a8a86;
      background: #fafaf8;
      border-radius: 2px;
    }
    .excerpt-block blockquote { margin: 0; }
    .excerpt-block blockquote p {
      font-style: italic;
      color: #333;
      margin: 0 0 0.5rem;
    }
    .excerpt-block blockquote p:last-child { margin-bottom: 0; }
    figcaption.excerpt-source {
      margin-top: 0.6rem;
      font-size: 0.8rem;
      color: #555;
    }
    figcaption.excerpt-source::before { content: "— "; }
    figure.excerpt-yellow { border-left-color: #e6cc33; }
    figure.excerpt-green  { border-left-color: #4fc74f; }
    figure.excerpt-blue   { border-left-color: #4f96f0; }
    figure.excerpt-pink   { border-left-color: #f04fa1; }
    """

    /// Related-documents styles (v1.6, Authoring Phase 5) — the "See also:" citation
    /// line, visually paired with the source-note apparatus line above it. Emitted by
    /// `pageHTML` **only when a document carries the line** (`usesRelatedDocuments`), so
    /// a collection with none exports byte-identically to the prior output.
    private static let relatedCSS = """
    /* ── Related documents (Authoring Phase 5) ─────────────────────────────── */
    .see-also {
      margin-top: 0.6rem;
      font-size: 0.85rem;
      color: #555;
    }
    .see-also strong {
      text-transform: uppercase;
      font-size: 0.75rem;
      letter-spacing: 0.06em;
      /* #1602: 4.61:1 on white, where #777 was 4.48. */
      color: #757575;
    }
    """

    /// AI-attribution styles (v1.9) — the small uppercase caption under a generated
    /// summary block or a filled headnote. Emitted by `pageHTML` **only when some item
    /// renders an attribution caption** (`usesAIAttribution`), so a collection with no
    /// rendered generated summary exports byte-identically to the prior output.
    private static let attributionCSS = """
    /* ── AI attribution (Session 2026-07-03) ───────────────────────────────── */
    .ai-attribution {
      margin-top: 0.6rem;
      margin-bottom: 0;
      font-size: 0.7rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      /* #1602: the caption sits in a summary block (#f0f4ff) or a headnote (#f7f7f5). #6e6e6e is
         4.63:1 and 4.75:1 there; #888 was 3.22 and 3.30. */
      color: #6e6e6e;
    }
    """

    /// Generated-block styles (v1.7, Authoring Phase 6) — the titled apparatus section
    /// and its plain row list (deliberately spartan: designed per-block layouts are a
    /// later exporter-local upgrade). Emitted by `pageHTML` **only when the item list
    /// contains a generated block** (`usesGeneratedBlocks`), so a block-free collection
    /// exports byte-identically to the prior output.
    private static let generatedCSS = """
    /* ── Generated apparatus block (Authoring Phase 6) ─────────────────────── */
    section.generated-block { border-top: 1px solid #ddd; padding-top: 2rem; }
    .generated-title {
      font-size: 1.25rem;
      font-weight: bold;
      margin-bottom: 0.75rem;
    }
    ul.generated-rows { list-style: none; padding-left: 0; }
    ul.generated-rows li { margin: 0.35rem 0; }
    ul.generated-rows a { color: #1a4c8f; text-decoration: none; }
    ul.generated-rows a:hover { text-decoration: underline; }
    .generated-secondary { color: #555; font-size: 0.9em; }
    .generated-row.indent-1 { padding-left: 1.25rem; }
    .generated-row.indent-2 { padding-left: 2.5rem; }
    .generated-row.indent-3 { padding-left: 3.75rem; }
    .generated-row.indent-4 { padding-left: 5rem; }
    """

    /// Preview-only card styles (v1.2) — the citation-only card (volume not downloaded)
    /// and the summary-placeholder card. Emitted by `pageHTML` **only when a preview
    /// affordance is configured** (`isPreviewConfigured`), never by exporters, so the
    /// exported stylesheet — and therefore the exported file's bytes — are identical to
    /// the pre-Phase-2b output (`htmlExportMatchesSharedRenderer` holds this line).
    private static let previewCSS = """
    /* ── Untitled section heading (preview only: every export leaves it out, #1465) ── */
    .untitled-section { font-style: italic; opacity: 0.55; }

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
      /* #1602: #986500 is 4.73:1 on the card's #fdf8ee; #a06a00 was 4.35. */
      color: #986500;
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

    /// Renders a rich-text prose block — the paragraphs of formatted spans the resolver decoded
    /// from its RTF (or a legacy Phase 3b JSON blob, which the shared decoder recovers rather
    /// than dropping) — to an HTML fragment: bold/italic/underline/colour runs map to
    /// `<strong>`/`<em>`/`<u>`/`<span style=color>`, a `.link` run to an outermost `<a href>`
    /// (Session 2026-07-03: the editor's Link control), blank lines to `<p>` boundaries, single
    /// newlines to `<br>`. Paragraph breaks are resolved *before* spans are emitted
    /// (`CollectionProse`), so open/close tags never straddle a `<p>`.
    private func proseHTML(_ paragraphs: [[ProseFormattedSpan]]) -> String {
        guard !paragraphs.isEmpty else { return "" }

        var out = "<div class=\"prose-block\">\n"
        for paragraph in paragraphs {
            let html = paragraph.map { span -> String in
                var open = "", close = ""
                if span.bold      { open += "<strong>"; close = "</strong>" + close }
                if span.italic    { open += "<em>";     close = "</em>" + close }
                if span.underline { open += "<u>";      close = "</u>" + close }
                if let hex = span.colorHex { open += "<span style=\"color:#\(hex)\">"; close = "</span>" + close }
                if let url = span.linkURL, !url.isEmpty {
                    open = "<a href=\"\(escaped(url))\">" + open
                    close += "</a>"
                }
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
