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

/// The three encoding steps between a pooled document vector and the shipped tiers, each a literal
/// mirror of the procedure the measured gates ran under (`tools/semantic-harvest/spike_gates.py`,
/// re-run at corpus scale by `tools/semantic-harvest/corpus-gates/`).
///
/// These are pinned rules, not implementation choices. Every recall number the program has —
/// int8-256 at 0.749, int8-512 at 0.864, the Hamming funnel at 0.728 rising to 0.851 at a wider
/// rerank pool — describes *these* arithmetic steps. Changing one silently re-prices the whole
/// artifact, which is why each carries the numpy expression it reproduces.
public enum SemanticQuantization {

    /// Matryoshka truncation: keep the first `dims` components, then L2-renormalise.
    ///
    /// Mirrors `spike_gates.truncate`: `cut / norm(cut)`. The components are held in `Float`,
    /// because that is the width the numpy pipeline held after `float_full` was cast down, but the
    /// **norm is accumulated in `Double`** — see below. The cut is the entire measured cost of the
    /// shipping configuration — 768 → 256 loses ~25% of the exact top-10 — so it is applied once,
    /// here, and the width is recorded in every artifact header.
    ///
    /// The summation width is the one place this code knowingly differs from a naive reading of the
    /// reference, and it is worth the sentence because it was measured. `np.linalg.norm` sums
    /// **pairwise**; a sequential `Float` loop does not, and over 256 squares the two disagree by
    /// ~1e-7 relative. That is far below the int8 step (1/127), but it re-rounds the occasional
    /// component by one and is the sole source of this packer's divergence from the reference
    /// matrices — measured corpus-wide, a sequential `Float` norm differed on 54 of 80,507,648
    /// components, a `Double` accumulation on 11. Neither moves a neighbour list; `Double` is used
    /// because it is closer to the correctly-rounded norm that numpy's pairwise sum approximates,
    /// and because every other accumulation in this file is already `Double` for the same reason.
    ///
    /// - Parameters:
    ///   - vector: A pooled unit-norm vector at native width.
    ///   - dims: Target width; must not exceed the vector's width.
    /// - Returns: The renormalised truncation, or `nil` when the truncated prefix has no length.
    public static func truncate(_ vector: [Double], to dims: Int) -> [Float]? {
        precondition(dims <= vector.count, "cannot truncate \(vector.count) dims to \(dims)")
        var cut = [Float](repeating: 0, count: dims)
        for index in 0..<dims { cut[index] = Float(vector[index]) }
        var norm = 0.0
        for value in cut { norm += Double(value) * Double(value) }
        let scale = Float(norm.squareRoot())
        guard scale > 0 else { return nil }
        for index in 0..<dims { cut[index] /= scale }
        return cut
    }

    /// Per-vector symmetric int8 quantization.
    ///
    /// Mirrors `spike_gates.int8_quantize`: `scale = max|x| / 127`, then
    /// `clip(rint(x / scale), -127, 127)`. Two details are exact rather than approximate:
    ///
    /// * **Rounding is half-to-even** (`.toNearestOrEven`), because numpy's `rint` is, and Swift's
    ///   bare `rounded()` is half-away-from-zero. On a 256-dim corpus the two disagree on a small
    ///   but nonzero number of components, and every one of those is a vector that scores
    ///   differently from the one the gates measured.
    /// * **The clip is kept** even though `max|x| / 127` makes overflow unreachable by
    ///   construction, so the code states the invariant the measured procedure stated.
    ///
    /// Because vectors are L2-normalised before quantization,
    /// `dot(int8a, int8b) × scaleA × scaleB ≈ cosine`, which is what makes the int8 tier an exact
    /// enough cosine to rank with (measured: int8 storage costs recall in the fourth decimal).
    ///
    /// - Parameter vector: A unit-norm vector at the shipping width.
    /// - Returns: The int8 codes and the scale that reconstitutes them, or `nil` for an all-zero
    ///   vector (whose scale would be zero and whose reconstruction would divide by it).
    public static func quantizeInt8(_ vector: [Float]) -> (codes: [Int8], scale: Float)? {
        var peak: Float = 0
        for value in vector { peak = max(peak, abs(value)) }
        guard peak > 0 else { return nil }
        let scale = peak / 127.0
        var codes = [Int8](repeating: 0, count: vector.count)
        for index in 0..<vector.count {
            let scaled = (vector[index] / scale).rounded(.toNearestOrEven)
            codes[index] = Int8(min(127, max(-127, scaled)))
        }
        return (codes, scale)
    }

    /// Binary (sign-bit) packing for the Tier-1 Hamming tier.
    ///
    /// Mirrors `spike_gates.pack_bits` — `np.packbits(matrix >= 0, axis=1)` — which means two
    /// conventions that a hand-rolled version gets wrong in opposite directions and that no test
    /// catches unless it is written against these words: **zero packs as a set bit** (`>=`, not
    /// `>`), and bits fill **most-significant first** within each byte. Get either backwards and
    /// the Hamming distances are still plausible numbers, just not the ones that recall 0.728.
    ///
    /// - Parameter vector: A vector at the shipping width; the width must be a multiple of 8.
    /// - Returns: `width / 8` bytes of sign bits.
    public static func packSignBits(_ vector: [Float]) -> [UInt8] {
        precondition(vector.count % 8 == 0, "sign packing needs a byte-aligned width")
        var packed = [UInt8](repeating: 0, count: vector.count / 8)
        for index in 0..<vector.count where vector[index] >= 0 {
            packed[index / 8] |= UInt8(0x80) >> UInt8(index % 8)
        }
        return packed
    }

    /// The L2-normalised mean of a set of vectors — the centroid definition behind the volume and
    /// subseries rows the bundled tier carries.
    ///
    /// Accumulated in `Double` regardless of the input width, because a 5,000-document volume's
    /// centroid summed in `Float` loses the low bits of every late addend.
    ///
    /// - Parameters:
    ///   - vectors: The member vectors, all of the same width.
    ///   - dims: Their width.
    /// - Returns: The unit-norm centroid, or `nil` for an empty set or one that cancels to zero.
    public static func centroid(of vectors: [[Float]], dims: Int) -> [Float]? {
        guard !vectors.isEmpty else { return nil }
        var accumulator = [Double](repeating: 0, count: dims)
        for vector in vectors {
            for index in 0..<dims { accumulator[index] += Double(vector[index]) }
        }
        var norm = 0.0
        for index in 0..<dims {
            accumulator[index] /= Double(vectors.count)
            norm += accumulator[index] * accumulator[index]
        }
        norm = norm.squareRoot()
        guard norm > 0 else { return nil }
        var unit = [Float](repeating: 0, count: dims)
        for index in 0..<dims { unit[index] = Float(accumulator[index] / norm) }
        return unit
    }
}
