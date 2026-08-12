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

/// Stage 2 of the semantic-vectors pipeline: the deterministic packer.
///
/// Stage 1 is the neural harvest — owner-run through LM Studio, non-reproducible, pinned by
/// provenance (`tools/semantic-harvest/`). This is the half that must be reproducible, and it is:
/// given the same raw store it emits byte-identical artifacts, because every ordering is explicit
/// (volumes in manifest order, documents in store order, centroids in volume-then-subseries order)
/// and every arithmetic step is the pinned one from `SemanticQuantization`.
///
/// That split is the same epistemic move the keyness baseline makes when it pins tokenisation
/// rather than re-deriving it: determinism is asserted **from raw store to artifact**, and
/// provenance is what makes the store itself auditable.
///
/// The packer refuses rather than degrades. An empty volume set, a store whose model disagrees with
/// its run manifest, an id encoding that does not round-trip, a document whose vector cancels to
/// zero — each throws, because every one of them yields artifacts that load cleanly and retrieve
/// the wrong documents.
///
/// Version history:
///   1.0 — V-1: initial implementation (Tier 1 bundled binary + index, Tier 2 per-volume shards,
///         volume and subseries centroids). The Tier-0 map layer — 2-D coordinates and cluster
///         labels — waits on the UMAP/HDBSCAN stage, which needs a pinned non-stdlib Python
///         environment and ships as its own artifact.
public enum SemanticVectorsRunner {

    /// Artifact schema version for `semantic-vectors-index.json`.
    public static let schema = 1

    /// The candidate pool the Hamming tier hands the int8 rerank.
    ///
    /// Measured rather than assumed (`Planning/semantic-spike/Phase3-Store-Assessment.md` §5): the
    /// design's 200 costs 0.021 recall@10 against flat int8-256 but 0.047 against int8-512 — the
    /// pool binds exactly when the rerank tier gets better. At 800 the funnel lands within 0.004 of
    /// flat int8-256, for one wider rerank per query and an unchanged Hamming scan.
    public static let rerankPool = 800

    /// Recall@10 of the shipping funnel (Hamming-800 → int8-`dims`) against exact float-768
    /// neighbours, measured over 3,600 era-stratified queries at corpus scale — **keyed by width,
    /// because the number is a property of the width and nothing else in the artifact would say so.**
    ///
    /// A single constant here was a real defect: `DIMS` is an operator-set lever, and a 512-dim
    /// artifact carrying 256's 0.7449 would understate its own measured quality by 0.106 while
    /// citing the document that contradicts it. The artifact exists so a consumer need not read that
    /// document, which is exactly why a wrong number here would be the one believed. A width with no
    /// corpus-scale measurement is refused rather than shipped with a borrowed one.
    public static let measuredRecallAt10: [Int: Double] = [256: 0.7449, 512: 0.8510]

    /// Everything that can stop a pack.
    public enum RunError: Error, CustomStringConvertible {
        /// The manifest listed no volumes.
        case emptyManifest(String)
        /// A manifest volume has no completed store entry.
        case volumeMissingFromStore(String)
        /// The id run-length encoding did not reproduce its own input.
        case idRoundTripFailed(volume: String)
        /// A pooled vector could not be truncated or quantized.
        case degenerateVector(volume: String, documentID: String)
        /// A centroid cancelled to zero length.
        case degenerateCentroid(String)
        /// The harvest never recorded its weights digest, so the artifacts cannot pin a model.
        case unpinnedModel(String)
        /// `DIMS` was unusable, or names a width this program has never measured.
        case unusableDims(String)

        public var description: String {
            switch self {
            case .emptyManifest(let path):
                return "No volumes in manifest: \(path)"
            case .volumeMissingFromStore(let volume):
                return "Manifest volume absent or incomplete in the raw store: \(volume)"
            case .idRoundTripFailed(let volume):
                return "Document-id segments did not round-trip for \(volume) — refusing to write "
                    + "an artifact whose keys may name the wrong documents"
            case .degenerateVector(let volume, let documentID):
                return "\(volume)/\(documentID) truncated or quantized to nothing"
            case .degenerateCentroid(let name):
                return "Centroid for \(name) cancelled to zero length"
            case .unpinnedModel(let value):
                return "run-manifest model_file_sha256 is \(value.isEmpty ? "empty" : value) — a "
                    + "shipped artifact must name the weights it came from"
            case .unusableDims(let detail):
                return "DIMS \(detail). Measured widths: "
                    + measuredRecallAt10.keys.sorted().map(String.init).joined(separator: ", ")
                    + " — a width with no corpus-scale measurement would ship a recall number "
                    + "borrowed from a different artifact"
            }
        }
    }

    /// Runs the packer, honouring the environment overrides documented in `CLAUDE.md`.
    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let storeURL = URL(
            fileURLWithPath: (env["STORE"] as NSString?)?.expandingTildeInPath
                ?? ("~/frus-semantic-raw" as NSString).expandingTildeInPath)
        let manifestPath = env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"
        let outputDir = URL(fileURLWithPath: env["OUTPUT_DIR"] ?? "FRUSExplorer/Resources")
        let shardsDir = URL(
            fileURLWithPath: env["SHARDS_DIR"] ?? "Planning/semantic-vectors/shards")
        let generated = generatorDateStamp(override: env["GENERATED_DATE"])

        let runManifest = try SemanticRawStore.runManifest(at: storeURL)
        // Validated before anything is read or written. Left unchecked, a plausible typo reached a
        // `precondition` deep in the quantizer — and preconditions keep their teeth but lose their
        // messages in a release build, so `DIMS=7` exited 133 with no diagnostic at all, while
        // `DIMS=abc` silently packed at 256 as though the variable had never been set.
        let shippingDims = try resolveShippingDims(env["DIMS"], native: runManifest.dim)
        guard runManifest.modelFileSHA256.count == 64 else {
            throw RunError.unpinnedModel(runManifest.modelFileSHA256)
        }
        let provenance = SemanticVectorsArtifacts.Provenance(
            model: runManifest.model,
            modelFileSHA256: runManifest.modelFileSHA256,
            nativeDims: runManifest.dim,
            shippingDims: shippingDims,
            chunkChars: runManifest.chunkChars,
            overlapChars: runManifest.overlapChars,
            prefix: runManifest.prefix,
            pooling: "char-length-weighted mean of unit-norm chunk vectors, L2-renormalized",
            quantization: "Matryoshka cut then L2-renormalize; int8 per-vector symmetric "
                + "(scale = max|x|/127, rint half-to-even, clip ±127); binary = sign bit, "
                + "MSB-first, zero packs as 1")

        let volumes = try loadManifestVolumes(manifestPath)
        guard !volumes.isEmpty else { throw RunError.emptyManifest(manifestPath) }
        generatorLog("manifest: \(volumes.count) volumes | store: \(storeURL.path)")
        generatorLog("model \(provenance.model) | \(provenance.nativeDims) -> \(shippingDims) dims "
            + "| digest \(provenance.digestHex.prefix(12))…")

        try FileManager.default.createDirectory(
            at: shardsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: outputDir, withIntermediateDirectories: true)

        var entries: [SemanticVectorsArtifacts.VolumeEntry] = []
        var signBits: [[UInt8]] = []
        var volumeCentroids: [(codes: [Int8], scale: Float)] = []
        var subseriesAccumulator: [String: [[Float]]] = [:]
        var shardDigests: [(volume: String, sha256: String, bytes: Int)] = []
        var rowOffset = 0

        for (index, volume) in volumes.enumerated() {
            guard SemanticRawStore.head(for: volume.id, at: storeURL) != nil else {
                throw RunError.volumeMissingFromStore(volume.id)
            }
            let pooled = try SemanticRawStore.pooledDocuments(
                for: volume.id, at: storeURL, manifest: runManifest)

            var truncated: [[Float]] = []
            var codes: [[Int8]] = []
            var scales: [Float] = []
            truncated.reserveCapacity(pooled.count)
            for document in pooled {
                guard let cut = SemanticQuantization.truncate(document.vector, to: shippingDims),
                      let quantized = SemanticQuantization.quantizeInt8(cut)
                else {
                    throw RunError.degenerateVector(
                        volume: volume.id, documentID: document.documentID)
                }
                truncated.append(cut)
                codes.append(quantized.codes)
                scales.append(quantized.scale)
                signBits.append(SemanticQuantization.packSignBits(cut))
            }

            // Identity is stored, never derived — and the encoding proves itself before it ships.
            let ids = pooled.map(\.documentID)
            let segments = DocumentIDSegments.encode(ids)
            guard DocumentIDSegments.decode(segments) == ids else {
                throw RunError.idRoundTripFailed(volume: volume.id)
            }
            entries.append(SemanticVectorsArtifacts.VolumeEntry(
                volumeID: volume.id, rowOffset: rowOffset, documentCount: pooled.count,
                idSegments: segments))
            rowOffset += pooled.count

            guard let centre = SemanticQuantization.centroid(of: truncated, dims: shippingDims),
                  let quantizedCentre = SemanticQuantization.quantizeInt8(centre)
            else { throw RunError.degenerateCentroid(volume.id) }
            volumeCentroids.append(quantizedCentre)
            subseriesAccumulator[volume.subseries, default: []].append(contentsOf: truncated)

            let shard = SemanticVectorsArtifacts.volumeShard(
                codes: codes, scales: scales, dims: shippingDims, provenance: provenance)
            let shardURL = shardsDir.appendingPathComponent("\(volume.id).vec")
            try shard.write(to: shardURL, options: .atomic)
            shardDigests.append((
                volume: volume.id,
                sha256: Data(SHA256.hash(data: shard)).map { String(format: "%02x", $0) }.joined(),
                bytes: shard.count))

            if index % 50 == 0 || index == volumes.count - 1 {
                generatorLog("[\(index + 1)/\(volumes.count)] \(volume.id) "
                    + "\(pooled.count) docs | \(rowOffset) rows so far")
            }
        }

        // Subseries centroids follow the volume block, in sorted name order so the roster is stable
        // across runs regardless of dictionary iteration.
        let subseriesNames = subseriesAccumulator.keys.sorted()
        var centroids = volumeCentroids
        for name in subseriesNames {
            guard let vectors = subseriesAccumulator[name],
                  let centre = SemanticQuantization.centroid(of: vectors, dims: shippingDims),
                  let quantized = SemanticQuantization.quantizeInt8(centre)
            else { throw RunError.degenerateCentroid(name) }
            centroids.append(quantized)
        }

        let index = SemanticVectorsArtifacts.Index(
            schema: schema, generated: generated, provenance: provenance,
            harvestGenerated: runManifest.generated,
            harvestScriptSHA256: runManifest.scriptSHA256,
            documentCount: rowOffset, volumes: entries, subseries: subseriesNames,
            retrieval: SemanticVectorsArtifacts.Index.Retrieval(
                rerankPool: rerankPool,
                measuredRecallAt10: measuredRecallAt10[shippingDims] ?? 0,
                measuredBy: "Planning/semantic-spike/Phase3-Store-Assessment.md §5, 3,600 "
                    + "era-stratified queries over the 314,483-document corpus; "
                    + "Hamming-\(rerankPool) → int8-\(shippingDims)"))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let indexData = try encoder.encode(index)
        try indexData.write(
            to: outputDir.appendingPathComponent("semantic-vectors-index.json"), options: .atomic)

        let binary = SemanticVectorsArtifacts.corpusBinary(
            signBits: signBits, centroids: centroids, dims: shippingDims, provenance: provenance)
        try binary.write(
            to: outputDir.appendingPathComponent("semantic-vectors-binary.bin"), options: .atomic)

        // The shard manifest is the download channel's contract: what to fetch, how big, and
        // whether the bytes that arrived are the bytes that were packed.
        let shardManifest = ShardManifest(
            schema: schema, generated: generated, provenanceDigest: provenance.digestHex,
            shippingDims: shippingDims,
            shards: shardDigests.map {
                ShardManifest.Shard(volumeID: $0.volume, sha256: $0.sha256, bytes: $0.bytes)
            })
        let shardData = try encoder.encode(shardManifest)
        try shardData.write(
            to: shardsDir.deletingLastPathComponent()
                .appendingPathComponent("shards-manifest.json"), options: .atomic)

        // Shards are written per volume inside the loop while the manifest is written once at the
        // end, so an interrupted run leaves files this manifest does not describe — from an earlier
        // generation, or from a wider DIMS, or for volumes a trimmed MANIFEST dropped. The directory
        // is gitignored, so nothing else in the repository would ever show it. Prune to exactly what
        // this run published; a stale `.vec` is a shard some future fetch could serve under a
        // provenance digest it does not carry.
        let published = Set(shardDigests.map { "\($0.volume).vec" })
        let present = (try? FileManager.default.contentsOfDirectory(atPath: shardsDir.path)) ?? []
        var pruned = 0
        for name in present.sorted() where name.hasSuffix(".vec") && !published.contains(name) {
            try? FileManager.default.removeItem(at: shardsDir.appendingPathComponent(name))
            pruned += 1
        }
        if pruned > 0 { generatorLog("pruned \(pruned) shard(s) not published by this run") }

        generatorLog("""

            wrote:
              semantic-vectors-index.json   \(indexData.count) bytes | \(entries.count) volumes, \
            \(rowOffset) documents, \(entries.reduce(0) { $0 + $1.idSegments.count }) id segments
              semantic-vectors-binary.bin   \(binary.count) bytes | \(rowOffset) sign-bit rows + \
            \(centroids.count) centroids (\(volumeCentroids.count) volume, \
            \(subseriesNames.count) subseries)
              shards/*.vec                  \(shardDigests.count) files, \
            \(shardDigests.reduce(0) { $0 + $1.bytes }) bytes total
            """)
    }

    // MARK: - Configuration

    /// Resolves and validates the shipping width.
    ///
    /// - Parameters:
    ///   - raw: The `DIMS` environment value, if set.
    ///   - native: The store's native embedding width.
    /// - Returns: The validated width, defaulting to 256.
    /// - Throws: `RunError.unusableDims` for anything unparseable, unrepresentable, wider than the
    ///   store, not byte-aligned, or without a corpus-scale measurement.
    static func resolveShippingDims(_ raw: String?, native: Int) throws -> Int {
        guard let raw, !raw.isEmpty else { return 256 }
        guard let dims = Int(raw) else { throw RunError.unusableDims("is not a number: \(raw)") }
        guard dims > 0 else { throw RunError.unusableDims("must be positive, got \(dims)") }
        guard dims <= native else {
            throw RunError.unusableDims("(\(dims)) exceeds the store's native width \(native)")
        }
        guard dims % 8 == 0 else {
            throw RunError.unusableDims("(\(dims)) must be a multiple of 8 to pack sign bits")
        }
        guard measuredRecallAt10[dims] != nil else {
            throw RunError.unusableDims("(\(dims)) has no corpus-scale measurement")
        }
        return dims
    }

    // MARK: - Shard manifest

    /// The Tier-2 download channel's manifest: one row per volume shard.
    public struct ShardManifest: Codable, Sendable {
        /// Artifact schema version.
        public let schema: Int
        /// `yyyy-MM-dd` generation stamp.
        public let generated: String
        /// The provenance digest every shard header carries; a consumer refuses a mismatch.
        public let provenanceDigest: String
        /// Shipping width of the shard vectors.
        public let shippingDims: Int
        /// Shards in manifest volume order.
        public let shards: [Shard]

        /// One downloadable shard.
        public struct Shard: Codable, Sendable {
            /// Manifest `volumeId`; the file is `<volumeID>.vec`.
            public let volumeID: String
            /// SHA-256 of the shard bytes.
            public let sha256: String
            /// Shard size in bytes.
            public let bytes: Int

            /// Creates a shard row.
            /// - Parameters:
            ///   - volumeID: Manifest `volumeId`.
            ///   - sha256: Digest of the shard bytes.
            ///   - bytes: Shard size.
            public init(volumeID: String, sha256: String, bytes: Int) {
                self.volumeID = volumeID
                self.sha256 = sha256
                self.bytes = bytes
            }
        }

        /// Creates the shard manifest.
        /// - Parameters:
        ///   - schema: Schema version.
        ///   - generated: Generation stamp.
        ///   - provenanceDigest: The shared pin's hex digest.
        ///   - shippingDims: Shard vector width.
        ///   - shards: Shard rows in manifest volume order.
        public init(
            schema: Int, generated: String, provenanceDigest: String, shippingDims: Int,
            shards: [Shard]
        ) {
            self.schema = schema
            self.generated = generated
            self.provenanceDigest = provenanceDigest
            self.shippingDims = shippingDims
            self.shards = shards
        }
    }

    // MARK: - Manifest

    /// The two manifest fields the packer needs: the volume's id and its subseries.
    private struct ManifestVolume {
        let id: String
        let subseries: String
    }

    /// Reads the app manifest's volume list, preserving its order — which is the artifact's row
    /// order and therefore part of the contract.
    ///
    /// - Parameter path: Path to `manifest.json`.
    /// - Returns: The volumes in manifest order.
    private static func loadManifestVolumes(_ path: String) throws -> [ManifestVolume] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw GeneratorError.missingFile(path)
        }
        struct Entry: Decodable {
            let volumeId: String
            let subseries: String?
        }
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        return entries.map { ManifestVolume(id: $0.volumeId, subseries: $0.subseries ?? "") }
    }
}
