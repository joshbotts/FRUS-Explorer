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
    /// Documents the two jointly supplied to those volumes.
    let sharedDocumentCount: Int
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

/// Where each node sits, in canvas coordinates.
///
/// Deterministic and physics-free (design direction 2a): the sector is decided by custodian and
/// the radius by strength, so the same focus always draws the same picture and two readers
/// comparing screens are comparing the same thing.
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
}

// MARK: - ArchivalNetworkBuilder

/// Builds a focus collection's neighbourhood and lays it out.
///
/// Every function here is pure over its inputs, so the whole graph is testable without a canvas.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
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
        let documents: Int
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

        var collectionCandidates: [Candidate] = []
        for candidate in collections where candidate.id != focus.id {
            let candidateVolumes = Set(candidate.volumeIds)
            let shared = candidateVolumes.intersection(focusVolumes)
            guard shared.count >= minimumSharedVolumes else { continue }
            let candidateDocuments = usage?.documentsByVolume(forCollectionId: candidate.id) ?? [:]
            let joint = shared.reduce(0) { total, volumeId in
                total + min(focusDocuments[volumeId] ?? 0, candidateDocuments[volumeId] ?? 0)
            }
            let value = strength(measure: measure, shared: shared.count,
                                 union: candidateVolumes.union(focusVolumes).count, joint: joint)
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
                      usage: usage!, expansion: expansion, measure: measure)
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
            nodes: disambiguate(nodes, in: collections),
            nodesAboveThreshold: ranked.count, partnersTotal: partnersTotal,
            strongestMeasureValue: strongest, expandedUmbrella: umbrella)
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
    private static func classes(focusVolumes: Set<String>, focusDocuments: [String: Int],
                                usage: CollectionUsageIndex,
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
                             documents: joint, value: value, breadth: 0)
        }
    }

    /// Makes labels unique within the graph.
    ///
    /// Measured on the shipped authority, 16 names are carried by more than one record among the
    /// 1,111 that appear in the flow vocabulary alone — `White House Central Files` is six
    /// distinct nodes across six repositories. Two identically-labelled circles in the same
    /// sector are indistinguishable, and the reader has no way to tell which one they tapped.
    static func disambiguate(_ nodes: [ArchivalNetworkNode],
                             in collections: [AuthorityCollectionRecord])
        -> [ArchivalNetworkNode] {
        var seen = Set<String>()
        var repeated = Set<String>()
        for node in nodes where !seen.insert(node.name).inserted { repeated.insert(node.name) }
        guard !repeated.isEmpty else { return nodes }
        var records: [String: AuthorityCollectionRecord] = [:]
        for record in collections where repeated.contains(record.name) { records[record.id] = record }
        var used = Set<String>()
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

    // MARK: - Layout

    /// Places every node in a canvas of the given size.
    ///
    /// Sector by custodian, radius by strength, angle by rank within the sector — no physics, so
    /// the picture is reproducible. Class squares take their own sub-arc at the trailing end of
    /// the State wedge, which both keeps them off the State collections and lets the hull that
    /// names them enclose nothing else.
    static func layout(_ graph: ArchivalNetworkGraph, in size: CGSize) -> ArchivalNetworkLayout {
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
        return ArchivalNetworkLayout(positions: positions, center: center, ringRadii: rings,
                                     ringFractions: ringFractions, outerRadius: outer,
                                     classHull: hull)
    }

    /// The drawn radius of one node, in points.
    ///
    /// Range 11…22, so the weakest neighbour is still a comfortable tap target once the
    /// transparent hit button around it is counted.
    static func radius(for node: ArchivalNetworkNode) -> CGFloat {
        11 + 11 * CGFloat(node.relativeStrength)
    }
}
