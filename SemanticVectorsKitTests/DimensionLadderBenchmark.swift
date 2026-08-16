// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SemanticVectorsKit

/// Times the shipping funnel at 256 and at 512 dimensions, over the real corpus artifacts.
///
/// ## Why this exists
/// The design prices 512 as a recall lever (0.864 against 0.749) and the kernel's header quotes a
/// 1.43 ms scan and a 2.44 ms funnel — **measured at 256, on an M1 Max**. Nothing had measured what
/// doubling the width costs in time, and the decision needs both halves of the trade.
///
/// ## It is skipped unless pointed at artifacts
/// `SEMANTIC_BENCH_256` and `SEMANTIC_BENCH_512` name two directories, each holding a
/// `semantic-vectors-index.json` and a `semantic-vectors-binary.bin`. Absent either, the suite skips
/// — the artifacts are 10–20 MB and the 512 set is not in the repo.
///
/// ## What it measures, and what it deliberately does not
/// The **Hamming scan** and the **candidate selection** — the two passes whose cost is a function of
/// width, and the ones that run for every query on every device regardless of what is downloaded.
/// The int8 rerank is excluded on purpose: it touches only `RERANK_POOL` rows out of 314,483, its
/// cost depends on which shards a device happens to hold, and including it would make the number a
/// property of a library rather than of the width.
///
/// Version history:
///   1.0 — the 256/512 spike
@Suite("Dimension ladder benchmark", .serialized)
struct DimensionLadderBenchmark {

    private struct Artifacts {
        let index: SemanticVectorIndex
        let vectors: SemanticCorpusVectors
        let dims: Int
    }

    private static func load(_ directory: String) throws -> Artifacts {
        let base = URL(fileURLWithPath: directory)
        let data = try Data(contentsOf: base.appending(path: "semantic-vectors-index.json"))
        let file = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self, from: data)
        let index = SemanticVectorIndex(file: file)
        let vectors = try SemanticCorpusVectors(
            contentsOf: base.appending(path: "semantic-vectors-binary.bin"),
            expecting: file.provenance)
        return Artifacts(index: index, vectors: vectors, dims: vectors.dims)
    }

    /// Median and mean of the scan, in milliseconds, over a fixed set of query rows.
    private static func time(_ artifacts: Artifacts, queries: [Int], pool: Int) -> (median: Double, mean: Double) {
        var samples: [Double] = []
        samples.reserveCapacity(queries.count)
        for row in queries {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = SemanticRetrievalKernel.hammingCandidates(
                queryRow: row, in: artifacts.vectors, limit: pool)
            let end = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(end - start) / 1_000_000)
        }
        samples.sort()
        return (samples[samples.count / 2], samples.reduce(0, +) / Double(samples.count))
    }

    @Test("the funnel's width-sensitive half, at both widths")
    func scanCostAtBothWidths() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir256 = env["SEMANTIC_BENCH_256"], let dir512 = env["SEMANTIC_BENCH_512"] else {
            print("[bench] set SEMANTIC_BENCH_256 and SEMANTIC_BENCH_512 to two artifact directories")
            return
        }

        let a256 = try Self.load(dir256)
        let a512 = try Self.load(dir512)
        #expect(a256.dims == 256)
        #expect(a512.dims == 512)
        #expect(a256.vectors.documentCount == a512.vectors.documentCount,
                "the two builds describe different corpora and are not comparable")

        // A fixed, spread sample rather than random rows: the same documents are timed at both
        // widths, so the comparison is not a property of which queries each happened to draw.
        let count = a256.vectors.documentCount
        let queries = stride(from: 0, to: count, by: max(1, count / 600)).map { $0 }
        let pool = 800   // RERANK_POOL, the shipping value

        // One warm pass per width so neither pays the first-touch page-in cost in its samples.
        _ = Self.time(a256, queries: Array(queries.prefix(20)), pool: pool)
        _ = Self.time(a512, queries: Array(queries.prefix(20)), pool: pool)

        let t256 = Self.time(a256, queries: queries, pool: pool)
        let t512 = Self.time(a512, queries: queries, pool: pool)

        print("""
        [bench] corpus \(count) documents, \(queries.count) queries, pool \(pool)
        [bench] 256 dims: median \(String(format: "%.3f", t256.median)) ms, mean \(String(format: "%.3f", t256.mean)) ms
        [bench] 512 dims: median \(String(format: "%.3f", t512.median)) ms, mean \(String(format: "%.3f", t512.mean)) ms
        [bench] ratio (median): \(String(format: "%.2f", t512.median / t256.median))x
        [bench] bytes/row: 256 -> \(a256.vectors.bytesPerRow), 512 -> \(a512.vectors.bytesPerRow)
        """)

        // Not an assertion about speed — a floor against a benchmark that silently measured nothing.
        #expect(t256.median > 0)
        #expect(t512.median > 0)
    }

    @Test("the rerank half, which is linear in width by construction")
    func rerankCostAtBothWidths() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir256 = env["SEMANTIC_BENCH_256"], let dir512 = env["SEMANTIC_BENCH_512"],
              let shards256 = env["SEMANTIC_BENCH_SHARDS_256"],
              let shards512 = env["SEMANTIC_BENCH_SHARDS_512"] else {
            print("[bench] rerank skipped — set SEMANTIC_BENCH_SHARDS_256/512 to the shard directories")
            return
        }

        /// Maps the largest shard in `directory`, so the timing loop has the most rows to work over.
        func openLargest(_ directory: String, provenanceFrom: String) throws -> (SemanticShard, String) {
            let base = URL(fileURLWithPath: provenanceFrom)
            let data = try Data(contentsOf: base.appending(path: "semantic-vectors-index.json"))
            let file = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self, from: data)
            let dir = URL(fileURLWithPath: directory)
            let urls = try FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey])
                .filter { $0.pathExtension == "vec" }
            let biggest = try #require(urls.max {
                (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0
                    < (try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0
            })
            let volumeID = biggest.deletingPathExtension().lastPathComponent
            let expected = file.volumes.first { $0.volumeID == volumeID }?.documentCount
            return (try SemanticShard(contentsOf: biggest, provenance: file.provenance,
                                      expectedDocumentCount: expected), volumeID)
        }

        /// Milliseconds to score `count` rows against one query vector — the rerank's real inner loop.
        func time(_ shard: SemanticShard, count: Int) -> Double {
            guard let query = shard.vector(at: 0) else { return 0 }
            let rows = min(count, shard.documentCount)
            var checksum = 0.0
            let start = DispatchTime.now().uptimeNanoseconds
            for row in 0..<rows {
                checksum += shard.cosine(row: row, query: query.codes, queryScale: query.scale) ?? 0
            }
            let end = DispatchTime.now().uptimeNanoseconds
            // Consume the result so the loop cannot be optimised away.
            #expect(checksum.isFinite)
            return Double(end - start) / 1_000_000
        }

        let (s256, volume) = try openLargest(shards256, provenanceFrom: dir256)
        let (s512, _) = try openLargest(shards512, provenanceFrom: dir512)
        let rows = min(800, s256.documentCount, s512.documentCount)   // RERANK_POOL

        _ = time(s256, count: rows); _ = time(s512, count: rows)      // warm
        var a: [Double] = [], b: [Double] = []
        for _ in 0..<20 { a.append(time(s256, count: rows)); b.append(time(s512, count: rows)) }
        a.sort(); b.sort()

        print("""
        [bench] rerank over \(rows) rows of \(volume)
        [bench] 256 dims: median \(String(format: "%.3f", a[a.count / 2])) ms
        [bench] 512 dims: median \(String(format: "%.3f", b[b.count / 2])) ms
        [bench] ratio (median): \(String(format: "%.2f", b[b.count / 2] / max(a[a.count / 2], 0.0001)))x
        """)
        #expect(a[a.count / 2] >= 0)
    }
}
