// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CoverageEra

/// A coarse historical era used to colour production analytics without
/// exploding into the manifest's 107 distinct subseries.
///
/// Four buckets span the whole series and carry a stable display order and a
/// localised label. Bucketing is by a single year (a volume's coverage-end
/// year for lag scatter, or its publication year for the per-year bar chart),
/// so the same helper serves both axes.
///
/// Version history:
///   1.0 — Analytics SA-1b: initial implementation
enum CoverageEra: Int, CaseIterable, Sendable, Hashable {
    /// Everything before 1900.
    case pre1900 = 0
    /// 1900 through 1944 (professionalization + the world wars).
    case earlyTwentieth = 1
    /// 1945 through 1990 (the Cold War / national-security turn).
    case coldWar = 2
    /// 1991 to the present (the statutory / contemporary series).
    case contemporary = 3

    /// The era a single year falls into.
    ///
    /// - Parameter year: A four-digit calendar year.
    /// - Returns: The matching era bucket.
    static func bucket(year: Int) -> CoverageEra {
        switch year {
        case ..<1900:        return .pre1900
        case 1900...1944:    return .earlyTwentieth
        case 1945...1990:    return .coldWar
        default:             return .contemporary
        }
    }

    /// Localised label for charts and legends.
    var label: String {
        switch self {
        case .pre1900:
            return String(localized: "series.era.pre1900", defaultValue: "Before 1900")
        case .earlyTwentieth:
            return String(localized: "series.era.earlyTwentieth", defaultValue: "1900–1944")
        case .coldWar:
            return String(localized: "series.era.coldWar", defaultValue: "1945–1990")
        case .contemporary:
            return String(localized: "series.era.contemporary", defaultValue: "1991–present")
        }
    }

    /// The eras in stable display order (matches the raw-value ordering).
    static var ordered: [CoverageEra] { allCases.sorted { $0.rawValue < $1.rawValue } }
}

// MARK: - LagBucket

/// A coarse publication-lag band used to colour the coverage-span Gantt chart.
///
/// Lag is `printYear − coverageEndYear` — how long after the events a volume
/// documents it reached print. The bands surface the story of the series: a
/// near-contemporaneous early record, the mid-century slippage, and the modern
/// ~30-year backlog.
///
/// Version history:
///   1.0 — Analytics SA-1b: initial implementation
enum LagBucket: Int, CaseIterable, Sendable, Hashable {
    /// Under ten years — near-contemporaneous.
    case under10 = 0
    /// Ten to under twenty years.
    case tenToTwenty = 1
    /// Twenty to under thirty years.
    case twentyToThirty = 2
    /// Thirty years or more — at or beyond the statutory target.
    case thirtyPlus = 3

    /// The band a lag (in years) falls into. Negative lags — a volume printed
    /// at or before its own latest document date — bucket as `under10`.
    ///
    /// - Parameter lag: `printYear − coverageEndYear`.
    /// - Returns: The matching lag band.
    static func bucket(lag: Int) -> LagBucket {
        switch lag {
        case ..<10:      return .under10
        case 10..<20:    return .tenToTwenty
        case 20..<30:    return .twentyToThirty
        default:         return .thirtyPlus
        }
    }

    /// Localised label for charts and legends.
    var label: String {
        switch self {
        case .under10:
            return String(localized: "series.lag.under10", defaultValue: "Under 10 years")
        case .tenToTwenty:
            return String(localized: "series.lag.tenToTwenty", defaultValue: "10–20 years")
        case .twentyToThirty:
            return String(localized: "series.lag.twentyToThirty", defaultValue: "20–30 years")
        case .thirtyPlus:
            return String(localized: "series.lag.thirtyPlus", defaultValue: "30+ years")
        }
    }

    /// The bands in stable display order (matches the raw-value ordering).
    static var ordered: [LagBucket] { allCases.sorted { $0.rawValue < $1.rawValue } }
}

// MARK: - SeriesProductionData

/// Pure, deterministic derivation of FRUS production-and-timeliness figures
/// from the bundled volume manifest.
///
/// This carries no SwiftUI and depends only on `VolumeManifestEntry`, so it is
/// fully unit-testable and renders offline with zero index. All year parsing
/// goes through `FRUSVolumeMetadata.firstYear(in:)`, which extracts the first
/// four-digit run and therefore handles a bare year (`"1861"`), an ISO date
/// (`"1861-12-31T…"`), and the one full ISO publication date in the corpus
/// (`"2010-11-05"`) identically.
///
/// The manifest catalogs only *published* volumes, so a pipeline-by-status
/// chart would be trivially uniform; `cumulativeByPrintYear` substitutes the
/// series growth curve instead.
///
/// Version history:
///   1.0 — Analytics SA-1b: initial implementation
///   1.1 — Analytics SA (x-axis bounds): year-range filter helpers
///          (`lagPoints(in:)`, `coverageSpans(in:)`, `volumesPerPrintYearByEra(in:)`,
///          `cumulativeByPrintYear(in:)`) for the editable dashboard year range
struct SeriesProductionData: Sendable {

    // MARK: Point types

    /// One volume's publication-lag observation, present only when both a print
    /// year and a coverage-end year could be parsed.
    struct LagPoint: Identifiable, Sendable, Hashable {
        /// The volume's stable id (also the `Identifiable` id).
        let volumeId: String
        /// The volume's subseries identifier.
        let subseries: String
        /// Year of the latest document in the volume (`dateRange.latest`).
        let coverageEndYear: Int
        /// The TEI print year (`publicationDate`).
        let printYear: Int
        /// `printYear − coverageEndYear`; may be small or negative for
        /// near-contemporaneous early volumes.
        let lagYears: Int
        /// Era bucket of `coverageEndYear`, used to colour the scatter.
        let coverageEra: CoverageEra

        var id: String { volumeId }
    }

    /// One volume's coverage span, present only when both an earliest and a
    /// latest document year could be parsed. Drives the Gantt chart.
    struct CoverageSpan: Identifiable, Sendable, Hashable {
        /// The volume's stable id (also the `Identifiable` id).
        let volumeId: String
        /// The volume's subseries identifier.
        let subseries: String
        /// Year of the earliest document (`dateRange.earliest`).
        let startYear: Int
        /// Year of the latest document (`dateRange.latest`).
        let endYear: Int
        /// Lag band, when a print year was also available; `nil` when the
        /// volume has a coverage span but no parseable print year.
        let lagBucket: LagBucket?

        var id: String { volumeId }
    }

    /// A count of volumes printed in a given year, optionally split by the era
    /// bucket of that print year (for the stacked bar chart).
    struct PrintYearCount: Identifiable, Sendable, Hashable {
        /// The print year.
        let printYear: Int
        /// The era bucket of `printYear`.
        let pubEra: CoverageEra
        /// How many volumes were printed in this (year, era) pair.
        let count: Int

        var id: String { "\(printYear)-\(pubEra.rawValue)" }
    }

    /// A running total of volumes published up to and including a print year.
    struct CumulativePoint: Identifiable, Sendable, Hashable {
        /// The print year.
        let printYear: Int
        /// Total volumes published through this year (inclusive).
        let cumulativeCount: Int

        var id: Int { printYear }
    }

    // MARK: Derived collections

    /// Per-volume lag observations (all kept, including small/negative lags).
    let lagPoints: [LagPoint]

    /// Volumes printed per year, keyed by year in ascending order (summed
    /// across eras — the simple total for a single-colour bar chart).
    let volumesPerPrintYear: [(printYear: Int, count: Int)]

    /// Volumes printed per (year, era) pair, ascending by year then era —
    /// the breakdown for an era-coloured bar chart.
    let volumesPerPrintYearByEra: [PrintYearCount]

    /// Per-volume coverage spans, sorted by `startYear` (then `endYear`).
    let coverageSpans: [CoverageSpan]

    /// Cumulative published-volume totals by print year, ascending.
    let cumulativeByPrintYear: [CumulativePoint]

    // MARK: Coverage stats

    /// Total number of manifest entries considered.
    let total: Int
    /// How many entries had a parseable print year.
    let countWithPrintYear: Int
    /// How many entries had a parseable coverage span (earliest + latest).
    let countWithCoverage: Int
    /// How many entries had both a print year and a coverage-end year (lag).
    let countLagComputable: Int
    /// Minimum lag across `lagPoints`, or `nil` when none exist.
    let lagMin: Int?
    /// Maximum lag across `lagPoints`, or `nil` when none exist.
    let lagMax: Int?
    /// Median lag across `lagPoints`, or `nil` when none exist.
    let lagMedian: Int?

    // MARK: Init

    /// Computes every derived collection and statistic from manifest entries.
    ///
    /// Empty or all-unparseable input yields empty collections and `nil`
    /// statistics — never a crash or a divide-by-zero.
    ///
    /// - Parameter entries: The volume manifest entries to summarise.
    init(entries: [VolumeManifestEntry]) {
        total = entries.count

        // ── Lag points + coverage spans in one pass ────────────────────────
        var lag: [LagPoint] = []
        var spans: [CoverageSpan] = []
        var withPrintYear = 0
        var withCoverage = 0

        for entry in entries {
            let printYear = FRUSVolumeMetadata.firstYear(in: entry.publicationDate)
            let startYear = FRUSVolumeMetadata.firstYear(in: entry.dateRange.earliest)
            let endYear = FRUSVolumeMetadata.firstYear(in: entry.dateRange.latest)

            if printYear != nil { withPrintYear += 1 }
            if startYear != nil && endYear != nil { withCoverage += 1 }

            // Lag needs a print year AND a coverage-end year.
            if let printYear, let endYear {
                let lagYears = printYear - endYear
                lag.append(
                    LagPoint(
                        volumeId: entry.volumeId,
                        subseries: entry.subseries,
                        coverageEndYear: endYear,
                        printYear: printYear,
                        lagYears: lagYears,
                        coverageEra: CoverageEra.bucket(year: endYear)
                    )
                )
            }

            // Coverage span needs an earliest AND a latest year.
            if let startYear, let endYear {
                let bucket = printYear.map { LagBucket.bucket(lag: $0 - endYear) }
                spans.append(
                    CoverageSpan(
                        volumeId: entry.volumeId,
                        subseries: entry.subseries,
                        startYear: startYear,
                        endYear: endYear,
                        lagBucket: bucket
                    )
                )
            }
        }

        lagPoints = lag
        coverageSpans = spans.sorted {
            $0.startYear != $1.startYear ? $0.startYear < $1.startYear : $0.endYear < $1.endYear
        }
        countWithPrintYear = withPrintYear
        countWithCoverage = withCoverage
        countLagComputable = lag.count

        // ── Volumes per print year (total + by era) ────────────────────────
        var totalByYear: [Int: Int] = [:]
        var byYearEra: [PrintYearCount.ID: PrintYearCount] = [:]
        for entry in entries {
            guard let printYear = FRUSVolumeMetadata.firstYear(in: entry.publicationDate) else { continue }
            totalByYear[printYear, default: 0] += 1
            let era = CoverageEra.bucket(year: printYear)
            let key = "\(printYear)-\(era.rawValue)"
            if let existing = byYearEra[key] {
                byYearEra[key] = PrintYearCount(printYear: printYear, pubEra: era, count: existing.count + 1)
            } else {
                byYearEra[key] = PrintYearCount(printYear: printYear, pubEra: era, count: 1)
            }
        }
        let sortedYears = totalByYear.keys.sorted()
        volumesPerPrintYear = sortedYears.map { (printYear: $0, count: totalByYear[$0] ?? 0) }
        volumesPerPrintYearByEra = byYearEra.values.sorted {
            $0.printYear != $1.printYear ? $0.printYear < $1.printYear : $0.pubEra.rawValue < $1.pubEra.rawValue
        }

        // ── Cumulative published-by-print-year ─────────────────────────────
        var running = 0
        cumulativeByPrintYear = sortedYears.map { year in
            running += totalByYear[year] ?? 0
            return CumulativePoint(printYear: year, cumulativeCount: running)
        }

        // ── Lag stats ──────────────────────────────────────────────────────
        let lagValues = lag.map(\.lagYears).sorted()
        lagMin = lagValues.first
        lagMax = lagValues.last
        lagMedian = Self.median(of: lagValues)
    }

    // MARK: Year-range filtering

    /// `lagPoints` restricted to those whose *coverage-end* year falls within
    /// `domain` — the range filter for the (coverage-valued) lag scatter.
    ///
    /// - Parameter domain: The inclusive coverage-year range to keep.
    /// - Returns: The in-range lag points, order preserved.
    func lagPoints(in domain: ClosedRange<Int>) -> [LagPoint] {
        lagPoints.filter { domain.contains($0.coverageEndYear) }
    }

    /// `coverageSpans` restricted to those that *overlap* `domain` — a span is
    /// kept when any part of its `startYear...endYear` intersects the range, so a
    /// volume straddling the boundary still appears. The range filter for the
    /// (coverage-valued) Gantt chart.
    ///
    /// - Parameter domain: The inclusive coverage-year range to keep.
    /// - Returns: The overlapping coverage spans, order preserved.
    func coverageSpans(in domain: ClosedRange<Int>) -> [CoverageSpan] {
        coverageSpans.filter { $0.startYear <= domain.upperBound && $0.endYear >= domain.lowerBound }
    }

    /// `volumesPerPrintYearByEra` restricted to buckets whose *print* year falls
    /// within `domain` — the range filter for the (production-valued) per-year bars.
    ///
    /// - Parameter domain: The inclusive print-year range to keep.
    /// - Returns: The in-range buckets, order preserved.
    func volumesPerPrintYearByEra(in domain: ClosedRange<Int>) -> [PrintYearCount] {
        volumesPerPrintYearByEra.filter { domain.contains($0.printYear) }
    }

    /// `cumulativeByPrintYear` restricted to points whose *print* year falls
    /// within `domain` — the range filter for the (production-valued) growth curve.
    ///
    /// - Parameter domain: The inclusive print-year range to keep.
    /// - Returns: The in-range cumulative points, order preserved.
    func cumulativeByPrintYear(in domain: ClosedRange<Int>) -> [CumulativePoint] {
        cumulativeByPrintYear.filter { domain.contains($0.printYear) }
    }

    /// The median of a *pre-sorted* ascending integer array, or `nil` when
    /// empty. For an even count returns the lower-of-two-middle integer
    /// average (rounded toward zero) — deterministic and crash-safe.
    ///
    /// - Parameter sorted: An ascending-sorted array of values.
    /// - Returns: The median, or `nil` for an empty array.
    static func median(of sorted: [Int]) -> Int? {
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[mid]
        }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
}
