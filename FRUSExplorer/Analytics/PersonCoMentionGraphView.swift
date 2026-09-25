// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - PersonCoMentionNode

/// One node in the co-mention ego graph: the focus person or one of their partners (CA-8).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonCoMentionNode: Identifiable, Equatable {
    /// The rollup id (the People-browser identity), unique within the graph.
    let rollupId: Int
    /// The person's canonical display name.
    let name: String
    /// Shared-document count with the focus person (`0` for the focus node itself).
    let sharedWithFocus: Int

    var id: Int { rollupId }
}

// MARK: - PersonCoMentionEdge

/// One weighted edge in the co-mention ego graph: two rollups sharing `sharedDocuments`
/// documents (CA-8). `a`/`b` are rollup ids; the pair is undirected.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonCoMentionEdge: Equatable {
    /// One endpoint rollup id.
    let a: Int
    /// The other endpoint rollup id.
    let b: Int
    /// Distinct documents mentioning both endpoints (the edge weight).
    let sharedDocuments: Int
}

// MARK: - GraphLabelRequest

/// One node label waiting to be placed by `GraphNodeLabels.place(_:)` (#1384): the node it names,
/// where that node's disc is drawn, and how big the label measured.
///
/// Version history:
///   1.0 — #1384: initial implementation
///   1.1 — #1384 review: `shape`, so the archival network's class squares are kept clear of whole
struct GraphLabelRequest<ID: Hashable>: Equatable {

    /// The outline a node is drawn with, which decides what "clear of its disc" means.
    enum Shape: Equatable {
        /// A circle of `radius` — every node in the co-mention and volume graphs, and a
        /// collection in the archival network.
        case disc
        /// A square reaching `radius` from the centre on each side — the archival network's class
        /// node, drawn as a rounded square inside it, so a label kept clear of the square is clear
        /// of the rounded corners too. A disc of the same radius would leave those corners out.
        case square
    }

    /// The node the label names.
    let id: ID
    /// The centre of the node's disc on the canvas.
    let center: CGPoint
    /// The radius of the node's disc as drawn — its fill, or half a square's side. A white ring,
    /// where one is drawn, lies within `GraphNodeLabels.clearance` of it.
    let radius: CGFloat
    /// The node's outline: `.disc` unless the canvas draws it square.
    var shape: Shape = .disc
    /// The label's measured size (`GraphicsContext.ResolvedText.measure(in:)` on the canvas).
    let size: CGSize
}

// MARK: - GraphNodeLabels

/// The node-label rules the co-mention, volume connection and archival network graphs share
/// (#1384): how a long name is cut, where its label goes, and which labels are drawn at all.
///
/// Before #1384 all three graphs drew every label centred under its node, cut to a fixed number of
/// characters, and nothing kept two labels apart. The Mac capture drew "Bruce, David K" and
/// "Truman, Harry" end to end as one string, and "Kennan, George" over "Bohlen, Charle". Now a cut
/// ends in "…", and labels are placed in priority order — the focus's first — each only where it
/// keeps clear of every label already placed and of every other node's disc. A label that does not
/// fit is not drawn, the focus's included. A partner's full name stays in its node's VoiceOver
/// label and in the dock or panel that a click, a tap or (on the Mac) a hover opens; the focus's
/// stays in the bar or chip above the graph, or in that dock's or panel's counts.
///
/// Version history:
///   1.0 — #1384: initial implementation
///   1.1 — #1384 review: the first label obeys the rules every other label does (the plate it was
///          drawn on across a disc is gone), and a `.square` node is kept clear of whole
enum GraphNodeLabels {

    /// The gap between a node's disc and the top of its label. Before #1384 each label was drawn
    /// centred 8 pt below its disc; measuring it lets the placement pin its top edge instead.
    static let spacing: CGFloat = 3

    /// The least space a placed label keeps from another placed label and from any node's disc.
    ///
    /// Two labels that merely touch read as one string ("Bruce, David KTruman, Harry"). The focus
    /// and the emphasised partner draw a white ring whose outer edge lies 2.75–3 pt outside the
    /// disc's fill, so a label kept this far from the fill may touch the focus's ring but never
    /// crosses it, and stays clear of a partner's.
    static let clearance: CGFloat = 3

    /// A node's label as drawn: `name` whole when it has at most `limit` characters, otherwise cut
    /// so that it has at most `limit` characters counting the "…" that ends it.
    ///
    /// The cut falls at the last word boundary within the limit — whitespace, with a comma,
    /// semicolon or colon left hanging before it dropped too — so "Bohlen, Charles E." at 14 reads
    /// "Bohlen…", never "Bohlen, Charl…". A period stays, since in a name it ends an initial
    /// ("Johnson, U.…"). With no boundary that leaves a word before it, as in a volume id, which
    /// has no spaces at all, the cut is hard ("frus1961-63…") and still marked.
    /// - Parameters:
    ///   - name: The node's full name.
    ///   - limit: The most characters the drawn label may have, the "…" included.
    /// - Returns: The label to draw.
    static func shortLabel(_ name: String, limit: Int) -> String {
        let characters = Array(name)
        guard characters.count > limit else { return name }
        // One character is held back for the "…", so a cut label never outgrows the limit.
        let room = max(1, limit - 1)
        // Whitespace at index `boundary` means the first `boundary` characters are whole words.
        for boundary in stride(from: room, through: 1, by: -1) where characters[boundary].isWhitespace {
            var words = characters[..<boundary]
            while let last = words.last, last.isWhitespace || ",;:".contains(last) {
                words.removeLast()
            }
            if !words.isEmpty { return String(words) + "…" }
        }
        return String(characters[..<room]) + "…"
    }

    /// The rect a request's label occupies: centred under its node, `spacing` below the disc.
    /// - Parameter request: The label to place.
    /// - Returns: The label's rect on the canvas.
    static func labelRect<ID: Hashable>(for request: GraphLabelRequest<ID>) -> CGRect {
        CGRect(x: request.center.x - request.size.width / 2,
               y: request.center.y + request.radius + spacing,
               width: request.size.width, height: request.size.height)
    }

    /// Chooses which labels to draw (#1384).
    ///
    /// Every label, in the order given — the graph's priority order, the focus's or the central
    /// volume's first — is placed only when its rect keeps `clearance` from every label already
    /// placed and from every OTHER node's disc: every node's, whether or not its own label was
    /// placed, since every disc is drawn. A label that fails is skipped, not moved, so a
    /// lower-ranked label can never displace a higher one.
    ///
    /// The first label is held to the disc rule like the rest, as #1384 and the open-issues plan
    /// (§3 A5) state the rule, with no exception. Ranking first only means no partner's label can
    /// take its place. The layout often puts a partner just under the centre, and then the focus
    /// goes unlabelled on the canvas: in both of `PersonCoMentionLabelTests`' laid-out graphs, and
    /// on an iPad capture of Stalin's network over seven 1945–48 volumes. Its name is still on
    /// screen outside the canvas: the archival network's Focus chip; Person Analytics' Focus bar,
    /// until Explore connections re-centres the graph inside it (the bar keeps the person it was
    /// opened on); and, while a partner is shown, the co-mention dock's "shared documents with"
    /// line and the volume panel's reference counts. The first version of this change exempted the
    /// first label and drew it on a plate of the background across the disc under it; review
    /// restored the rule.
    ///
    /// A label's own disc is excluded by position in `requests`, not left to the geometry: the rect
    /// starts exactly `radius + spacing` below the centre, and measuring that back can round below
    /// `radius + clearance`, which is the same distance. Measured at seven radii the co-mention and
    /// volume graphs draw (12, 15, 18, 22, 25, 26 and 28 pt), over centres from y = 48 to 699.9 pt
    /// in 0.1 pt steps, it did at 1,224 of the 45,640 positions; a node at y = 483.3 with a 26 pt
    /// disc finds it 28.999999999999943 pt away, not 29, and would drop its own label.
    /// - Parameter requests: One request per drawn node, highest priority first.
    /// - Returns: The rect of every label placed, keyed by its node's id.
    static func place<ID: Hashable>(_ requests: [GraphLabelRequest<ID>]) -> [ID: CGRect] {
        var placed: [ID: CGRect] = [:]
        var kept: [CGRect] = []
        for (index, request) in requests.enumerated() {
            let rect = labelRect(for: request)
            if kept.contains(where: { crowds(rect, $0) }) { continue }
            if requests.indices.contains(where: { $0 != index && covers(rect, disc: requests[$0]) }) {
                continue
            }
            kept.append(rect)
            placed[request.id] = rect
        }
        return placed
    }

    /// Whether two label rects come within `clearance` of each other — overlapping, touching end
    /// to end, or nearly so.
    private static func crowds(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX + clearance && b.minX < a.maxX + clearance
            && a.minY < b.maxY + clearance && b.minY < a.maxY + clearance
    }

    /// Whether a label rect comes within `clearance` of a node's outline: its disc, or for a
    /// `.square` node the whole square, corners included.
    private static func covers<ID: Hashable>(_ rect: CGRect, disc node: GraphLabelRequest<ID>) -> Bool {
        let dx = max(rect.minX - node.center.x, 0, node.center.x - rect.maxX)
        let dy = max(rect.minY - node.center.y, 0, node.center.y - rect.maxY)
        switch node.shape {
        case .disc:
            return hypot(dx, dy) < node.radius + clearance
        case .square:
            // The gap from the rect to the square's edges, `radius` out from the centre each way.
            return hypot(max(dx - node.radius, 0), max(dy - node.radius, 0)) < clearance
        }
    }
}

// MARK: - PersonCoMentionGraphViewModel

/// ViewModel for the person co-mention ego graph (CA-8).
///
/// Loads the focus person's top-N co-mentioned partners plus the partner-partner
/// co-mention edges from `PersonMentionStore`, then runs a pinned spring-repulsion layout
/// (a parallel of `VolumeConnectionGraphViewModel.runPhysics` — the two graph views each
/// carry their own layout engine; there is no shared engine to refactor into). The focus
/// person is pinned at the canvas centre while partner nodes settle around it.
///
/// ## Bound (decision CA-8-1)
/// The partner set is capped at `partnerLimit` — the disclosed top-N by shared-document
/// count. There is no silent truncation: when the cap bites the view says so. It cannot say by
/// how much. `totalPartnerCount` comes from a probe capped at `partnerLimit + 1`, so it is a
/// lower bound, and the footer reads "(of 25+)" rather than a total (#1385).
///
/// ## Hover and selection (#1383)
/// A click or tap pins or unpins a partner (`selectedPartnerId`, written only by
/// `toggleSelection(_:)` and `load`); on macOS the pointer previews one (`hoveredPartnerId`,
/// written by `hoverChanged(_:hovering:)`). The dock and node emphasis read `displayedPartnerId`.
///
/// ## Navigation
/// Explore connections, in the info dock or a node's context menu, re-centres the graph on that
/// person (changing the focus); a click or tap on a node only selects it, or deselects it when it
/// is the pinned one. A history stack supports back-navigation, mirroring the volume graph.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — #307: `zoom(by:)` — the multiplicative scroll-wheel zoom path, mirroring
///          `CrossReferenceGraphViewModel.zoom(by:)` for cross-graph parity
///   1.2 — #1383: hover (`hoveredPartnerId`) separated from the clicked selection, which only
///          `toggleSelection(_:)` writes; the dock and node emphasis read `displayedPartnerId`.
///          #1385: `capDisclosure`, and `totalPartnerCount` documented as the probe's lower bound
///   1.3 — #1384: the label rules the canvas places through `GraphNodeLabels` — `labelLimit`,
///          `labelPriority`, `label(for:)`, `labelRequests(sizes:)` — and `nodeRadius(for:)`, the
///          disc radius the canvas draws and the placement keeps clear of
@Observable
@MainActor
final class PersonCoMentionGraphViewModel {

    // MARK: - Configuration

    /// The disclosed top-N partner cap (decision CA-8-1). Mirrors the volume graph's degree
    /// limits — bounded so the physics and self-join stay fast and the canvas stays legible.
    static let partnerLimit = 24

    // MARK: - Data

    private(set) var focusRollupId: Int
    private(set) var focusName: String
    var nodes: [PersonCoMentionNode] = []
    var edges: [PersonCoMentionEdge] = []
    var isLoading = false
    var error: String? = nil

    /// A lower bound on the focus person's distinct partner count: the size of a probe capped at
    /// `partnerLimit + 1` (#1385). It is the true count while that is at most `partnerLimit`; once
    /// the cap bites it is always `partnerLimit + 1`, which is why the footer can say "of 25+"
    /// and never the total.
    private(set) var totalPartnerCount = 0

    // MARK: - Navigation

    private(set) var history: [(id: Int, name: String)] = []

    // MARK: - Interaction

    /// The partner the reader pinned by clicking (macOS) or tapping (iOS) its node. Only
    /// `toggleSelection(_:)` and `load` write it — never the pointer (#1383) — so the partner a
    /// reader clicked is still pinned when the pointer reaches the dock's buttons, whatever nodes
    /// it crossed on the way.
    private(set) var selectedPartnerId: Int? = nil

    /// The partner node under the pointer (macOS hover; never set on iOS). Transient:
    /// `hoverChanged(_:hovering:)` sets and clears it, and a click and a reload drop it.
    private(set) var hoveredPartnerId: Int? = nil

    /// The partner the info dock and the node emphasis show: the hovered one while the pointer is
    /// over a node, otherwise the pinned one (#1383). Hover previews and never pins, so the pinned
    /// partner is back the moment the pointer leaves the node, in time for the dock's buttons.
    ///
    /// Hover wins here, where `CrossReferenceGraphViewModel.resolvedNodeKey` lets the pinned node
    /// win. That graph's Session 162 note gives its reason: a hover whose exit never arrived
    /// masked every later click. Here a click drops the hover (`toggleSelection(_:)`), so a click
    /// is never masked, and #1383 asked for the preview.
    var displayedPartnerId: Int? { hoveredPartnerId ?? selectedPartnerId }

    /// The pointer entered (`hovering`) or left a partner node's hit area (#1383).
    ///
    /// Entry previews the node. Exit clears the preview only while it still names this node:
    /// two nodes' 48 pt hit areas can overlap, and an exit arriving after the next node's entry
    /// must not erase that node's preview. Never writes the selection.
    /// - Parameters:
    ///   - rollupId: The partner whose hit area the pointer entered or left.
    ///   - hovering: `true` on entry, `false` on exit.
    func hoverChanged(_ rollupId: Int, hovering: Bool) {
        if hovering {
            hoveredPartnerId = rollupId
        } else if hoveredPartnerId == rollupId {
            hoveredPartnerId = nil
        }
    }

    /// A click or tap on a partner node: pins it, or unpins it when it is the pinned one (#1383).
    ///
    /// It also drops the hover preview, so the dock shows what the click did at once: unpinning
    /// the node the pointer rests on empties the dock, rather than leaving it on that node's
    /// preview until the pointer moves off.
    /// - Parameter rollupId: The partner clicked.
    func toggleSelection(_ rollupId: Int) {
        selectedPartnerId = (selectedPartnerId == rollupId) ? nil : rollupId
        hoveredPartnerId = nil
    }

    /// The footer sentence shown while `capApplied` (#1385): "Showing the top 24 co-mentioned
    /// people (of 25+) by shared-document count."
    ///
    /// `totalPartnerCount` is the probe's lower bound, so here it always reads `partnerLimit + 1`
    /// and the "+" is the whole of what the view knows: that there are more.
    var capDisclosure: String {
        String(localized: "personCoMention.cap.disclosed",
               defaultValue: "Showing the top \(partners.count) co-mentioned people (of \(totalPartnerCount)+) by shared-document count.")
    }

    /// Pinch-to-zoom magnification applied to the canvas; `1.0` is neutral.
    var scale: CGFloat = 1.0
    /// Pan translation applied to the canvas; `.zero` is neutral.
    var panOffset: CGSize = .zero

    private(set) var steadyScale: CGFloat = 1.0
    private(set) var steadyPanOffset: CGSize = .zero

    // MARK: - Layout

    var nodePositions: [Int: CGPoint] = [:]

    // MARK: - Private

    private var canvasSize: CGSize = .zero
    private var layoutTask: Task<Void, Never>? = nil

    // MARK: - Init

    /// Creates the view model centred on `focusRollupId`.
    /// - Parameters:
    ///   - focusRollupId: The starting focus person's rollup id.
    ///   - focusName: The focus person's canonical name (for the centre label).
    init(focusRollupId: Int, focusName: String) {
        self.focusRollupId = focusRollupId
        self.focusName = focusName
    }

    // MARK: - Derived

    /// Partner nodes (everything but the focus), ordered by shared-document count desc.
    var partners: [PersonCoMentionNode] {
        nodes.filter { $0.rollupId != focusRollupId }
            .sorted { $0.sharedWithFocus != $1.sharedWithFocus
                ? $0.sharedWithFocus > $1.sharedWithFocus
                : $0.name < $1.name }
    }

    /// All rollup ids in the graph (focus first).
    var allRollupIds: [Int] { [focusRollupId] + partners.map(\.rollupId) }

    /// Whether the top-N cap actually elided partners (drives the disclosure text).
    var capApplied: Bool { totalPartnerCount > partners.count }

    /// The largest edge weight, for edge-thickness normalisation (never zero).
    var maxEdgeWeight: Int { edges.map(\.sharedDocuments).max() ?? 1 }

    /// The largest partner shared-with-focus count, for node-size normalisation.
    var maxSharedWithFocus: Int { max(1, partners.map(\.sharedWithFocus).max() ?? 1) }

    func name(for rollupId: Int) -> String {
        nodes.first { $0.rollupId == rollupId }?.name ?? ""
    }

    func sharedWithFocus(for rollupId: Int) -> Int {
        nodes.first { $0.rollupId == rollupId }?.sharedWithFocus ?? 0
    }

    var canNavigateBack: Bool { !history.isEmpty }

    // MARK: - Labels (#1384)

    /// The most characters a node's label may have, the "…" of a cut included.
    ///
    /// Sixteen, where every label was cut to fourteen before #1384: a trade between how much of a
    /// name each label says and how many labels fit, since a longer label crowds more neighbours
    /// and `GraphNodeLabels.place(_:)` drops the ones it crowds.
    ///
    /// The name a node draws is its rollup's canonical name: the bundled person authority's name
    /// for the person (`person-authority-index.json`'s `n`, "Kennan, George Frost") wherever the
    /// rollup has an authority id — the rollup builder prefers it — and otherwise the longest name
    /// a persons list gives them ("Kennan, George F."). Both are "Surname, Given". A word-boundary
    /// cut leaves a bare surname ("Kennan…") for 57.0% of the 12,836 authority names at fourteen,
    /// 29.3% at sixteen ("Kennan, George…") and 6.1% at twenty; over the 62,898 persons-list names
    /// in the 553 shippable volumes (tags stripped, whitespace folded) the figures are 56.7%, 29.8%
    /// and 5.5%. Over `PersonCoMentionLabelTests`' two laid-out graphs of 25 nodes, named as the
    /// authority stores them and sized by that suite's estimate rather than a font, the placement
    /// keeps 19 labels at fourteen, 17 at sixteen and 10 at twenty on a 700 × 520 canvas, and 20,
    /// 16 and 8 on a 360 × 420 one; the counts at sixteen are pinned there. Sixteen keeps a given
    /// name for most people at a cost of two to four labels.
    static let labelLimit = 16

    /// The radius of the focus node's disc.
    static let focusRadius: CGFloat = 26

    /// The radius a node's disc is drawn at, which the canvas and the label placement both read: the
    /// focus's fixed `focusRadius`, or a partner's 12–22 pt scaled by its shared documents with the
    /// focus, 3 pt more while it is the displayed partner (#1383).
    /// - Parameter rollupId: The node.
    /// - Returns: The disc's radius in points.
    func nodeRadius(for rollupId: Int) -> CGFloat {
        if rollupId == focusRollupId { return Self.focusRadius }
        let base = 12 + 10 * (CGFloat(sharedWithFocus(for: rollupId)) / CGFloat(maxSharedWithFocus))
        return displayedPartnerId == rollupId ? base + 3 : base
    }

    /// The order the labels are placed in (#1384): the focus, then the partner the dock shows
    /// (`displayedPartnerId` — the hovered one on the Mac, otherwise the pinned one), then the other
    /// partners by shared documents with the focus (the `partners` order).
    ///
    /// #1384 asked for the *selected* partner second. This ranks the displayed one, because that
    /// is the partner the dock names and the canvas emphasises (#1383), and its label now yields
    /// only to the focus's label or to a disc. On iOS, where nothing hovers, the two are the same
    /// partner.
    var labelPriority: [Int] {
        let ranked = partners.map(\.rollupId)
        return [focusRollupId]
            + ranked.filter { $0 == displayedPartnerId }
            + ranked.filter { $0 != displayedPartnerId }
    }

    /// The label a node draws: its name, cut to `labelLimit`.
    /// - Parameter rollupId: The node.
    /// - Returns: The label text.
    func label(for rollupId: Int) -> String {
        GraphNodeLabels.shortLabel(name(for: rollupId), limit: Self.labelLimit)
    }

    /// One placement request per laid-out node, in `labelPriority` order, for
    /// `GraphNodeLabels.place(_:)`. A node with no position or no measured size is left out, since
    /// the canvas draws neither its disc nor its label.
    /// - Parameter sizes: Each node's measured label size, keyed by rollup id.
    /// - Returns: The requests, highest priority first.
    func labelRequests(sizes: [Int: CGSize]) -> [GraphLabelRequest<Int>] {
        labelPriority.compactMap { id in
            guard let center = nodePositions[id], let size = sizes[id] else { return nil }
            return GraphLabelRequest(id: id, center: center, radius: nodeRadius(for: id), size: size)
        }
    }

    // MARK: - Viewport gestures

    /// Applies an in-flight pinch gesture value on top of the committed zoom level.
    func magnificationChanged(_ value: CGFloat) {
        scale = max(0.25, min(4.0, steadyScale * value))
    }

    /// Commits the current zoom level so the next pinch starts from it.
    func magnificationEnded() { steadyScale = scale }

    /// Applies a multiplicative zoom factor (> 1 zooms in) — the macOS scroll-wheel path (#307),
    /// mirroring `CrossReferenceGraphViewModel.zoom(by:)` so the two graphs feel identical.
    /// Commits immediately: wheel deltas arrive as a stream of small factors, not a gesture
    /// with a distinct end.
    func zoom(by factor: CGFloat) {
        steadyScale = max(0.25, min(4.0, steadyScale * factor))
        scale = steadyScale
    }

    /// Applies an in-flight drag translation on top of the committed pan offset.
    func panChanged(_ translation: CGSize) {
        panOffset = CGSize(width: steadyPanOffset.width + translation.width,
                           height: steadyPanOffset.height + translation.height)
    }

    /// Commits the current pan offset so the next drag continues from it.
    func panEnded() { steadyPanOffset = panOffset }

    /// Restores the pan/zoom viewport to its neutral state.
    /// - Parameter animated: When `true`, glides back with a spring.
    func resetViewport(animated: Bool) {
        guard scale != 1.0 || panOffset != .zero
                || steadyScale != 1.0 || steadyPanOffset != .zero else { return }
        steadyScale = 1.0
        steadyPanOffset = .zero
        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scale = 1.0
                panOffset = .zero
            }
        } else {
            scale = 1.0
            panOffset = .zero
        }
    }

    // MARK: - Load

    /// Loads the ego (focus + top-N partners + partner-partner edges) from the store, then
    /// runs the layout. Degrades to an empty graph on any query failure.
    /// - Parameter store: The person mention store.
    func load(from store: PersonMentionStore, volumeIds: [String]? = nil) async {
        isLoading = true
        error = nil
        nodes = []
        edges = []
        nodePositions = [:]
        selectedPartnerId = nil
        // The hit areas are rebuilt for the new ego, and a removed one is not guaranteed to
        // report the pointer's exit, so a hover would otherwise outlive its node.
        hoveredPartnerId = nil
        totalPartnerCount = 0
        resetViewport(animated: false)
        do {
            // The disclosed top-N partners (bounded to the focus person's own documents),
            // optionally restricted to the volume scope (#189-B).
            let partnerRows = try await store.topCoMentionedPeople(
                forRollupId: focusRollupId, limit: Self.partnerLimit, volumeIds: volumeIds)
            // A cheap over-limit probe: fetch one more than the cap to know whether the cap
            // actually elided anyone (so the disclosure is accurate), without an unbounded
            // count query.
            let probe = try await store.topCoMentionedPeople(
                forRollupId: focusRollupId, limit: Self.partnerLimit + 1, volumeIds: volumeIds)
            totalPartnerCount = probe.count

            var built: [PersonCoMentionNode] = [
                PersonCoMentionNode(rollupId: focusRollupId, name: focusName, sharedWithFocus: 0)
            ]
            for row in partnerRows {
                built.append(PersonCoMentionNode(rollupId: row.rollupId,
                                                 name: row.canonicalName,
                                                 sharedWithFocus: row.sharedDocuments))
            }
            nodes = built

            // Partner-partner edges + focus-partner edges, within the bounded ego set only.
            let ids = built.map(\.rollupId)
            let edgeRows = try await store.coMentionEdges(amongRollupIds: ids, volumeIds: volumeIds)
            edges = edgeRows.map { PersonCoMentionEdge(a: $0.a, b: $0.b, sharedDocuments: $0.sharedDocuments) }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        if canvasSize.width > 0 { rerunLayout(reduceMotion: false) }
    }

    // MARK: - Navigation

    /// Re-centres the graph on `rollupId`, pushing the current focus onto the history stack.
    ///
    /// Mutating `focusRollupId` re-fires the view's `.task(id:)`, which is the sole loader —
    /// this method must NOT call `load` itself, or the ego would load twice per navigation.
    func recenterOn(rollupId: Int) {
        guard rollupId != focusRollupId else { return }
        let newName = name(for: rollupId)
        history.append((id: focusRollupId, name: focusName))
        focusRollupId = rollupId
        focusName = newName
    }

    /// Pops the history stack and re-centres on the previous focus person.
    ///
    /// Mutating `focusRollupId` re-fires the view's `.task(id:)`, which is the sole loader —
    /// this method must NOT call `load` itself, or the ego would load twice per navigation.
    func navigateBack() {
        guard let prev = history.popLast() else { return }
        focusRollupId = prev.id
        focusName = prev.name
    }

    // MARK: - Canvas size / layout

    /// Reacts to a canvas-size change, (re)running the layout when a graph is present.
    func onCanvasSizeChanged(_ size: CGSize, reduceMotion: Bool) {
        canvasSize = size
        guard size.width > 0, size.height > 0, !partners.isEmpty else { return }
        rerunLayout(reduceMotion: reduceMotion)
    }

    private func rerunLayout(reduceMotion: Bool) {
        layoutTask?.cancel()
        let focus = focusRollupId
        let ids = allRollupIds
        let edgeList = edges
        let size = canvasSize
        guard ids.count > 1 else {
            nodePositions = [focus: CGPoint(x: size.width / 2, y: size.height / 2)]
            return
        }

        let cx = size.width / 2, cy = size.height / 2
        let r = min(size.width, size.height) * 0.35
        var initial: [Int: CGPoint] = [focus: CGPoint(x: cx, y: cy)]
        let partnerIds = ids.filter { $0 != focus }
        for (i, id) in partnerIds.enumerated() {
            let angle = 2 * Double.pi * Double(i) / Double(partnerIds.count)
            initial[id] = CGPoint(x: cx + r * CGFloat(cos(angle)),
                                  y: cy + r * CGFloat(sin(angle)))
        }

        // Reduce Motion (or a tiny graph): settle instantly, no animated relaxation.
        if reduceMotion || ids.count <= 3 {
            nodePositions = Self.runPhysics(
                ids: ids, centralId: focus, edges: edgeList,
                positions: initial, size: size, iterations: 300)
            return
        }

        nodePositions = initial
        layoutTask = Task { [weak self] in
            var current = initial
            for _ in 0..<15 {
                guard !Task.isCancelled else { break }
                current = PersonCoMentionGraphViewModel.runPhysics(
                    ids: ids, centralId: focus, edges: edgeList,
                    positions: current, size: size, iterations: 20)
                guard !Task.isCancelled else { break }
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.nodePositions = current
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: - Physics (static for testability)

    /// Spring-repulsion layout with the focus node pinned at the canvas centre — a parallel
    /// of `VolumeConnectionGraphViewModel.runPhysics` for rollup-id nodes and undirected
    /// co-mention edges. Deterministic for fixed inputs; bounded by `iterations`.
    ///
    /// - Parameters:
    ///   - ids: All node rollup ids (focus + partners).
    ///   - centralId: The pinned focus rollup id.
    ///   - edges: Undirected weighted co-mention edges.
    ///   - positions: Initial positions (focus pre-placed at centre).
    ///   - size: Canvas size.
    ///   - iterations: Fixed iteration count (bounded — never spins).
    /// - Returns: Settled positions keyed by rollup id.
    static func runPhysics(
        ids: [Int],
        centralId: Int,
        edges: [PersonCoMentionEdge],
        positions: [Int: CGPoint],
        size: CGSize,
        iterations: Int
    ) -> [Int: CGPoint] {
        let k_s: CGFloat = 0.008
        let L0: CGFloat = 150
        let k_r: CGFloat = 6_000
        let damping: CGFloat = 0.82
        let pad: CGFloat = 48
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var pos = positions
        var vel: [Int: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

        for _ in 0..<iterations {
            var forces: [Int: CGVector] = ids.reduce(into: [:]) { $0[$1] = .zero }

            // Attractive spring along every edge.
            for edge in edges {
                guard let ps = pos[edge.a], let pt = pos[edge.b] else { continue }
                let dx = pt.x - ps.x, dy = pt.y - ps.y
                let d = max(hypot(dx, dy), 1)
                let f = k_s * (d - L0)
                let ux = dx / d, uy = dy / d
                forces[edge.a]?.dx += ux * f
                forces[edge.a]?.dy += uy * f
                forces[edge.b]?.dx -= ux * f
                forces[edge.b]?.dy -= uy * f
            }

            // Repulsion between every node pair.
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    guard let pa = pos[ids[i]], let pb = pos[ids[j]] else { continue }
                    let dx = pa.x - pb.x, dy = pa.y - pb.y
                    let d = max(hypot(dx, dy), 1)
                    let f = k_r / (d * d)
                    let ux = dx / d, uy = dy / d
                    forces[ids[i]]?.dx += ux * f; forces[ids[i]]?.dy += uy * f
                    forces[ids[j]]?.dx -= ux * f; forces[ids[j]]?.dy -= uy * f
                }
            }

            for id in ids {
                if id == centralId {
                    pos[id] = center
                    vel[id] = .zero
                    continue
                }
                guard var v = vel[id], var p = pos[id], let f = forces[id] else { continue }
                v.dx = (v.dx + f.dx) * damping
                v.dy = (v.dy + f.dy) * damping
                p.x = max(pad, min(size.width - pad, p.x + v.dx))
                p.y = max(pad, min(size.height - pad, p.y + v.dy))
                vel[id] = v; pos[id] = p
            }
        }
        return pos
    }

    // MARK: - Hit testing

    /// Returns the partner rollup id whose node contains `point`, if any (focus excluded —
    /// tapping the focus is a no-op).
    func partnerAt(point: CGPoint) -> Int? {
        for node in partners {
            guard let pos = nodePositions[node.rollupId] else { continue }
            if hypot(pos.x - point.x, pos.y - point.y) <= 22 { return node.rollupId }
        }
        return nil
    }
}

// MARK: - PersonCoMentionGraphView

/// Canvas-based co-mention ego graph (CA-8): the focus person at the centre with their
/// top-N co-mentioned partners orbiting in a spring-repulsion layout, edges weighted by
/// shared-document count.
///
/// The focus node is pinned at the canvas centre; partner node size encodes shared
/// documents with the focus, and edge thickness encodes pairwise co-mention weight.
/// Tapping a partner node pins it (tapping it again unpins it), and the info dock shows its
/// shared-document count, an "Explore connections" button that re-centres the graph on that
/// person, and an "Open in Search" button that deep-links to their mentions.
///
/// Accessibility mirrors `VolumeConnectionGraphView`: the `Canvas` is hidden from
/// VoiceOver and a transparent per-node hit-area button carries the label/hint. Reduce
/// Motion settles the layout instantly. The disclosed top-N cap and a legend appear below
/// the canvas.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — #307 (parity with the cross-reference graph): macOS scroll-wheel/trackpad zoom
///          via the shared `ScrollWheelZoomCatcher` (now internal in
///          CrossReferenceGraphView.swift), and a node context menu (Explore Connections /
///          Open in Search) mirroring the tap-selected info card's actions
///   1.2 — #1383: a hit area's click calls `toggleSelection(_:)` and its hover
///          `hoverChanged(_:hovering:)`, and the dock and node emphasis read
///          `displayedPartnerId`, so hovering no longer replaces the clicked partner, and the node's
///          VoiceOver hint says activation selects or deselects (Explore re-centres). #1385: the
///          footer reads the view model's `capDisclosure`
///   1.3 — #1384: labels are measured and drawn only where `GraphNodeLabels.place(_:)` keeps
///          them clear of one another and of every other disc, and a name over 16 characters is
///          cut at a word boundary and marked "…", where every name was its first 14 characters
struct PersonCoMentionGraphView: View {

    @State private var vm: PersonCoMentionGraphViewModel

    /// The store, injected by the host so no-index degradation happens above this view.
    let store: PersonMentionStore
    /// Active volume scope (`nil` = whole corpus). Changing it reloads the ego graph (#189-B).
    let volumeIds: [String]?
    /// Opens a person's mentions in Search (reuses the CA-5 person deep-link).
    let onOpenPerson: (_ rollupId: Int, _ name: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the graph centred on the given focus person.
    init(focusRollupId: Int, focusName: String, store: PersonMentionStore,
         volumeIds: [String]? = nil,
         onOpenPerson: @escaping (_ rollupId: Int, _ name: String) -> Void) {
        _vm = State(initialValue: PersonCoMentionGraphViewModel(
            focusRollupId: focusRollupId, focusName: focusName))
        self.store = store
        self.volumeIds = volumeIds
        self.onOpenPerson = onOpenPerson
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if vm.isLoading {
                    ProgressView(String(localized: "personCoMention.loading",
                                        defaultValue: "Loading co-mention network…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.error {
                    ContentUnavailableView(
                        String(localized: "personCoMention.error.title", defaultValue: "Graph Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(err))
                } else if vm.partners.isEmpty {
                    ContentUnavailableView(
                        String(localized: "personCoMention.empty.title", defaultValue: "No Co-Mentions"),
                        systemImage: "person.2.slash",
                        description: Text(String(
                            localized: "personCoMention.empty.detail",
                            defaultValue: "\(vm.focusName) is not co-mentioned with any other indexed person. Index more volumes, or pick a more frequently mentioned focus person.")))
                } else {
                    graphContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !vm.partners.isEmpty && vm.error == nil && !vm.isLoading {
                legendBar
            }
        }
        .task(id: "\(vm.focusRollupId)#\(volumeIds?.sorted().joined(separator: ",") ?? "*")") {
            await vm.load(from: store, volumeIds: volumeIds)
        }
    }

    // MARK: - Graph Content

    /// Graph + a PERMANENTLY-reserved info dock (Win 6). Reserving the dock at all times — an
    /// empty-state placeholder when nothing is selected — keeps the graph canvas region a constant
    /// size, so selecting/deselecting a node never resizes the canvas. That matters because a canvas
    /// resize fires `onCanvasSizeChanged` → the spring layout re-runs and nodes visibly jump; a fixed
    /// region avoids it. A side dock on wide layouts (≥640pt), a bottom dock when narrow.
    private var graphContent: some View {
        GeometryReader { outer in
            let sideDock = outer.size.width >= 640
            if sideDock {
                HStack(spacing: 0) {
                    graphRegion
                    Divider()
                    infoDock.frame(width: 300)
                }
            } else {
                VStack(spacing: 0) {
                    graphRegion
                    Divider()
                    infoDock.frame(height: 190)
                }
            }
        }
    }

    /// The graph canvas plus its floating viewport buttons, occupying all space not taken by the
    /// info dock. The inner `GeometryReader` measures ONLY this reduced region, so the layout settles
    /// into it from the first frame (no post-hoc shrink) and is stable across selection changes.
    private var graphRegion: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    graphCanvas
                    nodeHitAreas
                }
                .scaleEffect(vm.scale, anchor: .center)
                .offset(vm.panOffset)
                .gesture(magnificationGesture)
                .gesture(panGesture)
                .gesture(resetViewportGesture)
                .onChange(of: geo.size, initial: true) { _, size in
                    vm.onCanvasSizeChanged(size, reduceMotion: reduceMotion)
                }
                #if os(macOS)
                .background {
                    // Scroll-wheel / trackpad-scroll zoom (#307) — the same event-monitor
                    // catcher the cross-reference graph uses (shared from
                    // CrossReferenceGraphView.swift), so it never intercepts clicks,
                    // drags, or hover.
                    ScrollWheelZoomCatcher { factor in
                        vm.zoom(by: factor)
                    }
                    .allowsHitTesting(false)
                }
                #endif
            }
            viewportControls
                .padding()
        }
    }

    // MARK: - Canvas

    private var graphCanvas: some View {
        Canvas { context, _ in
            let maxWeight = CGFloat(vm.maxEdgeWeight)
            let focusId = vm.focusRollupId

            // Edges — grey, weighted by shared-document count.
            for edge in vm.edges {
                guard let from = vm.nodePositions[edge.a],
                      let to = vm.nodePositions[edge.b] else { continue }
                // Focus-incident edges are tinted the accent colour to read as spokes.
                let isSpoke = edge.a == focusId || edge.b == focusId
                drawEdge(&context, from: from, to: to,
                         color: isSpoke ? Color.accentColor : .gray,
                         weight: CGFloat(edge.sharedDocuments) / maxWeight)
            }

            // Partner nodes (drawn before the focus so the focus renders on top).
            for node in vm.partners {
                guard let pos = vm.nodePositions[node.rollupId] else { continue }
                // The dock's partner — hovered or pinned (#1383) — is the one emphasised.
                let isEmphasized = vm.displayedPartnerId == node.rollupId
                // 12…22 pt by shared documents, 3 pt more when emphasised: the radius the label
                // placement keeps clear of (#1384).
                let r = vm.nodeRadius(for: node.rollupId)
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(isEmphasized ? .teal : Color.teal.opacity(0.6)))
                if isEmphasized {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                                   with: .color(.white), lineWidth: 1.5)
                }
            }

            // Focus node — drawn on top of the partners.
            if let cp = vm.nodePositions[focusId] {
                let cr = vm.nodeRadius(for: focusId)
                let centralRect = CGRect(x: cp.x - cr, y: cp.y - cr, width: cr * 2, height: cr * 2)
                context.fill(Path(ellipseIn: centralRect), with: .color(Color.accentColor))
                context.stroke(Path(ellipseIn: centralRect.insetBy(dx: -2, dy: -2)),
                               with: .color(.white), lineWidth: 2)
                context.draw(Image(systemName: "person.fill"),
                             in: centralRect.insetBy(dx: cr * 0.4, dy: cr * 0.4))
            }

            // Labels (#1384): each measured as it will be drawn, then placed in priority order —
            // the focus, then the dock's partner and the partners by shared documents — each only
            // where it keeps clear of the labels already placed and of every other disc.
            var resolved: [Int: GraphicsContext.ResolvedText] = [:]
            var sizes: [Int: CGSize] = [:]
            for id in vm.labelPriority {
                let text = context.resolve(labelText(for: id, isFocus: id == focusId))
                resolved[id] = text
                sizes[id] = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                    height: .greatestFiniteMagnitude))
            }
            for (id, rect) in GraphNodeLabels.place(vm.labelRequests(sizes: sizes)) {
                if let text = resolved[id] {
                    context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// A node's label styled as the canvas draws it (#1384): the focus's in 9 pt semibold, a
    /// partner's in 8 pt secondary. The canvas measures exactly this text before placing it.
    /// - Parameters:
    ///   - rollupId: The node.
    ///   - isFocus: Whether the node is the focus.
    /// - Returns: The styled label.
    private func labelText(for rollupId: Int, isFocus: Bool) -> Text {
        let text = Text(verbatim: vm.label(for: rollupId))
        return isFocus
            ? text.font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.primary)
            : text.font(.system(size: 8)).foregroundStyle(Color.secondary)
    }

    private func drawEdge(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint,
                          color: Color, weight: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path,
                       with: .color(color.opacity(0.2 + weight * 0.5)),
                       lineWidth: 0.5 + weight * 3.5)
    }

    // MARK: - Hit Areas (accessibility + tap-to-select)

    @ViewBuilder
    private var nodeHitAreas: some View {
        ForEach(vm.partners) { node in
            if let pos = vm.nodePositions[node.rollupId] {
                Button {
                    vm.toggleSelection(node.rollupId)
                } label: {
                    Circle().fill(Color.clear).frame(width: 48, height: 48).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(pos)
                #if os(macOS)
                // Hover previews and never pins (#1383): only the click above selects.
                .onHover { hovering in vm.hoverChanged(node.rollupId, hovering: hovering) }
                #endif
                // Right-click / long-press parity with the cross-reference graph's node
                // context menu (#307): the same two actions the tap-selected info card
                // offers, reachable without first pinning the card.
                .contextMenu {
                    Button {
                        vm.recenterOn(rollupId: node.rollupId)
                    } label: {
                        Label(String(localized: "personCoMention.contextMenu.recenter",
                                     defaultValue: "Explore Connections"),
                              systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    Button {
                        onOpenPerson(node.rollupId, node.name)
                    } label: {
                        Label(String(localized: "personCoMention.contextMenu.openSearch",
                                     defaultValue: "Open in Search"),
                              systemImage: "magnifyingglass")
                    }
                }
                .accessibilityLabel(node.name)
                .accessibilityValue(String(
                    localized: "personCoMention.node.a11yValue",
                    defaultValue: "\(node.sharedWithFocus) shared documents with \(vm.focusName)"))
                // Activating the node selects or deselects it (`toggleSelection`); only Explore
                // connections re-centres (#1383 corrected the old claim that a tap re-centred).
                .accessibilityHint(String(localized: "personCoMention.node.hint",
                                          defaultValue: "Selects or deselects this person. While they are selected, the network shows how many documents they share with the focus person, and Explore connections re-centers it on them. Right-click or long-press for actions"))
                .help(String(localized: "personCoMention.node.help",
                             defaultValue: "Co-mention count with the focus person — click for details, right-click for actions"))
            }
        }
    }

    // MARK: - Viewport Controls

    /// The small floating viewport buttons (Reset View / Back) pinned at the graph's top-leading
    /// corner. The selected-person info no longer lives here — it moved to the docked panel (Win 6) —
    /// so these buttons never obscure a node's neighbourhood.
    @ViewBuilder
    private var viewportControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.scale != 1.0 || vm.panOffset != .zero {
                Button {
                    vm.resetViewport(animated: !reduceMotion)
                } label: {
                    Label(String(localized: "personCoMention.resetView", defaultValue: "Reset View"),
                          systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }

            if vm.canNavigateBack {
                Button {
                    vm.navigateBack()
                } label: {
                    Label(String(localized: "personCoMention.back", defaultValue: "Back"),
                          systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: vm.canNavigateBack)
    }

    // MARK: - Info Dock

    /// The permanently-reserved info region beside (wide) or below (narrow) the graph. It shows the
    /// hovered or pinned partner's card (`displayedPartnerId`, #1383), or a prompt when there is
    /// neither. The placeholder is what keeps the graph canvas a constant size across selection
    /// changes (see `graphContent`). Only the dock CONTENT cross-fades; its frame never changes.
    private var infoDock: some View {
        ZStack {
            if let sel = vm.displayedPartnerId {
                // Scroll within the fixed-height reserve so the action buttons stay reachable when the
                // card exceeds the dock — a long name, or large Dynamic Type in the ~190pt bottom dock
                // (which would otherwise overflow past the panel onto the legend). The dock FRAME stays
                // fixed; only its content scrolls, so the canvas-stability reservation is preserved.
                ScrollView { dockedInfoPanel(for: sel) }
            } else {
                infoDockEmptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: vm.displayedPartnerId)
    }

    /// The displayed partner's card — hovered or pinned (#1383) — with its name, shared-document
    /// count, and the Explore/Open actions, filling the dock width (no fixed 280pt frame, unlike the
    /// former floating panel).
    @ViewBuilder
    private func dockedInfoPanel(for partnerId: Int) -> some View {
        let name = vm.name(for: partnerId)
        let shared = vm.sharedWithFocus(for: partnerId)
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline).lineLimit(3)
            Divider()
            Label(String(localized: "personCoMention.info.shared",
                         defaultValue: "\(shared) shared document\(shared == 1 ? "" : "s") with \(vm.focusName)"),
                  systemImage: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Full-width stacked buttons so the titles never truncate at any Dynamic Type size or
            // dock width (the old side-by-side HStack was ~7pt from clipping in the 300pt side dock).
            VStack(spacing: 6) {
                Button(String(localized: "personCoMention.info.explore",
                              defaultValue: "Explore connections")) {
                    vm.recenterOn(rollupId: partnerId)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                Button(String(localized: "personCoMention.info.openSearch",
                              defaultValue: "Open in Search")) {
                    onOpenPerson(partnerId, name)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .font(.caption)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    /// The dock's empty state, shown while no partner is hovered or pinned.
    private var infoDockEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(String(localized: "personCoMention.dock.empty",
                        defaultValue: "Select a person to see their shared documents and connections."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Legend / Disclosure

    private var legendBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                legendItem(color: Color.accentColor,
                           text: String(localized: "personCoMention.legend.focus", defaultValue: "Focus person"))
                legendItem(color: .teal,
                           text: String(localized: "personCoMention.legend.partner", defaultValue: "Co-mentioned (size = shared documents)"))
            }
            .font(.caption2)
            if vm.capApplied {
                Text(vm.capDisclosure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "personCoMention.cap.all",
                            defaultValue: "Showing all \(vm.partners.count) co-mentioned people, sized by shared documents. Edge thickness = documents mentioning both."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).foregroundStyle(.secondary)
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { vm.magnificationChanged($0) }
            .onEnded { _ in vm.magnificationEnded() }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { vm.panChanged($0.translation) }
            .onEnded { _ in vm.panEnded() }
    }

    private var resetViewportGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded { vm.resetViewport(animated: !reduceMotion) }
    }
}
