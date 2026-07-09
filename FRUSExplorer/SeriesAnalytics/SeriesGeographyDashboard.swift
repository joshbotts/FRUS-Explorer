// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - SeriesGeographyDashboard

/// The live "Geographic Emphasis" dashboard rendered inside the Research Guide
/// (Series Analytics SA-2).
///
/// It reads the bundled/known volume manifest through `AppState.manifestStore`,
/// builds the place-tag → region map from `AppState.volumeLevelTagStore`, derives
/// a pure `SeriesGeographyData`, and renders three Swift Charts telling the
/// geographic story of the FRUS series: how regional emphasis shifted from an
/// early Europe/Western-Hemisphere concentration toward postwar diversification
/// into Asia, the Near East, and Africa; the overall regional emphasis of the
/// corpus; and the individual countries the series covers most. Everything is
/// derived from the bundled `manifest.json` and `volume-tag-taxonomy.json`, so it
/// renders offline, with zero index, mid-onboarding.
///
/// `AppState` is read as an *optional* environment value (the defensive pattern
/// Prep-A established and SA-1b followed): an absent environment degrades to a
/// neutral empty state rather than trapping.
///
/// Version history:
///   1.0 — Analytics SA-2: initial implementation
///   1.1 — Analytics SA (x-axis bounds): bounded coverage x-domain (1861–1993)
///          on the regional-emphasis trend plus an editable year-range bar; the
///          1861 floor also drops the pre-1861 retrospective outlier decades
///   1.2 — Analytics SA (series chart refinements): no-comma decade x-axis on the
///          regional-emphasis trend
///   1.3 — Analytics SA (chart table inspector): each chart card gains a "View as
///          table" button opening a `ChartDataInspectorView` pop-up
struct SeriesGeographyDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead
    /// of a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// Compact-width detection for the year-range bar (drops its label on iPhone).
    /// Resolves to `.regular` on macOS, so `isCompactWidth` is `false` there.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// This dashboard's default upper year — its only time-series chart is
    /// coverage-valued, so the range ends at the coverage ceiling.
    private static let defaultEnd = SeriesChartKind.coverageCeilingYear

    /// The editable range's start year (floors at the series' start).
    @State private var yearStart = SeriesChartKind.floorYear
    /// The editable range's end year (defaults to the coverage ceiling).
    @State private var yearEnd = defaultEnd

    /// The chart whose underlying data is currently shown in the table-inspector
    /// pop-up, or `nil` when none. Drives the single dashboard-level `.sheet`.
    @State private var inspectorData: ChartInspectorData?

    /// The active subseries scope (#236). `@State`, so it resets per Research-Guide
    /// visit. Scoping rebuilds every chart — including the two categorical bar charts
    /// (region totals, top countries) the year-range bar cannot narrow, so scope
    /// answers "the most-covered countries in the 1969–76 subseries".
    @State private var scope = SeriesScope.whole

    /// The manifest entries to summarise: the diff's known set when a live
    /// refresh has happened, else the always-available bundled set, else empty
    /// (defensive — `AppState` absent). The full set drives the scope bar's menu.
    private var entries: [VolumeManifestEntry] {
        guard let store = appState?.manifestStore else { return [] }
        return store.diffResult?.known ?? store.bundledEntries
    }

    /// The place-tag slug → region map, built from the bundled taxonomy via the
    /// tag store: every `.places` tag's `subcategory` maps to a
    /// `GeographicRegion`. Empty when `AppState` is absent.
    private var placeRegions: [String: GeographicRegion] {
        guard let store = appState?.volumeLevelTagStore else { return [:] }
        var map: [String: GeographicRegion] = [:]
        for tag in store.allTags(inCategory: .places) {
            map[tag.slug] = GeographicRegion.from(subcategory: tag.subcategory)
        }
        return map
    }

    /// The pure derivation driving every chart, over the in-scope entries (#236).
    private var data: SeriesGeographyData {
        SeriesGeographyData(entries: scope.filter(entries), placeRegions: placeRegions)
    }

    /// Resolves a place-tag slug to its display name via the tag store, falling
    /// back to the raw slug when the taxonomy can't resolve it.
    private func displayName(forSlug slug: String) -> String {
        appState?.volumeLevelTagStore.resolve(slug: slug)?.displayName ?? slug
    }

    /// `true` on compact-width (iPhone); always `false` on macOS / regular-width.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// `true` when the range has been narrowed away from its `1861…1993` default.
    private var isCustomRange: Bool {
        yearStart != SeriesChartKind.floorYear || yearEnd != Self.defaultEnd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if entries.isEmpty || placeRegions.isEmpty {
                emptyState
            } else {
                intro
                SeriesScopeBar(entries: entries, scope: $scope)
                yearRangeBar
                regionTrendChart
                regionTotalsChart
                topCountriesChart
                caveats
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
    }

    // MARK: - Intro

    /// A short framing paragraph above the charts.
    private var intro: some View {
        Text(String(localized: "series.geography.intro",
                    defaultValue: "Where in the world does Foreign Relations of the United States look? Every volume carries editorial place tags, which resolve to the State Department's six regional bureaus. These charts trace how the series' geographic emphasis shifted over time — from an early concentration on Europe and the Western Hemisphere toward the postwar diversification into Asia, the Near East, and Africa — and which regions and countries the corpus covers most."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Year-range bar

    /// The editable start/end year filter above the charts, reusing the shared
    /// `AnalyticsYearRangeBar`. Only the coverage-valued trend chart honours it;
    /// the two categorical bar charts are unaffected.
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

    // MARK: - Chart 1: Regional emphasis over time (stacked area)

    /// Stacked area of each region's fractional share of the volumes covering a
    /// decade, over coverage decades. The anchor chart.
    private var regionTrendChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .coverage)
        let shares = data.regionShareByDecade(in: domain)
        return chartCard(
            title: String(localized: "series.geography.trend.title",
                          defaultValue: "Regional emphasis over time"),
            caption: String(localized: "series.geography.trend.caption",
                            defaultValue: "Each decade's volumes divided among the regions they cover — a volume spanning several regions splits evenly among them, so every decade sums to 100%. Decades are set by each volume's coverage midpoint."),
            inspector: ChartInspectorAdapters.regionTrendTable(shares)
        ) {
            Chart {
                ForEach(shares) { point in
                    AreaMark(
                        x: .value(
                            String(localized: "series.geography.trend.x", defaultValue: "Coverage decade"),
                            point.decade
                        ),
                        y: .value(
                            String(localized: "series.geography.trend.y", defaultValue: "Share"),
                            point.share
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.geography.region.legend", defaultValue: "Region"),
                        point.region.displayName
                    ))
                    .accessibilityLabel(Text(String(
                        localized: "series.geography.trend.a11y.label",
                        defaultValue: "\(point.region.displayName), \(String(point.decade))s"
                    )))
                    .accessibilityValue(Text(point.share, format: FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0))))
                }
            }
            .chartForegroundStyleScale(domain: GeographicRegion.ordered.map(\.displayName))
            .chartXScale(domain: domain.lowerBound...domain.upperBound)
            .chartYScale(domain: 0...1)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: SeriesChartKind.yearAxisFormat)
                }
            }
            .chartYAxis {
                AxisMarks(format: FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0)))
            }
            .chartXAxisLabel(String(localized: "series.geography.trend.x", defaultValue: "Coverage decade"))
            .chartYAxisLabel(String(localized: "series.geography.trend.y", defaultValue: "Share of volumes"))
            .frame(height: 280)
        }
    }

    // MARK: - Chart 2: Overall regional emphasis

    /// Bars of the volume-overlap count for each region.
    private var regionTotalsChart: some View {
        let data = data
        return chartCard(
            title: String(localized: "series.geography.totals.title",
                          defaultValue: "Overall regional emphasis"),
            caption: String(localized: "series.geography.totals.caption",
                            defaultValue: "How many volumes touch each region across the whole series. A volume that covers several regions counts once in each, so these totals overlap."),
            inspector: ChartInspectorAdapters.regionTotalsTable(data.regionTotals)
        ) {
            Chart {
                ForEach(data.regionTotals) { total in
                    BarMark(
                        x: .value(
                            String(localized: "series.geography.totals.x", defaultValue: "Region"),
                            total.region.displayName
                        ),
                        y: .value(
                            String(localized: "series.geography.totals.y", defaultValue: "Volumes"),
                            total.volumeCount
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.geography.region.legend", defaultValue: "Region"),
                        total.region.displayName
                    ))
                    .accessibilityLabel(Text(total.region.displayName))
                    .accessibilityValue(Text(total.volumeCount, format: .number))
                }
            }
            .chartForegroundStyleScale(domain: GeographicRegion.ordered.map(\.displayName))
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .vertical)
                    AxisTick()
                }
            }
            .chartXAxisLabel(String(localized: "series.geography.totals.x", defaultValue: "Region"))
            .chartYAxisLabel(String(localized: "series.geography.totals.y", defaultValue: "Volumes"))
            .frame(height: 260)
        }
    }

    // MARK: - Chart 3: Most-covered countries

    /// Horizontal bars of the most-tagged place tags, resolved to display names.
    private var topCountriesChart: some View {
        let data = data
        return chartCard(
            title: String(localized: "series.geography.countries.title",
                          defaultValue: "Most-covered countries"),
            caption: String(localized: "series.geography.countries.caption",
                            defaultValue: "The individual place tags carried by the most volumes — the concrete detail behind the regional picture."),
            inspector: ChartInspectorAdapters.topCountriesTable(
                data.topCountries,
                displayName: { displayName(forSlug: $0) }
            )
        ) {
            Chart {
                ForEach(data.topCountries) { country in
                    BarMark(
                        x: .value(
                            String(localized: "series.geography.countries.x", defaultValue: "Volumes"),
                            country.volumeCount
                        ),
                        y: .value(
                            String(localized: "series.geography.countries.y", defaultValue: "Country"),
                            displayName(forSlug: country.slug)
                        )
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text(displayName(forSlug: country.slug)))
                    .accessibilityValue(Text(country.volumeCount, format: .number))
                }
            }
            .chartYAxis {
                AxisMarks(preset: .aligned) {
                    AxisValueLabel()
                }
            }
            .chartXAxisLabel(String(localized: "series.geography.countries.x", defaultValue: "Volumes"))
            .frame(height: CGFloat(max(data.topCountries.count, 1)) * 24 + 40)
        }
    }

    // MARK: - Caveats

    /// A footer stating the honest limits of the geographic metadata.
    private var caveats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "series.geography.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let label = scope.label {
                Text(String(format: String(localized: "series.caveats.scope %@",
                                           defaultValue: "Scoped to the %@ subseries — reset the scope above for the whole series."),
                            label))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "series.geography.caveats.body",
                        defaultValue: "Place tags are volume-level editorial tags: a volume \"touches\" a region if it carries a place tag mapped to that region — this is not a document count, and a volume commonly spans several regions. The stacked view uses per-volume fractional attribution, so a volume covering three regions contributes a third to each and every decade sums to 100%; the overall bars, by contrast, count a multi-region volume once in each region. Regions follow the State Department's six regional bureaus, with dependencies and territories folded into \"Other.\" 551 of the 552 catalogued volumes carry at least one place tag. These figures reflect the volumes the app currently catalogs — the newest volumes may not yet appear."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Empty state

    /// Neutral state shown when no manifest entries or no place-region map are
    /// available (e.g. `AppState` absent). Never a crash.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "series.geography.empty.title", defaultValue: "No geographic data"))
                .font(.headline)
            Text(String(localized: "series.geography.empty.message",
                        defaultValue: "The bundled volume manifest or place-tag taxonomy is unavailable in this context."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart card

    /// A titled, captioned container for a single chart, keeping the three
    /// sections visually consistent (mirrors the SA-1b dashboard card). When
    /// `inspector` is non-nil, the header gains a trailing "View as table" button
    /// that opens the data pop-up.
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
