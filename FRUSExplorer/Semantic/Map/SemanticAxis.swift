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
import simd

/// A direction through the embedding space, with a pole at each end.
///
/// The design's "fewer-dimensional slices": *"a semantic axis = normalised difference of two centroid
/// vectors, where the user picks the poles … project visible documents onto it (one dot product each)
/// and drive the x-axis with it while y stays date. This is honest in a way the UMAP plane is not —
/// UMAP preserves neighborhoods, not global distances."*
///
/// That last sentence is the whole reason this exists. The map's own plane is a UMAP embedding: near
/// things are near, and the distance between two far-apart regions means nothing. An axis has a
/// definition a reader can state — *toward this volume, away from that one* — and a coordinate on it
/// is a dot product, not an artifact of a layout algorithm.
///
/// ## What the poles can be, and what they cannot
///
/// The bundle carries **int8 centroids for every volume and subseries** (659 of them) and, per
/// document, only **256 sign bits**. So volume and subseries poles are exact to int8; a *cluster*
/// pole is not offerable at all, because the Tier-0 map records a cluster's centre in 2-D layout
/// coordinates and nowhere records one in the embedding space. Free-text poles would need an
/// on-device encoder, which the design puts last and calls optional. Offering a pole the data cannot
/// support would be worse than offering fewer.
///
/// Version history:
///   1.0 — V-4: initial implementation
struct SemanticAxis: Equatable, Sendable {

    /// Unit-norm direction from the negative pole toward the positive one.
    let direction: [Float]
    /// What sits at the low end.
    let negativeLabel: String
    /// What sits at the high end.
    let positiveLabel: String

    /// Builds the normalised difference of two pole vectors.
    ///
    /// - Parameters:
    ///   - negative: The low-end pole.
    ///   - negativeLabel: Its name.
    ///   - positive: The high-end pole.
    ///   - positiveLabel: Its name.
    /// - Returns: The axis, or `nil` when the poles are the same direction — a zero-length difference
    ///   has no orientation, and normalising it would produce a direction made entirely of rounding.
    static func between(
        negative: [Float], negativeLabel: String,
        positive: [Float], positiveLabel: String
    ) -> SemanticAxis? {
        guard negative.count == positive.count, !negative.isEmpty else { return nil }
        var difference = [Float](repeating: 0, count: negative.count)
        var sumOfSquares = Double(0)
        for index in 0..<negative.count {
            let value = positive[index] - negative[index]
            difference[index] = value
            sumOfSquares += Double(value) * Double(value)
        }
        // Double accumulation, matching `SemanticVectorsGenerator.truncate`: a sequential Float sum
        // over 256 squares disagrees with a pairwise one by ~1e-7 relative, which the generator's
        // parity work traced to exactly this loop.
        let norm = sumOfSquares.squareRoot()
        guard norm > 1e-6 else { return nil }
        for index in 0..<difference.count { difference[index] /= Float(norm) }
        return SemanticAxis(direction: difference,
                            negativeLabel: negativeLabel,
                            positiveLabel: positiveLabel)
    }

    /// Projects one document's **sign bits** onto the axis.
    ///
    /// The bundled per-document tier is one bit per dimension, so the document is read as a vector of
    /// ±1 and the coordinate is `Σ sign[d]·direction[d] / √dims`. The divisor is what puts the result
    /// in −1…1: a sign vector has length `√dims` and the direction is unit-norm, so this is the
    /// cosine between the sign pattern and the axis.
    ///
    /// **The bit convention is the artifact's and must not be re-derived.** Packing is MSB-first with
    /// zero packed as a SET bit (`>= 0`, matching numpy's `packbits(matrix >= 0)`); get it backwards
    /// and every coordinate is still a plausible number, just the wrong one — the same failure the
    /// generator's parity measurement exists to prevent.
    ///
    /// - Parameters:
    ///   - base: Start of the sign-bit block.
    ///   - row: The document's row.
    ///   - bytesPerRow: Bytes per document in that block.
    /// - Returns: The coordinate, in −1…1.
    func project(signBitsAt base: UnsafeRawPointer, row: Int, bytesPerRow: Int) -> Float {
        var total = Float(0)
        let rowStart = row * bytesPerRow
        for byteIndex in 0..<bytesPerRow {
            let byte = base.load(fromByteOffset: rowStart + byteIndex, as: UInt8.self)
            let dimensionBase = byteIndex * 8
            for bit in 0..<8 {
                let dimension = dimensionBase + bit
                guard dimension < direction.count else { break }
                // MSB-first: bit 0 of the byte is the most significant.
                let isSet = (byte >> (7 - UInt8(bit))) & 1 == 1
                total += isSet ? direction[dimension] : -direction[dimension]
            }
        }
        return total / Float(direction.count).squareRoot()
    }

    /// Half-extent of the slice grid.
    ///
    /// Its own constant rather than the map's `gridExtent`: a projection is bounded to −1…1 by
    /// construction, so the slice fills its grid exactly, where the map's extent is whatever the
    /// layout stage happened to quantize into.
    static let sliceExtent = 30_000

    /// Dequantizes an int8 centroid into the float vector a pole needs.
    ///
    /// - Parameters:
    ///   - codes: The stored codes.
    ///   - scale: Its per-vector scale.
    /// - Returns: The vector.
    static func dequantize(codes: [Int8], scale: Float) -> [Float] {
        codes.map { Float($0) * scale }
    }
}
