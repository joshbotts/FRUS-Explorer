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
