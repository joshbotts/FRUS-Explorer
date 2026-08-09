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
               defaultValue: "Method: these figures come from the source note on each published FRUS document. That note is the citation naming where the editors found the archival original. So they record where the editors drew documents from, not what the archives themselves hold. Collections are grouped across volumes by name. When two spellings of one name fail to merge, a single body of records appears twice under nearby names.")
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
                defaultValue: "Withheld: this ranking leaves out the Central Files umbrella record. On its own it accounts for %1$lld %2$@ in this era, and its bar would flatten the scale. The era-specific Central Files records are still included."),
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
                    defaultValue: "Scope: the %lld most widely cited collections in the series, ranked by how many volumes cite them. Each span runs from the earliest to the latest coverage year of those volumes. It says nothing about how densely the years in between are covered."),
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
                    defaultValue: "Scope: counted from what you have indexed on this device. That is %1$lld source notes across the %2$lld indexed volumes that carry them, out of %3$lld volumes in the series. These figures change as you index more volumes. Do not compare them with the figures for the whole series."),
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
                       defaultValue: "What a link means: two collections are linked because the same volumes drew on both. Each document carries exactly one source note, so no document can cite two collections. The shared-documents measure counts how much material the two collections supplied together to the volumes they share. It does not count documents citing both."),
                String(format: String(
                    localized: "archival.export.caveat.network.scope %lld %lld %lld",
                    defaultValue: "Scope: this table lists %1$lld of the %2$lld units above the current threshold. In all, %3$lld collections share two or more volumes with the focus. The graph draws at most six per custodian so each quadrant stays readable. This table lists exactly what the graph drew."),
                    Int64(drawn), Int64(aboveThreshold), Int64(partnersTotal)),
            ])
    }

    /// The Flows mode's statement — the one that owes the footnote sentence.
    static func flows(title: String, axisLabel: String, data: ArchivalFlowsData,
                      indexedVolumeCount: Int) -> AnalyticsProvenance {
        var caveats = [
            String(format: String(
                localized: "archival.export.caveat.flows.footnotes %@",
                defaultValue: "Read this first: %@ of these references are footnotes. A row describes how the editors annotated. While annotating material from one collection, they pointed the reader to material from another. It is not a relationship between the archives themselves."),
                data.footnoteShare.formatted(.percent.precision(.fractionLength(1)))),
            String(format: String(
                localized: "archival.export.caveat.flows.coverage %lld %lld",
                defaultValue: "Coverage: only %1$lld of the %2$lld volumes in the series contribute any of these references. The cross-reference style they come from postdates 1945. The figures carry no dates: the stored data is a pair of archival units and a count. You cannot narrow this view to a period."),
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
    ///
    /// Internal rather than private so the test requiring it can match the sentence the builder
    /// really appends. A test quoting a fragment instead keeps passing once the wording changes,
    /// which is a guard that has quietly stopped guarding.
    static var weightCaveat: String {
        String(localized: "archival.export.caveat.weight",
               defaultValue: "The two weights count different things. A document counts only when its own source note names the collection. A volume counts when either its front matter or any document source note names the collection. So a collection named only in front matter has volumes but no documents. Switching the weight changes which collections appear in the ranking, not just their order.")
    }

    /// The era asymmetry, which decides whether a reader should have switched lenses.
    private static var coverageCaveat: String {
        String(localized: "archival.export.caveat.coverage",
               defaultValue: "Coverage is uneven by era. Named collections are scarce before 1948, where central-file classes carry almost the whole record. Classes all but disappear after 1976, where the presidential libraries carry it. A thin ranking usually means you have the wrong unit selected, not a thin era.")
    }
}
