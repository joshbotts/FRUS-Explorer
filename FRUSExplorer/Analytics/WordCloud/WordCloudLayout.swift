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
enum WordCloudLayout {

    /// Computes word placements for the given terms within `size`.
    ///
    /// - Parameters:
    ///   - terms: Terms sorted by descending count (as produced by `WordFrequencyService`).
    ///   - size: The canvas size to pack into.
    ///   - maxWords: Hard cap on the number of words placed.
    ///   - minFontSize: Smallest point size (least frequent term).
    ///   - maxFontSize: Largest point size (most frequent term).
    /// - Returns: The successfully placed words. Words that found no free spot are omitted.
    static func place(
        terms: [TermCount],
        in size: CGSize,
        maxWords: Int = 120,
        minFontSize: CGFloat = 13,
        maxFontSize: CGFloat = 64
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
                                    minFontSize: minFontSize, maxFontSize: maxFontSize)
            let estimate = estimatedSize(term: term.term, fontSize: fontSize)

            // March outward along the spiral until a non-colliding slot is found.
            // The horizontal stretch (1.7) favours wider-than-tall clouds, matching
            // typical landscape/portrait card aspect ratios.
            var angle: CGFloat = 0
            let angleStep: CGFloat = 0.35
            let spiralTightness: CGFloat = max(estimate.height, minFontSize) * 0.28
            var slot: CGRect?
            while angle < 60 { // ~9.5 turns; plenty before giving up
                let radius = spiralTightness * angle
                let point = CGPoint(
                    x: center.x + radius * cos(angle) * 1.7,
                    y: center.y + radius * sin(angle)
                )
                let rect = CGRect(
                    x: point.x - estimate.width / 2,
                    y: point.y - estimate.height / 2,
                    width: estimate.width,
                    height: estimate.height
                )
                if bounds.contains(rect),
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
                colorIndex: rank
            ))
            // Pad the occupied rect slightly so neighbours don't touch.
            occupied.append(rect.insetBy(dx: -3, dy: -2))
        }
        return placed
    }

    /// Maps a term count onto a point size using a square-root (area-proportional) scale.
    static func fontSize(
        for count: Int,
        minCount: Int,
        maxCount: Int,
        minFontSize: CGFloat,
        maxFontSize: CGFloat
    ) -> CGFloat {
        guard maxCount > minCount else { return (minFontSize + maxFontSize) / 2 }
        let t = CGFloat(count - minCount) / CGFloat(maxCount - minCount)
        return minFontSize + (maxFontSize - minFontSize) * sqrt(max(0, min(1, t)))
    }

    /// Estimates the rendered bounding box of a term at a given point size.
    ///
    /// Uses an average glyph-advance heuristic (≈0.54 × point size) plus padding —
    /// good enough for collision spacing without a graphics context.
    private static func estimatedSize(term: String, fontSize: CGFloat) -> CGSize {
        let width = CGFloat(term.count) * fontSize * 0.54 + fontSize * 0.4
        let height = fontSize * 1.25
        return CGSize(width: width, height: height)
    }
}
