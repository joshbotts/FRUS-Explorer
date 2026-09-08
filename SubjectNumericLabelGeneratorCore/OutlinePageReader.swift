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

// MARK: - PageLine

/// One line of a PDF page, with the geometry that makes it placeable (#1211).
struct PageLine: Sendable, Equatable {
    /// The line's text, whitespace-trimmed.
    let text: String
    /// Left edge, in PDF points from the page's left.
    let x: Double
    /// Top edge, in PDF points from the page's bottom — so LARGER is HIGHER.
    let y: Double
}

// MARK: - OutlinePageReader

/// Reads a subject-file outline page out of the 1963/1965 Records Classification Handbooks.
///
/// ## Why this exists rather than a text-layer parse
/// `PDFPage.string` flattens these three-column tables into an order that is **not the table's row
/// order**. Measured on the POL outline, the flat stream emits `17 -3` then `17-4` and only then
/// the two labels, and at DEF 13 it emits a label *before* its designator — so the obvious rule
/// ("a designator opens an entry, the next line is its label") mis-pairs entries with a shift that
/// cascades through the rest of the page. Reserved slots make it worse: `(Reserved for future use)`
/// is printed in the INSTRUCTION column, so those designators have no label anywhere near them and
/// any positional alignment of N designators to M labels silently slides.
///
/// Geometry removes the problem rather than working around it. Every line carries a `y`, so the
/// table's row order is recoverable by sorting; and the instruction column can be cut away by `x`
/// before anything is read, so its prose can never be mistaken for a label.
///
/// ## The instruction cut is derived per page, never fixed
/// A constant was tried and does not hold: the pages are scanned at slightly different skews, and a
/// cut that reads one page correctly eats the first characters of a label on another (measured: a
/// split at 122 turned `ARMED FORCES` into `MED FORCES`). So the cut is computed from the page's
/// own line-start distribution.
///
/// Version history:
///   1.0 — #1211: initial implementation
enum OutlinePageReader {

    /// Every line left of `maxX`, in the table's own row order (top to bottom, then left to right).
    ///
    /// - Parameters:
    ///   - page: The page to read.
    ///   - maxX: The right edge of the region to read.
    /// - Returns: The lines, sorted top-to-bottom then left-to-right. Empty when the region holds
    ///   no text.
    static func lines(of page: PDFPage, maxX: Double) -> [PageLine] {
        let bounds = page.bounds(for: .mediaBox)
        // THE WHOLE PAGE IS READ AND THEN FILTERED BY x, never clipped by a narrow rect. Clipping
        // works on the 1963 edition, whose instruction column stands to the right of the label —
        // and destroys the 1965 one, where the label shares its LINE with the designator and the
        // instruction is merely indented beneath. A rect ending at the 1965 cut returns `19` and
        // leaves the subject behind.
        guard let selection = page.selection(for: bounds) else { return [] }
        var out: [PageLine] = []
        for line in selection.selectionsByLine() {
            let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let frame = line.bounds(for: page)
            guard Double(frame.minX) < maxX else { continue }
            out.append(PageLine(text: text, x: Double(frame.minX), y: Double(frame.maxY)))
        }
        // THE SORT IS THE FIX. `selectionsByLine()` returns the reading order PDFKit infers, which
        // on these tables interleaves the columns; the y coordinate is the table's own order and
        // does not depend on that inference.
        return out.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y > $1.y }
    }

    /// Where this page's instruction text begins, in points from the left.
    ///
    /// ## The two editions put it in different places, and neither distance is a constant
    /// The 1963 handbook sets instructions in a THIRD COLUMN to the right of the label (measured on
    /// the POL outline: designators at x≈84, labels at 116–152, instructions at 321). The 1965
    /// handbook sets them UNDER the entry at a deeper indent (designators at x≈65, instructions at
    /// 81–91). A rule written for either one silently destroys the other, so the column is found
    /// relative to the page's own designator column rather than at a remembered offset.
    ///
    /// - Parameter page: The page to measure.
    /// - Returns: The instruction indent, or `nil` when the page has no dominant one — in which
    ///   case the caller reads the full width, which is right for a page of bare designators.
    static func instructionColumnStart(of page: PDFPage) -> Double? {
        let bounds = page.bounds(for: .mediaBox)
        guard let selection = page.selection(for: bounds) else { return nil }
        var designatorStarts: [Double] = []
        var histogram: [Int: Int] = [:]
        for line in selection.selectionsByLine() {
            let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let x = Double(line.bounds(for: page).minX)
            histogram[Int(x / 5) * 5, default: 0] += 1
            if OutlineEntryParser.leadingDesignator(text) != nil { designatorStarts.append(x) }
        }
        // The designator column is where the entries begin. Taking the minimum rather than the mode
        // is deliberate: a page whose first entries are sub-numbers indented under a whole number
        // still opens at the outermost designator, and the cut has to sit outside all of them.
        guard let designatorX = designatorStarts.min() else { return nil }
        let candidates = histogram.filter { Double($0.key) > designatorX + 8 && $0.value >= 5 }
        guard let (bucket, _) = candidates.max(by: { $0.value < $1.value }) else { return nil }
        return Double(bucket)
    }

    /// The category code printed in the page's top corner (`POL (p. 7)`).
    ///
    /// The corner mark is the highest-recall page-to-category channel in either handbook — it
    /// survives on far more pages than the running head, which is lost entirely for three
    /// categories (`V`, `OS`, `SOC`).
    ///
    /// ## The strip is the FULL width, and that is not caution
    /// The mark alternates corners with the leaf: recto pages carry it at the right (`POL (p. 7)`
    /// at x=430), verso pages at the LEFT (`POL (p. 8)` at x=83). A right-half strip therefore
    /// finds every odd page of an outline and none of the even ones, which does not fail — it
    /// silently halves the table. Measured before the fix, POL came out with 66 designators and no
    /// entry for 22 through 26, including the `24 SUBVERSION. ESPIONAGE.` this schedule exists to
    /// distinguish from the 1965 edition's `24 SANCTIONS`.
    ///
    /// - Parameter page: The page to read.
    /// - Returns: The code and the printed page number within that outline, or `nil`.
    static func cornerCode(of page: PDFPage) -> (code: String, printedPage: Int)? {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 60,
                           width: bounds.width, height: 60)
        let text = (page.selection(for: strip)?.string ?? "")
            .replacingOccurrences(of: "\n", with: " ")
        if let match = cornerRegex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
           let codeRange = Range(match.range(at: 1), in: text),
           let pageRange = Range(match.range(at: 2), in: text),
           let printed = Int(text[pageRange]) {
            return (String(text[codeRange]), printed)
        }
        // THE 1965 SCAN BREAKS THE CORNER MARK ACROSS TWO LINES — `POL` sits beside the title at
        // x=248 and `5)` alone at x=522 — so the mark is unreadable on most of that edition and a
        // corner-only rule harvested 28 of its 55 categories. The running head is the fallback, and
        // the two channels are complementary rather than redundant: the head is lost for three
        // categories of the 1963 edition (`V`, `OS`, `SOC`) where the corner survives.
        return runningHeadCode(of: page).map { ($0, 0) }
    }

    /// The category code from the page's running head (`POL-POLITICAL AFFAIRS & RELATIONS`).
    ///
    /// - Parameter page: The page to read.
    /// - Returns: The code, or `nil`.
    static func runningHeadCode(of page: PDFPage) -> String? {
        runningHead(of: page)?.code
    }

    /// The running head read as a pair — the code AND the subject name beside it.
    ///
    /// The head is where the category names itself, and reading the label from the same line that
    /// establishes the code costs nothing: the divider tables of contents say the same thing, but
    /// they ABBREVIATE (the 1963 divider prints `DEFENSE` where every head and the outline title
    /// print `DEFENSE AFFAIRS`, and the 1965 dividers drop the `(CIVIL)`, `(GENERAL)` qualifiers
    /// the outlines keep). Taking the label from the head keeps the name a reader will see on the
    /// page the entries came from.
    ///
    /// - Parameter page: The page to read.
    /// - Returns: The code and its subject name, or `nil`.
    static func runningHead(of page: PDFPage) -> (code: String, label: String)? {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 120, width: bounds.width, height: 120)
        guard let selection = page.selection(for: strip) else { return nil }
        for line in selection.selectionsByLine() {
            let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let match = headRegex.firstMatch(
                    in: text, range: NSRange(text.startIndex..., in: text)),
                  let code = Range(match.range(at: 1), in: text),
                  let label = Range(match.range(at: 2), in: text)
            else { continue }
            return (String(text[code]), String(text[label]).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// The SPECIAL INSTRUCTION number printed in a page's corner (`10 (p. 3)`).
    ///
    /// The handbooks' special instructions are numbered rather than lettered, so they carry the
    /// same corner mark shape with a number where a category code would be — which is why
    /// ``cornerCode`` cannot read them and, just as importantly, cannot MISread them as a category.
    ///
    /// - Parameter page: The page to read.
    /// - Returns: The instruction number and the page within it, or `nil`.
    static func numericCorner(of page: PDFPage) -> (instruction: Int, printedPage: Int)? {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 60,
                           width: bounds.width, height: 60)
        let text = (page.selection(for: strip)?.string ?? "")
            .replacingOccurrences(of: "\n", with: " ")
        guard let match = numericCornerRegex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
              let instruction = Range(match.range(at: 1), in: text).flatMap({ Int(text[$0]) }),
              let printed = Range(match.range(at: 2), in: text).flatMap({ Int(text[$0]) })
        else { return nil }
        return (instruction, printed)
    }

    /// `10 (p. 3)`, tolerating the scan's spacing.
    private static let numericCornerRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(\d{1,2})\s*\(\s*p\s*\.\s*(\d{1,2})\s*\)"#)
    }()

    /// A known category code appearing anywhere in the page's top strip.
    ///
    /// ## The third channel, and why a vocabulary makes it safe
    /// Both named channels fail together on some pages: the 1965 POL page carrying entries 22
    /// through 25 prints its corner as `… HANDBOOK POL` with the `5)` thrown onto a second line,
    /// and its running head survives only as `AFFAIRS & RELATIONS` with the code gone. Neither can
    /// read it, so the page — and four whole-number subjects with it — was silently dropped.
    ///
    /// Searching the strip for a bare token would be a guess. Searching it for a token that is
    /// ALREADY a known category, harvested from the pages whose corner or head did survive, is not:
    /// the vocabulary is the constraint, and a page whose strip names no known category is left
    /// unattributed rather than assigned to whatever the scan happened to emit.
    ///
    /// - Parameters:
    ///   - page: The page to read.
    ///   - known: Codes already established from the unambiguous channels.
    /// - Returns: The code, or `nil`.
    static func vocabularyCode(of page: PDFPage, known: Set<String>) -> String? {
        let bounds = page.bounds(for: .mediaBox)
        let strip = CGRect(x: bounds.minX, y: bounds.maxY - 80, width: bounds.width, height: 80)
        let text = (page.selection(for: strip)?.string ?? "")
            .replacingOccurrences(of: "\n", with: " ")
        var found: String?
        for token in text.split(whereSeparator: { !$0.isLetter }) {
            let upper = token.uppercased()
            guard known.contains(upper) else { continue }
            // A strip naming two different categories is ambiguous and is refused: on a divider
            // sheet or a SEE: cross-reference the losing code would be assigned a whole page.
            if let found, found != upper { return nil }
            found = upper
        }
        return found
    }

    /// The running head: a code, a dash, then an ALL-CAPS subject name.
    private static let headRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^([A-Za-z]{1,5})\s*-\s*([A-Z][A-Z &.,'()/-]{4,})$"#)
    }()

    /// `POL (p. 7)`, tolerating the scan's spacing and a lower-cased code (`v (p. 2)`).
    private static let cornerRegex: NSRegularExpression = {
        // Force-unwrapped deliberately: a malformed literal here is a programmer error that must
        // fail on the first run, not silently disable the primary page-to-category channel.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"([A-Za-z]{1,5})\s*\(\s*p\s*\.\s*(\d{1,2})\s*\)"#)
    }()
}
