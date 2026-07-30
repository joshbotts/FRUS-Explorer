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
    /// View-specific caveats appended verbatim (e.g. the cross-reference excluded-references note).
    var extraCaveats: [String] = []
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

    /// The dating rule as implemented, including the volume-start-year fallback for undated
    /// documents and the month/day precision exclusion.
    var datingCaveat: String {
        String(localized: "analytics.export.caveat.dating",
               defaultValue: "Dating: each document is placed at its TEI <date> (the date of authorship). A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. Documents lacking month or day precision are excluded from the By Month and By Day charts.")
    }

    /// The selective-corpus caveat — always true, not only in `%` mode.
    var corpusCaveat: String {
        String(format: String(localized: "analytics.export.caveat.corpus %lld",
                              defaultValue: "Corpus: counts cover only the %lld volume(s) indexed on this device, not the entire FRUS series."),
               Int64(indexedVolumeCount))
    }

    /// The value-mode caveat, spelled out for both modes rather than only for shares.
    var valueModeCaveat: String? {
        guard let valueMode else { return nil }
        return String(format: String(localized: "analytics.export.caveat.values %@",
                                     defaultValue: "Values: %@. A share is that period's matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term."),
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
        if appliesDocumentDating {
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
        if appliesDocumentDating { lines.append(datingCaveat) }
        lines.append(corpusCaveat)
        if let valueModeCaveat { lines.append(valueModeCaveat) }
        for caveat in extraCaveats { lines.append(caveat) }
        lines.append("")
        lines.append(Self.corpusAttribution)
        return lines.map { $0.isEmpty ? "#" : "# \($0)" }
    }
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
