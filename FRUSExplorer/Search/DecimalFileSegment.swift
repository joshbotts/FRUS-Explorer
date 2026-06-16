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
/// Version history:
///   1.0 — Session 2026-06-16: archival neighbors
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
    static func segment(forYear year: Int) -> String? {
        switch year {
        case 1910...1929: return "1910–1929"
        case 1930...1939: return "1930–1939"
        case 1940...1944: return "1940–1944"
        case 1945...1949: return "1945–1949"
        case 1950...1954: return "1950–1954"
        case 1955...1959: return "1955–1959"
        case 1960...1963: return "1960–1963"
        default:          return nil
        }
    }

    /// The segment for a reference, preferring the suffix year and falling back to
    /// `fallbackYear` (the document's own indexed year) for sequential pre-1940 refs.
    static func segment(for ref: String, fallbackYear: Int?) -> String? {
        let year = suffixYear(from: ref) ?? fallbackYear
        return year.flatMap(segment(forYear:))
    }
}
