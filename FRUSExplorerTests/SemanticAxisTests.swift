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
@Suite("Semantic similarity axis")
struct SemanticAxisTests {

    // MARK: - Axis declaration

    @Test("The axis is a generator, ships opt-in at weight 0, and says experimental in its name")
    func axisDeclaration() {
        let axis = SimilarityAxis.semanticSimilarity
        #expect(axis.isGenerator)
        #expect(axis.defaultWeight == 0.0)
        #expect(axis.displayName.lowercased().contains("experimental"),
                "the axis ships without its quality gate; the slider must say so")
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

        // The gate must be "skip an EXPERIMENTAL axis at zero", not "skip everything at zero":
        // without this the whole related model could be disabled and the test above would pass.
        #expect(RelatedDocumentsEngine.runsGenerator(.archivalProvenance, at: zero))

        // The axis enters the ranker self-normalised (#643) and ships at 0 — the two facts the
        // old source scan was reaching for.
        #expect(SimilarityAxis.semanticSimilarity.isSelfNormalising)
        #expect(AxisWeights.default[.semanticSimilarity] == 0)
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
}
