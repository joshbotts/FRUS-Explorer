// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import OSLog
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
///   1.1 — the once-and-latched resolve is now CORRECT rather than merely cheap. It was always
///         asked before `BundledCloudVectors.prepareCore()` could have finished — the root scene's
///         `.task` suspends on `bootSearchInfrastructureOnce()` first — and the arbiter's
///         top-level vector guard turned that into a permanent `.none`, so no splash had ever been
///         seen on any launch. The guard moved to the branch it belongs to; see
///         `CloudSurfaceArbiter.resolve`. Nothing here changed, which is the point: the decision
///         is a rule's to make, and the rule was the thing that was wrong.
///   1.2 — a fresh install's splash is up from the FIRST frame (#1759). It used to wait for the
///         resolve, which runs from a `.task` after that frame, so the onboarding dock underneath
///         was the first thing a new reader saw: drawn under the fading launch screen for a quarter
///         of a second on an iPad (5.44 to 5.69 s into S2's first launch), and in the Mac window's
///         first two frames (S4), before the splash covered it.
///   1.3 — a CloudKit splash lets the launch through whatever sync does (#1796): it lifts when an
///         import ends, as before, and also when the device goes offline, when the event it waited
///         on ends with no import begun, or after a bound (`holdCloudKitImportSplash`), and logs
///         why. It used to lift only when an import ended, so a launch with no network kept it for good.
struct ContentViewWithSplash: View {

    @Environment(AppState.self) private var appState
    @State private var splashReason: CloudSurface.SplashReason?
    @State private var hasResolvedOnce = false

    var body: some View {
        let reason = shownReason
        ContentView()
            .overlay {
                if let reason {
                    LaunchSplashView(reason: reason)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: reason == nil)
            .task { await resolveSplash() }
    }

    /// The splash this frame shows: the resolved reason once ``resolveSplash()`` has run, and before
    /// it, a fresh install's (`CloudSurfaceArbiter.firstFrameSplash`, which says why only that one
    /// is known at frame zero). The resolve latches the same answer in the same pass that sets
    /// ``hasResolvedOnce``, so nothing moves when it lands.
    private var shownReason: CloudSurface.SplashReason? {
        hasResolvedOnce ? splashReason : CloudSurfaceArbiter.firstFrameSplash(appState: appState)
    }

    /// Asks the arbiter once, after the first frame, and honours the reason's own dismissal.
    ///
    /// **Once is right, and it is why the arbiter may not gate a splash on the word-cloud vectors.**
    /// This runs before they can possibly be resident, so any rule that required them could only
    /// ever answer "no" here — and the answer is kept. A late splash would be worse than none:
    /// `ContentView` is already on screen underneath, so raising one a second in would fade a
    /// launch screen over a running app — which is why a fresh install's splash no longer waits
    /// for this at all (``shownReason``).
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
                //
                // The flow is real since #1759: onboarding's backdrop fades its cloud in when the
                // vectors land, under the splash, on the splash's own lens, so the fade-out below
                // crosses one cloud into the other. It used to wait for its next lens change to
                // notice the vectors, and the splash left an empty backdrop, for 0.18 to 1.21 s
                // in the launches measured.
                try? await Task.sleep(for: .seconds(1.6))
                splashReason = nil
            } else {
                // Logged, so a launch the splash held can be read from the unified log (#1796).
                Self.splashLog.notice("CloudKit splash raised")
                let (lift, held) = await holdCloudKitImportSplash()
                Self.splashLog.notice("CloudKit splash lifted: \(lift?.rawValue ?? "cancelled", privacy: .public) after \(held, format: .fixed(precision: 1), privacy: .public) s")
                splashReason = nil
            }
        case .indexingBackdrop, .none:
            // (c) owns the screen, or nothing does. Either way, no splash — the precedence
            // lives in the arbiter, not here.
            splashReason = nil
        }
    }

    /// The launch splash's log: when a CloudKit splash is raised and why it lifted (#1796).
    private static let splashLog = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "LaunchSplash")

    /// Returns when a CloudKit splash may lift, with why and how long it held: when
    /// `CloudSurfaceArbiter.cloudKitImportSplashLift` names a reason, asked four times a second
    /// (#1796). The reason is `nil` only when the task was cancelled.
    ///
    /// The sync state is the most recent event's, so "idle" is measured from the first ask that
    /// finds no event in flight, and an event beginning again restarts it: a setup's end and the
    /// import that follows it a second later read as one wait, and a setup that fails with nothing
    /// after it lifts the splash a few seconds later rather than never.
    private func holdCloudKitImportSplash() async -> (CloudSurfaceArbiter.CloudKitSplashLift?, Double) {
        let clock = ContinuousClock()
        let raised = clock.now
        var idleSince: ContinuousClock.Instant?
        while !Task.isCancelled {
            let syncing = CloudSurfaceArbiter.isSyncing(appState.cloudKitSyncState)
            if syncing { idleSince = nil } else if idleSince == nil { idleSince = clock.now }
            if let lift = CloudSurfaceArbiter.cloudKitImportSplashLift(
                importSettled: appState.hasInitialProjectSyncSettled, isSyncing: syncing,
                isOnline: appState.isOnline, quietFor: idleSince.map { clock.now - $0 },
                shownFor: clock.now - raised) {
                return (lift, Self.seconds(clock.now - raised))
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return (nil, Self.seconds(clock.now - raised))
    }

    /// A duration in seconds, for the log.
    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
