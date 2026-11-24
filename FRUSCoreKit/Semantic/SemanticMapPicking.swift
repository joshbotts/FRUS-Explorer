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

/// Finds the document under a tap.
///
/// ## Why a linear scan is the right answer here
///
/// 314,616 positions is a contiguous array read straight through — no pointer chasing, no
/// allocation, perfectly predictable. A spatial index would be faster asymptotically and slower in
/// practice at this size, and it would be a second structure to keep in step. The scan also runs
/// **once per tap**, not per frame: the budget is a human's patience, not a frame. The suite measures
/// it rather than assuming.
///
/// ## It scans the DISPLAYED positions, not the artifact
///
/// The map can lay the same documents out two ways — the packed UMAP plane, and a semantic-axis
/// slice that computes new coordinates. Picking against the artifact would be right in one mode and
/// silently wrong in the other, selecting whatever happened to sit under the finger *on the map*
/// while the reader was looking at a slice. Row identity is unchanged by re-layout, so the caller
/// passes whatever it is currently drawing and everything downstream still resolves.
///
/// The comparison happens in **grid space**, not screen space, so the tolerance has to be converted:
/// a fixed 22-point finger radius is a different number of grid units at every zoom level, and
/// comparing squared distances in grid units avoids a square root per document.
///
/// Version history:
///   1.0 — V-4: initial implementation
///   1.1 — 2026-11-24: FRUS Explorer Light's S28a — moved into FRUSCoreKit, public, CoreGraphics behind
///          `canImport` and without `simd`; the hit test and the lasso in the map's own coordinates, which
///          their view-point forms call, ``regionName(ofRow:map:clusters:)``, which a tap and a reveal both
///          name a point's region by, and ``positions(of:)``, the plane's positions for a host's picks
public enum SemanticMapPicking {

    /// What a completed lasso enclosed, resolved to what a `WorkingCorpus` needs.
    ///
    /// Carries `total` separately from `documentKeys.count` on purpose: when a lasso encloses more
    /// than the capture limit those two differ, and the difference is the whole content of
    /// `WorkingCorpus.wasTruncatedAtCapture` / `totalMatchCountAtCapture`. Collapsing them would make
    /// every over-large capture claim to be the whole answer.
    public struct LassoResult: Equatable, Sendable {
        /// `"volumeId/documentId"` keys, capped at the capture limit.
        public let documentKeys: [String]
        /// Every document inside the lasso, capped or not.
        public let total: Int
        /// The regions the lasso touched, most-enclosed first, for naming the corpus.
        public let regionNames: [String]

        /// Creates a capture.
        /// - Parameters:
        ///   - documentKeys: `"volumeId/documentId"` keys, capped at the capture limit.
        ///   - total: Every document inside, capped or not.
        ///   - regionNames: The regions it touched, for naming the corpus.
        public init(documentKeys: [String], total: Int, regionNames: [String]) {
            self.documentKeys = documentKeys
            self.total = total
            self.regionNames = regionNames
        }

        /// Whether the capture stopped short of what the reader drew.
        public var isTruncated: Bool { total > documentKeys.count }
    }

    /// The document a tap selected, resolved to something a reader can act on.
    public struct Selection: Equatable, Sendable, Identifiable {
        /// The artifact row.
        public let row: Int
        /// The volume the document belongs to.
        public let volumeID: String
        /// The document's id within that volume.
        public let documentID: String
        /// Where it sits on the grid, for drawing the marker on the document rather than the finger.
        public let position: SIMD2<Float>
        /// The region it falls in, when it falls in one — 28% of the corpus is unclustered.
        public let regionName: String?
        /// Whether this device can actually open it.
        ///
        /// **The map draws all 553 volumes and a reader has downloaded some of them.** Without this
        /// the obvious implementation offers "Open" on every document and fails on most of them; the
        /// `availability` lens exists to show the same fact at corpus scale.
        public let isDownloaded: Bool

        /// Creates a selection.
        /// - Parameters:
        ///   - row: The artifact row.
        ///   - volumeID: The document's volume.
        ///   - documentID: The document's id within it.
        ///   - position: Where it sits on the grid.
        ///   - regionName: Its region's name, or `nil` between regions.
        ///   - isDownloaded: Whether the host can open it.
        public init(row: Int, volumeID: String, documentID: String, position: SIMD2<Float>,
                    regionName: String?, isDownloaded: Bool) {
            self.row = row
            self.volumeID = volumeID
            self.documentID = documentID
            self.position = position
            self.regionName = regionName
            self.isDownloaded = isDownloaded
        }

        public var id: Int { row }
    }

    /// The most documents a lasso will put in a working corpus.
    ///
    /// **This is the record's size budget, not a search cap.** `WorkingCorpus` sizes itself against
    /// exactly this number — "at most 7,500 keys … around 190 KB as a value array, well inside a
    /// CloudKit record" — because until now the only capture path was a search result set and
    /// macOS's `searchHardLimit` is 7,500. A lasso has no such natural bound: it can enclose the
    /// whole corpus. Capturing more would make the map the first writer to break the assumption the
    /// synced record was designed under.
    ///
    /// It is not spelled `MacSearchViewModel.searchHardLimit` because that type is macOS-only and
    /// this surface builds on both platforms — and because the constraint genuinely belongs to the
    /// record, not to a search view model that happens to share the number.
    ///
    /// Exceeding it is not an error. The capture records `wasTruncatedAtCapture` and the full count,
    /// which is the model's existing vocabulary for precisely this situation.
    public static let corpusCaptureLimit = 7_500

    /// How close a tap must land, in view points, to select a document.
    ///
    /// Sized for a fingertip rather than a cursor: on a dense map an exact hit is impossible, and a
    /// tap that selects nothing feels broken where a tap that selects a neighbour merely feels
    /// approximate — which is what the map is.
    public static let tapRadius: CGFloat = 22

    /// What a tap found.
    public struct Hit: Equatable, Sendable {
        /// The artifact row, which is what turns into a document id.
        public let row: Int
        /// Its grid position, for drawing the selection where the document actually is rather than
        /// where the finger landed.
        public let position: SIMD2<Float>
    }

    /// Finds every document inside a freeform region the reader drew.
    ///
    /// The path arrives in **view points** and is converted to grid space once, rather than
    /// projecting 314,616 documents into view space — same reason the tap radius is converted rather
    /// than the corpus: the transform is affine, so doing it to the small side is both cheaper and
    /// exactly equivalent.
    ///
    /// Containment is the **even-odd crossing rule**, which is what a hand-drawn lasso wants: a path
    /// that crosses itself leaves the overlap outside, matching what the stroke looks like. A winding
    /// rule would swallow the overlap and surprise the reader.
    ///
    /// - Parameters:
    ///   - path: The lasso in view points. Treated as closed; fewer than 3 points selects nothing.
    ///   - positions: The **displayed** grid positions, one per row.
    ///   - camera: Where the camera is looking.
    ///   - size: The view's size in points.
    ///   - limit: Keep at most this many rows.
    /// - Returns: The kept rows, ascending, and `total` — every **in-scope** document inside the
    ///   path, not just the kept ones. The scan deliberately runs to completion rather than stopping
    ///   at the limit, because `WorkingCorpus` records `totalMatchCountAtCapture` beside its
    ///   membership so a truncated capture can say what it is a fraction *of*. A denominator that
    ///   stopped counting when the numerator filled up would be worse than no denominator.
    ///
    ///   `scopeMask` gates the total as well as the kept rows, and it has to: the two numbers meet in
    ///   `isTruncated`, so counting ghosts in one and not the other would report a cap that never
    ///   applied. With no mask — or one whose length does not match `positions`, which is a stale
    ///   mask and is ignored — the total is every document inside the path, as before.
    public static func rows(
        inside path: [CGPoint],
        positions: [SIMD2<Int16>],
        camera: SemanticMapCamera,
        size: CGSize,
        limit: Int,
        scopeMask: [UInt8]? = nil
    ) -> (rows: [Int], total: Int) {
        guard path.count >= 3, size.width > 0, size.height > 0, limit > 0 else {
            return ([], 0)
        }
        let polygon = path.map {
            SemanticMapLabelLayout.unproject($0, camera: camera, size: size)
        }
        return rows(insideGrid: polygon, positions: positions, limit: limit, scopeMask: scopeMask)
    }

    /// Finds every document inside a region given in the map's own coordinates.
    ///
    /// What ``rows(inside:positions:camera:size:limit:scopeMask:)`` runs once it has turned the
    /// reader's path into grid space, for a host that holds the lasso there already — a server that
    /// takes a polygon in the map's coordinates and holds no view. The rule, the cap, the total and
    /// the scope's gate are that method's, word for word.
    ///
    /// - Parameters:
    ///   - polygon: The closed path in grid space. Fewer than 3 points selects nothing.
    ///   - positions: The **displayed** grid positions, one per row.
    ///   - limit: Keep at most this many rows.
    ///   - scopeMask: The active scope, when there is one; a mask whose length does not match
    ///     `positions` is stale and is ignored.
    /// - Returns: The kept rows, ascending, and every in-scope document inside the path.
    public static func rows(
        insideGrid polygon: [SIMD2<Float>],
        positions: [SIMD2<Int16>],
        limit: Int,
        scopeMask: [UInt8]? = nil
    ) -> (rows: [Int], total: Int) {
        guard polygon.count >= 3, limit > 0 else { return ([], 0) }

        // A bounding box first: most of the corpus is outside any lasso, and a box test is two
        // comparisons against the crossing test's walk of every edge.
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        for point in polygon {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }

        var found: [Int] = []
        var total = 0
        // **The mask gates the TOTAL as well as the kept rows.** A scoped lasso that counted ghosts
        // would tell the reader it caught 4,000 documents and hand them a corpus of 300, and the
        // truncation note — which compares the two — would call the difference a cap.
        //
        // Unwrapped to a plain array and a `Bool` before the loop rather than tested as an optional
        // inside it: this scan runs over all 314,616 rows and has a measured budget, and an
        // `if let` per row spends an optional check on the unscoped path that pays for nothing.
        let mask = (scopeMask?.count == positions.count) ? (scopeMask ?? []) : []
        let isScoped = !mask.isEmpty
        for row in 0..<positions.count {
            if isScoped && mask[row] != 0 { continue }
            let x = Float(positions[row].x)
            if x < minX || x > maxX { continue }
            let y = Float(positions[row].y)
            if y < minY || y > maxY { continue }
            guard contains(polygon: polygon, x: x, y: y) else { continue }
            total += 1
            if found.count < limit { found.append(row) }
        }
        return (found, total)
    }

    /// The rows belonging to one region, capped, with the honest total beside them.
    ///
    /// A sibling of `rows(inside:…)` and deliberately the same shape, because both feed the same
    /// `WorkingCorpus` capture and the truncation note compares the same two numbers. Everything
    /// that method's documentation says about the cap and the scope mask applies here: the scan runs
    /// to completion rather than stopping at the limit, so `total` is a denominator rather than a
    /// restatement of the numerator, and the mask gates the total as well as the kept rows.
    ///
    /// Takes a closure rather than an array so the caller can read cluster ids straight out of the
    /// mapped artifact without materialising 314,616 `UInt16`s, while a test can pass a synthetic
    /// corpus. One implementation, two callers, no second copy of the rule to drift.
    ///
    /// - Parameters:
    ///   - cluster: The region's id.
    ///   - count: How many rows the artifact holds.
    ///   - clusterAt: The cluster id of a row.
    ///   - limit: Keep at most this many rows.
    ///   - scopeMask: The active scope, when there is one. A mask whose length does not match
    ///     `count` is stale and is ignored, matching the lasso.
    /// - Returns: The kept rows, ascending, and every in-scope row in the region.
    public static func rows(
        inCluster cluster: UInt16,
        count: Int,
        clusterAt: (Int) -> UInt16,
        limit: Int,
        scopeMask: [UInt8]? = nil
    ) -> (rows: [Int], total: Int) {
        guard count > 0, limit > 0, cluster != SemanticMapArtifacts.unclustered else { return ([], 0) }
        let mask = (scopeMask?.count == count) ? (scopeMask ?? []) : []
        let isScoped = !mask.isEmpty
        var found: [Int] = []
        var total = 0
        for row in 0..<count {
            if isScoped && mask[row] != 0 { continue }
            guard clusterAt(row) == cluster else { continue }
            total += 1
            if found.count < limit { found.append(row) }
        }
        return (found, total)
    }

    /// Even-odd containment.
    ///
    /// - Parameters:
    ///   - polygon: The closed path in grid space.
    ///   - x: Grid x.
    ///   - y: Grid y.
    /// - Returns: Whether the point is inside.
    public static func contains(polygon: [SIMD2<Float>], x: Float, y: Float) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[j]
            // Half-open on y so a vertex exactly at the ray's height is counted once, not twice or
            // zero times — the classic source of speckled holes along a horizontal edge.
            if (a.y > y) != (b.y > y) {
                let t = (y - a.y) / (b.y - a.y)
                if x < a.x + t * (b.x - a.x) { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Finds the document nearest a point in the view, within the tap radius.
    ///
    /// - Parameters:
    ///   - point: Where the reader tapped, in view points.
    ///   - positions: The **displayed** grid positions, one per row.
    ///   - camera: Where the camera is looking.
    ///   - size: The view's size in points.
    ///   - radius: How far a tap may miss, in view points.
    /// - Returns: The nearest document within the radius, or `nil` when the tap landed on empty map.
    public static func hit(
        at point: CGPoint,
        positions: [SIMD2<Int16>],
        camera: SemanticMapCamera,
        size: CGSize,
        radius: CGFloat = tapRadius,
        scopeMask: [UInt8]? = nil
    ) -> Hit? {
        guard size.width > 0, size.height > 0 else { return nil }
        let target = SemanticMapLabelLayout.unproject(point, camera: camera, size: size)

        // The tolerance is a screen distance, so convert it through the same scale the projection
        // uses. Grid units per view point differ per axis on a non-square viewport, and taking the
        // larger keeps the pick radius from being tighter than it looks in the narrow axis.
        let aspect = Float(size.width / size.height)
        let scale = camera.scale(aspect: aspect)
        let gridPerPointX = scale.x * 2 / Float(size.width)
        let gridPerPointY = scale.y * 2 / Float(size.height)
        let tolerance = Float(radius) * max(gridPerPointX, gridPerPointY)
        return hit(nearGrid: target, tolerance: tolerance, positions: positions, scopeMask: scopeMask)
    }

    /// Finds the document nearest a point in the map's own coordinates, within a tolerance in grid
    /// units.
    ///
    /// What ``hit(at:positions:camera:size:radius:scopeMask:)`` runs once it has turned the tap and
    /// its radius into grid space, for a host that holds them there already — a server that is asked
    /// in the map's coordinates and holds no view. The scan, its cheap rejection, its tie rule and the
    /// scope's gate are that method's.
    ///
    /// - Parameters:
    ///   - target: The point, in grid units.
    ///   - tolerance: How far a pick may miss, in grid units.
    ///   - positions: The **displayed** grid positions, one per row.
    ///   - scopeMask: The active scope, when there is one; a mask whose length does not match
    ///     `positions` is stale and is ignored.
    /// - Returns: The nearest document within the tolerance, or `nil` when there is none.
    public static func hit(
        nearGrid target: SIMD2<Float>,
        tolerance: Float,
        positions: [SIMD2<Int16>],
        scopeMask: [UInt8]? = nil
    ) -> Hit? {
        let toleranceSquared = tolerance * tolerance

        var bestRow = -1
        var bestDistance = Float.greatestFiniteMagnitude
        var bestPosition = SIMD2<Float>(0, 0)

        // An out-of-scope point is drawn as ground, so it must not be pickable: a tap that opened a
        // document the reader had just excluded — and whose region name the scoped map no longer even
        // labels — would be the map disagreeing with its own scope chip. Hoisted out of the loop for
        // the reason `rows(inside:)` gives.
        let mask = (scopeMask?.count == positions.count) ? (scopeMask ?? []) : []
        let isScoped = !mask.isEmpty
        for row in 0..<positions.count {
            if isScoped && mask[row] != 0 { continue }
            let x = Float(positions[row].x)
            let dx = x - target.x
            // Cheap rejection on one axis before touching the second. Most of the corpus is
            // nowhere near any given tap, and this is the whole reason the scan is fast enough.
            if dx * dx > toleranceSquared { continue }
            let y = Float(positions[row].y)
            let dy = y - target.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance && distance <= toleranceSquared {
                bestDistance = distance
                bestRow = row
                bestPosition = SIMD2<Float>(x, y)
            }
        }

        guard bestRow >= 0 else { return nil }
        return Hit(row: bestRow, position: bestPosition)
    }

    /// The name of the region a row falls in, or `nil` when it falls between regions.
    ///
    /// **By ROW, from the artifact, never from a position**: a slice re-lays the same documents out,
    /// so a position means something different there, but a row still means the same document and
    /// therefore the same region. A tap and a reveal on one document name it the same way through
    /// this, or the two paths would disagree about which region a document is in. The name is the
    /// region's first three terms, the map's own form of it.
    ///
    /// - Parameters:
    ///   - row: The artifact row.
    ///   - map: The mapped placements.
    ///   - clusters: The artifact's regions.
    /// - Returns: The region's name, or `nil` between regions.
    public static func regionName(ofRow row: Int, map: SemanticMapVectors,
                                  clusters: [SemanticMapArtifacts.Cluster]) -> String? {
        let clusterID = map.placement(at: row)?.cluster ?? SemanticMapArtifacts.unclustered
        let region = clusterID == SemanticMapArtifacts.unclustered
            ? nil
            : clusters.first { $0.id == Int(clusterID) }
        return region.map { $0.terms.prefix(3).joined(separator: " ") }
    }

    /// The map's own plane: each row's grid position as the artifact places it, in row order.
    ///
    /// The **displayed** positions the hit test and the lasso scan while no slice is drawn. The app's
    /// model reads them out of the same block as it fills the renderer's points; a host that draws
    /// elsewhere and picks here takes them from this.
    ///
    /// - Parameter map: The mapped placements.
    /// - Returns: One position per document.
    public static func positions(of map: SemanticMapVectors) -> [SIMD2<Int16>] {
        var positions = [SIMD2<Int16>]()
        positions.reserveCapacity(map.documentCount)
        map.withPlacements { base, count in
            for row in 0..<count {
                let offset = row * SemanticMapArtifacts.bytesPerDocument
                positions.append(SIMD2<Int16>(
                    Int16(bitPattern: base.loadUnaligned(
                        fromByteOffset: offset, as: UInt16.self).littleEndian),
                    Int16(bitPattern: base.loadUnaligned(
                        fromByteOffset: offset + 2, as: UInt16.self).littleEndian)))
            }
        }
        return positions
    }
}
