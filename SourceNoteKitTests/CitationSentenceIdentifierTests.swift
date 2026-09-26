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
/// date, and a note is a central-files note only when its citation names the Department (#1460).
///
/// The narrative rule used to split the WHOLE note on commas and keep the first digit-bearing segment
/// under sixty characters. A designator's segment runs on to the next comma through the classification
/// and the remarks, so it was usually too long and the scan passed it for whatever came next — the year
/// of an "Also printed in Declassified Documents, 1977, 73B." clause, or a remark's "August 29". And a
/// note whose citation names a foreign ministry was filed as RG 59 because a remark mentioned the
/// Department. Every note below is copied verbatim from the corpus (a few cut after their citation
/// sentence) except the short control, which is the issue's own.
///
/// Version history:
///   1.0 — 2026-09-25: #1460
///   1.1 — 2026-09-25 (#1460 review round 1): the refusal covers every date, not only a bare year;
///          the space-after-dot controls keep their whole designator or store none; a
///          Subject-Numeric designator the dropped stop left dotless keeps a neighbour key
///   1.2 — 2026-09-25 (#1460 review round 2): a `Thru` span or open end is a date, joiner and end
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
    /// bounding the scan is not enough — the date refusal is what removes them. The first, `1964`,
    /// ends the scan; the sentence-final spelling `1965.` is the rule's other branch, pinned in
    /// `dateShape`.
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

    /// The space-after-dot shape — the issue's control, frus1958-60v17/d77 — and its sibling
    /// frus1958-60v12/d306. The sentence splitter cuts `756. D.00` at the class's dot, so bounded to
    /// the citation the scan reached only `756`: the Netherlands class, where the note cites
    /// 756D.00, Indonesia, and the packet printed "— file 756.". The class letter is rejoined before
    /// the split, so the designator is kept whole.
    @Test("A class letter printed apart from its class is rejoined", arguments: [
        ("Source: Department of State, Central Files, 756. D.00/5–258. Secret; Priority. Transmitted in two sections and repeated to The Hague, Manila, Canberra, Bangkok, Kuala Lumpur, and Singapore,",
         "756D.00/5–258"),
        ("Source: Department of State, Central Files, 786. A.11/3–358. Top Secret; Eyes Only Ambassador. Drafted by Newsom, cleared by Rountree, and approved by Dulles.",
         "786A.11/3–358"),
    ])
    func spacedClassLetterIsRejoined(_ note: String, _ designator: String) {
        #expect(identifier(note) == designator)
    }

    /// frus1958-60v15/d273 prints `790. C11/6–558`. It does have a reading — 790C is Nepal in the
    /// 1950–59 schedule, and the note concerns the ambassador accredited to Nepal, so it is
    /// `790C.11/6–558` with the class's dot misplaced — but the letter is followed by a digit, not
    /// by the class's dot, so the rejoin (which moves no dot) does not take it, and the split leaves
    /// `790.`: a bare class naming a wider file than the one cited. It is refused.
    @Test("A class the sentence split stranded is not a file number")
    func strandedClassIsRefused() {
        let note = "Source: Department of State, Central Files, 790. C11/6–558. Confidential. Repeated to Kathmandu. Ambassador Bunker, resident in New Delhi, was also accredited as Ambassador to Nepal."
        #expect(identifier(note) == nil)
    }

    /// The INR/IL Historical Files print a DATE where a file number would sit, inside the citation
    /// sentence — so bounding the scan reached it, where the whole-note scan used to pass over it
    /// for a later segment. The year-only refusal let every one of these through. Each is a corpus
    /// note, one per shape: a year span, a month span with its year, a month and year, a span
    /// joined by `through`, and a span the INR files leave open with `Thru` (review round 2 — the
    /// dash-only open end stored `1964 Thru`, where `v2` had stored nothing).
    @Test("A date span inside the citation sentence is refused", arguments: [
        // frus1964-68v24/d191
        "Source: Department of State, INR Historical Files, Africa General, 1967–1968. Secret; Sensitive. No drafting information appears on the source text.",
        // frus1969-76v21/d303
        "Source: Department of State, Bureau of Intelligence and Research, INR/IL Historical Files, Chile, July–December 1972. Secret; No Foreign Dissem; Controlled Dissem; No Dissem Abroad; This Information Is Not To Be Included in Any Other Document or Publication.",
        // frus1964-68v24/d343
        "Source: Department of State, INR /IL Historical Files, Somali Republic, April 1967. Top Secret. 11 pages of source text not declassified.",
        // frus1964-68v29p1/d86
        "Source: Department of State, INR /IL Historical Files, East Asia and Pacific General File, East Asia, FE Weekly Meetings, January through July 1966. Secret. Drafted on June 21. Koren sent this memorandum to Hughes, Denney, and Evans.",
        // frus1964-68v24/d591
        "Source: Department of State, INR Files, Country Files, Republic of South Africa, 1964 Thru. Secret; Special Handling. 3 pages of source text not declassified.",
    ])
    func dateSpanInsideTheCitationIsRefused(_ note: String) {
        #expect(identifier(note) == nil)
    }

    /// A date ENDS the scan: what follows it in the citation sentence is the dated folder's volume
    /// (frus1964-68v01/d423, `Bundy Files, Working Papers, Nov 1964, Vol. 1.`) or a classification
    /// the printer ran on without a stop (frus1964-68v01/d18, `January 30,1964 Secret.`). Skipping
    /// the date instead stored `Vol. 1` — a value the dotted neighbour arm then routes — and
    /// `1964 Secret`.
    @Test("A date in the citation sentence ends the scan", arguments: [
        "Source: Department of State, Bundy Files, Working Papers, Nov 1964, Vol. 1. Top Secret. Also sent to McNamara, McCone, Wheeler, Ball, and McGeorge Bundy.",
        "Source: Department of State, HarVan Files, Vietnam Coup Two, January 30,1964 Secret. The source text, which bears no time of transmission from Saigon, is a copy sent by the CIA to the Department of State for Hilsman.",
    ])
    func aDateEndsTheScan(_ note: String) {
        #expect(identifier(note) == nil)
    }

    // MARK: - The date rule itself

    /// The shapes `extractFirstIdentifier` refuses, one fixture per branch of the pattern — a year
    /// in each century the rule admits, the sentence's stop, a year span with a full and a two-digit
    /// tail, a month with a year, a qualified month, a month and day, a day span, a month span with
    /// its year, a `through` span, a span across years, an open end, a day-led `to` span, and the
    /// INR files' `Thru` as an open end (`1964 Thru`, frus1964-68v24 d591) and as a joiner (`Feb thru
    /// April 1963`, frus1961-63v11 d327's folder) — and the near misses that are NOT dates and must
    /// stay identifiers.
    @Test("The date shape", arguments: [
        ("1789", true), ("1978", true), ("2001", true), ("1962.", true),
        ("1967–1968", true), ("1963–79", true), ("April 1967", true), ("Late Nov 1964", true),
        ("Jan 21", true), ("September 16-30. 1963", true), ("July–December 1972", true),
        ("January through July 1966", true), ("Sept. 1962–Dec. 1963", true), ("August 1961-", true),
        ("23 January 1968 to December 1968", true), ("January–March. 1954", true),
        ("1964 Thru", true), ("Feb thru April 1963", true),
        ("1978, 5B", false), ("761.5411/1-2361", false), ("1599", false), ("19781", false),
        ("POL 15 HOND", false), ("711.00 Statement July 16, 1937/10", false),
        ("40 Committee Action after September 1970", false), ("Thailand 1968", false),
    ])
    func dateShape(_ candidate: String, _ isDate: Bool) {
        #expect(SourceNoteParser.isDateOnly(candidate) == isDate, "\(candidate)")
    }

    // MARK: - The neighbour key of a letter-led designator

    /// Dropping the stop left a Subject-Numeric designator dotless (`POL 15 HOND.` → `POL 15 HOND`),
    /// and both the dotted arm's `.` test and `dotlessFileLocation`'s leading digit refused it, so
    /// Source Explorer said no match was possible for all of them — 3,145 notes in the corpus, 2,674
    /// of which have a neighbour. The key is
    /// the designator's location, the same one the pipeline's query matches on; the notes are the
    /// frus1961-63v10-12mSupp d160 and frus1961-63v07-09mSupp d197 cohorts.
    @Test("A Subject-Numeric designator keeps its neighbour key", arguments: [
        ("Eventual recognition of Honduran Government and restoration of normal relations. Confidential. 3 pp. DOS, CF, POL 15 HOND.",
         "POL 15 HOND"),
        ("Readout of Harriman / Hailsham discussions with Khrushchev on July 15. Secret. 20 pp. Department of State, Central Files, DEF 18–3 USSR (MO).",
         "DEF 18–3 USSR (MO)"),
    ])
    func subjectNumericDesignatorKeepsItsKey(_ note: String, _ key: String) {
        #expect(parser.parse(note).archivalNeighborKey == key)
    }

    /// The lead the key admits, one fixture per clause, and the letter-led values it must not: a
    /// record group, a numbered issuance, prose, and a title-case slip.
    @Test("The Subject-Numeric lead", arguments: [
        ("POL 15 HOND", "POL 15 HOND"), ("POL 27–14 VIET/ MARIGOLD", "POL 27–14 VIET"),
        ("INCO–WOOL 17 US–JAPAN", "INCO–WOOL 17 US–JAPAN"), ("AID (US) 15-4 UAR", "AID (US) 15-4 UAR"),
        ("E 99–9 MEKONG", "E 99–9 MEKONG"),
        ("RG 59", nil), ("NSC 5412", nil), ("Box 1", nil), ("Def 12 NATO", nil),
        ("Records of the 40 Committee", nil),
    ] as [(String, String?)])
    func subjectNumericLead(_ fileId: String, _ location: String?) {
        #expect(ParsedSourceNote.subjectNumericFileLocation(of: fileId) == location, "\(fileId)")
    }
}
