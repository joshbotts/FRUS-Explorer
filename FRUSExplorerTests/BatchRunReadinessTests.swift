// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - BatchRunReadinessTests

/// Tests the batch-run Start gate (S-3c).
///
/// The gate this replaces was a boolean that checked a *subset* of what the start path actually
/// required, so Start could be live and do nothing. These pin every precondition, and the order
/// they are reported in — a reader sent to fix a scope picker when the real problem is that the
/// device cannot summarize at all has been sent to waste their time.
struct BatchRunReadinessTests {

    /// A run that can start: every precondition satisfied.
    private func ready(scope: ScopeType = .volume) -> BatchRunReadiness {
        BatchRunReadiness(
            modelAvailable: true,
            serviceAvailable: true,
            downloadManagerAvailable: true,
            promptCount: 3,
            selectedPromptExists: true,
            downloadedVolumeCount: 12,
            scopeType: scope,
            scopeSelectionComplete: true,
            customScopeDownloadedCount: 4
        )
    }

    @Test("A fully configured run can start")
    func happyPath() {
        #expect(ready().canStart)
        #expect(ready().blocker == nil)
    }

    // MARK: - The bug this replaces

    /// The regression that motivated the rewrite. The old gate checked `selectedPromptId != nil`;
    /// the start path additionally required the id to still *resolve*. Deleting the selected
    /// prompt — from the very same Settings screen — left Start enabled and inert.
    @Test("A deleted prompt blocks Start instead of leaving it live and inert")
    func deletedPromptBlocksStart() {
        var r = ready()
        r.selectedPromptExists = false
        #expect(!r.canStart)
        #expect(r.blocker == .promptMissing)
    }

    /// The other two preconditions the start path guarded and the old gate did not.
    @Test("A missing service or download manager blocks Start")
    func infrastructureBlocksStart() {
        var noService = ready()
        noService.serviceAvailable = false
        #expect(noService.blocker == .notReady)

        var noDownloads = ready()
        noDownloads.downloadManagerAvailable = false
        #expect(noDownloads.blocker == .notReady)
    }

    // MARK: - Each obstacle

    @Test("An unavailable model blocks Start")
    func modelUnavailable() {
        var r = ready()
        r.modelAvailable = false
        #expect(r.blocker == .modelUnavailable)
    }

    @Test("No prompts blocks Start")
    func noPrompts() {
        var r = ready()
        r.promptCount = 0
        r.selectedPromptExists = false
        #expect(r.blocker == .noPrompts)
    }

    /// Summarization reads volume text, so an empty library cannot run anything — worth saying
    /// before the reader fills in a scope that could never match.
    @Test("Nothing downloaded blocks Start")
    func nothingDownloaded() {
        var r = ready()
        r.downloadedVolumeCount = 0
        #expect(r.blocker == .nothingDownloaded)
    }

    @Test("An unfilled scope blocks Start and names the scope kind",
          arguments: [ScopeType.volume, .subseries, .userTag, .savedSearch, .dateRange])
    func incompleteScope(scope: ScopeType) {
        var r = ready(scope: scope)
        r.scopeSelectionComplete = false
        #expect(r.blocker == .scopeIncomplete(scope))
        #expect(!r.blocker!.reason.isEmpty)
    }

    /// A scope may legitimately name volumes that are not downloaded (#258 §8-Q1(a)). One with
    /// *none* downloaded would enumerate nothing, so it is blocked — and distinguished from a
    /// scope that simply has not been chosen yet.
    @Test("A chosen scope with no downloaded members is blocked, and distinctly")
    func customScopeNotDownloaded() {
        var chosen = ready(scope: .customScope)
        chosen.customScopeDownloadedCount = 0
        #expect(chosen.blocker == .customScopeNotDownloaded)

        var unchosen = ready(scope: .customScope)
        unchosen.scopeSelectionComplete = false
        unchosen.customScopeDownloadedCount = 0
        #expect(unchosen.blocker == .scopeIncomplete(.customScope))
    }

    // MARK: - Ordering

    /// When several things are wrong at once, the reader is told the most fundamental one. Being
    /// sent to pick a volume on a device that cannot summarize at all is worse than no message.
    @Test("The most fundamental obstacle is reported first")
    func ordering() {
        var everythingWrong = ready()
        everythingWrong.modelAvailable = false
        everythingWrong.serviceAvailable = false
        everythingWrong.promptCount = 0
        everythingWrong.selectedPromptExists = false
        everythingWrong.downloadedVolumeCount = 0
        everythingWrong.scopeSelectionComplete = false
        #expect(everythingWrong.blocker == .modelUnavailable)

        var noModelProblem = everythingWrong
        noModelProblem.modelAvailable = true
        #expect(noModelProblem.blocker == .notReady)

        var ready2 = noModelProblem
        ready2.serviceAvailable = true
        #expect(ready2.blocker == .noPrompts)
    }

    // MARK: - Copy

    /// Every blocker has to say something, or the footer renders blank and the reader is back to a
    /// silently dimmed button.
    @Test("Every blocker carries a non-empty reason")
    func everyBlockerExplains() {
        let all: [BatchRunBlocker] = [
            .modelUnavailable, .notReady, .noPrompts, .promptMissing, .nothingDownloaded,
            .customScopeNotDownloaded,
        ] + ScopeType.allCases.map { BatchRunBlocker.scopeIncomplete($0) }
        for blocker in all {
            #expect(!blocker.reason.isEmpty, "no reason for \(blocker)")
        }
    }

    /// The scope reasons have to differ from one another — a single generic "choose a scope" would
    /// leave a reader hunting for which of six pickers is the empty one.
    @Test("Each scope kind gets its own sentence")
    func scopeReasonsAreDistinct() {
        let reasons = ScopeType.allCases.map { BatchRunBlocker.scopeIncomplete($0).reason }
        #expect(Set(reasons).count == ScopeType.allCases.count)
    }
}
