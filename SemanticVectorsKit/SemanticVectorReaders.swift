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

/// Why a semantic answer could not be produced.
///
/// Modelled on `Collocation.Unavailable`, and for its reason: a surface that folds "we have no
/// vectors for this volume" into "there are no similar documents" tells the reader something false
/// about the corpus. Every case here is a different sentence on screen.
public enum SemanticUnavailable: Error, Equatable, Sendable {
    /// The bundled artifacts are absent or undecodable — the feature is off, not empty.
    case noArtifact
    /// The load has not finished. Distinct from every failure: a reader taken mid-load must not
    /// render as "unavailable" permanently.
    case pending
    /// A tier disagrees with the bundled provenance pin and was refused rather than blended.
    case provenanceMismatch(expected: String, found: String)
    /// The artifact carries no vector for this document — chapter divs, front matter and appendix
    /// structure are never embedded, so this is ordinary, not a fault.
    case documentNotVectorised
    /// The anchor's volume has vectors but this device has no Tier-2 shard for the volumes needed to
    /// score exactly. Retrieval can still run on the bundled tier alone.
    case shardMissing(volumeID: String)
    /// The file exists but its bytes are not a shard this build understands.
    case malformedArtifact(String)
}

/// Mmap-backed reader for the bundled corpus tier (`semantic-vectors-binary.bin`).
///
/// The app had no precedent for reading a binary bundle resource — every one of its 31 bundled
/// artifacts is JSON — so the rules this type follows are stated rather than inherited. It maps
/// rather than reads: 10.23 MB of sign bits are touched a few hundred thousand rows at a time by a
/// scan that runs in ~1.4 ms, and paging them in on demand costs less than decoding them ever could.
/// Nothing is copied into Swift arrays; every accessor hands back a pointer into the mapping.
public struct SemanticCorpusVectors: Sendable {

    /// The mapped file. Held so the mapping outlives every accessor.
    private let data: Data
    /// Byte offset of the sign-bit block.
    private let bitsOffset: Int
    /// Byte offset of the centroid block.
    private let centroidsOffset: Int
    /// Bytes per document's sign bits.
    public let bytesPerRow: Int
    /// Documents in the sign-bit block.
    public let documentCount: Int
    /// Centroids following the sign-bit block: volumes in index order, then subseries.
    public let centroidCount: Int
    /// Shipping vector width.
    public let dims: Int

    /// Maps and validates the corpus binary.
    ///
    /// - Parameters:
    ///   - url: The artifact's location.
    ///   - expecting: The provenance the bundled index states; the header digest must match it, or
    ///     the two tiers came from different generations and must not be scored against each other.
    /// - Throws: `SemanticUnavailable` on a missing file, a bad header, or a provenance mismatch.
    public init(contentsOf url: URL, expecting provenance: SemanticVectorsArtifacts.Provenance) throws {
        guard let mapped = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw SemanticUnavailable.noArtifact
        }
        let header = SemanticVectorsArtifacts.headerBytes
        guard mapped.count >= header else {
            throw SemanticUnavailable.malformedArtifact("file shorter than its header")
        }
        guard String(data: mapped.prefix(4), encoding: .utf8) == SemanticVectorsArtifacts.corpusMagic
        else { throw SemanticUnavailable.malformedArtifact("wrong magic") }
        let version = mapped.littleEndianUInt32(at: 4)
        guard version == SemanticVectorsArtifacts.binaryVersion else {
            throw SemanticUnavailable.malformedArtifact("binary layout version \(version)")
        }
        let digest = mapped.subdata(in: 20..<52)
        guard digest == provenance.digest else {
            throw SemanticUnavailable.provenanceMismatch(
                expected: provenance.digestHex,
                found: digest.map { String(format: "%02x", $0) }.joined())
        }
        let dims = Int(mapped.littleEndianUInt32(at: 8))
        let docs = Int(mapped.littleEndianUInt32(at: 12))
        let centroids = Int(mapped.littleEndianUInt32(at: 16))
        guard dims > 0, dims % 8 == 0, docs >= 0, centroids >= 0 else {
            throw SemanticUnavailable.malformedArtifact("implausible header counts")
        }
        let rowBytes = dims / 8
        let expected = header + docs * rowBytes + centroids * (dims + 4)
        guard mapped.count == expected else {
            throw SemanticUnavailable.malformedArtifact(
                "expected \(expected) bytes for \(docs) rows + \(centroids) centroids, "
                + "found \(mapped.count)")
        }
        self.data = mapped
        self.dims = dims
        self.documentCount = docs
        self.centroidCount = centroids
        self.bytesPerRow = rowBytes
        self.bitsOffset = header
        self.centroidsOffset = header + docs * rowBytes
    }

    /// Runs `body` over the raw sign-bit block.
    ///
    /// The block is exposed as a pointer rather than as rows because the scan reads it as
    /// `UInt64` quads; handing out `[UInt8]` per row would allocate 314,483 arrays per query.
    ///
    /// - Parameter body: Receives a pointer to the first row and the row count.
    /// - Returns: Whatever `body` returns.
    public func withSignBits<T>(_ body: (UnsafeRawPointer, Int) throws -> T) rethrows -> T {
        try data.withUnsafeBytes { raw in
            try body(raw.baseAddress!.advanced(by: bitsOffset), documentCount)
        }
    }

    /// The int8 centroid at `position` — volumes in index order first, then subseries.
    ///
    /// - Parameter position: Index into the centroid block.
    /// - Returns: The codes and scale, or `nil` when out of range.
    public func centroid(at position: Int) -> (codes: [Int8], scale: Float)? {
        guard position >= 0, position < centroidCount else { return nil }
        let stride = dims + 4
        let base = centroidsOffset + position * stride
        return data.withUnsafeBytes { raw in
            var codes = [Int8](repeating: 0, count: dims)
            for index in 0..<dims {
                codes[index] = raw.loadUnaligned(fromByteOffset: base + index, as: Int8.self)
            }
            let scale = Float(bitPattern: raw.loadUnaligned(
                fromByteOffset: base + dims, as: UInt32.self).littleEndian)
            return (codes, scale)
        }
    }
}

/// Mmap-backed reader for one volume's Tier-2 shard (`<volume>.vec`).
///
/// A shard is positional: row *k* is the *k*th document of that volume **in the bundled index's
/// order**, not in the order of whatever XML happens to be on disk. That distinction is the whole
/// safety argument — a volume re-published upstream with new documents changes the local XML and the
/// FTS index, and a reader that trusted local ordering would then score the wrong rows. Identity
/// comes from `SemanticVectorIndex` and nowhere else.
public struct SemanticShard: Sendable {

    /// The mapped file.
    private let data: Data
    /// Byte offset of the int8 block.
    private let codesOffset: Int
    /// Byte offset of the scale block.
    private let scalesOffset: Int
    /// Documents in this shard.
    public let documentCount: Int
    /// Shipping vector width.
    public let dims: Int

    /// Maps and validates a shard.
    ///
    /// - Parameters:
    ///   - url: The shard's location.
    ///   - provenance: The bundled pin; a shard from another generation is refused.
    ///   - expectedDocumentCount: The bundled index's count for this volume, or `nil` to skip the
    ///     cross-check. A shard whose length disagrees with the index would silently misalign every
    ///     row after the first discrepancy.
    /// - Throws: `SemanticUnavailable` on any mismatch.
    public init(
        contentsOf url: URL,
        provenance: SemanticVectorsArtifacts.Provenance,
        expectedDocumentCount: Int? = nil
    ) throws {
        guard let mapped = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw SemanticUnavailable.noArtifact
        }
        let header = SemanticVectorsArtifacts.headerBytes
        guard mapped.count >= header else {
            throw SemanticUnavailable.malformedArtifact("shard shorter than its header")
        }
        guard String(data: mapped.prefix(4), encoding: .utf8) == SemanticVectorsArtifacts.shardMagic
        else { throw SemanticUnavailable.malformedArtifact("wrong shard magic") }
        let version = mapped.littleEndianUInt32(at: 4)
        guard version == SemanticVectorsArtifacts.binaryVersion else {
            throw SemanticUnavailable.malformedArtifact("shard layout version \(version)")
        }
        let digest = mapped.subdata(in: 16..<48)
        guard digest == provenance.digest else {
            throw SemanticUnavailable.provenanceMismatch(
                expected: provenance.digestHex,
                found: digest.map { String(format: "%02x", $0) }.joined())
        }
        let dims = Int(mapped.littleEndianUInt32(at: 8))
        let docs = Int(mapped.littleEndianUInt32(at: 12))
        guard dims == provenance.shippingDims else {
            throw SemanticUnavailable.malformedArtifact(
                "shard width \(dims) against bundled \(provenance.shippingDims)")
        }
        if let expectedDocumentCount, docs != expectedDocumentCount {
            throw SemanticUnavailable.malformedArtifact(
                "shard holds \(docs) rows, index says \(expectedDocumentCount)")
        }
        let expected = header + docs * dims + docs * 4
        guard mapped.count == expected else {
            throw SemanticUnavailable.malformedArtifact(
                "expected \(expected) bytes for \(docs) rows, found \(mapped.count)")
        }
        self.data = mapped
        self.dims = dims
        self.documentCount = docs
        self.codesOffset = header
        self.scalesOffset = header + docs * dims
    }

    /// Runs `body` over the int8 codes and the scales.
    ///
    /// - Parameter body: Receives a pointer to the first code, a pointer to the first scale, and the
    ///   row count.
    /// - Returns: Whatever `body` returns.
    public func withVectors<T>(
        _ body: (UnsafeRawPointer, UnsafeRawPointer, Int) throws -> T
    ) rethrows -> T {
        try data.withUnsafeBytes { raw in
            try body(raw.baseAddress!.advanced(by: codesOffset),
                     raw.baseAddress!.advanced(by: scalesOffset),
                     documentCount)
        }
    }

    /// Approximate cosine between one of this shard's rows and a query vector, allocating nothing.
    ///
    /// The rerank stage calls this once per candidate — 800 times per query — so the per-call cost is
    /// the whole cost. Materialising each row as a `[Int8]` first measured 5.59 ms per query against
    /// 1.71 ms for this path; the difference is the allocator, not the arithmetic.
    ///
    /// - Parameters:
    ///   - row: Row within this shard (not a corpus row).
    ///   - query: The anchor's int8 codes, at this shard's width.
    ///   - queryScale: The anchor's quantization scale.
    /// - Returns: The approximate cosine, or `nil` when the row or width is out of range.
    public func cosine(row: Int, query: [Int8], queryScale: Float) -> Double? {
        guard row >= 0, row < documentCount, query.count == dims else { return nil }
        return data.withUnsafeBytes { raw in
            let codes = raw.baseAddress!.advanced(by: codesOffset + row * dims)
            var dot = 0
            query.withUnsafeBufferPointer { queryBuffer in
                for index in 0..<dims {
                    dot += Int(queryBuffer[index])
                        * Int(codes.loadUnaligned(fromByteOffset: index, as: Int8.self))
                }
            }
            let scale = Float(bitPattern: raw.loadUnaligned(
                fromByteOffset: scalesOffset + row * 4, as: UInt32.self).littleEndian)
            return Double(dot) * Double(scale) * Double(queryScale)
        }
    }

    /// One row's int8 codes and scale.
    ///
    /// Allocates; use `cosine(row:query:queryScale:)` on the hot rerank path.
    ///
    /// - Parameter row: Row within this shard (not a corpus row).
    /// - Returns: The codes and scale, or `nil` when out of range.
    public func vector(at row: Int) -> (codes: [Int8], scale: Float)? {
        guard row >= 0, row < documentCount else { return nil }
        return data.withUnsafeBytes { raw in
            var codes = [Int8](repeating: 0, count: dims)
            for index in 0..<dims {
                codes[index] = raw.loadUnaligned(
                    fromByteOffset: codesOffset + row * dims + index, as: Int8.self)
            }
            let scale = Float(bitPattern: raw.loadUnaligned(
                fromByteOffset: scalesOffset + row * 4, as: UInt32.self).littleEndian)
            return (codes, scale)
        }
    }
}

extension Data {
    /// Reads a little-endian `UInt32` at a byte offset.
    ///
    /// - Parameter offset: Byte offset into the data.
    /// - Returns: The decoded value.
    fileprivate func littleEndianUInt32(at offset: Int) -> UInt32 {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }
}
