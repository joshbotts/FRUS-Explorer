// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Converter

/// Layer 2 of the TEI rendering pipeline.
///
/// Converts a `FRUSDocumentAST` (Layer 1 output) into a `FRUSDocumentRenderModel`
/// (Layer 2 output) according to the `TEIRenderingConfig`.
///
/// ## Footnote Numbering
/// Footnotes are numbered sequentially in document order during the single conversion
/// pass. Each `<note>` in the AST produces two render nodes:
///   - A `footnoteMarker` inline at the reference point (goes into the body).
///   - A `footnoteBody` collected in the `footnotes` array for bottom rendering.
///
/// ## persName / gloss Lookup
/// In Session 06, lookups always return `nil` (the volume's List of Persons and Terms
/// are not yet parsed). Session 07 passes non-nil lookup closures to enable the popover
/// content in the Document view.
///
/// ## Mutability
/// The converter tracks footnote state via a `var` counter. Instances are single-use
/// (one instance per `convert` call).
///
/// Version history:
///   1.0 — Session 06: initial implementation
public struct ASTToRenderNodeConverter {

    // MARK: Dependencies

    /// Returns a `PersonEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's persons list.
    public var personLookup: ((String) -> PersonEntry?)?

    /// Returns a `GlossEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's terms list.
    public var glossLookup: ((String) -> GlossEntry?)?

    // MARK: State

    private var footnoteCounter = 0
    private var collectedFootnotes: [FRUSRenderNode] = []

    // MARK: Init

    public init(personLookup: ((String) -> PersonEntry?)? = nil,
                glossLookup: ((String) -> GlossEntry?)? = nil) {
        self.personLookup = personLookup
        self.glossLookup = glossLookup
    }

    // MARK: - Public API

    /// Converts a `FRUSDocumentAST` into a `FRUSDocumentRenderModel`.
    ///
    /// This method is called once per document. The converter instance should not be
    /// reused across multiple documents because the footnote counter is not reset.
    public mutating func convert(_ ast: FRUSDocumentAST) -> FRUSDocumentRenderModel {
        let bodyNodes = convertNodes(ast.nodes)
        return FRUSDocumentRenderModel(
            documentId: ast.documentId,
            bodyNodes: bodyNodes,
            footnotes: collectedFootnotes
        )
    }

    // MARK: - Node Conversion

    private mutating func convertNodes(_ nodes: [FRUSASTNode]) -> [FRUSRenderNode] {
        nodes.flatMap { convertNode($0) }
    }

    private mutating func convertNode(_ node: FRUSASTNode) -> [FRUSRenderNode] {
        switch node {

        case .document(_, _, let children):
            return convertNodes(children)

        case .head(let children):
            return [.heading(convertNodes(children))]

        case .dateline(let children):
            return [.dateline(convertNodes(children))]

        case .opener(let children):
            return [.letterOpener(convertNodes(children))]

        case .closer(let children):
            return [.letterCloser(convertNodes(children))]

        case .salute(let children):
            return [.salutation(convertNodes(children))]

        case .paragraph(let children):
            return [.paragraph(convertNodes(children))]

        case .footnote(let id, let type, let children):
            footnoteCounter += 1
            let number = footnoteCounter
            // Collect the body for bottom-of-document rendering.
            let body = FRUSRenderNode.footnoteBody(
                id: id, type: type, number: number, children: convertNodes(children)
            )
            collectedFootnotes.append(body)
            // Return the inline marker at the reference point.
            return [.footnoteMarker(id: id, number: number)]

        case .persName(let ref, let children):
            let person = ref.flatMap { personLookup?($0) }
            return [.persNameLink(ref: ref, children: convertNodes(children), person: person)]

        case .gloss(let ref, let children):
            let entry = ref.flatMap { glossLookup?($0) }
            return [.glossLink(ref: ref, children: convertNodes(children), entry: entry)]

        case .crossReference(let target, let volumeId, let children):
            return [.crossRefLink(target: target, volumeId: volumeId, children: convertNodes(children))]

        case .emphasis(let style, let children):
            let inner = convertNodes(children)
            switch style {
            case .italic:    return [.italicText(inner)]
            case .bold:      return [.boldText(inner)]
            case .smallCaps: return [.smallCapsText(inner)]
            case .underline: return [.underlineText(inner)]
            case .unspecified: return inner
            }

        case .term(let children):
            return [.termText(convertNodes(children))]

        case .text(let string):
            return string.isEmpty ? [] : [.plainText(string)]

        // MARK: Page breaks (Session 07)

        case .pageBreak(let number):
            return [.pageBreak(pageNumber: number)]

        // MARK: Tables (Session 07)

        case .table(let rows):
            let renderRows: [[TableCell]] = rows.compactMap { row in
                guard case .tableRow(let cells) = row else { return nil }
                return cells.compactMap { cell -> TableCell? in
                    guard case .tableCell(let rs, let cs, let ch) = cell else { return nil }
                    return TableCell(rowSpan: rs, colSpan: cs, children: convertNodes(ch))
                }
            }
            return [.tableBlock(rows: renderRows)]

        case .tableRow, .tableCell:
            // Handled as children of .table; should not appear standalone.
            return []

        // MARK: Lists (Session 07)

        case .list(let type, let items):
            let renderItems: [[FRUSRenderNode]] = items.compactMap { item in
                guard case .listItem(let ch) = item else { return nil }
                return convertNodes(ch)
            }
            return [.listBlock(type: type?.rawValue, items: renderItems)]

        case .listItem:
            // Handled as children of .list; should not appear standalone.
            return []

        // MARK: Structural divisions (Session 07)

        case .editorialNote(let children):
            return [.editorialNoteBlock(convertNodes(children))]

        case .titlePage(let children):
            return [.unknown(name: "titlePage", children: convertNodes(children))]

        // MARK: Figures and formulas (Session 07)

        case .figure(let graphic, _):
            return [.figureBlock(altText: graphic)]

        case .formula(let text):
            return [.formulaText(text)]

        // MARK: Inline editorial marks (Session 07)

        case .supplied(let children):
            return [.suppliedText(convertNodes(children))]

        case .sic(let children):
            return [.sicText(convertNodes(children))]

        case .corr(let children):
            return [.corrText(convertNodes(children))]

        // MARK: Line breaks (Session 07)

        case .lineBreak:
            return [.lineBreak]

        case .unknown(let name, _, let children):
            return [.unknown(name: name, children: convertNodes(children))]
        }
    }
}
