// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - KWICBuilderTests

/// The concordance line builder: every occurrence, aligned, with windows that never split a word.
@Suite("KWIC builder")
struct KWICBuilderTests {

    private func build(_ body: String, _ stems: [String], radius: Int = 20) -> KWICBuilder.DocumentScan {
        KWICBuilder.build(body: body, stems: stems, radius: radius,
                          volumeId: "frus1969-76v01", documentId: "d1",
                          header: "1. Memo", dateISO: "1971-03-01")
    }

    @Test("Every occurrence produces a line, not just the first")
    func everyOccurrenceIsALine() {
        // The whole reason the concordance does not reuse `makeContextSnippet`, which stops at the
        // first match. A document that says a thing three times is a different finding from one that
        // says it once.
        let scan = build("The treaty was signed. A second treaty followed. A third treaty lapsed.",
                         ["treati"])
        #expect(scan.lines.count == 3)
        #expect(scan.lines.map(\.match) == ["treaty", "treaty", "treaty"])
        // Offsets ascend and differ, which is what makes each line individually addressable.
        #expect(scan.lines.map(\.offset) == scan.lines.map(\.offset).sorted())
        #expect(Set(scan.lines.map(\.id)).count == 3, "Lines within one document must have distinct ids")
    }

    @Test("The match is the document's word, not the stem and not the query")
    func matchIsTheSurfaceForm() {
        let scan = build("Their alliances were reaffirmed.", ["alli"])
        #expect(scan.lines.count == 1)
        // `alli`, not `allianc`: the app's Swift PorterStemmer and SQLite's `porter unicode61`
        // disagree on this very word, and the concordance matches with the Swift one because that is
        // what the highlighter uses. Using SQLite's stem here produced zero lines — the disagreement
        // the builder's doc comment warns about, caught by its own test.
        #expect(scan.lines[0].match == "alliances",
                "A concordance shows what the document says; substituting the stem would misquote it")
    }

    @Test("Context windows never begin or end mid-word")
    func windowsSnapToWordBoundaries() throws {
        //                       0123456789...
        let body = "extraordinary circumstances the treaty determined subsequent negotiations"
        let scan = build(body, ["treati"], radius: 8)
        let line = try #require(scan.lines.first)
        // A raw ±8 window would cut "circumstances" and "determined" in half.
        #expect(!line.left.isEmpty)
        #expect(!line.right.isEmpty)
        #expect(!body.contains(line.left + "x"), "sanity: left is a substring of the body")
        for fragment in [line.left, line.right] {
            for word in fragment.split(separator: " ") {
                #expect(body.contains(String(word)),
                        "\"\(word)\" is a partial word — the window did not snap to a boundary")
            }
        }
    }

    @Test("A match at the very start or end of a document still yields a line")
    func matchesAtTheEdges() {
        let atStart = build("Treaty obligations were reviewed at length.", ["treati"], radius: 30)
        #expect(atStart.lines.count == 1)
        #expect(atStart.lines[0].left.isEmpty, "Nothing precedes a leading match")
        #expect(!atStart.lines[0].right.isEmpty)

        let atEnd = build("The parties reviewed the treaty", ["treati"], radius: 30)
        #expect(atEnd.lines.count == 1)
        #expect(atEnd.lines[0].right.isEmpty, "Nothing follows a trailing match")
        #expect(!atEnd.lines[0].left.isEmpty)
    }

    @Test("Adjacent occurrences do not swallow one another")
    func adjacentMatches() {
        // Windows overlap heavily here; each match must still be its own line with its own offset.
        let scan = build("treaty treaty treaty", ["treati"], radius: 50)
        #expect(scan.lines.count == 3)
        #expect(Set(scan.lines.map(\.offset)).count == 3)
        // The middle line sees its neighbours as context.
        #expect(scan.lines[1].left == "treaty")
        #expect(scan.lines[1].right == "treaty")
    }

    @Test("Several query terms all produce lines, in document order")
    func multipleStems() {
        let scan = build("The alliance preceded the treaty by a decade.", ["alli", "treati"])
        #expect(scan.lines.map(\.match) == ["alliance", "treaty"])
    }

    @Test("A word whose stem does not match is not a line")
    func nonMatchingWordsAreSkipped() {
        let scan = build("The treatment was described.", ["treati"])
        #expect(scan.lines.isEmpty,
                "\"treatment\" stems to `treatment`, not `treati` — matching it would put a word the search never found into the concordance")
    }

    @Test("Truncation is bounded and REPORTED, never silent")
    func truncationIsReported() {
        let body = Array(repeating: "treaty", count: KWICBuilder.maxLinesPerDocument + 25)
            .joined(separator: " and ")
        let scan = build(body, ["treati"], radius: 10)
        #expect(scan.lines.count == KWICBuilder.maxLinesPerDocument)
        #expect(scan.omittedCount == 25,
                "The bound has to be visible: a concordance that quietly drops 25 occurrences misrepresents the document it is summarising")
    }

    @Test("An empty body or an empty stem set yields nothing, not a crash")
    func degenerateInputs() {
        #expect(build("", ["treati"]).lines.isEmpty)
        #expect(build("The treaty was signed.", []).lines.isEmpty)
        #expect(build("", []).omittedCount == 0)
    }
}

// MARK: - KWICSortTests

/// The four orderings, and the property that makes a concordance readable: a total order.
@Suite("KWIC sort")
struct KWICSortTests {

    private func line(_ left: String, _ match: String, _ right: String,
                      volume: String = "frus1969-76v01", document: String = "d1",
                      date: String? = "1971-03-01", offset: Int = 0) -> KWICLine {
        KWICLine(volumeId: volume, documentId: document, header: "h", dateISO: date,
                 left: left, match: match, right: right, offset: offset)
    }

    @Test("Left-context sort groups lines by the word immediately before the match")
    func leftContextGroupsByPrecedingWord() throws {
        // The fixture is built so the two orderings DISAGREE, which the first version of this test
        // failed to do — an un-reversed sort key survived it, because with only one unrelated line
        // both orderings happened to produce the same arrangement.
        //
        // Un-reversed, these sort alpha < beta < zebra, which puts the unrelated "beta" line BETWEEN
        // the two that share "responsibility for". Reversed, both matching lines begin
        // "rof ytilibisnopser" and must land adjacent.
        let lines = [
            line("zebra responsibility for", "military", "security"),
            line("beta unrelated words here", "military", "aircraft"),
            line("alpha responsibility for", "military", "planning"),
        ]
        let sorted = KWICSort.leftContext.apply(to: lines)
        let matchingPositions = sorted.enumerated()
            .filter { $0.element.left.hasSuffix("responsibility for") }
            .map(\.offset)
        #expect(matchingPositions.count == 2)
        #expect(abs(matchingPositions[0] - matchingPositions[1]) == 1,
                "The two \"responsibility for\" lines must be ADJACENT — they landed at \(matchingPositions). Sorting on the un-reversed left context orders by the window's arbitrary start and separates them.")
    }

    @Test("Right-context sort orders by what follows, as it reads")
    func rightContextSorts() {
        let lines = [line("x", "treaty", "zulu"), line("y", "treaty", "alpha"), line("z", "treaty", "mike")]
        #expect(KWICSort.rightContext.apply(to: lines).map(\.right) == ["alpha", "mike", "zulu"])
    }

    @Test("Undated lines sort LAST, not first")
    func undatedSortsLast() {
        let lines = [
            line("a", "treaty", "a", date: nil, offset: 1),
            line("b", "treaty", "b", date: "1949-01-01", offset: 2),
            line("c", "treaty", "c", date: "1971-01-01", offset: 3),
        ]
        let sorted = KWICSort.date.apply(to: lines)
        #expect(sorted.map(\.dateISO) == ["1949-01-01", "1971-01-01", nil],
                "A nil date sorted as the empty string would come FIRST and read as the earliest document")
    }

    @Test("Volume sort follows the corpus's own order, down to position in the document")
    func volumeSortIsCorpusOrder() {
        let lines = [
            line("a", "treaty", "a", volume: "frus1969-76v02", document: "d1", offset: 5),
            line("b", "treaty", "b", volume: "frus1969-76v01", document: "d2", offset: 0),
            line("c", "treaty", "c", volume: "frus1969-76v01", document: "d1", offset: 90),
            line("d", "treaty", "d", volume: "frus1969-76v01", document: "d1", offset: 10),
        ]
        let sorted = KWICSort.volume.apply(to: lines)
        #expect(sorted.map(\.left) == ["d", "c", "b", "a"],
                "v01/d1@10, v01/d1@90, v01/d2, then v02 — volume, then document, then position")
    }

    @Test("Every sort is TOTAL, so the order cannot change between renders")
    func everySortIsTotal() {
        // Three lines identical in every sort dimension except identity. Without the id fallback the
        // comparator would call them equal, and `sorted(by:)` gives no stability guarantee — the
        // concordance could reshuffle under the reader on a redraw.
        let lines = [
            line("same", "treaty", "same", document: "d3", offset: 7),
            line("same", "treaty", "same", document: "d1", offset: 7),
            line("same", "treaty", "same", document: "d2", offset: 7),
        ]
        for sort in KWICSort.allCases {
            let first = sort.apply(to: lines)
            let second = sort.apply(to: lines.reversed())
            #expect(first.map(\.id) == second.map(\.id),
                    "\(sort) is not total: the same set in a different input order produced a different output order")
        }
    }

    @Test("Every sort has a label, and no two share one")
    func labelsAreDistinct() {
        var seen: Set<String> = []
        for sort in KWICSort.allCases {
            #expect(!sort.pickerLabel.isEmpty)
            #expect(seen.insert(sort.pickerLabel).inserted, "\(sort) repeats another sort's label")
        }
    }
}
