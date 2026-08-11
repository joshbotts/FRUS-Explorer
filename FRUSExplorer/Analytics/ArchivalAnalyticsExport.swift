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
///   1.1 — Session 2026-08-10: #832 — `lifecycles` retired with its card, `collectionTimeline`
///          added for the collection record's Cited Over Time chart
///   1.2 — Session 2026-08-10: #826 — the ranking states its class grain and its denominator
enum ArchivalAnalyticsExport {

    /// The caveat every archival export carries: what the figures are parsed from, and what they
    /// are not.
    static var baseCaveat: String {
        String(localized: "archival.export.caveat.base",
               defaultValue: "Method: these figures come from the source note on each published FRUS document. That note is the citation naming where the editors found the archival original. So they record where the editors drew documents from, not what the archives themselves hold. Collections are grouped across volumes by name. When two spellings of one name fail to merge, a single body of records appears twice under nearby names.")
    }

    /// What the class lens's one grain is, and what it costs.
    ///
    /// The corpus cites two filing systems through one grammar, and until #826 the ranking mixed
    /// them: a decimal row was a whole class, a subject-numeric row one country's slice of one.
    /// Folding to category+number is owner decision **D-3**'s grain and the one the co-citation
    /// network already used — but it hides the designator a reader writes on a pull slip, so the
    /// export says the fold happened and the app offers the leaves.
    static var grainCaveat: String {
        String(localized: "archival.export.caveat.grain",
               defaultValue: "Grain: central-file rows are one unit deep. A decimal file number (763.72) stands for itself; subject-numeric designators are grouped to their category and number (POL 27 VIET S and POL 27 ARAB-ISR both count under POL 27), because at full length half of them carry a single document. A grouped row's own leaves, with their counts, are listed under the chart in the app. A volume citing two designators in one group counts once for the group.")
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
                        indexedVolumeCount: Int, noteCount: Int = 0,
                        shownValue: Int = 0) -> AnalyticsProvenance {
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
        if lens == .centralFileClasses {
            caveats.append(grainCaveat)
        }
        // Only under the documents weight: a "rows account for N of M" sentence over a volume
        // count and a note total is the units error `ArchivalRanking.shownShare(weight:)`
        // refuses on screen, and a CSV outlives the screen that produced it.
        if noteCount > 0, weight == .documents {
            caveats.append(String(format: String(
                localized: "archival.export.caveat.denominator %lld %lld",
                defaultValue: "Denominator: the era's volumes carry %1$lld source notes in all, and the rows in this table account for %2$lld of them. The rest name a unit of the other kind, a unit below the row cap, or nothing this app resolves."),
                Int64(noteCount), Int64(shownValue)))
        }
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

    /// One collection's Cited Over Time statement (#832b).
    ///
    /// This is the surface that inherited the removed corpus-wide lifecycle card's question — when
    /// did a body of records enter the published series, and how long did the editors keep
    /// returning to it — and it answers it per collection, which is the grain the question actually
    /// has. Two things therefore have to be said that the lifecycle caveat never had to say: the
    /// buckets are **FRUS's own subseries**, not decades (a decade axis splits the 66-volume
    /// `1969-76` subseries in half), and a bar counts **volumes**, not documents, so a volume that
    /// cites the collection once and a volume built on it stand equally tall.
    ///
    /// - Parameters:
    ///   - collectionName: The collection whose record this chart sits on.
    ///   - eraCount: Buckets drawn — the chart is contiguous, so this is also its width in eras.
    ///   - indexedVolumeCount: Volumes indexed on this device.
    static func collectionTimeline(collectionName: String, eraCount: Int,
                                   indexedVolumeCount: Int) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: String(format: String(
                localized: "archival.export.title.timeline %@",
                defaultValue: "%@ — cited over time"), collectionName),
            axisLabel: String(localized: "archival.export.axis.timeline",
                              defaultValue: "Citing volumes by coverage era"),
            scopeLabel: collectionName,
            indexedVolumeCount: indexedVolumeCount,
            yearRange: nil,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "archival.weight.volumes", defaultValue: "Volumes"),
            extraCaveats: [
                baseCaveat,
                String(format: String(
                    localized: "archival.export.caveat.timeline %lld",
                    defaultValue: "Scope: the whole published series, not this device's library. Each bar counts the volumes in one coverage era whose front matter or document source notes name this collection — volumes, not documents, so a volume citing it once counts the same as a volume built on it. The %lld eras run contiguously from the first era that cites it to the last, so an interior gap is a real gap. The buckets are FRUS's own subseries rather than decades, because a decade axis splits a published subseries across two bars."),
                    Int64(eraCount)),
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
        // #784: the two layers are different bodies of evidence and owe different disclosures.
        // An export that carried the printed layer's caveats over unprinted-material rows would
        // state a footnote share of 0.0% and a class exclusion that never applied — a methods
        // statement describing a measurement the table is not.
        var caveats: [String]
        if let facts = data.externalFacts {
            caveats = [
                String(format: String(
                    localized: "archival.export.caveat.flows.unprinted.claim %lld %lld",
                    defaultValue: "Read this first: every row is an editorial footnote naming archival material FRUS did not print. A row says the editors, working on material from one collection, told the reader that something unprinted is in another. It is not a relationship between the archives and not a count of documents held anywhere. %1$lld citations were found; %2$lld matched a known collection."),
                    Int64(facts.referencesFound), Int64(facts.referencesJoined)),
                String(format: String(
                    localized: "archival.export.caveat.flows.unprinted.scope %lld %lld",
                    defaultValue: "Scope: State Department lot files and presidential-library collections only. Both are post-1945 ways of filing, so pre-war volumes are nearly absent even though their footnotes cite archives heavily — those citations give a central-file number, which this measure does not yet read. %1$lld of the %2$lld volumes in the series contribute a row."),
                    Int64(data.volumesWithEdges), Int64(data.volumesScanned)),
                String(format: String(
                    localized: "archival.export.caveat.flows.unprinted.ibid %@",
                    defaultValue: "Method: %@ of these citations come from an “Ibid.” — the archive is named once and referred back to. The app follows that back the way a reader would; it is a reading, not a quotation."),
                    facts.inheritedShare.formatted(.percent.precision(.fractionLength(1)))),
            ]
            if let span = facts.eraSpan {
                caveats.append(String(format: String(
                    localized: "archival.export.caveat.flows.unprinted.era %lld %lld",
                    defaultValue: "Coverage span: the contributing volumes cover %1$lld to %2$lld."),
                    Int64(span.lowerBound), Int64(span.upperBound)))
            }
        } else {
            caveats = [
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
        }
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
