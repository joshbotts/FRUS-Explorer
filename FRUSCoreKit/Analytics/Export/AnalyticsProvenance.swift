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
/// in-app `analytics.info.dating.body` copy was worded to match, so the app and its exports disclosed
/// the same method. **They match again since #1306**, which re-keyed this caveat to
/// `analytics.export.caveat.dating.v2` and the in-app row to `analytics.info.dating.body.v3`. Both
/// state the same rule: the editor-annotated date, a range plotted at its first day, and content with
/// no stored date at all kept by By Year and By Decade at its volume’s start year and dropped by By
/// Month and By Day. Since the owner’s 2026-09-30 wording the popover is the shorter of the two: only
/// this caveat adds that nothing is lost for want of a month or a day and that the fallback reaches
/// the % denominator, because it travels to a reader who cannot check it against the chart.
///
/// The export tests read `"editor-annotated date"` as the default rule’s marker. They read `"as the
/// editors date it"` until the 2026-09-30 rewording, and before #1306 `"TEI <date>"`, which is the
/// phrase this caveat had kept after #1299 removed it from the in-app row — so that marker was a
/// drift artefact standing in for a rule.
///
/// ## The host
/// What this read from the app is passed in (``Host``): the version the credit line prints, which it read
/// from `Bundle.main`, and the locale, calendar and time zone it wrote the export date and the volume count
/// in, which were the reader's. Every rendering that reads one takes the host (`captionLines(for:)`,
/// `csvPreambleLines(for:)`, `plateLines(for:)` and the rest); the app's own names, which pass its host,
/// are in `AnalyticsProvenance+App.swift`, as `QueryMethodAppendix`'s are. A host that fixes the locale,
/// calendar and time zone writes the same method block on any platform.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
///   1.1 — #1299 (docs only): says the in-app dating row and `datingCaveat` no longer match word for word
///   1.2 — #1306: `datingCaveat` re-keyed to `analytics.export.caveat.dating.v2`. Its first move: it had
///         kept "TEI <date>" a release after the in-app row dropped it, and carried the no-month/no-day
///         exclusion that measurement refuted. The two surfaces state the same rule again.
///   1.3 — owner's 2026-09-30 wording: the caveat opens "each document sits at the editor-annotated
///         date", and the tests' marker for the default rule follows it
///   1.4 — PV-1 (the 2026-09-28 audit): documentation only — `sources` says what each builder now passes
///   1.5 — 2026-11-11 (FRUS Explorer Light, S24a): moved into FRUSCoreKit, public, with its memberwise
///          initialiser spelt out; the renderings that read the bundle's version or the reader's locale
///          take a ``Host`` instead, and the app's names forward to them with its own
public struct AnalyticsProvenance: Sendable, Equatable {

    /// The figure's own title, e.g. `"sovereignty", "independence" — by Year`.
    public var figureTitle: String
    /// The searched term(s), in chip order. Empty for charts that are not term-driven
    /// (the Person and Cross-Reference rankings).
    public var terms: [String] = []
    /// The active grouping, e.g. `By Year`.
    public var axisLabel: String
    /// The active volume scope's display label, or `nil` for the whole indexed corpus.
    public var scopeLabel: String?
    /// How many volumes are indexed on this device — the corpus the numbers actually cover.
    public var indexedVolumeCount: Int
    /// The applied year range, or `nil` when the chart ignores it (the categorical breakdowns).
    public var yearRange: ClosedRange<Int>?
    /// Whether this artifact places documents on a timeline at all.
    ///
    /// `true` for every chart in the three analytics dashboards, which is why the dating rule and the
    /// year-range line are otherwise emitted unconditionally. A **word cloud** sets this `false`: it
    /// counts tokens across whatever documents its scope resolves to and never reads a date, so
    /// printing "each document is placed at its TEI `<date>`…" above its terms would be a methods
    /// statement about work the export did not do — worse than omitting one, because a reader has no
    /// way to tell a boilerplate caveat from a true one.
    public var appliesDocumentDating: Bool = true
    /// The value mode, e.g. `Raw count` / `% of documents`; `nil` where normalization never applies.
    public var valueMode: String?
    /// What the figure counts, e.g. `Documents` / `Occurrences (stems)`.
    ///
    /// Emitted **unconditionally** where supplied, unlike ``valueMode``, which is `nil` on the four
    /// axes normalisation never reaches. The unit is a fact about every figure: a reader of an
    /// occurrence chart who is told only "Raw count" has been told the one thing they could have
    /// guessed and not the one they could not.
    public var countingUnit: String?
    /// A surface's own dating rule, replacing ``datingCaveat`` when set.
    ///
    /// The default sentence describes the corpus-analytics rule specifically — a TEI `<date>`
    /// with a volume-start-year fallback, and By Month / By Day charts. None of that is true of
    /// the About-the-Series dashboards (#790): three of the four never read a document date at
    /// all, and the fourth reads `frus:doc-dateTime-min/-max` with no fallback and has no
    /// month/day axes. Emitting the default there would state a method the export did not use,
    /// which is the exact failure the D3 preamble exists to prevent.
    public var datingRule: String?
    /// A surface's own corpus statement, replacing ``corpusCaveat`` when set.
    ///
    /// The default says counts "cover only the N volume(s) indexed on this device". For a surface
    /// reading a bundled corpus-wide aggregate that is not a caveat, it is an untruth: those
    /// figures cover the whole series and render with no index at all.
    public var corpusStatement: String?
    /// View-specific caveats appended verbatim (e.g. the cross-reference excluded-references note).
    public var extraCaveats: [String] = []

    /// What this figure's numbers were drawn from (PV-1).
    ///
    /// Defaults to the volumes alone, which is true of most analytics — the counts come from the
    /// corpus index. A surface joining or computing anything else must say so, and until the
    /// 2026-09-28 audit none did. Now the word cloud adds this app's word lists, the semantic map its
    /// model, Person Analytics the OH people data, regional emphasis the OH subjects, and a class
    /// ranking the State Department's schedule where it reads it
    /// (`ArchivalAnalyticsExport.rankingSources`). The rest of the archival family adds nothing: it
    /// reads authority clusters by identity, all FRUS-derived (see `BundledArtifactProvenance`).
    /// `AnalyticsExportSourcesTests.everyBuilderStatesItsSources` reads every call that builds one.
    public var sources: Set<ProvenanceSource> = [.frusText]
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
    public var plateCaveats: [String]? = nil
    /// When the export was produced.
    public var exportDate: Date = Date()

    /// Creates a methods statement, as the memberwise initialiser did: every parameter in the order the
    /// properties are declared, each with the default its property has, an optional one `nil`.
    public init(figureTitle: String, terms: [String] = [], axisLabel: String, scopeLabel: String? = nil,
                indexedVolumeCount: Int, yearRange: ClosedRange<Int>? = nil,
                appliesDocumentDating: Bool = true, valueMode: String? = nil, countingUnit: String? = nil,
                datingRule: String? = nil, corpusStatement: String? = nil, extraCaveats: [String] = [],
                sources: Set<ProvenanceSource> = [.frusText], plateCaveats: [String]? = nil,
                exportDate: Date = Date()) {
        self.figureTitle = figureTitle
        self.terms = terms
        self.axisLabel = axisLabel
        self.scopeLabel = scopeLabel
        self.indexedVolumeCount = indexedVolumeCount
        self.yearRange = yearRange
        self.appliesDocumentDating = appliesDocumentDating
        self.valueMode = valueMode
        self.countingUnit = countingUnit
        self.datingRule = datingRule
        self.corpusStatement = corpusStatement
        self.extraCaveats = extraCaveats
        self.sources = sources
        self.plateCaveats = plateCaveats
        self.exportDate = exportDate
    }

    // MARK: - The host

    /// What a rendering reads from its host: the version the credit line names, and the locale, calendar
    /// and time zone the export date and the volume count are written in. The app's (`Host.app`) reads its
    /// bundle's short version string and the reader's own locale, calendar and time zone, which is what
    /// the renderings read themselves before they moved into the kit.
    public struct Host: Sendable {
        /// The version the credit line prints ("FRUS Explorer 1.0"), or `nil` to print `—` in its place.
        public var appVersion: String?
        /// The locale the export date and the volume count are written in.
        public var locale: Locale
        /// The calendar the export date is written in.
        public var calendar: Calendar
        /// The time zone the export date is written in.
        public var timeZone: TimeZone

        /// Creates a host.
        public init(appVersion: String?, locale: Locale = .autoupdatingCurrent,
                    calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) {
            self.appVersion = appVersion
            self.locale = locale
            self.calendar = calendar
            self.timeZone = timeZone
        }
    }

    // MARK: - Fixed text

    /// `FRUS Explorer 1.2` — the wordmark + version used on the figure and in the preamble: the host's
    /// version, or `"—"` when it has none.
    public static func appCredit(for host: Host) -> String {
        String(format: String(localized: "analytics.export.credit %@",
                              defaultValue: "FRUS Explorer %@"), host.appVersion ?? "—")
    }

    /// The publisher credit an exported figure carries on the image.
    ///
    /// **The plate must credit the Office of the Historian, not this app.** Until this existed
    /// every exported figure printed `FRUS Explorer <version>` and nothing else, so a plate
    /// published in an article credited a reading application for the U.S. government's documentary
    /// edition. `corpusAttribution` says the same thing at CSV length; this is the one-line form a
    /// caption can carry.
    public static var plateAttribution: String {
        String(localized: "analytics.export.plateAttribution",
               defaultValue: "Foreign Relations of the United States, published by the Office of the Historian, U.S. Department of State. Public domain.")
    }

    /// Where the numbers are — phrased to stay true of a plate published on its own.
    ///
    /// It used to read "Full method, caveats, and the underlying numbers **accompany this figure**
    /// in its CSV export", printed unconditionally by the canvas. Publish the PNG alone and that
    /// sentence does not merely omit the caveats — it asserts they travelled with the image. This
    /// states where the data can be got, which is true however the figure is published.
    public static var plateDataPointer: String {
        String(localized: "analytics.export.figure.seeData",
               defaultValue: "The underlying numbers are available as a CSV export from FRUS Explorer, with the full method statement.")
    }

    /// The corpus attribution, matching the app's own About/Settings wording.
    public static var corpusAttribution: String {
        String(localized: "analytics.export.attribution",
               defaultValue: "Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State (history.state.gov). The corpus is in the public domain.")
    }

    // MARK: - Derived text

    /// The scope line — the named scope, else the whole indexed corpus.
    public var scopeDescription: String {
        if let scopeLabel, !scopeLabel.isEmpty { return scopeLabel }
        return String(localized: "analytics.export.scope.wholeCorpus", defaultValue: "Whole corpus")
    }

    /// The year-range line, phrased explicitly when the axis ignores the range.
    public var yearRangeDescription: String {
        guard let yearRange else {
            return String(localized: "analytics.export.range.notApplied",
                          defaultValue: "Not applied — this breakdown covers the whole corpus span")
        }
        return String(format: String(localized: "analytics.export.range %lld %lld",
                                     defaultValue: "%lld–%lld"),
                      Int64(yearRange.lowerBound), Int64(yearRange.upperBound))
    }

    /// The dating rule as implemented — the surface's own where it supplied one, else the
    /// corpus-analytics rule with its volume-start-year fallback.
    ///
    /// Re-keyed to `.v2` at #1306, which is the first time this string has moved. It had drifted
    /// twice: it still named the `TEI <date>` the in-app row dropped at #1299, and it carried the
    /// no-month/no-day exclusion that #1306 measured and refuted. It is the worse of the two
    /// surfaces to leave wrong, because it travels — a CSV preamble or a figure caption is read
    /// outside the app, by someone who cannot check it against the chart.
    public var datingCaveat: String {
        if let datingRule { return datingRule }
        return String(localized: "analytics.export.caveat.dating.v2",
               defaultValue: "Dating: each document sits at the editor-annotated date; where that date is a range, at the range’s first day (about 3% of the corpus). Every stored date is a full day, so nothing is dropped for want of a month or a day. A document with no stored date at all falls back to the start year of its volume on the By Year and By Decade charts, in both the counts and the % denominator; the By Month and By Day charts have no such fallback and leave it out.")
    }

    /// What corpus the figure covers — the surface's own statement where it supplied one, else
    /// the indexed-on-this-device caveat. The count goes through `CountCopy` (#1374 review,
    /// round 1): the hedged "volume(s)" read "1 volume(s)" on a one-volume device. The count is grouped for
    /// the host's locale.
    public func corpusCaveat(for host: Host) -> String {
        if let corpusStatement { return corpusStatement }
        return String(format: String(localized: "analytics.export.caveat.corpus %@",
                              defaultValue: "Corpus: counts cover only the %@ indexed on this device, not the entire FRUS series."),
               CountCopy.volumes(indexedVolumeCount, locale: host.locale))
    }

    /// The value-mode caveat, spelled out for both modes rather than only for shares.
    public var valueModeCaveat: String? {
        guard let valueMode else { return nil }
        return String(format: String(localized: "analytics.export.caveat.values %@",
                                     defaultValue: "Values: %@. A share is that period’s matching documents divided by all indexed documents in the same period, so a growing corpus does not read as a rising term."),
                      valueMode)
    }

    /// The export timestamp, formatted for a reader (not for machines), in the host's locale, calendar
    /// and time zone: `formatted(date: .abbreviated, time: .shortened)`, which the app's host gives.
    public func formattedDate(for host: Host) -> String {
        Date.FormatStyle(date: .abbreviated, time: .shortened, locale: host.locale, calendar: host.calendar,
                         timeZone: host.timeZone).format(exportDate)
    }

    // MARK: - Renderings

    /// The two lines baked onto an exported figure: the title, then the identifying facts.
    ///
    /// Deliberately short — a journal retypesets captions, and a six-line block would consume the
    /// canvas. The complete method block lives in the accompanying CSV.
    public func captionLines(for host: Host) -> [String] {
        var facts: [String] = [scopeDescription]
        if yearRange != nil { facts.append(yearRangeDescription) }
        if let valueMode { facts.append(valueMode) }
        facts.append(Self.appCredit(for: host))
        facts.append(formattedDate(for: host))
        return [figureTitle, facts.joined(separator: " · ")]
    }

    /// Every caveat the CSV method block states, in the order it states them.
    ///
    /// One definition, two consumers: `csvPreambleLines` prints these below its header fields and
    /// `plateCaveatLines` prints them (or a designated subset) on the image, so a plate cannot
    /// disclose something its CSV does not.
    public func allCaveats(for host: Host) -> [String] {
        var lines: [String] = []
        if appliesDocumentDating || datingRule != nil { lines.append(datingCaveat) }
        lines.append(corpusCaveat(for: host))
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
    public func plateCaveatLines(for host: Host) -> [String] {
        guard let plateCaveats else { return allCaveats(for: host) }
        let designated = Set(plateCaveats)
        let sourceLines = ProvenanceStatement.lines(for: sources)
        let kept = allCaveats(for: host).filter { designated.contains($0) || sourceLines.contains($0) }
        let corpus = corpusCaveat(for: host)
        return kept.contains(corpus) ? kept : [corpus] + kept
    }

    /// Everything an exported plate prints beneath its chart, in order, each tagged with the role
    /// that decides how it is set.
    ///
    /// The canvas is a `ForEach` over this array and nothing else, so a test that drives this
    /// property is testing what the image actually says rather than a parallel copy of the rule.
    public func plateLines(for host: Host) -> [AnalyticsPlateLine] {
        var lines = captionLines(for: host).enumerated().map { index, text in
            AnalyticsPlateLine(role: index == 0 ? .title : .facts, text: text)
        }
        lines += plateCaveatLines(for: host).map { AnalyticsPlateLine(role: .caveat, text: $0) }
        lines.append(AnalyticsPlateLine(role: .attribution, text: Self.plateAttribution))
        lines.append(AnalyticsPlateLine(role: .dataPointer, text: Self.plateDataPointer))
        return lines
    }

    /// The complete method block as `#`-prefixed CSV comment lines (header included), ready to be
    /// prepended to a table's CSV.
    public func csvPreambleLines(for host: Host) -> [String] {
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
        lines.append("\(String(localized: "analytics.export.field.exported", defaultValue: "Exported")): \(Self.appCredit(for: host)), \(formattedDate(for: host))")
        lines.append("")
        lines.append(String(localized: "analytics.export.preamble.method", defaultValue: "Method and caveats"))
        lines.append(contentsOf: allCaveats(for: host))
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
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): moved into FRUSCoreKit, public
public struct AnalyticsPlateLine: Sendable, Equatable {

    /// What a line is for, which is what decides its size and weight.
    public enum Role: Sendable, Equatable {
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
    public let role: Role
    /// The text as printed.
    public let text: String
}

// MARK: - ChartInspectorData + provenance

extension ChartInspectorData {

    /// The table's CSV preceded by `provenance` as `#` comment lines (D3).
    ///
    /// The data itself is unchanged — `csv` still produces the bare RFC-4180 table — so a reader
    /// who wants only the numbers can skip the `#` lines (most parsers accept `comment='#'`), while
    /// a file that travels alone still carries its own method statement.
    ///
    /// - Parameters:
    ///   - provenance: The methods statement to stamp above the header row.
    ///   - host: What the statement reads from its host (``AnalyticsProvenance/Host``).
    /// - Returns: The provenance-stamped CSV text, newline-terminated.
    public func provenancedCSV(_ provenance: AnalyticsProvenance, for host: AnalyticsProvenance.Host) -> String {
        (provenance.csvPreambleLines(for: host) + [csv]).joined(separator: "\n").appending("\n")
    }
}
