// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// The gate: a GGUF's local path, or nil to skip the suite. Outside the suite type because a
/// trait that references its own suite is a circular macro reference. A path that starts `~/`
/// is read from the test host's home, which on a device is the app's own data container: the one
/// place a test on an iPhone can read a model file, copied there with `xcrun devicectl device
/// copy to … --domain-type appDataContainer --domain-identifier bottsywattsy.FRUS-Explorer`.
private enum EncoderGate {
    static let modelPath = ProcessInfo.processInfo.environment["FRUS_SEMANTIC_MODEL"].map { path in
        path.hasPrefix("~/") ? NSHomeDirectory() + path.dropFirst() : path
    }
}

/// The in-app encoder's acceptance gate (V-5 s2): drive `SemanticQueryEncoder` over the 25 judged
/// queries and demand near-exact agreement with committed reference vectors, which
/// `tools/semantic-harvest/make_query_parity_fixture.py` produced through the `llama-embedding`
/// CLI from the same weights. Same engine, same weights, so the bar is tight (min cosine ≥ 0.999;
/// the comment at the assertion says why not 0.9999): a miss is a WRAPPER bug — wrong pooling,
/// missing normalize, wrong prompt, tokenizer misuse — never model drift. Cross-engine parity (LM
/// Studio, whose vectors the judged sitting ranked with) is the spike's separate, measured result.
///
/// ONE FIXTURE A MODEL, chosen by the model file's SHA-256 (`fixtureNames`). EmbeddingGemma 300m's,
/// the model the app ships, was made at llama.cpp 8663224, the runtime vendored until 2026-10-15;
/// the runtime is a0e6dc7 since then (plan of record B4), so that fixture is now also the check
/// that the rebuild left the shipped model's query vectors where they were. EmbeddingGemma 2's
/// was made at a0e6dc7, for the move to that model (design step 7 of
/// `EmbeddingGemma-2-Spike-2026-10-14.md`). Two of the four tests run in the bundled tier's space
/// and so need the model the tier was embedded with; for any other model, run
/// `parityAgainstFixture()` and `memoryShape()` alone.
///
/// GATED on the real model file: set `FRUS_SEMANTIC_MODEL` to a GGUF's path — via
/// `TEST_RUNNER_FRUS_SEMANTIC_MODEL=<path>` in the xcodebuild invocation's OWN environment (a
/// trailing KEY=VALUE argument is a build setting and never reaches the test process). Without
/// it the suite records itself skipped rather than passing vacuously; the simulator does not
/// sandbox host paths, so a Mac-side model file works from an iOS-simulator test run, and a
/// device reads a `~/` path in the app's container (`EncoderGate`).
///
/// This suite is also where s2's IN-APP MEMORY MEASUREMENT lives — the number the step-4 spike
/// could not produce (its 639–861 MB was the CLI harness's shape, called a ceiling on purpose).
///
/// Version history:
///   1.0 — V-5 s2
///   1.1 — B4, 2026-10-15: a fixture a model, chosen by the GGUF's SHA-256, with EmbeddingGemma
///         2's added; `~/` paths for a device; the two tier-space tests require the tier's model;
///         the memory test also prints its load and encode times
@Suite("Query encoder parity", .enabled(if: EncoderGate.modelPath != nil))
struct QueryEncoderParityTests {

    /// Anchor for locating the test bundle from a struct-based suite.
    private final class BundleAnchor {}

    /// One fixture row.
    private struct FixtureQuery: Decodable {
        let text: String
        let vector: [Double]
    }

    private struct Fixture: Decodable {
        let queryPrefix: String
        let ggufSHA256: String
        /// The `llama-embedding` build the vectors came from, as the fixture script recorded it.
        let referenceEngine: String
        let queries: [FixtureQuery]
    }

    /// The committed fixtures, one a model. Each names the GGUF it was made from in `ggufSHA256`,
    /// and every one holds the same 25 judged queries in the same order.
    private static let fixtureNames = [
        "query-parity-fixture",
        "query-parity-fixture-embeddinggemma-2",
    ]

    /// Loads a committed fixture — from the test bundle when enrolled, falling back to the repo
    /// checkout, which the simulator can read (a device cannot, and reads the bundle's copy).
    private static func loadFixture(named name: String) throws -> Fixture {
        let data: Data
        if let url = Bundle(for: BundleAnchor.self)
            .url(forResource: name, withExtension: "json") {
            data = try Data(contentsOf: url)
        } else {
            let repo = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
            data = try Data(contentsOf: repo
                .appendingPathComponent("Fixtures/\(name).json"))
        }
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, na = 0.0, nb = 0.0
        for index in 0..<min(a.count, b.count) {
            dot += a[index] * b[index]
            na += a[index] * a[index]
            nb += b[index] * b[index]
        }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    @Test("The wrapper reproduces the CLI's vectors for all 25 judged queries")
    func parityAgainstFixture() async throws {
        let path = try #require(EncoderGate.modelPath)
        // The gate is only meaningful against the weights the fixture was made from.
        let modelSHA = try SemanticModelStore.sha256Hex(of: URL(fileURLWithPath: path))
        let fixtures = try Self.fixtureNames.map(Self.loadFixture(named:))
        let fixture = try #require(fixtures.first { $0.ggufSHA256 == modelSHA },
                                   "FRUS_SEMANTIC_MODEL points at a file no committed fixture was made from")
        #expect(fixture.queryPrefix == SemanticQueryPrompt.queryPrefix,
                "the fixture and the shared prompt definition must agree before parity means anything")

        let encoder = SemanticQueryEncoder()
        try await encoder.load(modelPath: path)
        defer { Task { await encoder.unload() } }

        var worst = 1.0
        var worstQuery = ""
        for row in fixture.queries {
            let vector = try await encoder.encodeQuery(row.text)
            #expect(vector.count == row.vector.count)
            let agreement = Self.cosine(vector, row.vector)
            if agreement < worst {
                worst = agreement
                worstQuery = row.text
            }
        }
        print("[QueryEncoderParity] \(URL(fileURLWithPath: path).lastPathComponent) against "
            + "\(fixture.referenceEngine): \(fixture.queries.count) queries, min cosine \(worst) "
            + "(worst: \"\(worstQuery)\")")
        // The bar is 0.999, not 0.9999, and the reason is MEASURED backend skew, not slack: the
        // fixture is a Metal CLI run, the simulator runs CPU (see the encoder's simulator rule),
        // and the CLI DISAGREES WITH ITSELF across those backends at min cosine 0.99987 over
        // these 25 queries (`-ngl 0` re-run, 2026-08-28) — the same magnitude this wrapper shows
        // (0.99986). A wrapper LOGIC bug (wrong pooling, prompt, tokenizer) lands orders of
        // magnitude lower — the simulator-Metal garbage measured cosine ≈ -0.12 — so 0.999
        // separates the two failure classes cleanly while sitting far above the §1a ladder's
        // 0.995 recall-free rung.
        #expect(worst >= 0.999,
                "same engine + same weights must be near-exact; a miss is a wrapper bug")
    }

    @Test("An encoded query enters the shipped funnel and produces candidates")
    @MainActor
    func encodedQueryEntersFunnel() async throws {
        let path = try #require(EncoderGate.modelPath)
        await BundledSemanticVectors.prepare()
        let index = try #require(BundledSemanticVectors.index)
        let corpus = try #require(BundledSemanticVectors.corpusVectors)
        // Another model's query would fill the pool just the same, from the wrong space.
        let modelSHA = try SemanticModelStore.sha256Hex(of: URL(fileURLWithPath: path))
        try #require(modelSHA == index.provenance.modelFileSHA256,
                     "the funnel is the bundled tier's: run this test with the model it was embedded with")

        let encoder = SemanticQueryEncoder()
        try await encoder.load(modelPath: path)
        defer { Task { await encoder.unload() } }

        let embedding = try await encoder.encodeQuery("Why did the Marshall Plan happen?")
        let cut = try #require(SemanticQuantization.truncate(
            embedding, to: index.provenance.shippingDims))
        let bits = SemanticQuantization.packSignBits(cut)
        let pool = index.file.retrieval.rerankPool
        let candidates = SemanticRetrievalKernel.hammingCandidates(
            queryBits: bits, in: corpus, limit: pool)
        #expect(candidates.count == pool,
                "a full-corpus scan with a valid query must fill the pool")
    }

    /// The four footprint points are the whole process's, so read them from a run of this test
    /// alone (`-only-testing …/memoryShape()`): Swift Testing runs a suite's tests in parallel, and
    /// an encoder another test still holds counts here too. Measured 2026-10-15 on the simulator,
    /// with the parity test in the same run: 352 MB before this test's load, against 116–123 alone.
    @Test("In-app memory shape: load, encode 25, unload — the s2 measurement")
    func memoryShape() async throws {
        let path = try #require(EncoderGate.modelPath)
        // Only the query texts are used, and every fixture holds the same 25.
        let fixture = try Self.loadFixture(named: Self.fixtureNames[0])

        let clock = ContinuousClock()
        let before = Self.physFootprint()
        let encoder = SemanticQueryEncoder()
        let loadStart = clock.now
        try await encoder.load(modelPath: path)
        let loadTime = clock.now - loadStart
        let afterLoad = Self.physFootprint()

        var first: Int64 = 0
        var encodeTimes: [Duration] = []
        for (offset, row) in fixture.queries.enumerated() {
            let encodeStart = clock.now
            _ = try await encoder.encodeQuery(row.text)
            encodeTimes.append(clock.now - encodeStart)
            if offset == 0 { first = Self.physFootprint() }
        }
        let afterAll = Self.physFootprint()
        await encoder.unload()
        let afterUnload = Self.physFootprint()

        let mb = { (value: Int64) in Double(value) / 1_048_576.0 }
        let ms = { (value: Duration) in
            Double(value.components.seconds) * 1_000 + Double(value.components.attoseconds) / 1e15
        }
        print(String(format: "[QueryEncoderMemory] %@: footprint MB — before %.0f, after load %.0f, "
            + "after first encode %.0f, after 25 encodes %.0f, after unload %.0f",
            URL(fileURLWithPath: path).lastPathComponent as NSString,
            mb(before), mb(afterLoad), mb(first), mb(afterAll), mb(afterUnload)))
        // The first encode pays the page-in the load skips (no warmup, by design); the median of
        // the other 24 is the warm cost a typed search pays.
        try #require(encodeTimes.count > 1, "the fixture holds the 25 judged queries")
        let warm = encodeTimes.dropFirst().map(ms).sorted()
        print(String(format: "[QueryEncoderLatency] %@: load %.0f ms, first encode %.1f ms, "
            + "warm encode median %.2f ms (min %.2f, max %.2f)",
            URL(fileURLWithPath: path).lastPathComponent as NSString, ms(loadTime), ms(encodeTimes[0]),
            warm[warm.count / 2], warm[0], warm[warm.count - 1]))
        // A weak structural bound, not the finding: the finding is the printed figures, which the
        // session records. The spike's CLI ceiling was 861 MB RSS; the in-app shape should sit
        // well under double that even before tuning.
        #expect(afterAll - before < Int64(2) << 30,
                "encode-in-place should not cost 2 GB; if it does, the mmap path regressed")
    }

    @Test("The whole product path: store-verified model → encoder → searcher → ranked hits")
    func searcherEndToEnd() async throws {
        let path = try #require(EncoderGate.modelPath)
        await BundledSemanticVectors.prepare()
        let index = try #require(await MainActor.run(body: { BundledSemanticVectors.index }))
        let corpus = try #require(await MainActor.run(body: { BundledSemanticVectors.corpusVectors }))
        let modelSHA = try SemanticModelStore.sha256Hex(of: URL(fileURLWithPath: path))
        try #require(modelSHA == index.provenance.modelFileSHA256,
                     "the searcher is the bundled tier's: run this test with the model it was embedded with")

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // The REAL doors, end to end: the model is adopted through the store's verification
        // (length then SHA), and the searcher loads it only through `verifiedModelURL()`.
        let modelStore = SemanticModelStore(
            directory: directory.appendingPathComponent("model"),
            expectedSHA256: index.provenance.modelFileSHA256)
        try await modelStore.adoptModel(from: URL(fileURLWithPath: path))

        let shardStore = SemanticShardStore(
            directory: directory.appendingPathComponent("shards"),
            provenance: index.provenance,
            expectedCounts: Dictionary(
                index.volumes.map { ($0.volumeID, $0.documentCount) },
                uniquingKeysWith: { first, _ in first }))
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let shard = repoRoot.appendingPathComponent(
            "Planning/semantic-vectors/shards/frus1895p1.vec")
        guard FileManager.default.fileExists(atPath: shard.path) else {
            print("[QueryEncoderE2E] local shards absent; end-to-end skipped")
            return
        }
        try await shardStore.adoptShard(from: shard, for: "frus1895p1")

        let searcher = SemanticQuerySearcher(
            index: index, corpus: corpus,
            modelStore: modelStore, shardStore: shardStore,
            requestShardFetch: { _ in false })
        let results = try await searcher.search(
            "Which document related to the Anglo-Venezuelan boundary dispute expanded the Monroe Doctrine?")
        #expect(!results.hits.isEmpty, "the judged query must produce hits through the real encoder")
        #expect(results.hits.allSatisfy { $0.volumeID == "frus1895p1" })
    }

    /// `phys_footprint` — the figure iOS actually terminates on, not RSS.
    private static func physFootprint() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int64(info.phys_footprint) : -1
    }
}
