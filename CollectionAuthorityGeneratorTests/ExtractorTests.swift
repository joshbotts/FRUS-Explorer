// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CollectionAuthorityGeneratorCore

/// TEI extraction parity: the front-matter Phase-3 keys and the document source-note
/// locator chain.
@Suite struct ExtractorTests {

    // MARK: Front matter

    @Test func frontMatterKeysMatchThePhase3Grammar() {
        let xml = """
        <TEI><text><body>
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p>The editors made use of the following collections.</p>
          <list>
            <item><hi rend="strong">Record Group 59, General Records of the Department of State</hi>
              <list>
                <item>Lot Files
                  <list>
                    <item>Lot 64 D 199, Records of the Policy Planning Staff</item>
                    <item>Lot 71–D 440, Records of the Executive Secretariat</item>
                  </list>
                </item>
                <item>Central Files 1967–69: POL 27 ARAB–ISR</item>
              </list>
            </item>
            <item><hi rend="strong">Johnson Library, Austin, Texas</hi>
              <list><item>National Security File</item></list>
            </item>
          </list>
        </div>
        </body></text></TEI>
        """
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        let items = rows.filter { $0.kind == .item }
        #expect(rows.first?.kind == .prose)

        let lot1 = items.first { $0.lotFileNorm == "64D199" }
        #expect(lot1 != nil)
        #expect(lot1?.recordGroup == "59")           // inherited from the RG heading
        #expect(lot1?.repository == "Department of State")

        // En-dash lot normalizes identically to the doc side.
        #expect(items.contains { $0.lotFileNorm == "71D440" })

        // Class leaf keyed in the shared canonical form (en-dash → hyphen).
        let classLeaf = items.first { $0.decimalClass != nil }
        #expect(classLeaf?.decimalClass == "POL 27 ARAB-ISR")

        // Library child inherits the library repository keyword.
        let nsf = items.first { $0.text == "National Security File" }
        #expect(nsf?.repository == "Johnson Library")
    }

    @Test func bibliographyRowsCarryNoKeys() {
        let xml = """
        <TEI><text><body>
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p><hi rend="strong">Published Sources</hi></p>
          <list>
            <item>Acheson, Dean. Present at the Creation. Lot 64 D 199 mentioned in passing.</item>
          </list>
        </div>
        </body></text></TEI>
        """
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        let bib = rows.filter { $0.kind == .bibliography }
        #expect(!bib.isEmpty)
        #expect(bib.allSatisfy { $0.lotFileNorm == nil && $0.decimalClass == nil })
    }

    // MARK: Document notes — locator chain

    @Test func headNestedSourceNoteWithSourcePrefixWins() {
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Telegram<note n="1" type="source">
            <p>Source: Johnson Library, National Security File, Country File, Vietnam.</p>
          </note></head>
          <p>Body text.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 1)
        #expect(notes[0].documentId == "d1")
        #expect(notes[0].note.hasPrefix("Source: Johnson Library"))
    }

    @Test func segSourceSegmentBeatsTheWholeNote() {
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d2">
          <head>2. Memo<note n="1">
            <p><seg type="summary">Summary of the memo.</seg>
            <seg type="source">Source: Ford Library, National Security Adviser Files.</seg></p>
          </note></head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 1)
        #expect(notes[0].note == "Source: Ford Library, National Security Adviser Files.")
    }

    @Test func topLevelInlineNoteIsExtractedAndBracketWrapperNormalized() {
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d3">
          <note rend="inline" type="source">[Source: 711.00/11–552. Telegram.]</note>
          <head>3. Note</head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 1)
        #expect(notes[0].note == "Source: 711.00/11–552. Telegram.")
    }

    @Test func nonPrefixedHeadNoteIsDeferredBehindTopLevelNote() {
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d4">
          <head>4. Memo<note n="1" type="source"><p>Dictated on Nov. 13.</p></note></head>
          <note rend="inline" type="source">711.00/11–552. Telegram.</note>
          <p>Body.</p>
        </div>
        <div type="document" xml:id="d5">
          <head>5. Memo<note n="1" type="source"><p>Eisenhower Library, Dulles papers.</p></note></head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 2)
        // d4: the top-level note wins over the non-prefixed head remark.
        #expect(notes[0].note == "711.00/11–552. Telegram.")
        // d5: no top-level alternative — the deferred head note serves.
        #expect(notes[1].note == "Eisenhower Library, Dulles papers.")
    }

    @Test func unrecognizedNoteTypesFollowTheAppsUnclassifiedSemantics() {
        // The app's FootnoteType maps an absent OR unrecognized `type` to
        // .unclassified, and its seg-source path accepts .source or .unclassified.
        // The extractor must mirror that (adversarial review 2026-07-04 finding 6):
        // type="summary" (unrecognized) is seg-visible; type="footnote" /
        // "editorial" (recognized non-source) are not.
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d7">
          <head>7. Memo<note n="1" type="summary">
            <p><seg type="source">Source: Kennedy Library, President's Office Files.</seg></p>
          </note></head>
          <p>Body.</p>
        </div>
        <div type="document" xml:id="d8">
          <head>8. Memo<note n="1" type="footnote">
            <p><seg type="source">Not a provenance note in the app's chain.</seg></p>
          </note></head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 1)
        #expect(notes.first?.documentId == "d7")
        #expect(notes.first?.note == "Source: Kennedy Library, President's Office Files.")
        #expect(DocumentNoteExtractor.isUnclassified(nil))
        #expect(DocumentNoteExtractor.isUnclassified("summary"))
        #expect(!DocumentNoteExtractor.isUnclassified("footnote"))
        #expect(!DocumentNoteExtractor.isUnclassified("editorial"))
        #expect(!DocumentNoteExtractor.isUnclassified("source"))
    }

    @Test func onlyDirectHeadChildrenAreHeadNested() {
        // The app scans direct .footnote children of the head AST node; a note
        // wrapped deeper inside the head must be invisible to the extractor too
        // (adversarial review 2026-07-04 finding 6).
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d9">
          <head>9. Memo<hi rend="italic"><note n="1" type="source">
            <p>Source: Wrapped note the app never sees.</p>
          </note></hi></head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        #expect(DocumentNoteExtractor.extract(fromXML: Data(xml.utf8)).isEmpty)
    }

    @Test func elementBoundariesJoinWithASpaceLikeTheAppsPlainText() {
        // FRUSASTNode.plainText joins runs as the page prints them (#1421), and a slash is in
        // neither of its sets, so the pipeline still stores "MSP /3–1952" for
        // `<gloss>MSP</gloss>/3–1952` — the extractor must produce the identical text (pinned
        // corpus-wide by RealTEINoteParityTests).
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d10">
          <note rend="inline" type="source">700.5 <gloss target="#t_MSP1">MSP</gloss>/3–1952</note>
          <head>10. Note</head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        let notes = DocumentNoteExtractor.extract(fromXML: Data(xml.utf8))
        #expect(notes.count == 1)
        #expect(notes[0].note == "700.5 MSP /3–1952")
    }

    @Test func editorialWrappedDocumentsYieldNoNotes() {
        // The app wraps `subtype="editorial-note"` documents (and
        // `type="editorialNote"` divs) in a single .editorialNote AST node, so their
        // notes are never top-level and extractSourceNote stores none — the
        // extractor mirrors that (real case: frus1952-54v01p1 d108).
        let xml = """
        <TEI><text><body>
        <div type="document" subtype="editorial-note" xml:id="d11">
          <note rend="inline" type="source">Eisenhower Library, Randall Commission records</note>
          <head>11. Editorial Note</head>
          <p>Body.</p>
        </div>
        <div type="editorialNote" xml:id="d12">
          <note rend="inline" type="source">Truman Library, PSF</note>
          <head>12. Editorial Note</head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        #expect(DocumentNoteExtractor.extract(fromXML: Data(xml.utf8)).isEmpty)
    }

    @Test func documentsWithoutSourceNotesYieldNothing() {
        let xml = """
        <TEI><text><body>
        <div type="document" xml:id="d6">
          <head>6. Editorial Note<note n="1"><p>For text of the treaty, see p. 4.</p></note></head>
          <p>Body.</p>
        </div>
        </body></text></TEI>
        """
        #expect(DocumentNoteExtractor.extract(fromXML: Data(xml.utf8)).isEmpty)
    }
}

// MARK: - Printed join (#1421)

/// `PrintedTextMirror` replays the app's printed join over SAX events, so each of the parser
/// behaviours it depends on gets a fixture of its own: a mutation that drops one fails the test
/// named for it. The app-side `PrintedJoinMirrorParityTests` compares the two on real shapes, and
/// `PrintedEdgeRuleTests` on every element kind and every character of the two sets, which this
/// package cannot do: it cannot see the app's `PrintedText`.
@Suite struct PrintedTextMirrorTests {

    /// One document's source note, through the note extractor.
    private func note(_ body: String) -> String? {
        let xml = "<TEI><text><body><div type=\"document\" xml:id=\"d1\">\(body)</div></body></text></TEI>"
        return DocumentNoteExtractor.extract(fromXML: Data(xml.utf8)).first?.note
    }

    /// One document's body footnotes, through the footnote extractor.
    private func footnotes(_ body: String) -> [String] {
        let xml = "<TEI><text><body><div type=\"document\" xml:id=\"d1\">\(body)</div></body></text></TEI>"
        return DocumentFootnoteExtractor.extract(fromXML: Data(xml.utf8)).first?.footnotes ?? []
    }

    @Test("No space is invented inside brackets and quotes or before a stop")
    func printedRule() {
        #expect(note(#"<note type="source">Countries Series, <gloss>USSR</gloss>, a (<persName>Kennan</persName>) “<hi>NSC</hi>” file.</note>"#)
                == "Countries Series, USSR, a (Kennan) “NSC” file.")
    }

    @Test("Where neither side carries a space or a stop, one is inserted")
    func insertedSpace() {
        #expect(note(#"<note type="source">States:<persName>John F. Kennedy</persName></note>"#)
                == "States: John F. Kennedy")
    }

    @Test("A persName's own edge whitespace is trimmed, as the parser trims it")
    func persNameTrim() {
        #expect(note("<note type=\"source\">(<persName>\n Kennan\n</persName>)</note>") == "(Kennan)")
        // A gloss is not trimmed by the parser, so its edge space survives.
        #expect(note("<note type=\"source\">(<gloss>\n NSC\n</gloss>)</note>") == "( NSC )")
    }

    @Test("A whitespace-only run between two elements is dropped, as the parser drops it")
    func whitespaceOnlyRunDropped() {
        #expect(note("<note type=\"source\">Filed <hi>(</hi>\n  <hi>Kennan</hi></note>") == "Filed (Kennan")
    }

    // The two block-edge lines are separate code (`start` and `end`), so each has a fixture where
    // its edge is the ONLY one between the two pieces (#1421 review). The earlier fixture,
    // `<p>One.</p><p>. Two.</p>`, put a closing AND an opening edge there, and either line alone
    // still produced its space, so deleting one of them passed.

    @Test("A paragraph's opening edge keeps its space, even after an opening bracket")
    func blockOpeningEdgeKeepsItsSpace() {
        #expect(footnotes("<p>Text.<note n=\"1\">Filed (<p>One.</p></note></p>") == ["Filed ( One."])
    }

    @Test("A paragraph's closing edge keeps its space, even before a stop")
    func blockClosingEdgeKeepsItsSpace() {
        #expect(footnotes("<p>Text.<note n=\"1\"><p>One.</p>. Two.</note></p>") == ["One. . Two."])
    }

    @Test("After a nested footnote closes, the text resumes by the printed rule")
    func footnoteCloseEdge() {
        #expect(footnotes("<p>Text.<note n=\"1\">See (Aisoo<note n=\"2\">Kioto.</note>) and Todo.</note></p>")
                == ["See (Aisoo Kioto.) and Todo."])
    }

    @Test("A line break is a space")
    func lineBreak() {
        #expect(footnotes("<p>Text.<note n=\"1\">One<lb/>Two</note></p>") == ["One Two"])
    }
}

// MARK: - Child-join boundary (#832a)

/// The front-matter extractor must contribute an element-boundary space, like its sibling did.
///
/// A source entry whose text is interrupted by a child element ran the two halves together,
/// because `FrontMatterSourcesExtractor` accumulated `foundCharacters` into the open item and
/// nothing marked the seam. When this was written, `DocumentNoteExtractor` — over the same corpus,
/// for the document-side notes — put a space at every element start *and* end; since #1421 it
/// joins as the page prints (`PrintedTextMirror`), while the front-matter extractor keeps the
/// boundary space this suite pins, because it mirrors the app's `SourcesParserDelegate`, not
/// `plainText` (`FrontMatterSourcesExtractor.appendBoundarySpace()`).
///
/// Measured over the shipped `collection-authority.json` before the fix: **35 concatenated names
/// and 38 aliases across 37 records**, detected as a digit immediately followed by an uppercase
/// letter beginning a word (`70Pakistan`), a shape a legitimate lot designator like `00D471`
/// cannot produce.
struct FrontMatterSourcesBoundaryTests {

    /// The type case, transcribed from `frus1969-76ve07.xml`.
    @Test("A child element inside an item does not fuse the text on either side of it")
    func childJoinDoesNotFuseText() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="sources">
          <list>
            <item><hi rend="strong">Department of State</hi>
              <list>
                <item>NEA/PAF Files: Lot 72 D 70<p>Pakistan political files for 1969</p></item>
              </list>
            </item>
          </list>
        </div>
        </body></text></TEI>
        """
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        let row = rows.first { $0.lotFileNorm == "72D70" }
        let text = try! #require(row?.text)
        #expect(!text.contains("70Pakistan"), "the child join fused two phrases: \(text)")
        #expect(text.contains("70 Pakistan") || text.contains("70  Pakistan"),
                "expected a separator at the child boundary; got: \(text)")
    }

    /// The closing edge matters on its own: text that RESUMES after a child must not fuse either.
    /// A start-only hook would leave `</p>Text` run together, which is why the sibling extractor
    /// calls the helper twice.
    @Test("Text resuming after a child element is separated too")
    func closingEdgeSeparates() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="sources">
          <list>
            <item><hi rend="strong">Department of State</hi>
              <list>
                <item>Lot 72 D 70<hi rend="italic">Pakistan</hi>Political files</item>
              </list>
            </item>
          </list>
        </div>
        </body></text></TEI>
        """
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        let text = try! #require(rows.first { $0.lotFileNorm == "72D70" }?.text)
        #expect(!text.contains("PakistanPolitical"), "the closing edge fused two phrases: \(text)")
    }

    /// The separator must not break the parses that already work — a lot number split across the
    /// element boundary by nothing but whitespace still normalises to one key.
    @Test("Adding the boundary space does not disturb lot normalisation")
    func lotNormalisationUnchanged() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="sources">
          <list>
            <item><hi rend="strong">Department of State</hi>
              <list>
                <item>Lot 64 D 199, Records of the Policy Planning Staff</item>
                <item>Lot 71–D 440, Records of the Executive Secretariat</item>
              </list>
            </item>
          </list>
        </div>
        </body></text></TEI>
        """
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        #expect(rows.contains { $0.lotFileNorm == "64D199" })
        #expect(rows.contains { $0.lotFileNorm == "71D440" })
    }
}

// MARK: - Nested apparatus lists (#1469)

/// A persons or abbreviations list nested INSIDE the Sources division is not a list of sources.
///
/// frus1955-57v13's sources division does not close before its List of Abbreviations and List of
/// Persons, so both sit inside it; the extractor harvested every `<item>` until the section's own
/// end tag and the authority shipped 309 records that were people and abbreviations ("Deptel,
/// Department of State telegram", "Cabell, Lt. Gen. C.P., …"). frus1964-68v06 nests the same two
/// lists after its Published Sources heading. Each fixture below exercises one clause of the
/// rule, so a mutation that drops any one of them fails exactly one test.
///
/// Version history:
///   1.0 — 2026-09-25: #1469
@Suite("Front matter — nested apparatus lists are not sources")
struct NestedApparatusExtractorTests {

    /// Every fixture also closes the sources division and prints a terms division BESIDE it — the
    /// control the issue asks for (a sibling list was never read, and must still not be), carried
    /// in every case rather than in a test of its own that would pass on the unfixed code.
    private func texts(_ nested: String) -> [String] {
        let xml = """
        <TEI><text><front>
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <list><item>Lot 61 D 233, Records of the Office of the Secretary</item></list>
          \(nested)
          <list><item>Kevin McCann Records</item></list>
        </div>
        <div type="section" subtype="index" xml:id="abbreviations-beside">
          <list><item>NIACT, night action</item></list>
        </div>
        </front></text></TEI>
        """
        return FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
            .filter { $0.kind == .item }.map(\.text)
    }

    /// The frus1955-57v13 shape: terms and persons nested, both `subtype="index"`, and — the
    /// frus1964-68v06 half — a nested division that is NOT apparatus, the covert-actions note the
    /// parsers deliberately keep. Only the real rows survive, and the one AFTER the nested lists
    /// proves harvesting resumes.
    @Test("The v13 shape: nested terms and persons lists yield nothing, and harvesting resumes")
    func v13Shape() {
        let rows = texts("""
          <div type="section" subtype="index" xml:id="terms">
            <head>Abbreviations</head>
            <list><item><hi rend="strong">Deptel</hi>, Department of State telegram</item></list>
          </div>
          <div type="section" subtype="index" xml:id="persons">
            <head>Persons</head>
            <list><item><hi rend="strong"><persName xml:id="p_CCP1">Cabell, Lt. Gen. C.P.</persName></hi>, USAF</item></list>
          </div>
          <div type="section" subtype="note-on-covert-actions" xml:id="actionsstatement">
            <list><item>Special Group Files</item></list>
          </div>
        """)
        #expect(rows == ["Lot 61 D 233, Records of the Office of the Secretary",
                         "Special Group Files", "Kevin McCann Records"])
    }

    /// One clause each: `subtype="index"` alone (neutral id), `xml:id="terms"` alone,
    /// `xml:id="persons"` alone, `type="listofabbreviations"` alone.
    @Test("Each clause of the apparatus rule is enough on its own", arguments: [
        #"<div type="section" subtype="index" xml:id="glossary"><list><item>ARAMCO, Arabian–American Oil Company</item></list></div>"#,
        #"<div type="section" xml:id="terms"><list><item>AmEmb, American Embassy</item></list></div>"#,
        #"<div type="section" xml:id="persons"><list><item>Allen, Francis O., Officer in Charge</item></list></div>"#,
        #"<div type="listofabbreviations"><list><item>FYI, for your information</item></list></div>"#,
    ])
    func eachClause(_ nested: String) {
        #expect(texts(nested) == ["Lot 61 D 233, Records of the Office of the Secretary", "Kevin McCann Records"])
    }
}

// MARK: - Childless repository headings (#1466)

/// A repository printed as an `<item>` of its own, with its collections as the items AFTER it.
///
/// frus1952-54v12p1 (and frus1955-57v20, frus1958-60v06 — the issue's scan finds the shape in 53
/// volumes) lays its Sources list out this way. The extractor took a repository only from an item's
/// ancestors, so every collection after such a heading had none, and `Whitman File` shipped twice —
/// once under the Eisenhower Library and once under no repository at all. These fixtures drive the
/// extractor on the real shape; `ReferenceBuilderTests` drives the same XML through to references.
///
/// Version history:
///   1.0 — 2026-09-25: #1466
///   1.1 — 2026-09-25 (review round 1): the lot clause and `takesSiblingHeading`'s repository
///          exclusion get fixtures that fail without them
@Suite("Front matter — a childless repository heading scopes the items after it")
struct SiblingHeadingExtractorTests {

    /// frus1952-54v12p1, lines 9421–9445, cut to one child per collection and with a State lot
    /// placed BEFORE the first heading.
    static let v12p1Shape = """
    <TEI><text><front>
    <div type="section" subtype="sources" xml:id="sources">
      <list>
        <item>Lot 58 D 776, Records of the Bureau of Far Eastern Affairs</item>
        <item><hi rend="italic">Dwight D. Eisenhower Library, Abilene, Kansas</hi></item>
        <item>Dulles Papers <list><item>Chronological Series</item></list></item>
        <item>Whitman File <list><item>NSC Series</item></list></item>
        <item><hi rend="italic">National Archives, Washington, D.C.</hi></item>
        <item>JCS Records <list><item>CCS 092 Asia (6–25–48)</item></list></item>
      </list>
    </div>
    </front></text></TEI>
    """

    private func row(_ text: String, in xml: String) -> FrontSourceRow? {
        FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8)).first { $0.text == text }
    }

    /// The carry runs FORWARD only: the State lot printed before the heading keeps no repository.
    @Test("A collection after a childless heading takes the heading's repository")
    func siblingTakesTheHeading() throws {
        #expect(try #require(row("Whitman File", in: Self.v12p1Shape)).repository == "Eisenhower Library")
        #expect(try #require(row("Dulles Papers", in: Self.v12p1Shape)).repository == "Eisenhower Library")
        let lot = try #require(row("Lot 58 D 776, Records of the Bureau of Far Eastern Affairs",
                                   in: Self.v12p1Shape))
        #expect(lot.repository == nil)
    }

    @Test("A child of such a collection inherits the heading through its parent")
    func childOfASiblingInherits() throws {
        #expect(try #require(row("NSC Series", in: Self.v12p1Shape)).repository == "Eisenhower Library")
    }

    @Test("The next childless heading takes over from the first")
    func nextHeadingTakesOver() throws {
        #expect(try #require(row("JCS Records", in: Self.v12p1Shape)).repository == "National Archives")
        #expect(try #require(row("CCS 092 Asia (6–25–48)", in: Self.v12p1Shape)).repository
                == "National Archives")
    }

    /// A repository heading WITH a nested list scopes its own children, and stops a childless
    /// heading's carry: the collection after it is not the earlier heading's.
    @Test("A heading with its own list stops the carry")
    func headingWithChildrenStopsTheCarry() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Whitman File</item>
          <item><hi rend="italic">Johnson Library, Austin, Texas</hi> <list><item>National Security File</item></list></item>
          <item>Dean Rusk Papers</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
        #expect(try #require(row("National Security File", in: xml)).repository == "Johnson Library")
        #expect(try #require(row("Dean Rusk Papers", in: xml)).repository == nil)
    }

    /// The carry belongs to one list: when the list closes, the item after its parent is not
    /// scoped by a heading printed inside it.
    @Test("The carry ends with its list")
    func carryEndsWithItsList() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item>Other Collections <list>
            <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
            <item>Whitman File</item>
          </list></item>
          <item>Dean Rusk Papers</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
        #expect(try #require(row("Dean Rusk Papers", in: xml)).repository == nil)
    }

    /// An item naming its own repository keeps it, whatever heading precedes it — and, not being a
    /// heading itself (its FIRST segment names no repository), it does not end the carry.
    @Test("An item that names its own repository keeps it")
    func ownRepositoryWins() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Ball Papers, Johnson Library</item>
          <item>Whitman File</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Ball Papers, Johnson Library", in: xml)).repository
                == "Johnson Library")
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
    }

    /// frus1964-68v26's shape. A row printed as a heading (its text opens with `<hi>`) that names no
    /// repository the rule can read ends the carry, and does not take it: the first cut of #1466
    /// carried `Johnson Library, Austin, Texas` through `National Security Council` and
    /// `Washington Federal Records Center` and filed the Djakarta Embassy's lot under the library.
    @Test("A row printed as a heading ends the carry")
    func styledRowEndsTheCarry() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="strong"> Johnson Library, Austin, Texas</hi></item>
          <item>Tom Johnson’s Notes of Meetings</item>
          <item><hi rend="strong">National Security Council</hi>
            <list><item>Special Group/303 Committee Files</item></list></item>
          <item>Special Group Minutes</item>
          <item><hi rend="strong">Washington Federal Records Center, Suitland, Maryland</hi>
            <list><item>Record Group 84, Records of U.S. Embassies and Posts
              <list><item>Djakarta Embassy Files: Lot 69 F 42</item></list></item></list></item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Tom Johnson’s Notes of Meetings", in: xml)).repository
                == "Johnson Library")
        #expect(try #require(row("National Security Council", in: xml)).repository == nil)
        #expect(try #require(row("Special Group/303 Committee Files", in: xml)).repository == nil)
        #expect(try #require(row("Special Group Minutes", in: xml)).repository == nil,
                "an unstyled row after the styled one is past the end of the scope")
        let lot = try #require(row("Djakarta Embassy Files: Lot 69 F 42", in: xml))
        #expect(lot.repository == nil)
        #expect(lot.recordGroup == "84")
    }

    /// Only a row printed as a heading opens a scope. frus1964-68v20's class leaf `POL 15-1
    /// US/NIXON: …` names `Nixon` in its first segment, and the first cut of #1466 filed the class
    /// leaves after it under the Nixon materials; a plain repository-shaped row neither opens a
    /// scope nor ends one.
    @Test("A plain row naming a repository neither opens nor ends a scope")
    func plainRowDoesNotOpenAScope() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>POL 15-1 US/NIXON: Head of State, Executive Branch, Pres.-elect Richard M. Nixon</item>
          <item>Whitman File</item>
          <item>Johnson Library, Austin, Texas</item>
          <item>Ann Whitman Diaries</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
        #expect(try #require(row("Ann Whitman Diaries", in: xml)).repository == "Eisenhower Library",
                "an unstyled Johnson Library row does not take over the scope")
        let plain = """
        <TEI><text><front><div type="sources"><list>
          <item>Eisenhower Library, Abilene, Kansas</item>
          <item>Whitman File</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: plain)).repository == nil,
                "an unstyled repository row opens no scope")
    }

    /// The heading a styled row opens is its styled LEAD, not the whole row. frus1964-68v06 prints
    /// `<hi>Central Files.</hi> See National Archives and Records Administration below.` inside its
    /// Department of State list; read whole, its first segment names the National Archives and the
    /// State lots after it were refiled there.
    @Test("A styled row opens a scope only when its styled lead names the repository")
    func styledLeadDecides() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item>Department of State, Washington, D.C. <list>
            <item><hi rend="strong">Central Files.</hi> See National Archives and Records Administration below.</item>
            <item>INR/EAP Files: Lot 90 D 99</item>
          </list></item>
          <item><hi rend="italic">Eisenhower Library</hi>, Abilene, Kansas</item>
          <item>Whitman File</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("INR/EAP Files: Lot 90 D 99", in: xml)).repository
                == "Department of State")
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library",
                "a lead naming the repository opens the scope even with the place after it")
    }

    /// A lot row is a collection even when it names a record group or a repository — the lot
    /// clause of the heading rule (`isRepositoryHeading`'s first guard) — and each half of that is
    /// pinned here on the row that shows it:
    /// - a PLAIN lot row naming a record group still takes the heading in force (without the clause
    ///   the record group makes it a heading, and a heading takes none — it would keep no
    ///   repository);
    /// - a STYLED, childless lot row opens no scope of its own (without the clause its lead names the
    ///   Department and opens one, filing the row after it under the Department of State).
    @Test("A lot row is never a heading")
    func lotRowIsNotAHeading() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">National Archives, College Park, Maryland</hi></item>
          <item>RG 59, Records of the Policy Planning Staff: Lot 64 D 563</item>
          <item><hi rend="strong">Department of State, Lot 64 D 199</hi></item>
          <item>Records of the Executive Secretariat</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("RG 59, Records of the Policy Planning Staff: Lot 64 D 563", in: xml))
                .repository == "National Archives")
        #expect(try #require(row("Records of the Executive Secretariat", in: xml)).repository == nil,
                "a styled lot row ends the scope and opens none")
    }

    /// A PLAIN row the heading test reads as a repository or record group never takes the sibling
    /// heading (`takesSiblingHeading`'s `!isRepositoryHeading` conjunct), and — being plain — does
    /// not end it either. One row per clause of the test it consults: a record group, and a
    /// full-name library the keyword list cannot read. Without the conjunct both rows would be filed
    /// under the Eisenhower Library.
    @Test("A plain repository or record-group row takes no heading")
    func plainRepositoryRowTakesNoHeading() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Record Group 218, Records of the Joint Chiefs of Staff</item>
          <item>Yale University Library, New Haven, Connecticut</item>
          <item>Whitman File</item>
        </list></div></front></text></TEI>
        """
        let rg = try #require(row("Record Group 218, Records of the Joint Chiefs of Staff", in: xml))
        #expect(rg.repository == nil)
        #expect(rg.recordGroup == "218")
        #expect(try #require(row("Yale University Library, New Haven, Connecticut", in: xml))
                .repository == nil)
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library",
                "a plain row does not end the scope")
    }

    /// A childless record-group heading carries its record group, the same channel a nested one
    /// uses (the record-group clause of the heading rule).
    @Test("A childless record-group heading carries its record group")
    func recordGroupHeadingCarries() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Record Group 84, Records of the Foreign Service Posts</hi></item>
          <item>Tokyo Embassy Files</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Tokyo Embassy Files", in: xml)).recordGroup == "84")
    }

    /// A full-name library heading the keyword list cannot read still ENDS the previous heading's
    /// carry: Princeton's Dulles Papers are not the Eisenhower Library's. What ends it here is the
    /// rule that every styled row ends a scope — the heading test's library clause is not needed
    /// for that, and is pinned by `plainRepositoryRowTakesNoHeading` and by
    /// `ReferenceBuilderTests.fullNameHeadingIsBridged`, where it decides the outcome. The row
    /// stores no repository keyword; `ReferenceBuilder` bridges the name.
    @Test("A full-name library heading ends the previous heading's carry")
    func fullNameLibraryHeadingStopsTheCarry() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Whitman File</item>
          <item><hi rend="italic">Princeton University Library, Princeton, New Jersey</hi></item>
          <item>John Foster Dulles Papers</item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
        #expect(try #require(row("John Foster Dulles Papers", in: xml)).repository == nil)
    }

    /// A heading never takes a sibling heading — neither for itself nor for the collections nested
    /// under it. Princeton's heading, printed with its own list after the Eisenhower Library's,
    /// names no keyword; without this rule the Eisenhower heading reached both it and its Dulles
    /// Papers through the ancestor walk.
    @Test("A heading takes no sibling heading, for itself or for its children")
    func headingIsNotScopedByAnEarlierHeading() throws {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Whitman File</item>
          <item><hi rend="italic">Princeton University Library, Princeton, New Jersey</hi> <list><item>Dulles Papers</item></list></item>
        </list></div></front></text></TEI>
        """
        #expect(try #require(row("Whitman File", in: xml)).repository == "Eisenhower Library")
        #expect(try #require(row("Princeton University Library, Princeton, New Jersey", in: xml))
                .repository == nil)
        #expect(try #require(row("Dulles Papers", in: xml)).repository == nil)
    }
}
