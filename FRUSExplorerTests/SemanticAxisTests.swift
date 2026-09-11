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

/// The semantic axis (V-3) and the two shared-code changes it required.
///
/// The shared changes are the risky part: `isSelfNormalising` and `skipsGenerationAtZeroWeight` both
/// live on `SimilarityAxis` and are read by the ranker and engine on behalf of *every* axis, so the
/// tests here assert as much about what did **not** change for the other six as about what the new
/// one does.
///
/// Version history:
///   1.0 — V-3: initial implementation
///   1.1 — 2026-09-10: S-1, re-scoring the other axes' candidates against the anchor's own band
@Suite("Semantic similarity axis")
struct SemanticAxisTests {

    // MARK: - Axis declaration

    @Test("The axis is a generator, ships at 0.5, and still says experimental in its name")
    func axisDeclaration() {
        let axis = SimilarityAxis.semanticSimilarity
        #expect(axis.isGenerator)
        #expect(axis.defaultWeight == 0.5, "raised from 0 by owner decision 2026-09-10 (D-D)")
        #expect(axis.displayName.lowercased().contains("experimental"), """
            The default moved; the label did not, and the pairing is the point. "Experimental" is \
            about maturity — the blind pre-1900 panel was retired as a gate, and the automatic gate \
            reaches only 572 pre-1900 queries — not about whether the axis is worth having, which \
            D-A settled. Raising the weight without keeping the word would have turned an \
            unmeasured axis on silently.
            """)
        #expect(!axis.systemImage.isEmpty)
        #expect(SimilarityAxis.allCases.contains(.semanticSimilarity))
    }

    /// The rawValue is a persistence token: it keys the UserDefaults weight string and the
    /// CloudKit-mirrored `Project.leadAxisWeights`. Renaming it ships as a silent zero weight.
    @Test("The axis rawValue is the persistence token and must not drift")
    func rawValueIsStable() {
        #expect(SimilarityAxis.semanticSimilarity.rawValue == "semanticSimilarity")
        #expect(SimilarityAxis(rawValue: "semanticSimilarity") == .semanticSimilarity)
    }

    /// Both properties are opt-in per axis. If a later axis flips one by accident, the behaviour
    /// it changes is the ranker's arithmetic for every user of that axis.
    ///
    /// An **allowlist**, not a single-axis pin, since W-17 session 2: the lexical axis's
    /// `bm25(candidate)/bm25(anchor)` ratio is absolute in `[0, 1]` by construction, so it
    /// carries the same #643 argument the semantic cosine does — max-normalising either one
    /// hands a document's only neighbour a 1.0 however weak the evidence. A third axis joins
    /// this list by argument, not by editing the loop's where-clause quietly (the
    /// `intendedStratifiedRequests` precedent).
    @Test("Self-normalising and skip-at-zero are an allowlist of the two absolute-score axes")
    func newAxisPropertiesAreScoped() {
        let allowlisted: Set<SimilarityAxis> = [.semanticSimilarity, .lexicalSimilarity]
        for axis in SimilarityAxis.allCases where !allowlisted.contains(axis) {
            #expect(!axis.isSelfNormalising, "\(axis.rawValue) must keep max-normalisation")
            #expect(!axis.skipsGenerationAtZeroWeight, "\(axis.rawValue) must keep generating")
        }
        for axis in allowlisted {
            #expect(axis.isSelfNormalising,
                    "\(axis.rawValue) produces an absolute score; max-normalising it is the #643 defect")
            #expect(axis.skipsGenerationAtZeroWeight,
                    "\(axis.rawValue) is experimental at weight 0; generating anyway changes default results")
        }
    }

    // MARK: - The #643 escape

    /// The defect this axis could not ship without. Max-normalisation hands a document's *only*
    /// neighbour a 1.0 no matter how unlike it is; a cosine must arrive at the ranker intact.
    @Test("A self-normalising axis keeps its absolute scores; the others are still max-normalised")
    func selfNormalisingBypassesMaxNormalisation() {
        let anchor = DocumentKey(volumeId: "v", documentId: "d1")
        let lonely = DocumentKey(volumeId: "v", documentId: "d2")
        let records = [lonely: CandidateRecord(
            header: "H", dateline: nil, documentNumber: nil, isEditorialNote: false)]

        // A single weak semantic neighbour at cosine 0.42 must score 0.42, not 1.0.
        let semantic = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.semanticSimilarity: [lonely: 0.42]],
            scorerScores: [:], records: records,
            weights: AxisWeights(weights: [.semanticSimilarity: 1.0]), limit: 10)
        #expect(semantic.rows.count == 1)
        #expect(abs((semantic.rows.first?.axisScores[.semanticSimilarity] ?? 0) - 0.42) < 1e-9)

        // The same shape on a max-normalised axis still reads 1.0 — unchanged behaviour.
        let crossRef = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.crossReference: [lonely: 0.42]],
            scorerScores: [:], records: records,
            weights: AxisWeights(weights: [.crossReference: 1.0]), limit: 10)
        #expect(abs((crossRef.rows.first?.axisScores[.crossReference] ?? 0) - 1.0) < 1e-9)
    }

    @Test("Self-normalised scores are clamped, not passed through")
    func selfNormalisingClamps() {
        let anchor = DocumentKey(volumeId: "v", documentId: "d1")
        let high = DocumentKey(volumeId: "v", documentId: "d2")
        let negative = DocumentKey(volumeId: "v", documentId: "d3")
        let record = CandidateRecord(
            header: "H", dateline: nil, documentNumber: nil, isEditorialNote: false)

        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            // Float reconstruction can land a hair above 1; a negative cosine is not evidence.
            generatorStrengths: [.semanticSimilarity: [high: 1.0000005, negative: -0.3]],
            scorerScores: [:], records: [high: record, negative: record],
            weights: AxisWeights(weights: [.semanticSimilarity: 1.0]), limit: 10)

        #expect(ranked.rows.count == 1, "a negative similarity must not become a ranked row")
        #expect(ranked.rows.first?.key == high)
        #expect((ranked.rows.first?.axisScores[.semanticSimilarity] ?? 0) <= 1.0)
    }

    /// Relative ordering must survive: two candidates at different cosines rank in that order.
    @Test("Cosines rank in their own order and keep their distances")
    func cosinesPreserveOrdering() {
        let anchor = DocumentKey(volumeId: "v", documentId: "d1")
        let near = DocumentKey(volumeId: "v", documentId: "d2")
        let far = DocumentKey(volumeId: "v", documentId: "d3")
        let record = CandidateRecord(
            header: "H", dateline: nil, documentNumber: nil, isEditorialNote: false)

        let ranked = RelatedDocumentsRanker.rank(
            anchor: anchor,
            generatorStrengths: [.semanticSimilarity: [near: 0.9, far: 0.45]],
            scorerScores: [:], records: [near: record, far: record],
            weights: AxisWeights(weights: [.semanticSimilarity: 1.0]), limit: 10)

        #expect(ranked.rows.map(\.key) == [near, far])
        #expect(abs((ranked.rows[0].totalScore) - 0.9) < 1e-9)
        #expect(abs((ranked.rows[1].totalScore) - 0.45) < 1e-9)
    }

    // MARK: - Helpers

    @Test("The eligibility set is the indexed volumes, narrowed by any caller scope")
    func eligibilityIntersectsScope() {
        let indexed: Set<String> = ["a", "b", "c"]
        #expect(SemanticSimilarityGenerator.eligibleVolumeIDs(indexed: indexed, scope: nil)
                == indexed)
        #expect(SemanticSimilarityGenerator.eligibleVolumeIDs(indexed: indexed, scope: ["b", "z"])
                == ["b"])
        #expect(SemanticSimilarityGenerator.eligibleVolumeIDs(indexed: indexed, scope: [])
                .isEmpty)
        #expect(SemanticSimilarityGenerator.eligibleVolumeIDs(indexed: [], scope: nil).isEmpty)
    }

    /// The chip states what the axis measured. It has no shared term, citation or container to name,
    /// so a percentage is the only honest thing it can say.
    @Test("The evidence chip reports the cosine as a percentage, clamped")
    func evidenceLabelReportsPercentage() {
        #expect(SemanticSimilarityGenerator.evidenceLabel(for: 0.823).contains("82"))
        #expect(SemanticSimilarityGenerator.evidenceLabel(for: 1.0).contains("100"))
        #expect(SemanticSimilarityGenerator.evidenceLabel(for: -0.5).contains("0"))
        #expect(SemanticSimilarityGenerator.evidenceLabel(for: 0.823).lowercased()
            .contains("semantic"))
    }

    // MARK: - Wiring

    /// The registration, and both of the engine's opt-in gates.
    ///
    /// **This test used to read the engine's SOURCE** and assert it contained two literals. That
    /// is blind by construction: a stage that bypassed the gate entirely would leave both strings
    /// in the file and the test green — and when the S-3 off-index scan added a SECOND gate, the
    /// source scan did not notice it existed. Both gates are now predicates on the engine and are
    /// driven here.
    @MainActor
    @Test("The generator is registered, and both engine gates hold at zero weight")
    func engineWiring() throws {
        #expect(RelatedDocumentsEngine.generators.contains { $0.axis == .semanticSimilarity })

        var zero = AxisWeights.default
        zero[.semanticSimilarity] = 0
        #expect(!RelatedDocumentsEngine.runsGenerator(.semanticSimilarity, at: zero))
        #expect(!RelatedDocumentsEngine.runsOffIndexScan(includeOffIndexLeads: true, weights: zero))

        var raised = zero
        raised[.semanticSimilarity] = 0.5
        #expect(RelatedDocumentsEngine.runsGenerator(.semanticSimilarity, at: raised))
        #expect(RelatedDocumentsEngine.runsOffIndexScan(includeOffIndexLeads: true, weights: raised))
        // The background opt-out is the scan gate's OTHER conjunct and needs its own fixture — a
        // case failing both at once would tell us nothing about either.
        #expect(!RelatedDocumentsEngine.runsOffIndexScan(includeOffIndexLeads: false, weights: raised))

        // The gate must be "skip an EXPERIMENTAL axis at zero", not "skip everything at zero".
        // **Every axis has to be at zero for this to mean anything** — an earlier version of this
        // line zeroed only the semantic axis and left archival at its non-zero default, so
        // `weights[axis] > 0` alone satisfied it and a mutation reducing the gate to exactly that
        // passed all fifteen tests.
        var allZero = AxisWeights.default
        for axis in SimilarityAxis.allCases { allZero[axis] = 0 }
        #expect(RelatedDocumentsEngine.runsGenerator(.archivalProvenance, at: allZero))
        #expect(!RelatedDocumentsEngine.runsGenerator(.semanticSimilarity, at: allZero))

        // The axis enters the ranker self-normalised (#643) and, since D-D, ships at 0.5 — the
        // two facts the old source scan was reaching for.
        #expect(SimilarityAxis.semanticSimilarity.isSelfNormalising)
        #expect(AxisWeights.default[.semanticSimilarity] == 0.5)
    }

    // MARK: - Off-index volume leads (V-3 §6.2(a))

    /// The rule, driven against the shipped artifacts: an off-index document is reported when it is
    /// at least as near as the last on-index candidate the axis would itself have shown.
    ///
    /// The fixture holds HALF the corpus, because that is the condition the yield was measured
    /// under — a median of 94 documents across 19 volumes per anchor.
    @MainActor
    @Test("Off-index leads are counted against the anchor's own band, and name volumes only")
    func offIndexLeadsUseTheAnchorsOwnBand() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let corpus = try #require(BundledSemanticVectors.corpusVectors)

        // Half the volumes, deterministically: every other one in index order.
        let held = Set(index.volumes.enumerated().filter { $0.offset.isMultiple(of: 2) }
                                     .map { $0.element.volumeID })
        var eligible = [UInt8](repeating: 0, count: index.documentCount)
        for volumeID in held {
            guard let rows = index.rows(forVolume: volumeID) else { continue }
            for row in rows { eligible[row] = 1 }
        }
        let anchorVolume = try #require(held.sorted().first)
        let anchorRow = try #require(index.rows(forVolume: anchorVolume)?.first)
        let onIndex = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: 800, isEligible: { eligible[$0] == 1 })
        try #require(!onIndex.isEmpty)

        let leads = SemanticSimilarityGenerator.offIndexLeads(
            anchorRow: anchorRow, corpus: corpus, index: index,
            onIndexRows: onIndex, eligible: eligible, limit: 120)

        #expect(leads.documentCount > 0, "a half-held corpus must surface something")
        #expect(!leads.volumes.isEmpty)
        // The whole point: NOT ONE of the volumes named may be one the reader already holds.
        #expect(leads.volumes.allSatisfy { !held.contains($0.volumeID) }, """
            An off-index lead that names a held volume is not off-index — the inverted eligibility \
            predicate has been applied the wrong way round.
            """)
        // Counts sum to the documents, and the list is ordered by count.
        #expect(leads.volumes.reduce(0) { $0 + $1.count } == leads.documentCount)
        #expect(leads.volumes.map(\.count) == leads.volumes.map(\.count).sorted(by: >))
    }

    /// A reader who holds everything has nothing off-index, and the helper must say so rather than
    /// scanning a corpus with no eligible rows and reporting whatever comes back.
    @MainActor
    @Test("A reader holding the whole corpus gets no off-index leads")
    func nothingOffIndexWhenEverythingIsHeld() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let corpus = try #require(BundledSemanticVectors.corpusVectors)
        let eligible = [UInt8](repeating: 1, count: index.documentCount)
        let anchorRow = 0
        let onIndex = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: 800, isEligible: { eligible[$0] == 1 })
        let leads = SemanticSimilarityGenerator.offIndexLeads(
            anchorRow: anchorRow, corpus: corpus, index: index,
            onIndexRows: onIndex, eligible: eligible, limit: 120)
        #expect(leads == .none)
    }

    // MARK: - Off-index document channel (S-3)

    /// A lead, spelled once so the fixtures below read as data.
    private static func lead(_ volumeID: String, _ documentID: String, _ score: Double)
        -> SemanticOffIndexLeads.DocumentLead {
        SemanticOffIndexLeads.DocumentLead(
            volumeID: volumeID, documentID: documentID, score: score)
    }

    /// The rank is the exact cosine, never the Hamming order the rows were walked in.
    ///
    /// The fixture arrives in ASCENDING score for that reason: an implementation that cut the walk
    /// at `limit` and then sorted would return the first entries of this list, which are its worst.
    @Test("Off-index documents rank by score, not by the order they were scanned")
    func offIndexDocumentsRankByScore() {
        let anchor = DocumentKey(volumeId: "frus1969-76v01", documentId: "d1")
        let ranked = SemanticSimilarityGenerator.rankOffIndexDocuments(
            [Self.lead("frusA", "d1", 0.10),
             Self.lead("frusB", "d2", 0.50),
             Self.lead("frusC", "d3", 0.90)],
            anchor: anchor, limit: 2)
        #expect(ranked.map(\.id) == ["frusC/d3", "frusB/d2"], """
            The list must be the two best by cosine. Getting the two WORST back means the cut was \
            applied in scan order and the sort only reordered what survived it.
            """)
    }

    /// The anchor reprinted in another edition is not a lead — to the reader it is the anchor.
    ///
    /// **One fixture per conjunct.** The drop rule is `areTwins(volume) && sameDocumentID`, so the
    /// suite carries a lead that fails each half on its own: a twin volume at a DIFFERENT document
    /// is a real lead, and the same document id in an UNRELATED volume is a different document that
    /// merely shares a number. A fixture violating both at once would test neither.
    @Test("The anchor's own edition twin is dropped, and neither half of the rule alone drops one")
    func offIndexDocumentsDropTheAnchorsTwin() {
        let anchor = DocumentKey(volumeId: "frus1951-54Iran", documentId: "d166")
        let ranked = SemanticSimilarityGenerator.rankOffIndexDocuments(
            [Self.lead("frus1951-54IranEd2", "d166", 0.99),   // the anchor, reprinted — dropped
             Self.lead("frus1951-54IranEd2", "d200", 0.98),   // twin volume, different document
             Self.lead("frus1958-60v10p1", "d166", 0.97)],    // same number, unrelated volume
            anchor: anchor, limit: 10)
        #expect(ranked.map(\.id) == ["frus1951-54IranEd2/d200", "frus1958-60v10p1/d166"])
    }

    /// Two editions of one document are one lead — and the fold is charged to the fold, not to the
    /// reader's slot.
    ///
    /// With `limit: 2` over a twin pair plus a third document, a fold applied AFTER the cut returns
    /// one row; applied before it, two. The kept edition is the better-scored one, which is what
    /// sorting before folding buys.
    @Test("An edition twin pair folds to one lead, and the limit is applied after the fold")
    func offIndexDocumentsFoldTwinsBeforeTheLimit() {
        let anchor = DocumentKey(volumeId: "frus1969-76v01", documentId: "d1")
        let ranked = SemanticSimilarityGenerator.rankOffIndexDocuments(
            [Self.lead("frus1951-54Iran", "d20", 0.90),
             Self.lead("frus1951-54IranEd2", "d20", 0.80),
             Self.lead("frusOther", "d5", 0.70)],
            anchor: anchor, limit: 2)
        #expect(ranked.map(\.id) == ["frus1951-54Iran/d20", "frusOther/d5"], """
            One row back means the twin consumed a display slot; the Ed2 edition first means the \
            fold ran before the sort and kept whichever arrived first.
            """)
    }

    /// The rows the scan kept and the number it reports are the same finding.
    ///
    /// The document channel is built from `rows`, and the caption from `documentCount`; if they can
    /// disagree the section names documents it did not count, or counts documents it cannot reach.
    @MainActor
    @Test("The kept rows are exactly the counted documents, and every one is off-index")
    func offIndexKeptRowsMatchTheCount() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let corpus = try #require(BundledSemanticVectors.corpusVectors)

        let held = Set(index.volumes.enumerated().filter { $0.offset.isMultiple(of: 2) }
                                     .map { $0.element.volumeID })
        var eligible = [UInt8](repeating: 0, count: index.documentCount)
        for volumeID in held {
            guard let rows = index.rows(forVolume: volumeID) else { continue }
            for row in rows { eligible[row] = 1 }
        }
        let anchorVolume = try #require(held.sorted().first)
        let anchorRow = try #require(index.rows(forVolume: anchorVolume)?.first)
        let onIndex = SemanticRetrievalKernel.hammingCandidates(
            queryRow: anchorRow, in: corpus, limit: 800, isEligible: { eligible[$0] == 1 })

        let leads = SemanticSimilarityGenerator.offIndexLeads(
            anchorRow: anchorRow, corpus: corpus, index: index,
            onIndexRows: onIndex, eligible: eligible, limit: 120)

        #expect(leads.rows.count == leads.documentCount)
        #expect(leads.rows.allSatisfy { eligible[$0] == 0 }, """
            A kept row inside the reader's own library is not a lead — the document channel would \
            then offer a download for a volume they already hold.
            """)
        // Nearest-first, which is what lets the document channel take a prefix and still be
        // scoring the strongest candidates.
        let distances = leads.rows.compactMap {
            SemanticRetrievalKernel.binarySimilarity(anchorRow, $0, in: corpus)
        }
        #expect(distances.count == leads.rows.count)
        #expect(distances == distances.sorted(by: >))
    }
    // MARK: - Re-scoring the other axes' candidates (S-1)

    /// A key, spelled once.
    private static func key(_ volumeID: String, _ documentID: String) -> DocumentKey {
        DocumentKey(volumeId: volumeID, documentId: documentID)
    }

    /// The floor is the axis's own weakest vended neighbour, and the targets are everything else.
    ///
    /// **The fixture carries one violation of each subtraction**, because `rescorePlan` subtracts
    /// twice and a fixture exercising only one would leave the other free to be deleted: the anchor
    /// is present in `allCandidates` (another generator may well have produced it), and so are the
    /// axis's own vended keys. Dropping either subtraction changes the expected set.
    @Test("The re-score floor is the axis's own weakest vended neighbour, never a constant")
    func theFloorIsTheAxisOwnBand() throws {
        let anchor = Self.key("frus1969-76v01", "d1")
        let vended: [DocumentKey: Double] = [
            Self.key("frus1969-76v01", "d40"): 0.91,
            Self.key("frus1969-76v02", "d7"): 0.70,
            Self.key("frus1969-76v03", "d9"): 0.62,       // the band's edge
        ]
        let others = [Self.key("frus1958-60v10p1", "d5"), Self.key("frus1955-57v12", "d88")]
        let plan = try #require(SemanticSimilarityGenerator.rescorePlan(
            vended: vended,
            allCandidates: Set(vended.keys).union(others).union([anchor]),
            anchor: anchor))

        #expect(plan.floor == 0.62, """
            The floor must be the MINIMUM of the vended scores. A maximum (0.91) admits almost \
            nothing; a mean sits inside the axis's own band and rejects documents it already shows.
            """)
        #expect(plan.targets == Set(others), """
            Targets must exclude the axis's own vended keys and the anchor itself. \
            Got \(plan.targets.map(\.compositeString).sorted()).
            """)
        #expect(plan.targets.isDisjoint(with: vended.keys), """
            The engine merges the re-scored scores into the vended ones. The two sides are disjoint \
            BY CONSTRUCTION here, which is why that merge can never overwrite a vended score.
            """)
    }

    /// With no band there is no floor, and the answer is to refuse rather than to invent one.
    ///
    /// This is the whole S-1 design decision in one assertion. Measured over 60 anchors on the
    /// shipped artifacts, a random corpus pair scores a median **0.472** and the anchor's own
    /// rank-120 cosine runs **0.543–0.836** — so an unfloored pass adds about half the axis's
    /// weight to every row uniformly, and any constant sits above some anchors' bands and far
    /// below others'.
    @Test("No vended neighbours means no re-score, rather than a fallback constant")
    func noVendedNeighboursMeansNoPlan() {
        let anchor = Self.key("frus1969-76v01", "d1")
        // A full candidate universe, so the refusal can only be coming from the absent band.
        let candidates: Set<DocumentKey> = [
            Self.key("frus1958-60v10p1", "d5"), Self.key("frus1955-57v12", "d88"),
        ]
        #expect(SemanticSimilarityGenerator.rescorePlan(
            vended: [:], allCandidates: candidates, anchor: anchor) == nil)
    }

    /// Nothing to score is also nothing to do — the engine must not run a shard pass for an empty
    /// set, which would resolve the anchor's shard for no reason.
    @Test("A candidate set the axis already covers yields no re-score")
    func nothingLeftToScoreMeansNoPlan() {
        let anchor = Self.key("frus1969-76v01", "d1")
        let vended: [DocumentKey: Double] = [Self.key("frus1969-76v02", "d7"): 0.70]
        #expect(SemanticSimilarityGenerator.rescorePlan(
            vended: vended,
            allCandidates: Set(vended.keys).union([anchor]),
            anchor: anchor) == nil)
    }

    /// A re-scored row carries the same chip a vended one carries, and a vended row keeps its own.
    ///
    /// The chip is not decoration: the ranker adds a re-scored score to `total` exactly as it adds
    /// a vended one, so a row that rises with no semantic chip is a row the panel cannot explain.
    /// The fixture puts a vended candidate WITH a label beside a re-scored one, so a mutation that
    /// overwrote instead of filling would change the first and one that skipped the fill would
    /// change the second.
    @Test("A re-scored candidate gets the axis's own chip, and a vended one keeps the label it had")
    func theFoldFillsChipsWithoutOverwritingThem() throws {
        let vendedKey = Self.key("frus1969-76v02", "d7")
        let rescoredKey = Self.key("frus1958-60v10p1", "d5")
        let folded = SemanticSimilarityGenerator.applyReScore(
            [rescoredKey: 0.81],
            strengths: [vendedKey: 0.70],
            labels: [vendedKey: "already set"])

        #expect(folded.strengths == [vendedKey: 0.70, rescoredKey: 0.81])
        #expect(folded.labels[vendedKey] == "already set", """
            The generator's own label must survive the fold — overwriting it would replace a \
            vended row's evidence with a recomputation of the same number.
            """)
        let minted = try #require(folded.labels[rescoredKey])
        #expect(minted == SemanticSimilarityGenerator.evidenceLabel(for: 0.81), """
            A re-scored row must get the axis's OWN chip function, not a different wording: \
            got "\(minted)".
            """)
        #expect(minted.contains("81"))
    }

    /// The fold's two collision rules, exercised at the function's own boundary.
    ///
    /// **`rescorePlan` makes these collisions impossible today** — its targets are disjoint from
    /// the vended keys — so neither rule can fire through the engine, and a mutation sweep found
    /// both surviving because of it. They are still the function's stated contract, and they are
    /// what a later change to the plan would land on: `max` so a document already vended keeps the
    /// score it was vended with, and fill-don't-overwrite so it keeps the generator's own chip. A
    /// guard nothing can reach is worth keeping only if something proves it works.
    @Test("A colliding key keeps the better score and the label it already had")
    func theFoldPrefersWhatWasAlreadyThere() throws {
        let shared = Self.key("frus1969-76v02", "d7")
        let folded = SemanticSimilarityGenerator.applyReScore(
            [shared: 0.40],
            strengths: [shared: 0.70],
            labels: [shared: "already set"])
        #expect(folded.strengths[shared] == 0.70, """
            The vended score must win: `merging(rescored) { $1 }` would replace 0.70 with 0.40 \
            and compile clean.
            """)
        #expect(folded.labels[shared] == "already set")
    }

    /// Nothing re-scored is nothing changed — not an emptied label table, and not a rebuilt one.
    @Test("An empty re-score leaves the axis exactly as the generator left it")
    func anEmptyFoldChangesNothing() {
        let vendedKey = Self.key("frus1969-76v02", "d7")
        let folded = SemanticSimilarityGenerator.applyReScore(
            [:], strengths: [vendedKey: 0.70], labels: [vendedKey: "already set"])
        #expect(folded.strengths == [vendedKey: 0.70])
        #expect(folded.labels == [vendedKey: "already set"])
    }

    // MARK: - The re-score itself, against real shards

    /// A store over a temporary directory holding exactly the shards named.
    ///
    /// Real packer shards from `Planning/semantic-vectors/shards`, adopted through the store's own
    /// `adoptShard` — so the header, provenance and count checks the device applies have all run.
    @MainActor
    private static func store(holding volumeIDs: [String], _ index: SemanticVectorIndex)
        async throws -> SemanticShardStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rescore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = SemanticShardStore(
            directory: directory,
            provenance: index.provenance,
            expectedCounts: Dictionary(
                index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first }))
        for volumeID in volumeIDs {
            try await store.adoptShard(from: RescoreFixtures.shardURL(volumeID), for: volumeID)
        }
        return store
    }

    /// The floor really cuts, and it cuts exactly where it says it does.
    ///
    /// Two passes over the SAME candidate set: one at a floor below every possible cosine, which
    /// yields the true scores, and one at the median of those, which must return exactly the upper
    /// half. The test asserts the result is a **proper, non-empty** subset — an implementation that
    /// ignored the floor would return everything, and one that compared the wrong way round would
    /// return the complement.
    @MainActor
    @Test("A candidate below the floor contributes nothing, and one above keeps its own cosine",
          .enabled(if: RescoreFixtures.shardsPresent))
    func theFloorAdmitsExactlyTheCandidatesThatClearIt() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let store = try await Self.store(
            holding: [RescoreFixtures.anchorVolume, RescoreFixtures.candidateVolume], index)

        let anchor = Self.key(RescoreFixtures.anchorVolume,
                              try #require(index.documentIDs(forVolume: RescoreFixtures.anchorVolume)?.first))
        let candidateIDs = try #require(index.documentIDs(forVolume: RescoreFixtures.candidateVolume))
        let candidates = Set(candidateIDs.prefix(60).map { Self.key(RescoreFixtures.candidateVolume, $0) })

        // A floor below every possible cosine: the unfiltered truth.
        let all = await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: candidates, floor: -1.1, store: store)
        try #require(all.count == candidates.count,
                     "every candidate's shard is on disk, so every one must score")

        let sorted = all.values.sorted()
        let floor = sorted[sorted.count / 2]
        let expected = all.filter { $0.value >= floor }
        try #require(!expected.isEmpty && expected.count < all.count, """
            The fixture's cosines must straddle their own median for this to test anything — \
            \(expected.count) of \(all.count) at floor \(floor).
            """)

        let kept = await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: candidates, floor: floor, store: store)
        #expect(Set(kept.keys) == Set(expected.keys), """
            The floor must admit exactly the candidates at or above it: kept \(kept.count), \
            expected \(expected.count) of \(all.count).
            """)
        #expect(kept.allSatisfy { all[$0.key] == $0.value }, """
            A kept candidate carries its OWN cosine, not the floor and not a normalised rank — the \
            axis is self-normalising (#643) and its scores enter the ranker raw.
            """)
    }

    /// A document is its own nearest neighbour, and that is the only ground truth here that is not
    /// a mirror of the code under test.
    ///
    /// **This test exists because a mutation sweep found the two it replaces were self-consistent
    /// rather than correct.** The floor test above makes two `reScore` passes and compares them, so
    /// replacing `anchorRow - anchorEntry.rowOffset` with `anchorRow % anchorEntry.documentCount`
    /// — a plausible-looking way to make a corpus row volume-relative, and wrong — moved BOTH runs
    /// together and survived. So did the same substitution on the candidate side. That is the
    /// codebase's characteristic semantic failure: not a crash, not an error, just the wrong
    /// documents at entirely believable scores, forever.
    ///
    /// Scoring an anchor against every document of its own volume pins both arithmetics at once,
    /// because it is the one case where the answer is known independently. The anchor must come
    /// back at 1.0 and nothing else may: a wrong QUERY row compares some other document against the
    /// volume and no candidate reaches 1.0; a wrong CANDIDATE row permutes the mapping and puts the
    /// 1.0 on whichever document the permutation lands on. Measured on `frus1895p1`, both
    /// substitutions move the top score onto a different document.
    @MainActor
    @Test("The anchor scores 1.0 against itself and nothing else does",
          .enabled(if: RescoreFixtures.shardsPresent))
    func theAnchorIsItsOwnNearestNeighbour() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let store = try await Self.store(holding: [RescoreFixtures.anchorVolume], index)

        let documentIDs = try #require(index.documentIDs(forVolume: RescoreFixtures.anchorVolume))
        try #require(documentIDs.count > 100, "the fixture volume must be large enough to permute")
        // The anchor sits at LOCAL ROW 0 of its volume, which is what makes the two wrong
        // arithmetics land on different documents rather than coinciding at the same one.
        let anchor = Self.key(RescoreFixtures.anchorVolume, documentIDs[0])
        let candidates = Set(documentIDs.map { Self.key(RescoreFixtures.anchorVolume, $0) })

        let scored = await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: candidates, floor: -1.1, store: store)
        #expect(scored.count == candidates.count)

        let own = try #require(scored[anchor])
        #expect(own > 0.999, """
            The anchor scored \(own) against itself. Either the query vector or the candidate row             is being read from the wrong place in the shard.
            """)
        let others = scored.filter { $0.key != anchor }.values
        #expect(others.max() ?? 0 < 0.999, """
            Another document scored 1.0 against the anchor (best \(others.max() ?? 0)) — the             row-to-document mapping is permuted.
            """)
    }

    /// It reads what is on disk and nothing else — no fetch, no queue, no new bytes.
    ///
    /// The candidate set spans a volume whose shard is present and one whose shard is not, and the
    /// store's own directory listing is compared before and after. **The stronger half of this
    /// guarantee is structural rather than tested**: `reScore` takes a `SemanticShardStore` and not
    /// the `AppState` its sibling entry points take, so there is no `fetchSemanticShardIfNeeded` in
    /// scope for a later change to reach. What remains for a test is the outcome — an absent shard
    /// is a silent miss, not a fault and not a download.
    @MainActor
    @Test("A candidate whose shard is absent contributes nothing and pulls nothing",
          .enabled(if: RescoreFixtures.shardsPresent))
    func anAbsentShardIsASilentMiss() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let store = try await Self.store(
            holding: [RescoreFixtures.anchorVolume, RescoreFixtures.candidateVolume], index)
        let before = Set(await store.volumeIDsOnDisk())

        let anchor = Self.key(RescoreFixtures.anchorVolume,
                              try #require(index.documentIDs(forVolume: RescoreFixtures.anchorVolume)?.first))
        let held = Set(try #require(index.documentIDs(forVolume: RescoreFixtures.candidateVolume))
            .prefix(20).map { Self.key(RescoreFixtures.candidateVolume, $0) })
        let absent = Set(try #require(index.documentIDs(forVolume: RescoreFixtures.absentVolume))
            .prefix(20).map { Self.key(RescoreFixtures.absentVolume, $0) })

        let scored = await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: held.union(absent), floor: -1.1, store: store)
        #expect(Set(scored.keys) == held, """
            Only the held volume's candidates may score. Scoring the absent one would mean a fetch \
            ran — the burst this path exists to avoid widening.
            """)
        let after = Set(await store.volumeIDsOnDisk())
        #expect(after == before, """
            The pass wrote to the store: \(before.sorted()) -> \(after.sorted()).
            """)
    }

    /// Without the anchor's own shard there is no query vector, so the pass yields nothing rather
    /// than falling back to the bundled sign bits — which would score a different arithmetic into
    /// the same axis and put two incomparable scales in one ranking.
    @MainActor
    @Test("An anchor whose own shard is absent re-scores nothing",
          .enabled(if: RescoreFixtures.shardsPresent))
    func anAbsentAnchorShardReScoresNothing() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let store = try await Self.store(holding: [RescoreFixtures.candidateVolume], index)

        let anchor = Self.key(RescoreFixtures.anchorVolume,
                              try #require(index.documentIDs(forVolume: RescoreFixtures.anchorVolume)?.first))
        let candidates = Set(try #require(index.documentIDs(forVolume: RescoreFixtures.candidateVolume))
            .prefix(20).map { Self.key(RescoreFixtures.candidateVolume, $0) })
        let scored = await SemanticSimilarityGenerator.reScore(
            anchor: anchor, candidates: candidates, floor: -1.1, store: store)
        #expect(scored.isEmpty)
    }
}

/// The real packer shards the S-1 re-score tests drive.
///
/// `Planning/semantic-vectors/shards` is gitignored — it is the download tier, not a bundled
/// resource — so the tests that need it are gated rather than failing on a fresh clone.
private enum RescoreFixtures {
    static let anchorVolume = "frus1895p1"
    static let candidateVolume = "frus1951-54IranEd2"
    /// Named by the bundled index — the candidate keys are real — but deliberately NOT adopted
    /// into the store under test, which is what makes it stand for a shard the reader declined.
    static let absentVolume = "frus1958-60v10p1"

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func shardURL(_ volumeID: String) -> URL {
        repoRoot.appendingPathComponent("Planning/semantic-vectors/shards/\(volumeID).vec")
    }

    static var shardsPresent: Bool {
        // Only the two that are adopted: `absentVolume` is read out of the INDEX, never off disk.
        [anchorVolume, candidateVolume]
            .allSatisfy { FileManager.default.fileExists(atPath: shardURL($0).path) }
    }
}
