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

    // MARK: - Lifecycles

    @Test("A lifecycle span reaches the real coverage endpoints, not the midpoints")
    func lifecycleUsesCoverageEndpoints() throws {
        var spans: [String: ArchivalVolumeCoverage] = [:]
        spans["v1"] = ArchivalVolumeCoverage(firstYear: 1952, lastYear: 1954)
        spans["v2"] = ArchivalVolumeCoverage(firstYear: 1969, lastYear: 1976)
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["v1", "v2"])
        let data = ArchivalCollectionsData.make(authority: [record], usage: nil, coverage: spans)
        let span = try #require(data.lifecycleSpans.first)
        #expect(span.firstYear == 1952)
        #expect(span.lastYear == 1976, """
            The span ends at \(span.lastYear). Using the coverage midpoint would end it at 1972 \
            and understate every bar on the card by half a subseries.
            """)
        #expect(span.volumeCount == 2)
    }

    @Test("A collection whose volumes are all outside the manifest yields no lifecycle bar")
    func lifecycleSkipsUnknownVolumes() {
        let record = AuthorityCollectionRecord(id: "lot:1", name: "Lot One", lotFileNorm: "1",
                                               volumeIds: ["not-in-manifest"])
        let data = ArchivalCollectionsData.make(authority: [record], usage: nil, coverage: [:])
        #expect(data.lifecycleSpans.isEmpty)
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
        #expect(checked == 40, "the sweep covered \(checked) combinations, not 40")
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
}
