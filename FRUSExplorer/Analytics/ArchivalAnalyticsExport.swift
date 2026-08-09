// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalExportRequest

/// One archival chart's data plus the methods statement that must travel with it (#787).
///
/// Bundled as a value so the two `Canvas` modes, which own their own state, can hand an export
/// up to the shell that holds the share sheet without also inheriting its plumbing.
struct ArchivalExportRequest: Identifiable, Equatable {
    /// The table to write.
    let table: ChartInspectorData
    /// The methods statement to stamp above it.
    let provenance: AnalyticsProvenance

    var id: String { table.id }
}

// MARK: - ArchivalAnalyticsExport

/// The provenance statements the archival surfaces stamp on their exports.
///
/// ## Why these are not the analytics dashboards' provenance
/// Every field the three older dashboards fill is about a term searched over a dated corpus. None
/// of the archival figures is either: they count **source notes**, they are scoped by an era band
/// or by the reader's own library rather than by a year range, and not one of them reads a
/// document's date. So `appliesDocumentDating` is `false` throughout — the word cloud set that
/// precedent for exactly this reason, and printing "each document is placed at its TEI `<date>`…"
/// above a table that never looked at a date is a methods statement about work the export did not
/// do.
///
/// ## What the caveats have to carry
/// The archival numbers are the ones in this app that most need their method attached, because
/// two of them are honest but counter-intuitive: Documents and Volumes count **different
/// populations**, and the default view **withholds** the Central Files umbrella. A CSV that
/// stated neither would be read as a complete ranking.
///
/// Version history:
///   1.0 — Session 2026-08-09: #787
enum ArchivalAnalyticsExport {

    /// The caveat every archival export carries: what the figures are parsed from, and what they
    /// are not.
    static var baseCaveat: String {
        String(localized: "archival.export.caveat.base",
               defaultValue: "Method: these figures are parsed from the source note each published FRUS document carries — the citation naming where its archival original was found. They record where the editors drew documents from, an editorial and archival signal, not a census of the archives themselves. Collections are clustered across volumes by name, so an under-merge leaves one body of records under two nearby names rather than combining them.")
    }

    /// The Collections ranking's statement.
    ///
    /// - Parameters:
    ///   - band: The era band on screen.
    ///   - lens: Named collections or central-file classes.
    ///   - weight: Documents or volumes.
    ///   - hiddenUmbrella: What the umbrella filter withheld in this band, when it withheld
    ///     anything. Stated as a number, because a ranking missing its largest member without
    ///     saying so is the defect this whole caveat block exists to prevent.
    ///   - indexedVolumeCount: Volumes indexed on this device.
    static func ranking(band: ArchivalEraBand, lens: ArchivalUnitLens, weight: ArchivalWeight,
                        hiddenUmbrella: Int?, unitsReached: Int, bandVolumeCount: Int,
                        indexedVolumeCount: Int) -> AnalyticsProvenance {
        var caveats = [baseCaveat, weightCaveat, coverageCaveat]
        if let hiddenUmbrella {
            caveats.append(String(format: String(
                localized: "archival.export.caveat.umbrella %lld %@",
                defaultValue: "Withheld: the Central Files umbrella record is excluded from this ranking. It accounts for %1$lld %2$@ in this era on its own, and its bar would flatten the scale. The era-specific Central Files records are included."),
                Int64(hiddenUmbrella), weight.title.lowercased()))
        }
        caveats.append(String(format: String(
            localized: "archival.export.caveat.scope %lld %lld",
            defaultValue: "Scope: %1$lld volumes cover this era, and %2$lld archival units in them carry at least one document under the current unit and weight."),
            Int64(bandVolumeCount), Int64(unitsReached)))
        return AnalyticsProvenance(
            figureTitle: String(format: String(localized: "archival.export.title.ranking %@ %@",
                                               defaultValue: "%1$@ by era — %2$@"),
                                lens.title, band.title),
            axisLabel: String(format: String(localized: "archival.export.axis.ranking %@ %@",
                                             defaultValue: "Ranked by %1$@, %2$@ volumes"),
                              weight.title.lowercased(), band.title),
            scopeLabel: band.title,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: band.startYear...band.endYear,
            // Nothing here reads a document's date: the era comes from the VOLUME's coverage
            // span, and the counts are of source notes.
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: weight.title,
            extraCaveats: caveats)
    }

    /// The lifecycle card's statement.
    static func lifecycles(spanCount: Int, indexedVolumeCount: Int) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: String(localized: "archival.lifecycle.title",
                                defaultValue: "Collection lifecycles in FRUS sourcing"),
            axisLabel: String(localized: "archival.export.axis.lifecycle",
                              defaultValue: "Coverage years spanned by citing volumes"),
            scopeLabel: nil,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "archival.weight.volumes", defaultValue: "Volumes"),
            extraCaveats: [
                baseCaveat,
                String(format: String(
                    localized: "archival.export.caveat.lifecycle %lld",
                    defaultValue: "Scope: the %lld most widely cited collections in the series, ranked by how many volumes cite them. A span runs from the earliest to the latest coverage year of those volumes and says nothing about how densely the years between are covered."),
                    Int64(spanCount)),
            ])
    }

    /// A Your Library card's statement.
    ///
    /// - Parameters:
    ///   - title: The card's own title.
    ///   - axisLabel: What the figure is ranked or divided by.
    ///   - profile: The library being described, for its two denominators.
    ///   - indexedVolumeCount: Volumes indexed on this device.
    ///   - corpusVolumeCount: Volumes in the series.
    static func library(title: String, axisLabel: String, profile: ArchivalLibraryProfile,
                        indexedVolumeCount: Int, corpusVolumeCount: Int) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: title,
            axisLabel: axisLabel,
            scopeLabel: String(localized: "archival.export.scope.library",
                               defaultValue: "Your indexed volumes"),
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "archival.export.unit.notes",
                                 defaultValue: "Source notes"),
            extraCaveats: [
                baseCaveat,
                String(format: String(
                    localized: "archival.export.caveat.library %lld %lld %lld",
                    defaultValue: "Scope: counted from this device's own index — %1$lld source notes across the %2$lld indexed volumes that carry them, out of %3$lld volumes in the series. These figures change as more volumes are indexed and are not comparable with the corpus-wide archival figures."),
                    Int64(profile.noteCount), Int64(profile.volumeCount),
                    Int64(corpusVolumeCount)),
                String(localized: "archival.export.caveat.notes",
                       defaultValue: "Unit: a source note is not a document. Only documents whose editors recorded where the original was found are counted, so this total is smaller than the indexed document count."),
            ])
    }

    /// The Network mode's statement.
    static func network(focusName: String, measure: ArchivalEdgeMeasure, drawn: Int,
                        aboveThreshold: Int, partnersTotal: Int,
                        indexedVolumeCount: Int) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: String(format: String(localized: "archival.export.title.network %@",
                                               defaultValue: "Co-cited with %@"),
                                focusName),
            axisLabel: measure.title,
            scopeLabel: nil,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: measure.title,
            extraCaveats: [
                baseCaveat,
                String(localized: "archival.export.caveat.network.grain",
                       defaultValue: "Grain: a link is volume-grain — the same volumes drew on both collections. A document has exactly one source note, so there is no document-level co-citation; the shared-documents measure is how much material the two jointly supplied to the volumes they share, not documents citing both."),
                String(format: String(
                    localized: "archival.export.caveat.network.scope %lld %lld %lld",
                    defaultValue: "Scope: %1$lld of the %2$lld units above the current threshold are listed, and %3$lld collections share two or more volumes with the focus in total. The graph draws at most six per custodian so each quadrant stays readable; this table lists exactly what the graph drew."),
                    Int64(drawn), Int64(aboveThreshold), Int64(partnersTotal)),
            ])
    }

    /// The Flows mode's statement — the one that owes the footnote sentence.
    static func flows(title: String, axisLabel: String, data: ArchivalFlowsData,
                      indexedVolumeCount: Int) -> AnalyticsProvenance {
        var caveats = [
            String(format: String(
                localized: "archival.export.caveat.flows.footnotes %@",
                defaultValue: "Read this first: %@ of these references are footnotes. A row describes the editors' annotation practice — annotating material from one collection, they sent the reader to material from another — and not a relationship between the archives themselves."),
                data.footnoteShare.formatted(.percent.precision(.fractionLength(1)))),
            String(format: String(
                localized: "archival.export.caveat.flows.coverage %lld %lld",
                defaultValue: "Coverage: only %1$lld of the %2$lld volumes in the series contribute a single one of these references, because the cross-reference idiom they are harvested from postdates 1945. The figures carry no dates — the source aggregate stores a pair of archival units and a count — so they cannot be narrowed to a period."),
                Int64(data.volumesWithEdges), Int64(data.volumesScanned)),
            String(format: String(
                localized: "archival.export.caveat.flows.classes %lld %lld",
                defaultValue: "Excluded: central-file classes. Between them the whole series carries %1$lld references over %2$lld pairs — under two per pair — which is too thin to rank, and there are no labels to rank it with."),
                Int64(data.classBetweenReferences), Int64(data.classBetweenPairs)),
        ]
        if data.sameUnitReferences > 0 {
            caveats.append(String(format: String(
                localized: "archival.export.caveat.flows.sameUnit %lld",
                defaultValue: "Excluded: %lld references from this collection to itself. A hand-off to yourself is not a hand-off, but the figure is stated so the exclusion is visible."),
                Int64(data.sameUnitReferences)))
        }
        return AnalyticsProvenance(
            figureTitle: title,
            axisLabel: axisLabel,
            scopeLabel: data.focus?.name,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "archival.export.unit.references",
                                 defaultValue: "References"),
            extraCaveats: caveats)
    }

    // MARK: - Shared caveats

    /// Why the two Collections weights disagree — the single most misreadable thing on the surface.
    private static var weightCaveat: String {
        String(localized: "archival.export.caveat.weight",
               defaultValue: "Weights count different populations. Documents come from the usage index, which resolves a source note to a collection only when the citation names one. Volumes come from the collection authority, where a volume counts if its front matter or any document note names the collection — so a collection named only in front matter has volumes and no documents, and switching the weight changes the membership of the ranking as well as its order.")
    }

    /// The era asymmetry, which decides whether a reader should have switched lenses.
    private static var coverageCaveat: String {
        String(localized: "archival.export.caveat.coverage",
               defaultValue: "Coverage is uneven by era. Named collections are scarce before 1948, where central-file classes carry almost the whole record; classes all but disappear after 1976, where the presidential libraries carry it. A thin ranking in either direction is usually the wrong unit rather than a thin era.")
    }
}
