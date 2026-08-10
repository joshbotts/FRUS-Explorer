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

// MARK: - ChartScrubRangeTests

/// Turning a scrubber drag into a year range (#306).
///
/// Version history:
///   1.0 — Session 2026-08-10: #306 (F-9)
@Suite("Chart scrub range (#306)")
struct ChartScrubRangeTests {

    private let maxYear = 1988

    private func resolve(_ range: ClosedRange<Int>, decade: Bool = false) -> ClosedRange<Int>? {
        ChartScrubRange.resolve(selection: range, decadeStride: decade, corpusMaxYear: maxYear)
    }

    @Test("A year drag applies verbatim")
    func yearDragIsLiteral() {
        #expect(resolve(1947...1962) == 1947...1962)
    }

    @Test("A decade drag covers the whole last decade, not its first year")
    func decadeDragCoversTenYears() {
        // The By Decade chart plots decade STARTS. A drag from 1950 to 1960 means 1950–1969;
        // committing the raw upper bound would drop nine years the user visibly selected, and the
        // chart would redraw narrower than the gesture that produced it.
        #expect(resolve(1950...1960, decade: true) == 1950...1969)
        #expect(resolve(1950...1950, decade: true) == 1950...1959,
                "a single decade bar is that decade, not a single year")
    }

    @Test("A descending drag is not a case the framework can produce")
    func descendingRangeIsImpossibleByConstruction() {
        // Worth pinning as a fact rather than leaving as an assumption: `chartXSelection(range:)`
        // yields a `ClosedRange`, and `1962...1947` TRAPS at construction — so `resolve` never
        // sees an inverted span and does not order its bounds. The first version of this file did
        // order them and documented Swift Charts as reporting the range "as drawn"; the test
        // written to prove that crashed on its own literal.
        //
        // Asserting the invariant the type guarantees keeps the reasoning visible to whoever next
        // wonders why there is no min/max here.
        let asDrawn: ClosedRange<Int> = 1947...1962
        #expect(asDrawn.lowerBound <= asDrawn.upperBound)
        #expect(resolve(asDrawn) == 1947...1962)
    }

    @Test("Bounds are clamped to the corpus at both ends")
    func clampsToCorpus() {
        // A drag can end past the plotted data. An out-of-corpus bound yields an empty chart whose
        // only escape is Reset.
        #expect(resolve(1700...1900) == 1861...1900)
        #expect(resolve(1970...2400) == 1970...maxYear)
        #expect(resolve(1700...2400) == 1861...maxYear)
        // …including a decade expansion that would otherwise overshoot.
        #expect(resolve(1980...1980, decade: true) == 1980...1988,
                "1980+9 = 1989 exceeds the corpus; the end clamps rather than inventing a year")
    }

    @Test("A single-year drag narrows to that year rather than being discarded")
    func singleYearIsHonoured() {
        // This is what a tap-like drag produces, and selecting one year is a legitimate narrowing.
        #expect(resolve(1953...1953) == 1953...1953)
    }

    @Test("A selection entirely past the corpus still yields a usable range")
    func fullyOutOfRangeStillUsable() {
        // Both bounds clamp to the top of the corpus rather than producing start > end.
        let r = resolve(2200...2300)
        #expect(r == maxYear...maxYear, "got \(String(describing: r))")
    }

    @Test("A corpus with no span yields nothing rather than an invalid range")
    func degenerateCorpus() {
        // Defensive: `corpusMaxYear` is derived from indexed data and is 0 before any volume is
        // indexed. `start...end` with end < start traps, so this must refuse instead.
        #expect(ChartScrubRange.resolve(selection: 1950...1960, decadeStride: false,
                                        corpusMaxYear: 0) == nil)
    }
}
