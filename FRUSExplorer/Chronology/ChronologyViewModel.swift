// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation

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
///   1.1 — Word Cloud fixes: `isoDay(_:)` formats in the local timezone (was UTC),
///          matching `reload()`'s local `startOfDay` bounds
///   1.2 — #1388: `volumeTag` reads the whole id suffix, so every bundled volume's tag is unique
///          (11 were shared by 29 volumes); `distilledVolumeLabelParts` returns the uncut topic and
///          the tag apart, so a surface can truncate the topic and never the tag
///   1.3 — #1387: `overflowCounts` splits the overflow rows three ways that do not overlap (begins
///          before only, ends after only, reaches past both ends); the view had counted a row that
///          encloses the range as both "before" and "after"
///   1.4 — #1387 review: `overflowCounts` takes the locale its counts are grouped in;
///          `spanningChipTitle` / `spanningChipAccessibilityLabel` give the spanning chip the
///          overflow chip's singular-at-one and grouping rule
///   1.5 — #1422: the spanning chip counts "documents", not "editorial notes", and says they "span
///          more than a year" — the rule `partition` applies — not "this whole period", which an
///          overlap query cannot promise; `spanningSectionHeader` gives the section the same words
///   1.6 — #1472: `volumeTopic` removes an E-volume's "Volume E–N" as it does a Roman "Volume N",
///          so the 22 E-volumes' labels no longer say their number twice
///   1.7 — #1761: `volumeTopic` trims a colon left at either end, so frus1961-63v23's label reads
///          "Southeast Asia · 1961-63 v23", not ": Southeast Asia · 1961-63 v23"
///   1.8 — 2026-11-10 (FRUS Explorer Light, S23b): the volume label's grammar (`volumeTag`, `volumeTopic`
///          and the rest of Volume Labelling) and `VolumeLabelParts` moved into FRUSCoreKit
///          (`VolumeLabels`, `FRUSCoreKit/Chronology/VolumeLabels.swift`), unchanged; the three names
///          the app calls stay here as forwarders
///   1.9 — 2026-11-12 (FRUS Explorer Light, S24b): `ChronologyDateGroup`, `ChronologyOverflowCounts`,
///          the four constants and every static rule moved into FRUSCoreKit (`ChronologyGrouping`,
///          `FRUSCoreKit/Chronology/ChronologyGrouping.swift`), line for line; their names here forward
///          there, and the state and `reload()` stay
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
    /// (often years). Surfaced in a separate "Spans more than a year" section rather than
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

    /// Per-chart-bucket finer breakdown for the hover magnifier, keyed by chart `bucketKey`.
    /// Populated only in the full-distribution state (`chartShowsFullDistribution`), where the
    /// document list is capped and the row-based breakdown would be incomplete; the magnifier
    /// reads these aggregate counts instead so it still works on wide ranges.
    var aggregatedMagnifierBars: [String: [ChronologyMagnifierBar]] = [:]

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

    /// Hard cap on rows materialised per load: the kit's `ChronologyGrouping.loadLimit`, under the
    /// name it had here.
    static let loadLimit = ChronologyGrouping.loadLimit

    /// Days above which day-grouping coarsens to month, and (×8) to year: the kit's
    /// `ChronologyGrouping.dayGroupingMaxDays` and `monthGroupingMaxDays`.
    nonisolated static let dayGroupingMaxDays = ChronologyGrouping.dayGroupingMaxDays
    nonisolated static let monthGroupingMaxDays = ChronologyGrouping.monthGroupingMaxDays

    /// The span above which a document is "spanning", not placed on a day: the kit's
    /// `ChronologyGrouping.maxSpanDaysForPlacement`, under the name it had here.
    nonisolated static let maxSpanDaysForPlacement = ChronologyGrouping.maxSpanDaysForPlacement

    /// Maximum distinct chart series (coloured volumes). Beyond this the smallest
    /// volumes fold into a single "Other" series so the legend and palette stay legible.
    /// Seeded from the global default (`ChartSeriesPalette`) and overridable per view via
    /// `applySeriesCount(_:)`.
    var seriesCount: Int = ChartSeriesPalette.defaultCount

    /// Cached chart inputs so `applySeriesCount(_:)` can rebuild the distribution chart
    /// when the series count changes, without re-running the (potentially large) date
    /// query. The aggregate counts are set on the capped path; otherwise the loaded
    /// `groups` are reused.
    private var cachedChartCounts: [(bucketKey: String, volumeId: String, count: Int)]?
    private var cachedViewBucket: DateBucket?

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
                    cachedChartCounts = counts
                    cachedViewBucket = viewBucket
                    let chart = Self.makeChart(fromCounts: counts,
                                               viewBucket: viewBucket,
                                               maxSeries: seriesCount)
                    chartBuckets = chart.buckets
                    chartSeries = chart.series
                    totalShown = counts.reduce(0) { $0 + $1.count }
                    chartShowsFullDistribution = true
                    // Precompute the hover magnifier's finer breakdown from aggregates, so it
                    // still works even though the document list (its usual source) is capped.
                    aggregatedMagnifierBars = await magnifierBars(
                        pipeline: pipeline, range: range, viewBucket: viewBucket, dayCounts: counts)
                } else {
                    // Defensive fallback: keep the row-derived chart if the aggregate
                    // query returned nothing (e.g. only spanning documents).
                    cachedChartCounts = nil
                    cachedViewBucket = nil
                    let chart = Self.makeChart(from: groups, maxSeries: seriesCount)
                    chartBuckets = chart.buckets
                    chartSeries = chart.series
                    chartShowsFullDistribution = false
                    aggregatedMagnifierBars = [:]
                }
            } else {
                cachedChartCounts = nil
                cachedViewBucket = nil
                let chart = Self.makeChart(from: groups, maxSeries: seriesCount)
                chartBuckets = chart.buckets
                chartSeries = chart.series
                chartShowsFullDistribution = false
                aggregatedMagnifierBars = [:]
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
            aggregatedMagnifierBars = [:]
            hasLoaded = true
        }
    }

    /// Re-folds the distribution chart for a new colored-series count without re-running
    /// the date query, by reusing the cached aggregate counts (capped path) or loaded
    /// `groups`. A no-op when the count is unchanged or no chart has been built yet.
    func applySeriesCount(_ count: Int) {
        guard count != seriesCount else { return }
        seriesCount = count
        if let counts = cachedChartCounts, let viewBucket = cachedViewBucket {
            let chart = Self.makeChart(fromCounts: counts, viewBucket: viewBucket, maxSeries: count)
            chartBuckets = chart.buckets
            chartSeries = chart.series
        } else if !groups.isEmpty {
            let chart = Self.makeChart(from: groups, maxSeries: count)
            chartBuckets = chart.buckets
            chartSeries = chart.series
        }
    }

    /// Builds the hover-magnifier breakdown for every chart bucket from aggregate counts,
    /// one granularity finer than the chart (year → months, month → days, day → volumes).
    /// Runs the finer query off the same range as the chart; reuses `dayCounts` for the
    /// day-bucket case so no extra query is needed.
    private func magnifierBars(
        pipeline: IndexingPipeline,
        range: DateRange,
        viewBucket: DateBucket,
        dayCounts: [(bucketKey: String, volumeId: String, count: Int)]
    ) async -> [String: [ChronologyMagnifierBar]] {
        switch viewBucket {
        case .year:
            let months = (try? await pipeline.dateBucketVolumeCounts(
                range, bucket: .month, scopeVolumeIds: nil)) ?? []
            return Self.magnifierBarsByBucket(counts: months,
                                              parentPrefix: DateBucket.year.prefixLength,
                                              volumeBreakdown: false)
        case .month:
            let days = (try? await pipeline.dateBucketVolumeCounts(
                range, bucket: .day, scopeVolumeIds: nil)) ?? []
            return Self.magnifierBarsByBucket(counts: days,
                                              parentPrefix: DateBucket.month.prefixLength,
                                              volumeBreakdown: false)
        case .day:
            return Self.magnifierBarsByBucket(counts: dayCounts,
                                              parentPrefix: DateBucket.day.prefixLength,
                                              volumeBreakdown: true)
        }
    }

    // MARK: - Grouping

    // The grouping, partition, overflow and chart rules are FRUSCoreKit's `ChronologyGrouping`, where
    // they moved line for line (FRUS Explorer Light, S24b); these are the names `reload()`, the view and
    // the suites call.

    /// Buckets `rows` into date sections: `ChronologyGrouping.group(_:viewBucket:ascending:)`.
    nonisolated private static func group(
        _ rows: [ChronologyRow],
        viewBucket: DateBucket,
        ascending: Bool
    ) -> [ChronologyDateGroup] {
        ChronologyGrouping.group(rows, viewBucket: viewBucket, ascending: ascending)
    }

    /// Splits loaded rows into day-placeable and spanning documents: `ChronologyGrouping.partition(_:)`.
    nonisolated static func partition(
        _ rows: [ChronologyRow]
    ) -> (placed: [ChronologyRow], spanning: [ChronologyRow]) {
        ChronologyGrouping.partition(rows)
    }

    /// Splits day-placeable rows into those inside the range and those reaching past it:
    /// `ChronologyGrouping.splitOverflow(_:startISO:endISO:)`.
    nonisolated static func splitOverflow(
        _ placed: [ChronologyRow],
        startISO: String,
        endISO: String
    ) -> (inRange: [ChronologyRow], overflow: [ChronologyRow]) {
        ChronologyGrouping.splitOverflow(placed, startISO: startISO, endISO: endISO)
    }

    /// Whether a row reaches before or after the range: `ChronologyGrouping.overflowDirection(_:startISO:endISO:)`.
    nonisolated static func overflowDirection(
        _ row: ChronologyRow,
        startISO: String,
        endISO: String
    ) -> (leading: Bool, trailing: Bool) {
        ChronologyGrouping.overflowDirection(row, startISO: startISO, endISO: endISO)
    }

    /// The overflow chip's three counts: `ChronologyGrouping.overflowCounts(_:startISO:endISO:locale:)`.
    nonisolated static func overflowCounts(
        _ rows: [ChronologyRow],
        startISO: String,
        endISO: String,
        locale: Locale = .autoupdatingCurrent
    ) -> ChronologyOverflowCounts {
        ChronologyGrouping.overflowCounts(rows, startISO: startISO, endISO: endISO, locale: locale)
    }

    /// The spanning chip's headline: `ChronologyGrouping.spanningChipTitle(_:locale:)`.
    nonisolated static func spanningChipTitle(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        ChronologyGrouping.spanningChipTitle(count, locale: locale)
    }

    /// The spanning chip's VoiceOver label: `ChronologyGrouping.spanningChipAccessibilityLabel(_:locale:)`.
    nonisolated static func spanningChipAccessibilityLabel(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        ChronologyGrouping.spanningChipAccessibilityLabel(count, locale: locale)
    }

    /// The spanning section's header: `ChronologyGrouping.spanningSectionHeader`.
    nonisolated static var spanningSectionHeader: String {
        ChronologyGrouping.spanningSectionHeader
    }

    /// A date group's own rows one granularity finer: `ChronologyGrouping.magnifierBreakdown(for:)`.
    nonisolated static func magnifierBreakdown(for group: ChronologyDateGroup) -> [ChronologyMagnifierBar] {
        ChronologyGrouping.magnifierBreakdown(for: group)
    }

    /// The hover magnifier's bars from aggregate counts:
    /// `ChronologyGrouping.magnifierBarsByBucket(counts:parentPrefix:volumeBreakdown:)`.
    nonisolated static func magnifierBarsByBucket(
        counts: [(bucketKey: String, volumeId: String, count: Int)],
        parentPrefix: Int,
        volumeBreakdown: Bool
    ) -> [String: [ChronologyMagnifierBar]] {
        ChronologyGrouping.magnifierBarsByBucket(counts: counts, parentPrefix: parentPrefix,
                                                 volumeBreakdown: volumeBreakdown)
    }

    /// Start instant of the bucket containing `date`: `ChronologyGrouping.startOfBucket(_:bucket:calendar:)`.
    nonisolated static func startOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        ChronologyGrouping.startOfBucket(date, bucket: bucket, calendar: calendar)
    }

    /// End instant of the bucket containing `date`: `ChronologyGrouping.endOfBucket(_:bucket:calendar:)`.
    nonisolated static func endOfBucket(_ date: Date, bucket: DateBucket, calendar: Calendar) -> Date {
        ChronologyGrouping.endOfBucket(date, bucket: bucket, calendar: calendar)
    }

    /// The distribution chart from the placed date groups: `ChronologyGrouping.makeChart(from:maxSeries:)`.
    nonisolated static func makeChart(
        from groups: [ChronologyDateGroup],
        maxSeries: Int
    ) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        ChronologyGrouping.makeChart(from: groups, maxSeries: maxSeries)
    }

    /// The distribution chart from aggregate counts:
    /// `ChronologyGrouping.makeChart(fromCounts:viewBucket:maxSeries:)`.
    nonisolated static func makeChart(
        fromCounts counts: [(bucketKey: String, volumeId: String, count: Int)],
        viewBucket: DateBucket,
        maxSeries: Int
    ) -> (buckets: [ChronologyChartBucket], series: [ChronologyChartSeries]) {
        ChronologyGrouping.makeChart(fromCounts: counts, viewBucket: viewBucket, maxSeries: maxSeries)
    }

    // MARK: - Volume Labelling

    /// The kit's `VolumeLabels.volumeTopicMaxLength`, under the name it had here.
    nonisolated static let volumeTopicMaxLength = VolumeLabels.volumeTopicMaxLength

    /// A concise, distinct, descriptive label for a volume: the kit's
    /// `VolumeLabels.distilledVolumeLabel(volumeId:subseries:title:)`, where the label's grammar and
    /// its history moved (FRUS Explorer Light, S23b), under the name every call site uses.
    nonisolated static func distilledVolumeLabel(volumeId: String, subseries: String, title: String) -> String {
        VolumeLabels.distilledVolumeLabel(volumeId: volumeId, subseries: subseries, title: title)
    }

    /// The label's two halves, apart, the topic uncut and the tag: the kit's
    /// `VolumeLabels.distilledVolumeLabelParts(volumeId:subseries:title:)`, under the name every call
    /// site uses.
    nonisolated static func distilledVolumeLabelParts(volumeId: String, subseries: String,
                                                      title: String) -> VolumeLabelParts {
        VolumeLabels.distilledVolumeLabelParts(volumeId: volumeId, subseries: subseries, title: title)
    }

    /// The view's grouping granularity for a range: `ChronologyGrouping.bucket(forDaysBetween:and:calendar:)`.
    nonisolated private static func bucket(forDaysBetween start: Date, and end: Date, calendar: Calendar) -> DateBucket {
        ChronologyGrouping.bucket(forDaysBetween: start, and: end, calendar: calendar)
    }

    // MARK: - Formatting

    /// The `yyyy-MM-dd` day string for a date, in the user's local timezone: `ChronologyGrouping.isoDay(_:)`.
    nonisolated private static func isoDay(_ date: Date) -> String {
        ChronologyGrouping.isoDay(date)
    }
}
