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

// MARK: - #668 follow-up: the owner's report against the shipped v34

/// The two defects the owner found after #725 shipped, both reproduced from the live index.
///
/// ## 1. A long book citation closed the published subtree
/// `proseKind`'s narrative-exit rule ends a published-works run when a paragraph runs past
/// 200 characters, on the reasoning that a volume can resume narrative after its book list.
/// **frus1950v07's `S. L. A. Marshall, The River and the Gauntlet …` is 208 characters** —
/// eight over — so the run closed there and the **16 books after it were promoted to
/// archival collections**, each with a catalog-resolution affordance. frus1952-54Guat lost
/// its last published row the same way, at 207.
///
/// Before #725 those rows were merely misfiled as prose; the promotion turned a cosmetic
/// misclassification into a wrong archival claim, which is this project's worst defect
/// class. A **flushleft paragraph is a list entry by definition** and can never be the
/// narrative that ends the list, so it no longer triggers the exit.
///
/// This also restores parity with `VolumeSourcesExtractor`, which has no narrative-exit rule
/// and therefore never had the bug: measured over all 552 volumes it promoted 0 rows in
/// frus1950v07 while the app promoted 16.
///
/// ## 2. Descriptions were divorced from their collections
/// The browser groups rows by `kind`, so a promoted collection landed under "Archival
/// Collections" and its description paragraph under "About These Sources" — the two halves
/// of one entry in different sections of the screen. `note` carries the description on the
/// collection row.
///
/// Version history:
///   1.0 — Session 2026-08-07: #668 follow-up
@Suite("Paragraph-encoded sources — owner report on v34 (#668)")
struct FlushLeftSourcesFollowUpTests {

    private func rows(_ front: String) async throws -> [VolumeSourceEntry] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus668b-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("frus1950v07.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>fixture</title></titleStmt>
          <publicationStmt><date when="1976">1976</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><front>
        \(front)
          </front><body></body></text>
        </TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
    }

    /// The 208-character citation, verbatim from frus1950v07, and the two books that
    /// followed it into the wrong section.
    private let longBookShape = """
    <div type="section" subtype="sources" xml:id="sources">
      <head>Note on sources</head>
      <p rend="center"><hi rend="smallcaps">Published Sources</hi></p>
      <p rend="flushleft">Douglas MacArthur, Reminiscences (New York, McGraw-Hill Book Company, 1964).</p>
      <p rend="flushleft">S. L. A. Marshall, The River and the Gauntlet: Defeat of the Eighth Army by the \
    Chinese Communist Forces, November, 1950, in the Battle of the Chongchon River, Korea (New York, \
    William Morrow and Company, 1953).</p>
      <p rend="flushleft">David Rees, Korea: The Limited War (New York, St. Martin's Press, 1964).</p>
      <p rend="flushleft">Matthew Ridgway, The Korean War (Garden City, N.Y., Doubleday, 1967).</p>
    </div>
    """

    @Test("A long book citation does not close the published list")
    func longCitationDoesNotEndTheBookList() async throws {
        let all = try await rows(longBookShape)
        // Fixture guard: the citation really is over the narrative-exit threshold, or this
        // test passes for the wrong reason.
        let marshall = try #require(all.first { $0.rawText.hasPrefix("S. L. A. Marshall") })
        #expect(marshall.rawText.count > 200,
                Comment(rawValue: "fixture no longer trips the threshold: \(marshall.rawText.count)"))

        #expect(all.allSatisfy { $0.kind != .item },
                Comment(rawValue: "books promoted: \(all.filter { $0.kind == .item }.map(\.rawText))"))
        #expect(all.filter { $0.kind == .bibliography }.count == 4,
                Comment(rawValue: "kinds: \(all.map { "\($0.kind)" })"))
    }

    /// The exit rule still has to work — a volume that genuinely resumes narrative after its
    /// book list must still leave the list. The discriminator is `rend`, not length.
    @Test("A long narrative paragraph still ends the published list")
    func longNarrativeStillEndsTheList() async throws {
        let all = try await rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>Sources</head>
          <p>Published Sources</p>
          <p rend="flushleft">David Rees, Korea: The Limited War (New York, St. Martin's Press, 1964).</p>
          <p>The Department of State also drew on a substantial body of covert-action \
        documentation for this volume, which is described at length in the paragraphs that \
        follow and which does not form part of the published bibliography above; the editors \
        have noted its provenance wherever it bears on the record printed here.</p>
          <p rend="flushleft">Conference Files, Lot 59 D 95</p>
        </div>
        """)
        #expect(all.contains { $0.kind == .bibliography && $0.rawText.hasPrefix("David Rees") })
        // The narrative paragraph closed the run, so the collection after it is promoted.
        #expect(all.contains { $0.kind == .item && $0.rawText == "Conference Files, Lot 59 D 95" },
                Comment(rawValue: "kinds: \(all.map { "\($0.kind): \($0.rawText.prefix(28))" })"))
    }

    // MARK: - The description belongs to its collection

    private let frus1951v05Shape = """
    <div type="section" subtype="sources" xml:id="source">
      <head>List of sources</head>
      <p>The principal source of documentation for this volume was the indexed central files.</p>
      <p rend="flushleft"><gloss target="#t_CFM1">CFM</gloss> Files, Lot M 88</p>
      <p>Consolidated master collection of the records of conferences of heads of state.</p>
      <p rend="flushleft">PPS Files, Lot 64 D 563</p>
      <p>Files of the Policy Planning Staff.</p>
    </div>
    """

    @Test("Each collection carries the description that follows it")
    func descriptionsRideOnTheirCollection() async throws {
        let items = try await rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.count == 2)
        #expect(items.first?.note == "Consolidated master collection of the records of conferences of heads of state.",
                Comment(rawValue: "note: \(items.first?.note ?? "nil")"))
        #expect(items.last?.note == "Files of the Policy Planning Staff.")
    }

    /// Absorbed descriptions must leave the prose list, or the volume shows each one twice —
    /// once on its collection and once under "About These Sources".
    @Test("An absorbed description is no longer a separate prose row")
    func absorbedDescriptionsLeaveTheProseList() async throws {
        let all = try await rows(frus1951v05Shape)
        let prose = all.filter { $0.kind == .prose }
        #expect(prose.count == 1, Comment(rawValue: "prose rows: \(prose.map(\.rawText))"))
        #expect(prose[0].rawText.hasPrefix("The principal source"))
        #expect(all.map { "\($0.kind)" } == ["prose", "item", "item"],
                Comment(rawValue: "kinds: \(all.map { "\($0.kind)" })"))
    }

    /// The description must not reach the key extraction: `rawText` is what the lot and
    /// record-group grammars read, and a paragraph of narrative would both bury the
    /// collection name and hand them spurious matches.
    @Test("The description stays out of the collection's keys")
    func descriptionDoesNotPolluteKeys() async throws {
        let items = try await rows(frus1951v05Shape).filter { $0.kind == .item }
        #expect(items.first?.rawText == "CFM Files, Lot M 88")
        #expect(items.last?.lotFileNorm == "64D563")
    }

    /// Consecutive headings have no description between them, and must not absorb each
    /// other — the book-list shape, where every row is flushleft.
    @Test("A heading does not absorb the next heading")
    func consecutiveHeadingsDoNotAbsorb() async throws {
        let items = try await rows("""
        <div type="section" subtype="sources" xml:id="sources">
          <head>List of sources</head>
          <p rend="flushleft">CFM Files, Lot M 88</p>
          <p rend="flushleft">Conference Files, Lot 59 D 95</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.map(\.rawText) == ["CFM Files, Lot M 88", "Conference Files, Lot 59 D 95"])
        #expect(items.allSatisfy { $0.note == nil },
                Comment(rawValue: "notes: \(items.map { $0.note ?? "nil" })"))
    }

    @Test("The follow-up is carried by its own index-version bump")
    func indexVersionMovedAgain() {
        #expect(IndexingPipeline.currentDateIndexVersion >= 35,
                "parse output changed again without bumping currentDateIndexVersion")
    }
}

// MARK: - #668 follow-up 2: repository headings and the library route

/// The owner's second report against the reindexed store: frus1952-54Guat's Eisenhower Library
/// collections did not resolve, though the #681 harvest holds them.
///
/// Two independent gaps, both measured before either was written:
///
/// 1. **The repository never reached the rows that need it.** `repository` is inherited from
///    ancestor *items* in a `<list>` outline; promoted paragraphs are all depth 0 with no
///    ancestors, so only the row naming the library in its own text carried one. Measured over
///    the reindexed store, **541 keyless promoted rows across 8 volumes** sit under a repository
///    heading (frus1969-76ve13 266, v34 51, frus1981-88v10 50, frus1950-55Intel 50, …).
/// 2. **`frontMatterResolution` never asked the library catalogue.** It consulted the lot index
///    and the record-group headers and nothing else; the presidential-library bundle was wired
///    into Source Explorer's document route in #710 and no further.
///
/// Version history:
///   1.0 — Session 2026-08-07: #668 follow-up 2
@Suite("Repository headings in a flat sources list (#668)")
struct FlatSourcesRepositoryHeadingTests {

    private func rows(_ front: String) async throws -> [VolumeSourceEntry] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("frus668c-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("frus1952-54Guat.xml")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>fixture</title></titleStmt>
          <publicationStmt><date when="2003">2003</date></publicationStmt>
          <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><front>
        \(front)
          </front><body></body></text>
        </TEI>
        """.write(to: url, atomically: true, encoding: .utf8)
        return try await FRUSDocumentParser().parseVolumeFull(volumeURL: url).volumeSources
    }

    /// frus1952-54Guat's unpublished list, reduced — two repository headings and their children.
    private let guatShape = """
    <div type="section" subtype="sources" xml:id="sources">
      <head>Sources</head>
      <p>Unpublished Sources</p>
      <p rend="flushleft">Central Intelligence Agency, Langley, Virginia</p>
      <p rend="flushleft">Guatemala Collection, Job 79–01025A</p>
      <p rend="flushleft">Dwight D. Eisenhower Library, Abilene, Kansas</p>
      <p rend="flushleft">John Foster Dulles Papers</p>
      <p rend="flushleft">Ann Whitman File</p>
      <p rend="flushleft">James C. Hagerty Papers</p>
    </div>
    """

    @Test("A repository row becomes the heading for the rows after it")
    func repositoryRowsBecomeHeadings() async throws {
        let items = try await rows(guatShape).filter { $0.kind == .item }
        #expect(items.map(\.isHeading) == [true, false, true, false, false, false],
                Comment(rawValue: "headings: \(items.map { "\($0.rawText.prefix(24)):\($0.isHeading)" })"))
        #expect(items.map(\.depth) == [0, 1, 0, 1, 1, 1],
                Comment(rawValue: "depths: \(items.map(\.depth))"))
    }

    /// The point of the heading: its children inherit the repository, which is what a library
    /// collection needs before it can resolve at all.
    @Test("Children inherit their repository from the heading")
    func childrenInheritTheRepository() async throws {
        let items = try await rows(guatShape).filter { $0.kind == .item }
        let dulles = try #require(items.first { $0.rawText == "John Foster Dulles Papers" })
        #expect(dulles.repository == "Eisenhower Library",
                Comment(rawValue: "got \(dulles.repository ?? "nil")"))
        let guatemala = try #require(items.first { $0.rawText.hasPrefix("Guatemala Collection") })
        #expect(guatemala.repository == "Central Intelligence Agency")
    }

    /// A lot-bearing row is a collection even when its text contains a repository keyword, or
    /// every `Department of State … Files, Lot 57 D 688` row would become a heading and swallow
    /// the lots after it.
    @Test("A lot-bearing row is never a repository heading")
    func lotRowsAreNotHeadings() async throws {
        let items = try await rows("""
        <div type="section" subtype="sources" xml:id="source">
          <head>List of sources</head>
          <p rend="flushleft">Department of State Atomic Energy Files, Lot 57 D 688</p>
          <p rend="flushleft">PPS Files, Lot 64 D 563</p>
        </div>
        """).filter { $0.kind == .item }
        #expect(items.allSatisfy { !$0.isHeading },
                Comment(rawValue: "headings: \(items.map { "\($0.rawText.prefix(30)):\($0.isHeading)" })"))
        #expect(items.allSatisfy { $0.depth == 0 })
        #expect(items.last?.lotFileNorm == "64D563")
    }

    // MARK: - The library route

    /// The two collections the owner's harvest holds, resolved through the **real** bundled
    /// catalogue and the **real** matcher.
    @Test("An Eisenhower Library collection resolves to its catalog record")
    func libraryCollectionsResolve() async throws {
        try #require(PresidentialLibraryIndexStore.shared != nil,
                     "presidential-library-catalog.json must be bundled")
        let dulles = try #require(ArchivalResolver.libraryResolution(
            repository: "Eisenhower Library", entryText: "John Foster Dulles Papers"))
        #expect(dulles.naId == "580942", Comment(rawValue: "got \(dulles.naId)"))
        #expect(dulles.matchType == "library")

        let hagerty = try #require(ArchivalResolver.libraryResolution(
            repository: "Eisenhower Library", entryText: "James C. Hagerty Papers"))
        #expect(hagerty.naId == "581740", Comment(rawValue: "got \(hagerty.naId)"))
    }

    /// **The trap this route exists to avoid.** `Ann Whitman File` is the common name for the
    /// Eisenhower Papers as President; the catalogue separately holds `Ann C. Whitman Papers`
    /// (NAID 643447), a different body of records. A looser title rule would hand a researcher
    /// a real NARA record for the wrong papers — the worst defect class this project has.
    @Test("Ann Whitman File does not resolve to Ann C. Whitman Papers")
    func annWhitmanFileIsNotAnnWhitmanPapers() async throws {
        let hit = ArchivalResolver.libraryResolution(
            repository: "Eisenhower Library", entryText: "Ann Whitman File")
        #expect(hit == nil, Comment(rawValue: "resolved to \(hit?.title ?? "-") (\(hit?.naId ?? "-"))"))
    }

    /// Without a repository the route cannot run, which is exactly why gap 1 had to be fixed
    /// before gap 2 could pay off.
    @Test("No repository, no library resolution")
    func repositoryIsRequired() {
        #expect(ArchivalResolver.libraryResolution(
            repository: nil, entryText: "John Foster Dulles Papers") == nil)
        #expect(ArchivalResolver.libraryResolution(
            repository: "", entryText: "John Foster Dulles Papers") == nil)
    }

    /// End to end: the parse gives the row its repository, and the resolver turns it into a
    /// catalog record. Neither half is useful alone.
    @Test("A parsed front-matter row resolves through the front-matter entry point")
    func endToEndFromParseToResolution() async throws {
        let items = try await rows(guatShape).filter { $0.kind == .item }
        let dulles = try #require(items.first { $0.rawText == "John Foster Dulles Papers" })
        let resolution = ArchivalResolver.frontMatterResolution(
            recordGroup: dulles.recordGroup, lotFile: dulles.lotFile,
            entryText: dulles.rawText, repository: dulles.repository)
        #expect(resolution?.naId == "580942",
                Comment(rawValue: "got \(resolution?.naId ?? "nil")"))
    }
}
