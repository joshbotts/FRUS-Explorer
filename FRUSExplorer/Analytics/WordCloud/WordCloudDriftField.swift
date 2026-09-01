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
///   1.1 — phase-corrected rest pose (t = 0 is now exactly the packed layout, which is what
///         Reduce Motion shows) and drift-time exclusion-zone avoidance
///   1.2 — the field expands to fill its host frame, so a large window shows a cloud you are
///         inside rather than a clump stranded in an empty expanse
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

    /// Per-axis multiplier applied to each word's offset from the centre.
    ///
    /// **This is what makes the cloud fill its frame.** `WordCloudLayout.place` marches an
    /// Archimedean spiral outward from the centre and takes the first free slot, and the
    /// spiral's reach is a function of the words' own point sizes — `max(height, minFont) *
    /// 0.22` per radian — not of the canvas. Twenty-five words therefore settle into a tight
    /// clump a few hundred points across whether the frame is a 96 pt strip or a 1200 pt
    /// window, which on a large surface reads as a small cloud stranded in an empty expanse
    /// rather than as a field you are inside.
    ///
    /// Expanding here rather than in the packer is deliberate: `place` is shared with the
    /// shipped analytics Word Cloud and its placements are pinned *exactly* by
    /// `WordCloudLayoutRegressionTests`. Scaling every word's displacement from the centre by
    /// a constant cannot introduce an overlap — all gaps grow — so the packer's composition
    /// and its non-overlap guarantee both survive untouched.
    let expansion: CGSize

    /// How far outside the frame a word may hang, as a fraction of its own half-extent.
    ///
    /// Zero on a small host, where a clipped word reads as a rendering fault. Non-zero on a
    /// full-bleed surface, where it is the point: a field whose every member is fully
    /// contained reads as a picture *of* a cloud, and one whose outermost members run off the
    /// edges reads as a cloud you are *in*. That difference is most of the sensation being
    /// asked for, and it costs nothing.
    let bleed: CGFloat

    /// Rects the words must stay clear of, in canvas coordinates.
    ///
    /// **The packer alone is not enough once words move.** `WordCloudLayout.place` honours
    /// zones as a placement rejection and nothing consults them afterwards, so a particle
    /// that drifts 14 pt sideways can settle straight over the dock or identity block the
    /// zone existed to protect. Latent rather than live today — the one drifting surface
    /// passes no zones — but it lights up the moment any full-bleed surface drifts, which is
    /// exactly what a search or splash backdrop would be.
    let exclusionZones: [CGRect]

    /// Builds a field from a packer result.
    ///
    /// - Parameter placed: `WordCloudLayout.place` output — already descending by count,
    ///   possibly with rank gaps.
    /// - Parameter rankCeiling: the rank that maps to maximum depth. Passing the *requested*
    ///   word count rather than the placed count keeps depth meaning the same thing whether
    ///   or not words were dropped.
    /// - Parameter canvas: the frame the words will be drawn in. Together with `fill` this
    ///   decides how far the packed composition is spread to occupy it.
    /// - Parameter fill: the fraction of each half-axis the outermost word should reach.
    ///   `1` puts the outermost box exactly against the edge; above `1` lets the field bleed
    ///   off-frame, which is the strongest cue for being *inside* a cloud rather than looking
    ///   at one. `0` disables expansion entirely, for hosts too small to spread into.
    init(placed: [PlacedWord], rankCeiling: Int, exclusionZones: [CGRect] = [],
         canvas: CGSize = .zero, fill: CGFloat = 0) {
        self.exclusionZones = exclusionZones
        let expansion = Self.expansion(for: placed, canvas: canvas, fill: fill)
        self.expansion = expansion
        self.bleed = max(0, fill - 1)
        let ceiling = Double(max(1, rankCeiling - 1))
        particles = placed.map { word in
            // colorIndex, not the array index — see the type's discussion.
            let depth = min(1, Double(word.colorIndex) / ceiling)
            let estimated = Self.estimatedHalfSize(term: word.term,
                                                   fontSize: word.fontSize,
                                                   rotated: word.rotationDegrees != 0)
            return Particle(term: word.term,
                            home: Self.expand(word.center, canvas: canvas, by: expansion),
                            baseFontSize: word.fontSize,
                            rotationDegrees: word.rotationDegrees,
                            depth: depth,
                            halfSize: estimated,
                            phase: Self.phase(for: word.term))
        }
        // Far first. Nearer, brighter, larger words are drawn last and so read as in front.
        .sorted { $0.depth > $1.depth }
    }

    /// The per-axis multiplier that spreads a packed field across its canvas.
    ///
    /// Computed per axis, not uniformly. A uniform factor preserves the composition's aspect
    /// ratio but leaves a wide-and-short field floating in a tall frame with bands of nothing
    /// above and below it — the exact complaint this exists to answer. Positions stretch;
    /// glyphs do not, so nothing is distorted, only redistributed.
    ///
    /// The axes are kept within `maximumAxisSkew` of each other so an extreme frame cannot
    /// smear the composition into a line.
    static func expansion(for placed: [PlacedWord], canvas: CGSize, fill: CGFloat) -> CGSize {
        guard fill > 0, canvas.width > 0, canvas.height > 0, !placed.isEmpty else {
            return CGSize(width: 1, height: 1)
        }
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        var reachX: CGFloat = 0
        var reachY: CGFloat = 0
        for word in placed {
            let half = estimatedHalfSize(term: word.term, fontSize: word.fontSize,
                                         rotated: word.rotationDegrees != 0)
            reachX = max(reachX, abs(word.center.x - center.x) + half.width)
            reachY = max(reachY, abs(word.center.y - center.y) + half.height)
        }
        guard reachX > 1, reachY > 1 else { return CGSize(width: 1, height: 1) }

        // Never contract: a field already wider than its frame is the packer's business.
        var x = max(1, canvas.width / 2 * fill / reachX)
        var y = max(1, canvas.height / 2 * fill / reachY)
        let skew = Tuning.maximumAxisSkew
        x = min(x, y * skew)
        y = min(y, x * skew)
        return CGSize(width: x, height: y)
    }

    /// Applies ``expansion`` to one packed centre.
    static func expand(_ point: CGPoint, canvas: CGSize, by expansion: CGSize) -> CGPoint {
        guard canvas.width > 0, canvas.height > 0 else { return point }
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        return CGPoint(x: center.x + (point.x - center.x) * expansion.width,
                       y: center.y + (point.y - center.y) * expansion.height)
    }

    /// Where a particle is, how big, and how bright, at `time`.
    ///
    /// - Parameter time: seconds since an arbitrary but fixed epoch. `0` yields the rest
    ///   pose, which is what Reduce Motion draws.
    /// - Parameter size: the canvas, used only to keep words inside it.
    static func state(of p: Particle, at time: Double, in size: CGSize,
                      avoiding zones: [CGRect] = [], bleed: CGFloat = 0) -> State {
        // Parallax: near words swing wider and faster than far ones. This is the whole of
        // the depth illusion — the eye reads differential motion as distance long before it
        // reads size.
        let nearness = 1 - p.depth
        let amplitude = Tuning.farAmplitude
            + (Tuning.nearAmplitude - Tuning.farAmplitude) * nearness
        let rate = Tuning.farRate + (Tuning.nearRate - Tuning.farRate) * nearness

        // Phase-corrected, so t = 0 is EXACTLY the packed layout.
        //
        // `sin(0 + phase)` is not zero, so the first version's rest pose sat every word up to
        // 14 pt off its packed home. Harmless in isolation — but Reduce Motion pins the clock
        // to 0, so that displaced pose is what a Reduce Motion user sees permanently, and it
        // is a pose the packer never sanctioned: it can sit inside an exclusion zone, which
        // the packer exists to keep words out of. Subtracting the phase term costs one extra
        // `sin` per axis and makes the frozen frame the real layout.
        let dx = (sin(time * rate + p.phase.x) - sin(p.phase.x)) * amplitude
        // Vertically shallower: a strip is much wider than it is tall, and equal excursion
        // in both axes reads as jitter rather than float.
        let dy = (sin(time * rate * Tuning.verticalRateRatio + p.phase.y) - sin(p.phase.y))
            * amplitude * Tuning.verticalAmplitudeRatio

        // Size breathes independently of position, so the two never look geared together.
        let baseScale = Tuning.farScale + (Tuning.nearScale - Tuning.farScale) * nearness
        let breath = 1 + (sin(time * Tuning.breathRate + p.phase.z) - sin(p.phase.z))
            * Tuning.breathDepth
        let scale = baseScale * breath

        // Nearer is brighter. Combined with scale this is the second depth cue, and the one
        // that survives when a word happens to be moving slowly.
        let opacity = Tuning.farOpacity + (Tuning.nearOpacity - Tuning.farOpacity) * nearness

        let drifted = CGPoint(x: p.home.x + dx, y: p.home.y + dy)
        let bounded = clamp(drifted, halfSize: p.halfSize, scale: scale, in: size, bleed: bleed)
        let clear = push(bounded, halfSize: p.halfSize, scale: scale, outOf: zones, in: size,
                         bleed: bleed)
        return State(position: clear, scale: scale, opacity: opacity)
    }

    /// Pushes a word clear of any exclusion zone it has drifted into.
    ///
    /// Along the shortest axis, which keeps the correction imperceptible: the packer already
    /// placed the home outside every zone and the excursion is at most ~14 pt, so this is a
    /// nudge, not a relocation. A word that cannot escape — larger than the gap the zones
    /// leave — is left where the canvas clamp put it rather than teleported somewhere worse.
    static func push(_ point: CGPoint, halfSize: CGSize, scale: CGFloat,
                     outOf zones: [CGRect], in size: CGSize, bleed: CGFloat) -> CGPoint {
        guard !zones.isEmpty else { return point }
        var result = point
        let halfW = halfSize.width * scale
        let halfH = halfSize.height * scale
        for zone in zones {
            let box = CGRect(x: result.x - halfW, y: result.y - halfH,
                             width: halfW * 2, height: halfH * 2)
            guard box.intersects(zone) else { continue }
            let left = zone.minX - (result.x + halfW)     // negative when overlapping
            let right = zone.maxX - (result.x - halfW)
            let up = zone.minY - (result.y + halfH)
            let down = zone.maxY - (result.y - halfH)
            let moves = [left, right, up, down]
            guard let shortest = moves.min(by: { abs($0) < abs($1) }) else { continue }
            // Push a hair PAST the edge, not onto it. Landing exactly on the boundary
            // leaves a sub-nanometre overlap after rounding, which `CGRect.intersects` still
            // reports — and a word resting flush against a dock reads as a collision anyway.
            let clearance: CGFloat = Tuning.zoneClearance
            var candidate = result
            if shortest == left || shortest == right {
                candidate.x += shortest + (shortest < 0 ? -clearance : clearance)
            } else {
                candidate.y += shortest + (shortest < 0 ? -clearance : clearance)
            }
            // Only accept a push that stays on the canvas; otherwise leave it be — measured
            // against the SAME canvas `state(of:)` clamped to, bleed included.
            //
            // This test used to re-clamp with the default `bleed: 0` while its caller had
            // clamped with the surface's own bleed, so on any surface with fill > 1 — every
            // host taller than `bandHeight`, the full-bleed splash included — a legitimate
            // push whose landing sat in the bleed margin was measured against a tighter
            // canvas, judged off-screen, and rejected. The word then stayed exactly where the
            // zone existed to keep it from. The parameter is required rather than defaulted
            // because a silent default is what made the two disagree in the first place.
            let reclamped = clamp(candidate, halfSize: halfSize, scale: scale, in: size,
                                  bleed: bleed)
            if abs(reclamped.x - candidate.x) < 0.5, abs(reclamped.y - candidate.y) < 0.5 {
                result = candidate
            }
        }
        return result
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
    static func clamp(_ point: CGPoint, halfSize: CGSize, scale: CGFloat, in size: CGSize,
                      bleed: CGFloat = 0) -> CGPoint {
        // `bleed` shrinks the effective half-extent, which lets that fraction of the word
        // hang off the edge while the rest of the clamp works exactly as before.
        let halfW = halfSize.width * scale * (1 - min(0.95, bleed))
        let halfH = halfSize.height * scale * (1 - min(0.95, bleed))
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
        // TWICE the breath depth. The breath term is `sin(wt + phase) - sin(phase)`, whose
        // range is [-2, 2], not [-1, 1] — phase-correcting the oscillator to fix the rest
        // pose silently doubled the amplitude of every one of them. Caught only because
        // `scaleNeverExceedsTheResolvedCeiling` compares against this constant; the visible
        // symptom would have been text a few percent wider than it should be, forever,
        // because a symbol drawn above its resolved size keeps the metrics it was resolved
        // with.
        Tuning.nearScale * (1 + 2 * Tuning.breathDepth)
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
        /// How far the two expansion axes may diverge before the composition looks smeared.
        static let maximumAxisSkew: CGFloat = 2.2

        /// Points of daylight left between a pushed word and the zone it was pushed out of.
        static let zoneClearance: CGFloat = 1

        /// Depth dimming, before the surface's own `dim` multiplier.
        static let nearOpacity: Double = 1.0
        static let farOpacity: Double = 0.55
    }
}
