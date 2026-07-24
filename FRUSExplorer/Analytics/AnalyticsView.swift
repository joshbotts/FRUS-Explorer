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
enum AnalyticsChartAxis: String, CaseIterable {
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
    @State private var committedTerm: String = ""
    @State private var yearData: [YearFrequency] = []
    /// Per-`(year, volume)` breakdown driving the source color-coding of the By-Year
    /// and By-Decade charts. Fetched alongside `yearData` so the two stay consistent.
    @State private var yearVolumeData: [YearVolumeFrequency] = []
    @State private var decadeData: [DecadeFrequency] = []
    @State private var monthData: [MonthFrequency] = []
    @State private var dayData: [DayFrequency] = []
    @State private var subseriesData: [SubseriesFrequency] = []
    @State private var volumeData: [VolumeFrequency] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var chartAxis: AnalyticsChartAxis = .byYear

    /// Start year for the chart x-axis and year-data filter. Defaults to 1861
    /// (the year of the first FRUS volume).
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

    /// `true` when normalized (`% of documents`) plotting is active for the current
    /// axis — the preference is on AND the axis supports it.
    private var isNormalized: Bool {
        normalizationApplies && normalizationMode == .percentOfDocuments
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
                    VStack(spacing: 0) {
                        // Wave B: one consolidated filter row (term + scope / range / group-by chips)
                        // replaces the four stacked bars, so the chart lands above the fold.
                        filterRow
                        if chartAxis.isCategorical && !committedTerm.isEmpty {
                            categoricalYearNote
                        }
                        Divider()
                        // Hide the hand-off link when there's nothing to view — during the async
                        // fetch (data arrays momentarily empty) or a genuine zero-match term (Win 3).
                        if !committedTerm.isEmpty && matchedDocumentCount > 0 {
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
        // Seed the default year-range end from the corpus span, then apply any
        // constructor parameter (iOS sheet presentation — a fresh `AnalyticsView`
        // instance is created each time the sheet opens).
        .task {
            seriesCount = defaultSeriesCount
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
        openWindow(id: "frus.search")
        bringMacWindowToFront(id: "frus.search")
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
        switch chartAxis {
        case .byYear:      return filteredYearData.reduce(0) { $0 + $1.count }
        case .byDecade:    return filteredDecadeData.reduce(0) { $0 + $1.count }
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Consolidated filter row (Wave B)

    /// The term entry field (split out of the old `searchBar` so it can sit in the filter row).
    private var termField: some View {
        TextField(
            String(localized: "analytics.term.placeholder", defaultValue: "Term…"),
            text: $termInput
        )
        .textFieldStyle(.roundedBorder)
        .onSubmit { runSearch() }
    }

    /// The Search trigger button.
    private var searchButton: some View {
        Button(String(localized: "analytics.search.button", defaultValue: "Search")) {
            runSearch()
        }
        .buttonStyle(.borderedProminent)
        .disabled(termInput.trimmingCharacters(in: .whitespaces).isEmpty)
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
                guard !committedTerm.isEmpty else { return }
                runSearch(term: committedTerm)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            scopeChip
                            yearChip
                            groupByChip
                            adminPresetChip
                        }
                        .padding(.vertical, 1)
                    }
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
        } else if isAllResultDataEmpty {
            ContentUnavailableView(
                String(localized: "analytics.empty.title", defaultValue: "No Results"),
                systemImage: "chart.bar",
                description: Text(
                    String(localized: "analytics.empty.detail",
                           defaultValue: "No indexed documents match \"\(committedTerm)\".")
                )
            )
        } else {
            switch viewMode {
            case .chart:
                chartContent
            case .table:
                tableContent
            }
        }
    }

    /// `true` iff every backing data array is empty — used for the "No Results"
    /// state regardless of which granularity is currently selected.
    private var isAllResultDataEmpty: Bool {
        yearData.isEmpty
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
                    Text(verbatim: "\(s.total)")
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
    private var valueAxisLabel: String {
        isNormalized
            ? String(localized: "analytics.axis.percentOfDocuments", defaultValue: "% of documents")
            : String(localized: "analytics.axis.documents", defaultValue: "Documents")
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
        return String(
            format: String(localized: "analytics.chart.source.count.a11y %lld",
                           defaultValue: "%lld documents"),
            Int64(count))
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
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Year")
            )
            .font(.headline)
            .padding(.horizontal)

            if !coloring.series.isEmpty {
                sourceLegend(coloring.series)
            }

            Chart {
                ForEach(coloring.segments) { seg in
                    // In `% of documents` mode the segment height is its share of the
                    // year's corpus total; a year with a missing/zero total is omitted
                    // (divide-by-zero guard). Raw mode plots the count unchanged.
                    if let y = normalizedValue(count: seg.count, period: seg.period, totals: documentTotalsByYear) {
                        BarMark(
                            x: .value(
                                String(localized: "analytics.axis.year", defaultValue: "Year"),
                                seg.period
                            ),
                            y: .value(valueAxisLabel, y)
                        )
                        .foregroundStyle(by: .value(
                            String(localized: "analytics.chart.source.series", defaultValue: "Volume"),
                            seg.seriesKey
                        ))
                        .accessibilityLabel(Text(verbatim: "\(seg.period), \(sourceTitle(seg.seriesKey))"))
                        .accessibilityValue(Text(sourceValueA11y(count: seg.count, plotted: y)))
                    }
                }
                if showFitLine {
                    ForEach(data) { point in
                        if let y = normalizedValue(count: point.count, period: point.year, totals: documentTotalsByYear) {
                            LineMark(
                                x: .value(
                                    String(localized: "analytics.axis.year", defaultValue: "Year"),
                                    point.year
                                ),
                                y: .value(valueAxisLabel, y)
                            )
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
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: integerNoGroupingFormat)
                }
            }
            .chartYAxis { valueAxisMarks }
            .chartXAxisLabel(
                String(localized: "analytics.axis.year", defaultValue: "Year"),
                alignment: .center
            )
            .chartYAxisLabel(valueAxisLabel)
            .frame(height: 280)
            .padding(.horizontal)

            normalizationCaption
                .padding(.horizontal)

            totalsFootnote(filtered: totalFiltered, total: totalAllYears)
                .padding(.horizontal)
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
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Decade")
            )
            .font(.headline)
            .padding(.horizontal)

            if !coloring.series.isEmpty {
                sourceLegend(coloring.series)
            }

            Chart {
                ForEach(coloring.segments) { seg in
                    // Normalized: the segment's share of the decade's corpus total (a
                    // decade with a missing/zero total is omitted). Raw: the count.
                    if let y = normalizedValue(count: seg.count, period: seg.period, totals: documentTotalsByDecade) {
                        BarMark(
                            x: .value(
                                String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                                seg.period
                            ),
                            y: .value(valueAxisLabel, y),
                            width: .ratio(0.8)
                        )
                        .foregroundStyle(by: .value(
                            String(localized: "analytics.chart.source.series", defaultValue: "Volume"),
                            seg.seriesKey
                        ))
                        .accessibilityLabel(Text(verbatim: "\(seg.period)s, \(sourceTitle(seg.seriesKey))"))
                        .accessibilityValue(Text(sourceValueA11y(count: seg.count, plotted: y)))
                    }
                }
                if showFitLine {
                    ForEach(data) { point in
                        if let y = normalizedValue(count: point.count, period: point.decadeStart, totals: documentTotalsByDecade) {
                            LineMark(
                                x: .value(
                                    String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                                    point.decadeStart
                                ),
                                y: .value(valueAxisLabel, y)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.primary.opacity(0.5))
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: scale.domain, range: scale.range)
            .chartLegend(.hidden)
            .chartXScale(domain: yearRangeStart...yearRangeEnd)
            .chartYAxis { valueAxisMarks }
            .chartXAxis {
                AxisMarks(values: .stride(by: 10)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: integerNoGroupingFormat)
                }
            }
            .chartXAxisLabel(
                String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                alignment: .center
            )
            .chartYAxisLabel(valueAxisLabel)
            .frame(height: 280)
            .padding(.horizontal)

            normalizationCaption
                .padding(.horizontal)

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
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
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Month")
            )
            .font(.headline)
            .padding(.horizontal)

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
                                String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                                    String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                    String(localized: "analytics.axis.documents", defaultValue: "Documents")
                )
                .frame(height: 280)
                .padding(.horizontal)
            }

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
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
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Day")
            )
            .font(.headline)
            .padding(.horizontal)

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
                                String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                                    String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                    String(localized: "analytics.axis.documents", defaultValue: "Documents")
                )
                .frame(height: 280)
                .padding(.horizontal)
            }

            totalsFootnote(filtered: totalFiltered, total: totalAll)
                .padding(.horizontal)
        }
        .padding(.vertical)
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
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
                String(localized: "analytics.axis.documents", defaultValue: "Documents"),
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
        Text(
            String(
                format: String(localized: "analytics.total %lld",
                               defaultValue: "%lld documents matched"),
                Int64(count)
            )
        )
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
        List(rows) { row in
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
            AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: committedTerm.isEmpty)
        }

        if horizontalSizeClass == .compact {
            // iPhone: fold the secondary chart controls into a single "Options" menu (mirrors
            // WordCloudView). On regular width they render inline below (#188-A). Shown only when the
            // menu would have content — after Wave B moved axis granularity to the filter row's
            // "Group by" chip, a categorical axis leaves normalization + fit-line/colors all
            // inapplicable, so an un-gated button would open an empty menu (R3).
            if normalizationApplies || (chartAxis.isDateBased && viewMode == .chart) {
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
            // Normalization: raw count vs % of documents (CA-4). Only meaningful for the
            // date-based By-Year / By-Decade axes, so it is hidden for the others.
            if normalizationApplies {
                ToolbarItem(placement: .primaryAction) {
                    Picker(
                        String(localized: "analytics.normalize.picker", defaultValue: "Values"),
                        selection: $normalizationMode
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
                .disabled(committedTerm.isEmpty || !chartAxis.isDateBased || viewMode != .chart)
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
                .disabled(committedTerm.isEmpty || !chartAxis.isDateBased || viewMode != .chart)
                .help(String(localized: "analytics.colors.help",
                             defaultValue: "How many source volumes appear as distinct colors before the rest fold into “Other”"))
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

    /// The secondary chart controls, folded into the toolbar's "Options" menu on compact
    /// (iPhone) width where the nav bar cannot hold them inline. On regular width these
    /// render as separate toolbar items instead (see `toolbarContent`). Controls that only
    /// apply to date-based charts are shown conditionally rather than disabled, keeping the
    /// menu concise (#188-A).
    @ViewBuilder
    private var compactChartOptionsMenu: some View {
        // Axis granularity moved to the filter row's "Group by" chip (Wave B).
        if normalizationApplies {
            Picker(selection: $normalizationMode) {
                ForEach(AnalyticsNormalizationMode.allCases, id: \.self) { mode in
                    Text(mode.pickerLabel).tag(mode)
                }
            } label: {
                Text(String(localized: "analytics.normalize.picker", defaultValue: "Values"))
            }
            .disabled(viewMode != .chart)
        }

        if chartAxis.isDateBased && viewMode == .chart {
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

    /// Runs the analytics query. Defaults to the live text field (`termInput`) for the
    /// user-typed Search / Return path; callers re-running for a state change (e.g. a scope
    /// change) pass the already-committed term explicitly so they never depend on the field's
    /// current contents.
    private func runSearch(term explicitTerm: String? = nil) {
        let term = (explicitTerm ?? termInput).trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, let service = appState.analyticsService else { return }
        committedTerm = term
        isLoading = true
        errorMessage = nil
        yearData = []
        yearVolumeData = []
        decadeData = []
        monthData = []
        dayData = []
        subseriesData = []
        volumeData = []
        documentTotalsByYear = [:]
        documentTotalsByDecade = [:]
        // Restrict every axis to the active volume-ID scope (Word Cloud → Analytics
        // handoff); `nil`/empty means the whole corpus, the default presentation.
        let scope: Set<String>? = scopeVolumeIds.map(Set.init)
        Task {
            do {
                // Fetch every granularity in parallel so switching between
                // Year / Decade / Month / Day / Subseries is instantaneous after
                // the initial Search press.
                async let years       = service.termFrequencyByYear(term: term, volumeIds: scope)
                async let yearVolumes = service.termFrequencyByYearAndVolume(term: term, volumeIds: scope)
                async let decades     = service.termFrequencyByDecade(term: term, volumeIds: scope)
                async let months      = service.termFrequencyByMonth(term: term, volumeIds: scope)
                async let days        = service.termFrequencyByDay(term: term, volumeIds: scope)
                async let subseries   = service.termFrequencyBySubseries(term: term, volumeIds: scope)
                async let volumes     = service.termFrequencyByVolume(term: term, volumeIds: scope)
                // Corpus document totals (the % of documents denominator, CA-4) —
                // fetched with the same scope as the numerator so a scoped share is a
                // correct within-scope proportion.
                async let totalsYear   = service.documentTotalsByYear(volumeIds: scope)
                async let totalsDecade = service.documentTotalsByDecade(volumeIds: scope)
                yearData      = try await years
                yearVolumeData = try await yearVolumes
                decadeData    = try await decades
                monthData     = try await months
                dayData       = try await days
                subseriesData = try await subseries
                volumeData    = try await volumes
                documentTotalsByYear   = try await totalsYear
                documentTotalsByDecade = try await totalsDecade
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
