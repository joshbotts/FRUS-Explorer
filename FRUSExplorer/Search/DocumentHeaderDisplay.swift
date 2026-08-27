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
/// Version history:
///   1.0 — UI review wave 1 (CW-2): initial implementation
///   1.1 — #888: charter corrected — extraction was already clean; this is the stale-index belt
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
