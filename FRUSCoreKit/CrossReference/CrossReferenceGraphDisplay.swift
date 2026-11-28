// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Supporting Types

/// The reader-facing gloss for a central-file class on a graph node — **`nil` in this version, and
/// that is a decision rather than an omission** (#834 / #828).
///
/// `DecimalClassLabelStore.gloss(for:coveringYears:)` needs the coverage span of the material being
/// labelled, because the classification was RENUMBERED in 1950: class 7 is Political Relations of
/// States before that date and Internal Political and National Defense Affairs after it, and Iran
/// moves from 91 to 88. Three schedules ship — 1910-1949, 1950-1959, 1960-1963 — and `gloss`
/// picks among them BY SPAN. A node here knows its CITING document, not the span of the file it
/// points at, so no schedule can be selected for it — and #828's standard is that where the
/// table cannot place something it says NOTHING, because a wrong gloss on an archival citation
/// is worse than a bare number: the reader cannot tell it is wrong.
///
/// The `gloss` field stays on the case so a later version can fill it once a span is available (the
/// citing volume's manifest coverage is the obvious source) rather than being retro-fitted through
/// every construction site.
///
/// **A free function, as it was in the view model's file,** where a method on the `@MainActor`
/// view model could not be called from inside the `Task.detached` that builds the unit nodes, which
/// now calls ``CrossReferenceGraphDisplay/unitNodes(rowsByDocument:authority:)``.
private func classGloss(_ key: String) -> String? { nil }

/// A node visible in the cross-reference graph canvas.
public struct DisplayNode: Identifiable, Sendable {
    public enum Kind: Sendable {
        case central
        case inbound
        case outbound
        /// A node reachable in 2 or more hops from the central document.
        case extended
        case clusterInbound(volumeId: String, count: Int)
        case clusterOutbound(volumeId: String, count: Int)
        /// Timeline-mode grouping of documents whose dates land within the same
        /// narrow x-window (Session 162): `label` is the period ("Jun 1967"),
        /// `memberKeys` the hidden document node keys. Tap expands in place.
        case dateCluster(label: String, count: Int, memberKeys: [String])
        /// An archival unit a document's footnotes point at, which FRUS did not print (#837).
        ///
        /// It is not a document: there is nothing behind it to open or recentre on, so it
        /// **terminates the walk** and routes to the collection record instead. Carries the
        /// name so the canvas needs no second lookup to label it.
        case unit(collectionId: String, name: String)
        /// A **central-file class** a document's footnotes point at (#834) — `763.72`, optionally
        /// glossed *China and Japan*.
        ///
        /// A separate case from ``unit`` rather than a synthetic collection id, because
        /// ``unitCollectionId`` feeds an authority lookup and the collection authority holds NO
        /// class records — classes exist there only as id-less display children. Giving a class a
        /// fake `collectionId` would make every existing unit path try to resolve it and quietly
        /// get nothing, which is the same wrong-join shape the artifact's second axis exists to
        /// avoid. Like a unit it **terminates the walk**: there is no document behind a file
        /// number.
        case centralFileClass(key: String, gloss: String?)
    }

    /// Whether this node stands for an archival unit rather than a printed document (#837).
    ///
    /// **A central-file class is NOT a unit**, deliberately: callers use this to reach
    /// ``unitCollectionId`` and the authority, which cannot answer for a class. Use
    /// ``terminatesWalk`` for the question "is there a document behind this node".
    public var isUnit: Bool { if case .unit = kind { true } else { false } }

    /// Whether the node is archival rather than a printed document, so the walk stops here — true
    /// for both an authority-backed unit and a central-file class.
    public var terminatesWalk: Bool {
        switch kind {
        case .unit, .centralFileClass: return true
        default: return false
        }
    }

    /// The central-file class behind a class node, or `nil` for every other node.
    public var centralFileClassKey: String? {
        if case .centralFileClass(let key, _) = kind { return key }
        return nil
    }

    /// The collection-authority id behind a unit node, or `nil` for every document node.
    public var unitCollectionId: String? {
        if case .unit(let id, _) = kind { return id }
        return nil
    }

    public let id: String   // nodeKey ("volId/docId") or cluster key ("cluster/inbound/volId")
    public let kind: Kind
    public let metadata: CrossReferenceNodeMetadata?
    public let isDownloaded: Bool
    /// Shortest hop distance from the central node (0 for central, 1 for direct neighbours, 2+ for extended).
    public let degree: Int

    /// Designated initializer. `degree` defaults to 1 so that pre-existing call sites
    /// (tests and cluster builders) that do not specify degree remain valid.
    public init(
        id: String,
        kind: Kind,
        metadata: CrossReferenceNodeMetadata?,
        isDownloaded: Bool,
        degree: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.metadata = metadata
        self.isDownloaded = isDownloaded
        self.degree = degree
    }

    public var isCentral: Bool { if case .central = kind { true } else { false } }

    public var isCluster: Bool {
        switch kind {
        case .clusterInbound, .clusterOutbound: true
        default: false
        }
    }

    /// `true` for timeline-mode date-group clusters (distinct from volume
    /// clusters: they expand via `toggleDateCluster`, a layout-level operation).
    public var isDateCluster: Bool {
        if case .dateCluster = kind { return true }
        return false
    }

    /// Best-effort volume ID for this node: from metadata, the cluster kind, or
    /// the `"volumeId/documentId"` node key as a last resort. Used by detail
    /// panels for manifest lookups (e.g. the Download Volume action).
    public var volumeId: String? {
        if let vol = metadata?.volumeId { return vol }
        switch kind {
        case .clusterInbound(let vol, _), .clusterOutbound(let vol, _):
            return vol
        default:
            return id.split(separator: "/", maxSplits: 1).first.map(String.init)
        }
    }

    /// The document or page id a document node stands for: from metadata, or the
    /// `"volumeId/documentId"` node key. `nil` for a cluster, a unit and a central-file class,
    /// which stand for no one document.
    public var documentId: String? {
        switch kind {
        case .central, .inbound, .outbound, .extended:
            if let id = metadata?.documentId { return id }
            let parts = id.split(separator: "/", maxSplits: 1)
            return parts.count == 2 ? String(parts[1]) : nil
        default:
            return nil
        }
    }

    /// Whether the node is a page the index left on its volume (#1799) — `pg_507`, or a roman or
    /// front-matter page (`pg_III`) — rather than a document. A page node opens nothing.
    public var isPageNode: Bool { documentId?.hasPrefix("pg_") ?? false }

    public var accessibilityLabel: String {
        switch kind {
        case .central:
            metadata?.header ?? id
        case .inbound:
            String(
                format: String(localized: "graph.a11y.inbound %@", defaultValue: "Inbound: %@"),
                metadata?.header ?? id
            )
        case .outbound:
            String(
                format: String(localized: "graph.a11y.outbound %@", defaultValue: "Outbound: %@"),
                metadata?.header ?? id
            )
        case .extended:
            String(
                format: String(localized: "graph.a11y.extended %@ %lld",
                               defaultValue: "Degree %2$lld: %1$@"),
                metadata?.header ?? id, Int64(degree)
            )
        case .clusterInbound(let vol, let count):
            String(
                format: String(localized: "graph.a11y.clusterInbound %lld %@",
                               defaultValue: "%lld inbound documents from volume %@"),
                Int64(count), vol
            )
        case .clusterOutbound(let vol, let count):
            String(
                format: String(localized: "graph.a11y.clusterOutbound %lld %@",
                               defaultValue: "%lld outbound documents to volume %@"),
                Int64(count), vol
            )
        case .centralFileClass(let key, let gloss):
            // The key alone is not speech. A VoiceOver reader gets "central file 763.72, China and
            // Japan" rather than a string of digits, and the canvas is accessibilityHidden so this
            // is the only description there is.
            if let gloss, !gloss.isEmpty {
                String(format: String(localized: "graph.a11y.centralFileClass %@ %@",
                                      defaultValue: "Central file %1$@, %2$@. Not printed."),
                       key, gloss)
            } else {
                String(format: String(localized: "graph.a11y.centralFileClassBare %@",
                                      defaultValue: "Central file %@. Not printed."),
                       key)
            }
        case .unit(_, let name):
            // Says what it is AND what it does, because the canvas is accessibilityHidden and
            // this label is the only description a VoiceOver reader gets of the node.
            String(
                format: String(localized: "graph.a11y.unit %@",
                               defaultValue: "Unprinted archival material: %@. Opens the collection record."),
                name
            )
        case .dateCluster(let label, let count, _):
            String(
                format: String(localized: "graph.a11y.dateCluster %lld %@",
                               defaultValue: "%lld documents around %@ — expands"),
                Int64(count), label
            )
        }
    }
}

/// A directed edge to render in the cross-reference graph canvas.
///
/// One `DisplayEdge` aggregates *all* individual references between the same
/// (source, target) document pair — a FRUS document routinely cites the same
/// target in several footnotes, and the `cross_references` table stores one row
/// per occurrence. Aggregation keeps `id` unique (a `ForEach` requirement) and
/// lets the renderer encode `referenceCount` as edge thickness.
public struct DisplayEdge: Identifiable, Sendable {
    /// Stable identity for use in `ForEach` and `selectedEdgeKey` lookups.
    /// Unique because edges are aggregated per (source, target) pair.
    public var id: String { "\(source)->\(target)" }
    public let source: String
    public let target: String
    /// `.editorialNote` only when *every* aggregated reference is an editorial
    /// note; mixed groups fall back to `.footnote`.
    public let referenceType: ReferenceType
    /// Plain text of every footnote or editorial note that contained a `<ref>`
    /// between this pair. Empty when no reference was inside a note block, or for
    /// edges indexed before Session 37 populated the context column.
    public let contexts: [String]
    /// Number of individual references aggregated into this edge (≥ 1).
    public let referenceCount: Int
    /// The degree of this edge: 1 for direct (inbound/outbound), 2+ for extended.
    public let degree: Int

    /// First context passage, if any. Convenience for call sites that only need
    /// to know whether *some* context exists.
    public var context: String? { contexts.first }

    /// All context passages joined into one displayable block, or `nil` when the
    /// edge carries no context at all.
    public var combinedContext: String? {
        contexts.isEmpty ? nil : contexts.joined(separator: "\n\n")
    }

    /// Aggregating initializer.
    public init(
        source: String,
        target: String,
        referenceType: ReferenceType,
        contexts: [String],
        referenceCount: Int,
        degree: Int = 1
    ) {
        self.source = source
        self.target = target
        self.referenceType = referenceType
        self.contexts = contexts
        self.referenceCount = max(1, referenceCount)
        self.degree = degree
    }

    /// Single-reference convenience initializer; keeps pre-aggregation call sites
    /// (tests, fixtures) valid.
    public init(
        source: String,
        target: String,
        referenceType: ReferenceType,
        context: String?,
        degree: Int = 1
    ) {
        self.init(
            source: source,
            target: target,
            referenceType: referenceType,
            contexts: context.map { [$0] } ?? [],
            referenceCount: 1,
            degree: degree
        )
    }
}

// MARK: - GraphLayoutMode

/// How the cross-reference graph arranges its nodes.
public enum GraphLayoutMode: String, Sendable, CaseIterable {
    /// Chronological: x position encodes the document date along a time axis,
    /// so antecedents sit left of the central document and later documents sit
    /// right. Undated nodes (and volume clusters) park in a column at the
    /// trailing edge.
    case timeline
    /// Topological: the original three-column / force-directed spring layout.
    case network
}

// MARK: - TimelineTick

/// One labelled tick on the timeline layout's date axis.
///
/// Its `x` was a `CGFloat` in the app's view model, and is a `Double` since FRUS Explorer Light's S23b
/// moved it into FRUSCoreKit: on every 64-bit Apple platform a `CGFloat` is a `Double`
/// (`CGFloat.NativeType`), and its arithmetic is `Double`'s, so the app draws each tick where it did.
public struct TimelineTick: Sendable, Equatable {
    /// X position in canvas coordinates.
    public let x: Double
    /// Short localized label ("1962", "Mar 1962", "Mar 4").
    public let label: String
}

// MARK: - GraphPoint

/// A position on the graph's canvas, in points: what the timeline layout returns for each node, where
/// the app's view model returned a `CGPoint`. The app turns each into the `CGPoint` it draws at with
/// the same two `Double`s (on every 64-bit Apple platform a `CGFloat` is a `Double`).
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S23b): initial implementation, for the timeline layout's
///          positions in FRUSCoreKit
public struct GraphPoint: Equatable, Sendable {
    /// The distance from the canvas's leading edge.
    public let x: Double
    /// The distance from the canvas's top edge.
    public let y: Double

    /// A position at `x` and `y`.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - CrossReferenceGraphDisplay

/// The cross-reference graph's display half, pure over the store's `CrossReferenceGraph`: the nodes and
/// edges the canvas draws, with the volume clusters and the unprinted archival units; the dates that
/// label and place each node; the timeline's date clusters and positions; whether a graph is widened
/// one hop and whether it can be drawn as a timeline; and the order the reference list shows a
/// section's nodes in.
///
/// It was `CrossReferenceGraphViewModel`'s, which calls it with the state it holds: its loaded graph,
/// the cluster keys the reader expanded, the canvas's size and the brushed date window. The network
/// layout, the node sizes and the canvas's labels stay the app's, with the view model.
///
/// **Dates are the process's.** The labels are written in the current locale, and the date values,
/// the clusters' periods and the axis's ticks are computed in a Gregorian calendar in the current time
/// zone, as the app computes them on each device; a host sets its own (a server, its `LANG` and `TZ`).
///
/// Version history:
///   1.0 — 2026-11-10 (FRUS Explorer Light, S23b): moved out of `CrossReferenceGraphViewModel`, its
///          statics line for line, `Double` for `CGFloat` (on every 64-bit Apple platform a `CGFloat` is
///          a `Double`, so every value is the same), and four rules that were inline in its methods:
///          the sparse widening (`loadGraph`), the unit nodes (`loadUnprintedUnits`), their attachment
///          (`rebuildDisplay`) and the timeline's eligibility (`timelineEligible`)
///   1.1 — 2026-11-15 (#1893, L16): `timelineLayout` keeps its axis's tick range in order on a canvas
///          narrower than 116 pt, where the range's ends crossed and the layout trapped; from 116 pt
///          every tick is unchanged
///   1.2 — 2026-11-15 (#1914, L16): `isTimelineEligible`'s doc says to ask it of a graph's built nodes,
///          as the view model now does, since a timeline's date clusters have no date value; the rule is
///          unchanged
///   1.3 — 2026-11-27 (#1990, L42): ``capture(nodes:edges:graph:dateValues:dateWindow:)``, what the
///          graph's two saves take (``CrossReferenceGraphCapture``)
public enum CrossReferenceGraphDisplay {

    // MARK: - Timeline eligibility

    /// Whether a graph can be laid out chronologically: the central document and at least two other
    /// non-cluster nodes need parseable dates spanning a non-zero interval. The view model defaults to
    /// the timeline whenever this holds, until the reader picks a layout.
    ///
    /// Ask it of the graph's nodes as built, before the timeline folds any into date clusters
    /// (``dateClusteredDisplay(nodes:edges:dateValues:canvasWidth:expandedKeys:domain:)``): a date
    /// cluster has no value in ``buildDateValues(for:)``'s dates, so over a timeline's displayed nodes a
    /// graph whose dated nodes fold into one cluster counts too few (#1914). `nodes` is read only when
    /// the central document is dated, as the view model's `timelineEligible` read its nodes when the
    /// rule was inline there, so a view that reads that property observes what it observed.
    ///
    /// - Parameters:
    ///   - centralKey: The central document's node key.
    ///   - dateValues: Each node's date value (``buildDateValues(for:)``).
    ///   - nodes: The graph's nodes as built, with any unit nodes attached.
    /// - Returns: Whether the timeline layout can place the graph.
    public static func isTimelineEligible(centralKey: String, dateValues: [String: TimeInterval],
                                          nodes: @autoclosure () -> [DisplayNode]) -> Bool {
        guard let centralValue = dateValues[centralKey] else { return false }
        let others = nodes().filter { !$0.isCentral && !$0.isCluster }
            .compactMap { dateValues[$0.id] }
        guard others.count >= 2 else { return false }
        let all = others + [centralValue]
        guard let minValue = all.min(), let maxValue = all.max() else { return false }
        return maxValue > minValue
    }

    // MARK: - Sparse widening

    /// Whether a graph loaded at `degree` is loaded again at two hops: a star of one to three direct
    /// references is the most common first impression and the least informative, so the view model
    /// widens it, while the reader has not chosen a degree, and keeps the wider graph only when it adds
    /// edges (``keepsWidenedGraph(_:over:)``). The degree picker goes on showing the reader's choice.
    ///
    /// - Parameters:
    ///   - degree: The degree the graph was loaded at.
    ///   - edgeCount: Its direct references, `CrossReferenceGraph.edgeCount`.
    /// - Returns: Whether to load it again at two hops.
    public static func widensSparseGraph(loadedAtDegree degree: Int, edgeCount: Int) -> Bool {
        degree == 1 && (1...3).contains(edgeCount)
    }

    /// Whether the graph loaded again at two hops (``widensSparseGraph(loadedAtDegree:edgeCount:)``)
    /// replaces the one loaded at one: when it has more edges in all.
    ///
    /// - Parameters:
    ///   - widened: The graph loaded at two hops.
    ///   - loaded: The graph loaded at one.
    /// - Returns: Whether to show the wider one.
    public static func keepsWidenedGraph(_ widened: CrossReferenceGraph, over loaded: CrossReferenceGraph) -> Bool {
        widened.totalEdgeCount > loaded.totalEdgeCount
    }

    // MARK: - Unprinted archival units (#837, #834)

    /// The archival nodes of each graph document's unprinted pointers, by document node key: a unit for
    /// each citation that joins the collection authority (`ExternalCitationAuthorityJoin`), and a
    /// central-file class for each class a footnote cites by number, each once per document. A citation
    /// that joins no record becomes no node: a node the reader cannot open, standing for a match the
    /// app did not make, would be a guess drawn as a finding (#837). Several documents citing one unit
    /// get a node each, since the edge is what carries the meaning.
    ///
    /// The view model runs it in a detached task, over the rows the pipeline's
    /// `externalCitations(volumeId:documentId:)` gave for each document, since the authority is a ~2 MB
    /// decode.
    ///
    /// - Parameters:
    ///   - rowsByDocument: Each document's citations, keyed `"volumeId/documentId"`.
    ///   - authority: The bundled collection authority (`collection-authority.json`).
    /// - Returns: Each document's archival nodes, for the documents that have any.
    public static func unitNodes(rowsByDocument: [String: [ExternalCitation]],
                                 authority: CollectionAuthorityIndex) -> [String: [DisplayNode]] {
        var out: [String: [DisplayNode]] = [:]
        for (documentKey, rows) in rowsByDocument {
            var seen = Set<String>()
            var nodes: [DisplayNode] = []
            for row in rows {
                // #834: a central-file class carries no authority record — the authority holds
                // none — so the `guard let record` below would DROP it, which is exactly what
                // the graph did until now: a document whose editors cited by decimal number
                // showed no teal nodes however many archival footnotes it carried, and the
                // help text had to apologise for it.
                if let classKey = row.decimalClass {
                    guard seen.insert("class/\(classKey)").inserted else { continue }
                    nodes.append(DisplayNode(
                        id: "class/\(documentKey)/\(classKey)",
                        kind: .centralFileClass(key: classKey, gloss: classGloss(classKey)),
                        metadata: nil,
                        // Same reasoning as a unit: a class has no volume, so "downloaded" is
                        // meaningless and `true` keeps it off every not-downloaded path.
                        isDownloaded: true,
                        degree: 1))
                    continue
                }
                guard let record = ExternalCitationAuthorityJoin.record(
                    lotFileNorm: row.lotFileNorm, collectionName: row.collection,
                    repository: row.repository, authority: authority) else { continue }
                guard seen.insert(record.id).inserted else { continue }
                nodes.append(DisplayNode(
                    id: "unit/\(documentKey)/\(record.id)",
                    kind: .unit(collectionId: record.id, name: record.name),
                    metadata: nil,
                    // A unit has no volume, so "downloaded" is meaningless. `true` keeps it
                    // off every not-downloaded path — the dashed ring, the icloud.slash
                    // glyph, and the two context-menu items disabled by `!isDownloaded` —
                    // none of which could tell the truth about a node with no volume.
                    isDownloaded: true,
                    degree: 1))
            }
            if !nodes.isEmpty { out[documentKey] = nodes }
        }
        return out
    }

    /// The display with each document's archival nodes (``unitNodes(rowsByDocument:authority:)``)
    /// after the display build's own, each with a footnote's edge from its document, for the documents
    /// the build kept, in the order of their keys.
    ///
    /// - Parameters:
    ///   - unitsByDocument: Each document's archival nodes, by document node key.
    ///   - nodes: The display build's nodes (``buildDisplayNodesAndEdges(graph:centralKey:expandedClusterKeys:downloadedVolumeIds:)``).
    ///   - edges: Its edges.
    /// - Returns: The nodes and edges with the archival nodes after them.
    public static func attachingUnits(_ unitsByDocument: [String: [DisplayNode]],
                                      to nodes: [DisplayNode],
                                      edges: [DisplayEdge]) -> (nodes: [DisplayNode], edges: [DisplayEdge]) {
        var nodes = nodes
        var edges = edges
        // #837: unit nodes hang off whichever document nodes survived the display build, so a
        // clustered-away document contributes none — the canvas never carries a unit whose
        // citing document is not on it. By citing document's key (#1764): a dictionary's order is
        // seeded per launch, and the network layout starts each node from its place in this order,
        // so in the dictionary's order the same graph settled differently at every launch.
        if !unitsByDocument.isEmpty {
            let onCanvas = Set(nodes.map(\.id))
            for (documentKey, units) in unitsByDocument.sorted(by: { $0.key < $1.key })
            where onCanvas.contains(documentKey) {
                for unit in units {
                    nodes.append(unit)
                    // `.footnote`: every external citation this reads comes from a body
                    // footnote — that is what the harvest collects — so the type is a fact
                    // about the data rather than a default.
                    edges.append(DisplayEdge(source: documentKey, target: unit.id,
                                             referenceType: .footnote, context: nil))
                }
            }
        }
        return (nodes, edges)
    }

    // MARK: - Date labels

    /// Formats each node's `dateISO` into a short label in the current locale, handling full
    /// dates, year-month, and year-only values. Runs once per rebuild.
    ///
    /// A node the device holds no row for is dated by a span (#1799) and labelled with it: the days
    /// of the documents on its page ("May 19 – 23, 1943"), or its volume's years ("1942 – 1944"),
    /// which is all the precision a volume's span has.
    public static func buildDateLabels(for nodes: [DisplayNode]) -> [String: String] {
        let calendar = Calendar(identifier: .gregorian)
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.setLocalizedDateFormatFromTemplate("MMM d y")
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.setLocalizedDateFormatFromTemplate("MMM y")
        let daySpanFormatter = DateIntervalFormatter()
        daySpanFormatter.calendar = calendar
        daySpanFormatter.dateTemplate = "MMM d y"
        let yearSpanFormatter = DateIntervalFormatter()
        yearSpanFormatter.calendar = calendar
        yearSpanFormatter.dateTemplate = "y"

        var labels: [String: String] = [:]
        for node in nodes {
            guard let iso = node.metadata?.dateISO, !iso.isEmpty else { continue }
            if let dating = node.metadata?.dating,
               let start = Self.date(fromISO: iso, calendar: calendar) {
                let end = node.metadata?.dateISOMax.flatMap { Self.date(fromISO: $0, calendar: calendar) } ?? start
                let formatter = dating == .volume ? yearSpanFormatter : daySpanFormatter
                labels[node.id] = formatter.string(from: start, to: max(start, end))
                continue
            }
            let parts = iso.split(separator: "-").map(String.init)
            guard let yearText = parts.first, let year = Int(yearText) else { continue }
            var comps = DateComponents()
            comps.year = year
            if parts.count >= 2, let month = Int(parts[1]), (1...12).contains(month) {
                comps.month = month
            }
            if parts.count >= 3, let day = Int(parts[2].prefix(2)), (1...31).contains(day) {
                comps.day = day
            }
            if comps.month == nil {
                labels[node.id] = yearText
            } else if let date = calendar.date(from: comps) {
                labels[node.id] = comps.day != nil
                    ? dayFormatter.string(from: date)
                    : monthFormatter.string(from: date)
            } else {
                labels[node.id] = yearText
            }
        }
        return labels
    }

    /// Parses each node's `dateISO` into a numeric value for the timeline layout.
    /// Year-only and year-month dates resolve to the start of their period.
    ///
    /// A node dated by a span (#1799) sits at its middle: the nearest the app can say where in a
    /// volume's span a page or document falls, and a day or two either way for the documents on a
    /// page. At the span's start, the Mac check copy drew the Long Telegram's two citers from
    /// volumes it lacked in 1945, months before the February 1946 telegram they cite, and dated
    /// March and April 1946; at the middle they fall in 1946.
    public static func buildDateValues(for nodes: [DisplayNode]) -> [String: TimeInterval] {
        let calendar = Calendar(identifier: .gregorian)
        var values: [String: TimeInterval] = [:]
        for node in nodes {
            guard !node.isCluster,
                  let iso = node.metadata?.dateISO,
                  let date = Self.date(fromISO: iso, calendar: calendar) else { continue }
            let start = date.timeIntervalSinceReferenceDate
            if node.metadata?.dating != nil,
               let endISO = node.metadata?.dateISOMax,
               let end = Self.date(fromISO: endISO, calendar: calendar)?.timeIntervalSinceReferenceDate,
               end > start {
                values[node.id] = (start + end) / 2
            } else {
                values[node.id] = start
            }
        }
        return values
    }

    /// Lenient ISO date parser accepting `yyyy`, `yyyy-MM`, and `yyyy-MM-dd`.
    /// Missing components default to the start of the period.
    public static func date(fromISO iso: String, calendar: Calendar) -> Date? {
        let parts = iso.split(separator: "-").map(String.init)
        guard let yearText = parts.first, let year = Int(yearText), year > 0 else { return nil }
        var comps = DateComponents()
        comps.year  = year
        comps.month = parts.count >= 2
            ? Int(parts[1]).flatMap { (1...12).contains($0) ? $0 : nil } ?? 1
            : 1
        comps.day   = parts.count >= 3
            ? Int(parts[2].prefix(2)).flatMap { (1...31).contains($0) ? $0 : nil } ?? 1
            : 1
        return calendar.date(from: comps)
    }

    // MARK: - Date clustering

    /// Collapses same-date pileups into expandable `.dateCluster` nodes for the
    /// timeline layout (Session 162).
    ///
    /// Dated, non-central document nodes are swept in date order; nodes whose x
    /// positions (under the timeline's standard margins) fall within a 52 pt
    /// window form a group, and groups of four or more collapse into one cluster
    /// node labelled with the group's period ("Jun 1967"). Edges touching hidden
    /// members are rerouted to the cluster and re-aggregated so identifiers stay
    /// unique; edges between two members of the same cluster disappear.
    /// Clusters listed in `expandedKeys` stay expanded (their members render
    /// individually). Output is deterministic for a given input.
    public static func dateClusteredDisplay(
        nodes: [DisplayNode],
        edges: [DisplayEdge],
        dateValues: [String: TimeInterval],
        canvasWidth: Double,
        expandedKeys: Set<String>,
        domain: ClosedRange<TimeInterval>? = nil
    ) -> (nodes: [DisplayNode], edges: [DisplayEdge], clusterDateValues: [String: TimeInterval]) {
        let clusterThreshold = 4
        let xWindow: Double = 52
        let padLeading: Double = 56
        let padTrailing: Double = 96
        let plotWidth = max(canvasWidth - padLeading - padTrailing, 1)

        // When a brush domain is active, clustering works on the zoomed scale —
        // zooming in naturally dissolves clusters as their members spread apart.
        let candidates = nodes
            .filter { node in
                guard !node.isCentral, !node.isCluster,
                      let t = dateValues[node.id] else { return false }
                return domain.map { $0.contains(t) } ?? true
            }
            .sorted {
                let a = dateValues[$0.id] ?? 0, b = dateValues[$1.id] ?? 0
                return a == b ? $0.id < $1.id : a < b
            }
        let minT: TimeInterval
        let maxT: TimeInterval
        if let domain {
            minT = domain.lowerBound
            maxT = domain.upperBound
        } else {
            guard let lower = candidates.compactMap({ dateValues[$0.id] }).min(),
                  let upper = candidates.compactMap({ dateValues[$0.id] }).max() else {
                return (nodes, edges, [:])
            }
            minT = lower
            maxT = upper
        }
        guard candidates.count >= clusterThreshold, maxT > minT else {
            return (nodes, edges, [:])
        }

        func xPosition(_ t: TimeInterval) -> Double {
            padLeading + ((t - minT) / (maxT - minT)) * plotWidth
        }

        // Sweep into x-window groups.
        var groups: [[DisplayNode]] = []
        var current: [DisplayNode] = []
        var groupStartX: Double = -.greatestFiniteMagnitude
        for node in candidates {
            let x = xPosition(dateValues[node.id] ?? 0)
            if current.isEmpty || x - groupStartX <= xWindow {
                if current.isEmpty { groupStartX = x }
                current.append(node)
            } else {
                groups.append(current)
                current = [node]
                groupStartX = x
            }
        }
        if !current.isEmpty { groups.append(current) }

        // Period label formatter ("Jun 1967" for the group's mean date).
        let calendar = Calendar(identifier: .gregorian)
        let periodFormatter = DateFormatter()
        periodFormatter.calendar = calendar
        periodFormatter.setLocalizedDateFormatFromTemplate("MMM y")

        var hiddenMemberToCluster: [String: String] = [:]
        var clusterNodes: [DisplayNode] = []
        var clusterDateValues: [String: TimeInterval] = [:]

        for group in groups where group.count >= clusterThreshold {
            let clusterKey = "datecluster/\(group[0].id)"
            guard !expandedKeys.contains(clusterKey) else { continue }
            let memberKeys = group.map(\.id)
            let meanDate = group.compactMap { dateValues[$0.id] }.reduce(0, +)
                / Double(group.count)
            let label = periodFormatter.string(
                from: Date(timeIntervalSinceReferenceDate: meanDate))
            clusterNodes.append(DisplayNode(
                id: clusterKey,
                kind: .dateCluster(label: label, count: group.count, memberKeys: memberKeys),
                metadata: nil,
                isDownloaded: group.allSatisfy(\.isDownloaded),
                degree: 1
            ))
            clusterDateValues[clusterKey] = meanDate
            for key in memberKeys { hiddenMemberToCluster[key] = clusterKey }
        }
        guard !clusterNodes.isEmpty else { return (nodes, edges, [:]) }

        // Visible nodes: everything not hidden, plus the cluster placeholders.
        let visibleNodes = nodes.filter { hiddenMemberToCluster[$0.id] == nil } + clusterNodes

        // Reroute edges to cluster endpoints, drop intra-cluster edges, and
        // re-aggregate per (source, target) pair so `DisplayEdge.id` stays unique.
        struct PairAccumulator {
            var referenceType: ReferenceType
            var contexts: [String] = []
            var referenceCount = 0
            var degree = Int.max
        }
        var pairs: [String: PairAccumulator] = [:]
        var pairOrder: [String] = []
        for edge in edges {
            let source = hiddenMemberToCluster[edge.source] ?? edge.source
            let target = hiddenMemberToCluster[edge.target] ?? edge.target
            guard source != target else { continue }
            let pairKey = "\(source)->\(target)"
            var accumulator: PairAccumulator
            if let existing = pairs[pairKey] {
                accumulator = existing
            } else {
                accumulator = PairAccumulator(referenceType: edge.referenceType)
                pairOrder.append(pairKey)
            }
            accumulator.contexts.append(contentsOf: edge.contexts)
            accumulator.referenceCount += edge.referenceCount
            accumulator.degree = min(accumulator.degree, edge.degree)
            if edge.referenceType != .editorialNote {
                accumulator.referenceType = .footnote
            }
            pairs[pairKey] = accumulator
        }
        let visibleEdges: [DisplayEdge] = pairOrder.compactMap { pairKey in
            guard let acc = pairs[pairKey] else { return nil }
            let parts = pairKey.components(separatedBy: "->")
            guard parts.count == 2 else { return nil }
            return DisplayEdge(
                source: parts[0], target: parts[1],
                referenceType: acc.referenceType,
                contexts: acc.contexts,
                referenceCount: acc.referenceCount,
                degree: acc.degree == Int.max ? 1 : acc.degree
            )
        }

        return (visibleNodes, visibleEdges, clusterDateValues)
    }

    // MARK: - Timeline layout

    /// Chronological layout: x encodes the document date along a bottom axis;
    /// y is assigned greedily to nearby lanes so labels don't collide.
    ///
    /// - Dated nodes are placed left-to-right between fixed margins, the central
    ///   document on the middle lane at its own date.
    /// - Undated nodes and volume clusters park in a column at the trailing edge
    ///   (`hasParkedNodes` tells the canvas to caption that column).
    /// - Axis ticks adapt to the span: years for multi-year graphs, months for
    ///   multi-month, days for tighter spans.
    ///
    /// The output is fully deterministic for a given node set and canvas size —
    /// no randomness, no iteration-order dependence — so the same document always
    /// produces the same picture.
    ///
    /// It lays out a canvas of any width. Below 116 pt the axis's visible range closes on its
    /// leading end, x = 48, and keeps only a tick that falls there, which in practice is none
    /// (#1893). No layout of the app's gives the canvas so little. Measured under iOS 27.0, the
    /// narrowest window is 374 pt and compact, so the canvas takes all of it, and a window wide
    /// enough to be regular leaves it more than 331 pt beside the reference list; on the Mac the
    /// window is at least 640 pt.
    public static func timelineLayout(
        nodes: [DisplayNode],
        dateValues: [String: TimeInterval],
        centralKey: String,
        canvasWidth: Double,
        canvasHeight: Double,
        domain: ClosedRange<TimeInterval>? = nil
    ) -> (positions: [String: GraphPoint], ticks: [TimelineTick], axisY: Double, hasParkedNodes: Bool) {
        var positions: [String: GraphPoint] = [:]

        let padLeading: Double  = 56
        let padTrailing: Double = 96
        let axisY   = max(canvasHeight - 34, 80)
        let yTop    = Double(64)
        let yBottom = max(axisY - 60, yTop + 1)
        let cy      = (yTop + yBottom) / 2
        let plotWidth = max(canvasWidth - padLeading - padTrailing, 1)

        // With a brush domain the axis zooms to the brushed window and dated
        // nodes outside it disappear entirely (they are *not* parked — the
        // Undated column is only for genuinely undated nodes).
        let dated = nodes.filter { node in
            guard let t = dateValues[node.id] else { return false }
            return domain.map { $0.contains(t) } ?? true
        }
        let minT: TimeInterval
        let maxT: TimeInterval
        if let domain {
            minT = domain.lowerBound
            maxT = domain.upperBound
        } else {
            let datedValues = dated.compactMap { dateValues[$0.id] }
            guard let lower = datedValues.min(), let upper = datedValues.max() else {
                return ([:], [], axisY, false)
            }
            minT = lower
            maxT = upper
        }
        guard maxT > minT, domain != nil || dated.count >= 2 else {
            return ([:], [], axisY, false)
        }

        func xPosition(_ t: TimeInterval) -> Double {
            padLeading + ((t - minT) / (maxT - minT)) * plotWidth
        }

        // --- Lane assignment ---
        // Lane 0 is the vertical centre; lanes alternate above/below in 58 pt
        // steps. A node joins the innermost lane where it keeps ≥ 76 pt of
        // horizontal clearance from every node already in that lane (enough for
        // its two-line label); failing that, the lane with the most clearance.
        let laneSpacing: Double = 58
        let lanesPerSide = max(1, Int((cy - yTop) / laneSpacing))
        var laneOffsets: [Double] = [0]
        for i in 1...lanesPerSide {
            laneOffsets.append(-Double(i) * laneSpacing)
            laneOffsets.append(Double(i) * laneSpacing)
        }
        var laneOccupiedXs: [[Double]] = Array(repeating: [], count: laneOffsets.count)

        func assignLane(x: Double, forceCentre: Bool) -> Double {
            if forceCentre {
                laneOccupiedXs[0].append(x)
                return cy
            }
            var bestLane = 0
            var bestClearance: Double = -1
            for (lane, occupied) in laneOccupiedXs.enumerated() {
                let clearance = occupied.map { abs($0 - x) }.min() ?? .greatestFiniteMagnitude
                if clearance >= 76 {
                    laneOccupiedXs[lane].append(x)
                    return cy + laneOffsets[lane]
                }
                if clearance > bestClearance {
                    bestClearance = clearance
                    bestLane = lane
                }
            }
            laneOccupiedXs[bestLane].append(x)
            return cy + laneOffsets[bestLane]
        }

        // Central first so it owns the middle lane at its own date. Like every
        // dated node, it hides when a brush domain excludes its date — placing
        // it anyway would extrapolate its x off the plot.
        if let centralT = dateValues[centralKey],
           domain.map({ $0.contains(centralT) }) ?? true {
            let x = xPosition(centralT)
            positions[centralKey] = GraphPoint(x: x, y: assignLane(x: x, forceCentre: true))
        }

        let sortedDated = dated
            .filter { $0.id != centralKey }
            .sorted {
                let a = dateValues[$0.id] ?? 0, b = dateValues[$1.id] ?? 0
                return a == b ? $0.id < $1.id : a < b
            }
        for node in sortedDated {
            guard let t = dateValues[node.id] else { continue }
            let x = xPosition(t)
            positions[node.id] = GraphPoint(x: x, y: assignLane(x: x, forceCentre: false))
        }

        // --- Parking column for undated nodes and clusters ---
        // Dated nodes without a position were excluded by the brush domain and
        // must stay hidden, not parked.
        let parked = nodes
            .filter { positions[$0.id] == nil && dateValues[$0.id] == nil }
            .sorted { $0.id < $1.id }
        var parkX = canvasWidth - 44
        var parkY = yTop + 8
        for node in parked {
            positions[node.id] = GraphPoint(x: parkX, y: parkY)
            parkY += 52
            if parkY > yBottom {
                parkY = yTop + 8
                parkX -= 46
            }
        }

        // --- Axis ticks ---
        // The range's upper end is kept at or above its lower one (#1893): below 116 pt it would fall
        // under it, and a `ClosedRange` with crossed ends traps. From 116 pt the range is as it was.
        let ticks = Self.timelineTicks(
            minT: minT, maxT: maxT,
            xPosition: xPosition,
            visibleRange: (padLeading - 8)...max(canvasWidth - padTrailing + 28, padLeading - 8)
        )

        return (positions, ticks, axisY, !parked.isEmpty)
    }

    /// Builds adaptive axis ticks for the timeline layout: yearly ticks for
    /// multi-year spans, monthly for multi-month, daily for tighter spans.
    private static func timelineTicks(
        minT: TimeInterval,
        maxT: TimeInterval,
        xPosition: (TimeInterval) -> Double,
        visibleRange: ClosedRange<Double>
    ) -> [TimelineTick] {
        let calendar = Calendar(identifier: .gregorian)
        let minDate = Date(timeIntervalSinceReferenceDate: minT)
        let maxDate = Date(timeIntervalSinceReferenceDate: maxT)
        let spanDays = (maxT - minT) / 86_400

        var ticks: [TimelineTick] = []

        func append(_ date: Date, label: String) {
            let x = xPosition(date.timeIntervalSinceReferenceDate)
            guard visibleRange.contains(x) else { return }
            ticks.append(TimelineTick(x: x, label: label))
        }

        if spanDays > 1_100 {
            // Year ticks (≈3+ years of span).
            let minYear = calendar.component(.year, from: minDate)
            let maxYear = calendar.component(.year, from: maxDate)
            let step = max(1, Int(ceil(Double(maxYear - minYear + 1) / 6.0)))
            var year = minYear
            while year <= maxYear + 1 {
                if let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                    append(date, label: String(year))
                }
                year += step
            }
        } else if spanDays > 45 {
            // Month ticks.
            let monthFormatter = DateFormatter()
            monthFormatter.calendar = calendar
            monthFormatter.setLocalizedDateFormatFromTemplate("MMM")
            let monthYearFormatter = DateFormatter()
            monthYearFormatter.calendar = calendar
            monthYearFormatter.setLocalizedDateFormatFromTemplate("MMM y")

            var monthStarts: [Date] = []
            var cursorComps = calendar.dateComponents([.year, .month], from: minDate)
            cursorComps.day = 1
            var cursor = calendar.date(from: cursorComps) ?? minDate
            while cursor <= maxDate, monthStarts.count < 240 {
                monthStarts.append(cursor)
                cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? maxDate.addingTimeInterval(1)
            }
            let step = [1, 2, 3, 6].first { monthStarts.count / $0 <= 7 } ?? 12
            for (index, date) in monthStarts.enumerated() where index % step == 0 {
                let isJanuary = calendar.component(.month, from: date) == 1
                let formatter = (index == 0 || isJanuary) ? monthYearFormatter : monthFormatter
                append(date, label: formatter.string(from: date))
            }
        } else {
            // Day ticks.
            let dayFormatter = DateFormatter()
            dayFormatter.calendar = calendar
            dayFormatter.setLocalizedDateFormatFromTemplate("MMM d")
            let stepDays = max(1, Int(ceil(spanDays / 6.0)))
            var cursor = calendar.startOfDay(for: minDate)
            while cursor <= maxDate {
                append(cursor, label: dayFormatter.string(from: cursor))
                cursor = calendar.date(byAdding: .day, value: stepDays, to: cursor)
                    ?? maxDate.addingTimeInterval(1)
            }
        }
        return ticks
    }

    // MARK: - Reference list order (#1764)

    /// Whether `a` comes before `b` in a section of the reference list, and in the graph's VoiceOver
    /// list (#1764, the owner's decision of 2026-11-01): every document before every page node, the
    /// documents in catalogue order — by volume, then by printed number — and the pages by volume,
    /// then page.
    ///
    /// Until #1764 both lists showed their nodes in the order the display builder made them, by the
    /// key `volume/document` as a string, so a page node in an earlier volume came first: at three
    /// hops from `frus1952-54v02p1` d16, Cited By This Document opened on `frus1948v01p2/pg_507`,
    /// which opens nothing (#1799), and listed d11, d41, d5. Volumes and numbers compare as the
    /// collection bibliography compares them (`CollectionGeneratedBlocks`), the way Finder compares
    /// names, so d5 comes before d41 and `373a` between 373 and 374. A document with no printed number
    /// comes after its volume's numbered ones, by its id; a volume cluster takes its volume's place.
    /// - Parameters:
    ///   - a: A node of the section.
    ///   - b: Another node of the section.
    /// - Returns: Whether `a` is listed first.
    public nonisolated static func precedesInReferenceList(_ a: DisplayNode, _ b: DisplayNode) -> Bool {
        if a.isPageNode != b.isPageNode { return !a.isPageNode }
        if let order = finderOrder(a.volumeId ?? a.id, b.volumeId ?? b.id) { return order }
        switch (a.metadata?.documentNumber, b.metadata?.documentNumber) {
        case (let x?, let y?):
            if let order = finderOrder(x, y) { return order }
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): break
        }
        if let order = finderOrder(a.documentId ?? a.id, b.documentId ?? b.id) { return order }
        return a.id < b.id
    }

    /// Whether `a` comes before `b` as Finder orders names, or `nil` when the two are the same.
    /// Character order breaks a tie Finder's order leaves (`d05` and `d5`), so the order is total.
    private nonisolated static func finderOrder(_ a: String, _ b: String) -> Bool? {
        guard a != b else { return nil }
        switch a.localizedStandardCompare(b) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return a < b
        }
    }

    // MARK: - Display node builder

    /// Computes the `DisplayNode` and `DisplayEdge` arrays from a `CrossReferenceGraph`.
    /// When the raw degree-1 reference count exceeds 30, same-volume nodes are collapsed
    /// into cluster nodes unless their key is in `expandedClusterKeys`.
    ///
    /// **Aggregation & uniqueness** — the `cross_references` table stores one row per
    /// `<ref>` occurrence, so the same (source, target) document pair can appear many
    /// times and the same document can appear as both an inbound and an outbound
    /// neighbour. This builder:
    ///   - groups raw edges by (source, target) into a single `DisplayEdge` carrying
    ///     `referenceCount` and all context passages,
    ///   - emits each node key exactly once (first kind encountered wins; a document
    ///     that both cites and is cited by the centre keeps `.inbound`, and the two
    ///     directed edges still convey the bidirectionality),
    ///   - sorts groups by key so the output (and therefore the layout seeded from
    ///     it) is deterministic across visits.
    ///
    /// Extended edges (degree ≥ 2) are added after degree-1 edges. Extended nodes
    /// not already present in the degree-1 set are given `.extended` kind.
    public static func buildDisplayNodesAndEdges(
        graph: CrossReferenceGraph,
        centralKey: String,
        expandedClusterKeys: Set<String>,
        downloadedVolumeIds: Set<String>
    ) -> (nodes: [DisplayNode], edges: [DisplayEdge]) {
        let threshold = 30
        let useClusters = graph.inboundEdges.count + graph.outboundEdges.count > threshold

        var nodes: [DisplayNode] = [
            DisplayNode(
                id: centralKey, kind: .central,
                metadata: graph.nodeMetadata[centralKey],
                isDownloaded: downloadedVolumeIds.contains(graph.centralVolumeId),
                degree: 0
            )
        ]
        var edges: [DisplayEdge] = []
        var seenNodeKeys: Set<String> = [centralKey]

        /// Appends a node for `key` unless one already exists (dedupe across
        /// repeated references and across the inbound/outbound boundary).
        func appendNodeIfNeeded(key: String, kind: DisplayNode.Kind, volumeId: String) {
            guard seenNodeKeys.insert(key).inserted else { return }
            nodes.append(DisplayNode(
                id: key, kind: kind,
                metadata: graph.nodeMetadata[key],
                isDownloaded: downloadedVolumeIds.contains(volumeId),
                degree: 1
            ))
        }

        /// `.editorialNote` only when every aggregated reference is one.
        func aggregatedType(_ group: [CrossReferenceEdge]) -> ReferenceType {
            group.allSatisfy { $0.referenceType == .editorialNote } ? .editorialNote : .footnote
        }

        /// Adds one node + one aggregated edge per unique source document.
        func addAggregatedInbound(_ rawEdges: [CrossReferenceEdge]) {
            let bySource = Dictionary(grouping: rawEdges) {
                "\($0.sourceVolumeId)/\($0.sourceDocumentId)"
            }
            for (key, group) in bySource.sorted(by: { $0.key < $1.key }) {
                appendNodeIfNeeded(key: key, kind: .inbound, volumeId: group[0].sourceVolumeId)
                edges.append(DisplayEdge(
                    source: key, target: centralKey,
                    referenceType: aggregatedType(group),
                    contexts: group.compactMap(\.context),
                    referenceCount: group.count,
                    degree: 1
                ))
            }
        }

        /// Adds one node + one aggregated edge per unique target document.
        func addAggregatedOutbound(_ rawEdges: [CrossReferenceEdge]) {
            let byTarget = Dictionary(grouping: rawEdges) {
                "\($0.targetVolumeId)/\($0.targetDocumentId)"
            }
            for (key, group) in byTarget.sorted(by: { $0.key < $1.key }) {
                appendNodeIfNeeded(key: key, kind: .outbound, volumeId: group[0].targetVolumeId)
                edges.append(DisplayEdge(
                    source: centralKey, target: key,
                    referenceType: aggregatedType(group),
                    contexts: group.compactMap(\.context),
                    referenceCount: group.count,
                    degree: 1
                ))
            }
        }

        func addInbound(_ inboundEdges: [CrossReferenceEdge]) {
            guard useClusters else { return addAggregatedInbound(inboundEdges) }
            let byVol = Dictionary(grouping: inboundEdges, by: \.sourceVolumeId)
            for (vol, volEdges) in byVol.sorted(by: { $0.key < $1.key }) {
                let clusterKey = "cluster/inbound/\(vol)"
                if expandedClusterKeys.contains(clusterKey) {
                    addAggregatedInbound(volEdges)
                } else {
                    let docCount = Set(volEdges.map {
                        "\($0.sourceVolumeId)/\($0.sourceDocumentId)"
                    }).count
                    nodes.append(DisplayNode(id: clusterKey,
                        kind: .clusterInbound(volumeId: vol, count: docCount),
                        metadata: nil,
                        isDownloaded: downloadedVolumeIds.contains(vol),
                        degree: 1))
                    edges.append(DisplayEdge(source: clusterKey, target: centralKey,
                        referenceType: .footnote, contexts: [],
                        referenceCount: volEdges.count, degree: 1))
                }
            }
        }

        func addOutbound(_ outboundEdges: [CrossReferenceEdge]) {
            guard useClusters else { return addAggregatedOutbound(outboundEdges) }
            let byVol = Dictionary(grouping: outboundEdges, by: \.targetVolumeId)
            for (vol, volEdges) in byVol.sorted(by: { $0.key < $1.key }) {
                let clusterKey = "cluster/outbound/\(vol)"
                if expandedClusterKeys.contains(clusterKey) {
                    addAggregatedOutbound(volEdges)
                } else {
                    let docCount = Set(volEdges.map {
                        "\($0.targetVolumeId)/\($0.targetDocumentId)"
                    }).count
                    nodes.append(DisplayNode(id: clusterKey,
                        kind: .clusterOutbound(volumeId: vol, count: docCount),
                        metadata: nil,
                        isDownloaded: downloadedVolumeIds.contains(vol),
                        degree: 1))
                    edges.append(DisplayEdge(source: centralKey, target: clusterKey,
                        referenceType: .footnote, contexts: [],
                        referenceCount: volEdges.count, degree: 1))
                }
            }
        }

        addInbound(graph.inboundEdges)
        addOutbound(graph.outboundEdges)

        // --- Extended edges (degree 2+) ---
        // Aggregated by (source, target) pair just like degree-1 edges. A node that
        // was already present at degree 1 keeps its degree-1 kind; new nodes become
        // `.extended`.
        if !graph.extendedEdges.isEmpty {
            let byPair = Dictionary(grouping: graph.extendedEdges) {
                "\($0.sourceVolumeId)/\($0.sourceDocumentId)->\($0.targetVolumeId)/\($0.targetDocumentId)"
            }
            for (_, group) in byPair.sorted(by: { $0.key < $1.key }) {
                let first  = group[0]
                let srcKey = "\(first.sourceVolumeId)/\(first.sourceDocumentId)"
                let tgtKey = "\(first.targetVolumeId)/\(first.targetDocumentId)"

                for (key, vol) in [(srcKey, first.sourceVolumeId), (tgtKey, first.targetVolumeId)]
                where !seenNodeKeys.contains(key) {
                    seenNodeKeys.insert(key)
                    nodes.append(DisplayNode(
                        id: key, kind: .extended,
                        metadata: graph.nodeMetadata[key],
                        isDownloaded: downloadedVolumeIds.contains(vol),
                        degree: graph.fetchedDegree
                    ))
                }

                edges.append(DisplayEdge(
                    source: srcKey, target: tgtKey,
                    referenceType: aggregatedType(group),
                    contexts: group.compactMap(\.context),
                    referenceCount: group.count,
                    degree: graph.fetchedDegree
                ))
            }
        }

        return (nodes, edges)
    }

    // MARK: - What the graph saves (#1990)

    /// What the graph's two saves take, *Save as Working Corpus* and *Add to Archives Visit*: every
    /// document the graph holds as drawn (decision 180), with which of them the graph draws an archival
    /// node for.
    ///
    /// **As drawn** is the graph at the depth it was loaded at, every document a volume cluster or a
    /// timeline's date cluster stands for, and the documents in volumes this device has not downloaded,
    /// which the graph draws too. A page node is not a document (#1799): the set leaves it out and
    /// counts it. Where a range is brushed on a timeline, a document dated outside it is left out, as the
    /// timeline leaves it off the canvas, and an undated one stays, as the timeline parks it in its
    /// Undated column; a volume cluster's documents are held to the range by their own dates, which is
    /// what the timeline would draw with the cluster open. The set is the same whichever clusters the
    /// reader has opened.
    ///
    /// The archival units and central-file classes are not documents and neither save takes them. They
    /// are reported for the visit's line, by the documents in the set whose footnotes the graph draws
    /// them for: one hangs off its citing document by an edge (``attachingUnits(_:to:edges:)``).
    ///
    /// The order is the graph's own: the central document, its direct references, then those further
    /// out, as the display build makes them, with a volume cluster's documents in its place by key. A
    /// working corpus's budget keeps the first of them (``WorkingCorpusCapture``), so the nearest come
    /// first; no graph the records name comes near it, the largest having 1,259 nodes.
    ///
    /// - Parameters:
    ///   - nodes: The graph's nodes as built, with their archival nodes attached: the view model's
    ///     `baseDisplayNodes`, never the timeline's displayed nodes, whose date clusters fold documents.
    ///     A date cluster among them is read through its members.
    ///   - edges: The edges built with them, which tie each archival node to its citing document.
    ///   - graph: The loaded graph, whose direct references give a volume cluster's documents.
    ///   - dateValues: Each node's date value (``buildDateValues(for:)``).
    ///   - dateWindow: The brushed range the timeline draws within, or `nil` when no range is brushed or
    ///     the network is drawn.
    /// - Returns: What the two saves take.
    public static func capture(nodes: [DisplayNode], edges: [DisplayEdge], graph: CrossReferenceGraph,
                               dateValues: [String: TimeInterval],
                               dateWindow: ClosedRange<TimeInterval>?) -> CrossReferenceGraphCapture {
        var keys: [String] = []
        var kept = Set<String>()
        var pages = Set<String>()

        /// Takes one document by its key, unless the brushed range leaves it out or it is a page.
        func take(_ key: String, isPage: Bool, dateValue: TimeInterval?) {
            if let dateWindow, let dateValue, !dateWindow.contains(dateValue) { return }
            if isPage {
                pages.insert(key)
            } else if kept.insert(key).inserted {
                keys.append(key)
            }
        }

        /// A volume cluster's documents, by key, with their dates as the timeline would give them open.
        func takeCluster(_ memberKeys: [String]) {
            let members = memberKeys.map {
                DisplayNode(id: $0, kind: .inbound, metadata: graph.nodeMetadata[$0], isDownloaded: true)
            }
            let values = buildDateValues(for: members)
            for member in members {
                take(member.id, isPage: member.isPageNode, dateValue: values[member.id])
            }
        }

        for node in nodes {
            switch node.kind {
            case .central, .inbound, .outbound, .extended:
                take(node.id, isPage: node.isPageNode, dateValue: dateValues[node.id])
            case .clusterInbound(let volumeId, _):
                takeCluster(Set(graph.inboundEdges.lazy.filter { $0.sourceVolumeId == volumeId }
                    .map { "\($0.sourceVolumeId)/\($0.sourceDocumentId)" }).sorted())
            case .clusterOutbound(let volumeId, _):
                takeCluster(Set(graph.outboundEdges.lazy.filter { $0.targetVolumeId == volumeId }
                    .map { "\($0.targetVolumeId)/\($0.targetDocumentId)" }).sorted())
            case .dateCluster(_, _, let memberKeys):
                // A date cluster folds the timeline's dated documents, all inside any brushed range.
                for key in memberKeys {
                    let documentId = graph.nodeMetadata[key]?.documentId
                        ?? key.split(separator: "/", maxSplits: 1).last.map(String.init) ?? key
                    take(key, isPage: documentId.hasPrefix("pg_"), dateValue: dateValues[key])
                }
            case .unit, .centralFileClass:
                continue
            }
        }

        // Each archival node's citing document, by the edge that ties them.
        let archivalIds = Set(nodes.lazy.filter(\.terminatesWalk).map(\.id))
        var citingDocument: [String: String] = [:]
        for edge in edges where archivalIds.contains(edge.target) && citingDocument[edge.target] == nil {
            citingDocument[edge.target] = edge.source
        }
        var unitIds: [String] = []
        var classKeys: [String] = []
        var seenUnits = Set<String>()
        var seenClasses = Set<String>()
        var citing = Set<String>()
        for node in nodes where node.terminatesWalk {
            guard let document = citingDocument[node.id], kept.contains(document) else { continue }
            citing.insert(document)
            switch node.kind {
            case .unit(let collectionId, _):
                if seenUnits.insert(collectionId).inserted { unitIds.append(collectionId) }
            case .centralFileClass(let key, _):
                if seenClasses.insert(key).inserted { classKeys.append(key) }
            default:
                break
            }
        }

        return CrossReferenceGraphCapture(
            documentKeys: keys,
            pageCount: pages.count,
            documentsWithArchivalNodes: keys.filter { citing.contains($0) },
            unitIds: unitIds,
            classKeys: classKeys,
            depth: graph.fetchedDegree,
            dateWindow: dateWindow)
    }
}

// MARK: - CrossReferenceGraphCapture

/// What the cross-reference graph's two saves take (#1990, decisions 180 and 181), as
/// ``CrossReferenceGraphDisplay/capture(nodes:edges:graph:dateValues:dateWindow:)`` reads it from the
/// graph, and the words each save says it in.
///
/// *Save as Working Corpus* writes ``documentKeys`` as a corpus (``workingCorpus(documentLabel:stamp:)``),
/// and *Add to Archives Visit* adds the same documents to a plan as its seeds, both halves on
/// (decision 181), through `ArchiveVisitPlanWrites.addingSeeds`, the one write every add flow shares.
///
/// Version history:
///   1.0 — 2026-11-27 (#1990, L42): initial implementation
///   1.1 — 2026-11-28 (L63, decision 235): the visit's line says the graph's central-file classes are among
///          the visit's targets, since its footnote channel takes the class
public struct CrossReferenceGraphCapture: Equatable, Sendable {

    /// Every document the graph holds as drawn, as `"volumeId/documentId"` keys, each once, in the
    /// graph's order.
    public let documentKeys: [String]
    /// How many page nodes the graph holds in the same reach, which neither save takes.
    public let pageCount: Int
    /// The documents of ``documentKeys`` whose footnotes the graph draws an archival node for, in the
    /// same order.
    public let documentsWithArchivalNodes: [String]
    /// The collection-authority records the graph's archival units stand for, each once, in the
    /// graph's order. A unit cited by several documents is one node for each and one record here.
    public let unitIds: [String]
    /// The central-file classes the graph's class nodes stand for, each once, in the graph's order.
    public let classKeys: [String]
    /// How many hops out the graph holds documents: the depth it was loaded at, two where a sparse
    /// graph was widened (``CrossReferenceGraphDisplay/widensSparseGraph(loadedAtDegree:edgeCount:)``).
    public let depth: Int
    /// The brushed range that narrowed the set, or `nil`.
    public let dateWindow: ClosedRange<TimeInterval>?

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(documentKeys: [String], pageCount: Int, documentsWithArchivalNodes: [String],
                unitIds: [String], classKeys: [String], depth: Int,
                dateWindow: ClosedRange<TimeInterval>?) {
        self.documentKeys = documentKeys
        self.pageCount = pageCount
        self.documentsWithArchivalNodes = documentsWithArchivalNodes
        self.unitIds = unitIds
        self.classKeys = classKeys
        self.depth = depth
        self.dateWindow = dateWindow
    }

    /// How many documents the saves take.
    public var documentCount: Int { documentKeys.count }

    /// The documents as a visit's seeds, `(volumeId, documentId)`, in the same order.
    public var seeds: [(volumeId: String, documentId: String)] {
        documentKeys.compactMap { key in
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
    }

    // MARK: Words

    /// The graph's central document as both saves name it: its volume and its printed number,
    /// "frus1952-54v02p1, Doc. 16" (the graph's own `graph.node.docNumber %@`), or its id where it prints
    /// none.
    ///
    /// - Parameters:
    ///   - volumeId: The central document's volume.
    ///   - documentId: Its id.
    ///   - documentNumber: Its printed number, or `nil`.
    /// - Returns: The label.
    public static func documentLabel(volumeId: String, documentId: String, documentNumber: String?) -> String {
        let number = documentNumber.flatMap { $0.isEmpty ? nil : $0 }
        let document = number.map {
            String(format: String(localized: "graph.node.docNumber %@", defaultValue: "Doc. %@"), $0)
        } ?? documentId
        return "\(volumeId), \(document)"
    }

    /// The depth in words: "one hop", "two hops", "three hops".
    public var depthPhrase: String {
        switch depth {
        case ...1: String(localized: "graph.save.depth.one", defaultValue: "one hop")
        case 2: String(localized: "graph.save.depth.two", defaultValue: "two hops")
        case 3: String(localized: "graph.save.depth.three", defaultValue: "three hops")
        default: CountCopy.phrase(depth, one: String(localized: "graph.save.depth.n.one", defaultValue: "%@ hop"),
                                  many: String(localized: "graph.save.depth.n.many", defaultValue: "%@ hops"))
        }
    }

    /// The brushed range in words, its two days ("Mar 4, 1950 – Jun 30, 1952"), or `nil` when none is
    /// brushed. Days in a Gregorian calendar in the process's time zone and locale, as the graph's dates
    /// are (``CrossReferenceGraphDisplay``).
    public var dateWindowPhrase: String? {
        guard let dateWindow else { return nil }
        let formatter = DateIntervalFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateTemplate = "MMM d y"
        return formatter.string(from: Date(timeIntervalSinceReferenceDate: dateWindow.lowerBound),
                                to: Date(timeIntervalSinceReferenceDate: dateWindow.upperBound))
    }

    /// What the set is, as a name begins and a new visit is named: "Cross-references of
    /// frus1952-54v02p1, Doc. 16".
    ///
    /// - Parameter documentLabel: The central document (``documentLabel(volumeId:documentId:documentNumber:)``).
    /// - Returns: The subject.
    public static func subject(documentLabel: String) -> String {
        String(format: String(localized: "graph.save.subject %@", defaultValue: "Cross-references of %@"),
               documentLabel)
    }

    /// Where the set came from, as a corpus records it: the graph's document and its depth, and the
    /// brushed range where one narrowed it, which is enough to draw the same graph again by hand.
    ///
    /// - Parameter documentLabel: The central document (``documentLabel(volumeId:documentId:documentNumber:)``).
    /// - Returns: The description.
    public func sourceDescription(documentLabel: String) -> String {
        dated(String(format: String(localized: "graph.save.source %@ %@",
                                    defaultValue: "Cross-reference graph of %1$@, at %2$@"),
                     documentLabel, depthPhrase))
    }

    /// `text` with the brushed range after it, where one narrowed the set.
    private func dated(_ text: String) -> String {
        guard let range = dateWindowPhrase else { return text }
        return String(format: String(localized: "graph.save.source.dated %@ %@",
                                     defaultValue: "%1$@, dated %2$@"), text, range)
    }

    /// The working corpus the graph saves: its documents, named for its central document with the
    /// capture's stamp (``WorkingCorpusCapture/name(subject:stamp:)``), and described by
    /// ``sourceDescription(documentLabel:)``.
    ///
    /// - Parameters:
    ///   - documentLabel: The central document (``documentLabel(volumeId:documentId:documentNumber:)``).
    ///   - stamp: When the save is made (``WorkingCorpusCapture/stamp(for:locale:timeZone:)``).
    /// - Returns: The capture.
    public func workingCorpus(documentLabel: String, stamp: String) -> WorkingCorpusCapture {
        WorkingCorpusCapture(
            name: WorkingCorpusCapture.name(subject: Self.subject(documentLabel: documentLabel), stamp: stamp),
            keys: documentKeys,
            sourceDescription: sourceDescription(documentLabel: documentLabel))
    }

    /// What either save says when the graph holds no document to save, which only a brushed range that
    /// takes in no dated document and no undated one can leave: the central document is always held
    /// otherwise.
    public static var nothingToSave: String {
        String(localized: "graph.save.empty",
               defaultValue: "The graph holds no document within the brushed dates, so there is nothing to save.")
    }

    /// What the saves leave out of what the graph holds, said before each: its page nodes, which are not
    /// documents. `nil` when it holds none.
    ///
    /// - Parameter locale: The locale that groups the count.
    /// - Returns: The sentence, or `nil`.
    public func pagesNote(locale: Locale = .autoupdatingCurrent) -> String? {
        guard pageCount > 0 else { return nil }
        return CountCopy.phrase(
            pageCount,
            one: String(localized: "graph.save.pages.one %@",
                        defaultValue: "The graph’s %@ cited page is not a document and is left out."),
            many: String(localized: "graph.save.pages.many %@",
                         defaultValue: "The graph’s %@ cited pages are not documents and are left out."),
            locale: locale)
    }

    // MARK: The visit's line

    /// The picker's line for *Add to Archives Visit*: where the documents come from, how many targets
    /// they give a visit on this device, and that the graph's central-file classes are among them.
    ///
    /// **A visit lists more than the graph draws.** It keys every lot and library a seed's footnotes cite,
    /// joined to the collection authority or not, where the graph draws a unit only for a citation that
    /// joins (``CrossReferenceGraphDisplay/unitNodes(rowsByDocument:authority:)``); with the source half on
    /// it lists the file each seed's own source note names; and it lists every central-file class a seed's
    /// footnotes cite, as the graph draws a class node for each (L63, decision 235). Until L63 the packet's
    /// footnote channel left the class out, and this line said how many of the graph's classes a seed's
    /// own source note named: 5 of 8 for `frus1952-54v02p1` d16 at three hops. It now says the graph's
    /// classes are among the targets, as the packet it read lists them, and how many where it lists fewer,
    /// which only a volume indexed again between the graph's read and the line's could leave.
    ///
    /// The picker shows the line after its own words, "Adding 143 documents: archival sources +
    /// unprinted references — ", so it begins in lower case, as the other surfaces' lines do ("from the
    /// collection “Berlin 1948”"). Without a preview, where the device has no index to read the packet
    /// from, it says where the documents come from and no more.
    ///
    /// - Parameters:
    ///   - documentLabel: The central document (``documentLabel(volumeId:documentId:documentNumber:)``).
    ///   - preview: What the documents give a visit, read from the packet they derive, or `nil`.
    ///   - locale: The locale that groups the counts.
    /// - Returns: The line, which the picker shows after its count of documents.
    public func visitBasis(documentLabel: String, preview: CrossReferenceGraphVisitPreview?,
                           locale: Locale = .autoupdatingCurrent) -> String {
        var sentences = [dated(String(format: String(localized: "graph.save.visit.source %@ %@",
                                                     defaultValue: "from the cross-reference graph of %1$@, at %2$@"),
                                      documentLabel, depthPhrase))]
        if let preview {
            let targets = CountCopy.phrase(
                preview.targetCount,
                one: String(localized: "graph.save.visit.targets.one %@", defaultValue: "%@ target"),
                many: String(localized: "graph.save.visit.targets.many %@", defaultValue: "%@ targets"),
                locale: locale)
            if preview.indexedSeedCount < documentCount {
                sentences.append(String(format: String(
                    localized: "graph.save.visit.partial %@ %@",
                    defaultValue: "On this device a visit of these documents lists %1$@, from the %2$@ indexed here"),
                    targets, CountCopy.documents(preview.indexedSeedCount, locale: locale)))
            } else {
                sentences.append(String(format: String(
                    localized: "graph.save.visit.whole %@",
                    defaultValue: "On this device a visit of these documents lists %@"), targets))
            }
            if !classKeys.isEmpty, preview.classesListed >= classKeys.count {
                sentences.append(CountCopy.phrase(
                    classKeys.count,
                    one: String(localized: "graph.save.visit.classes.listed.one %@",
                                defaultValue: "The graph’s %@ central-file class is among them"),
                    many: String(localized: "graph.save.visit.classes.listed.many %@",
                                 defaultValue: "The graph’s %@ central-file classes are among them"),
                    locale: locale))
            } else if !classKeys.isEmpty {
                // The form follows the graph's classes, and the listed count is the verb's object, so
                // no verb has to agree with it.
                sentences.append(CountCopy.phrase(
                    classKeys.count,
                    one: String(localized: "graph.save.visit.classes.partial.one %@ %@",
                                defaultValue: "Of the graph’s %1$@ central-file class, it lists %2$@"),
                    many: String(localized: "graph.save.visit.classes.partial.many %@ %@",
                                 defaultValue: "Of the graph’s %1$@ central-file classes, it lists %2$@"),
                    then: [preview.classesListed.formatted(.number.locale(locale))],
                    locale: locale))
            }
        }
        return sentences.joined(separator: ". ") + "."
    }

    /// The name a visit made from the picker's New row takes: the set's subject, with no stamp, since a
    /// visit is not looked up by its name.
    ///
    /// - Parameter documentLabel: The central document (``documentLabel(volumeId:documentId:documentNumber:)``).
    /// - Returns: The suggested name.
    public static func visitName(documentLabel: String) -> String {
        subject(documentLabel: documentLabel)
    }

    /// What *Add to Archives Visit* did, said after it, as Add to Collection says it (L19).
    ///
    /// - Parameters:
    ///   - documentCount: How many documents were added.
    ///   - planName: The visit's name as its list shows it.
    ///   - locale: The locale that groups the count.
    /// - Returns: The sentence the graph shows and VoiceOver hears.
    public static func visitOutcome(documentCount: Int, planName: String,
                                    locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            documentCount,
            one: String(localized: "graph.save.visit.added.one %@ %@",
                        defaultValue: "Added %1$@ document to “%2$@”"),
            many: String(localized: "graph.save.visit.added.many %@ %@",
                         defaultValue: "Added %1$@ documents to “%2$@”"),
            then: [planName], locale: locale)
    }
}

// MARK: - CrossReferenceGraphVisitPreview

/// What an Archives Visit seeded from the graph's documents would list, read before the write from the
/// packet those documents derive on this device (`TripPacketBuilder.build`, both halves on), for the
/// picker's line (``CrossReferenceGraphCapture/visitBasis(documentLabel:preview:locale:)``).
///
/// Version history:
///   1.0 — 2026-11-27 (#1990, L42): initial implementation
///   1.1 — 2026-11-28 (L63, decision 235): documentation only — a footnote's class is a target, so
///          `classesListed` counts every class the graph draws
public struct CrossReferenceGraphVisitPreview: Equatable, Sendable {

    /// How many targets the documents give: what a new visit of them lists.
    public let targetCount: Int
    /// How many of the graph's central-file classes are among those targets (`class|<key>`, the key both
    /// channels give a class since L63): all of them, unless a volume was indexed again between the
    /// graph's read and the preview's.
    public let classesListed: Int
    /// How many of the documents are in volumes indexed on this device, the only ones the packet reads.
    public let indexedSeedCount: Int

    /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
    public init(targetCount: Int, classesListed: Int, indexedSeedCount: Int) {
        self.targetCount = targetCount
        self.classesListed = classesListed
        self.indexedSeedCount = indexedSeedCount
    }

    /// The preview of `capture`'s documents, from the packet they derive.
    ///
    /// - Parameters:
    ///   - model: The packet built from the capture's documents, both halves on.
    ///   - capture: What the graph saves.
    ///   - indexedVolumeIds: The volumes this device has indexed.
    public init(model: TripPacketModel, capture: CrossReferenceGraphCapture, indexedVolumeIds: Set<String>) {
        let targetKeys = Set(model.targets.map(\.key))
        self.targetCount = model.targets.count
        self.classesListed = capture.classKeys.count { targetKeys.contains("class|\($0)") }
        self.indexedSeedCount = WorkingCorpusResolver(indexedVolumeIds: indexedVolumeIds)
            .resolve(documentKeys: capture.documentKeys).indexedCount
    }
}
