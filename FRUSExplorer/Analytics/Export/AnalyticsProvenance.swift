// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsProvenance

/// The methods statement that travels with an exported analytics figure or data table (D3).
///
/// An exported chart is a citable artifact: once it leaves the app it must still say what it
/// counted, over which corpus, with which value mode — and it must carry the caveats the app shows
/// on screen, because those are exactly what a reader would otherwise have to take on trust.
///
/// Two renderings are produced from one value:
///  - `captionLines` — two short lines baked onto the figure, so an image that travels without its
///    data file is still self-identifying;
///  - `csvPreambleLines` — the complete block, emitted as `#`-prefixed comment lines above the CSV
///    header (owner decision: preamble, not a sidecar, so the numbers and their method cannot be
///    separated in the wild).
///
/// ## Honest caveats
/// The on-screen captions are emitted **conditionally** (the normalization caveat only in `%` mode,
/// the categorical year-range note only on the breakdown axes, and so on). Here every caveat is
/// emitted **unconditionally**, with explicit "whole corpus" / "not applied" phrasing supplied when
/// a condition does not hold — an absent line in a methods block reads as "not applicable" when it
/// often means "still true, just not shown".
///
/// ## Dating
/// `datingCaveat` states the rule the code actually implements, including the volume-start-year
/// fallback for undated documents (see `CorpusAnalyticsService.termFrequencyByYear` and
/// `documentTotalsByYear`, which apply that fallback to numerator and denominator alike). The
/// in-app `analytics.info.dating.body` copy is worded to match, so the app and its exports disclose
/// the same method.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
struct AnalyticsProvenance: Sendable, Equatable {

    /// The figure's own title, e.g. `"sovereignty", "independence" — by Year`.
    var figureTitle: String
    /// The searched term(s), in chip order. Empty for charts that are not term-driven
    /// (the Person and Cross-Reference rankings).
    var terms: [String] = []
    /// The active grouping, e.g. `By Year`.
    var axisLabel: String
    /// The active volume scope's display label, or `nil` for the whole indexed corpus.
    var scopeLabel: String?
    /// How many volumes are indexed on this device — the corpus the numbers actually cover.
    var indexedVolumeCount: Int
    /// The applied year range, or `nil` when the chart ignores it (the categorical breakdowns).
    var yearRange: ClosedRange<Int>?
    /// Whether this artifact places documents on a timeline at all.
    ///
    /// `true` for every chart in the three analytics dashboards, which is why the dating rule and the
    /// year-range line are otherwise emitted unconditionally. A **word cloud** sets this `false`: it
    /// counts tokens across whatever documents its scope resolves to and never reads a date, so
    /// printing "each document is placed at its TEI `<date>`…" above its terms would be a methods
    /// statement about work the export did not do — worse than omitting one, because a reader has no
    /// way to tell a boilerplate caveat from a true one.
    var appliesDocumentDating: Bool = true
    /// The value mode, e.g. `Raw count` / `% of documents`; `nil` where normalization never applies.
    var valueMode: String?
    /// What the figure counts, e.g. `Documents` / `Occurrences (stems)`.
    ///
    /// Emitted **unconditionally** where supplied, unlike ``valueMode``, which is `nil` on the four
    /// axes normalisation never reaches. The unit is a fact about every figure: a reader of an
    /// occurrence chart who is told only "Raw count" has been told the one thing they could have
    /// guessed and not the one they could not.
    var countingUnit: String?
    /// A surface's own dating rule, replacing ``datingCaveat`` when set.
    ///
    /// The default sentence describes the corpus-analytics rule specifically — a TEI `<date>`
    /// with a volume-start-year fallback, and By Month / By Day charts. None of that is true of
    /// the About-the-Series dashboards (#790): three of the four never read a document date at
    /// all, and the fourth reads `frus:doc-dateTime-min/-max` with no fallback and has no
    /// month/day axes. Emitting the default there would state a method the export did not use,
    /// which is the exact failure the D3 preamble exists to prevent.
    var datingRule: String?
    /// A surface's own corpus statement, replacing ``corpusCaveat`` when set.
    ///
    /// The default says counts "cover only the N volume(s) indexed on this device". For a surface
    /// reading a bundled corpus-wide aggregate that is not a caveat, it is an untruth: those
    /// figures cover the whole series and render with no index at all.
    var corpusStatement: String?
    /// View-specific caveats appended verbatim (e.g. the cross-reference excluded-references note).
    var extraCaveats: [String] = []

    /// What this figure's numbers were drawn from (PV-1).
    ///
    /// Defaults to the volumes alone, which is true of most analytics — the counts come from the
    /// corpus index. A surface joining anything else must say so: the archival family adds nothing
    /// (it reads authority clusters by identity, all FRUS-derived — see
    /// `BundledArtifactProvenance`), while a subject or person breakdown does.
    var sources: Set<ProvenanceSource> = [.frusText]
    /// The caveats an exported *figure* prints on the image, when the full set is too much for a
    /// plate.
    ///
    /// **`nil` means print them all, and that default is the safe direction.** A figure published
    /// as a standalone PNG carries only what is baked into it: an omitted caveat is a research
    /// defect, while a tall text band is merely ugly. So a builder that says nothing gets complete
    /// disclosure, and trimming is a deliberate act by someone who has looked at the figure.
    ///
    /// A supplied list can only ever SELECT from what the CSV states, and cannot drop
    /// `corpusCaveat`. Both are enforced by `plateCaveatLines` rather than by a test, so a plate
    /// cannot assert a qualification the accompanying method block never made, and cannot drop the
    /// one caveat every figure here needs.
    var plateCaveats: [String]? = nil
    /// When the export was produced.
    var exportDate: Date = Date()

    // MARK: - Fixed text

    /// The app's marketing version, or `"—"` when unavailable.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    /// `FRUS Explorer 1.2` — the wordmark + version used on the figure and in the preamble.
    static var appCredit: String {
        String(format: String(localized: "analytics.export.credit %@",
                              defaultValue: "FRUS Explorer %@"), appVersion)
    }

    /// The publisher credit an exported figure carries on the image.
    ///
    /// **The plate must credit the Office of the Historian, not this app.** Until this existed
    /// every exported figure printed `FRUS Explorer <version>` and nothing else, so a plate
    /// published in an article credited a reading application for the U.S. government's documentary
    /// edition. `corpusAttribution` says the same thing at CSV length; this is the one-line form a
    /// caption can carry.
    static var plateAttribution: String {
        String(localized: "analytics.export.plateAttribution",
               defaultValue: "Foreign Relations of the United States, published by the Office of the Historian, U.S. Department of State. Public domain.")
    }

    /// Where the numbers are — phrased to stay true of a plate published on its own.
    ///
    /// It used to read "Full method, caveats, and the underlying numbers **accompany this figure**
    /// in its CSV export", printed unconditionally by the canvas. Publish the PNG alone and that
    /// sentence does not merely omit the caveats — it asserts they travelled with the image. This
    /// states where the data can be got, which is true however the figure is published.
    static var plateDataPointer: String {
        String(localized: "analytics.export.figure.seeData",
               defaultValue: "The underlying numbers are available as a CSV export from FRUS Explorer, with the full method statement.")
    }

    /// The corpus attribution, matching the app's own About/Settings wording.
    static var corpusAttribution: String {
        String(localized: "analytics.export.attribution",
               defaultValue: "Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State (history.state.gov). The corpus is in the public domain.")
    }

    // MARK: - Derived text

    /// The scope line — the named scope, else the whole indexed corpus.
    var scopeDescription: String {
        if let scopeLabel, !scopeLabel.isEmpty { return scopeLabel }
        return String(localized: "analytics.export.scope.wholeCorpus", defaultValue: "Whole corpus")
    }

    /// The year-range line, phrased explicitly when the axis ignores the range.
    var yearRangeDescription: String {
        guard let yearRange else {
            return String(localized: "analytics.export.range.notApplied",
                          defaultValue: "Not applied — this breakdown covers the whole corpus span")
        }
        return String(format: String(localized: "analytics.export.range %lld %lld",
                                     defaultValue: "%lld–%lld"),
                      Int64(yearRange.lowerBound), Int64(yearRange.upperBound))
    }

    /// The dating rule as implemented — the surface's own where it supplied one, else the
    /// corpus-analytics rule with its volume-start-year fallback and month/day exclusion.
    var datingCaveat: String {
        if let datingRule { return datingRule }
        return String(localized: "analytics.export.caveat.dating",
               defaultValue: "Dating: each document sits at its TEI <date>, the date it was written. A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. A document with no month is left out of the By Month chart. One with no day is left out of By Day.")
    }

    /// What corpus the figure covers — the surface's own statement where it supplied one, else
    /// the indexed-on-this-device caveat.
    var corpusCaveat: String {
        if let corpusStatement { return corpusStatement }
        return String(format: String(localized: "analytics.export.caveat.corpus %lld",
                              defaultValue: "Corpus: counts cover only the %lld volume(s) indexed on this device, not the entire FRUS series."),
               Int64(indexedVolumeCount))
    }

    /// The value-mode caveat, spelled out for both modes rather than only for shares.
    var valueModeCaveat: String? {
        guard let valueMode else { return nil }
        return String(format: String(localized: "analytics.export.caveat.values %@",
                                     defaultValue: "Values: %@. A share is that period’s matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term."),
                      valueMode)
    }

    /// The export timestamp, formatted for a reader (not for machines).
    var formattedDate: String {
        exportDate.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Renderings

    /// The two lines baked onto an exported figure: the title, then the identifying facts.
    ///
    /// Deliberately short — a journal retypesets captions, and a six-line block would consume the
    /// canvas. The complete method block lives in the accompanying CSV.
    var captionLines: [String] {
        var facts: [String] = [scopeDescription]
        if yearRange != nil { facts.append(yearRangeDescription) }
        if let valueMode { facts.append(valueMode) }
        facts.append(Self.appCredit)
        facts.append(formattedDate)
        return [figureTitle, facts.joined(separator: " · ")]
    }

    /// Every caveat the CSV method block states, in the order it states them.
    ///
    /// One definition, two consumers: `csvPreambleLines` prints these below its header fields and
    /// `plateCaveatLines` prints them (or a designated subset) on the image, so a plate cannot
    /// disclose something its CSV does not.
    var allCaveats: [String] {
        var lines: [String] = []
        if appliesDocumentDating || datingRule != nil { lines.append(datingCaveat) }
        lines.append(corpusCaveat)
        if let valueModeCaveat { lines.append(valueModeCaveat) }
        lines.append(contentsOf: extraCaveats)
        // PV-1: what the figure was drawn from, last, because it qualifies everything above it.
        // Joining `allCaveats` rather than the CSV preamble alone is deliberate — that is what
        // carries it onto the plate too, through the same designation filter, so a figure and its
        // CSV cannot disagree about their sources.
        lines.append(contentsOf: ProvenanceStatement.lines(for: sources))
        return lines
    }

    /// The caveats printed on an exported figure — all of them unless a builder designated fewer.
    ///
    /// A designation FILTERS `allCaveats`; it is never returned as given. Two consequences, both
    /// deliberate and both structural rather than merely documented:
    ///
    /// - **A plate can only print what its CSV prints.** A designated string the method block does
    ///   not contain is dropped, not rendered, so no trim can invent a qualification.
    /// - **`corpusCaveat` survives every trim.** It is the sentence saying which volumes the counts
    ///   cover, and a figure without it is a figure whose denominator is unstated. A designation
    ///   that omits it gets it back, first.
    ///
    /// Order always follows `allCaveats`, not the designation, so two figures trimmed differently
    /// still read in the same sequence.
    /// **The sources block survives a trim too (PV-1), for the same reason `corpusCaveat` does.**
    /// A designation trims *caveats* — qualifications a reader can weigh — where the sources
    /// sentence is the attribution, and a plate is the artifact most likely to be shared on its
    /// own, detached from the CSV that would otherwise carry it. A figure whose sources are
    /// unstated is the exact thing this wave exists to prevent, so a designation cannot drop them.
    var plateCaveatLines: [String] {
        guard let plateCaveats else { return allCaveats }
        let designated = Set(plateCaveats)
        let sourceLines = ProvenanceStatement.lines(for: sources)
        let kept = allCaveats.filter { designated.contains($0) || sourceLines.contains($0) }
        return kept.contains(corpusCaveat) ? kept : [corpusCaveat] + kept
    }

    /// Everything an exported plate prints beneath its chart, in order, each tagged with the role
    /// that decides how it is set.
    ///
    /// The canvas is a `ForEach` over this array and nothing else, so a test that drives this
    /// property is testing what the image actually says rather than a parallel copy of the rule.
    var plateLines: [AnalyticsPlateLine] {
        var lines = captionLines.enumerated().map { index, text in
            AnalyticsPlateLine(role: index == 0 ? .title : .facts, text: text)
        }
        lines += plateCaveatLines.map { AnalyticsPlateLine(role: .caveat, text: $0) }
        lines.append(AnalyticsPlateLine(role: .attribution, text: Self.plateAttribution))
        lines.append(AnalyticsPlateLine(role: .dataPointer, text: Self.plateDataPointer))
        return lines
    }

    /// The complete method block as `#`-prefixed CSV comment lines (header included), ready to be
    /// prepended to a table's CSV.
    var csvPreambleLines: [String] {
        var lines: [String] = []
        lines.append(String(localized: "analytics.export.preamble.header",
                            defaultValue: "FRUS Explorer — analytics export"))
        lines.append("")
        lines.append("\(String(localized: "analytics.export.field.figure", defaultValue: "Figure")): \(figureTitle)")
        if !terms.isEmpty {
            lines.append("\(String(localized: "analytics.export.field.terms", defaultValue: "Term(s)")): \(terms.joined(separator: ", "))")
        }
        lines.append("\(String(localized: "analytics.export.field.groupedBy", defaultValue: "Grouped by")): \(axisLabel)")
        lines.append("\(String(localized: "analytics.export.field.scope", defaultValue: "Scope")): \(scopeDescription)")
        // The year-range line used to be gated on `appliesDocumentDating`, which conflated two
        // independent facts. A surface can filter by year without placing documents on a timeline
        // — three of the four About-the-Series dashboards do exactly that — and suppressing the
        // line there would drop the one field a reader most needs. Strictly additive: a surface
        // with no range and no dating still prints nothing.
        if appliesDocumentDating || yearRange != nil {
            lines.append("\(String(localized: "analytics.export.field.yearRange", defaultValue: "Year range")): \(yearRangeDescription)")
        }
        if let countingUnit {
            lines.append("\(String(localized: "analytics.export.field.counting", defaultValue: "Counting")): \(countingUnit)")
        }
        if let valueMode {
            lines.append("\(String(localized: "analytics.export.field.values", defaultValue: "Values")): \(valueMode)")
        }
        lines.append("\(String(localized: "analytics.export.field.exported", defaultValue: "Exported")): \(Self.appCredit), \(formattedDate)")
        lines.append("")
        lines.append(String(localized: "analytics.export.preamble.method", defaultValue: "Method and caveats"))
        lines.append(contentsOf: allCaveats)
        lines.append("")
        lines.append(Self.corpusAttribution)
        return lines.map { $0.isEmpty ? "#" : "# \($0)" }
    }
}

// MARK: - AnalyticsPlateLine

/// One line printed on an exported figure, with the role that decides how it is set.
///
/// Version history:
///   1.0 — Visual-marketing GATE C: the plate's caption band gains caveats and an attribution
struct AnalyticsPlateLine: Sendable, Equatable {

    /// What a line is for, which is what decides its size and weight.
    enum Role: Sendable, Equatable {
        /// The figure title.
        case title
        /// The identifying facts — scope, range, credit, date.
        case facts
        /// A caveat that qualifies the numbers.
        case caveat
        /// The publisher credit.
        case attribution
        /// Where the underlying numbers can be got.
        case dataPointer
    }

    /// The role.
    let role: Role
    /// The text as printed.
    let text: String
}

// MARK: - ChartInspectorData + provenance

extension ChartInspectorData {

    /// The table's CSV preceded by `provenance` as `#` comment lines (D3).
    ///
    /// The data itself is unchanged — `csv` still produces the bare RFC-4180 table — so a reader
    /// who wants only the numbers can skip the `#` lines (most parsers accept `comment='#'`), while
    /// a file that travels alone still carries its own method statement.
    ///
    /// - Parameter provenance: The methods statement to stamp above the header row.
    /// - Returns: The provenance-stamped CSV text, newline-terminated.
    func provenancedCSV(_ provenance: AnalyticsProvenance) -> String {
        (provenance.csvPreambleLines + [csv]).joined(separator: "\n").appending("\n")
    }
}
