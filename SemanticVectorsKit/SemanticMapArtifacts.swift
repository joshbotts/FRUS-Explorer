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

/// Tier 0 — the discovery map's layer: where each document sits in two dimensions, and which cluster
/// it belongs to.
///
/// A **separate artifact** from the vector tiers rather than a block appended to them, because the
/// access patterns differ: a device may want the map without ever scanning for neighbours, and the
/// V-4 surface loads on a different path from the Related Documents axis. It carries the same
/// provenance digest as every other tier, so the family version-skew rule applies unchanged — a map
/// from one generation must never be drawn against vectors from another, or documents appear at
/// coordinates computed for different vectors.
///
/// Sizes, measured on the shipped corpus: the binary is **1.80 MiB** (6 bytes per document, the
/// design's §4.1 estimate) and the metadata ~60 KB for 179 clusters.
///
/// Version history:
///   1.0 — V-4: initial implementation
public enum SemanticMapArtifacts {

    /// Magic for the map binary.
    public static let mapMagic = "FRSM"

    /// Bytes per document: int16 x, int16 y, uint16 cluster.
    public static let bytesPerDocument = 6

    /// The cluster id meaning "this document was not clustered".
    ///
    /// HDBSCAN leaves a substantial minority unclustered by design — measured, 28.0% of the corpus —
    /// and that is information, not a gap: those documents sit between the map's regions. A surface
    /// must render them as unclustered rather than folding them into a neighbouring cluster.
    public static let unclustered: UInt16 = 0xFFFF

    /// One cluster's identity, as the map's metadata carries it.
    public struct Cluster: Codable, Sendable {
        /// Cluster id; matches the `uint16` stored per document.
        public let id: Int
        /// The label's terms, most distinctive first, in the anchor corpus's own vocabulary.
        public let terms: [String]
        /// Documents in the cluster.
        public let documentCount: Int
        /// Grid coordinates of the cluster's centre, for label placement.
        public let centreX: Int
        /// Grid Y of the cluster's centre.
        public let centreY: Int
        /// Documents per coverage era, keyed by the app's own `CoverageEra` raw value, so a cluster
        /// tooltip can say *when* as well as *what* without a second pass over the corpus.
        public let eraCounts: [String: Int]

        /// Creates a cluster record.
        /// - Parameters:
        ///   - id: Cluster id.
        ///   - terms: Label terms.
        ///   - documentCount: Members.
        ///   - centreX: Grid X of the centre.
        ///   - centreY: Grid Y of the centre.
        ///   - eraCounts: Members per era.
        public init(id: Int, terms: [String], documentCount: Int, centreX: Int, centreY: Int,
                    eraCounts: [String: Int]) {
            self.id = id
            self.terms = terms
            self.documentCount = documentCount
            self.centreX = centreX
            self.centreY = centreY
            self.eraCounts = eraCounts
        }
    }

    /// The map's metadata: provenance, layout parameters, and the cluster roster.
    public struct MapIndex: Codable, Sendable {
        /// Artifact schema version.
        public let schema: Int
        /// `yyyy-MM-dd` generation stamp.
        public let generated: String
        /// Hex provenance digest — the same pin the vector tiers carry.
        public let provenanceDigest: String
        /// Documents placed.
        public let documentCount: Int
        /// Half-extent of the grid the coordinates were quantized into.
        public let gridExtent: Int
        /// How the layout was produced, verbatim from the layout stage's own metadata, so a reader
        /// can tell which projection they are looking at without leaving the artifact.
        public let layout: Layout
        /// The clusters, by ascending id.
        public let clusters: [Cluster]

        /// The layout stage's parameters and cost.
        public struct Layout: Codable, Sendable {
            /// Projection method.
            public let method: String
            /// Width the projection consumed.
            public let sourceDims: Int
            /// UMAP neighbourhood size.
            public let neighbors: Int
            /// UMAP minimum distance.
            public let minDist: Double
            /// Random seed pinned for every stage.
            public let seed: Int
            /// Clustering method and its minimum cluster size.
            public let clustering: String
            /// Documents left unclustered.
            public let unclusteredCount: Int
            /// How many documents per cluster were read to build the labels, and the total read.
            public let labelSampling: String

            /// Creates a layout record.
            /// - Parameters:
            ///   - method: Projection method.
            ///   - sourceDims: Width projected from.
            ///   - neighbors: UMAP neighbourhood size.
            ///   - minDist: UMAP minimum distance.
            ///   - seed: Pinned seed.
            ///   - clustering: Clustering description.
            ///   - unclusteredCount: Documents with no cluster.
            ///   - labelSampling: How labels were sampled.
            public init(method: String, sourceDims: Int, neighbors: Int, minDist: Double, seed: Int,
                        clustering: String, unclusteredCount: Int, labelSampling: String) {
                self.method = method
                self.sourceDims = sourceDims
                self.neighbors = neighbors
                self.minDist = minDist
                self.seed = seed
                self.clustering = clustering
                self.unclusteredCount = unclusteredCount
                self.labelSampling = labelSampling
            }
        }

        /// Creates the map index.
        /// - Parameters:
        ///   - schema: Schema version.
        ///   - generated: Generation stamp.
        ///   - provenanceDigest: The family pin.
        ///   - documentCount: Documents placed.
        ///   - gridExtent: Grid half-extent.
        ///   - layout: Layout parameters.
        ///   - clusters: Cluster roster.
        public init(schema: Int, generated: String, provenanceDigest: String, documentCount: Int,
                    gridExtent: Int, layout: Layout, clusters: [Cluster]) {
            self.schema = schema
            self.generated = generated
            self.provenanceDigest = provenanceDigest
            self.documentCount = documentCount
            self.gridExtent = gridExtent
            self.layout = layout
            self.clusters = clusters
        }
    }

    /// One document's placement.
    public struct Placement: Sendable, Equatable {
        /// Grid X.
        public let x: Int16
        /// Grid Y.
        public let y: Int16
        /// Cluster id, or `unclustered`.
        public let cluster: UInt16

        /// Creates a placement.
        /// - Parameters:
        ///   - x: Grid X.
        ///   - y: Grid Y.
        ///   - cluster: Cluster id.
        public init(x: Int16, y: Int16, cluster: UInt16) {
            self.x = x
            self.y = y
            self.cluster = cluster
        }
    }

    /// Builds the map binary.
    ///
    /// Layout, little-endian:
    ///
    /// ```
    /// 0   magic "FRSM"        4 B
    /// 4   version             4 B  UInt32
    /// 8   document count      4 B  UInt32
    /// 12  cluster count       4 B  UInt32
    /// 16  grid extent         4 B  UInt32
    /// 20  provenance digest  32 B
    /// 52  zero padding       12 B
    /// 64  placements   docs × 6 B  (int16 x, int16 y, uint16 cluster)
    /// ```
    ///
    /// - Parameters:
    ///   - placements: One per document, in the vector artifact's row order.
    ///   - clusterCount: Distinct clusters, excluding the unclustered marker.
    ///   - gridExtent: Half-extent the coordinates were quantized into.
    ///   - provenance: The family pin.
    /// - Returns: The complete file bytes.
    public static func mapBinary(
        placements: [Placement], clusterCount: Int, gridExtent: Int,
        provenance: SemanticVectorsArtifacts.Provenance
    ) -> Data {
        var data = Data()
        data.reserveCapacity(
            SemanticVectorsArtifacts.headerBytes + placements.count * bytesPerDocument)
        data.append(contentsOf: Array(mapMagic.utf8))
        appendLittleEndian(&data, SemanticVectorsArtifacts.binaryVersion)
        appendLittleEndian(&data, UInt32(placements.count))
        appendLittleEndian(&data, UInt32(clusterCount))
        appendLittleEndian(&data, UInt32(gridExtent))
        data.append(provenance.digest)
        data.append(Data(repeating: 0, count: SemanticVectorsArtifacts.headerBytes - data.count))
        for placement in placements {
            appendLittleEndian(&data, UInt16(bitPattern: placement.x))
            appendLittleEndian(&data, UInt16(bitPattern: placement.y))
            appendLittleEndian(&data, placement.cluster)
        }
        return data
    }

    /// Appends a 32-bit value little-endian.
    /// - Parameters:
    ///   - data: Buffer.
    ///   - value: Value.
    private static func appendLittleEndian(_ data: inout Data, _ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    /// Appends a 16-bit value little-endian.
    /// - Parameters:
    ///   - data: Buffer.
    ///   - value: Value.
    private static func appendLittleEndian(_ data: inout Data, _ value: UInt16) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
