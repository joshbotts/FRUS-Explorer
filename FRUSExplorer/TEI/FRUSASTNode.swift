// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Document AST

/// A single parsed FRUS document extracted from a volume XML file.
///
/// One `FRUSDocumentAST` corresponds to one `<div type="document">` in the TEI source.
/// Each volume XML file contains many documents; `FRUSDocumentParser` returns an array.
///
/// Version history:
///   1.0 — Session 06: initial implementation
public struct FRUSDocumentAST: Sendable {
    /// The value of the `xml:id` attribute on the `<div type="document">` element.
    /// e.g. `"d1"`, `"d42"`. Stable identifier used to locate documents within a volume.
    public let documentId: String

    /// Top-level child nodes of the document div.
    public let nodes: [FRUSASTNode]
}

// MARK: - AST Node

/// A node in the FRUS document abstract syntax tree.
///
/// Layer 1 of the three-layer rendering pipeline. Produced by `FRUSDocumentParser`
/// from the TEI XML source; consumed by `ASTToRenderNodeConverter` (Layer 2).
///
/// ## Unknown Element Handling
/// Any TEI element not explicitly handled is represented as `.unknown(name:attributes:children:)`
/// rather than being dropped. This ensures forward compatibility: documents using elements
/// added in future FRUS.odd revisions parse without crashing and their content is preserved.
///
/// ## Session 07 Extensions
/// Session 07 extends this enum with: `pageBreak`, `tableElement`, `listElement`, `listItem`,
/// `editorialNote`, `lineBreak`, `figure`, `supplied`, `sic`, `correction`.
///
/// Version history:
///   1.0 — Session 06: initial implementation
public indirect enum FRUSASTNode: Sendable {

    // MARK: Document Structure

    /// `<div type="document">` — the top-level container for a single FRUS document.
    /// `id` is the `xml:id` attribute value (e.g. `"d1"`).
    case document(id: String, attributes: [String: String], children: [FRUSASTNode])

    /// `<head>` — document heading, typically the document title or number.
    case head(children: [FRUSASTNode])

    /// `<dateline>` — date and location line at the top of a document.
    case dateline(children: [FRUSASTNode])

    /// `<opener>` — opening block of a letter or memorandum.
    case opener(children: [FRUSASTNode])

    /// `<closer>` — closing block of a letter or memorandum.
    case closer(children: [FRUSASTNode])

    /// `<salute>` — salutation line within an opener or closer.
    case salute(children: [FRUSASTNode])

    // MARK: Content

    /// `<p>` — paragraph.
    case paragraph(children: [FRUSASTNode])

    /// `<note>` — footnote, editorial note, or source note embedded in the document.
    /// `id` is the `xml:id` attribute (may be absent). `type` classifies the note.
    case footnote(id: String?, type: FootnoteType, children: [FRUSASTNode])

    // MARK: Inline Links

    /// `<persName>` — a personal name that links to the volume's List of Persons.
    /// `ref` is the `ref` attribute value matching a `<person xml:id>` entry.
    case persName(ref: String?, children: [FRUSASTNode])

    /// `<gloss>` — a term that links to the volume's Terms and Abbreviations list.
    /// `ref` is the `ref` attribute value matching a `<term xml:id>` entry.
    case gloss(ref: String?, children: [FRUSASTNode])

    /// `<ref>` — a cross-reference to another FRUS document.
    /// `target` is the raw `target` attribute (e.g. `"#d42"` or `"frus1969-76v01#d42"`).
    /// `targetVolumeId` is extracted when `target` includes a volume identifier.
    case crossReference(target: String, targetVolumeId: String?, children: [FRUSASTNode])

    // MARK: Inline Formatting

    /// `<hi>` — typographic emphasis. `style` is derived from the `rend` attribute.
    case emphasis(style: EmphasisStyle, children: [FRUSASTNode])

    /// `<term>` — a technical term or abbreviation, rendered with subtle visual distinction.
    case term(children: [FRUSASTNode])

    // MARK: Text

    /// A run of character data. Whitespace is normalized by the parser.
    case text(String)

    // MARK: Unknown (Forward Compatibility)

    /// Any TEI element not explicitly handled above. Never dropped.
    /// `name` is the local element name. Children are preserved.
    case unknown(name: String, attributes: [String: String], children: [FRUSASTNode])
}

// MARK: - Supporting Enums

/// Classification of a `<note>` element by its `type` attribute.
public enum FootnoteType: String, Sendable, Codable {
    case footnote
    case editorial
    case source
    /// Used when the `type` attribute is absent or unrecognized.
    case unclassified
}

/// Visual style for `<hi>` elements, derived from the `rend` attribute.
public enum EmphasisStyle: String, Sendable, Codable {
    case italic
    case bold
    case smallCaps  // rend="smallcaps"
    case underline
    /// Used when the `rend` attribute is absent or unrecognized.
    case unspecified
}

// MARK: - Lookup Types

/// A person entry from the volume's List of Persons (`<div type="persons">`).
///
/// Populated by the `<div type="persons">` parser in Session 07.
/// In Session 06 lookups return `nil` until the volume's persons div is parsed.
///
/// Version history:
///   1.0 — Session 06: initial definition
///   1.1 — Session 07: populated by persons div parser
public struct PersonEntry: Sendable, Identifiable {
    /// The `xml:id` attribute value of the `<person>` element, matching the `ref`
    /// attribute of `<persName>` elements in the document body.
    public let ref: String

    /// Full display name.
    public let name: String

    /// Optional biographical description from the List of Persons.
    public let description: String?

    public var id: String { ref }
}

/// A term entry from the volume's Terms and Abbreviations list (`<div type="terms">`).
///
/// Populated by the `<div type="terms">` parser in Session 07.
///
/// Version history:
///   1.0 — Session 06: initial definition
///   1.1 — Session 07: populated by terms div parser
public struct GlossEntry: Sendable, Identifiable {
    /// The `xml:id` attribute value of the `<term>` element, matching the `ref`
    /// attribute of `<gloss>` elements in the document body.
    public let ref: String

    /// The term or abbreviation.
    public let term: String

    /// The definition or expansion of the abbreviation.
    public let definition: String?

    public var id: String { ref }
}
