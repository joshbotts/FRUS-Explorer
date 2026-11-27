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

import CryptoKit
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
/// **A layout is packed only over the vectors it was laid out over (#2023).** EmbeddingGemma 300m's
/// store and EmbeddingGemma 2's both hold 314,616 documents of 768 dimensions, so a layout's count
/// and length cannot tell them apart, and the map's two scripts defaulted to the 300m's store and
/// pool. `layout-meta.json` names the store its pool was made from and the `layout.bin` written with
/// it, and both passes refuse a layout that names another store, another file or neither.
///
/// Version history:
///   1.0 — V-4: initial implementation
///   1.1 — #1373 review round 3: `pack` refuses first, before reading anything, when this process's
///          tagger has no lemmatiser (`ClusterLabeller.requireLanguageAnalysis`)
///   1.2 — #1439: `preflight`, every refusal a map pass can make that needs no vector artifact, so
///          the runner can make them before it writes a byte; `readLayoutMeta` is shared with `pack`
///   1.3 — #1439 review, round 1: `preflight`'s doc names the runner's other pre-write read, the
///          manifest's coverage dates, which this function does not make
///   1.4 — #2023 (row L61): `preflight` and `pack` refuse a layout laid out over another store's
///          vectors (`VectorSource`, `requireSource(of:is:)`), a `layout.bin` that is not the file
///          its metadata describes (`requireLayoutFile(in:describedBy:)`), and a layout whose
///          metadata names neither, as every layout before #2023
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
        /// The layout describes a different corpus than the raw store's volume heads add up to —
        /// ``preflight(layoutDir:expectedDocumentCount:lexiconsPath:stopwordsPath:health:)``'s
        /// form of ``documentCountMismatch(layout:artifact:)``, raised before anything is written.
        case storeCountMismatch(layout: Int, store: Int)
        /// Every document came back unclustered, so there is nothing to label or draw regions from.
        case noClusters
        /// `layout-meta.json` does not say which store's vectors the layout was laid out over, or
        /// which `layout.bin` it describes: a layout written before #2023, or by hand. `missing`
        /// names the absent fields.
        case unattributedLayout(missing: [String])
        /// The layout was laid out over the vectors of another store (#2023): each field of the
        /// store's run manifest on which the layout's store and the packed one differ.
        case layoutFromAnotherStore(differences: [String])
        /// `layout.bin` is not the file `layout-meta.json` describes (#2023): their SHA-256s.
        case layoutFileMismatch(recorded: String, actual: String)

        /// How to make a layout the packer takes, or to pack without one.
        private static let rebuild = "Run tools/semantic-harvest/corpus-gates/pool_docs.py with STORE "
            + "set to the store this run packs, then tools/semantic-map/build_layout.py over that pool "
            + "into LAYOUT_DIR, or point LAYOUT_DIR at a directory with no layout.bin to pack the "
            + "vectors without a map"

        public var description: String {
            switch self {
            case .layoutSizeMismatch(let expected, let actual):
                return "layout.bin is \(actual) bytes, expected \(expected) (documents × 6)"
            case .unreadableMeta(let path):
                return "layout-meta.json unreadable at \(path)"
            case .documentCountMismatch(let layout, let artifact):
                return "layout places \(layout) documents, the vector artifact has \(artifact) — "
                    + "these are different corpora and their rows do not correspond"
            case .storeCountMismatch(let layout, let store):
                return "layout places \(layout) documents, the raw store's volume heads total "
                    + "\(store) — the layout was built over a different corpus and its rows would "
                    + "not correspond. Nothing was written. Re-run tools/semantic-map/build_layout.py "
                    + "over this store, or point LAYOUT_DIR at a directory with no layout.bin to "
                    + "pack the vectors without a map"
            case .noClusters:
                return "the layout produced no clusters; refusing to write a map with no regions"
            case .unattributedLayout(let missing):
                return "layout-meta.json records no \(missing.joined(separator: " and no ")): it was "
                    + "written before #2023, or by hand, so it cannot say which store's vectors the "
                    + "layout was laid out over, nor that layout.bin is the file it describes. "
                    + "Nothing was written. " + Self.rebuild
            case .layoutFromAnotherStore(let differences):
                return "the layout was laid out over another store's vectors ("
                    + differences.joined(separator: "; ") + "), so its map would place and label "
                    + "documents by vectors this pack does not hold. Nothing was written. " + Self.rebuild
            case .layoutFileMismatch(let recorded, let actual):
                return "layout.bin has SHA-256 \(actual.prefix(12))…, and layout-meta.json describes "
                    + "\(recorded.prefix(12))…: the two come from different layout runs (a gitignored "
                    + "layout.bin can outlive the metadata committed beside it). Nothing was written. "
                    + Self.rebuild
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
        /// The store the layout's pool was made from, as `pool_docs.py` read its run manifest and
        /// `build_layout.py` copied it (#2023); `nil` in a layout written before.
        let store: VectorSource?
        /// The SHA-256 of the `layout.bin` written with this metadata (#2023); `nil` before.
        let layoutSHA256: String?
    }

    /// What says which vectors a store holds: the fields of its `run-manifest.json` that the vector
    /// artifact's provenance is built from, under the manifest's own names (#2023).
    ///
    /// The path, the harvest date and the harvester script are left out. A store is its vectors, not
    /// its folder, and a store harvested again under the same model, weights and contract holds the
    /// same family of vectors; the corpus it covers is checked on its own, by the document count.
    struct VectorSource: Decodable, Equatable {
        /// The model id the store was embedded under.
        let model: String
        /// The SHA-256 of the model's GGUF weights.
        let modelFileSHA256: String
        /// The native embedding width.
        let dim: Int
        /// Characters per chunk window.
        let chunkChars: Int
        /// Characters of overlap between consecutive windows.
        let overlapChars: Int
        /// The document-side prompt, trailing space included.
        let prefix: String

        private enum CodingKeys: String, CodingKey {
            case model
            case modelFileSHA256 = "model_file_sha256"
            case dim
            case chunkChars = "chunk_chars"
            case overlapChars = "overlap_chars"
            case prefix
        }

        /// Each field on which `self`, the layout's store, and `packed`, the store being packed,
        /// differ, under the run manifest's name for it, in a fixed order.
        ///
        /// - Parameter packed: The source of the vectors being packed.
        /// - Returns: `name: the layout's …, the packed store's …` for each differing field.
        func differences(from packed: VectorSource) -> [String] {
            // Compared as values, shown abbreviated: two digests that share a prefix still differ.
            var found: [String] = []
            func note(_ name: String, differ: Bool, _ layout: String, _ packedValue: String) {
                guard differ else { return }
                found.append("\(name): the layout's \(layout), the packed store's \(packedValue)")
            }
            note("model", differ: model != packed.model, "\"\(model)\"", "\"\(packed.model)\"")
            note("model_file_sha256", differ: modelFileSHA256 != packed.modelFileSHA256,
                 "\(modelFileSHA256.prefix(12))…", "\(packed.modelFileSHA256.prefix(12))…")
            note("dim", differ: dim != packed.dim, String(dim), String(packed.dim))
            note("chunk_chars", differ: chunkChars != packed.chunkChars,
                 String(chunkChars), String(packed.chunkChars))
            note("overlap_chars", differ: overlapChars != packed.overlapChars,
                 String(overlapChars), String(packed.overlapChars))
            note("prefix", differ: prefix != packed.prefix, "\"\(prefix)\"", "\"\(packed.prefix)\"")
            return found
        }
    }

    /// Refuses a layout whose metadata does not say which store's vectors it was laid out over, or
    /// says another's (#2023).
    ///
    /// - Parameters:
    ///   - layoutMeta: The layout's metadata.
    ///   - vectors: The source of the vectors being packed: the store's run manifest before the
    ///     vectors are written, the vector artifact's provenance after.
    /// - Throws: `PackError.unattributedLayout` or `PackError.layoutFromAnotherStore`.
    static func requireSource(of layoutMeta: LayoutMeta, is vectors: VectorSource) throws {
        let missing = [layoutMeta.store == nil ? "store" : nil,
                       layoutMeta.layoutSHA256 == nil ? "layoutSHA256" : nil].compactMap { $0 }
        guard missing.isEmpty, let store = layoutMeta.store else {
            throw PackError.unattributedLayout(missing: missing)
        }
        let differences = store.differences(from: vectors)
        guard differences.isEmpty else {
            throw PackError.layoutFromAnotherStore(differences: differences)
        }
    }

    /// Refuses a `layout.bin` that is not the file `layout-meta.json` describes (#2023): until L28 the
    /// root checkout held the 300m's gitignored `layout.bin` beside the committed metadata of
    /// EmbeddingGemma 2's layout, and the two read as one layout of the right length.
    ///
    /// - Parameters:
    ///   - layoutDir: Directory holding `layout.bin`.
    ///   - layoutMeta: The layout's metadata, whose `layoutSHA256` ``requireSource(of:is:)`` has
    ///     required.
    /// - Throws: `PackError.layoutFileMismatch`, or the read's error.
    static func requireLayoutFile(in layoutDir: URL, describedBy layoutMeta: LayoutMeta) throws {
        let data = try Data(contentsOf: layoutDir.appendingPathComponent("layout.bin"))
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let recorded = layoutMeta.layoutSHA256 ?? ""
        guard recorded.lowercased() == actual else {
            throw PackError.layoutFileMismatch(recorded: recorded, actual: actual)
        }
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

    /// Reads the layout stage's metadata.
    ///
    /// - Parameter layoutDir: Directory holding `layout-meta.json`.
    /// - Returns: The decoded metadata.
    /// - Throws: `PackError.unreadableMeta` when the file is absent or does not decode.
    static func readLayoutMeta(in layoutDir: URL) throws -> LayoutMeta {
        let metaURL = layoutDir.appendingPathComponent("layout-meta.json")
        guard let metaData = try? Data(contentsOf: metaURL),
              let layoutMeta = try? JSONDecoder().decode(LayoutMeta.self, from: metaData)
        else { throw PackError.unreadableMeta(metaURL.path) }
        return layoutMeta
    }

    /// Makes every refusal a map pass can make without the vector artifact, so the runner can make
    /// them **before it writes anything** (#1439).
    ///
    /// ## Why it exists
    /// The map pass runs after the vector artifacts are written, because it keys its rows through
    /// the index the vector pass builds. So a map pass that refused — no lemmatiser in this process
    /// (#1373), a layout built over another corpus — left the NEW `semantic-vectors-*` artifacts
    /// beside the PREVIOUS `semantic-map*` ones, and in a run that also moved the provenance digest
    /// or the document count `SemanticMapCommittedTests.mapAgreesWithVectors` failed until the map
    /// was packed again. `SemanticVectorsRunner.run` calls this first when `layout.bin` exists.
    ///
    /// ## What it checks, in ``pack(layoutDir:index:storeURL:eraForVolume:lexiconsPath:stopwordsPath:generated:)``'s order
    /// 1. the tagger verdict lemmatises (`ClusterLabeller.requireLanguageAnalysis`);
    /// 2. `layout-meta.json` reads;
    /// 3. it names the store its pool was made from and the `layout.bin` written with it, and that
    ///    store holds the vectors `store` describes (``requireSource(of:is:)``, #2023);
    /// 4. `layout.bin` is the file it names (``requireLayoutFile(in:describedBy:)``, #2023);
    /// 5. the layout places `expectedDocumentCount` documents;
    /// 6. `layout.bin` is that many rows;
    /// 7. at least one row is clustered;
    /// 8. the stopword and lexicon payloads read (`ClusterLabeller.makeTokenizer`).
    ///
    /// That is every `throw` in `pack`. `pack` keeps its own, because its count is the exact one —
    /// the rows the vector pass really pooled — where the runner hands this the sum of the store's
    /// volume heads. The two agreed on all 553 volumes of the shipped store (measured 2026-10-01:
    /// 314,571 by either count; 314,616 by either on 2026-10-10), so a store whose heads misstate its documents is the one case
    /// that can still refuse after the vectors are written. Its source check reads the vector
    /// artifact's provenance, which the runner builds from the same run manifest this one reads.
    ///
    /// **`pack`'s throws are not the runner's whole map block.** The runner also decodes the
    /// manifest's coverage dates for the era histograms (`SemanticVectorsRunner.loadVolumeEras`),
    /// a stricter read than its volume list, and until the review of #1439 it did so after the
    /// vectors were written. It now reads them beside this call, before its first write, and
    /// `RunWriteOrderTests` requires that the block after the vectors makes no throwing call but
    /// `pack` and its two writes.
    ///
    /// - Parameters:
    ///   - layoutDir: Directory holding `layout.bin` and `layout-meta.json`.
    ///   - expectedDocumentCount: How many documents the vector pass will place.
    ///   - store: The run manifest of the store the vector pass will pack.
    ///   - lexiconsPath: Path to the word-cloud lexicons.
    ///   - stopwordsPath: Path to the word-cloud stopwords.
    ///   - health: The tagger verdict the labels would be counted under.
    /// - Throws: `ClusterLabeller.LabelError` or `PackError`, in the order above.
    static func preflight(
        layoutDir: URL,
        expectedDocumentCount: Int,
        store: SemanticRawStore.RunManifest,
        lexiconsPath: String,
        stopwordsPath: String,
        health: NaturalLanguageHealth
    ) throws {
        try ClusterLabeller.requireLanguageAnalysis(health)
        let layoutMeta = try readLayoutMeta(in: layoutDir)
        try requireSource(of: layoutMeta, is: VectorSource(
            model: store.model, modelFileSHA256: store.modelFileSHA256, dim: store.dim,
            chunkChars: store.chunkChars, overlapChars: store.overlapChars, prefix: store.prefix))
        try requireLayoutFile(in: layoutDir, describedBy: layoutMeta)
        guard layoutMeta.documents == expectedDocumentCount else {
            throw PackError.storeCountMismatch(
                layout: layoutMeta.documents, store: expectedDocumentCount)
        }
        let placements = try readPlacements(
            at: layoutDir.appendingPathComponent("layout.bin"),
            expectedCount: expectedDocumentCount)
        guard placements.contains(where: { $0.cluster != SemanticMapArtifacts.unclustered }) else {
            throw PackError.noClusters
        }
        _ = try ClusterLabeller.makeTokenizer(
            lexiconsPath: lexiconsPath, stopwordsPath: stopwordsPath)
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
    /// - Throws: `PackError` or a labelling error — first of all
    ///   `ClusterLabeller.LabelError.languageAnalysisUnavailable` when this process's tagger has no
    ///   lemmatiser, checked before anything is read, so the runner writes no map and the previous
    ///   map artifacts stay as they were (#1373). The runner has made each of these refusals once
    ///   already, before it wrote the vectors (``preflight(layoutDir:expectedDocumentCount:lexiconsPath:stopwordsPath:health:)``,
    ///   #1439); they stay here because this function's document count is the exact one.
    public static func pack(
        layoutDir: URL,
        index: SemanticVectorIndex,
        storeURL: URL,
        eraForVolume: (String) -> String,
        lexiconsPath: String,
        stopwordsPath: String,
        generated: String
    ) throws -> (binary: Data, meta: SemanticMapArtifacts.MapIndex) {
        // The labels are counted through the app's tokenizer, which reads the lemmatiser: refuse
        // before reading anything rather than label every cluster in printed forms.
        try ClusterLabeller.requireLanguageAnalysis(NaturalLanguageReadiness.health)
        let layoutMeta = try readLayoutMeta(in: layoutDir)
        // The vectors the map's rows are keyed through, and whose digest its binary carries (#2023).
        let provenance = index.provenance
        try requireSource(of: layoutMeta, is: VectorSource(
            model: provenance.model, modelFileSHA256: provenance.modelFileSHA256,
            dim: provenance.nativeDims, chunkChars: provenance.chunkChars,
            overlapChars: provenance.overlapChars, prefix: provenance.prefix))
        try requireLayoutFile(in: layoutDir, describedBy: layoutMeta)
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
