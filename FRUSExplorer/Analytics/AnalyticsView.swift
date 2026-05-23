// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import Charts

// MARK: - AnalyticsViewMode

/// Presentation mode for `AnalyticsView`.
///
/// Version history:
///   1.0 — Session 99: initial implementation
enum AnalyticsViewMode: String, CaseIterable {
    case chart, table
}

// MARK: - AnalyticsChartAxis

/// Which dimension to plot in `AnalyticsView`.
///
/// Version history:
///   1.0 — Session 99: initial implementation
enum AnalyticsChartAxis: String, CaseIterable {
    case byYear, bySubseries
}

// MARK: - AnalyticsView

/// Corpus frequency analytics view with Swift Charts.
///
/// Accepts a keyword term and charts how many indexed documents match that
/// term, broken down either by year of origin or by FRUS subseries. Results
/// are fetched asynchronously from `CorpusAnalyticsService` via `AppState`.
///
/// ## Layout
/// A search field at the top drives the query. The body shows either a
/// bar + line chart or a scrollable data table depending on `viewMode`.
/// A toolbar picker switches between "By Year" and "By Subseries" axes.
///
/// ## Platform placement
/// - **macOS**: standalone `frus.analytics` Window opened from `MainWindowView`.
/// - **iOS**: sheet presented from the Browse tab toolbar button.
///
/// ## Nil analytics service
/// When `appState.analyticsService` is `nil` (FTS5 database unavailable),
/// a `ContentUnavailableView` placeholder is shown instead.
///
/// Version history:
///   1.0 — Session 99: initial implementation
struct AnalyticsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var termInput: String = ""
    @State private var committedTerm: String = ""
    @State private var yearData: [YearFrequency] = []
    @State private var subseriesData: [SubseriesFrequency] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var viewMode: AnalyticsViewMode = .chart
    @State private var chartAxis: AnalyticsChartAxis = .byYear

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if appState.analyticsService == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        searchBar
                        Divider()
                        contentArea
                    }
                }
            }
            .navigationTitle(
                String(localized: "analytics.title", defaultValue: "Corpus Analytics")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #endif
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField(
                String(localized: "analytics.term.placeholder", defaultValue: "Term…"),
                text: $termInput
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { runSearch() }

            Button(String(localized: "analytics.search.button", defaultValue: "Search")) {
                runSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(termInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorMessage {
            ContentUnavailableView(
                String(localized: "analytics.error.title", defaultValue: "Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if committedTerm.isEmpty {
            ContentUnavailableView(
                String(localized: "analytics.prompt.title", defaultValue: "Enter a Term"),
                systemImage: "chart.bar.xaxis",
                description: Text(
                    String(localized: "analytics.prompt.detail",
                           defaultValue: "Type a keyword and tap Search to chart its frequency across the FRUS corpus.")
                )
            )
        } else if yearData.isEmpty && subseriesData.isEmpty {
            ContentUnavailableView(
                String(localized: "analytics.empty.title", defaultValue: "No Results"),
                systemImage: "chart.bar",
                description: Text(
                    String(localized: "analytics.empty.detail",
                           defaultValue: "No indexed documents match "\(committedTerm)".")
                )
            )
        } else {
            switch viewMode {
            case .chart:
                chartContent
            case .table:
                tableContent
            }
        }
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        ScrollView {
            switch chartAxis {
            case .byYear:
                yearChartSection
            case .bySubseries:
                subseriesChartSection
            }
        }
    }

    private var yearChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.year.heading",
                       defaultValue: ""\(committedTerm)" — by Year")
            )
            .font(.headline)
            .padding(.horizontal)

            Chart {
                ForEach(yearData) { point in
                    BarMark(
                        x: .value(
                            String(localized: "analytics.axis.year", defaultValue: "Year"),
                            point.year
                        ),
                        y: .value(
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
                            point.count
                        )
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.65))
                }
                ForEach(yearData) { point in
                    LineMark(
                        x: .value(
                            String(localized: "analytics.axis.year", defaultValue: "Year"),
                            point.year
                        ),
                        y: .value(
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
                            point.count
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .chartXAxisLabel(
                String(localized: "analytics.axis.year", defaultValue: "Year"),
                alignment: .center
            )
            .chartYAxisLabel(
                String(localized: "analytics.axis.documents", defaultValue: "Documents")
            )
            .frame(height: 280)
            .padding(.horizontal)

            totalFootnote(count: yearData.reduce(0) { $0 + $1.count })
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var subseriesChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(localized: "analytics.chart.subseries.heading",
                       defaultValue: ""\(committedTerm)" — by Subseries")
            )
            .font(.headline)
            .padding(.horizontal)

            // Horizontal bar chart so subseries labels remain legible.
            Chart {
                ForEach(subseriesData) { point in
                    BarMark(
                        x: .value(
                            String(localized: "analytics.axis.documents", defaultValue: "Documents"),
                            point.count
                        ),
                        y: .value(
                            String(localized: "analytics.axis.subseries", defaultValue: "Subseries"),
                            point.subseries
                        )
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.65))
                }
            }
            .chartXAxisLabel(
                String(localized: "analytics.axis.documents", defaultValue: "Documents"),
                alignment: .center
            )
            .frame(height: max(240, CGFloat(subseriesData.count) * 28))
            .padding(.horizontal)

            totalFootnote(count: subseriesData.reduce(0) { $0 + $1.count })
                .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func totalFootnote(count: Int) -> some View {
        Text(
            String(
                format: String(localized: "analytics.total %lld",
                               defaultValue: "%lld documents matched"),
                Int64(count)
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Table Content

    @ViewBuilder
    private var tableContent: some View {
        switch chartAxis {
        case .byYear:
            List(yearData) { point in
                HStack {
                    Text(verbatim: String(point.year))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: "\(point.count)")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            #if os(iOS)
            .listStyle(.plain)
            #else
            .listStyle(.inset)
            #endif
        case .bySubseries:
            List(subseriesData) { point in
                HStack {
                    Text(point.subseries)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: "\(point.count)")
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            #if os(iOS)
            .listStyle(.plain)
            #else
            .listStyle(.inset)
            #endif
        }
    }

    // MARK: - Unavailable Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "analytics.unavailable.title",
                   defaultValue: "Analytics Unavailable"),
            systemImage: "chart.bar.xaxis",
            description: Text(
                String(localized: "analytics.unavailable.detail",
                       defaultValue: "The search index is not available. Index at least one volume to enable analytics.")
            )
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // View mode: chart vs table
        ToolbarItem(placement: .primaryAction) {
            Picker(
                String(localized: "analytics.viewMode.picker", defaultValue: "Display"),
                selection: $viewMode
            ) {
                Image(systemName: "chart.bar")
                    .tag(AnalyticsViewMode.chart)
                    .accessibilityLabel(
                        String(localized: "analytics.viewMode.chart.a11y", defaultValue: "Chart")
                    )
                Image(systemName: "list.bullet")
                    .tag(AnalyticsViewMode.table)
                    .accessibilityLabel(
                        String(localized: "analytics.viewMode.table.a11y", defaultValue: "Table")
                    )
            }
            .pickerStyle(.segmented)
            .disabled(committedTerm.isEmpty)
        }

        // Axis: by year vs by subseries
        ToolbarItem(placement: .primaryAction) {
            Picker(
                String(localized: "analytics.axis.picker", defaultValue: "Group by"),
                selection: $chartAxis
            ) {
                Text(String(localized: "analytics.axis.byYear", defaultValue: "By Year"))
                    .tag(AnalyticsChartAxis.byYear)
                Text(String(localized: "analytics.axis.bySubseries", defaultValue: "By Subseries"))
                    .tag(AnalyticsChartAxis.bySubseries)
            }
            .disabled(committedTerm.isEmpty)
        }

        // Done button — iOS sheet only; macOS windows use the close button.
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "analytics.done", defaultValue: "Done")) {
                dismiss()
            }
        }
        #endif
    }

    // MARK: - Search Action

    private func runSearch() {
        let term = termInput.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, let service = appState.analyticsService else { return }
        committedTerm = term
        isLoading = true
        errorMessage = nil
        yearData = []
        subseriesData = []
        Task {
            do {
                async let years = service.termFrequencyByYear(term: term)
                async let subseries = service.termFrequencyBySubseries(term: term)
                yearData = try await years
                subseriesData = try await subseries
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
