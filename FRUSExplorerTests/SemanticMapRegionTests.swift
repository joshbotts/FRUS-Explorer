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
import Testing
import simd
@testable import FRUSExplorer

/// Regions: what they can be carried into, and whether the era ramp can be read at all.
///
/// Version history:
///   1.0 — build 42: region capture, and the era palette's contrast floor
@Suite("Map regions capture cleanly and the era ramp is legible")
struct SemanticMapRegionTests {

    // MARK: - OKLab, for measuring the palette rather than eyeballing it

    /// sRGB to OKLab, so "these two colours are too close" is a number rather than an opinion.
    ///
    /// The palette is *built* in OKLab and *measured* here by an independent inverse — a test that
    /// reused the forward transform would confirm the arithmetic round-trips and say nothing about
    /// whether the colours can be told apart.
    private static func oklab(_ c: SIMD4<Float>) -> SIMD3<Double> {
        func linear(_ v: Float) -> Double {
            let d = Double(v)
            return d <= 0.04045 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        let r = linear(c.x), g = linear(c.y), b = linear(c.z)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return SIMD3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private static func distance(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> Double {
        simd_distance(oklab(a), oklab(b))
    }

    /// The era lens colours the reader can actually receive — one per era, not all sixteen slots.
    private static var eraStops: [SIMD4<Float>] {
        let palette = SemanticMapColouring.palette(for: .era)
        return CoverageEra.allCases.map { palette[$0.rawValue % SemanticMapColouring.paletteSize] }
    }

    /// Adjacent eras must be far enough apart to be told apart.
    ///
    /// **The floor is set from a measurement of the palette this replaced.** That ramp interpolated
    /// linearly in RGB from a blue to a khaki; the straight line between them passes near the grey
    /// axis, so the two interior eras landed on `#6e90c8` and `#9daeb7` — a pair of near-identical
    /// greys, minimum adjacent ΔE **0.108**. The OKLCh ramp measures **0.228** on the same metric.
    /// A floor of 0.18 fails the old palette and passes the new one with room, so this test is about
    /// the property the reader complained about rather than about the specific colours chosen.
    @Test("Adjacent eras are perceptually distinct")
    func eraStopsAreDistinguishable() {
        let stops = Self.eraStops
        #expect(stops.count >= 2)
        var worst = Double.greatestFiniteMagnitude
        var worstPair = ""
        for index in 0..<(stops.count - 1) {
            let delta = Self.distance(stops[index], stops[index + 1])
            if delta < worst {
                worst = delta
                worstPair = "\(CoverageEra.allCases[index].label) → \(CoverageEra.allCases[index + 1].label)"
            }
        }
        #expect(worst >= 0.18, """
            The closest pair of adjacent eras (\(worstPair)) differs by only \(worst) in OKLab, \
            below the 0.18 floor. The palette this replaced scored 0.108 by mixing two colours in \
            RGB across the grey axis, which desaturated its middle into two near-identical greys — \
            interpolate lightness, chroma and hue separately instead.
            """)
    }

    /// Every pair, not just neighbours: era is ordered, but a reader comparing two distant regions
    /// still has to tell those two colours apart.
    @Test("No two eras collide, adjacent or not")
    func noTwoErasCollide() {
        let stops = Self.eraStops
        for i in 0..<stops.count {
            for j in (i + 1)..<stops.count {
                #expect(Self.distance(stops[i], stops[j]) >= 0.18, """
                    \(CoverageEra.allCases[i].label) and \(CoverageEra.allCases[j].label) are too \
                    close to distinguish.
                    """)
            }
        }
    }

    /// Lightness must climb with time, or the ramp stops encoding an order.
    ///
    /// This is also what keeps the lens usable without colour: monotonic lightness means the map
    /// still reads as early-to-late in greyscale, and for a reader with red-green colour blindness
    /// the navy→teal→green→yellow path collapses onto exactly that one axis.
    @Test("Era lightness increases monotonically")
    func eraLightnessIsMonotonic() {
        let lightness = Self.eraStops.map { Self.oklab($0).x }
        for index in 0..<(lightness.count - 1) {
            #expect(lightness[index] < lightness[index + 1], """
                Era lightness does not increase from \(CoverageEra.allCases[index].label) to \
                \(CoverageEra.allCases[index + 1].label) (\(lightness[index]) → \
                \(lightness[index + 1])). An ordered variable drawn without an ordered ramp reads \
                as categorical, and the lens loses the one thing it is for.
                """)
        }
        // And the ramp should use a real span of it, not three shades of the same tone.
        let span = lightness.last! - lightness.first!
        #expect(span > 0.4, "the ramp spans only \(span) of lightness, too little to read as an order")
    }

    /// The palette must stay in gamut — an unclamped OKLab conversion can produce negative or >1
    /// channels, which reach the shader as wrapped or clipped colour.
    @Test("Era colours are inside the displayable range")
    func eraColoursAreInGamut() {
        for (era, colour) in zip(CoverageEra.allCases, Self.eraStops) {
            for channel in [colour.x, colour.y, colour.z, colour.w] {
                #expect(channel >= 0 && channel <= 1,
                        "\(era.label) has an out-of-range channel (\(channel))")
            }
        }
    }

    // MARK: - Capturing a region

    /// A synthetic corpus: rows 0…19, cluster = row % 4, so region 1 holds rows 1, 5, 9, 13, 17.
    private func clusterAt(_ row: Int) -> UInt16 { UInt16(row % 4) }

    @Test("A region capture takes exactly its own rows")
    func regionRowsAreItsOwn() {
        let found = SemanticMapPicking.rows(
            inCluster: 1, count: 20, clusterAt: clusterAt, limit: 100)
        #expect(found.rows == [1, 5, 9, 13, 17])
        #expect(found.total == 5)
    }

    /// The cap and the total must disagree when the region is bigger than the cap — that difference
    /// is the entire content of the truncation note, and `WorkingCorpus` stores both.
    @Test("A capped capture still counts what it is a fraction of")
    func capDoesNotTruncateTheTotal() {
        let found = SemanticMapPicking.rows(
            inCluster: 1, count: 20, clusterAt: clusterAt, limit: 2)
        #expect(found.rows == [1, 5], "the cap should keep the first rows, in order")
        #expect(found.total == 5, """
            The total stopped counting when the cap filled. A truncation note compares the two, so a \
            denominator that stops at the numerator reports a cap that never applied.
            """)
    }

    /// A scoped map draws part of a region greyed out, and the capture must be the set on screen.
    @Test("A scope gates the capture and its total together")
    func scopeGatesBothNumbers() {
        // 0 means in scope, matching ScopeMask's flags.
        var mask = [UInt8](repeating: 1, count: 20)
        for row in [1, 5] { mask[row] = 0 }
        let found = SemanticMapPicking.rows(
            inCluster: 1, count: 20, clusterAt: clusterAt, limit: 100, scopeMask: mask)
        #expect(found.rows == [1, 5])
        #expect(found.total == 2, """
            The total counted rows the scope excludes. Scoped, the reader would be told the region \
            holds five documents and handed a corpus of two, and the difference would be reported \
            as a cap.
            """)
    }

    /// A stale mask is ignored rather than applied to the wrong rows — same rule as the lasso.
    @Test("A mask of the wrong length is ignored, not misapplied")
    func staleMaskIsIgnored() {
        let found = SemanticMapPicking.rows(
            inCluster: 1, count: 20, clusterAt: clusterAt, limit: 100,
            scopeMask: [UInt8](repeating: 0, count: 7))
        #expect(found.total == 5, "a stale mask should behave as no mask")
    }

    /// The unclustered sentinel is not a region and must never be capturable — 28% of the corpus
    /// sits there, and saving it as "a region" would be saving the leftovers.
    @Test("The between-regions sentinel captures nothing")
    func unclusteredIsNotARegion() {
        let found = SemanticMapPicking.rows(
            inCluster: SemanticMapArtifacts.unclustered, count: 20,
            clusterAt: { _ in SemanticMapArtifacts.unclustered }, limit: 100)
        #expect(found.rows.isEmpty && found.total == 0)
    }
}
