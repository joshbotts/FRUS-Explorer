// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SourceNoteKit

// MARK: - DoubledFileLabelTests

/// The doubled `File No. No.` label (#353).
///
/// A compositor's repetition running through `frus1918Supp02`. `tryFileNo` requires the capture
/// after the label to start with a digit — so a stray second `No.` stopped the match before it
/// began, and **146 documents** never reached the decimal grammars at all. They carried a
/// perfectly ordinary decimal citation behind the typo.
///
/// Measured: 146 recovered to `centralFiles`, **0 lost**.
///
/// Version history:
///   1.0 — Session 2026-08-07: #353, the doubled file label
@Suite("Doubled File No. label")
struct DoubledFileLabelTests {

    private let parser = SourceNoteParser()

    private func fileID(_ note: String) -> String? {
        if case .centralFiles(_, let identifier) = parser.parse(note) { return identifier }
        return nil
    }

    /// The identifier stored must be the citation, with no trace of the doubled label.
    @Test("A doubled label still yields the decimal citation")
    func doubledLabelIsRead() {
        #expect(fileID("File No. No. 195.2/1176") == "195.2/1176")
        #expect(fileID("File No. No. 123G31/112") == "123G31/112")
        #expect(fileID("File No. No. 195.2/1207a") == "195.2/1207a")
    }

    /// The single-label form is unchanged — this widened a repetition count, and must not have
    /// moved the ordinary case.
    @Test("The single label is unaffected")
    func singleLabelIsUnchanged() {
        #expect(fileID("File No. 861.00/1234") == "861.00/1234")
        #expect(fileID("File 093.11141/21.") == "093.11141/21")
    }

    /// Two is the bound. A third repetition is not a compositor's slip in this corpus, and
    /// admitting an unbounded run would let `File No. No. No. No. …` key a document.
    @Test("A third repetition is not admitted")
    func thirdRepetitionIsRefused() {
        #expect(fileID("File No. No. No. 195.2/1176") == nil)
    }

    /// The capture still has to start with a digit, so prose beginning `File Nothing…` cannot
    /// match — the guard the original pattern was written around.
    @Test("Prose after the label is still refused")
    func proseIsStillRefused() {
        #expect(fileID("File Nothing of consequence was recorded.") == nil)
    }
}
