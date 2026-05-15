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

/// Exports a `Collection` to a multi-page PDF using CoreGraphics + CoreText.
///
/// ## Output structure
/// 1. Cover page — collection title, optional note, table of contents
/// 2. One page per document — title, date, body preview, optional research note
///
/// Uses the PDF coordinate system (origin at lower-left, points at 72 DPI).
/// CoreText is used throughout so the same code path runs on iOS and macOS.
///
/// ## File location
/// Output is written to `FileManager.default.temporaryDirectory`. The caller
/// must move or share the file before the OS clears the temp directory.
///
/// Version history:
///   1.0 — Session 22: initial implementation
public final class PDFCollectionExporter: CollectionExporter {

    // MARK: - Page geometry

    private static let pageWidth: CGFloat  = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat     = 72
    private static var pageRect: CGRect {
        CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    }
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - CollectionExporter

    public func export(
        collection: Collection,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        let data = try buildPDF(collection: collection, documents: documents)
        let filename = sanitized(collection.name) + ".pdf"
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
        collection: Collection,
        documents: [CollectionExportDocument]
    ) throws -> Data {
        let mutableData = NSMutableData()
        var mediaBox = Self.pageRect
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderingFailed
        }

        ctx.beginPDFPage(nil)
        drawCoverPage(ctx: ctx, collection: collection, documents: documents)
        ctx.endPDFPage()

        for doc in documents {
            ctx.beginPDFPage(nil)
            drawDocumentPage(ctx: ctx, doc: doc)
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return mutableData as Data
    }

    // MARK: - Cover Page

    private func drawCoverPage(
        ctx: CGContext,
        collection: Collection,
        documents: [CollectionExportDocument]
    ) {
        let W = Self.pageWidth, H = Self.pageHeight, M = Self.margin
        let cw = Self.contentWidth

        // Title
        var y = H - M - 40
        draw(collection.name, in: ctx,
             rect: CGRect(x: M, y: y, width: cw, height: 36),
             fontSize: 22, bold: true)
        y -= 44

        // Collection note
        if let note = collection.note, !note.isEmpty {
            let noteLines = min(5, max(1, note.count / 80 + 1))
            let noteHeight = CGFloat(noteLines) * 16 + 8
            draw(note, in: ctx,
                 rect: CGRect(x: M, y: y - noteHeight, width: cw, height: noteHeight),
                 fontSize: 12, bold: false)
            y -= noteHeight + 20
        }

        // Separator line
        ctx.setStrokeColor(CGColor(gray: 0.6, alpha: 1))
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: M, y: y))
        ctx.addLine(to: CGPoint(x: W - M, y: y))
        ctx.strokePath()
        y -= 20

        // ToC header
        draw("Contents", in: ctx,
             rect: CGRect(x: M, y: y - 18, width: cw, height: 16),
             fontSize: 13, bold: true)
        y -= 32

        // ToC entries
        for (i, doc) in documents.enumerated() {
            guard y > M + 20 else { break }
            let label = "\(i + 1).  \(doc.title)"
            draw(label, in: ctx,
                 rect: CGRect(x: M + 8, y: y - 14, width: cw - 8, height: 14),
                 fontSize: 11, bold: false)
            y -= 18
        }

        // Page number
        drawPageNumber(ctx: ctx, number: 1)
    }

    // MARK: - Document Page

    private func drawDocumentPage(ctx: CGContext, doc: CollectionExportDocument) {
        let H = Self.pageHeight, M = Self.margin
        let cw = Self.contentWidth

        // Document title
        var y = H - M - 28
        draw(doc.title, in: ctx,
             rect: CGRect(x: M, y: y, width: cw, height: 24),
             fontSize: 16, bold: true)
        y -= 30

        // Date
        if let date = doc.date, !date.isEmpty {
            draw(date, in: ctx,
                 rect: CGRect(x: M, y: y - 14, width: cw, height: 14),
                 fontSize: 11, bold: false)
            y -= 20
        }

        // Separator
        ctx.setStrokeColor(CGColor(gray: 0.7, alpha: 1))
        ctx.setLineWidth(0.3)
        ctx.move(to: CGPoint(x: M, y: y))
        ctx.addLine(to: CGPoint(x: M + cw, y: y))
        ctx.strokePath()
        y -= 14

        // Body text (truncated to fit one page)
        let availableBodyHeight: CGFloat
        if let note = doc.noteText, !note.isEmpty {
            availableBodyHeight = y - M - 72
        } else {
            availableBodyHeight = y - M - 20
        }

        if !doc.bodyText.isEmpty && availableBodyHeight > 0 {
            draw(doc.bodyText, in: ctx,
                 rect: CGRect(x: M, y: M + (doc.noteText != nil ? 68 : 16),
                              width: cw, height: availableBodyHeight),
                 fontSize: 11, bold: false)
        }

        // Research note at bottom
        if let note = doc.noteText, !note.isEmpty {
            let noteBoxY: CGFloat = M
            let noteBoxH: CGFloat = 60
            ctx.setFillColor(CGColor(gray: 0.95, alpha: 1))
            ctx.fill(CGRect(x: M, y: noteBoxY, width: cw, height: noteBoxH))
            draw("Research Note:", in: ctx,
                 rect: CGRect(x: M + 6, y: noteBoxY + noteBoxH - 18, width: 120, height: 14),
                 fontSize: 10, bold: true)
            let notePreview = String(note.prefix(300))
            draw(notePreview, in: ctx,
                 rect: CGRect(x: M + 6, y: noteBoxY + 4, width: cw - 12, height: noteBoxH - 22),
                 fontSize: 10, bold: false)
        }

        drawPageNumber(ctx: ctx, number: doc.sortOrder + 2)
    }

    // MARK: - Text Drawing

    private func draw(
        _ text: String,
        in ctx: CGContext,
        rect: CGRect,
        fontSize: CGFloat,
        bold: Bool
    ) {
        guard !text.isEmpty, rect.height > 0, rect.width > 0 else { return }

        let fontName = bold ? "Helvetica-Bold" : "Helvetica"
        let font: CTFont
        if let cgFont = CGFont(fontName as CFString) {
            font = CTFontCreateWithGraphicsFont(cgFont, fontSize, nil, nil)
        } else {
            font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 0, alpha: 1)
        ]

        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, ctx)
    }

    private func drawPageNumber(ctx: CGContext, number: Int) {
        let M = Self.margin, W = Self.pageWidth
        draw("\(number)", in: ctx,
             rect: CGRect(x: W / 2 - 20, y: M / 2 - 8, width: 40, height: 14),
             fontSize: 10, bold: false)
    }

    // MARK: - Helpers

    private func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
    }
}
