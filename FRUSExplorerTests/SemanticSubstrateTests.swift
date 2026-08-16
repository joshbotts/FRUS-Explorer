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
@testable import FRUSExplorer

/// The V-2 device substrate, in the app host — where `Bundle.main` reaches the shipped artifacts.
///
/// The kit's own suite covers the readers and the kernel against synthetic fixtures. What can only be
/// checked here is that the **real** bundled artifacts are enrolled, decodable, and mutually
/// consistent, and that the shard store's disk behaviour is what teardown depends on. An un-enrolled
/// bundle resource produces no build error and no crash — only a permanently dark feature — which is
/// exactly why `KeynessBaselineArtifactTests` exists and why this does too.
///
/// Version history:
///   1.0 — V-2: initial implementation
@Suite("Semantic substrate")
struct SemanticSubstrateTests {

    // MARK: - Bundled artifacts

    /// The load the app performs at launch, against the real bundle.
    @MainActor
    @Test("The bundled tiers load, agree on provenance, and cover the shipped corpus")
    func bundledTiersLoad() async throws {
        BundledSemanticVectors.resetForTesting()
        await BundledSemanticVectors.prepare()

        #expect(BundledSemanticVectors.isAvailable,
                "semantic artifacts are not loading: \(BundledSemanticVectors.availability)")
        let index = try #require(BundledSemanticVectors.index)
        let vectors = try #require(BundledSemanticVectors.corpusVectors)

        // The two tiers must describe the same corpus, or a row means different things to each.
        #expect(vectors.documentCount == index.documentCount)
        #expect(vectors.dims == index.provenance.shippingDims)
        #expect(index.volumes.count == 552)
        #expect(index.documentCount == 314_483)
        // 552 volume centroids + 107 subseries centroids.
        #expect(vectors.centroidCount == index.volumes.count + index.file.subseries.count)
    }

    /// Row keying over the real artifact: a spot-check that the identity layer survived packing.
    @MainActor
    @Test("Real row keying round-trips at the corpus's boundaries")
    func realRowKeyingRoundTrips() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)

        // First row, last row, and a volume boundary — the places an off-by-one lives.
        var probes = [0, index.documentCount - 1]
        if index.volumes.count > 1 {
            probes.append(index.volumes[1].rowOffset)
            probes.append(index.volumes[1].rowOffset - 1)
        }
        for row in probes {
            let document = try #require(index.document(at: row), "row \(row)")
            #expect(index.row(documentID: document.documentID, volumeID: document.volumeID) == row)
            let located = try #require(index.volumeSlot(containing: row))
            #expect(index.volumes[located.slot].volumeID == document.volumeID)
            #expect(index.volumes[located.slot].rowOffset + located.localRow == row)
        }
    }

    /// `volumeSlot` is the hot path and `document(at:)` the readable one; they must never disagree
    /// about which volume owns a row.
    @MainActor
    @Test("The fast row lookup agrees with the readable one across every volume boundary")
    func fastAndReadableLookupsAgree() async throws {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        for volume in index.volumes {
            let first = volume.rowOffset
            let last = volume.rowOffset + volume.documentCount - 1
            for row in [first, last] {
                let located = try #require(index.volumeSlot(containing: row), "row \(row)")
                let document = try #require(index.document(at: row), "row \(row)")
                #expect(index.volumes[located.slot].volumeID == document.volumeID,
                        "\(volume.volumeID) row \(row)")
            }
        }
    }

    // MARK: - Shard store

    /// Builds a store over a scratch directory, using the real bundled pin.
    @MainActor
    static func makeStore() async throws -> (SemanticShardStore, SemanticVectorIndex, URL) {
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("semantic-shards-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = SemanticShardStore(
            directory: directory, provenance: index.provenance,
            expectedCounts: Dictionary(
                index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first }))
        return (store, index, directory)
    }

    @Test("An absent shard is nil, not a crash, and is remembered as refused")
    func absentShardIsTyped() async throws {
        let (store, index, _) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        #expect(await store.shard(for: volumeID) == nil)
        #expect(await store.refusal(for: volumeID) == .noArtifact)
        #expect(await store.volumeIDsOnDisk().isEmpty)
    }

    /// The adoption seam validates before it keeps — otherwise a bad file lands in the directory and
    /// a later listing reports the volume as semantic-ready.
    @Test("A file that is not a valid shard is refused and never lands in the store")
    func adoptionRefusesInvalidFiles() async throws {
        let (store, index, directory) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        let bogus = directory.appendingPathComponent("bogus.bin")
        try Data(repeating: 0, count: 512).write(to: bogus)

        await #expect(throws: SemanticUnavailable.self) {
            try await store.adoptShard(from: bogus, for: volumeID)
        }
        #expect(!FileManager.default.fileExists(
            atPath: await store.shardURL(for: volumeID).path))
        #expect(await store.volumeIDsOnDisk().isEmpty)
    }

    /// Teardown must be idempotent: the Settings storage paths run it twice, because `removeVolumes`
    /// calls the pipeline and then `DownloadManager.deleteVolume`, whose callback runs it again.
    @Test("Removing a shard twice is safe and leaves nothing behind")
    func removalIsIdempotent() async throws {
        let (store, index, _) = try await Self.makeStore()
        let volumeID = index.volumes[0].volumeID
        await store.removeShard(for: volumeID)
        await store.removeShard(for: volumeID)
        #expect(await store.volumeIDsOnDisk().isEmpty)
        await store.removeAllShards()
        #expect(await store.volumeIDsOnDisk().isEmpty)
    }

    /// A round trip through the real adoption path, using a shard the packer wrote — present only on
    /// a machine that has run the generator, so the test says what it skipped rather than failing.
    @Test("A packer-written shard adopts, maps, and scores against the bundled tier")
    func realShardAdoptsAndScores() async throws {
        let (store, index, _) = try await Self.makeStore()
        let repoShards = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Planning/semantic-vectors/shards")
        let volume = index.volumes[0]
        let source = repoShards.appendingPathComponent("\(volume.volumeID).vec")
        guard FileManager.default.fileExists(atPath: source.path) else {
            print("[SemanticSubstrateTests] no packer shards on disk (gitignored) — "
                + "run SemanticVectorsGenerator to exercise the adoption path")
            return
        }

        try await store.adoptShard(from: source, for: volume.volumeID)
        #expect(await store.volumeIDsOnDisk() == [volume.volumeID])
        let shard = try #require(await store.shard(for: volume.volumeID))
        #expect(shard.documentCount == volume.documentCount)

        // A document is maximally similar to itself: the clearest end-to-end proof that the row
        // keying, the shard's positional rows, and the cosine reconstruction all agree.
        let anchor = try #require(shard.vector(at: 0))
        let selfScore = try #require(
            shard.cosine(row: 0, query: anchor.codes, queryScale: anchor.scale))
        #expect(selfScore > 0.99, "a document should be ~1.0 similar to itself, got \(selfScore)")
    }

    // MARK: - Wiring

    /// The prepare() call is what makes every semantic surface work; without it each reads
    /// `.unavailable(.pending)` forever and the feature looks wired while being permanently dark.
    /// Source-scanned rather than behavioural, on the `KeynessWiringAuditTests` precedent.
    @Test("App start calls BundledSemanticVectors.prepare() and builds the shard store")
    func launchWiringIsPresent() throws {
        let app = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift")
        let source = try String(contentsOf: app, encoding: .utf8)
        #expect(source.contains("await BundledSemanticVectors.prepare()"))
        // The store is built and assigned. Matched in two parts since the construction gained a
        // `let store = …` binding: the generation purge has to run against the store *before* any
        // surface can reach it through `appState`, so the one-expression assignment this used to
        // pin is no longer the shape. What matters is unchanged — a store is constructed from the
        // bundled provenance and lands on `appState`.
        #expect(source.contains("SemanticShardStore("))
        #expect(source.contains("appState.semanticShardStore = store"))
        #expect(source.contains("makeSemanticVectorsDirectory"))
        // …and the purge runs at boot, or a generation change leaves unusable shards on disk being
        // counted as present and refused one at a time (the 256 -> 512 case).
        #expect(source.contains("await store.purgeIfGenerationChanged()"),
                "boot no longer discards shards from a previous vector generation")
        // Teardown: a shard must not outlive its volume.
        #expect(source.contains("semanticShardStore?.removeShard(for: volumeId)"))

        let reset = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Settings/ResetService.swift")
        let resetSource = try String(contentsOf: reset, encoding: .utf8)
        #expect(resetSource.contains("semanticShardStore?.removeAllShards()"),
                "reset deletes volume XML directly, so it never fires onVolumeDeleted")
    }
}
