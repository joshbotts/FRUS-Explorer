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

// MARK: - SecondaryClauseLotTests

/// A lot number named **outside** a note's own citation clause belongs to another document
/// (#353 §3.5).
///
/// ## The defect
/// Three strategies extracted lots — `tryInlineLotFile` (second in `parse()`, ahead of every
/// decimal rule), `tryNarrativeLotFile`, and `tryLooseLotFile` — and each scanned the entire
/// note and took the first `Lot` it found. FRUS routinely names a second archive later in a
/// note: where another copy of the document lives, or where a document the *remark* cites
/// lives. Both shapes flipped the whole note onto the lot route, filing it under an archive
/// its own citation does not claim.
///
/// Measured over the corpus with the shipped parser: **581 documents corrected** — 261 to
/// `centralFiles`, 209 to `presidentialLibrary`, 78 to `naraCollection`, 28 to `cfpfFile`,
/// 5 to `ciaCollection` — and **0 lost**. Every one moved to a *more* specific repository;
/// none fell to `unrecognized`. The owner reached 229 and 275 for two of these shapes
/// independently, from the live index.
///
/// ## The constraint that shapes the rule
/// The scope narrows **only when the leading sentence has already named a competing
/// repository**. A blanket "the lot must be in sentence 1" rule is the obvious version and it
/// is wrong: the 1961–1963 abstract notes are genuinely lot files and put their citation in
/// the tail (`"Anatomy of the revolution in Ecuador. Secret. 2 pp. WNRC, RG 59, S/P Files:
/// Lot 67 D 548, Ecuador."`). Measured, that rule would have broken **1,006** correct
/// classifications — four times what the defect is worth. The last two tests pin that.
///
/// Version history:
///   1.0 — Session 2026-08-06: #353 §3.5
@Suite("Secondary-clause lot steal")
struct SecondaryClauseLotTests {

    private let parser = SourceNoteParser()

    private func kind(_ note: String) -> String {
        switch parser.parse(note) {
        case .lotFile: return "lotFile"
        case .centralFiles: return "centralFiles"
        case .presidentialLibrary: return "presidentialLibrary"
        case .naraCollection: return "naraCollection"
        case .cfpfFile: return "cfpfFile"
        case .ciaCollection: return "ciaCollection"
        case .namedFileSeries: return "namedFileSeries"
        case .unrecognized: return "unrecognized"
        default: return "other"
        }
    }

    // MARK: - The three channels

    /// `tryInlineLotFile` runs **second in `parse()`**, ahead of every decimal rule, so an
    /// `Ibid., Conference Files: Lot 65 D 533` in a remark outranked the decimal citation the
    /// note leads with. 429 documents — the largest of the three channels, and the one the
    /// owner hit in #675 when `72A6248` was the single lot he could not clear.
    @Test("A lot in a remark does not outrank the decimal citation the note leads with")
    func remarkLotDoesNotBeatTheLeadingDecimalCitation() {
        let note = """
            Source: Department of State, Central Files, 110.11–RU/6–2362. Secret. According to \
            another copy, this telegram was drafted by Rusk and cleared by Kohler . (Ibid., \
            Conference Files: Lot 65 D 533, CF 2100.)
            """
        #expect(kind(note) == "centralFiles",
                "the note cites the central decimal file; the lot is the parenthetical's")
    }

    /// The shape from the owner's own report: a Central Files primary clause whose trailing
    /// parenthetical cites a *different* document held in a lot.
    @Test("A Central Files citation keeps its own classification")
    func centralFilesPrimaryClauseWins() {
        let note = """
            Source: Department of State, Central Files, TEL 9. (E Bureau Staff Minutes, \
            March 15; Washington National Records Center, E/CBA/REP Files: Lot 72 A 6248)
            """
        #expect(kind(note) == "centralFiles")
    }

    /// `tryNarrativeLotFile` scanned the whole body and ran *before* `tryPresidentialLibrary`,
    /// so a Carter Library citation whose later sentence mentioned a lot was filed as a State
    /// Department lot file — a wrong archive on 209 documents.
    @Test("A presidential-library citation is not flipped by a later lot")
    func libraryCitationSurvivesALaterLot() {
        let note = """
            Source: Carter Library, National Security Affairs, Brzezinski Material, Country \
            File, Box 21, El Salvador: 12/80–1/81. Secret; Sensitive. Another copy is in the \
            Department of State, S/S Files: Lot 92 D 630.
            """
        #expect(kind(note) == "presidentialLibrary")
    }

    /// The Library of Congress leads are the same defect, reached through
    /// `manuscriptRepositoryKeywords` rather than the presidential-library list. Only 4
    /// documents, but each is a wrong archive on a named personal collection.
    @Test("A manuscript-repository citation is not flipped by a later lot")
    func manuscriptRepositoryLeadSurvivesALaterLot() {
        let note = """
            Source: Library of Congress, Manuscript Division, Harriman Papers, Special Files, \
            Public Service, General File, April 1967. Secret. Drafted by Roy on April 21. A \
            copy is also in Department of State, S/S Files: Lot 69 D 277.
            """
        #expect(kind(note) != "lotFile",
                "the cited original is at the Library of Congress, not in a State lot")
    }

    // MARK: - What must NOT change

    /// The 1961–1963 abstract notes put the citation in the **tail**, and they are genuinely
    /// lot files. This is the case that rules out the simpler "lot must be in sentence 1"
    /// rule: 1,006 documents, four times the defect's size.
    @Test("An abstract note whose citation is in the tail is still a lot file")
    func abstractTailCitationStaysALotFile() {
        for note in [
            "Anatomy of the revolution in Ecuador. Secret. 2 pp. WNRC , RG 59, S/P Files: Lot 67 D 548, Ecuador.",
            "Acheson’s meetings in London. No classification marking. 10 pp. DOS , Bruce Diaries: Lot 64 D 327.",
            "Addresses input from regional bureaus on key issues. Secret. 4 pp. Department of State, S/P Files: Lot 70 D 199, Secretary’s PPMs.",
        ] {
            #expect(kind(note) == "lotFile",
                    Comment(rawValue: "abstract-tail citation lost its lot: \(note)"))
        }
    }

    /// A note whose leading clause names the lot itself is untouched — the scope only narrows,
    /// and the lot is inside the narrowed span.
    @Test("A lot named in the citation clause still classifies as a lot file")
    func leadingLotIsUnaffected() {
        #expect(kind("Source: Department of State, S/S Files: Lot 63 D 351, NSC Meetings.") == "lotFile")
        #expect(kind("Source: Department of State, Conference Files: Lot 65 D 533, CF 2200.") == "lotFile")
    }

    /// `namesCompetingRepository` uses the central-files **anchor**, not the bare
    /// `"Department of State"` test `matchesCentralFiles(_:)` would supply.
    ///
    /// Measured, that swap changes 373 documents and is a net loss: 61 fall back out of a
    /// specific repository into `lotFile` and 2 into `unrecognized`. This is the shape that
    /// causes it — a National Archives citation that names the central files and never names
    /// the Department, so the bare test does not fire, the scope stays the whole note, and a
    /// lot mentioned later captures the citation.
    ///
    /// The first version of this test asserted the same choice using an abstract note, and was
    /// **vacuous**: an abstract note's *leading sentence* is prose, so neither predicate fires
    /// on it and the mutation survived. Pinning a real regressing shape is what makes it bite.
    @Test("A NARA citation naming the central files is not captured by a later lot")
    func centralFilesAnchorCatchesANARALead() {
        let note = """
            Source: National Archives and Records Administration, RG 59, Central Files 1960–63, \
            110.10/5–1062. No classification marking. Another copy is in the Department of \
            State, S/S Files: Lot 63 D 351.
            """
        #expect(kind(note) == "naraCollection",
                "the cited original is the NARA central-files citation, not the later lot")
        #expect(SourceNoteParser.lotClaimScope(note) != note,
                "the leading sentence names the central files, so the scope must narrow")
    }

    /// The other half of the same choice: a lead that names *only* the Department is not a
    /// competing repository, so the scope stays whole and a lot later in the note still counts.
    @Test("A lead naming only the Department does not narrow the scope")
    func bareDepartmentOfStateIsNotACompetingRepository() {
        let note = "Source: Department of State. Secret. S/P Files: Lot 67 D 548."
        #expect(SourceNoteParser.lotClaimScope(note) == note,
                "a lead naming only the Department must not narrow the lot scope")
        #expect(kind(note) == "lotFile")
    }
}
