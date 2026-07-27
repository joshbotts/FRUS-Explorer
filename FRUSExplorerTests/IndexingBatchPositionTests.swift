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

/// The multi-volume indexing banner's "N of M" position.
///
/// This returned `nil` for entire multi-volume batches whenever downloads outpaced
/// indexing — the common case, not an edge case — because the batch-start test consulted
/// the DOWNLOAD queue to decide whether a new batch had begun. A subseries downloads far
/// faster than it indexes, so the queue was already empty, the reset re-fired on every
/// volume, and the total was pinned at 1.
///
/// Nothing observed it: the queue banner simply never appeared, which reads as "this app
/// indexes one volume at a time" rather than as a defect.
///
/// Version history:
///   1.0 — initial implementation, after the owner reported no queue banner on a subseries
@Suite("Indexing — multi-volume batch position")
@MainActor
struct IndexingBatchPositionTests {

    @Test("A multi-volume batch reports its position")
    func multiVolumeBatchReportsPosition() {
        let state = AppState()
        state.currentIndexingProgress = .init(volumeId: "frus1969-76v01", stage: .reading,
                                              completedDocuments: 10, totalDocuments: 100,
                                              docsPerSecond: 5)
        state.indexingBatchTotalAtStart = 27
        state.indexingBatchCompletedCount = 2

        let position = state.indexingQueuePosition
        #expect(position?.current == 3, "1-based: two finished means we are on the third")
        #expect(position?.total == 27)
    }

    @Test("A genuine single-volume index reports no position, so the compact banner shows")
    func singleVolumeHasNoPosition() {
        let state = AppState()
        state.currentIndexingProgress = .init(volumeId: "frus1861", stage: .reading,
                                              completedDocuments: 1, totalDocuments: 10,
                                              docsPerSecond: 1)
        state.indexingBatchTotalAtStart = 1
        #expect(state.indexingQueuePosition == nil)
    }

    @Test("No position when nothing is indexing, whatever the batch counters say")
    func idleHasNoPosition() {
        let state = AppState()
        state.indexingBatchTotalAtStart = 27
        state.indexingBatchCompletedCount = 2
        #expect(state.currentIndexingProgress == nil)
        #expect(state.indexingQueuePosition == nil)
    }

    @Test("A total of exactly 2 already qualifies — the threshold is not off by one")
    func twoVolumesQualifies() {
        let state = AppState()
        state.currentIndexingProgress = .init(volumeId: "v", stage: .reading,
                                              completedDocuments: 1, totalDocuments: 10,
                                              docsPerSecond: 1)
        state.indexingBatchTotalAtStart = 2
        #expect(state.indexingQueuePosition?.total == 2)
    }
}
