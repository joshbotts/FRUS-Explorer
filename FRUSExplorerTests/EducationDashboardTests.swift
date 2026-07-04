// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

// MARK: - EducationDashboardTests

/// Pure model tests for the "About the Series" content-model dashboards: the
/// optional `EducationPage.dashboard` variant, the `.aboutTheSeries` category,
/// and the real dashboard pages — `.seriesProduction` (Analytics SA-1b) and
/// `.seriesGeography` (Analytics SA-2).
///
/// These assert the content model only — no SwiftUI view is instantiated — so
/// they run without an `AppState` environment. They guard against: a missing or
/// duplicated dashboard page, a stray `dashboard` on a prose page (which must be
/// `.aboutTheSeries` with empty sections), and a broken deep-link contract for
/// the page ids.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
///   1.1 — Analytics SA-1b: retargeted from the DEBUG placeholder to the real,
///          unconditional `series-production` page
///   1.2 — Analytics SA-2: now covers BOTH dashboard pages
///          (`series-production`, `series-geography`); the guard is kept general
@MainActor
struct EducationDashboardTests {

    /// The two dashboard page ids paired with their expected dashboard case.
    private static let dashboardPages: [(id: String, dashboard: EducationDashboard)] = [
        ("series-production", .seriesProduction),
        ("series-geography", .seriesGeography),
    ]

    /// The category carries a non-empty localised title.
    @Test("EducationDashboard: aboutTheSeries category has a non-empty title")
    func aboutTheSeriesTitleNonEmpty() {
        #expect(!EducationCategory.aboutTheSeries.title.isEmpty)
    }

    /// Each dashboard case is carried by exactly one page, with the expected id,
    /// category, dashboard, and empty sections; and each id is unique.
    @Test("EducationDashboard: each dashboard page is well-formed and unique")
    func dashboardPagesAreWellFormed() {
        for expected in Self.dashboardPages {
            let matches = EducationPage.all.filter { $0.dashboard == expected.dashboard }
            #expect(matches.count == 1, "Expected exactly one page for \(expected.dashboard)")

            guard let page = matches.first else { continue }
            #expect(page.id == expected.id)
            #expect(page.category == .aboutTheSeries)
            #expect(page.dashboard == expected.dashboard)
            #expect(page.sections.isEmpty)

            // The id is unique across all pages.
            let sameId = EducationPage.all.filter { $0.id == expected.id }
            #expect(sameId.count == 1)
        }
    }

    /// Both dashboard pages exist and are distinct.
    @Test("EducationDashboard: both dashboard pages are present and distinct")
    func bothDashboardPagesPresent() {
        let dashboards = EducationPage.all.compactMap(\.dashboard)
        #expect(dashboards.contains(.seriesProduction))
        #expect(dashboards.contains(.seriesGeography))
        // Exactly two pages carry a dashboard.
        #expect(EducationPage.all.filter { $0.dashboard != nil }.count == 2)
    }

    /// The deep-link contract resolves each dashboard page by id.
    @Test("EducationDashboard: each dashboard page resolves via the deep-link firstIndex lookup")
    func dashboardsResolveViaDeepLink() {
        for expected in Self.dashboardPages {
            let index = EducationPage.all.firstIndex { $0.id == expected.id }
            #expect(index != nil, "Deep link failed to resolve \(expected.id)")
        }
    }

    /// Every page that carries a dashboard is an `.aboutTheSeries` page with
    /// empty sections, and every non-dashboard page carries a `nil` dashboard —
    /// the general guard against a prose page sprouting a dashboard, or a
    /// dashboard page carrying prose that would break the Markdown-link scan.
    @Test("EducationDashboard: only aboutTheSeries pages carry a dashboard, with empty sections")
    func onlyAboutTheSeriesPagesCarryDashboards() {
        for page in EducationPage.all {
            if page.dashboard != nil {
                #expect(page.category == .aboutTheSeries,
                        "Page \(page.id) carries a dashboard but is not .aboutTheSeries")
                #expect(page.sections.isEmpty,
                        "Dashboard page \(page.id) must have empty sections")
            } else {
                #expect(page.dashboard == nil, "Page \(page.id) unexpectedly carries a dashboard")
            }
        }
    }
}
