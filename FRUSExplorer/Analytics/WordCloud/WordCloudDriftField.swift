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

import CoreGraphics
import Foundation

/// The word cloud's motion model: words as particles suspended in a shallow 3-D field.
///
/// ## Pure, and separate from the renderer on purpose
/// Nothing here imports SwiftUI. Every value a frame needs is a function of `(particle,
/// time, size)`, so the whole of the motion can be tested by evaluating it — no view, no
/// snapshot, no simulator. That matters more than usual because the alternative is judging
/// an animation by looking at it, and the two questions this has to answer ("does a word
/// ever leave its frame?", "is it identical across launches?") are exactly the ones the eye
/// is worst at.
///
/// ## Derived, never accumulated
/// Position is a closed-form function of absolute time, not a state that integrates each
/// frame. This is the house rule the existing cadence driver already follows, for the same
/// reason: a dropped frame must not make the field drift out of step, and two devices at
/// different refresh rates must show the same thing at the same moment. It also means
/// Reduce Motion is a single substitution — pin the clock — rather than a parallel code
/// path.
///
/// ## Depth is rank, and rank is not the array index
/// `WordCloudLayout.place` drops any word that finds no free slot on the spiral, silently
/// and without a placeholder; on an iPhone-width indexing strip that is routinely more than
/// half of them. The surviving array is therefore *compacted*, and its indices are not
/// ranks. The true rank survives in `PlacedWord.colorIndex`, assigned before the drop.
///
/// This is not pedantry: depth drives size, brightness and parallax, so reading depth off
/// the array index would make the 9th-most-common word behave like the 25th purely because
/// sixteen words above it failed to place. The shipped view already makes this mistake for
/// its stagger delay, where it is invisible.
///
/// Version history:
///   1.0 — P-1: initial implementation
struct WordCloudDriftField: Sendable {

    /// One word, with everything the renderer needs to place it at any instant.
    struct Particle: Sendable, Identifiable {

        /// The term. Not unique across lenses — see ``WordCloudDriftField/SymbolKey``.
        let term: String

        /// Where the packer put it. The drift is an excursion around this point.
        let home: CGPoint

        /// The packer's point size, before depth scaling.
        let baseFontSize: CGFloat

        /// 0 or 90 — the packer's only two orientations.
        let rotationDegrees: Double

        /// 0 = nearest the viewer, 1 = furthest. Derived from true rank.
        let depth: Double

        /// Half-extent of the word's estimated box, used to keep it inside the frame.
        let halfSize: CGSize

        /// Deterministic per-term phase offsets, so no two words move in lockstep.
        let phase: SIMD3<Double>

        var id: String { term }
    }

    /// A word's placement at one instant.
    struct State: Equatable {
        let position: CGPoint
        let scale: CGFloat
        let opacity: Double
    }

    /// Identifies a rendered symbol.
    ///
    /// A composite of lens and term, for two independent reasons. The obvious one is that
    /// `PlacedWord.id` is the bare term and terms are **not** disjoint across lenses — the
    /// corpus top-25s share seven terms between the sentiment and concepts lenses alone, so
    /// a term-keyed symbol would collide and a crossfade would draw the wrong colour.
    ///
    /// The second is a trap in `Canvas`'s symbol lookup that the documentation does not
    /// mention: a tag's **static type** is part of its identity. A view tagged `.tag(0)` as
    /// an `Int` is invisible to `resolveSymbol(id:)` called with an enum whose raw value is
    /// 0 — it returns nil, silently, and the word simply never draws. Using one concrete
    /// key type everywhere makes that unreachable.
    struct SymbolKey: Hashable, Sendable {
        let lens: WordCloudLens
        let term: String
    }

    /// The particles, ordered far-to-near so a painter's-algorithm pass is a plain loop.
    let particles: [Particle]

    /// Builds a field from a packer result.
    ///
    /// - Parameter placed: `WordCloudLayout.place` output — already descending by count,
    ///   possibly with rank gaps.
    /// - Parameter rankCeiling: the rank that maps to maximum depth. Passing the *requested*
    ///   word count rather than the placed count keeps depth meaning the same thing whether
    ///   or not words were dropped.
    init(placed: [PlacedWord], rankCeiling: Int) {
        let ceiling = Double(max(1, rankCeiling - 1))
        particles = placed.map { word in
            // colorIndex, not the array index — see the type's discussion.
            let depth = min(1, Double(word.colorIndex) / ceiling)
            let estimated = Self.estimatedHalfSize(term: word.term,
                                                   fontSize: word.fontSize,
                                                   rotated: word.rotationDegrees != 0)
            return Particle(term: word.term,
                            home: word.center,
                            baseFontSize: word.fontSize,
                            rotationDegrees: word.rotationDegrees,
                            depth: depth,
                            halfSize: estimated,
                            phase: Self.phase(for: word.term))
        }
        // Far first. Nearer, brighter, larger words are drawn last and so read as in front.
        .sorted { $0.depth > $1.depth }
    }

    /// Where a particle is, how big, and how bright, at `time`.
    ///
    /// - Parameter time: seconds since an arbitrary but fixed epoch. `0` yields the rest
    ///   pose, which is what Reduce Motion draws.
    /// - Parameter size: the canvas, used only to keep words inside it.
    static func state(of p: Particle, at time: Double, in size: CGSize) -> State {
        // Parallax: near words swing wider and faster than far ones. This is the whole of
        // the depth illusion — the eye reads differential motion as distance long before it
        // reads size.
        let nearness = 1 - p.depth
        let amplitude = Tuning.farAmplitude
            + (Tuning.nearAmplitude - Tuning.farAmplitude) * nearness
        let rate = Tuning.farRate + (Tuning.nearRate - Tuning.farRate) * nearness

        let dx = sin(time * rate + p.phase.x) * amplitude
        // Vertically shallower: a strip is much wider than it is tall, and equal excursion
        // in both axes reads as jitter rather than float.
        let dy = sin(time * rate * Tuning.verticalRateRatio + p.phase.y)
            * amplitude * Tuning.verticalAmplitudeRatio

        // Size breathes independently of position, so the two never look geared together.
        let baseScale = Tuning.farScale + (Tuning.nearScale - Tuning.farScale) * nearness
        let breath = 1 + sin(time * Tuning.breathRate + p.phase.z) * Tuning.breathDepth
        let scale = baseScale * breath

        // Nearer is brighter. Combined with scale this is the second depth cue, and the one
        // that survives when a word happens to be moving slowly.
        let opacity = Tuning.farOpacity + (Tuning.nearOpacity - Tuning.farOpacity) * nearness

        let drifted = CGPoint(x: p.home.x + dx, y: p.home.y + dy)
        return State(position: clamp(drifted, halfSize: p.halfSize, scale: scale, in: size),
                     scale: scale,
                     opacity: opacity)
    }

    /// Keeps a drifting word inside the canvas.
    ///
    /// The packer guarantees every *home* box lies inside the frame; drift and scale-up can
    /// both push it out, and neither the packer nor the exclusion zones constrain a particle
    /// once it has moved. Clamping rather than wrapping, because a word that reappears on
    /// the far side is a teleport, and the eye catches it immediately.
    ///
    /// Words wider than the canvas — routinely the case on a 96 pt indexing strip — clamp to
    /// the centre rather than inverting their bounds.
    static func clamp(_ point: CGPoint, halfSize: CGSize, scale: CGFloat, in size: CGSize) -> CGPoint {
        let halfW = halfSize.width * scale
        let halfH = halfSize.height * scale
        let minX = min(halfW, size.width / 2)
        let maxX = max(size.width - halfW, size.width / 2)
        let minY = min(halfH, size.height / 2)
        let maxY = max(size.height - halfH, size.height / 2)
        return CGPoint(x: Swift.min(Swift.max(point.x, minX), maxX),
                       y: Swift.min(Swift.max(point.y, minY), maxY))
    }

    /// The largest scale any particle can reach.
    ///
    /// The renderer resolves each symbol at `baseFontSize × this` and only ever scales
    /// *down* from there. `ResolvedSymbol` is resolution-independent, so scaling up would
    /// not blur — but its *layout metrics* are frozen at resolve time, so a symbol resolved
    /// small and blown up is measurably wider than the same text set large. Resolving at the
    /// ceiling keeps the metrics honest at every size.
    static var maximumScale: CGFloat {
        Tuning.nearScale * (1 + Tuning.breathDepth)
    }

    // MARK: - Determinism

    /// Per-term phase offsets in [0, 2π).
    ///
    /// From a fixed FNV-1a hash of the term, **not** `String.hashValue` — Swift seeds that
    /// per process, so the cloud would drift differently on every launch. The packer is
    /// deterministic by design and the drift has to match it: the same volume set at the
    /// same size must animate identically today and next week, or the "same scope, same
    /// picture" property the layout cache rests on quietly stops being true.
    static func phase(for term: String) -> SIMD3<Double> {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in term.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let a = Double(hash & 0xFFFF) / Double(0xFFFF)
        let b = Double((hash >> 16) & 0xFFFF) / Double(0xFFFF)
        let c = Double((hash >> 32) & 0xFFFF) / Double(0xFFFF)
        let twoPi = Double.pi * 2
        return SIMD3(a * twoPi, b * twoPi, c * twoPi)
    }

    /// Mirrors `WordCloudLayout`'s glyph-extent heuristic, halved.
    ///
    /// The packer never measures text — it estimates from average advance width — so the
    /// clamp has to use the same estimate or a word could be held inside a box that does not
    /// describe it. Duplicated deliberately rather than exposed from the packer, whose
    /// placements are pinned exactly by `WordCloudLayoutRegressionTests`; widening its API
    /// for a consumer is how that pin gets loosened.
    static func estimatedHalfSize(term: String, fontSize: CGFloat, rotated: Bool) -> CGSize {
        let width = CGFloat(term.count) * fontSize * 0.54 + fontSize * 0.4
        let height = fontSize * 1.25
        return rotated ? CGSize(width: height / 2, height: width / 2)
                       : CGSize(width: width / 2, height: height / 2)
    }

    // MARK: - Tuning

    /// The motion's constants.
    ///
    /// Values, not settings. The cadence decision (O-2-1) established that this cloud's
    /// timing is a design constant with no user control, and drift inherits that.
    enum Tuning {
        /// Points of horizontal excursion for the nearest and furthest words.
        static let nearAmplitude: CGFloat = 14
        static let farAmplitude: CGFloat = 4
        /// Radians per second. Slow: this is a backdrop for a wait, not a screensaver.
        static let nearRate: Double = 0.34
        static let farRate: Double = 0.19
        /// Vertical motion is shallower and slightly out of step with horizontal, so the
        /// path is a soft Lissajous rather than a diagonal line.
        static let verticalAmplitudeRatio: CGFloat = 0.42
        static let verticalRateRatio: Double = 0.73
        /// Depth scaling. The near end exceeds 1 so the packer's size stays mid-field.
        static let nearScale: CGFloat = 1.12
        static let farScale: CGFloat = 0.78
        /// Slow size pulse, independent of position.
        static let breathRate: Double = 0.21
        static let breathDepth: Double = 0.05
        /// Depth dimming, before the surface's own `dim` multiplier.
        static let nearOpacity: Double = 1.0
        static let farOpacity: Double = 0.55
    }
}
