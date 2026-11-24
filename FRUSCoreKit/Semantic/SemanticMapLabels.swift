// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
// Linux's Foundation declares the geometry types itself; on Apple platforms a package module needs
// CoreGraphics for their Equatable and their members.
#if canImport(CoreGraphics)
import CoreGraphics
#endif
// SemanticVectorsKit is a module of its own in a package; Xcode compiles its sources into the app
// target (project.yml), where its types are already in this module and the import is compiled out.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

/// Where the map's camera is looking.
///
/// **This type exists so the projection has exactly one definition.** The vertex shader maps
/// `(grid - centre) / scale` into clip space; the label layer has to land text on the same pixels a
/// point lands on, and a second copy of that arithmetic is a second thing that can drift. The
/// renderer's `scale` is this type's `scale(aspect:)` and nothing else computes it.
///
/// `aspect` is deliberately **not** stored here. The renderer takes it from the drawable and the
/// label layer from the SwiftUI geometry — the same rectangle measured in pixels and in points, so
/// the ratio is identical by construction and there is nothing to keep in sync.
///
/// Version history:
///   1.0 — V-4: extracted when the map gained labels
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into FRUSCoreKit with the label layout, public,
///          CoreGraphics behind `canImport` and without `simd`, whose `SIMD2` is the standard library's
public struct SemanticMapCamera: Equatable, Sendable {

    /// Grid coordinate at the centre of the view.
    public var centre: SIMD2<Float>
    /// Half the visible grid height. Zoom scales this; aspect widens it.
    public var halfExtent: Float

    /// Creates a camera.
    /// - Parameters:
    ///   - centre: Grid coordinate at the centre of the view.
    ///   - halfExtent: Half the visible grid height.
    public init(centre: SIMD2<Float> = SIMD2<Float>(0, 0), halfExtent: Float = 32_768) {
        self.centre = centre
        self.halfExtent = halfExtent
    }

    /// Grid units per half-viewport in each axis.
    ///
    /// - Parameter aspect: Viewport width divided by height.
    /// - Returns: The per-axis scale. Applying aspect here rather than to `halfExtent` is what keeps
    ///   a resize from disturbing the camera and a zoom from distorting the map.
    public func scale(aspect: Float) -> SIMD2<Float> {
        let safeAspect = aspect.isFinite && aspect > 0 ? aspect : 1
        return safeAspect >= 1
            ? SIMD2<Float>(halfExtent * safeAspect, halfExtent)
            : SIMD2<Float>(halfExtent, halfExtent / safeAspect)
    }
}

/// One region's name, placed for drawing.
///
/// Version history:
///   1.0 — V-4: initial implementation
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into FRUSCoreKit, public
public struct SemanticMapLabel: Identifiable, Equatable {
    /// The cluster this names.
    public let id: Int
    /// The words, already trimmed to the number the map shows.
    public let text: String
    /// Where to draw it, in view points.
    public let position: CGPoint
    /// How many documents the region holds — the ranking that decides who gets a label.
    public let documentCount: Int
}

/// Chooses which regions get named, and where the names go.
///
/// The map has **172 regions and room for perhaps two dozen names**. Drawing them all produces an
/// unreadable thicket and drawing the nearest ones produces a different set every frame, so the rule
/// is: rank by document count, project, drop anything off screen, and keep a name only when it clears
/// every name already kept. Ranking by size rather than by proximity is what makes the labelling
/// stable while panning — a big region keeps its name when a small one drifts past it.
///
/// Everything here is a pure function of (clusters, camera, size) so it can be tested without a GPU,
/// which the rest of this surface has repeatedly needed and not had.
///
/// Version history:
///   1.0 — V-4: initial implementation
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into FRUSCoreKit with the camera, public;
///          ``labelledClusters(_:scope:)``, the scoped map's choice of what may be named, out of
///          `SemanticMapModel`
public enum SemanticMapLabelLayout {

    /// How many names the map will show at once.
    public static let defaultLimit = 22

    /// Minimum distance between two names, in points.
    public static let defaultSpacing: CGFloat = 72

    /// How many of a cluster's terms to show. The artifact carries four, ranked; two reads as a name
    /// and four reads as a word cloud.
    public static let defaultTermCount = 2

    /// How many in-scope documents a region needs before its name is drawn.
    ///
    /// A label sits at the region's WHOLE-CORPUS centroid, which is where its members are only if it
    /// has members. One in-scope document out of nine thousand puts a name in the middle of a field
    /// of ghosts, and the reader has no way to see that it describes a single point. Five is a
    /// judgement rather than a measurement, and a low one: it drops the degenerate case without
    /// pretending to a threshold nobody has calibrated.
    public static let minimumLabelledInScope = 5

    /// The regions to label, re-counted against the scope.
    ///
    /// Two things happen here and both are necessary. A region with (almost) nothing in scope is
    /// **dropped**, because the artifact's cluster centres are whole-corpus and scoping to one
    /// subseries otherwise left the label layer choosing its dozen from all 172 regions, most of them
    /// naming a place that now held nothing but ghosts.
    /// And a surviving region's `documentCount` is **replaced by its in-scope count**, because the
    /// label layer ranks by size and keeps a dozen: rank by the series and a narrow scope gives its
    /// labels to the corpus's biggest regions rather than to the ones it fills.
    ///
    /// The regions table of an export and the accessibility list read the same list, so the counts
    /// in a file and on the screen agree with the names drawn.
    ///
    /// - Parameters:
    ///   - clusters: Every region the artifact names.
    ///   - scope: The scope's mask, or `nil` for the whole series.
    /// - Returns: The regions to label: `clusters` itself when unscoped.
    public static func labelledClusters(_ clusters: [SemanticMapArtifacts.Cluster],
                                        scope: SemanticMapColouring.ScopeMask?)
        -> [SemanticMapArtifacts.Cluster] {
        guard let scope else { return clusters }
        return clusters.compactMap { cluster in
            guard let count = scope.regionCounts[UInt16(clamping: cluster.id)],
                  count >= minimumLabelledInScope else { return nil }
            return SemanticMapArtifacts.Cluster(
                id: cluster.id, terms: cluster.terms, documentCount: count,
                centreX: cluster.centreX, centreY: cluster.centreY, eraCounts: cluster.eraCounts)
        }
    }

    /// Projects a grid coordinate to a point in the view.
    ///
    /// Mirrors the vertex shader: `(grid - centre) / scale` gives clip space, which spans [-1, 1]
    /// across the viewport in both axes, with **y up**. The view's y runs down, hence the flip.
    ///
    /// - Parameters:
    ///   - grid: The artifact coordinate.
    ///   - camera: Where the camera is looking.
    ///   - size: The view's size in points.
    /// - Returns: The position in view points; may be outside `size`.
    public static func project(_ grid: SIMD2<Float>, camera: SemanticMapCamera, size: CGSize) -> CGPoint {
        let aspect = size.height > 0 ? Float(size.width / size.height) : 1
        let scale = camera.scale(aspect: aspect)
        let normalized = (grid - camera.centre) / scale
        return CGPoint(
            x: CGFloat((normalized.x + 1) * 0.5) * size.width,
            y: CGFloat((1 - normalized.y) * 0.5) * size.height)
    }

    /// Turns a point in the view back into a grid coordinate.
    ///
    /// The exact inverse of `project(_:camera:size:)`, and it has to be — a tap resolved through a
    /// slightly different rule would select a document next to the one under the reader's finger,
    /// which is the kind of wrongness that looks like imprecision rather than a bug.
    ///
    /// - Parameters:
    ///   - point: A position in view points.
    ///   - camera: Where the camera is looking.
    ///   - size: The view's size in points.
    /// - Returns: The grid coordinate under that point.
    public static func unproject(_ point: CGPoint, camera: SemanticMapCamera, size: CGSize)
        -> SIMD2<Float> {
        guard size.width > 0, size.height > 0 else { return camera.centre }
        let aspect = Float(size.width / size.height)
        let scale = camera.scale(aspect: aspect)
        let normalized = SIMD2<Float>(
            Float(point.x / size.width) * 2 - 1,
            1 - Float(point.y / size.height) * 2)
        return normalized * scale + camera.centre
    }

    /// Lays out the names for the visible regions.
    ///
    /// - Parameters:
    ///   - clusters: Every cluster in the artifact.
    ///   - camera: Where the camera is looking.
    ///   - size: The view's size in points.
    ///   - limit: How many names to show.
    ///   - spacing: Minimum distance between two names, in points.
    ///   - termCount: How many of each cluster's terms to show.
    /// - Returns: The names to draw, largest region first.
    public static func labels(
        for clusters: [SemanticMapArtifacts.Cluster],
        camera: SemanticMapCamera,
        size: CGSize,
        limit: Int = defaultLimit,
        spacing: CGFloat = defaultSpacing,
        termCount: Int = defaultTermCount
    ) -> [SemanticMapLabel] {
        guard size.width > 0, size.height > 0, limit > 0 else { return [] }

        // A name is drawn centred on its region, so it may hang outside the viewport by half its own
        // width before it stops being useful. The margin keeps a region whose centre is just off
        // screen from popping its name in and out as the reader pans.
        let margin: CGFloat = 24
        let visible = CGRect(x: -margin, y: -margin,
                             width: size.width + margin * 2, height: size.height + margin * 2)

        // ...and then the name is pulled back inside, because a region centred near the edge drew a
        // name running off it: the first build showed "srael israeli" and a truncated "seward
        // dayton". A nudged label is ordinary map practice and strictly better than a clipped one.
        // The clamp happens BEFORE the spacing test so two names pulled to the same edge still
        // cannot collide.
        let inset = CGSize(width: min(46, size.width / 3), height: min(14, size.height / 3))
        let placeable = CGRect(x: inset.width, y: inset.height,
                               width: max(0, size.width - inset.width * 2),
                               height: max(0, size.height - inset.height * 2))

        var kept: [SemanticMapLabel] = []
        kept.reserveCapacity(limit)

        // Sort by size, then by id so two equal-sized regions cannot swap places between runs.
        let ranked = clusters.sorted {
            $0.documentCount == $1.documentCount ? $0.id < $1.id : $0.documentCount > $1.documentCount
        }

        for cluster in ranked {
            guard kept.count < limit else { break }
            let terms = cluster.terms.prefix(max(1, termCount))
            guard !terms.isEmpty else { continue }
            let point = project(SIMD2<Float>(Float(cluster.centreX), Float(cluster.centreY)),
                                camera: camera, size: size)
            guard point.x.isFinite, point.y.isFinite, visible.contains(point) else { continue }
            let placed = CGPoint(
                x: min(max(point.x, placeable.minX), placeable.maxX),
                y: min(max(point.y, placeable.minY), placeable.maxY))
            let clearsNeighbours = kept.allSatisfy { existing in
                hypot(existing.position.x - placed.x, existing.position.y - placed.y) >= spacing
            }
            guard clearsNeighbours else { continue }
            kept.append(SemanticMapLabel(
                id: cluster.id,
                text: terms.joined(separator: " "),
                position: placed,
                documentCount: cluster.documentCount))
        }
        return kept
    }
}
