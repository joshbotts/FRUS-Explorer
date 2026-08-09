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

import CoreGraphics
import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ArchivalNetworkBuilderTests

/// The Network mode's neighbourhood derivation and its deterministic layout (#765 stage 2).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
@Suite("Archival analytics — network derivation")
struct ArchivalNetworkBuilderTests {

    // MARK: - Fixtures

    private func record(_ id: String, name: String, repository: String? = nil,
                        lot: String? = nil, volumes: [String]) -> AuthorityCollectionRecord {
        AuthorityCollectionRecord(id: id, name: name, repository: repository, lotFileNorm: lot,
                                  volumeIds: volumes)
    }

    private func usage(volumes: [String],
                       collections: [(String, [Int], [Int])],
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
            "schemaVersion": 1, "generated": "2026-08-09", "volumes": volumes,
            "volumeNoteCounts": volumes.map { _ in 0 },
            "collectionIds": collectionIds, "classKeys": classKeys, "categories": [],
            "collections": rows(collections, keys: collectionIds),
            "classes": rows(classes, keys: classKeys), "volumeCategories": [],
            "coverage": ["volumesScanned": volumes.count, "volumesWithNotes": volumes.count,
                          "noteCount": 0, "notesInACollection": 0, "notesWithAClassKey": 0,
                          "authorityCollectionCount": collectionIds.count,
                          "authorityCollectionsReached": collectionIds.count],
        ]
        return try JSONDecoder().decode(
            CollectionUsageIndex.self,
            from: try JSONSerialization.data(withJSONObject: payload))
    }

    // MARK: - The measure the design specified does not survive its own data

    @Test("A tiny subset collection does not outrank a real neighbour")
    func smallSubsetsDoNotWin() {
        // This is the defect that forced the measure change. Under the approved overlap
        // coefficient (shared ÷ the SMALLER list), `tiny` scores exactly 1.000 — the maximum —
        // because both of its volumes are inside the focus's. Measured on the shipped authority,
        // that is not an edge case: the top eight neighbours of the Whitman File under that
        // weighting are all two-to-seven-volume lot files at 1.000, and no threshold removes
        // them, because they sit at the top of the scale.
        let focus = record("f", name: "Focus", volumes: (1...20).map { "v\($0)" })
        let tiny = record("tiny", name: "Tiny", volumes: ["v1", "v2"])
        let peer = record("peer", name: "Peer", volumes: (1...18).map { "v\($0)" })
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, tiny, peer], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(graph.nodes.first?.id == "peer", """
            The strongest neighbour is \(graph.nodes.first?.id ?? "none"). `tiny` shares two of \
            the focus's twenty volumes and `peer` shares eighteen; a measure that ranks tiny \
            first is measuring smallness.
            """)
        let tinyStrength = graph.nodes.first { $0.id == "tiny" }?.relativeStrength ?? 1
        #expect(tinyStrength < 0.3, "tiny scored \(tinyStrength) of the strongest link")
    }

    @Test("The threshold is relative, so one slider serves both measures")
    func thresholdIsRelative() throws {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3", "v4"])
        let strong = record("strong", name: "Strong", volumes: ["v1", "v2", "v3", "v4"])
        let weak = record("weak", name: "Weak", volumes: ["v1", "v2", "x1", "x2", "x3", "x4"])
        let all = [focus, strong, weak]

        let wide = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0.1, expansion: .collapsed)
        #expect(wide.nodes.count == 2)
        #expect(wide.nodes.first?.relativeStrength == 1.0, "the strongest link is the unit")

        let narrow = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0.5, expansion: .collapsed)
        #expect(narrow.nodes.map(\.id) == ["strong"], """
            Raising the threshold left \(narrow.nodes.map(\.id)). The weak partner scores a \
            quarter of the strong one and must drop out at a half.
            """)
        #expect(narrow.partnersTotal == 2, "the total is what was co-cited, not what survived")
        #expect(narrow.nodesAboveThreshold == 1)
    }

    @Test("The two measures rank differently, which is why both are offered")
    func measuresDisagree() throws {
        // `broad` shares more volumes; `deep` supplies far more documents to the ones it shares.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3", "v4"])
        let broad = record("broad", name: "Broad", volumes: ["v1", "v2", "v3", "v4"])
        let deep = record("deep", name: "Deep", volumes: ["v1", "v2", "x1", "x2"])
        let index = try usage(volumes: ["v1", "v2", "v3", "v4", "x1", "x2"], collections: [
            ("f", [0, 1, 2, 3], [500, 500, 5, 5]),
            ("broad", [0, 1, 2, 3], [1, 1, 5, 5]),
            ("deep", [0, 1], [400, 400]),
        ])
        let all = [focus, broad, deep]

        let byVolumes = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: index, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(byVolumes.nodes.first?.id == "broad")

        let byDocuments = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(byDocuments.nodes.first?.id == "deep", """
            Under the document measure the strongest neighbour is \
            \(byDocuments.nodes.first?.id ?? "none"). `deep` supplies 800 documents to the two \
            volumes it shares and `broad` supplies 12 to four — if the two measures agreed here, \
            one of them would be redundant.
            """)
    }

    @Test("A partner sharing one volume is not a neighbour")
    func oneSharedVolumeIsNotEvidence() {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3"])
        let coincidence = record("c", name: "Coincidence", volumes: ["v1"])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, coincidence], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(graph.nodes.isEmpty, """
            One shared volume is a coincidence of compilation, and 2,846 shipped records cite \
            exactly one volume — the same floor #762 applies for the same reason.
            """)
    }

    @Test("A focus citing one volume has no neighbourhood at all")
    func singleVolumeFocusIsEmpty() {
        let focus = record("f", name: "Focus", volumes: ["v1"])
        let other = record("o", name: "Other", volumes: ["v1", "v2"])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, other], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(graph.nodes.isEmpty)
        #expect(graph.partnersTotal == 0)
    }

    // MARK: - The cap discloses

    @Test("The cap is per custodian, so a crowded sector cannot crowd out a quiet one")
    func capIsPerSector() {
        // Twenty lot files and one presidential library. A global top-N ranked by strength would
        // drop the library; the per-sector cap is what keeps every custodian on screen.
        let focus = record("f", name: "Focus", volumes: (1...20).map { "v\($0)" })
        var all = [focus]
        for index in 1...20 {
            all.append(record("lot\(index)", name: "Lot \(index)", lot: "L\(index)",
                              volumes: (1...19).map { "v\($0)" }))
        }
        all.append(record("lib", name: "Library", repository: "Ford Library",
                          volumes: ["v1", "v2", "v3"]))
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)

        let lots = graph.nodes.count { $0.category == .lotFile }
        #expect(lots == ArchivalNetworkGraph.sectorCap, "drew \(lots) lot files")
        #expect(graph.nodes.contains { $0.id == "lib" }, """
            The one presidential library was dropped. Twenty lot files all outrank it, so a \
            global cap would lose the only node in its quadrant — which is the whole reason the \
            cap is per sector.
            """)
        #expect(graph.isCapped)
        #expect(graph.withheldCount == 21 - graph.nodes.count, """
            Withheld \(graph.withheldCount) of \(graph.nodesAboveThreshold) above the threshold. \
            A cap that does not say what it withheld is the silent truncation the design forbids.
            """)
    }

    @Test("The disclosure's numerator and denominator count the same population")
    func capCountsAreCommensurable() throws {
        // The first draft put the drawn nodes — class squares included — over a count of
        // collections only, so an expanded umbrella could report drawing more collections than
        // were co-cited at all.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [10, 10]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [900, 900]),
        ], classes: [("763.72", [0, 1], [40, 30]), ("890.00", [0, 1], [20, 10])])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: index, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        #expect(graph.nodes.count <= graph.nodesAboveThreshold, """
            Drew \(graph.nodes.count) of \(graph.nodesAboveThreshold). The numerator counts \
            squares and circles alike, so the denominator must too.
            """)
        #expect(graph.classNodeCount == 2)
        #expect(graph.partnersTotal == 1, "one collection is co-cited, whatever is drawn from it")
    }

    @Test("Class squares obey the threshold slider, like every other node")
    func classesObeyTheThreshold() throws {
        // Measured on the shipped artifacts, 23 of the 40 most-cited foci drew class squares
        // below their own threshold before this was fixed — the slider governed half the graph.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3", "v4"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2", "v3", "v4"])
        let index = try usage(volumes: ["v1", "v2", "v3", "v4"], collections: [
            ("f", [0, 1, 2, 3], [100, 100, 100, 100]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1, 2, 3], [90, 90, 90, 90]),
        ], classes: [("763.72", [0, 1, 2, 3], [80, 80, 80, 80]), ("890.00", [0, 1], [2, 1])])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0.5, expansion: .decimalClasses)
        for node in graph.nodes {
            #expect(node.relativeStrength >= 0.5 - 0.0001,
                    "\(node.name) is drawn at \(node.relativeStrength), below the threshold")
        }
        #expect(!graph.nodes.contains { $0.name == "890.00" })
    }

    @Test("A class stronger than every collection does not clamp to the maximum")
    func classesShareTheStrengthScale() throws {
        // On `Conference Files, Lot 60 D 627` four classes exceeded the strongest collection, the
        // largest by 76%. Normalising them against a collection-only maximum clamped all four to
        // 1.0, so they drew at identical size and identical radius, on top of the focus disc.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        let small = record("small", name: "Small Partner", volumes: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [500, 500]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [400, 400]),
            ("small", [0, 1], [10, 10]),
        ], classes: [("763.72", [0, 1], [300, 300]), ("890.00", [0, 1], [60, 60])])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella, small], usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        let strengths = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.name, $0.relativeStrength) })
        #expect(strengths["763.72"] == 1.0, "the strongest node of either kind is the unit")
        let strongestCollection = strengths["Small Partner"] ?? 0
        #expect(strongestCollection < 1.0)
        #expect(graph.strongestMeasureValue == 600, """
            The rings are drawn as fractions of \(graph.strongestMeasureValue), but the strongest \
            drawn node supplies 600 jointly. A ring legend that misquotes its own maximum is \
            worse than no legend.
            """)
    }

    @Test("The class cap binds, and binds separately from the sector caps")
    func classCapBinds() throws {
        // Survived the first sweep: nothing asserted the class cap at all, so raising it to 100
        // changed no test. Ten classes would crowd the State wedge they share a sub-arc with.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        let keys = (1...12).map { "76\($0).72" }
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [500, 500]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [400, 400]),
        ], classes: keys.enumerated().map { ($0.element, [0, 1], [50 - $0.offset, 50 - $0.offset]) })
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        #expect(graph.classNodeCount == ArchivalNetworkGraph.classCap,
                "drew \(graph.classNodeCount) classes, cap is \(ArchivalNetworkGraph.classCap)")
        #expect(graph.isCapped, "twelve classes passed the threshold and six were withheld")
    }

    @Test("Among equals the narrower partner wins, because it is the more specific claim")
    func specificityTieBreak() throws {
        // Survived the first sweep: every earlier fixture separated its candidates on value or
        // shared count, so reversing this comparator changed nothing.
        //
        // The tie is only reachable under the DOCUMENT measure. Jaccard puts the partner's own
        // breadth in its denominator, so two partners of different breadth can never tie on it —
        // the volume measure cannot test this comparator at all.
        //
        // Both share two volumes and supply 100 documents each; they differ only in how widely
        // they are otherwise cited. They are named so the alphabetical fallback would order them
        // the OTHER way, or a later tie-break could pass this test for the wrong reason.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3", "v4"])
        let broad = record("a", name: "A Broad",
                           volumes: ["v1", "v2", "x1", "x2", "x3", "x4"])
        let narrow = record("z", name: "Z Narrow", volumes: ["v1", "v2", "y1"])
        let index = try usage(volumes: ["v1", "v2", "v3", "v4", "x1", "x2", "x3", "x4", "y1"],
                              collections: [
                                  ("f", [0, 1], [100, 100]),
                                  ("a", [0, 1], [100, 100]),
                                  ("z", [0, 1], [100, 100]),
                              ])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, broad, narrow], usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0, expansion: .collapsed)

        #expect(graph.nodes.count == 2)
        #expect(graph.nodes[0].measureValue == graph.nodes[1].measureValue,
                "the fixture must tie on the measure or it tests nothing")
        #expect(graph.nodes[0].sharedVolumeCount == graph.nodes[1].sharedVolumeCount,
                "and on shared volumes, or the earlier comparator decides it")
        #expect(graph.nodes.map(\.id) == ["z", "a"], """
            Ranked \(graph.nodes.map(\.id)). Among partners equal on evidence, the one drawn on \
            by fewer volumes is the more specific claim about this focus — and `a` sorts first \
            alphabetically, so a missing breadth comparator would put it first.
            """)
    }

    @Test("Three records sharing a name and a repository still get three distinct labels")
    func lastResortDisambiguation() {
        // Survived two sweeps before this fixture was right. With only TWO colliding records the
        // fallback is untested: dropping it leaves "Conference Files · Department of State" and a
        // bare "Conference Files", which are still distinct. It takes a THIRD record for the
        // missing id to collide with the second — the same trap as naming a tie-break fixture in
        // the expected order.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3"])
        let all = [focus] + ["a", "b", "c"].map {
            record("txt:state|\($0)", name: "Conference Files",
                   repository: "Department of State", volumes: ["v1", "v2", "v3"])
        }
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(graph.nodes.count == 3)
        #expect(Set(graph.nodes.map(\.label)).count == 3, """
            The three nodes are labelled \(graph.nodes.map(\.label)). When the repository cannot \
            separate records sharing a name, the id must — and it must do so for every one of \
            them, not just the first collision.
            """)
    }

    @Test("The ranking is a total order, so the same focus always draws the same graph")
    func rankingIsDeterministic() {
        // Two partners identical in every measured respect: only the id can separate them, and
        // it must, or the cap would keep a different one on each launch.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3"])
        let a = record("aaa", name: "Same Name", volumes: ["v1", "v2", "v3"])
        let b = record("bbb", name: "Same Name", volumes: ["v1", "v2", "v3"])
        let first = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, a, b], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        let second = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, b, a], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(first.nodes.map(\.id) == second.nodes.map(\.id))
        #expect(first.nodes.map(\.id) == ["aaa", "bbb"])
    }

    @Test("Two collections sharing a name get distinct labels")
    func labelsAreDisambiguated() {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3"])
        let ford = record("txt:ford|whcf", name: "White House Central Files",
                          repository: "Ford Library", volumes: ["v1", "v2", "v3"])
        let carter = record("txt:carter|whcf", name: "White House Central Files",
                            repository: "Carter Library", volumes: ["v1", "v2", "v3"])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, ford, carter], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(Set(graph.nodes.map(\.label)).count == 2, """
            Both nodes are labelled \(graph.nodes.map(\.label)). `White House Central Files` is \
            six distinct records on the shipped authority; two identical circles in one sector \
            cannot be told apart, and the reader has no way to know which one they tapped.
            """)
        #expect(graph.nodes.allSatisfy { $0.name == "White House Central Files" })
    }

    // MARK: - Umbrella expansion

    @Test("Expanding the umbrella replaces its circle with class squares")
    func umbrellaExpandsToClasses() throws {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", repository: "Department of State",
                              volumes: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [10, 10]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [900, 900]),
        ], classes: [("763.72", [0, 1], [40, 30]), ("POL 27 VIET S", [0, 1], [5, 5])])
        let all = [focus, umbrella]

        let collapsed = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: index, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        #expect(collapsed.nodes.map(\.id) == [ArchivalCollectionsData.umbrellaCollectionId])
        #expect(collapsed.expandedUmbrella == nil)

        let expanded = ArchivalNetworkBuilder.graph(
            focus: focus, in: all, usage: index, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        #expect(!expanded.nodes.contains { $0.id == ArchivalCollectionsData.umbrellaCollectionId },
                "the umbrella circle must be gone once its inside is on screen")
        #expect(expanded.expandedUmbrella?.name == "Central Files")
        let classes = expanded.nodes.filter { $0.kind == .centralFileClass }
        #expect(classes.map(\.name) == ["763.72"], """
            The decimal lens drew \(classes.map(\.name)). A subject-numeric designator is a \
            different filing system and belongs to the other lens.
            """)
        #expect(classes.allSatisfy { $0.category == .stateDepartment }, """
            A central-file class is a heading inside the Department's own filing system. Any \
            other sector would put it under a custodian that does not hold it.
            """)
    }

    @Test("The subject-numeric lens folds leaves to category and number")
    func subjectNumericIsFolded() throws {
        // At leaf grain the lens is unrankable — measured under #763, 691 of 1,362 keys carry a
        // single document. Folded, `POL 27 VIET S` and `POL 27 ARAB-ISR` are one group.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [10, 10]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [900, 900]),
        ], classes: [("POL 27 VIET S", [0, 1], [8, 8]), ("POL 27 ARAB-ISR", [0, 1], [6, 6]),
                     ("763.72", [0, 1], [50, 50])])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: index, measure: .sharedDocuments,
            minimumRelativeStrength: 0, expansion: .subjectNumeric)
        let classes = graph.nodes.filter { $0.kind == .centralFileClass }
        #expect(classes.map(\.name) == ["POL 27"], """
            Drew \(classes.map(\.name)). The two POL 27 leaves must fold into one group, and the \
            decimal class belongs to the other lens.
            """)
        // The focus supplies 10 documents to each of v1 and v2. The POL 27 group supplies
        // 8 + 6 = 14 to each. The joint total is min(10, 14) per volume = 20 — NOT 28, which is
        // what taking a separate min() per leaf key produced: two leaves in one volume each
        // clipped against the same focus contribution and were then added, so a group could claim
        // more jointly-supplied documents than the focus contributed at all.
        #expect(classes.first?.sharedDocumentCount == 20, """
            The fold reported \(classes.first?.sharedDocumentCount ?? -1). It must clip once per \
            volume, after summing the leaves, or the number exceeds what either side supplied.
            """)
    }

    @Test("An expansion that yields no class leaves the umbrella circle in place")
    func emptyExpansionKeepsTheUmbrella() throws {
        // Deleting the circle before knowing whether anything replaced it produced a graph that
        // said "No Co-Cited Collections" about a collection that had passed the threshold.
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        // Only a subject-numeric key exists, and the decimal lens asks for decimals.
        let index = try usage(volumes: ["v1", "v2"], collections: [
            ("f", [0, 1], [10, 10]),
            (ArchivalCollectionsData.umbrellaCollectionId, [0, 1], [900, 900]),
        ], classes: [("POL 27 VIET S", [0, 1], [5, 5])])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: index, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        #expect(graph.nodes.map(\.id) == [ArchivalCollectionsData.umbrellaCollectionId])
        #expect(graph.expandedUmbrella == nil, "nothing replaced it, so nothing was expanded")
    }

    @Test("Without the usage index the umbrella cannot expand, and does not pretend to")
    func expansionNeedsTheUsageIndex() {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2"])
        let umbrella = record(ArchivalCollectionsData.umbrellaCollectionId,
                              name: "Central Files", volumes: ["v1", "v2"])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, umbrella], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .decimalClasses)
        #expect(graph.nodes.isEmpty || graph.nodes.allSatisfy { $0.kind == .collection })
    }

    // MARK: - Layout

    @Test("Each custodian gets its own quadrant, and nothing lands on top of the focus")
    func layoutSeparatesSectors() {
        let focus = record("f", name: "Focus", repository: "Department of State",
                           volumes: ["v1", "v2", "v3", "v4"])
        let partners = [
            record("s", name: "State", repository: "Department of State",
                   volumes: ["v1", "v2", "v3", "v4"]),
            record("l", name: "Lot", lot: "63D351", volumes: ["v1", "v2", "v3"]),
            record("p", name: "Library", repository: "Ford Library", volumes: ["v1", "v2", "v3"]),
            record("o", name: "Other", repository: "National Archives", volumes: ["v1", "v2"]),
        ]
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus] + partners, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        let layout = ArchivalNetworkBuilder.layout(graph, in: CGSize(width: 600, height: 600))

        #expect(layout.positions[focus.id] == layout.center)
        for node in graph.nodes {
            let position = try? #require(layout.positions[node.id])
            guard let position else { continue }
            let dx = position.x - layout.center.x
            let dy = position.y - layout.center.y
            // Screen y grows downward: State is west-north, lots north-east, libraries
            // south-east, everything else south-west.
            switch node.category {
            case .stateDepartment: #expect(dx < 0, "State left of centre")
            case .lotFile: #expect(dy < 0, "lots above centre")
            case .presidentialLibrary: #expect(dx > 0, "libraries right of centre")
            case .otherInstitution: #expect(dy > 0, "other below centre")
            }
            #expect(hypot(dx, dy) > 30, "\(node.id) overlaps the focus node")
        }
    }

    @Test("A stronger link sits nearer the centre, and the rings mark real fractions")
    func layoutMapsStrengthToRadius() {
        let focus = record("f", name: "Focus", volumes: (1...10).map { "v\($0)" })
        let near = record("near", name: "Near", volumes: (1...10).map { "v\($0)" })
        let far = record("far", name: "Far", volumes: ["v1", "v2"] + (1...20).map { "x\($0)" })
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, near, far], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        let layout = ArchivalNetworkBuilder.layout(graph, in: CGSize(width: 600, height: 600))
        let nearRadius = hypot((layout.positions["near"]?.x ?? 0) - layout.center.x,
                               (layout.positions["near"]?.y ?? 0) - layout.center.y)
        let farRadius = hypot((layout.positions["far"]?.x ?? 0) - layout.center.x,
                              (layout.positions["far"]?.y ?? 0) - layout.center.y)
        #expect(nearRadius < farRadius, """
            The stronger link sits at \(nearRadius) and the weaker at \(farRadius). Distance from \
            the centre is the whole radial encoding; inverting it inverts the reading.
            """)
        #expect(layout.ringFractions == [0.75, 0.50, 0.25])
        #expect(layout.ringRadii == layout.ringRadii.sorted(), "rings grow outward as strength falls")
    }

    @Test("The layout is a pure function of its inputs")
    func layoutIsDeterministic() {
        let focus = record("f", name: "Focus", volumes: ["v1", "v2", "v3"])
        let partner = record("p", name: "Partner", volumes: ["v1", "v2", "v3"])
        let graph = ArchivalNetworkBuilder.graph(
            focus: focus, in: [focus, partner], usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0, expansion: .collapsed)
        let size = CGSize(width: 480, height: 520)
        #expect(ArchivalNetworkBuilder.layout(graph, in: size)
                == ArchivalNetworkBuilder.layout(graph, in: size), """
                The design's direction 2a is a deterministic layout precisely so that two \
                readers comparing screens are comparing the same picture.
                """)
    }

    @Test("Node radius grows with strength and stays inside a tappable range")
    func radiusRange() {
        let weak = ArchivalNetworkNode(id: "w", label: "W", name: "W", kind: .collection,
                                       category: .lotFile, sharedVolumeCount: 2,
                                       sharedDocumentCount: 0, measureValue: 0.1,
                                       relativeStrength: 0)
        let strong = ArchivalNetworkNode(id: "s", label: "S", name: "S", kind: .collection,
                                         category: .lotFile, sharedVolumeCount: 20,
                                         sharedDocumentCount: 90, measureValue: 1,
                                         relativeStrength: 1)
        #expect(ArchivalNetworkBuilder.radius(for: weak) >= 11)
        #expect(ArchivalNetworkBuilder.radius(for: strong) <= 22)
        #expect(ArchivalNetworkBuilder.radius(for: strong)
                > ArchivalNetworkBuilder.radius(for: weak))
    }

    // MARK: - The shipped artifacts

    private static let shipped: [AuthorityCollectionRecord] =
        CollectionAuthorityStore.shared?.collections ?? []

    @Test("On the shipped authority the measure surfaces real neighbourhoods, not small records")
    func shippedNeighbourhoodsAreLegible() throws {
        let records = Self.shipped
        try #require(!records.isEmpty)
        let whitman = try #require(records.first { $0.name == "Whitman File" })
        let graph = ArchivalNetworkBuilder.graph(
            focus: whitman, in: records, usage: CollectionUsageIndexStore.shared,
            measure: .sharedVolumes, minimumRelativeStrength: 0.25, expansion: .collapsed)

        #expect(!graph.nodes.isEmpty)
        #expect(graph.nodes.count
                <= ArchivalNetworkGraph.sectorCap * ArchivalRepositoryCategory.allCases.count)
        // The Eisenhower-era State/White House circuit. Under the overlap coefficient the top of
        // this list was `MID Files, Lot 57 D 59` — two volumes, zero documents in common.
        let top = graph.nodes.prefix(8).map(\.name)
        #expect(top.contains { $0.contains("Dulles") } || top.contains { $0.contains("S/S–NSC") },
                "the strongest neighbours are \(top); neither the Dulles Papers nor the S/S–NSC files appear")
        for node in graph.nodes {
            #expect(node.sharedVolumeCount >= ArchivalNetworkBuilder.minimumSharedVolumes)
            #expect(node.relativeStrength >= 0.25 - 0.0001)
            #expect(node.relativeStrength <= 1)
        }
    }

    @Test("Every drawn label is unique, for every focus a reader is likely to open")
    func shippedLabelsAreUnique() throws {
        let records = Self.shipped
        try #require(!records.isEmpty)
        // The twelve most widely cited collections — the ones the picker offers first.
        let candidates = records
            .sorted { $0.volumeIds.count > $1.volumeIds.count }
            .prefix(12)
        var checked = 0
        for focus in candidates {
            for measure in ArchivalEdgeMeasure.allCases {
                let graph = ArchivalNetworkBuilder.graph(
                    focus: focus, in: records, usage: CollectionUsageIndexStore.shared,
                    measure: measure, minimumRelativeStrength: 0.25, expansion: .collapsed)
                #expect(Set(graph.nodes.map(\.label)).count == graph.nodes.count,
                        "\(focus.name) / \(measure.title) has a repeated label")
                checked += 1
            }
        }
        #expect(checked == 24, "swept \(checked) combinations, not 24")
    }

    @Test("The cap really does bind on the shipped data, which is why it exists")
    func shippedCapBinds() throws {
        let records = Self.shipped
        try #require(!records.isEmpty)
        let umbrella = try #require(
            records.first { $0.id == ArchivalCollectionsData.umbrellaCollectionId })
        let graph = ArchivalNetworkBuilder.graph(
            focus: umbrella, in: records, usage: nil, measure: .sharedVolumes,
            minimumRelativeStrength: 0.25, expansion: .collapsed)
        #expect(graph.isCapped, """
            The Central Files umbrella no longer exceeds the sector caps. The design's "no hard \
            cap" position was overturned by that measurement; if it has stopped being true, \
            revisit the decision rather than inherit it.
            """)
        for category in ArchivalRepositoryCategory.ordered {
            let drawn = graph.nodes.count { $0.category == category }
            #expect(drawn <= ArchivalNetworkGraph.sectorCap,
                    "\(category) drew \(drawn), past the per-sector cap")
        }
    }
}

// MARK: - ArchivalNetworkWiringTests

/// The two structural properties of the Network view that no derivation test can see (#765).
///
/// Both exist because the view shipped with them broken and the suite stayed green: the mode
/// drew nothing at all, and the derivation tests could not tell.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
@Suite("Archival analytics — network view wiring")
struct ArchivalNetworkWiringTests {

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The canvas size never round-trips through state the drawn branch alone can write")
    func layoutDoesNotDeadlock() throws {
        // The defect: `layout` was a computed property gated on a `@State canvasSize`, and the
        // ONLY writer of that state was a GeometryReader inside the branch `layout` gated. The
        // branch could never be constructed, the size stayed zero, and the Network mode drew a
        // spinner forever on every device. The layout is now derived from the GeometryReader's
        // own proxy, so there is no cycle to re-enter.
        let source = try Self.source("Analytics/ArchivalNetworkView.swift")
        #expect(!source.contains("canvasSize"), """
            `canvasSize` is back. If the canvas size is stored in state, check that something \
            OUTSIDE the branch which consumes it can write it — otherwise the mode renders \
            nothing and every derivation test still passes.
            """)
        #expect(source.contains("let layout = ArchivalNetworkBuilder.layout(graph, in: geometry.size)"),
                "the layout must come from the GeometryReader proxy")
    }

    @Test("The focus picker carries the #498 status-bar preference")
    func focusPickerIsProtected() throws {
        // The picker hosts a `.searchable` field inside a sheet's own NavigationStack — the exact
        // shape that wedges under rotation. BrowserView's own comment names this surface: "the
        // Network mode's focus search would silently re-open the defect".
        let source = try Self.source("Analytics/ArchivalNetworkView.swift")
        let sheet = try #require(source.range(of: ".sheet(isPresented: $isChoosingFocus)"))
        let window = source[sheet.lowerBound...].prefix(600)
        #expect(window.contains("statusBarHidden(false)"), """
            The focus picker sheet does not author the status-bar preference. #498 measured \
            29,040,997 AttributeGraph cycle detections and a hang from this exact shape.
            """)
    }
}
