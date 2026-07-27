// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation

/// A single word positioned within a word-cloud canvas.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct PlacedWord: Identifiable, Sendable {
    /// The (already normalised) term. Doubles as the identity.
    let term: String
    /// Raw occurrence count, used for the accessibility/tooltip label.
    let count: Int
    /// Centre point of the word within the canvas.
    let center: CGPoint
    /// Point size the word is drawn at.
    let fontSize: CGFloat
    /// Index into the view's colour palette (assigned by rank).
    let colorIndex: Int
    /// Rotation in degrees (0 = horizontal, 90 = vertical). Vertical words fill the
    /// space a horizontally-constrained cloud leaves unused, raising density.
    let rotationDegrees: Double

    /// Stable identity for `ForEach`.
    var id: String { term }
}

/// Deterministic Archimedean-spiral packing for word clouds.
///
/// Words are placed largest-first from the centre outward along a spiral, each at
/// the first position where its estimated bounding box collides with neither a
/// previously placed word nor the canvas edge. Font size encodes frequency on a
/// square-root scale so a word's *area* (not its height) is roughly proportional
/// to its count — the perceptually correct mapping for tag clouds.
///
/// The packing is purely geometric (text extents are estimated from point size
/// and character count rather than measured), which keeps it `Sendable`, testable
/// without a graphics context, and identical across light/dark mode.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — O-2: `exclusionZones` / `yCompression` / `sizeExponent` added for the onboarding
///         backdrop, all defaulted to the shipped behaviour and pinned by
///         `WordCloudLayoutRegressionTests`
enum WordCloudLayout {

    /// Computes word placements for the given terms within `size`.
    ///
    /// - Parameters:
    ///   - terms: Terms sorted by descending count (as produced by `WordFrequencyService`).
    ///   - size: The canvas size to pack into.
    ///   - maxWords: Hard cap on the number of words placed.
    ///   - minFontSize: Smallest point size (least frequent term).
    ///   - maxFontSize: Largest point size (most frequent term).
    ///   - spacingScale: Multiplier on spiral tightness and inter-word gap; below 1
    ///     packs denser, above 1 spreads words apart. Drives the density preference.
    ///   - widthFactor: Average glyph-advance ratio (× point size) for text-extent
    ///     estimation; varies with the chosen font design.
    ///   - exclusionZones: Rects no word may overlap — used by the onboarding backdrop to
    ///     keep words out from under fixed UI (the splash identity block, the docked glass
    ///     panel, the lens chip). Empty means no exclusions, the shipped behaviour.
    ///   - yCompression: Multiplier on the spiral's vertical reach. `1` is the shipped
    ///     circular-ish field; the backdrop passes `0.62` for the hand-off's elliptical
    ///     full-bleed field.
    ///   - sizeExponent: Curve applied to the normalised count when mapping to point size.
    ///     `nil` keeps the shipped square-root (area-proportional) scale; the backdrop
    ///     passes `1.45` for the hand-off's steeper contrast. **`nil` rather than `0.5`
    ///     deliberately** — `pow(t, 0.5)` and `sqrt(t)` can differ in the last bit, and a
    ///     one-ulp font-size change can move a word to a different spiral slot.
    /// - Returns: The successfully placed words. Words that found no free spot are omitted.
    ///
    /// Every parameter added for the onboarding backdrop (O-2) defaults to the shipped
    /// behaviour, and `WordCloudLayoutRegressionTests` pins that the existing Word Cloud's
    /// placements are byte-for-byte unchanged.
    static func place(
        terms: [TermCount],
        in size: CGSize,
        maxWords: Int = 180,
        minFontSize: CGFloat = 13,
        maxFontSize: CGFloat = 64,
        spacingScale: CGFloat = 1,
        widthFactor: CGFloat = 0.54,
        exclusionZones: [CGRect] = [],
        yCompression: CGFloat = 1,
        sizeExponent: CGFloat? = nil
    ) -> [PlacedWord] {
        let words = Array(terms.prefix(maxWords))
        guard size.width > 0, size.height > 0,
              let maxCount = words.first?.count, maxCount > 0 else { return [] }
        let minCount = words.last?.count ?? maxCount

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let bounds = CGRect(origin: .zero, size: size)
        var placed: [PlacedWord] = []
        var occupied: [CGRect] = []

        for (rank, term) in words.enumerated() {
            let fontSize = fontSize(for: term.count, minCount: minCount, maxCount: maxCount,
                                    minFontSize: minFontSize, maxFontSize: maxFontSize,
                                    sizeExponent: sizeExponent)
            // Keep the largest words horizontal (most readable); rotate every third
            // of the rest 90° to fill vertical gaps. Rank-based so it's deterministic
            // and always produces some vertical words regardless of the term set.
            let vertical = rank > words.count / 4 && rank % 3 == 1
            var estimate = estimatedSize(term: term.term, fontSize: fontSize, widthFactor: widthFactor)
            if vertical { estimate = CGSize(width: estimate.height, height: estimate.width) }

            // March outward along the spiral until a non-colliding slot is found.
            // The horizontal stretch (1.7) favours wider-than-tall clouds, matching
            // typical landscape/portrait card aspect ratios.
            var angle: CGFloat = 0
            let angleStep: CGFloat = 0.30
            let spiralTightness: CGFloat = max(estimate.height, minFontSize) * 0.22 * spacingScale
            var slot: CGRect?
            while angle < 70 { // ~11 turns; plenty before giving up
                let radius = spiralTightness * angle
                let point = CGPoint(
                    x: center.x + radius * cos(angle) * 1.7,
                    y: center.y + radius * sin(angle) * yCompression
                )
                let rect = CGRect(
                    x: point.x - estimate.width / 2,
                    y: point.y - estimate.height / 2,
                    width: estimate.width,
                    height: estimate.height
                )
                if bounds.contains(rect),
                   !exclusionZones.contains(where: { $0.intersects(rect) }),
                   !occupied.contains(where: { $0.intersects(rect) }) {
                    slot = rect
                    break
                }
                angle += angleStep
            }

            guard let rect = slot else { continue }
            placed.append(PlacedWord(
                term: term.term,
                count: term.count,
                center: CGPoint(x: rect.midX, y: rect.midY),
                fontSize: fontSize,
                colorIndex: rank,
                rotationDegrees: vertical ? 90 : 0
            ))
            // Pad the occupied rect just enough that neighbours don't touch — the gap
            // scales with the density preference (tighter when compact, looser when airy).
            let gap = -1.5 * spacingScale
            occupied.append(rect.insetBy(dx: gap, dy: gap))
        }
        return placed
    }


    /// Maps a term count onto a point size.
    ///
    /// - Parameter sizeExponent: `nil` (the default) uses the square-root,
    ///   area-proportional scale the Word Cloud has always used — a word's *area*, not its
    ///   height, is roughly proportional to its count. A value applies `pow(t, exponent)`
    ///   instead; the onboarding backdrop passes `1.45`, which suppresses the long tail so
    ///   a few terms dominate a full-bleed field.
    static func fontSize(
        for count: Int,
        minCount: Int,
        maxCount: Int,
        minFontSize: CGFloat,
        maxFontSize: CGFloat,
        sizeExponent: CGFloat? = nil
    ) -> CGFloat {
        guard maxCount > minCount else { return (minFontSize + maxFontSize) / 2 }
        let t = max(0, min(1, CGFloat(count - minCount) / CGFloat(maxCount - minCount)))
        let curve = sizeExponent.map { pow(t, $0) } ?? sqrt(t)
        return minFontSize + (maxFontSize - minFontSize) * curve
    }

    /// Estimates the rendered bounding box of a term at a given point size.
    ///
    /// Uses an average glyph-advance heuristic (`widthFactor` × point size, ≈0.54 for
    /// the default font) plus padding — good enough for collision spacing without a
    /// graphics context.
    private static func estimatedSize(term: String, fontSize: CGFloat, widthFactor: CGFloat = 0.54) -> CGSize {
        let width = CGFloat(term.count) * fontSize * widthFactor + fontSize * 0.4
        let height = fontSize * 1.25
        return CGSize(width: width, height: height)
    }
}
