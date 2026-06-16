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

        let bare = try #require(RollTitleParser.numericalFileCaseRange(from: "5275-5300"))
        #expect(bare == (5275, 5300))
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
        #expect(RollTitleParser.numericalFileCaseRange(from: "Numerical File, 1906-1910 (M862)") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "Card Index to the Numerical File") == nil)
        #expect(RollTitleParser.numericalFileCaseRange(from: "") == nil)
    }
}
