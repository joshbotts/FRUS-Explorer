// MARK: - FRUS TEI Model
// Models the TEI P5 XML structure used by the HistoryAtState/frus repository.
// Schema reference: https://github.com/HistoryAtState/frus/tree/master/schema

import Foundation

// MARK: - Top-Level Document

/// The root `<TEI>` element of a FRUS volume.
public struct FRUSVolume: Sendable {
    /// Value of the `@xml:id` attribute on `<TEI>` — the volume identifier, e.g. `frus1969-76v24`.
    public let id: String
    /// Bibliographic and administrative metadata (`<teiHeader>`).
    public let header: TEIHeader
    /// The textual content of the volume (`<text>`).
    public let text: TEIText
}

// MARK: - TEI Header

/// `<teiHeader>` — bibliographic and administrative metadata.
public struct TEIHeader: Sendable {
    public let fileDescription: FileDescription
    public let encodingDescription: EncodingDescription?
    public let profileDescription: ProfileDescription?
    public let revisionDescription: RevisionDescription?
}

/// `<fileDesc>` — full bibliographic description of the file.
public struct FileDescription: Sendable {
    public let titleStatement: TitleStatement
    public let publicationStatement: PublicationStatement
    public let sourceDescription: SourceDescription?
}

/// `<titleStmt>` — groups information about the title of the work.
public struct TitleStatement: Sendable {
    /// All `<title>` children. The first without a `@level` or with `@level="m"` is the main title.
    public let titles: [Title]
    /// `<editor>` elements.
    public let editors: [Editor]
    /// `<principal>` elements.
    public let principals: [ResponsibilityStatement]
    /// `<respStmt>` elements.
    public let responsibilityStatements: [ResponsibilityStatement]
}

/// `<title>` element.
public struct Title: Sendable {
    /// `@level` attribute: `"m"` (monograph), `"s"` (series), `"a"` (article), etc.
    public let level: String?
    /// `@type` attribute: `"complete"`, `"short"`, `"sub"`, etc.
    public let type: String?
    /// `@xml:lang` attribute.
    public let lang: String?
    public let text: String
}

/// `<editor>` element.
public struct Editor: Sendable {
    /// `@role` attribute: `"primary"`, `"general"`, etc.
    public let role: String?
    public let name: String
}

/// `<respStmt>` or `<principal>` element.
public struct ResponsibilityStatement: Sendable {
    public let responsibility: String?
    public let names: [String]
}

/// `<publicationStmt>` — publication details.
public struct PublicationStatement: Sendable {
    public let publisher: String?
    public let pubPlace: String?
    public let date: String?
    public let idnos: [Identifier]
    public let availability: String?
}

/// `<idno>` element — any kind of formal identifier.
public struct Identifier: Sendable {
    /// `@type` attribute: `"isbn"`, `"issn"`, `"frus"`, etc.
    public let type: String?
    public let value: String
}

/// `<sourceDesc>` — source from which the text was derived.
public struct SourceDescription: Sendable {
    public let note: String?
}

/// `<encodingDesc>` — relationship between the electronic text and its source.
public struct EncodingDescription: Sendable {
    public let projectDescription: String?
    public let editorialDeclarations: [String]
}

/// `<profileDesc>` — non-bibliographic aspects of the text.
public struct ProfileDescription: Sendable {
    public let langUsage: [Language]
    public let textClass: TextClass?
    public let particDesc: ParticipantDescription?
}

/// `<language>` inside `<langUsage>`.
public struct Language: Sendable {
    /// `@ident` attribute (BCP 47 tag), e.g. `"en"`.
    public let ident: String
    public let description: String?
}

/// `<textClass>` — classification of the text.
public struct TextClass: Sendable {
    public let keywords: [String]
}

/// `<particDesc>` — participants / persons mentioned in the text.
public struct ParticipantDescription: Sendable {
    public let persons: [PersonRecord]
}

/// `<person>` in `<particDesc>` — a named individual.
public struct PersonRecord: Sendable {
    /// `@xml:id` attribute.
    public let id: String?
    /// `<persName>` children.
    public let names: [String]
    /// `<note>` children.
    public let notes: [String]
}

/// `<revisionDesc>` — history of changes.
public struct RevisionDescription: Sendable {
    public let changes: [Change]
}

/// `<change>` inside `<revisionDesc>`.
public struct Change: Sendable {
    public let when: String?
    public let who: String?
    public let description: String
}

// MARK: - TEI Text

/// `<text>` — the textual content of the volume.
public struct TEIText: Sendable {
    /// Front matter: `<front>`.
    public let front: FrontMatter?
    /// Body: `<body>`.
    public let body: Body
    /// Back matter: `<back>`.
    public let back: BackMatter?
}

// MARK: - Front Matter

/// `<front>` — front matter (preface, sources, abbreviations, etc.).
public struct FrontMatter: Sendable {
    public let divisions: [Division]
}

// MARK: - Back Matter

/// `<back>` — back matter (appendices, indexes, etc.).
public struct BackMatter: Sendable {
    public let divisions: [Division]
}

// MARK: - Body & Division Hierarchy

/// `<body>` — the main textual content.
public struct Body: Sendable {
    /// Top-level `<div>` elements (typically compilations or chapters).
    public let divisions: [Division]
}

/// `<div>` — a structural subdivision of the text.
///
/// FRUS uses a nested `<div>` hierarchy:
/// - `type="compilation"` — a thematic compilation
/// - `type="chapter"` — a chapter within a compilation
/// - `type="document"` — an individual diplomatic document
/// - `type="section"` — a named section (preface, sources, persons, terms, index, appendix, …)
public struct Division: Sendable {
    /// `@xml:id` attribute.
    public let id: String?
    /// `@type` attribute: `"compilation"`, `"chapter"`, `"document"`, `"section"`, etc.
    public let type: DivisionType?
    /// `@n` attribute — document number.
    public let number: String?
    /// `@subtype` attribute.
    public let subtype: String?
    /// `<head>` children — headings.
    public let headings: [Heading]
    /// `<dateline>` — date/place header for a document.
    public let dateline: Dateline?
    /// `<opener>` — opening of a letter/document.
    public let opener: Opener?
    /// `<closer>` — closing of a letter/document.
    public let closer: Closer?
    /// `<p>` children — body paragraphs.
    public let paragraphs: [Paragraph]
    /// `<note>` children that are direct children of this div (editorial notes).
    public let notes: [Note]
    /// Nested `<div>` children.
    public let children: [Division]
}

/// Controlled vocabulary for `<div @type>` in FRUS.
public enum DivisionType: String, Sendable, CaseIterable {
    case compilation
    case chapter
    case document
    case section
    case preface
    case sources
    case persons
    case terms
    case index
    case appendix
    case other
}

// MARK: - Document-Level Inline Elements

/// `<head>` — a heading.
public struct Heading: Sendable {
    /// `@type` attribute.
    public let type: String?
    public let content: [InlineContent]
}

/// `<dateline>` — date and place of creation of a document.
public struct Dateline: Sendable {
    public let content: [InlineContent]
    /// Convenience: all `<date>` children.
    public let dates: [DateElement]
    /// Convenience: all `<placeName>` children.
    public let placeNames: [PlaceName]
}

/// `<opener>` — salutation and related matter at the start of a letter.
public struct Opener: Sendable {
    public let salute: String?
    public let content: [InlineContent]
}

/// `<closer>` — salutation and valediction at the close of a letter.
public struct Closer: Sendable {
    public let salute: String?
    public let signed: String?
    public let content: [InlineContent]
}

/// `<p>` — a paragraph.
public struct Paragraph: Sendable {
    /// `@xml:id` attribute.
    public let id: String?
    /// `@rend` attribute — rendering hint.
    public let rend: String?
    public let content: [InlineContent]
}

/// `<note>` — a footnote or editorial annotation.
public struct Note: Sendable {
    /// `@xml:id` attribute.
    public let id: String?
    /// `@type` attribute: `"footnote"`, `"editorial"`, `"source"`, etc.
    public let type: String?
    /// `@n` attribute — displayed note marker.
    public let n: String?
    /// `@place` attribute: `"bottom"`, `"end"`, `"inline"`, etc.
    public let place: String?
    public let paragraphs: [Paragraph]
    public let content: [InlineContent]
}

// MARK: - Inline Content

/// Mixed inline content that can appear inside `<p>`, `<head>`, `<dateline>`, etc.
public indirect enum InlineContent: Sendable {
    /// Plain text node.
    case text(String)
    /// `<persName>` — a personal name.
    case persName(PersonName)
    /// `<placeName>` — a place name.
    case placeName(PlaceName)
    /// `<orgName>` — an organisation name.
    case orgName(OrgName)
    /// `<date>` — a date.
    case date(DateElement)
    /// `<ref>` or `<xRef>` — a cross-reference or hyperlink.
    case ref(Reference)
    /// `<hi>` — highlighted / formatted text.
    case hi(HighlightedText)
    /// `<term>` — a term or abbreviation.
    case term(Term)
    /// `<note>` — an inline footnote.
    case note(Note)
    /// `<pb>` — a page break.
    case pageBreak(PageBreak)
    /// `<lb>` — a line break.
    case lineBreak
    /// `<list>` — a list.
    case list(XMLList)
    /// `<table>` — a table.
    case table(Table)
    /// Any other element preserved as raw XML text for forward compatibility.
    case unknown(elementName: String, rawContent: String)
}

/// `<persName>` — personal name.
public struct PersonName: Sendable {
    /// `@corresp` / `@ref` attribute — pointer to person record in `<particDesc>`.
    public let ref: String?
    /// `@role` attribute.
    public let role: String?
    public let text: String
}

/// `<placeName>` — place name.
public struct PlaceName: Sendable {
    /// `@corresp` / `@ref` attribute.
    public let ref: String?
    public let text: String
}

/// `<orgName>` — organisation name.
public struct OrgName: Sendable {
    /// `@corresp` / `@ref` attribute.
    public let ref: String?
    public let text: String
}

/// `<date>` — a date expression.
public struct DateElement: Sendable {
    /// `@when` attribute — ISO 8601.
    public let when: String?
    /// `@from` attribute.
    public let from: String?
    /// `@to` attribute.
    public let to: String?
    /// `@notBefore` attribute.
    public let notBefore: String?
    /// `@notAfter` attribute.
    public let notAfter: String?
    public let text: String

    /// Convenience: parse `@when` as a `Date`. Returns `nil` if not present or unparseable.
    public var date: Date? {
        guard let when else { return nil }
        let fmts = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]
        for fmt in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let d = df.date(from: when) { return d }
        }
        return nil
    }
}

/// `<ref>` or `<xRef>` — a cross-reference.
public struct Reference: Sendable {
    /// `@target` attribute — URI or `xml:id` pointer.
    public let target: String?
    /// `@type` attribute.
    public let type: String?
    public let text: String
}

/// `<hi>` — highlighted/emphasised text.
public struct HighlightedText: Sendable {
    /// `@rend` attribute: `"italic"`, `"bold"`, `"smallcaps"`, `"underline"`, etc.
    public let rend: String?
    public let content: [InlineContent]
}

/// `<term>` — a defined term or abbreviation.
public struct Term: Sendable {
    /// `@ref` or `@corresp` attribute — pointer into the terms glossary.
    public let ref: String?
    public let text: String
}

/// `<pb>` — a page break (encoded as an empty element).
public struct PageBreak: Sendable {
    /// `@xml:id` attribute.
    public let id: String?
    /// `@n` attribute — the page number on the printed page.
    public let n: String?
    /// `@facs` attribute — URI of a page image.
    public let facs: String?
}

/// `<list>` — a structured list.
public struct XMLList: Sendable {
    /// `@type` attribute: `"ordered"`, `"unordered"`, `"gloss"`, etc.
    public let type: String?
    public let items: [ListItem]
}

/// `<item>` inside a `<list>`.
public struct ListItem: Sendable {
    public let content: [InlineContent]
}

/// `<table>` — a table.
public struct Table: Sendable {
    public let rows: [TableRow]
}

/// `<row>` in a `<table>`.
public struct TableRow: Sendable {
    /// `@role` attribute: `"label"`, `"data"`, etc.
    public let role: String?
    public let cells: [TableCell]
}

/// `<cell>` in a `<row>`.
public struct TableCell: Sendable {
    /// `@role` attribute.
    public let role: String?
    /// `@cols` attribute — column span.
    public let cols: Int?
    /// `@rows` attribute — row span.
    public let rows: Int?
    public let content: [InlineContent]
}
