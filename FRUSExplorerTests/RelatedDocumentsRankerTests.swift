// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - DocumentKeyTests

/// Verifies the shared `DocumentKey`'s boundary conversions and `Codable` round-trip.
struct DocumentKeyTests {

    @Test("compositeString is the slash-joined boundary form")
    func compositeString() {
        #expect(DocumentKey(volumeId: "frus1969-76v01", documentId: "d42").compositeString
                == "frus1969-76v01/d42")
        #expect(DocumentKey("v", "d").tuple.volumeId == "v")
    }

    @Test("init?(compositeString:) round-trips and rejects malformed input")
    func compositeRoundTrip() {
        let key = DocumentKey(volumeId: "frus1969-76v01", documentId: "d42")
        #expect(DocumentKey(compositeString: key.compositeString) == key)
        // A document id never contains a slash, so first-slash split is total.
        #expect(DocumentKey(compositeString: "no-separator") == nil)
        #expect(DocumentKey(compositeString: "/d42") == nil)          // empty volume
        #expect(DocumentKey(compositeString: "frus1969-76v01/") == nil) // empty document
        #expect(DocumentKey(compositeString: "") == nil)
    }

    @Test("DocumentKey Codable round-trips")
    func codable() throws {
        let key = DocumentKey(volumeId: "frus1952-54v10", documentId: "d197")
        let data = try JSONEncoder().encode(key)
        #expect(try JSONDecoder().decode(DocumentKey.self, from: data) == key)
    }
}

// MARK: - SimilarityAxisTests

/// Verifies the axis catalogue and the generator/scorer role split.
struct SimilarityAxisTests {

    @Test("all eight axes are present")
    func allCases() {
        // + semanticSimilarity (V-3), + lexicalSimilarity (W-17 session 2)
        #expect(SimilarityAxis.allCases.count == 8)
    }

    @Test("the four generators are archival, cross-reference, semantic and lexical")
    func generatorSplit() {
        let generators = SimilarityAxis.allCases.filter(\.isGenerator)
        #expect(Set(generators) == [.archivalProvenance, .crossReference,
                                    .semanticSimilarity, .lexicalSimilarity])
    }

    /// V-3 ships the semantic axis opt-in, and the reason is not caution about the ranker: the
    /// blind panel that would have graded its early-era quality was retired as a gate, so this
    /// weight is what stands between an unmeasured axis and every user's Related list.
    @Test("semantic similarity defaults to weight 0 (experimental, opt-in)")
    func semanticDefaultOff() {
        #expect(SimilarityAxis.semanticSimilarity.defaultWeight == 0)
        #expect(SimilarityAxis.semanticSimilarity.isGenerator)
    }

    /// **Raised from 0 to 0.5** by owner decision 2026-08-21, and the ordering is the assertion
    /// that matters: the axis now shapes results but must not outrank editorial metadata.
    ///
    /// It was 0 because `document-subject-index.json` was never bundled (#308 Phase 3 gated on
    /// #261) and the scorer was plain Jaccard over subject sets — which counts a shared `War`
    /// (58,480 documents) exactly as it counts a subject appearing on one, and over sets that small
    /// produces outright ties. Phase 3 bundles the index and weights by IDF with a co-occurrence
    /// term, so a shared subject now carries evidence proportional to how much it narrows.
    @Test("shared subjects defaults to 0.5 — below editorial metadata, above nothing")
    func subjectDefaultWeight() {
        #expect(SimilarityAxis.sharedSubjects.defaultWeight == 0.5)
        #expect(SimilarityAxis.sharedSubjects.defaultWeight
                < SimilarityAxis.archivalProvenance.defaultWeight, """
            Detected topics must not outrank archival provenance. These are machine string-matches, \
            not editorial metadata — upstream's KNOWN-ISSUES calls them recall-oriented candidates.
            """)
        #expect(SimilarityAxis.sharedSubjects.defaultWeight
                < SimilarityAxis.sharedPersons.defaultWeight,
                "and must not outrank shared persons, which come from an authority file")
    }
}

// MARK: - AxisWeightsTests

/// Verifies the weight vector's defaults, subscript, and `Codable` round-trip.
struct AxisWeightsTests {

    @Test("default covers every axis; subject carries its 0.5")
    func defaults() {
        let weights = AxisWeights.default
        for axis in SimilarityAxis.allCases {
            #expect(weights[axis] == axis.defaultWeight)
        }
        #expect(weights[.sharedSubjects] == 0.5, """
            The vector must carry the axis's own default rather than a separate copy of it — a \
            second literal here is how the two drift after a weight decision.
            """)
    }

    @Test("subscript reads 0 for an unset axis and updates on assignment")
    func subscriptBehaviour() {
        var weights = AxisWeights(weights: [.archivalProvenance: 1.0])
        #expect(weights[.dateProximity] == 0)   // unset → 0
        weights[.dateProximity] = 0.4
        #expect(weights[.dateProximity] == 0.4)
    }

    @Test("AxisWeights Codable round-trips")
    func codable() throws {
        let weights = AxisWeights(weights: [.archivalProvenance: 1.0, .sharedPersons: 0.7])
        let data = try JSONEncoder().encode(weights)
        #expect(try JSONDecoder().decode(AxisWeights.self, from: data) == weights)
    }

    @Test("AxisWeights RawRepresentable round-trips for @AppStorage persistence")
    func rawRepresentable() {
        let weights = AxisWeights(weights: [.archivalProvenance: 0.9, .sharedPersons: 0.3])
        #expect(AxisWeights(rawValue: weights.rawValue) == weights)
        #expect(AxisWeights(rawValue: "not valid json") == nil)   // malformed → nil (falls back to default)
    }
}

// MARK: - RelatedDocumentsRankerTests

/// Verifies the pure scoring core: weighted-sum, per-generator normalisation, anchor exclusion,
/// record gating, tie-breaking, limiting, and the zero-signal drops.
struct RelatedDocumentsRankerTests {

    private let anchor = DocumentKey(volumeId: "v1", documentId: "d0")
    private let a = DocumentKey(volumeId: "v1", documentId: "d1")
    private let b = DocumentKey(volumeId: "v1", documentId: "d2")
    private let c = DocumentKey(volumeId: "v1", documentId: "d3")

    /// A display record for every candidate, so the record-gating never trips unless a test omits one.
    private func records(_ keys: [DocumentKey]) -> [DocumentKey: CandidateRecord] {
        Dictionary(uniqueKeysWithValues: keys.map {
            ($0, CandidateRecord(header: "Doc \($0.documentId)", dateline: nil,
                                 documentNumber: nil, isEditorialNote: false))
        })
    }

    @Test("weighted sum ranks by total proximity and records the nonzero breakdown")
    func weightedSum() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [.dateProximity: [a: 1.0, b: 0.5]],
            records: records([a, b]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .dateProximity: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a, b])                 // a (2.0) before b (1.5)
        #expect(abs(rows[0].totalScore - 2.0) < 1e-9)
        #expect(abs(rows[1].totalScore - 1.5) < 1e-9)
        #expect(rows[0].axisScores[.archivalProvenance] == 1.0)
        #expect(rows[0].axisScores[.dateProximity] == 1.0)
        #expect(rows[1].axisScores[.dateProximity] == 0.5)
    }

    @Test("each generator axis is normalised to [0,1] by its own max")
    func generatorNormalisation() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.crossReference: [a: 4, b: 2]],   // raw strengths 4 and 2
            scorerScores: [:],
            records: records([a, b]),
            weights: AxisWeights(weights: [.crossReference: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a, b])
        #expect(rows[0].axisScores[.crossReference] == 1.0)   // 4/4
        #expect(rows[1].axisScores[.crossReference] == 0.5)   // 2/4
    }

    @Test("the anchor is excluded even if a generator emits it")
    func anchorExcluded() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [anchor: 1, a: 1]],
            scorerScores: [:],
            records: records([anchor, a]),
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a])
    }

    @Test("a candidate without a display record is dropped")
    func recordGating() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [:],
            records: records([a]),   // b has no record
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a])
    }

    @Test("a candidate with zero total is omitted")
    func zeroTotalOmitted() {
        // Archival produced `a`, but its weight is 0 and no scorer touches it → total 0 → dropped.
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1]],
            scorerScores: [:],
            records: records([a]),
            weights: AxisWeights(weights: [.archivalProvenance: 0, .dateProximity: 1]),
            limit: 30).rows
        #expect(rows.isEmpty)
    }

    @Test("an inert axis with no scores contributes nothing and never crashes")
    func inertSubjectAxis() {
        // sharedSubjects weight is > 0 but the scorer returned no scores (Phase 2 inert):
        // the archival signal still ranks `a`, and no subject contribution appears.
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1]],
            scorerScores: [:],   // no sharedSubjects entries
            records: records([a]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .sharedSubjects: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a])
        #expect(rows[0].axisScores[.sharedSubjects] == nil)
    }

    @Test("ties break by composite key ascending (stable)")
    func tieBreak() {
        // a and b get identical totals; a.compositeString ("v1/d1") < b ("v1/d2").
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [:],
            records: records([a, b]),
            weights: AxisWeights(weights: [.archivalProvenance: 1]),
            limit: 30).rows
        #expect(rows.map(\.key) == [a, b])
    }

    @Test("the limit truncates the rows but rankableCount reports the full pre-limit total")
    func limitTruncates() {
        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1, c: 1]],
            scorerScores: [.dateProximity: [a: 1.0, b: 0.5, c: 0.1]],
            records: records([a, b, c]),
            weights: AxisWeights(weights: [.archivalProvenance: 1, .dateProximity: 1]),
            limit: 2)
        #expect(ranked.rows.map(\.key) == [a, b])   // top 2 by total
        #expect(ranked.rankableCount == 3)          // all three scored > 0 (the "N more" denominator)
    }

    @Test("rankableCount excludes record-less and zero-total candidates")
    func rankableCountExcludesDrops() {
        // Archival weight is 0, so only a date score gives a nonzero total. Only `a` has one; `b` is
        // zero-total (produced, has a record, but no scoring signal); `c` has no display record.
        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1, c: 1]],
            scorerScores: [.dateProximity: [a: 1.0]],
            records: records([a, b]),   // c has no record
            weights: AxisWeights(weights: [.archivalProvenance: 0, .dateProximity: 1]),
            limit: 30)
        #expect(ranked.rows.map(\.key) == [a])   // only a survives
        #expect(ranked.rankableCount == 1)       // not 3 — record-less c and zero-total b excluded
    }

    @Test("an empty candidate universe yields no rows")
    func emptyUniverse() {
        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor, generatorStrengths: [:], scorerScores: [:],
            records: [:], weights: .default, limit: 30)
        #expect(ranked.rows.isEmpty)
        #expect(ranked.rankableCount == 0)
    }

    @Test("all-zero weights yield no rows")
    func allZeroWeights() {
        let rows = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.archivalProvenance: [a: 1, b: 1]],
            scorerScores: [.dateProximity: [a: 1.0]],
            records: records([a, b]),
            weights: AxisWeights(weights: [:]),   // everything 0
            limit: 30).rows
        #expect(rows.isEmpty)
    }
}

// MARK: - RelatedDocumentsRequestTests

/// Verifies the restorable request value round-trips through `Codable` (the window-payload contract).
struct RelatedDocumentsRequestTests {

    @Test("RelatedDocumentsRequest Codable round-trips with custom tuning and scope")
    func codableRoundTrip() throws {
        var weights = AxisWeights.default
        weights[.sharedSubjects] = 0.4
        let request = RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: "frus1969-76v01", documentId: "d42"),
            anchorYear: 1971,
            weights: weights,
            scope: .subseries(key: "1969-76", anchorVolumeId: "frus1969-76v01"),
            limit: 25)
        let data = try JSONEncoder().encode(request)
        let restored = try JSONDecoder().decode(RelatedDocumentsRequest.self, from: data)
        #expect(restored == request)
        #expect(restored.weights[.sharedSubjects] == 0.4)
        #expect(restored.anchorYear == 1971)
    }
}

// MARK: - SnippetTests

/// Verifies the pure snippet helper backing the #362 find-related row context.
struct SnippetTests {

    @Test("collapses whitespace and returns short text whole")
    func shortWhole() {
        #expect(IndexingPipeline.snippet(from: "The   Secretary\n\ttelegraphed.", maxLength: 240)
                == "The Secretary telegraphed.")
        #expect(IndexingPipeline.snippet(from: "", maxLength: 240) == "")
    }

    @Test("truncates at a word boundary with an ellipsis")
    func truncates() {
        let text = "Washington telegram reporting on the negotiations concerning the disputed border region."
        let snippet = IndexingPipeline.snippet(from: text, maxLength: 30)
        #expect(snippet.count <= 31)                 // ≤ maxLength + the ellipsis
        #expect(snippet.hasSuffix("…"))
        #expect(!snippet.dropLast().hasSuffix(" "))  // trimmed to a word boundary, no dangling space
        #expect(text.hasPrefix(String(snippet.dropLast())))
    }
}

// MARK: - ProximityMathTests

/// Verifies the pure scoring arithmetic the scorers share (date decay + Jaccard).
struct ProximityMathTests {

    @Test("date decay is 1 at Δ=0, symmetric, and monotonically decreasing")
    func dateDecay() {
        #expect(ProximityMath.dateDecay(deltaYears: 0, tau: 8) == 1.0)
        // Symmetric in the sign of Δ.
        #expect(ProximityMath.dateDecay(deltaYears: -5, tau: 8)
                == ProximityMath.dateDecay(deltaYears: 5, tau: 8))
        // Farther apart → smaller, and always within (0, 1].
        let near = ProximityMath.dateDecay(deltaYears: 2, tau: 8)
        let far = ProximityMath.dateDecay(deltaYears: 20, tau: 8)
        #expect(near > far)
        #expect(far > 0 && near <= 1)
        // exp(-8/8) = e^-1 ≈ 0.3679.
        #expect(abs(ProximityMath.dateDecay(deltaYears: 8, tau: 8) - 0.36787944) < 1e-6)
    }

    @Test("Jaccard is intersection over union, 0 for disjoint or empty sets, 1 for equal sets")
    func jaccard() {
        #expect(ProximityMath.jaccard(Set([1, 2, 3]), Set([1, 2, 3])) == 1.0)
        #expect(ProximityMath.jaccard(Set([1, 2]), Set([3, 4])) == 0.0)
        #expect(ProximityMath.jaccard(Set<Int>(), Set<Int>()) == 0.0)  // no divide-by-zero
        // |{1,2,3} ∩ {2,3,4}| / |{1,2,3,4}| = 2/4 = 0.5.
        #expect(ProximityMath.jaccard(Set([1, 2, 3]), Set([2, 3, 4])) == 0.5)
        // Works over string refs too (the subject axis).
        #expect(ProximityMath.jaccard(Set(["a", "b"]), Set(["b"])) == 0.5)
    }

    @Test("logDampedMultiplicity: 1× is the floor (1.0) and the heavy tail is compressed (#356)")
    func logDampedMultiplicity() {
        // A single direct citation never drops below the floor.
        #expect(ProximityMath.logDampedMultiplicity(1) == 1.0)
        // 1 + ln(2) ≈ 1.693.
        #expect(abs(ProximityMath.logDampedMultiplicity(2) - 1.6931) < 1e-3)
        // The measured 121× outlier collapses from 121 to ~5.8, so after the ranker normalises the
        // cross-ref axis by its max, a 1× partner scores 1.0/5.8 ≈ 0.17, not raw's 1/121 ≈ 0.008.
        let outlier = ProximityMath.logDampedMultiplicity(121)
        #expect(abs(outlier - 5.7957) < 1e-3)
        #expect(1.0 / outlier > 0.17)   // the single-citation partner stays visible
        // Monotonic: more citations still ranks higher.
        #expect(ProximityMath.logDampedMultiplicity(5) > ProximityMath.logDampedMultiplicity(2))
        // count ≤ 0 clamps to the floor (never -inf).
        #expect(ProximityMath.logDampedMultiplicity(0) == 1.0)
    }
}

// MARK: - SharedSubjectScorerCostTests

/// Prices the `sharedSubjects` axis against the **real bundled index** (#1025).
///
/// ## Why this measurement had to exist before #1021 lands
/// `ProjectLeadsService.recompute` runs the whole multi-axis rank once per seed, up to `seedCap`
/// (40) times, on the main actor. `RelatedDocumentsEngine` skips a scorer whose weight is 0, so
/// today the shared-subject scorer costs existing users **nothing** — every stored tuning spells
/// out `sharedSubjects:0.0`, which is the #1021 defect. Fixing #1021 turns that cost on for every
/// existing user at once. Pricing it afterwards would be measuring a regression already shipped.
///
/// ## What this can and cannot answer
/// It prices the SCORER, not a recompute: the engine's other cost is SQLite work behind `await`s,
/// which needs a live index and a device library. So this is the reproducible half — an
/// algorithmic guard that runs in CI — and the field half is the `OSSignposter` intervals
/// `recompute` emits. The two together are what #1025 asked for.
///
/// Assertions are ratio-and-ceiling rather than tight wall-clock, deliberately: this suite runs in
/// parallel with the rest, and a tight budget measures machine load rather than the scorer.
///
/// Version history:
///   1.0 — Session 2026-08-21: #1025
@Suite("Shared-subject scorer cost (#1025)")
struct SharedSubjectScorerCostTests {

    /// Real document keys from the bundled index, in artifact order — the same documents the
    /// scorer meets in production, with production's subject cardinality.
    @MainActor
    private func realKeys(limit: Int) throws -> [DocumentKey] {
        let index = try #require(DocumentSubjectStore.shared,
                                 "document-subject-index.json must decode from the app bundle")
        var keys: [DocumentKey] = []
        for volumeId in index.taggedVolumeIds {
            for row in index.bucketRows(forVolume: volumeId) {
                keys.append(DocumentKey(volumeId: volumeId, documentId: row.documentId))
                if keys.count >= limit { return keys }
            }
        }
        return keys
    }

    /// An anchor with several subjects, so the `O(shared²)` pair loop actually runs — an anchor
    /// with one subject would price the cheap path and call it the cost.
    @MainActor
    private func richAnchor() throws -> DocumentKey {
        let index = try #require(DocumentSubjectStore.shared)
        var best: (key: DocumentKey, count: Int)?
        for volumeId in index.taggedVolumeIds.prefix(40) {
            for row in index.bucketRows(forVolume: volumeId) {
                let key = DocumentKey(volumeId: volumeId, documentId: row.documentId)
                let count = index.subjects(forDocument: key).count
                if count > (best?.count ?? 0) { best = (key, count) }
            }
        }
        let found = try #require(best, "no tagged document found in the bundled index")
        #expect(found.count > 1, """
            The richest anchor in 40 volumes carries \(found.count) subject(s), so the pair term \
            never runs and this suite is pricing the cheap path. The scorer's cost claim would be \
            unmeasured.
            """)
        return found.key
    }

    /// The headline number, and an algorithmic ceiling around it.
    ///
    /// **The unit is cost PER CANDIDATE, and that is not a hedge — it is the only honest unit.**
    /// `perSeedRelatedLimit` is 30, but the engine scores the whole candidate UNIVERSE before
    /// limiting, and that universe is whatever the four generators return for a given anchor: it
    /// has no fixed cap, so no single number here can be "the" recompute cost. 1,000 candidates is
    /// a plausible order of magnitude and a stable basis for a regression guard. Turning it into a
    /// recompute figure needs the universe size from a real library, which is what
    /// `ProjectLeadsService.RecomputeCost.candidatesRanked` and the `rank-seed` signposts supply.
    ///
    /// Measured 2026-08-21 (iPhone 17 simulator): **22.6 µs per candidate** — 22.58 ms for 1,000,
    /// 985 of which scored. At 40 seeds that is ~181 ms of added main-actor time for a
    /// 200-candidate universe and ~900 ms for a 1,000-candidate one.
    @MainActor
    @Test("Scoring a realistic candidate set stays well inside a recompute budget")
    func scorerCostAtRealisticScale() async throws {
        let appState = AppState()
        let anchor = try richAnchor()
        let candidates = try realKeys(limit: 1_000)
        #expect(candidates.count == 1_000, "the bundled index must supply 1,000 real keys")

        let scorer = SharedSubjectScorer()
        _ = try await scorer.scores(anchor: anchor, candidates: candidates, appState: appState)  // warm

        let started = ContinuousClock.now
        let scores = try await scorer.scores(anchor: anchor, candidates: candidates, appState: appState)
        let elapsed = ContinuousClock.now - started

        // A generous ceiling: 40 seeds × this must stay far under a second of main-actor time.
        // It fails on an algorithmic regression, not on a loaded machine.
        #expect(elapsed < .milliseconds(250), """
            Scoring 1,000 real candidates took \(elapsed) — measured at 22.58 ms when this guard \
            was written, so a failure here is roughly a 10x regression, not scheduler noise. At \
            seedCap = \(ProjectLeadsService.seedCap) seeds that is \
            \(elapsed * ProjectLeadsService.seedCap) of added main-actor time per recompute. \
            \(scores.count) of 1,000 candidates scored.
            """)
    }

    /// The shape guard: cost must be linear in candidates. The per-candidate work is bounded by
    /// the anchor's own subject count, so nothing here should scale with the candidate set — an
    /// accidental cross-product would show up as super-linear growth long before it showed up as a
    /// slow app.
    @MainActor
    @Test("Cost grows linearly in the candidate count, not faster")
    func costIsLinearInCandidates() async throws {
        let appState = AppState()
        let anchor = try richAnchor()
        let small = try realKeys(limit: 500)
        let large = try realKeys(limit: 2_000)
        let scorer = SharedSubjectScorer()
        _ = try await scorer.scores(anchor: anchor, candidates: large, appState: appState)  // warm

        let smallStart = ContinuousClock.now
        _ = try await scorer.scores(anchor: anchor, candidates: small, appState: appState)
        let smallTime = ContinuousClock.now - smallStart

        let largeStart = ContinuousClock.now
        _ = try await scorer.scores(anchor: anchor, candidates: large, appState: appState)
        let largeTime = ContinuousClock.now - largeStart

        // 4x the candidates must cost well under 8x the time. Loose enough to survive scheduler
        // noise on a loaded machine, tight enough that a quadratic term cannot hide.
        #expect(largeTime < smallTime * 8, """
            500 candidates took \(smallTime), 2,000 took \(largeTime) — a 4x input grew cost by \
            more than 8x, which is superlinear. The per-candidate work is supposed to be bounded \
            by the ANCHOR's subject count.
            """)
    }
}
