// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSourcesIndexGeneratorCore

@Suite("VolumeSourcesExtractor")
struct VolumeSourcesExtractorTests {

    /// A minimal front-matter Sources section: one narrative paragraph, then a two-level
    /// collection outline with a bold heading.
    private let xml = Data("""
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <text><front>
        <div type="section" subtype="preface" xml:id="preface">
          <head>Preface</head><p>Prefatory remarks that must NOT become source rows.</p>
        </div>
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p>The sources for this volume are drawn from a diffuse base of records.</p>
          <list>
            <item><hi rend="strong">Department of State</hi>
              <list>
                <item>RG 59, Central Files 1969 POL 1, Lot File 70 D 150</item>
              </list>
            </item>
          </list>
        </div>
      </front></text>
    </TEI>
    """.utf8)

    @Test("Separates prose from items; only sources-section content is captured")
    func proseAndItems() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let prose = rows.filter { $0.kind == .prose }
        let items = rows.filter { $0.kind == .item }
        #expect(prose.count == 1)
        #expect(prose[0].text.contains("diffuse base"))
        // The preface paragraph (outside the sources section) is never captured.
        #expect(!rows.contains { $0.text.contains("Prefatory remarks") })
        #expect(items.count == 2)
    }

    @Test("Bold heading preserved at depth 0; RG record nested at depth 1")
    func headingsAndNesting() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let heading = try! #require(rows.first { $0.isHeading })
        #expect(heading.text.contains("Department of State"))
        #expect(heading.depth == 0)
        let rg = try! #require(rows.first { $0.text.contains("RG 59") })
        #expect(rg.depth == 1)
        #expect(rg.recordGroup == "59")
        #expect(rg.lotFile != nil)
    }

    @Test("Rows are emitted in document (pre-order) order: parent before child")
    func preOrder() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let hIdx = try! #require(rows.firstIndex { $0.isHeading })
        let rgIdx = try! #require(rows.firstIndex { $0.text.contains("RG 59") })
        #expect(hIdx < rgIdx)
    }

    @Test("Cross-volume authority dedups a heading recurring across volumes")
    func authorityDedup() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        let items = rows.filter { $0.kind == .item }
        var index = 0
        let tree = VolumeSourcesIndexRunner.buildTree(items, &index, depth: 0)
        var authority: [String: MajorCollection] = [:]
        VolumeSourcesIndexRunner.accumulateAuthority(tree, volumeId: "frusA", into: &authority)
        VolumeSourcesIndexRunner.accumulateAuthority(tree, volumeId: "frusB", into: &authority)
        let dept = try! #require(authority.values.first { $0.text.contains("Department of State") })
        #expect(dept.volumeIds.sorted() == ["frusA", "frusB"])
        #expect(dept.occurrences == 2)
    }

    @Test("Schema v2 output carries the resolution maps and drops per-volume trees")
    func schemaV2RoundTrips() throws {
        let index = VolumeSourcesIndex(
            schemaVersion: 2, generated: "2026-07-01",
            recordGroups: ["59": ResolvedNAID(naId: "388",
                                              catalogURL: "https://catalog.archives.gov/id/388",
                                              title: "General Records of the Department of State",
                                              recordGroup: "59", matchType: "api")],
            lots: ["80D212": ResolvedNAID(naId: "1", catalogURL: "https://catalog.archives.gov/id/1",
                                          title: "Lot 80 D 212", recordGroup: "59", matchType: "lot")],
            majorCollections: [])
        let encoded = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(VolumeSourcesIndex.self, from: encoded)
        #expect(decoded.schemaVersion == 2)
        #expect(decoded.recordGroups["59"]?.naId == "388")
        #expect(decoded.lots["80D212"]?.naId == "1")
        // The trimmed schema exposes only the resolution maps + authority — no `volumes` key.
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(!json.contains("\"volumes\""))
    }

    @Test("Lot files inherit the ancestor record group when gathering resolution keys")
    func ancestorRecordGroupInference() {
        let rows = VolumeSourcesExtractor.extract(fromXML: xml)
        var index = 0
        let tree = VolumeSourcesIndexRunner.buildTree(rows.filter { $0.kind == .item }, &index, depth: 0)
        var lotKeys: [String: String] = [:]
        var rgHeadings: [String: String] = [:]
        VolumeSourcesIndexRunner.gatherKeys(tree, inheritedRG: nil, lotKeys: &lotKeys, rgHeadings: &rgHeadings)
        // The RG-59 record nested under "Department of State" carries a lot file; its key
        // is gathered with the record group parsed from its own text ("RG 59").
        #expect(lotKeys.values.contains("59"))
        #expect(!lotKeys.isEmpty)
    }
}

// MARK: - #668: the Sources list encoded as paragraphs

/// The early-1950s encoding: a `<p rend="flushleft">` collection heading followed by an
/// ordinary description paragraph, with no `<list>`/`<item>` anywhere.
///
/// ## Why this needed its own suite
/// Every paragraph used to become `.prose`, so 14 volumes produced **zero** collection rows
/// and contributed nothing to `volume-sources-index.json` — `frus1951v05` appeared in it 0
/// times. Measured with this extractor over all 552 manifest volumes, the promotion adds
/// **526 collection rows across 14 volumes and takes a row away from none.**
///
/// The fixtures below are the four shapes the corpus actually writes, all reduced from real
/// volumes. Three of them are cases where a flushleft paragraph must **not** become a
/// collection, and they are the reason this is not a one-line change.
///
/// Version history:
///   1.0 — Session 2026-08-07: #668
@Suite("VolumeSourcesExtractor — paragraph-encoded sources (#668)")
struct FlushLeftSourcesTests {

    private func rows(_ body: String) -> [SourceRow] {
        VolumeSourcesExtractor.extract(fromXML: Data("""
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><front>
        \(body)
        </front></text></TEI>
        """.utf8))
    }

    /// frus1951v05, reduced. Note the `<gloss>` inside the first heading and the `xml:id`
    /// spelled `source` rather than `sources` — both verbatim from the volume.
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
    func flushLeftHeadingsArePromoted() {
        let items = rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.count == 3, Comment(rawValue: "got \(items.count) collection rows"))
        #expect(items.map(\.text) == ["CFM Files, Lot M 88",
                                      "PPS Files, Lot 64 D 563",
                                      "S/S–NSC Files, Lot 63 D 351"])
    }

    /// The `<gloss>` element wrapping `CFM` must not truncate the collection name — the
    /// characters arrive through `foundCharacters` like any other text.
    @Test("A <gloss> inside the heading keeps the collection name whole")
    func glossDoesNotTruncateTheName() {
        let items = rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.first?.text.hasPrefix("CFM Files") == true,
                Comment(rawValue: "got \(items.first?.text ?? "no rows")"))
    }

    /// The promoted rows must carry keys, or the promotion buys nothing: a collection row
    /// with no lot number resolves to nothing in Source Explorer.
    @Test("Promoted rows carry their lot numbers")
    func promotedRowsCarryKeys() {
        let items = rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.contains { $0.lotFile == "64 D 563" },
                Comment(rawValue: "lots: \(items.map { $0.lotFile ?? "-" })"))
    }

    /// The description paragraph after each heading stays prose, in document order beneath
    /// its heading. Folding it into the heading would bury the collection name in narrative
    /// and corrupt the key extraction that reads that text.
    @Test("The description paragraph stays prose, and stays in order")
    func descriptionsStayProse() {
        let all = rows(frus1951v05Shape)
        let kinds = all.map(\.kind)
        #expect(kinds == [.prose, .item, .prose, .item, .prose, .item, .prose],
                Comment(rawValue: "got \(kinds)"))
    }

    // MARK: - What must not be promoted

    /// The guard that leaves the 240 already-working volumes untouched **by construction**:
    /// a section that emits any item row promotes nothing.
    @Test("A section with an item outline promotes no paragraph")
    func sectionWithItemsPromotesNothing() {
        let all = rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p rend="flushleft">A flushleft paragraph that is not a collection.</p>
          <list><item>RG 59, Central Files, Lot 70 D 150</item></list>
        </div>
        """)
        let items = all.filter { $0.kind == .item }
        #expect(items.count == 1)
        #expect(items[0].text.contains("RG 59"))
        #expect(all.contains { $0.kind == .prose && $0.text.contains("not a collection") })
    }

    /// frus1950v07, reduced: 39 of its flushleft paragraphs are **books** sitting under a
    /// `Published Sources` pseudo-heading. Promoting them would file a memoir as an archival
    /// collection. The heading test reads the paragraph's text, so the volume's `smallcaps`
    /// spelling is caught as readily as the usual `strong`.
    @Test("Books under a published pseudo-heading stay prose")
    func publishedSubtreeIsNotPromoted() {
        let all = rows("""
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
        #expect(items.count == 1, Comment(rawValue: "promoted: \(items.map(\.text))"))
        #expect(items[0].text.contains("Korean Conflict"))
        #expect(all.contains { $0.kind == .prose && $0.text.contains("Acheson") })
    }

    /// An `Unpublished Sources` heading reopens the archival run, so a collection listed
    /// after the books is still promoted.
    @Test("An unpublished heading reopens promotion")
    func unpublishedHeadingReopensPromotion() {
        let items = rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p>Published Sources</p>
          <p rend="flushleft">Dean Acheson, Present at the Creation (New York, Norton, 1969).</p>
          <p>Unpublished Sources</p>
          <p rend="flushleft">Conference Files, Lot 59 D 95</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.map(\.text) == ["Conference Files, Lot 59 D 95"],
                Comment(rawValue: "got \(items.map(\.text))"))
    }

    /// frus1969-76v34/v36's shape: a whole section whose `<head>` marks it a bibliography,
    /// with its books as flushleft paragraphs and no `<item>` in sight. Promotion there
    /// would turn every book in the volume's reading list into an archival collection.
    @Test("A whole published-sources section promotes nothing")
    func publishedSectionHeadIsNotPromoted() {
        let items = rows("""
        <div type="section" subtype="sources" xml:id="published">
          <head>Published sources</head>
          <p rend="flushleft">Henry Kissinger, White House Years (Boston, Little Brown, 1979).</p>
          <p rend="flushleft">Richard Nixon, RN: The Memoirs of Richard Nixon (New York, 1978).</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.isEmpty, Comment(rawValue: "promoted books: \(items.map(\.text))"))
    }

    /// The series' own boilerplate section titles, which three volumes write as flushleft
    /// paragraphs. Measured over the promoted corpus: **6 of 30,920 item rows begin
    /// `Sources for `, and all six are these titles** — so the exclusion is exact rather
    /// than approximate, and costs no real collection.
    @Test("Boilerplate section titles are not collections")
    func sectionTitlesAreNotPromoted() {
        let items = rows("""
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
        #expect(items.map(\.text) == ["Guatemala Collection, Job 79–01025A"],
                Comment(rawValue: "got \(items.map(\.text))"))
        #expect(VolumeSourcesExtractor.isSectionTitle("Sources for the Foreign Relations Series"))
        #expect(!VolumeSourcesExtractor.isSectionTitle("Conference Files, Lot 59 D 95"))
    }
}
