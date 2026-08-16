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
@testable import FRUSExplorer

/// Serves canned responses so the fetcher's verification can be tested without the network.
///
/// Registered per-session rather than globally, so a stray registration cannot affect the rest of
/// the suite.
final class StubShardProtocol: URLProtocol, @unchecked Sendable {

    /// Response bodies by last path component, and the status to answer with.
    nonisolated(unsafe) static var bodies: [String: (Data, Int)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let name = request.url?.lastPathComponent ?? ""
        let (data, status) = Self.bodies[name] ?? (Data(), 404)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// A session that answers from `bodies`.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubShardProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// The Tier-2 fetch: what it verifies, and what it refuses.
///
/// Version history:
///   1.0 — V-2b: initial implementation
@Suite("Semantic shard fetch")
struct SemanticShardFetcherTests {

    /// A store over a scratch directory, using the real bundled pin.
    @MainActor
    static func makeStore() async throws -> (SemanticShardStore, SemanticVectorIndex) {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shard-fetch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (SemanticShardStore(
            directory: directory, provenance: index.provenance,
            expectedCounts: Dictionary(
                index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first })), index)
    }

    // MARK: - The bundled manifest

    /// The manifest and the index must describe one generation. If they disagree, every download
    /// verifies against a digest for vectors the app cannot use — each fetch succeeds and each shard
    /// is then refused by its own header, which reads as a network problem and is not one.
    @MainActor
    @Test("The bundled shard manifest matches the bundled index, volume for volume")
    func manifestMatchesIndex() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let expectations = try #require(SemanticShardFetcher.bundledExpectations())
        let digest = try #require(SemanticShardFetcher.bundledProvenanceDigest())

        #expect(digest == index.provenance.digestHex)
        #expect(expectations.count == index.volumes.count)
        for volume in index.volumes {
            let expectation = try #require(expectations[volume.volumeID],
                                           "\(volume.volumeID) missing from shard manifest")
            // Header + int8 codes + Float32 scales, which is what the packer wrote.
            let expectedBytes = 64 + volume.documentCount * (index.dims + 4)
            #expect(expectation.bytes == expectedBytes, "\(volume.volumeID) byte length")
            #expect(expectation.sha256.count == 64)
        }
    }

    // MARK: - Verification

    @Test("A volume the manifest does not list is refused before any request")
    func unknownVolumeIsRefused() async throws {
        let (store, _) = try await Self.makeStore()
        let fetcher = SemanticShardFetcher(
            expectations: [:], session: StubShardProtocol.makeSession())
        #expect(await fetcher.hasShard(for: "frus1861") == false)
        await #expect(throws: SemanticShardFetcher.FetchError.notInManifest("frus1861")) {
            try await fetcher.fetchShard(for: "frus1861", into: store)
        }
    }

    /// The check the app has never had for volume XML: bytes that arrive intact but wrong.
    @Test("A shard whose bytes do not match the manifest digest is refused and not kept")
    func corruptShardIsRefused() async throws {
        let (store, index) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        let payload = Data(repeating: 0xAB, count: 4096)
        StubShardProtocol.bodies = ["\(volumeID).vec": (payload, 200)]
        // The manifest expects the right length but a different digest.
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [volumeID: .init(bytes: 4096, sha256: String(repeating: "0", count: 64))],
            session: StubShardProtocol.makeSession())

        await #expect(throws: SemanticShardFetcher.FetchError.self) {
            try await fetcher.fetchShard(for: volumeID, into: store)
        }
        #expect(await store.volumeIDsOnDisk().isEmpty, "a refused shard must not land in the store")
    }

    @Test("A truncated shard is refused on length before its digest is computed")
    func truncatedShardIsRefused() async throws {
        let (store, index) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        let payload = Data(repeating: 0xAB, count: 100)
        StubShardProtocol.bodies = ["\(volumeID).vec": (payload, 200)]
        let digest = Data(SHA256.hash(data: payload)).map { String(format: "%02x", $0) }.joined()
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [volumeID: .init(bytes: 999_999, sha256: digest)],
            session: StubShardProtocol.makeSession())

        await #expect(throws: SemanticShardFetcher.FetchError.self) {
            try await fetcher.fetchShard(for: volumeID, into: store)
        }
        #expect(await store.volumeIDsOnDisk().isEmpty)
    }

    @Test("A non-success status is reported as such and remembered")
    func httpFailureIsRemembered() async throws {
        let (store, index) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        StubShardProtocol.bodies = ["\(volumeID).vec": (Data(), 404)]
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [volumeID: .init(bytes: 10, sha256: String(repeating: "0", count: 64))],
            session: StubShardProtocol.makeSession())

        await #expect(throws: SemanticShardFetcher.FetchError.self) {
            try await fetcher.fetchShard(for: volumeID, into: store)
        }
        #expect(await fetcher.failure(for: volumeID) != nil,
                "a lazy path must not retry a known failure on every query")
        await fetcher.clearFailures()
        #expect(await fetcher.failure(for: volumeID) == nil)
    }

    /// The happy path, served from a real packer-written shard so the bytes are genuine — present
    /// only on a machine that has run the generator, so the test says what it skipped.
    @Test("A verified shard is adopted, mapped, and scores against itself")
    func verifiedShardIsAdopted() async throws {
        let (store, index) = try await Self.makeStore()
        let volume = index.volumes[0]
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Planning/semantic-vectors/shards/\(volume.volumeID).vec")
        guard let payload = try? Data(contentsOf: source) else {
            print("[SemanticShardFetcherTests] no packer shards on disk (gitignored) — "
                + "run SemanticVectorsGenerator to exercise the fetch path")
            return
        }

        StubShardProtocol.bodies = ["\(volume.volumeID).vec": (payload, 200)]
        let digest = Data(SHA256.hash(data: payload)).map { String(format: "%02x", $0) }.joined()
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [volume.volumeID: .init(bytes: payload.count, sha256: digest)],
            session: StubShardProtocol.makeSession())

        try await fetcher.fetchShard(for: volume.volumeID, into: store)
        #expect(await store.volumeIDsOnDisk() == [volume.volumeID])
        let shard = try #require(await store.shard(for: volume.volumeID))
        #expect(shard.documentCount == volume.documentCount)
    }

    /// A shard whose bytes verify but whose HEADER the store refuses must be recorded (#900).
    ///
    /// ## The failure this pins was recorded nowhere at all
    /// `fetchShard` caught `SemanticUnavailable` from `adoptShard` and rethrew it **without
    /// touching `failed`**. Two consequences, and the second is the worse one:
    ///
    /// 1. The volume appeared in no diagnostic list, so the storage screen #900 adds would have
    ///    shown the device as problem-free while a volume silently had no vectors.
    /// 2. `failed` is *also* the do-not-retry gate, so the one failure that repeated on every
    ///    launch was the one nothing could report — the app re-downloaded and re-refused the same
    ///    bytes forever.
    ///
    /// It is the exact generation-skew case the manifest digest check exists to catch, which makes
    /// it the last one that should have been silent.
    ///
    /// The payload here passes the fetcher's own checks — its length and SHA-256 are computed from
    /// the bytes being served — and fails at the store, which is what separates this from
    /// `integrityMismatch`.
    @Test("A shard the store refuses is recorded as a failure, not silently rethrown")
    func storeRefusalIsRecorded() async throws {
        let (store, index) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID

        // Not a shard: right transport, wrong contents. The store's header check rejects it.
        let payload = Data(repeating: 0x7F, count: 4_096)
        let digest = Data(SHA256.hash(data: payload)).map { String(format: "%02x", $0) }.joined()
        StubShardProtocol.bodies = ["\(volumeID).vec": (payload, 200)]
        let fetcher = SemanticShardFetcher(
            baseURL: URL(string: "https://stub.invalid/shards")!,
            expectations: [volumeID: .init(bytes: payload.count, sha256: digest)],
            session: StubShardProtocol.makeSession())

        await #expect(throws: (any Error).self) {
            try await fetcher.fetchShard(for: volumeID, into: store)
        }

        let recorded = await fetcher.failure(for: volumeID)
        #expect(recorded != nil, """
            The store refused the shard and the fetcher recorded nothing. That volume is then \
            invisible to every diagnostic AND exempt from the do-not-retry gate, so it re-downloads \
            and is re-refused on every launch.
            """)
        if case .rejectedByStore = recorded {
            // The distinction that matters: the bytes arrived intact, so this is not a transport
            // or integrity fault and must not be described to the user as one.
        } else {
            Issue.record("expected .rejectedByStore, got \(String(describing: recorded))")
        }
        #expect(await store.volumeIDsOnDisk().isEmpty,
                "a refused shard was kept on disk — adoptShard validates BEFORE it moves")
    }

    // MARK: - Generation purge

    /// Shards from a previous generation are discarded at boot, not discovered one at a time.
    ///
    /// Before this, a generation change left the old shards on disk: the storage screen counted
    /// them as present, and each was refused only when some surface happened to ask for it. The
    /// 256 -> 512 move would have produced exactly that on every device that already had vectors.
    @MainActor
    @Test("A generation change discards the shards, and an unchanged one keeps them")
    func generationPurge() async throws {
        let (store, index) = try await Self.makeStore()
        let directory = await store.directory

        // Two files that look exactly like shards to every path that counts them.
        for name in ["frus1861.vec", "frus1862.vec"] {
            try Data(repeating: 0, count: 128).write(to: directory.appendingPathComponent(name))
        }
        #expect(await store.volumeIDsOnDisk().count == 2)

        // FIRST RUN: no marker. Their generation cannot be recovered, so they go — the owner
        // decision taken with the 256 -> 512 move in view.
        let discarded = await store.purgeIfGenerationChanged()
        #expect(discarded == 2, "shards predating the marker were kept and would be refused on use")
        #expect(await store.volumeIDsOnDisk().isEmpty)

        // SECOND RUN, same generation: nothing is touched. A purge that ran every launch would
        // re-download the whole library on every cold start.
        try Data(repeating: 0, count: 128)
            .write(to: directory.appendingPathComponent("frus1863.vec"))
        #expect(await store.purgeIfGenerationChanged() == 0,
                "an unchanged generation discarded shards it had just written the marker for")
        #expect(await store.volumeIDsOnDisk() == ["frus1863"])

        // A DIFFERENT generation: gone again. Same directory, a store pinned to another provenance.
        let other = SemanticVectorsArtifacts.Provenance(
            model: index.provenance.model, modelFileSHA256: index.provenance.modelFileSHA256,
            nativeDims: index.provenance.nativeDims,
            shippingDims: index.provenance.shippingDims * 2,   // the 256 -> 512 move, exactly
            chunkChars: index.provenance.chunkChars, overlapChars: index.provenance.overlapChars,
            prefix: index.provenance.prefix, pooling: index.provenance.pooling,
            quantization: index.provenance.quantization)
        #expect(other.digestHex != index.provenance.digestHex,
                "widening shippingDims did not move the digest — the family rule has stopped working")
        let next = SemanticShardStore(directory: directory, provenance: other, expectedCounts: [:])
        #expect(await next.purgeIfGenerationChanged() == 1)
        #expect(await next.volumeIDsOnDisk().isEmpty)

        // The marker itself is never counted as a shard, or the screen would report one too many.
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(".generation").path))
        #expect(await next.diskUsage().volumes == 0)
    }
}
