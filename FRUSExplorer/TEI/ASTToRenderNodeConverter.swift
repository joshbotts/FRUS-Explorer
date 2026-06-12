// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
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
///   1.x — Session 42: prefer `printedNumber` over sequential counter for display
///   1.1 — Session 78: `.attachment` case converts `.head` children to `.attachmentHeading`
///   1.2 — Session 79: `.titlePage` produces `.titlePageBlock` instead of `.unknown`
///   1.3 — Session 105: `renderingVersion(for:)` static API + `flatText(_:)` DFS helper
///   1.4 — Session 2026-06-08: `abbrLookup` added; `.unknown(name: "abbr", …)` elements
///          whose text matches a glossary term are emitted as `.glossLink` nodes so they
///          render with the accent-coloured dotted underline and open `GlossDetailSheet`
///          on tap, identical to explicit `<gloss ref="…">` elements.
public struct ASTToRenderNodeConverter {

    /// Converter algorithm version. Bump whenever the flat-text output changes
    /// (new text-bearing node type, traversal order change, character normalisation).
    /// Used as part of `DocumentHighlight.renderingVersion`.
    public static let kVersion = "1.2"

    // MARK: - Rendering Version

    /// Computes the 16-character hex `renderingVersion` for a render model.
    ///
    /// Hashes `SHA-256(flatText(bodyNodes).utf8 ++ kVersion.utf8)` and returns the
    /// first 16 hex characters (64 bits of collision resistance).
    ///
    /// The hash changes whenever the document's parsed text changes (e.g. after a
    /// volume re-download) or when `kVersion` is bumped after a converter algorithm change.
    /// Highlights whose stored `renderingVersion` no longer matches are shown as stale.
    public static func renderingVersion(for model: FRUSDocumentRenderModel) -> String {
        var data = Data()
        data.append(Data(flatText(model.bodyNodes).utf8))
        data.append(Data(kVersion.utf8))
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// DFS flat-text extraction per the Session 102 offset model spec.
    ///
    /// Rules:
    /// - `.plainText` / `.formulaText` → contribute their string value.
    /// - `.lineBreak` → contributes `"\n"`.
    /// - `.pageBreak`, `.footnoteMarker`, `.figureBlock`, `.footnoteBody` → skip (no chars).
    /// - `.suppliedText` children → recurse without adding brackets.
    /// - `.tableBlock` → recurse each cell's children in row-major order.
    /// - `.listBlock` → recurse each item in order.
    /// - All other container nodes → recurse their children.
    private static func flatText(_ nodes: [FRUSRenderNode]) -> String {
        var result = ""
        for node in nodes {
            switch node {
            case .plainText(let s):
                result += s
            case .formulaText(let s):
                result += s
            case .lineBreak:
                result += "\n"
            case .pageBreak, .footnoteMarker, .figureBlock, .footnoteBody:
                break
            case .tableBlock(let rows):
                for row in rows {
                    for cell in row { result += flatText(cell.children) }
                }
            case .listBlock(_, let items):
                for item in items { result += flatText(item) }
            case .heading(let c), .dateline(let c), .letterOpener(let c),
                 .letterCloser(let c), .salutation(let c), .paragraph(let c),
                 .boldText(let c), .italicText(let c), .smallCapsText(let c),
                 .underlineText(let c), .termText(let c), .suppliedText(let c),
                 .sicText(let c), .corrText(let c), .editorialNoteBlock(let c),
                 .titlePageBlock(let c), .attachmentHeading(let c):
                result += flatText(c)
            case .persNameLink(_, let c, _), .glossLink(_, let c, _),
                 .crossRefLink(_, _, let c), .attachmentBlock(_, let c),
                 .unknown(_, let c):
                result += flatText(c)
            }
        }
        return result
    }

    // MARK: Dependencies

    /// Returns a `PersonEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's persons list.
    public var personLookup: ((String) -> PersonEntry?)?

    /// Returns a `GlossEntry` for a given `ref` attribute value.
    /// `nil` until Session 07 populates the volume's terms list.
    public var glossLookup: ((String) -> GlossEntry?)?

    /// Returns a `GlossEntry` whose `term` text matches the given abbreviation string
    /// (case-insensitive). Used to resolve `<abbr>` elements that lack a `@ref` attribute.
    ///
    /// When non-nil, any `.unknown(name: "abbr", …)` AST node whose plain-text content
    /// matches a glossary term is emitted as a `.glossLink` render node — giving it the
    /// same dotted-underline styling and tap-to-sheet behaviour as explicit
    /// `<gloss ref="…">` links.
    ///
    /// `nil` (default) means `<abbr>` elements are rendered as plain text without linking.
    public var abbrLookup: ((String) -> GlossEntry?)?

    // MARK: State

    private var footnoteCounter = 0
    private var collectedFootnotes: [FRUSRenderNode] = []

    // MARK: Init

    public init(personLookup: ((String) -> PersonEntry?)? = nil,
                glossLookup: ((String) -> GlossEntry?)? = nil,
                abbrLookup: ((String) -> GlossEntry?)? = nil) {
        self.personLookup = personLookup
        self.glossLookup = glossLookup
        self.abbrLookup = abbrLookup
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

        case .footnote(let id, let type, let printedNumber, let children):
            footnoteCounter += 1
            let sequentialNumber = footnoteCounter
            // Use the printed number for display if available; fall back to sequential counter.
            // The counter is always incremented to keep bookkeeping consistent even when
            // some notes have @n and others do not within the same document.
            let displayLabel = printedNumber ?? "\(sequentialNumber)"
            let convertedChildren = convertNodes(children)
            // When a footnote contains only inline nodes (no <p> wrapper in the source TEI),
            // wrap them in a single .paragraph so the renderer treats them as continuous prose
            // rather than rendering each node as a separate VStack row.
            let footnoteChildren: [FRUSRenderNode] = convertedChildren.contains(where: isBlockNode)
                ? convertedChildren
                : [.paragraph(convertedChildren)]
            let body = FRUSRenderNode.footnoteBody(
                id: id, type: type,
                printedNumber: printedNumber,
                sequentialNumber: sequentialNumber,
                displayLabel: displayLabel,
                children: footnoteChildren
            )
            collectedFootnotes.append(body)
            return [.footnoteMarker(id: id, displayLabel: displayLabel)]

        case .persName(let ref, let children):
            // Normalise the ref by stripping the leading '#' that FRUS TEI uses
            // (e.g. ref="#AlexanderHaig"). PersonEntry.ref stores the bare xml:id
            // value without '#', so the lookup only succeeds after normalisation.
            let normRef = ref.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            let person  = normRef.flatMap { personLookup?($0) }
            return [.persNameLink(ref: normRef, children: convertNodes(children), person: person)]

        case .gloss(let ref, let children):
            // Heading-metadata glosses (`<gloss type="from">Department of State</gloss>`
            // etc.) carry no target — they are not glossary terms and must not
            // render as tappable links (Session 162 link audit: they produced
            // dead `href="#"` anchors in document headings).
            guard let rawRef = ref else {
                return convertNodes(children)
            }
            let normRef = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
            let entry   = glossLookup?(normRef)
            return [.glossLink(ref: normRef, children: convertNodes(children), entry: entry)]

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
            return [.titlePageBlock(convertNodes(children))]

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

        // MARK: Dates (Session 36)

        case .date(_, _, _, _, _, let children):
            // The structured date attributes (@when/@from/@to) are consumed by the
            // indexing pipeline only. Rendering passes through the display-text children
            // unchanged so the dateline reads identically to before this change.
            return convertNodes(children)

        // MARK: Attachments (Session 78)

        case .attachment(let n, let children):
            // Convert each child, but promote <head> children to .attachmentHeading
            // so the renderer can apply secondary heading style without extra context.
            let convertedChildren: [FRUSRenderNode] = children.flatMap { child -> [FRUSRenderNode] in
                if case .head(let headChildren) = child {
                    return [.attachmentHeading(convertNodes(headChildren))]
                }
                return convertNode(child)
            }
            return [.attachmentBlock(n: n, children: convertedChildren)]

        case .unknown(let name, _, let children) where name == "abbr":
            // Try to resolve the abbreviation text against the volume's glossary.
            // If a match is found, emit a `.glossLink` identical to an explicit
            // `<gloss ref="…">` element so the renderer styles it and the URL scheme
            // handler can open GlossDetailSheet on tap.
            let abbText = children.map(\.plainText).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !abbText.isEmpty, let entry = abbrLookup?(abbText) {
                return [.glossLink(
                    ref: "#\(entry.ref)",
                    children: convertNodes(children),
                    entry: entry
                )]
            }
            // No matching glossary entry — fall through as plain text.
            return convertNodes(children)

        case .unknown(let name, _, let children):
            return [.unknown(name: name, children: convertNodes(children))]
        }
    }

    private func isBlockNode(_ node: FRUSRenderNode) -> Bool {
        switch node {
        case .paragraph, .heading, .dateline, .letterOpener, .letterCloser,
             .salutation, .editorialNoteBlock, .tableBlock, .listBlock, .figureBlock,
             .attachmentBlock, .attachmentHeading, .titlePageBlock:
            return true
        default:
            return false
        }
    }
}
