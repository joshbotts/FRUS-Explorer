// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - CorrectedVolumeShardTests

/// R-1c: a shard whose bundled manifest digest has moved must be discarded.
///
/// The hole this closes is the one R-1a measured. `purgeIfGenerationChanged` keys on
/// `provenance.digestHex`, whose preimage has **no corpus term** — re-harvesting one corrected volume
/// under the same model family leaves it identical, and `EXPECT_DIGEST` requires that. The shard's own
/// checks miss it too: same provenance digest, unchanged `expectedDocumentCount` when the correction
/// preserves the count, and a length check measured against the file's own header. Over all 552
/// shipped shards `bytes == 64 + n × (dims + 4)` holds 552/552 with 96 lengths shared by more than one
/// volume, so length is a bijection with document count and cannot tell two editions apart.
@Suite("Corrected volume shard invalidation (R-1c)")
struct CorrectedVolumeShardTests {

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("r1c-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func digest(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }

    /// A store over a temp directory.
    ///
    /// The provenance is loaded from the bundle so the store is built the way the app builds it, but
    /// nothing under test consults it: `purgeShardsFailingBundledDigest` is deliberately independent
    /// of the family digest, because the family digest is exactly what cannot see a corrected volume.
    @MainActor
    private func makeStore(_ directory: URL) async throws -> SemanticShardStore {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index,
                                 "the bundled semantic index must load for this suite to mean anything")
        return SemanticShardStore(directory: directory, provenance: index.provenance,
                                  expectedCounts: [:])
    }

    /// The defect, end to end: same family, same length, different bytes.
    @Test("A shard whose bundled digest moved is discarded; one that still matches is kept")
    func staleShardIsDiscardedAndFreshOneKept() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try await makeStore(dir)

        // Two shards of IDENTICAL length — the case the length check cannot separate.
        let fresh = Data(repeating: 0x11, count: 4_096)
        let stale = Data(repeating: 0x22, count: 4_096)
        try fresh.write(to: dir.appendingPathComponent("volFresh.vec"))
        try stale.write(to: dir.appendingPathComponent("volStale.vec"))
        #expect(await store.volumeIDsOnDisk().count == 2)

        // The bundle expects `fresh` for both. volStale's bytes differ, so only it should go.
        let expected = ["volFresh": digest(fresh), "volStale": digest(fresh)]
        let discarded = await store.purgeShardsFailingBundledDigest(expected)

        #expect(discarded == ["volStale"], "discarded \(discarded)")
        let left = await store.volumeIDsOnDisk()
        #expect(left == ["volFresh"], "left on disk: \(left)")
    }

    /// The migration case, and the one most likely to be got wrong: on the first run no record
    /// exists, and "absent" must mean VERIFY, not TRUST. Recording the bundled digest without
    /// hashing would bless the stale shard this exists to catch.
    @Test("With no prior record, a matching shard survives and a mismatched one does not")
    func absentRecordMeansVerifyNotTrust() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try await makeStore(dir)
        let good = Data(repeating: 0xAB, count: 2_048)
        try good.write(to: dir.appendingPathComponent("volGood.vec"))
        try Data(repeating: 0xCD, count: 2_048).write(to: dir.appendingPathComponent("volBad.vec"))
        // No sidecar has ever been written in this directory.
        #expect(!FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(".verified-digests.json").path))

        let discarded = await store.purgeShardsFailingBundledDigest(
            ["volGood": digest(good), "volBad": digest(good)])
        #expect(discarded == ["volBad"])
        #expect(await store.volumeIDsOnDisk() == ["volGood"])
    }

    /// Once verified, a second pass must not re-hash — the steady state opens no file.
    ///
    /// Asserted by removing the file's readability out from under the store: if the second pass
    /// hashed again it would fail to read and could not report zero discards from a recorded match.
    @Test("A recorded digest short-circuits the second pass")
    func recordedDigestShortCircuits() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try await makeStore(dir)
        let payload = Data(repeating: 0x7F, count: 1_024)
        let url = dir.appendingPathComponent("volA.vec")
        try payload.write(to: url)

        let expected = ["volA": digest(payload)]
        #expect(await store.purgeShardsFailingBundledDigest(expected).isEmpty)
        let sidecar = dir.appendingPathComponent(".verified-digests.json")
        #expect(FileManager.default.fileExists(atPath: sidecar.path),
                "the first pass must record what it verified")

        // Corrupt the bytes but leave the record. A re-hash would now mismatch and discard;
        // a short-circuit keeps it.
        try Data(repeating: 0x00, count: 1_024).write(to: url)
        #expect(await store.purgeShardsFailingBundledDigest(expected).isEmpty,
                "a recorded match must not re-open the file")
    }

    /// No evidence must never mean "delete everything".
    @Test("Absent or empty expectations discard nothing")
    func noEvidenceDiscardsNothing() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try await makeStore(dir)
        try Data(repeating: 0x01, count: 512).write(to: dir.appendingPathComponent("volA.vec"))
        #expect(await store.purgeShardsFailingBundledDigest(nil).isEmpty)
        #expect(await store.purgeShardsFailingBundledDigest([:]).isEmpty)
        #expect(await store.volumeIDsOnDisk() == ["volA"],
                "a build with no shard manifest must not delete the reader's vectors")
    }

    /// A volume the bundle does not mention is left alone — it is not evidence of staleness.
    @Test("A shard absent from the manifest is left alone")
    func unmentionedShardIsLeftAlone() async throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try await makeStore(dir)
        try Data(repeating: 0x02, count: 512).write(to: dir.appendingPathComponent("volMystery.vec"))
        #expect(await store.purgeShardsFailingBundledDigest(["volOther": "deadbeef"]).isEmpty)
        #expect(await store.volumeIDsOnDisk() == ["volMystery"])
    }
}
