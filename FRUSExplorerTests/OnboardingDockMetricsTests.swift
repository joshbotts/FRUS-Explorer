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

/// The onboarding dock's width rule (UI review F-5).
///
/// The rule is trivial arithmetic; what these tests actually pin is that **one** rule feeds both
/// consumers. The dock's `.frame(maxWidth:)` and the word-cloud backdrop's exclusion rect were a
/// matched pair before the cap — both were the full screen — and capping one without the other is
/// the silent failure: the backdrop would keep refusing to place words across a band the dock no
/// longer occupies, which on a 13-inch iPad is most of the screen and looks like nothing at all
/// went wrong.
///
/// Version history:
///   1.0 — CW-10 (UI review F-5)
@Suite("Onboarding dock metrics")
struct OnboardingDockMetricsTests {

    @Test("a wide iPad is capped")
    func wideIsCapped() {
        // 1366 is the 13-inch iPad's landscape width; 1294 was the measured content width at
        // which the scope picker filled every available point before this cap existed.
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: 1366)
                == FRUSTheme.onboardingDockMaxWidth)
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: 1294)
                == FRUSTheme.onboardingDockMaxWidth)
    }

    @Test("a phone keeps every point it has")
    func narrowIsUnchanged() {
        // An iPhone 17 is 402pt: narrower than the cap, so the dock must still fill the screen.
        // A cap that also shrank the phone would be a regression on the platform that was fine.
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: 402) == 402)
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: 320) == 320)
    }

    @Test("the cap is exactly the boundary, not one point past it")
    func boundaryIsInclusive() {
        let cap = FRUSTheme.onboardingDockMaxWidth
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: cap) == cap)
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: cap - 1) == cap - 1)
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: cap + 1) == cap)
    }

    @Test("a zero or negative proposal yields a valid rect, not an inside-out one")
    func degenerateProposals() {
        // First layout passes of some containers propose 0. The exclusion rect derives its x
        // origin as (container - width) / 2, so a negative width here would place an inverted
        // rect into the backdrop's avoidance list rather than simply excluding nothing.
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: 0) == 0)
        #expect(OnboardingDockMetrics.dockWidth(forContainerWidth: -100) == 0)
    }

    @Test("the dock never exceeds the space it was offered")
    func neverExceedsContainer() {
        for width in stride(from: CGFloat(0), through: 2000, by: 37) {
            let resolved = OnboardingDockMetrics.dockWidth(forContainerWidth: width)
            #expect(resolved <= max(0, width),
                    "dock resolved to \(resolved) inside \(width)")
        }
    }
}
