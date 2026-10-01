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
///   1.3 — 2026-09-26 (#1489): a segment naming the series, its era or the record group is passed
///          over, a declassification remark, a URL or prose is not a file, `Vol. N` ends the scan,
///          a folder title's second year is kept, and a U.N. document symbol is a publication
///   1.4 — 2026-09-26 (#1489 review round 1): a U.N. symbol LATER in a central-files note leaves it
///          a central file (frus1955-57v16/d476), which pins the U.N. rule's lead anchor
///   1.5 — 2026-10-01 (#1514): a Department of State series that is not the central files is a named
///          series, so the INR/IL, INR–NIE and reading-room notes these tests drove the identifier
///          rule through are no longer central files. Each test that needs the rule now leads its
///          note with the Central Files (marked constructed), and the INR notes' own parse is pinned
///          in `DepartmentSeriesTests`; review round 1 renames `eraLabelAloneLeavesNone`, which now
///          asserts the designator IS stored, to `eraLabelThenADigitlessDesignatorStoresTheDesignator`
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
    /// Since #1514 the note is the Department's INR–NIE series, not a central file; the reprint year
    /// is still stored nowhere.
    @Test("A note naming no file number stores none, not the reprint year")
    func reprintYearIsNotAnIdentifier() {
        let note = "Source: Department of State, INR-NIE Files. Secret. Also published in Declassified Documents, 1978, 5B."
        #expect(parser.parse(note) == .namedFileSeries(seriesName: "Department of State, INR-NIE Files",
                                                       fileIdentifier: nil))
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

    /// frus1964-68v29p1/d359's shape: the years are INSIDE the citation sentence ("Japan, 1964,
    /// 1965"), so bounding the scan is not enough — the date refusal is what removes them. The first,
    /// `1964`, ends the scan; the sentence-final spelling `1965.` is the rule's other branch, pinned in
    /// `dateShape`. Constructed since #1514: d359 itself is an INR/IL series note.
    @Test("A bare year inside the citation sentence is refused, with or without its full stop")
    func bareYearInsideTheCitationIsRefused() {
        let note = "Source: Department of State, Central Files, East Asia Country Files, Japan, 1964, 1965. Secret; Eyes Only. 2 pages of source text not declassified."
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

    /// "Department of State" in the citation sentence still makes a central-files note when the
    /// citation names a file number and no central files (frus1955-57v11/d237). Since #1514 the d20
    /// shape it used to pin — a Department series naming no file — is a named series instead.
    @Test("The Department named in the citation with a file number still makes a central-files note")
    func departmentInTheCitationIsStillCentralFiles() {
        #expect(identifier("Source: Department of State, 310.2/10-2656. Secret. Drafted by Virginia F. Hartley.")
                == "310.2/10-2656")
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
    /// dash-only open end stored `1964 Thru`, where `v2` had stored nothing). Since #1514 every one
    /// is an INR series note and no longer a central file, so each shape is constructed under the
    /// Central Files here; the notes' own parse is pinned in `DepartmentSeriesTests`.
    @Test("A date span inside the citation sentence is refused", arguments: [
        // frus1964-68v24/d191's shape
        "Source: Department of State, Central Files, Africa General, 1967–1968. Secret; Sensitive. No drafting information appears on the source text.",
        // frus1969-76v21/d303's shape
        "Source: Department of State, Central Files, Chile, July–December 1972. Secret; No Foreign Dissem; Controlled Dissem; No Dissem Abroad; This Information Is Not To Be Included in Any Other Document or Publication.",
        // frus1964-68v24/d343's shape
        "Source: Department of State, Central Files, Somali Republic, April 1967. Top Secret. 11 pages of source text not declassified.",
        // frus1964-68v29p1/d86's shape
        "Source: Department of State, Central Files, East Asia and Pacific General File, East Asia, FE Weekly Meetings, January through July 1966. Secret. Drafted on June 21. Koren sent this memorandum to Hughes, Denney, and Evans.",
        // frus1964-68v24/d591's shape
        "Source: Department of State, Central Files, Country Files, Republic of South Africa, 1964 Thru. Secret; Special Handling. 3 pages of source text not declassified.",
    ])
    func dateSpanInsideTheCitationIsRefused(_ note: String) {
        #expect(identifier(note) == nil)
    }

    /// A date ENDS the scan: what follows it in the citation sentence is the dated folder's volume
    /// (frus1964-68v01/d423, `Bundy Files, Working Papers, Nov 1964, Vol. 1.`) or a classification
    /// the printer ran on without a stop (frus1964-68v01/d18, `January 30,1964 Secret.`). Skipping
    /// the date instead stored `Vol. 1` — a value the dotted neighbour arm then routes — and
    /// `1964 Secret`. Both notes are Department series since #1514, so the shapes are constructed
    /// under the Central Files here.
    @Test("A date in the citation sentence ends the scan", arguments: [
        "Source: Department of State, Central Files, Working Papers, Nov 1964, Vol. 1. Top Secret. Also sent to McNamara, McCone, Wheeler, Ball, and McGeorge Bundy.",
        "Source: Department of State, Central Files, Vietnam Coup Two, January 30,1964 Secret. The source text, which bears no time of transmission from Saigon, is a copy sent by the CIA to the Department of State for Hilsman.",
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

    // MARK: - #1489: a segment that is not a file

    /// The Subject-Numeric era's citations name the series and its era in one segment, BEFORE the
    /// file — `Central Files 1967–69, POL 27 VIET S` — so the first-digit rule stored the era label
    /// and the packet printed "— file Central Files 1967–69.", losing the file. The label is passed
    /// over and the designator after it is kept; a record-group segment in front of it (d192's
    /// `RG 59`, and the 1958–60 supplements' abstracts, `NARA, RG 59, Central Files, 711.5/5-858`)
    /// is passed over the same way. Each note is verbatim, except that d192's is cut after its first
    /// remark, `Received at 9:42 a.m.`
    @Test("The series' era label and the record group are passed over for the file after them",
          arguments: [
        // frus1964-68v06/d141
        ("Source: National Archives and Records Administration, Central Files 1967–69, POL 27 VIET S. Secret; Nodis. A copy was sent to Katzenbach.",
         "POL 27 VIET S"),
        // frus1964-68v19/d238
        ("Source: National Archives and Records Administration, Central Files 1967–69, POL 27 ARAB–ISR. Secret; Immediate. Drafted by Marshall W. Wiley (NEA/ARN); cleared by Wolle, Houghton, and Grey; and approved by Davies. Repeated Immediate to USUN, Amman, and Jerusalem.",
         "POL 27 ARAB–ISR"),
        // frus1969-76ve01/d63 — the era printed with a hyphen
        ("Source: National Archives, Central Files 1970-73, AV 12. Limited Official Use. Drafted by Stevenson and Malmborg.",
         "AV 12"),
        // frus1964-68v05/d192 — the record group AND the era label before the file
        ("Source: National and Records Administration Archives, RG 59, Central Files 1967–69, POL 27 VIET S. Secret; Priority; Nodis. Received at 9:42 a.m.",
         "POL 27 VIET S"),
        // frus1958-60v03mSupp/d53 — an abstract's citation, where `RG 59` was stored
        ("Source: Transmits views of Chief of Naval Operations on NSC 5810. Top Secret. 9 pp. NARA, RG 59, Central Files, 711.5/5-858.",
         "711.5/5-858"),
    ])
    func seriesLabelsArePassedOver(_ note: String, _ designator: String) {
        #expect(identifier(note) == designator)
    }

    /// frus1964-68v19/d134: the file after the era label carries no digit (`POL ARAB–ISR`). The digit
    /// gate refused it and the note stored no identifier until #1514 admitted a Subject-Numeric
    /// designator by its handbook category; it never stores the label.
    @Test("An era label followed by a designator with no number stores the designator")
    func eraLabelThenADigitlessDesignatorStoresTheDesignator() {
        let note = "Source: National Archives and Records Administration, Central Files 1967–69, POL ARAB–ISR. Secret; Immediate; Nodis. Received at 6:20 p.m."
        #expect(identifier(note) == "POL ARAB–ISR")
    }

    /// The same label printed as a PREFIX of the file, run on with a stop, a semicolon or nothing
    /// (`Central Files. 611.80/3–559`): the label comes off and the file stays. Controls against a
    /// strip that also takes the class: a Subject-Numeric designator and a singular `Central File`.
    @Test("A Central Files label printed in front of the file comes off", arguments: [
        // frus1958-60v12/d57
        ("Source: Department of State, Central Files. 611.80/3–559. Top Secret. Drafted by Newsom and cleared with Furnas.",
         "611.80/3–559"),
        // frus1955-57v04/d228
        ("Source: Department of State, Central Files 840.1901/3–757. Official Use Only.", "840.1901/3–757"),
        // frus1961-63v23/d314
        ("Source: Department of State, Central Files; POL 25–3 INDON. Confidential; Immediate. Repeated immediate to Kuala Lumpur, London, Manila, Singapore, USUN, Canberra, and CINCPAC.",
         "POL 25–3 INDON"),
        // frus1955-57v18/d104
        ("Source: Department of State, Central File 122.536H3/3–2157. Confidential. Also sent to Leopoldville.",
         "122.536H3/3–2157"),
    ])
    func centralFilesPrefixComesOff(_ note: String, _ designator: String) {
        #expect(identifier(note) == designator)
    }

    /// frus1958-60v05mSupp prints eleven notes that name the central files and then only say how
    /// much of the document is withheld; the packet printed "— file Central Files. 3 pages not
    /// declassified.". And frus1981-88v24/d162's folder title is itself withheld, so the scan passes
    /// the remark and reaches the folder's dates, which end it (#1460). The remark is a COUNT of
    /// what is withheld; a designation that merely carries a bracketed withheld title is still a
    /// designation — a CONSTRUCTED control, since the corpus's central-files citations print none.
    @Test("A declassification remark is not a file", arguments: [
        ("Source: Department of State, Central Files. 3 pages not declassified.", nil),
        // frus1981-88v24/d162's shape under the Central Files (constructed since #1514).
        ("Source: Department of State, Central Files, [less than 1 line not declassified], 1986–88, Tunis. Secret; Priority; [handling restriction not declassified].", nil),
        ("Source: Department of State, Central Files, Box 5 [folder title not declassified]. Secret.",
         "Box 5 [folder title not declassified]"),
    ] as [(String, String?)])
    func declassificationRemarkIsNotAFile(_ note: String, _ designation: String?) {
        #expect(identifier(note) == designation)
    }

    /// A URL (the shape of the FOIA reading room's Kissinger telcons, frus1969-76v39/d301 — a
    /// publication since #1514, so constructed under the Central Files here) and a sentence of prose
    /// (frus1952-54v03/d940, whose "citation" is an editor's account of a telegram) open in lower
    /// case, and a lower-case segment ENDS the scan: what follows prose is more prose.
    @Test("A URL or a fragment of prose is not a file", arguments: [
        "Source: Department of State, Central Files, Kissinger Transcripts of Telephone Conversations, http://foia.state.gov/documents/ kissinger /0000C042.pdf. No classification marking.",
        "Source: This statement was based on a substantial revision of the Department of State draft, the revision being transmitted by Lodge in telegram 706, May 7, 1954, 7:07 p.m., file 799.021/5–754, and approved by the Department in telegram 549, May 10, 1954,6:57 p.m., file 799.021/5–754, neither printed.",
    ])
    func urlOrProseIsNotAFile(_ note: String) {
        #expect(identifier(note) == nil)
    }

    /// `Vol. N` is a volume of the folder the PREVIOUS segment names, so it ENDS the scan, as a date
    /// does. Skipping it instead was measured over the eight corpus notes: it reached two real
    /// transfer numbers and stored three worse values — two slash-dated spans (`10/2/64–12/31/64`,
    /// `1/1/65–7/6/65`) and `Box 5 [Moscow`, cut at the bracketed city's comma. d198 is a note where
    /// skipping would have found a transfer number; it is pinned so the choice is deliberate. All
    /// eight are INR/IL series notes, which #1514 made named series keeping the folder with its
    /// volume (`DepartmentSeriesTests`), so the shapes are constructed under the Central Files here.
    @Test("A volume number ends the scan", arguments: [
        // frus1964-68v32/d422's shape
        "Source: Department of State, Central Files, Carlson –Department Messages, Vol. 4, 1965–69. Secret. The date is handwritten on the bottom of page 1 of the telegram.",
        // frus1977-80v23/d198's shape
        "Source: Department of State, Central Files, Volume 22, Transfer Identification Number 980643000012, Jamaica, 1977–80. Secret; Sensitive.",
    ])
    func volumeNumberEndsTheScan(_ note: String) {
        #expect(identifier(note) == nil)
    }

    /// The INR/IL Historical Files are filed by folder title, and a title carries a year
    /// (`Chile Chronology 1970`, frus1969-76v21/d42): a real designation, kept. `Guyana 1969, 1970`
    /// (frus1964-68v32/d423) was cut at its comma to `Guyana 1969`; a bare year following a title
    /// that ends in one is the title's own and is kept with it. Since #1514 those notes are INR/IL
    /// named series, so the shapes are constructed under the Central Files here.
    @Test("A folder title with a year is kept whole", arguments: [
        ("Source: Department of State, Central Files, Chile Chronology 1970. Secret; Roger Channel. Drafted by Crimmins; approved by Coerr.",
         "Chile Chronology 1970"),
        ("Source: Department of State, Central Files, Guyana 1969, 1970. Secret.",
         "Guyana 1969, 1970"),
    ])
    func folderTitleIsKept(_ note: String, _ designation: String) {
        #expect(identifier(note) == designation)
    }

    /// The join's two conjuncts, one CONSTRUCTED control each — the corpus prints neither shape, so
    /// no real note can hold them: a year after a decimal file number is not the file's (the kept
    /// segment must END in a space and a year, and a decimal item never does), and a title's year is
    /// joined only by a following BARE year, never by the next segment whatever it is.
    @Test("A year joins only a title ending in a year, and only a bare year joins it", arguments: [
        ("Source: Department of State, Central Files, 611.93/12–854, 1954. Secret.", "611.93/12–854"),
        ("Source: Department of State, Central Files, Guyana 1969, Box 3. Secret.", "Guyana 1969"),
    ])
    func yearJoinConjuncts(_ note: String, _ designation: String) {
        #expect(identifier(note) == designation)
    }

    /// The U.N. document symbols (`U.N. document S/1511` — the Security Council's resolution of 27
    /// June 1950, frus1950v07/d130) were read by the bare decimal-file rule, whose case-insensitive
    /// class takes `U.N` for a class and `. document S` for its infix, and filed as RG 59. The FRUS
    /// text is the U.N.'s issued document, so the note is a publication — with or without a
    /// `Source:` lead (frus1952-54v09p1/d710, which fell to `unrecognized`), and when the editors
    /// label the document by a member (`U.K. document S/1501`, frus1950v07/d84) — the symbol is the
    /// U.N.'s all the same.
    @Test("A U.N. document symbol is a publication, not a central file", arguments: [
        "U.N. document S/1511. This resolution was adopted shortly before 11:50 p. m., at which time the meeting rose.",
        "U.N. Doc. A/1857",
        "U.K. document S/1501. This resolution was adopted shortly before 6 p. m. at which time the 473rd meeting concluded.",
        "Source: U.N. doc. S/3128. This resolution, introduced by France, was approved unanimously at the 631st meeting of the Security Council on Oct. 27.",
        "Source: UN document S / RES /242. The resolution was adopted unanimously by the Security Council.",
    ])
    func unDocumentSymbolIsAPublication(_ note: String) {
        guard case .previouslyPublished(let citation) = parser.parse(note) else {
            Issue.record("parsed as \(parser.parse(note)), not .previouslyPublished")
            return
        }
        #expect(!citation.hasPrefix("Source:"), "the citation keeps its lead: \(citation)")
    }

    /// Controls for the U.N. lead: a decimal file led by letters (`F.W. 761.6711/3–2245`,
    /// frus1945v08/d1186), a `UN` Subject-Numeric designator in a central-files citation
    /// (frus1964-68v33/d421's `POL 19 UN`), and a central-files note whose REMARKS name a U.N.
    /// document (frus1955-57v16/d476, verbatim: "circulated as U.N. doc. A /3269") stay central
    /// files. d476 is the one that pins the lead anchor: the first two carry no `document`/`doc.`,
    /// so they would stay central files with the anchor gone, and 20 corpus notes name a symbol
    /// only after their citation.
    @Test("A letter-led decimal file, a UN designator and a later U.N. symbol stay central files", arguments: [
        ("F.W. 761.6711/3–2245: Telegram", "F.W. 761.6711/3–2245"),
        ("Source: National Archives and Records Administration, Central Files 1967–69, POL 19 UN. Confidential.",
         "POL 19 UN"),
        ("Source: Department of State, Central Files, 684A.86/11–356. A marginal notation on the source text indicates that the statement was handed to Murphy by Coulson at 10:15 a.m., November 3. Another notation indicates that “Eden made this statement in Commons at 7 a.m. E.S.T.” The British Government quoted this statement in full in a letter to Hammarskjold, dated November 3, which was circulated as U.N. doc. A /3269.",
         "684A.86/11–356"),
    ])
    func unLeadControls(_ note: String, _ designator: String) {
        #expect(identifier(note) == designator)
    }
}
