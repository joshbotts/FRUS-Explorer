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

// MARK: - DepartmentSeriesTests

/// A Department of State series that is not the central files is not filed as RG 59 central files
/// (#1514, decision D2 "wide"), and a central-files note led by the Department still is.
///
/// Every note is copied verbatim from the corpus (a few cut after their classification sentence),
/// with its document id beside it, except where a test says it is constructed.
///
/// Version history:
///   1.0 — 2026-10-01: #1514, #1515
@Suite("Department of State series are not central files (#1514)")
struct DepartmentSeriesTests {

    private let parser = SourceNoteParser()

    /// The named series and file, or a sentinel naming the case the note took instead.
    private func series(_ note: String) -> (name: String, file: String?)? {
        guard case .namedFileSeries(let name, let file) = parser.parse(note) else { return nil }
        return (name, file)
    }

    /// The `.centralFiles` identifier, or a sentinel naming the case the note took instead.
    private func centralFile(_ note: String) -> String? {
        switch parser.parse(note) {
        case .centralFiles(_, let identifier): return identifier
        default: return "<not centralFiles: \(parser.parse(note))>"
        }
    }

    @Test("A Department series is a named series headed by the Department", arguments: [
        // frus1969-76v21/d43 — an office printed before its series joins the name.
        ("Source: Department of State, Bureau of Intelligence and Research, INR/IL Historical Files, Chile Chronology 1970. Secret; Immediate; Roger Channel.",
         "Department of State, Bureau of Intelligence and Research, INR/IL Historical Files",
         "Chile Chronology 1970"),
        // frus1955-57v25/d11 — no comma after the Department.
        ("Source: Department of State INR – NIE Files. Secret.", "Department of State, INR – NIE Files", nil),
        // frus1964-68v23/d120 — `Department of State Files,` as the lead.
        ("Source: Department of State Files, INR /IL Historical Files, AF–CIA, 1962. Secret. 2 pages not declassified",
         "Department of State, INR /IL Historical Files", "AF–CIA, 1962"),
        // frus1989-92v31/d83 — the misprint `Department of States`.
        ("Source: Department of States, Office of the Under Secretary for Arms Control, International Security Affairs. Secret. Copied to Bartholomew.",
         "Department of State, Office of the Under Secretary for Arms Control", "International Security Affairs"),
        // frus1961-63v10-12mSupp/d269 — the abstracts' `DOS`, after the page count.
        ("Transmits memorandum for the Special Group on the program of covert action directed at the Castro regime. Secret. 12 pp. DOS, INR /IL Historical Files, S.G. 2, July 20, 1961.",
         "Department of State, INR /IL Historical Files", "S.G. 2, July 20, 1961"),
        // frus1964-68v33/d312 — `U.S.` does not end the citation.
        ("Source: Department of State, U.S. Mission to the United Nations, Subject Files, Reel 141, Frame 104. Confidential. The date is handwritten on the letter.",
         "Department of State, U.S. Mission to the United Nations, Subject Files", "Reel 141, Frame 104"),
        // frus1964-68v29p1/d359 — the series' colon tail starts the file.
        ("Source: Department of State, INR /IL Historical Files: East Asia Country Files, Japan, 1964, 1965. Secret; Eyes Only.",
         "Department of State, INR /IL Historical Files", "East Asia Country Files, Japan, 1964, 1965"),
        // frus1955-57v08/d216 — the classification run on after a semicolon.
        ("Source: Department of State, INR – NIE Files; Secret. According to a note on the cover sheet, the following intelligence organizations participated.",
         "Department of State, INR – NIE Files", nil),
        // frus1955-57v11/d44 — the classification run on after an unnumbered symbol's em dash.
        ("Source: Department of State, IO Master Files, US/A/M(SR)/1—.Confidential Drafted on November 26.",
         "Department of State, IO Master Files", "US/A/M(SR)/1—"),
        // frus1961-63v11/d69 — a records-center accession is the file, not a lot.
        ("Source: Department of State, USUN Files: NYFRC 84-84-001, Incoming Telegrams. Secret; Niact; Eyes Only.",
         "Department of State, USUN Files", "NYFRC 84-84-001, Incoming Telegrams"),
    ] as [(String, String, String?)])
    func departmentSeriesIsNamed(_ note: String, _ name: String, _ file: String?) throws {
        let parsed = try #require(series(note), "parsed as \(parser.parse(note))")
        #expect(parsed.name == name)
        #expect(parsed.file == file)
    }

    /// One fixture per signal that keeps a Department-led note a central file.
    @Test("A Department-led note naming the central files or a file number stays a central file",
          arguments: [
        // A Central Files label in its printed spellings.
        ("Source: Department of State, Central File 122.536H3/3–2157. Confidential. Also sent to Leopoldville.",
         "122.536H3/3–2157"), // frus1955-57v18/d104
        ("Source: Department of State, Centrals Files, 974.7301/8–2056. Secret.", "974.7301/8–2056"), // frus1955-57v16/d103
        ("Source: Department of State, Central piles, 761.13/11–2356. Confidential. Repeated to London and Paris.",
         "761.13/11–2356"), // frus1955-57v24/d63
        ("Source: Department of State, Central, 751G.13/2–2558. Secret; Limit Distribution.", "751G.13/2–2558"), // frus1958-60v01/d5
        // The abstracts' `CF`.
        ("Presentation of Ambassador’s credentials; Colombian budgetary difficulties. Confidential. 2 pp. DOS, CF, POL 17 COL–U.S.",
         "POL 17 COL–U.S."), // frus1961-63v10-12mSupp/d67
        // A file number in the first segment: a decimal number, a personnel file, a designator.
        ("Source: Department of State, 310.2/10-2656. Secret. Drafted by Virginia F. Hartley.", "310.2/10-2656"), // frus1955-57v11/d237
        ("Source: Department of State, 123– Cumming, Hugh S., Jr. Top Secret; Official-Informal.", "123 Cumming"), // frus1955-57v22/d98
        ("Source: Department of State, DEF 4 NATO. Secret; Exdis. Drafted by Vest.", "DEF 4 NATO"), // frus1964-68v13/d106
        // A dotted decimal number in a later segment.
        ("Source: Department of State, Conference Files, 396.1–GE/7–1855. Secret. Drafted by Bohlen.",
         "396.1–GE/7–1855"), // frus1955-57v05/d185
        // STARS, the Department's electronic central record system of 1989–92.
        ("Source: Department of State, STARS, Document Number 89075018. Secret; Exdis.", "Document Number 89075018"), // frus1989-92v31/d6
    ])
    func centralSignalsStayCentral(_ note: String, _ identifier: String) {
        #expect(centralFile(note) == identifier)
    }

    /// The two guards on a later segment's designator: a DOTLESS class is not one (it reads a folder
    /// title as class 303), and a Subject-Numeric designator must open with a handbook category (the
    /// lead shape alone reads a transfer number and a folder title).
    @Test("A folder title that looks like a class or a designator does not keep the note central",
          arguments: [
        // frus1969-76v06/d19
        ("Source: Department of State, INR/IL Historical Files, 303/40 Committee Files, 303 Meetings, 2/16/68–1/20/70. Secret; Eyes Only.",
         "303/40 Committee Files, 303 Meetings, 2/16/68–1/20/70"),
        // frus1977-80v12/d43
        ("Source: Department of State, Bureau of Intelligence and Research, Intelligence Liaison Files, TIN 980643000019, Box 3, Afghanistan, Non-Vector 1980–1985. Secret.",
         "TIN 980643000019, Box 3, Afghanistan, Non-Vector 1980–1985"),
        // frus1964-68v23/d104
        ("Source: Department of State, INR /IL Historical Files, AF–CIA 1962. Secret.", "AF–CIA 1962"),
    ])
    func folderTitlesAreNotDesignators(_ note: String, _ file: String) throws {
        let parsed = try #require(series(note), "parsed as \(parser.parse(note))")
        #expect(parsed.file == file)
    }

    /// frus1955-57v06/d167: a lot printed without the word `Lot` after its series' colon.
    @Test("A lot number without the word Lot is a lot file")
    func bareLotIsALot() {
        let parsed = parser.parse(
            "Source: Department of State, OAS Files: 60 D 665, BAEC —Reference Papers. Secret. Prepared by Ruth S. Donahue.")
        #expect(parsed == .lotFile(recordGroup: "RG-59", lotNumber: "60 D 665",
                                   fileIdentifier: "BAEC —Reference Papers"))
    }

    /// #1515 part 1: the eight `Vol. N` notes are INR/IL notes, and as named series their file is
    /// the folder WITH its volume (frus1964-68v32/d422, frus1981-88v03/d20).
    @Test("A folder's volume number is kept with the folder", arguments: [
        ("Source: Department of State, INR/IL Historical Files, Carlson –Department Messages, Vol. 4, 1965–69. Secret.",
         "Carlson –Department Messages, Vol. 4, 1965–69"),
        ("Source: Department of State, INR/IL Files, Vol. 17, Box 5 [Moscow, 1980–83]. Secret; Roger Channel.",
         "Vol. 17, Box 5 [Moscow, 1980–83]"),
    ])
    func volumeNumberKeptWithItsFolder(_ note: String, _ file: String) throws {
        let parsed = try #require(series(note), "parsed as \(parser.parse(note))")
        #expect(parsed.file == file)
    }

    /// The authority identity: a Department series keys nothing (its leading segment is the holder,
    /// and keyed on it every Department series would be one collection), while an agency series keeps
    /// the key it had (`National Security Council`), unchanged by #1514.
    @Test("A Department series keys no authority collection; another agency's series keeps its key")
    func departmentSeriesKeysNoCollection() {
        let department = "Source: Department of State, INR/IL Historical Files, Guyana 1969, 1970. Secret." // frus1964-68v32/d431
        #expect(CollectionKeying.identity(of: parser.parse(department), note: department) == nil)
        let agency = "Source: National Security Council, Carter Intelligence Files, Box 20, SCC Meetings. Secret."
        #expect(CollectionKeying.identity(of: parser.parse(agency), note: agency)?.leadingSegment
                == "National Security Council")
    }

    @Test("The holder a named series' name states")
    func namedSeriesHolder() {
        #expect(SourceNoteParser.namedSeriesHolder(ofSeriesName: "Department of State, INR/IL Historical Files")
                == "Department of State")
        #expect(SourceNoteParser.namedSeriesHolder(ofSeriesName: "National Security Council, Carter Intelligence Files")
                == "National Security Council")
        #expect(SourceNoteParser.namedSeriesHolder(ofSeriesName: "Conference files") == nil)
        // The head must be the whole first segment: `Department of State Atomic Energy Files` is one
        // series' name, not the Department's.
        #expect(SourceNoteParser.namedSeriesHolder(ofSeriesName: "Department of State Atomic Energy Files") == nil)
    }
}

// MARK: - ReadingRoomAndPublicationTests

/// An agency's online FOIA reading room and the Department's own press releases are publications,
/// and a note that LEADS with the Nixon Presidential Materials is that collection's (#1514).
@Suite("Reading rooms, press releases and the Nixon materials (#1514)")
struct ReadingRoomAndPublicationTests {

    private let parser = SourceNoteParser()

    private func isPublished(_ note: String) -> Bool {
        if case .previouslyPublished = parser.parse(note) { return true }
        return false
    }

    @Test("An agency's FOIA reading room is a publication", arguments: [
        // frus1969-76v16/d24 — was a central file.
        "Source: Department of State, Electronic Reading Room, Kissinger Transcripts of Telephone Conversations. No classification marking.",
        // frus1969-76ve11p1/d73 — was a CFPF citation, read off the remark's film number.
        "Source: Department of State, FOIA Electronic Reading Room, Kissinger Transcripts, Telecon with Ingersoll at 7:55 a.m., 12/6/75. No classification marking. In telegram 5780 from New York, December 6, Scali reported. (National Archives, RG 59, Central Foreign Policy File, D740355–0656)",
        // frus1969-76ve11p2/d256
        "Source: Department of State, Virtual Reading Room, Chile Declassification Project. Secret; Nodis.",
        // frus1969-76ve11p1/d270 — was a CIA collection with no job number.
        "Source: Central Intelligence Agency, FOIA Electronic Reading Room. Secret.",
    ])
    func readingRoomIsAPublication(_ note: String) {
        #expect(isPublished(note), "parsed as \(parser.parse(note))")
    }

    /// The lead anchor: a reading room named later in a central-files note is a remark (constructed).
    @Test("A reading room named in a remark leaves the note where it was")
    func readingRoomInARemark() {
        #expect(parser.parse("Source: Department of State, Central Files, POL 1 US. Secret. Released in the Electronic Reading Room.")
                == .centralFiles(recordGroup: "RG-59", fileIdentifier: "POL 1 US"))
    }

    @Test("The Department's press releases and its Dispatch are publications", arguments: [
        "Source: Press Releases of the Department of State, January–March. 1954.", // frus1952-54v03/d46
        "Source: Department of State Press Release 393. Dulles’ speech was delivered to the international convention.", // frus1955-57v03/d268
        "Source: A copy of Department of State press release 145, Feb. 26, 1952. A full set of the press releases is included in the library of the Department of State.", // frus1952-54v05p1/d114
        "Source: Department of State Dispatch Supplement, October 1991, Vol. 2, Supplement No. 5, pp. 1–16. Unclassified.", // frus1989-92v31/d246
    ])
    func pressReleasesArePublications(_ note: String) {
        #expect(isPublished(note), "parsed as \(parser.parse(note))")
    }

    @Test("A note led by the Nixon Presidential Materials is that collection's", arguments: [
        // frus1969-76v21/d266 — was unrecognized.
        ("Source: Nixon Presidential Materials, NSC Files, Box 776, Country Files, Latin America, Chile, Vol. VI. Confidential. Drafted by Fisher.",
         "NSC Files"),
        // frus1969-76ve03/d85 — was RG 59, by "White House Central Files".
        ("Source: Nixon Presidential Materials, White House Central Files, Subject Files, Outer Space, Box 1, EX, OS Outer Space, 1–1–73. Confidential.",
         "White House Central Files"),
    ])
    func nixonMaterialsLead(_ note: String, _ collection: String) {
        guard case .presidentialLibrary(let library, let parsedCollection, _) = parser.parse(note) else {
            Issue.record("parsed as \(parser.parse(note))")
            return
        }
        #expect(library == "Nixon Presidential Materials")
        #expect(parsedCollection == collection)
    }

    /// The lead anchor: the materials named in a remark of a central-files note do not take it
    /// (constructed).
    @Test("The Nixon materials named in a remark leave the note a central file")
    func nixonMaterialsInARemark() {
        #expect(parser.parse("Source: Department of State, Central Files, POL 1 US. Secret. A copy is in the Nixon Presidential Materials, NSC Files.")
                == .centralFiles(recordGroup: "RG-59", fileIdentifier: "POL 1 US"))
    }
}

// MARK: - SubjectNumericDesignatorTests

/// Subject-Numeric designators the identifier rule refused or misread: those with no number,
/// title-case and hyphenated ones, ones with the classification run on, and the stop of `U.S.`
/// (#1514, #1515, and #1460's title-case residue).
@Suite("Subject-Numeric designators the identifier rule now reads (#1514, #1515)")
struct SubjectNumericDesignatorTests {

    private let parser = SourceNoteParser()

    private func centralFile(_ note: String) -> String? {
        switch parser.parse(note) {
        case .centralFiles(_, let identifier): return identifier
        default: return "<not centralFiles: \(parser.parse(note))>"
        }
    }

    @Test("A designator with no number is stored, with its neighbour key", arguments: [
        ("Source: Department of State, Central Files, POL CHICOM -US. Confidential; Priority; Limit Distribution.",
         "POL CHICOM -US"), // frus1961-63v22/d175
        ("Source: National Archives, Central Files 1970-73, INCO -DRUGS TUR. Confidential. Copies were sent to Finch and Moynihan.",
         "INCO -DRUGS TUR"), // frus1969-76ve01/d170
        ("Source: Department of State, Central Files, PER- LODGE, HENRY CABOT. Secret; Limit Distribution; Eyes Only.",
         "PER LODGE"), // frus1961-63v04/d193
        // A dash taken off by the class collapse leaves one space, not two (frus1964-68v30/d73).
        ("Source: Department of State, Central Files, POL CHICOM - CHINAT. Secret; Limdis.", "POL CHICOM CHINAT"),
    ])
    func digitlessDesignatorIsStored(_ note: String, _ designator: String) {
        #expect(centralFile(note) == designator)
        #expect(parser.parse(note).archivalNeighborKey == designator)
    }

    /// One fixture per conjunct of the digitless shape (constructed): the lead must be a handbook
    /// category, and nothing lower-case may follow it.
    @Test("A capitalised pair that is not a designator is not stored", arguments: [
        "Source: Department of State, Central Files, ABC CHICOM. Secret.",
        "Source: Department of State, Central Files, POL Files. Secret.",
    ])
    func notADesignator(_ note: String) {
        #expect(centralFile(note) == nil)
    }

    @Test("The digitless shape", arguments: [
        ("POL US–USSR", true), ("POL IRAN-U.S.", true), ("FT (EX) US", true), ("INCO -DRUGS TUR", true),
        ("ABC CHICOM", false), ("POL Files", false), ("POL 15 HOND", false), ("POL", false),
    ])
    func digitlessShape(_ candidate: String, _ isDesignator: Bool) {
        #expect(ParsedSourceNote.isDigitlessSubjectNumeric(candidate) == isDesignator)
    }

    /// #1515: a designator ending in an abbreviation of initials keeps its stop; printed with two
    /// stops it keeps one; any other designator loses the sentence's stop as before.
    @Test("An abbreviation's stop is kept, the sentence's is not", arguments: [
        ("Source: Department of State, Central Files, POL IRAN-U.S. Confidential. Drafted by Tiger.", "POL IRAN-U.S."), // frus1964-68v22/d63
        ("Source: Department of State, Central Files, POL IRAN-U.S.. Confidential; Limdis.", "POL IRAN-U.S."), // frus1964-68v22/d109
        ("Source: Department of State, Central Files, DEF 15–3 IRAN-U.S.. Confidential. Repeated to CINCSTRIKE.", "DEF 15–3 IRAN-U.S."), // frus1964-68v22/d59
        ("Source: Department of State, Central Files, POL 15 HOND. Secret.", "POL 15 HOND"), // constructed control
    ])
    func abbreviationStopIsKept(_ note: String, _ designator: String) {
        #expect(centralFile(note) == designator)
    }

    @Test("A title-case or hyphenated designator is spelled as the handbooks spell it", arguments: [
        ("Source: Department of State, Central Files, Def 12 NATO. Secret. Drafted by Spiers.", "DEF 12 NATO", "DEF 12 NATO"), // frus1961-63v13/d194
        ("Source: Department of State, Central Files, Pol 7 US/ Kennedy. Secret. Drafted by Ball.", "POL 7 US/ Kennedy", "POL 7 US"), // frus1961-63v13/d79
        ("Source: Department of State, Central Files, Def(MLF)3. Confidential.", "DEF(MLF)3", "DEF(MLF)3"), // frus1961-63v13/d212
        ("Source: Department of State, Central Files, POL-1 S AFR. Confidential. Drafted by Judd.", "POL 1 S AFR", "POL 1 S AFR"), // frus1961-63v21/d417
    ])
    func titleCaseIsRespelled(_ note: String, _ designator: String, _ key: String) {
        #expect(centralFile(note) == designator)
        #expect(parser.parse(note).archivalNeighborKey == key)
    }

    /// The test a designator must pass wherever it must be told from a record number or a folder
    /// title: the lead shape AND a handbook category.
    @Test("A handbook designator opens with a handbook category", arguments: [
        ("POL 17-3 JORDAN", true), ("INCO–WOOL 17 US–JAPAN", true), ("POL IRAN-U.S.", true),
        ("STARS 199120884–0", false), ("TIN 980643000019", false), ("AF–CIA 1962", false),
        ("Document Number 89075018", false), ("Chile Chronology 1970", false),
    ])
    func handbookDesignator(_ candidate: String, _ isDesignator: Bool) {
        #expect(ParsedSourceNote.isHandbookSubjectNumeric(candidate) == isDesignator)
    }

    @Test("Only a handbook category's lead is respelled", arguments: [
        ("Box 1", "Box 1"), ("Def 12 NATO", "DEF 12 NATO"), ("POL-26 IRAQ", "POL 26 IRAQ"),
        ("INCO–WOOL 17 US–JAPAN", "INCO–WOOL 17 US–JAPAN"), ("611.93/12–854", "611.93/12–854"),
    ])
    func leadNormalization(_ identifier: String, _ expected: String) {
        #expect(ParsedSourceNote.normalizingSubjectNumericLead(identifier) == expected)
    }

    @Test("A classification run on after a designator is not part of it", arguments: [
        ("Source: Department of State, Central Files, POL 26 S VIET Top Secret; Emergency. Received at 7:39 p.m.", "POL 26 S VIET"), // frus1961-63v04/d20
        ("Source: Department of State, Central Files, 993.61/11–1755; Secret. Received at 12:34 p.m.", "993.61/11–1755"), // frus1955-57v03/d101
    ])
    func runOnClassificationIsCut(_ note: String, _ designator: String) {
        #expect(centralFile(note) == designator)
    }

    /// The marking must be followed by what follows a marking (constructed): a folder title carrying
    /// the word is not cut.
    @Test("A folder title carrying a classification word is not cut")
    func folderTitleWithAClassificationWord() {
        #expect(SourceNoteParser.cuttingRunOnClassification("Box 3 Secret Files") == "Box 3 Secret Files")
        #expect(SourceNoteParser.cuttingRunOnClassification("POL 26 S VIET Secret") == "POL 26 S VIET")
    }

    /// frus1964-68v01/d111 and d229 punctuate the citation with stops, so the sentence naming the
    /// central files ends at the label; the designator is the next sentence. A classification
    /// marking there is never taken (frus1958-60v05mSupp/co_d36).
    @Test("A designator after a stop-punctuated label is read", arguments: [
        ("Source: Department of State. Central Files. ORG 7 S. Secret; Immediate; Nodis. Drafted and initialed by Rusk.", "ORG 7 S"),
        ("Source: Department of State. Central Files. POL 1 US–VIET S. Secret; Limdis. Repeated to CINCPAC.", "POL 1 US–VIET S"),
    ] as [(String, String?)])
    func designatorAfterAStoppedLabel(_ note: String, _ designator: String?) {
        #expect(centralFile(note) == designator)
    }

    @Test("A classification marking after a stopped label is not a file")
    func markingAfterAStoppedLabel() {
        #expect(centralFile("Source: Department of State, Central Files. Secret; Official-Informal. 2 pages not declassified.") == nil)
    }
}

// MARK: - BridgedHeadingTests

/// A heading naming its repository in full, which no keyword reads, gives its rows that
/// repository's canonical name (the 2026-09-28 audit, folded into #1514).
@Suite("A full-name heading's bridged repository")
struct BridgedHeadingTests {

    @Test("A full name bridges; a keyword name or a collection does not", arguments: [
        ("Princeton University Library, Princeton, New Jersey", "Princeton University"),
        ("Princeton University Library, Dulles Papers, Appointment Book", "Princeton University"),
        ("Jimmy Carter Presidential Library, Atlanta, Georgia", "Carter Library"),
        ("Eisenhower Library, Abilene, Kansas", nil),
        ("Records of the Executive Secretariat", nil),
    ] as [(String, String?)])
    func bridged(_ heading: String, _ repository: String?) {
        #expect(CollectionKeying.bridgedRepository(ofHeading: heading) == repository)
    }
}

// MARK: - SubjectNumericCategoryPinTests

/// `ParsedSourceNote.subjectNumericCategories` is a copy of the categories the shipped
/// `subject-numeric-labels.json` names across both schedules; this fails when the two part.
@Suite("The Subject-Numeric category list matches the shipped schedules (#1514)")
struct SubjectNumericCategoryPinTests {

    @Test("The categories are the shipped schedules' categories")
    func categoriesMatchTheArtifact() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/subject-numeric-labels.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let schedules = try #require((object as? [String: Any])?["schedules"] as? [[String: Any]])
        var shipped = Set<String>()
        for schedule in schedules {
            let categories = try #require(schedule["categories"] as? [String: Any])
            shipped.formUnion(categories.keys)
        }
        #expect(schedules.count == 2)
        #expect(shipped.count > 50, "read \(shipped.count) categories — the artifact did not parse")
        #expect(ParsedSourceNote.subjectNumericCategories == shipped,
                "only in the code: \(ParsedSourceNote.subjectNumericCategories.subtracting(shipped).sorted()); only in the artifact: \(shipped.subtracting(ParsedSourceNote.subjectNumericCategories).sorted())")
    }
}
