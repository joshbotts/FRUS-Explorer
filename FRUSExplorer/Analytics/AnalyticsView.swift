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
struct AnalyticsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var termInput: String = ""
    @State private var committedTerm: String = ""
    @State private var yearData: [YearFrequency] = []
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

    /// User preference: whether to overlay a smoothed trend line on date-bucketed
    /// charts. Defaults to true. Has no effect on the by-subseries horizontal
    /// bar chart, which never plots a line.
    @State private var showFitLine: Bool = true

    /// Drives the info popover next to the toolbar pickers.
    @State private var showInfoPopover: Bool = false

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.analyticsService == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        searchBar
                        if chartAxis.isDateBased && !committedTerm.isEmpty {
                            Divider()
                            yearRangeBar
                        }
                        if !committedTerm.isEmpty {
                            Divider()
                            searchHandoffBar
                        }
                        Divider()
                        contentArea
                    }
                }
            }
            .navigationTitle(
                String(localized: "analytics.title", defaultValue: "Corpus Analytics")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
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
            seedDefaultYearRange()
            applyAnalyticsParameters(initialParameters)
        }
        // Re-seed when a new handoff arrives while the view is already on screen
        // (macOS `frus.analytics` Window — a long-lived instance reused across
        // openWindow calls). `MainWindowView` opens the window; this clears the
        // pending value once consumed, mirroring `MacSearchWindowView`'s
        // `pendingSearch` handling.
        .onChange(of: appState.pendingAnalytics) { _, params in
            guard let params else { return }
            applyAnalyticsParameters(params)
            appState.pendingAnalytics = nil
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
        appState.pendingSearch = SearchParameters(keywords: committedTerm, dateRange: range)
        #if DEBUG
        print("[AnalyticsView] Handoff to Search — term: \"\(committedTerm)\", dateRange: \(String(describing: range))")
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
        appState.pendingSearch = SearchParameters(keywords: committedTerm, volumeIds: volumeIds)
        #if DEBUG
        print("[AnalyticsView] Scoped handoff to Search — term: \"\(committedTerm)\", volumes: \(volumeIds.count)")
        #endif
        navigateToSearch()
    }

    /// Shared navigation tail for both handoff paths.
    ///
    /// On iOS, Analytics is a sheet over the Browse tab — switch to the Search tab
    /// (now pre-filled via `pendingSearch`) and dismiss the sheet. On macOS, Analytics
    /// is a standalone `frus.analytics` Window; setting `pendingSearch` is enough —
    /// `MainWindowView`/`BrowserView` open the search window/inspector and apply the
    /// parameters, and the analytics window stays open for side-by-side comparison.
    private func navigateToSearch() {
        #if os(iOS)
        appState.activeTab = .search
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

    // MARK: - Year Range Bar

    /// Compact year-range filter shown below the search field when the "By Year"
    /// axis is active. Steppers adjust `yearRangeStart` and `yearRangeEnd`;
    /// a "Reset" link appears when the range has been customised.
    private var yearRangeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(String(localized: "analytics.yearRange.label",
                        defaultValue: "Year range:"))
                .font(.caption)
                .foregroundStyle(.secondary)

            yearEntryField(
                value: $yearRangeStart,
                bounds: 1776...yearRangeEnd,
                accessibilityLabel: String(localized: "analytics.yearRange.start.a11y",
                                           defaultValue: "Start year")
            )

            Text(verbatim: "–")
                .foregroundStyle(.tertiary)
                .font(.caption)

            yearEntryField(
                value: $yearRangeEnd,
                bounds: yearRangeStart...corpusMaxYear,
                accessibilityLabel: String(localized: "analytics.yearRange.end.a11y",
                                           defaultValue: "End year")
            )

            if yearRangeIsCustom {
                Button {
                    yearRangeStart = 1861
                    yearRangeEnd = corpusMaxYear
                } label: {
                    Text(String(localized: "analytics.yearRange.reset",
                                defaultValue: "Reset"))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .help(String(
                    localized: "analytics.yearRange.reset.help",
                    defaultValue: "Reset the year range to 1861 – current year (the full FRUS corpus span)"
                ))
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// A year value rendered as an editable, clamped text field paired with an
    /// up/down stepper. Typing commits a value (clamped into `bounds`), letting
    /// the user jump directly to a year instead of stepping one at a time; the
    /// stepper remains for fine adjustment.
    private func yearEntryField(
        value: Binding<Int>,
        bounds: ClosedRange<Int>,
        accessibilityLabel: String
    ) -> some View {
        // Clamp on write so a typed (or stepped) value can never escape `bounds`.
        let clamped = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = min(max($0, bounds.lowerBound), bounds.upperBound) }
        )
        return Stepper(value: clamped, in: bounds) {
            TextField(
                String(localized: "analytics.yearRange.field.placeholder", defaultValue: "Year"),
                value: clamped,
                format: .number.grouping(.never)
            )
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .frame(width: 44)
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Search Handoff Bar

    /// Direction-A handoff affordance: "Analytics → Search".
    ///
    /// Shown beneath the search/year-range bars whenever a term has been
    /// committed. Lets the researcher jump straight from "how is this term
    /// distributed across the corpus?" to "show me the matching documents" —
    /// carrying the term and (for date-based axes) the current year-range filter
    /// along as `pendingSearch` so Search lands pre-filled and ready to run.
    private var searchHandoffBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(
                chartAxis.isDateBased
                    ? String(
                        localized: "analytics.handoff.prompt.dated",
                        defaultValue: "See the \(yearRangeStart)–\(yearRangeEnd) documents behind this chart"
                      )
                    : String(
                        localized: "analytics.handoff.prompt.plain",
                        defaultValue: "See the documents behind this chart"
                      )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                openMatchingDocumentsInSearch()
            } label: {
                Text(String(localized: "analytics.handoff.button",
                            defaultValue: "View in Search"))
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
            .help(String(
                localized: "analytics.handoff.help",
                defaultValue: "Switch to Search pre-filled with this term — and this year range, if a date-based view is active — to see the matching documents"
            ))
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField(
                String(localized: "analytics.term.placeholder", defaultValue: "Term…"),
                text: $termInput
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { runSearch() }

            Button(String(localized: "analytics.search.button", defaultValue: "Search")) {
                runSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(termInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
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

    private var yearChartSection: some View {
        let data = filteredYearData
        let totalAllYears = yearData.reduce(0) { $0 + $1.count }
        let totalFiltered = data.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.year.heading",
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Year")
            )
            .font(.headline)
            .padding(.horizontal)

            Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value(
                            String(localized: "analytics.axis.year", defaultValue: "Year"),
                            point.year
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
                                String(localized: "analytics.axis.year", defaultValue: "Year"),
                                point.year
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
            .chartXScale(domain: yearRangeStart...yearRangeEnd)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: integerNoGroupingFormat)
                }
            }
            .chartXAxisLabel(
                String(localized: "analytics.axis.year", defaultValue: "Year"),
                alignment: .center
            )
            .chartYAxisLabel(
                String(localized: "analytics.axis.documents", defaultValue: "Documents")
            )
            .frame(height: 280)
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
        return VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.decade.heading",
                       defaultValue: "\"\(committedTerm)\" \u{2014} by Decade")
            )
            .font(.headline)
            .padding(.horizontal)

            Chart {
                ForEach(data) { point in
                    BarMark(
                        x: .value(
                            String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                            point.decadeStart
                        ),
                        y: .value(
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
                            point.count
                        ),
                        width: .ratio(0.8)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.65))
                }
                if showFitLine {
                    ForEach(data) { point in
                        LineMark(
                            x: .value(
                                String(localized: "analytics.axis.decade", defaultValue: "Decade"),
                                point.decadeStart
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
            .chartXScale(domain: yearRangeStart...yearRangeEnd)
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
            .chartYAxisLabel(
                String(localized: "analytics.axis.documents", defaultValue: "Documents")
            )
            .frame(height: 280)
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
        // View mode: chart vs table
        ToolbarItem(placement: .primaryAction) {
            Picker(
                String(localized: "analytics.viewMode.picker", defaultValue: "Display"),
                selection: $viewMode
            ) {
                Image(systemName: "chart.bar")
                    .tag(AnalyticsViewMode.chart)
                    .accessibilityLabel(
                        String(localized: "analytics.viewMode.chart.a11y", defaultValue: "Chart")
                    )
                Image(systemName: "list.bullet")
                    .tag(AnalyticsViewMode.table)
                    .accessibilityLabel(
                        String(localized: "analytics.viewMode.table.a11y", defaultValue: "Table")
                    )
            }
            .pickerStyle(.segmented)
            .disabled(committedTerm.isEmpty)
            .help(String(
                localized: "analytics.viewMode.picker.help",
                defaultValue: "Switch between chart visualisation and a tabular list of the same data"
            ))
        }

        // Axis: granularity picker (decade / year / month / day / subseries)
        ToolbarItem(placement: .primaryAction) {
            Picker(
                String(localized: "analytics.axis.picker", defaultValue: "Group by"),
                selection: $chartAxis
            ) {
                ForEach(AnalyticsChartAxis.allCases, id: \.self) { axis in
                    Text(axis.pickerLabel).tag(axis)
                }
            }
            .disabled(committedTerm.isEmpty)
            .help(String(
                localized: "analytics.axis.picker.help",
                defaultValue: "Choose how to bucket results: by decade, year, month, day, or subseries"
            ))
        }

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

        // Info button — explains metric semantics, query syntax, and stemming.
        ToolbarItem(placement: .primaryAction) {
            Button {
                showInfoPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .accessibilityLabel(
                        String(localized: "analytics.info.a11y", defaultValue: "About these results")
                    )
            }
            .help(String(
                localized: "analytics.info.help",
                defaultValue: "What do the numbers mean? Multi-word handling, phrases, stemming, and how dates are determined."
            ))
            .popover(isPresented: $showInfoPopover, arrowEdge: .top) {
                infoPopoverContent
            }
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

    // MARK: - Info Popover

    /// Content of the info popover. Explains:
    /// - What the bar height represents (unique documents containing the term,
    ///   not total mentions)
    /// - How multi-word queries are interpreted (whitespace-AND, individual
    ///   Porter stemming)
    /// - That phrases are not supported in analytics
    /// - That the chart bucket is the document date (TEI `<date>`), not the
    ///   volume publication date
    private var infoPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "analytics.info.heading",
                        defaultValue: "About these results"))
                .font(.headline)

            infoRow(
                title: String(localized: "analytics.info.metric.title",
                              defaultValue: "What the numbers mean"),
                body:  String(localized: "analytics.info.metric.body",
                              defaultValue: "Each bar shows the number of indexed FRUS documents that contain your search term in that period. A document that mentions the term ten times is counted once.")
            )
            infoRow(
                title: String(localized: "analytics.info.multiword.title",
                              defaultValue: "Multiple words"),
                body:  String(localized: "analytics.info.multiword.body",
                              defaultValue: "Words separated by spaces are combined with AND: national security matches documents containing both words. OR (either term) and NOT / leading - (exclude a term) work too, exactly as in the Search box.")
            )
            infoRow(
                title: String(localized: "analytics.info.phrase.title",
                              defaultValue: "Phrases"),
                body:  String(localized: "analytics.info.phrase.body",
                              defaultValue: "Wrap words in quotes for an ordered phrase: \"missile crisis\" matches only documents where those words appear together, in that order. Analytics and Search interpret the same query identically, so the counts here match what Search returns.")
            )
            infoRow(
                title: String(localized: "analytics.info.stemming.title",
                              defaultValue: "Stemming"),
                body:  String(localized: "analytics.info.stemming.body",
                              defaultValue: "English stemming is applied: searching for \"negotiate\" also matches \"negotiating\", \"negotiated\", and \"negotiations\".")
            )
            infoRow(
                title: String(localized: "analytics.info.dating.title",
                              defaultValue: "How dates are determined"),
                body:  String(localized: "analytics.info.dating.body",
                              defaultValue: "Each document is placed at its TEI <date> attribute — the date of authorship, not the volume's publication date. Documents lacking month or day precision are excluded from the By Month and By Day charts.")
            )
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder
    private func infoRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Search Action

    private func runSearch() {
        let term = termInput.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, let service = appState.analyticsService else { return }
        committedTerm = term
        isLoading = true
        errorMessage = nil
        yearData = []
        decadeData = []
        monthData = []
        dayData = []
        subseriesData = []
        volumeData = []
        Task {
            do {
                // Fetch every granularity in parallel so switching between
                // Year / Decade / Month / Day / Subseries is instantaneous after
                // the initial Search press.
                async let years     = service.termFrequencyByYear(term: term)
                async let decades   = service.termFrequencyByDecade(term: term)
                async let months    = service.termFrequencyByMonth(term: term)
                async let days      = service.termFrequencyByDay(term: term)
                async let subseries = service.termFrequencyBySubseries(term: term)
                async let volumes   = service.termFrequencyByVolume(term: term)
                yearData      = try await years
                decadeData    = try await decades
                monthData     = try await months
                dayData       = try await days
                subseriesData = try await subseries
                volumeData    = try await volumes
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
