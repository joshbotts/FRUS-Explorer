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

// MARK: - FlushLeftSourcesParseTests

/// The app's side of #668: a front-matter Sources list encoded as paragraphs.
///
/// ## The bug
/// The early-1950s volumes alternate a `<p rend="flushleft">` collection heading with an
/// ordinary description paragraph and use no `<list>`/`<item>` at all:
///
/// ```xml
/// <p rend="flushleft"><gloss target="#t_CFM1">CFM</gloss> Files, Lot M 88</p>
/// <p>Consolidated master collection of the records of conferences of heads of state…</p>
/// ```
///
/// Every one became `.prose`, so 14 volumes produced **zero** collection rows. Measured over
/// all 552 manifest volumes, the promotion adds **526 collection rows and removes none**.
///
/// ## Why this suite exists alongside the generator's
/// `SourcesParserDelegate` (here) and `VolumeSourcesExtractor` (the generator that builds
/// `volume-sources-index.json`) are **two separate implementations of one grammar**. The app
/// parses at index time; the generator builds the bundle the corpus browser reads. A volume
/// that resolves in one and not the other is exactly the split #668 reported, so the same
/// four fixtures are pinned on both sides. `VolumeSourcesIndexGeneratorTests`'
/// `FlushLeftSourcesTests` is the twin — change one, change both.
///
/// Version history:
///   1.0 — Session 2026-08-07: #668
@Suite("Paragraph-encoded front-matter sources (#668)")
struct FlushLeftSourcesParseTests {

    /// Parses a front-matter body through the **real** `parseVolumeFull` entry point, so the
    /// section detection, the delegate, and the promotion are all exercised together.
    private func rows(_ front: String) async throws -> [VolumeSourceEntry] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus668-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("frus1951v05.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>fixture</title></titleStmt>
          <publicationStmt><date when="1979">1979</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><front>
        \(front)
          </front><body></body></text>
        </TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
    }

    /// frus1951v05, reduced. The `<gloss>` in the first heading and the `xml:id` spelled
    /// `source` rather than `sources` are both verbatim from the volume.
    private let frus1951v05Shape = """
    <div type="section" subtype="sources" xml:id="source">
      <head>List of sources</head>
      <p>The principal source of documentation for this volume was the indexed central
         (decimal) files of the Department of State.</p>
      <p rend="flushleft"><gloss target="#t_CFM1">CFM</gloss> Files, Lot M 88</p>
      <p>Consolidated master collection of the records of conferences of heads of state.</p>
      <p rend="flushleft">PPS Files, Lot 64 D 563</p>
      <p>Files of the Policy Planning Staff.</p>
      <p rend="flushleft">S/S–NSC Files, Lot 63 D 351</p>
      <p>Serial and subject master file of National Security Council documents.</p>
    </div>
    """

    @Test("Flushleft headings become collection rows when the section has no items")
    func flushLeftHeadingsArePromoted() async throws {
        let items = try await rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.map(\.rawText) == ["CFM Files, Lot M 88",
                                         "PPS Files, Lot 64 D 563",
                                         "S/S–NSC Files, Lot 63 D 351"],
                Comment(rawValue: "got \(items.map(\.rawText))"))
    }

    /// The promoted rows must carry keys, or the promotion buys nothing — a collection row
    /// with no lot number resolves to nothing in Source Explorer, and `lotFileNorm` is what
    /// the archival-neighbour matcher joins on.
    @Test("Promoted rows carry their lot keys in canonical form")
    func promotedRowsCarryKeys() async throws {
        let items = try await rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.contains { $0.lotFileNorm == "64D563" },
                Comment(rawValue: "norms: \(items.map { $0.lotFileNorm ?? "-" })"))
    }

    /// The `<gloss>` wrapping `CFM` must not truncate the name.
    @Test("A <gloss> inside the heading keeps the collection name whole")
    func glossDoesNotTruncateTheName() async throws {
        let items = try await rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.first?.rawText.hasPrefix("CFM Files") == true,
                Comment(rawValue: "got \(items.first?.rawText ?? "no rows")"))
    }

    // MARK: - What must not be promoted

    /// The guard that leaves the 240 already-working volumes untouched **by construction**
    /// rather than by measurement: a section that emits any item row promotes nothing.
    @Test("A section with an item outline promotes no paragraph")
    func sectionWithItemsPromotesNothing() async throws {
        let all = try await rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p rend="flushleft">A flushleft paragraph that is not a collection.</p>
          <list><item>RG 59, Central Files, Lot 70 D 150</item></list>
        </div>
        """)
        let items = all.filter { $0.kind == .item }
        #expect(items.count == 1, Comment(rawValue: "got \(items.map(\.rawText))"))
        #expect(items[0].rawText.contains("RG 59"))
        #expect(all.contains { $0.kind == .prose && $0.rawText.contains("not a collection") })
    }

    /// frus1950v07: 39 of its flushleft paragraphs are **books** under a `Published Sources`
    /// pseudo-heading. Promoting them would file a memoir as an archival collection. That
    /// volume spells the heading `<hi rend="smallcaps">`, not the usual `strong` — the
    /// heading test reads the paragraph's *text*, so both are caught.
    @Test("Books under a published pseudo-heading stay bibliography")
    func publishedSubtreeIsNotPromoted() async throws {
        let all = try await rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Note on sources</head>
          <p rend="flushleft">Korean Conflict Files, Lot 55 D 128</p>
          <p>A special historical collection.</p>
          <p rend="center"><hi rend="smallcaps">Published Sources</hi></p>
          <p rend="flushleft">Dean Acheson, Present at the Creation (New York, Norton, 1969).</p>
          <p rend="flushleft">John M. Allison, Ambassador from the Prairie (Boston, 1973).</p>
        </div>
        """)
        let items = all.filter { $0.kind == .item }
        #expect(items.count == 1, Comment(rawValue: "promoted: \(items.map(\.rawText))"))
        #expect(items[0].rawText.contains("Korean Conflict"))
        #expect(all.contains { $0.kind == .bibliography && $0.rawText.contains("Acheson") },
                "the memoir lost its bibliography kind")
    }

    /// frus1969-76v34/v36: a whole section whose `<head>` marks it a bibliography, its books
    /// encoded as flushleft paragraphs with no `<item>` in sight. Promotion there would turn
    /// the volume's whole reading list into archival collections.
    @Test("A whole published-sources section promotes nothing")
    func publishedSectionHeadIsNotPromoted() async throws {
        let items = try await rows("""
        <div type="section" subtype="sources" xml:id="published">
          <head>Published sources</head>
          <p rend="flushleft">Henry Kissinger, White House Years (Boston, Little Brown, 1979).</p>
          <p rend="flushleft">Richard Nixon, RN: The Memoirs of Richard Nixon (New York, 1978).</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.isEmpty, Comment(rawValue: "promoted books: \(items.map(\.rawText))"))
    }

    /// The series' boilerplate section titles, which three volumes write as flushleft
    /// paragraphs. Measured over the promoted corpus: **6 of 30,920 item rows begin
    /// `Sources for `, and all six are these titles** — the exclusion is exact rather than
    /// approximate, and costs no real collection.
    @Test("Boilerplate section titles are not collections")
    func sectionTitlesAreNotPromoted() async throws {
        let items = try await rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p rend="flushleft">Sources for the Foreign Relations Series</p>
          <p>The Foreign Relations statute requires that the published record …</p>
          <p rend="flushleft">Sources for Foreign Relations, 1952–1954, Guatemala</p>
          <p>This retrospective volume is a documentary history of PBSUCCESS.</p>
          <p rend="flushleft">Guatemala Collection, Job 79–01025A</p>
          <p>Records of the Directorate of Operations.</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.map(\.rawText) == ["Guatemala Collection, Job 79–01025A"],
                Comment(rawValue: "got \(items.map(\.rawText))"))
    }

    /// The index version must move with the parse output, or the owner's store keeps the
    /// old empty rows and none of this is visible.
    @Test("The change is carried by an index-version bump")
    func indexVersionMovedWithTheParse() {
        #expect(IndexingPipeline.currentDateIndexVersion >= 34,
                "parse output changed without bumping currentDateIndexVersion")
    }
}
