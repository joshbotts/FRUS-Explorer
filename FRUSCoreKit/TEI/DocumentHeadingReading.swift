// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentHeadingReading

/// The one reading of a document's printed heading and dateline (L34; the Collections design §3.4):
/// the heading's words, the number the volume prints before them, the heading's footnote calls, and
/// the dateline's words and calls, each apart from the others.
///
/// Every place that quotes a heading reads it here: a collection's contents rows, the line *As
/// published:* opens, a citation record's title and its "Document date:" line (decisions 165 and
/// 198). Until L34 each read the heading whole, so a contents row read "4.  1. Letter From…" (#2002), a
/// record's title ended in "[1]" (#1992), an editorial note had no heading (#2003), and a dateline in an
/// opener or a closer was not read at all (#1994).
///
/// **The volume's own number is read by its form, in every volume** (J23). Measured over the 553
/// catalogue volumes on 2026-11-27 (314,616 documents), a heading opens with a number in one of two
/// forms: `N.` ("1. Letter From…") in 78,873 headings of 232 volumes, and `No. N` with or without its
/// stop ("No. 98.", "No. 75") in 17,659 headings of 49, all but one of them on a line of their own.
/// 6,061 of the second form are not the document's `@n`, the number history.state.gov cites, so
/// a citation names history.state.gov's number and the *As published:* line keeps the volume's
/// (decision 197). About 60 headings of `frus1872p2v1` and `frus1872p2v2` open with a page number in
/// brackets and an asterisk ("[238] *No. 2.—…"), which the rule leaves as words.
///
/// **Two sources.** Where the volume is on the device the reading is of its parse
/// (``init(documentNodes:)``), through an editorial note's wrapper the way the index reads it: the
/// heading always (`IndexingPipeline.extractHeader(from:)`), the dateline only where the note prints a
/// source note of its own (`IndexingPipeline.ownFieldNodes(of:)`, L26's rule, #1854). Where it is not,
/// the reading is of the index's two strings (``init(indexedHeader:indexedDateline:)``), which hold less:
/// no dateline that sits only in a closer, and a note inside a dateline run into its text.
///
/// Version history:
///   1.0 — L34 (#1992, #1994, #2002, #2003): initial implementation
public struct DocumentHeadingReading: Sendable, Equatable {

    /// The heading's words: what the volume prints, without the number before them and without its
    /// footnote calls. Empty for a document with no heading, or one whose heading is its number alone.
    public let words: String
    /// The number the volume prints before the words, as printed: "1.", "No. 98.", "No. 75". `nil` where it
    /// prints none.
    public let number: String?
    /// The labels of the numbered footnote calls in the heading, in order. A note the volume printed
    /// unnumbered has no call to read.
    public let calls: [String]
    /// The dateline's words, without its calls: the first dateline at the top level or in an opener,
    /// else the first in a closer. `nil` where the document prints none.
    public let dateline: String?
    /// The labels of the numbered footnote calls in the dateline, in order.
    public let datelineCalls: [String]

    /// Creates a reading from its parts.
    public init(words: String, number: String? = nil, calls: [String] = [], dateline: String? = nil,
                datelineCalls: [String] = []) {
        self.words = words
        self.number = number
        self.calls = calls
        self.dateline = dateline
        self.datelineCalls = datelineCalls
    }

    /// The heading as the volume prints it, without its calls: the number, then the words. What the
    /// line *As published:* opens quotes, since it keeps the volume's own number (decision 197).
    public var printedHeading: String {
        [number, words].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: Reading the parse

    /// Reads a document's parse: its nodes as `FRUSDocumentParser` gives them.
    ///
    /// - Parameter nodes: The document's nodes (`FRUSDocumentAST.nodes`).
    public init(documentNodes nodes: [FRUSASTNode]) {
        let heading = IndexingPipeline.extractHeader(from: nodes)
        let split = Self.splitNumber(heading)
        let datelineNode = Self.datelineNode(in: IndexingPipeline.ownFieldNodes(of: nodes))
        let datelineText = datelineNode.map { $0.printedText(excludingFootnotes: true).normalizedWhitespace }
        self.init(words: split.words, number: split.number,
                  calls: Self.headNode(in: nodes).map(Self.callLabels(in:)) ?? [],
                  dateline: datelineText.flatMap { $0.isEmpty ? nil : $0 },
                  datelineCalls: datelineNode.map(Self.callLabels(in:)) ?? [])
    }

    // MARK: Reading the index

    /// Reads the two strings the index stores for a document (`document_cache.header` and `dateline`):
    /// the heading with its notes left out, and the dateline with any note run into it.
    ///
    /// - Parameters:
    ///   - indexedHeader: The stored heading.
    ///   - indexedDateline: The stored dateline, if any.
    public init(indexedHeader: String, indexedDateline: String?) {
        let split = Self.splitNumber(indexedHeader.normalizedWhitespace)
        let dateline = indexedDateline?.normalizedWhitespace
        self.init(words: split.words, number: split.number,
                  dateline: dateline.flatMap { $0.isEmpty ? nil : $0 })
    }

    // MARK: The number by its form

    /// `No. N`, with a letter after it or not and its stop or not, before whitespace, a dash or the end:
    /// "No. 98.", "No. 75", "No. 194 a.", "No. 5525.—".
    private static let noForm = try? NSRegularExpression(pattern: #"^No\.\s*\d+(?:\s?[A-Za-z])?\.?(?=\s|[—–]|$)"#)

    /// `N.`, with a letter after the digits or not, before whitespace or the end: "1.", "373a.".
    private static let numberForm = try? NSRegularExpression(pattern: #"^\d+[A-Za-z]?\.(?=\s|$)"#)

    /// A heading's leading number, read by its form, and the words after it: "No. 98. Mr. Fish to
    /// Mr. Mathews." is "No. 98." and "Mr. Fish to Mr. Mathews."; a heading that opens with no number is
    /// all words. A dash between the number and the words ("No. 5525.—United States") goes with the number.
    ///
    /// - Parameter heading: The heading's text, its calls left out.
    /// - Returns: The number as printed, or `nil`, and the words.
    public static func splitNumber(_ heading: String) -> (number: String?, words: String) {
        let text = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(text.startIndex..., in: text)
        for form in [noForm, numberForm].compactMap({ $0 }) {
            guard let match = form.firstMatch(in: text, range: range),
                  let numberRange = Range(match.range, in: text) else { continue }
            let number = String(text[numberRange])
            var rest = text[numberRange.upperBound...].drop { $0.isWhitespace }
            if let first = rest.first, first == "—" || first == "–" {
                rest = rest.dropFirst().drop { $0.isWhitespace }
            }
            return (number, String(rest))
        }
        return (nil, text)
    }

    // MARK: The nodes read

    /// The first `<head>` among `nodes`, read through an editorial note's wrapper as
    /// `IndexingPipeline.extractHeader(from:)` reads it.
    private static func headNode(in nodes: [FRUSASTNode]) -> FRUSASTNode? {
        if case .editorialNote(let children)? = nodes.first { return headNode(in: children) }
        return nodes.first { if case .head = $0 { return true } else { return false } }
    }

    /// The document's dateline: the first at the top level or in an opener, in document order, else the
    /// first in a closer (#1994). Measured over the 553 catalogue volumes, a document's dateline is in an
    /// opener in 286,088 documents, at the top level in 14,881 and in a closer alone in 5,331.
    private static func datelineNode(in nodes: [FRUSASTNode]) -> FRUSASTNode? {
        func first(in nodes: [FRUSASTNode], enteringClosers: Bool) -> FRUSASTNode? {
            for node in nodes {
                switch node {
                case .dateline:
                    return node
                case .opener(let children):
                    if let found = first(in: children, enteringClosers: enteringClosers) { return found }
                case .closer(let children) where enteringClosers:
                    if let found = first(in: children, enteringClosers: true) { return found }
                default:
                    break
                }
            }
            return nil
        }
        return first(in: nodes, enteringClosers: false) ?? first(in: nodes, enteringClosers: true)
    }

    /// The printed labels of the numbered footnote calls inside `node`, in document order.
    private static func callLabels(in node: FRUSASTNode) -> [String] {
        var labels: [String] = []
        func walk(_ node: FRUSASTNode) {
            if case .footnote(_, _, let printedNumber, _) = node {
                if let label = ASTToRenderNodeConverter.printedLabel(from: printedNumber) { labels.append(label) }
                return
            }
            node.children.forEach(walk)
        }
        node.children.forEach(walk)
        return labels
    }
}
