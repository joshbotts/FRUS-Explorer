// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Display-time repair for the two indexed-header defects every result row inherits (X-2).
///
/// Modern volumes' indexed headers **begin with their own document number**, so a row that also
/// renders a number chip reads "251. **251.** Memorandum From…" — and some extracted headers run
/// straight on into the document's archival source note, so a title ends "…(Rostow) **Source:
/// Johnson Library, National Security File…**", spending a 390-pt row's two-line budget on
/// provenance that has its own field. The 2026-08-14 UI review filed both on all three platforms
/// (Mac M-6, iPad F-21, iPhone P-5).
///
/// **Display-time, deliberately.** When this shipped, the cure was assumed to be in header
/// *extraction*; #888's close measured otherwise — `extractHeader` has excluded head-nested
/// notes since v15, and the live index holds ZERO leaky headers across all 316,839 documents.
/// What actually still leaked was a display-time derivation that bypassed the extractor
/// (`DocumentViewModel.documentTitle` used `plainText`), fixed at #888 by routing it through
/// `IndexingPipeline.extractHeader`. ``trimmedHeader(_:)`` remains as the belt for a device
/// whose index predates the v15 fix and has not re-indexed — a real population until the next
/// forced bump — and for any stored header reaching a title without a re-parse.
///
/// #1391 added the split for rows that keep the number in a column of their own
/// (``numberedRow(header:number:)``): the Source Explorer twins' Archival Neighbors rows and the
/// Cross-Reference Graph's document picker and reference list.
///
/// Version history:
///   1.0 — UI review wave 1 (CW-2): initial implementation
///   1.1 — #888: charter corrected — extraction was already clean; this is the stale-index belt
///   1.2 — #1391: `numberedRow(header:number:)`, the number column's split
enum DocumentHeaderDisplay {

    /// Whether the header already begins with this document number, making a separate chip a
    /// duplicate.
    ///
    /// Matches "251." and "251 " starts, including letter-suffixed numbers ("372a."), and is
    /// deliberately exact about the number: a header starting "2510." does not repeat "251".
    ///
    /// - Parameters:
    ///   - header: The indexed header.
    ///   - number: The row's document number, when it has one.
    /// - Returns: `true` when rendering both would double-number the row.
    static func headerRepeatsNumber(_ header: String, number: String?) -> Bool {
        guard let number, !number.isEmpty else { return false }
        let trimmed = header.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(number) else { return false }
        let tail = trimmed.dropFirst(number.count)
        guard let next = tail.first else { return true }
        return next == "." || next == " "
    }

    /// The two columns of a row that prints the document number beside its title (#1391).
    struct NumberedRow: Equatable, Sendable {
        /// The row's number column: the document number exactly as the caller passed it.
        let number: String?
        /// What to draw beside the number: the stored header, less the number it already prints.
        let title: String
    }

    /// What a row with a number column of its own draws: the number, and the header without the
    /// number the head already prints (#1391).
    ///
    /// **Why the title gives way and not the column.** Measured over the 553 manifest volumes'
    /// TEI, each `<head>` read without its notes as `IndexingPipeline.extractHeader` reads it:
    /// **79,479 of 314,571 documents, in 231 volumes, have a head that opens with their own `@n`
    /// and a full stop** (`256. Department of State Briefing Memorandum`), so a row that draws the
    /// number beside the stored header reads "256  256. Department…". The rest print the number
    /// only in `@n`, and for them the column is the only place it appears. Browse, whose rows have
    /// no column, dropped the number instead (`DocumentRowLabel`); a search row withholds its chip
    /// (``headerRepeatsNumber(_:number:)``). A fixed-width column cannot come and go without
    /// misaligning the list, so here the column stays and the title loses its prefix.
    ///
    /// **The rule is the document's own number and a full stop, and nothing looser**, each part
    /// measured over the same scan:
    /// - No space is required after the stop. `frus1882` d61 is encoded `61.<lb/>Mr. Trescot…`,
    ///   and three heads in the corpus have no whitespace there at all, so the row reads the same
    ///   whatever the stored header's join makes of the line break.
    /// - The number must be the document's own. 15 heads in 6 volumes open with a different number
    ///   (`frus1873p2v3` d17, `@n` 17, prints *1. Sir Edward Thornton to Mr. Fish.*), and there the
    ///   number is part of the title.
    /// - The number and a space, with no stop, is not stripped. No head in the corpus has that
    ///   shape; ``headerRepeatsNumber(_:number:)`` accepts it, and answers a different question.
    /// - A head that is only its number keeps it, so the row never loses its title (no head in the
    ///   corpus is only a number).
    ///
    /// The stored header is not changed: search, citations and the reader all read it as printed.
    ///
    /// - Parameters:
    ///   - header: The stored header, as `document_cache` holds it.
    ///   - number: The document number (`@n`), when the row has one.
    /// - Returns: The number unchanged, and the header without its leading "number." when it opens
    ///   with one; otherwise the number and the header both unchanged.
    static func numberedRow(header: String, number: String?) -> NumberedRow {
        guard let number, !number.isEmpty else { return NumberedRow(number: number, title: header) }
        let opening = header.drop(while: \.isWhitespace)
        guard opening.hasPrefix(number + ".") else { return NumberedRow(number: number, title: header) }
        let title = opening.dropFirst(number.count + 1).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return NumberedRow(number: number, title: header) }
        return NumberedRow(number: number, title: title)
    }

    /// The header with a leaked source-note tail removed.
    ///
    /// The leak has one shape: the title runs on into "Source: …" mid-string. The cut requires the
    /// marker to follow a space and to be followed by content, so a header that legitimately
    /// *begins* with "Source:" (front matter about sourcing) is left alone.
    ///
    /// - Parameter header: The indexed header.
    /// - Returns: The header up to the leaked note, whitespace-trimmed.
    static func trimmedHeader(_ header: String) -> String {
        guard let range = header.range(of: " Source: ") ?? header.range(of: "\u{00A0}Source: "),
              range.lowerBound != header.startIndex else {
            return header
        }
        return String(header[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
}
