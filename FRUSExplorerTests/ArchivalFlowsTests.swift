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

// MARK: - ArchivalFlowsDataTests

/// The Flows mode's derivation over the #764 aggregate (#765 stage 2).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
@Suite("Archival analytics — flows derivation")
struct ArchivalFlowsDataTests {

    // MARK: - Fixtures

    private func index(collectionIds: [String], flows: [(Int, Int, Int)],
                       documentEdges: Int = 100, footnoteEdges: Int = 95) throws
        -> ProvenanceFlowIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1, "generated": "2026-08-09",
            "collectionIds": collectionIds, "classKeys": [],
            "collectionFlows": flows.map { ["s": $0.0, "t": $0.1, "n": $0.2] },
            "classFlows": [],
            "coverage": [
                "volumesScanned": 552, "volumesWithEdges": 254,
                "referencesScanned": 2_713_592, "referencesInsideDocuments": 181_807,
                "documentEdges": documentEdges, "sameVolumeEdges": 60,
                "footnoteEdges": footnoteEdges,
                "collections": ["joinedReferences": 100, "sameUnitReferences": 20,
                                 "pairCount": flows.count, "unitCount": collectionIds.count],
                "classes": ["joinedReferences": 0, "sameUnitReferences": 0,
                             "pairCount": 0, "unitCount": 0],
            ],
        ]
        return try JSONDecoder().decode(
            ProvenanceFlowIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    private func authority(_ records: [(id: String, name: String, repository: String?)]) throws
        -> CollectionAuthorityIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1, "generated": "2026-08-09",
            "collections": records.map { record -> [String: Any] in
                var row: [String: Any] = ["id": record.id, "name": record.name]
                if let repository = record.repository { row["repository"] = repository }
                return row
            },
        ]
        return try JSONDecoder().decode(
            CollectionAuthorityIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    // MARK: - Focused flows

    @Test("A focused view fans out to every destination, heaviest first")
    func focusedFanOut() throws {
        let ids = ["a", "b", "c", "d"]
        let flows = try index(collectionIds: ids,
                              flows: [(0, 1, 40), (0, 2, 90), (0, 3, 10), (0, 0, 500)])
        let records = try authority(ids.map { (id: $0, name: $0.uppercased(), repository: nil) })
        let data = ArchivalFlowsData.focused(
            on: try #require(records.record(id: "a")), direction: .outgoing,
            index: flows, authority: records)

        #expect(data.endpoints.map(\.id) == ["c", "b", "d"], "heaviest first")
        #expect(data.totalReferences == 140)
        #expect(data.sameUnitReferences == 500, """
            Self-references came back as \(data.sameUnitReferences). They are excluded from the \
            diagram but must be *reported*, or the reader cannot tell that 500 of the 640 \
            references this collection carries were removed from the picture.
            """)
    }

    @Test("Direction is not symmetric, and the derivation preserves that")
    func directionIsPreserved() throws {
        let ids = ["a", "b"]
        let flows = try index(collectionIds: ids, flows: [(0, 1, 449), (1, 0, 317)])
        let records = try authority(ids.map { (id: $0, name: $0.uppercased(), repository: nil) })
        let focus = try #require(records.record(id: "a"))
        let outgoing = ArchivalFlowsData.focused(on: focus, direction: .outgoing,
                                                 index: flows, authority: records)
        let incoming = ArchivalFlowsData.focused(on: focus, direction: .incoming,
                                                 index: flows, authority: records)
        #expect(outgoing.endpoints.first?.count == 449)
        #expect(incoming.endpoints.first?.count == 317, """
            Incoming reported \(incoming.endpoints.first?.count ?? 0). The heaviest pair in the \
            shipped artifact runs 449 one way and 317 the other; a derivation that answered the \
            outgoing question twice would look right and be wrong.
            """)
    }

    // MARK: - No silent truncation

    @Test("Destinations past the block cap are folded into one block that counts itself")
    func remainderFoldsRatherThanTruncates() throws {
        let count = ArchivalFlowsData.endpointCap + 7
        let ids = ["focus"] + (0..<count).map { "d\($0)" }
        let flows = try index(collectionIds: ids,
                              flows: (0..<count).map { (0, $0 + 1, count - $0) })
        let records = try authority(ids.map { (id: $0, name: $0, repository: nil) })
        let data = ArchivalFlowsData.focused(
            on: try #require(records.record(id: "focus")), direction: .outgoing,
            index: flows, authority: records)

        #expect(data.endpoints.count == ArchivalFlowsData.endpointCap + 1,
                "the cap's worth of blocks plus one remainder")
        let remainder = try #require(data.endpoints.last)
        #expect(remainder.isRemainder)
        #expect(remainder.foldedCount == 7)
        #expect(data.allEndpoints.count == count, "the full list survives for the expansion")
        // The whole point: the reference total the diagram shows must equal the real total, or
        // folding would be truncation wearing a label.
        #expect(data.endpoints.reduce(0) { $0 + $1.count } == data.totalReferences, """
            The blocks sum to \(data.endpoints.reduce(0) { $0 + $1.count }) but the real total is \
            \(data.totalReferences). A remainder block that does not carry its own references is \
            silent truncation.
            """)
    }

    @Test("Exactly the cap's worth of destinations produces no remainder block")
    func noRemainderWhenNothingIsFolded() throws {
        let count = ArchivalFlowsData.endpointCap
        let ids = ["focus"] + (0..<count).map { "d\($0)" }
        let flows = try index(collectionIds: ids,
                              flows: (0..<count).map { (0, $0 + 1, count - $0) })
        let records = try authority(ids.map { (id: $0, name: $0, repository: nil) })
        let data = ArchivalFlowsData.focused(
            on: try #require(records.record(id: "focus")), direction: .outgoing,
            index: flows, authority: records)
        #expect(data.endpoints.count == count)
        #expect(!data.endpoints.contains { $0.isRemainder })
    }

    @Test("Two equal-weight destinations fold reproducibly")
    func foldIsDeterministic() throws {
        // Without an id tie-break, two destinations of equal weight could swap places between
        // launches and the remainder would hold a different collection each time.
        let ids = ["focus"] + (0..<(ArchivalFlowsData.endpointCap + 2)).map { "d\($0)" }
        let flows = try index(collectionIds: ids,
                              flows: (0..<(ArchivalFlowsData.endpointCap + 2)).map { (0, $0 + 1, 5) })
        let records = try authority(ids.map { (id: $0, name: $0, repository: nil) })
        let focus = try #require(records.record(id: "focus"))
        let first = ArchivalFlowsData.focused(on: focus, direction: .outgoing,
                                              index: flows, authority: records)
        let second = ArchivalFlowsData.focused(on: focus, direction: .outgoing,
                                               index: flows, authority: records)
        #expect(first.endpoints.map(\.id) == second.endpoints.map(\.id))
        #expect(first.allEndpoints.map(\.id) == first.allEndpoints.map(\.id).sorted())
    }

    // MARK: - Labels

    @Test("Two destinations sharing a name get distinct blocks")
    func blockLabelsAreDisambiguated() throws {
        let ids = ["focus", "ford", "carter"]
        let flows = try index(collectionIds: ids, flows: [(0, 1, 20), (0, 2, 10)])
        let records = try authority([
            (id: "focus", name: "Focus", repository: nil),
            (id: "ford", name: "White House Central Files", repository: "Ford Library"),
            (id: "carter", name: "White House Central Files", repository: "Carter Library"),
        ])
        let data = ArchivalFlowsData.focused(
            on: try #require(records.record(id: "focus")), direction: .outgoing,
            index: flows, authority: records)
        #expect(Set(data.endpoints.map(\.label)).count == 2, """
            Both blocks read \(data.endpoints.map(\.label)). Measured over the 1,111 collections \
            in the flow vocabulary, 16 names are carried by more than one record and \
            `White House Central Files` is six of them.
            """)
        // Unique is not enough: the id fallback would also produce two distinct labels, and a
        // reader cannot tell `txt:ford|whcf` from `txt:carter|whcf`. The repository is what makes
        // the distinction legible, so it is what the test pins.
        #expect(data.endpoints.contains { $0.label.contains("Ford Library") }, """
            Labels are \(data.endpoints.map(\.label)). The repository is the disambiguator a \
            reader can actually use.
            """)
        #expect(data.endpoints.contains { $0.label.contains("Carter Library") })
    }

    // MARK: - Disclosure

    @Test("The footnote share is read off the artifact, never written down")
    func footnoteShareComesFromCoverage() throws {
        let flows = try index(collectionIds: ["a", "b"], flows: [(0, 1, 5)],
                              documentEdges: 200, footnoteEdges: 50)
        let records = try authority([(id: "a", name: "A", repository: nil),
                                     (id: "b", name: "B", repository: nil)])
        let data = ArchivalFlowsData.corpusWide(index: flows, authority: records)
        #expect(abs(data.footnoteShare - 0.25) < 0.0001, """
            The share came back \(data.footnoteShare) for an artifact reporting 50 of 200. \
            Hard-coding 95.3% would survive a regeneration that changed it.
            """)
        #expect(data.volumesWithEdges == 254)
        #expect(data.volumesScanned == 552)
    }

    @Test("An artifact reporting no edges yields a zero share rather than a division by zero")
    func zeroEdgesIsSafe() throws {
        let flows = try index(collectionIds: ["a", "b"], flows: [], documentEdges: 0,
                              footnoteEdges: 0)
        let records = try authority([(id: "a", name: "A", repository: nil),
                                     (id: "b", name: "B", repository: nil)])
        let data = ArchivalFlowsData.corpusWide(index: flows, authority: records)
        #expect(data.footnoteShare == 0)
        #expect(data.isEmpty)
    }

    @Test("Same-unit pairs never reach the diagram, in either view")
    func sameUnitPairsAreExcluded() throws {
        let flows = try index(collectionIds: ["a", "b"], flows: [(0, 0, 900), (0, 1, 3)])
        let records = try authority([(id: "a", name: "A", repository: nil),
                                     (id: "b", name: "B", repository: nil)])
        let corpus = ArchivalFlowsData.corpusWide(index: flows, authority: records)
        #expect(corpus.topPairs.count == 1)
        #expect(corpus.topPairs.first?.source.id == "a")
        #expect(corpus.topPairs.first?.target.id == "b")

        let focused = ArchivalFlowsData.focused(
            on: try #require(records.record(id: "a")), direction: .outgoing,
            index: flows, authority: records)
        #expect(!focused.endpoints.contains { $0.id == "a" })
        #expect(focused.sameUnitReferences == 900)
    }

    @Test("Focus candidates are only collections that appear in a between-unit flow")
    func focusCandidatesAreReachable() throws {
        let flows = try index(collectionIds: ["a", "b", "orphan"],
                              flows: [(0, 1, 30), (2, 2, 90)])
        let records = try authority([(id: "a", name: "A", repository: nil),
                                     (id: "b", name: "B", repository: nil),
                                     (id: "orphan", name: "Orphan", repository: nil)])
        let candidates = ArchivalFlowsData.focusCandidates(index: flows, authority: records)
        #expect(candidates.map(\.record.id) == ["a", "b"], """
            Offered \(candidates.map(\.record.id)). A collection whose only stored flow points \
            at itself has nothing to draw, and offering it leads straight to the empty state.
            """)
        #expect(candidates.allSatisfy { $0.references == 30 })
    }

    // MARK: - The shipped artifact

    @Test("The shipped flows resolve, rank, and reproduce the known heaviest hand-off")
    func shippedCorpusWide() throws {
        let flows = try #require(ProvenanceFlowIndexStore.shared)
        let records = try #require(CollectionAuthorityStore.shared)
        let data = ArchivalFlowsData.corpusWide(index: flows, authority: records)

        #expect(data.topPairs.count == ArchivalFlowsData.topPairCap)
        let heaviest = try #require(data.topPairs.first)
        #expect(heaviest.source.label == "NSC Files")
        #expect(heaviest.target.label.contains("Central Files 1970"), """
            The heaviest hand-off in the series is \(heaviest.source.label) → \
            \(heaviest.target.label). It should be Nixon's NSC Files → Central Files 1970–73.
            """)
        #expect(data.footnoteShare > 0.9, """
            Footnotes are \(data.footnoteShare) of these references, not the >90% every \
            disclosure on this surface is written around.
            """)
        // Every drawn label must resolve; an unresolved endpoint would render as a blank block.
        for pair in data.topPairs {
            #expect(!pair.source.label.isEmpty)
            #expect(!pair.target.label.isEmpty)
        }
    }

    @Test("The busiest focus fans out past the cap, which is why the remainder block exists")
    func shippedFanOutIsReal() throws {
        let flows = try #require(ProvenanceFlowIndexStore.shared)
        let records = try #require(CollectionAuthorityStore.shared)
        let umbrella = try #require(
            records.record(id: ArchivalCollectionsData.umbrellaCollectionId))
        let data = ArchivalFlowsData.focused(on: umbrella, direction: .outgoing,
                                             index: flows, authority: records)
        #expect(data.allEndpoints.count > ArchivalFlowsData.endpointCap * 5, """
            The busiest collection has \(data.allEndpoints.count) destinations. The design's \
            "no cap while focused" promise is honoured by folding, not by drawing them all — if \
            this ever dropped to a drawable number, the remainder block could go.
            """)
        #expect(data.endpoints.last?.isRemainder == true)
        #expect(data.endpoints.reduce(0) { $0 + $1.count } == data.totalReferences)
    }

    @Test("Every shipped focus's blocks carry unique labels")
    func shippedLabelsAreUnique() throws {
        let flows = try #require(ProvenanceFlowIndexStore.shared)
        let records = try #require(CollectionAuthorityStore.shared)
        let candidates = ArchivalFlowsData.focusCandidates(index: flows, authority: records)
            .prefix(20)
        var checked = 0
        for candidate in candidates {
            for direction in ArchivalFlowDirection.allCases {
                let data = ArchivalFlowsData.focused(on: candidate.record, direction: direction,
                                                     index: flows, authority: records)
                #expect(Set(data.endpoints.map(\.label)).count == data.endpoints.count,
                        "\(candidate.record.name) / \(direction.title) has a repeated block label")
                checked += 1
            }
        }
        #expect(checked == 40, "swept \(checked) combinations, not 40")
    }
}

// MARK: - ArchivalFlowsUnprintedLayerTests

/// The Flows mode's second layer (#784): footnote citations of material FRUS did not print.
///
/// The tests that matter are the ones that keep the two layers apart. They are the same claim
/// shape over different evidence, and the failure mode is not a crash — it is a diagram that adds
/// them, or copy from one describing the other.
///
/// Version history:
///   1.0 — Session 2026-08-10: #784
@Suite("Archival analytics — the unprinted layer (#784)")
struct ArchivalFlowsUnprintedLayerTests {

    // MARK: - Fixtures

    private func externalIndex(targetIds: [String], sourceIds: [String],
                               pairs: [(Int, Int, Int)],
                               targets: [(key: Int, volumes: [Int], counts: [Int])],
                               volumes: [String] = ["frus1955-57v19", "frus1958-60v03"],
                               referencesFound: Int = 120, referencesJoined: Int = 100,
                               referencesInherited: Int = 12) throws -> ExternalCitationIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1, "generated": "2026-08-10",
            "volumes": volumes, "targetIds": targetIds, "sourceIds": sourceIds,
            "targets": targets.map { ["k": $0.key, "v": $0.volumes, "n": $0.counts] },
            "pairs": pairs.map { ["f": $0.0, "t": $0.1, "n": $0.2] },
            "coverage": [
                "volumesScanned": 552, "volumesWithReferences": volumes.count,
                "documentsScanned": 314_479, "footnotesScanned": 470_827,
                "footnotesExcluded": 299_643, "headNestedExcluded": 31_301,
                "headNestedExcludedWithAnchor": 533,
                "referencesFound": referencesFound, "referencesInherited": referencesInherited,
                "absenceClaimsRefused": 140, "lotReferences": 60, "libraryReferences": 60,
                "referencesJoined": referencesJoined, "referencesWithBothEnds": 90,
                "sameUnitReferences": 30, "authorityCollectionCount": 4423,
            ],
        ]
        return try JSONDecoder().decode(
            ExternalCitationIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    private func authority(_ records: [(id: String, name: String, repository: String?)]) throws
        -> CollectionAuthorityIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1, "generated": "2026-08-10",
            "collections": records.map { record -> [String: Any] in
                var row: [String: Any] = ["id": record.id, "name": record.name]
                if let repository = record.repository { row["repository"] = repository }
                return row
            },
        ]
        return try JSONDecoder().decode(
            CollectionAuthorityIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    private func entries(_ spans: [(String, String, String)]) -> [String: VolumeManifestEntry] {
        Dictionary(uniqueKeysWithValues: spans.map { id, earliest, latest in
            (id, VolumeManifestEntry(
                volumeId: id, filename: "\(id).xml", subseries: "s", title: id,
                dateRange: DateRange(earliest: earliest, latest: latest),
                publicationDate: nil, status: .published, editors: [], generalEditor: nil,
                documentCount: 0, sizeBytes: 0, tags: []))
        })
    }

    // MARK: - The derivation

    @Test("A focused collection's outgoing citations become endpoint blocks")
    func buildsFocusedEndpoints() throws {
        let index = try externalIndex(
            targetIds: ["lot:63D351", "txt:johnson library|national security file"],
            sourceIds: ["lot:60D627"],
            pairs: [(0, 0, 40), (0, 1, 15)],
            targets: [(0, [0, 1], [30, 10]), (1, [0], [15])])
        let auth = try authority([
            ("lot:60D627", "Conference Files", "Department of State"),
            ("lot:63D351", "S/S–NSC Files", "Department of State"),
            ("txt:johnson library|national security file", "National Security File", "Johnson Library"),
        ])
        let focus = try #require(auth.record(id: "lot:60D627"))

        let data = ArchivalFlowsData.focusedExternal(
            on: focus, direction: .outgoing, index: index, authority: auth,
            entriesById: entries([("frus1955-57v19", "1955-01-01", "1957-12-31"),
                                  ("frus1958-60v03", "1958-01-01", "1960-12-31")]))
        #expect(data.layer == .toUnprinted)
        #expect(data.endpoints.map(\.label) == ["S/S–NSC Files", "National Security File"])
        #expect(data.totalReferences == 55)
    }

    @Test("The layer carries its own disclosures and none of the printed layer's")
    func carriesItsOwnDisclosures() throws {
        let index = try externalIndex(
            targetIds: ["lot:63D351"], sourceIds: ["lot:60D627"],
            pairs: [(0, 0, 40)], targets: [(0, [0], [40])],
            referencesFound: 19_800, referencesJoined: 19_011, referencesInherited: 1_780)
        let auth = try authority([
            ("lot:60D627", "Conference Files", "Department of State"),
            ("lot:63D351", "S/S–NSC Files", "Department of State"),
        ])
        let data = ArchivalFlowsData.corpusWideExternal(
            index: index, authority: auth,
            entriesById: entries([("frus1955-57v19", "1955-01-01", "1957-12-31"),
                                  ("frus1958-60v03", "1958-01-01", "1960-12-31")]))
        let facts = try #require(data.externalFacts)
        #expect(facts.referencesFound == 19_800)
        #expect(facts.referencesJoined == 19_011)
        #expect(abs(facts.inheritedShare - 1_780.0 / 19_800.0) < 0.0001)
        #expect(data.classBetweenReferences == 0, """
            The printed layer's class-exclusion caveat describes `provenance-flow-index.json`. \
            Carrying a non-zero here would put a sentence about central-file classes under a \
            table that has nothing to do with them.
            """)
        #expect(data.footnoteShare == 0, """
            Every citation on this layer is a footnote, so "95.3% are footnotes" is not the \
            disclosure it owes; the view branches on `layer`, not on this number.
            """)
    }

    @Test("The era span is read off the manifest, not predicted")
    func statesTheEraItActuallyCovers() throws {
        let index = try externalIndex(
            targetIds: ["lot:63D351"], sourceIds: ["lot:60D627"],
            pairs: [(0, 0, 40)], targets: [(0, [0, 1], [20, 20])])
        let auth = try authority([
            ("lot:60D627", "Conference Files", "Department of State"),
            ("lot:63D351", "S/S–NSC Files", "Department of State"),
        ])
        let data = ArchivalFlowsData.corpusWideExternal(
            index: index, authority: auth,
            entriesById: entries([("frus1955-57v19", "1955-01-01", "1957-12-31"),
                                  ("frus1958-60v03", "1958-01-01", "1960-12-31")]))
        #expect(data.externalFacts?.eraSpan == 1955...1960, """
            #784's case rests on this harvest reaching 1910–1945. At the scope the same issue \
            mandates it does not, so the surface states the span the data has. A hard-coded era \
            sentence is exactly what this replaces.
            """)
    }

    @Test("A self-referencing collection is counted and excluded, never silently dropped")
    func excludesSameUnitEdgesAndSaysSo() throws {
        let index = try externalIndex(
            targetIds: ["lot:60D627", "lot:63D351"], sourceIds: ["lot:60D627"],
            pairs: [(0, 0, 25), (0, 1, 40)],
            targets: [(0, [0], [25]), (1, [0], [40])])
        let auth = try authority([
            ("lot:60D627", "Conference Files", "Department of State"),
            ("lot:63D351", "S/S–NSC Files", "Department of State"),
        ])
        let focus = try #require(auth.record(id: "lot:60D627"))
        let data = ArchivalFlowsData.focusedExternal(
            on: focus, direction: .outgoing, index: index, authority: auth,
            entriesById: entries([("frus1955-57v19", "1955-01-01", "1957-12-31")]))
        #expect(data.endpoints.map(\.label) == ["S/S–NSC Files"])
        #expect(data.sameUnitReferences == 25,
                "the diagram excludes it; the caption states it")
    }

    @Test("The focus picker offers only collections this layer actually has")
    func focusCandidatesComeFromThisLayer() throws {
        // `lot:77D777` appears in exactly one pair, and it points at itself. The mutation sweep is
        // why the fixture carries it: without a self-only collection, dropping the self-edge guard
        // changes nothing and the filter is untested — which is what M10 showed.
        let index = try externalIndex(
            targetIds: ["lot:63D351", "lot:77D777"],
            sourceIds: ["lot:60D627", "lot:77D777"],
            pairs: [(0, 0, 40), (1, 1, 10)],
            targets: [(0, [0], [40]), (1, [0], [10])])
        let auth = try authority([
            ("lot:60D627", "Conference Files", "Department of State"),
            ("lot:63D351", "S/S–NSC Files", "Department of State"),
            ("lot:77D777", "A collection that only cites itself", "Department of State"),
            ("lot:99D999", "A collection no footnote cites", "Department of State"),
        ])
        let candidates = ArchivalFlowsData.externalFocusCandidates(index: index, authority: auth)
        #expect(candidates.map(\.record.id).sorted() == ["lot:60D627", "lot:63D351"], """
            Two ways to land a reader on an empty diagram with no explanation: a collection the \
            printed layer knows but no footnote cites, and one whose only citations point back \
            into itself — which the diagram excludes by design.
            """)
    }
}
