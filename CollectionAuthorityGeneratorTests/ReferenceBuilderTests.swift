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
}
