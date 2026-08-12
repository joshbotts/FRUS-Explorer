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
@testable import SemanticVectorsGeneratorCore

// MARK: - Quantization

/// The three pinned encoding rules. Each test names the numpy expression it mirrors, because a
/// plausible-but-different rule here silently re-prices every recall number the program has.
///
/// Version history:
///   1.0 — V-1: initial implementation
@Suite("SemanticVectors — pinned quantization rules")
struct SemanticQuantizationTests {

    @Test("Truncation keeps the leading dims and renormalises (spike_gates.truncate)")
    func truncateRenormalises() throws {
        let vector = [0.6, 0.8, 3.0, -4.0]
        let cut = try #require(SemanticQuantization.truncate(vector, to: 2))
        #expect(cut.count == 2)
        // 0.6/0.8 is already unit-norm, so the renormalisation is the identity here.
        #expect(abs(cut[0] - 0.6) < 1e-6)
        #expect(abs(cut[1] - 0.8) < 1e-6)

        let unnormalised = try #require(SemanticQuantization.truncate([3.0, 4.0, 99.0], to: 2))
        #expect(abs(unnormalised[0] - 0.6) < 1e-6)
        #expect(abs(unnormalised[1] - 0.8) < 1e-6)
    }

    @Test("Truncating a zero prefix yields nil rather than a divide by zero")
    func truncateRefusesZeroPrefix() {
        #expect(SemanticQuantization.truncate([0, 0, 1, 1], to: 2) == nil)
    }

    @Test("int8 scale is max|x|/127 and the peak component saturates at ±127")
    func int8ScaleAndPeak() throws {
        let quantized = try #require(SemanticQuantization.quantizeInt8([0.5, -1.0, 0.25]))
        #expect(abs(quantized.scale - Float(1.0 / 127.0)) < 1e-9)
        #expect(quantized.codes[1] == -127)
        #expect(quantized.codes[0] == 64)   // 0.5 / (1/127) = 63.5, half-to-even -> 64
        #expect(quantized.codes[2] == 32)   // 0.25 / (1/127) = 31.75 -> 32
    }

    /// Swift's bare `rounded()` is half-away-from-zero; numpy's `rint` — the function the gates ran
    /// through — is half-to-even. A vector engineered to land exactly on .5 separates them.
    @Test("Rounding is half-to-even, matching numpy rint rather than Swift's default")
    func int8RoundsHalfToEven() throws {
        // scale = 1/127 exactly, so component c quantizes to c × 127.
        // 1.5/127 and 2.5/127 land on exact halves: rint gives 2 and 2, rounded() gives 2 and 3.
        let vector: [Float] = [1.0, 1.5 / 127.0, 2.5 / 127.0]
        let quantized = try #require(SemanticQuantization.quantizeInt8(vector))
        #expect(quantized.codes[1] == 2)
        #expect(quantized.codes[2] == 2)
    }

    @Test("All-zero vectors are refused rather than quantized to a zero scale")
    func int8RefusesZeroVector() {
        #expect(SemanticQuantization.quantizeInt8([0, 0, 0, 0]) == nil)
    }

    /// `np.packbits(matrix >= 0)`: MSB-first within each byte, and zero counts as set.
    @Test("Sign packing is MSB-first and packs zero as a set bit")
    func signBitsMatchPackbits() {
        let vector: [Float] = [1, -1, 0, -0.5, 2, -2, 3, -3]
        // bits:                1   0  1    0  1   0  1   0  -> 0b10101010
        #expect(SemanticQuantization.packSignBits(vector) == [0b1010_1010])

        let second: [Float] = [-1, -1, -1, -1, -1, -1, -1, 1]
        #expect(SemanticQuantization.packSignBits(second) == [0b0000_0001])
    }

    @Test("Sign packing spans multiple bytes in order")
    func signBitsSpanBytes() {
        var vector = [Float](repeating: -1, count: 16)
        vector[0] = 1      // first bit of byte 0
        vector[15] = 1     // last bit of byte 1
        #expect(SemanticQuantization.packSignBits(vector) == [0b1000_0000, 0b0000_0001])
    }

    @Test("Centroid is the L2-normalised mean")
    func centroidNormalises() throws {
        let centre = try #require(
            SemanticQuantization.centroid(of: [[3, 0], [0, 4]], dims: 2))
        // mean is (1.5, 2.0), norm 2.5 -> (0.6, 0.8)
        #expect(abs(centre[0] - 0.6) < 1e-6)
        #expect(abs(centre[1] - 0.8) < 1e-6)
    }

    @Test("Cancelling and empty centroids are refused")
    func centroidRefusesDegenerate() {
        #expect(SemanticQuantization.centroid(of: [[1, 0], [-1, 0]], dims: 2) == nil)
        #expect(SemanticQuantization.centroid(of: [], dims: 2) == nil)
    }

    /// The property the int8 tier exists for: `dot(a, b) × scaleA × scaleB` reconstructs cosine
    /// closely enough to rank with. Measured corpus-wide at four-decimal agreement; here a loose
    /// bound simply pins that the reconstruction is the intended one and not, say, off by a factor
    /// of the scale.
    @Test("int8 dot times scales reconstructs cosine")
    func int8ReconstructsCosine() throws {
        let a: [Float] = [0.6, 0.8, 0, 0]
        let b: [Float] = [0.8, 0.6, 0, 0]
        let exact = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let qa = try #require(SemanticQuantization.quantizeInt8(a))
        let qb = try #require(SemanticQuantization.quantizeInt8(b))
        var dot = 0
        for index in 0..<a.count { dot += Int(qa.codes[index]) * Int(qb.codes[index]) }
        let reconstructed = Float(dot) * qa.scale * qb.scale
        #expect(abs(reconstructed - exact) < 0.01)
    }
}

// MARK: - Document ids

/// The run-length id encoding — the artifact's identity layer.
///
/// Version history:
///   1.0 — V-1: initial implementation
@Suite("SemanticVectors — document-id segments")
struct DocumentIDSegmentsTests {

    @Test("A plain sequential volume encodes to one segment")
    func sequentialVolumeIsOneSegment() {
        let ids = (1...500).map { "d\($0)" }
        let segments = DocumentIDSegments.encode(ids)
        #expect(segments.count == 1)
        #expect(segments[0] == DocumentIDSegments.Segment(start: 0, id: "d1", count: 500))
        #expect(DocumentIDSegments.decode(segments) == ids)
    }

    /// The measured failure of the design's implicit keying: one suffixed id shifts every document
    /// behind it, so `d{ordinal+1}` mis-keys the whole tail. Here the tail is preserved exactly.
    @Test("A letter-suffixed id breaks the run and the tail keeps its own numbering")
    func suffixedIDSplitsTheRun() {
        let ids = ["d372", "d373", "d373a", "d374", "d375"]
        let segments = DocumentIDSegments.encode(ids)
        #expect(segments == [
            DocumentIDSegments.Segment(start: 0, id: "d372", count: 2),
            DocumentIDSegments.Segment(start: 2, id: "d373a", count: 1),
            DocumentIDSegments.Segment(start: 3, id: "d374", count: 2),
        ])
        #expect(DocumentIDSegments.decode(segments) == ids)
    }

    @Test("Non-numeric ids round-trip as single-document segments")
    func nonNumericIDsRoundTrip() {
        let ids = ["d1", "d2", "appA", "appB", "s05sub04", "d3"]
        let segments = DocumentIDSegments.encode(ids)
        #expect(DocumentIDSegments.decode(segments) == ids)
        #expect(segments.filter { $0.count > 1 }.allSatisfy {
            DocumentIDSegments.numericPart(of: $0.id) != nil
        })
    }

    @Test("Numeric gaps start a new segment")
    func gapsSplitRuns() {
        let ids = ["d1", "d2", "d9", "d10"]
        #expect(DocumentIDSegments.encode(ids).count == 2)
        #expect(DocumentIDSegments.decode(DocumentIDSegments.encode(ids)) == ids)
    }

    @Test("Numeric part parses only exact d-plus-digits ids")
    func numericPartIsStrict() {
        #expect(DocumentIDSegments.numericPart(of: "d42") == 42)
        #expect(DocumentIDSegments.numericPart(of: "d0") == 0)
        #expect(DocumentIDSegments.numericPart(of: "d42a") == nil)
        #expect(DocumentIDSegments.numericPart(of: "appA") == nil)
        #expect(DocumentIDSegments.numericPart(of: "d") == nil)
        #expect(DocumentIDSegments.numericPart(of: "") == nil)
    }

    /// `decode` re-mints interior ids from a value, so admitting a zero-padded id would let a run
    /// form whose members come back as `d7`, `d8` — the same documents under different names.
    @Test("A multi-digit leading zero is refused, so padded ids stay literal and round-trip")
    func zeroPaddedIDsStayLiteral() {
        #expect(DocumentIDSegments.numericPart(of: "d006") == nil)
        #expect(DocumentIDSegments.numericPart(of: "d09") == nil)
        // Single "d0" is unambiguous and still parses.
        #expect(DocumentIDSegments.numericPart(of: "d0") == 0)

        let padded = ["d006", "d007", "d008"]
        let segments = DocumentIDSegments.encode(padded)
        #expect(segments.count == 3, "each padded id must be its own literal segment")
        #expect(DocumentIDSegments.decode(segments) == padded)

        // Mixed: the padded id must not be swallowed into its neighbours' run.
        let mixed = ["d1", "d2", "d003", "d4"]
        #expect(DocumentIDSegments.decode(DocumentIDSegments.encode(mixed)) == mixed)
    }

    /// Non-ASCII digits satisfy `Character.isNumber`; `Int()` rejects them. Pinned so nobody
    /// "fixes" the parse into accepting them.
    @Test("Exotic digit strings become literal segments rather than parsing")
    func exoticDigitsAreLiteral() {
        #expect(DocumentIDSegments.numericPart(of: "d١٢") == nil)
        #expect(DocumentIDSegments.numericPart(of: "d99999999999999999999") == nil)
        let ids = ["d1", "d99999999999999999999", "d2"]
        #expect(DocumentIDSegments.decode(DocumentIDSegments.encode(ids)) == ids)
    }

    @Test("Decoding refuses a multi-document run from a non-numeric id")
    func decodeRefusesImpossibleRun() {
        #expect(DocumentIDSegments.decode(
            [DocumentIDSegments.Segment(start: 0, id: "appA", count: 3)]) == nil)
    }

    @Test("Decoding refuses segments that do not tile the row range")
    func decodeRefusesNonTiling() {
        #expect(DocumentIDSegments.decode([
            DocumentIDSegments.Segment(start: 0, id: "d1", count: 2),
            DocumentIDSegments.Segment(start: 5, id: "d9", count: 1),
        ]) == nil)
    }

    @Test("Encoding an empty volume yields no segments")
    func emptyVolume() {
        #expect(DocumentIDSegments.encode([]).isEmpty)
        #expect(DocumentIDSegments.decode([]) == [])
    }
}

// MARK: - Configuration

/// `DIMS` validation. Every case here was a live trap or a silent fallback before the check
/// existed — and in a release build a `precondition` keeps its teeth but loses its message, so
/// `DIMS=7` exited 133 with no diagnostic at all.
///
/// Version history:
///   1.0 — V-1: initial implementation
@Suite("SemanticVectors — shipping-width validation")
struct ShippingDimsTests {

    /// Asserts a value is refused, and that the message names the variable.
    /// - Parameters:
    ///   - raw: The `DIMS` value under test.
    ///   - native: The store's native width.
    static func expectRefused(_ raw: String?, native: Int = 768) {
        do {
            let dims = try SemanticVectorsRunner.resolveShippingDims(raw, native: native)
            Issue.record("DIMS=\(raw ?? "nil") should have been refused, got \(dims)")
        } catch let error as SemanticVectorsRunner.RunError {
            #expect(error.description.hasPrefix("DIMS"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Unset or empty DIMS defaults to 256")
    func defaultsTo256() throws {
        #expect(try SemanticVectorsRunner.resolveShippingDims(nil, native: 768) == 256)
        #expect(try SemanticVectorsRunner.resolveShippingDims("", native: 768) == 256)
    }

    @Test("Measured widths are accepted")
    func measuredWidthsAccepted() throws {
        #expect(try SemanticVectorsRunner.resolveShippingDims("256", native: 768) == 256)
        #expect(try SemanticVectorsRunner.resolveShippingDims("512", native: 768) == 512)
    }

    @Test("A non-numeric DIMS is refused rather than silently packing at 256")
    func nonNumericRefused() {
        Self.expectRefused("abc")
        Self.expectRefused("256.0")
        Self.expectRefused(" 256")
    }

    @Test("Zero, negative, over-native and unaligned widths are refused, not trapped")
    func structurallyInvalidRefused() {
        Self.expectRefused("0")
        Self.expectRefused("-8")
        Self.expectRefused("1024")           // wider than native 768
        Self.expectRefused("7")              // not byte-aligned: would trap in packSignBits
    }

    /// The point of the check: a width with no corpus-scale measurement cannot ship, because the
    /// index would state a recall number borrowed from a different artifact.
    @Test("A byte-aligned width with no measurement is refused")
    func unmeasuredWidthRefused() {
        Self.expectRefused("128")
        Self.expectRefused("768")
    }

    @Test("Every accepted width has its own measured recall number")
    func everyAcceptedWidthIsPriced() {
        for (dims, recall) in SemanticVectorsRunner.measuredRecallAt10 {
            #expect(dims % 8 == 0)
            #expect(recall > 0 && recall <= 1)
            #expect((try? SemanticVectorsRunner.resolveShippingDims(String(dims), native: 768))
                == dims)
        }
        // The two the corpus gates measured; a third must arrive with its own measurement.
        #expect(SemanticVectorsRunner.measuredRecallAt10[256] == 0.7449)
        #expect(SemanticVectorsRunner.measuredRecallAt10[512] == 0.8510)
    }
}

// MARK: - Binary layouts

/// The two binary layouts, read back field by field.
///
/// Version history:
///   1.0 — V-1: initial implementation
@Suite("SemanticVectors — binary layouts")
struct SemanticVectorsArtifactsTests {

    /// A provenance pin standing in for the shipped one.
    static let provenance = SemanticVectorsArtifacts.Provenance(
        model: "text-embedding-embeddinggemma-300m-qat",
        modelFileSHA256: String(repeating: "a", count: 64),
        nativeDims: 768, shippingDims: 8, chunkChars: 3200, overlapChars: 480,
        prefix: "title: none | text: ", pooling: "test", quantization: "test")

    /// Reads a little-endian `UInt32` at `offset`.
    /// - Parameters:
    ///   - data: The buffer.
    ///   - offset: Byte offset.
    /// - Returns: The decoded value.
    static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
            .littleEndian
    }

    @Test("Corpus binary header names its magic, version, dims and counts")
    func corpusHeader() {
        let bits: [[UInt8]] = [[0b1010_1010], [0b0000_1111], [0xFF]]
        let centroids: [(codes: [Int8], scale: Float)] = [
            (codes: [Int8](repeating: 1, count: 8), scale: 0.5),
        ]
        let data = SemanticVectorsArtifacts.corpusBinary(
            signBits: bits, centroids: centroids, dims: 8, provenance: Self.provenance)

        #expect(String(data: data.prefix(4), encoding: .utf8) == "FRSV")
        #expect(Self.uint32(data, at: 4) == SemanticVectorsArtifacts.binaryVersion)
        #expect(Self.uint32(data, at: 8) == 8)
        #expect(Self.uint32(data, at: 12) == 3)
        #expect(Self.uint32(data, at: 16) == 1)
        #expect(data[20..<52] == Self.provenance.digest)
        // Header padding is zeroed so two runs cannot differ in the slack.
        #expect(data[52..<64].allSatisfy { $0 == 0 })
        #expect(data.count == 64 + 3 * 1 + 1 * (8 + 4))
    }

    @Test("Corpus binary lays sign bits down in row order, centroids after them")
    func corpusPayloadOrder() {
        let bits: [[UInt8]] = [[0x11], [0x22], [0x33]]
        let centroids: [(codes: [Int8], scale: Float)] = [
            (codes: [Int8](repeating: -2, count: 8), scale: 0.25),
        ]
        let data = SemanticVectorsArtifacts.corpusBinary(
            signBits: bits, centroids: centroids, dims: 8, provenance: Self.provenance)
        #expect(Array(data[64..<67]) == [0x11, 0x22, 0x33])
        #expect(Array(data[67..<75]) == [UInt8](repeating: UInt8(bitPattern: -2), count: 8))
        let scaleBits = Self.uint32(data, at: 75)
        #expect(Float(bitPattern: scaleBits) == 0.25)
    }

    @Test("Shard header and payload round-trip codes then scales")
    func shardLayout() {
        let codes: [[Int8]] = [[1, 2, 3, 4, 5, 6, 7, -8], [-1, -2, -3, -4, -5, -6, -7, 8]]
        let scales: [Float] = [0.125, 0.5]
        let data = SemanticVectorsArtifacts.volumeShard(
            codes: codes, scales: scales, dims: 8, provenance: Self.provenance)

        #expect(String(data: data.prefix(4), encoding: .utf8) == "FRSS")
        #expect(Self.uint32(data, at: 8) == 8)
        #expect(Self.uint32(data, at: 12) == 2)
        #expect(data[16..<48] == Self.provenance.digest)
        #expect(data[48..<64].allSatisfy { $0 == 0 })
        #expect(data.count == 64 + 2 * 8 + 2 * 4)

        #expect(Int8(bitPattern: data[64]) == 1)
        #expect(Int8(bitPattern: data[71]) == -8)
        #expect(Int8(bitPattern: data[72]) == -1)
        #expect(Float(bitPattern: Self.uint32(data, at: 80)) == 0.125)
        #expect(Float(bitPattern: Self.uint32(data, at: 84)) == 0.5)
    }

    @Test("Packing the same inputs twice is byte-identical")
    func packingIsDeterministic() {
        let bits: [[UInt8]] = [[0x01], [0x02]]
        let centroids: [(codes: [Int8], scale: Float)] = [
            (codes: [Int8](repeating: 3, count: 8), scale: 0.75),
        ]
        let first = SemanticVectorsArtifacts.corpusBinary(
            signBits: bits, centroids: centroids, dims: 8, provenance: Self.provenance)
        let second = SemanticVectorsArtifacts.corpusBinary(
            signBits: bits, centroids: centroids, dims: 8, provenance: Self.provenance)
        #expect(first == second)
    }

    /// The version-skew rule's mechanism: anything that changes the numbers changes the digest,
    /// and anything that does not, does not.
    @Test("Provenance digest tracks the fields that change the numbers")
    func digestCoversScoringFields() {
        let base = Self.provenance
        var changed = SemanticVectorsArtifacts.Provenance(
            model: base.model, modelFileSHA256: base.modelFileSHA256, nativeDims: base.nativeDims,
            shippingDims: 512, chunkChars: base.chunkChars, overlapChars: base.overlapChars,
            prefix: base.prefix, pooling: base.pooling, quantization: base.quantization)
        #expect(changed.digest != base.digest)

        changed = SemanticVectorsArtifacts.Provenance(
            model: base.model, modelFileSHA256: base.modelFileSHA256, nativeDims: base.nativeDims,
            shippingDims: base.shippingDims, chunkChars: base.chunkChars,
            overlapChars: base.overlapChars, prefix: "search_document: ", pooling: base.pooling,
            quantization: base.quantization)
        #expect(changed.digest != base.digest)

        let identical = SemanticVectorsArtifacts.Provenance(
            model: base.model, modelFileSHA256: base.modelFileSHA256, nativeDims: base.nativeDims,
            shippingDims: base.shippingDims, chunkChars: base.chunkChars,
            overlapChars: base.overlapChars, prefix: base.prefix, pooling: base.pooling,
            quantization: base.quantization)
        #expect(identical.digest == base.digest)
        #expect(identical.digestHex == base.digestHex)
        #expect(base.digestHex.count == 64)
    }

    /// The trailing space in EmbeddingGemma's document prompt is part of the contract, and a
    /// separator-joined canonical string is what keeps it from being invisible to the digest.
    @Test("A prefix differing only in trailing space changes the digest")
    func digestSeesTrailingSpace() {
        let base = Self.provenance
        let trimmed = SemanticVectorsArtifacts.Provenance(
            model: base.model, modelFileSHA256: base.modelFileSHA256, nativeDims: base.nativeDims,
            shippingDims: base.shippingDims, chunkChars: base.chunkChars,
            overlapChars: base.overlapChars, prefix: "title: none | text:",
            pooling: base.pooling, quantization: base.quantization)
        #expect(trimmed.digest != base.digest)
    }
}
