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
///   1.1 — 2026-11-08: `editorialOmissions` and the 1925 gate on a volume's publication year, and
///          schema version 2's row beside version 1's (Lane 1 of the follow-ups plan)
@Suite("VolumeAnnotations — what each volume's editors annotated, and when a practice became standard")
struct VolumeAnnotationsTests {

    /// A volume of `documents` documents carrying `counts`.
    private func volume(_ era: AnnotationEra, documents: Int = 10,
                        _ counts: [AnnotationCategory: Int] = [:], sections: [String] = [],
                        publicationYear: Int? = nil) -> VolumeAnnotations {
        VolumeAnnotations(documents: documents, historicalDocuments: documents, personsListed: 0,
                          termsListed: 0, era: era, counts: counts, sections: sections,
                          publicationYear: publicationYear)
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

    @Test("Bracketed omissions are counted whatever the year and carried only from 1925; the gate is theirs alone")
    func editorialOmissionsAreGatedOnThePublicationYear() {
        #expect(VolumeAnnotations.editorialOmissionsFromYear == 1925)
        let before = volume(.from1914, documents: 10, [.editorialOmissions: 3, .excisions: 1], publicationYear: 1924)
        #expect(before.count(.editorialOmissions) == 3)
        #expect(!before.carries(.editorialOmissions) && before.publishedBeforeEditorialOmissionsOrder)
        #expect(before.carries(.excisions), "the gate is the one layer's")
        let from = volume(.from1914, documents: 10, [.editorialOmissions: 3], publicationYear: 1925)
        #expect(from.carries(.editorialOmissions) && !from.publishedBeforeEditorialOmissionsOrder)
        // No year, no gate: a version-1 file, or a header that prints none.
        let undated = volume(.from1914, documents: 10, [.editorialOmissions: 3])
        #expect(undated.carries(.editorialOmissions) && !undated.publishedBeforeEditorialOmissionsOrder)
        #expect(!volume(.from1969, documents: 10, publicationYear: 2006).carries(.editorialOmissions))
        #expect(AnnotationCategory.editorialOmissions.family == .provenance)
        #expect(AnnotationCategory.editorialOmissions.threshold == .anyDocument)
        #expect(!AnnotationCategory.editorialOmissions.isSeriesWide)
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
                    sections: ["preface", "sources", "persons", "terms", "index"], publicationYear: 2006),
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
        // Schema version 2: the year is each row's fourth element, `null` where the header prints none.
        #expect(text.contains(#""schemaVersion":2"#))
        #expect(text.contains(",2006]") && text.contains(",null]"))
        #expect(VolumeAnnotationsIndex.currentSchemaVersion == 2)
    }

    @Test("A version-1 row of three elements reads with no year, and no bracketed omissions")
    func schemaVersion1RowsReadWithNoYear() throws {
        let json = """
            {"corpusCommit":"6170e4b32","fields":["documents","historicalDocuments","personsListed","termsListed","people","excisions"],
             "generated":"2026-11-06","indexVersion":74,"schemaVersion":1,"sections":["preface"],
             "volumes":{"frus1914":["1914-1919",[1200,1200,0,0,0,0],[0]]}}
            """
        let index = try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: Data(json.utf8))
        let volume = try #require(index["frus1914"])
        #expect(index.schemaVersion == 1)
        #expect(volume.publicationYear == nil && !volume.publishedBeforeEditorialOmissionsOrder)
        #expect(volume.count(.editorialOmissions) == 0 && !volume.carries(.editorialOmissions))
    }

    @Test("A version-2 row carries the year, and the gate reads it")
    func schemaVersion2RowsCarryTheYear() throws {
        let json = """
            {"corpusCommit":"6170e4b32","fields":["documents","historicalDocuments","personsListed","termsListed","editorialOmissions"],
             "generated":"2026-11-08","indexVersion":74,"schemaVersion":2,"sections":["preface"],
             "volumes":{"frus1914":["1914-1919",[1200,1200,0,0,16],[0],1922],
                        "frus1925v01":["1920-1931",[800,800,0,0,9],[0],1940],
                        "frus-undated":["1920-1931",[10,10,0,0,1],[],null]}}
            """
        let index = try JSONDecoder().decode(VolumeAnnotationsIndex.self, from: Data(json.utf8))
        let early = try #require(index["frus1914"])
        #expect(early.publicationYear == 1922 && early.count(.editorialOmissions) == 16)
        #expect(!early.carries(.editorialOmissions) && early.publishedBeforeEditorialOmissionsOrder)
        let later = try #require(index["frus1925v01"])
        #expect(later.publicationYear == 1940 && later.carries(.editorialOmissions))
        let undated = try #require(index["frus-undated"])
        #expect(undated.publicationYear == nil && undated.carries(.editorialOmissions))
        #expect(index.volumeIds { $0.carries(.editorialOmissions) } == ["frus-undated", "frus1925v01"])
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
        #expect(volume.publicationYear == nil, "a row of three elements is schema version 1's")
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
