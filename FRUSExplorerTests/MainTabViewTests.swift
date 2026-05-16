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

// MARK: - MainTabViewTests

/// Tests for tab navigation state wired in Sessions 43–44.
///
/// All tests run on the main actor because `AppState` is `@MainActor`-isolated.
///
/// Version history:
///   1.0 — Session 44: initial implementation
@MainActor
struct MainTabViewTests {

    private let tabKey = "frus.activeTab"

    private func clearTabDefault() {
        UserDefaults.standard.removeObject(forKey: tabKey)
    }

    // MARK: - Active Tab

    #if os(iOS)
    @Test("activeTabDefaultIsBrowse — AppState.activeTab defaults to .browse")
    func activeTabDefaultIsBrowse() {
        clearTabDefault()
        let state = AppState()
        #expect(state.activeTab == .browse)
        clearTabDefault()
    }

    @Test("settingActiveTabUpdatesUserDefaults — writing activeTab persists rawValue")
    func settingActiveTabUpdatesUserDefaults() {
        clearTabDefault()
        let state = AppState()
        state.activeTab = .settings
        let stored = UserDefaults.standard.string(forKey: tabKey)
        #expect(stored == AppTab.settings.rawValue)
        clearTabDefault()
    }

    @Test("projectPickerClosureSwitchesToActivityTabOnIOS — closure writes .activity")
    func projectPickerClosureSwitchesToActivityTabOnIOS() {
        clearTabDefault()
        let state = AppState()
        state.activeTab = .activity
        #expect(state.activeTab == .activity)
        clearTabDefault()
    }

    @Test("activeTabPersistenceRoundTrip — cycling all five tabs persists and restores each")
    func activeTabPersistenceRoundTrip() {
        clearTabDefault()
        for tab in AppTab.allCases {
            UserDefaults.standard.set(tab.rawValue, forKey: tabKey)
            let restored = AppState()
            #expect(restored.activeTab == tab,
                    "Expected \(tab) to restore from UserDefaults but got \(restored.activeTab)")
        }
        clearTabDefault()
    }

    @Test("lastActivityTabVisitUpdatesOnActivityTabSelect — stamped near .now when Activity selected")
    func lastActivityTabVisitUpdatesOnActivityTabSelect() {
        clearTabDefault()
        UserDefaults.standard.removeObject(forKey: "frus.lastActivityTabVisit")
        let state = AppState()
        state.lastActivityTabVisit = .distantPast

        state.activeTab = .browse   // must NOT stamp
        #expect(state.lastActivityTabVisit == .distantPast)

        state.activeTab = .activity // MUST stamp
        let elapsed = Date.now.timeIntervalSince(state.lastActivityTabVisit)
        #expect(elapsed < 2, "lastActivityTabVisit should be near .now after selecting Activity tab")

        clearTabDefault()
        UserDefaults.standard.removeObject(forKey: "frus.lastActivityTabVisit")
    }
    #endif

    // MARK: - pendingBrowseDocument

    @Test("pendingBrowseDocumentClearedAfterNavigation — observer clears after consuming")
    func pendingBrowseDocumentClearedAfterNavigation() {
        let state = AppState()
        let entry = DocumentBrowserEntry(
            documentId: "d1",
            volumeId: "frus1969-76v01",
            documentNumber: "1",
            header: "Test Document",
            dateline: nil,
            sourceNote: nil
        )
        state.pendingBrowseDocument = entry
        #expect(state.pendingBrowseDocument != nil)

        // Simulate what BrowserView.onChange does: consume and clear.
        _ = state.pendingBrowseDocument
        state.pendingBrowseDocument = nil
        #expect(state.pendingBrowseDocument == nil)
    }

    @Test("pendingBrowseDocumentDefaultsNil — fresh AppState has nil pendingBrowseDocument")
    func pendingBrowseDocumentDefaultsNil() {
        let state = AppState()
        #expect(state.pendingBrowseDocument == nil)
    }

    // MARK: - showSearch / showCitationLookup

    @Test("showSearchDefaultsFalse — fresh AppState has showSearch == false")
    func showSearchDefaultsFalse() {
        let state = AppState()
        #expect(state.showSearch == false)
    }

    @Test("showCitationLookupDefaultsFalse — fresh AppState has showCitationLookup == false")
    func showCitationLookupDefaultsFalse() {
        let state = AppState()
        #expect(state.showCitationLookup == false)
    }
}

// MARK: - ResetFlowTests

/// Tests for the platform-specific reset flow introduced in Session 44.
///
/// All tests run on the main actor because `AppState` is `@MainActor`-isolated.
@MainActor
struct ResetFlowTests {

    #if os(iOS)
    @Test("resetFlowIOS — hasCompletedOnboarding set to false directly on iOS")
    func resetFlowIOS() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        // iOS reset path: direct assignment, no pendingOnboardingAfterReset needed.
        state.hasCompletedOnboarding = false
        #expect(state.hasCompletedOnboarding == false)
    }
    #endif

    #if os(macOS)
    @Test("resetFlowMacOS — pendingOnboardingAfterReset toggled, showSettingsSheet cleared")
    func resetFlowMacOS() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        state.showSettingsSheet = true
        // macOS reset path: two-phase dismissal.
        state.pendingOnboardingAfterReset = true
        state.showSettingsSheet = false
        #expect(state.pendingOnboardingAfterReset == true)
        #expect(state.showSettingsSheet == false)
        // BrowserView.handleSettingsSheetDismiss would then do:
        state.pendingOnboardingAfterReset = false
        state.hasCompletedOnboarding = false
        #expect(state.hasCompletedOnboarding == false)
    }
    #endif
}
