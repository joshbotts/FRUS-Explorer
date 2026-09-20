// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Which cloud surface — if any — owns the screen right now.
///
/// Owner decision O-0-1 gave the word cloud two homes outside onboarding: **(c)** a backdrop
/// behind the indexing banners, and **(d)** a splash on launches with a live reason. They
/// are mutually exclusive, and the plan is explicit about *how*: one resolved value with a
/// single owner, **not two independent `if`s in two views**. Two conditions racing for the
/// same surface is how the research-trail double-write in Wave R began.
///
/// Version history:
///   1.0 — O-3: initial implementation
enum CloudSurface: Hashable, Sendable {
    /// No cloud. The ordinary case, including every warm start.
    case none
    /// (c) — work is landing, and the wait is genuinely minutes long.
    case indexingBackdrop
    /// (d) — a launch with something to say.
    case splash(SplashReason)

    /// Why a splash is showing. Each reason owns its own dismissal rule.
    enum SplashReason: Hashable, Sendable {
        /// The very first launch after install. Flows straight into onboarding's own cloud.
        case freshInstall
        /// A CloudKit initial import is actually running — a real wait, of real duration.
        case cloudKitImport
    }
}

/// Resolves which cloud surface is showing, for both views to read.
///
/// Version history:
///   1.0 — O-3: initial implementation
@MainActor
enum CloudSurfaceArbiter {

    /// The inputs, named so the rules can be tested without an `AppState`.
    struct Inputs: Equatable, Sendable {
        /// Whether the bundled core vectors have finished decoding.
        var isCoreReady: Bool
        /// Volumes queued for download, or indexing work in flight.
        var hasPendingCorpusWork: Bool
        /// `false` on a fresh install.
        var hasCompletedOnboarding: Bool
        /// A CloudKit initial import is in progress.
        var isCloudKitImporting: Bool
        /// `FRUS_UI_TEST_MODE`.
        var isUITestMode: Bool

        /// Creates an input set.
        init(isCoreReady: Bool, hasPendingCorpusWork: Bool, hasCompletedOnboarding: Bool,
             isCloudKitImporting: Bool, isUITestMode: Bool) {
            self.isCoreReady = isCoreReady
            self.hasPendingCorpusWork = hasPendingCorpusWork
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.isCloudKitImporting = isCloudKitImporting
            self.isUITestMode = isUITestMode
        }
    }

    /// The single rule. Order is the decision.
    ///
    /// 1. **UI test mode wins over everything.** A splash fading in over `ContentView`
    ///    would race every existing UI test's first element lookup — the same bypass
    ///    `ContentView` already applies.
    /// 2. **(c) beats (d).** Pending download or index work means the indexing backdrop owns
    ///    the screen and no splash appears. This is the precedence rule from O-0-1, and it
    ///    is why the two surfaces cannot both claim the screen: they are branches of one
    ///    `switch`, not two views each testing their own condition.
    /// 3. **No vectors, no cloud — but that gates (c) ONLY.**
    /// 4. Then the (d) occasions, fresh install first.
    /// 5. Otherwise nothing — which is every ordinary warm start.
    ///
    /// ## Why the vector guard moved, and why the splash had never been seen
    ///
    /// `guard inputs.isCoreReady else { return .none }` used to sit above everything, and it made
    /// the splash **unreachable**. `ContentViewWithSplash.resolveSplash()` asks this question once,
    /// latched, from its own `.task`; `isCoreReady` turns true only inside the app's ROOT `.task`,
    /// behind `await bootSearchInfrastructureOnce()`. The root task therefore suspends before it
    /// reaches the decode, the child task runs the whole of `resolveSplash()` against a `false`, and
    /// the answer — `.none` — is kept forever. Measured on a fresh install of iPad Pro 11-inch
    /// (M5) / iOS 27.0: **44 frames over a cold and a warm launch, zero splash frames.** The
    /// sequence is launch screen -> onboarding.
    ///
    /// `CloudSurfaceArbiterTests.freshInstallSplash` passed throughout, because its fixture hard-codes
    /// `isCoreReady: true`. The rule was right; the question was asked at a moment when the rule
    /// could only say no. That is the defect class the visual-marketing plan's §10 already
    /// catalogues for `relaunchMidDownloadPrefersIndexing` — asserting the arbiter's value rather
    /// than what renders.
    ///
    /// The guard belongs to (c) alone because **(c) IS a cloud and (d) is not.** The indexing
    /// backdrop's whole content is the word field, so with no vectors there is nothing to raise.
    /// The splash is a composition — background, app tile, wordmark, caption, shimmer — that the
    /// cloud joins; `WordCloudBackdropView` already renders nothing until the vectors land, by its
    /// own contract, so a splash raised early is exactly the launch screen's composition, which is
    /// what `LaunchSplashView`'s own doc says it exists to continue.
    static func resolve(_ inputs: Inputs) -> CloudSurface {
        guard !inputs.isUITestMode else { return .none }
        // (c) first, and it is the only branch the vectors gate: with none resident there is
        // nothing for an all-cloud surface to draw, and `.none` here does NOT fall through to a
        // splash — the precedence from O-0-1 survives the move.
        if inputs.hasPendingCorpusWork { return inputs.isCoreReady ? .indexingBackdrop : .none }
        if !inputs.hasCompletedOnboarding { return .splash(.freshInstall) }
        if inputs.isCloudKitImporting { return .splash(.cloudKitImport) }
        return .none
    }

    /// Reads the live app state.
    static func resolve(appState: AppState) -> CloudSurface {
        resolve(Inputs(
            // `AppState`'s mirror, NOT `BundledCloudVectors.isCoreReady`. The store is a plain
            // `@MainActor enum` with static state, so nothing observes it: a caller evaluating this
            // inside a `body` — `IndexingBannerView` and `IndexingQueueBannerView` both do — was
            // never re-run when the vectors landed, and the strip's cloud appeared only if some
            // unrelated change happened to re-render the host. Reading the observable mirror makes
            // arrival a real dependency at every call site at once.
            isCoreReady: appState.areCloudVectorsReady,
            // The QUEUE, not the volume. `currentIndexingProgress` goes nil between
            // volumes, so this used to blink false once per volume and take the cloud
            // down with it — the strip appeared "for a second or two" and vanished,
            // repeatedly, which is what the owner reported on device.
            hasPendingCorpusWork: !appState.downloadQueue.isEmpty
                || appState.indexingBatch != nil,
            hasCompletedOnboarding: appState.hasCompletedOnboarding,
            // Both halves are required: `hasInitialProjectSyncSettled` alone is false on a
            // device that will never sync (no iCloud account), which would show a splash
            // waiting for something that is never going to arrive.
            isCloudKitImporting: !appState.hasInitialProjectSyncSettled
                && Self.isSyncing(appState.cloudKitSyncState),
            isUITestMode: ProcessInfo.processInfo.environment["FRUS_UI_TEST_MODE"] == "1"
        ))
    }

    /// Whether a sync is in flight.
    ///
    /// Pattern-matched rather than compared: `CloudKitSyncState` carries associated values
    /// (`.succeeded(Date)`, `.failed(String)`) and is deliberately not `Equatable`. Adding
    /// that conformance to satisfy one call site here would widen a shared type for a
    /// caller's convenience.
    private static func isSyncing(_ state: CloudKitSyncState) -> Bool {
        if case .syncing = state { return true }
        return false
    }

    /// The scope the indexing backdrop previews, from the volumes currently landing.
    ///
    /// Re-evaluated as the queue drains, so the cloud tracks what is actually arriving.
    /// A queue spanning several eras resolves to the corpus rather than picking one
    /// arbitrarily — showing a user one era's vocabulary while four eras download would
    /// misdescribe the wait they are watching.
    static func indexingScope(queuedVolumeIds: [String],
                              manifest: ManifestStore) -> BundledCloudVectors.Scope {
        let subseries = Set(queuedVolumeIds.compactMap { manifest.entry(forVolumeId: $0)?.subseries })
        if subseries.count == 1, let only = subseries.first { return .subseries(only) }
        return .corpus
    }
}
