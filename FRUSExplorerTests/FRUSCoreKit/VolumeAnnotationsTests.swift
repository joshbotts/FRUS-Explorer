// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - VolumeAnnotationsTests

/// Tests for FRUSCoreKit's `VolumeAnnotations`: what a count means (the thresholds), the era bands,
/// the onset rule, the columnar file, and the shipped `volume-annotations-index.json`
/// (`Planning/Editors-Annotations-Design-2026-11-06.md`).
///
/// Version history:
///   1.0 — 2026-11-06: the editors' annotations design, lane A
@Suite("VolumeAnnotations — what each volume's editors annotated, and when a practice became standard")
struct VolumeAnnotationsTests {

    /// A volume of `documents` documents carrying `counts`.
    private func volume(_ era: AnnotationEra, documents: Int = 10,
                        _ counts: [AnnotationCategory: Int] = [:], sections: [String] = []) -> VolumeAnnotations {
        VolumeAnnotations(documents: documents, historicalDocuments: documents, personsListed: 0,
                          termsListed: 0, era: era, counts: counts, sections: sections)
    }

    @Test("A pervasive layer needs half the documents, despatch numbers a tenth, a counted layer one")
    func thresholds() {
        let annotations = volume(.from1955, documents: 10, [
            .people: 5, .abbreviations: 4, .despatch: 1, .subjects: 1, .footnotes: 0,
        ])
        #expect(annotations.carries(.people))
        #expect(!annotations.carries(.abbreviations))
        #expect(annotations.carries(.despatch))
        #expect(annotations.carries(.subjects))
        #expect(!annotations.carries(.footnotes))
        #expect(!volume(.from1955, documents: 11, [.despatch: 1]).carries(.despatch))
        #expect(!volume(.from1955, documents: 0).carries(.people))
    }

    @Test("Source notes are carried by either form, and each form is era-bound")
    func sourceNotesCountEitherForm() {
        let annotations = volume(.from1955, documents: 10, [.sourceCitation: 3, .sourceFileNumber: 2])
        #expect(annotations.sourceNotes == 5)
        #expect(annotations.carriesSourceNotes)
        #expect(!annotations.carries(.sourceCitation) && !annotations.carries(.sourceFileNumber))
        #expect(!AnnotationCategory.sourceCitation.isSeriesWide && AnnotationCategory.people.isSeriesWide)
    }

    @Test("A volume's era is its subseries' first year, and the retrospectives a band of their own")
    func eras() {
        #expect(AnnotationEra.era(subseriesStartYear: 1861, volumeId: "frus1861") == .from1861)
        #expect(AnnotationEra.era(subseriesStartYear: 1898, volumeId: "frus1898") == .from1861)
        #expect(AnnotationEra.era(subseriesStartYear: 1951, volumeId: "frus1951v01") == .from1951)
        #expect(AnnotationEra.era(subseriesStartYear: 1969, volumeId: "frus1969-76v17") == .from1969)
        #expect(AnnotationEra.era(subseriesStartYear: 1989, volumeId: "frus1989-92v31") == .from1981)
        #expect(AnnotationEra.era(subseriesStartYear: 1860, volumeId: "frus1860") == nil)
        for retrospective in ["frus1917-72PubDipv06", "frus1945-50Intel", "frus1950-55Intel",
                              "frus1951-54Iran", "frus1951-54IranEd2", "frus1952-54Guat"] {
            #expect(AnnotationEra.era(subseriesStartYear: 1951, volumeId: retrospective) == .retrospective)
        }
        #expect(AnnotationEra.chronological.first == .from1861 && AnnotationEra.chronological.last == .from1981)
        #expect(AnnotationEra.from1945 < .from1951 && AnnotationEra.from1981 < .retrospective)
    }

    @Test("The onset is the first band from which every later band reaches 75%, the retrospectives aside")
    func onset() {
        var volumes: [String: VolumeAnnotations] = [:]
        func add(_ era: AnnotationEra, carrying: Int, of total: Int) {
            for n in 0..<total {
                volumes["\(era.rawValue)-\(n)"] = volume(era, documents: 2, n < carrying ? [.people: 2] : [:])
            }
        }
        add(.from1945, carrying: 2, of: 4)   // 50%
        add(.from1951, carrying: 3, of: 4)   // 75%
        add(.from1955, carrying: 4, of: 4)
        add(.from1969, carrying: 9, of: 10)
        add(.retrospective, carrying: 0, of: 5)
        let index = VolumeAnnotationsIndex(generated: "2026-11-06", corpusCommit: "c", indexVersion: 1,
                                           volumes: volumes)
        // 1861–1944 and 1981 on hold no volume here and are passed over.
        #expect(index.onset(of: .people) == .from1951)
        #expect(index.onset(of: .abbreviations) == nil)
        #expect(index.volumeIds(where: { $0.carries(.people) }).count == 18)
    }

    @Test("The columnar file reads back as written, and its keys are sorted")
    func columnarRoundTrip() throws {
        let index = VolumeAnnotationsIndex(
            generated: "2026-11-06", corpusCommit: "6170e4b32", indexVersion: 73,
            volumes: [
                "frus1969-76v17": VolumeAnnotations(
                    documents: 280, historicalDocuments: 268, personsListed: 325, termsListed: 470,
                    era: .from1969, counts: [.people: 279, .classification: 260, .numbered: 280],
                    sections: ["preface", "sources", "persons", "terms", "index"]),
                "frus1890": VolumeAnnotations(
                    documents: 502, historicalDocuments: 502, personsListed: 0, termsListed: 0,
                    era: .from1861, counts: [.correspondents: 502, .despatch: 347],
                    sections: ["list-of-papers", "index"]),
            ])
        let data = try index.shippingData()
        #expect(try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: data) == index)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"corpusCommit":"6170e4b32","fields":["documents","historicalDocuments""#))
        #expect(text.contains(#""sections":["index","list-of-papers","persons","preface","sources","terms"]"#))
    }

    @Test("A reader maps counts by name and ignores a field it does not know")
    func readerIgnoresAnUnknownField() throws {
        let json = """
            {"corpusCommit":"c","fields":["documents","historicalDocuments","personsListed","termsListed","people","someFutureLayer"],
             "generated":"2026-11-06","indexVersion":73,"schemaVersion":1,"sections":["preface"],
             "volumes":{"frus1955-57v01":["1955-1968",[10,9,40,30,8,6],[0]]}}
            """
        let index = try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: Data(json.utf8))
        let volume = try #require(index["frus1955-57v01"])
        #expect(volume.count(.people) == 8 && volume.personsListed == 40 && volume.sections == ["preface"])
        #expect(volume.count(.classification) == 0)
    }

    // MARK: The shipped file

    /// The shipped `volume-annotations-index.json`: from the repository in the package, from the
    /// app's bundle in Xcode, through the store the app reads it from.
    private func shippedIndex() throws -> VolumeAnnotationsIndex {
        #if SWIFT_PACKAGE
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/volume-annotations-index.json")
        return try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: Data(contentsOf: url))
        #else
        return try #require(VolumeAnnotationsStore.shared, """
            volume-annotations-index.json must decode from the app bundle. If it was just added it needs \
            `xcodegen generate` to be enrolled — followed by \
            `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
            """)
        #endif
    }

    @Test("The shipped file is the current index version's and covers the catalogue")
    func theShippedIndex() throws {
        let index = try shippedIndex()
        // Counted with the index's rules, so regenerated with every index version, as
        // `cited-page-map.json` is: a file from an older parse could disagree with the app.
        #expect(index.indexVersion == IndexingPipeline.currentDateIndexVersion)
        #expect(index.schemaVersion == VolumeAnnotationsIndex.currentSchemaVersion)
        #expect(index.volumes.count == 553)
    }
}
