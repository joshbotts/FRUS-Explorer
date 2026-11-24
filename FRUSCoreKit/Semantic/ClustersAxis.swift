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

import Foundation
// SemanticVectorsKit is a module of its own in a package; Xcode compiles its sources into the app
// target (project.yml), where its types are already in this module and the import is compiled out.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

// MARK: - ClustersAxis

/// The Semantic Clusters browse axis's pure logic (#1051 B-7, A-8): ordering, row
/// labels, the era mini-histogram derivation, the honesty caption, and the one-pass
/// membership enumeration — split from the views for testability.
///
/// ## What this axis is, and the disclosures it owes
/// The 172 clusters are HDBSCAN's grouping of the corpus's own language, read from the
/// bundled `semantic-map-index.json`. Three disclosures are mandatory on every surface
/// (the design-requirements A-8 list) and each is a sentence this axis renders:
/// labels are sampled c-TF-IDF terms, **not subject headings**; 92,268 documents
/// (29.3%) belong to no cluster and are unreachable from any cluster list; era
/// histograms bucket each document by its VOLUME's coverage era, not its own date.
/// Every figure is computed from the live artifact — never hard-coded — so a
/// regenerated artifact re-states its own truth.
///
/// ## The durability rule this axis is built around
/// Cluster ids re-mint per artifact generation (168 of 179 labels changed in one
/// regeneration), so an id is valid only against the artifact that minted it. Nothing
/// here persists one: navigation state is in-memory, a saved corpus materializes
/// `"volumeId/documentId"` keys at capture (the `WorkingCorpus` pattern), and the
/// "See on map" cross-link carries the artifact's provenance digest beside the id so
/// a restored window can refuse a focus minted against a different generation.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
///   1.1 — L14 (plan of record decision 124): a document row's Index starts its pass through
///          `AppState.indexWorkInFlight`, so a run of the iOS background task waits for it
///   1.2 — 2026-11-24: FRUS Explorer Light's S28a — moved into FRUSCoreKit out of
///          `ClustersBrowseView.swift`, public, with ``capture(keys:cluster:)`` and
///          ``corpusSourceDescription``, the browse save's, so a host saves a cluster as the app does
public enum ClustersAxis {

    // MARK: Ordering and labels

    /// The index order: largest cluster first, artifact id as the tiebreak.
    ///
    /// The labels are machine terms with no alphabetical meaning and the artifact's id
    /// order is arbitrary layout output, so size is the one axis a reader can predict —
    /// the biggest groupings of the corpus's language come first.
    ///
    /// - Parameter clusters: The artifact's roster.
    /// - Returns: The display order.
    public static func ordered(_ clusters: [SemanticMapArtifacts.Cluster]) -> [SemanticMapArtifacts.Cluster] {
        clusters.sorted {
            if $0.documentCount != $1.documentCount { return $0.documentCount > $1.documentCount }
            return $0.id < $1.id
        }
    }

    /// The row label: all four sampled terms, separated so they read as a term list
    /// rather than a phrase (`shah · iran · iranian · mosadeq`).
    ///
    /// - Parameter cluster: The cluster.
    /// - Returns: The label.
    public static func rowLabel(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        cluster.terms.joined(separator: " · ")
    }

    /// The three-term space-joined form the MAP uses for a region's name — reused for
    /// corpus naming so a set saved here and a set saved on the map read as the same
    /// region in the corpora list.
    ///
    /// - Parameter cluster: The cluster.
    /// - Returns: The map-style name.
    public static func mapStyleName(_ cluster: SemanticMapArtifacts.Cluster) -> String {
        cluster.terms.prefix(3).joined(separator: " ")
    }

    // MARK: Era mini-histogram

    /// One bar of the era mini-histogram.
    public struct EraBar: Equatable, Sendable {
        /// The era, or `nil` for the pooled bucket of non-era keys (the export's
        /// "Undated volumes" rule — rows must sum to the cluster's count).
        public let era: CoverageEra?
        /// Documents in this bucket.
        public let count: Int
        /// Whether this bar is one of the two largest — the design's accented pair.
        public let isPeak: Bool
    }

    /// Derives the mini-histogram: one bar per `CoverageEra` in era order (zero-count
    /// eras keep their slot so every row's histogram is positionally comparable), plus
    /// a trailing pooled bar only when the artifact carries non-era keys. The two
    /// largest non-zero bars are marked as peaks; a tie goes to the earlier slot.
    ///
    /// - Parameter eraCounts: The cluster's `eraCounts`, keyed by `CoverageEra` raw
    ///   value as a string (the artifact's wire form).
    /// - Returns: The bars, oldest era first.
    public static func eraBars(_ eraCounts: [String: Int]) -> [EraBar] {
        var pooled = 0
        var byEra: [CoverageEra: Int] = [:]
        for (key, count) in eraCounts {
            if let raw = Int(key), let era = CoverageEra(rawValue: raw) {
                byEra[era, default: 0] += count
            } else {
                pooled += count
            }
        }
        var slots: [(era: CoverageEra?, count: Int)] = CoverageEra.ordered.map { ($0, byEra[$0] ?? 0) }
        if pooled > 0 { slots.append((nil, pooled)) }
        // The two peaks, by count then earlier slot — indices, so equal counts cannot
        // both win a single peak place.
        let peaks = slots.indices
            .filter { slots[$0].count > 0 }
            .sorted { slots[$0].count != slots[$1].count ? slots[$0].count > slots[$1].count : $0 < $1 }
            .prefix(2)
        return slots.indices.map { i in
            EraBar(era: slots[i].era, count: slots[i].count, isPeak: peaks.contains(i))
        }
    }

    // MARK: The honesty caption

    /// The index-level caption, computed entirely from the live artifact (the design
    /// 1j text with the era disclosure appended — every figure re-states itself after
    /// a regeneration).
    ///
    /// - Parameters:
    ///   - clusterCount: `clusters.count`.
    ///   - unclusteredCount: `layout.unclusteredCount`.
    ///   - documentCount: The artifact's total placed documents.
    /// - Returns: The caption.
    public static func indexCaption(clusterCount: Int, unclusteredCount: Int, documentCount: Int) -> String {
        let percent = documentCount > 0
            ? Double(unclusteredCount) / Double(documentCount) * 100
            : 0
        let percentText = percent.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "browser.clusters.caption",
                      defaultValue: """
                      \(clusterCount) clusters computed from document text. Labels are the most \
                      distinctive sampled terms, not subject headings. \(unclusteredCount) documents \
                      (\(percentText)%) belong to no cluster and cannot be reached from this list. \
                      Era bars reflect each volume's coverage era, not document dates.
                      """)
    }

    // MARK: Membership enumeration

    /// Every artifact row in one cluster, in one pass over the mapped placements.
    ///
    /// Composes the shipped rule (`SemanticMapPicking.rows(inCluster:)` — one
    /// implementation, so the browse drill and the map's capture cannot disagree about
    /// membership) with the raw-pointer read `SemanticMapColouring.scopeMask` uses,
    /// because the obvious alternative — `placement(at:)` per row — re-enters
    /// `withUnsafeBytes` 314,616 times per scan.
    ///
    /// `nonisolated`, deliberately: both inputs are `Sendable` value types over an
    /// mmapped file, so the scan runs off the main actor.
    ///
    /// - Parameters:
    ///   - map: The mapped placements.
    ///   - clusterId: The artifact's cluster id.
    /// - Returns: The rows, ascending (= volume order), and the honest total (equal
    ///   here, since the drill takes every row; the capture cap is applied later, at
    ///   key grain, where the truncation disclosure lives).
    public nonisolated static func membershipRows(
        in map: SemanticMapVectors, clusterId: Int
    ) -> (rows: [Int], total: Int) {
        guard let cluster = UInt16(exactly: clusterId),
              cluster != SemanticMapArtifacts.unclustered else { return ([], 0) }
        return map.withPlacements { base, count in
            SemanticMapPicking.rows(
                inCluster: cluster,
                count: count,
                clusterAt: { row in
                    base.loadUnaligned(
                        fromByteOffset: row * SemanticMapArtifacts.bytesPerDocument + 4,
                        as: UInt16.self).littleEndian
                },
                limit: count)
        }
    }

    /// Materializes rows into `"volumeId/documentId"` keys — the identity that
    /// SURVIVES an artifact regeneration, which is why anything that outlives this
    /// screen (a saved corpus) stores these and never a cluster id.
    ///
    /// - Parameters:
    ///   - rows: Artifact rows, ascending.
    ///   - index: The vector index that keys them.
    /// - Returns: The keys, in row (= volume) order.
    public nonisolated static func documentKeys(rows: [Int], index: SemanticVectorIndex) -> [String] {
        var keys: [String] = []
        keys.reserveCapacity(rows.count)
        for row in rows {
            guard let document = index.document(at: row) else { continue }
            keys.append("\(document.volumeID)/\(document.documentID)")
        }
        return keys
    }

    // MARK: Capture

    /// A cluster's membership as a capture: the keys capped at the record's
    /// ``SemanticMapPicking/corpusCaptureLimit`` budget, the whole count beside them, named by the
    /// map's own form of the region's name, so a set saved here and a set saved on the map read as
    /// the same region in the corpora list.
    ///
    /// - Parameters:
    ///   - keys: Every member's `"volumeId/documentId"` key, in row order.
    ///   - cluster: The cluster.
    /// - Returns: The capture.
    public static func capture(keys: [String], cluster: SemanticMapArtifacts.Cluster) -> SemanticMapPicking.LassoResult {
        SemanticMapPicking.LassoResult(
            documentKeys: Array(keys.prefix(SemanticMapPicking.corpusCaptureLimit)),
            total: keys.count,
            regionNames: [mapStyleName(cluster)])
    }

    /// The source description a cluster's corpus is saved with. No query produced the set, and a
    /// cluster id cannot re-derive it across artifact generations, so the description names the
    /// browse rather than claiming a re-derivable origin.
    public static var corpusSourceDescription: String {
        String(localized: "browser.clusters.corpus.source",
               defaultValue: "Semantic cluster, browsed")
    }
}
