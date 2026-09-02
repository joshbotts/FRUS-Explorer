// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - EnclosureDualHomeTests

/// An enclosure's own archival home (B-5, the June 2026 pre-1910 research's Finding 4).
///
/// **The claim under test is that one printed FRUS page has two archival homes.** The covering
/// despatch or instruction is filmed in one series; the enclosure printed beneath it was filmed in
/// its own originating series, where the covering document is not, and in the covering document's
/// series the enclosure is only referenced. A reader handed one roll for the whole page is being
/// told something false about half of it.
///
/// The fixture is the research's own type case, `frus1895p2/d464`, transcribed from the corpus:
/// Acting Secretary Adee writes to Minister Taylor from the Department of State, enclosing a
/// despatch the Consulate-General at Havana wrote three weeks earlier. Every test here runs the
/// REAL parser over that markup rather than a hand-built AST, so a change to `<frus:attachment>`
/// handling fails here.
///
/// Version history:
///   1.0 — B-5 (W-8 residue): initial implementation
@Suite("Enclosures have their own archival home")
struct EnclosureDualHomeTests {

    /// `frus1895p2/d464`, abridged to its openers — the two datelines are verbatim.
    private let d464 = """
    <div type="document" xml:id="d464" n="464">
      <head><hi rend="italic">Mr. <persName type="from">Adee</persName> to Mr.
        <persName type="to">Taylor</persName>.</hi></head>
      <opener><dateline><placeName><hi rend="smallcaps">Department of State</hi>,<lb/><hi
        rend="italic">Washington</hi></placeName>, <date when="1895-07-05">July 5, 1895</date>.</dateline>
        <seg>No. 363.]</seg></opener>
      <p>Sir: I transmit for your information a copy of a dispatch from the vice-consul-general.</p>
      <frus:attachment n="1">
        <opener><seg>[Inclosure 1 in No. 363.]</seg></opener>
        <head><hi rend="italic">Mr. <persName type="from">Springer</persName> to Mr.
          <persName type="to">Uhl</persName>.</hi></head>
        <opener><dateline><placeName><hi rend="smallcaps">Consulate-General, of the United
          States</hi>,<lb/><hi rend="italic">Havana</hi></placeName>, <date when="1895-06-19">June
          19, 1895</date>.</dateline><seg>No. 2517.]</seg></opener>
        <p>Sir: I have the honor to accompany herewith copy of a letter.</p>
      </frus:attachment>
    </div>
    """

    /// Parses a document body through the real parser and returns its AST nodes.
    private func nodes(body: String) async throws -> [FRUSASTNode] {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:frus="http://history.state.gov/frus/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>Test</title></titleStmt></fileDesc></teiHeader>
          <text><body>\(body)</body></text>
        </TEI>
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-enclosure-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let docs = try await FRUSDocumentParser().parse(volumeURL: url)
        return try #require(docs.first?.nodes, "the fixture must parse to one document")
    }

    // MARK: - Extraction

    /// **The enclosure's own opener, not the parent's.** `IndexingPipeline.extractDateline` stops
    /// at the first dateline inside an `<opener>` and never descends into an attachment, so before
    /// this extractor the enclosure's dateline was unreachable anywhere in the app.
    @Test("An enclosure's own head and dateline are recovered")
    func enclosureOpenerIsRecovered() async throws {
        let openers = IndexingPipeline.extractEnclosureOpeners(from: try await nodes(body: d464))
        #expect(openers.count == 1)
        let enclosure = try #require(openers.first)
        #expect(enclosure.label == "1")
        #expect(enclosure.dateline.contains("Havana"), "got: \(enclosure.dateline)")
        #expect(enclosure.dateline.contains("June"), "got: \(enclosure.dateline)")
        #expect(enclosure.header.contains("Springer"), "got: \(enclosure.header)")
        // …and emphatically NOT the parent's, which is the whole point.
        #expect(!enclosure.dateline.contains("Department of State"))
        #expect(!enclosure.header.contains("Adee"))
    }

    /// The parent's own dateline is still the parent's, and is not mistaken for an enclosure.
    @Test("The document's own dateline is untouched")
    func parentDatelineIsUnchanged() async throws {
        let parsed = try await nodes(body: d464)
        let parent = try #require(IndexingPipeline.extractDateline(from: parsed))
        #expect(parent.contains("Department of State"), "got: \(parent)")
        #expect(!parent.contains("Havana"), "the parent picked up its enclosure's dateline")
    }

    /// An enclosure with no dateline of its own cannot be placed, so it is not offered — emitting
    /// it would invite a caller to classify it against the parent's dateline, which is the exact
    /// conflation this feature exists to end.
    @Test("An enclosure without a dateline is not returned")
    func undatedEnclosureIsSkipped() async throws {
        let body = """
        <div type="document" xml:id="d1">
          <opener><dateline>Legation of the United States, Paris, May 1, 1890.</dateline></opener>
          <frus:attachment n="1"><head>A memorandum</head><p>No dateline here.</p></frus:attachment>
        </div>
        """
        #expect(IndexingPipeline.extractEnclosureOpeners(from: try await nodes(body: body)).isEmpty)
    }

    /// An enclosure can enclose one. Both are reachable, and the outer one does not borrow the
    /// inner one's head.
    @Test("A nested enclosure is found, and heads are not borrowed")
    func nestedEnclosuresAreFound() async throws {
        let body = """
        <div type="document" xml:id="d1">
          <opener><dateline>Department of State, Washington, May 1, 1890.</dateline></opener>
          <frus:attachment n="1">
            <head>Mr. Outer to Mr. Reader</head>
            <opener><dateline>Consulate of the United States, Havana, April 2, 1890.</dateline></opener>
            <frus:attachment n="2">
              <head>Mr. Inner to Mr. Outer</head>
              <opener><dateline>Legation of the United States, Madrid, March 3, 1890.</dateline></opener>
            </frus:attachment>
          </frus:attachment>
        </div>
        """
        let openers = IndexingPipeline.extractEnclosureOpeners(from: try await nodes(body: body))
        #expect(openers.count == 2)
        #expect(openers[0].dateline.contains("Havana"))
        #expect(openers[0].header.contains("Outer"))
        #expect(!openers[0].header.contains("Inner"), "the outer enclosure borrowed the inner head")
        #expect(openers[1].dateline.contains("Madrid"))
        #expect(openers[1].header.contains("Inner"))
    }

    // MARK: - The dual home itself

    /// **Finding 4, end to end.** The two openers of one printed page classify to two different
    /// NARA series — which is the entire claim, and the reason a single answer was wrong.
    @Test("The document and its enclosure resolve to different series")
    func theTwoHomesAreDifferent() async throws {
        let parsed = try await nodes(body: d464)
        let parentDateline = try #require(IndexingPipeline.extractDateline(from: parsed))
        let enclosure = try #require(
            IndexingPipeline.extractEnclosureOpeners(from: parsed).first)

        // Adee (Department of State) to Taylor, Minister to Spain → an Instruction.
        let parentHomes = CentralFilesClassifier.classify(
            header: "Mr. Adee to Mr. Taylor", dateline: parentDateline, chapterCountry: "Spain.")
        // Springer (Consulate-General, Havana) to Uhl → a Consular Despatch.
        let enclosureHomes = CentralFilesClassifier.classify(
            header: enclosure.header, dateline: enclosure.dateline, chapterCountry: "Spain.")

        #expect(!parentHomes.isEmpty, "the covering instruction must place somewhere")
        #expect(!enclosureHomes.isEmpty, "the enclosure must place somewhere")
        let parentCategories = Set(parentHomes.map(\.category))
        let enclosureCategories = Set(enclosureHomes.map(\.category))
        #expect(parentCategories.isDisjoint(with: enclosureCategories),
                "the two homes coincided — parent \(parentCategories), enclosure \(enclosureCategories)")
        #expect(enclosureCategories.contains(.consularDespatches),
                "the enclosure should be a consular despatch, got \(enclosureCategories)")
    }

    // MARK: - The narrowing

    /// **An enclosure is offered a home only when its OWN dateline can place it.**
    ///
    /// Measured over the corpus: of 23,296 dateline-bearing enclosures, only 5,876 name an
    /// institution. The other 17,420 print a bare city, and passing the parent's chapter would
    /// route them through the `.medium` "datelined abroad" fallback to the PARENT's country — a
    /// parent-derived guess wearing an enclosure's label, which is the conflation this feature
    /// exists to end, re-entering through the geography instead of the head.
    ///
    /// The lever is `chapterCountry: nil`, and this pins both halves of it.
    @Test("Only a self-placing enclosure gets a home")
    func onlySelfPlacingEnclosuresResolve() {
        // Names its own institution: the consular branch reads the post out of the dateline.
        let placing = CentralFilesClassifier.classify(
            header: "Mr. Springer to Mr. Uhl",
            dateline: "Consulate-General, of the United States, Havana, June 19, 1895.",
            chapterCountry: nil)
        #expect(placing.contains { !$0.geoKeys.isEmpty },
                "a dateline naming its own consulate must place without a chapter")

        // A bare city places only by borrowing a chapter — so with none, it must not.
        let bare = CentralFilesClassifier.classify(
            header: "Mr. Smith to Mr. Jones",
            dateline: "Paris, December 11, 1863.",
            chapterCountry: nil)
        #expect(bare.allSatisfy { $0.geoKeys.isEmpty },
                "a bare city produced a usable geography from nowhere: \(bare.map(\.geoKeys))")

        // …and the same bare dateline DOES place when a chapter is supplied, which is what the
        // document's own row still does and what the enclosure row deliberately declines.
        let withChapter = CentralFilesClassifier.classify(
            header: "Mr. Smith to Mr. Jones",
            dateline: "Paris, December 11, 1863.",
            chapterCountry: "France.")
        #expect(withChapter.contains { !$0.geoKeys.isEmpty },
                "the control failed — the fixture proves nothing about the narrowing")
    }

    // MARK: - Row identity

    /// A document and its enclosure can resolve to the SAME series — one post writing twice — and
    /// a row id built from the category alone makes `ForEach` show one and silently drop the
    /// other. This drives the real `id`, not a restatement of it.
    @Test("Two parts sharing a series are still two rows")
    func rowIdentitySurvivesASharedSeries() {
        let classification = CentralFilesClassification(
            category: .consularDespatches, geoKeys: ["havana"], confidence: .high,
            rationale: "test")
        let document = SourceExplorerView.CountrySeriesResolution(
            classification: classification, rolls: [], part: .document)
        let enclosure = SourceExplorerView.CountrySeriesResolution(
            classification: classification, rolls: [], part: .enclosure(label: "1"))
        let second = SourceExplorerView.CountrySeriesResolution(
            classification: classification, rolls: [], part: .enclosure(label: "2"))
        #expect(Set([document.id, enclosure.id, second.id]).count == 3,
                "row ids collided: \(document.id), \(enclosure.id), \(second.id)")
        #expect(document.id.contains(classification.category.rawValue),
                "the series must still be part of the identity")
    }

    // MARK: - The part

    /// Two parts of one document can resolve to the SAME series — one post writing twice — and a
    /// row identity built from the category alone silently drops one of them in a `ForEach`.
    @Test("A part's key distinguishes rows that share a series")
    func partKeysAreDistinct() {
        let document = CentralFilesDocumentPart.document
        let first = CentralFilesDocumentPart.enclosure(label: "1")
        let second = CentralFilesDocumentPart.enclosure(label: "2")
        let unlabelled = CentralFilesDocumentPart.enclosure(label: nil)
        let keys = Set([document.key, first.key, second.key, unlabelled.key])
        #expect(keys.count == 4, "keys collided: \(keys)")
        #expect(!document.isEnclosure)
        #expect(first.isEnclosure && unlabelled.isEnclosure)
    }

    /// The label is used when the TEI carries one and the row still reads when it does not.
    @Test("A part names itself, numbered or not")
    func partDisplayNames() {
        #expect(CentralFilesDocumentPart.enclosure(label: "2").displayName.contains("2"))
        let bare = CentralFilesDocumentPart.enclosure(label: nil).displayName
        #expect(!bare.isEmpty)
        #expect(!bare.contains("nil"))
        #expect(CentralFilesDocumentPart.enclosure(label: "").displayName == bare,
                "an empty label must read the same as none")
        #expect(!CentralFilesDocumentPart.document.displayName.isEmpty)
        // The Finding-4 sentence exists and says what it is for.
        #expect(CentralFilesDocumentPart.enclosureNote.lowercased().contains("enclosure"))
    }
}
