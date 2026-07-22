// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - ChronologyView

/// Corpus-wide chronological browser: pick a date range and read every document in the
/// indexed corpus that falls within it, grouped into date sections.
///
/// Built on `IndexingPipeline.documentsInDateRange`. Distinct from `DocumentTimelineView`
/// (which visualizes a supplied result set) — this is a primary browsing surface.
///
/// ## Dense dates
/// Sections over `denseThreshold` rows (e.g. a summit or crisis) collapse to a preview
/// with a "Show all N" expander, and the section header summarises the cluster (count,
/// volumes, subseries, editorial notes) with an inline density bar.
///
/// ## Platform placement
/// - **iOS**: sheet from the Browse tab toolbar (mirrors Corpus Analytics).
/// - **macOS**: standalone `frus.chronology` Window.
///
/// Version history:
///   1.0 — Session 163: initial implementation
struct ChronologyView: View {

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var vm = ChronologyViewModel(
        rangeStart: ChronologyView.defaultStart,
        rangeEnd: ChronologyView.defaultEnd
    )
    @State private var navigationPath: [DocumentBrowserEntry] = []
    @State private var expandedSections: Set<String> = []
    @State private var didSeedDefaults = false
    /// Whether the distribution chart pane is shown (toolbar toggle).
    @State private var showChart = true
    /// Whether the wide-span ("spans this period") section is expanded.
    @State private var showSpanning = false
    /// Whether the "extends beyond this range" overflow section is expanded.
    @State private var showOverflow = false
    #if os(macOS)
    /// Bucket key currently under the pointer, driving the hover magnifier (macOS only).
    @State private var hoveredBucketKey: String? = nil
    #endif
    /// Active legend filter: a volume ID (or `chronologyOtherSeriesKey`) restricting the
    /// list to documents from that volume. `nil` = show all.
    @State private var selectedSeries: String? = nil

    /// Global default colored-series count, mirrored from Display settings.
    @AppStorage(ChartSeriesPalette.storageKey) private var defaultSeriesCount = ChartSeriesPalette.defaultCount
    /// Per-view colored-series count, seeded from the global default; overrides it for
    /// this session via the chart-colors menu.
    @State private var seriesCount = ChartSeriesPalette.defaultCount

    /// Parameters this view was opened with (a `pendingChronology` handoff). Applied once.
    private let initialParameters: ChronologyParameters?

    /// Rows shown in a dense section before the "Show all" expander.
    private static let denseThreshold = 25

    /// `id` of the spanning section, used as a scroll target from its chip.
    private static let spanningSectionID = "__chronology_spanning__"

    /// `id` of the overflow ("extends beyond this range") section, a scroll target from its chip.
    private static let overflowSectionID = "__chronology_overflow__"

    init(initialParameters: ChronologyParameters? = nil) {
        self.initialParameters = initialParameters
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if appState.indexingPipeline == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        rangeBar
                        Divider()
                        contentArea
                    }
                }
            }
            // iOS omits the nav title to unify the "no-title" pattern across the analytics family
            // and give the toolbar its full width (#219); the accessible screen name is preserved
            // via .accessibilityLabel. macOS keeps the title for its window title bar.
            #if os(macOS)
            .navigationTitle(String(localized: "chronology.title", defaultValue: "Chronology"))
            #else
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "chronology.title", defaultValue: "Chronology"))
            #endif
            // iOS pushes the document inline. On macOS a row routes to the provenance host
            // instead (owner decision D1) — the old inline push mounted a
            // `MacDocumentView(navigationPath: .constant([]))` whose constant binding
            // silently broke cross-reference taps and prev/next (the same defect the
            // Citation Lookup window fixed in #239).
            #if os(iOS)
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                DocumentView(entry: entry)
            }
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task { seedDefaultsAndApply(initialParameters) }
        .onChange(of: seriesCount) { _, newCount in vm.applySeriesCount(newCount) }
        // Re-seed when a new hand-off arrives while the macOS `frus.chronology` singleton is open
        // (`.macChronology`). iOS seeds via `initialParameters` (BrowserView), so on iOS this consumes
        // nothing (the hand-off targets the producing window, not `.macChronology`).
        .onChange(of: appState.pendingChronology) { _, _ in
            guard let params = appState.consumeHandoff(\.pendingChronology, for: .macChronology) else { return }
            apply(params)
        }
    }

    // MARK: - Defaults & handoff

    /// Placeholder range used before the manifest is consulted — a representative FRUS
    /// year, replaced on first appearance by the corpus's most recent year.
    private static let defaultStart = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 1969, month: 1, day: 1)) ?? .distantPast
    private static let defaultEnd = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 1969, month: 12, day: 31)) ?? .now

    /// On first appearance, point the VM at the pipeline and default the range to the
    /// corpus's most recent year (unless a handoff seeds an explicit range).
    private func seedDefaultsAndApply(_ params: ChronologyParameters?) {
        vm.pipeline = appState.indexingPipeline
        seriesCount = defaultSeriesCount
        vm.seriesCount = defaultSeriesCount
        // Explicit parameters (the iOS sheet) take priority; otherwise pick up a pending
        // macOS-window handoff set just before `openWindow` (which won't fire `.onChange`
        // because the value is already in place when this fresh window appears).
        if let params {
            apply(params)
            return
        }
        if let pending = appState.consumeHandoff(\.pendingChronology, for: .macChronology) {
            apply(pending)
            return
        }
        guard !didSeedDefaults else { return }
        didSeedDefaults = true
        let corpus = appState.manifestStore.corpusDateRange
        let cal = Calendar(identifier: .gregorian)
        vm.rangeEnd = corpus.upperBound
        vm.rangeStart = cal.date(byAdding: .year, value: -1, to: corpus.upperBound) ?? corpus.lowerBound
    }

    /// Applies a seeded date range and loads immediately.
    private func apply(_ params: ChronologyParameters) {
        didSeedDefaults = true
        if let start = params.rangeStart { vm.rangeStart = start }
        if let end = params.rangeEnd { vm.rangeEnd = end }
        reload()
    }

    /// Clears any active legend filter, then reloads the current range. Routing every
    /// reload through here prevents a stale volume filter persisting across a new query.
    private func reload() {
        selectedSeries = nil
        Task { await vm.reload() }
    }

    /// Opens a word cloud over the documents in the currently displayed date range —
    /// the inverse of the word cloud's "View in Chronology" handoff.
    private func openWordCloudForRange() {
        let scope = WordCloudScope.dateRange(
            startISO: WordCloudScope.isoDay(from: min(vm.rangeStart, vm.rangeEnd)),
            endISO: WordCloudScope.isoDay(from: max(vm.rangeStart, vm.rangeEnd))
        )
        appState.openWordCloud(scope, from: sceneID)
        #if os(macOS)
        // The word cloud inherits this Chronology window's provenance (transitive bind).
        appState.bindTool(.wordCloud, to: appState.provenance(of: .chronology))
        openWindow(id: "frus.wordcloud")
        bringMacWindowToFront(id: "frus.wordcloud")
        #else
        // The word cloud is presented at the tab-container level (MainTabView) on iOS;
        // dismiss this sheet so it can present on the `pendingWordCloud` change.
        dismiss()
        #endif
    }

    // MARK: - Range Bar

    private var rangeBar: some View {
        VStack(spacing: 8) {
            HStack {
                DatePicker(
                    String(localized: "chronology.range.from", defaultValue: "From"),
                    selection: $vm.rangeStart,
                    in: ...vm.rangeEnd,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                Text(verbatim: "–").foregroundStyle(.tertiary)
                DatePicker(
                    String(localized: "chronology.range.to", defaultValue: "To"),
                    selection: $vm.rangeEnd,
                    in: vm.rangeStart...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                Spacer()
                Button {
                    reload()
                } label: {
                    Text(String(localized: "chronology.show", defaultValue: "Show"))
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)
            }
            if vm.hasLoaded && !vm.groups.isEmpty {
                HStack(spacing: 12) {
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        searchInRange()
                    } label: {
                        Label(
                            String(localized: "chronology.searchRange", defaultValue: "Search in this range"),
                            systemImage: "magnifyingglass"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var summaryLine: String {
        let docs = vm.totalShown
        let base = String(
            format: String(localized: "chronology.summary %lld", defaultValue: "%lld documents"),
            Int64(docs)
        )
        if vm.chartShowsFullDistribution {
            // The chart reflects the full range (`docs` is the true total); the list below
            // is capped, so the headline count and the chart are complete while only the
            // browsable rows are limited.
            return base + " " + String(
                localized: "chronology.summary.chartFull",
                defaultValue: "(chart shows all; list shows the first \(ChronologyViewModel.loadLimit) — narrow the range to browse them)")
        }
        return vm.isCapped
            ? base + " " + String(localized: "chronology.summary.capped",
                                   defaultValue: "(showing the first \(ChronologyViewModel.loadLimit) — narrow the range)")
            : base
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorMessage {
            ContentUnavailableView(
                String(localized: "chronology.error.title", defaultValue: "Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if !vm.hasLoaded {
            ContentUnavailableView(
                String(localized: "chronology.prompt.title", defaultValue: "Choose a Date Range"),
                systemImage: "calendar",
                description: Text(String(
                    localized: "chronology.prompt.detail",
                    defaultValue: "Pick a start and end date, then tap Show to browse every corpus document from that period."
                ))
            )
        } else if vm.groups.isEmpty && vm.spanningRows.isEmpty && vm.overflowRows.isEmpty {
            ContentUnavailableView(
                String(localized: "chronology.empty.title", defaultValue: "No Documents"),
                systemImage: "calendar.badge.exclamationmark",
                description: Text(String(
                    localized: "chronology.empty.detail",
                    defaultValue: "No indexed documents fall within this date range. Try widening it or indexing more volumes."
                ))
            )
        } else {
            loadedContent
        }
    }

    private var maxSectionCount: Int {
        max(1, displayedGroups.map(\.count).max() ?? 1)
    }

    // MARK: - Legend filter

    /// Volume IDs that have their own coloured series (everything not folded into "Other").
    private var topSeriesKeys: Set<String> {
        Set(vm.chartSeries.map(\.key).filter { $0 != chronologyOtherSeriesKey })
    }

    /// Whether a row passes the active legend filter (always `true` when no filter is set).
    private func rowMatchesFilter(_ row: ChronologyRow) -> Bool {
        guard let selected = selectedSeries else { return true }
        if selected == chronologyOtherSeriesKey { return !topSeriesKeys.contains(row.volumeId) }
        return row.volumeId == selected
    }

    /// Placed date groups after applying the legend filter — groups left empty are dropped,
    /// and per-group provenance counts are recomputed from the surviving rows.
    private var displayedGroups: [ChronologyDateGroup] {
        guard selectedSeries != nil else { return vm.groups }
        return vm.groups.compactMap { group in
            let rows = group.rows.filter(rowMatchesFilter)
            guard !rows.isEmpty else { return nil }
            let subseries = Set(rows.compactMap { CorpusAnalyticsService.subseries(fromVolumeId: $0.volumeId) })
            return ChronologyDateGroup(
                bucketKey: group.bucketKey,
                granularity: group.granularity,
                sortDate: group.sortDate,
                displayLabel: group.displayLabel,
                rows: rows,
                volumeCount: Set(rows.map(\.volumeId)).count,
                subseriesCount: subseries.count,
                editorialNoteCount: rows.filter(\.isEditorialNote).count
            )
        }
    }

    /// Spanning rows after applying the legend filter.
    private var displayedSpanningRows: [ChronologyRow] {
        vm.spanningRows.filter(rowMatchesFilter)
    }

    /// Overflow rows (uncertain dates straddling the range bounds) after the legend filter.
    private var displayedOverflowRows: [ChronologyRow] {
        vm.overflowRows.filter(rowMatchesFilter)
    }

    /// The chart pane (pinned above), the spanning chip, and the scrolling section list,
    /// all inside one `ScrollViewReader` so the chart and chip can scroll the list.
    private var loadedContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if showChart && !vm.chartBuckets.isEmpty {
                    chartPane(scrollProxy: proxy)
                    Divider()
                }
                if !displayedSpanningRows.isEmpty {
                    spanningChip(scrollProxy: proxy)
                    Divider()
                }
                if !displayedOverflowRows.isEmpty {
                    overflowChip(scrollProxy: proxy)
                    Divider()
                }
                sectionList
            }
        }
    }

    private var sectionList: some View {
        List {
            ForEach(displayedGroups) { group in
                Section {
                    let visible = isExpanded(group) ? group.rows : Array(group.rows.prefix(Self.denseThreshold))
                    ForEach(visible) { row in
                        Button {
                            open(row)
                        } label: {
                            ChronologyRowView(row: row, volumeTitle: volumeTitle(row.volumeId))
                        }
                        .buttonStyle(.plain)
                    }
                    if group.count > Self.denseThreshold && !isExpanded(group) {
                        Button {
                            expandedSections.insert(group.bucketKey)
                        } label: {
                            Text(String(
                                format: String(localized: "chronology.showAll %lld",
                                               defaultValue: "Show all %lld documents on this date"),
                                Int64(group.count)
                            ))
                            .font(.subheadline)
                        }
                    }
                } header: {
                    sectionHeader(group)
                }
                .id(group.bucketKey)
            }

            if showSpanning {
                spanningSection
            }

            if showOverflow {
                overflowSection
            }

            if vm.totalShown > 0 {
                Section {
                    Text(String(localized: "chronology.undated.note",
                                defaultValue: "Documents without a machine-readable date are not shown."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    // MARK: - Distribution Chart

    /// Series colour for a given legend index; the folded "Other" key is always gray.
    private func seriesColor(_ key: String, index: Int) -> Color {
        key == chronologyOtherSeriesKey
            ? Color.gray
            : ChartSeriesPalette.color(at: index)
    }

    /// Colours in `vm.chartSeries` order — shared by the chart's foreground scale and the
    /// legend swatches so they always agree.
    private var seriesColors: [Color] {
        vm.chartSeries.enumerated().map { seriesColor($0.element.key, index: $0.offset) }
    }

    /// Human label for a series key: a volume title, or "Other volumes" for the fold.
    private func seriesTitle(_ key: String) -> String {
        key == chronologyOtherSeriesKey
            ? String(localized: "chronology.chart.other", defaultValue: "Other volumes")
            : distilledVolumeLabel(key)
    }

    /// Chart x-axis bucket unit, matching the view model's range-driven coarsening.
    private var chartUnit: Calendar.Component {
        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: min(vm.rangeStart, vm.rangeEnd), to: max(vm.rangeStart, vm.rangeEnd)).day ?? 0
        if days <= ChronologyViewModel.dayGroupingMaxDays { return .day }
        if days <= ChronologyViewModel.monthGroupingMaxDays { return .month }
        return .year
    }

    /// Inclusive x-domain that anchors the chart to the loaded range (rounded out to whole
    /// buckets by the view model). A one-unit nudge avoids a degenerate zero-width domain
    /// when the range collapses to a single bucket.
    private var chartXDomain: ClosedRange<Date> {
        let lower = vm.chartDomainStart
        var upper = vm.chartDomainEnd
        if upper <= lower {
            upper = Calendar(identifier: .gregorian).date(byAdding: chartUnit, value: 1, to: lower) ?? lower.addingTimeInterval(86_400)
        }
        return lower...upper
    }

    private func chartPane(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            chartLegend
            if let selected = selectedSeries {
                filterIndicator(selected)
            }
            distributionChart(scrollProxy: scrollProxy)
                .frame(height: 150)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// Textual legend — the non-colour channel for volume identity (each entry names the
    /// volume and its count), so the chart's colour encoding is fully available to
    /// VoiceOver and colour-blind users. Each entry is also a toggle that filters the list
    /// to that volume.
    private var chartLegend: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(Array(vm.chartSeries.enumerated()), id: \.element.id) { index, series in
                Button {
                    selectedSeries = (selectedSeries == series.key) ? nil : series.key
                } label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(seriesColor(series.key, index: index))
                            .frame(width: 10, height: 10)
                        Text(seriesTitle(series.key))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(verbatim: "\(series.total)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                    }
                    .opacity(legendOpacity(series.key))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(String(
                    format: String(localized: "chronology.chart.legend.a11y %@ %lld",
                                   defaultValue: "%@, %lld documents"),
                    seriesTitle(series.key), Int64(series.total)
                )))
                .accessibilityAddTraits(selectedSeries == series.key ? .isSelected : [])
                .accessibilityHint(Text(String(localized: "chronology.chart.legend.hint",
                                               defaultValue: "Filters the list to this volume")))
            }
        }
    }

    /// Dim non-selected legend entries when a filter is active so the active volume stands
    /// out without relying on colour alone.
    private func legendOpacity(_ key: String) -> Double {
        guard let selected = selectedSeries else { return 1 }
        return key == selected ? 1 : 0.35
    }

    /// Active-filter banner with a clear control, shown below the legend.
    private func filterIndicator(_ key: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(Color.accentColor)
                .font(.caption)
                .accessibilityHidden(true)
            Text(String(
                format: String(localized: "chronology.filter.active %@",
                               defaultValue: "Showing %@ only"),
                seriesTitle(key)
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                selectedSeries = nil
            } label: {
                Text(String(localized: "chronology.filter.clear", defaultValue: "Show all"))
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
    }

    private func distributionChart(scrollProxy: ScrollViewProxy) -> some View {
        Chart {
            ForEach(vm.chartBuckets) { bucket in
                ForEach(bucket.segments) { segment in
                    BarMark(
                        x: .value(String(localized: "chronology.chart.x", defaultValue: "Date"),
                                  bucket.date, unit: chartUnit),
                        y: .value(String(localized: "chronology.chart.y", defaultValue: "Documents"),
                                  segment.count)
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "chronology.chart.series", defaultValue: "Volume"),
                        segment.seriesKey
                    ))
                    // Each stacked segment is individually described so a VoiceOver user
                    // hears the date, volume, and count without seeing the colour.
                    .accessibilityLabel(Text("\(bucket.label), \(seriesTitle(segment.seriesKey))"))
                    .accessibilityValue(Text(String(
                        format: String(localized: "chronology.chart.count.a11y %lld",
                                       defaultValue: "%lld documents"),
                        Int64(segment.count)
                    )))
                }
            }
        }
        .chartForegroundStyleScale(domain: vm.chartSeries.map(\.key), range: seriesColors)
        .chartLegend(.hidden)
        .chartXScale(domain: chartXDomain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let nearest = bucket(near: location, proxy: proxy, geo: geo) {
                            withAnimation { scrollProxy.scrollTo(nearest.bucketKey, anchor: .top) }
                        }
                    }
                    #if os(macOS)
                    // Pointer-only enhancement: hovering a bar reveals a finer breakdown of
                    // that slice. The same counts remain in the list and legend, so nothing
                    // becomes hover-only.
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredBucketKey = bucket(near: location, proxy: proxy, geo: geo)?.bucketKey
                        case .ended:
                            hoveredBucketKey = nil
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        // The magnifier breaks the hovered bucket down one level finer. For the
                        // full-range aggregate chart (list capped) the loaded rows are
                        // incomplete, so it reads the precomputed aggregate breakdown instead;
                        // otherwise it derives the breakdown from the loaded date group.
                        if let key = hoveredBucketKey {
                            if vm.chartShowsFullDistribution,
                               let bucket = vm.chartBuckets.first(where: { $0.bucketKey == key }) {
                                magnifierCard(title: bucket.label,
                                              total: bucket.total,
                                              bars: vm.aggregatedMagnifierBars[key] ?? [])
                                    .offset(x: magnifierOffsetX(forBucketKey: key, proxy: proxy, geo: geo))
                                    .allowsHitTesting(false)
                            } else if let group = vm.groups.first(where: { $0.bucketKey == key }) {
                                magnifierCard(for: group)
                                    .offset(x: magnifierOffsetX(forBucketKey: key, proxy: proxy, geo: geo))
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    #endif
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(Text(String(
            localized: "chronology.chart.a11y",
            defaultValue: "Document distribution over the selected dates, stacked by volume. Counts are listed in the legend and in each date section below."
        )))
    }

    /// Maps a point in the chart overlay to the nearest `chartBuckets` entry, or `nil` when
    /// the point falls outside the plot. Shared by the tap-to-scroll and macOS hover paths.
    private func bucket(near location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> ChronologyChartBucket? {
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let xInPlot = location.x - geo[plotAnchor].origin.x
        guard let target: Date = proxy.value(atX: xInPlot) else { return nil }
        return vm.chartBuckets.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        })
    }

    #if os(macOS)
    // MARK: - Hover Magnifier (macOS)

    /// Maximum mini-bars shown in the magnifier before a "+N more" line.
    private static let magnifierMaxBars = 14

    /// Floating card shown on macOS hover: a finer-grained breakdown (months within a year,
    /// days within a month, or volumes within a day) of the bucket under the pointer.
    /// Card width — wider for the per-volume breakdown so the volume-specific titles read.
    private static let magnifierCardWidth: CGFloat = 210

    /// Convenience for the row-based (non-capped) path, breaking a loaded date group down.
    private func magnifierCard(for group: ChronologyDateGroup) -> some View {
        magnifierCard(title: group.displayLabel,
                      total: group.count,
                      bars: ChronologyViewModel.magnifierBreakdown(for: group))
    }

    private func magnifierCard(title: String, total: Int, bars: [ChronologyMagnifierBar]) -> some View {
        let shown = Array(bars.prefix(Self.magnifierMaxBars))
        let maxCount = max(1, shown.map(\.count).max() ?? 1)
        // Day buckets break down by volume; the per-volume rows put the (long) volume name on
        // its own line so the titles stay legible. Month/year buckets break down by short
        // date labels, which read fine inline. Volume bars carry a series key.
        let isVolumeBreakdown = bars.first?.seriesKey != nil
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Text(verbatim: "\(total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(shown) { bar in
                if isVolumeBreakdown {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(magnifierBarLabel(bar))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Capsule()
                                .fill(magnifierBarColor(bar))
                                .frame(width: max(3, 150 * CGFloat(bar.count) / CGFloat(maxCount)), height: 6)
                            Text(verbatim: "\(bar.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(magnifierBarLabel(bar))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 46, alignment: .trailing)
                        Capsule()
                            .fill(magnifierBarColor(bar))
                            .frame(width: max(3, 70 * CGFloat(bar.count) / CGFloat(maxCount)), height: 6)
                        Text(verbatim: "\(bar.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                    }
                }
            }
            if bars.count > shown.count {
                Text(String(
                    format: String(localized: "chronology.magnifier.more %lld",
                                   defaultValue: "+%lld more"),
                    Int64(bars.count - shown.count)
                ))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(width: Self.magnifierCardWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        .shadow(radius: 4, y: 2)
        .padding(.top, 4)
    }

    /// Display label for a magnifier bar — for per-volume bars the *volume-specific* title
    /// (dropping the shared series + subseries prefix so truncated names stay distinguishable);
    /// otherwise the pre-formatted month/day label.
    private func magnifierBarLabel(_ bar: ChronologyMagnifierBar) -> String {
        bar.seriesKey != nil ? distilledVolumeLabel(bar.label) : bar.label
    }

    /// The volume-specific portion of a full FRUS title — everything from "Volume …" onward,
    /// so "Foreign Relations of the United States, 1969–1976, Volume II, Organization and
    /// Management, 1969–1972" reads as "Volume II, Organization and Management, 1969–1972".
    /// Falls back to the full title for the rare volume whose title has no "Volume" segment
    /// (e.g. a named retrospective).

    /// Colour for a magnifier bar — the matching series colour for per-volume bars, else accent.
    private func magnifierBarColor(_ bar: ChronologyMagnifierBar) -> Color {
        guard let key = bar.seriesKey,
              let idx = vm.chartSeries.firstIndex(where: { $0.key == key }) else {
            return Color.accentColor
        }
        return seriesColor(key, index: idx)
    }

    /// Horizontal offset that centres the magnifier card over the hovered bar, clamped to the
    /// chart width.
    private func magnifierOffsetX(forBucketKey key: String, proxy: ChartProxy, geo: GeometryProxy) -> CGFloat {
        guard let bucket = vm.chartBuckets.first(where: { $0.bucketKey == key }),
              let plotAnchor = proxy.plotFrame,
              let x = proxy.position(forX: bucket.date) else { return 0 }
        let cardWidth = Self.magnifierCardWidth
        let raw = geo[plotAnchor].origin.x + x - cardWidth / 2
        return min(max(0, raw), max(0, geo.size.width - cardWidth))
    }
    #endif

    // MARK: - Spanning ("spans this period") section

    /// Chip beneath the chart summarising the wide-span documents excluded from the
    /// day-level list, and toggling their dedicated section.
    private func spanningChip(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation { showSpanning.toggle() }
            if showSpanning {
                withAnimation { scrollProxy.scrollTo(Self.spanningSectionID, anchor: .top) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(
                    format: String(localized: "chronology.spanning.chip %lld",
                                   defaultValue: "%lld editorial notes span this whole period"),
                    Int64(displayedSpanningRows.count)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: showSpanning ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(
            format: String(localized: "chronology.spanning.chip.a11y %lld",
                           defaultValue: "%lld editorial notes span the whole period. Toggle to show them."),
            Int64(displayedSpanningRows.count)
        )))
    }

    @ViewBuilder
    private var spanningSection: some View {
        Section {
            ForEach(displayedSpanningRows) { row in
                Button {
                    open(row)
                } label: {
                    ChronologyRowView(row: row, volumeTitle: volumeTitle(row.volumeId), spanLabel: spanLabel(row))
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "chronology.spanning.header", defaultValue: "Spans this period"))
                .textCase(nil)
        } footer: {
            Text(String(localized: "chronology.spanning.footer",
                        defaultValue: "These documents (mostly editorial notes) cover a span of dates rather than a single day, so they're listed here instead of on the timeline."))
                .font(.caption2)
        }
        .id(Self.spanningSectionID)
    }

    /// Year–year label for a spanning row, e.g. "1952–1975".
    private func spanLabel(_ row: ChronologyRow) -> String {
        let start = String(row.dateISO.prefix(4))
        let end = row.dateISOMax.map { String($0.prefix(4)) } ?? start
        return start == end ? start : "\(start)\u{2013}\(end)"
    }

    // MARK: - Overflow ("extends beyond this range") section

    /// Number of overflow rows that begin before / end after the loaded range, for the chip.
    private var overflowCounts: (leading: Int, trailing: Int) {
        var leading = 0, trailing = 0
        for row in displayedOverflowRows {
            let dir = ChronologyViewModel.overflowDirection(row, startISO: vm.loadedStartISO, endISO: vm.loadedEndISO)
            if dir.leading { leading += 1 }
            if dir.trailing { trailing += 1 }
        }
        return (leading, trailing)
    }

    /// Chip beneath the chart summarising the uncertain documents whose interval straddles a
    /// range boundary, and toggling their dedicated section.
    private func overflowChip(scrollProxy: ScrollViewProxy) -> some View {
        let counts = overflowCounts
        return Button {
            withAnimation { showOverflow.toggle() }
            if showOverflow {
                withAnimation { scrollProxy.scrollTo(Self.overflowSectionID, anchor: .top) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(
                    format: String(localized: "chronology.overflow.chip %lld",
                                   defaultValue: "%lld documents extend beyond this range"),
                    Int64(displayedOverflowRows.count)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(verbatim: overflowBreakdownText(counts))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: showOverflow ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(
            format: String(localized: "chronology.overflow.chip.a11y %lld",
                           defaultValue: "%lld documents have uncertain dates that extend beyond this range. Toggle to show them."),
            Int64(displayedOverflowRows.count)
        )))
    }

    /// "(2 before · 1 after)" breakdown for the overflow chip.
    private func overflowBreakdownText(_ counts: (leading: Int, trailing: Int)) -> String {
        var parts: [String] = []
        if counts.leading > 0 {
            parts.append(String(format: String(localized: "chronology.overflow.before %lld",
                                                defaultValue: "%lld before"), Int64(counts.leading)))
        }
        if counts.trailing > 0 {
            parts.append(String(format: String(localized: "chronology.overflow.after %lld",
                                                defaultValue: "%lld after"), Int64(counts.trailing)))
        }
        return parts.isEmpty ? "" : "(" + parts.joined(separator: " \u{00b7} ") + ")"
    }

    @ViewBuilder
    private var overflowSection: some View {
        Section {
            ForEach(displayedOverflowRows) { row in
                Button {
                    open(row)
                } label: {
                    ChronologyRowView(row: row, volumeTitle: volumeTitle(row.volumeId), spanLabel: overflowDirectionLabel(row))
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(String(localized: "chronology.overflow.header", defaultValue: "Extends beyond this range"))
                .textCase(nil)
        } footer: {
            Text(String(localized: "chronology.overflow.footer",
                        defaultValue: "These documents overlap your range but their dates are imprecise enough to reach before or after it, so they're listed here rather than placed on the chart."))
                .font(.caption2)
        }
        .id(Self.overflowSectionID)
    }

    /// Direction annotation for an overflow row, e.g. "begins 1961 · before range" or
    /// "ends 1970 · after range" (or both when the interval encloses the whole range).
    private func overflowDirectionLabel(_ row: ChronologyRow) -> String {
        let dir = ChronologyViewModel.overflowDirection(row, startISO: vm.loadedStartISO, endISO: vm.loadedEndISO)
        var parts: [String] = []
        if dir.leading {
            parts.append(String(format: String(localized: "chronology.overflow.begins %@",
                                                defaultValue: "begins %@ · before range"),
                                 String(row.dateISO.prefix(4))))
        }
        if dir.trailing {
            let end = row.dateISOMax.map { String($0.prefix(4)) } ?? String(row.dateISO.prefix(4))
            parts.append(String(format: String(localized: "chronology.overflow.ends %@",
                                                defaultValue: "ends %@ · after range"), end))
        }
        return parts.joined(separator: " \u{00b7} ")
    }

    private func sectionHeader(_ group: ChronologyDateGroup) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(group.displayLabel)
                    .font(.headline)
                Text(verbatim: "\(group.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                Spacer()
                densityBar(count: group.count)
            }
            Text(aggregateLine(group))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .textCase(nil)
    }

    private func densityBar(count: Int) -> some View {
        let fraction = CGFloat(count) / CGFloat(maxSectionCount)
        return Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 56, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: max(3, 56 * fraction), height: 5)
            }
            .accessibilityHidden(true)
    }

    private func aggregateLine(_ group: ChronologyDateGroup) -> String {
        var parts: [String] = []
        parts.append(String(format: String(localized: "chronology.agg.volumes %lld",
                                            defaultValue: "%lld volumes"), Int64(group.volumeCount)))
        parts.append(String(format: String(localized: "chronology.agg.subseries %lld",
                                            defaultValue: "%lld subseries"), Int64(group.subseriesCount)))
        if group.editorialNoteCount > 0 {
            parts.append(String(format: String(localized: "chronology.agg.editorial %lld",
                                               defaultValue: "%lld editorial notes"), Int64(group.editorialNoteCount)))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showChart.toggle()
            } label: {
                Label(
                    showChart
                        ? String(localized: "chronology.chart.hide", defaultValue: "Hide chart")
                        : String(localized: "chronology.chart.show", defaultValue: "Show chart"),
                    systemImage: showChart ? "chart.bar.fill" : "chart.bar"
                )
            }
            .disabled(!vm.hasLoaded || vm.chartBuckets.isEmpty)
            .help(String(localized: "chronology.chart.toggle.help",
                         defaultValue: "Show or hide the document distribution chart"))
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.ascending.toggle()
                if vm.hasLoaded { reload() }
            } label: {
                Label(
                    vm.ascending
                        ? String(localized: "chronology.sort.oldest", defaultValue: "Oldest first")
                        : String(localized: "chronology.sort.newest", defaultValue: "Newest first"),
                    systemImage: vm.ascending ? "arrow.up" : "arrow.down"
                )
            }
            .disabled(!vm.hasLoaded)
            .help(String(localized: "chronology.sort.help",
                         defaultValue: "Toggle chronological order"))
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(selection: $seriesCount) {
                    ForEach(Array(ChartSeriesPalette.range), id: \.self) { n in
                        Text(verbatim: "\(n)").tag(n)
                    }
                } label: {
                    Text(String(localized: "chronology.colors.count", defaultValue: "Colored volumes"))
                }
            } label: {
                Label(String(localized: "chronology.colors.menu", defaultValue: "Chart colors"),
                      systemImage: "paintpalette")
            }
            .disabled(!vm.hasLoaded || vm.chartBuckets.isEmpty)
            .help(String(localized: "chronology.colors.help",
                         defaultValue: "How many volumes appear as distinct colors before the rest fold into “Other”"))
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                openWordCloudForRange()
            } label: {
                Label {
                    Text(String(localized: "chronology.wordcloud", defaultValue: "Word Cloud for this range"))
                } icon: {
                    Image(systemName: WordCloudGlyph.symbol)
                }
            }
            .disabled(!vm.hasLoaded || vm.totalShown == 0)
            .help(String(localized: "chronology.wordcloud.help",
                         defaultValue: "Build a word cloud from the documents in the displayed date range"))
        }
        ToolbarItem(placement: .primaryAction) {
            FeatureInfoButton(
                heading: String(localized: "chronology.info.heading", defaultValue: "About Chronology"),
                items: [
                    FeatureInfoItem(
                        title: String(localized: "chronology.info.shows.title", defaultValue: "What you're seeing"),
                        detail: String(localized: "chronology.info.shows.detail",
                                       defaultValue: "Every indexed document whose date falls within the range you pick, grouped into date sections that coarsen (days → months → years) as the range widens.")),
                    FeatureInfoItem(
                        title: String(localized: "chronology.info.dates.title", defaultValue: "How dates work"),
                        detail: String(localized: "chronology.info.dates.detail",
                                       defaultValue: "Each document sits at its TEI date, and is shown no more precisely than its source supports — with the precision (day/month/year) and certainty (exact vs. approximate) preserved.")),
                    FeatureInfoItem(
                        title: String(localized: "chronology.info.chart.title", defaultValue: "The distribution chart"),
                        detail: String(localized: "chronology.info.chart.detail",
                                       defaultValue: "The stacked chart colour-codes documents by source volume (the top volumes, then a grey “Other”). Use the chart-colours menu to choose how many volumes get a distinct colour.")),
                    FeatureInfoItem(
                        title: String(localized: "chronology.info.cap.title", defaultValue: "Wide ranges"),
                        detail: String(localized: "chronology.info.cap.detail",
                                       defaultValue: "The document list is capped at 5,000, but the chart still reflects the whole range; the summary line reports the true total so you can narrow the range.")),
                ]
            )
            .disabled(!vm.hasLoaded)
        }
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "chronology.done", defaultValue: "Done")) { dismiss() }
        }
        #endif
    }

    // MARK: - Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "chronology.unavailable.title", defaultValue: "Chronology Unavailable"),
            systemImage: "calendar",
            description: Text(String(
                localized: "chronology.unavailable.detail",
                defaultValue: "The search index is not available. Index at least one volume to browse by date."
            ))
        )
    }

    // MARK: - Helpers

    private func isExpanded(_ group: ChronologyDateGroup) -> Bool {
        expandedSections.contains(group.bucketKey)
    }

    private func volumeTitle(_ volumeId: String) -> String {
        appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    /// Distilled, distinct, descriptive volume label for the chart legend and magnifier
    /// (e.g. "Southeast Asia · 1969-76 v20"), resolved from the manifest entry.
    private func distilledVolumeLabel(_ volumeId: String) -> String {
        let entry = appState.manifestStore.entry(forVolumeId: volumeId)
        return ChronologyViewModel.distilledVolumeLabel(
            volumeId: volumeId,
            subseries: entry?.subseries ?? "",
            title: entry?.title ?? volumeId
        )
    }

    /// Opens a chronology row: pushed inline on iOS; routed to this window's provenance
    /// host on macOS (owner decision D1 — the broken inline embed is deleted).
    private func open(_ row: ChronologyRow) {
        let entry = DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            documentNumber: row.documentNumber,
            header: row.header,
            dateline: row.dateline,
            sourceNote: nil,
            isEditorialNote: row.isEditorialNote
        )
        #if os(macOS)
        appState.openDocument(entry, from: .tool(.chronology), using: openWindow)
        #else
        navigationPath.append(entry)
        #endif
    }

    /// Hand off to Search with the current range pre-applied as a date filter.
    private func searchInRange() {
        let cal = Calendar(identifier: .gregorian)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        let range = DateRange(
            earliest: fmt.string(from: cal.startOfDay(for: min(vm.rangeStart, vm.rangeEnd))),
            latest: fmt.string(from: cal.startOfDay(for: max(vm.rangeStart, vm.rangeEnd)))
        )
        appState.pendingSearch = SearchParameters(dateRange: range)
        #if DEBUG
        print("[ChronologyView] Handoff to Search — dateRange: \(String(describing: range))")
        #endif
        #if os(macOS)
        // Open the Search window DIRECTLY (the MainWindowView relay is retired —
        // provenance PR 2); it inherits this Chronology window's provenance.
        appState.bindTool(.search, to: appState.provenance(of: .chronology))
        openWindow(id: "frus.search")
        bringMacWindowToFront(id: "frus.search")
        #else
        appState.pendingTab = .search
        dismiss()
        #endif
    }
}

// MARK: - ChronologyRowView

/// One document row in the Chronology list: snippet (summary or header), provenance, and
/// type/precision badges.
private struct ChronologyRowView: View {
    let row: ChronologyRow
    let volumeTitle: String
    /// When set (spanning section), the document's year–year coverage, e.g. "1952–1975",
    /// shown in place of a single dateline.
    var spanLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if let spanLabel {
                    Label(spanLabel, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                if spanLabel == nil, let dateline = row.dateline, !dateline.isEmpty {
                    Text(dateline)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if row.certainty == .approximate {
                    badge(String(localized: "chronology.badge.approx", defaultValue: "~ approximate"))
                }
                if row.isEditorialNote {
                    badge(String(localized: "chronology.badge.editorial", defaultValue: "Editorial note"))
                }
                if row.isFrontMatter {
                    badge(String(localized: "chronology.badge.frontMatter", defaultValue: "Front matter"))
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    /// Prefer the generated summary; fall back to the document header.
    private var snippet: String {
        if let summary = row.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        return row.header.isEmpty ? row.documentId : row.header
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
