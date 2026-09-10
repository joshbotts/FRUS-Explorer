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

// MARK: - SemanticMultiProbeScan

/// One Hamming pass over the corpus sign bits scored against **many** query rows at once
/// (plan of record S-2, re-scoped).
///
/// ## Why this exists
/// `SemanticSimilarityGenerator.offIndexSection` answers, for ONE anchor, *what does the semantic
/// axis see beyond the volumes you hold?* — and `ProjectLeadsService` switches it off, because its
/// loop runs up to `seedCap` = 40 times and each call is a full corpus pass. So a project, which is
/// exactly the scope where "what am I missing?" is worth asking, is the one scope that cannot ask.
///
/// **Measured on the shipped 20 MB block, 314,571 rows at the 512 width, 40 probes, a 10% library:**
///
/// | | |
/// |---|---|
/// | 40 seeds × the S-3 scan pair | **52.07 ms** |
/// | this fused pass | **13.09 ms** |
/// | stream-only floor | 0.68 ms |
///
/// A **4.0× saving**, and the floor says why it is available: at 5% of the time the pass is nowhere
/// near bandwidth-bound, so amortising the row load over 40 probes buys almost the whole difference.
/// Two shapes were measured and rejected before this one — writing the inner loop the way
/// `SemanticRetrievalKernel` writes it (re-loading the row words inside the probe loop) and keeping
/// a per-probe distance array — and both are *slower per probe* than 40 separate scans, the second
/// because 40 × 629 KB of output destroys the locality the single-probe loop enjoys.
///
/// ## What it deliberately does not do
/// **No centroid.** Every probe keeps its own row, its own cut and its own attribution; nothing is
/// averaged at any point. That is not a preference, it is the row's binding constraint: driven over
/// the shipped artifacts, `cos(centroid, d)` reproduces the per-seed cosine sum's full 314,483-row
/// ordering to 2.1e-14, and where it differs it is *worse* — on a real 3-seed project the centroid's
/// top-10 held 0 of the 3 seeds' own best neighbours, and the funnel's recall of the exact top-10
/// falls 10.00 → 6.33 between k=1 and k=40. A design that cannot represent a centroid cannot
/// regress into one.
///
/// **No document tier, and no `SemanticCorpusVectors` mutation.** The finding is group-grain: how
/// many rows in each group cleared their probe's own bar, and which probes reached it. A document
/// in a volume the device does not hold has no `document_cache` row and so cannot be named or
/// scored here; `SemanticSimilarityGenerator` owns that question, with the shard in hand.
///
/// ## Why not in `SemanticRetrievalKernel`
/// That file's tie-breaks ARE the artifact's stated recall — driving it over the shipped artifacts
/// reproduces the corpus gates' reference neighbour lists in exact order for 600/600 queries, and
/// its two entry points are pinned against each other. This pass answers a different question
/// (a count per group, not a ranked candidate list), so it earns its own file rather than a third
/// entry point in the one that must not move.
///
/// Version history:
///   1.0 — 2026-09-10: S-2, the project reach scan
public enum SemanticMultiProbeScan {

    /// The most probes one pass accepts — the width of `Group.probeMask`.
    ///
    /// `ProjectLeadsService.seedCap` is 40, so this is headroom rather than a live bound; a caller
    /// passing more gets a refusal rather than a silently truncated mask.
    public static let maxProbes = 64

    // MARK: - Result

    /// What one pass found.
    public struct Reach: Sendable, Equatable {

        /// One group's finding — a volume, where the caller partitions by volume.
        public struct Group: Sendable, Equatable {
            /// Index into the `groupStarts` the caller passed.
            public let slot: Int
            /// Rows in this group that cleared their nearest probe's own cut.
            public let documentCount: Int
            /// Bit *p* set when probe *p* admitted at least one row here.
            public let probeMask: UInt64
            /// The best (most negative) margin any admitted row reached, in Hamming bits.
            public let bestMargin: Int

            /// How many distinct probes reached this group.
            ///
            /// **This is the only quantity in the pass that is commensurable across probes**, and
            /// it is what a caller should rank by. Each probe contributes at most 1 to it however
            /// loose its cut or however large the group, where `documentCount` is bounded only by
            /// the group's size: a probe sitting in a sparse neighbourhood has a loose cut and can
            /// admit hundreds of rows, outvoting thirty-nine better-covered probes, and a
            /// 1,915-document volume beats a 480-document one on size alone.
            public var reachingProbes: Int { probeMask.nonzeroBitCount }

            /// Creates a group finding.
            public init(slot: Int, documentCount: Int, probeMask: UInt64, bestMargin: Int) {
                self.slot = slot
                self.documentCount = documentCount
                self.probeMask = probeMask
                self.bestMargin = bestMargin
            }
        }

        /// Groups with at least one admitted row, in `slot` order.
        public let groups: [Group]
        /// Rows admitted across every group.
        public let admittedRows: Int
        /// Each probe's cut, in the order the probes were passed — the Hamming distance of its own
        /// `cutRank`-th nearest HELD row — or, where the reader holds fewer than `cutRank`
        /// rows, that probe's farthest held row, matching S-3's short-list rule. `-1` where
        /// a probe had no held rows at all, which admits nothing.
        public let probeCuts: [Int]

        /// An empty finding.
        public static let none = Reach(groups: [], admittedRows: 0, probeCuts: [])

        /// Creates a reach finding.
        public init(groups: [Group], admittedRows: Int, probeCuts: [Int]) {
            self.groups = groups
            self.admittedRows = admittedRows
            self.probeCuts = probeCuts
        }
    }

    // MARK: - The pass

    /// Scores every corpus row against every probe in one pass, and reports what clears each
    /// probe's own bar in the rows the reader does **not** hold.
    ///
    /// ## The cut is each probe's own, and that is load-bearing
    /// "Strong" is not a constant. S-3 measured the Hamming distance of an anchor's 120th on-index
    /// neighbour ranging **104–162** across 60 anchors, while a random corpus pair sits at a median
    /// of 194 with a minimum of 105 — the bands overlap, so any fixed cutoff admits nothing for some
    /// probes and a swathe for others. So pass A derives each probe's cut from the rows the reader
    /// already holds, and pass B admits an unheld row only when it beats the cut of the probe that
    /// claims it. The claim the caller may then make is comparative — *as close as the ones you
    /// already have* — never absolute.
    ///
    /// - Parameters:
    ///   - probeRows: One corpus row per probe. At most ``maxProbes``; a caller with more must
    ///     narrow first (the choice of which seeds to drop is the caller's, not this pass's).
    ///   - vectors: The mapped corpus tier.
    ///   - held: One byte per corpus row, `1` where the reader holds the row's volume. Passed as an
    ///     array rather than a closure because a non-inlinable call per row per probe is real money
    ///     in this loop, and because the caller already builds exactly this array.
    ///   - cutRank: Which held neighbour's distance becomes a probe's cut (S-3 uses the axis's own
    ///     candidate limit, 120 in the shipped engine).
    ///   - groupStarts: Ascending row offsets partitioning `0..<documentCount`. The pass stays
    ///     ignorant of volumes: this is a contiguous integer partition and nothing more.
    ///   - isCancelled: Polled every `cancellationCheckRows` rows so a superseded recompute stops
    ///     inside the pass rather than after it. A pass that returns early returns ``Reach/none``.
    /// - Returns: The finding, or ``Reach/none`` on a malformed request or a cancellation.
    public static func reach(
        probeRows: [Int],
        in vectors: SemanticCorpusVectors,
        held: [UInt8],
        cutRank: Int,
        groupStarts: [Int],
        isCancelled: () -> Bool = { false }
    ) -> Reach {
        let probeCount = probeRows.count
        let docs = vectors.documentCount
        let quads = vectors.bytesPerRow / 8
        guard probeCount > 0, probeCount <= maxProbes,
              quads > 0, docs > 0, held.count == docs, cutRank > 0,
              !groupStarts.isEmpty, groupStarts[0] == 0,
              probeRows.allSatisfy({ $0 >= 0 && $0 < docs })
        else { return .none }

        let dims = vectors.dims
        let bytesPerRow = vectors.bytesPerRow

        return vectors.withSignBits { base, _ -> Reach in
            // The probe rows, pulled out once and laid out contiguously so the inner loop walks
            // them with a single stride.
            var probeWords = [UInt64](repeating: 0, count: probeCount * quads)
            for p in 0..<probeCount {
                for q in 0..<quads {
                    probeWords[p * quads + q] = base.loadUnaligned(
                        fromByteOffset: probeRows[p] * bytesPerRow + q * 8, as: UInt64.self)
                }
            }

            // ── Pass A: each probe's cut, from the rows the reader holds ──────────────────────
            // A cumulative histogram over held rows returns exactly what S-3's
            // `onIndexRows.prefix(limit).last` returns — the distance of the cutRank-th nearest
            // held neighbour — without materialising or sorting a candidate list.
            var cuts = [Int](repeating: dims + 1, count: probeCount)
            probeWords.withUnsafeBufferPointer { pw in
                let pb = pw.baseAddress!
                var histograms = [Int32](repeating: 0, count: probeCount * (dims + 2))
                histograms.withUnsafeMutableBufferPointer { hb in
                    let hp = hb.baseAddress!
                    for row in 0..<docs where held[row] == 1 {
                        let rowBase = row * bytesPerRow
                        for p in 0..<probeCount {
                            // A probe never ranks itself, matching
                            // `hammingCandidates(queryRow:)`'s `excludingRow` — counting it would
                            // put a distance of 0 in every probe's histogram and pull every cut in
                            // by one rank.
                            if probeRows[p] == row { continue }
                            let b = pb + p * quads
                            var d = 0
                            for q in 0..<quads {
                                d &+= (b[q] ^ base.loadUnaligned(
                                    fromByteOffset: rowBase + q * 8, as: UInt64.self)).nonzeroBitCount
                            }
                            hp[p * (dims + 2) + d] &+= 1
                        }
                    }
                    for p in 0..<probeCount {
                        var seen: Int32 = 0
                        var farthest = -1
                        var reached = false
                        for d in 0...dims {
                            let n = hp[p * (dims + 2) + d]
                            if n > 0 { farthest = d }
                            seen &+= n
                            if !reached, seen >= Int32(cutRank) { cuts[p] = d; reached = true }
                        }
                        // Two tails, and S-3 answers both differently from "no cut at all".
                        //
                        // FEWER held rows than `cutRank`: `offIndexLeads` takes
                        // `onIndexRows.prefix(limit).last`, which for a short list is its LAST
                        // entry — the farthest held neighbour — and says so ("a short list means
                        // the reader holds little; its own last entry is still the right cut,
                        // because the claim is comparative and not absolute"). Leaving the cut at
                        // `dims + 1` here would admit the entire corpus for exactly the reader who
                        // holds least.
                        //
                        // NO held rows at all: that guard fails outright in S-3 and the anchor
                        // yields `.none`. A cut of -1 is unreachable (`d >= 0`), so the probe
                        // admits nothing rather than everything.
                        if !reached { cuts[p] = farthest }
                    }
                }
            }
            if isCancelled() { return .none }

            // ── Pass B: what the reader does NOT hold, against those cuts ────────────────────
            // The row words are hoisted out of the probe loop — the single change that makes the
            // fusion worth doing. Written the shipped kernel's way (re-loading inside the probe
            // loop) the same pass measured 40.0 ms against 14.2 ms for this shape.
            var groupCounts = [Int](repeating: 0, count: groupStarts.count)
            var groupMasks = [UInt64](repeating: 0, count: groupStarts.count)
            var groupBest = [Int](repeating: Int.max, count: groupStarts.count)
            var admitted = 0
            var cancelled = false

            probeWords.withUnsafeBufferPointer { pw in
                cuts.withUnsafeBufferPointer { cb in
                    let pb = pw.baseAddress!
                    var slot = 0
                    for row in 0..<docs {
                        if row & (cancellationCheckRows - 1) == 0, isCancelled() {
                            cancelled = true
                            break
                        }
                        while slot + 1 < groupStarts.count && row >= groupStarts[slot + 1] {
                            slot += 1
                        }
                        if held[row] == 1 { continue }
                        let rowBase = row * bytesPerRow
                        var bestMargin = Int.max
                        var bestProbe = -1
                        for p in 0..<probeCount {
                            let b = pb + p * quads
                            var d = 0
                            for q in 0..<quads {
                                d &+= (b[q] ^ base.loadUnaligned(
                                    fromByteOffset: rowBase + q * 8, as: UInt64.self)).nonzeroBitCount
                            }
                            let margin = d &- cb[p]
                            if margin < bestMargin { bestMargin = margin; bestProbe = p }
                        }
                        // Admitted when the row is at least as close to its nearest probe as that
                        // probe's own cutRank-th held neighbour — S-3's `similarity >= cut`, in
                        // distance terms.
                        guard bestMargin <= 0, bestProbe >= 0 else { continue }
                        groupCounts[slot] += 1
                        groupMasks[slot] |= (UInt64(1) << UInt64(bestProbe))
                        groupBest[slot] = min(groupBest[slot], bestMargin)
                        admitted += 1
                    }
                }
            }
            if cancelled { return .none }

            var groups: [Reach.Group] = []
            groups.reserveCapacity(16)
            for slot in 0..<groupStarts.count where groupCounts[slot] > 0 {
                groups.append(Reach.Group(slot: slot,
                                          documentCount: groupCounts[slot],
                                          probeMask: groupMasks[slot],
                                          bestMargin: groupBest[slot]))
            }
            return Reach(groups: groups, admittedRows: admitted, probeCuts: cuts)
        }
    }

    /// How often pass B polls for cancellation — a power of two, so the check is a mask rather
    /// than a division in the hot loop.
    ///
    /// At the measured ~13 ms for 314,571 rows a 4,096-row granularity is roughly 0.17 ms of
    /// latency on a cancel, which is well inside a frame and far cheaper than the alternative the
    /// first draft had, which was no check at all: `Task.detached` does not inherit cancellation,
    /// so a reader flipping between projects could otherwise stack uncancellable passes.
    static let cancellationCheckRows = 4096
}
