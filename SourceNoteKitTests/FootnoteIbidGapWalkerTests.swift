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

// MARK: - FootnoteIbidGapWalkerTests

/// Pins `FootnoteIbidGapWalker` — the #1014 W-1 measurement's cross-footnote state machine.
///
/// ## What the fixtures assert
/// The walker's one job is to say what a bare `Ibid.`'s referent would be, mirroring
/// `FootnoteCitationScanner.scan`'s refusals (absence per clause, publication invalidation per
/// note, `ibidReach`) — so every test here is a short document of footnotes and an expected
/// classification, including the buckets that must NOT count toward the gap: an archival
/// referent, a refused-class referent, a publication clear, a referent out of reach.
///
/// ## The injected verdict
/// The shipped rule's schedule half lives in the generator (the schedule is a bundled JSON this
/// package deliberately does not read), so these tests inject the rule's SourceNoteKit-visible
/// prefix: refusal → subject-numeric → serial. The generator's own tests cover the composed
/// chain.
///
/// Version history:
///   1.0 — Session 2026-08-27: #1014 W-1
@Suite("Footnote Ibid. gap walker (#1014)")
struct FootnoteIbidGapWalkerTests {

    /// The shipped guard chain's SourceNoteKit-visible prefix, in the runner's own order.
    private static let verdict: @Sendable (FootnoteClassCandidate) -> String? = { candidate in
        if let refusal = candidate.refusal { return refusal }
        if candidate.isSubjectNumeric { return "subjectNumeric" }
        if !candidate.evidence.carriesSerial { return "noSerial" }
        return nil
    }

    /// Walks one document's footnotes and returns every observation plus the merged counters.
    private func walk(_ notes: [String]) -> (observations: [FootnoteIbidGapWalker.Observation],
                                             direct: Int, explicitIbid: Int, ambiguous: Int) {
        var walker = FootnoteIbidGapWalker(admissionVerdict: Self.verdict)
        walker.beginDocument()
        var observations: [FootnoteIbidGapWalker.Observation] = []
        var direct = 0, explicitIbid = 0, ambiguous = 0
        for note in notes {
            let result = walker.scan(note: note)
            observations.append(contentsOf: result.observations)
            direct += result.directAdmitted
            explicitIbid += result.explicitIbidAdmitted
            ambiguous += result.ambiguousClauses
        }
        return (observations, direct, explicitIbid, ambiguous)
    }

    // MARK: - The gap

    @Test("A bare Ibid. after an admitted class inherits it — the gap, distance 1")
    func bareIbidAfterAdmittedClass() throws {
        let result = walk(["Department of State, Central Files, 411.3441/12–257.", "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(result.observations.count == 1)
        #expect(observation.outcome == .inheritsAdmittedClass(key: "411.3441", distance: 1,
                                                              chained: false))
        #expect(observation.armingClause.contains("411.3441"))
        #expect(result.direct == 1, "the direct channel is re-derived for parity")
    }

    @Test("The referent chains: a second bare Ibid. inherits what the first one did")
    func chainedInheritance() throws {
        let result = walk(["File No. 763.72/10417.", "Ibid.", "Ibid."])
        #expect(result.observations.count == 2)
        #expect(result.observations[0].outcome
                == .inheritsAdmittedClass(key: "763.72", distance: 1, chained: false))
        #expect(result.observations[1].outcome
                == .inheritsAdmittedClass(key: "763.72", distance: 1, chained: true))
    }

    @Test("A box or date tail is a finer location, and the class still inherits")
    func boxTailStillInherits() throws {
        let result = walk(["793.94/9732.", "Ibid., Box 47."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .inheritsAdmittedClass(key: "793.94", distance: 1,
                                                              chained: false))
    }

    // MARK: - The buckets that are NOT the gap

    @Test("A lot citation between the class and the Ibid. makes the referent archival")
    func archivalReferentWins() throws {
        let result = walk(["File No. 763.72/10417.",
                           "Memorandum in Executive Secretariat Files, Lot 66–D95.",
                           "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .lastCitedIsArchival, """
            The existing channel already inherits this Ibid.; counting it as a class gap would
            double-attribute the reference and inflate the measurement.
            """)
    }

    @Test("A subject-numeric referent is a refusal, not a gap")
    func subjectNumericReferentIsRefused() throws {
        let result = walk(["Department of State, Central Files, POL 27 VIET S/8–1256.", "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .inheritsRefusedClass(key: "POL 27 VIET S",
                                                             reason: "subjectNumeric",
                                                             distance: 1))
    }

    @Test("An absence clause naming a class arms as refused — the Ibid. refers to it, the rule refuses it")
    func absenceArmedClassIsRefused() throws {
        let result = walk(["no record was found, 611.93/4–1956.", "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .inheritsRefusedClass(key: "611.93",
                                                             reason: "absenceClaim",
                                                             distance: 1))
    }

    @Test("A publication note clears the state, and the loss is priced")
    func publicationClearIsPriced() throws {
        let result = walk(["File No. 763.72/10417.",
                           "See Foreign Relations, 1914, Supplement, p. 22.",
                           "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .blockedByPublication(key: "763.72", admitted: true), """
            Refusal 3's cost has to be measured: without the shadow state, a state cleared by a
            publication would be indistinguishable from no state at all.
            """)
    }

    @Test("A publication clause trailing off in `and ibid` cites the publication, never the class")
    func publicationClauseWithTrailingIbid() throws {
        // The first corpus run classified this shape as a class inheritance — found by reading
        // the sample file (`frus1948v04/d404`: "See Foreign Relations, 1944, vol. iv, pp.
        // 257–282, passim and ibid"). `scan` tests publications before `inheritedCitation`, and
        // the walker must test them in the same order.
        let result = walk(["File No. 763.72/10417.",
                           "See Foreign Relations, 1944, vol. iv, and ibid",
                           "Ibid."])
        #expect(result.observations.count == 1, """
            The publication clause's trailing ibid is not a bare Ibid. observation — it cites
            the publication again.
            """)
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .blockedByPublication(key: "763.72", admitted: true),
                "…and as a publication-only note it clears the state for the NEXT Ibid.")
    }

    @Test("An admitted class in an archival-won clause is counted for parity, not lost")
    func archivalWonClauseParityCounter() {
        let result = walk(["Executive Secretariat Files, Lot 66–D95, 611.93/8–2255."])
        var walker = FootnoteIbidGapWalker(admissionVerdict: Self.verdict)
        walker.beginDocument()
        let note = walker.scan(note: "Executive Secretariat Files, Lot 66–D95, 611.93/8–2255.")
        #expect(note.directAdmittedInArchivalClauses == 1, """
            The runner's two passes are independent, so it counts this candidate in
            decimalReferences; the walker gives the clause to the lot. Parity needs the sum.
            """)
        #expect(note.directAdmitted == 0)
        #expect(result.ambiguous == 1)
    }

    @Test("An Ibid. carrying a page reference is a publication clause, not a bare Ibid.")
    func ibidWithPageIsPublication() throws {
        let result = walk(["File No. 763.72/10417.", "Ibid., p. 45.", "Ibid."])
        // The middle note is not a bare Ibid. (letters survive the strip), and as a
        // publication-only note it clears the state — so the LAST Ibid. is blocked.
        let observation = try #require(result.observations.first)
        #expect(result.observations.count == 1)
        #expect(observation.outcome == .blockedByPublication(key: "763.72", admitted: true))
    }

    @Test("The reach cap binds at four, and the distance is recorded")
    func beyondReachIsBucketed() throws {
        let filler = "See footnote 2 above."
        let result = walk(["File No. 763.72/10417.", filler, filler, filler, "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .beyondReach(key: "763.72", distance: 4, admitted: true))
    }

    @Test("Within reach at exactly three")
    func reachBoundaryInclusive() throws {
        let filler = "See footnote 2 above."
        let result = walk(["File No. 763.72/10417.", filler, filler, "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .inheritsAdmittedClass(key: "763.72", distance: 3,
                                                              chained: false))
    }

    @Test("A first-footnote Ibid. has no referent — never seeded from the source note")
    func noPriorCitation() throws {
        let result = walk(["Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .noPriorCitation)
    }

    @Test("The state resets at a document boundary")
    func documentBoundaryResets() throws {
        var walker = FootnoteIbidGapWalker(admissionVerdict: Self.verdict)
        walker.beginDocument()
        _ = walker.scan(note: "File No. 763.72/10417.")
        walker.beginDocument()
        let result = walker.scan(note: "Ibid.")
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .noPriorCitation)
    }

    // MARK: - Context counters

    @Test("An explicit Ibid. with its own class is already harvested, and arms the state")
    func explicitIbidCountsAndArms() throws {
        let result = walk(["Telegram 4507 from Moscow; see also Central Files, 611.93/8–2255.",
                           "Ibid., Central Files, 684A.86/8–956.",
                           "Ibid."])
        #expect(result.explicitIbid >= 1, "the explicit form is context for the step-2 rule")
        let observation = try #require(result.observations.last)
        #expect(observation.outcome == .inheritsAdmittedClass(key: "684A.86", distance: 1,
                                                              chained: false), """
            The bare Ibid. refers to the explicit Ibid.'s own class — the most recent citation —
            not to the one two notes back.
            """)
    }

    @Test("A note citing nothing leaves the state alone")
    func nonCitingNoteIsTransparent() throws {
        let result = walk(["File No. 763.72/10417.",
                           "For the Ambassador's earlier views, see footnote 3.",
                           "Ibid."])
        let observation = try #require(result.observations.first)
        #expect(observation.outcome == .inheritsAdmittedClass(key: "763.72", distance: 2,
                                                              chained: false))
    }
}
