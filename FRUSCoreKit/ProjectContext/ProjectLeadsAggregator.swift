// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProjectLeadCandidate

/// One aggregated project lead (#377 Phase 3): a candidate document keyed `"volumeId/documentId"`,
/// its summed relatedness across the project's seed, and which seeds contributed it.
struct ProjectLeadCandidate: Equatable, Sendable {
    /// The lead document key, `"volumeId/documentId"`.
    let key: String
    /// Summed relatedness across every seed this document relates to.
    let aggregateScore: Double
    /// The `"volumeId/documentId"` seeds that surfaced this lead (sorted, de-duplicated).
    let contributingSeedKeys: [String]
}

// MARK: - ProjectLeadsAggregator

/// Aggregates the per-seed related-document rankings (#308 engine output) into ranked project
/// leads (#377 Phase 3). Pure and deterministic.
enum ProjectLeadsAggregator {

    /// Aggregates related documents across a project's seed into ranked leads.
    ///
    /// A document's `aggregateScore` is the **sum** of its relatedness over every seed it
    /// relates to, so a document related to *many* seeds — or strongly to a few — rises. This
    /// rewards recurrence (more seeds → more terms) and strength (higher per-seed scores) in a
    /// single number. Documents already in the seed are excluded (they're already engaged).
    ///
    /// - Parameters:
    ///   - perSeedRelated: For each seed key, its ranked related documents as
    ///     `(key, score)` pairs (from `RelatedDocumentRow.compositeString` / `.totalScore`).
    ///   - seedKeys: The project's full seed set — leads in this set are dropped.
    ///   - dismissedKeys: Leads the researcher has dismissed. A dismissed lead no longer consumes a
    ///     display slot (so dismissing one lets the next-best backfill), but it is still *returned*
    ///     while it remains in the ranking so `applyLeads` keeps it hidden and it doesn't resurface;
    ///     it is dropped only once it leaves the ranking entirely.
    ///   - limit: Maximum **visible** (non-dismissed) leads to return.
    /// - Returns: Up to `limit` non-dismissed leads (ranked by `aggregateScore` descending, key
    ///   ascending as a stable tie-break), followed by every dismissed lead still in the ranking.
    static func aggregate(perSeedRelated: [(seed: String, related: [(key: String, score: Double)])],
                          seedKeys: Set<String>,
                          dismissedKeys: Set<String> = [],
                          limit: Int) -> [ProjectLeadCandidate] {
        var scoreByKey: [String: Double] = [:]
        var seedsByKey: [String: Set<String>] = [:]
        for (seed, related) in perSeedRelated {
            for candidate in related where !seedKeys.contains(candidate.key) {
                scoreByKey[candidate.key, default: 0] += candidate.score
                seedsByKey[candidate.key, default: []].insert(seed)
            }
        }
        let ranked = scoreByKey.keys
            .map { key in
                ProjectLeadCandidate(
                    key: key,
                    aggregateScore: scoreByKey[key] ?? 0,
                    contributingSeedKeys: (seedsByKey[key] ?? []).sorted())
            }
            .sorted { lhs, rhs in
                lhs.aggregateScore != rhs.aggregateScore
                    ? lhs.aggregateScore > rhs.aggregateScore
                    : lhs.key < rhs.key
            }
        // Fill `limit` with the top-ranked NON-dismissed leads (so a dismissed slot backfills with the
        // next-best), and retain every dismissed lead still in the ranking (hidden, non-resurfacing).
        let cap = max(0, limit)
        var visible: [ProjectLeadCandidate] = []
        var retainedDismissed: [ProjectLeadCandidate] = []
        for candidate in ranked {
            if dismissedKeys.contains(candidate.key) {
                retainedDismissed.append(candidate)
            } else if visible.count < cap {
                visible.append(candidate)
            }
        }
        return visible + retainedDismissed
    }
}
