// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// `CollectionKeying` needs no import: SourceNoteKit's sources are compiled directly into the app
// target (project.yml), the same arrangement as FTS5Store and WordCloudKit.
import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ArchivalNetworkNode

/// One node in the co-citation neighbourhood of a focus collection.
struct ArchivalNetworkNode: Identifiable, Sendable, Equatable {

    /// What kind of archival thing the node is. A class is **never** drawn like a collection.
    enum Kind: Sendable, Equatable {
        /// An authority collection — a body of records with a custodian. Drawn as a circle.
        case collection
        /// A central-file class expanded out of the umbrella. Drawn as a rounded square.
        case centralFileClass
    }

    /// Authority collection id, or the class key.
    let id: String
    /// Display label, disambiguated within the graph.
    let label: String
    /// The node's own name before disambiguation.
    let name: String
    /// Circle or square.
    let kind: Kind
    /// Which sector wedge it sits in. Classes take ``ArchivalRepositoryCategory/stateDepartment``,
    /// because a central-file class is a heading inside the Department's own filing system.
    let category: ArchivalRepositoryCategory
    /// Volumes citing both this node and the focus.
    let sharedVolumeCount: Int
    /// Documents the two jointly supplied to those volumes — for each shared volume the smaller of
    /// the two contributions, summed — or `nil` when it is **unknown**: the usage index holds no row
    /// for the focus or for this node, or is not loaded (#1467). A `nil` is never a zero; `0` means
    /// both were counted and no shared volume drew documents from both.
    let sharedDocumentCount: Int?
    /// The active measure's raw value — a Jaccard ratio, or a joint document count.
    let measureValue: Double
    /// The same value as a fraction of the strongest partner's, in `0...1`. This is what the
    /// radius and the threshold slider both read, so the two measures share one geometry.
    let relativeStrength: Double
}

// MARK: - ArchivalNetworkGraph

/// The focus collection's neighbourhood, ranked, capped, and laid out deterministically.
///
/// ## Why there is a cap at all
/// The approved design says hub handling is "overlap-coefficient weighting … no hard cap". That
/// decision assumed the weighting controlled the neighbourhood size. Measured, it does not — see
/// ``ArchivalEdgeMeasure``. Even under the replacement measure, **34.7% of the 1,577 multi-volume
/// records still have more than forty partners** above a quarter of their strongest link, and a
/// 90° wedge cannot hold forty nodes without them overlapping into one another's tap targets.
///
/// So the cap is **per sector**, not global: each custodian gets at most ``sectorCap`` nodes.
/// That is better than a global top-N in the way that matters here — a focus whose neighbourhood
/// is nine-tenths lot files still shows its one presidential library, instead of losing it to
/// thirty-two lot files. ``withheldCount`` is what the surface must state.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
///   1.1 — 2026-10-01: #1437 — `focusLabel`, the focus's name qualified when a node shares it;
///          #1438 — `expansion`, which the Central Files box's caption names
struct ArchivalNetworkGraph: Sendable, Equatable {

    /// Nodes drawn per custodian wedge.
    ///
    /// Six, because the geometry says so: a wedge is 74° of usable arc, and six nodes of up to
    /// 22pt radius are about as many as fit without their 48pt hit targets swallowing each other.
    static let sectorCap = 6

    /// Classes drawn when the umbrella is expanded. They get their own sub-arc inside the State
    /// wedge rather than sharing the collections' — which is also what makes the dashed hull
    /// around them honest, since it can then enclose classes and nothing else.
    static let classCap = 6

    /// The focus record.
    let focus: AuthorityCollectionRecord
    /// The focus's custodian sector.
    let focusCategory: ArchivalRepositoryCategory
    /// Nodes drawn, strongest first.
    let nodes: [ArchivalNetworkNode]
    /// Nodes that passed the threshold, of both kinds — the denominator ``nodes`` is drawn from.
    ///
    /// Counted over the same population as ``nodes``: when the umbrella is expanded its circle is
    /// gone and its classes are in, so both sides move together. The first draft counted classes
    /// in the numerator against a collection-only denominator and could report drawing more
    /// collections than existed.
    let nodesAboveThreshold: Int
    /// Collections sharing at least two volumes with the focus, whatever their strength — the
    /// figure the volume-grain sentence quotes. Independent of the measure and the threshold.
    let partnersTotal: Int
    /// The strongest **drawn** value, which every radius and every ring is a fraction of.
    ///
    /// Computed across collections *and* classes. Normalising classes against a collection-only
    /// maximum let a square exceed 1.0 and clamp: on `Conference Files, Lot 60 D 627` four
    /// classes exceeded the strongest collection, the largest by 76%, and all four drew at
    /// identical radius and identical size on top of the focus disc.
    let strongestMeasureValue: Double
    /// The umbrella record, when it was replaced by classes.
    let expandedUmbrella: AuthorityCollectionRecord?
    /// What the classes drawn in place of the umbrella are — decimal classes or subject-numeric
    /// families — and `.collapsed` when none are drawn. The Central Files box's caption names it.
    var expansion: ArchivalUmbrellaExpansion = .collapsed

    /// The focus's label: its name, qualified by its repository when a drawn node carries the
    /// same name (#1437) — `ArchivalNetworkBuilder.focusLabel(_:nodes:)`.
    var focusLabel: String { ArchivalNetworkBuilder.focusLabel(focus, nodes: nodes) }

    /// Nodes the sector caps withheld.
    var withheldCount: Int { max(nodesAboveThreshold - nodes.count, 0) }
    /// Whether anything was withheld.
    var isCapped: Bool { withheldCount > 0 }
    /// Class squares drawn.
    var classNodeCount: Int { nodes.count { $0.kind == .centralFileClass } }

    /// An empty graph — the honest state for a focus with no co-citing partners.
    static func empty(focus: AuthorityCollectionRecord) -> ArchivalNetworkGraph {
        ArchivalNetworkGraph(focus: focus,
                             focusCategory: ArchivalRepositoryCategory.from(focus),
                             nodes: [], nodesAboveThreshold: 0, partnersTotal: 0,
                             strongestMeasureValue: 0, expandedUmbrella: nil)
    }
}

// MARK: - ArchivalNetworkLayout

/// A caption the network canvas draws — a custodian's name, or the Central Files box's — and the
/// rect reserved for it (#1438, #1470).
struct ArchivalNetworkCaption: Sendable, Equatable {
    /// The text as drawn.
    let text: String
    /// Where it is drawn: the measured text, padded, centred in this rect.
    let rect: CGRect
}

/// Where each node sits, in canvas coordinates.
///
/// Deterministic and physics-free (design direction 2a): the sector is decided by custodian and
/// the radius by strength, so the same focus always draws the same picture and two readers
/// comparing screens are comparing the same thing.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
///   1.1 — 2026-10-01: #1470 — `captions`, each custodian's reserved clear of every node, the
///          class box and its caption; #1438 — `hullCaption`
struct ArchivalNetworkLayout: Sendable, Equatable {
    /// Node id → centre point.
    let positions: [String: CGPoint]
    /// The focus node's centre.
    let center: CGPoint
    /// Radii of the three dashed guide rings, **innermost first** — parallel to
    /// ``ringFractions``, which descends, because a stronger link sits nearer the centre.
    let ringRadii: [CGFloat]
    /// The fraction of the strongest link each ring marks, parallel to ``ringRadii``.
    let ringFractions: [Double]
    /// The bounding radius the wedge tints are filled to.
    let outerRadius: CGFloat
    /// The rectangle enclosing the class squares, when any are drawn — the dashed hull.
    ///
    /// Supplied by the layout rather than derived in the renderer from a bounding box of the
    /// class positions: in a radial layout that box also swallows whatever collection circles
    /// happen to fall inside it, and a hull labelled "Central Files" drawn around a presidential
    /// library is precisely the unit confusion the shapes exist to prevent.
    let classHull: CGRect?
    /// Each custodian's caption, in the corner of its quadrant, reserved where no node, no class
    /// square, no class box and no other caption is drawn (#1470) — see
    /// `ArchivalNetworkBuilder.layout(_:in:captionSize:)`.
    var captions: [ArchivalRepositoryCategory: ArchivalNetworkCaption] = [:]
    /// The class box's caption, above the box, when the box is drawn (#1438).
    var hullCaption: ArchivalNetworkCaption?
}

// MARK: - ArchivalNetworkBuilder

/// Builds a focus collection's neighbourhood and lays it out.
///
/// Every function here is pure over its inputs, so the whole graph is testable without a canvas.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
///   1.1 — 2026-09-24: #1384's label rules — `drawnLabel(_:)` and `markedCut(_:limit:)`, which
///          mark a cut in either half of a disambiguated label; `labelPriority` and
///          `labelRequests`, which the canvas places through `GraphNodeLabels` (the focus's label
///          always, on a plate); and `focusRadius` and `drawnRadius(for:isSelected:)`, the radii
///          the canvas draws and the placement keeps clear of
///   1.2 — 2026-09-25 (#1467): a partner's joint document count is `nil` when either collection
///          has no usage row; `cardDetail(for:focus:usage:)` words the panel sentence after the
///          measure and names the uncounted side, and `exportCells(for:)` leaves its cell empty
///   1.3 — 2026-10-01: #1437 — `disambiguate(_:in:focus:)` qualifies a node that carries the
///          focus's name, `focusLabel(_:nodes:)` the focus, and `identifierKeepingCut(_:limit:)`
///          keeps a trailing lot or file number whole; #1468 — `cardDetail(for:in:usage:)` names
///          the focus through `sentenceName(_:)`; #1470 and #1438 — the layout reserves each
///          caption's rect (`nodeReach(outerRadius:)`), and `labelObstacles(_:)`
enum ArchivalNetworkBuilder {

    /// Volumes a partner must share with the focus before it is a neighbour at all.
    ///
    /// The same floor #762 applies, for the same reason: one shared volume is a coincidence of
    /// compilation, and 2,846 of the shipped records cite one volume.
    static let minimumSharedVolumes = 2

    /// The three guide rings, as fractions of the strongest link.
    static let ringFractions: [Double] = [0.75, 0.50, 0.25]

    /// One candidate before normalisation — the shape both the collection and the class pass
    /// produce, so a single ranking and a single maximum cover both.
    private struct Candidate {
        let id: String
        let name: String
        let kind: ArchivalNetworkNode.Kind
        let category: ArchivalRepositoryCategory
        let shared: Int
        /// The joint document count, `nil` when either side has no usage row (#1467).
        let documents: Int?
        let value: Double
        /// Citing volumes of a collection candidate — the specificity tie-break. Zero for classes.
        let breadth: Int
    }

    // MARK: - Building

    /// The neighbourhood of `focus`.
    ///
    /// - Parameters:
    ///   - focus: The centre of the graph.
    ///   - collections: Every authority record.
    ///   - usage: The bundled usage index, for the document measure and the class expansion.
    ///   - measure: Which strength to rank and place by.
    ///   - minimumRelativeStrength: The threshold slider, as a fraction of the strongest link.
    ///   - expansion: Whether to replace the umbrella node with its co-cited classes.
    static func graph(focus: AuthorityCollectionRecord,
                      in collections: [AuthorityCollectionRecord],
                      usage: CollectionUsageIndex?,
                      measure: ArchivalEdgeMeasure,
                      minimumRelativeStrength: Double,
                      expansion: ArchivalUmbrellaExpansion) -> ArchivalNetworkGraph {
        let focusVolumes = Set(focus.volumeIds)
        guard focusVolumes.count >= minimumSharedVolumes else { return .empty(focus: focus) }
        let focusDocuments = usage?.documentsByVolume(forCollectionId: focus.id) ?? [:]
        // A joint count exists only when BOTH sides are in the usage index (#1467). A missing row
        // read as `[:]` made every shared volume contribute `min(x, 0) = 0`, and the panel then
        // printed that 0 as if it had been measured.
        let focusCounted = usage?.hasRow(forCollectionId: focus.id) ?? false

        var collectionCandidates: [Candidate] = []
        for candidate in collections where candidate.id != focus.id {
            let candidateVolumes = Set(candidate.volumeIds)
            let shared = candidateVolumes.intersection(focusVolumes)
            guard shared.count >= minimumSharedVolumes else { continue }
            let joint: Int?
            if focusCounted, let usage, usage.hasRow(forCollectionId: candidate.id) {
                let candidateDocuments = usage.documentsByVolume(forCollectionId: candidate.id)
                joint = shared.reduce(0) { total, volumeId in
                    total + min(focusDocuments[volumeId] ?? 0, candidateDocuments[volumeId] ?? 0)
                }
            } else {
                joint = nil
            }
            // An unknown count ranks as none under the document measure — it cannot be drawn by a
            // strength it does not have — but still carries its volume-grain strength.
            let value = strength(measure: measure, shared: shared.count,
                                 union: candidateVolumes.union(focusVolumes).count,
                                 joint: joint ?? 0)
            guard value > 0 else { continue }
            collectionCandidates.append(Candidate(
                id: candidate.id, name: candidate.name, kind: .collection,
                category: ArchivalRepositoryCategory.from(candidate),
                shared: shared.count, documents: joint, value: value,
                breadth: candidateVolumes.count))
        }
        // Counted before any threshold or measure is applied, so the volume-grain sentence quotes
        // a number that does not move when the reader changes the measure.
        let partnersTotal = collections.count { candidate in
            candidate.id != focus.id
                && Set(candidate.volumeIds).intersection(focusVolumes).count >= minimumSharedVolumes
        }

        let expandsUmbrella = expansion != .collapsed
            && collectionCandidates.contains { $0.id == ArchivalCollectionsData.umbrellaCollectionId }
        let classCandidates = expandsUmbrella && usage != nil
            ? classes(focusVolumes: focusVolumes, focusDocuments: focusDocuments,
                      focusCounted: focusCounted, usage: usage!, expansion: expansion,
                      measure: measure)
            : []

        // The maximum spans BOTH kinds, so a square and a circle at the same radius mean the
        // same thing — which is the whole justification for putting them on one radial axis.
        let visible = classCandidates.isEmpty
            ? collectionCandidates
            : collectionCandidates.filter { $0.id != ArchivalCollectionsData.umbrellaCollectionId }
                + classCandidates
        guard let strongest = visible.map(\.value).max(), strongest > 0 else {
            return ArchivalNetworkGraph(
                focus: focus, focusCategory: ArchivalRepositoryCategory.from(focus), nodes: [],
                nodesAboveThreshold: 0, partnersTotal: partnersTotal, strongestMeasureValue: 0,
                expandedUmbrella: nil)
        }

        // One threshold, one ranking, both kinds. The first draft filtered only collections, so
        // the slider governed half the graph: measured, 23 of the 40 most-cited foci drew class
        // squares below their own threshold at the default setting.
        let ranked = visible
            .filter { $0.value / strongest >= minimumRelativeStrength }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                if a.shared != b.shared { return a.shared > b.shared }
                if a.breadth != b.breadth { return a.breadth < b.breadth }
                if a.name != b.name { return a.name < b.name }
                return a.id < b.id
            }

        // Per-sector caps, applied after ranking so each wedge keeps its strongest.
        var perSector: [ArchivalRepositoryCategory: Int] = [:]
        var classesDrawn = 0
        var drawn: [Candidate] = []
        for candidate in ranked {
            if candidate.kind == .centralFileClass {
                guard classesDrawn < ArchivalNetworkGraph.classCap else { continue }
                classesDrawn += 1
            } else {
                let used = perSector[candidate.category] ?? 0
                guard used < ArchivalNetworkGraph.sectorCap else { continue }
                perSector[candidate.category] = used + 1
            }
            drawn.append(candidate)
        }

        let nodes = drawn.map { candidate in
            ArchivalNetworkNode(
                id: candidate.id, label: candidate.name, name: candidate.name,
                kind: candidate.kind, category: candidate.category,
                sharedVolumeCount: candidate.shared, sharedDocumentCount: candidate.documents,
                measureValue: candidate.value,
                relativeStrength: min(candidate.value / strongest, 1))
        }
        // The umbrella is reported as expanded only when a class actually survived to replace it.
        // Otherwise its circle stays, rather than the reader losing a collection that passed the
        // threshold to an expansion that produced nothing.
        let umbrella = classesDrawn > 0
            ? collections.first { $0.id == ArchivalCollectionsData.umbrellaCollectionId }
            : nil

        return ArchivalNetworkGraph(
            focus: focus, focusCategory: ArchivalRepositoryCategory.from(focus),
            nodes: disambiguate(nodes, in: collections, focus: focus),
            nodesAboveThreshold: ranked.count, partnersTotal: partnersTotal,
            strongestMeasureValue: strongest, expandedUmbrella: umbrella,
            expansion: classesDrawn > 0 ? expansion : .collapsed)
    }

    // MARK: - Words for one link (#1467)

    /// The sentence the selected-node panel prints under a partner's name.
    ///
    /// It used to read "…; together they supplied 0 documents to those volumes" whenever either
    /// collection had no row in the usage index — a zero the index never measured. The node for the
    /// repository-less Whitman File said it beside Lot 62 D 1, although the Whitman File's documents
    /// were counted all along, under the Eisenhower Library's record. And "together" read as the two
    /// collections' documents added up, which the measure is not. So the sentence now says which
    /// side is uncounted when the count is unknown, and words a measured count as what it is — per
    /// shared volume, the smaller of the two contributions, summed.
    ///
    /// - Parameters:
    ///   - node: The selected partner.
    ///   - graph: The graph it is drawn in: the focus it names, by `focusLabel` (#1437) and through
    ///     `sentenceName(_:)` (#1468).
    ///   - usage: The usage index the graph was built against — it decides which side is uncounted.
    ///
    /// The volume phrase goes through `CountCopy`; its verb is always the plural "cite", because a
    /// partner shares at least ``minimumSharedVolumes`` (two) volumes with the focus or it is not a
    /// node at all.
    static func cardDetail(for node: ArchivalNetworkNode, in graph: ArchivalNetworkGraph,
                           usage: CollectionUsageIndex?) -> String {
        let volumes = CountCopy.volumes(node.sharedVolumeCount)
        let focus = sentenceName(graph.focusLabel)
        if let documents = node.sharedDocumentCount {
            return String(format: String(
                localized: "archival.network.card.detail.counted %@ %@ %@",
                defaultValue: "%1$@ cite both this and %2$@. In those volumes the two jointly supplied %3$@ — for each volume, the smaller of their two document counts, summed."),
                volumes, focus, CountCopy.documents(documents))
        }
        guard let usage else {
            return String(format: String(
                localized: "archival.network.card.detail.noIndex %@ %@",
                defaultValue: "%1$@ cite both this and %2$@. The documents they supplied are not counted, because the document-usage index could not be loaded."),
                volumes, focus)
        }
        if !usage.hasRow(forCollectionId: graph.focus.id) {
            return String(format: String(
                localized: "archival.network.card.detail.focusUncounted %@ %@",
                defaultValue: "%1$@ cite both this and %2$@. No document source note resolves to %2$@, so the documents the two supplied are not counted."),
                volumes, focus)
        }
        return String(format: String(
            localized: "archival.network.card.detail.partnerUncounted %@ %@",
            defaultValue: "%1$@ cite both this and %2$@. No document source note resolves to this collection, so the documents it supplied are not counted."),
            volumes, focus)
    }

    /// The most characters a collection's name keeps inside one of the panel's sentences (#1468).
    ///
    /// The detail sentence named the focus in full, so with Indexed Central Files at the centre it
    /// ran to 570 pt in an iPhone's portrait dock (measured for decision D11). Eighty characters
    /// keep a name whole in 3,635 of the shipped authority's 4,051 records.
    static let sentenceNameLimit = 80

    /// A collection's name as the panel's sentences print it (#1468): whole up to
    /// ``sentenceNameLimit`` characters, otherwise cut at a word boundary and marked with "…"
    /// (`GraphNodeLabels.shortLabel(_:limit:)`). The selected node's heading shows the name whole
    /// up to three lines, and in its `.help` and accessibility label.
    /// - Parameter name: A collection's name or label.
    /// - Returns: The name as a sentence prints it.
    static func sentenceName(_ name: String) -> String {
        GraphNodeLabels.shortLabel(name, limit: sentenceNameLimit)
    }

    /// One exported row of the drawn neighbourhood: unit, kind, custodian, shared volumes, jointly
    /// supplied documents, share of the strongest link. The document cell is **empty** when the count
    /// is unknown (#1467) — a spreadsheet reads a `0` as a measurement.
    static func exportCells(for node: ArchivalNetworkNode) -> [String] {
        [node.label,
         node.kind == .collection
            ? String(localized: "archival.network.kind.collection", defaultValue: "collection")
            : String(localized: "archival.network.kind.class",
                     defaultValue: "central-file class"),
         node.category.displayName,
         "\(node.sharedVolumeCount)",
         node.sharedDocumentCount.map { "\($0)" } ?? "",
         node.relativeStrength.formatted(.percent.precision(.fractionLength(0)))]
    }

    /// One edge's raw strength under the active measure.
    private static func strength(measure: ArchivalEdgeMeasure, shared: Int, union: Int,
                                 joint: Int) -> Double {
        switch measure {
        case .sharedVolumes: return Double(shared) / Double(max(union, 1))
        case .sharedDocuments: return Double(joint)
        }
    }

    /// The central-file classes co-cited with the focus.
    ///
    /// Counts are accumulated **per volume before the `min`**, not per leaf key. Folding
    /// subject-numeric leaves and taking one `min` each let a group claim more jointly-supplied
    /// documents than the focus contributed to that volume at all — `POL 27 VIET S` and
    /// `POL 27 ARAB-ISR` in the same volume each took their own `min` against the same focus
    /// contribution and the two were then added.
    ///
    /// A class's own row always exists — the candidates come from the index — so its joint count
    /// is unknown only when the focus has no row (`focusCounted`, #1467).
    private static func classes(focusVolumes: Set<String>, focusDocuments: [String: Int],
                                focusCounted: Bool, usage: CollectionUsageIndex,
                                expansion: ArchivalUmbrellaExpansion,
                                measure: ArchivalEdgeMeasure) -> [Candidate] {
        guard expansion != .collapsed else { return [] }
        var classDocumentsByVolume: [String: [String: Int]] = [:]
        var unionVolumes: [String: Set<String>] = [:]
        for key in usage.classKeys {
            let isSubjectNumeric = CollectionKeying.isSubjectNumericClass(key)
            if expansion == .decimalClasses, isSubjectNumeric { continue }
            if expansion == .subjectNumeric, !isSubjectNumeric { continue }
            // Subject-numeric keys fold to category + number: at leaf grain half of them carry a
            // single document and the lens is unrankable (#763's D-3 measurement).
            let label = expansion == .subjectNumeric
                ? (CollectionKeying.subjectNumericGroup(key) ?? key)
                : key
            for (volumeId, count) in usage.documentsByVolume(forClassKey: key) {
                unionVolumes[label, default: []].insert(volumeId)
                guard focusVolumes.contains(volumeId) else { continue }
                classDocumentsByVolume[label, default: [:]][volumeId, default: 0] += count
            }
        }

        return classDocumentsByVolume.compactMap { label, byVolume -> Candidate? in
            guard byVolume.count >= minimumSharedVolumes else { return nil }
            let joint = byVolume.reduce(0) { total, entry in
                total + min(focusDocuments[entry.key] ?? 0, entry.value)
            }
            let union = unionVolumes[label]?.union(focusVolumes).count ?? focusVolumes.count
            let value = strength(measure: measure, shared: byVolume.count, union: union,
                                 joint: joint)
            guard value > 0 else { return nil }
            return Candidate(id: "class:\(label)", name: label, kind: .centralFileClass,
                             category: .stateDepartment, shared: byVolume.count,
                             documents: focusCounted ? joint : nil, value: value, breadth: 0)
        }
    }

    /// Makes labels unique within the graph, the focus's included (#1437).
    ///
    /// Measured on the shipped authority, 17 names are carried by more than one record among the
    /// 1,108 that appear in the flow vocabulary alone — `White House Central Files` is six
    /// distinct nodes across six repositories. Two identically-labelled circles in the same
    /// sector are indistinguishable, and the reader has no way to tell which one they tapped.
    ///
    /// A node that carries the FOCUS's name is qualified too. Before #1437 the focus was never
    /// compared, so the Whitman File at the centre drew a partner labelled "Whitman File" — the
    /// repository-less record two microfiche supplements cite — and the reader could take it for a
    /// collection linked to itself. Such a node is qualified by its repository as any repeated
    /// name is, and the focus by its own (`focusLabel(_:nodes:)`), which is what tells the two
    /// apart when the node has none. The focus's label is taken first, so no node is given it.
    /// - Parameters:
    ///   - nodes: The drawn nodes, strongest first.
    ///   - collections: Every authority record, for the repositories.
    ///   - focus: The graph's focus.
    /// - Returns: The nodes, each with a label no other node and not the focus draws.
    static func disambiguate(_ nodes: [ArchivalNetworkNode],
                             in collections: [AuthorityCollectionRecord],
                             focus: AuthorityCollectionRecord)
        -> [ArchivalNetworkNode] {
        var seen: Set<String> = [focus.name]
        var repeated = Set<String>()
        for node in nodes where !seen.insert(node.name).inserted { repeated.insert(node.name) }
        guard !repeated.isEmpty else { return nodes }
        var records: [String: AuthorityCollectionRecord] = [:]
        for record in collections where repeated.contains(record.name) { records[record.id] = record }
        var used: Set<String> = [focusLabel(focus, nodes: nodes)]
        return nodes.map { node in
            guard repeated.contains(node.name) else {
                used.insert(node.label)
                return node
            }
            var label = node.name
            if let repository = records[node.id]?.repository {
                label = "\(node.name) · \(repository)"
            }
            if used.contains(label) { label = "\(node.name) · \(node.id)" }
            used.insert(label)
            return ArchivalNetworkNode(
                id: node.id, label: label, name: node.name, kind: node.kind,
                category: node.category, sharedVolumeCount: node.sharedVolumeCount,
                sharedDocumentCount: node.sharedDocumentCount, measureValue: node.measureValue,
                relativeStrength: node.relativeStrength)
        }
    }

    /// The focus's label (#1437): its name, or `name · repository` when a node in `nodes` carries
    /// the same name and the focus has a repository. A focus with none keeps its bare name, which
    /// no same-named node then draws: `disambiguate(_:in:focus:)` qualifies each of them, by its
    /// repository or else by its id.
    /// - Parameters:
    ///   - focus: The graph's focus.
    ///   - nodes: The nodes drawn around it.
    /// - Returns: The label the centre is drawn and named with.
    static func focusLabel(_ focus: AuthorityCollectionRecord, nodes: [ArchivalNetworkNode]) -> String {
        guard let repository = focus.repository, nodes.contains(where: { $0.name == focus.name })
        else { return focus.name }
        return "\(focus.name) · \(repository)"
    }

    // MARK: - Layout

    /// Places every node in a canvas of the given size, and reserves the captions' space (#1470).
    ///
    /// Sector by custodian, radius by strength, angle by rank within the sector — no physics, so
    /// the picture is reproducible. Class squares take their own sub-arc at the trailing end of
    /// the State wedge, which both keeps them off the State collections and lets the hull that
    /// names them enclose nothing else.
    ///
    /// ## Captions (#1470, owner decision D12)
    /// Each custodian's caption was drawn first, at 45° into its wedge and 0.93 × the outer radius,
    /// where the layout also puts nodes: a wedge with an odd number of nodes puts one on that
    /// diagonal, and a weak node sits near the outer ring. On a small canvas the discs, the class
    /// squares and the dashed box drawn after it covered it. The captions stay on the bottom layer
    /// and their space is reserved instead — but not inside the wedge, which cannot hold it. A
    /// caption runs horizontally, 78–119 pt wide at 9 pt (measured on the Mac); at 390 × 300, where
    /// a wedge's outer radius is 106 pt, the 119 pt one on its diagonal comes within the clearance
    /// of a node of the default threshold's weakest strength anywhere from 32° into the wedge to its
    /// far edge at 82° (computed from the layout's constants), so a gap in the node arc that cleared
    /// it would leave the nodes 24° of the wedge's 74°. So each caption goes in the corner of its
    /// own quadrant, beyond every node: on the ray from
    /// the centre toward the canvas corner, at the first point where it keeps
    /// `GraphNodeLabels.clearance` from the farthest a node can reach (`nodeReach(outerRadius:)`),
    /// from the class box and its caption, and from the captions reserved before it, kept inside
    /// the canvas. Where no point on the ray clears all of them — a canvas too small to — it takes
    /// the point that comes closest. Its rect is then an obstacle the node labels keep clear of
    /// (#1438, `labelObstacles(_:)`).
    /// - Parameters:
    ///   - graph: The graph to lay out.
    ///   - size: The canvas.
    ///   - captionSize: The size a caption's text draws at; `measuredCaptionSize(_:)` unless a test
    ///     passes an estimate.
    /// - Returns: The layout.
    static func layout(_ graph: ArchivalNetworkGraph, in size: CGSize,
                       captionSize: (String) -> CGSize = measuredCaptionSize) -> ArchivalNetworkLayout {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = max(min(size.width, size.height) / 2 - 44, 60)
        let inner = min(70, outer * 0.35)

        var positions: [String: CGPoint] = [graph.focus.id: center]
        // Wedge order matches the design's compass: State NW, lots NE, libraries SE, other SW.
        // Screen y grows downward, so "north" is the negative half.
        let wedgeStart: [ArchivalRepositoryCategory: Double] = [
            .stateDepartment: 180, .lotFile: 270, .presidentialLibrary: 0, .otherInstitution: 90,
        ]
        let inset = 8.0
        let usableSpan = 90.0 - 2 * inset

        func place(_ nodes: [ArchivalNetworkNode], from start: Double, span: Double) {
            guard !nodes.isEmpty else { return }
            let step = nodes.count == 1 ? 0 : span / Double(nodes.count - 1)
            for (index, node) in nodes.enumerated() {
                let degrees = start + (nodes.count == 1 ? span / 2 : step * Double(index))
                let radians = degrees * .pi / 180
                let radius = inner + CGFloat(1 - node.relativeStrength) * (outer - inner)
                positions[node.id] = CGPoint(x: center.x + cos(radians) * radius,
                                             y: center.y + sin(radians) * radius)
            }
        }

        let classNodes = graph.nodes.filter { $0.kind == .centralFileClass }
        for category in ArchivalRepositoryCategory.ordered {
            let members = graph.nodes.filter { $0.category == category && $0.kind == .collection }
            let start = (wedgeStart[category] ?? 0) + inset
            if category == .stateDepartment, !classNodes.isEmpty {
                // Split the wedge: collections lead, classes trail, with a gap between so the
                // hull never has to reach across a collection.
                let half = (usableSpan - 8) / 2
                place(members, from: start, span: half)
                place(classNodes, from: start + half + 8, span: half)
            } else {
                place(members, from: start, span: usableSpan)
            }
        }

        var hull: CGRect?
        let classPoints = classNodes.compactMap { positions[$0.id] }
        if let first = classPoints.first {
            var rect = CGRect(origin: first, size: .zero)
            for point in classPoints.dropFirst() {
                rect = rect.union(CGRect(origin: point, size: .zero))
            }
            hull = rect.insetBy(dx: -28, dy: -28)
        }

        let rings: [CGFloat] = ringFractions.map { fraction in
            inner + CGFloat(1 - fraction) * (outer - inner)
        }
        var layout = ArchivalNetworkLayout(positions: positions, center: center, ringRadii: rings,
                                           ringFractions: ringFractions, outerRadius: outer,
                                           classHull: hull)
        reserveCaptions(in: &layout, graph: graph, size: size, captionSize: captionSize)
        return layout
    }

    // MARK: - Captions (#1438, #1470)

    /// The space added on each side of a caption's measured text when its rect is reserved, so a
    /// caption drawn a point wider than measured is still inside it.
    static let captionPadding = CGSize(width: 2, height: 1)

    /// The least space kept between the canvas's edge and a caption.
    static let captionInset: CGFloat = 4

    /// The caption the canvas draws in `category`'s quadrant: the custodian's name in capitals.
    /// - Parameter category: The custodian.
    /// - Returns: The caption's text.
    static func captionText(for category: ArchivalRepositoryCategory) -> String {
        category.displayName.uppercased()
    }

    /// The class box's caption: which classes it holds (`expansion`).
    /// - Parameter expansion: How the umbrella is drawn.
    /// - Returns: The caption's text.
    static func hullCaptionText(for expansion: ArchivalUmbrellaExpansion) -> String {
        String(format: String(localized: "archival.network.hull %@",
                              defaultValue: "Central Files — %@"),
               expansion.title.lowercased())
    }

    /// The size a caption's text draws at — the system font at 9 pt semibold, which the canvas's
    /// `.font(.system(size: 9, weight: .semibold))` resolves to — rounded up to whole points.
    /// - Parameter text: The caption.
    /// - Returns: Its size.
    static func measuredCaptionSize(_ text: String) -> CGSize {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: 9, weight: .semibold)
        #else
        let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
        #endif
        let size = (text as NSString).size(withAttributes: [.font: font])
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    /// The farthest a node's outline reaches from the centre, for an outer radius: a node's centre
    /// lies `inner + (1 − s) × (outer − inner)` out and its disc reaches `11 + 11 × s` past that
    /// (`radius(for:)`), so with `outer − inner` at least 11 — it is at least 39 — the farthest is
    /// `outer + 11`, a node of no strength on the outer ring. Selected, it draws 3 pt larger and a
    /// white ring 2 pt beyond that, 1.5 pt wide: 3 more again.
    /// - Parameter outerRadius: The layout's outer radius.
    /// - Returns: The reach, in points from the centre.
    static func nodeReach(outerRadius: CGFloat) -> CGFloat {
        outerRadius + 11 + 3 + 3
    }

    /// Every rect a partner label keeps clear of (#1438): each custodian's caption, the class box's
    /// caption, and the box's border as four thin rects — so a class label sits wholly inside the
    /// box or wholly outside it, never across its line.
    /// - Parameter layout: The layout as drawn.
    /// - Returns: The obstacles for `GraphNodeLabels.place(_:avoiding:)`.
    static func labelObstacles(_ layout: ArchivalNetworkLayout) -> [CGRect] {
        var rects = ArchivalRepositoryCategory.ordered.compactMap { layout.captions[$0]?.rect }
        if let caption = layout.hullCaption { rects.append(caption.rect) }
        if let hull = layout.classHull {
            rects += [CGRect(x: hull.minX, y: hull.minY - 0.5, width: hull.width, height: 1),
                      CGRect(x: hull.minX, y: hull.maxY - 0.5, width: hull.width, height: 1),
                      CGRect(x: hull.minX - 0.5, y: hull.minY, width: 1, height: hull.height),
                      CGRect(x: hull.maxX - 0.5, y: hull.minY, width: 1, height: hull.height)]
        }
        return rects
    }

    /// The canvas corner `category`'s quadrant opens toward: State top left, lot files top right,
    /// presidential libraries bottom right, other institutions bottom left (`layout`'s compass).
    private static func corner(of category: ArchivalRepositoryCategory, in size: CGSize) -> CGPoint {
        switch category {
        case .stateDepartment: return .zero
        case .lotFile: return CGPoint(x: size.width, y: 0)
        case .presidentialLibrary: return CGPoint(x: size.width, y: size.height)
        case .otherInstitution: return CGPoint(x: 0, y: size.height)
        }
    }

    /// Fills in `layout`'s captions (see `layout(_:in:captionSize:)`): the class box's above the
    /// box, centred on it; then each custodian's in its quadrant's corner, clear of the box and its
    /// caption. Where a custodian's corner has no such point — on a 390 × 300 canvas the State
    /// corner can be where a centred box caption falls — the box's caption slides sideways, a point
    /// at a time and nearest first, until it keeps `GraphNodeLabels.clearance` from every
    /// custodian's.
    private static func reserveCaptions(in layout: inout ArchivalNetworkLayout,
                                        graph: ArchivalNetworkGraph, size: CGSize,
                                        captionSize: (String) -> CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
            .insetBy(dx: captionInset, dy: captionInset)
        var taken: [CGRect] = []
        var hullCaption: ArchivalNetworkCaption?
        if let hull = layout.classHull, graph.expansion != .collapsed {
            let text = hullCaptionText(for: graph.expansion)
            let rect = clamped(paddedRect(captionSize(text),
                                          centredOn: CGPoint(x: hull.midX, y: hull.minY - 8)),
                               into: bounds)
            hullCaption = ArchivalNetworkCaption(text: text, rect: rect)
            taken = [hull, rect]
        }
        let reach = nodeReach(outerRadius: layout.outerRadius)
        for category in ArchivalRepositoryCategory.ordered {
            let text = captionText(for: category)
            let rect = reservedRect(size: captionSize(text), center: layout.center,
                                    toward: corner(of: category, in: size), reach: reach,
                                    avoiding: taken, bounds: bounds)
            layout.captions[category] = ArchivalNetworkCaption(text: text, rect: rect)
            taken.append(rect)
        }
        guard let hullCaption else { return }
        let custodians = layout.captions.values.map(\.rect)
        let clear = { (rect: CGRect) in
            custodians.allSatisfy { rectGap(rect, $0) >= GraphNodeLabels.clearance }
        }
        var chosen = hullCaption.rect
        if !clear(chosen) {
            for step in 1...max(Int(size.width), 1) {
                if let moved = [CGFloat(step), -CGFloat(step)]
                    .map({ clamped(hullCaption.rect.offsetBy(dx: $0, dy: 0), into: bounds) })
                    .first(where: clear) {
                    chosen = moved
                    break
                }
            }
        }
        layout.hullCaption = ArchivalNetworkCaption(text: hullCaption.text, rect: chosen)
    }

    /// The rect for a caption of `textSize`: the first point on the ray from `center` toward
    /// `corner`, a point at a time, whose rect — kept inside `bounds` — keeps
    /// `GraphNodeLabels.clearance` from the circle of radius `reach` and from every `avoiding`
    /// rect; else the point that came closest to it.
    private static func reservedRect(size textSize: CGSize, center: CGPoint, toward corner: CGPoint,
                                     reach: CGFloat, avoiding taken: [CGRect],
                                     bounds: CGRect) -> CGRect {
        let dx = corner.x - center.x, dy = corner.y - center.y
        let length = max(hypot(dx, dy), 1)
        var best: (gap: CGFloat, rect: CGRect)?
        var step: CGFloat = 0
        while step <= length {
            let point = CGPoint(x: center.x + dx / length * step, y: center.y + dy / length * step)
            let rect = clamped(paddedRect(textSize, centredOn: point), into: bounds)
            let fromNodes = distance(from: center, to: rect) - reach
            let gap = taken.reduce(fromNodes) { min($0, rectGap(rect, $1)) }
            if gap >= GraphNodeLabels.clearance { return rect }
            if best.map({ gap > $0.gap }) ?? true { best = (gap, rect) }
            step += 1
        }
        return best?.rect ?? clamped(paddedRect(textSize, centredOn: corner), into: bounds)
    }

    /// A caption's rect: its text's size plus ``captionPadding`` on each side, centred on `point`.
    private static func paddedRect(_ textSize: CGSize, centredOn point: CGPoint) -> CGRect {
        let width = textSize.width + 2 * captionPadding.width
        let height = textSize.height + 2 * captionPadding.height
        return CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
    }

    /// `rect` moved, not resized, to lie inside `bounds` — or against its leading edge when wider.
    private static func clamped(_ rect: CGRect, into bounds: CGRect) -> CGRect {
        var moved = rect
        moved.origin.x = max(min(rect.minX, bounds.maxX - rect.width), bounds.minX)
        moved.origin.y = max(min(rect.minY, bounds.maxY - rect.height), bounds.minY)
        return moved
    }

    /// The distance from `point` to the nearest point of `rect`, 0 inside it.
    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        hypot(max(rect.minX - point.x, 0, point.x - rect.maxX),
              max(rect.minY - point.y, 0, point.y - rect.maxY))
    }

    /// The gap between two rects along whichever axis separates them more — negative when they
    /// overlap. Two rects keep `GraphNodeLabels.clearance` from each other exactly when this is at
    /// least the clearance: it is the measure the label placement's own test applies.
    /// - Parameters:
    ///   - a: One rect.
    ///   - b: The other.
    /// - Returns: The gap, in points.
    static func rectGap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(a.minX - b.maxX, b.minX - a.maxX, a.minY - b.maxY, b.minY - a.maxY)
    }

    /// The drawn radius of one node, in points.
    ///
    /// Range 11…22, so the weakest neighbour is still a comfortable tap target once the
    /// transparent hit button around it is counted.
    static func radius(for node: ArchivalNetworkNode) -> CGFloat {
        11 + 11 * CGFloat(node.relativeStrength)
    }

    // MARK: - Labels (#1384)

    /// The radius of the focus collection's disc, which the canvas draws and the label placement
    /// keeps clear of.
    static let focusRadius: CGFloat = 26

    /// The radius a node is drawn at, which the canvas and the label placement both read:
    /// `radius(for:)`, 3 pt more while the node is selected. A class square's is half its side.
    /// - Parameters:
    ///   - node: The node.
    ///   - isSelected: Whether it is the selected node, which the canvas enlarges and rings.
    /// - Returns: The radius in points.
    static func drawnRadius(for node: ArchivalNetworkNode, isSelected: Bool) -> CGFloat {
        radius(for: node) + (isSelected ? 3 : 0)
    }

    /// The most characters a label naming one record may have, the "…" of a cut included —
    /// twenty-six, as before #1384.
    static let labelLimit = 26

    /// The most characters the NAME half of a disambiguated label (`name · repository`) may have,
    /// the "…" of a cut included: the fourteen characters and mark the name half had before #1384.
    static let labelNameLimit = 15

    /// The most characters the QUALIFIER half of a disambiguated label may have, the "…" of a cut
    /// included.
    ///
    /// The qualifier is the repository `disambiguate` adds, and it is the only part of the label
    /// that tells two same-named records apart. Before #1384 it was cut to ten characters with no
    /// mark, which drew "Department" for both the Department of State and the Department of
    /// Defense, and "University" for both Arkansas and Montana. Twenty-two draws 20 of the 26
    /// repositories in the bundled authority whole and keeps all 26 distinct; the six it cuts are
    /// the long names ("Washington National R…", "Central Intelligence…"). A marked cut keeps them
    /// distinct from sixteen characters up.
    static let labelQualifierLimit = 22

    /// The label a node draws for `label` (#1384): whole when it has at most `labelLimit`
    /// characters. A longer label naming one record is cut and marked. A disambiguated label is
    /// cut in two halves, the name to `labelNameLimit` and the repository to
    /// `labelQualifierLimit`, each marked only if it was cut, so both the name and the repository
    /// survive: cutting at the END would draw `White House Central Files · Ford Library` like the
    /// Carter Library record beside it, which is exactly the collision `disambiguate` exists to
    /// prevent.
    ///
    /// Before #1384 the repository half was its first ten characters with no mark, and the name
    /// half ended in "…" whether it was cut or not ("Dulles Papers… · Eisenhower").
    ///
    /// The cut is `identifierKeepingCut(_:limit:)`'s — a hard one, which keeps a trailing lot or
    /// file number whole — rather than the word-boundary cut the co-mention and volume graphs share
    /// (`GraphNodeLabels.shortLabel(_:limit:)`), because a record here is often told from its
    /// neighbours by a lot or file number at the END of its name ("Conference Files: Lot 65 D
    /// 110"), and backing up to a word boundary drops more of it.
    ///
    /// Measured over the 200 most widely cited foci (by citing volumes, then name) under both
    /// measures — 400 graphs, 376 with a node — before #1437 a node drew exactly like the focus in
    /// 42 graphs: 21 because it was a same-named record held elsewhere, which `disambiguate` did
    /// not qualify since it never compared a node with the focus, and 21 because a cut from the
    /// end made two different names alike, 15 of them at a lot number ("Conference Files: Lot 64…"
    /// stood for both 64 D 559 and 64 D 560). `ArchivalNetworkLabelTests` sweeps the same 400
    /// graphs and holds the figures this rule draws.
    /// - Parameter label: The node's label (`ArchivalNetworkNode.label`), or the focus's
    ///   (`ArchivalNetworkGraph.focusLabel`).
    /// - Returns: The label to draw.
    static func drawnLabel(_ label: String) -> String {
        guard label.count > labelLimit else { return label }
        guard let separator = label.range(of: " · ") else {
            return identifierKeepingCut(label, limit: labelLimit)
        }
        let name = String(label[label.startIndex..<separator.lowerBound])
        let qualifier = String(label[separator.upperBound...])
        return identifierKeepingCut(name, limit: labelNameLimit) + " · "
            + markedCut(qualifier, limit: labelQualifierLimit)
    }

    /// The fewest characters of a name's head an `identifierKeepingCut(_:limit:)` keeps before its
    /// "…"; with less room it cuts from the end like `markedCut(_:limit:)`.
    static let minimumHeadKept = 4

    /// `text` whole when it has at most `limit` characters; otherwise, when it ends in an
    /// identifier (`trailingIdentifier(of:)`), its head cut and marked and the identifier whole —
    /// "Conference F… Lot 64 D 559" — and else `markedCut(_:limit:)`. Never more than `limit`
    /// characters (#1437).
    /// - Parameters:
    ///   - text: The name to cut.
    ///   - limit: The most characters the result may have, the "…" included.
    /// - Returns: The text as drawn.
    static func identifierKeepingCut(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        guard let tail = trailingIdentifier(of: text) else { return markedCut(text, limit: limit) }
        var head = String(text[..<tail.lowerBound])
        while let last = head.last, last.isWhitespace || ",;:".contains(last) { head.removeLast() }
        let identifier = String(text[tail])
        // Room for the head and its "…", with a space before the identifier.
        let room = limit - identifier.count - 1
        guard room - 1 >= minimumHeadKept, !head.isEmpty else {
            // Too little room for a head: the identifier alone, marked, when it fits — the name
            // half of "OSD Files: FRC 66 A 3542 · National Archives" draws "…FRC 66 A 3542".
            return identifier.count < limit ? "…" + identifier : markedCut(text, limit: limit)
        }
        // The head always ends in "…", which marks the words, or the separator, the cut took.
        var kept = String(head.prefix(room - 1))
        while let last = kept.last, last.isWhitespace || ",;:".contains(last), kept.count > 1 {
            kept.removeLast()
        }
        return kept + "… " + identifier
    }

    /// `text` cut to show its END (#1437): its head cut and marked, then its last words — the
    /// fewest that no label in `others` also ends with — so a label a plain cut drew like another
    /// shows where the two differ: "National Securi… (H-Files)" beside the focus's "National
    /// Security Council…". `nil` when no such ending leaves room for ``minimumHeadKept``
    /// characters of the head, or `text` fits whole.
    /// - Parameters:
    ///   - text: The full label (or the name half of a qualified one).
    ///   - others: The full labels it was drawn like.
    ///   - limit: The most characters the result may have.
    /// - Returns: The cut, or `nil`.
    static func distinguishingCut(_ text: String, from others: [String], limit: Int) -> String? {
        guard text.count > limit else { return nil }
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        let otherWords = others.map { $0.split(separator: " ", omittingEmptySubsequences: true) }
        for count in 1..<words.count {
            let ending = words.suffix(count)
            guard otherWords.allSatisfy({ Array($0.suffix(count)) != Array(ending) }) else { continue }
            let tail = ending.joined(separator: " ")
            let room = limit - tail.count - 2
            guard room >= minimumHeadKept else { return nil }
            var kept = String(words.dropLast(count).joined(separator: " ").prefix(room))
            while let last = kept.last, last.isWhitespace || ",;:".contains(last), kept.count > 1 {
                kept.removeLast()
            }
            return kept + "… " + tail
        }
        return nil
    }

    /// Every label the graph draws, by id (#1384, #1437): the focus's — of `focusLabel` — and each
    /// node's `drawnLabel(_:)`, except that a NODE whose drawn label reads like the focus's or
    /// another node's is re-cut to show where its name differs (`distinguishingCut(_:from:limit:)`),
    /// in its name half when it is qualified. The focus's label is never re-cut.
    ///
    /// The cut from the end made two different names alike, and a node then drew exactly like the
    /// focus: "National Security Council Institutional Files (H-Files)" beside a focus named
    /// "National Security Council Files" both drew "National Security Council…".
    /// - Parameter graph: The graph as drawn.
    /// - Returns: The drawn label of the focus and of every node.
    static func drawnLabels(in graph: ArchivalNetworkGraph) -> [String: String] {
        let focusLabel = graph.focusLabel
        var full: [String: String] = [graph.focus.id: focusLabel]
        var drawn: [String: String] = [graph.focus.id: drawnLabel(focusLabel)]
        for node in graph.nodes {
            full[node.id] = node.label
            drawn[node.id] = drawnLabel(node.label)
        }
        let groups = Dictionary(grouping: drawn.keys, by: { drawn[$0] ?? "" }).filter { $0.value.count > 1 }
        for (_, ids) in groups {
            for id in ids where id != graph.focus.id {
                guard let label = full[id] else { continue }
                let others = ids.filter { $0 != id }.compactMap { full[$0] }
                if let separator = label.range(of: " · ") {
                    let name = String(label[..<separator.lowerBound])
                    let qualifier = String(label[separator.upperBound...])
                    let otherNames = others.map { $0.components(separatedBy: " · ").first ?? $0 }
                    if let cut = distinguishingCut(name, from: otherNames, limit: labelNameLimit) {
                        drawn[id] = cut + " · " + markedCut(qualifier, limit: labelQualifierLimit)
                    }
                } else if let cut = distinguishingCut(label, from: others, limit: labelLimit) {
                    drawn[id] = cut
                }
            }
        }
        return drawn
    }

    /// Words that open an identifier when they come just before its numbers ("Lot 64 D 559",
    /// "FRC 71 A 6682", "Entry 5280").
    private static let identifierKeywords: Set<String> = ["lot", "lots", "frc", "entry", "no", "accession"]

    /// The identifier `text` ends in, if any (#1437): its trailing words that each hold a digit or
    /// are one or two capital letters — "64 D 559", "64D199", "1947–1953" — with a keyword just
    /// before them ("Lot", "FRC") taken along. At least one word must hold a digit, so a name
    /// ending in "Files (H-Files)" ends in none.
    /// - Parameter text: A name.
    /// - Returns: The identifier's range in `text`, or `nil`.
    static func trailingIdentifier(of text: String) -> Range<String.Index>? {
        let punctuation = CharacterSet(charactersIn: "()[],.;:")
        func bare(_ word: Substring) -> String {
            String(word).trimmingCharacters(in: punctuation)
        }
        func isIdentifierWord(_ word: String) -> Bool {
            if word.contains(where: \.isNumber) { return true }
            return (1...2).contains(word.count) && word.allSatisfy { $0.isUppercase && $0.isLetter }
        }
        var start: String.Index?
        var holdsDigit = false
        var cursor = text.endIndex
        // Walk the words back from the end.
        while cursor > text.startIndex {
            var wordStart = cursor
            while wordStart > text.startIndex, !text[text.index(before: wordStart)].isWhitespace {
                wordStart = text.index(before: wordStart)
            }
            let word = bare(text[wordStart..<cursor])
            if !word.isEmpty, isIdentifierWord(word) {
                holdsDigit = holdsDigit || word.contains(where: \.isNumber)
                start = wordStart
            } else {
                if holdsDigit, identifierKeywords.contains(word.lowercased()) { start = wordStart }
                break
            }
            cursor = wordStart
            while cursor > text.startIndex, text[text.index(before: cursor)].isWhitespace {
                cursor = text.index(before: cursor)
            }
        }
        guard holdsDigit, let start, start > text.startIndex else { return nil }
        return start..<text.endIndex
    }

    /// `text` whole when it has at most `limit` characters; otherwise its first `limit - 1`
    /// characters, less any whitespace they end in, and "…" — never more than `limit` characters.
    /// - Parameters:
    ///   - text: The text to cut.
    ///   - limit: The most characters the result may have, the "…" included.
    /// - Returns: The text as drawn.
    static func markedCut(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        var kept = text.prefix(max(1, limit - 1))
        while let last = kept.last, last.isWhitespace, kept.count > 1 { kept.removeLast() }
        return String(kept) + "…"
    }

    /// The label a node or the focus draws, by id (#1384).
    /// - Parameters:
    ///   - id: A node's id, or the focus's.
    ///   - graph: The graph as drawn.
    /// - Returns: The label to draw, or `nil` for an id the graph does not hold.
    static func drawnLabel(for id: String, in graph: ArchivalNetworkGraph) -> String? {
        drawnLabels(in: graph)[id]
    }

    /// The order the labels are placed in (#1384): the focus — which
    /// `GraphNodeLabels.place(_:avoiding:)` always places, on a plate — then the selected node, then
    /// the others strongest first
    /// (`graph.nodes` order): the co-mention graph's rule, with the selected node in place of the
    /// displayed partner, since nothing here hovers.
    /// - Parameters:
    ///   - graph: The graph as drawn.
    ///   - selectedNodeId: The selected node's id, if any.
    /// - Returns: Every id the canvas draws, highest priority first.
    static func labelPriority(_ graph: ArchivalNetworkGraph, selectedNodeId: String?) -> [String] {
        let ranked = graph.nodes.map(\.id)
        return [graph.focus.id]
            + ranked.filter { $0 == selectedNodeId }
            + ranked.filter { $0 != selectedNodeId }
    }

    /// One placement request per drawn node, in `labelPriority` order, for
    /// `GraphNodeLabels.place(_:avoiding:)` (#1384). A class node is a `.square`; a node with no
    /// position or no measured size is left out, since the canvas draws neither its shape nor its
    /// label.
    /// - Parameters:
    ///   - graph: The graph as drawn.
    ///   - layout: Its layout.
    ///   - selectedNodeId: The selected node's id, if any.
    ///   - sizes: Each label's measured size, keyed by id.
    /// - Returns: The requests, highest priority first.
    static func labelRequests(_ graph: ArchivalNetworkGraph, layout: ArchivalNetworkLayout,
                              selectedNodeId: String?,
                              sizes: [String: CGSize]) -> [GraphLabelRequest<String>] {
        let nodes = Dictionary(graph.nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return labelPriority(graph, selectedNodeId: selectedNodeId).compactMap { id in
            guard let center = layout.positions[id], let size = sizes[id] else { return nil }
            guard let node = nodes[id] else {
                return GraphLabelRequest(id: id, center: center, radius: focusRadius, size: size)
            }
            return GraphLabelRequest(
                id: id, center: center,
                radius: drawnRadius(for: node, isSelected: id == selectedNodeId),
                shape: node.kind == .centralFileClass ? .square : .disc, size: size)
        }
    }
}
