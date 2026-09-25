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
///   1.1 — 2026-09-24: #1384's label rules — `drawnLabel(_:)` and `markedCut(_:limit:)`, which
///          mark a cut in either half of a disambiguated label; `labelPriority` and
///          `labelRequests`, which the canvas places through `GraphNodeLabels` (the focus's label
///          always, on a plate); and `focusRadius` and `drawnRadius(for:isSelected:)`, the radii
///          the canvas draws and the placement keeps clear of
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
    /// Measured on the shipped authority, 17 names are carried by more than one record among the
    /// 1,108 that appear in the flow vocabulary alone — `White House Central Files` is six
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
    /// The cut is `markedCut(_:limit:)`'s — a hard one — rather than the word-boundary cut the
    /// co-mention and volume graphs share (`GraphNodeLabels.shortLabel(_:limit:)`), because a
    /// record here is often told from its neighbours by a lot or file number at the END of its name
    /// ("Conference Files: Lot 65 D 110"), and backing up to a word boundary drops more of it.
    /// Measured over the 200 most widely cited foci (by citing volumes, then name) under both
    /// measures — 400 graphs, 376 with a node — the word-boundary cut draws two of a graph's nodes
    /// alike in 89, and this cut in 67, as many as before #1384. The placement draws fewer of them
    /// together: two placed node labels read alike in no graph at 390 × 300 or 700 × 420, in 4 at
    /// 1000 × 640 and in 12 at 1300 × 800. A node can also draw like the focus: in 42 graphs, 21 of
    /// them because it is a same-named record held elsewhere, which `disambiguate` does not
    /// qualify since it never compares a node with the focus, and 21 because this cut ends two
    /// different names alike, 15 of them at a lot number. The focus's label is always drawn, so the
    /// two are on screen together in 4, 6, 19 and 26 graphs at those sizes.
    /// - Parameter label: The node's label (`ArchivalNetworkNode.label`), or the focus's name.
    /// - Returns: The label to draw.
    static func drawnLabel(_ label: String) -> String {
        guard label.count > labelLimit else { return label }
        guard let separator = label.range(of: " · ") else {
            return markedCut(label, limit: labelLimit)
        }
        let name = String(label[label.startIndex..<separator.lowerBound])
        let qualifier = String(label[separator.upperBound...])
        return markedCut(name, limit: labelNameLimit) + " · "
            + markedCut(qualifier, limit: labelQualifierLimit)
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
        if id == graph.focus.id { return drawnLabel(graph.focus.name) }
        return graph.nodes.first { $0.id == id }.map { drawnLabel($0.label) }
    }

    /// The order the labels are placed in (#1384): the focus — which `GraphNodeLabels.place(_:)`
    /// always places, on a plate — then the selected node, then the others strongest first
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
    /// `GraphNodeLabels.place(_:)` (#1384). A class node is a `.square`; a node with no position
    /// or no measured size is left out, since the canvas draws neither its shape nor its label.
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
