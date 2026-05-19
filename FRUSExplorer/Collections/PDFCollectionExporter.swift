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
final class PDFCollectionExporter: CollectionExporter {

    // MARK: - Page geometry

    private static let pageWidth:  CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin:     CGFloat = 72
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }
    private static var pageRect: CGRect {
        CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    }

    // MARK: - CollectionExporter

    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        let data = try buildPDF(collection: metadata, documents: documents)
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
        documents: [CollectionExportDocument]
    ) throws -> Data {
        let mutableData = NSMutableData()
        var mediaBox = Self.pageRect
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderingFailed
        }

        var pageNumber = 1

        // Cover page
        ctx.beginPDFPage(nil)
        drawCoverPage(ctx: ctx, collection: collection, documents: documents)
        drawPageNumber(ctx: ctx, number: pageNumber)
        ctx.endPDFPage()
        pageNumber += 1

        // Document pages
        for doc in documents {
            drawDocumentSection(ctx: ctx, doc: doc, pageNumber: &pageNumber)
        }

        ctx.closePDF()
        return mutableData as Data
    }

    // MARK: - Cover Page

    private func drawCoverPage(
        ctx: CGContext,
        collection: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) {
        let W = Self.pageWidth, H = Self.pageHeight
        let M = Self.margin, cw = Self.contentWidth

        var y = H - M - 40

        // Title
        let titleHeight = measureHeight(collection.name, width: cw, fontSize: 22, bold: true)
        draw(collection.name, in: ctx,
             rect: CGRect(x: M, y: y - titleHeight, width: cw, height: titleHeight),
             fontSize: 22, bold: true)
        y -= titleHeight + 16

        // Collection note
        if let note = collection.note, !note.isEmpty {
            let noteH = measureHeight(note, width: cw, fontSize: 12, bold: false)
            draw(note, in: ctx,
                 rect: CGRect(x: M, y: y - noteH, width: cw, height: noteH),
                 fontSize: 12, bold: false)
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

        // ToC entries — each shows the full citation, wrapped if needed
        for (i, doc) in documents.enumerated() {
            guard y > M + 20 else { break }
            let label = "\(i + 1).  \(doc.citation.isEmpty ? doc.title : doc.citation)"
            let lineH = measureHeight(label, width: cw - 16, fontSize: 10, bold: false)
            let rowH = min(lineH, 40) // cap at ~3 lines in the ToC
            draw(label, in: ctx,
                 rect: CGRect(x: M + 16, y: y - rowH, width: cw - 16, height: rowH),
                 fontSize: 10, bold: false)
            y -= rowH + 6
        }

        _ = W // suppress warning
    }

    // MARK: - Document Section (multi-page)

    private func drawDocumentSection(
        ctx: CGContext,
        doc: CollectionExportDocument,
        pageNumber: inout Int
    ) {
        let H = Self.pageHeight, M = Self.margin, cw = Self.contentWidth

        // ── First page of document ──────────────────────────────────────────
        ctx.beginPDFPage(nil)
        var y = H - M

        // Citation heading
        let cit = doc.citation.isEmpty ? doc.title : doc.citation
        let citH = measureHeight(cit, width: cw, fontSize: 13, bold: true)
        draw(cit, in: ctx,
             rect: CGRect(x: M, y: y - citH, width: cw, height: citH),
             fontSize: 13, bold: true)
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

        // Body text — may flow across multiple pages
        if !doc.bodyText.isEmpty {
            let attrs = makeAttrs(fontSize: 10, bold: false)
            let attrStr = NSAttributedString(string: doc.bodyText, attributes: attrs)
            let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
            var charOffset = 0
            let totalChars = doc.bodyText.utf16.count

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
                CTFrameDraw(frame, ctx)

                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length == 0 { break }
                charOffset += visible.length

                if charOffset < totalChars {
                    // Text overflowed — new page
                    drawPageNumber(ctx: ctx, number: pageNumber)
                    ctx.endPDFPage()
                    pageNumber += 1
                    ctx.beginPDFPage(nil)
                    y = H - M
                } else {
                    // All text rendered; estimate remaining y space for note placement
                    // Use a conservative estimate: assume text filled the rect
                    y = M + 20 // set y to bottom; note goes on next page for cleanliness
                }
            }
        }

        drawPageNumber(ctx: ctx, number: pageNumber)
        ctx.endPDFPage()
        pageNumber += 1

        // ── Research note page (if any) ─────────────────────────────────────
        if let note = doc.noteText, !note.isEmpty {
            ctx.beginPDFPage(nil)
            var ny = H - M

            // Note header banner
            ctx.setFillColor(CGColor(gray: 0.93, alpha: 1))
            ctx.fill(CGRect(x: M, y: ny - 28, width: cw, height: 28))
            draw("Research Note", in: ctx,
                 rect: CGRect(x: M + 8, y: ny - 22, width: cw - 16, height: 18),
                 fontSize: 11, bold: true, gray: 0.2)
            ny -= 36

            // Citation reminder
            let shortCit = cit.count > 100 ? String(cit.prefix(100)) + "…" : cit
            draw(shortCit, in: ctx,
                 rect: CGRect(x: M, y: ny - 12, width: cw, height: 12),
                 fontSize: 8, bold: false, gray: 0.5)
            ny -= 20

            drawHRule(ctx: ctx, y: ny, gray: 0.7, thickness: 0.3)
            ny -= 12

            // Note body text
            let attrs = makeAttrs(fontSize: 11, bold: false)
            let attrStr = NSAttributedString(string: note, attributes: attrs)
            let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
            let rect = CGRect(x: M, y: M + 20, width: cw, height: ny - M - 20)
            let path = CGPath(rect: rect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, ctx)

            drawPageNumber(ctx: ctx, number: pageNumber)
            ctx.endPDFPage()
            pageNumber += 1
        }
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
