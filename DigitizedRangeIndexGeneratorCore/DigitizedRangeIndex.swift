// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DigitizedRange

/// One digitised NARA file unit, keyed by the decimal file range its title states (#663).
public struct DigitizedRange: Codable, Sendable, Equatable {
    /// The decimal class, lower-cased and dot-normalised (`763.72119`).
    public let decimalClass: String
    /// First and last document serial the file unit's title claims, inclusive.
    public let low: Int
    public let high: Int
    /// The file unit's NARA Archival Identifier.
    public let naId: String
    /// How many scanned images the unit holds — the "how long is this PDF" figure.
    public let objectCount: Int
    /// The scan's own URL on `catalog.archives.gov`, when the unit publishes one.
    public let objectUrl: String?
    /// The scan's filename, which names the microfilm publication and roll
    /// (`M367_Roll20.pdf`) — often the most legible thing about the record.
    public let objectFilename: String?
    /// The file unit's title, verbatim, so the UI can show NARA's own range rather than a
    /// reconstruction of it.
    public let title: String

    public init(decimalClass: String, low: Int, high: Int, naId: String, objectCount: Int,
                objectUrl: String?, objectFilename: String?, title: String) {
        self.decimalClass = decimalClass; self.low = low; self.high = high
        self.naId = naId; self.objectCount = objectCount
        self.objectUrl = objectUrl; self.objectFilename = objectFilename; self.title = title
    }
}

// MARK: - DigitizedRangeIndexFile

/// The bundled artifact: every digitised decimal-file range the harvest describes.
public struct DigitizedRangeIndexFile: Codable, Sendable {
    public let schemaVersion: Int
    public let generated: String
    /// The NARA series the ranges were harvested from, for provenance.
    public let seriesNaIds: [String]
    /// What the artifact deliberately does not cover, so a reader is not left to infer it.
    public let note: String
    public let ranges: [DigitizedRange]

    public init(schemaVersion: Int, generated: String, seriesNaIds: [String],
                note: String, ranges: [DigitizedRange]) {
        self.schemaVersion = schemaVersion; self.generated = generated
        self.seriesNaIds = seriesNaIds; self.note = note; self.ranges = ranges
    }
}

// MARK: - DigitizedRangeTitleParser

/// Reads a NARA file-unit title into the decimal range it states (#663).
///
/// ## What the titles look like, and what most of them are not
/// The digitised decimal series title their file units by the range of documents inside:
/// `763.72/1476-1635`, `131./1-423`, `763.72/1196a (Part1)`. Those parse.
///
/// **Most do not, and no parser fixes it.** Of the 4,247 digitised file units in the two decimal
/// series, **3,622 are name ranges** — `131/Abba-Abbi`, `131/ADAMS`, `131.Aa.5-131.Z9` — because
/// class 131 is the Visa Division's reports of births, filed by surname. A numeric FRUS citation
/// can never land in one. Widening the grammar to strip bracketed annotations, year
/// parentheticals, `(Part N)` suffixes and alphanumeric serials moved the parse rate from 13.8%
/// to **14.7%** and stopped there, which is the measurement that says the remainder is not a
/// parsing problem.
///
/// So the matchable population is **625 ranges across 18 classes**, and the index is small
/// because the data is, not because the parser is weak.
public enum DigitizedRangeTitleParser {

    private static let bracket = try! NSRegularExpression(pattern: #"\s*\[[^\]]*\]\s*$"#)
    private static let partTail = try! NSRegularExpression(pattern: #"(?i)\s*\(\s*part\s*\d+\s*\)\s*$"#)
    private static let yearParen = try! NSRegularExpression(pattern: #"\s*\(\s*\d{4}\s*\)\s*"#)

    /// A serial: digits, optionally an alphabetic suffix (`1196a`) and a fraction (`2140 1/2`).
    /// Only the leading digits order the interval; the suffix is display detail.
    private static let serial = #"(\d+)\s*[A-Za-z]?(?:\s*\d/\d)?"#

    private static let rangePattern = try! NSRegularExpression(
        pattern: #"^\s*([0-9][0-9A-Za-z.\-]*?)\.?\s*/?\s*"# + serial
               + #"\s*[-–—]\s*"# + serial + #"\s*$"#)
    private static let singlePattern = try! NSRegularExpression(
        pattern: #"^\s*([0-9][0-9A-Za-z.\-]*?)\.?\s*/\s*"# + serial + #"\s*$"#)

    /// Strips the annotations that ride along with a range without changing it.
    static func normalized(_ title: String) -> String {
        var s = title
        for regex in [bracket, partTail, yearParen] {
            s = regex.stringByReplacingMatches(
                in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The `(class, low, high)` a title states, or `nil` when it states no numeric range.
    public static func parse(_ title: String) -> (decimalClass: String, low: Int, high: Int)? {
        let s = normalized(title)
        let range = NSRange(s.startIndex..., in: s)
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            guard i < m.numberOfRanges, let r = Range(m.range(at: i), in: s) else { return nil }
            return String(s[r])
        }
        if let m = rangePattern.firstMatch(in: s, range: range),
           let cls = group(m, 1), let lo = group(m, 2).flatMap(Int.init),
           let hi = group(m, 3).flatMap(Int.init), lo <= hi {
            return (canonicalClass(cls), lo, hi)
        }
        if let m = singlePattern.firstMatch(in: s, range: range),
           let cls = group(m, 1), let one = group(m, 2).flatMap(Int.init) {
            return (canonicalClass(cls), one, one)
        }
        return nil
    }

    /// The class key both sides join on: lower-cased, with the leading/trailing dots the titles
    /// carry inconsistently (`131.` vs `131`) removed.
    public static func canonicalClass(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            .lowercased()
    }
}
