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
///   1.6 — Session 2026-08-08 (#267): the subseries scope bar the other three "About the
///          Series" dashboards already carry. Session 3 withheld it because the bundled
///          aggregate was decade × category and a scope would have had to be approximated;
///          schema 2 adds the per-volume table, so the narrowing is now exact. The bar is
///          still withheld — not approximated — if the artifact lacks that table
///   1.7 — Session 2026-08-09 (#795): a cross-link into Archival Analytics — the #765 D-1
///          rider. macOS only; the iOS arm is withheld because this dashboard also renders
///          inside the mid-onboarding `WhileIndexingSheet`, where it would be a sheet over
///          a sheet during the first index (see `archivalAnalyticsLink`)
///   1.8 — Session 2026-08-11: #835 — the `TopCollectionsCard` narrative layer, and #798's
///         iOS arm of the cross-link, withheld mid-onboarding through a threaded
///         `presentationContext` and presented locally rather than through the tab shell
struct SourceProvenanceDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead of
    /// a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// Compact-width detection for the year-range bar (drops its label on iPhone).
    /// Resolves to `.regular` on macOS, so `isCompactWidth` is `false` there.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// This scene, so a collection record opened from the card addresses the window the reader is
    /// in (#338). Absent on macOS and in the guide's own containers, where `.anyWindow` is right.
    @Environment(\.sceneID) private var sceneID

    /// This scene's model context, only for handing its container to the Archival Analytics sheet
    /// — which a sheet does not reliably inherit (#798).
    @Environment(\.modelContext) private var modelContext

    /// Closes the guide behind a navigation that lands on another surface (#798).
    @Environment(\.dismiss) private var dismiss

    #if os(macOS)
    /// Opens the Archival Analytics window from the #795 cross-link. macOS-only, because
    /// `OpenWindowAction.fronting(id:)` is itself declared inside `#if os(macOS)`.
    @Environment(\.openWindow) private var openWindow
    #endif

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

    /// The share sheet and error state for this dashboard's exports (#790).
    @State private var exportBox = SeriesExportBox()

    /// Provenance categories hidden from the mix + composition charts (#236). Shares
    /// renormalize over the shown categories. `@State`, resets per visit.
    @State private var hiddenCategories: Set<SourceProvenanceCategory> = []

    /// The active subseries scope (#267). `@State`, resets per visit like the sibling
    /// dashboards — re-opening on a stale narrowed scope would misrepresent the series.
    @State private var scope = SeriesScope.whole

    /// Whether the guide is read mid-onboarding, which withholds the iOS door into Archival
    /// Analytics (#798, owner decision (a)). Defaulted, so the macOS window and any future caller
    /// keep today's behaviour.
    var presentationContext: IndexingEducationView.PresentationContext = .standalone

    /// Whether the iOS Archival Analytics sheet is up (#798).
    @State private var showsArchivalAnalytics = false

    /// The collection record whose detail sheet is up, set by a Top-collections row (#835).
    @State private var collectionDetail: AuthorityCollectionRecord?

    /// The manifest entries the scope bar derives its subseries menu from: the diff's known set
    /// when a live refresh has happened, else the bundled set, else empty.
    private var entries: [VolumeManifestEntry] {
        guard let store = appState?.manifestStore else { return [] }
        return store.diffResult?.known ?? store.bundledEntries
    }

    /// The pure derivation driving every chart, over the in-scope volumes (empty/zeroed when
    /// `AppState` or the resource is absent).
    private var data: SourceProvenanceData {
        SourceProvenanceData(index: appState?.sourceProvenanceStore.index,
                             scopeVolumeIds: scope.volumeIds)
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
                // Withheld rather than approximated when the artifact predates #267's
                // per-volume table — the Session-3 position, kept as the fallback.
                if data.supportsVolumeScope {
                    SeriesScopeBar(entries: entries, scope: $scope, onReset: {
                        yearStart = SeriesChartKind.floorYear
                        yearEnd = Self.defaultEnd
                    })
                }
                yearRangeBar
                categoryFilterBar
                mixOverTimeChart
                compositionChart
                densityChart
                TopCollectionsCard(entries: entries, scope: scope,
                                   yearStart: yearStart, yearEnd: yearEnd,
                                   onOpenCollection: appState == nil ? nil : { collectionDetail = $0 })
                archivalAnalyticsLink
                caveats
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
        // Guarded on AppState: `CollectionDetailView` declares a NON-optional
        // `@Environment(AppState.self)`, which traps on DECLARATION, and this page holds it
        // optionally by design. #844 is the crash this shape prevents.
        .sheet(item: $collectionDetail) { record in
            if let appState {
                CollectionDetailSheet(record: record)
                    .environment(appState)
                    .environment(\.sceneID, sceneID ?? .anyWindow)
            }
        }
        #if os(iOS)
        // Presented HERE, not through the hand-off: on iOS this page is itself a sheet inside the
        // tab shell, and the shell cannot present a second one while presenting this. The three
        // injections match `MainTabView.archivalSheet`. `onNavigateAway` closes the guide too —
        // otherwise a Browse hand-off from a collection record lands underneath it and nothing
        // appears to happen, the shape #844 fixed one level up.
        .sheet(isPresented: $showsArchivalAnalytics) {
            if let appState {
                ArchivalAnalyticsView(onNavigateAway: {
                    showsArchivalAnalytics = false
                    dismiss()
                })
                .environment(appState)
                .modelContainer(modelContext.container)
                .environment(\.sceneID, sceneID ?? .anyWindow)
                .statusBarHidden(false)
            }
        }
        #endif
        .seriesExportPresentation(exportBox)
    }

    // MARK: - Intro

    /// A short framing paragraph above the charts.
    private var intro: some View {
        Text(String(localized: "series.provenance.intro",
                    defaultValue: "Where did the editors of Foreign Relations of the United States find the documents they published? Since the early 20th century, every document carries a source note naming the archival file it came from. These charts read those notes across the whole series to trace how its archival base changed. The State Department's central files dominated almost completely until bureau lot files and presidential libraries appeared after the war. Modern volumes draw on a much wider range of sources."))
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

    // MARK: - Export provenance

    /// This dashboard's methods statement, shared by its three charts.
    ///
    /// The hidden-category list is the part that matters: hiding a category **re-bases every
    /// share** over what is left (#236), so a table exported under a filter is not a table of
    /// shares of all source notes, and only the preamble can say so.
    private func provenanceStatement(figureTitle: String, axisLabel: String,
                                     yearRange: ClosedRange<Int>?) -> AnalyticsProvenance {
        SeriesAnalyticsExport.provenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scope.label,
            yearRange: yearRange,
            volumeCount: data.volumesCovered,
            noteCount: data.totalSourceNotes,
            hiddenCategories: hiddenCategories.map(\.displayName))
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
                            defaultValue: "Each decade's source notes divided among the archival collections they cite, so every decade totals 100%. A volume's decade is set by the midpoint of its coverage. The trend begins in 1900 because earlier volumes carry no archival source notes."),
            inspector: ChartInspectorAdapters.provenanceMixTable(shares),
            provenance: provenanceStatement(
                figureTitle: String(localized: "series.provenance.trend.title",
                                    defaultValue: "Archival provenance over time"),
                axisLabel: String(localized: "series.export.axis.provenanceMix",
                                  defaultValue: "By coverage decade, share of source notes"),
                yearRange: domain.lowerBound...domain.upperBound),
            figureHeight: 300
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
                            defaultValue: "How many source notes across the whole series, from 1900 on, cite each kind of archival collection. The Central Decimal File dwarfs the rest. Most published FRUS documents came from the State Department's own central filing."),
            inspector: ChartInspectorAdapters.compositionTable(composition),
            provenance: provenanceStatement(
                figureTitle: String(localized: "series.provenance.composition.title",
                                    defaultValue: "Overall provenance composition"),
                axisLabel: String(localized: "series.export.axis.composition",
                                  defaultValue: "By provenance, across the whole span"),
                yearRange: nil),
            figureHeight: 300
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
                            defaultValue: "How many source notes each decade contributes. These are the counts behind the shares above. The 1940s carry the deepest base. Volumes covering the 1970s, 1980s, and 1990s are still in production, so those decades will look different as new volumes are released."),
            inspector: ChartInspectorAdapters.densityTable(density),
            provenance: provenanceStatement(
                figureTitle: String(localized: "series.provenance.density.title",
                                    defaultValue: "The documentary base by decade"),
                axisLabel: String(localized: "series.export.axis.density",
                                  defaultValue: "By coverage decade, source notes"),
                yearRange: domain.lowerBound...domain.upperBound),
            figureHeight: 240
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

    // MARK: - Cross-link

    /// The #795 rider: a pointer from this dashboard's ten provenance *categories* to the named
    /// collections behind them.
    ///
    /// **On iOS it is withheld mid-onboarding** (#798, owner decision (a)). The Mac has no
    /// onboarding path for this page, so its arm is unconditional; on iOS the page also renders
    /// inside `WhileIndexingSheet`, where the door would present a sheet over a sheet while the
    /// first index is still building. `presentationContext` is threaded from
    /// `IndexingEducationView` for exactly this decision.
    ///
    /// The iOS sheet is presented **locally** rather than through `AppState.openArchivalScope`:
    /// that hand-off is consumed by `MainTabView`'s own presenter, and on iOS this page is itself
    /// a sheet inside that shell — so the shell would be asked to present a second sheet while
    /// already presenting one. The three environment injections a sheet does not inherit are made
    /// here, as `MainTabView.archivalSheet` makes them.
    @ViewBuilder
    private var archivalAnalyticsLink: some View {
        #if os(iOS)
        if presentationContext == .standalone {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    showsArchivalAnalytics = true
                } label: {
                    Label(String(localized: "series.provenance.archivalLink",
                                 defaultValue: "Open Archival Analytics"),
                          systemImage: "archivebox")
                }
                Text(String(localized: "series.provenance.archivalLink.detail",
                            defaultValue: "This dashboard groups source notes into ten broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        #endif
        #if os(macOS)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                // `nil`, not a host: this dashboard is not a document window, so there is no
                // provenance to inherit — the same reason the menu-bar Analytics menu clears it.
                appState?.bindTool(.archivalAnalytics, to: nil)
                openWindow.fronting(id: "frus.archivalAnalytics")
            } label: {
                Label(String(localized: "series.provenance.archivalLink",
                             defaultValue: "Open Archival Analytics"),
                      systemImage: "archivebox")
            }
            Text(String(localized: "series.provenance.archivalLink.detail",
                        defaultValue: "This dashboard groups source notes into ten broad categories. Archival Analytics names the individual collections inside them, ranks them era by era, and shows which ones the same volumes drew on together."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        #endif
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
                            defaultValue: "Some categories are hidden. Each share below is a share of the categories still shown, not of all source notes. A decade with no notes in any shown category reads as zero rather than being skipped. Use the Categories menu above to show them all."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "series.provenance.caveats.body",
                        defaultValue: "These figures come from parsing each document's source note, the citation naming where its archival original was found. They are not drawn from a catalog of the archives. \"Other / Unclassified\" means a citation the parser could not classify, not a missing source note. Coverage spans 522 of the 552 catalogued volumes. Pre-1900 volumes are largely published diplomatic correspondence with no archival source notes, so the trend begins around 1900. Those early retrospective compilations are left out of the charts. The categories follow State Department filing practice. The Central Decimal File is the pre-1963 central filing system, and the Central Foreign Policy File is its post-1963 successor. Lot files were kept by individual bureaus, offices, and posts. Presidential libraries hold the White House records that dominate modern volumes. Remember that these counts show where FRUS editors drew their documents. That is an editorial and archival signal, not a full census of the underlying archives."))
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
    /// A titled, captioned chart card with its D3 export control (#790).
    ///
    /// The `content` closure is used twice — once for the card and once, unchanged, as the plate
    /// inside `AnalyticsFigureCanvas`. That is what keeps an exported figure identical to the one
    /// on screen: there is no second rendering of the chart to drift.
    ///
    /// - Parameter figureHeight: The plate's chart area. It matches the height the closure applies
    ///   to itself, so the exported figure is the same shape as the card's chart.
    private func chartCard<Content: View>(
        title: String,
        caption: String,
        inspector: ChartInspectorData?,
        provenance: AnalyticsProvenance,
        figureHeight: CGFloat = 300,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SeriesChartCard(
            title: title,
            caption: caption,
            inspector: inspector,
            onInspect: { inspectorData = $0 },
            controls: {
                SeriesChartExportControl(
                    table: inspector, provenance: provenance, box: exportBox,
                    figure: { format in
                        exportBox.deliverFigure(format, provenance: provenance,
                                                chartHeight: figureHeight, chart: content)
                    })
            },
            content: content
        )
    }
}
