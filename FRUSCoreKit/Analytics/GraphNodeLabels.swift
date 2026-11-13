// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - GraphLabelRequest

/// One node label waiting to be placed by `GraphNodeLabels.place(_:avoiding:settling:)` (#1384):
/// the node, where its disc is drawn, and how big the label measured.
///
/// Version history:
///   1.0 — #1384: initial implementation
///   1.1 — #1384 review: `shape`, so the archival network's class squares are kept clear of whole
///   1.2 — 2026-11-12 (FRUS Explorer Light, S24c): out of `PersonCoMentionGraphView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public, unchanged but for access and the `Sendable` it had by inference, its memberwise initialiser spelt out and
///          public
public struct GraphLabelRequest<ID: Hashable>: Equatable {

    /// The outline a node is drawn with, which decides what "clear of its disc" means.
    public enum Shape: Equatable, Sendable {
        /// A circle of `radius` — every node in the co-mention and volume graphs, and a
        /// collection in the archival network.
        case disc
        /// A square reaching `radius` from the centre on each side — the archival network's class
        /// node, drawn as a rounded square inside it, so a label kept clear of the square is clear
        /// of the rounded corners too. A disc of the same radius would leave those corners out.
        case square
    }

    /// The node the label names.
    public let id: ID
    /// The centre of the node's disc on the canvas.
    public let center: CGPoint
    /// The radius of the node's disc as drawn — its fill, or half a square's side. A white ring,
    /// where one is drawn, lies within `GraphNodeLabels.clearance` of it.
    public let radius: CGFloat
    /// The node's outline: `.disc` unless the canvas draws it square.
    public var shape: Shape = .disc
    /// The label's measured size: `GraphicsContext.ResolvedText.measure(in:)` on the app's canvas, and a
    /// host's own measure of the font it draws the label in.
    public let size: CGSize

    /// A request for the label of node `id`, drawn at `center` with an outline of `radius` and `shape`,
    /// whose text measures `size`: the memberwise initialiser, spelt out so a host can make one.
    public init(id: ID, center: CGPoint, radius: CGFloat, shape: Shape = .disc, size: CGSize) {
        self.id = id
        self.center = center
        self.radius = radius
        self.shape = shape
        self.size = size
    }
}

// A public type is inferred no `Sendable`: the request keeps the conformance it had by inference while it
// was internal.
extension GraphLabelRequest: Sendable where ID: Sendable {}

// MARK: - GraphNodeLabels

/// The node-label rules the co-mention, volume connection and archival network graphs share
/// (#1384): how a long name is cut, where its label goes, and which labels are drawn at all.
///
/// Before #1384 all three graphs drew every label centred under its node, cut to a fixed number of
/// characters, and nothing kept two labels apart. The Mac capture drew "Bruce, David K" and
/// "Truman, Harry" end to end as one string, and "Kennan, George" over "Bohlen, Charle". Now a cut
/// ends in "…", and labels are placed in priority order. The centre's — the focus's, or the central
/// volume's — comes first and is always drawn, on a plate of the background over whatever lies
/// under it. Every other label is drawn under its node, or above it when the place under is
/// taken (#1438), only where it keeps clear of every label already placed, the centre's included,
/// of every node's disc but its own, and of anything else the canvas draws there (an obstacle — the
/// archival network's custodian captions, its Central Files box and the box's caption). A partner
/// label that fits in neither place is not drawn: its full name stays in its node's VoiceOver label
/// and in the dock or panel that a click, a tap or (on the Mac) a hover opens.
///
/// While a graph's spring layout is still animating, only the centre's label is placed (#1434):
/// `place(_:avoiding:settling:)`.
///
/// Version history:
///   1.0 — #1384: initial implementation
///   1.1 — #1384 review: the first label obeys the rules every other label does (the plate it was
///          drawn on across a disc is gone), and a `.square` node is kept clear of whole
///   1.2 — #1384 review round 2: by the owner's decision the first label — the centre's — is
///          always placed again, on a plate: `plateRect(behind:)`, `plate(for:placed:)` and
///          `drawPlate(_:in:)`
///   1.3 — #1434: `place(_:settling:)` places only the centre's label while the layout animates
///   1.4 — 2026-10-01: #1438 — a partner label falls back to a place above its node
///          (`labelRectAbove(for:)`, owner decision D10), and `place(_:avoiding:settling:)` keeps
///          every partner label clear of the obstacles a canvas passes
///   1.5 — 2026-11-12 (FRUS Explorer Light, S24c): out of `PersonCoMentionGraphView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public, unchanged but for access; `drawPlate(_:in:)`, which draws with SwiftUI,
///          stays the app's there
public enum GraphNodeLabels {

    /// The gap between a node's disc and the top of its label. Before #1384 each label was drawn
    /// centred 8 pt below its disc; measuring it lets the placement pin its top edge instead.
    public static let spacing: CGFloat = 3

    /// The least space a placed partner label keeps from every other placed label and from every
    /// other node's disc. The centre's label is held to neither rule
    /// (`place(_:avoiding:settling:)`), but every partner label keeps this far from it.
    ///
    /// Two labels that merely touch read as one string ("Bruce, David KTruman, Harry"). The focus
    /// and the emphasised partner draw a white ring whose outer edge lies 2.75–3 pt outside the
    /// disc's fill, so a label kept this far from the fill may touch the focus's ring but never
    /// crosses it, and stays clear of a partner's.
    public static let clearance: CGFloat = 3

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
    public static func shortLabel(_ name: String, limit: Int) -> String {
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
    public static func labelRect<ID: Hashable>(for request: GraphLabelRequest<ID>) -> CGRect {
        CGRect(x: request.center.x - request.size.width / 2,
               y: request.center.y + request.radius + spacing,
               width: request.size.width, height: request.size.height)
    }

    /// The rect a request's label occupies in its fallback place (#1438, owner decision D10):
    /// centred over its node, `spacing` above the disc — the mirror of `labelRect(for:)`.
    /// - Parameter request: The label to place.
    /// - Returns: The label's rect on the canvas.
    public static func labelRectAbove<ID: Hashable>(for request: GraphLabelRequest<ID>) -> CGRect {
        CGRect(x: request.center.x - request.size.width / 2,
               y: request.center.y - request.radius - spacing - request.size.height,
               width: request.size.width, height: request.size.height)
    }

    /// Chooses which labels to draw, and where (#1384, #1438).
    ///
    /// The first label — the centre's: the focus's, or the central volume's, which each graph's
    /// priority order puts first — is always placed, under its node, whatever lies there. It names
    /// the node every other one is drawn around, and the canvas draws it on a plate
    /// (`plate(for:placed:)`) that keeps it legible over a disc or an edge. Every later label, in
    /// the order given, is placed under its node (`labelRect(for:)`), or above it
    /// (`labelRectAbove(for:)`) when the place under fails, and only where its rect keeps
    /// `clearance` from every label already placed — the centre's included, so no partner label
    /// overlaps the plate — from every `obstacle`, and from every OTHER node's disc: every node's,
    /// whether or not its own label was placed, since every disc is drawn. A label that fits in
    /// neither place is skipped, and no label is moved once placed, so a lower-ranked label can
    /// never displace a higher one.
    ///
    /// ## The place above (#1438, owner decision D10, 2026-09-28)
    /// Measured on `PersonCoMentionLabelTests`' and `VolumeConnectionLabelTests`' laid-out graphs,
    /// which pin the counts: on a 700 × 520 canvas the place above keeps 21 person labels where
    /// one place kept 18, and 31 volume labels where it kept 18; on a 360 × 420 canvas 19 against
    /// 17, and 19 against 11 — the figures #1384 measured when it first tried the place. The
    /// archival network's own counts are in `ArchivalNetworkLabelTests`. The place under is tried
    /// first in every graph, so a label that fitted there before #1438 still sits there.
    ///
    /// ## Obstacles (#1438)
    /// Something the canvas draws that is not a node: the archival network's custodian captions,
    /// the dashed Central Files box and the box's caption. "JCS Records" ran into "OTHER
    /// INSTITUTIONS" on the Mac, and a class label sat across the box's border, because only
    /// labels and discs were checked. A border is passed as thin rects along its sides, so a label
    /// may sit wholly inside the box or wholly outside it, never across its line. The centre's
    /// label is not checked against them: it is always placed.
    ///
    /// The centre's exemption is the owner's decision (2026-09-24). It departs from #1384 and the
    /// open-issues plan (§3 A5), which hold every label to the disc rule with no exception. That
    /// rule drops the centre's label wherever the layout puts a partner just under the centre, and
    /// the layout often does: in both of `PersonCoMentionLabelTests`' laid-out graphs, on an iPad
    /// capture of Stalin's network over seven 1945–48 volumes, and under 8 of the 12 most widely
    /// cited archival foci at 700 × 420 (11 at 390 × 300). Review round 1 applied the rule to the
    /// centre too, and the centre then went unlabelled on the canvas; round 2 restores the first
    /// version's exemption and plate.
    ///
    /// A label's own disc is excluded by position in `requests`, not left to the geometry: the rect
    /// starts exactly `radius + spacing` below the centre, and measuring that back can round below
    /// `radius + clearance`, which is the same distance. Measured at seven radii the co-mention and
    /// volume graphs draw (12, 15, 18, 22, 25, 26 and 28 pt), over centres from y = 48 to 699.9 pt
    /// in 0.1 pt steps, it did at 1,224 of the 45,640 positions; a node at y = 483.3 with a 26 pt
    /// disc finds it 28.999999999999943 pt away, not 29, and would drop its own label. The place
    /// above is the mirror image, so its own disc is excluded the same way.
    ///
    /// ## While the layout settles (#1434)
    /// The co-mention and volume graphs animate their spring layout: after a load, a re-centre or a
    /// resize they publish fifteen intermediate layouts over about a quarter of a second, and the
    /// canvas redraws on each. Chosen afresh from each frame's positions, which partner labels fit
    /// changed from frame to frame, so labels flickered on and off until the layout came to rest.
    /// With `settling` set, only the first label is placed: its node is pinned at the canvas centre,
    /// so it does not move while the others do. Every other label is placed once the layout rests,
    /// from the settled positions — the same placement a layout that never animated (Reduce Motion,
    /// or three nodes or fewer) gets at once.
    /// - Parameters:
    ///   - requests: One request per drawn node, highest priority first.
    ///   - obstacles: Rects every partner label keeps `clearance` from; none by default.
    ///   - settling: Whether the graph's layout is still animating toward its settled positions.
    ///     `false` — the default, and the archival network's, whose layout never animates — places
    ///     every label that fits.
    /// - Returns: The rect of every label placed, keyed by its node's id.
    public static func place<ID: Hashable>(_ requests: [GraphLabelRequest<ID>],
                                           avoiding obstacles: [CGRect] = [],
                                           settling: Bool = false) -> [ID: CGRect] {
        var placed: [ID: CGRect] = [:]
        var kept: [CGRect] = []
        for (index, request) in requests.enumerated() {
            // The partner labels wait for the settled layout (#1434).
            if settling && index > 0 { break }
            // The centre's label is placed whatever lies under it, on its plate (owner, 2026-09-24).
            guard index > 0 else {
                let rect = labelRect(for: request)
                kept.append(rect)
                placed[request.id] = rect
                continue
            }
            let fits = { (rect: CGRect) -> Bool in
                !kept.contains { crowds(rect, $0) }
                    && !obstacles.contains { crowds(rect, $0) }
                    && !requests.indices.contains { $0 != index && covers(rect, disc: requests[$0]) }
            }
            // Under the node, else above it (#1438); else not drawn.
            guard let rect = [labelRect(for: request), labelRectAbove(for: request)].first(where: fits)
            else { continue }
            kept.append(rect)
            placed[request.id] = rect
        }
        return placed
    }

    /// The plate a label is drawn on: its rect, `clearance` wider at each side and a point taller
    /// above and below. A partner label keeps `clearance` from the centre's label, so it may touch
    /// the plate's side but never overlaps it, and it stays two points from the plate's top and
    /// bottom.
    /// - Parameter rect: A placed label's rect.
    /// - Returns: The plate's rect.
    public static func plateRect(behind rect: CGRect) -> CGRect {
        rect.insetBy(dx: -clearance, dy: -1)
    }

    /// The one plate a canvas draws: behind the first request's label — the centre's, the one label
    /// `place(_:avoiding:settling:)` puts over whatever lies under it — and behind no other.
    /// - Parameters:
    ///   - requests: The requests given to `place(_:avoiding:settling:)`, highest priority first.
    ///   - placed: What `place(_:avoiding:settling:)` returned for them.
    /// - Returns: The plate's rect, or `nil` when there is no request or the first was not placed.
    public static func plate<ID: Hashable>(for requests: [GraphLabelRequest<ID>],
                                           placed: [ID: CGRect]) -> CGRect? {
        guard let first = requests.first, let rect = placed[first.id] else { return nil }
        return plateRect(behind: rect)
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
