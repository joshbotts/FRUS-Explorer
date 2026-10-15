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
///   1.1 — lane HYG (2026-10-01): `DIMS` defaults to the width the bundle ships
///         (``defaultShippingDims``, 512), where it defaulted to 256 and a regeneration that forgot
///         the variable repacked the bundle at half width; and #1439 — every refusal the map pass
///         can make is made before the first write (``run(environment:languageAnalysis:)``)
///   1.2 — #1439 review, round 1: the manifest's coverage dates are decoded before the first
///         write too. `loadVolumeEras` ran after the vectors and shards were on disk and reads a
///         stricter shape than the volume list, so a one-sided `dateRange` refused there
///   1.3 — B4 (#1659, 2026-10-15): the measured recall is keyed by model as well as width
///         (``funnelMeasurements``), and a model's score calibration is packed with it
///         (``scoreCalibrations``), for the move to EmbeddingGemma 2
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

    /// What the corpus gates measured of one model's shipping funnel at one width: recall@10
    /// against exact float-768 neighbours over 3,600 era-stratified queries, and where.
    public struct FunnelMeasurement: Sendable, Equatable {
        /// Recall@10 of Hamming-800 → int8 at the width.
        public let recallAt10: Double
        /// The artifact's `retrieval.measuredBy`, verbatim.
        public let measuredBy: String
    }

    /// The SHA-256 of EmbeddingGemma 300m's GGUF, the model builds 42 to 50 shipped.
    public static let embeddingGemma300mSHA256 =
        "5a9e0645541b06367dec3fd14d0019015b872cfe36d35dfb2a9d752dade09020"

    /// The SHA-256 of EmbeddingGemma 2's GGUF, the model shipped from build 51 (#1659, B4).
    public static let embeddingGemma2SHA256 =
        "2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135"

    /// Recall@10 of the shipping funnel, **keyed by the model's GGUF SHA-256 and then by width,
    /// because the number is a property of both and nothing else in the artifact would say so.**
    ///
    /// A single constant here was a real defect: `DIMS` is an operator-set lever, and a 512-dim
    /// artifact carrying 256's 0.7449 would understate its own measured quality by 0.106 while
    /// citing the document that contradicts it. The artifact exists so a consumer need not read that
    /// document, which is exactly why a wrong number here would be the one believed. A width with no
    /// corpus-scale measurement is refused rather than shipped with a borrowed one.
    ///
    /// **Keyed by model since B4 (2026-10-15)**, for the same defect one level up: keyed by width
    /// alone, B2's pack of EmbeddingGemma 2 stated the 300m's 0.851 and cited the 300m's
    /// measurement (the stage-2 memo's §3). A model with no entry is refused at every width.
    ///
    /// The 300m's two entries are August's, word for word, so a control repack of its store is
    /// byte-identical to the artifact builds 42 to 50 shipped; its 0.851 was measured with 256 sign
    /// bits ahead of the int8-512 rerank, and the 512-bit funnel those builds ran measures 0.861
    /// (the stage-2 memo's §5). EmbeddingGemma 2's are that memo's §5, through the funnel the app
    /// runs.
    public static let funnelMeasurements: [String: [Int: FunnelMeasurement]] = [
        embeddingGemma300mSHA256: [
            256: FunnelMeasurement(
                recallAt10: 0.7449,
                measuredBy: "Planning/semantic-spike/Phase3-Store-Assessment.md §5, 3,600 "
                    + "era-stratified queries over the 314,483-document corpus; "
                    + "Hamming-800 → int8-256"),
            512: FunnelMeasurement(
                recallAt10: 0.8510,
                measuredBy: "Planning/semantic-spike/Phase3-Store-Assessment.md §5, 3,600 "
                    + "era-stratified queries over the 314,483-document corpus; "
                    + "Hamming-800 → int8-512"),
        ],
        embeddingGemma2SHA256: [
            256: FunnelMeasurement(
                recallAt10: 0.7845,
                measuredBy: "Planning/semantic-vectors/EmbeddingGemma-2-Stage-2-2026-10-15.md §5, "
                    + "3,600 era-stratified queries over the 314,616-document corpus; "
                    + "Hamming-800 over 256 sign bits → int8-256"),
            512: FunnelMeasurement(
                recallAt10: 0.9021,
                measuredBy: "Planning/semantic-vectors/EmbeddingGemma-2-Stage-2-2026-10-15.md §5, "
                    + "3,600 era-stratified queries over the 314,616-document corpus; "
                    + "Hamming-800 over 512 sign bits → int8-512"),
        ],
    ]

    /// How each model's cosines are shown, by GGUF SHA-256 (B4, the owner's decision of
    /// 2026-10-15). A model with no entry packs with none, and its consumers show the raw cosine:
    /// the 300m's builds did, so its control repack stays byte-identical.
    public static let scoreCalibrations: [String: SemanticVectorsArtifacts.Index.ScoreCalibration] = [
        embeddingGemma2SHA256: SemanticVectorsArtifacts.Index.ScoreCalibration(
            queryOffset: 0.47,
            documentOffset: 0.40,
            measuredBy: "Planning/semantic-vectors/EmbeddingGemma-2-B4-Move-2026-10-15.md §1b, "
                + "fitted to EmbeddingGemma 300m's scores over 90 typed queries and 600 anchor "
                + "documents against the 314,616-document corpus"),
    ]

    /// The width a run packs at when `DIMS` is unset: the width the bundle ships.
    ///
    /// It was 256 for as long as the bundle shipped 256, and stayed 256 after #933 / build 42 took
    /// the bundle to 512 — so every regeneration had to remember `DIMS=512`, and one that forgot
    /// repacked the bundle at half its shipping width and took every consumer to
    /// `.provenanceMismatch` (the width is in the provenance digest). `EXPECT_DIGEST` catches that
    /// when the operator sets it; this removes the trap when they do not.
    /// `SemanticVectorsArtifactTests.defaultWidthIsTheShippedWidth` holds it to the
    /// committed index's `provenance.shippingDims`, so the next width change moves both or fails.
    public static let defaultShippingDims = 512

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
        /// `EXPECT_DIGEST` was set and the provenance this pack would carry is not it.
        case unexpectedDigest(expected: String, actual: String)
        /// `EXPECT_DIGEST` was set to something that cannot be a SHA-256 hex digest.
        case malformedExpectedDigest(String)

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
            case .unexpectedDigest(let expected, let actual):
                return "provenance digest \(actual.prefix(12))… but EXPECT_DIGEST is "
                    + "\(expected.prefix(12))… — refusing to write. A changed digest is a changed "
                    + "vector family: every installed device would refuse its downloaded shards "
                    + "and re-fetch all of them (162 MB). If the store's contract really changed "
                    + "(model, GGUF, prefix, chunking, DIMS), unset EXPECT_DIGEST deliberately; if it "
                    + "did not, the store or the environment is wrong — see release plan §4.2"
            case .malformedExpectedDigest(let value):
                return "EXPECT_DIGEST must be a 64-character hex SHA-256, got "
                    + "\(value.isEmpty ? "an empty string" : "\"\(value)\"")"
            case .unusableDims(let detail):
                return "DIMS \(detail). Measured models and widths: "
                    + funnelMeasurements.keys.sorted().map { model in
                        "\(model.prefix(12))… at "
                            + (funnelMeasurements[model] ?? [:]).keys.sorted()
                                .map(String.init).joined(separator: " and ")
                    }.joined(separator: "; ")
                    + " — a width with no corpus-scale measurement for the store's model would "
                    + "ship a recall number borrowed from a different artifact"
            }
        }
    }

    /// Runs the packer, honouring the environment overrides documented in `CLAUDE.md`.
    ///
    /// The process's own environment and tagger verdict, handed to
    /// ``run(environment:languageAnalysis:)``, which is the whole run.
    public static func run() throws {
        try run(environment: ProcessInfo.processInfo.environment,
                languageAnalysis: { NaturalLanguageReadiness.health })
    }

    /// The run, with its two process-wide inputs supplied by the caller so a test can drive it.
    ///
    /// ## Nothing is written until every refusal that can be made first has been made
    /// In order: the model pin, the shipping width, `EXPECT_DIGEST`, the manifest, and — when
    /// `LAYOUT_DIR/layout.bin` exists, so a map pass will follow — everything that pass can refuse
    /// on: the manifest's coverage dates (`loadVolumeEras`), which the map's era histograms read
    /// and which decode a stricter shape than the volume list does; then the store's volume heads;
    /// then `SemanticMapPacker.preflight` (#1439). Only then are the output directories created.
    /// Before #1439 the map pass made its refusals after the vector artifacts were on disk, which
    /// left new vectors beside the previous map. `RunWriteOrderTests` pins the order in this body:
    /// both calls come before every write, and after the first write the map block makes no call
    /// that can throw other than `SemanticMapPacker.pack` and its own two writes.
    ///
    /// - Parameters:
    ///   - env: The environment overrides (`STORE`, `MANIFEST`, `OUTPUT_DIR`, `SHARDS_DIR`, `DIMS`,
    ///     `EXPECT_DIGEST`, `LAYOUT_DIR`, `LEXICONS`, `STOPWORDS`, `GENERATED_DATE`).
    ///   - languageAnalysis: This process's tagger verdict. A closure, because the vector pack
    ///     never reads the tagger: it is asked only when there is a layout to label, so a run with
    ///     no `layout.bin` does not wait on the tagger's warm-up.
    static func run(
        environment env: [String: String],
        languageAnalysis: () -> NaturalLanguageHealth
    ) throws {
        let storeURL = URL(
            fileURLWithPath: (env["STORE"] as NSString?)?.expandingTildeInPath
                // The shipped family's store: EmbeddingGemma 2's since B4. The 300m's is
                // `~/frus-semantic-raw`; `EXPECT_DIGEST` refuses a pack of the wrong one.
                ?? ("~/frus-semantic-raw-embeddinggemma-2" as NSString).expandingTildeInPath)
        let manifestPath = env["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json"
        let outputDir = URL(fileURLWithPath: env["OUTPUT_DIR"] ?? "FRUSExplorer/Resources")
        let shardsDir = URL(
            fileURLWithPath: env["SHARDS_DIR"] ?? "Planning/semantic-vectors/shards")
        let generated = generatorDateStamp(override: env["GENERATED_DATE"])

        let runManifest = try SemanticRawStore.runManifest(at: storeURL)
        guard runManifest.modelFileSHA256.count == 64 else {
            throw RunError.unpinnedModel(runManifest.modelFileSHA256)
        }
        // Validated before anything is read or written. Left unchecked, a plausible typo reached a
        // `precondition` deep in the quantizer — and preconditions keep their teeth but lose their
        // messages in a release build, so `DIMS=7` exited 133 with no diagnostic at all, while
        // `DIMS=abc` silently packed at the default width as though the variable had never been set.
        // After the pin since B4, because the measured widths are the model's.
        let shippingDims = try resolveShippingDims(
            env["DIMS"], native: runManifest.dim, modelFileSHA256: runManifest.modelFileSHA256)
        guard let measurement = funnelMeasurements[runManifest.modelFileSHA256]?[shippingDims] else {
            throw RunError.unusableDims("(\(shippingDims)) has no corpus-scale measurement")
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
                + "MSB-first, zero packs as 1",
            // Read from the shared declaration the app and the parity-fixture generator both use,
            // so the artifact cannot describe a prompt the encoder does not send. Published,
            // never digested — see `Provenance.queryPrefix`.
            queryPrefix: SemanticQueryPrompt.queryPrefix)

        // R-2's packer-side guard. Checked BEFORE any directory is created or byte written, so a
        // refused run leaves the previous artifacts exactly as they were.
        try verifyExpectedDigest(env["EXPECT_DIGEST"], actual: provenance.digestHex)

        let volumes = try loadManifestVolumes(manifestPath)
        guard !volumes.isEmpty else { throw RunError.emptyManifest(manifestPath) }
        generatorLog("manifest: \(volumes.count) volumes | store: \(storeURL.path)")
        generatorLog("model \(provenance.model) | \(provenance.nativeDims) -> \(shippingDims) dims "
            + "| digest \(provenance.digestHex.prefix(12))…")

        // Tier 0, the map, is a SEPARATE pass and skippable: its layout comes from a 15-minute
        // Python stage, and a packer that refused to emit vectors because no layout existed would
        // hold the shipping feature hostage to an experimental one. But when a layout IS there the
        // map pass will run, after the vectors are written — so everything it can refuse on is
        // checked here, while a refusal still leaves the previous artifacts exactly as they were
        // (#1439). The document count it checks is the sum of the store's volume heads, which is
        // what the vector pass is about to pool. The manifest's coverage dates are read here too:
        // `loadVolumeEras` decodes `dateRange`, which `loadManifestVolumes` above never touches, so
        // read after the vectors a one-sided `dateRange` refused there (review of #1439).
        let layoutDir = URL(fileURLWithPath: env["LAYOUT_DIR"] ?? "Planning/semantic-map")
        let lexiconsPath = env["LEXICONS"] ?? "FRUSExplorer/Resources/word-cloud-lexicons.json"
        let stopwordsPath = env["STOPWORDS"] ?? "FRUSExplorer/Resources/word-cloud-stopwords.json"
        let packsMap = FileManager.default.fileExists(
            atPath: layoutDir.appendingPathComponent("layout.bin").path)
        var eras: [String: String] = [:]
        if packsMap {
            eras = try loadVolumeEras(manifestPath)
            var documentsInStore = 0
            for volume in volumes {
                guard let head = SemanticRawStore.head(for: volume.id, at: storeURL) else {
                    throw RunError.volumeMissingFromStore(volume.id)
                }
                documentsInStore += head.docs
            }
            try SemanticMapPacker.preflight(
                layoutDir: layoutDir, expectedDocumentCount: documentsInStore,
                lexiconsPath: lexiconsPath, stopwordsPath: stopwordsPath,
                health: languageAnalysis())
        }

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
                measuredRecallAt10: measurement.recallAt10,
                measuredBy: measurement.measuredBy,
                scoreCalibration: scoreCalibrations[runManifest.modelFileSHA256]))

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
        // The shard manifest is BUNDLED, not left beside the shards: the device needs it to verify
        // what it downloads (a truncated shard fails the header's size check, but a flipped byte in
        // the payload does not), and to know a shard exists at all before asking for it. It is ~60 KB
        // for 552 rows, which is the cheapest integrity check in the program.
        let shardData = try encoder.encode(shardManifest)
        try shardData.write(
            to: outputDir.appendingPathComponent("semantic-shards-manifest.json"), options: .atomic)

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

        // Tier 0, the map. Whether it runs was decided before the first write, where its refusals
        // were made and its eras read (`packsMap`, above).
        if packsMap {
            let packed = try SemanticMapPacker.pack(
                layoutDir: layoutDir,
                index: SemanticVectorIndex(file: index),
                storeURL: storeURL,
                eraForVolume: { eras[$0] ?? "unknown" },
                lexiconsPath: lexiconsPath,
                stopwordsPath: stopwordsPath,
                generated: generated)
            try packed.binary.write(
                to: outputDir.appendingPathComponent("semantic-map.bin"), options: .atomic)
            try encoder.encode(packed.meta).write(
                to: outputDir.appendingPathComponent("semantic-map-index.json"), options: .atomic)
            generatorLog("  semantic-map.bin              \(packed.binary.count) bytes | "
                + "\(packed.meta.documentCount) placements, \(packed.meta.clusters.count) clusters, "
                + "\(packed.meta.layout.unclusteredCount) unclustered")
        } else {
            generatorLog("no layout.bin under \(layoutDir.path) — Tier 0 (map) skipped; "
                + "run tools/semantic-map/build_layout.py to produce one")
        }

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
    ///   - modelFileSHA256: The store's GGUF digest, whose measured widths are the ones allowed.
    /// - Returns: The validated width, defaulting to ``defaultShippingDims``.
    /// - Throws: `RunError.unusableDims` for anything unparseable, unrepresentable, wider than the
    ///   store, not byte-aligned, or without a corpus-scale measurement for the store's model.
    static func resolveShippingDims(
        _ raw: String?, native: Int, modelFileSHA256: String
    ) throws -> Int {
        // The default goes through every check below, like a width the operator typed: at 512 it
        // is no longer narrower than every store, and an unchecked default on a 256- or 384-wide
        // one would reach the quantizer's precondition instead of this function's message.
        let dims: Int
        if let raw, !raw.isEmpty {
            guard let parsed = Int(raw) else {
                throw RunError.unusableDims("is not a number: \(raw)")
            }
            dims = parsed
        } else {
            dims = defaultShippingDims
        }
        guard dims > 0 else { throw RunError.unusableDims("must be positive, got \(dims)") }
        guard dims <= native else {
            throw RunError.unusableDims("(\(dims)) exceeds the store's native width \(native)")
        }
        guard dims % 8 == 0 else {
            throw RunError.unusableDims("(\(dims)) must be a multiple of 8 to pack sign bits")
        }
        guard funnelMeasurements[modelFileSHA256]?[dims] != nil else {
            throw RunError.unusableDims("(\(dims)) has no corpus-scale measurement for the "
                + "store's model, \(modelFileSHA256.prefix(12))…")
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

    /// Coverage era per volume, banded the way the app bands everything else.
    ///
    /// The raw value of the app's `CoverageEra`, not a scheme invented here, so a cluster's era
    /// histogram is comparable with every other era-split surface.
    ///
    /// Read before the run's first write (review of #1439): it decodes `dateRange` as two strings,
    /// which ``loadManifestVolumes(_:)`` never reads, so an entry with a one-sided or non-string
    /// `dateRange` passes the volume list and throws here.
    ///
    /// - Parameter path: Path to `manifest.json`.
    /// - Returns: Volume id to era raw value.
    /// - Throws: `GeneratorError.missingFile`, or the decoder's error for a `dateRange` that is
    ///   present and is not `{earliest: String, latest: String}`.
    private static func loadVolumeEras(_ path: String) throws -> [String: String] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw GeneratorError.missingFile(path)
        }
        struct Entry: Decodable {
            struct Range: Decodable { let earliest: String; let latest: String }
            let volumeId: String
            let dateRange: Range?
        }
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        var eras: [String: String] = [:]
        for entry in entries {
            guard let range = entry.dateRange,
                  let earliest = Int(range.earliest.prefix(4)),
                  let latest = Int(range.latest.prefix(4))
            else { eras[entry.volumeId] = "unknown"; continue }
            switch (earliest + latest) / 2 {
            case ..<1900:     eras[entry.volumeId] = "0"
            case 1900...1944: eras[entry.volumeId] = "1"
            case 1945...1990: eras[entry.volumeId] = "2"
            default:          eras[entry.volumeId] = "3"
            }
        }
        return eras
    }

    /// Reads the app manifest's volume list, preserving its order — which is the artifact's row
    /// order and therefore part of the contract.
    ///
    /// - Parameter path: Path to `manifest.json`.
    /// - Returns: The volumes in manifest order.
    /// Refuses to pack under a provenance digest other than the one the operator expected.
    ///
    /// ## Why this exists (release plan §4.2, R-2)
    /// The family digest is computed from the store's `run-manifest.json`, which the harvester
    /// rewrites from its *current* invocation at the end of every run. A resumed harvest that
    /// forgot `PREFIX` therefore packs cleanly under a **different** digest, and every installed
    /// device then refuses its downloaded shards and re-fetches all of them — 162 MB — to get
    /// vectors that mix two prompts. The harvester now refuses that resume at its end; this is
    /// the independent check at ours, and it also catches a store that was transferred from the
    /// wrong run, which the harvester cannot see.
    ///
    /// `nil` (unset) is a pass: the digest is still logged, and a first pack of a new family has
    /// no prior digest to expect. Empty or non-hex is an error rather than a pass, because an
    /// operator who set the variable and mistyped it must not be told the pack was verified.
    ///
    /// - Parameters:
    ///   - expected: the `EXPECT_DIGEST` environment value, or `nil` when unset.
    ///   - actual: the digest this pack would carry.
    static func verifyExpectedDigest(_ expected: String?, actual: String) throws {
        guard let expected else { return }
        let normalised = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalised.count == 64,
              normalised.allSatisfy({ $0.isHexDigit }) else {
            throw RunError.malformedExpectedDigest(expected)
        }
        guard normalised == actual.lowercased() else {
            throw RunError.unexpectedDigest(expected: normalised, actual: actual)
        }
    }

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
