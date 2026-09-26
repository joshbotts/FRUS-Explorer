// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// Tests the decimal-file location/segment parsing that drives decimal-file archival
/// neighbors, using the exact examples from the feature definition.
struct DecimalFileSegmentTests {

    @Test("Location is the classification before the first slash")
    func location() {
        #expect(DecimalFileSegment.location(from: "711.654/11-543") == "711.654")
        #expect(DecimalFileSegment.location(from: "711.01/6-742") == "711.01")
        #expect(DecimalFileSegment.location(from: "862S.01") == "862S.01")  // no suffix
    }

    @Test("Suffix year is the last two digits of a date-form suffix")
    func suffixYear() {
        #expect(DecimalFileSegment.suffixYear(from: "711.654/11-543") == 1943)
        #expect(DecimalFileSegment.suffixYear(from: "711.654/3-1342") == 1942)
        #expect(DecimalFileSegment.suffixYear(from: "711.654/8-147") == 1947)
        #expect(DecimalFileSegment.suffixYear(from: "862S.01/10-1646") == 1946)
        // Sequential (pre-1940) suffix has no embedded year.
        #expect(DecimalFileSegment.suffixYear(from: "711.654/123") == nil)
        #expect(DecimalFileSegment.suffixYear(from: "711.654") == nil)
    }

    @Test("Years map to the correct decimal-file period segment")
    func segmentForYear() {
        #expect(DecimalFileSegment.segment(forYear: 1943) == "1940–1944")
        #expect(DecimalFileSegment.segment(forYear: 1942) == "1940–1944")
        #expect(DecimalFileSegment.segment(forYear: 1947) == "1945–1949")
        #expect(DecimalFileSegment.segment(forYear: 1925) == "1910–1929")
        // The last band is NAMED for when the decimal file actually closed — January
        // 1963 — so this label and `decimalFilePeriodLabel` on the same Source Explorer
        // screen can no longer contradict each other (#830).
        #expect(DecimalFileSegment.segment(forYear: 1962) == "1960–January 1963")
        #expect(DecimalFileSegment.segment(forYear: 1963) == "1960–January 1963")
        #expect(DecimalFileSegment.segment(forYear: 1964) == nil)  // subject-numeric era
        #expect(DecimalFileSegment.segment(forYear: 1905) == nil)  // outside decimal era
    }

    /// 1963 divides by NUMBER FORM (#830): a dotted decimal number is a decimal filing
    /// whatever its date; a letter-led subject-numeric designator never is, whatever year
    /// rides along. Banding a `POL` ref would cluster it with filings from a system it
    /// was never part of — a live wrong answer in `relatedByDecimal`, not a label.
    @Test("A non-decimal-form ref is refused, whatever its year")
    func nonDecimalFormIsRefused() {
        #expect(DecimalFileSegment.segment(for: "POL 27 VIET S", fallbackYear: 1963, documentDay: nil) == nil)
        #expect(DecimalFileSegment.segment(for: "POL 17-3 JORDAN", fallbackYear: 1962, documentDay: nil) == nil)
        // A decimal-form ref with a 1963 fallback year IS decimal — the number decides.
        #expect(DecimalFileSegment.segment(for: "611.61/2200", fallbackYear: 1963, documentDay: nil)
                == "1960–January 1963")
        // And a decimal date-form suffix still resolves by its own embedded year.
        #expect(DecimalFileSegment.segment(for: "611.93/12-854", fallbackYear: nil, documentDay: nil)
                == "1950–1954")
    }

    @Test("The feature's worked example resolves to the right neighbor verdicts")
    func workedExample() {
        // 711.654/11-543 (1943) is a neighbor of 711.654/3-1342 (1942) — same location, segment.
        let a = (DecimalFileSegment.location(from: "711.654/11-543"),
                 DecimalFileSegment.segment(for: "711.654/11-543", fallbackYear: nil, documentDay: nil))
        let b = (DecimalFileSegment.location(from: "711.654/3-1342"),
                 DecimalFileSegment.segment(for: "711.654/3-1342", fallbackYear: nil, documentDay: nil))
        let c = (DecimalFileSegment.location(from: "711.654/8-147"),
                 DecimalFileSegment.segment(for: "711.654/8-147", fallbackYear: nil, documentDay: nil))
        let d = (DecimalFileSegment.location(from: "711.01/6-742"),
                 DecimalFileSegment.segment(for: "711.01/6-742", fallbackYear: nil, documentDay: nil))
        #expect(a == b)        // neighbors
        #expect(a != c)        // different segment (1945–1949)
        #expect(a != d)        // different location
    }

    @Test("Pre-1940 sequential refs fall back to the document's own year")
    func sequentialFallback() {
        // "711.654/123" has no suffix year; the document's 1925 date places it in 1910–1929.
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: 1925, documentDay: nil) == "1910–1929")
        // No suffix year and no fallback → no segment (caller does location-only matching).
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: nil, documentDay: nil) == nil)
    }
}

// MARK: - DecimalDateFormTests (#1407)

/// The date-form item as the corpus prints it (#1407).
///
/// FRUS writes the date form with an EN DASH (`611.93/12–854`) — 63,343 of the 63,998 date-form
/// file numbers the index stores — and `suffixYear` used to accept only an ASCII hyphen, so almost
/// none of them had a file year. The fix could not simply widen the dash, because a pre-1940
/// sequential item carries dashes for other reasons, and reading the last two digits of those minted
/// years. So every refusal below is one real corpus shape, named with the document it came from.
///
/// What each fixture kills was measured (the X3 A/B logs), not assumed. The ranges, long ranges,
/// lettered runs, out-of-era years and the second slash are written in BOTH spellings — the en
/// dash the corpus prints and the hyphen the old rule read — and fail on the old rule (which dated
/// the hyphen) and on a naive widening (any dash, the item's last two digits, which dates both);
/// the trailing note fails on both as well. The dash spellings and the spaces fail on the old rule
/// only, since a naive widening reads them too. Two refusals kill less: the half number fails only
/// the naive widening — the old rule refused it too, since its last two characters, `3½`, are no
/// integer — and the bare dash fails neither, having no digits to read; they pin the grammar's
/// refusals, not the change. The ASCII digit alphabet has its own fixture, `asciiDigitsBoundTheRun`.
@Suite("Decimal date-form item (#1407)")
struct DecimalDateFormTests {

    /// Every dash spelling of one date-form number gives one year.
    @Test("En dash, em dash, non-breaking hyphen and hyphen spellings give the same year")
    func everyDashSpellingGivesTheSameYear() {
        for dash in ["-", "\u{2013}", "\u{2014}", "\u{2011}"] {
            #expect(DecimalFileSegment.suffixYear(from: "611.93/12\(dash)854") == 1954,
                    "611.93/12\(dash)854 must read as 8 December 1954")
            #expect(DecimalFileSegment.segment(for: "611.93/12\(dash)854", fallbackYear: nil, documentDay: nil)
                    == "1950–1954")
        }
        // The two-digit day: 3–1342 is 13 March 1942.
        #expect(DecimalFileSegment.suffixYear(from: "711.654/3–1342") == 1942)
    }

    /// The item is read where it starts: after the first slash, past one space.
    @Test("A space before the slash or around the dash does not hide the date")
    func spacesAroundTheItem() {
        // 2,224 stored numbers carry a space before the slash (`751G.5 MSP /10–553`).
        #expect(DecimalFileSegment.suffixYear(from: "751G.5 MSP /10–553") == 1953)
        #expect(DecimalFileSegment.suffixYear(from: "501. BC / 1–2045") == 1945)
        #expect(DecimalFileSegment.suffixYear(from: "740.00119 EW/8 – 2644") == 1944)
    }

    /// A file number the parser returns with its note attached is dated by its own item, not by
    /// the last digits of the drafting date that follows it.
    @Test("A note left on the file number does not date it (frus1961-63v10/d242)")
    func trailingNoteDoesNotDate() {
        // The old rule joined everything after the slash and took its last two digits: "July 10"
        // made this 1910. 23 stored numbers read that way, every one of them 1961–1962.
        #expect(DecimalFileSegment.suffixYear(
            from: "737.00/7-761. Secret. Drafted by Hurwitch on July 10.") == 1961)
        #expect(DecimalFileSegment.suffixYear(
            from: "751K.oo/7-361. Secret; Priority. In telegram 12 to Saigon") == 1961)
    }

    /// Neither the month nor the day is range-checked, and each has a fixture a check would fail.
    ///
    /// A misprinted month need not be a misprinted year: `0–2447` is 24 June 1947, the day
    /// frus1947v04/d12 is dated. The grammar cannot see every misprint, though, and the second
    /// fixture says only what is right about it: `865.01/12–5441` reads as printed, 1941, but
    /// frus1944v03/d1080 is dated 5 December 1944, so the number meant was `12–544` with one stray
    /// digit. 1941 and 1944 fall in one band, so the BAND — what every caller shows — is right
    /// either way, and a day check (54 is no day) would lose it for a caller with no document year
    /// to fall back on. The year itself is deliberately not asserted.
    @Test("An unchecked month keeps 0–2447's year, and an unchecked day keeps 12–5441's band (frus1947v04/d12, frus1944v03/d1080)")
    func uncheckedMonthAndDay() {
        #expect(DecimalFileSegment.suffixYear(from: "870.00/0–2447") == 1947)
        #expect(DecimalFileSegment.segment(for: "865.01/12–5441", fallbackYear: nil, documentDay: nil)
                == "1940–1944")
    }

    /// The grammar's digits are ASCII — the only ones `Int(_:)` reads — so a vulgar fraction after
    /// the day-and-year run ends the run rather than joining it. No stored date-form item has one
    /// (2,203 stored decimal numbers carry a `½` in their item, none directly after a date), so this
    /// is a synthetic fixture pinning the alphabet: counted by `Character.isNumber`, `854½` would be
    /// a four-character run whose last two characters, `4½`, are no year.
    @Test("A fraction after the date ends the digit run rather than joining it")
    func asciiDigitsBoundTheRun() {
        #expect(DecimalFileSegment.suffixYear(from: "611.93/12–854½") == 1954)
    }

    /// A year outside the date-numbering era is a misprint the document's own year answers
    /// better: `5–510` in a 1950 volume is not a 1910 filing.
    @Test("A year outside 1940–1963 is refused (frus1950v05/d820, frus1949v05/d386)")
    func outOfEraYearsAreRefused() {
        for ref in ["689.90D3/5–510", "689.90D3/5-510", "861.00/10–1491", "861.00/10-1491"] {
            #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) is not a date-form year")
        }
    }

    /// The pre-1940 shapes, one fixture each, in both spellings.
    @Test("A range of items is not a date (frus1914/d606, frus1909/d515, frus1913/d207)",
          arguments: ["711.654/4|5", "358.117/1|2", "893.51/13|65"])
    func itemRangesAreRefused(_ shape: String) {
        for dash in ["\u{2013}", "-"] {
            let ref = shape.replacingOccurrences(of: "|", with: dash)
            #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) is a range of items")
        }
    }

    /// A range whose second number has four digits looks most like a date, and is refused because
    /// the first number is not a month.
    @Test("A range from a three-digit item is not a date (frus1927v02/d731, frus1933-39/d255)",
          arguments: ["462.00 R 29/828|1224", "861.00 Congress, Communist International, VII/56|62"])
    func longRangesAreRefused(_ shape: String) {
        for dash in ["\u{2013}", "-"] {
            let ref = shape.replacingOccurrences(of: "|", with: dash)
            #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) is a range of items")
        }
    }

    /// A lettered run of documents (`12392a–j`), which the old rule read as 1992 — and, spelled
    /// with a hyphen as the corpus does once, as 1957 on a 1916 document.
    @Test("A lettered run is not a date (frus1914/d807, frus1916Supp/d1178)",
          arguments: ["812.00/12392a|j", "861.48/157a|e"])
    func letteredRunsAreRefused(_ shape: String) {
        for dash in ["\u{2013}", "-"] {
            let ref = shape.replacingOccurrences(of: "|", with: dash)
            #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) is a lettered run")
        }
    }

    /// A half-numbered item (`1183–½`), refused because a four-digit run before the dash is no
    /// month. (Not by the ASCII digit rule: the grammar never reaches the `½`.)
    @Test("A half-numbered item is not a date (frus1921v01/d595)")
    func halfItemsAreRefused() {
        for ref in ["793.94/1183–½", "793.94/1183-½"] {
            #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) is a half item")
        }
    }

    /// A bare dash standing for "no item number" — also after a second slash.
    @Test("A bare dash is not a date (frus1913/d1497, frus1917Supp01v01/d850, frus1925v02/d583)",
          arguments: ["823.00/—", "705.6254/–", "841.61311/-", "811.612 Oranges/Spain/—"])
    func bareDashesAreRefused(_ ref: String) {
        #expect(DecimalFileSegment.suffixYear(from: ref) == nil, "\(ref) carries no date")
    }

    /// The item is the FIRST slash's, and that is a choice with a measured cost. Anchoring at the
    /// last slash instead would lose the 22 stored numbers whose first item is a date and whose
    /// last is not — mostly a note left on the number, whose office symbol has a slash of its own
    /// (`611.93/10–2955. Secret. Drafted by McAuliffe (S/S).`). Anchoring at the first leaves
    /// exactly FOUR stored numbers undated, each with a slash inside its class
    /// (`740.00/119 Council/9–3045`, whose class is `740.00119 Council`) — and each falls back to
    /// its document's year, which is in the same band as its file's in all four.
    @Test("A date past a misprinted second slash is not read (frus1945v02/d172)")
    func dateAfterASecondSlashIsNotRead() {
        #expect(DecimalFileSegment.suffixYear(from: "740.00/119 Council/9–3045") == nil)
        #expect(DecimalFileSegment.suffixYear(from: "740.00/119 Council/9-3045") == nil)
        #expect(DecimalFileSegment.suffixYear(
            from: "611.93/10–2955. Secret. Drafted by McAuliffe (S/S).") == 1955)
    }
}

// MARK: - DecimalMisprintedYearTests (#1407 review)

/// A date-form year that misprints the document's own day is refused (#1407 review, round 1).
///
/// The date form is the document's own date, so an item whose month and day are the document's
/// and whose year is not is a misprinted year digit. frus1943/d394 is the type case: dated 20
/// August 1943, its source note prints `740.0011 EW/8–2045`, and its own footnote 1 gives the
/// same paragraphs' files as `…/8–2043`. #1407 as first committed read that 1945 and moved the
/// document into 1945–1949; measured over the stored numbers, 47 of the 206 notes it re-banded
/// carry their document's own month and day under another year. Each conjunct of the rule has a
/// fixture of its own, because a fixture breaking two of them at once tests neither.
@Suite("Decimal date-form misprinted year (#1407 review)")
struct DecimalMisprintedYearTests {

    /// frus1943/d394's day.
    static let quebec = DecimalFileSegment.DocumentDay(year: 1943, month: 8, day: 20)

    @Test("The document's own day under another year is refused, and the document's year answers")
    func misprintedYearIsRefused() {
        #expect(DecimalFileSegment.fileYear(from: "740.0011 EW/8–2045", documentDay: Self.quebec) == nil)
        #expect(DecimalFileSegment.segment(for: "740.0011 EW/8–2045", fallbackYear: 1943,
                                           documentDay: Self.quebec) == "1940–1944")
        #expect(DecimalFileSegment.filingYear(for: "740.0011 EW/8–2045", documentDay: Self.quebec,
                                              documentYear: 1943) == 1943)
        // Real, in the other direction: frus1949v04/d128, a telegram of 23 March 1949, prints
        // `840.20/3–2340`.
        let march = DecimalFileSegment.DocumentDay(year: 1949, month: 3, day: 23)
        #expect(DecimalFileSegment.segment(for: "840.20/3–2340", fallbackYear: 1949,
                                           documentDay: march) == "1945–1949")
    }

    /// One fixture per conjunct: a different month, a different day, the same year.
    @Test("Another month, another day or the same year keeps the file's year")
    func eachConjunctKeepsTheYear() {
        // Month differs, day and year as in the misprint: 27 July 1954 on a document of 27 August 1945.
        #expect(DecimalFileSegment.fileYear(
            from: "740.0011 EW/7–2754",
            documentDay: .init(year: 1945, month: 8, day: 27)) == 1954)
        // Day differs: 21 August 1945 on a document of 20 August 1943.
        #expect(DecimalFileSegment.fileYear(from: "740.0011 EW/8–2145", documentDay: Self.quebec) == 1945)
        // Year agrees: the number the footnote gives, 8–2043, is the document's own day.
        #expect(DecimalFileSegment.fileYear(from: "740.0011 EW/8–2043", documentDay: Self.quebec) == 1943)
    }

    /// A year gap alone is never refused: later filings are real. frus1945Berlinv02/d843, dated
    /// 27 July 1945, is filed under 14 September 1954.
    @Test("A later filing keeps its year (frus1945Berlinv02/d843)")
    func laterFilingKeepsItsYear() {
        let potsdam = DecimalFileSegment.DocumentDay(year: 1945, month: 7, day: 27)
        #expect(DecimalFileSegment.fileYear(from: "023.1/9–1454", documentDay: potsdam) == 1954)
        #expect(DecimalFileSegment.segment(for: "023.1/9–1454", fallbackYear: 1945,
                                           documentDay: potsdam) == "1950–1954")
        #expect(DecimalFileSegment.filingYear(for: "023.1/9–1454", documentDay: potsdam,
                                              documentYear: 1945) == 1954)
    }

    /// With no day to check against, the year is read as printed — the rule refuses only on
    /// evidence.
    @Test("With no document day the year is read as printed")
    func noDayReadsAsPrinted() {
        #expect(DecimalFileSegment.fileYear(from: "740.0011 EW/8–2045", documentDay: nil) == 1945)
        #expect(DecimalFileSegment.dateFormItem(from: "740.0011 EW/8–2045")
                == .init(month: 8, day: 20, year: 1945))
    }

    /// The index pads a year-only or month-only date to a full day, and a padded day is not the
    /// document's: `1949-03` stored as `1949-03-01` must not refuse `3–140`.
    @Test("Only a day-precision date is a document day")
    func onlyDayPrecisionIsADay() {
        #expect(DecimalFileSegment.DocumentDay(iso: "1943-08-20", precision: .day) == Self.quebec)
        #expect(DecimalFileSegment.DocumentDay(iso: "1943-08-20", precision: nil) == Self.quebec,
                "a row older than the precision column reads at day grain")
        #expect(DecimalFileSegment.DocumentDay(iso: "1949-03-01", precision: .month) == nil)
        #expect(DecimalFileSegment.DocumentDay(iso: "1949-01-01", precision: .year) == nil)
        #expect(DecimalFileSegment.DocumentDay(iso: "1949", precision: nil) == nil)
        #expect(DecimalFileSegment.DocumentDay(iso: nil, precision: .day) == nil)
        let padded = DecimalFileSegment.DocumentDay(iso: "1949-03-01", precision: .month)
        #expect(DecimalFileSegment.fileYear(from: "840.20/3–140", documentDay: padded) == 1940)
    }
}

// MARK: - DecimalFileYearNeighbourTests (#1407)

/// `relatedByDecimal` bands both sides by the FILE's year, through the real index (#1407).
///
/// The anchor is a document of 1 May 1943 citing `740.0011 EW/8–2045` — a later filing, 20 August
/// 1945, in the 1945–1949 band. Before the fix the en dash gave it no file year, so it fell back
/// to 1943 and drew its neighbours from 1940–1944: the candidate filed 12–2845 but dated 1944 came
/// in for the wrong reason, the 1942 filing came in, and the 1946 filing and the hyphen-spelled
/// 1945 filing stayed out. The query runs at READ time over `series_name`, which stores the number
/// verbatim, so this needs no reindex — the fixture proves it by indexing once and reading through
/// the fixed rule.
///
/// Two more documents carry the MISPRINT the round-1 review found (#1407 review): each prints its
/// own month and day under another year, as frus1943/d394 does. (`d3` was dated 28 December 1944
/// until then — its own day under 1945, a misprint by that rule — and is now dated 20 December, so
/// it stays the later filing it was written to be.) `d6` (10 June 1944, `6–1045`) is a
/// candidate, and must band by its document's 1944, not join the 1945 anchor; `d7` (20 August
/// 1943, `8–2045` — d394's own number and day) is an anchor, and must draw from 1940–1944 even
/// though `d1` cites the very same number. Its day comes from the index, by the excluded key.
@Suite("Decimal neighbours by file year (#1407)")
struct DecimalFileYearNeighbourTests {

    /// One volume, seven documents citing one decimal location in different filing years.
    private static let volumeXML = """
        <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
          <div type="document" xml:id="d1" n="1"
               frus:doc-dateTime-min="1943-05-01" frus:doc-dateTime-max="1943-05-01">
            <head>Anchor<note type="source">Source: Department of State, Central Files, 740.0011 EW/8–2045. Secret.</note></head>
            <p>Filed in 1945, dated 1943.</p>
          </div>
          <div type="document" xml:id="d2" n="2"
               frus:doc-dateTime-min="1946-03-10" frus:doc-dateTime-max="1946-03-10">
            <head>Later filing<note type="source">Source: Department of State, Central Files, 740.0011 EW/3–1046. Secret.</note></head>
            <p>Filed in 1946.</p>
          </div>
          <div type="document" xml:id="d3" n="3"
               frus:doc-dateTime-min="1944-12-20" frus:doc-dateTime-max="1944-12-20">
            <head>Filed across the band<note type="source">Source: Department of State, Central Files, 740.0011 EW/12–2845. Secret.</note></head>
            <p>Filed in 1945, dated 1944 — on another day, so a later filing, not a misprint.</p>
          </div>
          <div type="document" xml:id="d4" n="4"
               frus:doc-dateTime-min="1942-01-15" frus:doc-dateTime-max="1942-01-15">
            <head>Earlier filing<note type="source">Source: Department of State, Central Files, 740.0011 EW/1–1542. Secret.</note></head>
            <p>Filed in 1942.</p>
          </div>
          <div type="document" xml:id="d5" n="5"
               frus:doc-dateTime-min="1944-06-01" frus:doc-dateTime-max="1944-06-01">
            <head>Hyphen spelling<note type="source">Source: Department of State, Central Files, 740.0011 EW/12-2745. Secret.</note></head>
            <p>Filed in 1945, dated 1944, spelled with a hyphen.</p>
          </div>
          <div type="document" xml:id="d6" n="6"
               frus:doc-dateTime-min="1944-06-10" frus:doc-dateTime-max="1944-06-10">
            <head>Misprinted candidate<note type="source">Source: Department of State, Central Files, 740.0011 EW/6–1045. Secret.</note></head>
            <p>Dated 10 June 1944; its number prints that day under 1945.</p>
          </div>
          <div type="document" xml:id="d7" n="7"
               frus:doc-dateTime-min="1943-08-20" frus:doc-dateTime-max="1943-08-20">
            <head>Misprinted anchor<note type="source">Source: Department of State, Central Files, 740.0011 EW/8–2045. Secret.</note></head>
            <p>Dated 20 August 1943; its number prints that day under 1945.</p>
          </div>
        </body></text></TEI>
        """

    /// Indexes the fixture volume into a fresh database under `dir`.
    private static func indexedPipeline(in dir: URL) async throws -> IndexingPipeline {
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try Data(Self.volumeXML.utf8).write(to: volDir.appendingPathComponent("frus1943v99.xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volDir,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume("frus1943v99")
        return pipeline
    }

    @Test("A 1943 document citing a 1945 file finds the 1945–1949 filings, whatever the dash")
    func neighboursShareTheFilesBand() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSDecimalBand-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = try await Self.indexedPipeline(in: dir)

        // Fixture guard: every note parsed as a central file keyed on `740.0011 EW`. A sequential
        // anchor with no document year has no segment, so the query is location-only and must
        // reach all six other documents — otherwise the band assertion below could fail (or
        // pass) over an empty set.
        let unbanded = try await pipeline.relatedDocuments(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/123"),
            limit: 30, documentYear: nil,
            excludingVolumeId: "frus1943v99", excludingDocumentId: "d1")
        try #require(unbanded.totalCount == 6,
                     "the fixture's notes must key on 740.0011 EW; got \(unbanded.totalCount)")

        let related = try await pipeline.relatedDocuments(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8–2045"),
            limit: 30, documentYear: 1943,
            excludingVolumeId: "frus1943v99", excludingDocumentId: "d1")
        #expect(Set(related.documents.map(\.documentId)) == ["d2", "d3", "d5"], """
            The anchor's file is 20 August 1945, so its neighbours are the 1945–1949 filings: d2 \
            (1946), d3 (12–2845, dated 1944) and d5 (12-2745, hyphen). Got \
            \(related.documents.map(\.documentId).sorted()) — ["d3", "d4", "d6", "d7"] is the \
            document-year band the en dash used to fall back to, and d6 or d7 here is a misprinted \
            year read as printed.
            """)
        #expect(related.totalCount == 3)
    }

    /// The anchor that misprints its own day is banded by its document's year, and so is the
    /// candidate that does (#1407 review, round 1).
    @Test("An anchor whose number misprints its own day draws from its document's band")
    func misprintedAnchorDrawsFromItsDocumentsBand() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSDecimalMisprint-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let pipeline = try await Self.indexedPipeline(in: dir)

        // The day the anchor is checked against, read through the function both Source Explorer
        // twins call — and the guard that the fixture's date reached `document_dates` at day grain.
        let day = await SourceExplorerDocumentContext.documentDay(
            pipeline: pipeline, volumeId: "frus1943v99", documentId: "d7")
        try #require(day == .init(year: 1943, month: 8, day: 20), "got \(String(describing: day))")

        let related = try await pipeline.relatedDocuments(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8–2045"),
            limit: 30, documentYear: 1943,
            excludingVolumeId: "frus1943v99", excludingDocumentId: "d7")
        #expect(Set(related.documents.map(\.documentId)) == ["d4", "d6"], """
            d7 is dated 20 August 1943 and prints 8–2045, its own day under 1945: a misprint, so it \
            bands by 1943 and its neighbours are the 1940–1944 filings — d4 (1942) and d6, whose \
            own misprint bands it by 1944. Got \(related.documents.map(\.documentId).sorted()); \
            ["d1", "d2", "d3", "d5", "d6"] is the 1945 band the printed year names.
            """)
    }
}

// MARK: - SourceExplorerBasisLineTests (#1407)

/// The Archival Neighbors basis line names the FILE's filing band (#1407), through the static the
/// section draws (`SourceExplorerView.archivalNeighborBasis(for:documentYear:documentDay:)`) —
/// unless the file's year misprints the document's own day (#1407 review).
@Suite("Source Explorer basis line (#1407)")
@MainActor
struct SourceExplorerBasisLineTests {

    /// frus1945Berlinv02/d843's day: 27 July 1945, filed `023.1/9–1454`.
    static let potsdam = DecimalFileSegment.DocumentDay(year: 1945, month: 7, day: 27)

    @Test("An en-dash file names its own band, not the document's (frus1945Berlinv02/d843)")
    func enDashFileNamesItsBand() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "023.1/9–1454"),
            documentYear: 1945, documentDay: Self.potsdam)
        // A later filing: the document is 1945, the filing 1954.
        #expect(basis == "Same decimal file — 023.1, 1950–1954", "got \(basis ?? "nil")")
    }

    @Test("A hyphen spelling of the same file gives the same line")
    func hyphenGivesTheSameLine() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "023.1/9-1454"),
            documentYear: 1945, documentDay: Self.potsdam)
        #expect(basis == "Same decimal file — 023.1, 1950–1954", "got \(basis ?? "nil")")
    }

    /// frus1943/d394, dated 20 August 1943, prints `740.0011 EW/8–2045` — its own day under 1945.
    @Test("A file year that misprints the document's day gives the document's band (frus1943/d394)")
    func misprintedYearGivesTheDocumentsBand() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8–2045"),
            documentYear: 1943, documentDay: .init(year: 1943, month: 8, day: 20))
        #expect(basis == "Same decimal file — 740.0011 EW, 1940–1944", "got \(basis ?? "nil")")
    }

    @Test("A sequential item still takes the document's year")
    func sequentialItemTakesTheDocumentYear() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "711.654/123"),
            documentYear: 1925, documentDay: nil)
        #expect(basis == "Same decimal file — 711.654, 1910–1929", "got \(basis ?? "nil")")
    }
}

// MARK: - FilingPeriodYearTests (#1407)

/// Source Explorer's "Filing Period" row and its Archival Neighbors basis line name one band
/// (#1407). The basis line reads the file's own year once the en dash is read; the period row read
/// the document's year outright, so on every stored note whose file year falls in a different band
/// from its document's — 135 of them, once a year that misprints the document's own day is
/// refused (183 before that rule) — the two rows would have disagreed. Both platforms' period rows
/// now read `DecimalFileSegment.filingYear`, with the document's day.
@Suite("Filing period year (#1407)")
struct FilingPeriodYearTests {

    @Test("The file's own year wins; the document's year answers everything else")
    func filingYearPrefersTheFile() {
        // frus1945Berlinv02/d843: a 1945 document filed in 1954.
        let potsdam = DecimalFileSegment.DocumentDay(year: 1945, month: 7, day: 27)
        #expect(DecimalFileSegment.filingYear(for: "023.1/9–1454", documentDay: potsdam,
                                              documentYear: 1945) == 1954)
        #expect(DecimalFileSegment.filingYear(for: "023.1/9–1454", documentDay: nil,
                                              documentYear: nil) == 1954)
        // frus1943/d394: the number misprints the document's own day, so the document's year wins.
        #expect(DecimalFileSegment.filingYear(for: "740.0011 EW/8–2045",
                                              documentDay: .init(year: 1943, month: 8, day: 20),
                                              documentYear: 1943) == 1943)
        // A sequential item, a subject-numeric designator and no number carry no year.
        #expect(DecimalFileSegment.filingYear(for: "711.654/123", documentDay: nil, documentYear: 1925) == 1925)
        #expect(DecimalFileSegment.filingYear(for: "POL 27 VIET S", documentDay: nil, documentYear: 1966) == 1966)
        #expect(DecimalFileSegment.filingYear(for: nil, documentDay: nil, documentYear: 1950) == 1950)
        #expect(DecimalFileSegment.filingYear(for: nil, documentDay: nil, documentYear: nil) == nil)
    }

    /// The twins' period rows bind their year through `filingYear`. The Mac twin is compiled only
    /// for macOS, so no iOS test can draw it: this reads both files and checks each `if let year =`
    /// binding inside the period function, whole — the expression up to the `{` that opens the
    /// branch, parentheses balanced — and fails naming the file.
    @Test("Both Source Explorer twins' Filing Period rows read DecimalFileSegment.filingYear")
    func twinsReadTheFilingYear() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let sites = [("FRUSExplorer/SourceExplorer/SourceExplorerView.swift", "centralFilesPeriodSection"),
                     ("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift", "centralFilesPeriodBox")]
        let expected = "DecimalFileSegment.filingYear(for: fileIdentifier, documentDay: documentDay, documentYear: effectiveYear)"
        var bindingsRead = 0
        for (path, function) in sites {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let body = try Self.body(of: function, in: source, file: path)
            let bindings = Self.yearBindings(in: body)
            #expect(!bindings.isEmpty, "\(path): \(function) binds no `year` — the row moved?")
            for binding in bindings {
                bindingsRead += 1
                #expect(binding == expected, """
                    \(path): \(function) binds its period year as `\(binding)`. It must read the \
                    file's own year first (#1407), checked against the document's day (#1407 \
                    review), or the row names a different band from the basis line beside it.
                    """)
            }
        }
        #expect(bindingsRead == 2, "read \(bindingsRead) bindings across the two twins")
    }

    /// The `documentDay` both period rows pass is the one `load()` reads (#1407 review): a twin
    /// whose load never assigned it would pass `nil` for ever, and a misprinted year would stand
    /// on that platform alone. The read itself is driven through a real index in
    /// `DecimalFileYearNeighbourTests`; this checks each twin's `load()` calls it, with the
    /// document's key, and stores what it returns.
    @Test("Both Source Explorer twins' load() reads the document's day")
    func twinsLoadTheDocumentDay() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let call = "SourceExplorerDocumentContext.documentDay( pipeline: indexingPipeline, "
            + "volumeId: documentVolumeId, documentId: documentId)"
        for path in ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"] {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let body = try Self.body(of: "load", in: source, file: path)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            #expect(body.contains("let day = await \(call)"),
                    "\(path): load() does not read the document's day through \(call)")
            #expect(body.contains("documentDay = day"),
                    "\(path): load() reads the document's day but never stores it")
        }
    }

    /// `function`'s body, from its first `{` to the brace that closes it.
    private static func body(of function: String, in source: String, file: String) throws -> Substring {
        let head = try #require(source.range(of: "func \(function)("), "\(file) has no func \(function)")
        let open = try #require(source[head.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return source[open...index] }
            }
            index = source.index(after: index)
        }
        Issue.record("\(file): \(function)'s braces do not balance")
        return source[open...]
    }

    /// Every `if let year = …` binding's expression, whitespace collapsed: the text after `=` up
    /// to the `{` that opens the branch, at parenthesis depth zero.
    private static func yearBindings(in body: Substring) -> [String] {
        var results: [String] = []
        var rest = body[...]
        while let match = rest.range(of: "if let year = ") {
            var depth = 0
            var index = match.upperBound
            while index < rest.endIndex {
                let character = rest[index]
                if character == "(" { depth += 1 }
                if character == ")" { depth -= 1 }
                if character == "{", depth == 0 { break }
                index = rest.index(after: index)
            }
            results.append(rest[match.upperBound..<index]
                .split(whereSeparator: \.isWhitespace).joined(separator: " "))
            rest = rest[index...]
        }
        return results
    }
}
