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

/// The pending-surface cloud's gating rules and its scope resolution.
///
/// ## Why these are worth writing down
/// Every word-cloud surface this project has shipped had a gating defect that only a person
/// looking at a device could find: an arbiter branch that never fired, a strip declared but
/// never placed in the view hierarchy, a lens pinned to the wrong index under Reduce Motion,
/// and a `Canvas` that trapped on every scope. None of them were logic anyone could evaluate
/// without running the app. These rules can be.
///
/// Version history:
///   1.0 — P-2: initial implementation
@Suite("Pending cloud — gating and scope")
struct PendingCloudBackdropTests {

    // MARK: - When a cloud may show

    @Test("The ordinary case shows a cloud")
    func ordinaryCaseShows() {
        #expect(PendingCloudRule.shouldShow(isCoreReady: true, isUITestMode: false, isIndexing: false))
    }

    /// A cloud fading in over the results area races every UI test's first element lookup.
    /// The same bypass `ContentView` and `CloudSurfaceArbiter` already apply.
    @Test("UI test mode suppresses it, whatever else is true")
    func uiTestModeWins() {
        #expect(!PendingCloudRule.shouldShow(isCoreReady: true, isUITestMode: true, isIndexing: false))
        #expect(!PendingCloudRule.shouldShow(isCoreReady: false, isUITestMode: true, isIndexing: true))
    }

    /// The backdrop renders nothing without vectors, by contract — an empty cloud is just a
    /// slower blank.
    @Test("No resident vectors, no cloud")
    func coreMustBeReady() {
        #expect(!PendingCloudRule.shouldShow(isCoreReady: false, isUITestMode: false, isIndexing: false))
    }

    /// The one rule that is about this surface rather than inherited. During indexing the
    /// banner strip already carries a drifting cloud directly below the results area; a
    /// second doubles the per-frame cost on a main thread the indexer is already contending
    /// for — the surface where p95 was measured at 75 ms — and reads as noise.
    @Test("Never two drifting clouds at once")
    func indexingSuppressesTheSearchCloud() {
        #expect(!PendingCloudRule.shouldShow(isCoreReady: true, isUITestMode: false, isIndexing: true))
    }

    // MARK: - The delay

    /// Measured against the real 316,839-document index, a rare term returns in 4–47 ms. A
    /// cloud that faded in and out inside that is a flicker.
    @Test("The appearance delay outlasts a fast search but not a real wait")
    func appearanceDelayIsInTheRightBand() {
        let delay = PendingCloudBackdrop.appearanceDelay
        #expect(delay > .milliseconds(150),
                "shorter than this and the fast half of the latency distribution sees a flash")
        #expect(delay < .milliseconds(900),
                "longer than this and a genuine multi-second wait sits blank first")
    }

    // MARK: - Scope

    @MainActor
    private func store() -> ManifestStore { ManifestStore() }

    @Test("No volume filter means the corpus")
    @MainActor
    func noFilterIsCorpus() {
        #expect(CloudSurfaceArbiter.searchScope(volumeIds: nil, manifest: store()) == .corpus)
        #expect(CloudSurfaceArbiter.searchScope(volumeIds: [], manifest: store()) == .corpus)
    }

    @Test("A filter inside one subseries scopes to that subseries")
    @MainActor
    func singleSubseriesScopes() throws {
        let manifest = store()
        // Take two real volumes that genuinely share a subseries, rather than inventing ids
        // the manifest cannot resolve — an unresolvable id silently falls through to corpus,
        // which would make this test pass for the wrong reason.
        let bySubseries = Dictionary(grouping: manifest.bundledEntries, by: \.subseries)
        let group = try #require(bySubseries.first { $0.value.count >= 2 })
        let ids = group.value.prefix(2).map(\.volumeId)

        #expect(CloudSurfaceArbiter.searchScope(volumeIds: Array(ids), manifest: manifest)
                == .subseries(group.key))
    }

    @Test("A filter spanning two subseries falls back to the corpus")
    @MainActor
    func mixedSubseriesIsCorpus() throws {
        let manifest = store()
        let bySubseries = Dictionary(grouping: manifest.bundledEntries, by: \.subseries)
        let keys = Array(bySubseries.keys.sorted().prefix(2))
        #expect(keys.count == 2, "the bundled manifest must cover at least two subseries")
        let ids = keys.compactMap { bySubseries[$0]?.first?.volumeId }

        #expect(CloudSurfaceArbiter.searchScope(volumeIds: ids, manifest: manifest) == .corpus,
                "two subseries have no shared vocabulary narrower than the corpus")
    }

    /// The honest-scope property. A search narrowed by a date range, a person, user tags or
    /// an explicit document set cannot be expressed by the bundled vectors — those carry only
    /// corpus / subseries / volume grain. Falling back to the volume scope keeps the cloud
    /// true if less precise: every document the search can reach lies inside it.
    @Test("An unresolvable volume id degrades to the corpus rather than guessing")
    @MainActor
    func unknownVolumeIdDegradesToCorpus() {
        #expect(CloudSurfaceArbiter.searchScope(volumeIds: ["not-a-real-volume"],
                                                manifest: store()) == .corpus)
    }

    // MARK: - The hand-over

    /// The spinner yields to the cloud rather than sitting on top of it. Both say "still
    /// working"; two indicators competing reads worse than either alone.
    @Test("The hand-over outlasts the cloud's own fade, so they overlap rather than snap")
    func handoverOutlastsTheFadeIn() {
        // The cloud fades in over 0.45 s (WordCloudBackdropView's transition). If the spinner
        // vanished faster than that, there would be a moment with neither indicator visible —
        // a blank waiting screen, which is worse than what this replaced.
        #expect(PendingCloudBackdrop.handoverDuration >= 0.45,
                "the spinner must not clear before the cloud has arrived")
        #expect(PendingCloudBackdrop.handoverDuration < 1.5,
                "and it should not linger over the cloud once it has")
    }
}
