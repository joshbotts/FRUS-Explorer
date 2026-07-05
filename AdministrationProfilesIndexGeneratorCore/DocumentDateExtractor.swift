// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A single FRUS document's extracted date, classified for administration attribution.
///
/// Mirrors the classification `IndexingPipeline.extractDateRange` produces from the same
/// authoritative source (`frus:doc-dateTime-min`/`-max` on the document `<div>`): a
/// document whose interval collapses to one calendar day is a **point** date; one that
/// spans multiple days is a **range** (chiefly editorial notes, but also multi-day
/// historical documents); a document with neither is **undated**.
public enum DocumentDate: Equatable, Sendable {
    /// A single resolvable calendar date (`yyyy-MM-dd`). Attributed to the one
    /// administration whose half-open interval contains it.
    case point(String)
    /// A date range `[start, end]` (both `yyyy-MM-dd`, inclusive). Attributed by
    /// any-overlap to every administration whose interval intersects it.
    case range(start: String, end: String)
    /// No resolvable date. Counted but attributed to no administration.
    case undated
}

/// Extracts one `DocumentDate` per FRUS document (`<div type="document">`) from a
/// volume's TEI XML.
///
/// **How this mirrors `IndexingPipeline`.** The app's `IndexingPipeline.extractDateRange`
/// prefers the authoritative `frus:doc-dateTime-min`/`-max` attributes the HistoryAtState
/// `update-frus-doc-dates.xsl` pipeline stamps on each document `<div>` (the editors'
/// curated date assessment), falling back to descending the parsed AST's `<dateline>`
/// `<date>` nodes only for volumes that pre-date that pipeline. Across the 694-volume
/// corpus **every** volume that contains `type="document"` divs carries these attributes;
/// the 141 volumes without them are unpublished stubs / index volumes with no document
/// bodies. This extractor therefore reads the same authoritative attributes directly at
/// the XML level (no AST needed): it takes the `yyyy-MM-dd` prefix of `-min` and `-max`
/// (the leading-four-digits / ISO-prefix convention used across the app), and classifies
/// point vs. range by whether the two days are equal — exactly the min/max collapse
/// `extractDateRange` yields.
///
/// Version history:
///   1.0 — SA-2a (Session 2026-07-05): initial implementation
public final class DocumentDateExtractor: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Extracts one `DocumentDate` per document div, in document order.
    ///
    /// - Parameter data: The raw TEI XML bytes.
    /// - Returns: One `DocumentDate` per `<div type="document">`.
    public static func extract(fromXML data: Data) -> [DocumentDate] {
        let delegate = DocumentDateExtractor()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.dates
    }

    private var dates: [DocumentDate] = []

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        // A FRUS document is `<div type="document">`. The `qName` carries the raw element
        // name; `type` is unprefixed, `frus:doc-dateTime-*` is prefixed. `XMLParser` with
        // namespace processing off (the default) reports keys verbatim as written.
        guard localName(elementName, qName) == "div",
              attributeDict["type"] == "document" else { return }

        dates.append(Self.classify(
            min: attributeDict["frus:doc-dateTime-min"],
            max: attributeDict["frus:doc-dateTime-max"]))
    }

    /// Classifies a document's raw `doc-dateTime-min`/`-max` attribute values into a
    /// `DocumentDate`.
    ///
    /// Takes the `yyyy-MM-dd` prefix of each timestamp. Point when both resolve to the
    /// same day; range when they differ; undated when neither yields a day. A lone `-min`
    /// (or lone `-max`) with no partner is treated as a point date on that day.
    ///
    /// - Parameters:
    ///   - min: The raw `frus:doc-dateTime-min` value (e.g. `1945-04-12T00:00:00-05:00`).
    ///   - max: The raw `frus:doc-dateTime-max` value.
    /// - Returns: The classified `DocumentDate`.
    static func classify(min: String?, max: String?) -> DocumentDate {
        let minDay = day(from: min)
        let maxDay = day(from: max)
        switch (minDay, maxDay) {
        case let (m?, x?):
            return m == x ? .point(m) : .range(start: Swift.min(m, x), end: Swift.max(m, x))
        case let (m?, nil):
            return .point(m)
        case let (nil, x?):
            return .point(x)
        case (nil, nil):
            return .undated
        }
    }

    /// Extracts the `yyyy-MM-dd` prefix of an ISO timestamp, or `nil` when the string does
    /// not begin with a four-digit year.
    static func day(from iso: String?) -> String? {
        guard let iso, iso.count >= 10 else {
            // Accept a bare four-digit year too, padding to Jan 1 (matches the app's
            // `normalizeToFullDate` earliest-in-period convention).
            if let iso, iso.count >= 4 {
                let y = iso.prefix(4)
                if y.allSatisfy(\.isNumber) { return "\(y)-01-01" }
            }
            return nil
        }
        let prefix = iso.prefix(10)
        // yyyy-MM-dd shape check: digits at 0-3, 5-6, 8-9; hyphens at 4, 7.
        let chars = Array(prefix)
        guard chars[0].isNumber, chars[1].isNumber, chars[2].isNumber, chars[3].isNumber,
              chars[4] == "-", chars[5].isNumber, chars[6].isNumber,
              chars[7] == "-", chars[8].isNumber, chars[9].isNumber else {
            // Fall back to a bare year prefix if present.
            let y = prefix.prefix(4)
            if y.allSatisfy(\.isNumber) { return "\(y)-01-01" }
            return nil
        }
        return String(prefix)
    }

    /// Returns the local (unprefixed) element name from the parser's reported name.
    ///
    /// With namespace processing off, `XMLParser` reports the qualified name; this strips
    /// any `prefix:` so `tei:div` and `div` both match.
    private func localName(_ elementName: String, _ qName: String?) -> String {
        let name = qName ?? elementName
        if let colon = name.lastIndex(of: ":") {
            return String(name[name.index(after: colon)...])
        }
        return name
    }
}
