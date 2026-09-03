// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SemanticVectorsKit
@testable import SemanticVectorsGeneratorCore

// MARK: - SemanticContractGuardTests

/// The two packer-side halves of R-2 (release plan §4.2): `EXPECT_DIGEST`, and the per-volume
/// contract check `head.json` now makes possible.
///
/// **The hazard both guard against:** the harvester rewrites `run-manifest.json` from its current
/// invocation at the end of every run, and until R-2 a per-volume head recorded only `model` and
/// `dim`. A resume that forgot `PREFIX` therefore packed cleanly under a different family digest,
/// and every installed device would refuse its shards and re-fetch 162 MB of vectors that mixed
/// two prompts. Nothing in the pipeline could say so.
///
/// The digest test drives the **real** `run()` against a two-kilobyte store, because a unit test
/// of `verifyExpectedDigest` alone would pass with the call site deleted — which is the mutation
/// that matters. Serialized: `run()` reads `ProcessInfo.environment`, which is process-global.
///
/// Version history:
///   1.0 — R-2 (release plan §4.2, W-1): initial implementation
@Suite("SemanticVectors — R-2 contract guards", .serialized)
struct SemanticContractGuardTests {

    // MARK: - verifyExpectedDigest

    @Test("Unset passes; a match passes; a mismatch refuses")
    func digestVerification() throws {
        let digest = String(repeating: "ab", count: 32)
        try SemanticVectorsRunner.verifyExpectedDigest(nil, actual: digest)
        try SemanticVectorsRunner.verifyExpectedDigest(digest, actual: digest)
        // Case- and whitespace-insensitive, since the value is pasted from a log line.
        try SemanticVectorsRunner.verifyExpectedDigest(" " + digest.uppercased() + "\n", actual: digest)
        #expect(throws: SemanticVectorsRunner.RunError.self) {
            try SemanticVectorsRunner.verifyExpectedDigest(String(repeating: "cd", count: 32),
                                                           actual: digest)
        }
    }

    /// An operator who set the variable and mistyped it must not be told the pack was verified —
    /// so a malformed value is an error, never a silent pass.
    @Test("A malformed EXPECT_DIGEST is an error, not a pass")
    func malformedDigestRefused() {
        let digest = String(repeating: "ab", count: 32)
        for bad in ["", "abc", String(repeating: "zz", count: 32), String(repeating: "ab", count: 31)] {
            #expect(throws: SemanticVectorsRunner.RunError.self, "\(bad.count) chars passed") {
                try SemanticVectorsRunner.verifyExpectedDigest(bad, actual: digest)
            }
        }
    }

    // MARK: - The store's per-volume contract

    /// A pre-R-2 head (no contract keys) is trusted; a head whose recorded prefix disagrees with
    /// the manifest is refused with the field named. Driven through `pooledDocuments`, the real
    /// reader, so a check that was never wired in would fail here.
    @Test("A head that records a different prefix is refused; one that records none is trusted")
    func perVolumeContract() throws {
        let store = try Fixture.makeStore()
        defer { store.remove() }
        let manifest = try SemanticRawStore.runManifest(at: store.url)

        // The shipped shape: no contract keys at all.
        _ = try SemanticRawStore.pooledDocuments(for: Fixture.volume, at: store.url, manifest: manifest)

        // Now a head that carries the contract, and carries it WRONG.
        try store.rewriteHead(extra: ["prefix": "", "chunk_chars": 3200, "overlap_chars": 480])
        let thrown = #expect(throws: SemanticRawStore.StoreError.self) {
            _ = try SemanticRawStore.pooledDocuments(for: Fixture.volume, at: store.url,
                                                     manifest: manifest)
        }
        if case .contractMismatch(_, let field, _, _)? = thrown {
            #expect(field == "prefix")
        } else {
            Issue.record("expected contractMismatch, got \(String(describing: thrown))")
        }

        // …and one that carries it RIGHT is accepted.
        try store.rewriteHead(extra: ["prefix": Fixture.prefix, "chunk_chars": 3200, "overlap_chars": 480])
        _ = try SemanticRawStore.pooledDocuments(for: Fixture.volume, at: store.url, manifest: manifest)
    }

    // MARK: - The real run()

    /// **The test this suite exists for.** With `EXPECT_DIGEST` set to the wrong value, `run()`
    /// must throw `unexpectedDigest` and write **nothing** — the previous artifacts survive a
    /// refused pack untouched. With the right value it packs. The right value is computed through
    /// the same `Provenance` the runner builds, so this cannot drift from the runner's own digest.
    @Test("run() refuses a wrong EXPECT_DIGEST before writing, and packs under the right one")
    func runHonoursExpectedDigest() throws {
        let store = try Fixture.makeStore()
        defer { store.remove() }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-guard-out-\(UUID().uuidString)")
        let shards = out.appendingPathComponent("shards")
        let manifestPath = store.url.appendingPathComponent("manifest.json").path
        defer { try? FileManager.default.removeItem(at: out) }

        Env.set(["STORE": store.url.path, "MANIFEST": manifestPath, "OUTPUT_DIR": out.path,
                 "SHARDS_DIR": shards.path, "DIMS": "512", "GENERATED_DATE": "2026-09-01",
                 "LAYOUT_DIR": out.appendingPathComponent("no-layout").path])
        defer { Env.clear(["STORE", "MANIFEST", "OUTPUT_DIR", "SHARDS_DIR", "DIMS",
                           "GENERATED_DATE", "LAYOUT_DIR", "EXPECT_DIGEST"]) }

        // Wrong digest: refuse, and leave no trace.
        Env.set(["EXPECT_DIGEST": String(repeating: "cd", count: 32)])
        let thrown = #expect(throws: SemanticVectorsRunner.RunError.self) {
            try SemanticVectorsRunner.run()
        }
        if case .unexpectedDigest? = thrown {} else {
            Issue.record("expected unexpectedDigest, got \(String(describing: thrown))")
        }
        #expect(!FileManager.default.fileExists(atPath: out.path),
                "a refused pack must not have created its output directory")

        // Right digest: the same Provenance the runner assembles, from the fixture's manifest.
        let manifest = try SemanticRawStore.runManifest(at: store.url)
        let expected = SemanticVectorsArtifacts.Provenance(
            model: manifest.model, modelFileSHA256: manifest.modelFileSHA256,
            nativeDims: manifest.dim, shippingDims: 512,
            chunkChars: manifest.chunkChars, overlapChars: manifest.overlapChars,
            prefix: manifest.prefix,
            pooling: "char-length-weighted mean of unit-norm chunk vectors, L2-renormalized",
            quantization: "Matryoshka cut then L2-renormalize; int8 per-vector symmetric "
                + "(scale = max|x|/127, rint half-to-even, clip ±127); binary = sign bit, "
                + "MSB-first, zero packs as 1").digestHex
        Env.set(["EXPECT_DIGEST": expected])
        try SemanticVectorsRunner.run()
        #expect(FileManager.default.fileExists(
            atPath: out.appendingPathComponent("semantic-vectors-index.json").path),
                "the correctly-expected pack must have written its index")
    }
}

// MARK: - Fixture

/// A two-kilobyte raw store: one volume, one document, one chunk at the shipping width.
private enum Fixture {
    static let volume = "frus1861"
    static let model = "text-embedding-embeddinggemma-300m-qat"
    static let prefix = "title: none | text: "
    static let dim = 512

    struct Store {
        let url: URL
        func remove() { try? FileManager.default.removeItem(at: url) }

        /// Rewrites the volume's head with extra keys — the harvester's post-R-2 shape.
        func rewriteHead(extra: [String: Any]) throws {
            var head: [String: Any] = ["volume": Fixture.volume, "model": Fixture.model,
                                       "dim": Fixture.dim, "docs": 1, "chunks": 1,
                                       "chars": 100, "secs": 0.1]
            for (key, value) in extra { head[key] = value }
            let data = try JSONSerialization.data(withJSONObject: head)
            try data.write(to: url.appendingPathComponent("vectors/\(Fixture.volume).head.json"))
        }
    }

    static func makeStore() throws -> Store {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-guard-store-\(UUID().uuidString)")
        let vectors = root.appendingPathComponent("vectors")
        try FileManager.default.createDirectory(at: vectors, withIntermediateDirectories: true)
        let store = Store(url: root)

        let runManifest: [String: Any] = [
            "model": model, "model_file_sha256": String(repeating: "ab", count: 32),
            "dim": dim, "chunk_chars": 3200, "overlap_chars": 480, "prefix": prefix,
            "generated": "2026-09-01T00:00:00", "script_sha256": String(repeating: "cd", count: 32),
        ]
        try JSONSerialization.data(withJSONObject: runManifest)
            .write(to: root.appendingPathComponent("run-manifest.json"))
        try store.rewriteHead(extra: [:])   // the shipped, pre-R-2 shape

        // One non-degenerate chunk vector, little-endian Float32.
        var bin = Data(capacity: dim * 4)
        for i in 0..<dim {
            var v = Float32(0.01 * Float(i % 7 + 1))
            withUnsafeBytes(of: &v) { bin.append(contentsOf: $0) }
        }
        try bin.write(to: vectors.appendingPathComponent("\(volume).bin"))
        try #"{"d":"d1","o":0,"c0":0,"c1":100}"#.write(
            to: vectors.appendingPathComponent("\(volume).meta.jsonl"), atomically: true, encoding: .utf8)
        try #"[{"volumeId":"frus1861","subseries":"1861"}]"#.write(
            to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        return store
    }
}

/// Process-environment helpers for driving `run()`, which reads `ProcessInfo.environment`.
private enum Env {
    static func set(_ values: [String: String]) {
        for (key, value) in values { setenv(key, value, 1) }
    }
    static func clear(_ keys: [String]) {
        for key in keys { unsetenv(key) }
    }
}
