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
///   1.3 — every word is settled before the first frame where its whole drift clears the edge,
///         the zones and every word settled before it (#1759), so the clamp and the push have
///         nothing left to correct and no two words can meet
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

        /// How much of its depth's drift this word may use, from 1 (all of it) to 0 (none).
        ///
        /// Below 1 only where ``WordCloudDriftField/settle(_:packedCenters:canvas:zones:bleed:)``
        /// found no room for the whole excursion: a crowded word moves less rather than leaving its
        /// place in the composition. Breathing is untouched, so it still reads as part of the field.
        let excursion: CGFloat

        var id: String { term }

        /// Creates a particle. `excursion` defaults to the whole drift, which every particle had
        /// before the settle pass existed.
        init(term: String, home: CGPoint, baseFontSize: CGFloat, rotationDegrees: Double,
             depth: Double, halfSize: CGSize, phase: SIMD3<Double>, excursion: CGFloat = 1) {
            self.term = term
            self.home = home
            self.baseFontSize = baseFontSize
            self.rotationDegrees = rotationDegrees
            self.depth = depth
            self.halfSize = halfSize
            self.phase = phase
            self.excursion = excursion
        }
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
    /// survives untouched. What the scaling cannot see is the edge and the exclusion zones, which
    /// it carries the outermost words into; ``settle(_:packedCenters:canvas:zones:bleed:)`` is
    /// what keeps the non-overlap once they are corrected (#1759).
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
    /// zone existed to protect. The splash and onboarding pass zones. Since #1759
    /// ``settle(_:packedCenters:canvas:zones:bleed:)`` keeps every word's whole drift out of them,
    /// and `push` remains as the net for a field built without a canvas to settle into.
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
        let bleed = max(0, fill - 1)
        self.bleed = bleed
        let ceiling = Double(max(1, rankCeiling - 1))
        let expanded = placed.map { word in
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
        // Settled in the packer's order, which is rank order, so the commonest words keep their
        // homes — and only where the field is spread past its frame. A band (fill ≤ 1, no bleed)
        // is drawn close to the packer's own tight layout, where every word's drift reaches a
        // neighbour; settling it would take most of its words or all of their motion, so it is
        // left exactly as it was.
        particles = (bleed > 0
            ? Self.settle(expanded, packedCenters: placed.map(\.center), canvas: canvas,
                          zones: exclusionZones, bleed: bleed)
            : expanded)
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

    // MARK: - Settling

    /// The whole of the space one particle can ever occupy, relative to its home.
    ///
    /// Every term of ``state(of:at:in:avoiding:bleed:)`` is a sine with a fixed amplitude, so its
    /// range is known exactly: `sin(ωt + φ) − sin(φ)` runs from `−1 − sin φ` to `1 − sin φ`. The
    /// box a word is drawn in at any instant therefore lies inside its home's box widened by those
    /// ranges and scaled to the largest breath, and two words whose sweeps are apart can never
    /// touch, at any instant, on any device, whatever the clock reads.
    struct Sweep: Equatable {
        /// The horizontal excursion's range, in points.
        let dx: ClosedRange<CGFloat>
        /// The vertical excursion's range, in points.
        let dy: ClosedRange<CGFloat>
        /// The word's half-extent at the largest scale its breath reaches.
        let halfSize: CGSize

        /// The sweep around a home: every box the word can be drawn in, at once.
        func box(at home: CGPoint) -> CGRect {
            CGRect(x: home.x + dx.lowerBound - halfSize.width,
                   y: home.y + dy.lowerBound - halfSize.height,
                   width: dx.upperBound - dx.lowerBound + halfSize.width * 2,
                   height: dy.upperBound - dy.lowerBound + halfSize.height * 2)
        }

        /// Whether the clamp would ever move a word swept from this home: the same test
        /// ``WordCloudDriftField/clamp(_:halfSize:scale:in:bleed:)`` applies, at the sweep's
        /// extremes, with the share of the word that `bleed` lets hang off the edge.
        func fits(at home: CGPoint, in canvas: CGSize, bleed: CGFloat) -> Bool {
            let keep = 1 - min(0.95, bleed)
            return home.x + dx.lowerBound - halfSize.width * keep >= 0
                && home.x + dx.upperBound + halfSize.width * keep <= canvas.width
                && home.y + dy.lowerBound - halfSize.height * keep >= 0
                && home.y + dy.upperBound + halfSize.height * keep <= canvas.height
        }
    }

    /// One particle's sweep — derived from the same depth, phases and tuning `state(of:)` reads.
    ///
    /// - Parameter excursion: the share of the drift to sweep; the particle's own by default.
    static func sweep(of p: Particle, excursion: CGFloat? = nil) -> Sweep {
        let nearness = 1 - p.depth
        let amplitude = (Tuning.farAmplitude + (Tuning.nearAmplitude - Tuning.farAmplitude) * nearness)
            * (excursion ?? p.excursion)
        let vertical = amplitude * Tuning.verticalAmplitudeRatio
        let baseScale = Tuning.farScale + (Tuning.nearScale - Tuning.farScale) * nearness
        let largest = baseScale * (1 + (1 - sin(p.phase.z)) * Tuning.breathDepth)
        let sinX = CGFloat(sin(p.phase.x)), sinY = CGFloat(sin(p.phase.y))
        return Sweep(dx: (-1 - sinX) * amplitude...(1 - sinX) * amplitude,
                     dy: (-1 - sinY) * vertical...(1 - sinY) * vertical,
                     halfSize: CGSize(width: p.halfSize.width * largest,
                                      height: p.halfSize.height * largest))
    }

    /// Gives every particle a home where nothing it ever does can touch the canvas edge, an
    /// exclusion zone, or a word settled before it (#1759).
    ///
    /// ## Why the expansion needs this, though it cannot overlap two words by itself
    /// ``expansion`` multiplies each word's offset from the centre, which grows every gap — but it
    /// knows nothing of the zones or the edge, and the packer's flattened field (`yCompression`
    /// 0.62) is spread furthest of all vertically: ×3.33 on a 13-inch iPad's onboarding, which
    /// carried words straight into the dock's zone and off the canvas. `state(of:)` then corrected
    /// each frame on its own — the clamp pulled a word back to the edge, the push lifted it over the
    /// zone's top — and neither looked at the other words. So onboarding's Add Volumes step drew
    /// *objective* lifted onto *power* above the dock, and *hostility*, thrown 67 pt off the left
    /// edge, clamped onto *conflict* (S2's `onboarding-volumes`, measured at its instant).
    ///
    /// ## What the pass does
    /// In rank order, each particle looks for a home whose ``Sweep`` fits the canvas, misses every
    /// zone and clears every sweep already claimed by ``Tuning/settleClearance``. It looks first on
    /// its own ray — the expanded home, then the line back to the packer's centre — giving up drift
    /// a step at a time (``Tuning/settleExcursions``) before it gives up the ray. Off the ray it
    /// searches outward from the expanded home for the nearest point where it can stand still, and
    /// a few grid steps beyond that for one with more drift (``nearestHome(to:in:level:)``). The
    /// commonest words claim first, so they keep the composition; a word with no room anywhere on
    /// the canvas is left out, as the packer leaves out a word with no slot. A field that never met
    /// an edge, a zone or a neighbour keeps every expanded home and every drift exactly.
    ///
    /// ## What it costs, measured
    /// Over every bundled scope's two first-impression lenses, on the splash and onboarding canvases
    /// of three iPhones, four iPad shapes and the Mac's 560 × 540 window, sampled for five minutes:
    /// before, word boxes met in most frames of almost every layout and words were drawn over the
    /// dock; after, no two boxes meet and none reaches a zone. The iPads keep every word and 89–100%
    /// of the drift (weighted by amplitude); the iPhones keep 99.7–100% of their words and 72–85% of
    /// the drift; the Mac's window, the densest, keeps 98–100% of its words and 76–84% of the drift.
    /// A field takes up to a millisecond to build there on an M-series Mac, which is why
    /// `WordCloudBackdropView` caches it beside the packer's layout.
    ///
    /// A field built with no canvas — the unit tests' fixtures — has nothing to settle into and is
    /// returned as it came.
    static func settle(_ particles: [Particle], packedCenters: [CGPoint], canvas: CGSize,
                       zones: [CGRect], bleed: CGFloat) -> [Particle] {
        guard canvas.width > 0, canvas.height > 0 else { return particles }
        var kept: [Particle] = []
        var claimed: [CGRect] = []
        for (particle, packed) in zip(particles, packedCenters) {
            func isClear(_ home: CGPoint, _ sweep: Sweep) -> Bool {
                guard sweep.fits(at: home, in: canvas, bleed: bleed) else { return false }
                let box = sweep.box(at: home)
                let padded = box.insetBy(dx: -Tuning.settleClearance, dy: -Tuning.settleClearance)
                return !zones.contains { $0.intersects(box) }
                    && !claimed.contains { $0.intersects(padded) }
            }
            let sweeps = Tuning.settleExcursions.map { Self.sweep(of: particle, excursion: $0) }
            var found: (home: CGPoint, level: Int)?
            // On the ray: the most drift first, then the nearest the composition.
            let ray = rayCandidates(from: particle.home, toward: packed)
            for level in sweeps.indices {
                if let home = ray.first(where: { isClear($0, sweeps[level]) }) {
                    found = (home, level)
                    break
                }
            }
            // Off it. A sweep holds every smaller one, so a point that cannot hold the word
            // standing still holds nothing, and that is the one test most points need.
            if found == nil, let still = sweeps.last {
                found = nearestHome(to: particle.home, in: canvas) { point in
                    guard isClear(point, still) else { return nil }
                    return sweeps.indices.first { isClear(point, sweeps[$0]) } ?? sweeps.count - 1
                }
            }
            guard let found else { continue }
            claimed.append(sweeps[found.level].box(at: found.home))
            kept.append(Particle(term: particle.term, home: found.home,
                                 baseFontSize: particle.baseFontSize,
                                 rotationDegrees: particle.rotationDegrees,
                                 depth: particle.depth, halfSize: particle.halfSize,
                                 phase: particle.phase,
                                 excursion: Tuning.settleExcursions[found.level]))
        }
        return kept
    }

    /// The homes on a particle's own ray, nearest the composition first: the expanded home, then
    /// sixteen steps back along the line to the packed centre.
    static func rayCandidates(from home: CGPoint, toward packed: CGPoint) -> [CGPoint] {
        guard home != packed else { return [home] }
        return [home] + (1...16).map { step in
            let along = 1 - CGFloat(step) / 16
            return CGPoint(x: packed.x + (home.x - packed.x) * along,
                           y: packed.y + (home.y - packed.y) * along)
        }
    }

    /// The home a particle takes off its ray: a point of a ``Tuning/settleGrid`` grid, searched in
    /// square rings outward from `start` (pulled onto the canvas first).
    ///
    /// `level` answers, for a point, the index into ``Tuning/settleExcursions`` of the most drift
    /// the word has room for there, or `nil` where it cannot even stand still. The search takes
    /// the first point with the whole drift; failing that, it runs ``Tuning/settleSearchRings``
    /// rings past the first point that holds the word at all and takes the one with the most drift
    /// it met, the nearest among equals. So a word stays near its place in the composition and
    /// still moves where the canvas allows — measured, a bare nearest-point rule kept about half
    /// the drift on a phone, and an unbounded search for full drift cost four times as long and
    /// carried words further. `nil` only when no grid point on the canvas holds the word.
    static func nearestHome(to start: CGPoint, in canvas: CGSize,
                            level: (CGPoint) -> Int?) -> (home: CGPoint, level: Int)? {
        let step = Tuning.settleGrid
        let origin = CGPoint(x: min(max(start.x, 0), canvas.width),
                             y: min(max(start.y, 0), canvas.height))
        var best: (home: CGPoint, level: Int)?
        var firstRing: Int?
        let rings = Int((max(canvas.width, canvas.height) / step).rounded(.up))
        for ring in 0...rings {
            // The ring's square, clockwise from its top-left corner, without repeating a corner.
            var offsets: [CGPoint] = ring == 0 ? [.zero] : []
            if ring > 0 {
                for i in -ring..<ring { offsets.append(CGPoint(x: i, y: -ring)) }
                for i in -ring..<ring { offsets.append(CGPoint(x: ring, y: i)) }
                for i in -ring..<ring { offsets.append(CGPoint(x: -i, y: ring)) }
                for i in -ring..<ring { offsets.append(CGPoint(x: -ring, y: -i)) }
            }
            for offset in offsets {
                let point = CGPoint(x: origin.x + offset.x * step, y: origin.y + offset.y * step)
                guard point.x >= 0, point.x <= canvas.width,
                      point.y >= 0, point.y <= canvas.height,
                      let room = level(point) else { continue }
                if firstRing == nil { firstRing = ring }
                if room < best?.level ?? Int.max {
                    best = (point, room)
                    if room == 0 { return best }
                }
            }
            if let firstRing, ring >= firstRing + Tuning.settleSearchRings { return best }
        }
        return best
    }

    // MARK: - Motion

    /// Where a particle is, how big, and how bright, at `time`.
    ///
    /// - Parameter time: seconds since an arbitrary but fixed epoch. `0` yields the rest
    ///   pose, which is what Reduce Motion draws.
    /// - Parameter size: the canvas, used only to keep words inside it.
    /// - Note: `bleed` is **required**, on the same argument the push's own re-clamp records: a
    ///   silent default is what let the two clamps disagree, and nothing structurally ties a
    ///   caller's bleed to the one the particle's homes were expanded with. Making it explicit
    ///   puts the question in front of every caller instead of answering it for them with a zero.
    static func state(of p: Particle, at time: Double, in size: CGSize,
                      avoiding zones: [CGRect] = [], bleed: CGFloat) -> State {
        // Parallax: near words swing wider and faster than far ones. This is the whole of
        // the depth illusion — the eye reads differential motion as distance long before it
        // reads size.
        let nearness = 1 - p.depth
        // Scaled by the share of the drift the settle pass left this word room for.
        let amplitude = (Tuning.farAmplitude
            + (Tuning.nearAmplitude - Tuning.farAmplitude) * nearness) * p.excursion
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

        /// Points of daylight kept between two settled words' sweeps, on top of the sweeps
        /// themselves — which already hold every excursion, so at rest the gap is far wider.
        static let settleClearance: CGFloat = 2

        /// The shares of its drift a crowded word gives up to, in turn, before it leaves its ray.
        /// Descending, and ending at 0, which ``WordCloudDriftField/settle`` relies on.
        static let settleExcursions: [CGFloat] = [1, 0.5, 0.25, 0]

        /// The spacing, in points, of the grid a word searches when its own ray has no room.
        static let settleGrid: CGFloat = 8

        /// How many grid rings past the first that holds it a word looks for more drift: 48 pt.
        static let settleSearchRings = 6

        /// Depth dimming, before the surface's own `dim` multiplier.
        static let nearOpacity: Double = 1.0
        static let farOpacity: Double = 0.55
    }
}
