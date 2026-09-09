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

// MARK: - CountryTableGeometry

/// Reads NARA's country-number table by its own column geometry (#1256).
///
/// ## Why this replaces the alignment rules rather than supplementing them
/// The table is ONE document with three code columns, one per era, and the generator's job is to
/// say which column a code sits in. Read as flat text that information is simply absent, so the
/// old parse inferred it: three codes filled the three columns in order, and a partial row was
/// LEFT-aligned when its note said `Discontinued`, RIGHT-aligned when it said `Beginning` or
/// `Established`, and dropped otherwise.
///
/// Every one of those inferences was wrong somewhere, and the failures are silent because a code
/// in the wrong column still glosses — it just names another era's country:
///
/// - **The right-alignment rule fills cells the document leaves EMPTY.** Measured, 15 entries in
///   the shipped 1960–1963 table exist in no column of the source, `77 = Amhara` among them —
///   Amhara's 1960–63 cell is blank and the document gives 77 to the Somali Republic.
/// - **The two branches are tested in the wrong order.** `note.contains("Beginning")` runs before
///   the `Discontinued <year>` branch, so the Ethiopian pattern `Beginning 1936. … Discontinued
///   1960. See 75.` — which states BOTH — always right-aligns. Six of the fifteen come from this.
/// - **A code can land in a column whose span excludes its own year.** `Trieste 60s`, printed in
///   the 1910–1949 column with the note `Established 1940s.`, right-aligned into 1960–1963.
///
/// ## The document answers the question directly, and it is born-digital
/// Its columns sit at constant x for all 23 pages — name 72.0, then 180.9 / 248.5 / 315.9 for
/// 1910–1949 / 1950–1959 / 1960–1963, and notes at 383.5 — and PDFKit reports them exactly. So a
/// code's column is READ rather than inferred, an empty cell stays empty, and a note is evidence
/// about a country rather than the only clue to a column.
///
/// The doc comment this replaces argued that layout could not be trusted and the note could. That
/// was true of the text layer, which discards position; it is not true of the file.
///
/// Version history:
///   1.0 — #1256: initial implementation
enum CountryTableGeometry {

    /// One line of the table, with the geometry that places it.
    struct Line: Sendable {
        /// The line's text, whitespace-trimmed.
        let text: String
        /// Which column's band it was read from — 0 name, 1–3 the eras, 4 notes.
        let column: Int
        /// Left edge in PDF points.
        let x: Double
        /// Top edge in PDF points — larger is higher on the page.
        let y: Double
    }

    /// A row of the table as the document prints it.
    struct Row: Sendable {
        /// The country name, wrapped lines rejoined.
        var name: String
        /// One optional code per era column, in column order.
        var codes: [String?]
        /// The note, wrapped lines rejoined.
        var note: String
    }

    /// The left edge of each column, measured on the shipped scan and constant across its pages.
    ///
    /// Stated rather than clustered per page because the file is a single born-digital export: a
    /// per-page fit would re-derive the same five numbers 23 times and could disagree on a page
    /// whose columns are sparsely filled.
    static let columnOrigins: [Double] = [72.0, 180.9, 248.5, 315.9, 383.5]

    /// Every line of a page, read COLUMN BY COLUMN and tagged with the column it came from.
    ///
    /// ## One selection per column, not one per page
    /// Reading the page whole and sorting the results by `x` is the obvious thing and it is wrong
    /// here: `selectionsByLine()` sometimes returns a whole printed row as a SINGLE line, which
    /// begins at the name column's origin — so `Abyssinia`, the next row's `Acklin Island`, and
    /// three of its codes all arrive as one string at x=72, the codes never reach a code column,
    /// and the name guard then discards the pair. Measured, that welding is what produced
    /// `Bijagoz Islands Billiton Island` and `Niger, Republic of Nigeria`, names of no country.
    ///
    /// Clipping the selection to one column's band cannot weld across columns, because the text
    /// outside the rect is not in the selection to begin with.
    ///
    /// - Parameter page: The page to read.
    /// - Returns: Its lines, each carrying its column index, top to bottom then left to right.
    static func lines(of page: PDFPage) -> [Line] {
        let bounds = page.bounds(for: .mediaBox)
        var out: [Line] = []
        for (index, origin) in columnOrigins.enumerated() {
            let width = index + 1 < columnOrigins.count
                ? columnOrigins[index + 1] - origin
                : Double(bounds.maxX) - origin
            let rect = CGRect(x: origin - 4, y: bounds.minY,
                              width: width, height: bounds.height)
            guard let selection = page.selection(for: rect) else { continue }
            for line in selection.selectionsByLine() {
                let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let frame = line.bounds(for: page)
                out.append(Line(text: text, column: index,
                                x: Double(frame.minX), y: Double(frame.maxY)))
            }
        }
        return out.sorted { $0.y == $1.y ? $0.column < $1.column : $0.y > $1.y }
    }

    /// Reads the whole table.
    ///
    /// - Parameters:
    ///   - document: The country-number PDF.
    ///   - isCode: Whether a token is a country code.
    /// - Returns: The rows, in document order.
    static func rows(in document: PDFDocument, isCode: (String) -> Bool) -> [Row] {
        var out: [Row] = []
        var open: Row?

        func close() {
            guard var row = open else { return }
            open = nil
            row.name = tidy(row.name)
            row.note = tidy(row.note)
            guard !row.name.isEmpty else { return }
            out.append(row)
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for grouped in group(lines(of: page)) {
                var name = ""
                var note = ""
                var codes: [String?] = [nil, nil, nil]
                var sawCode = false
                for line in grouped {
                    switch line.column {
                    case 0:
                        name += name.isEmpty ? line.text : " \(line.text)"
                    case 1, 2, 3:
                        // A cell holds one code. Where the scan welds two, the first is this
                        // column's and the rest belong to columns the loop reaches on their own.
                        guard let token = line.text.split(separator: " ").first.map(String.init),
                              isCode(token) else { continue }
                        codes[line.column - 1] = token
                        sawCode = true
                    default:
                        note += note.isEmpty ? line.text : " \(line.text)"
                    }
                }
                // A CODE OPENS A ROW; anything else continues the one above it. Every entry in
                // this table carries at least one code, so a code-less group is a wrapped name or
                // a wrapped note — `Trust Territory of` / `Somaliland` is the type case, and
                // treating it as a new row would ship a country named for half a phrase.
                if sawCode {
                    close()
                    open = Row(name: name, codes: codes, note: note)
                } else if var row = open {
                    if !name.isEmpty { row.name += " \(name)" }
                    if !note.isEmpty { row.note += row.note.isEmpty ? note : " \(note)" }
                    open = row
                } else if !name.isEmpty || !note.isEmpty {
                    // Page furniture above the first row of a page.
                    continue
                }
            }
            close()
        }
        close()
        return out
    }

    /// Groups a page's lines into table rows by their vertical position.
    ///
    /// - Parameter lines: The page's lines, already ordered.
    /// - Returns: One group per printed row.
    static func group(_ lines: [Line]) -> [[Line]] {
        var out: [[Line]] = []
        var bucket: [Line] = []
        for line in lines {
            // 4 points: the table's leading is ~13, and the cells of one row differ by under a
            // point. A generous tolerance would merge a row with the one beneath it.
            if let first = bucket.first, abs(first.y - line.y) > 4 {
                out.append(bucket)
                bucket = []
            }
            bucket.append(line)
        }
        if !bucket.isEmpty { out.append(bucket) }
        return out
    }

    /// Collapses whitespace in a rejoined cell.
    ///
    /// - Parameter text: The joined text.
    /// - Returns: The tidied text.
    static func tidy(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
