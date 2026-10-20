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
struct IndexingBatch: Equatable, Sendable {

    /// Volumes expected in this queue.
    ///
    /// Only ever revised upward, so the denominator in "Volume 3 of 12" never jumps
    /// backwards while the user is reading it.
    var total: Int

    /// Volumes finished so far.
    var completed: Int

    /// The most recent per-volume update.
    ///
    /// **Retained across the gaps between volumes** — this is what lets a banner keep
    /// showing a volume name and a progress bar during the moment when nothing is
    /// actively parsing, instead of blanking and re-entering.
    var latest: IndexingProgressUpdate

    /// Every volume this queue covers, captured when it is created and unioned with the
    /// backlog as it is discovered.
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
}
