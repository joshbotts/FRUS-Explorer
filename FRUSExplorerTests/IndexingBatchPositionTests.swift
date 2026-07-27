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

/// The multi-volume indexing banner's "N of M" position, and the queue-grained presence
/// rule underneath it.
///
/// ## Two defects, one root
/// The position returned `nil` for entire multi-volume batches whenever downloads
/// outpaced indexing — the common case, not an edge case — because the batch-start test
/// consulted the DOWNLOAD queue to decide whether a new batch had begun. A subseries
/// downloads far faster than it indexes, so the queue was already empty, the reset
/// re-fired on every volume, and the total was pinned at 1.
///
/// Fixing that exposed the second defect, which the owner then saw on device: the banner
/// itself was keyed on the per-volume signal, which goes `nil` between volumes. It slid
/// in, ran a second or two, slid out, and slid back in — once per volume. Both are the
/// same mistake at different levels: reading a queue-level fact off a volume-level
/// signal. The position and the banner now both read ``AppState/indexingBatch``.
///
/// Version history:
///   1.0 — initial implementation, after the owner reported no queue banner on a subseries
///   2.0 — queue-grained: `indexingBatch` replaces the two loose counters, and the
///         presence rule (does the banner survive the gap between volumes?) is now
///         directly testable rather than only observable on device
@Suite("Indexing — multi-volume batch position")
@MainActor
struct IndexingBatchPositionTests {

    /// A progress update with the shape the banner cares about.
    private func update(_ volumeId: String = "v") -> IndexingProgressUpdate {
        .init(volumeId: volumeId, stage: .reading,
              completedDocuments: 10, totalDocuments: 100, docsPerSecond: 5)
    }

    @Test("A multi-volume batch reports its position")
    func multiVolumeBatchReportsPosition() {
        let state = AppState()
        state.indexingBatch = IndexingBatch(total: 27, completed: 2,
                                            latest: update("frus1969-76v01"),
                                            volumeIds: ["frus1969-76v01"])

        let position = state.indexingQueuePosition
        #expect(position?.current == 3, "1-based: two finished means we are on the third")
        #expect(position?.total == 27)
    }

    @Test("A genuine single-volume index reports no position, so the compact banner shows")
    func singleVolumeHasNoPosition() {
        let state = AppState()
        state.indexingBatch = IndexingBatch(total: 1, completed: 0, latest: update("frus1861"),
                                            volumeIds: ["frus1861"])
        #expect(state.indexingQueuePosition == nil)
    }

    @Test("No position when no queue exists")
    func idleHasNoPosition() {
        let state = AppState()
        #expect(state.indexingBatch == nil)
        #expect(state.indexingQueuePosition == nil)
    }

    @Test("A total of exactly 2 already qualifies — the threshold is not off by one")
    func twoVolumesQualifies() {
        let state = AppState()
        state.indexingBatch = IndexingBatch(total: 2, completed: 0, latest: update(), volumeIds: ["a", "b"])
        #expect(state.indexingQueuePosition?.total == 2)
    }

    // MARK: - The presence rule

    @Test("The queue survives the gap between volumes — the banner does not strobe")
    func queueSurvivesTheGapBetweenVolumes() {
        let state = AppState()
        state.indexingBatch = IndexingBatch(total: 12, completed: 3, latest: update("frus1969-76v04"),
                                            volumeIds: ["frus1969-76v04"])

        // This is exactly what `connectIndexingProgress` does on `.complete`: the
        // per-volume signal goes away while the queue does not.
        state.currentIndexingProgress = nil

        #expect(state.indexingBatch != nil, "the banner's presence must not follow one volume")
        #expect(state.indexingQueuePosition?.total == 12,
                "and the position must still read, so the banner has something to show")
    }

    @Test("The retained update keeps the banner's content alive across that gap")
    func retainedUpdateOutlivesTheVolume() {
        let state = AppState()
        state.indexingBatch = IndexingBatch(total: 12, completed: 3, latest: update("frus1969-76v04"),
                                            volumeIds: ["frus1969-76v04"])
        state.currentIndexingProgress = nil

        // The banners read `indexingBatch.latest`, never `currentIndexingProgress`. If
        // they read the latter they would render an empty volume name mid-queue.
        #expect(state.indexingBatch?.latest.volumeId == "frus1969-76v04")
    }

    @Test("Position never exceeds the total, even if completion outruns a stale estimate")
    func positionIsClampedToTotal() {
        let state = AppState()
        // The total is only ever revised upward from the backlog, but a completion can
        // land before that query returns. "Volume 13 of 12" must not be reachable.
        state.indexingBatch = IndexingBatch(total: 12, completed: 12, latest: update(), volumeIds: ["a"])
        #expect(state.indexingQueuePosition?.current == 12)
    }
}
