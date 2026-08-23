// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ClustersAxisTests

/// Pins the Semantic Clusters axis's pure logic (#1051 B-7): ordering, the era
/// mini-histogram, the honesty caption, the digest guard, and — against the LIVE bundled
/// artifacts — the membership enumeration the drill and the capture both ride.
///
/// The membership test drives the REAL reader over a binary built by the REAL packer
/// (`SemanticMapArtifacts.mapBinary`), and then the real bundled artifact — never a
/// hand-rolled byte layout that could agree with the test and disagree with the shipped
/// file.
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
@Suite("Clusters browse axis (#1051 B-7)")
struct ClustersAxisTests {

    private func cluster(id: Int, count: Int,
                         terms: [String] = ["a", "b", "c", "d"],
                         eraCounts: [String: Int] = [:]) -> SemanticMapArtifacts.Cluster {
        .init(id: id, terms: terms, documentCount: count,
              centreX: 0, centreY: 0, eraCounts: eraCounts)
    }

    // MARK: Ordering and labels

    /// Fixture chosen so id order ALONE yields the wrong answer: count-desc must move
    /// cluster 1 last, and only then does the id tiebreak order the tied pair.
    @Test("The index orders largest first, artifact id as the tiebreak")
    func orderedIsLargestFirst() {
        let ordered = ClustersAxis.ordered([
            cluster(id: 1, count: 5), cluster(id: 3, count: 9), cluster(id: 2, count: 9),
        ])
        #expect(ordered.map(\.id) == [2, 3, 1], """
            Got \(ordered.map(\.id)). The labels are machine terms with no alphabetical \
            meaning, so size is the one predictable order — and the tied pair must fall \
            back to artifact id, not stay in input order.
            """)
    }

    @Test("The row label is all four terms; the map-style name is the map's three")
    func labels() {
        let c = cluster(id: 0, count: 1, terms: ["shah", "iran", "iranian", "mosadeq"])
        #expect(ClustersAxis.rowLabel(c) == "shah · iran · iranian · mosadeq")
        #expect(ClustersAxis.mapStyleName(c) == "shah iran iranian",
                "corpus names must match the map's region naming so both save paths read alike")
    }

    // MARK: Era mini-histogram

    @Test("Every era keeps its slot; zero-count eras never peak")
    func eraBarsSlots() {
        let bars = ClustersAxis.eraBars(["1": 3])
        #expect(bars.count == CoverageEra.allCases.count,
                "zero-count eras keep their slot so histograms are positionally comparable")
        #expect(bars.map(\.count) == [0, 3, 0, 0])
        #expect(bars.map(\.isPeak) == [false, true, false, false],
                "a single non-zero bar is the only peak — zero bars must never be accented")
    }

    /// A three-way tie: exactly two peaks, and they go to the EARLIER slots.
    @Test("Peak ties resolve to the earlier era, and only two bars ever peak")
    func eraBarsPeakTies() {
        let bars = ClustersAxis.eraBars(["0": 40, "1": 40, "2": 40])
        #expect(bars.map(\.isPeak) == [true, true, false, false])
        #expect(bars.filter(\.isPeak).count == 2)
    }

    @Test("Non-era keys pool into a trailing bar, and the bars account for every document")
    func eraBarsPooling() {
        let counts = ["0": 5, "unknown": 7]
        let bars = ClustersAxis.eraBars(counts)
        #expect(bars.count == CoverageEra.allCases.count + 1,
                "the pooled bar exists only when the artifact carries non-era keys")
        #expect(bars.last?.era == nil)
        #expect(bars.last?.count == 7)
        #expect(bars.map(\.count).reduce(0, +) == counts.values.reduce(0, +),
                "dropping a key would make the histogram disagree with the row's count")

        #expect(ClustersAxis.eraBars(["0": 5]).count == CoverageEra.allCases.count,
                "no pooled bar when every key is an era")
    }

    // MARK: The honesty caption

    @Test("The caption computes its figures from the artifact, grouping separators included")
    func indexCaption() {
        let caption = ClustersAxis.indexCaption(
            clusterCount: 179, unclusteredCount: 88_207, documentCount: 314_483)
        // Interpolated Ints in String(localized:) localize WITH grouping separators
        // (the B-4 lesson), so the assertions use .formatted() forms.
        #expect(caption.contains(179.formatted()))
        #expect(caption.contains(88_207.formatted()))
        #expect(caption.contains("28.0"), "88,207 of 314,483 is 28.0% to one decimal")
        #expect(caption.contains("not subject headings"),
                "the labels-are-sampled-terms disclosure is mandatory (A-8)")
        #expect(caption.contains("coverage era"),
                "the era disclosure travels with every era histogram (A-8)")
    }

    @Test("A zero-document artifact cannot divide by zero")
    func indexCaptionZeroDenominator() {
        _ = ClustersAxis.indexCaption(clusterCount: 0, unclusteredCount: 0, documentCount: 0)
    }

    // MARK: The digest guard

    /// The never-persist rule's runtime edge: a cluster focus applies only when the
    /// request's digest matches the loaded artifact's.
    @Test("A cluster focus applies only on a digest match")
    func regionFocusDigestGuard() {
        #expect(SemanticMapModel.regionFocusApplies(requestDigest: "abc", artifactDigest: "abc"))
        #expect(!SemanticMapModel.regionFocusApplies(requestDigest: "abc", artifactDigest: "def"),
                "ids re-mint per generation — a stale focus must open the map unfocused, never land on the re-minted cluster")
        #expect(!SemanticMapModel.regionFocusApplies(requestDigest: nil, artifactDigest: "abc"))
        #expect(!SemanticMapModel.regionFocusApplies(requestDigest: "abc", artifactDigest: nil))
    }

    // MARK: Membership enumeration — the real packer, the real reader

    private static let syntheticProvenance = SemanticVectorsArtifacts.Provenance(
        model: "test-model", modelFileSHA256: String(repeating: "0", count: 64),
        nativeDims: 8, shippingDims: 8, chunkChars: 100, overlapChars: 10,
        prefix: "p ", pooling: "mean", quantization: "int8")

    /// Packs a tiny map with the REAL packer, reads it with the REAL reader, and checks
    /// the one-pass enumeration against hand-countable membership — including that the
    /// unclustered marker is refused and an unrepresentable id returns nothing.
    @Test("Membership enumeration agrees with the packed placements")
    func membershipAgainstSyntheticBinary() throws {
        let placements: [SemanticMapArtifacts.Placement] = [
            .init(x: 0, y: 0, cluster: 1),
            .init(x: 1, y: 1, cluster: 0),
            .init(x: 2, y: 2, cluster: 1),
            .init(x: 3, y: 3, cluster: SemanticMapArtifacts.unclustered),
            .init(x: 4, y: 4, cluster: 1),
        ]
        let data = SemanticMapArtifacts.mapBinary(
            placements: placements, clusterCount: 2, gridExtent: 100,
            provenance: Self.syntheticProvenance)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clusters-test-\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let map = try SemanticMapVectors(
            contentsOf: url, provenance: Self.syntheticProvenance, expectedDocumentCount: 5)

        let one = ClustersAxis.membershipRows(in: map, clusterId: 1)
        #expect(one.rows == [0, 2, 4])
        #expect(one.total == 3)

        let zero = ClustersAxis.membershipRows(in: map, clusterId: 0)
        #expect(zero.rows == [1])

        let unclustered = ClustersAxis.membershipRows(
            in: map, clusterId: Int(SemanticMapArtifacts.unclustered))
        #expect(unclustered.rows.isEmpty && unclustered.total == 0,
                "the unclustered marker is not a cluster and must enumerate nothing")

        let unrepresentable = ClustersAxis.membershipRows(in: map, clusterId: 70_000)
        #expect(unrepresentable.rows.isEmpty,
                "an id outside UInt16 must return nothing, not trap in the conversion")
    }

    // MARK: The live bundled artifacts

    private static func bundledMapIndex() throws -> SemanticMapArtifacts.MapIndex {
        let url = try #require(Bundle.main.url(forResource: "semantic-map-index",
                                               withExtension: "json"))
        return try JSONDecoder().decode(SemanticMapArtifacts.MapIndex.self,
                                        from: Data(contentsOf: url))
    }

    /// The partition invariant the caption depends on: every placed document is in
    /// exactly one cluster or unclustered, so the counts must sum exactly.
    @Test("The shipped artifact's cluster counts partition the corpus")
    func shippedArtifactPartitions() throws {
        let index = try Self.bundledMapIndex()
        #expect(!index.clusters.isEmpty)
        let clustered = index.clusters.map(\.documentCount).reduce(0, +)
        #expect(clustered + index.layout.unclusteredCount == index.documentCount, """
            \(clustered) clustered + \(index.layout.unclusteredCount) unclustered != \
            \(index.documentCount) placed. The index caption states all three figures, so \
            a regeneration that broke this identity would ship a self-contradicting screen.
            """)
        #expect(index.clusters.allSatisfy { !$0.terms.isEmpty },
                "a cluster with no terms would render an empty row label")
        let ordered = ClustersAxis.ordered(index.clusters)
        #expect(ordered.count == index.clusters.count, "ordering must not drop a cluster")
        #expect(Set(ordered.map(\.id)).count == ordered.count, "no duplication")
        for cluster in index.clusters {
            let bars = ClustersAxis.eraBars(cluster.eraCounts)
            #expect(bars.map(\.count).reduce(0, +) == cluster.eraCounts.values.reduce(0, +),
                    "cluster \(cluster.id): the histogram must account for every counted document")
        }
    }

    /// The drill's enumeration against the SHIPPED binary: for the largest cluster and
    /// two more, the one-pass scan must find exactly the count the 25KB index states —
    /// the two artifacts describing the same membership is what makes the list level's
    /// counts and the drill's rows the same truth.
    @Test("The shipped binary's membership matches the shipped index's counts")
    func shippedMembershipMatchesCounts() throws {
        let mapIndex = try Self.bundledMapIndex()
        let vectorsURL = try #require(Bundle.main.url(forResource: "semantic-vectors-index",
                                                      withExtension: "json"))
        let vectorsFile = try JSONDecoder().decode(SemanticVectorsArtifacts.Index.self,
                                                   from: Data(contentsOf: vectorsURL))
        #expect(mapIndex.provenanceDigest == vectorsFile.provenanceDigest,
                "the bundled pair must be one generation — mixing is refused at runtime")
        let binURL = try #require(Bundle.main.url(forResource: "semantic-map",
                                                  withExtension: "bin"))
        let map = try SemanticMapVectors(contentsOf: binURL,
                                         provenance: vectorsFile.provenance,
                                         expectedDocumentCount: vectorsFile.documentCount)
        let vectorIndex = SemanticVectorIndex(file: vectorsFile)

        let bysize = ClustersAxis.ordered(mapIndex.clusters)
        let sample = [bysize.first, bysize.dropFirst(bysize.count / 2).first, bysize.last]
            .compactMap { $0 }
        for cluster in sample {
            let found = ClustersAxis.membershipRows(in: map, clusterId: cluster.id)
            #expect(found.total == cluster.documentCount, """
                cluster \(cluster.id): the binary enumerates \(found.total) members but the \
                index states \(cluster.documentCount) — the list level and the drill would \
                show different truths.
                """)
            let keys = ClustersAxis.documentKeys(rows: found.rows, index: vectorIndex)
            #expect(keys.count == found.rows.count,
                    "cluster \(cluster.id): every row must resolve to a document key")
            #expect(keys.allSatisfy { $0.split(separator: "/", maxSplits: 1).count == 2 },
                    "keys must be volumeId/documentId composites")
        }
    }
}

// MARK: - SemanticMapRequestFocusTests

/// Pins the cluster-focus fields added to `SemanticMapRequest` (#1051 B-7).
///
/// Version history:
///   1.0 — #1051 B-7: initial implementation
@Suite("Semantic map request cluster focus (#1051 B-7)")
struct SemanticMapRequestFocusTests {

    @Test("The focus fields round-trip through Codable")
    func focusRoundTrips() throws {
        let request = SemanticMapRequest(
            volumeIDs: nil, scopeLabel: nil,
            lensRawValue: "cluster",
            focusClusterID: 8, focusClusterDigest: "a726ca60")
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SemanticMapRequest.self, from: data)
        #expect(decoded == request)
        #expect(decoded.focusClusterID == 8)
        #expect(decoded.focusClusterDigest == "a726ca60")
    }

    /// A payload written before the fields existed — a restored window from an older
    /// build — must decode with `nil` focus, not fail.
    @Test("An older payload without the focus fields decodes unchanged")
    func olderPayloadDecodes() throws {
        let older = Data(#"{"lensRawValue":"cluster"}"#.utf8)
        let decoded = try JSONDecoder().decode(SemanticMapRequest.self, from: older)
        #expect(decoded.focusClusterID == nil)
        #expect(decoded.focusClusterDigest == nil)
        #expect(decoded.lensRawValue == "cluster")
    }

    /// The focus is part of the window identity, like `focusDocumentKey` — two different
    /// cluster focuses must not be `openWindow`-equal, or the second tap focuses the
    /// first window and appears to do nothing.
    @Test("The focus participates in identity")
    func focusIsIdentity() {
        let base = SemanticMapRequest.wholeCorpus
        let focused = SemanticMapRequest(
            volumeIDs: nil, scopeLabel: nil,
            lensRawValue: SemanticMapLens.cluster.rawValue,
            focusClusterID: 8, focusClusterDigest: "d")
        #expect(base != focused)
        #expect(focused != SemanticMapRequest(
            volumeIDs: nil, scopeLabel: nil,
            lensRawValue: SemanticMapLens.cluster.rawValue,
            focusClusterID: 9, focusClusterDigest: "d"))
    }
}
