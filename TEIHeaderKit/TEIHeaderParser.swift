// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `TEIHeaderParser`.
/// Parses the `<teiHeader>` of a FRUS TEI XML file into a `ParsedTEIHeader`.
///
/// Uses Foundation's `XMLParser` in SAX (streaming) mode. The parser is fed the
/// raw bytes returned by `TEIHeaderFetcher`, which end with `</teiHeader></TEI>`.
///
/// ## Extracted Fields
///
/// | TEI Path | Field |
/// |----------|-------|
/// | `//titleStmt/title[@type="complete"]` | `title` |
/// | `//titleStmt/editor` (non-general) | `editors` |
/// | `//titleStmt/editor[@role="general"]` | `generalEditor` |
/// | `//publicationStmt/date[@type="publication-date"]` (TEXT), else untyped `//publicationStmt/date` (TEXT) | `publicationDate` |
/// | `//publicationStmt/date[@type="content-date"][@notBefore][@notAfter]` | `earliestDate`, `latestDate` |
/// | `//profileDesc/creation/date[@from][@to]` (fallback `@notBefore`/`@notAfter`) | `earliestDate`, `latestDate` |
/// | `//keywords[@scheme="https://history.state.gov/tags"]/term` | `tags` |
///
/// ### Date semantics
/// - `publicationDate` is the historical **print year** — the *text content* of the
///   `publicationStmt/date[@type="publication-date"]` element (e.g. `"1861"`). It is
///   NOT the digital `@when` timestamp (a 2010–2025 build stamp on sibling `<bibl>`
///   elements) and NOT the coverage range. The 10 oldest volumes (1860s Civil War era,
///   e.g. `frus1862`, `frus1865p1`) instead carry an **empty self-closing**
///   `date[@type="publication-date"]` `@when` build stamp and place the real print year
///   on a sibling **untyped** `publicationStmt/date` (e.g. `<date calendar="gregorian">1862</date>`);
///   the parser falls back to that untyped element's text when the typed one is empty.
///   In-progress modern volumes carry an empty `publication-date` and no untyped print
///   year, which yields `publicationDate == nil`.
/// - `earliestDate`/`latestDate` are the **coverage range**, taken from the
///   `@notBefore`/`@notAfter` attributes of `publicationStmt/date[@type="content-date"]`
///   when present, else from `profileDesc/creation/date` (`@from`/`@to`, falling back to
///   `@notBefore`/`@notAfter`). The human-readable range TEXT (e.g. `"1860 to 1861"`) is
///   never parsed for the range; only attributes are used.
///
/// `documentCount` is always 0 — it cannot be determined from the header alone.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — SA-1a: publicationDate = publication-date TEXT only (no `@when`, no content-date);
///         coverage range now also read from content-date `@notBefore`/`@notAfter`.
///   1.2 — SA-1a (review fix): fall back to an untyped `publicationStmt/date` text for the
///         print year when the typed `publication-date` element is empty (the legacy encoding
///         used by the 10 oldest 1860s volumes), still never taking `@when` or content-date.
public struct TEIHeaderParser {

    private init() {}

    /// Parses FRUS TEI header XML data into a `ParsedTEIHeader`.
    ///
    /// - Parameter data: XML bytes ending with `</teiHeader></TEI>` as produced by
    ///   `TEIHeaderFetcher.fetch(from:session:)`.
    /// - Returns: Extracted header metadata.
    /// - Throws: `TEIHeaderParserError` if the XML is malformed.
    public static func parse(_ data: Data) throws -> ParsedTEIHeader {
        let delegate = TEIHeaderParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            let errorDescription = parser.parserError?.localizedDescription ?? "unknown XML error"
            throw TEIHeaderParserError.xmlParseError(errorDescription)
        }

        return delegate.result
    }
}

// MARK: - XMLParser Delegate

/// SAX delegate that accumulates metadata while walking the TEI element tree.
///
/// Marked `@unchecked Sendable` because it is created, used, and discarded within a single
/// synchronous call to `XMLParser.parse()` — it never crosses a concurrency boundary.
///
/// Version history:
///   1.0 — Session 02: initial implementation
final class TEIHeaderParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: - Accumulated Result

    private(set) var result = ParsedTEIHeader()

    // MARK: - Parser State

    private var elementStack: [String] = []
    private var attributeStack: [[String: String]] = []
    private var characterBuffer = ""

    // Flags
    private var inTagsKeywords = false
    private var bestTitleType = ""   // track which title type we've captured

    // Print-year resolution: the typed `publication-date` element always wins. When it is
    // empty/self-closing (the 10 oldest volumes), fall back to the text of an untyped
    // `publicationStmt/date` element. `sawTypedPublicationDate` locks out the fallback once a
    // typed publication-date has supplied a non-empty year, so a later untyped sibling cannot
    // override it and the ordering of siblings within publicationStmt does not matter.
    private var sawTypedPublicationDate = false
    private var untypedPublicationYearCandidate: String?

    // MARK: - Convenience

    private var depth: Int { elementStack.count }

    /// The name of the direct parent of the currently-open (or just-closed) element.
    private func parentName() -> String? {
        guard depth >= 2 else { return nil }
        return elementStack[depth - 2]
    }

    /// Returns `true` if the element path contains `ancestor` at any depth.
    private func hasAncestor(_ ancestor: String) -> Bool {
        elementStack.dropLast().contains(ancestor)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName _: String?,
        attributes: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        attributeStack.append(attributes)
        characterBuffer = ""

        switch elementName {
        case "date" where hasAncestor("creation"):
            // Coverage range from profileDesc/creation/date: prefer @from/@to; fall back to
            // @notBefore/@notAfter. This is the historical fallback source; modern volumes
            // instead carry the range on publicationStmt/date[@type="content-date"] (below).
            if let from = attributes["from"] { result.earliestDate = from }
            if let to = attributes["to"] { result.latestDate = to }
            if result.earliestDate == nil, let nb = attributes["notBefore"] { result.earliestDate = nb }
            if result.latestDate == nil, let na = attributes["notAfter"] { result.latestDate = na }

        case "date" where parentName() == "publicationStmt" && attributes["type"] == "content-date":
            // Coverage range carried on the content-date element via @notBefore/@notAfter.
            // Precedence: content-date wins over creation when both supply a bound, since it is
            // the authoritative range on every current FRUS volume. The human-readable TEXT of
            // this element (e.g. "1860 to 1861") is intentionally NOT parsed for the range.
            if let nb = attributes["notBefore"] { result.earliestDate = nb }
            if let na = attributes["notAfter"] { result.latestDate = na }

        case "keywords":
            inTagsKeywords = (attributes["scheme"] == "https://history.state.gov/tags")

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName _: String?
    ) {
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let attrs = attributeStack.last ?? [:]
        let parent = parentName()

        // Pop before processing to ensure depth reflects the closed element's parent.
        elementStack.removeLast()
        attributeStack.removeLast()
        characterBuffer = ""

        switch elementName {
        case "title" where parent == "titleStmt":
            let titleType = attrs["type"] ?? ""
            // Prefer type="complete"; accept any title as a fallback.
            if titleType == "complete" {
                result.title = text
                bestTitleType = "complete"
            } else if bestTitleType != "complete" && !text.isEmpty {
                result.title = text
                bestTitleType = titleType
            }

        case "editor" where parent == "titleStmt":
            guard !text.isEmpty else { break }
            let role = attrs["role"] ?? ""
            if role == "general" {
                result.generalEditor = text
            } else {
                result.editors.append(text)
            }

        case "date" where parent == "publicationStmt" && attrs["type"] == "publication-date":
            // Print year: ONLY the TEXT content of the publication-date element (e.g. "1861").
            // Never the digital @when timestamp (a build stamp on sibling <bibl> elements) and
            // never the content-date range. An empty / self-closing publication-date leaves the
            // typed year unset; the untyped fallback below may then supply it (10 oldest volumes).
            // characterBuffer already isolates this element's own text, so sibling <idno> text
            // cannot bleed in.
            if !text.isEmpty {
                result.publicationDate = text
                sawTypedPublicationDate = true
            }

        case "date" where parent == "publicationStmt" && attrs["type"] == nil:
            // Legacy print-year encoding (10 oldest 1860s volumes): the real print year lives on
            // an untyped <date calendar="gregorian">YEAR</date> sibling while the typed
            // publication-date is an empty @when build stamp. Record it as a fallback candidate;
            // it is applied at endDocument only if no typed publication-date supplied a year.
            // Untyped dates carrying @notBefore/@notAfter etc. are content-date rows handled above
            // (they have type="content-date"), so an untyped element with range attrs is not a
            // print year — but the pre-1866 print-year elements carry no range attrs, so a plain
            // text-only untyped date is the safe fallback.
            if !text.isEmpty, untypedPublicationYearCandidate == nil {
                untypedPublicationYearCandidate = text
            }

        case "term" where inTagsKeywords:
            if !text.isEmpty {
                result.tags.append(text)
            }

        case "keywords":
            inTagsKeywords = false

        default:
            break
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Apply the untyped print-year fallback only when no typed publication-date supplied a
        // year (the 10 oldest 1860s volumes). This runs after the whole header is walked so the
        // typed element always takes precedence regardless of sibling ordering.
        if !sawTypedPublicationDate, let candidate = untypedPublicationYearCandidate {
            result.publicationDate = candidate
        }
    }
}
