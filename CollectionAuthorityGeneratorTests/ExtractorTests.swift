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
        // FRUSASTNode.plainText joins every AST child with " ", so the pipeline
        // stores "MSP /3–1952" for `<gloss>MSP</gloss>/3–1952` — the extractor must
        // produce the identical text (pinned corpus-wide by RealTEINoteParityTests).
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

// MARK: - Child-join boundary (#832a)

/// The front-matter extractor must contribute an element-boundary space, like its sibling.
///
/// A source entry whose text is interrupted by a child element ran the two halves together,
/// because `FrontMatterSourcesExtractor` accumulated `foundCharacters` into the open item and
/// nothing marked the seam. `DocumentNoteExtractor.appendBoundarySpace()` — over the same corpus,
/// for the document-side notes — has always called it on element start *and* end.
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
