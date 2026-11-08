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

/// Generates candidates by nearness in the corpus's embedding space.
///
/// This is the axis the whole vector program exists for, and the only one that can reach a document
/// with no archival key and no citation. Every other generator needs an editorial or archival hook
/// that the early corpus does not carry.
///
/// **Re-measured 2026-09-06: 45,030 of 316,839 documents, and the predicate matters more than the
/// number.** The figure this comment used to give — 46,234 — came from the lexical-neighbours
/// assessment and travelled without the rule that produced it, so it could not be reproduced or
/// falsified. The rule is: *no row in `document_sources`, and no `cross_references` row on either
/// side with `is_broken = 0`* (a NULL `target_volume_id` coalesced to the source's). State it
/// beside the count; a bare number here is what let the stale one survive.
///
/// **And the pre-1900 fact, restored in the direction its source actually states it.** The old
/// comment read "98.2% of them pre-1900", which inverts the assessment it came from — that
/// document says *pre-1900 is 98.2% zero-candidate*, a statement about early documents, not about
/// the composition of the zero-candidate set. Re-measured, both directions differ from it:
/// **93.9% of pre-1900 documents are zero-candidate** (33,729 documents, 31,667 of them with no
/// candidate), while only **70.3% of zero-candidate documents are pre-1900**. The first is the
/// number that argues for this axis; the second is what the old sentence appeared to claim and was
/// never true.
///
/// **Coverage against that population, which is the half the design actually asks for:** the
/// bundled index holds a vector for **43,552 of the 45,030 (96.7%)**; **1,478 are unreachable
/// because they carry no vector at all**, the corpus being 314,571 vectored rows against 316,839
/// display rows. Do NOT compare this with the lexical axis's 32,956 — that measures a different
/// population (source-noted rows only, 264,487) under a stricter served rule.
///
/// ## The pipeline, and why each stage is where it is
///
/// 1. **Candidates come from the bundled Tier-1 block**, a sign vector per document (one bit per
///    shipping dimension) for all 314,616 documents — so candidate generation works with *zero
///    volumes downloaded* and reaches volumes the reader does not have. A full corpus scan is
///    1.43 ms, measured at the 256 width on an M1 Max; the ladder spike puts the same kernel
///    about 1.6x slower at the shipped 512.
/// 2. **The display fence is applied inside the scan**, as a precomputed per-row eligibility byte
///    array built from the indexed volumes' row ranges. Filtering afterwards would let ineligible
///    rows consume the candidate pool — measured in V-2 as a 50-candidate request returning 28.
/// 3. **Scoring is exact int8 cosine** against Tier-2 shards. A candidate whose shard this device
///    does not hold is **dropped, not scored** — an absent shard is missing evidence, and a zero
///    would be a claim of dissimilarity.
/// 4. **Missing shards are queued for fetch**, so a library that has never used the axis warms up
///    across a few uses rather than downloading ~162 MB the first time anyone opens it.
///
/// ## What it deliberately does not do
///
/// It does not fall back to ranking by Hamming distance when a shard is missing. Raw binary recalls
/// 0.53 of the exact top ten at 256 (V-0's raw binary tier) where the shipped 512-width funnel
/// recalls 0.851, and the two are different scales — a list mixing them would be sorted by a
/// number that means one thing in some rows and another thing in the rest. Fewer honest rows
/// beat more incomparable ones.
///
/// ## Experimental
///
/// The axis ships at weight 0.5 since 2026-09-10 (raised from 0 by owner decision), and keeps
/// "experimental" in its name — maturity, not worth. The blind panel that would have
/// graded early-era quality was retired as a gate (owner decision 2026-08-12) in favour of tester
/// feedback, so **pre-1900 quality is an unmeasured unknown** — the corpus-scale gate reaches 572
/// pre-1900 queries because the `dN` citation idiom postdates 1945. Say so wherever this axis is
/// described.
///
/// Version history:
///   1.0 — V-3: initial implementation
///   1.1 — S-3: the off-index leads channel (volume counts, plus document grain where a
///          Tier-2 shard is already present)
///   1.2 — B4 (#1659): every cosine the axis vends, re-scores or names off-index is calibrated
///          for the generation's model (`retrieval.calibratedDocumentScore`), so EmbeddingGemma 2's
///          scores read, and weigh in the sum, on the scale the 300m's did
///   1.3 — 2026-11-08: FRUS Explorer Light's S23a — the declaration, its pure rules and
///          ``SemanticOffIndexLeads`` are FRUSCoreKit's; the generation, the re-score and the
///          off-index scan read SemanticVectorsKit's bundled tiers and the app's shard store, so
///          they stay in the app (`SemanticSimilarityGenerator+App.swift`), and the engine reaches
///          them through the host's ``SemanticSimilaritySource`` (``RelatedDocumentsDependencies/semantic``),
///          which a host without the semantic stack leaves out
@MainActor
struct SemanticSimilarityGenerator: SimilarityGenerator {

    var axis: SimilarityAxis { .semanticSimilarity }

    /// Creates the generator.
    init() {}

    /// The host's semantic candidates, or none when the host gives no semantic axis.
    ///
    /// The generation is the host's: the app's reads SemanticVectorsKit's bundled tiers and its
    /// shard store and fetches a missing shard, in `SemanticSimilarityGenerator+App.swift`, which is
    /// why it stays in the app until FRUS Explorer Light's phase 4.
    func candidates(
        for anchor: DocumentKey,
        anchorYear: Int?,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        dependencies: RelatedDocumentsDependencies
    ) async throws -> GeneratedPool {
        guard let semantic = dependencies.semantic else { return .empty }
        return try await semantic.candidates(
            for: anchor, anchorYear: anchorYear, limit: limit, scopeVolumeIds: scopeVolumeIds)
    }

    /// The host's off-index leads for an anchor (S-3), or `.none` when the host gives no semantic
    /// axis. The scan is the host's, as the generation is.
    static func offIndexSection(
        for anchor: DocumentKey,
        limit: Int,
        scopeVolumeIds: Set<String>?,
        dependencies: RelatedDocumentsDependencies
    ) async -> SemanticOffIndexLeads {
        guard let semantic = dependencies.semantic else { return .none }
        return await semantic.offIndexSection(
            for: anchor, limit: limit, scopeVolumeIds: scopeVolumeIds)
    }

    // MARK: - Re-scoring the other axes' candidates (S-1)

    /// What a re-score pass should target, and the floor it must clear — the decision, separated
    /// from the arithmetic so a test can drive it without a shard store.
    ///
    /// Returns `nil` when this axis vended nothing: with no band there is no floor, and a re-score
    /// with no floor is the flat-lift failure the type's own note measures. **Refusing is the
    /// answer, not falling back to a constant** — the anchor's band runs 0.543 to 0.836 across
    /// anchors, so no constant is a stand-in for it.
    ///
    /// - Parameters:
    ///   - vended: This axis's own candidates and their calibrated cosines.
    ///   - allCandidates: Every key the generators produced.
    ///   - anchor: The document being related, which is never its own candidate.
    /// - Returns: The keys to score and the floor, or `nil` when there is no band to floor against.
    nonisolated static func rescorePlan(
        vended: [DocumentKey: Double], allCandidates: Set<DocumentKey>, anchor: DocumentKey
    ) -> (targets: Set<DocumentKey>, floor: Double)? {
        guard let floor = vended.values.min() else { return nil }
        let targets = allCandidates.subtracting(vended.keys).subtracting([anchor])
        guard !targets.isEmpty else { return nil }
        return (targets, floor)
    }

    /// Folds a re-score back into what the generator pass produced for this axis.
    ///
    /// Separated from the engine for the reason ``rescorePlan(vended:allCandidates:anchor:)`` is:
    /// the engine's own entry point needs a live `IndexingPipeline` and a semantic source, so a rule
    /// left inline there is a rule only an indexed fixture drives, and then only the cases that
    /// fixture happens to hold.
    ///
    /// Two things happen, and the second is easy to forget. The scores merge with `max`, matching
    /// how the generator loop merges duplicate candidates — though the two sides are disjoint by
    /// construction, since `rescorePlan` subtracts the vended keys, so the closure can never
    /// actually fire. And a re-scored candidate **gets the same evidence chip a vended one gets**,
    /// from the same pure function of the score: it contributes to the ranker's `total` identically,
    /// so a row that rises with no semantic chip is a row the panel cannot explain. Without it the
    /// two populations differ on first paint — vended rows carry the generator's label, re-scored
    /// rows fall through to `.percent` — until `SemanticSharedTerms` overwrites both with the
    /// shared vocabulary. The floor is what makes the chip honest: it says the pair is at least as
    /// near as the weakest neighbour this axis was already showing one for.
    ///
    /// An existing label is never overwritten, so a vended candidate keeps the generator's own.
    ///
    /// - Parameters:
    ///   - rescored: What ``reScore(anchor:candidates:floor:store:)`` returned. Empty is a no-op.
    ///   - strengths: This axis's vended strengths.
    ///   - labels: This axis's vended evidence labels.
    /// - Returns: The merged strengths and labels.
    nonisolated static func applyReScore(
        _ rescored: [DocumentKey: Double],
        strengths: [DocumentKey: Double],
        labels: [DocumentKey: String]
    ) -> (strengths: [DocumentKey: Double], labels: [DocumentKey: String]) {
        guard !rescored.isEmpty else { return (strengths, labels) }
        var labels = labels
        for (key, score) in rescored where labels[key] == nil {
            labels[key] = Self.evidenceLabel(for: score)
        }
        return (strengths.merging(rescored) { max($0, $1) }, labels)
    }

    /// The volumes a candidate may come from: indexed, intersected with the caller's scope.
    ///
    /// - Parameters:
    ///   - indexed: Volumes with rows in `document_cache`.
    ///   - scope: The caller's volume restriction, if any.
    /// - Returns: The eligible volume ids.
    nonisolated static func eligibleVolumeIDs(indexed: Set<String>, scope: Set<String>?) -> Set<String> {
        guard let scope else { return indexed }
        return indexed.intersection(scope)
    }

    /// The "why related" chip's text for a calibrated cosine.
    ///
    /// A percentage of a cosine is the honest thing to show here and the only thing this axis knows:
    /// it has no shared term, no citation and no archival container to name. The design's
    /// shared-distinctive-terms chip is a render-time computation over the displayed rows and is a
    /// separate piece of work; until it exists, this says what it measured rather than implying a
    /// relationship it did not find.
    ///
    /// - Parameter score: The approximate cosine, through the generation's calibration (B4).
    /// - Returns: A short label.
    nonisolated static func evidenceLabel(for score: Double) -> String {
        let percent = Int((min(1.0, max(0.0, score)) * 100).rounded())
        return String(
            localized: "related.semantic.evidence",
            defaultValue: "Semantic match · \(percent)%")
    }

}

// MARK: - SemanticSimilaritySource

/// The semantic axis's three passes, which a host with the semantic stack gives the engine through
/// ``RelatedDocumentsDependencies/semantic``: the app's, over SemanticVectorsKit's bundled tiers and
/// its shard store, is `AppSemanticSimilaritySource`. A host without one, as FRUS Explorer Light is
/// until its phase 4, leaves the axis out, and it contributes nothing.
///
/// What a host outside the app needs to fill the passes' values beyond `.none` is still internal:
/// the off-index leads' initialisers, ``SemanticSimilarityGenerator/evidenceLabel(for:)`` and
/// `RelatedDocumentsCounts`' off-index lines. The host that gains a semantic stack makes them public.
///
/// Version history:
///   1.0 — 2026-11-08: FRUS Explorer Light's S23a
@MainActor
public protocol SemanticSimilaritySource: Sendable {
    /// The axis's own candidates for `anchor`: calibrated cosines, absolute in `[0, 1]`; the app's
    /// labels each with ``SemanticSimilarityGenerator/evidenceLabel(for:)``.
    func candidates(for anchor: DocumentKey, anchorYear: Int?, limit: Int,
                    scopeVolumeIds: Set<String>?) async throws -> GeneratedPool

    /// What the axis sees in volumes the host has not indexed (S-3), or `.none`.
    func offIndexSection(for anchor: DocumentKey, limit: Int,
                         scopeVolumeIds: Set<String>?) async -> SemanticOffIndexLeads

    /// Calibrated cosines for the other axes' candidates that clear `floor` (S-1), fetching nothing.
    func reScore(anchor: DocumentKey, candidates: Set<DocumentKey>,
                 floor: Double) async -> [DocumentKey: Double]
}

// MARK: - SemanticOffIndexLeads

/// What the semantic axis can see in volumes the reader has **not** indexed (V-3 §6.2(a)).
///
/// Two channels, and what separates them is the shard. The **volume** channel needs nothing but
/// the bundled sign bits, so it always answers: a count, and the volumes holding it. The
/// **document** channel needs a volume's Tier-2 shard to be on this device already, and names
/// documents only where one is — the register `SemanticUndownloadedRow` already ships in search
/// (a document id, its volume's manifest title, a score chip), approved for this surface by the
/// owner on 2026-09-06.
///
/// **Nothing here queues a shard fetch, and that is a decision rather than an omission.** Search
/// queues (`SemanticQuerySearcher.fetchQueueDepth`) because the reader typed a question; here
/// they merely opened a document, and prefetching the top volumes would spend ~294 KB each on
/// volumes they have never asked for. So the document channel is opportunistic — it enriches the
/// section where search or a past download has already paid for the shard, and its absence costs
/// the reader nothing the volume channel does not already say.
public struct SemanticOffIndexLeads: Equatable, Sendable {

    /// One volume beyond the reader's library, and how many of its documents cleared the cut.
    public struct VolumeLead: Equatable, Sendable, Identifiable {
        /// The volume id. The caller titles it from the manifest, which is the one surface that
        /// knows a volume this device does not hold.
        public let volumeID: String
        /// Documents in it at or better than the anchor's own on-index cut.
        public let count: Int
        public var id: String { volumeID }
    }

    /// One document named outright, because its volume's shard was already on this device.
    public struct DocumentLead: Equatable, Sendable, Identifiable {
        public let volumeID: String
        public let documentID: String
        /// The exact cosine through the generation's calibration (B4) — the same scale as the
        /// ranked rows above it. Never a Hamming distance rescaled to look like one; the axis
        /// refuses that mix everywhere else.
        public let score: Double
        public var id: String { "\(volumeID)/\(documentID)" }
    }

    /// Documents at or better than the anchor's own on-index cut.
    public var documentCount: Int
    /// The volumes holding them, most matches first.
    public var volumes: [VolumeLead]
    /// `true` when the scan's cap bound, so `documentCount` is a floor and the copy must say so.
    public var isCapped: Bool
    /// The kept corpus rows, nearest-first — carried so the document channel need not rescan.
    public var rows: [Int] = []
    /// The document channel's rows, best first. Empty when no off-index shard was present.
    public var documents: [DocumentLead] = []

    public static let none = SemanticOffIndexLeads(documentCount: 0, volumes: [], isCapped: false)
}
