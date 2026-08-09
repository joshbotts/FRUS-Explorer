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

// MARK: - ProvenanceFlowIndexTests

/// The shipped `provenance-flow-index.json` (#764) and its reader.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
@Suite("Provenance flow index — artifact")
struct ProvenanceFlowIndexTests {

    private func index() throws -> ProvenanceFlowIndex {
        try #require(ProvenanceFlowIndexStore.shared, """
            provenance-flow-index.json must decode from the app bundle. If it was just \
            regenerated it needs `xcodegen generate` to be enrolled — followed by \
            `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.
            """)
    }

    // MARK: - Shape

    @Test("The artifact decodes, and every row points inside its vocabulary")
    func shape() throws {
        let flows = try index()
        #expect(flows.schemaVersion == 1)
        #expect(flows.collectionIds == flows.collectionIds.sorted())
        #expect(flows.classKeys == flows.classKeys.sorted())
        var checked = 0
        for (label, rows, vocabulary) in [
            ("collections", flows.collectionFlows, flows.collectionIds),
            ("classes", flows.classFlows, flows.classKeys),
        ] {
            for row in rows {
                #expect(vocabulary.indices.contains(row.source), "\(label): source out of range")
                #expect(vocabulary.indices.contains(row.target), "\(label): target out of range")
                #expect(row.count > 0, "\(label): a stored flow with no references")
                checked += 1
            }
        }
        #expect(checked > 5_000, "guard is vacuous — only \(checked) rows checked")
    }

    @Test("Every collection endpoint exists in the shipped authority")
    func endpointsJoinToTheAuthority() throws {
        // The same staleness trap #763 closed: the flow index and the authority are generated
        // independently, and a fold like #696's "president's " → "presidential " silently strands
        // whole collections if the two are built against different clusterings.
        let flows = try index()
        let authority = try #require(CollectionAuthorityStore.shared)
        let known = Set(authority.collections.map(\.id))
        let orphans = flows.collectionIds.filter { !known.contains($0) }
        #expect(orphans.isEmpty, """
            \(orphans.count) flow endpoints are absent from collection-authority.json — the two \
            artifacts were built against different clusterings. First few: \
            \(orphans.prefix(5).joined(separator: ", "))
            """)
    }

    // MARK: - Coverage tells the truth about itself

    @Test("The funnel narrows monotonically and the axis totals match their rows")
    func coverageIsInternallyConsistent() throws {
        let flows = try index()
        let coverage = flows.coverage
        #expect(coverage.referencesInsideDocuments <= coverage.referencesScanned)
        #expect(coverage.documentEdges <= coverage.referencesInsideDocuments)
        #expect(coverage.sameVolumeEdges <= coverage.documentEdges)
        #expect(coverage.footnoteEdges <= coverage.documentEdges)
        #expect(coverage.volumesWithEdges <= coverage.volumesScanned)

        for (label, axis, rows, vocabulary) in [
            ("collections", coverage.collections, flows.collectionFlows, flows.collectionIds),
            ("classes", coverage.classes, flows.classFlows, flows.classKeys),
        ] {
            #expect(axis.pairCount == rows.count, "\(label): pairCount disagrees with the rows")
            #expect(axis.unitCount == vocabulary.count, "\(label): unitCount disagrees")
            #expect(rows.reduce(0) { $0 + $1.count } == axis.joinedReferences,
                    "\(label): the rows do not sum to joinedReferences")
            #expect(rows.filter(\.isSameUnit).reduce(0) { $0 + $1.count } == axis.sameUnitReferences,
                    "\(label): same-unit rows do not sum to sameUnitReferences")
            #expect(axis.joinedReferences <= coverage.documentEdges,
                    "\(label): more joined references than there are edges")
        }
    }

    @Test("The artifact records that most of these references are footnotes")
    func footnoteShareIsRecorded() throws {
        // The single most important disclosure this artifact carries: a flow cell describes the
        // editors' annotation practice, not a relation between the archives. If the share ever
        // collapsed, the framing every consumer prints would need rewriting — so it is pinned.
        let coverage = try index().coverage
        let share = Double(coverage.footnoteEdges) / Double(coverage.documentEdges)
        #expect(share > 0.9, """
            Footnotes are \(Int(share * 100))% of document-to-document references, not the >90% \
            every disclosure on this data is written around.
            """)
    }

    @Test("Most of the series contributes no references at all, and that is recorded")
    func mostVolumesContributeNothing() throws {
        // The `dN` cross-reference idiom postdates 1945; 298 of 552 volumes have no edges. A
        // consumer that assumed corpus-wide coverage would misread every empty result.
        let coverage = try index().coverage
        #expect(coverage.volumesWithEdges < coverage.volumesScanned / 2, """
            \(coverage.volumesWithEdges) of \(coverage.volumesScanned) volumes carry edges. The \
            feature's coverage line depends on this being a minority.
            """)
    }

    @Test("The class axis is thin, which is why it ships as a measurement")
    func classAxisIsThinnerThanCollections() throws {
        let coverage = try index().coverage
        #expect(coverage.collections.betweenUnitReferences
                > coverage.classes.betweenUnitReferences * 3, """
                The class axis is no longer far thinner than the collection axis \
                (\(coverage.classes.betweenUnitReferences) vs \
                \(coverage.collections.betweenUnitReferences)). If that has changed, the plan's \
                recommendation not to build a class-flow surface should be revisited rather than \
                inherited.
                """)
        let perPair = Double(coverage.classes.betweenUnitReferences)
            / Double(max(coverage.classes.pairCount, 1))
        #expect(perPair < 3, "class flows average \(perPair) references per pair")
    }

    // MARK: - The reader

    @Test("Outgoing and incoming flows resolve, exclude same-unit rows, and rank by weight")
    func readerResolvesFlows() throws {
        let flows = try index()
        // Pick the busiest source from the artifact so the test cannot pass by naming a
        // collection whose id has drifted.
        let busiest = try #require(flows.collectionFlows
            .filter { !$0.isSameUnit }
            .max { $0.count < $1.count }
            .map { flows.collectionIds[$0.source] })

        let outgoing = flows.outgoingFlows(fromCollectionId: busiest)
        #expect(!outgoing.isEmpty)
        #expect(outgoing.map(\.count) == outgoing.map(\.count).sorted(by: >),
                "outgoing flows must be heaviest-first")
        #expect(!outgoing.contains { $0.collectionId == busiest },
                "a collection referencing itself is not a hand-off and must be excluded")
        for flow in outgoing {
            #expect(flows.collectionIds.contains(flow.collectionId))
            #expect(flow.count > 0)
        }

        // Direction is preserved. Asserting only that the source *appears* in the target's
        // incoming list passes even when incoming and outgoing are the same function, because the
        // heaviest flows run both ways (measured — the sweep's M12 survived that). The COUNT is
        // what separates them: Nixon NSC → Central Files 1970-73 is 449 and the reverse is 317.
        let heaviest = try #require(flows.collectionFlows
            .filter { !$0.isSameUnit }
            .max { $0.count < $1.count })
        let source = flows.collectionIds[heaviest.source]
        let target = flows.collectionIds[heaviest.target]
        let incoming = flows.incomingFlows(toCollectionId: target)
        let edge = try #require(incoming.first { $0.collectionId == source },
                                "the reverse lookup lost the edge entirely")
        #expect(edge.count == heaviest.count, """
            Incoming reports \(edge.count) for \(source) → \(target), but the stored flow is \
            \(heaviest.count). The reader is answering the outgoing question in both directions.
            """)
    }

    @Test("An unknown collection reads as empty rather than resolving to something")
    func unknownCollectionIsEmpty() throws {
        let flows = try index()
        #expect(flows.outgoingFlows(fromCollectionId: "lot:NOT-A-LOT").isEmpty)
        #expect(flows.incomingFlows(toCollectionId: "lot:NOT-A-LOT").isEmpty)
        #expect(flows.sameUnitReferences(forCollectionId: "lot:NOT-A-LOT") == 0)
    }

    @Test("Same-unit references are reachable, because the exclusion has to be disclosed")
    func sameUnitReferencesAreReadable() throws {
        let flows = try index()
        let selfLoop = try #require(flows.collectionFlows.filter(\.isSameUnit)
            .max { $0.count < $1.count })
        let id = flows.collectionIds[selfLoop.source]
        #expect(flows.sameUnitReferences(forCollectionId: id) == selfLoop.count)
        #expect(selfLoop.count > 0)
    }
}
