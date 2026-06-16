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

/// Tests for Numerical File roll-title parsing.
struct RollTitleParserTests {

    @Test("Parses the golden roll titles from the reference data")
    func parsesGoldenTitles() throws {
        // Doc 6 (frus1907p2/d246) and Doc 7 (frus1909/d299).
        let a = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 7179-7187"))
        #expect(a.start == 7179)
        #expect(a.end == 7187)

        let b = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 682-699"))
        #expect(b.start == 682)
        #expect(b.end == 699)
    }

    @Test("Tolerates en-dash, extra whitespace, trailing period, and case")
    func toleratesFormatting() throws {
        let endash = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 682–699"))
        #expect(endash == (682, 699))

        let spaced = try #require(RollTitleParser.numericalFileCaseRange(from: "  numerical file :  100 - 200 . "))
        #expect(spaced == (100, 200))

        let cased = try #require(RollTitleParser.numericalFileCaseRange(from: "NUMERICAL FILE: 5275-5300"))
        #expect(cased == (5275, 5300))
    }

    @Test("Normalises reversed ranges so start <= end")
    func normalisesReversedRange() throws {
        let r = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 7187-7179"))
        #expect(r.start == 7179)
        #expect(r.end == 7187)
    }

    @Test("Rejects non-roll titles (series, file units, finding aids)")
    func rejectsNonRollTitles() {
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical and Minor Files") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Card Index to the Numerical File") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "") == nil)
    }

    @Test("Rejects the publication/file-unit title whose digits are years, not cases")
    func rejectsPublicationYearTitle() {
        // "1906-1910" are years; the colon-less label marks a descriptive record.
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File, 1906-1910 (M862)") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File 1906-1910") == nil)
    }

    @Test("Rejects the name/place-filed rolls (no case numbers)")
    func rejectsNamePlaceRolls() {
        // Real unmatched titles from the M862 harvest — these are not numeric File No. targets.
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File: Miscellaneous") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File: North Dakota-Wisconsin") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File: New York City - New York State") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File: Alabama-Illinois") == nil)
    }

    @Test("Parses single-case rolls")
    func parsesSingleCase() throws {
        let a = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 22346"))
        #expect(a == (22346, 22346))
        let b = try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 18944"))
        #expect(b == (18944, 18944))
    }

    @Test("Parses sub-document boundary rolls (case integer wins over /NN suffix)")
    func parsesSubDocumentBoundaries() throws {
        // Real harvest titles.
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 21701-21740/125")) == (21701, 21740))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 19274/46-19297")) == (19274, 19297))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 18858/15-18878")) == (18858, 18878))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 21019/51- 21060")) == (21019, 21060))
        // Non-numeric end token falls back to the start case.
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 21740/126-End of case")) == (21740, 21740))
    }

    @Test("Parses roll-split (R)/(S) marker rolls")
    func parsesSplitMarkers() throws {
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 23600 (S)-23640")) == (23600, 23640))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 23600-23600 (R)")) == (23600, 23600))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 21091(S)-21140")) == (21091, 21140))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: 21091/201-21091(R)")) == (21091, 21091))
    }

    @Test("Parses stray-leading-dash, space-separated ranges")
    func parsesStrayDashSpaceRanges() throws {
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: -25101 25240")) == (25101, 25240))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: -23046 23120")) == (23046, 23120))
        #expect(try #require(RollTitleParser.numericalFileCaseRange(from: "Numerical File: -19132 19153")) == (19132, 19153))
    }
}
