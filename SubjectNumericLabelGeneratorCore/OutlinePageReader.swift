// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PageLine

/// One line of a PDF page, with the geometry that makes it placeable (#1211).
struct PageLine: Sendable, Equatable {
    /// The line's text, whitespace-trimmed.
    let text: String
    /// Left edge, in PDF points from the page's left.
    let x: Double
    /// Top edge, in PDF points from the page's bottom — so LARGER is HIGHER.
    let y: Double
    /// The line's height: the type size of its tallest run. Zero where it is not known, which is
    /// every fixture that tests a rule the height plays no part in.
    var height: Double = 0
}

// MARK: - OutlinePageReader

/// Reads a subject-file outline page out of the 1963/1965 Records Classification Handbooks.
///
/// ## Why this exists rather than a text-layer parse
/// A page's text in reading order flattens these three-column tables into an order that is **not
/// the table's row order**. Measured on the POL outline, the flat stream emits `17 -3` then `17-4`
/// and only then the two labels, and at DEF 13 it emits a label *before* its designator — so the
/// obvious rule ("a designator opens an entry, the next line is its label") mis-pairs entries with
/// a shift that cascades through the rest of the page. Reserved slots make it worse: `(Reserved
/// for future use)` is printed in the INSTRUCTION column, so those designators have no label
/// anywhere near them and any positional alignment of N designators to M labels silently slides.
///
/// Geometry removes the problem rather than working around it. Every line carries a `y`, so the
/// table's row order is recoverable by sorting; and the instruction column can be cut away by `x`
/// before anything is read, so its prose can never be mistaken for a label.
///
/// ## The instruction cut is derived per page, never fixed
/// A constant was tried and does not hold: the pages are scanned at slightly different skews, and a
/// cut that reads one page correctly eats the first characters of a label on another (measured: a
/// split at 122 turned `ARMED FORCES` into `MED FORCES`). So the cut is computed from the page's
/// own line-start distribution (``OutlinePageLayout``).
///
/// ## Where the lines come from
/// From the page's content stream, through ``TextLayerReader`` (#1644). Until then they were
/// PDFKit's (`selectionsByLine()`), and the table changed when the operating system did.
///
/// Version history:
///   1.0 — #1211: initial implementation
///   1.1 — #1644: reads ``HandbookPage`` lines, which come from the content stream and not from
///          PDFKit; the unused per-page instruction-column measurement is removed
enum OutlinePageReader {

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
    static func cornerCode(of page: HandbookPage) -> (code: String, printedPage: Int)? {
        let text = page.text(inTop: 60).replacingOccurrences(of: "\n", with: " ")
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
        return runningHead(of: page).map { ($0.code, 0) }
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
    static func runningHead(of page: HandbookPage) -> (code: String, label: String)? {
        for line in page.lines(inTop: 120) {
            let text = line.text
            guard let match = headRegex.firstMatch(
                    in: text, range: NSRange(text.startIndex..., in: text)),
                  let code = Range(match.range(at: 1), in: text),
                  let label = Range(match.range(at: 2), in: text)
            else { continue }
            return (String(text[code]), String(text[label]).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Whether a page belongs to a handbook's alphabetical index (#1644).
    ///
    /// ## Known by its leaders, because its corner mark is not always legible
    /// An index line runs from a subject to the designation it is filed under along a row of
    /// dots (`BRANCH BANKS ........ FN 6`), and nothing else in either handbook is set that way.
    /// Counted over every page: an index page of the 1963 handbook has at least 44 such lines
    /// and one of the 1965 handbook at least 9, while no other page of the first has more than 2
    /// and no other page of the second more than 1. (One page of the 1963 index has no text
    /// layer at all, and is given to nothing because it says nothing.)
    ///
    /// The corner mark cannot do this alone. The 1963 index prints `Index (p. 12)` and it is
    /// read on 68 of its 73 pages; the 1965 one prints the same and the capture read the word on
    /// none of them. An index page nobody has named is then open to the vocabulary channel,
    /// whose strip holds the page's first entries and the category codes they end in — and its
    /// lines open with numbers often enough to be read as an outline. That is where the shipped
    /// table's `POL 15-4` under 1964–1973 came by the reading *BG*.
    ///
    /// - Parameter page: The page to test.
    /// - Returns: `true` when the page is an index page.
    static func isIndexPage(_ page: HandbookPage) -> Bool {
        page.lines.lazy.filter { line in
            leaderRegex.firstMatch(in: line.text,
                                   range: NSRange(line.text.startIndex..., in: line.text)) != nil
        }.prefix(minimumLeaderLines).count == minimumLeaderLines
    }

    /// How many lines with a leader make a page an index page: three times the most any other
    /// page has, and under the fewest any index page has.
    static let minimumLeaderLines = 6

    /// A dotted leader: four or more full stops, bullets or centred dots, spaced or not.
    private static let leaderRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?:[.\x{2022}\x{00B7}]\s?){4,}"#)
    }()

    /// The SPECIAL INSTRUCTION number printed in a page's corner (`10 (p. 3)`).
    ///
    /// The handbooks' special instructions are numbered rather than lettered, so they carry the
    /// same corner mark shape with a number where a category code would be — which is why
    /// ``cornerCode`` cannot read them and, just as importantly, cannot MISread them as a category.
    ///
    /// - Parameter page: The page to read.
    /// - Returns: The instruction number and the page within it, or `nil`.
    static func numericCorner(of page: HandbookPage) -> (instruction: Int, printedPage: Int)? {
        let text = page.text(inTop: 60).replacingOccurrences(of: "\n", with: " ")
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
    static func vocabularyCode(of page: HandbookPage, known: Set<String>) -> String? {
        let text = page.text(inTop: 80).replacingOccurrences(of: "\n", with: " ")
        var found: String?
        for token in text.split(whereSeparator: { !$0.isLetter }) {
            let upper = correctedCode(token.uppercased())
            guard known.contains(upper) else { continue }
            // A strip naming two different categories is ambiguous and is refused: on a divider
            // sheet or a SEE: cross-reference the losing code would be assigned a whole page.
            if let found, found != upper { return nil }
            found = upper
        }
        return found
    }

    /// A category code as the handbook prints it, where the scan reads it short (#1644).
    ///
    /// Curated rather than ruled, for the reason the abbreviations' own corrections give: this is
    /// damage to a NAME, and no rule repairs a lost letter without licensing rewrites the page
    /// does not support. The 1965 scan reads the corner mark of `INCO` (Industries &
    /// Commodities) without its first letter, or with the letter set apart, on five of the
    /// eight pages of that outline that carry one (`.!NCO (p. 4)`, `I NCO`), and no category of
    /// either edition is `NCO`. Left as read, 22 of the outline's entries were filed under a
    /// category no key cites.
    ///
    /// - Parameter code: A code as read from a page's top strip, upper-cased.
    /// - Returns: The code the handbook prints.
    static func correctedCode(_ code: String) -> String {
        misreadCodes[code] ?? code
    }

    /// The scan's misreadings of a category code, each checked against the printed page.
    static let misreadCodes: [String: String] = [
        "NCO": "INCO",
    ]

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
