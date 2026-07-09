// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - SeriesProductionDashboard

/// The live "Production & Timeliness" dashboard rendered inside the Research
/// Guide (Series Analytics SA-1b), replacing the Prep-A development placeholder.
///
/// It reads the bundled/known volume manifest through `AppState.manifestStore`,
/// builds a pure `SeriesProductionData`, and renders three Swift Charts telling
/// the production story of the FRUS series: how long volumes take to reach
/// print (against the evolving publication-timeliness target), how publication
/// output has ebbed and flowed, and the cumulative growth of the published
/// corpus. Everything is derived from `manifest.json`, so it renders offline,
/// with zero index, mid-onboarding.
///
/// `AppState` is read as an *optional* environment value (the defensive pattern
/// Prep-A established): an absent environment degrades to a neutral empty state
/// rather than trapping.
///
/// Version history:
///   1.0 — Analytics SA-1b: initial implementation
///   1.1 — Analytics SA (x-axis bounds): fixed default x-domains (coverage
///          1861–1993, production 1861–2026) plus an editable year-range bar that
///          scales and filters every time-series chart
///   1.2 — Analytics SA (series chart refinements): no-comma year axes; removed
///          the coverage-span Gantt chart; replaced the flat 30-year lag rule with
///          the evolving `PublicationLagTarget` step line (15→20→30)
///   1.3 — Analytics SA (series chart refinements): the lag chart's x-axis is the
///          volume's publication year (production domain), so the timeliness-target
///          step is exact — the directive in force when a volume was published
///   1.4 — Analytics SA (chart table inspector): each chart card gains a "View as
///          table" button opening a `ChartDataInspectorView` pop-up over the
///          range-filtered data
struct SeriesProductionDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead
    /// of a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// Compact-width detection for the year-range bar (drops its label on iPhone).
    /// Resolves to `.regular` on macOS, so `isCompactWidth` is `false` there.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// This dashboard's default upper year — it is the Production & Timeliness
    /// dashboard, so its range runs to the present publication horizon.
    private static let defaultEnd = SeriesChartKind.productionCeilingYear

    /// The editable range's start year (floors at the series' start).
    @State private var yearStart = SeriesChartKind.floorYear
    /// The editable range's end year (defaults to the production ceiling).
    @State private var yearEnd = defaultEnd

    /// The chart whose underlying data is currently shown in the table-inspector
    /// pop-up, or `nil` when none. Drives the single dashboard-level `.sheet`.
    @State private var inspectorData: ChartInspectorData?

    /// The manifest entries to summarise: the diff's known set when a live
    /// refresh has happened, else the always-available bundled set, else empty
    /// (defensive — `AppState` absent).
    private var entries: [VolumeManifestEntry] {
        guard let store = appState?.manifestStore else { return [] }
        return store.diffResult?.known ?? store.bundledEntries
    }

    /// The pure derivation driving every chart.
    private var data: SeriesProductionData {
        SeriesProductionData(entries: entries)
    }

    /// `true` on compact-width (iPhone); always `false` on macOS / regular-width.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// `true` when the range has been narrowed away from its `1861…2026` default.
    private var isCustomRange: Bool {
        yearStart != SeriesChartKind.floorYear || yearEnd != Self.defaultEnd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if entries.isEmpty {
                emptyState
            } else {
                intro
                yearRangeBar
                lagChart
                perYearChart
                cumulativeChart
                caveats
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
    }

    // MARK: - Intro

    /// A short framing paragraph above the charts.
    private var intro: some View {
        Text(String(localized: "series.production.intro",
                    defaultValue: "How long does the official record take to reach print? These charts trace the timeliness of Foreign Relations of the United States across its whole span — the lag between the events a volume documents and its publication (against the evolving publication-timeliness target), the pace of publication over time, and the steady growth of the digitized corpus."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Year-range bar

    /// The editable start/end year filter above the charts, reusing the shared
    /// `AnalyticsYearRangeBar` chrome. Coverage charts additionally clamp to 1993
    /// (via `effectiveDomain`), so this bar's `2026` end only widens the
    /// production charts.
    private var yearRangeBar: some View {
        AnalyticsYearRangeBar(
            start: $yearStart,
            end: $yearEnd,
            corpusMaxYear: Self.defaultEnd,
            isCompactWidth: isCompactWidth,
            isCustom: isCustomRange,
            onReset: {
                yearStart = SeriesChartKind.floorYear
                yearEnd = Self.defaultEnd
            }
        )
    }

    // MARK: - Chart 1: Publication lag over time

    /// Scatter of publication lag against publication year, coloured by coverage
    /// era, overlaid with the evolving publication-timeliness target as a dashed
    /// step line (15→20→30 years). The anchor chart.
    private var lagChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .production)
        let points = data.lagPoints(in: domain)
        let targetSteps = PublicationLagTarget.stepPoints(in: domain)
        let targetLabel = String(localized: "series.chart.lag.target.series",
                                 defaultValue: "Publication-timeliness target")
        return chartCard(
            title: String(localized: "series.chart.lag.title",
                          defaultValue: "Publication lag over time"),
            caption: String(localized: "series.chart.lag.caption",
                            defaultValue: "Each point is a volume: its publication year (horizontal) against how many years earlier its latest document was written — the lag (vertical). The dashed step line is the timeliness target in force at publication — 15 years from the 1961 directive, 20 from 1972, and 30 from 1985 (codified by the 1991 statute)."),
            inspector: ChartInspectorAdapters.lagTable(points)
        ) {
            Chart {
                ForEach(points) { point in
                    PointMark(
                        x: .value(
                            String(localized: "series.chart.lag.x", defaultValue: "Publication year"),
                            point.printYear
                        ),
                        y: .value(
                            String(localized: "series.chart.lag.y", defaultValue: "Years to publication"),
                            point.lagYears
                        )
                    )
                    .symbolSize(20)
                    .foregroundStyle(by: .value(
                        String(localized: "series.chart.era.legend", defaultValue: "Era"),
                        point.coverageEra.label
                    ))
                    .accessibilityLabel(Text(point.volumeId))
                    .accessibilityValue(Text(String(
                        localized: "series.chart.lag.a11y",
                        defaultValue: "Covers through \(point.coverageEndYear), published \(point.printYear), lag \(point.lagYears) years"
                    )))
                }

                // Evolving publication-timeliness target: a dashed step line that
                // only appears from 1961 onward and respects the editable range.
                ForEach(targetSteps) { step in
                    LineMark(
                        x: .value(
                            String(localized: "series.chart.lag.x", defaultValue: "Publication year"),
                            step.year
                        ),
                        y: .value(
                            String(localized: "series.chart.lag.y", defaultValue: "Years to publication"),
                            step.targetYears
                        ),
                        series: .value(
                            String(localized: "series.chart.lag.target.axis", defaultValue: "Target"),
                            targetLabel
                        )
                    )
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .interpolationMethod(.stepEnd)
                    .accessibilityLabel(Text(targetLabel))
                    .accessibilityValue(Text(String(
                        localized: "series.chart.lag.target.a11y",
                        defaultValue: "From \(step.year), target \(step.targetYears) years"
                    )))
                }
            }
            .chartForegroundStyleScale(domain: CoverageEra.ordered.map(\.label))
            .chartXScale(domain: domain.lowerBound...domain.upperBound)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: SeriesChartKind.yearAxisFormat)
                }
            }
            .chartXAxisLabel(String(localized: "series.chart.lag.x", defaultValue: "Publication year"))
            .chartYAxisLabel(String(localized: "series.chart.lag.y", defaultValue: "Years to publication"))
            .frame(height: 260)
        }
    }

    // MARK: - Chart 2: Volumes published per print year

    /// Bars of volumes printed per year, coloured by the publication-year era.
    private var perYearChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .production)
        let buckets = data.volumesPerPrintYearByEra(in: domain)
        return chartCard(
            title: String(localized: "series.chart.peryear.title",
                          defaultValue: "Volumes published per year"),
            caption: String(localized: "series.chart.peryear.caption",
                            defaultValue: "How many volumes reached print in each year, coloured by era. Output has never been steady — it reflects staffing, declassification throughput, and the shift to digital publication."),
            inspector: ChartInspectorAdapters.perYearTable(buckets)
        ) {
            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value(
                            String(localized: "series.chart.peryear.x", defaultValue: "Print year"),
                            bucket.printYear
                        ),
                        y: .value(
                            String(localized: "series.chart.peryear.y", defaultValue: "Volumes"),
                            bucket.count
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.chart.era.legend", defaultValue: "Era"),
                        bucket.pubEra.label
                    ))
                    .accessibilityLabel(Text(String(bucket.printYear)))
                    .accessibilityValue(Text(bucket.count, format: .number))
                }
            }
            .chartForegroundStyleScale(domain: CoverageEra.ordered.map(\.label))
            .chartXScale(domain: domain.lowerBound...domain.upperBound)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: SeriesChartKind.yearAxisFormat)
                }
            }
            .chartXAxisLabel(String(localized: "series.chart.peryear.x", defaultValue: "Print year"))
            .chartYAxisLabel(String(localized: "series.chart.peryear.y", defaultValue: "Volumes"))
            .frame(height: 240)
        }
    }

    // MARK: - Chart 3: Cumulative volumes published

    /// The series growth curve: a running total of published volumes by print
    /// year. Replaces the impossible pipeline-by-status chart.
    private var cumulativeChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .production)
        let points = data.cumulativeByPrintYear(in: domain)
        return chartCard(
            title: String(localized: "series.chart.cumulative.title",
                          defaultValue: "Cumulative volumes published"),
            caption: String(localized: "series.chart.cumulative.caption",
                            defaultValue: "The digitized corpus has grown to the 552 volumes this app catalogs — steeply in some decades, slowly in others."),
            inspector: ChartInspectorAdapters.cumulativeTable(points)
        ) {
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value(
                            String(localized: "series.chart.cumulative.x", defaultValue: "Print year"),
                            point.printYear
                        ),
                        y: .value(
                            String(localized: "series.chart.cumulative.y", defaultValue: "Volumes to date"),
                            point.cumulativeCount
                        )
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.25))
                    LineMark(
                        x: .value(
                            String(localized: "series.chart.cumulative.x", defaultValue: "Print year"),
                            point.printYear
                        ),
                        y: .value(
                            String(localized: "series.chart.cumulative.y", defaultValue: "Volumes to date"),
                            point.cumulativeCount
                        )
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text(String(point.printYear)))
                    .accessibilityValue(Text(point.cumulativeCount, format: .number))
                }
            }
            .chartXScale(domain: domain.lowerBound...domain.upperBound)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: SeriesChartKind.yearAxisFormat)
                }
            }
            .chartXAxisLabel(String(localized: "series.chart.cumulative.x", defaultValue: "Print year"))
            .chartYAxisLabel(String(localized: "series.chart.cumulative.y", defaultValue: "Volumes to date"))
            .frame(height: 240)
        }
    }

    // MARK: - Caveats

    /// A footer stating the honest limits of the production metadata.
    private var caveats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "series.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(localized: "series.caveats.body",
                        defaultValue: "Production figures reflect only published, digitized volumes. Publication year is the volume's TEI print year and coverage is the span of its document dates; lag is print year minus coverage-end year, and can be near-zero or negative for the near-contemporaneous early volumes. The publication-timeliness target evolved over time — no formal target before 1961, then 15 years (1961 directive), 20 years (1972 directive), and 30 years (1985 directive, codified by the 1991 statute); the step line is drawn against each volume's publication year, so it shows exactly the target in force when the volume was published. These charts reflect the 552 volumes the app currently catalogs — the newest volumes may not yet appear."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Empty state

    /// Neutral state shown when no manifest entries are available (e.g.
    /// `AppState` absent). Never a crash.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "series.empty.title", defaultValue: "No manifest data"))
                .font(.headline)
            Text(String(localized: "series.empty.message",
                        defaultValue: "The bundled volume manifest is unavailable in this context."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart card

    /// Thin binding of the shared `SeriesChartCard` to this dashboard's
    /// `inspectorData` sheet state. Extracted in #236 — the card body now lives in
    /// `SeriesChartCard.swift`.
    private func chartCard<Content: View>(
        title: String,
        caption: String,
        inspector: ChartInspectorData?,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SeriesChartCard(
            title: title,
            caption: caption,
            inspector: inspector,
            onInspect: { inspectorData = $0 },
            content: content
        )
    }
}
