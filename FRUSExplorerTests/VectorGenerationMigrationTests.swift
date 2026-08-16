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

/// A rehearsal of the 256 → 512 generation change, against real artifacts of both widths.
///
/// ## Why rehearse rather than reason
/// Moving the corpus to 512 dimensions means publishing 155 MB of shards and swapping five bundled
/// files. Two of the three things that could go wrong are **ordering** problems that only appear on
/// a device — a bundle swapped before the shards are published, or old shards left behind — and
/// neither is visible in a diff. Rehearsing costs one test and tells the owner exactly what each
/// failure looks like before they spend the effort.
///
/// ## It is skipped unless the 512 artifacts are on this machine
/// `SEMANTIC_512_DIR` names a directory holding a 512-dimension `semantic-vectors-index.json` and
/// `semantic-shards-manifest.json`; `SEMANTIC_512_SHARDS` the matching `.vec` files. They are 175 MB
/// and deliberately not in the repo — `SemanticVectorsGenerator` at `DIMS=512` reproduces them
/// byte-for-byte (verified twice over all 552 shards), so they are regenerable rather than stored.
///
/// Version history:
///   1.0 — the 512 migration rehearsal
@Suite("Vector generation migration", .serialized)
struct VectorGenerationMigrationTests {

    /// The repo root, found by walking up from this file — the test process's working directory
    /// is not the checkout, so a relative path finds nothing and the suite skips itself silently.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// A shipped 256 shard, or `nil` when the gitignored build is absent.
    private static func shipped256(_ volumeID: String) -> Data? {
        try? Data(contentsOf: repoRoot
            .appending(path: "Planning/semantic-vectors/shards/\(volumeID).vec"))
    }

    private struct Bundle512 {
        let index: SemanticVectorsArtifacts.Index
        let shards: URL
    }

    private static func load512() throws -> Bundle512? {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SEMANTIC_512_DIR"], let shards = env["SEMANTIC_512_SHARDS"] else {
            return nil
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: dir)
            .appending(path: "semantic-vectors-index.json"))
        let index = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self, from: data)
        return Bundle512(index: index, shards: URL(fileURLWithPath: shards))
    }

    /// A temporary shard directory, and a store pinned to `provenance`.
    private static func makeStore(_ provenance: SemanticVectorsArtifacts.Provenance,
                                  counts: [String: Int]) throws -> (SemanticShardStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (SemanticShardStore(directory: directory, provenance: provenance,
                                   expectedCounts: counts), directory)
    }

    // MARK: - The rehearsal

    @MainActor
    @Test("A device on 256 upgrades to 512: old shards go, new ones verify and score")
    func upgradeFrom256To512() async throws {
        guard let bundle = try Self.load512() else {
            print("[512] skipped — set SEMANTIC_512_DIR and SEMANTIC_512_SHARDS")
            return
        }
        await BundledSemanticVectors.prepare()
        let shipped = try #require(BundledSemanticVectors.index)   // the 256 generation

        #expect(shipped.provenance.shippingDims == 256)
        #expect(bundle.index.provenance.shippingDims == 512)
        #expect(shipped.provenance.digestHex != bundle.index.provenance.digestHex,
                "the two generations share a digest — the family rule cannot distinguish them")

        // ── The device as it is today: a 256 store with shards on disk ──────────────────────
        let (old, directory) = try Self.makeStore(
            shipped.provenance,
            counts: Dictionary(shipped.volumes.map { ($0.volumeID, $0.documentCount) },
                               uniquingKeysWith: { first, _ in first }))
        _ = await old.purgeIfGenerationChanged()      // stamps the 256 marker
        let sampleID = bundle.index.volumes[0].volumeID
        if let bytes = Self.shipped256(sampleID) {
            try bytes.write(to: directory.appendingPathComponent("\(sampleID).vec"))
        } else {
            try Data(repeating: 0, count: 256).write(
                to: directory.appendingPathComponent("\(sampleID).vec"))
        }
        #expect(await old.volumeIDsOnDisk().count == 1)

        // ── The update lands: same directory, a store pinned to 512 ─────────────────────────
        let next = SemanticShardStore(
            directory: directory, provenance: bundle.index.provenance,
            expectedCounts: Dictionary(
                bundle.index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first }))
        let discarded = await next.purgeIfGenerationChanged()
        #expect(discarded == 1, """
            The 256 shard survived the generation change. It would then be counted as present by \
            the storage screen and refused whenever a surface asked for it — indefinitely, since \
            nothing re-fetches a shard that is already on disk.
            """)
        #expect(await next.volumeIDsOnDisk().isEmpty)

        // ── The re-download, verified against the 512 manifest ──────────────────────────────
        let payload = try Data(contentsOf: bundle.shards.appending(path: "\(sampleID).vec"))
        let digest = Data(SHA256.hash(data: payload)).map { String(format: "%02x", $0) }.joined()
        StubShardProtocol.bodies = ["\(sampleID).vec": (payload, 200)]
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [sampleID: .init(bytes: payload.count, sha256: digest)],
            session: StubShardProtocol.makeSession())

        try await fetcher.fetchShard(for: sampleID, into: next)
        #expect(await next.volumeIDsOnDisk() == [sampleID])

        // ── And it is usable, not merely present ────────────────────────────────────────────
        let shard = try #require(await next.shard(for: sampleID))
        #expect(shard.dims == 512, "the adopted shard is not the width the bundle expects")
        #expect(shard.documentCount == bundle.index.volumes[0].documentCount)
        let anchor = try #require(shard.vector(at: 0))
        let self0 = try #require(shard.cosine(row: 0, query: anchor.codes, queryScale: anchor.scale))
        #expect(self0 > 0.99, "a document should be ~1.0 similar to itself, got \(self0)")
        // Announce what was exercised. A suite that skips itself prints nothing and passes, which
        // is indistinguishable from a suite that verified the migration — the vacuity this repo
        // keeps catching.
        print("[512] upgraded \(sampleID): discarded \(discarded) old shard, adopted "
              + "\(payload.count) bytes at \(shard.dims) dims, self-similarity \(self0)")

        try? FileManager.default.removeItem(at: directory)
    }

    /// **The ordering constraint, stated as a failure.**
    ///
    /// If the bundle is swapped to 512 *before* the 512 shards are published, every fetch pulls a
    /// 256 file and checks it against a 512 expectation. This pins what that looks like — a refused
    /// download with a recorded diagnosis — so the symptom is recognisable rather than mysterious,
    /// and so the ordering is enforced by the artifact rather than by remembering.
    @MainActor
    @Test("A 512 bundle against a 256 host refuses every shard, and says why")
    func prematureSwapIsRefused() async throws {
        guard let bundle = try Self.load512() else { return }
        await BundledSemanticVectors.prepare()
        let shipped = try #require(BundledSemanticVectors.index)

        let sampleID = bundle.index.volumes[0].volumeID
        guard let old256 = Self.shipped256(sampleID) else {
            print("[512] no 256 shards on disk — run SemanticVectorsGenerator to exercise this")
            return
        }
        let new512 = try Data(contentsOf: bundle.shards.appending(path: "\(sampleID).vec"))
        #expect(old256.count != new512.count, "the two widths produced the same byte length")

        let (store, directory) = try Self.makeStore(
            bundle.index.provenance,
            counts: Dictionary(bundle.index.volumes.map { ($0.volumeID, $0.documentCount) },
                               uniquingKeysWith: { first, _ in first }))
        defer { try? FileManager.default.removeItem(at: directory) }

        // The host still serves 256 while the bundle expects 512.
        let digest512 = Data(SHA256.hash(data: new512)).map { String(format: "%02x", $0) }.joined()
        StubShardProtocol.bodies = ["\(sampleID).vec": (old256, 200)]
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [sampleID: .init(bytes: new512.count, sha256: digest512)],
            session: StubShardProtocol.makeSession())

        await #expect(throws: (any Error).self) {
            try await fetcher.fetchShard(for: sampleID, into: store)
        }
        // Caught by LENGTH, before the digest and before the store — the cheapest check first.
        let recorded = await fetcher.failure(for: sampleID)
        if case .integrityMismatch = recorded {} else {
            Issue.record("expected .integrityMismatch, got \(String(describing: recorded))")
        }
        #expect(await store.volumeIDsOnDisk().isEmpty,
                "a shard that failed verification was still written to the store")
        // And the reader is told, rather than left with a silently empty axis.
        #expect(!SemanticStorageReport.describe(try #require(recorded)).isEmpty)
        print("[512] premature swap refused \(sampleID): served \(old256.count) bytes against a "
              + "\(new512.count)-byte expectation -> \(String(describing: recorded))")
        _ = shipped
    }
}
