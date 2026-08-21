// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SourceNoteKit

// MARK: - FootnoteClassCandidateTests

/// Pins `FootnoteCitationScanner.classCandidates(inNote:)` — the #834 measurement detector.
///
/// ## Every fixture is a real clause from the corpus
/// They come from `Planning/decimal-channel-measurement-sample.json`, the 820-candidate sample the
/// 2026-08-20 measurement wrote, not from invention. That matters most for the negatives: the
/// false positives pinned below are ones the detector actually produced, and the boundary between
/// them and the genuine citations is the whole design.
///
/// ## What the evidence flags are for
/// The detector never decides whether a candidate is admissible — it records what made the clause
/// recognisable and lets the report price each rule. So these tests assert the FLAGS, not a
/// verdict. A future harvest picks a rule; this decides what a rule has to work with.
///
/// Version history:
///   1.0 — Session 2026-08-20: #834 commit 1
@Suite("Footnote class candidates (#834)")
struct FootnoteClassCandidateTests {

    private func candidates(_ note: String) -> [FootnoteClassCandidate] {
        FootnoteCitationScanner.classCandidates(inNote: note)
    }

    private func single(_ note: String) throws -> FootnoteClassCandidate {
        let found = candidates(note)
        #expect(found.count == 1, "fixture guard: expected one candidate, got \(found.count)")
        return try #require(found.first)
    }

    // MARK: - The three ways a clause identifies itself

    /// The post-war form, and the only one #834's mandated rule can see.
    @Test("A Central Files clause names the repository")
    func repositoryAnchorIsRecognised() throws {
        let c = try single("Department of State, Central Files, 411.3441/12–257")
        #expect(c.classKey == "411.3441")
        #expect(c.evidence.namesRepository, "the mandated anchor-first rule depends on this flag")
        #expect(!c.evidence.shapeOnly)
    }

    /// The pre-war form. **This is the rule the measurement found the mandated one cannot reach**:
    /// `central files` is post-war naming, and 159 volumes covering 1910–1945 yield ZERO
    /// repository-anchored candidates.
    @Test("A File No. label is recognised without any repository phrase")
    func fileNumberLabelIsRecognised() throws {
        let c = try single("File No. 763.72/10417")
        #expect(c.classKey == "763.72")
        #expect(c.evidence.namesFileNumber)
        #expect(!c.evidence.namesRepository, """
            This clause carries no repository phrase, which is exactly why the mandated rule \
            returns nothing pre-war. If this ever becomes true, the measurement's headline is stale.
            """)
    }

    /// The commonest pre-war shape: no label, no repository, just the file and the paper in it.
    @Test("A bare class with its document serial is recognised by the serial alone")
    func bareSerialIsRecognised() throws {
        let c = try single("793.94/9732")
        #expect(c.classKey == "793.94")
        #expect(c.evidence.carriesSerial)
        #expect(!c.evidence.namesRepository)
        #expect(!c.evidence.namesFileNumber)
        #expect(!c.evidence.shapeOnly, "the serial IS the self-identification here")
    }

    // MARK: - The boundary: what the serial requirement keeps out

    /// **The false positives the serial rule exists to exclude**, both produced by the shape-only
    /// rule on real corpus prose. A comma'd quantity has the shape of a class and no serial.
    @Test("Prose numbers are not serial-carrying, however class-shaped they look")
    func proseNumbersCarryNoSerial() {
        for note in ["total, 771,967",
                     "to deposit its quota of 2,500,000"] {
            for c in candidates(note) {
                #expect(!c.evidence.carriesSerial, """
                    "\(note)" yielded a serial-carrying candidate (\(c.classKey)). It is a number \
                    in prose; admitting it would put a fabricated file citation on a document.
                    """)
                #expect(c.evidence.shapeOnly, "\(note) is recognisable by shape and nothing else")
            }
        }
    }

    /// **The owner's correction, pinned.** A first pass read dotless keys as false positives and
    /// proposed requiring a dot. That was wrong: dotless decimal file numbers are real, the parser
    /// admits them deliberately, and `222` composes against the 1910–49 schedule as
    /// *Extradition / Ecuador*. Measured, the dot would have discarded 326 of 4,718 pre-war
    /// candidates to exclude 28 external ones.
    @Test("A dotless class with a serial is a real citation, not a false positive")
    func dotlessClassWithSerialIsAdmitted() throws {
        let c = try single("222/4")
        #expect(c.classKey == "222")
        #expect(c.evidence.carriesSerial, """
            Dotless decimal file numbers are real — 222 is class 2 (Extradition), country 22 \
            (Ecuador). Requiring a dot here would drop genuine pre-war citations.
            """)
    }

    // MARK: - Refusals are recorded, never applied

    /// The detector records what the harvest's guards would say and leaves the decision to the
    /// report — a measurement that silently dropped refused clauses could not price the refusal.
    ///
    /// The fixture uses a REAL absence shape. `absenceRegex` wants *found / located / identified /
    /// retained / extant*, or *no record|copy|text|trace|indication* — **"Not printed" matches none
    /// of them**, which a first version of this test got wrong.
    ///
    /// It also needs the COMMA. Two different splits are in play and confusing them wastes an
    /// afternoon: a *clause* breaks on parentheses, semicolons and sentence-ending periods, while
    /// `decimalClassLocation` scans the *comma segments* inside one clause and needs the class to
    /// LEAD a segment. So `no record of 611.93/4-1956` yields nothing at all — the class sits
    /// mid-prose — whereas the comma form below puts the absence phrase and the class in the same
    /// clause and different segments, which is the shape the guard is actually for.
    @Test("An absence claim in the same clause is recorded as refused, not dropped")
    func absenceClaimIsRecordedNotDropped() throws {
        let found = candidates("no record was found, 611.93/4–1956")
        let c = try #require(found.first, "the candidate must survive so its refusal can be counted")
        #expect(c.refusal == "absenceClaim", """
            An absence-shaped clause must carry a refusal REASON rather than vanish. Dropping it \
            here would make the guard's cost invisible — the measurement exists to price refusals, \
            not to apply them.
            """)
    }

    /// **The per-clause rule, pinned.** #784 refuses absence claims per CLAUSE, not per note,
    /// precisely so `Not printed. (Truman Library, Papers of Clark M. Clifford)` still lands. The
    /// same split protects a decimal citation sitting beside an absence phrase — the citation is in
    /// its own clause and is not refused by its neighbour.
    @Test("An absence phrase in a NEIGHBOURING clause does not refuse the citation")
    func absenceInAnotherClauseDoesNotRefuse() throws {
        let found = candidates("no record was found (Department of State, Central Files, 611.93/4–1956)")
        let c = try #require(found.first { $0.classKey == "611.93" },
                             "fixture guard: the citation clause must still yield its candidate")
        #expect(c.refusal == nil, """
            The citation sits in its own clause and must survive its neighbour's absence phrase. \
            Refusing per NOTE would lose it — that is the defect the per-clause rule exists to \
            avoid, and 140 references corpus-wide depend on it.
            """)
    }

    // MARK: - Shape

    @Test("A footnote with no class yields nothing")
    func noClassYieldsNothing() {
        #expect(candidates("For documentation on this subject, see the compilation in volume IV.")
            .isEmpty)
        #expect(candidates("").isEmpty)
    }

    /// Subject-numeric designators reach the same grammar and are flagged, not dropped — #834 puts
    /// them out of scope, and a count is what makes "out of scope" a decision rather than a gap.
    @Test("A subject-numeric designator is flagged as such")
    func subjectNumericIsFlagged() throws {
        let found = candidates("Department of State, Central Files, POL 27 VIET S/8–1256")
        let c = try #require(found.first, "fixture guard: the clause must yield a candidate")
        #expect(c.isSubjectNumeric, "POL 27 VIET S is subject-numeric, not a decimal file number")
    }
}
