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

// MARK: - AdministrationAxisTests

/// Pure-logic tests for the Administrations browse axis (#1051 B-2, A-3): the term text,
/// the dual-membership map, and the R-1 drill spec — order preservation, the accessory
/// math, and the "Also under" notes — plus one guard over the real bundled artifact.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
@MainActor
struct AdministrationAxisTests {

    // MARK: Fixtures

    private func profile(
        id: String, number: Int, president: String,
        start: String = "1945-04-12", end: String? = "1953-01-20",
        volumes: [AdministrationVolume]
    ) -> AdministrationProfile {
        AdministrationProfile(
            id: id, number: number, president: president, party: "Democratic",
            start: start, end: end,
            pointDocCount: volumes.reduce(0) { $0 + $1.pointDocs },
            rangeDocCount: volumes.reduce(0) { $0 + $1.rangeDocs },
            volumeCount: volumes.count, volumeCountPointOnly: volumes.count,
            coverageEarliest: 1945, coverageLatest: 1953, volumes: volumes
        )
    }

    private func fixtureIndex() -> AdministrationProfilesIndex {
        // Truman's volumes arrive in the ARTIFACT's order (largest share first); the ids
        // are chosen so an id sort would INVERT it — only order preservation yields the
        // expected drill order.
        let truman = profile(id: "truman", number: 33, president: "Harry S. Truman", volumes: [
            AdministrationVolume(volumeId: "frus-z-big", pointDocs: 300, rangeDocs: 10),
            AdministrationVolume(volumeId: "frus-m-mid", pointDocs: 100, rangeDocs: 0),
            AdministrationVolume(volumeId: "frus-a-small", pointDocs: 5, rangeDocs: 0),
        ])
        let eisenhower = profile(id: "eisenhower", number: 34, president: "Dwight D. Eisenhower",
                                 start: "1953-01-20", end: "1961-01-20", volumes: [
            AdministrationVolume(volumeId: "frus-m-mid", pointDocs: 40, rangeDocs: 0),
        ])
        return AdministrationProfilesIndex(
            schemaVersion: 1, generated: "2026-08-23",
            totalDocumentsPointDated: 445, totalDocumentsRangeDated: 10,
            totalDocumentsUndated: 0, volumesCovered: 3,
            administrations: [truman, eisenhower],
            volumeTotals: [
                "frus-z-big": VolumeTotals(pointDocs: 600, rangeDocs: 20, undatedDocs: 0),
                "frus-m-mid": VolumeTotals(pointDocs: 190, rangeDocs: 10, undatedDocs: 0),
                "frus-a-small": VolumeTotals(pointDocs: 5, rangeDocs: 0, undatedDocs: 0),
            ]
        )
    }

    // MARK: Term text

    @Test func termTextSpansYearsAndHandlesSittingTerm() {
        #expect(AdministrationAxis.termText(start: "1945-04-12", end: "1953-01-20") == "1945\u{2013}1953")
        #expect(AdministrationAxis.termText(start: "2025-01-20", end: nil).hasPrefix("2025"))
        #expect(AdministrationAxis.termText(start: "2025-01-20", end: nil) != "2025\u{2013}2025")
    }

    // MARK: Spec

    @Test func specPreservesArtifactOrder_idSortWouldInvertIt() {
        let index = fixtureIndex()
        let spec = AdministrationAxis.spec(for: index.administrations[0], index: index,
                                           membership: AdministrationAxis.membershipMap(for: index))
        #expect(spec.volumeIds == ["frus-z-big", "frus-m-mid", "frus-a-small"])
        #expect(spec.axisKey == "administration:truman")
        #expect(spec.title == "Harry S. Truman")
    }

    @Test func accessoryCountsAnyDatedDocumentAndSharesAgainstVolumeTotals() {
        // frus-z-big: 300 point + 10 range = 310 docs of 620 total → exactly 50.0%.
        let index = fixtureIndex()
        let spec = AdministrationAxis.spec(for: index.administrations[0], index: index,
                                           membership: AdministrationAxis.membershipMap(for: index))
        let accessory = try! #require(spec.accessories["frus-z-big"])
        #expect(accessory.contains("310"))
        #expect(accessory.contains("50.0"))
    }

    @Test func dualMembershipGetsAnAlsoUnderNote_exclusiveVolumeGetsNone() {
        let index = fixtureIndex()
        let membership = AdministrationAxis.membershipMap(for: index)
        let trumanSpec = AdministrationAxis.spec(for: index.administrations[0], index: index,
                                                 membership: membership)
        let note = try! #require(trumanSpec.notes["frus-m-mid"])
        #expect(note.contains("Eisenhower"))
        #expect(!note.contains("Truman"))
        #expect(trumanSpec.notes["frus-z-big"] == nil)
    }

    @Test func membershipMapListsAdministrationsInPresidencyOrder() {
        let index = fixtureIndex()
        let map = AdministrationAxis.membershipMap(for: index)
        #expect(map["frus-m-mid"]?.map(\.id) == ["truman", "eisenhower"])
        #expect(map["frus-a-small"]?.map(\.id) == ["truman"])
    }

    // MARK: The real bundled artifact

    @Test func bundledIndexSupportsTheAxisPremises() throws {
        let store = AdministrationProfilesStore()
        let index = try #require(store.index, "bundled administration-profiles-index.json must decode")
        // Presidency order is the roster order.
        let numbers = index.administrations.map(\.number)
        #expect(numbers == numbers.sorted())
        #expect(numbers.first == 16)   // Lincoln
        // The any-overlap disclosure's premise: memberships sum past the corpus size.
        let membershipSum = index.administrations.reduce(0) { $0 + $1.volumeCount }
        #expect(membershipSum > index.volumeTotals.count)
        // The disabled-row case exists: post-corpus administrations carry zero volumes.
        #expect(index.administrations.contains { $0.volumeCount == 0 })
        // Every drill id resolves against volumeTotals (the accessory's denominator).
        for profile in index.administrations {
            for volume in profile.volumes {
                #expect(index.volumeTotals[volume.volumeId] != nil,
                        "\(profile.id) names \(volume.volumeId) with no volumeTotals row")
            }
        }
    }
}

// MARK: - EditorIndexGroupingTests

/// Pure-logic tests for the Editors browse axis (#1051 B-2, A-4): the two normalization
/// layers, the fold that must NOT over-merge, the row ordering contracts, and the letter
/// sections — plus guards over the real bundled manifest.
///
/// Version history:
///   1.0 — #1051 B-2: initial implementation
struct EditorIndexGroupingTests {

    // MARK: Fixtures

    private func entry(
        id: String, editors: [String],
        publicationDate: String? = "2000"
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: "1969-76",
            title: "Foreign Relations of the United States, Volume I, Fixture",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: publicationDate, status: .published,
            editors: editors, generalEditor: "General Editor Excluded",
            documentCount: 0, sizeBytes: 0, tags: []
        )
    }

    // MARK: Mechanical normalization

    @Test func mechanicalNormalizationFoldsPunctuationVariants() {
        #expect(EditorIndexGrouping.mechanicallyNormalized("Robert J . McMahon") == "Robert J. McMahon")
        #expect(EditorIndexGrouping.mechanicallyNormalized("E.R. Perkins") == "E. R. Perkins")
        #expect(EditorIndexGrouping.mechanicallyNormalized("Henry P. Beers.") == "Henry P. Beers")
        #expect(EditorIndexGrouping.mechanicallyNormalized("  Joan   M.  Lee ") == "Joan M. Lee")
    }

    @Test func mechanicalNormalizationSparesInitialsAndSuffixes() {
        #expect(EditorIndexGrouping.mechanicallyNormalized("William F. Sanford, Jr.")
                == "William F. Sanford, Jr.")
        #expect(EditorIndexGrouping.mechanicallyNormalized("N. O. Sappington") == "N. O. Sappington")
    }

    // MARK: Aliases

    @Test func aliasFoldRunsAfterMechanicalNormalization() {
        // "E.B. Perkins" needs BOTH layers: mechanical → "E. B. Perkins", alias → the
        // canonical "E. R. Perkins".
        #expect(EditorIndexGrouping.canonicalName("E.B. Perkins") == "E. R. Perkins")
        #expect(EditorIndexGrouping.canonicalName("Fredrick Aandahl") == "Frederick Aandahl")
        #expect(EditorIndexGrouping.canonicalName("William Slany") == "William Z. Slany")
    }

    @Test func thePhillipsPairStaysSplit() {
        // The over-merge guard: same surname, same first initial, two different people.
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-a", editors: ["Shirley L. Phillips"]),
            entry(id: "frus-b", editors: ["Steven E. Phillips"]),
        ])
        #expect(rows.count == 2)
        #expect(EditorIndexGrouping.aliases.keys.allSatisfy { !$0.contains("Phillips") })
    }

    // MARK: Rows

    @Test func rowsFoldVariantsAndCountSpellings() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-a", editors: ["E. R. Perkins"]),
            entry(id: "frus-b", editors: ["E. Ralph Perkins"]),
            entry(id: "frus-c", editors: ["E.R. Perkins"]),
        ])
        #expect(rows.count == 1)
        #expect(rows[0].name == "E. R. Perkins")
        #expect(rows[0].volumeIds.count == 3)
        // Three RAW spellings folded (two only after the mechanical layer).
        #expect(rows[0].variantCount == 3)
    }

    @Test func rowVolumesOrderByPublicationYear_idOrderWouldInvertIt() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-a", editors: ["Joan M. Lee"], publicationDate: "1998"),
            entry(id: "frus-b", editors: ["Joan M. Lee"], publicationDate: "1972"),
            entry(id: "frus-c", editors: ["Joan M. Lee"], publicationDate: "1985"),
        ])
        #expect(rows[0].volumeIds == ["frus-b", "frus-c", "frus-a"])
    }

    @Test func rowVolumesTieBreakByVolumeId_yearsEqualSoOnlyIdDecides() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-z", editors: ["Joan M. Lee"], publicationDate: "1985"),
            entry(id: "frus-a", editors: ["Joan M. Lee"], publicationDate: "1985"),
        ])
        #expect(rows[0].volumeIds == ["frus-a", "frus-z"])
    }

    // MARK: Sections

    @Test func sectionsFileBySurnameInitialWithSuffixesSkipped() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-a", editors: ["William Z. Slany"]),
            entry(id: "frus-b", editors: ["C. Thomas Thorne, Jr."]),
            entry(id: "frus-c", editors: ["Frederick Aandahl"]),
        ])
        let sections = EditorIndexGrouping.sections(from: rows, query: "")
        #expect(sections.map(\.letter) == ["A", "S", "T"])
    }

    @Test func queryFiltersByName() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-a", editors: ["William Z. Slany"]),
            entry(id: "frus-b", editors: ["Joan M. Lee"]),
        ])
        let sections = EditorIndexGrouping.sections(from: rows, query: "slany")
        #expect(sections.flatMap(\.editors).map(\.name) == ["William Z. Slany"])
        #expect(EditorIndexGrouping.sections(from: rows, query: "zzz").isEmpty)
    }

    // MARK: The drill spec

    @Test func specKeysOnCanonicalNameAndKeepsPublicationOrder() {
        let rows = EditorIndexGrouping.rows(from: [
            entry(id: "frus-b", editors: ["William Slany"], publicationDate: "1972"),
            entry(id: "frus-a", editors: ["William Z. Slany"], publicationDate: "1998"),
        ])
        let spec = EditorIndexGrouping.spec(for: rows[0])
        #expect(spec.axisKey == "editor:William Z. Slany")
        #expect(spec.volumeIds == ["frus-b", "frus-a"])
        #expect(spec.caption?.contains("publication order") == true)
    }

    // MARK: The real bundled manifest

    @Test func bundledManifestFoldsToOneRowPerPerson() throws {
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let rows = EditorIndexGrouping.rows(from: entries)
        // Every curated cluster folds to one row; the two Phillipses stay two.
        #expect(rows.filter { $0.name.contains("Slany") }.count == 1)
        #expect(rows.filter { $0.name.contains("Perkins") }.count == 1)
        #expect(rows.filter { $0.name.contains("Aandahl") }.count == 1)
        #expect(rows.filter { $0.name.contains("Phillips") }.count == 2)
        // No alias VARIANT survives as a row of its own.
        let names = Set(rows.map(\.name))
        for variant in EditorIndexGrouping.aliases.keys {
            #expect(!names.contains(variant), "alias variant '\(variant)' escaped the fold")
        }
        // The corpus-shaped sanity band: ~170 people from 552 volumes.
        #expect(rows.count > 140 && rows.count < 220)
    }
}
