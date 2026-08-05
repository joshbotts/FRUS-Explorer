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

// MARK: - DecimalClassRuleTests

/// The three citation shapes that `decimalClassLocation(inCitation:)` refused (#353 / N-1a).
///
/// `decimal_class` feeds `relatedByDecimalClass`, the Archival Neighbors axis, so a decimal
/// citation with no class is absent from it entirely. **59,669 of the 71,644** unclassed rows
/// gain one from these rules.
///
/// The rules are deliberately narrow. The obvious alternative — scanning the whole note for a
/// class-shaped token — finds a similar number and is the **unbounded scan this parser already
/// abandoned**, because it stored numbered issuances from remark sentences as the row's class.
/// Everything here stays inside the citation sentence; the last test is what pins that.
///
/// Version history:
///   1.0 — Session 2026-08-05: #353 / N-1a
@Suite("Decimal class rules")
struct DecimalClassRuleTests {

    // MARK: Rule 1 — the `File No.` label (21,960 documents, 1,064 classes)

    @Test("The early volumes' File No. label no longer hides the class")
    func fileNumberLabelIsStripped() {
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "File No. 861.00/1234") == "861.00")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "File No. 763.72112/456. Telegram.") == "763.72112")
        // Tolerant of the missing period and of case, both of which occur.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "File No 812.00/9876") == "812.00")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "file no. 861.00/1") == "861.00")
    }

    @Test("The label strip does not invent a class out of a bare label")
    func labelAloneYieldsNothing() {
        #expect(SourceNoteParser.decimalClassLocation(inCitation: "File No.") == nil)
        #expect(SourceNoteParser.decimalClassLocation(inCitation: "File Number attached") == nil)
    }

    // MARK: Rule 2 — a class followed by prose (2,837 documents)

    @Test("A leading class survives prose in the same segment")
    func leadingClassBeforeProse() {
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "740.0011 European War 1939/12345: Telegram") == "740.0011")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "740.0112 European War 1939/987") == "740.0112")
    }

    @Test("The leading-token rule cannot reach past the first token")
    func leadingRuleIsAnchored() {
        // If it scanned the whole segment this would yield 861.00; it must not.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Memorandum concerning file 861.00 policy") == nil)
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Central Files material") == nil)
    }

    // MARK: Rule 3 — the dash-alpha suffix (1,165 documents, 162 classes)

    @Test("Programme and country suffixes are part of the class, not noise")
    func dashAlphaSuffixIsKept() {
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 751G.5–MSP/1–1055. Top Secret.")
                == "751G.5-MSP")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 396.1–GE/7–2255. Secret.")
                == "396.1-GE")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 711.11–EI/3–155. Secret.")
                == "711.11-EI")
    }

    @Test("An em dash in the suffix folds to the same class as an en dash")
    func emDashSuffixFoldsIdentically() {
        // Both spellings occur in the corpus for the same class; storing two forms would
        // split the neighbour set in half.
        let en = SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 751G.5–MSP/8–1055. Secret.")
        let em = SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 751G.5—MSP/8—1055. Secret.")
        #expect(en == "751G.5-MSP")
        #expect(en == em)
    }

    // MARK: Rule 3b — the space spelling of the same suffix (5,204 documents)

    @Test("The space spelling keys identically to the dash spelling")
    func spaceSuffixUnifiesWithDash() {
        // frus1952-54v13p1/d416, reported against #687: the note is space-separated, so it
        // fell through to the leading-token rule and was stored as the BARE class `751G.5` —
        // silently merged with the unrelated unsuffixed file, and absent from the MSP
        // neighbours. The space form is the more common of the two (4,851 notes vs 2,029).
        let spaced = SourceNoteParser.decimalClassLocation(inCitation: "751G.5 MSP /10–553: Telegram")
        let dashed = SourceNoteParser.decimalClassLocation(inCitation: "751G.5–MSP/10–553: Telegram")
        #expect(spaced == "751G.5-MSP")
        #expect(spaced == dashed, "the same class must key the same way in both spellings")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 396.1 GE/6–2355. Top Secret.")
                == "396.1-GE")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "033.1100 CO/4–1053-Telegram") == "033.1100-CO")
    }

    @Test("A qualified subdivision keys the same way in both spellings")
    func qualifiedSubdivisionsAgree() {
        // `740.00119 EW (39)` and `740.00119 EW (Peace)` are subdivisions of one suffixed
        // class; `740.00119 European War 1939` is a different subdivision of the bare class.
        // Whether `EW` and `European War` name the same file is an archival judgement this
        // parser must not make — so it keeps them apart, as NARA wrote them.
        // Both spellings must agree. The dash form absorbs the suffix because it rides in the
        // first token; the space form has to be taught to, or the two split apart again — the
        // same defect this PR fixes, in mirror image. My first draft of the fix had exactly
        // that asymmetry and this test is what caught it.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "740.00119 EW (39)/2645") == "740.00119-EW")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "740.00119–EW (39)/2645") == "740.00119-EW")
        // `European War` is prose, not a code, so it is never absorbed — and the two EW
        // spellings above stay distinct from it, which is NARA's own distinction, not ours.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "740.00119 European War 1939/1007: Telegram") == "740.00119")
    }

    @Test("Space-separated subject-numeric classes survive the rewrite unchanged")
    func subjectNumericClassesAreUntouched() {
        // The subject-numeric vocabulary is legitimately space-separated, and the rewrite is
        // scoped to dotted-decimal heads so it cannot reach them. (A first draft of this test
        // asserted `DEF ISR` and `POL ISR` round-trip; they do not — they were never valid
        // classes, because the subject-numeric shape requires a digit component. Checking
        // fabricated inputs proves nothing.)
        #expect(SourceNoteParser.decimalClassKey("POL 27 ARAB-ISR") == "POL 27 ARAB-ISR")
        #expect(SourceNoteParser.decimalClassKey("POL 27-14 ARAB-ISR") == "POL 27-14 ARAB-ISR")
        #expect(SourceNoteParser.decimalClassKey("POL 1 US") == "POL 1 US")
    }

    @Test("Only a short all-caps remainder becomes a suffix")
    func suffixShapeIsNarrow() {
        // Prose must never be absorbed into the class key.
        #expect(SourceNoteParser.decimalClassKey("740.0011 European") == nil)
        #expect(SourceNoteParser.decimalClassKey("751G.5 Msp") == nil)
        #expect(SourceNoteParser.decimalClassKey("751G.5 TOOLONGX") == nil)
        #expect(SourceNoteParser.decimalClassKey("751G.5 MSP") == "751G.5-MSP")
    }

    // MARK: The bound these rules must not break

    @Test("A class in a remark sentence is still never taken")
    func remarkSentencesRemainOutOfReach() {
        // The defect the citation-sentence bound exists to prevent: a secondary reference in a
        // remark becoming the row's class. All three new rules run *inside* that bound, so this
        // must still resolve to the citation's own class and never the remark's.
        let note = "Source: Department of State, Central Files, 611.61/1–2355. Secret. "
            + "For the full text see ibid., 033.84A11/10–158."
        #expect(SourceNoteParser.decimalClassLocation(inCitation: note) == "611.61")
    }

    @Test("A note whose only class is in a remark yields nothing")
    func remarkOnlyClassIsRefused() {
        let note = "Source: Department of State, Central Files. Secret. "
            + "Printed also at ibid., 033.84A11/10–158."
        #expect(SourceNoteParser.decimalClassLocation(inCitation: note) == nil)
    }

    // MARK: Existing behaviour

    @Test("Classes that already resolved still resolve identically")
    func existingShapesAreUnchanged() {
        // Verified corpus-wide as well: over all 122,033 rows that already carried a class the
        // new parser returns the same value for every one — 0 changed, 0 lost.
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Source: Department of State, Central Files, 611.61/1–2355. Secret.")
                == "611.61")
        #expect(SourceNoteParser.decimalClassLocation(
            inCitation: "Department of State, Central Files, 100.4/7–2762.") == "100.4")
        #expect(SourceNoteParser.decimalClassKey("POL 27 ARAB-ISR") == "POL 27 ARAB-ISR")
    }
}
