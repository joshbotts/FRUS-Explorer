// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ChartScrubRange

/// Turns an in-chart scrubber drag into a year range (#306).
///
/// Pure arithmetic, deliberately separated from the view: `commitScrub` lives on a SwiftUI `View`
/// where no test can call it, and three sessions of mutation sweeps in this area have all ended
/// the same way — the rule that mattered was the one no test could reach.
///
/// Version history:
///   1.0 — Session 2026-08-10: #306 (F-9)
enum ChartScrubRange {

    /// The corpus's first year — FRUS begins with the 1861 volume, and it is the lower bound the
    /// year-range control resets to.
    static let corpusFirstYear = 1861

    /// Resolves a scrubber selection to the year range it should apply.
    ///
    /// - Parameters:
    ///   - selection: The drag's span in the chart's own x units.
    ///   - decadeStride: `true` when the chart plots decade **starts** (1950, 1960, …) rather than
    ///     individual years.
    ///   - corpusMaxYear: The newest year the corpus covers; the upper clamp.
    /// - Returns: The range to apply, or `nil` when it would not change anything.
    ///
    /// Three rules, each of which is a way to get this quietly wrong:
    ///
    /// 1. **A decade selection covers ten years.** On the By Decade axis a drag from 1950 to 1960
    ///    means 1950–1969. Committing the raw upper bound drops the last nine years of the span
    ///    the user actually drew, and the chart would redraw slightly narrower than the gesture.
    /// 2. **The bounds are clamped to the corpus.** A drag can end past the plotted data at either
    ///    edge; an out-of-corpus bound yields an empty chart whose only escape is Reset.
    /// A right-to-left drag needs no handling and gets none: `chartXSelection(range:)` hands back
    /// a `ClosedRange`, which cannot hold `lower > upper` — constructing one traps. An earlier
    /// version of this ordered the bounds defensively and documented the framework as reporting
    /// them "as drawn"; the test written to prove it crashed on its own literal, which is how the
    /// claim was found to be false rather than merely redundant.
    ///
    /// A single-unit drag is honoured, not discarded: selecting one year is a legitimate
    /// narrowing, and it is what a tap-like drag produces.
    static func resolve(
        selection: ClosedRange<Int>,
        decadeStride: Bool,
        corpusMaxYear: Int
    ) -> ClosedRange<Int>? {
        let expandedEnd = decadeStride ? selection.upperBound + 9 : selection.upperBound
        guard corpusMaxYear >= corpusFirstYear else { return nil }
        let start = max(corpusFirstYear, min(selection.lowerBound, corpusMaxYear))
        let end = min(corpusMaxYear, max(expandedEnd, start))
        return start...end
    }
}
