// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - CIAJobGrammarTests

/// The shared CIA Job grammar and its normal form (#733).
///
/// Until #733 the Job pattern was reachable only through `tryCIACollection`, which requires the
/// note to name the Agency. A front-matter outline row rarely does — its CIA identity lives in an
/// ancestor heading — so the front matter keyed no Job at all while the same collection cited in a
/// document note keyed one.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("CIA Job grammar (#733)")
struct CIAJobGrammarTests {

    @Test("The real corpus spellings all parse")
    func realSpellings() {
        // Every shape the corpus actually uses, taken from the owner's index.
        let cases: [(String, String)] = [
            ("Job 78–05091A", "78–05091A"),                                  // en-dash
            ("Job 80-01795R", "80-01795R"),                                  // hyphen
            ("Job 79R01012A", "79R01012A"),                                  // no separator
            ("Job 84–B00389R", "84–B00389R"),                                // letter mid-number
            ("DCI (McCone) Files: Job 80-B01285A", "80-B01285A"),            // prefixed by a series
            ("Job 79-R01012A, ODDI Registry", "79-R01012A"),                 // trailing segment
            ("NIC Registry of NIE and SNIE Files, Job 79–R01012A", "79–R01012A"),
            ("Job 80B01676R (DCI Logs, Minutes of Deputies Meetings)", "80B01676R"),
            ("job 95–G00278R", "95–G00278R"),                                // case-insensitive
        ]
        for (text, expected) in cases {
            #expect(SourceNoteParser.firstJobNumber(in: text) == expected,
                    "\(text) → \(SourceNoteParser.firstJobNumber(in: text) ?? "nil")")
        }
    }

    @Test("Prose senses of the word do not mint an archival key")
    func prosesSensesRefused() {
        // The measured false-positive rate over all 33,764 front-matter rows is zero, but that is
        // a property of today's corpus. The leading-digits requirement makes it structural: these
        // are what a bare `\bJob\s+(\w+)` would have keyed.
        for text in ["Job Corps records, 1965", "his job at the Department",
                     "Job Descriptions, Box 4", "the Job of the Under Secretary",
                     "Job"] {
            #expect(SourceNoteParser.firstJobNumber(in: text) == nil,
                    "\(text) must not yield a job key, got \(SourceNoteParser.firstJobNumber(in: text) ?? "nil")")
        }
    }

    @Test("A job number needs two leading digits and a body")
    func shapeGuard() {
        #expect(SourceNoteParser.firstJobNumber(in: "Job 7") == nil, "too short")
        #expect(SourceNoteParser.firstJobNumber(in: "Job 79R") == "79R", "three chars is enough")
        #expect(SourceNoteParser.firstJobNumber(in: "Job R01012A") == nil, "must open with digits")
    }

    @Test("The four spellings of one job reduce to one key")
    func normFoldsDashVariants() {
        // Job 79R01012A — the Registry of National Intelligence Estimates — is cited 214 times
        // across four spellings. Without a normal form it is four collections of 119, 55, 33 and 7.
        let spellings = ["79R01012A", "79-R01012A", "79–R01012A", "79R–01012A"]
        let keys = Set(spellings.map { SourceNoteParser.jobNumberNorm($0) })
        #expect(keys == ["79R01012A"], "got \(keys.sorted())")
    }

    @Test("The job key space is not the lot key space")
    func jobKeysAreNotLotKeys() {
        // Measured over the whole corpus: 395 job norms against 1,734 lot norms, zero collisions.
        // The two normal forms are the same transformation, so nothing but the separate column
        // keeps a job number from being looked up in `central-files-index.json`'s lot table.
        #expect(SourceNoteParser.jobNumberNorm("79–R01012A") == "79R01012A")
        #expect(SourceNoteParser.lotFileNorm("64 D 199") == "64D199")
        // A job is not recognised as a lot, and a lot is not recognised as a job.
        #expect(SourceNoteParser.firstLotReference(in: "Job 79–R01012A") == nil,
                "the lot grammar requires the word Lot")
        #expect(SourceNoteParser.firstJobNumber(in: "Lot 64 D 199") == nil,
                "the job grammar requires the word Job")
    }
}

// MARK: - FrontMatterJobKeyingTests

/// That the front-matter extractor actually emits the key (#733).
///
/// The generator's four existing promotion tests assert on `items.map(\.text)` only, so they stay
/// green whether a key is extracted correctly, incorrectly, or not at all. These drive the real
/// extractor and assert the key.
///
/// Version history:
///   1.0 — Session 2026-08-10: #733
@Suite("Front-matter CIA Job keying (#733)")
struct FrontMatterJobKeyingTests {

    /// Parses a Sources section through the **real** `parseVolumeFull` entry point, so section
    /// detection, the delegate and the promotion pass are all exercised together.
    private func parse(_ sourcesXML: String) async throws -> [VolumeSourceEntry] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus733-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("frus1961-63v10.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>fixture</title></titleStmt>
          <publicationStmt><date when="1997">1997</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><front>
            <div type="section" subtype="sources" xml:id="sources">
              <head>Sources</head>
        \(sourcesXML)
            </div>
          </front><body></body></text>
        </TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
    }

    @Test("An outline item naming a Job keys it, normalised")
    func itemRowKeysAJob() async throws {
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Central Intelligence Agency</hi>
            <list>
              <item>Job 79–R01012A (Registry of National Intelligence Estimates)</item>
              <item>DDO/DDP Files: Job 64–00352R</item>
            </list>
          </item>
        </list>
        """)
        let keyed = rows.filter { $0.jobNumber != nil }
        #expect(keyed.count == 2, "expected both job rows keyed, got \(rows.map(\.jobNumber))")
        #expect(keyed.map(\.jobNumberNorm) == ["79R01012A", "6400352R"])
        // The job must NOT land in the lot column — that column is looked up as a lot number.
        #expect(keyed.allSatisfy { $0.lotFile == nil && $0.lotFileNorm == nil },
                "a job number in lot_file would be resolved against the lot table")
    }

    @Test("A row that names no Job keys none")
    func nonJobRowsUnaffected() async throws {
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Department of State</hi>
            <list><item>Central Files, Lot 64 D 199</item></list>
          </item>
        </list>
        """)
        #expect(rows.allSatisfy { $0.jobNumber == nil })
        #expect(rows.contains { $0.lotFileNorm == "64D199" }, "the lot key still works")
    }

    @Test("The job is read from the row's own text, never inherited")
    func jobIsNotInherited() async throws {
        // Unlike repository and record group, a job number identifies ONE container. Inheriting
        // it would key every sibling to the first child's collection.
        let rows = try await parse("""
        <list>
          <item><hi rend="strong">Job 79–R01012A, Central Intelligence Agency</hi>
            <list>
              <item>Some other series with no job number</item>
            </list>
          </item>
        </list>
        """)
        let children = rows.filter { $0.depth > 0 }
        #expect(!children.isEmpty, "fixture must produce a child row")
        #expect(children.allSatisfy { $0.jobNumber == nil },
                "a child inherited a job number: \(children.map(\.jobNumber))")
    }

    @Test("The promotion pass carries the job across")
    func promotedRowKeepsItsJob() async throws {
        // `withNote` rebuilds the entry field-by-field after extraction, so an omitted field is
        // dropped from exactly the #668 paragraph-encoded collections and nowhere else — the
        // silent-loss shape this test exists to pin.
        let rows = try await parse("""
        <p rend="flushleft">Job 80–B01285A (DCI McCone Files)</p>
        <p>Records of the Director of Central Intelligence, 1961–1965.</p>
        """)
        let keyed = rows.filter { $0.jobNumber != nil }
        #expect(keyed.count == 1, "expected the promoted row to keep its job, got \(rows.map(\.jobNumber))")
        #expect(keyed.first?.jobNumberNorm == "80B01285A")
        #expect(keyed.first?.note != nil, "and to keep the description the promotion pass absorbed")
    }

    // MARK: - #809: four-digit lot prefixes

    /// Modern State lot numbers carry a four-digit accession year, and the grammar's former
    /// `{2,3}` prefix bound made them match NOTHING — not a wrong lot, no lot at all, on both
    /// the document-source-note and front-matter routes.
    ///
    /// All three are real corpus citations, found by measuring the widening over all 694 files.
    @Test("A four-digit lot prefix is recognised")
    func fourDigitLotPrefixIsFound() {
        let cases = [
            ("Lot 2015D608: Executive Secretariat, Papers of L. Paul Bremer II", "2015D608"),
            ("Department of State, EUR/RUS, Political Subject and Chronological Files, "
             + "Lot 2000D471, Shultz - Shevardnadze", "2000D471"),
            ("Lot 2016F0003: Ambassador Arthur Hartman Files", "2016F0003"),
        ]
        for (note, expected) in cases {
            let found = SourceNoteParser.firstLotReference(in: note)?.lotNumber
                .trimmingCharacters(in: .whitespaces)
            #expect(found == expected, """
                \(note.prefix(40))… yielded \(found ?? "nil"). A four-digit accession year is \
                the modern lot form, so this population grows with every volume published.
                """)
        }
    }

    /// The widening's guard rail. The tighter bound presumably existed to stop a nearby year
    /// being swallowed; measured over the corpus the discrimination actually comes from the
    /// DESIGNATOR LETTER immediately after the digits, not the digit count — so a bare year
    /// with no designator must still not read as a lot.
    @Test("A bare four-digit year is not mistaken for a lot")
    func bareYearIsNotALot() {
        #expect(SourceNoteParser.firstLotReference(in: "the lot 2015 shipment was delayed")?.lotNumber
            .trimmingCharacters(in: .whitespaces) != "2015 shipment")
        // Three- and two-digit forms are unchanged by the widening.
        #expect(SourceNoteParser.firstLotReference(in: "Lot 62 D 225, Trust Territory")?.lotNumber
            .trimmingCharacters(in: .whitespaces) == "62 D 225")
    }

    // MARK: - #353: vulgar fractions in a decimal class

    /// The decimal file uses fraction characters as real subdivisions, and each is a single
    /// Unicode character rather than digit-slash-digit — so `[A-Z0-9]` could not match one and
    /// the entire note fell to `unrecognized`.
    ///
    /// Small family, honestly: 3 notes corpus-wide (eval residue 5,974 -> 5,971). It is here
    /// because the failure mode is silent and recurs with every new decimal-era volume.
    @Test("A decimal class carrying a vulgar fraction is recognised")
    func decimalClassWithFractionParses() {
        let parser = SourceNoteParser()
        #expect(parser.parse("311.6121½") != nil, """
            A fraction subdivision still defeats the decimal grammar. Note the trap this rule was \
            first written into: `\\u{00BC}` is NOT valid NSRegularExpression syntax — the pattern \
            silently fails to compile, the property is nil, and EVERY decimal note stops matching. \
            Measured, that moved the residue to 6,292. Use literal characters.
            """)
    }

    // MARK: - #353: OCR corruptions of the Files keyword

    /// The scanned volumes misread `Files` as `Flies`/`Piles` inside `type="source"` notes —
    /// `frus1941-43` d144 is literally `<note type="source">Defense Flies</note>`. The fold
    /// runs BEFORE every strategy, so the stored series name is the corrected one; a widened
    /// keyword regex would instead have stored "Defense Flies", which `AuthorityLookup` (a
    /// name join) could never match to the real Defense Files cluster.
    ///
    /// Measured: 31 notes, all 1940-51, moving unrecognized -> namedFileSeries with nothing
    /// else shifting anywhere (category-level diff of two full eval runs).
    @Test("OCR-corrupted Files keywords fold before parsing")
    func ocrFilesVariantsFoldAndParse() {
        let parser = SourceNoteParser()
        if case .namedFileSeries(let name, _) = parser.parse("Defense Flies") {
            #expect(name == "Defense Files", "the STORED name must be the corrected one")
        } else {
            Issue.record("'Defense Flies' still unrecognized — the OCR fold is not running")
        }
        if case .namedFileSeries(let name, _) = parser.parse("Department of the Army Piles") {
            #expect(name == "Department of the Army Files")
        } else {
            Issue.record("'Department of the Army Piles' still unrecognized")
        }
        // The fold also unlocks LATER strategies: `CFM Flies: Lot M-88` becomes an inline
        // lot-file citation once the keyword reads Files (frus1949v03).
        if case .unrecognized = parser.parse("CFM Flies: Lot M–88: Box 140") {
            Issue.record("the folded text should reach the inline-lot strategy")
        }
    }

    /// The guard is keyword POSITION — a token not preceded by a capitalized word never folds,
    /// so the fold cannot touch prose even in principle.
    @Test("The OCR fold requires series-name position")
    func ocrFoldRequiresNamePosition() {
        #expect(SourceNoteParser.foldOCRKeywords("Flies were a problem")
                == "Flies were a problem", "a leading token has no preceding word and must not fold")
        #expect(SourceNoteParser.foldOCRKeywords("Defense Flies") == "Defense Files")
    }

    // MARK: - #353: suffix-bearing decimal citations (1906-51)

    /// The decimal file's subdivided forms — 269 notes, the largest #353 recovery so far,
    /// measured by positional diff of two full eval runs: every move was
    /// unrecognized -> centralFiles and NOTHING was stolen from a recognized class.
    ///
    /// Each case below is a verbatim corpus note.
    @Test("Suffix-bearing decimal forms parse as central files")
    func suffixBearingDecimalFormsParse() {
        let parser = SourceNoteParser()
        let cases = [
            "763.72119 P 43/-",                                    // office infix, dash item
            "890h.001 Am 1/\u{2013}",                               // lowercase class + infix
            "740.00111 A.R.\u{2013}Subs/la",                        // dotted infix, letter item
            "711.00111 Armament Control/Military Secrets /418",    // slash-subdivided, spaced /
            "811.612 Oranges/Spain/\u{2014}",                       // two subdivisions, em-dash item
            "811.612Oranges/Spain/\u{2014}",                        // OCR-joined infix
            "611.626/\u{2153}",                                     // fraction as the ITEM
            "818.6363/\u{2014}: Telegram",                          // em-dash item + tail
            "663.119/orig: Telegram",                              // orig item
            "412.11\u{2013}Catron, Hiram/Orig.: Telegram",          // personal-name infix
            "365.112Eagan, Edward P. et al.",                      // OCR-joined name, no item
        ]
        for note in cases {
            if case .centralFiles = parser.parse(note) { continue }
            Issue.record("still unrecognized: \(note)")
        }
    }

    /// The other side of the widening: prose is untouched. The strongest evidence is the
    /// corpus-wide positional diff (zero steals over 267,663 notes); this pins the shape.
    @Test("Prose and editorial notes do not ride the widened decimal grammar")
    func proseDoesNotBecomeCentralFiles() {
        let parser = SourceNoteParser()
        for note in ["Received through the Chinese minister, July 19, 1909.",
                     "[Enclosure\u{2014}Translation]",
                     "S. Doc. No. 515, 60th Cong., 1st sess."] {
            if case .centralFiles = parser.parse(note) {
                Issue.record("prose classified as a central file: \(note)")
            }
        }
    }

    // MARK: - #353: FRC accession series (158 notes, 1940-76)

    /// Two shapes, both verbatim corpus notes.
    ///
    /// The bare comma form (`ECA Telegram Files, FRC Acc. No. 53A278, Paris Torep : Telegram`)
    /// dies in the generic comma rule because its key segment excludes dots, which `Acc.` and
    /// `No.` both carry. The narrative form (`Source: Washington National Records Center,
    /// OASD/ISA Files: FRC 60 A 133`) dies because `tryNARACollection` requires a record group
    /// and only a MODERN accession (`FRC 330-78-0011`) encodes one — the year-first style
    /// (`FRC 60 A 133`) does not, so those notes fell through everything.
    ///
    /// Both land in `.namedFileSeries` on the argument `tryAgencyFileSeries` documents:
    /// the accession encodes no catalogue route, and asserting one would be the
    /// confidently-wrong link this workstream removes. The WNRC lead never enters the series
    /// name — WNRC is where the series sits, not what it is.
    @Test("FRC accession citations parse as named file series")
    func frcAccessionFormsParse() {
        let parser = SourceNoteParser()
        let cases: [(String, String)] = [
            ("ECA Telegram Files, FRC Acc. No. 53A278, Paris Torep : Telegram",
             "ECA Telegram Files"),
            ("ECA Telegram Files, FRC Acc. No. 53A278,", "ECA Telegram Files"),
            ("ECA message files, FRC acc. no. 53 A 278: Telegram", "ECA message files"),
            ("MSA telegram files, FRC Acc. No. 54 A 298, \u{201C}Paris Repto \u{201D}: Telegram",
             "MSA telegram files"),
            ("Source: Washington National Records Center, OASD/ISA Files: FRC 60 A 133. Secret.",
             "OASD/ISA Files"),
            ("Source: Washington National Records Center, McNamara Files: FRC 71-A-347, Box 5.",
             "McNamara Files"),
        ]
        for (note, series) in cases {
            if case .namedFileSeries(let name, let id) = parser.parse(note) {
                #expect(name == series, "series for \(note.prefix(40))")
                #expect(id?.contains("FRC") == true, "the accession stays in the identifier")
            } else {
                Issue.record("still unrecognized: \(note.prefix(60))")
            }
        }
    }

    /// The boundary that must not move: a MODERN accession leads with its record group, and
    /// those WNRC citations keep resolving to `.naraCollection` — the route with a real
    /// catalogue query — not to the weaker named-series class.
    @Test("A modern RG-first FRC accession still yields naraCollection")
    func modernFRCAccessionKeepsItsRecordGroup() {
        let parser = SourceNoteParser()
        let note = "Source: Washington National Records Center, OSD Files: FRC 330\u{2013}78\u{2013}0011, Box 63, Indian Ocean."
        if case .naraCollection(let rg, _, _, _) = parser.parse(note) {
            #expect(rg == "330", "the RG is encoded in the accession and must be extracted")
        } else {
            Issue.record("modern-accession WNRC note lost its naraCollection route")
        }
    }

    // MARK: - #353: published-source leads (41 notes)

    /// Congressional prints, statutes, DDRS, and the reprint phrase — each a verbatim
    /// corpus note, including the OCR-bent "God Cong." for "62d Cong.".
    @Test("Published-source citations classify as previouslyPublished")
    func publishedSourceLeadsClassify() {
        let parser = SourceNoteParser()
        let cases = [
            "S. Doc. No. 515, 60th Cong., 1st sess.",
            "Senate Doc. 157, God Cong., 1st sess.",
            "42 Stat. 122\u{2013}141.",
            "Printed from S. Doc. No. 150, 67th Cong., 2d sess.",
            "Public Law 93\u{2013}559.",
            "Source: Declassified Documents, 1976, 33H. Secret.",
            "Source: United States-Vietnam Relations, 1945-1967, Book 12, p. 574. Top Secret.",
            "Released to the press by the White House May 18, 1945; reprinted from "
                + "Department of State Bulletin, May 20, 1945, p. 927.",
        ]
        for note in cases {
            if case .previouslyPublished = parser.parse(note) { continue }
            Issue.record("not previouslyPublished: \(note.prefix(60))")
        }
    }

    /// The refuted rules, pinned so they are not re-derived. "Printed from" ALONE is
    /// measured-wrong (three of its six notes are archival), and a contains-anywhere
    /// Bulletin match is refuted by two editorial notes whose mention is a see-reference.
    @Test("Archival and see-reference notes refuse the published rules")
    func publishedRulesRefuseArchivalNotes() {
        let parser = SourceNoteParser()
        if case .previouslyPublished = parser.parse(
            "Printed from draft copy obtained from the Library of Congress, Manuscripts "
            + "Division, papers of Mr. Pasvolsky.") {
            Issue.record("an LC manuscript classified as previously published")
        }
        if case .previouslyPublished = parser.parse(
            "Vance discussed demilitarization with Gromyko. (Department of State Bulletin, "
            + "April 25, 1977, p. 401)") {
            Issue.record("a parenthetical see-reference classified as previously published")
        }
    }

    /// THE STEAL GUARD. The first cut of the reprint-phrase rule ran early in the narrative
    /// dispatch and took 46 archival citations whose notes merely REMARK on a reprint. The
    /// phrase now runs only at the dispatch tails; an archival note with a reprint remark
    /// must keep its archival class. The eval headline was IDENTICAL in the stolen and clean
    /// runs (5,472 both) — only the positional per-note diff exposed the difference, which is
    /// why this exists as a unit pin too.
    @Test("A reprint remark cannot steal an archival citation")
    func reprintRemarkDoesNotStealArchivalNotes() {
        let parser = SourceNoteParser()
        let note = "Source: Department of State, Central Files, 674.84A/2\u{2013}1157. Drafted by "
            + "Dulles. The text was reprinted in the Department of State Bulletin, March 4, 1957."
        if case .previouslyPublished = parser.parse(note) {
            Issue.record("""
                A Central Files citation with a Bulletin reprint remark was classified as \
                previously published. The reprint phrase may only run AFTER every archival \
                strategy has declined — check the dispatch tails.
                """)
        }
    }

    // MARK: - #353 accuracy: the strategy-steal repairs (29 notes)

    /// A library named as the LOCATION of related material must not claim the note. The
    /// audit counted 456 of these; `droppingSecondaryCopyClauses` had fixed all but 14, and
    /// every survivor used a verb phrase instead of the word "copy" — or opened its clause
    /// lowercase, which the sentence splitter cannot see.
    @Test("A related-material library remark cannot claim a central-files citation")
    func libraryRemarkDoesNotStealCentralFiles() {
        let parser = SourceNoteParser()
        let cases = [
            "Source: Department of State, Central Files, 611.93/7\u{2013}1155. Top Secret. "
                + "Early drafts of the first two paragraphs are in Eisenhower Library, Whitman File.",
            "Source: Department of State, Central Files, 320/2\u{2013}1157. a copy is in the "
                + "Eisenhower Library, Dulles\u{2013}Herter Series.",
            "Source: Department of State, Central Files, 600.0012/5\u{2013}1757. Secret. "
                + "Goodpaster and Taylor also made records of this meeting: Kennedy Library, NSF.",
        ]
        for note in cases {
            if case .centralFiles = parser.parse(note) { continue }
            Issue.record("stolen by the library remark: \(note.prefix(70))")
        }
    }

    /// §3.5: a note that LEADS with a presidential library is that library's citation, even
    /// when a State lot number rides later — the lot is the records' State-era designation,
    /// and classifying by it sends a reader to NARA for boxes that are in Boston.
    @Test("A library-led note keeps its library over a riding lot number")
    func libraryLeadOutranksRidingLot() {
        let parser = SourceNoteParser()
        let note = "Source: Kennedy Library, Crockett Papers, MS 75\u{2013}45, Lot 68 D 323. "
            + "No classification marking."
        if case .presidentialLibrary(let library, _, _) = parser.parse(note) {
            #expect(library.contains("Kennedy"), "the leading library is the repository")
        } else {
            Issue.record("library-led note still classified by its riding lot number")
        }
        // The reverse boundary: a LOT-led note remarking on a library copy stays a lot file.
        let lotLed = "Source: Department of State, Presidential Correspondence: Lot 66 D 204. "
            + "A copy is in the Eisenhower Library."
        if case .presidentialLibrary = parser.parse(lotLed) {
            Issue.record("a lot-led note was claimed by its library remark")
        }
    }

    /// The RG extractor admits the corpus's mangled forms — `RG, 330` (an OCR comma) and
    /// `RG59` (run together). Both were dropping NARA-led notes into weaker classes; both
    /// were found in the steal diff, not by reading.
    @Test("Mangled RG forms still yield naraCollection with the right record group")
    func mangledRGFormsExtract() {
        let parser = SourceNoteParser()
        let byNote = [
            ("Source: Washington National Records Center, RG, 330, OSD Files: "
             + "FRC 70 A 5127, 381 Vietnam Sensitive. Top Secret.", "330"),
            ("Source: National Archives, RG59, Central Files 1970\u{2013}73, UN 3 SC. "
             + "Confidential.", "59"),
        ]
        for (note, rg) in byNote {
            if case .naraCollection(let got, _, _, _) = parser.parse(note) {
                #expect(got == rg, "record group for \(note.prefix(50))")
            } else {
                Issue.record("mangled RG not extracted: \(note.prefix(60))")
            }
        }
    }
}
