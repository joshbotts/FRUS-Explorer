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
/// Routes to `OnboardingView` unless at least one of these conditions is true:
/// - `appState.hasCompletedOnboarding == true` (UserDefaults flag set at wizard completion)
/// - At least one `.xml` volume file exists on disk
///
/// Setting `hasCompletedOnboarding = false` (e.g. from the Settings reset action) and
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
struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        let hasVolumes = OnboardingViewModel.hasDownloadedVolumes(in: appState.downloadManager?.volumesDirectory)
        if appState.hasCompletedOnboarding || hasVolumes {
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
