// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PageRank

/// A pure, bounded, offline PageRank power-iteration over a directed citation graph.
///
/// PageRank estimates each node's steady-state visit probability under a "random surfer"
/// that follows out-edges with probability `damping` and teleports to a uniformly random
/// node with probability `1 - damping`. Applied to FRUS document cross-references it
/// surfaces **landmark documents** — those a citation-following reader keeps returning to.
///
/// This is an *influence* score, not a statement of historical importance or editorial
/// authority: it measures position in the citation graph, nothing more. The view labels it
/// accordingly.
///
/// ## Node & edge definition
/// - **Nodes**: the union of all edge sources and targets (`DocumentNodeKey`).
/// - **Edges**: `(source → target)` document citations, resolved-target only (edges to a
///   NULL target volume are excluded upstream). Repeated citations between the same pair
///   appear as repeated edges, so a heavily-cited pair carries proportionally more weight.
///
/// ## Bounded / offline
/// Standard damping `0.85`, capped at `iterations` (default 100) sweeps, with early exit
/// once the L1 change between successive rank vectors falls below `tolerance` (default
/// `1e-6`). The cap guarantees termination on any graph — including large or cyclic ones —
/// so this never spins. Dangling nodes (no out-edges) have their mass redistributed
/// uniformly each sweep, keeping the total probability mass conserved at 1.
///
/// ## Determinism
/// Iteration order is derived from a sorted node list, so results are deterministic across
/// runs regardless of edge-insertion order.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
public enum PageRank {

    /// The default random-jump probability complement (the "damping factor"). 0.85 is the
    /// value from the original PageRank paper.
    public static let defaultDamping = 0.85

    /// A scored node: its `DocumentNodeKey` and its PageRank value (a probability in `0…1`;
    /// the scores across all nodes sum to ~1).
    public struct ScoredNode: Equatable, Sendable {
        /// The document node.
        public let key: DocumentNodeKey
        /// The PageRank score (steady-state visit probability).
        public let score: Double

        /// Creates a scored node.
        public init(key: DocumentNodeKey, score: Double) {
            self.key = key
            self.score = score
        }
    }

    /// Computes PageRank over the given directed edges.
    ///
    /// - Parameters:
    ///   - edges: Directed `(source, target)` citation edges. The node set is their union.
    ///   - damping: Follow-edge probability (default `0.85`). Teleport probability is
    ///     `1 - damping`.
    ///   - iterations: Hard cap on power-iteration sweeps (default `100`) — the offline
    ///     bound guaranteeing termination.
    ///   - tolerance: Early-exit threshold on the L1 delta between successive rank vectors
    ///     (default `1e-6`).
    /// - Returns: Every node with its score, **sorted by score descending** (ties broken by
    ///   volume then document id). Empty input returns an empty array.
    public static func compute(
        edges: [(source: DocumentNodeKey, target: DocumentNodeKey)],
        damping: Double = defaultDamping,
        iterations: Int = 100,
        tolerance: Double = 1e-6
    ) -> [ScoredNode] {
        guard !edges.isEmpty else { return [] }

        // Assign each node a stable integer index from a sorted key list (determinism).
        var nodeSet: Set<DocumentNodeKey> = []
        for e in edges { nodeSet.insert(e.source); nodeSet.insert(e.target) }
        let nodes = nodeSet.sorted {
            $0.volumeId != $1.volumeId ? $0.volumeId < $1.volumeId : $0.documentId < $1.documentId
        }
        let n = nodes.count
        guard n > 0 else { return [] }
        var indexOf: [DocumentNodeKey: Int] = [:]
        indexOf.reserveCapacity(n)
        for (i, key) in nodes.enumerated() { indexOf[key] = i }

        // Adjacency: for each source, its out-target indices (with multiplicity); out-degree.
        var outTargets: [[Int]] = Array(repeating: [], count: n)
        var outDegree = [Int](repeating: 0, count: n)
        for e in edges {
            guard let s = indexOf[e.source], let t = indexOf[e.target] else { continue }
            outTargets[s].append(t)
            outDegree[s] += 1
        }

        let base = (1.0 - damping) / Double(n)
        var rank = [Double](repeating: 1.0 / Double(n), count: n)

        for _ in 0..<max(1, iterations) {
            var next = [Double](repeating: base, count: n)

            // Dangling mass: rank held by nodes with no out-edges is redistributed uniformly
            // so total probability stays 1 (otherwise it would leak away each sweep).
            var danglingMass = 0.0
            for i in 0..<n where outDegree[i] == 0 { danglingMass += rank[i] }
            let danglingShare = damping * danglingMass / Double(n)

            for i in 0..<n {
                if outDegree[i] > 0 {
                    let contribution = damping * rank[i] / Double(outDegree[i])
                    for t in outTargets[i] { next[t] += contribution }
                }
                next[i] += danglingShare
            }

            // L1 convergence check.
            var delta = 0.0
            for i in 0..<n { delta += abs(next[i] - rank[i]) }
            rank = next
            if delta < tolerance { break }
        }

        let scored = (0..<n).map { ScoredNode(key: nodes[$0], score: rank[$0]) }
        return scored.sorted {
            $0.score != $1.score
                ? $0.score > $1.score
                : ($0.key.volumeId != $1.key.volumeId
                   ? $0.key.volumeId < $1.key.volumeId
                   : $0.key.documentId < $1.key.documentId)
        }
    }
}
