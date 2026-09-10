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
/// with no archival key and no citation. Every other generator needs an editorial or archival hook
/// that the early corpus does not carry.
///
/// **Re-measured 2026-09-06: 45,030 of 316,839 documents, and the predicate matters more than the
/// number.** The figure this comment used to give — 46,234 — came from the lexical-neighbours
/// assessment and travelled without the rule that produced it, so it could not be reproduced or
/// falsified. The rule is: *no row in `document_sources`, and no `cross_references` row on either
/// side with `is_broken = 0`* (a NULL `target_volume_id` coalesced to the source's). State it
/// beside the count; a bare number here is what let the stale one survive.
///
/// **And the pre-1900 fact, restored in the direction its source actually states it.** The old
/// comment read "98.2% of them pre-1900", which inverts the assessment it came from — that
/// document says *pre-1900 is 98.2% zero-candidate*, a statement about early documents, not about
/// the composition of the zero-candidate set. Re-measured, both directions differ from it:
/// **93.9% of pre-1900 documents are zero-candidate** (33,729 documents, 31,667 of them with no
/// candidate), while only **70.3% of zero-candidate documents are pre-1900**. The first is the
/// number that argues for this axis; the second is what the old sentence appeared to claim and was
/// never true.
///
/// **Coverage against that population, which is the half the design actually asks for:** the
/// bundled index holds a vector for **43,552 of the 45,030 (96.7%)**; **1,478 are unreachable
/// because they carry no vector at all**, the corpus being 314,571 vectored rows against 316,839
/// display rows. Do NOT compare this with the lexical axis's 32,956 — that measures a different
/// population (source-noted rows only, 264,487) under a stricter served rule.
///
/// ## The pipeline, and why each stage is where it is
///
/// 1. **Candidates come from the bundled Tier-1 block**, a sign vector per document (one bit per
///    shipping dimension) for all 314,571 documents — so candidate generation works with *zero
///    volumes downloaded* and reaches volumes the reader does not have. A full corpus scan is
///    1.43 ms, measured at the 256 width on an M1 Max; the ladder spike puts the same kernel
///    about 1.6x slower at the shipped 512.
/// 2. **The display fence is applied inside the scan**, as a precomputed per-row eligibility byte
///    array built from the indexed volumes' row ranges. Filtering afterwards would let ineligible
///    rows consume the candidate pool — measured in V-2 as a 50-candidate request returning 28.
/// 3. **Scoring is exact int8 cosine** against Tier-2 shards. A candidate whose shard this device
///    does not hold is **dropped, not scored** — an absent shard is missing evidence, and a zero
///    would be a claim of dissimilarity.
/// 4. **Missing shards are queued for fetch**, so a library that has never used the axis warms up
///    across a few uses rather than downloading ~162 MB the first time anyone opens it.
///
/// ## What it deliberately does not do
///
/// It does not fall back to ranking by Hamming distance when a shard is missing. Raw binary recalls
/// 0.53 of the exact top ten at 256 (V-0's raw binary tier) where the shipped 512-width funnel
/// recalls 0.851, and the two are different scales — a list mixing them would be sorted by a
/// number that means one thing in some rows and another thing in the rest. Fewer honest rows
/// beat more incomparable ones.
///
/// ## Experimental
///
/// The axis ships at weight 0.5 since 2026-09-10 (raised from 0 by owner decision), and keeps
/// "experimental" in its name — maturity, not worth. The blind panel that would have
/// graded early-era quality was retired as a gate (owner decision 2026-08-12) in favour of tester
/// feedback, so **pre-1900 quality is an unmeasured unknown** — the corpus-scale gate reaches 572
/// pre-1900 queries because the `dN` citation idiom postdates 1945. Say so wherever this axis is
/// described.
///
/// Version history:
///   1.0 — V-3: initial implementation
///   1.1 — S-3: the off-index leads channel (volume counts, plus document grain where a
///          Tier-2 shard is already present)
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
                  let score = shard.cosine(
                    row: located.localRow, query: query.codes, queryScale: query.scale)
            else { continue }
            scored.append(SemanticOffIndexLeads.DocumentLead(
                volumeID: document.volumeID, documentID: document.documentID, score: score))
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

// MARK: - SemanticOffIndexLeads

/// What the semantic axis can see in volumes the reader has **not** indexed (V-3 §6.2(a)).
///
/// Two channels, and what separates them is the shard. The **volume** channel needs nothing but
/// the bundled sign bits, so it always answers: a count, and the volumes holding it. The
/// **document** channel needs a volume's Tier-2 shard to be on this device already, and names
/// documents only where one is — the register `SemanticUndownloadedRow` already ships in search
/// (a document id, its volume's manifest title, a score chip), approved for this surface by the
/// owner on 2026-09-06.
///
/// **Nothing here queues a shard fetch, and that is a decision rather than an omission.** Search
/// queues (`SemanticQuerySearcher.fetchQueueDepth`) because the reader typed a question; here
/// they merely opened a document, and prefetching the top volumes would spend ~294 KB each on
/// volumes they have never asked for. So the document channel is opportunistic — it enriches the
/// section where search or a past download has already paid for the shard, and its absence costs
/// the reader nothing the volume channel does not already say.
struct SemanticOffIndexLeads: Equatable, Sendable {

    /// One volume beyond the reader's library, and how many of its documents cleared the cut.
    struct VolumeLead: Equatable, Sendable, Identifiable {
        /// The volume id. The caller titles it from the manifest, which is the one surface that
        /// knows a volume this device does not hold.
        let volumeID: String
        /// Documents in it at or better than the anchor's own on-index cut.
        let count: Int
        var id: String { volumeID }
    }

    /// One document named outright, because its volume's shard was already on this device.
    struct DocumentLead: Equatable, Sendable, Identifiable {
        let volumeID: String
        let documentID: String
        /// The exact cosine — the same scale as the ranked rows above it. Never a Hamming
        /// distance rescaled to look like one; the axis refuses that mix everywhere else.
        let score: Double
        var id: String { "\(volumeID)/\(documentID)" }
    }

    /// Documents at or better than the anchor's own on-index cut.
    var documentCount: Int
    /// The volumes holding them, most matches first.
    var volumes: [VolumeLead]
    /// `true` when the scan's cap bound, so `documentCount` is a floor and the copy must say so.
    var isCapped: Bool
    /// The kept corpus rows, nearest-first — carried so the document channel need not rescan.
    var rows: [Int] = []
    /// The document channel's rows, best first. Empty when no off-index shard was present.
    var documents: [DocumentLead] = []

    static let none = SemanticOffIndexLeads(documentCount: 0, volumes: [], isCapped: false)
}
