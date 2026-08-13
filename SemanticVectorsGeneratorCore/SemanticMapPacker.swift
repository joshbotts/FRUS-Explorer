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
import GeneratorKit
import SemanticVectorsKit
import WordCloudKit

/// Packs the Tier-0 map: the layout stage's coordinates and clusters, plus the labels only Swift can
/// name.
///
/// Runs as a **separate pass** from the vector pack, and can be skipped. The vectors are the feature;
/// the map is a surface built on them, its layout comes from a Python stage that takes 15 minutes,
/// and a packer that refused to emit vectors because no layout existed would hold the shipping
/// feature hostage to an experimental one.
///
/// Version history:
///   1.0 — V-4: initial implementation
public enum SemanticMapPacker {

    /// Artifact schema version for `semantic-map-index.json`.
    public static let schema = 1

    /// Everything that can stop a map pack.
    public enum PackError: Error, CustomStringConvertible {
        /// `layout.bin` is not `documents × 6` bytes.
        case layoutSizeMismatch(expected: Int, actual: Int)
        /// The layout's metadata could not be read.
        case unreadableMeta(String)
        /// The layout describes a different corpus than the vectors do.
        case documentCountMismatch(layout: Int, artifact: Int)
        /// Every document came back unclustered, so there is nothing to label or draw regions from.
        case noClusters

        public var description: String {
            switch self {
            case .layoutSizeMismatch(let expected, let actual):
                return "layout.bin is \(actual) bytes, expected \(expected) (documents × 6)"
            case .unreadableMeta(let path):
                return "layout-meta.json unreadable at \(path)"
            case .documentCountMismatch(let layout, let artifact):
                return "layout places \(layout) documents, the vector artifact has \(artifact) — "
                    + "these are different corpora and their rows do not correspond"
            case .noClusters:
                return "the layout produced no clusters; refusing to write a map with no regions"
            }
        }
    }

    /// The layout stage's own metadata, as much of it as the artifact repeats.
    struct LayoutMeta: Decodable {
        struct UMAP: Decodable {
            let nNeighbors: Int
            let minDist: Double
            let metric: String
        }
        struct HDBSCAN: Decodable {
            let minClusterSize: Int
            let clusters: Int
            let unclustered: Int
        }
        struct Grid: Decodable { let extent: Double }
        let documents: Int
        let projectedFromDims: Int
        let seed: Int
        let umap: UMAP
        let hdbscan: HDBSCAN
        let grid: Grid
    }

    /// Reads `layout.bin` into placements.
    ///
    /// - Parameters:
    ///   - url: The layout binary.
    ///   - expectedCount: How many documents the vector artifact placed.
    /// - Returns: One placement per document, in row order.
    /// - Throws: `PackError` when the file's length disagrees with the corpus.
    static func readPlacements(
        at url: URL, expectedCount: Int
    ) throws -> [SemanticMapArtifacts.Placement] {
        let data = try Data(contentsOf: url)
        let expectedBytes = expectedCount * SemanticMapArtifacts.bytesPerDocument
        guard data.count == expectedBytes else {
            throw PackError.layoutSizeMismatch(expected: expectedBytes, actual: data.count)
        }
        return data.withUnsafeBytes { raw -> [SemanticMapArtifacts.Placement] in
            (0..<expectedCount).map { index in
                let base = index * SemanticMapArtifacts.bytesPerDocument
                return SemanticMapArtifacts.Placement(
                    x: Int16(bitPattern: raw.loadUnaligned(
                        fromByteOffset: base, as: UInt16.self).littleEndian),
                    y: Int16(bitPattern: raw.loadUnaligned(
                        fromByteOffset: base + 2, as: UInt16.self).littleEndian),
                    cluster: raw.loadUnaligned(
                        fromByteOffset: base + 4, as: UInt16.self).littleEndian)
            }
        }
    }

    /// Packs the map artifacts.
    ///
    /// - Parameters:
    ///   - layoutDir: Directory holding `layout.bin` and `layout-meta.json`.
    ///   - index: The vector artifact's index, for row keying and the shared pin.
    ///   - storeURL: The raw store, for the text the labels are built from.
    ///   - eraForVolume: A volume's coverage era, for the per-cluster era histogram.
    ///   - lexiconsPath: Path to the word-cloud lexicons.
    ///   - stopwordsPath: Path to the word-cloud stopwords.
    ///   - generated: Generation stamp.
    /// - Returns: The binary and the metadata, ready to write.
    /// - Throws: `PackError` or a labelling error.
    public static func pack(
        layoutDir: URL,
        index: SemanticVectorIndex,
        storeURL: URL,
        eraForVolume: (String) -> String,
        lexiconsPath: String,
        stopwordsPath: String,
        generated: String
    ) throws -> (binary: Data, meta: SemanticMapArtifacts.MapIndex) {
        let metaURL = layoutDir.appendingPathComponent("layout-meta.json")
        guard let metaData = try? Data(contentsOf: metaURL),
              let layoutMeta = try? JSONDecoder().decode(LayoutMeta.self, from: metaData)
        else { throw PackError.unreadableMeta(metaURL.path) }
        guard layoutMeta.documents == index.documentCount else {
            throw PackError.documentCountMismatch(
                layout: layoutMeta.documents, artifact: index.documentCount)
        }

        let placements = try readPlacements(
            at: layoutDir.appendingPathComponent("layout.bin"),
            expectedCount: index.documentCount)

        // Members, in row order, so the label sampler's stride spans a cluster's whole membership
        // rather than concentrating in whichever volumes come first.
        var members: [ClusterLabeller.Member] = []
        members.reserveCapacity(placements.count)
        var clusterRows: [Int: [Int]] = [:]
        for (row, placement) in placements.enumerated()
        where placement.cluster != SemanticMapArtifacts.unclustered {
            guard let document = index.document(at: row) else { continue }
            let cluster = Int(placement.cluster)
            members.append(ClusterLabeller.Member(
                volumeID: document.volumeID, documentID: document.documentID, cluster: cluster))
            clusterRows[cluster, default: []].append(row)
        }
        guard !clusterRows.isEmpty else { throw PackError.noClusters }

        // Read the sampled documents' text, one volume at a time: the text layer is per volume and
        // decompressing it 300 times over would dominate the pass.
        let sampled = ClusterLabeller.sample(members: members)
        var wantedByVolume: [String: [(documentID: String, cluster: Int)]] = [:]
        var sampledTotal = 0
        for (cluster, chosen) in sampled {
            sampledTotal += chosen.count
            for member in chosen {
                wantedByVolume[member.volumeID, default: []]
                    .append((documentID: member.documentID, cluster: cluster))
            }
        }

        let tokenizer = try ClusterLabeller.makeTokenizer(
            lexiconsPath: lexiconsPath, stopwordsPath: stopwordsPath)
        var counts: [Int: [String: Int]] = [:]
        for volumeID in wantedByVolume.keys.sorted() {
            guard let texts = SemanticRawStore.documentTexts(for: volumeID, at: storeURL) else {
                continue
            }
            for wanted in wantedByVolume[volumeID] ?? [] {
                guard let text = texts[wanted.documentID], !text.isEmpty else { continue }
                var local: [String: Int] = [:]
                tokenizer.accumulate(from: text, into: &local)
                for (term, count) in local {
                    counts[wanted.cluster, default: [:]][term, default: 0] += count
                }
            }
        }
        let labels = ClusterLabeller.label(counts: counts)

        // Cluster centres and era histograms, from the placements themselves.
        var clusters: [SemanticMapArtifacts.Cluster] = []
        clusters.reserveCapacity(clusterRows.count)
        for cluster in clusterRows.keys.sorted() {
            let rows = clusterRows[cluster] ?? []
            guard !rows.isEmpty else { continue }
            var sumX = 0, sumY = 0
            var eras: [String: Int] = [:]
            for row in rows {
                sumX += Int(placements[row].x)
                sumY += Int(placements[row].y)
                if let document = index.document(at: row) {
                    eras[eraForVolume(document.volumeID), default: 0] += 1
                }
            }
            clusters.append(SemanticMapArtifacts.Cluster(
                id: cluster,
                terms: labels[cluster] ?? [],
                documentCount: rows.count,
                centreX: sumX / rows.count,
                centreY: sumY / rows.count,
                eraCounts: eras))
        }

        let unclusteredCount = placements.filter {
            $0.cluster == SemanticMapArtifacts.unclustered
        }.count
        let mapIndex = SemanticMapArtifacts.MapIndex(
            schema: schema,
            generated: generated,
            provenanceDigest: index.provenance.digestHex,
            documentCount: placements.count,
            gridExtent: Int(layoutMeta.grid.extent),
            layout: SemanticMapArtifacts.MapIndex.Layout(
                method: "PCA-50 -> UMAP-2 (\(layoutMeta.umap.metric))",
                sourceDims: layoutMeta.projectedFromDims,
                neighbors: layoutMeta.umap.nNeighbors,
                minDist: layoutMeta.umap.minDist,
                seed: layoutMeta.seed,
                clustering: "HDBSCAN(min_cluster_size=\(layoutMeta.hdbscan.minClusterSize)) "
                    + "over the 2-D embedding",
                unclusteredCount: unclusteredCount,
                labelSampling: "c-TF-IDF over up to \(ClusterLabeller.documentsPerCluster) "
                    + "stride-sampled documents per cluster (\(sampledTotal) read of "
                    + "\(members.count) clustered)"),
            clusters: clusters)

        let binary = SemanticMapArtifacts.mapBinary(
            placements: placements, clusterCount: clusters.count,
            gridExtent: Int(layoutMeta.grid.extent), provenance: index.provenance)
        return (binary: binary, meta: mapIndex)
    }
}
