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

    /// Both new properties are opt-in per axis. If a later axis flips one by accident, the behaviour
    /// it changes is the ranker's arithmetic for every user of that axis.
    @Test("Only the semantic axis is self-normalising or skipped at zero weight")
    func newAxisPropertiesAreScoped() {
        for axis in SimilarityAxis.allCases where axis != .semanticSimilarity {
            #expect(!axis.isSelfNormalising, "\(axis.rawValue) must keep max-normalisation")
            #expect(!axis.skipsGenerationAtZeroWeight, "\(axis.rawValue) must keep generating")
        }
        #expect(SimilarityAxis.semanticSimilarity.isSelfNormalising)
        #expect(SimilarityAxis.semanticSimilarity.skipsGenerationAtZeroWeight)
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

    @MainActor
    @Test("The generator is registered, and the engine skips it at zero weight")
    func engineWiring() throws {
        #expect(RelatedDocumentsEngine.generators.contains { $0.axis == .semanticSimilarity })

        let engine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/RelatedDocuments/RelatedDocumentsEngine.swift")
        let source = try String(contentsOf: engine, encoding: .utf8)
        // The gate is what stops a user who never enabled the axis from paying for its shard fetches.
        #expect(source.contains("where !generator.axis.skipsGenerationAtZeroWeight"))
        #expect(source.contains("axis.isSelfNormalising"))
    }
}
