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

/// One indexing queue, from the moment it is created to the moment everything the user
/// downloaded is searchable.
///
/// ## Why the queue is the unit
/// `IndexingPipeline` reports per volume, and the indexing banner used to be driven
/// straight off that report: `AppState.currentIndexingProgress` goes `nil` between
/// volumes, so the banner slid in, ran for a second or two, slid out, and slid back in
/// for the next volume. Against a subseries download that is a strobe, not a status.
///
/// It was also answering the wrong question. What a researcher needs to know is *when
/// everything they downloaded is ready to search* — a property of the queue. Which
/// volume is parsing right now is detail, and belongs inside the banner rather than
/// deciding whether there is one.
///
/// So this value is created when the first volume starts indexing and survives until the
/// backlog on disk is empty. `AppState.indexingQueuePosition` and every banner surface
/// read it instead of the per-volume signal.
///
/// ## What it counts (#1757)
/// Every volume the queue holds, by id, once each: those waiting to download or under way
/// (`AppState.downloadQueue`), those whose download has landed and whose pass has not finished,
/// those waiting on disk (the backlog), and the volume whose progress opened the queue
/// (`count(_:)`). A volume moves between those lists as its download lands and its pass begins,
/// and can sit in two at once, so they are counted by id rather than added up. Until #1757 the
/// total was the download queue's length plus one, taken when the first volume began indexing
/// and raised afterwards only by the backlog, so a subseries still being queued read short:
/// measured on an iPhone 17 simulator, a queue of 27 opened at *Volume 1 of 20* and read
/// *20 of 20* with seven volumes still to come, and the volume that opened a queue, still listed
/// as downloading, was counted twice (*Volume 1 of 12* for eleven).
///
/// ## What ends it
/// The backlog — `IndexingPipeline.unindexedDownloadedVolumeIds()` — is the authority,
/// re-read after every volume, less the volumes whose pass failed in this queue
/// (`failedVolumeIds`). `AppState.indexingBatchStallTimeout` is the backstop for a volume
/// that can never be indexed and so never leaves that backlog, when its failure went
/// unreported. On iPhone and iPad the queue's end also ends its Live Activity (#1695).
///
/// Version history:
///   1.0 — queue-grained indexing banner: extracted from the two loose counters
///         (`indexingBatchTotalAtStart` / `indexingBatchCompletedCount`) that could not
///         outlive a single volume
///   1.1 — #1695: `failedVolumeIds`
///   1.2 — #1757: `count(_:)` and `uncount(_:)`, `completedVolumeIds`; the total counts the whole
///         queue, its downloads included
struct IndexingBatch: Equatable, Sendable {

    /// Volumes expected in this queue.
    ///
    /// Raised by one for each volume the queue meets (`count(_:)`), and lowered only when a
    /// download it counted is cancelled or fails for good (`uncount(_:)`). A volume moving from the
    /// download queue to the disk moves nothing, so the denominator in "Volume 3 of 12" never
    /// jumps backwards on a timing while the user is reading it.
    var total: Int

    /// Volumes finished so far.
    var completed: Int

    /// The most recent per-volume update.
    ///
    /// **Retained across the gaps between volumes** — this is what lets a banner keep
    /// showing a volume name and a progress bar during the moment when nothing is
    /// actively parsing, instead of blanking and re-entering.
    var latest: IndexingProgressUpdate

    /// Every volume this queue covers, in the order the queue met them (`count(_:)`), each once.
    /// A volume whose download is cancelled or fails for good leaves it (`uncount(_:)`).
    ///
    /// The word-cloud strip's scope is derived from this rather than from
    /// `AppState.downloadQueue`, which drains as downloads finish and then falls back to
    /// "whichever volume is parsing right now". A queue spanning two subseries would
    /// otherwise start at corpus scope and then flip to a per-volume subseries scope
    /// partway through — re-scoping, recomputing and crossfading the cloud mid-wait. It
    /// would also be a quiet lie of the kind decision O-4-2 rules out: the user would see
    /// one subseries' vocabulary while a much larger download was in flight, and would
    /// have no reason not to attribute it to the whole thing.
    var volumeIds: [String]

    /// Bumped on every advance. Lets a pending stall timeout tell "still working" from
    /// "wedged" without having to be cancelled and re-armed on every progress tick.
    var generation: Int = 0

    /// The volumes whose pass failed in this queue (`IndexingStage.failed`, #1695), until a
    /// later pass over one reports progress.
    ///
    /// Such a volume stays in the backlog, since nothing indexed it, and nothing in this queue
    /// will. The queue's end leaves it out, so the banner and the Live Activity end a couple
    /// of seconds after the last volume that can be indexed, not after the stall timeout.
    var failedVolumeIds: Set<String> = []

    /// The volumes whose pass finished in this queue (#1757). `uncount(_:)` leaves them counted:
    /// their pass is among `completed`, whatever becomes of a later download of the same volume.
    var completedVolumeIds: Set<String> = []

    /// Counts among the queue's volumes each of `volumeIds` it has not counted yet (#1757): the
    /// volume joins ``volumeIds`` and the total rises by one for it. An empty id, which names no
    /// volume (the merge that ends a whole-library pass reports one), is never counted.
    ///
    /// - Returns: Whether the total moved.
    @discardableResult
    mutating func count(_ volumeIds: some Sequence<String>) -> Bool {
        var known = Set(self.volumeIds)
        let before = total
        for volumeId in volumeIds where !volumeId.isEmpty {
            guard known.insert(volumeId).inserted else { continue }
            self.volumeIds.append(volumeId)
            total += 1
        }
        return total != before
    }

    /// Stops counting `volumeId`, whose download was cancelled or failed for good (#1757): it
    /// leaves ``volumeIds`` and the total falls by one, but never below the volumes already
    /// finished. A volume this queue never counted, or whose pass already finished in it
    /// (``completedVolumeIds``), is left as it is.
    ///
    /// - Returns: Whether the total moved.
    @discardableResult
    mutating func uncount(_ volumeId: String) -> Bool {
        guard !completedVolumeIds.contains(volumeId),
              let index = volumeIds.firstIndex(of: volumeId) else { return false }
        volumeIds.remove(at: index)
        let before = total
        total = max(total - 1, completed)
        return total != before
    }
}
