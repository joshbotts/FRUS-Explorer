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

/// Pulls each FRUS document's body text out of a TEI volume, mimicking what the app
/// indexes.
///
/// ## What it mimics, and how closely
/// The app tokenises `body_text` from FTS5, which `IndexingPipeline` fills with
/// `extractBodyText(from: astDoc.nodes)` — every top-level child of a
/// `<div type="document">`, rendered through `FRUSASTNode.plainText` and
/// whitespace-normalised. `plainText` **includes footnote subtrees** (there is a separate
/// `plainTextExcludingFootnotes`, used only for headers), so the faithful rule is simply:
/// *all character data inside the document div*. That is what this extracts.
///
/// It is a **deliberate approximation, not a reimplementation of the parser.** Matching the
/// AST byte for byte would mean lifting `FRUSDocumentParser` (2,243 lines) into SPM. The
/// residual differences are inter-node separators and entity edge cases, which change
/// whitespace rather than word boundaries — and word boundaries are all the tokenizer reads.
/// Where the two genuinely cannot agree is documented on `CloudVectorsAggregator`.
///
/// ## Why not XMLParser
/// `XMLParser` is DOM/SAX over the whole 3.3 GB corpus and rejects the corpus's undeclared
/// `frus:` namespace prefixes without extra configuration. This is a forward byte scan that
/// tracks depth from the opening `<div … type="document">` to its matching `</div>`,
/// skipping comments, CDATA, and processing instructions — the same technique
/// `CrossRefValidationGenerator` uses over the same corpus.
///
/// Version history:
///   1.0 — O-1: initial implementation
public enum TEIBodyTextExtractor {

    /// One document's identity and text.
    public struct Document: Sendable, Equatable {
        /// The `xml:id` of the document div (`"d1"`, `"d42"`), or a synthesised ordinal
        /// when the attribute is absent.
        public let documentId: String
        /// All character data inside the div, whitespace-normalised.
        public let bodyText: String

        /// Creates a document.
        public init(documentId: String, bodyText: String) {
            self.documentId = documentId
            self.bodyText = bodyText
        }
    }

    /// Extracts every `<div type="document">` body in `xml`, in document order.
    ///
    /// - Parameter xml: A whole TEI volume.
    /// - Returns: One entry per document div. Empty when the volume has none, which is
    ///   itself worth reporting — a volume that tokenises to nothing is a finding, not a
    ///   scope with a small cloud.
    public static func documents(in xml: String) -> [Document] {
        var results: [Document] = []
        let scalars = Array(xml.unicodeScalars)
        let count = scalars.count
        var i = 0
        var ordinal = 0

        while i < count {
            guard scalars[i] == "<" else { i += 1; continue }

            // Skip the three constructs whose contents are not markup, so a "<div" inside
            // a comment or CDATA can never open a phantom document.
            if let skipped = skipNonMarkup(scalars, from: i) { i = skipped; continue }

            guard let tagEnd = indexOfTagEnd(scalars, from: i) else { break }
            let tag = String(String.UnicodeScalarView(scalars[i...tagEnd]))

            if isDocumentDivOpen(tag) {
                ordinal += 1
                let id = attributeValue("xml:id", in: tag) ?? "d\(ordinal)"
                // Self-closing document divs carry no text; nothing to collect.
                if tag.hasSuffix("/>") {
                    results.append(Document(documentId: id, bodyText: ""))
                    i = tagEnd + 1
                    continue
                }
                let (text, next) = collectText(scalars, from: tagEnd + 1)
                results.append(Document(documentId: id, bodyText: text))
                i = next
                continue
            }
            i = tagEnd + 1
        }
        return results
    }

    // MARK: - Scanning

    /// If `i` opens a comment, CDATA section, or processing instruction, returns the index
    /// just past its terminator; otherwise `nil`.
    private static func skipNonMarkup(_ s: [Unicode.Scalar], from i: Int) -> Int? {
        if matches(s, at: i, "<!--")            { return indexPast(s, from: i + 4, terminator: "-->") }
        if matches(s, at: i, "<![CDATA[")       { return indexPast(s, from: i + 9, terminator: "]]>") }
        if matches(s, at: i, "<?")              { return indexPast(s, from: i + 2, terminator: "?>") }
        return nil
    }

    /// Collects character data from `start` until the `</div>` matching the already-open
    /// document div, tracking nested `<div>`s.
    ///
    /// - Returns: The whitespace-normalised text, and the index just past the closing tag.
    private static func collectText(_ s: [Unicode.Scalar], from start: Int) -> (String, Int) {
        var text = String.UnicodeScalarView()
        var depth = 1
        var i = start

        while i < s.count {
            if s[i] == "<" {
                if let skipped = skipNonMarkup(s, from: i) { i = skipped; continue }
                guard let tagEnd = indexOfTagEnd(s, from: i) else { break }
                let tag = String(String.UnicodeScalarView(s[i...tagEnd]))
                if isDivOpen(tag) && !tag.hasSuffix("/>") {
                    depth += 1
                } else if isDivClose(tag) {
                    depth -= 1
                    if depth == 0 { return (normalize(String(text)), tagEnd + 1) }
                }
                // A tag boundary is a word boundary: "<hi>treaty</hi>signed" must not
                // tokenise as one word.
                text.append(" ")
                i = tagEnd + 1
                continue
            }
            text.append(s[i])
            i += 1
        }
        return (normalize(String(text)), s.count)
    }

    /// Index of the `>` closing the tag that starts at `i`, honouring quoted attribute
    /// values so a `>` inside one does not end the tag early.
    private static func indexOfTagEnd(_ s: [Unicode.Scalar], from i: Int) -> Int? {
        var j = i + 1
        var quote: Unicode.Scalar?
        while j < s.count {
            let c = s[j]
            if let q = quote {
                if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
            } else if c == ">" {
                return j
            }
            j += 1
        }
        return nil
    }

    private static func indexPast(_ s: [Unicode.Scalar], from i: Int, terminator: String) -> Int {
        let t = Array(terminator.unicodeScalars)
        var j = i
        while j + t.count <= s.count {
            if Array(s[j..<(j + t.count)]) == t { return j + t.count }
            j += 1
        }
        return s.count
    }

    private static func matches(_ s: [Unicode.Scalar], at i: Int, _ literal: String) -> Bool {
        let l = Array(literal.unicodeScalars)
        guard i + l.count <= s.count else { return false }
        return Array(s[i..<(i + l.count)]) == l
    }

    // MARK: - Tag predicates

    private static func isDivOpen(_ tag: String) -> Bool {
        tag.hasPrefix("<div") && (tag.count == 5 || isTagNameBoundary(tag, after: 4))
    }

    private static func isDivClose(_ tag: String) -> Bool {
        let squashed = tag.dropFirst(2).drop { $0 == " " }
        return tag.hasPrefix("</") && squashed.hasPrefix("div")
    }

    /// A `<div>` opener carrying `type="document"`.
    ///
    /// Attribute order varies across the corpus (`type` often follows `frus:doc-dateTime-*`),
    /// so this checks for the attribute rather than a prefix.
    private static func isDocumentDivOpen(_ tag: String) -> Bool {
        isDivOpen(tag) && attributeValue("type", in: tag) == "document"
    }

    private static func isTagNameBoundary(_ tag: String, after index: Int) -> Bool {
        let idx = tag.index(tag.startIndex, offsetBy: index)
        guard idx < tag.endIndex else { return false }
        let c = tag[idx]
        return c == " " || c == "\t" || c == "\n" || c == "\r" || c == ">" || c == "/"
    }

    /// The value of `name` in `tag`, or `nil`.
    ///
    /// Matches on a whole attribute name, so `type` does not match `subtype` — the corpus
    /// carries `subtype="editorial-note"` on many document divs, and a prefix match would
    /// read it as the type.
    static func attributeValue(_ name: String, in tag: String) -> String? {
        var search = tag[tag.startIndex...]
        while let r = search.range(of: name) {
            let before = r.lowerBound == tag.startIndex ? " " : tag[tag.index(before: r.lowerBound)]
            let isWholeName = before == " " || before == "\t" || before == "\n" || before == "\r"
            var after = r.upperBound
            while after < search.endIndex, search[after] == " " { after = search.index(after: after) }
            if isWholeName, after < search.endIndex, search[after] == "=" {
                var v = search.index(after: after)
                while v < search.endIndex, search[v] == " " { v = search.index(after: v) }
                guard v < search.endIndex, search[v] == "\"" || search[v] == "'" else { return nil }
                let quote = search[v]
                let valueStart = search.index(after: v)
                guard let end = search[valueStart...].firstIndex(of: quote) else { return nil }
                return String(search[valueStart..<end])
            }
            search = search[r.upperBound...]
        }
        return nil
    }

    // MARK: - Text

    /// Decodes the five predefined XML entities plus numeric references, and collapses
    /// whitespace runs to single spaces — matching `String.normalizedWhitespace`, which is
    /// what `extractBodyText` applies.
    static func normalize(_ raw: String) -> String {
        var s = raw
        if s.contains("&") { s = decodeEntities(s) }
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func decodeEntities(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var rest = s[s.startIndex...]
        while let amp = rest.firstIndex(of: "&") {
            out += rest[rest.startIndex..<amp]
            let tail = rest[amp...]
            guard let semi = tail.firstIndex(of: ";"),
                  tail.distance(from: amp, to: semi) <= 10 else {
                out.append("&")
                rest = rest[rest.index(after: amp)...]
                continue
            }
            let entity = String(tail[tail.index(after: amp)..<semi])
            switch entity {
            case "amp":  out.append("&")
            case "lt":   out.append("<")
            case "gt":   out.append(">")
            case "quot": out.append("\"")
            case "apos": out.append("'")
            default:
                if entity.hasPrefix("#"),
                   let scalar = numericScalar(entity.dropFirst()) {
                    out.unicodeScalars.append(scalar)
                } else {
                    // Unknown entity: keep it as a space so it cannot glue two words
                    // together into a token that exists in neither.
                    out.append(" ")
                }
            }
            rest = tail[tail.index(after: semi)...]
        }
        out += rest
        return out
    }

    private static func numericScalar(_ digits: Substring) -> Unicode.Scalar? {
        let value: UInt32?
        if digits.hasPrefix("x") || digits.hasPrefix("X") {
            value = UInt32(digits.dropFirst(), radix: 16)
        } else {
            value = UInt32(digits, radix: 10)
        }
        guard let value else { return nil }
        return Unicode.Scalar(value)
    }
}
