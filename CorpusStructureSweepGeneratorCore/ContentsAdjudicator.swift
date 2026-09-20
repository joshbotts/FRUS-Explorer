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

/// Adjudicates a candidate against the volume's OWN printed table of contents.
///
/// This is the strongest thing the report can say — *the book itself disagrees with the file* — and
/// it is #1309's own evidence: Malta's contents lists 7., 8., 9., 10. and 11. as a flat run under
/// "III. THE YALTA CONFERENCE", while the file nests 9., 10. and 11. inside 8.
///
/// **Where the defects concentrate, this channel is blind, and the report must say so.** 481 of the
/// 553 shippable volumes carry a contents list with at least one item; the volumes holding most of
/// the structural violations are 1861–1902, and the per-decade join rate there is 0.0% (1860s),
/// 2.9% (1870s), 0.0% (1880s). A row this cannot adjudicate ships as a question, never as an
/// assertion.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
public enum ContentsAdjudicator {

    /// One printed contents entry: its text and how deep it sits in the printed list.
    public struct Entry: Sendable, Equatable {
        /// The item's own text, normalised for comparison.
        public let key: String
        /// Nesting depth inside the contents list, from zero.
        public let depth: Int
        /// The parent item's key, or `nil` at the top of the list.
        public let parentKey: String?
    }

    /// Reads the volume's contents list, or an empty array when it has none.
    ///
    /// The list lives in a `<div type="section" subtype="table-of-contents">` in front matter,
    /// as `<list type="toc">` with a nested `<item>` forest.
    public static func entries(in xml: String) -> [Entry] {
        guard let start = xml.range(of: "subtype=\"table-of-contents\"") else { return [] }
        guard let listStart = xml.range(of: "<list", range: start.upperBound..<xml.endIndex) else {
            return []
        }
        // The contents div ends at its own </div>; scanning to the first one after the list is
        // enough, because a contents list holds no divs.
        let end = xml.range(of: "</div>", range: listStart.upperBound..<xml.endIndex)?.lowerBound
            ?? xml.endIndex
        return parseItems(String(xml[listStart.lowerBound..<end]))
    }

    /// Parses the `<item>` forest, keeping each item's own text and its depth.
    static func parseItems(_ fragment: String) -> [Entry] {
        var entries: [Entry] = []
        var stack: [(key: String, depth: Int)] = []
        var depth = -1
        var buffer = ""
        var pendingKeys: [String?] = []
        var index = fragment.startIndex

        func flush() {
            guard depth >= 0 else { buffer = ""; return }
            let key = normalize(buffer)
            buffer = ""
            guard !key.isEmpty else { return }
            // The item's own text belongs to the item opened most recently at this depth.
            if let last = entries.indices.last, entries[last].key.isEmpty, entries[last].depth == depth {
                entries[last] = Entry(key: key, depth: depth, parentKey: entries[last].parentKey)
                stack.append((key, depth))
            }
        }

        while index < fragment.endIndex {
            guard let open = fragment[index...].firstIndex(of: "<") else {
                buffer += fragment[index...]
                break
            }
            buffer += fragment[index..<open]
            guard let close = fragment[open...].firstIndex(of: ">") else { break }
            let tag = String(fragment[open...close])
            let name = DivScanner.elementName(of: tag)
            if name == "item" {
                if tag.hasPrefix("</") {
                    flush()
                    while let top = stack.last, top.depth >= depth { stack.removeLast() }
                    depth -= 1
                    pendingKeys = pendingKeys.dropLast()
                } else if !tag.hasSuffix("/>") {
                    flush()
                    depth += 1
                    let parent = stack.last.map(\.key)
                    entries.append(Entry(key: "", depth: depth, parentKey: parent))
                    pendingKeys.append(parent)
                }
            }
            index = fragment.index(after: close)
        }
        return entries.filter { !$0.key.isEmpty }
    }

    /// Normalises a heading for comparison: decomposed, unaccented, case-folded, letters and
    /// digits only, with a trailing printed page number removed.
    ///
    /// The printed contents carries page numbers and small-caps markup that the body head does
    /// not, so a raw comparison joins nothing.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var kept = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            .map(Character.init)
        // A trailing run of digits is the printed page number, not part of the heading.
        while let last = kept.last, last.isNumber { kept.removeLast() }
        return String(kept)
    }

    /// Whether the printed contents CONTRADICTS the file: both heads appear, at the same printed
    /// depth, so the book makes them siblings while the file nests one inside the other.
    public static func contradicts(parentHead: String, childHead: String, entries: [Entry]) -> Bool {
        let parentKey = normalize(parentHead)
        let childKey = normalize(childHead)
        guard !parentKey.isEmpty, !childKey.isEmpty else { return false }
        let parentMatches = entries.filter { $0.key == parentKey }
        let childMatches = entries.filter { $0.key == childKey }
        // Uniqueness: a heading printed twice cannot adjudicate anything.
        guard parentMatches.count == 1, childMatches.count == 1 else { return false }
        return parentMatches[0].depth == childMatches[0].depth
    }
}
