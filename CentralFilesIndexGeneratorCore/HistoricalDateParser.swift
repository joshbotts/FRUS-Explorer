// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DateRangeISO

/// An inclusive date range parsed from a roll/file-unit title, as ISO `yyyy-MM-dd`
/// strings. Either endpoint may be `nil` when the title carries only one date.
public struct DateRangeISO: Sendable, Equatable {
    /// Start date, `yyyy-MM-dd`, or `nil`.
    public let startISO: String?
    /// End date, `yyyy-MM-dd`, or `nil`.
    public let endISO: String?
    /// `false` when a parsed year fell outside the plausible band (1780–1915) — a likely
    /// catalog typo (e.g. "1675" for "1875"). The value is still emitted; the flag is for
    /// the survey. A too-wide range never causes a missed lookup, only a looser match.
    public let plausible: Bool

    public init(startISO: String?, endISO: String?, plausible: Bool) {
        self.startISO = startISO
        self.endISO = endISO
        self.plausible = plausible
    }
}

// MARK: - HistoricalDateParser

/// Parses the human date ranges in NARA roll/file-unit titles into ISO date ranges.
///
/// Handles the forms seen in the diplomatic-series titles:
/// - `Aug. 17, 1861 - Sept. 2, 1863` (abbreviated months, spaces around the dash)
/// - `Apr. 19, 1893-Mar. 28, 1896` (no spaces)
/// - `July 2, 1675-Dec. 18, 1876` (a catalog year typo — flagged not-plausible)
/// - `Mar. 4, 1905-Aug. 31, 1905`, `July 7, 1834 - June 26, 1906`
/// - a single date (`September 28, 1875`) or a bare year (`1906`)
///
/// Separators include the dash family plus the Unicode replacement character and
/// underscore (corrupted en-dashes seen in the Numerical File harvest).
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 — diplomatic-series date ranges
public enum HistoricalDateParser {

    /// Plausible year band for pre-1910 Central Files titles. Years outside flag a typo.
    static let plausibleYears = 1780...1915

    private static let separators = CharacterSet(charactersIn: "-–—‐\u{FFFD}_")

    /// Parses a date range (or single date) from `text`. Returns `nil` only when no year
    /// can be found at all (after correction and year-sharing).
    public static func parse(_ text: String) -> DateRangeISO? {
        let (lhs, rhs) = splitOnSeparator(text)

        var start = parseComponents(lhs)
        var end = rhs.flatMap(parseComponents)

        // Year-sharing: a day-range roll like "Apr. 16-Aug. 23, 1881" gives the year only
        // on one side — borrow it for the other.
        if start?.year == nil, let y = end?.year { start?.year = y }
        if end?.year == nil, let y = start?.year { end?.year = y }

        let startISO = start?.iso()
        let endISO = end?.iso()

        if rhs == nil {
            guard let startISO else { return nil }
            return DateRangeISO(startISO: startISO, endISO: nil, plausible: start?.plausible ?? true)
        }
        guard startISO != nil || endISO != nil else { return nil }
        let plausible = (start?.plausible ?? true) && (end?.plausible ?? true)
        return DateRangeISO(startISO: startISO, endISO: endISO, plausible: plausible)
    }

    // MARK: - Range splitting

    /// Splits on the first separator that sits *between two dates* (so the hyphen inside a
    /// single date like a future `2-3` day form is not mistaken for a range divider). In
    /// practice titles use ` - ` / `-` between full dates; we split on the first separator
    /// that has a digit on both sides at some distance.
    private static func splitOnSeparator(_ text: String) -> (lhs: String, rhs: String?) {
        // Find the last separator: month-day-year ranges never contain an internal dash,
        // so the (single) separator divides the two dates. Using the last occurrence is
        // robust to a stray leading dash.
        let scalars = Array(text.unicodeScalars)
        var splitIndex: Int? = nil
        for i in stride(from: scalars.count - 1, through: 0, by: -1) where separators.contains(scalars[i]) {
            // Require a digit somewhere before and after to avoid splitting trailing junk.
            let before = scalars[..<i].contains { CharacterSet.decimalDigits.contains($0) }
            let after = scalars[(i + 1)...].contains { CharacterSet.decimalDigits.contains($0) }
            if before && after { splitIndex = i; break }
        }
        guard let idx = splitIndex else {
            return (text.trimmingCharacters(in: .whitespaces), nil)
        }
        let lhs = String(String.UnicodeScalarView(scalars[..<idx])).trimmingCharacters(in: .whitespaces)
        let rhs = String(String.UnicodeScalarView(scalars[(idx + 1)...])).trimmingCharacters(in: .whitespaces)
        return (lhs, rhs.isEmpty ? nil : rhs)
    }

    // MARK: - Single date (component-based)

    /// Partially-parsed date components. `year` may be filled in later by year-sharing.
    private struct DateComponents {
        var month: Int?
        var day: Int?
        var year: Int?

        /// Whether the (corrected) year sits in the plausible band.
        var plausible: Bool { year.map(plausibleYears.contains) ?? true }

        /// ISO `yyyy-MM-dd`, defaulting a missing month/day to January 1. `nil` without a year.
        func iso() -> String? {
            guard let year else { return nil }
            return String(format: "%04d-%02d-%02d", year, month ?? 1, min(max(day ?? 1, 1), 31))
        }
    }

    // Tried in priority order; each may leave fields nil.
    private static let monthDayYear = try? NSRegularExpression(pattern: #"([A-Za-z]+)\.?\s+(\d{1,2})\s*,?\s*(\d{4})"#)
    private static let monthYear    = try? NSRegularExpression(pattern: #"([A-Za-z]+)\.?\s+(\d{4})"#)
    private static let monthDay     = try? NSRegularExpression(pattern: #"([A-Za-z]+)\.?\s+(\d{1,2})\b"#)
    private static let yearOnly     = try? NSRegularExpression(pattern: #"(\d{4})"#)

    /// Parses a single date side into components. Applies the `16xx`→`18xx` OCR correction.
    private static func parseComponents(_ text: String) -> DateComponents? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        if let m = monthDayYear?.firstMatch(in: text, range: full),
           let month = monthNumber(ns.substring(with: m.range(at: 1))) {
            return DateComponents(month: month, day: Int(ns.substring(with: m.range(at: 2))),
                                  year: correctYear(Int(ns.substring(with: m.range(at: 3)))))
        }
        if let m = monthYear?.firstMatch(in: text, range: full),
           let month = monthNumber(ns.substring(with: m.range(at: 1))) {
            return DateComponents(month: month, day: nil,
                                  year: correctYear(Int(ns.substring(with: m.range(at: 2)))))
        }
        if let m = monthDay?.firstMatch(in: text, range: full),
           let month = monthNumber(ns.substring(with: m.range(at: 1))) {
            return DateComponents(month: month, day: Int(ns.substring(with: m.range(at: 2))), year: nil)
        }
        if let m = yearOnly?.firstMatch(in: text, range: full) {
            return DateComponents(month: nil, day: nil, year: correctYear(Int(ns.substring(with: m.range(at: 1)))))
        }
        return nil
    }

    /// Corrects the dominant catalog OCR error in these 1780–1906 series: a `16xx`/`15xx`
    /// year (the "18"/"17" prefix misread) is shifted up by 200 (1675→1875, 1656→1856).
    /// Years already in or above the plausible band are left untouched.
    static func correctYear(_ year: Int?) -> Int? {
        guard let year else { return nil }
        return year < plausibleYears.lowerBound ? year + 200 : year
    }

    /// Maps a full or abbreviated month name to 1–12. Handles `Sept` and common forms.
    static func monthNumber(_ name: String) -> Int? {
        let key = name.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch key {
        case "jan", "january":              return 1
        case "feb", "february":             return 2
        case "mar", "march":                return 3
        case "apr", "april":                return 4
        case "may":                         return 5
        case "jun", "june":                 return 6
        case "jul", "july":                 return 7
        case "aug", "august":               return 8
        case "sep", "sept", "september":    return 9
        case "oct", "october":              return 10
        case "nov", "november":             return 11
        case "dec", "december":             return 12
        default:                            return nil
        }
    }
}
