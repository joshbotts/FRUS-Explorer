// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalFlowDirection

/// Which way a focused hand-off runs.
enum ArchivalFlowDirection: String, CaseIterable, Identifiable, Sendable {
    /// References *out of* documents drawn from the focus.
    case outgoing
    /// References *into* documents drawn from the focus.
    case incoming

    var id: String { rawValue }

    /// Segment label.
    var title: String {
        switch self {
        case .outgoing:
            return String(localized: "archival.flows.outgoing", defaultValue: "Outgoing")
        case .incoming:
            return String(localized: "archival.flows.incoming", defaultValue: "Incoming")
        }
    }
}

// MARK: - ArchivalFlowLayer

/// Which body of references the Flows diagram is drawing (#784).
///
/// The two layers are the same claim shape — *the editors, annotating material from this
/// collection, sent the reader to that one* — over two different bodies of evidence, and they must
/// never be added together:
///
/// - ``betweenPrinted`` counts references from one **printed** document to another
///   (`provenance-flow-index.json`, #764). Structurally empty before 1945: the `dN` cross-reference
///   idiom postdates the war, and 298 of 552 volumes contribute no edge at all.
/// - ``toUnprinted`` counts references to material FRUS **did not print**
///   (`external-citation-index.json`, #784) — the third body of archival evidence, and the one
///   thing the Flows mode could not previously show.
enum ArchivalFlowLayer: String, CaseIterable, Identifiable, Sendable {
    /// References between two printed documents.
    case betweenPrinted
    /// References to archival material the volume did not print.
    case toUnprinted

    var id: String { rawValue }

    /// Segment label.
    var title: String {
        switch self {
        case .betweenPrinted:
            return String(localized: "archival.flows.layer.printed",
                          defaultValue: "Between printed documents")
        case .toUnprinted:
            return String(localized: "archival.flows.layer.unprinted",
                          defaultValue: "To unprinted material")
        }
    }
}

// MARK: - ArchivalFlowEndpoint

/// One block in the hand-off diagram.
struct ArchivalFlowEndpoint: Identifiable, Sendable, Equatable {
    /// Authority collection id, or ``ArchivalFlowsData/remainderId`` for the folded block.
    let id: String
    /// Display label, disambiguated within the diagram.
    let label: String
    /// The collection's repository, for the block's caption. `nil` on the remainder block.
    let repository: String?
    /// Custodian bucket, which colours the block and its ribbon.
    let category: ArchivalRepositoryCategory
    /// References along this edge.
    let count: Int
    /// Collections folded into this block — zero for a real endpoint.
    let foldedCount: Int

    /// Whether this is the folded remainder rather than one collection.
    var isRemainder: Bool { foldedCount > 0 }
}

// MARK: - ArchivalFlowsData

/// The Flows mode's derivation over the bundled `provenance-flow-index.json` (#764).
///
/// ## Read this before rendering a ribbon
/// **95.3% of these references are footnotes** — 74,146 of 77,792 on the shipped artifact. A
/// ribbon therefore says *the editors, annotating material from this collection, sent the reader
/// to material from that one*. It does **not** say the two archives cite each other. The
/// percentage is recomputed from the artifact's own `coverage` block rather than written down
/// here, so the disclosure cannot go stale against a regenerated index.
///
/// ## Three things the approved design asks for that this data cannot support
/// 1. **The year-range chip.** Verified twice: the artifact's only volume-shaped fields are the
///    two scalars `volumesScanned` and `volumesWithEdges`, and the generator aggregates into a
///    `Pair(from:to:)` that carries the two unit ids and nothing else. A time filter needs a
///    schema-2 regeneration; it is not a view-layer omission.
/// 2. **A class focus.** #764 measured 4,663 between-class references over 2,730 pairs — 1.7 per
///    pair, largest cell 31 — and its own reader says "do not build a class-flow surface on it".
///    There is also nothing to label one with: the design's class-label rider was refuted in the
///    plan of record (2,550 of 2,550 class-keyed children carry a name equal to the class key).
///    So the focus search offers collections only, and the caveat says why.
/// 3. **"Browse these citations in your library."** No query joins `cross_references` to
///    `document_sources`, and `cross_references.reference_type` defaults body-text references to
///    `"footnote"`, so a local browse could not reproduce the split this whole surface is framed
///    around. The flow card offers Archival Neighbors on either endpoint instead — a route that
///    exists and answers a question this data really does support.
///
/// ## The unprinted layer (#784)
/// `ArchivalFlowLayer.toUnprinted` runs the same diagram over `external-citation-index.json` —
/// footnote citations of material FRUS did not print. It answers limitation 1 above only in part:
/// that artifact *is* per-volume, so an era statement is possible, and ``ExternalFacts/eraSpan``
/// makes it. What it cannot do is claim the pre-war reach #784 predicted; see
/// `ExternalCitationIndex`'s own note for the measurement that refutes it.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
///   1.1 — Session 2026-08-10 (#784): the unprinted layer and its disclosures
struct ArchivalFlowsData: Sendable, Equatable {

    /// The id of the folded remainder block.
    static let remainderId = "archival.flows.remainder"

    /// Endpoint blocks drawn before folding begins.
    static let endpointCap = 10

    /// Corpus-wide pairs listed when nothing is focused.
    static let topPairCap = 15

    /// The focused collection, or `nil` for the corpus-wide view.
    let focus: AuthorityCollectionRecord?
    /// The focus's own custodian bucket.
    let focusCategory: ArchivalRepositoryCategory?
    /// Destination (or origin) blocks, heaviest first, with the tail folded into one remainder.
    let endpoints: [ArchivalFlowEndpoint]
    /// Every endpoint, unfolded — what the remainder block expands to.
    let allEndpoints: [ArchivalFlowEndpoint]
    /// References along the drawn edges, remainder included.
    let totalReferences: Int
    /// References from the focus to itself, which the diagram excludes.
    let sameUnitReferences: Int
    /// The corpus-wide heaviest pairs, for the unfocused state.
    let topPairs: [(source: ArchivalFlowEndpoint, target: ArchivalFlowEndpoint)]
    /// Footnote share of all document-to-document references, `0...1`.
    let footnoteShare: Double
    /// Volumes contributing at least one reference.
    let volumesWithEdges: Int
    /// Volumes scanned.
    let volumesScanned: Int
    /// References between two *different* central-file classes across the whole series.
    ///
    /// Read off the artifact rather than written into the caveat, for the same reason the
    /// footnote share is: a regenerated index that changed either figure would leave a
    /// hard-coded sentence quietly wrong.
    let classBetweenReferences: Int
    /// Distinct pairs those references spread over.
    let classBetweenPairs: Int
    /// Which body of references this is (#784). Defaults to the printed layer, so every existing
    /// construction keeps its meaning.
    var layer: ArchivalFlowLayer = .betweenPrinted
    /// The disclosures the unprinted layer owes, or `nil` on the printed layer.
    var externalFacts: ExternalFacts?

    /// What the unprinted layer has to say about itself (#784).
    ///
    /// Every field is read off the artifact rather than written into a sentence, so a regenerated
    /// index cannot leave the copy quietly wrong.
    struct ExternalFacts: Sendable, Equatable {
        /// Archival units named in footnotes, before the authority join.
        let referencesFound: Int
        /// Of those, the ones that resolved to a collection — what the diagram can draw from.
        let referencesJoined: Int
        /// Share whose unit came from an `Ibid.` rather than a phrase of its own, `0...1`.
        let inheritedShare: Double
        /// The coverage years the referencing volumes span, when the manifest supplies them.
        ///
        /// This exists because #784's headline claim — that footnote citations reach 1910–1945 —
        /// **does not survive its own scope**. See `ExternalCitationIndex`'s note: the pre-war
        /// signal is entirely in the decimal-file channel the issue defers. The surface states the
        /// span the data has instead of the one that was predicted.
        let eraSpan: ClosedRange<Int>?
    }

    static func == (lhs: ArchivalFlowsData, rhs: ArchivalFlowsData) -> Bool {
        lhs.focus == rhs.focus && lhs.endpoints == rhs.endpoints
            && lhs.allEndpoints == rhs.allEndpoints && lhs.totalReferences == rhs.totalReferences
            && lhs.sameUnitReferences == rhs.sameUnitReferences
            && lhs.topPairs.map(\.source) == rhs.topPairs.map(\.source)
            && lhs.topPairs.map(\.target) == rhs.topPairs.map(\.target)
            && lhs.footnoteShare == rhs.footnoteShare
            && lhs.layer == rhs.layer && lhs.externalFacts == rhs.externalFacts
    }

    /// Whether there is anything to draw.
    var isEmpty: Bool { endpoints.isEmpty && topPairs.isEmpty }

    // MARK: - Building

    /// Builds the corpus-wide view — the heaviest hand-offs in the series.
    static func corpusWide(index: ProvenanceFlowIndex,
                           authority: CollectionAuthorityIndex) -> ArchivalFlowsData {
        let pairs = index.collectionFlows
            .filter { !$0.isSameUnit }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.source != b.source { return a.source < b.source }
                return a.target < b.target
            }
            .prefix(topPairCap)
            .compactMap { flow -> (ArchivalFlowEndpoint, ArchivalFlowEndpoint)? in
                guard index.collectionIds.indices.contains(flow.source),
                      index.collectionIds.indices.contains(flow.target),
                      let source = authority.record(id: index.collectionIds[flow.source]),
                      let target = authority.record(id: index.collectionIds[flow.target])
                else { return nil }
                return (endpoint(source, count: flow.count),
                        endpoint(target, count: flow.count))
            }

        return ArchivalFlowsData(
            focus: nil, focusCategory: nil, endpoints: [], allEndpoints: [],
            totalReferences: pairs.reduce(0) { $0 + $1.0.count }, sameUnitReferences: 0,
            topPairs: Array(pairs),
            footnoteShare: footnoteShare(index), volumesWithEdges: index.coverage.volumesWithEdges,
            volumesScanned: index.coverage.volumesScanned,
            classBetweenReferences: index.coverage.classes.betweenUnitReferences,
            classBetweenPairs: index.classFlows.count { !$0.isSameUnit })
    }

    /// Builds the focused view.
    static func focused(on focus: AuthorityCollectionRecord, direction: ArchivalFlowDirection,
                        index: ProvenanceFlowIndex,
                        authority: CollectionAuthorityIndex) -> ArchivalFlowsData {
        let raw = direction == .outgoing
            ? index.outgoingFlows(fromCollectionId: focus.id)
            : index.incomingFlows(toCollectionId: focus.id)
        let resolved = raw
            .compactMap { flow -> ArchivalFlowEndpoint? in
                guard let record = authority.record(id: flow.collectionId) else { return nil }
                return endpoint(record, count: flow.count)
            }
        // `outgoingFlows` already sorts heaviest-first, but the id tie-break is what makes the
        // fold reproducible: without it two equal-weight endpoints could swap places between
        // launches and the remainder would hold different collections each time.
        let ordered = disambiguate(resolved.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.id < b.id
        })

        return ArchivalFlowsData(
            focus: focus, focusCategory: ArchivalRepositoryCategory.from(focus),
            endpoints: fold(ordered), allEndpoints: ordered,
            totalReferences: ordered.reduce(0) { $0 + $1.count },
            sameUnitReferences: index.sameUnitReferences(forCollectionId: focus.id),
            topPairs: [], footnoteShare: footnoteShare(index),
            volumesWithEdges: index.coverage.volumesWithEdges,
            volumesScanned: index.coverage.volumesScanned,
            classBetweenReferences: index.coverage.classes.betweenUnitReferences,
            classBetweenPairs: index.classFlows.count { !$0.isSameUnit })
    }

    /// Collections that appear at either end of any between-unit flow, for the focus search.
    ///
    /// Sorted by total references so the search's unfiltered state opens on collections that
    /// actually have something to show, rather than alphabetically on a collection with one
    /// reference.
    static func focusCandidates(index: ProvenanceFlowIndex,
                                authority: CollectionAuthorityIndex)
        -> [(record: AuthorityCollectionRecord, references: Int)] {
        var totals: [Int: Int] = [:]
        for flow in index.collectionFlows where !flow.isSameUnit {
            totals[flow.source, default: 0] += flow.count
            totals[flow.target, default: 0] += flow.count
        }
        return totals
            .compactMap { position, count -> (AuthorityCollectionRecord, Int)? in
                guard index.collectionIds.indices.contains(position),
                      let record = authority.record(id: index.collectionIds[position])
                else { return nil }
                return (record, count)
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.id < b.0.id
            }
    }

    // MARK: - The unprinted layer (#784)

    /// The corpus-wide view over footnote citations of material FRUS did not print.
    static func corpusWideExternal(index: ExternalCitationIndex,
                                   authority: CollectionAuthorityIndex,
                                   entriesById: [String: VolumeManifestEntry]) -> ArchivalFlowsData {
        let pairs = index.heaviestPairs(limit: topPairCap)
            .compactMap { pair -> (ArchivalFlowEndpoint, ArchivalFlowEndpoint)? in
                guard let source = authority.record(id: pair.sourceId),
                      let target = authority.record(id: pair.targetId) else { return nil }
                return (endpoint(source, count: pair.count), endpoint(target, count: pair.count))
            }
        return external(focus: nil, endpoints: [], allEndpoints: [],
                        totalReferences: pairs.reduce(0) { $0 + $1.0.count },
                        sameUnitReferences: 0, topPairs: pairs,
                        index: index, entriesById: entriesById)
    }

    /// The focused view over footnote citations.
    static func focusedExternal(on focus: AuthorityCollectionRecord,
                                direction: ArchivalFlowDirection,
                                index: ExternalCitationIndex,
                                authority: CollectionAuthorityIndex,
                                entriesById: [String: VolumeManifestEntry]) -> ArchivalFlowsData {
        let raw = direction == .outgoing
            ? index.outgoingReferences(fromCollectionId: focus.id)
            : index.incomingReferences(toCollectionId: focus.id)
        let ordered = disambiguate(raw
            .compactMap { reference -> ArchivalFlowEndpoint? in
                guard let record = authority.record(id: reference.collectionId) else { return nil }
                return endpoint(record, count: reference.count)
            }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.id < b.id
            })
        return external(focus: focus, endpoints: fold(ordered), allEndpoints: ordered,
                        totalReferences: ordered.reduce(0) { $0 + $1.count },
                        sameUnitReferences: index.sameUnitReferences(forCollectionId: focus.id),
                        topPairs: [], index: index, entriesById: entriesById)
    }

    /// Collections that appear at either end of any between-unit footnote citation.
    static func externalFocusCandidates(index: ExternalCitationIndex,
                                        authority: CollectionAuthorityIndex)
        -> [(record: AuthorityCollectionRecord, references: Int)] {
        var totals: [String: Int] = [:]
        for pair in index.pairs {
            let sourceId = index.sourceIds[pair.source]
            let targetId = index.targetIds[pair.target]
            guard sourceId != targetId else { continue }
            totals[sourceId, default: 0] += pair.count
            totals[targetId, default: 0] += pair.count
        }
        return totals
            .compactMap { id, count in authority.record(id: id).map { ($0, count) } }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.id < b.0.id
            }
    }

    /// Assembles an unprinted-layer value, so both builders read their disclosures the same way.
    private static func external(focus: AuthorityCollectionRecord?,
                                 endpoints: [ArchivalFlowEndpoint],
                                 allEndpoints: [ArchivalFlowEndpoint],
                                 totalReferences: Int, sameUnitReferences: Int,
                                 topPairs: [(ArchivalFlowEndpoint, ArchivalFlowEndpoint)],
                                 index: ExternalCitationIndex,
                                 entriesById: [String: VolumeManifestEntry]) -> ArchivalFlowsData {
        ArchivalFlowsData(
            focus: focus, focusCategory: focus.map { ArchivalRepositoryCategory.from($0) },
            endpoints: endpoints, allEndpoints: allEndpoints,
            totalReferences: totalReferences, sameUnitReferences: sameUnitReferences,
            topPairs: topPairs,
            // Every reference on this layer is by definition an editor's footnote, so the printed
            // layer's "95.3% are footnotes" caveat does not apply — it is 100% and saying so adds
            // nothing. Zero here means "not the disclosure this layer owes", and the view branches
            // on `layer` rather than on this number.
            footnoteShare: 0,
            volumesWithEdges: index.coverage.volumesWithReferences,
            volumesScanned: index.coverage.volumesScanned,
            classBetweenReferences: 0, classBetweenPairs: 0,
            layer: .toUnprinted,
            externalFacts: ExternalFacts(
                referencesFound: index.coverage.referencesFound,
                referencesJoined: index.coverage.referencesJoined,
                inheritedShare: index.coverage.inheritedShare,
                eraSpan: index.eraSpan(entriesById: entriesById)))
    }

    // MARK: - Helpers

    /// Draws the ten heaviest endpoints and folds the rest into one counted remainder block.
    ///
    /// Shared by both layers, because "no silent truncation" is a property of the diagram, not of
    /// the data behind it.
    static func fold(_ ordered: [ArchivalFlowEndpoint]) -> [ArchivalFlowEndpoint] {
        var drawn = Array(ordered.prefix(endpointCap))
        if ordered.count > endpointCap {
            let tail = ordered.dropFirst(endpointCap)
            drawn.append(ArchivalFlowEndpoint(
                id: remainderId,
                label: String(format: String(localized: "archival.flows.remainder %lld",
                                             defaultValue: "%lld more collections"),
                              Int64(tail.count)),
                repository: nil, category: .otherInstitution,
                count: tail.reduce(0) { $0 + $1.count }, foldedCount: tail.count))
        }
        return drawn
    }

    private static func endpoint(_ record: AuthorityCollectionRecord,
                                 count: Int) -> ArchivalFlowEndpoint {
        ArchivalFlowEndpoint(id: record.id, label: record.name, repository: record.repository,
                             category: ArchivalRepositoryCategory.from(record),
                             count: count, foldedCount: 0)
    }

    /// Makes block labels unique, for the same reason the Network and the Collections ranking do.
    ///
    /// Measured over the 1,111 collections that appear in the flow vocabulary: 16 names are
    /// carried by more than one record, covering 38 nodes. `White House Central Files` is six
    /// distinct blocks, one per repository.
    static func disambiguate(_ endpoints: [ArchivalFlowEndpoint]) -> [ArchivalFlowEndpoint] {
        var seen = Set<String>()
        var repeated = Set<String>()
        for endpoint in endpoints where !seen.insert(endpoint.label).inserted {
            repeated.insert(endpoint.label)
        }
        guard !repeated.isEmpty else { return endpoints }
        var used = Set<String>()
        return endpoints.map { endpoint in
            guard repeated.contains(endpoint.label) else {
                used.insert(endpoint.label)
                return endpoint
            }
            var label = endpoint.label
            if let repository = endpoint.repository { label = "\(endpoint.label) · \(repository)" }
            if used.contains(label) { label = "\(endpoint.label) · \(endpoint.id)" }
            used.insert(label)
            return ArchivalFlowEndpoint(id: endpoint.id, label: label,
                                        repository: endpoint.repository,
                                        category: endpoint.category, count: endpoint.count,
                                        foldedCount: endpoint.foldedCount)
        }
    }

    /// The footnote share, read off the artifact so the disclosure cannot go stale.
    private static func footnoteShare(_ index: ProvenanceFlowIndex) -> Double {
        guard index.coverage.documentEdges > 0 else { return 0 }
        return Double(index.coverage.footnoteEdges) / Double(index.coverage.documentEdges)
    }
}
