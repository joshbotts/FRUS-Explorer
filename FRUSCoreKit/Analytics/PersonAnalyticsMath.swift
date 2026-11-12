// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonTrajectoryNormalization

/// How the multi-person trajectory chart expresses its y-values (CA-5).
///
/// - `raw`: absolute mention counts (mentions in dated documents).
/// - `percentOfDocuments`: each person's mentioning-document count in year Y as a share
///   of **all dated documents** in year Y. Both numerator and denominator are drawn from
///   the dated-only join (`PersonMentionStore.mentioningDocumentTrajectories` /
///   `datedDocumentTotalsByYear`), so a within-year share can never exceed 100%.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonAnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public and `Sendable`
public enum PersonTrajectoryNormalization: String, CaseIterable, Sendable {
    case raw
    case percentOfDocuments

    /// `UserDefaults`/`@AppStorage` key for the persisted per-user choice.
    public static let storageKey = "frus.personAnalytics.normalizationMode"

    /// Short label for the segmented picker.
    public var pickerLabel: String {
        switch self {
        case .raw:
            return String(localized: "personAnalytics.normalize.raw", defaultValue: "Raw count")
        case .percentOfDocuments:
            return String(localized: "personAnalytics.normalize.percent", defaultValue: "% of documents")
        }
    }
}

// MARK: - PersonTrajectoryPoint

/// One plotted point in the multi-person trajectory chart: a person series, a year,
/// and its value (raw mention count, or a document share in `0...1`).
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonAnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public and `Sendable`
public struct PersonTrajectoryPoint: Identifiable, Equatable, Sendable {
    /// The rollup id, keying the color series.
    public let rollupId: Int
    /// The person's canonical display name (the chart series label).
    public let name: String
    /// The coverage year.
    public let year: Int
    /// The plotted value — a raw mention count, or a `0...1` document share.
    public let value: Double

    public var id: String { "\(rollupId)/\(year)" }
}

// MARK: - PersonAnalyticsMath

/// Pure, view-independent transforms behind `PersonAnalyticsView`, factored out so the
/// bucketing / ranking / normalization rules can be unit-tested without a SwiftUI host
/// or a live SQLite connection.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonAnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public
public enum PersonAnalyticsMath {

    /// Flattens raw `rollupId → year → count` trajectories into chart points, filtered
    /// to `range` and sorted by (series, year). Years outside `range` are dropped so the
    /// chart matches the year-range bar without a re-query.
    public static func rawPoints(
        trajectories: [Int: [Int: Int]],
        names: [Int: String],
        range: ClosedRange<Int>
    ) -> [PersonTrajectoryPoint] {
        var points: [PersonTrajectoryPoint] = []
        for (rollupId, byYear) in trajectories {
            let name = names[rollupId] ?? ""
            for (year, count) in byYear where range.contains(year) {
                points.append(PersonTrajectoryPoint(rollupId: rollupId, name: name,
                                                    year: year, value: Double(count)))
            }
        }
        return points.sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }

    /// Converts `rollupId → year → mentioning-document count` into document-share points
    /// (`0...1`), dividing each by the dated-document total for that year. Years absent
    /// from `totals`, or with a zero/negative total, are skipped (no denominator). Because
    /// both the numerator (distinct dated documents mentioning the person) and the
    /// denominator (all dated documents) come from the same dated population, every share
    /// is clamped into `0...1` — a share can never exceed 100%.
    public static func sharePoints(
        mentioningDocs: [Int: [Int: Int]],
        totals: [Int: Int],
        names: [Int: String],
        range: ClosedRange<Int>
    ) -> [PersonTrajectoryPoint] {
        var points: [PersonTrajectoryPoint] = []
        for (rollupId, byYear) in mentioningDocs {
            let name = names[rollupId] ?? ""
            for (year, docs) in byYear where range.contains(year) {
                guard let total = totals[year], total > 0 else { continue }
                let share = min(1.0, Double(docs) / Double(total))
                points.append(PersonTrajectoryPoint(rollupId: rollupId, name: name,
                                                    year: year, value: share))
            }
        }
        return points.sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }

    /// The source years a plotted trajectory period aggregates.
    ///
    /// In **By Decade** mode `bucketByDecade` keys a point by the decade's start, while the raw
    /// per-person dictionaries stay keyed by single year. An exporter that looks those up by the
    /// decade start alone prints the first year's numbers beside a whole-decade plotted value — a
    /// file whose own columns contradict each other. The span is clipped to `range`, because the
    /// plotted point was built from in-range years only, so an edge decade must not pick up years
    /// the chart never counted.
    ///
    /// - Parameters:
    ///   - period: The plotted point's period key (a year, or a decade's start year).
    ///   - byDecade: Whether the chart is bucketing by decade.
    ///   - range: The chart's year range.
    /// - Returns: Every source year that period aggregates, ascending.
    public static func sourceYears(forPeriod period: Int, byDecade: Bool, range: ClosedRange<Int>) -> [Int] {
        guard byDecade else { return [period] }
        let lower = max(period, range.lowerBound)
        let upper = min(period + 9, range.upperBound)
        guard lower <= upper else { return [period] }
        return Array(lower...upper)
    }

    /// Buckets year-keyed points into decades (year floored to the nearest ten), summing
    /// raw values and averaging shares. Used by the decade toggle. `isShare` selects the
    /// aggregation: raw counts sum, document shares are averaged across the decade's years
    /// (a share can't be summed without exceeding 100%).
    ///
    /// One property of the share path is load-bearing for anything that describes this number:
    /// the divisor is the count of points that **reached** the bucket, and `sharePoints` emits a
    /// point only for years the person was actually mentioned in (the underlying query groups by
    /// year and returns no row for a zero-mention year). So a decade's share is the mean over the
    /// years with mentions, not over the decade's ten years — a person mentioned in one year of a
    /// decade plots that year's share for the whole decade.
    public static func bucketByDecade(_ points: [PersonTrajectoryPoint], isShare: Bool) -> [PersonTrajectoryPoint] {
        struct Key: Hashable { let rollupId: Int; let decade: Int }
        var sums: [Key: Double] = [:]
        var counts: [Key: Int] = [:]
        var names: [Int: String] = [:]
        for p in points {
            let decade = (p.year / 10) * 10
            let key = Key(rollupId: p.rollupId, decade: decade)
            sums[key, default: 0] += p.value
            counts[key, default: 0] += 1
            names[p.rollupId] = p.name
        }
        return sums.map { key, sum in
            let value = isShare ? sum / Double(max(1, counts[key] ?? 1)) : sum
            return PersonTrajectoryPoint(rollupId: key.rollupId, name: names[key.rollupId] ?? "",
                                         year: key.decade, value: value)
        }
        .sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }
}

// MARK: - PersonRelationshipPoint

/// One plotted point in the two-person relationship-dynamics chart (CA-8): a year and the
/// number of documents co-mentioning both selected people.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonAnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public and `Sendable`
public struct PersonRelationshipPoint: Identifiable, Equatable, Sendable {
    /// The coverage year (or decade, when bucketed).
    public let year: Int
    /// Distinct dated documents co-mentioning both people in `year`.
    public let coMentions: Int

    public var id: Int { year }
}

/// Pure transforms for the two-person relationship-dynamics chart, factored out for unit
/// testing without a SwiftUI host or a live database (CA-8).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S24b): out of `PersonAnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public
public enum PersonRelationshipMath {

    /// Flattens a `year → co-mention count` map into chart points inside `range`, sorted by
    /// year. Years outside `range` are dropped so the chart matches the year-range bar.
    public static func points(timeline: [Int: Int], range: ClosedRange<Int>) -> [PersonRelationshipPoint] {
        timeline
            .filter { range.contains($0.key) }
            .map { PersonRelationshipPoint(year: $0.key, coMentions: $0.value) }
            .sorted { $0.year < $1.year }
    }

    /// Buckets year-keyed points into decades (year floored to the nearest ten), SUMMING the
    /// co-mention counts (raw counts, so summation is correct — unlike a share).
    public static func bucketByDecade(_ points: [PersonRelationshipPoint]) -> [PersonRelationshipPoint] {
        var sums: [Int: Int] = [:]
        for p in points {
            let decade = (p.year / 10) * 10
            sums[decade, default: 0] += p.coMentions
        }
        return sums.map { PersonRelationshipPoint(year: $0.key, coMentions: $0.value) }
            .sorted { $0.year < $1.year }
    }
}
