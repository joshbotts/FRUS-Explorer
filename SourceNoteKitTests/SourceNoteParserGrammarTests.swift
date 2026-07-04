// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SourceNoteKit

// MARK: - Grammar v2 (Source Explorer Phase 2)

/// Era-realistic fixtures for every Phase 2 grammar upgrade, plus regression pins
/// for the pre-v2 grammar. Fixture texts are taken verbatim from the citations.csv
/// eval corpus (267k source notes, 520 volumes).
@Suite("SourceNoteParser grammar v2")
struct SourceNoteParserGrammarTests {

    private let parser = SourceNoteParser()

    // MARK: Decimal refs with word/office infixes (audit §2.2 bulk class)

    @Test("Decimal class with word infix parses as centralFiles with full identifier",
          arguments: [
            "893.51 Manchuria/49",
            "740.00112 European War 1939/6363",
            "500.A15A4 Naval Armaments/153",
            "396.1 GE/7–854",
            "110.11 DU/5–154",
            "740.00111A Combat Areas/113",
            "300.115 (39)/452: Telegram",
            "501. BC Indonesia/12–248: Telegram",
            "841.857 L 97/137½",
            "100.4 FEP/1–2754",
          ])
    func decimalInfix(_ note: String) {
        guard case .centralFiles(let rg, let fileId?) = parser.parse(note) else {
            Issue.record("expected .centralFiles for \(note)")
            return
        }
        #expect(rg == "RG-59")
        // The identifier is the full matched citation (class + infix + item).
        #expect(note.hasPrefix(fileId))
        #expect(fileId.contains("/"))
    }

    @Test("Infix decimal location key is the text before the slash")
    func decimalInfixLocation() {
        let parsed = parser.parse("893.51 Manchuria/49")
        #expect(parsed.archivalNeighborKey == "893.51 Manchuria")
    }

    @Test("Personnel-class citations parse as centralFiles",
          arguments: ["123M431/163", "123 F 84/16: Telegram",
                      "033.4111MacDonald, Ramsay/141"])
    func personnelClassWithItem(_ note: String) {
        guard case .centralFiles = parser.parse(note) else {
            Issue.record("expected .centralFiles for \(note)")
            return
        }
    }

    @Test("Personnel file without an item number parses as centralFiles")
    func personnelClassNoItem() {
        guard case .centralFiles(_, let fileId?) = parser.parse("123 Ward, Angus I.: Telegram") else {
            Issue.record("expected .centralFiles")
            return
        }
        #expect(fileId == "123 Ward, Angus I")
    }

    @Test("Dotted decimal class without an item slash parses as centralFiles")
    func decimalNoItem() {
        guard case .centralFiles(_, let fileId?) = parser.parse("102.8951: Telegram") else {
            Issue.record("expected .centralFiles")
            return
        }
        #expect(fileId == "102.8951")
    }

    @Test("Bare Numerical File refs with trailing matter parse as centralFiles")
    func bareNumericalFileWithTrailer() {
        guard case .centralFiles = parser.parse("195/597: Telegram") else {
            Issue.record("expected .centralFiles")
            return
        }
    }

    @Test("Prose starting with a year can not match the infix decimal rule")
    func infixDoesNotSwallowProse() {
        if case .centralFiles = parser.parse("1918/19 annual report of the mission") {
            Issue.record("prose must not classify as centralFiles")
        }
    }

    // MARK: Paris Peace Conference decimals (RG 256)

    @Test("Paris Peace Conference decimals map to RG 256 with a canonical prefix",
          arguments: ["Paris Peace Conf. 185.001/28: Telegram",
                      "Paris Peace Conference 180.03101/14",
                      "Paris peace Conf. 184.44/1"])
    func parisPeaceConference(_ note: String) {
        guard case .centralFiles(let rg, let fileId?) = parser.parse(note) else {
            Issue.record("expected .centralFiles for \(note)")
            return
        }
        #expect(rg == "RG-256")
        #expect(fileId.hasPrefix("Paris Peace Conf. "))
    }

    // MARK: File No. punctuation/typo variants

    @Test("File No. punctuation variants parse as centralFiles",
          arguments: [
            ("File. No. 9254/5–7.", "9254/5–7"),
            ("File No, 352/8.", "352/8"),
            ("FileNo.812.415A/125.", "812.415A/125"),
            ("File Not 7523.", "7523"),
            ("File Nos. 817.00/1593, 1594, 1595.", "817.00/1593"),
          ])
    func fileNoVariants(_ fixture: (String, String)) {
        guard case .centralFiles(_, let fileId?) = parser.parse(fixture.0) else {
            Issue.record("expected .centralFiles for \(fixture.0)")
            return
        }
        #expect(fileId == fixture.1)
    }

    @Test("'File Nothing…' prose can not match the File No. rule")
    func fileNoRejectsProse() {
        if case .centralFiles = parser.parse("File Nothing was received on this subject.") {
            Issue.record("prose must not classify as centralFiles")
        }
    }

    // MARK: Loose lot styles

    @Test("Lowercase comma lot style parses as lotFile")
    func lowercaseCommaLot() {
        let note = "PPS files, lot 64 D 563, “Administrative Transition.”"
        guard case .lotFile(let rg, let lot, _) = parser.parse(note) else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(rg == "RG-59")
        #expect(lot == "64 D 563")
    }

    @Test("Lot-leading note with en-dash parses as lotFile with box")
    func lotLeadingEnDash() {
        guard case .lotFile(_, let lot, let fileId) = parser.parse("Lot 71–D 440, Box 19232") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(lot == "71–D 440")
        #expect(fileId == "Box 19232")
    }

    @Test("Run-together designator parses as lotFile")
    func runTogetherLot() {
        guard case .lotFile(_, let lot, _) = parser.parse("Marshall Mission Files, Lot 54–D270") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(lot == "54–D270")
    }

    @Test("Letter-first designator parses as lotFile")
    func letterFirstLot() {
        guard case .lotFile(_, let lot, _) = parser.parse("CFM files lot M 88, box 166 “NATO Ministerial Meeting Paris 1953”") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(lot == "M 88")
    }

    @Test("F-designator loose lot routes to RG 84")
    func looseLotFDesignator() {
        guard case .lotFile(let rg, _, _) = parser.parse("Office files, lot 57–F103, 800 Korea") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(rg == "RG-84")
    }

    @Test("The English word 'lot' without the designator shape does not match")
    func englishLotDoesNotMatch() {
        if case .lotFile = parser.parse("A lot of related correspondence is filed elsewhere.") {
            Issue.record("the English word 'lot' must not classify as lotFile")
        }
    }

    // MARK: lotFileNorm

    @Test("lotFileNorm produces the canonical compact key",
          arguments: [
            ("64 D 199", "64D199"),
            ("64-D-199", "64D199"),
            ("71–D 440", "71D440"),
            ("54—D270", "54D270"),
            ("60 d 665", "60D665"),
            ("M 88", "M88"),
          ])
    func lotFileNorm(_ fixture: (String, String)) {
        #expect(SourceNoteParser.lotFileNorm(fixture.0) == fixture.1)
    }

    // MARK: Presidential-library lead notes (no "Source:" prefix)

    @Test("Library-lead note without Source: prefix parses as presidentialLibrary")
    func libraryLeadNote() {
        let note = "Eisenhower Library, Dulles papers, “Telephone Conversations”"
        guard case .presidentialLibrary(let library, let collection, _) = parser.parse(note) else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "Eisenhower Library")
        #expect(collection == "Dulles papers")
    }

    @Test("Truman Library lead note parses as presidentialLibrary")
    func trumanLead() {
        guard case .presidentialLibrary(let library, _, _) = parser.parse("Truman Library, Acheson papers") else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "Truman Library")
    }

    @Test("A library inside a comma list is not a lead and does not trigger")
    func libraryMidListDoesNotTrigger() {
        if case .presidentialLibrary = parser.parse("Dulles papers, Eisenhower Library") {
            Issue.record("comma-list mention must not classify as presidentialLibrary")
        }
    }

    // MARK: Manuscript repositories (lead-gated)

    @Test("Library of Congress lead narrative parses as repository/collection")
    func libraryOfCongressLead() {
        let note = "Source: Library of Congress, Manuscript Division, Harriman Papers, IJKL. Confidential."
        guard case .presidentialLibrary(let library, let collection, _) = parser.parse(note) else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "Library of Congress")
        #expect(collection == "Manuscript Division")
    }

    @Test("University lead narrative parses as repository/collection")
    func universityLead() {
        let note = "Source: University of Montana, Mansfield Papers, Series XXII, Box 107, Vietnam."
        guard case .presidentialLibrary(let library, let collection, _) = parser.parse(note) else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "University of Montana")
        #expect(collection == "Mansfield Papers")
    }

    // MARK: Named file series

    @Test("Colon-form named series parses with series and file key")
    func namedSeriesColon() {
        guard case .namedFileSeries(let series, let fileId) = parser.parse("IO Files: US(P)/A/351") else {
            Issue.record("expected .namedFileSeries")
            return
        }
        #expect(series == "IO Files")
        #expect(fileId == "US(P)/A/351")
    }

    @Test("Comma-form named series requires a digit-bearing key")
    func namedSeriesComma() {
        guard case .namedFileSeries(let series, let fileId) = parser.parse("Conference files, CF 292") else {
            Issue.record("expected .namedFileSeries")
            return
        }
        #expect(series == "Conference files")
        #expect(fileId == "CF 292")
    }

    @Test("Whole-note named collections parse with a nil file key",
          arguments: ["J. C. S. Files", "Roosevelt Papers: Telegram", "Bohlen Collection",
                      "War Trade Board Files", "Department of State Atomic Energy Files"])
    func namedSeriesWholeNote(_ note: String) {
        guard case .namedFileSeries(_, let fileId) = parser.parse(note) else {
            Issue.record("expected .namedFileSeries for \(note)")
            return
        }
        #expect(fileId == nil)
    }

    @Test("Source: narratives leading with a named collection parse as namedFileSeries")
    func narrativeNamedSeries() {
        let note = "Source: Collins Papers, Vietnam File, Series VII, L. Secret."
        guard case .namedFileSeries(let series, let fileId) = parser.parse(note) else {
            Issue.record("expected .namedFileSeries")
            return
        }
        #expect(series == "Collins Papers")
        #expect(fileId == "Vietnam File, Series VII, L")
    }

    @Test("Source: narrative that is only a named collection parses with nil key")
    func narrativeNamedSeriesBare() {
        guard case .namedFileSeries(let series, let fileId) = parser.parse("Source: JCS Files. Top secret.") else {
            Issue.record("expected .namedFileSeries")
            return
        }
        #expect(series == "JCS Files")
        #expect(fileId == nil)
    }

    @Test("Paris Peace Conference council designations parse as namedFileSeries",
          arguments: ["HD–46", "BC–29", "WCP–1133", "IC–175D"])
    func councilSeries(_ note: String) {
        guard case .namedFileSeries(_, let fileId) = parser.parse(note) else {
            Issue.record("expected .namedFileSeries for \(note)")
            return
        }
        #expect(fileId == note)
    }

    @Test("namedFileSeries exposes no archival-neighbor key (Phase 3 wires the matcher)")
    func namedSeriesHasNoNeighborKey() {
        let parsed = parser.parse("Conference files, CF 292")
        #expect(parsed.archivalNeighborKey == nil)
        #expect(!parsed.supportsArchivalNeighbors)
    }

    // MARK: Abstract notes with trailing citations (1961–1963 supplements)

    @Test("Abstract with trailing Kennedy Library citation parses as presidentialLibrary")
    func abstractLibraryTail() {
        let note = "Decisions on key issues for 18-Nation Disarmament Conference. Confidential. 4 pp. "
            + "Kennedy Library, National Security Files, Kaysen Series, Disarmament."
        guard case .presidentialLibrary(let library, _, _) = parser.parse(note) else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "Kennedy Library")
    }

    @Test("Abstract with trailing WNRC citation parses as naraCollection")
    func abstractWNRCTail() {
        let note = "Option III—Invasion. Top Secret. 9 pp. WNRC, RG 330, OASD (C) A Files: "
            + "FRC 71 A 2896, Nitze Files: Black Book, Cuba, Vol. I."
        guard case .naraCollection(let rg, _, _, _) = parser.parse(note) else {
            Issue.record("expected .naraCollection")
            return
        }
        #expect(rg == "330")
    }

    @Test("Abstract with trailing CIA job citation parses as ciaCollection")
    func abstractCIATail() {
        let note = "Soviet missile threat in Cuba. Top Secret. 2 pp. CIA Files: Job 80–R01386R, "
            + "O/D/NFAC, Box 1, Cuba (20 Oct–22 Oct 1962)."
        guard case .ciaCollection(let job?, _, _) = parser.parse(note) else {
            Issue.record("expected .ciaCollection")
            return
        }
        #expect(job == "80–R01386R")
    }

    @Test("Abstract with trailing DOS abbreviation parses as centralFiles")
    func abstractDOSTail() {
        let note = "Settlement of the Chamizal dispute. Confidential. 3 pp. DOS, CF, POL 32–1 MEX–US."
        guard case .centralFiles = parser.parse(note) else {
            Issue.record("expected .centralFiles")
            return
        }
    }

    // MARK: WNRC FRC-derived record groups

    @Test("Records-center-led note derives the RG from a modern FRC accession",
          arguments: [
            ("Source: Washington National Records Center, OSD Files: FRC 330–78–0011, Box 66, Iran. Secret.", "330"),
            ("Source: Washington National Records Center, OSD Files: FRC 330 70 A 1266, 381 (Alpha). Secret.", "330"),
            ("Source: Washington National Records Center, Department of the Treasury, Files of Under Secretary Volcker: FRC 56 79 15, CIEP. Confidential.", "56"),
          ])
    func frcDerivedRecordGroup(_ fixture: (String, String)) {
        guard case .naraCollection(let rg, _, _, _) = parser.parse(fixture.0) else {
            Issue.record("expected .naraCollection for \(fixture.0)")
            return
        }
        #expect(rg == fixture.1)
    }

    @Test("Year-first FRC accessions carry no RG and do not classify as naraCollection")
    func frcYearFirstHasNoRG() {
        let note = "Source: Washington National Records Center, OSD/ISA Files: FRC 62 A 1698, 092 Vietnam. Secret."
        if case .naraCollection = parser.parse(note) {
            Issue.record("year-first FRC accession must not yield an RG")
        }
    }

    @Test("A secondary WNRC mention can not reclassify a library-led note")
    func frcSecondaryMentionGated() {
        let note = "Source: Johnson Library, National Security File, Arms Limits. Secret. "
            + "A copy is in the Washington National Records Center, OSD Files: FRC 330 69 A 7425."
        guard case .presidentialLibrary(let library, _, _) = parser.parse(note) else {
            Issue.record("expected .presidentialLibrary")
            return
        }
        #expect(library == "Johnson Library")
    }

    // MARK: Previously published print citations

    @Test("Public Papers and campaign print citations parse as previouslyPublished",
          arguments: [
            "Source: Public Papers: Carter, 1978, Book I, pp. 129–144. The President spoke at 9 a.m.",
            "Source: Public Papers of the Presidents of the United States: John F. Kennedy, 1961, pp. 1–3.",
            "Source: The Presidential Campaign 1976, volume I, part I: Jimmy Carter, pp. 66–70.",
        ])
    func publicPapers(_ note: String) {
        guard case .previouslyPublished = parser.parse(note) else {
            Issue.record("expected .previouslyPublished for \(note)")
            return
        }
    }

    @Test("Treaty Series print citations parse as previouslyPublished")
    func treatySeries() {
        guard case .previouslyPublished = parser.parse("Treaty Series No. 762") else {
            Issue.record("expected .previouslyPublished")
            return
        }
    }

    // MARK: Regression pins (pre-v2 grammar unchanged)

    @Test("Strict decimal citations still parse exactly as before")
    func strictDecimalUnchanged() {
        guard case .centralFiles(let rg, let fileId?) = parser.parse("862S.01/10-1646: Telegram") else {
            Issue.record("expected .centralFiles")
            return
        }
        #expect(rg == "RG-59")
        #expect(fileId == "862S.01/10-1646")
    }

    @Test("Inline colon lot files still parse as lotFile")
    func inlineLotUnchanged() {
        guard case .lotFile(_, let lot, _) = parser.parse("OAS Files: Lot 60 D 665, Box 5") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(lot == "60 D 665")
    }

    @Test("Structured NARA narratives still parse as naraCollection")
    func naraNarrativeUnchanged() {
        let note = "Source: National Archives, RG 59, Central Decimal File 1910–1929, Box 736."
        guard case .naraCollection(let rg, _, _, _) = parser.parse(note) else {
            Issue.record("expected .naraCollection")
            return
        }
        #expect(rg == "59")
    }

    @Test("Central Files narratives still parse as centralFiles")
    func centralFilesNarrativeUnchanged() {
        let note = "Source: Department of State, Central Files 1963–66, POL 14. Secret."
        guard case .centralFiles = parser.parse(note) else {
            Issue.record("expected .centralFiles")
            return
        }
    }

    @Test("Pre-1906 non-archival annotations stay unrecognized",
          arguments: ["[Extract.]", "[Translation.]", "E.", "True copy:"])
    func pre1906StaysUnrecognized(_ note: String) {
        guard case .unrecognized = parser.parse(note) else {
            Issue.record("expected .unrecognized for \(note)")
            return
        }
    }

    @Test("Attachment placeholders stay unrecognized",
          arguments: ["[Attachment]", "[Enclosure 1]", "[Tab A]", "Annex B"])
    func attachmentsStayUnrecognized(_ note: String) {
        guard case .unrecognized = parser.parse(note) else {
            Issue.record("expected .unrecognized for \(note)")
            return
        }
    }

    // MARK: - Shared lot grammar (Phase 3: firstLotReference)

    @Test("firstLotReference recognizes every designator and formatting variant",
          arguments: [
            ("Lot 64 D 199, Records of the Policy Planning Staff", "64 D 199"),
            ("RG 84 post records, Lot 62 F 83", "62 F 83"),
            ("Lot W 130, Records of the Department", "W 130"),
            ("C.F.M. Files: Lot M–88: Box 2063", "M–88"),
            ("Marshall Mission Files, Lot 54–D270", "54–D270"),
            ("Lot 90 D 313Records of the Executive Secretariat", "90 D 313"),
            ("Lot File 57 D 577, Box 3", "57 D 577"),
            ("Lot Files 74 D 131", "74 D 131"),
            ("E–CFEP Files, Lot 61 D 282A", "61 D 282A"),        // letter suffix kept
            ("CFEP Files: Lot 61 D 282a, Soviet Economic Penetration", "61 D 282a"),
          ])
    func firstLotReferenceVariants(_ text: String, _ expected: String) {
        let found = SourceNoteParser.firstLotReference(in: text)
        #expect(found?.lotNumber == expected)
    }

    @Test("firstLotReference never matches the English word lot without a number shape",
          arguments: ["a lot of documentation exists", "the vacant lot beside the chancery",
                      "Lot Files"])
    func firstLotReferenceRejectsProse(_ text: String) {
        #expect(SourceNoteParser.firstLotReference(in: text) == nil)
    }

    @Test("Lot File infix notes now parse as lotFile on the document side")
    func lotFileInfixParsesAsLot() {
        guard case .lotFile(_, let lot, _) = parser.parse("Lot File 57 D 577, Box 3") else {
            Issue.record("expected .lotFile")
            return
        }
        #expect(lot == "57 D 577")
        #expect(SourceNoteParser.lotFileNorm(lot) == "57D577")
    }

    // MARK: - Shared class grammar (Phase 3 verification: decimalClassKey)

    @Test("decimalClassKey canonicalizes class-leaf shapes (dashes → hyphen)",
          arguments: [
            ("POL 27 ARAB–ISR", "POL 27 ARAB-ISR"),   // en-dash → hyphen
            ("POL 27 ARAB-ISR", "POL 27 ARAB-ISR"),   // hyphen fixed point
            ("POL 15–1 IRAN", "POL 15-1 IRAN"),
            ("DEF 6 MLF", "DEF 6 MLF"),
            ("E 12 IRAN", "E 12 IRAN"),
            ("711.11", "711.11"),
            ("500.A15A4", "500.A15A4"),
            ("484A.8612", "484A.8612"),
            ("AID (US) 15–4 UAR", "AID (US) 15-4 UAR"), // parenthesized agency qualifier
            (" 611.80. ", "611.80"),                    // trims + strips trailing period
          ])
    func decimalClassKeyVariants(_ candidate: String, _ expected: String) {
        #expect(SourceNoteParser.decimalClassKey(candidate) == expected)
    }

    @Test("decimalClassKey rejects prose, record groups, and non-class shapes",
          arguments: ["RG 59", "FRC 330–78–0011", "Arab unity", "NEA Files",
                      "Records of the Executive Secretariat", "1977–1980",
                      "POL Near East 1", "Vol. 12", "as maintained by the Executive Secretariat."])
    func decimalClassKeyRejects(_ candidate: String) {
        #expect(SourceNoteParser.decimalClassKey(candidate) == nil)
    }

    @Test("decimalClassLocation extracts the class location from citations")
    func decimalClassLocationShapes() {
        // Narrative decimal: item suffix cut at "/".
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Department of State, Central Files, 788.5/9–1361. Top Secret.") == "788.5")
        // Subject-numeric structured: sentence tail cut at ". ".
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "National Archives and Records Administration, RG 59, Central Files 1967–69, POL 27 ARAB-ISR. Secret; Immediate.") == "POL 27 ARAB-ISR")
        // Subdivision with an item suffix.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "RG 59, Central Files 1967–69, POL 27-14 ARAB-ISR/SANDSTORM. Secret.") == "POL 27-14 ARAB-ISR")
        // Old-style decimal-leading note (no narrative prefix).
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "611.41/3–553. Foreign Service despatch.") == "611.41")
        // CFPF reel identifiers are not classes.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Department of State, Central Foreign Policy File, P840114–1808") == nil)
        // Library citations carry no class-shaped segment.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Johnson Library, National Security File, Country File, Vietnam, Vol. 12. Top Secret.") == nil)
    }
}
