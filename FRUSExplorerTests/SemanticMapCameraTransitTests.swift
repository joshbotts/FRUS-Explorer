// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SemanticMapCameraTransitTests

/// The camera transit's curve (visual-marketing plan §3.2, M-1 — "a named type with its own test").
///
/// The wiring is checked by `SemanticMapRevealTests`, which asserts the synchronous contract this
/// must not break. What is checked here is the shape of the move, because a curve is the part that
/// is wrong silently: a linear zoom still starts where it should and ends where it should, and only
/// looks wrong in motion, on a device, to someone who knows what to look for.
///
/// Version history:
///   1.0 — visual-marketing plan §3.2 M-1: initial implementation
@Suite("Semantic map — camera transit")
struct SemanticMapCameraTransitTests {

    private let wide = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: 32_768)
    private let close = SemanticMapCamera(centre: SIMD2<Float>(1_000, -500), halfExtent: 1_200)

    /// A transit must LAND, exactly. A last frame of 1,200.0001 leaves the model's camera one float
    /// from the destination `SemanticMapRevealTests` asserts, and every caller would then need a
    /// second write to correct it — a second write that can drift from the first.
    ///
    /// **What this does NOT prove:** that the `fraction >= 1` guard is required. Mutating it to
    /// `> 1` leaves this test green, because for these values the interpolation lands on the
    /// endpoint anyway. The guard makes the guarantee hold for every pair rather than for the
    /// tried ones; it is insurance, and the type's doc comment says so.
    @Test("The ends are the endpoints, by identity")
    func endsAreExact() {
        let transit = SemanticMapCameraTransit(from: wide, to: close)
        #expect(transit.camera(at: 0) == wide)
        #expect(transit.camera(at: 1) == close)
        // Clamped, so a caller whose clock overshoots by a frame lands rather than sails past.
        #expect(transit.camera(at: 1.4) == close)
        #expect(transit.camera(at: -0.2) == wide)
    }

    /// **The assertion that tells this curve apart from a linear one.**
    ///
    /// Zoom is multiplicative, so the halfway point of a zoom from 32,768 to 1,200 is their
    /// GEOMETRIC mean (~6,270), not their arithmetic mean (~16,984). A linear interpolation is at
    /// 16,984 halfway through — still 14× the destination with half the time gone, which is the
    /// "hurtle inward then crawl" the log space exists to remove.
    @Test("Halfway through a zoom is the geometric mean, not the arithmetic one")
    func midpointIsTheGeometricMean() {
        let transit = SemanticMapCameraTransit(from: wide, to: close)
        let middle = transit.camera(at: 0.5).halfExtent
        let geometric = (Double(wide.halfExtent) * Double(close.halfExtent)).squareRoot()
        let arithmetic = (Double(wide.halfExtent) + Double(close.halfExtent)) / 2
        #expect(abs(Double(middle) - geometric) < 1, "expected ~\(geometric), got \(middle)")
        #expect(abs(Double(middle) - arithmetic) > 1_000,
                "a linear interpolation would sit at ~\(arithmetic)")
    }

    /// The zoom proceeds one way. A curve that reverses reads as the map changing its mind.
    @Test("The zoom is monotonic across the whole move")
    func zoomIsMonotonic() {
        let transit = SemanticMapCameraTransit(from: wide, to: close)
        var previous = Float.greatestFiniteMagnitude
        for step in 0...40 {
            let extent = transit.camera(at: Double(step) / 40).halfExtent
            #expect(extent <= previous, "step \(step): \(extent) rose from \(previous)")
            previous = extent
        }
    }

    /// Smoothstep, so the camera starts and ends at rest rather than cutting into motion.
    @Test("The ease starts and ends at rest, and is symmetric")
    func easingShape() {
        #expect(SemanticMapCameraTransit.eased(0) == 0)
        #expect(SemanticMapCameraTransit.eased(1) == 1)
        #expect(abs(SemanticMapCameraTransit.eased(0.5) - 0.5) < 1e-9)
        // Slow at the ends: the first tenth of the time covers less than a tenth of the distance.
        #expect(SemanticMapCameraTransit.eased(0.1) < 0.1)
        #expect(SemanticMapCameraTransit.eased(0.9) > 0.9)
        // Symmetric about the midpoint.
        #expect(abs(SemanticMapCameraTransit.eased(0.25)
                    + SemanticMapCameraTransit.eased(0.75) - 1) < 1e-9)
    }

    /// The centre travels in a straight line — a stated approximation, pinned so that a change to
    /// it is a decision rather than a drift.
    @Test("The centre interpolates linearly under the ease")
    func centreIsLinearUnderTheEase() {
        let transit = SemanticMapCameraTransit(from: wide, to: close)
        let t = 0.3
        let eased = Float(SemanticMapCameraTransit.eased(t))
        let expectedX = wide.centre.x + (close.centre.x - wide.centre.x) * eased
        #expect(abs(transit.camera(at: t).centre.x - expectedX) < 0.01)
    }

    /// Nothing to animate is not an animation. The caller applies the destination and skips the
    /// task entirely, so an identical move costs no frames at all.
    @Test("An identical or degenerate move is not worth animating")
    func degenerateMoves() {
        #expect(!SemanticMapCameraTransit(from: close, to: close).isWorthAnimating)
        #expect(SemanticMapCameraTransit(from: wide, to: close).isWorthAnimating)
        // A non-positive half-extent has no logarithm; the guard keeps a NaN camera off the map.
        let degenerate = SemanticMapCamera(centre: .zero, halfExtent: 0)
        #expect(!SemanticMapCameraTransit(from: degenerate, to: close).isWorthAnimating)
        #expect(SemanticMapCameraTransit(from: degenerate, to: close).camera(at: 0.5) == close)
    }

    /// A transit outward is the same curve run the other way — the region focus zooms in, but
    /// `frameAll` after one zooms out, and both go through this type.
    @Test("Zooming out is monotonic too")
    func zoomingOutIsMonotonic() {
        let transit = SemanticMapCameraTransit(from: close, to: wide)
        var previous: Float = 0
        for step in 0...40 {
            let extent = transit.camera(at: Double(step) / 40).halfExtent
            #expect(extent >= previous, "step \(step): \(extent) fell from \(previous)")
            previous = extent
        }
    }
}
