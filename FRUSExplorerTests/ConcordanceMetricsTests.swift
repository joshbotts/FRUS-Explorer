// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Testing
@testable import FRUSExplorer

/// The concordance's width rule (UI review P-3).
///
/// ## What is worth testing
/// Not the arithmetic — that is one multiplication. What matters is the pair of properties the
/// view's own header makes non-negotiable:
///
/// 1. **The geometry does not differ between platforms.** The header warns that "a concordance
///    whose columns differ between platforms is a concordance that cannot be compared across
///    them", so the rule must produce the *same* table width for the same radius everywhere, and
///    vary only whether the viewport scrolls to reach it.
/// 2. **A wide container does not gain a scroll gesture.** A Mac already fits the natural width;
///    if the rule said otherwise it would add a stray horizontal scroll to a window that needs
///    none.
///
/// Version history:
///   1.0 — P-3
@Suite("Concordance metrics")
struct ConcordanceMetricsTests {

    /// The radius `SearchService.concordance` builds lines with.
    private let shippedRadius = 60

    @Test("a phone needs to scroll; the content it would reach already exists")
    func phoneScrolls() {
        // 390pt is an iPhone; the finding measured ~15–18 characters per column there against the
        // 60 the line actually carries.
        #expect(ConcordanceMetrics.needsHorizontalScroll(radius: shippedRadius, available: 390))
        #expect(ConcordanceMetrics.tableWidth(radius: shippedRadius, available: 390)
                > 390, "the table must be wider than the phone, or nothing was gained")
    }

    @Test("a Mac window does not gain a scroll it does not need")
    func wideDoesNotScroll() {
        // The Search window opens at 820pt and the natural width for a 60-character radius is
        // under that, so the Mac keeps exactly today's layout — no scroll view, no behaviour
        // change. If this ever flips, the Mac silently gains a horizontal scroll gesture.
        #expect(!ConcordanceMetrics.needsHorizontalScroll(radius: shippedRadius, available: 1_100))
        #expect(ConcordanceMetrics.tableWidth(radius: shippedRadius, available: 1_100) == 1_100,
                "a container wider than the natural width must fill, not float in dead space")
    }

    @Test("the same radius yields the same table width regardless of container")
    func geometryIsPlatformIndependent() {
        // The header's contract, stated as a test: two concordances built with the same radius are
        // laid out identically wherever they are scrolled to. Only the VIEWPORT differs.
        let phone = ConcordanceMetrics.tableWidth(radius: shippedRadius, available: 390)
        let pad = ConcordanceMetrics.tableWidth(radius: shippedRadius, available: 700)
        #expect(phone == pad,
                "a phone and a narrow iPad must lay the columns out at the same width — otherwise the two cannot be compared, which is the thing this view says it exists for")
        #expect(phone == ConcordanceMetrics.naturalWidth(radius: shippedRadius))
    }

    @Test("more context means a wider table, monotonically")
    func widthTracksRadius() {
        var previous = CGFloat(0)
        for radius in [10, 30, 60, 120] {
            let width = ConcordanceMetrics.naturalWidth(radius: radius)
            #expect(width > previous, "radius \(radius) must be wider than the one before it")
            previous = width
        }
    }

    @Test("a zero or unmeasured container never claims to need scrolling")
    func degenerateContainer() {
        // First layout passes report 0. Reporting "needs scrolling" there would build the scroll
        // path before any width is known, and the view would flip arrangement on the next frame.
        #expect(!ConcordanceMetrics.needsHorizontalScroll(radius: shippedRadius, available: 0))
        #expect(!ConcordanceMetrics.needsHorizontalScroll(radius: shippedRadius, available: -50))
    }
}
