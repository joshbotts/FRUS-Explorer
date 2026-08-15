// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SemanticMapExport

/// The semantic map's exit: the regions table and the methods statement that rides above it
/// (UI review M-20 / F-28).
///
/// ## Why a table of regions and not a table of documents
/// The map draws 314,483 points, and "the data behind it" read literally is 314,483 coordinate
/// rows — a file nobody can check against anything. The regions table is the one the reader can
/// audit: every row is a label they can see on screen, with the count the map itself drew it
/// from. It is also the only grain at which the artifact has something to say beyond position.
///
/// ## The identity ceiling, enforced here rather than remembered
/// The map artifact carries **ids only** — `Placement` is six bytes of int16 x, int16 y and a
/// uint16 cluster, and `SemanticVectorIndex.document(at:)` returns `(volumeID, documentID)`. It
/// has no document titles and no dates. So this table names regions and counts, and the only
/// prose in it is the cluster's own terms, which are corpus tokens. `SemanticMapSpikeView` states
/// the same ceiling at its selection card ("the artifact carries no per-document titles, so
/// `volume title · Doc id` is the honest ceiling"), and CLAUDE.md writes the same posture for
/// `resolved-edge-index.json`. A table that invented a title would be inventing evidence.
///
/// ## No figure, deliberately
/// Manual §13.9 promises every analytics chart a figure *or* its data, and this ships the data
/// half only. That is a refusal, not an omission, and the reason is structural: the map is a
/// Metal point-sprite pass inside an `MTKView`, and the app's figure path
/// (`AnalyticsFigureExporter`) drives `ImageRenderer` over a SwiftUI view — which captures the
/// SwiftUI layer tree, not a `CAMetalLayer` drawable, and would render the map as a blank plate.
/// The two real routes are an offscreen Metal pass into a private texture, or reading back
/// `currentDrawable.texture` (which this view cannot do: `MTKView.framebufferOnly` defaults to
/// true and nothing in the repo clears it, and it would capture the visible viewport at screen
/// resolution rather than a publication plate). Either is a Metal work item, not an adoption, and
/// `AnalyticsSectionExportControl` already supports a CSV-only surface by construction — omit
/// `exportFigure` and the PNG/PDF items do not exist.
///
/// Version history:
///   1.0 — CW-7a (UI review M-20 / F-28): regions CSV + provenance
enum SemanticMapExport {

    // MARK: - Provenance

    /// The methods statement printed above the regions CSV.
    ///
    /// **`corpusStatement` is supplied and must stay supplied.** `AnalyticsProvenance`'s default
    /// corpus caveat says counts "cover only the N volume(s) indexed on this device" — which is
    /// false here and would be a false methods statement in a file written to outlive the screen.
    /// The map is a bundled whole-series artifact: it draws all 314,483 documents with zero
    /// volumes downloaded. That is precisely the case `corpusStatement` was added for.
    ///
    /// - Parameters:
    ///   - index: The bundled map index, for the layout parameters and the generation stamp.
    ///   - scopeLabel: The scope bar's current label, or `nil` for the whole corpus.
    ///   - scopedDocumentCount: Documents inside the current scope, or `nil` when unscoped.
    ///   - lensLabel: The colour lens in effect when the table was taken.
    ///   - indexedVolumeCount: Volumes this device can actually open.
    /// - Returns: The provenance block.
    static func provenance(index: SemanticMapArtifacts.MapIndex,
                           scopeLabel: String?,
                           scopedDocumentCount: Int?,
                           lensLabel: String,
                           indexedVolumeCount: Int) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: String(localized: "semanticMap.export.title",
                                defaultValue: "Semantic map regions"),
            axisLabel: String(localized: "semanticMap.export.axis",
                              defaultValue: "Documents"),
            scopeLabel: scopeLabel,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            // The map has no date axis at all: position is projected similarity, not time.
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "semanticMap.export.unit", defaultValue: "Documents"),
            corpusStatement: corpusStatement(index: index,
                                             scopedDocumentCount: scopedDocumentCount,
                                             indexedVolumeCount: indexedVolumeCount),
            extraCaveats: caveats(index: index, lensLabel: lensLabel))
    }

    /// The corpus sentence, which has to say two different numbers that are easy to conflate: what
    /// the map draws (the whole series, from the bundle) and what this device could open (the
    /// volumes actually indexed here).
    private static func corpusStatement(index: SemanticMapArtifacts.MapIndex,
                                        scopedDocumentCount: Int?,
                                        indexedVolumeCount: Int) -> String {
        let base = String(format: String(
            localized: "semanticMap.export.caveat.corpus %lld %lld",
            defaultValue: "Corpus: the map is a bundled artifact covering all %1$lld documents in the published series, and draws them whether or not a volume has been downloaded. Only the %2$lld volume(s) indexed on this device can be opened from it."),
            Int64(index.documentCount), Int64(indexedVolumeCount))
        guard let scopedDocumentCount else { return base }
        return base + " " + String(format: String(
            localized: "semanticMap.export.caveat.scoped %lld",
            defaultValue: "The current scope covers %1$lld of those documents; every row below is counted inside that scope."),
            Int64(scopedDocumentCount))
    }

    /// The caveats, every one of which is a fact the reader can otherwise only get off the screen.
    private static func caveats(index: SemanticMapArtifacts.MapIndex,
                                lensLabel: String) -> [String] {
        let layout = index.layout
        return [
            // The sentence the map already prints under itself. An export that dropped it would
            // let a reader treat the distance between two rows' centres as a measurement.
            String(localized: "semanticMap.export.caveat.layout",
                   defaultValue: "How to read position: the projection preserves local similarity, so documents near each other are alike. Distances between far-apart regions are not meaningful, and neither is direction — there is no axis, no scale and no origin."),
            String(localized: "semanticMap.export.caveat.experimental",
                   defaultValue: "This surface is experimental. The regions are found by a clustering algorithm, not by an editor, and their names are the most distinctive words in a sample of each region's documents — not subject headings."),
            String(format: String(
                localized: "semanticMap.export.caveat.unclustered %lld %lld %lld",
                defaultValue: "Coverage: %1$lld regions cover %2$lld documents. The other %3$lld sit between regions and appear in no row below — a table of regions cannot describe them."),
                Int64(index.clusters.count),
                Int64(index.documentCount - layout.unclusteredCount),
                Int64(layout.unclusteredCount)),
            String(format: String(
                localized: "semanticMap.export.caveat.method %@ %lld %lld %@ %@",
                defaultValue: "Method: %1$@ from %2$lld dimensions (neighbours %3$lld), clustered with %4$@. Labels: %5$@."),
                layout.method, Int64(layout.sourceDims), Int64(layout.neighbors),
                layout.clustering, layout.labelSampling),
            String(format: String(
                localized: "semanticMap.export.caveat.artifact %@ %@",
                defaultValue: "Artifact: generated %1$@, provenance %2$@. The layout is pinned to a fixed seed, so the same artifact always draws the same map."),
                index.generated, index.provenanceDigest),
            String(format: String(
                localized: "semanticMap.export.caveat.lens %@",
                defaultValue: "Colour lens in effect when this table was taken: %1$@. The lens changes only what the points are coloured by, never where they sit."),
                lensLabel),
            String(localized: "semanticMap.export.caveat.identity",
                   defaultValue: "The map artifact stores positions and region membership only — no document titles and no dates — so this table names regions and counts, and cannot name a document."),
        ]
    }

    // MARK: - Table

    /// One row per region, in the order the map ranks them.
    ///
    /// The ranking is document count descending with an id tiebreak — the same comparator
    /// `SemanticMapLabelLayout` uses to decide which labels get drawn, so the top of this table is
    /// the set of names a reader actually sees. Every region is listed, not just the ~22 the
    /// canvas has room for: the drawing cap is a space compromise, not a fact about the data, and
    /// the cross-reference graph's accessibility list sets the same precedent.
    ///
    /// - Parameters:
    ///   - clusters: The regions to list — the scope-aware `labelledClusters` when a scope is on,
    ///     so counts agree with what the map drew.
    ///   - termCount: How many of each region's terms to name.
    /// - Returns: The table, ready for `provenancedCSV`.
    static func regionsTable(clusters: [SemanticMapArtifacts.Cluster],
                             termCount: Int = 4) -> ChartInspectorData {
        let ranked = clusters.sorted {
            $0.documentCount == $1.documentCount ? $0.id < $1.id
                                                 : $0.documentCount > $1.documentCount
        }
        let eras = CoverageEra.allCases
        let columns = [
            String(localized: "semanticMap.export.column.region", defaultValue: "Region"),
            String(localized: "semanticMap.export.column.terms", defaultValue: "Terms"),
            String(localized: "semanticMap.export.column.documents", defaultValue: "Documents"),
            String(localized: "semanticMap.export.column.x", defaultValue: "Centre X"),
            String(localized: "semanticMap.export.column.y", defaultValue: "Centre Y"),
        ] + eras.map(\.label)
        let rows = ranked.map { cluster -> [String] in
            // `eraCounts` is keyed by CoverageEra's raw value as a string — the artifact's own
            // note says it is stored that way so a reader can say *when* as well as *what*. This
            // is that reader: until now nothing in the app read the field.
            let eraCells = eras.map { era in String(cluster.eraCounts["\(era.rawValue)"] ?? 0) }
            return [
                String(cluster.id),
                cluster.terms.prefix(termCount).joined(separator: " "),
                String(cluster.documentCount),
                String(cluster.centreX),
                String(cluster.centreY),
            ] + eraCells
        }
        return ChartInspectorData(
            id: "semanticMap.regions",
            title: String(localized: "semanticMap.export.table.title",
                          defaultValue: "Semantic map regions"),
            columns: columns,
            rowCells: rows)
    }
}
