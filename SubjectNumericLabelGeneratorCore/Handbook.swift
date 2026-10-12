// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation

// MARK: - HandbookPage

/// One page of a handbook: its size and its lines of text, read once (#1644).
struct HandbookPage: Sendable, Equatable {
    /// The page's width, in points.
    let width: Double
    /// The page's height, in points.
    let height: Double
    /// Every line of the page, top to bottom and then left to right.
    let lines: [PageLine]

    /// The lines in a strip across the top of the page.
    ///
    /// A line is in the strip when the MIDDLE of its height is. That is what PDFKit's selection
    /// of a rectangle took, and the strips' depths (60, 80 and 120 points) were set against it:
    /// measured on macOS 27 over every page of both handbooks, the middle gives the characters
    /// PDFKit's selection gave on 1,120 of 1,182 page-and-depth pairs of the 1963 handbook and
    /// 777 of 783 of the 1965 one, where "any part of the line" gives 898 and 609.
    ///
    /// - Parameter depth: The strip's depth from the top edge, in points.
    /// - Returns: The strip's lines, top to bottom and then left to right.
    func lines(inTop depth: Double) -> [PageLine] {
        lines.filter { $0.y - $0.height / 2 > height - depth }
    }

    /// The text of a strip across the top of the page, its lines separated by line breaks.
    ///
    /// - Parameter depth: The strip's depth from the top edge, in points.
    /// - Returns: The strip's text.
    func text(inTop depth: Double) -> String {
        lines(inTop: depth).map(\.text).joined(separator: "\n")
    }
}

// MARK: - Handbook

/// A Records Classification Handbook, opened and read into lines (#1644).
///
/// Every page is read when the document is opened, because every pass of the generator walks the
/// whole book and several walk it twice. A page that uses anything ``TextLayerReader`` does not
/// model fails the open: a handbook is read whole or not at all.
struct Handbook: Sendable {
    /// The pages, in the file's order.
    let pages: [HandbookPage]

    /// Makes a handbook from pages already read.
    ///
    /// - Parameter pages: The pages, in order.
    init(pages: [HandbookPage]) {
        self.pages = pages
    }

    /// Opens a handbook.
    ///
    /// - Parameter url: The PDF's location.
    /// - Throws: ``GenerationError`` when the file cannot be opened, or a page cannot be read by
    ///   ``TextLayerReader``.
    init(contentsOf url: URL) throws {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else {
            throw GenerationError(description: "cannot open \(url.path)")
        }
        var pages: [HandbookPage] = []
        pages.reserveCapacity(document.numberOfPages)
        for number in 1...document.numberOfPages {
            guard let page = document.page(at: number) else {
                throw GenerationError(description: "\(url.lastPathComponent) has no page \(number)")
            }
            let box = page.getBoxRect(.mediaBox)
            // The parse measures from the page's own corner. Both handbooks' pages begin at the
            // origin; a page that did not would put every threshold out by its offset.
            guard box.minX == 0, box.minY == 0 else {
                throw GenerationError(description: "\(url.lastPathComponent) page \(number) "
                    + "does not begin at the origin (\(box.minX), \(box.minY))")
            }
            pages.append(HandbookPage(width: Double(box.width), height: Double(box.height),
                                      lines: TextLayerReader.lines(
                                        from: try TextLayerReader.runs(of: page))))
        }
        self.pages = pages
    }
}
