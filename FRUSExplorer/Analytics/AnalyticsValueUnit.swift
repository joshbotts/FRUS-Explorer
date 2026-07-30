// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnalyticsValueUnit

/// What the Corpus Analytics numbers count — the single place that names the unit.
///
/// ## Why this exists before there is a second unit
/// The word "Documents" was written out at **thirteen** separate sites in `AnalyticsView` — six
/// chart builders, the table header, the accessibility phrasing, the totals footnote — plus the
/// export column header in `AnalyticsChartTables`. Every one of them is correct today, because
/// documents are the only thing Corpus Analytics counts.
///
/// The moment a second unit arrives, thirteen sites become thirteen chances to leave one saying
/// "Documents" over a column of occurrence counts. That failure has no compile error, no test
/// failure, and no on-screen symptom on the axes you happen to check — and one of those sites is a
/// rendered figure axis title, which nothing in the build reads at all. So the consolidation lands
/// on its own, ahead of the unit that needs it, where the diff is reviewable as "no behaviour
/// change" rather than buried in new SQL.
///
/// ## Nothing here changes what the app displays
/// `documents` is the only case, and every routed site resolves to the same string it hardcoded.
/// Verified by `AnalyticsValueUnitTests`, which also fails if the literal reappears in
/// `AnalyticsView`.
///
/// ## Unit versus normalisation — deliberately separate
/// These are two different questions and conflating them is how a mislabel gets in:
///
/// - **Unit** (this type) is *what is counted* — documents, later occurrences. It applies to every
///   axis.
/// - **Normalisation** (``AnalyticsNormalizationMode``) is *whether the count is divided by the
///   period's corpus total*. It applies only to By Year and By Decade, because no other axis has a
///   per-period denominator.
///
/// A normalised chart's axis reads "% of documents" whatever the unit, since the denominator is
/// documents either way. ``axisLabel(unit:isNormalized:)`` is the one place that decision is made.
///
/// Version history:
///   1.0 — R-2 PR-B: initial implementation, ahead of the occurrence unit (PR-D)
// `Codable` is synthesized from the `String` raw value, which is what makes it safe here: the
// recursion trap recorded for this codebase is a *Codable struct* given a `rawValue` that re-encodes
// `self` for `@AppStorage`. A raw-value enum has a real `rawValue` and needs no such shim, so it
// works with `@AppStorage` and `JSONEncoder` alike.
enum AnalyticsValueUnit: String, CaseIterable, Codable, Sendable {

    /// Matching documents — one per document that matches, however many times it matches.
    case documents

    /// Total occurrences of the query's word stem — every mention, not every document.
    ///
    /// Available only for a single-word query, and only on By Year / By Decade; see
    /// ``OccurrenceAvailability`` for the shapes it cannot serve honestly and why.
    case occurrences

    /// The axis title and table-column noun, capitalised.
    var axisLabel: String {
        switch self {
        case .documents:
            return String(localized: "analytics.axis.documents", defaultValue: "Documents")
        case .occurrences:
            // "(stems)" is not decoration. The count is of the STEM's instances, so a query for
            // "containment" counts "contains" and "container" too — the same breadth the document
            // count has always had, but far more visible once you are counting mentions.
            return String(localized: "analytics.axis.occurrences", defaultValue: "Occurrences (stems)")
        }
    }

    /// The CSV column header for the matching-count column.
    ///
    /// Distinct from ``axisLabel`` because an export column has room to name the population and a
    /// chart axis does not.
    var exportColumnHeader: String {
        switch self {
        case .documents:
            return String(localized: "analytics.export.column.matching",
                          defaultValue: "Matching documents")
        case .occurrences:
            // Deliberately distinct from the word cloud's "Occurrences" column, which counts
            // NLTagger lemmas over body_text only. Two exportable tables using one word for two
            // tokenisations would leave a researcher comparing them with no way to learn why they
            // disagree.
            return String(localized: "analytics.export.column.occurrences",
                          defaultValue: "Occurrences (index stems)")
        }
    }

    /// The totals footnote beneath a chart: "182 documents matched".
    func matchedPhrase(count: Int) -> String {
        switch self {
        case .documents:
            return String(format: String(localized: "analytics.total %lld",
                                         defaultValue: "%lld documents matched"),
                          Int64(count))
        case .occurrences:
            return String(format: String(localized: "analytics.total.occurrences %lld",
                                         defaultValue: "%lld occurrences"),
                          Int64(count))
        }
    }

    /// VoiceOver phrasing for one raw value: "182 documents".
    func accessibilityPhrase(count: Int) -> String {
        switch self {
        case .documents:
            return String(format: String(localized: "analytics.chart.source.count.a11y %lld",
                                         defaultValue: "%lld documents"),
                          Int64(count))
        case .occurrences:
            return String(format: String(localized: "analytics.chart.source.occurrences.a11y %lld",
                                         defaultValue: "%lld occurrences"),
                          Int64(count))
        }
    }

    /// Short label for the Measure picker.
    var pickerLabel: String {
        switch self {
        case .documents:
            return String(localized: "analytics.measure.documents", defaultValue: "Documents")
        case .occurrences:
            return String(localized: "analytics.measure.occurrences", defaultValue: "Occurrences")
        }
    }

    /// `UserDefaults`/`@AppStorage` key for the persisted per-user choice.
    static let storageKey = "frus.analytics.valueUnit"

    /// The value-axis title for a chart, given whether it is plotting normalised shares.
    ///
    /// The normalised label does **not** vary by unit: a share's denominator is indexed documents
    /// whatever the numerator counts, so "% of documents" stays accurate. Keeping that reasoning in
    /// one function is the point — spread across thirteen call sites it would be re-decided
    /// thirteen times.
    static func axisLabel(unit: AnalyticsValueUnit, isNormalized: Bool) -> String {
        guard isNormalized else { return unit.axisLabel }
        return String(localized: "analytics.axis.percentOfDocuments",
                      defaultValue: "% of documents")
    }
}
