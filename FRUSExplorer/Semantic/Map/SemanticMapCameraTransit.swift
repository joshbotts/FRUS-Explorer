// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SemanticMapCameraTransit

/// One camera move, as a function of time — the establishing zoom a region focus performs instead
/// of teleporting (visual-marketing plan §3.2, M-1).
///
/// A named type with its own test, as that row requires, because the interesting part is not the
/// wiring but the *curve*, and a curve buried in a view body is a curve nobody can check.
///
/// ## `halfExtent` moves in LOG space, and that is the whole design
///
/// Zoom is multiplicative: going from the whole map (`halfExtent` 32,768) to a region (1,200) is
/// not a subtraction, it is a division by ~27. Interpolate it linearly and the first half of the
/// move covers 94% of the *numeric* distance while covering barely a third of the *visible* zoom —
/// the map appears to hurtle inward and then crawl. In log space the ratio changes at a constant
/// rate, which is what reads as a steady approach. The midpoint of a log interpolation is the
/// GEOMETRIC mean, and `midpointIsTheGeometricMean` pins exactly that: it is the one assertion that
/// tells this curve apart from a linear one.
///
/// ## The centre moves linearly, and that is a stated approximation
///
/// The principled answer for simultaneous pan and zoom is Van Wijk and Nuij's optimal path, which
/// keeps the *perceived* velocity constant by arcing the camera outward as it travels. It is not
/// used here: the two moves this drives are short (a region focus starts from a view that already
/// contains the target), the arc is invisible at that range, and an unfamiliar closed form nobody
/// can check is worse than a plain lerp that says it is a plain lerp. Revisit if a transit is ever
/// asked to cross the map.
///
/// ## Landing exactly
///
/// `camera(at: 1)` returns `to` by identity rather than by arithmetic, so the property holds for
/// every pair of cameras rather than for the ones anyone happened to try. A transit whose last
/// frame is 1,200.0001 would leave the model's camera one float from the destination
/// `SemanticMapRevealTests` asserts, and every caller would then need a second write to correct it.
///
/// **Measured, and stated because the obvious reading is stronger than the truth:** at
/// `fraction == 1` the interpolation *also* lands exactly for the two moves this app performs —
/// `pow(ratio, 1)` is the ratio, and the products round back to the endpoint in `Float`. So
/// mutating the guard from `>= 1` to `> 1` does **not** fail the suite. The guard is kept because
/// it makes the guarantee unconditional and costs a comparison, not because a test proves it
/// necessary. Do not read the green suite as evidence that removing it is safe.
///
/// Version history:
///   1.0 — visual-marketing plan §3.2 M-1: initial implementation
struct SemanticMapCameraTransit: Equatable, Sendable {

    /// Where the camera starts.
    let from: SemanticMapCamera
    /// Where it lands.
    let to: SemanticMapCamera

    /// Creates a transit.
    /// - Parameters:
    ///   - from: The camera at the start.
    ///   - to: The camera at the end.
    init(from: SemanticMapCamera, to: SemanticMapCamera) {
        self.from = from
        self.to = to
    }

    /// Whether this move is worth animating at all.
    ///
    /// A transit between two cameras that are already equal is a run of identical frames: the
    /// caller should apply `to` and be done. Also false when either half-extent is non-positive,
    /// which has no logarithm — a defensive case, since `SemanticMapCamera` is never built that way
    /// by the app, but one where the alternative is a `NaN` camera and a blank map.
    var isWorthAnimating: Bool {
        guard from.halfExtent > 0, to.halfExtent > 0 else { return false }
        return from != to
    }

    /// The camera `fraction` of the way through the move.
    ///
    /// - Parameter fraction: 0 at the start, 1 at the end. Values outside are clamped, so a caller
    ///   that overshoots its clock by a frame lands on the destination rather than past it.
    /// - Returns: The interpolated camera; `from` at 0 and `to` at 1, both by identity.
    func camera(at fraction: Double) -> SemanticMapCamera {
        guard isWorthAnimating else { return to }
        if fraction <= 0 { return from }
        if fraction >= 1 { return to }

        let t = Self.eased(fraction)
        let centre = SIMD2<Float>(
            from.centre.x + (to.centre.x - from.centre.x) * Float(t),
            from.centre.y + (to.centre.y - from.centre.y) * Float(t))
        // The log interpolation, written as `from · (to/from)^t` rather than
        // `exp(lerp(log a, log b))` — the same value, one fewer transcendental, and it reads as
        // what it is: a constant-ratio approach.
        let ratio = Double(to.halfExtent) / Double(from.halfExtent)
        let halfExtent = Double(from.halfExtent) * pow(ratio, t)
        return SemanticMapCamera(centre: centre, halfExtent: Float(halfExtent))
    }

    /// Smoothstep — a cubic ease-in-out, so the move starts and ends at rest.
    ///
    /// Deliberately not a spring or an overshoot: the destination of a region focus is a *claim*
    /// about where a region is, and a camera that sails past it and comes back says the map moved
    /// when it did not.
    static func eased(_ fraction: Double) -> Double {
        let t = min(max(fraction, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
