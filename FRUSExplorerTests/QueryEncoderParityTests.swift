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

/// The gate: the pinned GGUF's local path, or nil to skip the suite. Outside the suite type
/// because a trait that references its own suite is a circular macro reference.
private enum EncoderGate {
    static let modelPath = ProcessInfo.processInfo.environment["FRUS_SEMANTIC_MODEL"]
}

/// The in-app encoder's acceptance gate (V-5 s2): drive `SemanticQueryEncoder` over the 25 judged
/// queries and demand near-exact agreement with the committed reference vectors, which
/// `tools/semantic-harvest/make_query_parity_fixture.py` produced through the `llama-embedding`
/// CLI at the same pinned commit and weights. Same engine, same weights, so the bar is tight
/// (min cosine ≥ 0.9999): a miss is a WRAPPER bug — wrong pooling, missing normalize, wrong
/// prompt, tokenizer misuse — never model drift. Cross-engine parity (LM Studio, whose vectors
/// the judged sitting ranked with) is the spike's separate, measured result.
///
/// GATED on the real model file: set `FRUS_SEMANTIC_MODEL` to the verified GGUF's path — via
/// `TEST_RUNNER_FRUS_SEMANTIC_MODEL=<path>` in the xcodebuild invocation's OWN environment (a
/// trailing KEY=VALUE argument is a build setting and never reaches the test process). Without
/// it the suite records itself skipped rather than passing vacuously; the simulator does not
/// sandbox host paths, so a Mac-side model file works from an iOS-simulator test run.
///
/// This suite is also where s2's IN-APP MEMORY MEASUREMENT lives — the number the step-4 spike
/// could not produce (its 639–861 MB was the CLI harness's shape, called a ceiling on purpose).
///
/// Version history:
///   1.0 — V-5 s2
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
        let queries: [FixtureQuery]
    }

    /// Loads the committed fixture — from the test bundle when enrolled, falling back to the
    /// repo checkout (the simulator can read host paths, and the gated run is host-bound anyway).
    private static func loadFixture() throws -> Fixture {
        let data: Data
        if let url = Bundle(for: BundleAnchor.self)
            .url(forResource: "query-parity-fixture", withExtension: "json") {
            data = try Data(contentsOf: url)
        } else {
            let repo = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
            data = try Data(contentsOf: repo
                .appendingPathComponent("Fixtures/query-parity-fixture.json"))
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
        let fixture = try Self.loadFixture()
        #expect(fixture.queryPrefix == SemanticQueryPrompt.queryPrefix,
                "the fixture and the shared prompt definition must agree before parity means anything")
        // The gate is only meaningful against the pinned weights.
        let modelSHA = try SemanticModelStore.sha256Hex(of: URL(fileURLWithPath: path))
        try #require(modelSHA == fixture.ggufSHA256,
                     "FRUS_SEMANTIC_MODEL points at a file that is not the pinned GGUF")

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
        print("[QueryEncoderParity] \(fixture.queries.count) queries, min cosine \(worst) "
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

    @Test("In-app memory shape: load, encode 25, unload — the s2 measurement")
    func memoryShape() async throws {
        let path = try #require(EncoderGate.modelPath)
        let fixture = try Self.loadFixture()

        let before = Self.physFootprint()
        let encoder = SemanticQueryEncoder()
        try await encoder.load(modelPath: path)
        let afterLoad = Self.physFootprint()

        var first: Int64 = 0
        for (offset, row) in fixture.queries.enumerated() {
            _ = try await encoder.encodeQuery(row.text)
            if offset == 0 { first = Self.physFootprint() }
        }
        let afterAll = Self.physFootprint()
        await encoder.unload()
        let afterUnload = Self.physFootprint()

        let mb = { (value: Int64) in Double(value) / 1_048_576.0 }
        print(String(format: "[QueryEncoderMemory] footprint MB — before %.0f, after load %.0f, "
            + "after first encode %.0f, after 25 encodes %.0f, after unload %.0f",
            mb(before), mb(afterLoad), mb(first), mb(afterAll), mb(afterUnload)))
        // A weak structural bound, not the finding: the finding is the printed figures, which the
        // session records. The spike's CLI ceiling was 861 MB RSS; the in-app shape should sit
        // well under double that even before tuning.
        #expect(afterAll - before < Int64(2) << 30,
                "encode-in-place should not cost 2 GB; if it does, the mmap path regressed")
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
