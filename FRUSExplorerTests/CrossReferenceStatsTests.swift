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

// MARK: - PageRankTests

/// Unit tests for the pure offline `PageRank` power iteration (CA-6).
struct PageRankTests {

    private func key(_ v: String, _ d: String) -> DocumentNodeKey {
        DocumentNodeKey(volumeId: v, documentId: d)
    }

    @Test("Empty graph returns no scores")
    func emptyGraphGuard() {
        let scores = PageRank.compute(edges: [])
        #expect(scores.isEmpty)
    }

    @Test("Scores sum to ~1 and rank the expected top node on a known hub graph")
    func knownHubGraphRanking() {
        // A → C, B → C, C → A. C is cited by both A and B (in-degree 2), and A is cited
        // by C. Classic small hub: C should have the highest PageRank, then A (fed by the
        // hub C), then B (never cited).
        let a = key("v", "A"), b = key("v", "B"), c = key("v", "C")
        let edges: [(source: DocumentNodeKey, target: DocumentNodeKey)] = [
            (a, c), (b, c), (c, a)
        ]
        let scores = PageRank.compute(edges: edges)

        #expect(scores.count == 3)
        let total = scores.reduce(0.0) { $0 + $1.score }
        #expect(abs(total - 1.0) < 1e-6, "PageRank mass must be conserved at 1")

        // Top node is C (the hub cited by both others).
        #expect(scores.first?.key == c)

        // Ordering C > A > B.
        let byKey = Dictionary(uniqueKeysWithValues: scores.map { ($0.key, $0.score) })
        let sc = try! #require(byKey[c]) as Double
        let sa = try! #require(byKey[a]) as Double
        let sb = try! #require(byKey[b]) as Double
        #expect(sc > sa)
        #expect(sa > sb)
    }

    @Test("Two-node cycle splits mass evenly")
    func symmetricTwoNodeCycle() {
        let a = key("v", "A"), b = key("v", "B")
        let scores = PageRank.compute(edges: [(a, b), (b, a)])
        #expect(scores.count == 2)
        // By symmetry both nodes get 0.5.
        for s in scores {
            #expect(abs(s.score - 0.5) < 1e-4)
        }
    }

    @Test("Dangling node (no out-edges) keeps total mass at 1")
    func danglingNodeMassConservation() {
        // A → B, A → C; B and C are dangling (no out-edges).
        let a = key("v", "A"), b = key("v", "B"), c = key("v", "C")
        let scores = PageRank.compute(edges: [(a, b), (a, c)])
        let total = scores.reduce(0.0) { $0 + $1.score }
        #expect(abs(total - 1.0) < 1e-6, "Dangling mass must be redistributed, not leaked")
        // B and C (cited by A) should each outrank A (never cited).
        let byKey = Dictionary(uniqueKeysWithValues: scores.map { ($0.key, $0.score) })
        #expect((byKey[b] ?? 0) > (byKey[a] ?? 0))
        #expect((byKey[c] ?? 0) > (byKey[a] ?? 0))
    }

    @Test("Deterministic regardless of edge order")
    func deterministicAcrossEdgeOrder() {
        let a = key("v", "A"), b = key("v", "B"), c = key("v", "C")
        let s1 = PageRank.compute(edges: [(a, c), (b, c), (c, a)])
        let s2 = PageRank.compute(edges: [(c, a), (a, c), (b, c)])
        #expect(s1 == s2)
    }
}

// MARK: - CrossReferenceStatsTests

/// Unit tests for the pure degree-distribution bucketing and top-N-volume selection (CA-6).
struct CrossReferenceStatsTests {

    @Test("Degree distribution buckets exact low degrees and groups the tail")
    func degreeDistributionBucketing() {
        // Degrees: three 1s, two 2s, one 5, one 12, one 17, one 23.
        let degrees = [1, 1, 1, 2, 2, 5, 12, 17, 23]
        let buckets = CrossReferenceStats.degreeDistribution(degrees)

        // Exact buckets for 1, 2, 5; a 10–19 bucket (12 and 17); a 20–29 bucket (23).
        let byDegree = Dictionary(uniqueKeysWithValues: buckets.map { ($0.degree, $0) })
        #expect(byDegree[1]?.documentCount == 3)
        #expect(byDegree[1]?.label == "1")
        #expect(byDegree[2]?.documentCount == 2)
        #expect(byDegree[5]?.documentCount == 1)
        #expect(byDegree[10]?.documentCount == 2)   // 12 and 17
        #expect(byDegree[10]?.label == "10–19")
        #expect(byDegree[20]?.documentCount == 1)   // 23
        #expect(byDegree[20]?.label == "20–29")

        // Ordered ascending, no empty buckets.
        #expect(buckets.map(\.degree) == [1, 2, 5, 10, 20])
    }

    @Test("Degree distribution ignores zero/negative and returns empty for empty input")
    func degreeDistributionEdges() {
        #expect(CrossReferenceStats.degreeDistribution([]).isEmpty)
        // Zeroes are dropped (a zero-in-degree doc never appears as a target).
        let buckets = CrossReferenceStats.degreeDistribution([0, 0, 3])
        #expect(buckets.count == 1)
        #expect(buckets.first?.degree == 3)
    }

    @Test("Top-N volumes chosen by total (in + out) degree, ties by id")
    func topVolumesByTotalDegree() {
        // Edges (source → target, count):
        //   A → B (10)   → A total 10, B total 10
        //   B → C (5)    → B total 15, C total 5
        //   C → A (3)    → C total 8,  A total 13
        // Totals: A 13, B 15, C 8. Top 2 → B, A.
        let edges = [
            VolumeConnectionEdge(sourceVolumeId: "A", targetVolumeId: "B", count: 10),
            VolumeConnectionEdge(sourceVolumeId: "B", targetVolumeId: "C", count: 5),
            VolumeConnectionEdge(sourceVolumeId: "C", targetVolumeId: "A", count: 3)
        ]
        let top2 = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: 2)
        #expect(top2 == ["B", "A"])

        let top3 = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: 3)
        #expect(top3 == ["B", "A", "C"])
    }

    @Test("Top-N volume selection handles empty and over-limit gracefully")
    func topVolumesEdgeCases() {
        #expect(CrossReferenceStats.topVolumesByTotalDegree([], limit: 5).isEmpty)
        let edges = [VolumeConnectionEdge(sourceVolumeId: "A", targetVolumeId: "B", count: 1)]
        // Over-limit returns all available.
        let top = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: 10)
        #expect(Set(top) == ["A", "B"])
    }
}
