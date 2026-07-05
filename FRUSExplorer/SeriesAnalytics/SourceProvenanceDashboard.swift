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
struct SourceProvenanceDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead of
    /// a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// The pure derivation driving every chart, built from the bundled aggregate
    /// (empty/zeroed when `AppState` or the resource is absent).
    private var data: SourceProvenanceData {
        SourceProvenanceData(index: appState?.sourceProvenanceStore.index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if data.shareByDecade.isEmpty {
                emptyState
            } else {
                intro
                mixOverTimeChart
                compositionChart
                densityChart
                caveats
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Chart 1: Provenance mix over time (stacked area, the anchor)

    /// Stacked area of each provenance category's share of a decade's source
    /// notes, over coverage decades from 1900. The anchor chart.
    private var mixOverTimeChart: some View {
        let data = data
        return chartCard(
            title: String(localized: "series.provenance.trend.title",
                          defaultValue: "Archival provenance over time"),
            caption: String(localized: "series.provenance.trend.caption",
                            defaultValue: "Each decade's source notes divided among the archival collections they cite, so every decade sums to 100%. Decades are set by each volume's coverage midpoint; the trend begins in 1900 because earlier volumes carry no archival source notes.")
        ) {
            Chart {
                ForEach(data.shareByDecade) { point in
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
            .chartYScale(domain: 0...1)
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
        let data = data
        return chartCard(
            title: String(localized: "series.provenance.composition.title",
                          defaultValue: "Overall provenance composition"),
            caption: String(localized: "series.provenance.composition.caption",
                            defaultValue: "How many source notes across the whole series (from 1900) cite each kind of archival collection. The Central Decimal File dwarfs the rest — most published FRUS documents came from the State Department's own central filing.")
        ) {
            Chart {
                ForEach(data.overallComposition) { item in
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
        let data = data
        return chartCard(
            title: String(localized: "series.provenance.density.title",
                          defaultValue: "The documentary base by decade"),
            caption: String(localized: "series.provenance.density.caption",
                            defaultValue: "How many source notes each decade contributes — the density behind the shares above. The 1940s carry the deepest base; a share in a thin decade rests on far fewer documents.")
        ) {
            Chart {
                ForEach(data.notesByDecade) { item in
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
    /// sections visually consistent (mirrors the SA-1b/SA-2 dashboard card).
    private func chartCard<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }
}
