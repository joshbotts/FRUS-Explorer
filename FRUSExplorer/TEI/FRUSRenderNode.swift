// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Render Node

/// Layer 2 output: a rendering instruction that maps directly to a SwiftUI view or text run.
///
/// `FRUSRenderNode` is the output of `ASTToRenderNodeConverter`, which converts a
/// `FRUSDocumentAST` (Layer 1) into rendering instructions (Layer 2). The SwiftUI
/// renderer (`FRUSDocumentRenderer`, Layer 3) consumes these nodes to build the view.
///
/// ## Block vs Inline
/// Block nodes map to `VStack` children — each renders on its own visual line.
/// Inline nodes contribute to a text run within a block.
///
/// ## Footnotes
/// `footnoteMarker` appears inline at the reference point in the body text.
/// `footnoteBody` is collected by `FRUSDocumentRenderModel` for bottom-of-document rendering.
/// The converter assigns sequential numbers during the single conversion pass.
///
/// Version history:
///   1.0 — Session 06: initial implementation (core elements)
///   1.1 — Session 07: full element coverage (page breaks, tables, lists, editorial notes, etc.)
///   1.x — Session 42: `.footnoteBody` and `.footnoteMarker` gain `displayLabel: String` and `printedNumber: String?`
///   1.2 — Session 78: `.attachmentBlock` and `.attachmentHeading` added for `<frus:attachment>` rendering
///   1.3 — Session 79: `.titlePageBlock` added for `<titlePage>` centred rendering
///   1.4 — #985: `displayLabel` becomes `String?` on both footnote cases — a note the volume
///          printed without a number no longer gets one invented. `.footnoteMarker` gains `type`
///          (to pick an affordance for the `nil` case) and `sequentialNumber` (so it can derive
///          the same DOM key as its body via `footnoteDOMKey`, the pairing having previously
///          rested on a shared label that was neither unique nor well-formed).
public indirect enum FRUSRenderNode: Sendable {

    // MARK: Block Elements

    /// Document heading (`<head>`). Rendered with prominent typography.
    case heading([FRUSRenderNode])

    /// Date and location line (`<dateline>`). Rendered with secondary typography.
    case dateline([FRUSRenderNode])

    /// Opening block of a letter or memo (`<opener>`).
    case letterOpener([FRUSRenderNode])

    /// Closing block of a letter or memo (`<closer>`).
    case letterCloser([FRUSRenderNode])

    /// Salutation line within opener or closer (`<salute>`).
    case salutation([FRUSRenderNode])

    /// Paragraph (`<p>`).
    case paragraph([FRUSRenderNode])

    /// Footnote body, rendered in the footnote section at the bottom of the document.
    /// `printedNumber` is the raw TEI `@n` value (nil for notes without `@n`).
    /// `sequentialNumber` is the 1-based counter assigned by the converter.
    /// `displayLabel` is the number **as printed in the volume**, or `nil` when the note carries
    /// none. It is never synthesised — see the `#985` note on `footnoteMarker`.
    case footnoteBody(id: String?, type: FootnoteType, printedNumber: String?, sequentialNumber: Int, displayLabel: String?, children: [FRUSRenderNode])

    // MARK: Inline Elements

    /// Plain character data.
    case plainText(String)

    /// Bold text (`<hi rend="bold">`).
    case boldText([FRUSRenderNode])

    /// Italic text (`<hi rend="italic">`).
    case italicText([FRUSRenderNode])

    /// Small-caps text (`<hi rend="smallcaps">`).
    case smallCapsText([FRUSRenderNode])

    /// Underlined text (`<hi rend="underline">`).
    case underlineText([FRUSRenderNode])

    /// Technical term (`<term>`). Rendered with subtle visual distinction.
    case termText([FRUSRenderNode])

    // MARK: Footnote Marker

    /// Inline superscript footnote reference number.
    ///
    /// `displayLabel` matches the corresponding `footnoteBody.displayLabel`, and is `nil` for a
    /// note the volume printed without a number — chiefly the unnumbered source note, which is
    /// 193,500 of the corpus's 196,040 id-less notes. Before #985 this was a non-optional
    /// `printedNumber ?? "\(sequentialNumber)"`, which handed the source note the label "1" and
    /// collided with the real footnote 1 in 51,368 documents.
    ///
    /// `type` rides along solely so a renderer can pick an affordance for the `nil` case: a
    /// `.source` note is this document's provenance and earns the archival mark, while the ~73
    /// other unnumbered notes in the corpus must not, since an archival glyph on them would
    /// assert a provenance they do not carry.
    ///
    /// `sequentialNumber` is NOT for display. It exists so the marker can derive the same DOM key
    /// as its body through ``footnoteDOMKey(id:sequentialNumber:)`` — the two must agree or the
    /// popover does not open, and they no longer share a label to agree on.
    case footnoteMarker(id: String?, type: FootnoteType, sequentialNumber: Int, displayLabel: String?)

    // MARK: Interactive Elements

    /// A personal name link (`<persName>`).
    /// `person` is non-nil when the volume's List of Persons has been parsed (Session 07+).
    case persNameLink(ref: String?, children: [FRUSRenderNode], person: PersonEntry?)

    /// A glossary term link (`<gloss>`).
    /// `entry` is non-nil when the volume's Terms list has been parsed (Session 07+).
    case glossLink(ref: String?, children: [FRUSRenderNode], entry: GlossEntry?)

    /// A cross-reference link (`<ref>`).
    /// `broken` is non-nil when the corpus validation dataset (issue #240) flags this target as
    /// unresolvable; the serializer then renders a non-navigable explained span instead of a link,
    /// and the payload drives the reading view's explanation sheet. `nil` = a live link.
    case crossRefLink(target: String, volumeId: String?, broken: BrokenRefInfo?, children: [FRUSRenderNode])

    // MARK: Page Breaks (Session 07)

    /// Page break marker. Not visually rendered; retained for Session 30 citation lookup.
    case pageBreak(pageNumber: PageNumber)

    // MARK: Tables (Session 07)

    /// A rendered table. Each outer array element is a row; each inner element is a cell.
    case tableBlock(rows: [[TableCell]])

    // MARK: Lists (Session 07)

    /// A rendered list. `type` is the raw `@type` attribute value (e.g. `"ordered"`).
    case listBlock(type: String?, items: [[FRUSRenderNode]])

    // MARK: Structural Blocks (Session 07)

    /// An editorial note block, rendered with a visual distinction from body text.
    case editorialNoteBlock([FRUSRenderNode])

    /// A figure placeholder, rendered with an alt-text caption.
    case figureBlock(altText: String?)

    // MARK: Inline Editorial Marks (Session 07)

    /// Supplied text (`<supplied>`), rendered in square brackets.
    case suppliedText([FRUSRenderNode])

    /// Source error (`<sic>`), rendered with strikethrough.
    case sicText([FRUSRenderNode])

    /// Editorial correction (`<corr>`), rendered normally.
    case corrText([FRUSRenderNode])

    /// Formula text, rendered verbatim in an italic fixed-width style.
    case formulaText(String)

    /// Line break within flowing text.
    case lineBreak

    // MARK: Title Page (Session 79)

    /// A `<titlePage>` block from front-matter volumes.
    ///
    /// Rendered as a centred `VStack` with generous vertical padding, matching the
    /// website's centred title-page layout. Children are typically `.unknown` nodes
    /// for `<docTitle>`, `<docAuthor>`, `<docImprint>` etc.; each renders its own
    /// inline text content through the standard `.unknown` path.
    case titlePageBlock([FRUSRenderNode])

    // MARK: Attachments (Session 78)

    /// A `<frus:attachment>` sub-document block.
    ///
    /// Rendered with a prominent top separator (`Divider` + top padding matching
    /// the website's `.attachment { margin-top: 4em }`) and with any `.attachmentHeading`
    /// children styled at a secondary heading level (smaller, distinct from the main
    /// document heading). `n` carries the `@n` attribute if present.
    case attachmentBlock(n: String?, children: [FRUSRenderNode])

    /// The `<head>` inside a `<frus:attachment>`, rendered at a secondary heading level.
    ///
    /// Distinct from `.heading` (main document heading). Matches the website's
    /// `tei-head6` CSS class: smaller font, no size boost above body text.
    case attachmentHeading([FRUSRenderNode])

    // MARK: Passthrough / Unknown

    /// Preserves unrecognised elements for forward compatibility.
    /// Children are rendered as their own nodes.
    case unknown(name: String, children: [FRUSRenderNode])
}

// MARK: - Footnote DOM key (#985)

public extension FRUSRenderNode {

    /// The stable per-document key identifying one footnote in rendered output.
    ///
    /// Every renderer that pairs a marker with its body MUST derive both sides from this one
    /// function. Before #985 the pairing key was the *display label*, which is neither unique nor
    /// well-formed: an unnumbered source note was labelled `"1"` alongside the real footnote 1
    /// (51,368 documents), and because `@n` is copied verbatim from the TEI the corpus also
    /// produced `id="fn-*"` (3,854 notes), `id="fn-†"` (944), `id="fn- 1"` — a literal space
    /// inside an HTML id — and `id="fn-"` from an empty `@n`.
    ///
    /// The TEI `xml:id` is the right key and is measurably clean: **unique within a volume across
    /// every element type in all 552 shippable volumes**, and matching `^[A-Za-z][A-Za-z0-9_-]*$`
    /// in 574,903 of 574,904 occurrences (the exception is `d89fnǁ` in `frus1919Parisv06`, valid
    /// as both an HTML id and a CSS ident).
    ///
    /// But it is absent exactly where it is most needed: **196,040 in-document notes carry no
    /// `xml:id` (25.4%), and 193,500 of those are the unnumbered source notes**. Having `@n` and
    /// having `xml:id` is very nearly the same property — 574,901 notes have both and 195,518 have
    /// neither — so the note stripped of its label by #985 is, 99.9% of the time, the note that
    /// cannot be keyed by `xml:id`. The synthesised branch is the main path, not an edge case.
    ///
    /// The two branches are made disjoint **structurally**, by a discriminator that precedes any
    /// corpus-supplied text, rather than by the observation that no `xml:id` currently begins with
    /// `n-`. The Office of the Historian re-mints these ids between drops; a guarantee that rests
    /// on today's values is not a guarantee.
    ///
    /// - Parameters:
    ///   - id: the note's TEI `xml:id`, or `nil`.
    ///   - sequentialNumber: the converter's 1-based per-document counter.
    /// - Returns: a key unique within one converted document.
    static func footnoteDOMKey(id: String?, sequentialNumber: Int) -> String {
        // Whitespace is the one character class that is invalid in an HTML id and would silently
        // truncate the attribute. Measured at 0 occurrences in note xml:ids today; a future drop
        // that introduced one would fall back to the synthesised key rather than emit broken HTML.
        if let id, !id.isEmpty, !id.contains(where: \.isWhitespace) {
            return "x-\(id)"
        }
        return "n-\(sequentialNumber)"
    }
}

// MARK: - Table Cell

/// A single cell within a `tableBlock` row.
///
/// `rowSpan` and `colSpan` preserve the TEI `@rows` / `@cols` spanning attributes
/// for Session 07's functional table rendering and future precise layout.
///
/// Version history:
///   1.0 — Session 07: initial implementation
public struct TableCell: Sendable {
    public let rowSpan: Int
    public let colSpan: Int
    public let children: [FRUSRenderNode]

    public init(rowSpan: Int = 1, colSpan: Int = 1, children: [FRUSRenderNode]) {
        self.rowSpan = rowSpan
        self.colSpan = colSpan
        self.children = children
    }
}

// MARK: - Document Render Model

/// The fully converted render model for a single FRUS document.
///
/// Produced by `ASTToRenderNodeConverter.convert(_:)`. Consumed by `FRUSDocumentWebView`.
///
/// The `footnotes` array is separated from `bodyNodes` so the renderer can place footnote
/// bodies at the bottom of the document independent of where the markers appear in the body.
///
/// Version history:
///   1.0 — Session 06: initial implementation
public struct FRUSDocumentRenderModel: Sendable {
    /// The document identifier from `FRUSDocumentAST`.
    public let documentId: String

    /// The main document content in order of appearance.
    /// `footnoteMarker` nodes within this list pair with entries in `footnotes` through
    /// ``FRUSRenderNode/footnoteDOMKey(id:sequentialNumber:)`` — not by displayed number, which
    /// is neither unique nor always present (#985).
    public let bodyNodes: [FRUSRenderNode]

    /// Footnote bodies in sequential display order (1-based numbering).
    public let footnotes: [FRUSRenderNode]
}

// MARK: - Flat-text extraction

/// Builds the flat-text string from `model.bodyNodes` using the deterministic DFS
/// defined in `Planning/Completed/102-DocumentHighlight-Architecture.md §1`.
///
/// Only `.plainText`, `.formulaText`, and `.lineBreak` leaf nodes contribute
/// characters. All container nodes recurse in array order. `.pageBreak`,
/// `.footnoteMarker`, and `.figureBlock` are skipped. This matches the character
/// positions stored in `DocumentHighlight.startOffset`/`endOffset`, and exactly
/// mirrors the `window.FRUSOffsets.flatText` produced by `frus-offset-engine.js`.
///
/// Used by `FRUSOffsetEngineTests` (equivalence tests), `DocumentView`, and
/// `MacDocumentView` when creating highlights from WebKit selections.
///
/// Version history:
///   1.0 — Session 143: initial implementation in `DocumentHighlightTextView.swift`
///   1.1 — Session 147: moved here after `DocumentHighlightTextView.swift` deleted
public func buildFlatText(from model: FRUSDocumentRenderModel) -> String {
    var flat = ""
    appendFlatText(from: model.bodyNodes, into: &flat)
    return flat
}

/// Builds the flat-text string of an arbitrary render-node list using the same
/// deterministic DFS as `buildFlatText(from:)`. Used by the HTML serializer to
/// recover a source footnote's plain text for the classification chip
/// (Source Explorer Phase 5) without duplicating the traversal.
func flatText(of nodes: [FRUSRenderNode]) -> String {
    var flat = ""
    appendFlatText(from: nodes, into: &flat)
    return flat
}

private func appendFlatText(from nodes: [FRUSRenderNode], into flat: inout String) {
    for node in nodes {
        switch node {
        case .plainText(let s), .formulaText(let s):
            flat += s
        case .lineBreak:
            flat += "\n"
        case .tableBlock(let rows):
            for row in rows {
                for cell in row { appendFlatText(from: cell.children, into: &flat) }
            }
        case .listBlock(_, let items):
            for item in items { appendFlatText(from: item, into: &flat) }
        case .heading(let cs), .dateline(let cs), .letterOpener(let cs),
             .letterCloser(let cs), .salutation(let cs), .paragraph(let cs),
             .boldText(let cs), .italicText(let cs), .smallCapsText(let cs),
             .underlineText(let cs), .termText(let cs), .suppliedText(let cs),
             .sicText(let cs), .corrText(let cs), .editorialNoteBlock(let cs),
             .titlePageBlock(let cs), .attachmentHeading(let cs):
            appendFlatText(from: cs, into: &flat)
        case .persNameLink(_, let cs, _):
            appendFlatText(from: cs, into: &flat)
        case .glossLink(_, let cs, _):
            appendFlatText(from: cs, into: &flat)
        case .crossRefLink(_, _, _, let cs):
            appendFlatText(from: cs, into: &flat)
        case .attachmentBlock(_, let cs), .unknown(_, let cs):
            appendFlatText(from: cs, into: &flat)
        case .footnoteBody(_, _, _, _, _, let cs):
            appendFlatText(from: cs, into: &flat)
        default:
            // .pageBreak, .footnoteMarker, .figureBlock — contribute no characters
            break
        }
    }
}

// MARK: - Block-aware flat-text extraction (Authoring Phase 5)

/// Partitions the flat text into block-level segments whose concatenation is exactly
/// `buildFlatText(from:)` — the same DFS, so flat-text offsets index into the joined
/// blocks unchanged. Block boundaries follow the HTML serializer's block elements
/// (`paragraph`, `heading`, `dateline`, opener/closer, salutation, editorial notes,
/// title pages, attachments, footnote bodies, plus each table cell and list item);
/// inline containers (`bold`/`italic`/links/`unknown` spans, …) never split a block.
///
/// The flat text itself has **no separator between blocks** (adjacent paragraphs are
/// fused), which is fine for offset arithmetic but corrupts any string extracted
/// across a block boundary. `flatTextExcerpt(from:start:end:)` uses this partition to
/// re-introduce paragraph breaks when freezing a selection into display text.
///
/// Version history:
///   1.0 — Authoring Phase 5 review fixes: initial implementation
public func buildFlatTextBlocks(from model: FRUSDocumentRenderModel) -> [String] {
    var blocks: [String] = []
    var current = ""
    appendFlatTextBlocks(from: model.bodyNodes, into: &blocks, current: &current)
    flushFlatTextBlock(&blocks, &current)
    return blocks
}

/// Extracts the flat-text range `start..<end` (UTF-16 offsets, the coordinate space of
/// `DocumentHighlight.startOffset`/`endOffset` and the WebKit selection range) as
/// display text: per-block slices joined with `"\n\n"`, so a selection spanning block
/// boundaries keeps its paragraph breaks instead of fusing "…first paragraph.Start of
/// second…". A single-block range returns exactly the raw flat-text slice.
///
/// The offsets remain pure flat-space anchors: they delimit the *flat-text span*, not
/// the returned string (which inserts separators the flat text does not contain).
/// Whitespace-only per-block slices are dropped.
///
/// - Parameters:
///   - model: The document render model to extract from.
///   - start: UTF-16 start offset into `buildFlatText(from: model)`.
///   - end: UTF-16 end offset (exclusive).
/// - Returns: The block-separated passage, or `nil` when the range is empty, out of
///   bounds, splits a surrogate pair, or covers only whitespace — callers fall back
///   to their pre-existing behavior (raw selection text or empty string).
///
/// Version history:
///   1.0 — Authoring Phase 5 review fixes: initial implementation
public func flatTextExcerpt(from model: FRUSDocumentRenderModel, start: Int, end: Int) -> String? {
    guard start >= 0, end > start else { return nil }
    var pieces: [String] = []
    var position = 0
    for block in buildFlatTextBlocks(from: model) {
        let blockStart = position
        let blockLength = block.utf16.count
        position += blockLength
        let sliceStart = max(start, blockStart)
        let sliceEnd = min(end, blockStart + blockLength)
        guard sliceStart < sliceEnd else {
            if blockStart >= end { break }
            continue
        }
        guard let range = Range(
            NSRange(location: sliceStart - blockStart, length: sliceEnd - sliceStart),
            in: block
        ) else { return nil }
        let piece = String(block[range])
        if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pieces.append(piece)
        }
    }
    guard !pieces.isEmpty else { return nil }
    return pieces.joined(separator: "\n\n")
}

/// Ends the current block: appends it to `blocks` when non-empty and resets the
/// accumulator. Empty flushes are no-ops, so the concatenation invariant holds.
private func flushFlatTextBlock(_ blocks: inout [String], _ current: inout String) {
    guard !current.isEmpty else { return }
    blocks.append(current)
    current = ""
}

/// The block-partitioning twin of `appendFlatText`: identical DFS and identical
/// character contribution, but block-level containers flush the accumulator on entry
/// and exit so each visual block lands in its own segment.
private func appendFlatTextBlocks(
    from nodes: [FRUSRenderNode],
    into blocks: inout [String],
    current: inout String
) {
    for node in nodes {
        switch node {
        case .plainText(let s), .formulaText(let s):
            current += s
        case .lineBreak:
            current += "\n"
        case .tableBlock(let rows):
            flushFlatTextBlock(&blocks, &current)
            for row in rows {
                for cell in row {
                    appendFlatTextBlocks(from: cell.children, into: &blocks, current: &current)
                    flushFlatTextBlock(&blocks, &current)
                }
            }
        case .listBlock(_, let items):
            flushFlatTextBlock(&blocks, &current)
            for item in items {
                appendFlatTextBlocks(from: item, into: &blocks, current: &current)
                flushFlatTextBlock(&blocks, &current)
            }
        case .heading(let cs), .dateline(let cs), .letterOpener(let cs),
             .letterCloser(let cs), .salutation(let cs), .paragraph(let cs),
             .editorialNoteBlock(let cs), .titlePageBlock(let cs),
             .attachmentHeading(let cs):
            flushFlatTextBlock(&blocks, &current)
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
            flushFlatTextBlock(&blocks, &current)
        case .boldText(let cs), .italicText(let cs), .smallCapsText(let cs),
             .underlineText(let cs), .termText(let cs), .suppliedText(let cs),
             .sicText(let cs), .corrText(let cs):
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
        case .persNameLink(_, let cs, _):
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
        case .glossLink(_, let cs, _):
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
        case .crossRefLink(_, _, _, let cs):
            // Inline in the HTML serializer (<a>), so it never splits a block.
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
        case .unknown(_, let cs):
            // Serialized as an inline <span class="unknown">, so inline here too.
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
        case .attachmentBlock(_, let cs):
            flushFlatTextBlock(&blocks, &current)
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
            flushFlatTextBlock(&blocks, &current)
        case .footnoteBody(_, _, _, _, _, let cs):
            flushFlatTextBlock(&blocks, &current)
            appendFlatTextBlocks(from: cs, into: &blocks, current: &current)
            flushFlatTextBlock(&blocks, &current)
        default:
            // .pageBreak, .footnoteMarker, .figureBlock — contribute no characters
            break
        }
    }
}
