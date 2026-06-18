// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

// MARK: - ChronologyDateGroup

/// A date-bucketed section of the Chronology browser: all loaded documents that fall in
/// one calendar bucket (day / month / year), plus aggregate provenance counts shown in
/// the section header.
///
/// Version history:
///   1.0 — Session 163: initial implementation
struct ChronologyDateGroup: Identifiable {
    /// ISO prefix identifying the bucket (`"1969-02-15"`, `"1969-02"`, or `"1969"`).
    let bucketKey: String
    /// Granularity this bucket is rendered at.
    let granularity: DateBucket
    /// Earliest instant of the bucket, used for chronological ordering.
    let sortDate: Date
    /// Human-readable section title rendered at the bucket's granularity.
    let displayLabel: String
    /// Documents in this bucket, pre-sorted by date then document number.
    let rows: [ChronologyRow]
    /// Distinct volumes represented.
    let volumeCount: Int
    /// Distinct subseries represented.
    let subseriesCount: Int
    /// Number of editorial notes in the bucket.
    let editorialNoteCount: Int

    var id: String { bucketKey }
    var count: Int { rows.count }
}

// MARK: - ChronologyViewModel

/// Drives the corpus-wide Chronology browser: holds the selected date range, loads the
/// overlapping documents from `IndexingPipeline.documentsInDateRange`, and groups them
/// into date sections (auto-coarsening day → month → year as the range widens, and never
/// rendering a document finer than its own stored precision).
///
/// Mirrors the data-loading shape of `DocumentTimelineView` but is a standalone,
/// corpus-wide browser rather than a visualization of a supplied result set.
///
/// Version history:
///   1.0 — Session 163: initial implementation
@Observable
@MainActor
final class ChronologyViewModel {

    // MARK: - Inputs

    /// Inclusive lower bound of the displayed range.
    var rangeStart: Date
    /// Inclusive upper bound of the displayed range.
    var rangeEnd: Date
    /// Sort oldest-first when `true`.
    var ascending: Bool = true

    // MARK: - Output

    /// Loaded, date-bucketed sections in display order. Contains only **placed**
    /// documents (those whose date interval is narrow enough to sit on a day/period).
    var groups: [ChronologyDateGroup] = []

    /// Documents whose date interval is too wide to place on a specific day — chiefly
    /// editorial notes that FRUS stamps with the whole span of dates they discuss
    /// (often years). Surfaced in a separate "spans this period" section rather than
    /// smeared across the day-level list and chart. Sorted by start date.
    var spanningRows: [ChronologyRow] = []

    /// Day-placeable documents whose date interval is **not fully contained** in the
    /// picked range — their uncertainty extends before (`leading`) or after (`trailing`)
    /// the range. Kept off the range-anchored chart and reported in a dedicated list
    /// section instead. Sorted by start date.
    var overflowRows: [ChronologyRow] = []

    /// Inclusive chart x-domain, the picked range rounded **out** to whole buckets at the
    /// view granularity. Anchors the distribution chart to the user's range rather than to
    /// the uncertainty bounds of overlapping documents. Set on every `reload()`.
    var chartDomainStart: Date
    var chartDomainEnd: Date

    /// Inclusive `yyyy-MM-dd` bounds of the range that produced the current results — used to
    /// classify overflow direction consistently even if the pickers change before the next
    /// load. Set on every `reload()`.
    var loadedStartISO: String = ""
    var loadedEndISO: String = ""

    /// Per-bucket, per-volume counts backing the distribution chart (placed docs only).
    var chartBuckets: [ChronologyChartBucket] = []

    /// Chart legend series (coloured volumes + an optional folded "Other"), largest first.
    var chartSeries: [ChronologyChartSeries] = []

    /// Total **placed** documents currently shown across all sections.
    var totalShown: Int = 0
    /// `true` once a load has completed (drives the prompt vs results state).
    var hasLoaded: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    /// `true` when the result set hit `loadLimit` and was truncated.
    var isCapped: Bool = false

    /// `true` when the distribution chart reflects the full range via aggregate counts
    /// while the document list below is capped at `loadLimit`. Drives the summary wording
    /// and disables the row-based hover magnifier (whose rows aren't fully loaded).
    var chartShowsFullDistribution: Bool = false

    // MARK: - Dependencies

    /// Set by the view before the first `reload()`.
    var pipeline: IndexingPipeline?

    /// Hard cap on rows materialised per load. The date pickers bound the working set;
    /// when a very wide range still exceeds this, the UI advises narrowing.
    static let loadLimit = 5000

    /// Days above which day-grouping coarsens to month, and (×8) to year.
    nonisolated static let dayGroupingMaxDays = 366
    nonisolated static let monthGroupingMaxDays = 366 * 8

    /// A document whose interval spans more than this many days is treated as
    /// "spanning" (not placed on a day) — set just above a year so genuine multi-day
    /// meetings and year-only documents stay in the list while multi-year editorial
    /// notes are separated out.
    nonisolated static let maxSpanDaysForPlacement = 366

    /// Maximum distinct chart series (coloured volumes). Beyond this the smallest
    /// volumes fold into a single "Other" series so the legend and palette stay legible.
    nonisolated static let maxChartSeries = 8

    // MARK: - Init

    init(rangeStart: Date, rangeEnd: Date) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.chartDomainStart = rangeStart
        self.chartDomainEnd = rangeEnd
    }

    // MARK: - Loading

    /// Loads documents overlapping the current range and rebuilds the grouped sections.
    func reload() async {
        guard let pipeline else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cal = Calendar(identifier: .gregorian)
        // Normalize the bounds to whole days so the inclusive end day is captured.
        let startDay = cal.startOfDay(for: min(rangeStart, rangeEnd))
        let endDay = cal.startOfDay(for: max(rangeStart, rangeEnd))
        let startISO = Self.isoDay(startDay)
        let endISO = Self.isoDay(endDay)
        let range = DateRange(earliest: startISO, latest: endISO)

        do {
            let rows = try await pipeline.documentsInDateRange(
                range,
                scopeVolumeIds: nil,
                ascending: ascending,
                limit: Self.loadLimit
            )
            isCapped = rows.count >= Self.loadLimit

            // Separate wide-span documents (multi-year editorial notes) from the
            // day-placeable set before grouping, so they neither pollute the date
            // sections nor the distribution chart.
            let (placed, spanning) = Self.partition(rows)
            spanningRows = spanning.sorted { $0.dateISO < $1.dateISO }

            // Among the day-placeable documents, peel off those whose interval pokes
            // outside the picked range (uncertain dates). They are reported in a list
            // section rather than stretching the range-anchored chart.
            let (inRange, overflow) = Self.splitOverflow(placed, startISO: startISO, endISO: endISO)
            overflowRows = overflow.sorted { $0.dateISO < $1.dateISO }
            loadedStartISO = startISO
            loadedEndISO = endISO
            totalShown = inRange.count

            let viewBucket = Self.bucket(forDaysBetween: startDay, and: endDay, calendar: cal)
            chartDomainStart = Self.startOfBucket(startDay, bucket: viewBucket, calendar: cal)
            chartDomainEnd = Self.endOfBucket(endDay, bucket: viewBucket, calendar: cal)
            groups = Self.group(inRange, viewBucket: viewBucket, ascending: ascending)

            if isCapped {
                // The list is truncated to `loadLimit`, but the distribution chart should
                // still reflect the whole range. Rebuild it from an aggregate COUNT query
                // (no row materialisation) and report the true total above the capped list.
                let counts = (try? await pipeline.dateBucketVolumeCounts(
                    range, bucket: viewBucket, scopeVolumeIds: nil)) ?? []
                if !counts.isEmpty {
                    let chart = Self.makeChart(fromCounts: counts,
                                               viewBucket: viewBucket,
                                               maxSeries: Self.maxChartSeries)
                    chartBuckets = chart.buckets
                    chartSeries = chart.series
                    totalShown = counts.reduce(0) { $0 + $1.count }
                    chartShowsFullDistribution = true
                } else {
                    // Defensive fallback: keep the row-derived chart if the aggregate
                    // query returned nothing (e.g. only spanning documents).
                    let chart = Self.makeChart(from: groups, maxSeries: Self.maxChartSeries)
                    chartBuckets = chart.buckets
                    chartSeries = chart.series
                    chartShowsFullDistribution = false
                }
            } else {
                let chart = Self.makeChart(from: groups, maxSeries: Self.maxChartSeries)
                chartBuckets = chart.buckets
                chartSeries = chart.series
                chartShowsFullDistribution = false
            }
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            groups = []
            spanningRows = []
            overflowRows = []
            chartBuckets = []
            chartSeries = []
            totalShown = 0
            chartShowsFullDistribution = false
            hasLoaded = true
        }
    }

    // MARK: - Grouping

    /// Buckets `rows` into date sections. Each row is placed at the **coarser** of the
    /// view's target granularity and the row's own stored precision, so a year-only
    /// document never lands in a specific-day section pretending to be January 1.
    nonisolated private static func group(
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
    nonisolated static func partition(
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
    nonisolated static func splitOverflow(
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
    nonisolated static func overflowDirection(
        _ row: ChronologyRow,
        startISO: String,
        endISO: String
    ) -> (leading: Bool, trailing: Bool) {
        let start = String(row.dateISO.prefix(10))
        let end = String((row.dateISOMax ?? row.dateISO).prefix(10))
        return (leading: start < startISO, trailing: end > endISO)
    }

    /// Re-buckets a date group's own rows one granularity finer than the group, for the macOS
    /// hover magnifier: year → months, month → days, day → per-volume. Bars are returned in
    /// ascending key order; empty sub-buckets are omitted.
    nonisolated static func magnifierBreakdown(for group: ChronologyDateGroup) -> [ChronologyMagnifierBar] {
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

    /// Start instant of the bucket (year/month/day) containing `date`.
    nonisolated static func startOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
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
    nonisolated static func endOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
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
    nonisolated static func makeChart(
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
    nonisolated static func makeChart(
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

    // MARK: - Volume Labelling

    /// Maximum characters kept from a volume's topic before eliding; the period/volume tag
    /// keeps the overall label distinct even when the topic is truncated.
    nonisolated static let volumeTopicMaxLength = 40

    /// A concise, distinct, descriptive label for a volume, distilled from its full FRUS
    /// title for the chronology chart legend and hover magnifier — where the raw title (e.g.
    /// "Foreign Relations of the United States, 1969–1976, Volume XX, Southeast Asia,
    /// 1969–1972") is far too long and repetitive to tell volumes apart.
    ///
    /// The result is the volume's **topic** (when the title carries one) joined to a compact
    /// **period + volume/part tag** derived from the id — e.g. "Southeast Asia · 1969-76 v20"
    /// or "Soviet Union · 1981-88 v6". The early annual "Papers Relating to Foreign Affairs"
    /// volumes have no topic, so they reduce to just the tag, e.g. "1864 pt.1". The tag alone
    /// is globally unique, so labels never collide even after a long topic is truncated.
    ///
    /// - Parameters:
    ///   - volumeId: The volume's stable id, e.g. `"frus1969-76v20"`.
    ///   - subseries: The volume's subseries period, e.g. `"1969-76"`.
    ///   - title: The full TEI volume title (whitespace already collapsed on manifest decode).
    nonisolated static func distilledVolumeLabel(volumeId: String, subseries: String, title: String) -> String {
        let tag = volumeTag(volumeId: volumeId, subseries: subseries)
        let topic = volumeTopic(from: title)
        return topic.isEmpty ? tag : "\(topic) · \(tag)"
    }

    /// Compact, globally unique period + volume/part tag derived from the id, e.g.
    /// `"1969-76 v20"`, `"1952-54 v2 pt.1"`, `"1864 pt.1"`, `"1877 app"`, or `"1870"`.
    nonisolated private static func volumeTag(volumeId: String, subseries: String) -> String {
        var parts = [subseries]
        let vol = captureGroups(in: volumeId, pattern: "v(E-)?([0-9]+)")
        if let vol, vol.count > 2, let digits = vol[2], let n = Int(digits) {
            parts.append("v\(vol[1] ?? "")\(n)")
        }
        let part = captureGroups(in: volumeId, pattern: "p([0-9]+)")
        if let part, part.count > 1, let digits = part[1], let n = Int(digits) {
            parts.append("pt.\(n)")
        }
        if parts.count == 1 {
            // No v/p suffix — append any remaining id suffix (e.g. "app") for uniqueness.
            var suffix = volumeId
            let withSub = "frus" + subseries
            if suffix.hasPrefix(withSub) { suffix = String(suffix.dropFirst(withSub.count)) }
            else if suffix.hasPrefix("frus") { suffix = String(suffix.dropFirst(4)) }
            suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            if !suffix.isEmpty { parts.append(suffix) }
        }
        return parts.joined(separator: " ")
    }

    /// The descriptive topic distilled from a full FRUS volume title, or `""` when the title
    /// is pure boilerplate (the early annual "Papers Relating…/Message of the President…"
    /// volumes). Strips the series boilerplate, the subseries year, the "Volume N"/"Part N"
    /// tokens, and trailing date ranges, then truncates to `volumeTopicMaxLength`.
    nonisolated private static func volumeTopic(from title: String) -> String {
        var t = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "Foreign Relations of the United States, Diplomatic Papers,",
            "Foreign Relations of the United States,",
            "Papers Relating to the Foreign Relations of the United States,",
            "Papers Relating to Foreign Affairs,"
        ]
        for p in prefixes where t.hasPrefix(p) {
            t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        for boilerplate in [
            "Accompanying the Annual Message of the President",
            "With the Annual Message of the President",
            "with the Annual Message of the President",
            "Transmitted to Congress",
            "Diplomatic Papers"
        ] {
            t = t.replacingOccurrences(of: boilerplate, with: "")
        }
        let removals = [
            ",?\\s*\\bVolumes?\\s+[IVXLCDM/]+(?:,\\s*[IVXLCDM/]+)*\\b",
            ",?\\s*\\bPart\\s+([IVXLCDM]+|[0-9]+)\\b",
            "to the .*?Congress",
            "^[0-9]{4}(?:[–-][0-9]{2,4})?\\s*,?\\s*",
            ",?\\s*[A-Z][a-z]+ [0-9]{1,2},?\\s*[0-9]{4}.*$",
            ",?\\s*[A-Z][a-z]+ [0-9]{4}\\s*[–-]\\s*[A-Z][a-z]+ [0-9]{4}\\s*$",
            ",?\\s*[0-9]{4}(?:[–-][0-9]{2,4})?\\s*$"
        ]
        for pattern in removals {
            t = t.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;"))
        let low = t.lowercased()
        if t.count < 3 || low.hasPrefix("message of the president")
            || low.contains("congress") || low.contains("session") {
            return ""
        }
        return truncateTopic(t)
    }

    /// Truncates a topic to `volumeTopicMaxLength`, preferring a trailing word boundary, and
    /// appends an ellipsis. The volume tag keeps the full label distinct after truncation.
    nonisolated private static func truncateTopic(_ s: String) -> String {
        guard s.count > volumeTopicMaxLength else { return s }
        var cut = String(s.prefix(volumeTopicMaxLength))
        if let space = cut.lastIndex(of: " "),
           cut.distance(from: cut.startIndex, to: space) >= volumeTopicMaxLength - 12 {
            cut = String(cut[..<space])
        }
        return cut.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:")) + "…"
    }

    /// Returns a regex match's capture groups indexed by group number (`[0]` is the whole
    /// match); an entry is `nil` when that optional group did not participate. `nil` when the
    /// pattern does not match.
    nonisolated private static func captureGroups(in string: String, pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { i in
            Range(match.range(at: i), in: string).map { String(string[$0]) }
        }
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
    nonisolated private static func bucket(forDaysBetween start: Date, and end: Date, calendar: Calendar) -> DateBucket {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days <= dayGroupingMaxDays { return .day }
        if days <= monthGroupingMaxDays { return .month }
        return .year
    }

    // MARK: - Formatting

    nonisolated private static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
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
