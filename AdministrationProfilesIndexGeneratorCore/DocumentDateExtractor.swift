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
///   1.1 — 2026-09-19 / #1326: reads each document's `<dateline>` `<date>` and takes the day from
///          it when the two name the same instant. The attribute alone put 11,847 documents on the
///          wrong day, two of which changed presidential administration in this very artifact —
///          `frus1923v02/d954` (Harding → Coolidge) and `frus1945v07/d55` (Roosevelt → Truman).
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

    /// The open document's raw attributes, held until its dateline has been seen (#1326).
    private var pendingMin: String?
    private var pendingMax: String?
    /// Whether a document div is open at all — a `<dateline>` outside one is not its.
    private var inDocument = false
    /// Depth inside the open document's `<dateline>`, so a `<date>` elsewhere is ignored.
    private var datelineDepth = 0
    /// The winning `<date>` attributes for the open document, in the app's own priority.
    private var datelineWhen: String?
    private var datelineFrom: String?
    private var datelineNotBefore: String?
    private var datelineTo: String?
    private var datelineNotAfter: String?
    private var anyWhen: String?

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        let name = localName(elementName, qName)

        // A FRUS document is `<div type="document">`. The `qName` carries the raw element
        // name; `type` is unprefixed, `frus:doc-dateTime-*` is prefixed. `XMLParser` with
        // namespace processing off (the default) reports keys verbatim as written.
        if name == "div", attributeDict["type"] == "document" {
            flushPendingDocument()
            inDocument = true
            pendingMin = attributeDict["frus:doc-dateTime-min"]
            pendingMax = attributeDict["frus:doc-dateTime-max"]
            return
        }

        guard inDocument else { return }
        if name == "dateline" { datelineDepth += 1; return }
        guard name == "date" else { return }
        if datelineDepth > 0 {
            if datelineWhen == nil { datelineWhen = attributeDict["when"] }
            if datelineFrom == nil { datelineFrom = attributeDict["from"] }
            if datelineNotBefore == nil { datelineNotBefore = attributeDict["notBefore"] }
            if datelineTo == nil { datelineTo = attributeDict["to"] }
            if datelineNotAfter == nil { datelineNotAfter = attributeDict["notAfter"] }
        }
        if anyWhen == nil { anyWhen = attributeDict["when"] }
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        guard inDocument, localName(elementName, qName) == "dateline", datelineDepth > 0 else {
            return
        }
        datelineDepth -= 1
    }

    public func parserDidEndDocument(_ parser: XMLParser) {
        flushPendingDocument()
    }

    /// Closes the open document, classifying it once its dateline has been read (#1326).
    ///
    /// Deferred to the NEXT document's start (or end of file) rather than done at
    /// `didStartElement`, because the `<date>` that decides the day sits INSIDE the div and has
    /// not been parsed yet when the div opens. Documents do not nest, so the next document's
    /// start is the current one's end for this purpose.
    private func flushPendingDocument() {
        guard inDocument else { return }
        dates.append(Self.classify(
            min: pendingMin, max: pendingMax,
            minAttribute: datelineWhen ?? datelineFrom ?? datelineNotBefore ?? anyWhen,
            maxAttribute: datelineTo ?? datelineNotAfter ?? datelineWhen ?? anyWhen))
        inDocument = false
        pendingMin = nil; pendingMax = nil
        datelineDepth = 0
        datelineWhen = nil; datelineFrom = nil; datelineNotBefore = nil
        datelineTo = nil; datelineNotAfter = nil; anyWhen = nil
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
    static func classify(min: String?, max: String?,
                         minAttribute: String? = nil, maxAttribute: String? = nil) -> DocumentDate {
        // #1326: `frus:doc-dateTime-*` is an INSTANT the corpus normalises to −05:00, so its
        // first ten characters are not the day the document is dated. Where the editors' own
        // `<date>` names the SAME INSTANT, its local rendering is the day they meant. This is the
        // rule `IndexingPipeline.sameInstantDay` applies, mirrored rather than shared because the
        // app target is not linkable from this package — the app's own tests pin the app side, and
        // `DocumentDateExtractorTests` pins this one against the same fixtures.
        let minDay = Self.sameInstantDay(instant: min, attribute: minAttribute) ?? day(from: min)
        let maxDay = Self.sameInstantDay(instant: max, attribute: maxAttribute) ?? day(from: max)
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

    /// The day an editors' `<date>` states, when it denotes the SAME INSTANT as the corpus's
    /// `frus:doc-dateTime-*` attribute — otherwise `nil` (#1326).
    ///
    /// Mirror of `IndexingPipeline.sameInstantDay`. Strict about the offset for the same reason:
    /// a value with no offset has no instant to compare, and reading it as UTC would make two
    /// different moments compare equal and move a day that must not move.
    static func sameInstantDay(instant: String?, attribute: String?) -> String? {
        guard let instant, let attribute,
              let a = isoInstant(instant), let b = isoInstant(attribute), a == b else { return nil }
        return day(from: attribute)
    }

    /// Parses an `xs:dateTime` carrying an explicit offset into an absolute instant, or `nil`.
    static func isoInstant(_ raw: String) -> Date? {
        guard raw.contains("T") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw)
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
