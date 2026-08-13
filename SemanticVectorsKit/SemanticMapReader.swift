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

/// Mmap-backed reader for the Tier-0 map (`semantic-map.bin`).
///
/// Maps rather than reads, for the same reason the corpus tier does: 1.89 MB of placements are
/// consumed once per frame by the GPU, and decoding them into Swift structures would cost more than
/// the draw. The renderer wants one contiguous block it can hand to a vertex buffer, which is
/// exactly the file's payload.
///
/// Version history:
///   1.0 — V-4: initial implementation
public struct SemanticMapVectors: Sendable {

    /// The mapped file.
    private let data: Data
    /// Byte offset of the placement block.
    private let placementsOffset: Int
    /// Documents placed.
    public let documentCount: Int
    /// Distinct clusters, excluding the unclustered marker.
    public let clusterCount: Int
    /// Half-extent of the coordinate grid.
    public let gridExtent: Int

    /// Maps and validates the map binary.
    ///
    /// - Parameters:
    ///   - url: The artifact's location.
    ///   - provenance: The pin the vector tiers carry; a map from another generation places
    ///     documents at coordinates computed for different vectors and is refused.
    ///   - expectedDocumentCount: The vector artifact's document count, or `nil` to skip the check.
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
            throw SemanticUnavailable.malformedArtifact("map shorter than its header")
        }
        guard String(data: mapped.prefix(4), encoding: .utf8) == SemanticMapArtifacts.mapMagic else {
            throw SemanticUnavailable.malformedArtifact("wrong map magic")
        }
        let version = mapped.mapUInt32(at: 4)
        guard version == SemanticVectorsArtifacts.binaryVersion else {
            throw SemanticUnavailable.malformedArtifact("map layout version \(version)")
        }
        let digest = mapped.subdata(in: 20..<52)
        guard digest == provenance.digest else {
            throw SemanticUnavailable.provenanceMismatch(
                expected: provenance.digestHex,
                found: digest.map { String(format: "%02x", $0) }.joined())
        }
        let documents = Int(mapped.mapUInt32(at: 8))
        if let expectedDocumentCount, documents != expectedDocumentCount {
            throw SemanticUnavailable.malformedArtifact(
                "map places \(documents) documents, the vectors have \(expectedDocumentCount)")
        }
        let expected = header + documents * SemanticMapArtifacts.bytesPerDocument
        guard mapped.count == expected else {
            throw SemanticUnavailable.malformedArtifact(
                "expected \(expected) bytes for \(documents) placements, found \(mapped.count)")
        }
        self.data = mapped
        self.documentCount = documents
        self.clusterCount = Int(mapped.mapUInt32(at: 12))
        self.gridExtent = Int(mapped.mapUInt32(at: 16))
        self.placementsOffset = header
    }

    /// Runs `body` over the raw placement block.
    ///
    /// - Parameter body: Receives a pointer to the first placement and the count.
    /// - Returns: Whatever `body` returns.
    public func withPlacements<T>(_ body: (UnsafeRawPointer, Int) throws -> T) rethrows -> T {
        try data.withUnsafeBytes { raw in
            try body(raw.baseAddress!.advanced(by: placementsOffset), documentCount)
        }
    }

    /// One document's placement.
    ///
    /// - Parameter row: A corpus row index.
    /// - Returns: The placement, or `nil` when out of range.
    public func placement(at row: Int) -> SemanticMapArtifacts.Placement? {
        guard row >= 0, row < documentCount else { return nil }
        let base = placementsOffset + row * SemanticMapArtifacts.bytesPerDocument
        return data.withUnsafeBytes { raw in
            SemanticMapArtifacts.Placement(
                x: Int16(bitPattern: raw.loadUnaligned(
                    fromByteOffset: base, as: UInt16.self).littleEndian),
                y: Int16(bitPattern: raw.loadUnaligned(
                    fromByteOffset: base + 2, as: UInt16.self).littleEndian),
                cluster: raw.loadUnaligned(fromByteOffset: base + 4, as: UInt16.self).littleEndian)
        }
    }
}

extension Data {
    /// Reads a little-endian `UInt32` at a byte offset.
    /// - Parameter offset: Byte offset.
    /// - Returns: The value.
    fileprivate func mapUInt32(at offset: Int) -> UInt32 {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }
}
