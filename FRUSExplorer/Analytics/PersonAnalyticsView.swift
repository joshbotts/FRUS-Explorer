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

    /// The source years a plotted trajectory period aggregates.
    ///
    /// In **By Decade** mode `bucketByDecade` keys a point by the decade's start, while the raw
    /// per-person dictionaries stay keyed by single year. An exporter that looks those up by the
    /// decade start alone prints the first year's numbers beside a whole-decade plotted value — a
    /// file whose own columns contradict each other. The span is clipped to `range`, because the
    /// plotted point was built from in-range years only, so an edge decade must not pick up years
    /// the chart never counted.
    ///
    /// - Parameters:
    ///   - period: The plotted point's period key (a year, or a decade's start year).
    ///   - byDecade: Whether the chart is bucketing by decade.
    ///   - range: The chart's year range.
    /// - Returns: Every source year that period aggregates, ascending.
    static func sourceYears(forPeriod period: Int, byDecade: Bool, range: ClosedRange<Int>) -> [Int] {
        guard byDecade else { return [period] }
        let lower = max(period, range.lowerBound)
        let upper = min(period + 9, range.upperBound)
        guard lower <= upper else { return [period] }
        return Array(lower...upper)
    }

    /// Buckets year-keyed points into decades (year floored to the nearest ten), summing
    /// raw values and averaging shares. Used by the decade toggle. `isShare` selects the
    /// aggregation: raw counts sum, document shares are averaged across the decade's years
    /// (a share can't be summed without exceeding 100%).
    ///
    /// One property of the share path is load-bearing for anything that describes this number:
    /// the divisor is the count of points that **reached** the bucket, and `sharePoints` emits a
    /// point only for years the person was actually mentioned in (the underlying query groups by
    /// year and returns no row for a zero-mention year). So a decade's share is the mean over the
    /// years with mentions, not over the decade's ten years — a person mentioned in one year of a
    /// decade plots that year's share for the whole decade.
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
// MARK: - PersonAnalyticsRequest

/// What keys a Person Analytics window (UI review F-11, CW-9d).
///
/// ## Why this type carries a mode when it could have been empty
/// Person Analytics takes no parameters — no deep-link hand-off, nothing a caller pre-sets — so
/// #906 offered two shapes: an empty marker (every value equal, therefore exactly one window), or
/// this one. The owner chose this one, and the reason is the comparison it makes possible: the
/// rankings dashboard and the co-mention ego network are two readings of the same evidence, and
/// on an iPad they can now sit side by side instead of taking turns behind a segmented control.
///
/// The mode is therefore **window identity**, not view state: `openWindow(value:)` focuses the
/// existing window for an equal request, so Trends and Network open as two windows while asking
/// for Trends twice focuses the one already showing it.
///
/// It is not a *freeze*, though — the picker inside a window still switches modes in place. A
/// reader who opens Trends and flips it to Network has one window showing Network; opening
/// Network from the menu then focuses the *other* window. That is the ordinary consequence of
/// keying a scene by a value the surface can also change, and it is preferable to disabling the
/// picker in windows, which would make the two hosts behave differently.
///
/// Version history:
///   1.0 — CW-9d: created for the mode-carrying window (owner decision, #906 option 2)
struct PersonAnalyticsRequest: Codable, Hashable, Sendable {

    /// Which half of the dashboard the window opens in.
    var mode: PersonAnalyticsMode

    /// Creates a request.
    /// - Parameter mode: The half to open. Defaults to the dashboard's own default.
    init(mode: PersonAnalyticsMode = .trends) {
        self.mode = mode
    }
}

// MARK: - PersonAnalyticsMode

enum PersonAnalyticsMode: String, CaseIterable, Codable, Hashable {
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
    /// Dismisses the iOS sheet from the toolbar's Done button. Unused on macOS, where this view
    /// is a window and the close button is the exit.
    @Environment(\.dismiss) private var dismiss
    /// This view's owning scene, so person-mention deep-links target the originating window (#338).
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    /// Opens the Search window directly for the person-mentions deep-link (the
    /// MainWindowView relay is retired — provenance PR 2).
    @Environment(\.openWindow) private var openWindow
    #endif

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
    ///
    /// Seeded from `initialMode` so a window can open straight into either one (CW-9d). The
    /// picker still switches it in place afterwards: the mode keys which *window* the menu opens,
    /// it does not freeze the surface.
    @State private var mode: PersonAnalyticsMode

    /// The mode this view was opened with — `.trends` from the sheet and from the menu's default,
    /// or whichever the reader chose when opening a window.
    private let initialMode: PersonAnalyticsMode

    /// Creates the dashboard.
    ///
    /// - Parameter initialMode: Which half to open in. Defaults to `.trends`, so every existing
    ///   call site is unchanged.
    init(initialMode: PersonAnalyticsMode = .trends) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

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

    /// Per-chart expansion (#207), persisted so a user's focus choice sticks across visits.
    /// Distinct keys per screen so the analytics dashboards don't share collapse state.
    @AppStorage("frus.personAnalytics.rankingExpanded") private var rankingExpanded = true
    @AppStorage("frus.personAnalytics.trajectoriesExpanded") private var trajectoriesExpanded = true

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

    // MARK: - Research-grade export (D3)

    /// The written export awaiting an iOS share sheet; always `nil` on macOS (the save panel writes
    /// straight to the chosen destination).
    @State private var exportShareItem: AnalyticsExportFile?
    /// A human-readable export failure, surfaced in an alert.
    @State private var exportError: String?

    /// The methods statement for a Person Analytics export.
    ///
    /// Carries the caveat that distinguishes this view from Corpus Analytics: person mentions are
    /// counted over **dated documents only**, with no volume-start-year fallback, so a Person figure
    /// and a Corpus figure are drawn from different document populations and their absolute counts
    /// are not directly comparable.
    ///
    /// - Parameters:
    ///   - figureTitle: The chart's title.
    ///   - periodGrain: The period grain shown (`By Year` / `By Decade`), or `nil` for the ranking.
    ///   - valueMode: The value mode, or `nil` where normalization does not apply.
    /// - Returns: The provenance to stamp on the export.
    private func personProvenance(figureTitle: String,
                                  periodGrain: String?,
                                  valueMode: String?,
                                  extra: [String] = []) -> AnalyticsProvenance {
        AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: periodGrain ?? String(localized: "personAnalytics.export.axis.ranking",
                                             defaultValue: "Ranked by mentions"),
            scopeLabel: scopeLabel,
            indexedVolumeCount: appState.indexedVolumeIds.count,
            yearRange: yearRangeStart...yearRangeEnd,
            // Person mentions are counted over DATED documents only — no volume-start-year fallback.
            // `appliesDocumentDating` defaults to `true`, so every Person export has been carrying
            // `AnalyticsProvenance.datingCaveat`, which describes that fallback as applying here. The
            // very next caveat below then says it does not. A methods block that contradicts itself
            // one line later is worse than one that says nothing.
            appliesDocumentDating: false,
            valueMode: valueMode,
            extraCaveats: [
                String(localized: "personAnalytics.export.caveat.dated",
                       defaultValue: "Population: person mentions are counted in dated documents only. The Corpus Analytics charts fall back to the volume's start year for undated documents; these charts do not. Counts from the two views are therefore not directly comparable."),
                String(localized: "personAnalytics.export.caveat.identity",
                       defaultValue: "Identity: mentions are grouped by the app's person authority, so spelling variants and name forms for one individual merge into a single identity. The person id column is that grouped identity."),
            ] + extra
        )
    }

    /// The caveat a decade-grained **share** trajectory needs, and only that combination.
    ///
    /// A decade's plotted share is the mean of the yearly shares **for the years this person was
    /// mentioned in**. A year with no mentions produces no point at all (the store's query groups
    /// by year and emits no zero row), so it is dropped from the average rather than entered as a
    /// zero — while the file's `Dated documents in period` column sums every year of the decade.
    /// The gap is not a rounding difference: someone mentioned in one year of a decade plots that
    /// single year's share for the whole decade, which against even denominators is ten times the
    /// decade's own share. A reader dividing this file's columns must be told exactly that.
    private var decadeShareCaveat: [String] {
        guard byDecade, isNormalized else { return [] }
        return [String(localized: "personAnalytics.export.caveat.decadeShare",
                       defaultValue: "Decade shares: the share plotted for a decade is the average of the yearly shares for the years this person was mentioned. Years with no mentions are dropped from that average rather than counted as zero. The \"Dated documents in period\" column, by contrast, sums every year of the decade. So dividing this file's columns gives the decade's own share, which can be far lower than the plotted value. Someone mentioned in one year of a decade plots that single year's share for the whole decade. Use the columns for the decade's share and the plotted value for the average across the mentioned years. They answer different questions.")]
    }

    /// The period grain label for the trajectory/relationship charts.
    private var periodGrainLabel: String {
        byDecade
            ? String(localized: "analytics.axis.decade", defaultValue: "Decade")
            : String(localized: "analytics.axis.year", defaultValue: "Year")
    }

    /// Delivers one chart's provenance-stamped CSV.
    ///
    /// - Parameters:
    ///   - table: The chart's data table.
    ///   - provenance: The methods statement to stamp above it.
    private func deliver(_ table: ChartInspectorData, _ provenance: AnalyticsProvenance) {
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle) + ".csv"
        switch AnalyticsExportDelivery.deliver(text: table.provenancedCSV(provenance), filename: filename) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// Exports the most-mentioned-people ranking.
    private func exportRankingCSV() {
        let title = String(localized: "personAnalytics.ranking.heading", defaultValue: "Most-Mentioned People")
        deliver(rankingInspectorTable(title: title),
                personProvenance(figureTitle: title, periodGrain: nil, valueMode: nil))
    }

    /// Exports the mention-trajectory comparison, carrying both numerators and the denominator so the
    /// plotted share can be recomputed from the file.
    /// The per-person trajectory series exactly as the CSV exports them — plotted value
    /// included — shared with the render-time descriptor so the two cannot drift (#268).
    private func trajectoryExportSeries()
        -> [(rollupId: Int, name: String,
             points: [(period: Int, mentions: Int, mentioningDocs: Int?,
                       datedTotal: Int?, plotted: Double)])] {
        trajectorySeriesBody()
    }

    private func trajectorySeriesBody()
        -> [(rollupId: Int, name: String,
             points: [(period: Int, mentions: Int, mentioningDocs: Int?,
                       datedTotal: Int?, plotted: Double)])] {
        let plottedByPerson = Dictionary(grouping: trajectoryPoints, by: { $0.rollupId })
        return selectedPeople.map { person -> (rollupId: Int, name: String, points: [(period: Int, mentions: Int, mentioningDocs: Int?, datedTotal: Int?, plotted: Double)]) in
            let points = (plottedByPerson[person.rollupId] ?? []).sorted { $0.year < $1.year }.map { point in
                let years = PersonAnalyticsMath.sourceYears(
                    forPeriod: point.year, byDecade: byDecade, range: yearRange)
                let mentions = years.reduce(0) { $0 + (rawTrajectories[person.rollupId]?[$1] ?? 0) }
                // A document carries one date, so it falls in exactly one year — summing the
                // per-year distinct-document counts across a decade cannot double-count.
                let docs = years.compactMap { mentioningDocs[person.rollupId]?[$0] }
                let totals = years.compactMap { datedTotals[$0] }
                return (period: point.year,
                        mentions: mentions,
                        mentioningDocs: docs.isEmpty ? nil : docs.reduce(0, +),
                        datedTotal: totals.isEmpty ? nil : totals.reduce(0, +),
                        plotted: point.value)
            }
            return (rollupId: person.rollupId, name: person.canonicalName, points: points)
        }
    }

    private func exportTrajectoryCSV() {
        let title = String(localized: "personAnalytics.comparison.heading", defaultValue: "Mention Trajectories")
        let series = trajectoryExportSeries()
        deliver(trajectoryInspectorTable(title: title, series: series),
                personProvenance(figureTitle: title,
                                 periodGrain: periodGrainLabel,
                                 valueMode: normalization.pickerLabel,
                                 extra: decadeShareCaveat))
    }

    /// Renders one Person chart as a publication figure and shares (iOS) or saves (macOS).
    ///
    /// - Parameters:
    ///   - format: PNG or PDF.
    ///   - provenance: The methods statement printed on the plate.
    ///   - chartHeight: The plate's chart area height.
    ///   - chart: The chart, built from data already resolved on this side of the render boundary.
    private func deliverFigure<Content: View>(_ format: AnalyticsFigureFormat,
                                              provenance: AnalyticsProvenance,
                                              chartHeight: CGFloat,
                                              @ViewBuilder chart: @escaping () -> Content) {
        let canvas = AnalyticsFigureCanvas(provenance: provenance, chartHeight: chartHeight, content: chart)
        guard let data = AnalyticsFigureExporter.render(canvas, format: format) else {
            exportError = String(localized: "analytics.export.error.render",
                                 defaultValue: "The figure could not be rendered.")
            return
        }
        let filename = AnalyticsExportDelivery.filenameStem(title: provenance.figureTitle)
            + "." + format.pathExtension
        switch AnalyticsExportDelivery.deliver(data: data, filename: filename, contentType: format.contentType) {
        case .share(let item): exportShareItem = item
        case .saved, .cancelled: break
        case .failed(let reason): exportError = reason
        }
    }

    /// Exports the ranking as a figure — without the transient selection styling (see
    /// `rankingChartBody(showsSelection:)`).
    private func exportRankingFigure(_ format: AnalyticsFigureFormat) {
        let title = String(localized: "personAnalytics.ranking.heading", defaultValue: "Most-Mentioned People")
        deliverFigure(format,
                      provenance: personProvenance(figureTitle: title, periodGrain: nil, valueMode: nil),
                      chartHeight: max(240, CGFloat(ranking.count) * 26 + 40)) {
            rankingChartBody(showsSelection: false)
        }
    }

    /// Exports the mention-trajectory comparison as a figure.
    private func exportTrajectoryFigure(_ format: AnalyticsFigureFormat) {
        let title = String(localized: "personAnalytics.comparison.heading", defaultValue: "Mention Trajectories")
        deliverFigure(format,
                      provenance: personProvenance(figureTitle: title,
                                                   periodGrain: periodGrainLabel,
                                                   valueMode: normalization.pickerLabel),
                      chartHeight: 420) {
            trajectoryChart
        }
    }

    /// The trajectory's tabular form — one build shared by export and descriptor (#268).
    private func trajectoryInspectorTable(
        title: String,
        series: [(rollupId: Int, name: String,
                  points: [(period: Int, mentions: Int, mentioningDocs: Int?,
                            datedTotal: Int?, plotted: Double)])]
    ) -> ChartInspectorData {
        AnalyticsChartTables.personTrajectoryTable(
            title: title, periodColumn: periodGrainLabel, series: series,
            isNormalized: isNormalized)
    }

    /// Exports the two-person relationship series (only meaningful with exactly two people selected).
    private func exportRelationshipCSV() {
        guard isTwoPersonComparison else { return }
        let title = String(localized: "personAnalytics.relationship.heading", defaultValue: "Relationship Dynamics")
        let table = AnalyticsChartTables.personRelationshipTable(
            title: title,
            periodColumn: periodGrainLabel,
            personA: selectedPeople[0].canonicalName,
            personB: selectedPeople[1].canonicalName,
            points: relationshipPoints.map { (period: $0.year, coMentions: $0.coMentions) })
        deliver(table, personProvenance(figureTitle: title, periodGrain: periodGrainLabel, valueMode: nil))
    }

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
            // iOS omits the nav title so the full nav-bar width goes to the trailing controls
            // (#219); the accessible screen name is preserved via .accessibilityLabel. macOS keeps
            // the title for its window title bar.
            #if os(macOS)
            .navigationTitle(
                String(localized: "personAnalytics.title", defaultValue: "Person Analytics")
            )
            #else
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "personAnalytics.title", defaultValue: "Person Analytics"))
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 560)
        #endif
        // D3: anchored on the outermost view (not the inner `Group`, which would apply the
        // presentation per child — see the Group-modifier gotcha).
        .sheet(item: $exportShareItem) { item in
            AnalyticsExportShareSheet(item: item)
        }
        .alert(String(localized: "analytics.export.error.title", defaultValue: "Export Failed"),
               isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .task {
            seedDefaultYearRange()
            await loadRanking()
        }
        .onChange(of: yearRange) { _, _ in
            Task { await loadRanking() }
        }
        // Reload against the freshly reopened person store after a reindex settles (#275): the
        // boot-time read-only connection can be left stale by the rebuild, so a dashboard already
        // on screen would otherwise keep showing empty results until the app is relaunched.
        .onChange(of: appState.readOnlyStoresGeneration) { _, _ in
            reloadForScopeChange()
        }
        // A correction or a corpus change rebuilds `person_rollup` *without* reopening the store,
        // so `readOnlyStoresGeneration` never moves and this dashboard kept charting rollup ids
        // that had since been renumbered — every series silently re-attributed to a neighbour
        // (#747 / audit M-27). Reloading re-queries by the ids currently on screen; the focus and
        // comparison rows are rebuilt from that reload.
        .onChange(of: appState.personRollupGeneration) { _, _ in
            reloadForScopeChange()
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
                // Each chart is a collapsible section hosting its OWN controls (#207), so it's
                // unambiguous which chart a control affects and users can focus on one at a time.
                AnalyticsCollapsibleSection(
                    title: String(localized: "personAnalytics.ranking.heading",
                                  defaultValue: "Most-Mentioned People"),
                    isExpanded: $rankingExpanded,
                    controls: { rankingControls },
                    content: { rankingSection }
                )
                Divider()
                AnalyticsCollapsibleSection(
                    title: String(localized: "personAnalytics.comparison.heading",
                                  defaultValue: "Mention Trajectories"),
                    isExpanded: $trajectoriesExpanded,
                    controls: { comparisonControls },
                    content: { comparisonSection }
                )
            }
            .padding(.vertical, 8)
        }
    }

    /// Chart/table display toggle for the ranking — moved out of the shared toolbar into this
    /// chart's section (#207). Disabled when there are no people to rank.
    @ViewBuilder
    private var rankingControls: some View {
        HStack {
            AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: ranking.isEmpty)
            Spacer()
            // D3: per-section export — this view shows several charts, so a view-level control would
            // be ambiguous about which one it acts on (owner decision H).
            AnalyticsSectionExportControl(isEnabled: !ranking.isEmpty,
                                          exportCSV: exportRankingCSV,
                                          exportFigure: exportRankingFigure)
        }
        .padding(.horizontal)
    }

    /// "By decade" bucketing + value normalization for the trajectory (and nested relationship)
    /// charts — moved out of the shared toolbar into this chart's section (#207). Normalization is
    /// disabled until people are selected.
    @ViewBuilder
    private var comparisonControls: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $byDecade) {
                Text(String(localized: "personAnalytics.decade.toggle", defaultValue: "By decade"))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help(String(localized: "personAnalytics.decade.help",
                         defaultValue: "Bucket the trajectory chart by decade instead of by year"))
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
            Spacer()
            // D3: the trajectory export, plus the relationship series when exactly two people are
            // compared (that chart is nested in this section and appears only in that case).
            AnalyticsSectionExportControl(isEnabled: !selectedPeople.isEmpty,
                                          exportCSV: exportTrajectoryCSV,
                                          exportFigure: exportTrajectoryFigure)
            if isTwoPersonComparison {
                Button {
                    exportRelationshipCSV()
                } label: {
                    Label(String(localized: "personAnalytics.export.relationship",
                                 defaultValue: "Export relationship CSV"),
                          systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(String(localized: "personAnalytics.export.relationship.help",
                             defaultValue: "Export the two-person co-mention series with its method and caveats"))
            }
        }
        .padding(.horizontal)
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

    /// The ranking's tabular form — ONE build shared by the CSV export and the Audio Graph
    /// descriptor (#268), so the sonified series and the exported one cannot drift.
    private func rankingInspectorTable(title: String) -> ChartInspectorData {
        // Same id/suffix pairing the chart uses (`rankingChart`'s local `rowKey`), so the
        // "chart label" column matches the figure's y-axis text row for row.
        let labels = disambiguatedRankingLabels(
            ranking.map { (id: String($0.rollupId), name: $0.canonicalName, shortSuffix: String($0.rollupId)) })
        return AnalyticsChartTables.personRankingTable(
            title: title,
            rows: ranking.map { (rollupId: $0.rollupId,
                                 name: $0.canonicalName,
                                 axisLabel: labels[String($0.rollupId)] ?? $0.canonicalName,
                                 mentions: $0.mentionCount) })
    }

    private var rankingChart: some View {
        rankingChartBody(showsSelection: true)
            // #268: label = "Chart label" (the disambiguated axis text), value = "Mentions in
            // dated documents". The default (0, 1) reads (Rank, Person) — Rank parses, so it
            // would sonify rank positions as values without complaint.
            .axChartDescriptor(
                inspector: rankingInspectorTable(
                    title: String(localized: "personAnalytics.ranking.heading",
                                  defaultValue: "Most-Mentioned People")),
                title: String(localized: "personAnalytics.ranking.heading",
                              defaultValue: "Most-Mentioned People"),
                labelColumn: 2, valueColumn: 4)
            // Interaction belongs to the on-screen chart only; the exported figure omits it.
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotAnchor = proxy.plotFrame else { return }
                            let plotRect = geo[plotAnchor]
                            let relativeY = location.y - plotRect.origin.y
                            guard let id = proxy.value(atY: relativeY, as: String.self),
                                  let row = ranking.first(where: { String($0.rollupId) == id }) else { return }
                            toggleSelection(row)
                        }
                }
            }
            .frame(height: CGFloat(ranking.count) * 30 + 40)
            .padding(.horizontal)
    }

    /// The most-mentioned ranking chart, shared by the screen and the D3 figure export.
    ///
    /// - Parameter showsSelection: `true` on screen, where bars dim and carry a checkmark to mirror
    ///   the comparison set. The exported figure passes `false`: selection is transient UI, and a
    ///   published figure showing half its bars dimmed for a reason it never states would be
    ///   misleading.
    private func rankingChartBody(showsSelection: Bool) -> some View {
        // Key each bar on the rollup's UNIQUE id (as a string), never the canonical name: two
        // distinct rollups can share a canonical name (homonymous or not-yet-merged people), and
        // Swift Charts SUMS a `BarMark`'s x-values whenever rows share a categorical y — which would
        // silently merge distinct people into one oversized bar (#275 follow-up, mirroring the
        // cross-reference ranking fix). Ids are unique → one bar per person; an explicit domain
        // preserves the mention-descending order, and a lookup renders the (disambiguated) name.
        // This keying is kept verbatim in the export — re-keying on names for a published figure
        // would reintroduce the merged-bar bug into the artifact of record.
        let rowKey: (PersonMentionRanking) -> String = { String($0.rollupId) }
        let axisLabels = disambiguatedRankingLabels(
            ranking.map { (id: rowKey($0), name: $0.canonicalName, shortSuffix: String($0.rollupId)) }
        )
        return Chart(ranking) { row in
            BarMark(
                x: .value(String(localized: "personAnalytics.axis.mentions", defaultValue: "Mentions"),
                          row.mentionCount),
                y: .value(String(localized: "personAnalytics.axis.person", defaultValue: "Person"),
                          rowKey(row))
            )
            // The chart now matches the table's selection state (design Win 4): full accent when
            // nothing is selected (the default view stays crisp) or this row IS selected; dimmed only
            // when a DIFFERENT row is selected, so the comparison set stands out.
            .foregroundStyle((!showsSelection || selectedPeople.isEmpty || isSelected(row))
                             ? Color.accentColor : Color.accentColor.opacity(0.5))
            .annotation(position: .trailing) {
                HStack(spacing: 5) {
                    if showsSelection {
                        Image(systemName: isSelected(row) ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(isSelected(row) ? Color.accentColor : Color.secondary)
                    }
                    Text(row.mentionCount, format: .number)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(Text(axisLabels[rowKey(row)] ?? row.canonicalName))
            .accessibilityValue(Text(String(localized: "personAnalytics.axis.mentionsValue",
                                             defaultValue: "\(row.mentionCount) mentions")))
        }
        // Highest mention count at the top: `ranking` is sorted descending, and the first domain
        // element is placed at the top of a horizontal-bar categorical y-axis.
        .chartYScale(domain: ranking.map(rowKey))
        .chartYAxis {
            AxisMarks(preset: .aligned) { value in
                AxisValueLabel {
                    if let id = value.as(String.self) {
                        Text(axisLabels[id] ?? id)
                    }
                }
            }
        }
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
        // #268: the export's exact table (guarded by the same two-person condition the mount
        // sits inside). Columns: 2 = period, 3 = co-mention count.
        .axChartDescriptor(
            inspector: isTwoPersonComparison ? AnalyticsChartTables.personRelationshipTable(
                title: String(localized: "personAnalytics.relationship.heading",
                              defaultValue: "Relationship Dynamics"),
                periodColumn: periodGrainLabel,
                personA: selectedPeople[0].canonicalName,
                personB: selectedPeople[1].canonicalName,
                points: relationshipPoints.map { (period: $0.year, coMentions: $0.coMentions) }) : nil,
            title: String(localized: "personAnalytics.relationship.heading",
                          defaultValue: "Relationship Dynamics"),
            labelColumn: 2, valueColumn: 3)
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
                // Recreate the graph (re-running its load against the reopened store) when the
                // focus changes OR after a reindex settles — its own `.task` is keyed on
                // focus/scope, not the store, so a generation bump alone would otherwise leave it
                // showing the stale-connection empty state until relaunch (#275).
                .id("\(focus.rollupId)-\(appState.readOnlyStoresGeneration)")
            } else {
                ContentUnavailableView(
                    String(localized: "personAnalytics.network.noFocus.title", defaultValue: "Pick a Focus Person"),
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text(String(
                        localized: "personAnalytics.network.noFocus.detail",
                        defaultValue: "Search for a person above to center the co-mention network on them. No people are indexed in this range yet."))
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
                            .padding(.horizontal)
                            // Win 5: full-width, ≥44pt row so a tap anywhere across it (including the
                            // gap before the count) adds the person. contentShape must be OUTERMOST so
                            // the whole padded/44pt area is hittable, not just the text glyphs.
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
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
                    // Win 5: the name (open-mentions) and ✕ (remove) are SIBLING buttons — never wrap
                    // the whole chip in one gesture or the ✕ gets swallowed. Each control enlarges its
                    // OWN hit area to ≥44pt via a frame + contentShape; the chip settles at 44pt tall
                    // (the old .padding(.vertical, 5) is dropped so it doesn't overshoot).
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
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            removeFromComparison(person)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            localized: "personAnalytics.chip.remove.a11y",
                            defaultValue: "Remove \(person.canonicalName) from comparison"))
                    }
                    .padding(.leading, 10)
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
        // #268: THE chart the refusal cannot protect — the table interleaves every person's
        // rows and all its cells parse, so fed whole it would sonify one zig-zag crossing
        // every person. Split by Person (0); label = period (2); value = Plotted (6), which
        // matches raw-vs-normalized exactly.
        .axChartDescriptor(
            inspector: trajectoryInspectorTable(
                title: String(localized: "personAnalytics.comparison.heading",
                              defaultValue: "Mention Trajectories"),
                series: trajectoryExportSeries()),
            title: String(localized: "personAnalytics.comparison.heading",
                          defaultValue: "Mention Trajectories"),
            labelColumn: 2, valueColumn: 6, splitBySeriesColumn: 0)
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
        // Only the global Trends/Network mode picker lives in the toolbar now; each chart's own
        // controls (display, by-decade, values) moved into its collapsible section (#207), so it's
        // clear which chart each control affects and the compact-width "Options" fold is gone.
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
        // Win 7: the shared feature-info affordance, matching Corpus and Cross-Reference Analytics.
        ToolbarItem(placement: .primaryAction) {
            FeatureInfoButton.personAnalytics
        }
        // Done button — iOS sheet only; macOS windows use the close button. Matching Corpus
        // Analytics, Archival Analytics, Chronology and the word cloud, all of which have had one
        // since they shipped. Without it this sheet's only exit is the swipe-down, which is
        // undiscoverable and unavailable to a switch-control or VoiceOver reader.
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "personAnalytics.done", defaultValue: "Done")) {
                dismiss()
            }
        }
        #endif
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
    /// macOS opens the window directly, binding it to this analytics window's provenance.
    private func openPersonMentions(_ person: PersonMentionRanking) {
        appState.openSearch(SearchParameters(personRollupId: person.rollupId,
                                             personLabel: person.canonicalName), from: sceneID)
        #if os(macOS)
        appState.bindTool(.search, to: appState.provenance(of: .personAnalytics))
        openWindow.fronting(id: "frus.search")
        #else
        appState.openTab(.search, from: sceneID)
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
