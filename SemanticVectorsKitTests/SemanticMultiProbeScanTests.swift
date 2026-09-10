//
//  Copyright 2026 Josh Botts
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Testing
@testable import SemanticVectorsKit

/// Pins `SemanticMultiProbeScan` against the shipped kernel composed the S-3 way.
///
/// **The parity claim is the whole test, and it is what makes the fusion safe.** The pass exists to
/// do in one traversal what `SemanticSimilarityGenerator.offIndexSection` does per anchor, so the
/// only thing worth asserting is that it admits *exactly* the rows the per-anchor path admits. The
/// reference side here is not a re-implementation: it is `SemanticRetrievalKernel.hammingCandidates`
/// and `binarySimilarity` — the two calls `offIndexLeads` itself makes — composed in the same order,
/// so a change to either kernel entry point moves both sides together and cannot hide a divergence.
///
/// It drives the **shipped artifacts** out of `FRUSExplorer/Resources` rather than a fixture,
/// because the properties that matter are properties of the real distribution: the cut is a rank in
/// a real neighbour list, and a synthetic corpus of random bits has no neighbourhood structure to
/// rank. The suite skips when they are absent rather than failing, so a checkout without them
/// still builds.
///
/// Version history:
///   1.0 — 2026-09-10: S-2, the project reach scan
@Suite("SemanticMultiProbeScan — parity with the per-anchor path")
struct SemanticMultiProbeScanTests {

    private struct Artifacts {
        let index: SemanticVectorIndex
        let vectors: SemanticCorpusVectors
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func shipped() throws -> Artifacts? {
        let base = repoRoot.appending(path: "FRUSExplorer/Resources")
        let indexURL = base.appending(path: "semantic-vectors-index.json")
        let binaryURL = base.appending(path: "semantic-vectors-binary.bin")
        guard FileManager.default.fileExists(atPath: indexURL.path),
              FileManager.default.fileExists(atPath: binaryURL.path)
        else { return nil }
        let file = try JSONDecoder().decode(
            SemanticVectorsArtifacts.Index.self, from: Data(contentsOf: indexURL))
        return Artifacts(
            index: SemanticVectorIndex(file: file),
            vectors: try SemanticCorpusVectors(contentsOf: binaryURL, expecting: file.provenance))
    }

    /// A held mask standing in for a reader who holds roughly one volume in ten, in whole volumes —
    /// the grain the real fence uses, and the reader S-3 exists for.
    private static func heldMask(_ a: Artifacts, everyNthVolume n: Int) -> [UInt8] {
        var held = [UInt8](repeating: 0, count: a.vectors.documentCount)
        for (slot, volume) in a.index.volumes.enumerated() where slot % n == 0 {
            for row in volume.rowOffset..<(volume.rowOffset + volume.documentCount) {
                held[row] = 1
            }
        }
        return held
    }

    /// Every corpus row partitioned by volume, in row order — the `groupStarts` contract.
    private static func groupStarts(_ a: Artifacts) -> [Int] {
        a.index.volumes.map(\.rowOffset).sorted()
    }

    /// What `offIndexLeads` keeps for one anchor, computed through the kernel calls it makes.
    private static func referenceAdmitted(
        anchor: Int, in a: Artifacts, held: [UInt8], cutRank: Int
    ) -> Set<Int> {
        let onIndex = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchor, in: a.vectors, limit: cutRank, isEligible: { held[$0] == 1 })
        guard let cutRow = onIndex.last,
              let cutSimilarity = SemanticRetrievalKernel.binarySimilarity(
                anchor, cutRow, in: a.vectors)
        else { return [] }
        var admitted: Set<Int> = []
        for row in 0..<a.vectors.documentCount where held[row] == 0 {
            guard let similarity = SemanticRetrievalKernel.binarySimilarity(anchor, row, in: a.vectors),
                  similarity >= cutSimilarity
            else { continue }
            admitted.insert(row)
        }
        return admitted
    }

    // MARK: - Parity

    @Test("One probe admits exactly what the per-anchor path admits")
    func singleProbeMatchesTheAnchorPath() throws {
        guard let a = try Self.shipped() else { return }
        let held = Self.heldMask(a, everyNthVolume: 10)
        let starts = Self.groupStarts(a)
        let cutRank = 120                                   // the engine's candidatePoolFloor

        // Spread across the corpus rather than clustered, so the probes land in different
        // neighbourhood densities — the property that makes a per-probe cut necessary at all.
        for anchor in [1_000, 60_000, 150_000, 240_000, 310_000] {
            let reach = SemanticMultiProbeScan.reach(
                probeRows: [anchor], in: a.vectors, held: held,
                cutRank: cutRank, groupStarts: starts)
            let reference = Self.referenceAdmitted(anchor: anchor, in: a, held: held, cutRank: cutRank)

            #expect(reach.admittedRows == reference.count,
                    "probe \(anchor): fused admitted \(reach.admittedRows), per-anchor \(reference.count)")

            // Per volume, too — an equal total over a different distribution would be a coincidence
            // that the count alone cannot tell from agreement.
            var referenceByVolume: [Int: Int] = [:]
            for row in reference {
                guard let located = a.index.volumeSlot(containing: row) else { continue }
                let start = a.index.volumes[located.slot].rowOffset
                guard let slot = starts.firstIndex(of: start) else { continue }
                referenceByVolume[slot, default: 0] += 1
            }
            let fusedByVolume = Dictionary(
                uniqueKeysWithValues: reach.groups.map { ($0.slot, $0.documentCount) })
            #expect(fusedByVolume == referenceByVolume, "probe \(anchor): per-volume counts differ")
        }
    }

    @Test("Many probes admit the union of what each admits alone, attributed to the nearest")
    func manyProbesAdmitTheUnion() throws {
        guard let a = try Self.shipped() else { return }
        let held = Self.heldMask(a, everyNthVolume: 10)
        let starts = Self.groupStarts(a)
        let cutRank = 120
        let probes = [1_000, 60_000, 150_000, 240_000, 310_000]

        let fused = SemanticMultiProbeScan.reach(
            probeRows: probes, in: a.vectors, held: held, cutRank: cutRank, groupStarts: starts)

        var union: Set<Int> = []
        for probe in probes {
            union.formUnion(Self.referenceAdmitted(anchor: probe, in: a, held: held, cutRank: cutRank))
        }
        #expect(fused.admittedRows == union.count,
                "fused \(fused.admittedRows) vs union of singles \(union.count)")

        // Every probe's cut is its own, and they really do differ — this is the assertion that
        // would catch a regression to a single shared cutoff, which is the shape a centroid takes.
        #expect(fused.probeCuts.count == probes.count)
        #expect(Set(fused.probeCuts).count > 1,
                "all probes shared one cut (\(fused.probeCuts)) — the per-probe band is what makes the comparison legitimate")
    }

    // MARK: - The rules the caller depends on

    @Test("A probe with no held rows admits nothing, rather than everything")
    func noHeldRowsAdmitsNothing() throws {
        guard let a = try Self.shipped() else { return }
        let held = [UInt8](repeating: 0, count: a.vectors.documentCount)
        let reach = SemanticMultiProbeScan.reach(
            probeRows: [1_000], in: a.vectors, held: held,
            cutRank: 120, groupStarts: Self.groupStarts(a))
        // The per-anchor path's guard fails outright here and yields `.none`; the failure mode this
        // pins is the opposite one, where an unreachable cut admits the whole corpus.
        #expect(reach.admittedRows == 0)
        #expect(reach.probeCuts == [-1])
    }

    @Test("Holding fewer rows than the cut rank uses the farthest held row as the cut")
    func shortHeldListUsesItsLastEntry() throws {
        guard let a = try Self.shipped() else { return }
        // One small volume only, so the held list is far shorter than the cut rank.
        guard let small = a.index.volumes.min(by: { $0.documentCount < $1.documentCount })
        else { return }
        var held = [UInt8](repeating: 0, count: a.vectors.documentCount)
        for row in small.rowOffset..<(small.rowOffset + small.documentCount) { held[row] = 1 }
        let anchor = (small.rowOffset + small.documentCount + 5_000) % a.vectors.documentCount

        let reach = SemanticMultiProbeScan.reach(
            probeRows: [anchor], in: a.vectors, held: held,
            cutRank: 120, groupStarts: Self.groupStarts(a))
        let reference = Self.referenceAdmitted(anchor: anchor, in: a, held: held, cutRank: 120)
        #expect(reach.admittedRows == reference.count,
                "short held list: fused \(reach.admittedRows), per-anchor \(reference.count)")
        #expect(reach.probeCuts[0] >= 0 && reach.probeCuts[0] <= a.vectors.dims)
    }

    @Test("reachingProbes counts distinct probes, not admitted rows")
    func reachingProbesIsProbeGrain() {
        let group = SemanticMultiProbeScan.Reach.Group(
            slot: 3, documentCount: 400, probeMask: 0b1011, bestMargin: -12)
        // The distinction the ranking rule turns on: a volume can take 400 rows from one loose
        // probe, or 3 rows from three probes. Only the second says the project points there.
        #expect(group.reachingProbes == 3)
        #expect(group.documentCount == 400)
    }

    @Test("A malformed request is refused rather than half-answered")
    func malformedRequestsAreRefused() throws {
        guard let a = try Self.shipped() else { return }
        let held = Self.heldMask(a, everyNthVolume: 10)
        let starts = Self.groupStarts(a)
        // No probes, too many probes, a held mask of the wrong length, and a partition that does
        // not start at row 0 — each returns `.none` rather than reading out of bounds.
        #expect(SemanticMultiProbeScan.reach(
            probeRows: [], in: a.vectors, held: held, cutRank: 120, groupStarts: starts) == .none)
        #expect(SemanticMultiProbeScan.reach(
            probeRows: Array(0..<(SemanticMultiProbeScan.maxProbes + 1)), in: a.vectors,
            held: held, cutRank: 120, groupStarts: starts) == .none)
        #expect(SemanticMultiProbeScan.reach(
            probeRows: [1_000], in: a.vectors, held: [1, 0, 1], cutRank: 120,
            groupStarts: starts) == .none)
        #expect(SemanticMultiProbeScan.reach(
            probeRows: [1_000], in: a.vectors, held: held, cutRank: 120,
            groupStarts: [7, 100]) == .none)
    }

    @Test("Cancellation stops the pass and yields nothing")
    func cancellationStopsThePass() throws {
        guard let a = try Self.shipped() else { return }
        let reach = SemanticMultiProbeScan.reach(
            probeRows: [1_000], in: a.vectors, held: Self.heldMask(a, everyNthVolume: 10),
            cutRank: 120, groupStarts: Self.groupStarts(a), isCancelled: { true })
        #expect(reach == .none)
    }
}
