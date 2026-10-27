// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SavedSearchFreshness

/// The `SavedSearch` run watermark (W-5 / #266): when the search was last run, what it
/// matched then, and how many volumes were indexed on the device that ran it.
///
/// `indexedVolumeCountAtLastRun` is context for the surfaces, not part of the verdict math:
/// a "+12 since last run" caption after six new volumes indexed is growth of the library, not
/// of the archive — a surface may choose to say so.
///
/// Every field is optional and the decoder is hand-written per-field-tolerant (`try?` around
/// each), so a blob written by a build with more fields — or a corrupted one — degrades to
/// whatever still parses rather than discarding the whole watermark.
///
/// Version history:
///   1.0 — W-5 (#266): initial implementation
///   1.1 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved here from the app's
///          `Models/SavedSearch.swift`, public, with the rules of "+N since last run" that
///          `SavedSearchFreshnessEvaluator` applied (``evaluation(currentCount:)``,
///          ``verdict(current:baseline:)``), the mark a run writes (``run(at:matchCount:indexedVolumeCount:)``)
///          and its blob (``encoded``, ``decoded(from:)``), for the web edition's saved searches;
///          the count and the store stay the host's
public struct SavedSearchFreshness: Codable, Equatable, Sendable {
    /// When the search was last recalled and run. `nil` never happens in a freshly-recorded
    /// mark, but survives decoding a partial blob.
    public var lastRunAt: Date?
    /// The exact match count that run reported (`searchCount` — uncapped), the baseline the
    /// "+N since last run" delta is computed against. `nil` when the last run came through a
    /// hand-off site that never learns the count; the freshness evaluator backfills it.
    public var matchCountAtLastRun: Int?
    /// How many volumes were indexed on the device at that run.
    public var indexedVolumeCountAtLastRun: Int?

    public init(lastRunAt: Date?, matchCountAtLastRun: Int?, indexedVolumeCountAtLastRun: Int?) {
        self.lastRunAt = lastRunAt
        self.matchCountAtLastRun = matchCountAtLastRun
        self.indexedVolumeCountAtLastRun = indexedVolumeCountAtLastRun
    }

    private enum CodingKeys: String, CodingKey {
        case lastRunAt, matchCountAtLastRun, indexedVolumeCountAtLastRun
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastRunAt = try? container.decodeIfPresent(Date.self, forKey: .lastRunAt)
        matchCountAtLastRun = try? container.decodeIfPresent(Int.self, forKey: .matchCountAtLastRun)
        indexedVolumeCountAtLastRun = try? container.decodeIfPresent(
            Int.self, forKey: .indexedVolumeCountAtLastRun)
    }
}

// MARK: - The stored mark

extension SavedSearchFreshness {

    /// The mark a run of a saved search writes: `date`, the run's match count, and the device's
    /// indexed-volume count.
    ///
    /// A `nil` count, from a hand-off site that never learns it (the sidebar shortcuts), still
    /// advances `lastRunAt`, and the baseline is CLEARED, not kept: the user just saw the current
    /// results, so the old baseline would keep claiming "+N" about results already seen.
    /// ``evaluation(currentCount:)`` backfills a nil baseline with the current count (showing no
    /// badge for that cycle).
    ///
    /// - Parameters:
    ///   - date: When the search ran.
    ///   - matchCount: The exact count the run reported, or `nil` when the site never learns it.
    ///   - indexedVolumeCount: How many volumes the device had indexed.
    /// - Returns: The mark to store.
    public static func run(at date: Date, matchCount: Int?,
                           indexedVolumeCount: Int?) -> SavedSearchFreshness {
        SavedSearchFreshness(lastRunAt: date,
                             matchCountAtLastRun: matchCount,
                             indexedVolumeCountAtLastRun: indexedVolumeCount)
    }

    /// The mark as the record stores it (`SavedSearch.freshnessData`): JSON from a plain
    /// `JSONEncoder`, a date as seconds since 2001 and a field with no value left out, or `nil` if
    /// encoding fails, which leaves the record with no watermark, as before.
    public var encoded: Data? {
        try? JSONEncoder().encode(self)
    }

    /// The mark a stored blob holds, or `nil` when none was ever recorded or the blob does not
    /// parse — which surfaces read as "never run", showing no badge rather than a fake zero.
    ///
    /// - Parameter data: The record's `freshnessData`.
    /// - Returns: The mark, or `nil`.
    public static func decoded(from data: Data?) -> SavedSearchFreshness? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(SavedSearchFreshness.self, from: data)
    }
}

// MARK: - "+N since last run"

extension SavedSearchFreshness {

    /// What one evaluation of a saved search's mark shows (W-5 / #266).
    ///
    /// ## The verdict is a count, not a guess
    /// The delta is `searchCount(now) − matchCountAtLastRun` — both EXACT, uncapped counts
    /// (`SearchService.searchCount` runs the same match expressions and filters as the search
    /// itself), which is what makes the "+N since last run" caption safe to print. There is no
    /// result-cap floor anywhere in the arithmetic.
    public enum Evaluation: Equatable, Sendable {
        /// No badge: never run, no count, nothing new, or fewer results than the baseline.
        case noBadge
        /// "+N since last run": how many results the search has gained.
        case newResults(Int)
        /// No badge this cycle, and a baseline to keep: the host stores this mark, which holds the
        /// current count with `lastRunAt` unchanged — a backfill, not a run.
        case backfill(SavedSearchFreshness)
    }

    /// Whether an evaluation counts this search at all: only once a run has stamped its time. A
    /// baseline that never existed cannot have grown, so the host need not take a count.
    public var hasRun: Bool { lastRunAt != nil }

    /// Evaluates the mark against the saved search's count now, taken by the host of the saved
    /// search's own parameters — not of a run that put rows on screen, which can be another search
    /// (`SearchParameters.runningInside(workingCorpus:)`).
    ///
    /// ## What yields no badge, and why
    /// - **Never run** (no `lastRunAt`): nothing is invented.
    /// - **No count** (the count failed, or the host has no index yet).
    /// - **Run without a count** (a sidebar hand-off stamped `lastRunAt` with a nil baseline): the
    ///   evaluation BACKFILLS the baseline with the current count and shows no badge this cycle.
    ///   The next evaluation has a baseline to compare against.
    /// - **A negative delta** (results went away — a volume was removed, the index rebuilt
    ///   smaller): results the user has already seen disappearing is not news the NEW capsule
    ///   should claim. No badge; the baseline stays until the search is actually re-run.
    ///
    /// - Parameter currentCount: The saved search's exact count now, or `nil` when there is none.
    /// - Returns: The evaluation.
    public func evaluation(currentCount: Int?) -> Evaluation {
        guard hasRun, let current = currentCount else { return .noBadge }
        guard let baseline = matchCountAtLastRun else {
            var mark = self
            mark.matchCountAtLastRun = current
            return .backfill(mark)
        }
        return Self.verdict(current: current, baseline: baseline).map(Evaluation.newResults) ?? .noBadge
    }

    /// The verdict arithmetic, factored out so it is testable without a live index:
    /// the positive growth since the baseline, or `nil` for "no badge" (nothing new, or
    /// results went AWAY — a shrunken index is not news the NEW capsule should claim).
    public static func verdict(current: Int, baseline: Int) -> Int? {
        let delta = current - baseline
        return delta > 0 ? delta : nil
    }
}
