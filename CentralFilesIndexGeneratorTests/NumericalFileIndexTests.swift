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

/// Tests for the case-number → roll lookup and File No. parsing.
struct NumericalFileIndexTests {

    /// A small index modelled on the verified golden rolls.
    private func sampleIndex() -> NumericalFileIndex {
        NumericalFileIndex(
            seriesNaId: "654171",
            microfilm: "M862",
            rolls: [
                NumericalFileRoll(naId: "19174810", title: "Numerical File: 682-699",
                                  caseStart: 682, caseEnd: 699,
                                  catalogURL: "https://catalog.archives.gov/id/19174810"),
                NumericalFileRoll(naId: "19779414", title: "Numerical File: 7179-7187",
                                  caseStart: 7179, caseEnd: 7187,
                                  catalogURL: "https://catalog.archives.gov/id/19779414"),
            ])
    }

    @Test("Resolves golden File No. citations to the correct roll")
    func resolvesGoldenCitations() throws {
        let index = sampleIndex()
        // Doc 6: File No. 7187 → roll 19779414.
        #expect(index.roll(forFileNumber: "7187")?.naId == "19779414")
        // Doc 7: File No. 697/43 → roll 19174810 (the /43 sub-number is ignored).
        #expect(index.roll(forFileNumber: "697/43")?.naId == "19174810")
    }

    @Test("Parses the leading case number, ignoring labels and sub-document suffixes")
    func parsesCaseNumber() {
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "7187") == 7187)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "697/43") == 697)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "File No. 17529.") == 17529)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "File 682") == 682)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "5275/1/2") == 5275)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "no digits") == nil)
        #expect(NumericalFileIndex.caseNumber(fromFileNumber: "") == nil)
    }

    @Test("Range boundaries are inclusive")
    func inclusiveBoundaries() {
        let index = sampleIndex()
        #expect(index.roll(forCaseNumber: 682)?.naId == "19174810")  // lower bound
        #expect(index.roll(forCaseNumber: 699)?.naId == "19174810")  // upper bound
        #expect(index.roll(forCaseNumber: 7179)?.naId == "19779414")
    }

    @Test("Returns nil for case numbers in a coverage gap")
    func gapReturnsNil() {
        let index = sampleIndex()
        #expect(index.roll(forCaseNumber: 700) == nil)   // between the two sample rolls
        #expect(index.roll(forCaseNumber: 1) == nil)     // below all rolls
        #expect(index.roll(forFileNumber: "700/12") == nil)
    }

    @Test("Init sorts rolls ascending by caseStart even when given out of order")
    func initSortsRolls() {
        let index = NumericalFileIndex(
            seriesNaId: "654171", microfilm: "M862",
            rolls: [
                NumericalFileRoll(naId: "c", title: "Numerical File: 900-999",
                                  caseStart: 900, caseEnd: 999, catalogURL: ""),
                NumericalFileRoll(naId: "a", title: "Numerical File: 1-99",
                                  caseStart: 1, caseEnd: 99, catalogURL: ""),
                NumericalFileRoll(naId: "b", title: "Numerical File: 100-200",
                                  caseStart: 100, caseEnd: 200, catalogURL: ""),
            ])
        #expect(index.rolls.map(\.caseStart) == [1, 100, 900])
    }
}
