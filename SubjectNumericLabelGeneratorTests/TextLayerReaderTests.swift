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

/// A run as the capture writes one: a string at a place, in nine-point Times unless said.
private func run(_ text: String, _ minX: Double, _ maxX: Double, baseline: Double = 500,
                 size: Double = 9.6) -> TextRun {
    // Half a space of Times-Roman: a quarter of the type size, halved.
    TextRun(text: text, minX: minX, maxX: maxX, baseline: baseline, top: baseline + 0.75 * size,
            size: size, halfSpace: 0.125 * size)
}

// MARK: - TextLayerLineTests

/// The lines ``TextLayerReader`` makes of a page's runs (#1644).
///
/// Every coordinate here is the scan's own, read from the handbooks' content streams: these are
/// the rows on which macOS 26 and macOS 27 disagreed.
@Suite("Text layer — where a word ends and where a line does")
struct TextLayerLineTests {

    @Test("Two runs a hair apart are one word, and the abbreviation they spell stays whole")
    func aGapUnderHalfASpaceJoins() {
        // The 1963 appendix's `USIS`, which the capture wrote as `US` and `IS` 0.80 points apart.
        // macOS 27 put a space there, `US` became the code of that entry, and every `…-US` tail
        // read "… and IS U.S. Information Service".
        let lines = TextLayerReader.lines(from: [run("US", 324.35, 333.93), run("IS", 334.73, 343.51)])
        #expect(lines.map(\.text) == ["USIS"])
    }

    @Test("Two runs more than half a space apart are two words, as the capture left them")
    func aGapOverHalfASpaceDivides() {
        // `REAL PROPER TY`: the capture split PROPERTY, 4.36 points between the halves. That is a
        // word's gap by any rule over gaps, so the label keeps the capture's break, as it did
        // under macOS 26.
        let lines = TextLayerReader.lines(from: [
            run("REAL", 135.48, 164.47, size: 9), run("PROPER", 171.66, 214.06, size: 9),
            run("TY", 218.43, 232.0, size: 9),
        ])
        #expect(lines.map(\.text) == ["REAL PROPER TY"])
    }

    @Test("The text layer's own space is a word break, whatever the gap")
    func aWrittenSpaceIsABreak() {
        // The 1965 layer ends each word's string with a space. These two overlap by a point.
        let lines = TextLayerReader.lines(from: [run("30 ", 89.41, 100.70), run("IMMIGRANTS, ", 99.8, 164.4)])
        #expect(lines.map(\.text) == ["30 IMMIGRANTS,"])
        #expect(TextLayerReader.startsWord(run("b", 10, 20), after: run("a ", 0, 30)))
    }

    @Test("A line is cut where a column's width of space opens in it")
    func aColumnGapCutsTheLine() {
        // INT 6 of the 1963 outline: the capture wrote the label and the instruction beside it as
        // one line, 20.85 points apart at 9.3. PDFKit kept them together, and the label shipped
        // as "COLLECTION OF INTELLIGENCE Methods, programs of collection, types".
        let lines = TextLayerReader.lines(from: [
            run("COLLECTION", 133, 190, size: 9.3), run("OF", 194.5, 205, size: 9.3),
            run("INTELLIGENCE", 209.5, 317.4, size: 9.3), run("Methods,", 338.25, 380, size: 9.3),
        ])
        #expect(lines.map(\.text) == ["COLLECTION OF INTELLIGENCE", "Methods,"])
        #expect(lines.map(\.x) == [133, 338.25])
    }

    @Test("Two typed spaces after a full stop are under the cut, and the line stays whole")
    func aSentenceGapDoesNotCut() {
        // From the 1963 handbook's own instructions: `c.` and `Use`, 14.09 points apart at 8.8,
        // which is 1.6 times the type size.
        let lines = TextLayerReader.lines(from: [run("c.", 109.5, 117.41, size: 8.8),
                                                 run("Use", 131.5, 146.2, size: 8.8)])
        #expect(lines.map(\.text) == ["c. Use"])
    }

    @Test("Runs that do not follow one another in the stream are two lines, however close")
    func theStreamKeepsTwoColumnsApart() {
        // Page 114 of the 1965 handbook: a line of the left column ends 13.4 points short of a
        // designator of the right one, on the same baseline. The capture read them as two lines
        // and wrote the left column's next line between them; position alone would join them.
        let left = run("Organization", 232.8, 283.4, baseline: 400, size: 7)
        let next = run("of", 73.1, 80, baseline: 392, size: 7)
        let right = run("9", 296.8, 302, baseline: 400, size: 10.4)
        let lines = TextLayerReader.lines(from: [left, next, right])
        // Top to bottom: the designator's larger type stands a little higher than the line's.
        #expect(lines.map(\.text) == ["9", "Organization", "of"])
        // The control: written one after the other, the same two runs ARE one line.
        #expect(TextLayerReader.lines(from: [left, right]).map(\.text) == ["Organization 9"])
    }

    @Test("Designators written one after another, a row each, are a line each")
    func aChangeOfBaselineBeginsALine() {
        // The 1963 outlines hold a page's designators together, before any label.
        let lines = TextLayerReader.lines(from: [
            run("1", 101.7, 106.4, baseline: 695), run("2", 102.9, 107.6, baseline: 633),
            run("GENERAL", 133.3, 180, baseline: 695),
        ])
        #expect(lines.map(\.text) == ["1", "GENERAL", "2"], "top to bottom, then left to right")
    }

    @Test("A run to the left of the one before it begins a new line")
    func aRunToTheLeftBeginsALine() {
        let lines = TextLayerReader.lines(from: [run("Belgium", 300, 340), run("Use", 100, 115)])
        #expect(lines.map(\.text) == ["Use", "Belgium"])
    }

    @Test("A designator and the label beside it are one line though their type differs")
    func aBaselineAFractionOffIsTheSameLine() {
        // V 31-5 of the 1965 outline: an eleven-point designator half a point below its
        // nine-point label. The baselines differ, and a quarter of the smaller size takes it in.
        let lines = TextLayerReader.lines(from: [
            run("31-5 ", 369.72, 386.9, baseline: 606.72, size: 10.9),
            run("Treaty ", 397.12, 423.4, baseline: 607.21, size: 8.9),
        ])
        #expect(lines.map(\.text) == ["31-5 Treaty"])
        #expect(lines[0].x == 369.72)
    }

    @Test("A stray mark set thirty points tall does not take the row beside it")
    func aLargeStrayMarkIsMeasuredByTheSmallerType() {
        // Measured by its own size the mark's tolerance would be seven points; by the row's, two.
        let lines = TextLayerReader.lines(from: [
            run("I", 20, 30, baseline: 505, size: 29), run("LIB", 176, 190, baseline: 500, size: 9.6),
        ])
        #expect(lines.count == 2)
    }

    @Test("A line stands at its first run's left edge and its tallest run's top")
    func aLineIsPlacedByItsRuns() {
        let lines = TextLayerReader.lines(from: [run("31 ", 369.75, 379.7, baseline: 672.24, size: 9.5),
                                                 run("NONIMMIGRANTS ", 389.8, 468.6, baseline: 672.0, size: 8.9)])
        #expect(lines.count == 1)
        #expect(lines[0].x == 369.75)
        #expect(abs(lines[0].y - (672.24 + 0.75 * 9.5)) < 1e-9)
        #expect(lines[0].height == 9.5)
    }
}

// MARK: - TextLayerFontTests

/// What ``TextLayerReader`` knows of the fonts the handbooks' text layers name (#1644).
@Suite("Text layer — the standard fonts' widths, and the hidden font's map")
struct TextLayerFontTests {

    @Test("A standard font's widths are its own, for the codes the handbooks use")
    func widthsAreTheFontsOwn() throws {
        let times = try #require(StandardFontMetrics.font(named: "Times-Roman"))
        let helvetica = try #require(StandardFontMetrics.font(named: "Helvetica-Bold"))
        #expect(times.space == 250)
        #expect(times.width(of: UInt8(ascii: "A")) == 722)
        #expect(times.width(of: 0x95) == 350, "the bullet a leader is made of")
        #expect(helvetica.space == 278)
        #expect(helvetica.width(of: UInt8(ascii: "W")) == 944)
        #expect(times.ascent == 0.75)
        #expect(helvetica.ascent == 0.77)
        // The oblique faces share the upright faces' widths.
        #expect(StandardFontMetrics.font(named: "Helvetica-Oblique")?.ascii
                    == StandardFontMetrics.font(named: "Helvetica")?.ascii)
    }

    @Test("A code the handbooks never use has no width, so the reader refuses it")
    func anUnusedCodeHasNoWidth() throws {
        let times = try #require(StandardFontMetrics.font(named: "Times-Roman"))
        #expect(times.width(of: 0x81) == nil)
        #expect(StandardFontMetrics.scalar(of: 0x81) == nil)
        #expect(StandardFontMetrics.font(named: "Courier") == nil)
    }

    @Test("The encoding's second hyphen reads as a hyphen")
    func theSecondHyphen() throws {
        #expect(StandardFontMetrics.scalar(of: 0xAD) == "-")
        #expect(StandardFontMetrics.font(named: "Times-Bold")?.width(of: 0xAD) == 333)
    }

    @Test("A ToUnicode map gives each code its characters, by pair and by range")
    func theHiddenFontsMap() throws {
        let cmap = """
            2 beginbfchar
            <0003> <0020>
            <002D> <007E>
            endbfchar
            1 beginbfrange
            <0024> <0026> <0041>
            endbfrange
            """
        let map = try #require(ToUnicodeMap.parse(Data(cmap.utf8)))
        #expect(map[0x0003] == " ")
        #expect(map[0x002D] == "~", "the capture's mark for a character it could not read")
        #expect(map[0x0024] == "A")
        #expect(map[0x0026] == "C")
        #expect(map[0x0027] == nil)
    }

    @Test("A map that lists a range's values one by one is refused, not half read")
    func theArrayFormIsRefused() {
        let cmap = "1 beginbfrange\n<0001> <0002> [<0041> <0042>]\nendbfrange"
        #expect(ToUnicodeMap.parse(Data(cmap.utf8)) == nil)
    }
}

// MARK: - HandbookPageTests

/// What a page says is at its head (#1644).
@Suite("Handbook page — the strip a corner mark is read from")
struct HandbookPageTests {

    @Test("A line is in the top strip when the middle of its height is")
    func theMiddleDecides() {
        // A page 792 points tall; the strip is its top 60, so its floor is at 732.
        let page = HandbookPage(width: 612, height: 792, lines: [
            PageLine(text: "POL (p. 7)", x: 430, y: 755, height: 9),
            // Top at 736, so part of it is inside; its middle, at 731.5, is not.
            PageLine(text: "POL - POLITICAL AFFAIRS & RELATIONS", x: 84, y: 736, height: 9),
        ])
        #expect(page.lines(inTop: 60).map(\.text) == ["POL (p. 7)"])
        #expect(page.text(inTop: 120) == "POL (p. 7)\nPOL - POLITICAL AFFAIRS & RELATIONS")
    }
}
