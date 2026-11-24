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

/// What a region and a lasso carry off the map: the documents, the honest total, and the name and
/// description a working corpus is saved under.
///
/// The rules `SemanticMapModel.regionCapture()` and `finishLasso(size:)` resolve a capture by, and the
/// name and source description `SemanticMapSpikeView` saves it under, out of the app, so that a host
/// saving a map's corpus saves the same set under the same words. Both captures are the same type, on
/// purpose: a region is a set of documents the map can already name and count, so the save path, its
/// naming rule, its truncation disclosure and its scope provenance are one set rather than two that
/// could disagree. Every capture stores `"volumeId/documentId"` keys, the identity that survives an
/// artifact's regeneration, never a cluster id.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S28a — out of `SemanticMapModel` and `SemanticMapSpikeView`,
///          which call it, and of Browse's clusters, whose save names its corpus by the same rule
public enum SemanticMapCapture {

    /// A region, captured, ready to become a working corpus.
    ///
    /// Honours the active scope for the same reason the lasso does: a scoped map shows a region
    /// partly greyed, and a capture that quietly included the grey would not be the set on screen.
    /// Capped at ``SemanticMapPicking/corpusCaptureLimit``, with the whole count beside the kept keys.
    ///
    /// - Parameters:
    ///   - region: The region, straight from the artifact.
    ///   - map: The mapped placements.
    ///   - index: The vector index that keys the rows.
    ///   - scopeMask: The active scope's flags, when there is one.
    /// - Returns: The capture, named for the region.
    public static func region(_ region: SemanticMapArtifacts.Cluster, map: SemanticMapVectors,
                              index: SemanticVectorIndex,
                              scopeMask: [UInt8]?) -> SemanticMapPicking.LassoResult {
        let found = SemanticMapPicking.rows(
            inCluster: UInt16(region.id),
            count: index.documentCount,
            clusterAt: { map.placement(at: $0)?.cluster ?? SemanticMapArtifacts.unclustered },
            limit: SemanticMapPicking.corpusCaptureLimit,
            scopeMask: scopeMask)
        var keys: [String] = []
        keys.reserveCapacity(found.rows.count)
        for row in found.rows {
            guard let document = index.document(at: row) else { continue }
            keys.append("\(document.volumeID)/\(document.documentID)")
        }
        // The region's own name, so the saved corpus is identifiable in a list months later. The
        // lasso derives its name from whichever regions it happened to cross; here there is exactly
        // one, and it is the thing the reader pointed at.
        return SemanticMapPicking.LassoResult(
            documentKeys: keys, total: found.total,
            regionNames: [region.terms.prefix(3).joined(separator: " ")])
    }

    /// What a lasso enclosed, resolved to keys and named by the regions it caught most of.
    ///
    /// **Empty is not the same as nothing happened, once a scope is active.** Unscoped, an empty lasso
    /// means the reader enclosed bare canvas and no card is the right answer. Scoped, they may have
    /// drawn a careful ring around a dense grey mass — every point of it excluded — and silence reads
    /// as a broken control rather than as an answer. So the capture is empty, and the card says so.
    ///
    /// Identity is resolved only for the rows that will be kept: `document(at:)` mints a String and
    /// walks a volume's id segments, and doing it for a discarded row is pure waste. The name is the
    /// three regions with the most kept rows, two terms each, ties by id.
    ///
    /// - Parameters:
    ///   - rows: The kept rows, ascending, as ``SemanticMapPicking/rows(inside:positions:camera:size:limit:scopeMask:)``
    ///     or ``SemanticMapPicking/rows(insideGrid:positions:limit:scopeMask:)`` gives them.
    ///   - total: Every in-scope document inside the lasso.
    ///   - isScoped: Whether a scope is active.
    ///   - map: The mapped placements.
    ///   - index: The vector index that keys the rows.
    ///   - clusters: The artifact's regions.
    /// - Returns: The capture, or `nil` for an unscoped lasso that caught nothing.
    public static func lasso(rows: [Int], total: Int, isScoped: Bool, map: SemanticMapVectors,
                             index: SemanticVectorIndex,
                             clusters: [SemanticMapArtifacts.Cluster]) -> SemanticMapPicking.LassoResult? {
        guard !rows.isEmpty else {
            return isScoped ? SemanticMapPicking.LassoResult(documentKeys: [], total: 0, regionNames: []) : nil
        }
        var keys: [String] = []
        keys.reserveCapacity(rows.count)
        var regionCounts: [Int: Int] = [:]
        for row in rows {
            guard let document = index.document(at: row) else { continue }
            keys.append("\(document.volumeID)/\(document.documentID)")
            if let placement = map.placement(at: row),
               placement.cluster != SemanticMapArtifacts.unclustered {
                regionCounts[Int(placement.cluster), default: 0] += 1
            }
        }
        let names = regionCounts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(3)
            .compactMap { entry in
                clusters.first { $0.id == entry.key }?.terms.prefix(2).joined(separator: " ")
            }
        return SemanticMapPicking.LassoResult(
            documentKeys: keys, total: total, regionNames: Array(names))
    }

    /// The name a capture is saved under: the regions it touched, and when.
    ///
    /// Names are NOT unique by design, and the app looks corpora up BY NAME, so two captures over the
    /// same regions must not produce the same string. The capture time disambiguates them and is also
    /// the most useful thing to see in a list.
    ///
    /// - Parameters:
    ///   - regionNames: The capture's regions, most-enclosed first.
    ///   - stamp: When it was taken, as ``stamp(for:locale:timeZone:)`` writes it.
    /// - Returns: The name.
    public static func corpusName(regionNames: [String], stamp: String) -> String {
        let regions = regionNames.isEmpty
            ? String(localized: "semanticMap.lasso.defaultName", defaultValue: "Map selection")
            : regionNames.joined(separator: ", ")
        let name = "\(regions) — \(stamp)"
        return name
    }

    /// A capture's time, as its name carries it: the date abbreviated and the time short.
    ///
    /// - Parameters:
    ///   - date: When the capture was taken.
    ///   - locale: The reader's locale; the app passes its current one.
    ///   - timeZone: The reader's time zone; the app passes its current one.
    /// - Returns: The stamp.
    public static func stamp(for date: Date, locale: Locale = .autoupdatingCurrent,
                             timeZone: TimeZone = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened,
                                        locale: locale, timeZone: timeZone))
    }

    /// The source description a map's capture is saved with.
    ///
    /// Names the scope, when there was one. A corpus captured from a scoped map holds only that
    /// scope's documents, and its provenance is the one place that fact survives after the map is
    /// closed — without it, two lassos over the same region under two different scopes are
    /// indistinguishable in the corpora list.
    ///
    /// - Parameter scopeLabel: The scope's name, or `nil` when unscoped.
    /// - Returns: The description.
    public static func sourceDescription(scopeLabel: String?) -> String {
        scopeLabel.map { label in
            String(format: String(localized: "semanticMap.lasso.source.scoped %@",
                                  defaultValue: "Semantic map selection, scoped to %@"), label)
        } ?? String(localized: "semanticMap.lasso.source",
                    defaultValue: "Semantic map selection")
    }
}
