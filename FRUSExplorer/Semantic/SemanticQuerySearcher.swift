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

/// Typed natural-language search over the pinned semantic space (V-5 s3): encode the reader's
/// query on-device, run the shipped funnel, fold edition twins, disclose what could not be
/// scored.
///
/// ## The pipeline is the judged one, step for step
///
/// `SemanticQueryPrompt.queryPrefix` + query → the encoder (the s2-accepted wrapper) →
/// `SemanticQuantization.truncate` to the artifact's `shippingDims` → sign bits → corpus-wide
/// Hamming at the artifact's `rerankPool` → exact int8 cosine against Tier-2 shards. This is the
/// exact route the owner's 25-query sitting judged at P 0.65 / MRR 0.77, entered through the same
/// parity-pinned kernel doorway the evaluation harness uses — the only difference from the
/// harness is WHO embeds the query, and the encoder's own gate pins that at min cosine 0.99986.
///
/// ## Missing shards: the Related-axis rule, adopted whole
///
/// A candidate whose shard this device does not hold is **dropped, not scored** — an absent shard
/// is missing evidence, and a zero would be a claim of dissimilarity — and there is **no Hamming
/// fallback**, because raw binary recalls 0.53 against the funnel's 0.851 and a list mixing the
/// two scales would be sorted by a number that means different things in different rows
/// (`SemanticSimilarityGenerator`'s written argument, which binds here too). Missing volumes are
/// queued for a background fetch instead, so the surface warms up across a few uses; the result
/// carries the count of what was dropped, because a surface that silently narrowed itself to the
/// shards it happens to hold would present a library-local answer as a corpus-wide one.
///
/// ## Unlike the Related axis, candidates are NOT fenced to the library
///
/// The axis fences candidates through `document_cache` so it never offers a document the reader
/// cannot open. This surface deliberately does not: corpus-wide discovery is the measured value
/// (the sitting's rescued queries found documents wherever they were), so a hit in a volume the
/// reader lacks is SHOWN — titled from the manifest, marked not-downloaded, with the download
/// affordance — the cross-reference graph's #262 presentation rule rather than the axis's fence.
///
/// Version history:
///   1.0 — V-5 s3: initial implementation
actor SemanticQuerySearcher {

    /// One ranked hit.
    struct Hit: Equatable, Sendable {
        /// Manifest `volumeId`.
        let volumeID: String
        /// TEI document id (`d139`).
        let documentID: String
        /// Exact int8 cosine in the pinned space, the axis's self-normalising scale.
        let score: Double
    }

    /// What a search produced, including what it could not score.
    struct Results: Equatable, Sendable {
        /// Ranked hits, best first, edition twins folded.
        let hits: [Hit]
        /// Candidate documents dropped because their volume's shard is not on this device —
        /// the honest-disclosure counterpart of the axis's silent fence. Their fetches are
        /// queued; the next search is better.
        let unscoredCandidates: Int
        /// Distinct volumes those dropped candidates came from.
        let unscoredVolumes: Int
    }

    /// Why a search could not run at all.
    enum SearchUnavailable: Error, Equatable {
        /// The model file is not on this device — the UI's cue to offer the download.
        case modelNotDownloaded
        /// The bundled vector artifacts are unavailable (a build state, not a library state).
        case vectorsUnavailable
        /// The query tokenized past the model's context (the encoder's refusal, surfaced).
        case queryTooLong
        /// The encoder failed for another reason, described.
        case encodingFailed(String)
    }

    private let index: SemanticVectorIndex
    private let corpus: SemanticCorpusVectors
    private let modelStore: SemanticModelStore
    private let shardStore: SemanticShardStore
    /// Queues a background shard fetch for a volume — `AppState.fetchSemanticShardIfNeeded`
    /// with `.readerAskedForSemantics`, injected so this actor never touches the main actor.
    private let queueShardFetch: @Sendable (String) -> Void
    /// The embed step, injectable so tests can drive the funnel with fixture vectors and no
    /// 229 MB model. `nil` means the real encoder through the model store's verified door.
    private let embedOverride: (@Sendable (String) async throws -> [Double])?

    /// The encoder, created lazily on first search and dropped by the idle watchdog.
    private var encoder: SemanticQueryEncoder?
    /// Bumped per search; the idle watchdog unloads only if nothing newer ran.
    private var searchGeneration = 0

    /// How long the encoder stays resident after the last search. The measured cost of being
    /// wrong in either direction: resident is ~250 MB footprint (the s2 measurement), reload is
    /// ~0.4 s cold — so a short idle window that drops the big number and re-pays the small one.
    static let encoderIdleSeconds: UInt64 = 180

    /// Volumes queued for fetch at most once per searcher lifetime, so repeated searches do not
    /// re-queue the same misses (the fetcher's own failure memory would refuse them anyway, but
    /// there is no point asking).
    private var queuedVolumes: Set<String> = []

    /// How deep into the Hamming order missing-shard volumes are queued for fetch. Bounded so a
    /// first search does not queue hundreds of files: the pool is 800, but the top of the order
    /// is where the next search's answers live.
    static let fetchQueueDepth = 100

    init(
        index: SemanticVectorIndex,
        corpus: SemanticCorpusVectors,
        modelStore: SemanticModelStore,
        shardStore: SemanticShardStore,
        queueShardFetch: @escaping @Sendable (String) -> Void,
        embedOverride: (@Sendable (String) async throws -> [Double])? = nil
    ) {
        self.index = index
        self.corpus = corpus
        self.modelStore = modelStore
        self.shardStore = shardStore
        self.queueShardFetch = queueShardFetch
        self.embedOverride = embedOverride
    }

    /// Runs one semantic search.
    ///
    /// - Parameters:
    ///   - query: The reader's text, verbatim; the query template is applied inside.
    ///   - limit: Ranked hits to return after twin folding.
    /// - Returns: Hits plus the unscored disclosure.
    /// - Throws: `SearchUnavailable`.
    func search(_ query: String, limit: Int = 10) async throws -> Results {
        let embedding = try await embed(query)

        guard let cut = SemanticQuantization.truncate(embedding, to: index.provenance.shippingDims)
        else { throw SearchUnavailable.encodingFailed("query vector would not truncate") }
        guard let int8 = SemanticQuantization.quantizeInt8(cut)
        else { throw SearchUnavailable.encodingFailed("query vector quantized to nothing") }
        let bits = SemanticQuantization.packSignBits(cut)

        let pool = max(limit, index.file.retrieval.rerankPool)
        let rows = SemanticRetrievalKernel.hammingCandidates(
            queryBits: bits, in: corpus, limit: pool)

        // Exact scoring where a shard exists; the drop-and-queue rule the header explains.
        // One pass collects both disclosures: every dropped candidate's volume (the caption's
        // "N documents in M volumes"), and the top-of-order subset that gets a fetch queued.
        var shards: [Int: SemanticShard?] = [:]
        var fetchWorthy: Set<String> = []
        var droppedVolumes: Set<String> = []
        var unscored = 0
        var scored: [(row: Int, score: Double)] = []
        scored.reserveCapacity(rows.count)
        for (order, row) in rows.enumerated() {
            guard let located = index.volumeSlot(containing: row) else { continue }
            let volumeID = index.volumes[located.slot].volumeID
            if shards[located.slot] == nil {
                shards[located.slot] = await shardStore.shard(for: volumeID)
            }
            guard let shard = shards[located.slot] ?? nil else {
                unscored += 1
                droppedVolumes.insert(volumeID)
                if order < Self.fetchQueueDepth { fetchWorthy.insert(volumeID) }
                continue
            }
            guard let score = shard.cosine(
                row: located.localRow, query: int8.codes, queryScale: int8.scale) else { continue }
            scored.append((row: row, score: score))
        }
        for volumeID in fetchWorthy where !queuedVolumes.contains(volumeID) {
            queuedVolumes.insert(volumeID)
            queueShardFetch(volumeID)
        }

        // The kernel's tie-break, then identity, then the twin fold — first-wins keeps the
        // better-scored edition.
        scored.sort { $0.score == $1.score ? $0.row < $1.row : $0.score > $1.score }
        let identified: [Hit] = scored.compactMap { candidate in
            guard let identity = index.document(at: candidate.row) else { return nil }
            return Hit(volumeID: identity.volumeID, documentID: identity.documentID,
                       score: candidate.score)
        }
        let folded = SemanticEditionTwins.foldingTwins(identified) { ($0.volumeID, $0.documentID) }

        return Results(
            hits: Array(folded.prefix(limit)),
            unscoredCandidates: unscored,
            unscoredVolumes: droppedVolumes.count)
    }

    /// Embeds through the override or the real encoder, managing the encoder's lifetime.
    private func embed(_ query: String) async throws -> [Double] {
        if let embedOverride {
            return try await embedOverride(query)
        }
        guard let modelURL = await modelStore.verifiedModelURL() else {
            throw SearchUnavailable.modelNotDownloaded
        }
        let encoder = self.encoder ?? SemanticQueryEncoder()
        self.encoder = encoder
        searchGeneration += 1
        let generation = searchGeneration
        defer { scheduleIdleUnload(after: generation) }
        do {
            try await encoder.load(modelPath: modelURL.path)
            return try await encoder.encodeQuery(query)
        } catch SemanticQueryEncoder.EncoderError.queryTooLong {
            throw SearchUnavailable.queryTooLong
        } catch let error as SearchUnavailable {
            throw error
        } catch {
            throw SearchUnavailable.encodingFailed("\(error)")
        }
    }

    /// Drops the encoder after the idle window unless a newer search has run.
    private func scheduleIdleUnload(after generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.encoderIdleSeconds * 1_000_000_000)
            await self?.unloadIfIdle(since: generation)
        }
    }

    private func unloadIfIdle(since generation: Int) async {
        guard generation == searchGeneration, let encoder else { return }
        await encoder.unload()
        self.encoder = nil
    }
}
