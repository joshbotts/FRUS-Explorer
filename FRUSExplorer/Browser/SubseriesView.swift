// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SubseriesView

/// Browser level showing all volumes in a single subseries with optional tag filtering.
///
/// A tag filter bar allows the user to narrow the volume list by volume-level tag,
/// using AND logic. Tag chips in the VolumeView can push a filter here via
/// `BrowserViewModel.activateTagFilter(slug:forSubseries:)`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
struct SubseriesView: View {

    let vm: BrowserViewModel
    let group: SubseriesGroup

    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            // Subseries statistics
            Section {
                SubseriesStatsView(group: group)
            }

            // Tag filter bar
            Section(header: Text(String(localized: "browser.subseries.filter.header",
                                        defaultValue: "Filter by Tag"))) {
                SubseriesTagFilterBar(vm: vm, subseries: group.subseries)
            }

            // Volume list
            let volumes = vm.filteredVolumes(for: group.subseries)
            Section(header: Text(
                volumes.isEmpty
                    ? String(localized: "browser.subseries.noResults", defaultValue: "No Matching Volumes")
                    : "Volumes (\(volumes.count))"
            )) {
                if volumes.isEmpty {
                    Text(String(localized: "browser.subseries.emptyState",
                                defaultValue: "No volumes match the selected tags."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(volumes) { volume in
                        Button {
                            vm.navigationPath.append(.volume(volume))
                            #if DEBUG
                            print("[BrowserView] Navigate → volume \(volume.volumeId)")
                            #endif
                        } label: {
                            VolumeRowLabel(volume: volume, isDownloaded: vm.isDownloaded(volume.volumeId))
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .contextMenu {
                            VolumeRowContextMenu(volume: volume)
                        }
                        #endif
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(group.subseries)
        #if os(iOS)
        // Inline (not large) title: at this depth the large title only restates the last
        // breadcrumb crumb, wasting a ~52pt band above the content. The breadcrumb bar is
        // the single location label. (The corpus root keeps its large title.)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.pendingWordCloud = .subseries(subseriesId: group.subseries)
                } label: {
                    Image(systemName: WordCloudGlyph.symbol)
                }
                .help(String(localized: "browser.subseries.wordCloud.help",
                             defaultValue: "Visualise the most frequent terms across this subseries"))
                .accessibilityLabel(String(localized: "browser.subseries.wordCloud.a11y",
                                           defaultValue: "Subseries word cloud"))
            }
        }
    }
}

// MARK: - SubseriesStatsView

private struct SubseriesStatsView: View {
    let group: SubseriesGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 20) {
                StatPill(
                    value: "\(group.publishedCount)",
                    label: String(localized: "browser.subseries.published", defaultValue: "Published")
                )
                if group.partiallyPublishedCount > 0 {
                    StatPill(
                        value: "\(group.partiallyPublishedCount)",
                        label: String(localized: "browser.subseries.partial", defaultValue: "Partial")
                    )
                }
                if group.plannedCount > 0 {
                    StatPill(
                        value: "\(group.plannedCount)",
                        label: String(localized: "browser.subseries.planned", defaultValue: "Planned")
                    )
                }
            }
            if let e = group.earliestDate, let l = group.latestDate {
                Text("Documents: \(e.prefix(4)) – \(l.prefix(4))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - SubseriesTagFilterBar

/// Inline tag picker with selected-tag chips for subseries-level filtering.
struct SubseriesTagFilterBar: View {

    let vm: BrowserViewModel
    let subseries: String
    @State private var showingPicker = false

    private var activeFilter: Set<String> { vm.tagFilters[subseries] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active filter chips
            if !activeFilter.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(activeFilter).sorted(), id: \.self) { slug in
                            let name = vm.tagStore.resolve(slug: slug)?.displayName ?? slug
                            HStack(spacing: 4) {
                                Text(name)
                                    .font(.caption)
                                    .padding(.leading, 8)
                                Button {
                                    vm.removeTagFilter(slug: slug, forSubseries: subseries)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                                .buttonStyle(.borderless)
                                .padding(.trailing, 6)
                                .accessibilityLabel(
                                    String(localized: "browser.filter.remove.a11y",
                                           defaultValue: "Remove \(name) filter")
                                )
                                .help(String(
                                    localized: "browser.filter.remove.help",
                                    defaultValue: "Remove this tag filter"
                                ))
                            }
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        Button {
                            vm.clearTagFilters(forSubseries: subseries)
                        } label: {
                            Text(String(localized: "browser.filter.clearAll", defaultValue: "Clear All"))
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(String(localized: "browser.filter.clearAll.help",
                                     defaultValue: "Remove all active tag filters and show every volume in this subseries"))
                    }
                    .padding(.vertical, 2)
                }
            }

            // "Add filter" button
            Button {
                showingPicker = true
            } label: {
                Label(
                    String(localized: "browser.filter.addTag", defaultValue: "Add Tag Filter"),
                    systemImage: "tag"
                )
                .font(.callout)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "browser.filter.addTag.help",
                         defaultValue: "Filter volumes by research topic — select one or more tags to narrow the list to volumes covering those themes"))
        }
        .sheet(isPresented: $showingPicker) {
            TagPickerSheet(vm: vm, subseries: subseries, isPresented: $showingPicker)
        }
    }
}

// MARK: - TagPickerSheet

private struct TagPickerSheet: View {
    let vm: BrowserViewModel
    let subseries: String
    @Binding var isPresented: Bool
    @State private var searchText: String = ""

    private var filteredEntries: [TagTaxonomyEntry] {
        let all = vm.tagStore.allEntries
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(TagCategory.allCases, id: \.self) { category in
                    let entries = filteredEntries.filter { $0.category == category.rawValue }
                    if !entries.isEmpty {
                        Section(header: Text(category.displayName)) {
                            ForEach(entries, id: \.slug) { entry in
                                TagPickerRow(vm: vm, subseries: subseries, entry: entry)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText,
                        prompt: String(localized: "browser.filter.search",
                                       defaultValue: "Search tags"))
            .navigationTitle(String(localized: "browser.filter.title", defaultValue: "Filter by Tag"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "browser.filter.done", defaultValue: "Done")) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - VolumeRowLabel

/// Row content for a single volume in `SubseriesView`.
///
/// On iOS, displays an `IndexingCapsule` below the metadata line while this
/// volume is being indexed, so the user gets real-time throughput feedback
/// without navigating away from the browser.
///
/// An amber warning badge is shown on iOS when `AppState.interruptedVolumeIds` contains
/// this volume's ID, indicating that a prior indexing pass was interrupted. The badge
/// disappears while active indexing is in progress for this volume.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Session 51: iOS IndexingCapsule wired via AppState.currentIndexingProgress
///   1.2 — Session 113: metadata parameter forwarded to IndexingCapsule
///   1.3 — Session 115: amber interrupted badge; "Re-index" contextual menu item
///   1.4 — Session 2026-07-03: volume titles wrap to their full value (two-line clip removed)
///   1.5 — Session 2026-07-03: .contentShape(Rectangle()) — the enclosing Browse-list
///          Buttons are .buttonStyle(.plain), which only hit-tests opaque content, so
///          taps between/around the text labels were dead
struct VolumeRowLabel: View {
    let volume: VolumeManifestEntry
    let isDownloaded: Bool

    #if os(iOS)
    @Environment(AppState.self) private var appState
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(volume.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                #if os(iOS)
                if appState.interruptedVolumeIds.contains(volume.volumeId),
                   appState.currentIndexingProgress?.volumeId != volume.volumeId {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .accessibilityLabel(
                            String(localized: "browser.volume.interrupted.a11y",
                                   defaultValue: "Indexing interrupted")
                        )
                }
                #endif
                if isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .accessibilityLabel(
                            String(localized: "browser.volume.downloaded.a11y",
                                   defaultValue: "Downloaded")
                        )
                }
            }
            HStack(spacing: 8) {
                if let pub = volume.publicationDate {
                    Text(pub).foregroundStyle(.secondary)
                }
                if volume.documentCount > 0 {
                    Text("\(volume.documentCount) docs")
                        .foregroundStyle(.secondary)
                }
                if volume.status == .partiallyPublished {
                    Text(String(localized: "browser.volume.partial", defaultValue: "Partial"))
                        .foregroundStyle(.orange)
                }
                if volume.status == .planned {
                    Text(String(localized: "browser.volume.planned", defaultValue: "Planned"))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            #if os(iOS)
            if let progress = appState.currentIndexingProgress,
               progress.volumeId == volume.volumeId {
                IndexingCapsule(progress: progress, metadata: appState.lastDiscoveredMetadata)
            }
            #endif
        }
        .padding(.vertical, 3)
        // The enclosing row Buttons use .buttonStyle(.plain), which hit-tests only opaque
        // content — make the whole row rectangle (including gaps around the text) tappable.
        .contentShape(Rectangle())
    }
}

// MARK: - VolumeRowContextMenu

#if os(iOS)
/// Context menu for a volume row in `SubseriesView`.
///
/// Shows a "Re-index" action when the volume is in `AppState.interruptedVolumeIds`,
/// letting the user trigger a re-index directly from the browser list.
///
/// Version history:
///   1.0 — Session 115: initial implementation
private struct VolumeRowContextMenu: View {
    let volume: VolumeManifestEntry
    @Environment(AppState.self) private var appState

    var body: some View {
        if let dm = appState.downloadManager, !dm.isVolumeDownloaded(volume.volumeId) {
            Button {
                Task { await dm.enqueueDownload(volumeId: volume.volumeId,
                                                downloadUrl: volume.downloadUrl) }
            } label: {
                Label(
                    String(localized: "browser.volume.download.action",
                           defaultValue: "Download Volume"),
                    systemImage: "arrow.down.circle"
                )
            }
        }
        if appState.interruptedVolumeIds.contains(volume.volumeId),
           let pipeline = appState.indexingPipeline {
            Button {
                Task { try? await pipeline.indexVolume(volume.volumeId) }
            } label: {
                Label(
                    String(localized: "browser.volume.reindex.action",
                           defaultValue: "Re-index"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        }
        Button {
            appState.pendingWordCloud = .volume(volumeId: volume.volumeId)
        } label: {
            Label { Text(String(localized: "browser.volume.wordCloud.action",
                                defaultValue: "Word Cloud")) }
                icon: { Image(systemName: WordCloudGlyph.symbol) }
        }
    }
}
#endif

// MARK: - IndexingCapsule

#if os(iOS)
/// An inline pill showing live FTS5 indexing progress for a volume.
///
/// Displayed in `VolumeRowLabel` while `AppState.currentIndexingProgress`
/// references the matching volume. Disappears automatically when indexing
/// completes (the parent condition becomes `false`).
///
/// When `metadata` is non-nil and matches the volume, a single person-count
/// line is shown below the throughput: "312 persons".
///
/// Version history:
///   1.0 — Session 51: initial implementation
///   1.1 — Session 113: `metadata` parameter; person count line
private struct IndexingCapsule: View {
    let progress: IndexingProgressUpdate
    var metadata: VolumeMetadataDiscovered? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 80)
                    .tint(.accentColor)
                Text(stageLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if progress.docsPerSecond > 0 {
                    Text(String(format: "%.0f doc/s", progress.docsPerSecond))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let meta = metadata,
               meta.volumeId == progress.volumeId,
               meta.uniquePersonCount > 0 {
                Text(String(
                    localized: "indexing.capsule.meta.persons",
                    defaultValue: "\(meta.uniquePersonCount) persons"
                ))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "browser.indexingCapsule.a11y",
                   defaultValue: "Indexing: \(stageLabel)")
        )
    }

    private var progressFraction: Double {
        guard progress.totalDocuments > 0 else { return 0 }
        return Double(progress.completedDocuments) / Double(progress.totalDocuments)
    }

    private var stageLabel: String {
        switch progress.stage {
        case .reading:
            return String(localized: "indexing.stage.reading", defaultValue: "Reading…")
        case .storingBatch(let current, let total):
            return String(localized: "indexing.stage.storingBatch",
                          defaultValue: "Storing batch \(current) of \(total)…")
        case .optimizing:
            return String(localized: "indexing.stage.optimizing",
                          defaultValue: "Finalizing index…")
        case .complete:
            return String(localized: "indexing.stage.complete", defaultValue: "Complete")
        }
    }
}
#endif

// MARK: - TagPickerRow

private struct TagPickerRow: View {
    let vm: BrowserViewModel
    let subseries: String
    let entry: TagTaxonomyEntry

    var body: some View {
        let isActive = vm.tagFilters[subseries]?.contains(entry.slug) ?? false
        Button {
            if isActive {
                vm.removeTagFilter(slug: entry.slug, forSubseries: subseries)
            } else {
                vm.activateTagFilter(slug: entry.slug, forSubseries: subseries)
            }
        } label: {
            HStack {
                Text(entry.displayName)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TagCategory display name

private extension TagCategory {
    var displayName: String {
        switch self {
        case .people: return String(localized: "browser.tag.category.people", defaultValue: "People")
        case .places: return String(localized: "browser.tag.category.places", defaultValue: "Places")
        case .topics: return String(localized: "browser.tag.category.topics", defaultValue: "Topics")
        }
    }
}
