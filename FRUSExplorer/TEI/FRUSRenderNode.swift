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
    /// `number` is the sequential 1-based display number assigned by the converter.
    case footnoteBody(id: String?, type: FootnoteType, number: Int, children: [FRUSRenderNode])

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
    /// The matching body is in `FRUSDocumentRenderModel.footnotes`.
    case footnoteMarker(id: String?, number: Int)

    // MARK: Interactive Elements

    /// A personal name link (`<persName>`).
    /// `person` is non-nil when the volume's List of Persons has been parsed (Session 07+).
    case persNameLink(ref: String?, children: [FRUSRenderNode], person: PersonEntry?)

    /// A glossary term link (`<gloss>`).
    /// `entry` is non-nil when the volume's Terms list has been parsed (Session 07+).
    case glossLink(ref: String?, children: [FRUSRenderNode], entry: GlossEntry?)

    /// A cross-reference link (`<ref>`).
    case crossRefLink(target: String, volumeId: String?, children: [FRUSRenderNode])

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

    // MARK: Passthrough / Unknown

    /// Preserves unrecognised elements for forward compatibility.
    /// Children are rendered as their own nodes.
    case unknown(name: String, children: [FRUSRenderNode])
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
/// Produced by `ASTToRenderNodeConverter.convert(_:)`. Consumed by `FRUSDocumentRenderer`.
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
    /// `footnoteMarker` nodes within this list reference entries in `footnotes` by number.
    public let bodyNodes: [FRUSRenderNode]

    /// Footnote bodies in sequential display order (1-based numbering).
    public let footnotes: [FRUSRenderNode]
}
