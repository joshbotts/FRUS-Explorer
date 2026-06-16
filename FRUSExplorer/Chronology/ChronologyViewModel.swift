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

    /// Loaded, date-bucketed sections in display order.
    var groups: [ChronologyDateGroup] = []
    /// Total documents currently shown across all sections.
    var totalShown: Int = 0
    /// `true` once a load has completed (drives the prompt vs results state).
    var hasLoaded: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    /// `true` when the result set hit `loadLimit` and was truncated.
    var isCapped: Bool = false

    // MARK: - Dependencies

    /// Set by the view before the first `reload()`.
    var pipeline: IndexingPipeline?

    /// Hard cap on rows materialised per load. The date pickers bound the working set;
    /// when a very wide range still exceeds this, the UI advises narrowing.
    static let loadLimit = 5000

    /// Days above which day-grouping coarsens to month, and (×8) to year.
    nonisolated static let dayGroupingMaxDays = 366
    nonisolated static let monthGroupingMaxDays = 366 * 8

    // MARK: - Init

    init(rangeStart: Date, rangeEnd: Date) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
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
        let range = DateRange(
            earliest: Self.isoDay(startDay),
            latest: Self.isoDay(endDay)
        )

        do {
            let rows = try await pipeline.documentsInDateRange(
                range,
                scopeVolumeIds: nil,
                ascending: ascending,
                limit: Self.loadLimit
            )
            isCapped = rows.count >= Self.loadLimit
            totalShown = rows.count
            groups = Self.group(rows, viewBucket: Self.bucket(forDaysBetween: startDay, and: endDay, calendar: cal), ascending: ascending)
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            groups = []
            totalShown = 0
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
