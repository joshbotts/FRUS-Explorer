// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Parses a State Department decimal file reference into the two parts that define an
/// archival neighborhood: the **location** (the decimal classification before the `/`) and
/// the **chronological segment** (the decimal-file filing period).
///
/// Two documents are decimal-file neighbors when they share both: same location *and* same
/// segment. The segment is derived from the year encoded in a date-form suffix
/// (`/11-543` → 1943), which the date system used from 1940 on; pre-1940 refs use a
/// sequential suffix with no embedded year, so the caller supplies the document's own
/// indexed year as a fallback.
///
/// Examples (all location `711.654`): `711.654/11-543` (1943) and `711.654/3-1342` (1942)
/// are neighbors (both 1940–1944); `711.654/8-147` (1947) is not (1945–1949).
///
/// ## 1963 divides by number form, not by date (#830)
/// The Central Decimal File ends **January 1963**; the Subject-Numeric File begins
/// **1963-02-01**. A dotted decimal number (`611.61/…`) belongs to the decimal file
/// whatever its date, and a letter-led designator (`POL 27 …`) never does — the filing
/// system is fixed by the number, exactly as `NARACatalogClient.decimalFilePeriodLabel`
/// already states. This type used to band all of calendar 1963 as decimal-file and never
/// checked the form at all, so a February-1963 subject-numeric document could cluster as
/// a filing-period neighbor of January's decimal filings — a live wrong answer in
/// `IndexingPipeline.relatedByDecimal`, not just a label. The last band's NAME carries
/// the correction too, so the neighbor basis line and the period label on the same
/// Source Explorer screen can no longer contradict each other.
///
/// Version history:
///   1.0 — Session 2026-06-16: archival neighbors
///   1.1 — Session 2026-08-23: #830 — a non-decimal-form ref is refused (no decimal
///          segment exists for it), and the last band is named "1960–January 1963"
enum DecimalFileSegment {

    /// The decimal classification before the first `/` (`711.654/11-543` → `711.654`).
    /// Returns the trimmed whole string when there is no `/`.
    static func location(from ref: String) -> String {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        return trimmed.components(separatedBy: "/").first?
            .trimmingCharacters(in: .whitespaces) ?? trimmed
    }

    /// The 4-digit year from a date-form suffix (one containing `-`, e.g. `11-543` → 1943),
    /// taken from the suffix's last two digits. `nil` for a sequential (pre-1940) suffix or
    /// when no suffix is present.
    static func suffixYear(from ref: String) -> Int? {
        let parts = ref.components(separatedBy: "/")
        guard parts.count >= 2 else { return nil }
        let suffix = parts[1...].joined(separator: "/")
        guard suffix.contains("-") else { return nil }     // date form only
        let digits = suffix.filter(\.isNumber)
        guard digits.count >= 2, let yy = Int(digits.suffix(2)) else { return nil }
        return 1900 + yy
    }

    /// The decimal-file period segment key for a year, or `nil` outside 1910–1963.
    ///
    /// The last band is named for what it is: the decimal file closed in **January**
    /// 1963, and a 1963 year reaching this function belongs to it only because the
    /// caller's ref was decimal-FORM (see `segment(for:fallbackYear:)`) — a decimal
    /// number is a decimal filing by definition, whatever month it carries.
    static func segment(forYear year: Int) -> String? {
        switch year {
        case 1910...1929: return "1910–1929"
        case 1930...1939: return "1930–1939"
        case 1940...1944: return "1940–1944"
        case 1945...1949: return "1945–1949"
        case 1950...1954: return "1950–1954"
        case 1955...1959: return "1955–1959"
        case 1960...1963: return "1960–January 1963"
        default:          return nil
        }
    }

    /// The segment for a reference, preferring the suffix year and falling back to
    /// `fallbackYear` (the document's own indexed year) for sequential pre-1940 refs.
    ///
    /// **Refuses a ref that is not in decimal-file FORM** — a letter-led designator
    /// (`POL 27 VIET S`) is a Subject-Numeric filing and no decimal segment exists for
    /// it, whatever year rides along. Banding it would cluster it with filings from a
    /// system it was never part of.
    static func segment(for ref: String, fallbackYear: Int?) -> String? {
        guard NARACatalogClient.isDecimalFileNumber(ref) else { return nil }
        let year = suffixYear(from: ref) ?? fallbackYear
        return year.flatMap(segment(forYear:))
    }
}
