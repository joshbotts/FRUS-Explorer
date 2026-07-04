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

/// Pure model tests for the Analytics Prep-A content-model extension: the
/// optional `EducationPage.dashboard` variant, the new `.aboutTheSeries`
/// category, and the `DEBUG`-only placeholder page.
///
/// These assert the content model only — no SwiftUI view is instantiated — so
/// they run without an `AppState` environment. They guard against three
/// regressions: an accidental release-visible dashboard page (the placeholder
/// must stay `DEBUG`-only), a stray `dashboard` on an existing prose page, and
/// a broken deep-link contract for the placeholder id.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
@MainActor
struct EducationDashboardTests {

    /// The new category carries a non-empty localised title.
    @Test("EducationDashboard: aboutTheSeries category has a non-empty title")
    func aboutTheSeriesTitleNonEmpty() {
        #expect(!EducationCategory.aboutTheSeries.title.isEmpty)
    }

    #if DEBUG
    /// In DEBUG, exactly one page carries the placeholder dashboard, and it has
    /// the expected id, category, and empty sections.
    @Test("EducationDashboard: DEBUG placeholder page is well-formed and unique")
    func debugPlaceholderPageIsWellFormed() {
        let dashboardPages = EducationPage.all.filter { $0.dashboard == .placeholder }
        #expect(dashboardPages.count == 1)

        guard let page = dashboardPages.first else { return }
        #expect(page.id == "series-dashboard-placeholder")
        #expect(page.category == .aboutTheSeries)
        #expect(page.sections.isEmpty)

        // The id is unique across all pages.
        let matchingIds = EducationPage.all.filter { $0.id == "series-dashboard-placeholder" }
        #expect(matchingIds.count == 1)
    }

    /// The deep-link contract still resolves the placeholder page by id.
    @Test("EducationDashboard: DEBUG placeholder resolves via the deep-link firstIndex lookup")
    func debugPlaceholderResolvesViaDeepLink() {
        let index = EducationPage.all.firstIndex { $0.id == "series-dashboard-placeholder" }
        #expect(index != nil)
    }
    #endif

    /// Every non-placeholder page has a `nil` dashboard — guards against a
    /// prose page accidentally sprouting a dashboard.
    @Test("EducationDashboard: only the placeholder page carries a dashboard")
    func onlyPlaceholderCarriesDashboard() {
        for page in EducationPage.all where page.id != "series-dashboard-placeholder" {
            #expect(page.dashboard == nil, "Page \(page.id) unexpectedly carries a dashboard")
        }
    }
}
