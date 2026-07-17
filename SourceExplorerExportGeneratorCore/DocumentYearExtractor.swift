// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentYearExtractor

/// Extracts each document's coverage year from a volume's TEI: the leading four digits of the
/// authoritative `frus:doc-dateTime-min` attribute on `<div type="document">`, keyed by the
/// div's `xml:id`.
///
/// The attribute is read by its qualified name exactly as `XMLParser` reports it with
/// namespace processing off (`"frus:doc-dateTime-min"`), the same convention
/// `AdministrationProfilesIndexGeneratorCore.DocumentDateExtractor` documents — that extractor
/// returns bare dates without ids, which is why the export needs this id-keyed twin.
///
/// A full div stack is tracked so only OUTERMOST document divs record a year (FRUS never
/// nests document divs, but the stack keeps the mapping stable — and depth accounting
/// correct — for any nesting of non-document divs inside a document).
///
/// Version history:
///   1.0 — #335: initial implementation
public final class DocumentYearExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Extracted `documentId → year` (documents with no id or no parseable year omitted).
    private var years: [String: Int] = [:]
    /// One entry per open `<div>`: `true` when that div is a document div.
    private var divStack: [Bool] = []

    /// Extracts the `documentId → coverage year` map from a volume's TEI XML.
    public static func extract(fromXML data: Data) -> [String: Int] {
        let delegate = DocumentYearExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.years
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                       namespaceURI: String?, qualifiedName qName: String?,
                       attributes attributeDict: [String: String]) {
        guard elementName == "div" else { return }
        let isDocument = attributeDict["type"]?.lowercased() == "document"
        // Record only when no enclosing document div is already open (outermost wins).
        if isDocument, !divStack.contains(true),
           let id = attributeDict["xml:id"], !id.isEmpty,
           let minDate = attributeDict["frus:doc-dateTime-min"], minDate.count >= 4,
           let year = Int(minDate.prefix(4)) {
            years[id] = year
        }
        divStack.append(isDocument)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                       namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "div", !divStack.isEmpty {
            divStack.removeLast()
        }
    }
}
