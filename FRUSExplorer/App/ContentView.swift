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
        if !appState.hasCompletedOnboarding {
            // A genuinely new user. This branch reads nothing that boot has to finish first, so it
            // is decided on the very first frame and never flashes.
            OnboardingView()
        } else if !appState.isBootComplete && !isUITestMode {
            // #753 (audit M-20): an onboarded user must NEVER be shown the first-run Welcome screen
            // again while the app is still starting. `hasVolumes` reads
            // `downloadManager?.volumesDirectory`, and the download manager is assigned at the very
            // END of the async boot — so a researcher with hundreds of downloaded volumes looked
            // exactly like someone who had none, and the app told them so. The flash lengthens with
            // store size, which aims it squarely at the people with the most to lose.
            OnboardingView()
        } else if hasVolumes || hasActiveDownloads || isUITestMode {
            #if os(iOS)
            MainTabView()
            #else
            MainWindowView()
            #endif
        } else {
            // Onboarded, boot finished, and genuinely no volumes — e.g. everything was removed.
            // Re-onboarding is the right answer here, and now it is only ever said when true.
            OnboardingView()
        }
    }
}

// MARK: - Splash host

/// Hosts `ContentView` and the occasional launch splash above it (O-3, decision (d)).
///
/// Separate from `ContentView` so the routing decision and the splash decision stay
/// independent — and because `ContentView`'s `body` already does a filesystem scan on every
/// render pass (`hasDownloadedVolumes(in:)`, finding 9 in the Workstream O plan). That is
/// pre-existing and **flagged, not silently fixed here**: it belongs in its own change with
/// its own reasoning, not folded into a UI PR.
///
/// Version history:
///   1.0 — O-3: initial implementation
struct ContentViewWithSplash: View {

    @Environment(AppState.self) private var appState
    @State private var splashReason: CloudSurface.SplashReason?
    @State private var hasResolvedOnce = false

    var body: some View {
        ContentView()
            .overlay {
                if let splashReason {
                    LaunchSplashView(reason: splashReason)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: splashReason == nil)
            .task { await resolveSplash() }
            .onChange(of: appState.hasInitialProjectSyncSettled) { _, settled in
                // A CloudKit splash dismisses when its wait actually ends, not on a timer.
                if settled, splashReason == .cloudKitImport { splashReason = nil }
            }
    }

    /// Asks the arbiter once, after the first frame, and honours the reason's own dismissal.
    private func resolveSplash() async {
        guard !hasResolvedOnce else { return }
        hasResolvedOnce = true

        switch CloudSurfaceArbiter.resolve(appState: appState) {
        case .splash(let reason):
            splashReason = reason
            if reason == .freshInstall {
                // Nothing to wait for, so hold briefly and flow into onboarding's own
                // cloud. ONCE PER INSTALL — not a per-launch floor, which the plan rules
                // out as a permanent tax on a tool people open repeatedly.
                try? await Task.sleep(for: .seconds(1.6))
                splashReason = nil
            }
        case .indexingBackdrop, .none:
            // (c) owns the screen, or nothing does. Either way, no splash — the precedence
            // lives in the arbiter, not here.
            splashReason = nil
        }
    }
}
