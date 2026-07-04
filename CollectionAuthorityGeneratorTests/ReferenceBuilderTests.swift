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
