// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import CorpusStructureSweepGeneratorCore

/// The structural sweep behind #1309.
///
/// **Every exclusion has a fixture of its own**, because the exclusions are what keep this report
/// credible: the naive "no div may have a same-type ancestor" rule hits 937 times corpus-wide at
/// 97.7% noise, and it is the rule an outsider would propose.
///
/// Version history:
///   1.0 — 2026-09-20: #1309
@Suite("Corpus structure sweep (#1309)")
struct StructureSweepTests {

    /// Wraps body content in a minimal TEI volume.
    private func volume(_ body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <text><body>
        \(body)
          </body></text>
        </TEI>
        """.utf8)
    }

    // MARK: - The scanner

    @Test("The scanner reads a div's type, subtype, id and n without confusing their names")
    func attributesAreReadByName() {
        // `type=` is a substring of `subtype=`, and `n=` of `frus:doc-dateTime-min=`. A scanner
        // that matched either way disagreed with a real parse on 554 of 744 files.
        let nodes = DivScanner.scan(volume("""
        <div frus:doc-dateTime-min="1945-02-07T00:00:00-05:00" subtype="index" type="section"
             xml:id="persons" n="3"><head>Persons</head></div>
        """))
        #expect(nodes.count == 1)
        let node = try? #require(nodes.first)
        #expect(node?.type == "section")
        #expect(node?.subtype == "index")
        #expect(node?.id == "persons")
        #expect(node?.n == "3")
    }

    @Test("A div inside a comment is neither opened nor counted")
    func commentedDivsAreInvisible() {
        let nodes = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch1"><head>One</head>
          <!-- <div type="chapter" xml:id="ch2"><head>Commented</head></div> -->
        </div>
        """))
        #expect(nodes.count == 1)
        #expect(nodes.first?.id == "ch1")
    }

    @Test("A foreign-namespace div is not a TEI div")
    func foreignNamespaceDivsAreSkipped() {
        // The four PubDip volumes embed an XHTML video player. Counting its divs desynchronises
        // the tree for the rest of the file, moving every byte offset the report prints.
        let nodes = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch1"><head>One</head>
          <div xmlns="http://www.w3.org/1999/xhtml" class="video-player">player</div>
        </div>
        """))
        #expect(nodes.count == 1)
        #expect(nodes.first?.id == "ch1")
    }

    @Test("A head's editorial note is not part of the heading")
    func headNotesAreStripped() {
        // Without this the anchored day grammar matches nothing, and one whole volume's day
        // headings went unseen in the measurement that designed this sweep.
        let nodes = DivScanner.scan(volume("""
        <div type="subchapter" xml:id="ch1subch1">
          <head>Thursday, February 8, 1945<note n="1">For the delegation list, see p. 12.</note></head>
        </div>
        """))
        #expect(nodes.first?.headText == "Thursday, February 8, 1945")
        #expect(StructureRules.isDayHeading(nodes.first?.headText ?? ""))
    }

    // MARK: - The rules, and the exclusions that keep them precise

    @Test("A chapter inside a chapter is flagged")
    func chapterInChapterIsFlagged() {
        let nodes = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch8"><head>8. Minutes</head>
          <div type="chapter" xml:id="ch9"><head>9. Other documents</head></div>
        </div>
        """))
        let flagged = StructureRules.rankViolations(in: nodes)
        #expect(flagged.count == 1)
        #expect(nodes[flagged[0]].id == "ch9")
    }

    @Test("A subchapter inside a subchapter is NOT flagged — the corpus's own idiom")
    func subchapterNestingIsExcluded() {
        // 915 pairs corpus-wide. Flagging them is the difference between a report OH can act on
        // and 937 rows at 97.7% noise.
        let nodes = DivScanner.scan(volume("""
        <div type="subchapter" xml:id="ch1subch1"><head>One</head>
          <div type="subchapter" xml:id="ch1subch2"><head>Two</head></div>
        </div>
        """))
        #expect(StructureRules.rankViolations(in: nodes).isEmpty)
    }

    @Test("A compilation inside a section is NOT flagged — a deliberate part-title page")
    func compilationInSectionIsExcluded() {
        let nodes = DivScanner.scan(volume("""
        <div type="section" xml:id="part1"><head>Part I</head>
          <div type="compilation" xml:id="comp1"><head>Great Britain</head></div>
        </div>
        """))
        #expect(StructureRules.rankViolations(in: nodes).isEmpty)
    }

    @Test("A subchapter legitimately inside a chapter is not flagged")
    func ordinaryNestingIsQuiet() {
        let nodes = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch1"><head>One</head>
          <div type="subchapter" xml:id="ch1subch1"><head>First</head></div>
        </div>
        """))
        #expect(StructureRules.rankViolations(in: nodes).isEmpty)
        #expect(StructureRules.idLevelViolations(in: nodes).isEmpty)
    }

    @Test("A day inside a day is flagged, and a day inside its chapter is not")
    func dayNesting() {
        let nested = DivScanner.scan(volume("""
        <div type="subchapter" xml:id="a"><head>Wednesday, February 7, 1945</head>
          <div type="subchapter" xml:id="b"><head>Thursday, February 8, 1945</head></div>
        </div>
        """))
        #expect(StructureRules.dayInDay(in: nested).count == 1)

        let ordinary = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch1"><head>8. Minutes</head>
          <div type="subchapter" xml:id="a"><head>Wednesday, February 7, 1945</head></div>
          <div type="subchapter" xml:id="b"><head>Thursday, February 8, 1945</head></div>
        </div>
        """))
        #expect(StructureRules.dayInDay(in: ordinary).isEmpty)
    }

    @Test("A timed session inside another is flagged; a timed DOCUMENT is not")
    func sessionNesting() {
        let nested = DivScanner.scan(volume("""
        <div type="subchapter" xml:id="a"><head>Meeting of the Foreign Ministers, noon</head>
          <div type="subchapter" xml:id="b"><head>Fourth plenary meeting, 4 p.m.</head></div>
        </div>
        """))
        #expect(StructureRules.sessionInSession(in: nested).count == 1)

        // Scoped to structural divs: a printed paper carrying a time in its head is not a
        // container, and flagging those was measured at 60% false.
        let document = DivScanner.scan(volume("""
        <div type="subchapter" xml:id="a"><head>Meeting of the Foreign Ministers, noon</head>
          <div type="document" xml:id="d1"><head>Memorandum, 4 p.m.</head></div>
        </div>
        """))
        #expect(StructureRules.sessionInSession(in: document).isEmpty)
    }

    @Test("The id grammar flags a level, never a number")
    func idLevelIgnoresTheNumber() {
        // Strengthening this to compare chapter numbers would mint 27 false rows across four
        // volumes, each a stale id-minting counter with a constant per-file offset.
        let wrongLevel = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch12"><head>Twelve</head>
          <div type="subchapter" xml:id="ch12subsubch23"><head>Deep</head></div>
        </div>
        """))
        #expect(StructureRules.idLevelViolations(in: wrongLevel).count == 1)

        let staleCounter = DivScanner.scan(volume("""
        <div type="chapter" xml:id="ch96"><head>Ninety-six</head>
          <div type="subchapter" xml:id="ch96subch1"><head>First</head>
            <div type="subchapter" xml:id="ch93subsubch1"><head>Deeper</head></div>
          </div>
        </div>
        """))
        #expect(StructureRules.idLevelViolations(in: staleCounter).isEmpty,
                "the parent is a subchapter, which is the only thing this rule may test")
    }

    @Test("A chapter in a historical document is flagged; one in an appendix is not")
    func chapterInHistoricalDocument() {
        let flagged = DivScanner.scan(volume("""
        <div type="section" subtype="historical-document" xml:id="msg"><head>Message</head>
          <div type="chapter" xml:id="ch1"><head>One</head></div>
        </div>
        """))
        #expect(StructureRules.chapterInHistoricalDocument(in: flagged).count == 1)

        // Widening to any section takes precision from 100% to 36%: one volume's appendix
        // deliberately holds seven chapters.
        let appendix = DivScanner.scan(volume("""
        <div type="section" subtype="appendix" xml:id="app"><head>Appendix</head>
          <div type="chapter" xml:id="ch1"><head>One</head></div>
        </div>
        """))
        #expect(StructureRules.chapterInHistoricalDocument(in: appendix).isEmpty)
    }

    @Test("A document in an editorial note is flagged; nested historical documents are not")
    func documentInEditorialNote() {
        let flagged = DivScanner.scan(volume("""
        <div type="document" subtype="editorial-note" xml:id="d1"><head>Note</head>
          <div type="document" xml:id="d2"><head>Paper</head></div>
        </div>
        """))
        #expect(StructureRules.documentInEditorialNote(in: flagged).count == 1)

        let exhibits = DivScanner.scan(volume("""
        <div type="document" subtype="historical-document" xml:id="d1"><head>Paper</head>
          <div type="document" xml:id="d2"><head>EXHIBIT I</head></div>
        </div>
        """))
        #expect(StructureRules.documentInEditorialNote(in: exhibits).isEmpty)
    }

    @Test("A container typed chapter that its own id calls a compilation is a RETYPE, not a move")
    func mistypedContainer() {
        // The nesting here is correct and the live site renders it correctly. Reporting its ten
        // children as misplaced would send an editor to a location where nothing is wrong.
        let nodes = DivScanner.scan(volume("""
        <div type="chapter" xml:id="comp1"><head>Correspondence.</head>
          <div type="chapter" xml:id="ch1"><head>Great Britain.</head></div>
          <div type="chapter" xml:id="ch2"><head>British legation.</head></div>
        </div>
        """))
        #expect(StructureRules.mistypedContainers(in: nodes).count == 1)
        #expect(StructureRules.rankViolations(in: nodes).isEmpty,
                "the children must not ALSO be reported as misplaced")
    }

    // MARK: - The adjudicator

    @Test("The printed contents contradicts the file when it prints two heads at one level")
    func contentsContradicts() {
        let entries = ContentsAdjudicator.entries(in: """
        <div type="section" subtype="table-of-contents" xml:id="toc"><head>Contents</head>
          <list type="toc">
            <item>III. The Yalta Conference
              <list>
                <item><ref target="#pg_1">8. Minutes and related documents</ref></item>
                <item><ref target="#pg_2">9. Other conference documents</ref></item>
              </list>
            </item>
          </list>
        </div>
        """)
        #expect(entries.count >= 3)
        #expect(ContentsAdjudicator.contradicts(
            parentHead: "8. Minutes and related documents",
            childHead: "9. Other conference documents", entries: entries))
        #expect(!ContentsAdjudicator.contradicts(
            parentHead: "III. The Yalta Conference",
            childHead: "8. Minutes and related documents", entries: entries),
            "the book really does nest these, so this pair must not contradict")
    }

    @Test("A heading normalises past small caps, accents and its printed page number")
    func normalisation() {
        #expect(ContentsAdjudicator.normalize("9. Other Conference Documents 401")
                == ContentsAdjudicator.normalize("9. Other conference documents"))
        #expect(ContentsAdjudicator.normalize("Ágústsson") == ContentsAdjudicator.normalize("agustsson"))
    }

    // MARK: - The repair simulator

    @Test("A simulated move that fixes the tree is confirmed; a bad donor offset is refused")
    func repairSimulation() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
        <div type="chapter" xml:id="ch8"><head>Eight</head><div type="chapter" xml:id="ch9"><head>Nine</head></div></div>
        </body></text></TEI>
        """
        let nodes = DivScanner.scan(Data(xml.utf8))
        let parent = nodes[0]
        let child = nodes[1]
        let outcome = RepairSimulator.simulateMove(
            xml: xml, donorCloseByte: parent.closeByte, insertByte: child.openByte,
            recheck: StructureRules.rankViolations)
        #expect(outcome.isConfirmed, "\(outcome)")
        #expect(outcome.violationsBefore == 1)
        #expect(outcome.violationsAfter == 0)

        // A correction naming a tag that is not there must never ship: the measurement pass that
        // designed this sweep proposed three such moves.
        let wrong = RepairSimulator.simulateMove(
            xml: xml, donorCloseByte: parent.openByte, insertByte: child.openByte,
            recheck: StructureRules.rankViolations)
        #expect(!wrong.isConfirmed)
        #expect(wrong.refusal?.contains("no </div>") == true, "\(String(describing: wrong.refusal))")
    }

    @Test("The byte scan and a real parse agree, or the run refuses")
    func parityGuard() {
        let data = volume("""
        <div type="chapter" xml:id="ch1"><head>One</head>
          <div type="subchapter" xml:id="ch1subch1"><head>First</head></div>
        </div>
        """)
        #expect(ElementTreeParity.check(data: data, against: DivScanner.scan(data)) == nil)
        // A scan that missed a div must be reported, not tolerated.
        let truncated = Array(DivScanner.scan(data).dropLast())
        #expect(ElementTreeParity.check(data: data, against: truncated) != nil)
    }
}
