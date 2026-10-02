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
import WordCloudKit
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

// MARK: - MapPassRefusesBeforeTheVectorsTests

/// #1439: **a map pass that will refuse, refuses before the vector artifacts are written.**
///
/// The map pass runs after the vector pass, because it keys its rows through the index that pass
/// builds. Before #1439 it also made its refusals there, so a run in a process with no lemmatiser
/// (#1373) wrote the new `semantic-vectors-*` artifacts and then stopped, leaving them beside the
/// previous `semantic-map*` ones. `run` now makes every one of those refusals first, through
/// `SemanticMapPacker.preflight`, when `LAYOUT_DIR/layout.bin` exists.
///
/// Each test drives the real `run(environment:languageAnalysis:)` over the two-kilobyte store and
/// a six-byte layout, and requires the refusal AND an output directory that was never created. One
/// fixture per refusal: with the `preflight` call removed, every one of them fails, because the
/// run writes the vectors before the map pass stops it (measured 2026-10-01, macOS host).
///
/// Not serialized, and it needs no `setenv`: the environment is passed in.
///
/// Version history:
///   1.0 — #1439 (lane HYG): initial implementation
@Suite("SemanticVectors — the map pass refuses before the vectors are written (#1439)")
struct MapPassRefusesBeforeTheVectorsTests {

    /// A tagger verdict with no lemmatiser — the #1373 state the map pass refuses on.
    private static let noLemmatiser = NaturalLanguageHealth(
        lemmatizes: false, classifiesWords: true, recognizesNames: true)

    /// Runs the packer over `sandbox` and returns what it threw, if anything.
    private static func run(
        _ sandbox: Fixture.Sandbox, health: NaturalLanguageHealth = .fullyWorking,
        overriding overrides: [String: String] = [:]
    ) -> (any Error)? {
        var environment = sandbox.environment
        for (key, value) in overrides { environment[key] = value }
        do {
            try SemanticVectorsRunner.run(environment: environment, languageAnalysis: { health })
            return nil
        } catch {
            return error
        }
    }

    /// The refusal left no trace: neither output directory was created.
    private static func expectNothingWritten(_ sandbox: Fixture.Sandbox, _ what: String) {
        #expect(!FileManager.default.fileExists(atPath: sandbox.output.path),
                "\(what): the run created its output directory before the map pass refused")
        #expect(!FileManager.default.fileExists(atPath: sandbox.shards.path),
                "\(what): the run wrote shards before the map pass refused")
    }

    /// **The issue's own case.** No lemmatiser, a layout present: the run refuses with the
    /// labeller's error and writes nothing.
    @Test("No lemmatiser and a layout present: the run refuses and writes nothing")
    func noLemmatiserRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout()

        let thrown = Self.run(sandbox, health: Self.noLemmatiser)
        guard case ClusterLabeller.LabelError.languageAnalysisUnavailable? = thrown else {
            Issue.record("expected languageAnalysisUnavailable, got \(String(describing: thrown))")
            return
        }
        Self.expectNothingWritten(sandbox, "no lemmatiser")
    }

    /// The layout's metadata is unreadable.
    @Test("An unreadable layout-meta.json refuses before any write")
    func unreadableMetaRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout(documents: nil)

        let thrown = Self.run(sandbox)
        guard case SemanticMapPacker.PackError.unreadableMeta? = thrown else {
            Issue.record("expected unreadableMeta, got \(String(describing: thrown))")
            return
        }
        Self.expectNothingWritten(sandbox, "unreadable meta")
    }

    /// The layout places a different number of documents than the store's heads add up to.
    @Test("A layout built over another corpus refuses before any write, naming both counts")
    func countMismatchRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout(documents: 2, clusters: [0, 0])

        let thrown = Self.run(sandbox)
        guard case SemanticMapPacker.PackError.storeCountMismatch(let layout, let store)? = thrown else {
            Issue.record("expected storeCountMismatch, got \(String(describing: thrown))")
            return
        }
        #expect(layout == 2)
        #expect(store == 1)
        Self.expectNothingWritten(sandbox, "count mismatch")
    }

    /// The metadata agrees with the store, and `layout.bin` is not that many rows.
    @Test("A layout.bin of the wrong length refuses before any write")
    func sizeMismatchRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout(documents: 1, clusters: [0, 0])

        let thrown = Self.run(sandbox)
        guard case SemanticMapPacker.PackError.layoutSizeMismatch(let expected, let actual)? = thrown else {
            Issue.record("expected layoutSizeMismatch, got \(String(describing: thrown))")
            return
        }
        #expect(expected == 6)
        #expect(actual == 12)
        Self.expectNothingWritten(sandbox, "size mismatch")
    }

    /// Every row is unclustered, so there is nothing to label.
    @Test("A layout with no clusters refuses before any write")
    func noClustersRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout(clusters: [SemanticMapArtifacts.unclustered])

        let thrown = Self.run(sandbox)
        guard case SemanticMapPacker.PackError.noClusters? = thrown else {
            Issue.record("expected noClusters, got \(String(describing: thrown))")
            return
        }
        Self.expectNothingWritten(sandbox, "no clusters")
    }

    /// The labeller's payloads: a missing stopword file and a missing lexicon file, one each.
    @Test("A missing stopword or lexicon payload refuses before any write",
          arguments: ["STOPWORDS", "LEXICONS"])
    func missingPayloadRefusesBeforeAnyWrite(variable: String) throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout()

        let missing = sandbox.root.appendingPathComponent("no-such-payload.json").path
        let thrown = Self.run(sandbox, overriding: [variable: missing])
        #expect(thrown != nil, "a run with no \(variable) payload packed anyway")
        Self.expectNothingWritten(sandbox, "missing \(variable)")
    }

    /// The store lacks a volume the manifest lists. With a layout present the heads are read
    /// before anything is written, so this too stops before the first shard.
    @Test("A manifest volume the store lacks refuses before any write when a layout is present")
    func missingVolumeRefusesBeforeAnyWrite() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout()
        try #"[{"volumeId":"frus1861","subseries":"1861"},{"volumeId":"frus1862","subseries":"1862"}]"#
            .write(to: sandbox.store.url.appendingPathComponent("manifest.json"),
                   atomically: true, encoding: .utf8)

        let thrown = Self.run(sandbox)
        guard case SemanticVectorsRunner.RunError.volumeMissingFromStore(let volume)? = thrown else {
            Issue.record("expected volumeMissingFromStore, got \(String(describing: thrown))")
            return
        }
        #expect(volume == "frus1862")
        Self.expectNothingWritten(sandbox, "missing volume")
    }

    /// **The control, without which every refusal above could be a run that cannot pack at all.**
    /// The same store and the same layout, a working verdict: the vectors and the map are written.
    /// `pack` re-checks this process's own tagger, which lemmatises on the macOS host these
    /// package tests run on (CLAUDE.md, `CloudVectorsGenerator`).
    @Test("With a working tagger and a sound layout the run writes the vectors and the map")
    func soundLayoutPacksTheMap() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }
        try sandbox.writeLayout()

        let thrown = Self.run(sandbox)
        #expect(thrown == nil, "the sound run refused: \(String(describing: thrown))")
        for name in ["semantic-vectors-index.json", "semantic-vectors-binary.bin",
                     "semantic-shards-manifest.json", "semantic-map.bin", "semantic-map-index.json"] {
            #expect(FileManager.default.fileExists(
                atPath: sandbox.output.appendingPathComponent(name).path),
                    "the sound run did not write \(name)")
        }
    }

    /// The vector pack never reads the tagger, so a run with no layout must not ask for the
    /// verdict — asking blocks on the tagger's warm-up, and on a host with no lemmatiser it would
    /// refuse a pack that needs none.
    @Test("With no layout the tagger verdict is never asked for, and a failed one does not stop the vectors")
    func noLayoutNeverAsksTheTagger() throws {
        let sandbox = try Fixture.makeSandbox()
        defer { sandbox.remove() }

        var asked = 0
        try SemanticVectorsRunner.run(environment: sandbox.environment, languageAnalysis: {
            asked += 1
            return Self.noLemmatiser
        })
        #expect(asked == 0, "the run asked for the tagger verdict \(asked) time(s) with no layout to label")
        #expect(FileManager.default.fileExists(
            atPath: sandbox.output.appendingPathComponent("semantic-vectors-index.json").path))
        #expect(!FileManager.default.fileExists(
            atPath: sandbox.output.appendingPathComponent("semantic-map.bin").path),
                "a run with no layout wrote a map")
    }
}

// MARK: - RunWriteOrderTests

/// The order #1439 depends on, pinned where it is written.
///
/// `MapPassRefusesBeforeTheVectorsTests` drives the run, so it sees a refusal that comes late. What
/// it cannot see is the public `run()` handing the driven function something other than this
/// process's own tagger verdict — a constant, say — because the tests supply that argument
/// themselves. Both are read from `SemanticVectorsRunner.swift`, comments removed, each inside the
/// balanced braces of the function it belongs to.
///
/// Version history:
///   1.0 — #1439 (lane HYG): initial implementation
@Suite("SemanticVectors — run order (#1439)")
struct RunWriteOrderTests {

    /// `SemanticVectorsRunner.swift` with every `//` comment removed, so a comment naming a call
    /// is not the call.
    private static func runnerSource() throws -> String {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SemanticVectorsGeneratorCore/SemanticVectorsRunner.swift")
        return try String(contentsOf: path, encoding: .utf8)
            .components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
    }

    /// The body of the function whose declaration begins with `declaration`, braces balanced.
    private static func body(of declaration: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: declaration),
                                 "\(declaration) is no longer declared as expected")
        let open = try #require(source[start.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var close = open
        for index in source[open...].indices {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" { depth -= 1 }
            if depth == 0 { close = index; break }
        }
        try #require(close > open, "\(declaration)'s body never closes")
        return source[open..<close]
    }

    @Test("run() hands the driven run this process's environment and its own tagger verdict")
    func publicRunPassesTheProcessVerdict() throws {
        let body = try Self.body(of: "public static func run() throws", in: Self.runnerSource())
        #expect(body.contains("ProcessInfo.processInfo.environment"))
        #expect(body.contains("languageAnalysis: { NaturalLanguageReadiness.health }"),
                "run() no longer hands the map preflight this process's tagger verdict")
    }

    @Test("The map preflight comes before every write in the run")
    func preflightPrecedesEveryWrite() throws {
        let body = try Self.body(of: "static func run(\n        environment env:", in: Self.runnerSource())
        let preflight = try #require(body.range(of: "try SemanticMapPacker.preflight("),
                                     "the run no longer makes the map pass's refusals first")
        // Every way this function touches the disk. The counts are the function's own, so a new
        // write must be added here, and a scan that stops matching fails instead of passing.
        let writes: [(call: String, count: Int)] = [
            ("createDirectory(", 2), (".write(", 6), ("removeItem(", 1),
        ]
        for (call, count) in writes {
            var sites = 0
            var searched = body[...]
            while let site = searched.range(of: call) {
                sites += 1
                #expect(preflight.upperBound <= site.lowerBound,
                        "the run reaches \(call) before the map pass has made its refusals")
                searched = searched[site.upperBound...]
            }
            #expect(sites == count, "the run has \(sites) \(call) call(s), and this test knows \(count)")
        }
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

    /// A store, plus the directories a run writes to and reads its layout from. Neither output
    /// directory is created here: a refused run must leave them absent.
    struct Sandbox {
        let root: URL
        let store: Store
        var output: URL { root.appendingPathComponent("out") }
        var shards: URL { root.appendingPathComponent("shards") }
        var layout: URL { root.appendingPathComponent("layout") }

        func remove() {
            store.remove()
            try? FileManager.default.removeItem(at: root)
        }

        /// The environment a run over this sandbox reads. The labeller's payloads are the
        /// repository's own, by absolute path, so the run does not depend on the working directory.
        var environment: [String: String] {
            let resources = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Resources")
            return [
                "STORE": store.url.path,
                "MANIFEST": store.url.appendingPathComponent("manifest.json").path,
                "OUTPUT_DIR": output.path,
                "SHARDS_DIR": shards.path,
                "LAYOUT_DIR": layout.path,
                "LEXICONS": resources.appendingPathComponent("word-cloud-lexicons.json").path,
                "STOPWORDS": resources.appendingPathComponent("word-cloud-stopwords.json").path,
                "DIMS": "512",
                "GENERATED_DATE": "2026-10-01",
            ]
        }

        /// Writes a layout: `layout.bin` with one six-byte row per entry of `clusters`, and a
        /// `layout-meta.json` saying it places `documents` documents (`nil` writes no metadata).
        /// The defaults are a sound layout for the one-document store.
        func writeLayout(documents: Int? = 1, clusters: [UInt16] = [0]) throws {
            try FileManager.default.createDirectory(at: layout, withIntermediateDirectories: true)
            var bin = Data(capacity: clusters.count * 6)
            for (row, cluster) in clusters.enumerated() {
                for value in [UInt16(truncatingIfNeeded: row * 10), UInt16(truncatingIfNeeded: row * 20),
                              cluster] {
                    var little = value.littleEndian
                    withUnsafeBytes(of: &little) { bin.append(contentsOf: $0) }
                }
            }
            try bin.write(to: layout.appendingPathComponent("layout.bin"))
            guard let documents else { return }
            let meta: [String: Any] = [
                "documents": documents, "projectedFromDims": 256, "seed": 18_610_810,
                "umap": ["nNeighbors": 15, "minDist": 0.1, "metric": "cosine"],
                "hdbscan": ["minClusterSize": 250, "clusters": 1, "unclustered": 0],
                "grid": ["extent": 30_000.0],
            ]
            try JSONSerialization.data(withJSONObject: meta)
                .write(to: layout.appendingPathComponent("layout-meta.json"))
        }
    }

    static func makeSandbox() throws -> Sandbox {
        Sandbox(root: FileManager.default.temporaryDirectory
                    .appendingPathComponent("frus-guard-run-\(UUID().uuidString)"),
                store: try makeStore())
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
