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

/// Generates candidates by nearness in the corpus's embedding space.
///
/// This is the axis the whole vector program exists for, and the only one that can reach a document
/// with no archival key and no citation — measured, **46,234 documents have an empty Related list
/// today, 98.2% of them pre-1900**. Every other generator needs an editorial or archival hook that
/// the early corpus does not carry.
///
/// ## The pipeline, and why each stage is where it is
///
/// 1. **Candidates come from the bundled Tier-1 block**, a 256-bit sign vector per document for all
///    314,483 documents — so candidate generation works with *zero volumes downloaded* and reaches
///    volumes the reader does not have. A full corpus scan is 1.43 ms.
/// 2. **The display fence is applied inside the scan**, as a precomputed per-row eligibility byte
///    array built from the indexed volumes' row ranges. Filtering afterwards would let ineligible
///    rows consume the candidate pool — measured in V-2 as a 50-candidate request returning 28.
/// 3. **Scoring is exact int8 cosine** against Tier-2 shards. A candidate whose shard this device
///    does not hold is **dropped, not scored** — an absent shard is missing evidence, and a zero
///    would be a claim of dissimilarity.
/// 4. **Missing shards are queued for fetch**, so a library that has never used the axis warms up
///    across a few uses rather than downloading 82 MB the first time anyone opens it.
///
/// ## What it deliberately does not do
///
/// It does not fall back to ranking by Hamming distance when a shard is missing. Raw binary recalls
/// 0.53 of the exact top ten against the reranked funnel's 0.745, and the two are different scales —
/// a list mixing them would be sorted by a number that means one thing in some rows and another
/// thing in the rest. Fewer honest rows beat more incomparable ones.
///
/// ## Experimental
///
/// The axis ships at weight 0 with "experimental" in its name. The blind panel that would have
/// graded early-era quality was retired as a gate (owner decision 2026-08-12) in favour of tester
/// feedback, so **pre-1900 quality is an unmeasured unknown** — the corpus-scale gate reaches 572
/// pre-1900 queries because the `dN` citation idiom postdates 1945. Say so wherever this axis is
/// described.
///
/// Version history:
///   1.0 — V-3: initial implementation
@MainActor
struct SemanticSimilarityGenerator: SimilarityGenerator {

    var axis: SimilarityAxis { .semanticSimilarity }

    /// Creates the generator.
    init() {}

    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async throws -> GeneratedPool {
        guard let index = BundledSemanticVectors.index,
              let corpus = BundledSemanticVectors.corpusVectors,
              let store = appState.semanticShardStore,
              let pipeline = appState.indexingPipeline
        else { return .empty }

        // The anchor needs a vector at all: 2,356 of the app's display rows are chapter divs, front
        // matter and appendix structure that were never embedded. That is ordinary, not a fault.
        guard let anchorRow = index.row(
            documentID: anchor.documentId, volumeID: anchor.volumeId) else { return .empty }

        // ...and its own shard, to be the query vector. Fetched on demand when absent, because this
        // is the one shard whose absence makes the axis useless rather than merely narrower, and it
        // is the volume the reader is already looking at.
        guard let anchorEntry = index.volume(anchor.volumeId) else { return .empty }
        guard let anchorShard = await store.shard(for: anchor.volumeId) else {
            appState.fetchSemanticShardIfNeeded(for: anchor.volumeId, reason: .readerAskedForSemantics)
            return .empty
        }
        guard let query = anchorShard.vector(at: anchorRow - anchorEntry.rowOffset) else {
            return .empty
        }

        // The display fence, as an O(1) per-row lookup. A candidate must be a document the reader
        // could actually open: indexed, and inside the caller's scope when one is set.
        let eligibleVolumes = Self.eligibleVolumeIDs(
            indexed: appState.indexedVolumeIds, scope: scopeVolumeIds)
        guard !eligibleVolumes.isEmpty else { return .empty }
        var eligible = [UInt8](repeating: 0, count: index.documentCount)
        for volumeID in eligibleVolumes {
            guard let range = index.rows(forVolume: volumeID) else { continue }
            for row in range { eligible[row] = 1 }
        }

        // Tier 1: corpus-wide Hamming candidates at the measured rerank pool.
        let pool = max(limit, index.file.retrieval.rerankPool)
        let rows = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: pool,
            isEligible: { eligible[$0] == 1 })
        guard !rows.isEmpty else { return .empty }

        // Tier 2: exact cosine, for the candidates whose shard is present. Volumes without one are
        // queued so the next query is better; they contribute nothing to this one.
        var shards: [Int: SemanticShard?] = [:]
        var missingVolumes: Set<String> = []
        var scored: [(row: Int, score: Double)] = []
        scored.reserveCapacity(rows.count)
        for row in rows {
            guard let located = index.volumeSlot(containing: row) else { continue }
            let volumeID = index.volumes[located.slot].volumeID
            if shards[located.slot] == nil {
                shards[located.slot] = await store.shard(for: volumeID)
            }
            guard let candidateShard = shards[located.slot] ?? nil else {
                missingVolumes.insert(volumeID)
                continue
            }
            guard let score = candidateShard.cosine(
                row: located.localRow, query: query.codes, queryScale: query.scale) else { continue }
            scored.append((row: row, score: score))
        }
        for volumeID in missingVolumes {
            appState.fetchSemanticShardIfNeeded(for: volumeID, reason: .readerAskedForSemantics)
        }

        scored.sort { $0.score == $1.score ? $0.row < $1.row : $0.score > $1.score }
        let top = Array(scored.prefix(limit))
        guard !top.isEmpty else { return .empty }

        // Display records come from `document_cache`, which is the fence itself: a key with no row
        // there is a document this device cannot render, and the ranker drops it anyway.
        var keys: [DocumentKey] = []
        keys.reserveCapacity(top.count)
        var scoreByKey: [DocumentKey: Double] = [:]
        for entry in top {
            guard let document = index.document(at: entry.row) else { continue }
            let key = DocumentKey(volumeId: document.volumeID, documentId: document.documentID)
            guard key != anchor else { continue }
            keys.append(key)
            scoreByKey[key] = entry.score
        }
        let records = try await pipeline.candidateRecords(forKeys: keys)

        return GeneratedPool(
            candidates: keys.compactMap { key in
                guard let record = records[key], let score = scoreByKey[key] else { return nil }
                return GeneratedCandidate(
                    key: key,
                    record: record,
                    // Raw cosine, absolute in [0, 1]. The axis is `isSelfNormalising`, so the ranker
                    // clamps it rather than dividing by this list's own max — without that, a weak
                    // best-of-field neighbour would read as a perfect one (#643).
                    strength: score,
                    evidenceLabel: Self.evidenceLabel(for: score))
            },
            // Deliberately nil: the pool was cut at `limit` from a bounded candidate list, and this
            // generator never counted how many documents would have scored above zero corpus-wide.
            // `nil` means "unknown", which `GeneratedPool` keeps distinct from "not truncated".
            availableTotal: nil)
    }

    /// The volumes a candidate may come from: indexed, intersected with the caller's scope.
    ///
    /// - Parameters:
    ///   - indexed: Volumes with rows in `document_cache`.
    ///   - scope: The caller's volume restriction, if any.
    /// - Returns: The eligible volume ids.
    nonisolated static func eligibleVolumeIDs(indexed: Set<String>, scope: Set<String>?) -> Set<String> {
        guard let scope else { return indexed }
        return indexed.intersection(scope)
    }

    /// The "why related" chip's text for a cosine.
    ///
    /// A percentage of a cosine is the honest thing to show here and the only thing this axis knows:
    /// it has no shared term, no citation and no archival container to name. The design's
    /// shared-distinctive-terms chip is a render-time computation over the displayed rows and is a
    /// separate piece of work; until it exists, this says what it measured rather than implying a
    /// relationship it did not find.
    ///
    /// - Parameter score: The approximate cosine.
    /// - Returns: A short label.
    nonisolated static func evidenceLabel(for score: Double) -> String {
        let percent = Int((min(1.0, max(0.0, score)) * 100).rounded())
        return String(
            localized: "related.semantic.evidence",
            defaultValue: "Semantic match · \(percent)%")
    }

}
