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
/// ## The figure, and how it is assembled (W-3 / #1007 — this section replaces the old
/// "No figure, deliberately" refusal, whose justification expired when the offscreen pass shipped)
/// Manual §13.9 promises every analytics chart a figure *or* its data; this surface now ships
/// both. `ImageRenderer` still cannot capture a `CAMetalLayer` drawable — that fact did not
/// change. What changed is that `SemanticMapRenderer.renderOffscreen` renders the SAME corpus
/// through the SAME pipeline into a private texture and hands back a `CGImage`. The figure is
/// then a composite: the point layer is Metal, the region labels and plate chrome are SwiftUI
/// (`SemanticMapFigureContent` inside `AnalyticsFigureCanvas`), and the two are composited
/// rather than one being reimplemented in the other — text shaping stays out of shaders, and
/// the point pass stays out of `Canvas`. Both layers derive their geometry from ONE export
/// rectangle, which is what keeps a label on its region at every plate size. The plate is a
/// dark map inset in the light figure canvas, deliberately: the shader's scope treatment was
/// tuned against the dark ground, and a light-background map would be a design change wearing
/// an export option's clothes.
///
/// Version history:
///   1.0 — CW-7a (UI review M-20 / F-28): regions CSV + provenance
///   1.3 — Visual-marketing gap 5: `FigureFrame` — a figure states what was in frame and how many
///         regions it names, neither of which was recoverable from the plate
///   1.2 — Visual-marketing step 1: `lens` replaces `lensLabel`, so the lens's own caveat reaches
///         both export halves; four table-only phrasings reworded to stay true on a figure
///   1.1 — W-3 (#1007): the figure — `figureTitle`/`sliceDescription` parameters on
///         ``provenance(index:scopeLabel:scopedDocumentCount:lens:indexedVolumeCount:figureTitle:sliceDescription:)``,
///         and the refusal section above rewritten as the assembly description
enum SemanticMapExport {

    // MARK: - The figure's frame

    /// What was in frame when a FIGURE was rendered — the facts a plate cannot otherwise state.
    ///
    /// A figure is a photograph of a view, and the view is not the reader's. The export builds its
    /// uniforms from its own plate rectangle, so its field of view differs from a wide Mac window's;
    /// and `SemanticMapLabelLayout` re-runs its spacing rule against that rectangle, so **the figure
    /// can name regions the on-screen reader never saw named, and omit ones they did**. Neither
    /// fact was recoverable from the plate.
    ///
    /// Figure-only, and `nil` everywhere else on purpose. The regions CSV lists every region
    /// regardless of what was on screen, so a frame sentence there would describe a framing the
    /// table does not depend on. The frame sequence is a moving camera; one frame's numbers would
    /// be false of the other 552.
    struct FigureFrame: Equatable, Sendable {
        /// The camera the plate was rendered through.
        let camera: SemanticMapCamera
        /// The plate rectangle, in points.
        let size: CGSize
        /// How many regions this figure actually names.
        let labelledRegionCount: Int
    }

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
    ///   - lens: The colour lens in effect. **The lens itself, not its label** — a lens that
    ///     carries a `caption` carries it because the colouring is not self-explanatory, and
    ///     `provenance` is the one place that caveat can reach both export halves. Passing a label
    ///     made the caption structurally unreachable, which is how the `.provenance` lens shipped
    ///     an export that never said its categories are a plurality.
    ///   - indexedVolumeCount: Volumes this device can actually open, or **`nil` when the export
    ///     has no such affordance**. A film is the case: nobody opens a document out of a video, so
    ///     "only the N volume(s) indexed on this device can be opened from it" is not a caveat
    ///     there, it is a sentence about a thing the artifact cannot do. The frame-sequence sidecar
    ///     shipped it reading "the 0 volume(s)", which is worse than saying nothing.
    /// - Returns: The provenance block.
    /// - Parameters (figure additions, W-3):
    ///   - figureTitle: Overrides the default regions-table title — the FIGURE passes
    ///     "Semantic map", because it is a picture of the map, not of the table.
    ///   - sliceDescription: Non-nil when the export shows a SLICE. It leads the caveats,
    ///     because a slice figure omits its region labels (a region's centre belongs to the map
    ///     plane, not the slice) and without this sentence the reader has no way to know why.
    ///   - frame: Non-nil for a FIGURE. Adds the frame and label-selection caveats — see
    ///     ``FigureFrame``.
    static func provenance(index: SemanticMapArtifacts.MapIndex,
                           scopeLabel: String?,
                           scopedDocumentCount: Int?,
                           lens: SemanticMapLens,
                           indexedVolumeCount: Int?,
                           figureTitle: String? = nil,
                           sliceDescription: String? = nil,
                           frame: FigureFrame? = nil) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: figureTitle ?? String(localized: "semanticMap.export.title",
                                defaultValue: "Semantic map regions"),
            axisLabel: String(localized: "semanticMap.export.axis",
                              defaultValue: "Documents"),
            scopeLabel: scopeLabel,
            // Unused here — `corpusStatement` is always supplied below, so the default
            // device-limited caveat this feeds never renders. Zero is the neutral filler.
            indexedVolumeCount: indexedVolumeCount ?? 0,
            yearRange: nil,
            // The map has no date axis at all: position is projected similarity, not time.
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "semanticMap.export.unit", defaultValue: "Documents"),
            corpusStatement: corpusStatement(index: index,
                                             scopedDocumentCount: scopedDocumentCount,
                                             indexedVolumeCount: indexedVolumeCount),
            extraCaveats: (sliceDescription.map { [$0] } ?? [])
                + caveats(index: index, lens: lens)
                + frameCaveats(index: index, frame: frame))
    }

    /// The corpus sentence, which has to say two different numbers that are easy to conflate: what
    /// the map draws (the whole series, from the bundle) and what this device could open (the
    /// volumes actually indexed here).
    private static func corpusStatement(index: SemanticMapArtifacts.MapIndex,
                                        scopedDocumentCount: Int?,
                                        indexedVolumeCount: Int?) -> String {
        let whole = String(format: String(
            localized: "semanticMap.export.caveat.corpus.whole %lld",
            defaultValue: "Corpus: the map is a bundled artifact covering all %1$lld documents in the published series, and draws them whether or not a volume has been downloaded."),
            Int64(index.documentCount))
        // The device-reach clause only where the reader can act on it.
        let base = indexedVolumeCount.map { count in
            whole + " " + String(format: String(
                localized: "semanticMap.export.caveat.corpus.reach %lld",
                defaultValue: "Only the %1$lld volume(s) indexed on this device can be opened from it."),
                Int64(count))
        } ?? whole
        guard let scopedDocumentCount else { return base }
        return base + " " + String(format: String(
            localized: "semanticMap.export.caveat.scoped %lld",
            defaultValue: "The current scope covers %1$lld of those documents; every count in this export is taken inside that scope."),
            Int64(scopedDocumentCount))
    }

    /// The caveats, every one of which is a fact the reader can otherwise only get off the screen.
    private static func caveats(index: SemanticMapArtifacts.MapIndex,
                                lens: SemanticMapLens) -> [String] {
        let layout = index.layout
        var lines: [String] = [
            // The sentence the map already prints under itself. An export that dropped it would
            // let a reader treat the distance between two rows' centres as a measurement.
            String(localized: "semanticMap.export.caveat.layout",
                   defaultValue: "How to read position: the projection preserves local similarity, so documents near each other are alike. Distances between far-apart regions are not meaningful, and neither is direction — there is no axis, no scale and no origin."),
            String(localized: "semanticMap.export.caveat.experimental",
                   defaultValue: "This surface is experimental. The regions are found by a clustering algorithm, not by an editor, and their names are the most distinctive words in a sample of each region's documents — not subject headings."),
            String(format: String(
                localized: "semanticMap.export.caveat.unclustered %lld %lld %lld",
                defaultValue: "Coverage: %1$lld regions cover %2$lld documents. The other %3$lld sit between regions and belong to none: a regions table cannot list them, and on the map they are drawn with no region name."),
                Int64(index.clusters.count),
                Int64(index.documentCount - layout.unclusteredCount),
                Int64(layout.unclusteredCount)),
            String(format: String(
                localized: "semanticMap.export.caveat.method %@ %lld %lld %@ %@",
                defaultValue: "Method: %1$@ from %2$lld dimensions (neighbors %3$lld), clustered with %4$@. Labels: %5$@."),
                layout.method, Int64(layout.sourceDims), Int64(layout.neighbors),
                layout.clustering, layout.labelSampling),
            String(format: String(
                localized: "semanticMap.export.caveat.artifact %@ %@",
                defaultValue: "Artifact: generated %1$@, provenance %2$@. The layout is pinned to a fixed seed, so the same artifact always draws the same map."),
                index.generated, index.provenanceDigest),
            String(format: String(
                localized: "semanticMap.export.caveat.lens %@",
                defaultValue: "Color lens in effect when this export was taken: %1$@. The lens changes only what the points are colored by, never where they sit."),
                lens.displayName),
            String(localized: "semanticMap.export.caveat.identity",
                   defaultValue: "The map artifact stores positions and region membership only — no document titles and no dates — so an export from it can name regions and counts, and cannot name a document."),
        ]
        // The lens's OWN caveat, which until now reached only the on-screen legend. A lens carries
        // a caption exactly when its colouring would otherwise overstate the evidence — the
        // provenance lens's categories are a plurality, not a majority, for 73 of 522 volumes — so
        // an export without it is an export that overstates. Appended last, beside the lens line
        // it qualifies.
        if let caption = lens.caption { lines.append(caption) }
        return lines
    }

    /// What a figure can say about its own framing, and nothing when there is no figure.
    ///
    /// Two sentences, because they answer two different questions a reader of a published plate
    /// will have: *what am I looking at*, and *why are these the names on it*.
    ///
    /// The coordinates are stated even though the projection has no axis, scale or origin — and the
    /// sentence says both things at once. They are not a measurement and must not be read as one;
    /// they are the parameters that restore this exact view in the app, which is what a methods
    /// statement is for. Suppressing them because they could be misread would leave a figure whose
    /// framing is unreproducible.
    private static func frameCaveats(index: SemanticMapArtifacts.MapIndex,
                                     frame: FigureFrame?) -> [String] {
        guard let frame else { return [] }
        let aspect = frame.size.height > 0 ? Float(frame.size.width / frame.size.height) : 1
        let visible = frame.camera.scale(aspect: aspect)
        // The artifact's grid is int16, so ±32,768 on each axis is the whole plane.
        let containsWholeMap = visible.x >= 32_768 && visible.y >= 32_768
        let span = containsWholeMap
            ? String(localized: "semanticMap.export.caveat.frame.whole",
                     defaultValue: "the entire map is in frame")
            : String(format: String(localized: "semanticMap.export.caveat.frame.span %lld %lld",
                                    defaultValue: "%1$lld × %2$lld grid units in view"),
                     Int64(visible.x * 2), Int64(visible.y * 2))
        var lines = [String(format: String(
            localized: "semanticMap.export.caveat.frame %lld %lld %lld %lld %@",
            defaultValue: "Frame: rendered at %1$lld × %2$lld points, centered on grid (%3$lld, %4$lld) — %5$@. Those coordinates are the artifact's own grid, recorded so this exact view can be restored; they are not a measurement, and the projection has no axis, no scale and no origin."),
            Int64(frame.size.width), Int64(frame.size.height),
            Int64(frame.camera.centre.x), Int64(frame.camera.centre.y), span)]
        // Only when the figure carries names at all — a slice figure has none, and says so through
        // `sliceDescription` instead.
        if frame.labelledRegionCount > 0 {
            lines.append(String(format: String(
                localized: "semanticMap.export.caveat.frame.labels %lld %lld",
                defaultValue: "Region names shown: %1$lld of %2$lld, chosen to fit this plate. The app's window is a different shape and re-runs the same rule against it, so a reader at the screen sees a different set of names — a region named here can be unnamed there, and the reverse."),
                Int64(frame.labelledRegionCount), Int64(index.clusters.count)))
        }
        return lines
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
            String(localized: "semanticMap.export.column.x", defaultValue: "Center X"),
            String(localized: "semanticMap.export.column.y", defaultValue: "Center Y"),
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

// MARK: - SemanticMapRegionRows

/// The region card's era rows (UI review F-29 / M-21).
///
/// A separate type from the view for one reason: a rule that only exists inside a `private var`
/// cannot be tested, and both of these rules fail *silently* — a dropped era key makes the rows
/// stop summing to the headline, and an iterated `allCases` prints a zero row that reads as a
/// claim about the corpus. This repo's standard is that a test drives the real emitter, so the
/// emitter has to be reachable.
///
/// Version history:
///   1.0 — CW-7b: extracted from `SemanticMapSpikeView.regionEraRows`
enum SemanticMapRegionRows {

    /// One era's label and count, as the card prints them.
    struct Row {
        /// The era's name, or the fallback for a key this app has no case for.
        let label: String
        /// The document count, already a string for display.
        let count: String
    }

    /// The rows for a region, oldest era first, keeping every key.
    ///
    /// - Parameter cluster: The region, straight from the artifact.
    /// - Returns: Rows that account for every document in `cluster.documentCount`.
    static func eraRows(_ cluster: SemanticMapArtifacts.Cluster) -> [Row] {
        let known = cluster.eraCounts
            .compactMap { key, value -> (Int, String, Int)? in
                guard let raw = Int(key), let era = CoverageEra(rawValue: raw) else { return nil }
                return (raw, era.label, value)
            }
            .sorted { $0.0 < $1.0 }
            .map { Row(label: $0.1, count: String($0.2)) }
        // Anything that is not a CoverageEra raw value — "unknown" today, which the generator
        // emits for a volume with no parseable coverage year — is pooled into one row rather than
        // dropped, so the rows still account for the headline count.
        let unrecognised = cluster.eraCounts
            .filter { Int($0.key).flatMap(CoverageEra.init(rawValue:)) == nil }
            .map(\.value)
            .reduce(0, +)
        guard unrecognised > 0 else { return known }
        return known + [Row(label: String(localized: "semanticMap.region.era.unknown",
                                          defaultValue: "Undated volumes"),
                            count: String(unrecognised))]
    }
}
