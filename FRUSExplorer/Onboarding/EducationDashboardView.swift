// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - EducationDashboard

/// Identifies a live SwiftUI dashboard rendered in place of a Research Guide
/// page's static prose `sections`.
///
/// When an `EducationPage` carries a non-`nil` `dashboard`, both platform
/// content renderers (`macContentArea` on macOS, `iOSPageView` on iOS/iPadOS)
/// substitute an `EducationDashboardView` for the usual prose section stack —
/// the additive content-model extension introduced by Analytics Prep-A so the
/// "About the Series" dashboards (SA-1…SA-3) can live inside the guide.
///
/// SA-1b ships the first real dashboard, `.seriesProduction`. The remaining
/// Series Analytics sessions (SA-2/SA-3) extend this enum and the `switch` in
/// `EducationDashboardView` — the `switch` is deliberately kept exhaustive (no
/// `default`) so a new case must add its arm.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation; `.placeholder` only
///   1.1 — Analytics SA-1b: replaced `.placeholder` with the real
///          `.seriesProduction` case
enum EducationDashboard: String, Hashable {
    /// The live "Production & Timeliness" dashboard (SA-1b): four Swift Charts
    /// derived from the bundled `manifest.json` — publication lag, volumes per
    /// print year, coverage spans, and cumulative growth — that render offline,
    /// with zero index, mid-onboarding. See `SeriesProductionDashboard`.
    case seriesProduction
}

// MARK: - EducationDashboardView

/// The single enum-to-view mapping site that renders the concrete dashboard for
/// an `EducationDashboard` value.
///
/// This is deliberately the one extension point the Series Analytics sessions
/// (SA-1…SA-3) grow: each new `EducationDashboard` case adds one `switch` arm
/// here pointing at its own dashboard view. The `switch` is exhaustive (no
/// `default`), so a new case is a compile error until its arm is added. Keeping
/// the mapping centralised means the two content renderers in
/// `IndexingEducationView` need no knowledge of individual dashboards — they
/// only branch on `page.dashboard != nil`.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation; renders `.placeholder`
///   1.1 — Analytics SA-1b: renders `.seriesProduction`
struct EducationDashboardView: View {

    /// Which dashboard to render.
    let dashboard: EducationDashboard

    var body: some View {
        switch dashboard {
        case .seriesProduction:
            SeriesProductionDashboard()
        }
    }
}
