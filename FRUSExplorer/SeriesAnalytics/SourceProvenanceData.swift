// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SourceProvenanceIndex

/// The bundled `source-provenance-index.json` aggregate (Series Analytics SA-3a),
/// mirroring the artifact the `SourceProvenanceIndexGenerator` writes.
///
/// The generator parses every volume's per-document source notes (each TEI
/// `type="source"` element) with the shared `SourceNoteParser` grammar, maps each
/// parse to a stable provenance category, and aggregates the counts by coverage
/// decade (the manifest `dateRange` midpoint). Zero-count categories are *omitted*
/// from a decade's `counts` for size, so a missing key reads as `0`.
///
/// This is a pure `Codable`/`Sendable` value with no SwiftUI dependency; the view
/// derives its chart-ready `SourceProvenanceData` from it.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
struct SourceProvenanceIndex: Codable, Sendable {
    /// The artifact schema version (currently `1`).
    let schemaVersion: Int
    /// The generation date (`yyyy-MM-dd`), for provenance display.
    let generated: String
    /// Total parsed document source notes across every covered volume.
    let totalSourceNotes: Int
    /// How many volumes contributed source notes.
    let volumesCovered: Int
    /// The ordered raw category keys the generator emits (the 10
    /// `SourceProvenanceCategory` raw values, in artifact order).
    let categories: [String]
    /// Per-decade aggregates, ascending by decade.
    let byDecade: [DecadeProvenance]
}

// MARK: - DecadeProvenance

/// One coverage decade's provenance aggregate.
///
/// `counts` is keyed by the raw category string; a category absent from the map
/// contributed `0` notes in this decade (the generator omits zero counts for
/// size). Read counts through `count(for:)` so the omission stays invisible.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
struct DecadeProvenance: Codable, Sendable {
    /// The coverage decade (e.g. `1940` for the 1940s).
    let decade: Int
    /// Total source notes attributed to this decade (sum of all category counts,
    /// including categories omitted from `counts`).
    let totalNotes: Int
    /// How many volumes contributed to this decade.
    let volumeCount: Int
    /// Category-raw-key → note count. Zero-count categories are omitted.
    let counts: [String: Int]

    /// The note count for a category, treating an omitted key as `0`.
    ///
    /// - Parameter category: The provenance category to look up.
    /// - Returns: The number of notes in this decade for that category (`0` if
    ///   the key is absent).
    func count(for category: SourceProvenanceCategory) -> Int {
        counts[category.rawValue] ?? 0
    }
}

// MARK: - SourceProvenanceCategory

/// A stable classification of where a FRUS document's archival original was found,
/// derived from parsing its source note.
///
/// The raw values are the exact category strings the generator writes, in the
/// artifact's order (`ordered` preserves that order). An unknown future raw string
/// is ignored gracefully by `init?(rawValue:)` — decoders that iterate the index's
/// `categories` array skip unrecognised keys rather than trapping.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
enum SourceProvenanceCategory: String, CaseIterable, Sendable, Hashable {
    /// Pre-1960 State Department central filing (the decimal file).
    case centralDecimalFile
    /// Post-1960 State Department central filing (the Central Foreign Policy File).
    case centralForeignPolicyFile
    /// Bureau/office "lot" files.
    case lotFile
    /// Presidential library holdings.
    case presidentialLibrary
    /// Other NARA record-group collections.
    case naraCollection
    /// Intelligence-community records.
    case intelligence
    /// Named State Department file series (e.g. conference or country files).
    case namedFileSeries
    /// Records held in a foreign archive.
    case foreignArchive
    /// Documents drawn from a previously published source.
    case previouslyPublished
    /// A citation form the parser could not classify — *not* the absence of a
    /// source note.
    case unrecognized

    /// The categories in stable display order (matches the artifact's
    /// `categories` array order).
    static var ordered: [SourceProvenanceCategory] {
        [
            .centralDecimalFile, .centralForeignPolicyFile, .lotFile,
            .presidentialLibrary, .naraCollection, .intelligence,
            .namedFileSeries, .foreignArchive, .previouslyPublished,
            .unrecognized,
        ]
    }

    /// Localised label for charts, legends, and the caveat glossary.
    var displayName: String {
        switch self {
        case .centralDecimalFile:
            return String(localized: "series.provenance.cat.centralDecimalFile",
                          defaultValue: "Central Decimal File")
        case .centralForeignPolicyFile:
            return String(localized: "series.provenance.cat.centralForeignPolicyFile",
                          defaultValue: "Central Foreign Policy File")
        case .lotFile:
            return String(localized: "series.provenance.cat.lotFile",
                          defaultValue: "Lot Files")
        case .presidentialLibrary:
            return String(localized: "series.provenance.cat.presidentialLibrary",
                          defaultValue: "Presidential Libraries")
        case .naraCollection:
            return String(localized: "series.provenance.cat.naraCollection",
                          defaultValue: "Other NARA Collections")
        case .intelligence:
            return String(localized: "series.provenance.cat.intelligence",
                          defaultValue: "Intelligence Records")
        case .namedFileSeries:
            return String(localized: "series.provenance.cat.namedFileSeries",
                          defaultValue: "Named File Series")
        case .foreignArchive:
            return String(localized: "series.provenance.cat.foreignArchive",
                          defaultValue: "Foreign Archives")
        case .previouslyPublished:
            return String(localized: "series.provenance.cat.previouslyPublished",
                          defaultValue: "Previously Published")
        case .unrecognized:
            return String(localized: "series.provenance.cat.unrecognized",
                          defaultValue: "Other / Unclassified")
        }
    }

    /// A short label for cramped legends (falls back to `displayName`).
    var shortName: String {
        switch self {
        case .centralDecimalFile:
            return String(localized: "series.provenance.short.centralDecimalFile",
                          defaultValue: "Decimal File")
        case .centralForeignPolicyFile:
            return String(localized: "series.provenance.short.centralForeignPolicyFile",
                          defaultValue: "CFPF")
        case .naraCollection:
            return String(localized: "series.provenance.short.naraCollection",
                          defaultValue: "NARA Collections")
        default:
            return displayName
        }
    }
}

// MARK: - SourceProvenanceData

/// Pure, deterministic derivation of the FRUS series' archival-sourcing evolution
/// from the bundled `SourceProvenanceIndex`.
///
/// This carries no SwiftUI and depends only on the decoded aggregate, so it is
/// fully unit-testable. Everything it derives concerns *where FRUS editors drew
/// documents from* — an editorial/archival signal parsed out of document source
/// notes, not a census of the archives.
///
/// ## The pre-1900 floor
///
/// The pre-1900 decades in the artifact are tiny retrospective-compilation buckets
/// — a handful of volumes, almost entirely `unrecognized` because those early
/// published-correspondence volumes carry no archival source notes. Including them
/// in an over-time trend would be misleading noise, so every derived collection
/// here is floored to decades `>= 1900`. The floored-out note count is surfaced as
/// `prewarExcludedNoteCount` for honest disclosure.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
///   1.1 — Analytics SA (x-axis bounds): `shareByDecade(in:)` / `notesByDecade(in:)`
///          year-range filters for the editable dashboard year range
///   1.2 — Session 3 / #236: retains raw per-decade counts and adds
///          `shareByDecade(in:excluding:)` / `overallComposition(excluding:)` — the
///          category include/exclude filter, renormalizing shares exactly over the
///          shown categories
struct SourceProvenanceData: Sendable {

    /// The decade at which the over-time trend begins; earlier decades are the
    /// retrospective-compilation floor and are excluded from every derivation.
    static let trendStartDecade = 1900

    // MARK: Point types

    /// One category's fractional share within one shown decade — a stacked-area
    /// datum. Shares within a decade sum to `1.0` across all categories present.
    struct CategoryDecadeShare: Identifiable, Sendable, Hashable {
        /// The coverage decade (e.g. `1940` for the 1940s).
        let decade: Int
        /// The provenance category this share is for.
        let category: SourceProvenanceCategory
        /// The category's fractional share of the decade's notes, in `0.0...1.0`.
        let share: Double

        var id: String { "\(decade)-\(category.rawValue)" }
    }

    /// One category's overall composition across all shown decades — a bar datum.
    struct CategoryComposition: Identifiable, Sendable, Hashable {
        /// The provenance category.
        let category: SourceProvenanceCategory
        /// Total notes in this category across all shown decades.
        let noteCount: Int
        /// The category's share of all shown notes, in `0.0...1.0`.
        let share: Double

        var id: Int { SourceProvenanceCategory.ordered.firstIndex(of: category) ?? -1 }
    }

    /// One decade's documentary density — a bar datum for the base-by-decade
    /// context chart.
    struct DecadeDensity: Identifiable, Sendable, Hashable {
        /// The coverage decade (e.g. `1940`).
        let decade: Int
        /// Total source notes attributed to the decade.
        let totalNotes: Int
        /// How many volumes contributed to the decade.
        let volumeCount: Int

        var id: Int { decade }
    }

    // MARK: Derived collections

    /// Per-decade, per-category fractional shares for the stacked-area trend.
    /// Sorted ascending by decade, then by category display order. Within each
    /// decade the shares sum to `1.0` (subject to floating-point rounding); a
    /// category absent from a decade simply has no row. Only decades `>=
    /// trendStartDecade` appear.
    let shareByDecade: [CategoryDecadeShare]

    /// Overall composition — total notes and share per category across all shown
    /// decades — in stable category display order (categories with zero notes are
    /// included so the legend stays stable).
    let overallComposition: [CategoryComposition]

    /// Per-decade documentary density (total notes + volume count) for shown
    /// decades, ascending by decade.
    let notesByDecade: [DecadeDensity]

    // MARK: Stats

    /// The artifact's headline total (all decades, including the pre-1900 floor).
    let totalSourceNotes: Int
    /// The artifact's covered-volume count.
    let volumesCovered: Int
    /// The earliest and latest shown decades, or `nil` when none is present.
    let decadeRangeShown: ClosedRange<Int>?
    /// Total notes floored out below `trendStartDecade` (the pre-1900 buckets).
    let prewarExcludedNoteCount: Int
    /// Total notes across the shown decades (the denominator for `overallComposition`).
    let shownNoteCount: Int

    /// Retained raw per-decade, per-category note counts for the shown decades (zero
    /// counts omitted), so the category include/exclude filter can renormalize shares
    /// *exactly* from counts rather than rescaling the pre-divided shares (#236).
    let shownDecadeCategoryCounts: [Int: [SourceProvenanceCategory: Int]]

    // MARK: Init

    /// Computes every derived collection and statistic from the decoded index.
    ///
    /// A `nil` index (resource missing/malformed) yields empty collections and
    /// zeroed stats — never a crash or divide-by-zero. Decades below
    /// `trendStartDecade` are floored out and their notes counted into
    /// `prewarExcludedNoteCount`.
    ///
    /// - Parameter index: The decoded `source-provenance-index.json`, or `nil`.
    init(index: SourceProvenanceIndex?) {
        guard let index else {
            shareByDecade = []
            overallComposition = []
            notesByDecade = []
            totalSourceNotes = 0
            volumesCovered = 0
            decadeRangeShown = nil
            prewarExcludedNoteCount = 0
            shownNoteCount = 0
            shownDecadeCategoryCounts = [:]
            return
        }

        totalSourceNotes = index.totalSourceNotes
        volumesCovered = index.volumesCovered

        // Partition decades at the trend-start floor.
        let shownDecades = index.byDecade
            .filter { $0.decade >= Self.trendStartDecade }
            .sorted { $0.decade < $1.decade }
        let excludedDecades = index.byDecade
            .filter { $0.decade < Self.trendStartDecade }

        prewarExcludedNoteCount = excludedDecades.reduce(0) { $0 + $1.totalNotes }

        // ── Raw per-decade counts (retained for exact category-filter renormalization) ──
        var decadeCounts: [Int: [SourceProvenanceCategory: Int]] = [:]
        for decade in shownDecades {
            var perCategory: [SourceProvenanceCategory: Int] = [:]
            for category in SourceProvenanceCategory.ordered {
                let count = decade.count(for: category)
                if count > 0 { perCategory[category] = count }
            }
            decadeCounts[decade.decade] = perCategory
        }
        shownDecadeCategoryCounts = decadeCounts

        // ── Share by decade (stacked area) ──────────────────────────────────
        var shares: [CategoryDecadeShare] = []
        for decade in shownDecades {
            guard decade.totalNotes > 0 else { continue }
            let divisor = Double(decade.totalNotes)
            for category in SourceProvenanceCategory.ordered {
                let count = decade.count(for: category)
                guard count > 0 else { continue }
                shares.append(
                    CategoryDecadeShare(
                        decade: decade.decade,
                        category: category,
                        share: Double(count) / divisor
                    )
                )
            }
        }
        shareByDecade = shares

        // ── Overall composition ─────────────────────────────────────────────
        var totalByCategory: [SourceProvenanceCategory: Int] = [:]
        for decade in shownDecades {
            for category in SourceProvenanceCategory.ordered {
                let count = decade.count(for: category)
                guard count > 0 else { continue }
                totalByCategory[category, default: 0] += count
            }
        }
        let shownTotal = totalByCategory.values.reduce(0, +)
        shownNoteCount = shownTotal
        overallComposition = SourceProvenanceCategory.ordered.map { category in
            let count = totalByCategory[category] ?? 0
            let share = shownTotal > 0 ? Double(count) / Double(shownTotal) : 0
            return CategoryComposition(category: category, noteCount: count, share: share)
        }

        // ── Notes by decade (density context) ───────────────────────────────
        notesByDecade = shownDecades.map {
            DecadeDensity(decade: $0.decade, totalNotes: $0.totalNotes, volumeCount: $0.volumeCount)
        }

        // ── Decade range ────────────────────────────────────────────────────
        if let first = shownDecades.first?.decade, let last = shownDecades.last?.decade {
            decadeRangeShown = first...last
        } else {
            decadeRangeShown = nil
        }
    }

    // MARK: Year-range filtering

    /// `shareByDecade` restricted to rows whose *decade* falls within `domain` —
    /// the range filter for the (coverage-valued) provenance-mix stacked area.
    ///
    /// - Parameter domain: The inclusive coverage-year range to keep decades within.
    /// - Returns: The in-range decade shares, order preserved.
    func shareByDecade(in domain: ClosedRange<Int>) -> [CategoryDecadeShare] {
        shareByDecade.filter { domain.contains($0.decade) }
    }

    /// `notesByDecade` restricted to points whose *decade* falls within `domain` —
    /// the range filter for the (coverage-valued) documentary-density bars.
    ///
    /// - Parameter domain: The inclusive coverage-year range to keep decades within.
    /// - Returns: The in-range density points, order preserved.
    func notesByDecade(in domain: ClosedRange<Int>) -> [DecadeDensity] {
        notesByDecade.filter { domain.contains($0.decade) }
    }

    // MARK: Category filtering

    /// `shareByDecade(in:)` with `hidden` categories removed and each decade's shares
    /// **renormalized** over the remaining categories, so a stacked decade still sums to
    /// `1.0` and reads as "share of the shown categories" (#236). Computed exactly from
    /// the retained raw counts, not by rescaling the pre-divided shares. Identity (the
    /// plain `shareByDecade(in:)`) when `hidden` is empty.
    ///
    /// - Parameters:
    ///   - domain: The inclusive coverage-year range to keep decades within.
    ///   - hidden: The categories to exclude.
    /// - Returns: The in-range, renormalized decade shares in decade then display order.
    func shareByDecade(
        in domain: ClosedRange<Int>,
        excluding hidden: Set<SourceProvenanceCategory>
    ) -> [CategoryDecadeShare] {
        guard !hidden.isEmpty else { return shareByDecade(in: domain) }
        var out: [CategoryDecadeShare] = []
        for decade in shownDecadeCategoryCounts.keys.sorted() where domain.contains(decade) {
            let counts = shownDecadeCategoryCounts[decade] ?? [:]
            let shownTotal = counts.reduce(0) { $0 + (hidden.contains($1.key) ? 0 : $1.value) }
            guard shownTotal > 0 else { continue }
            for category in SourceProvenanceCategory.ordered where !hidden.contains(category) {
                let count = counts[category] ?? 0
                guard count > 0 else { continue }
                out.append(CategoryDecadeShare(decade: decade, category: category,
                                               share: Double(count) / Double(shownTotal)))
            }
        }
        return out
    }

    /// `overallComposition` with `hidden` categories removed and shares renormalized over
    /// the remaining categories across all shown decades (#236). The returned rows keep
    /// the stable display order (hidden categories simply drop out, so the chart's colour
    /// domain stays consistent). Identity when `hidden` is empty.
    ///
    /// - Parameter hidden: The categories to exclude.
    /// - Returns: The renormalized composition rows for the shown categories.
    func overallComposition(
        excluding hidden: Set<SourceProvenanceCategory>
    ) -> [CategoryComposition] {
        guard !hidden.isEmpty else { return overallComposition }
        var totalByCategory: [SourceProvenanceCategory: Int] = [:]
        for counts in shownDecadeCategoryCounts.values {
            for (category, count) in counts where !hidden.contains(category) {
                totalByCategory[category, default: 0] += count
            }
        }
        let shownTotal = totalByCategory.values.reduce(0, +)
        return SourceProvenanceCategory.ordered
            .filter { !hidden.contains($0) }
            .map { category in
                let count = totalByCategory[category] ?? 0
                let share = shownTotal > 0 ? Double(count) / Double(shownTotal) : 0
                return CategoryComposition(category: category, noteCount: count, share: share)
            }
    }
}
