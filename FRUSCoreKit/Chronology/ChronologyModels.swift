// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - DateBucket

/// Granularity used to aggregate documents in `IndexingPipeline.dateBucketCounts` and
/// to group sections in the Chronology view.
///
/// `prefixLength` is the number of leading characters of an ISO `yyyy-MM-dd` string that
/// identify the bucket — 4 for the year, 7 for the month, 10 for the full day.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public enum DateBucket: Sendable {
    case day
    case month
    case year

    /// Leading-character count of `date_iso` that identifies this bucket.
    public var prefixLength: Int {
        switch self {
        case .day:   return 10
        case .month: return 7
        case .year:  return 4
        }
    }
}

// MARK: - ChronologyRow

/// One document row returned by `IndexingPipeline.documentsInDateRange`, carrying the
/// fields the Chronology view needs to render without a second query.
///
/// `summary` is the generated AI summary when present (preferred snippet); the view falls
/// back to `header` otherwise. `dateISO`/`dateISOMax` are the normalized interval bounds;
/// `precision`/`certainty` are the original TEI metadata (`nil` for documents indexed
/// before date-index version 9).
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct ChronologyRow: Sendable, Identifiable {
    public let volumeId: String
    public let documentId: String
    public let header: String
    public let dateline: String?
    public let summary: String?
    public let dateISO: String
    public let dateISOMax: String?
    public let precision: DatePrecision?
    public let certainty: DateCertainty?
    public let isEditorialNote: Bool
    public let isFrontMatter: Bool
    public let documentNumber: String?

    public var id: String { "\(volumeId)/\(documentId)" }

    public init(
        volumeId: String,
        documentId: String,
        header: String,
        dateline: String?,
        summary: String?,
        dateISO: String,
        dateISOMax: String?,
        precision: DatePrecision?,
        certainty: DateCertainty?,
        isEditorialNote: Bool,
        isFrontMatter: Bool,
        documentNumber: String?
    ) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.header = header
        self.dateline = dateline
        self.summary = summary
        self.dateISO = dateISO
        self.dateISOMax = dateISOMax
        self.precision = precision
        self.certainty = certainty
        self.isEditorialNote = isEditorialNote
        self.isFrontMatter = isFrontMatter
        self.documentNumber = documentNumber
    }

    /// `true` when the document's stored interval spans more than one day — i.e. an
    /// explicit multi-day range or an imprecise (month/year-only) date.
    public var isSpan: Bool {
        guard let max = dateISOMax else { return false }
        return max != dateISO
    }

    /// Number of days between the interval's start and end (0 when single-day or
    /// missing a max). Used to separate documents whose date interval is too wide to be
    /// placed on a specific day — chiefly editorial notes, which FRUS stamps with the
    /// whole span of dates they discuss (often the entire volume, sometimes decades).
    public var spanDays: Int {
        guard let maxISO = dateISOMax,
              let start = Self.day(from: dateISO),
              let end = Self.day(from: maxISO)
        else { return 0 }
        return max(0, Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0)
    }

    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func day(from iso: String) -> Date? {
        isoDayFormatter.date(from: String(iso.prefix(10)))
    }
}

// MARK: - Chart aggregation

/// Series key used for the long tail of volumes folded together in the distribution
/// chart once the distinct-volume count exceeds the colour budget.
public let chronologyOtherSeriesKey = "__other__"

/// One stacked segment of a chart bar: the per-series document count within a date bucket.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct ChronologyChartSegment: Sendable, Identifiable {
    /// Volume ID, or `chronologyOtherSeriesKey` for the folded long tail.
    public let seriesKey: String
    public let count: Int
    public var id: String { seriesKey }

    public init(seriesKey: String, count: Int) {
        self.seriesKey = seriesKey
        self.count = count
    }
}

/// One bar of the distribution chart — a date bucket (matching a list section) plus its
/// per-volume breakdown, so the chart and the list stay perfectly in step.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct ChronologyChartBucket: Sendable, Identifiable {
    /// Matches the `bucketKey` of the corresponding `ChronologyDateGroup`.
    public let bucketKey: String
    /// Human-readable bucket label (e.g. "October 22, 1962").
    public let label: String
    /// Start instant of the bucket, used as the temporal x-position.
    public let date: Date
    public let segments: [ChronologyChartSegment]
    public var id: String { bucketKey }
    public var total: Int { segments.reduce(0) { $0 + $1.count } }

    public init(bucketKey: String, label: String, date: Date, segments: [ChronologyChartSegment]) {
        self.bucketKey = bucketKey
        self.label = label
        self.date = date
        self.segments = segments
    }
}

/// A chart series (one coloured volume, or the folded "Other" group) and its total count,
/// in legend display order (largest first). The view resolves `key` to a volume title and
/// a colour.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct ChronologyChartSeries: Sendable, Identifiable {
    public let key: String
    public let total: Int
    public var id: String { key }

    public init(key: String, total: Int) {
        self.key = key
        self.total = total
    }
}

// MARK: - ChronologyMagnifierBar

/// One mini-bar in the macOS hover magnifier: a finer-grained slice of a hovered chart
/// bucket (a month within a year, a day within a month, or a volume within a day).
///
/// `seriesKey` is the volume ID for the day-level (per-volume) breakdown so the view can
/// tint the mini-bar with the matching series colour; it is `nil` for the month/day
/// date breakdowns, which use the accent colour.
///
/// Version history:
///   1.0 — Session 165: macOS hover magnifier
public struct ChronologyMagnifierBar: Sendable, Identifiable {
    public let label: String
    public let count: Int
    public let seriesKey: String?
    public var id: String { label }

    public init(label: String, count: Int, seriesKey: String? = nil) {
        self.label = label
        self.count = count
        self.seriesKey = seriesKey
    }
}

// MARK: - ChronologyParameters

/// Lightweight, `Sendable`/`Equatable` handoff value placed on
/// `AppState.pendingChronology` to open the Chronology browser seeded with a date range.
///
/// Mirrors the role `AnalyticsParameters` plays for `pendingAnalytics`.
///
/// Version history:
///   1.0 — Session 163: initial implementation
/// `Codable & Hashable` since CW-9b, so the same value can key the iOS `chronologyScene` window.
/// Both fields are `Date?`, so both conformances are synthesised.
public struct ChronologyParameters: Sendable, Equatable, Codable, Hashable {
    /// Lower bound of the range to display. `nil` keeps the view's default.
    public var rangeStart: Date?
    /// Upper bound of the range to display. `nil` keeps the view's default.
    public var rangeEnd: Date?

    public init(rangeStart: Date? = nil, rangeEnd: Date? = nil) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}
