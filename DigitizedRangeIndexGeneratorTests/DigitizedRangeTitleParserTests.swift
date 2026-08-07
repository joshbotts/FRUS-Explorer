// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import DigitizedRangeIndexGeneratorCore

// MARK: - DigitizedRangeTitleParserTests

/// Reading a NARA file-unit title into the decimal range it states (#663).
///
/// Every fixture is a title taken verbatim from the 2026-07-30 harvest.
///
/// Version history:
///   1.0 — Session 2026-08-07: #663
@Suite("Digitised range titles")
struct DigitizedRangeTitleParserTests {

    @Test("The plain range form parses")
    func plainRange() {
        let p = DigitizedRangeTitleParser.parse("763.72/1476-1635")
        #expect(p?.decimalClass == "763.72")
        #expect(p?.low == 1476)
        #expect(p?.high == 1635)
    }

    /// The corpus writes the same class with and without a trailing dot; both must key alike or
    /// half the ranges in a class become unreachable.
    @Test("A trailing dot on the class is not part of the key")
    func trailingDotIsNormalised() {
        #expect(DigitizedRangeTitleParser.parse("131./1-423")?.decimalClass == "131")
        #expect(DigitizedRangeTitleParser.parse("131/426-750")?.decimalClass == "131")
    }

    /// Annotations that ride along without changing the range.
    @Test("Bracketed notes, year parentheticals and part suffixes are stripped")
    func annotationsAreStripped() {
        #expect(DigitizedRangeTitleParser.parse("131/5327-5345 [1940 Reports of Births]")?.low == 5327)
        #expect(DigitizedRangeTitleParser.parse("131 (1940) 104-146 [1940 Reports of Births]")?.high == 146)
        let part = DigitizedRangeTitleParser.parse("763.72/1196a (Part1)")
        #expect(part?.low == 1196 && part?.high == 1196)
    }

    /// `2001-2140 1/2` — a half-serial. The leading digits order the interval.
    @Test("A fractional serial keeps its integer bound")
    func fractionalSerial() {
        let p = DigitizedRangeTitleParser.parse("763.72/2001-2140 1/2")
        #expect(p?.low == 2001 && p?.high == 2140)
    }

    // MARK: - What is not a numeric range

    /// **The measurement this parser exists to record.** 3,622 of the 4,247 digitised file units
    /// in these series are filed by *surname*, not serial — class 131 is the Visa Division's
    /// reports of births. No decimal citation can land in one, so they must parse to `nil`
    /// rather than to a range that would match by accident.
    @Test("Name ranges are not decimal ranges")
    func nameRangesAreRefused() {
        for title in ["131/Abba-Abbi [1940 Reports of Births]",
                      "131/ADAMS [1940 Reports of Births]",
                      "131/ADE-ADY [1940 Reports of Births]",
                      "131.Aa.5-131.Z9",
                      "131ABR-ABU [1940 Reports of Births]"] {
            #expect(DigitizedRangeTitleParser.parse(title) == nil,
                    Comment(rawValue: "\(title) parsed as a numeric range"))
        }
    }

    /// An inverted range is a transcription error, not an interval — admitting it would make
    /// every containment test on that class answer false and hide the mistake.
    @Test("An inverted range is refused")
    func invertedRangeIsRefused() {
        #expect(DigitizedRangeTitleParser.parse("763.72/1635-1476") == nil)
    }

    @Test("A title stating no range at all yields nothing")
    func nonRangeTitles() {
        for title in ["Introduction and Key to the Records of the American Commission",
                      "", "   ", "Purport Lists"] {
            #expect(DigitizedRangeTitleParser.parse(title) == nil,
                    Comment(rawValue: "\(title) parsed"))
        }
    }

    /// The two series the index is built from, and the one deliberately left out: the app
    /// already routes 1906–1910 citations to their roll through `central-files-index.json`, and
    /// a second index answering the same question is how two surfaces come to disagree.
    @Test("The Numerical File series is deliberately excluded")
    func numericalFileSeriesIsExcluded() {
        #expect(DigitizedRangeIndexRunner.seriesNaIds == ["302021", "2555709"])
        #expect(!DigitizedRangeIndexRunner.seriesNaIds.contains("654171"))
    }
}
