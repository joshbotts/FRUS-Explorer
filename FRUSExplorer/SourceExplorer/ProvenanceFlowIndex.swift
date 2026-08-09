// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ProvenanceFlowIndex

/// Where FRUS's editors sent the reader when they cross-referenced one document from another,
/// aggregated to the archival unit each document came from — the bundled `provenance-flow-index.json`
/// (#764).
///
/// ## Read this before rendering a cell
/// **95.3% of these references are footnotes.** Measured on the shipped corpus: 74,146 of 77,792
/// document-to-document references sit in an editor's note, and 3,646 in document body text. A
/// cell therefore says *the editors, annotating material from this collection, pointed the reader
/// at material from that one* — a real and unmapped thing, but **not** "these two archives cite
/// each other". Any surface built on this owes that sentence.
///
/// ## The two axes are not equals
/// - **Collections** (``collectionFlows``): 20,837 references between different collections over
///   4,356 pairs. The heaviest are legible — Nixon NSC Files → Central Files 1970-73 (449),
///   Kennedy National Security File → Central Files (365), the Whitman File and Central Files in
///   both directions (287 / 276).
/// - **Classes** (``classFlows``): 4,663 references between different classes over 2,730 pairs —
///   **1.7 references per pair**, with a largest single cell of 31 that is one wartime file cited
///   two ways (`740.00119` → `740.0011-EW`). There is no head to this distribution: the top 100
///   pairs hold 18.6% of it, against 42.5% on the collection axis.
///
/// The class axis ships as a **measurement, not a feature**. The cause is structural: the `dN`
/// cross-reference idiom does not exist before 1945 — 298 of 552 volumes contribute no edges at
/// all — while the decades that do cross-reference heavily cite lot files and libraries rather
/// than decimal classes. Do not build a class-flow surface on it.
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
struct ProvenanceFlowIndex: Decodable, Sendable {

    /// One ordered (source → target) pair and its reference count.
    struct Flow: Decodable, Sendable {
        /// Index of the source unit in its vocabulary.
        let source: Int
        /// Index of the target unit.
        let target: Int
        /// References running along the pair.
        let count: Int

        /// Whether both ends are the same unit — excluded from display, retained for disclosure.
        var isSameUnit: Bool { source == target }

        enum CodingKeys: String, CodingKey {
            case source = "s"
            case target = "t"
            case count = "n"
        }
    }

    /// What one axis reached.
    struct AxisCoverage: Decodable, Sendable {
        /// References with a unit at both ends.
        let joinedReferences: Int
        /// Of those, references whose ends are the same unit.
        let sameUnitReferences: Int
        /// Distinct ordered pairs stored.
        let pairCount: Int
        /// Distinct units at either end.
        let unitCount: Int

        /// References a flow diagram can actually draw.
        var betweenUnitReferences: Int { joinedReferences - sameUnitReferences }
    }

    /// The funnel from every reference in the corpus down to the joinable edges.
    struct Coverage: Decodable, Sendable {
        /// Volumes scanned.
        let volumesScanned: Int
        /// Volumes contributing at least one edge.
        let volumesWithEdges: Int
        /// Every `<ref target>` harvested.
        let referencesScanned: Int
        /// References inside a document div.
        let referencesInsideDocuments: Int
        /// References resolving to a real document in a manifest volume.
        let documentEdges: Int
        /// Of those, references whose ends share a volume.
        let sameVolumeEdges: Int
        /// Of those, references carried by a footnote rather than body text.
        let footnoteEdges: Int
        /// The collection axis.
        let collections: AxisCoverage
        /// The class axis.
        let classes: AxisCoverage
    }

    /// Artifact schema version.
    let schemaVersion: Int
    /// Generation date stamp.
    let generated: String
    /// Authority collection ids at either end of a collection flow, sorted.
    let collectionIds: [String]
    /// Class keys at either end of a class flow, sorted.
    let classKeys: [String]
    /// Collection-to-collection flows.
    let collectionFlows: [Flow]
    /// Class-to-class flows. Thin by measurement — see the type's note.
    let classFlows: [Flow]
    /// The funnel.
    let coverage: Coverage

    // MARK: - Lookups

    /// References **out of** a collection, to other collections, heaviest first.
    ///
    /// Same-unit flows are excluded, because a collection referencing itself is not a hand-off —
    /// but they are 56% of the joined references, which is why ``Coverage`` keeps the number.
    func outgoingFlows(fromCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = collectionIds.firstIndex(of: id) else { return [] }
        return collectionFlows
            .filter { $0.source == index && !$0.isSameUnit }
            .sorted { $0.count > $1.count }
            .map { (collectionIds[$0.target], $0.count) }
    }

    /// References **into** a collection, from other collections, heaviest first.
    func incomingFlows(toCollectionId id: String) -> [(collectionId: String, count: Int)] {
        guard let index = collectionIds.firstIndex(of: id) else { return [] }
        return collectionFlows
            .filter { $0.target == index && !$0.isSameUnit }
            .sorted { $0.count > $1.count }
            .map { (collectionIds[$0.source], $0.count) }
    }

    /// References from a collection to itself — the number the "between units only" disclosure
    /// has to quote.
    func sameUnitReferences(forCollectionId id: String) -> Int {
        guard let index = collectionIds.firstIndex(of: id) else { return 0 }
        return collectionFlows.first { $0.source == index && $0.target == index }?.count ?? 0
    }
}

// MARK: - ProvenanceFlowIndexStore

/// Loads and caches the bundled `provenance-flow-index.json`.
///
/// `shared` is `nil` only when the resource is missing or cannot be decoded; consumers must treat
/// that as "reference flows are unavailable", never as "this collection references nothing".
///
/// Version history:
///   1.0 — Session 2026-08-08: #764
enum ProvenanceFlowIndexStore {

    /// The bundled flow index, or `nil` when unavailable.
    static let shared: ProvenanceFlowIndex? = load()

    private static func load() -> ProvenanceFlowIndex? {
        guard let url = Bundle.main.url(forResource: "provenance-flow-index",
                                        withExtension: "json") else {
            #if DEBUG
            print("[SourceExplorer] ProvenanceFlowIndexStore: provenance-flow-index.json not found.")
            #endif
            return nil
        }
        do {
            return try JSONDecoder().decode(ProvenanceFlowIndex.self,
                                            from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[SourceExplorer] ProvenanceFlowIndexStore: decode failed — \(error)")
            #endif
            return nil
        }
    }
}
