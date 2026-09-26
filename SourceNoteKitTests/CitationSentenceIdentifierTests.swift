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

// MARK: - CitationSentenceIdentifierTests

/// A narrative central-files note's file identifier comes from its citation sentence, is never a
/// bare year, and a note is a central-files note only when its citation names the Department (#1460).
///
/// The narrative rule used to split the WHOLE note on commas and keep the first digit-bearing segment
/// under sixty characters. A designator's segment runs on to the next comma through the classification
/// and the remarks, so it was usually too long and the scan passed it for whatever came next — the year
/// of an "Also printed in Declassified Documents, 1977, 73B." clause, or a remark's "August 29". And a
/// note whose citation names a foreign ministry was filed as RG 59 because a remark mentioned the
/// Department. Every note below is copied verbatim from the corpus except the short control, which is
/// the issue's own.
///
/// Version history:
///   1.0 — 2026-09-25: #1460
@Suite("Central-files identifier from the citation sentence")
struct CitationSentenceIdentifierTests {

    private let parser = SourceNoteParser()

    /// The `.centralFiles` identifier, or a sentinel naming the case the note took instead — so a
    /// failure shows what the parser did, not only that it did not match.
    private func identifier(_ note: String) -> String? {
        switch parser.parse(note) {
        case .centralFiles(_, let identifier): return identifier
        default: return "<not centralFiles: \(parser.parse(note))>"
        }
    }

    // MARK: - The cases the issue reported

    /// frus1961-63v14/d20: no designator at all, so the old scan returned the reprint's year and the
    /// packet printed "file 1978".
    @Test("A note naming no file number stores none, not the reprint year")
    func reprintYearIsNotAnIdentifier() {
        let note = "Source: Department of State, INR-NIE Files. Secret. Also published in Declassified Documents, 1978, 5B."
        #expect(identifier(note) == nil)
    }

    /// frus1961-63v05/d11: the designator's comma segment ran to "Also printed in Declassified
    /// Documents" (over sixty characters), so the scan skipped it and returned 1977.
    @Test("A long remark no longer hides the designator")
    func designatorBeforeALongRemark() {
        let note = "Source: Department of State, Central Files, 761.5411/1-2361. Secret; Niact. Drafted by Kohler on January 23 and approved by Rusk. Also printed in Declassified Documents, 1977, 73B."
        #expect(identifier(note) == "761.5411/1-2361")
    }

    /// frus1955-57v02/d25: the year came from "a memorandum of August 29, 1958" in the last remark.
    @Test("A year in a remark sentence is out of reach")
    func remarkYearIsOutOfReach() {
        let note = "Source: Department of State, Central Files, 793.5/8–2958. Top Secret. Drafted by Assistant Secretary Merchant and revised by Dulles. Filed with a memorandum of August 29, 1958, from Fisher Howe, Director of the Executive Secretariat, to the Acting Secretary."
        #expect(identifier(note) == "793.5/8–2958")
    }

    /// frus1964-68v29p1/d359: the years are INSIDE the citation sentence ("Japan, 1964, 1965"), so
    /// bounding the scan is not enough — the bare-year refusal is what removes them, and it has to
    /// refuse both spellings, `1964` and the sentence-final `1965.`.
    @Test("A bare year inside the citation sentence is refused, with or without its full stop")
    func bareYearInsideTheCitationIsRefused() {
        let note = "Source: Department of State, INR/IL Historical Files: East Asia Country Files, Japan, 1964, 1965. Secret; Eyes Only. 2 pages of source text not declassified."
        #expect(identifier(note) == nil)
    }

    /// frus1961-63v06/d93: the citation names the Russian ministry; "Department of State" is in a
    /// remark ("made the Russian text available to the Department of State in September 1995").
    @Test("A foreign-archive citation with the Department only in a remark is a foreign archive")
    func departmentInARemarkDoesNotMakeACentralFilesNote() {
        let note = "Source: Russian Ministry of Foreign Affairs, Department of History and Records. Secret. The Department of History and Records made the Russian text available to the Department of State in September 1995; the text was translated by Senior Foreign Service Officer Michael Joyce. There are no copies of the message in Department of State or White House Files. On April 3, 1963, Ambassador Dobrynin handed an English translation of this message to Robert Kennedy, who read it, returned it to Dobrynin, and summarized its contents and his reasons for returning it in an April 3 memorandum to President Kennedy (Document 94). Although the message was directed to Robert Kennedy, it was clearly intended that he pass it along to President Kennedy."
        guard case .foreignGovernmentArchive = parser.parse(note) else {
            Issue.record("parsed as \(parser.parse(note)), not .foreignGovernmentArchive")
            return
        }
    }

    // MARK: - Controls

    /// The issue's short control. Its identifier used to carry the classification with it
    /// (`611.93/12–854. Secret.`); bounded to the citation it is the designator alone.
    @Test("A short note keeps its designator, without the sentence's stop")
    func shortNoteKeepsItsDesignator() {
        #expect(identifier("Source: Department of State, Central Files, 611.93/12–854. Secret.")
                == "611.93/12–854")
    }

    /// "Department of State" in the citation sentence itself still makes a central-files note, even
    /// with no "Central Files" anywhere — the d20 shape, checked for its CLASSIFICATION here (the
    /// first test checks its identifier).
    @Test("The Department named in the citation still makes a central-files note")
    func departmentInTheCitationIsStillCentralFiles() {
        guard case .centralFiles = parser.parse(
            "Source: Department of State, INR-NIE Files. Secret. Also published in Declassified Documents, 1978, 5B.")
        else {
            Issue.record("the Department-led citation left .centralFiles")
            return
        }
    }

    /// frus1908/d5: a Numerical File case number is four digits and looks like a year. It is read
    /// by `tryFileNo`, not the narrative rule, and the year refusal must not reach it.
    @Test("A Numerical File case number that looks like a year is kept")
    func numericalFileCaseNumberIsKept() {
        #expect(identifier("File No. 1636.") == "1636")
    }

    /// frus1958-60v17/d77, the space-after-dot shape. The sentence splitter cuts `756. D.00` at the
    /// dot (a single capital is not the all-caps suffix `collapsingClassPunctuation` joins), so the
    /// bounded scan reaches only the class number — the whole designator is two notes in the corpus
    /// (`[0-9]{3}\. [A-Z]\.[0-9]+/`), both in 1958–60 volumes. The old scan stored NOTHING for this
    /// note (its segment ran past sixty characters), so the class is a gain, and it is the same class
    /// `decimalClassLocation(inCitation:)` already stores for it.
    @Test("The space-after-dot designator keeps its class")
    func spaceAfterDotKeepsItsClass() {
        let note = "Source: Department of State, Central Files, 756. D.00/5–258. Secret; Priority. Transmitted in two sections and repeated to The Hague, Manila, Canberra, Bangkok, Kuala Lumpur, and Singapore,"
        #expect(identifier(note) == "756")
    }

    // MARK: - The year rule itself

    /// The shape `extractFirstIdentifier` refuses, one fixture per branch of the pattern: a
    /// seventeenth-to-nineteenth-century year, a twentieth/twenty-first-century year, the
    /// sentence-final stop, and three near misses that are NOT years and must stay identifiers.
    @Test("The bare-year shape", arguments: [
        ("1789", true), ("1978", true), ("2001", true), ("1962.", true),
        ("1978, 5B", false), ("761.5411/1-2361", false), ("1599", false), ("19781", false),
    ])
    func bareYearShape(_ candidate: String, _ isYear: Bool) {
        #expect(SourceNoteParser.isBareYear(candidate) == isYear, "\(candidate)")
    }
}
