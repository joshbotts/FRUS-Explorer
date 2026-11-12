// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonCoMentionNode

/// One node in the co-mention ego graph: the focus person or one of their partners (CA-8).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonCoMentionGraphView.swift`, a SwiftUI file,
///          into FRUSCoreKit, public and `Sendable`
public struct PersonCoMentionNode: Identifiable, Equatable, Sendable {
    /// The rollup id (the People-browser identity), unique within the graph.
    public let rollupId: Int
    /// The person's canonical display name.
    public let name: String
    /// Shared-document count with the focus person (`0` for the focus node itself).
    public let sharedWithFocus: Int

    public var id: Int { rollupId }
}

// MARK: - PersonCoMentionEdge

/// One weighted edge in the co-mention ego graph: two rollups sharing `sharedDocuments`
/// documents (CA-8). `a`/`b` are rollup ids; the pair is undirected.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonCoMentionGraphView.swift`, a SwiftUI file,
///          into FRUSCoreKit, public and `Sendable`
public struct PersonCoMentionEdge: Equatable, Sendable {
    /// One endpoint rollup id.
    public let a: Int
    /// The other endpoint rollup id.
    public let b: Int
    /// Distinct documents mentioning both endpoints (the edge weight).
    public let sharedDocuments: Int
}

// MARK: - PersonCoMentionNetwork

/// The co-mention ego network's choice of nodes and edges (CA-8): the focus person, their top
/// `partnerLimit` partners by shared documents, the co-mention edges among those people, and the
/// cap the view discloses — the half of `PersonCoMentionGraphViewModel` that reads the store and
/// decides what the graph holds, without the layout, the labels or the viewport, which stay with
/// the view. A host builds the same network from the same `PersonMentionStore` and draws it as it
/// likes.
///
/// `PersonCoMentionGraphViewModel.load(from:volumeIds:)` calls the two loads in turn, setting what
/// the first gives before it asks for the second, so a failed edge query leaves the nodes in place,
/// as it did when the view model ran both queries itself.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonCoMentionGraphViewModel`
///          (`PersonCoMentionGraphView.swift`, a SwiftUI file): `partnerLimit`, the two halves of
///          `load(from:volumeIds:)`'s reading of the store, the partners' order and the cap's
///          sentence, line for line; the view model's names forward here
public enum PersonCoMentionNetwork {

    /// The disclosed top-N partner cap (decision CA-8-1). Mirrors the volume graph's degree
    /// limits — bounded so the physics and self-join stay fast and the canvas stays legible.
    public static let partnerLimit = 24

    /// The ego's nodes, focus first: the focus person, sharing no documents with themself, then
    /// their top `partnerLimit` partners in the store's order (shared documents, most first, ties
    /// by name), with how many partners a probe capped at `partnerLimit + 1` found.
    ///
    /// That count is a lower bound (#1385): the true count while it is at most `partnerLimit`, and
    /// `partnerLimit + 1` once the cap bites, which is why the disclosure can say "of 25+" and
    /// never the total.
    ///
    /// - Parameters:
    ///   - focusRollupId: The focus person's rollup id.
    ///   - focusName: The focus person's canonical name (the centre node's name).
    ///   - store: The person mention store.
    ///   - volumeIds: The volume scope, or `nil` for the whole corpus (#189-B).
    /// - Returns: The nodes, and the probe's partner count.
    /// - Throws: Either query's error.
    public static func nodes(
        focusRollupId: Int,
        focusName: String,
        store: PersonMentionStore,
        volumeIds: [String]?
    ) async throws -> (nodes: [PersonCoMentionNode], totalPartnerCount: Int) {
        // The disclosed top-N partners (bounded to the focus person's own documents),
        // optionally restricted to the volume scope (#189-B).
        let partnerRows = try await store.topCoMentionedPeople(
            forRollupId: focusRollupId, limit: Self.partnerLimit, volumeIds: volumeIds)
        // A cheap over-limit probe: fetch one more than the cap to know whether the cap
        // actually elided anyone (so the disclosure is accurate), without an unbounded
        // count query.
        let probe = try await store.topCoMentionedPeople(
            forRollupId: focusRollupId, limit: Self.partnerLimit + 1, volumeIds: volumeIds)

        var built: [PersonCoMentionNode] = [
            PersonCoMentionNode(rollupId: focusRollupId, name: focusName, sharedWithFocus: 0)
        ]
        for row in partnerRows {
            built.append(PersonCoMentionNode(rollupId: row.rollupId,
                                             name: row.canonicalName,
                                             sharedWithFocus: row.sharedDocuments))
        }
        return (nodes: built, totalPartnerCount: probe.count)
    }

    /// The edges among `nodes`: partner-partner edges and focus-partner edges, within the bounded
    /// ego set only, each weighted by the documents its two people share.
    ///
    /// - Parameters:
    ///   - nodes: The ego's nodes, as ``nodes(focusRollupId:focusName:store:volumeIds:)`` gives them.
    ///   - store: The person mention store.
    ///   - volumeIds: The volume scope, or `nil` for the whole corpus (#189-B).
    /// - Returns: The edges.
    /// - Throws: The query's error.
    public static func edges(
        among nodes: [PersonCoMentionNode],
        store: PersonMentionStore,
        volumeIds: [String]?
    ) async throws -> [PersonCoMentionEdge] {
        // Partner-partner edges + focus-partner edges, within the bounded ego set only.
        let ids = nodes.map(\.rollupId)
        let edgeRows = try await store.coMentionEdges(amongRollupIds: ids, volumeIds: volumeIds)
        return edgeRows.map { PersonCoMentionEdge(a: $0.a, b: $0.b, sharedDocuments: $0.sharedDocuments) }
    }

    /// Partner nodes (everything but the focus), ordered by shared-document count desc.
    ///
    /// - Parameters:
    ///   - nodes: The ego's nodes.
    ///   - focusRollupId: The focus person's rollup id.
    /// - Returns: The partners, most-shared first, ties by name.
    public static func partners(of nodes: [PersonCoMentionNode], focusRollupId: Int) -> [PersonCoMentionNode] {
        nodes.filter { $0.rollupId != focusRollupId }
            .sorted { $0.sharedWithFocus != $1.sharedWithFocus
                ? $0.sharedWithFocus > $1.sharedWithFocus
                : $0.name < $1.name }
    }

    /// Whether the top-N cap actually elided partners (drives the disclosure text).
    ///
    /// - Parameters:
    ///   - partnerCount: The partners shown.
    ///   - totalPartnerCount: The probe's count.
    public static func capApplied(partnerCount: Int, totalPartnerCount: Int) -> Bool {
        totalPartnerCount > partnerCount
    }

    /// The footer sentence shown while the cap applies (#1385): "Showing the top 24 co-mentioned
    /// people (of 25+) by shared-document count."
    ///
    /// `totalPartnerCount` is the probe's lower bound, so here it always reads `partnerLimit + 1`
    /// and the "+" is the whole of what the view knows: that there are more.
    ///
    /// - Parameters:
    ///   - partnerCount: The partners shown.
    ///   - totalPartnerCount: The probe's count.
    public static func capDisclosure(partnerCount: Int, totalPartnerCount: Int) -> String {
        String(localized: "personCoMention.cap.disclosed",
               defaultValue: "Showing the top \(partnerCount) co-mentioned people (of \(totalPartnerCount)+) by shared-document count.")
    }
}
