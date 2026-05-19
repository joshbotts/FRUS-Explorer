// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Errors thrown by `TEIHeaderParser`.
public enum TEIHeaderParserError: Error, Sendable {
    case xmlParseError(String)
}

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
/// | `//publicationStmt/date` | `publicationDate` |
/// | `//profileDesc/creation/date[@from][@to]` | `earliestDate`, `latestDate` |
/// | `//keywords[@scheme="https://history.state.gov/tags"]/term` | `tags` |
///
/// `documentCount` is always 0 — it cannot be determined from the header alone.
///
/// Version history:
///   1.0 — Session 02: initial implementation
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
            // Date range: prefer @from/@to; fall back to @notBefore/@notAfter.
            if let from = attributes["from"] { result.earliestDate = from }
            if let to = attributes["to"] { result.latestDate = to }
            if result.earliestDate == nil, let nb = attributes["notBefore"] { result.earliestDate = nb }
            if result.latestDate == nil, let na = attributes["notAfter"] { result.latestDate = na }

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

        case "date" where parent == "publicationStmt":
            // Prefer @when attribute — it reliably encodes the publication year as ISO 8601
            // and is unambiguous. Text content may contain prose descriptions or coverage
            // year ranges (e.g. "1969–1976") that are not the print year.
            if let when = attrs["when"], !when.isEmpty {
                result.publicationDate = when
            } else if !text.isEmpty {
                result.publicationDate = text
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
}
