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
/// ## Structural, not temporal
/// These are structural statistics of the citation graph, so — unlike the term/person
/// analytics — there is no year-range bar. The chart/table mode picker applies where useful.
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
struct CrossReferenceAnalyticsView: View {

    @Environment(AppState.self) private var appState

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

    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var showOutDegree = false
    @State private var isLoading = false
    @State private var didLoad = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.crossReferenceStore == nil {
                    unavailablePlaceholder
                } else {
                    content
                }
            }
            .navigationTitle(
                String(localized: "crossRefAnalytics.title", defaultValue: "Cross-Reference Analytics")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 600)
        #endif
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadAll()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                resolvedCaption
                Divider()
                rankingSection
                Divider()
                distributionSection
                Divider()
                matrixSection
                Divider()
                landmarkSection
            }
            .padding(.vertical, 8)
        }
    }

    private var resolvedCaption: some View {
        Text(String(localized: "crossRefAnalytics.resolvedCaption",
                    defaultValue: "The most-referenced, degree, and PageRank figures count every citation, attributing same-volume references (including resolved page references) to their own volume. The volume heat matrix counts connections between different volumes, so it excludes same-volume citations."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }

    // MARK: - Most-referenced documents

    @ViewBuilder
    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(String(localized: "crossRefAnalytics.ranking.heading",
                                  defaultValue: "Most-Referenced Documents"))
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
        Chart(ranking) { row in
            BarMark(
                x: .value(String(localized: "crossRefAnalytics.axis.inDegree", defaultValue: "Inbound citations"),
                          row.inDegree),
                y: .value(String(localized: "crossRefAnalytics.axis.document", defaultValue: "Document"),
                          row.displayLabel)
            )
            .foregroundStyle(Color.accentColor)
            .annotation(position: .trailing) {
                Text(row.inDegree, format: .number)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned) { _ in AxisValueLabel() }
        }
        .frame(height: CGFloat(ranking.count) * 30 + 40)
        .padding(.horizontal)
    }

    private var rankingTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranking.enumerated()), id: \.element.id) { index, row in
                Button {
                    openDocument(volumeId: row.volumeId, documentId: row.documentId,
                                 header: row.displayLabel)
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.displayLabel).font(.body).lineLimit(2)
                            Text(verbatim: "\(row.volumeId) · \(row.documentId)")
                                .font(.caption2).foregroundStyle(.secondary)
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
            sectionHeading(String(localized: "crossRefAnalytics.distribution.heading",
                                  defaultValue: "Citation Degree Distribution"))
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
            sectionHeading(String(localized: "crossRefAnalytics.matrix.heading",
                                  defaultValue: "Volume Citation Heat Matrix"))
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
        let cellSize: CGFloat = 22
        let labelWidth: CGFloat = 92
        return ScrollView([.horizontal, .vertical]) {
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                // Header row: corner + column (target) labels.
                GridRow {
                    Color.clear.frame(width: labelWidth, height: cellSize)
                    ForEach(matrixVolumes, id: \.self) { target in
                        Button {
                            openVolume(target)
                        } label: {
                            Text(shortVolumeLabel(target))
                                .font(.system(size: 8).monospaced())
                                .rotationEffect(.degrees(-90))
                                .frame(width: cellSize, height: labelWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help(volumeTitle(target))
                    }
                }
                ForEach(matrixVolumes, id: \.self) { source in
                    GridRow {
                        Button {
                            openVolume(source)
                        } label: {
                            Text(shortVolumeLabel(source))
                                .font(.system(size: 9).monospaced())
                                .lineLimit(1)
                                .frame(width: labelWidth, height: cellSize, alignment: .trailing)
                        }
                        .buttonStyle(.plain)
                        .help(volumeTitle(source))
                        ForEach(matrixVolumes, id: \.self) { target in
                            heatCellView(source: source, target: target, size: cellSize)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: 420)
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
            sectionHeading(String(localized: "crossRefAnalytics.landmarks.heading",
                                  defaultValue: "Landmark Documents (Influence)"))
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
                                 header: row.displayLabel)
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.displayLabel).font(.body).lineLimit(2)
                            Text(verbatim: "\(row.volumeId) · \(row.documentId)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(row.score, format: .number.precision(.significantDigits(2)))
                            .font(.caption.monospacedDigit())
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

    // MARK: - Shared row chrome

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline).padding(.horizontal)
    }

    private func sectionSubtitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AnalyticsViewModePicker(viewMode: $viewMode, isDisabled: ranking.isEmpty)
        }
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $showOutDegree) {
                Text(String(localized: "crossRefAnalytics.outDegree.toggle", defaultValue: "Out-degree"))
            }
            .toggleStyle(.button)
            .disabled(distribution.isEmpty)
            .help(String(localized: "crossRefAnalytics.outDegree.help",
                         defaultValue: "Overlay the out-degree distribution (how many citations documents make) on the histogram"))
        }
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

    /// Document tap → open in the main browser window/tab (the established deep-link,
    /// reused from HistoryWindowView and the analytics/search hand-offs).
    private func openDocument(volumeId: String, documentId: String, header: String) {
        appState.pendingBrowseDocument = DocumentBrowserEntry(
            documentId: documentId, volumeId: volumeId, header: header)
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        #if DEBUG
        print("[CrossReferenceAnalyticsView] Open document \(volumeId)/\(documentId)")
        #endif
    }

    /// Volume tap → open the browser to that volume (the `pendingBrowseVolume` deep-link,
    /// the volume-grain sibling used by Cross-Volume Provenance rows).
    private func openVolume(_ volumeId: String) {
        appState.pendingBrowseVolume = volumeId
        #if os(iOS)
        appState.activeTab = .browse
        #endif
        #if DEBUG
        print("[CrossReferenceAnalyticsView] Open volume \(volumeId)")
        #endif
    }

    // MARK: - Data loading

    private func loadAll() async {
        guard let store = appState.crossReferenceStore else { return }
        isLoading = true

        // In-degree ranking.
        let topDocs = (try? await store.topDocumentsByInDegree(limit: Self.rankingLimit)) ?? []
        ranking = topDocs.map {
            InDegreeRow(volumeId: $0.volumeId, documentId: $0.documentId,
                        inDegree: $0.inDegree, header: $0.header)
        }

        // Degree distributions.
        let inDeg = (try? await store.resolvedInDegrees()) ?? []
        let outDeg = (try? await store.resolvedOutDegrees()) ?? []
        distribution = CrossReferenceStats.degreeDistribution(inDeg)
        outDistribution = CrossReferenceStats.degreeDistribution(outDeg)

        // Volume heat matrix.
        let edges = (try? await store.volumeLevelConnections()) ?? []
        let topVolumes = CrossReferenceStats.topVolumesByTotalDegree(edges, limit: Self.matrixVolumeLimit)
        let volumeSet = Set(topVolumes)
        let cells = edges
            .filter { volumeSet.contains($0.sourceVolumeId) && volumeSet.contains($0.targetVolumeId) }
            .map { HeatCell(sourceVolumeId: $0.sourceVolumeId, targetVolumeId: $0.targetVolumeId, count: $0.count) }
        matrixVolumes = topVolumes
        matrixCells = cells
        matrixMaxCount = cells.map(\.count).max() ?? 0

        // PageRank landmarks — compute off the main actor (bounded/offline).
        let citationEdges = (try? await store.resolvedCitationEdges()) ?? []
        let scored = await Task.detached(priority: .userInitiated) {
            PageRank.compute(edges: citationEdges)
        }.value
        let topScored = Array(scored.prefix(Self.landmarkLimit))
        // Join headers for the landmark set.
        let headerKeys = topScored.map { (volumeId: $0.key.volumeId, documentId: $0.key.documentId) }
        let headers = (try? await store.documentHeaders(for: headerKeys)) ?? [:]
        landmarks = topScored.map {
            LandmarkRow(volumeId: $0.key.volumeId, documentId: $0.key.documentId,
                        score: $0.score,
                        header: headers["\($0.key.volumeId)/\($0.key.documentId)"])
        }

        isLoading = false
    }
}
