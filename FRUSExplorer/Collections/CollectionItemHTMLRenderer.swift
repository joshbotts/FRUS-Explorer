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
    /// - `.excerpt` → a `<figure class="excerpt-block">`: blockquote passage + a
    ///   source-citation line, with a colour-accent class when the source highlight's
    ///   colour is known (Authoring Phase 5).
    /// - `.generated` → a titled `<section class="generated-block">` with a plain row
    ///   list (Authoring Phase 6).
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
        case .excerpt(let excerpt):
            return excerptHTML(excerpt)
        case .generated(let block):
            return generatedBlockHTML(block)
        case .document(let doc):
            return documentSectionHTML(doc)
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
        // Section heading: the per-entry `titleOverride` when set, else the citation
        // (M3, centralized via `exportHeading`), regardless of ToC style.
        let heading = doc.exportHeading
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
        // Headnote (Authoring Phase 5) — an italic abstract above the body, rendered in
        // every body mode (including the citation-only preview card); a requested
        // headnote with nothing stored renders the placeholder note instead.
        if doc.includeHeadnote {
            body += headnoteHTML(doc.headnoteText, authorship: doc.headnoteAuthorship)
        }

        if citationOnlyVolumeIds.contains(doc.volumeId) {
            body += citationOnlyCardHTML(doc)
        } else {
        // Body — controlled by doc.bodyDepth (per-entry effective depth).
        switch doc.bodyDepth {
        case .full:
            // Phase 5 overrides: the per-entry/section value when resolved, else the
            // collection-level option — untouched documents behave exactly as before.
            let includeFootnotes = doc.includeFootnotesOverride ?? options.includeFootnotes
            let applyHighlights = doc.applyHighlightsOverride ?? options.applyHighlights
            if let model = doc.renderModel {
                // #985: this page carries many documents, and a footnote DOM key is only unique
                // within one. Both branches of the key repeat across documents — 46,695 note
                // `xml:id`s recur across volumes (`d1fn2` is in 314 of them), and the synthesised
                // branch restarts at `n-1` per document because each gets its own converter — so
                // without a per-document scope two footnotes on one exported page share an id and
                // every marker for the second opens the first.
                body += FRUSRenderNodeHTMLSerializer(idScope: "\(Self.anchorId(doc: doc))-").serialize(
                    model,
                    includeFootnotes: includeFootnotes,
                    highlights: applyHighlights ? doc.highlights : []
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
                // AI attribution (v1.9) — generated text is always labeled in exports,
                // mirroring the in-app "AI summary" badge.
                body += "    <p class=\"ai-attribution\">\(escaped(CollectionAIAttribution.label()))</p>\n"
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

        // Source note (options.includeSourceNote)
        if let sourceNote = doc.sourceNoteText, !sourceNote.isEmpty {
            body += "  <p class=\"source-note\"><strong>Source:</strong> "
                + "\(escaped(SourceNoteDisplay.withoutLeadingLabel(sourceNote)))</p>\n"
        }

        // Related documents (A10, Authoring Phase 5): the pre-resolved in-collection
        // "See also:" citations; empty (every untouched entry) renders nothing.
        if !doc.relatedDocumentCitations.isEmpty {
            let label = String(localized: "collection.related.label", defaultValue: "See also:")
            let joined = doc.relatedDocumentCitations
                .map { markdownItalics(escaped($0)) }
                .joined(separator: "; ")
            body += "  <p class=\"see-also\"><strong>\(escaped(label))</strong> \(joined)</p>\n"
        }

        // Research notes — the per-entry override when resolved, else options.includeNotes.
        if doc.includeNotesOverride ?? options.includeNotes {
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

    /// The headnote block (Authoring Phase 5): a labeled, italic abstract rendered above
    /// the document body. When `text` is nil/empty — the entry requested a headnote but
    /// no summary is stored (headnote resolution never generates) — a placeholder note
    /// renders instead, in exports and preview alike, so the author sees exactly what
    /// the artifact will carry.
    ///
    /// - Parameter text: The resolved headnote (stored `GeneratedSummary` text), if any.
    /// - Returns: The `<div class="headnote">…</div>` HTML fragment.
    private func headnoteHTML(_ text: String?, authorship: SummaryAuthorship) -> String {
        let label = String(localized: "collection.headnote.label", defaultValue: "Headnote")
        var body = ""
        body += "  <div class=\"headnote\">\n"
        body += "    <p class=\"headnote-label\">\(escaped(label))</p>\n"
        if let text, !text.isEmpty {
            let paragraphs = text
                .components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            for para in paragraphs {
                body += "    <p><em>\(escaped(para.trimmingCharacters(in: .whitespacesAndNewlines)))</em></p>\n"
            }
            // Attribution honors the headnote's authorship (Composer redesign): an AI headnote keeps
            // the AI label, an AI-edited one discloses the edit, a user-written one shows none.
            if let attribution = CollectionAIAttribution.headnoteLabel(authorship: authorship) {
                body += "    <p class=\"ai-attribution\">\(escaped(attribution))</p>\n"
            }
        } else {
            let missing = String(localized: "collection.headnote.missing",
                                 defaultValue: "No stored summary for this document — generate one in the document view to fill this headnote.")
            body += "    <p class=\"headnote-missing\">\(escaped(missing))</p>\n"
        }
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
            case .generated(let block):
                // A generated block is listed by title, like a section label (Phase 6);
                // it inherits the current nesting level without changing it.
                body += "\(indent(level))<li class=\"toc-section\">\(markdownItalics(escaped(block.title)))</li>\n"
            case .prose, .excerpt:
                break   // interstitial content — never a ToC row
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
            body += "  <p>\(escaped(CollectionColophon.text(for: items)))</p>\n"
            // PV-1: the sources block travels with the colophon, in all three rich formats.
            for line in CollectionColophon.sourceLines(for: items) {
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
    static func usesFrameFeatures(metadata: CollectionExportMetadata,
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
    static func usesHeadnotes(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .document(let doc) = $0 { return doc.includeHeadnote }
            return false
        }
    }

    /// `true` when the item list contains an excerpt (Authoring Phase 5). Gates
    /// `excerptCSS` so an excerpt-free collection emits the exact prior stylesheet bytes.
    static func usesExcerpts(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .excerpt = $0 { return true }
            return false
        }
    }

    /// `true` when some document carries a related-documents line (Authoring Phase 5).
    /// Gates `relatedCSS` so a collection with none emits the exact prior stylesheet bytes.
    static func usesRelatedDocuments(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .document(let doc) = $0 { return !doc.relatedDocumentCitations.isEmpty }
            return false
        }
    }

    /// `true` when the item list contains a generated apparatus block (Authoring
    /// Phase 6). Gates `generatedCSS` so a block-free collection emits the exact prior
    /// stylesheet bytes.
    static func usesGeneratedBlocks(items: [CollectionExportItem]) -> Bool {
        items.contains {
            if case .generated = $0 { return true }
            return false
        }
    }

    /// `true` when some document actually renders an AI-attribution caption (v1.9) — a
    /// non-empty `.summaryOnly` summary body or a filled (non-placeholder) headnote.
    /// Gates `attributionCSS` so a collection rendering no generated summary emits the
    /// exact prior stylesheet bytes.
    static func usesAIAttribution(items: [CollectionExportItem]) -> Bool {
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
      color: #777;
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
      color: #777;
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
      color: #888;
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
    /// a `.link` run to an outermost `<a href>` (Session 2026-07-03: the editor's Link
    /// control), blank lines to `<p>` boundaries, single newlines to `<br>`. Formatting is
    /// decoded once by the shared `CollectionProse.paragraphs(fromRTF:)`, which resolves
    /// paragraph breaks *before* spans are emitted so open/close tags never straddle a `<p>`.
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
