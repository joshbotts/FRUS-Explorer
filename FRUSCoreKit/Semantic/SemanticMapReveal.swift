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
// SemanticVectorsKit is a module of its own in a package; Xcode compiles its sources into the app
// target (project.yml), where its types are already in this module and the import is compiled out.
#if canImport(SemanticVectorsKit)
import SemanticVectorsKit
#endif

/// How the map reveals one document or focuses one region, and when a request that names either is
/// settled.
///
/// The rules `SemanticMapModel.reveal(documentKey:isReadable:)` and `focusRegion(id:digest:)` land by, out
/// of the model, so that a host answering a link that names a document or a region lands where the app
/// does: the reader's rail's On the Map, and Browse's See on the semantic map.
///
/// **The map draws every document in the published series, so a reveal works for a volume the device
/// does not hold** — the point is *there*, and showing where a document sits in the corpus's language
/// is worth doing whether or not it can be opened. **Not every document has a point**: 2,356 of the
/// app's display rows are chapter divs, front matter and appendix structure that were never embedded,
/// so a reveal can legitimately fail, and the caller is told.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — out of `SemanticMapModel` and `SemanticMapSpikeView`,
///          which call it
public enum SemanticMapReveal {

    /// The three ways a reveal can end.
    ///
    /// **`.notReady` exists because collapsing it into failure shipped a broken feature.** The map
    /// opens, `prepare()` starts uploading 314,616 points, and the continuation can arrive before
    /// the index exists — at which point a `Bool`-returning reveal says "false", the caller records
    /// the continuation as applied, and the retry that would have worked never happens. The document
    /// simply never gets selected, which is exactly what a reader reported. `setScope` had solved
    /// the same race years earlier by deferring; this is the same lesson arriving late.
    public enum Outcome: Equatable, Sendable {
        /// Selected, and the camera moved to it.
        case revealed
        /// The map is loaded and has no such document — 2,356 display rows were never embedded.
        case notFound
        /// The map is not loaded yet. Ask again; do not record this as an answer.
        case notReady
    }

    /// How much of the map a reveal leaves in view, in grid units.
    ///
    /// Close enough to read the neighbourhood, not so close the surrounding language is off screen —
    /// the question a reveal answers is "what is this document *near*", and a camera pinned to the point
    /// alone would answer "where is this document", which the selection marker already does.
    public static let documentHalfExtent: Float = 900

    /// How much of the map a region focus leaves in view, in grid units — wider than a document
    /// reveal, because the question is "what is this group and what sits around it", not "where is
    /// this point".
    public static let regionHalfExtent: Float = 3600

    /// A `"volumeId/documentId"` key's two halves, or `nil` when it has no separator.
    ///
    /// - Parameter key: The key.
    /// - Returns: The volume and the document, split at the first `/`.
    public static func documentKey(_ key: String) -> (volumeID: String, documentID: String)? {
        let parts = key.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    /// Where a reveal lands: the document selected, and the camera brought to it.
    ///
    /// Region identity by ROW, from `clusters`, as a tap derives it
    /// (``SemanticMapPicking/regionName(ofRow:map:clusters:)``): a reveal and a tap on the same document
    /// must produce the same card, or the two paths disagree about which region a document is in.
    ///
    /// - Parameters:
    ///   - volumeID: The document's volume.
    ///   - documentID: The document's id within it.
    ///   - index: The vector index that keys the rows.
    ///   - map: The mapped placements.
    ///   - clusters: The artifact's regions.
    ///   - isReadable: Whether the host can open a volume's documents.
    /// - Returns: The selection and the camera, or `nil` when the map has no point for the document.
    public static func reveal(volumeID: String, documentID: String, index: SemanticVectorIndex,
                              map: SemanticMapVectors, clusters: [SemanticMapArtifacts.Cluster],
                              isReadable: (String) -> Bool)
        -> (selection: SemanticMapPicking.Selection, camera: SemanticMapCamera)? {
        guard let row = index.row(documentID: documentID, volumeID: volumeID),
              let placement = map.placement(at: row) else { return nil }
        let position = SIMD2(Float(placement.x), Float(placement.y))
        let selection = SemanticMapPicking.Selection(
            row: row,
            volumeID: volumeID,
            documentID: documentID,
            position: position,
            regionName: SemanticMapPicking.regionName(ofRow: row, map: map, clusters: clusters),
            isDownloaded: isReadable(volumeID))
        return (selection, SemanticMapCamera(centre: position, halfExtent: documentHalfExtent))
    }

    /// Whether a cluster-focus request may land on the loaded artifact.
    ///
    /// Cluster ids re-mint per artifact generation, and a request can outlive one, so a focus whose
    /// digest does not match the loaded layout's (`SemanticMapArtifacts.MapIndex.layoutIdentity`) is
    /// refused rather than landing on whatever re-minted cluster now wears the number.
    ///
    /// - Parameters:
    ///   - requestDigest: The digest the request was minted against.
    ///   - artifactDigest: The loaded artifact's digest.
    /// - Returns: `true` only when both exist and agree.
    public static func regionFocusApplies(requestDigest: String?, artifactDigest: String?) -> Bool {
        guard let requestDigest, let artifactDigest else { return false }
        return requestDigest == artifactDigest
    }

    /// Where a region focus lands: the region, and the camera brought to its centre.
    ///
    /// - Parameters:
    ///   - regionID: The artifact's cluster id.
    ///   - digest: The digest the id was minted against.
    ///   - artifactDigest: The loaded artifact's layout identity.
    ///   - clusters: The artifact's regions.
    /// - Returns: The region and the camera, or `nil` when the digest or the id does not land, in which
    ///   case the map opens unfocused.
    public static func focus(regionID: Int, digest: String?, artifactDigest: String?,
                             clusters: [SemanticMapArtifacts.Cluster])
        -> (region: SemanticMapArtifacts.Cluster, camera: SemanticMapCamera)? {
        guard regionFocusApplies(requestDigest: digest, artifactDigest: artifactDigest),
              let region = clusters.first(where: { $0.id == regionID }) else { return nil }
        let position = SIMD2(Float(region.centreX), Float(region.centreY))
        return (region, SemanticMapCamera(centre: position, halfExtent: regionHalfExtent))
    }

    /// Whether a request that produced this reveal outcome may be marked applied.
    ///
    /// **Marking a request applied is precisely what prevents the retry that makes the feature work**,
    /// so only `.notReady` leaves it open.
    ///
    /// - Parameter outcome: The reveal's result, or `nil` when the request carried no document.
    /// - Returns: `true` when the answer is final.
    public static func continuationIsSettled(_ outcome: Outcome?) -> Bool {
        outcome != .notReady
    }
}
