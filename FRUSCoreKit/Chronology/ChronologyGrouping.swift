// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ChronologyDateGroup

/// A date-bucketed section of the Chronology browser: all loaded documents that fall in
/// one calendar bucket (day / month / year), plus aggregate provenance counts shown in
/// the section header.
///
/// Version history:
///   1.0 — Session 163: initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `ChronologyViewModel.swift` into FRUSCoreKit,
///          public and `Sendable`, its memberwise initialiser spelt out and public
public struct ChronologyDateGroup: Identifiable, Sendable {
    /// ISO prefix identifying the bucket (`"1969-02-15"`, `"1969-02"`, or `"1969"`).
    public let bucketKey: String
    /// Granularity this bucket is rendered at.
    public let granularity: DateBucket
    /// Earliest instant of the bucket, used for chronological ordering.
    public let sortDate: Date
    /// Human-readable section title rendered at the bucket's granularity.
    public let displayLabel: String
    /// Documents in this bucket, pre-sorted by date then document number.
    public let rows: [ChronologyRow]
    /// Distinct volumes represented.
    public let volumeCount: Int
    /// Distinct subseries represented.
    public let subseriesCount: Int
    /// Number of editorial notes in the bucket.
    public let editorialNoteCount: Int

    public var id: String { bucketKey }
    public var count: Int { rows.count }

    /// A section of exactly these values, as `ChronologyGrouping.group(_:viewBucket:ascending:)` builds
    /// each one: the memberwise initialiser, spelt out so that a host can build one too, as the app's
    /// legend filter does when it narrows a section's rows to the chosen volumes.
    public init(bucketKey: String, granularity: DateBucket, sortDate: Date, displayLabel: String,
                rows: [ChronologyRow], volumeCount: Int, subseriesCount: Int, editorialNoteCount: Int) {
        self.bucketKey = bucketKey
        self.granularity = granularity
        self.sortDate = sortDate
        self.displayLabel = displayLabel
        self.rows = rows
        self.volumeCount = volumeCount
        self.subseriesCount = subseriesCount
        self.editorialNoteCount = editorialNoteCount
    }
}

// MARK: - ChronologyOverflowCounts

/// How the Chronology's overflow rows — the documents whose uncertain dates reach past the picked
/// range — split by the way each one reaches past it, and the chip copy built from that split.
/// `ChronologyGrouping.overflowCounts(_:startISO:endISO:locale:)` produces it (the app calls it by
/// `ChronologyViewModel`'s name); `ChronologyView`'s chip draws its three strings and nothing else.
///
/// The three counts do not overlap. A row that begins before the range **and** ends after it (a
/// year-only date around a season's range) is counted once, in `spansWholeRange`, and in neither
/// of the others, so the parts always add up to `total` and the breakdown reads as a split of the
/// headline. #1387: the view used to count "before" and "after" separately, so over Sep 1 – Nov
/// 30, 1962 the iOS manual's capture read "26 documents extend beyond this range (26 before · 24
/// after)" — 24 enclosing rows counted on both sides, and 2 that only began before.
///
/// Every count is grouped and singular at exactly one. The app ships no String Catalog, so each
/// phrase is a `.one` / `.many` key pair (the `HubCopy` pattern) with the number grouped in
/// `locale` (`12,067`), where a `%lld` through `String(format:)` is not grouped at all.
///
/// Version history:
///   1.0 — #1387: initial implementation, lifted out of `ChronologyView`'s two-counter loop
///   1.1 — #1387 review: the VoiceOver label reads the breakdown as well as the total, and the
///          counts are grouped in `locale`, which a test pins rather than inheriting the host's
///   1.2 — #1387 second review: `==` compares the three parts and leaves the locale out
///   1.3 — 2026-11-12 (FRUS Explorer Light, S24b): out of `ChronologyViewModel.swift` into FRUSCoreKit,
///          public
public struct ChronologyOverflowCounts: Equatable, Sendable {
    /// Rows that begin before the range and end inside it.
    public let beginsBeforeOnly: Int
    /// Rows that begin inside the range and end after it.
    public let endsAfterOnly: Int
    /// Rows that begin before the range and end after it, so they enclose the whole of it.
    public let spansWholeRange: Int
    /// The locale every count is grouped in: the reader's own, unless a caller pins one — the
    /// tests do, so that an expected "12,067" does not depend on the region of the machine running
    /// them. It decides how the counts are written, not what was counted, so `==` leaves it out.
    public var locale: Locale = .autoupdatingCurrent

    /// Every overflow row counted: the sum of the three disjoint parts.
    public var total: Int { beginsBeforeOnly + endsAfterOnly + spansWholeRange }

    /// `n` grouped in `locale`: "12,067" in the United States, "12.067" in Germany.
    private func grouped(_ n: Int) -> String {
        n.formatted(.number.locale(locale))
    }

    /// The chip's headline, "26 documents extend beyond this range".
    public var chipTitle: String {
        total == 1
            ? String(localized: "chronology.overflow.chip.one",
                     defaultValue: "1 document extends beyond this range")
            : String(localized: "chronology.overflow.chip.many",
                     defaultValue: "\(grouped(total)) documents extend beyond this range")
    }

    /// The non-zero parts in the order before, after, both: "2 begin before", "24 reach past both
    /// ends". The third part says "reach past both ends" rather than "span the whole range": the
    /// spanning chip directly above this one says its documents "span more than a year", so a
    /// second "span" would read as the same claim about a different set of documents.
    private var parts: [String] {
        var parts: [String] = []
        if beginsBeforeOnly > 0 {
            let n = beginsBeforeOnly
            parts.append(n == 1
                ? String(localized: "chronology.overflow.beginsBefore.one",
                         defaultValue: "1 begins before")
                : String(localized: "chronology.overflow.beginsBefore.many",
                         defaultValue: "\(grouped(n)) begin before"))
        }
        if endsAfterOnly > 0 {
            let n = endsAfterOnly
            parts.append(n == 1
                ? String(localized: "chronology.overflow.endsAfter.one",
                         defaultValue: "1 ends after")
                : String(localized: "chronology.overflow.endsAfter.many",
                         defaultValue: "\(grouped(n)) end after"))
        }
        if spansWholeRange > 0 {
            let n = spansWholeRange
            parts.append(n == 1
                ? String(localized: "chronology.overflow.reachesPastBoth.one",
                         defaultValue: "1 reaches past both ends")
                : String(localized: "chronology.overflow.reachesPastBoth.many",
                         defaultValue: "\(grouped(n)) reach past both ends"))
        }
        return parts
    }

    /// The chip's breakdown, "(2 begin before · 24 reach past both ends)": `parts` in
    /// parentheses, or `""` when every part is zero.
    public var chipBreakdown: String {
        let parts = self.parts
        return parts.isEmpty ? "" : "(" + parts.joined(separator: " \u{00b7} ") + ")"
    }

    /// The chip's VoiceOver label. It replaces both lines of the chip, so it speaks the breakdown
    /// as well as the headline — "26 documents have uncertain dates that extend beyond this range:
    /// 2 begin before, 24 reach past both ends. Toggle to show them." — with the parts joined by
    /// commas, as a sentence lists them, rather than by the screen's middle dots.
    public var chipAccessibilityLabel: String {
        let breakdown = parts.joined(separator: ", ")
        return total == 1
            ? String(localized: "chronology.overflow.chip.a11y.one",
                     defaultValue: "1 document has an uncertain date that extends beyond this range: \(breakdown). Toggle to show it.")
            : String(localized: "chronology.overflow.chip.a11y.many",
                     defaultValue: "\(grouped(total)) documents have uncertain dates that extend beyond this range: \(breakdown). Toggle to show them.")
    }

    /// Two counts are equal when their three parts are. A synthesized `==` compared `locale` too,
    /// so counts built in the reader's `.autoupdatingCurrent` were unequal to the same split built
    /// in any pinned locale, `en_US` included (#1387's second review).
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.beginsBeforeOnly == rhs.beginsBeforeOnly
            && lhs.endsAfterOnly == rhs.endsAfterOnly
            && lhs.spansWholeRange == rhs.spansWholeRange
    }
}

// MARK: - ChronologyGrouping

/// The corpus-wide Chronology browser's rules over the rows `IndexingPipeline.documentsInDateRange`
/// loads and the counts `IndexingPipeline.dateBucketVolumeCounts` gives: the view's granularity for a
/// range, the split into placed, spanning and overflow rows, the date sections, the chips' copy, the
/// stacked distribution chart with its folded "Other" series, and the hover magnifier's bars — each
/// pure, so a host groups and charts what the app does from the same queries.
///
/// `ChronologyViewModel` keeps the state and `reload()`, which runs these in order, and its names
/// forward here, so the view and the suites call them as before.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24b): out of `ChronologyViewModel` (an `@Observable`
///          `@MainActor` class), line for line: the four constants, the grouping, partition, overflow
///          and chart statics, the bucket choice and the bucket keys' formatting
public enum ChronologyGrouping {

    /// Hard cap on rows materialised per load. The date pickers bound the working set;
    /// when a very wide range still exceeds this, the UI advises narrowing.
    public static let loadLimit = 5000

    /// Days above which day-grouping coarsens to month, and (×8) to year.
    public nonisolated static let dayGroupingMaxDays = 366
    public nonisolated static let monthGroupingMaxDays = 366 * 8

    /// A document whose interval spans more than this many days is treated as
    /// "spanning" (not placed on a day) — set just above a year so genuine multi-day
    /// meetings and year-only documents stay in the list while multi-year editorial
    /// notes are separated out. The section they go to and its chip are worded from this
    /// rule (#1422): a row there has bounds at least 367 days apart, longer than any
    /// calendar year, leap years included, so "more than a year" is true of every row listed.
    public nonisolated static let maxSpanDaysForPlacement = 366

    // MARK: - Grouping

    /// Buckets `rows` into date sections. Each row is placed at the **coarser** of the
    /// view's target granularity and the row's own stored precision, so a year-only
    /// document never lands in a specific-day section pretending to be January 1.
    public nonisolated static func group(
        _ rows: [ChronologyRow],
        viewBucket: DateBucket,
        ascending: Bool
    ) -> [ChronologyDateGroup] {
        var buckets: [String: [ChronologyRow]] = [:]
        var bucketGranularity: [String: DateBucket] = [:]
        for row in rows {
            let gran = coarser(viewBucket, bucket(forPrecision: row.precision))
            let key = String(row.dateISO.prefix(gran.prefixLength))
            buckets[key, default: []].append(row)
            bucketGranularity[key] = gran
        }

        let groups: [ChronologyDateGroup] = buckets.map { key, rows in
            let gran = bucketGranularity[key] ?? viewBucket
            let subseries = Set(rows.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) })
            return ChronologyDateGroup(
                bucketKey: key,
                granularity: gran,
                sortDate: sortDate(forBucketKey: key) ?? .distantPast,
                displayLabel: label(forBucketKey: key, granularity: gran),
                rows: rows,
                volumeCount: Set(rows.map(\.volumeId)).count,
                subseriesCount: subseries.count,
                editorialNoteCount: rows.filter(\.isEditorialNote).count
            )
        }
        return groups.sorted { ascending ? $0.sortDate < $1.sortDate : $0.sortDate > $1.sortDate }
    }

    /// Splits loaded rows into day-placeable documents and wide-span ("spanning")
    /// documents using `maxSpanDaysForPlacement`.
    public nonisolated static func partition(
        _ rows: [ChronologyRow]
    ) -> (placed: [ChronologyRow], spanning: [ChronologyRow]) {
        var placed: [ChronologyRow] = []
        var spanning: [ChronologyRow] = []
        for row in rows {
            if row.spanDays > maxSpanDaysForPlacement {
                spanning.append(row)
            } else {
                placed.append(row)
            }
        }
        return (placed, spanning)
    }

    /// Splits day-placeable rows into those whose interval is fully contained in the picked
    /// range (`inRange`) and those that straddle a boundary (`overflow`). `startISO`/`endISO`
    /// are the inclusive `yyyy-MM-dd` range bounds. A row is overflow when its interval starts
    /// before the range or ends after it — i.e. its date uncertainty pokes outside the window,
    /// so plotting it on the range-anchored chart would misrepresent where it sits.
    public nonisolated static func splitOverflow(
        _ placed: [ChronologyRow],
        startISO: String,
        endISO: String
    ) -> (inRange: [ChronologyRow], overflow: [ChronologyRow]) {
        var inRange: [ChronologyRow] = []
        var overflow: [ChronologyRow] = []
        for row in placed {
            let dir = overflowDirection(row, startISO: startISO, endISO: endISO)
            if dir.leading || dir.trailing {
                overflow.append(row)
            } else {
                inRange.append(row)
            }
        }
        return (inRange, overflow)
    }

    /// Whether a row's date interval extends before (`leading`) and/or after (`trailing`) the
    /// picked range. Compares the 10-character ISO day prefixes so it is precision-agnostic.
    public nonisolated static func overflowDirection(
        _ row: ChronologyRow,
        startISO: String,
        endISO: String
    ) -> (leading: Bool, trailing: Bool) {
        let start = String(row.dateISO.prefix(10))
        let end = String((row.dateISOMax ?? row.dateISO).prefix(10))
        return (leading: start < startISO, trailing: end > endISO)
    }

    /// Counts `rows` by how each one reaches past the inclusive `startISO`…`endISO` range, for the
    /// overflow chip: begins before only, ends after only, or both — three parts that do not
    /// overlap, so they add up to the rows counted (#1387). A row inside the range on both sides
    /// adds to no part; `splitOverflow` never hands the chip one, since it files such a row under
    /// `inRange`, and `ChronologyOverflowChipTests.headlineStatesTheListedRows` pins that the parts
    /// add up to what `splitOverflow` lists. `locale` is the one the chip's counts are grouped in.
    public nonisolated static func overflowCounts(
        _ rows: [ChronologyRow],
        startISO: String,
        endISO: String,
        locale: Locale = .autoupdatingCurrent
    ) -> ChronologyOverflowCounts {
        var beginsBeforeOnly = 0, endsAfterOnly = 0, spansWholeRange = 0
        for row in rows {
            switch overflowDirection(row, startISO: startISO, endISO: endISO) {
            case (leading: true, trailing: true): spansWholeRange += 1
            case (leading: true, trailing: false): beginsBeforeOnly += 1
            case (leading: false, trailing: true): endsAfterOnly += 1
            case (leading: false, trailing: false): break
            }
        }
        return ChronologyOverflowCounts(
            beginsBeforeOnly: beginsBeforeOnly,
            endsAfterOnly: endsAfterOnly,
            spansWholeRange: spansWholeRange,
            locale: locale
        )
    }

    /// The spanning chip's headline, "714 documents span more than a year": singular at one and
    /// grouped in `locale`, like the overflow chip drawn beneath it. It had gone through a `%lld`,
    /// which printed "1 editorial notes" and "12067" (#1387's review).
    ///
    /// **It counts documents, and says "more than a year", on purpose (#1422).** It used to read
    /// "N editorial notes span this whole period", and both halves were false somewhere:
    /// - The count is every row `partition` separates, of every kind. In a 553-volume index 36 of
    ///   the 7,137 rows wider than `maxSpanDaysForPlacement`, in 8 volumes, are not editorial
    ///   notes. The section's footer keeps "(mostly editorial notes)", which holds at 99.5%.
    /// - A row is loaded because its dates OVERLAP the range (`documentsInDateRange`), so it may
    ///   begin or end inside it. What every counted row does is span more than a year — the rule
    ///   that put it here.
    public nonisolated static func spanningChipTitle(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        count == 1
            ? String(localized: "chronology.spanning.chip.one",
                     defaultValue: "1 document spans more than a year")
            : String(localized: "chronology.spanning.chip.many",
                     defaultValue: "\(count.formatted(.number.locale(locale))) documents span more than a year")
    }

    /// The spanning chip's VoiceOver label, singular at one and grouped like its headline, in the
    /// headline's words (#1422).
    public nonisolated static func spanningChipAccessibilityLabel(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        count == 1
            ? String(localized: "chronology.spanning.chip.a11y.one",
                     defaultValue: "1 document spans more than a year. Toggle to show it.")
            : String(localized: "chronology.spanning.chip.a11y.many",
                     defaultValue: "\(count.formatted(.number.locale(locale))) documents span more than a year. Toggle to show them.")
    }

    /// The header of the section the spanning chip opens, "Spans more than a year" — the chip's
    /// rule in the chip's words (#1422). It read "Spans this period", which a row that overlaps
    /// the range and begins or ends inside it does not do. Here beside the chip's sentences so the
    /// two are worded, and tested, together.
    public nonisolated static var spanningSectionHeader: String {
        String(localized: "chronology.spanning.header", defaultValue: "Spans more than a year")
    }

    /// Re-buckets a date group's own rows one granularity finer than the group, for the macOS
    /// hover magnifier: year → months, month → days, day → per-volume. Bars are returned in
    /// ascending key order; empty sub-buckets are omitted.
    public nonisolated static func magnifierBreakdown(for group: ChronologyDateGroup) -> [ChronologyMagnifierBar] {
        switch group.granularity {
        case .year:
            return histogram(group.rows, prefix: 7) { key in monthLabel(fromMonthKey: key) }
        case .month:
            return histogram(group.rows, prefix: 10) { key in dayLabel(fromDayKey: key) }
        case .day:
            // Finest date granularity: break the day down by volume so the colours map to
            // the chart's series palette.
            var counts: [String: Int] = [:]
            for row in group.rows { counts[row.volumeId, default: 0] += 1 }
            return counts
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { ChronologyMagnifierBar(label: $0.key, count: $0.value, seriesKey: $0.key) }
        }
    }

    /// Counts rows by the leading `prefix` characters of their `dateISO`, labelling each
    /// bucket via `label`. Date breakdowns carry no `seriesKey` (accent-coloured mini-bars).
    nonisolated private static func histogram(
        _ rows: [ChronologyRow],
        prefix: Int,
        label: (String) -> String
    ) -> [ChronologyMagnifierBar] {
        var counts: [String: Int] = [:]
        for row in rows { counts[String(row.dateISO.prefix(prefix)), default: 0] += 1 }
        return counts
            .sorted { $0.key < $1.key }
            .map { ChronologyMagnifierBar(label: label($0.key), count: $0.value, seriesKey: nil) }
    }

    /// Short month name from a `"yyyy-MM"` key (e.g. `"1962-10"` → `"Oct"`).
    nonisolated private static func monthLabel(fromMonthKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count >= 2, let month = Int(parts[1]), (1...12).contains(month) else { return key }
        return Calendar(identifier: .gregorian).shortStandaloneMonthSymbols[month - 1]
    }

    /// Day-of-month from a `"yyyy-MM-dd"` key (e.g. `"1962-10-22"` → `"22"`).
    nonisolated private static func dayLabel(fromDayKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count >= 3 else { return key }
        return String(Int(parts[2]) ?? 0)
    }

    /// Short label for a date bucket key — day-of-month for a `yyyy-MM-dd` key, short month
    /// name for a `yyyy-MM` key, else the key verbatim.
    nonisolated private static func dateBucketLabel(forKey key: String) -> String {
        if key.count >= 10 { return dayLabel(fromDayKey: key) }
        if key.count >= 7  { return monthLabel(fromMonthKey: key) }
        return key
    }

    /// Groups finer-grained `(bucketKey, volumeId, count)` aggregates under their parent chart
    /// bucket (the first `parentPrefix` characters of the finer key) to build the hover
    /// magnifier's bars. With `volumeBreakdown` the bars are per volume (largest first, carrying
    /// the volume's series key); otherwise they are per finer date bucket (chronological, no
    /// series key) — matching `magnifierBreakdown(for:)`'s row-based output.
    public nonisolated static func magnifierBarsByBucket(
        counts: [(bucketKey: String, volumeId: String, count: Int)],
        parentPrefix: Int,
        volumeBreakdown: Bool
    ) -> [String: [ChronologyMagnifierBar]] {
        var grouped: [String: [String: Int]] = [:]
        for c in counts {
            let parent = String(c.bucketKey.prefix(parentPrefix))
            let inner = volumeBreakdown ? c.volumeId : c.bucketKey
            grouped[parent, default: [:]][inner, default: 0] += c.count
        }
        var result: [String: [ChronologyMagnifierBar]] = [:]
        for (parent, inner) in grouped {
            if volumeBreakdown {
                result[parent] = inner
                    .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                    .map { ChronologyMagnifierBar(label: $0.key, count: $0.value, seriesKey: $0.key) }
            } else {
                result[parent] = inner
                    .sorted { $0.key < $1.key }
                    .map { ChronologyMagnifierBar(label: dateBucketLabel(forKey: $0.key), count: $0.value, seriesKey: nil) }
            }
        }
        return result
    }

    /// Start instant of the bucket (year/month/day) containing `date`.
    public nonisolated static func startOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        let comps: Set<Calendar.Component>
        switch bucket {
        case .year:  comps = [.year]
        case .month: comps = [.year, .month]
        case .day:   comps = [.year, .month, .day]
        }
        return calendar.date(from: calendar.dateComponents(comps, from: date)) ?? date
    }

    /// End instant of the bucket (year/month/day) containing `date` — the last moment before
    /// the following bucket begins, so the chart domain rounds *out* to whole buckets.
    public nonisolated static func endOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        let start = startOfBucket(date, bucket: bucket, calendar: calendar)
        let unit: Calendar.Component
        switch bucket {
        case .year:  unit = .year
        case .month: unit = .month
        case .day:   unit = .day
        }
        let next = calendar.date(byAdding: unit, value: 1, to: start) ?? start
        return calendar.date(byAdding: .second, value: -1, to: next) ?? next
    }

    /// Builds the stacked-distribution chart data from the placed date groups: one bucket
    /// per group, segmented by volume. When more than `maxSeries` distinct volumes appear,
    /// the smallest fold into a single `chronologyOtherSeriesKey` series so the legend
    /// stays legible. Series are returned largest-first for stable colour assignment.
    public nonisolated static func makeChart(
        from groups: [ChronologyDateGroup],
        maxSeries: Int
    ) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        var volumeTotals: [String: Int] = [:]
        for group in groups {
            for row in group.rows { volumeTotals[row.volumeId, default: 0] += 1 }
        }
        guard !volumeTotals.isEmpty else { return ([], []) }

        // Largest volume first; ties broken by ID for determinism.
        let ranked = volumeTotals.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        let topKeys: Set<String>
        let usesOther: Bool
        if ranked.count <= maxSeries {
            topKeys = Set(ranked.map(\.key))
            usesOther = false
        } else {
            topKeys = Set(ranked.prefix(maxSeries - 1).map(\.key))
            usesOther = true
        }
        func seriesKey(for volumeId: String) -> String {
            topKeys.contains(volumeId) ? volumeId : chronologyOtherSeriesKey
        }

        let buckets: [ChronologyChartBucket] = groups.map { group in
            var counts: [String: Int] = [:]
            for row in group.rows { counts[seriesKey(for: row.volumeId), default: 0] += 1 }
            let segments = counts
                .map { ChronologyChartSegment(seriesKey: $0.key, count: $0.value) }
                .sorted { $0.seriesKey < $1.seriesKey }
            return ChronologyChartBucket(
                bucketKey: group.bucketKey,
                label: group.displayLabel,
                date: group.sortDate,
                segments: segments
            )
        }

        var series = ranked
            .filter { topKeys.contains($0.key) }
            .map { ChronologyChartSeries(key: $0.key, total: $0.value) }
        if usesOther {
            let otherTotal = ranked.filter { !topKeys.contains($0.key) }.reduce(0) { $0 + $1.value }
            series.append(ChronologyChartSeries(key: chronologyOtherSeriesKey, total: otherTotal))
        }
        return (buckets, series)
    }

    /// Builds the stacked-distribution chart from pre-aggregated `(bucketKey, volumeId, count)`
    /// tuples produced by `IndexingPipeline.documentDateBucketCounts`. Used when the range
    /// exceeds `loadLimit`, so the chart reflects the full distribution without materialising
    /// rows. Buckets are keyed at `viewBucket` granularity; volume folding into
    /// `chronologyOtherSeriesKey` matches `makeChart(from:maxSeries:)`.
    public nonisolated static func makeChart(
        fromCounts counts: [(bucketKey: String, volumeId: String, count: Int)],
        viewBucket: DateBucket,
        maxSeries: Int
    ) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        guard !counts.isEmpty else { return ([], []) }

        var volumeTotals: [String: Int] = [:]
        for c in counts { volumeTotals[c.volumeId, default: 0] += c.count }

        let ranked = volumeTotals.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        let topKeys: Set<String>
        let usesOther: Bool
        if ranked.count <= maxSeries {
            topKeys = Set(ranked.map(\.key))
            usesOther = false
        } else {
            topKeys = Set(ranked.prefix(maxSeries - 1).map(\.key))
            usesOther = true
        }
        func seriesKey(for volumeId: String) -> String {
            topKeys.contains(volumeId) ? volumeId : chronologyOtherSeriesKey
        }

        var perBucket: [String: [String: Int]] = [:]
        for c in counts {
            perBucket[c.bucketKey, default: [:]][seriesKey(for: c.volumeId), default: 0] += c.count
        }
        let buckets: [ChronologyChartBucket] = perBucket.keys.sorted().map { key in
            let segments = perBucket[key]!
                .map { ChronologyChartSegment(seriesKey: $0.key, count: $0.value) }
                .sorted { $0.seriesKey < $1.seriesKey }
            return ChronologyChartBucket(
                bucketKey: key,
                label: label(forBucketKey: key, granularity: viewBucket),
                date: sortDate(forBucketKey: key) ?? .distantPast,
                segments: segments
            )
        }

        var series = ranked
            .filter { topKeys.contains($0.key) }
            .map { ChronologyChartSeries(key: $0.key, total: $0.value) }
        if usesOther {
            let otherTotal = ranked.filter { !topKeys.contains($0.key) }.reduce(0) { $0 + $1.value }
            series.append(ChronologyChartSeries(key: chronologyOtherSeriesKey, total: otherTotal))
        }
        return (buckets, series)
    }

    /// The coarser (fewer-component) of two buckets.
    nonisolated private static func coarser(_ a: DateBucket, _ b: DateBucket) -> DateBucket {
        a.prefixLength <= b.prefixLength ? a : b
    }

    /// Maps a stored `DatePrecision` to the corresponding bucket (`nil` → `.day`).
    nonisolated private static func bucket(forPrecision precision: DatePrecision?) -> DateBucket {
        switch precision {
        case .year:  return .year
        case .month: return .month
        default:     return .day
        }
    }

    /// Chooses the view's target grouping granularity from the span of the range.
    public nonisolated static func bucket(forDaysBetween start: Date, and end: Date, calendar: Calendar) -> DateBucket {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days <= dayGroupingMaxDays { return .day }
        if days <= monthGroupingMaxDays { return .month }
        return .year
    }

    // MARK: - Formatting

    /// The `yyyy-MM-dd` day string for a date, in the user's local timezone.
    ///
    /// Must stay in the same timezone as `reload()`'s `Calendar.startOfDay`
    /// normalisation (local): a UTC formatter here rendered a local midnight as the
    /// *previous* day for users east of UTC, querying a range one day earlier than
    /// the pickers showed. Mirrors `WordCloudScope.isoDay(from:)`.
    public nonisolated static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    /// Parses the start instant of a bucket key (`"1969"`, `"1969-02"`, `"1969-02-15"`).
    nonisolated private static func sortDate(forBucketKey key: String) -> Date? {
        let parts = key.split(separator: "-").map { Int($0) }
        guard let year = parts.first ?? nil else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = parts.count > 1 ? parts[1] : 1
        comps.day = parts.count > 2 ? parts[2] : 1
        return Calendar(identifier: .gregorian).date(from: comps)
    }

    /// Renders a bucket key at its granularity: `"1969"`, `"February 1969"`, or
    /// `"February 15, 1969"`.
    nonisolated private static func label(forBucketKey key: String, granularity: DateBucket) -> String {
        guard let date = sortDate(forBucketKey: key) else { return key }
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        switch granularity {
        case .year:  f.dateFormat = "yyyy"
        case .month: f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        case .day:   f.dateStyle = .long
        }
        return f.string(from: date)
    }
}
