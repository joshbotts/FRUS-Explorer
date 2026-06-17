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
    @Environment(\.dismiss) private var dismiss

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
    /// Active legend filter: a volume ID (or `chronologyOtherSeriesKey`) restricting the
    /// list to documents from that volume. `nil` = show all.
    @State private var selectedSeries: String? = nil

    /// Parameters this view was opened with (a `pendingChronology` handoff). Applied once.
    private let initialParameters: ChronologyParameters?

    /// Rows shown in a dense section before the "Show all" expander.
    private static let denseThreshold = 25

    /// Distinct colours for the top chart volumes; the folded "Other" series uses gray.
    /// System colours so light/dark mode and accessibility contrast are handled by the OS.
    private static let seriesPalette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .indigo]

    /// `id` of the spanning section, used as a scroll target from its chip.
    private static let spanningSectionID = "__chronology_spanning__"

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
            .navigationTitle(String(localized: "chronology.title", defaultValue: "Chronology"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                #if os(iOS)
                DocumentView(entry: entry)
                #else
                MacDocumentView(entry: entry, navigationPath: .constant([]), highlightCoordinator: HighlightCoordinator())
                #endif
            }
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task { seedDefaultsAndApply(initialParameters) }
        .onChange(of: appState.pendingChronology) { _, params in
            guard let params else { return }
            apply(params)
            appState.pendingChronology = nil
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
        if let params {
            apply(params)
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
                .labelsHidden()
                Text(verbatim: "–").foregroundStyle(.tertiary)
                DatePicker(
                    String(localized: "chronology.range.to", defaultValue: "To"),
                    selection: $vm.rangeEnd,
                    in: vm.rangeStart...,
                    displayedComponents: .date
                )
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
        .padding()
    }

    private var summaryLine: String {
        let docs = vm.totalShown
        let base = String(
            format: String(localized: "chronology.summary %lld", defaultValue: "%lld documents"),
            Int64(docs)
        )
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
        } else if vm.groups.isEmpty {
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
            : Self.seriesPalette[index % Self.seriesPalette.count]
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
            : volumeTitle(key)
    }

    /// Chart x-axis bucket unit, matching the view model's range-driven coarsening.
    private var chartUnit: Calendar.Component {
        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: min(vm.rangeStart, vm.rangeEnd), to: max(vm.rangeStart, vm.rangeEnd)).day ?? 0
        if days <= ChronologyViewModel.dayGroupingMaxDays { return .day }
        if days <= ChronologyViewModel.monthGroupingMaxDays { return .month }
        return .year
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
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotAnchor = proxy.plotFrame else { return }
                        let xInPlot = location.x - geo[plotAnchor].origin.x
                        guard let tapped: Date = proxy.value(atX: xInPlot) else { return }
                        if let nearest = vm.chartBuckets.min(by: {
                            abs($0.date.timeIntervalSince(tapped)) < abs($1.date.timeIntervalSince(tapped))
                        }) {
                            withAnimation { scrollProxy.scrollTo(nearest.bucketKey, anchor: .top) }
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(Text(String(
            localized: "chronology.chart.a11y",
            defaultValue: "Document distribution over the selected dates, stacked by volume. Counts are listed in the legend and in each date section below."
        )))
    }

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
                Image(systemName: "arrow.left.right")
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

    private func open(_ row: ChronologyRow) {
        navigationPath.append(DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            documentNumber: row.documentNumber,
            header: row.header,
            dateline: row.dateline,
            sourceNote: nil,
            isEditorialNote: row.isEditorialNote
        ))
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
        #if os(iOS)
        appState.activeTab = .search
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
