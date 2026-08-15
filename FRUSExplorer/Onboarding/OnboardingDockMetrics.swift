// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics

// MARK: - OnboardingDockMetrics

/// How wide the onboarding dock stack is, given the space it was offered (UI review F-5).
///
/// ## Why this is a function and not two `.frame` calls
/// The width is needed in **two** places that must agree: the stack's own `.frame(maxWidth:)`,
/// and the exclusion rect `OnboardingView.dockExclusionZone` hands the word-cloud backdrop so it
/// keeps words out from under the dock. Those two were already a matched pair before the cap —
/// both were the full screen — and the cap is exactly the change that could silently unmatch
/// them. If the exclusion rect stays full-width while the dock narrows, the backdrop refuses to
/// place words across a band the dock does not occupy: on a 13-inch iPad that is most of the
/// screen reserved for nothing.
///
/// The comment on `dockExclusionZone` records that its height was once a hardcoded guess, and
/// that O-5 caught it drifting from the real dock at an accessibility text size. This is the same
/// failure in the width axis, and the fix is the same one: derive both from one rule.
///
/// ## The rule
/// Take the offered width, up to `FRUSTheme.onboardingDockMaxWidth`. On macOS there is no cap —
/// the window is already pinned at 560×540 — so the offered width is returned unchanged and the
/// dock keeps filling it.
///
/// Version history:
///   1.0 — CW-10 (UI review F-5): extracted so the frame and the exclusion zone cannot disagree
enum OnboardingDockMetrics {

    /// The dock stack's width inside a container of the given width.
    ///
    /// - Parameter containerWidth: The width available to the dock — the screen or window.
    /// - Returns: The width the dock will actually occupy, never more than the container.
    static func dockWidth(forContainerWidth containerWidth: CGFloat) -> CGFloat {
        // A negative or zero proposal reaches here on the first layout pass of some containers;
        // clamping at zero keeps the derived exclusion rect valid rather than inside-out.
        guard containerWidth > 0 else { return 0 }
        #if os(macOS)
        return containerWidth
        #else
        return min(containerWidth, FRUSTheme.onboardingDockMaxWidth)
        #endif
    }
}
