// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ArchivalEraBandTests

/// The era-band rollup (#765). Every claim here is about the band axis being a *view of*
/// ``CollectionRelations/coverageEras`` rather than a second set of boundaries — which is the
/// one property that keeps this surface and #762's collection timeline from disagreeing.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — era bands")
struct ArchivalEraBandTests {

    @Test("The bands tile the coverage-era axis exactly once")
    func bandsTileTheAxis() {
        var covered: [Int] = []
        for band in ArchivalEraBand.all {
            #expect(band.eraIndices.lowerBound <= band.eraIndices.upperBound)
            covered.append(contentsOf: band.eraIndices)
        }
        #expect(covered == Array(CollectionRelations.coverageEras.indices), """
            The bands cover \(covered) but the era axis is \
            \(Array(CollectionRelations.coverageEras.indices)). A gap silently drops volumes \
            from every ranking; an overlap counts them twice.
            """)
    }

    @Test("Each band's index is its position, so `all[i].index == i`")
    func indicesMatchPositions() {
        for (position, band) in ArchivalEraBand.all.enumerated() {
            #expect(band.index == position)
        }
    }

    @Test("A band's years are read off its eras, never written twice")
    func yearsComeFromTheEras() {
        for band in ArchivalEraBand.all {
            let first = CollectionRelations.coverageEras[band.eraIndices.lowerBound]
            let last = CollectionRelations.coverageEras[band.eraIndices.upperBound]
            #expect(band.startYear == first.startYear)
            #expect(band.endYear == last.endYear)
        }
        // The rollup exists because the design's own boundaries are not all expressible: three
        // of its four are, and 1946 is not. Pin the three that are, so a future edit that moves
        // an era boundary under them fails here rather than silently re-labelling a chart.
        let titles = ArchivalEraBand.all.map(\.title)
        #expect(titles.contains("1961–1968"))
        #expect(titles.contains("1969–1976"))
        #expect(titles.first == "Through 1947", """
            The first band is \(titles.first ?? "nil"). It is deliberately open-ended: it spans \
            1861–1947, and writing that on a segment would imply an evenly covered span when it \
            actually holds four nineteenth-century decades of retrospective compilations.
            """)
    }

    @Test("Every coverage midpoint lands in exactly one band, including out-of-range years")
    func everyYearResolves() {
        for year in stride(from: 1600, through: 2100, by: 1) {
            let band = ArchivalEraBand.band(forMidpointYear: year)
            #expect(band.contains(midpointYear: year),
                    "year \(year) resolved to a band that does not claim it")
            let claiming = ArchivalEraBand.all.filter { $0.contains(midpointYear: year) }
            #expect(claiming.count == 1, "year \(year) is claimed by \(claiming.count) bands")
        }
        // The clamp is inherited from the era axis and matters: `frus1872p2v5` prints a
        // retrospective annex reaching back to 1620, for a midpoint of 1746.
        #expect(ArchivalEraBand.band(forMidpointYear: 1746).index == 0)
        #expect(ArchivalEraBand.band(forMidpointYear: 2100).index == ArchivalEraBand.all.count - 1)
    }
}

// MARK: - ArchivalRepositoryCategoryTests

/// The four-way custodian bucket, tested against the shipped authority rather than a fixture —
/// the rule's whole job is to be right about real repository keywords.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — custodian categories")
struct ArchivalRepositoryCategoryTests {

    private func authority() throws -> [AuthorityCollectionRecord] {
        try #require(CollectionAuthorityStore.shared?.collections, """
            collection-authority.json must decode from the app bundle.
            """)
    }

    @Test("Presidential custody wins over the filing system, and Nixon is one of them")
    func presidentialCustodyFirst() {
        let nixon = AuthorityCollectionRecord(id: "txt:nixon|nsc file", name: "NSC Files",
                                              repository: "Nixon")
        #expect(ArchivalRepositoryCategory.from(nixon) == .presidentialLibrary, """
            "Nixon" is how the corpus cites the Nixon presidential materials, and it carries NSC \
            Files — 7,056 documents, the second-largest collection in the series and the biggest \
            single bar of the 1969–1976 era. A suffix-only rule would colour it "other".
            """)
        let library = AuthorityCollectionRecord(id: "txt:johnson library|national security file",
                                                name: "National Security File",
                                                repository: "Johnson Library")
        #expect(ArchivalRepositoryCategory.from(library) == .presidentialLibrary)
        // Custody outranks the lot key, and the order of the tests is what enforces it.
        let libraryHeldLot = AuthorityCollectionRecord(id: "lot:64D199", name: "Some Lot",
                                                       repository: "Ford Library",
                                                       lotFileNorm: "64D199")
        #expect(ArchivalRepositoryCategory.from(libraryHeldLot) == .presidentialLibrary)
    }

    @Test("Library of Congress is not a presidential library")
    func libraryOfCongressIsOther() {
        // It is the one repository in the shipped set that contains the word "Library" without
        // being one — 34 records, including Manuscript Division with 985 documents.
        let loc = AuthorityCollectionRecord(id: "txt:library of congress|manuscript division",
                                            name: "Manuscript Division",
                                            repository: "Library of Congress")
        #expect(ArchivalRepositoryCategory.from(loc) == .otherInstitution)
    }

    @Test("A lot key without presidential custody is a State lot file")
    func lotKeyIsLot() {
        let lot = AuthorityCollectionRecord(id: "lot:63D351", name: "S/S–NSC Files: Lot 63 D 351",
                                            repository: "Department of State",
                                            lotFileNorm: "63D351")
        #expect(ArchivalRepositoryCategory.from(lot) == .lotFile)
    }

    @Test("An unattributed record is other, never State by default")
    func unattributedIsOther() {
        let orphan = AuthorityCollectionRecord(id: "txt:|io file", name: "IO Files")
        #expect(ArchivalRepositoryCategory.from(orphan) == .otherInstitution, """
            661 documents ride "IO Files", which asserts no repository. Defaulting an \
            unattributed record to the Department of State would put words in the corpus's mouth.
            """)
    }

    @Test("Every shipped record classifies, and the four buckets are all populated")
    func shippedDistribution() throws {
        let records = try authority()
        var counts: [ArchivalRepositoryCategory: Int] = [:]
        for record in records {
            counts[ArchivalRepositoryCategory.from(record), default: 0] += 1
        }
        #expect(counts.values.reduce(0, +) == records.count)
        for category in ArchivalRepositoryCategory.ordered {
            #expect((counts[category] ?? 0) > 0, "\(category) is empty on the shipped authority")
        }
        // Measured 2026-08-09 on the 2026-08-06 authority. Pinned as a band rather than exact
        // values, so a re-clustering that shifts a few dozen records does not fail the suite but
        // one that collapses a bucket does.
        #expect((counts[.lotFile] ?? 0) > 1_500, "lot files: \(counts[.lotFile] ?? 0), expected ~1,727")
        #expect((counts[.presidentialLibrary] ?? 0) > 350,
                "libraries: \(counts[.presidentialLibrary] ?? 0), expected ~451")
    }

    @Test("The umbrella record is the one the design names, and it really does dwarf the rest")
    func umbrellaIsTheBiggest() throws {
        let records = try authority()
        let umbrella = try #require(
            records.first { $0.id == ArchivalCollectionsData.umbrellaCollectionId },
            """
            The Central Files umbrella id is not in the shipped authority — the default filter \
            would hide nothing and the disclosure line would never appear.
            """)
        #expect(umbrella.name == "Central Files")
        #expect(umbrella.volumeIds.count > 100,
                "the umbrella cites \(umbrella.volumeIds.count) volumes; the copy says 157")
        let runnerUp = records
            .filter { $0.id != umbrella.id }
            .map(\.volumeIds.count).max() ?? 0
        #expect(umbrella.volumeIds.count > runnerUp,
                "the umbrella is no longer the widest-cited record; the hiding rationale changed")
    }
}

// MARK: - ArchivalCollectionsDataTests

/// The corpus-wide Collections derivation (#765), driven both by synthetic corpora — where the
/// expected answer is arithmetic — and by the shipped artifacts, where the claims the UI copy
/// makes have to actually hold.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — collections derivation")
struct ArchivalCollectionsDataTests {

    // MARK: - Fixtures

    /// A volume in the given band, spanning one year.
    private func coverage(_ pairs: [(String, Int)]) -> [String: ArchivalVolumeCoverage] {
        var result: [String: ArchivalVolumeCoverage] = [:]
        for (id, year) in pairs {
            result[id] = ArchivalVolumeCoverage(firstYear: year, lastYear: year)
        }
        return result
    }

    private func usage(volumes: [String], collections: [(String, [Int], [Int])],
                       classes: [(String, [Int], [Int])] = []) throws -> CollectionUsageIndex {
        let collectionIds = collections.map(\.0).sorted()
        let classKeys = classes.map(\.0).sorted()
        func rows(_ source: [(String, [Int], [Int])], keys: [String]) -> [[String: Any]] {
            source.compactMap { key, vols, counts in
                guard let index = keys.firstIndex(of: key) else { return nil }
                return ["k": index, "v": vols, "n": counts]
            }
        }
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "generated": "2026-08-09",
            "volumes": volumes,
            "volumeNoteCounts": volumes.map { _ in 0 },
            "collectionIds": collectionIds,
            "classKeys": classKeys,
            "categories": [],
            "collections": rows(collections, keys: collectionIds),
            "classes": rows(classes, keys: classKeys),
            "volumeCategories": [],
            "coverage": [
                "volumesScanned": volumes.count, "volumesWithNotes": volumes.count,
                "noteCount": 0, "notesInACollection": 0, "notesWithAClassKey": 0,
                "authorityCollectionCount": collectionIds.count,
                "authorityCollectionsReached": collectionIds.count,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(CollectionUsageIndex.self, from: data)
    }

    // MARK: - Banding

    @Test("Documents and volumes are attributed to the band their volume's midpoint falls in")
    func bandAttribution() throws {
        // v1 covers 1950 (band 1), v2 covers 1970 (band 3). One collection cites both.
        let spans = coverage([("v1", 1950), ("v2", 1970)])
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One",
                                               repository: "Department of State",
                                               lotFileNorm: "1", volumeIds: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [("lot:1", [0, 1], [7, 30])])
        let data = ArchivalCollectionsData.make(authority: [record], usage: index,
                                                coverage: spans)

        let early = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                 weight: .documents, hidingUmbrella: true)
        #expect(early.rows.map(\.value) == [7])
        let late = data.ranking(band: ArchivalEraBand.all[3], lens: .namedCollections,
                                weight: .documents, hidingUmbrella: true)
        #expect(late.rows.map(\.value) == [30])
        #expect(early.bandVolumeCount == 1)
        // A band with no volumes at all yields nothing rather than a zero-valued bar.
        let empty = data.ranking(band: ArchivalEraBand.all[0], lens: .namedCollections,
                                 weight: .documents, hidingUmbrella: true)
        #expect(empty.rows.isEmpty)
        #expect(empty.bandVolumeCount == 0)
    }

    /// One manifest entry, for the shared coverage builder's own tests.
    private func manifestEntry(_ id: String, earliest: String, latest: String)
        -> VolumeManifestEntry
    {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: "s", title: id,
            dateRange: DateRange(earliest: earliest, latest: latest),
            publicationDate: nil, status: .published, editors: [], generalEditor: nil,
            documentCount: 0, sizeBytes: 0, tags: [])
    }

    // MARK: - Multi-band ranking (#835)

    @Test("One band through the multi-band path is the single-band ranking, exactly")
    func multiBandPassThroughIsIdentity() throws {
        // The single-band call is now EXPRESSED as `ranking(bands: [band], …)`, so this is what
        // makes that re-expression safe: if the merge changed anything for one band — ordering,
        // labels, denominators — every existing caller would silently shift.
        let spans = coverage([("v1", 1900), ("v2", 1950), ("v3", 1965), ("v4", 1972), ("v5", 1985)])
        let a = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                          volumeIds: ["v1", "v2", "v3", "v4", "v5"])
        let b = AuthorityCollectionRecord(id: "lot:2", name: "Lot Two", lotFileNorm: "2",
                                          volumeIds: ["v2", "v4"])
        let index = try usage(volumes: ["v1", "v2", "v3", "v4", "v5"],
                              collections: [("lot:1", [0, 1, 2, 3, 4], [3, 9, 4, 11, 6]),
                                            ("lot:2", [1, 3], [5, 8])])
        let data = ArchivalCollectionsData.make(authority: [a, b], usage: index, coverage: spans)

        for band in ArchivalEraBand.all {
            for weight in ArchivalWeight.allCases {
                let single = data.ranking(band: band, lens: .namedCollections, weight: weight,
                                          hidingUmbrella: true, limit: .max)
                let viaSet = data.ranking(bands: [band], lens: .namedCollections, weight: weight,
                                          hidingUmbrella: true, limit: .max)
                #expect(single.rows == viaSet.rows, "\(band.title) / \(weight.title) diverged")
                #expect(single.bandVolumeCount == viaSet.bandVolumeCount)
                #expect(single.bandNoteCount == viaSet.bandNoteCount)
                #expect(single.unitsReached == viaSet.unitsReached)
            }
        }
    }

    @Test("Merging every band sums the per-band values, under BOTH weights")
    func multiBandSummationIsExact() throws {
        // The property the whole multi-band API rests on: `make` writes one band per volume, so
        // the bands PARTITION the corpus and a unit's citing volumes in two bands are disjoint.
        // Under Volumes this is the difference between a correct total and the double-count that
        // folding class leaves within one band really does produce.
        let spans = coverage([("v1", 1900), ("v2", 1950), ("v3", 1965), ("v4", 1972), ("v5", 1985)])
        let a = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                          volumeIds: ["v1", "v2", "v3", "v4", "v5"])
        let b = AuthorityCollectionRecord(id: "lot:2", name: "Lot Two", lotFileNorm: "2",
                                          volumeIds: ["v2", "v4"])
        let index = try usage(volumes: ["v1", "v2", "v3", "v4", "v5"],
                              collections: [("lot:1", [0, 1, 2, 3, 4], [3, 9, 4, 11, 6]),
                                            ("lot:2", [1, 3], [5, 8])])
        let data = ArchivalCollectionsData.make(authority: [a, b], usage: index, coverage: spans)

        for weight in ArchivalWeight.allCases {
            // Expected totals accumulated from the FIVE single-band rankings, so the assertion is
            // not the merged method checked against itself.
            var expected: [String: Int] = [:]
            for band in ArchivalEraBand.all {
                for row in data.ranking(band: band, lens: .namedCollections, weight: weight,
                                        hidingUmbrella: true, limit: .max).rows {
                    expected[row.id, default: 0] += row.value
                }
            }
            let merged = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                      weight: weight, hidingUmbrella: true, limit: .max)
            #expect(Dictionary(uniqueKeysWithValues: merged.rows.map { ($0.id, $0.value) })
                    == expected, "\(weight.title) did not sum across the bands")
            #expect(merged.bandVolumeCount == 5, "every volume is counted once")
        }

        // Spelled out, so the arithmetic is visible rather than inferred: lot:1 cites all five
        // volumes and lot:2 cites two, in two DIFFERENT bands.
        let volumes = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                   weight: .volumes, hidingUmbrella: true, limit: .max)
        #expect(volumes.rows.first(where: { $0.id == "lot:1" })?.value == 5)
        #expect(volumes.rows.first(where: { $0.id == "lot:2" })?.value == 2)
        let documents = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                     weight: .documents, hidingUmbrella: true, limit: .max)
        #expect(documents.rows.first(where: { $0.id == "lot:1" })?.value == 33)
        #expect(documents.rows.first(where: { $0.id == "lot:2" })?.value == 13)
    }

    @Test("A duplicated band is not counted twice")
    func multiBandDeduplicates() throws {
        let spans = coverage([("v1", 1950)])
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["v1"])
        let index = try usage(volumes: ["v1"], collections: [("lot:1", [0], [7])])
        let data = ArchivalCollectionsData.make(authority: [record], usage: index, coverage: spans)
        let band = ArchivalEraBand.all[1]
        let doubled = data.ranking(bands: [band, band], lens: .namedCollections,
                                   weight: .documents, hidingUmbrella: true)
        #expect(doubled.rows.map(\.value) == [7], "a repeated band doubled every figure")
        #expect(doubled.bandVolumeCount == 1)
        #expect(doubled.bandNoteCount == data.ranking(band: band, lens: .namedCollections,
                                                      weight: .documents,
                                                      hidingUmbrella: true).bandNoteCount)
    }

    @Test("Two records sharing a name survive the merge with distinct labels")
    func multiBandDisambiguatesAcrossBands() throws {
        // THE reason the merge lives inside the type. Each record tops a DIFFERENT band, so they
        // never collide in a single-band ranking and only meet once the bands are combined —
        // and Swift Charts draws two bars sharing a label as one.
        let spans = coverage([("v-early", 1950), ("v-late", 1972)])
        let early = AuthorityCollectionRecord(id: "txt:truman library|white house central files",
                                              name: "White House Central Files",
                                              repository: "Truman Library",
                                              volumeIds: ["v-early"])
        let late = AuthorityCollectionRecord(id: "txt:nixon library|white house central files",
                                             name: "White House Central Files",
                                             repository: "Nixon Library",
                                             volumeIds: ["v-late"])
        let data = ArchivalCollectionsData.make(authority: [early, late], usage: nil,
                                                coverage: spans)
        let merged = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                  weight: .volumes, hidingUmbrella: true, limit: .max)
        #expect(merged.rows.count == 2, "one of the two collections vanished in the merge")
        #expect(Set(merged.rows.map(\.label)).count == 2, """
            Both rows drew the same label. A chart would silently merge them into one bar, and \
            a reader would see one collection where the corpus has two.
            """)
        for row in merged.rows { #expect(row.name == "White House Central Files") }
    }

    @Test("The umbrella disclosure adds up across the merged bands")
    func multiBandUmbrellaValue() throws {
        let spans = coverage([("v1", 1950), ("v2", 1972)])
        let umbrella = AuthorityCollectionRecord(
            id: "txt:department of state|central file", name: "Central File",
            repository: "Department of State", volumeIds: ["v1", "v2"])
        let other = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                              volumeIds: ["v1"])
        let data = ArchivalCollectionsData.make(authority: [umbrella, other], usage: nil,
                                                coverage: spans)
        let hidden = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                  weight: .volumes, hidingUmbrella: true, limit: .max)
        #expect(hidden.hiddenUmbrellaValue == 2, "the withheld figure must cover every band shown")
        #expect(!hidden.rows.contains { $0.id == ArchivalCollectionsData.umbrellaCollectionId })
        let shown = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                 weight: .volumes, hidingUmbrella: false, limit: .max)
        #expect(shown.hiddenUmbrellaValue == nil)
        #expect(shown.rows.contains { $0.id == ArchivalCollectionsData.umbrellaCollectionId })
    }

    // MARK: - Guide-card parity (#835)

    @Test("The guide card's ranking is the instrument's ranking, over one real subseries")
    func guideCardMatchesTheInstrument() throws {
        // THE DRIFT GUARD. It is only meaningful because the two surfaces now reach the ranking
        // by DIFFERENT routes: the dashboard calls `ranking(bands:)` with the bands its year
        // range overlaps, the Collections mode calls `ranking(band:)`. Both are re-expressed
        // through one implementation, and this asserts that re-expression holds over the real
        // bundled manifest rather than a fixture.
        let manifest = try #require(Self.bundledManifest(), "manifest.json is not readable")
        let subseries = try #require(
            Dictionary(grouping: manifest, by: \.subseries)
                .filter { $0.value.count >= 4 }
                .max(by: { $0.value.count < $1.value.count })?.value,
            "no subseries with enough volumes to test")
        let ids = Set(subseries.map(\.volumeId))

        let coverage = ArchivalVolumeCoverage.map(from: manifest, limitedTo: ids)
        #expect(!coverage.isEmpty, "the scope resolved to no dated volumes")
        let data = ArchivalCollectionsData.make(
            authority: CollectionAuthorityStore.shared?.collections ?? [],
            usage: CollectionUsageIndexStore.shared, coverage: coverage)

        // The CARD's own rule, called — not a predicate restated in the test, which would pass
        // with the card pinned to one band.
        let bands = ArchivalEraBand.bands(overlapping: 1861, through: 1993)
        #expect(bands.count == ArchivalEraBand.all.count,
                "the default range must cover the whole axis, or the card hides eras silently")

        // Band by band, the card's route and the instrument's must agree exactly.
        for band in ArchivalEraBand.all {
            let instrument = data.ranking(band: band, lens: .namedCollections, weight: .documents,
                                          hidingUmbrella: true, limit: ArchivalCollectionsData.rowCap)
            let card = data.ranking(bands: [band], lens: .namedCollections, weight: .documents,
                                    hidingUmbrella: true, limit: ArchivalCollectionsData.rowCap)
            #expect(instrument.rows == card.rows, """
                \(band.title): the guide card and the Collections mode drew different rows for \
                one scope. They are supposed to be one derivation.
                """)
            #expect(instrument.shownShare(weight: .documents) == card.shownShare(weight: .documents))
        }

        // And the whole-range card is the union, with every label still unique.
        let whole = data.ranking(bands: bands, lens: .namedCollections, weight: .documents,
                                 hidingUmbrella: true, limit: .max)
        #expect(Set(whole.rows.map(\.label)).count == whole.rows.count, """
            Two rows share a label after merging the bands. A chart would draw them as one bar.
            """)
        #expect(whole.bandVolumeCount == coverage.count, """
            The merged denominator must be every dated volume in the scope; otherwise the card's \
            share sentence describes a population it did not rank.
            """)
    }

    @Test("The card's year range selects the bands it OVERLAPS")
    func cardBandSelection() {
        // Containment would drop the first band — 261 of 552 volumes — for any range starting
        // after 1861, which is most of them.
        #expect(ArchivalEraBand.bands(overlapping: 1861, through: 1993).count
                == ArchivalEraBand.all.count, "the default range must cover the whole axis")
        #expect(ArchivalEraBand.bands(overlapping: 1900, through: 1993).contains(
                    where: { $0.index == 0 }), """
            A range starting after 1861 must still include the 1861–1947 band it overlaps; \
            dropping it would silently discard 261 volumes.
            """)

        // A range inside one band selects exactly that band.
        let sixties = ArchivalEraBand.bands(overlapping: 1962, through: 1966)
        #expect(sixties.map(\.index) == [2])

        // A range spanning a boundary selects both.
        #expect(ArchivalEraBand.bands(overlapping: 1966, through: 1970).map(\.index) == [2, 3])

        // Outside the axis entirely: no bands, which the card reports as a range problem rather
        // than as a fact about the scope.
        #expect(ArchivalEraBand.bands(overlapping: 1994, through: 2020).isEmpty)
        #expect(ArchivalEraBand.bands(overlapping: 1700, through: 1800).isEmpty)

        // Reversed endpoints order themselves rather than selecting nothing.
        #expect(ArchivalEraBand.bands(overlapping: 1970, through: 1962).map(\.index) == [2, 3])
    }

    /// The shipped manifest, for the tests that must not run against a fixture.
    private static func bundledManifest() -> [VolumeManifestEntry]? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/manifest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([VolumeManifestEntry].self, from: data)
    }

    @Test("The shipped manifest bands as the axis documents it")
    func shippedManifestBandDistribution() throws {
        // Pins the coverage builder against the real corpus. The distribution is documented on
        // `ArchivalEraBand.all`, so a builder change that silently re-dated volumes would show up
        // here rather than as a quietly different chart.
        let manifest = try #require(Self.bundledManifest())
        let coverage = ArchivalVolumeCoverage.map(from: manifest)
        var counts = [Int](repeating: 0, count: ArchivalEraBand.all.count)
        for span in coverage.values {
            counts[ArchivalEraBand.band(forMidpointYear: span.midpointYear).index] += 1
        }
        #expect(counts == [261, 120, 64, 66, 41], """
            The band distribution moved. Either the manifest changed or the coverage builder \
            re-dated volumes; both need a look before this number is updated.
            """)
        #expect(coverage.count == 552, "every catalogued volume must carry a parseable span")
    }

    // MARK: - The shared coverage-map builder (#835)

    @Test("The shared coverage builder is the one definition of a scope")
    func coverageBuilderRules() throws {
        let entries = [
            manifestEntry("v1", earliest: "1950-01-01", latest: "1952-12-31"),
            manifestEntry("v2", earliest: "1970", latest: "1974"),
            manifestEntry("v3", earliest: "", latest: ""),          // no parseable year
            manifestEntry("v4", earliest: "1980", latest: "1976"),  // reversed endpoints
        ]
        let all = ArchivalVolumeCoverage.map(from: entries)
        #expect(Set(all.keys) == ["v1", "v2", "v4"], """
            A volume with no parseable year must be SKIPPED, not defaulted — an invented year \
            would place it in a band on no evidence.
            """)
        #expect(all["v1"]?.midpointYear == 1951)
        #expect(all["v4"]?.firstYear == 1976, "reversed endpoints must order themselves")

        #expect(ArchivalVolumeCoverage.map(from: entries, limitedTo: ["v2"]).keys.sorted() == ["v2"])
        #expect(ArchivalVolumeCoverage.map(from: entries, limitedTo: []).isEmpty, """
            An empty scope is an empty map, never the whole corpus — the difference between \
            "nothing selected" and "everything".
            """)
        #expect(ArchivalVolumeCoverage.map(from: entries, limitedTo: ["nope"]).isEmpty)
    }

    @Test("Volumes weight counts the authority's citing volumes, documents weight the index's")
    func weightsCountDifferentPopulations() throws {
        // `frontOnly` is named in a volume's front matter and never resolved from a document
        // note — the shipped state of 2,595 of the authority's 4,423 records.
        let spans = coverage([("v1", 1950), ("v2", 1951)])
        let deep = AuthorityCollectionRecord(id: "lot:deep", name: "Deep", lotFileNorm: "deep",
                                             volumeIds: ["v1"])
        let frontOnly = AuthorityCollectionRecord(id: "lot:front", name: "Front Matter Only",
                                                  lotFileNorm: "front", volumeIds: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [("lot:deep", [0], [500])])
        let data = ArchivalCollectionsData.make(authority: [deep, frontOnly], usage: index,
                                                coverage: spans)

        let byDocuments = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                       weight: .documents, hidingUmbrella: true)
        #expect(byDocuments.rows.map(\.id) == ["lot:deep"], """
            The front-matter-only record has no documents and must not appear under the document \
            weight as a zero. Got \(byDocuments.rows.map(\.id)).
            """)
        let byVolumes = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                     weight: .volumes, hidingUmbrella: true)
        #expect(byVolumes.rows.map(\.id) == ["lot:front", "lot:deep"], """
            Under the volume weight the front-matter record leads on 2 volumes to 1. Switching \
            the weight changes the membership as well as the order, which is what the info \
            copy claims.
            """)
    }

    // MARK: - The umbrella filter

    @Test("Hiding the umbrella reports what it hid, per band, and shows it again when off")
    func umbrellaDisclosureIsPerBand() throws {
        let spans = coverage([("v1", 1950), ("v2", 1970)])
        let umbrella = AuthorityCollectionRecord(
            id: ArchivalCollectionsData.umbrellaCollectionId, name: "Central Files",
            repository: "Department of State", volumeIds: ["v1"])
        let other = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                              volumeIds: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [
            (ArchivalCollectionsData.umbrellaCollectionId, [0], [12_060]),
            ("lot:1", [0, 1], [3, 5]),
        ])
        let data = ArchivalCollectionsData.make(authority: [umbrella, other], usage: index,
                                                coverage: spans)

        let hidden = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                  weight: .documents, hidingUmbrella: true)
        #expect(hidden.rows.map(\.id) == ["lot:1"])
        #expect(hidden.hiddenUmbrellaValue == 12_060)

        // The umbrella contributes nothing to the 1969–1976 band, so there is nothing to
        // disclose there. A fixed "157 volumes hidden" sentence would be wrong in three of the
        // five shipped bands.
        let laterBand = data.ranking(band: ArchivalEraBand.all[3], lens: .namedCollections,
                                     weight: .documents, hidingUmbrella: true)
        #expect(laterBand.hiddenUmbrellaValue == nil)

        let shown = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                 weight: .documents, hidingUmbrella: false)
        #expect(shown.rows.first?.id == ArchivalCollectionsData.umbrellaCollectionId)
        #expect(shown.hiddenUmbrellaValue == nil)
    }

    @Test("The class lens ignores the umbrella filter, because a class has no umbrella")
    func classLensHasNoUmbrella() throws {
        let spans = coverage([("v1", 1930)])
        let index = try usage(volumes: ["v1"], collections: [],
                              classes: [("793.94", [0], [4_956])])
        let data = ArchivalCollectionsData.make(authority: [], usage: index, coverage: spans)
        let ranking = data.ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses,
                                   weight: .documents, hidingUmbrella: true)
        #expect(ranking.rows.map(\.id) == ["793.94"])
        #expect(ranking.hiddenUmbrellaValue == nil)
        #expect(ranking.rows.first?.category == .stateDepartment, """
            A central-file class is a heading inside the State Department's own filing system. \
            Colouring the whole lens "other" would say the opposite.
            """)
    }

    @Test("The class lens counts citing volumes under the volume weight, not documents again")
    func classLensVolumeWeightCountsVolumes() throws {
        // The class lens is the one place both weights come from the same artifact, so the
        // volume count is derived from the number of stored (class, volume) pairs. Reading the
        // document counts there instead would make the two weights identical and the segmented
        // control a no-op — silently, since the order would rarely change.
        let spans = coverage([("v1", 1930), ("v2", 1935)])
        let index = try usage(volumes: ["v1", "v2"], collections: [],
                              classes: [("793.94", [0, 1], [4_000, 956]),
                                        ("740.0011", [0], [3_985])])
        let data = ArchivalCollectionsData.make(authority: [], usage: index, coverage: spans)

        let byDocuments = data.ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses,
                                       weight: .documents, hidingUmbrella: false)
        #expect(byDocuments.rows.map(\.id) == ["793.94", "740.0011"])
        #expect(byDocuments.rows.map(\.value) == [4_956, 3_985])

        let byVolumes = data.ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses,
                                     weight: .volumes, hidingUmbrella: false)
        #expect(byVolumes.rows.map(\.value) == [2, 1], """
            The volume weight returned \(byVolumes.rows.map(\.value)). 793.94 is cited by two \
            volumes and 740.0011 by one, whatever their document counts are.
            """)
    }

    // MARK: - Label disambiguation

    @Test("Two collections sharing a name get distinct labels, or Charts merges their bars")
    func duplicateNamesAreDisambiguated() throws {
        let spans = coverage([("v1", 1980)])
        let ford = AuthorityCollectionRecord(id: "txt:ford library|national security council",
                                             name: "National Security Council",
                                             repository: "Ford Library", volumeIds: ["v1"])
        let nara = AuthorityCollectionRecord(id: "txt:national archives|national security council",
                                             name: "National Security Council",
                                             repository: "National Archives", volumeIds: ["v1"])
        let index = try usage(volumes: ["v1"], collections: [
            (ford.id, [0], [388]), (nara.id, [0], [255]),
        ])
        let data = ArchivalCollectionsData.make(authority: [ford, nara], usage: index,
                                                coverage: spans)
        let rows = data.ranking(band: ArchivalEraBand.all[4], lens: .namedCollections,
                                weight: .documents, hidingUmbrella: true).rows
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.label)).count == 2, """
            Both bars are labelled \(rows.map(\.label)). A Swift Charts categorical axis keys on \
            the label string, so two bars sharing one are drawn as a single bar carrying the sum \
            — 643 documents attributed to whichever record the reader assumes.
            """)
        // The underlying name survives for detail copy; only the axis label is decorated.
        #expect(rows.allSatisfy { $0.name == "National Security Council" })
        #expect(rows.allSatisfy { $0.label.contains("National Security Council") })
    }

    @Test("A unique name is left alone")
    func uniqueNamesAreNotDecorated() throws {
        let spans = coverage([("v1", 1950)])
        let record = AuthorityCollectionRecord(id: "txt:eisenhower library|whitman file",
                                               name: "Whitman File",
                                               repository: "Eisenhower Library",
                                               volumeIds: ["v1"])
        let index = try usage(volumes: ["v1"], collections: [(record.id, [0], [1_643])])
        let data = ArchivalCollectionsData.make(authority: [record], usage: index,
                                                coverage: spans)
        let rows = data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                                weight: .documents, hidingUmbrella: true).rows
        #expect(rows.first?.label == "Whitman File")
    }

    // MARK: - Degraded artifacts

    @Test("A missing usage index disables the document weight rather than reporting zeroes")
    func missingUsageIndexIsDisclosed() {
        let spans = ["v1": ArchivalVolumeCoverage(firstYear: 1950, lastYear: 1950)]
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["v1"])
        let data = ArchivalCollectionsData.make(authority: [record], usage: nil, coverage: spans)
        #expect(!data.supportsDocumentWeight)
        #expect(data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                             weight: .documents, hidingUmbrella: true).rows.isEmpty)
        #expect(data.ranking(band: ArchivalEraBand.all[1], lens: .namedCollections,
                             weight: .volumes, hidingUmbrella: true).rows.count == 1, """
            The volume weight comes from the authority and must keep working when the usage \
            index is absent — otherwise a failed decode blanks the whole mode.
            """)
    }

    @Test("Removing the lifecycle card left the Volumes weight's only writer standing (#832c)")
    func volumeWeightSurvivesTheLifecycleRemoval() throws {
        // The loop that used to build the lifecycle spans also fills `collectionVolumes`, which
        // is the SOLE source of the named-collection lens's Volumes weight. Deleting the loop
        // with the card would not have failed a build or thrown — the ranking would simply have
        // gone empty under that weight, in a mode whose other weight needs a bundled artifact
        // this test deliberately withholds. Both bands are asserted because the per-band
        // bookkeeping is what the removed span code was interleaved with.
        let coverage = [
            "v-early": ArchivalVolumeCoverage(firstYear: 1950, lastYear: 1952),
            "v-late": ArchivalVolumeCoverage(firstYear: 1969, lastYear: 1976),
        ]
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["v-early", "v-late"])
        let data = ArchivalCollectionsData.make(authority: [record], usage: nil,
                                                coverage: coverage)
        for band in ArchivalEraBand.all {
            let rows = data.ranking(band: band, lens: .namedCollections, weight: .volumes,
                                    hidingUmbrella: true).rows
            let expected = coverage.values
                .filter { ArchivalEraBand.band(forMidpointYear: $0.midpointYear).index == band.index }
                .count
            #expect(rows.first?.value ?? 0 == expected, """
                Band \(band.title) counts \(rows.first?.value ?? 0) volumes, not \(expected). \
                `collectionVolumes` has no other writer, so an empty Volumes weight here means \
                the authority loop was removed along with the span bookkeeping it carried.
                """)
        }
    }

    // MARK: - One class grain (#826 / R-4)

    /// One app source file, for the drift guards that cannot reach the code they protect.
    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// A usage index over a synthetic corpus, built through the decoder because the type is
    /// decode-only by design.
    private static func usage(volumes: [String], noteCounts: [Int], classKeys: [String],
                              rows: [(key: Int, volumes: [Int], counts: [Int])])
        throws -> CollectionUsageIndex {
        let rowJSON = rows.map { "{\"k\":\($0.key),\"v\":\($0.volumes),\"n\":\($0.counts)}" }
            .joined(separator: ",")
        // Swift already quotes String elements when it describes an array, so the vocabularies
        // are interpolated bare — wrapping them again yields keys containing literal quote
        // characters, which decode cleanly and then match nothing.
        let json = """
        {"categories":[],"classKeys":\(classKeys),
         "classes":[\(rowJSON)],"collectionIds":[],"collections":[],
         "coverage":{"authorityCollectionCount":0,"authorityCollectionsReached":0,
           "noteCount":\(noteCounts.reduce(0,+)),"notesInACollection":0,
           "notesWithAClassKey":\(noteCounts.reduce(0,+)),
           "volumesScanned":\(volumes.count),"volumesWithNotes":\(volumes.count)},
         "generated":"2026-08-10","schemaVersion":1,"volumeCategories":[],
         "volumeNoteCounts":\(noteCounts),"volumes":\(volumes)}
        """
        return try JSONDecoder().decode(CollectionUsageIndex.self, from: Data(json.utf8))
    }

    @Test("Two designators in one family are one citing volume, not two")
    func foldingDoesNotDoubleCountVolumes() throws {
        // THE hazard of folding a per-(key, volume) tally: documents ADD across leaves, volumes
        // do not. One volume citing POL 27 VIET S and POL 27 ARAB-ISR is one citing volume of
        // POL 27. Summing the leaf volume counts would report two, and the error is invisible —
        // a plausible number, slightly too large, on every folded row.
        let index = try Self.usage(
            volumes: ["v1"], noteCounts: [40],
            classKeys: ["POL 27 ARAB-ISR", "POL 27 VIET S"],
            rows: [(key: 0, volumes: [0], counts: [7]), (key: 1, volumes: [0], counts: [11])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["v1": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)])
        let band = ArchivalEraBand.all[2]

        let byDocuments = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                                       hidingUmbrella: false).rows
        #expect(byDocuments.count == 1, "the two leaves must rank as one family row")
        #expect(byDocuments.first?.id == "POL 27")
        #expect(byDocuments.first?.value == 18, "documents add across the leaves: 7 + 11")

        let byVolumes = data.ranking(band: band, lens: .centralFileClasses, weight: .volumes,
                                     hidingUmbrella: false).rows
        #expect(byVolumes.first?.value == 1, """
            The family reports \(byVolumes.first?.value ?? -1) citing volumes from a single \
            volume. Volume counts must be a set union across the folded leaves, never a sum.
            """)
    }

    @Test("A folded row keeps its leaves; a decimal file number is not a family")
    func leavesSurviveTheFold() throws {
        let index = try Self.usage(
            volumes: ["v1"], noteCounts: [40],
            classKeys: ["763.72", "POL 27 ARAB-ISR", "POL 27 VIET S"],
            rows: [(key: 0, volumes: [0], counts: [30]),
                   (key: 1, volumes: [0], counts: [7]),
                   (key: 2, volumes: [0], counts: [11])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["v1": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)])
        let rows = data.ranking(band: ArchivalEraBand.all[2], lens: .centralFileClasses,
                                weight: .documents, hidingUmbrella: false).rows

        let decimal = try #require(rows.first { $0.id == "763.72" })
        #expect(!decimal.isFamily, """
            A decimal file number is already the unit a pull slip names. Folding it, or drawing \
            it with an expander that reveals only itself, would invent a hierarchy the filing \
            system does not have.
            """)

        let family = try #require(rows.first { $0.id == "POL 27" })
        #expect(family.isFamily)
        // Heaviest leaf first — the reader's next question after "which family" is "which one".
        #expect(family.leaves.map(\.key) == ["POL 27 VIET S", "POL 27 ARAB-ISR"])
        #expect(family.leaves.map(\.documents) == [11, 7])
        #expect(family.leaves.reduce(0) { $0 + $1.documents } == family.value,
                "a family's leaves must account for exactly the row's own value")
        // Each leaf also carries its own citing-volume count, so an expansion read under the
        // volumes weight adds up to the bar above it instead of to a document total.
        #expect(family.leaves.allSatisfy { $0.volumes == 1 })
        #expect(family.leaves.map { $0.value(weight: .volumes) } == [1, 1])
    }

    @Test("Every class row is a fold fixed point, so the two surfaces cannot disagree on a family")
    func classRowsAreFoldedToOneGrain() throws {
        // The two surfaces disagreeing about what `POL 27` means would be worse than either
        // grain alone. They cannot share a call site — the Network folds inside its own
        // co-citation accumulation — so the claim pinned here is the observable one: nothing
        // the ranking draws is a key that the shared rule would fold further. A raw leaf on the
        // chart fails this; so does folding with any rule but `subjectNumericGroup`.
        let data = try #require(Self.shipped)
        var families = 0
        var checked = 0
        for band in ArchivalEraBand.all {
            for weight in ArchivalWeight.allCases {
                let rows = data.ranking(band: band, lens: .centralFileClasses, weight: weight,
                                        hidingUmbrella: false, limit: 200).rows
                for row in rows {
                    let folded = CollectionKeying.subjectNumericGroup(row.id) ?? row.id
                    #expect(folded == row.id, """
                        The ranking drew \(row.id), which the shared fold reduces to \(folded). \
                        A row at leaf grain means the Collections lens is ranking something the \
                        co-citation network would call part of a larger family.
                        """)
                    if row.isFamily { families += 1 }
                    checked += 1
                }
            }
        }
        #expect(checked > 100, "the sweep covered \(checked) rows, which is too few to mean much")
        #expect(families > 0, """
            No drawn row folds anything, so this sweep would pass just as well against the \
            unfolded ranking it exists to rule out.
            """)
    }

    @Test("The shared fold is what both archival surfaces call")
    func bothSurfacesCallTheSharedFold() throws {
        // A source scan because the Network's fold is buried in its own accumulation and cannot
        // be reached from here. It is the drift guard: a second, local fold in either file is
        // how the two grains would part company again.
        for relative in ["Analytics/ArchivalCollectionsData.swift",
                         "Analytics/ArchivalNetworkData.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("CollectionKeying.subjectNumericGroup("),
                    "\(relative) no longer routes through the shared fold")
        }
    }

    // MARK: - Opening a row, and every row (#825)

    @Test("A row id resolves to its authority record, and an unknown id opens nothing")
    func rowsResolveToRecordsOrToNothing() {
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["v1"])
        let data = ArchivalCollectionsData.make(
            authority: [record], usage: nil,
            coverage: ["v1": ArchivalVolumeCoverage(firstYear: 1950, lastYear: 1952)])
        #expect(data.record(forId: "lot:1")?.name == "Lot One")
        // The documents table is keyed by the USAGE INDEX, which can name an id the authority
        // does not carry. Such a row draws (the ranking falls back to the raw id for its label)
        // and must simply not open — a navigation target invented for it would be a worse dead
        // end than the one #825 is closing.
        #expect(data.record(forId: "lot:not-in-authority") == nil)
    }

    @Test("The row cap is a display decision the uncapped table can lift")
    func rankingCanBeUncapped() throws {
        // 20 classes in one band, against a cap of 12. The "Show all N units" table asks for the
        // same ranking with the cap lifted, so the two must agree on everything except length —
        // if the cap were baked into the derivation instead, the full list could not exist.
        let keys = (1...20).map { "76\($0).00" }
        let index = try Self.usage(
            volumes: ["v1"], noteCounts: [500], classKeys: keys.sorted(),
            rows: keys.sorted().enumerated().map {
                (key: $0.offset, volumes: [0], counts: [100 - $0.offset])
            })
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["v1": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)])
        let band = ArchivalEraBand.all[2]

        let capped = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                                  hidingUmbrella: false)
        #expect(capped.rows.count == ArchivalCollectionsData.rowCap)
        #expect(capped.unitsReached == 20, "the caption counts every unit, not the drawn ones")

        let all = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                               hidingUmbrella: false, limit: .max)
        #expect(all.rows.count == 20)
        #expect(all.unitsReached == 20)
        #expect(Array(all.rows.prefix(ArchivalCollectionsData.rowCap)).map(\.id)
                    == capped.rows.map(\.id), """
            The uncapped list must open with exactly the rows the chart drew, in the same order. \
            A reader who taps "show all" and finds a different top twelve has been shown two \
            different rankings of one era.
            """)
    }

    // MARK: - The denominators (#826 / R-5)

    @Test("A band's note total is read from the artifact, and the share is withheld when it would lie")
    func denominatorsComeFromTheArtifact() throws {
        let index = try Self.usage(
            volumes: ["v1", "v2"], noteCounts: [40, 60],
            classKeys: ["763.72"],
            rows: [(key: 0, volumes: [0, 1], counts: [10, 15])])
        let coverage = ["v1": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968),
                        "v2": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)]
        let data = ArchivalCollectionsData.make(authority: [], usage: index, coverage: coverage)
        let band = ArchivalEraBand.all[2]

        #expect(data.noteCount(band: band) == 100, "40 + 60, from volumeNoteCounts")
        let documents = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                                     hidingUmbrella: false)
        #expect(documents.bandNoteCount == 100)
        #expect(documents.shownValue == 25)
        #expect(documents.shownShare(weight: .documents) == 0.25)

        let volumes = data.ranking(band: band, lens: .centralFileClasses, weight: .volumes,
                                   hidingUmbrella: false)
        #expect(volumes.shownShare(weight: .volumes) == nil, """
            Under the volumes weight the numerator counts volumes and the denominator counts \
            source notes. No share is better than a ratio of two different things.
            """)
    }

    @Test("A missing usage index states no denominator rather than zero")
    func denominatorIsAbsentWithoutTheArtifact() {
        let data = ArchivalCollectionsData.make(
            authority: [], usage: nil,
            coverage: ["v1": ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)])
        #expect(data.noteCount(band: ArchivalEraBand.all[2]) == nil)
    }

    // MARK: - Volume scoping (#827)

    @Test("A scope is a filter on the coverage map, so every figure narrows together")
    func scopingNarrowsEveryFigure() throws {
        // The derivation is a pure function of (authority, usage, coverage), so scoping is a
        // filter on ONE input. That is what makes the ranking, the denominator, the band volume
        // count and the units-reached caption move together — none of them can be scoped
        // separately, and so none of them can be left describing the wider population.
        let index = try Self.usage(
            volumes: ["v-in", "v-out"], noteCounts: [100, 900],
            classKeys: ["763.72", "764.00"],
            rows: [(key: 0, volumes: [0, 1], counts: [10, 90]),
                   (key: 1, volumes: [1], counts: [200])])
        let span = ArchivalVolumeCoverage(firstYear: 1964, lastYear: 1968)
        let band = ArchivalEraBand.all[2]

        let whole = ArchivalCollectionsData.make(
            authority: [], usage: index, coverage: ["v-in": span, "v-out": span])
        let scoped = ArchivalCollectionsData.make(
            authority: [], usage: index, coverage: ["v-in": span])

        #expect(whole.noteCount(band: band) == 1_000)
        #expect(scoped.noteCount(band: band) == 100, """
            The denominator must be the SCOPE's notes. Leaving it corpus-wide would put a \
            scoped numerator over a series-wide denominator — a share of the wrong thing, and \
            wrong in the direction that flatters the scope.
            """)

        let wholeRanking = whole.ranking(band: band, lens: .centralFileClasses,
                                         weight: .documents, hidingUmbrella: false)
        let scopedRanking = scoped.ranking(band: band, lens: .centralFileClasses,
                                           weight: .documents, hidingUmbrella: false)
        #expect(wholeRanking.bandVolumeCount == 2)
        #expect(scopedRanking.bandVolumeCount == 1, "the caption counts the scope's volumes")
        #expect(wholeRanking.unitsReached == 2)
        #expect(scopedRanking.unitsReached == 1, """
            `764.00` exists only in the excluded volume, so a scoped ranking must not reach it — \
            and the "draw on N units" caption must not count it.
            """)
        #expect(scopedRanking.rows.first?.value == 10, "only the in-scope volume's documents")
        #expect(scopedRanking.shownShare(weight: .documents) == 0.1)
    }

    @Test("An empty scope yields an empty derivation rather than the whole corpus")
    func emptyScopeIsNotWholeCorpus() throws {
        // The failure mode worth ruling out: a scope that resolves to no volumes silently
        // falling back to everything, so the reader sees the series while the chip claims a
        // narrow set.
        let index = try Self.usage(
            volumes: ["v1"], noteCounts: [100], classKeys: ["763.72"],
            rows: [(key: 0, volumes: [0], counts: [10])])
        let data = ArchivalCollectionsData.make(authority: [], usage: index, coverage: [:])
        let band = ArchivalEraBand.all[2]
        #expect(data.noteCount(band: band) == nil)
        #expect(data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                             hidingUmbrella: false).rows.isEmpty)
    }

    // MARK: - The shipped artifacts

    /// The derivation over what actually ships, built once for the whole suite.
    ///
    /// The manifest is decoded here rather than read off a `ManifestStore` because that type is
    /// `@MainActor` and this needs to be a plain static.
    private static let shipped: ArchivalCollectionsData? = {
        guard let authority = CollectionAuthorityStore.shared?.collections,
              let url = Bundle.main.url(forResource: "manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        else { return nil }
        var coverage: [String: ArchivalVolumeCoverage] = [:]
        for entry in entries {
            let first = FRUSVolumeMetadata.firstYear(in: entry.dateRange.earliest)
            let last = FRUSVolumeMetadata.firstYear(in: entry.dateRange.latest)
            guard let start = first ?? last, let end = last ?? first else { continue }
            coverage[entry.volumeId] = ArchivalVolumeCoverage(firstYear: start, lastYear: end)
        }
        return ArchivalCollectionsData.make(authority: authority,
                                            usage: CollectionUsageIndexStore.shared,
                                            coverage: coverage)
    }()

    @Test("The default view's denominator is the measured one, end to end")
    func shippedDenominatorReproduces() throws {
        // The mode opens here: 1948–1960, named collections, documents, umbrella hidden. The
        // whole point of R-5 is that this view draws twelve bars accounting for 9.4% of the
        // band's sourced documents, so the number is pinned against the shipped artifacts rather
        // than trusted — it travels through manifest coverage, band attribution, the usage
        // index and the umbrella filter, and a regression in any of them moves it.
        let data = try #require(Self.shipped)
        let band = ArchivalEraBand.all[1]
        #expect(data.noteCount(band: band) == 59_973, """
            The 1948–1960 band's source-note total is \(data.noteCount(band: band) ?? -1), not \
            59,973. That sum comes straight from volumeNoteCounts and the band attribution.
            """)
        let ranking = data.ranking(band: band, lens: .namedCollections, weight: .documents,
                                   hidingUmbrella: true)
        let share = try #require(ranking.shownShare(weight: .documents))
        #expect(abs(share - 0.094) < 0.005, """
            The opening view's twelve rows cover \(share.formatted(.percent)) of the band, not \
            ~9.4%.
            """)
        // With the umbrella shown the same twelve rows cover 29.2%: the share is a function of
        // the chip, so it must be recomputed with it rather than cached per band.
        let shown = data.ranking(band: band, lens: .namedCollections, weight: .documents,
                                 hidingUmbrella: false)
        let shownShare = try #require(shown.shownShare(weight: .documents))
        #expect(shownShare > share * 2)
    }

    /// The pointer weight is a **swap**, not a third column, and this is the assertion that says so:
    /// it must rank a materially different set of collections, not the same ones reordered. The
    /// issue measured 1,014 usage collections dropping out and 181 pointer-only units appearing;
    /// the exact figures move with the artifacts, so this pins the direction rather than a number.
    @Test("The pointer weight replaces the row set rather than reordering it")
    func pointerWeightReplacesTheRowSet() throws {
        let data = try #require(Self.shipped)
        #expect(data.supportsPointerWeight, "the bundled external-citation index did not load")

        var documentIds: Set<String> = []
        var pointerIds: Set<String> = []
        for band in ArchivalEraBand.all {
            documentIds.formUnion(data.ranking(band: band, lens: .namedCollections,
                                               weight: .documents, hidingUmbrella: false,
                                               limit: .max).rows.map(\.id))
            pointerIds.formUnion(data.ranking(band: band, lens: .namedCollections,
                                              weight: .unprintedPointers, hidingUmbrella: false,
                                              limit: .max).rows.map(\.id))
        }
        #expect(!pointerIds.isEmpty, "no collection is pointed at — the pointer table is empty")
        #expect(!pointerIds.subtracting(documentIds).isEmpty, """
            Every pointed-at collection also supplied a printed document. The whole point of this \
            weight is that some collections are only ever pointed AT, so this suggests the pointer \
            table is being filled from the usage index rather than the citation index.
            """)
        #expect(!documentIds.subtracting(pointerIds).isEmpty)
    }

    /// The class lens ranks the pointer weight, which it could not do before #834.
    ///
    /// **This test previously asserted the opposite** — that the combination yielded nothing —
    /// because #784's harvest read lot files and presidential libraries and never a decimal class.
    /// #834 gave the lens its own vocabulary, so the assertion is inverted rather than deleted: the
    /// hole it guarded is now a feature, and something has to hold the feature in place.
    @Test("The class lens ranks the pointer weight")
    func classLensRanksPointers() throws {
        let data = try #require(Self.shipped)
        var ranked = 0
        for band in ArchivalEraBand.all {
            let ranking = data.ranking(band: band, lens: .centralFileClasses,
                                       weight: .unprintedPointers, hidingUmbrella: false)
            if !ranking.rows.isEmpty { ranked += 1 }
            // Every row must be a class key, not an authority id that leaked across the axes.
            for row in ranking.rows {
                #expect(SourceNoteParser.decimalClassKey(row.id) != nil, """
                    \(row.id) is ranked on the class lens but is not a class key. The two axes have \
                    separate vocabularies and separate index spaces; a leak here means a collection \
                    id is being ranked as a class.
                    """)
            }
        }
        #expect(ranked > 0, """
            No era band ranks anything under the class lens's pointer weight. Before #834 that was \
            correct — the lens had no pointer vocabulary at all and the weight was withheld in the \
            picker. If it is true again, the decimal channel has stopped reaching the artifact.
            """)
    }

    /// The bands partition the corpus by citing volume, so a multi-band pointer ranking must be the
    /// exact sum of its parts — the same property the other two weights rely on, and the one that
    /// would break if references were banded by the *target's* coverage instead of the citer's.
    @Test("Pointer rankings sum exactly across bands")
    func pointerRankingsSumAcrossBands() throws {
        let data = try #require(Self.shipped)
        var perBand: [String: Int] = [:]
        for band in ArchivalEraBand.all {
            for row in data.ranking(band: band, lens: .namedCollections, weight: .unprintedPointers,
                                    hidingUmbrella: false, limit: .max).rows {
                perBand[row.id, default: 0] += row.value
            }
        }
        let merged = data.ranking(bands: ArchivalEraBand.all, lens: .namedCollections,
                                  weight: .unprintedPointers, hidingUmbrella: false, limit: .max)
        #expect(!merged.rows.isEmpty)
        for row in merged.rows {
            #expect(perBand[row.id] == row.value, """
                \(row.label): the merged ranking says \(row.value) but the bands sum to \
                \(perBand[row.id] ?? 0).
                """)
        }
    }

    @Test("Every ranking the UI can ask for has unique labels")
    func shippedLabelsAreAlwaysUnique() throws {
        let data = try #require(Self.shipped)
        var checked = 0
        for band in ArchivalEraBand.all {
            for lens in ArchivalUnitLens.allCases {
                for weight in ArchivalWeight.allCases {
                    for hiding in [true, false] {
                        let rows = data.ranking(band: band, lens: lens, weight: weight,
                                                hidingUmbrella: hiding).rows
                        #expect(Set(rows.map(\.label)).count == rows.count, """
                            \(band.title) / \(lens.title) / \(weight.title) (hiding: \(hiding)) \
                            has a repeated label: \(rows.map(\.label)).
                            """)
                        checked += 1
                    }
                }
            }
        }
        // 5 bands x 2 lenses x 3 weights x 2 umbrella states. The count is asserted so that a
        // weight or lens added without extending this sweep fails here rather than shipping
        // unswept — which is what it did for the pointer weight (#829c).
        #expect(checked == 60, "the sweep covered \(checked) combinations, not 60")
    }

    @Test("The class lens carries the early series and the collection lens carries the late one")
    func theUnitAsymmetryIsReal() throws {
        // This is the claim the caveat block and the Units chip both rest on. If it ever stops
        // being true, the copy telling readers to switch lenses is wrong.
        let data = try #require(Self.shipped)
        let earlyClasses = data.ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses,
                                        weight: .documents, hidingUmbrella: true)
        let earlyCollections = data.ranking(band: ArchivalEraBand.all[0],
                                            lens: .namedCollections, weight: .documents,
                                            hidingUmbrella: true)
        #expect((earlyClasses.rows.first?.value ?? 0) > (earlyCollections.rows.first?.value ?? 0),
                """
                Before 1948 the top class supplies \(earlyClasses.rows.first?.value ?? 0) \
                documents and the top collection \(earlyCollections.rows.first?.value ?? 0). \
                The copy says classes carry that era.
                """)

        let lateClasses = data.ranking(band: ArchivalEraBand.all[4], lens: .centralFileClasses,
                                       weight: .documents, hidingUmbrella: true)
        let lateCollections = data.ranking(band: ArchivalEraBand.all[4], lens: .namedCollections,
                                           weight: .documents, hidingUmbrella: true)
        #expect(lateClasses.unitsReached < 20, """
            \(lateClasses.unitsReached) classes reach the 1977–1992 volumes. The copy says they \
            all but disappear.
            """)
        #expect(lateCollections.unitsReached > 100)
    }

    @Test("The record really did move to the White House, and the chart shows it")
    func theWhiteHouseShiftIsVisible() throws {
        // The finding this whole mode exists to render: State's own files lead the 1948–1960
        // ranking and a presidential library leads 1969–1976 and 1977–1992.
        let data = try #require(Self.shipped)
        func topCategory(_ band: ArchivalEraBand) -> ArchivalRepositoryCategory? {
            data.ranking(band: band, lens: .namedCollections, weight: .documents,
                         hidingUmbrella: true).rows.first?.category
        }
        #expect(topCategory(ArchivalEraBand.all[3]) == .presidentialLibrary)
        #expect(topCategory(ArchivalEraBand.all[4]) == .presidentialLibrary)
    }

    @Test("Switching the weight changes the answer, which is why both are offered")
    func weightsDisagreeOnTheShippedData() throws {
        let data = try #require(Self.shipped)
        var disagreements = 0
        for band in ArchivalEraBand.all {
            let byDocuments = data.ranking(band: band, lens: .namedCollections,
                                           weight: .documents, hidingUmbrella: true)
            let byVolumes = data.ranking(band: band, lens: .namedCollections, weight: .volumes,
                                         hidingUmbrella: true)
            if byDocuments.rows.map(\.id) != byVolumes.rows.map(\.id) { disagreements += 1 }
        }
        #expect(disagreements >= 4, """
            The two weights produce the same top twelve in \(5 - disagreements) of 5 bands. The \
            info copy promises they differ; if they stopped differing, one of them is redundant.
            """)
    }

    @Test("A class label follows the volumes citing the key, not the band's own years")
    func perKeyEraAttribution() throws {
        // Band 1 runs 1948–1960 and spans THREE classification schedules, so no schedule can
        // ever speak for it — while `862.00` inside it is cited only by volumes covering
        // 1948–1949, which the 1910–49 schedule states exactly. Asking the band was asking the
        // wrong question: the band is how the chart groups, the volumes are the evidence.
        // The volumes are ordered LATE FIRST, so the straddling key's *last* contributor is the
        // one inside the schedule. A span that overwrote instead of widening would read that
        // last volume and label the key; the ordering is what makes the difference visible.
        let index = try Self.usage(
            volumes: ["a-late", "b-early"], noteCounts: [40, 40],
            classKeys: ["862.00", "893.00"],
            rows: [(key: 0, volumes: [1], counts: [9]),
                   (key: 1, volumes: [0, 1], counts: [5, 5])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            // Both land in band 1 by coverage midpoint; only one sits inside the schedule.
            coverage: ["b-early": ArchivalVolumeCoverage(firstYear: 1948, lastYear: 1949),
                       "a-late": ArchivalVolumeCoverage(firstYear: 1955, lastYear: 1958)])
        let band = ArchivalEraBand.all[1]
        #expect(band.startYear == 1948 && band.endYear == 1960, "the fixture assumes this band")
        let rows = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                                hidingUmbrella: false).rows

        let labelled = try #require(rows.first { $0.id == "862.00" })
        #expect(labelled.gloss == "Germany — Political affairs", """
            Every volume citing this key covers 1948–1949. Under the band's own 1948–1960 span it \
            rendered bare, and it would still render bare with all three schedules parsed — 1960 \
            falls outside 1951–59 as surely as outside 1910–49.
            """)

        // The other key is cited from both sides of the renumbering, so its union spans it and
        // no schedule may speak. Silence is the designed outcome, not a gap.
        let straddling = try #require(rows.first { $0.id == "893.00" })
        #expect(straddling.gloss == nil, """
            1948–1958 crosses the 1950 renumbering, where the same digits mean different things, \
            so a label here would be a confident guess. Note the LAST volume citing this key \
            covers 1948–1949 and would resolve on its own: the span has to widen across every \
            contributor rather than track the most recent.
            """)
    }

    @Test("A merged-band selection labels what its keys support, not nothing at all")
    func mergedBandsUsePerKeySpans() throws {
        // #835's `ranking(bands:)` merges bands. The union of two bands' years is covered by no
        // schedule, so a band-span rule silenced EVERY key in a multi-band scope — including the
        // ones whose own volumes never leave the 1910–49 file.
        let index = try Self.usage(
            volumes: ["v1938", "v1948", "v1955"], noteCounts: [40, 40, 40],
            classKeys: ["812.6363", "893.00"],
            rows: [(key: 0, volumes: [0, 1], counts: [11, 4]),
                   (key: 1, volumes: [0, 2], counts: [6, 6])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["v1938": ArchivalVolumeCoverage(firstYear: 1938, lastYear: 1939),
                       "v1948": ArchivalVolumeCoverage(firstYear: 1948, lastYear: 1949),
                       "v1955": ArchivalVolumeCoverage(firstYear: 1955, lastYear: 1958)])
        let rows = data.ranking(bands: [ArchivalEraBand.all[0], ArchivalEraBand.all[1]],
                                lens: .centralFileClasses, weight: .documents,
                                hidingUmbrella: false).rows
        let row = try #require(rows.first { $0.id == "812.6363" })
        #expect(row.value == 15, "the merge still adds across bands")
        #expect(row.gloss == "Mexico — Petroleum", """
            The merged bands run 1861–1960, which no schedule governs. The key's own volumes run \
            1938–1949, which the 1910–49 schedule governs completely.
            """)

        // The other key reaches band 1's far side, so its contributions across the two bands
        // straddle the renumbering. Reading only the first band's span would label it on the
        // strength of evidence the rest of the row contradicts.
        let straddling = try #require(rows.first { $0.id == "893.00" })
        #expect(straddling.value == 12)
        #expect(straddling.gloss == nil, """
            1938–1958 crosses 1950. The band-0 half alone resolves cleanly, which is exactly why \
            the span is unioned across every band being ranked rather than taken from the first.
            """)
    }

    @Test("A key's span reaches back to its earliest citing volume, not just its latest")
    func spanWidensBackwards() throws {
        // Unobservable against the shipped table, which carries one schedule: every lower bound
        // that could matter is either below 1910 and clamped, or inside the only schedule there
        // is. With two, it decides the answer — so the table is injected and the case is pinned
        // here rather than left for the schedule that will depend on it.
        let json = """
        {"schemaVersion":1,"generated":"2026-08-11","provenance":"test","schedules":[
          {"id":"1910-1949","startYear":1910,"endYear":1949,"source":"test",
           "classes":{"8":"Internal Affairs of States"},"relationsClasses":["7"],
           "countryArrangedClasses":["8"],"countries":{"91":"Iran"},"subjects":{}},
          {"id":"1951-1959","startYear":1951,"endYear":1959,"source":"test",
           "classes":{"8":"Other Internal Affairs"},"relationsClasses":["6"],
           "countryArrangedClasses":["8"],"countries":{"91":"Iran"},"subjects":{}}]}
        """
        let table = try JSONDecoder().decode(DecimalClassLabelTable.self, from: Data(json.utf8))
        // Both volumes have a coverage MIDPOINT in 1948–1960, so both land in band 1 and one
        // band's own span has to cross the renumbering — the case a per-band union could not
        // otherwise reach.
        let index = try Self.usage(
            volumes: ["v1948", "v1955"], noteCounts: [40, 40],
            classKeys: ["891.00"],
            rows: [(key: 0, volumes: [0, 1], counts: [5, 5])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["v1948": ArchivalVolumeCoverage(firstYear: 1947, lastYear: 1949),
                       "v1955": ArchivalVolumeCoverage(firstYear: 1954, lastYear: 1956)],
            labels: table)
        let rows = data.ranking(band: ArchivalEraBand.all[1], lens: .centralFileClasses,
                                weight: .documents, hidingUmbrella: false).rows
        let row = try #require(rows.first { $0.id == "891.00" })
        #expect(row.value == 10, "both volumes are in band 1")
        #expect(row.gloss == nil, """
            The span runs 1947–1956 and crosses 1950. A span that only widened forwards would end \
            at 1954–1956, sit inside the later schedule, and name a country by a number half this \
            key's documents predate.
            """)
    }

    @Test("A key cited only by undated volumes produces no row to label")
    func unplacedKeysStaySilent() throws {
        // The invariant behind `gloss(forKey:bands:)` treating a missing span as unreachable: a
        // volume absent from `coverage` cannot be attributed to a band, so it supplies neither a
        // document count nor a span, and no row exists to be glossed either way. If that stopped
        // holding, a row would reach the label lookup with no evidence behind it.
        let index = try Self.usage(
            volumes: ["known", "undated"], noteCounts: [40, 40],
            classKeys: ["862.00"],
            rows: [(key: 0, volumes: [1], counts: [9])])
        let data = ArchivalCollectionsData.make(
            authority: [], usage: index,
            coverage: ["known": ArchivalVolumeCoverage(firstYear: 1930, lastYear: 1935)])
        for band in ArchivalEraBand.all {
            let rows = data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                                    hidingUmbrella: false).rows
            #expect(rows.isEmpty, "an undated volume supplies no rows in band \(band.index)")
        }
    }
}
