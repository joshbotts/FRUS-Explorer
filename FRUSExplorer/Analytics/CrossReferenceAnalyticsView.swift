// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - Row models

/// One most-referenced document row: its node, inbound citation count, and header.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
private struct InDegreeRow: Identifiable, Equatable {
    let volumeId: String
    let documentId: String
    let inDegree: Int
    let header: String?
    /// Whether the target is indexed locally (present in `document_cache`), independent of whether
    /// it has a `<head>` — editorial notes are indexed but headerless (#278).
    let isIndexed: Bool

    var id: String { "\(volumeId)/\(documentId)" }

    /// Display label — the header if indexed, else the volume/document key.
    var displayLabel: String { header ?? "\(volumeId) · \(documentId)" }
}

/// One PageRank landmark row: its node, score, and header.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
private struct LandmarkRow: Identifiable, Equatable {
    let volumeId: String
    let documentId: String
    let score: Double
    let header: String?
    /// Whether the target is indexed locally (present in `document_cache`), independent of whether
    /// it has a `<head>` — editorial notes are indexed but headerless (#278).
    let isIndexed: Bool

    var id: String { "\(volumeId)/\(documentId)" }

    var displayLabel: String { header ?? "\(volumeId) · \(documentId)" }
}

/// One cell of the volume heat matrix: source volume, target volume, ref count.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
private struct HeatCell: Identifiable, Equatable {
    let sourceVolumeId: String
    let targetVolumeId: String
    let count: Int

    var id: String { "\(sourceVolumeId)->\(targetVolumeId)" }
}

// MARK: - CrossReferenceAnalyticsView

/// Corpus cross-reference analytics (CA-6): the citation network as a statistical object,
/// over the local SQLite index.
///
/// ## What it shows
/// - **Most-referenced documents** — the top-N documents by inbound citation count
///   (in-degree), as a ranked bar chart or table, each tappable to open the document.
/// - **Degree distribution** — a histogram of in-degree (with an optional out-degree
///   overlay), showing the network's skew: a few heavily-cited documents and a long tail.
/// - **Volume heat matrix** — the top-N most-connected volumes as an N×N grid whose cells
///   are shaded by cross-volume reference count.
/// - **Landmark documents (PageRank)** — the top-N documents by an offline PageRank
///   *influence* score, each tappable.
///
/// ## Same-volume attribution
/// The `cross_references` table stores a NULL `target_volume_id` for a **same-volume** reference
/// (a bare `#…` TEI fragment, including the page references resolved at index time). The three
/// document-level sections (most-referenced, degree distribution, PageRank) attribute those to
/// the source's own volume via `COALESCE(target_volume_id, source_volume_id)`, so within-volume
/// citations count. The **volume heat matrix** is inherently cross-volume — it plots connections
/// *between* volumes — so it continues to exclude same-volume edges.
///
/// ## Scope & era slicing (#189-B)
/// A year-range bar and a subseries/volume scope picker restrict the analysis so
/// project-specific citation structure emerges from behind the corpus-wide totals. The four
/// document-level figures are **source-anchored**: they count citations *made by* documents in
/// the selected era/scope (a heavily-cited foundational document outside the slice still ranks).
/// The volume heat matrix keeps its both-endpoints volume filter. The default full-corpus span +
/// no scope analyzes the whole graph, exactly as before.
///
/// ## No-index degradation
/// When `appState.crossReferenceStore` is `nil` (index unavailable), a `ContentUnavailableView`
/// placeholder is shown instead — mirroring how `AnalyticsView` handles a `nil`
/// `analyticsService` and `PersonAnalyticsView` a `nil` `personMentionStore`.
///
/// ## Platform placement
/// - **macOS**: standalone `frus.crossRefAnalytics` Window.
/// - **iOS**: sheet presented from the Browse "Analysis Tools" menu.
///
/// Version history:
///   1.0 — CA-6 (analytics CA-track): initial implementation
///   1.1 — Session 3 / #236: administration preset menu beneath the year-range bar
///          (one tap sets the document-year range to a president's term, bounded
///          and clamped to the corpus span)
///   1.2 — Session 7 / #240B: broken-reference disclosure — `excludedBrokenCount`
///          fetched per scope and appended to the resolved caption when non-zero
///   1.3 — #275 follow-up: (a) the most-referenced-documents bar chart keys each bar on the
///          document's unique id, not its title — distinct documents sharing a generic FRUS
///          title (e.g. "Department of State Minutes") were being summed into one oversized
///          bar by Swift Charts' categorical aggregation; (b) reloads on
///          `readOnlyStoresGeneration` so a dashboard on screen when a reindex finishes
///          refreshes against the reopened store instead of showing stale-connection emptiness
struct CrossReferenceAnalyticsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// #338 step 4: the scene this view renders in on iOS (the Browse-tab sheet), so its document /
    /// volume open hand-offs address the presenting window. Injected at the sheet site; nil on macOS.
    @Environment(\.sceneID) private var sceneID
    #if os(macOS)
    /// Mint tail for `AppState.openDocument` — when no document host is live, a document
    /// tap lands in a fresh standalone document window instead of being dropped.
    @Environment(\.openWindow) private var openWindow
    #endif

    // MARK: - Tunables

    /// Top-N size for the in-degree ranking.
    private static let rankingLimit = 15
    /// Top-N size for the PageRank landmark list.
    private static let landmarkLimit = 15
    /// N for the N×N volume heat matrix (readable bound; disclosed in-UI).
    private static let matrixVolumeLimit = 15

    // MARK: - State

    @State private var ranking: [InDegreeRow] = []
    @State private var distribution: [DegreeBucket] = []
    @State private var outDistribution: [DegreeBucket] = []
    @State private var matrixVolumes: [String] = []
    @State private var matrixCells: [HeatCell] = []
    @State private var matrixMaxCount: Int = 0
    @State private var landmarks: [LandmarkRow] = []
    /// Count of unresolvable references excluded from the current scope (#240B); drives the footnote.
    @State private var excludedBrokenCount: Int = 0

    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var showOutDegree = false
    @State private var isLoading = false
    @State private var didLoad = false

    /// Per-chart expansion (#209), persisted so a user's focus choice sticks. Distinct keys so the
    /// analytics dashboards don't share collapse state.
    @AppStorage("frus.crossRefAnalytics.rankingExpanded") private var rankingExpanded = true
    @AppStorage("frus.crossRefAnalytics.distributionExpanded") private var distributionExpanded = true
    @AppStorage("frus.crossRefAnalytics.matrixExpanded") private var matrixExpanded = true
    @AppStorage("frus.crossRefAnalytics.landmarkExpanded") private var landmarkExpanded = true

    /// Year-range filter (#189-B). Seeded to the corpus span on first appear; when the user
    /// narrows it, every CA-6 query is restricted to citations whose SOURCE document is dated in
    /// range (source-anchored). A whole-corpus span emits no date SQL (unfiltered = unchanged).
    @State private var yearRangeStart: Int = 1861
    @State private var yearRangeEnd: Int = Calendar.current.component(.year, from: Date())
    @State private var didSeedYearRange = false
    /// Volume scope (#189-B). `nil` = whole corpus. Source-anchored for the four document-level
    /// figures; both-endpoints for the volume heat matrix (its shipped contract).
    @State private var scopeVolumeIds: [String]? = nil
    @State private var scopeLabel: String? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.crossReferenceStore == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        scopeBar
                        Divider()
                        yearRangeBar
                        Divider()
                        content
                    }
                }
            }
            // iOS omits the nav title so the full nav-bar width goes to the trailing controls —
            // this is the worst-crowding view (longest title, no compact fold) (#219). The
            // accessible screen name is preserved via .accessibilityLabel. macOS keeps the title
            // for its window title bar.
            #if os(macOS)
            .navigationTitle(
                String(localized: "crossRefAnalytics.title", defaultValue: "Cross-Reference Analytics")
            )
            #else
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "crossRefAnalytics.title", defaultValue: "Cross-Reference Analytics"))
            #endif
            // The chart/table picker and out-degree toggle moved into their own collapsible sections
            // (#209). Win 7 restores a single toolbar affordance: the shared feature-info button,
            // matching Corpus and Person Analytics.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FeatureInfoButton.crossReferenceAnalytics
                }
            }
        }
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
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 600)
        #endif
        .task {
            seedDefaultYearRange()
            guard !didLoad else { return }
            didLoad = true
            await loadAll()
        }
        .onChange(of: yearRange) { _, _ in
            Task { await loadAll() }
        }
        // Reload against the freshly reopened store after a reindex settles (#275): the boot-time
        // read-only connection this view read through can be left stale by the rebuild, so a
        // dashboard already on screen would otherwise keep showing "No Data" until relaunch.
        .onChange(of: appState.readOnlyStoresGeneration) { _, _ in
            Task { await loadAll() }
        }
    }

    // MARK: - Filters (#189-B)

    /// Most recent corpus year — the year-range upper bound and reset target (mirrors
    /// `AnalyticsView`/`PersonAnalyticsView`).
    private var corpusMaxYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: appState.manifestStore.corpusDateRange.upperBound)
    }

    /// The active year range, normalised so start ≤ end.
    private var yearRange: ClosedRange<Int> {
        let lo = min(yearRangeStart, yearRangeEnd)
        let hi = max(yearRangeStart, yearRangeEnd)
        return lo...hi
    }

    /// `true` once the user has narrowed the range away from the full-corpus default.
    private var yearRangeIsCustom: Bool {
        yearRangeStart != 1861 || yearRangeEnd != corpusMaxYear
    }

    /// The year range to pass to the store, or `nil` when the range is the full-corpus default
    /// (so the store emits no date SQL and whole-corpus output is byte-for-byte unchanged).
    private var effectiveYearRange: ClosedRange<Int>? {
        yearRangeIsCustom ? yearRange : nil
    }

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    /// Seeds `yearRangeEnd` to the corpus span once, on first appearance.
    private func seedDefaultYearRange() {
        guard !didSeedYearRange else { return }
        didSeedYearRange = true
        yearRangeEnd = corpusMaxYear
    }

    /// Re-runs every CA-6 query after the scope changes.
    private func reloadForFilterChange() {
        Task { await loadAll() }
    }

    private var scopeBar: some View {
        AnalyticsScopeBar(
            indexedVolumeIds: appState.indexedVolumeIds,
            volumeTitle: volumeTitle,
            scopeVolumeIds: $scopeVolumeIds,
            scopeLabel: $scopeLabel,
            onChange: reloadForFilterChange
        )
    }

    private var yearRangeBar: some View {
        VStack(spacing: 2) {
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
            // Administration presets (#236): one tap sets the document-year range to a
            // president's term — this view's year filter is the document's coverage year.
            let administrations = appState.administrationProfilesStore.index?.administrations ?? []
            if !administrations.isEmpty {
                HStack {
                    AdministrationPresetMenu(
                        administrations: administrations,
                        corpusMaxYear: corpusMaxYear,
                        yearStart: $yearRangeStart,
                        yearEnd: $yearRangeEnd
                    )
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                resolvedCaption
                Divider()
                // Each chart is a collapsible section hosting its OWN controls (#209): the
                // chart/table picker lives with Most-Referenced, the out-degree overlay with the
                // degree distribution — so it's clear which chart a control affects.
                AnalyticsCollapsibleSection(
                    title: String(localized: "crossRefAnalytics.ranking.heading",
                                  defaultValue: "Most-Referenced Documents"),
                    isExpanded: $rankingExpanded,
                    controls: { rankingControls },
                    content: { rankingSection }
                )
                Divider()
                AnalyticsCollapsibleSection(
                    title: String(localized: "crossRefAnalytics.distribution.heading",
                                  defaultValue: "Citation Degree Distribution"),
                    isExpanded: $distributionExpanded,
                    controls: { distributionControls },
                    content: { distributionSection }
                )
                Divider()
                // D3: these two switch from the EmptyView convenience init to the `controls:`
                // variant so each can host its own export button (never in the collapsible header,
                // which is itself a Button).
                AnalyticsCollapsibleSection(
                    title: String(localized: "crossRefAnalytics.matrix.heading",
                                  defaultValue: "Volume Citation Heat Matrix"),
                    isExpanded: $matrixExpanded,
                    controls: {
                        HStack {
                            Spacer()
                            AnalyticsSectionExportControl(isEnabled: !matrixCells.isEmpty,
                                                          exportCSV: exportMatrixCSV)
                        }
                        .padding(.horizontal)
                    },
                    content: { matrixSection }
                )
                Divider()
                AnalyticsCollapsibleSection(
                    title: String(localized: "crossRefAnalytics.landmarks.heading",
                                  defaultValue: "Landmark Documents (Influence)"),
                    isExpanded: $landmarkExpanded,
                    controls: {
                        HStack {
                            Spacer()
                            AnalyticsSectionExportControl(isEnabled: !landmarks.isEmpty,
                                                          exportCSV: exportLandmarkCSV)
                        }
                        .padding(.horizontal)
                    },
                    content: { landmarkSection }
                )
            }
            .padding(.vertical, 8)
        }
    }

    /// Chart/table display toggle for the Most-Referenced ranking — moved out of the shared
    /// toolbar into this chart's section (#209). Disabled when there's nothing ranked.
    @ViewBuilder
    private var rankingControls: some View {
        HStack {
            AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: ranking.isEmpty)
            Spacer()
            // D3: per-section export — this view shows four artifacts, so a view-level control would
            // be ambiguous about which one it acts on (owner decision H).
            AnalyticsSectionExportControl(isEnabled: !ranking.isEmpty,
                                          exportCSV: exportRankingCSV,
                                          exportFigure: exportRankingFigure)
        }
        .padding(.horizontal)
    }

    // MARK: - Research-grade export (D3)

    /// The written export awaiting an iOS share sheet; always `nil` on macOS.
    @State private var exportShareItem: AnalyticsExportFile?
    /// A human-readable export failure, surfaced in an alert.
    @State private var exportError: String?

    /// The methods statement for a Cross-Reference Analytics export.
    ///
    /// Always discloses the unresolvable-reference exclusion — on screen that caption appears only
    /// when the count is non-zero, but "none were excluded" is itself a fact a reader needs.
    ///
    /// - Parameters:
    ///   - figureTitle: The chart's title.
    ///   - axisLabel: What the chart is ranked/grouped by.
    ///   - extra: Any further chart-specific caveats.
    /// - Returns: The provenance to stamp on the export.
    private func crossRefProvenance(figureTitle: String,
                                    axisLabel: String,
                                    extra: [String] = []) -> AnalyticsProvenance {
        let excluded = String(
            format: String(localized: "crossRefAnalytics.export.caveat.excluded %lld",
                           defaultValue: "Unresolvable references: %lld cross-reference(s) are excluded from this analysis — references in the printed volumes that point to a document, page, or volume not present in this corpus."),
            Int64(excludedBrokenCount))
        let sameVolume = String(
            localized: "crossRefAnalytics.export.caveat.sameVolume",
            defaultValue: "Attribution: the document-level figures attribute same-volume references (including resolved page references) to the document's own volume. The volume heat matrix is inherently cross-volume and excludes same-volume citations.")
        return AnalyticsProvenance(
            figureTitle: figureTitle,
            axisLabel: axisLabel,
            scopeLabel: scopeLabel,
            indexedVolumeCount: appState.indexedVolumeIds.count,
            yearRange: yearRangeStart...yearRangeEnd,
            valueMode: nil,
            extraCaveats: [excluded, sameVolume] + extra
        )
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

    /// Exports the most-referenced-documents ranking.
    private func exportRankingCSV() {
        let title = String(localized: "crossRefAnalytics.ranking.heading", defaultValue: "Most-Referenced Documents")
        let table = AnalyticsChartTables.crossRefRankingTable(
            title: title,
            rows: ranking.map { (volumeId: $0.volumeId, documentId: $0.documentId,
                                 label: $0.displayLabel, inDegree: $0.inDegree) })
        deliver(table, crossRefProvenance(
            figureTitle: title,
            axisLabel: String(localized: "crossRefAnalytics.export.axis.inDegree",
                              defaultValue: "Ranked by inbound references")))
    }

    /// Renders one Cross-Reference chart as a publication figure and shares (iOS) or saves (macOS).
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

    /// Exports the most-referenced ranking as a figure.
    private func exportRankingFigure(_ format: AnalyticsFigureFormat) {
        let title = String(localized: "crossRefAnalytics.ranking.heading", defaultValue: "Most-Referenced Documents")
        deliverFigure(format,
                      provenance: crossRefProvenance(
                        figureTitle: title,
                        axisLabel: String(localized: "crossRefAnalytics.export.axis.inDegree",
                                          defaultValue: "Ranked by inbound references")),
                      chartHeight: max(240, CGFloat(ranking.count) * 26 + 40)) {
            rankingChart
        }
    }

    /// Exports the citation-degree distribution as a figure.
    private func exportDistributionFigure(_ format: AnalyticsFigureFormat) {
        let title = String(localized: "crossRefAnalytics.distribution.heading", defaultValue: "Citation Degree Distribution")
        deliverFigure(format,
                      provenance: crossRefProvenance(
                        figureTitle: title,
                        axisLabel: String(localized: "crossRefAnalytics.export.axis.degree",
                                          defaultValue: "Grouped by references received")),
                      chartHeight: 380) {
            distributionChart
        }
    }

    /// Exports the citation-degree distribution, including the out-degree overlay when shown.
    private func exportDistributionCSV() {
        let title = String(localized: "crossRefAnalytics.distribution.heading", defaultValue: "Citation Degree Distribution")
        let outByLabel = Dictionary(outDistribution.map { ($0.label, $0.documentCount) },
                                    uniquingKeysWith: { first, _ in first })
        let table = AnalyticsChartTables.crossRefDistributionTable(
            title: title,
            rows: distribution.map { (bucket: $0.label,
                                      inDegreeDocuments: $0.documentCount,
                                      outDegreeDocuments: showOutDegree ? outByLabel[$0.label] : nil) })
        deliver(table, crossRefProvenance(
            figureTitle: title,
            axisLabel: String(localized: "crossRefAnalytics.export.axis.degree",
                              defaultValue: "Grouped by references received")))
    }

    /// Exports the volume heat matrix as an edge list — on screen a cell's value is encoded only as
    /// opacity plus a tooltip, so these counts are otherwise unreadable.
    private func exportMatrixCSV() {
        let title = String(localized: "crossRefAnalytics.matrix.heading", defaultValue: "Volume Citation Heat Matrix")
        let rows = matrixCells.map { cell in
            (sourceId: cell.sourceVolumeId, sourceTitle: volumeTitle(cell.sourceVolumeId),
             targetId: cell.targetVolumeId, targetTitle: volumeTitle(cell.targetVolumeId),
             count: cell.count)
        }
        let table = AnalyticsChartTables.crossRefMatrixTable(title: title, rows: rows)
        deliver(table, crossRefProvenance(
            figureTitle: title,
            axisLabel: String(localized: "crossRefAnalytics.export.axis.matrix",
                              defaultValue: "Cross-volume citation counts"),
            extra: [String(format: String(localized: "crossRefAnalytics.export.caveat.matrixLimit %lld",
                                          defaultValue: "Selection: the matrix covers the %lld most-connected volumes by total inbound + outbound references; pairs with no references between them are omitted from this file."),
                           Int64(Self.matrixVolumeLimit))]))
    }

    /// Exports the PageRank landmarks — the scores are otherwise reachable only through the chart's
    /// VoiceOver value.
    private func exportLandmarkCSV() {
        let title = String(localized: "crossRefAnalytics.landmarks.heading", defaultValue: "Landmark Documents (Influence)")
        let table = AnalyticsChartTables.crossRefLandmarkTable(
            title: title,
            rows: landmarks.map { (volumeId: $0.volumeId, documentId: $0.documentId,
                                   label: $0.displayLabel, score: $0.score) })
        deliver(table, crossRefProvenance(
            figureTitle: title,
            axisLabel: String(localized: "crossRefAnalytics.export.axis.pageRank",
                              defaultValue: "Ranked by PageRank influence score"),
            extra: [String(localized: "crossRefAnalytics.export.caveat.pageRank",
                           defaultValue: "Score: an offline PageRank over the resolved citation graph — a structural measure of how often a document is cited by other well-cited documents. It is not a claim of historical importance.")]))
    }

    /// Out-degree overlay toggle for the degree distribution — moved out of the shared toolbar
    /// into this chart's section (#209). Disabled when there's no distribution to chart.
    @ViewBuilder
    private var distributionControls: some View {
        HStack {
            Toggle(isOn: $showOutDegree) {
                Text(String(localized: "crossRefAnalytics.outDegree.toggle", defaultValue: "Out-degree"))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .disabled(distribution.isEmpty)
            .help(String(localized: "crossRefAnalytics.outDegree.help",
                         defaultValue: "Overlay the out-degree distribution (how many citations documents make) on the in-degree histogram."))
            Spacer()
            AnalyticsSectionExportControl(isEnabled: !distribution.isEmpty,
                                          exportCSV: exportDistributionCSV,
                                          exportFigure: exportDistributionFigure)
        }
        .padding(.horizontal)
    }

    private var resolvedCaption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "crossRefAnalytics.resolvedCaption",
                        defaultValue: "The most-referenced, degree, and PageRank figures attribute same-volume references (including resolved page references) to their own volume; when a year range or scope is set they count citations made by documents in that era/scope. The volume heat matrix counts connections between different volumes, so it excludes same-volume citations."))
            // No accessibilityLabel override: the explanatory clause exists nowhere else in the
            // view, so VoiceOver must read the full visible caption.
            if excludedBrokenCount > 0 {
                Text(String(localized: "crossRefAnalytics.excludedBrokenCaption",
                            defaultValue: "\(excludedBrokenCount) unresolvable references are excluded from this analysis — cross-references in the printed volumes that point to a document, page, or volume not present in the corpus."))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    // MARK: - Most-referenced documents

    @ViewBuilder
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionSubtitle(String(localized: "crossRefAnalytics.ranking.subtitle",
                                   defaultValue: "Top documents by inbound citation count (in-degree). Tap a document to open it."))

            if isLoading {
                loadingRow
            } else if ranking.isEmpty {
                emptyRow(String(localized: "crossRefAnalytics.ranking.empty",
                                defaultValue: "No resolved cross-references are indexed yet. Index more volumes to build the citation network."))
            } else if viewMode == .chart {
                rankingChart
            } else {
                rankingTable
            }
        }
    }

    private var rankingChart: some View {
        // Key each bar on the row's UNIQUE id (volumeId/documentId), never its title. FRUS reuses
        // generic titles ("Department of State Minutes", "Mr. Adams to Mr. Seward") across many
        // distinct documents, and Swift Charts SUMS a `BarMark`'s x-values whenever rows share a
        // categorical y — so a title-keyed y silently merged several documents into one oversized
        // bar (e.g. four "Department of State Minutes" documents at in-degrees 48/43/42/39 rendered
        // as a single 172-long bar) while the annotation and table still showed one document's count
        // (#243-followup). Ids are unique → one bar per document, correct length. An explicit domain
        // preserves the in-degree-descending order (a categorical scale otherwise reorders the axis),
        // and a lookup renders the human title — disambiguated when a title is shared — on the axis.
        let axisLabels = disambiguatedRankingLabels(
            ranking.map { row in
                (id: row.id,
                 name: targetLabel(volumeId: row.volumeId, documentId: row.documentId, header: row.header),
                 shortSuffix: row.documentId)
            }
        )
        return Chart(ranking) { row in
            BarMark(
                x: .value(String(localized: "crossRefAnalytics.axis.inDegree", defaultValue: "Inbound citations"),
                          row.inDegree),
                y: .value(String(localized: "crossRefAnalytics.axis.document", defaultValue: "Document"),
                          row.id)
            )
            .foregroundStyle(Color.accentColor)
            .annotation(position: .trailing) {
                Text(row.inDegree, format: .number)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            // The bar is keyed on the opaque id for correct geometry, so restore a meaningful
            // VoiceOver announcement: the human document label + its inbound-citation count.
            .accessibilityLabel(Text(axisLabels[row.id] ?? row.displayLabel))
            .accessibilityValue(Text(String(localized: "crossRefAnalytics.axis.inDegreeValue",
                                             defaultValue: "\(row.inDegree) inbound citations")))
        }
        // Highest in-degree at the top: `ranking` is sorted descending, and the first domain
        // element is placed at the top of a horizontal-bar categorical y-axis.
        .chartYScale(domain: ranking.map(\.id))
        .chartYAxis {
            AxisMarks(preset: .aligned) { value in
                AxisValueLabel {
                    if let id = value.as(String.self) {
                        Text(axisLabels[id] ?? id)
                    }
                }
            }
        }
        .frame(height: CGFloat(ranking.count) * 30 + 40)
        .padding(.horizontal)
    }

    private var rankingTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranking.enumerated()), id: \.element.id) { index, row in
                Button {
                    openDocument(volumeId: row.volumeId, documentId: row.documentId,
                                 header: targetLabel(volumeId: row.volumeId, documentId: row.documentId, header: row.header))
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(targetLabel(volumeId: row.volumeId, documentId: row.documentId, header: row.header))
                                .font(.body).lineLimit(2)
                            Text(verbatim: "\(row.volumeId) · \(row.documentId)")
                                .font(.caption2).foregroundStyle(.secondary)
                            if !row.isIndexed {
                                Text(String(localized: "crossRefAnalytics.row.notDownloaded",
                                            defaultValue: "In a volume you haven't downloaded"))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(row.inDegree, format: .number)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    // MARK: - Degree distribution

    @ViewBuilder
    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionSubtitle(String(localized: "crossRefAnalytics.distribution.subtitle",
                                   defaultValue: "How many documents have each inbound-citation count — a few landmark documents and a long tail. Toggle the out-degree overlay to compare how many citations documents make."))

            if isLoading {
                loadingRow
            } else if distribution.isEmpty {
                emptyRow(String(localized: "crossRefAnalytics.distribution.empty",
                                defaultValue: "No resolved cross-references to chart."))
            } else {
                distributionChart
            }
        }
    }

    private var distributionChart: some View {
        Chart {
            ForEach(distribution) { bucket in
                BarMark(
                    x: .value(String(localized: "crossRefAnalytics.axis.degree", defaultValue: "Degree"),
                              bucket.label),
                    y: .value(String(localized: "crossRefAnalytics.axis.documentCount", defaultValue: "Documents"),
                              bucket.documentCount)
                )
                .foregroundStyle(by: .value(
                    String(localized: "crossRefAnalytics.axis.series", defaultValue: "Direction"),
                    String(localized: "crossRefAnalytics.series.inDegree", defaultValue: "In-degree")))
                .position(by: .value(
                    String(localized: "crossRefAnalytics.axis.series", defaultValue: "Direction"),
                    String(localized: "crossRefAnalytics.series.inDegree", defaultValue: "In-degree")))
            }
            if showOutDegree {
                ForEach(outDistribution) { bucket in
                    BarMark(
                        x: .value(String(localized: "crossRefAnalytics.axis.degree", defaultValue: "Degree"),
                                  bucket.label),
                        y: .value(String(localized: "crossRefAnalytics.axis.documentCount", defaultValue: "Documents"),
                                  bucket.documentCount)
                    )
                    .foregroundStyle(by: .value(
                        String(localized: "crossRefAnalytics.axis.series", defaultValue: "Direction"),
                        String(localized: "crossRefAnalytics.series.outDegree", defaultValue: "Out-degree")))
                    .position(by: .value(
                        String(localized: "crossRefAnalytics.axis.series", defaultValue: "Direction"),
                        String(localized: "crossRefAnalytics.series.outDegree", defaultValue: "Out-degree")))
                }
            }
        }
        // Explicit domain+range: supplying only `range:` maps the palette positionally onto
        // Swift Charts' inferred (sorted) series domain, which can mis-color the overlay
        // (the CA-5 color-scale gotcha, per ChronologyView). Keep the two series' colors fixed.
        .chartForegroundStyleScale(
            domain: [
                String(localized: "crossRefAnalytics.series.inDegree", defaultValue: "In-degree"),
                String(localized: "crossRefAnalytics.series.outDegree", defaultValue: "Out-degree")
            ],
            range: [Color.accentColor, Color.orange]
        )
        .chartLegend(showOutDegree ? .visible : .hidden)
        .frame(height: 260)
        .padding(.horizontal)
    }

    // MARK: - Volume heat matrix

    @ViewBuilder
    private var matrixSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionSubtitle(String(localized: "crossRefAnalytics.matrix.subtitle",
                                   defaultValue: "Cross-volume citation counts among the \(Self.matrixVolumeLimit) most-connected volumes (by total inbound + outbound references). Rows cite columns; darker cells are more references. Tap a volume label to open it."))

            if isLoading {
                loadingRow
            } else if matrixVolumes.count < 2 {
                emptyRow(String(localized: "crossRefAnalytics.matrix.empty",
                                defaultValue: "Not enough cross-volume references are indexed to build a heat matrix. Index more volumes."))
            } else {
                heatMatrix
                matrixLegend
            }
        }
    }

    private var heatMatrix: some View {
        // Win 8: larger cells (was 22pt) and HORIZONTAL short column codes (were rotated, truncated
        // ids) so the column axis reads left-to-right. Rows keep the fuller descriptive label.
        let cellSize: CGFloat = 34
        let headerHeight: CGFloat = 40
        let rowLabelWidth: CGFloat = 150
        // Resolve each column's manifest metadata once, then derive the collision-free codes (column
        // axis) and the descriptive labels (row axis).
        let columns: [(id: String, subseries: String, title: String, topic: String)] = matrixVolumes.map { id in
            let entry = appState.manifestStore.entry(forVolumeId: id)
            let subseries = entry?.subseries ?? ""
            let title = entry?.title ?? id
            let distilled = ChronologyViewModel.distilledVolumeLabel(volumeId: id, subseries: subseries, title: title)
            // distilledVolumeLabel is "Topic · tag" (topic present) or just "tag"; take the topic half.
            let topic = distilled.contains(" · ") ? String(distilled.components(separatedBy: " · ").first ?? "") : ""
            return (id: id, subseries: subseries, title: title, topic: topic)
        }
        let codes = matrixColumnCodes(columns)
        let rowLabels = Dictionary(uniqueKeysWithValues: columns.map { c in
            (c.id, ChronologyViewModel.distilledVolumeLabel(volumeId: c.id, subseries: c.subseries, title: c.title))
        })
        return ScrollView([.horizontal, .vertical]) {
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                // Header row: corner + column (target) codes — horizontal, up to two lines.
                GridRow {
                    Color.clear.frame(width: rowLabelWidth, height: headerHeight)
                    ForEach(matrixVolumes, id: \.self) { target in
                        Button {
                            openVolume(target)
                        } label: {
                            Text(codes[target] ?? shortVolumeLabel(target))
                                .font(.system(size: 10).monospaced())
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.center)
                                .frame(width: cellSize, height: headerHeight, alignment: .center)
                        }
                        .buttonStyle(.plain)
                        .help(volumeTitle(target))
                        .accessibilityLabel(Text(volumeTitle(target)))
                    }
                }
                ForEach(matrixVolumes, id: \.self) { source in
                    GridRow {
                        Button {
                            openVolume(source)
                        } label: {
                            Text(rowLabels[source] ?? shortVolumeLabel(source))
                                .font(.system(size: 10))
                                .lineLimit(1)
                                // Head-truncate: distilledVolumeLabel's uniqueness lives in its
                                // trailing "· period vN" tag, so when the topic is too long keep the
                                // tag (right-aligned, nearest the cells) visible rather than dropping
                                // it — otherwise volumes sharing a topic prefix render identically.
                                .truncationMode(.head)
                                .frame(width: rowLabelWidth, height: cellSize, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                        .help(volumeTitle(source))
                        .accessibilityLabel(Text(volumeTitle(source)))
                        ForEach(matrixVolumes, id: \.self) { target in
                            heatCellView(source: source, target: target, size: cellSize)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 480)
    }

    private func heatCellView(source: String, target: String, size: CGFloat) -> some View {
        let count = cellCount(source: source, target: target)
        return RoundedRectangle(cornerRadius: 2)
            .fill(heatColor(for: count))
            .frame(width: size, height: size)
            .overlay {
                if source == target {
                    // Diagonal (self) — no cross-volume value; mark it neutral.
                    Rectangle().fill(Color.secondary.opacity(0.12))
                }
            }
            .help(count > 0
                  ? String(localized: "crossRefAnalytics.matrix.cell.help",
                           defaultValue: "\(shortVolumeLabel(source)) → \(shortVolumeLabel(target)): \(count) references")
                  : String(localized: "crossRefAnalytics.matrix.cell.none",
                           defaultValue: "\(shortVolumeLabel(source)) → \(shortVolumeLabel(target)): no references"))
    }

    private var matrixLegend: some View {
        HStack(spacing: 8) {
            Text(String(localized: "crossRefAnalytics.matrix.legend.low", defaultValue: "Fewer"))
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach([0.15, 0.35, 0.55, 0.75, 0.95], id: \.self) { t in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(t))
                        .frame(width: 18, height: 12)
                }
            }
            Text(String(localized: "crossRefAnalytics.matrix.legend.high", defaultValue: "More"))
                .font(.caption2).foregroundStyle(.secondary)
            if matrixMaxCount > 0 {
                Text(String(localized: "crossRefAnalytics.matrix.legend.max",
                            defaultValue: "(max \(matrixMaxCount))"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Landmark documents (PageRank)

    @ViewBuilder
    private var landmarkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionSubtitle(String(localized: "crossRefAnalytics.landmarks.subtitle",
                                   defaultValue: "Ranked by an offline PageRank influence score over the resolved citation graph — documents a citation-following reader keeps returning to. This is a structural influence measure, not a claim of historical importance. Tap to open."))

            if isLoading {
                loadingRow
            } else if landmarks.isEmpty {
                emptyRow(String(localized: "crossRefAnalytics.landmarks.empty",
                                defaultValue: "No resolved citation graph to rank yet."))
            } else {
                landmarkTable
            }
        }
    }

    private var landmarkTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(landmarks.enumerated()), id: \.element.id) { index, row in
                Button {
                    openDocument(volumeId: row.volumeId, documentId: row.documentId,
                                 header: targetLabel(volumeId: row.volumeId, documentId: row.documentId, header: row.header))
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        // Rank chip (design Win 9) — the ordinal position, replacing the plain "1."
                        // number and (with the bar below) the raw PageRank decimal ("0.0042") that
                        // meant nothing to a reader.
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(index == 0 ? Color.white : Color.accentColor)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(index == 0
                                                      ? Color.accentColor
                                                      : Color.accentColor.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(targetLabel(volumeId: row.volumeId, documentId: row.documentId, header: row.header))
                                .font(.body).lineLimit(2)
                            Text(verbatim: "\(row.volumeId) · \(row.documentId)")
                                .font(.caption2).foregroundStyle(.secondary)
                            if !row.isIndexed {
                                Text(String(localized: "crossRefAnalytics.row.notDownloaded",
                                            defaultValue: "In a volume you haven't downloaded"))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            // Relative influence bar — width ∝ score / max landmark score.
                            influenceBar(fraction: maxLandmarkScore > 0 ? row.score / maxLandmarkScore : 0)
                                .padding(.top, 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    // The exact PageRank score is kept for VoiceOver, per the design.
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(Text(row.score, format: .number.precision(.significantDigits(2))))
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    /// The largest landmark PageRank score — the denominator for the influence bars (design Win 9).
    private var maxLandmarkScore: Double { landmarks.map(\.score).max() ?? 1 }

    /// A thin relative-influence bar whose filled width is `fraction` of the track. Decorative — the
    /// exact PageRank value lives on each row's `accessibilityValue`, so the bar is hidden from a11y.
    private func influenceBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(Color.accentColor)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: - Shared row chrome

    private func sectionSubtitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
    }

    /// Primary label for a cross-reference target row (#209). An indexed target shows its document
    /// header; a legitimate citation into a not-yet-downloaded volume (no cached header) falls back
    /// to a manifest-derived "Document N — <volume title>" instead of the raw "volumeId · documentId"
    /// key — so the highest-influence landmarks, which are frequently in un-downloaded volumes, read
    /// as real documents rather than opaque keys.
    private func targetLabel(volumeId: String, documentId: String, header: String?) -> String {
        if let header, !header.isEmpty { return header }
        let number = documentId.hasPrefix("d") ? String(documentId.dropFirst()) : documentId
        let prefix = String(localized: "crossRefAnalytics.row.documentPrefix", defaultValue: "Document")
        return "\(prefix) \(number) — \(volumeTitle(volumeId))"
    }

    private var loadingRow: some View {
        ProgressView().frame(maxWidth: .infinity).padding()
    }

    private func emptyRow(_ text: String) -> some View {
        ContentUnavailableView(
            String(localized: "crossRefAnalytics.section.empty.title", defaultValue: "No Data"),
            systemImage: "point.3.connected.trianglepath.dotted",
            description: Text(text)
        )
    }

    // MARK: - Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "crossRefAnalytics.unavailable.title", defaultValue: "Cross-Reference Analytics Unavailable"),
            systemImage: "point.3.connected.trianglepath.dotted",
            description: Text(String(
                localized: "crossRefAnalytics.unavailable.detail",
                defaultValue: "The search index is not available. Index at least one volume to build the citation network."))
        )
    }

    // MARK: - Matrix helpers

    private func cellCount(source: String, target: String) -> Int {
        matrixCells.first { $0.sourceVolumeId == source && $0.targetVolumeId == target }?.count ?? 0
    }

    /// Heat shade for a cross-volume cell, scaled against the matrix maximum. Zero → clear.
    private func heatColor(for count: Int) -> Color {
        guard count > 0, matrixMaxCount > 0 else { return Color.secondary.opacity(0.06) }
        // Log-ish emphasis so small nonzero counts remain visible; floor at 0.15 opacity.
        let ratio = Double(count) / Double(matrixMaxCount)
        let opacity = 0.15 + 0.80 * ratio
        return Color.accentColor.opacity(opacity)
    }

    /// A compact matrix label: the volume id with the leading "frus" stripped.
    private func shortVolumeLabel(_ volumeId: String) -> String {
        volumeId.hasPrefix("frus") ? String(volumeId.dropFirst(4)) : volumeId
    }

    /// The volume's full title (for tooltips), falling back to the id.
    private func volumeTitle(_ volumeId: String) -> String {
        appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    // MARK: - Navigation

    /// Document tap → open in this window's provenance host on macOS
    /// (`AppState.openDocument(_:from: .tool(.crossRefAnalytics))`), or the Browse tab on iOS. On
    /// macOS this view renders only in the `frus.crossRefAnalytics` window (the `frus.analytics`
    /// window hosts `AnalyticsView`, which has no document-open path), so `.crossRefAnalytics` is
    /// its unambiguous provenance. (It is also shown as a sheet from the iOS Browse tab.)
    private func openDocument(volumeId: String, documentId: String, header: String) {
        let entry = DocumentBrowserEntry(
            documentId: documentId, volumeId: volumeId, header: header)
        #if os(macOS)
        appState.openDocument(entry, from: .tool(.crossRefAnalytics), using: openWindow)
        #else
        appState.openBrowseDocument(entry, from: sceneID)
        appState.openTab(.browse, from: sceneID)
        #endif
        #if DEBUG
        print("[CrossReferenceAnalyticsView] Open document \(volumeId)/\(documentId)")
        #endif
    }

    /// Volume tap → open the browser to that volume (the `pendingBrowseVolume` deep-link,
    /// the volume-grain sibling used by Cross-Volume Provenance rows).
    private func openVolume(_ volumeId: String) {
        appState.openBrowseVolume(volumeId, from: sceneID)
        #if os(iOS)
        appState.openTab(.browse, from: sceneID)
        #endif
        #if DEBUG
        print("[CrossReferenceAnalyticsView] Open volume \(volumeId)")
        #endif
    }

    // MARK: - Data loading

    private func loadAll() async {
        guard let store = appState.crossReferenceStore else { return }
        isLoading = true

        // Snapshot the active filters (#189-B): source-anchored year + volume scope for the four
        // document-level figures; the heat matrix reuses the scope as its both-endpoints filter.
        let range = effectiveYearRange
        let scope = scopeVolumeIds

        // Unresolvable references excluded from this scope (#240B) — disclosed in the caption.
        excludedBrokenCount = (try? await store.excludedBrokenCount(yearRange: range, volumeIds: scope)) ?? 0

        // In-degree ranking.
        let topDocs = (try? await store.topDocumentsByInDegree(limit: Self.rankingLimit, yearRange: range, volumeIds: scope)) ?? []
        let rankingIndexed = (try? await store.indexedDocumentKeys(
            for: topDocs.map { (volumeId: $0.volumeId, documentId: $0.documentId) })) ?? []
        ranking = topDocs.map {
            InDegreeRow(volumeId: $0.volumeId, documentId: $0.documentId,
                        inDegree: $0.inDegree, header: $0.header,
                        isIndexed: rankingIndexed.contains("\($0.volumeId)/\($0.documentId)"))
        }

        // Degree distributions.
        let inDeg = (try? await store.resolvedInDegrees(yearRange: range, volumeIds: scope)) ?? []
        let outDeg = (try? await store.resolvedOutDegrees(yearRange: range, volumeIds: scope)) ?? []
        distribution = CrossReferenceStats.degreeDistribution(inDeg)
        outDistribution = CrossReferenceStats.degreeDistribution(outDeg)

        // Volume heat matrix (both-endpoints volume scope via limitToVolumeIds; source-anchored date).
        let edges = (try? await store.volumeLevelConnections(limitToVolumeIds: scope, yearRange: range)) ?? []
        let topVolumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: Self.matrixVolumeLimit)
        let volumeSet = Set(topVolumes)
        let cells = edges
            .filter { volumeSet.contains($0.sourceVolumeId) && volumeSet.contains($0.targetVolumeId) }
            .map { HeatCell(sourceVolumeId: $0.sourceVolumeId, targetVolumeId: $0.targetVolumeId, count: $0.count) }
        matrixVolumes = topVolumes
        matrixCells = cells
        matrixMaxCount = cells.map(\.count).max() ?? 0

        // PageRank landmarks — compute off the main actor (bounded/offline).
        let citationEdges = (try? await store.resolvedCitationEdges(yearRange: range, volumeIds: scope)) ?? []
        let scored = await Task.detached(priority: .userInitiated) {
            PageRank.compute(edges: citationEdges)
        }.value
        let topScored = Array(scored.prefix(Self.landmarkLimit))
        // Join headers for the landmark set.
        let headerKeys = topScored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) }
        let headers = (try? await store.documentHeaders(for: headerKeys)) ?? [:]
        let landmarkIndexed = (try? await store.indexedDocumentKeys(for: headerKeys)) ?? []
        landmarks = topScored.map {
            LandmarkRow(volumeId: $0.key.volumeId, documentId: $0.key.documentId,
                        score: $0.score,
                        header: headers["\($0.key.volumeId)/\($0.key.documentId)"],
                        isIndexed: landmarkIndexed.contains("\($0.key.volumeId)/\($0.key.documentId)"))
        }

        isLoading = false
    }
}
