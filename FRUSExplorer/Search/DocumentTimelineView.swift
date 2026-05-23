// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - DocumentTimelineView

/// Chronological visualisation of a document set using Swift Charts.
///
/// Displays documents grouped by year in two switchable modes:
/// - **Chart**: bar chart with year on the x-axis and document count on the y-axis.
/// - **List**: scrollable list with year-section headers; each row is tappable when
///   an `onSelect` handler is provided.
///
/// Documents without a machine-readable date in `document_dates` are excluded from
/// both modes. An undated-count footnote appears at the bottom when any documents
/// are excluded.
///
/// Date data is loaded asynchronously via `AppState.indexingPipeline`
/// (`IndexingPipeline.datesByDocumentKey(_:)`). The view automatically reloads
/// when the `items` array changes identity (first-10-ID fingerprint).
///
/// ## Platform placement
/// - **Search**: replaces the results list when the timeline toolbar button is active.
/// - **Collections**: presented as a sheet from the Documents section header button.
///
/// Version history:
///   1.0 — Session 88
struct DocumentTimelineView: View {

    // MARK: - Item Model

    /// Minimal document info required for timeline display.
    struct Item: Identifiable, Equatable {
        let volumeId: String
        let documentId: String
        let header: String
        var id: String { "\(volumeId)/\(documentId)" }
    }

    // MARK: - Display Mode

    enum DisplayMode { case chart, list }

    // MARK: - Internal Year Grouping

    private struct YearSection: Identifiable {
        let year: Int
        let items: [Item]
        var id: Int { year }
        var count: Int { items.count }
    }

    // MARK: - Inputs

    let items: [Item]
    /// Called when the user taps a document row in list mode. Pass `nil` to disable tapping.
    var onSelect: ((Item) -> Void)? = nil

    // MARK: - State

    @Environment(AppState.self) private var appState
    @State private var yearSections: [YearSection] = []
    @State private var undatedCount: Int = 0
    @State private var isLoading = true
    @State private var displayMode: DisplayMode = .chart

    // MARK: - Body

    var body: some View {
        Group {
            if isLoading {
                ProgressView(String(localized: "timeline.loading",
                                    defaultValue: "Loading timeline\u{2026}"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if yearSections.isEmpty {
                ContentUnavailableView(
                    String(localized: "timeline.empty.title",
                           defaultValue: "No Dated Documents"),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(
                        String(localized: "timeline.empty.detail",
                               defaultValue: "None of these documents have machine-readable dates."))
                )
            } else {
                mainContent
            }
        }
        .task(id: itemsFingerprint) { await loadTimeline() }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Mode picker
            Picker(String(localized: "timeline.modePicker", defaultValue: "View mode"),
                   selection: $displayMode) {
                Label(String(localized: "timeline.mode.chart", defaultValue: "Chart"),
                      systemImage: "chart.bar").tag(DisplayMode.chart)
                Label(String(localized: "timeline.mode.list", defaultValue: "List"),
                      systemImage: "list.bullet").tag(DisplayMode.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch displayMode {
            case .chart: chartView
            case .list:  listView
            }

            if undatedCount > 0 { undatedNote }
        }
    }

    // MARK: - Chart Mode

    @ViewBuilder
    private var chartView: some View {
        let minBarWidth: CGFloat = 22
        let chartWidth = max(300, CGFloat(yearSections.count) * minBarWidth)
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(yearSections) { section in
                    BarMark(
                        x: .value(String(localized: "timeline.x", defaultValue: "Year"),
                                  section.year),
                        y: .value(String(localized: "timeline.y", defaultValue: "Documents"),
                                  section.count)
                    )
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(yearSections.count, 10))) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text(verbatim: "\(year)").font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(width: chartWidth, height: 220)
            .padding()
        }
    }

    // MARK: - List Mode

    @ViewBuilder
    private var listView: some View {
        List {
            ForEach(yearSections) { section in
                Section(String(section.year)) {
                    ForEach(section.items) { item in
                        Button {
                            onSelect?(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.header.isEmpty ? item.documentId : item.header)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(item.volumeId)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(onSelect == nil)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    // MARK: - Undated Note

    private var undatedNote: some View {
        let s = undatedCount == 1 ? "" : "s"
        return Text(
            String(localized: "timeline.undated",
                   defaultValue: "\(undatedCount) document\(s) without a reliable date excluded from the timeline.")
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Data Loading

    private var itemsFingerprint: String {
        "\(items.count):\(items.prefix(10).map { $0.id }.joined(separator: ","))"
    }

    private func loadTimeline() async {
        isLoading = true
        yearSections = []
        undatedCount = 0
        guard let pipeline = appState.indexingPipeline, !items.isEmpty else {
            isLoading = false
            return
        }
        let pairs = items.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        let dates = (try? await pipeline.datesByDocumentKey(pairs)) ?? [:]

        var yearToItems: [Int: [Item]] = [:]
        var undated = 0
        for item in items {
            if let iso = dates[item.id], let year = Self.parseYear(iso) {
                yearToItems[year, default: []].append(item)
            } else {
                undated += 1
            }
        }
        yearSections = yearToItems.keys.sorted().map {
            YearSection(year: $0, items: yearToItems[$0]!)
        }
        undatedCount = undated
        isLoading = false
    }

    private static func parseYear(_ iso: String) -> Int? {
        guard iso.count >= 4 else { return nil }
        return Int(iso.prefix(4))
    }
}
