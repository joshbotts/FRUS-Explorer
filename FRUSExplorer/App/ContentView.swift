// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

/// Root routing view for FRUS Explorer.
///
/// Gates between `OnboardingView` and the platform-appropriate main UI.
///
/// Routes to `OnboardingView` unless BOTH of these conditions are true:
/// - `appState.hasCompletedOnboarding == true` (UserDefaults flag set at wizard completion)
/// - At least one `.xml` volume file exists on disk, OR a download is actively queued,
///   OR the process is running under `FRUS_UI_TEST_MODE` (UI tests have no downloaded
///   volumes but still need to reach the main UI)
///
/// Using AND (not OR) means no volumes → always show onboarding, even if the user
/// previously completed it. `downloadQueue` prevents a mid-download flicker: the flag
/// is set true at "Get Started" but the first volume may not have landed yet.
///
/// Setting `hasCompletedOnboarding = false` (e.g. from the Settings reset action) OR
/// deleting all downloaded volumes causes this view to re-route to `OnboardingView` on
/// the next SwiftUI render pass, effectively re-triggering onboarding.
///
/// ## Platform routing (post-onboarding)
/// - **macOS**: `MainWindowView` — window-based navigation with NavigationStack, research strip,
///   and status bar. Corpus Browser, Cross-Reference Graph, and Source Explorer open as
///   independent windows via `openWindow(id:)`.
/// - **iOS**: `MainTabView` — five-tab navigation unchanged from the existing architecture.
///
/// Version history:
///   1.0 — Session 01: initial placeholder implementation
///   1.1 — Session 10: replaced with onboarding / main-app routing
///   1.2 — Session 11: replaced placeholder with BrowserView
///   1.3 — Session 43: iOS routes to MainTabView; macOS stays on BrowserView
///   2.0 — New UI: macOS routes to MainWindowView (window-based navigation)
///   2.1 — Routing changed from OR to AND: no volumes → always show onboarding even if
///          flag is true; downloadQueue prevents flicker during active downloads
///   2.2 — Session 156: FRUS_UI_TEST_MODE bypasses the volumes/downloadQueue check, so
///          `-hasCompletedOnboarding 1` reaches MainTabView/MainWindowView in UI tests
///          (the AND-based check in 2.1 had made that launch argument a no-op)
struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        let hasVolumes = OnboardingViewModel.hasDownloadedVolumes(in: appState.downloadManager?.volumesDirectory)
        let hasActiveDownloads = !appState.downloadQueue.isEmpty
        let isUITestMode = ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
        if appState.hasCompletedOnboarding && (hasVolumes || hasActiveDownloads || isUITestMode) {
            #if os(iOS)
            MainTabView()
            #else
            MainWindowView()
            #endif
        } else {
            OnboardingView()
        }
    }
}
