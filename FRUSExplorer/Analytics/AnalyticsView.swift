// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - AnalyticsViewMode

/// Presentation mode for `AnalyticsView`.
///
/// Version history:
///   1.0 — Session 99: initial implementation
enum AnalyticsViewMode: String, CaseIterable {
    case chart, table
}

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
enum AnalyticsNormalizationMode: String, CaseIterable {
    case raw
    case percentOfDocuments

    /// `UserDefaults`/`@AppStorage` key for the persisted per-user choice.
    static let storageKey = "frus.analytics.normalizationMode"

    /// Short label for the segmented picker.
    var pickerLabel: String {
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
enum AnalyticsChartAxis: String, CaseIterable, Codable {
    case byDecade, byYear, byMonth, byDay, bySubseries, byVolume

    /// Short label for the toolbar picker.
    var pickerLabel: String {
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
    var isDateBased: Bool {
        self != .bySubseries && self != .byVolume
    }

    /// `true` for the categorical axes (subseries / volume) whose rows and bars can
    /// be tapped to open Search scoped to that subseries or volume.
    var isCategorical: Bool {
        self == .bySubseries || self == .byVolume
    }
}

// MARK: - SavedAnalyticsQuery

/// A persisted Corpus Analytics query (D1 Phase 3): the term(s), axis, year range, and volume scope,
/// so a user can save a comparison and jump back to it, and recent queries are remembered per window.
///
/// Persisted as JSON under a plain `UserDefaults` key (never a `RawRepresentable` `@AppStorage`, which
/// crashes when `rawValue` re-encodes `self` — see the codable-rawrepresentable-recursion note).
/// Normalization mode is intentionally NOT captured (it's forced to % while comparing anyway).
///
/// ## Why the counting unit IS captured, when normalisation is not
/// They look like the same kind of setting and are not. Normalisation is a *display* choice — the same
/// query, drawn against a denominator. The counting unit changes **what the query asks**: documents
/// and occurrences are different numbers over the same corpus, and on this corpus they can move in
/// opposite directions (`Article 43`'s documents fall 34 → 11 from 1948 to 1949 while its occurrences
/// rise 77 → 92). A starred query that silently re-ran in the other unit would re-export a
/// numerically different figure under an identical title and the same filename stem.
///
/// Optional with a `documents` default so queries saved before PR-D still decode.
///
/// Version history:
///   1.0 — D1 Phase 3: initial implementation
///   1.1 — R-2 PR-D: `valueUnit` captured — it changes what is counted, not how it is drawn
struct SavedAnalyticsQuery: Codable, Identifiable, Equatable {
    /// Stable identity for `ForEach` / list membership (not part of query equality).
    let id: UUID
    /// The compared terms, in chip order.
    var terms: [String]
    /// The active chart axis.
    var axis: AnalyticsChartAxis
    /// Year-range bounds.
    var yearStart: Int
    var yearEnd: Int
    /// Volume scope (`nil` = whole corpus) and its display label.
    var scopeVolumeIds: [String]?
    var scopeLabel: String?
    /// When the query was last saved / viewed (drives recents ordering; not part of equality).
    var savedAt: Date
    /// What the query counted. `nil` in queries saved before PR-D; treated as `documents`.
    var valueUnit: AnalyticsValueUnit?

    /// Query equality ignoring `id`/`savedAt` — used for de-duplication and the "is the current
    /// query already saved?" check. Scope identity is the volume-id set; `scopeLabel` is derived.
    ///
    /// The year range is compared only on the **date-based** axes: the categorical breakdowns
    /// (By Subseries / By Volume) ignore it entirely when computing results, so including it would
    /// make the star read "unsaved" — and let the user pile up duplicate entries — for queries that
    /// render an identical chart (review fix).
    func matchesQuery(_ other: SavedAnalyticsQuery) -> Bool {
        guard terms == other.terms, axis == other.axis, scopeVolumeIds == other.scopeVolumeIds,
              (valueUnit ?? .documents) == (other.valueUnit ?? .documents) else {
            return false
        }
        guard !axis.isCategorical else { return true }
        return yearStart == other.yearStart && yearEnd == other.yearEnd
    }

    /// A one-line menu label: the terms joined, then the axis (and scope when narrowed).
    var menuLabel: String {
        let joined = terms.joined(separator: ", ")
        if let scope = scopeLabel, !scope.isEmpty {
            return "\(joined) · \(axis.pickerLabel) · \(scope)"
        }
        return "\(joined) · \(axis.pickerLabel)"
    }
}

// MARK: - AnalyticsView

/// Corpus frequency analytics view with Swift Charts.
///
/// Accepts a keyword term and charts how many indexed documents match that
/// term, broken down either by year of origin or by FRUS subseries. Results
/// are fetched asynchronously from `CorpusAnalyticsService` via `AppState`.
///
/// ## Layout
/// A search field at the top drives the query. When the "By Year" axis is
/// active a compact year-range filter bar is shown below the search field,
/// allowing users to restrict the chart to a custom date window. The body
/// shows either a bar + line chart or a scrollable data table depending on
/// `viewMode`. A toolbar picker switches between "By Year" and "By Subseries".
///
/// ## Year range filtering
/// `yearRangeStart` and `yearRangeEnd` default to 1861 (first FRUS volume
/// year) and the current calendar year. The chart x-axis is pinned to this
/// range via `.chartXScale(domain:)`. Filtering is applied in `filteredYearData`
/// at display time; no re-query is needed.
///
/// ## Platform placement
/// - **macOS**: standalone `frus.analytics` Window opened from `MainWindowView`.
/// - **iOS**: sheet presented from the Browse tab toolbar button.
///
/// ## Nil analytics service
/// When `appState.analyticsService` is `nil` (FTS5 database unavailable),
/// a `ContentUnavailableView` placeholder is shown instead.
///
/// Version history:
///   1.0 — Session 99: initial implementation
///   1.1 — Session 119: year-range filter controls; explicit x-axis domain
///          (1861 default); removed 20,000 result limit (see FTS5Store 1.3)
///   1.2 — Session 121: by-decade / by-month / by-day granularity options; year
///          axis labels rendered without comma grouping; user-toggleable fit
///          line; info popover explaining metric semantics
///   1.3 — Session 2026-06-07: two-way Search ↔ Analytics integration —
///          `init(initialParameters:)` seeds and auto-runs from a `pendingAnalytics`
///          handoff (Search's over-cap "Visualize in Corpus Analytics" suggestion);
///          `searchHandoffBar` lets the user jump from a committed term/year-range
///          straight to Search, pre-filled via `pendingSearch`
///   1.4 — Session 163: add the `byVolume` axis (per-volume breakdown) and make the
///          categorical By-Subseries / By-Volume charts and table rows tappable —
///          each opens Search scoped to that subseries/volume via
///          `openScopedDocumentsInSearch(volumeIds:)`
///   1.5 — Prep-B (analytics CA-track): year-range bar and chart/table mode picker
///          extracted into reusable `AnalyticsYearRangeBar` / `AnalyticsViewModePicker`
///          chrome components (behavior-preserving; no user-facing change)
///   1.6 — CA-4 (analytics CA-track): "% of documents" normalization toggle for the
///          date-based By-Year / By-Decade charts — plots each period's matches as a
///          share of all indexed documents in that period (scoped denominator, zero-
///          total guard), persisted per-user via `@AppStorage`; raw mode unchanged
///   1.7 — CA-4 review fix: `valueAxisMarks` raw path emits a default `AxisValueLabel()`
///          so raw-mode By-Year/By-Decade Y labels keep Swift Charts' framework-default
///          thousands grouping ("4,187"), restoring byte-for-byte parity with the
///          pre-CA-4 axis instead of the no-grouping integer format
struct AnalyticsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneID) private var sceneID
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #if os(macOS)
    /// Opens the Search window directly for the View-in-Search hand-offs (the
    /// MainWindowView relay is retired — provenance PR 2).
    @Environment(\.openWindow) private var openWindow
    #endif

    // MARK: - State

    @State private var termInput: String = ""

    /// Whether the term field holds first responder. Written **only** to `false`
    /// (``addTerm()``) — see ``termField`` for why that restriction is what makes a single
    /// binding safe across the two `ViewThatFits` instantiations.
    @FocusState private var isTermFieldFocused: Bool

    /// The committed comparison terms, in chip order — the source of both iteration order and the
    /// per-term color index (D1). Phase 1 keeps this at 0 or 1 element (a Search press replaces it);
    /// a later phase lets the user add up to five. The single-term `committedTerm` shim below feeds
    /// the existing call sites and chart headings unchanged.
    @State private var committedTerms: [String] = []
    /// Per-term By-Year data, keyed by the committed term (D1). Read through the `yearData` shim in
    /// single-term mode; the compare charts iterate all terms in a later phase.
    @State private var yearDataByTerm: [String: [YearFrequency]] = [:]
    /// Per-`(year, volume)` breakdown driving the source color-coding of the By-Year and By-Decade
    /// charts. Stays SINGLE (not per-term): source coloring is dropped while comparing, so this is
    /// fetched only for a single committed term.
    @State private var yearVolumeData: [YearVolumeFrequency] = []
    /// Per-term occurrence series (PR-D). Populated only for By Year / By Decade — the axes
    /// `measureApplies` admits — and only for query shapes with an honest occurrence count.
    @State private var occurrenceYearDataByTerm: [String: [YearFrequency]] = [:]
    /// Whether the committed query can be counted by occurrence, and if not, why. Fetched with the
    /// data so the notice and the picker's enablement agree with what was actually loaded.
    @State private var occurrenceAvailability: OccurrenceAvailability = .unavailable(reason: .noPositiveTerm)
    @State private var decadeDataByTerm: [String: [DecadeFrequency]] = [:]
    @State private var monthDataByTerm: [String: [MonthFrequency]] = [:]
    @State private var dayDataByTerm: [String: [DayFrequency]] = [:]
    @State private var subseriesDataByTerm: [String: [SubseriesFrequency]] = [:]
    @State private var volumeDataByTerm: [String: [VolumeFrequency]] = [:]
    /// Monotonic token that discards a stale `reloadData` run when the term set changes mid-fetch (D1).
    @State private var fetchToken: Int = 0

    /// Saved and recent analytics queries (D1 Phase 3). Held per window in `@State`, loaded from and
    /// written back to `UserDefaults` as JSON (see `loadQueries()` / `persistQueries()`).
    @State private var savedQueries: [SavedAnalyticsQuery] = []
    @State private var recentQueries: [SavedAnalyticsQuery] = []

    /// The written export awaiting an iOS share sheet (D3); always `nil` on macOS, where the save
    /// panel writes straight to the user's chosen destination.
    @State private var exportShareItem: AnalyticsExportFile?
    /// A human-readable export failure, surfaced in an alert (the word-cloud exporter swallows these).
    @State private var exportError: String?
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var chartAxis: AnalyticsChartAxis = .byYear

    /// Start year for the chart x-axis and year-data filter. Defaults to 1861
    /// (the year of the first FRUS volume).
    /// The in-chart scrubber's live selection (#306), in the chart's own x units — calendar years
    /// on the By Year axis, decade *starts* on By Decade.
    ///
    /// Held separately from `yearRangeStart`/`yearRangeEnd` rather than bound to them directly:
    /// Swift Charts updates this continuously through a drag, and writing the year range on every
    /// frame would re-filter and re-render the series under the user's finger. It is committed
    /// once, when the drag ends.
    @State private var scrubSelection: ClosedRange<Int>?

    @State private var yearRangeStart: Int = 1861

    /// End year for the chart x-axis and year-data filter. Defaults to the
    /// current calendar year, re-evaluated at view construction.
    @State private var yearRangeEnd: Int = Calendar.current.component(.year, from: Date())

    /// Guards one-time seeding of `yearRangeEnd` from the corpus span on first
    /// appearance (see `seedDefaultYearRange()`).
    @State private var didSeedYearRange = false

    /// Optional volume-ID scope carried in from a `WordCloud → Analytics` handoff.
    /// When non-empty, every chart query is restricted to these volumes; `nil`
    /// means the whole indexed corpus (the default and only state for the
    /// toolbar-button presentation).
    @State private var scopeVolumeIds: [String]? = nil

    /// Human-readable label for `scopeVolumeIds` (a volume or subseries title),
    /// shown in the scope chip. `nil` when the query is corpus-wide.
    @State private var scopeLabel: String? = nil

    /// User preference: whether to overlay a smoothed trend line on date-bucketed
    /// charts. Defaults to true. Has no effect on the by-subseries horizontal
    /// bar chart, which never plots a line.
    @State private var showFitLine: Bool = true

    /// User preference (CA-4): whether the date-based charts plot raw matching-document
    /// counts or each period's matches as a **share of all indexed documents** in that
    /// period. Persisted per-user; defaults to `raw` (byte-for-byte the original
    /// behavior). Only consulted for the date-based By-Year / By-Decade axes.
    @AppStorage(AnalyticsNormalizationMode.storageKey) private var normalizationMode: AnalyticsNormalizationMode = .raw

    /// The normalization mode used **while comparing** (D1). Defaults to `.percentOfDocuments` so
    /// several terms are comparable regardless of absolute frequency, but the Raw/% toggle still
    /// drives it — kept separate from `normalizationMode` so the compare default never persists into
    /// the single-term `@AppStorage` preference.
    @State private var compareNormalizationMode: AnalyticsNormalizationMode = .percentOfDocuments

    /// Corpus document totals per year — the `% of documents` denominator (CA-4),
    /// fetched (scoped to `scopeVolumeIds`) alongside the term data in `runSearch()`.
    @State private var documentTotalsByYear: [Int: Int] = [:]

    /// Corpus document totals per decade bucket — the By-Decade `% of documents`
    /// denominator (CA-4). Fetched alongside `documentTotalsByYear`.
    @State private var documentTotalsByDecade: [Int: Int] = [:]

    /// Global default colored-series count, mirrored from Display settings.
    @AppStorage(ChartSeriesPalette.storageKey) private var defaultSeriesCount = ChartSeriesPalette.defaultCount
    /// Per-view colored-series count, seeded from the global default; overrides it for
    /// this session via the chart-colors menu.
    @State private var seriesCount = ChartSeriesPalette.defaultCount

    /// Parameters this view was opened with — e.g. from `SearchView`'s "Visualize
    /// in Corpus Analytics" handoff when a search hits `searchHardLimit`. Applied
    /// once on appearance via `seedFromInitialParameters()`. `nil` for the normal
    /// toolbar-button / menu-command presentation paths.
    private let initialParameters: AnalyticsParameters?

    // MARK: - Single-term shims (D1)

    /// The primary committed term (first chip) or `""` — the single-term value behind the existing
    /// `.isEmpty` gates and chart headings, so they keep working unchanged while storage moved to
    /// `committedTerms`. Empty exactly when nothing is committed.
    private var committedTerm: String { committedTerms.first ?? "" }
    /// The primary term's per-axis data — the single-term view the existing chart code reads. The
    /// compare charts (a later phase) read the `*DataByTerm` dictionaries directly.
    private var yearData: [YearFrequency] { yearSeries(for: committedTerm) }
    private var decadeData: [DecadeFrequency] { decadeSeries(for: committedTerm) }

    /// The By-Year series for `term` in the active unit.
    ///
    /// Every chart, table, footnote and export reads its data through here and its decade sibling, so
    /// switching measure cannot leave one surface plotting documents while another plots occurrences.
    private func yearSeries(for term: String) -> [YearFrequency] {
        valueUnit == .occurrences
            ? (occurrenceYearDataByTerm[term] ?? [])
            : (yearDataByTerm[term] ?? [])
    }

    /// The By-Decade series for `term` in the active unit.
    ///
    /// Occurrences are bucketed from the year series rather than fetched: a decade is the sum of its
    /// years, so a second query would cost latency for a number arithmetic already has — and any
    /// disagreement between the two would be a bug with no way to tell which side was wrong.
    private func decadeSeries(for term: String) -> [DecadeFrequency] {
        guard valueUnit == .occurrences else { return decadeDataByTerm[term] ?? [] }
        var byDecade: [Int: Int] = [:]
        for entry in occurrenceYearDataByTerm[term] ?? [] {
            byDecade[(entry.year / 10) * 10, default: 0] += entry.count
        }
        return byDecade
            .map { DecadeFrequency(decadeStart: $0.key, count: $0.value) }
            .sorted { $0.decadeStart < $1.decadeStart }
    }
    private var monthData: [MonthFrequency] { monthDataByTerm[committedTerm] ?? [] }
    private var dayData: [DayFrequency] { dayDataByTerm[committedTerm] ?? [] }
    private var subseriesData: [SubseriesFrequency] { subseriesDataByTerm[committedTerm] ?? [] }
    private var volumeData: [VolumeFrequency] { volumeDataByTerm[committedTerm] ?? [] }

    // MARK: - Initialisation

    /// Creates the analytics view, optionally pre-seeded with a term and year
    /// range carried over from another view (currently: Search's over-cap
    /// handoff — see `AnalyticsParameters`).
    ///
    /// - Parameter initialParameters: When non-nil, `termInput`/`committedTerm`
    ///   and the year-range bounds are seeded from it and a search is run
    ///   automatically as soon as the view appears, so the chart is already
    ///   populated — mirroring how `SearchView(initialParameters:)` immediately
    ///   reflects a `pendingSearch` handoff.
    init(initialParameters: AnalyticsParameters? = nil) {
        self.initialParameters = initialParameters
    }

    // MARK: - Derived Properties

    /// Most recent year covered by the known FRUS corpus, used as the default
    /// upper bound and stepper maximum. Derived from the manifest's volume span
    /// (typically 1992/1993) rather than the calendar year, since no published
    /// FRUS volume includes documents past the most recent published volume —
    /// defaulting to the current year would leave an empty tail on the chart.
    private var corpusMaxYear: Int {
        Calendar(identifier: .gregorian)
            .component(.year, from: appState.manifestStore.corpusDateRange.upperBound)
    }

    /// `yearData` filtered to `yearRangeStart...yearRangeEnd`.
    ///
    /// Filtering is applied at display time so no re-query is needed when the
    /// range changes.
    private var filteredYearData: [YearFrequency] {
        guard !yearData.isEmpty else { return [] }
        return yearData.filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
    }

    /// `decadeData` filtered to ten-year buckets that intersect `yearRangeStart`...`yearRangeEnd`.
    /// A decade is included if any of its years falls inside the range.
    private var filteredDecadeData: [DecadeFrequency] {
        guard !decadeData.isEmpty else { return [] }
        return decadeData.filter { d in
            let bucketEnd = d.decadeStart + 9
            return bucketEnd >= yearRangeStart && d.decadeStart <= yearRangeEnd
        }
    }

    /// `monthData` filtered to entries whose year falls within `yearRangeStart`...`yearRangeEnd`.
    private var filteredMonthData: [MonthFrequency] {
        guard !monthData.isEmpty else { return [] }
        let cal = Calendar(identifier: .gregorian)
        return monthData.filter { m in
            let y = cal.component(.year, from: m.date)
            return y >= yearRangeStart && y <= yearRangeEnd
        }
    }

    /// `dayData` filtered to entries whose year falls within `yearRangeStart`...`yearRangeEnd`.
    private var filteredDayData: [DayFrequency] {
        guard !dayData.isEmpty else { return [] }
        let cal = Calendar(identifier: .gregorian)
        return dayData.filter { d in
            let y = cal.component(.year, from: d.date)
            return y >= yearRangeStart && y <= yearRangeEnd
        }
    }

    /// `true` when the user has narrowed the range away from its default values.
    private var yearRangeIsCustom: Bool {
        yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear
    }

    /// `true` when the normalization toggle applies to the active axis — the date-based
    /// By-Year / By-Decade axes, which have a per-period corpus denominator. The
    /// categorical and sub-year axes (month / day / subseries / volume) have no
    /// meaningful per-period corpus total, so the toggle is hidden and ignored for them
    /// (CA-4 is scoped to Year + Decade).
    private var normalizationApplies: Bool {
        chartAxis == .byYear || chartAxis == .byDecade
    }

    /// `true` when normalized (`% of documents`) plotting is active for the current axis — the
    /// effective preference is on AND the axis supports it. While comparing, the effective mode is
    /// `compareNormalizationMode` (default %) rather than the persisted single-term preference.
    /// `true` when normalized (`% of documents`) plotting is active — the preference is on, the axis
    /// supports it, **and** a chart is what is on screen.
    ///
    /// The `viewMode` term is load-bearing and was missing. Table mode renders raw counts
    /// unconditionally (`tableRow` prints the integer), while the toolbar picker was merely
    /// `.disabled` — so a greyed-out "% of documents" sat above a column of raw counts, and
    /// `exportProvenance` stamped the exported CSV "% of documents" while `exportTable` wrote those
    /// same raw counts. Coupling it here fixes the screen, the provenance and the export together,
    /// because all three read this one property.
    private var isNormalized: Bool {
        // `valueUnit == .documents` is load-bearing, not defensive. `normalizedValue` divides by the
        // period's DOCUMENT total and every consumer calls the result a percentage; occurrences
        // divided by documents is a rate that runs freely past 100% and is not a share of anything.
        // So the combination is made unreachable here rather than clamped or relabelled later — and
        // the Measure picker is what the researcher reaches for, so occurrences win and the share
        // mode yields.
        normalizationApplies && viewMode == .chart && valueUnit == .documents
            && effectiveNormalizationMode == .percentOfDocuments
    }

    /// `=word` operands the analytics service refuses to chart, for the term(s) currently committed.
    ///
    /// Non-empty means the frequency functions returned nothing **by design** — see
    /// `CorpusAnalyticsService.makeQuery(from:)`. Checked before the No-Results branch so the state
    /// explains itself; a bare "No Results" would tell the researcher their word never appears when
    /// in fact it appears and Analytics simply cannot count it exactly.
    private var unsupportedExactTerms: [String] {
        let terms = isComparing ? committedTerms : (committedTerm.isEmpty ? [] : [committedTerm])
        var seen: Set<String> = []
        return terms
            .flatMap { CorpusAnalyticsService.unsupportedExactTerms(in: $0) }
            .filter { seen.insert($0).inserted }
    }

    // MARK: - Compare terms (D1)

    /// The maximum number of terms compared at once (owner decision: 5, matching Person Analytics and
    /// staying under the palette's 6-color floor so series colors never wrap).
    private static let maxCompareTerms = 5

    /// `true` once two or more terms are committed — the compare charts (per-term line marks) replace
    /// the single-term source-colored bars.
    private var isComparing: Bool { committedTerms.count >= 2 }

    /// `true` when the committed set has reached `maxCompareTerms` (disables the add affordance).
    private var atCompareCap: Bool { committedTerms.count >= Self.maxCompareTerms }

    /// The palette color for a term's series — its chip-order index into the shared palette.
    private func termColor(_ term: String) -> Color {
        ChartSeriesPalette.color(at: max(0, committedTerms.firstIndex(of: term) ?? 0))
    }

    /// The normalization mode actually in effect: `compareNormalizationMode` while comparing, the
    /// persisted `normalizationMode` otherwise.
    private var effectiveNormalizationMode: AnalyticsNormalizationMode {
        isComparing ? compareNormalizationMode : normalizationMode
    }

    /// Binding for the Raw/% picker that routes to the compare mode while comparing (so the toggle
    /// stays live without persisting the compare default into the single-term `@AppStorage`).
    private var normalizationBinding: Binding<AnalyticsNormalizationMode> {
        Binding(
            get: { isComparing ? compareNormalizationMode : normalizationMode },
            set: { newValue in
                if isComparing { compareNormalizationMode = newValue } else { normalizationMode = newValue }
            }
        )
    }

    /// The per-term color scale for the compare charts — domain = committed terms (chip order),
    /// range = the palette colors at those indices.
    private var compareColorScale: (domain: [String], range: [Color]) {
        (committedTerms, committedTerms.indices.map { ChartSeriesPalette.color(at: $0) })
    }

    /// The chart heading's quoted term(s): `"term"` for one, `"a", "b"` for a comparison.
    private var chartHeadingTerms: String {
        committedTerms.map { "\"\($0)\"" }.joined(separator: ", ")
    }

    /// One committed term's By-Year data, filtered to the active year range.
    private func filteredYearData(for term: String) -> [YearFrequency] {
        yearSeries(for: term).filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
    }
    /// One committed term's By-Decade data, filtered to decades intersecting the active range.
    private func filteredDecadeData(for term: String) -> [DecadeFrequency] {
        decadeSeries(for: term).filter { $0.decadeStart + 9 >= yearRangeStart && $0.decadeStart <= yearRangeEnd }
    }
    /// One committed term's By-Month data, filtered to the active year range.
    private func filteredMonthData(for term: String) -> [MonthFrequency] {
        let cal = Calendar(identifier: .gregorian)
        return (monthDataByTerm[term] ?? []).filter {
            let y = cal.component(.year, from: $0.date); return y >= yearRangeStart && y <= yearRangeEnd
        }
    }
    /// One committed term's By-Day data, filtered to the active year range.
    private func filteredDayData(for term: String) -> [DayFrequency] {
        let cal = Calendar(identifier: .gregorian)
        return (dayDataByTerm[term] ?? []).filter {
            let y = cal.component(.year, from: $0.date); return y >= yearRangeStart && y <= yearRangeEnd
        }
    }

    /// Appends the live `termInput` as a comparison term (Return / ＋): trims, de-dups
    /// case-insensitively, enforces `maxCompareTerms`, clears the field, and reloads.
    private func addTerm() {
        let term = termInput.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !atCompareCap else { return }
        guard !committedTerms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else {
            termInput = ""
            return
        }
        committedTerms.append(term)
        termInput = ""
        #if os(iOS)
        // #559: the term is committed, so the field's work is done — give the screen back. Left up,
        // the keyboard covers the chart it was typed to produce, and in landscape it covers
        // essentially all of it, with no way down: this view has no Done bar and nothing else here
        // resigns first responder.
        //
        // iOS only. On macOS the Return key committing a term and *keeping* focus is what lets a
        // second term be typed without reaching for the mouse, so resigning there would be a
        // regression rather than a fix.
        isTermFieldFocused = false
        #endif
        // A categorical axis can't compare (owner decision A) — fall back to By-Year on the 2nd term.
        if isComparing && chartAxis.isCategorical { chartAxis = .byYear }
        reloadData()
    }

    /// Removes a comparison term (chip ✕) and reloads (or clears when the last term goes).
    private func removeTerm(_ term: String) {
        committedTerms.removeAll { $0 == term }
        reloadData()
    }

    // MARK: - Saved & recent queries (D1 Phase 3)

    private static let maxRecentQueries = 10
    private static let savedQueriesKey = "frus.analytics.savedQueries"
    private static let recentQueriesKey = "frus.analytics.recentQueries"

    /// A snapshot of the current committed query (terms · axis · range · scope).
    private func currentQuery() -> SavedAnalyticsQuery {
        SavedAnalyticsQuery(id: UUID(), terms: committedTerms, axis: chartAxis,
                            yearStart: yearRangeStart, yearEnd: yearRangeEnd,
                            scopeVolumeIds: scopeVolumeIds, scopeLabel: scopeLabel, savedAt: Date(),
                            // The PREFERENCE, not the effective unit: restoring must reinstate what
                            // the researcher asked for. `valueUnit` falls back to documents on an axis
                            // or query that cannot serve occurrences, and saving that fallback would
                            // quietly demote the query for every later restore.
                            valueUnit: storedValueUnit)
    }

    /// `true` when the current query is already in the saved list (drives the star's filled state).
    private var isCurrentQuerySaved: Bool {
        guard !committedTerms.isEmpty else { return false }
        let q = currentQuery()
        return savedQueries.contains { $0.matchesQuery(q) }
    }

    /// Stars / un-stars the current query.
    ///
    /// Re-reads the stored list first so a concurrent Analytics window's saves survive: these lists
    /// live in per-window `@State` over one shared `UserDefaults` key, so writing this window's
    /// (possibly stale) copy wholesale would silently drop the other window's entries (review fix).
    private func toggleSaveCurrentQuery() {
        guard !committedTerms.isEmpty else { return }
        let q = currentQuery()
        var merged = storedQueries(forKey: Self.savedQueriesKey)
        if let idx = merged.firstIndex(where: { $0.matchesQuery(q) }) {
            merged.remove(at: idx)
        } else {
            merged.insert(q, at: 0)
        }
        savedQueries = merged
        persist(merged, forKey: Self.savedQueriesKey)
    }

    /// Records the current committed query as the most-recent (de-duplicated, capped). Called from
    /// `reloadData` on each committed search. Re-reads the stored list first (see
    /// `toggleSaveCurrentQuery`) and writes ONLY the recents key, so recording a recent can never
    /// clobber another window's saved queries.
    private func recordRecentQuery() {
        guard !committedTerms.isEmpty else { return }
        let q = currentQuery()
        var merged = storedQueries(forKey: Self.recentQueriesKey)
        merged.removeAll { $0.matchesQuery(q) }
        merged.insert(q, at: 0)
        if merged.count > Self.maxRecentQueries {
            merged = Array(merged.prefix(Self.maxRecentQueries))
        }
        recentQueries = merged
        persist(merged, forKey: Self.recentQueriesKey)
    }

    /// Restores a saved/recent query — terms, axis, year range, and scope together — then re-runs.
    private func restoreQuery(_ q: SavedAnalyticsQuery) {
        committedTerms = q.terms
        chartAxis = q.axis
        yearRangeStart = q.yearStart
        yearRangeEnd = q.yearEnd
        scopeVolumeIds = (q.scopeVolumeIds?.isEmpty == true) ? nil : q.scopeVolumeIds
        scopeLabel = scopeVolumeIds == nil ? nil : q.scopeLabel
        storedValueUnit = q.valueUnit ?? .documents
        termInput = ""
        reloadData()
    }

    /// Loads saved + recent queries from `UserDefaults` (JSON). Called once on appearance. A
    /// concurrent window's later changes are not observed here, but they are never *lost*: both
    /// mutators re-read the stored list before writing, so this window's list is at worst visually
    /// stale until it is next mounted.
    private func loadQueries() {
        savedQueries = storedQueries(forKey: Self.savedQueriesKey)
        recentQueries = storedQueries(forKey: Self.recentQueriesKey)
    }

    /// The queries currently stored under `key`, or `[]` when absent/undecodable (a decode failure —
    /// e.g. data written by a future schema — degrades to an empty list rather than throwing).
    private func storedQueries(forKey key: String) -> [SavedAnalyticsQuery] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let queries = try? JSONDecoder().decode([SavedAnalyticsQuery].self, from: data) else {
            return []
        }
        return queries
    }

    /// Writes one query list back to `UserDefaults` as JSON (plain data, NOT a `RawRepresentable`
    /// `@AppStorage`, which crashes when `rawValue` re-encodes `self`). Each list is written under
    /// its own key so one list's update never rewrites the other.
    private func persist(_ queries: [SavedAnalyticsQuery], forKey key: String) {
        guard let data = try? JSONEncoder().encode(queries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Research-grade export (D3)

    /// The methods statement stamped onto this chart's export — what was counted, over which corpus,
    /// with which value mode, plus the caveats the view shows on screen only conditionally.
    private var exportProvenance: AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: exportFigureTitle,
            terms: committedTerms,
            axisLabel: chartAxis.pickerLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: appState.indexedVolumeIds.count,
            // The categorical breakdowns ignore the range entirely — say so rather than implying it applied.
            yearRange: chartAxis.isCategorical ? nil : yearRangeStart...yearRangeEnd,
            // `isNormalized`, not `normalizationApplies && mode`: exporting from TABLE mode writes
            // raw counts, and this line is the methods block that claims what they are. The two must
            // read the same property or the CSV documents a normalisation it does not contain.
            valueMode: normalizationApplies
                ? (isNormalized ? effectiveNormalizationMode.pickerLabel
                                : AnalyticsNormalizationMode.raw.pickerLabel)
                : nil,
            // The EFFECTIVE unit, not the preference: this describes the numbers in the file. A
            // figure exported from an axis that cannot serve occurrences contains document counts,
            // whatever the picker still says.
            countingUnit: valueUnit.axisLabel
        )
    }

    /// The export's figure title — the quoted term(s) and the active grouping, matching the heading
    /// shown above the chart.
    private var exportFigureTitle: String {
        "\(chartHeadingTerms) — \(chartAxis.pickerLabel)"
    }

    /// The data table behind the active chart (D3), or `nil` when nothing is committed.
    ///
    /// Built for every committed term, so a D1 comparison exports the same shape as a single term.
    private var exportTable: ChartInspectorData? {
        guard !committedTerms.isEmpty else { return nil }
        let dayFormat = Date.FormatStyle(date: .numeric, time: .omitted)
        let series: [(term: String, points: [CorpusSeriesPoint])] = committedTerms.map { term in
            let points: [CorpusSeriesPoint]
            switch chartAxis {
            case .byYear:
                points = filteredYearData(for: term).map {
                    CorpusSeriesPoint(periodLabel: "\($0.year)", denominatorKey: $0.year, count: $0.count)
                }
            case .byDecade:
                points = filteredDecadeData(for: term).map {
                    CorpusSeriesPoint(periodLabel: "\($0.decadeStart)s", denominatorKey: $0.decadeStart, count: $0.count)
                }
            case .byMonth:
                points = filteredMonthData(for: term).map {
                    CorpusSeriesPoint(periodLabel: $0.label, denominatorKey: nil, count: $0.count)
                }
            case .byDay:
                points = filteredDayData(for: term).map {
                    CorpusSeriesPoint(periodLabel: $0.date.formatted(dayFormat), denominatorKey: nil, count: $0.count)
                }
            case .bySubseries:
                points = (subseriesDataByTerm[term] ?? []).map {
                    CorpusSeriesPoint(periodLabel: $0.subseries, denominatorKey: nil, count: $0.count)
                }
            case .byVolume:
                points = (volumeDataByTerm[term] ?? []).map {
                    CorpusSeriesPoint(periodLabel: volumeTitle($0.volumeId), denominatorKey: nil, count: $0.count)
                }
            }
            return (term: term, points: points)
        }
        let totals: [Int: Int]
        switch chartAxis {
        case .byYear:   totals = documentTotalsByYear
        case .byDecade: totals = documentTotalsByDecade
        default:        totals = [:]
        }
        return AnalyticsChartTables.corpusSeriesTable(
            id: "corpus.\(chartAxis.rawValue)",
            title: exportFigureTitle,
            periodColumn: exportPeriodColumn,
            seriesByTerm: series,
            totals: totals,
            isNormalized: isNormalized,
            // Passed explicitly rather than left to the default, so the exported table's unit is
            // the one this view plotted — the two cannot drift apart silently.
            unit: valueUnit
        )
    }

    /// The period column's header for the active axis.
    private var exportPeriodColumn: String {
        switch chartAxis {
        case .byYear:      return String(localized: "analytics.axis.year", defaultValue: "Year")
        case .byDecade:    return String(localized: "analytics.axis.decade", defaultValue: "Decade")
        case .byMonth:     return String(localized: "analytics.axis.month", defaultValue: "Month")
        case .byDay:       return String(localized: "analytics.axis.date", defaultValue: "Date")
        case .bySubseries: return String(localized: "analytics.axis.subseries", defaultValue: "Subseries")
        case .byVolume:    return String(localized: "analytics.axis.volume", defaultValue: "Volume")
        }
    }

    /// `true` when there is committed data to export.
    private var canExport: Bool {
        !committedTerms.isEmpty && !isAllResultDataEmpty
    }

    /// `true` when the active axis can be rendered as a figure (D3 Phase 1 covers the date axes; the
    /// categorical breakdowns and the heat matrix follow).
    private var canExportFigure: Bool {
        canExport && chartAxis.isDateBased
    }

    /// The chart drawn onto an exported figure — the SAME builders the screen uses, with every label
    /// pre-resolved here (exported content is environment-detached and cannot reach `appState`).
    @ViewBuilder
    private var exportFigureChart: some View {
        let xLabel = exportPeriodColumn
        if isComparing {
            switch chartAxis {
            case .byYear, .byDecade:
                compareIntChart(
                    seriesByTerm: committedTerms.map { term in
                        chartAxis == .byYear
                            ? (term: term, points: filteredYearData(for: term).map { (period: $0.year, count: $0.count) })
                            : (term: term, points: filteredDecadeData(for: term).map { (period: $0.decadeStart, count: $0.count) })
                    },
                    xLabel: xLabel,
                    xDomain: yearRangeStart...yearRangeEnd,
                    totals: chartAxis == .byYear ? documentTotalsByYear : documentTotalsByDecade,
                    decadeStride: chartAxis == .byDecade
                )
            default:
                compareDateChart(
                    seriesByTerm: committedTerms.map { term in
                        chartAxis == .byMonth
                            ? (term: term, points: filteredMonthData(for: term).map { (date: $0.date, count: $0.count) })
                            : (term: term, points: filteredDayData(for: term).map { (date: $0.date, count: $0.count) })
                    },
                    xLabel: xLabel,
                    xDomain: exportDateDomain
                )
            }
        } else {
            switch chartAxis {
            case .byYear, .byDecade:
                let raw: [(period: Int, volumeId: String, count: Int)] = chartAxis == .byYear
                    ? yearVolumeData.filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
                        .map { (period: $0.year, volumeId: $0.volumeId, count: $0.count) }
                    : yearVolumeData.compactMap {
                        let decade = ($0.year / 10) * 10
                        guard decade + 9 >= yearRangeStart && decade <= yearRangeEnd else { return nil }
                        return (period: decade, volumeId: $0.volumeId, count: $0.count)
                    }
                let coloring = sourceColoring(raw)
                let titles = resolvedSourceTitles(coloring.series)
                VStack(alignment: .leading, spacing: 10) {
                    // The chart hides Swift Charts' legend, so the figure must carry the color key
                    // itself or its colored segments mean nothing to a reader.
                    if !coloring.series.isEmpty {
                        figureSourceLegend(coloring.series, titles: titles)
                    }
                    singleTermDateChart(
                        segments: coloring.segments,
                        scale: sourceScale(coloring.series),
                        fitPoints: chartAxis == .byYear
                            ? filteredYearData.map { (period: $0.year, count: $0.count) }
                            : filteredDecadeData.map { (period: $0.decadeStart, count: $0.count) },
                        totals: chartAxis == .byYear ? documentTotalsByYear : documentTotalsByDecade,
                        xLabel: xLabel,
                        sourceTitles: titles,
                        decadeStride: chartAxis == .byDecade,
                        showsFitLine: showFitLine
                    )
                }
            default:
                // Month/Day single-term: one series, so the compare builder renders it identically
                // without the per-volume coloring those axes never had.
                compareDateChart(
                    seriesByTerm: [(term: committedTerm,
                                    points: (chartAxis == .byMonth
                                             ? filteredMonthData.map { (date: $0.date, count: $0.count) }
                                             : filteredDayData.map { (date: $0.date, count: $0.count) }))],
                    xLabel: xLabel,
                    xDomain: exportDateDomain
                )
            }
        }
    }

    /// The date domain for the Month/Day figures, matching the on-screen charts.
    private var exportDateDomain: ClosedRange<Date> {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: yearRangeStart, month: 1, day: 1)) ?? .distantPast
        let end = cal.date(from: DateComponents(year: yearRangeEnd, month: 12, day: 31)) ?? .distantFuture
        return start...end
    }

    /// Renders the active chart as a publication figure and shares (iOS) or saves (macOS).
    ///
    /// - Parameter format: PNG or PDF.
    private func exportFigure(_ format: AnalyticsFigureFormat) {
        guard canExportFigure else { return }
        let provenance = exportProvenance
        let canvas = AnalyticsFigureCanvas(provenance: provenance) { exportFigureChart }
        guard let data = AnalyticsFigureExporter.render(canvas, format: format) else {
            exportError = String(localized: "analytics.export.error.render",
                                 defaultValue: "The figure could not be rendered.")
            return
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle)
            + "." + format.pathExtension
        switch AnalyticsExportDelivery.deliver(data: data, filename: filename, contentType: format.contentType) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// Writes the active chart's provenance-stamped CSV, then shares (iOS) or saves (macOS).
    private func exportCSV() {
        guard let table = exportTable else { return }
        let filename = AnalyticsExportDelivery.filenameStem(title: exportFigureTitle) + ".csv"
        switch AnalyticsExportDelivery.deliver(text: table.provenancedCSV(exportProvenance), filename: filename) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// `true` on a compact-width layout (iPhone portrait, and most iPhones in
    /// landscape) — used to tighten the year-range bar where horizontal space is scarce.
    /// Always `false` on macOS / regular-width iPad.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// `true` in iPhone portrait (compact width + regular height), where rotating to
    /// landscape gives the chart noticeably more room. Drives the landscape hint.
    private var showsLandscapeHint: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.analyticsService == nil {
                    unavailablePlaceholder
                } else {
                    // #559, the other half: committing a term resigns focus, but a user who
                    // typed and then changed their mind needs a way down too. Dragging the chart
                    // area dismisses interactively. Available on macOS since 13 and inert there,
                    // so no `#if` — a Mac has no software keyboard to dismiss.
                    VStack(spacing: 0) {
                        // D1: the comparison-term chips sit above the consolidated filter row.
                        termChipsRow
                        // Wave B: one consolidated filter row (term + scope / range / group-by chips)
                        // replaces the four stacked bars, so the chart lands above the fold.
                        filterRow
                        if chartAxis.isCategorical && !committedTerm.isEmpty {
                            categoricalYearNote
                        }
                        Divider()
                        // Hide the hand-off link when there's nothing to view — during the async fetch
                        // (data arrays momentarily empty) or a genuine zero-match term (Win 3) — and
                        // while comparing (owner decision C): a per-term overlay has no single
                        // "these documents" population to drill into.
                        if !isComparing && !committedTerm.isEmpty && matchedDocumentCount > 0 {
                            searchHandoffBar
                            Divider()
                        }
                        if showsLandscapeHint && !committedTerm.isEmpty && viewMode == .chart {
                            landscapeHint
                        }
                        // Fill the space below the filter row so the VStack takes the whole
                        // window/sheet height and `filterRow` pins to the top. Without this the
                        // VStack shrink-wraps and the macOS window centers it — floating the term
                        // field mid-window (Wave B made this prominent: one compact row replaced the
                        // four tall bars that used to mask the missing greedy frame).
                        contentArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            // iOS omits the nav title so the full nav-bar width goes to the trailing analytics
            // controls, which otherwise crowd/truncate against a centered title on narrow iPhones
            // (#219). The accessible screen name is preserved by naming the content container
            // (children: .contain keeps the chart/table/toolbar elements individually navigable).
            // macOS keeps the title for its window title bar.
            #if os(macOS)
            .navigationTitle(
                String(localized: "analytics.title", defaultValue: "Corpus Analytics")
            )
            #else
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "analytics.title", defaultValue: "Corpus Analytics"))
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
        // D3: anchored on the outermost view (not the inner `Group`, which would apply the
        // presentation per child — see the Group-modifier gotcha).
        .sheet(item: $exportShareItem) { item in
            AnalyticsExportShareSheet(item: item)
        }
        .alert(String(localized: "analytics.export.error.title", defaultValue: "Export Failed"),
               isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        // Seed the default year-range end from the corpus span, then apply any
        // constructor parameter (iOS sheet presentation — a fresh `AnalyticsView`
        // instance is created each time the sheet opens).
        .task {
            seriesCount = defaultSeriesCount
            loadQueries()   // D1 Phase 3: saved + recent queries
            seedDefaultYearRange()
            applyAnalyticsParameters(initialParameters)
            #if os(macOS)
            // A FRESH macOS `frus.analytics` window is created AFTER the producer set
            // `pendingAnalytics` and opened it directly (relay elimination, PR 2). `initialParameters`
            // is always nil on macOS (the scene mounts `AnalyticsView()`), and the `.onChange` below
            // never fires for a value set BEFORE this view subscribed — so drain the hand-off here on
            // first open, mirroring `MacSearchWindowView`/`WordCloudWindowContent`. Without this the
            // window opens on the empty "enter a term" state and the term/date-range are lost.
            if let pending = appState.consumeHandoff(\.pendingAnalytics, for: .macAnalytics) {
                applyAnalyticsParameters(pending)
            }
            #endif
        }
        // Re-seed when a new handoff arrives while the view is already on screen
        // (macOS `frus.analytics` Window — a long-lived instance reused across
        // openWindow calls). `MainWindowView` opens the window; this clears the
        // pending value once consumed, mirroring `MacSearchWindowView`'s
        // `pendingSearch` handling.
        // Re-seed when a new hand-off arrives while a window is already open. macOS `frus.analytics`
        // is a long-lived singleton (`.macAnalytics`); iOS seeds via `initialParameters` (BrowserView),
        // so on iOS this consumes nothing (the hand-off targets the producing window, not `.macAnalytics`).
        // Switching to Occurrences after a documents-mode search has to fetch the series that
        // search deliberately skipped — and it re-runs `reloadData()` to do it, rather than a
        // second fetch path of its own.
        //
        // That is the whole design, and it was learned the hard way: a dedicated lazy loader had to
        // own a second in-flight flag and a second producer against `fetchToken`, and an adversarial
        // review found four user-reachable failures in it, including a one-click deterministic wedge
        // (restore a saved Occurrences query -> the trigger steals the token from the reload that
        // just started -> every document series discarded and the spinner never clears). One
        // producer, one token, one flag is worth re-running six cached document queries for.
        //
        // No axis trigger is needed: `reloadData()`'s gate reads the PREFERENCE, not
        // `measureApplies`, so a search made on any axis with Occurrences selected already fetched
        // the series.
        .onChange(of: storedValueUnit) { _, _ in
            guard storedValueUnit == .occurrences, committedTerms.count == 1,
                  let term = committedTerms.first,
                  occurrenceYearDataByTerm[term] == nil else { return }
            reloadData()
        }
        .onChange(of: appState.pendingAnalytics) { _, _ in
            guard let params = appState.consumeHandoff(\.pendingAnalytics, for: .macAnalytics) else { return }
            applyAnalyticsParameters(params)
        }
    }

    // MARK: - Cross-View Handoff (Search ↔ Analytics)

    /// Applies a `Search → Analytics` handoff: seeds the term and (if present)
    /// the year-range bounds, then runs the chart query immediately so the user
    /// lands on a populated chart rather than an empty "enter a term" prompt.
    /// Seeds `yearRangeEnd` to the most recent corpus year on first appearance.
    /// The `@State` initialiser can't read `appState`, so the field starts at a
    /// placeholder and is corrected here once. Runs at most once per view
    /// lifetime so it never clobbers a range the user has since adjusted.
    private func seedDefaultYearRange() {
        guard !didSeedYearRange else { return }
        didSeedYearRange = true
        yearRangeEnd = corpusMaxYear
    }

    private func applyAnalyticsParameters(_ params: AnalyticsParameters?) {
        guard let params else { return }
        let term = params.term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        termInput = term
        if let start = params.yearRangeStart { yearRangeStart = start }
        if let end = params.yearRangeEnd { yearRangeEnd = end }
        // Always assign the scope (including nil) so a later corpus-wide handoff
        // clears a scope left over from a previous one on the long-lived macOS window.
        scopeVolumeIds = (params.scopeVolumeIds?.isEmpty == true) ? nil : params.scopeVolumeIds
        scopeLabel = scopeVolumeIds == nil ? nil : params.scopeLabel
        runSearch()
    }

    /// Builds the `Analytics → Search` handoff parameters and switches to Search.
    ///
    /// Carries `committedTerm` over as `keywords` and — when the active axis is
    /// date-based — the current year-range bounds as a `DateRange` (January 1st
    /// of the start year through December 31st of the end year), so the search
    /// results the user lands on are the same documents the chart visualised.
    /// Mirrors the `pendingSearch` handoff used throughout the app (see
    /// `PersonIndexView`, `IndexingSummaryCard`, `MacDocumentView`).
    private func openMatchingDocumentsInSearch() {
        let range: DateRange? = chartAxis.isDateBased
            ? DateRange(
                earliest: String(format: "%04d-01-01", yearRangeStart),
                latest: String(format: "%04d-12-31", yearRangeEnd)
              )
            : nil
        // Carry the active volume scope through to Search so a Word Cloud → Analytics
        // → Search chain lands on the same documents the (scoped) chart visualised.
        appState.openSearch(SearchParameters(
            keywords: committedTerm, dateRange: range, volumeIds: scopeVolumeIds
        ), from: sceneID)
        #if DEBUG
        print("[AnalyticsView] Handoff to Search — term: \"\(committedTerm)\", dateRange: \(String(describing: range)), scopeVolumes: \(scopeVolumeIds?.count ?? 0)")
        #endif
        navigateToSearch()
    }

    /// Direction-A drill-in handoff: open Search scoped to a specific subseries or
    /// volume (the `volumeIds` of a single tapped bar/row), carrying the committed
    /// term along. Used by the tappable By-Subseries / By-Volume charts and tables so
    /// the researcher can go straight from "this subseries/volume has N matches" to
    /// the documents themselves. No date range is applied — these axes are not
    /// date-based.
    private func openScopedDocumentsInSearch(volumeIds: [String]) {
        guard !volumeIds.isEmpty else { return }
        appState.openSearch(SearchParameters(keywords: committedTerm, volumeIds: volumeIds), from: sceneID)
        #if DEBUG
        print("[AnalyticsView] Scoped handoff to Search — term: \"\(committedTerm)\", volumes: \(volumeIds.count)")
        #endif
        navigateToSearch()
    }

    /// Shared navigation tail for both handoff paths.
    ///
    /// On iOS, Analytics is a sheet over the Browse tab — switch to the Search tab
    /// (now pre-filled via `pendingSearch`) and dismiss the sheet. On macOS, Analytics
    /// is a standalone `frus.analytics` Window; the Search window is opened DIRECTLY
    /// (the MainWindowView relay is retired — provenance PR 2) and inherits this
    /// analytics window's provenance, while the analytics window stays open for
    /// side-by-side comparison.
    private func navigateToSearch() {
        #if os(macOS)
        appState.bindTool(.search, to: appState.provenance(of: .analytics))
        openWindow.fronting(id: "frus.search")
        #else
        appState.openTab(.search, from: sceneID)
        dismiss()
        #endif
    }

    /// Resolves the indexed volume IDs belonging to a subseries label, using the same
    /// parsing the chart itself used to bucket documents (`CorpusAnalyticsService
    /// .subseries(fromVolumeId:)`) so the handoff scope matches the bar exactly.
    private func indexedVolumeIds(forSubseries subseries: String) -> [String] {
        appState.indexedVolumeIds
            .filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }
            .sorted()
    }

    /// Human-readable title for a volume ID, resolved from the manifest. Falls back
    /// to the raw volume ID when the manifest has no entry.
    private func volumeTitle(_ volumeId: String) -> String {
        appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    // The scope selector is now the filter row's `scopeChip` (Wave B).

    /// Subtle one-line hint, shown only in iPhone portrait, that rotating the device
    /// widens the chart. Non-modal; disappears in landscape and on iPad / macOS.
    private var landscapeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "rotate.right")
            Text(String(localized: "analytics.landscapeHint",
                        defaultValue: "Rotate to landscape for a wider chart"))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    // The year-range control and administration presets are now the filter row's `yearChip` /
    // `adminPresetChip` (Wave B).

    // MARK: - Search Handoff Bar

    /// Direction-A handoff affordance: "Analytics → Search".
    ///
    /// Shown beneath the search/year-range bars whenever a term has been
    /// committed. Lets the researcher jump straight from "how is this term
    /// distributed across the corpus?" to "show me the matching documents" —
    /// carrying the term and (for date-based axes) the current year-range filter
    /// along as `pendingSearch` so Search lands pre-filled and ready to run.
    /// The number of documents matched by the current term/scope/range on the active axis — the sum
    /// of the plotted series, mirroring each chart section's own footnote math. Surfaced in the
    /// "View N documents" hand-off link so the affordance carries the count (design Win 3).
    private var matchedDocumentCount: Int {
        // DOCUMENTS, whatever the chart is plotting. This drives "View N documents ↗", which hands
        // off to Search — and Search returns documents. Reading it off the active axis series was a
        // real defect found by running the app: in Occurrences mode the button read "View 57,433
        // documents" for a term with 39,405 matching documents, so the one number the researcher
        // could check against another surface was the one that disagreed with it. Exactly the class
        // of mislabel PR-A removed, reintroduced one PR later by a shared accessor.
        //
        // The date axes therefore bypass `filteredYearData`/`filteredDecadeData`, which follow the
        // measure. The other four axes never carry occurrences and are already document counts.
        switch chartAxis {
        case .byYear:
            return (yearDataByTerm[committedTerm] ?? [])
                .filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
                .reduce(0) { $0 + $1.count }
        case .byDecade:
            return (decadeDataByTerm[committedTerm] ?? [])
                .filter { $0.decadeStart + 9 >= yearRangeStart && $0.decadeStart <= yearRangeEnd }
                .reduce(0) { $0 + $1.count }
        case .byMonth:     return filteredMonthData.reduce(0) { $0 + $1.count }
        case .byDay:       return filteredDayData.reduce(0) { $0 + $1.count }
        case .bySubseries: return subseriesData.reduce(0) { $0 + $1.count }
        case .byVolume:    return volumeData.reduce(0) { $0 + $1.count }
        }
    }

    /// The single document hand-off affordance (design Win 3): one "View N documents ↗" link
    /// carrying the matched count, replacing the redundant two-part bar ("See the documents behind
    /// this chart" + a separate "View in Search" button). The `openMatchingDocumentsInSearch()`
    /// `pendingSearch` hand-off is unchanged — only the entry point is consolidated.
    private var searchHandoffBar: some View {
        HStack(spacing: 8) {
            Button {
                openMatchingDocumentsInSearch()
            } label: {
                HStack(spacing: 4) {
                    Text(String(format: String(localized: "analytics.handoff.viewDocuments %lld",
                                               defaultValue: "View %lld documents"),
                                Int64(matchedDocumentCount)))
                        .font(.caption.weight(.medium))
                    Image(systemName: "arrow.up.forward")
                        .font(.caption2)
                }
            }
            .buttonStyle(.borderless)
            .help(String(
                localized: "analytics.handoff.help",
                defaultValue: "Switch to Search pre-filled with this term — and this year range, if a date-based view is active — to see the matching documents"
            ))

            // Dispersion belongs here, beside the query's own document count, and NOT under a
            // chart's totals footnote. It is computed from the volume breakdown, which is
            // date-independent and un-range-filtered, so sitting it beneath a By-Month or By-Day
            // total would invite the reader to take it as a decomposition of that total — and those
            // axes drop year-only and undated documents, so the two do not share a denominator. Here
            // it reads as a property of the term, which is what it is.
            dispersionFootnote

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Consolidated filter row (Wave B)

    /// The term entry field. D1: an "Add a term…" field that appends on Return (each committed term
    /// becomes a chip); the placeholder reads "Term…" for the first, then "Add a term…".
    ///
    /// ## Why one `@FocusState` is safe here despite two instantiations
    /// `filterRow` puts this field inside a `ViewThatFits`, so it is built **twice** — once in the
    /// one-row candidate and once in the stacked one. Two views sharing a focus binding is normally
    /// a shape to avoid, because *setting* the binding to `true` leaves it ambiguous which of them
    /// receives focus.
    ///
    /// This code never sets it to `true`. The only write is `false`, in ``addTerm()``, and "no view
    /// is focused" is unambiguous no matter how many claim the binding. That is what makes the
    /// small fix legitimate instead of forcing `filterRow` to be restructured — and restructuring
    /// it would cost the one-row layout on macOS and the iPad sheet, which is the whole reason
    /// `ViewThatFits` is here.
    private var termField: some View {
        TextField(termFieldPlaceholder, text: $termInput)
            .textFieldStyle(.roundedBorder)
            .focused($isTermFieldFocused)
            .submitLabel(.search)
            .onSubmit { addTerm() }
            .disabled(atCompareCap)
    }

    private var termFieldPlaceholder: String {
        committedTerms.isEmpty
            ? String(localized: "analytics.term.placeholder", defaultValue: "Term…")
            : String(localized: "analytics.term.addPlaceholder", defaultValue: "Add a term…")
    }

    /// The Search / Add trigger — commits the field as a comparison term (D1). Labelled "Search" for
    /// the first term, "Add" thereafter; disabled when empty or at the term cap.
    private var searchButton: some View {
        Button(committedTerms.isEmpty
               ? String(localized: "analytics.search.button", defaultValue: "Search")
               : String(localized: "analytics.addTerm.button", defaultValue: "Add")) {
            addTerm()
        }
        .buttonStyle(.borderedProminent)
        .disabled(atCompareCap || termInput.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    /// The comparison-term chips (D1) — one per committed term, colored by its series and removable
    /// with a ≥44pt ✕. Sits on its own row above the filter chips (owner decision D).
    @ViewBuilder
    private var termChipsRow: some View {
        if !committedTerms.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(committedTerms, id: \.self) { term in
                        HStack(spacing: 6) {
                            Circle().fill(termColor(term)).frame(width: 9, height: 9)
                            Text(term).font(.caption).lineLimit(1)
                            Button {
                                removeTerm(term)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: String(localized: "analytics.compare.chip.remove.a11y %@",
                                                                      defaultValue: "Remove %@ from comparison"), term))
                        }
                        .padding(.leading, 10)
                        .background(Capsule().fill(.quaternary.opacity(0.4)))
                    }
                    if atCompareCap {
                        Text(String(format: String(localized: "analytics.compare.cap %lld",
                                                   defaultValue: "Comparing %lld terms (the maximum)."),
                                    Int64(Self.maxCompareTerms)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// The compact scope chip — the shared `AnalyticsScopeBar` in its `.chip` presentation,
    /// re-running against the committed term on change (the old `scopeBar`'s behavior).
    private var scopeChip: some View {
        AnalyticsScopeBar(
            indexedVolumeIds: appState.indexedVolumeIds,
            volumeTitle: volumeTitle,
            scopeVolumeIds: $scopeVolumeIds,
            scopeLabel: $scopeLabel,
            onChange: {
                guard !committedTerms.isEmpty else { return }
                reloadData()
            },
            presentation: .chip
        )
    }

    /// The compact year-range chip, dimmed (not hidden) on the categorical axes whose breakdowns
    /// ignore the range — `categoricalYearNote` below the row explains it (design decision, Wave B).
    private var yearChip: some View {
        AnalyticsYearRangeBar(
            start: $yearRangeStart,
            end: $yearRangeEnd,
            corpusMaxYear: corpusMaxYear,
            isCompactWidth: isCompactWidth,
            isCustom: yearRangeIsCustom,
            onReset: {
                yearRangeStart = 1861
                yearRangeEnd = corpusMaxYear
            },
            presentation: .chip
        )
        .controlSize(.small)   // match the sibling menu chips' height in the row
        .disabled(chartAxis.isCategorical)
        .opacity(chartAxis.isCategorical ? 0.45 : 1)
    }

    /// The Administration-preset menu (one tap sets the range to a president's term), re-homed from
    /// the old year-range bar into the filter row as a chip; dimmed with the year chip on categorical
    /// axes since it too only sets a year range. Absent until the profiles index loads.
    @ViewBuilder private var adminPresetChip: some View {
        let administrations = appState.administrationProfilesStore.index?.administrations ?? []
        if !administrations.isEmpty {
            AdministrationPresetMenu(
                administrations: administrations,
                corpusMaxYear: corpusMaxYear,
                yearStart: $yearRangeStart,
                yearEnd: $yearRangeEnd
            )
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(chartAxis.isCategorical)
            .opacity(chartAxis.isCategorical ? 0.45 : 1)
        }
    }

    /// The "Group by" chip (Wave B) — replaces the toolbar axis picker. Opens a sectioned menu:
    /// "Over time" (the date-based axes) and "Broken down by" (the categorical axes), driven off the
    /// axis enum so the sections can't drift. Binds `$chartAxis`; no new state.
    private var groupByChip: some View {
        Menu {
            Section(String(localized: "analytics.axis.section.overTime", defaultValue: "Over time")) {
                ForEach(AnalyticsChartAxis.allCases.filter { $0.isDateBased }, id: \.self) { axis in
                    Button { chartAxis = axis } label: {
                        if axis == chartAxis {
                            Label(axis.pickerLabel, systemImage: "checkmark")
                        } else {
                            Text(axis.pickerLabel)
                        }
                    }
                }
            }
            Section(String(localized: "analytics.axis.section.brokenDown", defaultValue: "Broken down by")) {
                ForEach(AnalyticsChartAxis.allCases.filter { $0.isCategorical }, id: \.self) { axis in
                    Button { chartAxis = axis } label: {
                        if axis == chartAxis {
                            Label(axis.pickerLabel, systemImage: "checkmark")
                        } else {
                            Text(axis.pickerLabel)
                        }
                    }
                    // The categorical breakdowns can't compare multiple terms (owner decision A) —
                    // disabled while comparing; the date axes carry the per-term line comparison.
                    .disabled(isComparing)
                }
            }
        } label: {
            // Icon + bare axis label (no "Group by:" prefix) — parallels the sibling scope/year
            // chips' icon+value shape and is ~65pt narrower, which lets all four chips share one
            // un-clipped row on the narrow iPad sheet. The menu's sections carry the "group by"
            // meaning; `.help`/`.accessibilityLabel` restate it for pointer and VoiceOver users.
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption2)
                Text(chartAxis.pickerLabel)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(committedTerm.isEmpty)
        .help(String(localized: "analytics.axis.help", defaultValue: "Group the chart"))
        .accessibilityLabel(String(format: String(localized: "analytics.axis.a11y %@",
                                                  defaultValue: "Group by: %@"), chartAxis.pickerLabel))
    }

    /// Footnote under the filter row on the categorical axes, explaining the dimmed year chip.
    private var categoricalYearNote: some View {
        Text(String(localized: "analytics.yearRange.categoricalNote",
                    defaultValue: "The year range applies to the time views; the breakdowns show the whole span."))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 4)
    }

    /// The consolidated filter row (Wave B): term field + Search, then the scope / year-range /
    /// group-by / administration chips — `ViewThatFits` keeps everything on one row wherever the
    /// actual width allows (macOS window, `.page`-sized iPad sheet), and falls back to a term row
    /// plus a horizontally scrolling chip cluster only when genuinely narrow (iPhone). Replaces the
    /// four stacked filter bars so the chart lands above the fold on the iPad sheet.
    /// Width of the compact chip cluster's content, measured (P-1 residue).
    @State private var chipRowContentWidth: CGFloat = 0
    /// Width the chip cluster actually gets to show.
    @State private var chipRowVisibleWidth: CGFloat = 0

    /// Whether the chips do not all fit, and so a "there is more" cue is owed.
    ///
    /// The 1-point slack keeps a row that fits exactly from flickering a fade on a rounding
    /// difference between the two measurements.
    private var chipRowOverflows: Bool {
        chipRowVisibleWidth > 0 && chipRowContentWidth > chipRowVisibleWidth + 1
    }

    /// Opaque except for a short fade at the trailing edge — the standard overflow cue.
    private var chipFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.9),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .leading, endPoint: .trailing)
    }

    private var filterRow: some View {
        // Decide one-row vs. two-row by ACTUAL available width, not size class — an iPad sheet reports
        // compact width yet is wide enough for one row (that mismatch put the chips below the field).
        ViewThatFits(in: .horizontal) {
            // Preferred: everything on one row (iPad sheet, macOS window, regular-width iPad).
            HStack(spacing: 8) {
                termField.frame(minWidth: 150, maxWidth: 260)
                searchButton
                if !committedTerm.isEmpty {
                    scopeChip
                    yearChip
                    groupByChip
                    adminPresetChip
                }
            }
            // Fallback (iPhone / genuinely narrow): term row, then a horizontally scrolling chip cluster.
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    termField.frame(maxWidth: .infinity)
                    searchButton
                }
                if !committedTerm.isEmpty {
                    // **A trailing fade when — and only when — the chips overflow.**
                    // The row already scrolled, with `showsIndicators: false`, so a chip cut at the
                    // right edge read as a layout fault rather than as "there is more": the state
                    // the UI review's P-1 photographed. iOS auto-hides horizontal indicators, so the
                    // cue has to be drawn. Both widths are measured rather than assumed, because a
                    // permanent fade would dim a row that fits — which is most of them, on iPad.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            scopeChip
                            yearChip
                            groupByChip
                            adminPresetChip
                        }
                        .padding(.vertical, 1)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                            chipRowContentWidth = $0
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                        chipRowVisibleWidth = $0
                    }
                    .mask(chipRowOverflows ? AnyView(chipFadeMask) : AnyView(Rectangle()))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorMessage {
            ContentUnavailableView(
                String(localized: "analytics.error.title", defaultValue: "Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if committedTerm.isEmpty {
            ContentUnavailableView(
                String(localized: "analytics.prompt.title", defaultValue: "Enter a Term"),
                systemImage: "chart.bar.xaxis",
                description: Text(
                    String(localized: "analytics.prompt.detail",
                           defaultValue: "Type a keyword and tap Search to chart its frequency across the FRUS corpus.")
                )
            )
        } else if !unsupportedExactTerms.isEmpty {
            // Ahead of the No-Results branch on purpose: this state has matches, and a bare
            // "No Results" would read as "this word never appears" — the opposite of the truth.
            ContentUnavailableView(
                String(localized: "analytics.exactUnsupported.title",
                       defaultValue: "Exact-Word Charting Isn’t Available"),
                systemImage: "equal.circle",
                description: Text(
                    String(localized: "analytics.exactUnsupported.detail",
                           defaultValue: "\(unsupportedExactTerms.map { "=\($0)" }.formatted(.list(type: .and))) can’t be charted: Analytics counts by word stem, so it cannot tell \"containment\" from \"container\". Remove the = to chart the stem, or use Search, which does filter to the exact word.")
                )
            )
        } else if isAllResultDataEmpty {
            ContentUnavailableView(
                String(localized: "analytics.empty.title", defaultValue: "No Results"),
                systemImage: "chart.bar",
                description: Text(isComparing
                    ? String(localized: "analytics.empty.detail.compare",
                             defaultValue: "None of these terms match any indexed documents.")
                    : String(localized: "analytics.empty.detail",
                             defaultValue: "No indexed documents match \"\(committedTerm)\"."))
            )
        } else if isComparing {
            // Compare mode is chart-only — the table shows a single term (D1 review fix); the
            // view-mode toggle is disabled while comparing.
            chartContent
        } else {
            switch viewMode {
            case .chart:
                chartContent
            case .table:
                tableContent
            }
        }
    }

    /// `true` iff every backing data array is empty — used for the "No Results" state regardless of
    /// which granularity is selected. While comparing, checks EVERY committed term (a zero-match term
    /// in any position must not hide the other terms' lines — D1 review fix).
    private var isAllResultDataEmpty: Bool {
        if isComparing {
            return committedTerms.allSatisfy { term in
                (yearDataByTerm[term]?.isEmpty ?? true)
                    && (decadeDataByTerm[term]?.isEmpty ?? true)
                    && (monthDataByTerm[term]?.isEmpty ?? true)
                    && (dayDataByTerm[term]?.isEmpty ?? true)
                    && (subseriesDataByTerm[term]?.isEmpty ?? true)
                    && (volumeDataByTerm[term]?.isEmpty ?? true)
            }
        }
        return yearData.isEmpty
            && decadeData.isEmpty
            && monthData.isEmpty
            && dayData.isEmpty
            && subseriesData.isEmpty
            && volumeData.isEmpty
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        ScrollView {
            occurrenceNotice
            switch chartAxis {
            case .byDecade:    decadeChartSection
            case .byYear:      yearChartSection
            case .byMonth:     monthChartSection
            case .byDay:       dayChartSection
            case .bySubseries: subseriesChartSection
            case .byVolume:    volumeChartSection
            }
        }
    }

    // MARK: - Source Color-Coding (By Year / By Decade)

    /// Series key for the folded long tail of volumes.
    private static let otherSourceKey = "__other__"

    /// A period-bucketed, source-colored chart segment (one stacked rectangle).
    private struct SourceSegment: Identifiable {
        let period: Int
        let seriesKey: String
        let count: Int
        var id: String { "\(period)/\(seriesKey)" }
    }

    /// One legend entry: a source series key and its total over the rendered slice.
    private struct SourceSeries: Identifiable {
        let key: String
        let total: Int
        var id: String { key }
    }

    /// Ranks the volumes in `raw` by total count over the slice, keeps the top
    /// `seriesCount`, folds the rest into a single "Other" series, and returns the
    /// stacked per-period segments plus the ranked series list. Ranking is computed over
    /// the SAME slice that renders, so the color scale never drops or miscolors a segment.
    private func sourceColoring(_ raw: [(period: Int, volumeId: String, count: Int)])
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

    /// Color for a source series — palette by rank, gray for the folded "Other".
    private func sourceColor(_ key: String, index: Int) -> Color {
        key == Self.otherSourceKey ? .gray : ChartSeriesPalette.color(at: index)
    }

    /// Human label for a source series — a distilled volume label, or "Other volumes".
    private func sourceTitle(_ key: String) -> String {
        if key == Self.otherSourceKey {
            return String(localized: "analytics.chart.source.other", defaultValue: "Other volumes")
        }
        let subseries = CorpusAnalyticsService.subseries(fromVolumeId: key) ?? ""
        let title = appState.manifestStore.entry(forVolumeId: key)?.title ?? ""
        return ChronologyViewModel.distilledVolumeLabel(volumeId: key, subseries: subseries, title: title)
    }

    /// The color scale (domain + range) for a source-colored chart, in series order.
    private func sourceScale(_ series: [SourceSeries]) -> (domain: [String], range: [Color]) {
        (series.map(\.key), series.enumerated().map { sourceColor($0.element.key, index: $0.offset) })
    }

    /// Textual legend for the source colors — the non-color channel (volume name +
    /// count) so the encoding is fully available to VoiceOver and color-blind users.
    private func sourceLegend(_ series: [SourceSeries]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            alignment: .leading, spacing: 4
        ) {
            ForEach(Array(series.enumerated()), id: \.element.id) { index, s in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(sourceColor(s.key, index: index))
                        .frame(width: 10, height: 10)
                    Text(sourceTitle(s.key))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    // Same unit-less raw total as the exported figure's legend — labelled here too,
                    // so the screen and the figure agree.
                    Text(String(localized: "analytics.figure.legend.docs",
                                defaultValue: "\(s.total) docs"))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(String(
                    format: String(localized: "analytics.chart.source.legend.a11y %@ %lld",
                                   defaultValue: "%@, %lld documents"),
                    sourceTitle(s.key), Int64(s.total))))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Normalization Math (CA-4)

    /// The plotted y-value for a raw `count` in `period`, honoring the active
    /// normalization mode. In raw mode this is the count itself (as a `Double`). In
    /// `% of documents` mode it is `count / totals[period] * 100`; a period whose corpus
    /// total is missing or zero yields `nil` (divide-by-zero guard) so the caller can
    /// omit that mark rather than plot a bogus value.
    ///
    /// `totals` is `documentTotalsByYear` for the By-Year axis and
    /// `documentTotalsByDecade` for the By-Decade axis — the scoped corpus denominator
    /// fetched in `runSearch()`, keyed the same way the chart buckets its periods.
    private func normalizedValue(count: Int, period: Int, totals: [Int: Int]) -> Double? {
        guard isNormalized else { return Double(count) }
        guard let total = totals[period], total > 0 else { return nil }
        return Double(count) / Double(total) * 100.0
    }

    /// Y-axis title for the date charts — "Documents" in raw mode, "% of documents"
    /// when the normalization toggle is active for the axis.
    /// What this view's numbers count, as the researcher last chose.
    ///
    /// Read through ``valueUnit``, never directly: the preference persists across axes, but only
    /// By Year and By Decade can serve occurrences, so the effective unit falls back to documents
    /// elsewhere rather than the picker's choice silently applying where no data backs it.
    @AppStorage(AnalyticsValueUnit.storageKey) private var storedValueUnit: AnalyticsValueUnit = .documents

    /// What this view's numbers actually count right now.
    ///
    /// Documents whenever occurrences cannot be served: on an axis without an occurrence series, or
    /// for a query shape that has no honest occurrence count (see ``OccurrenceAvailability``). The
    /// fallback is silent in the data and **loud in the UI** — `occurrenceNotice` states the reason —
    /// because a chart that quietly switched units would be the exact defect this workstream removed.
    private var valueUnit: AnalyticsValueUnit {
        guard storedValueUnit == .occurrences, measureApplies, occurrenceAvailability.isAvailable
        else { return .documents }
        return .occurrences
    }

    /// Whether a measure other than documents can be offered on the current axis.
    ///
    /// By Year and By Decade only — the same two axes normalisation applies to, and for the same
    /// underlying reason: they are the axes with a per-period series the service can produce. Only
    /// `termOccurrencesByYear` exists; the sub-year and categorical axes would each need their own
    /// method with its own population reasoning, which is deliberately not in this change.
    ///
    /// Separate from ``normalizationApplies`` even though the two currently agree: they answer
    /// different questions (what is counted vs. whether it is divided by a denominator), and
    /// collapsing them would make the next axis-scope change edit the wrong one.
    private var measureApplies: Bool {
        chartAxis == .byYear || chartAxis == .byDecade
    }

    private var valueAxisLabel: String {
        isNormalized
            ? AnalyticsValueUnit.axisLabel(unit: valueUnit, isNormalized: true)
            : AnalyticsValueUnit.axisLabel(unit: valueUnit, isNormalized: false)
    }

    /// Y-axis marks for the date charts: percent-formatted value labels in normalized
    /// mode (the plotted values are already 0–100). In raw mode the value labels use
    /// Swift Charts' framework-default formatting (locale thousands grouping, e.g.
    /// "4,187"), preserving the original document-count axis byte-for-byte — the raw
    /// path only supplies grid line + tick + a default `AxisValueLabel()`, exactly as
    /// before this axis was made explicit for the normalized mode.
    @AxisContentBuilder
    private var valueAxisMarks: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisTick()
            if isNormalized {
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(verbatim: "\(percent.formatted(.number.precision(.fractionLength(0...1))))%")
                    }
                }
            } else {
                AxisValueLabel()
            }
        }
    }

    /// VoiceOver value string for a source segment, reflecting the active mode: the raw
    /// document count, or the plotted share as a percentage.
    private func sourceValueA11y(count: Int, plotted: Double) -> String {
        if isNormalized {
            return String(
                format: String(localized: "analytics.chart.source.share.a11y %@",
                               defaultValue: "%@ percent of documents"),
                plotted.formatted(.number.precision(.fractionLength(0...1))))
        }
        return valueUnit.accessibilityPhrase(count: count)
    }

    /// Caption disclosing the active normalization mode beneath the By-Year / By-Decade
    /// charts. Only shown when `% of documents` is active; names the denominator and
    /// repeats the standing selective-corpus caveat (only indexed volumes are counted).
    @ViewBuilder
    private var normalizationCaption: some View {
        if isNormalized {
            Text(String(localized: "analytics.normalize.caption",
                        defaultValue: "Share of indexed documents per period. Only downloaded, indexed volumes are counted, so this is a share of your local corpus, not the entire FRUS series."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Single-term date chart (shared by the screen and the D3 figure export)

    /// The source-colored bar chart for the By-Year / By-Decade axes.
    ///
    /// Called by both the on-screen section and the exported figure, so the published image cannot
    /// drift from what the app shows. It takes **pre-resolved** `sourceTitles` rather than calling
    /// `sourceTitle` itself: exported content is detached from the view hierarchy and inherits no
    /// environment, so a builder that reached for `appState` here would fail at render time (D3).
    ///
    /// - Parameters:
    ///   - segments: The stacked per-(period, source) segments.
    ///   - scale: The color scale's domain and range.
    ///   - fitPoints: The per-period totals backing the smoothed fit line.
    ///   - totals: The corpus denominator for the axis.
    ///   - xLabel: The x-axis title.
    ///   - sourceTitles: Series key → display title, resolved by the caller.
    ///   - decadeStride: Whether to tick the x-axis every ten years.
    ///   - showsFitLine: Whether to overlay the smoothed trend line.
    private func singleTermDateChart(
        segments: [SourceSegment],
        scale: (domain: [String], range: [Color]),
        fitPoints: [(period: Int, count: Int)],
        totals: [Int: Int],
        xLabel: String,
        sourceTitles: [String: String],
        decadeStride: Bool,
        showsFitLine: Bool
    ) -> some View {
        Chart {
            ForEach(segments) { seg in
                // In `% of documents` mode the segment height is its share of the period's corpus
                // total; a period with a missing/zero total is omitted (divide-by-zero guard). Raw
                // mode plots the count unchanged.
                if let y = normalizedValue(count: seg.count, period: seg.period, totals: totals) {
                    BarMark(
                        x: .value(xLabel, seg.period),
                        y: .value(valueAxisLabel, y),
                        width: decadeStride ? .ratio(0.8) : .automatic
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "analytics.chart.source.series", defaultValue: "Volume"),
                        seg.seriesKey
                    ))
                    .accessibilityLabel(Text(verbatim: "\(seg.period), \(sourceTitles[seg.seriesKey] ?? seg.seriesKey)"))
                    .accessibilityValue(Text(sourceValueA11y(count: seg.count, plotted: y)))
                }
            }
            if showsFitLine {
                ForEach(fitPoints, id: \.period) { point in
                    if let y = normalizedValue(count: point.count, period: point.period, totals: totals) {
                        LineMark(x: .value(xLabel, point.period), y: .value(valueAxisLabel, y))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: scale.domain, range: scale.range)
        .chartLegend(.hidden)
        .chartXScale(domain: yearRangeStart...yearRangeEnd)
        .chartXAxis {
            if decadeStride {
                AxisMarks(values: .stride(by: 10)) { _ in
                    AxisGridLine(); AxisTick(); AxisValueLabel(format: integerNoGroupingFormat)
                }
            } else {
                AxisMarks { _ in
                    AxisGridLine(); AxisTick(); AxisValueLabel(format: integerNoGroupingFormat)
                }
            }
        }
        .chartYAxis { valueAxisMarks }
        .chartXAxisLabel(xLabel, alignment: .center)
        .chartYAxisLabel(valueAxisLabel)
        // #306: drag across the plot to narrow the year range. The selection is committed on
        // release, not continuously — see `scrubSelection`.
        .chartXSelection(range: $scrubSelection)
        .onChange(of: scrubSelection) { _, range in
            guard let range else { return }
            commitScrub(range, decadeStride: decadeStride)
        }
    }

    /// Applies a finished scrubber drag to the year range (#306). The arithmetic lives in
    /// `ChartScrubRange.resolve` so it can be tested; this is the state write.
    private func commitScrub(_ range: ClosedRange<Int>, decadeStride: Bool) {
        defer { scrubSelection = nil }
        guard let resolved = ChartScrubRange.resolve(selection: range,
                                                     decadeStride: decadeStride,
                                                     corpusMaxYear: corpusMaxYear) else { return }
        guard resolved.lowerBound != yearRangeStart || resolved.upperBound != yearRangeEnd else {
            return
        }
        yearRangeStart = resolved.lowerBound
        yearRangeEnd = resolved.upperBound
        // Nothing else to do: the scope chip and its Reset already read `yearRangeIsCustom`, which
        // is derived from these two, so a drag surfaces both without a second code path.
    }

    /// Display titles for the source series currently colored, resolved here (where `appState` is
    /// available) so the detached export content never has to.
    ///
    /// - Parameter series: The ranked source series.
    /// - Returns: Series key → display title.
    private func resolvedSourceTitles(_ series: [SourceSeries]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: series.map { ($0.key, sourceTitle($0.key)) })
    }

    /// The source-color key drawn onto an exported figure (D3).
    ///
    /// The By-Year / By-Decade charts hide Swift Charts' own legend and draw a hand-rolled one, so
    /// without this an exported figure would show colored segments whose meaning is nowhere stated —
    /// unusable in a publication. Takes pre-resolved titles because export content is detached.
    ///
    /// - Parameters:
    ///   - series: The ranked source series.
    ///   - titles: Series key → display title, resolved by the caller.
    private func figureSourceLegend(_ series: [SourceSeries], titles: [String: String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading),
                      GridItem(.flexible(), alignment: .leading),
                      GridItem(.flexible(), alignment: .leading)],
            alignment: .leading, spacing: 4
        ) {
            ForEach(Array(series.enumerated()), id: \.element.id) { index, s in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(sourceColor(s.key, index: index))
                        .frame(width: 10, height: 10)
                    Text(titles[s.key] ?? s.key)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.black.opacity(0.7))
                        .lineLimit(1)
                    // Always the raw document total, even when the plotted bars are percentages —
                    // so under a normalised chart this number is in different units from everything
                    // above it. It shipped unlabelled on exported figures, where a reader has only
                    // the image: they read the legend as the plotted quantity and mis-scale every
                    // claim about which volume drives the trend. Naming the unit is enough; the
                    // number itself is the right one to show (a share per source would not sum).
                    Text(String(localized: "analytics.figure.legend.docs",
                                defaultValue: "\(s.total) docs"))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Color.black.opacity(0.45))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Compare charts (D1)

    /// Per-term line chart over an Int period axis (By-Year / By-Decade) for compare mode: one line
    /// per committed term colored by term, y respecting the active (compare-defaulted %) normalization.
    private func compareIntChart(seriesByTerm: [(term: String, points: [(period: Int, count: Int)])],
                                 xLabel: String, xDomain: ClosedRange<Int>, totals: [Int: Int],
                                 decadeStride: Bool) -> some View {
        Chart {
            ForEach(seriesByTerm, id: \.term) { series in
                ForEach(series.points, id: \.period) { pt in
                    if let y = normalizedValue(count: pt.count, period: pt.period, totals: totals) {
                        LineMark(x: .value(xLabel, pt.period), y: .value(valueAxisLabel, y))
                            .foregroundStyle(by: .value(
                                String(localized: "analytics.chart.term.series", defaultValue: "Term"), series.term))
                            .interpolationMethod(.catmullRom)
                            .accessibilityLabel(Text(verbatim: "\(series.term), \(pt.period)"))
                            .accessibilityValue(Text(sourceValueA11y(count: pt.count, plotted: y)))
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: compareColorScale.domain, range: compareColorScale.range)
        .chartLegend(.visible)
        .chartXScale(domain: xDomain)
        .chartYAxis { valueAxisMarks }
        .chartXAxis {
            if decadeStride {
                AxisMarks(values: .stride(by: 10)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: integerNoGroupingFormat) }
            } else {
                AxisMarks { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: integerNoGroupingFormat) }
            }
        }
        .chartXAxisLabel(xLabel, alignment: .center)
        .chartYAxisLabel(valueAxisLabel)
        .frame(height: 280)
        .padding(.horizontal)
    }

    /// Per-term line chart over a Date axis (By-Month / By-Day) for compare mode. These axes have no
    /// corpus denominator, so values are raw counts; one line per committed term, colored by term.
    private func compareDateChart(seriesByTerm: [(term: String, points: [(date: Date, count: Int)])],
                                  xLabel: String, xDomain: ClosedRange<Date>) -> some View {
        Chart {
            ForEach(seriesByTerm, id: \.term) { series in
                ForEach(series.points, id: \.date) { pt in
                    LineMark(x: .value(xLabel, pt.date),
                             y: .value(valueAxisLabel, pt.count))
                        .foregroundStyle(by: .value(
                            String(localized: "analytics.chart.term.series", defaultValue: "Term"), series.term))
                        .interpolationMethod(.catmullRom)
                        .accessibilityLabel(Text(verbatim: series.term))
                        .accessibilityValue(Text(verbatim: "\(pt.count)"))
                }
            }
        }
        .chartForegroundStyleScale(domain: compareColorScale.domain, range: compareColorScale.range)
        .chartLegend(.visible)
        .chartXScale(domain: xDomain)
        .chartXAxisLabel(xLabel, alignment: .center)
        .chartYAxisLabel(valueAxisLabel)
        .frame(height: 280)
        .padding(.horizontal)
    }

    // MARK: - Year Chart

    private var yearChartSection: some View {
        let data = filteredYearData
        let totalAllYears = yearData.reduce(0) { $0 + $1.count }
        let totalFiltered = data.reduce(0) { $0 + $1.count }
        // Per-(year, volume) segments over the same filtered slice the chart renders.
        let raw = yearVolumeData
            .filter { $0.year >= yearRangeStart && $0.year <= yearRangeEnd }
            .map { (period: $0.year, volumeId: $0.volumeId, count: $0.count) }
        let coloring = sourceColoring(raw)
        let scale = sourceScale(coloring.series)
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.year.heading",
                       defaultValue: "\(chartHeadingTerms) \u{2014} by Year")
            )
            .font(.headline)
            .padding(.horizontal)

            if isComparing {
                compareIntChart(
                    seriesByTerm: committedTerms.map { term in
                        (term: term, points: filteredYearData(for: term).map { (period: $0.year, count: $0.count) })
                    },
                    xLabel: String(localized: "analytics.axis.year", defaultValue: "Year"),
                    xDomain: yearRangeStart...yearRangeEnd,
                    totals: documentTotalsByYear,
                    decadeStride: false
                )
                normalizationCaption.padding(.horizontal)
            } else {
            if !coloring.series.isEmpty {
                sourceLegend(coloring.series)
            }

            // D3: the same builder the exported figure uses, so the published image cannot drift
            // from what the app shows.
            singleTermDateChart(
                segments: coloring.segments,
                scale: scale,
                fitPoints: data.map { (period: $0.year, count: $0.count) },
                totals: documentTotalsByYear,
                xLabel: String(localized: "analytics.axis.year", defaultValue: "Year"),
                sourceTitles: resolvedSourceTitles(coloring.series),
                decadeStride: false,
                showsFitLine: showFitLine
            )
            .frame(height: 280)
            .padding(.horizontal)

            normalizationCaption
                .padding(.horizontal)

            totalsFootnote(filtered: totalFiltered, total: totalAllYears)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Decade Chart

    private var decadeChartSection: some View {
        let data = filteredDecadeData
        let totalAll = decadeData.reduce(0) { $0 + $1.count }
        let totalFiltered = data.reduce(0) { $0 + $1.count }
        // Bucket the per-(year, volume) data into decades, keeping decades that
        // intersect the active year range (matching `filteredDecadeData`).
        let raw: [(period: Int, volumeId: String, count: Int)] = yearVolumeData.compactMap {
            let decade = ($0.year / 10) * 10
            guard decade + 9 >= yearRangeStart && decade <= yearRangeEnd else { return nil }
            return (period: decade, volumeId: $0.volumeId, count: $0.count)
        }
        let coloring = sourceColoring(raw)
        let scale = sourceScale(coloring.series)
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.decade.heading",
                       defaultValue: "\(chartHeadingTerms) \u{2014} by Decade")
            )
            .font(.headline)
            .padding(.horizontal)

            if isComparing {
                compareIntChart(
                    seriesByTerm: committedTerms.map { term in
                        (term: term, points: filteredDecadeData(for: term).map { (period: $0.decadeStart, count: $0.count) })
                    },
                    xLabel: String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                    xDomain: yearRangeStart...yearRangeEnd,
                    totals: documentTotalsByDecade,
                    decadeStride: true
                )
                normalizationCaption.padding(.horizontal)
            } else {
            if !coloring.series.isEmpty {
                sourceLegend(coloring.series)
            }

            // D3: the same builder the exported figure uses (see `singleTermDateChart`).
            singleTermDateChart(
                segments: coloring.segments,
                scale: scale,
                fitPoints: data.map { (period: $0.decadeStart, count: $0.count) },
                totals: documentTotalsByDecade,
                xLabel: String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                sourceTitles: resolvedSourceTitles(coloring.series),
                decadeStride: true,
                showsFitLine: showFitLine
            )
            .frame(height: 280)
            .padding(.horizontal)

            normalizationCaption
                .padding(.horizontal)

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Month Chart

    private var monthChartSection: some View {
        let data = filteredMonthData
        let totalAll = monthData.reduce(0) { $0 + $1.count }
        let totalFiltered = data.reduce(0) { $0 + $1.count }
        let cal = Calendar(identifier: .gregorian)
        let startDate = cal.date(from: DateComponents(year: yearRangeStart, month: 1, day: 1)) ?? .distantPast
        let endDate   = cal.date(from: DateComponents(year: yearRangeEnd,  month: 12, day: 31)) ?? .distantFuture
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.month.heading",
                       defaultValue: "\(chartHeadingTerms) \u{2014} by Month")
            )
            .font(.headline)
            .padding(.horizontal)

            if isComparing {
                let series = committedTerms.map { term in
                    (term: term, points: filteredMonthData(for: term).map { (date: $0.date, count: $0.count) })
                }
                if series.allSatisfy({ $0.points.isEmpty }) {
                    noMonthDataNotice.padding(.horizontal)
                } else {
                    compareDateChart(seriesByTerm: series,
                                     xLabel: String(localized: "analytics.axis.month", defaultValue: "Month"),
                                     xDomain: startDate...endDate)
                }
            } else {
            if data.isEmpty {
                noMonthDataNotice
                    .padding(.horizontal)
            } else {
                Chart {
                    ForEach(data) { point in
                        BarMark(
                            x: .value(
                                String(localized: "analytics.axis.month", defaultValue: "Month"),
                                point.date,
                                unit: .month
                            ),
                            y: .value(
                                valueAxisLabel,
                                point.count
                            )
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.65))
                    }
                    if showFitLine {
                        ForEach(data) { point in
                            LineMark(
                                x: .value(
                                    String(localized: "analytics.axis.month", defaultValue: "Month"),
                                    point.date
                                ),
                                y: .value(
                                    valueAxisLabel,
                                    point.count
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .chartXScale(domain: startDate...endDate)
                .chartXAxisLabel(
                    String(localized: "analytics.axis.month", defaultValue: "Month"),
                    alignment: .center
                )
                .chartYAxisLabel(
                    valueAxisLabel
                )
                .frame(height: 280)
                .padding(.horizontal)
            }

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Day Chart

    private var dayChartSection: some View {
        let data = filteredDayData
        let totalAll = dayData.reduce(0) { $0 + $1.count }
        let totalFiltered = data.reduce(0) { $0 + $1.count }
        let cal = Calendar(identifier: .gregorian)
        let startDate = cal.date(from: DateComponents(year: yearRangeStart, month: 1, day: 1)) ?? .distantPast
        let endDate   = cal.date(from: DateComponents(year: yearRangeEnd,  month: 12, day: 31)) ?? .distantFuture
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.day.heading",
                       defaultValue: "\(chartHeadingTerms) \u{2014} by Day")
            )
            .font(.headline)
            .padding(.horizontal)

            if isComparing {
                let series = committedTerms.map { term in
                    (term: term, points: filteredDayData(for: term).map { (date: $0.date, count: $0.count) })
                }
                if series.allSatisfy({ $0.points.isEmpty }) {
                    noDayDataNotice.padding(.horizontal)
                } else {
                    compareDateChart(seriesByTerm: series,
                                     xLabel: String(localized: "analytics.axis.date", defaultValue: "Date"),
                                     xDomain: startDate...endDate)
                }
            } else {
            if data.isEmpty {
                noDayDataNotice
                    .padding(.horizontal)
            } else {
                Chart {
                    ForEach(data) { point in
                        PointMark(
                            x: .value(
                                String(localized: "analytics.axis.date", defaultValue: "Date"),
                                point.date
                            ),
                            y: .value(
                                valueAxisLabel,
                                point.count
                            )
                        )
                        .symbolSize(20)
                        .foregroundStyle(Color.accentColor.opacity(0.55))
                    }
                    if showFitLine {
                        ForEach(data) { point in
                            LineMark(
                                x: .value(
                                    String(localized: "analytics.axis.date", defaultValue: "Date"),
                                    point.date
                                ),
                                y: .value(
                                    valueAxisLabel,
                                    point.count
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                        }
                    }
                }
                .chartXScale(domain: startDate...endDate)
                .chartXAxisLabel(
                    String(localized: "analytics.axis.date", defaultValue: "Date"),
                    alignment: .center
                )
                .chartYAxisLabel(
                    valueAxisLabel
                )
                .frame(height: 280)
                .padding(.horizontal)
            }

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Occurrence measure notice (R-2 PR-D)

    /// States why the Measure picker is unavailable, when the researcher has asked for occurrences
    /// and this query cannot honestly supply them.
    ///
    /// ## Why this exists rather than a disabled control alone
    /// A greyed-out picker says "not here" and nothing else. The reasons are not guessable — that
    /// exact-word searches cannot be counted by occurrence is a fact about how the index stores
    /// stems, and no amount of looking at the UI would reveal it. So the reason is stated, once, in
    /// the researcher's own terms.
    ///
    /// Shown only when the preference is `occurrences`: someone who never asked for the measure does
    /// not need to be told which of their queries could not have provided it. And only on the axes
    /// that offer the measure at all, so switching to By Volume does not produce a notice about a
    /// control that is not on screen.
    @ViewBuilder
    private var occurrenceNotice: some View {
        if storedValueUnit == .occurrences, measureApplies, !committedTerm.isEmpty,
           let reason = occurrenceAvailability.reason {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(reason.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Dispersion (R-2 PR-C)

    /// How widely the current term's matches are spread across volumes, and whether they concentrate.
    ///
    /// ## Why this is worth a line
    /// "182 documents" describes two completely different findings: a term spread across 150 volumes
    /// is a corpus-wide vocabulary, and one concentrated in three is a specific episode. The charts
    /// show *when* matches occur and never *how narrowly*.
    ///
    /// ## Why it is computed from the VOLUME data and not the plotted axis
    /// Three constraints, each of which would produce a wrong number if ignored:
    ///
    /// 1. **N comes from `volumeData`, the same array whose sum is being decomposed** — never
    ///    `matchedDocumentCount`, which is per-axis and year-range filtered while `volumeData` is
    ///    not. Mixing them makes the parts disagree with the whole exactly when a custom range is
    ///    set, which is precisely when a researcher is looking closely.
    /// 2. **It is date-independent.** `termFrequencyByVolume` never touches dates, so this is immune
    ///    to the volume-start-year fallback that makes undated documents land in a manufactured year
    ///    bucket. A "spans N years" figure from `yearData` would inherit that fabrication, which is
    ///    why there isn't one.
    /// 3. **The denominator is volumes indexed on this device**, not the manifest's 552. A share of
    ///    the published series would be a claim about data the device does not have.
    ///
    /// Returns `nil` while comparing (the sentence would need a subject) or with no volume data.
    ///
    /// The arithmetic lives in ``CorpusDispersion`` rather than here so it can be tested at its
    /// boundaries — a share gate buried in a view body is a rule nothing can check.
    private var volumeDispersion: CorpusDispersion? {
        guard !isComparing, !committedTerm.isEmpty else { return nil }
        return CorpusDispersion.make(volumeCounts: volumeData.map(\.count),
                                     indexedVolumeCount: appState.indexedVolumeIds.count)
    }

    /// The dispersion footnote: how many volumes hold the match, and — only when it is genuinely a
    /// concentration — how much of it the top three hold.
    ///
    /// The 25% gate follows `FacetPanelView`'s precedent ("Computed, never templated"): across 552
    /// volumes a common term's top three hold ~1.7%, and announcing that as a concentration would
    /// train the reader to ignore the line. Above the gate it is the finding.
    @ViewBuilder
    private var dispersionFootnote: some View {
        if let d = volumeDispersion {
            HStack(spacing: 4) {
                Text(String(localized: "analytics.dispersion.volumes",
                            defaultValue: "Spread across \(d.volumes) of \(d.indexedVolumeCount) indexed volumes"))
                if d.showsConcentration {
                    Text(verbatim: "·")
                    Text(String(localized: "analytics.dispersion.concentration",
                                defaultValue: "top 3 hold \(d.topThreePercent)%"))
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Footnote Helpers

    /// Format style for integer axis labels that suppresses comma grouping —
    /// years should display as `1969`, not `1,969`.
    private var integerNoGroupingFormat: IntegerFormatStyle<Int> {
        IntegerFormatStyle<Int>.number.grouping(.never)
    }

    /// Renders the count footnote shown under each chart. When the user has
    /// narrowed the range away from defaults, displays both the in-range count
    /// and the full-corpus total alongside.
    @ViewBuilder
    private func totalsFootnote(filtered: Int, total: Int) -> some View {
        HStack(spacing: 4) {
            totalFootnote(count: filtered)
            if yearRangeIsCustom && total != filtered {
                Text(verbatim: "·")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                Text(
                    String(
                        format: String(localized: "analytics.total.all %lld",
                                       defaultValue: "%lld total in full corpus"),
                        Int64(total)
                    )
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }

    /// Shown for the by-month chart when no document in the corpus has a date
    /// with month-level precision (only `yyyy` was indexed).
    private var noMonthDataNotice: some View {
        ContentUnavailableView(
            String(localized: "analytics.month.empty.title",
                   defaultValue: "No documents with month-level dates"),
            systemImage: "calendar.badge.exclamationmark",
            description: Text(
                String(localized: "analytics.month.empty.detail",
                       defaultValue: "Matching documents are indexed with year-only dates. Switch to By Year or By Decade.")
            )
        )
        .frame(height: 220)
    }

    /// Shown for the by-day chart when no document has day-level precision.
    private var noDayDataNotice: some View {
        ContentUnavailableView(
            String(localized: "analytics.day.empty.title",
                   defaultValue: "No documents with day-level dates"),
            systemImage: "calendar.badge.exclamationmark",
            description: Text(
                String(localized: "analytics.day.empty.detail",
                       defaultValue: "Matching documents are indexed without full yyyy-MM-dd dates. Try By Month or By Year.")
            )
        )
        .frame(height: 220)
    }

    private var subseriesChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.subseries.heading",
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Subseries")
            )
            .font(.headline)
            .padding(.horizontal)

            // Horizontal bar chart so subseries labels remain legible.
            Chart {
                ForEach(subseriesData) { point in
                    BarMark(
                        x: .value(
                            valueAxisLabel,
                            point.count
                        ),
                        y: .value(
                            String(localized: "analytics.axis.subseries", defaultValue: "Subseries"),
                            point.subseries
                        )
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.65))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(verbatim: "\(point.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxisLabel(
                valueAxisLabel,
                alignment: .center
            )
            .chartOverlay { proxy in categoryTapOverlay(proxy) { subseries in
                openScopedDocumentsInSearch(volumeIds: indexedVolumeIds(forSubseries: subseries))
            } }
            .frame(height: max(240, CGFloat(subseriesData.count) * 28))
            .padding(.horizontal)

            drillInHint
                .padding(.horizontal)

            totalFootnote(count: subseriesData.reduce(0) { $0 + $1.count })
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Volume Chart

    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.volume.heading",
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Volume")
            )
            .font(.headline)
            .padding(.horizontal)

            // Horizontal bar chart so volume titles remain legible. The bar's
            // category is the resolved title; the tap handler maps it back to its
            // volume ID for the scoped Search handoff.
            Chart {
                ForEach(volumeData) { point in
                    BarMark(
                        x: .value(
                            valueAxisLabel,
                            point.count
                        ),
                        y: .value(
                            String(localized: "analytics.axis.volume", defaultValue: "Volume"),
                            volumeTitle(point.volumeId)
                        )
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.65))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(verbatim: "\(point.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxisLabel(
                valueAxisLabel,
                alignment: .center
            )
            .chartOverlay { proxy in categoryTapOverlay(proxy) { title in
                // Reverse-resolve the tapped title to its volume ID.
                if let match = volumeData.first(where: { volumeTitle($0.volumeId) == title }) {
                    openScopedDocumentsInSearch(volumeIds: [match.volumeId])
                }
            } }
            .frame(height: max(240, CGFloat(volumeData.count) * 28))
            .padding(.horizontal)

            drillInHint
                .padding(.horizontal)

            totalFootnote(count: volumeData.reduce(0) { $0 + $1.count })
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Drill-in Helpers

    /// Caption shown beneath the categorical (subseries / volume) charts telling the
    /// user the bars are tappable.
    private var drillInHint: some View {
        Label(
            String(localized: "analytics.drillIn.hint",
                   defaultValue: "Tap a bar to open the matching documents in Search."),
            systemImage: "hand.tap"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Transparent overlay that maps a tap on a horizontal bar chart to the category
    /// (string value on the Y axis) under the tap, invoking `onSelect` with it.
    ///
    /// Shared by the By-Subseries and By-Volume charts. The plot frame is resolved via
    /// `GeometryReader` so the tap location is converted into plot-area coordinates
    /// before `proxy.value(atY:)` looks up the nearest category.
    private func categoryTapOverlay(
        _ proxy: ChartProxy,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard let plotAnchor = proxy.plotFrame else { return }
                    let plotRect = geo[plotAnchor]
                    let relativeY = location.y - plotRect.origin.y
                    guard let category = proxy.value(atY: relativeY, as: String.self) else { return }
                    onSelect(category)
                }
        }
    }

    private func totalFootnote(count: Int) -> some View {
        Text(valueUnit.matchedPhrase(count: count))
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Table Content

    @ViewBuilder
    private var tableContent: some View {
        switch chartAxis {
        case .byDecade:
            tableList(rows: filteredDecadeData,
                      label: { "\($0.decadeStart)s" },
                      countOf: { $0.count })

        case .byYear:
            tableList(rows: filteredYearData,
                      label: { String($0.year) },
                      countOf: { $0.count })

        case .byMonth:
            tableList(rows: filteredMonthData,
                      label: { $0.label },
                      countOf: { $0.count })

        case .byDay:
            tableList(rows: filteredDayData,
                      label: { Self.isoDayFormatter.string(from: $0.date) },
                      countOf: { $0.count })

        case .bySubseries:
            tableList(rows: subseriesData,
                      label: { $0.subseries },
                      countOf: { $0.count },
                      onTap: { openScopedDocumentsInSearch(volumeIds: indexedVolumeIds(forSubseries: $0.subseries)) })

        case .byVolume:
            tableList(rows: volumeData,
                      label: { volumeTitle($0.volumeId) },
                      countOf: { $0.count },
                      onTap: { openScopedDocumentsInSearch(volumeIds: [$0.volumeId]) })
        }
    }

    /// Generic two-column row list used by every table-mode granularity.
    ///
    /// When `onTap` is non-nil (the categorical subseries / volume axes) each row is a
    /// button that opens Search scoped to that row; otherwise rows are static.
    @ViewBuilder
    private func tableList<Row: Identifiable>(
        rows: [Row],
        label: @escaping (Row) -> String,
        countOf: @escaping (Row) -> Int,
        onTap: ((Row) -> Void)? = nil
    ) -> some View {
        List {
            // The one surface that never said what its numbers are. Every chart carries a
            // "Documents" y-axis label, and the exported CSV heads the column "Matching documents",
            // but the on-screen table printed a bare integer per row with no header — so the reader
            // could not tell document counts from occurrence counts, which for this corpus differ by
            // up to 9× (one 1949 document carries 54 of the 92 "Article 43" occurrences).
            Section {
                ForEach(rows) { row in
                    if let onTap {
                        Button {
                            onTap(row)
                        } label: {
                            tableRow(label: label(row), count: countOf(row), tappable: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        tableRow(label: label(row), count: countOf(row), tappable: false)
                    }
                }
            } header: {
                HStack {
                    Text(chartAxis.pickerLabel)
                    Spacer()
                    Text(String(localized: "analytics.table.header.documents",
                                defaultValue: "Documents"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    /// One row of the analytics data table: a label on the left and a right-aligned
    /// count. Tappable rows (subseries / volume) add a trailing chevron to advertise
    /// the drill-in affordance.
    @ViewBuilder
    private func tableRow(label: String, count: Int, tappable: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: "\(count)")
                .fontWeight(.medium)
                .monospacedDigit()
            if tappable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    /// Shared yyyy-MM-dd formatter for the by-day table.
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Unavailable Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "analytics.unavailable.title",
                   defaultValue: "Analytics Unavailable"),
            systemImage: "chart.bar.xaxis",
            description: Text(
                String(localized: "analytics.unavailable.detail",
                       defaultValue: "The search index is not available. Index at least one volume to enable analytics.")
            )
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // View mode: chart vs table (reusable chrome component, Prep-B).
        ToolbarItem(placement: .primaryAction) {
            AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: committedTerm.isEmpty || isComparing)
        }

        if horizontalSizeClass == .compact {
            // iPhone: fold the secondary chart controls into a single "Options" menu (mirrors
            // WordCloudView). On regular width they render inline below (#188-A). Shown only when the
            // menu would have content — after Wave B moved axis granularity to the filter row's
            // "Group by" chip, a categorical axis leaves normalization + fit-line/colors all
            // inapplicable, so an un-gated button would open an empty menu (R3).
            // D3 adds Export to this menu, so the gate gains `canExport` — still "shown only when the
            // menu would have content" (never unconditionally), which is what R3 fixed.
            // `measureApplies` belongs in this gate for the same reason the others do: without it a
            // By-Year chart whose only available control is Measure would open an EMPTY menu on
            // iPhone — no compile error, no test failure, and invisible on a Mac.
            if measureApplies || normalizationApplies
                || (chartAxis.isDateBased && viewMode == .chart) || canExport {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        compactChartOptionsMenu
                    } label: {
                        Label(String(localized: "analytics.options.menu", defaultValue: "Options"),
                              systemImage: "ellipsis.circle")
                    }
                    .disabled(committedTerm.isEmpty)
                    .help(String(localized: "analytics.options.help",
                                 defaultValue: "Values, fit line, and chart colors."))
                }
            }
        } else {
            // Measure: documents vs occurrences (PR-D). Same two axes as normalisation, for the same
            // underlying reason — those are the axes with a per-period series. Disabled rather than
            // hidden when the query has no honest occurrence count, so the control's absence never
            // has to be inferred; `occurrenceNotice` says why.
            if measureApplies {
                ToolbarItem(placement: .primaryAction) {
                    Picker(
                        String(localized: "analytics.measure.picker", defaultValue: "Measure"),
                        selection: $storedValueUnit
                    ) {
                        ForEach(AnalyticsValueUnit.allCases, id: \.self) { unit in
                            Text(unit.pickerLabel).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(committedTerm.isEmpty || !occurrenceAvailability.isAvailable)
                    .help(String(
                        localized: "analytics.measure.help",
                        defaultValue: "Count matching documents, or every occurrence of the word. A term mentioned fifty times in one document is one document and fifty occurrences — the two can move in opposite directions."
                    ))
                }
            }

            // Normalization: raw count vs % of documents (CA-4). Only meaningful for the
            // date-based By-Year / By-Decade axes, so it is hidden for the others.
            if normalizationApplies {
                ToolbarItem(placement: .primaryAction) {
                    Picker(
                        String(localized: "analytics.normalize.picker", defaultValue: "Values"),
                        selection: normalizationBinding
                    ) {
                        ForEach(AnalyticsNormalizationMode.allCases, id: \.self) { mode in
                            Text(mode.pickerLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(committedTerm.isEmpty || viewMode != .chart)
                    .help(String(
                        localized: "analytics.normalize.help",
                        defaultValue: "Plot raw matching-document counts, or each period's matches as a share of all indexed documents in that period — so a rising corpus size doesn't masquerade as a rising term."
                    ))
                }
            }

            // Axis granularity moved to the "Group by" chip in the consolidated filter row (Wave B).

            // Fit-line toggle. Only meaningful on date-based charts.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFitLine.toggle()
                } label: {
                    Label(
                        showFitLine
                            ? String(localized: "analytics.fitLine.hide", defaultValue: "Hide fit line")
                            : String(localized: "analytics.fitLine.show", defaultValue: "Show fit line"),
                        systemImage: showFitLine ? "chart.line.uptrend.xyaxis" : "chart.bar"
                    )
                }
                .disabled(committedTerm.isEmpty || !chartAxis.isDateBased || viewMode != .chart || isComparing)
                .help(
                    String(localized: "analytics.fitLine.help",
                           defaultValue: "Toggle the smoothed trend line overlay on the chart.")
                )
            }

            // Colored-volume count — how many source volumes get a distinct color on the
            // By-Year / By-Decade charts before the rest fold into "Other".
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker(selection: $seriesCount) {
                        ForEach(Array(ChartSeriesPalette.range), id: \.self) { n in
                            Text(verbatim: "\(n)").tag(n)
                        }
                    } label: {
                        Text(String(localized: "analytics.colors.count", defaultValue: "Colored volumes"))
                    }
                } label: {
                    Label(String(localized: "analytics.colors.menu", defaultValue: "Chart colors"),
                          systemImage: "paintpalette")
                }
                .disabled(committedTerm.isEmpty || !chartAxis.isDateBased || viewMode != .chart || isComparing)
                .help(String(localized: "analytics.colors.help",
                             defaultValue: "How many source volumes appear as distinct colors before the rest fold into “Other”"))
            }
        }

        // D1 Phase 3: star the current query, and a menu of saved + recent queries. On compact
        // width the two fold into ONE menu (the save toggle becomes its first item) — the iPhone
        // nav bar already sheds its title to fit the existing controls (#219), so adding two more
        // items would crowd the view-mode picker (review fix).
        if horizontalSizeClass == .compact {
            ToolbarItem(placement: .primaryAction) {
                savedQueriesMenu(includingSaveToggle: true)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                saveQueryButton
            }
            ToolbarItem(placement: .primaryAction) {
                savedQueriesMenu(includingSaveToggle: false)
            }
        }

        // D3: research-grade export. Corpus shows one chart at a time, so the control is view-level
        // (owner decision H). At regular width it is its own toolbar menu; on compact width it folds
        // into the existing Options menu instead of adding a nav-bar item (#219, D1 Phase 3).
        if horizontalSizeClass != .compact {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    exportMenuItems
                } label: {
                    Label(String(localized: "analytics.export.menu", defaultValue: "Export"),
                          systemImage: "square.and.arrow.up")
                }
                .disabled(!canExport)
                .help(String(localized: "analytics.export.menu.help",
                             defaultValue: "Export this chart's data with its method and caveats"))
            }
        }

        // Info button — explains metric semantics, query syntax, and stemming. Win 7: now the
        // shared FeatureInfoButton (copy preserved verbatim via `analytics.info.*` keys), matching
        // Person and Cross-Reference Analytics.
        ToolbarItem(placement: .primaryAction) {
            FeatureInfoButton.corpusAnalytics
        }

        // Done button — iOS sheet only; macOS windows use the close button.
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "analytics.done", defaultValue: "Done")) {
                dismiss()
            }
        }
        #endif
    }

    /// The export actions (D3), shared by the regular-width toolbar menu and the compact Options
    /// menu. Phase 0 ships the data table; the figure formats join here in the figure phase.
    @ViewBuilder
    private var exportMenuItems: some View {
        Button {
            exportCSV()
        } label: {
            Label(String(localized: "analytics.export.csv", defaultValue: "Chart data (CSV)…"),
                  systemImage: "tablecells")
        }
        .disabled(!canExport)
        Button {
            exportFigure(.png)
        } label: {
            Label(String(localized: "analytics.export.png", defaultValue: "Figure (PNG)…"),
                  systemImage: "photo")
        }
        .disabled(!canExportFigure)
        Button {
            exportFigure(.pdf)
        } label: {
            Label(String(localized: "analytics.export.pdf", defaultValue: "Figure (PDF)…"),
                  systemImage: "doc.richtext")
        }
        .disabled(!canExportFigure)
    }

    /// The star that saves / un-saves the current query (D1 Phase 3). Filled once the current
    /// terms · axis · range · scope match a saved entry.
    private var saveQueryButton: some View {
        Button {
            toggleSaveCurrentQuery()
        } label: {
            Label(isCurrentQuerySaved
                  ? String(localized: "analytics.saved.starred", defaultValue: "Saved")
                  : String(localized: "analytics.saved.save", defaultValue: "Save query"),
                  systemImage: isCurrentQuerySaved ? "star.fill" : "star")
        }
        .disabled(committedTerms.isEmpty)
        .help(String(localized: "analytics.saved.star.help",
                     defaultValue: "Save this query (terms, axis, year range, and scope) to revisit later"))
    }

    /// The saved / recent queries menu (D1 Phase 3). Each entry restores the whole query — terms,
    /// axis, year range, and scope — and re-runs it.
    ///
    /// - Parameter includingSaveToggle: When `true` (compact width) the save/un-save action leads the
    ///   menu, so the two controls occupy a single nav-bar slot.
    private func savedQueriesMenu(includingSaveToggle: Bool) -> some View {
        Menu {
            if includingSaveToggle {
                saveQueryButton
                Divider()
            }
            if savedQueries.isEmpty && recentQueries.isEmpty {
                Text(String(localized: "analytics.saved.empty", defaultValue: "No saved or recent queries"))
            } else {
                if !savedQueries.isEmpty {
                    Section(String(localized: "analytics.saved.section.saved", defaultValue: "Saved")) {
                        ForEach(savedQueries) { q in
                            Button(q.menuLabel) { restoreQuery(q) }
                        }
                    }
                }
                if !recentQueries.isEmpty {
                    Section(String(localized: "analytics.saved.section.recent", defaultValue: "Recent")) {
                        ForEach(recentQueries) { q in
                            Button(q.menuLabel) { restoreQuery(q) }
                        }
                    }
                }
            }
        } label: {
            Label(String(localized: "analytics.saved.menu", defaultValue: "Saved queries"),
                  systemImage: "bookmark")
        }
        .help(String(localized: "analytics.saved.menu.help", defaultValue: "Jump to a saved or recent query"))
    }

    /// The secondary chart controls, folded into the toolbar's "Options" menu on compact
    /// (iPhone) width where the nav bar cannot hold them inline. On regular width these
    /// render as separate toolbar items instead (see `toolbarContent`). Controls that only
    /// apply to date-based charts are shown conditionally rather than disabled, keeping the
    /// menu concise (#188-A).
    @ViewBuilder
    private var compactChartOptionsMenu: some View {
        // D3: export leads the menu on compact width, where it has no nav-bar item of its own.
        if canExport {
            Section(String(localized: "analytics.export.section", defaultValue: "Export")) {
                exportMenuItems
            }
        }
        // Axis granularity moved to the filter row's "Group by" chip (Wave B).
        // Measure (PR-D) leads the normalisation picker: it decides WHAT is counted, and "Values"
        // only decides whether that is divided by a denominator.
        if measureApplies {
            Picker(selection: $storedValueUnit) {
                ForEach(AnalyticsValueUnit.allCases, id: \.self) { unit in
                    Text(unit.pickerLabel).tag(unit)
                }
            } label: {
                Text(String(localized: "analytics.measure.picker", defaultValue: "Measure"))
            }
            .disabled(committedTerm.isEmpty || !occurrenceAvailability.isAvailable)
        }
        if normalizationApplies {
            Picker(selection: normalizationBinding) {
                ForEach(AnalyticsNormalizationMode.allCases, id: \.self) { mode in
                    Text(mode.pickerLabel).tag(mode)
                }
            } label: {
                Text(String(localized: "analytics.normalize.picker", defaultValue: "Values"))
            }
            .disabled(viewMode != .chart)
        }

        if chartAxis.isDateBased && viewMode == .chart && !isComparing {
            Divider()
            Toggle(isOn: $showFitLine) {
                Label(String(localized: "analytics.fitLine.toggle", defaultValue: "Fit line"),
                      systemImage: "chart.line.uptrend.xyaxis")
            }
            Picker(selection: $seriesCount) {
                ForEach(Array(ChartSeriesPalette.range), id: \.self) { n in
                    Text(verbatim: "\(n)").tag(n)
                }
            } label: {
                Text(String(localized: "analytics.colors.count", defaultValue: "Colored volumes"))
            }
        }
    }

    // MARK: - Search Action

    /// Commits a search term and loads its data. Defaults to the live text field (`termInput`) for
    /// the user-typed Search / Return path; callers re-running for a state change (e.g. a scope
    /// change) call `reloadData()` directly so they never depend on the field's current contents.
    ///
    /// D1 Phase 1: a Search press commits exactly one term (a later phase lets the user add up to
    /// five). The fan-out over `committedTerms` in `reloadData()` already handles a multi-term set.
    private func runSearch(term explicitTerm: String? = nil) {
        let term = (explicitTerm ?? termInput).trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        committedTerms = [term]
        reloadData()
    }

    /// Fetches the per-axis chart data for every committed term (D1). The term-independent document
    /// totals (the % denominator) are fetched once, and the per-volume source-color breakdown only
    /// for a single term (it drives coloring that is dropped while comparing). A monotonic
    /// `fetchToken` discards a stale run when the term set changes mid-fetch.
    private func reloadData() {
        guard let service = appState.analyticsService else { return }
        fetchToken &+= 1
        let token = fetchToken
        let terms = committedTerms
        guard !terms.isEmpty else {
            // Nothing committed — clear every result surface.
            yearDataByTerm = [:]; decadeDataByTerm = [:]; monthDataByTerm = [:]
            dayDataByTerm = [:]; subseriesDataByTerm = [:]; volumeDataByTerm = [:]
            yearVolumeData = []; documentTotalsByYear = [:]; documentTotalsByDecade = [:]
            occurrenceYearDataByTerm = [:]
            occurrenceAvailability = .unavailable(reason: .noPositiveTerm)
            errorMessage = nil   // clear a stale error so removing the last term shows the empty state
            isLoading = false
            return
        }
        recordRecentQuery()   // D1 Phase 3: remember this committed query
        isLoading = true
        errorMessage = nil
        yearDataByTerm = [:]; decadeDataByTerm = [:]; monthDataByTerm = [:]
        dayDataByTerm = [:]; subseriesDataByTerm = [:]; volumeDataByTerm = [:]
        yearVolumeData = []
        documentTotalsByYear = [:]; documentTotalsByDecade = [:]
        occurrenceYearDataByTerm = [:]
        // Restrict every axis to the active volume-ID scope (Word Cloud → Analytics handoff);
        // `nil`/empty means the whole corpus, the default presentation.
        let scope: Set<String>? = scopeVolumeIds.map(Set.init)
        let singleTerm = terms.count == 1
        // Read once, here: `storedValueUnit` can change mid-fetch, and a task that decided to skip
        // the occurrence query must not later be treated as though it had run it.
        let unit = storedValueUnit
        Task {
            do {
                // Term-independent corpus document totals (the % of documents denominator, CA-4),
                // fetched once with the same scope as the numerator so a scoped share is a correct
                // within-scope proportion.
                async let totalsYear   = service.documentTotalsByYear(volumeIds: scope)
                async let totalsDecade = service.documentTotalsByDecade(volumeIds: scope)
                // Per-volume source-color breakdown drives single-term coloring only (dropped while
                // comparing), so fetch it only for a lone committed term.
                let yearVolumes = singleTerm
                    ? try await service.termFrequencyByYearAndVolume(term: terms[0], volumeIds: scope)
                    : []
                // Per-term axis data. The service methods are already single-term and per-term
                // cached, so re-running after adding a term only re-hits the DB for the new term.
                var years:     [String: [YearFrequency]]      = [:]
                var decades:   [String: [DecadeFrequency]]    = [:]
                var months:    [String: [MonthFrequency]]     = [:]
                var days:      [String: [DayFrequency]]       = [:]
                var subseries: [String: [SubseriesFrequency]] = [:]
                var volumes:   [String: [VolumeFrequency]]    = [:]
                // Occurrences (PR-D): only for a single committed term, and only when the shape has
                // an honest count. Compare mode is excluded deliberately — the availability notice
                // names ONE reason, and a mixed set where some chips are countable and others are not
                // would need per-chip suppression the chart cannot express without inventing a
                // legend for absence.
                var occurrenceYears: [String: [YearFrequency]] = [:]
                let availability = singleTerm
                    ? await service.occurrenceAvailability(for: terms[0])
                    : OccurrenceAvailability.unavailable(reason: .compositeQuery)
                // Fetched only when the researcher is actually looking at occurrences. It was
                // unconditional, which made toggling the Measure picker instant — at the price of
                // every single-word search paying for a measure most sessions never use. Measured on
                // the owner's iPhone with all 552 volumes indexed, that was a noticeable delay for
                // `state` and `the`. `availability` above stays unconditional: it is one tokenizer
                // probe, and the picker's enabled state and the notice both depend on it whether or
                // not the series is wanted.
                if singleTerm, unit == .occurrences, availability.isAvailable {
                    occurrenceYears[terms[0]] = try await service.termOccurrencesByYear(
                        term: terms[0], volumeIds: scope)
                }
                for term in terms {
                    async let y  = service.termFrequencyByYear(term: term, volumeIds: scope)
                    async let d  = service.termFrequencyByDecade(term: term, volumeIds: scope)
                    async let m  = service.termFrequencyByMonth(term: term, volumeIds: scope)
                    async let dd = service.termFrequencyByDay(term: term, volumeIds: scope)
                    async let s  = service.termFrequencyBySubseries(term: term, volumeIds: scope)
                    async let v  = service.termFrequencyByVolume(term: term, volumeIds: scope)
                    years[term]     = try await y
                    decades[term]   = try await d
                    months[term]    = try await m
                    days[term]      = try await dd
                    subseries[term] = try await s
                    volumes[term]   = try await v
                }
                let ty = try await totalsYear
                let td = try await totalsDecade
                // Discard this run if a newer term set superseded it mid-fetch.
                guard token == fetchToken else { return }
                yearDataByTerm = years
                decadeDataByTerm = decades
                monthDataByTerm = months
                dayDataByTerm = days
                subseriesDataByTerm = subseries
                volumeDataByTerm = volumes
                yearVolumeData = yearVolumes
                documentTotalsByYear = ty
                documentTotalsByDecade = td
                occurrenceYearDataByTerm = occurrenceYears
                occurrenceAvailability = availability
            } catch {
                guard token == fetchToken else { return }
                errorMessage = error.localizedDescription
            }
            if token == fetchToken { isLoading = false }
        }
    }
}
