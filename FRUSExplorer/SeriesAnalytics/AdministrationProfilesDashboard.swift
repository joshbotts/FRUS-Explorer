// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - AdministrationProfilesDashboard

/// The live "Administration Profiles" dashboard rendered inside the Research Guide
/// (Series Analytics SA-2b) — the fourth "About the Series" dashboard, after
/// Production & Timeliness (SA-1b), Geographic Emphasis (SA-2), and Archival
/// Sourcing (SA-3b).
///
/// It reads the bundled `administration-profiles-index.json` aggregate through
/// `AppState.administrationProfilesStore`, joins volume ids to titles through
/// `AppState.manifestStore`, derives a pure `AdministrationProfilesData`, and
/// renders two overview charts plus a per-administration detail card. Everything is
/// derived from the bundled aggregate, so it renders offline, with zero index,
/// mid-onboarding.
///
/// The dashboard measures **coverage** — which administration's foreign policy the
/// published documents concern — under an *any-overlap* attribution: a volume
/// spanning two administrations counts in both. Administrations are per-president,
/// so Nixon and Ford are distinct. An "Include editorial notes" toggle folds the
/// range-dated (editorial-note) documents into every count and proportion; it is
/// **off** by default so the headline figures rest on the firmer point-dated data,
/// and this is disclosed in the caveats.
///
/// `AppState` is read as an *optional* environment value (the defensive pattern
/// Prep-A established and SA-1b/SA-2/SA-3b followed): an absent environment
/// degrades to a neutral empty state rather than trapping.
///
/// Version history:
///   1.0 — Analytics SA-2b: initial implementation
///   1.1 — Analytics SA-2b review: key the overview charts' x-position and
///         `chartXScale(domain:)` on the distinct administration id (not the
///         president name), so Grover Cleveland's two non-consecutive terms no
///         longer collapse into one stacked bar; axis labels map the id back to a
///         year-disambiguated last name.
///   1.2 — Session 3 / #236: subseries scope bar (counts recompute from the
///         per-volume breakdown; coverage span hidden under scope) and the
///         previously-missing year-range bar (an administration shows when its term
///         overlaps the range), bringing this dashboard onto the same chrome as the
///         other three; a narrowed-empty state keeps the controls reachable.
///   1.3 — Session 3 review: the scope bar's and year bar's resets clear scope +
///         year range together (#236 plan item 7).
struct AdministrationProfilesDashboard: View {

    /// Optional so a missing environment yields a neutral empty state instead of
    /// a trap. Both live presentation paths (the onboarding sheet and the
    /// standalone Research Guide) inject `AppState` at the scene root, so this
    /// normally resolves; the optionality is purely defensive.
    @Environment(AppState.self) private var appState: AppState?

    /// Compact-width detection for the year-range bar (drops its label on iPhone).
    /// Resolves to `.regular` on macOS, so `isCompactWidth` is `false` there.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// This dashboard's default upper year: administrations run to the present, so
    /// the range ends at the production ceiling (the sitting administration's term
    /// has no end date).
    private static let defaultEnd = SeriesChartKind.productionCeilingYear

    /// The editable range's start year (floors at the series' start).
    @State private var yearStart = SeriesChartKind.floorYear
    /// The editable range's end year (defaults to the production ceiling).
    @State private var yearEnd = defaultEnd

    /// When `true`, range-dated (editorial-note) documents are folded into every
    /// count and proportion. Off by default (disclosed in the caveats).
    @State private var includeEditorialNotes = false

    /// The focus administration for the detail card, by slug. `nil` until the
    /// data resolves, then defaulted to the most-documented administration.
    @State private var selectedAdministrationID: String?

    /// The chart whose underlying data is currently shown in the table-inspector
    /// pop-up, or `nil` when none. Drives the single dashboard-level `.sheet`.
    @State private var inspectorData: ChartInspectorData?

    /// The share sheet and error state for this dashboard's exports (#790).
    @State private var exportBox = SeriesExportBox()

    /// The active subseries scope (#236). `@State`, so it resets per Research-Guide
    /// visit. Under a scope every count/proportion is recomputed from each
    /// administration's per-volume breakdown, and the coverage-span stat is hidden
    /// (it is a pre-aggregated scalar that cannot be re-derived per scope).
    @State private var scope = SeriesScope.whole

    /// The manifest entries backing the scope bar's subseries menu (this dashboard
    /// otherwise reads the bundled profiles index, not the manifest).
    private var entries: [VolumeManifestEntry] {
        guard let store = appState?.manifestStore else { return [] }
        return store.diffResult?.known ?? store.bundledEntries
    }

    /// The pure derivation driving every chart, rebuilt whenever the toggle or scope
    /// changes.
    private var data: AdministrationProfilesData {
        AdministrationProfilesData(
            index: appState?.administrationProfilesStore.index,
            includeEditorialNotes: includeEditorialNotes,
            scopeVolumeIds: scope.volumeIds
        )
    }

    /// The party color scale's domain — every party label present in the data, in
    /// stable order. Paired with `partyRange` so `chartForegroundStyleScale` gets
    /// BOTH halves (the CA-5 gotcha: an unpaired domain lets Swift Charts pick its
    /// own hues, which would mislead a party palette).
    private var partyDomain: [String] {
        PoliticalParty.ordered.map(\.displayName)
    }

    /// The party color scale's range — the color for each label in `partyDomain`.
    private var partyRange: [Color] {
        PoliticalParty.ordered.map(\.color)
    }

    /// `true` on compact-width (iPhone); always `false` on macOS / regular-width.
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// `true` when the range has been narrowed away from its `1861…2026` default.
    private var isCustomRange: Bool {
        yearStart != SeriesChartKind.floorYear || yearEnd != Self.defaultEnd
    }

    /// The scoped profiles further narrowed by the year range: an administration is
    /// shown when its term **overlaps** the range (the sitting administration's open
    /// term ends at the production ceiling). This is a term-year filter — the plan's
    /// "which administrations sat in these years" reading — not a re-count of documents.
    private var visibleProfiles: [AdministrationProfilesData.Profile] {
        data.profiles.filter { profile in
            guard let termStart = Int(profile.start.prefix(4)) else { return true }
            let termEnd = profile.end.flatMap { Int($0.prefix(4)) } ?? Self.defaultEnd
            return termStart <= yearEnd && termEnd >= yearStart
        }
    }

    /// The resolved focus profile: the selection if it is still visible, else the
    /// most-documented visible administration, else `nil`.
    private var focusProfile: AdministrationProfilesData.Profile? {
        let visible = visibleProfiles
        if let id = selectedAdministrationID,
           let match = visible.first(where: { $0.id == id }) {
            return match
        }
        return visible.max { $0.documentCount < $1.documentCount }
    }

    /// `true` when the bundled profiles index decoded to at least one administration —
    /// the guard for the "no data at all" empty state (distinct from a scope that simply
    /// touches no administration, which keeps the scope bar reachable so it can be reset).
    private var indexHasData: Bool {
        !(appState?.administrationProfilesStore.index?.administrations.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !indexHasData {
                emptyState
            } else {
                intro
                // Reset affordances clear scope + year range together (#236 plan
                // item 7): the scope bar's reset also restores the default years,
                // and the year bar's reset (below) also restores the whole series.
                SeriesScopeBar(entries: entries, scope: $scope, onReset: {
                    yearStart = SeriesChartKind.floorYear
                    yearEnd = Self.defaultEnd
                })
                yearRangeBar
                if visibleProfiles.isEmpty {
                    narrowedEmptyState
                } else {
                    editorialNotesToggle
                    documentsChart
                    volumesPerYearChart
                    administrationDetail
                    caveats
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $inspectorData) { ChartDataInspectorView(data: $0) }
        .seriesExportPresentation(exportBox)
        .onAppear {
            if selectedAdministrationID == nil {
                selectedAdministrationID = data.mostDocumentedProfile?.id
            }
        }
    }

    /// Shown when the active scope and/or year range leave no administration to show —
    /// keeps the controls above it reachable so the user can reset rather than seeing a
    /// blank (or worse, empty chart axes).
    private var narrowedEmptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "series.admin.narrowedEmpty.title",
                        defaultValue: "No administrations in view"))
                .font(.headline)
            Text(String(localized: "series.admin.narrowedEmpty.message",
                        defaultValue: "No administration matches your current scope and year range. The subseries you selected may carry no attributed documents, or your years may fall outside every presidential term. Reset the scope or year range above to see the whole series."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Year-range bar

    /// The editable start/end year filter (#236 — the one dashboard that lacked it):
    /// an administration is shown when its **term** overlaps the range, aligning the
    /// four Series dashboards on the same chrome. Counts are per-administration
    /// coverage attributions and are not themselves re-counted by year.
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
                scope = .whole
            }
        )
    }

    // MARK: - Intro

    /// A short framing paragraph above the charts.
    private var intro: some View {
        Text(String(localized: "series.admin.intro",
                    defaultValue: "Whose foreign policy does Foreign Relations of the United States document? Every dated document is assigned to the presidential administration in office when the events it records took place. These charts show how many documents each administration draws, and how densely the series covers each term. Select any administration to see which volumes carry its record."))
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Editorial-note toggle

    /// The "Include editorial notes (date ranges)" toggle. Flipping it recomputes
    /// every count and proportion.
    private var editorialNotesToggle: some View {
        Toggle(isOn: $includeEditorialNotes) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "series.admin.toggle.title",
                            defaultValue: "Include editorial notes (date ranges)"))
                    .font(.subheadline.weight(.medium))
                Text(String(localized: "series.admin.toggle.subtitle",
                            defaultValue: "Editorial-note documents carry a span of dates rather than a single date; including them adds them to every count and proportion."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        #if os(iOS)
        .toggleStyle(.switch)
        #endif
    }

    // MARK: - Chart 1: Documents per administration

    /// Bars of the document count for each populated administration, chronological
    /// and party-colored.
    private var documentsChart: some View {
        let profiles = visibleProfiles
        let labels = Self.axisLabels(for: profiles)
        return chartCard(
            title: String(localized: "series.admin.docs.title",
                          defaultValue: "Documents per administration"),
            caption: String(localized: "series.admin.docs.caption",
                            defaultValue: "How many published documents concern each administration's foreign policy, in chronological order. Any date overlap counts, so a volume spanning two terms counts in both.\n\nVolumes covering the 1970s, 1980s, and 1990s are still in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released."),
            inspector: ChartInspectorAdapters.administrationDocumentsTable(profiles),
            provenance: SeriesAnalyticsExport.administration(
                figureTitle: String(localized: "series.admin.docs.title",
                                    defaultValue: "Documents per administration"),
                axisLabel: String(localized: "series.export.axis.adminDocuments",
                                  defaultValue: "By administration, documents"),
                scopeLabel: scope.label, yearRange: yearStart...yearEnd,
                volumeCount: data.volumesCovered,
                includesEditorialNotes: includeEditorialNotes),
            figureHeight: 320
        ) {
            Chart {
                ForEach(profiles) { profile in
                    BarMark(
                        x: .value(
                            String(localized: "series.admin.docs.x", defaultValue: "Administration"),
                            profile.id
                        ),
                        y: .value(
                            String(localized: "series.admin.docs.y", defaultValue: "Documents"),
                            profile.documentCount
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.admin.party.legend", defaultValue: "Party"),
                        profile.party.displayName
                    ))
                    .accessibilityLabel(Text(profile.president))
                    .accessibilityValue(Text(profile.documentCount, format: .number))
                }
            }
            .chartForegroundStyleScale(domain: partyDomain, range: partyRange)
            .chartXScale(domain: profiles.map(\.id))
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .vertical) {
                        if let id = value.as(String.self), let label = labels[id] {
                            Text(label)
                        }
                    }
                    AxisTick()
                }
            }
            .chartXAxisLabel(String(localized: "series.admin.docs.x", defaultValue: "Administration"))
            .chartYAxisLabel(String(localized: "series.admin.docs.y", defaultValue: "Documents"))
            .frame(height: 320)
        }
    }

    // MARK: - Chart 2: Volumes per administration-year

    /// Bars of the volumes-per-term-year density for each populated administration,
    /// chronological and party-colored. Presented raw — no baseline reference line.
    private var volumesPerYearChart: some View {
        let profiles = visibleProfiles.filter { $0.termYears > 0 }
        let labels = Self.axisLabels(for: profiles)
        return chartCard(
            title: String(localized: "series.admin.perYear.title",
                          defaultValue: "Volumes per administration-year"),
            caption: String(localized: "series.admin.perYear.caption",
                            defaultValue: "How many volumes cover each administration, divided by the length of its term in years. This measures how densely the series covers each presidency. The sitting administration has no end date, so it is left out.\n\nVolumes covering the 1970s, 1980s, and 1990s are still in production. The Carter, Reagan, H.W. Bush, and Clinton administrations will look different as new volumes are released."),
            inspector: ChartInspectorAdapters.administrationVolumesPerYearTable(profiles),
            provenance: SeriesAnalyticsExport.administration(
                figureTitle: String(localized: "series.admin.perYear.title",
                                    defaultValue: "Volumes per administration-year"),
                axisLabel: String(localized: "series.export.axis.adminPerYear",
                                  defaultValue: "By administration, volumes per term-year"),
                scopeLabel: scope.label, yearRange: yearStart...yearEnd,
                volumeCount: data.volumesCovered,
                includesEditorialNotes: includeEditorialNotes),
            figureHeight: 320
        ) {
            Chart {
                ForEach(profiles) { profile in
                    BarMark(
                        x: .value(
                            String(localized: "series.admin.perYear.x", defaultValue: "Administration"),
                            profile.id
                        ),
                        y: .value(
                            String(localized: "series.admin.perYear.y", defaultValue: "Volumes per year"),
                            profile.volumesPerAdministrationYear
                        )
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "series.admin.party.legend", defaultValue: "Party"),
                        profile.party.displayName
                    ))
                    .accessibilityLabel(Text(profile.president))
                    .accessibilityValue(Text(profile.volumesPerAdministrationYear, format: .number.precision(.fractionLength(1))))
                }
            }
            .chartForegroundStyleScale(domain: partyDomain, range: partyRange)
            .chartXScale(domain: profiles.map(\.id))
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .vertical) {
                        if let id = value.as(String.self), let label = labels[id] {
                            Text(label)
                        }
                    }
                    AxisTick()
                }
            }
            .chartXAxisLabel(String(localized: "series.admin.perYear.x", defaultValue: "Administration"))
            .chartYAxisLabel(String(localized: "series.admin.perYear.y", defaultValue: "Volumes per year"))
            .frame(height: 320)
        }
    }

    // MARK: - Administration detail

    /// The administration picker, profile card, and per-administration volume
    /// list.
    private var administrationDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "series.admin.detail.title", defaultValue: "Administration detail"))
                .font(.headline)

            Picker(
                String(localized: "series.admin.detail.picker", defaultValue: "Administration"),
                selection: Binding(
                    get: { focusProfile?.id ?? "" },
                    set: { selectedAdministrationID = $0 }
                )
            ) {
                ForEach(visibleProfiles) { profile in
                    Text(pickerLabel(for: profile)).tag(profile.id)
                }
            }
            .pickerStyle(.menu)

            if let profile = focusProfile {
                profileCard(profile)
                volumeList(for: profile)
            }
        }
    }

    /// The profile summary card for one administration.
    ///
    /// - Parameter profile: The focus administration.
    /// - Returns: A card of president, party, term, counts, density, coverage span.
    private func profileCard(_ profile: AdministrationProfilesData.Profile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile.president)
                    .font(.title3.weight(.semibold))
                Text(profile.party.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(profile.party.color.opacity(0.18), in: Capsule())
                    .foregroundStyle(profile.party.color)
            }

            statRow(
                label: String(localized: "series.admin.stat.term", defaultValue: "Term"),
                value: termText(profile)
            )
            statRow(
                label: String(localized: "series.admin.stat.documents", defaultValue: "Documents"),
                value: documentsText(profile)
            )
            statRow(
                label: String(localized: "series.admin.stat.volumes", defaultValue: "Volumes"),
                value: profile.volumeCount.formatted(.number)
            )
            if profile.termYears > 0 {
                statRow(
                    label: String(localized: "series.admin.stat.density", defaultValue: "Volumes per term-year"),
                    value: profile.volumesPerAdministrationYear.formatted(.number.precision(.fractionLength(1)))
                )
            }
            if let earliest = profile.coverageEarliest, let latest = profile.coverageLatest {
                statRow(
                    label: String(localized: "series.admin.stat.coverage", defaultValue: "Coverage span"),
                    value: coverageText(earliest: earliest, latest: latest)
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    /// The per-administration volume list: each row = title + proportion + doc
    /// count, sorted by document count descending, scrollable, count disclosed.
    ///
    /// - Parameter profile: The focus administration.
    /// - Returns: A titled, scrollable list of volume-proportion rows.
    private func volumeList(for profile: AdministrationProfilesData.Profile) -> some View {
        let rows = data.volumeShares(for: profile.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "series.admin.volumes.header",
                        defaultValue: "Volumes covering this administration (\(rows.count))"))
                .font(.subheadline.weight(.semibold))
            Text(String(localized: "series.admin.volumes.caption",
                        defaultValue: "Each volume's share is the fraction of that volume's documents that fall in this administration — so shares can sum past 100% across administrations under any-overlap attribution."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if rows.isEmpty {
                Text(String(localized: "series.admin.volumes.empty", defaultValue: "No volumes attributed."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            volumeRow(row)
                            if row.id != rows.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    /// One volume-proportion row.
    ///
    /// - Parameter row: The volume share.
    /// - Returns: A row of title, doc count, and proportion.
    private func volumeRow(_ row: AdministrationProfilesData.VolumeShare) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(volumeTitle(for: row.id))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "series.admin.volumes.docCount",
                            defaultValue: "\(row.documentCount) documents"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(row.proportion, format: FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    /// One label/value line in the profile card.
    ///
    /// - Parameters:
    ///   - label: The stat name.
    ///   - value: The formatted value.
    /// - Returns: A baseline-aligned label/value row.
    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }

    // MARK: - Caveats

    /// A footer stating the honest limits of the administration attribution.
    private var caveats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "series.admin.caveats.title", defaultValue: "About these figures"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let label = scope.label {
                Text(String(format: String(localized: "series.admin.caveats.scope %@",
                                           defaultValue: "Scoped to the %@ subseries. Counts and proportions come from that subseries' volumes alone. The coverage span for each administration is hidden here, because the source data pre-aggregates it for the whole series. Reset the scope above to see the whole series."),
                            label))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(String(localized: "series.admin.caveats.body",
                        defaultValue: "A document counts toward an administration if its dates overlap that president's term at all. A volume spanning two administrations therefore counts in both. That is why the volume counts add up to more than the series' 552 volumes. It is also why one volume's proportions can total over 100% across administrations. These counts measure whose foreign policy the documents cover, not when the volumes were published. Editorial notes carry a range of dates rather than a single date. The toggle above decides whether they are counted, and it is off by default. Retrospective compilations covering years before 1861 concern no single administration and are left out. Each president is counted separately: Nixon and Ford are distinct, as are Grover Cleveland's two non-consecutive terms. Administrations the series has not yet published do not appear."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Empty state

    /// Neutral state shown when no administration profiles are available (e.g.
    /// `AppState` absent or the resource missing). Never a crash.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "series.admin.empty.title", defaultValue: "No administration data"))
                .font(.headline)
            Text(String(localized: "series.admin.empty.message",
                        defaultValue: "The bundled administration-profiles index is unavailable in this context."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chart card

    /// A titled, captioned container for a single chart, keeping the sections
    /// visually consistent (mirrors the SA-1b/SA-2/SA-3b dashboard card). When
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

    // MARK: - Helpers

    /// The volume's manifest title, falling back to the raw `volumeId` when the
    /// manifest has no entry.
    ///
    /// - Parameter volumeId: The volume identifier.
    /// - Returns: The manifest title or, failing that, the id itself.
    private func volumeTitle(for volumeId: String) -> String {
        appState?.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    /// The picker menu label for one administration — the president's name, with
    /// the term span appended when another administration shares the identical name
    /// (Grover Cleveland's two non-consecutive terms) so the two rows are distinct.
    ///
    /// - Parameter profile: The administration.
    /// - Returns: The disambiguated menu label.
    private func pickerLabel(for profile: AdministrationProfilesData.Profile) -> String {
        let sharesName = data.profiles.filter { $0.president == profile.president }.count > 1
        guard sharesName else { return profile.president }
        return String(localized: "series.admin.picker.disambiguated",
                      defaultValue: "\(profile.president) (\(termText(profile)))")
    }

    /// The term-dates line for the profile card.
    ///
    /// - Parameter profile: The administration.
    /// - Returns: A `"1969–1974"` style span (or `"1969–present"` for a null end).
    private func termText(_ profile: AdministrationProfilesData.Profile) -> String {
        let startYear = Self.year(from: profile.start)
        if let end = profile.end {
            let endYear = Self.year(from: end)
            return "\(startYear)\u{2013}\(endYear)"
        }
        return String(localized: "series.admin.term.present", defaultValue: "\(startYear)–present")
    }

    /// The documents line for the profile card — point-only, or point + range when
    /// editorial notes are included.
    ///
    /// - Parameter profile: The administration.
    /// - Returns: The formatted documents description.
    private func documentsText(_ profile: AdministrationProfilesData.Profile) -> String {
        if includeEditorialNotes {
            return String(localized: "series.admin.docs.pointPlusRange",
                          defaultValue: "\(profile.documentCount) (\(profile.pointDocCount) dated + \(profile.rangeDocCount) editorial notes)")
        }
        return profile.pointDocCount.formatted(.number)
    }

    /// The coverage-span line for the profile card.
    ///
    /// - Parameters:
    ///   - earliest: The earliest coverage year.
    ///   - latest: The latest coverage year.
    /// - Returns: A `"1969–1976"` style span.
    private func coverageText(earliest: Int, latest: Int) -> String {
        "\(String(earliest))\u{2013}\(String(latest))"
    }

    /// The year portion of a `yyyy-MM-dd` string (the leading four characters);
    /// the whole string when it is shorter.
    ///
    /// - Parameter iso: The ISO date string.
    /// - Returns: The four-digit year, or the input when too short.
    private static func year(from iso: String) -> String {
        iso.count >= 4 ? String(iso.prefix(4)) : iso
    }

    /// The last whitespace-delimited token of a president's name — the compact
    /// axis label (e.g. `"Richard M. Nixon"` → `"Nixon"`).
    ///
    /// - Parameter fullName: The president's display name.
    /// - Returns: The final name token, or the whole string when it has none.
    static func lastName(_ fullName: String) -> String {
        fullName.split(separator: " ").last.map(String.init) ?? fullName
    }

    /// The per-administration axis labels, keyed by administration id.
    ///
    /// Each label is the president's last name; when two administrations share the
    /// same last name (Grover Cleveland's two non-consecutive terms, the two
    /// Johnsons, the two Roosevelts, and so on) the term's start year is appended
    /// so the two categorical bars stay visually distinct — the axis is keyed on
    /// the distinct administration id, so the bars never merge, but their labels
    /// would otherwise collide.
    ///
    /// - Parameter profiles: The profiles rendered on the chart.
    /// - Returns: A map from administration id to its axis label.
    static func axisLabels(for profiles: [AdministrationProfilesData.Profile]) -> [String: String] {
        var counts: [String: Int] = [:]
        for profile in profiles {
            counts[lastName(profile.president), default: 0] += 1
        }
        var labels: [String: String] = [:]
        for profile in profiles {
            let name = lastName(profile.president)
            if counts[name, default: 0] > 1 {
                labels[profile.id] = "\(name) \(year(from: profile.start))"
            } else {
                labels[profile.id] = name
            }
        }
        return labels
    }
}
