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
@testable import SemanticVectorsKit

// MARK: - SemanticBundledMapTests

/// The bundled map by URL, refused as the app's `BundledSemanticMap.prepare()` refuses it.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a
@Suite("SemanticVectorsKit — the bundled map by URL")
struct SemanticBundledMapTests {

    /// The vectors the map is held to: twelve documents under the fixture's provenance.
    private static let vectors = SemanticVectorIndexTests.index()

    /// A map index for `vectors`, whose digest may be another generation's.
    private static func mapIndex(digest: String = SemanticFixture.provenance().digestHex) throws -> Data {
        try JSONEncoder().encode(SemanticMapArtifacts.MapIndex(
            schema: 1, generated: "2026-08-12", provenanceDigest: digest, documentCount: 12,
            gridExtent: 100,
            layout: SemanticMapArtifacts.MapIndex.Layout(
                method: "fixture", sourceDims: 8, neighbors: 15, minDist: 0.1, seed: 1,
                clustering: "fixture", unclusteredCount: 4, labelSampling: "fixture"),
            clusters: [SemanticMapArtifacts.Cluster(id: 0, terms: ["alpha"], documentCount: 8,
                                                    centreX: 1, centreY: 2, eraCounts: ["2": 8])]))
    }

    /// The pair in one folder: an index, and a binary placing `rows` documents.
    private static func pair(index: Data? = nil, rows: Int = 12) throws -> (index: URL, binary: URL) {
        let indexURL = try SemanticFixture.temporaryFile(try index ?? mapIndex(), name: "semantic-map-index.json")
        let binaryURL = indexURL.deletingLastPathComponent().appendingPathComponent("semantic-map.bin")
        let placements = (0..<rows).map {
            SemanticMapArtifacts.Placement(x: Int16($0), y: Int16(-$0),
                                           cluster: $0 < 8 ? 0 : SemanticMapArtifacts.unclustered)
        }
        try SemanticMapArtifacts.mapBinary(placements: placements, clusterCount: 1, gridExtent: 100,
                                           provenance: SemanticFixture.provenance()).write(to: binaryURL)
        return (indexURL, binaryURL)
    }

    @Test("The pair loads, held to the vectors' generation and count")
    func thePairLoads() throws {
        let urls = try Self.pair()
        let map = try SemanticBundledMap(indexAt: urls.index, binaryAt: urls.binary, vectorIndex: Self.vectors)
        #expect(map.vectors.documentCount == Self.vectors.documentCount)
        #expect(map.index.provenanceDigest == Self.vectors.provenance.digestHex)
        #expect(map.index.clusters.map(\.id) == [0])
        #expect(map.vectors.placement(at: 3) == SemanticMapArtifacts.Placement(x: 3, y: -3, cluster: 0))
    }

    @Test("Either file missing is no artifact, as a bundle that carries neither")
    func eachMissingFileIsNoArtifact() throws {
        let urls = try Self.pair()
        let nowhere = urls.index.deletingLastPathComponent().appendingPathComponent("absent")
        #expect(throws: SemanticUnavailable.noArtifact) {
            try SemanticBundledMap(indexAt: nowhere, binaryAt: urls.binary, vectorIndex: Self.vectors)
        }
        #expect(throws: SemanticUnavailable.noArtifact) {
            try SemanticBundledMap(indexAt: urls.index, binaryAt: nowhere, vectorIndex: Self.vectors)
        }
    }

    @Test("An index of another generation is refused, naming both digests")
    func anotherGenerationIsRefused() throws {
        let other = SemanticFixture.provenance(dims: 16).digestHex
        let urls = try Self.pair(index: try Self.mapIndex(digest: other))
        #expect(throws: SemanticUnavailable.provenanceMismatch(
            expected: Self.vectors.provenance.digestHex, found: other)) {
            try SemanticBundledMap(indexAt: urls.index, binaryAt: urls.binary, vectorIndex: Self.vectors)
        }
    }

    @Test("An index that cannot be decoded is a malformed one, named for the map's index")
    func anUndecodableIndexIsMalformed() throws {
        let urls = try Self.pair(index: Data("{}".utf8))
        do {
            _ = try SemanticBundledMap(indexAt: urls.index, binaryAt: urls.binary, vectorIndex: Self.vectors)
            Issue.record("an empty index loaded")
        } catch {
            guard case .malformedArtifact(let reason) = error else {
                Issue.record("refused as \(error), not as a malformed index"); return
            }
            #expect(reason.hasPrefix("map index: "), "\(reason)")
        }
    }

    @Test("A binary placing another count of documents is refused by the binary's own check")
    func anotherCountIsRefused() throws {
        let urls = try Self.pair(rows: 11)
        do {
            _ = try SemanticBundledMap(indexAt: urls.index, binaryAt: urls.binary, vectorIndex: Self.vectors)
            Issue.record("a map of 11 placements loaded against 12 vectors")
        } catch {
            guard case .malformedArtifact(let reason) = error else {
                Issue.record("refused as \(error), not as a malformed map"); return
            }
            #expect(reason.contains("map places 11 documents, the vectors have 12"), "\(reason)")
        }
    }
}
