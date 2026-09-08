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
        let positions = labelColumn + Array(repeating: 321.0, count: 20)
        #expect(OutlinePageLayout.dominantFarColumn(in: positions, pageWidth: 616) == 320)
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
            A single "find the instruction column" rule cannot serve both handbooks; if this ever             returns a value the two layouts have been conflated.
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
