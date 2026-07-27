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

import SwiftUI

/// The drifting word cloud, drawn as one `Canvas` of pre-resolved symbols.
///
/// ## Why a Canvas, and why symbols specifically
/// The static backdrop is 25 SwiftUI `Text` views that do not move: SwiftUI lays them out
/// once and the compositor re-composites them for free, so its per-frame cost is close to
/// zero. Animating position and size continuously changes that completely — every frame
/// becomes a layout pass over every word.
///
/// Three ways to draw text in a `Canvas` were measured on Apple Silicon at 500 particles,
/// and they are not close:
///
/// | approach | µs per particle per frame |
/// |---|---|
/// | `context.draw(Text(...))` — what every existing Canvas in this repo does | ~29 |
/// | `context.draw(resolvedText)` — resolved once per frame, drawn many times | ~3.6 |
/// | `context.draw(resolvedSymbol)` — this file | **~0.21** |
///
/// The inline form re-shapes the text on *every call, every frame*; holding the font size
/// constant barely helps (~20 µs), so it is not merely that varying sizes force reshaping.
/// Only `ResolvedSymbol` is a fully-baked display list. At the ~140× ratio the choice makes
/// the difference between roughly 0.07 ms and 1.5 ms per frame for this cloud — the
/// difference between a rounding error and a fifth of the whole budget on a surface that
/// already has none to spare.
///
/// ## Resolve at the ceiling, scale down
/// `ResolvedSymbol` is resolution-*independent* — a symbol resolved at 3 pt and drawn
/// through a 40× scale is pixel-for-pixel as crisp as text set natively at 120 pt, so
/// scaling up does not blur. But its **layout metrics are frozen at resolve time**, which
/// makes the small-and-magnified version measurably wider than the native one. So each
/// symbol is resolved at the largest size its particle can ever reach and the renderer only
/// ever scales down.
///
/// ## Everything is a function of the clock
/// There is no animation state. The lens cycle, the crossfade, and every particle's
/// position, scale and opacity are computed from `context.date`. A dropped frame therefore
/// cannot desynchronise anything, and Reduce Motion is one substitution — pin the clock —
/// rather than a second code path.
///
/// ## What the closure may touch
/// Only the snapshot passed into it. `CrossReferenceGraphView` already records the rule and
/// the reason ("so Observation tracking stays in body"); at 120 Hz it stops being style. In
/// particular `BundledCloudVectors.polarity(of:inScope:lens:)` is a linear scan of an
/// 865-entry vocabulary and is resolved into the snapshot's colours **once**, in `body`.
/// Called per word per frame it would be ~2.6 million string comparisons a second.
///
/// Version history:
///   1.0 — P-1: initial implementation
struct WordCloudDriftCanvas: View {

    /// Everything the renderer may read, resolved in `body` and immutable thereafter.
    struct Snapshot: Equatable {

        /// One lens's field of particles.
        struct Layer: Equatable {
            let lens: WordCloudLens
            let field: WordCloudDriftField
            /// Colour per term, resolved once — never in the render closure.
            let colors: [String: Color]
            /// Font size to resolve each symbol at: the particle's ceiling.
            let symbolFontSizes: [String: CGFloat]

            static func == (a: Layer, b: Layer) -> Bool {
                a.lens == b.lens && a.field.particles.map(\.id) == b.field.particles.map(\.id)
            }
        }

        let layers: [Layer]
        /// The canvas the particles were packed for. A different size means a new snapshot.
        let size: CGSize

        static func == (a: Snapshot, b: Snapshot) -> Bool {
            a.size == b.size && a.layers == b.layers
        }
    }

    let snapshot: Snapshot

    /// Surface opacity multiplier — `FRUSTheme.cloudDim*`.
    let dim: Double

    /// Frozen when true: the field is drawn at its rest pose and never ticks.
    let reduceMotion: Bool

    var body: some View {
        // NOT `paused:`. Reduce Motion freezes the drift, not the lens rotation — the house
        // rule is to simplify a transition, not to remove it, and the static renderer keeps
        // cycling lenses under Reduce Motion too (it just swaps scale-and-stagger for a
        // plain fade). Pausing the schedule outright would pin one lens forever and quietly
        // take three quarters of the vocabulary away from exactly the users least likely to
        // be shown it again elsewhere.
        //
        // Instead the schedule slows to a rate that can still carry a 1.15 s crossfade, and
        // the *motion* clock is pinned inside the renderer.
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 6.0 : nil)) { context in
            WordCloudDriftCanvasFrame(snapshot: snapshot, dim: dim,
                                      reduceMotion: reduceMotion, date: context.date)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One frame of the drift canvas, at an explicit instant.
///
/// Split from the `TimelineView` on purpose: with the clock as a parameter rather than
/// ambient, a frame is a pure function of `(snapshot, date)` and can be rendered
/// off-screen. `WordCloudDriftRenderTests` uses that to answer the one question the motion
/// tests cannot — *does anything actually draw?*
///
/// That question is not idle. `Canvas`'s symbol lookup keys on the tag's **static type** as
/// well as its value, so a mismatch between the type used at `.tag(_:)` and the one passed
/// to `resolveSymbol(id:)` returns nil for every particle and renders a completely empty
/// canvas — no crash, no warning, no log. Against a `.bar` background during indexing that
/// is indistinguishable from "the cloud has not loaded yet".
struct WordCloudDriftCanvasFrame: View {

    let snapshot: WordCloudDriftCanvas.Snapshot
    let dim: Double
    let reduceMotion: Bool
    let date: Date

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { ctx, size in
            let started = CFAbsoluteTimeGetCurrent()
            draw(into: &ctx, size: size)
            DrawCostMeter.record(microseconds: (CFAbsoluteTimeGetCurrent() - started) * 1_000_000)
        } symbols: {
            symbols
        }
    }

    // MARK: - Symbols

    /// One view per (lens, term), across **all** lenses.
    ///
    /// Deliberately not just the visible lens. SwiftUI stores a rendered version of each
    /// child here and hands them to the renderer; declaring all four lenses up front means
    /// `body` never has to re-evaluate when the lens changes, so the lens cycle costs
    /// nothing beyond the arithmetic in the render closure. The cost is ~100 tiny retained
    /// views, paid once.
    @ViewBuilder
    private var symbols: some View {
        ForEach(snapshot.layers, id: \.lens) { layer in
            ForEach(layer.field.particles) { particle in
                Text(particle.term)
                    .font(.system(size: layer.symbolFontSizes[particle.term] ?? particle.baseFontSize,
                                  weight: .semibold, design: .serif))
                    .foregroundStyle(layer.colors[particle.term] ?? .primary)
                    .tag(WordCloudDriftField.SymbolKey(lens: layer.lens, term: particle.term))
            }
        }
    }

    // MARK: - Rendering

    private func draw(into ctx: inout GraphicsContext, size: CGSize) {
        guard !snapshot.layers.isEmpty else { return }

        // Two clocks, deliberately.
        //
        // The MOTION clock is pinned to 0 under Reduce Motion — pinned, not paused, because
        // a paused schedule freezes whatever mid-drift pose happened to be on screen when
        // the setting was read, which looks like a rendering fault rather than a still.
        //
        // The CYCLE clock always runs, so lenses keep rotating. Conflating the two was a
        // real bug in the first draft: `cycle(at: 0, layerCount: 4)` returns
        // `outgoing: 3, progress: 0`, so pinning the cycle clock to zero drew layer 3 —
        // sentiment — at full opacity, forever, and a Reduce Motion user would have seen
        // exactly one of the four lenses and no indication the others existed.
        let motionTime = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
        let cycleTime = date.timeIntervalSinceReferenceDate

        let cycle = WordCloudDriftCanvas.cycle(at: cycleTime, layerCount: snapshot.layers.count)
        drawLayer(snapshot.layers[cycle.outgoing], opacity: 1 - cycle.progress,
                  into: &ctx, size: size, time: motionTime)
        if cycle.progress > 0, cycle.incoming != cycle.outgoing {
            drawLayer(snapshot.layers[cycle.incoming], opacity: cycle.progress,
                      into: &ctx, size: size, time: motionTime)
        }
    }

    private func drawLayer(_ layer: WordCloudDriftCanvas.Snapshot.Layer, opacity: Double,
                           into ctx: inout GraphicsContext, size: CGSize, time: Double) {
        guard opacity > 0.001 else { return }
        // Far to near: `WordCloudDriftField` already ordered them, so this is a plain loop
        // and the painter's algorithm falls out of it.
        for particle in layer.field.particles {
            guard let symbol = ctx.resolveSymbol(
                id: WordCloudDriftField.SymbolKey(lens: layer.lens, term: particle.term)
            ) else { continue }

            let state = WordCloudDriftField.state(of: particle, at: time, in: size)

            // A per-particle context COPY, never `drawLayer`. `drawLayer` opens a real
            // transparency group — an offscreen buffer per particle — which at 25 particles
            // × 120 Hz is 3000 offscreen passes a second. Copying the value and setting
            // `opacity` is the house idiom and is free.
            var particleContext = ctx
            particleContext.opacity = state.opacity * opacity * dim
            particleContext.translateBy(x: state.position.x, y: state.position.y)
            // Only ever <= 1: symbols are resolved at the ceiling, so this never magnifies.
            let downscale = state.scale / WordCloudDriftField.maximumScale
            particleContext.scaleBy(x: downscale, y: downscale)
            if particle.rotationDegrees != 0 {
                particleContext.rotate(by: .degrees(particle.rotationDegrees))
            }
            // `at:` with a transform, never `draw(_:in: rect)` — drawing into a rect is a
            // non-uniform affine stretch, not a re-layout, so it visibly squashes glyphs.
            particleContext.draw(symbol, at: .zero, anchor: .center)
        }
    }

}

extension WordCloudDriftCanvas {

    /// Which lenses are showing and how far the crossfade between them has run.
    ///
    /// Derived from absolute time so it matches the chip driver exactly without either
    /// having to tell the other anything.
    static func cycle(at time: Double, layerCount: Int) -> (outgoing: Int, incoming: Int, progress: Double) {
        guard layerCount > 1 else { return (0, 0, 0) }
        let cadence = FRUSTheme.cloudLensCadence
        let phase = time / cadence
        let index = Int(phase.rounded(.down))
        let within = (phase - phase.rounded(.down)) * cadence
        // The crossfade occupies the head of each hold, matching the Text renderer's
        // incoming-transform duration so the two surfaces feel like one animation.
        let progress = min(1, max(0, within / FRUSTheme.cloudTransformDuration))
        let incoming = ((index % layerCount) + layerCount) % layerCount
        let outgoing = ((index - 1) % layerCount + layerCount) % layerCount
        return (outgoing: outgoing, incoming: incoming, progress: progress)
    }
}
