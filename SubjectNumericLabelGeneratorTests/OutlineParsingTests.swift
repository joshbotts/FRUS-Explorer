// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import SubjectNumericLabelGeneratorCore

// MARK: - OutlineRowTests

/// Rebuilding a handbook's table rows from page geometry (#1211).
///
/// Every fixture here is the shape of a real page, transcribed from the coordinates PDFKit returns
/// for the 1963 and 1965 Records Classification Handbooks. They are geometry rather than text
/// because the defect they pin is geometric: the flat text layer's line order is NOT the table's
/// row order, and a parser that trusts it mis-pairs designators with labels.
@Suite("Outline rows — geometry, not reading order")
struct OutlineRowTests {

    @Test("A row is defined by its y, so the flat stream's order cannot mis-pair it")
    func rowsComeFromGeometry() {
        // The real POL page 7. `selectionsByLine()` hands these back in an order that puts 17-4
        // before 17-3's label; sorting by y is what recovers the table.
        let asPDFKitReturnsThem: [PageLine] = [
            PageLine(text: "17 -3", x: 84.6, y: 595.6),
            PageLine(text: "17-4", x: 84.8, y: 574.7),
            PageLine(text: "Diplomatic & Consular Lists", x: 140.3, y: 595.6),
            PageLine(text: "Ceremonial & Social Affairs", x: 140.3, y: 574.5),
        ]
        let lines = asPDFKitReturnsThem.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y > $1.y }
        let rows = OutlineEntryParser.rows(lines)
        #expect(rows.map { $0.text } == ["17 -3 Diplomatic & Consular Lists",
                                     "17-4 Ceremonial & Social Affairs"], """
            Taking the lines in the order PDFKit returns them pairs 17-3 with Ceremonial & Social \
            Affairs. Got \(rows.map { $0.text }).
            """)
    }

    @Test("A label wrapping onto its own row extends the entry above it")
    func wrappedLabelsRejoin() {
        let lines = [
            PageLine(text: "17-5", x: 85.0, y: 512.2),
            PageLine(text: "Arrival & Departure.", x: 140.0, y: 511.9),
            PageLine(text: "Change in Status.", x: 152.3, y: 501.6),
            PageLine(text: "18", x: 84.8, y: 459.9),
            PageLine(text: "PROVINCIAL, MUNICIPAL &", x: 117.1, y: 459.7),
            PageLine(text: "STATE GOVERNMENT", x: 128.5, y: 449.1),
        ]
        let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
        #expect(parsed.entries == [
            OutlineEntry(designator: "17-5", label: "Arrival & Departure. Change in Status."),
            OutlineEntry(designator: "18", label: "PROVINCIAL, MUNICIPAL & STATE GOVERNMENT"),
        ])
    }

    @Test("The scan's split hyphen is the same designator, not a second one")
    func splitHyphensClose() {
        #expect(OutlineEntryParser.leadingDesignator("17 -3 Diplomatic")?.0 == "17-3")
        #expect(OutlineEntryParser.leadingDesignator("25- 1 Anti-Government")?.0 == "25-1")
        #expect(OutlineEntryParser.leadingDesignator("27-14 Truce.")?.0 == "27-14")
        // A label that merely opens with a word is not an entry.
        #expect(OutlineEntryParser.leadingDesignator("Accreditation") == nil)
    }

    @Test("A reserved number is refused rather than given the next entry's words")
    func reservedSlotsAreRefused() {
        // The 1965 edition prints the placeholder inline where a label would be. Shipping it would
        // tell a reader the file has a subject there.
        let lines = [
            PageLine(text: "12-2 (Reserved for future use)", x: 65.2, y: 535.5),
            PageLine(text: "12-3 Meetings & Conferences", x: 66.1, y: 514.9),
        ]
        let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
        #expect(parsed.entries == [OutlineEntry(designator: "12-3",
                                                label: "Meetings & Conferences")])
    }

    @Test("A row's pieces are joined left to right, whatever order they arrive in")
    func rowPiecesAreOrderedByX() {
        // `rows` is fed by `OutlinePageReader.lines`, which sorts, so this contract is never
        // violated in the running generator — and it is exactly the kind of guarantee that gets
        // quietly dropped as redundant. Pinned directly, because the failure it prevents is a
        // label printed before its own designator.
        let scrambled = [
            PageLine(text: "Immunities. Privileges.", x: 139.6, y: 637.2),
            PageLine(text: "17-2", x: 84.6, y: 637.3),
        ]
        #expect(OutlineEntryParser.rows(scrambled).map { $0.text }
                    == ["17-2 Immunities. Privileges."])
    }

    @Test("Furniture is refused BY THE PARSE, not merely recognised")
    func parseDropsFurniture() {
        // `isFurniture` is pinned above; this pins that `parse` actually calls it. Without the
        // call the running head opens no entry — it carries no designator — so it would be
        // appended to whatever entry preceded it, which on a continuation page is the label
        // carried over from the page before.
        let lines = [
            PageLine(text: "17-5 Arrival & Departure.", x: 85.0, y: 512.2),
            PageLine(text: "POL - POLITICAL AFFAIRS & RELATIONS", x: 82.5, y: 500.0),
            PageLine(text: "TL:RC - 1 3/1/63", x: 84.9, y: 489.0),
        ]
        let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
        #expect(parsed.entries == [OutlineEntry(designator: "17-5",
                                                label: "Arrival & Departure.")], """
            The running head and the transmittal stamp were folded into the label. Got \
            \(parsed.entries).
            """)
        #expect(parsed.refused.count == 2)
    }

    @Test("The cue cut is applied BY THE PARSE, not merely available")
    func parseCutsInstructionProse() {
        // Same species as the furniture test: `cutAtInstructionCue` is pinned above, and this
        // pins that `tidy` reaches for it.
        let lines = [
            PageLine(text: "27 MILITARY OPERATIONS", x: 86.6, y: 654.5),
            PageLine(text: "Use for declared or undeclared warfare involving", x: 104.6, y: 642.3),
        ]
        let parsed = OutlineEntryParser.parse(lines, footerFloor: 100)
        #expect(parsed.entries == [OutlineEntry(designator: "27", label: "MILITARY OPERATIONS")])
    }

    @Test("Running heads, corner marks and transmittal stamps are furniture")
    func furnitureIsRefused() {
        #expect(OutlineEntryParser.isFurniture("POL - POLITICAL AFFAIRS & RELATIONS"))
        #expect(OutlineEntryParser.isFurniture("POL-POLITICAL AFFAIRS & RELATIONS"))
        #expect(OutlineEntryParser.isFurniture("RECORDS CLASSIFICATION HANDBOOK"))
        #expect(OutlineEntryParser.isFurniture("TL:RC - 1 3/1/63"))
        #expect(OutlineEntryParser.isFurniture("POL (p. 7)"))
        // A subject that happens to contain a dash is NOT furniture — the head rule is anchored on
        // a short code, and `NON-AGGRESSION` is a real POL heading.
        #expect(OutlineEntryParser.isFurniture("PEACE. NON-AGGRESSION.") == false)
        #expect(OutlineEntryParser.isFurniture("Anti-Government") == false)
    }

    @Test("An instruction sentence that leaked into the label column is cut at its cue")
    func instructionProseIsCut() {
        // Measured on the parsed tables, 42 of 1,897 labels in the 1963 edition and 14 of 1,648 in
        // the 1965 one arrived as a correct heading followed by a sentence.
        #expect(OutlineEntryParser.cutAtInstructionCue(
            "GENERAL LEDGER Includes journal vouchers, balance sheet") == "GENERAL LEDGER")
        #expect(OutlineEntryParser.cutAtInstructionCue(
            "MILITARY OPERATIONS Use for declared or undeclared warfare") == "MILITARY OPERATIONS")
        #expect(OutlineEntryParser.cutAtInstructionCue(
            "EXHIBITS. EXHIBITIONS. Subdivide by location if volume warrants.")
                == "EXHIBITS. EXHIBITIONS.")
        // A clean heading is untouched, cue words and all — `Includes` inside a heading would be
        // cut only if it were not the first word.
        #expect(OutlineEntryParser.cutAtInstructionCue("MILITARY OPERATIONS")
                    == "MILITARY OPERATIONS")
        // THE REFUSAL THAT KEEPS A COSMETIC FIX FROM DELETING A SUBJECT: a label opening with a
        // cue is left whole rather than emptied.
        #expect(OutlineEntryParser.cutAtInstructionCue("Includes Treasury Checks.")
                    == "Includes Treasury Checks.")
    }
}

// MARK: - OutlineLayoutTests

/// Deciding how a page is laid out before reading it (#1211).
@Suite("Outline layout — one column or two, and where the instructions live")
struct OutlineLayoutTests {

    @Test("Two entry columns are found; one indented label column is not")
    func columnsAreFoundByTheGapBetweenDesignators() {
        // A 1965 two-column page: designators at 70 and at 330. Grouping rows by y alone would
        // merge them, which is how POL 3 came to carry the whole of POL 7.
        #expect(OutlinePageLayout.columnStarts([70, 71, 72, 330, 331, 332]) == [70, 330])
        // A single column whose labels are indented 60 points is ONE column. This is the case a
        // smaller gap threshold would split, silently halving every 1963 page.
        #expect(OutlinePageLayout.columnStarts([84, 85, 86, 144]) == [84])
    }

    @Test("The 1963 instruction column is the busiest far cluster, not the nearest")
    func rightColumnLayoutIgnoresTheLabelColumn() {
        // Wrapped labels sit at 116–152 and carry a line or two each; the instruction column at
        // 321 carries most of the page. Taking the nearest would cut the labels away.
        let labelColumn: [Double] = [84, 84, 116, 128, 139, 139, 151]
        // A SECOND far cluster, thinly populated. Without it "busiest" and "nearest" agree on this
        // page and the rule under test is not exercised at all — the mutation that swaps one for
        // the other survives against a single-cluster fixture.
        let strayFarLines = Array(repeating: 262.0, count: 3)
        let positions = labelColumn + strayFarLines + Array(repeating: 321.0, count: 20)
        #expect(OutlinePageLayout.dominantFarColumn(in: positions, pageWidth: 616) == 320, """
            The instruction column is the one carrying most of the page, not the leftmost thing \
            in its half — a stray wrapped line further left must not become the cut.
            """)
    }

    @Test("The 1965 instruction indent is the nearest step, not the busiest")
    func indentLayoutTakesTheNearestStep() {
        // Instructions under a whole number indent to one stop and under a sub-number to a deeper
        // one. The deeper stop carries more lines, so taking the busiest keeps every instruction
        // belonging to a whole number — which is how POL 27 shipped with its paragraph attached.
        let entries: [Double] = [65, 66, 66]
        let shallow = Array(repeating: 103.0, count: 9)
        let deep = Array(repeating: 113.0, count: 20)
        let positions = entries + shallow + deep
        #expect(OutlinePageLayout.nearestIndent(in: positions, designatorX: 65) == 100)
        // AND THE OTHER EDITION'S RULE FINDS NOTHING HERE AT ALL — the 1965 instructions sit at
        // 103 and 113 points on a 616-point page, well inside the left 40% the 1963 rule ignores.
        // So the pair is not two tunings of one idea: each rule is blind where the other works,
        // which is why the edition says which typography to expect instead of a page being asked.
        #expect(OutlinePageLayout.dominantFarColumn(in: positions, pageWidth: 616) == nil, """
            A single "find the instruction column" rule cannot serve both handbooks; if this \
            ever returns a value the two layouts have been conflated.
            """)
    }

    @Test("A column with no instruction text yields nothing rather than a guess")
    func aPageOfBareDesignatorsHasNoInstructionColumn() {
        #expect(OutlinePageLayout.nearestIndent(in: [65, 66, 66, 67], designatorX: 65) == nil)
        #expect(OutlinePageLayout.dominantFarColumn(in: [84, 85, 86], pageWidth: 616) == nil)
    }
}

// MARK: - SubjectNumericKeyTests

/// Joining a corpus class key to a handbook row (#1211).
@Suite("Subject-numeric keys — splitting and ordering")
struct SubjectNumericKeyTests {

    @Test("A key divides into the category and the designator the handbook prints")
    func keysSplit() {
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("POL 27")?.0 == "POL")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("POL 27")?.1 == "27")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("POL 27 VIET S")?.1 == "27")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("DEF 12-5 US")?.1 == "12-5")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("AID (US) 15-4 UAR")?.0 == "AID")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("AID (US) 15-4 UAR")?.1 == "15-4")
        // THE UN-SPACED KEY IS WHERE THE FOLD AND THE LOOKUP DIVIDE. #841 forbids the fold from
        // rewriting `DEF1-1` to `DEF 1-1`, because the query that follows it is a SQL LIKE prefix.
        // The LOOKUP has no such constraint, so this is where the two spellings meet the same row.
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("DEF1-1")?.0 == "DEF")
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("DEF1-1")?.1 == "1-1")
        // A decimal file number is not subject-numeric and must not be split.
        #expect(SubjectNumericLabelRunner.splitSubjectNumeric("763.72") == nil)
    }

    @Test("Designators sort numerically, so 9 precedes 10")
    func designatorsSortNumerically() {
        let sorted = ["27-14", "9", "10", "27-2", "27"].sorted(
            by: SubjectNumericLabelRunner.designatorOrder)
        #expect(sorted == ["9", "10", "27", "27-2", "27-14"], """
            A lexical sort puts 10 before 9 and 27-14 before 27-2, which makes the diagnostic \
            dump unreadable exactly where the tables are densest. Got \(sorted).
            """)
    }
}

// MARK: - AbbreviationTests

/// Reading the COMMON ABBREVIATIONS appendix, which is what identifies an organization file
/// (#1211).
@Suite("Abbreviations — the appendix that names an organization")
struct AbbreviationTests {

    @Test("A code opens an entry with or without its dash")
    func theDashIsOptional() {
        // The scan loses it often enough that requiring it folds the next entry into the previous
        // one: `SACLANT` and `SC` both arrive without one.
        #expect(SubjectNumericLabelRunner.leadingAbbreviation(
            "NATO - North Atlantic Treaty Organization")?.0 == "NATO")
        #expect(SubjectNumericLabelRunner.leadingAbbreviation(
            "SC Security Council (UN)")?.1 == "Security Council (UN)")
        #expect(SubjectNumericLabelRunner.leadingAbbreviation(
            "SACLANT Supreme Allied Command of the Atlantic")?.0 == "SACLANT")
        // A wrapped continuation opens nothing — it is prose, not a code.
        #expect(SubjectNumericLabelRunner.leadingAbbreviation(
            "(Australia, New Zealand, Pakistan,") == nil)
    }

    @Test("An expansion that swallowed the next entry is refused, however plausible it reads")
    func mergedExpansionsAreRefused() {
        // The 1965 appendix produced this, and it is three entries in a row. Shipping it would be
        // the mistake the decimal generator's refused subject layer exists to remember.
        #expect(SubjectNumericLabelRunner.isMergedExpansion(
            "General Assembly - Department Telegram - Distant Early Warning System"))
        // LENGTH IS NOT THE SIGNAL AND MUST NOT BECOME ONE. The handbook is discursive: CENTO's
        // real entry names its members and its headquarters and runs to 180 characters. A rule
        // that capped length would drop it and keep nothing better.
        #expect(SubjectNumericLabelRunner.isMergedExpansion("""
            Central Treaty Organization (Iran, Pakistan, U.S. and Turkey. U.S. is a member of the \
            economic and military committees. Successor to the Baghdad Pact). Headquarters in \
            Ankara.
            """) == false)
        #expect(SubjectNumericLabelRunner.isMergedExpansion("United Nations") == false)
    }
}

// MARK: - OrganizationLookupTests

/// Choosing between an outline and the administrative-subject list (#1211).
@Suite("Organization files — the order between the two lookups")
struct OrganizationLookupTests {

    private func schedule() -> Schedule {
        Schedule(id: "1963", startYear: 1963, endYear: 1963, source: "test",
                 categories: ["POL": "POLITICAL AFFAIRS & RELATIONS"],
                 subjects: ["POL": ["27": "MILITARY OPERATIONS", "6": "PEOPLE. BIOGRAPHIC DATA."]],
                 organizationSubjects: ["6": "MEMBERSHIP. ASSOCIATION."],
                 // POL IS IN THE APPENDIX TOO, and leaving it out makes the fixture unable to
                 // tell a correct `organizationName` from one that never checks whether the
                 // prefix is a primary subject. Measured, five of the 55 category codes head an
                 // abbreviations entry — POL among them — so the overlap is the real case.
                 abbreviations: ["UN": "United Nations", "POL": "Political Officer"],
                 areas: [:])
    }

    @Test("A primary subject reads from its own outline, never from the shared list")
    func theOutlineWinsForAPrimarySubject() {
        // `6` exists in BOTH tables and means different things. If the order were reversed, every
        // POL, DEF and E key with a designator the list also carries would take the wrong subject
        // — and each would look perfectly reasonable on screen.
        #expect(schedule().subject(category: "POL", designator: "6")
                    == "PEOPLE. BIOGRAPHIC DATA.")
        #expect(schedule().organizationName(for: "POL") == nil, """
            POL heads an abbreviations entry as well as an outline. Reading the appendix without \
            first asking whether the prefix is a primary subject would caption every POL row with \
            an unrelated expansion.
            """)
    }

    @Test("An organization reads from the list, under the name the appendix gives it")
    func organizationsReadFromTheList() {
        #expect(schedule().subject(category: "UN", designator: "6")
                    == "MEMBERSHIP. ASSOCIATION.")
        #expect(schedule().organizationName(for: "UN") == "United Nations")
    }

    @Test("A prefix the appendix does not name is refused, because the list would fit it")
    func unknownPrefixesAreRefused() {
        // THIS IS THE GUARD, and it is not hypothetical: the corpus carries `PSL 27 VIET S`, a
        // one-character corruption of POL, and `NSSD 05-82`, a National Security Study Directive.
        // Both would take a subject from the list without complaint.
        #expect(schedule().subject(category: "PSL", designator: "27") == nil)
        #expect(schedule().subject(category: "NSSD", designator: "6") == nil, """
            NSSD 6 would read as "MEMBERSHIP. ASSOCIATION." if the appendix check were dropped, \
            and nothing on screen would say the key is not a central-file class at all.
            """)
    }
}
