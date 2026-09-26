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

// MARK: - CitationParserTests

struct CitationParserTests {

    private let parser = CitationParser()

    // MARK: - FullCitationTest

    @Test("CitationParserTest: parse history.state.gov recommended style")
    func fullCitationTest() {
        let raw = "Foreign Relations of the United States, 1969–1976, Volume I, Foundations of Foreign Policy, 1969–1972, eds. David Patterson (Washington: GPO, 2003), Document 15."
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.parserConfidence == .high)
    }

    // MARK: - ChicagoShortTest

    @Test("CitationParserTest: parse Chicago short footnote")
    func chicagoShortTest() {
        let raw = "FRUS, 1969–76, I, doc. 15"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.pageNumber == nil)
    }

    // MARK: - ChicagoFullTest

    @Test("CitationParserTest: parse Chicago full footnote with page number")
    func chicagoFullTest() {
        let raw = "Foreign Relations of the United States, 1969–1976, vol. I, doc. 15, p. 47"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
        #expect(result.pageNumber == 47)
    }

    // MARK: - PageOnlyTest

    @Test("CitationParserTest: parse page-only citation (no document number)")
    func pageOnlyTest() {
        let raw = "FRUS, 1952–1954, vol. XIV, p. 847"
        let result = parser.parse(raw)
        #expect(result.subseries == "1952-54")
        #expect(result.pageNumber == 847)
        #expect(result.documentNumber == nil)
    }

    // MARK: - InformalTest

    @Test("CitationParserTest: parse informal citation with Arabic volume and 'no.' prefix")
    func informalTest() {
        let raw = "FRUS 1969-76, vol. 1, no. 15"
        let result = parser.parse(raw)
        #expect(result.subseries == "1969-76")
        // Arabic "1" should be normalized to Roman "I"
        #expect(result.volumeNumber == "I")
        #expect(result.documentNumber == 15)
    }

    // MARK: - HyphenVariantTest

    @Test("CitationParserTest: hyphen, en dash, and full-year variants all extract same subseries")
    func hyphenVariantTest() {
        let hyphen    = parser.extractSubseries(from: "FRUS 1969-76, vol. I")
        let enDash    = parser.extractSubseries(from: "FRUS 1969–76, vol. I")
        let fullYear  = parser.extractSubseries(from: "FRUS 1969–1976, vol. I")

        #expect(hyphen == "1969-76")
        #expect(enDash == "1969-76")
        #expect(fullYear == "1969-76")
        #expect(hyphen == enDash)
        #expect(hyphen == fullYear)
    }

    // MARK: - VolumeNormalizationTest

    @Test("CitationParserTest: 'vol. I', 'v. I', 'vol. 1', 'Volume I' all normalize to 'I'")
    func volumeNormalizationTest() {
        let forms = [
            "FRUS, 1969–76, vol. I, doc. 1",
            "FRUS, 1969–76, v. I, doc. 1",
            "FRUS, 1969–76, vol. 1, doc. 1",
            "FRUS, 1969–76, Volume I, doc. 1",
        ]
        let volumes = forms.compactMap { parser.extractVolumeNumber(from: $0) }
        #expect(volumes.count == 4, "Expected all 4 forms to parse")
        let unique = Set(volumes)
        #expect(unique.count == 1, "Expected all forms to normalize to the same value, got \(unique)")
        #expect(unique.first == "I")
    }

    // MARK: - MalformedTest

    @Test("CitationParserTest: malformed/OCR-corrupted citation still extracts partial fields")
    func malformedTest() {
        // Simulated OCR artifact: missing comma, extra spaces, wrong en-dash encoding
        let raw = "Foreign Relations United States 1969 1976  vol I  doc15"
        let result = parser.parse(raw)
        // Should extract year even from malformed text
        #expect(result.subseries != nil || result.volumeNumber != nil || result.documentNumber != nil,
                "Expected at least one field extracted from malformed text")
        // Confidence should reflect poor parse
        #expect(result.parserConfidence == .low || result.parserConfidence == .medium)
    }

    // MARK: - RealTimeTest

    @Test("CitationParserTest: incremental parsing — final result matches full parse")
    func realTimeTest() {
        let full = "FRUS, 1969–76, vol. I, doc. 15"
        let finalResult = parser.parse(full)

        // Parse progressively longer substrings — none should crash
        for end in stride(from: 1, through: full.count, by: 1) {
            let idx = full.index(full.startIndex, offsetBy: end)
            let partial = String(full[..<idx])
            let _ = parser.parse(partial) // must not crash
        }

        #expect(finalResult.subseries == "1969-76")
        #expect(finalResult.documentNumber == 15)
    }

    // MARK: - SingleYearTest

    @Test("CitationParserTest: single-year subseries (e.g. 1861) is extracted correctly")
    func singleYearSubseriesTest() {
        let result = parser.parse("FRUS 1861, vol. I, doc. 3")
        #expect(result.subseries == "1861")
    }

    // MARK: - VolumeXIVTest

    @Test("CitationParserTest: multi-digit Roman numeral volume XIV extracted correctly")
    func volumeXIVTest() {
        let vol = parser.extractVolumeNumber(from: "FRUS, 1952–54, vol. XIV, p. 847")
        #expect(vol == "XIV")
    }

    // MARK: - Part (#1474)

    @Test("CitationParserTest: 'pt. N', 'part N', 'Part N' and 'Part II' parse to the volume's part (#1474)")
    func partNumberTest() {
        let cases: [(text: String, part: Int)] = [
            ("FRUS, 1952–1954, vol. II, pt. 1, doc. 41", 1),
            ("FRUS, 1952–1954, vol. II, pt. 2, doc. 41", 2),
            ("FRUS 1964–68, vol. XXIX, part 1, doc. 3", 1),
            // The app's own citation of a part volume carries the manifest title's "Part 2".
            ("Foreign Relations of the United States, 1952–1954, National Security Affairs, Volume II, Part 2, Document 41.", 2),
            // The pre-1906 titles print the part in Roman, and #216's round trip rides on it.
            ("Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the First Session Thirty-eighth Congress, Part II, Document 1.", 2),
        ]
        for c in cases {
            #expect(parser.parse(c.text).partNumber == c.part, "\(c.text)")
        }
        // The part leaves the volume numeral alone.
        #expect(parser.parse("FRUS, 1952–1954, vol. II, pt. 1, doc. 41").volumeNumber == "II")
    }

    @Test("CitationParserTest: a word that merely contains 'part' or 'pt' names no part (#1474)")
    func partNumberNegativeTest() {
        let texts = [
            "FRUS, 1961–1963, vol. V, doc. 84",
            "Telegram from the Department of State, Sept. 5, 1962, doc. 3",
            "A counterpart 2 memorandum, FRUS, 1961–1963, vol. V, doc. 84",
            "Part of the record: FRUS, 1961–1963, vol. V, doc. 84",
            // The numeral must end at a word boundary: "Iran" begins with the numeral I (#1474
            // review round 1 — without the closing `\b` this parsed as part 1).
            "On the Part Iran played: FRUS, 1952–1954, vol. X, doc. 5",
        ]
        for text in texts {
            #expect(parser.parse(text).partNumber == nil, "\(text)")
        }
    }

    @Test("CitationParserTest: a Part field accepts Arabic or Roman and nothing else (#1474)")
    func normalizedPartNumberTest() {
        #expect(CitationParser.normalizedPartNumber("2") == 2)
        #expect(CitationParser.normalizedPartNumber(" 1 ") == 1)
        #expect(CitationParser.normalizedPartNumber("II") == 2)
        #expect(CitationParser.normalizedPartNumber("iv") == 4)
        #expect(CitationParser.normalizedPartNumber("") == nil)
        #expect(CitationParser.normalizedPartNumber("0") == nil)
        #expect(CitationParser.normalizedPartNumber("two") == nil)
    }

    // MARK: - history.state.gov links (#1474)

    @Test("CitationParserTest: a history.state.gov document link parses to its exact volume and document (#1474)")
    func historyStateGovLinkTest() {
        let parsed = parser.parse("https://history.state.gov/historicaldocuments/frus1952-54v02p1/d41")
        #expect(parsed.exactReference == CitationExactReference(volumeId: "frus1952-54v02p1", documentId: "d41"))
        #expect(parsed.subseries == "1952-54")
        #expect(parsed.volumeNumber == "II")
        #expect(parsed.partNumber == 1)
        #expect(parsed.documentNumber == 41)
        #expect(parsed.pageNumber == nil)
        #expect(parsed.titleFragment == nil)
        #expect(parsed.isActionable)
    }

    @Test("CitationParserTest: the app's own FRUSCanonicalURL round-trips through the parser for every id shape (#1474)")
    func canonicalURLRoundTripTest() {
        // One row per volume-id shape in the bundled manifest that a link can carry, and one per
        // document-id shape in the corpus: `d` plus digits, with a letter suffix (`d373a`, and
        // `d550A`, the corpus's one capitalised suffix), and every shape among the 866 ids that are
        // not `d` plus digits and letters at all (#1474 review round 1; the last four rows review
        // round 2) — `d710a-1` (217 in frus1945Berlinv02), `eta_d1` (628 in frus1958-60v05mSupp),
        // the frus1981-88 appendices' three spellings `appA` (v05, v11, v44p1), `appxA` (v04) and
        // `appendix-A` (v01), and frus1902app1's two section-shaped ids `s12` and `s05sub04`. Each
        // id must come back exactly as the app wrote it.
        let shapes: [(volumeId: String, documentId: String, number: Int?)] = [
            ("frus1961-63v05", "d84", 84),
            ("frus1952-54v02p1", "d41", 41),
            ("frus1865p1", "d373a", nil),
            ("frus1919Parisv01", "d5", 5),
            ("frus1969-76ve05p1", "d10", 10),
            ("frus1872p2v1", "d3", 3),
            ("frus1961-63v07-09mSupp", "d1", 1),
            ("frus1913", "d707", 707),
            ("frus1955-57v03mSupp", "d550A", nil),
            ("frus1945Berlinv02", "d710a-1", nil),
            ("frus1958-60v05mSupp", "eta_d1", nil),
            ("frus1981-88v05", "appA", nil),
            ("frus1981-88v04", "appxA", nil),
            ("frus1981-88v01", "appendix-A", nil),
            ("frus1902app1", "s12", nil),
            ("frus1902app1", "s05sub04", nil),
        ]
        for shape in shapes {
            let url = FRUSCanonicalURL.string(volumeId: shape.volumeId, documentId: shape.documentId)
            let parsed = parser.parse(url)
            #expect(parsed.exactReference == CitationExactReference(volumeId: shape.volumeId,
                                                                    documentId: shape.documentId),
                    "\(url)")
            #expect(parsed.documentNumber == shape.number, "\(url)")
            #expect(parsed.isActionable, "\(url)")
        }
    }

    @Test("CitationParserTest: a link's page, section and decorations are read as the site means them (#1474)")
    func historyStateGovLinkVariantsTest() {
        // A page link names the volume and a page in it.
        let page = parser.parse("https://history.state.gov/historicaldocuments/frus1961-63v14/pg_50")
        #expect(page.exactReference == CitationExactReference(volumeId: "frus1961-63v14", documentId: nil))
        #expect(page.pageNumber == 50)
        #expect(page.documentNumber == nil)

        // A chapter link carries its segment as written, for the matcher to look up: nothing in
        // the address tells `ch3` from a document id such as `eta_d1` (#1474 review round 1).
        let chapter = parser.parse("https://history.state.gov/historicaldocuments/frus1961-63v14/ch3")
        #expect(chapter.exactReference == CitationExactReference(volumeId: "frus1961-63v14", documentId: "ch3"))
        #expect(chapter.volumeNumber == "XIV")
        #expect(chapter.documentNumber == nil)

        // A volume link carries no segment.
        let volume = parser.parse("https://history.state.gov/historicaldocuments/frus1961-63v14")
        #expect(volume.exactReference == CitationExactReference(volumeId: "frus1961-63v14", documentId: nil))

        // A fragment, a query, a trailing slash, plain http, and a link inside prose.
        let decorated = [
            "http://history.state.gov/historicaldocuments/frus1961-63v05/d84#fn3",
            "https://history.state.gov/historicaldocuments/frus1961-63v05/d84/",
            "https://history.state.gov/historicaldocuments/frus1961-63v05/d84?q=Khrushchev",
            "FRUS, 1961–1963, vol. XIV, p. 50 (https://history.state.gov/historicaldocuments/frus1961-63v05/d84).",
        ]
        for text in decorated {
            let parsed = parser.parse(text)
            #expect(parsed.exactReference == CitationExactReference(volumeId: "frus1961-63v05", documentId: "d84"),
                    "\(text)")
            // The link's ids decide every field, so the prose around it cannot contradict them.
            #expect(parsed.volumeNumber == "V", "\(text)")
            #expect(parsed.documentNumber == 84, "\(text)")
            #expect(parsed.pageNumber == nil, "\(text)")
        }

        // Prose with no link carries no reference.
        #expect(parser.parse("FRUS, 1961–1963, vol. V, doc. 84").exactReference == nil)
    }

    @Test("CitationParserTest: a link naming only a volume or a section keeps the document and page printed beside it (#1474 review round 1)")
    func linkBesideProseKeepsItsDocument() {
        // The Chicago shape: a document number, then the volume's URL. The link decides the
        // volume, and the prose the document it does not name.
        // The prose's own volume fields travel with the reference (#1474 review round 2), for the
        // matcher to check the document the prose chooses against.
        let chicago = parser.parse("FRUS, 1961–1963, vol. V, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05.")
        #expect(chicago.exactReference == CitationExactReference(
            volumeId: "frus1961-63v05", documentId: nil,
            prose: CitationVolumeFields(subseries: "1961-63", volumeNumber: "V")))
        #expect(chicago.subseries == "1961-63")
        #expect(chicago.volumeNumber == "V")
        #expect(chicago.documentNumber == 84)
        #expect(chicago.pageNumber == nil)

        // A section link, in parentheses, beside a page.
        let section = parser.parse("FRUS, 1961–1963, vol. XIV, p. 50 (https://history.state.gov/historicaldocuments/frus1961-63v14/ch3).")
        #expect(section.exactReference == CitationExactReference(
            volumeId: "frus1961-63v14", documentId: "ch3",
            prose: CitationVolumeFields(subseries: "1961-63", volumeNumber: "XIV")))
        #expect(section.pageNumber == 50)
        #expect(section.documentNumber == nil)

        // The prose never decides the volume: the link's id does, even where the two disagree.
        // What the prose named is kept beside it, part included, so the disagreement is not lost.
        let disagreeing = parser.parse("FRUS, 1961–1963, vol. XIV, pt. 2, doc. 84, https://history.state.gov/historicaldocuments/frus1961-63v05")
        #expect(disagreeing.volumeNumber == "V")
        #expect(disagreeing.partNumber == nil)
        #expect(disagreeing.documentNumber == 84)
        #expect(disagreeing.exactReference?.prose
                == CitationVolumeFields(subseries: "1961-63", volumeNumber: "XIV", partNumber: 2))

        // A link with no prose beside it carries none.
        #expect(parser.parse("https://history.state.gov/historicaldocuments/frus1961-63v05").exactReference?.prose == nil)

        // A link to a document by a number-bearing id still decides the document itself.
        let document = parser.parse("FRUS, 1961–1963, vol. V, doc. 12, https://history.state.gov/historicaldocuments/frus1961-63v05/d84")
        #expect(document.documentNumber == 84)
        // …and reads nothing from the prose, whose fields therefore carry nothing to check.
        #expect(document.exactReference?.prose == nil)
    }

    @Test("CitationParserTest: a link to an E-volume fills the Volume field with its E-number (#1474 review round 1)")
    func eVolumeLinkFillsTheVolume() {
        let parsed = parser.parse(FRUSCanonicalURL.string(volumeId: "frus1969-76ve05p1", documentId: "d10"))
        #expect(parsed.volumeNumber == "E-5")
        #expect(parsed.partNumber == 1)
        #expect(parser.parse(FRUSCanonicalURL.string(volumeId: "frus1969-76ve16", documentId: "d1")).volumeNumber == "E-16")
        // A single-volume year, and a range, name no volume.
        #expect(parser.parse(FRUSCanonicalURL.string(volumeId: "frus1913", documentId: "d707")).volumeNumber == nil)
        #expect(parser.parse(FRUSCanonicalURL.string(volumeId: "frus1961-63v07-09mSupp", documentId: "d1")).volumeNumber == nil)
    }

    @Test("CitationParserTest: the subseries is the year the series names, not the date a footnote opens with (#1474 review round 3)")
    func subseriesIsTheYearTheSeriesNames() {
        // The commonest footnote: the document's own date first, then the publication. The first
        // year in it is 1962, which no volume carries.
        let dated = "Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84"
        #expect(parser.extractSubseries(from: dated) == "1961-63")
        let parsed = parser.parse(dated)
        #expect(parsed.subseries == "1961-63")
        #expect(parsed.volumeNumber == "V")
        #expect(parsed.documentNumber == 84)

        // Beside a link, the prose's own subseries is read the same way.
        let linked = parser.parse(dated + ", https://history.state.gov/historicaldocuments/frus1961-63v05")
        #expect(linked.exactReference?.prose == CitationVolumeFields(subseries: "1961-63", volumeNumber: "V"))

        // A single-year subseries is read too: a 1950 volume prints late-1949 documents.
        #expect(parser.extractSubseries(from: "Memorandum, December 30, 1949, FRUS, 1950, vol. VII, doc. 1") == "1950")
        #expect(parser.extractSubseries(from: "FRUS, 1950, vol. VII, doc. 1") == "1950")

        // The series spelled out, italicised as the app writes it, or with a subtitle between the
        // name and its year.
        #expect(parser.extractSubseries(
            from: "Telegram, June 3, 1970, _Foreign Relations of the United States_, 1969–1976, Volume I") == "1969-76")
        #expect(parser.extractSubseries(
            from: "Memorandum, December 31, 1942, Foreign Relations of the United States, Diplomatic Papers, 1943, China") == "1943")
        #expect(parser.extractSubseries(
            from: "Minutes, January 12, 1942, Foreign Relations, The Conferences at Washington, 1941–1942, and Casablanca, 1943") == "1941-42")

        // A committee named before the date is not the series.
        #expect(parser.extractSubseries(
            from: "Letter to the Senate Committee on Foreign Relations, May 5, 1962, FRUS, 1961–1963, vol. V") == "1961-63")

        // No series named: the first year, as before.
        #expect(parser.extractSubseries(from: "1961–1963, vol. V, doc. 84") == "1961-63")
        #expect(parser.extractSubseries(from: "Memorandum, May 5, 1962, vol. V, doc. 84") == "1962")
    }

    @Test("CitationParserTest: a series named with no year after it falls back to the first year, and the name is a whole word (#1474 review round 4)")
    func seriesNameFallbackAndWordBoundary() {
        // The series is named, but no year follows it: the first year in the text, rather than
        // nothing. No manifest title reaches this branch, so only this row, and the reading
        // `proseSubseriesSaysHowItWasRead` pins for it beside a link, cover it.
        #expect(parser.extractSubseries(from: "Memorandum, May 5, 1962, FRUS, vol. V, doc. 84") == "1962")

        // A word that begins with the series' name is not the series: "Frustrated" is not "FRUS",
        // and "Foreign Relationship" is not "Foreign Relations". Read as the series, each sent the
        // subseries to the year after it, 1955.
        #expect(parser.extractSubseries(from: "Frustrated Allies, 1955, FRUS, 1961–1963, vol. V") == "1961-63")
        #expect(parser.extractSubseries(
            from: "Report on the Foreign Relationship, 1955, Foreign Relations, 1961–1963") == "1961-63")
    }

    @Test("CitationParserTest: beside a link, the text's subseries says whether it followed the series' name or was the text's first year (#1474 review round 5)")
    func proseSubseriesSaysHowItWasRead() {
        let v05 = "https://history.state.gov/historicaldocuments/frus1961-63v05"
        func prose(_ text: String) -> CitationVolumeFields? {
            parser.parse("\(text), \(v05)").exactReference?.prose
        }
        // After the series' name — each form of it, and past a committee named before the date:
        // the text names a volume of the series, and the matcher checks it.
        let afterName: [(text: String, subseries: String, volume: String)] = [
            ("FRUS, 1961–1963, vol. XXIII, doc. 5", "1961-63", "XXIII"),
            ("Foreign Relations of the United States, 1964–1968, Volume V, doc. 84", "1964-68", "V"),
            ("Foreign Relations, 1933, vol. I, doc. 12", "1933", "I"),
            ("Memorandum of Conversation, Moscow, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84", "1961-63", "V"),
            ("Letter to the Senate Committee on Foreign Relations, May 5, 1962, FRUS, 1961–1963, vol. V, doc. 84",
             "1961-63", "V"),
        ]
        for row in afterName {
            #expect(prose(row.text) == CitationVolumeFields(subseries: row.subseries,
                                                            subseriesReading: .afterSeriesName,
                                                            volumeNumber: row.volume),
                    "\(row.text): \(String(describing: prose(row.text)))")
        }

        // The text's first year: the link is the note's only "frus", so its text names no series
        // — or names it with no year after it — and a single year is the date the note opens
        // with. A range comes before it since #1507: `May 5, 1962, 1961–1963` read 1962 until then.
        let firstYear: [(text: String, subseries: String)] = [
            ("Memorandum of Conversation, Moscow, May 5, 1962, vol. V, doc. 84", "1962"),
            ("National Intelligence Estimate, December 1, 1960, vol. V, doc. 1", "1960"),
            ("May 5, 1962, 1961–1963, vol. V, doc. 84", "1961-63"),
            ("1961–1963, vol. V, doc. 84", "1961-63"),
            ("Memorandum, December 1, 1960, FRUS, vol. V, doc. 1", "1960"),
        ]
        for row in firstYear {
            #expect(prose(row.text) == CitationVolumeFields(subseries: row.subseries,
                                                            subseriesReading: .firstYear,
                                                            volumeNumber: "V"),
                    "\(row.text): \(String(describing: prose(row.text)))")
        }

        // No year at all: no reading either.
        #expect(prose("vol. V, doc. 84") == CitationVolumeFields(volumeNumber: "V"))
        #expect(prose("vol. V, doc. 84")?.subseriesReading == nil)
    }

    @Test("CitationParserTest: with no series named, a range is read before a single year, which is read only when the text gives no range (#1507)")
    func rangeBeforeASingleYear() {
        // Issue #1507's first shape: the note's date came first and was read as the subseries,
        // which no volume carries.
        #expect(parser.extractSubseries(from: "Memorandum, May 5, 1962, 1961–1963, vol. V, doc. 84") == "1961-63")
        #expect(parser.extractSubseries(from: "Telegram, Tehran, August 19, 1951, 1952–54, vol. X, doc. 5") == "1952-54")
        // With no range, the single year is all there is.
        #expect(parser.extractSubseries(from: "Memorandum, May 5, 1962, vol. V, doc. 84") == "1962")
        #expect(parser.parse("Memorandum, May 5, 1962, 1961–1963, vol. V, doc. 84").subseries == "1961-63")
    }

    @Test("CitationParserTest: a year follows the series' name only with no other number between them, and every place the series is named is tried (#1507)")
    func yearAfterTheSeriesNameHasNoNumberBefore() {
        let v05 = "https://history.state.gov/historicaldocuments/frus1961-63v05"
        func prose(_ text: String) -> CitationVolumeFields? {
            parser.parse("\(text), \(v05)").exactReference?.prose
        }
        // Issue #1507's third shape: the year after "FRUS" is the note's date, behind a volume, a
        // document number and a day; after a committee's "Foreign Relations", behind a day. Each
        // read as the series' year until #1507, and was checked against the link's volume.
        for text in ["FRUS, vol. V, doc. 84, Memorandum, May 5, 1962",
                     "Senate Committee on Foreign Relations, May 5, 1962, vol. V, doc. 84"] {
            #expect(prose(text) == CitationVolumeFields(subseries: "1962", subseriesReading: .firstYear,
                                                        volumeNumber: "V"),
                    "\(text): \(String(describing: prose(text)))")
        }
        // Words between are a title's: a subtitle, or the volume and title a note gives when it
        // cites a volume of its own subseries. A narrower rule refusing a locator or a month here
        // lost 4 of the 25 such citations in the corpus's own footnotes.
        #expect(prose("Foreign Relations, volume XV, Soviet Union, June 1972–August 1974, Document 1")
                == CitationVolumeFields(subseries: "1972", subseriesReading: .afterSeriesName, volumeNumber: "XV"))
        #expect(parser.extractSubseries(
            from: "Foreign Relations of the United States, Diplomatic Papers, The Conference of Berlin (The Potsdam Conference), 1945, Volume I") == "1945")
        // The committee named first has no year after it with no number between, so the next
        // naming of the series is tried: the one the footnote cites.
        let committee = "Statement by Assistant Secretary Thorp before the Senate Foreign Relations Committee on June 10, 1949; see the editorial note in Foreign Relations, 1950, vol. ii, p. 679."
        #expect(parser.extractSubseries(from: committee) == "1950")
        // A range with no series named beside a link is carried as a first-year read; the matcher
        // checks it because it is a range (`CitationMatchingEngine.namesSubseries`).
        #expect(prose("1964–68, vol. V, doc. 84") == CitationVolumeFields(subseries: "1964-68",
                                                                          subseriesReading: .firstYear,
                                                                          volumeNumber: "V"))
    }

    @Test("CitationParserTest: the title fragment keeps the series' name, spells out FRUS, and drops the editors and a Turabian publication statement (#1505)")
    func titleFragmentIsTheTitlesWords() throws {
        func words(_ text: String) throws -> [String] {
            let fragment = try #require(parser.parse(text).titleFragment, "\(text)")
            return fragment.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        // Turabian prints the publication statement outside parentheses; its words sent 13
        // pre-1906 part volumes to the next print year's.
        let turabian = try words("*Papers Relating to Foreign Affairs, Accompanying the Annual Message of the President to the First Session Thirty-eighth Congress, Part I*. Washington, D.C.: Government Printing Office, 1864. Document 1.")
        #expect(turabian.contains("congress") && turabian.contains("part"), "\(turabian)")
        for word in ["washington", "government", "printing", "office"] {
            #expect(!turabian.contains(word), "\(word) in \(turabian)")
        }
        // A title that names Washington keeps it: the statement is Washington followed by a colon.
        let conferences = try words("Foreign Relations of the United States, The Conferences at Washington, 1941–1942, and Casablanca, 1943, Document 1.")
        #expect(conferences.contains("washington"), "\(conferences)")
        // Editors in each form: Chicago's `edited by`, Turabian's `Edited by`, and every name of
        // the history.state.gov form's `eds.` — whose second and third names stayed after a comma.
        let chicago = try words("*Foreign Relations of the United States, Diplomatic Papers, 1943, China*, edited by G. Bernard Noble and E. R. Perkins (Washington, D.C.: Government Printing Office, 1957), Document 1.")
        let turabianEditors = try words("*Papers Relating to the Foreign Relations of the United States, 1919, Russia*. Edited by Joseph V. Fuller. Washington, D.C.: Government Printing Office, 1937. Document 1.")
        let history = try words("_Foreign Relations of the United States_, 1961–1963, Volume V, Soviet Union, eds. Charles S. Sampson, John Michael Joyce, and David S. Patterson (Washington, D.C.: Government Printing Office, 1998), Document 1.")
        for (fragment, names) in [(chicago, ["edited", "noble", "perkins"]),
                                  (turabianEditors, ["edited", "fuller", "washington"]),
                                  (history, ["eds", "sampson", "joyce", "patterson"])] {
            for name in names {
                #expect(!fragment.contains(name), "\(name) in \(fragment)")
            }
        }
        #expect(chicago.contains("china") && turabianEditors.contains("russia") && history.contains("soviet"))
        // The series' name stays, as Copy Citation's plain text begins with it, and "FRUS" is
        // spelled out: a title can then be printed whole.
        #expect(try words("Foreign Relations of the United States, 1952–1954, Iran, 1951–1954, Document 1.").prefix(6)
                == ["foreign", "relations", "of", "the", "united", "states"])
        #expect(try words("FRUS, 1952–1954, Iran, 1951–1954, doc. 5").prefix(6)
                == ["foreign", "relations", "of", "the", "united", "states"])
    }
}

// MARK: - CitationLookupFieldsTests

/// The Citation Lookup form's fields, driven through the same `refreshed` / `input` calls the view
/// makes (#1474).
struct CitationLookupFieldsTests {

    private let parser = CitationParser()

    /// Applies a sequence of pastes the way the view's `onChange(of: pasteText)` does.
    private func pasting(_ texts: [String], into start: CitationLookupFields = CitationLookupFields()) -> CitationLookupFields {
        texts.reduce(start) { $0.refreshed(forPaste: $1, mode: .paste, parser: parser) }
    }

    @Test("A second paste re-derives every field: a Volume the new citation omits is empty (#1474)")
    func secondPasteEmptiesAnOmittedVolume() {
        let first = pasting(["FRUS, 1952-1954, vol. IV, doc. 90"])
        #expect(first.volume == "IV")
        #expect(first.document == "90")

        let second = pasting(["FRUS, 1913, doc. 707"], into: first)
        #expect(second.subseries == "1913")
        #expect(second.volume == "")
        #expect(second.document == "707")
    }

    @Test("A page-only citation after a document citation carries no Document into the lookup (#1474)")
    func pageOnlyAfterDocumentCarriesNoDocument() {
        let text = "FRUS, 1961–1963, vol. XIV, p. 50"
        let fields = pasting(["FRUS, 1961–1963, vol. V, doc. 84", text])
        #expect(fields.document == "")
        let input = fields.input(mode: .paste, pasteText: text, parser: parser)
        #expect(input.documentNumber == nil)
        #expect(input.pageNumber == 50)
        #expect(input.volumeNumber == "XIV")
    }

    @Test("Clearing the paste box empties every field and the hidden fragment (#1474)")
    func clearingThePasteEmptiesEverything() {
        let full = pasting(["Foreign Relations of the United States, 1952–1954, National Security Affairs, Volume II, Part 2, Document 41, p. 1050"])
        #expect(!full.subseries.isEmpty && !full.volume.isEmpty && !full.part.isEmpty
                && !full.document.isEmpty && !full.page.isEmpty)
        #expect(full.titleFragment != nil)

        for cleared in ["", "   \n"] {
            let fields = pasting([cleared], into: full)
            #expect(fields.subseries == "", "\(cleared.debugDescription)")
            #expect(fields.volume == "")
            #expect(fields.part == "")
            #expect(fields.document == "")
            #expect(fields.page == "")
            #expect(fields.titleFragment == nil)
            #expect(fields.exactReference == nil)
            #expect(!fields.isActionable(mode: .paste, pasteText: cleared, parser: parser))
        }
    }

    @Test("Entering Paste from Batch re-derives the fields from the text Batch changed (#1474)")
    func batchToPasteRederives() {
        let pasted = pasting(["FRUS, 1952-1954, vol. IV, doc. 90"])
        // Batch edited the shared text; no paste field was mounted to re-parse it.
        let batchText = "FRUS, 1913, doc. 707"
        let entered = pasted.refreshed(forPaste: batchText, mode: .paste, parser: parser)
        #expect(entered.volume == "")
        #expect(entered.document == "707")
        #expect(entered.subseries == "1913")
    }

    @Test("Entering Paste from Structured keeps the reader's structured edits (#1474)")
    func structuredToPasteKeepsEdits() {
        let text = "FRUS, 1952-1954, vol. IV, doc. 90"
        var fields = pasting([text])
        fields.document = "91"   // edited in Structured Entry; the paste text did not change
        let entered = fields.refreshed(forPaste: text, mode: .paste, parser: parser)
        #expect(entered.document == "91")
        #expect(entered.volume == "IV")
        // And a mode that is not Paste never re-derives anything.
        let structured = fields.refreshed(forPaste: "FRUS, 1913, doc. 707", mode: .structured, parser: parser)
        #expect(structured == fields)
    }

    @Test("Batch mode's Look Up follows the footnote block, not the Parsed Fields (#1474)")
    func batchActionableFollowsTheBlock() {
        let block = "1. FRUS, 1961–1963, vol. V, doc. 84.\n2. FRUS, 1961–1963, vol. XIV, p. 50."
        let empty = CitationLookupFields()
        #expect(empty.isActionable(mode: .batch, pasteText: block, parser: parser))
        #expect(!empty.isActionable(mode: .batch, pasteText: "  \n ", parser: parser))
        var filled = empty
        filled.document = "84"
        #expect(!filled.isActionable(mode: .batch, pasteText: "", parser: parser))
    }

    @Test("A pasted link enables Look Up and is forwarded exactly; an edited field withdraws it (#1474)")
    func linkForwardedOnlyWhileUnedited() {
        let url = "https://history.state.gov/historicaldocuments/frus1865p1/d373a"
        let fields = pasting([url])
        #expect(fields.document == "")   // d373a has no number to show
        #expect(fields.isActionable(mode: .paste, pasteText: url, parser: parser))
        #expect(fields.input(mode: .paste, pasteText: url, parser: parser).exactReference
                == CitationExactReference(volumeId: "frus1865p1", documentId: "d373a"))

        // A field the reader changed is what they will be looking up, so the link stops deciding.
        var edited = fields
        edited.document = "12"
        let editedInput = edited.input(mode: .paste, pasteText: url, parser: parser)
        #expect(editedInput.exactReference == nil)
        #expect(editedInput.documentNumber == 12)

        // Structured Entry never forwards a link it cannot show.
        #expect(fields.input(mode: .structured, pasteText: url, parser: parser).exactReference == nil)
        #expect(!fields.isActionable(mode: .structured, pasteText: url, parser: parser))
    }

    @Test("Structured Entry's Part field reaches the lookup as a part number (#1474)")
    func structuredPartField() {
        var fields = CitationLookupFields()
        fields.subseries = "1952-54"
        fields.volume = "II"
        fields.document = "41"
        fields.part = "2"
        #expect(fields.input(mode: .structured, pasteText: "", parser: parser).partNumber == 2)
        fields.part = "II"
        #expect(fields.input(mode: .structured, pasteText: "", parser: parser).partNumber == 2)
        fields.part = ""
        #expect(fields.input(mode: .structured, pasteText: "", parser: parser).partNumber == nil)
    }

    @Test("A pasted part fills the Part field (#1474)")
    func pastedPartFillsThePartField() {
        #expect(pasting(["FRUS, 1952–1954, vol. II, pt. 2, doc. 41"]).part == "2")
    }
}

// MARK: - CitationLookupViewWiringTests

/// Pins that `CitationLookupView` makes the `CitationLookupFields` calls `CitationLookupFieldsTests`
/// drives (#1474 review round 1).
///
/// The fields' rules are tested as a value type, which is only worth something if the view calls
/// them: #1474's own defect was view wiring — an `onChange(of: pasteText)` that assigned
/// `parsed.x ?? oldValue` — and three plausible regressions (a deleted mode re-derive, the old
/// three-field Look Up gate, a lookup input rebuilt by hand without its part and link) passed every
/// one of #1474's tests. The view needs an `AppState` and a live form, and the by-eye pass could
/// not type into its paste field, so this reads the view's source instead. Each check is scoped to
/// ONE handler's body, with its comments removed, and matches ONE call statement in it — not a
/// substring anywhere in the file, which a stray comment or a sibling handler would satisfy.
struct CitationLookupViewWiringTests {

    /// The view's source.
    private static func viewSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("FRUSExplorer/Citation/CitationLookupView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The brace-delimited body that follows the one occurrence of `anchor` in `source`, braces
    /// included, with `//` comments removed and whitespace collapsed to single spaces; `nil` when
    /// `anchor` does not occur exactly once, or no balanced body follows it.
    ///
    /// String literals are skipped when counting braces, escapes included, so an interpolation
    /// such as `"\(match.volumeId)"` does not end the scan; the bodies read here hold no block
    /// comments or raw strings.
    static func body(after anchor: String, in source: String) -> String? {
        let occurrences = source.ranges(of: anchor)
        guard occurrences.count == 1,
              var index = source[occurrences[0].upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var code = ""
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            if inString {
                code.append(character)
                if character == "\\", next < source.endIndex {
                    code.append(source[next])
                    index = source.index(after: next)
                    continue
                }
                if character == "\"" { inString = false }
                index = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                index = source[index...].firstIndex(of: "\n") ?? source.endIndex
                continue
            }
            code.append(character)
            switch character {
            case "\"": inString = true
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return code.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                }
            default: break
            }
            index = next
        }
        return nil
    }

    @Test("The scanner reads a body whole, without its comments, and refuses an anchor it cannot place")
    func scannerReadsOneBody() throws {
        let source = """
            func a() { // a comment { with a brace
                let s = "\\(x) }"
                call(1)
            }
            func b() { call(2) }
            """
        #expect(Self.body(after: "func a()", in: source) == #"{ let s = "\(x) }" call(1) }"#)
        #expect(Self.body(after: "func b()", in: source) == "{ call(2) }")
        #expect(Self.body(after: "func", in: source) == nil)
        #expect(Self.body(after: "func c()", in: source) == nil)
    }

    @Test("Entering a mode re-derives the fields through CitationLookupFields.refreshed (#1474)")
    func modeChangeRefreshesTheFields() throws {
        let body = try #require(Self.body(after: ".onChange(of: mode)", in: try Self.viewSource()))
        #expect(body.contains("fields = fields.refreshed(forPaste: pasteText, mode: newMode, parser: parser)"),
                "\(body)")
    }

    @Test("A paste re-derives the fields through CitationLookupFields.refreshed (#1474)")
    func pasteRefreshesTheFields() throws {
        let body = try #require(Self.body(after: ".onChange(of: pasteText)", in: try Self.viewSource()))
        #expect(body.contains("fields = fields.refreshed(forPaste: new, mode: mode, parser: parser)"),
                "\(body)")
    }

    @Test("Look Up is gated by CitationLookupFields.isActionable, and by nothing else (#1474)")
    func lookUpGateIsTheFieldsRule() throws {
        let source = try Self.viewSource()
        let gate = try #require(Self.body(after: "private var isInputActionable: Bool", in: source))
        #expect(gate == "{ fields.isActionable(mode: mode, pasteText: pasteText, parser: parser) }", "\(gate)")
        // The button and Return both go through that gate.
        let button = try #require(Self.body(after: "private var lookUpSection: some View", in: source))
        #expect(button.contains(".disabled(!isInputActionable || isSearching)"), "\(button)")
        let submit = try #require(Self.body(after: "private func submitIfActionable()", in: source))
        #expect(submit.contains("guard isInputActionable, !isSearching else { return }"), "\(submit)")
    }

    @Test("The lookup hands the engine CitationLookupFields.input whole, not a copy of its fields (#1474)")
    func lookupUsesTheFieldsInput() throws {
        let body = try #require(Self.body(after: "private func performLookup() async", in: try Self.viewSource()))
        #expect(body.contains("let input = fields.input(mode: mode, pasteText: pasteText, parser: parser)"),
                "\(body)")
        #expect(body.contains("matches = try await engine.match(input: input)"), "\(body)")
        // A hand-built input is how the part and the link were dropped before.
        #expect(!body.contains("CitationInput("), "\(body)")
    }

    @Test("A Batch row with one uncertain candidate shows that candidate's label (#1474 review round 1)")
    func batchRowShowsALoneCandidatesLabel() throws {
        let body = try #require(Self.body(after: "private func batchOutcomeLabel(_ row: BatchCitationRow)",
                                          in: try Self.viewSource()))
        #expect(body.contains("Label(row.loneCandidateLabel ?? String(format:"), "\(body)")
    }
}
