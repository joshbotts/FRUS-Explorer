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

import Testing
import Foundation
@testable import FRUSExplorer

/// The one rule deciding which cloud surface owns the screen.
///
/// The plan is specific that (c) and (d) must never both claim it, and specific about *how*
/// — one resolved value, not two views each testing their own condition. These tests pin
/// the precedence, because the failure mode is two clouds on screen at once and the only
/// place that can be prevented is here.
///
/// Version history:
///   1.0 — O-3: initial implementation
@Suite("Cloud surface arbiter — precedence")
@MainActor
struct CloudSurfaceArbiterTests {

    /// A warm start on a settled, populated install: the ordinary case.
    private var quiet: CloudSurfaceArbiter.Inputs {
        .init(isCoreReady: true, hasPendingCorpusWork: false, hasCompletedOnboarding: true,
              isCloudKitImporting: false, isUITestMode: false)
    }

    // MARK: - The ordinary case

    @Test("An ordinary warm start shows nothing at all")
    func warmStartShowsNothing() {
        #expect(CloudSurfaceArbiter.resolve(quiet) == .none)
    }

    // MARK: - Precedence: (c) beats (d)

    @Test("Pending corpus work wins over BOTH splash reasons")
    func indexingBeatsEverySplash() {
        // The precedence rule from O-0-1, and the reason the two surfaces are branches of
        // one switch. Both (d) predicates are true here; neither may produce a splash.
        var inputs = quiet
        inputs.hasPendingCorpusWork = true
        inputs.hasCompletedOnboarding = false
        inputs.isCloudKitImporting = true
        #expect(CloudSurfaceArbiter.resolve(inputs) == .indexingBackdrop)
    }

    /// **What this proves, and what it does not.**
    ///
    /// It asserts the arbiter's VALUE, not what reaches the screen. That distinction used to be a
    /// live defect: `.indexingBackdrop` is a suppression verdict this layer does not render, and on
    /// a relaunch with a download QUEUED but no batch started — a fresh library's first volume —
    /// the splash was refused while `MainTabView`'s inset matched no branch, so nothing reported
    /// the pending work and this test passed throughout.
    ///
    /// **B-6 closed it**: `IndexingInsetState.downloadsQueued` now renders that window, and
    /// `IndexingInsetStateTests` covers it — the precedence moved out of the view body precisely
    /// so a test could reach it. The split of responsibility is unchanged and still worth knowing:
    /// this suite proves the verdict, that one proves something renders it. Neither alone would
    /// have caught the gap.
    @Test("Relaunching mid-download shows the indexing backdrop, not a splash")
    func relaunchMidDownloadPrefersIndexing() {
        // The exact state the plan says to verify by hand: start a download, relaunch.
        // Onboarding is done, sync is settled, but volumes are still landing.
        var inputs = quiet
        inputs.hasPendingCorpusWork = true
        #expect(CloudSurfaceArbiter.resolve(inputs) == .indexingBackdrop)
    }

    // MARK: - The (d) occasions

    @Test("A fresh install gets the fresh-install splash")
    func freshInstallSplash() {
        var inputs = quiet
        inputs.hasCompletedOnboarding = false
        #expect(CloudSurfaceArbiter.resolve(inputs) == .splash(.freshInstall))
    }

    @Test("A running CloudKit import gets its own splash")
    func cloudKitImportSplash() {
        var inputs = quiet
        inputs.isCloudKitImporting = true
        #expect(CloudSurfaceArbiter.resolve(inputs) == .splash(.cloudKitImport))
    }

    @Test("Fresh install outranks a concurrent import, so the reason is never ambiguous")
    func freshInstallOutranksImport() {
        // Both can hold at once on a restore-to-new-device. One reason must win, because
        // the reason decides the dismissal rule — fresh install holds briefly, an import
        // waits for the import.
        var inputs = quiet
        inputs.hasCompletedOnboarding = false
        inputs.isCloudKitImporting = true
        #expect(CloudSurfaceArbiter.resolve(inputs) == .splash(.freshInstall))
    }

    // MARK: - Suppression

    @Test("UI test mode suppresses every surface")
    func uiTestModeSuppressesEverything() {
        // A splash fading in over ContentView would race every existing UI test's first
        // element lookup — the failure the plan calls out explicitly.
        for (work, onboarded, importing) in [(true, true, true), (false, false, false), (true, false, true)] {
            var inputs = quiet
            inputs.isUITestMode = true
            inputs.hasPendingCorpusWork = work
            inputs.hasCompletedOnboarding = onboarded
            inputs.isCloudKitImporting = importing
            #expect(CloudSurfaceArbiter.resolve(inputs) == .none)
        }
    }

    @Test("No vectors means no surface, whatever else is true")
    func unloadedVectorsSuppressEverything() {
        // The core file decodes after the first frame. Until then there is nothing to draw,
        // and a placeholder would be worse than nothing.
        for (work, onboarded, importing) in [(true, true, false), (false, false, false), (false, true, true)] {
            var inputs = quiet
            inputs.isCoreReady = false
            inputs.hasPendingCorpusWork = work
            inputs.hasCompletedOnboarding = onboarded
            inputs.isCloudKitImporting = importing
            #expect(CloudSurfaceArbiter.resolve(inputs) == .none)
        }
    }

    // MARK: - Exhaustive: the two surfaces can never coexist

    @Test("Across every input combination, at most one surface is ever chosen")
    func surfacesAreMutuallyExclusive() {
        // The property the whole design rests on, checked over all 32 combinations rather
        // than the handful above. A `switch` cannot return two values — which is exactly
        // why the arbiter is a switch and not two views' `if`s — so this also documents
        // *why* the shape was chosen.
        var seen: Set<CloudSurface> = []
        for a in [true, false] {
            for b in [true, false] {
                for c in [true, false] {
                    for d in [true, false] {
                        for e in [true, false] {
                            let surface = CloudSurfaceArbiter.resolve(.init(
                                isCoreReady: a, hasPendingCorpusWork: b,
                                hasCompletedOnboarding: c, isCloudKitImporting: d,
                                isUITestMode: e))
                            seen.insert(surface)
                            // A splash and the indexing backdrop are distinct cases of one
                            // enum, so "both" is unrepresentable. Assert the weaker, real
                            // property: pending work always yields the backdrop.
                            if a && !e && b { #expect(surface == .indexingBackdrop) }
                        }
                    }
                }
            }
        }
        // And every branch is reachable — otherwise this suite proves nothing.
        let expected: Set<CloudSurface> = [.none, .indexingBackdrop,
                                           .splash(.freshInstall), .splash(.cloudKitImport)]
        #expect(seen == expected)
    }

    // MARK: - Indexing scope

    @Test("A single-era queue previews that era; a mixed queue previews the corpus")
    func indexingScopeTracksTheQueue() {
        let store = ManifestStore(bundledEntries: [
            entry("frus1969-76v01", "1969-76"),
            entry("frus1969-76v02", "1969-76"),
            entry("frus1977-80v01", "1977-80"),
        ])

        #expect(CloudSurfaceArbiter.indexingScope(
            queuedVolumeIds: ["frus1969-76v01", "frus1969-76v02"], manifest: store)
            == .subseries("1969-76"))

        // Showing one era's vocabulary while four eras download would misdescribe the wait.
        #expect(CloudSurfaceArbiter.indexingScope(
            queuedVolumeIds: ["frus1969-76v01", "frus1977-80v01"], manifest: store) == .corpus)

        // An empty or unknown queue has no era to name.
        #expect(CloudSurfaceArbiter.indexingScope(queuedVolumeIds: [], manifest: store) == .corpus)
        #expect(CloudSurfaceArbiter.indexingScope(
            queuedVolumeIds: ["not-in-manifest"], manifest: store) == .corpus)
    }

    private func entry(_ id: String, _ subseries: String) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: id, filename: "\(id).xml", subseries: subseries, title: "Volume \(id)",
            dateRange: DateRange(earliest: nil, latest: nil), publicationDate: nil,
            status: .published, editors: [], generalEditor: nil, documentCount: 0,
            sizeBytes: 500_000, tags: [])
    }
}
