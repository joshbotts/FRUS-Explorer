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
}

// MARK: - ChronologyParameters

/// Lightweight, `Sendable`/`Equatable` handoff value placed on
/// `AppState.pendingChronology` to open the Chronology browser seeded with a date range.
///
/// Mirrors the role `AnalyticsParameters` plays for `pendingAnalytics`.
///
/// Version history:
///   1.0 — Session 163: initial implementation
public struct ChronologyParameters: Sendable, Equatable {
    /// Lower bound of the range to display. `nil` keeps the view's default.
    public var rangeStart: Date?
    /// Upper bound of the range to display. `nil` keeps the view's default.
    public var rangeEnd: Date?

    public init(rangeStart: Date? = nil, rangeEnd: Date? = nil) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}
