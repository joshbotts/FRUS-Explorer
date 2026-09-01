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

    // MARK: - The splash's own geometry

    /// The composition guard the plan asks for: the **real** identity zone, at phone width, over a
    /// full drift period.
    ///
    /// It drives `LaunchSplashView.identityZone` and `WordCloudBackdropView.fillFactor` rather than
    /// restating their numbers, so a change to either is caught here instead of agreeing with a
    /// copy of itself. Words are placed where the packer would put them — outside the zone — and
    /// the assertion is that drift never leaves one sitting on the wordmark.
    @Test("No word settles on the identity block over a full drift period")
    func nothingSettlesOnTheIdentityBlock() {
        let size = phone
        let zone = LaunchSplashView.identityZone(in: size)
        let fill = WordCloudBackdropView.fillFactor(for: size)
        #expect(fill > 1, "the splash must be a full-bleed surface for this test to mean anything")

        // **Above and below only, and that is a fact about the phone rather than a shortcut.**
        // The identity block is 340 pt wide on a 393 pt screen, so it leaves 26.5 pt a side —
        // narrower than a single word's half-width at this size. The packer cannot place a word
        // beside it, which is also why every escape from this zone is a vertical one.
        #expect(min(zone.minX, size.width - zone.maxX) < 30,
                "the zone stopped spanning the width; this fixture needs side words again")
        let placed = [
            word("diplomacy", at: CGPoint(x: size.width / 2, y: zone.minY - 14)),
            word("telegram", at: CGPoint(x: size.width / 3, y: zone.maxY + 14)),
            word("memorandum", at: CGPoint(x: size.width * 2 / 3, y: zone.minY - 18)),
            word("aide", at: CGPoint(x: size.width / 2, y: zone.maxY + 18)),
        ]
        let field = WordCloudDriftField(placed: placed,
                                        rankCeiling: WordCloudBackdropView.rankCeiling,
                                        exclusionZones: [zone], canvas: size, fill: fill)
        #expect(field.bleed > 0, "fill > 1 must produce a bleed for the push path to matter")

        for particle in field.particles {
            for step in 0..<1_200 {
                let state = WordCloudDriftField.state(of: particle, at: Double(step) / 20,
                                                      in: size,
                                                      avoiding: field.exclusionZones,
                                                      bleed: field.bleed)
                let box = CGRect(x: state.position.x - particle.halfSize.width * state.scale,
                                 y: state.position.y - particle.halfSize.height * state.scale,
                                 width: particle.halfSize.width * state.scale * 2,
                                 height: particle.halfSize.height * state.scale * 2)
                #expect(!box.intersects(zone),
                        "\(particle.term) settled on the identity block at step \(step)")
                if box.intersects(zone) { return }
            }
        }
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
        let call = String(rest[..<end.lowerBound])
        #expect(call.contains("drift: true"), "the splash stopped drifting:\n\(call)")
        #expect(call.contains("lensSeed: 0"), "M-5's seeded lens was lost")
    }

    // MARK: - Helpers

    private func word(_ term: String, at center: CGPoint) -> PlacedWord {
        PlacedWord(term: term, count: 100, center: center, fontSize: 20,
                   colorIndex: 0, rotationDegrees: 0)
    }
}
