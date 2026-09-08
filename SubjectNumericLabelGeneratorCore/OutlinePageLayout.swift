// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
import PDFKit

// MARK: - OutlinePageLayout

/// Works out how one outline page is laid out before anything is read from it (#1211).
///
/// ## Three layouts, one book each and one shared by both
/// The 1963 handbook sets a single entry column with instructions in a third column to its right.
/// The 1965 handbook sets a single entry column with instructions indented beneath it — and, on
/// some of its pages, TWO entry columns side by side. That last one is the layout that cannot be
/// ignored: rows are grouped by `y`, so two columns at the same height merge into one row and the
/// right column's entries are swallowed into the left column's labels. Measured before this
/// existed, the 1965 `POL 3` came out carrying the whole of `POL 7` and its instruction prose.
///
/// So the page's own designator positions decide. Where they fall into two well-separated groups
/// the page is read as two columns, left then right; where they do not, as one.
///
/// Version history:
///   1.0 — #1211: initial implementation
enum OutlinePageLayout {

    /// A column of entries: where it starts, where the next one starts, and where its instruction
    /// text begins.
    struct Column: Sendable, Equatable {
        /// Left edge of the column, a little outside its designators.
        let minX: Double
        /// Right edge — the next column's left edge, or the page's.
        let maxX: Double
        /// Instruction indent within the column; lines at or right of it are prose.
        let instructionX: Double
    }

    /// The minimum gap between two entry columns' designators.
    ///
    /// A label indented under its designator sits some 30–60 points in; two columns of a
    /// letter-size page sit some 250 apart. 150 separates them with room on both sides, and is
    /// checked by a fixture at each extreme rather than reasoned about alone.
    static let columnGap: Double = 150

    /// Where an edition prints the instruction text that must never be read as a label.
    ///
    /// ## Why this is per-edition and not inferred
    /// One rule was tried for both and cannot exist. In the 1963 handbook a wrapped label sits 68
    /// points right of its designator and the instructions 237 points right; in the 1965 handbook
    /// the label shares the designator's line and the instructions are 16 points right. So "the
    /// nearest column to the right of the designators" reads 1965 correctly and eats 1963's labels,
    /// while "the dominant far-right column" reads 1963 correctly and finds nothing in 1965. Any
    /// constant that separates them in one book merges them in the other. The generator knows which
    /// edition it has open, so it says which typography to expect rather than guessing from a page.
    enum Layout: Sendable {
        /// Instructions in a third column at the right of the page (1963).
        case rightColumn
        /// Instructions indented beneath the entry (1965).
        case indent
    }

    /// Reads the page's layout.
    ///
    /// - Parameters:
    ///   - page: The page to measure.
    ///   - layout: Where this edition prints its instructions.
    /// - Returns: One or two columns, left to right. Empty when the page has no designators at all,
    ///   which is how a divider or an instruction page declines to be read as an outline.
    static func columns(of page: PDFPage, layout: Layout) -> [Column] {
        let bounds = page.bounds(for: .mediaBox)
        guard let selection = page.selection(for: bounds) else { return [] }
        var designatorX: [Double] = []
        var allX: [Double] = []
        for line in selection.selectionsByLine() {
            let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let x = Double(line.bounds(for: page).minX)
            allX.append(x)
            if OutlineEntryParser.leadingDesignator(text) != nil { designatorX.append(x) }
        }
        guard !designatorX.isEmpty else { return [] }

        let starts = columnStarts(designatorX.sorted())
        var out: [Column] = []
        for (index, start) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1] - 5 : Double(bounds.maxX)
            let inColumn = allX.filter { $0 >= start - 5 && $0 < end }
            let instruction: Double?
            switch layout {
            case .rightColumn:
                instruction = dominantFarColumn(in: inColumn, pageWidth: Double(bounds.width))
            case .indent:
                instruction = nearestIndent(in: inColumn, designatorX: start)
            }
            out.append(Column(minX: start - 5, maxX: end, instructionX: instruction ?? end))
        }
        return out
    }

    /// Splits sorted designator positions into one or two column starts.
    ///
    /// - Parameter sorted: Designator left edges, ascending.
    /// - Returns: Each column's leftmost designator position.
    static func columnStarts(_ sorted: [Double]) -> [Double] {
        guard let first = sorted.first else { return [] }
        var starts = [first]
        for (previous, current) in zip(sorted, sorted.dropFirst()) where current - previous > columnGap {
            starts.append(current)
        }
        return starts
    }

    /// The 1963 layout's instruction column: the busiest cluster in the page's right half.
    ///
    /// Taking the busiest rather than the nearest is what protects the label column, whose wrapped
    /// continuations sit well right of their designators and carry only a line or two each.
    ///
    /// - Parameters:
    ///   - positions: Every line start inside the column.
    ///   - pageWidth: The page's width, which sets where "the right half" begins.
    /// - Returns: The column's left edge, or `nil`.
    static func dominantFarColumn(in positions: [Double], pageWidth: Double) -> Double? {
        var histogram: [Int: Int] = [:]
        for x in positions where x > pageWidth * 0.4 { histogram[Int(x / 5) * 5, default: 0] += 1 }
        guard let (bucket, count) = histogram.max(by: { $0.value < $1.value }), count >= 5
        else { return nil }
        return Double(bucket)
    }

    /// The 1965 layout's instruction indent: the NEAREST supported step right of the designators.
    ///
    /// Nearest rather than busiest, and the difference is not cosmetic. That edition indents an
    /// instruction under a whole number to one stop and under a sub-number to a deeper one, so the
    /// busiest step is the deeper of the two — and a cut placed there keeps every instruction
    /// belonging to a whole number. Measured before the fix, `POL 27` shipped with the whole of its
    /// instruction paragraph as its subject heading.
    ///
    /// - Parameters:
    ///   - positions: Every line start inside the column.
    ///   - designatorX: The column's designator position.
    /// - Returns: The indent, or `nil`.
    static func nearestIndent(in positions: [Double], designatorX: Double) -> Double? {
        var histogram: [Int: Int] = [:]
        for x in positions where x > designatorX + 8 { histogram[Int(x / 5) * 5, default: 0] += 1 }
        // Three lines, not five: a two-column page splits the same prose between two columns, so a
        // floor tuned to a full-width column stops finding it exactly where it matters most.
        guard let bucket = histogram.filter({ $0.value >= 3 }).keys.min() else { return nil }
        return Double(bucket)
    }
}
