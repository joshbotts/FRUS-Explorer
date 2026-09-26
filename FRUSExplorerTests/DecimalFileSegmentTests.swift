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
        #expect(DecimalFileSegment.segment(for: "POL 27 VIET S", fallbackYear: 1963) == nil)
        #expect(DecimalFileSegment.segment(for: "POL 17-3 JORDAN", fallbackYear: 1962) == nil)
        // A decimal-form ref with a 1963 fallback year IS decimal — the number decides.
        #expect(DecimalFileSegment.segment(for: "611.61/2200", fallbackYear: 1963)
                == "1960–January 1963")
        // And a decimal date-form suffix still resolves by its own embedded year.
        #expect(DecimalFileSegment.segment(for: "611.93/12-854", fallbackYear: nil)
                == "1950–1954")
    }

    @Test("The feature's worked example resolves to the right neighbor verdicts")
    func workedExample() {
        // 711.654/11-543 (1943) is a neighbor of 711.654/3-1342 (1942) — same location, segment.
        let a = (DecimalFileSegment.location(from: "711.654/11-543"),
                 DecimalFileSegment.segment(for: "711.654/11-543", fallbackYear: nil))
        let b = (DecimalFileSegment.location(from: "711.654/3-1342"),
                 DecimalFileSegment.segment(for: "711.654/3-1342", fallbackYear: nil))
        let c = (DecimalFileSegment.location(from: "711.654/8-147"),
                 DecimalFileSegment.segment(for: "711.654/8-147", fallbackYear: nil))
        let d = (DecimalFileSegment.location(from: "711.01/6-742"),
                 DecimalFileSegment.segment(for: "711.01/6-742", fallbackYear: nil))
        #expect(a == b)        // neighbors
        #expect(a != c)        // different segment (1945–1949)
        #expect(a != d)        // different location
    }

    @Test("Pre-1940 sequential refs fall back to the document's own year")
    func sequentialFallback() {
        // "711.654/123" has no suffix year; the document's 1925 date places it in 1910–1929.
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: 1925) == "1910–1929")
        // No suffix year and no fallback → no segment (caller does location-only matching).
        #expect(DecimalFileSegment.segment(for: "711.654/123", fallbackYear: nil) == nil)
    }
}

// MARK: - DecimalDateFormTests (#1407)

/// The date-form item as the corpus prints it (#1407).
///
/// FRUS writes the date form with an EN DASH (`611.93/12–854`) — 63,343 of the 63,998 date-form
/// file numbers the index stores — and `suffixYear` used to accept only an ASCII hyphen, so almost
/// none of them had a file year. The fix could not simply widen the dash, because a pre-1940
/// sequential item carries dashes for other reasons, and reading the last two digits of those minted
/// years. So every refusal below is one real corpus shape, named with the document it came from, and
/// each is written in BOTH spellings: the en dash the corpus prints, and the hyphen the old rule
/// read — so each fixture fails on the old rule (which dated the hyphen spelling) and on a naive
/// widening (which would date both).
@Suite("Decimal date-form item (#1407)")
struct DecimalDateFormTests {

    /// Every dash spelling of one date-form number gives one year.
    @Test("En dash, em dash, non-breaking hyphen and hyphen spellings give the same year")
    func everyDashSpellingGivesTheSameYear() {
        for dash in ["-", "\u{2013}", "\u{2014}", "\u{2011}"] {
            #expect(DecimalFileSegment.suffixYear(from: "611.93/12\(dash)854") == 1954,
                    "611.93/12\(dash)854 must read as 8 December 1954")
            #expect(DecimalFileSegment.segment(for: "611.93/12\(dash)854", fallbackYear: nil)
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

    /// A misprinted month or day still carries the right year, so neither is range-checked.
    @Test("A misprinted month or day keeps its year (frus1947v04/d12, frus1944v03/d1080)")
    func misprintsKeepTheirYear() {
        #expect(DecimalFileSegment.suffixYear(from: "870.00/0–2447") == 1947)
        #expect(DecimalFileSegment.suffixYear(from: "865.01/12–5441") == 1941)
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

    /// A half-numbered item (`1183–½`) — `½` is a number to `Character.isNumber`.
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

// MARK: - DecimalFileYearNeighbourTests (#1407)

/// `relatedByDecimal` bands both sides by the FILE's year, through the real index (#1407).
///
/// The anchor is a 1943 document citing `740.0011 EW/8–2045` — a 1945 file, in the 1945–1949
/// filing band. Before the fix the en dash gave it no file year, so it fell back to 1943 and drew
/// its neighbours from 1940–1944: the candidate filed 12–2845 but dated 1944 came in for the wrong
/// reason, the 1942 filing came in, and the 1946 filing and the hyphen-spelled 1945 filing stayed
/// out. The query runs at READ time over `series_name`, which stores the number verbatim, so this
/// needs no reindex — the fixture proves it by indexing once and reading through the fixed rule.
@Suite("Decimal neighbours by file year (#1407)")
struct DecimalFileYearNeighbourTests {

    /// One volume, five documents citing one decimal location in different filing years.
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
               frus:doc-dateTime-min="1944-12-28" frus:doc-dateTime-max="1944-12-28">
            <head>Filed across the band<note type="source">Source: Department of State, Central Files, 740.0011 EW/12–2845. Secret.</note></head>
            <p>Filed in 1945, dated 1944.</p>
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
        </body></text></TEI>
        """

    @Test("A 1943 document citing a 1945 file finds the 1945–1949 filings, whatever the dash")
    func neighboursShareTheFilesBand() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSDecimalBand-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try Data(Self.volumeXML.utf8).write(to: volDir.appendingPathComponent("frus1943v99.xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: dbURL),
                                            databaseURL: dbURL, volumesDirectory: volDir,
                                            concurrencyLimit: 1)
        try await pipeline.indexVolume("frus1943v99")

        // Fixture guard: every note parsed as a central file keyed on `740.0011 EW`. A sequential
        // anchor with no document year has no segment, so the query is location-only and must
        // reach all four other documents — otherwise the band assertion below could fail (or
        // pass) over an empty set.
        let unbanded = try await pipeline.relatedDocuments(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/123"),
            limit: 30, documentYear: nil,
            excludingVolumeId: "frus1943v99", excludingDocumentId: "d1")
        try #require(unbanded.totalCount == 4,
                     "the fixture's notes must key on 740.0011 EW; got \(unbanded.totalCount)")

        let related = try await pipeline.relatedDocuments(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8–2045"),
            limit: 30, documentYear: 1943,
            excludingVolumeId: "frus1943v99", excludingDocumentId: "d1")
        #expect(Set(related.documents.map(\.documentId)) == ["d2", "d3", "d5"], """
            The anchor's file is 8 August 1945, so its neighbours are the 1945–1949 filings: d2 \
            (1946), d3 (12–2845, dated 1944) and d5 (12-2745, hyphen). Got \
            \(related.documents.map(\.documentId).sorted()) — ["d3", "d4"] is the document-year \
            band the en dash used to fall back to.
            """)
        #expect(related.totalCount == 3)
    }
}

// MARK: - SourceExplorerBasisLineTests (#1407)

/// The Archival Neighbors basis line names the FILE's filing band (#1407), through the static the
/// section draws (`SourceExplorerView.archivalNeighborBasis(for:documentYear:)`).
@Suite("Source Explorer basis line (#1407)")
@MainActor
struct SourceExplorerBasisLineTests {

    @Test("An en-dash file names its own band, not the document's")
    func enDashFileNamesItsBand() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8–2045"),
            documentYear: 1943)
        // frus1943/d394 cites exactly this file: the document is 1943, the filing 1945.
        #expect(basis == "Same decimal file — 740.0011 EW, 1945–1949", "got \(basis ?? "nil")")
    }

    @Test("A hyphen spelling of the same file gives the same line")
    func hyphenGivesTheSameLine() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "740.0011 EW/8-2045"),
            documentYear: 1943)
        #expect(basis == "Same decimal file — 740.0011 EW, 1945–1949", "got \(basis ?? "nil")")
    }

    @Test("A sequential item still takes the document's year")
    func sequentialItemTakesTheDocumentYear() {
        let basis = SourceExplorerView.archivalNeighborBasis(
            for: .centralFiles(recordGroup: "RG-59", fileIdentifier: "711.654/123"),
            documentYear: 1925)
        #expect(basis == "Same decimal file — 711.654, 1910–1929", "got \(basis ?? "nil")")
    }
}

// MARK: - FilingPeriodYearTests (#1407)

/// Source Explorer's "Filing Period" row and its Archival Neighbors basis line name one band
/// (#1407). The basis line reads the file's own year once the en dash is read; the period row read
/// the document's year outright, so on the 206 stored notes whose file and document years fall in
/// different bands the two rows would have disagreed. Both platforms' period rows now read
/// `DecimalFileSegment.filingYear`.
@Suite("Filing period year (#1407)")
struct FilingPeriodYearTests {

    @Test("The file's own year wins; the document's year answers everything else")
    func filingYearPrefersTheFile() {
        // frus1943/d394: a 1943 document citing a 1945 file.
        #expect(DecimalFileSegment.filingYear(for: "740.0011 EW/8–2045", documentYear: 1943) == 1945)
        #expect(DecimalFileSegment.filingYear(for: "740.0011 EW/8–2045", documentYear: nil) == 1945)
        // A sequential item, a subject-numeric designator and no number carry no year.
        #expect(DecimalFileSegment.filingYear(for: "711.654/123", documentYear: 1925) == 1925)
        #expect(DecimalFileSegment.filingYear(for: "POL 27 VIET S", documentYear: 1966) == 1966)
        #expect(DecimalFileSegment.filingYear(for: nil, documentYear: 1950) == 1950)
        #expect(DecimalFileSegment.filingYear(for: nil, documentYear: nil) == nil)
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
        let expected = "DecimalFileSegment.filingYear(for: fileIdentifier, documentYear: effectiveYear)"
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
                    file's own year first (#1407), or the row names a different band from the \
                    basis line beside it.
                    """)
            }
        }
        #expect(bindingsRead == 2, "read \(bindingsRead) bindings across the two twins")
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
