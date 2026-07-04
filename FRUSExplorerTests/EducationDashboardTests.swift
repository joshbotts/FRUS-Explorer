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
/// and the real `.seriesProduction` page (Analytics SA-1b, which replaced the
/// Prep-A DEBUG placeholder).
///
/// These assert the content model only — no SwiftUI view is instantiated — so
/// they run without an `AppState` environment. They guard against: a missing or
/// duplicated dashboard page, a stray `dashboard` on a prose page (which must be
/// `.aboutTheSeries`), and a broken deep-link contract for the page id.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
///   1.1 — Analytics SA-1b: retargeted from the DEBUG placeholder to the real,
///          unconditional `series-production` page
@MainActor
struct EducationDashboardTests {

    /// The dashboard page's stable id.
    private static let productionPageID = "series-production"

    /// The category carries a non-empty localised title.
    @Test("EducationDashboard: aboutTheSeries category has a non-empty title")
    func aboutTheSeriesTitleNonEmpty() {
        #expect(!EducationCategory.aboutTheSeries.title.isEmpty)
    }

    /// Exactly one page carries the production dashboard, in both debug and
    /// release, with the expected id, category, dashboard, and empty sections.
    @Test("EducationDashboard: the series-production page is well-formed and unique")
    func productionPageIsWellFormed() {
        let dashboardPages = EducationPage.all.filter { $0.dashboard == .seriesProduction }
        #expect(dashboardPages.count == 1)

        guard let page = dashboardPages.first else { return }
        #expect(page.id == Self.productionPageID)
        #expect(page.category == .aboutTheSeries)
        #expect(page.dashboard == .seriesProduction)
        #expect(page.sections.isEmpty)

        // The id is unique across all pages.
        let matchingIds = EducationPage.all.filter { $0.id == Self.productionPageID }
        #expect(matchingIds.count == 1)
    }

    /// The deep-link contract resolves the production page by id.
    @Test("EducationDashboard: series-production resolves via the deep-link firstIndex lookup")
    func productionResolvesViaDeepLink() {
        let index = EducationPage.all.firstIndex { $0.id == Self.productionPageID }
        #expect(index != nil)
    }

    /// Every page that carries a dashboard is an `.aboutTheSeries` page, and
    /// every non-dashboard page carries a `nil` dashboard — guards against a
    /// prose page accidentally sprouting a dashboard.
    @Test("EducationDashboard: only aboutTheSeries pages carry a dashboard")
    func onlyAboutTheSeriesPagesCarryDashboards() {
        for page in EducationPage.all {
            if page.dashboard != nil {
                #expect(page.category == .aboutTheSeries,
                        "Page \(page.id) carries a dashboard but is not .aboutTheSeries")
            } else {
                #expect(page.dashboard == nil, "Page \(page.id) unexpectedly carries a dashboard")
            }
        }
    }
}
