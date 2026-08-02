// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RelatedDocumentsRanker

/// The **pure** scoring core of the find-related model: given each generator's raw candidate
/// strengths and each scorer's `[0, 1]` scores, it normalises the generator axes, computes the
/// user-weighted total per candidate, and returns the ranked, limited rows. No I/O — every input
/// is a plain value, so the ranking logic is unit-testable without a live index (`RelatedDocumentsEngine`
/// does the `AppState`-bound fetching and hands the results here).
///
/// Version history:
///   1.0 — #308 Phase 2: initial implementation
enum RelatedDocumentsRanker {

    /// Ranks the candidate universe.
    ///
    /// - Parameters:
    ///   - anchor: The seed document, excluded from the results.
    ///   - generatorStrengths: Per generator axis, its produced candidates' **raw** strengths.
    ///     Normalised to `[0, 1]` per axis (by the axis's own max) before scoring, so one axis's
    ///     scale never dominates another's.
    ///
    ///     The normalisation is **per query and anchor-relative**: a generator axis score means
    ///     "fraction of the strongest evidence *this anchor* has on this axis", and is deliberately
    ///     not comparable across anchors. The corollary is worth stating plainly, because it is the
    ///     axis's most surprising behaviour: an axis producing exactly one candidate always reads
    ///     1.0, however weak that evidence is. Measured on the owner's index, 48,901 of 88,940
    ///     cross-referenced anchors (**54.98%**) have exactly one candidate.
    ///
    ///     Scorer axes are already absolute `[0, 1]` and are used raw.
    ///   - scorerScores: Per scorer axis, its already-`[0, 1]` scores over the candidate universe.
    ///   - records: Display record per candidate; a candidate without one is dropped (it can't render).
    ///   - weights: The user's per-axis weights. Axes at weight 0 contribute nothing.
    ///   - limit: Maximum rows returned.
    /// - Returns: `rows` sorted by total proximity descending, ties broken by composite key ascending
    ///   (a strict total order for real corpus keys — volume/document ids never contain `/` — so the
    ///   result is fully deterministic regardless of set-iteration order), truncated to `limit`; and
    ///   `rankableCount`, the number of candidates that scored above 0 *before* the limit (the honest
    ///   denominator for an "N more" overflow hint — not the raw candidate count, which includes
    ///   record-less and zero-total drops).
    static func rank(
        anchor: DocumentKey,
        generatorStrengths: [SimilarityAxis: [DocumentKey: Double]],
        scorerScores: [SimilarityAxis: [DocumentKey: Double]],
        records: [DocumentKey: CandidateRecord],
        weights: AxisWeights,
        limit: Int
    ) -> (rows: [RelatedDocumentRow], rankableCount: Int) {
        // 1. The candidate universe is the union of the generators' outputs, minus the anchor.
        var universe = Set<DocumentKey>()
        for (_, strengths) in generatorStrengths { universe.formUnion(strengths.keys) }
        universe.remove(anchor)
        guard !universe.isEmpty else { return ([], 0) }

        // 2. Normalise each generator axis's raw strengths to [0, 1] by that axis's own max.
        var generatorNormalised: [SimilarityAxis: [DocumentKey: Double]] = [:]
        for (axis, strengths) in generatorStrengths {
            let maxStrength = strengths.values.max() ?? 0
            guard maxStrength > 0 else { continue }
            generatorNormalised[axis] = strengths.mapValues { $0 / maxStrength }
        }

        // 3. Weighted-sum each candidate; keep only nonzero contributions in the breakdown.
        var rows: [RelatedDocumentRow] = []
        rows.reserveCapacity(universe.count)
        for key in universe {
            guard let record = records[key] else { continue }   // can't render without a display row
            var axisScores: [SimilarityAxis: Double] = [:]
            var total = 0.0
            for axis in SimilarityAxis.allCases {
                let weight = weights[axis]
                guard weight > 0 else { continue }
                let score = axis.isGenerator
                    ? (generatorNormalised[axis]?[key] ?? 0)
                    : (scorerScores[axis]?[key] ?? 0)
                guard score > 0 else { continue }
                axisScores[axis] = score
                total += weight * score
            }
            guard total > 0 else { continue }
            rows.append(RelatedDocumentRow(key: key, record: record, totalScore: total, axisScores: axisScores))
        }

        // 4. Rank (deterministic total-order tie-break); report the pre-limit rankable count.
        rows.sort { lhs, rhs in
            lhs.totalScore != rhs.totalScore
                ? lhs.totalScore > rhs.totalScore
                : lhs.key.compositeString < rhs.key.compositeString
        }
        return (Array(rows.prefix(max(0, limit))), rows.count)
    }
}

// MARK: - RelatedDocumentsEngine

/// Orchestrates the find-related fetch: runs the generators to build the bounded candidate
/// universe (and a display-record cache), runs the enabled scorers over it, then hands everything
/// to the pure `RelatedDocumentsRanker`.
///
/// All the heavy work is bounded: the generators are `O(neighbours)` keyed lookups and the scorers
/// batch-extract signatures over the candidate set (chunked `IN`), never per-candidate SQL. Runs on
/// the main actor (it reads `AppState`); the SQLite work happens inside the awaited actor calls, off
/// the main thread.
///
/// Version history:
///   1.0 — #308 Phase 2: archival generator + date/subseries/persons scorers; the shared-subjects
///          scorer is inert until the Phase 3 data drop
///   1.1 — #308 Phase 2b: cross-reference generator (direct citation) added to the generator set
enum RelatedDocumentsEngine {

    /// The bounded candidate producers. Archival is listed first, so on a key a candidate is produced
    /// by both, its (equivalent, `document_cache`-sourced) record wins the engine's first-generator
    /// merge. `@MainActor` because the generators conform to the main-actor-isolated `SimilarityGenerator`.
    @MainActor static let generators: [any SimilarityGenerator] = [
        ArchivalProvenanceGenerator(),
        CrossReferenceGenerator(),
    ]

    /// The rankers over the generated candidates.
    @MainActor static let scorers: [any SimilarityScorer] = [
        DateProximityScorer(),
        SubseriesScorer(),
        SharedPersonScorer(),
        SharedSubjectScorer(),
    ]

    /// The minimum candidate pool each generator fetches, regardless of the display `limit`. Scoring
    /// re-ranks the pool, so it must be *larger* than the display limit for the scorers to surface a
    /// document a generator ranked low — otherwise the top-`limit` after scoring is just the generator's
    /// own first `limit` reordered. The engine fetches `max(displayLimit, candidatePoolFloor)`.
    static let candidatePoolFloor = 120

    /// Computes the ranked related documents for an anchor.
    ///
    /// - Parameters:
    ///   - anchor: The seed document.
    ///   - anchorYear: The seed's coverage year, if known, threaded to date-sensitive generators.
    ///   - weights: The user's per-axis tuning. A scorer whose axis weight is 0 is skipped entirely
    ///     (its query never runs).
    ///   - scopeVolumeIds: The volume set to restrict candidates to (`nil` = all indexed).
    ///   - limit: Maximum rows.
    ///   - appState: Holds the live index / stores.
    /// - Returns: The ranked result, or `.empty` when the index isn't ready or nothing matched. A
    ///   failing axis is coalesced to "no contribution", never a thrown error to the caller.
    @MainActor
    static func rank(
        anchor: DocumentKey,
        anchorYear: Int?,
        weights: AxisWeights,
        scopeVolumeIds: Set<String>?,
        limit: Int,
        includeSnippets: Bool = true,
        appState: AppState
    ) async -> RelatedDocumentsResult {
        guard appState.indexingPipeline != nil else { return .empty }

        // Fetch a candidate pool at least as deep as the display limit (and never below the floor),
        // so the scorers re-rank a pool larger than what's shown rather than just reordering the
        // generator's own first `limit`.
        let candidateFetchLimit = max(limit, Self.candidatePoolFloor)

        // Generators → per-axis raw strengths + a shared display-record cache.
        var generatorStrengths: [SimilarityAxis: [DocumentKey: Double]] = [:]
        var generatorEvidence: [SimilarityAxis: [DocumentKey: Int]] = [:]
        var records: [DocumentKey: CandidateRecord] = [:]
        for generator in generators {
            let produced = (try? await generator.candidates(
                for: anchor, anchorYear: anchorYear, limit: candidateFetchLimit,
                scopeVolumeIds: scopeVolumeIds, appState: appState)) ?? []
            var strengths: [DocumentKey: Double] = [:]
            var evidence: [DocumentKey: Int] = [:]
            for candidate in produced where candidate.key != anchor {
                strengths[candidate.key] = max(strengths[candidate.key] ?? 0, candidate.strength)
                // Merged with `max`, exactly as the strength is, so the two cannot disagree about
                // which of two duplicate candidates won.
                if let count = candidate.evidenceCount {
                    evidence[candidate.key] = max(evidence[candidate.key] ?? 0, count)
                }
                if records[candidate.key] == nil { records[candidate.key] = candidate.record }
            }
            generatorStrengths[generator.axis] = strengths
            generatorEvidence[generator.axis] = evidence
        }

        let candidateKeys = Array(Set(generatorStrengths.values.flatMap(\.keys)).subtracting([anchor]))
        guard !candidateKeys.isEmpty else { return .empty }

        // Scorers over the bounded candidate set — skip any axis the user zeroed (its query is work
        // the ranker would discard anyway).
        var scorerScores: [SimilarityAxis: [DocumentKey: Double]] = [:]
        for scorer in scorers where weights[scorer.axis] > 0 {
            scorerScores[scorer.axis] = (try? await scorer.scores(
                anchor: anchor, candidates: candidateKeys, appState: appState)) ?? [:]
        }

        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: generatorStrengths,
            scorerScores: scorerScores,
            records: records,
            weights: weights,
            limit: limit)

        // Fetch a context snippet for the SHOWN rows only (already limited — a bounded batch, not
        // the candidate universe) so the researcher can judge relevance without opening each (#362).
        // Background callers that never read `.snippet` (e.g. the Project Leads aggregator, #377
        // Phase 3, which runs this up to `seedCap` times per recompute) pass `includeSnippets: false`
        // to skip the batched extraction entirely.
        // Evidence counts are attached AFTER ranking, in the same place and for the same reason as
        // the snippet fill below: `RelatedDocumentsRanker.rank` stays a pure function of its
        // inputs, so nothing here can move a row.
        var rows = ranked.rows
        for index in rows.indices {
            var evidence: [SimilarityAxis: Int] = [:]
            for axis in rows[index].axisScores.keys {
                if let count = generatorEvidence[axis]?[rows[index].key] { evidence[axis] = count }
            }
            rows[index].axisEvidence = evidence
        }

        if includeSnippets, let pipeline = appState.indexingPipeline, !rows.isEmpty {
            let keys = rows.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
            if let snippets = try? await pipeline.documentSnippets(forKeys: keys) {
                for i in rows.indices { rows[i].snippet = snippets[rows[i].key.compositeString] }
            }
        }
        return RelatedDocumentsResult(rows: rows, totalBeforeLimit: ranked.rankableCount)
    }
}
