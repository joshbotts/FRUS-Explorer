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
import SwiftData

// MARK: - SavedSearchFreshnessEvaluator

/// Decides whether a saved search has new results since it was last run (W-5 / #266).
///
/// ## The verdict is a count, not a guess
/// The delta is `searchCount(now) − matchCountAtLastRun` — both EXACT, uncapped counts
/// (`SearchService.searchCount` runs the same match expressions and filters as the search
/// itself), which is what makes the "+N since last run" caption safe to print. There is no
/// result-cap floor anywhere in the arithmetic.
///
/// ## What yields no badge, and why
/// - **Never run** (`freshness` nil, or no `lastRunAt`): a baseline that never existed cannot
///   have grown. No badge, and nothing is invented.
/// - **Run without a count** (a sidebar hand-off stamped `lastRunAt` with a nil baseline):
///   the evaluator BACKFILLS the baseline with the current count — writing it into the
///   record without advancing `lastRunAt` — and shows no badge this cycle. The next
///   evaluation has a baseline to compare against.
/// - **A negative delta** (results went away — a volume was removed, the index rebuilt
///   smaller): results the user has already seen disappearing is not news the NEW capsule
///   should claim. No badge; the baseline stays until the search is actually re-run.
///
/// ## Cost, and where to call it
/// A warm unfiltered count is ~10 ms, but a cold filtered one on a device that just launched
/// can take seconds — so surfaces evaluate SEQUENTIALLY from a cancellable `.task` on appear,
/// row by row, rather than fanning out one query per saved search at once.
///
/// Version history:
///   1.0 — W-5 (#266): initial implementation
@MainActor
enum SavedSearchFreshnessEvaluator {

    /// Evaluates one saved search. Returns the number of NEW results since its last run —
    /// `nil` for "no badge" (never run, no service, count failed, backfilled this cycle, or
    /// nothing new).
    ///
    /// May write to `saved` (the baseline backfill) and save `context`; the caller owns
    /// making the call from a cancellable task.
    static func newResultCount(for saved: SavedSearch,
                               service: SearchService?,
                               context: ModelContext) async -> Int? {
        guard let service,
              let freshness = saved.freshness,
              freshness.lastRunAt != nil else { return nil }
        guard let current = try? await service.searchCount(parameters: saved.searchParameters)
        else { return nil }
        guard let baseline = freshness.matchCountAtLastRun else {
            // A hand-off run stamped the time but never learned the count: adopt the current
            // count as the baseline (lastRunAt is preserved — this is a backfill, not a run).
            var mark = freshness
            mark.matchCountAtLastRun = current
            saved.freshnessData = try? JSONEncoder().encode(mark)
            try? context.save()
            return nil
        }
        return verdict(current: current, baseline: baseline)
    }

    /// The verdict arithmetic, factored out so it is testable without a live index:
    /// the positive growth since the baseline, or `nil` for "no badge" (nothing new, or
    /// results went AWAY — a shrunken index is not news the NEW capsule should claim).
    static func verdict(current: Int, baseline: Int) -> Int? {
        let delta = current - baseline
        return delta > 0 ? delta : nil
    }
}
