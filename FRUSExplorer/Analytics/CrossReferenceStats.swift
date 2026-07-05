// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DocumentNodeKey

/// Stable identity of a document node in the citation graph: `(volumeId, documentId)`.
///
/// A FRUS document is uniquely identified by its volume plus its `xml:id`; the same
/// document number recurs across volumes, so the volume component is load-bearing.
/// Used by `CrossReferenceStore.resolvedCitationEdges()` and `PageRank`.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
public struct DocumentNodeKey: Hashable, Sendable {
    /// The volume containing the document.
    public let volumeId: String
    /// The document's `xml:id` within its volume.
    public let documentId: String

    /// Creates a node key from its volume and document identifiers.
    public init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }
}

// MARK: - DegreeBucket

/// One bar of the degree-distribution histogram: how many documents have a given
/// in-degree (or fall into a given in-degree bucket).
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
public struct DegreeBucket: Identifiable, Equatable, Sendable {
    /// The in-degree value this bucket represents. For low degrees this is the exact
    /// degree (`1`, `2`, …); for the long tail it is the lower bound of a range and
    /// `label` describes the span.
    public let degree: Int
    /// Human-readable x-axis label (e.g. `"1"`, `"2"`, `"10–19"`, `"50+"`).
    public let label: String
    /// Number of documents whose in-degree falls in this bucket.
    public let documentCount: Int

    public var id: Int { degree }

    /// Creates a histogram bucket.
    public init(degree: Int, label: String, documentCount: Int) {
        self.degree = degree
        self.label = label
        self.documentCount = documentCount
    }
}

// MARK: - CrossReferenceStats

/// Pure, view-independent transforms behind `CrossReferenceAnalyticsView`, factored out so
/// the degree-distribution bucketing and the top-N-volume selection can be unit-tested
/// without a SwiftUI host or a live SQLite connection.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
public enum CrossReferenceStats {

    /// Buckets a list of per-document in-degrees into histogram bars.
    ///
    /// Exact degrees `1…exactUpTo` each get their own bucket. Everything above is grouped
    /// into decade-style ranges (`exactUpTo+1 … `) so the long tail of a few heavily-cited
    /// documents doesn't produce hundreds of one-document bars. Documents with an in-degree
    /// of zero are not represented (they never appear as a citation target, so they are not
    /// in the input); the caller need not pass them.
    ///
    /// - Parameters:
    ///   - degrees: One in-degree value per resolved-target document.
    ///   - exactUpTo: The highest degree that gets its own bucket (default 9); higher
    ///     degrees are grouped into `[10,20)`, `[20,30)`, … ranges.
    /// - Returns: Buckets ordered by ascending degree, omitting empty buckets.
    public static func degreeDistribution(_ degrees: [Int], exactUpTo: Int = 9) -> [DegreeBucket] {
        guard !degrees.isEmpty else { return [] }
        var counts: [Int: Int] = [:]      // bucket-key (lower bound) → document count
        var labels: [Int: String] = [:]
        for d in degrees where d > 0 {
            if d <= exactUpTo {
                counts[d, default: 0] += 1
                labels[d] = String(d)
            } else {
                let lower = (d / 10) * 10          // 10, 20, 30, …
                counts[lower, default: 0] += 1
                labels[lower] = "\(lower)–\(lower + 9)"
            }
        }
        return counts.keys.sorted().map { key in
            DegreeBucket(degree: key, label: labels[key] ?? String(key),
                         documentCount: counts[key] ?? 0)
        }
    }

    /// Picks the top-N volumes by **total citation degree** (inbound + outbound ref counts)
    /// from the aggregated volume-to-volume connection edges, for the readable bounded heat
    /// matrix. A full 552×552 grid is unusable, so the matrix is scoped to the most-connected
    /// volumes; the caller discloses the bound (no silent truncation).
    ///
    /// Total degree for a volume = Σ ref_count over every edge where it is the source
    /// **plus** every edge where it is the target. Ties break by volume id for a stable
    /// order.
    ///
    /// - Parameters:
    ///   - edges: Cross-volume connection edges (`volumeLevelConnections`), already excluding
    ///     same-volume edges.
    ///   - limit: N — the number of volumes to keep.
    /// - Returns: The chosen volume ids, ordered by total degree descending then id.
    public static func topVolumesByTotalDegree(
        _ edges: [VolumeConnectionEdge],
        limit: Int
    ) -> [String] {
        var totals: [String: Int] = [:]
        for e in edges {
            totals[e.sourceVolumeId, default: 0] += e.count
            totals[e.targetVolumeId, default: 0] += e.count
        }
        return totals.keys
            .sorted { a, b in
                let ta = totals[a] ?? 0, tb = totals[b] ?? 0
                return ta != tb ? ta > tb : a < b
            }
            .prefix(max(0, limit))
            .map { $0 }
    }
}
