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

import Testing
import Foundation
import CoreGraphics
@testable import FRUSExplorer

/// The drift field's motion model.
///
/// ## What is worth testing about an animation
/// Not whether it looks good — that is the owner's call, on a device. What a test can do,
/// and the eye cannot, is answer the questions that only fail sometimes:
///
/// - Does a word *ever* leave its frame, at any instant, at any depth? Sampling the motion
///   answers that in milliseconds; watching it does not answer it at all.
/// - Is the field identical on every launch? A per-process hash seed would make it differ,
///   and nobody would ever notice by looking.
/// - Does any particle ever scale *above* the size its symbol was resolved at? That is
///   invisible — it shows up as text a few percent wider than it should be, forever.
///
/// Version history:
///   1.0 — P-1: initial implementation
@Suite("Word cloud — drift field")
struct WordCloudDriftFieldTests {

    private func word(_ term: String, rank: Int, at center: CGPoint,
                      fontSize: CGFloat = 20, rotated: Bool = false) -> PlacedWord {
        PlacedWord(term: term, count: 100 - rank, center: center, fontSize: fontSize,
                   colorIndex: rank, rotationDegrees: rotated ? 90 : 0)
    }

    // MARK: - Depth comes from true rank

    /// `WordCloudLayout.place` drops any word it cannot fit and returns a *compacted* array,
    /// so index 3 is routinely rank 8. Depth drives size, brightness and parallax, so
    /// reading it off the index would make a common word behave like a rare one purely
    /// because words above it failed to place — which on an iPhone-width strip is most of
    /// them.
    @Test("Depth is read from colorIndex, not the array index")
    func depthUsesTrueRankNotArrayIndex() throws {
        // Ranks 0, 8, 24 survived; ranks 1-7 and 9-23 were dropped by the packer.
        let placed = [
            word("alpha", rank: 0, at: CGPoint(x: 100, y: 50)),
            word("beta", rank: 8, at: CGPoint(x: 200, y: 50)),
            word("gamma", rank: 24, at: CGPoint(x: 300, y: 50)),
        ]
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)

        let byTerm = Dictionary(uniqueKeysWithValues: field.particles.map { ($0.term, $0) })
        #expect(byTerm["alpha"]?.depth == 0, "rank 0 is nearest")
        #expect(abs((byTerm["beta"]?.depth ?? 0) - 8.0 / 24.0) < 0.0001,
                "rank 8 of a 25-word ceiling — the array index 1 would have given 0.5")
        #expect(byTerm["gamma"]?.depth == 1, "rank 24 is furthest")
    }

    @Test("Particles are ordered far to near, so a painter's pass is a plain loop")
    func particlesAreOrderedFarToNear() {
        let placed = (0..<10).map { word("w\($0)", rank: $0, at: CGPoint(x: 50 * $0 + 20, y: 40)) }
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)
        let depths = field.particles.map(\.depth)
        #expect(depths == depths.sorted(by: >), "nearer words must be drawn last, or they hide behind far ones")
    }

    // MARK: - The frame is never left

    /// The packer guarantees every *home* box is inside the canvas; nothing guarantees that
    /// once a particle drifts and scales. Sampling the whole motion is the only way to know.
    ///
    /// **Asserts the box, not the centre.** The first version checked
    /// `0 <= position.x <= width`, which `clamp` returns unconditionally: its lower bound is
    /// `min(halfW, W/2)` and its upper is `max(W - halfW, W/2)`, both inside `[0, W]` for
    /// any non-negative inputs. Nothing the test varied could have made it fail.
    ///
    /// **What this still does not cover**, and it took a mutation to notice: the expectation
    /// is computed from `particle.halfSize`, which is the extent estimate itself. So this
    /// verifies the *clamp* against whatever extents it is given, and is blind to the
    /// extents being wrong. Corrupt `estimatedHalfSize` — drop the rotation swap, say — and
    /// this test happily re-derives its own bounds from the corrupted value and passes.
    /// `rotatedWordExtentsAreSwapped` is the independent oracle for that half.
    @Test("No word's box leaves the canvas, at any instant, at any depth")
    func particlesStayInsideTheCanvas() {
        let size = CGSize(width: 393, height: 96)   // an iPhone indexing strip
        let placed = [
            word("diplomatic", rank: 0, at: CGPoint(x: 60, y: 30), fontSize: 34),
            word("negotiation", rank: 6, at: CGPoint(x: 200, y: 60), fontSize: 24),
            word("aid", rank: 12, at: CGPoint(x: 340, y: 20), fontSize: 18),
            // Rotated, and long enough that its UNROTATED width (~168 pt) far exceeds the
            // canvas height. That makes the width/height swap in `estimatedHalfSize`
            // load-bearing: drop it and this word's vertical half-extent collapses from
            // 168 to 7.5, the clamp stops constraining it, and it hangs off the strip.
            word("internationalisation", rank: 24, at: CGPoint(x: 300, y: 48),
                 fontSize: 12, rotated: true),
        ]
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)

        // ~3 minutes of motion at 20 Hz — long enough to cover every phase relationship
        // between the horizontal, vertical and breathing oscillators.
        for step in 0..<3600 {
            let t = Double(step) / 20
            for particle in field.particles {
                let state = WordCloudDriftField.state(of: particle, at: t, in: size)
                #expect(state.position.x.isFinite && state.position.y.isFinite)

                let halfW = particle.halfSize.width * state.scale
                let halfH = particle.halfSize.height * state.scale
                // A word too large to fit in an axis is centred instead — the only honest
                // option, and the packer emits them routinely on a 96 pt strip. Everything
                // that *can* fit must fit.
                if halfW * 2 <= size.width {
                    #expect(state.position.x - halfW >= -0.001,
                            "\(particle.term) box escaped left at t=\(t): \(state.position)")
                    #expect(state.position.x + halfW <= size.width + 0.001,
                            "\(particle.term) box escaped right at t=\(t): \(state.position)")
                } else {
                    #expect(abs(state.position.x - size.width / 2) < 0.001)
                }
                if halfH * 2 <= size.height {
                    #expect(state.position.y - halfH >= -0.001,
                            "\(particle.term) box escaped top at t=\(t): \(state.position)")
                    #expect(state.position.y + halfH <= size.height + 0.001,
                            "\(particle.term) box escaped bottom at t=\(t): \(state.position)")
                } else {
                    #expect(abs(state.position.y - size.height / 2) < 0.001)
                }
            }
        }
    }

    @Test("A word wider than its canvas clamps to the centre rather than inverting")
    func oversizedWordClampsToCentre() {
        // Routine on a 96 pt strip: the estimated box is taller than the frame.
        let size = CGSize(width: 200, height: 40)
        let placed = [word("internationalisation", rank: 0, at: CGPoint(x: 100, y: 20), fontSize: 30)]
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)
        let particle = try! #require(field.particles.first)

        for step in 0..<200 {
            let state = WordCloudDriftField.state(of: particle, at: Double(step) / 10, in: size)
            #expect(state.position.x == size.width / 2,
                    "a word too wide to fit must sit centred, not at an inverted bound")
        }
    }

    /// The extent estimate itself, against hand-computed values rather than against the
    /// implementation. This is the half `particlesStayInsideTheCanvas` structurally cannot
    /// check, because it takes `halfSize` as an input.
    ///
    /// A 90° word is narrow and tall. Getting that backwards makes a long rotated term
    /// report a 7.5 pt vertical half-extent instead of 67, so the clamp stops constraining
    /// it and it hangs off the strip — while every bounds assertion still passes.
    @Test("A rotated word's extents are swapped")
    func rotatedWordExtentsAreSwapped() {
        // width = 20 chars × 12 pt × 0.54 + 12 × 0.4 = 129.6 + 4.8 = 134.4  → half 67.2
        // height = 12 × 1.25 = 15                                          → half 7.5
        let upright = WordCloudDriftField.estimatedHalfSize(
            term: "internationalisation", fontSize: 12, rotated: false)
        #expect(abs(upright.width - 67.2) < 0.01, "got \(upright.width)")
        #expect(abs(upright.height - 7.5) < 0.01, "got \(upright.height)")

        let rotated = WordCloudDriftField.estimatedHalfSize(
            term: "internationalisation", fontSize: 12, rotated: true)
        #expect(abs(rotated.width - 7.5) < 0.01, "a 90° word is NARROW — got \(rotated.width)")
        #expect(abs(rotated.height - 67.2) < 0.01, "and TALL — got \(rotated.height)")
    }

    /// The estimate must track the packer's own heuristic, or the clamp constrains a box
    /// that does not describe the word being drawn.
    @Test("The extent estimate matches WordCloudLayout's glyph heuristic")
    func extentsMatchThePackerHeuristic() {
        for (term, fontSize) in [("aid", 34.0), ("negotiation", 18.0), ("policy", 12.0)] {
            let half = WordCloudDriftField.estimatedHalfSize(
                term: term, fontSize: fontSize, rotated: false)
            let expectedWidth = (Double(term.count) * fontSize * 0.54 + fontSize * 0.4) / 2
            let expectedHeight = fontSize * 1.25 / 2
            #expect(abs(half.width - expectedWidth) < 0.01, "\(term)")
            #expect(abs(half.height - expectedHeight) < 0.01, "\(term)")
        }
    }

    // MARK: - The symbol is never magnified

    /// Symbols are resolved at `baseFontSize × maximumScale` and the renderer divides by
    /// that. If any scale exceeds the ceiling the divisor goes above 1 and the symbol is
    /// magnified past its resolved metrics — which does not blur (resolved symbols are
    /// resolution-independent) but does make the text a few percent wider than it should be,
    /// permanently and invisibly.
    @Test("No particle ever scales above the size its symbol is resolved at")
    func scaleNeverExceedsTheResolvedCeiling() {
        let size = CGSize(width: 400, height: 200)
        let placed = (0..<25).map { word("w\($0)", rank: $0, at: CGPoint(x: 200, y: 100)) }
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)
        let ceiling = WordCloudDriftField.maximumScale

        var observedMax: CGFloat = 0
        for step in 0..<4000 {
            for particle in field.particles {
                let scale = WordCloudDriftField.state(of: particle, at: Double(step) / 20, in: size).scale
                observedMax = max(observedMax, scale)
                #expect(scale <= ceiling + 1e-9, "scale \(scale) exceeded the resolved ceiling \(ceiling)")
                #expect(scale > 0)
            }
        }
        // And the ceiling must not be wastefully high, or every symbol is resolved much
        // larger than it is ever drawn.
        #expect(observedMax > ceiling * 0.98, "the ceiling should be reached, not merely respected")
    }

    // MARK: - Determinism

    /// `String.hashValue` is seeded per process. Using it here would make the cloud animate
    /// differently on every launch — never wrong-looking, never noticed, and quietly at odds
    /// with the deterministic packer the layout cache depends on.
    @Test("Phase offsets are stable across processes, not seeded")
    func phasesAreDeterministic() {
        // Pinned literals, computed from the FNV-1a definition rather than observed from a
        // run — a golden value copied out of the failure message would pin whatever the code
        // does, including a bug. If the hash ever changes these change, and that is the
        // point: it becomes a deliberate re-tune rather than a silent one.
        let concepts = WordCloudDriftField.phase(for: "diplomatic")
        #expect(abs(concepts.x - 3.6447) < 0.001, "got \(concepts.x)")
        #expect(abs(concepts.y - 4.5051) < 0.001, "got \(concepts.y)")
        #expect(abs(concepts.z - 2.3654) < 0.001, "got \(concepts.z)")
    }

    @Test("Different terms get different phases, so nothing moves in lockstep")
    func phasesDiffer() {
        let terms = ["treaty", "aid", "negotiation", "policy", "security", "trade"]
        let xs = terms.map { WordCloudDriftField.phase(for: $0).x }
        #expect(Set(xs.map { Int($0 * 1000) }).count == terms.count)
    }

    @Test("Every phase component is inside one full turn")
    func phasesAreInRange() {
        for term in ["a", "the", "reparations", "西", "", "a-very-long-compound-term"] {
            let p = WordCloudDriftField.phase(for: term)
            for component in [p.x, p.y, p.z] {
                #expect(component >= 0 && component < .pi * 2, "\(term): \(component)")
            }
        }
    }

    // MARK: - Reduce Motion

    /// Pinning the clock, not pausing the schedule. Pausing alone freezes whatever pose the
    /// field happened to be in, which reads as a rendering fault; `t = 0` is a deliberate
    /// rest pose and it is the same one every time.
    @Test("At t=0 every particle sits at its home position")
    func restPoseIsTheHomeLayout() {
        let size = CGSize(width: 400, height: 300)
        let homes = [CGPoint(x: 100, y: 100), CGPoint(x: 250, y: 180), CGPoint(x: 300, y: 60)]
        let placed = homes.enumerated().map { word("w\($0.offset)", rank: $0.offset * 8, at: $0.element) }
        let field = WordCloudDriftField(placed: placed, rankCeiling: 25)

        for particle in field.particles {
            let state = WordCloudDriftField.state(of: particle, at: 0, in: size)
            let dx = abs(state.position.x - particle.home.x)
            let dy = abs(state.position.y - particle.home.y)
            // sin(0 + phase) is not zero, so the rest pose is the home plus each word's own
            // fixed offset — stable, bounded, and identical on every launch. What matters is
            // that it does not wander.
            #expect(dx <= WordCloudDriftField.Tuning.nearAmplitude + 0.001)
            #expect(dy <= WordCloudDriftField.Tuning.nearAmplitude + 0.001)

            let again = WordCloudDriftField.state(of: particle, at: 0, in: size)
            #expect(again == state, "the rest pose must be a function, not a sample")
        }
    }

    // MARK: - Depth cues actually vary

    @Test("Near words are larger, brighter and swing wider than far ones")
    func depthCuesAreMonotone() {
        let size = CGSize(width: 800, height: 600)
        let near = word("near", rank: 0, at: CGPoint(x: 400, y: 300))
        let far = word("far", rank: 24, at: CGPoint(x: 400, y: 300))
        let field = WordCloudDriftField(placed: [near, far], rankCeiling: 25)
        let nearP = field.particles.first { $0.term == "near" }!
        let farP = field.particles.first { $0.term == "far" }!

        // Sampled across time, because a single instant can catch either mid-oscillation.
        var nearExcursion = 0.0, farExcursion = 0.0
        var nearScaleSum = 0.0, farScaleSum = 0.0
        for step in 0..<2000 {
            let t = Double(step) / 20
            let n = WordCloudDriftField.state(of: nearP, at: t, in: size)
            let f = WordCloudDriftField.state(of: farP, at: t, in: size)
            nearExcursion = max(nearExcursion, abs(n.position.x - 400))
            farExcursion = max(farExcursion, abs(f.position.x - 400))
            nearScaleSum += n.scale
            farScaleSum += f.scale
            #expect(n.opacity > f.opacity, "the near word must always be the brighter one")
        }
        #expect(nearExcursion > farExcursion * 2, "parallax is the primary depth cue and must be pronounced")
        #expect(nearScaleSum > farScaleSum)
    }

    // MARK: - The lens cycle

    @Test("The crossfade runs at the head of each hold and then settles")
    func lensCycleCrossfades() {
        let cadence = FRUSTheme.cloudLensCadence
        // Just after a boundary: mid-crossfade.
        let early = WordCloudDriftCanvas.cycle(at: cadence * 4 + 0.05, layerCount: 4)
        #expect(early.progress > 0 && early.progress < 1)
        #expect(early.incoming != early.outgoing)

        // Late in the hold: fully settled on one lens.
        let settled = WordCloudDriftCanvas.cycle(at: cadence * 4 + cadence * 0.9, layerCount: 4)
        #expect(settled.progress == 1)
    }

    @Test("Lens indices wrap and never go negative")
    func lensCycleWraps() {
        for step in 0..<200 {
            let c = WordCloudDriftCanvas.cycle(at: Double(step) * 0.7, layerCount: 4)
            #expect(c.incoming >= 0 && c.incoming < 4, "incoming \(c.incoming)")
            #expect(c.outgoing >= 0 && c.outgoing < 4, "outgoing \(c.outgoing)")
            #expect(c.progress >= 0 && c.progress <= 1)
        }
    }

    @Test("At t=0 the cycle names the PREVIOUS layer, which is why the clocks are separate")
    func cycleAtZeroWrapsBackwards() {
        // Not a hypothetical. Reduce Motion originally pinned one clock for both the drift
        // and the lens cycle, and this is what that produced: at t = 0 `outgoing` wraps to
        // the last layer and `progress` is 0, so the canvas drew layer 3 — sentiment — at
        // full opacity and never advanced. A Reduce Motion user saw one lens of four.
        let c = WordCloudDriftCanvas.cycle(at: 0, layerCount: 4)
        #expect(c.outgoing == 3)
        #expect(c.progress == 0)
        // The renderer draws `outgoing` at `1 - progress`, i.e. layer 3 at full strength.
        // The fix is not to change this function — it is correct for a running clock — but
        // to keep the cycle on the real clock while pinning only the motion.
    }

    @Test("A single lens never cross-fades with itself")
    func singleLayerDoesNotCrossfade() {
        let c = WordCloudDriftCanvas.cycle(at: 12.3, layerCount: 1)
        #expect(c.incoming == 0 && c.outgoing == 0 && c.progress == 0)
    }

    // MARK: - The layout cache key

    /// The cache key omitted `exclusionZones` entirely, so two different exclusion rects at
    /// the same quantised box returned the same placement.
    ///
    /// That is not theoretical. Onboarding derives its zone from `measuredDockHeight`, and
    /// O-5 introduced that measurement precisely because a hardcoded guess left words
    /// underneath a dock that had grown at large accessibility text sizes. The cache handed
    /// back the pre-growth layout and quietly re-created the bug the measurement existed to
    /// fix — visible only at a text size nobody re-tests at.
    @Test("Different exclusion zones produce different cache keys")
    @MainActor
    func exclusionZonesDiscriminate() {
        let short = WordCloudBackdropView.exclusionSignature([CGRect(x: 0, y: 400, width: 390, height: 200)])
        let tall = WordCloudBackdropView.exclusionSignature([CGRect(x: 0, y: 300, width: 390, height: 300)])
        #expect(short != tall, "a dock that grew must not reuse the layout packed around the smaller one")
        #expect(WordCloudBackdropView.exclusionSignature([]) != short)
    }

    /// Quantised for the same reason the box is: the measured dock height moves by fractions
    /// of a point as type settles, and an exact key would miss on every one of them and
    /// re-run the packer inside `body` — the incident that produced the 8 pt grid.
    @Test("Sub-grid differences collapse to the same key")
    @MainActor
    func exclusionZonesQuantise() {
        let a = WordCloudBackdropView.exclusionSignature([CGRect(x: 0, y: 400.0, width: 390, height: 200.0)])
        let b = WordCloudBackdropView.exclusionSignature([CGRect(x: 0, y: 401.3, width: 390, height: 199.4)])
        #expect(a == b, "a 1 pt wobble in a measured height must not thrash the cache")
    }
}
