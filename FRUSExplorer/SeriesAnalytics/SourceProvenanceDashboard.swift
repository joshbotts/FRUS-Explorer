// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - SourceProvenanceDashboard

/// The live "Archival Sourcing Over Time" dashboard rendered inside the Research
/// Guide (Series Analytics SA-3b) — the third "About the Series" dashboard, after
/// Production & Timeliness (SA-1b) and Geographic Emphasis (SA-2).
///
/// It reads the bundled `source-provenance-index.json` aggregate through
/// `AppState.sourceProvenanceStore`, derives a pure `SourceProvenanceData`, and
/// renders three Swift Charts telling the sourcing story of the FRUS series: how
/// the archival base shifted from the near-total dominance of the State
/// Department's Central Decimal File in the 1900s–1930s, through the 1950s
/// appearance of bureau lot files and presidential libraries, to the 1970s
/// preponderance of presidential-library and Central Foreign Policy File material.
/// Everything is derived from the bundled aggregate, so it renders offline, with
/// zero index, mid-onboarding.
///
/// The pre-1900 retrospective-compilation decades are floored out of the trend by
/// `SourceProvenanceData` (they are tiny buckets, almost entirely unclassified) and
/// disclosed in the caveats.
///
/// `AppState` is read as an *optional* environment value (the defensive pattern
/// Prep-A established and SA-1b/SA-2 followed): an absent environment degrades to a
/// neutral empty state rather than trapping.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
///   1.1 — Analytics SA (x-axis bounds): bounded coverage x-domain (1861–1993) on
///          the provenance-mix and density charts plus an editable year-range bar
///   1.2 — Analytics SA (series chart refinements): no-comma decade x-axes on the
///          provenance-mix and density charts
///   1.3 — Analytics SA (chart table inspector): each chart card gains a "View as
///          table" button opening a `ChartDataInspectorView` pop-up
///   1.4 — Session 3 / #236: category include/exclude filter (per-category menu +
///          "Hide Other / Unclassified" shortcut) with shares renormalized exactly
///          over the shown categories; a filter caveat discloses the re-basing;
///          `chartCard` delegates to the shared `SeriesChartCard`
///   1.5 — Session 3 review: per-category rows are menu `Toggle`s so shown/hidden
///          state is voiced (the icon-swapped Buttons read identically under
///          VoiceOver); the last shown category's items disable instead of the tap
///          silently dead-ending
struct SourceProvenanceDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead of
    /// a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// Compact-width detection for the year-range bar (drops its label on iPhone).
    /// Resolves to `.regular` on macOS, so `isCompactWidth` is `false` there.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// This dashboard's default upper year — its time-series charts are
    /// coverage-valued, so the range ends at the coverage ceiling.
    private static let defaultEnd = SeriesChartKind.coverageCeilingYear

    /// The editable range's start year (floors at the series' start).
    @State private var yearStart = SeriesChartKind.floorYear
    /// The editable range's end year (defaults to the coverage ceiling).
    @State private var yearEnd = defaultEnd

    /// The chart whose underlying data is currently shown in the table-inspector
    /// pop-up, or `nil` when none. Drives the single dashboard-level `.sheet`.
    @State private var inspectorData: ChartInspectorData?

    /// Provenance categories hidden from the mix + composition charts (#236). The
    /// bundled aggregate is decade × category only — no volume/subseries dimension —
    /// so this category include/exclude filter is the one narrowing the data supports;
    /// shares renormalize over the shown categories. `@State`, resets per visit.
    @State private var hiddenCategories: Set<SourceProvenanceCategory> = []

    /// The pure derivation driving every chart, built from the bundled aggregate
    /// (empty/zeroed when `AppState` or the resource is absent).
    private var data: SourceProvenanceData {
        SourceProvenanceData(index: appState?.sourceProvenanceStore.index)
    }

    /// `true` on compact-width (iPhone); always `false` on macOS / regular-width.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// `true` when the range has been narrowed away from its `1861…1993` default.
    private var isCustomRange: Bool {
        yearStart != SeriesChartKind.floorYear || yearEnd != Self.defaultEnd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if data.shareByDecade.isEmpty {
                emptyState
            } else {
                intro
                yearRangeBar
                categoryFilterBar
                mixOverTimeChart
                compositionChart
                densityChart
                caveats
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
    }

    // MARK: - Intro

    /// A short framing paragraph above the charts.
    private var intro: some View {
        Text(String(localized: "series.provenance.intro",
                    defaultValue: "Where did the editors of Foreign Relations of the United States find the documents they published? Every document carries a source note naming the archival file it was drawn from. These charts parse those notes across the whole series to trace how its archival base evolved — from the near-total dominance of the State Department's Central Decimal File in the early twentieth century, through the postwar appearance of bureau lot files and presidential libraries, to the diversified sourcing of the modern volumes."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Year-range bar

    /// The editable start/end year filter above the charts, reusing the shared
    /// `AnalyticsYearRangeBar`. Both coverage-valued charts (mix + density) honour
    /// it; the categorical composition bars are unaffected. Provenance data floors
    /// at 1900, so the 1861–1900 span of the axis is honestly empty.
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

    // MARK: - Category filter

    /// A compact menu to hide provenance categories (the only narrowing the
    /// decade × category aggregate supports). Offers a one-tap "Hide Other /
    /// Unclassified" — the most common narrowing — plus a per-category checklist.
    /// At least one category must stay shown, so the charts never blank.
    private var categoryFilterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Menu {
                Button {
                    toggleCategory(.unrecognized)
                } label: {
                    Label(hiddenCategories.contains(.unrecognized)
                          ? String(localized: "series.provenance.filter.showOther", defaultValue: "Show Other / Unclassified")
                          : String(localized: "series.provenance.filter.hideOther", defaultValue: "Hide Other / Unclassified"),
                          systemImage: hiddenCategories.contains(.unrecognized) ? "eye" : "eye.slash")
                }
                .disabled(isLastShownCategory(.unrecognized))
                Divider()
                ForEach(SourceProvenanceCategory.ordered, id: \.self) { category in
                    // A menu Toggle renders the native checkmark AND announces its
                    // on/off state to VoiceOver — an icon-swapped Button label would
                    // read identically shown or hidden (Session 3 review).
                    Toggle(isOn: Binding(
                        get: { !hiddenCategories.contains(category) },
                        set: { _ in toggleCategory(category) }
                    )) {
                        Text(category.displayName)
                    }
                    // The last shown category cannot be hidden (the charts would
                    // blank); a disabled item is dimmed and voiced as such, instead
                    // of the tap silently dead-ending.
                    .disabled(isLastShownCategory(category))
                }
                if !hiddenCategories.isEmpty {
                    Divider()
                    Button {
                        hiddenCategories.removeAll()
                    } label: {
                        Label(String(localized: "series.provenance.filter.showAll", defaultValue: "Show all categories"),
                              systemImage: "eye")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(hiddenCategories.isEmpty
                         ? String(localized: "series.provenance.filter.label", defaultValue: "Categories: all")
                         : String(format: String(localized: "series.provenance.filter.label.count %lld",
                                                  defaultValue: "Categories: %lld shown"),
                                  Int64(SourceProvenanceCategory.ordered.count - hiddenCategories.count)))
                        .font(.caption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
            }
            .accessibilityLabel(String(localized: "series.provenance.filter.a11y",
                                       defaultValue: "Provenance categories shown"))
            .accessibilityValue(hiddenCategories.isEmpty
                                ? String(localized: "series.provenance.filter.a11y.all", defaultValue: "All shown")
                                : String(format: String(localized: "series.provenance.filter.a11y.count %lld",
                                                        defaultValue: "%lld of 10 shown"),
                                         Int64(SourceProvenanceCategory.ordered.count - hiddenCategories.count)))
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// Toggles a category's hidden state, but never hides the last shown category
    /// (that would blank the charts with no way back except this menu). The UI
    /// communicates the constraint by disabling the last shown item
    /// (`isLastShownCategory(_:)`); this guard is the state-level backstop.
    private func toggleCategory(_ category: SourceProvenanceCategory) {
        if hiddenCategories.contains(category) {
            hiddenCategories.remove(category)
        } else if hiddenCategories.count < SourceProvenanceCategory.ordered.count - 1 {
            hiddenCategories.insert(category)
        }
    }

    /// `true` when `category` is the only category still shown — the one item the
    /// filter refuses to hide. Drives `.disabled` on its menu item so the constraint
    /// is dimmed and voiced rather than a silent dead-end tap.
    private func isLastShownCategory(_ category: SourceProvenanceCategory) -> Bool {
        !hiddenCategories.contains(category)
            && hiddenCategories.count == SourceProvenanceCategory.ordered.count - 1
    }

    // MARK: - Chart 1: Provenance mix over time (stacked area, the anchor)

    /// Stacked area of each provenance category's share of a decade's source
    /// notes, over coverage decades from 1900. The anchor chart.
    private var mixOverTimeChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .coverage)
        let shares = data.shareByDecade(in: domain, excluding: hiddenCategories)
        return chartCard(
            title: String(localized: "series.provenance.trend.title",
                          defaultValue: "Archival provenance over time"),
            caption: String(localized: "series.provenance.trend.caption",
                            defaultValue: "Each decade's source notes divided among the archival collections they cite, so every decade sums to 100%. Decades are set by each volume's coverage midpoint; the trend begins in 1900 because earlier volumes carry no archival source notes."),
            inspector: ChartInspectorAdapters.provenanceMixTable(shares)
        ) {
            Chart {
                ForEach(shares) { point in
                    AreaMark(
                        x: .value(
                            String(localized: "series.provenance.trend.x", defaultValue: "Coverage decade"),
                            point.decade
                        ),
                        y: .value(
                            String(localized: "series.provenance.trend.y", defaultValue: "Share"),
                            point.share
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.provenance.category.legend", defaultValue: "Provenance"),
                        point.category.displayName
                    ))
                    .accessibilityLabel(Text(String(
                        localized: "series.provenance.trend.a11y.label",
                        defaultValue: "\(point.category.displayName), \(String(point.decade))s"
                    )))
                    .accessibilityValue(Text(point.share, format: FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0))))
                }
            }
            .chartForegroundStyleScale(domain: SourceProvenanceCategory.ordered.map(\.displayName))
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
            .chartXAxisLabel(String(localized: "series.provenance.trend.x", defaultValue: "Coverage decade"))
            .chartYAxisLabel(String(localized: "series.provenance.trend.y", defaultValue: "Share of source notes"))
            .frame(height: 300)
        }
    }

    // MARK: - Chart 2: Overall provenance composition

    /// Bars of the total note count for each provenance category across the shown
    /// decades.
    private var compositionChart: some View {
        let composition = data.overallComposition(excluding: hiddenCategories)
        return chartCard(
            title: String(localized: "series.provenance.composition.title",
                          defaultValue: "Overall provenance composition"),
            caption: String(localized: "series.provenance.composition.caption",
                            defaultValue: "How many source notes across the whole series (from 1900) cite each kind of archival collection. The Central Decimal File dwarfs the rest — most published FRUS documents came from the State Department's own central filing."),
            inspector: ChartInspectorAdapters.compositionTable(composition)
        ) {
            Chart {
                ForEach(composition) { item in
                    BarMark(
                        x: .value(
                            String(localized: "series.provenance.composition.x", defaultValue: "Provenance"),
                            item.category.displayName
                        ),
                        y: .value(
                            String(localized: "series.provenance.composition.y", defaultValue: "Source notes"),
                            item.noteCount
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.provenance.category.legend", defaultValue: "Provenance"),
                        item.category.displayName
                    ))
                    .accessibilityLabel(Text(item.category.displayName))
                    .accessibilityValue(Text(item.noteCount, format: .number))
                }
            }
            .chartForegroundStyleScale(domain: SourceProvenanceCategory.ordered.map(\.displayName))
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .vertical)
                    AxisTick()
                }
            }
            .chartXAxisLabel(String(localized: "series.provenance.composition.x", defaultValue: "Provenance"))
            .chartYAxisLabel(String(localized: "series.provenance.composition.y", defaultValue: "Source notes"))
            .frame(height: 300)
        }
    }

    // MARK: - Chart 3: The documentary base by decade

    /// Bars of the total source-note count per shown decade — the density context
    /// behind the shares (a 1970s share sits on far fewer notes than a 1940s one).
    private var densityChart: some View {
        let domain = effectiveDomain(userStart: yearStart, userEnd: yearEnd, kind: .coverage)
        let density = data.notesByDecade(in: domain)
        return chartCard(
            title: String(localized: "series.provenance.density.title",
                          defaultValue: "The documentary base by decade"),
            caption: String(localized: "series.provenance.density.caption",
                            defaultValue: "How many source notes each decade contributes — the density behind the shares above. The 1940s carry the deepest base; a share in a thin decade rests on far fewer documents."),
            inspector: ChartInspectorAdapters.densityTable(density)
        ) {
            Chart {
                ForEach(density) { item in
                    BarMark(
                        x: .value(
                            String(localized: "series.provenance.density.x", defaultValue: "Coverage decade"),
                            item.decade
                        ),
                        y: .value(
                            String(localized: "series.provenance.density.y", defaultValue: "Source notes"),
                            item.totalNotes
                        )
                    )
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text(String(
                        localized: "series.provenance.density.a11y.label",
                        defaultValue: "\(String(item.decade))s"
                    )))
                    .accessibilityValue(Text(item.totalNotes, format: .number))
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
            .chartXAxisLabel(String(localized: "series.provenance.density.x", defaultValue: "Coverage decade"))
            .chartYAxisLabel(String(localized: "series.provenance.density.y", defaultValue: "Source notes"))
            .frame(height: 240)
        }
    }

    // MARK: - Caveats

    /// A footer stating the honest limits of the provenance metadata.
    private var caveats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "series.provenance.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if !hiddenCategories.isEmpty {
                // New key (.v2): the zero-decade sentence changed this string's meaning
                // when the review pass made gap decades collapse to zero (1.5).
                Text(String(localized: "series.provenance.caveats.filtered.v2",
                            defaultValue: "Some categories are hidden — the shares shown are re-based to the shown categories, not the full mix. A decade with no notes in any shown category collapses to zero rather than being skipped. Use the Categories menu above to show all."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "series.provenance.caveats.body",
                        defaultValue: "These figures are derived by parsing each document's source note — the citation naming where its archival original was found — not from a catalog of the archives. \"Other / Unclassified\" is a citation form the parser could not classify, not the absence of a source note. Coverage spans 522 of the 552 catalogued volumes. Pre-1900 volumes are largely published diplomatic correspondence carrying no archival source notes, so the trend begins around 1900; those early retrospective compilations are excluded from the charts. The categories map to State Department filing practice: the Central Decimal File is the pre-1960 central filing system, the Central Foreign Policy File its post-1960 successor, lot files are bureau and office working files, and presidential libraries hold the White House records that dominate the modern volumes. Above all, these counts reflect where FRUS editors drew documents — an editorial and archival signal — rather than a full census of the underlying archives."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Empty state

    /// Neutral state shown when no provenance aggregate is available (e.g.
    /// `AppState` absent or the resource missing). Never a crash.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "series.provenance.empty.title", defaultValue: "No provenance data"))
                .font(.headline)
            Text(String(localized: "series.provenance.empty.message",
                        defaultValue: "The bundled source-provenance index is unavailable in this context."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart card

    /// A titled, captioned container for a single chart, keeping the three
    /// sections visually consistent (mirrors the SA-1b/SA-2 dashboard card). When
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
