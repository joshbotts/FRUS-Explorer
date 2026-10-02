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

// MARK: - SubjectNumericCitationTests

/// The form of an RG 59 central-files citation is read from what the citation gives — a decimal
/// file number or a Subject-Numeric file designation — in either wording, Department-led or
/// National-Archives-led (#1543). `CollectionKeying.centralFilesReading(parsed:note:)` is the rule;
/// the generators' provenance category, the index's `citation_era` and Source Explorer's panel all
/// read it.
///
/// The notes are the corpus's text at `8e5da08c1`, each with its document id beside it, except
/// where a case says it is constructed. They are CUT, three ways, and no cut changes a result:
/// - most stop after their classification sentence or after their first remark, and
///   `frus1964-68v28/d366` is cut inside a sentence;
/// - the e-volume notes (`frus1969-76ve09p2` d33, d78 and d85; `frus1969-76ve11p1` d393 and d429)
///   drop the `Summary: …` sentence the corpus prints before `Source:`. The rule reads the
///   citation sentence, which is selected after that sentence, and `RealTEISubjectNumericTests`
///   indexes `frus1969-76ve09p2` whole;
/// - `frus1969-76ve11p1` d393 and d429 keep the remark that makes the parse `.cfpfFile` and drop
///   or shorten the sentences before it.
///
/// One fixture per kind of evidence and per gate conjunct. A refusal that isolates its conjunct
/// has a control beside it that differs in that conjunct alone. Three refusals do NOT, and each
/// says so where it stands: the Central Foreign Policy File's own forms (`filmFormsAreNil`) give no
/// evidence of any kind, so the film-form gate is tested by `eachFilmFormRefusesADesignation`; and
/// two of the record-group notes (`Paris Peace Conf. 182/1`, the RG 429 `Central File`) stay
/// unread with the record-group gate removed, so that gate is tested by the RG 330 note and the
/// constructed RG-256 identifier.
///
/// Version history:
///   1.0 — 2026-10-02: #1543
///   1.1 — 2026-10-02 (#1543, review round 1): `eachFilmFormRefusesADesignation`, one fixture per
///          alternative of the film-form gate; the header says how the notes are cut and which
///          refusals isolate a conjunct; `frus1969-76v22/d16` carries its own film number
@Suite("Central-files citations are placed by their form (#1543)")
struct SubjectNumericCitationTests {

    private let parser = SourceNoteParser()

    /// The rule over a note as the corpus prints it.
    private func reading(_ note: String) -> CentralFilesReading? {
        CollectionKeying.centralFilesReading(parsed: parser.parse(note), note: note)
    }

    /// The parse case's name, so a fixture that changed case fails naming it.
    private func parseCase(_ note: String) -> String {
        switch parser.parse(note) {
        case .centralFiles: return "centralFiles"
        case .cfpfFile: return "cfpfFile"
        case .naraCollection: return "naraCollection"
        case .presidentialLibrary: return "presidentialLibrary"
        case .lotFile: return "lotFile"
        default: return "other"
        }
    }

    // MARK: Subject-Numeric by the class key

    @Test("A class key the grammar reads as letter-led is Subject-Numeric in every wording", arguments: [
        // frus1964-68v01/d5 — Department-led.
        ("Source: Department of State, Central Files, POL 27 VIET S. Secret. A copy was sent to McGeorge Bundy.",
         "centralFiles", "POL 27 VIET S"),
        // frus1964-68v14/d93 — National-Archives-led, the block in the anchor segment.
        ("Source: National Archives and Records Administration, RG 59, Central Files 1964–66, POL 27 VIET S. Secret; Immediate; Exdis.",
         "naraCollection", "POL 27 VIET S"),
        // frus1964-68v34/d121 — `Records of the Department of State` between the record group and the anchor.
        ("Source: National Archives and Records Administration, RG 59, Records of the Department of State, Central Files, 1964–66, AV 12–7 US. Confidential. Repeated to Paris for USRO.",
         "naraCollection", "AV 12-7 US"),
        // frus1961-63v10-12mSupp/d201 — the microfiche supplements' `DOS, CF`.
        ("Status report on Chamizal negotiations. Confidential. 3 pp. DOS, CF, POL 32–1 MEX–US.",
         "centralFiles", "POL 32–1 MEX–US"),
        // frus1964-68v19/d505 — `RG 59 Central Files` with no comma.
        ("Source: National Archives and Records Administration, RG 59 Central Files 1967–69, POL 27–14 ARAB–ISR. Secret; Priority; Nodis.",
         "naraCollection", "POL 27-14 ARAB-ISR"),
        // frus1964-68v34/d254 — the singular `Central File`.
        ("Source: National Archives and Records Administration, RG 59, Records of the Department of State, Central File, 1967–69, PET 3 OECD. Limited Official Use; Immediate.",
         "naraCollection", "PET 3 OECD"),
        // frus1969-76ve11p1/d429 — read as `.cfpfFile` for its remark, led by a Subject-Numeric citation.
        ("Source: National Archives, RG 59, Central Files, 1970–1973, POL 15–1 JAM. Confidential. Repeated to Bridgetown, Georgetown, and Port of Spain. (Ibid., Central Foreign Policy File, [no film number])",
         "cfpfFile", "POL 15-1 JAM"),
    ])
    func classKeyIsSubjectNumeric(note: String, parseCase expectedCase: String, designation: String) {
        #expect(parseCase(note) == expectedCase)
        let reading = reading(note)
        #expect(reading?.form == .subjectNumeric)
        #expect(reading?.evidence == .classKey)
        #expect(reading?.designation == designation)
        #expect(CollectionKeying.isSubjectNumericCitation(parsed: parser.parse(note), note: note))
        #expect(CollectionKeying.centralFileDesignation(parsed: parser.parse(note), note: note) == designation)
    }

    // MARK: Subject-Numeric by a designation the class grammar refuses

    @Test("A designation the class grammar refuses is read by its lead", arguments: [
        // frus1961-63v15/d171 — a general file, no number.
        ("Source: Department of State, Central Files, POL US–USSR. Secret; Niact; Limit Distribution.",
         "centralFiles", "POL US–USSR", "POL"),
        // frus1961-63v03/d47 — no stop before the classification; nothing stored.
        ("Source: Department of State, Central Files, AID (US) S VIET Confidential. Drafted by Walter G. Stoneman in FE / VN, AID.",
         "centralFiles", "AID (US) S VIET", "AID"),
        // frus1964-68v13/d20 — an agency with no country.
        ("Source: Department of State, Central Files, DEF(MLF). Confidential. Drafted by Tyler.",
         "centralFiles", "DEF(MLF)", "DEF"),
        // frus1964-68v09/d204 — a commodity joined by a dash, no number.
        ("Source: Department of State, Central Files, INCO–GRAINS GATT. Unclassified. Repeated to Bonn.",
         "centralFiles", "INCO–GRAINS GATT", "INCO"),
        // frus1961-63v13/d351 — a title-case category of three letters.
        ("Source: Department of State, Central Files, Pol Port-US. Secret. Repeated to Madrid and Paris.",
         "centralFiles", "Pol Port-US", "POL"),
        // frus1964-68v13/d279 — an organization file.
        ("Source: Department of State, Central Files, NATO 3 BEL(BR). Secret. Drafted by Glenn and Knight on December 12.",
         "centralFiles", "NATO 3 BEL(BR)", "NATO"),
        // frus1964-68v01/d115
        ("Source: Department of State, Central Files, SEATO 3 PHIL (MA). Secret; Immediate; Exdis.",
         "centralFiles", "SEATO 3 PHIL (MA)", "SEATO"),
        // frus1961-63v25/d285 — NARA's own example of a designator, under a printed "1960–63".
        ("Source: National Archives and Records Administration, RG 59, Central Files 1960–63, UN. Limited Official Use. Drafted by Armstrong and approved in S on December 13.",
         "naraCollection", "UN", "UN"),
        // frus1969-76ve07/d110
        ("Source: National Archives, RG 59, Central Files 1970–73, AID (US) INDIA. Secret. Drafted on January 26 by Quainton.",
         "naraCollection", "AID (US) INDIA", "AID"),
        // frus1969-76ve09p2/d33 — a box before the designation, a country in title case.
        ("Source: National Archives, RG 59, Central Files, 1970–73, Box 2432, POL Kuwait, 1/1/1970. Secret. Drafted by James H. Timberlake (OASD/ISA/NESA).",
         "naraCollection", "POL Kuwait", "POL"),
        // frus1964-68v12/d19 — a doubled `Source:` label; a country the class grammar refuses.
        ("Source: Source: National Archives and Records Administration, RG 59, Central Files 1967-69, DEF 15-4 GREENLAND-US. Secret; Exdis.",
         "naraCollection", "DEF 15-4 GREENLAND-US", "DEF"),
        // frus1964-68v19/d8 — no comma between the holder and the record group.
        ("Source: National Archives and Records Administration RG 59, Central Files 1967–69, POL ARAB–ISR. Secret; Immediate.",
         "naraCollection", "POL ARAB–ISR", "POL"),
        // frus1969-76ve09p2/d78 — the block cited under the Central Foreign Policy File's name.
        ("Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, POL 27–14 Arab-Israeli. Confidential. Repeated to Amman, Beirut, Kuwait City, Tripoli, and Tel Aviv.",
         "cfpfFile", "POL 27–14 Arab-Israeli", "POL"),
    ])
    func designationIsSubjectNumeric(note: String, parseCase expectedCase: String,
                                     designation: String, lead: String) {
        #expect(parseCase(note) == expectedCase)
        let reading = reading(note)
        #expect(reading?.form == .subjectNumeric)
        #expect(reading?.evidence == .designation)
        #expect(reading?.designation == designation)
        #expect(reading?.lead == lead)
    }

    // MARK: Subject-Numeric by the block of years alone

    @Test("A block of years inside 1964–1973 decides when nothing else does")
    func blockIsSubjectNumeric() {
        // frus1964-68v29p1/d368 — the block in the anchor segment; `JAPAN–KOR S` has no category.
        let inAnchor = "Source: National Archives and Records Administration, RG 59, Central Files 1964–66, JAPAN–KOR S. Secret. Drafted by Zurhellen and approved in S on July 25."
        #expect(reading(inAnchor) == CentralFilesReading(
            form: .subjectNumeric, evidence: .block, designation: nil, lead: nil))
        #expect(CollectionKeying.centralFileDesignation(parsed: parser.parse(inAnchor), note: inAnchor) == nil)

        // Constructed from the note above: the block in the segment AFTER the anchor.
        let afterAnchor = "Source: National Archives and Records Administration, RG 59, Central Files, 1964–66, JAPAN–KOR S. Secret."
        #expect(reading(afterAnchor)?.evidence == .block)

        // Constructed: the same note under a block outside the Subject-Numeric years, and under a
        // range that only starts inside them. Both ends must be in 1964…1973.
        #expect(reading("Source: National Archives and Records Administration, RG 59, Central Files 1960–63, JAPAN–KOR S. Secret.") == nil)
        #expect(reading("Source: National Archives and Records Administration, RG 59, Central Files 1972–77, JAPAN–KOR S. Secret.") == nil)
        // Constructed: a single year never decides.
        #expect(reading("Source: National Archives and Records Administration, RG 59, Central Files 1966, JAPAN–KOR S. Secret.") == nil)
        // Constructed: under a block, a folder title is in the file whatever its first word is —
        // the lead test refuses `Inter-American Affairs` (see `leadIsRefused`), and the block
        // still decides. Without the block the same note gives no form (`noEvidenceIsNil`).
        #expect(reading("Source: National Archives, RG 59, Central Files 1970–73, Inter-American Affairs. Confidential.")
                == CentralFilesReading(form: .subjectNumeric, evidence: .block, designation: nil, lead: nil))
        // Constructed: a range two segments past the anchor is a folder's dates, not the block.
        #expect(reading("Source: National Archives and Records Administration, RG 59, Central Files, JAPAN–KOR S, Box 5, 1964–66. Secret.") == nil)
    }

    @Test("A stored identifier is read where the citation has no anchor to read segments after")
    func identifierIsReadWithoutAnAnchor() {
        // Constructed: the parse carries a designation the class grammar refuses, and the note
        // names no central files, so there is no segment after an anchor to find it in. The
        // identifier is tested first, and for a Department-led parse no anchor is asked for.
        let parsed = ParsedSourceNote.centralFiles(recordGroup: "RG-59", fileIdentifier: "POL US–USSR")
        #expect(CollectionKeying.centralFilesAnchor(in: CollectionKeying.segments(ofCitation: "POL US–USSR.")) == nil)
        #expect(SourceNoteParser.decimalClassLocation(inCitation: "POL US–USSR.") == nil)
        #expect(CollectionKeying.centralFilesReading(parsed: parsed, note: "POL US–USSR.")
                == CentralFilesReading(form: .subjectNumeric, evidence: .designation,
                                       designation: "POL US–USSR", lead: "POL"))
        // The same identifier under another record group is refused (the Paris Peace Conference's
        // file is RG 256): the gate is the record group's, and nothing else differs.
        #expect(CollectionKeying.centralFilesReading(
            parsed: .centralFiles(recordGroup: "RG-256", fileIdentifier: "POL US–USSR"), note: "POL US–USSR.") == nil)
        #expect(CollectionKeying.centralFilesReading(
            parsed: .centralFiles(recordGroup: "59", fileIdentifier: "POL US–USSR"), note: "POL US–USSR.")?
            .form == .subjectNumeric)
    }

    @Test("An office's or a lot's records under the Central Files heading are not the file")
    func officeFilesUnderTheHeadingAreRefused() {
        // frus1969-76ve08/d15 — `Entry` after the block.
        #expect(reading("Source: National Archives, RG 59, Central Files 1970–73, Entry 5463, Records of Henry Kissinger, Box 5, Nodis Memoranda of Conversations, November 1974 (2). Secret; Nodis.") == nil)
        // frus1969-76ve08/d39 — `Records of` after the block.
        #expect(reading("Source: National Archives, RG 59, Central Files 1970–73, Records of Henry Kissinger, 1973–77, Entry 5407, Box 5, Nodis Memoranda of Conversation, November 1974. Confidential.") == nil)
        // The admitted neighbour differs only in what follows the block (frus1969-76ve06/d78).
        #expect(reading("Source: National Archives, RG 59, Central Files 1970–73, ETH-SOMALIA. Secret; Priority.")?.evidence == .block)
        // frus1969-76ve11p1/d393 — a lot under the heading: the parse carries the lot, and the
        // remark makes it `.cfpfFile`, whose gate refuses a lot in the citation sentence.
        let lot = "Source: National Archives, RG 59, Central Files, 1970–1973, ARA/CAR, Lot 75D393, POL 7 Visits and Meetings. Confidential. In a February 28 letter to Burke, Knox expressed satisfaction. (Ibid., Central Foreign Policy File, [no film number])"
        #expect(reading(lot) == nil)
        // Constructed from it: without the remark it is `.naraCollection` carrying the lot.
        let lotNoRemark = "Source: National Archives, RG 59, Central Files, 1970–1973, ARA/CAR, Lot 75D393, POL 7 Visits and Meetings. Confidential."
        #expect(parseCase(lotNoRemark) == "naraCollection")
        #expect(reading(lotNoRemark) == nil)
    }

    // MARK: Decimal

    @Test("A decimal file number is decimal, through the National Archives too", arguments: [
        // frus1961-63v25/d494
        ("Source: National Archives and Records Administration, RG 59, Central Files 1960–63, 399.731/7–2561. Confidential.",
         "naraCollection", "399.731/7–2561"),
        // frus1917-72PubDip/d10 — a box before the number.
        ("Source: National Archives, RG 59, Central Decimal File 1910–1929, Box 736, 103.9302/12a. No classification marking. Marked “Seen” by Alvey Adee on January 23.",
         "naraCollection", "103.9302/12a"),
        // frus1945-50Intel/d1 — `Decimal File` is an anchor.
        ("Source: National Archives and Records Administration, RG 59, Records of the Department of State, Decimal File 1945–49, 101.5/8–2145. Secret.",
         "naraCollection", "101.5/8–2145"),
        // frus1961-63v11/d301 — a decimal number dated March 1963: the form decides, not the year.
        ("Source: Department of State, Central Files, 611.61/3-2763. Secret; Operational Immediate. This telegram was inadvertently filed under the discontinued decimal filing system.",
         "centralFiles", "611.61/3-2763"),
    ])
    func decimalNumberIsDecimal(note: String, parseCase expectedCase: String, designation: String) {
        #expect(parseCase(note) == expectedCase)
        let reading = reading(note)
        #expect(reading?.form == .decimal)
        #expect(reading?.evidence == .classKey)
        #expect(reading?.designation == designation)
        #expect(!CollectionKeying.isSubjectNumericCitation(parsed: parser.parse(note), note: note))
    }

    // MARK: No evidence, and the gate's refusals

    @Test("A central-files citation that gives no form is not placed", arguments: [
        // frus1958-60v05mSupp/co_d36 — the name alone.
        "Source: Department of State, Central Files. Secret; Official-Informal. 2 pages not declassified.",
        // frus1961-63v23/d477 — an OCR slip for POL.
        "Source: Department of State, Central Files, P9L THAI-US. Secret. Repeated to Bangkok, Karachi, Manila.",
        // frus1951-54Iran/d86 — a decimal number the class grammar cannot read.
        "Source: National Archives, RG 59, Central Files 1950–1954, 888. 10/7–1852. Top Secret; Priority; NIACT.",
        // frus1969-76v38p2/d119 — the Central Foreign Policy File by name and a single year.
        "Source: National Archives, RG 59, Central Foreign Policy Files, 1973. Unclassified. Drafted by Pickering.",
        // frus1969-76v31/d37 — by name alone.
        "Source: National Archives, RG 59, Central Foreign Policy Files. Secret; Limdis. Drafted by William Dutton.",
        // Constructed: a five-letter title-case word that upper-cases to a category (INTER).
        "Source: National Archives, RG 59, Central Files, Inter-American Affairs. Confidential.",
    ])
    func noEvidenceIsNil(note: String) {
        // The control: the rule is running, and reads the neighbouring note that does give a form.
        #expect(reading("Source: Department of State, Central Files, POL 27 VIET S. Secret.")?.form == .subjectNumeric)
        #expect(reading(note) == nil)
        #expect(CollectionKeying.centralFilesForm(parsed: parser.parse(note), note: note) == nil)
        #expect(CollectionKeying.centralFileDesignation(parsed: parser.parse(note), note: note) == nil)
        #expect(!CollectionKeying.isSubjectNumericCitation(parsed: parser.parse(note), note: note))
    }

    /// A PIN, not a guard for the film-form gate: these notes carry no class key, no designation
    /// and no block, so the rule answers `nil` for them with or without that gate (measured: with
    /// `!matches(filmFormRegex, scope)` deleted, this test still passes). What it holds is that the
    /// Central Foreign Policy File's own citations give the rule nothing to read. The gate's own
    /// test is `eachFilmFormRefusesADesignation`.
    @Test("The Central Foreign Policy File's own forms stay out", arguments: [
        // frus1969-76v22/d17 — a film number.
        "Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Confidential; Priority; Nodis; Stadis.",
        // frus1969-76v26/d292 — a dash after the letter.
        "Source: National Archives, RG 59, Central Foreign Policy Files, P–860122–0281. Secret. The meeting was held at Ambassador Helms’s residence.",
        // Constructed from frus1969-76v22/d51 (`D740218–0840`): a space after the letter.
        "Source: National Archives, RG 59, Central Foreign Policy File, D 750010–1075. Secret; Flash; Exdis.",
        // frus1969-76v21/d331
        "Source: National Archives, RG 59, Central Foreign Policy File, [no film number]. Secret; Immediate; Exdis.",
        // frus1989-92v31/d20
        "Source: Department of State, Central Foreign Policy File, STARS, Document Number 89170489. Secret; Exdis.",
    ])
    func filmFormsAreNil(note: String) {
        // The rule is running: under the same name, a designation is read (frus1969-76ve09p2/d85).
        // This note differs from the fixtures by HAVING a designation, not by lacking a film form.
        #expect(reading("Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, POL 2 Saudi Arabia. Secret.")?
            .form == .subjectNumeric)
        #expect(parseCase(note) == "cfpfFile")
        #expect(reading(note) == nil)
    }

    /// The film-form gate, one fixture per alternative of `filmFormRegex`. Every note is
    /// CONSTRUCTED from frus1969-76ve09p2/d78's citation sentence, which the rule reads as
    /// Subject-Numeric by its designation, with one of the Central Foreign Policy File's own forms
    /// added as a last segment — so the form is the only thing the gate can refuse it for. Each
    /// form is spelled as the corpus prints it (the document beside it), except `P-Reel` and
    /// `D-Reel`, which no source note prints.
    @Test("Each film form refuses a citation sentence that carries a designation", arguments: [
        "P840114–1808",                       // frus1969-76v22/d17 — a film number
        "P–860122–0281",                      // frus1969-76v26/d292 — a dash after the letter
        "D 750010–1075",                      // a space after the letter (constructed)
        "N770003-0421",                       // an N number with an ASCII hyphen (constructed)
        "D810025 – 1157",                     // spaces around the dash (constructed from frus1981-88v01's D810025–1157)
        "[no film number]",                   // frus1969-76v21/d331
        "[no N number]",                      // frus1981-88v04
        "No reel number available",           // frus1977-80v26 — a capital, and no bracket
        "Electronic Telegrams",               // frus1981-88v01
        "P-Reel Index",                       // constructed
        "DReel 12",                           // constructed: no hyphen
        "reel # N/A",                         // frus1977-80v26
        "STARS, Document Number 89170489",    // frus1989-92v31/d20
    ])
    func eachFilmFormRefusesADesignation(form: String) {
        // The control differs from the fixture in the film form alone, and is read.
        let sentence = "Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, POL 27–14 Arab-Israeli"
        let control = "\(sentence). Confidential."
        #expect(reading(control) == CentralFilesReading(
            form: .subjectNumeric, evidence: .designation, designation: "POL 27–14 Arab-Israeli", lead: "POL"))

        let note = "\(sentence), \(form). Confidential."
        #expect(parseCase(note) == "cfpfFile")
        #expect(reading(note) == nil, "\(form) did not refuse the citation")
        #expect(!CollectionKeying.isSubjectNumericCitation(parsed: parser.parse(note), note: note))
    }

    @Test("A film form refuses in the citation sentence, and not in a remark")
    func filmFormOutranksADesignation() {
        // Constructed from frus1969-76ve09p2/d78: the same sentence with a film number in it.
        let withFilm = "Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, POL 27–14 Arab-Israeli, P840114–1808. Confidential."
        #expect(parseCase(withFilm) == "cfpfFile")
        #expect(reading(withFilm) == nil)
        // The film form in a REMARK does not refuse: only the citation sentence is read
        // (frus1969-76v22/d16, cut after its first remark).
        let filmInRemark = "Source: National Archives, RG 59, Central Files 1970–73, POL 33–3 PAN. No classification marking. Drafted by Shlaudeman and Bell. The letter was transmitted in telegram 156307 to Panama City, August 8. (National Archives, RG 59, Central Foreign Policy File, P840114–1802)"
        #expect(parseCase(filmInRemark) == "cfpfFile")
        #expect(reading(filmInRemark)?.form == .subjectNumeric)
    }

    @Test("A `.cfpfFile` note never answers decimal")
    func foreignPolicyFileNeverAnswersDecimal() {
        // Constructed: a decimal number in a citation the parser reads as `.cfpfFile` for its name.
        let note = "Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, 611.61/3-2763. Secret."
        #expect(parseCase(note) == "cfpfFile")
        #expect(SourceNoteParser.decimalClassLocation(inCitation: note) == "611.61")
        #expect(reading(note) == nil)
        // The control: the same number under the decimal file's own heading is decimal, so the
        // refusal above is the `.cfpfFile` case's.
        let underCentralFiles = "Source: National Archives, RG 59, Central Files 1960–63, 611.61/3-2763. Secret."
        #expect(parseCase(underCentralFiles) == "naraCollection")
        #expect(reading(underCentralFiles)?.form == .decimal)
    }

    @Test("A note led by another holder is refused, whatever its remark cites")
    func aRemarkIsNotTheCitation() {
        // frus1964-68v05/d67 — a library note whose remark gives a Subject-Numeric file.
        let library = "Source: Johnson Library, National Security File, Country File, Vietnam, Sunflower & Sunflower Plus. Secret. Received at the White House at 9:54 a.m. Also sent to London as telegram 135731. (National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27–14 VIET/SUNFLOWER)"
        #expect(parseCase(library) == "naraCollection")
        #expect(reading(library) == nil)
        // The remark's own citation, alone, is read — so the refusal above is the lead's.
        let alone = "Source: National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27–14 VIET/SUNFLOWER."
        #expect(reading(alone)?.form == .subjectNumeric)

        // frus1977-80v30/d121, with the remark its volume's neighbours carry (constructed join): a
        // library note whose remark names the Central Foreign Policy File.
        let carter = "Source: Carter Library, White House Central Files, Subject File, Federal Government, International Communication Agency, Executive, Box FG–217, FG 298 1/20/77–12/31/78. No classification marking. Another copy is in the National Archives, RG 59, Central Foreign Policy File, P840176–1246."
        #expect(reading(carter) == nil)
    }

    @Test("Only record group 59 is read")
    func otherRecordGroupsAreRefused() {
        // frus1919Parisv01/d17 — the Paris Peace Conference's decimal file is RG 256. A pin and
        // not the gate's guard: `182/1` has no class key the grammar reads, so this note stays
        // unread with the record-group gate removed.
        let paris = "Paris Peace Conf. 182/1"
        guard case .centralFiles(let recordGroup, _) = parser.parse(paris) else {
            Issue.record("expected .centralFiles, got \(parser.parse(paris))")
            return
        }
        #expect(recordGroup == "RG-256")
        #expect(reading(paris) == nil)

        // frus1969-76v36/d347 — a `Central File` in RG 429. Also a pin: its lead is not clean
        // (`Records of the Council on International Economic Policy` is between the record group
        // and the anchor) and it gives no form, so it too stays unread with the gate removed. The
        // RG 330 note below and the RG-256 identifier in `identifierIsReadWithoutAnAnchor` are the
        // fixtures only the record group refuses.
        let council = "Source: National Archives, RG 429, Records of the Council on International Economic Policy, 1971–77, Central File 1972–77, Box 54, File 53508, Memcon major oil firms. No classification marking."
        #expect(parseCase(council) == "naraCollection")
        #expect(reading(council) == nil)

        // frus1964-68v28/d366 — the parser takes RG 330 from the remark, so the row it stores is an
        // RG 330 collection ("OSD /Admin Files: FRC 73A 1304"). The citation sentence has a clean
        // lead, an anchor and a designation; only the record group refuses it. (25 notes are read
        // this way, a parser defect the lane leaves alone: relabelling the form would leave a row
        // that contradicts its own record group and series.)
        let remarkGroup = "Source: Department of State, Central Files, POL 27 LAOS. Top Secret. Bundy sent a draft of this letter to Katzenbach under cover of a memorandum of May 3. A note on another copy indicates that Nitze saw it. (Washington National Records Center, RG 330, OSD /Admin Files: FRC 73A 1304, Laos 381, 1968)"
        guard case .naraCollection(let group, _, let lot, _) = parser.parse(remarkGroup) else {
            Issue.record("expected .naraCollection, got \(parser.parse(remarkGroup))")
            return
        }
        #expect(group == "330")
        #expect(lot == nil)
        #expect(reading(remarkGroup) == nil)

        // The controls: a bare RG 59 decimal number is read, and so is a Subject-Numeric file
        // behind RG 59 (frus1964-68v14/d93) — the refusals above are the record group's.
        #expect(reading("611.61/2–1548.")?.form == .decimal)
        #expect(reading("Source: National Archives and Records Administration, RG 59, Central Files 1964–66, POL 27 VIET S. Secret.")?
            .form == .subjectNumeric)
    }

    @Test("A National Archives citation with no central-files anchor is refused")
    func noAnchorIsRefused() {
        // frus1964-68v21/d344 — the corpus's `Cental Files` typo: no anchor, so no reading, though
        // the designation is a real one.
        let typo = "Source: National Archives and Records Administration, RG 59, Cental Files 1964-66, POL 27 YEMEN. Secret; Priority; Limdis."
        #expect(parseCase(typo) == "naraCollection")
        #expect(reading(typo) == nil)
        // Constructed: the same note spelled correctly is read.
        let spelled = "Source: National Archives and Records Administration, RG 59, Central Files 1964-66, POL 27 YEMEN. Secret; Priority; Limdis."
        #expect(reading(spelled)?.form == .subjectNumeric)
    }

    // MARK: The lead test

    @Test("The lead test reads capitals, and title case of three or four letters", arguments: [
        ("POL 27 VIET S", "POL"), ("POL US–USSR.", "POL"), ("DEF(MLF)", "DEF"), ("INCO–GRAINS GATT", "INCO"),
        ("Pol Port-US", "POL"), ("Def W Eur", "DEF"), ("Inco-Poultry US", "INCO"),
        ("AID (US) S VIET Confidential", "AID"), ("UN.", "UN"), ("NATO 3 BEL(BR)", "NATO"),
        ("SEATO 3 PHIL (MA)", "SEATO"), ("CENTO 3", "CENTO"), ("EEC 3", "EEC"), ("OECD 3", "OECD"),
        ("E 1 JAPAN-US", "E"), ("FT7", "FT"),
        // After a `": "`, as `Central Files 1967-69: POL 27 ARAB-ISR` prints it.
        ("1967-69: POL 27 ARAB-ISR", "POL"),
    ])
    func leadIsRead(candidate: String, lead: String) {
        #expect(CollectionKeying.subjectNumericLead(ofCandidate: candidate) == lead)
    }

    @Test("The lead test refuses what is not a category or an organization lead", arguments: [
        "Box 2432",                    // title case, no category
        "Inter-American Affairs",      // five letters in title case, though INTER is a category
        "pol 27 VIET S",               // lower case
        "POl 27 VIET S",               // mixed case
        "P9L THAI-US",                 // a digit inside the lead
        "JAPAN–KOR S",                 // capitals, no category
        "OAS 3",                       // an organization this list does not carry (read by the class key)
        "POLICY 3",                    // a category's letters inside a longer word
        "Secret",
        "1/1/1970",
        "",
    ])
    func leadIsRefused(candidate: String) {
        // The control: the test reads leads at all.
        #expect(CollectionKeying.subjectNumericLead(ofCandidate: "POL 27 VIET S") == "POL")
        #expect(CollectionKeying.subjectNumericLead(ofCandidate: candidate) == nil)
    }

    @Test("The organization leads are the seven the packet's crib names")
    func organizationLeadsArePinned() {
        #expect(CollectionKeying.subjectNumericOrganizationLeads
                == ["AID", "UN", "NATO", "SEATO", "CENTO", "EEC", "OECD"])
        // None is a handbook category: the two vocabularies are disjoint, so each is tested.
        #expect(CollectionKeying.subjectNumericOrganizationLeads
            .isDisjoint(with: ParsedSourceNote.subjectNumericCategories))
    }

    // MARK: NARA's blocks

    @Test("A printed range is a block only when it is one of NARA's three", arguments: [
        // frus1964-68v14/d93
        ("Source: National Archives and Records Administration, RG 59, Central Files 1964–66, POL 27 VIET S. Secret.", "1964–66"),
        // frus1964-68v12/d19 — an ASCII hyphen.
        ("Source: Source: National Archives and Records Administration, RG 59, Central Files 1967-69, DEF 15-4 GREENLAND-US. Secret; Exdis.", "1967–69"),
        // frus1969-76ve11p1/d429 — four digits, in the segment after the anchor.
        ("Source: National Archives, RG 59, Central Files, 1970–1973, POL 15–1 JAM. Confidential.", "1970–73"),
        // frus1969-76ve09p2/d78 — under the Central Foreign Policy File's name.
        ("Source: National Archives, RG 59, Central Foreign Policy File, 1970–73, POL 27–14 Arab-Israeli. Confidential.", "1970–73"),
    ])
    func printedBlockIsRead(note: String, block: String) {
        #expect(CollectionKeying.printedSubjectNumericBlock(inCitation: note) == block)
    }

    @Test("Any other printed range, or none, is no block", arguments: [
        // frus1961-63v25/d61 — "1960–63" over a file of February 1963.
        "Source: National Archives and Records Administration, RG 59, Central Files 1960–63, ORG 4–COMM. No classification marking.",
        // frus1964-68v05/d4 — "1964–67".
        "Source: National Archives and Records Administration, RG 59, Central Files 1964–67, POL 27–14 VIET/MARIGOLD. Top Secret; Marigold.",
        // frus1964-68v01/d5 — no range printed.
        "Source: Department of State, Central Files, POL 27 VIET S. Secret.",
        // Constructed: a block's two ends from different blocks.
        "Source: National Archives, RG 59, Central Files 1964–69, POL 27 VIET S. Secret.",
        // Constructed: a range later in the citation is a folder's dates, not the block.
        "Source: National Archives, RG 59, Central Files, POL 27 VIET S, Box 2432, 1970–73. Secret.",
    ])
    func otherRangesAreNoBlock(note: String) {
        // The control: a printed block is read.
        #expect(CollectionKeying.printedSubjectNumericBlock(
            inCitation: "Source: National Archives, RG 59, Central Files 1970–73, POL 27 VIET S.") == "1970–73")
        #expect(CollectionKeying.printedSubjectNumericBlock(inCitation: note) == nil)
    }

    // MARK: The anchor and the clean lead

    @Test("The anchor is the first segment naming the central files", arguments: [
        (["Source: Department of State", "Central Files", "POL 27 VIET S."], 1, "Central Files"),
        (["Source: National Archives", "RG 59 Central Files 1967–69", "POL 27"], 1, "Central Files 1967–69"),
        (["National Archives", "RG 59", "Central File", "1967–69"], 2, "Central File"),
        (["National Archives", "RG 59", "Decimal File 1945–49", "101.5/8–2145."], 2, "Decimal File 1945–49"),
        (["3 pp. DOS", "CF", "POL 32–1 MEX–US."], 1, "CF"),
        (["Source: Source: National Archives", "Record Group 59 Central Decimal File 1910–1929"], 1,
         "Central Decimal File 1910–1929"),
    ])
    func anchorIsFound(segments: [String], index: Int, text: String) {
        let anchor = CollectionKeying.centralFilesAnchor(in: segments)
        #expect(anchor?.index == index)
        #expect(anchor?.text == text)
    }

    @Test("A segment that only contains the words is no anchor", arguments: [
        ["Carter Library", "White House Central Files", "Subject File"],
        ["National Archives", "RG 59", "Cental Files 1964-66", "POL 27 YEMEN."],
        ["National Archives", "RG 59", "Central Policy Files", "1973."],
        ["Department of State", "CFM Files"],
    ])
    func anchorIsRefused(segments: [String]) {
        // The control: an anchor is found where a segment LEADS with the words.
        #expect(CollectionKeying.centralFilesAnchor(in: ["National Archives", "RG 59", "Central Files"])?.index == 2)
        #expect(CollectionKeying.centralFilesAnchor(in: segments) == nil)
    }

    @Test("A clean lead is holders and record groups only", arguments: [
        (["Source: National Archives", "RG 59", "Central Files"], 2, true),
        (["National Archives and Records Administration RG 59", "Central Files"], 1, true),
        (["Source: Source: National Archives and Records Administration", "RG-59", "Central Files"], 2, true),
        (["NARA", "Record Group 59", "General Records of the Department of State", "Central Files"], 3, true),
        (["Source: Department of State", "Central Files"], 1, true),
        (["Central Files"], 0, true),
        (["Johnson Library", "National Security File", "Central Files"], 2, false),
        (["National Archives", "RG 84", "Central Files"], 2, false),
        (["National Archives", "Nixon Presidential Materials", "Central Files"], 2, false),
        (["3 pp. DOS", "CF"], 1, false),
    ])
    func cleanLead(segments: [String], anchorIndex: Int, expected: Bool) {
        #expect(CollectionKeying.hasCleanLead(segments, before: anchorIndex) == expected)
    }

    @Test("Candidates are the anchor's tail, then every later segment that is not only a range")
    func candidatesInOrder() {
        let segments = ["National Archives", "RG 59", "Central Files 1970–73: POL 27", "1970–73", "Box 2432",
                        "POL Kuwait", "1/1/1970."]
        let anchor = CollectionKeying.centralFilesAnchor(in: segments)
        #expect(anchor?.index == 2)
        #expect(anchor.map { CollectionKeying.centralFilesCandidates(segments, anchor: $0) }
                == ["POL 27", "Box 2432", "POL Kuwait", "1/1/1970."])
        // `CF` has no tail.
        let cf = ["DOS", "CF", "POL 32–1 MEX–US."]
        #expect(CollectionKeying.centralFilesAnchor(in: cf)
            .map { CollectionKeying.centralFilesCandidates(cf, anchor: $0) } == ["POL 32–1 MEX–US."])
    }
}
