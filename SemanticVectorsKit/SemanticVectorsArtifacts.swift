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

/// The artifact shapes the packer emits, and the binary layouts that go with them.
///
/// Three artifacts across two distribution tiers (`Planning/Vector-Embeddings-Semantic-Design.md`
/// §4), plus the provenance pin that ties them to one another and to the harvest:
///
/// | artifact | tier | where | size |
/// |---|---|---|---|
/// | `semantic-vectors-index.json` | keys + centroids metadata | bundled | ~73 KB |
/// | `semantic-vectors-binary.bin` | Tier 1 (Hamming candidates, corpus-wide) | bundled | ~9.8 MiB |
/// | `<volume>.vec` | Tier 2 (int8 cosine, exact) | downloaded per volume | ~150 KB each |
///
/// **The version-skew rule is the family rule** (design §4.3, promoted from
/// `BundledKeynessBaseline.configurationMismatch`): every artifact carries the same provenance
/// digest, and no consumer may mix two. A Tier-2 shard from generation *N* must never rescore Tier-1
/// candidates from generation *N+1* — refuse, re-fetch, or degrade to the tier that matches, but
/// never blend. The digest is what makes that check one comparison instead of a field-by-field
/// argument.
public enum SemanticVectorsArtifacts {

    // MARK: - Provenance

    /// Everything that has to match for two artifacts to be scored against each other.
    ///
    /// Deliberately narrow: it names what changes the *numbers*, not what changes the run. The
    /// harvest date and machine live in the index for the record but are not part of the digest, so
    /// re-packing the same store on another machine produces interchangeable artifacts — while
    /// changing the model, width, chunking, prefix, or pooling rule does not.
    public struct Provenance: Codable, Equatable, Sendable {
        /// LM Studio model id the corpus was embedded under.
        public let model: String
        /// SHA-256 of the GGUF weights.
        public let modelFileSHA256: String
        /// Native embedding width.
        public let nativeDims: Int
        /// Shipping width after Matryoshka truncation.
        public let shippingDims: Int
        /// Characters per chunk window.
        public let chunkChars: Int
        /// Characters of overlap between windows.
        public let overlapChars: Int
        /// The document-side prompt, trailing space included.
        public let prefix: String
        /// The pooling rule, spelled out.
        public let pooling: String
        /// The quantization rules, spelled out.
        public let quantization: String

        /// Creates a provenance pin.
        /// - Parameters:
        ///   - model: LM Studio model id.
        ///   - modelFileSHA256: SHA-256 of the GGUF weights.
        ///   - nativeDims: Native embedding width.
        ///   - shippingDims: Width after truncation.
        ///   - chunkChars: Chunk window size.
        ///   - overlapChars: Window overlap.
        ///   - prefix: Document-side prompt.
        ///   - pooling: The pooling rule in words.
        ///   - quantization: The quantization rules in words.
        public init(
            model: String, modelFileSHA256: String, nativeDims: Int, shippingDims: Int,
            chunkChars: Int, overlapChars: Int, prefix: String, pooling: String,
            quantization: String
        ) {
            self.model = model
            self.modelFileSHA256 = modelFileSHA256
            self.nativeDims = nativeDims
            self.shippingDims = shippingDims
            self.chunkChars = chunkChars
            self.overlapChars = overlapChars
            self.prefix = prefix
            self.pooling = pooling
            self.quantization = quantization
        }

        /// The 32-byte digest every artifact header carries.
        ///
        /// Built from a canonical, order-fixed string rather than from encoded JSON, so a change in
        /// the encoder's key ordering or escaping can never move the digest and invalidate a
        /// perfectly good pair of artifacts.
        public var digest: Data {
            let canonical = [
                model, modelFileSHA256, String(nativeDims), String(shippingDims),
                String(chunkChars), String(overlapChars), prefix, pooling, quantization,
            ].joined(separator: "\u{1F}")
            return Data(SHA256.hash(data: Data(canonical.utf8)))
        }

        /// The digest as lower-case hex, for the JSON side of the artifacts.
        public var digestHex: String {
            digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    // MARK: - Index

    /// One volume's row block in the corpus matrix.
    public struct VolumeEntry: Codable, Sendable {
        /// Manifest `volumeId`.
        public let volumeID: String
        /// Row index of this volume's first document in the corpus-wide binary tier.
        public let rowOffset: Int
        /// Documents in this volume.
        public let documentCount: Int
        /// Run-length-encoded document ids, in row order.
        public let idSegments: [DocumentIDSegments.Segment]

        /// Creates a volume entry.
        /// - Parameters:
        ///   - volumeID: Manifest `volumeId`.
        ///   - rowOffset: Corpus-wide row index of the volume's first document.
        ///   - documentCount: Documents in the volume.
        ///   - idSegments: The volume's run-length-encoded ids.
        public init(
            volumeID: String, rowOffset: Int, documentCount: Int,
            idSegments: [DocumentIDSegments.Segment]
        ) {
            self.volumeID = volumeID
            self.rowOffset = rowOffset
            self.documentCount = documentCount
            self.idSegments = idSegments
        }

        private enum CodingKeys: String, CodingKey {
            case volumeID = "v"
            case rowOffset = "r"
            case documentCount = "n"
            case idSegments = "seg"
        }
    }

    /// The bundled index: provenance, the volume table, and the centroid roster.
    public struct Index: Codable, Sendable {
        /// Artifact schema version.
        public let schema: Int
        /// `yyyy-MM-dd` generation stamp.
        public let generated: String
        /// The pin every artifact in the set shares.
        public let provenance: Provenance
        /// Hex form of the provenance digest, matching the binary headers.
        public let provenanceDigest: String
        /// When the harvest that produced the vectors finished — recorded, not part of the digest.
        public let harvestGenerated: String
        /// SHA-256 of the harvester script that ran — recorded, not part of the digest.
        public let harvestScriptSHA256: String
        /// Total documents across all volumes.
        public let documentCount: Int
        /// Volumes in manifest order; row blocks are contiguous and in this order.
        public let volumes: [VolumeEntry]
        /// Subseries names in the centroid block's order, after the per-volume centroids.
        public let subseries: [String]
        /// Retrieval defaults the measured gates justify, carried so a consumer need not re-derive
        /// them from a planning document.
        public let retrieval: Retrieval

        /// Retrieval parameters this artifact set was measured under.
        public struct Retrieval: Codable, Sendable {
            /// Binary-tier candidate pool feeding the int8 rerank.
            public let rerankPool: Int
            /// Measured recall@10 of the shipping funnel against exact float-768 neighbours.
            public let measuredRecallAt10: Double
            /// Where those numbers come from.
            public let measuredBy: String

            /// Creates the retrieval block.
            /// - Parameters:
            ///   - rerankPool: Candidates the Hamming stage hands the int8 rerank.
            ///   - measuredRecallAt10: Measured recall@10 for that configuration.
            ///   - measuredBy: Citation for the measurement.
            public init(rerankPool: Int, measuredRecallAt10: Double, measuredBy: String) {
                self.rerankPool = rerankPool
                self.measuredRecallAt10 = measuredRecallAt10
                self.measuredBy = measuredBy
            }
        }

        /// Creates the index.
        /// - Parameters:
        ///   - schema: Schema version.
        ///   - generated: Generation stamp.
        ///   - provenance: The shared pin.
        ///   - harvestGenerated: Harvest completion stamp.
        ///   - harvestScriptSHA256: Harvester script digest.
        ///   - documentCount: Total documents.
        ///   - volumes: Volume table in manifest order.
        ///   - subseries: Subseries names in centroid order.
        ///   - retrieval: Measured retrieval defaults.
        public init(
            schema: Int, generated: String, provenance: Provenance, harvestGenerated: String,
            harvestScriptSHA256: String, documentCount: Int, volumes: [VolumeEntry],
            subseries: [String], retrieval: Retrieval
        ) {
            self.schema = schema
            self.generated = generated
            self.provenance = provenance
            self.provenanceDigest = provenance.digestHex
            self.harvestGenerated = harvestGenerated
            self.harvestScriptSHA256 = harvestScriptSHA256
            self.documentCount = documentCount
            self.volumes = volumes
            self.subseries = subseries
            self.retrieval = retrieval
        }
    }

    // MARK: - Binary layouts

    /// Bytes every binary artifact reserves for its header, so the payload starts page-friendly and
    /// a later field can be added without moving the data.
    public static let headerBytes = 64

    /// Magic for the bundled corpus-wide binary tier.
    public static let corpusMagic = "FRSV"
    /// Magic for a per-volume int8 shard.
    public static let shardMagic = "FRSS"
    /// Binary layout version, bumped when the byte layout changes shape.
    public static let binaryVersion: UInt32 = 1

    /// Builds the Tier-1 artifact: corpus-wide sign bits, then the centroid roster.
    ///
    /// Layout, all little-endian:
    ///
    /// ```
    /// 0   magic "FRSV"                     4 B
    /// 4   version                          4 B  UInt32
    /// 8   shipping dims                    4 B  UInt32
    /// 12  document count                   4 B  UInt32
    /// 16  centroid count                   4 B  UInt32
    /// 20  provenance digest               32 B
    /// 52  zero padding                    12 B
    /// 64  sign bits           docs × dims/8 B
    /// ..  centroids       centroids × (dims + 4) B   int8 codes then Float32 scale
    /// ```
    ///
    /// Centroids ride in this file rather than the index because they are vectors — 171 KB of them
    /// — and base64 in a JSON the app parses at launch would cost more to decode than the whole
    /// Hamming scan they support.
    ///
    /// - Parameters:
    ///   - signBits: Per-document packed sign bits, in corpus row order.
    ///   - centroids: Volume centroids followed by subseries centroids, each as int8 codes + scale.
    ///   - dims: Shipping width.
    ///   - provenance: The shared pin.
    /// - Returns: The complete file bytes.
    public static func corpusBinary(
        signBits: [[UInt8]],
        centroids: [(codes: [Int8], scale: Float)],
        dims: Int,
        provenance: Provenance
    ) -> Data {
        var data = Data()
        data.reserveCapacity(
            headerBytes + signBits.count * (dims / 8) + centroids.count * (dims + 4))
        data.append(contentsOf: Array(corpusMagic.utf8))
        appendLittleEndian(&data, binaryVersion)
        appendLittleEndian(&data, UInt32(dims))
        appendLittleEndian(&data, UInt32(signBits.count))
        appendLittleEndian(&data, UInt32(centroids.count))
        data.append(provenance.digest)
        data.append(Data(repeating: 0, count: headerBytes - data.count))
        for bits in signBits { data.append(contentsOf: bits) }
        for centroid in centroids {
            data.append(contentsOf: centroid.codes.map { UInt8(bitPattern: $0) })
            appendLittleEndian(&data, centroid.scale.bitPattern)
        }
        return data
    }

    /// Builds one volume's Tier-2 shard.
    ///
    /// Layout, all little-endian:
    ///
    /// ```
    /// 0   magic "FRSS"                     4 B
    /// 4   version                          4 B  UInt32
    /// 8   shipping dims                    4 B  UInt32
    /// 12  document count                   4 B  UInt32
    /// 16  provenance digest               32 B
    /// 48  zero padding                    16 B
    /// 64  int8 codes            docs × dims B
    /// ..  scales                docs × 4    B  Float32
    /// ```
    ///
    /// Two deliberate departures from the design's §4.3 sketch, both toward fewer sources of truth:
    ///
    /// * **Scales are `Float32`, not `Float16`.** The design's own size table budgeted 4 bytes; the
    ///   prose said half. Float32 costs 629 KB across the whole corpus tier and removes a rounding
    ///   step between the score a device computes and the score the gates measured.
    /// * **No id rows.** The design put per-volume id exceptions in the shard; the bundled index
    ///   already carries every volume's ids in 1,605 run segments (48 KB encoded), and a shard that
    ///   repeated them would be a second place for identity to be wrong.
    ///
    /// - Parameters:
    ///   - codes: Per-document int8 codes in volume row order.
    ///   - scales: Per-document scales, aligned with `codes`.
    ///   - dims: Shipping width.
    ///   - provenance: The shared pin.
    /// - Returns: The complete shard bytes.
    public static func volumeShard(
        codes: [[Int8]], scales: [Float], dims: Int, provenance: Provenance
    ) -> Data {
        precondition(codes.count == scales.count, "shard codes and scales must align")
        var data = Data()
        data.reserveCapacity(headerBytes + codes.count * (dims + 4))
        data.append(contentsOf: Array(shardMagic.utf8))
        appendLittleEndian(&data, binaryVersion)
        appendLittleEndian(&data, UInt32(dims))
        appendLittleEndian(&data, UInt32(codes.count))
        data.append(provenance.digest)
        data.append(Data(repeating: 0, count: headerBytes - data.count))
        for row in codes { data.append(contentsOf: row.map { UInt8(bitPattern: $0) }) }
        for scale in scales { appendLittleEndian(&data, scale.bitPattern) }
        return data
    }

    /// Appends a 32-bit value little-endian.
    /// - Parameters:
    ///   - data: The buffer to append to.
    ///   - value: The value to append.
    private static func appendLittleEndian(_ data: inout Data, _ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
