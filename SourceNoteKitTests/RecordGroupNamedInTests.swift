// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - RecordGroupNamedInTests

/// Pins `CollectionKeying.recordGroupNamedIn(_:)` — the test that decides whether a volume
/// front-matter row has earned a whole-record-group catalogue link.
///
/// The front-matter outline stores an **inherited** record group on every descendant of a
/// record-group heading, so the stored column cannot tell a row that *is* a record group from
/// one that merely sits beneath one. Measured on the owner's index, 5,829 of the 6,373
/// record-group links went to rows that only inherited one — including
/// `frus1961-63v25`'s "USIA Historical Collection", which inherited RG 59 from the heading it
/// is nested under and linked to *General Records of the Department of State*. USIA is RG 306,
/// which the same volume names correctly a few rows later.
///
/// Every "names it" fixture below is a verbatim heading from the corpus.
///
/// Version history:
///   1.0 — Session 2026-08-05: the front-matter record-group rule
@Suite("CollectionKeying — the record group a row names")
struct RecordGroupNamedInTests {

    @Test("A row that names its record group yields the number")
    func namedRecordGroupsAreFound() {
        let corpus = [
            "Record Group 59, Records of the Department of State": "59",
            "Record Group 306, Records of the U.S. Information Agency": "306",
            "Record Group 383, Records of the Arms Control and Disarmament Agency": "383",
            "Record Group 170, Records of the Drug Enforcement Administration": "170",
            "RG 185, Records of the Panama Canal": "185",
            "RG 200, Records of Robert S. McNamara": "200",
            "National Archives Record Group 16, Records of the Office of the Secretary of Agriculture": "16",
            // The pointer row: it names RG 59 mid-sentence and legitimately links to it.
            "Lot Files. These files may be transferred to the National Archives and Records "
                + "Administration at College Park, Maryland, Record Group 59.": "59",
        ]
        for (text, expected) in corpus {
            #expect(CollectionKeying.recordGroupNamedIn(text) == expected,
                    "failed on: \(text.prefix(60))")
        }
    }

    /// The rows the rule exists to refuse — all verbatim corpus rows that inherited a record
    /// group and were linking to the whole of it.
    @Test("A row that only inherited a record group yields nil")
    func inheritedRecordGroupsAreNotNamed() {
        for text in ["USIA Historical Collection",
                     "Reference works, visual materials, transcripts of oral histories, and "
                        + "copies of official records documenting the activities and history of "
                        + "the USIA and its predecessor agencies",
                     "ACDA/DD Files: FRC 77 A 17",
                     "Accession #89–0021, FORGN Country File 70–80",
                     "Negotiating and Planning Records for 1977",
                     "Subject Files of the 1979 Panama Canal Treaty Planning Group",
                     "842/534 (12 Sep 68) TR 5077, Sec. 1",
                     "Central Files. In February 1963 the Department of State switched from a "
                        + "decimal filing system",
                     "110.10: Organization, functions, rules, and regulations of the Department"] {
            #expect(CollectionKeying.recordGroupNamedIn(text) == nil,
                    "wrongly matched: \(text.prefix(60))")
        }
    }

    @Test("Matching is case-insensitive and anchored on word boundaries")
    func matchingShape() {
        #expect(CollectionKeying.recordGroupNamedIn("record group 84, Foreign Service Posts") == "84")
        #expect(CollectionKeying.recordGroupNamedIn("rg 59") == "59")
        // A bare number is not a record group…
        #expect(CollectionKeying.recordGroupNamedIn("59") == nil)
        #expect(CollectionKeying.recordGroupNamedIn("Lot 64 D 199") == nil)
        // …and neither is a word that merely starts with the letters.
        #expect(CollectionKeying.recordGroupNamedIn("RGS 12 something") == nil)
        #expect(CollectionKeying.recordGroupNamedIn("") == nil)
    }

    /// The RG-number form the parser also accepts (`RG 59A`), so the rule does not become
    /// stricter than the value it is compared against.
    @Test("An alphanumeric record-group number is matched")
    func alphanumericRecordGroup() {
        #expect(CollectionKeying.recordGroupNamedIn("RG 59A, some series") == "59A")
    }
}
