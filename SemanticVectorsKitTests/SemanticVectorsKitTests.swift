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

// MARK: - Fixtures

/// Builds synthetic artifacts so the kit's readers and kernel are tested without the 10 MB bundled
/// file — which the artifact suite covers separately. Synthetic fixtures are what let a test assert
/// on a *known* answer rather than on whatever the corpus happens to contain.
enum SemanticFixture {

    /// A provenance pin for fixtures; deliberately not the shipping one.
    static func provenance(dims: Int = 8) -> SemanticVectorsArtifacts.Provenance {
        SemanticVectorsArtifacts.Provenance(
            model: "fixture-model", modelFileSHA256: String(repeating: "b", count: 64),
            nativeDims: 16, shippingDims: dims, chunkChars: 3200, overlapChars: 480,
            prefix: "title: none | text: ", pooling: "fixture", quantization: "fixture")
    }

    /// A corpus binary with `rows` documents whose sign bits are the low bits of their row index,
    /// plus `centroids` centroids.
    static func corpusBinary(
        rows: Int, centroids: Int = 0, dims: Int = 8,
        provenance: SemanticVectorsArtifacts.Provenance
    ) -> Data {
        let signBits = (0..<rows).map { row -> [UInt8] in
            var bytes = [UInt8](repeating: 0, count: dims / 8)
            bytes[0] = UInt8(row % 256)
            return bytes
        }
        let centroidRows = (0..<centroids).map { index -> (codes: [Int8], scale: Float) in
            (codes: [Int8](repeating: Int8(index % 100), count: dims), scale: Float(index + 1) / 100)
        }
        return SemanticVectorsArtifacts.corpusBinary(
            signBits: signBits, centroids: centroidRows, dims: dims, provenance: provenance)
    }

    /// A shard whose row *k* has all components `k % 100` and scale `(k+1)/1000`.
    static func shard(
        rows: Int, dims: Int = 8, provenance: SemanticVectorsArtifacts.Provenance
    ) -> Data {
        let codes = (0..<rows).map { [Int8](repeating: Int8($0 % 100), count: dims) }
        let scales = (0..<rows).map { Float($0 + 1) / 1000 }
        return SemanticVectorsArtifacts.volumeShard(
            codes: codes, scales: scales, dims: dims, provenance: provenance)
    }

    /// Writes `data` to a unique temporary file and returns its URL.
    static func temporaryFile(_ data: Data, name: String) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("semkit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}

// MARK: - Row keying

/// The map between `(volume, document)` and a corpus row — the layer where a mistake shows the wrong
/// document at a plausible score rather than failing.
///
/// Version history:
///   1.0 — V-2: initial implementation
@Suite("SemanticVectorsKit — row keying")
struct SemanticVectorIndexTests {

    /// An index over three volumes whose id shapes cover the corpus's real variety: a plain run, a
    /// run broken by a letter-suffixed id, and non-numeric ids.
    static func index() -> SemanticVectorIndex {
        let volumes = [
            SemanticVectorsArtifacts.VolumeEntry(
                volumeID: "volA", rowOffset: 0, documentCount: 4,
                idSegments: DocumentIDSegments.encode(["d1", "d2", "d3", "d4"])),
            SemanticVectorsArtifacts.VolumeEntry(
                volumeID: "volB", rowOffset: 4, documentCount: 5,
                idSegments: DocumentIDSegments.encode(["d372", "d373", "d373a", "d374", "d375"])),
            SemanticVectorsArtifacts.VolumeEntry(
                volumeID: "volC", rowOffset: 9, documentCount: 3,
                idSegments: DocumentIDSegments.encode(["appA", "s05sub04", "d1"])),
        ]
        return SemanticVectorIndex(file: SemanticVectorsArtifacts.Index(
            schema: 1, generated: "2026-08-12", provenance: SemanticFixture.provenance(),
            harvestGenerated: "2026-08-10T20:19:04", harvestScriptSHA256: "abc",
            documentCount: 12, volumes: volumes, subseries: ["s1"],
            retrieval: SemanticVectorsArtifacts.Index.Retrieval(
                rerankPool: 800, measuredRecallAt10: 0.7449, measuredBy: "fixture")))
    }

    @Test("A document resolves to its row, inside a run and at a run start")
    func rowLookup() {
        let index = Self.index()
        #expect(index.row(documentID: "d1", volumeID: "volA") == 0)
        #expect(index.row(documentID: "d4", volumeID: "volA") == 3)
        #expect(index.row(documentID: "d372", volumeID: "volB") == 4)
        #expect(index.row(documentID: "d373a", volumeID: "volB") == 6)
        #expect(index.row(documentID: "d375", volumeID: "volB") == 8)
        #expect(index.row(documentID: "appA", volumeID: "volC") == 9)
        #expect(index.row(documentID: "d1", volumeID: "volC") == 11)
    }

    /// The same id lives in two volumes at different rows; a lookup that ignored the volume would
    /// return the first and be wrong for the second.
    @Test("Lookup is scoped to its volume")
    func lookupIsVolumeScoped() {
        let index = Self.index()
        #expect(index.row(documentID: "d1", volumeID: "volA") == 0)
        #expect(index.row(documentID: "d1", volumeID: "volC") == 11)
        #expect(index.row(documentID: "d2", volumeID: "volC") == nil)
        #expect(index.row(documentID: "d1", volumeID: "nope") == nil)
    }

    /// The property that matters: every row names the document that resolves back to it.
    @Test("Row and document lookups are inverses across every row")
    func lookupsAreInverses() throws {
        let index = Self.index()
        for row in 0..<index.documentCount {
            let document = try #require(index.document(at: row), "row \(row) named no document")
            #expect(index.row(documentID: document.documentID, volumeID: document.volumeID) == row)
        }
        #expect(index.document(at: -1) == nil)
        #expect(index.document(at: index.documentCount) == nil)
    }

    /// A suffixed id must not be reachable by arithmetic from its run's base — that is precisely the
    /// mis-keying the stored encoding exists to prevent.
    @Test("An id absent from the volume resolves to nil rather than to a neighbouring row")
    func absentIDsAreNil() {
        let index = Self.index()
        #expect(index.row(documentID: "d5", volumeID: "volA") == nil)
        #expect(index.row(documentID: "d376", volumeID: "volB") == nil)
        #expect(index.row(documentID: "d372a", volumeID: "volB") == nil)
    }

    @Test("Volume ranges tile the corpus without gaps or overlap")
    func volumeRangesTile() throws {
        let index = Self.index()
        #expect(index.rows(forVolume: "volA") == 0..<4)
        #expect(index.rows(forVolume: "volB") == 4..<9)
        #expect(index.rows(forVolume: "volC") == 9..<12)
        #expect(index.rows(forVolume: "missing") == nil)
        #expect(try #require(index.documentIDs(forVolume: "volB"))
            == ["d372", "d373", "d373a", "d374", "d375"])
    }
}

// MARK: - Readers

/// The mmap readers and the provenance refusals that keep two generations apart.
///
/// Version history:
///   1.0 — V-2: initial implementation
@Suite("SemanticVectorsKit — artifact readers")
struct SemanticVectorReaderTests {

    @Test("The corpus reader exposes header counts and centroids")
    func corpusReaderRoundTrip() throws {
        let provenance = SemanticFixture.provenance()
        let url = try SemanticFixture.temporaryFile(
            SemanticFixture.corpusBinary(rows: 10, centroids: 3, provenance: provenance),
            name: "corpus.bin")
        let vectors = try SemanticCorpusVectors(contentsOf: url, expecting: provenance)
        #expect(vectors.documentCount == 10)
        #expect(vectors.centroidCount == 3)
        #expect(vectors.dims == 8)
        #expect(vectors.bytesPerRow == 1)

        let centroid = try #require(vectors.centroid(at: 1))
        #expect(centroid.codes == [Int8](repeating: 1, count: 8))
        #expect(abs(centroid.scale - 0.02) < 1e-6)
        #expect(vectors.centroid(at: 3) == nil)
        #expect(vectors.centroid(at: -1) == nil)
    }

    /// The family rule, at the byte level: a tier from another generation is refused, not blended.
    @Test("A corpus binary from another generation is refused")
    func corpusRefusesForeignProvenance() throws {
        let built = SemanticFixture.provenance()
        let other = SemanticVectorsArtifacts.Provenance(
            model: built.model, modelFileSHA256: built.modelFileSHA256,
            nativeDims: built.nativeDims, shippingDims: built.shippingDims,
            chunkChars: built.chunkChars, overlapChars: built.overlapChars,
            prefix: "search_document: ", pooling: built.pooling, quantization: built.quantization)
        let url = try SemanticFixture.temporaryFile(
            SemanticFixture.corpusBinary(rows: 4, provenance: built), name: "corpus.bin")

        #expect(throws: SemanticUnavailable.self) {
            _ = try SemanticCorpusVectors(contentsOf: url, expecting: other)
        }
        do {
            _ = try SemanticCorpusVectors(contentsOf: url, expecting: other)
        } catch let error as SemanticUnavailable {
            guard case .provenanceMismatch(let expected, let found) = error else {
                Issue.record("expected provenanceMismatch, got \(error)"); return
            }
            #expect(expected == other.digestHex)
            #expect(found == built.digestHex)
        }
    }

    @Test("A missing or truncated corpus binary is typed, not a crash")
    func corpusRefusesBadFiles() throws {
        let provenance = SemanticFixture.provenance()
        let missing = URL(fileURLWithPath: "/nonexistent/semantic-vectors-binary.bin")
        #expect(throws: SemanticUnavailable.noArtifact) {
            _ = try SemanticCorpusVectors(contentsOf: missing, expecting: provenance)
        }

        var truncated = SemanticFixture.corpusBinary(rows: 10, provenance: provenance)
        truncated.removeLast(3)
        let url = try SemanticFixture.temporaryFile(truncated, name: "short.bin")
        #expect(throws: SemanticUnavailable.self) {
            _ = try SemanticCorpusVectors(contentsOf: url, expecting: provenance)
        }
    }

    @Test("The shard reader round-trips codes and scales")
    func shardReaderRoundTrip() throws {
        let provenance = SemanticFixture.provenance()
        let url = try SemanticFixture.temporaryFile(
            SemanticFixture.shard(rows: 5, provenance: provenance), name: "vol.vec")
        let shard = try SemanticShard(
            contentsOf: url, provenance: provenance, expectedDocumentCount: 5)
        #expect(shard.documentCount == 5)
        let vector = try #require(shard.vector(at: 2))
        #expect(vector.codes == [Int8](repeating: 2, count: 8))
        #expect(abs(vector.scale - 0.003) < 1e-6)
        #expect(shard.vector(at: 5) == nil)
    }

    /// A shard whose length disagrees with the bundled index would misalign every row after the
    /// discrepancy — silently, since both files are otherwise well-formed.
    @Test("A shard whose row count disagrees with the index is refused")
    func shardRefusesCountMismatch() throws {
        let provenance = SemanticFixture.provenance()
        let url = try SemanticFixture.temporaryFile(
            SemanticFixture.shard(rows: 5, provenance: provenance), name: "vol.vec")
        #expect(throws: SemanticUnavailable.self) {
            _ = try SemanticShard(
                contentsOf: url, provenance: provenance, expectedDocumentCount: 6)
        }
    }

    @Test("A corpus binary offered as a shard is refused on its magic")
    func shardRefusesWrongMagic() throws {
        let provenance = SemanticFixture.provenance()
        let url = try SemanticFixture.temporaryFile(
            SemanticFixture.corpusBinary(rows: 4, provenance: provenance), name: "wrong.vec")
        #expect(throws: SemanticUnavailable.self) {
            _ = try SemanticShard(contentsOf: url, provenance: provenance)
        }
    }
}

// MARK: - Kernel

/// The retrieval kernel: selection, tie-breaks, and the refusal to score what it cannot see.
///
/// Version history:
///   1.0 — V-2: initial implementation
@Suite("SemanticVectorsKit — retrieval kernel")
struct SemanticRetrievalKernelTests {

    /// A corpus of `rows` documents with pseudo-random 64-bit sign patterns from a fixed seed, so the
    /// counting-sort selection can be checked against a naive sort on non-trivial data.
    static func randomCorpus(rows: Int, seed: UInt64 = 18_610_810)
        throws -> (vectors: SemanticCorpusVectors, patterns: [UInt64]) {
        let provenance = SemanticFixture.provenance(dims: 64)
        var state = seed
        var patterns: [UInt64] = []
        var signBits: [[UInt8]] = []
        for _ in 0..<rows {
            // xorshift64 — deterministic and dependency-free.
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            patterns.append(state)
            var bytes = [UInt8](repeating: 0, count: 8)
            for byte in 0..<8 { bytes[byte] = UInt8((state >> (8 * UInt64(7 - byte))) & 0xFF) }
            signBits.append(bytes)
        }
        let data = SemanticVectorsArtifacts.corpusBinary(
            signBits: signBits, centroids: [], dims: 64, provenance: provenance)
        let url = try SemanticFixture.temporaryFile(data, name: "corpus.bin")
        return (try SemanticCorpusVectors(contentsOf: url, expecting: provenance), patterns)
    }

    /// The correctness proof for the counting sort: it must agree exactly — order included — with a
    /// naive "compute every distance, sort by (distance, row)" implementation.
    @Test("Counting-sort selection matches a naive sort, order and all")
    func selectionMatchesNaiveSort() throws {
        let (vectors, patterns) = try Self.randomCorpus(rows: 500)
        for queryRow in [0, 1, 17, 250, 499] {
            for limit in [1, 5, 40, 499] {
                let got = SemanticRetrievalKernel.hammingCandidates(
                    queryRow: queryRow, in: vectors, limit: limit)
                var scored: [(row: Int, distance: Int)] = []
                for row in 0..<patterns.count where row != queryRow {
                    let distance = (patterns[row] ^ patterns[queryRow]).nonzeroBitCount
                    scored.append((row: row, distance: distance))
                }
                scored.sort { left, right in
                    left.distance == right.distance
                        ? left.row < right.row
                        : left.distance < right.distance
                }
                let expected: [Int] = scored.prefix(limit).map { $0.row }
                #expect(got == expected, "query \(queryRow) limit \(limit)")
            }
        }
    }

    @Test("The anchor is never its own candidate, and a full request still fills")
    func anchorExcludedAndPoolFills() throws {
        let (vectors, _) = try Self.randomCorpus(rows: 120)
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryRow: 7, in: vectors, limit: 119)
        #expect(!candidates.contains(7))
        #expect(candidates.count == 119)
        #expect(Set(candidates).count == candidates.count)
    }

    /// The display fence, applied during collection: an excluded row must not consume a slot.
    @Test("An eligibility filter excludes rows without shrinking the pool")
    func eligibilityFilterKeepsThePoolFull() throws {
        let (vectors, _) = try Self.randomCorpus(rows: 300)
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryRow: 3, in: vectors, limit: 50, isEligible: { $0 % 2 == 0 })
        #expect(candidates.count == 50)
        #expect(candidates.allSatisfy { $0 % 2 == 0 })
    }

    @Test("Out-of-range or empty requests return nothing rather than trapping")
    func degenerateRequests() throws {
        let (vectors, _) = try Self.randomCorpus(rows: 20)
        #expect(SemanticRetrievalKernel.hammingCandidates(
            queryRow: -1, in: vectors, limit: 5).isEmpty)
        #expect(SemanticRetrievalKernel.hammingCandidates(
            queryRow: 100, in: vectors, limit: 5).isEmpty)
        #expect(SemanticRetrievalKernel.hammingCandidates(
            queryRow: 0, in: vectors, limit: 0).isEmpty)
    }

    @Test("Rerank sorts by score descending, then row ascending")
    func rerankTieBreak() {
        let unit: [Int8] = [127, 0, 0, 0, 0, 0, 0, 0]
        let query = (codes: unit, scale: Float(1.0 / 127))
        // Rows 1 and 3 are identical to the query, so they tie and must come back in row order.
        let vectors: [Int: (codes: [Int8], scale: Float)] = [
            1: (unit, Float(1.0 / 127)),
            2: ([64, 0, 0, 0, 0, 0, 0, 0], Float(1.0 / 127)),
            3: (unit, Float(1.0 / 127)),
        ]
        let ranked = SemanticRetrievalKernel.rerank(
            candidates: [3, 2, 1], limit: 3,
            score: { vectors[$0].map { SemanticRetrievalKernel.cosine(query, $0) } })
        #expect(ranked.map(\.row) == [1, 3, 2])
        #expect(ranked[0].score > ranked[2].score)
    }

    /// A row whose shard is absent is dropped, never scored zero — absence of evidence is not
    /// evidence of dissimilarity, and a zero would rank it below genuinely dissimilar documents.
    @Test("A row with no vector is dropped from the rerank, not scored as zero")
    func missingVectorsAreDropped() {
        let unit: [Int8] = [127, 0, 0, 0, 0, 0, 0, 0]
        let query = (codes: unit, scale: Float(1.0 / 127))
        let ranked = SemanticRetrievalKernel.rerank(
            candidates: [1, 2, 3], limit: 10,
            score: { $0 == 2 ? SemanticRetrievalKernel.cosine(query, (unit, Float(1.0 / 127))) : nil })
        #expect(ranked.map(\.row) == [2])
    }

    @Test("int8 cosine reconstructs a known similarity")
    func cosineReconstruction() {
        let a = (codes: [Int8](arrayLiteral: 127, 0, 0, 0, 0, 0, 0, 0), scale: Float(1.0 / 127))
        let b = (codes: [Int8](arrayLiteral: 0, 127, 0, 0, 0, 0, 0, 0), scale: Float(1.0 / 127))
        #expect(abs(SemanticRetrievalKernel.cosine(a, a) - 1.0) < 0.001)
        #expect(abs(SemanticRetrievalKernel.cosine(a, b)) < 0.001)
    }

    @Test("Binary similarity is 1 for a row against itself and falls with distance")
    func binarySimilarityShape() throws {
        let (vectors, patterns) = try Self.randomCorpus(rows: 50)
        #expect(SemanticRetrievalKernel.binarySimilarity(4, 4, in: vectors) == 1.0)
        let similarity = try #require(SemanticRetrievalKernel.binarySimilarity(4, 9, in: vectors))
        let distance = Double((patterns[4] ^ patterns[9]).nonzeroBitCount)
        #expect(abs(similarity - (1.0 - distance / 64.0)) < 1e-9)
        #expect(SemanticRetrievalKernel.binarySimilarity(4, 999, in: vectors) == nil)
    }
}
