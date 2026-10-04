// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// Moved verbatim from `IndexingPipeline.swift` (FRUSCoreKit, part 1): the index and the reader
// share this walk, and the reader's half now compiles in FRUSCoreKit, which cannot see the index.

// MARK: - FRUSASTNode Extensions

extension FRUSASTNode {
    /// All plain text content of this node and its descendants, joined the way the page prints it
    /// (#1421): ``printedText(excludingFootnotes:)`` with every note kept.
    ///
    /// Every string the index joins from a document's nodes is built by the same walk, ``PrintedText`` —
    /// through this property or ``printedText(of:excludingFootnotes:)``: `body_text`, each body
    /// footnote's text, the source note, a cross-reference's context, the title and the dateline,
    /// the despatch serial and an enclosure's head and label — and so are the summariser's input
    /// and the reader's source note. It used to join every child with a space,
    /// which invented one inside brackets and quotes and before a stop ("( Kennan )", "“ NSC Record
    /// of Actions”", "Moscow , January 20, 1961 ."): measured over the 553 manifest volumes, in
    /// 313,949 of 316,930 bodies, 46,049 of 264,575 source notes and 213,847 of 469,250 body
    /// footnotes.
    var plainText: String { printedText(excludingFootnotes: false) }

    /// The node's text as the page prints it (#1375, #1421).
    ///
    /// Runs inside a block join by ``joinPrinted(_:)``'s rule; a block's edge keeps its space, as
    /// ``PrintedText`` explains. Titles (`IndexingPipeline.extractHeader`) and datelines
    /// (`extractDateline`) came first, in #1375; #1421 made it the rule for every stored string, and
    /// measured that the block rule moves none of #1375's titles or datelines.
    ///
    /// - Parameter excludingFootnotes: when `true`, every `.footnote` subtree is dropped at any
    ///   depth, not just among direct children — the title's rule, because 1955+ volumes nest the
    ///   source note inside `<head>` and 68 documents nest a footnote inside `<hi>`/`<persName>`/`<p>`
    ///   within it. The dateline keeps its notes, as it always has.
    func printedText(excludingFootnotes: Bool) -> String {
        var text = PrintedText()
        text.append(self, excludingFootnotes: excludingFootnotes)
        return text.string
    }

    /// The printed text of a run of sibling nodes (#1421) — what every stored-text site in
    /// `IndexingPipeline` builds its string from, in place of joining each child's `plainText`
    /// with a space.
    ///
    /// - Parameters:
    ///   - nodes: The siblings, in document order.
    ///   - excludingFootnotes: As ``printedText(excludingFootnotes:)``.
    static func printedText(of nodes: [FRUSASTNode], excludingFootnotes: Bool = false) -> String {
        var text = PrintedText()
        for node in nodes { text.append(node, excludingFootnotes: excludingFootnotes) }
        return text.string
    }

    /// Joins sibling text runs the way the printed line reads (#1375).
    ///
    /// **Why not a space, and why not nothing.** The parser keeps a single space at a text/element
    /// boundary wherever the XML had whitespace there, and discards whitespace-only runs
    /// (`FRUSDocumentParser.normalizedText`). A space separator is therefore redundant wherever the
    /// XML had one and *invents* one wherever it had none — which is how the corpus writes a name in
    /// parentheses (`(<persName>Kennan</persName>)`) and a closing stop (`…Adams</persName></hi>.`).
    /// Joining with nothing fails the other way: a pretty-printed head puts each phrase in its own
    /// element with only whitespace-only runs between them (`frus1915Supp` d1120), and those runs
    /// are gone, so a plain concatenation reads "TheLake Torpedo Boat Companyto the…".
    ///
    /// The rule, applied between the text so far and the next non-empty piece:
    /// - concatenate when either side already carries a boundary space;
    /// - concatenate after an opening bracket or quote: `( [ { “ ‘`;
    /// - concatenate before closing punctuation: `) ] } . , ; : ! ? ” ’`;
    /// - otherwise insert one space.
    ///
    /// These are the sets the issue measured. Over the whole corpus they leave 727 titles and
    /// 4,903 datelines differing from the parser's normalisation of the XML — ordinals split by
    /// markup ("11 th"), dash compounds, drop caps — every one of which the old join spaced the
    /// same way. They are deliberately not widened to the ambiguous ASCII quote and apostrophe,
    /// which open as often as they close, nor to dashes — so #1421's own example, the two glosses
    /// of `S/S–NSC`, keeps its spaces. Callers normalise whitespace afterwards.
    ///
    /// Strings only: the node walk that also keeps a space at block edges is ``PrintedText``.
    static func joinPrinted(_ pieces: [String]) -> String {
        var text = PrintedText()
        for piece in pieces { text.append(piece) }
        return text.string
    }

    /// Whether the page sets this node apart from its neighbours (#1421).
    ///
    /// The render converter's block set — the nodes `ASTToRenderNodeConverter`'s `isBlockNode`
    /// names, and the table cells and list items `buildFlatTextBlocks` splits on — plus the
    /// footnote, whose text the index inlines at its mark while the reader sets it apart. Inline
    /// markup is not: `hi`, `persName`, `gloss`, `ref`, `date`, `term`, the editorial marks, and
    /// every element the parser keeps as `.unknown`, because the reader draws each inside a line.
    /// The switch is exhaustive on purpose, so a new node kind has to be classified.
    var isPrintedBlock: Bool {
        switch self {
        case .head, .dateline, .opener, .closer, .salute, .paragraph, .footnote,
             .table, .tableRow, .tableCell, .list, .listItem,
             .editorialNote, .titlePage, .figure, .attachment:
            return true
        case .document, .date, .persName, .gloss, .crossReference, .emphasis, .term, .text,
             .pageBreak, .supplied, .sic, .corr, .formula, .lineBreak, .elementSpace, .unknown:
            return false
        }
    }

    /// Direct and indirect child nodes (used for recursive cross-reference and page-range extraction).
    var children: [FRUSASTNode] {
        switch self {
        case .text, .formula, .lineBreak, .pageBreak, .elementSpace: return []
        case .document(_, _, let c): return c
        case .head(let c), .dateline(let c), .paragraph(let c),
             .opener(let c), .closer(let c), .salute(let c),
             .term(let c), .editorialNote(let c), .titlePage(let c),
             .supplied(let c), .sic(let c), .corr(let c):
            return c
        case .attachment(_, let c): return c
        case .date(_, _, _, _, _, let c): return c
        case .emphasis(_, let c): return c
        case .persName(_, let c): return c
        case .gloss(_, let c):    return c
        case .crossReference(_, _, let c): return c
        case .figure(_, let c):   return c
        case .footnote(_, _, _, let c): return c
        case .table(let rows):    return rows
        case .tableRow(let cells): return cells
        case .tableCell(_, _, let c): return c
        case .list(_, let items): return items
        case .listItem(let c):    return c
        case .unknown(_, _, let c): return c
        }
    }
}

// MARK: - PrintedText (#1375, #1421)

/// Accumulates a node's text the way the page prints it — the one join every stored string uses.
///
/// Inside a block, runs join by the printed rule (``FRUSASTNode/joinPrinted(_:)``). **A block's
/// edge keeps its space**, because the page breaks the line there. Joined blind to blocks, the
/// printed rule glues a paragraph that opens with a stop to the one before it (`frus1865p1` d339,
/// "without.. But"), a ditto mark to the next cell (`frus1863p2` d611, "“202") and a footnote to
/// the bracket before it (`frus1873p2v3` d29): measured over the corpus, 6,935 documents would
/// have been glued that way.
///
/// **The one exception is a footnote's closing edge.** A footnote interrupts a line rather than
/// ending one, so the text after it resumes by the printed rule: `(Aisoo<note>…</note>) and Todo`
/// stores "…commander-in-chief of Kioto.) and Todo" (`frus1864p3` d499). It is also what keeps a
/// dateline that carries a note exactly as #1375 stored it — with the exception, the block rule
/// moves no stored title and no stored dateline (without it, 1,069 datelines).
///
/// **The exception does not reach past a block the note ends in.** The footnote marks no edge of
/// its own when it closes, but a `<p>`, list or table that is its last child marks ITS closing
/// edge, and that edge is still pending when the text after the note arrives — so the text is
/// spaced: `submitted.</p></note>; whereas` stores "submitted. ; whereas" (`frus1881` d159 fn2).
/// Measured over the 553 manifest volumes (#1421 review): 161 notes that end in a block are
/// followed directly by a closing mark, in 65 volumes. Those strings are the old ones unchanged —
/// the old join spaced them too — and the generator mirror stores them the same way. Clearing the
/// pending edge when a note closes would glue them, and would need the title and dateline
/// measurement redone, so it has not been done.
///
/// Every output is the old space-joined text with zero or more spaces removed: each edge either
/// keeps the space the old join put there or loses it, and nothing else changes.
///
/// Version history:
///   1.0 — #1421: initial implementation, from #1375's `joinPrinted`
///   1.1 — #1421 review: documents that the footnote exception stops at a block the note ends in
///   1.2 — FRUSCoreKit, part 1: moved, unchanged, from `IndexingPipeline.swift` to
///          `FRUSCoreKit/TEI/FRUSASTNode+PrintedText.swift`, with the `FRUSASTNode` members it
///          backs, which the reader's converter and the page-span resolver call too
struct PrintedText {

    /// The text so far. Callers normalise whitespace.
    private(set) var string = ""

    /// A block edge lies between the last run and the next one.
    private var pendingBlockEdge = false

    /// Characters after which the next run follows with no space: opening brackets and curly quotes.
    static let openers: Set<Character> = ["(", "[", "{", "\u{201C}", "\u{2018}"]

    /// Characters before which the previous run ends with no space: closing brackets, curly quotes
    /// and the punctuation that closes a phrase or sentence.
    static let closers: Set<Character> = [
        ")", "]", "}", ".", ",", ";", ":", "!", "?", "\u{201D}", "\u{2019}",
    ]

    /// Appends `node`'s text, marking its edges when it is a block.
    mutating func append(_ node: FRUSASTNode, excludingFootnotes: Bool) {
        switch node {
        case .text(let s), .formula(let s):
            append(s)
        case .lineBreak:
            append(" ")
        case .pageBreak, .document, .elementSpace:
            // `.elementSpace` (#1516 fold-in) is no text: the seam it marks was always spaced by
            // the printed rule below, and appending a space for it would add one after an opening
            // bracket or before a stop, where the rule leaves none — moving stored text.
            return
        case .footnote where excludingFootnotes:
            return
        case .footnote:
            // Its opening edge sets it apart; its closing edge does not, though a block it ends in
            // still marks its own (see the type's doc).
            markBlockEdge()
            for child in node.children { append(child, excludingFootnotes: excludingFootnotes) }
        default:
            let isBlock = node.isPrintedBlock
            if isBlock { markBlockEdge() }
            for child in node.children { append(child, excludingFootnotes: excludingFootnotes) }
            if isBlock { markBlockEdge() }
        }
    }

    /// Appends one run of text by the printed rule.
    mutating func append(_ piece: String) {
        guard let first = piece.first else { return }
        guard let last = string.last else {
            string = piece
            return
        }
        if last.isWhitespace || first.isWhitespace {
            string += piece
        } else if pendingBlockEdge || !(Self.openers.contains(last) || Self.closers.contains(first)) {
            string += " " + piece
        } else {
            string += piece
        }
        pendingBlockEdge = false
    }

    /// Records a block edge. One before any text changes nothing, so it is not kept.
    private mutating func markBlockEdge() {
        if !string.isEmpty { pendingBlockEdge = true }
    }
}

// MARK: - String helper

extension String {
    /// The string with every run of whitespace collapsed to one space, and none at either end.
    var normalizedWhitespace: String {
        split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Source-note wrapper

/// The `[Source: …]` wrapper rule the index stores a source note by and the reader prints it by.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `IndexingPipeline.normalizeSourceNoteWrapper`, which
///          now forwards here
enum StoredSourceNote {
    /// Collapses the `[Source: …]` bracket wrapper (used for withheld-document
    /// provenance notes) to the unbracketed `Source: …` shape, so both TEI encodings
    /// store one consistent form. Text not wrapped in brackets is returned unchanged —
    /// in particular the bare pre-1955 decimal-file notes (`711.00/11–552`) and plain
    /// `Source: …` narratives keep their stored shape exactly.
    nonisolated static func normalizeWrapper(_ text: String) -> String {
        guard text.hasPrefix("[Source:"), text.hasSuffix("]") else { return text }
        let inner = text.dropFirst("[".count).dropLast("]".count)
        return String(inner).normalizedWhitespace
    }
}
