// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Testing

@testable import DecimalClassLabelGeneratorCore

// MARK: - CountryTableGeometryTests

/// Reading the country-number table by its own columns (#1256).
///
/// The fixtures are real PDFs drawn at the source document's own column positions, because the
/// defect being fixed is geometric: a code's meaning depends on which column it sits in, and a
/// text fixture cannot express that at all — which is exactly why the parse this replaces had to
/// guess.
@Suite("Country table — columns read, not inferred")
struct CountryTableGeometryTests {

    /// Draws cells at the source's own column origins and returns the file's path.
    private func makePDF(_ rows: [[(column: Int, text: String)]]) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("country-\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try #require(CGDataConsumer(url: url as CFURL))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        context.beginPDFPage(nil)
        var y = 700.0
        for row in rows {
            for cell in row {
                let attributed = NSAttributedString(
                    string: cell.text,
                    attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
                context.textPosition = CGPoint(
                    x: CountryTableGeometry.columnOrigins[cell.column], y: y)
                CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
            }
            y -= 20
        }
        context.endPDFPage()
        context.closePDF()
        return url.path
    }

    private func isCode(_ token: String) -> Bool {
        token.range(of: #"^\d{1,3}[a-z]?$"#, options: .regularExpression) != nil
    }

    private func rows(_ path: String) throws -> [CountryTableGeometry.Row] {
        let document = try #require(PDFDocument(url: URL(fileURLWithPath: path)))
        return CountryTableGeometry.rows(in: document, isCode: isCode)
    }

    @Test("A code's column is read off the page")
    func codesLandInTheirOwnColumn() throws {
        let path = try makePDF([
            [(0, "Poland"), (1, "60"), (2, "48"), (3, "48")],
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try rows(path)
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "Poland")
        #expect(parsed[0].codes == ["60", "48", "48"])
    }

    @Test("An empty cell stays empty, which is the fabrication the old rule committed")
    func emptyCellsAreNotFilled() throws {
        // `Alaska` carries 11h in the 1950–59 column ONLY, with a note saying it lapsed. The rule
        // this replaces read the note and right-aligned partial rows, which is how 15 entries the
        // document leaves blank reached the shipped 1960–63 table.
        let path = try makePDF([
            [(0, "Alaska"), (2, "11h"), (4, "Discontinued 1959. See 11.")],
            [(0, "Wake Island"), (3, "11h"), (4, "Beginning 1960.")],
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try rows(path)
        #expect(parsed.count == 2)
        #expect(parsed[0].codes == [nil, "11h", nil], """
            Alaska's 1910–49 and 1960–63 cells are blank on the page and must stay blank. Got \
            \(parsed[0].codes).
            """)
        #expect(parsed[1].codes == [nil, nil, "11h"])
    }

    @Test("A note stating both Beginning and Discontinued no longer decides anything")
    func aNoteIsEvidenceAboutACountryNotAboutAColumn() throws {
        // The Ethiopian pattern. Under the old ordering `Beginning` was tested first and always
        // won, so this row right-aligned into a column the document leaves empty.
        let path = try makePDF([
            [(0, "Amhara"), (1, "65d"), (2, "77"),
             (4, "Beginning 1936. Discontinued 1960. See 75.")],
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try rows(path)
        #expect(parsed[0].codes == ["65d", "77", nil], """
            The note says both things; the PAGE says which columns are filled. Got \
            \(parsed[0].codes).
            """)
    }

    @Test("A code-less group continues the name above it")
    func wrappedNamesRejoin() throws {
        // `Trust Territory of` / `Somaliland` is one entry printed on two lines. Treated as a new
        // row it would ship a country named for half a phrase.
        let path = try makePDF([
            [(0, "Trust Territory of"), (3, "77"), (4, "Discontinued July 1960.")],
            [(0, "Somaliland")],
            [(0, "Tanganyika"), (3, "78"), (4, "Established December 1961.")],
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try rows(path)
        #expect(parsed.count == 2)
        #expect(parsed[0].name == "Trust Territory of Somaliland")
        #expect(parsed[1].name == "Tanganyika")
    }

    @Test("A wrapped note rejoins without opening a row")
    func wrappedNotesRejoin() throws {
        let path = try makePDF([
            [(0, "Ruanda-Urundi"), (1, "62s"), (2, "78"), (3, "78"),
             (4, "Discontinued 1962.")],
            [(4, "See 70y and 70z.")],
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try rows(path)
        #expect(parsed.count == 1)
        #expect(parsed[0].note == "Discontinued 1962. See 70y and 70z.")
    }

    @Test("Column bands cover their own origin and stop before the next")
    func columnBands() {
        #expect(CountryTableGeometry.column(forX: 72.0) == 0)
        #expect(CountryTableGeometry.column(forX: 180.9) == 1)
        #expect(CountryTableGeometry.column(forX: 248.5) == 2)
        #expect(CountryTableGeometry.column(forX: 315.9) == 3)
        #expect(CountryTableGeometry.column(forX: 383.5) == 4)
        // A wrapped line indented a few points inside its own column still belongs to it.
        #expect(CountryTableGeometry.column(forX: 88.0) == 0)
        // Nothing sits left of the table.
        #expect(CountryTableGeometry.column(forX: 20.0) == nil)
    }

    @Test("Rows are grouped by their own leading, not by proximity")
    func rowGrouping() {
        let lines = [
            CountryTableGeometry.Line(text: "Poland", column: 0, x: 72, y: 700),
            CountryTableGeometry.Line(text: "48", column: 2, x: 248.5, y: 699.7),
            CountryTableGeometry.Line(text: "Portugal", column: 0, x: 72, y: 687),
        ]
        let grouped = CountryTableGeometry.group(lines)
        #expect(grouped.count == 2, """
            The two cells of one row differ by under a point and the next row is 13 away. A \
            tolerance wide enough to merge them would fuse every row with its neighbour.
            """)
        #expect(grouped[0].count == 2)
    }
}
