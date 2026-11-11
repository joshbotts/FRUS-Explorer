// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsSourceColoring

/// The volume folding of Corpus Analytics' By Year and By Decade charts: each period's matches split by the
/// volume they come from, the volumes ranked by their total over the slice the chart draws, the first kept as
/// series of their own and the rest folded into one "Other" series, as the Chronology chart folds them.
///
/// It was `AnalyticsView`'s, private to that SwiftUI view, which held the series count as state. It is here
/// unchanged, with the count a parameter, and the view's names forward to it; the colours, the palette and
/// the series' titles stay the view's.
///
/// Version history:
///   1.0 — 2026-11-11 (FRUS Explorer Light, S24a): out of `AnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public, with the series count a parameter
public enum AnalyticsSourceColoring {

    /// Series key for the folded long tail of volumes.
    public static let otherSourceKey = "__other__"

    /// A period-bucketed, source-colored chart segment (one stacked rectangle).
    public struct SourceSegment: Identifiable, Sendable {
        public let period: Int
        public let seriesKey: String
        public let count: Int
        public var id: String { "\(period)/\(seriesKey)" }
    }

    /// One legend entry: a source series key and its total over the rendered slice.
    public struct SourceSeries: Identifiable, Sendable {
        public let key: String
        public let total: Int
        public var id: String { key }
    }

    /// Ranks the volumes in `raw` by total count over the slice, keeps the top
    /// `seriesCount`, folds the rest into a single "Other" series, and returns the
    /// stacked per-period segments plus the ranked series list. Ranking is computed over
    /// the SAME slice that renders, so the color scale never drops or miscolors a segment.
    ///
    /// `seriesCount` must be at least 1, as every count the view's picker offers is: at 1 every volume
    /// folds into Other, and below 1 the fold's `prefix(seriesCount - 1)` traps. A host that takes the
    /// count from a request bounds it first.
    public static func sourceColoring(_ raw: [(period: Int, volumeId: String, count: Int)], seriesCount: Int)
        -> (segments: [SourceSegment], series: [SourceSeries]) {
        guard !raw.isEmpty else { return ([], []) }
        var volumeTotals: [String: Int] = [:]
        for r in raw { volumeTotals[r.volumeId, default: 0] += r.count }
        let ranked = volumeTotals.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        // Show up to `seriesCount` distinct colored volumes total: when more exist, keep
        // the top (seriesCount - 1) and fold the rest into one "Other" series — matching
        // the Chronology chart so neither over-colors nor wraps the palette.
        let usesOther = ranked.count > seriesCount
        let topRanked = usesOther ? Array(ranked.prefix(seriesCount - 1)) : ranked
        let topKeys = Set(topRanked.map(\.key))

        var segCounts: [String: Int] = [:]   // "period\u{1}seriesKey" → count
        var seriesTotals: [String: Int] = [:]
        for r in raw {
            let sk = topKeys.contains(r.volumeId) ? r.volumeId : Self.otherSourceKey
            segCounts["\(r.period)\u{1}\(sk)", default: 0] += r.count
            seriesTotals[sk, default: 0] += r.count
        }
        let segments: [SourceSegment] = segCounts.compactMap { keyStr, count in
            let parts = keyStr.split(separator: "\u{1}", maxSplits: 1)
            guard parts.count == 2, let p = Int(parts[0]) else { return nil }
            return SourceSegment(period: p, seriesKey: String(parts[1]), count: count)
        }
        .sorted { $0.period != $1.period ? $0.period < $1.period : $0.seriesKey < $1.seriesKey }

        var series: [SourceSeries] = topRanked.compactMap { entry in
            seriesTotals[entry.key].map { SourceSeries(key: entry.key, total: $0) }
        }
        if let otherTotal = seriesTotals[Self.otherSourceKey] {
            series.append(SourceSeries(key: Self.otherSourceKey, total: otherTotal))
        }
        return (segments, series)
    }
}
