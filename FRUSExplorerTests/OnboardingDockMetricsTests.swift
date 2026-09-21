// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import SwiftUI
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

// MARK: - OnboardingIdentityPlacement

/// The identity block on the welcome step is shown by MEASUREMENT against the dock, not by step.
///
/// The fixtures below are real geometries: `LaunchSplashView.identityZone` at an iPhone 17's
/// safe-area box, against a dock of the height the welcome step measures at the default size and
/// one of the height it reaches at the largest accessibility size. The rule must answer
/// differently to the two, or it is a step check wearing a measurement's clothes.
///
/// Version history:
///   1.0 — the app icon in the launch → splash → onboarding handover
@Suite("Onboarding identity placement")
@MainActor
struct OnboardingIdentityPlacementTests {

    /// iPhone 17's safe-area box in portrait, and its insets.
    private let phone = CGSize(width: 402, height: 874 - 62 - 34)
    private let insets = EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)

    /// The dock rect as `OnboardingView.dockExclusionZone` builds it, translated by the top inset
    /// into the identity zone's full-bleed space.
    private func dock(height: CGFloat) -> CGRect {
        CGRect(x: 0, y: insets.top + phone.height - height, width: phone.width, height: height)
    }

    @Test("At the default type size the welcome dock clears the block and the block is shown")
    func defaultSizeShowsTheBlock() {
        let zone = LaunchSplashView.identityZone(in: phone, safeAreaInsets: insets)
        // Measured: page dots + title + two-line body + a large button + 28 pt bottom inset.
        #expect(OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: true, identityZone: zone, dockZone: dock(height: 230)))
    }

    @Test("At an accessibility size the dock reaches the block and the block hides")
    func accessibilitySizeHidesTheBlock() {
        let zone = LaunchSplashView.identityZone(in: phone, safeAreaInsets: insets)
        // At AX5 the body wraps to six lines and the button doubles; the dock runs to ~430 pt.
        #expect(!OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: true, identityZone: zone, dockZone: dock(height: 430)))
    }

    @Test("The gap is a floor, exactly")
    func gapIsExact() {
        let zone = CGRect(x: 0, y: 100, width: 300, height: 200)
        let gap = OnboardingIdentityPlacement.minimumGap
        func dockAt(_ top: CGFloat) -> CGRect { CGRect(x: 0, y: top, width: 300, height: 100) }
        #expect(OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: true, identityZone: zone, dockZone: dockAt(zone.maxY + gap)))
        #expect(!OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: true, identityZone: zone, dockZone: dockAt(zone.maxY + gap - 1)))
    }

    @Test("Only the welcome step carries the block, however much room there is")
    func laterStepsNeverShowIt() {
        let zone = CGRect(x: 0, y: 100, width: 300, height: 200)
        let farDock = CGRect(x: 0, y: 900, width: 300, height: 100)
        #expect(OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: true, identityZone: zone, dockZone: farDock))
        #expect(!OnboardingIdentityPlacement.showsIdentity(
            isWelcomeStep: false, identityZone: zone, dockZone: farDock))
    }
}
