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
/// asked for in a background fetch instead, so the surface warms up across a few uses; the result
/// carries the count of what was dropped, because a surface that silently narrowed itself to the
/// shards it happens to hold would present a library-local answer as a corpus-wide one, and the
/// count of those whose download the request says is under way (#1527).
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
///   1.1 — Session 2026-09-30: #1527 — `Results.downloadingVolumes` counts the unscored volumes
///         with a match-file download under way, so a caption can tell "downloading" from "not"
///   1.2 — Session 2026-09-30, review round 1: #1527 — the fetch request answers whether a
///         download started, and every search asks again, so an ask declined while the switch was
///         off or the device offline no longer counts as downloading once they change
///   1.3 — #1577 lane 1: `search(_:within:limit:)` ranks a given set of documents, every member
///         scored exactly, where the corpus-wide search could only be filtered down to the set
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
        /// the honest-disclosure counterpart of the axis's silent fence. The top of the order's
        /// fetches are asked for, and where they start the next search is better.
        let unscoredCandidates: Int
        /// Distinct volumes those dropped candidates came from.
        let unscoredVolumes: Int
        /// Of those volumes, how many have a match-file download under way, as this search's
        /// fetch requests were answered (#1527). Only candidates in the top ``fetchQueueDepth`` of
        /// the order are asked for, so a volume whose candidates all rank below them is counted in
        /// ``unscoredVolumes`` and not here. An ask is counted only when it was answered `true`:
        /// `AppState.requestSemanticShardForSearch` says no while Download With Volumes is off,
        /// offline, with no fetcher, for a volume with no published file, and for one whose fetch
        /// already failed this session.
        let downloadingVolumes: Int
        /// How many documents the search ranked inside, for ``search(_:within:limit:)``: the
        /// distinct keys it was given. `nil` for the corpus-wide search, which ranks the series.
        ///
        /// Every member is in exactly one of three counts, so
        /// `ranked + withoutVector + unscoredCandidates == rankedWithin`, where `ranked` is the
        /// number of members scored (``hits`` is its best `limit`).
        let rankedWithin: Int?
        /// Members of that set the bundled vectors hold no row for, which no search can rank:
        /// front matter, chapter headings and appendix structure are never embedded, and a
        /// document newer than this build's vectors has none yet. Zero for the corpus-wide
        /// search, whose candidates all come from the vectors.
        let withoutVector: Int

        /// Creates a result.
        ///
        /// - Parameters:
        ///   - hits: Ranked hits, best first.
        ///   - unscoredCandidates: Documents not scored for want of their volume's match file.
        ///   - unscoredVolumes: Distinct volumes those came from.
        ///   - downloadingVolumes: Of those volumes, the ones with a download under way.
        ///   - rankedWithin: The size of the set ranked inside, or `nil` for the whole series.
        ///   - withoutVector: Members of that set with no vector.
        init(hits: [Hit], unscoredCandidates: Int, unscoredVolumes: Int, downloadingVolumes: Int,
             rankedWithin: Int? = nil, withoutVector: Int = 0) {
            self.hits = hits
            self.unscoredCandidates = unscoredCandidates
            self.unscoredVolumes = unscoredVolumes
            self.downloadingVolumes = downloadingVolumes
            self.rankedWithin = rankedWithin
            self.withoutVector = withoutVector
        }
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
    /// Asks for a background shard fetch for a volume and answers whether a download is under way
    /// for it — `AppState.requestSemanticShardForSearch`, injected so this actor never touches the
    /// main actor itself.
    private let requestShardFetch: @Sendable (String) async -> Bool
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

    /// How deep into the Hamming order missing-shard volumes are queued for fetch. Bounded so a
    /// first search does not queue hundreds of files: the pool is 800, but the top of the order
    /// is where the next search's answers live.
    static let fetchQueueDepth = 100

    /// How many volumes a search inside a document set asks for at most, when their match files
    /// are missing (#1577). The corpus-wide bound above is a depth in candidate order and has no
    /// meaning here, where there is no candidate order: every member is scored or it is not. So
    /// the bound is a count of volumes, taken from those with most unranked members first, since
    /// they are what the next search gains most from. At the mean file size of 294 KB, 24 volumes
    /// are about 7 MB a search. Download Missing Vectors in Settings fetches the rest.
    static let setFetchVolumeLimit = 24

    init(
        index: SemanticVectorIndex,
        corpus: SemanticCorpusVectors,
        modelStore: SemanticModelStore,
        shardStore: SemanticShardStore,
        requestShardFetch: @escaping @Sendable (String) async -> Bool,
        embedOverride: (@Sendable (String) async throws -> [Double])? = nil
    ) {
        self.index = index
        self.corpus = corpus
        self.modelStore = modelStore
        self.shardStore = shardStore
        self.requestShardFetch = requestShardFetch
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
        let (bits, int8) = try await quantizedQuery(query)

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
        let downloading = await Self.requestFetches(for: fetchWorthy, using: requestShardFetch)

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
            unscoredVolumes: droppedVolumes.count,
            downloadingVolumes: downloading.count)
    }

    /// Ranks a given set of documents by meaning: every member that can be scored is scored
    /// exactly, and the best `limit` are returned (#1577 lane 1).
    ///
    /// ## Why this is not the corpus-wide search with a filter
    ///
    /// ``search(_:limit:)`` returns the closest documents in the whole series. Asked for the
    /// closest inside a working corpus, it could only be filtered afterwards, and a set whose
    /// members all rank below the series' top hundred came back empty though every one of them
    /// had a score to give. Here there is no candidate stage at all. The Hamming scan exists to
    /// choose which 800 of 314,616 documents are worth an exact score; a set of a few thousand
    /// needs no choosing, so each member goes straight to the kernel's `rerank`, the same exact
    /// int8 cosine and the same tie-break the corpus-wide search ends with. The kit's restricted
    /// scan (`hammingCandidates(…isEligible:)`) is left alone for that reason: it would have to
    /// return as many candidates as rows shown, above the pool its recall was measured at.
    ///
    /// ## Every member is accounted for
    ///
    /// A member is ranked, or it has no vector (``Results/withoutVector``), or its volume's match
    /// file is not on this device (``Results/unscoredCandidates``). None is dropped in silence and
    /// none is scored as zero, which would be a claim of unlikeness. `rerank` drops a row it
    /// cannot score, so the three are counted here, around the call.
    ///
    /// ## What it does not do
    ///
    /// **Edition twins are not folded.** The corpus-wide search folds them because it chose the
    /// documents; here the reader did, and removing one of two documents they put in the set
    /// would be an edit to their set.
    ///
    /// **A set with nothing to score never loads the encoder.** That is an empty set, a set with
    /// no vectors, and a set whose every rankable member is in a volume with no match file on the
    /// device. The 229 MB model is not read and its absence is not reported, because the reader
    /// would be offered a download that could not rank a single document; in the last case the
    /// missing files are asked for, and they are what the reader is told about. So the match
    /// files are looked for before the question is encoded, the other way round from the
    /// corpus-wide search, which needs the embedding to choose its candidates at all.
    ///
    /// - Parameters:
    ///   - query: The reader's text, verbatim; the query template is applied inside.
    ///   - keys: The set, each member keyed `"volumeId/documentId"` as `SearchParameters.documentIds`
    ///     keys it. Order carries no meaning and a repeated key counts once.
    ///   - limit: Ranked hits to return.
    /// - Returns: The best `limit` members, best first, with the set's accounting.
    /// - Throws: `SearchUnavailable`.
    func search(_ query: String, within keys: [String], limit: Int) async throws -> Results {
        let clock = ContinuousClock()

        // Keys to corpus rows. A key the vectors hold no row for cannot be ranked by anyone.
        let resolveStart = clock.now
        var distinct: Set<String> = []
        var members: [(row: Int, slot: Int)] = []
        var identityByRow: [Int: (volumeID: String, documentID: String)] = [:]
        var withoutVector = 0
        for key in keys where distinct.insert(key).inserted {
            guard let slash = key.firstIndex(of: "/") else {
                withoutVector += 1
                continue
            }
            let volumeID = String(key[..<slash])
            let documentID = String(key[key.index(after: slash)...])
            // A row already claimed cannot be claimed twice: the index maps one id to one row, so
            // this is unreachable today, and counting such a key keeps the accounting whole if a
            // later index ever let two spellings share a row.
            guard let row = index.row(documentID: documentID, volumeID: volumeID),
                  let located = index.volumeSlot(containing: row),
                  identityByRow[row] == nil
            else {
                withoutVector += 1
                continue
            }
            identityByRow[row] = (volumeID, documentID)
            members.append((row: row, slot: located.slot))
        }
        let resolveTime = clock.now - resolveStart

        guard !members.isEmpty else {
            return Results(hits: [], unscoredCandidates: 0, unscoredVolumes: 0,
                           downloadingVolumes: 0, rankedWithin: distinct.count,
                           withoutVector: withoutVector)
        }

        // Each volume's match file is asked for once. `rerank` scores through a synchronous
        // closure, so the files are in hand before it is called.
        let shardStart = clock.now
        var shards: [Int: SemanticShard] = [:]
        var volumesAsked = 0
        for slot in Set(members.map(\.slot)).sorted() {
            volumesAsked += 1
            if let shard = await shardStore.shard(for: index.volumes[slot].volumeID) {
                shards[slot] = shard
            }
        }
        var candidates: [Int] = []
        candidates.reserveCapacity(members.count)
        var unscoredByVolume: [String: Int] = [:]
        for member in members {
            if shards[member.slot] != nil {
                candidates.append(member.row)
            } else {
                unscoredByVolume[index.volumes[member.slot].volumeID, default: 0] += 1
            }
        }
        let shardTime = clock.now - shardStart
        let unscored = unscoredByVolume.values.reduce(0, +)

        // Nothing to score: every rankable member's file is missing. The files are asked for and
        // the question is not encoded.
        guard !candidates.isEmpty else {
            let downloading = await Self.requestFetches(
                for: Set(Self.volumesWorthFetching(unscoredByVolume)), using: requestShardFetch)
            return Results(hits: [], unscoredCandidates: unscored,
                           unscoredVolumes: unscoredByVolume.count,
                           downloadingVolumes: downloading.count,
                           rankedWithin: distinct.count, withoutVector: withoutVector)
        }

        let encodeStart = clock.now
        let (_, int8) = try await quantizedQuery(query)
        let encodeTime = clock.now - encodeStart

        // Asked for in full, and cut to `limit` below, so the count of what was scored is the
        // kernel's own and not a guess at what it dropped.
        let scoreStart = clock.now
        let ranked = SemanticRetrievalKernel.rerank(
            candidates: candidates, limit: candidates.count
        ) { row in
            guard let located = index.volumeSlot(containing: row),
                  let shard = shards[located.slot] else { return nil }
            return shard.cosine(row: located.localRow, query: int8.codes, queryScale: int8.scale)
        }
        let scoreTime = clock.now - scoreStart
        // A member whose file is here and whose row it would not score: no usable vector.
        withoutVector += candidates.count - ranked.count

        let hits: [Hit] = ranked.prefix(max(0, limit)).compactMap { neighbour in
            guard let identity = identityByRow[neighbour.row] else { return nil }
            return Hit(volumeID: identity.volumeID, documentID: identity.documentID,
                       score: neighbour.score)
        }

        let downloading = await Self.requestFetches(
            for: Set(Self.volumesWorthFetching(unscoredByVolume)), using: requestShardFetch)

        SearchTimingLog.record(SearchTimingLog.MeaningInSet(
            setSize: distinct.count,
            withVector: members.count,
            volumes: volumesAsked,
            ranked: ranked.count,
            encode: encodeTime,
            resolve: resolveTime,
            shards: shardTime,
            score: scoreTime))

        return Results(
            hits: hits,
            unscoredCandidates: unscored,
            unscoredVolumes: unscoredByVolume.count,
            downloadingVolumes: downloading.count,
            rankedWithin: distinct.count,
            withoutVector: withoutVector)
    }

    /// The volumes a search inside a set asks for, of those whose match files are missing: the
    /// ``setFetchVolumeLimit`` with most unranked members, most first, a tie going to the volume
    /// whose id sorts first so that the choice is the same on every search.
    ///
    /// - Parameter unrankedByVolume: Volume id to the count of the set's members in it that went
    ///   unranked for want of its match file.
    /// - Returns: The volumes to ask for, most unranked members first.
    static func volumesWorthFetching(_ unrankedByVolume: [String: Int]) -> [String] {
        unrankedByVolume
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(setFetchVolumeLimit)
            .map(\.key)
    }

    /// The query as both searches score with it: embedded, cut to the artifact's shipping width,
    /// and quantized by the pinned rules — the judged pipeline's first three steps, in one place
    /// so the two searches cannot take them differently.
    ///
    /// - Parameter query: The reader's text, verbatim.
    /// - Returns: The packed sign bits for the Hamming scan, and the int8 codes and scale for the
    ///   exact cosine.
    /// - Throws: `SearchUnavailable`.
    private func quantizedQuery(
        _ query: String
    ) async throws -> (bits: [UInt8], int8: (codes: [Int8], scale: Float)) {
        let embedding = try await embed(query)
        guard let cut = SemanticQuantization.truncate(embedding, to: index.provenance.shippingDims)
        else { throw SearchUnavailable.encodingFailed("query vector would not truncate") }
        guard let int8 = SemanticQuantization.quantizeInt8(cut)
        else { throw SearchUnavailable.encodingFailed("query vector quantized to nothing") }
        return (SemanticQuantization.packSignBits(cut), int8)
    }

    /// Asks for each volume's match file and returns the volumes whose request was answered with a
    /// download under way (#1527).
    ///
    /// Asked on every search, not once per launch: a request declined while Download With Volumes
    /// was off or the device offline is asked again once they change, and a fetch that has since
    /// failed answers no. The requests are cheap to repeat, since the fetcher de-duplicates a fetch
    /// already running. Sorted so the requests go out in a stable order.
    ///
    /// - Parameters:
    ///   - volumes: The volumes to ask for — the unscored ones in the top ``fetchQueueDepth``, or
    ///     for a search inside a set the ``setFetchVolumeLimit`` with most unranked members.
    ///   - request: The request, answering whether that volume's download is under way.
    /// - Returns: The volumes answered `true`.
    static func requestFetches(
        for volumes: Set<String>, using request: @Sendable (String) async -> Bool
    ) async -> Set<String> {
        var downloading: Set<String> = []
        for volumeID in volumes.sorted() {
            if await request(volumeID) { downloading.insert(volumeID) }
        }
        return downloading
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
