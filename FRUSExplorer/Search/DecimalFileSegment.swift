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
/// ## The date form is a grammar, not "a dash somewhere" (#1407)
/// FRUS prints the date-form item with an **en dash** (`611.93/12–854`), and the old test —
/// `suffix.contains("-")`, an ASCII hyphen — read a year from none of them. Measured over every
/// decimal-form file number the index stores as `series_name` (175,812 source notes, a fresh
/// `SourceExplorerExportGenerator` run over the 553 shipped volumes on 2026-09-26), the old rule
/// read a year from **582**; this one reads **63,998** — 63,343 en-dash, 565 hyphen, 90 em-dash.
///
/// Widening the dash alone would have been wrong, because a pre-1940 sequential item carries
/// dashes for other reasons: a range of items (`711.654/4–5`, `462.00 R 29/828–1224`,
/// `861.00 Congress, Communist International, VII/56–62`), a lettered run (`812.00/12392a–j`),
/// a half number (`793.94/1183–½`), or a bare dash standing for "no item" (`823.00/—`). Reading
/// the last two digits of those minted 1945, 1924, 1962, 1992 and 1983. So the item must open with
/// the date itself: a month of one or two digits, one dash, and three or four digits — the day
/// run straight into the year — with no digit after them; and the year must fall in the
/// date-numbering era, 1940–1963. Over the same measurement that rule reads a year for **no**
/// document dated before 1940 (the old one read one: `861.48/157a-e` → 1957, on a 1916 document).
///
/// Anchoring at the item's start also fixes the other way the old rule went wrong: it joined
/// everything after the first slash, so a file number the parser returned with its note still
/// attached (`737.00/7-761. Secret. Drafted by Hurwitch on July 10.`) was dated by the digits of
/// the drafting date — 23 notes, all read as 1910–1940 instead of 1961–1962.
///
/// Version history:
///   1.0 — Session 2026-06-16: archival neighbors
///   1.1 — Session 2026-08-23: #830 — a non-decimal-form ref is refused (no decimal
///          segment exists for it), and the last band is named "1960–January 1963"
///   1.2 — Session 2026-09-25: #1407 — `suffixYear` reads the date form as a grammar at the
///          start of the item, with any of the corpus's dash spellings, and only for 1940–1963
enum DecimalFileSegment {

    /// The decimal classification before the first `/` (`711.654/11-543` → `711.654`).
    /// Returns the trimmed whole string when there is no `/`.
    static func location(from ref: String) -> String {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        return trimmed.components(separatedBy: "/").first?
            .trimmingCharacters(in: .whitespaces) ?? trimmed
    }

    /// The dashes that separate a date-form item's month from its day and year: the ASCII
    /// hyphen, the non-breaking hyphen (U+2011), the en dash (U+2013) the corpus prints almost
    /// everywhere, and the em dash (U+2014). Measured, the stored file numbers use only the
    /// hyphen, the en dash and the em dash in this position; the non-breaking hyphen is admitted
    /// because it is the one other spelling a typesetter substitutes for a hyphen inside a number.
    static let dateSeparators: Set<Character> = ["-", "\u{2011}", "\u{2013}", "\u{2014}"]

    /// The two-digit years the date form can carry: the Department numbered decimal-file
    /// documents by date from 1940 until the decimal file closed in January 1963. (Beside
    /// sequential numbers at first: of the decimal file numbers cited in documents dated 1940–1944,
    /// 15.1% are date form, against 99.7% for 1945–1949.)
    static let dateFormYears: ClosedRange<Int> = 40...63

    /// The 4-digit year from a date-form item (`11-543` → 1943, `12–854` → 1954), or `nil` for a
    /// sequential (pre-1940) item, an item that is not a date, or no item at all.
    ///
    /// The item is what follows the FIRST `/`. It is date form only when it opens — after at
    /// most one space — with a one- or two-digit month, one of ``dateSeparators`` (a space either
    /// side is allowed), and a run of three or four digits (the day run into the year) that no
    /// further digit follows. The year is that run's last two digits, and only
    /// ``dateFormYears`` are accepted. The month and day are NOT range-checked: the corpus's
    /// misprints (`0–2447`, `12–5441`) still carry the right year, and the checks refuse none of
    /// the pre-1940 shapes the grammar does not already refuse. See the type's note for the shapes
    /// this refuses and why.
    static func suffixYear(from ref: String) -> Int? {
        guard let slash = ref.firstIndex(of: "/") else { return nil }
        var rest = Substring(ref[ref.index(after: slash)...])
        rest = droppingOneSpace(rest)
        let month = rest.prefix(while: isDigit)
        guard (1...2).contains(month.count) else { return nil }
        rest = droppingOneSpace(rest.dropFirst(month.count))
        guard let dash = rest.first, dateSeparators.contains(dash) else { return nil }
        rest = droppingOneSpace(rest.dropFirst())
        let dayAndYear = rest.prefix(while: isDigit)
        guard (3...4).contains(dayAndYear.count),
              let yy = Int(dayAndYear.suffix(2)), dateFormYears.contains(yy) else { return nil }
        return 1900 + yy
    }

    /// The year whose filing period a central-file citation belongs to: the date-form item's own
    /// year (``suffixYear(from:)``), else `documentYear` — the document's own year, which is all a
    /// sequential item, a subject-numeric designator or a missing number leaves to go on.
    ///
    /// Source Explorer's "Filing Period" row reads this on both platforms, so it names the same
    /// band as the Archival Neighbors basis line beside it (`segment(for:fallbackYear:)`, the same
    /// preference). Before #1407 the row took the document's year outright, which the basis line
    /// also did in effect while an en-dash item carried no year; once the basis line read the
    /// file's year, a 1943 document citing `740.0011 EW/8–2045` would have shown "1945–1949" in one
    /// row and "1940–1944" in the next.
    static func filingYear(for fileIdentifier: String?, documentYear: Int?) -> Int? {
        fileIdentifier.flatMap(suffixYear(from:)) ?? documentYear
    }

    /// Whether a character is an ASCII digit. `Character.isNumber` is not enough: it admits `½`,
    /// which the corpus prints inside items (`793.94/1183–½`).
    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isWholeNumber
    }

    /// `text` without one leading space, when it has one.
    private static func droppingOneSpace(_ text: Substring) -> Substring {
        text.first == " " ? text.dropFirst() : text
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
