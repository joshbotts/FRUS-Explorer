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
// package's FRUSCoreKitTests.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit as a module of its own; Xcode compiles it into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

// MARK: - SemanticProjectReachTests (S-2)

/// Pins the two pure rules of the project reach scan — the consent gate and the ranking.
///
/// The scan itself is pinned in `SemanticVectorsKitTests/SemanticMultiProbeScanTests`, against the
/// shipped artifacts and against the per-anchor path it fuses; what is left here is what the app
/// decides rather than what the kit computes.
///
/// Version history:
///   1.0 — 2026-09-10: S-2
///   1.1 — 2026-11-23: FRUS Explorer Light's S26a — moved out of `ProjectLeadsTests.swift` into the
///          kit's suites, unchanged, with the reach, which FRUSCoreKit holds now
@Suite("SemanticProjectReach — the gate and the ranking")
struct SemanticProjectReachTests {

    private func lead(_ id: String, documents: Int, seeds: Int) -> ProjectReach.VolumeLead {
        ProjectReach.VolumeLead(volumeID: id, documentCount: documents, reachingSeeds: seeds)
    }

    // MARK: - The consent gate

    @Test("The scan runs at the shipped default, since the axis was raised to 0.5")
    func onAtTheDefault() {
        // Was the opposite until 2026-09-10, when the owner raised `semanticSimilarity` from 0 to
        // 0.5. The gate is unchanged — it is still `weights[.semanticSimilarity] > 0`, the same one
        // `RelatedDocumentsEngine.runsOffIndexScan` applies — what changed is where the default
        // sits relative to it.
        #expect(SemanticProjectReach.runsScan(weights: .default))
    }

    @Test("Taking the slider to zero switches the scan back off")
    func offWhenTheReaderZeroesIt() {
        // The population the gate now protects: not the reader who never opted in, but the reader
        // who opted OUT.
        var weights = AxisWeights.default
        weights[.semanticSimilarity] = 0
        #expect(!SemanticProjectReach.runsScan(weights: weights))
    }

    @Test("The scan runs once the reader raises the semantic weight")
    func onWhenTheReaderAsks() {
        var weights = AxisWeights.default
        weights[.semanticSimilarity] = 0.4
        #expect(SemanticProjectReach.runsScan(weights: weights))
    }

    @Test("Another axis being zeroed does not turn the semantic scan off")
    func onlyItsOwnAxisClosesTheGate() {
        // The mirror of `offWhenTheReaderZeroesIt`: the gate reads exactly one axis, so a reader
        // who has zeroed everything else still gets the scan, and a reader who has raised
        // everything else but zeroed this one does not.
        var weights = AxisWeights.default
        weights[.crossReference] = 0
        weights[.sharedPersons] = 0
        #expect(SemanticProjectReach.runsScan(weights: weights))
    }

    // MARK: - The ranking

    @Test("Reaching seeds outrank document count")
    func seedsBeatDocuments() {
        // The defect this rule exists to prevent: one seed in a sparse neighbourhood has a loose
        // cut and can admit hundreds of rows from one big volume, outvoting the rest of the
        // project. `reachingSeeds` is the only quantity commensurable across seeds — each
        // contributes at most 1 — so it ranks, and the document count is shown second.
        let ranked = SemanticProjectReach.rank([
            lead("frus1915", documents: 900, seeds: 1),
            lead("frus1969-76v12", documents: 40, seeds: 9),
        ])
        #expect(ranked.map(\.volumeID) == ["frus1969-76v12", "frus1915"])
    }

    @Test("Document count breaks a tie on seeds")
    func documentsBreakTheSeedTie() {
        let ranked = SemanticProjectReach.rank([
            lead("frus-a", documents: 12, seeds: 4),
            lead("frus-b", documents: 80, seeds: 4),
        ])
        #expect(ranked.map(\.volumeID) == ["frus-b", "frus-a"])
    }

    @Test("The volume id is the final tie-break, so the list cannot reshuffle")
    func volumeIdIsATotalOrder() {
        // Two recomputes that found the same thing must render the same order; without a total
        // final key the sort is unstable across runs and the section flickers between them.
        let leads = [lead("frus-z", documents: 5, seeds: 2), lead("frus-a", documents: 5, seeds: 2)]
        #expect(SemanticProjectReach.rank(leads).map(\.volumeID) == ["frus-a", "frus-z"])
        #expect(SemanticProjectReach.rank(leads.reversed()).map(\.volumeID) == ["frus-a", "frus-z"])
    }

    @Test("At most volumeLimit volumes are offered")
    func truncatesToTheDisplayLimit() {
        let many = (0..<20).map { lead("frus-\($0)", documents: 10, seeds: 20 - $0) }
        let ranked = SemanticProjectReach.rank(many)
        #expect(ranked.count == SemanticProjectReach.volumeLimit)
        #expect(ranked.first?.volumeID == "frus-0")
    }

    // MARK: - The slot mapping (the trap that was there)

    private func entry(_ id: String, at offset: Int, documents: Int)
        -> SemanticVectorsArtifacts.VolumeEntry {
        SemanticVectorsArtifacts.VolumeEntry(
            volumeID: id, rowOffset: offset, documentCount: documents, idSegments: [])
    }

    @Test("Slots map to volumes by position, in row order")
    func slotOrderIsRowOrder() {
        let order = SemanticProjectReach.slotOrder([
            entry("frus-c", at: 200, documents: 50),
            entry("frus-a", at: 0, documents: 120),
            entry("frus-b", at: 120, documents: 80),
        ])
        #expect(order.starts == [0, 120, 200])
        #expect(order.volumeIDs == ["frus-a", "frus-b", "frus-c"])
    }

    @Test("A zero-document volume shares a row offset and does not trap")
    func zeroDocumentVolumeDoesNotTrap() {
        // The defect this replaced: `Dictionary(uniqueKeysWithValues:)` keyed on `rowOffset` is a
        // runtime crash on a duplicate key, and two volumes share an offset exactly when one has
        // zero documents. Latent against the shipped index — 553 distinct offsets, smallest volume
        // 2 documents — so nothing would have surfaced it until a regeneration produced an empty
        // volume, on a Project Home path the 0.5 default made reachable for everyone.
        let order = SemanticProjectReach.slotOrder([
            entry("frus-a", at: 0, documents: 120),
            entry("frus-empty", at: 120, documents: 0),
            entry("frus-b", at: 120, documents: 80),
        ])
        #expect(order.starts.count == 3)
        #expect(order.volumeIDs.count == 3)
        #expect(Set(order.volumeIDs) == ["frus-a", "frus-empty", "frus-b"])
        // Ascending, duplicates included — the scan's cursor advances past a zero-width group.
        #expect(order.starts == order.starts.sorted())
    }

    @Test("An empty finding is empty")
    func emptyIsEmpty() {
        #expect(ProjectReach.none.isEmpty)
        #expect(SemanticProjectReach.rank([]).isEmpty)
    }
}
