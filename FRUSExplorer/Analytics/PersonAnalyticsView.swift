// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - PersonTrajectoryNormalization

/// How the multi-person trajectory chart expresses its y-values (CA-5).
///
/// - `raw`: absolute mention counts (mentions in dated documents).
/// - `percentOfDocuments`: each person's mentioning-document count in year Y as a share
///   of **all dated documents** in year Y. Both numerator and denominator are drawn from
///   the dated-only join (`PersonMentionStore.mentioningDocumentTrajectories` /
///   `datedDocumentTotalsByYear`), so a within-year share can never exceed 100%.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
enum PersonTrajectoryNormalization: String, CaseIterable {
    case raw
    case percentOfDocuments

    /// `UserDefaults`/`@AppStorage` key for the persisted per-user choice.
    static let storageKey = "frus.personAnalytics.normalizationMode"

    /// Short label for the segmented picker.
    var pickerLabel: String {
        switch self {
        case .raw:
            return String(localized: "personAnalytics.normalize.raw", defaultValue: "Raw count")
        case .percentOfDocuments:
            return String(localized: "personAnalytics.normalize.percent", defaultValue: "% of documents")
        }
    }
}

// MARK: - PersonTrajectoryPoint

/// One plotted point in the multi-person trajectory chart: a person series, a year,
/// and its value (raw mention count, or a document share in `0...1`).
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
struct PersonTrajectoryPoint: Identifiable, Equatable {
    /// The rollup id, keying the color series.
    let rollupId: Int
    /// The person's canonical display name (the chart series label).
    let name: String
    /// The coverage year.
    let year: Int
    /// The plotted value — a raw mention count, or a `0...1` document share.
    let value: Double

    var id: String { "\(rollupId)/\(year)" }
}

// MARK: - PersonAnalyticsMath

/// Pure, view-independent transforms behind `PersonAnalyticsView`, factored out so the
/// bucketing / ranking / normalization rules can be unit-tested without a SwiftUI host
/// or a live SQLite connection.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
enum PersonAnalyticsMath {

    /// Flattens raw `rollupId → year → count` trajectories into chart points, filtered
    /// to `range` and sorted by (series, year). Years outside `range` are dropped so the
    /// chart matches the year-range bar without a re-query.
    static func rawPoints(
        trajectories: [Int: [Int: Int]],
        names: [Int: String],
        range: ClosedRange<Int>
    ) -> [PersonTrajectoryPoint] {
        var points: [PersonTrajectoryPoint] = []
        for (rollupId, byYear) in trajectories {
            let name = names[rollupId] ?? ""
            for (year, count) in byYear where range.contains(year) {
                points.append(PersonTrajectoryPoint(rollupId: rollupId, name: name,
                                                    year: year, value: Double(count)))
            }
        }
        return points.sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }

    /// Converts `rollupId → year → mentioning-document count` into document-share points
    /// (`0...1`), dividing each by the dated-document total for that year. Years absent
    /// from `totals`, or with a zero/negative total, are skipped (no denominator). Because
    /// both the numerator (distinct dated documents mentioning the person) and the
    /// denominator (all dated documents) come from the same dated population, every share
    /// is clamped into `0...1` — a share can never exceed 100%.
    static func sharePoints(
        mentioningDocs: [Int: [Int: Int]],
        totals: [Int: Int],
        names: [Int: String],
        range: ClosedRange<Int>
    ) -> [PersonTrajectoryPoint] {
        var points: [PersonTrajectoryPoint] = []
        for (rollupId, byYear) in mentioningDocs {
            let name = names[rollupId] ?? ""
            for (year, docs) in byYear where range.contains(year) {
                guard let total = totals[year], total > 0 else { continue }
                let share = min(1.0, Double(docs) / Double(total))
                points.append(PersonTrajectoryPoint(rollupId: rollupId, name: name,
                                                    year: year, value: share))
            }
        }
        return points.sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }

    /// Buckets year-keyed points into decades (year floored to the nearest ten), summing
    /// raw values and averaging shares. Used by the decade toggle. `isShare` selects the
    /// aggregation: raw counts sum, document shares are averaged across the decade's years
    /// (a share can't be summed without exceeding 100%).
    static func bucketByDecade(_ points: [PersonTrajectoryPoint], isShare: Bool) -> [PersonTrajectoryPoint] {
        struct Key: Hashable { let rollupId: Int; let decade: Int }
        var sums: [Key: Double] = [:]
        var counts: [Key: Int] = [:]
        var names: [Int: String] = [:]
        for p in points {
            let decade = (p.year / 10) * 10
            let key = Key(rollupId: p.rollupId, decade: decade)
            sums[key, default: 0] += p.value
            counts[key, default: 0] += 1
            names[p.rollupId] = p.name
        }
        return sums.map { key, sum in
            let value = isShare ? sum / Double(max(1, counts[key] ?? 1)) : sum
            return PersonTrajectoryPoint(rollupId: key.rollupId, name: names[key.rollupId] ?? "",
                                         year: key.decade, value: value)
        }
        .sorted { $0.rollupId != $1.rollupId ? $0.rollupId < $1.rollupId : $0.year < $1.year }
    }
}

// MARK: - PersonAnalyticsMode

/// Top-level surface of `PersonAnalyticsView` (CA-8): the scrolling trends dashboard vs
/// the full-frame co-mention network. A `Canvas` and a `ScrollView` do not mix, so the
/// network takes the whole frame rather than living as a section inside the trends scroll.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
enum PersonAnalyticsMode: String, CaseIterable {
    /// Rankings, trajectories, and the two-person relationship-dynamics chart.
    case trends
    /// The person co-mention ego network (`PersonCoMentionGraphView`).
    case network

    /// Segmented-picker label.
    var pickerLabel: String {
        switch self {
        case .trends:
            return String(localized: "personAnalytics.mode.trends", defaultValue: "Trends")
        case .network:
            return String(localized: "personAnalytics.mode.network", defaultValue: "Network")
        }
    }
}

// MARK: - PersonRelationshipPoint

/// One plotted point in the two-person relationship-dynamics chart (CA-8): a year and the
/// number of documents co-mentioning both selected people.
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
struct PersonRelationshipPoint: Identifiable, Equatable {
    /// The coverage year (or decade, when bucketed).
    let year: Int
    /// Distinct dated documents co-mentioning both people in `year`.
    let coMentions: Int

    var id: Int { year }
}

/// Pure transforms for the two-person relationship-dynamics chart, factored out for unit
/// testing without a SwiftUI host or a live database (CA-8).
///
/// Version history:
///   1.0 — CA-8 (analytics CA-track): initial implementation
enum PersonRelationshipMath {

    /// Flattens a `year → co-mention count` map into chart points inside `range`, sorted by
    /// year. Years outside `range` are dropped so the chart matches the year-range bar.
    static func points(timeline: [Int: Int], range: ClosedRange<Int>) -> [PersonRelationshipPoint] {
        timeline
            .filter { range.contains($0.key) }
            .map { PersonRelationshipPoint(year: $0.key, coMentions: $0.value) }
            .sorted { $0.year < $1.year }
    }

    /// Buckets year-keyed points into decades (year floored to the nearest ten), SUMMING the
    /// co-mention counts (raw counts, so summation is correct — unlike a share).
    static func bucketByDecade(_ points: [PersonRelationshipPoint]) -> [PersonRelationshipPoint] {
        var sums: [Int: Int] = [:]
        for p in points {
            let decade = (p.year / 10) * 10
            sums[decade, default: 0] += p.coMentions
        }
        return sums.map { PersonRelationshipPoint(year: $0.key, coMentions: $0.value) }
            .sorted { $0.year < $1.year }
    }
}

// MARK: - PersonAnalyticsView

/// Corpus person analytics (CA-5): the most-mentioned people in a coverage era and a
/// multi-person mention-trajectory comparison, over the local SQLite index.
///
/// ## What it shows
/// - **Most-mentioned people by era** — for the selected year range, the top-N person
///   rollups by mention count, as a ranked bar chart or table. The honest replacement
///   for the removed `CorpusAnalyticsService.topTermsByYear` stub.
/// - **Multi-person mention-trajectory comparison** — a search-to-add picker (chips,
///   capped at `maxComparisonPeople`) driving a multi-series line chart of each selected
///   person's mentions over time, with a Raw / `% of documents` toggle.
///
/// ## Identity
/// A "person" is a `person_rollup` cluster (the People browser's identity), so a person
/// tracked across volumes counts as one. All counts come from the dated join
/// (`person_mentions × person_rollup_member × document_dates`): mentions in undated
/// documents can't be placed on the year axis, so they are excluded and disclosed
/// ("mentions in dated documents") rather than silently dropped.
///
/// ## Normalization population (the CA-4 lesson)
/// The `% of documents` numerator (distinct dated documents mentioning a person in year Y)
/// and the denominator (all dated documents in year Y) are BOTH dated-only, so a share
/// never exceeds 100%. This deliberately does not reuse
/// `CorpusAnalyticsService.documentTotalsByYear`, whose volume-start-year fallback for
/// undated documents would mismatch this dated-only numerator.
///
/// ## No-index degradation
/// When `appState.personMentionStore` is `nil` (index unavailable), a
/// `ContentUnavailableView` placeholder is shown instead — mirroring how `AnalyticsView`
/// handles a `nil` `analyticsService`.
///
/// ## Platform placement
/// - **macOS**: standalone `frus.personAnalytics` Window.
/// - **iOS**: sheet presented from the Browse "Analysis Tools" menu.
///
/// ## Modes (CA-8)
/// A top-level **Trends / Network** picker splits the surface: *Trends* is the scrolling
/// dashboard (rankings + trajectories + the two-person relationship-dynamics chart);
/// *Network* is the full-frame `PersonCoMentionGraphView` co-mention ego graph (a `Canvas`
/// and a `ScrollView` do not mix, so the network takes the whole frame). Both share the
/// store and the no-index placeholder. When EXACTLY two people are in the comparison, a
/// relationship-dynamics bar chart of their shared-document count over time appears inline.
///
/// Version history:
///   1.0 — CA-5 (analytics CA-track): initial implementation
///   1.1 — CA-5 review fixes: explicit color-scale domain (chip/line color parity) and a
///         latest-fetch token guarding the trajectory refetch race
///   1.2 — CA-8 (analytics CA-track): Trends/Network mode picker, the co-mention ego
///         network (full-frame), and the two-person relationship-dynamics chart
struct PersonAnalyticsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Tunables

    /// Maximum people in the comparison chart — the documented cap (no silent truncation:
    /// the add field disables at the cap and says why).
    private static let maxComparisonPeople = 5
    /// Top-N size for the "most mentioned" ranking.
    private static let rankingLimit = 15

    // MARK: - State

    @State private var yearRangeStart: Int = 1861
    @State private var yearRangeEnd: Int = Calendar.current.component(.year, from: Date())
    @State private var didSeedYearRange = false

    @State private var ranking: [PersonMentionRanking] = []
    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var isLoadingRanking = false

    /// Trends vs Network top-level mode (CA-8). The network takes the full frame.
    @State private var mode: PersonAnalyticsMode = .trends

    /// The focus person driving Network mode (CA-8). Defaults to the top-ranked person, or
    /// a person the user has tapped/selected.
    @State private var networkFocus: PersonMentionRanking? = nil

    /// The two-person relationship-dynamics timeline (year → co-mention count), loaded when
    /// EXACTLY two people are in the comparison (CA-8).
    @State private var relationshipTimeline: [Int: Int] = [:]
    @State private var isLoadingRelationship = false
    /// Latest-fetch token guarding the relationship refetch race (mirrors the trajectory guard).
    @State private var relationshipFetchToken = 0

    /// Selected people (rollups) for the comparison, in add order. Capped at
    /// `maxComparisonPeople`.
    @State private var selectedPeople: [PersonMentionRanking] = []
    @State private var searchText: String = ""
    @State private var searchResults: [PersonMentionRanking] = []

    /// Raw mention trajectories (rollup → year → count) for the selected people.
    @State private var rawTrajectories: [Int: [Int: Int]] = [:]
    /// Mentioning-document trajectories (rollup → year → distinct-dated-doc count),
    /// the normalized numerator.
    @State private var mentioningDocs: [Int: [Int: Int]] = [:]
    /// Dated-document totals per year — the normalized denominator.
    @State private var datedTotals: [Int: Int] = [:]
    @State private var isLoadingTrajectories = false

    /// Monotonic token identifying the most recently issued trajectory fetch. A fetch only
    /// writes its results back if it is still the latest, so a fast double-add can't let an
    /// earlier task's (smaller) selection clobber a later task's fuller one (finding CA-5-2).
    @State private var trajectoryFetchToken = 0

    /// Decade toggle for the trajectory chart. Off → per-year.
    /// Active volume scope for every Person Analytics query (`nil` = whole corpus). Set via the
    /// scope bar; drives the ranking, trajectories, relationship timeline, and co-mention
    /// network so project-specific person trends become visible (#189-B).
    @State private var scopeVolumeIds: [String]? = nil
    /// Human-readable label for `scopeVolumeIds`, shown in the scope bar.
    @State private var scopeLabel: String? = nil
    @State private var byDecade = false

    /// Persisted normalization choice (default Raw).
    @AppStorage(PersonTrajectoryNormalization.storageKey)
    private var normalization: PersonTrajectoryNormalization = .raw

    // MARK: - Derived

    /// Most recent corpus year — the year-range upper bound and reset target.
    private var corpusMaxYear: Int {
        Calendar(identifier: .gregorian)
            .component(.year, from: appState.manifestStore.corpusDateRange.upperBound)
    }

    private var yearRange: ClosedRange<Int> {
        let lo = min(yearRangeStart, yearRangeEnd)
        let hi = max(yearRangeStart, yearRangeEnd)
        return lo...hi
    }

    private var yearRangeIsCustom: Bool {
        yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear
    }

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    private var isNormalized: Bool { normalization == .percentOfDocuments }

    private var atComparisonCap: Bool { selectedPeople.count >= Self.maxComparisonPeople }

    /// Names keyed by rollup id, for the chart series labels.
    private var selectedNames: [Int: String] {
        Dictionary(uniqueKeysWithValues: selectedPeople.map { ($0.rollupId, $0.canonicalName) })
    }

    /// The chart points for the current normalization + decade toggle.
    private var trajectoryPoints: [PersonTrajectoryPoint] {
        let base: [PersonTrajectoryPoint]
        if isNormalized {
            base = PersonAnalyticsMath.sharePoints(
                mentioningDocs: mentioningDocs, totals: datedTotals,
                names: selectedNames, range: yearRange)
        } else {
            base = PersonAnalyticsMath.rawPoints(
                trajectories: rawTrajectories, names: selectedNames, range: yearRange)
        }
        return byDecade ? PersonAnalyticsMath.bucketByDecade(base, isShare: isNormalized) : base
    }

    /// Whether EXACTLY two people are selected — the trigger for relationship dynamics (CA-8).
    private var isTwoPersonComparison: Bool { selectedPeople.count == 2 }

    /// The relationship-dynamics chart points for the current year range + decade toggle (CA-8).
    private var relationshipPoints: [PersonRelationshipPoint] {
        let base = PersonRelationshipMath.points(timeline: relationshipTimeline, range: yearRange)
        return byDecade ? PersonRelationshipMath.bucketByDecade(base) : base
    }

    /// The current Network-mode focus person: an explicit selection, else the top-ranked (CA-8).
    private var effectiveNetworkFocus: PersonMentionRanking? {
        networkFocus ?? ranking.first
    }

    /// Stable color for a person, by their position in the selection.
    private func color(forRollupId rollupId: Int) -> Color {
        let idx = selectedPeople.firstIndex { $0.rollupId == rollupId } ?? 0
        return ChartSeriesPalette.color(at: idx)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.personMentionStore == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        scopeBar
                        Divider()
                        switch mode {
                        case .trends:  content
                        case .network: networkContent
                        }
                    }
                }
            }
            .navigationTitle(
                String(localized: "personAnalytics.title", defaultValue: "Person Analytics")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 560)
        #endif
        .task {
            seedDefaultYearRange()
            await loadRanking()
        }
        .onChange(of: yearRange) { _, _ in
            Task { await loadRanking() }
        }
    }

    // MARK: - Scope

    /// The shared analysis-scope selector, applied to every Person Analytics query in both the
    /// Trends and Network modes (#189-B).
    private var scopeBar: some View {
        AnalyticsScopeBar(
            indexedVolumeIds: appState.indexedVolumeIds,
            volumeTitle: { appState.manifestStore.entry(forVolumeId: $0)?.title ?? $0 },
            scopeVolumeIds: $scopeVolumeIds,
            scopeLabel: $scopeLabel,
            onChange: reloadForScopeChange
        )
    }

    /// Re-runs the trends-mode queries after the scope changes. The Network graph reloads
    /// itself — its `.task` is keyed on the scope — so it is not refetched here.
    private func reloadForScopeChange() {
        Task {
            await loadRanking()
            await loadTrajectories()
            await loadRelationship()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                yearRangeBar
                Divider()
                rankingSection
                Divider()
                comparisonSection
            }
            .padding(.vertical, 8)
        }
    }

    private var yearRangeBar: some View {
        AnalyticsYearRangeBar(
            start: $yearRangeStart,
            end: $yearRangeEnd,
            corpusMaxYear: corpusMaxYear,
            isCompactWidth: isCompactWidth,
            isCustom: yearRangeIsCustom,
            onReset: {
                yearRangeStart = 1861
                yearRangeEnd = corpusMaxYear
            }
        )
    }

    // MARK: - Ranking Section

    @ViewBuilder
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "personAnalytics.ranking.heading",
                        defaultValue: "Most-Mentioned People"))
                .font(.headline)
                .padding(.horizontal)

            Text(String(localized: "personAnalytics.ranking.subtitle",
                        defaultValue: "Top people by mentions in dated documents, \(yearRange.lowerBound)–\(yearRange.upperBound). Tap a person to compare them below."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if isLoadingRanking {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if ranking.isEmpty {
                ContentUnavailableView(
                    String(localized: "personAnalytics.ranking.empty.title", defaultValue: "No People in Range"),
                    systemImage: "person.2",
                    description: Text(String(
                        localized: "personAnalytics.ranking.empty.detail",
                        defaultValue: "No dated documents in this year range mention indexed people. Widen the range or index more volumes."))
                )
            } else if viewMode == .chart {
                rankingChart
            } else {
                rankingTable
            }
        }
    }

    private var rankingChart: some View {
        Chart(ranking) { row in
            BarMark(
                x: .value(String(localized: "personAnalytics.axis.mentions", defaultValue: "Mentions"),
                          row.mentionCount),
                y: .value(String(localized: "personAnalytics.axis.person", defaultValue: "Person"),
                          row.canonicalName)
            )
            .foregroundStyle(Color.accentColor)
            .annotation(position: .trailing) {
                Text(row.mentionCount, format: .number)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisValueLabel()
            }
        }
        .frame(height: CGFloat(ranking.count) * 30 + 40)
        .padding(.horizontal)
    }

    private var rankingTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranking.enumerated()), id: \.element.id) { index, row in
                Button {
                    toggleSelection(row)
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        Text(row.canonicalName)
                            .font(.body)
                        Spacer()
                        Text(row.mentionCount, format: .number)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if isSelected(row) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .contextMenu { findMentionsButton(row) }
                Divider()
            }
        }
    }

    // MARK: - Comparison Section

    @ViewBuilder
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "personAnalytics.comparison.heading",
                        defaultValue: "Mention Trajectories"))
                .font(.headline)
                .padding(.horizontal)

            searchToAddField

            if !selectedPeople.isEmpty {
                selectionChips
            }

            if selectedPeople.isEmpty {
                Text(String(localized: "personAnalytics.comparison.empty",
                            defaultValue: "Add up to \(Self.maxComparisonPeople) people — from the ranking above or the search field — to compare how often each is mentioned over time."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else if isLoadingTrajectories {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if trajectoryPoints.isEmpty {
                ContentUnavailableView(
                    String(localized: "personAnalytics.comparison.noData.title", defaultValue: "No Dated Mentions"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(String(
                        localized: "personAnalytics.comparison.noData.detail",
                        defaultValue: "The selected people have no mentions in dated documents within this year range."))
                )
            } else {
                trajectoryChart
                trajectoryCaption
            }

            if isTwoPersonComparison {
                Divider().padding(.vertical, 4)
                relationshipSection
            }
        }
    }

    // MARK: - Relationship Dynamics Section (CA-8)

    @ViewBuilder
    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "personAnalytics.relationship.heading",
                        defaultValue: "Relationship Dynamics"))
                .font(.headline)
                .padding(.horizontal)

            Text(String(localized: "personAnalytics.relationship.subtitle",
                        defaultValue: "How often \(selectedPeople[0].canonicalName) and \(selectedPeople[1].canonicalName) are mentioned together over time."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if isLoadingRelationship {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if relationshipPoints.isEmpty {
                ContentUnavailableView(
                    String(localized: "personAnalytics.relationship.empty.title", defaultValue: "No Shared Documents"),
                    systemImage: "person.2.slash",
                    description: Text(String(
                        localized: "personAnalytics.relationship.empty.detail",
                        defaultValue: "These two people are never co-mentioned in a dated document within this year range."))
                )
            } else {
                relationshipChart
                Text(String(localized: "personAnalytics.relationship.caption",
                            defaultValue: "Co-occurrences in dated documents only; documents mentioning both people. Undated documents cannot be placed on the year axis."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private var relationshipChart: some View {
        Chart(relationshipPoints) { point in
            BarMark(
                x: .value(String(localized: "personAnalytics.axis.year", defaultValue: "Year"), point.year),
                y: .value(String(localized: "personAnalytics.axis.coMentions", defaultValue: "Shared documents"),
                          point.coMentions)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXScale(domain: yearRange.lowerBound...yearRange.upperBound)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let year = value.as(Int.self) {
                        Text(verbatim: String(year))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text(count, format: .number)
                    }
                }
            }
        }
        .frame(height: 220)
        .padding(.horizontal)
    }

    // MARK: - Network Content (CA-8)

    @ViewBuilder
    private var networkContent: some View {
        VStack(spacing: 0) {
            networkFocusBar
            Divider()
            if let store = appState.personMentionStore, let focus = effectiveNetworkFocus {
                PersonCoMentionGraphView(
                    focusRollupId: focus.rollupId,
                    focusName: focus.canonicalName,
                    store: store,
                    volumeIds: scopeVolumeIds,
                    onOpenPerson: { rollupId, name in
                        openPersonMentions(PersonMentionRanking(
                            rollupId: rollupId, canonicalName: name, mentionCount: 0))
                    }
                )
                .id(focus.rollupId)
            } else {
                ContentUnavailableView(
                    String(localized: "personAnalytics.network.noFocus.title", defaultValue: "Pick a Focus Person"),
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(String(
                        localized: "personAnalytics.network.noFocus.detail",
                        defaultValue: "Search for a person above to centre the co-mention network on them. No people are indexed in this range yet."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var networkFocusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(String(localized: "personAnalytics.network.focusLabel", defaultValue: "Focus:"))
                    .font(.subheadline.weight(.semibold))
                if let focus = effectiveNetworkFocus {
                    Text(focus.canonicalName).font(.subheadline)
                } else {
                    Text(String(localized: "personAnalytics.network.focusNone", defaultValue: "None"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(
                    String(localized: "personAnalytics.network.searchPlaceholder", defaultValue: "Set focus person…"),
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, _ in Task { await runPersonSearch() } }
            }
            .padding(.horizontal)

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults.prefix(6)) { result in
                        Button {
                            networkFocus = result
                            searchText = ""
                            searchResults = []
                        } label: {
                            HStack {
                                Text(result.canonicalName).font(.body)
                                Spacer()
                                Text(result.mentionCount, format: .number)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 5)
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(.quaternary.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
    }

    private var searchToAddField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(
                    String(localized: "personAnalytics.search.placeholder", defaultValue: "Add a person to compare…"),
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)
                .disabled(atComparisonCap)
                .onChange(of: searchText) { _, _ in Task { await runPersonSearch() } }
            }
            .padding(.horizontal)

            if atComparisonCap {
                Text(String(localized: "personAnalytics.search.cap",
                            defaultValue: "Comparison is limited to \(Self.maxComparisonPeople) people. Remove one to add another."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults.prefix(6)) { result in
                        Button {
                            addToComparison(result)
                            searchText = ""
                            searchResults = []
                        } label: {
                            HStack {
                                Text(result.canonicalName).font(.body)
                                Spacer()
                                Text(result.mentionCount, format: .number)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 5)
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSelected(result))
                        Divider()
                    }
                }
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var selectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedPeople) { person in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color(forRollupId: person.rollupId))
                            .frame(width: 9, height: 9)
                        Button {
                            openPersonMentions(person)
                        } label: {
                            Text(person.canonicalName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        Button {
                            removeFromComparison(person)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            localized: "personAnalytics.chip.remove.a11y",
                            defaultValue: "Remove \(person.canonicalName) from comparison"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.quaternary.opacity(0.4)))
                }
            }
            .padding(.horizontal)
        }
    }

    private var trajectoryChart: some View {
        Chart(trajectoryPoints) { point in
            LineMark(
                x: .value(String(localized: "personAnalytics.axis.year", defaultValue: "Year"), point.year),
                y: .value(isNormalized
                          ? String(localized: "personAnalytics.axis.share", defaultValue: "% of documents")
                          : String(localized: "personAnalytics.axis.mentions", defaultValue: "Mentions"),
                          point.value)
            )
            .foregroundStyle(by: .value(
                String(localized: "personAnalytics.axis.person", defaultValue: "Person"), point.name))
            .symbol(by: .value(
                String(localized: "personAnalytics.axis.person", defaultValue: "Person"), point.name))
        }
        // Key the color scale explicitly by person name (the `.foregroundStyle(by:)`
        // series value) so each rendered line matches its chip color regardless of the
        // order people were added. Supplying only `range:` would map the palette
        // positionally onto Swift Charts' inferred (rollupId-sorted) domain, which
        // disagrees with the selection-order chip colors — mirror ChronologyView's
        // domain+range pairing instead.
        .chartForegroundStyleScale(
            domain: selectedPeople.map(\.canonicalName),
            range: selectedPeople.map { color(forRollupId: $0.rollupId) }
        )
        .chartXScale(domain: yearRange.lowerBound...yearRange.upperBound)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let year = value.as(Int.self) {
                        Text(verbatim: String(year))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if isNormalized, let share = value.as(Double.self) {
                        Text(share, format: .percent.precision(.fractionLength(0...1)))
                    } else if let count = value.as(Int.self) {
                        Text(count, format: .number)
                    }
                }
            }
        }
        .frame(height: 300)
        .padding(.horizontal)
    }

    private var trajectoryCaption: some View {
        Text(String(localized: "personAnalytics.comparison.caption",
                    defaultValue: "Counts mentions in dated documents only; mentions in undated documents cannot be placed on the year axis."))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker(
                String(localized: "personAnalytics.mode.picker", defaultValue: "Mode"),
                selection: $mode
            ) {
                ForEach(PersonAnalyticsMode.allCases, id: \.self) { m in
                    Text(m.pickerLabel).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .help(String(localized: "personAnalytics.mode.help",
                         defaultValue: "Switch between the trends dashboard (rankings, trajectories, relationship dynamics) and the co-mention network graph."))
        }
        if isCompactWidth {
            // iPhone: keep the primary Trends/Network mode picker inline and fold the
            // trends-only refinements (display, by-decade, values) into one "Options" menu
            // so the nav bar doesn't cram them. They don't apply in Network mode, so the
            // menu is omitted there entirely (#188-A).
            if mode == .trends {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        compactTrendsOptionsMenu
                    } label: {
                        Label(String(localized: "personAnalytics.options.menu", defaultValue: "Options"),
                              systemImage: "ellipsis.circle")
                    }
                }
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: ranking.isEmpty || mode == .network)
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $byDecade) {
                    Text(String(localized: "personAnalytics.decade.toggle", defaultValue: "By decade"))
                }
                .toggleStyle(.button)
                .help(String(localized: "personAnalytics.decade.help",
                             defaultValue: "Bucket the trajectory chart by decade instead of by year"))
            }
            ToolbarItem(placement: .primaryAction) {
                Picker(
                    String(localized: "personAnalytics.normalize.picker", defaultValue: "Values"),
                    selection: $normalization
                ) {
                    ForEach(PersonTrajectoryNormalization.allCases, id: \.self) { mode in
                        Text(mode.pickerLabel).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(selectedPeople.isEmpty)
                .help(String(localized: "personAnalytics.normalize.help",
                             defaultValue: "Plot raw mention counts, or each person's share of all dated documents in that period — so a growing corpus doesn't masquerade as a rising person."))
            }
        }
    }

    /// The trends-mode refinements (display mode, by-decade bucketing, value normalization),
    /// folded into the toolbar's "Options" menu on compact (iPhone) width. On regular width
    /// these render as separate toolbar items instead (see `toolbarContent`) (#188-A).
    @ViewBuilder
    private var compactTrendsOptionsMenu: some View {
        Picker(selection: $viewMode) {
            Label(String(localized: "analytics.viewMode.chart.a11y", defaultValue: "Chart"),
                  systemImage: "chart.bar").tag(AnalyticsViewMode.chart)
            Label(String(localized: "analytics.viewMode.table.a11y", defaultValue: "Table"),
                  systemImage: "list.bullet").tag(AnalyticsViewMode.table)
        } label: {
            Text(String(localized: "analytics.viewMode.picker", defaultValue: "Display"))
        }
        .disabled(ranking.isEmpty)

        Divider()

        Toggle(isOn: $byDecade) {
            Text(String(localized: "personAnalytics.decade.toggle", defaultValue: "By decade"))
        }
        Picker(selection: $normalization) {
            ForEach(PersonTrajectoryNormalization.allCases, id: \.self) { mode in
                Text(mode.pickerLabel).tag(mode)
            }
        } label: {
            Text(String(localized: "personAnalytics.normalize.picker", defaultValue: "Values"))
        }
        .disabled(selectedPeople.isEmpty)
    }

    // MARK: - Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "personAnalytics.unavailable.title", defaultValue: "Person Analytics Unavailable"),
            systemImage: "person.2.slash",
            description: Text(String(
                localized: "personAnalytics.unavailable.detail",
                defaultValue: "The search index is not available. Index at least one volume to enable person analytics."))
        )
    }

    // MARK: - Actions

    private func seedDefaultYearRange() {
        guard !didSeedYearRange else { return }
        didSeedYearRange = true
        yearRangeEnd = corpusMaxYear
    }

    private func isSelected(_ row: PersonMentionRanking) -> Bool {
        selectedPeople.contains { $0.rollupId == row.rollupId }
    }

    private func toggleSelection(_ row: PersonMentionRanking) {
        if isSelected(row) {
            removeFromComparison(row)
        } else {
            addToComparison(row)
        }
    }

    private func addToComparison(_ row: PersonMentionRanking) {
        guard !isSelected(row), selectedPeople.count < Self.maxComparisonPeople else { return }
        selectedPeople.append(row)
        Task { await loadTrajectories() }
        Task { await loadRelationship() }
    }

    private func removeFromComparison(_ row: PersonMentionRanking) {
        selectedPeople.removeAll { $0.rollupId == row.rollupId }
        rawTrajectories[row.rollupId] = nil
        mentioningDocs[row.rollupId] = nil
        // No trajectory re-fetch needed on removal — the remaining series stay cached.
        Task { await loadRelationship() }
    }

    /// Person tap → open the person's mentions in Search (the established person
    /// deep-link, reused from the People browser's "Find all mentions" action).
    private func openPersonMentions(_ person: PersonMentionRanking) {
        appState.pendingSearch = SearchParameters(personRollupId: person.rollupId,
                                                  personLabel: person.canonicalName)
        #if os(iOS)
        appState.activeTab = .search
        #endif
        #if DEBUG
        print("[PersonAnalyticsView] Open mentions for rollup \(person.rollupId) (\(person.canonicalName))")
        #endif
    }

    @ViewBuilder
    private func findMentionsButton(_ row: PersonMentionRanking) -> some View {
        Button {
            openPersonMentions(row)
        } label: {
            Label(String(localized: "personAnalytics.row.findMentions", defaultValue: "Find all mentions"),
                  systemImage: "magnifyingglass")
        }
    }

    // MARK: - Data Loading

    private func loadRanking() async {
        guard let store = appState.personMentionStore else { return }
        isLoadingRanking = true
        let range = yearRange
        ranking = (try? await store.topPeopleByMentions(inYearRange: range, limit: Self.rankingLimit, volumeIds: scopeVolumeIds)) ?? []
        isLoadingRanking = false
    }

    private func runPersonSearch() async {
        guard let store = appState.personMentionStore else { return }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; return }
        searchResults = (try? await store.rollupsMatchingName(q, limit: 20)) ?? []
    }

    private func loadTrajectories() async {
        guard let store = appState.personMentionStore, !selectedPeople.isEmpty else { return }
        let ids = selectedPeople.map(\.rollupId)
        trajectoryFetchToken += 1
        let token = trajectoryFetchToken
        isLoadingTrajectories = true
        async let raw = store.mentionTrajectories(rollupIds: ids, volumeIds: scopeVolumeIds)
        async let docs = store.mentioningDocumentTrajectories(rollupIds: ids, volumeIds: scopeVolumeIds)
        async let totals = store.datedDocumentTotalsByYear(volumeIds: scopeVolumeIds)
        let rawResult = (try? await raw) ?? [:]
        let docsResult = (try? await docs) ?? [:]
        let totalsResult = (try? await totals) ?? [:]
        // Only the latest-issued fetch may write back: a fast double-add enqueues two
        // tasks with different captured selections, and without this guard whichever
        // resumes last (not guaranteed to be the fuller one) would win (finding CA-5-2).
        guard token == trajectoryFetchToken else { return }
        rawTrajectories = rawResult
        mentioningDocs = docsResult
        datedTotals = totalsResult
        isLoadingTrajectories = false
    }

    /// Loads the two-person co-mention timeline when EXACTLY two people are selected (CA-8).
    /// Clears it otherwise, so the relationship section is only offered for a pair. A
    /// latest-fetch token guards against a fast add/remove race writing stale data back.
    private func loadRelationship() async {
        guard let store = appState.personMentionStore, selectedPeople.count == 2 else {
            relationshipTimeline = [:]
            return
        }
        let a = selectedPeople[0].rollupId
        let b = selectedPeople[1].rollupId
        relationshipFetchToken += 1
        let token = relationshipFetchToken
        isLoadingRelationship = true
        let timeline = (try? await store.coMentionTimeline(rollupA: a, rollupB: b, volumeIds: scopeVolumeIds)) ?? [:]
        guard token == relationshipFetchToken else { return }
        relationshipTimeline = timeline
        isLoadingRelationship = false
    }
}
