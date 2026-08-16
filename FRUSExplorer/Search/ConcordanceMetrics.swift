// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics

// MARK: - ConcordanceMetrics

/// How wide a concordance line has to be for the concordance to be one (UI review P-3).
///
/// ## The finding, and why the fix is a viewport rather than a layout
/// `ConcordanceView`'s own header states the purpose: *"Alignment is the feature. The three
/// columns are fixed-width so the eye can run down the margins."* At 390 pt each context column
/// gets roughly 120 pt — **15 to 18 monospaced characters, two or three words** — before
/// truncation. The repeated-formula scan the view exists for is physically absent on a phone.
///
/// The content is not missing: `SearchService.concordance` builds each line with a **60-character
/// radius** either side, extended outward to a word boundary. So a phone is showing about a
/// quarter of what it already has. That is a viewport problem, not a layout problem.
///
/// The same header supplies the constraint on any remedy: *"a concordance whose columns differ
/// between platforms is a concordance that cannot be compared across them."* A phone-specific
/// arrangement — one side at a time, wrapped lines, a narrower radius — would break exactly that.
/// So the geometry stays identical on every platform and the narrow screen scrolls instead. On a
/// Mac or a wide iPad nothing changes at all, because the natural width already fits.
///
/// ## Why this is a type and not two numbers in a view
/// The width is needed by the layout *and* by the decision of whether to scroll at all, and those
/// two must agree — a table sized for scrolling inside a non-scrolling container clips, and a
/// scrolling container around a table that fits adds a stray scroll gesture to a Mac. One rule
/// serves both, and it is testable without a screen.
///
/// Version history:
///   1.0 — P-3
enum ConcordanceMetrics {

    /// Advance width of one character in the concordance's monospaced caption face.
    ///
    /// A measured approximation, not a promise: `.caption` is ~12 pt and SF Mono advances at
    /// ~0.6 em. It only has to be close — being a few points out changes how much slack sits at
    /// the end of a scroll, never whether the columns align, because every row uses the same
    /// font and the same frame.
    static let characterWidth: CGFloat = 7.2

    /// Points reserved for the match column and the inter-column spacing.
    ///
    /// The match never truncates (it carries `layoutPriority(1)`), so it takes what it needs; this
    /// is the allowance that keeps the two context columns from being squeezed by a long term.
    static let matchAllowance: CGFloat = 140

    /// The width at which a line shows its full context on both sides.
    ///
    /// - Parameter radius: The context radius the lines were built with, in characters.
    /// - Returns: The natural table width in points.
    static func naturalWidth(radius: Int) -> CGFloat {
        // Both sides, plus the match column and spacing. `radius` is characters per side.
        CGFloat(max(0, radius)) * characterWidth * 2 + matchAllowance
    }

    /// The width to lay the table out at, given the space available.
    ///
    /// Never narrower than the container — a table narrower than its viewport would leave the
    /// columns floating in dead space rather than filling it, which is worse than today.
    ///
    /// - Parameters:
    ///   - radius: The context radius the lines were built with.
    ///   - available: The width the container offers.
    /// - Returns: The layout width.
    static func tableWidth(radius: Int, available: CGFloat) -> CGFloat {
        max(available, naturalWidth(radius: radius))
    }

    /// Whether the table needs to scroll horizontally in this container.
    ///
    /// - Parameters:
    ///   - radius: The context radius the lines were built with.
    ///   - available: The width the container offers.
    /// - Returns: `true` when the natural width exceeds the space available.
    static func needsHorizontalScroll(radius: Int, available: CGFloat) -> Bool {
        available > 0 && naturalWidth(radius: radius) > available
    }
}
