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
@testable import SemanticVectorsKit

// MARK: - SemanticBundledTiersTests

/// The bundled pair loaded by URL (``SemanticBundledTiers``), as the app's `BundledSemanticVectors`
/// loads it from its bundle and a host outside the app loads it from a folder: both files or neither,
/// and every failure a ``SemanticUnavailable`` the app's screens already word.
///
/// The fixtures are the row-keying suite's index of twelve documents at a width of 8, written as the
/// packer writes `semantic-vectors-index.json`, beside a corpus binary of twelve rows. The shipped pair
/// is loaded through the same initialiser by FRUSCoreKit's `SemanticSubstrateTests` in the package.
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
@Suite("SemanticVectorsKit — the bundled pair by URL")
struct SemanticBundledTiersTests {

    /// The index file and a corpus binary under `binaryProvenance`, in one folder.
    private static func pair(binaryProvenance: SemanticVectorsArtifacts.Provenance = SemanticFixture.provenance(),
                             rows: Int = 12) throws -> (index: URL, binary: URL) {
        let index = try SemanticFixture.temporaryFile(
            try JSONEncoder().encode(SemanticVectorIndexTests.index().file), name: "semantic-vectors-index.json")
        let binary = index.deletingLastPathComponent().appendingPathComponent("semantic-vectors-binary.bin")
        try SemanticFixture.corpusBinary(rows: rows, provenance: binaryProvenance).write(to: binary)
        return (index, binary)
    }

    @Test("The pair loads: the index decoded and the binary mapped, under one provenance")
    func thePairLoads() throws {
        let urls = try Self.pair()
        let tiers = try SemanticBundledTiers(indexAt: urls.index, binaryAt: urls.binary)
        #expect(tiers.index.documentCount == 12)
        #expect(tiers.corpus.documentCount == tiers.index.documentCount)
        #expect(tiers.corpus.dims == tiers.index.provenance.shippingDims)
        #expect(tiers.index.row(documentID: "d373a", volumeID: "volB") == 6)
    }

    @Test("A binary from another generation is refused, naming both digests")
    func anotherGenerationIsRefused() throws {
        let other = SemanticFixture.provenance(dims: 16)
        let urls = try Self.pair(binaryProvenance: other)
        #expect(throws: SemanticUnavailable.provenanceMismatch(
            expected: SemanticFixture.provenance().digestHex, found: other.digestHex)) {
            try SemanticBundledTiers(indexAt: urls.index, binaryAt: urls.binary)
        }
    }

    @Test("A missing binary is no artifact; a missing or unreadable index is a malformed one, named for the index")
    func eachMissingHalfIsRefused() throws {
        let urls = try Self.pair()
        let nowhere = urls.index.deletingLastPathComponent().appendingPathComponent("absent.bin")
        #expect(throws: SemanticUnavailable.noArtifact) {
            try SemanticBundledTiers(indexAt: urls.index, binaryAt: nowhere)
        }
        for index in [nowhere, try SemanticFixture.temporaryFile(Data("{}".utf8), name: "index.json")] {
            do {
                _ = try SemanticBundledTiers(indexAt: index, binaryAt: urls.binary)
                Issue.record("an index at \(index.lastPathComponent) loaded")
            } catch {
                guard case .malformedArtifact(let reason) = error else {
                    Issue.record("refused as \(error), not as a malformed index"); continue
                }
                #expect(reason.hasPrefix("index: "), "\(reason)")
            }
        }
    }
}
