// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SeriesAnalyticsExport

/// The methods statements the four About-the-Series dashboards stamp on their exports (#790).
///
/// ## Why these are four builders and not one
/// The D3 program (#474–#479) never covered these dashboards, and cloning the corpus-analytics
/// provenance onto them would have produced two false sentences on every file:
///
/// 1. **The dating rule.** `AnalyticsProvenance`'s default describes a TEI `<date>` with a
///    volume-start-year fallback and By Month / By Day axes. Three of these four dashboards never
///    read a document's date at all — Production charts the *volume's* print and coverage years
///    from its TEI header, Geography counts *volumes* per region, Provenance buckets by the
///    *volume's* coverage decade — and the fourth, Administration, reads
///    `frus:doc-dateTime-min/-max` off each document with **no** fallback and has no month or day
///    axis. Each states its own rule through ``AnalyticsProvenance/datingRule``.
/// 2. **The corpus.** The default says counts "cover only the N volume(s) indexed on this
///    device". These four read bundled aggregates and render with **no index at all** — that is
///    the point of them, since they appear mid-onboarding. Saying otherwise would understate the
///    coverage of every figure. Each supplies a ``AnalyticsProvenance/corpusStatement`` instead.
///
/// Version history:
///   1.0 — Session 2026-08-09: #790
enum SeriesAnalyticsExport {

    /// Volumes in the shipped series — the denominator these dashboards actually cover.
    ///
    /// Passed as `indexedVolumeCount` so the figure caption's volume count is the corpus rather
    /// than the device, and countered by an explicit ``AnalyticsProvenance/corpusStatement`` so
    /// the wording cannot read as "indexed here".
    static func corpusStatement(volumeCount: Int) -> String {
        String(format: String(
            localized: "series.export.caveat.corpus %lld",
            defaultValue: "Corpus: these figures come from a data file that ships with the app and covers all %lld cataloged volumes of the series. They do not depend on which volumes you have indexed on this device. Every device shows the same numbers, and they are available before you download anything."),
            Int64(volumeCount))
    }

    /// A scope narrowing, when one is active — the sentence that keeps a subset from reading as
    /// the whole series.
    static func scopeCaveat(_ label: String?) -> String? {
        guard let label else { return nil }
        return String(format: String(
            localized: "series.export.caveat.scope %@",
            defaultValue: "Scoped to %@ — every figure below is recomputed from that subset's volumes alone and is not comparable with a whole-series export."),
            label)
    }

    // MARK: - Production & timeliness (SA-1b)

    /// Publication timeliness. Nothing here reads a document.
    static func production(figureTitle: String, axisLabel: String, scopeLabel: String?,
                           yearRange: ClosedRange<Int>, volumeCount: Int,
                           extra: [String] = []) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: volumeCount,
            yearRange: yearRange,
            // The dating flag is `false` and a rule is supplied: this dashboard places VOLUMES on
            // a timeline, never documents, so the corpus-analytics sentence would be false — but
            // the year range does filter the rows, and `datingRule` keeps that line printing.
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "series.export.unit.volumes", defaultValue: "Volumes"),
            datingRule: String(localized: "series.export.dating.production",
                               defaultValue: "Dating: no document date is read. A volume sits at its print year, taken from the publication-date in its TEI header. Its publication lag is that print year minus the last year of the coverage range in the same header. Neither figure is derived from the dates of the volume's own documents."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: [scopeCaveat(scopeLabel)].compactMap { $0 } + extra)
    }

    // MARK: - Geographic emphasis (SA-2)

    /// Regional emphasis, counted over volumes and their subject tags.
    static func geography(figureTitle: String, axisLabel: String, scopeLabel: String?,
                          yearRange: ClosedRange<Int>?, volumeCount: Int,
                          extra: [String] = []) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: volumeCount,
            yearRange: yearRange,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "series.export.unit.volumes", defaultValue: "Volumes"),
            datingRule: String(localized: "series.export.dating.geography",
                               defaultValue: "Dating: no document date is read. A volume is placed by the coverage range declared in its TEI header. Its regions come from the volume's own subject tags. So these figures count volumes concerned with a region, not documents about it."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: [scopeCaveat(scopeLabel)].compactMap { $0 } + extra)
    }

    // MARK: - Archival sourcing over time (SA-3b)

    /// Where the editors drew documents from, by coverage decade.
    ///
    /// - Parameter hiddenCategories: Categories the reader filtered out. Their absence **re-bases
    ///   every share**, so an export that did not say so would present a re-based share as a
    ///   share of the whole.
    /// - Parameter generated: The bundled artifact's generation date. Named on the figure because
    ///   every number here comes from one aggregate: two plates drawn from different generations
    ///   are different figures, and without this they carry identical captions. Empty is tolerated
    ///   and simply omits the line — an absent stamp is better than a fabricated one.
    static func provenance(figureTitle: String, axisLabel: String, scopeLabel: String?,
                           yearRange: ClosedRange<Int>?, volumeCount: Int, noteCount: Int,
                           hiddenCategories: [String], generated: String = "",
                           extra: [String] = []) -> AnalyticsProvenance {
        var caveats = [scopeCaveat(scopeLabel)].compactMap { $0 }
        if !generated.isEmpty {
            caveats.append(String(format: String(
                localized: "series.export.caveat.artifact %@",
                defaultValue: "Artifact: drawn from the bundled source-provenance aggregate generated %@. Every figure on this surface reads that one file; a plate from a different generation is a different figure."),
                generated))
        }
        if !hiddenCategories.isEmpty {
            caveats.append(String(format: String(
                localized: "series.export.caveat.hiddenCategories %@",
                defaultValue: "Re-based: %@ are hidden, and every share in this table is a share of the categories shown rather than of all source notes. A decade with nothing in any shown category is zero here, not absent."),
                hiddenCategories.sorted().formatted(.list(type: .and))))
        }
        caveats.append(String(format: String(
            localized: "series.export.caveat.provenanceNotes %lld",
            defaultValue: "Unit: %lld parsed source notes. A source note is the citation naming where a document's archival original was found. \"Other / Unclassified\" means a citation the parser could not classify, not a missing note."),
            Int64(noteCount)))
        return AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: volumeCount,
            yearRange: yearRange,
            appliesDocumentDating: false,
            valueMode: nil,
            countingUnit: String(localized: "series.export.unit.notes",
                                 defaultValue: "Source notes"),
            datingRule: String(localized: "series.export.dating.provenance",
                               defaultValue: "Dating: no document date is read. Each source note sits in the coverage decade of the volume that printed it, taken from that volume's declared date range. The trend starts around 1900. Earlier volumes are published correspondence and carry no archival source notes."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: caveats + extra)
    }

    // MARK: - Administration profiles (SA-2b)

    /// What the year control actually does: it filters which presidents appear, and never
    /// re-counts a document.
    ///
    /// Named rather than inlined so the test that requires it can match the sentence the builder
    /// really appends. A test quoting a fragment of it instead passes for the wrong reason the
    /// first time the wording changes.
    static var adminYearsCaveat: String {
        String(localized: "series.export.caveat.adminYears",
               defaultValue: "Year range: this selects which administrations appear, by whether the president's term overlaps the range. It does not re-count documents. An administration shown here carries its full count even when only part of its term falls inside the range.")
    }

    /// What any-overlap attribution costs: the per-administration counts are not exclusive, so
    /// they sum past the corpus.
    static var adminOverlapCaveat: String {
        String(localized: "series.export.caveat.adminOverlap",
               defaultValue: "Attribution: a document counts toward every administration its date range overlaps. The counts therefore overlap each other and add up to more than the whole series. A term ends on the day the next president takes office. A document dated on a succession day therefore belongs to the incoming president. These counts measure whose foreign policy the documents cover, not when the volumes were published.")
    }

    /// Coverage by presidential administration — the one dashboard that *does* read document
    /// dates, and the one whose year control does not mean what it looks like.
    ///
    /// - Parameter includesEditorialNotes: Whether range-dated documents are counted. Both
    ///   charts respond to it since #791 — the documents chart in its counts, the
    ///   volumes-per-year chart in which volumes are held to cover an administration — so one
    ///   sentence is true of both. Until #791 it was not, and this builder carried a second
    ///   parameter to say so.
    static func administration(figureTitle: String, axisLabel: String, scopeLabel: String?,
                               yearRange: ClosedRange<Int>, volumeCount: Int,
                               includesEditorialNotes: Bool,
                               extra: [String] = []) -> AnalyticsProvenance {
        var caveats = [scopeCaveat(scopeLabel)].compactMap { $0 }
        caveats.append(adminYearsCaveat)
        caveats.append(adminOverlapCaveat)
        caveats.append(String(format: String(
            localized: "series.export.caveat.adminNotes.v2 %@",
            defaultValue: "Editorial notes: %@. Editorial-note documents carry a span of dates rather than a single date; excluding them also withholds a volume whose only tie to an administration is such a note."),
            includesEditorialNotes
                ? String(localized: "series.export.included", defaultValue: "included")
                : String(localized: "series.export.excluded", defaultValue: "excluded")))
        return AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: volumeCount,
            yearRange: yearRange,
            // Substantively true — every cell was produced by reading a document's own date — but
            // the default sentence is still wrong for this surface, so a rule is supplied too.
            appliesDocumentDating: true,
            valueMode: nil,
            countingUnit: String(localized: "series.export.unit.documents",
                                 defaultValue: "Documents"),
            datingRule: String(localized: "series.export.dating.administration",
                               defaultValue: "Dating: each document is placed by its own editorial date bounds, the frus:doc-dateTime-min and -max attributes on the document element. A TEI <date> is not used, and there is no fallback to the volume's start year. An undated document is attributed to no administration and drops out."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: caveats + extra)
    }
}
