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
// No `import SemanticVectorsKit`: `project.yml` compiles the kit's sources directly into
// both app targets (the FTS5Store/WordCloudKit pattern), so its types are in this module.
// The SPM library target exists so the generators write through the same declarations.

// MARK: - ProjectReach

/// What the semantic axis sees **beyond the volumes the reader holds**, for a whole project.
///
/// Volume-grain, and deliberately so: a document in an undownloaded volume has no `document_cache`
/// row, so it has no header, no document number and no editorial-note flag — nothing a lead row can
/// render. `SemanticSimilarityGenerator` owns the document-grain question, per anchor, with a shard
/// in hand; this type answers the one a project can ask, which is *which volumes should I get?*
struct ProjectReach: Sendable, Equatable {

    /// One volume the project reaches into but does not hold.
    struct VolumeLead: Sendable, Equatable {
        /// Manifest `volumeId`.
        let volumeID: String
        /// Documents in it that read as close to one of the project's own documents as that
        /// document's nearest neighbours already on the device.
        let documentCount: Int
        /// How many of the project's seed documents reached it.
        let reachingSeeds: Int
    }

    /// Volumes, ranked. See ``ProjectReach`` for what ranks them.
    let volumes: [VolumeLead]
    /// Documents admitted across every volume.
    let documentCount: Int
    /// Seeds that carried a vector and were actually probed.
    let seedsProbed: Int

    /// Nothing found, or nothing asked.
    static let none = ProjectReach(volumes: [], documentCount: 0, seedsProbed: 0)

    /// Whether there is anything to show.
    var isEmpty: Bool { volumes.isEmpty }
}

// MARK: - SemanticProjectReach

/// Runs the S-2 project reach scan: one multi-probe Hamming pass over the bundled corpus tier,
/// probed by every one of a project's seed documents at once.
///
/// ## What it is for
/// `ProjectLeadsService` calls `RelatedDocumentsEngine.rank` once per seed with
/// `includeOffIndexLeads: false`, so a project's leads can only ever name documents in volumes the
/// reader already has. The semantic axis's one unique capability — seeing past the library — was
/// switched off for the scope where it is most useful, because switching it on meant a full corpus
/// pass per seed. **Measured, 40 seeds against the shipped artifacts: 52.07 ms that way, 13.09 ms
/// fused.** `SemanticMultiProbeScan` carries the measurement and the two rejected loop shapes.
///
/// ## The ranking is by REACHING SEEDS, not document count
/// A volume is ranked by how many of the project's own documents point at it, and shows its
/// document count second. That is not a presentation preference — `reachingSeeds` is the only
/// quantity in the pass that is commensurable across seeds. Each seed contributes at most 1 to it,
/// where `documentCount` is bounded only by the volume's size, so ranking by documents would let a
/// single seed sitting in a sparse neighbourhood (a loose cut admits far more rows) outvote the
/// other thirty-nine, and would systematically prefer the largest volumes — the shipped index runs
/// from 2 to 1,915 documents per volume, median 480, so a raw count with no denominator recommends
/// the 1910s annuals to almost every project.
///
/// ## It runs unless the reader turned the axis off
/// Gated on `weights[.semanticSimilarity] > 0` — the same gate `RelatedDocumentsEngine`
/// `runsOffIndexScan` applies to S-3, unchanged. What changed is where the default sits relative to
/// it: the owner raised `semanticSimilarity.defaultWeight` from 0 to **0.5 on 2026-09-10**, so this
/// runs for every reader who has not deliberately zeroed the axis, where it would have run for
/// almost nobody. The population the gate protects is now the reader who opted OUT.
///
/// The scan needs no shard — it reads only the bundled sign bits — so it queues no download, which
/// is worth stating now that it runs by default: the #926 question the default change does raise
/// belongs to the per-anchor generator's Tier-2 rerank, not here.
///
/// Version history:
///   1.0 — 2026-09-10: S-2, the project reach scan
@MainActor
enum SemanticProjectReach {

    /// The rank whose distance becomes each seed's own cut.
    ///
    /// `RelatedDocumentsEngine.candidatePoolFloor`, so a project's bar is the same bar the Related
    /// panel's S-3 section uses for a single document — the two surfaces are one feature and a
    /// reader moving between them should not meet two different definitions of "close".
    nonisolated static let cutRank = 120

    /// How many volumes the caller is offered.
    nonisolated static let volumeLimit = 5

    /// Whether the scan runs.
    ///
    /// Extracted for the reason `runsGenerator` was: so a test can drive the rule instead of
    /// grepping for it.
    ///
    /// - Parameter weights: The reader's tuning.
    /// - Returns: `true` when the reader has turned the semantic axis on.
    nonisolated static func runsScan(weights: AxisWeights) -> Bool {
        weights[.semanticSimilarity] > 0
    }

    /// Ranks a project's off-index volumes.
    ///
    /// - Parameters:
    ///   - seedKeys: The project's seed document keys, `"volumeId/documentId"`.
    ///   - weights: The reader's tuning — the consent gate.
    ///   - appState: Holds the bundled vectors and the indexed-volume set.
    /// - Returns: The ranked finding, or ``ProjectReach/none`` when the axis is off, the artifacts
    ///   are unavailable, no seed carries a vector, or the pass was cancelled.
    static func reach(
        seedKeys: [String], weights: AxisWeights, appState: AppState
    ) async -> ProjectReach {
        guard runsScan(weights: weights) else { return .none }
        await BundledSemanticVectors.prepare()
        guard let corpus = BundledSemanticVectors.corpusVectors,
              let index = BundledSemanticVectors.index
        else { return .none }

        // Seeds → corpus rows. A seed whose volume is outside the artifact, or whose document has
        // no vector, is skipped exactly as the generator skips it; the pass reports how many were
        // actually probed so a caller never implies coverage it did not have.
        var probeRows: [Int] = []
        var probeSeeds: [String] = []
        for key in seedKeys {
            guard probeRows.count < SemanticMultiProbeScan.maxProbes else { break }
            guard let document = DocumentKey(compositeString: key),
                  let row = index.row(documentID: document.documentId, volumeID: document.volumeId)
            else { continue }
            probeRows.append(row)
            probeSeeds.append(key)
        }
        guard !probeRows.isEmpty else { return .none }

        let eligible = SemanticSimilarityGenerator.eligibleVolumeIDs(
            indexed: appState.indexedVolumeIds, scope: nil)
        let starts = index.volumes.map(\.rowOffset).sorted()

        let scan = await runScan(probeRows: probeRows, corpus: corpus, index: index,
                                 eligible: eligible, groupStarts: starts)
        guard !scan.groups.isEmpty else { return .none }

        let volumesByStart = Dictionary(
            uniqueKeysWithValues: index.volumes.map { ($0.rowOffset, $0.volumeID) })
        var leads: [ProjectReach.VolumeLead] = []
        leads.reserveCapacity(scan.groups.count)
        for group in scan.groups {
            guard group.slot < starts.count,
                  let volumeID = volumesByStart[starts[group.slot]]
            else { continue }
            leads.append(ProjectReach.VolumeLead(
                volumeID: volumeID,
                documentCount: group.documentCount,
                reachingSeeds: group.reachingProbes))
        }
        return ProjectReach(
            volumes: rank(leads),
            documentCount: scan.admittedRows,
            seedsProbed: probeSeeds.count)
    }

    /// The pass itself, off the main actor.
    ///
    /// `nonisolated` **and** `async`, which is what takes it off the actor while keeping it in the
    /// calling Task — so `Task.isCancelled` inside the scan is the recompute's own cancellation.
    /// `Task.detached` would have been wrong twice over: it does not inherit cancellation, and this
    /// is superseded on every project switch, so a reader flipping between projects could stack
    /// passes that nothing could stop.
    ///
    /// The held mask is built HERE rather than by the caller for the same reason the scan is: it is
    /// one byte per corpus row — 314,571 writes — which has no business on a frame.
    ///
    /// - Parameters:
    ///   - probeRows: The seeds' corpus rows.
    ///   - corpus: The mapped bundled tier.
    ///   - index: The bundled index, for the volume row blocks.
    ///   - eligible: Volume ids the reader holds.
    ///   - groupStarts: Volume row offsets, ascending.
    /// - Returns: The raw finding.
    nonisolated private static func runScan(
        probeRows: [Int], corpus: SemanticCorpusVectors, index: SemanticVectorIndex,
        eligible: Set<String>, groupStarts: [Int]
    ) async -> SemanticMultiProbeScan.Reach {
        var held = [UInt8](repeating: 0, count: index.documentCount)
        for volume in index.volumes where eligible.contains(volume.volumeID) {
            for row in volume.rowOffset..<(volume.rowOffset + volume.documentCount) {
                held[row] = 1
            }
        }
        return SemanticMultiProbeScan.reach(
            probeRows: probeRows, in: corpus, held: held,
            cutRank: cutRank, groupStarts: groupStarts,
            isCancelled: { Task.isCancelled })
    }

    /// Ranks and truncates the volume leads.
    ///
    /// Pure and `nonisolated` so the rule is testable without an `AppState`. Reaching seeds first,
    /// documents second, `volumeID` last — the final key is a total order, so the list cannot
    /// reshuffle between two recomputes that found the same thing.
    ///
    /// - Parameter leads: The unranked leads.
    /// - Returns: At most ``volumeLimit`` leads, best first.
    nonisolated static func rank(_ leads: [ProjectReach.VolumeLead]) -> [ProjectReach.VolumeLead] {
        leads.sorted {
            if $0.reachingSeeds != $1.reachingSeeds { return $0.reachingSeeds > $1.reachingSeeds }
            if $0.documentCount != $1.documentCount { return $0.documentCount > $1.documentCount }
            return $0.volumeID < $1.volumeID
        }
        .prefix(volumeLimit)
        .map { $0 }
    }
}
