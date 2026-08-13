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
import SemanticVectorsKit
@testable import SemanticVectorsGeneratorCore

// MARK: - Labelling

/// c-TF-IDF, the sampler, and the one thing a label must never print.
///
/// Version history:
///   1.0 — V-4: initial implementation
@Suite("SemanticMap — cluster labelling")
struct ClusterLabellerTests {

    /// The whole point of the "c" in c-TF-IDF: a term every cluster shares carries no information
    /// about any of them, however often it appears.
    @Test("A term shared by every cluster loses to one concentrated in a single cluster")
    func sharedTermsLoseToDistinctiveOnes() throws {
        let counts: [Int: [String: Int]] = [
            0: ["government": 900, "kearsarge": 20],
            1: ["government": 900, "saigon": 25],
            2: ["government": 900, "mosadeq": 15],
        ]
        let labels = ClusterLabeller.label(counts: counts, limit: 1)
        #expect(labels[0] == ["kearsarge"])
        #expect(labels[1] == ["saigon"])
        #expect(labels[2] == ["mosadeq"])
    }

    @Test("Labels are ordered most distinctive first and are deterministic on ties")
    func labelsAreOrderedAndDeterministic() throws {
        let counts: [Int: [String: Int]] = [
            0: ["alpha": 10, "beta": 10, "shared": 100],
            1: ["shared": 100, "gamma": 5],
        ]
        let first = ClusterLabeller.label(counts: counts, limit: 2)[0]
        let second = ClusterLabeller.label(counts: counts, limit: 2)[0]
        #expect(first == second)
        #expect(first == ["alpha", "beta"])
    }

    /// The measured defect: the first real run named a cluster "british, apr, united, war".
    @Test("Date chrome never reaches a label, however distinctive it looks")
    func dateChromeIsFiltered() {
        let counts: [Int: [String: Int]] = [
            0: ["apr": 500, "british": 40],
            1: ["saigon": 30],
        ]
        let labels = ClusterLabeller.label(counts: counts, limit: 2)
        #expect(labels[0]?.contains("apr") == false)
        #expect(labels[0]?.first == "british")
        #expect(ClusterLabeller.labelChrome.contains("december"))
    }

    /// Sampling must span a cluster, not its first N documents: members arrive in row order, which is
    /// volume order, so taking a prefix would label a cluster after whichever volumes sort first.
    @Test("The sampler strides across a cluster rather than taking a prefix")
    func samplingStridesAcrossTheCluster() throws {
        let members = (0..<1000).map {
            ClusterLabeller.Member(volumeID: "v\($0 / 100)", documentID: "d\($0)", cluster: 7)
        }
        let sampled = try #require(ClusterLabeller.sample(members: members, perCluster: 10)[7])
        #expect(sampled.count == 10)
        #expect(Set(sampled.map(\.volumeID)).count > 5,
                "a prefix sample would draw from one or two volumes")
    }

    @Test("A cluster smaller than the sample is taken whole")
    func smallClustersAreTakenWhole() throws {
        let members = (0..<12).map {
            ClusterLabeller.Member(volumeID: "v", documentID: "d\($0)", cluster: 3)
        }
        #expect(ClusterLabeller.sample(members: members, perCluster: 50)[3]?.count == 12)
    }
}

// MARK: - The map binary

/// The Tier-0 layout, its header, and the invariant that keeps it aligned with the vectors.
///
/// Version history:
///   1.0 — V-4: initial implementation
@Suite("SemanticMap — artifact")
struct SemanticMapArtifactShapeTests {

    static let provenance = SemanticVectorsArtifacts.Provenance(
        model: "fixture", modelFileSHA256: String(repeating: "c", count: 64),
        nativeDims: 768, shippingDims: 256, chunkChars: 3200, overlapChars: 480,
        prefix: "title: none | text: ", pooling: "fixture", quantization: "fixture")

    @Test("The map binary's header and payload round-trip")
    func mapBinaryRoundTrips() {
        let placements = [
            SemanticMapArtifacts.Placement(x: -30000, y: 12345, cluster: 0),
            SemanticMapArtifacts.Placement(x: 7, y: -7, cluster: 42),
            SemanticMapArtifacts.Placement(x: 0, y: 0, cluster: SemanticMapArtifacts.unclustered),
        ]
        let data = SemanticMapArtifacts.mapBinary(
            placements: placements, clusterCount: 43, gridExtent: 30000, provenance: Self.provenance)

        #expect(String(data: data.prefix(4), encoding: .utf8) == SemanticMapArtifacts.mapMagic)
        func uint32(_ offset: Int) -> UInt32 {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
                .littleEndian
        }
        #expect(uint32(8) == 3)
        #expect(uint32(12) == 43)
        #expect(uint32(16) == 30000)
        #expect(data[20..<52] == Self.provenance.digest)
        #expect(data.count == SemanticVectorsArtifacts.headerBytes
                + placements.count * SemanticMapArtifacts.bytesPerDocument)

        // `readPlacements` reads a bare `layout.bin` — raw 6-byte records, no header — so the
        // round trip strips the artifact header the packer adds. The negative coordinate is the one
        // a sign error would corrupt.
        let bare = Data(data.dropFirst(SemanticVectorsArtifacts.headerBytes))
        let readBack = try? SemanticMapPacker.readPlacements(
            at: Self.write(bare), expectedCount: 3)
        #expect(readBack == placements)
    }

    /// A layout whose length disagrees with the vector artifact would misalign every row after the
    /// discrepancy — silently, since both files are otherwise well-formed.
    @Test("A layout with the wrong document count is refused")
    func wrongLengthIsRefused() {
        let data = SemanticMapArtifacts.mapBinary(
            placements: [SemanticMapArtifacts.Placement(x: 1, y: 2, cluster: 0)],
            clusterCount: 1, gridExtent: 30000, provenance: Self.provenance)
        // The packer reads a bare layout.bin, not the packed artifact, so strip the header.
        let bare = data.dropFirst(SemanticVectorsArtifacts.headerBytes)
        #expect(throws: SemanticMapPacker.PackError.self) {
            _ = try SemanticMapPacker.readPlacements(at: Self.write(Data(bare)), expectedCount: 99)
        }
    }

    @Test("The unclustered marker is distinct from every real cluster id")
    func unclusteredMarkerIsReserved() {
        #expect(SemanticMapArtifacts.unclustered == 0xFFFF)
        #expect(SemanticMapArtifacts.bytesPerDocument == 6)
    }

    /// Writes bytes to a temporary file.
    /// - Parameter data: The bytes.
    /// - Returns: The file URL.
    static func write(_ data: Data) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("map-\(UUID().uuidString).bin")
        try? data.write(to: url)
        return url
    }
}

// MARK: - The committed artifact

/// The shipped map, checked from the repository alone.
///
/// Version history:
///   1.0 — V-4: initial implementation
@Suite("SemanticMap — committed artifact")
struct SemanticMapCommittedTests {

    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer/Resources")

    static let mapIndex: SemanticMapArtifacts.MapIndex? = {
        let url = resources.appendingPathComponent("semantic-map-index.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SemanticMapArtifacts.MapIndex.self, from: data)
    }()

    /// The map and the vectors must describe the same corpus and the same generation, or a document
    /// appears at coordinates computed for a different vector.
    @Test("The map agrees with the vector artifact on corpus and provenance")
    func mapAgreesWithVectors() throws {
        let map = try #require(Self.mapIndex, "semantic-map-index.json missing or undecodable")
        let vectorsData = try #require(try? Data(contentsOf:
            Self.resources.appendingPathComponent("semantic-vectors-index.json")))
        let vectors = try JSONDecoder().decode(
            SemanticVectorsArtifacts.Index.self, from: vectorsData)

        #expect(map.documentCount == vectors.documentCount)
        #expect(map.provenanceDigest == vectors.provenanceDigest)
        #expect(map.schema == SemanticMapPacker.schema)
    }

    @Test("The map binary is exactly header plus six bytes per document")
    func mapBinaryLengthIsExact() throws {
        let map = try #require(Self.mapIndex)
        let data = try #require(try? Data(contentsOf:
            Self.resources.appendingPathComponent("semantic-map.bin")))
        #expect(data.count == SemanticVectorsArtifacts.headerBytes
                + map.documentCount * SemanticMapArtifacts.bytesPerDocument)
        #expect(String(data: data.prefix(4), encoding: .utf8) == SemanticMapArtifacts.mapMagic)
        #expect(data[20..<52].map { String(format: "%02x", $0) }.joined() == map.provenanceDigest)
    }

    /// Every cluster the binary references must exist in the roster, or the map draws a region it
    /// cannot name.
    @Test("Cluster ids are contiguous from zero and every one is labelled")
    func clustersAreCompleteAndLabelled() throws {
        let map = try #require(Self.mapIndex)
        #expect(!map.clusters.isEmpty)
        #expect(map.clusters.map(\.id) == Array(0..<map.clusters.count))
        for cluster in map.clusters {
            #expect(cluster.documentCount > 0, "cluster \(cluster.id) has no members")
            #expect(!cluster.terms.isEmpty, "cluster \(cluster.id) has no label")
            #expect(cluster.terms.allSatisfy { !ClusterLabeller.labelChrome.contains($0) })
            #expect(abs(cluster.centreX) <= map.gridExtent)
            #expect(abs(cluster.centreY) <= map.gridExtent)
        }
    }

    /// The counts have to add up: clustered members plus unclustered documents is the corpus.
    @Test("Cluster membership and the unclustered count together cover the corpus")
    func membershipCoversTheCorpus() throws {
        let map = try #require(Self.mapIndex)
        let clustered = map.clusters.reduce(0) { $0 + $1.documentCount }
        #expect(clustered + map.layout.unclusteredCount == map.documentCount)
    }

    /// The artifact must disclose that its labels were sampled — a label built from part of a cluster
    /// should say so rather than let a reader assume it saw everything.
    @Test("The layout block discloses the projection, the seed and the label sampling")
    func layoutBlockDiscloses() throws {
        let map = try #require(Self.mapIndex)
        #expect(map.layout.method.contains("UMAP"))
        #expect(map.layout.seed != 0)
        #expect(map.layout.sourceDims == 256)
        #expect(map.layout.labelSampling.contains("sampled"))
        #expect(map.layout.clustering.contains("HDBSCAN"))
    }
}
