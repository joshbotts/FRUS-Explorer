// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - OutlineEntry

/// One row of a subject-file outline: a designator and the subject it names (#1211).
struct OutlineEntry: Sendable, Equatable {
    /// `"17"` or `"17-1"`, with the scan's stray spaces closed up.
    let designator: String
    /// `"Diplomatic & Consular Representation"`, wrapped lines rejoined.
    let label: String
}

// MARK: - OutlineEntryParser

/// Turns geometry-ordered page lines into outline entries (#1211).
///
/// ## The grammar, as the handbooks actually print it
/// A row opens with a designator in its own narrow column and carries the subject beside it; a
/// subject too long for the column WRAPS onto rows that carry no designator at all. So the rule is
/// "a designator opens an entry, and every following designator-less row extends it" — which is
/// only safe once the rows are in the table's own order, and they are not in the flat text layer.
/// ``OutlinePageReader`` is what puts them there.
///
/// ## What is deliberately NOT read
/// The instruction column is cut away by geometry before this sees anything, because its prose is
/// indistinguishable from a label once flattened: `Includes letters of credence and exequator.`
/// reads exactly like a subject heading. `(Reserved for future use)` is printed in that column, so
/// a reserved designator arrives here with no label and is DROPPED rather than given the next
/// entry's words — the failure that makes a positional parse slide.
///
/// Version history:
///   1.0 — #1211: initial implementation
enum OutlineEntryParser {

    /// Parses one outline page.
    ///
    /// - Parameters:
    ///   - lines: The page's lines, already ordered and cut to the designator + label columns.
    ///   - footerFloor: Lines at or below this `y` are furniture (the transmittal footer).
    /// - Returns: The entries found, in page order, and the rows refused as furniture.
    static func parse(_ lines: [PageLine], footerFloor: Double) -> (entries: [OutlineEntry],
                                                                   refused: [String]) {
        var entries: [OutlineEntry] = []
        var refused: [String] = []
        var current: (designator: String, label: [String])?

        func close() {
            guard let open = current else { return }
            let label = tidy(open.label.joined(separator: " "))
            // A designator whose label lives in the instruction column arrives with nothing, and
            // dropping it is the point: the alternative is to let the next row's words slide up
            // into it. A RESERVED slot is refused for the same reason at the other end — the 1965
            // edition prints "(Reserved for future use)" inline where the label would be, and
            // shipping that as a subject would tell a reader the file has one.
            if !label.isEmpty, !isReserved(label) {
                entries.append(OutlineEntry(designator: open.designator, label: label))
            }
            current = nil
        }

        for row in rows(lines) {
            guard row.y > footerFloor else { refused.append(row.text); continue }
            if isFurniture(row.text) { refused.append(row.text); continue }
            if let (designator, rest) = leadingDesignator(row.text) {
                close()
                current = (designator, rest.isEmpty ? [] : [rest])
            } else if current != nil {
                current?.label.append(row.text)
            } else {
                refused.append(row.text)
            }
        }
        close()
        return (entries, refused)
    }

    /// Groups lines into table rows, joining the pieces of one row left to right.
    ///
    /// The designator and its label are separate `selectionsByLine()` results whenever the gap
    /// between the columns is wide enough, and one result when it is not — so a row is defined by
    /// its `y`, never by the line count.
    ///
    /// - Parameter lines: Geometry-ordered lines.
    /// - Returns: One entry per row, its pieces joined by a space.
    static func rows(_ lines: [PageLine]) -> [(text: String, y: Double)] {
        var out: [(text: String, y: Double)] = []
        var bucket: [PageLine] = []

        func flush() {
            guard !bucket.isEmpty else { return }
            let joined = bucket.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ")
            out.append((joined, bucket[0].y))
            bucket = []
        }

        for line in lines {
            // 5 points: the tightest leading in these tables is ~10.5pt, and the two halves of one
            // row differ by at most a fraction of a point.
            if let first = bucket.first, abs(first.y - line.y) > 5 { flush() }
            bucket.append(line)
        }
        flush()
        return out
    }

    /// The row's leading designator and whatever follows it, or `nil` when the row opens no entry.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: `("17-1", "Acceptability &")`, or `nil`.
    static func leadingDesignator(_ text: String) -> (String, String)? {
        guard let match = designatorRegex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text)),
              let whole = Range(match.range, in: text),
              let number = Range(match.range(at: 1), in: text)
        else { return nil }
        // `17 -3` and `17- 3` are the same designator as `17-3`. The scan splits at the hyphen
        // often enough that leaving them apart would mint a second, unreachable key.
        let designator = String(text[number]).replacingOccurrences(
            of: #"\s*-\s*"#, with: "-", options: .regularExpression)
        return (designator, String(text[whole.upperBound...]).trimmingCharacters(in: .whitespaces))
    }

    /// A whole number or a hyphenated sub-number at the very start of a row.
    private static let designatorRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^\s*(\d{1,2}(?:\s*-\s*\d{1,2})*)(?:\s+|$)"#)
    }()

    /// Whether a row is a running head, a corner mark, or a transmittal stamp rather than content.
    ///
    /// Pattern-based rather than margin-based: content starts within 90 points of the top on a
    /// continuation page, so a top margin wide enough to drop the running head also drops the first
    /// entry.
    ///
    /// - Parameter text: A joined row.
    /// - Returns: `true` when the row is furniture.
    static func isFurniture(_ text: String) -> Bool {
        let upper = text.uppercased()
        if upper.contains("RECORDS CLASSIF") || upper.contains("CLASSIFICATION HANDBOOK") { return true }
        if upper.contains("TL:RC") || upper.contains("TL: RC") { return true }
        if upper.replacingOccurrences(of: " ", with: "").contains("(P.") { return true }
        // The running head, `POL - POLITICAL AFFAIRS & RELATIONS`. Anchored, so a label that
        // happens to contain a dash is untouched.
        if text.range(of: #"^[A-Za-z]{1,5}\s*-\s*[A-Z][A-Z &.,'()/-]*$"#,
                      options: .regularExpression) != nil { return true }
        return false
    }

    /// Whether a label is the handbooks' placeholder for an unassigned number.
    ///
    /// Tolerant of the scan, which breaks the phrase in several places (`Res erved`, `fGr`,
    /// `us e`) — so the test is on the two words most likely to survive intact.
    ///
    /// - Parameter label: A parsed label.
    /// - Returns: `true` when the number is reserved rather than assigned.
    static func isReserved(_ label: String) -> Bool {
        let squeezed = label.lowercased().replacingOccurrences(
            of: #"[^a-z]"#, with: "", options: .regularExpression)
        return squeezed.contains("reserved") || squeezed.contains("reserved")
    }

    /// Rejoins a wrapped label and drops the continuation marker the handbooks print on it.
    ///
    /// - Parameter raw: The joined label lines.
    /// - Returns: The tidied label.
    static func tidy(_ raw: String) -> String {
        var text = raw
            // The closing parenthesis is lost to the scan often enough that requiring it leaves
            // `32 TERRITORY. BOUNDARIES. (cont'd` on screen.
            .replacingOccurrences(of: #"\(cont'?d\.?\)?"#, with: "",
                                  options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        // The scan spaces punctuation the way the decimal manuals' did.
        for mark in [".", ",", ";", ":"] {
            text = text.replacingOccurrences(of: " \(mark)", with: mark)
        }
        return cutAtInstructionCue(text).trimmingCharacters(in: CharacterSet(charactersIn: " -"))
    }

    /// Cuts a label at the first word the handbooks open an INSTRUCTION with.
    ///
    /// ## Why a cue list rather than more geometry
    /// The column cut removes the instructions on all but a handful of pages, where the scan's skew
    /// puts a line of prose inside the label column. Measured on the parsed tables, that is 42 of
    /// 1,897 labels in the 1963 edition and 14 of 1,648 in the 1965 one — around 2% and under 1% —
    /// and every one of them is a correct heading followed by a sentence: `GENERAL LEDGER Includes
    /// journal vouchers…`. Widening the cut to catch them would take real labels with it on every
    /// other page, so the leak is removed where it is legible instead.
    ///
    /// The cues are the manuals' own imperative openers, and the cut is refused when one begins the
    /// label — a heading that opened with a cue word would otherwise be emptied rather than
    /// trimmed, which turns a cosmetic defect into a missing subject.
    ///
    /// - Parameter label: A parsed label.
    /// - Returns: The label up to the first cue, or the label unchanged.
    static func cutAtInstructionCue(_ label: String) -> String {
        var cut: String.Index?
        for cue in instructionCues {
            guard let found = label.range(of: cue, options: [.caseInsensitive]),
                  found.lowerBound != label.startIndex
            else { continue }
            if cut == nil || found.lowerBound < cut! { cut = found.lowerBound }
        }
        guard let cut else { return label }
        return String(label[..<cut]).trimmingCharacters(in: .whitespaces)
    }

    /// The words the handbooks open an instruction paragraph with.
    static let instructionCues = [
        "Use for ", "Use only ", "Use also ", "Includes ", "Include ", "Exclude:",
        "SEE:", "Subdivide ", "Provided ", "Limit materials ", "For agency ",
    ]
}
