// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsNormalizationMode

/// How the date-based Corpus analytics charts express their y-values (CA-4).
///
/// - `raw`: absolute matching-document counts (the original, byte-for-byte behavior).
/// - `percentOfDocuments`: each period's matches as a share of **all** indexed
///   documents in that same period — reading the term as a proportion of the corpus,
///   so "the term got more common" is not conflated with "the corpus got bigger."
///
/// Only meaningful for the date-based By-Year / By-Decade axes (a per-period corpus
/// denominator); the categorical and sub-year axes ignore it.
///
/// Version history:
///   1.0 — CA-4 (analytics CA-track): initial implementation
///   1.1 — 2026-11-11 (FRUS Explorer Light, S24a): out of `AnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public
public enum AnalyticsNormalizationMode: String, CaseIterable, Sendable {
    case raw
    case percentOfDocuments

    /// `UserDefaults`/`@AppStorage` key for the persisted per-user choice.
    static let storageKey = "frus.analytics.normalizationMode"

    /// Short label for the segmented picker.
    public var pickerLabel: String {
        switch self {
        case .raw:
            return String(localized: "analytics.normalize.raw", defaultValue: "Raw count")
        case .percentOfDocuments:
            return String(localized: "analytics.normalize.percent", defaultValue: "% of documents")
        }
    }
}

// MARK: - AnalyticsChartAxis

/// Which dimension to plot in `AnalyticsView`.
///
/// Version history:
///   1.0 — Session 99: initial implementation
///   1.1 — Session 121: add `byDecade`, `byMonth`, and `byDay` granularity options
///   1.2 — Session 163: add `byVolume` axis (per-individual-volume breakdown)
///   1.3 — D1 Phase 3: `Codable` so it can persist inside a saved analytics query
///   1.4 — 2026-11-11 (FRUS Explorer Light, S24a): out of `AnalyticsView.swift`, a SwiftUI file, into
///          FRUSCoreKit, public
public enum AnalyticsChartAxis: String, CaseIterable, Codable, Sendable {
    case byDecade, byYear, byMonth, byDay, bySubseries, byVolume

    /// Short label for the toolbar picker.
    public var pickerLabel: String {
        switch self {
        case .byDecade:    return String(localized: "analytics.axis.byDecade",    defaultValue: "By Decade")
        case .byYear:      return String(localized: "analytics.axis.byYear",      defaultValue: "By Year")
        case .byMonth:     return String(localized: "analytics.axis.byMonth",     defaultValue: "By Month")
        case .byDay:       return String(localized: "analytics.axis.byDay",       defaultValue: "By Day")
        case .bySubseries: return String(localized: "analytics.axis.bySubseries", defaultValue: "By Subseries")
        case .byVolume:    return String(localized: "analytics.axis.byVolume",    defaultValue: "By Volume")
        }
    }

    /// `true` when this axis is date-based (uses `yearRangeStart`...`yearRangeEnd`
    /// for filtering). The categorical Subseries and Volume views ignore the
    /// year-range bar.
    public var isDateBased: Bool {
        self != .bySubseries && self != .byVolume
    }

    /// `true` for the categorical axes (subseries / volume) whose rows and bars can
    /// be tapped to open Search scoped to that subseries or volume.
    public var isCategorical: Bool {
        self == .bySubseries || self == .byVolume
    }
}
