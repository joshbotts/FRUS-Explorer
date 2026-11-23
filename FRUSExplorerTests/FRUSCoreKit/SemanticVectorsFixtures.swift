// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds SemanticVectorsKit as a module of its own; Xcode compiles it into the app.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

// MARK: - BundledTiersFixture

/// The bundled vector tiers, `semantic-vectors-index.json` and `semantic-vectors-binary.bin`, loaded
/// by SemanticVectorsKit's ``SemanticBundledTiers``, as a host outside the app loads them: in the
/// package, where `Bundle.main` is the test runner, from the repository; in Xcode, from the test
/// host's bundle, the files the app loads.
///
/// Each call loads its own pair and shares nothing with the app's `BundledSemanticVectors`, whose
/// statics `SemanticSubstrateTests` resets while it loads them again: a suite that waited on those
/// statics could read them empty in that window, as the suites that still call
/// `BundledSemanticVectors.prepare()` can.
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
enum BundledTiersFixture {

    /// The row index and the corpus tier.
    static func tiers() throws -> (index: SemanticVectorIndex, corpus: SemanticCorpusVectors) {
        #if SWIFT_PACKAGE
        // `FRUSExplorer/Resources`, from this file's place in the repository.
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources", isDirectory: true)
        let indexURL = resources.appendingPathComponent("semantic-vectors-index.json")
        let binaryURL = resources.appendingPathComponent("semantic-vectors-binary.bin")
        #else
        let indexURL = try #require(Bundle.main.url(forResource: "semantic-vectors-index", withExtension: "json"))
        let binaryURL = try #require(Bundle.main.url(forResource: "semantic-vectors-binary", withExtension: "bin"))
        #endif
        let tiers = try SemanticBundledTiers(indexAt: indexURL, binaryAt: binaryURL)
        return (tiers.index, tiers.corpus)
    }
}

// MARK: - SyntheticShardFolder

/// Tier-2 shards written for the tests, for real volumes of the bundled index, and a host's reading of
/// them through SemanticVectorsKit's ``SemanticShardSource``.
///
/// The packer's shards are not in the repository (`Planning/semantic-vectors/shards` is ignored), so
/// these are made here: each document's int8 codes carry its own sign bits from the bundled corpus
/// tier, each with a magnitude from 1 to 126 that a hash of the row and the dimension picks, and its
/// scale makes its vector unit length. So a document scores 1.0 against itself and less against any
/// other, and the nearer two documents are in the sign bits the higher they score, as with the real
/// shards. Each is written with the kit's own writer, under the bundled provenance and at the index's
/// count for its volume, and read back through ``SemanticShard/init(contentsOf:provenance:expectedDocumentCount:)``,
/// which validates it, as a host's store reads one.
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
actor SyntheticShardFolder: SemanticShardSource {

    /// The folder the shards are written into.
    let directory: URL
    /// The bundled provenance every shard carries.
    private let provenance: SemanticVectorsArtifacts.Provenance
    /// The index's count for each volume.
    private let expectedCounts: [String: Int]
    /// Every volume a pass asked for, in the order asked.
    private(set) var asked: [String] = []

    /// A folder holding no shard yet.
    init(index: SemanticVectorIndex) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSSemanticShards-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        provenance = index.provenance
        expectedCounts = Dictionary(index.volumes.map { ($0.volumeID, $0.documentCount) },
                                    uniquingKeysWith: { first, _ in first })
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Reads a volume's shard as a host's store does: mapped and validated, or `nil`.
    func shard(for volumeID: String) -> SemanticShard? {
        asked.append(volumeID)
        return try? SemanticShard(contentsOf: url(for: volumeID), provenance: provenance,
                                  expectedDocumentCount: expectedCounts[volumeID])
    }

    /// Writes a shard for each volume.
    func write(_ volumeIDs: [String], index: SemanticVectorIndex, corpus: SemanticCorpusVectors) throws {
        for volumeID in volumeIDs {
            guard let entry = index.volume(volumeID) else {
                throw SemanticUnavailable.malformedArtifact("\(volumeID) is not in the bundled index")
            }
            let rows = Array(entry.rowOffset..<(entry.rowOffset + entry.documentCount))
            let vectors = rows.map { Self.vector(row: $0, corpus: corpus, dims: provenance.shippingDims) }
            let data = SemanticVectorsArtifacts.volumeShard(
                codes: vectors.map(\.codes), scales: vectors.map(\.scale),
                dims: provenance.shippingDims, provenance: provenance)
            try data.write(to: url(for: volumeID))
        }
    }

    /// The shard's file.
    private func url(for volumeID: String) -> URL {
        directory.appendingPathComponent("\(volumeID).vec")
    }

    /// One document's codes, from its sign bits (most significant bit first, a set bit for a
    /// dimension at or above zero), and the scale that makes it unit length.
    static func vector(row: Int, corpus: SemanticCorpusVectors, dims: Int) -> (codes: [Int8], scale: Float) {
        var codes = [Int8](repeating: 0, count: dims)
        corpus.withSignBits { base, _ in
            for dimension in 0..<dims {
                let byte = base.load(fromByteOffset: row * corpus.bytesPerRow + dimension / 8, as: UInt8.self)
                let positive = byte & (UInt8(0x80) >> UInt8(dimension % 8)) != 0
                var mixed = UInt64(row) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(dimension) &* 0xBF58_476D_1CE4_E5B9
                mixed ^= mixed >> 31
                mixed &*= 0x94D0_49BB_1331_11EB
                mixed ^= mixed >> 29
                let magnitude = Int8(1 + mixed % 126)
                codes[dimension] = positive ? magnitude : -magnitude
            }
        }
        let norm = codes.reduce(0.0) { $0 + Double($1) * Double($1) }.squareRoot()
        return (codes, Float(1 / norm))
    }
}

// MARK: - ShardRequestLog

/// The volumes a host was asked for, through ``SemanticSimilarityHost/requestShard(for:)``.
///
/// Version history:
///   1.0 — 2026-11-23: FRUS Explorer Light's S26a
@MainActor
final class ShardRequestLog {
    /// Every request, in order.
    private(set) var volumes: [String] = []

    /// Records one.
    func record(_ volumeID: String) { volumes.append(volumeID) }
}
