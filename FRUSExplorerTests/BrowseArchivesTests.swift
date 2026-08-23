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

// MARK: - BrowseArchivesTests

/// Pure-logic tests for the Archives browse axis (#1051 B-5, A-9): the category-door
/// derivation, the R-1 drill spec's ordering and share arithmetic, the forward
/// category accessor, and the live-bundle guards that pin the axis's premises — the
/// slug↔`SourceProvenanceCategory` mapping and the categories-partition-the-notes
/// invariant, computed from the artifact rather than copied from doc comments.
///
/// Version history:
///   1.0 — #1051 B-5: initial implementation
struct BrowseArchivesTests {

    // MARK: Fixtures

    /// A tiny usage index: two categories over three volumes. Volume note counts are the
    /// share denominators; category rows use the k/v/n wire shape.
    private func fixture() throws -> CollectionUsageIndex {
        let json = """
        {
          "schemaVersion": 1,
          "generated": "2026-08-23",
          "volumes": ["frus-a", "frus-b", "frus-c"],
          "volumeNoteCounts": [100, 50, 0],
          "collectionIds": [],
          "classKeys": [],
          "categories": ["centralDecimalFile", "lotFile"],
          "collections": [],
          "classes": [],
          "volumeCategories": [
            {"k": 0, "v": [0, 1], "n": [80, 10]},
            {"k": 1, "v": [1], "n": [40]}
          ],
          "coverage": {
            "volumesScanned": 3,
            "volumesWithNotes": 2,
            "noteCount": 130,
            "notesInACollection": 40,
            "notesWithAClassKey": 90,
            "authorityCollectionCount": 5,
            "authorityCollectionsReached": 2
          }
        }
        """
        return try JSONDecoder().decode(CollectionUsageIndex.self, from: Data(json.utf8))
    }

    // MARK: The forward accessor

    @Test func documentsByVolumeForCategoryPairsTheWireArrays() throws {
        let usage = try fixture()
        #expect(usage.documentsByVolume(forCategory: "centralDecimalFile")
                == ["frus-a": 80, "frus-b": 10])
        #expect(usage.documentsByVolume(forCategory: "lotFile") == ["frus-b": 40])
        #expect(usage.documentsByVolume(forCategory: "not-a-category").isEmpty)
    }

    // MARK: Doors

    @Test func categoryDoorsCarryLiveCountsInArtifactOrder() throws {
        let doors = ArchivesAxis.categoryDoors(usage: try fixture())
        #expect(doors.map(\.slug) == ["centralDecimalFile", "lotFile"])
        #expect(doors[0].volumeCount == 2)
        #expect(doors[0].docCount == 90)
        #expect(doors[1].volumeCount == 1)
        #expect(doors[1].docCount == 40)
        // The display vocabulary is the shipped localized one, not the slug.
        #expect(doors[0].name == SourceProvenanceCategory.centralDecimalFile.displayName)
    }

    // MARK: The drill spec

    @Test func specOrdersByDocCountDescending_idOrderWouldInvertIt() throws {
        // frus-a (80 docs) must lead frus-b (10) — and the ids ascend WITH the counts
        // here, so flip the fixture: use lotFile+decimal reversed? The decimal row's ids
        // ascend with counts descending already (frus-a 80 > frus-b 10), so an id sort
        // would produce the SAME order. Assert on a category where they differ: build the
        // inversion by checking the accessory-bearing spec of centralDecimalFile AND a
        // hand-flipped row below.
        let usage = try fixture()
        let spec = ArchivesAxis.spec(forCategory: "centralDecimalFile", usage: usage)
        #expect(spec.volumeIds == ["frus-a", "frus-b"])
        #expect(spec.axisKey == "archives:category:centralDecimalFile")
    }

    @Test func specOrderIsCountDriven_provedByAFlippedFixture() throws {
        // Ids DESCEND against counts: frus-b holds more than frus-a, so an id sort gives
        // [frus-a, frus-b] and only the count rule gives [frus-b, frus-a].
        let json = """
        {
          "schemaVersion": 1, "generated": "x",
          "volumes": ["frus-a", "frus-b"],
          "volumeNoteCounts": [10, 10],
          "collectionIds": [], "classKeys": [],
          "categories": ["lotFile"],
          "collections": [], "classes": [],
          "volumeCategories": [{"k": 0, "v": [0, 1], "n": [1, 9]}],
          "coverage": {"volumesScanned": 2, "volumesWithNotes": 2, "noteCount": 20,
                       "notesInACollection": 10, "notesWithAClassKey": 10,
                       "authorityCollectionCount": 1, "authorityCollectionsReached": 1}
        }
        """
        let usage = try JSONDecoder().decode(CollectionUsageIndex.self, from: Data(json.utf8))
        let spec = ArchivesAxis.spec(forCategory: "lotFile", usage: usage)
        #expect(spec.volumeIds == ["frus-b", "frus-a"])
    }

    @Test func accessoryShareUsesTheVolumeNoteDenominator() throws {
        let usage = try fixture()
        let spec = ArchivesAxis.spec(forCategory: "centralDecimalFile", usage: usage)
        // frus-a: 80 of its 100 sourced docs → 80%.
        #expect(spec.accessories["frus-a"]?.contains("80") == true)
        #expect(spec.accessories["frus-a"]?.contains("80%") == true)
        // frus-b: 10 of 50 → 20%.
        #expect(spec.accessories["frus-b"]?.contains("20%") == true)
    }

    @Test func captionsComputeFromTheCoverageBlock() throws {
        let usage = try fixture()
        // 40 of 130 notes in a collection → 31%.
        #expect(ArchivesAxis.collectionSharePercent(coverage: usage.coverage) == 31)
        let caption = ArchivesAxis.indexCaption(coverage: usage.coverage)
        #expect(caption.contains(130.formatted()))
        #expect(caption.contains("2 of 3"))
        #expect(caption.contains("31%"))
        // volumesScanned - volumesWithNotes = 1 noteless volume, disclosed.
        #expect(caption.contains("1 volumes") || caption.contains("1 volume"))
    }

    // MARK: The live bundled artifact

    @Test func bundledArtifactSupportsTheAxisPremises() throws {
        let usage = try #require(CollectionUsageIndexStore.shared,
                                 "bundled collection-usage-index.json must decode")
        // Every artifact slug maps into the shipped display vocabulary — the join the
        // doors depend on. An unknown future slug degrades to itself, but TODAY none may.
        for slug in usage.categories {
            #expect(SourceProvenanceCategory(rawValue: slug) != nil,
                    "artifact category '\(slug)' has no SourceProvenanceCategory case")
        }
        // The categories PARTITION the notes: door doc counts must sum to the coverage
        // block's noteCount exactly (the generator's verified invariant, re-pinned here
        // so a regenerated artifact cannot silently break the doors' arithmetic).
        let doors = ArchivesAxis.categoryDoors(usage: usage)
        #expect(doors.reduce(0) { $0 + $1.docCount } == usage.coverage.noteCount)
        // No door reaches more volumes than carry notes at all.
        for door in doors {
            #expect(door.volumeCount <= usage.coverage.volumesWithNotes,
                    "\(door.slug) reaches \(door.volumeCount) volumes against \(usage.coverage.volumesWithNotes) with notes")
        }
    }
}
