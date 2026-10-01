// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
import SourceNoteKit
@testable import CollectionAuthorityGeneratorCore

/// Segment tokenization, gating, and reference derivation (the merge.xq segment model
/// at two-level depth).
@Suite struct ReferenceBuilderTests {

    // MARK: Tokenization & gates

    @Test func citationSegmentsTokenizeOnCommaSpace() {
        let segs = ReferenceBuilder.segments(
            ofCitation: "Johnson Library, National Security File, Country File, Vietnam, Box 43. Secret.")
        #expect(segs.first == "Johnson Library")
        #expect(segs.contains("National Security File"))
        #expect(segs.contains("Country File"))
    }

    @Test func locatorSegmentsAreRejected() {
        #expect(!ReferenceBuilder.isSeriesSegment("Box 43"))
        #expect(!ReferenceBuilder.isSeriesSegment("Folder 12"))
        #expect(!ReferenceBuilder.isSeriesSegment("Reel 7"))
        #expect(!ReferenceBuilder.isSeriesSegment("Lot 64 D 199"))
        #expect(!ReferenceBuilder.isSeriesSegment("RG 59"))
        #expect(!ReferenceBuilder.isSeriesSegment("\u{201C}Memorandums of meetings\u{201D}"))
        #expect(!ReferenceBuilder.isSeriesSegment("US(P)/A/351"))
        // Classes are level-2 identities, never series segments.
        #expect(!ReferenceBuilder.isSeriesSegment("POL 27 ARAB-ISR"))
    }

    @Test func seriesSegmentsPassTheGate() {
        #expect(ReferenceBuilder.isSeriesSegment("National Security File"))
        #expect(ReferenceBuilder.isSeriesSegment("Country File"))
        #expect(ReferenceBuilder.isSeriesSegment("Records of the Policy Planning Staff"))
        // Word-bounded locator leads: a real name that merely starts with the letters.
        #expect(ReferenceBuilder.isSeriesSegment("Boxer Rebellion File"))
    }

    @Test func genericLeadsFallBackToFullTextKey() {
        // "Records, 1950-54" would over-merge on "Records" alone.
        let segment = ReferenceBuilder.leadingMergeSegment(of: "Records, of the Executive Secretariat")
        #expect(segment == "Records, of the Executive Secretariat")
        let distinctive = ReferenceBuilder.leadingMergeSegment(
            of: "National Security File, Country File")
        #expect(distinctive == "National Security File")
    }

    @Test func normalizationBridgesDashesCaseAndWhitespace() {
        #expect(ReferenceBuilder.normalized("Central Files 1967–69") ==
                ReferenceBuilder.normalized("central files  1967-69."))
    }

    @Test func segmentNormFoldsTrailingPluralsConservatively() {
        // Singular/plural variants of the same collection produce one merge key…
        #expect(CollectionKeying.segmentNorm("National Security Files") ==
                CollectionKeying.segmentNorm("National Security File"))
        #expect(CollectionKeying.level1Key(lotFileNorm: nil, repository: "Johnson Library",
                                           leadingSegment: "National Security Files") ==
                "txt:johnson library|national security file")
        // …but the fold never touches double-s words, short words, non-letter words,
        // or possessive tails.
        #expect(CollectionKeying.segmentNorm("Records of Congress") == "records of congress")
        #expect(CollectionKeying.segmentNorm("Press Files 1960s") == "press files 1960s")
        #expect(CollectionKeying.segmentNorm("US") == "us")
        #expect(CollectionKeying.segmentNorm("Memoranda of the Secretary's") ==
                "memoranda of the secretary's")
    }

    @Test func sentenceCutNeverTruncatesNameInitials() {
        // Adversarial review 2026-07-04 finding 2: the '. ' sentence cut fired on
        // name initials, keying "Charles S. Murphy Papers" as "Charles S".
        #expect(ReferenceBuilder.leadingMergeSegment(of: "Charles S. Murphy Papers")
                == "Charles S. Murphy Papers")
        #expect(ReferenceBuilder.leadingMergeSegment(of: "Henry A. Kissinger Office Files")
                == "Henry A. Kissinger Office Files")
        // A real prose boundary after the name still cuts — at the right dot.
        #expect(ReferenceBuilder.leadingMergeSegment(
                    of: "Charles S. Murphy Papers. Documents from the Truman era were consulted")
                == "Charles S. Murphy Papers")
        // The original prose-cut motivation keeps working…
        #expect(ReferenceBuilder.leadingMergeSegment(
                    of: "Central Files. During this period the Department employed a subject-numeric system")
                == "Central Files")
        // …and dotted abbreviations still refuse the cut.
        #expect(ReferenceBuilder.leadingMergeSegment(of: "U.S. Delegation Files")
                == "U.S. Delegation Files")
        // Distinct Kissinger collections stay distinct level-1 keys.
        #expect(CollectionKeying.level1Key(
                    lotFileNorm: nil, repository: "National Archives",
                    leadingSegment: ReferenceBuilder.leadingMergeSegment(
                        of: "Henry A. Kissinger Office Files")!) !=
                CollectionKeying.level1Key(
                    lotFileNorm: nil, repository: "National Archives",
                    leadingSegment: ReferenceBuilder.leadingMergeSegment(
                        of: "Henry A. Kissinger Telephone Conversations")!))
    }

    @Test func repositoryCanonicalizationBridgesLibraryVariants() {
        #expect(ReferenceBuilder.canonicalRepository("Dwight D. Eisenhower Library") == "Eisenhower Library")
        #expect(ReferenceBuilder.canonicalRepository("Nixon Presidential Materials") == "Nixon")
        #expect(ReferenceBuilder.canonicalRepository("Department of State") == "Department of State")
        #expect(ReferenceBuilder.canonicalRepository(nil) == nil)
    }

    // MARK: Document-note references

    @Test func presidentialLibraryNoteYieldsTwoLevels() {
        let note = "Source: Johnson Library, National Security File, Country File, Vietnam, Box 43."
        let parsed = SourceNoteParser().parse(note)
        let ref = ReferenceBuilder.reference(volumeId: "frus1964-68v01", note: note, parsed: parsed)
        #expect(ref?.repository == "Johnson Library")
        #expect(ref?.leadingSegment == "National Security File")
        #expect(ref?.subSegment == "Country File")
        #expect(ref?.lotFileNorm == nil)
    }

    @Test func secondaryCopyCitationsMintNoPhantomRepositoryBuckets() {
        // Adversarial review 2026-07-04 finding 1: a State-held original with a
        // library copy cited later parses as .presidentialLibrary(library:
        // "Department of State", collection: "National Security File") — that
        // identity must never crystallize into the artifact (verified real shape,
        // frus1964-68v01).
        let note = "Source: Department of State, Bundy Files, Working Papers of "
            + "McGeorge Bundy. Secret. Copies are in the Johnson Library, "
            + "National Security File, Memos to the President."
        let parsed = SourceNoteParser().parse(note)
        if case .presidentialLibrary(let library, _, _) = parsed {
            #expect(library == "Department of State",
                    "parser shape assumption — the gate exists because of this parse")
        }
        #expect(CollectionKeying.identity(of: parsed, note: note) == nil,
                "secondary-copy citations are not clusterable (conservative)")
        #expect(ReferenceBuilder.reference(volumeId: "frus1964-68v01",
                                           note: note, parsed: parsed) == nil)
        // Genuine library leads keep working, including manuscript repositories.
        let genuine = "Source: Johnson Library, National Security File, Country File, Box 3."
        let genuineRef = ReferenceBuilder.reference(volumeId: "v", note: genuine,
                                                    parsed: SourceNoteParser().parse(genuine))
        #expect(genuineRef?.repository == "Johnson Library")
        let manuscript = "Minnesota Historical Society, Hubert H. Humphrey Papers, Box 12."
        let manuscriptRef = ReferenceBuilder.reference(
            volumeId: "v", note: manuscript, parsed: SourceNoteParser().parse(manuscript))
        #expect(manuscriptRef?.repository == "Minnesota Historical Society")
        #expect(manuscriptRef?.leadingSegment == "Hubert H. Humphrey Papers")
        // The parser's synthesized Nixon Presidential Materials identity (the
        // NARA-held Nixon corpus, ~8k 1969–76 notes) passes the gate too.
        let nixon = "Source: National Archives, Nixon Presidential Materials, NSC Files, "
            + "Box 1025, Presidential/HAK MemCons."
        let nixonRef = ReferenceBuilder.reference(
            volumeId: "v", note: nixon, parsed: SourceNoteParser().parse(nixon))
        #expect(nixonRef?.repository == "Nixon")
        #expect(nixonRef?.leadingSegment == "NSC Files")
    }

    @Test func centralFilesOverrideIsProvenanceIndependent() {
        // Adversarial review 2026-07-04 finding 5: a "Central Files…" row inherited
        // under a presidential-library heading keeps the library bucket (it is the
        // library's own collection), matching the .presidentialLibrary note
        // identity, which never overrides…
        let library = CollectionKeying.frontMatterIdentity(
            text: "Central Files", repository: "Johnson Library",
            lotFileNorm: nil, decimalClass: nil)
        #expect(library?.repository == "Johnson Library")
        // …while unattributed / National Archives / WNRC rows still re-bucket to
        // Department of State (the same file series across holder phrasings).
        for repo in [nil, "National Archives", "Washington National Records Center"] {
            let identity = CollectionKeying.frontMatterIdentity(
                text: "Central Files 1967–69", repository: repo,
                lotFileNorm: nil, decimalClass: nil)
            #expect(identity?.repository == "Department of State",
                    "repo \(repo ?? "nil") must re-bucket to Department of State")
        }
    }

    @Test func lotNoteKeysOnNormWithSeriesAlias() {
        let note = "Secretary's Memoranda of Conversation, lot 64 D 199, Box 3."
        let parsed = SourceNoteParser().parse(note)
        let ref = ReferenceBuilder.reference(volumeId: "frus1952-54v03", note: note, parsed: parsed)
        #expect(ref?.lotFileNorm == "64D199")
        #expect(ref?.seriesAlias == "Secretary's Memoranda of Conversation")
        #expect(ref?.repository == "Department of State")
    }

    @Test func centralFilesNoteAnchorsLevel1AndClassLevel2() {
        let note = "Source: Department of State, Central Files 1967–69, POL 27 ARAB–ISR. Secret."
        let parsed = SourceNoteParser().parse(note)
        let ref = ReferenceBuilder.reference(volumeId: "frus1964-68v19", note: note, parsed: parsed)
        #expect(ref != nil)
        #expect(ref?.leadingSegment?.contains("Central Files") == true)
        #expect(ref?.subDecimalClass == "POL 27 ARAB-ISR")
    }

    @Test func bareDecimalNoteIsNotClusterable() {
        let note = "711.00/11–552. Telegram."
        let parsed = SourceNoteParser().parse(note)
        let ref = ReferenceBuilder.reference(volumeId: "frus1952-54v01", note: note, parsed: parsed)
        #expect(ref == nil)
    }

    @Test func unrecognizedAndPublishedNotesAreSkipped() {
        let parser = SourceNoteParser()
        for note in ["Ibid., p. 4.", "Printed from an uncited copy."] {
            let ref = ReferenceBuilder.reference(volumeId: "v", note: note,
                                                 parsed: parser.parse(note))
            #expect(ref == nil)
        }
    }

    // MARK: Front-matter outline references

    private func rows(_ specs: [(depth: Int, heading: Bool, text: String)]) -> [FrontSourceRow] {
        specs.map {
            FrontMatterSourcesExtractor.makeItemRow(text: $0.text, depth: $0.depth,
                                                    isHeading: $0.heading, ancestorTexts: [])
        }
    }

    @Test func outlineWalkMapsTwoLevels() {
        // Johnson Library (structural) > National Security File (L1) > Country File (L2).
        let front = [
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Johnson Library, Austin, Texas", depth: 0, isHeading: true, ancestorTexts: []),
            FrontMatterSourcesExtractor.makeItemRow(
                text: "National Security File", depth: 1, isHeading: false,
                ancestorTexts: ["Johnson Library, Austin, Texas"]),
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Country File", depth: 2, isHeading: false,
                ancestorTexts: ["Johnson Library, Austin, Texas", "National Security File"]),
        ]
        let refs = ReferenceBuilder.references(volumeId: "v1", frontRows: front)
        #expect(refs.count == 2)
        #expect(refs[0].leadingSegment == "National Security File")
        #expect(refs[0].repository == "Johnson Library")
        #expect(refs[1].leadingSegment == "National Security File")
        #expect(refs[1].subSegment == "Country File")
    }

    @Test func lotItemsAreAlwaysLevel1EvenUnderGroupingHeadings() {
        let front = [
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Record Group 59, General Records of the Department of State",
                depth: 0, isHeading: true, ancestorTexts: []),
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Lot Files", depth: 1, isHeading: false,
                ancestorTexts: ["Record Group 59, General Records of the Department of State"]),
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Lot 64 D 199, Records of the Policy Planning Staff",
                depth: 2, isHeading: false,
                ancestorTexts: ["Record Group 59, General Records of the Department of State",
                                "Lot Files"]),
        ]
        let refs = ReferenceBuilder.references(volumeId: "v1", frontRows: front)
        #expect(refs.count == 1)
        #expect(refs[0].lotFileNorm == "64D199")
        #expect(refs[0].recordGroup == "59")
        #expect(refs[0].seriesAlias == "Records of the Policy Planning Staff")
    }

    @Test func classLeafUnderCentralFilesIsLevel2() {
        let front = [
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Central Files 1967–69", depth: 0, isHeading: false, ancestorTexts: []),
            FrontMatterSourcesExtractor.makeItemRow(
                text: "POL 27 ARAB–ISR", depth: 1, isHeading: false,
                ancestorTexts: ["Central Files 1967–69"]),
        ]
        let refs = ReferenceBuilder.references(volumeId: "v1", frontRows: front)
        #expect(refs.count == 2)
        #expect(refs[1].subDecimalClass == "POL 27 ARAB-ISR")
        #expect(refs[1].leadingSegment == "Central Files 1967–69")
    }

    @Test func colonJoinedClassLeafSplitsIntoCollectionAndClass() {
        let front = [
            FrontMatterSourcesExtractor.makeItemRow(
                text: "Central Files 1967–69: POL 27 ARAB–ISR", depth: 0,
                isHeading: false, ancestorTexts: []),
        ]
        let refs = ReferenceBuilder.references(volumeId: "v1", frontRows: front)
        #expect(refs.count == 1)
        #expect(refs[0].leadingSegment == "Central Files 1967–69")
        #expect(refs[0].subDecimalClass == "POL 27 ARAB-ISR")
    }

    // MARK: Childless repository headings (#1466)

    /// The level-1 references of an XML Sources list, keyed `leadingSegment or lot → repository`.
    private func level1Repositories(_ xml: String) -> [String: String] {
        let rows = FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8))
        var out: [String: String] = [:]
        for ref in ReferenceBuilder.references(volumeId: "v1", frontRows: rows)
        where ref.subSegment == nil && ref.subDecimalClass == nil {
            out[ref.leadingSegment ?? ref.lotFileNorm ?? "?"] = ref.repository ?? "<none>"
        }
        return out
    }

    /// The issue's fixture, frus1952-54v12p1's shape, driven from XML through the extractor to
    /// references — so the key the authority clusters under is the one asserted.
    @Test("Collections after a childless heading are keyed under its repository")
    func childlessHeadingAttributesItsSiblings() {
        let refs = level1Repositories(SiblingHeadingExtractorTests.v12p1Shape)
        #expect(refs["Whitman File"] == "Eisenhower Library")
        #expect(refs["Dulles Papers"] == "Eisenhower Library")
        #expect(refs["JCS Records"] == "National Archives")
        // The State lot printed before the Eisenhower heading does not take it.
        #expect(refs["58D776"] != "Eisenhower Library")
    }

    /// A full-name library heading the keyword list cannot read (`Princeton University Library`)
    /// still attributes the collections after it: the row carries no keyword, so the outline walk
    /// bridges the heading's name the way it already does for a heading with a nested list.
    @Test("A full-name library heading attributes its siblings through the bridge")
    func fullNameHeadingIsBridged() {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Whitman File</item>
          <item><hi rend="italic">Princeton University Library, Princeton, New Jersey</hi></item>
          <item>John Foster Dulles Papers</item>
          <item><hi rend="italic">Johnson Library, Austin, Texas</hi> <list><item>National Security File</item></list></item>
          <item>Dean Rusk Papers</item>
        </list></div></front></text></TEI>
        """
        let refs = level1Repositories(xml)
        #expect(refs["Whitman File"] == "Eisenhower Library")
        #expect(refs["John Foster Dulles Papers"] == "Princeton University")
        #expect(refs["National Security File"] == "Johnson Library")
        // A heading with its own list ends the bridge as it ends the row-level carry.
        #expect(refs["Dean Rusk Papers"] == "<none>")
    }

    /// A row printed as a heading ends the bridge as it ends the row-level carry: a collection after
    /// a styled `National Security Council` is not the full-name library's.
    @Test("A styled row ends the bridged sibling scope")
    func styledRowEndsTheBridge() {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="strong">Princeton University Library, Princeton, New Jersey</hi></item>
          <item>John Foster Dulles Papers</item>
          <item><hi rend="strong">National Security Council</hi></item>
          <item>Special Group Files</item>
        </list></div></front></text></TEI>
        """
        let refs = level1Repositories(xml)
        #expect(refs["John Foster Dulles Papers"] == "Princeton University")
        #expect(refs["Special Group Files"] == "<none>")
    }

    /// A full-name heading WITH its own list, printed after a childless keyword heading: its
    /// collections are its own, not the earlier heading's.
    @Test("A nested full-name heading is not scoped by an earlier sibling heading")
    func nestedFullNameHeadingKeepsItsCollections() {
        let xml = """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="italic">Eisenhower Library, Abilene, Kansas</hi></item>
          <item>Whitman File</item>
          <item><hi rend="italic">Princeton University Library, Princeton, New Jersey</hi> <list><item>Dulles Papers</item></list></item>
        </list></div></front></text></TEI>
        """
        let refs = level1Repositories(xml)
        #expect(refs["Whitman File"] == "Eisenhower Library")
        #expect(refs["Dulles Papers"] == "Princeton University")
    }

    // MARK: A long item's printed title (#1468)

    /// A Sources list under the Department of State holding one item, `item`, as XML.
    private static func stateList(_ item: String) -> String {
        """
        <TEI><text><front><div type="sources"><list>
          <item><hi rend="strong">Department of State</hi>
            <list>
              \(item)
            </list>
          </item>
        </list></div></front></text></TEI>
        """
    }

    /// frus1961-63v17.xml:7481's shape, shortened: the collection's title and its description share
    /// one item, the title printed in italic. Before #1468 the whole paragraph — 2,150 characters
    /// in the volume — was the record's name. The nested list is not in v17; it pins that a
    /// sub-series under the item votes the parent's title too, or the paragraph would win the vote.
    static let longTitledItem = stateList("""
        <item><p><hi rend="italic">Indexed Central Files.</hi> The main source of documentation for \
        <ref target="frus1961-63v17"><hi rend="italic">Foreign Relations</hi>, 1961–1963, Volumes \
        XVII</ref> and <ref target="frus1961-63v18">XVIII</ref> was the Department of State’s \
        indexed central files.</p><list><item>Telegrams to Saigon</item></list></item>
        """)

    /// Every reference the Sources list `xml` produces.
    private func references(_ xml: String) -> [CollectionReference] {
        ReferenceBuilder.references(volumeId: "v1",
                                    frontRows: FrontMatterSourcesExtractor.extract(fromXML: Data(xml.utf8)))
    }

    /// The one level-1 reference the Sources list `xml` produces.
    private func level1(_ xml: String) throws -> CollectionReference {
        let refs = references(xml).filter { $0.subSegment == nil && $0.subDecimalClass == nil }
        #expect(refs.count == 1, "\(refs.count) level-1 references")
        return try #require(refs.first)
    }

    @Test("A long item that opens with a printed title is named by the title and keeps its text as an alias")
    func longItemIsNamedByItsPrintedTitle() throws {
        let ref = try level1(Self.longTitledItem)
        let text = try #require(ref.fullTextAlias)
        #expect(ref.displayName == "Indexed Central Files")
        #expect(text.hasPrefix("Indexed Central Files. The main source of documentation for Foreign Relations"))
        #expect(text.count > ReferenceBuilder.printedTitleThreshold)
        // The record is still the one it was: its key is its leading segment, not its name.
        #expect(AuthorityBuilder.level1Key(for: ref) == "txt:department of state|indexed central file")
    }

    @Test("A sub-series under a titled item votes the parent's title, not its paragraph")
    func subSeriesVoteTheTitle() {
        let refs = references(Self.longTitledItem)
        #expect(refs.count == 2, "\(refs.count) references")
        #expect(refs.contains { $0.subSegment == "Telegrams to Saigon" })
        #expect(refs.allSatisfy { $0.displayName == "Indexed Central Files" },
                "names voted: \(refs.map { $0.displayName ?? "nil" })")
        // Each carries the paragraph too, so the former name is counted as the name was.
        #expect(refs.allSatisfy { $0.fullTextAlias?.hasPrefix("Indexed Central Files. The main source") == true })
    }

    @Test("An item of exactly 100 characters keeps its whole text as its name, printed title or not")
    func shortTitledItemKeepsItsText() throws {
        // 100 characters, the threshold itself: the title rule is for paragraphs, not for a title
        // with a short gloss. The fixture sits ON the boundary, so a threshold moved down by one
        // renames it.
        let item = #"<item><hi rend="italic">Subject-Numeric Central Files.</hi> The principal files consulted for both volumes, the political series.</item>"#
        let ref = try level1(Self.stateList(item))
        let name = try #require(ref.displayName)
        #expect(name.count == 100, "\(name.count) characters")
        #expect(name.hasPrefix("Subject-Numeric Central Files. The principal files"))
        #expect(ref.fullTextAlias == nil)
    }

    @Test("An item of 101 characters that opens with a printed title is named by the title")
    func justPastTheThresholdIsNamedByItsTitle() throws {
        // One character past the threshold, so a threshold moved up by one keeps the whole text.
        let item = #"<item><hi rend="italic">Subject-Numeric Central Files.</hi> The principal files consulted for these volumes, the political series.</item>"#
        let ref = try level1(Self.stateList(item))
        let text = try #require(ref.fullTextAlias)
        #expect(text.count == 101, "\(text.count) characters")
        #expect(ref.displayName == "Subject-Numeric Central Files")
    }

    @Test("A long item with no printed title keeps its whole text as its name")
    func longUntitledItemKeepsItsText() throws {
        // frus1952-54v06p1.xml:12601's shape: a plain item, 818 characters in the volume.
        let item = "<item>Files of the Office of the Director, International Security Affairs, Department of State, containing material for the years 1951 and 1952.</item>"
        let ref = try level1(Self.stateList(item))
        #expect(ref.displayName?.hasPrefix("Files of the Office of the Director, International Security Affairs") == true)
        #expect((ref.displayName?.count ?? 0) > ReferenceBuilder.printedTitleThreshold)
        #expect(ref.fullTextAlias == nil)
    }

    @Test("A long lot item keeps its whole text as its name, so its name keeps its lot number")
    func longLotItemKeepsItsText() throws {
        let item = #"<item><hi rend="italic">Conference Files.</hi> Lot 64 D 559, the records of the Executive Secretariat for the international conferences the Secretary attended, 1961–1963.</item>"#
        let ref = try level1(Self.stateList(item))
        #expect(ref.lotFileNorm == "64D559")
        #expect(ref.displayName?.contains("Lot 64 D 559") == true, "\(ref.displayName ?? "nil")")
        #expect(ref.fullTextAlias == nil)
    }

    @Test("A long item printed wholly as its title keeps its whole text as its name")
    func wholeItemTitleKeepsItsText() throws {
        // Nothing follows the title, so there is no description to cut away: only the closing
        // full stop would go, and the name would still be the whole item.
        let item = #"<item><hi rend="italic">Records of the Policy Planning Council, Subject Files on Atomic Energy, Outer Space and Disarmament Negotiations, 1957–1962.</hi></item>"#
        let ref = try level1(Self.stateList(item))
        #expect(ref.displayName?.hasPrefix("Records of the Policy Planning Council, Subject Files") == true)
        #expect(ref.displayName?.hasSuffix("1957–1962.") == true, "\(ref.displayName ?? "nil")")
        #expect(ref.fullTextAlias == nil)
    }

    @Test("A long item whose printed lead is empty keeps its whole text as its name")
    func emptyLeadKeepsItsText() throws {
        // A `<hi>` holding only a space opens the item without printing a title.
        let item = #"<item><hi rend="italic"> </hi>Files of the Office of the Director, International Security Affairs, Department of State, containing material for the years 1951 and 1952.</item>"#
        let ref = try level1(Self.stateList(item))
        #expect(ref.displayName?.hasPrefix("Files of the Office of the Director, International Security Affairs") == true,
                "\(ref.displayName ?? "nil")")
        #expect(ref.fullTextAlias == nil)
    }

    @Test("A printed title the item's text does not begin with is not used")
    func mismatchedLeadKeepsItsText() throws {
        // A line break inside the title joins its words in the `<hi>`'s own text
        // ("IndexedCentral Files.") but not in the item's, which spaces every element boundary.
        let item = #"<item><p><hi rend="italic">Indexed<lb/>Central Files.</hi> The main source of documentation for these volumes, 1961–1963, was the indexed central files of the Department.</p></item>"#
        let ref = try level1(Self.stateList(item))
        #expect(ref.displayName?.hasPrefix("Indexed Central Files. The main source") == true,
                "\(ref.displayName ?? "nil")")
        #expect(ref.fullTextAlias == nil)
    }
}
