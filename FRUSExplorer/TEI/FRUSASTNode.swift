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
///   1.1 — Session 76: `dateTimeMin`/`dateTimeMax` added to carry `frus:doc-dateTime-min`
///          and `frus:doc-dateTime-max` attribute values set by the HistoryAtState TEI
///          pipeline. These are the authoritative editorial date bounds for each document.
public struct FRUSDocumentAST: Sendable {
    /// The value of the `xml:id` attribute on the `<div type="document">` element.
    /// e.g. `"d1"`, `"d42"`. Stable identifier used to locate documents within a volume.
    public let documentId: String

    /// Top-level child nodes of the document div.
    public let nodes: [FRUSASTNode]

    /// Value of the `frus:doc-dateTime-min` attribute on the document div, if present.
    ///
    /// Set by the HistoryAtState `update-frus-doc-dates.xsl` pipeline. Represents the
    /// earliest bound of the document date range as a full xs:dateTime string, normalized
    /// to a consistent timezone offset. Derived from `@from`, `@notBefore`, or `@when`
    /// on the first dateline `<date>` element. Absent on volumes not yet processed by
    /// the pipeline.
    public let dateTimeMin: String?

    /// Value of the `frus:doc-dateTime-max` attribute on the document div, if present.
    ///
    /// The latest bound of the document date range. Derived from `@to`, `@notAfter`, or
    /// `@when` (expanded to end-of-period). Stored alongside `dateTimeMin` so the
    /// indexing pipeline can use interval overlap rather than point comparison for
    /// date-range filtering.
    public let dateTimeMax: String?

    /// `true` when this document was promoted from a prose-only front-matter structural
    /// div (e.g. `<div type="preface">`, `<div type="prefatoryNote">`).
    ///
    /// Used by `IndexingPipeline` to populate the `is_front_matter` column in
    /// `document_cache`, which in turn powers the "Include front matter" search
    /// scope toggle in Phase 4.
    ///
    /// `false` for primary-source documents (`<div type="document">`) and editorial
    /// notes (`<div type="editorialNote">`).
    public let isFrontMatter: Bool

    /// Canonical document number from the document div's `@n` attribute (e.g. `"17"`).
    ///
    /// This is the **history.state.gov document number** — every document on HSG carries
    /// one, so citing it lets a reader resolve directly to the canonical source. It is
    /// preferred over parsing the leading number out of the `<head>` text: in early volumes
    /// the printed edition was unnumbered (heads are titles), but the HSG digital edition /
    /// TEI assigns each document an `@n`, and that is the number readers use to locate it.
    public let printedNumber: String?

    public init(
        documentId: String,
        nodes: [FRUSASTNode],
        dateTimeMin: String? = nil,
        dateTimeMax: String? = nil,
        isFrontMatter: Bool = false,
        printedNumber: String? = nil
    ) {
        self.documentId = documentId
        self.nodes = nodes
        self.dateTimeMin = dateTimeMin
        self.dateTimeMax = dateTimeMax
        self.isFrontMatter = isFrontMatter
        self.printedNumber = printedNumber
    }
}

// MARK: - Classification override (#279 / W-4)

extension FRUSDocumentAST {

    /// Whether this document's AST is SHAPED as an editorial note — the exact rule
    /// `IndexingPipeline` applies at index time (the first node is `.editorialNote`), kept
    /// here so the two cannot drift.
    public var isShapedAsEditorialNote: Bool {
        guard let first = nodes.first, case .editorialNote = first else { return false }
        return true
    }

    /// The AST with a user's classification override applied to its SHAPE (#279, owner
    /// decision: the override restyles the body, not only the metadata).
    ///
    /// - Overriding to a DOCUMENT unwraps the `.editorialNote` container, splicing its
    ///   children in place, so the body renders as ordinary document prose.
    /// - Overriding to an EDITORIAL NOTE wraps the whole body in one `.editorialNote`
    ///   node, exactly the shape the parser produces for `subtype="editorial-note"`.
    ///
    /// Idempotent: an override matching the AST's own shape returns the AST unchanged, so
    /// callers can apply the EFFECTIVE classification unconditionally.
    public func applyingClassificationOverride(isEditorialNote: Bool) -> FRUSDocumentAST {
        guard isEditorialNote != isShapedAsEditorialNote else { return self }
        let newNodes: [FRUSASTNode]
        if isEditorialNote {
            newNodes = [.editorialNote(nodes)]
        } else {
            newNodes = nodes.flatMap { node -> [FRUSASTNode] in
                if case .editorialNote(let children) = node { return children }
                return [node]
            }
        }
        return FRUSDocumentAST(
            documentId: documentId,
            nodes: newNodes,
            dateTimeMin: dateTimeMin,
            dateTimeMax: dateTimeMax,
            isFrontMatter: isFrontMatter,
            printedNumber: printedNumber)
    }
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
/// Version history:
///   1.0 — Session 06: initial implementation (core elements)
///   1.1 — Session 07: full element coverage (page breaks, tables, lists, editorial notes, etc.)
///   1.2 — Session 36: `.date` case added for structured date attribute extraction
///   1.2 — Session 42: `.footnote` gains `printedNumber: String?` for TEI `@n` attribute
///   1.3 — Session 78: `.attachment` added for `<frus:attachment>` sub-document blocks
public indirect enum FRUSASTNode: Sendable {

    // MARK: Document Structure

    /// `<div type="document">` — the top-level container for a single FRUS document.
    /// `id` is the `xml:id` attribute value (e.g. `"d1"`).
    case document(id: String, attributes: [String: String], children: [FRUSASTNode])

    /// `<head>` — document heading, typically the document title or number.
    case head(children: [FRUSASTNode])

    /// `<dateline>` — date and location line at the top of a document.
    case dateline(children: [FRUSASTNode])

    /// `<date>` — a date element, typically inside a `<dateline>` or document body.
    ///
    /// Preserves machine-readable ISO 8601 values from TEI date attributes so the
    /// indexing pipeline can extract structured dates without heuristic parsing.
    ///
    /// - `when`:      Exact point-in-time value (`@when`), e.g. `"1969-01-15"`.
    /// - `from`/`to`: Inclusive range endpoints (`@from`, `@to`).
    /// - `notBefore`/`notAfter`: Approximate bounds (`@notBefore`, `@notAfter`).
    /// - `children`:  Original display text nodes (used for rendering; unchanged).
    case date(
        when: String?,
        from: String?,
        to: String?,
        notBefore: String?,
        notAfter: String?,
        children: [FRUSASTNode]
    )

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
    /// `printedNumber` is the `@n` attribute value as it appears in the printed volume.
    /// May differ from the sequential display number assigned by the converter when
    /// footnotes are renumbered or have gaps in the source TEI.
    case footnote(id: String?, type: FootnoteType, printedNumber: String?, children: [FRUSASTNode])

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

    // MARK: Page Breaks (Session 07)

    /// `<pb>` — page break. Carries the normalized page number from the `@n` attribute.
    /// Not rendered visually; required by Session 30 (Citation Lookup) for page range resolution.
    case pageBreak(pageNumber: PageNumber)

    // MARK: Tables (Session 07)

    /// `<table>` — a tabular structure. Children are `.tableRow` nodes.
    case table([FRUSASTNode])

    /// `<row>` — a row within a table. Children are `.tableCell` nodes.
    case tableRow([FRUSASTNode])

    /// `<cell>` — a cell within a table row.
    /// `rowSpan` / `colSpan` come from the TEI `@rows` / `@cols` spanning attributes (default 1).
    case tableCell(rowSpan: Int, colSpan: Int, children: [FRUSASTNode])

    // MARK: Lists (Session 07)

    /// `<list>` — an ordered or unordered list. Children are `.listItem` nodes.
    case list(type: ListType?, items: [FRUSASTNode])

    /// `<item>` — a single list item.
    case listItem([FRUSASTNode])

    // MARK: Structural Divisions (Session 07)

    /// `<div type="editorialNote">` — an editorial note block.
    case editorialNote([FRUSASTNode])

    /// `<titlePage>` — the title page element in front matter.
    case titlePage([FRUSASTNode])

    // MARK: Inline Editorial Marks (Session 07)

    /// `<supplied>` — text supplied by the editor to fill a gap in the source.
    case supplied([FRUSASTNode])

    /// `<sic>` — an error in the source text, preserved as-is.
    case sic([FRUSASTNode])

    /// `<corr>` — a correction replacing an error in the source.
    case corr([FRUSASTNode])

    // MARK: Figures and Formulas (Session 07)

    /// `<figure>` — a figure element. `graphic` is the URL from a nested `<graphic url="..."/>`.
    case figure(graphic: String?, children: [FRUSASTNode])

    /// `<formula>` — a mathematical or chemical formula. Contains the raw formula text.
    case formula(String)

    // MARK: Line Breaks (Session 07)

    /// `<lb>` — a line break within flowing text.
    case lineBreak

    // MARK: Attachments (Session 78)

    /// `<frus:attachment>` — a sub-document attached to a FRUS document.
    ///
    /// Appears at the end of a `<div type="document">`, after all body content.
    /// Multiple siblings may follow one another. `n` carries the `@n` attribute
    /// if present (ordinal label). The element cannot contain child `<tei:div>`
    /// elements; its content model mirrors a stripped document div.
    case attachment(n: String?, children: [FRUSASTNode])

    // MARK: Unknown (Forward Compatibility)

    /// Any TEI element not explicitly handled above. Never dropped.
    /// `name` is the local element name. Children are preserved.
    case unknown(name: String, attributes: [String: String], children: [FRUSASTNode])
}

// MARK: - Supporting Enums

/// Certainty of a structured date value extracted from a `.date` AST node.
///
/// Derived from which TEI date attributes are present on the `<date>` element.
/// Used by `IndexingPipeline.extractStructuredDate(from:)` to rank candidates.
///
/// Version history:
///   1.0 — Session 36: initial implementation
public enum DateCertainty: Sendable, Comparable {
    /// `@when` present — an exact point-in-time date.
    case exact
    /// `@from` and/or `@to` present — a defined date range.
    case range
    /// Only `@notBefore` and/or `@notAfter` — an approximate bound.
    case approximate
    /// No machine-readable attributes; content is display text only.
    case textOnly

    /// Stable lowercase string used to persist this value in the `document_dates`
    /// table. Kept separate from the case names so the storage format is decoupled
    /// from any future case renames.
    public var storageValue: String {
        switch self {
        case .exact:       return "exact"
        case .range:       return "range"
        case .approximate: return "approximate"
        case .textOnly:    return "textOnly"
        }
    }

    /// Reconstructs a `DateCertainty` from its `storageValue`. Returns `nil` for an
    /// unrecognized or `NULL` string (e.g. a row indexed before certainty was stored).
    public init?(storageValue: String?) {
        switch storageValue {
        case "exact":       self = .exact
        case "range":       self = .range
        case "approximate": self = .approximate
        case "textOnly":    self = .textOnly
        default:            return nil
        }
    }
}

/// Granularity of a structured date value — how precisely the source TEI pinned the date.
///
/// Derived from the component count of the **raw** `<date>` attribute string before it
/// is padded to a full `yyyy-MM-dd` by the indexing pipeline. Persisted in the
/// `document_dates.date_precision` column so date features can render and place dates
/// honestly (a year-only document should read "1969", not "January 1, 1969") instead of
/// inheriting the false day-level precision created by normalization.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public enum DatePrecision: String, Sendable, Comparable {
    /// Full `yyyy-MM-dd` — an exact calendar day.
    case day
    /// `yyyy-MM` — month known, day unknown.
    case month
    /// `yyyy` — only the year is known.
    case year

    /// Coarse-to-fine ordering (`year < month < day`) so callers can compare precision.
    public static func < (lhs: DatePrecision, rhs: DatePrecision) -> Bool {
        func rank(_ p: DatePrecision) -> Int {
            switch p {
            case .year:  return 0
            case .month: return 1
            case .day:   return 2
            }
        }
        return rank(lhs) < rank(rhs)
    }
}

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

// MARK: - Session 07 Supporting Types

/// Normalized page number extracted from a `<pb @n="...">` element.
///
/// Normalization rules:
/// - Leading zeros stripped before arabic conversion.
/// - Roman numerals parsed case-insensitively (i, v, x, l, c, d, m).
/// - Bracketed Roman numerals (e.g. `"[XII]"`) stripped of brackets then parsed as roman.
/// - Prefixed forms (e.g. `"A-12"`) preserved verbatim.
/// - Unparseable values preserved and logged as a `[TEIParser]` warning.
///
/// Required by Session 30 (Citation Lookup) for page range resolution.
///
/// Version history:
///   1.0 — Session 07: initial implementation
public enum PageNumber: Sendable, Equatable {
    case arabic(Int)
    case roman(Int)
    case prefixed(String)
    case unparseable(String)

    public static func parse(_ raw: String) -> PageNumber {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return .unparseable(raw) }
        if let n = Int(s) { return .arabic(n) }
        // Strip enclosing brackets, e.g. "[XII]" → "XII" (FRUS front-matter convention)
        let unbracketed: String
        if s.hasPrefix("["), s.hasSuffix("]") {
            unbracketed = String(s.dropFirst().dropLast())
        } else {
            unbracketed = s
        }
        let lower = unbracketed.lowercased()
        if !lower.isEmpty, lower.allSatisfy({ "ivxlcdm".contains($0) }), let r = romanToInt(lower), r > 0 {
            return .roman(r)
        }
        // Prefixed: letter(s) + hyphen/en-dash + digits, e.g. "A-12"
        if s.range(of: #"^[A-Za-z]+[-–]\d+"#, options: .regularExpression) != nil {
            return .prefixed(s)
        }
        #if DEBUG
        print("[TEIParser] Warning: unparseable <pb n=\"\(s)\">")
        #endif
        return .unparseable(s)
    }

    private static func romanToInt(_ s: String) -> Int? {
        let map: [Character: Int] = ["i": 1, "v": 5, "x": 10, "l": 50, "c": 100, "d": 500, "m": 1000]
        var result = 0
        var prev = 0
        for ch in s.reversed() {
            guard let val = map[ch] else { return nil }
            if val < prev { result -= val } else { result += val }
            prev = val
        }
        return result > 0 ? result : nil
    }
}

/// The display style for a `<list>` element.
public enum ListType: String, Sendable, Codable {
    case ordered
    case unordered
    case simple
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
///   1.2 — Person rollup Phase 1: role + active-year range captured from the persons list
///   1.3 — Audit fix: collapse internal whitespace in `description`/`role`. The TEI List of
///          Persons wraps the trailing role text across indented source lines, so the captured
///          string carries embedded newlines + run-on spaces (e.g. "Assistant\n      to the
///          President…"). Normalizing in the initializer fixes both the stored value on the next
///          index *and* the display of values already in the database, with no version bump.
public struct PersonEntry: Sendable, Identifiable {
    /// The `xml:id` attribute value of the `<person>` element, matching the `ref`
    /// attribute of `<persName>` elements in the document body.
    public let ref: String

    /// Full display name.
    public let name: String

    /// Optional biographical description from the List of Persons (the full trailing text after
    /// the name, e.g. "Assistant to the President for National Security Affairs, 1969–1975").
    public let description: String?

    /// The role/title portion of `description` with any trailing year range removed
    /// (e.g. "Assistant to the President for National Security Affairs"). Used for compact
    /// `role · era` subtitles. `nil` when the persons list gives no descriptive text.
    public let role: String?

    /// First year of the person's active range, parsed from the persons-list text when present.
    public let startYear: Int?

    /// Last year of the person's active range (or `nil` for an open/"present" range or a single year).
    public let endYear: Int?

    public var id: String { ref }

    public init(ref: String, name: String, description: String? = nil,
                role: String? = nil, startYear: Int? = nil, endYear: Int? = nil) {
        self.ref = ref
        self.name = name
        self.description = PersonEntry.collapsingWhitespace(description)
        self.role = PersonEntry.collapsingWhitespace(role)
        self.startYear = startYear
        self.endYear = endYear
    }

    /// Collapses every run of Unicode whitespace (spaces, tabs, the newlines and indentation the
    /// TEI source wraps role text across) into a single ASCII space and trims the ends. Returns
    /// `nil` for a `nil` input or a value that is entirely whitespace, preserving the "no role"
    /// semantics callers rely on.
    private static func collapsingWhitespace(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }
}

public extension PersonEntry {
    /// A compact active-year string for subtitles: "1969–1975" for a range, "1969" for a single or
    /// open-ended year, or `nil` when no year was parsed.
    var eraText: String? {
        guard let start = startYear else { return nil }
        if let end = endYear, end != start { return "\(start)–\(end)" }
        return "\(start)"
    }

    /// A one-line `role · era` subtitle combining the role title (falling back to `description`)
    /// with `eraText`. `nil` when neither is available.
    var roleEraSubtitle: String? {
        let title = role ?? description
        switch (title, eraText) {
        case let (t?, e?): return "\(t) · \(e)"
        case let (t?, nil): return t
        case let (nil, e?): return e
        default: return nil
        }
    }
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
