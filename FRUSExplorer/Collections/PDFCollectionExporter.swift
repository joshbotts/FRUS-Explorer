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

        // Body text — rich rendering when available, else plain-text fallback
        let bodyAttrStr: NSAttributedString
        if let model = doc.renderModel {
            bodyAttrStr = renderModelToAttributedString(model)
        } else if !doc.bodyText.isEmpty {
            bodyAttrStr = NSAttributedString(string: doc.bodyText,
                                             attributes: makeAttrs(fontSize: 10, bold: false))
        } else {
            bodyAttrStr = NSAttributedString()
        }
        if bodyAttrStr.length > 0 {
            let framesetter = CTFramesetterCreateWithAttributedString(bodyAttrStr)
            var charOffset = 0
            let totalChars = bodyAttrStr.length

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

    // MARK: - Rich Rendering (Session 81)

    /// Converts a `FRUSDocumentRenderModel` into a single `NSAttributedString` for CoreText
    /// framesetting. Block nodes are concatenated with paragraph breaks; footnote bodies
    /// are appended after the main content with a rule separator and reduced font size.
    private func renderModelToAttributedString(_ model: FRUSDocumentRenderModel) -> NSAttributedString {
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
        // Footnotes section
        if !model.footnotes.isEmpty {
            let ruleAttrs: [NSAttributedString.Key: Any] = makeAttrs(fontSize: 4, bold: false,
                                                                      gray: 0.7)
            result.append(NSAttributedString(string: "\n\u{00A0}\n", attributes: ruleAttrs))
            for note in model.footnotes {
                if case .footnoteBody(_, _, _, _, let label, let children) = note {
                    let fnMark = NSMutableAttributedString(
                        string: "\(label). ",
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
            for row in rows {
                let rowText = row.map { inlineAttributedString($0.children, fontSize: fontSize - 1).string }
                              .joined(separator: " | ")
                result.append(NSAttributedString(string: rowText + "\n",
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
            return NSAttributedString(string: s,
                                      attributes: makeStyledAttrs(fontSize: fontSize,
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
            return NSAttributedString(string: s,
                                      attributes: makeStyledAttrs(fontSize: fontSize, bold: false, italic: true))
        case .lineBreak:
            return NSAttributedString(string: "\n",
                                      attributes: makeAttrs(fontSize: fontSize, bold: false))
        case .footnoteMarker(_, let label):
            var attrs = makeAttrs(fontSize: max(fontSize - 3, 6), bold: false)
            attrs[NSAttributedString.Key(kCTSuperscriptAttributeName as String)] = 1 as CFNumber
            return NSAttributedString(string: label, attributes: attrs)
        case .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
        case .pageBreak:
            return NSAttributedString()
        case .unknown(_, let c):
            return inlineAttributedString(c, fontSize: fontSize, bold: bold, italic: italic)
        default:
            return blockNodeToAttributedString(node, fontSize: fontSize)
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

    /// Builds an `NSAttributedString` for a user-typed note string,
    /// converting `_text_` patterns to italic runs. Non-italic spans use
    /// the default (non-bold, gray) attribute set.
    private func noteAttributedString(_ text: String, fontSize: CGFloat,
                                       gray: CGFloat = 0.2) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "_([^_\\n]+)_") else {
            return NSAttributedString(string: text,
                                      attributes: makeAttrs(fontSize: fontSize, bold: false, gray: gray))
        }
        var lastEnd = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            if beforeRange.length > 0 {
                result.append(NSAttributedString(
                    string: ns.substring(with: beforeRange),
                    attributes: makeAttrs(fontSize: fontSize, bold: false, gray: gray)))
            }
            let g1 = match.range(at: 1)
            if g1.location != NSNotFound, g1.length > 0 {
                result.append(NSAttributedString(
                    string: ns.substring(with: g1),
                    attributes: makeStyledAttrs(fontSize: fontSize, bold: false,
                                                italic: true, gray: gray)))
            }
            lastEnd = match.range.upperBound
        }
        if lastEnd < ns.length {
            result.append(NSAttributedString(
                string: ns.substring(from: lastEnd),
                attributes: makeAttrs(fontSize: fontSize, bold: false, gray: gray)))
        }
        return result
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
