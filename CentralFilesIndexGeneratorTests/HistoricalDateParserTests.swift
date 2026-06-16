// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import CentralFilesIndexGeneratorCore

/// Tests for parsing the human date ranges in NARA diplomatic-series titles, using the
/// real roll titles from the reference data (Docs 1–5).
struct HistoricalDateParserTests {

    @Test("Parses the reference-data roll date ranges")
    func parsesReferenceRanges() throws {
        // Doc 1: Diplomatic Instructions, Great Britain.
        let d1 = try #require(HistoricalDateParser.parse("Aug. 17, 1861 - Sept. 2, 1863"))
        #expect(d1.startISO == "1861-08-17")
        #expect(d1.endISO == "1863-09-02")
        #expect(d1.plausible)

        // Doc 2: Notes from Foreign Missions, Venezuela (no spaces around dash).
        let d2 = try #require(HistoricalDateParser.parse("Apr. 19, 1893-Mar. 28, 1896"))
        #expect(d2.startISO == "1893-04-19")
        #expect(d2.endISO == "1896-03-28")

        // Doc 3: Notes to Foreign Missions, Uruguay and Paraguay (full month names).
        let d3 = try #require(HistoricalDateParser.parse("July 7, 1834 - June 26, 1906"))
        #expect(d3.startISO == "1834-07-07")
        #expect(d3.endISO == "1906-06-26")

        // Doc 4: Diplomatic Despatches, Japan.
        let d4 = try #require(HistoricalDateParser.parse("Mar. 4, 1905-Aug. 31, 1905"))
        #expect(d4.startISO == "1905-03-04")
        #expect(d4.endISO == "1905-08-31")
    }

    @Test("Flags a catalog year typo but still parses the range")
    func flagsYearTypo() throws {
        // Doc 5: Diplomatic Despatches, Switzerland — NARA title typo "1675" for "1875".
        let d5 = try #require(HistoricalDateParser.parse("July 2, 1675-Dec. 18, 1876"))
        #expect(d5.startISO == "1675-07-02")
        #expect(d5.endISO == "1876-12-18")
        #expect(d5.plausible == false)  // 1675 is outside 1780–1915
        // A too-wide low bound still contains real 1875/1876 documents, so lookups hold.
    }

    @Test("Parses a single date and a bare year")
    func parsesSingleAndYear() throws {
        let single = try #require(HistoricalDateParser.parse("September 28, 1875"))
        #expect(single.startISO == "1875-09-28")
        #expect(single.endISO == nil)

        let year = try #require(HistoricalDateParser.parse("1906"))
        #expect(year.startISO == "1906-01-01")
        #expect(year.endISO == nil)
    }

    @Test("Maps full and abbreviated month names including Sept")
    func mapsMonths() {
        #expect(HistoricalDateParser.monthNumber("Jan.") == 1)
        #expect(HistoricalDateParser.monthNumber("Sept") == 9)
        #expect(HistoricalDateParser.monthNumber("September") == 9)
        #expect(HistoricalDateParser.monthNumber("Dec.") == 12)
        #expect(HistoricalDateParser.monthNumber("frobuary") == nil)
    }

    @Test("Returns nil when no date is present")
    func nilWhenNoDate() {
        #expect(HistoricalDateParser.parse("Despatches") == nil)
        #expect(HistoricalDateParser.parse("") == nil)
    }
}
