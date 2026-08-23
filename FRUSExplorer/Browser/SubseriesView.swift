// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - SubseriesView

/// Browser level showing all volumes in a single subseries with optional tag filtering.
///
/// A tag filter bar allows the user to narrow the volume list by volume-level tag,
/// using AND logic. Tag chips in the VolumeView can push a filter here via
/// `BrowserViewModel.activateTagFilter(slug:forSubseries:)`.
///
/// Version history:
///   1.0 — Session 11: initial implementation
///   1.1 — Wave R / R-8: the word-cloud toolbar button names itself in its `Label` rather than
///          relying on `.accessibilityLabel` alone, which an overflowed toolbar row discards.
struct SubseriesView: View {

    let vm: BrowserViewModel
    let group: SubseriesGroup

    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID
    /// The scopes, queried live so the "Browsing within" filter (Q-3) resolves at render
    /// (#1051 B-3).
    @Query private var scopes: [CustomVolumeScope]

    var body: some View {
        let filterState = ScopeAxis.filterState(
            filterId: appState.browseScopeFilterId,
            scopes: scopes,
            manifestIds: Set(vm.allVolumes.map(\.volumeId))
        )
        List {
            BrowseScopeFilterSection(state: filterState) {
                appState.browseScopeFilterId = nil
            }

            // Subseries statistics
            Section {
                SubseriesStatsView(group: group)
            }

            // Tag filter bar
            Section(header: Text(String(localized: "browser.subseries.filter.header",
                                        defaultValue: "Filter by Tag"))) {
                SubseriesTagFilterBar(vm: vm, subseries: group.subseries)
            }

            // Volume list — the scope filter composes with the tag and downloaded filters
            // (#1051 B-3; `.empty`/`.unavailable` show the explicit nothing, never the
            // whole corpus).
            let volumes = ScopeAxis.scopedVolumes(vm.filteredVolumes(for: group.subseries),
                                                  state: filterState)
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
                            VolumeRowLabel(
                                volume: volume,
                                isDownloaded: vm.isDownloaded(volume.volumeId),
                                isIndexed: vm.isIndexed(volume.volumeId),
                                isDownloading: appState.downloadQueue.contains(volume.volumeId),
                                documentCount: appState.administrationProfilesStore
                                    .documentCount(forVolumeId: volume.volumeId)
                            )
                        }
                        .buttonStyle(.plain)
                        #if os(iOS)
                        .contextMenu {
                            // #1051 B-3 (design 3b): the scope items lead, then the
                            // volume's own actions — the order the design specifies.
                            VolumeScopeMenuItems(volumeId: volume.volumeId) { id in
                                vm.navigationPath.append(.scopeEditor(id))
                            }
                            Divider()
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
                    appState.openWordCloud(.subseries(subseriesId: group.subseries), from: sceneID)
                } label: {
                    // R-8: named `Label`, not a bare `Image`. This toolbar has a single
                    // item today and so cannot overflow, but the shape is the one that
                    // announced a raw SF Symbol name the moment a Browse toolbar did.
                    Label(Self.wordCloudName, systemImage: WordCloudGlyph.symbol)
                }
                .help(String(localized: "browser.subseries.wordCloud.help",
                             defaultValue: "Visualise the most frequent terms across this subseries"))
                .accessibilityLabel(Self.wordCloudName)
            }
        }
    }

    /// The word-cloud control's name, read both from its `Label` (which is what an
    /// overflowed toolbar row announces) and from `.accessibilityLabel`. See R-8.
    static var wordCloudName: String {
        String(localized: "browser.subseries.wordCloud.a11y", defaultValue: "Subseries word cloud")
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
                if group.sideloadedCount > 0 {
                    StatPill(
                        value: "\(group.sideloadedCount)",
                        label: String(localized: "browser.subseries.sideloaded",
                                      defaultValue: "Side-loaded")
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
                // #312 follow-up: `.borderless` hit-tests only its label content, exactly like
                // `.plain` — measured on iPhone 16e (iOS 26.x), a tap on the right-hand half of this
                // row did nothing before these two lines. This row spans the full width visually, so
                // the whole width should be the target.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
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
///   1.6 — #1051 B-1 (R-1): the ONE badge vocabulary on both platforms — `isIndexed`
///          (green check) and `isDownloading` (blue arrow) join Downloaded / Side-loaded /
///          Partial / Planned, so the iOS row stops carrying fewer facts than its macOS
///          twin (#777 drift class); the dead `volume.documentCount > 0` gate (0 in all
///          552 manifest entries — it had never rendered) is replaced by the
///          `documentCount` parameter, fed by the R-2 accessor at every call site
struct VolumeRowLabel: View {
    let volume: VolumeManifestEntry
    let isDownloaded: Bool
    /// Whether the volume is indexed on this device (the green check badge).
    var isIndexed: Bool = false
    /// Whether the volume is currently in the download queue (the blue badge).
    var isDownloading: Bool = false
    /// The volume's document count from the R-2 accessor, or `nil` to omit the caption.
    var documentCount: Int? = nil
    /// Whether the metadata line leads with the volume id — the macOS corpus browser's
    /// convention, off on iOS.
    var showsVolumeId: Bool = false

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
                    if isIndexed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .accessibilityLabel(
                                String(localized: "browser.volume.indexed.a11y",
                                       defaultValue: "Indexed")
                            )
                    }
                } else if isDownloading {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                        .font(.caption)
                        .accessibilityLabel(
                            String(localized: "browser.volume.downloading.a11y",
                                   defaultValue: "Downloading")
                        )
                }
            }
            HStack(spacing: 8) {
                if showsVolumeId {
                    Text(volume.volumeId).foregroundStyle(.secondary)
                }
                if let pub = volume.publicationDate {
                    Text(pub).foregroundStyle(.secondary)
                }
                if let documentCount {
                    Text("\(documentCount) docs")
                        .foregroundStyle(.secondary)
                }
                if volume.status == .partiallyPublished {
                    Text(String(localized: "browser.volume.partial", defaultValue: "Partial"))
                        .foregroundStyle(.orange)
                }
                // #777: the row says on-screen what only the remove dialog said before. The
                // reader who added the file knows; the reader on the SAME iCloud account who
                // opens Browse a week later does not.
                if volume.provenance == .sideloaded {
                    Text(String(localized: "browser.volume.sideloaded",
                                defaultValue: "Side-loaded"))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .background(.quaternary, in: Capsule())
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
///   1.1 — #1051 B-3: internal (not `private`) — the shared R-1 `VolumeListView` composes
///          it after the pan-axis scope items
struct VolumeRowContextMenu: View {
    let volume: VolumeManifestEntry
    @Environment(AppState.self) private var appState
    /// #338 step 2: this scene's identity, so a word-cloud hand-off is addressed to THIS window.
    @Environment(\.sceneID) private var sceneID

    var body: some View {
        // #777: no Download affordance for a side-loaded volume — there is nothing to fetch, and
        // the file is already here. `downloadUrl == nil` is exactly that condition.
        if let dm = appState.downloadManager, !dm.isVolumeDownloaded(volume.volumeId),
           volume.downloadUrl != nil {
            Button {
                Task { await dm.enqueueDownload(volume) }
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
            appState.openWordCloud(.volume(volumeId: volume.volumeId), from: sceneID)
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
                        // Decorative: the selected state is conveyed by the .isSelected trait.
                        .accessibilityHidden(true)
                }
            }
            // #312 follow-up: no frame needed — the Spacer already makes this HStack full width.
            // contentShape makes the gap between the name and the checkmark tappable, which for a
            // toggle row is most of the target. Mirrors `MergeTagSheet.mergeTagRow` in SettingsView.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // VoiceOver announces which taxonomy filters are active; the visual checkmark
        // alone is invisible to it (#242 session a11y rider).
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
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
