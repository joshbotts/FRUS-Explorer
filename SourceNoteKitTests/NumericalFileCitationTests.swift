// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - NumericalFileCitationTests

/// The one rule both FRUSCoreKit's `CentralFilesIndex` and `CentralFilesIndexGeneratorCore`'s
/// `NumericalFileIndex` read a Numerical File case number by (#1974, decision 176). The cases are the kit's
/// own (`FRUSExplorerTests/CentralFilesIndexTests.swift`), held here where the rule now lives.
///
/// Version history:
///   1.0 — 2026-11-26 (#1974, plan of record row L31): initial implementation
@Suite("NumericalFileCitation — the 1906–1910 case number, and the decimal form that has none")
struct NumericalFileCitationTests {

    @Test("A Numerical File citation gives its case number; a label and a sub-document suffix are skipped")
    func caseNumbers() {
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "7187") == 7187)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "697/43") == 697)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "File No. 17529.") == 17529)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "14319/77") == 14319)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "697/43.") == 697)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "no digits") == nil)
        #expect(NumericalFileCitation.caseNumber(fromFileNumber: "") == nil)
    }

    @Test("A citation in the decimal file's form gives none: a point, a spaced point, a point after a letter")
    func decimalFormsGiveNone() {
        for decimal in ["723.2515/110", "File No. 723.2515/110.", "835.415A/97", "864.56/12", "211.63 Or5/2",
                        "511. 4A1/914", "812. 415A/7", "811B.5034"] {
            #expect(NumericalFileCitation.isDecimalFileForm(decimal), "\(decimal)")
            #expect(NumericalFileCitation.caseNumber(fromFileNumber: decimal) == nil, "\(decimal)")
        }
    }

    @Test("The label's dot and a dot after the slash are not a decimal point")
    func dotsThatAreNotDecimalPoints() {
        #expect(!NumericalFileCitation.isDecimalFileForm("File No. 17529."))
        #expect(!NumericalFileCitation.isDecimalFileForm("697/43"))
        #expect(!NumericalFileCitation.isDecimalFileForm("697/43."))
        #expect(!NumericalFileCitation.isDecimalFileForm("101/2-2162. Secret."))
        #expect(!NumericalFileCitation.isDecimalFileForm("no digits."))
    }
}
