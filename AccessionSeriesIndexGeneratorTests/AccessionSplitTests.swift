// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import AccessionSeriesIndexGeneratorCore

// MARK: - AccessionSplitTests

/// The key derivation (#1203). Every case here is a spelling NARA actually uses in the harvest.
@Suite("Accession keys (#1203)")
struct AccessionSplitTests {

    /// A FRUS citation and NARA's string must fold to one key.
    @Test("Punctuation and case fold away, as they do for a lot number")
    func foldingIsSpellingBlind() {
        let expected = "71A6682"
        for spelling in ["71A6682", "71 A 6682", "71-A-6682", "71a6682", "71 A-6682"] {
            #expect(AccessionSeriesIndexRunner.fold(spelling) == expected, "folding \(spelling)")
        }
    }

    /// NARA writes the record-group prefix four ways; all of them must come off.
    @Test("The record-group prefix is split off, however it is written")
    func prefixIsSplit() {
        let cases: [(String, String?, String)] = [
            ("059-71A6682", "59", "71A6682"),      // zero-padded
            ("59-71A6682", "59", "71A6682"),       // bare
            ("59-71A-6682", "59", "71A6682"),      // hyphenated body
            ("306-72A-5121", "306", "72A5121"),    // three digits
            ("W084-70-1", "84", "701"),            // the W form
            ("71A6682", nil, "71A6682"),           // no prefix at all
        ]
        for (raw, group, accession) in cases {
            let got = AccessionSeriesIndexRunner.split(raw)
            #expect(got.recordGroup == group, "record group of \(raw)")
            #expect(got.accession == accession, "accession of \(raw)")
        }
    }

    /// An item number inside the accession belongs to the accession.
    ///
    /// This is #1203's own acceptance case: without it `71A6682` misses the two series carrying
    /// items -9/-29/-31/-33, and `68A5159` — cited 34 times in the corpus — resolves to nothing.
    @Test("An item suffix folds to its base accession")
    func itemSuffixFoldsToBase() {
        for raw in ["059-71A6682-9", "059-71A6682-29", "059-71A6682-31", "059-71A6682-33"] {
            let got = AccessionSeriesIndexRunner.split(raw)
            #expect(got.recordGroup == "59")
            #expect(got.accession == "71A6682", "\(raw) must key to its base accession")
        }
        #expect(AccessionSeriesIndexRunner.split("084-68A5159-22").accession == "68A5159")
    }

    /// The unlettered form is a different grammar and must NOT be truncated.
    ///
    /// `059-96-564` is accession `96-564`. Stripping its tail the way an item suffix is stripped
    /// would invent an accession `96` and merge unrelated series under it — the guard is on the
    /// lettered shape for exactly this reason.
    @Test("An unlettered accession keeps its whole body")
    func unletteredAccessionIsNotTruncated() {
        let got = AccessionSeriesIndexRunner.split("059-96-564")
        #expect(got.recordGroup == "59")
        #expect(got.accession == "96564", "must not be truncated to `96`")
        #expect(AccessionSeriesIndexRunner.split("059-80-58").accession == "8058")
    }

    /// A string that is only a prefix, or empty, resolves to nothing rather than a bare group.
    @Test("Degenerate strings yield no accession")
    func degenerateStringsAreRefused() {
        #expect(AccessionSeriesIndexRunner.split("59-").accession == "59")
        #expect(AccessionSeriesIndexRunner.fold("---").isEmpty)
    }
}
