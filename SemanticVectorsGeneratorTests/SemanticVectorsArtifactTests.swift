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
import CryptoKit
import Foundation
@testable import SemanticVectorsGeneratorCore

/// Artifact tests over the **committed** semantic-vector artifacts.
///
/// These need no raw store — that is the point. The 2 GB harvest lives on one machine and the
/// artifacts ship to every machine, so the properties a consumer depends on have to be checkable
/// from the bytes in the repository alone: that the index and the binary agree about how many
/// documents exist and where each volume's rows start, that both name the same provenance, and that
/// every document id round-trips out of its run-length encoding.
///
/// The identity checks are the load-bearing ones. A vector artifact whose keys drift does not fail
/// — it silently shows the wrong documents, at plausible-looking scores, forever.
///
/// Version history:
///   1.0 — V-1: initial implementation
@Suite("SemanticVectors — committed artifacts")
struct SemanticVectorsArtifactTests {

    /// Repository root, derived from this file's own path so the suite runs from any working
    /// directory.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// The bundled resources directory.
    static let resources = repoRoot.appendingPathComponent("FRUSExplorer/Resources")

    /// The decoded index.
    static let index: SemanticVectorsArtifacts.Index = {
        let url = resources.appendingPathComponent("semantic-vectors-index.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(
                  SemanticVectorsArtifacts.Index.self, from: data)
        else { fatalError("semantic-vectors-index.json missing or undecodable at \(url.path)") }
        return decoded
    }()

    /// The raw bytes of the corpus binary.
    static let binary: Data = {
        let url = resources.appendingPathComponent("semantic-vectors-binary.bin")
        guard let data = try? Data(contentsOf: url) else {
            fatalError("semantic-vectors-binary.bin missing at \(url.path)")
        }
        return data
    }()

    /// Reads a little-endian `UInt32` from the binary header.
    /// - Parameter offset: Byte offset.
    /// - Returns: The decoded value.
    static func headerValue(at offset: Int) -> UInt32 {
        binary.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
            .littleEndian
    }

    /// The app manifest's volume ids, in manifest order — the artifact's row order.
    static let manifestVolumeIDs: [String] = {
        struct Entry: Decodable { let volumeId: String }
        let url = resources.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { fatalError("manifest.json missing or undecodable at \(url.path)") }
        return entries.map(\.volumeId)
    }()

    // MARK: - Shape

    @Test("Index and binary agree on schema, width and document count")
    func headerAgreesWithIndex() {
        #expect(Self.index.schema == SemanticVectorsRunner.schema)
        #expect(String(data: Self.binary.prefix(4), encoding: .utf8)
            == SemanticVectorsArtifacts.corpusMagic)
        #expect(Self.headerValue(at: 4) == SemanticVectorsArtifacts.binaryVersion)
        #expect(Int(Self.headerValue(at: 8)) == Self.index.provenance.shippingDims)
        #expect(Int(Self.headerValue(at: 12)) == Self.index.documentCount)
    }

    @Test("Binary is exactly header + sign bits + centroids, with nothing unaccounted for")
    func binarySizeIsExact() {
        let dims = Self.index.provenance.shippingDims
        let centroids = Int(Self.headerValue(at: 16))
        let expected = SemanticVectorsArtifacts.headerBytes
            + Self.index.documentCount * (dims / 8)
            + centroids * (dims + 4)
        #expect(Self.binary.count == expected)
    }

    @Test("Centroid roster is one per volume plus one per subseries")
    func centroidCount() {
        #expect(Int(Self.headerValue(at: 16))
            == Self.index.volumes.count + Self.index.subseries.count)
    }

    // MARK: - Provenance

    /// The version-skew rule needs one comparison to be decisive; this asserts the digest in the
    /// binary header is the digest of the provenance the index states, so the comparison means what
    /// a consumer will assume it means.
    @Test("The binary header carries the digest of the index's own provenance")
    func digestsAgree() {
        let headerDigest = Self.binary[20..<52]
        #expect(headerDigest == Self.index.provenance.digest)
        #expect(Self.index.provenanceDigest == Self.index.provenance.digestHex)
    }

    @Test("Provenance pins a real model, its weights digest, and the harvested contract")
    func provenanceIsComplete() {
        let provenance = Self.index.provenance
        #expect(!provenance.model.isEmpty)
        #expect(provenance.modelFileSHA256.count == 64)
        #expect(provenance.modelFileSHA256.allSatisfy { $0.isHexDigit })
        #expect(provenance.nativeDims == 768)
        #expect(provenance.shippingDims == 256)
        #expect(provenance.chunkChars == 3200)
        #expect(provenance.overlapChars == 480)
        // The trailing space is part of EmbeddingGemma's document prompt and part of the contract.
        #expect(provenance.prefix == "title: none | text: ")
        #expect(provenance.pooling.contains("char-length-weighted"))
        #expect(provenance.quantization.contains("127"))
        #expect(!Self.index.harvestScriptSHA256.isEmpty)
        #expect(!Self.index.harvestGenerated.isEmpty)
    }

    /// The measured retrieval defaults travel with the artifact so a device does not have to read a
    /// planning document to know the pool the recall number describes.
    @Test("Retrieval defaults carry the measured rerank pool")
    func retrievalDefaults() {
        #expect(Self.index.retrieval.rerankPool == SemanticVectorsRunner.rerankPool)
        #expect(Self.index.retrieval.rerankPool >= 800)
        #expect(Self.index.retrieval.measuredBy.contains("Phase3-Store-Assessment"))
        // Pinned to the value for THIS artifact's width, not to a floor. A floor (`> 0.7`) is
        // satisfied by 256's number in a 512-dim artifact, which is exactly the mismatch the
        // width-keyed table exists to prevent.
        #expect(Self.index.retrieval.measuredRecallAt10
            == SemanticVectorsRunner.measuredRecallAt10[Self.index.provenance.shippingDims])
        #expect(Self.index.retrieval.measuredBy.contains("int8-\(Self.index.provenance.shippingDims)"))
    }

    // MARK: - Row keying

    @Test("Volumes are in manifest order and cover the manifest exactly")
    func volumeOrderMatchesManifest() {
        #expect(Self.index.volumes.map(\.volumeID) == Self.manifestVolumeIDs)
    }

    @Test("Row blocks are contiguous, start at zero, and sum to the document count")
    func rowBlocksTile() {
        var expectedOffset = 0
        for volume in Self.index.volumes {
            #expect(volume.rowOffset == expectedOffset)
            #expect(volume.documentCount > 0)
            expectedOffset += volume.documentCount
        }
        #expect(expectedOffset == Self.index.documentCount)
    }

    /// The check that would have caught the design's implicit-keying rule: every id is stored and
    /// recoverable, and no two rows in a volume claim the same document.
    @Test("Every volume's id segments decode to exactly its document count, all distinct")
    func idsDecodeAndAreUnique() throws {
        var totalSegments = 0
        for volume in Self.index.volumes {
            let ids = try #require(
                DocumentIDSegments.decode(volume.idSegments),
                "segments for \(volume.volumeID) did not decode")
            #expect(ids.count == volume.documentCount, "\(volume.volumeID) id count")
            #expect(Set(ids).count == ids.count, "\(volume.volumeID) has duplicate ids")
            #expect(!ids.contains { $0.isEmpty })
            totalSegments += volume.idSegments.count
        }
        // The whole reason identity is affordable to store: measured 1,605 segments corpus-wide.
        #expect(totalSegments < Self.index.documentCount / 50)
    }

    @Test("Subseries names are sorted and unique, matching the centroid block's order")
    func subseriesRosterIsStable() {
        #expect(Self.index.subseries == Self.index.subseries.sorted())
        #expect(Set(Self.index.subseries).count == Self.index.subseries.count)
    }

    // MARK: - Shard manifest

    /// The download tier's rows must line up with the bundled tier, or a device could fetch a shard
    /// for a volume whose rows live somewhere else entirely.
    @Test("Shard manifest matches the index's volumes, order, and provenance")
    func shardManifestAgreesWithIndex() throws {
        let url = Self.repoRoot
            .appendingPathComponent("Planning/semantic-vectors/shards-manifest.json")
        let data = try #require(try? Data(contentsOf: url), "shards-manifest.json missing")
        let manifest = try JSONDecoder().decode(
            SemanticVectorsRunner.ShardManifest.self, from: data)

        #expect(manifest.provenanceDigest == Self.index.provenanceDigest)
        #expect(manifest.shippingDims == Self.index.provenance.shippingDims)
        #expect(manifest.shards.map(\.volumeID) == Self.index.volumes.map(\.volumeID))

        let dims = Self.index.provenance.shippingDims
        for (shard, volume) in zip(manifest.shards, Self.index.volumes) {
            #expect(shard.bytes == SemanticVectorsArtifacts.headerBytes
                + volume.documentCount * (dims + 4), "\(shard.volumeID) shard size")
            #expect(shard.sha256.count == 64)
            #expect(shard.sha256.allSatisfy { $0.isHexDigit })
        }
    }

    /// The manifest's digests are the download channel's only integrity claim, and until this test
    /// existed nothing in the repository ever opened a `.vec` to check one — the shard rows were
    /// verified to be 64 hex characters and nothing more.
    ///
    /// Shards are gitignored (79 MB), so on a fresh clone there is nothing to check and the test
    /// says so rather than failing. That is the honest shape: it verifies what is present, and a
    /// machine that has just run the generator gets the full check.
    @Test("Where shards exist, their bytes match the manifest's digests and headers")
    func shardBytesMatchTheirManifestRows() throws {
        let url = Self.repoRoot
            .appendingPathComponent("Planning/semantic-vectors/shards-manifest.json")
        let manifest = try JSONDecoder().decode(
            SemanticVectorsRunner.ShardManifest.self, from: try #require(try? Data(contentsOf: url)))
        let shardsDir = Self.repoRoot.appendingPathComponent("Planning/semantic-vectors/shards")

        var checked = 0
        for row in manifest.shards {
            let shardURL = shardsDir.appendingPathComponent("\(row.volumeID).vec")
            guard let bytes = try? Data(contentsOf: shardURL) else { continue }
            checked += 1
            #expect(bytes.count == row.bytes, "\(row.volumeID) size")
            #expect(Data(SHA256.hash(data: bytes)).map { String(format: "%02x", $0) }.joined()
                == row.sha256, "\(row.volumeID) digest")
            #expect(String(data: bytes.prefix(4), encoding: .utf8)
                == SemanticVectorsArtifacts.shardMagic, "\(row.volumeID) magic")
            // Every shard must carry the same pin as the bundled tier — the version-skew rule.
            #expect(bytes[16..<48] == Self.index.provenance.digest, "\(row.volumeID) provenance")
        }
        if checked == 0 {
            print("[SemanticVectorsArtifactTests] no shards on disk (gitignored) — "
                + "run SemanticVectorsGenerator to check their bytes")
        }
    }

    // MARK: - Corpus facts

    /// Pins the corpus the artifacts were built from. A regeneration that moves these has either
    /// re-harvested or changed the extraction boundary, and either way the recall numbers in
    /// `Phase3-Store-Assessment.md` describe a different corpus than the one shipping.
    @Test("Artifact covers the measured 552-volume, 314,483-document corpus")
    func corpusFactsAreThePinnedOnes() {
        #expect(Self.index.volumes.count == 552)
        #expect(Self.index.documentCount == 314_483)
        #expect(Self.index.subseries.count == 107)
    }
}
