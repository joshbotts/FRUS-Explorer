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

/// The app's half of ``SemanticSimilarityGenerator``, whose declaration, pure rules and
/// ``SemanticOffIndexLeads`` are FRUSCoreKit's (`FRUSCoreKit/RelatedDocuments/SemanticSimilarityGenerator.swift`,
/// where the type's own note is): the generation, the re-score and the off-index scan, which read
/// SemanticVectorsKit's bundled tiers and the app's shard store and so stay here until FRUS Explorer
/// Light's phase 4. The kit's engine reaches them through ``AppSemanticSimilaritySource``.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a — split from the type's file, which moved into
///          FRUSCoreKit; every member here is unchanged
extension SemanticSimilarityGenerator {

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
        // Edition twins fold BEFORE the cut (the V-3 requirement `SemanticEditionTwins`
        // documents): a reader with both Iran editions indexed would otherwise get the same
        // document twice at cosine 1.0 in adjacent slots. Streaming — identity is resolved only
        // until `limit` survivors exist, so the fold costs identity lookups for the kept band,
        // not the whole pool. The anchor's own twin is folded out explicitly: to the reader it
        // IS the anchor, reprinted.
        var seenFoldKeys = Set<String>()
        var top: [(row: Int, score: Double, volumeID: String, documentID: String)] = []
        for entry in scored {
            guard top.count < limit else { break }
            guard let document = index.document(at: entry.row) else { continue }
            if SemanticEditionTwins.areTwins(document.volumeID, anchor.volumeId),
               document.documentID == anchor.documentId { continue }
            let fold = SemanticEditionTwins.foldKey(
                volumeID: document.volumeID, documentID: document.documentID)
            guard seenFoldKeys.insert(fold).inserted else { continue }
            top.append((entry.row, entry.score, document.volumeID, document.documentID))
        }
        guard !top.isEmpty else { return .empty }

        // Display records come from `document_cache`, which is the fence itself: a key with no row
        // there is a document this device cannot render, and the ranker drops it anyway.
        var keys: [DocumentKey] = []
        keys.reserveCapacity(top.count)
        var scoreByKey: [DocumentKey: Double] = [:]
        for entry in top {
            let key = DocumentKey(volumeId: entry.volumeID, documentId: entry.documentID)
            guard key != anchor else { continue }
            keys.append(key)
            // The generation's document calibration (B4), applied once here: the chip and the
            // ranker's sum read the same number, and the order is the cosine's.
            scoreByKey[key] = index.file.retrieval.calibratedDocumentScore(entry.score)
        }
        let records = try await pipeline.candidateRecords(forKeys: keys)

        return GeneratedPool(
            candidates: keys.compactMap { key in
                guard let record = records[key], let score = scoreByKey[key] else { return nil }
                return GeneratedCandidate(
                    key: key,
                    record: record,
                    // The calibrated cosine, absolute on the 300m's scale (B4). The axis is
                    // `isSelfNormalising`, so the ranker clamps it rather than dividing by this
                    // list's own max — without that, a weak best-of-field neighbour would read as
                    // a perfect one (#643).
                    strength: score,
                    evidenceLabel: Self.evidenceLabel(for: score))
            },
            // Deliberately nil: the pool was cut at `limit` from a bounded candidate list, and this
            // generator never counted how many documents would have scored above zero corpus-wide.
            // `nil` means "unknown", which `GeneratedPool` keeps distinct from "not truncated".
            availableTotal: nil)
    }

    // MARK: - Re-scoring the other axes' candidates (S-1)

    /// Scores candidates the OTHER generators produced, which this axis would otherwise leave at 0.
    ///
    /// ## The defect, and why D-D made it visible
    /// The axis is a generator: it vends its own top `limit` neighbours and scores those. Every
    /// other candidate reads `generatorNormalised[.semanticSimilarity]?[key] ?? 0` in the ranker, so
    /// an archival or cross-reference candidate scores **zero on this axis however near it is** —
    /// a discontinuity at the axis's own rank `limit`. That was invisible while the axis shipped at
    /// weight 0; since D-D raised the default to 0.5 it is in every reader's ranking.
    ///
    /// It is not merely a boundary artefact. The Tier-1 funnel selects by **Hamming** and only then
    /// reranks by int8 cosine, at a measured recall of 0.851 — so roughly a seventh of the true
    /// nearest neighbours never reach the pool at all. Those are exactly the documents another axis
    /// may have found by citation or provenance, and they are the population this serves.
    ///
    /// ## The floor is the anchor's own band, and a constant would be wrong
    /// Cosine has no zero. **Measured over 60 anchors on the 300m's artifacts: a random corpus pair
    /// scores a median 0.472**, so re-scoring without a floor adds about half the axis's weight to
    /// every row uniformly — compressing the ranking rather than discriminating within it.
    /// (EmbeddingGemma 2's raw cosines sit higher, a random pair at about 0.71 (the B4 memo's
    /// §1b); its calibration brings its scores back to the 300m's scale, and the argument holds on
    /// either.)
    ///
    /// **But a fixed floor is wrong for the reason S-3 measured on the Hamming side.** The anchor's
    /// own rank-120 cosine runs **0.543 to 0.836** across those same anchors (median 0.695), so any
    /// constant sits above the band for some anchors — admitting nothing — and well below it for
    /// others, admitting a swathe of chance. So the floor is the axis's **own worst vended
    /// neighbour**: a re-scored candidate contributes exactly when it is at least as close as the
    /// weakest document this axis was already willing to show. No constant, calibrated per anchor,
    /// and it closes the discontinuity at its own edge rather than somewhere near it.
    ///
    /// ## What it deliberately does not do
    /// **It fetches nothing.** It reads only shards already on disk and queues no download, unlike
    /// ``candidates(for:anchorYear:limit:scopeVolumeIds:appState:)``, which asks for the shards its
    /// pool needs. Re-scoring the whole candidate universe would otherwise widen the burst measured
    /// at a median of 104 volumes per panel open onto the other axes' pools as well — and that path
    /// now honours the reader's download switch, so a miss here means the reader declined, not that
    /// something failed.
    ///
    /// - Parameters:
    ///   - anchor: The document being related.
    ///   - candidates: Keys the other generators produced that this axis has not scored.
    ///   - floor: The calibrated cosine of this axis's own weakest vended neighbour. A candidate's
    ///     cosine is calibrated before it is compared, so the two are on one scale.
    ///   - store: The shard store, read-only. **Taking the store rather than the `AppState` its
    ///     siblings take is what makes the paragraph above structural instead of a convention**:
    ///     with no `AppState` in scope there is no `fetchSemanticShardIfNeeded` to call, so a later
    ///     change cannot widen the burst here by accident. A test can pin an outcome; it cannot pin
    ///     the absence of a call that nothing prevents.
    /// - Returns: Calibrated cosines for the candidates that cleared the floor; empty when nothing
    ///   did.
    static func reScore(
        anchor: DocumentKey,
        candidates: Set<DocumentKey>,
        floor: Double,
        store: SemanticShardStore
    ) async -> [DocumentKey: Double] {
        // `candidates.isEmpty` is a COST guard and nothing more — it saves mapping the anchor's
        // shard for a pass with nothing to score. The result is `[:]` either way, which is why no
        // test pins it; `rescorePlan` is what actually refuses an empty target set.
        guard !candidates.isEmpty,
              let index = BundledSemanticVectors.index,
              let anchorRow = index.row(documentID: anchor.documentId, volumeID: anchor.volumeId),
              let anchorEntry = index.volume(anchor.volumeId),
              let anchorShard = await store.shard(for: anchor.volumeId),
              let query = anchorShard.vector(at: anchorRow - anchorEntry.rowOffset)
        else { return [:] }

        // The candidates arrive interleaved by volume, so the shards are cached across the loop.
        // **Two dictionaries rather than one `[String: SemanticShard?]`**: assigning `nil` to a
        // dictionary subscript REMOVES the key, so a single optional-valued map cannot remember
        // that a volume has no shard — it would ask the store again for every candidate in it.
        var shards: [String: SemanticShard] = [:]
        var withoutShard: Set<String> = []
        var scored: [DocumentKey: Double] = [:]
        for candidate in candidates {
            guard let row = index.row(documentID: candidate.documentId,
                                      volumeID: candidate.volumeId),
                  let entry = index.volume(candidate.volumeId)
            else { continue }
            if shards[candidate.volumeId] == nil, !withoutShard.contains(candidate.volumeId) {
                if let shard = await store.shard(for: candidate.volumeId) {
                    shards[candidate.volumeId] = shard
                } else {
                    withoutShard.insert(candidate.volumeId)
                }
            }
            // A shard the reader does not hold is skipped in silence: this path queues no fetch,
            // so an absent one is a reader's declined download rather than a fault to report.
            guard let shard = shards[candidate.volumeId],
                  let cosine = shard.cosine(row: row - entry.rowOffset,
                                            query: query.codes, queryScale: query.scale)
            else { continue }
            let score = index.file.retrieval.calibratedDocumentScore(cosine)
            guard score >= floor else { continue }
            scored[candidate] = score
        }
        return scored
    }

    /// The off-index scan, and the reason its threshold is derived rather than chosen.
    ///
    /// ## "Strong" cannot be a constant, and that is measured
    /// Over 60 random anchors against the shipped 512-dim artifact, the Hamming distance of the
    /// **120th** neighbour — the axis's own cut — ranges **104 to 162** by anchor, while a random
    /// corpus pair sits at median **194** with a minimum of **105** over 4,000 pairs. The bands
    /// overlap: one anchor's 120th-best is worse than another pair's coincidence. A fixed corpus-
    /// wide cutoff would therefore admit nothing for some anchors and a wide swathe for others.
    ///
    /// So the cut is the anchor's **own** on-index band, taken from the scan that has already run:
    /// an off-index document is reported when it is at least as near as the last on-index
    /// candidate the axis would itself have shown. Self-calibrating, and free.
    ///
    /// Measured yield with that rule, simulating a reader holding half the corpus: a median of
    /// **94 documents across 19 volumes** per anchor, and every one of 20 sampled anchors found
    /// something.
    ///
    /// ## Why the cap is generous
    /// At a **10% library** — the reader this feature exists for — the median rises to 732 and a
    /// cap of 800 would bind on **43%** of anchors. The Hamming pass is a full corpus scan whatever
    /// the cap, so a larger one costs nothing but the selection; `isCapped` still discloses the
    /// floor when it binds.
    static func offIndexLeads(
        anchorRow: Int,
        corpus: SemanticCorpusVectors,
        index: SemanticVectorIndex,
        onIndexRows: [Int],
        eligible: [UInt8],
        limit: Int
    ) -> SemanticOffIndexLeads {
        // The anchor's own band. `onIndexRows` is nearest-first, so the last one the axis would
        // have shown IS the cut. A short list means the reader holds little; its own last entry is
        // still the right cut, because the claim is comparative and not absolute.
        guard let cutRow = onIndexRows.prefix(limit).last,
              let cutSimilarity = SemanticRetrievalKernel.binarySimilarity(
                anchorRow, cutRow, in: corpus)
        else { return .none }

        let scanned = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: Self.offIndexScanCap,
            isEligible: { eligible[$0] == 0 })
        guard !scanned.isEmpty else { return .none }

        var perVolume: [String: Int] = [:]
        var kept: [Int] = []
        for row in scanned {
            // Nearest-first, so the first row past the cut ends the walk.
            guard let similarity = SemanticRetrievalKernel.binarySimilarity(anchorRow, row, in: corpus),
                  similarity >= cutSimilarity else { break }
            guard let located = index.volumeSlot(containing: row) else { continue }
            perVolume[index.volumes[located.slot].volumeID, default: 0] += 1
            kept.append(row)
        }
        guard !kept.isEmpty else { return .none }
        return SemanticOffIndexLeads(
            documentCount: kept.count,
            volumes: perVolume.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                .map { SemanticOffIndexLeads.VolumeLead(volumeID: $0.key, count: $0.value) },
            // The cap bound only if the walk consumed every scanned row without falling past the cut.
            isCapped: kept.count == scanned.count && scanned.count >= Self.offIndexScanCap,
            rows: kept)
    }

    /// Runs the off-index scan for an anchor, end to end, and scores what it can.
    ///
    /// A separate entry point rather than a second return value from ``candidates(for:anchorYear:limit:scopeVolumeIds:appState:)``:
    /// `GeneratedPool` is document-grain and record-bearing — every candidate needs a
    /// `document_cache` row to render — and a finding about documents this device *cannot* render
    /// has no shape there. So the engine calls this beside the generator and carries the result on
    /// its own result type.
    ///
    /// It re-runs the on-index Hamming pass rather than sharing the generator's. That pass is a
    /// measured 1.43 ms over the whole corpus, and the alternative — threading one axis's internals
    /// out through the shared `SimilarityGenerator` protocol — would make every other axis carry a
    /// parameter for this one.
    ///
    /// **The volume channel deliberately does not need the anchor's own shard.** The cut is a
    /// binary-similarity comparison over the bundled sign bits, so a reader whose anchor shard is
    /// still downloading gets the leads even though the axis itself shows nothing at all.
    ///
    /// - Parameters:
    ///   - anchor: The seed document.
    ///   - limit: The axis's own candidate limit — the rank whose distance becomes the cut.
    ///   - scopeVolumeIds: The caller's volume restriction, if any. It narrows what counts as
    ///     *held*, exactly as it does for the axis, so a scoped panel reports leads against the
    ///     scope the reader is looking at.
    ///   - appState: Holds the live index and the shard store.
    /// - Returns: The leads, or `.none` when the stack is absent or nothing cleared the cut.
    static func offIndexSection(
        for anchor: DocumentKey,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        appState: AppState
    ) async -> SemanticOffIndexLeads {
        guard let index = BundledSemanticVectors.index,
              let corpus = BundledSemanticVectors.corpusVectors,
              let store = appState.semanticShardStore,
              let anchorRow = index.row(documentID: anchor.documentId, volumeID: anchor.volumeId)
        else { return .none }

        let eligibleVolumes = Self.eligibleVolumeIDs(
            indexed: appState.indexedVolumeIds, scope: scopeVolumeIds)
        guard !eligibleVolumes.isEmpty else { return .none }
        var eligible = [UInt8](repeating: 0, count: index.documentCount)
        for volumeID in eligibleVolumes {
            guard let range = index.rows(forVolume: volumeID) else { continue }
            for row in range { eligible[row] = 1 }
        }

        let onIndex = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: max(limit, index.file.retrieval.rerankPool),
            isEligible: { eligible[$0] == 1 })
        var leads = Self.offIndexLeads(
            anchorRow: anchorRow, corpus: corpus, index: index,
            onIndexRows: onIndex, eligible: eligible, limit: limit)
        guard leads.documentCount > 0 else { return .none }

        leads.documents = await Self.offIndexDocuments(
            anchor: anchor, anchorRow: anchorRow, rows: leads.rows, index: index, store: store)
        return leads
    }

    /// The document channel: exact cosines for the kept rows whose volume shard is already here.
    ///
    /// Walks the kept rows nearest-first up to ``offIndexDocumentDepth``, scores every one whose
    /// volume shard is present, and hands the whole scored pool to ``rankOffIndexDocuments(_:anchor:limit:)``.
    ///
    /// **Scoring the pool and cutting afterwards is the point, not an accident of structure.** The
    /// walk is in Hamming order and the display is in cosine order; a version of this that stopped
    /// walking once it had `limit` rows would show the first five by Hamming, merely re-sorted —
    /// which is exactly the funnel the on-index path exists to avoid (binary recalled 0.53 of the
    /// exact top ten at 256, where the shipped 512-width funnel recalls 0.851).
    private static func offIndexDocuments(
        anchor: DocumentKey,
        anchorRow: Int,
        rows: [Int],
        index: SemanticVectorIndex,
        store: SemanticShardStore
    ) async -> [SemanticOffIndexLeads.DocumentLead] {
        // The query vector is the anchor's own, which needs the anchor's shard. Absent, the volume
        // channel still stands; only the exact scores are unavailable.
        guard let anchorEntry = index.volume(anchor.volumeId),
              let anchorShard = await store.shard(for: anchor.volumeId),
              let query = anchorShard.vector(at: anchorRow - anchorEntry.rowOffset)
        else { return [] }

        var shards: [Int: SemanticShard?] = [:]
        var scored: [SemanticOffIndexLeads.DocumentLead] = []
        for row in rows.prefix(Self.offIndexDocumentDepth) {
            guard let located = index.volumeSlot(containing: row) else { continue }
            let volumeID = index.volumes[located.slot].volumeID
            if shards[located.slot] == nil { shards[located.slot] = await store.shard(for: volumeID) }
            guard let shard = shards[located.slot] ?? nil,
                  let document = index.document(at: row),
                  let cosine = shard.cosine(
                    row: located.localRow, query: query.codes, queryScale: query.scale)
            else { continue }
            scored.append(SemanticOffIndexLeads.DocumentLead(
                volumeID: document.volumeID, documentID: document.documentID,
                score: index.file.retrieval.calibratedDocumentScore(cosine)))
        }
        return Self.rankOffIndexDocuments(
            scored, anchor: anchor, limit: Self.offIndexDocumentLimit)
    }

    /// Ranks the scored off-index candidates and folds edition twins out of them.
    ///
    /// Pure, and separated from the walk above so the rule can be driven by a test rather than
    /// pinned by reading the source — the walk needs a shard store and the index, this needs
    /// neither.
    ///
    /// **Sorting happens before folding**, which is what makes `foldingTwins`' documented
    /// first-wins rule keep the better-scored edition rather than whichever the scan reached first.
    /// **And the limit is applied after both**, so a twin pair inside the top `limit` costs a slot
    /// to the fold and not to the list.
    ///
    /// **One twin case is deliberately left unhandled**: whether the reader already holds a twin of
    /// an off-index document *on-index*. That needs a fold key for every on-index row, and the
    /// volume channel beside this cannot afford that walk at all — so handling it here would make
    /// the two channels disagree about the same document, which is worse than the residue.
    ///
    /// - Parameters:
    ///   - scored: The candidates, in any order.
    ///   - anchor: The seed, whose own reprint in another edition is dropped — to the reader it IS
    ///     the anchor.
    ///   - limit: How many survive.
    /// - Returns: The kept leads, best first.
    nonisolated static func rankOffIndexDocuments(
        _ scored: [SemanticOffIndexLeads.DocumentLead],
        anchor: DocumentKey,
        limit: Int
    ) -> [SemanticOffIndexLeads.DocumentLead] {
        let ranked = scored
            .filter { !(SemanticEditionTwins.areTwins($0.volumeID, anchor.volumeId)
                        && $0.documentID == anchor.documentId) }
            .sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
        let folded = SemanticEditionTwins.foldingTwins(ranked) { ($0.volumeID, $0.documentID) }
        return Array(folded.prefix(max(0, limit)))
    }

    /// How deep the off-index scan selects. See `offIndexLeads` for why it is not 800.
    static let offIndexScanCap = 4096

    /// How many off-index documents the section names at most.
    static let offIndexDocumentLimit = 5

    /// How many kept rows the document channel examines before it stops looking. Bounded because a
    /// reader holding almost nothing can clear the cut thousands of times, and every new volume in
    /// that walk costs a shard lookup that will usually miss.
    static let offIndexDocumentDepth = 200

}

// MARK: - AppSemanticSimilaritySource

/// The app's semantic axis for the kit's engine: this generator's three passes over SemanticVectorsKit's
/// bundled tiers and the app's shard store, bound to the `AppState` that holds them.
///
/// `RelatedDocumentsDependencies(appState:)` passes one, so the engine runs the axis as it did when it
/// called these passes with its own `AppState`.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a
@MainActor
struct AppSemanticSimilaritySource: SemanticSimilaritySource {

    /// Holds the shard store and the indexed volumes the passes read.
    let appState: AppState

    /// The generator's own candidates (``SemanticSimilarityGenerator/candidates(for:anchorYear:limit:scopeVolumeIds:appState:)``).
    func candidates(for anchor: DocumentKey, anchorYear: Int?, limit: Int,
                    scopeVolumeIds: Set<String>?) async throws -> GeneratedPool {
        try await SemanticSimilarityGenerator().candidates(
            for: anchor, anchorYear: anchorYear, limit: limit,
            scopeVolumeIds: scopeVolumeIds, appState: appState)
    }

    /// The off-index scan (``SemanticSimilarityGenerator/offIndexSection(for:limit:scopeVolumeIds:appState:)``).
    func offIndexSection(for anchor: DocumentKey, limit: Int,
                         scopeVolumeIds: Set<String>?) async -> SemanticOffIndexLeads {
        await SemanticSimilarityGenerator.offIndexSection(
            for: anchor, limit: limit, scopeVolumeIds: scopeVolumeIds, appState: appState)
    }

    /// The re-score (``SemanticSimilarityGenerator/reScore(anchor:candidates:floor:store:)``) over the
    /// shard store `AppState` holds now, the store the engine read before it called the re-score
    /// itself; with none there is nothing to score. `reScore` is still given the store alone, so it
    /// can queue no fetch.
    func reScore(anchor: DocumentKey, candidates: Set<DocumentKey>,
                 floor: Double) async -> [DocumentKey: Double] {
        guard let store = appState.semanticShardStore else { return [:] }
        return await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: candidates, floor: floor, store: store)
    }
}
