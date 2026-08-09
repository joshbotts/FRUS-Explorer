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
/// records still have more than forty partners** above a quarter of their strongest link. A graph
/// cannot draw four hundred nodes legibly, so this caps at ``nodeCap`` and reports
/// ``partnersAboveThreshold`` so the surface can say what it withheld. A cap that discloses is
/// honest; a cap that does not is the thing the design was guarding against.
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 2
struct ArchivalNetworkGraph: Sendable, Equatable {

    /// Nodes drawn, strongest first.
    static let nodeCap = 32

    /// Classes drawn when the umbrella is expanded. Small on purpose: they share the State
    /// sector with the collections already there.
    static let classCap = 10

    /// The focus record.
    let focus: AuthorityCollectionRecord
    /// The focus's custodian sector.
    let focusCategory: ArchivalRepositoryCategory
    /// Neighbours drawn, strongest first.
    let nodes: [ArchivalNetworkNode]
    /// Neighbours passing the threshold before the cap — the disclosure numerator.
    let partnersAboveThreshold: Int
    /// Neighbours sharing at least two volumes with the focus, whatever their strength.
    let partnersTotal: Int
    /// The strongest partner's raw measure value, which the rings are drawn as fractions of.
    let strongestMeasureValue: Double
    /// The umbrella record, when it is a neighbour and was replaced by classes.
    let expandedUmbrella: AuthorityCollectionRecord?

    /// Whether anything was withheld by the cap.
    var isCapped: Bool { partnersAboveThreshold > nodes.count }

    /// An empty graph — the honest state for a focus with no co-citing partners.
    static func empty(focus: AuthorityCollectionRecord) -> ArchivalNetworkGraph {
        ArchivalNetworkGraph(focus: focus,
                             focusCategory: ArchivalRepositoryCategory.from(focus),
                             nodes: [], partnersAboveThreshold: 0, partnersTotal: 0,
                             strongestMeasureValue: 0, expandedUmbrella: nil)
    }
}

// MARK: - ArchivalNetworkLayout

/// Where each node sits, in canvas coordinates.
///
/// Deterministic and physics-free (design direction 2a): the sector is decided by custodian and
/// the radius by strength, so the same focus always draws the same picture and two users
/// comparing screens are comparing the same thing.
struct ArchivalNetworkLayout: Sendable, Equatable {
    /// Node id → centre point.
    let positions: [String: CGPoint]
    /// The focus node's centre.
    let center: CGPoint
    /// Radii of the three dashed guide rings, outermost first.
    let ringRadii: [CGFloat]
    /// The fraction of the strongest link each ring marks, parallel to ``ringRadii``.
    let ringFractions: [Double]
    /// The bounding radius the wedge tints are filled to.
    let outerRadius: CGFloat
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
        guard focusVolumes.count >= minimumSharedVolumes else {
            return .empty(focus: focus)
        }
        let focusDocuments = usage?.documentsByVolume(forCollectionId: focus.id) ?? [:]

        var candidates: [(record: AuthorityCollectionRecord, shared: Int, documents: Int,
                          value: Double)] = []
        for candidate in collections where candidate.id != focus.id {
            let candidateVolumes = Set(candidate.volumeIds)
            let shared = candidateVolumes.intersection(focusVolumes)
            guard shared.count >= minimumSharedVolumes else { continue }
            let candidateDocuments = usage?.documentsByVolume(forCollectionId: candidate.id) ?? [:]
            let joint = shared.reduce(0) { total, volumeId in
                total + min(focusDocuments[volumeId] ?? 0, candidateDocuments[volumeId] ?? 0)
            }
            let union = candidateVolumes.union(focusVolumes).count
            let value: Double
            switch measure {
            case .sharedVolumes: value = Double(shared.count) / Double(max(union, 1))
            case .sharedDocuments: value = Double(joint)
            }
            guard value > 0 else { continue }
            candidates.append((candidate, shared.count, joint, value))
        }

        guard let strongest = candidates.map(\.value).max(), strongest > 0 else {
            return ArchivalNetworkGraph(
                focus: focus, focusCategory: ArchivalRepositoryCategory.from(focus), nodes: [],
                partnersAboveThreshold: 0, partnersTotal: candidates.count,
                strongestMeasureValue: 0, expandedUmbrella: nil)
        }

        // A total order, so the same focus always draws the same graph: strength, then shared
        // volumes, then the narrower partner (the more specific one), then name, then id.
        let ranked = candidates
            .filter { $0.value / strongest >= minimumRelativeStrength }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                if a.shared != b.shared { return a.shared > b.shared }
                if a.record.volumeIds.count != b.record.volumeIds.count {
                    return a.record.volumeIds.count < b.record.volumeIds.count
                }
                if a.record.name != b.record.name { return a.record.name < b.record.name }
                return a.record.id < b.record.id
            }

        let umbrella = expansion == .collapsed
            ? nil
            : ranked.first { $0.record.id == ArchivalCollectionsData.umbrellaCollectionId }?.record
        let drawn = ranked
            .filter { umbrella == nil || $0.record.id != umbrella?.id }
            .prefix(ArchivalNetworkGraph.nodeCap)

        var nodes = drawn.map { candidate in
            ArchivalNetworkNode(
                id: candidate.record.id, label: candidate.record.name,
                name: candidate.record.name, kind: .collection,
                category: ArchivalRepositoryCategory.from(candidate.record),
                sharedVolumeCount: candidate.shared, sharedDocumentCount: candidate.documents,
                measureValue: candidate.value,
                relativeStrength: min(candidate.value / strongest, 1))
        }
        if umbrella != nil, let usage {
            nodes.append(contentsOf: classNodes(focusVolumes: focusVolumes,
                                                focusDocuments: focusDocuments,
                                                usage: usage, expansion: expansion,
                                                strongest: strongest, measure: measure))
        }

        return ArchivalNetworkGraph(
            focus: focus, focusCategory: ArchivalRepositoryCategory.from(focus),
            nodes: disambiguate(nodes, in: collections),
            partnersAboveThreshold: ranked.count, partnersTotal: candidates.count,
            strongestMeasureValue: strongest, expandedUmbrella: umbrella)
    }

    /// The central-file classes co-cited with the focus, as square nodes.
    ///
    /// A class's strength is measured the same way as a collection's so the two sit on one
    /// radial axis — otherwise a square at the same radius as a circle would mean something
    /// different, which is exactly the confusion the shape distinction exists to prevent.
    private static func classNodes(focusVolumes: Set<String>,
                                   focusDocuments: [String: Int],
                                   usage: CollectionUsageIndex,
                                   expansion: ArchivalUmbrellaExpansion,
                                   strongest: Double,
                                   measure: ArchivalEdgeMeasure) -> [ArchivalNetworkNode] {
        var shared: [String: Set<String>] = [:]
        var joint: [String: Int] = [:]
        var union: [String: Set<String>] = [:]
        for key in usage.classKeys {
            let isSubjectNumeric = CollectionKeying.isSubjectNumericClass(key)
            switch expansion {
            case .collapsed: return []
            case .decimalClasses where isSubjectNumeric: continue
            case .subjectNumeric where !isSubjectNumeric: continue
            default: break
            }
            // Subject-numeric keys are folded to category + number: at leaf grain half of them
            // carry a single document and the lens is unrankable (#763's D-3 measurement).
            let label = expansion == .subjectNumeric
                ? (CollectionKeying.subjectNumericGroup(key) ?? key)
                : key
            let byVolume = usage.documentsByVolume(forClassKey: key)
            for (volumeId, count) in byVolume {
                union[label, default: []].insert(volumeId)
                guard focusVolumes.contains(volumeId) else { continue }
                shared[label, default: []].insert(volumeId)
                joint[label, default: 0] += min(focusDocuments[volumeId] ?? 0, count)
            }
        }

        let ranked = shared
            .filter { $0.value.count >= minimumSharedVolumes }
            .map { label, volumes -> (label: String, shared: Int, documents: Int, value: Double) in
                let documents = joint[label] ?? 0
                let unionCount = union[label]?.union(focusVolumes).count ?? focusVolumes.count
                let value: Double
                switch measure {
                case .sharedVolumes: value = Double(volumes.count) / Double(max(unionCount, 1))
                case .sharedDocuments: value = Double(documents)
                }
                return (label, volumes.count, documents, value)
            }
            .filter { $0.value > 0 }
            .sorted { a, b in
                if a.value != b.value { return a.value > b.value }
                return a.label < b.label
            }
            .prefix(ArchivalNetworkGraph.classCap)

        return ranked.map { entry in
            ArchivalNetworkNode(
                id: "class:\(entry.label)", label: entry.label, name: entry.label,
                kind: .centralFileClass, category: .stateDepartment,
                sharedVolumeCount: entry.shared, sharedDocumentCount: entry.documents,
                measureValue: entry.value,
                relativeStrength: min(entry.value / max(strongest, .leastNonzeroMagnitude), 1))
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
    /// the picture is reproducible. Nodes are ordered within their wedge by strength, and the
    /// wedge is filled from its leading edge, so the strongest neighbour of each custodian is
    /// always at the same corner of its quadrant.
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
        for category in ArchivalRepositoryCategory.ordered {
            let members = graph.nodes.filter { $0.category == category }
            guard !members.isEmpty else { continue }
            let start = wedgeStart[category] ?? 0
            // Inset from both wedge edges so neighbouring sectors never touch, and spread the
            // members evenly across what is left.
            let span = 90.0 - 2 * 8.0
            let step = members.count == 1 ? 0 : span / Double(members.count - 1)
            for (index, node) in members.enumerated() {
                let degrees = start + 8.0 + (members.count == 1 ? span / 2 : step * Double(index))
                let radians = degrees * .pi / 180
                let radius = inner + (1 - node.relativeStrength) * (outer - inner)
                positions[node.id] = CGPoint(x: center.x + cos(radians) * radius,
                                             y: center.y + sin(radians) * radius)
            }
        }

        let rings: [CGFloat] = ringFractions.map { fraction in
            inner + CGFloat(1 - fraction) * (outer - inner)
        }
        return ArchivalNetworkLayout(positions: positions, center: center, ringRadii: rings,
                                     ringFractions: ringFractions, outerRadius: outer)
    }

    /// The drawn radius of one node, in points.
    ///
    /// Range 11…22, so the weakest neighbour is still a comfortable tap target once the
    /// transparent hit button around it is counted.
    static func radius(for node: ArchivalNetworkNode) -> CGFloat {
        11 + 11 * CGFloat(node.relativeStrength)
    }
}
