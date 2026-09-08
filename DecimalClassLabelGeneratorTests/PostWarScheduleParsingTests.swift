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
import Testing

@testable import DecimalClassLabelGeneratorCore

// MARK: - RecordsBlockTests

/// Reading a class table out of the 1950–59 and 1960–63 handbooks (#1210).
///
/// The 1910–49 manual states its classes in a `SUMMARY` block of round hundreds, and the parser
/// that reads it shipped with #828. Neither later handbook has one: each heads its divisions
/// `Class N` inside a `CLASSES OF RECORDS` block, and their scans letter-space the text — so the
/// two rules that worked on the first manual find a partial and, worse, a *truncated* table here.
/// These pin the shapes that forced a second pass, each of which was found by reading real output
/// rather than reasoned about in advance.
@Suite("Post-1950 handbooks — the CLASSES OF RECORDS block")
struct RecordsBlockTests {

    /// Runs the block pass alone, the way `parseClasses` runs it — into an existing table.
    private func block(_ text: String, seeded: [String: String] = [:]) -> [String: String] {
        var result = seeded
        DecimalClassLabelRunner.collectFromRecordsBlock(text, into: &result)
        return result
    }

    @Test("The word Class is letter-spaced on some rows and is still a heading")
    func letterSpacedHeading() {
        // Measured on the 1960–63 handbook: exactly classes 4 and 5 are spaced through, so a
        // pattern tolerating one interior space finds eight of ten — and the two it misses are
        // International Trade and Commerce and International Informational and Educational
        // Relations, which is to say the two a commercial-diplomacy reader most needs.
        let parsed = block("""
            CLASSES OF RECORDS
            Class 3 International Conferences.
            C l a s s 4 International Trade and Commerce.
            Class 5 Internal Security.
            """)
        #expect(parsed["4"] == "International Trade and Commerce", """
            A spaced heading is the same heading. Got: \(parsed["4"] ?? "nil")
            """)
        #expect(parsed["3"] == "International Conferences")
    }

    @Test("A gloss that wraps past its line is taken whole, not cut on the word it broke at")
    func wrappedGlossIsTakenWhole() {
        // The defect this pass exists for. A line-bounded capture ends class 3 on "and", and a
        // gloss ending on a conjunction is not a thin label — it is a wrong one, and nothing on
        // screen would say so.
        let parsed = block("""
            CLASSES OF RECORDS
            Class 3 International Conferences, Congresses, Meetings and
            Organizations. United Nations. Multilateral Treaties.
            Class 4 International Trade and Commerce.
            """)
        // `trimGloss` drops the trailing stop, as it does for every gloss in the shipped
        // 1910–49 schedule — the sentence-interior stops are what had to survive.
        #expect(parsed["3"] == """
            International Conferences, Congresses, Meetings and Organizations. United Nations. \
            Multilateral Treaties
            """, "the gloss must run to the next heading, not to end-of-line: \(parsed["3"] ?? "nil")")
    }

    @Test("The block ends at the manual's own note, so the last class does not swallow the manual")
    func blockEndsAtTheNote() {
        let parsed = block("""
            CLASSES OF RECORDS
            Class 9 Other Internal Affairs.
            Note: The above classes are further subdivided as shown in the schedules which follow,
            and the whole of this handbook describes their use at length.
            """)
        #expect(parsed["9"] == "Other Internal Affairs", """
            Without the Note: bound the last class takes everything after it. Got: \
            \(parsed["9"] ?? "nil")
            """)
    }

    @Test("A run-together label column declines to be read rather than being read wrongly")
    func flattenedLabelColumnYieldsNothing() {
        // This is how the 1950–59 handbook's own text layer arrives: the scan flattens two columns
        // into a label run with the glosses somewhere else entirely. The pass must produce NO
        // reading here — an empty or one-word gloss between two adjacent headings is not evidence
        // of anything — which is what leaves the geometry pass something to do.
        let parsed = block("""
            CLASSES OF RECORDS
            Class 1 Class 2 Class 3 Class 4 Class 5
            """)
        #expect(parsed.isEmpty, "a label with no gloss beside it must be refused: \(parsed)")
    }

    @Test("A class the summary already named is never displaced")
    func firstReadingWins() {
        // Ordering is the whole reason this pass sits where it does. The 1910–49 manual has no
        // such block, so the case cannot arise there; a later manual that grew one must still not
        // overwrite a reading taken from a list of classes by construction.
        let parsed = block("""
            CLASSES OF RECORDS
            Class 8 Something The Scan Mangled.
            """, seeded: ["8": "Internal Affairs of States"])
        #expect(parsed["8"] == "Internal Affairs of States")
    }

    @Test("Without the heading the pass is inert")
    func inertWithoutTheHeading() {
        // The 1910–49 manual. `Class 8` appears in its running prose — "...substantially as
        // Class 8..." — and an unbounded pass would take the rest of that sentence as the gloss.
        let parsed = block("""
            SUMMARY
            800 Internal Affairs of States
            The numbering is arranged substantially as Class 8 was under the earlier scheme, so
            that Wireless Telegraphy has the number 8**.74 throughout.
            """)
        #expect(parsed.isEmpty, "no CLASSES OF RECORDS heading, no reading: \(parsed)")
    }

    @Test("Through parseClasses, the block beats the line-bounded fallback")
    func blockWinsOverTheLineFallback() {
        // The bug that shipped for one run: the fallback ran first, claimed class 3 as a gloss
        // ending on "and", and this pass then skipped it as already known. Driving the real entry
        // point is the only way to pin the ORDER — either pass alone reads this text correctly.
        let parsed = DecimalClassLabelRunner.parseClasses("""
            CLASSES OF RECORDS
            Class 3 International Conferences, Congresses, Meetings and
            Organizations. United Nations.
            Class 4 International Trade and Commerce.
            """)
        #expect(parsed["3"]?.hasSuffix("United Nations") == true, """
            Reversing the two passes leaves a gloss ending on "and" and no test but this one \
            notices. Got: \(parsed["3"] ?? "nil")
            """)
    }
}

// MARK: - LetterSpacedPunctuationTests

/// The spacing a letter-spaced scan leaves around punctuation.
@Suite("Letter-spaced punctuation")
struct LetterSpacedPunctuationTests {

    @Test("A space before a mark is closed up")
    func marksAreTightened() {
        #expect(DecimalClassLabelRunner.tightenPunctuation("Commerce . Trade Relations")
                    == "Commerce. Trade Relations")
        #expect(DecimalClassLabelRunner.tightenPunctuation("Economic , Industrial ; Social : Other")
                    == "Economic, Industrial; Social: Other")
    }

    @Test("It never joins words, so it cannot invent a reading")
    func wordsAreLeftAlone() {
        // The narrow scope is the safety argument. `despace` beside it rejoins letters split
        // inside a word and can therefore change what a phrase says; this cannot.
        let input = "International Trade and Commerce"
        #expect(DecimalClassLabelRunner.tightenPunctuation(input) == input)
    }
}

// MARK: - PageGeometryTests

/// Reading the block off the PAGE when the text layer cannot pair a label with its gloss.
///
/// These drive real PDFs built for the test rather than the shipped scans, which stay local by the
/// owner's decision and are not in the repository. What they can pin is the contract: pairs come
/// from POSITION, the label is not part of its own gloss, and the pass refuses rather than guesses
/// when the page does not look like the block.
@Suite("Post-1950 handbooks — page geometry")
struct PageGeometryTests {

    /// Draws `items` at PDF coordinates (origin bottom-left) and returns the file's path.
    private func makePDF(_ items: [(text: String, x: CGFloat, y: CGFloat)]) throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("decimal-geometry-\(UUID().uuidString).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try #require(CGDataConsumer(url: url as CFURL))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        context.beginPDFPage(nil)
        for item in items {
            let attributed = NSAttributedString(
                string: item.text,
                attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
            context.textPosition = CGPoint(x: item.x, y: item.y)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
        context.endPDFPage()
        context.closePDF()
        return url.path
    }

    @Test("A label in the left strip takes the gloss standing beside it")
    func pairsComeFromPosition() throws {
        let path = try makePDF([
            ("CLASSES OF RECORDS", 50, 700),
            ("Class 3", 20, 650), ("International Conferences", 250, 650),
            ("Class 4", 20, 600), ("International Trade and Commerce", 250, 600),
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try #require(DecimalClassLabelRunner.classesByGeometry(of: path))
        #expect(parsed["3"] == "International Conferences")
        #expect(parsed["4"] == "International Trade and Commerce")
    }

    @Test("The label is cut from its own gloss at the match, not at a fixed offset")
    func labelIsNotPartOfItsGloss() throws {
        // Cutting a fixed number of characters looks equivalent until the column boundary splits a
        // word, which is exactly what the strip width does on the real page.
        let path = try makePDF([
            ("CLASSES OF RECORDS", 50, 700),
            ("Class 6", 20, 650), ("International Political Relations", 250, 650),
            ("Class 7", 20, 600), ("Internal Political Affairs", 250, 600),
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        let parsed = try #require(DecimalClassLabelRunner.classesByGeometry(of: path))
        #expect(parsed["6"]?.contains("Class") == false, "got: \(parsed["6"] ?? "nil")")
        #expect(parsed["6"] == "International Political Relations")
    }

    @Test("A page with one label is not a class block, and yields nothing")
    func oneLabelIsRefused() throws {
        // Two is the floor because a single `Class N` occurs in running prose throughout both
        // handbooks; a page carrying one is far likelier to be a sentence than a table.
        let path = try makePDF([
            ("CLASSES OF RECORDS", 50, 700),
            ("Class 4", 20, 650), ("International Trade", 250, 650),
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(DecimalClassLabelRunner.classesByGeometry(of: path) == nil)
    }

    @Test("A page without the block heading is never read")
    func headingIsRequired() throws {
        let path = try makePDF([
            ("Class 4", 20, 650), ("International Trade", 250, 650),
            ("Class 5", 20, 600), ("Internal Security", 250, 600),
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(DecimalClassLabelRunner.classesByGeometry(of: path) == nil, """
            The heading is what bounds the search to a list of classes by construction. Without \
            it the pass would read any page whose left margin happens to carry the word.
            """)
    }

    @Test("A path that is not a document is refused rather than trapped")
    func missingDocumentIsRefused() {
        #expect(DecimalClassLabelRunner.classesByGeometry(of: "/nonexistent/manual.pdf") == nil)
    }
}
