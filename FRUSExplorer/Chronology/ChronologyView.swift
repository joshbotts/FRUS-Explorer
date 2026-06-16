// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ChronologyView

/// Corpus-wide chronological browser: pick a date range and read every document in the
/// indexed corpus that falls within it, grouped into date sections.
///
/// Built on `IndexingPipeline.documentsInDateRange`. Distinct from `DocumentTimelineView`
/// (which visualizes a supplied result set) — this is a primary browsing surface.
///
/// ## Dense dates
/// Sections over `denseThreshold` rows (e.g. a summit or crisis) collapse to a preview
/// with a "Show all N" expander, and the section header summarises the cluster (count,
/// volumes, subseries, editorial notes) with an inline density bar.
///
/// ## Platform placement
/// - **iOS**: sheet from the Browse tab toolbar (mirrors Corpus Analytics).
/// - **macOS**: standalone `frus.chronology` Window.
///
/// Version history:
///   1.0 — Session 163: initial implementation
struct ChronologyView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var vm = ChronologyViewModel(
        rangeStart: ChronologyView.defaultStart,
        rangeEnd: ChronologyView.defaultEnd
    )
    @State private var navigationPath: [DocumentBrowserEntry] = []
    @State private var expandedSections: Set<String> = []
    @State private var didSeedDefaults = false

    /// Parameters this view was opened with (a `pendingChronology` handoff). Applied once.
    private let initialParameters: ChronologyParameters?

    /// Rows shown in a dense section before the "Show all" expander.
    private static let denseThreshold = 25

    init(initialParameters: ChronologyParameters? = nil) {
        self.initialParameters = initialParameters
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if appState.indexingPipeline == nil {
                    unavailablePlaceholder
                } else {
                    VStack(spacing: 0) {
                        rangeBar
                        Divider()
                        contentArea
                    }
                }
            }
            .navigationTitle(String(localized: "chronology.title", defaultValue: "Chronology"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                #if os(iOS)
                DocumentView(entry: entry)
                #else
                MacDocumentView(entry: entry, navigationPath: .constant([]), highlightCoordinator: HighlightCoordinator())
                #endif
            }
            .toolbar { toolbarContent }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task { seedDefaultsAndApply(initialParameters) }
        .onChange(of: appState.pendingChronology) { _, params in
            guard let params else { return }
            apply(params)
            appState.pendingChronology = nil
        }
    }

    // MARK: - Defaults & handoff

    /// Placeholder range used before the manifest is consulted — a representative FRUS
    /// year, replaced on first appearance by the corpus's most recent year.
    private static let defaultStart = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 1969, month: 1, day: 1)) ?? .distantPast
    private static let defaultEnd = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 1969, month: 12, day: 31)) ?? .now

    /// On first appearance, point the VM at the pipeline and default the range to the
    /// corpus's most recent year (unless a handoff seeds an explicit range).
    private func seedDefaultsAndApply(_ params: ChronologyParameters?) {
        vm.pipeline = appState.indexingPipeline
        if let params {
            apply(params)
            return
        }
        guard !didSeedDefaults else { return }
        didSeedDefaults = true
        let corpus = appState.manifestStore.corpusDateRange
        let cal = Calendar(identifier: .gregorian)
        vm.rangeEnd = corpus.upperBound
        vm.rangeStart = cal.date(byAdding: .year, value: -1, to: corpus.upperBound) ?? corpus.lowerBound
    }

    /// Applies a seeded date range and loads immediately.
    private func apply(_ params: ChronologyParameters) {
        didSeedDefaults = true
        if let start = params.rangeStart { vm.rangeStart = start }
        if let end = params.rangeEnd { vm.rangeEnd = end }
        Task { await vm.reload() }
    }

    // MARK: - Range Bar

    private var rangeBar: some View {
        VStack(spacing: 8) {
            HStack {
                DatePicker(
                    String(localized: "chronology.range.from", defaultValue: "From"),
                    selection: $vm.rangeStart,
                    in: ...vm.rangeEnd,
                    displayedComponents: .date
                )
                .labelsHidden()
                Text(verbatim: "–").foregroundStyle(.tertiary)
                DatePicker(
                    String(localized: "chronology.range.to", defaultValue: "To"),
                    selection: $vm.rangeEnd,
                    in: vm.rangeStart...,
                    displayedComponents: .date
                )
                .labelsHidden()
                Spacer()
                Button {
                    Task { await vm.reload() }
                } label: {
                    Text(String(localized: "chronology.show", defaultValue: "Show"))
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)
            }
            if vm.hasLoaded && !vm.groups.isEmpty {
                HStack(spacing: 12) {
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        searchInRange()
                    } label: {
                        Label(
                            String(localized: "chronology.searchRange", defaultValue: "Search in this range"),
                            systemImage: "magnifyingglass"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
    }

    private var summaryLine: String {
        let docs = vm.totalShown
        let base = String(
            format: String(localized: "chronology.summary %lld", defaultValue: "%lld documents"),
            Int64(docs)
        )
        return vm.isCapped
            ? base + " " + String(localized: "chronology.summary.capped",
                                   defaultValue: "(showing the first \(ChronologyViewModel.loadLimit) — narrow the range)")
            : base
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorMessage {
            ContentUnavailableView(
                String(localized: "chronology.error.title", defaultValue: "Error"),
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
        } else if !vm.hasLoaded {
            ContentUnavailableView(
                String(localized: "chronology.prompt.title", defaultValue: "Choose a Date Range"),
                systemImage: "calendar",
                description: Text(String(
                    localized: "chronology.prompt.detail",
                    defaultValue: "Pick a start and end date, then tap Show to browse every corpus document from that period."
                ))
            )
        } else if vm.groups.isEmpty {
            ContentUnavailableView(
                String(localized: "chronology.empty.title", defaultValue: "No Documents"),
                systemImage: "calendar.badge.exclamationmark",
                description: Text(String(
                    localized: "chronology.empty.detail",
                    defaultValue: "No indexed documents fall within this date range. Try widening it or indexing more volumes."
                ))
            )
        } else {
            sectionList
        }
    }

    private var maxSectionCount: Int {
        max(1, vm.groups.map(\.count).max() ?? 1)
    }

    private var sectionList: some View {
        List {
            ForEach(vm.groups) { group in
                Section {
                    let visible = isExpanded(group) ? group.rows : Array(group.rows.prefix(Self.denseThreshold))
                    ForEach(visible) { row in
                        Button {
                            open(row)
                        } label: {
                            ChronologyRowView(row: row, volumeTitle: volumeTitle(row.volumeId))
                        }
                        .buttonStyle(.plain)
                    }
                    if group.count > Self.denseThreshold && !isExpanded(group) {
                        Button {
                            expandedSections.insert(group.bucketKey)
                        } label: {
                            Text(String(
                                format: String(localized: "chronology.showAll %lld",
                                               defaultValue: "Show all %lld documents on this date"),
                                Int64(group.count)
                            ))
                            .font(.subheadline)
                        }
                    }
                } header: {
                    sectionHeader(group)
                }
            }
            if vm.totalShown > 0 {
                Section {
                    Text(String(localized: "chronology.undated.note",
                                defaultValue: "Documents without a machine-readable date are not shown."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        #endif
    }

    private func sectionHeader(_ group: ChronologyDateGroup) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(group.displayLabel)
                    .font(.headline)
                Text(verbatim: "\(group.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                Spacer()
                densityBar(count: group.count)
            }
            Text(aggregateLine(group))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .textCase(nil)
    }

    private func densityBar(count: Int) -> some View {
        let fraction = CGFloat(count) / CGFloat(maxSectionCount)
        return Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 56, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: max(3, 56 * fraction), height: 5)
            }
            .accessibilityHidden(true)
    }

    private func aggregateLine(_ group: ChronologyDateGroup) -> String {
        var parts: [String] = []
        parts.append(String(format: String(localized: "chronology.agg.volumes %lld",
                                            defaultValue: "%lld volumes"), Int64(group.volumeCount)))
        parts.append(String(format: String(localized: "chronology.agg.subseries %lld",
                                            defaultValue: "%lld subseries"), Int64(group.subseriesCount)))
        if group.editorialNoteCount > 0 {
            parts.append(String(format: String(localized: "chronology.agg.editorial %lld",
                                               defaultValue: "%lld editorial notes"), Int64(group.editorialNoteCount)))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                vm.ascending.toggle()
                if vm.hasLoaded { Task { await vm.reload() } }
            } label: {
                Label(
                    vm.ascending
                        ? String(localized: "chronology.sort.oldest", defaultValue: "Oldest first")
                        : String(localized: "chronology.sort.newest", defaultValue: "Newest first"),
                    systemImage: vm.ascending ? "arrow.up" : "arrow.down"
                )
            }
            .disabled(!vm.hasLoaded)
            .help(String(localized: "chronology.sort.help",
                         defaultValue: "Toggle chronological order"))
        }
        #if os(iOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "chronology.done", defaultValue: "Done")) { dismiss() }
        }
        #endif
    }

    // MARK: - Placeholder

    private var unavailablePlaceholder: some View {
        ContentUnavailableView(
            String(localized: "chronology.unavailable.title", defaultValue: "Chronology Unavailable"),
            systemImage: "calendar",
            description: Text(String(
                localized: "chronology.unavailable.detail",
                defaultValue: "The search index is not available. Index at least one volume to browse by date."
            ))
        )
    }

    // MARK: - Helpers

    private func isExpanded(_ group: ChronologyDateGroup) -> Bool {
        expandedSections.contains(group.bucketKey)
    }

    private func volumeTitle(_ volumeId: String) -> String {
        appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
    }

    private func open(_ row: ChronologyRow) {
        navigationPath.append(DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            documentNumber: row.documentNumber,
            header: row.header,
            dateline: row.dateline,
            sourceNote: nil,
            isEditorialNote: row.isEditorialNote
        ))
    }

    /// Hand off to Search with the current range pre-applied as a date filter.
    private func searchInRange() {
        let cal = Calendar(identifier: .gregorian)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        let range = DateRange(
            earliest: fmt.string(from: cal.startOfDay(for: min(vm.rangeStart, vm.rangeEnd))),
            latest: fmt.string(from: cal.startOfDay(for: max(vm.rangeStart, vm.rangeEnd)))
        )
        appState.pendingSearch = SearchParameters(dateRange: range)
        #if DEBUG
        print("[ChronologyView] Handoff to Search — dateRange: \(String(describing: range))")
        #endif
        #if os(iOS)
        appState.activeTab = .search
        dismiss()
        #endif
    }
}

// MARK: - ChronologyRowView

/// One document row in the Chronology list: snippet (summary or header), provenance, and
/// type/precision badges.
private struct ChronologyRowView: View {
    let row: ChronologyRow
    let volumeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volumeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if let dateline = row.dateline, !dateline.isEmpty {
                    Text(dateline)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if row.certainty == .approximate {
                    badge(String(localized: "chronology.badge.approx", defaultValue: "~ approximate"))
                }
                if row.isEditorialNote {
                    badge(String(localized: "chronology.badge.editorial", defaultValue: "Editorial note"))
                }
                if row.isFrontMatter {
                    badge(String(localized: "chronology.badge.frontMatter", defaultValue: "Front matter"))
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    /// Prefer the generated summary; fall back to the document header.
    private var snippet: String {
        if let summary = row.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        return row.header.isEmpty ? row.documentId : row.header
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
