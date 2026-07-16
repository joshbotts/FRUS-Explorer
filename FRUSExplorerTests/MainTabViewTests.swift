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

    // MARK: - Tab seed + hand-off (#316: per-window @SceneStorage selection replaced the shared
    // `activeTab`; the persisted last tab is now `AppState.seedActiveTab` / `persistTabSeed`, and
    // cross-view hand-offs go through the consume-once `pendingTab`.)

    #if os(iOS)
    @Test("seedActiveTabDefaultsToBrowse — AppState.seedActiveTab defaults to .browse")
    func seedActiveTabDefaultsToBrowse() {
        clearTabDefault()
        #expect(AppState.seedActiveTab == .browse)
        clearTabDefault()
    }

    @Test("persistTabSeedWritesUserDefaults — persistTabSeed persists the tab rawValue")
    func persistTabSeedWritesUserDefaults() {
        clearTabDefault()
        AppState.persistTabSeed(.settings)
        #expect(UserDefaults.standard.string(forKey: tabKey) == AppTab.settings.rawValue)
        clearTabDefault()
    }

    @Test("handoffRequestsResearchViaPendingTab — a hand-off sets the consume-once pendingTab")
    func handoffRequestsResearchViaPendingTab() {
        let state = AppState()
        #expect(state.pendingTab == nil)
        state.pendingTab = .research
        #expect(state.pendingTab == .research)
    }

    @Test("seedActiveTabRoundTrip — seedActiveTab restores each persisted tab")
    func seedActiveTabRoundTrip() {
        clearTabDefault()
        for tab in AppTab.allCases {
            UserDefaults.standard.set(tab.rawValue, forKey: tabKey)
            #expect(AppState.seedActiveTab == tab,
                    "Expected \(tab) to restore from UserDefaults but got \(AppState.seedActiveTab)")
        }
        clearTabDefault()
    }

    @Test("persistTabSeedDoesNotStampLastActivityVisit — the seed writer never stamps lastActivityTabVisit")
    func persistTabSeedDoesNotStampLastActivityVisit() {
        // Activity tab was replaced by Research in Session 130; lastActivityTabVisit is retained
        // in AppState but is no longer stamped by any tab write (persistTabSeed only writes the
        // seed key).
        clearTabDefault()
        UserDefaults.standard.removeObject(forKey: "frus.lastActivityTabVisit")
        let state = AppState()
        state.lastActivityTabVisit = .distantPast

        for tab in AppTab.allCases {
            AppState.persistTabSeed(tab)
            #expect(state.lastActivityTabVisit == .distantPast,
                    "lastActivityTabVisit must not change when the seed is written for .\(tab.rawValue)")
        }

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

    // MARK: - pendingBrowseVolume
    //
    // showSearch (Session 2026-06-07) and showCitationLookup (Session 2026-07-04,
    // UI audit B4 — Citation Lookup is a macOS Window scene / iOS-local sheet
    // state) were both removed from AppState.

    @Test("pendingBrowseVolumeDefaultsNil — fresh AppState has nil pendingBrowseVolume")
    func pendingBrowseVolumeDefaultsNil() {
        let state = AppState()
        #expect(state.pendingBrowseVolume == nil)
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
    @Test("resetFlowMacOS — hasCompletedOnboarding set to false directly on macOS")
    func resetFlowMacOS() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        // macOS reset path (Session 46): Settings is now a Settings scene (independent window),
        // not a modal sheet. showSettingsSheet and pendingOnboardingAfterReset have been removed
        // from AppState. Direct assignment is safe on both platforms — there is no animation
        // race with ContentView.
        state.hasCompletedOnboarding = false
        #expect(state.hasCompletedOnboarding == false)
    }
    #endif
}
