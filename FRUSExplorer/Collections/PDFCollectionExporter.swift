// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CoreGraphics
import CoreText

// MARK: - PDFCollectionExporter

/// Exports a collection to a multi-page PDF using CoreGraphics + CoreText.
///
/// ## Output structure
/// 1. **Cover page** — collection title, optional note, table of contents with citations
/// 2. **Per document** — citation heading, history.state.gov URL, full body text (flows
///    across as many pages as needed), then a research-note callout page (if any)
///
/// Uses PDF coordinate system (origin at lower-left, 72 DPI).
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 32: replaced Collection parameter with CollectionExportMetadata
///   1.2 — Session 73: multi-page body text flow; citation + URL headers; @MainActor
///   1.3 — Session 81: rich rendering via `FRUSDocumentRenderModel` when available;
///          `renderModelToAttributedString` converts render nodes to NSAttributedString
///          with paragraph styles, bold/italic/superscript attributes; flat-text
///          fallback preserved
///   1.4 — Session 83: `noteAttributedString(_:fontSize:gray:)` parses `_text_` italic
///          spans in the collection note using `NSRegularExpression`; overloaded
///          `draw(_:in:rect:)` and `measureHeight(_:width:)` accept `NSAttributedString`
///   1.5 — Session 128: `noteAttributedString(_:fontSize:gray:)` now used for ToC citation
///          labels, document citation headings, and citation reminders in research-note pages
///          so `_Foreign Relations..._` renders as italic instead of literal underscores;
///          research note body text uses `noteAttributedString` for the same reason;
///          `options: CollectionExportOptions` controls ToC label style;
///          `noteTexts: [String]` and `includeDocumentBody` respected per entry
///   1.6 — Future (unnumbered): inline highlight annotation. When
///          `options.applyHighlights` is set and `doc.highlights` is non-empty,
///          `highlightPaint` tracks flat-text position through
///          `renderModelToAttributedString` and paints `.backgroundColor`-equivalent
///          shading (a custom attribute key, since CoreText ignores
///          `NSAttributedString.Key.backgroundColor`) over highlighted leaf text
///          (`plainText`/`formulaText`/`lineBreak`); `drawFrameWithHighlights`
///          manually fills rectangles behind highlighted glyph runs before
///          `CTFrameDraw`. Table-cell rendering now preserves rich attributed
///          strings (previously flattened to plain joined text) so highlights and
///          inline formatting inside table cells survive export.
///   1.7 — Collections rework Phase 3 (structure): the full composed
///          `[CollectionExportItem]` renders in authored order. Documents keep their
///          page-per-document flow; authored section headings and rich-text prose blocks
///          share a continuous "structural flow" page (`drawHeadingFlow`/`drawProseFlow`),
///          and the cover-page table of contents lists numbered documents interleaved with
///          section-heading labels. Prose formatting is decoded via the shared `CollectionProse`.
///   1.8 — Session 2026-07-02 data-loss fix: `drawProseFlow` no longer silently drops a
///          prose block whose payload predates the RTF storage format — the shared
///          `CollectionProse.paragraphs(fromRTF:)` now decodes legacy Phase 3b JSON
///          `AttributedString` blobs (bold/italic preserved) instead of returning `[]`
///   1.9 — Authoring Phase 4 (publication frame): cover gains subtitle/author lines when
///          set (unset → byte-identical cover); heading flow renders level-stepped
///          typography (level 1 = the exact prior 17-pt ruled heading; 2/3 = smaller,
///          indented, un-ruled); the cover ToC indents heading rows by level; opt-in
///          trailing colophon page (`CollectionColophon`). The introduction needs no code
///          here — it arrives as the resolver's leading `.prose` item
///   1.10 — Authoring Phase 5: opt-in headnote — a labeled italic abstract prepended to
///          the body flow (`headnoteAttributedString`); a requested headnote with no
///          stored summary renders a placeholder note. Footnote rendering here remained
///          ungated (pre-existing behavior — this exporter never consumed the legacy
///          `footnoteStyle`), so untouched collections export byte-identically
///          (gap since closed — see 1.13)
///   1.11 — Authoring Phase 5 (excerpts): `.excerpt` items render into the structural
///          flow as a quote-styled block — indented italic passage with a colour accent
///          bar when the source highlight's colour is known, followed by the
///          source-citation line — and are omitted from the cover ToC like prose
///   1.12 — Authoring Phase 5 (overrides + related documents): the highlight and
///          research-note gates honor the document's resolved per-entry override
///          (`doc.x ?? options.x` — nil keeps collection behavior bit-for-bit); a
///          non-empty `relatedDocumentCitations` appends a small "See also:" line to
///          the body flow (paginating with it). Footnote rendering remained ungated
///          (the pre-existing gap, unchanged — resolved: owner decision 2026-07-03,
///          see 1.13)
///   1.13 — Footnote gate (owner decision 2026-07-03): the body honours
///          `doc.includeFootnotesOverride ?? options.includeFootnotes`, mirroring the
///          shared HTML renderer's semantics exactly — when the flag is `false` the
///          trailing footnotes section is omitted while inline superscript markers
///          still render (HTML likewise keeps its `.fn-marker` buttons). The default
///          pair for an untouched collection is `(true, false)`, so untouched
///          collections keep rendering footnotes op-identically; legacy
///          `footnoteStyle` values of `none`/`sourceNoteOnly` now suppress the
///          footnotes section BY DESIGN (they previously rendered it regardless)
///   1.14 — Authoring Phase 6 (generated apparatus): `.generated` items render as a
///          titled flow block — 14-pt ruled title, then one line per row (text +
///          gray secondary, stepped by indent level), paginating like prose — and the
///          cover ToC lists the block by its title like a section label. A row's URL
///          renders as visible small gray text: bare CoreText frame drawing has no
///          link annotations, so a clickable link would require per-run geometry +
///          `CGPDFContext` link boxes — the documented tradeoff (HTML/DOCX carry the
///          real hyperlink)
///   1.15 — Authoring Phase 6 review fix: a generated row taller than a full page (a
///          persons-index reference list spanning hundreds of documents) continues on
///          the next page via the same framesetter continuation `drawProseFlow` uses,
///          instead of being drawn once into a rect extending below the media box
///          (which viewers clip — the tail silently vanished from the PDF)
///   1.16 — Session 2026-07-03 (prose links): a prose span carrying a `.link` attribute
///          (the rich-text editor's Link control) renders underlined with the URL
///          appended as small gray parenthetical text — the v1.14 visible-URL tradeoff
///          applied inline; link-free prose renders byte-identically to 1.15
///   1.17 — Session 2026-07-03 (AI attribution): every rendered generated summary — a
///          `.summaryOnly` body or a filled headnote — is followed by the shared
///          `CollectionAIAttribution` caption in small gray type; collections rendering
///          no generated summary export byte-identically to 1.16
///   1.18 — Session 2026-07-03 review fix: the visible-URL parenthetical is emitted once
///          per *run of consecutive spans sharing a link*, not once per decoded span —
///          a link with mixed inline formatting (e.g. one bolded word) decodes as
///          several spans all carrying the same `linkURL`, and 1.16 printed the URL
///          after every one of them, injecting it repeatedly mid-phrase
final class PDFCollectionExporter: CollectionExporter {

    /// Custom attribute key carrying a highlight `CGColor` for a span of body text.
    /// CoreText's `CTFrameDraw` does not render the Cocoa `NSAttributedString.Key
    /// .backgroundColor` attribute (a higher-level text-system feature), so
    /// highlight shading is painted manually — see `drawFrameWithHighlights`.
    private static let highlightAttrKey = NSAttributedString.Key("FRUSHighlightBackgroundColor")

    // MARK: - Page geometry

    private static let pageWidth:  CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin:     CGFloat = 72
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }
    private static var pageRect: CGRect {
        CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    }

    // MARK: - Highlight Annotation State

    /// Tracks flat-text position and highlight overlap while building the body
    /// attributed string for the document currently being rendered. `nil` when
    /// `options.applyHighlights` is off or the document has no highlights.
    ///
    /// Set by `drawDocumentSection` immediately before constructing `bodyAttrStr`
    /// (and `nil`ed out again immediately after, including before the footnotes
    /// section is appended — footnote bodies are not part of the flat text per
    /// `appendFlatText`, so they must not be painted or advance the tracker).
    /// Consulted only by `paintedString(_:attrs:)`, called at the same flat-text
    /// leaf points (`plainText`/`formulaText`/`lineBreak`) that `appendFlatText`
    /// counts, keeping painted ranges aligned with `ExportHighlight` offsets.
    private var highlightPaint: HighlightPaintTracker?

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL {
        let wordCloud: CGImage? = options.includeWordCloud
            ? WordCloudExporter.collectionCloudImage(
                texts: items.documents.map(\.bodyText), title: metadata.name
              )?.cgImage
            : nil
        let data = try buildPDF(collection: metadata, items: items,
                                options: options, wordCloud: wordCloud)
        let filename = sanitized(metadata.name) + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
        return url
    }

    // MARK: - PDF Construction

    private func buildPDF(
        collection: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions,
        wordCloud: CGImage? = nil
    ) throws -> Data {
        let mutableData = NSMutableData()
        var mediaBox = Self.pageRect
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderingFailed
        }

        let H = Self.pageHeight, M = Self.margin, cw = Self.contentWidth
        var pageNumber = 1

        // Cover page — the table of contents reflects the composed structure
        // (numbered documents plus authored section headings).
        ctx.beginPDFPage(nil)
        drawCoverPage(ctx: ctx, collection: collection, items: items, options: options)
        drawPageNumber(ctx: ctx, number: pageNumber)
        ctx.endPDFPage()
        pageNumber += 1

        // Word-cloud overview page (optional)
        if let wordCloud {
            ctx.beginPDFPage(nil)
            drawWordCloudPage(ctx: ctx, image: wordCloud)
            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
        }

        // Composed body. Documents keep their page-per-document flow; section headings and
        // prose blocks share a continuous "structural flow" page so an authored section
        // divider and its introductory prose sit together, with documents starting fresh.
        var flowOpen = false
        var flowY: CGFloat = 0

        func endFlow() {
            guard flowOpen else { return }
            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
            flowOpen = false
        }
        func beginFlow() {
            ctx.beginPDFPage(nil)
            flowY = H - M
            flowOpen = true
        }
        // Close the current structural-flow page and open a fresh one (mid-item overflow).
        func flowNewPage() {
            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
            ctx.beginPDFPage(nil)
            flowY = H - M
        }

        // Draws an authored section heading into the flow with level-stepped typography:
        // level 1 keeps the exact pre-Phase-4 rendering (17 pt bold + underline rule);
        // levels 2/3 render smaller, indented, and un-ruled sub-section headings.
        func drawHeadingFlow(_ text: String, level: Int) {
            let l = min(max(level, 1), CollectionOutline.maxLevel)
            let sizes: [CGFloat] = [17, 14, 12.5]
            let indentX = CGFloat(l - 1) * 18
            if !flowOpen { beginFlow() }
            let attr = noteAttributedString(text, fontSize: sizes[l - 1], gray: 0.0, bold: true)
            let h = measureHeight(attr, width: cw - indentX)
            // Need room for the heading, its rule, and a little following space.
            if flowY - h - 22 < M + 40 { flowNewPage() }
            if flowY < H - M - 1 { flowY -= 12 }   // top gap unless at the very top
            draw(attr, in: ctx,
                 rect: CGRect(x: M + indentX, y: flowY - h, width: cw - indentX, height: h))
            flowY -= h + 6
            if l == 1 {
                drawHRule(ctx: ctx, y: flowY, gray: 0.5, thickness: 0.5)
                flowY -= 16
            } else {
                flowY -= 8
            }
        }

        // Flows a rich-text prose block into the structural flow, paginating if needed.
        func drawProseFlow(_ rtf: Data) {
            let attr = proseAttributedString(rtf)
            guard attr.length > 0 else { return }
            if !flowOpen { beginFlow() }
            if flowY < H - M - 1 { flowY -= 8 }   // gap above prose unless at page top

            let framesetter = CTFramesetterCreateWithAttributedString(attr)
            let fullH = measureHeight(attr, width: cw)
            if fullH <= flowY - (M + 20) {
                // Fits entirely on the current page.
                draw(attr, in: ctx, rect: CGRect(x: M, y: flowY - fullH, width: cw, height: fullH))
                flowY -= fullH + 12
                return
            }
            // Multi-page flow: fill each page top-down, then advance to a fresh page.
            var charOffset = 0
            let total = attr.length
            while charOffset < total {
                let availH = flowY - (M + 20)
                if availH < 28 { flowNewPage(); continue }
                let rect = CGRect(x: M, y: M + 20, width: cw, height: availH)
                let path = CGPath(rect: rect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charOffset, 0), path, nil)
                CTFrameDraw(frame, ctx)
                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length == 0 { break }
                charOffset += visible.length
                if charOffset < total {
                    flowNewPage()
                } else {
                    // Advance the cursor by the height the final chunk actually consumed.
                    let used = CTFramesetterSuggestFrameSizeWithConstraints(
                        framesetter, CFRangeMake(charOffset - visible.length, visible.length),
                        nil, CGSize(width: cw, height: availH), nil)
                    flowY -= ceil(used.height) + 12
                }
            }
        }

        // Flows an excerpt quotation into the structural flow (Authoring Phase 5):
        // an indented italic passage behind a colour accent bar (the source highlight's
        // colour when known), followed by the source-citation line. Paginates like prose.
        func drawExcerptFlow(_ excerpt: CollectionExportExcerpt) {
            let attr = excerptAttributedString(excerpt)
            guard attr.length > 0 else { return }
            let indentX: CGFloat = 18
            let width = cw - indentX
            let barColor = excerpt.color?.cgColor ?? CGColor(gray: 0.55, alpha: 1)
            if !flowOpen { beginFlow() }
            if flowY < H - M - 1 { flowY -= 10 }   // gap above the quote unless at page top

            let framesetter = CTFramesetterCreateWithAttributedString(attr)
            var charOffset = 0
            let total = attr.length
            while charOffset < total {
                let availH = flowY - (M + 20)
                if availH < 28 { flowNewPage(); continue }
                // Measure the chunk that fits this page so the accent bar can span
                // exactly the drawn height.
                let used = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter, CFRangeMake(charOffset, 0), nil,
                    CGSize(width: width, height: availH), nil)
                let chunkH = min(ceil(used.height) + 4, availH)
                let rect = CGRect(x: M + indentX, y: flowY - chunkH, width: width, height: chunkH)
                ctx.setFillColor(barColor)
                ctx.fill(CGRect(x: M + indentX - 10, y: rect.minY, width: 3, height: rect.height))
                let path = CGPath(rect: rect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charOffset, 0), path, nil)
                CTFrameDraw(frame, ctx)
                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length == 0 { break }
                charOffset += visible.length
                if charOffset < total {
                    flowNewPage()
                } else {
                    flowY = rect.minY - 12
                }
            }
        }

        // Flows a generated apparatus block into the structural flow (Authoring
        // Phase 6): a ruled 14-pt title, then the rows as plain lines — text with
        // optional gray secondary text and visible URL, stepped by indent level.
        // Paginates like prose; designed per-block layouts are a later upgrade.
        func drawGeneratedFlow(_ block: CollectionGeneratedBlock) {
            if !flowOpen { beginFlow() }
            if flowY < H - M - 1 { flowY -= 12 }   // top gap unless at the very top
            let titleAttr = noteAttributedString(block.title, fontSize: 14, gray: 0.0, bold: true)
            let titleH = measureHeight(titleAttr, width: cw)
            if flowY - titleH - 22 < M + 40 { flowNewPage() }
            draw(titleAttr, in: ctx, rect: CGRect(x: M, y: flowY - titleH, width: cw, height: titleH))
            flowY -= titleH + 6
            drawHRule(ctx: ctx, y: flowY, gray: 0.5, thickness: 0.5)
            flowY -= 12
            for row in block.rows {
                let indentX = CGFloat(min(max(row.indentLevel, 0), 4)) * 16
                let width = cw - indentX
                let attr = NSMutableAttributedString(
                    attributedString: noteAttributedString(row.text, fontSize: 10, gray: 0.1))
                if let secondary = row.secondaryText, !secondary.isEmpty {
                    attr.append(NSAttributedString(string: "  ",
                                                   attributes: makeAttrs(fontSize: 10, bold: false)))
                    attr.append(noteAttributedString(secondary, fontSize: 9, gray: 0.45))
                }
                if let url = row.url, !url.isEmpty {
                    // Visible URL text — see the v1.14 note for the no-annotation tradeoff.
                    attr.append(NSAttributedString(string: "\n",
                                                   attributes: makeAttrs(fontSize: 3, bold: false)))
                    attr.append(NSAttributedString(string: url,
                                                   attributes: makeAttrs(fontSize: 8, bold: false, gray: 0.45)))
                }
                let h = measureHeight(attr, width: width)
                if flowY - h < M + 20 { flowNewPage() }
                if h <= flowY - (M + 20) {
                    draw(attr, in: ctx,
                         rect: CGRect(x: M + indentX, y: flowY - h, width: width, height: h))
                    flowY -= h + 4
                } else {
                    // A single row taller than a fresh page (e.g. a persons-index
                    // reference list spanning hundreds of documents): the same
                    // framesetter continuation drawProseFlow uses, so the overflow
                    // continues on the next page instead of being clipped below the
                    // media box (Phase 6 review fix).
                    let framesetter = CTFramesetterCreateWithAttributedString(attr)
                    var charOffset = 0
                    let total = attr.length
                    while charOffset < total {
                        let availH = flowY - (M + 20)
                        if availH < 28 { flowNewPage(); continue }
                        let rect = CGRect(x: M + indentX, y: M + 20, width: width, height: availH)
                        let path = CGPath(rect: rect, transform: nil)
                        let frame = CTFramesetterCreateFrame(
                            framesetter, CFRangeMake(charOffset, 0), path, nil)
                        CTFrameDraw(frame, ctx)
                        let visible = CTFrameGetVisibleStringRange(frame)
                        if visible.length == 0 { break }
                        charOffset += visible.length
                        if charOffset < total {
                            flowNewPage()
                        } else {
                            // Advance by the height the final chunk actually consumed.
                            let used = CTFramesetterSuggestFrameSizeWithConstraints(
                                framesetter,
                                CFRangeMake(charOffset - visible.length, visible.length),
                                nil, CGSize(width: width, height: availH), nil)
                            flowY -= ceil(used.height) + 4
                        }
                    }
                }
            }
            flowY -= 8
        }

        for item in items {
            switch item {
            case .document(let doc):
                endFlow()   // documents always start on a fresh page
                drawDocumentSection(ctx: ctx, doc: doc, options: options, pageNumber: &pageNumber)
            case .heading(let text, let level):
                drawHeadingFlow(text, level: level)
            case .prose(let rtf):
                drawProseFlow(rtf)
            case .excerpt(let excerpt):
                drawExcerptFlow(excerpt)
            case .generated(let block):
                drawGeneratedFlow(block)
            }
        }
        endFlow()

        // Method-appendix page (M-2) — opt-in only. Its own page rather than a trailing
        // paragraph, because it is a section a reader is meant to consult, not a footnote.
        if !collection.methodAppendixLines.isEmpty {
            ctx.beginPDFPage(nil)
            var y = M
            for line in collection.methodAppendixLines where !line.isEmpty {
                let attr = noteAttributedString(line, fontSize: 9, gray: 0.35)
                let h = measureHeight(attr, width: cw)
                // A long log runs past one page; start another rather than drawing off the edge.
                if y + h > H - M {
                    drawPageNumber(ctx: ctx, number: pageNumber)
                    ctx.endPDFPage()
                    pageNumber += 1
                    ctx.beginPDFPage(nil)
                    y = M
                }
                draw(attr, in: ctx, rect: CGRect(x: M, y: y, width: cw, height: h))
                y += h + 4
            }
            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
        }

        // Colophon page (Authoring Phase 4) — opt-in only, so collections that never
        // enable it produce exactly the prior page sequence.
        if collection.includeColophon {
            ctx.beginPDFPage(nil)
            // PV-1: the sources block travels with the colophon, in all three rich formats. It
            // is set with the colophon line as one flow so a long block wraps rather than
            // overprinting the page number beneath it.
            let colophonText = ([CollectionColophon.text(for: items)]
                                + CollectionColophon.sourceLines(for: items))
                .joined(separator: "\n")
            let attr = noteAttributedString(colophonText, fontSize: 9, gray: 0.45)
            let h = measureHeight(attr, width: cw)
            draw(attr, in: ctx, rect: CGRect(x: M, y: H - M - h, width: cw, height: h))
            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
        }

        ctx.closePDF()
        return mutableData as Data
    }

    // MARK: - Word Cloud Page

    /// Draws the word-cloud overview image, aspect-fit within the page margins.
    /// A raw Core Graphics PDF context has a bottom-left origin and draws images
    /// upright, so no flip transform is needed.
    private func drawWordCloudPage(ctx: CGContext, image: CGImage) {
        let page = Self.pageRect
        let available = page.insetBy(dx: Self.margin, dy: Self.margin)
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        var width = available.width
        var height = width / imageAspect
        if height > available.height {
            height = available.height
            width = height * imageAspect
        }
        // Top-aligned, not vertically centred (#960 item 4's remainder): the image is
        // wide-format, so centring floated it in a band of whitespace mid-page — the owner's
        // build-43 export shows the shape. PDF coordinates put the origin bottom-left, so the
        // top of the content area is maxY minus the drawn height.
        let rect = CGRect(
            x: page.midX - width / 2,
            y: available.maxY - height,
            width: width,
            height: height
        )
        ctx.draw(image, in: rect)
    }

    // MARK: - Cover Page

    private func drawCoverPage(
        ctx: CGContext,
        collection: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) {
        let H = Self.pageHeight
        let M = Self.margin, cw = Self.contentWidth

        var y = H - M - 40

        // Title
        let titleHeight = measureHeight(collection.name, width: cw, fontSize: 22, bold: true)
        draw(collection.name, in: ctx,
             rect: CGRect(x: M, y: y - titleHeight, width: cw, height: titleHeight),
             fontSize: 22, bold: true)
        y -= titleHeight + 16

        // Title-page subtitle and author lines (Authoring Phase 4) — drawn only when set,
        // so an unset collection's cover is unchanged.
        if let subtitle = collection.subtitle, !subtitle.isEmpty {
            let subAttr = noteAttributedString(subtitle, fontSize: 14, gray: 0.2)
            let subH = measureHeight(subAttr, width: cw)
            draw(subAttr, in: ctx, rect: CGRect(x: M, y: y - subH, width: cw, height: subH))
            y -= subH + 10
        }
        if let author = collection.authorLine, !author.isEmpty {
            let authorAttr = noteAttributedString(author, fontSize: 11, gray: 0.3)
            let authorH = measureHeight(authorAttr, width: cw)
            draw(authorAttr, in: ctx, rect: CGRect(x: M, y: y - authorH, width: cw, height: authorH))
            y -= authorH + 12
        }

        // Project provenance (#377 Phase 4) — drawn only when the collection opted in and a
        // project was active at export time, so an unset collection's cover is unchanged.
        if let projectName = collection.projectName, !projectName.isEmpty {
            let label = String(localized: "export.frontmatter.project", defaultValue: "Project")
            let projAttr = noteAttributedString("\(label): \(projectName)", fontSize: 11, gray: 0.35)
            let projH = measureHeight(projAttr, width: cw)
            draw(projAttr, in: ctx, rect: CGRect(x: M, y: y - projH, width: cw, height: projH))
            y -= projH + 4
            if let question = collection.projectResearchQuestion, !question.isEmpty {
                let qAttr = noteAttributedString(question, fontSize: 11, gray: 0.4)
                let qH = measureHeight(qAttr, width: cw)
                draw(qAttr, in: ctx, rect: CGRect(x: M, y: y - qH, width: cw, height: qH))
                y -= qH
            }
            y -= 12
        }

        // Collection note — _text_ spans rendered as italic
        if let note = collection.note, !note.isEmpty {
            let noteAttr = noteAttributedString(note, fontSize: 12, gray: 0.3)
            let noteH = measureHeight(noteAttr, width: cw)
            draw(noteAttr, in: ctx,
                 rect: CGRect(x: M, y: y - noteH, width: cw, height: noteH))
            y -= noteH + 20
        }

        // Separator
        drawHRule(ctx: ctx, y: y, gray: 0.4, thickness: 0.5)
        y -= 20

        // Contents header
        draw("Contents", in: ctx,
             rect: CGRect(x: M, y: y - 16, width: cw, height: 16),
             fontSize: 13, bold: true)
        y -= 30

        // ToC entries in authored order: documents are numbered; authored section headings
        // appear as bold, un-numbered labels; prose blocks are omitted. Document label style
        // is controlled by options.tocStyle; _text_ spans render as italic.
        var docNumber = 0
        for item in items {
            // Stop before a row could be drawn below the bottom margin: the tallest row
            // is a section heading (up to a 6-pt top gap + a 44-pt label).
            guard y >= M + 50 else { break }
            switch item {
            case .document(let doc):
                docNumber += 1
                let rawLabel = "\(docNumber).  \(doc.tocLabel(style: options.tocStyle))"
                let labelAttr = noteAttributedString(rawLabel, fontSize: 10, gray: 0.1)
                let lineH = measureHeight(labelAttr, width: cw - 16)
                let rowH = min(lineH, 40) // cap at ~3 lines
                draw(labelAttr, in: ctx,
                     rect: CGRect(x: M + 16, y: y - rowH, width: cw - 16, height: rowH))
                y -= rowH + 6
            case .heading(let text, let level):
                // Nested sections indent by resolved level (level 1 = the pre-Phase-4 row).
                let l = min(max(level, 1), CollectionOutline.maxLevel)
                let indentX = CGFloat(l - 1) * 16
                let labelAttr = noteAttributedString(text, fontSize: 11, gray: 0.0, bold: true)
                let lineH = measureHeight(labelAttr, width: cw - indentX)
                let rowH = min(lineH, 44)
                y -= 6   // a little breathing room above a section label
                draw(labelAttr, in: ctx,
                     rect: CGRect(x: M + indentX, y: y - rowH, width: cw - indentX, height: rowH))
                y -= rowH + 6
            case .generated(let block):
                // A generated block is listed by its title, like a section label (Phase 6).
                let labelAttr = noteAttributedString(block.title, fontSize: 11, gray: 0.0, bold: true)
                let lineH = measureHeight(labelAttr, width: cw)
                let rowH = min(lineH, 44)
                y -= 6
                draw(labelAttr, in: ctx,
                     rect: CGRect(x: M, y: y - rowH, width: cw, height: rowH))
                y -= rowH + 6
            case .prose, .excerpt:
                break   // interstitial content — never a ToC row
            }
        }
    }

    // MARK: - Document Section (multi-page)

    private func drawDocumentSection(
        ctx: CGContext,
        doc: CollectionExportDocument,
        options: CollectionExportOptions,
        pageNumber: inout Int
    ) {
        let H = Self.pageHeight, M = Self.margin, cw = Self.contentWidth

        // ── First page of document ──────────────────────────────────────────
        ctx.beginPDFPage(nil)
        var y = H - M

        // Heading: the per-entry `titleOverride` when set, else the citation (M3,
        // centralized via `exportHeading`). noteAttributedString renders _text_ as italic.
        let cit = doc.exportHeading
        let citBoldAttr = noteAttributedString(cit, fontSize: 13, gray: 0.0, bold: true)
        let citH = measureHeight(citBoldAttr, width: cw)
        draw(citBoldAttr, in: ctx,
             rect: CGRect(x: M, y: y - citH, width: cw, height: citH))
        y -= citH + 6

        // history.state.gov URL
        if !doc.historyStateGovURL.isEmpty {
            draw(doc.historyStateGovURL, in: ctx,
                 rect: CGRect(x: M, y: y - 11, width: cw, height: 11),
                 fontSize: 8, bold: false, gray: 0.45)
            y -= 17
        }

        drawHRule(ctx: ctx, y: y, gray: 0.6, thickness: 0.3)
        y -= 12

        // Body — controlled by doc.bodyDepth (per-entry effective depth).
        let bodyAttrStr: NSAttributedString
        switch doc.bodyDepth {
        case .full:
            if let model = doc.renderModel {
                // Highlight offsets are flat-text positions over the render model's
                // body nodes (see `ExportHighlight`); the plain `bodyText` fallback
                // below uses a different extraction path, so painting is only valid
                // when a render model is present.
                // Phase 5: the per-entry/section override when resolved, else the
                // collection-level option.
                let applyHighlights = doc.applyHighlightsOverride ?? options.applyHighlights
                // Footnote gate (owner decision 2026-07-03): mirrors the shared HTML
                // renderer — `false` omits the footnotes section, markers stay.
                let includeFootnotes = doc.includeFootnotesOverride ?? options.includeFootnotes
                highlightPaint = (applyHighlights && !doc.highlights.isEmpty)
                    ? HighlightPaintTracker(doc.highlights)
                    : nil
                bodyAttrStr = renderModelToAttributedString(model,
                                                            includeFootnotes: includeFootnotes)
                highlightPaint = nil
            } else if !doc.bodyText.isEmpty {
                bodyAttrStr = NSAttributedString(string: doc.bodyText,
                                                 attributes: makeAttrs(fontSize: 10, bold: false))
            } else {
                bodyAttrStr = NSAttributedString()
            }
        case .summaryOnly:
            if let summary = doc.summaryText, !summary.isEmpty {
                // AI attribution (v1.17): generated text is always labeled in exports —
                // a small gray caption line after the summary, mirroring the in-app
                // "AI summary" badge.
                let labeled = NSMutableAttributedString(
                    string: summary,
                    attributes: makeAttrs(fontSize: 10, bold: false))
                labeled.append(NSAttributedString(string: "\n\n",
                                                  attributes: makeAttrs(fontSize: 4, bold: false)))
                labeled.append(NSAttributedString(
                    string: CollectionAIAttribution.label(),
                    attributes: makeAttrs(fontSize: 7.5, bold: false, gray: 0.45)))
                bodyAttrStr = labeled
            } else {
                bodyAttrStr = NSAttributedString()
            }
        case .index:
            bodyAttrStr = NSAttributedString()
        }

        // Source note (options.includeSourceNote)
        if let sourceNote = doc.sourceNoteText, !sourceNote.isEmpty {
            drawHRule(ctx: ctx, y: y, gray: 0.75, thickness: 0.25)
            y -= 10
            let snText = "Source: \(SourceNoteDisplay.withoutLeadingLabel(sourceNote))"
            // Approximate height: one line at 9pt
            let snH: CGFloat = 14
            draw(snText, in: ctx,
                 rect: CGRect(x: M, y: y - snH, width: cw, height: snH),
                 fontSize: 9, bold: false, gray: 0.45)
            y -= snH + 6
        }

        // Headnote (Authoring Phase 5) — a labeled italic abstract prepended to the body
        // flow, so a long headnote paginates with the body. A requested headnote with
        // no stored summary renders the placeholder note (never generated on demand).
        // Prepending shifts the painted highlight attribute ranges with their text, so
        // highlight shading stays aligned.
        let headnotedBody = doc.includeHeadnote
            ? headnoteAttributedString(doc.headnoteText, authorship: doc.headnoteAuthorship, thenBody: bodyAttrStr)
            : bodyAttrStr

        // Related documents (A10, Authoring Phase 5): a small trailing "See also:" line
        // appended to the body flow so it paginates with it; empty (every untouched
        // entry) leaves the flow byte-identical. Appending (after the body) leaves the
        // painted highlight attribute ranges unshifted.
        let composedBody: NSAttributedString
        if doc.relatedDocumentCitations.isEmpty {
            composedBody = headnotedBody
        } else {
            let label = String(localized: "collection.related.label", defaultValue: "See also:")
            let joined = doc.relatedDocumentCitations.joined(separator: "; ")
            let combined = NSMutableAttributedString(attributedString: headnotedBody)
            combined.append(NSAttributedString(string: "\n\n",
                                               attributes: makeAttrs(fontSize: 4, bold: false)))
            // noteAttributedString renders _text_ citation spans as italics.
            combined.append(noteAttributedString("\(label) \(joined)", fontSize: 9, gray: 0.45))
            composedBody = combined
        }

        if composedBody.length > 0 {
            let framesetter = CTFramesetterCreateWithAttributedString(composedBody)
                var charOffset = 0
                let totalChars = composedBody.length

                while charOffset < totalChars {
                    let availH = y - (M + 20)
                    if availH < 20 {
                        // No room on this page — start a new one
                        drawPageNumber(ctx: ctx, number: pageNumber)
                        ctx.endPDFPage()
                        pageNumber += 1
                        ctx.beginPDFPage(nil)
                        y = H - M
                        continue
                    }

                    let rect = CGRect(x: M, y: M + 20, width: cw, height: availH)
                    let path = CGPath(rect: rect, transform: nil)
                    let cfRange = CFRangeMake(charOffset, 0)
                    let frame = CTFramesetterCreateFrame(framesetter, cfRange, path, nil)
                    drawFrameWithHighlights(frame, attrStr: composedBody, in: ctx)

                    let visible = CTFrameGetVisibleStringRange(frame)
                    if visible.length == 0 { break }
                    charOffset += visible.length

                    if charOffset < totalChars {
                        // #960: a whitespace-only remainder must not open a page. Trailing
                        // newlines in a composed body could overflow onto a fresh page on
                        // which CoreText then draws nothing — a blank page with only its
                        // folio, which is exactly the shipped defect (p18 of the owner's
                        // build-43 export). Whitespace left to draw is drawing done.
                        let remainder = (composedBody.string as NSString)
                            .substring(from: charOffset)
                        if remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            charOffset = totalChars
                            y = M + 20
                        } else {
                            // Text overflowed — new page
                            drawPageNumber(ctx: ctx, number: pageNumber)
                            ctx.endPDFPage()
                            pageNumber += 1
                            ctx.beginPDFPage(nil)
                            y = H - M
                        }
                    } else {
                        y = M + 20
                    }
                }
        }

        drawPageNumber(ctx: ctx, number: pageNumber)
        ctx.endPDFPage()
        pageNumber += 1

        // ── Research note pages (one per note; the per-entry override when resolved,
        //    else options.includeNotes — Phase 5) ─
        guard doc.includeNotesOverride ?? options.includeNotes else { return }
        for note in doc.noteTexts where !note.isEmpty {
            ctx.beginPDFPage(nil)
            var ny = H - M

            // Note header banner
            ctx.setFillColor(CGColor(gray: 0.93, alpha: 1))
            ctx.fill(CGRect(x: M, y: ny - 28, width: cw, height: 28))
            draw("Research Note", in: ctx,
                 rect: CGRect(x: M + 8, y: ny - 22, width: cw - 16, height: 18),
                 fontSize: 11, bold: true, gray: 0.2)
            ny -= 36

            // Citation reminder — noteAttributedString renders _text_ as italic.
            let rawShortCit = cit.count > 100 ? String(cit.prefix(100)) + "…" : cit
            let shortCitAttr = noteAttributedString(rawShortCit, fontSize: 8, gray: 0.5)
            let shortCitH = measureHeight(shortCitAttr, width: cw)
            draw(shortCitAttr, in: ctx,
                 rect: CGRect(x: M, y: ny - shortCitH, width: cw, height: shortCitH))
            ny -= shortCitH + 8

            drawHRule(ctx: ctx, y: ny, gray: 0.7, thickness: 0.3)
            ny -= 12

            // Note body text — noteAttributedString renders _text_ as italic.
            let noteAttr = noteAttributedString(note, fontSize: 11, gray: 0.1)
            let framesetter = CTFramesetterCreateWithAttributedString(noteAttr)
            let rect = CGRect(x: M, y: M + 20, width: cw, height: ny - M - 20)
            let path = CGPath(rect: rect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, ctx)

            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
        }
    }

    // MARK: - Headnote (Authoring Phase 5)

    /// Builds the document flow for an entry with a headnote request: a small bold
    /// "Headnote" label, the italic abstract (or the missing-summary placeholder when no
    /// summary is stored — headnote resolution never generates), a small gap, then the
    /// body. Prepending keeps a long headnote paginating naturally with the body text.
    ///
    /// - Parameters:
    ///   - text: The resolved headnote text, if any.
    ///   - body: The already-built body attributed string to follow the headnote.
    /// - Returns: The combined attributed string.
    private func headnoteAttributedString(_ text: String?,
                                          authorship: SummaryAuthorship,
                                          thenBody body: NSAttributedString) -> NSAttributedString {
        let combined = NSMutableAttributedString()
        let label = String(localized: "collection.headnote.label", defaultValue: "Headnote")
        combined.append(NSAttributedString(
            string: label + "\n",
            attributes: makeAttrs(fontSize: 8, bold: true, gray: 0.35)))
        if let text, !text.isEmpty {
            combined.append(NSAttributedString(
                string: text + "\n",
                attributes: makeStyledAttrs(fontSize: 10, bold: false, italic: true, gray: 0.15)))
            // Attribution honors the headnote's authorship (Composer redesign): AI keeps the
            // caption, an AI-edited headnote discloses the edit, a user-written one shows none.
            if let attribution = CollectionAIAttribution.headnoteLabel(authorship: authorship) {
                combined.append(NSAttributedString(
                    string: attribution + "\n",
                    attributes: makeAttrs(fontSize: 7.5, bold: false, gray: 0.45)))
            }
        } else {
            let missing = String(localized: "collection.headnote.missing",
                                 defaultValue: "No stored summary for this document — generate one in the document view to fill this headnote.")
            combined.append(NSAttributedString(
                string: missing + "\n",
                attributes: makeStyledAttrs(fontSize: 9, bold: false, italic: true, gray: 0.45)))
        }
        combined.append(NSAttributedString(string: "\n",
                                           attributes: makeAttrs(fontSize: 4, bold: false)))
        combined.append(body)
        return combined
    }

    // MARK: - Excerpt (Authoring Phase 5)

    /// Builds the attributed string for an excerpt quotation: the frozen passage in
    /// italics (verbatim — no markdown transforms, it is primary-source text), then a
    /// small gap and the "— citation" source line (the citation runs through
    /// `noteAttributedString` so `_…_` spans render as italics, matching document
    /// citations). An empty citation omits the source line.
    ///
    /// - Parameter excerpt: The resolved excerpt payload.
    /// - Returns: The combined attributed string for the flow block.
    private func excerptAttributedString(_ excerpt: CollectionExportExcerpt) -> NSAttributedString {
        let combined = NSMutableAttributedString()
        combined.append(NSAttributedString(
            string: excerpt.text,
            attributes: makeStyledAttrs(fontSize: 10, bold: false, italic: true, gray: 0.15)))
        if !excerpt.citation.isEmpty {
            combined.append(NSAttributedString(string: "\n",
                                               attributes: makeAttrs(fontSize: 5, bold: false)))
            combined.append(NSAttributedString(
                string: "\u{2014} ",
                attributes: makeAttrs(fontSize: 8, bold: false, gray: 0.45)))
            combined.append(noteAttributedString(excerpt.citation, fontSize: 8, gray: 0.45))
        }
        return combined
    }

    // MARK: - Rich Rendering (Session 81)

    /// Converts a `FRUSDocumentRenderModel` into a single `NSAttributedString` for CoreText
    /// framesetting. Block nodes are concatenated with paragraph breaks; footnote bodies
    /// are appended after the main content with a rule separator and reduced font size.
    ///
    /// - Parameter includeFootnotes: When `false` (owner decision 2026-07-03), the
    ///   trailing footnotes section is omitted — matching the shared HTML renderer,
    ///   which drops footnote bodies while keeping inline markers (rendered here as
    ///   superscript labels regardless).
    private func renderModelToAttributedString(_ model: FRUSDocumentRenderModel,
                                               includeFootnotes: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in model.bodyNodes {
            let block = blockNodeToAttributedString(node)
            if block.length > 0 {
                result.append(block)
                // Paragraph gap between blocks
                if !result.string.hasSuffix("\n") {
                    result.append(NSAttributedString(string: "\n",
                                                     attributes: makeAttrs(fontSize: 10, bold: false)))
                }
            }
        }
        // Footnote bodies are not part of the flat-text traversal `appendFlatText`
        // walks (only `model.bodyNodes` is counted), so highlight offsets never
        // point into them — stop tracking/painting before appending this section.
        highlightPaint = nil

        // Footnotes section — gated on the resolved include-footnotes flag (owner
        // decision 2026-07-03), matching the shared HTML renderer's footnote gate.
        if includeFootnotes, !model.footnotes.isEmpty {
            let ruleAttrs: [NSAttributedString.Key: Any] = makeAttrs(fontSize: 4, bold: false,
                                                                      gray: 0.7)
            result.append(NSAttributedString(string: "\n\u{00A0}\n", attributes: ruleAttrs))
            for note in model.footnotes {
                if case .footnoteBody(_, _, _, _, let label, let children) = note {
                    // #985: the printed number, or a bullet when the volume printed none.
                    let fnMark = NSMutableAttributedString(
                        string: label.map { "\($0). " } ?? "\u{2022} ",
                        attributes: makeAttrs(fontSize: 8, bold: false, gray: 0.3))
                    result.append(fnMark)
                    for child in children {
                        result.append(blockNodeToAttributedString(child, fontSize: 8))
                    }
                    if !result.string.hasSuffix("\n") {
                        result.append(NSAttributedString(string: "\n",
                                                         attributes: makeAttrs(fontSize: 8, bold: false)))
                    }
                }
            }
        }
        return result
    }

    private func blockNodeToAttributedString(_ node: FRUSRenderNode,
                                              fontSize: CGFloat = 10) -> NSAttributedString {
        let result = NSMutableAttributedString()
        switch node {
        case .heading(let c):
            result.append(inlineAttributedString(c, fontSize: 13, bold: true))
            result.append(NSAttributedString(string: "\n", attributes: makeAttrs(fontSize: 4, bold: false)))
        case .dateline(let c):
            result.append(inlineAttributedString(c, fontSize: fontSize, bold: false, italic: true))
            result.append(NSAttributedString(string: "\n", attributes: makeAttrs(fontSize: 4, bold: false)))
        case .salutation(let c):
            result.append(inlineAttributedString(c, fontSize: fontSize, bold: false, italic: true))
            result.append(NSAttributedString(string: "\n", attributes: makeAttrs(fontSize: 4, bold: false)))
        case .paragraph(let c):
            result.append(inlineAttributedString(c, fontSize: fontSize))
            // Double newline after each paragraph provides natural visual separation
            result.append(NSAttributedString(string: "\n\n",
                                             attributes: makeAttrs(fontSize: fontSize, bold: false)))
        case .letterOpener(let c), .letterCloser(let c):
            for child in c { result.append(blockNodeToAttributedString(child, fontSize: fontSize)) }
        case .editorialNoteBlock(let c):
            for child in c {
                let inner = blockNodeToAttributedString(child, fontSize: fontSize - 1)
                result.append(inner)
            }
        case .attachmentBlock(_, let c):
            // Extra leading space to suggest visual break
            result.append(NSAttributedString(string: "\n",
                                             attributes: makeAttrs(fontSize: fontSize, bold: false)))
            for child in c { result.append(blockNodeToAttributedString(child, fontSize: fontSize)) }
        case .attachmentHeading(let c):
            result.append(inlineAttributedString(c, fontSize: 11, bold: true))
            result.append(NSAttributedString(string: "\n", attributes: makeAttrs(fontSize: 4, bold: false)))
        case .titlePageBlock(let c):
            for child in c { result.append(blockNodeToAttributedString(child, fontSize: fontSize)) }
        case .listBlock(_, let items):
            for item in items {
                result.append(NSAttributedString(string: "• ",
                                                 attributes: makeAttrs(fontSize: fontSize, bold: false)))
                result.append(inlineAttributedString(item, fontSize: fontSize))
                result.append(NSAttributedString(string: "\n",
                                                 attributes: makeAttrs(fontSize: fontSize, bold: false)))
            }
        case .tableBlock(let rows):
            // Preserve each cell's rich attributed string (rather than flattening
            // to plain joined text) so highlight shading and inline formatting
            // (bold/italic/etc.) inside cells survive export. " | " separators and
            // the trailing "\n" are appended directly — `appendFlatText` does not
            // count them, so they must bypass `paintedString`/`highlightPaint`.
            for row in rows {
                for (i, cell) in row.enumerated() {
                    if i > 0 {
                        result.append(NSAttributedString(string: " | ",
                                                         attributes: makeAttrs(fontSize: fontSize - 1, bold: false)))
                    }
                    result.append(inlineAttributedString(cell.children, fontSize: fontSize - 1))
                }
                result.append(NSAttributedString(string: "\n",
                                                 attributes: makeAttrs(fontSize: fontSize - 1, bold: false)))
            }
        case .figureBlock(let alt):
            if let alt, !alt.isEmpty {
                result.append(NSAttributedString(string: "[\(alt)]\n",
                                                 attributes: makeAttrs(fontSize: fontSize - 1, bold: false, gray: 0.4)))
            }
        case .footnoteBody, .pageBreak:
            break // handled separately
        case .unknown(_, let c):
            for child in c { result.append(blockNodeToAttributedString(child, fontSize: fontSize)) }
        default:
            // Inline node at block level — treat as a paragraph
            result.append(inlineAttributedString([node], fontSize: fontSize))
            result.append(NSAttributedString(string: "\n",
                                             attributes: makeAttrs(fontSize: fontSize, bold: false)))
        }
        return result
    }

    private func inlineAttributedString(_ nodes: [FRUSRenderNode],
                                         fontSize: CGFloat = 10,
                                         bold: Bool = false,
                                         italic: Bool = false) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in nodes {
            result.append(inlineNodeToAttributedString(node,
                                                        fontSize: fontSize,
                                                        bold: bold,
                                                        italic: italic))
        }
        return result
    }

    private func inlineNodeToAttributedString(_ node: FRUSRenderNode,
                                               fontSize: CGFloat = 10,
                                               bold: Bool = false,
                                               italic: Bool = false) -> NSAttributedString {
        switch node {
        case .plainText(let s):
            return paintedString(s, attrs: makeStyledAttrs(fontSize: fontSize,
                                                            bold: bold, italic: italic))
        case .boldText(let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: true, italic: italic)
        case .italicText(let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: true)
        case .smallCapsText(let c):
            // CoreText: use lowercase-small-caps feature via descriptor (CTFontCreateCopyWithFeatures removed in iOS 19 SDK)
            let fontName = bold ? "Helvetica-Bold" : "Helvetica"
            let baseFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
            let baseDescriptor = CTFontCopyFontDescriptor(baseFont)
            let scDescriptor = CTFontDescriptorCreateCopyWithFeature(
                baseDescriptor,
                kLowerCaseType as CFNumber,
                kLowerCaseSmallCapsSelector as CFNumber)
            let scFont = CTFontCreateWithFontDescriptor(scDescriptor, fontSize, nil)
            let attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): scFont,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ]
            let result = NSMutableAttributedString()
            for child in c {
                let inner = inlineNodeToAttributedString(child, fontSize: fontSize, bold: bold, italic: italic)
                let m = NSMutableAttributedString(attributedString: inner)
                m.addAttributes(attrs, range: NSRange(location: 0, length: m.length))
                result.append(m)
            }
            return result
        case .underlineText(let c):
            let inner = inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
            let m = NSMutableAttributedString(attributedString: inner)
            m.addAttribute(NSAttributedString.Key(kCTUnderlineStyleAttributeName as String),
                           value: CTUnderlineStyle.single.rawValue as CFNumber,
                           range: NSRange(location: 0, length: m.length))
            return m
        case .termText(let c), .corrText(let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
        case .suppliedText(let c):
            let inner = inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
            let result = NSMutableAttributedString(string: "[",
                                                   attributes: makeStyledAttrs(fontSize: fontSize, bold: bold, italic: italic))
            result.append(inner)
            result.append(NSAttributedString(string: "]",
                                             attributes: makeStyledAttrs(fontSize: fontSize, bold: bold, italic: italic)))
            return result
        case .sicText(let c):
            let inner = inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
            let m = NSMutableAttributedString(attributedString: inner)
            m.addAttribute(.strikethroughStyle,
                           value: 1,
                           range: NSRange(location: 0, length: m.length))
            return m
        case .formulaText(let s):
            return paintedString(s, attrs: makeStyledAttrs(fontSize: fontSize, bold: false, italic: true))
        case .lineBreak:
            return paintedString("\n", attrs: makeAttrs(fontSize: fontSize, bold: false))
        case .footnoteMarker(_, _, _, let label):
            var attrs = makeAttrs(fontSize: max(fontSize - 3, 6), bold: false)
            attrs[NSAttributedString.Key(kCTSuperscriptAttributeName as String)] = 1 as CFNumber
            // #985: a note the volume printed unnumbered gets a bullet, not an invented number.
            // The reading view shows an archival glyph for `.source` here; a PDF cannot carry the
            // inline SVG, and a bullet keeps the marker paired with its endnote entry either way.
            return NSAttributedString(string: label ?? "\u{2022}", attributes: attrs)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, _, let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
        case .pageBreak:
            return NSAttributedString()
        case .unknown(_, let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
        default:
            return blockNodeToAttributedString(node, fontSize: fontSize)
        }
    }

    // MARK: - Highlight Annotation

    /// Plain-Swift wrapper around a highlight `CGColor`, stored as the value of
    /// `Self.highlightAttrKey` attributes.
    ///
    /// `CGColor` is a Core Foundation type that is toll-free-bridged to
    /// `AnyObject`; conditional casts from `Any` straight to `CGColor` are
    /// statically flagged by the compiler as "always succeeds" (and rejected as an
    /// error under this project's warnings-as-errors policy). Wrapping it in an
    /// ordinary struct sidesteps that bridging quirk so the attribute value can be
    /// safely round-tripped through `NSAttributedString` and recovered with a
    /// normal `as?` conditional cast in `drawFrameWithHighlights`.
    private struct HighlightColorBox {
        let cgColor: CGColor
    }

    /// Builds an attributed string for one flat-text leaf chunk (`.plainText`,
    /// `.formulaText`, or `.lineBreak` content), applying `Self.highlightAttrKey`
    /// shading to any sub-ranges that `highlightPaint` reports as overlapping an
    /// `ExportHighlight`, and advancing the tracker's flat-text position by
    /// `text.count`.
    ///
    /// Must be called exactly once, in traversal order, for every chunk of text
    /// that `appendFlatText` would count toward the document's flat text — see
    /// `HighlightPaintTracker`'s usage contract. All other leaf-string construction
    /// in this file (brackets around supplied text, footnote labels, figure
    /// captions, table separators, etc.) intentionally bypasses this method so the
    /// tracker's position counter stays aligned with stored highlight offsets.
    private func paintedString(_ text: String,
                               attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard let tracker = highlightPaint, tracker.isActive else {
            return NSAttributedString(string: text, attributes: attrs)
        }
        let result = NSMutableAttributedString()
        for (range, color) in tracker.partition(text) {
            var spanAttrs = attrs
            if let color { spanAttrs[Self.highlightAttrKey] = HighlightColorBox(cgColor: color.cgColor) }
            result.append(NSAttributedString(string: String(text[range]), attributes: spanAttrs))
        }
        return result
    }

    /// Draws `frame`'s text, first manually painting filled rectangles behind any
    /// glyph runs carrying `Self.highlightAttrKey` shading.
    ///
    /// CoreText's `CTFrameDraw` does not render the Cocoa `NSAttributedString.Key
    /// .backgroundColor` attribute — that's a higher-level text-system feature not
    /// implemented by bare CoreText frame drawing — so highlight backgrounds must
    /// be painted as rectangles derived from each line's typographic bounds and
    /// per-glyph string-index offsets, *before* the text itself is drawn on top.
    ///
    /// - Parameters:
    ///   - frame: The CoreText frame about to be drawn.
    ///   - attrStr: The full attributed string `frame` was created from — needed
    ///     to look up `Self.highlightAttrKey` runs by string index, since `CTFrame`
    ///     does not expose attributes directly.
    ///   - ctx: The destination graphics context (PDF page context).
    private func drawFrameWithHighlights(_ frame: CTFrame, attrStr: NSAttributedString, in ctx: CGContext) {
        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else {
            CTFrameDraw(frame, ctx)
            return
        }

        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &origins)

        ctx.saveGState()
        for (i, line) in lines.enumerated() {
            let lineRange = CTLineGetStringRange(line)
            guard lineRange.length > 0 else { continue }
            let nsLineRange = NSRange(location: lineRange.location, length: lineRange.length)
            guard nsLineRange.location + nsLineRange.length <= attrStr.length else { continue }

            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let origin = origins[i]

            attrStr.enumerateAttribute(Self.highlightAttrKey, in: nsLineRange, options: []) { value, subRange, _ in
                guard let box = value as? HighlightColorBox else { return }
                let startX = CTLineGetOffsetForStringIndex(line, subRange.location, nil)
                let endX   = CTLineGetOffsetForStringIndex(line, subRange.location + subRange.length, nil)
                let rect = CGRect(x: origin.x + min(startX, endX),
                                  y: origin.y - descent,
                                  width: abs(endX - startX),
                                  height: ascent + descent)
                ctx.setFillColor(box.cgColor)
                ctx.fill(rect)
            }
        }
        ctx.restoreGState()

        CTFrameDraw(frame, ctx)
    }

    // MARK: - Text Drawing

    private func draw(
        _ text: String,
        in ctx: CGContext,
        rect: CGRect,
        fontSize: CGFloat,
        bold: Bool,
        gray: CGFloat = 0
    ) {
        guard !text.isEmpty, rect.height > 0, rect.width > 0 else { return }
        let attrs = makeAttrs(fontSize: fontSize, bold: bold, gray: gray)
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, ctx)
    }

    private func draw(_ attrStr: NSAttributedString, in ctx: CGContext, rect: CGRect) {
        guard attrStr.length > 0, rect.height > 0, rect.width > 0 else { return }
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: rect, transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil), ctx)
    }

    private func measureHeight(_ attrStr: NSAttributedString, width: CGFloat) -> CGFloat {
        guard attrStr.length > 0 else { return 0 }
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let constraint = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRangeMake(0, 0), nil, constraint, nil)
        return ceil(size.height) + 4
    }

    /// Builds an `NSAttributedString` converting `_text_` patterns to italic runs.
    /// Non-italic spans use the specified font weight and gray level.
    ///
    /// - Parameters:
    ///   - text: Raw text, may contain `_span_` markers.
    ///   - fontSize: Point size for non-italic runs.
    ///   - gray: Grayscale level (0 = black, 1 = white) for all runs.
    ///   - bold: When `true`, non-italic runs use the bold font face.
    private func noteAttributedString(_ text: String, fontSize: CGFloat,
                                       gray: CGFloat = 0.2,
                                       bold: Bool = false) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "_([^_\\n]+)_") else {
            return NSAttributedString(string: text,
                                      attributes: makeStyledAttrs(fontSize: fontSize,
                                                                   bold: bold, gray: gray))
        }
        var lastEnd = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            if beforeRange.length > 0 {
                result.append(NSAttributedString(
                    string: ns.substring(with: beforeRange),
                    attributes: makeStyledAttrs(fontSize: fontSize, bold: bold, gray: gray)))
            }
            let g1 = match.range(at: 1)
            if g1.location != NSNotFound, g1.length > 0 {
                result.append(NSAttributedString(
                    string: ns.substring(with: g1),
                    attributes: makeStyledAttrs(fontSize: fontSize, bold: bold,
                                                italic: true, gray: gray)))
            }
            lastEnd = match.range.upperBound
        }
        if lastEnd < ns.length {
            result.append(NSAttributedString(
                string: ns.substring(from: lastEnd),
                attributes: makeStyledAttrs(fontSize: fontSize, bold: bold, gray: gray)))
        }
        return result
    }

    /// Builds an `NSAttributedString` for a rich-text prose block (RTF, or a legacy Phase 3b
    /// JSON blob the shared decoder recovers rather than dropping). Bold/italic/
    /// underline/colour spans (decoded once by the shared `CollectionProse`) map to font-face,
    /// underline, and foreground-colour attributes; paragraphs are separated by a blank line.
    /// A linked span renders underlined with the URL appended as small gray text in
    /// parentheses — the v1.14 no-annotation tradeoff (bare CoreText frame drawing has no
    /// link boxes; HTML/DOCX carry the real hyperlink), applied inline for prose. The
    /// decoder splits one user-applied link into multiple consecutive spans wherever any
    /// other inline attribute changes inside the linked range (a bolded word, a colour),
    /// so the parenthetical is emitted once per *run* of consecutive spans sharing the
    /// same `linkURL` — after the run's last span — never once per span (v1.18); the
    /// self-describing-link suppression compares the URL against the whole run's text.
    private func proseAttributedString(_ rtf: Data, fontSize: CGFloat = 11) -> NSAttributedString {
        let paragraphs = CollectionProse.paragraphs(fromRTF: rtf)
        let result = NSMutableAttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n\n",
                                                 attributes: makeAttrs(fontSize: fontSize, bold: false)))
            }
            /// Text accumulated across the current run of consecutive spans sharing one
            /// `linkURL` — the unit the visible-URL parenthetical is emitted for.
            var linkRunText = ""
            for (spanIndex, span) in paragraph.enumerated() {
                var attrs = makeStyledAttrs(fontSize: fontSize, bold: span.bold,
                                            italic: span.italic, gray: 0)
                if span.underline || span.linkURL != nil {
                    attrs[NSAttributedString.Key(kCTUnderlineStyleAttributeName as String)] =
                        CTUnderlineStyle.single.rawValue as CFNumber
                }
                if let hex = span.colorHex, let color = Self.cgColor(fromHex: hex) {
                    attrs[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color
                }
                result.append(NSAttributedString(string: span.text, attributes: attrs))
                if let url = span.linkURL, !url.isEmpty {
                    linkRunText += span.text
                    let nextURL = spanIndex + 1 < paragraph.count
                        ? paragraph[spanIndex + 1].linkURL : nil
                    if nextURL != url {
                        // Last span of this link run — emit the parenthetical once,
                        // unless the linked text IS the URL (self-describing link).
                        if url != linkRunText.trimmingCharacters(in: .whitespacesAndNewlines) {
                            result.append(NSAttributedString(
                                string: " (\(url))",
                                attributes: makeAttrs(fontSize: 8, bold: false, gray: 0.45)))
                        }
                        linkRunText = ""
                    }
                } else {
                    linkRunText = ""
                }
            }
        }
        return result
    }

    /// Parses an uppercase `RRGGBB` string into an opaque sRGB `CGColor`, or `nil` if malformed.
    private static func cgColor(fromHex hex: String) -> CGColor? {
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    private func measureHeight(_ text: String, width: CGFloat, fontSize: CGFloat, bold: Bool) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let attrs = makeAttrs(fontSize: fontSize, bold: bold)
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let constraint = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRangeMake(0, 0), nil, constraint, nil)
        return ceil(size.height) + 4
    }

    /// Font + color attributes with optional italic style.
    private func makeStyledAttrs(fontSize: CGFloat, bold: Bool,
                                  italic: Bool = false, gray: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let fontName: String
        switch (bold, italic) {
        case (true,  true):  fontName = "Helvetica-BoldOblique"
        case (true,  false): fontName = "Helvetica-Bold"
        case (false, true):  fontName = "Helvetica-Oblique"
        case (false, false): fontName = "Helvetica"
        }
        let font: CTFont
        if let cgFont = CGFont(fontName as CFString) {
            font = CTFontCreateWithGraphicsFont(cgFont, fontSize, nil, nil)
        } else {
            font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        }
        return [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1)
        ]
    }


    private func makeAttrs(fontSize: CGFloat, bold: Bool, gray: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let fontName = bold ? "Helvetica-Bold" : "Helvetica"
        let font: CTFont
        if let cgFont = CGFont(fontName as CFString) {
            font = CTFontCreateWithGraphicsFont(cgFont, fontSize, nil, nil)
        } else {
            font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        }
        return [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: gray, alpha: 1)
        ]
    }

    private func drawHRule(ctx: CGContext, y: CGFloat, gray: CGFloat, thickness: CGFloat) {
        let M = Self.margin, W = Self.pageWidth
        ctx.setStrokeColor(CGColor(gray: gray, alpha: 1))
        ctx.setLineWidth(thickness)
        ctx.move(to: CGPoint(x: M, y: y))
        ctx.addLine(to: CGPoint(x: W - M, y: y))
        ctx.strokePath()
    }

    private func drawPageNumber(ctx: CGContext, number: Int) {
        let W = Self.pageWidth, M = Self.margin
        draw("\(number)", in: ctx,
             rect: CGRect(x: W / 2 - 20, y: M / 2 - 8, width: 40, height: 14),
             fontSize: 10, bold: false, gray: 0.5)
    }

    // MARK: - Helpers

    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }
}
