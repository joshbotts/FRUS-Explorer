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

/// The on-device retrieval kernel: an exact brute-force scan, in the two stages the corpus gates
/// measured.
///
/// **No ANN index, by design and now by measurement.** On an M1 Max, a full Hamming scan of all
/// 314,483 documents takes **1.43 ms**, and this kernel's whole funnel — scan, select 800, rescore in
/// int8 against mapped shards — takes **2.44 ms** per query. An approximate index would trade
/// exactness and determinism for time this feature does not need to save. (Both figures are desktop;
/// the oldest supported device is still owed its own measurement, which is what
/// `SemanticVectorsLatencyHarness` exists to take.)
///
/// The funnel and its tie-breaks are not free choices. Every recall number the program has
/// (`Planning/semantic-spike/Phase3-Store-Assessment.md` §5) describes *this* procedure, and a
/// harness running these exact steps over the shipped artifacts reproduced the reference neighbour
/// lists **in exact order for 600 of 600 gate queries**. Change a tie-break and the artifact's stated
/// recall stops describing what the device does.
///
/// Version history:
///   1.0 — V-2: initial implementation
public enum SemanticRetrievalKernel {

    /// One scored neighbour.
    public struct Neighbour: Equatable, Sendable {
        /// Corpus-wide row index.
        public let row: Int
        /// Approximate cosine, reconstructed as `dot(int8, int8) × scaleA × scaleB`.
        ///
        /// Absolute in [-1, 1] — an actual similarity, not a rank score — which is what lets a
        /// consumer show it and compare it across queries.
        public let score: Double

        /// Creates a neighbour.
        /// - Parameters:
        ///   - row: Corpus row index.
        ///   - score: Approximate cosine.
        public init(row: Int, score: Double) {
            self.row = row
            self.score = score
        }
    }

    /// Hamming candidate generation over the bundled sign-bit tier.
    ///
    /// Selection is a **counting sort**, not a heap. Distances are integers in 0...`dims`, so the
    /// whole ranking is three linear passes and no comparison sort: one pass computes distances and
    /// a histogram, a prefix sum turns the histogram into per-distance output offsets, and a second
    /// row pass places each row at its offset. Rows are visited in index order, so within a distance
    /// bucket they land index-ascending — which is exactly the reference's `lexsort((row, distance))`
    /// tie-break, obtained by construction rather than by sorting.
    ///
    /// Two details are load-bearing and were both wrong in a first draft:
    ///
    /// * **The output is ordered by distance**, not merely drawn from the right set. A caller with no
    ///   Tier-2 shard ranks on this order directly, so "the right documents in arbitrary order" is a
    ///   different answer from "nearest first".
    /// * **`isEligible` is applied while the histogram is built**, not while results are collected.
    ///   Filtering afterwards leaves the cutoff computed over rows that were then discarded, and the
    ///   pool comes back short — measured, a 50-candidate request returned 28.
    ///
    /// - Parameters:
    ///   - queryRow: The anchor's corpus row.
    ///   - vectors: The mapped corpus tier.
    ///   - limit: How many candidates to return.
    ///   - isEligible: Optional filter — the display fence, or a volume restriction. An ineligible
    ///     row is excluded from the ranking entirely rather than ranked and dropped.
    /// - Returns: Candidate rows, nearest first, `limit` at most, never including `queryRow`.
    public static func hammingCandidates(
        queryRow: Int,
        in vectors: SemanticCorpusVectors,
        limit: Int,
        isEligible: ((Int) -> Bool)? = nil
    ) -> [Int] {
        guard queryRow >= 0, queryRow < vectors.documentCount else { return [] }
        let words = vectors.withSignBits { base, _ -> [UInt64] in
            let quads = vectors.bytesPerRow / 8
            var query = [UInt64](repeating: 0, count: quads)
            for q in 0..<quads {
                query[q] = base.loadUnaligned(
                    fromByteOffset: queryRow * vectors.bytesPerRow + q * 8, as: UInt64.self)
            }
            return query
        }
        return hammingCandidates(queryWords: words, in: vectors, limit: limit,
                                 excludingRow: queryRow, isEligible: isEligible)
    }

    /// Hamming candidate generation for an **external** query — a vector that is not a corpus row
    /// (W-17 session 3 / the V-5 assessment §6's shared prerequisite: a typed query, embedded and
    /// sign-packed, entering the same funnel every recall number describes).
    ///
    /// - Parameters:
    ///   - queryBits: The query's packed sign bits, **exactly as `SemanticQuantization.packSignBits`
    ///     emits them** — MSB-first within each byte, `>= 0` packing as a set bit — i.e. the same
    ///     byte layout a stored corpus row has. Must be `vectors.bytesPerRow` bytes.
    ///   - vectors: The mapped corpus tier.
    ///   - limit: How many candidates to return.
    ///   - isEligible: Optional filter, applied while the histogram is built (see the row form).
    /// - Returns: Candidate rows, nearest first, `limit` at most.
    ///
    /// Parity is pinned, not assumed: `SemanticVectorsKitTests` feeds a corpus row's own bytes
    /// through this overload (excluding the row via `isEligible`) and requires the row form's exact
    /// candidate list — the tie-breaks ARE the measurement, so a new entry point that merely
    /// "should" agree would silently invalidate the artifact's stated recall.
    public static func hammingCandidates(
        queryBits: [UInt8],
        in vectors: SemanticCorpusVectors,
        limit: Int,
        isEligible: ((Int) -> Bool)? = nil
    ) -> [Int] {
        guard queryBits.count == vectors.bytesPerRow else { return [] }
        let quads = vectors.bytesPerRow / 8
        let words: [UInt64] = queryBits.withUnsafeBytes { raw in
            (0..<quads).map { raw.loadUnaligned(fromByteOffset: $0 * 8, as: UInt64.self) }
        }
        return hammingCandidates(queryWords: words, in: vectors, limit: limit,
                                 excludingRow: nil, isEligible: isEligible)
    }

    /// The shared scan both entry points run. Extracted verbatim from the row form so the shipped
    /// path stays byte-identical (its 600/600 exact-order gate still applies); the row form differs
    /// only in loading its words from the row and excluding itself.
    private static func hammingCandidates(
        queryWords: [UInt64],
        in vectors: SemanticCorpusVectors,
        limit: Int,
        excludingRow: Int?,
        isEligible: ((Int) -> Bool)?
    ) -> [Int] {
        guard limit > 0 else { return [] }
        let quads = vectors.bytesPerRow / 8
        guard quads > 0, queryWords.count == quads else { return [] }
        let dims = vectors.dims

        return vectors.withSignBits { base, count in
            let query = queryWords

            // `dims + 1` marks a row that is not a candidate at all — the anchor, or one the filter
            // rejected — so the placement pass needs no second predicate.
            let excluded = UInt16(dims + 1)
            var distances = [UInt16](repeating: excluded, count: count)
            var histogram = [Int](repeating: 0, count: dims + 2)
            distances.withUnsafeMutableBufferPointer { distanceBuffer in
                for row in 0..<count {
                    if row == excludingRow { continue }
                    if let isEligible, !isEligible(row) { continue }
                    let rowBase = row * vectors.bytesPerRow
                    var distance = 0
                    for q in 0..<quads {
                        let word = base.loadUnaligned(
                            fromByteOffset: rowBase + q * 8, as: UInt64.self)
                        distance += (query[q] ^ word).nonzeroBitCount
                    }
                    distanceBuffer[row] = UInt16(distance)
                    histogram[distance] += 1
                }
            }

            // Per-distance output offsets, capped so the buckets together hold exactly `limit`.
            var offsets = [Int](repeating: 0, count: dims + 2)
            var capacities = [Int](repeating: 0, count: dims + 2)
            var placed = 0
            for distance in 0...dims {
                let take = min(histogram[distance], limit - placed)
                offsets[distance] = placed
                capacities[distance] = take
                placed += take
                if placed >= limit { break }
            }
            guard placed > 0 else { return [] }

            var candidates = [Int](repeating: 0, count: placed)
            var written = [Int](repeating: 0, count: dims + 2)
            for row in 0..<count {
                let distance = Int(distances[row])
                if distance > dims { continue }
                guard written[distance] < capacities[distance] else { continue }
                candidates[offsets[distance] + written[distance]] = row
                written[distance] += 1
            }
            return candidates
        }
    }

    /// Exact int8 cosine between two vectors.
    ///
    /// Vectors are L2-normalised before quantization, so `dot × scaleA × scaleB` reconstructs cosine
    /// — measured at four-decimal agreement with float-768 in the corpus gates.
    ///
    /// - Parameters:
    ///   - lhs: One vector's codes and scale.
    ///   - rhs: The other's.
    /// - Returns: The approximate cosine.
    public static func cosine(
        _ lhs: (codes: [Int8], scale: Float), _ rhs: (codes: [Int8], scale: Float)
    ) -> Double {
        let width = min(lhs.codes.count, rhs.codes.count)
        var dot = 0
        for index in 0..<width { dot += Int(lhs.codes[index]) * Int(rhs.codes[index]) }
        return Double(dot) * Double(lhs.scale) * Double(rhs.scale)
    }

    /// Reranks candidate rows by exact int8 cosine and returns the best `limit`.
    ///
    /// The tie-break is score descending then row ascending, matching the reference's
    /// `lexsort((row, -score))`. `score` returns `nil` for a row whose shard this device does not
    /// hold; such rows are **dropped rather than scored as zero**, because a missing shard is an
    /// absence of evidence and a zero is a claim of dissimilarity — one ranks the document last, the
    /// other says it is unlike the anchor.
    ///
    /// Scoring is a closure over a row rather than a vector-fetching closure so the caller can score
    /// straight out of a mapped shard. Measured over 600 corpus queries, materialising a `[Int8]` per
    /// candidate cost **5.59 ms** per query against **4.78 ms** scoring in place — an allocator cost,
    /// not a retrieval one. `SemanticShard.cosine(row:query:queryScale:)` is that in-place path. (The
    /// larger win was elsewhere: see `SemanticVectorIndex.volumeSlot(containing:)`, which took the
    /// same query from 4.78 ms to **2.44 ms**.)
    ///
    /// - Parameters:
    ///   - candidates: Rows from `hammingCandidates(queryRow:in:limit:isEligible:)`.
    ///   - limit: How many neighbours to return.
    ///   - score: Approximate cosine for a row, or `nil` when this device cannot score it.
    /// - Returns: Neighbours, best first.
    public static func rerank(
        candidates: [Int],
        limit: Int,
        score: (Int) -> Double?
    ) -> [Neighbour] {
        var scored: [Neighbour] = []
        scored.reserveCapacity(candidates.count)
        for row in candidates {
            guard let value = score(row) else { continue }
            scored.append(Neighbour(row: row, score: value))
        }
        scored.sort { $0.score == $1.score ? $0.row < $1.row : $0.score > $1.score }
        return Array(scored.prefix(limit))
    }

    /// Hamming distance between two rows of the bundled tier, for callers that want a coarse score
    /// where no shard exists.
    ///
    /// Expressed as a similarity in [0, 1] (`1 - distance / dims`) so it is at least the same shape
    /// as a cosine — but it is **not** a cosine, and a surface must not present the two
    /// interchangeably: raw binary recalls 0.53 of the exact top-10 where the reranked funnel
    /// recalls 0.745.
    ///
    /// - Parameters:
    ///   - lhs: One corpus row.
    ///   - rhs: The other.
    ///   - vectors: The mapped corpus tier.
    /// - Returns: The similarity, or `nil` when either row is out of range.
    public static func binarySimilarity(
        _ lhs: Int, _ rhs: Int, in vectors: SemanticCorpusVectors
    ) -> Double? {
        guard lhs >= 0, lhs < vectors.documentCount, rhs >= 0, rhs < vectors.documentCount
        else { return nil }
        let quads = vectors.bytesPerRow / 8
        return vectors.withSignBits { base, _ in
            var distance = 0
            for q in 0..<quads {
                let a = base.loadUnaligned(
                    fromByteOffset: lhs * vectors.bytesPerRow + q * 8, as: UInt64.self)
                let b = base.loadUnaligned(
                    fromByteOffset: rhs * vectors.bytesPerRow + q * 8, as: UInt64.self)
                distance += (a ^ b).nonzeroBitCount
            }
            return 1.0 - Double(distance) / Double(vectors.dims)
        }
    }
}
