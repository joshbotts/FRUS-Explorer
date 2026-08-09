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
            defaultValue: "Corpus: these figures come from a bundled aggregate covering the %lld catalogued volumes of the series, not from the volumes indexed on this device. They are identical on every device and are available before anything is downloaded."),
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
                               defaultValue: "Dating: no document date is read. A volume is placed at its print year — the text of its TEI publication-date — and the publication lag is that year minus the last year of the coverage range declared in the same header. Neither is a maximum over the volume's documents."),
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
                               defaultValue: "Dating: no document date is read. A volume is placed by the coverage range declared in its TEI header, and its regions come from the volume's own subject tags — so a figure counts volumes concerned with a region, not documents about it."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: [scopeCaveat(scopeLabel)].compactMap { $0 } + extra)
    }

    // MARK: - Archival sourcing over time (SA-3b)

    /// Where the editors drew documents from, by coverage decade.
    ///
    /// - Parameter hiddenCategories: Categories the reader filtered out. Their absence **re-bases
    ///   every share**, so an export that did not say so would present a re-based share as a
    ///   share of the whole.
    static func provenance(figureTitle: String, axisLabel: String, scopeLabel: String?,
                           yearRange: ClosedRange<Int>?, volumeCount: Int, noteCount: Int,
                           hiddenCategories: [String], extra: [String] = []) -> AnalyticsProvenance {
        var caveats = [scopeCaveat(scopeLabel)].compactMap { $0 }
        if !hiddenCategories.isEmpty {
            caveats.append(String(format: String(
                localized: "series.export.caveat.hiddenCategories %@",
                defaultValue: "Re-based: %@ are hidden, and every share in this table is a share of the categories shown rather than of all source notes. A decade with nothing in any shown category is zero here, not absent."),
                hiddenCategories.sorted().formatted(.list(type: .and))))
        }
        caveats.append(String(format: String(
            localized: "series.export.caveat.provenanceNotes %lld",
            defaultValue: "Unit: %lld parsed source notes. A source note is the citation naming where a document's archival original was found; \"Other / Unclassified\" is a citation form the parser could not classify, not the absence of a note."),
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
                               defaultValue: "Dating: no document date is read. Each source note is placed in the coverage decade of the volume that printed it, taken from that volume's declared date range. The trend begins around 1900 because earlier volumes are published correspondence carrying no archival source notes."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: caveats + extra)
    }

    // MARK: - Administration profiles (SA-2b)

    /// Coverage by presidential administration — the one dashboard that *does* read document
    /// dates, and the one whose year control does not mean what it looks like.
    ///
    /// - Parameters:
    ///   - includesEditorialNotes: Whether range-dated documents are counted.
    ///   - affectedByEditorialNotes: Whether *this figure* responds to that setting. The
    ///     volumes-per-year chart does not, and the toggle's own subtitle says it affects "every
    ///     count and proportion" — so a figure that silently ignores it must say so rather than
    ///     inherit a claim from the control above it.
    static func administration(figureTitle: String, axisLabel: String, scopeLabel: String?,
                               yearRange: ClosedRange<Int>, volumeCount: Int,
                               includesEditorialNotes: Bool, affectedByEditorialNotes: Bool,
                               extra: [String] = []) -> AnalyticsProvenance {
        var caveats = [scopeCaveat(scopeLabel)].compactMap { $0 }
        // The year control filters which presidents appear by their term years; it does NOT
        // re-count documents. A preamble that printed the range without saying so would read as
        // "documents in these years", which is not what any number here is.
        caveats.append(String(localized: "series.export.caveat.adminYears",
                              defaultValue: "Year range: selects which administrations appear, by whether the president's term overlaps the range. It does not re-count documents — a listed administration carries its full count even when only part of its term falls inside."))
        caveats.append(String(localized: "series.export.caveat.adminOverlap",
                              defaultValue: "Attribution: a document is attributed to every administration its date range overlaps, so the counts are not mutually exclusive and sum past the corpus. Terms are half-open, so a document dated on a succession day belongs to the incoming president. Counts measure whose foreign policy the documents cover, not when the volumes were published."))
        caveats.append(affectedByEditorialNotes
            ? String(format: String(
                localized: "series.export.caveat.adminNotes %@",
                defaultValue: "Editorial notes: %@. Editorial-note documents carry a span of dates rather than a single date."),
                includesEditorialNotes
                    ? String(localized: "series.export.included", defaultValue: "included")
                    : String(localized: "series.export.excluded", defaultValue: "excluded"))
            : String(localized: "series.export.caveat.adminNotesIgnored",
                     defaultValue: "Editorial notes: this figure is unaffected by the editorial-notes setting. A volume counts toward an administration if any of its documents fall there, range-dated ones included, whatever the toggle says."))
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
                               defaultValue: "Dating: each document is placed by its own editorial date bounds (frus:doc-dateTime-min / -max on the document element), not by a TEI <date> and with no volume-start-year fallback — an undated document is attributed to no administration and simply drops out."),
            corpusStatement: corpusStatement(volumeCount: volumeCount),
            extraCaveats: caveats + extra)
    }
}
