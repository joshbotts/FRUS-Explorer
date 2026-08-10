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

// MARK: - ArchivalLifecycleAxisTests

/// The lifecycle chart's x-axis domain.
///
/// Reported from the app: the axis started at 0. Swift Charts infers a numeric domain from the
/// marks when none is given, and a `BarMark` anchors that domain at **zero** — so a chart of
/// coverage years rendered 0–1990 with every bar crushed against the right edge. Coverage years
/// are dates, not magnitudes: nothing is measured *from* zero, so zero is not a meaningful origin.
///
/// Version history:
///   1.0 — Session 2026-08-10: lifecycle x-axis fix
@Suite("Archival lifecycle axis")
struct ArchivalLifecycleAxisTests {

    private func span(_ first: Int, _ last: Int, id: String = "c") -> ArchivalLifecycleSpan {
        ArchivalLifecycleSpan(id: id, label: id, name: id, category: .stateDepartment,
                              firstYear: first, lastYear: last, volumeCount: 1)
    }

    @Test("The axis opens at 1860, not at zero")
    func opensAtTheSeriesStart() {
        let domain = ArchivalLifecycleAxis.domain(for: [span(1947, 1968), span(1955, 1972)])
        #expect(domain?.lowerBound == 1860, """
            got \(String(describing: domain)). Zero is not an origin for a date axis, and an axis \
            that starts there crushes every bar against the right edge.
            """)
        #expect(domain?.upperBound == 1972)
    }

    @Test("A span starting before 1860 widens the axis rather than being cut off")
    func floorIsADefaultNotAClamp() {
        // FRUS begins with the 1861 volume, but a collection's coverage can predate it. Clamping
        // would hide the very records whose early coverage makes them interesting — and silently,
        // since the bar would simply start at the edge.
        let domain = ArchivalLifecycleAxis.domain(for: [span(1823, 1901)])
        #expect(domain?.lowerBound == 1823, "got \(String(describing: domain))")
        #expect(domain?.upperBound == 1901)
    }

    @Test("A single-year span still has an axis with extent")
    func singleYearSpan() {
        // A zero-width domain renders as an axis with no extent at all.
        let domain = ArchivalLifecycleAxis.domain(for: [span(1950, 1950)])
        #expect(domain != nil)
        #expect((domain?.upperBound ?? 0) > (domain?.lowerBound ?? 0))
    }

    @Test("No spans yields no domain")
    func emptyYieldsNil() {
        // The card is not rendered when there is nothing to plot; inventing a range here would
        // draw an empty axis over no data.
        #expect(ArchivalLifecycleAxis.domain(for: []) == nil)
    }

    @Test("The domain covers every span, not just the first")
    func coversAllSpans() {
        let domain = ArchivalLifecycleAxis.domain(for: [
            span(1900, 1910, id: "a"), span(1880, 1885, id: "b"), span(1990, 1999, id: "c"),
        ])
        #expect(domain?.lowerBound == 1860, "1880 is later than the floor, so the floor holds")
        #expect(domain?.upperBound == 1999, "a bar past the end would be clipped out of view")
    }
}
