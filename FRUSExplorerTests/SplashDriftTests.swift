// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import CoreGraphics
@testable import FRUSExplorer

// MARK: - SplashDriftTests

/// The launch splash's particle field, and the clamp defect that had to be fixed to enable it
/// (visual-marketing plan §3.2, M-4).
///
/// ## Why these tests did not exist before
/// `WordCloudDriftField.push` has **never run in production**. It is reached only when a drifting
/// surface passes an exclusion zone, and until this change the one surface passing a zone — the
/// splash — was on the static `Text` renderer, while the two drifting surfaces passed no zones.
/// So the path was written, reviewed, and shipped unexecuted, with a real bug in it.
///
/// Version history:
///   1.0 — visual-marketing plan §3.2 M-4: initial implementation
@Suite("Launch splash — drift and exclusion")
struct SplashDriftTests {

    /// A phone at the width the composition review is asked for.
    private let phone = CGSize(width: 393, height: 852)

    // MARK: - The clamp defect

    /// **The bug, at the only geometry where it shows.**
    ///
    /// `state(of:)` clamps a drifted word against the canvas *plus the surface's bleed*, then asks
    /// `push` to move it out of a zone. `push` re-clamped the candidate against the canvas with
    /// **no bleed**, so a push whose landing sat in the bleed margin was measured against a
    /// tighter canvas than the one it was drawn on, judged off-screen, and rejected — leaving the
    /// word inside the zone it was being moved out of.
    ///
    /// The fixture puts the landing squarely in that margin and nowhere else. With `halfW` 40 and
    /// bleed 0.12 the accepted left edge moves from 40 to 35.2, so a candidate at **x = 37** is
    /// rejected under the old rule and accepted under the new one. A candidate on either side of
    /// that 4.8 pt band behaves identically before and after, which is why the numbers are chosen
    /// rather than round.
    @Test("A push landing in the bleed margin is accepted, not discarded")
    func pushHonoursTheSurfacesBleed() {
        let size = phone
        // Tall enough that a vertical escape is never the shortest move, so the push is the
        // horizontal one whose landing this test is about.
        let zone = CGRect(x: 78, y: 0, width: 200, height: size.height)
        let half = CGSize(width: 40, height: 12)
        let start = CGPoint(x: 100, y: 426)   // box [60, 140] — overlaps the zone at 78

        let withBleed = WordCloudDriftField.push(start, halfSize: half, scale: 1,
                                                 outOf: [zone], in: size, bleed: 0.12)
        // 78 - 40 - 1 (clearance) = 37, inside the bleed-widened canvas and outside the bare one.
        #expect(abs(withBleed.x - 37) < 0.001, "expected the word moved clear, got \(withBleed.x)")
        #expect(!CGRect(x: withBleed.x - 40, y: withBleed.y - 12, width: 80, height: 24)
            .intersects(zone), "the word is still under the identity block")

        // A genuinely zero-bleed surface is unchanged: the same candidate really is off its canvas.
        let noBleed = WordCloudDriftField.push(start, halfSize: half, scale: 1,
                                               outOf: [zone], in: size, bleed: 0)
        #expect(abs(noBleed.x - start.x) < 0.001,
                "a zero-bleed surface must still refuse an off-canvas push, got \(noBleed.x)")
    }

    /// The refusal is not removed, only measured correctly. A push that lands off the canvas even
    /// *with* the bleed is still declined — a word half off the screen is a worse failure than a
    /// word touching the zone it should have cleared.
    @Test("A push that clears the bleed-widened canvas too is still refused")
    func anImpossiblePushIsStillRefused() {
        let size = phone
        // The zone starts hard against the left edge, so there is nowhere to the left to go.
        let zone = CGRect(x: 0, y: 0, width: 200, height: size.height)
        let half = CGSize(width: 40, height: 12)
        let start = CGPoint(x: 100, y: 426)
        let pushed = WordCloudDriftField.push(start, halfSize: half, scale: 1,
                                              outOf: [zone], in: size, bleed: 0.12)
        // `right` is the shortest escape here and it is on-canvas, so the word does move —
        // what must not happen is a move that puts it off the left edge.
        #expect(pushed.x >= 35.2 - 0.001, "the word was pushed off the canvas: \(pushed.x)")
    }

    /// Without zones the whole path is inert, bleed or no bleed.
    @Test("No zones, no movement")
    func noZonesNoMovement() {
        let point = CGPoint(x: 10, y: 10)
        #expect(WordCloudDriftField.push(point, halfSize: CGSize(width: 40, height: 12),
                                         scale: 1, outOf: [], in: phone, bleed: 0.12) == point)
    }

    /// **The same defect through the door production uses.**
    ///
    /// The test above drives `push` directly, which is not what the canvas does — it calls
    /// `state(of:)`, and `state(of:)` has to *forward* its bleed to the push. Fixing `push`'s
    /// signature while leaving that call passing `0` restores the bug in full and leaves the
    /// direct test green, so the fix needs an assertion on the real entry point. (Measured: that
    /// exact mutation survived every other test in this suite.)
    ///
    /// At `t = 0` the field is phase-corrected to sit exactly on its packed layout with `breath`
    /// at 1, so the particle is at `home` and the scale is `farScale`. That makes the geometry
    /// arithmetic rather than a search: half-width 50 × 0.78 = 39, so a zone at x = 76 puts the
    /// escape at 76 − 39 − 1 = **36**, inside the bleed-widened canvas (34.32) and outside the
    /// bare one (39).
    @Test("state(of:) forwards its bleed, so the push survives the trip")
    func stateForwardsBleedIntoThePush() {
        let size = CGSize(width: 400, height: 400)
        // Full-height so a vertical escape is never the shortest; wide so `right` never is either.
        let zone = CGRect(x: 76, y: 0, width: 250, height: 400)
        let particle = WordCloudDriftField.Particle(
            term: "communiqué", home: CGPoint(x: 100, y: 200), baseFontSize: 20,
            rotationDegrees: 0, depth: 1, halfSize: CGSize(width: 50, height: 15),
            phase: SIMD3<Double>(0, 0, 0))

        let state = WordCloudDriftField.state(of: particle, at: 0, in: size,
                                              avoiding: [zone], bleed: 0.12)
        #expect(abs(state.position.x - 36) < 0.001,
                "expected the word cleared to 36, got \(state.position.x)")
        let box = CGRect(x: state.position.x - 39, y: state.position.y - 11.7,
                         width: 78, height: 23.4)
        #expect(!box.intersects(zone), "the word is still under the identity block")
    }

    // MARK: - The splash's own geometry

    /// The composition guard the plan asks for: the **real** identity zone, at phone width, over a
    /// full drift period — and, crucially, a check that the sweep actually reaches the zone.
    ///
    /// **The first version of this test was inert and looked fine.** It placed words 14 pt outside
    /// the zone's edges, which sounds like the closest the packer could put them; but
    /// `WordCloudDriftField.init` then applies the v1.2 expansion — measured at (1.78, 2.97) for a
    /// set this small — which threw every home clean off the canvas, 267 pt from the zone. The
    /// pre-push box intersected the zone in **0 of 4,800 samples**, so the whole sweep passed with
    /// `push` deleted, with `state(of:)` not calling it, with the exclusion zones discarded in the
    /// initialiser, and with the very bug this change fixes restored.
    ///
    /// So the assertion that matters is `entered > 0`, and it is measured rather than assumed: each
    /// instant is evaluated twice, once with no zones (which is the un-pushed position, since
    /// `push` returns early on an empty list) and once with the real one. Any future change to
    /// `expansion`, `fillFactor` or the tuning that quietly stops carrying words into the zone
    /// fails here instead of going green.
    @Test("No word settles on the identity block — and the sweep really reaches it")
    func nothingSettlesOnTheIdentityBlock() {
        let size = phone
        let zone = LaunchSplashView.identityZone(in: size)
        let fill = WordCloudBackdropView.fillFactor(for: size)
        #expect(fill > 1, "the splash must be a full-bleed surface for this test to mean anything")

        // **Packed centres, not final positions.** The expansion moves each of these outward from
        // the canvas centre; these values were chosen so that AFTER it they sit a few points
        // outside the zone's edges — where the packer would actually leave them — and drift then
        // carries them in. `entered` below is what keeps that true.
        let placed = [
            word("diplomacy", at: CGPoint(x: size.width / 2, y: 392), rank: 0),
            word("telegram", at: CGPoint(x: size.width / 3, y: 460), rank: 8),
            word("memorandum", at: CGPoint(x: size.width * 2 / 3, y: 388), rank: 20),
            word("aide", at: CGPoint(x: size.width / 2, y: 464), rank: 40),
        ]
        let field = WordCloudDriftField(placed: placed,
                                        rankCeiling: WordCloudBackdropView.rankCeiling,
                                        exclusionZones: [zone], canvas: size, fill: fill)
        #expect(field.bleed > 0, "fill > 1 must produce a bleed for the push path to matter")

        func box(_ state: WordCloudDriftField.State,
                 _ particle: WordCloudDriftField.Particle) -> CGRect {
            CGRect(x: state.position.x - particle.halfSize.width * state.scale,
                   y: state.position.y - particle.halfSize.height * state.scale,
                   width: particle.halfSize.width * state.scale * 2,
                   height: particle.halfSize.height * state.scale * 2)
        }

        var entered = 0
        for particle in field.particles {
            for step in 0..<1_200 {
                let t = Double(step) / 20
                // No zones = the position before any push, since `push` returns early on `[]`.
                let free = WordCloudDriftField.state(of: particle, at: t, in: size,
                                                     avoiding: [], bleed: field.bleed)
                if box(free, particle).intersects(zone) { entered += 1 }

                let pushed = WordCloudDriftField.state(of: particle, at: t, in: size,
                                                       avoiding: field.exclusionZones,
                                                       bleed: field.bleed)
                let settled = box(pushed, particle)
                #expect(!settled.intersects(zone),
                        "\(particle.term) settled on the identity block at step \(step)")
                if settled.intersects(zone) { return }
            }
        }
        #expect(entered > 0,
                "the sweep never carried a word into the zone, so it proves nothing about the push")
    }

    /// The splash is a full-bleed surface by the same rule every other host uses — it is far
    /// taller than the band threshold, so it takes the spread the field's v1.2 expansion exists
    /// for. If this ever flipped, M-4's whole argument would be gone and the splash would be back
    /// to a clump in an empty expanse.
    @Test("The splash is on the full-bleed side of the fill threshold")
    func splashIsFullBleed() {
        #expect(phone.height > WordCloudBackdropView.bandHeight)
        #expect(WordCloudBackdropView.fillFactor(for: phone) > 1)
        // …and a short strip is not, so the threshold is doing work.
        #expect(WordCloudBackdropView.fillFactor(for: CGSize(width: 393, height: 96)) <= 1)
    }

    /// **The zone must cover the thing it exists to protect.**
    ///
    /// The composition sweep above places its words relative to the zone, so it moves with the
    /// zone and passes for any zone at all — shrinking `identityZone` to 40 pt tall left it green.
    /// This checks the zone against the identity block's own layout constants instead, so a zone
    /// too small to cover the wordmark fails here rather than on a store screenshot.
    @Test("The exclusion zone covers the identity block it protects")
    func zoneCoversTheIdentityBlock() {
        for size in [phone, CGSize(width: 1_280, height: 800)] {
            let zone = LaunchSplashView.identityZone(in: size)
            #expect(zone.height >= LaunchSplashView.identityBlockMinimumHeight,
                    "the zone is \(zone.height) tall at \(size), and the block needs \(LaunchSplashView.identityBlockMinimumHeight)")
            #expect(zone.width >= LaunchSplashView.tileSize,
                    "the zone is narrower than the app tile at \(size)")
            // Centred on the block, which is centred in the frame.
            #expect(abs(zone.midX - size.width / 2) < 0.001)
            #expect(abs(zone.midY - size.height / 2) < 0.001)
        }
    }

    // MARK: - Wiring

    /// The splash actually asks for the particle field.
    ///
    /// Scoped to the `WordCloudBackdropView(…)` call rather than the file, so it cannot pass on a
    /// `drift` mentioned anywhere else in the source — and it fails loudly if the call cannot be
    /// found at all, which is the way a source scan usually goes quietly wrong.
    @Test("LaunchSplashView asks its backdrop to drift")
    func splashRequestsDrift() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Analytics/WordCloud/LaunchSplashView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "WordCloudBackdropView("),
                                 "the splash no longer builds a WordCloudBackdropView")
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "\n                )"),
                               "could not find the end of the backdrop call")
        // **Comments stripped first.** Two thirds of this call's 1,600 characters are prose
        // explaining why the splash drifts, and a bare `contains` is satisfied by an explanation
        // as readily as by an argument — so flipping the flag while any nearby comment happened to
        // quote it would leave this green.
        let call = String(rest[..<end.lowerBound])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(call.contains("drift: true"), "the splash stopped drifting:\n\(call)")
        #expect(call.contains("lensSeed: 0"), "M-5's seeded lens was lost")
    }

    // MARK: - Helpers

    /// `rank` is load-bearing: it becomes `colorIndex`, which the field turns into `depth`, which
    /// selects the amplitude, rate, scale and opacity. Leaving it at 0 for every word — as the
    /// first draft did — sweeps only the near end of the depth model and makes the field's own
    /// depth sort a no-op.
    private func word(_ term: String, at center: CGPoint, rank: Int = 0) -> PlacedWord {
        PlacedWord(term: term, count: 100 - rank, center: center, fontSize: 20,
                   colorIndex: rank, rotationDegrees: 0)
    }
}
