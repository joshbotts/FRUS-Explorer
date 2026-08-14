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
/// Gates between `OnboardingView`, `BootPlaceholderView` and the platform-appropriate main UI.
/// **The decision itself lives in `AppRootRouter`, not here** — see that type for the rule and
/// for why it was worth extracting.
///
/// In short: an onboarded reader reaches the app when they have a volume on disk, a download in
/// flight, a UI-test launch, or a deliberate empty-library finish
/// (`AppState.hasFinishedOnboardingWithoutVolumes`). Onboarding is re-shown only to someone who
/// has never completed it, or whose volumes have gone missing — the case the AND was written
/// for. Setting `hasCompletedOnboarding = false` (the Settings reset action) re-triggers the
/// wizard on the next render pass.
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
///   2.3 — the routing rule moves to `AppRootRouter` (testable), and a deliberate
///          empty-library finish reaches the app instead of looping back to the wizard
struct ContentView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        let destination = AppRootRouter.destination(
            hasCompletedOnboarding: appState.hasCompletedOnboarding,
            isBootComplete: appState.isBootComplete,
            hasVolumes: OnboardingViewModel.hasDownloadedVolumes(
                in: appState.downloadManager?.volumesDirectory),
            hasActiveDownloads: !appState.downloadQueue.isEmpty,
            hasFinishedOnboardingWithoutVolumes: appState.hasFinishedOnboardingWithoutVolumes,
            isUITestMode: ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1")

        switch destination {
        case .onboarding:
            OnboardingView()
        case .bootPlaceholder:
            BootPlaceholderView()
        case .main:
            #if os(iOS)
            MainTabView()
            #else
            MainWindowView()
            #endif
        }
    }
}

// MARK: - AppRootRouter

/// Where the app's root should send the reader.
enum AppRootDestination: Equatable {
    /// The first-run wizard.
    case onboarding
    /// The "still starting" placeholder — never the wizard, see `AppRootRouter`.
    case bootPlaceholder
    /// The platform's main UI.
    case main
}

/// The root routing decision, as a pure function.
///
/// **Extracted from `ContentView.body` so it can be tested at all.** The rule below shipped for
/// months with a first-run trap in it (see `hasFinishedOnboardingWithoutVolumes`), and the
/// existing tests could not have caught it: they cover `OnboardingCompletion`'s side effects,
/// every one of which *succeeds* on the trapped path. What was untested was the decision made
/// afterwards, and a decision living inside a view body has no seam a test can reach.
///
/// Version history:
///   1.0 — extracted from `ContentView.body` with the Skip dead-end fix
enum AppRootRouter {

    /// Resolves the root destination.
    ///
    /// The order of the checks is load-bearing:
    ///
    /// 1. **Never onboarded → the wizard**, decided on the first frame because it reads nothing
    ///    that boot must finish first, so it cannot flash.
    /// 2. **Onboarded but still booting → the placeholder** (#753 / audit M-20). `hasVolumes`
    ///    reads the download manager's directory and the manager is assigned at the very END of
    ///    the async boot, so a researcher with hundreds of volumes looks exactly like someone
    ///    with none until boot finishes — and the app used to tell them so, for longer the more
    ///    they had. An onboarded user must never be shown the first-run screen again.
    /// 3. **Anything to read, anything arriving, a UI-test run, or a reader who deliberately
    ///    finished onboarding empty → the app.**
    /// 4. **Otherwise → the wizard**, which now means only what it was written to mean: onboarded,
    ///    booted, and the volumes are *gone*. Re-onboarding is right for that; it was never right
    ///    for the reader who simply chose not to download, and telling those two cases apart is
    ///    the whole point of the fourth flag.
    static func destination(hasCompletedOnboarding: Bool,
                            isBootComplete: Bool,
                            hasVolumes: Bool,
                            hasActiveDownloads: Bool,
                            hasFinishedOnboardingWithoutVolumes: Bool,
                            isUITestMode: Bool) -> AppRootDestination {
        guard hasCompletedOnboarding else { return .onboarding }
        guard isBootComplete || isUITestMode else { return .bootPlaceholder }
        if hasVolumes || hasActiveDownloads || isUITestMode
            || hasFinishedOnboardingWithoutVolumes {
            return .main
        }
        return .onboarding
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
