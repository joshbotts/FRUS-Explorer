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
/// attached (`737.00/7-761. Secret. Drafted by Hurwitch on July 10.`) was dated by whatever digits
/// ended the note — a drafting date in 19 of 23 notes, a receipt time in two (`Received at 1:40
/// p.m.` made 1940), a telegram number and an office symbol (`J-3`) — all read as 1910–1940
/// instead of 1961–1962.
///
/// ## A misprinted year is the document's own day under another year (#1407 review, round 1)
/// The date form is the date of the document itself, so an item whose month and day are the
/// document's own and whose year is not is a misprinted year digit, not a later filing.
/// frus1943/d394 is dated 20 August 1943 and its source note prints `740.0011 EW/8–2045`, while
/// its own first footnote gives the files of the same paragraphs as `…/8–2043`. Read as printed,
/// that year put the 1943 Quebec minutes in the 1945–1949 band beside two Potsdam documents.
/// ``fileYear(from:documentDay:)`` refuses such a year, and every caller then falls back to the
/// document's own. A year gap alone is never refused, because later filings are real:
/// frus1945Berlinv02/d843, dated 27 July 1945, is filed `023.1/9–1454`.
///
/// Measured over the same stored numbers, each joined to its document's dateline date (else its
/// `frus:doc-dateTime-min`): **111** of the 63,998 date-form reads carry their document's month
/// and day under another year, and **48** of those name a different band from the document's
/// year. Most are the misprint — `840.20/3–2340` on a telegram of 23 March 1949,
/// `762.00/11–1253` on one of 12 November 1958 — but the rule cannot tell a misprinted number
/// from a misdated document, and in about six the TEI misdates the document instead
/// (`frus1945Malta/d273` prints November 27, 1944 and is encoded 1945; `frus1955-57v15/d334` is
/// encoded 1965). There the rule answers with the document's year, the wrong one of the two —
/// which is what every caller answered for an en-dash item before #1407.
///
/// Version history:
///   1.0 — Session 2026-06-16: archival neighbors
///   1.1 — Session 2026-08-23: #830 — a non-decimal-form ref is refused (no decimal
///          segment exists for it), and the last band is named "1960–January 1963"
///   1.2 — Session 2026-09-25: #1407 — `suffixYear` reads the date form as a grammar at the
///          start of the item, with any of the corpus's dash spellings, and only for 1940–1963
///   1.3 — Session 2026-09-26: #1407 review, round 1 — `dateFormItem` keeps the month and day,
///          and `fileYear(from:documentDay:)` refuses a year that misprints the document's own
///          day; `segment` and `filingYear` take the document's day
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

    /// A date-form item as printed: its month, its day and its four-digit year (`8–2045` → 8, 20,
    /// 1945). Neither the month nor the day is range-checked — see ``dateFormItem(from:)``.
    struct DateFormItem: Equatable, Sendable {
        /// The month as printed (`0` in `870.00/0–2447`, a misprint).
        let month: Int
        /// The day as printed (`54` in `865.01/12–5441`, a misprint).
        let day: Int
        /// The year, 1940–1963.
        let year: Int
    }

    /// A document's own calendar day, as the index stores it — what
    /// ``fileYear(from:documentDay:)`` compares a date-form item with.
    struct DocumentDay: Equatable, Sendable {
        /// The document's year.
        let year: Int
        /// The document's month, 1–12.
        let month: Int
        /// The document's day of the month.
        let day: Int

        /// A day from its three parts.
        init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }

        /// The day an index date names — the leading `yyyy-MM-dd` of `iso`
        /// (`document_dates.date_iso`, `DocumentDateMetadata.dateISO`) — or `nil` when there is
        /// none, or when `precision` says the source date is coarser than a day: the index pads
        /// `1949` to `1949-01-01` and `1949-03` to `1949-03-01`, and a padded `01` is not a day the
        /// document names. A `nil` precision (a row older than the column) reads at day grain, as
        /// the rest of the app reads it.
        init?(iso: String?, precision: DatePrecision?) {
            guard let iso, precision == nil || precision == .day else { return nil }
            let parts = iso.prefix(10).split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0].count == 4,
                  let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
                  (1...12).contains(month), (1...31).contains(day) else { return nil }
            self.init(year: year, month: month, day: day)
        }
    }

    /// The date-form item a file number carries (`11-543` → 5 November 1943, `12–854` → 8 December
    /// 1954), or `nil` for a sequential (pre-1940) item, an item that is not a date, or no item.
    ///
    /// The item is what follows the FIRST `/`. It is date form only when it opens — after at
    /// most one space — with a one- or two-digit month, one of ``dateSeparators`` (a space either
    /// side is allowed), and a run of three or four digits (the day run into the year) that no
    /// further digit follows. The year is that run's last two digits, and only
    /// ``dateFormYears`` are accepted. The month and day are NOT range-checked, because the
    /// checks would refuse none of the pre-1940 shapes the grammar does not already refuse, and
    /// a misprinted month or day need not be a misprinted year: `870.00/0–2447` is 24 June 1947
    /// (frus1947v04/d12, dated that day). Nor can the grammar see every misprint:
    /// `865.01/12–5441` reads 1941, but its document (frus1944v03/d1080) is dated 5 December 1944,
    /// so the number meant was `12–544` with one stray digit — and 1941 and 1944 fall in one band.
    /// See the type's note for the shapes this refuses and why.
    static func dateFormItem(from ref: String) -> DateFormItem? {
        guard let slash = ref.firstIndex(of: "/") else { return nil }
        var rest = Substring(ref[ref.index(after: slash)...])
        rest = droppingOneSpace(rest)
        let monthDigits = rest.prefix(while: isDigit)
        guard (1...2).contains(monthDigits.count), let month = Int(monthDigits) else { return nil }
        rest = droppingOneSpace(rest.dropFirst(monthDigits.count))
        guard let dash = rest.first, dateSeparators.contains(dash) else { return nil }
        rest = droppingOneSpace(rest.dropFirst())
        let dayAndYear = rest.prefix(while: isDigit)
        guard (3...4).contains(dayAndYear.count),
              let day = Int(dayAndYear.dropLast(2)),
              let yy = Int(dayAndYear.suffix(2)), dateFormYears.contains(yy) else { return nil }
        return DateFormItem(month: month, day: day, year: 1900 + yy)
    }

    /// The 4-digit year a date-form item prints (``dateFormItem(from:)``), or `nil`. The grammar
    /// alone: it cannot tell a misprinted year, so a caller holding the document's day reads
    /// ``fileYear(from:documentDay:)`` instead. The trip packet's crib reads this one to choose
    /// NARA's date-numbering example, which a misprinted date is still an instance of.
    static func suffixYear(from ref: String) -> Int? {
        dateFormItem(from: ref)?.year
    }

    /// The year a date-form file number files under, for a document dated `documentDay`: the
    /// item's own year, or `nil` when there is none — or when the item is the document's own
    /// month and day under another year, a misprinted year digit (`740.0011 EW/8–2045` on a
    /// document of 20 August 1943). A different month or day is a later filing and keeps its
    /// year. With no `documentDay` this is ``suffixYear(from:)``. See the type's note.
    static func fileYear(from ref: String, documentDay: DocumentDay?) -> Int? {
        guard let item = dateFormItem(from: ref) else { return nil }
        if let documentDay, isMisprintedYear(item, of: documentDay) { return nil }
        return item.year
    }

    /// Whether `item` is `documentDay` with another year — the one misprint the date form can
    /// be caught in, since the item is the document's own date.
    static func isMisprintedYear(_ item: DateFormItem, of documentDay: DocumentDay) -> Bool {
        item.month == documentDay.month && item.day == documentDay.day && item.year != documentDay.year
    }

    /// The year whose filing period a central-file citation belongs to: the date-form item's own
    /// year (``fileYear(from:documentDay:)``, so not a misprint of the document's day), else
    /// `documentYear` — the document's own year, which is all a sequential item, a misprinted
    /// date, a subject-numeric designator or a missing number leaves to go on.
    ///
    /// Source Explorer's "Filing Period" row reads this on both platforms, so it names the same
    /// band as the Archival Neighbors basis line beside it (`segment(for:fallbackYear:documentDay:)`,
    /// the same preference). Before #1407 the row took the document's year outright, which the
    /// basis line also did in effect while an en-dash item carried no year; once the basis line
    /// read the file's year, a 1945 document citing `023.1/9–1454` (frus1945Berlinv02/d843) would
    /// have shown "1950–1954" in one row and "1945–1949" in the next.
    static func filingYear(for fileIdentifier: String?, documentDay: DocumentDay?,
                           documentYear: Int?) -> Int? {
        fileIdentifier.flatMap { fileYear(from: $0, documentDay: documentDay) } ?? documentYear
    }

    /// Whether a character is an ASCII digit — the only digits `Int(_:)` reads, so the run this
    /// counts is the run the grammar parses. `Character.isNumber` would count a vulgar fraction
    /// as one more digit, and `12–854½` would become a four-character run whose last two
    /// characters are no year, refusing a date the item states whole. No stored date-form item
    /// is followed by a fraction (2,203 stored decimal numbers carry a `½` in their item, none of
    /// them directly after a date), so the choice decides no stored note; `asciiDigitsBoundTheRun`
    /// pins it. (It is not what refuses `793.94/1183–½`: that item's four-digit "month" is.)
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
    /// caller's ref was decimal-FORM (see `segment(for:fallbackYear:documentDay:)`) — a decimal
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

    /// The segment for a reference, preferring the file's own year
    /// (``fileYear(from:documentDay:)``) and falling back to `fallbackYear` (the document's own
    /// indexed year) for a sequential pre-1940 ref and for a date that misprints the document's
    /// day. `documentDay` is the document's own day, `nil` when the caller has none — which
    /// leaves a misprinted year standing.
    ///
    /// **Refuses a ref that is not in decimal-file FORM** — a letter-led designator
    /// (`POL 27 VIET S`) is a Subject-Numeric filing and no decimal segment exists for
    /// it, whatever year rides along. Banding it would cluster it with filings from a
    /// system it was never part of.
    static func segment(for ref: String, fallbackYear: Int?, documentDay: DocumentDay?) -> String? {
        guard NARACatalogClient.isDecimalFileNumber(ref) else { return nil }
        let year = fileYear(from: ref, documentDay: documentDay) ?? fallbackYear
        return year.flatMap(segment(forYear:))
    }
}
